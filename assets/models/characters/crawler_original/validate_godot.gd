extends SceneTree

const BASE: String = "res://assets/models/characters/crawler_original/"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("TEST FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error: Error = document.append_from_file(BASE + "crawler.glb", state)
	check(error == OK, "GLB parses in Godot")
	if error != OK:
		quit(1)
		return
	var scene: Node = document.generate_scene(state)
	root.add_child(scene)
	var parts: Dictionary = {}
	for node: Node in scene.find_children("*", "MeshInstance3D", true, false):
		parts[String(node.name)] = node
	var names: Array[String] = ["Head", "Torso", "Arm_Left", "Arm_Right", "Hip_Stump_Left", "Hip_Stump_Right", "Hand_Left", "Hand_Right"]
	check(parts.size() == 8, "exactly eight mesh nodes")
	var materials: Dictionary = {}
	var triangles: int = 0
	var low := Vector3(INF, INF, INF)
	var high := Vector3(-INF, -INF, -INF)
	var joints: Dictionary = {}
	var contact_points: Dictionary = {"Head": [], "Torso": []}
	for name: String in names:
		check(parts.has(name), "node " + name)
		if not parts.has(name):
			continue
		var mi: MeshInstance3D = parts[name]
		check(mi.transform.basis.is_equal_approx(Basis.IDENTITY), name + " rotation and scale applied")
		joints[name] = [mi.global_position.x, mi.global_position.y, mi.global_position.z]
		for s: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(s)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			triangles += indices.size() / 3
			check(normals.size() == positions.size(), name + " normals")
			check(tangents.size() == positions.size() * 4, name + " tangents")
			check(uvs.size() == positions.size(), name + " UVs")
			check(colors.size() == positions.size(), name + " vertex tints")
			for p: Vector3 in positions:
				var world: Vector3 = mi.global_transform * p
				if contact_points.has(name):
					(contact_points[name] as Array).append(world)
				low = low.min(world)
				high = high.max(world)
			var mat: StandardMaterial3D = mi.mesh.surface_get_material(s) as StandardMaterial3D
			check(mat != null, "standard PBR material")
			if mat != null:
				materials[mat.resource_name] = true
				check(mat.metallic == 0.0, "metallic zero")
				check(mat.albedo_texture == null and mat.normal_texture == null, "no textures")
				if mat.resource_name == "flesh_wound":
					check(mat.vertex_color_use_as_albedo, name + " blood tint imported")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "validation.json"))
	check(triangles == int(expected["triangle_count"]), "exact triangle count matches export audit")
	check(materials.size() == 6, "six materials")
	check((parts["Torso"] as Node3D).global_position.is_zero_approx(), "origin on ground under hips")
	check(low.y >= -0.02, "no ground penetration")
	check(absf(float(joints["Head"][1]) - 0.685) < 0.000001, "head pivot 0.685 m")
	check(absf(high.y - 0.929) < 0.000001, "mesh top 0.929 m")
	var minimum_distance_squared: float = INF
	for head_point: Vector3 in contact_points["Head"]:
		for torso_point: Vector3 in contact_points["Torso"]:
			minimum_distance_squared = minf(minimum_distance_squared, head_point.distance_squared_to(torso_point))
			if minimum_distance_squared < 1e-16:
				break
		if minimum_distance_squared < 1e-16:
			break
	var neck_distance: float = sqrt(minimum_distance_squared)
	check(neck_distance < 0.000001, "head and torso touch")
	var report: Dictionary = {
		"engine": Engine.get_version_info()["string"], "passed": failures.is_empty(),
		"glb_sha256": FileAccess.get_sha256(BASE + "crawler.glb"),
		"triangle_count": triangles, "mesh_count": parts.size(), "node_names": parts.keys(),
		"material_names": materials.keys(), "pivots_godot_m": joints,
		"bounds_min_m": [low.x, low.y, low.z], "bounds_max_m": [high.x, high.y, high.z],
		"head_pivot_height_m": joints["Head"][1], "mesh_top_height_m": high.y,
		"head_torso_minimum_vertex_distance_m": neck_distance, "neck_gap_closed": neck_distance < 0.000001,
		"normals_tangents_uvs_vertex_tints_imported": failures.is_empty(), "failures": failures,
	}
	var file := FileAccess.open(BASE + "godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	scene.free()
	print("TEST: Crawler Godot import %s; %d triangles, %d meshes" % ["PASSED" if failures.is_empty() else "FAILED", triangles, parts.size()])
	quit(0 if failures.is_empty() else 1)
