extends SceneTree
## The island's boss is the one enemy allowed one past the horde limit (it is
## never replaced), while ordinary spawns still stop at the limit.
## Run: godot --headless --path . --script res://tests/test_boss_spawn.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var ctx := RunContext.new(41)
	ctx.biome = &"beach"
	ctx.mission = &"activate"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 3
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	for k in 3:
		run.horde.add(run.player_pos + Vector3(10 + k, 0, 0), GameData.EnemyKind.WALKER, run.rng)
	_check(run.horde.count == run.director.max_alive, "the horde is at its limit (%d of %d)" % [run.horde.count, run.director.max_alive])

	run._spawn_boss()
	_check(run.boss_index() != -1 and run.horde.count == 4,
		"the boss spawns even at the limit: %d enemies alive against a limit of 3" % run.horde.count)

	run._spawn_enemy()
	_check(run.horde.count == 4, "an ordinary spawn still stops at the limit")
	quit(1 if _failures > 0 else 0)
