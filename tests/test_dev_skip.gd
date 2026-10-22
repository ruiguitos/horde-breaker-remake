extends SceneTree
## DEV skip (docs/design/DEV_MENU.md, zona 2, "Saltar"): every mission can be
## finished at once, the way out is open afterwards, the last island can skip to
## its boss, and the dev menu enables each button only when it applies.
## Run: godot --headless --path . --script res://tests/test_dev_skip.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_each_mission_reaches_the_exit()
	_test_skip_to_boss_on_the_last_island()
	await _test_menu_buttons()
	quit(1 if _failures > 0 else 0)


## A run with no enemies (rules only), on the mission's own rules.
func _quiet_run(mission: StringName) -> IslandRun:
	var run := IslandRun.new(41)
	run.director.max_alive = 0
	run.set_mission(mission)
	return run


func _test_each_mission_reaches_the_exit() -> void:
	for id: StringName in GameData.MISSIONS:
		var run: IslandRun = _quiet_run(id)
		run.dev_complete_main_task()
		_check(run._main_task_done(), "%s: the main task is done at once" % id)
		_check(run.dev_skip_to_end(), "%s: skipping to the end is accepted" % id)
		run._update_mission(0.0)
		_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT or run.objective == IslandRun.Objective.WON,
			"%s: the island is at its exit (objective %d)" % [id, run.objective])
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
		_check(run.objective == IslandRun.Objective.WON, "%s: standing at the boat wins the island" % id)
		_check(not run.dev_skip_to_end(), "%s: a finished island cannot be skipped again" % id)


func _test_skip_to_boss_on_the_last_island() -> void:
	var ctx := RunContext.new(41)
	ctx.biome = &"beach"
	ctx.mission = &"activate"
	ctx.island_index = ctx.island_count() - 1
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	_check(run.has_boss and run.objective == IslandRun.Objective.GENERATORS,
		"the last island has a boss, and its generators are still to do")
	_check(run.dev_skip_to_boss(), "skipping to the boss is accepted on the last island")
	_check(run.objective == IslandRun.Objective.BOSS and run.boss_index() != -1,
		"skipping to the boss spawns the boss at once")
	_check(not run.dev_skip_to_boss(), "skipping to the boss again does nothing while the boss is in play")
	_check(run.dev_skip_to_end(), "skipping to the end kills the boss and is accepted")
	run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.boss_killed, "the boss is down after the skip")
	run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.objective == IslandRun.Objective.WON, "the last island is won after skipping to the end")


func _test_menu_buttons() -> void:
	var run: IslandRun = _quiet_run(&"activate")
	var menu := DevMenu.new()
	menu.run = run
	root.add_child(menu)
	await process_frame
	menu.toggle()
	var to_boss := menu.find_child("SkipToBoss", true, false) as Button
	var to_end := menu.find_child("SkipToEnd", true, false) as Button
	_check(to_boss != null and to_end != null, "the dev menu has the two skip buttons")
	if to_boss != null and to_end != null:
		_check(to_boss.disabled, "to boss is off on an island without a boss")
		_check(not to_end.disabled, "to end is on while the island is in play")
		to_end.pressed.emit()
		_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "the button skips the activation to the exit")
		_check(not to_end.disabled, "to end stays on until the island is won")
	menu.queue_free()
	await process_frame
