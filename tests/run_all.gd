extends SceneTree
## Headless test runner: discovers res://tests/test_*.gd and
## res://spikes/*/tests/test_*.gd and runs each one in its own Godot
## subprocess, so a crash, hang-free failure or leaked state in one test
## cannot affect the others. A test still running after the timeout is killed
## and fails, so one hung test cannot block the rest.
## Run: godot --headless --path . --script res://tests/run_all.gd
## Optional: ... --script res://tests/run_all.gd -- --filter=<substring> --timeout=<seconds>
## Exit code: 0 if every test exits 0, 1 otherwise (or if no tests are found).

## test_escort runs its bots for about 190 s on its own, so 240 s killed it.
const DEFAULT_TIMEOUT_SECONDS: int = 600
## Each test writes its engine log here. The exit code comes from the process and
## the result lines from this file: create_process does not capture the output.
const LOG_DIR: String = "user://test_logs"


func _initialize() -> void:
	var filter := _read_filter()
	var timeout_seconds := _read_timeout_seconds()
	var tests := _discover_tests()
	if filter != "":
		tests = tests.filter(func(p: String) -> bool: return p.contains(filter))
	if tests.is_empty():
		print("TEST FAIL: no tests found")
		quit(1)
		return

	var exe := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	var failed: Array[String] = []
	var total_start := Time.get_ticks_msec()

	for test_path in tests:
		var log_file := "%s/%s.log" % [LOG_DIR, test_path.trim_prefix("res://").replace("/", "__")]
		var args := PackedStringArray(["--headless", "--path", project_dir, "--log-file",
			ProjectSettings.globalize_path(log_file), "--script", test_path])
		var start := Time.get_ticks_msec()
		var pid := OS.create_process(exe, args)
		var timed_out := false
		if pid != -1:
			while OS.is_process_running(pid):
				if Time.get_ticks_msec() - start > timeout_seconds * 1000:
					OS.kill(pid)
					timed_out = true
					break
				OS.delay_msec(50)
		var elapsed := Time.get_ticks_msec() - start
		var code := OS.get_process_exit_code(pid) if pid != -1 else -1
		var log_text := FileAccess.get_file_as_string(log_file)
		var verdict: String = verdict_for(code, log_text, timed_out, timeout_seconds) if pid != -1 else "FAIL (could not start)"
		var ok: bool = verdict == "PASS" or verdict == "PASS (exit code at quit)"
		print("%s %s (%d ms, exit %d) %s" % ["PASS" if ok else "FAIL", test_path, elapsed, code, verdict if verdict != "PASS" else ""])
		if not ok:
			failed.append(test_path)
			for line in log_text.split("\n"):
				if line.strip_edges() != "":
					print("    | " + line)

	print("RESULT: %d/%d passed in %d ms" % [tests.size() - failed.size(), tests.size(), Time.get_ticks_msec() - total_start])
	if failed.is_empty():
		print("TEST: all tests passed")
		quit(0)
	else:
		print("TEST FAIL: %d test(s) failed: %s" % [failed.size(), ", ".join(PackedStringArray(failed))])
		quit(1)


## Verdict for one run. A run killed at the timeout always fails; otherwise the
## log decides (see classify).
static func verdict_for(code: int, log_text: String, timed_out: bool, timeout_seconds: int) -> String:
	if timed_out:
		return "FAIL (timeout after %d s)" % timeout_seconds
	return classify(code, log_text)


## Verdict for one test run. A test passes when its log has no error markers,
## it reached its own result lines, and it exited 0 - or exited with a known
## Windows exit code at quit after finishing (the engine's shutdown quirk).
## A script error, a parse error or a TEST FAIL always fails the test, even
## with exit 0. A run that never printed a result line did not finish, even
## with exit 0 and no output: silence is not a pass.
static func classify(code: int, log_text: String) -> String:
	if log_text.contains("TEST FAIL") or log_text.contains("SCRIPT ERROR") or log_text.contains("Parse Error"):
		return "FAIL (test or script error)"
	var finished: bool = log_text.contains("TEST: ")
	if code == 0:
		return "PASS" if finished else "FAIL (exit 0 without results)"
	if finished and code in [5, 139, -1073741819, 3221225477]:
		return "PASS (exit code at quit)"
	return "FAIL (exit %d)" % code


func _discover_tests() -> Array[String]:
	var found: Array[String] = []
	found.append_array(_tests_in("res://tests"))
	var spikes := DirAccess.open("res://spikes")
	if spikes != null:
		var names := spikes.get_directories()
		names.sort()
		for spike_name in names:
			found.append_array(_tests_in("res://spikes/%s/tests" % spike_name))
	return found


func _tests_in(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return result
	var files := dir.get_files()
	files.sort()
	for file_name in files:
		if file_name.begins_with("test_") and file_name.ends_with(".gd"):
			result.append("%s/%s" % [dir_path, file_name])
	return result


func _read_filter() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--filter="):
			return arg.trim_prefix("--filter=")
	return ""


func _read_timeout_seconds() -> int:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--timeout="):
			return maxi(1, int(arg.trim_prefix("--timeout=")))
	return DEFAULT_TIMEOUT_SECONDS
