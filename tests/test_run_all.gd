extends SceneTree
## The test runner's verdicts on controlled logs: a good test, a TEST FAIL,
## a script error, a parse error, a known Windows exit code at quit, a
## failing exit code and a run that never reached its results.
## Run: godot --headless --path . --script res://tests/test_run_all.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var runner: Script = load("res://tests/run_all.gd")
	_check(runner.classify(0, "TEST: a\nTEST: b\n") == "PASS", "a clean run passes")
	_check(runner.classify(0, "TEST FAIL: x\n").begins_with("FAIL"), "a failure marker fails even with exit 0")
	_check(runner.classify(0, "SCRIPT ERROR: boom\nTEST: a\n").begins_with("FAIL"), "a script error fails even with exit 0")
	_check(runner.classify(0, "Parse Error: bad\n").begins_with("FAIL"), "a parse error fails")
	_check(runner.classify(139, "TEST: a\nTEST: b\n") == "PASS (exit code at quit)", "a finished run with the Windows exit code at quit passes")
	_check(runner.classify(-1073741819, "TEST: a\n") == "PASS (exit code at quit)", "the access-violation code at quit passes when the run finished")
	_check(runner.classify(139, "").begins_with("FAIL"), "a crash before any result fails")
	_check(runner.classify(1, "TEST: a\n") == "FAIL (exit 1)", "a non-zero exit fails when it is not the known quit code")
	_check(runner.classify(0, "some output without results\n") == "FAIL (exit 0 without results)", "exit 0 without results does not pass")
	_check(runner.classify(0, "").begins_with("FAIL"), "exit 0 with no output at all does not pass")
	quit(1 if _failures > 0 else 0)
