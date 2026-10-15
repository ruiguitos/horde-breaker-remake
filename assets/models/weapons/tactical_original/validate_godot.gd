extends SceneTree
## Direct GLB decoding: does not require the editor's asset import database.

const DIR: String = "res://assets/models/weapons/tactical_original/"
const LENGTHS: Dictionary = {"assault_rifle": 0.96, "smg": 0.74, "machine_gun": 1.04, "shotgun": 1.04, "marksman": 1.12}
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		print("TEST FAIL: " + message)


func _run() -> void:
	var report: Dictionary = {"godot_version": Engine.get_version_info().string, "weapons": {}}
	for weapon_name: String in LENGTHS:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var error: Error = document.append_from_file(DIR + weapon_name + ".glb", state)
		_check(error == OK, weapon_name + ": GLB decode")
		if error != OK:
			continue
		var weapon: Node3D = document.generate_scene(state) as Node3D
		_check(weapon != null, weapon_name + ": scene generation")
		if weapon == null:
			continue
		root.add_child(weapon)
		var queue: Array[Node] = [weapon]
		var meshes: int = 0
		var triangles: int = 0
		var muzzle: Node3D
		var bounds := AABB()
		var have_bounds: bool = false
		while not queue.is_empty():
			var node: Node = queue.pop_back()
			for child: Node in node.get_children():
				queue.append(child)
			_check(not (node is Camera3D or node is Light3D or node is Skeleton3D or node is AnimationPlayer), weapon_name + ": forbidden node")
			if node.name == &"Muzzle":
				muzzle = node as Node3D
			if node is MeshInstance3D:
				var instance := node as MeshInstance3D
				meshes += 1
				_check(instance.transform.is_equal_approx(Transform3D.IDENTITY), weapon_name + ": applied mesh transform")
				var local_bounds: AABB = instance.global_transform * instance.mesh.get_aabb()
				bounds = bounds.merge(local_bounds) if have_bounds else local_bounds
				have_bounds = true
				for surface_index: int in range(instance.mesh.get_surface_count()):
					var arrays: Array = instance.mesh.surface_get_arrays(surface_index)
					var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
					var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
					var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					_check(normals.size() == vertices.size(), weapon_name + ": runtime normals")
					_check(tangents.size() == vertices.size() * 4, weapon_name + ": runtime tangents")
					_check(uvs.size() == vertices.size(), weapon_name + ": runtime UVs")
					triangles += int(indices.size() / 3)
		_check(muzzle != null, weapon_name + ": Muzzle exists")
		_check(absf(bounds.size.z - float(LENGTHS[weapon_name])) <= 0.02, weapon_name + ": overall length")
		_check(triangles >= 4000 and triangles <= 9000, weapon_name + ": triangle budget")
		_check(weapon.transform.is_equal_approx(Transform3D.IDENTITY), weapon_name + ": grip root identity")
		if muzzle != null:
			_check((-muzzle.global_basis.z).is_equal_approx(Vector3.FORWARD), weapon_name + ": muzzle -Z forward")
			_check(absf(muzzle.global_position.z - bounds.position.z) < 0.00001, weapon_name + ": muzzle at barrel tip")
			report.weapons[weapon_name] = {"length_m": bounds.size.z, "triangles": triangles, "mesh_count": meshes,
				"muzzle_position": [muzzle.global_position.x, muzzle.global_position.y, muzzle.global_position.z]}
		print("TEST: " + weapon_name + " decoded; " + str(triangles) + " triangles; " + str(bounds.size.z) + " m")
		weapon.free()
	report["passed"] = failures == 0 and report.weapons.size() == LENGTHS.size()
	var file := FileAccess.open(DIR + "checks/godot_validation.json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
	print("TEST: weapon GLBs: " + str(failures) + " failures")
	quit(0 if report.passed else 1)
