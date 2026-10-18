extends SceneTree

const BASE: String = "res://assets/models/characters/arms_firstperson_original/"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("TEST FAIL: " + message)

func xyz(point: Vector3) -> Array[float]:
	return [point.x, point.y, point.z]

func closest_triangle(point: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var normal: Vector3 = ab.cross(ac).normalized()
	var projected: Vector3 = point - normal * (point - a).dot(normal)
	var ap: Vector3 = projected - a
	var denominator: float = ab.dot(ab) * ac.dot(ac) - ab.dot(ac) * ab.dot(ac)
	if absf(denominator) > 1e-20:
		var u: float = (ac.dot(ac) * ap.dot(ab) - ab.dot(ac) * ap.dot(ac)) / denominator
		var v: float = (ab.dot(ab) * ap.dot(ac) - ab.dot(ac) * ap.dot(ab)) / denominator
		if u >= 0.0 and v >= 0.0 and u + v <= 1.0:
			return projected
	var nearest: Vector3 = a
	for edge: Array in [[a, b], [b, c], [c, a]]:
		var start: Vector3 = edge[0]
		var axis: Vector3 = (edge[1] as Vector3) - start
		var candidate: Vector3 = start + axis * clampf((point - start).dot(axis) / axis.length_squared(), 0.0, 1.0)
		if candidate.distance_squared_to(point) < nearest.distance_squared_to(point):
			nearest = candidate
	return nearest

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error: Error = document.append_from_file(BASE + "arms_firstperson.glb", state)
	check(error == OK, "GLB parses")
	if error != OK:
		quit(1)
		return
	var scene: Node = document.generate_scene(state)
	root.add_child(scene)
	var skeletons: Array[Node] = scene.find_children("*", "Skeleton3D", true, false)
	check(skeletons.size() == 1, "one skeleton")
	if skeletons.size() != 1:
		scene.free()
		quit(1)
		return
	var skeleton: Skeleton3D = skeletons[0] as Skeleton3D
	check(skeleton.get_bone_count() == 8, "eight bones")
	var expected_names: Array[String] = ["Shoulder_R", "UpperArm_R", "Forearm_R", "Hand_R", "Shoulder_L", "UpperArm_L", "Forearm_L", "Hand_L"]
	var bones: Dictionary = {}
	for bone_name: String in expected_names:
		var bone_index: int = skeleton.find_bone(bone_name)
		check(bone_index >= 0, bone_name)
		if bone_index >= 0:
			bones[bone_name] = xyz(skeleton.get_bone_global_rest(bone_index).origin)
	var arms_node: Node3D = scene.find_child("Arms", true, false) as Node3D
	if scene.name == "Arms":
		arms_node = scene as Node3D
	check(arms_node != null and arms_node.transform.is_equal_approx(Transform3D.IDENTITY), "Arms identity")
	var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 12, "two forearm/palm meshes and ten finger meshes")
	var triangles: int = 0
	var skinned: int = 0
	var finger_meshes: int = 0
	var blended: int = 0
	var maximum_weight_sum_error: float = 0.0
	var materials: Dictionary = {}
	var bind_positions: Dictionary = {}
	var skin_id: int = -1
	var left_points := PackedVector3Array()
	var left_indices := PackedInt32Array()
	for item: Node in meshes:
		var mi: MeshInstance3D = item as MeshInstance3D
		var is_skinned: bool = mi.skin != null
		if is_skinned:
			skinned += 1
			if skin_id == -1:
				skin_id = mi.skin.get_instance_id()
			check(mi.skin.get_instance_id() == skin_id, "one shared skin")
			check(mi.skin.get_bind_count() == 8, "eight skin binds")
			for bind_index: int in mi.skin.get_bind_count():
				var bone_index: int = mi.skin.get_bind_bone(bind_index)
				check(bone_index >= 0, "numeric skin bone binding")
				if bone_index >= 0:
					bind_positions[String(skeleton.get_bone_name(bone_index))] = xyz(mi.skin.get_bind_pose(bind_index).affine_inverse().origin)
		else:
			finger_meshes += 1
			var parent_node: Node = mi.get_parent()
			while parent_node != null and not parent_node is BoneAttachment3D:
				parent_node = parent_node.get_parent()
			check(parent_node is BoneAttachment3D, "rigid finger bone attachment")
			if parent_node is BoneAttachment3D:
				check((parent_node as BoneAttachment3D).bone_name in ["Hand_R", "Hand_L"], "finger follows hand")
		for surface: int in mi.mesh.get_surface_count():
			var arrays: Array = mi.mesh.surface_get_arrays(surface)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
			check(normals.size() == positions.size(), "imported normals")
			check(tangents.size() == positions.size() * 4, "imported tangents")
			check(uvs.size() == positions.size(), "imported UVs")
			triangles += indices.size() / 3
			var mat: StandardMaterial3D = mi.mesh.surface_get_material(surface) as StandardMaterial3D
			check(mat != null, "PBR material")
			if mat != null:
				materials[mat.resource_name] = true
				check(mat.metallic == 0.0 and mat.albedo_texture == null and mat.normal_texture == null, "no metallic or textures")
			if is_skinned:
				var bone_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				check(weights.size() == positions.size() * 4, "four stored influence slots")
				var offset: int = left_points.size()
				for vertex: int in positions.size():
					var point := Vector3.ZERO
					var active: int = 0
					var sum_weight: float = 0.0
					for slot: int in 4:
						var weight: float = weights[vertex * 4 + slot]
						if weight <= 0.000001:
							continue
						active += 1
						sum_weight += weight
						check(is_equal_approx(weight, 1.0) or is_equal_approx(weight, 0.5), "rigid or 50/50 weights")
						var bind_index: int = bone_ids[vertex * 4 + slot]
						var bone_index: int = mi.skin.get_bind_bone(bind_index)
						point += (skeleton.get_bone_global_rest(bone_index) * mi.skin.get_bind_pose(bind_index) * positions[vertex]) * weight
					maximum_weight_sum_error = maxf(maximum_weight_sum_error, absf(sum_weight - 1.0))
					check(active in [1, 2] and absf(sum_weight - 1.0) <= 2.0 / 65535.0, "one bone or wrist blend; Godot 16-bit weight quantization")
					blended += 1 if active == 2 else 0
					if mi.name == "Arm_L":
						left_points.append(point)
				if mi.name == "Arm_L":
					for index: int in indices:
						left_indices.append(index + offset)
	check(skinned == 2 and finger_meshes == 10 and blended > 0, "skin and rigid hand attachments")
	for mat_name: String in ["sleeve_cloth", "glove", "skin"]:
		check(materials.has(mat_name), "material " + mat_name)
	check(materials.size() == 3, "three materials")
	for side: String in ["R", "L"]:
		var upper := Vector3(float(bind_positions["UpperArm_" + side][0]), float(bind_positions["UpperArm_" + side][1]), float(bind_positions["UpperArm_" + side][2]))
		var forearm := Vector3(float(bind_positions["Forearm_" + side][0]), float(bind_positions["Forearm_" + side][1]), float(bind_positions["Forearm_" + side][2]))
		var wrist := Vector3(float(bind_positions["Hand_" + side][0]), float(bind_positions["Hand_" + side][1]), float(bind_positions["Hand_" + side][2]))
		check(absf(upper.distance_to(forearm) - 0.3) < 0.00001 and absf(forearm.distance_to(wrist) - 0.3) < 0.00001, "0.30 m bind segments")
		check((forearm - upper).normalized().dot((wrist - forearm).normalized()) > 0.99999, "straight bind segments")
	var target := Vector3(0.0, 0.077, -0.26)
	var palm_error: float = INF
	for index: int in range(0, left_indices.size(), 3):
		var nearest: Vector3 = closest_triangle(target, left_points[left_indices[index]], left_points[left_indices[index + 1]], left_points[left_indices[index + 2]])
		palm_error = minf(palm_error, target.distance_to(nearest))
	check(palm_error < 0.00002, "left palm exact contact after Godot skinning")
	check(scene.find_children("*", "AnimationPlayer", true, false).is_empty(), "no animations")
	check(scene.find_children("*", "Camera3D", true, false).is_empty(), "no cameras")
	check(scene.find_children("*", "Light3D", true, false).is_empty(), "no lights")
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + "validation.json"))
	check(triangles == int(expected["triangles"]) and triangles >= 2000 and triangles <= 6000, "exact triangle budget")
	var report: Dictionary = {"passed": failures.is_empty(), "engine": Engine.get_version_info()["string"],
		"glb_sha256": FileAccess.get_sha256(BASE + "arms_firstperson.glb"), "triangles": triangles,
		"bone_names": expected_names, "armature": "Arms", "mesh_count": meshes.size(), "skinned_mesh_count": skinned,
		"rigid_bone_child_finger_meshes": finger_meshes, "material_names": materials.keys(),
		"bind_rest_positions_gun_m": bind_positions, "godot_default_skeleton_rest_positions_gun_m": bones,
		"rest_definition": "Skin inverse binds retain straight Blender bind rest. Godot Skeleton rest is the fixed bent glTF node pose.",
		"left_palm_contact_error_m": palm_error, "wrist_blended_exported_vertices": blended,
		"maximum_imported_weight_sum_error": maximum_weight_sum_error, "weight_quantization_tolerance": 2.0 / 65535.0,
		"normals_tangents_uvs_imported": failures.is_empty(), "failures": failures}
	var file := FileAccess.open(BASE + "godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	scene.free()
	print("TEST: Arms Godot import %s; %d triangles; palm error %.9f m" % ["PASSED" if failures.is_empty() else "FAILED", triangles, palm_error])
	quit(0 if failures.is_empty() else 1)
