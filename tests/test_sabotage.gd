extends SceneTree
## Sabotage (docs/design/OBJECTIVES_PROPOSAL.md, step 6): cut the power at a switch (hold, leaving pauses it, a spike
## on the first step in), then plant a charge on each machine (only once the
## power is cut; hold each, a spike each), then the fuse burns down while
## the player gets out: a player still in the blast takes heavy damage (not
## a kill from full health). The extraction opens with the last charge, at
## the map's ExfilPoint when it has one, else the boat.
## Also: data, PowerSwitch/Machine_*/ExfilPoint markers and the fallback
## spots (switch deep in the island, machines 30-60 m from it, spread),
## death and redeploy, the boat draw (weight 3 on the Industrial Port, no
## repeat), no preferred island for Sabotage, a bot run, the Island scene in
## the three cameras.
## Run: godot --headless --path . --script res://tests/test_sabotage.gd

const DT: float = 1.0 / 60.0

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _done: bool = false


func _initialize() -> void:
	GameInput.setup()
	create_timer(900.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "sabotage tests finished in time")
			_finish())
	_test_data()
	_test_fallback_spots()
	_test_handmade_islands()
	_test_markers()
	_test_stage_order()
	_test_power_hold()
	_test_charges()
	_test_fuse_and_blast()
	_test_exfil()
	_test_death_and_redeploy()
	_test_draw()
	_test_island_preference()
	_test_bot()
	_test_scene.call_deferred()


func _finish() -> void:
	_done = true
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		print("TEST FAIL: " + what)
		_failures += 1


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## A run on a generated island with no enemies spawning (rules only).
func _quiet_run(rng_seed: int, biome: StringName = &"beach", map: IslandMap = null) -> IslandRun:
	var run := IslandRun.new(rng_seed, biome, map)
	run.director.max_alive = 0
	run.set_mission(&"sabotage")
	return run


## The director stays relaxed until something calls a spike.
func _relax(run: IslandRun) -> void:
	run.director.phase = Director.Phase.RELAX
	run.director.phase_time = 1000.0


func _step(run: IslandRun, n: int = 1, move: Vector2 = Vector2.ZERO) -> void:
	for k in n:
		run.step(DT, move, Vector3(0, 0, -1), false)


## Teleports to the switch and holds it until the power is cut.
func _cut_power(run: IslandRun) -> void:
	run.player_pos = run.power_pos
	_step(run, int((IslandRun.power_seconds() + 0.1) / DT))


## Teleports to charge `k` and plants it.
func _plant(run: IslandRun, k: int) -> void:
	run.player_pos = run.charge_pos[k]
	_step(run, int((IslandRun.charge_seconds() + 0.1) / DT))


func _test_data() -> void:
	var m: Dictionary = GameData.MISSIONS.get(&"sabotage", {})
	_check(not m.is_empty() and m["name"] == "Sabotage" and int(m["points"]) == 2 and float(m["seconds"]) > 0.0
		and float(m["radius"]) > 0.0 and float(m["spike_seconds"]) > 0.0 and float(m["power_seconds"]) > 0.0
		and float(m["fuse_seconds"]) > 0.0 and float(m["blast_radius"]) > 0.0 and float(m["blast_damage"]) > 0.0
		and float(m["blast_damage"]) < 1.0,
		"sabotage.tres: power %.0f s at %.0f m (spike %.0f s), %d charges %.0f s at %.0f m (spike %.0f s), fuse %.0f s, blast %.0f m, %.0f%% HP" % [
		float(m.get("power_seconds", 0)), float(m.get("power_radius", 0)), float(m.get("power_spike_seconds", 0)),
		int(m.get("points", 0)), float(m.get("seconds", 0)), float(m.get("radius", 0)), float(m.get("spike_seconds", 0)),
		float(m.get("fuse_seconds", 0)), float(m.get("blast_radius", 0)), 100.0 * float(m.get("blast_damage", 0))])
	_check(GameData.ROUTE_MISSIONS.has(&"sabotage") and GameData.ROUTE_MISSIONS.find(&"sabotage") == GameData.ROUTE_MISSIONS.find(&"signals") + 1,
		"Sabotage is offered on archipelago routes (after Light the Signals)")
	_check(IslandRun.charge_count_wanted() == 2 and IslandRun.charge_seconds() == float(m.get("seconds", 0))
		and IslandRun.charge_radius() == float(m.get("radius", 0)) and IslandRun.power_seconds() == float(m.get("power_seconds", 0))
		and IslandRun.power_radius() == float(m.get("power_radius", 0)) and IslandRun.fuse_seconds() == float(m.get("fuse_seconds", 0))
		and IslandRun.blast_radius() == float(m.get("blast_radius", 0)) and IslandRun.blast_damage() == float(m.get("blast_damage", 0)),
		"the run reads its numbers from the data")
	_check((m.get("preferred_islands", []) as Array).is_empty(), "Sabotage has no preferred island (Hashima was removed)")
	var cues: bool = true
	for cue: StringName in [&"land_sabotage", &"power_cut", &"charge_planted", &"charges_set", &"sabotage_blast"]:
		cues = cues and Story.RADIO.has(cue)
	_check(cues, "radio lines for landing, the power cut, each charge, the fuse and the blast")
	_check(Briefing.ADVICE.has(&"sabotage"), "briefing advice for Sabotage")


## The switch reachable, off the boat; every machine reachable, the
## spacing kept; same seed, same spots.
func _check_spots(map: IslandMap, sw: Vector3, machines: Array[Vector3], label: String) -> Array:
	var f: FlowField = map.field
	var saved: int = f.max_distance
	f.max_distance = 0
	f.compute_now(f.world_to_cell(map.player_start))
	var ok: bool = sw.x >= 0.0 and f.distance_at(sw) < FlowField.UNREACHABLE and _flat_dist(sw, map.boat) >= IslandMap.HOLD_MIN_FROM_BOAT
	var bad: int = 0
	var in_band: int = 0
	var dists := PackedStringArray()
	for k in machines.size():
		var d: float = _flat_dist(machines[k], sw)
		dists.append("%.0f m" % d)
		if f.distance_at(machines[k]) >= FlowField.UNREACHABLE:
			bad += 1
		in_band += 1 if d >= IslandMap.MACHINE_MIN and d <= IslandMap.MACHINE_MAX else 0
	var apart: float = _flat_dist(machines[0], machines[1]) if machines.size() > 1 else INF
	f.max_distance = saved
	_check(ok and machines.size() == 2 and bad == 0 and apart >= IslandMap.MACHINE_APART * 0.5,
		"%s: switch reachable %d m from the start, %.0f m from the boat; machines reachable at %s from it, %.0f m apart" % [label,
		f.distance_at(sw), _flat_dist(sw, map.boat), ", ".join(dists), apart])
	return [in_band, machines.size()]


func _test_fallback_spots() -> void:
	var band: int = 0
	var total: int = 0
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		for s in [3, 77]:
			var a := _quiet_run(s, biome)
			var b := _quiet_run(s, biome)
			_check(a.power_pos == b.power_pos and a.charge_pos == b.charge_pos and not a.has_exfil(),
				"%s seed %d: same seed, same switch and machines; no exfil marker: the boat" % [biome, s])
			var r: Array = _check_spots(a.map, a.power_pos, a.charge_pos, "%s seed %d" % [biome, s])
			band += r[0]
			total += r[1]
			var lava: int = 0
			for p in a.charge_pos + [a.power_pos]:
				for k in a.map.lava.size():
					if _flat_dist(p, a.map.lava[k]) < a.map.lava_radius[k] + 1.0:
						lava += 1
			_check(lava == 0, "%s seed %d: no switch or machine in lava" % [biome, s])
			# Far from the boat: deeper (walking) than most candidate spots.
			var far: bool = _flat_dist(a.power_pos, a.map.boat) >= IslandMap.HOLD_MIN_FROM_BOAT
			_check(far, "%s seed %d: the switch is far from the boat (%.0f m)" % [biome, s, _flat_dist(a.power_pos, a.map.boat)])
	_check(band >= total * 0.9, "generated islands: %d / %d machines 30-60 m from their switch" % [band, total])
	var x := _quiet_run(3)
	var y := _quiet_run(4)
	_check(x.power_pos != y.power_pos or x.charge_pos != y.charge_pos, "another seed, other spots")


## The archipelago's hand-made islands without Sabotage markers: the
## fallback must work on their real grids.
func _test_handmade_islands() -> void:
	for path in HandmadeIsland.island_paths():
		var scene: PackedScene = load(path)
		if scene == null:
			_check(false, "%s loads" % path)
			continue
		var hm: HandmadeIsland = scene.instantiate()
		root.add_child(hm)
		var map: IslandMap = hm.build_map()
		hm.free()
		var sw: Vector3 = IslandMap.pick_power_switch(map, 9)
		_check_spots(map, sw, IslandMap.pick_machine_points(map, sw, 2, 9), path.get_file())


func _test_markers() -> void:
	var hm := HandmadeIsland.new()
	hm.size = 120
	var markers := Node3D.new()
	markers.name = "Markers"
	hm.add_child(markers)
	var spots: Dictionary = {"Boat": Vector3(60, 0, 110), "PlayerStart": Vector3(60, 0, 104),
		"PowerSwitch": Vector3(60, 0, 30), "Machine_2": Vector3(30, 0, 70), "Machine_1": Vector3(90, 0, 70),
		"ExfilPoint": Vector3(20, 0, 100)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.position = spots[n]
		markers.add_child(m)
	root.add_child(hm)
	hm.mission = &"sabotage"
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	var want: Array[Vector3] = [Vector3(90.5, 0, 70.5), Vector3(30.5, 0, 70.5)]
	_check(map.power_switch == Vector3(60.5, 0, 30.5) and map.machine_points == want and map.exfil == Vector3(20.5, 0, 100.5),
		"PowerSwitch, Machine_1, _2 in number order and ExfilPoint read (%s, %s, %s)" % [map.power_switch, map.machine_points, map.exfil])
	_check(problems.is_empty(), "markers reachable, no problems (%s)" % [problems])
	var run := _quiet_run(1, &"beach", map)
	_check(run.power_pos == map.power_switch and run.charge_pos == want and run.has_exfil() and run.extraction_point() == map.exfil
		and run.extraction_name() == "Exfil", "the run uses the markers; the extraction is the ExfilPoint")
	hm.play_area = PackedVector2Array([Vector2(10, 40), Vector2(110, 40), Vector2(110, 118), Vector2(10, 118)])
	problems.clear()
	hm.build_map(problems)
	var reported: bool = false
	for p in problems:
		if "PowerSwitch" in p and "(60, 30)" in p:
			reported = true
	_check(reported, "an unreachable PowerSwitch is reported (%s)" % [problems])
	hm.queue_free()
	_check(HandmadeIsland.marker_number("Machine_3", "Machine") == 3, "Machine_* numbers")


## Charges cannot be planted before the power is cut; the site follows the
## stages; the extraction stays shut.
func _test_stage_order() -> void:
	var run := _quiet_run(11)
	_relax(run)
	_check(run.sabotage_phase == IslandRun.SAB_POWER and run.site == run.power_pos and not run.power_cut()
		and run.objective_text().begins_with("Cut the power"), "landing: cut the power first ('%s')" % run.objective_text())
	run.player_pos = run.charge_pos[0]
	_step(run, int(2.0 / DT))
	_check(run.charge_progress[0] == 0.0 and not run.charge_started[0] and run.director.phase == Director.Phase.RELAX,
		"at a machine with the power on: nothing happens, no spike")
	run.player_pos = run.map.boat
	_step(run, 10)
	_check(run.objective == IslandRun.Objective.GENERATORS, "no extraction at the boat before the job")
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"power") and legend.has(&"charge") and not legend.has(&"charge_set"), "minimap key: SWITCH and MACHINE")


func _test_power_hold() -> void:
	var run := _quiet_run(12)
	_relax(run)
	run.player_pos = run.power_pos + Vector3(IslandRun.power_radius() - 0.5, 0, 0)
	_step(run, int(3.0 / DT))
	_check(absf(run.power_progress - 3.0) < 0.05 and run.power_started and run.director.phase == Director.Phase.PEAK,
		"in the switch radius the cut runs (%.2f s) and calls a spike" % run.power_progress)
	run.player_pos = run.power_pos + Vector3(IslandRun.power_radius() + 3.0, 0, 0)
	var p: float = run.power_progress
	_step(run, int(2.0 / DT))
	_check(run.power_progress == p, "leaving pauses the cut (kept %.2f s)" % p)
	_relax(run)
	run.player_pos = run.power_pos
	var hp0: float = run.hp
	for k in int(1.0 / DT):
		run._take_player_damage(0.2)
		_step(run)
	_check(run.power_progress > p + 0.9 and run.hp < hp0 and run.director.phase == Director.Phase.RELAX,
		"damage does not interrupt it; back in: no second spike (%.2f s)" % run.power_progress)
	var ammo0: int = run.ammo[0]
	_step(run, int((IslandRun.power_seconds() - run.power_progress + 0.1) / DT))
	_check(run.power_cut() and run.sabotage_phase == IslandRun.SAB_CHARGES and run.radio.has(&"power_cut")
		and run.site == run.charge_pos[run.nearest_unplanted()] and run.objective == IslandRun.Objective.GENERATORS,
		"held: the power is cut, the machines are next")
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(not legend.has(&"power") and legend.has(&"charge"), "minimap key: the switch goes, the machines stay")
	_check(run.ammo[0] >= ammo0, "a third of the ammo back on the cut")


func _test_charges() -> void:
	var run := _quiet_run(13)
	_cut_power(run)
	_relax(run)
	# Any order: start with the second machine.
	run.player_pos = run.charge_pos[1]
	_step(run, int(2.0 / DT))
	_check(absf(run.charge_progress[1] - 2.0) < 0.05 and run.charge_started[1] and run.director.phase == Director.Phase.PEAK,
		"planting runs at any machine (%.2f s) with a spike" % run.charge_progress[1])
	run.player_pos = run.charge_pos[1] + Vector3(IslandRun.charge_radius() + 3.0, 0, 0)
	var p: float = run.charge_progress[1]
	_step(run, int(1.0 / DT))
	_check(run.charge_progress[1] == p and not run.charge_planted[1], "leaving pauses that charge")
	_plant(run, 1)
	_check(run.charge_planted[1] and run.charges_planted() == 1 and run.radio.has(&"charge_planted")
		and run.site == run.charge_pos[0] and run.objective == IslandRun.Objective.GENERATORS,
		"charge 2 planted first; charge 1 is next, no extraction yet")
	_relax(run)
	run.player_pos = run.charge_pos[0]
	_step(run)
	_check(run.director.phase == Director.Phase.PEAK, "each charge calls its own spike")
	_plant(run, 0)
	_check(run.sabotage_phase == IslandRun.SAB_FUSE and run.objective == IslandRun.Objective.RETURN_TO_BOAT
		and run.radio.has(&"charges_set") and run.fuse_left > IslandRun.fuse_seconds() - 1.0
		and run.objective_text().begins_with("Get clear"),
		"the last charge lights the fuse (%.1f s) and opens the extraction ('%s')" % [run.fuse_left, run.objective_text()])
	var intel: int = run.intel_earned()
	_check(intel >= 45, "Intel: 15 for the cut and 15 per charge (%d)" % intel)


func _test_fuse_and_blast() -> void:
	# Caught in the blast: heavy damage, not a kill from full health; the
	# enemies around the charges die.
	var run := _quiet_run(14)
	_cut_power(run)
	_plant(run, 0)
	_plant(run, 1)
	var e: int = run.horde.add(run.charge_pos[0] + Vector3(2, 0, 0), GameData.EnemyKind.WALKER, run.rng)
	var kills0: int = run.kills
	run.player_pos = run.charge_pos[1]
	run.hp = run.max_hp
	var t0: float = run.fuse_left
	_step(run, int(5.0 / DT))
	_check(absf(t0 - run.fuse_left - 5.0) < 0.05 and run.sabotage_phase == IslandRun.SAB_FUSE,
		"the fuse counts down (%.1f s left)" % run.fuse_left)
	run.hp = run.max_hp
	run.fuse_left = DT * 0.5
	_step(run)
	var lost: float = run.max_hp - run.hp
	_check(run.sabotage_phase == IslandRun.SAB_BLOWN and run.blast_hit and absf(lost - run.max_hp * IslandRun.blast_damage()) < 0.5
		and run.hp > 0.0 and not run.is_over() and run.radio.has(&"sabotage_blast") and run.explosions.size() >= 2,
		"caught in the blast: %.0f HP lost of %.0f, alive, explosions at the charges" % [lost, run.max_hp])
	_check(run.kills > kills0 or run.horde.count == 0, "the blast kills the enemies by the charges (%d kills)" % (run.kills - kills0))
	_step(run, 10)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "after the blast the way out is still open")
	run.player_pos = run.extraction_point()
	_step(run)
	_check(run.objective == IslandRun.Objective.WON, "and the extraction wins")
	# Clear of it: no damage. Shield first.
	var clear := _quiet_run(15)
	_cut_power(clear)
	_plant(clear, 0)
	_plant(clear, 1)
	# Back at the switch (30-60 m from the machines): clear of the blast.
	clear.player_pos = clear.power_pos
	var hp_clear: float = clear.hp
	clear.fuse_left = DT * 0.5
	_step(clear)
	_check(not clear.in_blast(clear.power_pos) and clear.sabotage_phase == IslandRun.SAB_BLOWN and not clear.blast_hit
		and clear.hp >= hp_clear and clear.objective == IslandRun.Objective.RETURN_TO_BOAT,
		"clear of the blast when it blows: no damage, still heading out")
	var sh := _quiet_run(16)
	_cut_power(sh)
	_plant(sh, 0)
	_plant(sh, 1)
	sh.player_pos = sh.charge_pos[0]
	sh.hp = sh.max_hp
	sh.add_shield(30.0)
	var with_shield: float = sh.shield
	sh.fuse_left = DT * 0.5
	_step(sh)
	_check(sh.blast_hit and sh.shield == 0.0 and absf((sh.max_hp - sh.hp) - (sh.max_hp * IslandRun.blast_damage() - with_shield)) < 0.5,
		"the shield takes the blast first (%.0f shield, %.0f HP lost)" % [with_shield, sh.max_hp - sh.hp])
	# Low on health in the blast: the blast can finish you (heavy damage).
	var low := _quiet_run(17)
	_cut_power(low)
	_plant(low, 0)
	_plant(low, 1)
	low.player_pos = low.charge_pos[0]
	low.hp = 10.0
	low.fuse_left = DT * 0.5
	_step(low)
	_check(low.objective == IslandRun.Objective.LOST, "at 10 HP the blast kills: dying ends the island as always")
	# Out before the blast: it goes off behind you, no damage, the island is won.
	var out := _quiet_run(18)
	_cut_power(out)
	_plant(out, 0)
	_plant(out, 1)
	out.player_pos = out.extraction_point()
	_step(out)
	_check(out.objective == IslandRun.Objective.WON and out.sabotage_phase == IslandRun.SAB_BLOWN and not out.blast_hit and out.hp > 0.0,
		"at the boat before the blast: won, the charges blow behind you")


## ExfilPoint: the run ends there, not at the boat; an expedition's Exit
## still wins over it.
func _test_exfil() -> void:
	var map := IslandMap.build(21, &"beach")
	var plain := _quiet_run(21, &"beach", map)
	# A reachable exfil far from the boat: the switch itself.
	map.exfil = plain.power_pos
	var run := _quiet_run(21, &"beach", map)
	_check(run.has_exfil() and run.extraction_point() == map.exfil and run.extraction_name() == "Exfil", "ExfilPoint: the extraction point")
	_cut_power(run)
	_plant(run, 0)
	_plant(run, 1)
	run.player_pos = run.map.boat
	_step(run, 5)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "the boat does not end a Sabotage with an exfil point")
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"exfil"), "minimap key: EXFIL")
	run.player_pos = map.exfil
	_step(run)
	_check(run.objective == IslandRun.Objective.WON, "the exfil point does")
	var other := IslandRun.new(21, &"beach", map)
	other.set_mission(&"activate")
	_check(not other.has_exfil() and other.extraction_point() == map.boat, "other missions ignore the ExfilPoint")
	map.exit = map.boat + Vector3(-3, 0, -3)
	var part := _quiet_run(21, &"beach", map)
	_check(part.has_exit() and not part.has_exfil() and part.extraction_point() == map.exit, "an expedition Exit wins over the ExfilPoint")


func _test_death_and_redeploy() -> void:
	var ctx := RunContext.new(8)
	ctx.biome = &"port"
	ctx.mission = &"sabotage"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	_cut_power(run)
	run.player_pos = run.charge_pos[0]
	_step(run, int(2.0 / DT))
	_check(run.power_cut() and run.charge_progress[0] > 0.0, "power cut, a charge half planted")
	run.hp = 0.0
	_step(run)
	_check(run.objective == IslandRun.Objective.LOST and run.is_over(), "dying ends the island")
	var again := IslandRun.new(ctx.island_seed(), ctx.biome)
	again.load_context(ctx)
	var fresh: bool = again.sabotage_phase == IslandRun.SAB_POWER and again.power_progress == 0.0 and not again.power_started \
		and again.charges_planted() == 0 and again.fuse_left == 0.0 and not again.blast_hit
	for k in again.charge_pos.size():
		fresh = fresh and again.charge_progress[k] == 0.0 and not again.charge_started[k]
	_check(fresh and again.power_pos == run.power_pos and again.charge_pos == run.charge_pos,
		"a redeployed island starts fresh, same switch and machines")
	_cut_power(again)
	_plant(again, 0)
	_plant(again, 1)
	again.set_mission(&"activate")
	_check(again.charge_pos.is_empty() and again.sabotage_phase == IslandRun.SAB_POWER and again.fuse_left == 0.0
		and not again.has_exfil(), "switching mission clears the sabotage, fuse included")


func _test_draw() -> void:
	var weights_ok: bool = GameData.mission_weight(&"sabotage", &"port") == 3
	for biome: StringName in [&"beach", &"town", &"jungle", &"volcano"]:
		weights_ok = weights_ok and GameData.mission_weight(&"sabotage", biome) == 1
	_check(weights_ok, "weights: Sabotage weighs 3 on the Industrial Port, 1 elsewhere")
	_check(not GameData.route_missions_after(&"sabotage").has(&"sabotage"), "never Sabotage twice in a row")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1357
	var beach: int = 0
	var port: int = 0
	var repeats: int = 0
	var n: int = 4000
	for k in n:
		if GameData.pick_route_mission(rng, &"", &"beach") == &"sabotage":
			beach += 1
		if GameData.pick_route_mission(rng, &"", &"port") == &"sabotage":
			port += 1
		if GameData.pick_route_mission(rng, &"sabotage", &"port") == &"sabotage":
			repeats += 1
	var want_beach: float = GameData.mission_share(&"sabotage", &"beach")
	var want_port: float = GameData.mission_share(&"sabotage", &"port")
	_check(absf(want_port - 3.0 / 12.0) < 0.001 and absf(want_beach - 1.0 / 12.0) < 0.001,
		"shares: Port %.1f%% (3 of 12), Beach %.1f%% (1 of 12)" % [100.0 * want_port, 100.0 * want_beach])
	_check(absf(beach / float(n) - want_beach) < 0.03 and absf(port / float(n) - want_port) < 0.03,
		"draw shares: Beach %.0f%% (expected %.0f%%), Port %.0f%% (expected %.0f%%)" % [100.0 * beach / n, 100.0 * want_beach, 100.0 * port / n, 100.0 * want_port])
	_check(repeats == 0, "no repeat")
	var shares := PackedStringArray()
	for biome: StringName in GameData.ISLAND_BIOMES + [&"volcano"]:
		var row := PackedStringArray()
		for id: StringName in GameData.ROUTE_MISSIONS:
			row.append("%s %.1f%%" % [id, 100.0 * GameData.mission_share(id, biome)])
		shares.append("%s: %s" % [biome, ", ".join(row)])
	print("  (first-island shares)\n    " + "\n    ".join(shares))
	var boat_script: Script = load("res://game/states/boat.gd")
	var deterministic: bool = true
	var draws: int = 0
	var repeats_boat: int = 0
	var on_port: int = 0
	var sabotage_port: int = 0
	for s in range(1, 61):
		for prev: StringName in GameData.ROUTE_MISSIONS:
			var first: Array = _boat_routes(boat_script, s, prev)
			if first != _boat_routes(boat_script, s, prev):
				deterministic = false
			for i in 2:
				var m: StringName = first[0][i]
				draws += 1
				if GameData.mission_family(m) == GameData.mission_family(prev):
					repeats_boat += 1
				if first[1][i] == &"port":
					on_port += 1
					sabotage_port += 1 if m == &"sabotage" else 0
	_check(deterministic and repeats_boat == 0 and sabotage_port > 0,
		"boat routes: %d draws, deterministic, %d repeats, Sabotage on %d of %d Port routes" % [draws, repeats_boat, sabotage_port, on_port])


## [missions, biomes] of the two routes the boat draws for seed `s` after `prev`.
func _boat_routes(boat_script: Script, s: int, prev: StringName) -> Array:
	var ctx := RunContext.new(s)
	ctx.island_index = 1
	ctx.mission = prev
	var boat := Control.new()
	boat.set_script(boat_script)
	boat.set("context", ctx)
	(boat.get("_rng") as RandomNumberGenerator).seed = ctx.island_seed() + 1
	boat.call("_make_routes")
	var out: Array = [(boat.get("_route_missions") as Array).duplicate(), (boat.get("_route_biomes") as Array).duplicate()]
	boat.free()
	return out


## Sabotage has no preferred island any more: on the Port every hand-made
## island (or a generated one) is allowed, like the other missions.
func _test_island_preference() -> void:
	var port: PackedStringArray = HandmadeIsland.island_paths(&"port")
	_check(HandmadeIsland.preferred_paths(port, &"sabotage") == port, "Sabotage on the Port: every Port island (%s)" % [port])
	_check(HandmadeIsland.preferred_paths(port, &"activate") == port and HandmadeIsland.preferred_paths(port, &"") == port,
		"other missions: every Port island")
	var beach: PackedStringArray = HandmadeIsland.island_paths(&"beach")
	_check(HandmadeIsland.preferred_paths(beach, &"sabotage") == beach, "Sabotage elsewhere: that biome's islands, unchanged")


## A bot walks to each goal (the switch, then the nearest machine) and
## stands there, then heads out (the soak test's navigation; invincible:
## this checks completability and the pacing with the horde).
func _test_bot() -> void:
	for s in [404, 505, 606]:
		var ctx := RunContext.new(s)
		ctx.threat = 2
		ctx.mission = &"sabotage"
		ctx.biome = [&"port", &"beach", &"town"][[404, 505, 606].find(s)]
		var run := IslandRun.new(ctx.island_seed(), ctx.biome)
		run.load_context(ctx)
		_bot(run, "bot seed %d (%s)" % [s, ctx.biome])


func _bot(run: IslandRun, label: String) -> void:
	var nav := FlowField.new(run.field.width, run.field.height)
	nav.blocked = run.field.blocked
	var goal := Vector3.INF
	var steps: int = 0
	var peak_enemies: int = 0
	var cut_at: float = -1.0
	var set_at: float = -1.0
	var blast_at: float = -1.0
	var in_blast: bool = false
	while not run.is_over() and steps < int(900.0 / DT):
		steps += 1
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.hp = 10000.0
		var move := Vector2.ZERO
		var g: Vector3 = run.site if run.objective == IslandRun.Objective.GENERATORS else run.extraction_point()
		g = Vector3(floorf(g.x) + 0.5, 0, floorf(g.z) + 0.5)
		if g != goal:
			goal = g
			nav.compute_now(nav.world_to_cell(goal))
		var stp: Vector2 = nav.direction_at(run.player_pos)
		if stp != Vector2.ZERO:
			var c := Vector2(floori(run.player_pos.x) + stp.x + 0.5, floori(run.player_pos.z) + stp.y + 0.5)
			move = (c - Vector2(run.player_pos.x, run.player_pos.z)).normalized()
		elif run.player_pos.distance_to(goal) > 0.5:
			move = Vector2(goal.x - run.player_pos.x, goal.z - run.player_pos.z).normalized()
		var close: PackedInt32Array = run.horde.query_radius(run.player_pos, 20.0)
		var aim := Vector3(move.x, 0, move.y)
		if close.size() > 0:
			aim = run.horde.positions[close[0]] - run.player_pos
		var was: int = run.sabotage_phase
		run.step(DT, move, aim, close.size() > 10)
		var t: float = run.time_alive - run.landed_time
		if was == IslandRun.SAB_POWER and run.sabotage_phase != IslandRun.SAB_POWER:
			cut_at = t
		if was == IslandRun.SAB_CHARGES and run.sabotage_phase >= IslandRun.SAB_FUSE:
			set_at = t
		if was == IslandRun.SAB_FUSE and run.sabotage_phase == IslandRun.SAB_BLOWN and run.objective != IslandRun.Objective.WON:
			blast_at = t  # (it also blows when the player gets out first: not counted here)
			in_blast = run.blast_hit
		peak_enemies = maxi(peak_enemies, run.horde.count)
	_check(run.objective == IslandRun.Objective.WON and run.charges_planted() == run.charge_pos.size(),
		"%s: %s in %.0f s; power cut at %.0f s, charges set at %.0f s, blast at %s (%s); %d kills, up to %d enemies alive, Intel %d" % [label,
		run.objective_text(), run.time_alive - run.landed_time, cut_at, set_at,
		"%.0f s" % blast_at if blast_at >= 0.0 else "the extraction (out before the fuse ran out)", "caught" if in_blast else "clear",
		run.kills, peak_enemies, run.intel_earned()])


## The Island scene with Sabotage, in each camera mode: the switch and the
## machines are built, the machines' lights are on while the line is live;
## first person cuts the power through the scene's own loop (the lights
## die), third person plants a charge, the fixed camera the last one (the
## fuse: blast rings, HUD countdown), then the blast (machines gone, camera
## shake).
func _test_scene() -> void:
	var profile := MemoryProfile.new()
	var ctx := RunContext.new(5)
	ctx.mission = &"sabotage"
	ctx.biome = &"beach"
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	island.set("context", ctx)
	root.add_child(island)
	for i in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	var machines: Array = island.get("_machines")
	var lights: Array = island.get("_machine_lights")
	_check(island.get("_power_switch") != null and machines.size() == 2 and lights.size() == 2,
		"the scene builds the switch and 2 machines")
	await physics_frame
	await process_frame
	_check((lights[0] as OmniLight3D).is_visible_in_tree() and (lights[1] as OmniLight3D).is_visible_in_tree(),
		"the machines' lamps are lit while the power is on")
	var hud: Hud = island.get("hud")
	var objective: Label = hud.get("_objective")
	var marker: Label = hud.get("_marker")
	var minimap: Minimap = hud.get("_minimap")
	_check(objective.text == "CUT THE POWER", "HUD objective '%s'" % objective.text)
	var modes: Array = [Profile.CameraMode.FIRST_PERSON, Profile.CameraMode.THIRD_PERSON, Profile.CameraMode.FIXED]
	for k in modes.size():
		var mode_name: String = Profile.CAMERA_MODE_NAMES[modes[k]]
		island.call("_set_camera_mode", modes[k], false)
		var at: Vector3 = run.power_pos if k == 0 else run.charge_pos[k - 1]
		run.player_pos = at
		var to: Vector3 = at - run.map.player_start
		island.set("_tp_yaw", atan2(-to.x, -to.z))
		run.facing = Vector3(to.x, 0, to.z).normalized() if to.length() > 0.1 else Vector3(0, 0, -1)
		for f in 30:
			await physics_frame
			await process_frame
		if k == 0:
			var fill: Node3D = island.get("_power_fill")
			_check(run.power_progress > 0.0 and marker.text.begins_with("CUTTING POWER ·") and fill.visible
				and (island.get("_power_ring") as Node3D).visible,
				"%s: cutting the power (%.1f s), marker '%s'" % [mode_name, run.power_progress, marker.text])
			run.power_progress = IslandRun.power_seconds() - 0.01
		else:
			var fills: Array = island.get("_charge_fills")
			_check(run.charge_progress[k - 1] > 0.0 and marker.text.begins_with("PLANTING ·") and (fills[k - 1] as Node3D).visible,
				"%s: planting charge %d (%.1f s), marker '%s'" % [mode_name, k, run.charge_progress[k - 1], marker.text])
			run.charge_progress[k - 1] = IslandRun.charge_seconds() - 0.01
		if minimap != null:
			minimap.queue_redraw()
			await process_frame
			_check(minimap.drawn_kinds.has(&"charge") or minimap.drawn_kinds.has(&"charge_set"),
				"%s: the minimap draws the machines" % mode_name)
		for f in 3:
			await physics_frame
			await process_frame
		if k == 0:
			_check(run.power_cut() and not (lights[0] as OmniLight3D).is_visible_in_tree() and not (lights[1] as OmniLight3D).is_visible_in_tree()
				and objective.text == "CHARGES 0 / 2", "%s: power cut, the machines go dark, HUD '%s'" % [mode_name, objective.text])
		elif k == 1:
			var charges: Array = island.get("_charges")
			_check(run.charges_planted() == 1 and (charges[0] as Node3D).visible and objective.text == "CHARGES 1 / 2",
				"%s: charge 1 planted, its block shows, HUD '%s'" % [mode_name, objective.text])
	var rings: Array = island.get("_blast_rings")
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and objective.text.begins_with("GET CLEAR ·") and (rings[0] as Node3D).visible
		and (rings[1] as Node3D).visible and (island.get("_boat_ring") as Node3D).visible,
		"all set: the fuse, blast rings and the extraction ring show, HUD '%s'" % objective.text)
	run.fuse_left = 0.01
	for f in 3:
		await physics_frame
		await process_frame
	var scorches: Array = island.get("_machine_scorches")
	_check(run.sabotage_phase == IslandRun.SAB_BLOWN and not (machines[0] as Node3D).visible and (scorches[0] as Node3D).visible
		and float(island.get("_trauma")) > 0.3 and not (rings[0] as Node3D).visible,
		"the blast: machines gone, scorches, camera shake (trauma %.2f)" % float(island.get("_trauma")))
	island.queue_free()
	await process_frame
	_finish()
