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
	_check(problems.is_empty() and map.side_caches.size() == 2 and map.side_survivors.size() == 2 and map.side_nests.size() == 2,
		"beach_01 has pools of 2 stashes, 2 survivors and 2 nests, and Check map finds no problem (%s)" % [problems])
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
	_check(run.side_tasks.size() == 3 and map.side_caches.has(run.side_tasks[0].position), "a run on beach_01 has a stash, a survivor and a nest, each from its pool")
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
	_check(entry["side_tasks"] == 3 and entry["side_done"] == 1, "the island log records the side tasks and how many were done")
	# The same seed draws the same stash; a generated island (no markers) has none.
	_check(_run_on(map).side_tasks[0].position == task.position, "the same seed draws the same stash")
	var plain := IslandRun.new(7)
	_check(plain.side_tasks.is_empty(), "a map without Side_Cache markers has no side task")
	await _test_screens(map)
	_test_survivor_and_nest(map)
	print("TEST: side tasks, %d failures" % _failures)
	await create_timer(0.3).timeout
	quit(1 if _failures > 0 else 0)


## Stage 2: the HUD lists the side task under the objective, the minimap marks it and keys it,
## and the end-of-island panel says how many were done.
func _test_screens(map: IslandMap) -> void:
	var run := _run_on(map)
	var hud := Hud.new()
	root.add_child(hud)
	await process_frame
	hud.refresh(run, null, 0.0)
	var list: VBoxContainer = hud.get("_side_list")
	var line: Label = list.get_child(0) as Label if list.get_child_count() > 0 else null
	_check(list.visible and line != null and line.text.begins_with("OPTIONAL · INTEL STASH · +%d INTEL" % GameData.SIDE_CACHE_INTEL), "the HUD lists the side task under the objective (%s)" % [line.text if line != null else "none"])
	var keys: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(keys.has(&"side"), "the minimap's key has the optional task while it is not done")
	run.player_pos = run.side_tasks[0].position
	run._update_side_tasks(GameData.SIDE_CACHE_SECONDS + 0.1)
	hud.refresh(run, null, 0.0)
	_check(line.text.begins_with("✓ INTEL STASH"), "a done side task shows a tick (%s)" % line.text)
	keys = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(keys.has(&"side"), "the key stays while other side tasks are left")
	var summary: Dictionary = IslandEndPanel.summary(run, RunContext.new(5))
	_check(summary["side"] == "1 / 3 optional done", "the end-of-island panel counts the side tasks (%s)" % summary["side"])
	hud.queue_free()
	var plain := Hud.new()
	root.add_child(plain)
	await process_frame
	plain.refresh(IslandRun.new(7), null, 0.0)
	_check(not (plain.get("_side_list") as Control).visible, "an island without side tasks shows no optional line")
	plain.queue_free()
	await process_frame


## Stage 3: the survivor gives a card to pick, the nest calls a horde peak when started and fills
## health and ammo when done; a main mission that plays the same mechanic leaves its side kind out.
func _test_survivor_and_nest(map: IslandMap) -> void:
	var run := _run_on(map)
	var survivor: SideTask = run.side_tasks.filter(func(t: SideTask) -> bool: return t.kind == &"survivor")[0]
	var nest: SideTask = run.side_tasks.filter(func(t: SideTask) -> bool: return t.kind == &"nest")[0]
	run.player_pos = survivor.position
	run._update_side_tasks(GameData.SIDE_SURVIVOR_SECONDS + 0.1)
	run._roll_cards_if_needed()
	_check(survivor.done and not run.card_choices.is_empty(), "a found survivor gives a card to pick")
	run.card_choices.clear()
	run.hp = 10.0
	run.player_pos = nest.position
	run._update_side_tasks(0.5)
	_check(nest.alarmed and run.director.phase == Director.Phase.PEAK, "starting the nest's charge calls a horde peak")
	run._update_side_tasks(GameData.SIDE_NEST_SECONDS)
	_check(nest.done and is_equal_approx(run.hp, run.max_hp), "a destroyed nest fills health (%.0f of %.0f)" % [run.hp, run.max_hp])
	var rescue := IslandRun.new(5, &"beach", map)
	rescue.set_mission(&"rescue")
	var nests := IslandRun.new(5, &"beach", map)
	nests.set_mission(&"nests")
	_check(not rescue.side_tasks.any(func(t: SideTask) -> bool: return t.kind == &"survivor") and rescue.side_tasks.size() == 2,
		"a Rescue island leaves the survivor side task out")
	_check(not nests.side_tasks.any(func(t: SideTask) -> bool: return t.kind == &"nest"), "a Nests island leaves the nest side task out")
