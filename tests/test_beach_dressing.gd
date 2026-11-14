extends SceneTree
## The visual pilot must preserve the beach's exact pre-pilot gameplay grid.

const BEACH: String = "res://game/world/handmade/islands/beach_01.tscn"
const BASELINE: String = "res://tests/fixtures/beach_visual_baseline.json"
var _failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + message)
	_failures += 0 if ok else 1

func _digest(value: Variant) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(value))
	return hash.finish().hex_encode()

func _run() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	var scene: PackedScene = load(BEACH) as PackedScene
	if not parsed is Dictionary or scene == null:
		_check(false, "baseline fixture and scene load")
		quit(1)
		return
	var baseline: Dictionary = parsed
	var island: HandmadeIsland = scene.instantiate()
	var issues: Array[String] = []
	var map: IslandMap = island.build_map(issues)
	_check(issues.is_empty(), "dressed beach has no navigation problems")
	_check(_digest(map.field.blocked) == baseline.blocked, "blocking cells are identical to the original beach")
	_check(_digest(map.cover) == baseline.cover, "road and bridge walking surfaces are unchanged")
	_check(_digest(map.heights) == baseline.heights, "all gameplay ground heights are unchanged")
	var markers: Node = island.get_node("Markers")
	var unchanged: bool = markers.get_child_count() == baseline.markers.size()
	for marker: Node3D in markers.get_children():
		var before: Array = baseline.markers.get(str(marker.name), [])
		unchanged = unchanged and before.size() == 3
		if before.size() == 3:
			unchanged = unchanged and marker.position.distance_to(Vector3(before[0], before[1], before[2])) < 0.00001
	_check(unchanged, "every objective, choke, arena, spawn and boat marker is unchanged")
	var dressing: Node3D = island.get_node_or_null("Decor/Dressing")
	_check(dressing != null, "the normal route island includes its persistent visual layer")
	if dressing != null:
		_check(dressing.get_node("RockSurfaces").get_child_count() >= 4, "prepared realistic outcrops dress the already-blocked coast")
		_check(dressing.get_node("Shore").get_child_count() >= 4, "the coast contains actual wreckage, netting and timber")
		_check(dressing.get_node_or_null("Facades") != null and dressing.get_node("Facades").get_child_count() >= 20,
			"village facades contain authored windows, doors and coastal details")
		var misplaced: int = 0
		var floating: int = 0
		for group: String in ["Shore", "RockSurfaces", "HorrorOnly"]:
			for prop: Node3D in dressing.get_node(group).get_children():
				var box: AABB = island._box_of(prop)
				var embed: float = prop.get_meta("ground_embed", 0.0)
				floating += 1 if absf(box.position.y - map.ground_y(prop.position) + embed) > 0.01 else 0
				if group == "RockSurfaces":
					floating += 1 if box.end.y < map.ground_y(prop.position) + 0.5 else 0
				for z in range(floori(box.position.z), ceili(box.end.z)):
					for x in range(floori(box.position.x), ceili(box.end.x)):
						if not map.field.is_blocked(x, z) or map.cover[z * map.field.width + x] != 0:
							misplaced += 1
		_check(misplaced == 0, "every solid coastal prop, outcrop and horror tree stays off playable surfaces")
		_check(floating == 0, "coastal props and trees stand on their actual ground, with no floating bases")
		var hidden: int = 0
		for rock: Node3D in island.get_node("Rocks").get_children():
			hidden += 0 if rock.visible else 1
		_check(hidden == 0, "original blocking rocks remain visible at their full gameplay silhouette")
		var boxes_before: Array[AABB] = island.object_boxes()
		dressing.free()
		var bare: IslandMap = island.build_map()
		_check(bare.field.blocked == map.field.blocked and bare.cover == map.cover and island.object_boxes() == boxes_before,
			"removing the visual layer preserves the original navigation and obstacle boxes")
	var walls: MeshInstance3D = island.get_node("Buildings/Hut_01/Body")
	var material: StandardMaterial3D = walls.material_override as StandardMaterial3D
	_check(material != null and material.albedo_texture != null and material.normal_enabled,
		"village plaster has real colour and normal textures")
	var correct: bool = true
	var expected: Dictionary = {"Body":"white_plaster_02", "Roof":"clay_roof_tiles_02"}
	for house: Node3D in island.get_node("Buildings").get_children():
		for part: MeshInstance3D in house.get_children():
			if house.name.begins_with("Hut_") and expected.has(str(part.name)):
				correct = correct and part.material_override.resource_path.ends_with(expected[str(part.name)] + ".tres")
	correct = correct and island.get_node("Buildings/Tower_01/Body").material_override.resource_path.ends_with("stone_wall_02.tres")
	for bridge: MeshInstance3D in island.get_node("Bridges").get_children():
		correct = correct and bridge.material_override.resource_path.ends_with("weathered_planks.tres")
		for rail: MeshInstance3D in bridge.get_children():
			correct = correct and rail.material_override.resource_path.ends_with("weathered_planks.tres")
	for rock: Node3D in island.get_node("Rocks").get_children():
		for part: MeshInstance3D in rock.find_children("*", "MeshInstance3D", true, false):
			correct = correct and part.material_override != null and part.material_override.resource_path.ends_with("rock_face_03.tres")
	_check(correct, "all facade, roof, bridge and rock materials survive a fresh scene load")
	var assets: Resource = island.get_node("Terrain3D").get("assets")
	_check(assets.call("get_texture_count") >= 3, "the pilot terrain has separate sand, rock and ground textures")
	_check(assets.resource_path.ends_with("dressing/beach_01_ground.tres"), "the beach owns its terrain material set")
	var formats_match: bool = true
	var first_format: int = -1
	for texture: Resource in assets.call("get_texture_list"):
		var albedo: Texture2D = texture.get("albedo_texture")
		var normal: Texture2D = texture.get("normal_texture")
		if first_format < 0:
			first_format = albedo.get_image().get_format()
		formats_match = formats_match and albedo.get_width() == 1024 and normal.get_width() == 1024
		formats_match = formats_match and albedo.get_image().get_format() == first_format and normal.get_image().get_format() == first_format
	_check(formats_match, "all terrain array textures match in 1K dimensions and GPU format")
	island.free()
	for biome: String in ["town", "jungle", "port", "volcano"]:
		var other: HandmadeIsland = load("res://game/world/handmade/islands/" + biome + "_01.tscn").instantiate()
		var other_assets: Resource = other.get_node("Terrain3D").get("assets")
		_check(other_assets.resource_path.ends_with("handmade/ground_assets.res"), "%s keeps its original shared terrain assets" % biome)
		other.free()
	_check(HandmadeIsland.island_paths(&"beach").size() == 1, "the visual scene is not accidentally included as another route island")
	GameInput.setup()
	for atmosphere: StringName in [&"normal", &"horror"]:
		var context := RunContext.new(7)
		context.biome = &"beach"
		context.atmosphere = atmosphere
		var world: Node3D = load("res://game/world/island.tscn").instantiate()
		world.set("handmade_scene", load(BEACH))
		world.set("context", context)
		root.add_child(world)
		await process_frame
		var authored: Node3D = world.get("_handmade")
		_check(authored.get_node("Decor/Dressing/HorrorOnly").visible == (atmosphere == &"horror"),
			"dead-tree dressing follows the actual %s gameplay preset" % atmosphere)
		_check(world.get("_building_boxes").size() > authored.object_boxes().size(),
			"the actual camera also avoids the decorative props in %s" % atmosphere)
		var cover: BeachVegetation = world.get("_vegetation")
		var grass: MultiMeshInstance3D = cover.get("_grass")
		_check(grass.multimesh.mesh.get_faces().size() > 6,
			"the pilot uses tapered grass blades instead of solid rectangular cards")
		world.free()
		await process_frame
	quit(1 if _failures > 0 else 0)
