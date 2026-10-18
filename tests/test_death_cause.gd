extends SceneTree
## The island's telemetry names what killed the player: the last source that
## took HP reaches the death and the island log. A hit the shield fully
## absorbs does not count as the cause.
## Run: godot --headless --path . --script res://tests/test_death_cause.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _new_run(seed_value: int) -> IslandRun:
	var ctx := RunContext.new(seed_value)
	ctx.biome = &"beach"
	ctx.mission = &"activate"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	return run


func _initialize() -> void:
	var run: IslandRun = _new_run(31)
	run.shield = 0.0
	run.hp = 5.0
	run._take_player_damage(3.0, &"melee")
	_check(run.last_hit_by == &"melee" and absf(run.hp - 2.0) < 0.001, "damage remembers its source")
	run._take_player_damage(10.0, &"lava")
	run.step(1.0 / 60.0, Vector2.ZERO, Vector3.FORWARD, false)
	_check(run.objective == IslandRun.Objective.LOST and run.death_cause == &"lava",
		"the death records the last source (%s)" % run.death_cause)
	var out := RunContext.new(31)
	run.save_to_context(out)
	var entry: Dictionary = out.island_log[-1]
	_check(entry["cause"] == "lava" and entry["result"] == "died", "the island log names the cause")

	var shielded: IslandRun = _new_run(32)
	shielded.shield = 50.0
	shielded.hp = 100.0
	shielded._take_player_damage(10.0, &"bloater")
	_check(shielded.last_hit_by == &"" and absf(shielded.shield - 40.0) < 0.001 and absf(shielded.hp - 100.0) < 0.001,
		"a hit the shield absorbs fully is not a cause")
	quit(1 if _failures > 0 else 0)
