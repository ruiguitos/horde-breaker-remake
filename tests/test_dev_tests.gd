extends SceneTree
## DEV · TESTS (docs/design/DEV_MENU.md, zona 3): the panel finds the test scripts,
## reads each verdict from the runner's log, and builds without starting a run.
## Run: godot --headless --path . --script res://tests/test_dev_tests.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var found: Array[String] = DevTestPanel.discover()
	_check(found.has("res://tests/test_dev_tests.gd"), "the panel finds the test scripts in tests/")
	_check(found.size() >= 20, "the panel finds the whole suite (%d scripts)" % found.size())
	_check(not found.has("res://tests/run_all.gd"), "the runner itself is not listed as a test")
	_check(found.any(func(p: String) -> bool: return p.begins_with("res://spikes/")), "the spikes' tests are listed too")
	var tests_only: Array[String] = found.filter(func(p: String) -> bool: return p.begins_with("res://tests/"))
	var sorted: Array[String] = tests_only.duplicate()
	sorted.sort()
	_check(sorted == tests_only, "the tests/ scripts come sorted, and before the spikes")

	var log_text: String = "Godot Engine\nPASS res://tests/test_a.gd (12 ms, exit 0) \n    | TEST: a ok\nFAIL res://tests/test_b.gd (9 ms, exit 1) FAIL (exit 1)\n"
	_check(DevTestPanel.result_for(log_text, "res://tests/test_a.gd") == "PASS", "a PASS line gives PASS")
	_check(DevTestPanel.result_for(log_text, "res://tests/test_b.gd") == "FAIL", "a FAIL line gives FAIL")
	_check(DevTestPanel.result_for(log_text, "res://tests/test_c.gd") == "", "a test with no line in the log has no verdict")

	var panel := DevTestPanel.new()
	root.add_child(panel)
	await process_frame
	_check(not panel.is_running(), "the panel starts with no run")
	_check(panel.find_child("RunAll", true, false) != null and panel.find_child("Stop", true, false) != null,
		"the panel has its run and stop buttons")
	panel.free()
	quit(1 if _failures > 0 else 0)
