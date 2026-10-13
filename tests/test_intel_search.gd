extends SceneTree
## Intel Search (docs/design/OBJECTIVES_PROPOSAL.md, step 4): search the
## marked spots before the clock runs out; only some hold intel (seeded,
## hidden until searched). Standing at a spot searches it (leaving pauses
## it, damage does not); each search start calls a short spike. When every
## intel is found, or time is up with some found, the intel is transmitted
## at the uplink (a hold with a spike); the extraction opens after it. Time
## up with nothing found: straight to the extraction, no bonus.
## Also: data, Search_*/Uplink markers and the fallback spots (near
## buildings when the island has them), the reward, death and redeploy,
## the boat draw (Coastal Town preference, no repeat), a bot run and the
## Island scene in the three cameras.
## Run: godot --headless --path . --script res://tests/test_intel_search.gd

const DT: float = 1.0 / 60.0

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _done: bool = false


func _initialize() -> void:
	GameInput.setup()
	create_timer(600.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "intel search tests finished in time")
			_finish())
	_test_data()
	_test_fallback_spots()
	_test_handmade_islands()
	_test_markers()
	_test_hidden_intel()
	_test_search_progress()
	_test_empty_and_full()
	_test_transmit_and_extraction()
	_test_timer_partial()
	_test_zero_found()
	_test_death_and_redeploy()
	_test_draw()
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
func _quiet_run(rng_seed: int, biome: StringName = &"town") -> IslandRun:
	var run := IslandRun.new(rng_seed, biome)
	run.director.max_alive = 0
	run.set_mission(&"intel_search")
	return run


## The director stays relaxed until something calls a spike.
func _relax(run: IslandRun) -> void:
	run.director.phase = Director.Phase.RELAX
	run.director.phase_time = 1000.0


func _step(run: IslandRun, n: int = 1) -> void:
	for k in n:
		run.step(DT, Vector2.ZERO, run.facing, false)


## Index of the first spot with (or without) intel; -1 = none.
func _spot(run: IslandRun, with_intel: bool) -> int:
	for k in run.search_pos.size():
		if run.search_has_intel[k] == with_intel and run.search_state[k] == IslandRun.SPOT_UNSEARCHED:
			return k
	return -1


## Stands on spot k until it is searched (or `seconds` pass).
func _search(run: IslandRun, k: int, seconds: float = -1.0) -> void:
	run.player_pos = run.search_pos[k]
	var frames: int = int(((seconds if seconds >= 0.0 else IslandRun.search_seconds()) + 0.05) / DT)
	for i in frames:
		if run.search_state[k] != IslandRun.SPOT_UNSEARCHED or run.objective != IslandRun.Objective.GENERATORS:
			break
		_step(run)


func _test_data() -> void:
	var m: Dictionary = GameData.MISSIONS.get(&"intel_search", {})
	_check(not m.is_empty() and m["name"] == "Intel Search" and int(m["points"]) == 3 and int(m["search_spots"]) == 5
		and float(m["seconds"]) > 0.0 and float(m["radius"]) > 0.0 and float(m["time_limit"]) > 0.0
		and float(m["transmit_seconds"]) > 0.0 and float(m["transmit_radius"]) > 0.0 and int(m["intel_reward"]) > 0
		and float(m["spike_seconds"]) > 0.0,
		"intel_search.tres: %d intel in %d spots, search %.0f s at %.1f m, %.0f s limit, transmit %.0f s at %.0f m, %d Intel each, spike %.0f s" % [
		int(m.get("points", 0)), int(m.get("search_spots", 0)), float(m.get("seconds", 0)), float(m.get("radius", 0)),
		float(m.get("time_limit", 0)), float(m.get("transmit_seconds", 0)), float(m.get("transmit_radius", 0)),
		int(m.get("intel_reward", 0)), float(m.get("spike_seconds", 0))])
	_check(GameData.ROUTE_MISSIONS.has(&"intel_search"), "Intel Search is offered on archipelago routes")
	_check(IslandRun.intel_count_wanted() == 3 and IslandRun.search_spots_wanted() == 5
		and IslandRun.search_seconds() == float(m.get("seconds", 0)) and IslandRun.search_time_limit() == float(m.get("time_limit", 0))
		and IslandRun.transmit_seconds() == float(m.get("transmit_seconds", 0)) and IslandRun.intel_reward() == int(m.get("intel_reward", 0)),
		"the run reads its numbers from the data")
	var cues: bool = true
	for cue: StringName in [&"land_intel_search", &"intel_found", &"intel_transmit", &"intel_done", &"intel_none"]:
		cues = cues and Story.RADIO.has(cue)
	_check(cues, "radio lines for landing, each find, the uplink, the end and the empty end")
	_check(Briefing.ADVICE.has(&"intel_search"), "briefing advice for Intel Search")
	_check(IslandRun.clock_text(102.0) == "1:42" and IslandRun.clock_text(0.2) == "0:01" and IslandRun.clock_text(-3.0) == "0:00",
		"clock text m:ss, rounded up")


## Every spot reachable from the start, off the boat, spread apart; the
## uplink reachable and off the boat too.
func _check_spots(map: IslandMap, pts: Array[Vector3], uplink: Vector3, label: String) -> void:
	var f: FlowField = map.field
	var saved: int = f.max_distance
	f.max_distance = 0
	f.compute_now(f.world_to_cell(map.player_start))
	var bad: int = 0
	var spacing: float = INF
	for i in pts.size():
		if f.distance_at(pts[i]) >= FlowField.UNREACHABLE or _flat_dist(pts[i], map.boat) < IslandMap.HOLD_MIN_FROM_BOAT:
			bad += 1
		for j in range(i + 1, pts.size()):
			spacing = minf(spacing, _flat_dist(pts[i], pts[j]))
	var up_ok: bool = uplink.x >= 0.0 and f.distance_at(uplink) < FlowField.UNREACHABLE \
		and _flat_dist(uplink, map.boat) >= IslandMap.HOLD_MIN_FROM_BOAT
	f.max_distance = saved
	_check(pts.size() == 5 and bad == 0 and spacing >= IslandMap.HOLD_MIN_SPACING and up_ok,
		"%s: 5 spots reachable, >= %d m from the boat, min spacing %.0f m; uplink reachable" % [label, int(IslandMap.HOLD_MIN_FROM_BOAT), spacing])


## How many of `pts` are within SEARCH_NEAR_BUILDING cells of a building.
func _near_buildings(map: IslandMap, pts: Array[Vector3]) -> int:
	var n: int = 0
	for p in pts:
		for r in map.buildings:
			if r.size.x <= 60 and r.size.y <= 60 and r.grow(IslandMap.SEARCH_NEAR_BUILDING).has_point(Vector2i(int(p.x), int(p.z))):
				n += 1
				break
	return n


func _test_fallback_spots() -> void:
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		for s in [3, 77]:
			var a := _quiet_run(s, biome)
			var b := _quiet_run(s, biome)
			_check(a.search_pos == b.search_pos and a.uplink_pos == b.uplink_pos and a.search_has_intel == b.search_has_intel,
				"%s seed %d: same seed, same spots, uplink and hidden intel" % [biome, s])
			_check_spots(a.map, a.search_pos, a.uplink_pos, "%s seed %d" % [biome, s])
			var near: int = _near_buildings(a.map, a.search_pos)
			var lava: int = 0
			for p in a.search_pos + [a.uplink_pos]:
				for k in a.map.lava.size():
					if _flat_dist(p, a.map.lava[k]) < a.map.lava_radius[k] + IslandRun.search_radius():
						lava += 1
			var apart: float = INF
			for p in a.search_pos:
				apart = minf(apart, _flat_dist(p, a.uplink_pos))
			_check(lava == 0 and (biome != &"town" or near == 5),
				"%s seed %d: %d / 5 spots next to a building, none in lava, uplink %.0f m from the nearest spot" % [biome, s, near, apart])
	var x := _quiet_run(3)
	var y := _quiet_run(4)
	_check(x.search_pos != y.search_pos, "another seed, other spots")
	var f := IslandRun.new(3, &"town")
	f.set_mission(&"nests")
	_check(f.nest_pos != x.search_pos.slice(0, 3), "the spots are not the Nests spots of the same seed")


## The archipelago's hand-made islands have no Search markers: the fallback
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
		var pts: Array[Vector3] = map.search_points if not map.search_points.is_empty() else IslandMap.pick_search_points(map, 5, 9)
		var up: Vector3 = map.uplink if map.uplink.x >= 0.0 else IslandMap.pick_uplink_point(map, pts, 9)
		_check_spots(map, pts, up, path.get_file())


func _test_markers() -> void:
	var hm := HandmadeIsland.new()
	hm.size = 120
	var markers := Node3D.new()
	markers.name = "Markers"
	hm.add_child(markers)
	var spots: Dictionary = {"Boat": Vector3(60, 0, 110), "PlayerStart": Vector3(60, 0, 104),
		"Search_10": Vector3(90, 0, 30), "Search_2": Vector3(30, 0, 50), "Search_1": Vector3(60, 0, 70),
		"Search_3": Vector3(85, 0, 60), "Uplink": Vector3(50, 0, 45)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.position = spots[n]
		markers.add_child(m)
	root.add_child(hm)
	hm.mission = &"intel_search"
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	var want: Array[Vector3] = [Vector3(60.5, 0, 70.5), Vector3(30.5, 0, 50.5), Vector3(85.5, 0, 60.5), Vector3(90.5, 0, 30.5)]
	_check(map.search_points == want and map.uplink == Vector3(50.5, 0, 45.5),
		"Search_1, _2, _3, _10 in number order, Uplink read (%s, %s)" % [map.search_points, map.uplink])
	_check(problems.is_empty(), "markers reachable, no problems (%s)" % [problems])
	var run := IslandRun.new(1, &"town", map)
	run.set_mission(&"intel_search")
	_check(run.search_pos == want and run.uplink_pos == map.uplink and run.intel_total() == 3,
		"the run uses the markers (4 spots, 3 hold intel), not picked spots")
	hm.play_area = PackedVector2Array([Vector2(10, 40), Vector2(110, 40), Vector2(110, 118), Vector2(10, 118)])
	problems.clear()
	hm.build_map(problems)
	var reported: bool = false
	for p in problems:
		if p.begins_with("Search at (90, 30)"):
			reported = true
	_check(reported, "an unreachable Search marker is reported (%s)" % [problems])
	_check(HandmadeIsland.marker_number("Search_4", "Search") == 4, "Search marker suffix number")
	hm.free()


func _test_hidden_intel() -> void:
	var differs: bool = false
	var counts_ok: bool = true
	var first := _quiet_run(30)
	for s in range(30, 40):
		var r := _quiet_run(s)
		counts_ok = counts_ok and r.intel_total() == 3 and r.search_pos.size() == 5 and r.intel_found() == 0
		var pattern: Array[bool] = r.search_has_intel
		if pattern != first.search_has_intel:
			differs = true
	_check(counts_ok, "every island: 5 spots, 3 hold intel, none found at the landing")
	_check(differs, "which spots hold the intel changes with the seed")
	var again := _quiet_run(30)
	_check(again.search_has_intel == first.search_has_intel, "same seed, same hidden intel")


func _test_search_progress() -> void:
	var run := _quiet_run(41)
	var k: int = _spot(run, false)
	_relax(run)
	run.player_pos = run.search_pos[k] + Vector3(0.8, 0, 0)
	_step(run, int(2.0 / DT))
	_check(absf(run.search_progress[k] - 2.0) < 0.05 and run.search_state[k] == IslandRun.SPOT_UNSEARCHED,
		"standing at the spot searches it (%.2f s of %.0f)" % [run.search_progress[k], IslandRun.search_seconds()])
	_check(run.director.phase == Director.Phase.PEAK and run.search_started[k], "the search start calls a spike")
	run.player_pos = run.search_pos[k] + Vector3(IslandRun.search_radius() + 2.0, 0, 0)
	var p: float = run.search_progress[k]
	_step(run, 60)
	_check(run.search_progress[k] == p, "leaving pauses the search (kept %.2f s)" % p)
	_relax(run)
	run.player_pos = run.search_pos[k]
	run._take_player_damage(5.0)
	_step(run, 30)
	run._take_player_damage(5.0)
	_check(run.search_progress[k] > p and run.director.phase == Director.Phase.RELAX,
		"coming back resumes it, damage does not interrupt it, no second spike for the same spot")
	_step(run, int(2.0 / DT))
	_check(run.search_state[k] == IslandRun.SPOT_EMPTY, "after %.0f s the spot is searched" % IslandRun.search_seconds())


func _test_empty_and_full() -> void:
	var run := _quiet_run(42)
	var empty: int = _spot(run, false)
	var full: int = _spot(run, true)
	var intel0: int = run.intel_earned()
	run.messages.clear()
	_search(run, empty)
	_check(run.search_state[empty] == IslandRun.SPOT_EMPTY and run.messages.has("Nothing here") and run.intel_found() == 0,
		"an empty spot says 'Nothing here'")
	_check(run.site != run.search_pos[empty] and run.intel_goal() == run.search_pos[run.nearest_unsearched()],
		"the goal moves on to the nearest unsearched spot")
	run.radio.clear()
	_search(run, full)
	_check(run.search_state[full] == IslandRun.SPOT_FOUND and run.intel_found() == 1 and run.radio.has(&"intel_found"),
		"a full spot gives its intel (1 / 3), radio line")
	var gain: int = run.intel_earned() - intel0
	_check(gain >= IslandRun.intel_reward(), "each intel found pays %d Intel (+%d here)" % [IslandRun.intel_reward(), gain])
	_check(run.objective == IslandRun.Objective.GENERATORS and run.intel_phase == IslandRun.INTEL_SEARCH,
		"intel left to find: still searching")


func _test_transmit_and_extraction() -> void:
	var ctx := RunContext.new(7)
	ctx.mission = &"intel_search"
	ctx.biome = &"town"
	var run := IslandRun.new(61, &"town")
	run.load_context(ctx)
	run.director.max_alive = 0
	_check(run.radio.has(&"land_intel_search") and run.intel_time_left == IslandRun.search_time_limit(),
		"landing: radio line, the clock starts at %.0f s" % IslandRun.search_time_limit())
	run.player_pos = run.map.boat
	_step(run, 10)
	_check(run.objective == IslandRun.Objective.GENERATORS, "searching: no extraction at the boat")
	run.radio.clear()
	for i in 3:
		_search(run, _spot(run, true))
	_check(run.intel_found() == 3 and run.intel_phase == IslandRun.INTEL_TRANSMIT and run.radio.has(&"intel_transmit")
		and run.site == run.uplink_pos, "all intel found: transmit phase, the goal is the uplink")
	_check(run.radio.count(&"intel_found") == 2, "radio after the first two finds, the uplink line after the last")
	var left: float = run.intel_time_left
	run.player_pos = run.map.boat
	_step(run, 60)
	_check(run.objective == IslandRun.Objective.GENERATORS and run.intel_time_left == left,
		"not transmitted: no extraction yet; the clock stops after the search")
	_relax(run)
	run.player_pos = run.uplink_pos + Vector3(IslandRun.transmit_radius() - 2.5, 0, 0)
	_step(run, int(5.0 / DT))
	_check(absf(run.transmit_progress - 5.0) < 0.05 and run.director.phase == Director.Phase.PEAK,
		"at the uplink: transmitting (%.1f s), spike" % run.transmit_progress)
	run.player_pos = run.uplink_pos + Vector3(IslandRun.transmit_radius() + 3.0, 0, 0)
	var t: float = run.transmit_progress
	_step(run, 60)
	_check(run.transmit_progress == t, "leaving the uplink pauses the transmission")
	_check(run.objective_text().begins_with("Transmit the intel (") and run.objective_text().ends_with(" / 15 s)"), "objective '%s'" % run.objective_text())
	run.player_pos = run.uplink_pos
	_step(run, int((IslandRun.transmit_seconds() - 5.0 + 0.1) / DT))
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.radio.has(&"intel_done"),
		"transmitted: extraction opens, radio line")
	run.player_pos = run.map.boat
	_step(run, 2)
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() >= 40 + 3 * IslandRun.intel_reward(),
		"at the boat the run is won (Intel %d)" % run.intel_earned())


func _test_timer_partial() -> void:
	var run := _quiet_run(43)
	_search(run, _spot(run, false))
	_search(run, _spot(run, true))
	var found_intel: int = run.intel_earned()
	run.player_pos = run.map.player_start
	run.intel_time_left = 1.0
	_step(run, int(1.1 / DT))
	_check(run.intel_phase == IslandRun.INTEL_TRANSMIT and run.intel_found() == 1 and run.objective == IslandRun.Objective.GENERATORS,
		"time up with 1 intel: the search ends, transmit what was found")
	_check(run.intel_earned() == found_intel and run.nearest_unsearched() != -1,
		"the found intel is kept (partial reward); spots left unsearched")
	# Standing at a spot after time is up does nothing.
	var k: int = run.nearest_unsearched()
	run.player_pos = run.search_pos[k]
	_step(run, int(IslandRun.search_seconds() / DT) + 10)
	_check(run.search_state[k] == IslandRun.SPOT_UNSEARCHED and run.search_progress[k] == 0.0, "no searching once time is up")
	run.player_pos = run.uplink_pos
	_step(run, int((IslandRun.transmit_seconds() + 0.1) / DT))
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "partial transmission done: extraction opens")


func _test_zero_found() -> void:
	var run := _quiet_run(44)
	_search(run, _spot(run, false))
	run.radio.clear()
	run.messages.clear()
	run.player_pos = run.map.player_start
	run.intel_time_left = 0.5
	_step(run, int(0.6 / DT))
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.intel_found() == 0 and run.transmit_progress == 0.0
		and run.radio.has(&"intel_none"), "time up with no intel: no transmission, extraction opens at once (no softlock)")
	_check(run.messages.has("No intel to send. Get back to the boat!"), "the message says there is nothing to send")
	var base := _quiet_run(44)
	run.player_pos = run.map.boat
	_step(run, 2)
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() >= 40, "the island can still be won (Intel %d, no mission bonus)" % run.intel_earned())
	_check(base.intel_found() == 0, "a fresh island starts with nothing found")


func _test_death_and_redeploy() -> void:
	var ctx := RunContext.new(9)
	ctx.mission = &"intel_search"
	ctx.biome = &"town"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	_search(run, _spot(run, true))
	run.hp = 0.0
	_step(run)
	_check(run.objective == IslandRun.Objective.LOST and run.is_over(), "dying mid-search ends the island")
	var again := IslandRun.new(ctx.island_seed(), ctx.biome)
	again.load_context(ctx)
	var fresh: bool = again.intel_found() == 0 and again.intel_phase == IslandRun.INTEL_SEARCH and again.transmit_progress == 0.0
	for k in again.search_pos.size():
		fresh = fresh and again.search_state[k] == IslandRun.SPOT_UNSEARCHED and again.search_progress[k] == 0.0
	_check(fresh and again.search_pos == run.search_pos and again.search_has_intel == run.search_has_intel
		and again.intel_time_left == IslandRun.search_time_limit(), "a redeployed island starts fresh, same spots and hidden intel")
	again.set_mission(&"activate")
	_check(again.search_pos.is_empty() and again.search_state.is_empty() and again.intel_time_left == 0.0,
		"switching mission clears the search")


func _test_draw() -> void:
	_check(GameData.mission_weight(&"intel_search", &"town") == 3 and GameData.mission_weight(&"intel_search", &"beach") == 1,
		"weights: Intel Search x3 on the Coastal Town, 1 elsewhere")
	_check(not GameData.route_missions_after(&"intel_search").has(&"intel_search"), "never Intel Search twice in a row")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1357
	var town: int = 0
	var port: int = 0
	var repeats: int = 0
	var n: int = 4000
	for k in n:
		if GameData.pick_route_mission(rng, &"", &"town") == &"intel_search":
			town += 1
		if GameData.pick_route_mission(rng, &"", &"port") == &"intel_search":
			port += 1
		if GameData.pick_route_mission(rng, &"intel_search", &"town") == &"intel_search":
			repeats += 1
	var want_town: float = GameData.mission_share(&"intel_search", &"town")
	var want_port: float = GameData.mission_share(&"intel_search", &"port")
	_check(absf(town / float(n) - want_town) < 0.03 and absf(port / float(n) - want_port) < 0.03,
		"draw shares: Town %.0f%% (expected %.0f%%), Port %.0f%% (expected %.0f%%)" % [100.0 * town / n, 100.0 * want_town, 100.0 * port / n, 100.0 * want_port])
	_check(repeats == 0, "no repeat even on the Town")
	var shares := PackedStringArray()
	for biome: StringName in GameData.ISLAND_BIOMES + [&"volcano"]:
		var row := PackedStringArray()
		for id: StringName in GameData.ROUTE_MISSIONS:
			row.append("%s %.0f%%" % [id, 100.0 * GameData.mission_share(id, biome)])
		shares.append("%s: %s" % [biome, ", ".join(row)])
	print("  (first-island shares)\n    " + "\n    ".join(shares))
	var boat_script: Script = load("res://game/states/boat.gd")
	var deterministic: bool = true
	var draws: int = 0
	var repeats_boat: int = 0
	var on_town: Array[int] = [0, 0]
	var elsewhere: Array[int] = [0, 0]
	for s in range(1, 61):
		for prev: StringName in GameData.ROUTE_MISSIONS:
			var first: Array = _boat_routes(boat_script, s, prev)
			if first != _boat_routes(boat_script, s, prev):
				deterministic = false
			for i in 2:
				var m: StringName = first[0][i]
				var b: StringName = first[1][i]
				draws += 1
				if GameData.mission_family(m) == GameData.mission_family(prev):
					repeats_boat += 1
				if prev == &"intel_search":
					continue
				var bucket: Array[int] = on_town if b == &"town" else elsewhere
				bucket[1] += 1
				if m == &"intel_search":
					bucket[0] += 1
	_check(deterministic and repeats_boat == 0 and draws > 0, "boat routes: %d draws, deterministic, %d repeats" % [draws, repeats_boat])
	var share_town: float = on_town[0] / maxf(1.0, on_town[1])
	var share_other: float = elsewhere[0] / maxf(1.0, elsewhere[1])
	_check(share_town > share_other * 1.5 and elsewhere[0] > 0,
		"boat routes: Intel Search on %.0f%% of Town routes, %.0f%% elsewhere (still possible)" % [100.0 * share_town, 100.0 * share_other])


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


## A bot walks to the nearest unsearched spot and stands in it, spot after
## spot, then to the uplink, then extracts (the soak test's navigation;
## invincible: this checks completability and measures the pacing with the
## real horde).
func _test_bot() -> void:
	for s in [404, 505, 606]:
		var ctx := RunContext.new(s)
		ctx.threat = 2
		ctx.mission = &"intel_search"
		ctx.biome = &"town" if s != 505 else &"beach"
		var run := IslandRun.new(ctx.island_seed(), ctx.biome)
		run.load_context(ctx)
		_bot(run, "bot seed %d (%s)" % [s, ctx.biome])


func _bot(run: IslandRun, label: String) -> void:
	var nav := FlowField.new(run.field.width, run.field.height)
	nav.blocked = run.field.blocked
	var goal := Vector3.INF
	var steps: int = 0
	var peak_enemies: int = 0
	var searched_at: float = -1.0
	var transmitted_at: float = -1.0
	while not run.is_over() and steps < int(900.0 / DT):
		steps += 1
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.hp = 10000.0
		var g: Vector3 = run.site if run.objective == IslandRun.Objective.GENERATORS else run.extraction_point()
		g = Vector3(floorf(g.x) + 0.5, 0, floorf(g.z) + 0.5)
		if g != goal:
			goal = g
			nav.compute_now(nav.world_to_cell(goal))
		var move := Vector2.ZERO
		var stp: Vector2 = nav.direction_at(run.player_pos)
		if stp != Vector2.ZERO:
			var c := Vector2(floori(run.player_pos.x) + stp.x + 0.5, floori(run.player_pos.z) + stp.y + 0.5)
			move = (c - Vector2(run.player_pos.x, run.player_pos.z)).normalized()
		elif run.player_pos.distance_to(goal) > 0.5:
			move = Vector2(goal.x - run.player_pos.x, goal.z - run.player_pos.z).normalized()
		var aim := Vector3(move.x, 0, move.y)
		var close: PackedInt32Array = run.horde.query_radius(run.player_pos, 15.0)
		if close.size() > 0:
			aim = run.horde.positions[close[0]] - run.player_pos
		run.step(DT, move, aim, close.size() > 10)
		if searched_at < 0.0 and run.intel_phase != IslandRun.INTEL_SEARCH:
			searched_at = run.time_alive - run.landed_time
		if transmitted_at < 0.0 and run.intel_phase == IslandRun.INTEL_DONE:
			transmitted_at = run.time_alive - run.landed_time
		peak_enemies = maxi(peak_enemies, run.horde.count)
	var searched: int = 0
	for st in run.search_state:
		if st != IslandRun.SPOT_UNSEARCHED:
			searched += 1
	_check(run.objective == IslandRun.Objective.WON,
		"%s: %s in %.0f s; search ended at %.0f s (%d / %d intel, %d / %d spots searched, %.0f s left), transmitted at %.0f s; %d kills, up to %d enemies alive, Intel %d" % [
		label, run.objective_text(), run.time_alive - run.landed_time, searched_at, run.intel_found(), run.intel_total(),
		searched, run.search_pos.size(), run.intel_time_left, transmitted_at, run.kills, peak_enemies, run.intel_earned()])


## The Island scene with Intel Search, in each camera mode: spots and the
## uplink are built and drawn, the HUD, its marker and the minimap key show
## them, and standing at a spot searches it through the scene's own loop.
func _test_scene() -> void:
	var profile := MemoryProfile.new()
	var ctx := RunContext.new(5)
	ctx.mission = &"intel_search"
	ctx.biome = &"town"
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
	var spots: Array = island.get("_search_spots")
	_check(spots.size() == run.search_pos.size() and spots.size() == 5 and island.get("_uplink") != null,
		"the scene builds %d search spots and the uplink" % spots.size())
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"search") and legend.has(&"uplink"), "the minimap key shows SEARCH and UPLINK")
	var hud: Hud = island.get("hud")
	var objective: Label = hud.get("_objective")
	_check(objective.text.begins_with("INTEL 0 / 3 · 2:00"), "HUD objective '%s'" % objective.text)
	var minimap: Minimap = hud.get("_minimap")
	if minimap != null:
		minimap.queue_redraw()
		await process_frame
		_check(minimap.drawn_kinds.has(&"search") and minimap.drawn_kinds.has(&"uplink"), "the minimap draws the spots and the uplink")
	var marker: Label = hud.get("_marker")
	var k: int = 0
	for mode in [Profile.CameraMode.FIRST_PERSON, Profile.CameraMode.THIRD_PERSON, Profile.CameraMode.FIXED]:
		var mode_name: String = Profile.CAMERA_MODE_NAMES[mode]
		island.call("_set_camera_mode", mode, false)
		# At most two intel found before the last mode (the third would end the search).
		k = _spot(run, false) if run.intel_found() >= 2 else run.nearest_unsearched()
		run.player_pos = run.search_pos[k]
		var to: Vector3 = run.search_pos[k] - run.map.player_start
		island.set("_tp_yaw", atan2(-to.x, -to.z))
		run.facing = Vector3(to.x, 0, to.z).normalized() if to.length() > 0.1 else Vector3(0, 0, -1)
		for i in 60:
			await physics_frame
			await process_frame
		var rings: Array = island.get("_search_rings")
		_check(run.search_progress[k] > 0.0 and marker.text.begins_with("SEARCHING ·") and (rings[k] as Node3D).visible,
			"%s: standing at a spot searches it (%.1f s), marker '%s'" % [mode_name, run.search_progress[k], marker.text])
		# Finish it (empty or full) and check the spot's state is drawn.
		run.search_progress[k] = IslandRun.search_seconds() - 0.01
		for i in 3:
			await physics_frame
			await process_frame
		var beacon: MeshInstance3D = (island.get("_search_beacons") as Array)[k]
		var greyed: bool = (island.get("_search_greyed") as Array)[k]
		var empty: bool = run.search_state[k] == IslandRun.SPOT_EMPTY
		_check(run.search_state[k] != IslandRun.SPOT_UNSEARCHED and not beacon.visible and greyed == empty,
			"%s: a searched spot loses its beacon (%s)" % [mode_name, "empty: greyed" if empty else "intel found"])
	# Transmit phase: the uplink ring shows, the HUD and the marker follow.
	for j in run.search_pos.size():
		if run.search_has_intel[j] and run.search_state[j] == IslandRun.SPOT_UNSEARCHED:
			run.search_state[j] = IslandRun.SPOT_FOUND
	run.player_pos = run.uplink_pos
	for i in 30:
		await physics_frame
		await process_frame
	var ring: MeshInstance3D = island.get("_uplink_ring")
	_check(run.intel_phase == IslandRun.INTEL_TRANSMIT and ring.visible and run.transmit_progress > 0.0
		and objective.text == "TRANSMIT INTEL 3 / 3" and marker.text.begins_with("TRANSMITTING ·"),
		"transmit phase: uplink ring, HUD '%s', marker '%s'" % [objective.text, marker.text])
	island.queue_free()
	await process_frame
	_finish()
