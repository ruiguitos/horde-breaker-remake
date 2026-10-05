@tool
class_name HandmadeIsland
extends Node3D
## An island built by hand in the editor. The game still plays on a 2D grid
## (1 cell = 1 m), so build_map() reads this scene and converts it:
##   Terrain3D      -> below the sea level or too steep = blocked
##   Buildings/     -> every child blocks the cells under its footprint
##   Rocks/         -> same as buildings (single rocks block one cell)
##   Trees/         -> every child blocks only the cell of its trunk
##   Decor/         -> never blocks (grass, flowers, roads, lights, water)
##   Markers/       -> Boat (required), PlayerStart, Generator*, Cache*
## The island covers x, z in [0, size): keep everything inside that square.
## How to build one: game/README.md, "Ilhas feitas à mão".

## Side of the playable square in metres (cells).
@export var size: int = 160
## Height of the sea surface; ground lower than this (+ a margin) is sea.
@export var sea_level: float = -0.3
## Steepest walkable step between neighbouring cells, in metres per metre
## (1.0 = 45°). Steeper ground is a wall (cliff).
@export var max_step: float = 0.9
## Biome look (sky, fog, ambience, minimap colours): see GameData.BIOMES.
@export var biome: StringName = &"beach"
## Writes a top-down picture of the converted grid next to this scene and
## prints a report: what blocks, what is unreachable from the boat.
@export_tool_button("Check map", "Search") var check_button: Callable = check_map

## Islands used by the run: <biome>_<anything>.tscn (beach_01.tscn,
## town_harbour.tscn...). One is picked per island; none = generated island.
const ISLANDS_DIR: String = "res://game/world/handmade/islands/"
const GROUND_MARGIN: float = 0.15
const NO_TERRAIN: float = 0.0  ## height used when there is no Terrain3D


## Converts the scene into the grid map the simulation uses. Problems found
## (missing boat, unreachable goals...) are appended to `problems`.
func build_map(problems: Array[String] = []) -> IslandMap:
	var map := IslandMap.new()
	map.biome = biome
	map.handmade = true
	var f := FlowField.new(size, size, 1.0)
	map.field = f
	# Ground: height per cell (centre), sea and cliffs.
	var heights := PackedFloat32Array()
	heights.resize(size * size)
	var regions: Dictionary = _load_regions(problems)
	for z in size:
		for x in size:
			# Cell centre = mean of its four corner vertices (1 m spacing).
			var h: float = 0.0
			for o: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				h += _vertex_height(regions, x + o.x, z + o.y)
			heights[z * size + x] = h * 0.25 if not regions.is_empty() else NO_TERRAIN
	for z in size:
		for x in size:
			var i: int = z * size + x
			var h: float = heights[i]
			var blocked: bool = h < sea_level + GROUND_MARGIN or x == 0 or z == 0 or x == size - 1 or z == size - 1
			if not blocked:
				for o: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
					var nx: int = x + o.x
					var nz: int = z + o.y
					if nx >= 0 and nz >= 0 and nx < size and nz < size and absf(heights[nz * size + nx] - h) > max_step:
						blocked = true
						break
			if blocked:
				f.blocked[i] = 1
	map.heights = heights
	# Objects.
	for node in _children_of("Buildings") + _children_of("Rocks"):
		var rect: Rect2i = _footprint(node)
		if rect.size == Vector2i.ZERO:
			problems.append("%s has no mesh: it blocks nothing." % node.name)
			continue
		f.set_blocked_rect(rect.position.x, rect.position.y, rect.end.x - 1, rect.end.y - 1)
		map.buildings.append(rect)
	for node in _children_of("Trees"):
		var cell := Vector2i(floori(node.global_position.x), floori(node.global_position.z))
		if _inside(cell):
			f.blocked[cell.y * size + cell.x] = 1
			map.trees.append(cell)
	# Markers.
	var boat: Node3D = get_node_or_null("Markers/Boat")
	if boat == null:
		problems.append("Missing Markers/Boat: using the bottom centre.")
		map.boat = Vector3(size * 0.5, 0, size - 10.5)
	else:
		map.boat = _flat(boat.global_position)
	var start: Node3D = get_node_or_null("Markers/PlayerStart")
	map.player_start = _flat(start.global_position) if start != null else map.boat + Vector3(0, 0, -5)
	for node in _children_of("Markers"):
		if node.name.begins_with("Generator"):
			map.generators.append(_flat(node.global_position))
		elif node.name.begins_with("Cache"):
			map.caches.append(_flat(node.global_position))
	if map.generators.size() != GameData.GENERATOR_COUNT:
		problems.append("Markers: %d generators found, the Activate mission needs %d." % [map.generators.size(), GameData.GENERATOR_COUNT])
	# Reachability from the player start (the horde and the player walk the grid).
	var start_cell: Vector2i = f.world_to_cell(map.player_start)
	if f.is_blocked(start_cell.x, start_cell.y):
		problems.append("PlayerStart is on a blocked cell (sea, cliff or object).")
	else:
		f.compute_now(start_cell)
		for list: Array in [["Boat", [map.boat]], ["Generator", map.generators], ["Cache", map.caches]]:
			for p: Vector3 in list[1]:
				if f.distance_at(p) >= FlowField.UNREACHABLE:
					problems.append("%s at (%d, %d) cannot be reached from the start." % [list[0], int(p.x), int(p.z)])
	return map


## A hand-made island for this biome (stable per seed), or null.
static func pick(biome_id: StringName, seed_value: int) -> PackedScene:
	var found: PackedStringArray = []
	for file in ResourceLoader.list_directory(ISLANDS_DIR) if DirAccess.dir_exists_absolute(ISLANDS_DIR) else PackedStringArray():
		if file.ends_with(".tscn") and file.begins_with(String(biome_id) + "_"):
			found.append(ISLANDS_DIR + file)
	if found.is_empty():
		return null
	found.sort()
	return load(found[absi(seed_value) % found.size()]) as PackedScene


## Editor button: report + grid picture (<scene>_grid.png).
func check_map() -> void:
	var problems: Array[String] = []
	var map: IslandMap = build_map(problems)
	var open: int = 0
	for b in map.field.blocked:
		open += 1 if b == 0 else 0
	print("[HandmadeIsland] %d x %d m, walkable %d cells, %d buildings/rocks, %d trees, %d generators, %d caches"
		% [size, size, open, map.buildings.size(), map.trees.size(), map.generators.size(), map.caches.size()])
	for p in problems:
		print("[HandmadeIsland] PROBLEM: ", p)
	if problems.is_empty():
		print("[HandmadeIsland] OK")
	if scene_file_path != "":
		var path: String = scene_file_path.get_basename() + "_grid.png"
		grid_image(map).save_png(path)
		print("[HandmadeIsland] grid picture: ", path)


## Top-down picture of the grid: sea blue, cliffs dark, ground by height,
## buildings grey, trees green, boat yellow, generators red, caches cyan.
static func grid_image(map: IslandMap) -> Image:
	var f: FlowField = map.field
	var img := Image.create_empty(f.width, f.height, false, Image.FORMAT_RGBA8)
	for z in f.height:
		for x in f.width:
			var i: int = z * f.width + x
			var h: float = map.heights[i] if map.heights.size() == f.width * f.height else 0.0
			var c := Color(0.55, 0.75, 0.4).lerp(Color(0.95, 0.95, 0.9), clampf(h / 20.0, 0.0, 1.0))
			if f.blocked[i] != 0:
				c = Color(0.1, 0.3, 0.8) if h < 0.0 else Color(0.25, 0.2, 0.15)
			img.set_pixel(x, z, c)
	for r in map.buildings:
		img.fill_rect(r, Color(0.6, 0.6, 0.6))
	for t in map.trees:
		img.set_pixelv(t, Color(0.05, 0.45, 0.1))
	for p: Vector3 in map.generators:
		img.fill_rect(Rect2i(int(p.x) - 1, int(p.z) - 1, 3, 3), Color.RED)
	for p: Vector3 in map.caches:
		img.fill_rect(Rect2i(int(p.x) - 1, int(p.z) - 1, 3, 3), Color.CYAN)
	img.fill_rect(Rect2i(int(map.boat.x) - 2, int(map.boat.z) - 1, 5, 3), Color.YELLOW)
	return img


## Terrain3D region files (terrain3d_00_00.res, terrain3d-01_00.res...) of the
## Terrain3D node's data directory: Vector2i location -> height Image. Read
## straight from disk, so it works before the node has loaded its data.
func _load_regions(problems: Array[String]) -> Dictionary:
	var out: Dictionary = {}
	var terrain: Node = get_node_or_null("Terrain3D")
	if terrain == null:
		return out
	var dir: String = terrain.get("data_directory")
	if dir == "" or not DirAccess.dir_exists_absolute(dir):
		problems.append("Terrain3D has no data directory: the ground is flat.")
		return out
	if not is_equal_approx(float(terrain.get("vertex_spacing")), 1.0):
		problems.append("Terrain3D vertex_spacing must be 1.0.")
	var re := RegEx.create_from_string("terrain3d([_-]\\d+)([_-]\\d+)\\.res$")
	for file in DirAccess.get_files_at(dir):
		var m: RegExMatch = re.search(file.trim_suffix(".remap"))
		if m == null:
			continue
		var region: Resource = load(dir.path_join(file.trim_suffix(".remap")))
		var img: Image = region.get("height_map") if region != null else null
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		out[Vector2i(_loc(m.get_string(1)), _loc(m.get_string(2)))] = img
	return out


static func _loc(part: String) -> int:
	return int(part.substr(1)) * (-1 if part.begins_with("-") else 1)


## Height of the terrain vertex (x, z); far below the sea when no region
## covers it (unsculpted area = open sea).
func _vertex_height(regions: Dictionary, x: int, z: int) -> float:
	for loc: Vector2i in regions:
		var img: Image = regions[loc]
		var rs: int = img.get_width()
		var px: int = x - loc.x * rs
		var pz: int = z - loc.y * rs
		if px >= 0 and pz >= 0 and px < rs and pz < rs:
			return img.get_pixel(px, pz).r
	return sea_level - 10.0


func _children_of(group: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	var parent: Node = get_node_or_null(group)
	if parent != null:
		for c in parent.get_children():
			if c is Node3D:
				out.append(c)
	return out


## Cells covered by the meshes under `node` (world AABB on XZ), clamped to
## the island. A thin object still covers at least the cell it stands on.
func _footprint(node: Node3D) -> Rect2i:
	var box := AABB()
	var first: bool = true
	var meshes: Array[Node] = [node]
	meshes.append_array(node.find_children("*", "VisualInstance3D", true, false))
	for m in meshes:
		if not m is VisualInstance3D:
			continue
		var vi := m as VisualInstance3D
		var b: AABB = vi.global_transform * vi.get_aabb()
		if b.size == Vector3.ZERO:
			continue
		box = b if first else box.merge(b)
		first = false
	if first:
		return Rect2i()
	var x0: int = clampi(floori(box.position.x + 0.25), 0, size - 1)
	var z0: int = clampi(floori(box.position.z + 0.25), 0, size - 1)
	var x1: int = clampi(ceili(box.end.x - 0.25), x0 + 1, size)
	var z1: int = clampi(ceili(box.end.z - 0.25), z0 + 1, size)
	return Rect2i(x0, z0, x1 - x0, z1 - z0)


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


## Marker position on the grid: cell centre, height dropped (gameplay is 2D).
func _flat(p: Vector3) -> Vector3:
	return Vector3(floorf(p.x) + 0.5, 0, floorf(p.z) + 0.5)
