extends SceneTree
## Hand-made islands: the template scene converts to a grid where the sea
## and cliffs block, gentle hills stay walkable, objects block their
## footprint (trees only the trunk) and markers become the goals.
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


func _run_checks() -> void:
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
