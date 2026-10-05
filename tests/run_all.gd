extends SceneTree
## Headless test runner: discovers res://tests/test_*.gd and
## res://spikes/*/tests/test_*.gd and runs each in its own Godot subprocess.
## A test fails if its exit code is not 0 or its output contains "TEST FAIL".
## Run: godot --headless --path . --script res://tests/run_all.gd
## Filter (substring of the path): ... --script res://tests/run_all.gd -- smoke

const TEST_PREFIX := "test_"
const TEST_SUFFIX := ".gd"


func _initialize() -> void:
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if user_args.size() > 0:
		filter = user_args[0]

	var tests := _discover_tests()
	if filter != "":
		var matching: PackedStringArray = []
		for path: String in tests:
			if path.contains(filter):
				matching.append(path)
		tests = matching
	if tests.is_empty():
		print("TEST FAIL: no tests found")
		quit(1)
		return

	var exe := OS.get_executable_path()
	var project_dir := ProjectSettings.globalize_path("res://")
	var failed: PackedStringArray = []
	var total_start := Time.get_ticks_msec()

	for test_path: String in tests:
		var output: Array = []
		var args := PackedStringArray(["--headless", "--path", project_dir, "--script", test_path])
		var start := Time.get_ticks_msec()
		# Blocking call: a test that never calls quit() hangs the runner.
		var code := OS.execute(exe, args, output, true)
		var elapsed := Time.get_ticks_msec() - start
		var text := "".join(output)
		var ok := code == 0 and not text.contains("TEST FAIL")
		print("%s %s (exit %d, %d ms)" % ["PASS" if ok else "FAIL", test_path, code, elapsed])
		if not ok:
			failed.append(test_path)
			print(_indent(text))

	print("---")
	print("Ran %d test file(s) in %d ms; %d failed." % [
		tests.size(), Time.get_ticks_msec() - total_start, failed.size()])
	for path: String in failed:
		print("TEST FAIL: %s" % path)
	quit(1 if failed.size() > 0 else 0)


func _discover_tests() -> PackedStringArray:
	var found: PackedStringArray = []
	found.append_array(_tests_in("res://tests"))
	for spike: String in DirAccess.get_directories_at("res://spikes"):
		found.append_array(_tests_in("res://spikes/%s/tests" % spike))
	found.sort()
	return found


func _tests_in(dir_path: String) -> PackedStringArray:
	var result: PackedStringArray = []
	if not DirAccess.dir_exists_absolute(dir_path):
		return result
	for file: String in DirAccess.get_files_at(dir_path):
		if file.begins_with(TEST_PREFIX) and file.ends_with(TEST_SUFFIX):
			result.append("%s/%s" % [dir_path, file])
	return result


func _indent(text: String) -> String:
	var lines := text.strip_edges().split("\n")
	return "\n".join(Array(lines).map(func(l: String) -> String: return "    " + l))
