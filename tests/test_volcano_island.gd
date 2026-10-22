extends SceneTree
## Volcano island (game/world/handmade/islands/volcano_01.tscn): it is listed
## for its biome, instantiates as a HandmadeIsland and converts without
## problems; it has the generators and caches the Activate mission needs,
## seven lava pools of LAVA_RADIUS none of them within 6 m of the boat or of
## the player's start; and pick() finds it for the Activate mission.
## Run: godot --headless --path . --script res://tests/test_volcano_island.gd

const SCENE_PATH: String = "res://game/world/handmade/islands/volcano_01.tscn"
const LAVA_POOLS: int = 7
const CACHES: int = 4
const MIN_FROM_SPOTS: float = 6.0

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_listed()
	_test_island()
	_test_pick()
	quit(1 if _failures > 0 else 0)


func _test_listed() -> void:
	var listed: bool = false
	for path: String in HandmadeIsland.island_paths():
		listed = listed or path.ends_with("volcano_01.tscn")
	_check(listed, "island_paths() lists volcano_01.tscn")


func _test_island() -> void:
	var scene: PackedScene = null
	if ResourceLoader.exists(SCENE_PATH):
		scene = load(SCENE_PATH) as PackedScene
	var node: Node = scene.instantiate() if scene != null else null
	var island: HandmadeIsland = node as HandmadeIsland
	_check(island != null, "volcano_01.tscn instantiates as a HandmadeIsland")
	if island == null:
		if node != null:
			node.free()
		return
	root.add_child(island)
	var problems: Array[String] = []
	var map: IslandMap = island.build_map(problems)
	_check(problems.is_empty(), "volcano_01 has no problems %s" % [problems])
	_check(map.generators.size() == GameData.GENERATOR_COUNT and map.caches.size() == CACHES,
		"%d generators, %d caches" % [map.generators.size(), map.caches.size()])
	_check(map.lava.size() == LAVA_POOLS and map.lava_radius.size() == LAVA_POOLS,
		"%d lava pools" % map.lava.size())
	var radius_ok: bool = true
	for r: float in map.lava_radius:
		radius_ok = radius_ok and is_equal_approx(r, HandmadeIsland.LAVA_RADIUS)
	_check(radius_ok, "every lava pool has the radius LAVA_RADIUS (%.1f m)" % HandmadeIsland.LAVA_RADIUS)
	var boat := Vector2(map.boat.x, map.boat.z)
	var start := Vector2(map.player_start.x, map.player_start.z)
	var nearest: float = INF
	for lava: Vector3 in map.lava:
		var p := Vector2(lava.x, lava.z)
		nearest = minf(nearest, minf(p.distance_to(boat), p.distance_to(start)))
	_check(not map.lava.is_empty() and nearest >= MIN_FROM_SPOTS,
		"lava pools at least %.0f m from the boat and the start (nearest %.1f m)" % [MIN_FROM_SPOTS, nearest])
	var blocked: int = 0
	for lava: Vector3 in map.lava:
		if map.field.is_blocked(int(lava.x), int(lava.z)):
			blocked += 1
	_check(blocked == 0, "every lava pool centre is walkable ground (%d blocked)" % blocked)
	root.remove_child(island)
	island.free()


func _test_pick() -> void:
	var picked: PackedScene = HandmadeIsland.pick(&"volcano", 1, &"activate")
	_check(picked != null, "pick(volcano, 1, activate) gives a hand-made island")
