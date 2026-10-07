extends SceneTree
## Hand-made islands: the template scene converts to a grid where the sea
## and cliffs block, gentle hills stay walkable, objects block their
## footprint (trees only the trunk) and markers become the goals. The four
## route islands convert without problems, walk over their bridges (water
## under the deck) and have road meshes.
## Run: godot --headless --path . --script res://tests/test_handmade.gd

var _failures: int = 0
var _island: HandmadeIsland
var _frames: int = 0
var _scene: Node
var _scene_frames: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
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


## Berlenga Grande (tools/real_island/build.gd): a real 1.5 km island. It
## converts without problems in a few seconds, its horde works around the
## player only (horde_radius) and enemies left far behind are replaced.
func _berlenga_checks() -> void:
	var path: String = HandmadeIsland.ISLANDS_DIR + "beach_berlenga.scn"
	var island: HandmadeIsland = (load(path) as PackedScene).instantiate()
	root.add_child(island)
	var problems: Array[String] = []
	var t0: int = Time.get_ticks_msec()
	var map: IslandMap = island.build_map(problems)
	var ms: int = Time.get_ticks_msec() - t0
	var f: FlowField = map.field
	_check(problems.is_empty(), "beach_berlenga has no problems %s" % [problems])
	_check(f.width > 1000 and map.generators.size() == 3 and map.caches.size() >= 5, "%d m island, 3 generators, %d caches" % [f.width, map.caches.size()])
	_check(ms < 8000, "grid of %d cells converted in %d ms" % [f.width * f.height, ms])
	_check(f.max_distance == island.horde_radius and island.horde_radius > 0, "horde paths limited to %d m around the player" % f.max_distance)
	var decks: int = 0
	var walkable: int = 0
	for deck: Node3D in island.get_node("Bridges").get_children():
		decks += 1
		var c: Vector2i = f.world_to_cell(deck.position)
		walkable += 0 if f.is_blocked(c.x, c.y) else 1
	_check(decks >= 4 and walkable == decks, "%d bridge decks, %d walkable in the middle" % [decks, walkable])
	var picked: Array[String] = []
	for s in 8:
		var scene: PackedScene = HandmadeIsland.pick(&"beach", s)
		if not picked.has(scene.resource_path):
			picked.append(scene.resource_path)
	_check(picked.has(path) and picked.size() == 2, "Beach routes pick beach_01 or Berlenga %s" % [picked])
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


func _run_checks() -> void:
	_route_island_checks()
	_berlenga_checks()
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
