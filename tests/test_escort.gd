extends SceneTree
## Escort (docs/design/OBJECTIVES_PROPOSAL.md, step 7; "Escoltar por
## percurso"): a cart moves along a route only while the player is within
## escort_radius() of it; an enemy just in front of it blocks it; enemies
## touching it wear its HP down and at 0 it breaks down until the player
## stands by it to repair it (never a mission fail); at each stop it halts
## with a horde spike; delivered at the end, the extraction opens.
## Also: data, EscortRoute_*/EscortStop_*/EscortEnd/EscortSurvivor markers,
## the seeded fallback route (walkable, deterministic, 150-230 m on foot
## back to the boat), death and redeploy, the boat draw (weight 1, no
## repeat), bots, the Island scene in the three cameras, and Berlenga part
## 1, where a survivor walks the climbing path.
## Run: godot --headless --path . --script res://tests/test_escort.gd

const DT: float = 1.0 / 60.0
const PART_1: String = "res://game/world/handmade/expeditions/berlenga/part_1.scn"
## Where the bot walks: this far ahead of the cart, on its route (clearing
## the way: 4 m ahead finished every test seed; 5 m behind, 4 m to the side
## and 2 m behind + 3 m aside left some unfinished in 900 s).
const BOT_AHEAD: float = 4.0

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _done: bool = false


func _initialize() -> void:
	GameInput.setup()
	create_timer(1500.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "escort tests finished in time")
			_finish())
	_test_data()
	_test_fallback_route()
	_test_handmade_islands()
	_test_markers()
	_test_advance_when_near()
	_test_blocking()
	_test_damage_and_repair()
	_test_stops()
	_test_extraction()
	_test_death_and_redeploy()
	_test_draw()
	_test_berlenga()
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


## A run on a generated island with no enemies spawning and no firing
## (rules only: tests add the enemies they need).
func _quiet_run(rng_seed: int, biome: StringName = &"beach", map: IslandMap = null) -> IslandRun:
	var run := IslandRun.new(rng_seed, biome, map)
	run.director.max_alive = 0
	run.set_mission(&"escort")
	_hold_fire(run)
	return run


func _hold_fire(run: IslandRun) -> void:
	run._fire_cd = 1.0e9


func _relax(run: IslandRun) -> void:
	run.director.phase = Director.Phase.RELAX
	run.director.phase_time = 1000.0


func _step(run: IslandRun, n: int = 1) -> void:
	for k in n:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)


## Steps with the player standing on the cart (always near it).
func _walk_with(run: IslandRun, seconds: float) -> void:
	for k in int(seconds / DT):
		run.player_pos = run.escort_pos
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)


## Moves the cart to `d` metres along the route (tests skip the walking).
func _jump(run: IslandRun, d: float) -> void:
	run.escort_dist = d
	run._place_escort()
	run.player_pos = run.escort_pos


## A stunned enemy (it does not move) at `p`, with HP to spare.
func _enemy_at(run: IslandRun, p: Vector3) -> int:
	var i: int = run.horde.add(p, GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[i] = 1000.0
	return i


func _test_data() -> void:
	var m: Dictionary = GameData.MISSIONS.get(&"escort", {})
	_check(not m.is_empty() and m["name"] == "Escort" and int(m["points"]) == 2 and float(m["seconds"]) > 0.0
		and float(m["radius"]) > 0.0 and float(m["spike_seconds"]) > 0.0 and float(m["escort_speed"]) > 0.0
		and float(m["escort_hp"]) > 0.0 and float(m["block_radius"]) > 0.0 and float(m["repair_seconds"]) > 0.0
		and float(m["repair_hp"]) > 0.0 and float(m["repair_hp"]) <= 1.0 and float(m["route_min"]) < float(m["route_max"]),
		"escort.tres: %d stops of %.0f s (spike %.0f s), moves at %.1f m/s within %.0f m, %.0f HP (%.0f/s per enemy), blocked within %.0f m, repair %.0f s at %.0f m to %.0f%%, route %.0f-%.0f m" % [
		int(m.get("points", 0)), float(m.get("seconds", 0)), float(m.get("spike_seconds", 0)), float(m.get("escort_speed", 0)),
		float(m.get("radius", 0)), float(m.get("escort_hp", 0)), float(m.get("escort_hit_dps", 0)), float(m.get("block_radius", 0)),
		float(m.get("repair_seconds", 0)), float(m.get("repair_radius", 0)), 100.0 * float(m.get("repair_hp", 0)),
		float(m.get("route_min", 0)), float(m.get("route_max", 0))])
	_check(GameData.ROUTE_MISSIONS.has(&"escort") and GameData.ROUTE_MISSIONS[-1] == &"escort",
		"Escort is offered on archipelago routes (last in order)")
	_check(IslandRun.stop_count_wanted() == 2 and IslandRun.stop_seconds() == float(m.get("seconds", 0))
		and IslandRun.escort_radius() == float(m.get("radius", 0)) and IslandRun.escort_speed() == float(m.get("escort_speed", 0))
		and IslandRun.escort_max_hp() == float(m.get("escort_hp", 0)) and IslandRun.block_radius() == float(m.get("block_radius", 0))
		and IslandRun.repair_seconds() == float(m.get("repair_seconds", 0)) and IslandRun.repair_hp() == float(m.get("repair_hp", 0))
		and IslandRun.escort_route_min() == float(m.get("route_min", 0)),
		"the run reads its numbers from the data")
	var cues: bool = true
	for cue: StringName in [&"land_escort", &"escort_stop", &"escort_broken", &"escort_done"]:
		cues = cues and Story.RADIO.has(cue) and Story.RADIO.has(StringName(String(cue) + "_survivor"))
	_check(cues, "radio lines for landing, stops, breakdowns and the delivery, cart and survivor")
	_check(Briefing.ADVICE.has(&"escort"), "briefing advice for Escort")


## The route's path: every point on open ground, every straight piece
## clear, starting at the route's first point and ending at `end`.
func _path_walkable(map: IslandMap, path: PackedVector3Array) -> bool:
	for p in path:
		var c: Vector2i = map.field.world_to_cell(p)
		if map.field.is_blocked(c.x, c.y):
			return false
	for i in range(1, path.size()):
		var a: Vector3 = path[i - 1]
		var b: Vector3 = path[i]
		var n: int = ceili(_flat_dist(a, b) / 0.25)
		for k in n + 1:
			var p: Vector3 = a.lerp(b, float(k) / maxf(1.0, n))
			if map.field.is_blocked(floori(p.x), floori(p.z)):
				return false
	return true


## Walking distance (m) from `from` to `to` on the map's grid.
func _walk(map: IslandMap, from: Vector3, to: Vector3) -> int:
	var nav := FlowField.new(map.field.width, map.field.height)
	nav.blocked = map.field.blocked
	nav.compute_now(nav.world_to_cell(to))
	return nav.distance_at(from)


func _test_fallback_route() -> void:
	var lengths := PackedStringArray()
	var in_band: int = 0
	var total: int = 0
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		for s in [3, 77]:
			var t0: int = Time.get_ticks_msec()
			var a := _quiet_run(s, biome)
			var ms: int = Time.get_ticks_msec() - t0
			var b := _quiet_run(s, biome)
			_check(a.escort_path == b.escort_path and a.escort_stop_at == b.escort_stop_at and a.escort_path.size() >= 2,
				"%s seed %d: same seed, same route (%d points, built in %d ms)" % [biome, s, a.escort_path.size(), ms])
			var start: Vector3 = a.escort_path[0]
			var end: Vector3 = a.escort_path[a.escort_path.size() - 1]
			var walk_in: int = _walk(a.map, a.map.player_start, start)
			var walk_back: int = _walk(a.map, start, a.extraction_point())
			_check(_path_walkable(a.map, a.escort_path) and walk_in < FlowField.UNREACHABLE and _flat_dist(end, a.extraction_point()) < 1.5
				and not a.escort_survivor and a.escort_pos == start and a.site == start,
				"%s seed %d: walkable route of %.0f m from a reachable start (%d m from the landing) to the boat" % [biome, s, a.escort_length, walk_in])
			var lava: int = 0
			for p in a.escort_path:
				for k in a.map.lava.size():
					if _flat_dist(p, a.map.lava[k]) < a.map.lava_radius[k]:
						lava += 1
			_check(lava == 0, "%s seed %d: the route stays out of the lava" % [biome, s])
			var even: bool = a.escort_stop_at.size() == 2 and absf(a.escort_stop_at[0] - a.escort_length / 3.0) < 0.01 \
				and absf(a.escort_stop_at[1] - a.escort_length * 2.0 / 3.0) < 0.01
			_check(even, "%s seed %d: 2 stops at a third and two thirds (%.0f m, %.0f m)" % [biome, s,
				a.escort_stop_at[0] if a.escort_stop_at.size() > 0 else -1.0, a.escort_stop_at[1] if a.escort_stop_at.size() > 1 else -1.0])
			lengths.append("%s/%d %.0f m (walk %d m)" % [biome, s, a.escort_length, walk_back])
			total += 1
			if walk_back >= int(IslandRun.escort_route_min()) - 1 and walk_back <= int(IslandRun.escort_route_max()) + 1:
				in_band += 1
	_check(in_band >= total * 0.8, "generated islands: %d / %d routes start 150-230 m on foot from the boat (%s)" % [in_band, total, ", ".join(lengths)])
	var x := _quiet_run(3)
	var y := _quiet_run(4)
	_check(x.escort_path != y.escort_path, "another seed, another route")


## The archipelago's hand-made islands (no escort markers): the fallback
## must find a walkable route on their real grids.
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
		var run := _quiet_run(9, map.biome, map)
		var walk_in: int = _walk(map, map.player_start, run.escort_path[0])
		_check(run.escort_path.size() >= 2 and _path_walkable(map, run.escort_path) and walk_in < FlowField.UNREACHABLE
			and _flat_dist(run.escort_path[run.escort_path.size() - 1], run.extraction_point()) < 1.5,
			"%s: walkable route of %.0f m, %d m from the landing, to the boat" % [path.get_file(), run.escort_length, walk_in])


func _test_markers() -> void:
	var hm := HandmadeIsland.new()
	hm.size = 120
	var markers := Node3D.new()
	markers.name = "Markers"
	hm.add_child(markers)
	var spots: Dictionary = {"Boat": Vector3(60, 0, 110), "PlayerStart": Vector3(60, 0, 104),
		"EscortRoute_2": Vector3(90, 0, 40), "EscortRoute_1": Vector3(30, 0, 30), "EscortRoute_3": Vector3(90, 0, 90),
		"EscortStop_2": Vector3(91, 0, 70), "EscortStop_1": Vector3(60, 0, 36), "EscortEnd": Vector3(70, 0, 100)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.position = spots[n]
		markers.add_child(m)
	root.add_child(hm)
	hm.mission = &"escort"
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	var want: Array[Vector3] = [Vector3(30.5, 0, 30.5), Vector3(90.5, 0, 40.5), Vector3(90.5, 0, 90.5)]
	_check(map.escort_route == want and map.escort_stops.size() == 2 and map.escort_stops[0] == Vector3(60.5, 0, 36.5)
		and map.escort_end == Vector3(70.5, 0, 100.5) and not map.escort_survivor,
		"EscortRoute_1.._3 in number order, EscortStop_1, _2 and EscortEnd read (%s)" % [map.escort_route])
	_check(problems.is_empty(), "markers reachable, no problems (%s)" % [problems])
	var run := _quiet_run(1, &"beach", map)
	var on_route: bool = _flat_dist(run.escort_path[0], want[0]) < 0.1 and _flat_dist(run.escort_path[run.escort_path.size() - 1], map.escort_end) < 0.1
	# Each waypoint is on the path (the path passes within a metre of it).
	for w in want:
		var near: float = INF
		for p in run.escort_path:
			near = minf(near, _flat_dist(p, w))
		on_route = on_route and near < 1.0
	_check(on_route and _path_walkable(map, run.escort_path), "the run follows the markers: start, waypoints, EscortEnd (%.0f m)" % run.escort_length)
	# Stops: each marker moved onto the route, in order along it.
	var s0: Vector3 = run.stop_pos(0)
	var s1: Vector3 = run.stop_pos(1)
	_check(run.escort_stop_at.size() == 2 and run.escort_stop_at[0] < run.escort_stop_at[1] and _flat_dist(s0, Vector3(60.5, 0, 36.5)) < 1.5
		and _flat_dist(s1, Vector3(91.5, 0, 70.5)) < 1.5, "stops projected onto the route (%.0f m and %.0f m along it)" % [run.escort_stop_at[0], run.escort_stop_at[1]])
	# Delivered at the EscortEnd, the extraction is still the boat.
	_check(run.escort_end_point() == map.escort_end and run.extraction_point() == map.boat, "EscortEnd is the delivery point; out at the boat")
	# A survivor marker: the route starts there and a survivor walks it.
	var sv := Marker3D.new()
	sv.name = "EscortSurvivor"
	sv.position = Vector3(20, 0, 20)
	markers.add_child(sv)
	map = hm.build_map(problems)
	_check(map.escort_survivor and map.escort_route.size() == 4 and map.escort_route[0] == Vector3(20.5, 0, 20.5),
		"EscortSurvivor: a survivor, waiting before EscortRoute_1")
	var srun := _quiet_run(1, &"beach", map)
	_check(srun.escort_survivor and srun.escort_noun() == "survivor" and srun.escort_cue(&"escort_stop") == &"escort_stop_survivor"
		and srun.objective_text().begins_with("Escort the survivor"), "the survivor variant ('%s')" % srun.objective_text())
	hm.play_area = PackedVector2Array([Vector2(10, 50), Vector2(110, 50), Vector2(110, 118), Vector2(10, 118)])
	problems.clear()
	hm.build_map(problems)
	var reported: bool = false
	for p in problems:
		if "EscortRoute" in p and "(30, 30)" in p:
			reported = true
	_check(reported, "an unreachable EscortRoute marker is reported (%s)" % [problems])
	hm.queue_free()
	_check(HandmadeIsland.marker_number("EscortStop_3", "EscortStop") == 3, "EscortStop_* numbers")


func _test_advance_when_near() -> void:
	var run := _quiet_run(11)
	_relax(run)
	_check(run.escort_status == IslandRun.ESC_WAITING and run.escort_dist == 0.0 and run.objective_text().begins_with("Escort the cart (0%"),
		"landing: the cart waits ('%s')" % run.objective_text())
	# Far away: it does not move.
	_step(run, int(2.0 / DT))
	_check(run.escort_dist == 0.0 and run.escort_status == IslandRun.ESC_WAITING, "the player far away: the cart waits")
	# Just outside the radius: still waits; inside: moves at its speed.
	run.player_pos = run.escort_pos + Vector3(IslandRun.escort_radius() + 0.5, 0, 0)
	_step(run, 30)
	_check(run.escort_dist == 0.0, "just outside %.0f m: still waiting" % IslandRun.escort_radius())
	run.player_pos = run.escort_pos + Vector3(IslandRun.escort_radius() - 1.0, 0, 0)
	_step(run)
	var first: float = run.escort_dist
	_walk_with(run, 2.0)
	var want: float = IslandRun.escort_speed() * 2.0
	_check(first > 0.0 and absf(run.escort_dist - first - want) < 0.1 and run.escort_status == IslandRun.ESC_MOVING and run.escort_started,
		"within %.0f m it moves at %.1f m/s (%.2f m in 2 s)" % [IslandRun.escort_radius(), IslandRun.escort_speed(), run.escort_dist - first])
	_check(_flat_dist(run.escort_pos, IslandMap.point_along(run.escort_path, run.escort_dist)) < 0.01 and run.site == run.escort_pos,
		"it moves along the route; the site follows it")
	# Walk away: it stops where it is.
	var d: float = run.escort_dist
	run.player_pos = run.escort_pos + Vector3(IslandRun.escort_radius() + 5.0, 0, 0)
	_step(run, int(1.0 / DT))
	_check(run.escort_dist == d and run.escort_status == IslandRun.ESC_WAITING, "the player walks off: it stops (kept %.2f m)" % d)
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"cart") and legend.has(&"route") and legend.has(&"stop"), "minimap key: CART, ROUTE and STOP")


func _test_blocking() -> void:
	var run := _quiet_run(12)
	_relax(run)
	_jump(run, 10.0)
	run.player_pos = run.escort_pos - run.escort_dir * 4.0
	# An enemy just in front of it, within the block radius: it cannot move.
	var e: int = _enemy_at(run, run.escort_pos + run.escort_dir * (IslandRun.block_radius() - 0.4))
	var d: float = run.escort_dist
	_step(run, int(1.0 / DT))
	_check(run.escort_dist == d and run.escort_status == IslandRun.ESC_BLOCKED and run.escort_blocked(),
		"an enemy %.1f m in front blocks the cart" % (IslandRun.block_radius() - 0.4))
	# Behind it: no block.
	run.horde.positions[e] = run.escort_pos - run.escort_dir * 1.2
	_step(run, int(1.0 / DT))
	_check(run.escort_dist > d and not run.escort_blocked(), "an enemy behind it does not (it moved %.2f m)" % (run.escort_dist - d))
	# Cleared out of the way: it rolls on.
	run.horde.remove(e)
	d = run.escort_dist
	_walk_with(run, 1.0)
	_check(run.escort_dist > d + 1.5 and run.escort_status == IslandRun.ESC_MOVING, "the way cleared: it moves again")


func _test_damage_and_repair() -> void:
	var run := _quiet_run(13)
	_relax(run)
	_jump(run, 5.0)
	run.player_pos = run.escort_pos + Vector3(IslandRun.escort_radius() + 4.0, 0, 0)  # it stays put
	var hp0: float = run.escort_hp
	# Two enemies touching it (beside it: the cart can still move).
	for side in [-1.0, 1.0]:
		_enemy_at(run, run.escort_pos + Vector3(-run.escort_dir.z, 0, run.escort_dir.x) * 0.8 * side)
	_step(run, int(1.0 / DT))
	var lost: float = hp0 - run.escort_hp
	_check(absf(lost - 2.0 * IslandRun.escort_hit_dps()) < 0.5, "2 enemies touching it: %.1f HP a second (%.1f lost)" % [2.0 * IslandRun.escort_hit_dps(), lost])
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	# Many touching: at most 6 count.
	for k in 10:
		_enemy_at(run, run.escort_pos + Vector3(cos(k * TAU / 10.0), 0, sin(k * TAU / 10.0)) * 1.0)
	var hp1: float = run.escort_hp
	_step(run, int(1.0 / DT))
	_check(absf((hp1 - run.escort_hp) - 6.0 * IslandRun.escort_hit_dps()) < 0.5, "10 touching: capped at 6 (%.1f HP lost)" % (hp1 - run.escort_hp))
	# Worn down to 0: broken down, no matter how near the player is.
	run.escort_hp = 1.0
	_step(run, 30)
	_check(run.escort_broken and run.escort_hp == 0.0 and run.escort_status == IslandRun.ESC_BROKEN and run.escort_breakdowns == 1
		and run.radio.has(&"escort_broken") and run.objective == IslandRun.Objective.GENERATORS and not run.is_over(),
		"at 0 HP it breaks down: no mission fail")
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	var d: float = run.escort_dist
	run.player_pos = run.escort_pos + Vector3(IslandRun.repair_radius() + 1.5, 0, 0)
	_step(run, int(2.0 / DT))
	_check(run.escort_dist == d and run.repair_progress == 0.0 and run.objective_text().begins_with("Repair the cart"),
		"broken: it does not move, and the repair needs the player within %.0f m ('%s')" % [IslandRun.repair_radius(), run.objective_text()])
	run.player_pos = run.escort_pos + Vector3(IslandRun.repair_radius() - 0.5, 0, 0)
	_step(run, int(2.0 / DT))
	var p: float = run.repair_progress
	run.player_pos = run.escort_pos + Vector3(IslandRun.repair_radius() + 2.0, 0, 0)
	_step(run, int(1.0 / DT))
	_check(absf(p - 2.0) < 0.05 and run.repair_progress == p, "repairing (%.2f s), leaving pauses it" % p)
	run.player_pos = run.escort_pos
	_step(run, int((IslandRun.repair_seconds() - p + 0.1) / DT))
	_check(not run.escort_broken and absf(run.escort_hp - IslandRun.escort_max_hp() * IslandRun.repair_hp()) < 0.5,
		"repaired after %.0f s: back to %.0f HP (%.0f%%)" % [IslandRun.repair_seconds(), run.escort_hp, 100.0 * IslandRun.repair_hp()])
	d = run.escort_dist
	_walk_with(run, 1.0)
	_check(run.escort_dist > d + 1.5, "and it moves again")


func _test_stops() -> void:
	var run := _quiet_run(14)
	_relax(run)
	var s0: float = run.escort_stop_at[0]
	_jump(run, s0 - 1.0)
	var ammo_w: int = -1  # a weapon with finite ammo (the refill), if the loadout has one
	for w in run.weapons.size():
		if run.weapons[w].max_ammo > 0:
			ammo_w = w
	if ammo_w >= 0:
		run.ammo[ammo_w] = 0
	_walk_with(run, 1.0)
	_check(run.at_stop() and absf(run.escort_dist - s0) < 0.001 and run.escort_status == IslandRun.ESC_STOPPED
		and run.director.phase == Director.Phase.PEAK and run.radio.has(&"escort_stop") and absf(run.stop_left - (IslandRun.stop_seconds() - 0.5)) < 0.1,
		"at stop 1 (%.0f m) it halts for %.0f s with a horde spike (%.1f s left)" % [s0, IslandRun.stop_seconds(), run.stop_left])
	_walk_with(run, 5.0)
	_check(absf(run.escort_dist - s0) < 0.001 and run.at_stop(), "it stays put at the stop with the player beside it")
	# The countdown also runs while it is broken down (damage at a stop is
	# the danger; the repair comes after).
	run.escort_hp = 0.5
	var e: int = _enemy_at(run, run.escort_pos + Vector3(0.6, 0, 0))
	var left: float = run.stop_left
	_step(run, int(1.0 / DT))
	_check(run.escort_broken and run.stop_left < left - 0.9, "broken at a stop: the stop's countdown still runs")
	run.horde.remove(e)
	run.player_pos = run.escort_pos
	_step(run, int((IslandRun.repair_seconds() + 0.1) / DT))
	_walk_with(run, run.stop_left + 0.2)
	_check(not run.at_stop() and run.stop_index == 1 and run.stops_done() == 1 and (ammo_w < 0 or run.ammo[ammo_w] > 0),
		"stop 1 done: a third of the ammo back, stop 2 next")
	_walk_with(run, 1.0)
	_check(run.escort_dist > s0 + 1.5 and run.escort_status == IslandRun.ESC_MOVING, "it moves on")
	_jump(run, run.escort_stop_at[1] - 0.5)
	_walk_with(run, 0.5)
	_check(run.at_stop() and run.stop_index == 1, "stop 2 halts it too")
	_walk_with(run, IslandRun.stop_seconds() + 0.2)
	_check(run.stops_done() == 2 and not run.at_stop(), "both stops done")
	var legend: Array = Minimap.legend_entries(run).map(func(e2: Array) -> StringName: return e2[0])
	_check(not legend.has(&"stop") and legend.has(&"cart"), "minimap key: no STOP once both are done")


func _test_extraction() -> void:
	var run := _quiet_run(15)
	_relax(run)
	run.player_pos = run.map.boat
	_step(run, 10)
	_check(run.objective == IslandRun.Objective.GENERATORS, "no extraction at the boat before the delivery")
	for k in run.escort_stop_at.size():
		run.stop_index = k + 1  # stops already held
	_jump(run, run.escort_length - 1.0)
	# Six metres behind it: near enough to move it, not yet at the boat.
	for k in int(1.0 / DT):
		run.player_pos = run.escort_pos - run.escort_dir * 6.0
		_step(run)
	_check(run.escort_delivered and run.escort_status == IslandRun.ESC_DONE and run.objective == IslandRun.Objective.RETURN_TO_BOAT
		and run.radio.has(&"escort_done") and run.escort_progress() == 1.0,
		"delivered at the boat: the extraction opens ('%s')" % run.objective_text())
	_check(run.intel_earned() >= 45, "Intel: 15 per stop and 15 for the delivery (%d)" % run.intel_earned())
	var d: float = run.escort_dist
	run.player_pos = run.escort_pos - run.escort_dir * 6.0
	_step(run, int(1.0 / DT))
	_check(run.escort_dist == d and run.objective == IslandRun.Objective.RETURN_TO_BOAT, "a delivered cart stays where it is")
	run.player_pos = run.extraction_point()
	_step(run)
	_check(run.objective == IslandRun.Objective.WON, "and the extraction wins")
	# A route of length 0 (nothing to pick from): delivered as soon as the
	# player comes near. Never a softlock.
	var tiny := _quiet_run(16)
	tiny.escort_path = PackedVector3Array([tiny.map.boat])
	tiny.escort_cum = PackedFloat32Array([0.0])
	tiny.escort_length = 0.0
	tiny.escort_stop_at.clear()
	tiny._escort_seg = 0
	tiny._place_escort()
	tiny.player_pos = tiny.map.boat
	_step(tiny)
	_check(tiny.escort_delivered and tiny.objective == IslandRun.Objective.RETURN_TO_BOAT, "a route of length 0 is delivered at once")


func _test_death_and_redeploy() -> void:
	var ctx := RunContext.new(8)
	ctx.biome = &"port"
	ctx.mission = &"escort"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	_hold_fire(run)
	_check(run.radio.has(&"land_escort"), "landing radio: land_escort")
	_jump(run, run.escort_stop_at[0] - 0.5)
	_walk_with(run, 1.0)
	run.escort_hp = 20.0
	_check(run.at_stop() and run.escort_dist > 0.0, "half way, at a stop, damaged")
	run.hp = 0.0
	_step(run)
	_check(run.objective == IslandRun.Objective.LOST and run.is_over(), "dying ends the island")
	var again := IslandRun.new(ctx.island_seed(), ctx.biome)
	again.load_context(ctx)
	var fresh: bool = again.escort_dist == 0.0 and again.stop_index == 0 and again.stop_left == 0.0 and not again.escort_broken \
		and again.escort_hp == IslandRun.escort_max_hp() and not again.escort_started and not again.escort_delivered and again.escort_breakdowns == 0
	_check(fresh and again.escort_path == run.escort_path and again.escort_stop_at == run.escort_stop_at,
		"a redeployed island starts fresh, same route and stops")
	again.set_mission(&"activate")
	_check(again.escort_path.is_empty() and again.escort_stop_at.is_empty() and again.escort_dist == 0.0,
		"switching mission clears the escort")


func _test_draw() -> void:
	var weights_ok: bool = true
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		weights_ok = weights_ok and GameData.mission_weight(&"escort", biome) == 1
	_check(weights_ok, "weights: Escort weighs 1 on every biome")
	_check(not GameData.route_missions_after(&"escort").has(&"escort"), "never Escort twice in a row")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var beach: int = 0
	var port: int = 0
	var repeats: int = 0
	var n: int = 4000
	for k in n:
		if GameData.pick_route_mission(rng, &"", &"beach") == &"escort":
			beach += 1
		if GameData.pick_route_mission(rng, &"", &"port") == &"escort":
			port += 1
		if GameData.pick_route_mission(rng, &"escort", &"port") == &"escort":
			repeats += 1
	var want_beach: float = GameData.mission_share(&"escort", &"beach")
	var want_port: float = GameData.mission_share(&"escort", &"port")
	_check(absf(want_port - 1.0 / 12.0) < 0.001 and absf(want_beach - 1.0 / 12.0) < 0.001,
		"shares: %.1f%% everywhere (1 of 12: ten route missions, the home mission weighs 3)" % [100.0 * want_port])
	_check(absf(beach / float(n) - want_beach) < 0.03 and absf(port / float(n) - want_port) < 0.03,
		"draw shares: Beach %.1f%%, Port %.1f%% (expected %.1f%%)" % [100.0 * beach / n, 100.0 * port / n, 100.0 * want_port])
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
	var escorts: int = 0
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
				escorts += 1 if m == &"escort" else 0
	_check(deterministic and repeats_boat == 0 and escorts > 0,
		"boat routes: %d draws, deterministic, %d repeats, Escort on %d" % [draws, repeats_boat, escorts])


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


## Berlenga part 1 (Carreiro do Mosteiro): a survivor waits in the Bairro
## dos Pescadores and walks the climbing path to the Exit, with 2 stops on
## the climb (build.gd preset; markers on the grid path). A bot plays it.
func _test_berlenga() -> void:
	var parts: Array = Expeditions.parts(&"berlenga")
	if parts.is_empty() or parts[0]["mission"] != &"escort":
		print("  (Berlenga part 1 is not an escort: skipped)")
		return
	if not ResourceLoader.exists(PART_1):
		_check(false, "%s exists" % PART_1)
		return
	var t0: int = Time.get_ticks_msec()
	var hm: HandmadeIsland = (load(PART_1) as PackedScene).instantiate()
	root.add_child(hm)
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	hm.free()
	_check(problems.is_empty() and map.escort_survivor and map.escort_route.size() >= 3 and map.escort_stops.size() == 2 and map.exit.x >= 0.0,
		"part 1: no problems, a survivor, %d route points, %d stops, an Exit %s" % [map.escort_route.size(), map.escort_stops.size(), problems])
	_check(_flat_dist(map.escort_route[0], Vector3(1011, 0, 720)) < 12.0,
		"part 1: the survivor waits in the Bairro dos Pescadores (%.0f m from (1011, 720))" % _flat_dist(map.escort_route[0], Vector3(1011, 0, 720)))
	var ctx := RunContext.new(42)
	ctx.threat = 2
	ctx.biome = &"beach"
	ctx.mission = &"escort"
	var t1: int = Time.get_ticks_msec()
	var run := IslandRun.new(ctx.island_seed(), ctx.biome, map)
	run.load_context(ctx)
	var build_ms: int = Time.get_ticks_msec() - t1
	var end: Vector3 = run.escort_path[run.escort_path.size() - 1]
	_check(run.escort_survivor and run.radio.has(&"land_escort_survivor") and _flat_dist(end, map.exit) < 1.5
		and _path_walkable(map, run.escort_path) and run.escort_stop_at.size() == 2,
		"part 1: a walkable route of %.0f m to the Exit (run ready in %d ms, scene and map %d ms)" % [run.escort_length, build_ms, t1 - t0])
	# The stops are on the climb: higher than the lowest point of the route.
	var low: float = INF
	for p in run.escort_path:
		low = minf(low, map.ground_y(p))
	var h0: float = map.ground_y(run.stop_pos(0))
	var h1: float = map.ground_y(run.stop_pos(1))
	var top: float = map.ground_y(end)
	_check(h0 > low + 2.0 and h1 > h0 and top > h1, "part 1: stops on the climbing path (lowest %.1f m, stops %.1f m and %.1f m, Exit %.1f m)" % [low, h0, h1, top])
	_bot(run, "bot on Berlenga part 1 (threat 2)")


## A bot walks to the cart and then along the route just ahead of it,
## repairing it when it breaks, then heads out (invincible: this checks
## completability and the pacing with the horde).
func _test_bot() -> void:
	for s in [404, 505, 606]:
		var ctx := RunContext.new(s)
		ctx.threat = 2
		ctx.mission = &"escort"
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
	var reached_at: float = -1.0
	var stop_at := PackedStringArray()
	var delivered_at: float = -1.0
	var blocked: float = 0.0
	var waiting: float = 0.0
	var was_stop: bool = false
	var ms: int = Time.get_ticks_msec()
	while not run.is_over() and steps < int(900.0 / DT):
		steps += 1
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.hp = 10000.0
		var move := Vector2.ZERO
		var t: float = run.time_alive - run.landed_time
		var escorting: bool = run.objective == IslandRun.Objective.GENERATORS
		if escorting and reached_at < 0.0 and _flat_dist(run.player_pos, run.escort_pos) < IslandRun.escort_radius():
			reached_at = t
		# Near the cart: straight to the point ahead of it (the route is
		# walkable); farther: the grid to the cart (round houses and walls).
		if escorting and _flat_dist(run.player_pos, run.escort_pos) < IslandRun.escort_radius() - 2.0:
			# On the route, BOT_AHEAD metres ahead of the cart (the route is
			# walkable; the bot shoots what comes down the road at it);
			# beside it while it is broken down.
			var to_pt: Vector3 = run.escort_pos if run.escort_broken else IslandMap.point_along(run.escort_path, minf(run.escort_length, run.escort_dist + BOT_AHEAD))
			var to := Vector2(to_pt.x - run.player_pos.x, to_pt.z - run.player_pos.z)
			if to.length() > 0.6:
				move = to.normalized()
		else:
			var g: Vector3 = run.escort_pos if escorting else run.extraction_point()
			g = Vector3(floorf(g.x) + 0.5, 0, floorf(g.z) + 0.5)
			if goal == Vector3.INF or _flat_dist(g, goal) > 6.0:
				goal = g
				nav.compute_now(nav.world_to_cell(goal))
			var stp: Vector2 = nav.direction_at(run.player_pos)
			if stp != Vector2.ZERO:
				var c := Vector2(floori(run.player_pos.x) + stp.x + 0.5, floori(run.player_pos.z) + stp.y + 0.5)
				move = (c - Vector2(run.player_pos.x, run.player_pos.z)).normalized()
			elif _flat_dist(run.player_pos, g) > 0.5:
				move = Vector2(g.x - run.player_pos.x, g.z - run.player_pos.z).normalized()
		var close: PackedInt32Array = run.horde.query_radius(run.player_pos, 20.0)
		var aim := Vector3(move.x, 0, move.y)
		if close.size() > 0:
			aim = run.horde.positions[close[0]] - run.player_pos
		run.step(DT, move, aim, close.size() > 10)
		if run.at_stop() and not was_stop:
			stop_at.append("%.0f s" % t)
		was_stop = run.at_stop()
		if run.escort_status == IslandRun.ESC_BLOCKED:
			blocked += DT
		if run.escort_status == IslandRun.ESC_WAITING and reached_at >= 0.0 and escorting:
			waiting += DT
		if run.escort_delivered and delivered_at < 0.0:
			delivered_at = t
		peak_enemies = maxi(peak_enemies, run.horde.count)
	_check(run.objective == IslandRun.Objective.WON and run.escort_delivered and run.stops_done() == run.escort_stop_at.size(),
		"%s: %s in %.0f s; at the %s at %.0f s, stops at %s, delivered at %.0f s; %.0f s blocked, %.0f s waiting, %d breakdowns; %d kills, up to %d enemies alive, Intel %d (%.1f s of CPU)" % [
		label, run.objective_text(), run.time_alive - run.landed_time, run.escort_noun(), reached_at, ", ".join(stop_at), delivered_at,
		blocked, waiting, run.escort_breakdowns, run.kills, peak_enemies, run.intel_earned(), (Time.get_ticks_msec() - ms) / 1000.0])


## The Island scene with Escort, in each camera mode: the cart, the route
## arrows, the ring and the stop posts are built; first person walks with
## the cart (it moves, the minimap draws the cart, route and stops), third
## person reaches stop 1 (the label counts down), the fixed camera breaks it
## down and repairs it; then the delivery (arrows and ring gone, the boat
## ring shows).
func _test_scene() -> void:
	var profile := MemoryProfile.new()
	var ctx := RunContext.new(5)
	ctx.mission = &"escort"
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
	var model: EscortModel = island.get("_escort")
	var arrows: MultiMesh = island.get("_escort_arrows")
	var posts: Array = island.get("_escort_stop_posts")
	_check(model != null and not model.survivor and model.wheels.size() == 4 and arrows.instance_count >= int(run.escort_length / 3.0) - 1
		and posts.size() == 2, "the scene builds the cart, %d route arrows and 2 stop posts" % arrows.instance_count)
	await physics_frame
	await process_frame
	var hud: Hud = island.get("hud")
	var objective: Label = hud.get("_objective")
	var detail: Label = hud.get("_objective_detail")
	var marker: Label = hud.get("_marker")
	var minimap: Minimap = hud.get("_minimap")
	var label: Label3D = island.get("_escort_label")
	var ring: Node3D = island.get("_escort_ring")
	_check(objective.text == "ESCORT 0% · STOP 1/2" and detail.text.contains("STAY WITHIN") and ring.visible and arrows.visible_instance_count > 0,
		"HUD '%s' / '%s', the ring and the arrows show" % [objective.text, detail.text])
	var modes: Array = [Profile.CameraMode.FIRST_PERSON, Profile.CameraMode.THIRD_PERSON, Profile.CameraMode.FIXED]
	for k in modes.size():
		var mode_name: String = Profile.CAMERA_MODE_NAMES[modes[k]]
		island.call("_set_camera_mode", modes[k], false)
		if k == 1:
			run.escort_dist = run.escort_stop_at[0] - 0.3
			run._place_escort()
		run.player_pos = run.escort_pos - run.escort_dir * 3.0
		island.set("_tp_yaw", atan2(-run.escort_dir.x, -run.escort_dir.z))
		run.facing = run.escort_dir
		if k == 2:
			run.escort_hp = 0.01
			var e: int = run.horde.add(run.escort_pos + Vector3(0.5, 0, 0), GameData.EnemyKind.WALKER, run.rng)
			run.horde.stun[e] = 1000.0
		var d0: float = run.escort_dist
		var visible0: int = arrows.visible_instance_count
		for f in 30:
			await physics_frame
			await process_frame
		if k == 0:
			_check(run.escort_dist > d0 + 0.3 and run.escort_status == IslandRun.ESC_MOVING and marker.text.begins_with("CART ·")
				and detail.text.contains("MOVING") and arrows.visible_instance_count <= visible0,
				"%s: walking with the cart (%.1f m), HUD '%s' / '%s', marker '%s'" % [mode_name, run.escort_dist, objective.text, detail.text, marker.text])
		elif k == 1:
			_check(run.at_stop() and label.visible and label.text.begins_with("STOP ·") and detail.text.contains("STOPPED")
				and objective.text.ends_with("STOP 1/2") and marker.text.contains("STOP"),
				"%s: stop 1, label '%s', HUD '%s' / '%s', marker '%s'" % [mode_name, label.text, objective.text, detail.text, marker.text])
			run.stop_left = 0.05
		else:
			for i in range(run.horde.count - 1, -1, -1):
				run.horde.remove(i)
			run.player_pos = run.escort_pos
			for f in 10:
				await physics_frame
				await process_frame
			_check(run.escort_broken and not model.wheels[0].visible and label.text.begins_with("REPAIR") and marker.text.begins_with("REPAIRING ·")
				and detail.text.contains("BROKEN"), "%s: broken down, a wheel off, label '%s', marker '%s', HUD '%s'" % [mode_name, label.text, marker.text, detail.text])
			run.repair_progress = IslandRun.repair_seconds() - 0.01
			for f in 3:
				await physics_frame
				await process_frame
			_check(not run.escort_broken and model.wheels[0].visible, "%s: repaired, the wheel is back" % mode_name)
		if minimap != null:
			minimap.queue_redraw()
			await process_frame
			_check(minimap.drawn_kinds.has(&"cart") and minimap.drawn_kinds.has(&"route"),
				"%s: the minimap draws the cart and the route (%s)" % [mode_name, minimap.drawn_kinds.keys()])
	# The delivery.
	run.stop_index = run.escort_stop_at.size()
	run.escort_dist = run.escort_length - 0.2
	run._place_escort()
	run.player_pos = run.escort_pos - run.escort_dir * 6.0  # near it, not yet at the boat
	for f in 10:
		await physics_frame
		await process_frame
	_check(run.escort_delivered and run.objective == IslandRun.Objective.RETURN_TO_BOAT and arrows.visible_instance_count == 0
		and not ring.visible and (island.get("_boat_ring") as Node3D).visible and objective.text == "RETURN TO THE BOAT",
		"delivered: arrows and ring gone, the boat ring shows, HUD '%s'" % objective.text)
	island.queue_free()
	await process_frame
	await _test_berlenga_scene()
	_finish()


## Berlenga part 1 in the Island scene: the survivor model walks the route.
func _test_berlenga_scene() -> void:
	var parts: Array = Expeditions.parts(&"berlenga")
	if parts.is_empty() or parts[0]["mission"] != &"escort" or not ResourceLoader.exists(PART_1):
		return
	var t0: int = Time.get_ticks_msec()
	var ctx := RunContext.new(31)
	ctx.start_expedition(&"berlenga")
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	island.set("context", ctx)
	island.set("handmade_scene", load(PART_1))
	root.add_child(island)
	for i in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	var model: EscortModel = island.get("_escort")
	run.player_pos = run.escort_pos
	for f in 20:
		await physics_frame
		await process_frame
	_check(model != null and model.survivor and model.legs.size() == 2 and run.escort_dist > 0.0 and run.has_exit(),
		"Berlenga part 1 in the scene: the survivor walks with you (%.1f m; ready in %d ms)" % [run.escort_dist, Time.get_ticks_msec() - t0])
	island.queue_free()
	await process_frame
