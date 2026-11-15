extends SceneTree
## Open-island pilot, stage 1 (docs/design/OPEN_ISLAND_PILOT.md): beach_01 has an optional Intel
## stash, drawn by seed from its Side_Cache markers. Standing in its circle for its seconds empties
## it once, for its Intel; it never opens the extraction, which stays the main mission's. A map
## without Side_Cache markers has no side task. The island log records the side tasks.
## Run: godot --headless --path . --script res://tests/test_side_tasks.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		_failures += 1
		print("TEST FAIL: " + what)


func _initialize() -> void:
	call_deferred("_run")


func _beach_map() -> IslandMap:
	var island: HandmadeIsland = (load("res://game/world/handmade/islands/beach_01.tscn") as PackedScene).instantiate() as HandmadeIsland
	root.add_child(island)
	await process_frame
	var problems: Array[String] = []
	var map: IslandMap = island.build_map(problems)
	_check(problems.is_empty() and map.side_caches.size() == 2, "beach_01 has a pool of 2 Intel stashes and Check map finds no problem (%s)" % [problems])
	island.queue_free()
	return map


func _run_on(map: IslandMap) -> IslandRun:
	var ctx := RunContext.new(5)
	ctx.apply_class(&"recruit")
	ctx.biome = &"beach"
	ctx.mission = &"activate"
	var run := IslandRun.new(ctx.island_seed(), &"beach", map)
	run.load_context(ctx)
	run.noclip = true
	return run


func _run() -> void:
	var map: IslandMap = await _beach_map()
	var run := _run_on(map)
	_check(run.side_tasks.size() == 1 and map.side_caches.has(run.side_tasks[0].position), "a run on beach_01 has one Intel stash, one of the pool's")
	var task: SideTask = run.side_tasks[0]
	var before: int = run.intel_earned()
	run.player_pos = task.position + Vector3(GameData.SIDE_TASK_RADIUS + 2.0, 0, 0)
	run._update_side_tasks(GameData.SIDE_CACHE_SECONDS + 1.0)
	_check(not task.done, "the stash does nothing from outside its circle")
	run.player_pos = task.position
	run._update_side_tasks(GameData.SIDE_CACHE_SECONDS * 0.5)
	_check(not task.done, "half the time in the circle is not enough")
	run._update_side_tasks(GameData.SIDE_CACHE_SECONDS * 0.6)
	_check(task.done and run.messages.size() > 0, "standing in the circle for its seconds empties the stash, with a message")
	var paid: int = run.intel_earned() - before
	_check(paid > 0, "the emptied stash pays Intel (+%d, before the run's multipliers)" % paid)
	run._update_side_tasks(GameData.SIDE_CACHE_SECONDS * 2.0)
	_check(run.intel_earned() - before == paid, "a stash pays once")
	_check(run.objective == IslandRun.Objective.GENERATORS and not run.is_over(), "a side task never opens or ends the extraction")
	var ctx := RunContext.new(5)
	run.save_to_context(ctx)
	var entry: Dictionary = ctx.island_log[-1]
	_check(entry["side_tasks"] == 1 and entry["side_done"] == 1, "the island log records the side tasks and how many were done")
	# The same seed draws the same stash; a generated island (no markers) has none.
	_check(_run_on(map).side_tasks[0].position == task.position, "the same seed draws the same stash")
	var plain := IslandRun.new(7)
	_check(plain.side_tasks.is_empty(), "a map without Side_Cache markers has no side task")
	print("TEST: side tasks, %d failures" % _failures)
	await create_timer(0.3).timeout
	quit(1 if _failures > 0 else 0)
