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
		# The Recruit's own model holds its rifle low across the body (~1 m).
		_check(t.origin.z < -0.3 and t.origin.y > 0.9, "%s model has a forward muzzle at chest height" % id)
		s.animate(1.0, 0.1)
		s.free()
	_test_recruit_model()
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


## The Recruit uses the user's GLB: loaded, standing on the ground, ~2 m tall,
## muzzle at the rifle tip; other guns and first person still work.
func _test_recruit_model() -> void:
	var s := SoldierModel.create(&"recruit")
	_check(s.get("_model") != null, "recruit uses the imported model (recruit.glb)")
	var lo := INF
	var hi := -INF
	for mi in s.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := Transform3D()
		var n: Node = m
		while n != s:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var b: AABB = t * m.get_aabb()
		lo = minf(lo, b.position.y)
		hi = maxf(hi, b.end.y)
	_check(absf(lo) < 0.02 and hi > 1.8 and hi < 2.2, "recruit model stands on the ground, %.2f m tall" % hi)
	var mt := Transform3D()
	var mn: Node3D = s.muzzle
	while mn != s:
		mt = mn.transform * mt
		mn = mn.get_parent()
	_check(mt.origin.y > 0.9 and mt.origin.y < 1.6, "recruit muzzle at chest height (%.2f m)" % mt.origin.y)
	s.set_shadow_only(true)
	s.set_weapon(&"shotgun")
	_check(s.muzzle != null and s.muzzle.get_parent() != null, "recruit model swaps to a placeholder shotgun with a muzzle")
	s.set_weapon(&"rifle")
	_check(s.find_children("*", "MeshInstance3D", true, false).all(func(x: Node) -> bool:
		return (x as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "recruit body stays shadow-only in first person")
	s.animate(1.0, 0.2)
	s.free()
