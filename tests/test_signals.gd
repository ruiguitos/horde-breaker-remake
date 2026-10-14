extends SceneTree
## Light the Signals (docs/design/OBJECTIVES_PROPOSAL.md, step 5): a chain
## of signal beacons lit in order. Only the next signal (and its fuel can)
## is revealed; the fuel is carried with the Fuel Run rules (one can, x0.8,
## no firing, interact / ability drop it) and poured in at the signal; then
## standing there lights it (leaving pauses it, a spike on the first step
## in). A lit signal stays lit and reveals the next one; the last opens the
## extraction. The last one can be a lighthouse (Berlenga part 2).
## Also: data, Signal_*/Lighthouse/Fuel_* markers and the fallback spots
## (reachable, spread, farther in each time, fuel 15-30 m from its signal),
## death and redeploy, the boat draw (weight 1, no repeat), a bot run, the
## Island scene in the three cameras and the Berlenga part.
## Run: godot --headless --path . --script res://tests/test_signals.gd

const DT: float = 1.0 / 60.0
const BERLENGA_PART_2: String = "res://game/world/handmade/expeditions/berlenga/part_2.scn"

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _done: bool = false


func _initialize() -> void:
	GameInput.setup()
	create_timer(900.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "signals tests finished in time")
			_finish())
	_test_data()
	_test_fallback_spots()
	_test_handmade_islands()
	_test_markers()
	_test_reveal_order()
	_test_fuel_and_carry()
	_test_lighting()
	_test_extraction()
	_test_death_and_redeploy()
	_test_draw()
	_test_berlenga_part()
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
func _quiet_run(rng_seed: int, biome: StringName = &"beach") -> IslandRun:
	var run := IslandRun.new(rng_seed, biome)
	run.director.max_alive = 0
	run.set_mission(&"signals")
	return run


## The director stays relaxed until something calls a spike.
func _relax(run: IslandRun) -> void:
	run.director.phase = Director.Phase.RELAX
	run.director.phase_time = 1000.0


func _step(run: IslandRun, n: int = 1, move: Vector2 = Vector2.ZERO) -> void:
	for k in n:
		run.step(DT, move, Vector3(0, 0, -1), false)


## Picks up the next signal's can, carries it to the signal (teleporting)
## and lights it.
func _light_next(run: IslandRun) -> void:
	var i: int = run.signal_index
	run.player_pos = run.cargo_pos[i]
	_step(run)
	run.player_pos = run.signal_pos[i]
	_step(run)
	_step(run, int((IslandRun.signal_seconds() + 0.1) / DT))


func _test_data() -> void:
	var m: Dictionary = GameData.MISSIONS.get(&"signals", {})
	_check(not m.is_empty() and m["name"] == "Light the Signals" and int(m["points"]) == 3 and float(m["seconds"]) > 0.0
		and float(m["radius"]) > 0.0 and float(m["spike_seconds"]) > 0.0,
		"signals.tres: %d signals, light %.0f s at %.1f m, spike %.0f s" % [int(m.get("points", 0)), float(m.get("seconds", 0)),
		float(m.get("radius", 0)), float(m.get("spike_seconds", 0))])
	_check(GameData.ROUTE_MISSIONS.has(&"signals") and GameData.ROUTE_MISSIONS.find(&"signals") == GameData.ROUTE_MISSIONS.find(&"intel_search") + 1,
		"Light the Signals is offered on archipelago routes (after Intel Search)")
	_check(IslandRun.signal_count_wanted() == 3 and IslandRun.signal_seconds() == float(m.get("seconds", 0))
		and IslandRun.signal_radius() == float(m.get("radius", 0)) and IslandRun.signal_spike_seconds() == float(m.get("spike_seconds", 0)),
		"the run reads its numbers from the data")
	var cues: bool = true
	for cue: StringName in [&"land_signals", &"signal_fuel", &"signal_lit", &"signals_done", &"lighthouse_lit"]:
		cues = cues and Story.RADIO.has(cue)
	_check(cues, "radio lines for landing, fuel, each signal, the end and the lighthouse")
	_check(Briefing.ADVICE.has(&"signals"), "briefing advice for Light the Signals")


## The signals reachable, off the boat, spread apart and each farther in
## (walking) than the one before; every can reachable within the walk
## limit of its own signal, none on another signal.
func _check_spots(map: IslandMap, sig: Array[Vector3], fuel: Array[Vector3], label: String) -> void:
	var f: FlowField = map.field
	var saved: int = f.max_distance
	f.max_distance = 0
	f.compute_now(f.world_to_cell(map.player_start))
	var bad: int = 0
	var spacing: float = INF
	var ordered: bool = true
	for i in sig.size():
		if f.distance_at(sig[i]) >= FlowField.UNREACHABLE or _flat_dist(sig[i], map.boat) < IslandMap.HOLD_MIN_FROM_BOAT:
			bad += 1
		if i > 0 and f.distance_at(sig[i]) < f.distance_at(sig[i - 1]):
			ordered = false
		for j in range(i + 1, sig.size()):
			spacing = minf(spacing, _flat_dist(sig[i], sig[j]))
	var fuel_bad: int = 0
	var in_band: int = 0
	var dists := PackedStringArray()
	for i in fuel.size():
		f.compute_now(f.world_to_cell(sig[i]))
		var walk: int = f.distance_at(fuel[i])
		var d: float = _flat_dist(fuel[i], sig[i])
		dists.append("%.0f m (walk %d)" % [d, walk])
		if walk > IslandMap.SIGNAL_FUEL_WALK:
			fuel_bad += 1
		for j in sig.size():
			if j != i and _flat_dist(fuel[i], sig[j]) < IslandMap.SIGNAL_FUEL_MIN:
				fuel_bad += 1
		if d >= IslandMap.SIGNAL_FUEL_MIN and d <= IslandMap.SIGNAL_FUEL_MAX:
			in_band += 1
	f.max_distance = saved
	_check(sig.size() == 3 and fuel.size() == 3 and bad == 0 and spacing >= IslandMap.HOLD_MIN_SPACING and ordered and fuel_bad == 0,
		"%s: 3 signals reachable, >= %d m from the boat, min spacing %.0f m, farther in each time; fuel %s (%d / 3 in the %d-%d m band)" % [
		label, int(IslandMap.HOLD_MIN_FROM_BOAT), spacing, ", ".join(dists), in_band, int(IslandMap.SIGNAL_FUEL_MIN), int(IslandMap.SIGNAL_FUEL_MAX)])


func _test_fallback_spots() -> void:
	var band_total: int = 0
	var cans: int = 0
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		for s in [3, 77]:
			var a := _quiet_run(s, biome)
			var b := _quiet_run(s, biome)
			_check(a.signal_pos == b.signal_pos and a.cargo_pos == b.cargo_pos and not a.signal_lighthouse,
				"%s seed %d: same seed, same signals and fuel" % [biome, s])
			_check_spots(a.map, a.signal_pos, a.cargo_pos, "%s seed %d" % [biome, s])
			for i in a.cargo_pos.size():
				var d: float = _flat_dist(a.cargo_pos[i], a.signal_pos[i])
				cans += 1
				band_total += 1 if d >= IslandMap.SIGNAL_FUEL_MIN and d <= IslandMap.SIGNAL_FUEL_MAX else 0
			var lava: int = 0
			for p in a.signal_pos + a.cargo_pos:
				for k in a.map.lava.size():
					if _flat_dist(p, a.map.lava[k]) < a.map.lava_radius[k] + 1.0:
						lava += 1
			_check(lava == 0, "%s seed %d: no signal or can in lava" % [biome, s])
	_check(band_total >= cans * 0.9, "generated islands: %d / %d cans 15-30 m from their signal" % [band_total, cans])
	var x := _quiet_run(3)
	var y := _quiet_run(4)
	_check(x.signal_pos != y.signal_pos, "another seed, other signals")
	var h := IslandRun.new(3, &"beach")
	h.set_mission(&"hold_sequence")
	_check(h.hold_points != x.signal_pos, "the signals are not the Hold Sequence points of the same seed")


## The archipelago's hand-made islands have no Signal markers: the fallback
## must work on their real grids.
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
		var sig: Array[Vector3] = IslandMap.pick_signal_points(map, 3, 9)
		var fuel: Array[Vector3] = IslandMap.pick_signal_fuel_points(map, sig, 9)
		_check_spots(map, sig, fuel, path.get_file())


func _test_markers() -> void:
	var hm := HandmadeIsland.new()
	hm.size = 120
	var markers := Node3D.new()
	markers.name = "Markers"
	hm.add_child(markers)
	var spots: Dictionary = {"Boat": Vector3(60, 0, 110), "PlayerStart": Vector3(60, 0, 104),
		"Signal_2": Vector3(30, 0, 50), "Signal_1": Vector3(60, 0, 70), "Lighthouse": Vector3(90, 0, 30),
		"Fuel_1": Vector3(75, 0, 75), "Fuel_2": Vector3(30, 0, 70)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.position = spots[n]
		markers.add_child(m)
	root.add_child(hm)
	hm.mission = &"signals"
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	var want: Array[Vector3] = [Vector3(60.5, 0, 70.5), Vector3(30.5, 0, 50.5), Vector3(90.5, 0, 30.5)]
	_check(map.signal_points == want and map.signal_lighthouse and map.signal_fuel == ([Vector3(75.5, 0, 75.5), Vector3(30.5, 0, 70.5)] as Array[Vector3]),
		"Signal_1, _2 in number order, then the Lighthouse; Fuel_1, _2 read (%s, %s)" % [map.signal_points, map.signal_fuel])
	_check(problems.is_empty(), "markers reachable, no problems (%s)" % [problems])
	var run := IslandRun.new(1, &"beach", map)
	run.set_mission(&"signals")
	_check(run.signal_pos == want and run.signal_lighthouse and run.signal_name(2) == "Lighthouse" and run.signal_name(0) == "Signal 1",
		"the run uses the markers; the last signal is the lighthouse")
	_check(run.cargo_pos.size() == 3 and run.cargo_pos[0] == map.signal_fuel[0] and run.cargo_pos[1] == map.signal_fuel[1]
		and run.cargo_pos[2].x >= 0.0 and _flat_dist(run.cargo_pos[2], want[2]) <= IslandMap.SIGNAL_FUEL_MAX + 0.5,
		"Fuel_1 and Fuel_2 feed signals 1 and 2; the lighthouse's fuel is picked near it (%.0f m)" % _flat_dist(run.cargo_pos[2], want[2]))
	hm.play_area = PackedVector2Array([Vector2(10, 40), Vector2(110, 40), Vector2(110, 118), Vector2(10, 118)])
	problems.clear()
	hm.build_map(problems)
	var reported: bool = false
	for p in problems:
		if p.begins_with("Signal/Lighthouse at (90, 30)"):
			reported = true
	_check(reported, "an unreachable Lighthouse marker is reported (%s)" % [problems])
	_check(HandmadeIsland.marker_number("Signal_4", "Signal") == 4 and HandmadeIsland.marker_number("Fuel_2", "Fuel") == 2,
		"Signal and Fuel marker suffix numbers")
	hm.free()


func _test_reveal_order() -> void:
	var run := _quiet_run(21)
	_check(run.signal_index == 0 and run.site == run.cargo_pos[0] and run.can_available(0) and not run.can_available(1)
		and not run.can_available(2), "landing: only signal 1 and its fuel are in play; the goal is its can")
	_check(run.nearest_waiting_can() == 0, "the nearest waiting can is always the next signal's")
	# Walking over a later signal's can does nothing.
	run.player_pos = run.cargo_pos[2]
	_step(run)
	_check(not run.is_carrying() and run.cargo_state[2] == IslandRun.CAN_WAITING, "a hidden signal's can cannot be picked up")
	run.player_pos = run.cargo_pos[1]
	_check(not run.interact(), "nor with interact")
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"signal") and legend.has(&"fuel") and not legend.has(&"signal_lit"), "minimap key: SIGNAL and FUEL, nothing lit yet")
	_relax(run)
	_light_next(run)
	_check(run.signal_index == 1 and run.signals_lit() == 1 and run.site == run.cargo_pos[1] and run.can_available(1)
		and not run.can_available(0) and not run.can_available(2), "signal 1 lit: signal 2 and its fuel are revealed, signal 3 still hidden")
	legend = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"signal_lit") and legend.has(&"signal"), "minimap key: the lit signal stays on the map")


func _test_fuel_and_carry() -> void:
	var run := _quiet_run(31)
	_relax(run)
	# At the signal without fuel: nothing happens.
	run.player_pos = run.signal_pos[0]
	_step(run, int(IslandRun.signal_seconds() / DT) + 10)
	_check(run.signal_progress == 0.0 and not run.signal_fuelled() and run.director.phase == Director.Phase.RELAX
		and run.objective_text().begins_with("Signals 0 / 3: find the fuel"),
		"no fuel, no lighting: standing at the signal does nothing ('%s')" % run.objective_text())
	# Walking over the can picks it up (the Fuel Run carry rules).
	var p0: Vector3 = run.cargo_pos[0]
	run.radio.clear()
	run.player_pos = p0
	_step(run)
	_check(run.is_carrying() and run.carrying == 0 and run.radio.has(&"signal_fuel") and run.director.phase == Director.Phase.RELAX
		and run.site == run.signal_pos[0], "walking over the fuel picks it up (radio line, no spike yet); the goal is the signal")
	# Speed x carry_speed_mult (Fuel Run's), no sprint.
	var carried: float = _best_walk(run, p0)
	run.player_pos = p0
	_check(run.drop_cargo() and not run.is_carrying(), "drop_cargo puts it down")
	var free: float = _best_walk(run, p0)
	_check(absf(carried / free - IslandRun.carry_speed_mult()) < 0.03,
		"carrying walks at x%.2f, the Fuel Run rule (%.2f m vs %.2f m in 8 steps)" % [carried / free, carried, free])
	# No firing with the fuel; the ability button drops it.
	run.player_pos = p0
	_check(run.interact() and run.is_carrying(), "interact picks it up again")
	var e: int = run.horde.add(p0 + Vector3(0, 0, -2.0), GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[e] = 100.0
	var shots: int = run._shots
	for k in 60:
		run.player_pos = p0
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run._shots == shots, "no shots while carrying the fuel")
	run.grenade_cd = 0.0
	var used: bool = run.use_ability(Vector3(0, 0, -6))
	_check(not used and run.grenades.is_empty() and not run.is_carrying() and run.cargo_state[0] == IslandRun.CAN_WAITING,
		"ability with the fuel: no grenade, the can is dropped")
	run.horde.remove(e)
	# Pick it up again and carry it in: poured in within signal_radius().
	run.player_pos = p0 + Vector3(IslandRun.cargo_pickup_radius() + 3.0, 0, 0)
	_step(run)
	run.player_pos = p0
	_step(run)
	_check(run.is_carrying() and run.radio.count(&"signal_fuel") == 1, "picked up again (one radio line per can)")
	run.player_pos = run.signal_pos[0] + Vector3(IslandRun.signal_radius() - 0.5, 0, 0)
	_step(run)
	_check(not run.is_carrying() and run.cargo_state[0] == IslandRun.CAN_DELIVERED and run.signal_fuelled()
		and run.cargo_pos[0] == run.signal_pos[0], "at the signal the fuel is poured in: signal 1 fuelled")


## Metres walked in 8 steps from `from`, the best of four directions.
func _best_walk(run: IslandRun, from: Vector3) -> float:
	var best: float = 0.0
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		run.player_pos = from
		_step(run, 8, d)
		best = maxf(best, _flat_dist(run.player_pos, from))
	run.player_pos = from
	return best


func _test_lighting() -> void:
	var run := _quiet_run(41)
	run.player_pos = run.cargo_pos[0]
	_step(run)
	_relax(run)
	run.player_pos = run.signal_pos[0]
	_step(run, int(2.0 / DT))
	_check(absf(run.signal_progress - 2.0) < 0.05 and run.director.phase == Director.Phase.PEAK and run.signal_started,
		"fuelled and standing there: lighting (%.2f s of %.0f), the first step in calls a spike" % [run.signal_progress, IslandRun.signal_seconds()])
	_check(run.objective_text().begins_with("Signals 0 / 3: light signal 1"), "objective '%s'" % run.objective_text())
	run.player_pos = run.signal_pos[0] + Vector3(IslandRun.signal_radius() + 2.0, 0, 0)
	var p: float = run.signal_progress
	_step(run, 60)
	_check(run.signal_progress == p, "leaving pauses the lighting (kept %.2f s)" % p)
	_relax(run)
	run.player_pos = run.signal_pos[0]
	run._take_player_damage(5.0)
	_step(run, 30)
	_check(run.signal_progress > p and run.director.phase == Director.Phase.RELAX,
		"coming back resumes it, damage does not stop it, no second spike")
	for w in run.weapons.size():
		run.ammo[w] = 0
	run.radio.clear()
	_step(run, int((IslandRun.signal_seconds() - run.signal_progress + 0.1) / DT))
	var refilled: bool = false
	for w in run.weapons.size():
		if run.weapons[w].max_ammo > 0 and run.ammo[w] > 0:
			refilled = true
	_check(run.signal_index == 1 and run.signal_progress == 0.0 and not run.signal_started and run.radio.has(&"signal_lit") and refilled,
		"after %.0f s signal 1 is lit: radio line, a third of the ammo back, the next one waits" % IslandRun.signal_seconds())
	_check(run.objective == IslandRun.Objective.GENERATORS, "signals left: no extraction yet")


func _test_extraction() -> void:
	var ctx := RunContext.new(7)
	ctx.mission = &"signals"
	var run := IslandRun.new(61)
	run.load_context(ctx)
	run.director.max_alive = 0
	_check(run.radio.has(&"land_signals") and run.signal_pos.size() == 3 and run.signals_lit() == 0, "landing: radio line, 3 signals")
	run.player_pos = run.map.boat
	_step(run, 10)
	_check(run.objective == IslandRun.Objective.GENERATORS, "nothing lit: no extraction at the boat")
	var intel0: int = run.intel_earned()
	run.radio.clear()
	_light_next(run)
	_light_next(run)
	_check(run.objective == IslandRun.Objective.GENERATORS and run.signals_lit() == 2 and run.intel_earned() - intel0 >= 30,
		"two lit: still no extraction (Intel +%d)" % (run.intel_earned() - intel0))
	_light_next(run)
	_check(run.signals_lit() == 3 and run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.radio.has(&"signals_done")
		and run.radio.count(&"signal_lit") == 2, "the last signal opens the extraction (radio after the first two, the end line after the last)")
	run.player_pos = run.map.boat
	_step(run, 2)
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() >= 40 + 45, "at the boat the run is won (Intel %d)" % run.intel_earned())


func _test_death_and_redeploy() -> void:
	var ctx := RunContext.new(9)
	ctx.mission = &"signals"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	_light_next(run)
	run.player_pos = run.cargo_pos[1]
	_step(run)
	_check(run.is_carrying() and run.signals_lit() == 1, "one lit, carrying the next fuel")
	run.hp = 0.0
	_step(run)
	_check(run.objective == IslandRun.Objective.LOST and run.is_over(), "dying with the fuel ends the island")
	var again := IslandRun.new(ctx.island_seed(), ctx.biome)
	again.load_context(ctx)
	var fresh: bool = again.signal_index == 0 and again.signal_progress == 0.0 and not again.is_carrying() and not again.signal_started
	for c in again.cargo_state.size():
		fresh = fresh and again.cargo_state[c] == IslandRun.CAN_WAITING and not again.cargo_touched[c]
	_check(fresh and again.signal_pos == run.signal_pos and again.cargo_pos.size() == 3,
		"a redeployed island starts fresh, same signals, every can back")
	again.set_mission(&"activate")
	_check(again.signal_pos.is_empty() and again.cargo_pos.is_empty() and again.signal_index == 0 and not again.uses_cargo(),
		"switching mission clears the signals and their fuel")
	var fr := IslandRun.new(ctx.island_seed(), ctx.biome)
	fr.set_mission(&"signals")
	fr.set_mission(&"fuel_run")
	_check(fr.signal_pos.is_empty() and fr.cargo_pos.size() == 3 and fr.can_available(2), "Fuel Run after Signals: its own cans, all available")


func _test_draw() -> void:
	var weights_ok: bool = true
	for biome: StringName in GameData.ISLAND_BIOMES + [&"volcano"]:
		weights_ok = weights_ok and GameData.mission_weight(&"signals", biome) == 1
	_check(weights_ok, "weights: Light the Signals weighs 1 on every biome (no signature island)")
	_check(not GameData.route_missions_after(&"signals").has(&"signals"), "never Light the Signals twice in a row")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var beach: int = 0
	var port: int = 0
	var repeats: int = 0
	var n: int = 4000
	for k in n:
		if GameData.pick_route_mission(rng, &"", &"beach") == &"signals":
			beach += 1
		if GameData.pick_route_mission(rng, &"", &"port") == &"signals":
			port += 1
		if GameData.pick_route_mission(rng, &"signals", &"port") == &"signals":
			repeats += 1
	var want_beach: float = GameData.mission_share(&"signals", &"beach")
	var want_port: float = GameData.mission_share(&"signals", &"port")
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
	var signals: int = 0
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
				if m == &"signals":
					signals += 1
	_check(deterministic and repeats_boat == 0 and signals > 0,
		"boat routes: %d draws, deterministic, %d repeats, Light the Signals on %d" % [draws, repeats_boat, signals])


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


## Berlenga part 2 (Lighthouse Plateau) plays Light the Signals: two
## signals then the real lighthouse, the fuel at the keepers' houses, the
## lighthouse marker beside the real tower; the whole chain can be done.
func _test_berlenga_part() -> void:
	var parts: Array = Expeditions.parts(&"berlenga")
	_check(parts.size() == 4 and parts[1]["mission"] == &"signals" and String(parts[1]["scene"]) == BERLENGA_PART_2,
		"the Berlenga expedition's part 2 is Light the Signals")
	if not ResourceLoader.exists(BERLENGA_PART_2):
		_check(false, "%s exists" % BERLENGA_PART_2)
		return
	var island: HandmadeIsland = (load(BERLENGA_PART_2) as PackedScene).instantiate()
	root.add_child(island)
	var problems: Array[String] = []
	var map: IslandMap = island.build_map(problems)
	_check(island.mission == &"signals" and problems.is_empty(), "part 2: mission '%s', no problems %s" % [island.mission, problems])
	_check(map.signal_points.size() == 3 and map.signal_lighthouse and map.signal_fuel.size() == 3,
		"part 2: %d signals (the last the Lighthouse), %d Fuel markers" % [map.signal_points.size(), map.signal_fuel.size()])
	# The real tower: Buildings/Lighthouse_0's centre.
	var tower := Vector3.INF
	var houses: Array[Vector3] = []
	for n in island.get_node("Buildings").get_children():
		var c: Vector3 = _centre(n)
		if String(n.name).begins_with("Lighthouse"):
			tower = c
		elif String(n.name).begins_with("House"):
			houses.append(c)
	var light_d: float = _flat_dist(map.signal_points[-1], tower) if map.signal_points.size() == 3 else INF
	_check(tower != Vector3.INF and light_d <= 15.0, "the Lighthouse marker is %.1f m from the real tower" % light_d)
	var near_house: int = 0
	var report := PackedStringArray()
	for p in map.signal_fuel:
		var best: float = INF
		for hc in houses:
			best = minf(best, _flat_dist(p, hc))
		report.append("%.0f m" % best)
		near_house += 1 if best <= 15.0 else 0
	_check(near_house == map.signal_fuel.size() and houses.size() > 0, "the fuel waits at the keepers' houses (%s from a house)" % ", ".join(report))
	var run := IslandRun.new(5, &"beach", map)
	run.director.max_alive = 0
	run.set_mission(&"signals")
	var lit_order: bool = true
	for i in 3:
		_light_next(run)
		lit_order = lit_order and run.signals_lit() == i + 1
	_check(lit_order and run.signal_lighthouse and run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.has_exit()
		and run.radio.has(&"lighthouse_lit"), "part 2: the chain lights to the lighthouse, then the Exit opens")
	island.queue_free()


func _centre(n: Node) -> Vector3:
	var box := AABB()
	var any: bool = false
	for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			# Island space without needing the tree: the chain of local transforms.
			var t: Transform3D = (mi as Node3D).transform
			var up: Node = (mi as Node).get_parent()
			while up != null and not up is HandmadeIsland:
				if up is Node3D:
					t = (up as Node3D).transform * t
				up = up.get_parent()
			var a: AABB = t * (mi as MeshInstance3D).mesh.get_aabb()
			box = a if not any else box.merge(a)
			any = true
	return box.get_center() if any else (n as Node3D).position


## A bot walks to the next goal (the can, then the signal) and stands in
## it, signal after signal, then extracts (the soak test's navigation;
## invincible: this checks completability and the pacing with the horde).
## It drops the can to fight when crowded.
func _test_bot() -> void:
	for s in [404, 505, 606]:
		var ctx := RunContext.new(s)
		ctx.threat = 2
		ctx.mission = &"signals"
		ctx.biome = [&"beach", &"town", &"jungle"][[404, 505, 606].find(s)]
		var run := IslandRun.new(ctx.island_seed(), ctx.biome)
		run.load_context(ctx)
		_bot(run, "bot seed %d (%s)" % [s, ctx.biome])


func _bot(run: IslandRun, label: String) -> void:
	var nav := FlowField.new(run.field.width, run.field.height)
	nav.blocked = run.field.blocked
	var goal := Vector3.INF
	var steps: int = 0
	var drops: int = 0
	var fight: int = 0
	var peak_enemies: int = 0
	var lit_at := PackedStringArray()
	var last_lit: int = 0
	while not run.is_over() and steps < int(900.0 / DT):
		steps += 1
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.hp = 10000.0
		var near: PackedInt32Array = run.horde.query_radius(run.player_pos, 6.0)
		if run.is_carrying() and near.size() > 12:
			run.drop_cargo()
			drops += 1
			fight = int(4.0 / DT)
		var move := Vector2.ZERO
		if fight > 0:
			fight -= 1
			if fight == 0:
				run.interact()
		else:
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
		run.step(DT, move, aim, close.size() > 10)
		if run.signals_lit() > last_lit:
			last_lit = run.signals_lit()
			lit_at.append("%.0f s" % (run.time_alive - run.landed_time))
		peak_enemies = maxi(peak_enemies, run.horde.count)
	_check(run.objective == IslandRun.Objective.WON and run.signals_lit() == run.signal_pos.size(),
		"%s: %s in %.0f s; lit at %s; %d drops to fight, %d kills, up to %d enemies alive, Intel %d" % [label,
		run.objective_text(), run.time_alive - run.landed_time, ", ".join(lit_at), drops, run.kills, peak_enemies, run.intel_earned()])


## The Island scene with Light the Signals, in each camera mode: signals
## and cans are built, only the next signal shows, the carried can follows
## the soldier, the HUD (DROP CAN), its marker and the minimap follow, and
## lighting through the scene's own loop lights the fire. Then a lighthouse
## variant (markers on a hand-made island) builds its beam.
func _test_scene() -> void:
	var profile := MemoryProfile.new()
	var ctx := RunContext.new(5)
	ctx.mission = &"signals"
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
	var sigs: Array = island.get("_signals")
	var cans: Array = island.get("_cans")
	_check(sigs.size() == 3 and cans.size() == 3 and island.get("_signal_beam") == null,
		"the scene builds 3 signals and 3 cans (no lighthouse beam on a plain island)")
	await physics_frame
	await process_frame
	_check((sigs[0] as Node3D).visible and not (sigs[1] as Node3D).visible and not (sigs[2] as Node3D).visible
		and (cans[0] as Node3D).visible and not (cans[1] as Node3D).visible and not (cans[2] as Node3D).visible,
		"only signal 1 and its can show; the later ones are hidden")
	var hud: Hud = island.get("hud")
	var objective: Label = hud.get("_objective")
	var marker: Label = hud.get("_marker")
	var ability: Label = hud.get("_ability_status")
	var minimap: Minimap = hud.get("_minimap")
	_check(objective.text == "SIGNALS 0 / 3", "HUD objective '%s'" % objective.text)
	var modes: Array = [Profile.CameraMode.FIRST_PERSON, Profile.CameraMode.THIRD_PERSON, Profile.CameraMode.FIXED]
	for k in modes.size():
		var mode_name: String = Profile.CAMERA_MODE_NAMES[modes[k]]
		island.call("_set_camera_mode", modes[k], false)
		var i: int = run.signal_index
		# Pick up this signal's fuel: carried at the soldier's side.
		run.player_pos = run.cargo_pos[i]
		for f in 4:
			await physics_frame
			await process_frame
		var player: Node3D = island.get("_player")
		var can: Node3D = cans[i]
		_check(run.is_carrying() and can.visible and can.position.distance_to(player.position) < 1.0 and ability.text == "DROP CAN",
			"%s: the fuel is carried at the soldier's side (%.2f m), ability slot '%s'" % [mode_name, can.position.distance_to(player.position), ability.text])
		# Pour it in and stand there: the scene's loop lights it.
		run.player_pos = run.signal_pos[i]
		var to: Vector3 = run.signal_pos[i] - run.map.player_start
		island.set("_tp_yaw", atan2(-to.x, -to.z))
		run.facing = Vector3(to.x, 0, to.z).normalized() if to.length() > 0.1 else Vector3(0, 0, -1)
		for f in 40:
			await physics_frame
			await process_frame
		var rings: Array = island.get("_signal_rings")
		_check(run.signal_fuelled() and run.signal_progress > 0.0 and marker.text.begins_with("LIGHTING ·") and (rings[i] as Node3D).visible
			and not can.visible, "%s: fuel poured in, lighting (%.1f s), marker '%s'" % [mode_name, run.signal_progress, marker.text])
		if minimap != null:
			minimap.queue_redraw()
			await process_frame
			_check(minimap.drawn_kinds.has(&"signal") and (i == 0 or minimap.drawn_kinds.has(&"signal_lit")),
				"%s: the minimap draws the next signal%s" % [mode_name, "" if i == 0 else " and the lit ones"])
		run.signal_progress = IslandRun.signal_seconds() - 0.01
		for f in 3:
			await physics_frame
			await process_frame
		var fires: Array = island.get("_signal_fires")
		var lights: Array = island.get("_signal_lights")
		_check(run.signals_lit() == i + 1 and (fires[i] as Node3D).visible and (lights[i] as OmniLight3D).is_visible_in_tree()
			and (sigs[i] as Node3D).visible, "%s: signal %d lit, its fire and light on" % [mode_name, i + 1])
		if i + 1 < 3:
			_check((sigs[i + 1] as Node3D).visible and (cans[i + 1] as Node3D).visible and objective.text == "SIGNALS %d / 3" % (i + 1),
				"%s: the next signal and its fuel are revealed, HUD '%s'" % [mode_name, objective.text])
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and objective.text == "RETURN TO THE BOAT",
		"all lit: extraction, HUD '%s'" % objective.text)
	island.queue_free()
	await process_frame
	await _test_lighthouse_scene()
	_finish()


## A hand-made island (beach_01) with Signal_1, Signal_2 and a Lighthouse
## marker on its generators: the last signal builds the lighthouse (a stone
## tower when the scene has none) with its beam, and the beam turns once lit.
func _test_lighthouse_scene() -> void:
	var hm: HandmadeIsland = (load(HandmadeIsland.ISLANDS_DIR + "beach_01.tscn") as PackedScene).instantiate()
	hm.mission = &"signals"
	var markers: Node = hm.get_node("Markers")
	for spot: Array in [["Signal_1", "Generator1"], ["Signal_2", "Generator2"], ["Lighthouse", "Generator3"]]:
		var m := Marker3D.new()
		m.name = spot[0]
		m.transform = (markers.get_node(spot[1]) as Node3D).transform
		markers.add_child(m)
		m.owner = hm
	var packed := PackedScene.new()
	packed.pack(hm)
	hm.free()
	var ctx := RunContext.new(21)
	ctx.mission = &"signals"
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	island.set("handmade_scene", packed)
	island.set("context", ctx)
	root.add_child(island)
	for i in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	var beam: Node3D = island.get("_signal_beam")
	_check(run.signal_lighthouse and run.signal_name(2) == "Lighthouse" and beam != null,
		"a Lighthouse marker: the last signal is a lighthouse with a beam")
	var fires: Array = island.get("_signal_fires")
	var fire_y: float = (fires[2] as Node3D).global_position.y - run.map.ground_y(run.signal_pos[2])
	_check(fire_y >= 9.0, "the lighthouse fire sits high (%.1f m above the ground)" % fire_y)
	run.signal_index = 3  # all lit: the beam turns
	var r0: float = beam.rotation.y
	for i in 10:
		await process_frame
	_check(beam.is_visible_in_tree() and beam.rotation.y != r0, "the lit lighthouse's beam turns")
	island.queue_free()
	await process_frame
	await _test_berlenga_scene()


## Berlenga part 2 in the Island scene: the lighthouse's fire and beam go
## to the top of the real tower (Buildings/Lighthouse_0), not to a new one.
func _test_berlenga_scene() -> void:
	if not ResourceLoader.exists(BERLENGA_PART_2):
		return
	var t0: int = Time.get_ticks_msec()
	var ctx := RunContext.new(31)
	ctx.mission = &"signals"
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	island.set("handmade_scene", load(BERLENGA_PART_2))
	island.set("context", ctx)
	root.add_child(island)
	for i in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	var hm: HandmadeIsland = island.get("_handmade")
	var tower: Vector3 = _centre(hm.get_node("Buildings/Lighthouse_0"))
	var fires: Array = island.get("_signal_fires")
	var fire: Vector3 = (fires[2] as Node3D).global_position if fires.size() == 3 else Vector3.ZERO
	var above: float = fire.y - run.map.ground_y(run.signal_pos[2])
	_check(run.signal_lighthouse and island.get("_signal_beam") != null and _flat_dist(fire, tower) < 1.0 and above > 15.0,
		"Berlenga part 2: the lighthouse fire is on the real tower (%.1f m from its centre, %.0f m up; scene ready in %d ms)" % [
		_flat_dist(fire, tower), above, Time.get_ticks_msec() - t0])
	island.queue_free()
	await process_frame
