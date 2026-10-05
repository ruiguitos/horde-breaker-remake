class_name IslandTerrain
extends RefCounted
## Builds the island ground as a Terrain3D node (addons/terrain_3d) from the
## grid map: walkable land stays exactly at height 0 (gameplay is 2D on the
## grid, so nothing may float or sink), and the coast slopes smoothly down
## under the sea. Colour comes from the Terrain3D colour map (sand on the
## coast, biome ground inland), so no texture assets are needed yet.
##
## The node is created through ClassDB so this script still parses when the
## addon is missing; build() then returns null and the caller falls back to
## the flat tile ground.

const SEA_DEPTH: float = 3.0  ## deepest sea floor (below 0)
const SLOPE: float = 0.45     ## metres of drop per cell away from land


## `land` marks cells that must be flat ground; `colors` is the per-cell
## ground colour (same size, row-major). Adds the Terrain3D node to `parent`
## (its data only exists inside the tree) and returns it, or null.
static func build(parent: Node, width: int, height: int, land: PackedByteArray, colors: PackedColorArray, sea_floor: Color) -> Node3D:
	if not ClassDB.class_exists(&"Terrain3D"):
		return null
	# One sample per grid vertex. Vertex (x, z) is the corner shared by cells
	# (x-1..x, z-1..z); it stays flat when any of them is land, so land cells
	# keep exactly their tile footprint and the slope starts at the coast.
	var dist: PackedFloat32Array = _land_distance(width, height, land)
	var height_img := Image.create_empty(width + 1, height + 1, false, Image.FORMAT_RF)
	var color_img := Image.create_empty(width + 1, height + 1, false, Image.FORMAT_RGBA8)
	for z in height + 1:
		for x in width + 1:
			var d: float = 99.0
			var col := Color.BLACK
			var n: int = 0
			for cz in range(maxi(z - 1, 0), mini(z + 1, height)):
				for cx in range(maxi(x - 1, 0), mini(x + 1, width)):
					var i: int = cz * width + cx
					d = minf(d, dist[i])
					if land[i] != 0:
						col += colors[i]
						n += 1
			if n > 0:
				height_img.set_pixel(x, z, Color(0, 0, 0))
				color_img.set_pixel(x, z, col / n)
			else:
				# Smooth shelf: drops fast near the shore, flattens at SEA_DEPTH.
				var y: float = -SEA_DEPTH * (1.0 - exp(-d * SLOPE / SEA_DEPTH * 1.6))
				height_img.set_pixel(x, z, Color(y, 0, 0))
				color_img.set_pixel(x, z, sea_floor.darkened(clampf(d / 20.0, 0.0, 0.4)))

	var terrain: Node3D = ClassDB.instantiate(&"Terrain3D")
	terrain.name = "Terrain3D"
	terrain.set("region_size", 256)
	terrain.set("vertex_spacing", 1.0)
	terrain.set("collision_mode", 0)  # gameplay uses the grid, not physics
	parent.add_child(terrain)
	# Terrain3D creates its data, material and assets during ready (a frame
	# later when `parent` is not in the tree yet), so set up once they exist.
	# Must start at >= 0: Terrain3D only imports an image that starts at a
	# negative position into that one region (the rest is dropped).
	var origin := Vector3.ZERO
	var images: Array[Image] = [height_img, null, color_img]
	if not _try_setup(terrain, images, origin):
		var tree := Engine.get_main_loop() as SceneTree
		var poll: Array[Callable] = []  # lets the lambda disconnect itself
		poll.append(func() -> void:
			if not is_instance_valid(terrain) or _try_setup(terrain, images, origin):
				tree.process_frame.disconnect(poll[0]))
		tree.process_frame.connect(poll[0])
	return terrain


## Terrain3D draws a checker pattern until it has a texture, so give it one
## light, slightly noisy texture; the colour map then tints it per cell.
## Real ground textures (sand, grass, rock) can replace it later.
static func _add_ground_texture(terrain: Node3D) -> void:
	if not ClassDB.class_exists(&"Terrain3DTextureAsset"):
		return
	var img := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.frequency = 0.08
	for y in 128:
		for x in 128:
			var v: float = 0.88 + noise.get_noise_2d(x, y) * 0.1
			img.set_pixel(x, y, Color(v, v, v, 0.5))  # alpha = height (blending)
	img.generate_mipmaps()
	var asset: Resource = ClassDB.instantiate(&"Terrain3DTextureAsset")
	asset.set("name", "Ground")
	asset.set("albedo_texture", ImageTexture.create_from_image(img))
	var assets: Resource = terrain.get("assets")
	if assets == null:
		assets = ClassDB.instantiate(&"Terrain3DAssets")
		terrain.set("assets", assets)
	assets.call("set_texture", 0, asset)


static func _try_setup(terrain: Node3D, images: Array[Image], origin: Vector3) -> bool:
	var data: Object = terrain.get("data")
	if data == null or not terrain.is_node_ready():
		return false
	var mat: Object = terrain.get("material")
	if mat != null:
		mat.set("world_background", 0)  # no endless terrain outside regions
	_add_ground_texture(terrain)
	data.call("import_images", images, origin, 0.0, 1.0)
	return true


## Distance (in cells) from every grid cell to the nearest land cell;
## 0 on land. Multi-source BFS, same idea as the coast colouring.
static func _land_distance(width: int, height: int, land: PackedByteArray) -> PackedFloat32Array:
	var dist := PackedFloat32Array()
	dist.resize(width * height)
	dist.fill(-1.0)
	var queue := PackedInt32Array()
	for i in land.size():
		if land[i] != 0:
			dist[i] = 0.0
			queue.append(i)
	var head: int = 0
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		var x: int = idx % width
		var z: int = idx / width
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + o.x
			var nz: int = z + o.y
			if nx < 0 or nz < 0 or nx >= width or nz >= height:
				continue
			var n: int = nz * width + nx
			if dist[n] < 0.0:
				dist[n] = dist[idx] + 1.0
				queue.append(n)
	for i in dist.size():
		if dist[i] < 0.0:
			dist[i] = 99.0
	return dist
