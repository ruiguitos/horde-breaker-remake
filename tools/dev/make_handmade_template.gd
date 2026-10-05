extends SceneTree
## One-off: builds game/world/handmade/island_template.tscn, the starting
## point for hand-made islands: a Terrain3D island (flat beach, one hill, a
## cliff plateau), the sea, one example of each object and every marker.
## Run: godot --headless --path . --script res://tools/dev/make_handmade_template.gd

const DIR: String = "res://game/world/handmade/"
const KIT: String = "res://assets/models/nature_megakit/"
const SIZE: int = 160

var _root: Node3D
var _terrain: Node3D
var _frames: int = 0


func _initialize() -> void:
	_root = Node3D.new()
	_root.name = "IslandTemplate"
	_root.set_script(load(DIR + "handmade_island.gd"))
	root.add_child(_root)
	_terrain = ClassDB.instantiate(&"Terrain3D")
	_terrain.name = "Terrain3D"
	_terrain.set("region_size", 256)
	_terrain.set("vertex_spacing", 1.0)
	_root.add_child(_terrain)
	_terrain.owner = _root


func _process(_delta: float) -> bool:
	_frames += 1
	if _terrain.get("data") == null:
		if _frames > 60:
			print("TEST FAIL: Terrain3D data never appeared")
			quit(1)
		return false
	_build()
	quit(0)
	return true


func _build() -> void:
	# Heights: island disc at 0 m, sea floor at -3 m, a round hill (8 m) and
	# a flat plateau (4 m) with a cliff edge, so both slope rules show up.
	var c: float = SIZE * 0.5
	var height := Image.create_empty(SIZE + 1, SIZE + 1, false, Image.FORMAT_RF)
	var color := Image.create_empty(SIZE + 1, SIZE + 1, false, Image.FORMAT_RGBA8)
	var sand := Color(0.86, 0.78, 0.55)
	var grass := Color(0.42, 0.55, 0.3)
	for z in SIZE + 1:
		for x in SIZE + 1:
			var d: float = Vector2(x - c, z - c).length()
			var h: float = -3.0 * smoothstep(64.0, 74.0, d)
			h += 8.0 * exp(-Vector2(x - c - 30, z - c + 25).length_squared() / 300.0)
			if Vector2(x - c + 35, z - c + 30).length() < 16.0:
				h = maxf(h, 4.0)
			height.set_pixel(x, z, Color(h, 0, 0))
			color.set_pixel(x, z, sand.lerp(grass, clampf((62.0 - d) / 10.0, 0.0, 1.0)))
	var mat: Object = _terrain.get("material")
	if mat != null:
		mat.set("world_background", 0)
	IslandTerrain._add_ground_texture(_terrain)
	var data: Object = _terrain.get("data")
	data.call("import_images", [height, null, color], Vector3.ZERO, 0.0, 1.0)
	var data_dir: String = DIR + "island_template_data"
	DirAccess.make_dir_recursive_absolute(data_dir)
	data.call("save_directory", data_dir)
	_terrain.set("data_directory", data_dir)
	ResourceSaver.save(_terrain.get("assets"), DIR + "ground_assets.res")
	_terrain.set("assets", load(DIR + "ground_assets.res"))
	# Containers.
	for group in ["Buildings", "Trees", "Rocks", "Decor", "Markers"]:
		var n := Node3D.new()
		n.name = group
		_root.add_child(n)
		n.owner = _root
	# Sea surface (decor: the game draws its own sea).
	var sea := MeshInstance3D.new()
	sea.name = "SeaPreview"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE + 80, SIZE + 80)
	sea.mesh = plane
	sea.position = Vector3(c, -0.3, c)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.35, 0.55, 0.8)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = water
	_add(sea, "Decor")
	# One building: a grey box (replace with real models later).
	var house := MeshInstance3D.new()
	house.name = "House"
	var box := BoxMesh.new()
	box.size = Vector3(8, 4, 6)
	house.mesh = box
	house.position = Vector3(c - 12, 2, c + 10)
	_add(house, "Buildings")
	_add_model(KIT + "CommonTree_1.gltf", "Tree", Vector3(c + 10, 0, c + 12), "Trees")
	_add_model(KIT + "Rock_Medium_1.gltf", "Rock", Vector3(c + 4, 0, c - 6), "Rocks")
	# Markers: boat on the south shore, goals spread out.
	var marks: Dictionary = {
		"Boat": Vector3(c, 0, c + 58), "PlayerStart": Vector3(c, 0, c + 53),
		"Generator1": Vector3(c - 38, 0, c - 10), "Generator2": Vector3(c + 40, 0, c - 5),
		"Generator3": Vector3(c + 2, 0, c - 50), "Cache1": Vector3(c + 25, 0, c + 30),
	}
	for key: String in marks:
		var m := Marker3D.new()
		m.name = key
		m.gizmo_extents = 3.0
		m.position = marks[key]
		_add(m, "Markers")
	var packed := PackedScene.new()
	packed.pack(_root)
	var err := ResourceSaver.save(packed, DIR + "island_template.tscn")
	var problems: Array[String] = []
	var map: IslandMap = _root.build_map(problems)
	HandmadeIsland.grid_image(map).save_png(DIR + "island_template_grid.png")
	print("template saved: %s, problems: %s" % [error_string(err), problems])


func _add(n: Node3D, group: String) -> void:
	_root.get_node(group).add_child(n)
	n.owner = _root


func _add_model(path: String, node_name: String, pos: Vector3, group: String) -> void:
	var inst: Node3D = (load(path) as PackedScene).instantiate()
	inst.name = node_name
	inst.position = pos
	_add(inst, group)
