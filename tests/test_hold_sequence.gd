extends SceneTree
## Hold Sequence (docs/design/OBJECTIVES_PROPOSAL.md, step 1): hold points
## A -> B -> C in order; leaving pauses a point; each point's start calls a
## horde spike; the extraction stays locked until every point is held.
## Also: HoldPoint_* markers (order, reachability), the fallback points on
## maps without markers, the boat's no-repeat rule and a bot run.
## Run: godot --headless --path . --script res://tests/test_hold_sequence.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


func _initialize() -> void:
	_test_data()
	_test_order_and_pause()
	_test_spikes_and_extraction()
	_test_fallback_points()
	_test_handmade_islands()
	_test_markers_ordered()
	_test_no_repeat()
	_test_bot()
	_test_berlenga_part_3()
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		print("TEST FAIL: " + what)
		_failures += 1


func _step(run: IslandRun, n: int = 1) -> void:
	for k in n:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)


## A run on a generated island with no enemies (rules only).
func _quiet_run(rng_seed: int) -> IslandRun:
	var run := IslandRun.new(rng_seed)
	run.director.max_alive = 0
	run.set_mission(&"hold_sequence")
	return run


func _test_data() -> void:
	var m: Dictionary = GameData.MISSIONS.get(&"hold_sequence", {})
	_check(not m.is_empty() and m["name"] == "Hold Sequence" and int(m["points"]) == 3
		and float(m["seconds"]) > 0.0 and float(m["radius"]) > 0.0,
		"hold_sequence.tres: %d points, %.0f s each, %.1f m radius" % [int(m.get("points", 0)), float(m.get("seconds", 0)), float(m.get("radius", 0))])
	_check(GameData.ROUTE_MISSIONS.has(&"hold_sequence") and not GameData.ROUTE_MISSIONS.has(&"holdout"),
		"Hold Sequence is offered on archipelago routes (%s)" % [GameData.ROUTE_MISSIONS])
	_check(IslandRun.hold_count_wanted() == 3 and IslandRun.hold_seconds() == float(m.get("seconds", 0))
		and IslandRun.hold_radius() == float(m.get("radius", 0)), "the run reads its numbers from the data")
	_check(Story.RADIO.has(&"land_hold_sequence") and Story.RADIO.has(&"hold_point") and Story.RADIO.has(&"hold_done"),
		"radio lines for the start, each point and the end")


func _test_order_and_pause() -> void:
	var run := _quiet_run(21)
	_check(run.hold_points.size() == 3 and run.site == run.hold_points[0] and run.hold_index == 0,
		"three points, the first is the active site")
	var secs: float = IslandRun.hold_seconds()
	# Standing on point 2 first does nothing: the order is enforced.
	run.player_pos = run.hold_points[1]
	_step(run, int(secs / DT) + 30)
	_check(run.hold_index == 0 and run.hold_progress == 0.0 and not run.hold_started,
		"point 2 before point 1: no progress")
	# Half of point 1, then leave: the progress pauses (it is kept, not lost).
	run.player_pos = run.hold_points[0]
	_step(run, int(secs * 0.5 / DT))
	var half: float = run.hold_progress
	_check(half > secs * 0.45 and half < secs * 0.55, "half of point 1 held (%.1f s)" % half)
	run.player_pos = run.hold_points[0] + Vector3(IslandRun.hold_radius() + 3.0, 0, 0)
	_step(run, 120)
	_check(is_equal_approx(run.hold_progress, half) and run.hold_index == 0, "outside the point the progress pauses")
	run.player_pos = run.hold_points[0]
	_step(run, int(secs * 0.5 / DT) + 5)
	_check(run.hold_index == 1 and run.site == run.hold_points[1] and run.hold_progress < 0.2,
		"back in: point 1 held, point 2 is now the site")
	_check(run.objective_text().begins_with("Hold point 2 / 3"), "objective text: '%s'" % run.objective_text())


func _test_spikes_and_extraction() -> void:
	var ctx := RunContext.new(5)
	ctx.mission = &"hold_sequence"
	var run := IslandRun.new(33)
	run.load_context(ctx)
	run.director.max_alive = 0
	_check(run.radio.has(&"land_hold_sequence"), "landing radio line")
	run.radio.clear()
	var secs: float = IslandRun.hold_seconds()
	var spikes: int = 0
	for k in run.hold_points.size():
		run.director.phase = Director.Phase.RELAX
		run.player_pos = run.hold_points[k]
		_step(run)
		if run.director.phase == Director.Phase.PEAK:
			spikes += 1
		if k < run.hold_points.size() - 1:
			_step(run, int(secs / DT) + 5)
			# Not done yet: the boat does not take you.
			run.player_pos = run.map.boat
			_step(run, 30)
			if run.objective != IslandRun.Objective.GENERATORS:
				break
	_check(spikes == run.hold_points.size(), "a spike when each point starts (%d of %d)" % [spikes, run.hold_points.size()])
	_check(run.objective == IslandRun.Objective.GENERATORS and run.holds_done() == 2,
		"extraction locked with %d of 3 points held" % run.holds_done())
	_check(run.radio.count(&"hold_point") == 2, "radio after each point (%d)" % run.radio.count(&"hold_point"))
	run.player_pos = run.hold_points[2]
	_step(run, int(secs / DT) + 5)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.radio.has(&"hold_done"),
		"all points held: extraction open, 'done' radio line")
	run.player_pos = run.map.boat
	_step(run, 2)
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() > 0, "at the boat: extracted (Intel %d)" % run.intel_earned())


## Every point reachable from the start, with open ground, away from the
## boat and from each other. Returns the smallest spacing.
func _check_points(map: IslandMap, pts: Array[Vector3], label: String) -> float:
	var f: FlowField = map.field
	var saved: int = f.max_distance
	f.max_distance = 0
	f.compute_now(f.world_to_cell(map.player_start))
	var bad: int = 0
	var spacing: float = INF
	for i in pts.size():
		if f.distance_at(pts[i]) >= FlowField.UNREACHABLE or Vector2(pts[i].x - map.boat.x, pts[i].z - map.boat.z).length() < IslandMap.HOLD_MIN_FROM_BOAT:
			bad += 1
		for k in map.lava.size():
			if Vector2(pts[i].x - map.lava[k].x, pts[i].z - map.lava[k].z).length() < map.lava_radius[k] + 1.0:
				bad += 1
		for j in range(i + 1, pts.size()):
			spacing = minf(spacing, Vector2(pts[i].x - pts[j].x, pts[i].z - pts[j].z).length())
	var ordered: bool = true
	for i in range(1, pts.size()):
		if f.distance_at(pts[i]) < f.distance_at(pts[i - 1]):
			ordered = false
	f.max_distance = saved
	_check(pts.size() == 3 and bad == 0 and ordered and spacing >= IslandMap.HOLD_MIN_SPACING,
		"%s: 3 points reachable, off the boat, nearest first, min spacing %.0f m" % [label, spacing])
	return spacing


func _test_fallback_points() -> void:
	var wide: int = 0
	var total: int = 0
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		for s in [3, 77]:
			var a := IslandRun.new(s, biome)
			a.set_mission(&"hold_sequence")
			var b := IslandRun.new(s, biome)
			b.set_mission(&"hold_sequence")
			_check(a.hold_points == b.hold_points, "%s seed %d: same seed, same points" % [biome, s])
			total += 1
			if _check_points(a.map, a.hold_points, "%s seed %d" % [biome, s]) >= IslandMap.HOLD_SPACING:
				wide += 1
	_check(wide == total, "generated islands keep the full %d m spacing (%d of %d)" % [int(IslandMap.HOLD_SPACING), wide, total])
	var x := IslandRun.new(3, &"beach")
	x.set_mission(&"hold_sequence")
	var y := IslandRun.new(4, &"beach")
	y.set_mission(&"hold_sequence")
	_check(x.hold_points != y.hold_points, "another seed, other points")


## The archipelago's hand-made islands have no HoldPoint markers yet: the
## fallback must work on their real grids too.
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
		var t0: int = Time.get_ticks_msec()
		var pts: Array[Vector3] = map.hold_points if not map.hold_points.is_empty() else IslandMap.pick_hold_points(map, 3, 9, IslandRun.hold_radius())
		print("  %s: points picked in %d ms" % [path.get_file(), Time.get_ticks_msec() - t0])
		_check_points(map, pts, path.get_file())


func _test_markers_ordered() -> void:
	var hm := HandmadeIsland.new()
	hm.size = 120
	var markers := Node3D.new()
	markers.name = "Markers"
	hm.add_child(markers)
	var spots: Dictionary = {"Boat": Vector3(60, 0, 110), "PlayerStart": Vector3(60, 0, 104),
		"HoldPoint_10": Vector3(90, 0, 30), "HoldPoint_2": Vector3(30, 0, 50), "HoldPoint_1": Vector3(60, 0, 70)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.position = spots[n]
		markers.add_child(m)
	root.add_child(hm)
	hm.mission = &"hold_sequence"
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	var want: Array[Vector3] = [Vector3(60.5, 0, 70.5), Vector3(30.5, 0, 50.5), Vector3(90.5, 0, 30.5)]
	_check(map.hold_points == want, "HoldPoint_1, _2, _10 in number order (%s)" % [map.hold_points])
	_check(problems.is_empty(), "markers reachable, no problems (%s)" % [problems])
	var run := IslandRun.new(1, &"beach", map)
	run.set_mission(&"hold_sequence")
	_check(run.hold_points == want and run.site == want[0], "the run holds the markers, not picked points")
	# A HoldPoint outside the walkable area is reported, like other markers.
	hm.play_area = PackedVector2Array([Vector2(10, 40), Vector2(110, 40), Vector2(110, 118), Vector2(10, 118)])
	problems.clear()
	hm.build_map(problems)
	var reported: bool = false
	for p in problems:
		if p.begins_with("HoldPoint at (90, 30)"):
			reported = true
	_check(reported, "an unreachable HoldPoint is reported (%s)" % [problems])
	_check(HandmadeIsland.hold_point_number("HoldPoint_3") == 3 and HandmadeIsland.hold_point_number("HoldPoint12") == 12
		and HandmadeIsland.hold_point_number("HoldPoint") == -1, "suffix numbers")
	hm.free()


func _test_no_repeat() -> void:
	_check(GameData.route_missions_after(&"") == GameData.ROUTE_MISSIONS, "first island: every route mission")
	_check(not GameData.route_missions_after(&"defend").has(&"defend") and not GameData.route_missions_after(&"holdout").has(&"defend")
		and not GameData.route_missions_after(&"hold_sequence").has(&"hold_sequence")
		and GameData.route_missions_after(&"activate").size() == GameData.ROUTE_MISSIONS.size() - 1,
		"never the same mission (or family: defend/holdout) twice in a row")
	var boat_script: Script = load("res://game/states/boat.gd")
	var repeats: int = 0
	var draws: int = 0
	var deterministic: bool = true
	for s in range(1, 41):  # seed 0 = random
		for prev: StringName in GameData.ROUTE_MISSIONS:
			var first: Array = _boat_missions(boat_script, s, prev)
			if first != _boat_missions(boat_script, s, prev):
				deterministic = false
			for m: StringName in first:
				draws += 1
				if GameData.mission_family(m) == GameData.mission_family(prev):
					repeats += 1
	_check(repeats == 0 and draws > 0, "boat routes: %d draws, %d repeats of the last mission" % [draws, repeats])
	_check(deterministic, "boat routes: same seed, same missions")


## The two route missions the boat draws for seed `s` after `prev`.
func _boat_missions(boat_script: Script, s: int, prev: StringName) -> Array:
	var ctx := RunContext.new(s)
	ctx.island_index = 1
	ctx.mission = prev
	var boat := Control.new()
	boat.set_script(boat_script)
	boat.set("context", ctx)
	(boat.get("_rng") as RandomNumberGenerator).seed = ctx.island_seed() + 1
	boat.call("_make_routes")
	var out: Array = (boat.get("_route_missions") as Array).duplicate()
	boat.free()
	return out


## A bot walks to the active point, holds it, and extracts (the soak test's
## navigation; invincible: this checks completability, not balance).
func _test_bot() -> void:
	for s in [404, 505]:
		var ctx := RunContext.new(s)
		ctx.threat = 2
		ctx.mission = &"hold_sequence"
		ctx.biome = &"town" if s == 404 else &"beach"
		var run := IslandRun.new(ctx.island_seed(), ctx.biome)
		run.load_context(ctx)
		_bot(run, "bot seed %d (%s)" % [s, ctx.biome])


## Berlenga part 3 (Southwest Coast) as the expedition plays it: its three
## HoldPoint markers, then out through the Exit beside the start.
func _test_berlenga_part_3() -> void:
	var part: Dictionary = Expeditions.ALL[&"berlenga"][2]
	_check(part["mission"] == &"hold_sequence", "Berlenga part 3 is a Hold Sequence")
	if not ResourceLoader.exists(String(part["scene"])):
		_check(false, "part 3 scene exists")
		return
	var hm: HandmadeIsland = (load(String(part["scene"])) as PackedScene).instantiate()
	root.add_child(hm)
	var map: IslandMap = hm.build_map()
	_check(hm.mission == &"hold_sequence" and map.hold_points.size() == 3, "part 3 scene: mission '%s', %d HoldPoint markers" % [hm.mission, map.hold_points.size()])
	hm.free()
	var ctx := RunContext.new(31)
	ctx.start_expedition(&"berlenga", 2)
	ctx.threat = 2
	var run := IslandRun.new(ctx.island_seed(), ctx.biome, map)
	run.load_context(ctx)
	_check(run.hold_points == map.hold_points and run.has_exit(), "the run holds the markers and leaves by the Exit")
	_bot(run, "Berlenga part 3 bot")


func _bot(run: IslandRun, label: String) -> void:
	var nav := FlowField.new(run.field.width, run.field.height)
	nav.blocked = run.field.blocked
	var goal := Vector3.INF
	var steps: int = 0
	var peak_enemies: int = 0
	while not run.is_over() and steps < int(600.0 / DT):
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
		var near: PackedInt32Array = run.horde.query_radius(run.player_pos, 20.0)
		var aim := Vector3(move.x, 0, move.y)
		if near.size() > 0:
			aim = run.horde.positions[near[0]] - run.player_pos
		run.step(DT, move, aim, near.size() > 10)
		peak_enemies = maxi(peak_enemies, run.horde.count)
	_check(run.objective == IslandRun.Objective.WON and run.holds_done() == run.hold_points.size(),
		"%s: %s in %.0f s, %d points, %d kills, up to %d enemies alive" % [label,
		run.objective_text(), run.time_alive - run.landed_time, run.holds_done(), run.kills, peak_enemies])
