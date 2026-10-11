extends SceneTree
## Textured props must remain grounded and preserve objective feedback.

var _failures: int = 0


func _check(ok: bool, message: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + message)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var path: String = "res://game/world/island_props.gd"
	_check(ResourceLoader.exists(path), "Realistic props have a runtime adapter")
	if not ResourceLoader.exists(path):
		quit(1)
		return
	var props: Script = load(path)
	for id: StringName in [&"generator", &"jerrycan", &"crate", &"barrier"]:
		var model: Node3D = props.call("create", id)
		_check(model != null, "%s loads without Blender" % id)
		if model == null:
			continue
		var bounds: AABB = props.call("bounds", model)
		_check(absf(bounds.position.y) < 0.001 and bounds.size.y > 0.3 and bounds.size.y < 2.0, "%s keeps metre scale and feet on the ground" % id)
		var textured: bool = true
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface) as StandardMaterial3D
				textured = textured and material != null and material.albedo_texture != null
		_check(textured, "%s retains its textured materials" % id)
		model.free()
	_check(props.call("create", &"not_an_asset") == null, "Unknown prop returns the primitive fallback")
	for size: Vector3 in [Vector3(12, 1.6, 1), Vector3(1, 1.6, 17)]:
		var wall: MultiMeshInstance3D = props.call("barrier_wall", size)
		_check(wall != null and wall.multimesh.instance_count > 1, "Long walls repeat barriers in one MultiMesh")
		if wall == null:
			continue
		var bounds := AABB()
		var transforms: Array[Transform3D] = props.call("barrier_transforms", wall.multimesh.mesh.get_aabb(), size)
		for i in transforms.size():
			var box: AABB = transforms[i] * wall.multimesh.mesh.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
		var footprint := AABB(-size * 0.5, size).grow(0.001)
		_check(footprint.encloses(bounds) and bounds.size.is_equal_approx(Vector3(size.x if size.x > 1 else bounds.size.x, size.y, size.z if size.z > 1 else bounds.size.z)),
			"Barricade stays inside the existing blocked footprint (%s inside %s)" % [bounds.size, size])
		wall.free()
	var scene: PackedScene = load("res://game/world/island.tscn")
	for enabled: bool in [true, false]:
		var island: Node = scene.instantiate()
		island.set("realistic_props", enabled)
		root.add_child(island)
		await process_frame
		island.set_physics_process(false)
		var run: IslandRun = island.get("run")
		var blocked: PackedByteArray = run.field.blocked.duplicate()
		var generators: Array = island.get("_generators")
		var caches: Array = island.get("_caches")
		_check(not generators.is_empty() and not caches.is_empty(), "Test island has generators and supply caches")
		for gen: MeshInstance3D in generators:
			_check((gen.find_child("PolyHaven_generator", false, false) != null) == enabled, "Generator respects the realistic-props switch")
		for cache: MeshInstance3D in caches:
			_check((cache.find_child("PolyHaven_crate", false, false) != null) == enabled, "Supply cache respects the realistic-props switch")
		run.generator_progress[0] = GameData.GENERATOR_HOLD_SECONDS
		run.cache_progress[0] = GameData.CACHE_OPEN_TIME
		island.call("_draw_mission")
		_check(not (island.get("_generator_rings") as Array)[0].visible and generators[0].material_override.albedo_color == Color(0.2, 0.85, 0.3), "Activated generator retains its green completion feedback")
		_check(caches[0].material_override.albedo_color == Color(0.25, 0.25, 0.25), "Opened crate retains its used feedback")
		_check(run.field.blocked == blocked, "Rendering props never changes the navigation grid")
		island.free()
	quit(0 if _failures == 0 else 1)
