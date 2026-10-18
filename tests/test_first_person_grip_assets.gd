extends SceneTree
## Independent import/skin audit of the five actual GLBs, not only joint markers.
const BASE: String = "res://assets/models/characters/weapon_grips_original/"
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		print("TEST FAIL: " + message)

func xyz(p: Vector3) -> Array[float]:
	return [p.x, p.y, p.z]

func closest_triangle(p: Vector3, a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	var ab: Vector3 = b - a
	var ac: Vector3 = c - a
	var normal: Vector3 = ab.cross(ac).normalized()
	var q: Vector3 = p - normal * (p - a).dot(normal)
	var ap: Vector3 = q - a
	var divisor: float = ab.dot(ab) * ac.dot(ac) - ab.dot(ac) * ab.dot(ac)
	if absf(divisor) > 1e-20:
		var u: float = (ac.dot(ac) * ap.dot(ab) - ab.dot(ac) * ap.dot(ac)) / divisor
		var v: float = (ab.dot(ab) * ap.dot(ac) - ab.dot(ac) * ap.dot(ab)) / divisor
		if u >= 0.0 and v >= 0.0 and u + v <= 1.0:
			return q
	var nearest: Vector3 = a
	for edge: Array in [[a, b], [b, c], [c, a]]:
		var start: Vector3 = edge[0]
		var axis: Vector3 = (edge[1] as Vector3) - start
		var candidate: Vector3 = start + axis * clampf((p - start).dot(axis) / axis.length_squared(), 0.0, 1.0)
		if candidate.distance_squared_to(p) < nearest.distance_squared_to(p):
			nearest = candidate
	return nearest

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var reports: Dictionary = {}
	for id: StringName in WeaponModel.IDS:
		var path: String = BASE + String(id) + "/arms_firstperson.glb"
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + String(id) + "/validation.json"))
		var fitted: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + String(id) + "/grip_validation.json"))
		var doc := GLTFDocument.new()
		var state := GLTFState.new()
		check(doc.append_from_file(path, state) == OK, "%s GLB parses" % id)
		var scene: Node = doc.generate_scene(state)
		root.add_child(scene)
		var skeleton: Skeleton3D = scene.find_child("Skeleton3D", true, false) as Skeleton3D
		check(skeleton != null and skeleton.get_bone_count() == 8, "%s eight bones" % id)
		var triangles: int = 0
		var skins: Dictionary = {}
		var materials: Dictionary = {}
		var palm_error: float = INF
		var bind: Dictionary = {}
		var meshes: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		check(meshes.size() == 12, "%s only the twelve arm/hand meshes" % id)
		for item: Node in meshes:
			var mesh: MeshInstance3D = item as MeshInstance3D
			if mesh.skin != null:
				skins[mesh.skin.get_instance_id()] = true
				check(mesh.skin.get_bind_count() == 8, "%s eight skin binds" % id)
				for index: int in mesh.skin.get_bind_count():
					var bone: int = mesh.skin.get_bind_bone(index)
					if bone < 0:
						bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
					bind[String(skeleton.get_bone_name(bone))] = mesh.skin.get_bind_pose(index).affine_inverse().origin
			for surface: int in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				check((arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).size() == points.size(), "%s normals" % id)
				check((arrays[Mesh.ARRAY_TANGENT] as PackedFloat32Array).size() == points.size() * 4, "%s tangents" % id)
				check((arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).size() == points.size(), "%s UVs" % id)
				triangles += indices.size() / 3
				var mat: StandardMaterial3D = mesh.mesh.surface_get_material(surface) as StandardMaterial3D
				check(mat != null and mat.metallic == 0.0 and mat.albedo_texture == null and mat.normal_texture == null, "%s texture-free PBR" % id)
				if mat != null:
					materials[mat.resource_name] = true
				if mesh.name != "Arm_L":
					continue
				var bone_ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
				var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
				var posed := PackedVector3Array()
				for vertex: int in points.size():
					var p := Vector3.ZERO
					for slot: int in 4:
						var weight: float = weights[vertex * 4 + slot]
						if weight <= 0.0:
							continue
						var index: int = bone_ids[vertex * 4 + slot]
						var bone: int = mesh.skin.get_bind_bone(index)
						if bone < 0:
							bone = skeleton.find_bone(mesh.skin.get_bind_name(index))
						p += (skeleton.get_bone_global_rest(bone) * mesh.skin.get_bind_pose(index) * points[vertex]) * weight
					posed.append(p)
				for index: int in range(0, indices.size(), 3):
					var p: Vector3 = closest_triangle(WeaponModel.SUPPORT_POINTS[id], posed[indices[index]], posed[indices[index + 1]], posed[indices[index + 2]])
					palm_error = minf(palm_error, p.distance_to(WeaponModel.SUPPORT_POINTS[id]))
		check(triangles == int(expected["triangles"]) and triangles >= 2000 and triangles <= 6000, "%s triangle contract" % id)
		check(palm_error < 0.0001, "%s real skinned palm touches the measured furniture point" % id)
		check(skins.size() == 1 and materials.size() == 3, "%s one skin and three materials" % id)
		check(materials.has("glove") and materials.has("skin") and materials.has("sleeve_cloth"), "%s material names" % id)
		for side: String in ["R", "L"]:
			var upper: Vector3 = bind["UpperArm_" + side]
			var fore: Vector3 = bind["Forearm_" + side]
			var hand: Vector3 = bind["Hand_" + side]
			check(absf(upper.distance_to(fore) - 0.3) < 0.00001 and absf(fore.distance_to(hand) - 0.3) < 0.00001,
				"%s %s bind segments stay 0.30 m" % [id, side])
			check((fore - upper).normalized().dot((hand - fore).normalized()) > 0.99999, "%s %s straight bind" % [id, side])
		for type: String in ["Camera3D", "Light3D", "AnimationPlayer"]:
			check(scene.find_children("*", type, true, false).is_empty(), "%s no %s" % [id, type])
		var report: Dictionary = {"weapon": id, "triangles": triangles, "palm_surface_error_m": palm_error,
			"mesh_count": meshes.size(), "bone_count": skeleton.get_bone_count(), "materials": materials.keys(),
			"glb_sha256": FileAccess.get_sha256(path), "fitting_report_support_m": fitted["support_gun_m"]}
		reports[String(id)] = report
		print("TEST: %s fitted GLB: %d triangles, palm surface error %.6f mm" % [id, triangles, palm_error * 1000.0])
		scene.free()
	var file := FileAccess.open(BASE + "godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "engine": Engine.get_version_info()["string"], "weapons": reports, "failures": failures}, "  "))
	file.close()
	quit(0 if failures.is_empty() else 1)
