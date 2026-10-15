extends SceneTree
## Weapon art (WeaponModel): the five original GLBs retain their geometry,
## PBR materials and muzzle in game; SoldierModel (third person, Armory) and
## ViewModel (first person) show the equipped one; in the island every
## camera mode shows the right gun, and common zombies are drawn by
## ZombieHordeView instead of capsules.
## Run: godot --headless --path . --script res://tests/test_weapon_models.gd

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

## Muzzle to butt, metres: real guns are ~0.6 (SMG) to ~1.15 m (marksman).
const LENGTHS: Dictionary = {&"rifle": Vector2(0.9, 1.0), &"smg": Vector2(0.6, 0.8), &"machine_gun": Vector2(0.95, 1.1),
	&"shotgun": Vector2(0.95, 1.1), &"marksman": Vector2(1.05, 1.2)}
const GLB_TRIANGLES: Dictionary = {&"rifle": 7482, &"smg": 6292, &"machine_gun": 7940, &"shotgun": 4550, &"marksman": 7708}
const GLB_LENGTHS: Dictionary = {&"rifle": 0.96, &"smg": 0.74, &"machine_gun": 1.04, &"shotgun": 1.04, &"marksman": 1.12}

var _failures: int = 0
var _done: bool = false


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	create_timer(60.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "weapon tests finished in time")
			_finish())
	_test_models()
	_test_soldiers()
	_test_view_model()
	call_deferred("_scene_tests")


func _finish() -> void:
	_done = true
	quit(1 if _failures > 0 else 0)


func _test_models() -> void:
	for id: StringName in WeaponModel.IDS:
		var w := WeaponModel.build(id)
		var range_ok: Vector2 = LENGTHS[id]
		_check(w.weapon_id == id and w.muzzle != null and w.muzzle.position.z < -0.4 and absf(w.muzzle.position.y) < 0.16,
			"%s: muzzle ahead of the grip (%.2f m)" % [id, -w.muzzle.position.z])
		_check(w.length >= range_ok.x and w.length <= range_ok.y, "%s: %.2f m long" % [id, w.length])
		_check(absf(w.length - float(GLB_LENGTHS[id])) <= 0.02, "%s: GLB real-world length within 2 cm" % id)
		var triangles: int = 0
		var surfaces: int = 0
		var attributes_ok: bool = true
		var materials_ok: bool = true
		for part: MeshInstance3D in w.find_children("*", "MeshInstance3D", true, false):
			_check(part.mesh is ArrayMesh, "%s: imported geometry, not a primitive" % id)
			for surface: int in part.mesh.get_surface_count():
				surfaces += 1
				var arrays: Array = part.mesh.surface_get_arrays(surface)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				triangles += int(indices.size() / 3) if not indices.is_empty() else int(vertices.size() / 3)
				attributes_ok = attributes_ok and arrays[Mesh.ARRAY_NORMAL] != null and arrays[Mesh.ARRAY_TANGENT] != null and arrays[Mesh.ARRAY_TEX_UV] != null
				if attributes_ok:
					attributes_ok = arrays[Mesh.ARRAY_NORMAL].size() == vertices.size() and arrays[Mesh.ARRAY_TANGENT].size() == vertices.size() * 4 and arrays[Mesh.ARRAY_TEX_UV].size() == vertices.size()
				var material := part.get_active_material(surface) as StandardMaterial3D
				materials_ok = materials_ok and material != null and material.resource_name in ["gunmetal", "steel", "polymer", "wood", "rust", "bore"]
		_check(triangles == int(GLB_TRIANGLES[id]), "%s: all %d source GLB triangles retained (%d)" % [id, GLB_TRIANGLES[id], triangles])
		_check(surfaces >= 4 and surfaces <= 6 and materials_ok, "%s: batched by the original PBR materials (%d surfaces)" % [id, surfaces])
		_check(attributes_ok, "%s: exported normals, tangents and UVs retained" % id)
		_check(w.muzzle.get_parent() == w and w.muzzle.basis.is_equal_approx(Basis.IDENTITY), "%s: muzzle in grip space, -Z forward" % id)
		w.free()
	var fallback := WeaponModel.build(&"pistol")
	_check(fallback.weapon_id == &"rifle", "unknown ids fall back to the rifle")
	fallback.free()
	_check(WeaponModel.material("gunmetal") == WeaponModel.material("gunmetal"), "materials are shared between guns")


func _test_soldiers() -> void:
	for class_id: StringName in [&"recruit", &"vanguard"]:
		var s := SoldierModel.create(class_id)
		root.add_child(s)
		for id: StringName in WeaponModel.IDS:
			s.set_weapon(id)
			var guns: Array[Node] = s.find_children("Weapon_*", "Node3D", true, false)
			var on_hand: bool = guns.size() == 1 and guns[0].get_parent().name == "WeaponMount"
			_check(on_hand and guns[0].name == "Weapon_" + String(id) and s.muzzle != null and s.muzzle.get_parent() != null,
				"%s holds the %s on the right hand, muzzle live" % [class_id, id])
			var gun := guns[0] as WeaponModel
			_check(s.muzzle == gun.muzzle, "%s %s: shots use the equipped GLB muzzle" % [class_id, id])
		s.free()


func _test_view_model() -> void:
	var vm := ViewModel.create(&"recruit")
	root.add_child(vm)
	for id: StringName in WeaponModel.IDS:
		vm.set_weapon(id)
		var gun := vm.find_child("Weapon_" + String(id), true, false) as WeaponModel
		var shadows: bool = false
		if gun != null:
			for c in gun.get_children():
				if c is MeshInstance3D and (c as MeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					shadows = true
		_check(gun != null and not shadows and vm.tip != null and vm.tip.position.z < gun.muzzle.position.z,
			"first person: %s in the hands, no shadow at the eye, flash past the muzzle" % id)
	# Reach in camera space: the gun must not fill the view.
	vm.set_weapon(&"marksman")
	var reach: float = -(vm.position.z + vm.tip.position.z * vm.scale.z)
	_check(reach < 0.95 and vm.scale.x <= 0.6, "first-person marksman reaches %.2f m ahead of the eye at %.0f %% scale" % [reach, vm.scale.x * 100])
	vm.free()


func _settle(frames: int) -> void:
	for k in frames:
		await process_frame


func _scene_tests() -> void:
	var profile := MemoryProfile.new()
	profile.camera_mode = Profile.CameraMode.THIRD_PERSON
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	root.add_child(island)
	await _settle(3)
	var run: IslandRun = island.get("run")
	run.noclip = true
	run.director.max_alive = 0
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	var soldier: SoldierModel = island.get("_player")
	var view_model: ViewModel = island.get("_view_model")
	var slot: GameData.Weapon = run.weapons[run.weapon_index]
	var original: StringName = slot.id
	for mode: int in [Profile.CameraMode.FIRST_PERSON, Profile.CameraMode.THIRD_PERSON, Profile.CameraMode.FIXED]:
		profile.camera_mode = mode  # the island follows the profile setting
		await _settle(1)
		_check(int(island.get("camera_mode")) == mode, "%s camera active" % Profile.CAMERA_MODE_NAMES[mode])
		for id: StringName in WeaponModel.IDS:
			slot.id = id  # visual check only: the stats stay the slot's own
			await _settle(2)
			var held: bool = soldier.weapon_id == id and soldier.find_child("Weapon_" + String(id), true, false) != null
			var fp: bool = mode == Profile.CameraMode.FIRST_PERSON
			var shown: bool = view_model.visible == fp and (not fp or view_model.weapon_id == id)
			_check(held and shown, "%s camera: %s in the soldier's hands%s" % [Profile.CAMERA_MODE_NAMES[mode], id, " and in first person" if fp else ""])
	slot.id = original
	# All enemy kinds use ZombieHordeView; walkers and brutes have distinct meshes.
	var p: Vector3 = run.player_pos
	for k in 6:
		run.horde.add(p + Vector3(-5 + k * 2, 0, -12), GameData.EnemyKind.WALKER if k < 4 else GameData.EnemyKind.BRUTE, run.rng)
	await _settle(2)
	var zombies: ZombieHordeView = island.get("_zombies")
	# Auto-fire may already have shot one: it is then a falling corpse
	# (drawn from the next frame), still by the same view.
	island.set("paused", true)
	await _settle(2)
	var drawn: int = 0
	for v in ZombieHordeView.VARIANTS:
		drawn += zombies.instance_count(v)
	var walkers: int = 0
	for k in run.horde.count:
		if run.horde.kinds[k] == GameData.EnemyKind.WALKER:
			walkers += 1
	_check(walkers + zombies.corpse_count() == 4 and drawn == 6
		and zombies.instance_count(ZombieHordeView.variant_for(GameData.EnemyKind.BRUTE, 0.0)) == 2,
		"island draws 4 walkers (%d alive + %d corpses) and 2 distinct brute models" % [walkers, zombies.corpse_count()])
	island.queue_free()
	await _settle(2)
	_finish()
