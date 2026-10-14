extends SceneTree
## Expedition runs (docs/design/BERLENGA_EXPEDITION.md): the run choice in
## the Armory, RunContext parts, the flow part -> camp -> part -> debrief,
## death -> debrief, the archipelago run unchanged and TEST ISLAND entries.
## The real part scenes may not be built: existing islands stand in for them.

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

enum Flow { BOAT, ISLAND, DEBRIEF, ARMORY, TITLE, CAMP }  # mirrors main.gd GameFlow

const STAND_INS: Array[String] = [
	"res://game/world/handmade/islands/beach_01.tscn",
	"res://game/world/handmade/islands/jungle_01.tscn",
	"res://game/world/handmade/islands/port_01.tscn",
	"res://game/world/handmade/islands/town_01.tscn",
]

var _failures: int = 0
var _checks: int = 0
var _main: Node


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("TEST FAIL: " + message)


func _settle() -> void:
	await process_frame
	await process_frame


func _current() -> Node:
	return _main.get("_current")


func _state() -> int:
	return int(_main.get("state"))


func _context() -> RunContext:
	return _main.get("context")


func _scene_path() -> String:
	var scene: PackedScene = _current().get("handmade_scene")
	return scene.resource_path if scene != null else ""


## Ends the island being played (as island.gd does when the run is over).
func _finish_island(won: bool, hp: float = -1.0) -> void:
	var run: IslandRun = _current().get("run")
	if hp > 0.0:
		run.hp = hp
	run.objective = IslandRun.Objective.WON if won else IslandRun.Objective.LOST
	_current().call("_finish")
	await _settle()


func _run_tests() -> void:
	var holdout: StringName = &"holdout" if GameData.MISSIONS.has(&"holdout") else &"defend"
	var missions: Array[StringName] = [&"rescue", &"activate", &"defend", holdout]
	var parts: Array = []
	for i in 4:
		parts.append({"name": "Stand-in %d" % (i + 1), "scene": STAND_INS[i], "mission": missions[i]})
	_context_tests(parts)
	Expeditions.stand_ins[&"berlenga"] = parts
	_check(Expeditions.available(&"berlenga"), "stand-ins make the expedition playable")
	await _menu_tests()
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _settle()
	var profile := MemoryProfile.new()
	_main.set("profile", profile)
	Profile.current = profile
	await _expedition_run(parts)
	await _expedition_death()
	await _archipelago_run()
	await _test_island_part(parts)
	await _between_islands_exit()
	_main.queue_free()
	await _settle()
	Expeditions.stand_ins.clear()
	await create_timer(0.1).timeout
	if _failures == 0:
		print("TEST: expedition OK (%d checks)" % _checks)
	quit(1 if _failures > 0 else 0)


func _between_islands_exit() -> void:
	for flow in [Flow.CAMP, Flow.BOAT]:
		for to_title in [false, true]:
			var profile := MemoryProfile.new()
			profile.intel = 100
			_main.set("profile", profile)
			Profile.current = profile
			var ctx := RunContext.new(5)
			if flow == Flow.CAMP:
				ctx.start_expedition(&"berlenga")
			ctx.advance()
			ctx.intel = 80
			ctx.time_alive = 90.0
			ctx.kills = 44
			ctx.lore_found = 1
			ctx.hp = 40.0
			ctx.island_log.append({"island": 1, "result": "cleared", "intel": 80})
			_main.set("context", ctx)
			_main.call("_go", flow)
			await _settle()
			var screen: Node = _current()
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.physical_keycode = KEY_ESCAPE
			event.pressed = true
			Input.parse_input_event(event)
			await _settle()
			var dialog: MenuDialog = screen.get("_exit_dialog")
			_check(is_instance_valid(dialog) and _context() == ctx and profile.intel == 100,
				"Escape at state %d opens choices without ending or banking the run" % flow)
			if not is_instance_valid(dialog):
				continue
			var consequences: Label = dialog.find_child("ExitConsequences", true, false)
			_check(consequences.text.contains("80 Intel"), "exit choices show the exact earned Intel to keep")
			screen.call("_land_now")
			_check(not bool(screen.get("_applied")) and ctx.hp == 40.0,
				"exit modal prevents deployment or supply application")
			var pick: Button = dialog.find_child("ReturnToTitle" if to_title else "ReturnToArmory", true, false)
			pick.pressed.emit()
			pick.pressed.emit()  # two same-frame clicks must emit only once
			await _settle()
			_check(_state() == (Flow.TITLE if to_title else Flow.ARMORY) and _context() == null,
				"leaving state %d reaches the requested menu and clears the active run" % flow)
			_check(profile.intel == 180 and profile.runs == 1 and profile.extractions == 0
				and profile.best_kills == 44 and profile.lore_pages == 1 and not ctx.won,
				"leaving keeps Intel and lore exactly once, without extraction bonus or a win")
			_main.call("_leave_between_islands", to_title)
			_check(profile.intel == 180 and profile.runs == 1, "stale exit callback cannot deposit the run twice")
	# No completed island: returning cancels setup without recording an empty run.
	var profile := MemoryProfile.new()
	_main.set("profile", profile)
	Profile.current = profile
	_main.set("context", RunContext.new(7))
	_main.call("_go", Flow.BOAT)
	await _settle()
	_current().call("_back")
	await _settle()
	var dialog: MenuDialog = _current().get("_exit_dialog")
	if is_instance_valid(dialog):
		(dialog.find_child("ReturnToArmory", true, false) as Button).pressed.emit()
		await _settle()
		_check(_state() == Flow.ARMORY and profile.runs == 0 and profile.intel == 0,
			"leaving before first landing returns to classes without recording an empty run")
	else:
		_check(false, "first-landing setup also has exit choices")


func _context_tests(parts: Array) -> void:
	Expeditions.stand_ins[&"berlenga"] = parts
	var ctx := RunContext.new(5)
	_check(not ctx.is_expedition() and ctx.island_count() == RunContext.ISLAND_COUNT and ctx.part().is_empty(), "a new context is an archipelago run")
	_check(not ctx.start_expedition(&"atlantis") and not ctx.is_expedition(), "an unknown expedition is refused")
	_check(ctx.start_expedition(&"berlenga"), "the expedition starts")
	_check(ctx.island_count() == 4 and ctx.island_index == 0 and not ctx.is_last_island(), "4 parts, first one")
	_check(ctx.biome == &"beach" and ctx.mission == &"rescue" and ctx.modifier == &"calm", "biome and mission from the part")
	_check(ctx.part_name() == "Stand-in 1" and ctx.part_scene() == STAND_INS[0], "part name and scene")
	ctx.advance()
	_check(ctx.island_index == 1 and ctx.mission == &"activate" and ctx.part_name() == "Stand-in 2", "advance moves to the next part")
	ctx.advance()
	ctx.advance()
	_check(ctx.is_last_island() and ctx.mission == parts[3]["mission"], "the fourth part is the last")
	Expeditions.stand_ins.clear()
	# The real data: four parts, in order, with the design's missions.
	var real: Array = Expeditions.parts(&"berlenga")
	_check(real.size() == 4 and real[0]["mission"] == &"rescue" and real[3]["mission"] == &"holdout", "Berlenga: 4 parts, rescue first, holdout last")


func _menu_tests() -> void:
	# START RUN asks which run; the dialog keeps focus inside it.
	var profile := MemoryProfile.new()
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	await _settle()
	var started: Array = []
	armory.connect("start_requested", func(id: StringName) -> void: started.append(id))
	armory.call("_start")
	await _settle()
	var dialog: MenuDialog = armory.get("_dialog")
	_check(is_instance_valid(dialog), "START RUN opens the run choice")
	var archipelago: Button = dialog.find_child("Run_archipelago", true, false)
	var berlenga: Button = dialog.find_child("Run_berlenga", true, false)
	_check(archipelago != null and berlenga != null and not berlenga.disabled, "both runs are offered")
	var focus := root.gui_get_focus_owner()
	_check(focus != null and dialog.is_ancestor_of(focus) and dialog.is_ancestor_of(focus.get_node(focus.focus_next)), "focus cycles inside the run choice")
	armory.call("_start")
	_check(started.is_empty(), "START RUN again does not start under the dialog")
	berlenga.pressed.emit()
	await _settle()
	_check(started == [&"berlenga"] and not is_instance_valid(dialog), "picking the expedition starts it")
	armory.call("_start")
	await _settle()
	(armory.get("_dialog") as MenuDialog).find_child("Run_archipelago", true, false).emit_signal("pressed")
	await _settle()
	_check(started.size() == 2 and started[1] == &"", "picking the archipelago starts it")
	# Without stand-ins and without built scenes the expedition is disabled.
	var saved: Array = Expeditions.stand_ins[&"berlenga"]
	Expeditions.stand_ins.clear()
	armory.call("_start")
	await _settle()
	dialog = armory.get("_dialog")
	berlenga = dialog.find_child("Run_berlenga", true, false)
	var built: bool = Expeditions.available(&"berlenga")
	_check(berlenga.disabled != built, "the expedition is disabled only while its parts are missing")
	dialog.close()
	Expeditions.stand_ins[&"berlenga"] = saved
	armory.queue_free()
	await _settle()


func _expedition_run(parts: Array) -> void:
	_current().emit_signal("play_requested")
	await _settle()
	_check(_state() == Flow.ARMORY, "deploy opens the armory")
	_current().call("_start_run", &"berlenga")
	await _settle()
	var ctx: RunContext = _context()
	_check(_state() == Flow.ISLAND, "an expedition lands straight on part 1 (no boat)")
	_check(ctx.is_expedition() and ctx.island_index == 0 and ctx.mission == &"rescue" and ctx.biome == &"beach", "part 1: its mission, beach biome")
	_check(_scene_path() == STAND_INS[0], "part 1 plays its scene (%s)" % _scene_path())
	# Progress made on part 1 (found by Codex: only HP was checked).
	var run1: IslandRun = _current().get("run")
	run1.level = 4
	run1.xp = 7
	run1.kills = 33
	run1.card_stacks = {&"carry_test": 2}
	var ammo1: PackedInt32Array = run1.ammo.duplicate()
	if not ammo1.is_empty():
		ammo1[0] = maxi(ammo1[0] - 3, 0)
		run1.ammo = ammo1.duplicate()
	await _finish_island(true, 42.0)
	_check(ctx.level == 4 and ctx.xp == 7 and ctx.kills == 33 and ctx.card_stacks.get(&"carry_test", 0) == 2 and ctx.ammo == ammo1, "level, XP, kills, cards and ammo carried over")
	_check(_state() == Flow.CAMP, "a won part leads to the camp")
	_check(ctx.island_index == 1 and ctx.mission == &"activate" and is_equal_approx(ctx.hp, 42.0), "the camp is for part 2, HP carried over")
	var camp: Node = _current()
	_check((camp.find_child("PartName", true, false) as Label).text == "STAND-IN 2", "the camp names the next part")
	_check(camp.find_child("Trail_1", true, false) != null and camp.find_child("Trail_4", true, false) != null, "the camp shows the 4 parts")
	# One screen, no supply modal: the first useful supply (Field Repairs,
	# HP is 42) starts selected and is applied on CONTINUE.
	_check(int(camp.get("_supply")) == 0 and camp.call("_can_land"), "the camp preselects Field Repairs when hurt")
	camp.call("_pick_route", 0)  # no routes on foot: ignored
	camp.call("_pick", 0)  # Field Repairs
	await _settle()
	_check(is_equal_approx(ctx.hp, 42.0), "the supply is not applied before CONTINUE")
	_check(root.gui_get_focus_owner() == camp.find_child("Deploy", true, false), "CONTINUE takes focus after the supply")
	camp.call("_land_now")
	_check(is_equal_approx(ctx.hp, minf(ctx.max_hp, 92.0)), "Field Repairs heals at the camp")
	await _settle()
	_check(_state() == Flow.ISLAND and _scene_path() == STAND_INS[1] and ctx.mission == &"activate", "part 2 plays with its mission")
	var run2: IslandRun = _current().get("run")
	_check(run2.level == 4 and run2.kills == 33 and run2.card_stacks.get(&"carry_test", 0) == 2, "part 2 starts with part 1's level, kills and cards")
	await _finish_island(true)
	# The camp counts down and goes on by itself, to the fixed next part.
	var camp3: Node = _current()
	_check(_state() == Flow.CAMP and (camp3.find_child("Heading", true, false) as Label).text == "NEXT PART IN 5…",
		"the camp counts down to the next part (%s)" % (camp3.find_child("Heading", true, false) as Label).text)
	camp3.call("tick_countdown", GameData.NEXT_ISLAND_COUNTDOWN)
	await _settle()
	_check(_state() == Flow.ISLAND and _scene_path() == STAND_INS[2] and ctx.mission == &"defend", "part 3 plays with its mission (auto-departed, fixed order)")
	await _finish_island(true)
	_check(_state() == Flow.CAMP and ctx.is_last_island(), "the camp before the last part")
	_check(String((_current().find_child("PartName", true, false) as Label).text) == "STAND-IN 4", "the last camp names the fort stand-in")
	_current().call("_pick", 0)
	_current().call("_land_now")
	await _settle()
	_check(_state() == Flow.ISLAND and _scene_path() == STAND_INS[3] and ctx.mission == parts[3]["mission"], "part 4 plays with its mission")
	var run: IslandRun = _current().get("run")
	run.objective = IslandRun.Objective.WON  # intel_earned() counts the win
	var intel_before: int = ctx.intel + run.intel_earned()
	await _finish_island(true)
	_check(_state() == Flow.DEBRIEF and ctx.won, "the last part won ends the run extracted")
	_check(ctx.intel == int(intel_before * GameData.EXTRACTION_INTEL_MULTIPLIER), "extraction multiplies the Intel")
	_check(ctx.island_log.size() == 4, "telemetry logs the 4 parts")
	_current().emit_signal("new_run_requested")
	await _settle()
	_check(_state() == Flow.ARMORY, "the debrief returns to the armory")


func _expedition_death() -> void:
	_current().call("_start_run", &"berlenga")
	await _settle()
	await _finish_island(true)
	_current().call("_pick", 0)
	_current().call("_land_now")
	await _settle()
	_check(_state() == Flow.ISLAND and _context().island_index == 1, "a new expedition reaches part 2")
	await _finish_island(false)
	_check(_state() == Flow.DEBRIEF and not _context().won, "death in a part ends the run in the debrief")
	_current().emit_signal("new_run_requested")
	await _settle()


func _archipelago_run() -> void:
	_current().call("_start_run", &"")
	await _settle()
	var ctx: RunContext = _context()
	_check(_state() == Flow.BOAT and not ctx.is_expedition() and ctx.island_count() == RunContext.ISLAND_COUNT, "the archipelago run starts on the boat")
	_current().call("_pick", 0)
	_current().call("_pick_route", 0)
	_current().emit_signal("land_requested")
	await _settle()
	_check(_state() == Flow.ISLAND and _current().get("handmade_scene") == null, "the archipelago island is picked by the run, as before")
	await _finish_island(true)
	_check(_state() == Flow.BOAT and ctx.island_index == 1, "a cleared island returns to the boat")
	# Between islands: no route choice, a countdown, then it departs alone.
	var boat2: Node = _current()
	var route_biome: StringName = (boat2.get("_route_biomes") as Array)[0]
	var route_mission: StringName = (boat2.get("_route_missions") as Array)[0]
	_check(boat2.find_child("Route_2", true, false) == null and (boat2.find_child("Heading", true, false) as Label).text == "NEXT ISLAND IN 5…",
		"island 2: one drawn route and NEXT ISLAND IN 5…")
	boat2.call("tick_countdown", GameData.NEXT_ISLAND_COUNTDOWN)
	await _settle()
	_check(_state() == Flow.ISLAND and ctx.biome == route_biome and ctx.mission == route_mission,
		"the countdown departs to the drawn route through the loading screen (%s, %s)" % [route_biome, route_mission])
	await _finish_island(false)
	_check(_state() == Flow.DEBRIEF, "death on the archipelago ends in the debrief")


func _test_island_part(parts: Array) -> void:
	# TEST ISLAND lists the expedition parts; a part brings its own mission.
	var holder := Control.new()
	root.add_child(holder)
	var picked: Array = []
	var dialog: MenuDialog = MenuDialog.test_island(holder, func(path: String, mission: StringName) -> void: picked.append([path, mission]))
	await _settle()
	var b4: Button = dialog.find_child("Expedition_berlenga_4", true, false)
	_check(dialog.find_child("Expedition_berlenga_1", true, false) != null and b4 != null, "TEST ISLAND lists the expedition parts")
	_check(b4 != null and b4.text.begins_with("BERLENGA 4 / STAND-IN 4"), "a part is labelled with its number and name (%s)" % (b4.text if b4 else ""))
	var mission: OptionButton = dialog.find_child("Mission", true, false)
	mission.select(0)
	b4.pressed.emit()
	await _settle()
	_check(picked.size() == 1 and picked[0][0] == STAND_INS[3] and picked[0][1] == parts[3]["mission"], "a part forces its own mission")
	holder.queue_free()
	_current().emit_signal("new_run_requested")
	await _settle()
	_current().emit_signal("back_requested")
	await _settle()
	_main.call("_test_island", STAND_INS[3], parts[3]["mission"])
	await _settle()
	var ctx: RunContext = _context()
	_check(_state() == Flow.ISLAND and _scene_path() == STAND_INS[3], "the tested part is played")
	_check(ctx.expedition == &"berlenga" and ctx.island_index == 3 and ctx.is_last_island() and ctx.biome == &"beach", "a tested part plays as that part (last, beach)")
	await _finish_island(true)
	_check(_state() == Flow.TITLE, "a tested part returns to the title")
