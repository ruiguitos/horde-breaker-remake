extends RefCounted
## Authoring pass for beach_01. Never changes gameplay geometry or uses the layout RNG.
## The baked result is ordinary scene content, not a runtime generator.
## This authoring pass owns/replaces Dressing; edit this file to retain hand changes.

const DIR: String = "res://game/world/handmade/dressing/"
const SCENE: String = DIR + "beach_01_dressing.tscn"
const KIT: Script = preload("res://game/world/scenery_kit.gd")
const BOULDER: String = "res://assets/models/polyhaven/boulder_01/boulder_01_game.glb"
static var _problems: Array[String] = []
static var _mesh_cache: Dictionary = {}

static func apply(island: HandmadeIsland) -> Array[String]:
	_problems.clear()
	_mesh_cache.clear()
	for id: String in KIT.BEACH + KIT.COASTAL:
		if not ResourceLoader.exists(KIT.path(id)):
			_problems.append("Missing scenery piece: " + id)
	if not ResourceLoader.exists(BOULDER):
		_problems.append("Missing prepared Boulder 01")
	for house: Node3D in island.get_node("Buildings").get_children():
		if not house.basis.is_equal_approx(Basis.IDENTITY):
			_problems.append("Re-author the facade placement for rotated building: " + str(house.name))
	if not _problems.is_empty():
		return _problems.duplicate()
	DirAccess.make_dir_recursive_absolute(DIR)
	var map_problems: Array[String] = []
	var map: IslandMap = island.build_map(map_problems)
	if not map_problems.is_empty():
		return map_problems
	var old: Node = island.get_node_or_null("Decor/Dressing")
	if old != null:
		old.free()
	var dressing := Node3D.new()
	dressing.name = "Dressing"
	for label: String in ["Facades", "Shore", "RockSurfaces", "HorrorOnly", "Plants"]:
		var group := Node3D.new()
		group.name = label
		dressing.add_child(group)
		dressing.get_node(label).owner = dressing
	dressing.get_node("HorrorOnly").visible = false
	island.get_node("Decor").add_child(dressing)
	_buildings(island, dressing, map)
	_rocks(island, dressing, map)
	_cliff_rocks(island, dressing, map)
	_plants(island, dressing, map)
	_shore(island, dressing, map)
	_ground(island, map)
	if not _problems.is_empty():
		return _problems.duplicate()
	var packed := PackedScene.new()
	if packed.pack(dressing) != OK or not _save(packed, SCENE):
		_problems.append("Could not pack the beach dressing")
		return _problems.duplicate()
	_canonical_scene(SCENE)
	if not _problems.is_empty():
		return _problems.duplicate()
	dressing.free()
	var saved: PackedScene = load(SCENE) as PackedScene
	if saved == null:
		_problems.append("The saved dressing scene could not reload")
		return _problems.duplicate()
	var instance: Node3D = saved.instantiate()
	island.get_node("Decor").add_child(instance)
	instance.owner = island
	island.set_meta("beach_visual_pilot", true)
	return _problems.duplicate()

static func _save(resource: Resource, path: String) -> bool:
	var result: Error = ResourceSaver.save(resource, path)
	if result != OK:
		_problems.append("Could not save %s: %s" % [path, error_string(result)])
	return result == OK

static func _canonical_scene(path: String) -> void:
	var text: String = FileAccess.get_file_as_string(path)
	var ids := RegEx.create_from_string('\\[(?:sub|ext)_resource[^\\n]* id="([^"]+)"')
	# Two passes: an id Godot kept from an earlier save can already read "BeachResource_006", and a
	# one-pass renumbering then merged two resources into one id (the facades lost their textures).
	var found: Array[String] = []
	for match: RegExMatch in ids.search_all(text):
		found.append(match.get_string(1))
	for index in found.size():
		text = text.replace('"' + found[index] + '"', '"@@canonical_%d@@"' % index)
	for index in found.size():
		text = text.replace('"@@canonical_%d@@"' % index, '"BeachResource_%03d"' % index)
	text = RegEx.create_from_string(" unique_id=[0-9]+").sub(text, "", true)
	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		_problems.append("Could not canonicalize " + path)
		return
	output.store_string(text)
	output.close()

static func _surface(id: String, scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var source: String = "res://assets/textures/polyhaven/" + id
	material.albedo_texture = load(source + "_diffuse.res")
	material.normal_enabled = true
	material.normal_texture = load(source + "_nor_gl.res")
	material.roughness_texture = load(source + "_rough.res")
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.take_over_path(DIR + id + ".tres")
	_save(material, material.resource_path)
	return material

static func _packed_surface(id: String, scale: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	var source: String = "res://assets/textures/polyhaven/" + id
	material.albedo_texture = load(source + "_albedo_height.res")
	material.normal_enabled = true
	material.normal_texture = load(source + "_normal_rough.res")
	material.roughness_texture = material.normal_texture
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_ALPHA
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.take_over_path(DIR + id + ".tres")
	_save(material, material.resource_path)
	return material

static func _buildings(island: HandmadeIsland, dressing: Node3D, map: IslandMap) -> void:
	var plaster: Material = _surface("white_plaster_02", 0.45)
	var tiles: Material = _surface("clay_roof_tiles_02", 0.5)
	var timber: Material = _surface("weathered_planks", 0.5)
	var stone: Material = _surface("stone_wall_02", 0.35)
	var path: Material = _packed_surface("rocky_trail", 0.22)
	for house: Node3D in island.get_node("Buildings").get_children():
		var body: MeshInstance3D = house.get_node("Body")
		body.material_override = plaster
		if not house.name.begins_with("Hut_"):
			body.material_override = stone
			_house_volume(house, dressing.get_node("Facades"), map, stone, true)
			continue
		house.get_node("Roof").material_override = tiles
		var centre: Vector3 = house.position
		_house_volume(house, dressing.get_node("Facades"), map, stone)
		var face := Vector3(centre.x, 0, centre.z + 3.02)
		# Facade pivots are centred on the wall contact face, not on the floor.
		var door_y: float = map.ground_y(face) + 1.135
		var door: Node3D = _piece("door_frame", dressing.get_node("Facades"), centre + Vector3(0, 0, 3.02), 0)
		door.position.y = door_y
		for x: float in [-2.0, 2.0]:
			_piece("window_shutters", dressing.get_node("Facades"), centre + Vector3(x, 1.65, 3.025), 0, 0.75)
		_piece("wall_lantern", dressing.get_node("Facades"), centre + Vector3(0.95, 2.4, 3.025), 0, 0.8)
		_piece("chimney", dressing.get_node("Facades"), centre + Vector3(2.3, 4.3, -0.8), PI * 0.5)
		if house.name in [&"Hut_01", &"Hut_04"]:
			_piece("canvas_awning", dressing.get_node("Facades"), centre + Vector3(0, 2.55, 3.025), 0)
		if house.name == &"Hut_04":
			_piece("tavern_sign", dressing.get_node("Facades"), centre + Vector3(-3.52, 2.35, 1), -PI * 0.5)
	# The tower's balcony is ornamental; no new walkable upper floor is implied.
	var tower: Node3D = island.get_node("Buildings/Tower_01")
	_piece("small_balcony", dressing.get_node("Facades"), tower.position + Vector3(0, 5.5, 3.52), 0)
	for y: float in [2.0, 6.2]:
		_piece("window_shutters", dressing.get_node("Facades"), tower.position + Vector3(0, y, 3.525), 0, 0.8)
	for bridge: MeshInstance3D in island.get_node("Bridges").get_children():
		bridge.material_override = timber
		for rail: MeshInstance3D in bridge.get_children():
			rail.material_override = timber
	island.get_node("Decor/Roads/Surface").material_override = path

static func _piece(id: String, parent: Node3D, at: Vector3, yaw: float, size: float = 1.0) -> Node3D:
	var source: Node3D = KIT.build(id)
	var result := Node3D.new()
	result.name = id.to_pascal_case() + "_%02d" % parent.get_child_count()
	parent.add_child(result)
	result.owner = parent.owner
	_clone_geometry(source, result, Transform3D.IDENTITY, id)
	source.free()
	result.position = at
	result.rotation.y = yaw
	result.scale = Vector3.ONE * size
	return result

static func _clone_geometry(source: Node3D, target: Node3D, parent_transform: Transform3D, id: String) -> void:
	var transform: Transform3D = parent_transform * source.transform
	if source is MeshInstance3D:
		var mesh_instance := MeshInstance3D.new()
		var key: String = id + "/" + str(source.name)
		if not _mesh_cache.has(key):
			var copy: ArrayMesh = source.mesh.duplicate()
			for i in copy.get_surface_count():
				copy.surface_set_material(i, KIT.material())
			_mesh_cache[key] = copy
		var mesh: ArrayMesh = _mesh_cache[key]
		mesh_instance.name = "Geometry_%02d" % target.get_child_count()
		mesh_instance.mesh = mesh
		mesh_instance.transform = transform
		target.add_child(mesh_instance)
		mesh_instance.owner = target.owner
	for child: Node in source.get_children():
		if child is Node3D:
			_clone_geometry(child, target, transform, id)

static func _rocks(island: HandmadeIsland, dressing: Node3D, map: IslandMap) -> void:
	# Existing rocks keep their exact visible silhouette and camera proxy.
	var material: Material = _surface("rock_face_03", 0.45)
	for original: Node3D in island.get_node("Rocks").get_children():
		original.visible = true
		for part: MeshInstance3D in original.find_children("*", "MeshInstance3D", true, false):
			part.material_override = material
	# New scanned outcrops are on already-blocked shoreline, never tiny stand-ins
	# for large invisible obstacles.
	var source: Node3D = (load(BOULDER) as PackedScene).instantiate()
	var mesh: Mesh = source.find_children("*", "MeshInstance3D", true, false)[0].mesh
	for i in 8:
		var rock := MeshInstance3D.new()
		rock.name = "CoastalOutcrop_%02d" % i
		rock.mesh = mesh
		rock.rotation.y = i * 1.17
		rock.scale = Vector3.ONE * (1.3 + (i % 3) * 0.35)
		rock.set_meta("ground_embed", mesh.get_aabb().size.y * rock.scale.y * 0.2)
		dressing.get_node("RockSurfaces").add_child(rock)
		rock.owner = dressing
		var target := Vector2(99 + i * 8, 220 + (i % 2) * 3) + _landing_shift(island)
		if not _shore_position(rock, target, -1.1, island, map):
			rock.free()
	source.free()

static func _blocked_box(box: AABB, map: IslandMap) -> bool:
	for z in range(floori(box.position.z), ceili(box.end.z)):
		for x in range(floori(box.position.x), ceili(box.end.x)):
			if x < 0 or z < 0 or x >= map.field.width or z >= map.field.height:
				return false
			if not map.field.is_blocked(x, z) or map.cover[z * map.field.width + x] != 0:
				return false
	return true

static func _shore(island: HandmadeIsland, dressing: Node3D, map: IslandMap) -> void:
	var shore: Node3D = dressing.get_node("Shore")
	for spec: Array in [
		["stranded_hull", Vector2(110, 216), -0.35, -0.45],
		["driftwood", Vector2(151, 214), 0.8, -0.32],
		["driftwood", Vector2(104, 216), -0.6, -0.32],
		["fallen_fishing_net", Vector2(113, 216), 0.3, -0.2],
		["crooked_dock_post", Vector2(117, 221), 0.15, -0.4],
		["crooked_dock_post", Vector2(139, 222), -0.15, -0.4],
	]:
		_place_shore(spec, shore, island, map)
	for point: Vector2 in [Vector2(148, 218) + _landing_shift(island), Vector2(108, 152) * _scale(island), Vector2(146, 139) * _scale(island)]:
		_place_shore(["dead_tree", point, 0.4, -0.35], dressing.get_node("HorrorOnly"), island, map)

static func _place_shore(spec: Array, parent: Node3D, island: HandmadeIsland, map: IslandMap) -> void:
	var target: Vector2 = spec[1]
	target += _landing_shift(island)  # authored round the 256 m beach's landing
	var node: Node3D = _piece(spec[0], parent, Vector3(target.x, 0, target.y), spec[2])
	if not _shore_position(node, target, spec[3], island, map):
		node.free()

static func _shore_position(node: Node3D, target: Vector2, min_ground: float, island: HandmadeIsland, map: IslandMap) -> bool:
	for radius in 16:
		for direction in 12:
			var p: Vector2 = target + Vector2.from_angle(direction * TAU / 12.0) * radius
			var position := Vector3(p.x, 0, p.y)
			var ground: float = map.ground_y(position)
			if ground < min_ground or ground > 0.2:
				continue
			var clear: bool = true
			for marker: Node3D in island.get_node("Markers").get_children():
				if Vector2(marker.position.x, marker.position.z).distance_to(p) < 7.0:
					clear = false
			if not clear:
				continue
			node.position = position
			node.position.y = ground - float(node.get_meta("ground_embed", 0.0))
			if _blocked_box(island._box_of(node), map):
				return true
	return false

static func _ground(island: HandmadeIsland, map: IslandMap) -> void:
	var terrain: Node = island.get_node("Terrain3D")
	var assets: Resource = ClassDB.instantiate(&"Terrain3DAssets")
	var sources: Array[String] = ["coast_sand_01", "rock_face_03", "aerial_grass_rock", "rocky_trail"]
	for i in sources.size():
		var asset: Resource = ClassDB.instantiate(&"Terrain3DTextureAsset")
		asset.set("name", ["Shore", "Cliffs", "Scrub", "Track"][i])
		asset.set("id", i)
		var texture_dir: String = DIR if i == 0 else "res://assets/textures/polyhaven/"
		asset.set("albedo_texture", load(texture_dir + sources[i] + "_albedo_height.res"))
		asset.set("normal_texture", load(texture_dir + sources[i] + "_normal_rough.res"))
		asset.set("uv_scale", [0.15, 0.2, 0.12, 0.3][i])
		asset.set("detiling_rotation", 0.3)
		assets.call("set_texture", i, asset)
	assets.take_over_path(DIR + "beach_01_ground.tres")
	_save(assets, assets.resource_path)
	terrain.set("assets", assets)
	var data: Object = terrain.get("data")
	# Every region as one picture (the open-island beach is 512 m: four regions of 256 m).
	var height: Image = data.call("layered_to_image", 0)  # Terrain3DRegion.TYPE_HEIGHT
	if height.get_width() != map.field.width or height.get_height() != map.field.height:
		_problems.append("Beach terrain and gameplay map dimensions differ")
		return
	var control := Image.create_empty(height.get_width(), height.get_height(), false, Image.FORMAT_RF)
	var colors := Image.create_empty(height.get_width(), height.get_height(), false, Image.FORMAT_RGBA8)
	var noise := FastNoiseLite.new()
	noise.seed = 20261114
	noise.frequency = 0.075
	for z in height.get_height():
		for x in height.get_width():
			var h: float = height.get_pixel(x, z).r
			var index: int = z * map.field.width + x
			var cell_height: float = map.heights[index]
			var slope: float = 0.0
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx: int = clampi(x + offset.x, 0, map.field.width - 1)
				var nz: int = clampi(z + offset.y, 0, map.field.height - 1)
				slope = maxf(slope, absf(cell_height - map.heights[nz * map.field.width + nx]))
			var n: float = noise.get_noise_2d(x, z)
			var forest: float = 0.0
			for patch: Vector2 in [Vector2(80, 62) * _scale(island), Vector2(176, 196) * _scale(island), Vector2(160, 80) * _scale(island), Vector2(80, 200) * _scale(island)]:
				forest = maxf(forest, 1.0 - Vector2(x, z).distance_to(patch) / 30.0)
			var overlay: int = 2
			var base: int = 0
			var blend: float = clampf(forest + n * 0.25, 0, 1) if h > 0.6 else 0.0
			if slope > island.max_step:
				base = 1
				blend = 0.0
			elif map.cover[z * map.field.width + x] == IslandMap.COVER_ROAD:
				base = 3
				blend = 0.0
			var encoded: int = Terrain3DUtil.enc_base(base) | Terrain3DUtil.enc_overlay(overlay) | Terrain3DUtil.enc_blend(roundi(blend * 255))
			control.set_pixel(x, z, Color(Terrain3DUtil.as_float(encoded), 0, 0))
			var wet: float = lerpf(0.72, 1.0, smoothstep(-0.3, 0.65, h))
			var shade: float = wet * (0.98 + n * 0.035)
			colors.set_pixel(x, z, Color(shade, shade, shade, 0.5))
	data.call("import_images", [height, control, colors], Vector3.ZERO, 0.0, 1.0)
	data.call("save_directory", terrain.get("data_directory"))


## A hut's box made less plain without changing its footprint: a stone plinth along the base, a
## stone quoin up each corner and a step at the door. They stand at most 6 cm proud of the walls,
## so the grid (built from Buildings, which these are not part of) and the paths do not change.
static func _house_volume(house: Node3D, parent: Node3D, map: IslandMap, stone: Material, tower: bool = false) -> void:
	var body := house.get_node("Body") as MeshInstance3D
	var box := body.mesh as BoxMesh
	if box == null:
		return
	var half := Vector3(box.size.x, 0, box.size.z) * 0.5
	var base: float = map.ground_y(house.position)
	var parts: Array = []  # [size, centre]
	parts.append([Vector3(box.size.x + 0.12, 0.55, box.size.z + 0.12), Vector3(0, 0.27, 0)])
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			parts.append([Vector3(0.42, box.size.y - 0.3, 0.42), Vector3(sx * (half.x - 0.15), (box.size.y - 0.3) * 0.5, sz * (half.z - 0.15))])
	parts.append([Vector3(1.6, 0.18, 0.5), Vector3(0, 0.09, half.z + 0.25)])
	if tower:
		# The tower: two string courses and a corbelled parapet under the spire, so the box reads
		# as a built tower. The spire stands on the parapet's ring.
		var top: float = body.position.y + box.size.y * 0.5 - (base - house.position.y)
		for y: float in [top * 0.42, top * 0.74]:
			parts.append([Vector3(box.size.x + 0.16, 0.22, box.size.z + 0.16), Vector3(0, y, 0)])
		parts.append([Vector3(box.size.x + 0.5, 0.35, box.size.z + 0.5), Vector3(0, top - 0.1, 0)])
		parts.append([Vector3(box.size.x + 0.7, 0.7, box.size.z + 0.7), Vector3(0, top + 0.42, 0)])
	for k in parts.size():
		var size: Vector3 = parts[k][0]
		var mesh := BoxMesh.new()
		mesh.size = size
		var piece := MeshInstance3D.new()
		piece.name = "%s_Stone_%02d" % [house.name, k]
		piece.mesh = mesh
		piece.material_override = stone
		parent.add_child(piece)
		piece.owner = parent.owner
		piece.position = Vector3(house.position.x, base, house.position.z) + parts[k][1]


## Taller plants of the nature kit where vegetation gathers: against walls, cliffs and rocks, on
## open ground. Low (bushes, ferns, big-leaf plants under 1.3 m), so they never read as cover; they
## are decoration and the horde walks through them, like the grass.
const PLANTS: Array = [["Bush_Common", 1.0], ["Bush_Common", 0.7], ["Bush_Common_Flowers", 0.9], ["Fern_1", 0.7], ["Plant_1_Big", 1.1]]  # no Plant_7: flat purple petals, out of place here
const PLANT_COUNT: int = 140
const PLANT_CLEAR_OF_MARKERS: float = 5.0

static func _plants(island: HandmadeIsland, dressing: Node3D, map: IslandMap) -> void:
	var f: FlowField = map.field
	var spots: Array[Vector2i] = []
	for z in range(2, f.height - 2):
		for x in range(2, f.width - 2):
			if f.is_blocked(x, z) or map.heights.size() == f.width * f.height and map.heights[z * f.width + x] < 0.2:
				continue
			var edge: bool = false
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n := Vector2i(x, z) + o
				if f.is_blocked(n.x, n.y) and map.heights[n.y * f.width + n.x] >= 0.0:
					edge = true  # a wall, a cliff or a rock; not the sea
			if edge:
				spots.append(Vector2i(x, z))
	# Half the plants go round the houses and the tower: the long river and cliff edges would
	# otherwise take nearly all of them, and the village is where the camera looks.
	var village: Array[Vector2i] = []
	for building: Node3D in island.get_node("Buildings").get_children():
		for cell: Vector2i in spots:
			if Vector2(cell.x + 0.5 - building.position.x, cell.y + 0.5 - building.position.z).length() < 7.0:
				village.append(cell)
	var markers: Array[Vector3] = [map.boat, map.player_start]
	markers.append_array(map.generators)
	markers.append_array(map.caches)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x504c414e
	var picked: Array = []
	for model: Array in PLANTS:
		picked.append([])
	var tries: int = 0
	while tries < PLANT_COUNT * 6 and spots.size() > 0 and (picked.map(func(a: Array) -> int: return a.size()).reduce(func(a: int, b: int) -> int: return a + b, 0)) < PLANT_COUNT:
		tries += 1
		var pool: Array[Vector2i] = village if tries % 2 == 0 and not village.is_empty() else spots
		var cell: Vector2i = pool[rng.randi_range(0, pool.size() - 1)]
		var at := Vector3(cell.x + rng.randf_range(0.2, 0.8), 0, cell.y + rng.randf_range(0.2, 0.8))
		var near: bool = false
		for m: Vector3 in markers:
			near = near or Vector2(m.x - at.x, m.z - at.z).length() < PLANT_CLEAR_OF_MARKERS
		if near:
			continue
		at.y = map.ground_y(at) - 0.05
		picked[rng.randi_range(0, PLANTS.size() - 1)].append([at, rng.randf() * TAU, rng.randf_range(0.8, 1.2)])
	# One node per plant, not a MultiMesh: this pass runs headless, where a MultiMesh keeps no
	# instance transforms, and the saved plants all stood at the origin.
	for k in PLANTS.size():
		var mesh: Mesh = NatureKit.mesh(PLANTS[k][0])
		if mesh == null:
			continue
		var base: float = NatureKit.scale_for(mesh, PLANTS[k][1])
		for i in (picked[k] as Array).size():
			var spec: Array = picked[k][i]
			var node := MeshInstance3D.new()
			node.name = "%s_%02d" % [PLANTS[k][0], i]
			node.mesh = mesh
			node.position = spec[0]
			node.rotation.y = spec[1]
			node.scale = Vector3.ONE * base * spec[2]
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			dressing.get_node("Plants").add_child(node)
			node.owner = dressing


## Scanned rock along the cliffs, where the terrain's texture stretches over a steep face: a
## boulder half sunk into each stretch, every CLIFF_ROCK_SPACING metres. Only on blocked, dry
## cells (never the sea, a building or a path), so the grid does not change.
const CLIFF_ROCK_SPACING: float = 7.0
const CLIFF_ROCK_MAX: int = 48
const CLIFF_DROP: float = 0.8  ## metres of height between a cliff cell and the walkable cell beside it

static func _cliff_rocks(island: HandmadeIsland, dressing: Node3D, map: IslandMap) -> void:
	var f: FlowField = map.field
	if map.heights.size() != f.width * f.height:
		return
	var buildings: Array[AABB] = []
	for building: Node3D in island.get_node("Buildings").get_children():
		buildings.append(island._box_of(building).grow(1.5))
	var source: Node3D = (load(BOULDER) as PackedScene).instantiate()
	var mesh: Mesh = source.find_children("*", "MeshInstance3D", true, false)[0].mesh
	source.free()
	var placed: Array[Vector2] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x434c4946
	for z in range(1, f.height - 1):
		for x in range(1, f.width - 1):
			if placed.size() >= CLIFF_ROCK_MAX or not f.is_blocked(x, z):
				continue
			var h: float = map.heights[z * f.width + x]
			if h < 0.3:
				continue
			var drop: float = 0.0
			var away := Vector2.ZERO  # from the walkable side into the cliff
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				if not f.is_blocked(x + o.x, z + o.y):
					drop = maxf(drop, absf(h - map.heights[(z + o.y) * f.width + x + o.x]))
					away -= Vector2(o)
			if drop < CLIFF_DROP:
				continue
			var at := Vector2(x + 0.5, z + 0.5) + away.normalized() * 0.9
			var spaced: bool = true
			for p: Vector2 in placed:
				spaced = spaced and p.distance_to(at) >= CLIFF_ROCK_SPACING
			var inside: bool = false
			for box: AABB in buildings:
				inside = inside or (at.x > box.position.x and at.x < box.end.x and at.y > box.position.z and at.y < box.end.z)
			if not spaced or inside:
				continue
			var rock := MeshInstance3D.new()
			rock.name = "CliffRock_%02d" % placed.size()
			rock.mesh = mesh
			rock.rotation.y = rng.randf() * TAU
			dressing.get_node("RockSurfaces").add_child(rock)
			rock.owner = dressing
			# The largest size whose footprint stays on blocked cells (the dressing's rule for solids),
			# its base sunk a fifth into the ground, set one cell into the cliff from the walkable side.
			var fits: bool = false
			for size: float in [1.6, 1.3, 1.0, 0.8, 0.65]:
				rock.scale = Vector3.ONE * minf(size, maxf(0.65, drop * 0.6))
				var embed: float = mesh.get_aabb().size.y * rock.scale.y * 0.2
				rock.set_meta("ground_embed", embed)
				rock.position = Vector3(at.x, 0, at.y)
				rock.position.y = map.ground_y(rock.position) - embed
				var box: AABB = island._box_of(rock)
				if _blocked_box(box, map) and box.end.y >= map.ground_y(rock.position) + 0.5:
					fits = true
					break
			if not fits:
				rock.free()
				continue
			placed.append(at)


## The open-island pilot: how many times wider this beach is than the 256 m one it was authored on.
static func _scale(island: HandmadeIsland) -> float:
	return island.size / 256.0


## How far the landing (the Boat marker) moved from the 256 m beach's: the shore pieces were
## authored round it, and keep their places beside it.
static func _landing_shift(island: HandmadeIsland) -> Vector2:
	var boat: Node3D = island.get_node_or_null("Markers/Boat")
	if boat == null:
		return Vector2.ZERO
	return Vector2(boat.position.x, boat.position.z) - Vector2(128.0, 216.5)
