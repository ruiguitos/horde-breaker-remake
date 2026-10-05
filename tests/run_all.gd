extends SceneTree
## Headless test runner: discovers res://tests/test_*.gd and
## res://spikes/*/tests/test_*.gd and runs each one in its own Godot
## subprocess, so a crash, hang-free failure or leaked state in one test
## cannot affect the others.
## Run: godot --headless --path . --script res://tests/run_all.gd
## Optional filter: ... --script res://tests/run_all.gd -- --filter=<substring>
## Exit code: 0 if every test exits 0, 1 otherwise (or if no tests are found).


func _initialize() -> void:
	var filter := _read_filter()
	var tests := _discover_tests()
	if filter != "":
		tests = tests.filter(func(p: String) -> bool: return p.contains(filter))
	if tests.is_empty():
		print("TEST FAIL: no tests found")
		quit(1)
		return

	var exe := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	var failed: Array[String] = []
	var total_start := Time.get_ticks_msec()

	for test_path in tests:
		var args := PackedStringArray(["--headless", "--path", project_dir, "--script", test_path])
		var output: Array = []
		var start := Time.get_ticks_msec()
		var code := OS.execute(exe, args, output, true)
		var elapsed := Time.get_ticks_msec() - start
		var log_text := "".join(PackedStringArray(output))
		# A test that prints "TEST FAIL" but exits 0 still counts as failed.
		var ok := code == 0 and not log_text.contains("TEST FAIL")
		print("%s %s (%d ms, exit %d)" % ["PASS" if ok else "FAIL", test_path, elapsed, code])
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
