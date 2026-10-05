extends SceneTree
## World dressing built from the island map: Terrain3D ground, Road Generator
## roads and the low-poly soldier. Visual only, but the data must be right:
## land stays flat at 0, roads run on walkable cells, models have a muzzle.
## Run: godot --headless --path . --script res://tests/test_world_dressing.gd

var _failures: int = 0
var _frames: int = 0
var _terrain: Node3D


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	# Roads: every planned point is on a walkable cell.
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		var map := IslandMap.build(31, biome)
		var paths: Array[PackedVector3Array] = IslandRoads.plan(map)
		var ok: bool = not paths.is_empty()
		for path in paths:
			ok = ok and path.size() >= 2
			for p in path:
				var c: Vector2i = map.field.world_to_cell(p)
				ok = ok and not map.field.is_blocked(c.x, c.y)
		_check(ok, "%s: %d road(s) planned on walkable cells" % [biome, paths.size()])
	# Soldier models: both classes, gun muzzle in front of the body (-Z).
	for id: StringName in [&"recruit", &"vanguard"]:
		var s := SoldierModel.create(id)
		# Muzzle position in the model's space (not in the tree yet).
		var t := Transform3D()
		var n: Node3D = s.muzzle
		while n != s:
			t = n.transform * t
			n = n.get_parent()
		_check(t.origin.z < -0.3 and t.origin.y > 1.0, "%s model has a forward muzzle at chest height" % id)
		s.animate(1.0, 0.1)
		s.free()
	# Terrain: a 10x10 grid with a 4x4 island in the middle.
	var land := PackedByteArray()
	land.resize(100)
	for z in range(3, 7):
		for x in range(3, 7):
			land[z * 10 + x] = 1
	var colors := PackedColorArray()
	colors.resize(100)
	colors.fill(Color.RED)
	_terrain = IslandTerrain.build(root, 10, 10, land, colors, Color.BLUE)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	if _terrain == null:
		_check(not ClassDB.class_exists(&"Terrain3D"), "terrain falls back only without the addon")
	else:
		var data: Object = _terrain.get("data")
		var land_h: float = data.call("get_height", Vector3(5, 0, 5))
		var sea_h: float = data.call("get_height", Vector3(0, 0, 0))
		_check(is_equal_approx(land_h, 0.0), "terrain: land is flat at 0 m")
		_check(sea_h < -1.0, "terrain: the sea floor slopes down (%.2f m)" % sea_h)
	quit(1 if _failures > 0 else 0)
	return true
