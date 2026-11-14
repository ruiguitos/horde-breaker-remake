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
	for label: String in ["Facades", "Shore", "RockSurfaces", "HorrorOnly"]:
		var group := Node3D.new()
		group.name = label
		dressing.add_child(group)
		dressing.get_node(label).owner = dressing
	dressing.get_node("HorrorOnly").visible = false
	island.get_node("Decor").add_child(dressing)
	_buildings(island, dressing, map)
	_rocks(island, dressing, map)
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
	var index: int = 0
	for match: RegExMatch in ids.search_all(text):
		text = text.replace('"' + match.get_string(1) + '"', '"BeachResource_%03d"' % index)
		index += 1
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
			continue
		house.get_node("Roof").material_override = tiles
		var centre: Vector3 = house.position
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
		var target := Vector2(99 + i * 8, 220 + (i % 2) * 3)
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
	for point: Vector2 in [Vector2(148, 218), Vector2(108, 152), Vector2(146, 139)]:
		_place_shore(["dead_tree", point, 0.4, -0.35], dressing.get_node("HorrorOnly"), island, map)

static func _place_shore(spec: Array, parent: Node3D, island: HandmadeIsland, map: IslandMap) -> void:
	var target: Vector2 = spec[1]
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
	var region: Object = data.call("get_region", Vector2i.ZERO)
	var height: Image = region.get("height_map")
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
			for patch: Vector2 in [Vector2(80, 62), Vector2(176, 196), Vector2(160, 80), Vector2(80, 200)]:
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
