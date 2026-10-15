extends SceneTree
## Hand-made islands: the template scene converts to a grid where the sea
## and cliffs block, gentle hills stay walkable, objects block their
## footprint (trees only the trunk) and markers become the goals. The four
## route islands convert without problems, walk over their bridges (water
## under the deck) and have road meshes. The Berlenga expedition: the whole
## island and its four parts (scenes inherited from one base, one terrain).
## Run: godot --headless --path . --script res://tests/test_handmade.gd
##      [-- --berlenga-dir res://tools/real_island/test_out/<name>/] to check a test build
##      [--check-failed-build] also checks that a failed build leaves that folder untouched (slow)

var _failures: int = 0
## Where the Berlenga's scenes are (tools/real_island/build.gd -- berlenga).
var _berlenga_dir: String = Expeditions.DIR + "berlenga/"
var _check_failed_build: bool = false
var _island: HandmadeIsland
var _frames: int = 0
var _scene: Node
var _scene_frames: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--berlenga-dir")
	if at >= 0 and at + 1 < args.size():
		_berlenga_dir = args[at + 1].trim_suffix("/") + "/"
	_check_failed_build = args.has("--check-failed-build")
	_island = (load("res://game/world/handmade/island_template.tscn") as PackedScene).instantiate()
	root.add_child(_island)


func _process(_delta: float) -> bool:
	_frames += 1
	var terrain: Node = _island.get_node("Terrain3D")
	if (terrain.get("data") == null or terrain.get("data").call("get_region_count") == 0) and _frames < 60:
		return false
	if _scene == null:
		_run_checks()
		# The island scene playing the template (as F6 with handmade_scene set).
		_scene = (load("res://game/world/island.tscn") as PackedScene).instantiate()
		_scene.set("handmade_scene", load("res://game/world/handmade/island_template.tscn"))
		root.add_child(_scene)
		return false
	_scene_frames += 1
	if _scene_frames < 10:
		return false
	_scene_checks()
	quit(1 if _failures > 0 else 0)
	return true


func _scene_checks() -> void:
	var run: IslandRun = _scene.get("run")
	_check(run.map.handmade and _scene.get_node_or_null("IslandTemplate") != null, "island scene uses the hand-made map and its models")
	_check(absf(run.map.ground_y(Vector3(110.5, 0, 55.5)) - 8.0) < 0.1 and absf(run.map.ground_y(run.map.player_start)) < 0.05,
		"ground_y follows the terrain (hill 8 m, beach 0 m)")
	run.player_pos = Vector3(110.5, 0, 55.5)
	_scene.call("_draw_player_and_camera")
	var player: Node3D = _scene.get("_player")
	_check(absf(player.position.y - 8.0) < 0.1, "player stands on the hill (y %.2f)" % player.position.y)
	_check(HandmadeIsland.pick(&"volcano", 1) == null, "no hand-made island for a biome -> generated")


func _route_island_checks() -> void:
	for biome in ["beach", "town", "jungle", "port"]:
		var island: HandmadeIsland = (load(HandmadeIsland.ISLANDS_DIR + biome + "_01.tscn") as PackedScene).instantiate()
		var problems: Array[String] = []
		var map: IslandMap = island.build_map(problems)
		_check(problems.is_empty(), "%s_01 has no problems %s" % [biome, problems])
		var decks: Array[Node] = island.get_node("Bridges").get_children()
		var ok: bool = true
		for deck: Node3D in decks:
			# Deck centre: walkable at the deck's height; 3 m beside it (along
			# the river, past the rails) is water.
			var c: Vector3 = deck.position
			var side: Vector3 = c + deck.basis.x.normalized() * ((deck as MeshInstance3D).mesh.get_aabb().size.x * 0.5 + 3.0)
			var cell: Vector2i = map.field.world_to_cell(c)
			ok = ok and not map.field.is_blocked(cell.x, cell.y) and map.ground_y(c) > 0.2
			ok = ok and map.field.is_blocked(map.field.world_to_cell(side).x, map.field.world_to_cell(side).y)
			# Near the rail a unit stays on the deck (no sinking towards the water).
			var rail: Vector3 = c + deck.basis.x.normalized() * ((deck as MeshInstance3D).mesh.get_aabb().size.x * 0.5 - 0.3)
			ok = ok and absf(map.ground_y(rail) - map.ground_y(c)) < 0.2
		var bridges: int = {"beach": 1, "town": 3, "jungle": 1, "port": 1}[biome]
		_check(decks.size() == bridges and ok, "%s_01: %d bridge(s), walkable decks over water" % [biome, decks.size()])
		_check(island.get_node_or_null("Decor/Roads/Surface") != null, "%s_01 has road meshes" % biome)
		island.free()


## Berlenga Grande (tools/real_island/build.gd): a real 1.5 km island, now
## the expedition's whole.scn (TEST ISLAND), out of the Beach rotation. It
## converts without problems in a few seconds, its horde works around the
## player only (horde_radius) and enemies left far behind are replaced.
func _berlenga_checks() -> void:
	var path: String = _berlenga_dir + "whole.scn"
	var island: HandmadeIsland = (load(path) as PackedScene).instantiate()
	root.add_child(island)
	var problems: Array[String] = []
	var t0: int = Time.get_ticks_msec()
	var map: IslandMap = island.build_map(problems)
	var ms: int = Time.get_ticks_msec() - t0
	var f: FlowField = map.field
	_check(problems.is_empty(), "Berlenga whole.scn has no problems %s" % [problems])
	_check(f.width > 1000 and map.generators.size() == 3 and map.caches.size() >= 5, "%d m island, 3 generators, %d caches" % [f.width, map.caches.size()])
	_check(ms < 8000, "grid of %d cells converted in %d ms" % [f.width * f.height, ms])
	_check(f.max_distance == island.horde_radius and island.horde_radius > 0, "horde paths limited to %d m around the player" % f.max_distance)
	var decks: int = 0
	var walkable: int = 0
	var pier: int = 0
	for deck: Node3D in island.get_node("Bridges").get_children():
		decks += 1
		pier += 1 if deck.name.begins_with("Pier_") else 0
		var c: Vector2i = f.world_to_cell(deck.position)
		walkable += 0 if f.is_blocked(c.x, c.y) else 1
	_check(decks >= 4 and pier > 0 and walkable == decks, "%d bridge decks (%d on the fort's pier), %d walkable in the middle" % [decks, pier, walkable])
	var picked: Array[String] = []
	for s in 8:
		var scene: PackedScene = HandmadeIsland.pick(&"beach", s)
		if not picked.has(scene.resource_path):
			picked.append(scene.resource_path)
	_check(not picked.any(func(p: String) -> bool: return "berlenga" in p), "Beach routes no longer pick the Berlenga %s" % [picked])
	# The horde on the big map: the field around the player finishes while
	# they walk, enemies spawn and reach them, a straggler far away goes.
	var run := IslandRun.new(7, map.biome, map)
	run.director.trigger_peak(30.0)
	var finished: int = 0
	var t1: int = Time.get_ticks_usec()
	for i in 600:
		var was: bool = f.is_computing
		run.step(1.0 / 60.0, Vector2(0, -1) if i < 300 else Vector2.ZERO, Vector3(0, 0, -1), false)
		finished += 1 if was and not f.is_computing else 0
	var step_ms: float = (Time.get_ticks_usec() - t1) / 600000.0
	_check(finished >= 10 and run.horde.count > 10, "big map: field finished %d times in 10 s, %d enemies, %.2f ms per step" % [finished, run.horde.count, step_ms])
	var far: Vector3 = run.player_pos + Vector3(0, 0, 0)
	for p in [Vector3(400, 0, 0), Vector3(-400, 0, 0), Vector3(0, 0, 400), Vector3(0, 0, -400)]:
		var q: Vector3 = run.player_pos + p
		var c: Vector2i = f.world_to_cell(q)
		if not f.is_blocked(c.x, c.y):
			far = q
			break
	var before: int = run.horde.count
	run.horde.add(far, GameData.EnemyKind.WALKER, RandomNumberGenerator.new())
	for i in 90:
		run.step(1.0 / 60.0, Vector2.ZERO, Vector3(0, 0, -1), false)
	var left: bool = true
	for i in run.horde.count:
		left = left and run.horde.positions[i].distance_to(far) > 1.0
	_check(far != run.player_pos and left, "a straggler 400 m away is replaced (%d -> %d enemies)" % [before, run.horde.count])
	island.queue_free()


## The Berlenga expedition's four parts (docs/design/BERLENGA_EXPEDITION.md):
## each converts without problems, has its mission and a play area holding
## only its part of the island (parts share cells only with the next or
## previous part, inside their portal), every marker reachable and near its
## design spot (build.gd PLACES), the Exit at its crossing, the shut Caminho
## do Forte stays shut, the final's boat on the pier deck facing open water,
## natural boundary dressing off the walkable cells; all four share one
## terrain and store only their differences.
func _expedition_checks() -> void:
	var parts: Array = Expeditions.parts(&"berlenga")
	_check(parts.size() == 4, "the Berlenga expedition has 4 parts")
	var design: Array = (load("res://tools/real_island/build.gd") as GDScript).get_script_constant_map()["PLACES"]["berlenga"]["parts"]
	var terrains: Dictionary = {}
	var walk: Array[PackedByteArray] = []
	var exits: Array[Vector3] = []
	for k in parts.size():
		var part: Dictionary = parts[k]
		var spec: Dictionary = design[k]
		var path: String = _berlenga_dir + String(part["scene"]).get_file()
		var label: String = "part_%d (%s)" % [k + 1, part["mission"]]
		if not ResourceLoader.exists(path):
			_check(false, "%s: %s exists" % [label, path])
			return
		var island: HandmadeIsland = (load(path) as PackedScene).instantiate()
		var problems: Array[String] = []
		var map: IslandMap = island.build_map(problems)
		var f: FlowField = map.field  # dist: walking distances from the start
		var open: int = 0
		for b in f.blocked:
			open += 1 if b == 0 else 0
		walk.append(f.blocked)
		exits.append(map.exit)
		_check(problems.is_empty(), "%s has no problems %s" % [label, problems])
		_check(island.mission == part["mission"] and island.mission == spec["mission"] and island.play_area.size() >= 4,
			"%s: mission '%s', play area of %d points" % [label, island.mission, island.play_area.size()])
		_check(open > 30000 and open < 400000, "%s: %d walkable cells, its part of the island only" % [label, open])
		var goals: Array[Vector3] = [map.boat]
		goals.append_array(map.generators)
		goals.append_array(map.caches)
		for p: Vector3 in [map.exit, map.rescue_target, map.defend_zone]:
			if p.x >= 0.0:
				goals.append(p)
		goals.append_array(map.hold_points)
		goals.append_array(map.signal_points)
		goals.append_array(map.signal_fuel)
		goals.append_array(map.escort_route)
		goals.append_array(map.escort_stops)
		_check(goals.all(func(g: Vector3) -> bool: return f.distance_at(g) < FlowField.UNREACHABLE),
			"%s: its %d markers are reachable from the start" % [label, goals.size()])
		# Each marker at most 10 m from where the design puts it (snapped to clear ground).
		var pairs: Array = []  # [what, placed, design]
		if spec.has("rescue"):
			pairs.append(["RescueTarget", map.rescue_target, spec["rescue"]])
		if spec.has("defend"):
			pairs.append(["DefendZone", map.defend_zone, spec["defend"]])
		# Escort (survivor variant): EscortSurvivor at its spot, the route
		# markers and two stops (placed along the road by the builder).
		if spec.has("escort"):
			var esc: Dictionary = spec["escort"]
			_check(map.escort_survivor and map.escort_route.size() >= 3 and map.escort_stops.size() == int(esc.get("stops", 2)),
				"%s: EscortSurvivor, %d route markers, %d EscortStop markers" % [label, map.escort_route.size() - 1, map.escort_stops.size()])
			pairs.append(["EscortSurvivor", map.escort_route[0] if not map.escort_route.is_empty() else Vector3(-1000, 0, -1000), esc["survivor"]])
		var holds: Array = spec.get("holds", [])
		_check(map.hold_points.size() == holds.size(), "%s: %d HoldPoint markers, in order" % [label, map.hold_points.size()])
		for h in holds.size():
			pairs.append(["HoldPoint_%d" % (h + 1), map.hold_points[h] if h < map.hold_points.size() else Vector3(-1000, 0, -1000), holds[h]])
		# Light the Signals: Signal_* then the Lighthouse, and one Fuel_* each.
		var sigs: Array = spec.get("signals", []).duplicate()
		if spec.has("lighthouse"):
			sigs.append(spec["lighthouse"])
		var fuel: Array = spec.get("fuel", [])
		_check(map.signal_points.size() == sigs.size() and map.signal_fuel.size() == fuel.size() and map.signal_lighthouse == spec.has("lighthouse"),
			"%s: %d signal markers (lighthouse: %s), %d Fuel markers" % [label, map.signal_points.size(), map.signal_lighthouse, map.signal_fuel.size()])
		for s in sigs.size():
			var sname: String = "Lighthouse" if spec.has("lighthouse") and s == sigs.size() - 1 else "Signal_%d" % (s + 1)
			pairs.append([sname, map.signal_points[s] if s < map.signal_points.size() else Vector3(-1000, 0, -1000), sigs[s]])
		for u in fuel.size():
			pairs.append(["Fuel_%d" % (u + 1), map.signal_fuel[u] if u < map.signal_fuel.size() else Vector3(-1000, 0, -1000), fuel[u]])
		var gens: Array = spec.get("generators", [])
		for g in gens.size():
			pairs.append(["Generator%d" % (g + 1), map.generators[g] if g < map.generators.size() else Vector3(-1000, 0, -1000), gens[g]])
		var caches: Array = spec.get("caches", [])
		for c in caches.size():
			pairs.append(["Cache%d" % (c + 1), map.caches[c] if c < map.caches.size() else Vector3(-1000, 0, -1000), caches[c]])
		var worst: float = 0.0
		var worst_name: String = ""
		for pr: Array in pairs:
			var d: float = Vector2(pr[1].x, pr[1].z).distance_to(pr[2])
			if d > worst:
				worst = d
				worst_name = pr[0]
		_check(pairs.size() >= 2 and worst <= 10.0, "%s: %d markers within 10 m of the design (furthest %s, %.1f m)" % [label, pairs.size(), worst_name, worst])
		if k < 3:
			var cross: Vector2 = spec["exit"][0]
			var e := Vector2(map.exit.x, map.exit.z)
			_check(map.exit.x >= 0.0 and e.distance_to(cross) <= 10.0 and f.distance_at(map.exit) < FlowField.UNREACHABLE,
				"%s: Exit at (%d, %d), %.1f m from the crossing (%d, %d), %d m walk from the start"
				% [label, int(e.x), int(e.y), e.distance_to(cross), int(cross.x), int(cross.y), f.distance_at(map.exit)])
		else:
			# The final: the rescue boat moors at the end of the fort's pier (a
			# walkable deck in Bridges/) and sails in along its +Z, over open water.
			var boat: Node3D = island.get_node("Markers/Boat")
			var on_deck: bool = false
			for deck: Node in island.get_node("Bridges").get_children():
				if deck.name.begins_with("Pier_") and Vector2((deck as Node3D).position.x, (deck as Node3D).position.z).distance_to(Vector2(map.boat.x, map.boat.z)) < 6.0:
					on_deck = true
			var sea: bool = true
			for d: float in [6.0, 10.0, 15.0, 20.0]:
				var p: Vector3 = map.boat + map.boat_dir * d
				var c: Vector2i = f.world_to_cell(p)
				sea = sea and f.is_blocked(c.x, c.y) and map.heights[c.y * f.width + c.x] < island.sea_level
			_check(map.exit.x < 0.0 and on_deck and map.ground_y(map.boat) > 0.5 and f.distance_at(map.boat) < FlowField.UNREACHABLE,
				"%s: no Exit, the boat on the pier deck at (%d, %d), %.1f m high, reachable" % [label, int(map.boat.x), int(map.boat.z), map.ground_y(map.boat)])
			_check(sea and boat.basis.z.dot(Vector3(map.boat_dir.x, 0, map.boat_dir.z)) > 0.99, "%s: the boat's +Z (%.2f, %.2f) points out over open water for 20 m" % [label, map.boat_dir.x, map.boat_dir.z])
		# The Caminho do Forte crossing between parts 2 and 4 (559, 800) stays shut.
		if k == 1 or k == 3:
			var far := Vector3(555.5, 0, 808.5) if k == 1 else Vector3(562.5, 0, 792.5)
			_check(f.distance_at(far) >= FlowField.UNREACHABLE, "%s: the Caminho do Forte is shut at the part's edge" % label)
		var boundary: Node = island.get_node_or_null("Decor/Boundary")
		var copies: int = 0
		var on_walkable: int = 0
		if boundary != null:
			for n: Node in boundary.get_children():
				if n is Scatter:
					var sc := n as Scatter
					var box: AABB = sc.mesh.get_aabb()
					for i in sc.count():
						copies += 1
						on_walkable += 1 if _covers_walkable_box(f, sc.transform * sc.instance_transform(i) * box) else 0
				elif n is MeshInstance3D:
					var faces: PackedVector3Array = (n as MeshInstance3D).mesh.get_faces()
					for i in range(0, faces.size(), 3):
						on_walkable += 1 if _covers_walkable_tri(f, faces[i], faces[i + 1], faces[i + 2]) else 0
		_check(copies > 100 and on_walkable == 0, "%s: natural boundary dressing (%d stones and boulders), none over a walkable cell (%d)" % [label, copies, on_walkable])
		var kb: int = FileAccess.get_file_as_bytes(path).size() / 1024
		_check(kb < 1024, "%s: stores only its differences from base.scn (%d KB)" % [label, kb])
		terrains[island.get_node("Terrain3D").get("data_directory")] = true
		island.free()
	_check(terrains.size() == 1, "the parts share one terrain folder %s" % [terrains.keys()])
	# Walkable in two parts: never two that do not follow each other, and two
	# that do only around their crossing (the portal, within 20 m of the Exit).
	var n: int = walk.size()
	var both: Array = []  # [a, b, cells, cells away from the crossing]
	for a in n:
		for b in range(a + 1, n):
			both.append([a, b, 0, 0])
	var size: int = int(sqrt(walk[0].size()))
	for i in walk[0].size():
		var mask: int = 0
		for k in n:
			if walk[k][i] == 0:
				mask |= 1 << k
		if mask & (mask - 1) == 0:
			continue
		for pair: Array in both:
			if mask & (1 << pair[0]) != 0 and mask & (1 << pair[1]) != 0:
				pair[2] += 1
				var e: Vector3 = exits[pair[0]]
				if Vector2(i % size + 0.5, i / size + 0.5).distance_to(Vector2(e.x, e.z)) > 20.0:
					pair[3] += 1
	for pair: Array in both:
		if pair[1] == pair[0] + 1:
			_check(pair[2] > 0 and pair[3] == 0, "parts %d and %d share %d walkable cells, all at their crossing" % [pair[0] + 1, pair[1] + 1, pair[2]])
		else:
			_check(pair[2] == 0, "parts %d and %d share no walkable cell (%d)" % [pair[0] + 1, pair[1] + 1, pair[2]])


## A walkable cell centre under `box` seen from above.
func _covers_walkable_box(f: FlowField, box: AABB) -> bool:
	for z in range(floori(box.position.z - 0.5), ceili(box.end.z) + 1):
		for x in range(floori(box.position.x - 0.5), ceili(box.end.x) + 1):
			if x + 0.5 >= box.position.x and x + 0.5 <= box.end.x and z + 0.5 >= box.position.z and z + 0.5 <= box.end.z and not f.is_blocked(x, z):
				return true
	return false


## A walkable cell centre under the triangle seen from above.
func _covers_walkable_tri(f: FlowField, a3: Vector3, b3: Vector3, c3: Vector3) -> bool:
	var a := Vector2(a3.x, a3.z)
	var b := Vector2(b3.x, b3.z)
	var c := Vector2(c3.x, c3.z)
	if absf((b - a).cross(c - a)) < 1e-6:
		return false  # edge-on from above (an end of the wall): covers nothing
	var lo: Vector2 = a.min(b).min(c)
	var hi: Vector2 = a.max(b).max(c)
	for z in range(floori(lo.y), ceili(hi.y) + 1):
		for x in range(floori(lo.x), ceili(hi.x) + 1):
			if not f.is_blocked(x, z) and Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, z + 0.5), a, b, c):
				return true
	return false


## Opt-in (-- --check-failed-build, with --berlenga-dir in tools/real_island/test_out/):
## runs the builder with a part forced to fail after it is written and checks
## that every file of the expedition folder is exactly as before (about a minute).
func _failed_build_checks() -> void:
	if not _berlenga_dir.begins_with("res://tools/real_island/test_out/"):
		_check(false, "--check-failed-build needs --berlenga-dir inside tools/real_island/test_out/")
		return
	var before: Dictionary = _md5_tree(_berlenga_dir)
	var out: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"--script", "res://tools/real_island/build.gd", "--", "berlenga", "--out-dir", _berlenga_dir, "--fail-part", "3"], out, true)
	var restored: bool = "".join(out).contains("put back as it was")
	var after: Dictionary = _md5_tree(_berlenga_dir)
	_check(code != 0 and restored and before.size() > 5 and before == after,
		"a build whose part 3 fails leaves the %d expedition files untouched (exit %d)" % [before.size(), code])


## path -> md5 of every file under `dir`.
func _md5_tree(dir: String) -> Dictionary:
	var out: Dictionary = {}
	for f in DirAccess.get_files_at(dir):
		out[dir.path_join(f)] = FileAccess.get_md5(dir.path_join(f))
	for sub in DirAccess.get_directories_at(dir):
		out.merge(_md5_tree(dir.path_join(sub)))
	return out


## Hashima was removed (2026-10-16): its scene is gone, and Port routes pick
## the remaining Port island (port_01), also for Sabotage.
func _hashima_checks() -> void:
	var path: String = HandmadeIsland.ISLANDS_DIR + "port_hashima.scn"
	_check(not ResourceLoader.exists(path), "port_hashima.scn is removed")
	var picked: Array[String] = []
	for s in 8:
		var scene: PackedScene = HandmadeIsland.pick(&"port", s)
		if scene != null and not picked.has(scene.resource_path):
			picked.append(scene.resource_path)
	_check(picked == [HandmadeIsland.ISLANDS_DIR + "port_01.tscn"], "Port routes pick port_01 only %s" % [picked])
	var sabotage: bool = true
	for s in 4:
		var scene: PackedScene = HandmadeIsland.pick(&"port", s, &"sabotage")
		sabotage = sabotage and scene != null and scene.resource_path == HandmadeIsland.ISLANDS_DIR + "port_01.tscn"
	_check(sabotage, "a Port Sabotage lands on port_01 (no preferred island)")


func _run_checks() -> void:
	_route_island_checks()
	_berlenga_checks()
	_expedition_checks()
	if _check_failed_build:
		_failed_build_checks()
	_hashima_checks()
	var problems: Array[String] = []
	var map: IslandMap = _island.build_map(problems)
	var f: FlowField = map.field
	_check(problems.is_empty(), "template has no problems %s" % [problems])
	_check(map.handmade and f.width == 160 and map.heights.size() == 160 * 160, "160 x 160 grid with heights")
	_check(f.is_blocked(5, 5) and not f.is_blocked(80, 80), "sea blocks, the middle is open ground")
	# Hill top (8 m, gentle) at (110, 55): walkable and high.
	_check(not f.is_blocked(110, 55) and map.heights[55 * 160 + 110] > 6.0, "gentle hill is walkable (%.1f m)" % map.heights[55 * 160 + 110])
	# Plateau (4 m) centred at (45, 50), radius 16: top open, rim is a cliff.
	_check(not f.is_blocked(45, 50) and f.is_blocked(45 + 16, 50), "plateau top open, its cliff edge blocks")
	var house: Rect2i = map.buildings[0]
	_check(house.size == Vector2i(8, 6) and f.is_blocked(house.position.x + 1, house.position.y + 1), "house blocks its 8 x 6 footprint (%s)" % [house])
	_check(map.trees.size() == 1 and f.is_blocked(map.trees[0].x, map.trees[0].y)
		and not f.is_blocked(map.trees[0].x + 2, map.trees[0].y), "tree blocks only its trunk cell")
	_check(map.generators.size() == 3 and map.caches.size() == 1 and map.boat == Vector3(80.5, 0, 138.5), "markers: boat, 3 generators, 1 cache")
	# The run plays on it like on a generated island.
	var run := IslandRun.new(7, map.biome, map)
	for i in 120:
		run.step(1.0 / 60.0, Vector2(0, -1), Vector3(0, 0, -1), false)
	_check(run.player_pos.z < map.player_start.z - 1.0, "IslandRun walks on the hand-made map")
	# Problems are reported: no boat, unreachable generator.
	_island.get_node("Markers/Boat").free()
	_island.get_node("Markers/Generator1").position = Vector3(5, 0, 5)
	problems.clear()
	_island.build_map(problems)
	_check(problems.any(func(p: String) -> bool: return p.begins_with("Missing Markers/Boat"))
		and problems.any(func(p: String) -> bool: return p.begins_with("Generator at (5, 5)")), "reports missing boat and unreachable generator (%s)" % [problems])
