extends SceneTree
## The first-person arms (FirstPersonArms): the left palm's contact sits on the
## support point of each gun it can reach; the one it cannot reach is measured,
## not hidden; the sleeve and glove take the class colours; the view model wears them.
## Run: godot --headless --path . --script res://tests/test_first_person_arms.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


## Palm contact of the left hand in gun space, read from the skeleton.
func _contact(arms: FirstPersonArms) -> Vector3:
	arms.skeleton.force_update_all_bone_transforms()
	var hand: Transform3D = arms.skeleton.get_bone_global_pose(arms.skeleton.find_bone("Hand_L"))
	return hand.origin + hand.basis * arms._palm_offset


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var palette: Dictionary = SoldierModel.PALETTES[&"recruit"]
	var arms: FirstPersonArms = FirstPersonArms.build(palette)
	_check(arms.skeleton.get_bone_count() == 8, "the arms file has its eight bones")

	arms.set_support(arms.palm_rest)
	_check(arms.reach_error < 0.0001 and _contact(arms).distance_to(arms.palm_rest) < 0.001,
		"at rest the palm stays on the rifle's fitted contact (%.4f mm)" % (_contact(arms).distance_to(arms.palm_rest) * 1000.0))

	# The sleeve and the glove take the class colours.
	var sleeve_ok: bool = false
	var glove_ok: bool = false
	for part: MeshInstance3D in arms.find_children("*", "MeshInstance3D", true, false):
		for surface: int in part.mesh.get_surface_count():
			var source := part.get_active_material(surface) as StandardMaterial3D
			var used := part.get_surface_override_material(surface) as StandardMaterial3D
			if source == null or used == null:
				continue
			if String(source.resource_name) == "sleeve_cloth":
				sleeve_ok = used.albedo_color.is_equal_approx(palette["cloth"])
			if String(source.resource_name) == "glove":
				glove_ok = used.albedo_color.is_equal_approx(palette["dark"])
	_check(sleeve_ok and glove_ok, "the sleeve and the glove take the recruit's colours")

	# The view model wears the arms, on the gun, and solves them for its weapon.
	var vm: ViewModel = ViewModel.create(&"recruit")
	vm.set_weapon(&"smg")
	_check(vm._arms != null and vm._arms.get_parent() == vm._gun and vm._arms.skeleton != null,
		"the view model carries the arms on the gun")
	# A matching contact marker cannot catch oversized fingers: both assets must
	# use the same metre scale so their visible grasp has its authored proportions.
	_check(vm._arms.scale.is_equal_approx(Vector3.ONE) and vm.scale.is_equal_approx(Vector3.ONE),
		"the gun and hands share their authored metre scale (no inverse arm scaling)")
	var vm_contact: Vector3 = _contact(vm._arms)
	var seen: Vector3 = WeaponModel.SUPPORT_POINTS[&"smg"]
	_check(vm._arms.reach_error < 0.0001 and vm_contact.distance_to(seen) < 0.001,
		"the view model's arms hold the SMG's support point in unscaled gun space")
	root.add_child(vm)
	_check(vm.is_inside_tree() and vm._arms.skeleton.is_inside_tree(), "world-space checks run inside the SceneTree")
	for id: StringName in WeaponModel.IDS:
		vm.set_weapon(id)
		_check(vm._arms.get("grip_weapon") == id, "%s: loads its own fitted hand model" % id)
		_check(vm._arms.reach_error < 0.0001, "%s: fitted grip reaches without stretching the bones" % id)
		_check(vm._arms.palm_rest.distance_to(vm._model.support_point) < 0.00001,
			"%s: runtime and fitted contact agree" % id)
		vm._arms.skeleton.force_update_all_bone_transforms()
		var skeleton_in_gun: Transform3D = vm._gun.global_transform.affine_inverse() * vm._arms.skeleton.global_transform
		_check(skeleton_in_gun.is_equal_approx(Transform3D.IDENTITY),
			"%s: skeleton and weapon use the same coordinate frame" % id)
		var world_contact: Vector3 = vm._arms.skeleton.global_transform * _contact(vm._arms)
		var world_support: Vector3 = vm._gun.to_global(vm._model.support_point)
		var world_error: float = world_contact.distance_to(world_support)
		_check(absf(world_error - vm._arms.reach_error) < 0.00001,
			"%s: visible-frame contact error matches measured IK reach (%.3f mm)" % [id, world_error * 1000.0])
	vm.free()
	arms.free()
	quit(1 if _failures > 0 else 0)
