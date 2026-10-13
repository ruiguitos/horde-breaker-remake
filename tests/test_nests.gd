extends SceneTree
## Nests (docs/design/OBJECTIVES_PROPOSAL.md, step 3): destroy the horde
## nests, in any order. Each living nest near the player spawns a small,
## capped brood; destroying one calls a short spike and drops a power-up;
## the extraction opens once every nest is gone. Nests are hit by the
## enemies' own pipeline: auto-fire (fixed camera) and the crosshair (first
## / third person) pick them as targets, pellets stop on them (pierce),
## grenades and the Breaker impact hurt them; enemies keep priority.
## Also: data, Nest_* markers and the fallback spots, HP scaling, death and
## redeploy, the boat draw (Jungle / Volcano preference, no repeat), a bot
## run and the Island scene in the three cameras.
## Run: godot --headless --path . --script res://tests/test_nests.gd

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
			_check(false, "nests tests finished in time")
			_finish())
	_test_data()
	_test_fallback_spots()
	_test_handmade_islands()
	_test_markers()
	_test_hp_scaling()
	_test_fixed_camera_fire()
	_test_crosshair_fire()
	_test_pellets_and_pierce()
	_test_grenade_and_breaker()
	_test_trickle()
	_test_destroy_and_extraction()
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
func _quiet_run(rng_seed: int, biome: StringName = &"jungle") -> IslandRun:
	var run := IslandRun.new(rng_seed, biome)
	run.director.max_alive = 0
	run.set_mission(&"nests")
	return run


func _clear_horde(run: IslandRun) -> void:
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)


## A walkable spot `dist` metres from nest n with a clear line (grid and
## view) to it; Vector3.INF when none of 32 directions fits.
func _stand_near(run: IslandRun, n: int, dist: float) -> Vector3:
	var c: Vector3 = run.nest_pos[n]
	for k in 32:
		var ang: float = k * TAU / 32.0
		var p: Vector3 = c + Vector3(cos(ang), 0, sin(ang)) * dist
		var cell: Vector2i = run.field.world_to_cell(p)
		if p.x < 1 or p.z < 1 or p.x > run.field.width - 1 or p.z > run.field.height - 1:
			continue
		if run.field.is_blocked(cell.x, cell.y) or Horde.overlaps_wall(run.field, p.x, p.z, GameData.PLAYER_RADIUS + 0.1):
			continue
		if run._line_of_sight(p, c) and run._view_clear(p, c) and absf(run.map.ground_y(p) - run.map.ground_y(c)) < 1.0:
			return Vector3(p.x, 0, p.z)
	return Vector3.INF


## Puts the player `dist` m from nest n, facing it (fixed camera).
func _face_nest(run: IslandRun, n: int, dist: float) -> bool:
	var p: Vector3 = _stand_near(run, n, dist)
	if p == Vector3.INF:
		return false
	run.player_pos = p
	var to: Vector3 = run.nest_pos[n] - p
	run.facing = Vector3(to.x, 0, to.z).normalized()
	return true


## A first-person crosshair from the player's eyes at nest n's middle.
func _crosshair_at_nest(run: IslandRun, n: int) -> void:
	var eye: Vector3 = run.player_pos + Vector3(0, run.map.ground_y(run.player_pos) + 1.6, 0)
	var c: Vector3 = run.nest_pos[n]
	var mid := Vector3(c.x, run.map.ground_y(c) + IslandRun.NEST_HEIGHT * 0.5, c.z)
	run.set_crosshair(eye, mid - eye)


func _step(run: IslandRun, n: int = 1, move: Vector2 = Vector2.ZERO) -> void:
	for k in n:
		run.step(DT, move, run.facing, false)


func _test_data() -> void:
	var m: Dictionary = GameData.MISSIONS.get(&"nests", {})
	_check(not m.is_empty() and m["name"] == "Nests" and int(m["points"]) == 3 and float(m["nest_hp"]) > 0.0
		and float(m["radius"]) > 0.0 and float(m["spawn_interval"]) > 0.0 and int(m["spawn_count"]) > 0
		and int(m["brood_cap"]) > 0 and float(m["wake_range"]) > 0.0 and float(m["priority_range"]) > 0.0
		and float(m["spike_seconds"]) > 0.0,
		"nests.tres: %d nests, HP %.0f, radius %.1f m, brood %d every %.0f s (cap %d, wake %.0f m), priority %.0f m, spike %.0f s" % [
		int(m.get("points", 0)), float(m.get("nest_hp", 0)), float(m.get("radius", 0)), int(m.get("spawn_count", 0)),
		float(m.get("spawn_interval", 0)), int(m.get("brood_cap", 0)), float(m.get("wake_range", 0)),
		float(m.get("priority_range", 0)), float(m.get("spike_seconds", 0))])
	_check(GameData.ROUTE_MISSIONS.has(&"nests"), "Nests is offered on archipelago routes")
	_check(IslandRun.nest_count_wanted() == 3 and IslandRun.nest_base_hp() == float(m.get("nest_hp", 0))
		and IslandRun.nest_radius() == float(m.get("radius", 0)) and IslandRun.nest_brood_cap() == int(m.get("brood_cap", 0))
		and IslandRun.nest_priority_range() == float(m.get("priority_range", 0)), "the run reads its numbers from the data")
	_check(Story.RADIO.has(&"land_nests") and Story.RADIO.has(&"nest_destroyed") and Story.RADIO.has(&"nests_done"),
		"radio lines for landing, each nest and the end")
	_check(Briefing.ADVICE.has(&"nests"), "briefing advice for Nests")
	_check(IslandRun.target_nest(IslandRun.nest_target(2)) == 2 and IslandRun.target_nest(5) == -1
		and IslandRun.target_nest(-1) == -1, "nest target ids do not collide with enemies or 'no target'")


## Every nest reachable from the start, off the boat, spread apart.
func _check_spots(map: IslandMap, pts: Array[Vector3], label: String) -> void:
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
	f.max_distance = saved
	_check(pts.size() == 3 and bad == 0 and spacing >= IslandMap.HOLD_MIN_SPACING,
		"%s: 3 nests reachable, >= %d m from the boat, min spacing %.0f m" % [label, int(IslandMap.HOLD_MIN_FROM_BOAT), spacing])


func _test_fallback_spots() -> void:
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		for s in [3, 77]:
			var a := _quiet_run(s, biome)
			var b := _quiet_run(s, biome)
			_check(a.nest_pos == b.nest_pos, "%s seed %d: same seed, same nests" % [biome, s])
			_check_spots(a.map, a.nest_pos, "%s seed %d" % [biome, s])
			var lava: int = 0
			for p in a.nest_pos:
				for k in a.map.lava.size():
					if _flat_dist(p, a.map.lava[k]) < a.map.lava_radius[k] + IslandRun.nest_radius():
						lava += 1
			_check(lava == 0, "%s seed %d: no nest in a lava pool" % [biome, s])
	var x := _quiet_run(3)
	var y := _quiet_run(4)
	_check(x.nest_pos != y.nest_pos, "another seed, other nests")
	var f := IslandRun.new(3, &"jungle")
	f.set_mission(&"fuel_run")
	_check(f.cargo_pos != x.nest_pos, "the nests are not on the Fuel Run spots of the same seed")


## The archipelago's hand-made islands have no Nest markers: the fallback
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
		var pts: Array[Vector3] = map.nest_points if not map.nest_points.is_empty() else IslandMap.pick_nest_points(map, 3, 9)
		_check_spots(map, pts, path.get_file())


func _test_markers() -> void:
	var hm := HandmadeIsland.new()
	hm.size = 120
	var markers := Node3D.new()
	markers.name = "Markers"
	hm.add_child(markers)
	var spots: Dictionary = {"Boat": Vector3(60, 0, 110), "PlayerStart": Vector3(60, 0, 104),
		"Nest_10": Vector3(90, 0, 30), "Nest_2": Vector3(30, 0, 50), "Nest_1": Vector3(60, 0, 70)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.position = spots[n]
		markers.add_child(m)
	root.add_child(hm)
	hm.mission = &"nests"
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	var want: Array[Vector3] = [Vector3(60.5, 0, 70.5), Vector3(30.5, 0, 50.5), Vector3(90.5, 0, 30.5)]
	_check(map.nest_points == want, "Nest_1, _2, _10 in number order (%s)" % [map.nest_points])
	_check(problems.is_empty(), "markers reachable, no problems (%s)" % [problems])
	var run := IslandRun.new(1, &"jungle", map)
	run.set_mission(&"nests")
	_check(run.nest_pos == want and run.nest_hp.size() == 3, "the run uses the markers, not picked spots")
	hm.play_area = PackedVector2Array([Vector2(10, 40), Vector2(110, 40), Vector2(110, 118), Vector2(10, 118)])
	problems.clear()
	hm.build_map(problems)
	var reported: bool = false
	for p in problems:
		if p.begins_with("Nest at (90, 30)"):
			reported = true
	_check(reported, "an unreachable Nest marker is reported (%s)" % [problems])
	_check(HandmadeIsland.marker_number("Nest_3", "Nest") == 3, "Nest marker suffix number")
	hm.free()


func _test_hp_scaling() -> void:
	var ctx := RunContext.new(5)
	ctx.mission = &"nests"
	var run := IslandRun.new(5, &"jungle")
	run.load_context(ctx)
	_check(is_equal_approx(run.nest_max_hp, IslandRun.nest_base_hp() * run.horde.hp_scale) and run.nest_hp[0] == run.nest_max_hp,
		"island 1, threat 1: nest HP %.0f (base x enemy HP scale %.2f)" % [run.nest_max_hp, run.horde.hp_scale])
	var hard := RunContext.new(5)
	hard.mission = &"nests"
	hard.threat = 3
	hard.island_index = 2
	var run2 := IslandRun.new(5, &"jungle")
	run2.load_context(hard)
	var want: float = IslandRun.nest_base_hp() * (1.0 + 0.3 * 2) * GameData.threat_hp(3)
	_check(is_equal_approx(run2.nest_max_hp, want) and is_equal_approx(run2.nest_hp[2], run2.nest_max_hp),
		"island 3, threat 3: nest HP %.0f (scales like enemy HP)" % run2.nest_max_hp)


func _test_fixed_camera_fire() -> void:
	var run := _quiet_run(21)
	_check(_face_nest(run, 0, 9.0), "a spot 9 m from nest 1 with a clear line")
	_check(run._pick_target(30.0) == IslandRun.nest_target(0), "fixed camera: facing a nest makes it the target")
	var shots: int = run._shots
	_step(run, 120)
	_check(run._shots > shots and run.nest_hp[0] < run.nest_max_hp,
		"auto-fire hurts the nest (%d shots, HP %.0f / %.0f)" % [run._shots - shots, run.nest_hp[0], run.nest_max_hp])
	# Enemy priority: an enemy within priority range wins even off to the side.
	var to: Vector3 = (run.nest_pos[0] - run.player_pos).normalized()
	var side: Vector3 = to.rotated(Vector3.UP, deg_to_rad(30.0))
	var e: int = run.horde.add(run.player_pos + side * 5.0, GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[e] = 100.0
	_check(run._pick_target(30.0) == e, "an enemy within %.0f m wins over the nest" % IslandRun.nest_priority_range())
	run.horde.positions[e] = run.player_pos + to.rotated(Vector3.UP, deg_to_rad(40.0)) * 20.0
	run.horde.rebuild_hash()
	var t: int = run._pick_target(30.0)
	_check(t == IslandRun.nest_target(0), "a far enemy off to the side does not steal the faced nest (target %d)" % t)
	_clear_horde(run)
	# Turned away: no target, no damage.
	run.facing = -to
	var hp: float = run.nest_hp[0]
	shots = run._shots
	_step(run, 60)
	_check(run._shots == shots and run.nest_hp[0] == hp, "facing away from the nest: no shots at it")


func _test_crosshair_fire() -> void:
	var run := _quiet_run(22)
	_check(_face_nest(run, 1, 10.0), "a spot 10 m from nest 2")
	_crosshair_at_nest(run, 1)
	_check(run._pick_target(30.0) == IslandRun.nest_target(1), "crosshair on the nest: it is the target")
	_step(run, 120)
	_check(run.nest_hp[1] < run.nest_max_hp, "crosshair auto-fire hurts the nest (HP %.0f / %.0f)" % [run.nest_hp[1], run.nest_max_hp])
	# Crosshair at the sky: nothing.
	run.set_crosshair(run.crosshair_origin, Vector3(0, 1, 0))
	_check(run._pick_target(30.0) == -1, "crosshair at the sky: no target")
	# An enemy near the player under the crosshair (in front of the nest) wins.
	_crosshair_at_nest(run, 1)
	var to: Vector3 = run.nest_pos[1] - run.player_pos
	to.y = 0.0
	var e: int = run.horde.add(run.player_pos + to.normalized() * 4.0, GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[e] = 100.0
	_check(run._pick_target(30.0) == e, "an enemy under the crosshair in front of the nest is shot first")
	_clear_horde(run)


func _test_pellets_and_pierce() -> void:
	var run := _quiet_run(23)
	_face_nest(run, 0, 9.0)
	var rifle: GameData.Weapon = GameData.weapon(&"rifle")
	var marksman: GameData.Weapon = GameData.weapon(&"marksman")
	var shotgun: GameData.Weapon = GameData.weapon(&"shotgun")
	var to: Vector3 = (run.nest_pos[0] - run.player_pos)
	to.y = 0.0
	to = to.normalized()
	# A walker on the line, 4 m ahead: the rifle (pierce 1) hits it, not the nest.
	var e: int = run.horde.add(run.player_pos + to * 4.0, GameData.EnemyKind.BRUTE, run.rng)
	run.horde.stun[e] = 100.0
	var hp0: float = run.nest_hp[0]
	var ehp: float = run.horde.hp[e]
	run._fire(rifle, IslandRun.nest_target(0))
	_check(run.horde.hp[e] < ehp and run.nest_hp[0] == hp0, "rifle (pierce 1): the enemy in front takes the bullet, the nest does not")
	run._fire(marksman, IslandRun.nest_target(0))
	_check(run.nest_hp[0] < hp0, "marksman (pierce %d): through the enemy into the nest (-%.0f HP)" % [marksman.pierce, hp0 - run.nest_hp[0]])
	_clear_horde(run)
	# Shotgun pellets at close range (8 m is within its 12 m range).
	_face_nest(run, 0, 6.0)
	var hp1: float = run.nest_hp[0]
	run._fire(shotgun, IslandRun.nest_target(0))
	_check(run.nest_hp[0] < hp1 - shotgun.damage * 2.0, "shotgun: several pellets hit the nest (-%.0f HP)" % (hp1 - run.nest_hp[0]))
	# Crosshair: the same with the 3D ray.
	_crosshair_at_nest(run, 0)
	var hp2: float = run.nest_hp[0]
	run._fire(rifle, IslandRun.nest_target(0))
	_check(run.nest_hp[0] < hp2, "crosshair rifle shot hits the nest (-%.0f HP)" % (hp2 - run.nest_hp[0]))
	run.clear_crosshair()
	# A stray pellet aimed at an enemy beside a nest's line is not a nest hit
	# when the nest is not on its line (aimed the other way).
	var hp3: float = run.nest_hp[0]
	var back: int = run.horde.add(run.player_pos - to * 5.0, GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[back] = 100.0
	run.facing = -to
	run._fire(rifle, back)
	_check(run.nest_hp[0] == hp3, "a shot the other way does not touch the nest")
	_clear_horde(run)


func _test_grenade_and_breaker() -> void:
	var run := _quiet_run(24)
	_face_nest(run, 2, 7.0)
	run.reload_times[run.weapon_index] = 1000.0  # the gun stays quiet: only the blast counts
	var hp0: float = run.nest_hp[2]
	run.grenade_cd = 0.0
	_check(run.throw_grenade(run.nest_pos[2] - run.player_pos), "grenade thrown at the nest")
	_step(run, int((GameData.GRENADE_FUSE + 0.2) / DT))
	_check(is_equal_approx(hp0 - run.nest_hp[2], run.grenade_damage()), "the grenade blast hurts the nest (-%.0f HP, grenade %.0f)" % [hp0 - run.nest_hp[2], run.grenade_damage()])
	# Breaker: charge into the nest; the impact damages it, the mound stops the player.
	_face_nest(run, 2, 4.0)
	var hp1: float = run.nest_hp[2]
	var to: Vector3 = (run.nest_pos[2] - run.player_pos)
	run.breaker_cd = 0.0
	run.facing = Vector3(to.x, 0, to.z).normalized()
	run.step(DT, Vector2(to.x, to.z).normalized(), run.facing, true)
	_step(run, int((GameData.BREAKER_DURATION + 0.1) / DT))
	_check(is_equal_approx(hp1 - run.nest_hp[2], GameData.BREAKER_DAMAGE), "the Breaker impact hurts the nest (-%.0f HP, Breaker %.0f)" % [hp1 - run.nest_hp[2], GameData.BREAKER_DAMAGE])
	_check(_flat_dist(run.player_pos, run.nest_pos[2]) >= IslandRun.nest_radius() + GameData.PLAYER_RADIUS - 0.05,
		"the mound is solid: the player ends outside it (%.2f m from the centre)" % _flat_dist(run.player_pos, run.nest_pos[2]))


## Keeps the director quiet (relaxed) and every enemy stunned in place, so
## only nest broods add enemies and they stay where they appear.
func _hold_still(run: IslandRun, seconds: float) -> void:
	for k in int(seconds / DT):
		run.director.phase = Director.Phase.RELAX
		run.director.phase_time = 1000.0
		for i in run.horde.count:
			run.horde.stun[i] = 100.0
		_step(run)


func _test_trickle() -> void:
	var run := IslandRun.new(25, &"jungle")
	run.set_mission(&"nests")
	_clear_horde(run)
	_check(_face_nest(run, 0, 15.0), "a spot 15 m from nest 1")
	var awake: int = 0
	for n in run.nest_pos.size():
		if _flat_dist(run.nest_pos[n], run.player_pos) <= IslandRun.nest_wake_range():
			awake += 1
	run.facing = -run.facing  # look away: no shooting at the brood or the nest
	_hold_still(run, 60.0)
	var cap: int = IslandRun.nest_brood_cap()
	var per_nest_ok: bool = true
	for n in run.nest_pos.size():
		if run.horde.query_radius(run.nest_pos[n], IslandRun.NEST_BROOD_RADIUS).size() > cap:
			per_nest_ok = false
	var near_mound: bool = true
	for i in run.horde.count:
		var best: float = INF
		for n in run.nest_pos.size():
			best = minf(best, _flat_dist(run.horde.positions[i], run.nest_pos[n]))
		if best > IslandRun.nest_radius() + 3.05:
			near_mound = false
	_check(run.nest_spawns > 0 and run.nest_spawns <= awake * cap and per_nest_ok,
		"a living nest spawns a capped brood: %d enemies from %d awake nests in 60 s (cap %d each)" % [run.nest_spawns, awake, cap])
	_check(near_mound and run.horde.count == run.nest_spawns, "the brood appears right beside the mounds")
	_check(run.spawn_requests == 0, "broods do not go through the director's ring spawns (sector rule untouched)")
	# The global cap holds.
	var capped := IslandRun.new(25, &"jungle")
	capped.set_mission(&"nests")
	_clear_horde(capped)
	_face_nest(capped, 0, 15.0)
	capped.facing = -capped.facing
	capped.director.max_alive = 3
	_hold_still(capped, 40.0)
	_check(capped.horde.count <= 3 and capped.nest_spawns <= 3, "the director's max_alive caps the broods too (%d alive)" % capped.horde.count)
	# A far nest sleeps.
	var far := IslandRun.new(25, &"jungle")
	far.set_mission(&"nests")
	_clear_horde(far)
	far.player_pos = far.map.player_start
	var all_far: bool = true
	for n in far.nest_pos.size():
		all_far = all_far and _flat_dist(far.nest_pos[n], far.player_pos) > IslandRun.nest_wake_range()
	if all_far:
		_hold_still(far, 30.0)
		_check(far.nest_spawns == 0, "nests farther than %.0f m do not spawn" % IslandRun.nest_wake_range())
	else:
		print("TEST: (wake range check skipped: a nest is near the start on this seed)")
	# A destroyed nest stops spawning; a Nuke's spawn delay pauses broods.
	var quiet := IslandRun.new(25, &"jungle")
	quiet.set_mission(&"nests")
	_clear_horde(quiet)
	_face_nest(quiet, 0, 15.0)
	quiet.facing = -quiet.facing
	for n in quiet.nest_pos.size():
		quiet._damage_nest(n, 1.0e9)
	_clear_horde(quiet)
	var before: int = quiet.nest_spawns
	quiet.objective = IslandRun.Objective.GENERATORS
	_hold_still(quiet, 20.0)
	_check(quiet.nest_spawns == before, "destroyed nests spawn nothing")
	var nuked := IslandRun.new(25, &"jungle")
	nuked.set_mission(&"nests")
	_clear_horde(nuked)
	_face_nest(nuked, 0, 15.0)
	nuked.facing = -nuked.facing
	nuked.power_ups.spawn_delay = 30.0
	_hold_still(nuked, 15.0)
	_check(nuked.nest_spawns == 0, "no broods during a Nuke's spawn delay")


func _test_destroy_and_extraction() -> void:
	var ctx := RunContext.new(7)
	ctx.mission = &"nests"
	ctx.biome = &"jungle"
	var run := IslandRun.new(61, &"jungle")
	run.load_context(ctx)
	run.director.max_alive = 0
	_check(run.radio.has(&"land_nests") and run.nest_pos.size() == 3 and run.nests_destroyed() == 0,
		"landing: radio line, 3 nests standing")
	_check(run.site == run.nest_pos[run.nearest_nest()], "the goal is the nearest nest")
	run.radio.clear()
	var boat: Vector3 = run.map.boat
	run.player_pos = boat
	_step(run, 10)
	_check(run.objective == IslandRun.Objective.GENERATORS, "nests standing: no extraction at the boat")
	run.player_pos = _stand_near(run, 0, 12.0)  # away from the boat while the nests fall
	var spikes: int = 0
	var drops: int = 0
	for n in run.nest_pos.size():
		run.director.phase = Director.Phase.RELAX
		run.power_ups.ground_kind = &""
		run._damage_nest(n, run.nest_max_hp * 0.5)
		_check(run.nest_alive(n), "nest %d at half HP still stands" % (n + 1))
		run._damage_nest(n, run.nest_max_hp)
		if run.director.phase == Director.Phase.PEAK:
			spikes += 1
		if run.power_ups.ground_kind != &"":
			drops += 1
		_step(run, 2)
		if n < run.nest_pos.size() - 1:
			_check(run.objective == IslandRun.Objective.GENERATORS and run.nests_destroyed() == n + 1
				and run.objective_text() == "Destroy the nests (%d / 3)" % (n + 1),
				"nest %d destroyed, extraction still locked ('%s')" % [n + 1, run.objective_text()])
	_check(spikes == 3 and drops == 3, "each destroyed nest calls a spike (%d) and drops a power-up (%d)" % [spikes, drops])
	_check(run.radio.count(&"nest_destroyed") == 2 and run.radio.has(&"nests_done"), "radio after each nest and at the end")
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "all nests gone: extraction opens")
	run.player_pos = boat
	_step(run, 2)
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() >= 45,
		"at the boat the run is won (Intel %d)" % run.intel_earned())
	# The drop does not replace a power-up already on the ground.
	var r2 := _quiet_run(62)
	r2.power_ups.ground_kind = &"nuke"
	r2._damage_nest(0, 1.0e9)
	_check(r2.power_ups.ground_kind == &"nuke", "a nest's drop never replaces one on the ground")


func _test_death_and_redeploy() -> void:
	var ctx := RunContext.new(9)
	ctx.mission = &"nests"
	ctx.biome = &"jungle"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	run._damage_nest(0, 1.0e9)
	run._damage_nest(1, run.nest_max_hp * 0.5)
	run.hp = 0.0
	_step(run)
	_check(run.objective == IslandRun.Objective.LOST and run.is_over(), "dying with nests standing ends the island")
	var again := IslandRun.new(ctx.island_seed(), ctx.biome)
	again.load_context(ctx)
	var full: bool = true
	for n in again.nest_pos.size():
		full = full and is_equal_approx(again.nest_hp[n], again.nest_max_hp)
	_check(full and again.nests_destroyed() == 0 and again.nest_pos == run.nest_pos and again.nest_spawns == 0,
		"a redeployed island starts with every nest back at full HP")
	again.set_mission(&"activate")
	_check(again.nest_pos.is_empty() and again.nest_hp.is_empty(), "switching mission clears the nests")


func _test_draw() -> void:
	_check(GameData.mission_weight(&"nests", &"jungle") == 3 and GameData.mission_weight(&"nests", &"volcano") == 3
		and GameData.mission_weight(&"nests", &"beach") == 1, "weights: Nests x3 on Jungle and Volcano, 1 elsewhere")
	_check(not GameData.route_missions_after(&"nests").has(&"nests"), "never Nests twice in a row")
	var routes: int = GameData.ROUTE_MISSIONS.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	var jungle: int = 0
	var town: int = 0
	var repeats: int = 0
	var n: int = 4000
	for k in n:
		if GameData.pick_route_mission(rng, &"", &"jungle") == &"nests":
			jungle += 1
		if GameData.pick_route_mission(rng, &"", &"town") == &"nests":
			town += 1
		if GameData.pick_route_mission(rng, &"nests", &"volcano") == &"nests":
			repeats += 1
	var want_jungle: float = 3.0 / (routes + 2)
	var want_town: float = 1.0 / routes
	_check(absf(jungle / float(n) - want_jungle) < 0.03 and absf(town / float(n) - want_town) < 0.03,
		"draw shares: Jungle %.0f%% (expected %.0f%%), Town %.0f%% (expected %.0f%%)" % [100.0 * jungle / n, 100.0 * want_jungle, 100.0 * town / n, 100.0 * want_town])
	_check(repeats == 0, "no repeat even on the Volcano")
	var boat_script: Script = load("res://game/states/boat.gd")
	var deterministic: bool = true
	var draws: int = 0
	var repeats_boat: int = 0
	var preferred: Array[int] = [0, 0]  # [nests, routes] on Jungle / Volcano
	var elsewhere: Array[int] = [0, 0]
	for s in range(1, 61):
		for prev: StringName in GameData.ROUTE_MISSIONS:
			for last in [false, true]:
				var first: Array = _boat_routes(boat_script, s, prev, last)
				if first != _boat_routes(boat_script, s, prev, last):
					deterministic = false
				for i in 2:
					var m: StringName = first[0][i]
					var b: StringName = first[1][i]
					draws += 1
					if GameData.mission_family(m) == GameData.mission_family(prev):
						repeats_boat += 1
					if prev == &"nests":
						continue
					var bucket: Array[int] = preferred if b in [&"jungle", &"volcano"] else elsewhere
					bucket[1] += 1
					if m == &"nests":
						bucket[0] += 1
	_check(deterministic and repeats_boat == 0 and draws > 0, "boat routes: %d draws, deterministic, %d repeats" % [draws, repeats_boat])
	var share_pref: float = preferred[0] / maxf(1.0, preferred[1])
	var share_other: float = elsewhere[0] / maxf(1.0, elsewhere[1])
	_check(share_pref > share_other * 1.5 and elsewhere[0] > 0,
		"boat routes: Nests on %.0f%% of Jungle/Volcano routes, %.0f%% elsewhere (still possible)" % [100.0 * share_pref, 100.0 * share_other])


## [missions, biomes] of the two routes the boat draws for seed `s` after
## `prev` (`last`: the routes to the last island, the Volcano).
func _boat_routes(boat_script: Script, s: int, prev: StringName, last: bool) -> Array:
	var ctx := RunContext.new(s)
	ctx.island_index = RunContext.ISLAND_COUNT - 1 if last else 1
	ctx.mission = prev
	var boat := Control.new()
	boat.set_script(boat_script)
	boat.set("context", ctx)
	(boat.get("_rng") as RandomNumberGenerator).seed = ctx.island_seed() + 1
	boat.call("_make_routes")
	var out: Array = [(boat.get("_route_missions") as Array).duplicate(), (boat.get("_route_biomes") as Array).duplicate()]
	boat.free()
	return out


## A bot walks to the nearest nest and shoots it down with auto-fire
## (fixed camera), one nest after the other, then extracts. Invincible:
## this checks the mission can be completed with the real horde and broods.
func _test_bot() -> void:
	for s in [404, 505]:
		var ctx := RunContext.new(s)
		ctx.threat = 2
		ctx.mission = &"nests"
		ctx.biome = &"jungle" if s == 404 else &"volcano"
		var run := IslandRun.new(ctx.island_seed(), ctx.biome)
		run.load_context(ctx)
		run.has_boss = false  # the Volcano's boss is another test's business
		_bot(run, "bot seed %d (%s)" % [s, ctx.biome])


func _bot(run: IslandRun, label: String) -> void:
	var nav := FlowField.new(run.field.width, run.field.height)
	nav.blocked = run.field.blocked
	var goal := Vector3.INF
	var steps: int = 0
	var peak_enemies: int = 0
	var nest_shots: int = 0
	while not run.is_over() and steps < int(900.0 / DT):
		steps += 1
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.hp = 10000.0
		var g: Vector3 = run.site if run.objective == IslandRun.Objective.GENERATORS else run.extraction_point()
		var target_nest: int = run.nearest_nest() if run.objective == IslandRun.Objective.GENERATORS else -1
		var move := Vector2.ZERO
		var close_to_nest: bool = target_nest >= 0 and _flat_dist(run.player_pos, run.nest_pos[target_nest]) < 7.0 \
			and run._line_of_sight(run.player_pos, run.nest_pos[target_nest])
		if not close_to_nest:
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
		var aim := Vector3(move.x, 0, move.y)
		var close: PackedInt32Array = run.horde.query_radius(run.player_pos, 6.0)
		if close.size() > 0:
			aim = run.horde.positions[close[0]] - run.player_pos
		elif target_nest >= 0 and _flat_dist(run.player_pos, run.nest_pos[target_nest]) < 25.0:
			aim = run.nest_pos[target_nest] - run.player_pos
		var hp_before: float = run.nest_hp[target_nest] if target_nest >= 0 else 0.0
		run.step(DT, move, aim, close.size() > 10)
		if target_nest >= 0 and target_nest < run.nest_hp.size() and run.nest_hp[target_nest] < hp_before:
			nest_shots += 1
		peak_enemies = maxi(peak_enemies, run.horde.count)
	_check(run.objective == IslandRun.Objective.WON and run.nests_destroyed() == run.nest_pos.size(),
		"%s: %s in %.0f s, %d nests, %d frames of nest damage, %d brood, %d kills, up to %d enemies alive" % [label,
		run.objective_text(), run.time_alive - run.landed_time, run.nests_destroyed(), nest_shots, run.nest_spawns,
		run.kills, peak_enemies])


## The Island scene with Nests, in each camera mode: nests are built and
## drawn, the HUD and the minimap key show them, and auto-fire through the
## scene's own aim (crosshair or facing) hurts the nest.
func _test_scene() -> void:
	var profile := MemoryProfile.new()
	var ctx := RunContext.new(5)
	ctx.mission = &"nests"
	ctx.biome = &"jungle"
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	island.set("context", ctx)
	root.add_child(island)
	for i in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	_clear_horde(run)
	var nests: Array = island.get("_nests")
	_check(nests.size() == run.nest_pos.size() and nests.size() == 3, "the scene builds %d nests" % nests.size())
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"nest"), "the minimap key shows NEST")
	var hud: Hud = island.get("hud")
	var objective: Label = hud.get("_objective")
	_check(objective.text == "NESTS 0 / 3", "HUD objective '%s'" % objective.text)
	var minimap: Minimap = hud.get("_minimap")
	if minimap != null:
		minimap.queue_redraw()
		await process_frame
		_check(minimap.drawn_kinds.has(&"nest"), "the minimap draws the nests")
	var marker: Label = hud.get("_marker")
	var n: int = 0
	for mode in [Profile.CameraMode.FIRST_PERSON, Profile.CameraMode.THIRD_PERSON, Profile.CameraMode.FIXED]:
		var mode_name: String = Profile.CAMERA_MODE_NAMES[mode]
		island.call("_set_camera_mode", mode, false)
		if not _face_nest(run, n, 9.0):
			_check(false, "%s: a spot near nest %d" % [mode_name, n + 1])
			continue
		var to: Vector3 = run.nest_pos[n] - run.player_pos
		island.set("_tp_yaw", atan2(-to.x, -to.z))
		# Pitch the crosshair at the nest's middle (twice: the shoulder
		# camera's origin depends on the yaw and pitch).
		for k in 2:
			var ray: Array[Vector3] = island.call("crosshair_ray")
			var c: Vector3 = run.nest_pos[n]
			var mid := Vector3(c.x, run.map.ground_y(c) + IslandRun.NEST_HEIGHT * 0.5, c.z)
			var d: Vector3 = (mid - ray[0]).normalized()
			island.set("_tp_pitch", -asin(d.y))
		var hp0: float = run.nest_hp[n]
		for i in 90:
			run.player_pos = run.player_pos  # stays put: no input in headless
			await physics_frame
			await process_frame
		var bar: Node3D = (island.get("_nest_bars") as Array)[n]
		_check(run.nest_hp[n] < hp0 and (nests[n] as Node3D).visible,
			"%s: auto-fire hurts the nest (HP %.0f -> %.0f), mound visible" % [mode_name, hp0, run.nest_hp[n]])
		_check(bar.visible and marker.text.begins_with("NEST "), "%s: HP bar over the damaged nest, marker '%s'" % [mode_name, marker.text])
		n += 1
	# Destroy one: it bursts, its scorch shows, the HUD counts it.
	run._damage_nest(0, 1.0e9)
	for i in 3:
		await process_frame
	var scorch: MeshInstance3D = (island.get("_nest_scorches") as Array)[0]
	_check(not (nests[0] as Node3D).visible and scorch.visible and objective.text == "NESTS 1 / 3",
		"a destroyed nest is replaced by its scorch; HUD '%s'" % objective.text)
	island.queue_free()
	await process_frame
	_finish()
