extends SceneTree
## The test runner's verdicts on controlled logs: a good test, a TEST FAIL,
## a script error, a parse error, a crash (also after its results), a failing
## exit code, a run that never reached its results, a run killed at the timeout,
## and a test listed in KNOWN_SHUTDOWN_CRASH that crashes at quit.
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
	_check(runner.classify(139, "TEST: a\nTEST: b\n").begins_with("FAIL"), "a crash after its results fails: it may have crashed mid-test")
	_check(runner.classify(-1073741819, "TEST: a\n").begins_with("FAIL"), "the access-violation code fails, even after results")
	_check(runner.classify(5, "TEST: a\n").begins_with("FAIL"), "exit 5 at quit fails, even after results")
	# A test listed in KNOWN_SHUTDOWN_CRASH may crash at quit once it has printed its results, and nothing else.
	_check(runner.classify(139, "TEST: a\n", true) == "PASS (exit code at quit, known)", "a listed test may crash at quit after its results")
	_check(runner.classify(139, "", true).begins_with("FAIL"), "a listed test that crashed before any result still fails")
	_check(runner.classify(139, "TEST: a\nTEST FAIL: b\n", true).begins_with("FAIL"), "a listed test that reports a failed check still fails")
	_check(runner.verdict_for(139, "TEST: a\n", false, 5, true) == "PASS (exit code at quit, known)", "verdict_for passes a listed quit crash")
	_check(runner.verdict_for(139, "TEST: a\n", false, 5).begins_with("FAIL"), "verdict_for fails the same crash when the test is not listed")
	_check(runner.classify(3221225477, "TEST: a\n").begins_with("FAIL"), "the unsigned access-violation code fails, even after results")
	_check(runner.classify(1, "TEST: a\n", true) == "FAIL (exit 1)", "a listed test that exits 1 still fails")
	_check(runner.verdict_for(139, "TEST: a\n", true, 5, true).begins_with("FAIL"), "a listed test killed at the timeout still fails")
	_check(runner.classify(139, "").begins_with("FAIL"), "a crash before any result fails")
	_check(runner.classify(1, "TEST: a\n") == "FAIL (exit 1)", "a non-zero exit fails when it is not the known quit code")
	_check(runner.classify(0, "some output without results\n") == "FAIL (exit 0 without results)", "exit 0 without results does not pass")
	_check(runner.classify(0, "").begins_with("FAIL"), "exit 0 with no output at all does not pass")
	_check(runner.verdict_for(0, "TEST: a\n", true, 5) == "FAIL (timeout after 5 s)", "a run killed at the timeout fails, even if it printed results")
	_check(runner.verdict_for(0, "TEST: a\n", false, 5) == "PASS", "without a timeout the log decides")
	quit(1 if _failures > 0 else 0)
