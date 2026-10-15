extends SceneTree
## Every enemy kind must have a distinct animated mesh in the live horde view.
var _failures: int = 0
class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + message)
	if not ok:
		_failures += 1


func _run() -> void:
	var view := ZombieHordeView.new()
	root.add_child(view)
	var types: Array[GameData.EnemyType] = GameData.enemy_types()
	var all_handled: bool = true
	for kind in types.size():
		_check(view.handles(kind), "%s has a model instead of a capsule" % types[kind].display_name)
		all_handled = all_handled and view.handles(kind)
	_check(not view.handles(-1) and not view.handles(99), "Unknown enemy kinds are rejected")
	if all_handled:
		_test_meshes(view)
		_test_instances(view, types)
		_test_head_targets(view)
		_test_overlapping_deaths()
	view.free()
	if all_handled:
		await _test_island_models()
	quit(0 if _failures == 0 else 1)


func _test_meshes(view: ZombieHordeView) -> void:
	var shapes: Dictionary = {}
	for node: Node in view.get_children():
		var instance := node as MultiMeshInstance3D
		if instance == null or not String(node.name).begins_with("Zombies_"):
			continue
		var mesh: Mesh = instance.multimesh.mesh
		var triangles: int = 0
		var valid: bool = true
		var signature: int = 0
		for surface in mesh.get_surface_count():
			var a: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = a[Mesh.ARRAY_NORMAL]
			var tangents: PackedFloat32Array = a[Mesh.ARRAY_TANGENT]
			var uvs: PackedVector2Array = a[Mesh.ARRAY_TEX_UV]
			var indices: PackedInt32Array = a[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
			valid = valid and vertices.size() == normals.size() and tangents.size() == vertices.size() * 4 and uvs.size() == vertices.size()
			for p: Vector3 in vertices:
				valid = valid and p.is_finite()
			for i in range(0, indices.size(), 3):
				valid = valid and (vertices[indices[i + 1]] - vertices[indices[i]]).cross(vertices[indices[i + 2]] - vertices[indices[i]]).length_squared() > 0.000000000001
			signature = hash([signature, vertices])
			valid = valid and mesh.surface_get_material(surface) is ShaderMaterial
		_check(valid and triangles >= 300 and triangles <= 6000, "%s has valid textured geometry with normals/tangents (%d triangles)" % [node.name, triangles])
		if String(node.name) in ["Zombies_runner", "Zombies_brute", "Zombies_grabber", "Zombies_behemoth", "Zombies_bloater", "Zombies_screamer"]:
			shapes[signature] = true
	_check(shapes.size() == 6, "The six specials have six different geometries")


func _test_instances(view: ZombieHordeView, types: Array[GameData.EnemyType]) -> void:
	var map := IslandMap.new()
	map.field = FlowField.new(64, 64)
	var h := Horde.new(map.field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 71
	for kind in types.size():
		var i: int = h.add(Vector3(10 + kind * 3, 0, 20), kind, rng)
		h.speeds[i] = 1.7  # Equal speed must never make a special use Walker geometry.
		h.velocities[i] = Vector3(0, 0, 2)
	h.target = Vector3(20, 0, 50)
	view.draw(h, map, 1.0, 0.016)
	var visible: int = 0
	for node: Node in view.get_children():
		var instance := node as MultiMeshInstance3D
		if instance == null:
			continue
		visible += instance.multimesh.visible_instance_count
		if String(node.name) in ["Zombies_runner", "Zombies_brute", "Zombies_grabber", "Zombies_behemoth", "Zombies_bloater", "Zombies_screamer"]:
			_check(instance.multimesh.visible_instance_count == 1, "%s draws its own enemy even with identical rolled speeds" % node.name)
	_check(visible == 7, "Exactly seven alive models are drawn")
	for i in h.count:
		h.freeze_time[i] = 1.0
	view.draw(h, map, 2.0, 0.0)
	var frozen: Array[PackedFloat32Array] = []
	for variant in ZombieHordeView.VARIANTS:
		frozen.append(view.buffer(variant))
	view.draw(h, map, 5.0, 0.0)
	var stable: bool = true
	for variant in ZombieHordeView.VARIANTS:
		stable = stable and frozen[variant] == view.buffer(variant)
	_check(stable, "Frozen models remain still across time for all seven kinds")
	h.freeze_time.fill(0.0)
	# Kind, body scale and mesh must survive removal/array compaction.
	h.remove(1)
	view.draw(h, map, 1.1, 0.016)
	var screamer := view.get_node("Zombies_screamer") as MultiMeshInstance3D
	_check(screamer.multimesh.visible_instance_count == 1, "A compacted special keeps its model")
	for kind in range(1, types.size()):
		view.on_death(Vector4(10 + kind * 3, 20, kind, 0), Vector3(10 + kind * 3, 0, 20), Vector3.ZERO)
	view.draw(h, map, 1.1, 0.0)
	_check(view.corpse_count() == 6, "Every special has a modelled corpse")
	for kind in range(1, types.size()):
		var variant: int = ZombieHordeView.variant_for(kind, 1.7)
		_check(view.instance_count(variant) == (1 if kind == GameData.EnemyKind.RUNNER else 2), "%s corpse keeps its own model" % types[kind].display_name)
	view.draw(h, map, 1.1, ZombieHordeView.CORPSE_TIME + 0.01)
	_check(view.corpse_count() == 0, "Special corpses expire normally")


func _test_head_targets(view: ZombieHordeView) -> void:
	var run := IslandRun.new(71)
	for kind in range(1, GameData.enemy_types().size()):
		var type: GameData.EnemyType = run.horde.types[kind]
		var instance: int = run.horde.add(Vector3(20 + kind, 0, 20), kind, run.rng)
		var node := view.get_node("Zombies_" + ("behemoth" if kind == GameData.EnemyKind.BOSS else String(type.id))) as MultiMeshInstance3D
		var mesh: Mesh = node.multimesh.mesh
		var low := Vector3(INF, INF, INF)
		var high := Vector3(-INF, -INF, -INF)
		var skull_seed: float = -1.0
		for surface in mesh.get_surface_count():
			var a: Array = mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
			var custom: PackedFloat32Array = a[Mesh.ARRAY_CUSTOM0]
			for i in vertices.size():
				if int(custom[i * 4] + 0.5) != ZombieModel.Part.HEAD:
					continue
				if skull_seed < 0.0:
					skull_seed = custom[i * 4 + 1]
				if is_equal_approx(skull_seed, custom[i * 4 + 1]):
					low = low.min(vertices[i])
					high = high.max(vertices[i])
		var centre: Vector3 = (low + high) * 0.5
		var actual_y: float = run.map.ground_y(run.horde.positions[instance]) + centre.y * type.height / ZombieModel.MODEL_HEIGHT
		var expected_y: float = run.enemy_head(instance).y
		_check(skull_seed >= 0.0 and absf(actual_y - expected_y) < 0.002, "%s mesh skull matches the actual headshot target (%.4f m error)" % [type.display_name, absf(actual_y - expected_y)])


func _test_island_models() -> void:
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	root.add_child(island)
	for i in 4:
		await process_frame
	island.set("paused", true)
	var run: IslandRun = island.get("run")
	while run.horde.count > 0:
		run.horde.remove(run.horde.count - 1)
	for kind in GameData.enemy_types().size():
		run.horde.add(run.player_pos + Vector3((kind - 3) * 3.0, 0, -8), kind, run.rng)
	island.call("_draw_enemies")
	var view: ZombieHordeView = island.get("_zombies")
	var count: int = 0
	for variant in ZombieHordeView.VARIANTS:
		count += view.instance_count(variant)
	_check(count == 7, "Real island scene draws all seven enemy kinds as models")
	# Dummy RenderingServer does not retain MultiMesh transforms. Check actual
	# capsule hiding only with a GPU, never infer it from Dummy identity values.
	if DisplayServer.get_name() != "headless":
		var bodies: MultiMesh = island.get("_enemy_mm")
		var hidden: bool = true
		for i in 7:
			hidden = hidden and absf(bodies.get_instance_transform(i).basis.determinant()) < 0.000001
		_check(hidden, "GPU: capsule placeholders are hidden for every enemy kind")
	island.free()


func _test_overlapping_deaths() -> void:
	var view := ZombieHordeView.new()
	root.add_child(view)
	var map := IslandMap.new()
	map.field = FlowField.new(32, 32)
	var h := Horde.new(map.field)
	var rng := RandomNumberGenerator.new()
	var p := Vector3(15, 0, 15)
	for kind in 7:
		h.add(p, kind, rng)
	view.draw(h, map, 1.0, 0.0)
	for kind in range(6, 0, -1):
		h.remove(kind)
		view.draw(h, map, 1.0, 0.0)
		view.on_death(Vector4(p.x, p.z, kind, 0), p, Vector3.ZERO)
		view.draw(h, map, 1.0, 0.0)
		_check(view.instance_count(ZombieHordeView.variant_for(kind, 0.0)) == 1,
			"An overlapping %s dies as its own model, never a neighbour's" % h.types[kind].display_name)
	view.free()
