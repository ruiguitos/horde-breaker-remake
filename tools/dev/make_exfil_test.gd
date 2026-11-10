extends SceneTree
## Builds game/world/handmade/test/exfil_test.tscn, the map of the EXFIL mode (DEV sandbox).
## The ground is a 256 m Terrain3D, flat at 0 m, with a soft coast in the outer 4 m (sea floor at -1 m).
## The arena comes from the Codex's plan (assets/models/environment/extraction_test_arena/layout.json,
## CC0): each instance is a placeholder box with its footprint from build_layout.py's BOUNDS, placed at
## the layout's x and z, rotated as the layout says. The modules' GLB are not delivered yet, so the
## heights below are assumptions (the plan gives none): walls 3 m, low cover 1.2 m, containers 2.6 m,
## pillars 6 m, beacon 3 m. Solid pieces go in Buildings/ (they block the grid), the ramp and the dock in
## Decor/ (the dock is decoration, as the sandbox's rules say). When the GLB modules arrive, replace the
## boxes inside Buildings/ and Decor/ with them: do not redraw the layout.
## Markers: PlayerStart at the main entry (128, 16), Boat at the dock's landing (128, 4), ExfilPoint at the
## extraction goal (128, 246), beside the beacon's pedestal.
## Run: godot --headless --path . --script res://tools/dev/make_exfil_test.gd

const DIR: String = "res://game/world/handmade/test/"
const DATA_DIR: String = DIR + "exfil_test_data"
const LAYOUT: String = "res://assets/models/environment/extraction_test_arena/layout.json"
const SIZE: int = 256
const COAST_METRES: float = 4.0  ## the ground falls to the sea over this strip at the square's edge
const SEA_FLOOR: float = -1.0

## Footprints as build_layout.py measures them: (x0, z0, x1, z1) in the piece's own frame, before rotation.
const BOUNDS: Dictionary = {
	"concrete_wall": [0.0, 0.0, 4.0, 0.4], "low_cover": [0.0, 0.0, 4.0, 0.4],
	"shipping_container": [0.0, 0.0, 6.0, 2.4], "platform": [0.0, 0.0, 8.0, 8.0],
	"ramp": [0.0, 0.0, 8.0, 4.0], "landmark_pillar": [0.0, 0.0, 1.2, 1.2],
	"extraction_beacon": [-1.0, -1.0, 1.0, 1.0], "dock": [0.0, 0.0, 10.0, 3.0],
}
## Placeholder heights (metres). Assumed: the plan gives footprints, not heights.
const HEIGHTS: Dictionary = {
	"concrete_wall": 3.0, "low_cover": 1.2, "shipping_container": 2.6, "landmark_pillar": 6.0,
	"platform": 1.2, "extraction_beacon": 3.0, "dock": 0.6,
}
## The ramp rises 1.2 m over its 4 m run (layout_features.json: slope 16.7 degrees).
const RAMP_RISE: float = 1.2
const RAMP_RUN: float = 4.0

var _root: Node3D
var _terrain: Node3D
var _frames: int = 0
var _meshes: Dictionary = {}  ## size key -> BoxMesh, shared by the placeholders of one size


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	_root = Node3D.new()
	_root.name = "ExfilTest"
	_root.set_script(load("res://game/world/handmade/handmade_island.gd"))
	_root.set("size", SIZE)
	_root.set("biome", &"beach")
	_root.set("mission", &"exfil")  # no generators are needed: the Activate check does not apply
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
	var height := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	var color := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var sand := Color(0.86, 0.78, 0.55)
	var grass := Color(0.42, 0.55, 0.3)
	for z in SIZE:
		for x in SIZE:
			var edge: float = minf(minf(x, z), minf(SIZE - 1 - x, SIZE - 1 - z))
			var t: float = clampf(edge / COAST_METRES, 0.0, 1.0)
			var h: float = lerpf(SEA_FLOOR, 0.0, t)
			height.set_pixel(x, z, Color(h, 0, 0))
			color.set_pixel(x, z, sand.lerp(grass, clampf((edge - 6.0) / 10.0, 0.0, 1.0)) if h > -0.3 else sand.darkened(0.3))
	var mat: Object = _terrain.get("material")
	if mat != null:
		mat.set("world_background", 0)
	IslandTerrain._add_ground_texture(_terrain)
	var data: Object = _terrain.get("data")
	data.call("import_images", [height, null, color], Vector3.ZERO, 0.0, 1.0)
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	data.call("save_directory", DATA_DIR)
	_terrain.set("data_directory", DATA_DIR)
	for group in ["Buildings", "Trees", "Rocks", "Decor", "Markers"]:
		var n := Node3D.new()
		n.name = group
		_root.add_child(n)
		n.owner = _root
	# Sea surface (decor: the game draws its own sea).
	var sea := MeshInstance3D.new()
	sea.name = "SeaPreview"
	var plane := PlaneMesh.new()
	plane.size = Vector2(800, 800)
	sea.mesh = plane
	sea.position = Vector3(SIZE * 0.5, -0.3, SIZE * 0.5)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.35, 0.55, 0.8)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = water
	_add(sea, "Decor")
	var layout: Array = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var placed: int = 0
	for item: Dictionary in layout:
		_piece(item)
		placed += 1
	# Markers.
	var marks: Dictionary = {"Boat": Vector3(128, 0, 4), "PlayerStart": Vector3(128, 0, 16), "ExfilPoint": Vector3(128, 0, 246),
		"ExfilPoint2": Vector3(12, 0, 128), "ExfilPoint3": Vector3(244, 0, 128)}  # the run draws one of the three
	for key: String in marks:
		var m := Marker3D.new()
		m.name = key
		m.gizmo_extents = 3.0
		m.position = marks[key]
		if key == "Boat":
			m.rotation.y = PI  # the boat is moored along the marker's +Z: turn it to the sea (the -Z side)
		_add(m, "Markers")
	var packed := PackedScene.new()
	packed.pack(_root)
	var err := ResourceSaver.save(packed, DIR + "exfil_test.tscn")
	print("exfil test scene saved: %s, %d layout pieces" % [error_string(err), placed])
	var problems: Array[String] = []
	var map: IslandMap = _root.build_map(problems)
	HandmadeIsland.grid_image(map).save_png(DIR + "exfil_test_grid.png")
	print("problems: %s" % [problems])


## One layout piece as a placeholder box: its footprint (rotated, at x and z), its height, its group.
func _piece(item: Dictionary) -> void:
	var module: String = item["module"]
	var at := Vector2(float(item["x"]), float(item["z"]))
	var angle: int = int(item["rotation_deg"])
	var fp: Rect2 = _footprint(module, angle, at)
	if module == "ramp":
		_ramp(fp, angle)
		return
	var h: float = HEIGHTS[module]
	var box := MeshInstance3D.new()
	box.name = "%s_%d_%d" % [module, int(at.x), int(at.y)]
	box.mesh = _box_mesh(Vector3(fp.size.x, h, fp.size.y))
	box.position = Vector3(fp.get_center().x, h * 0.5, fp.get_center().y)
	# Solid pieces block the grid; the dock is decoration (the sandbox's rule: the pier does not block).
	_add(box, "Decor" if module == "dock" else "Buildings")


## The ramp: a thin slab on the 16.7-degree slope that leads up to the platform.
func _ramp(fp: Rect2, angle: int) -> void:
	var slab := MeshInstance3D.new()
	slab.name = "Ramp_%d_%d" % [int(fp.position.x), int(fp.position.y)]
	var length: float = sqrt(RAMP_RUN * RAMP_RUN + RAMP_RISE * RAMP_RISE)
	slab.mesh = _box_mesh(Vector3(fp.size.x, 0.2, length))
	slab.position = Vector3(fp.get_center().x, RAMP_RISE * 0.5, fp.get_center().y)
	# A negative turn about X lifts +Z: the top (the +Z end, at the platform) comes up to RAMP_RISE.
	# test_exfil_map checks the engine's own transform of that end.
	slab.rotation.x = -atan2(RAMP_RISE, RAMP_RUN)
	_add(slab, "Decor")


## The footprint of a module in the world, after its cardinal rotation, at (x, z).
func _footprint(module: String, angle: int, at: Vector2) -> Rect2:
	var b: Array = BOUNDS[module]
	var corners: Array[Vector2] = [Vector2(b[0], b[1]), Vector2(b[2], b[1]), Vector2(b[2], b[3]), Vector2(b[0], b[3])]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector2 in corners:
		var p: Vector2 = _transform(c, angle) + at
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
	return Rect2(lo, hi - lo)


## build_layout.py's transform: 0, 90, 180 and 270 degrees.
func _transform(c: Vector2, angle: int) -> Vector2:
	match angle:
		90:
			return Vector2(c.y, -c.x)
		180:
			return Vector2(-c.x, -c.y)
		270:
			return Vector2(-c.y, c.x)
	return c


## One BoxMesh per size: 640 walls share two of them.
func _box_mesh(size: Vector3) -> BoxMesh:
	var key: String = "%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if not _meshes.has(key):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[key] = mesh
	return _meshes[key]


func _add(n: Node3D, group: String) -> void:
	_root.get_node(group).add_child(n)
	n.owner = _root
