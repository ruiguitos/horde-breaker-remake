@tool
class_name HandmadeIsland
extends Node3D
## An island built by hand in the editor. The game still plays on a 2D grid
## (1 cell = 1 m), so build_map() reads this scene and converts it:
##   Terrain3D      -> below the sea level or too steep = blocked
##   Buildings/     -> every child blocks the cells under its footprint
##   Rocks/         -> same as buildings (single rocks block one cell)
##   Trees/         -> every child blocks only the cell of its trunk
##   Bridges/       -> every child is a deck mesh: the cells under it become
##                     walkable ground at the deck's top, even over water
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
## Big islands: the horde's paths are computed only this many metres around
## the player (0 = the whole island). Enemies left further behind are
## replaced by new ones near the player.
@export var horde_radius: int = 0
## Writes a top-down picture of the converted grid next to this scene and
## prints a report: what blocks, what is unreachable from the boat.
@export_tool_button("Check map", "Search") var check_button: Callable = check_map

## Islands used by the run: <biome>_<anything>.tscn or .scn (beach_01.tscn,
## beach_berlenga.scn...). One is picked per island; none = generated island.
const ISLANDS_DIR: String = "res://game/world/handmade/islands/"
const GROUND_MARGIN: float = 0.15
const NO_TERRAIN: float = 0.0  ## height used when there is no Terrain3D

var _objects := PackedByteArray()  ## cells already in map.wall_cells (build_map)


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
	heights.fill(NO_TERRAIN)
	# Plain loops over packed arrays, no function calls or small arrays per
	# cell: a 1.5 km island has over 2 million cells.
	var verts: PackedFloat32Array = _vertex_heights(problems)
	if not verts.is_empty():
		var row: int = size + 1
		for z in size:
			var r0: int = z * row
			var r1: int = r0 + row
			var out: int = z * size
			for x in size:
				# Cell centre = mean of its four corner vertices (1 m spacing).
				heights[out + x] = (verts[r0 + x] + verts[r0 + x + 1] + verts[r1 + x] + verts[r1 + x + 1]) * 0.25
	var deck := PackedByteArray()
	deck.resize(size * size)
	var deck_cells: PackedInt32Array = _lay_bridges(heights, deck)
	var low: float = sea_level + GROUND_MARGIN
	var blocked: PackedByteArray = f.blocked
	for z in size:
		for x in size:
			var i: int = z * size + x
			var h: float = heights[i]
			if h < low or x == 0 or z == 0 or x == size - 1 or z == size - 1:
				blocked[i] = 1
				continue
			# A step steeper than max_step to any neighbour is a cliff. A bridge
			# has rails: a drop beside the deck is not a cliff for the deck.
			var on_deck: bool = deck[i] != 0
			var hn: float = heights[i + 1]
			var steep: bool = absf(hn - h) > max_step and not (on_deck and deck[i + 1] == 0 and hn < h)
			if not steep:
				hn = heights[i - 1]
				steep = absf(hn - h) > max_step and not (on_deck and deck[i - 1] == 0 and hn < h)
			if not steep:
				hn = heights[i + size]
				steep = absf(hn - h) > max_step and not (on_deck and deck[i + size] == 0 and hn < h)
			if not steep:
				hn = heights[i - size]
				steep = absf(hn - h) > max_step and not (on_deck and deck[i - size] == 0 and hn < h)
			if steep:
				blocked[i] = 1
	f.blocked = blocked
	_raise_beside_decks(heights, deck, deck_cells, f)
	map.heights = heights
	# Objects. A Scatter (many copies of one rock) blocks under every copy.
	_objects = PackedByteArray()
	_objects.resize(size * size)
	for node in _children_of("Rocks"):
		if node is Scatter:
			var scatter := node as Scatter
			var box: AABB = scatter.mesh.get_aabb() if scatter.mesh != null else AABB()
			for k in scatter.count():
				var rect: Rect2i = _rect_of(_local(scatter) * scatter.instance_transform(k) * box)
				f.set_blocked_rect(rect.position.x, rect.position.y, rect.end.x - 1, rect.end.y - 1)
				map.rocks.append(rect.get_center())
	for node in _children_of("Buildings") + _children_of("Rocks"):
		if node is Scatter:
			continue
		var rect: Rect2i = _footprint(node)
		if rect.size == Vector2i.ZERO:
			problems.append("%s has no mesh: it blocks nothing." % node.name)
			continue
		_block_shape(node, rect, f, map)
		map.buildings.append(rect)
	for node in _children_of("Trees"):
		var tp: Vector3 = _local(node).origin
		var cell := Vector2i(floori(tp.x), floori(tp.z))
		if _inside(cell):
			f.blocked[cell.y * size + cell.x] = 1
			map.trees.append(cell)
	# Markers.
	var boat: Node3D = get_node_or_null("Markers/Boat")
	if boat == null:
		problems.append("Missing Markers/Boat: using the bottom centre.")
		map.boat = Vector3(size * 0.5, 0, size - 10.5)
	else:
		map.boat = _flat(_local(boat).origin)
		# The boat is moored along the marker's +Z (rotate the marker to aim it at the sea).
		var out: Vector3 = _local(boat).basis.z
		out.y = 0.0
		if out.length_squared() > 0.01:
			map.boat_dir = out.normalized()
	var start: Node3D = get_node_or_null("Markers/PlayerStart")
	map.player_start = _flat(_local(start).origin) if start != null else map.boat + Vector3(0, 0, -5)
	for node in _children_of("Markers"):
		if node.name.begins_with("Generator"):
			map.generators.append(_flat(_local(node).origin))
		elif node.name.begins_with("Cache"):
			map.caches.append(_flat(_local(node).origin))
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
	f.max_distance = horde_radius  # after the check above, which needs the whole island
	return map


## A hand-made island for this biome (stable per seed), or null.
static func pick(biome_id: StringName, seed_value: int) -> PackedScene:
	var found: PackedStringArray = []
	for file in ResourceLoader.list_directory(ISLANDS_DIR) if DirAccess.dir_exists_absolute(ISLANDS_DIR) else PackedStringArray():
		if (file.ends_with(".tscn") or file.ends_with(".scn")) and file.begins_with(String(biome_id) + "_"):
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
	if not map.handmade:
		for r in map.buildings:
			img.fill_rect(r, Color(0.6, 0.6, 0.6))
	for i in map.wall_cells:
		img.set_pixel(i % f.width, i / f.width, Color(0.6, 0.6, 0.6))
	for t in map.trees:
		img.set_pixelv(t, Color(0.05, 0.45, 0.1))
	for p: Vector3 in map.generators:
		img.fill_rect(Rect2i(int(p.x) - 1, int(p.z) - 1, 3, 3), Color.RED)
	for p: Vector3 in map.caches:
		img.fill_rect(Rect2i(int(p.x) - 1, int(p.z) - 1, 3, 3), Color.CYAN)
	img.fill_rect(Rect2i(int(map.boat.x) - 2, int(map.boat.z) - 1, 5, 3), Color.YELLOW)
	return img


## Terrain heights at every vertex of the island, (size + 1)^2 values, row
## by row; far below the sea where no region covers it (unsculpted = open
## sea). Empty without a Terrain3D. The regions are copied into one image
## (native code) instead of being looked up vertex by vertex.
func _vertex_heights(problems: Array[String]) -> PackedFloat32Array:
	var regions: Dictionary = _load_regions(problems)
	if regions.is_empty():
		return PackedFloat32Array()
	var all := Image.create_empty(size + 1, size + 1, false, Image.FORMAT_RF)
	all.fill(Color(sea_level - 10.0, 0, 0))
	for loc: Vector2i in regions:
		var img: Image = regions[loc]
		if img.get_format() != Image.FORMAT_RF:
			img.convert(Image.FORMAT_RF)
		var rs: int = img.get_width()
		all.blit_rect(img, Rect2i(0, 0, rs, rs), loc * rs)
	return all.get_data().to_float32_array()


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


## Bridges/: every cell whose centre lies under a deck gets the height of the
## deck's top surface there (decks may slope from bank to bank) and is marked
## in `deck`. A deck is a MeshInstance3D; its children (rails) are ignored.
## Returns the deck cells.
func _lay_bridges(heights: PackedFloat32Array, deck: PackedByteArray) -> PackedInt32Array:
	var cells := PackedInt32Array()
	for node in _children_of("Bridges"):
		if not node is MeshInstance3D or (node as MeshInstance3D).mesh == null:
			continue
		var box: AABB = (node as MeshInstance3D).mesh.get_aabb()
		var xf: Transform3D = _local(node)
		var inv: Transform3D = xf.affine_inverse()
		# The top face as a plane: a point on it and its normal.
		var top: Vector3 = xf * Vector3(0.0, box.end.y, 0.0)
		var up: Vector3 = xf.basis.y.normalized()
		var r: Rect2i = _footprint(node)
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				# Where the vertical line through the cell centre meets the top.
				var p := Vector3(x + 0.5, 0.0, z + 0.5)
				p.y = top.y - (up.x * (p.x - top.x) + up.z * (p.z - top.z)) / up.y
				var c: Vector3 = inv * p
				if c.x < box.position.x or c.x > box.end.x or c.z < box.position.z or c.z > box.end.z:
					continue
				var i: int = z * size + x
				heights[i] = p.y
				if deck[i] == 0:
					cells.append(i)
				deck[i] = 1
	return cells


## Blocked cells beside a deck (the water past the rails) take the deck's
## height: ground_y() blends neighbouring cells, so a unit walking near the
## rail would otherwise sink towards the riverbed. They stay blocked.
func _raise_beside_decks(heights: PackedFloat32Array, deck: PackedByteArray, deck_cells: PackedInt32Array, f: FlowField) -> void:
	var raised := {}  # cell -> height: decided from the original heights only
	for i in deck_cells:
		for n: int in [i + 1, i - 1, i + size, i - size]:
			var x: int = n % size
			var z: int = n / size
			if n < 0 or x == 0 or z == 0 or x >= size - 1 or z >= size - 1:
				continue
			if deck[n] != 0 or f.blocked[n] == 0:
				continue
			if heights[i] > maxf(heights[n], raised.get(n, -INF)):
				raised[n] = heights[i]
	for n: int in raised:
		heights[n] = raised[n]


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
	var box: AABB = _box_of(node)
	return Rect2i() if box.size == Vector3.ZERO else _rect_of(box)


## The box around the meshes under `node`, in island space (empty if none).
func _box_of(node: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	var meshes: Array[Node] = [node]
	meshes.append_array(node.find_children("*", "VisualInstance3D", true, false))
	for m in meshes:
		if not m is VisualInstance3D:
			continue
		var vi := m as VisualInstance3D
		var b: AABB = _local(vi) * vi.get_aabb()
		if b.size == Vector3.ZERO:
			continue
		box = b if first else box.merge(b)
		first = false
	return box


## Boxes (island space, real heights) of the buildings and single rocks: the
## island scene shortens the third-person camera when it would pass through
## one. A 27 m block needs its 27 m, not a fixed height.
func object_boxes() -> Array[AABB]:
	var out: Array[AABB] = []
	for node in _children_of("Buildings") + _children_of("Rocks"):
		if node is Scatter:
			continue
		var box: AABB = _box_of(node)
		if box.size != Vector3.ZERO:
			out.append(box)
	return out


## Blocks the cells whose centre lies under the object's real shape seen
## from above (its mesh triangles projected on the ground), not the whole
## box around it: a rotated or L-shaped building leaves the alleys and yards
## beside it open. Objects without a mesh shape (or too thin to cover a cell
## centre) block their box, as before. Each mesh is judged on its own (a
## thin railing beside a thick wall still blocks). Blocked cells go to
## map.wall_cells once each (the minimap draws them), also over cliffs.
func _block_shape(node: Node3D, rect: Rect2i, f: FlowField, map: IslandMap) -> void:
	var meshes: Array[Node] = [node]
	meshes.append_array(node.find_children("*", "MeshInstance3D", true, false))
	var any_mesh: bool = false
	for m in meshes:
		if not m is MeshInstance3D or (m as MeshInstance3D).mesh == null:
			continue
		any_mesh = true
		var mi := m as MeshInstance3D
		var xf: Transform3D = _local(mi)
		var faces: PackedVector3Array = mi.mesh.get_faces()
		var covered: int = 0
		for k in range(0, faces.size() - 2, 3):
			var a3: Vector3 = xf * faces[k]
			var b3: Vector3 = xf * faces[k + 1]
			var c3: Vector3 = xf * faces[k + 2]
			var a := Vector2(a3.x, a3.z)
			var b := Vector2(b3.x, b3.z)
			var c := Vector2(c3.x, c3.z)
			if absf((b - a).cross(c - a)) < 1e-6:
				continue  # edge-on from above (a wall): its roof or floor gives the shape
			var lo: Vector2 = a.min(b).min(c)
			var hi: Vector2 = a.max(b).max(c)
			for z in range(maxi(floori(lo.y), 0), mini(ceili(hi.y), size)):
				for x in range(maxi(floori(lo.x), 0), mini(ceili(hi.x), size)):
					if Geometry2D.point_is_inside_triangle(Vector2(x + 0.5, z + 0.5), a, b, c):
						covered += 1
						_mark_object(z * size + x, f, map)
		if covered == 0:  # too thin to cover a cell centre: its box
			_block_rect(_rect_of(xf * mi.mesh.get_aabb()), f, map)
	if not any_mesh:
		_block_rect(rect, f, map)


func _block_rect(r: Rect2i, f: FlowField, map: IslandMap) -> void:
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_mark_object(z * size + x, f, map)


func _mark_object(i: int, f: FlowField, map: IslandMap) -> void:
	f.blocked[i] = 1
	if _objects[i] == 0:
		_objects[i] = 1
		map.wall_cells.append(i)


## Cells under a box (island space, seen from above), clamped to the island.
## Edges that cover less than a quarter of a cell leave that cell free.
func _rect_of(box: AABB) -> Rect2i:
	var x0: int = clampi(floori(box.position.x + 0.25), 0, size - 1)
	var z0: int = clampi(floori(box.position.z + 0.25), 0, size - 1)
	var x1: int = clampi(ceili(box.end.x - 0.25), x0 + 1, size)
	var z1: int = clampi(ceili(box.end.z - 0.25), z0 + 1, size)
	return Rect2i(x0, z0, x1 - x0, z1 - z0)


## Transform of `n` relative to this island (works before the scene is in
## the tree, where global transforms are not available).
func _local(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != null and n != self:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size and c.y < size


## Marker position on the grid: cell centre, height dropped (gameplay is 2D).
func _flat(p: Vector3) -> Vector3:
	return Vector3(floorf(p.x) + 0.5, 0, floorf(p.z) + 0.5)
