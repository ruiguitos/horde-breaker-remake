extends SceneTree
## Headless tests for the expedition missions (docs/design/BERLENGA_EXPEDITION.md):
## extraction on foot at the Exit, rescue / defend at their markers, the
## final holdout (hold the zone, the boat comes, board it) and spawns that
## stay inside a part's play area.
## Run: godot --headless --path . --script res://tests/test_expedition_missions.gd

const DT: float = 1.0 / 60.0
## Part 4 of the Berlenga (the fort), island metres (BERLENGA_EXPEDITION.md).
const FORT: Array = [[523, 800], [880, 800], [880, 1466], [500, 1466], [500, 880], [523, 850]]

var _failures: int = 0


func _initialize() -> void:
	_test_exit_extraction()
	_test_rescue_escort_to_exit()
	_test_markers()
	_test_holdout()
	_test_boat_scenery()
	_test_spawns_in_play_area()
	_test_berlenga_fort()
	_scene = _part_scene(&"activate")  # the real Island scene, next in _process


func _finish() -> void:
	if _failures > 0:
		print("TEST FAIL: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


var _scene: Node
var _frames: int = 0
var _phase: int = 0


## beach_01 turned into an expedition part: the land west of x = 50 is
## outside the play area, Exit and DefendZone markers on two generators.
func _part_scene(mission: StringName) -> Node:
	var island: HandmadeIsland = (load(HandmadeIsland.ISLANDS_DIR + "beach_01.tscn") as PackedScene).instantiate()
	island.play_area = PackedVector2Array([Vector2(50, 0), Vector2(256, 0), Vector2(256, 256), Vector2(50, 256)])
	island.mission = mission
	var markers: Node = island.get_node("Markers")
	for spot: Array in [["Exit", "Generator2"], ["DefendZone", "Generator3"]]:
		var m := Marker3D.new()
		m.name = spot[0]
		m.transform = (markers.get_node(spot[1]) as Node3D).transform
		markers.add_child(m)
		m.owner = island
	var packed := PackedScene.new()
	packed.pack(island)
	island.free()
	var ctx := RunContext.new(21)
	ctx.mission = mission
	var scene: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	scene.set("handmade_scene", packed)
	scene.set("context", ctx)
	root.add_child(scene)
	return scene


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames > 900:
		_check(false, "the Island scene checks finished in time (phase %d)" % _phase)
		_finish()
		return false
	var run: IslandRun = _scene.get("run")
	var hud: Hud = _scene.get("hud")
	match _phase:
		0:
			if _frames < 3:
				return false
			run.director.max_alive = 0
			_check(run.has_exit() and run.play_area.size() == 4, "Island scene: the part's Exit and play area reach the run")
			var mm: Minimap = hud.get("_minimap")
			var img: Image = (mm.get("_texture") as ImageTexture).get_image()
			var step: int = mm.get("_step")
			var dark: int = 0
			var dark_inside: int = 0
			for pz in img.get_height():
				for px in img.get_width():
					if img.get_pixel(px, pz).is_equal_approx(Color("232b24")):
						dark += 1
						if px * step >= 50:
							dark_inside += 1
			_check(dark > 0 and dark_inside == 0, "minimap: land outside the play area is darkened (%d px), none inside" % dark)
			for g in GameData.GENERATOR_COUNT:
				run.generator_progress[g] = GameData.GENERATOR_HOLD_SECONDS
			_phase = 1
			_frames = 0
		1:
			if _frames < 5:
				return false
			var title: String = (hud.get("_objective") as Label).text
			var marker: String = (hud.get("_marker") as Label).text
			_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and title == "LEAVE ALONG THE PATH" and marker.to_upper().contains("EXIT"),
				"HUD: '%s', marker '%s'" % [title, marker])
			var ring: Node3D = _scene.get("_boat_ring")
			_check(ring.visible and Vector2(ring.position.x, ring.position.z).distance_to(Vector2(run.map.exit.x, run.map.exit.z)) < 0.5,
				"the green extraction ring stands at the Exit")
			_scene.queue_free()
			_scene = _part_scene(&"holdout")
			_phase = 2
			_frames = 0
		2:
			if _frames < 3:
				return false
			run.director.max_alive = 0
			var boat: Node3D = _scene.get("_boat")
			_check(not boat.visible and run.site == run.map.defend_zone, "holdout scene: no boat yet, zone at the DefendZone")
			run.defend_time = run.hold_time()
			_phase = 3
			_frames = 0
		3:
			var boat: Node3D = _scene.get("_boat")
			# The hold ends on the next simulation step, which may take a few
			# frames to come: wait for it (up to 60 frames) instead of a fixed frame.
			var heading: String = (hud.get("_objective") as Label).text
			if not has_meta(&"called_at") and ((boat.visible and heading == "BOAT INBOUND") or _frames >= 60):
				set_meta(&"called_at", _frames)
				set_meta(&"far", Vector2(boat.position.x, boat.position.z).distance_to(Vector2(run.map.boat.x, run.map.boat.z)))
				_check(boat.visible and heading == "BOAT INBOUND", "holdout scene: the boat is called and shows (visible %s, '%s', frame %d)" % [boat.visible, heading, _frames])
			if has_meta(&"called_at") and _frames == int(get_meta(&"called_at")) + 117:
				var near: float = Vector2(boat.position.x, boat.position.z).distance_to(Vector2(run.map.boat.x, run.map.boat.z))
				_check(near < float(get_meta(&"far")), "the boat sails in towards the pier (%.0f m -> %.0f m)" % [float(get_meta(&"far")), near])
				_scene.queue_free()
				_finish()
	return false


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
func _quiet_run(rng_seed: int, mission: StringName) -> IslandRun:
	var run := IslandRun.new(rng_seed)
	run.director.max_alive = 0
	run.set_mission(mission)
	return run


func _test_exit_extraction() -> void:
	var run := IslandRun.new(5)
	run.director.max_alive = 0
	run.map.exit = run.map.generators[1]  # any reachable spot away from the boat
	run.set_mission(&"activate")
	_check(run.has_exit() and run.extraction_point() == run.map.exit and run.extraction_name() == "Exit",
		"an Exit marker moves the extraction there")
	for g in GameData.GENERATOR_COUNT:
		run.generator_progress[g] = GameData.GENERATOR_HOLD_SECONDS
	_step(run)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.objective_text() == "Leave along the path!",
		"objective done: '%s'" % run.objective_text())
	run.exit_label = "Lighthouse Plateau"
	_check(run.objective_text() == "Head to Lighthouse Plateau!" and run.extraction_name() == "Lighthouse Plateau",
		"with the next part's name: '%s'" % run.objective_text())
	run.player_pos = run.map.boat
	_step(run)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "the boat does not end a part with an Exit")
	run.player_pos = run.map.exit
	_step(run)
	_check(run.objective == IslandRun.Objective.WON, "walking out at the Exit wins the part")
	var plain := _quiet_run(5, &"activate")
	_check(not plain.has_exit() and plain.extraction_point() == plain.map.boat, "without an Exit the boat is the extraction, as before")


func _test_rescue_escort_to_exit() -> void:
	var run := IslandRun.new(9)
	run.director.max_alive = 0
	run.map.exit = run.map.generators[0]
	run.map.rescue_target = run.map.generators[2]
	run.set_mission(&"rescue")
	run.player_pos = run.site
	_step(run)
	_check(run.survivor_found and run.objective == IslandRun.Objective.RETURN_TO_BOAT, "rescue at the marker starts the escort")
	run.player_pos = run.map.exit
	_step(run)
	_check(run.objective != IslandRun.Objective.WON, "the part needs the survivor at the Exit too")
	run.survivor_pos = run.map.exit
	_step(run)
	_check(run.objective == IslandRun.Objective.WON, "survivor and player at the Exit win the part")


func _test_markers() -> void:
	var r := IslandRun.new(9)
	var far: Vector3 = Vector3.ZERO
	var best: float = -1.0
	for g in r.map.generators:
		if g.distance_to(r.map.boat) > best:
			best = g.distance_to(r.map.boat)
			far = g
	r.set_mission(&"rescue")
	_check(r.site == far and r.survivor_pos == far, "no marker: rescue at the generator farthest from the boat")
	var spot: Vector3 = r.map.player_start + Vector3(2, 0, 0)
	r.map.rescue_target = spot
	r.set_mission(&"rescue")
	_check(r.site == spot and r.survivor_pos == spot, "rescue uses the RescueTarget marker")
	r.set_mission(&"defend")
	_check(r.site == far, "defend ignores the RescueTarget")
	r.map.defend_zone = spot + Vector3(0, 0, 3)
	r.set_mission(&"defend")
	_check(r.site == spot + Vector3(0, 0, 3), "defend uses the DefendZone marker")
	r.set_mission(&"holdout")
	_check(r.site == r.map.defend_zone, "holdout uses the DefendZone marker")
	r.map.generators.clear()
	r.map.defend_zone = Vector3(-1, 0, -1)
	r.set_mission(&"defend")
	_check(r.site == r.map.boat, "no marker and no generators: the site falls back to a known spot")


func _test_holdout() -> void:
	_check(GameData.MISSIONS.has(&"holdout") and GameData.MISSIONS[&"holdout"]["name"] == "Holdout"
		and not GameData.ROUTE_MISSIONS.has(&"holdout") and GameData.ROUTE_MISSIONS.size() == 6,
		"holdout mission exists and is not offered on boat routes")
	var ctx := RunContext.new(3)
	ctx.island_index = RunContext.ISLAND_COUNT - 1  # the last island
	ctx.mission = &"holdout"
	var run := IslandRun.new(11)
	run.map.exit = run.map.generators[0]  # an Exit must not matter: the final ends on the boat
	run.map.defend_zone = run.map.generators[2]
	run.load_context(ctx)
	run.director.max_alive = 0
	_check(not run.has_boss and not run.has_exit() and run.site == run.map.defend_zone,
		"holdout: no Behemoth, extraction on the boat, zone at the marker")
	_check(not run.shows_boat(), "the rescue boat is not there before it is called")
	run.player_pos = run.site
	_step(run, int(GameData.HOLDOUT_TIME / DT) - 30)
	_check(run.objective == IslandRun.Objective.GENERATORS and run.objective_text().begins_with("Hold the fort courtyard"),
		"still holding just before %d s ('%s')" % [int(GameData.HOLDOUT_TIME), run.objective_text()])
	_step(run, 40)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.boat_eta > 0.0 and run.shows_boat(),
		"held: the boat is called (%.1f s out)" % run.boat_eta)
	run.player_pos = run.map.boat
	_step(run)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.boat_arrival() < 1.0
		and run.objective_text().begins_with("The boat is coming"), "at the pier too early: wait for the boat")
	var arrival_before: float = run.boat_arrival()
	_step(run, int(GameData.BOAT_ARRIVAL_TIME / DT) - 60)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.boat_arrival() > arrival_before,
		"the boat approaches (%.2f)" % run.boat_arrival())
	run.player_pos = run.site
	_step(run, 120)
	_check(run.boat_eta == 0.0 and run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.objective_text() == "Board the rescue boat!",
		"the boat has docked; the player is still in the courtyard")
	run.player_pos = run.map.boat
	_step(run)
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() >= 85, "boarding wins the expedition (Intel %d)" % run.intel_earned())


func _test_boat_scenery() -> void:
	var run := IslandRun.new(5)
	run.map.exit = run.map.generators[0]
	run.set_mission(&"activate")
	_check(run.shows_boat(), "generated (flat) islands keep the boat")
	var f: FlowField = run.field
	run.map.heights.resize(f.width * f.height)
	run.map.heights.fill(2.0)  # land everywhere: the Boat marker is inland (parts 2-3)
	_check(not run.shows_boat(), "a Boat marker inland on a part with an Exit hides the boat")
	run.map.heights.fill(-1.0)  # water under the hull: the landing (part 1)
	_check(run.shows_boat(), "the landing boat on part 1 stays as scenery")
	run.map.exit = Vector3(-1, 0, -1)
	run.map.heights.fill(2.0)
	_check(run.shows_boat(), "hand-made islands without an Exit always show the boat")


## Blocks every cell outside `poly` (as HandmadeIsland.play_area does).
func _block_outside(f: FlowField, poly: PackedVector2Array) -> void:
	for z in f.height:
		for x in f.width:
			if not Geometry2D.is_point_in_polygon(Vector2(x + 0.5, z + 0.5), poly):
				f.blocked[z * f.width + x] = 1


func _test_spawns_in_play_area() -> void:
	var run := IslandRun.new(13)
	var c: Vector3 = _free_near(run.field, Vector3(IslandMap.SIZE * 0.5, 0, IslandMap.SIZE * 0.5))
	run.player_pos = c
	# A small yard with a 6 m wide path out of it: most of every spawn ring
	# (28-45 m) is outside.
	var poly := PackedVector2Array([
		Vector2(c.x - 8, c.z - 8), Vector2(c.x + 8, c.z - 8), Vector2(c.x + 8, c.z - 3),
		Vector2(c.x + 60, c.z - 3), Vector2(c.x + 60, c.z + 3), Vector2(c.x + 8, c.z + 3),
		Vector2(c.x + 8, c.z + 8), Vector2(c.x - 8, c.z + 8)])
	_block_outside(run.field, poly)
	run.field.compute_now(run.field.world_to_cell(c))
	var bad: int = 0
	for n in 500:
		run._spawn_enemy()
		if run.horde.count > 0:
			var q: Vector3 = run.horde.positions[run.horde.count - 1]
			if not Geometry2D.is_point_in_polygon(Vector2(q.x, q.z), poly) or run.field.distance_at(q) >= FlowField.UNREACHABLE:
				bad += 1
			run.horde.remove(run.horde.count - 1)
	print("  narrow yard: %d requests, %d needed the ring fallback, %d found no spot" % [run.spawn_requests, run.spawn_fallbacks, run.spawn_failures])
	_check(bad == 0, "no spawn outside the play area or unreachable (%d bad)" % bad)
	_check(run.spawn_failures * 10 < run.spawn_requests, "the fallback keeps spawning near the boundary (%d/%d failed)" % [run.spawn_failures, run.spawn_requests])
	# The boss: 22 m from the player is outside this yard, and the map's
	# generators may be outside too. It must still land inside, reachable.
	run.map.generators.clear()
	run._spawn_boss()
	var b: int = run.boss_index()
	var bp: Vector3 = run.horde.positions[b] if b != -1 else Vector3.ZERO
	_check(b != -1 and Geometry2D.is_point_in_polygon(Vector2(bp.x, bp.z), poly) and run.field.distance_at(bp) < FlowField.UNREACHABLE,
		"boss fallback inside the play area, without generators")
	# Summons around an enraged boss standing against the edge.
	run.horde.positions[b] = Vector3(c.x - 7.0, 0, c.z)
	run.boss_enraged = true
	run.boss_max_hp = run.horde.hp[b] * 4.0
	var before: int = run.horde.count
	run._summon_cd = 0.0
	run._update_boss(DT, b)
	var outside: int = 0
	for i in range(before, run.horde.count):
		var q: Vector3 = run.horde.positions[i]
		if not Geometry2D.is_point_in_polygon(Vector2(q.x, q.z), poly) or run.field.distance_at(q) >= FlowField.UNREACHABLE:
			outside += 1
	_check(outside == 0, "boss summons stay inside (%d summoned, %d outside)" % [run.horde.count - before, outside])


## The real fort part (Berlenga, part 4: Expeditions.ALL), with its own
## play area (FORT only if the scene has none). Spawns are sampled at the
## part's start, its courtyard (DefendZone) and its pier (Boat).
func _test_berlenga_fort() -> void:
	var path: String = String(Expeditions.ALL[&"berlenga"][3]["scene"])
	_check(ResourceLoader.exists(path), "Berlenga part 4 scene exists (%s)" % path)
	if not ResourceLoader.exists(path):
		return
	var island: HandmadeIsland = (load(path) as PackedScene).instantiate()
	root.add_child(island)
	var poly: PackedVector2Array = island.play_area
	if poly.is_empty():
		for v: Array in FORT:
			poly.append(Vector2(v[0], v[1]))
		island.play_area = poly
	island.horde_radius = 0  # parts are Hashima-sized: whole-part flow field
	var map: IslandMap = island.build_map([])
	var bad: int = 0
	var report := PackedStringArray()
	var samples: Array[Vector2] = []
	for q: Vector3 in [map.player_start, map.defend_zone, map.boat]:
		if q.x >= 0.0:
			samples.append(Vector2(floorf(q.x), floorf(q.z)))
	for s: Vector2 in samples:
		var p: Vector3 = _free_near(map.field, Vector3(s.x + 0.5, 0, s.y + 0.5))
		var run := IslandRun.new(3, &"beach", map)
		run.player_pos = p
		run.field.compute_now(run.field.world_to_cell(p))
		for n in 300:
			run._spawn_enemy()
			if run.horde.count > 0:
				var q: Vector3 = run.horde.positions[run.horde.count - 1]
				if not Geometry2D.is_point_in_polygon(Vector2(q.x, q.z), poly) or run.field.distance_at(q) >= FlowField.UNREACHABLE:
					bad += 1
				run.horde.remove(run.horde.count - 1)
		report.append("(%d, %d) 12-try misses %d/%d, failed %d" % [int(s.x), int(s.y), run.spawn_fallbacks, run.spawn_requests, run.spawn_failures])
	print("  Berlenga fort: " + "; ".join(report))
	_check(bad == 0, "Berlenga fort: every spawn inside the part and reachable")
	island.queue_free()


func _free_near(f: FlowField, p: Vector3) -> Vector3:
	for r in 15:
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if not Horde.overlaps_wall(f, p.x + dx, p.z + dz, 0.4):
					return Vector3(p.x + dx, 0, p.z + dz)
	return p
