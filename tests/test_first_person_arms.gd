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
	var palette: Dictionary = SoldierModel.PALETTES[&"recruit"]
	var arms: FirstPersonArms = FirstPersonArms.build(palette)
	_check(arms.skeleton.get_bone_count() == 8, "the arms file has its eight bones")

	arms.set_support(FirstPersonArms.PALM_REST)
	_check(arms.reach_error < 0.0001 and _contact(arms).distance_to(FirstPersonArms.PALM_REST) < 0.001,
		"at rest the palm stays on the rifle's support point (%.4f mm)" % (_contact(arms).distance_to(FirstPersonArms.PALM_REST) * 1000.0))

	for id: StringName in [&"rifle", &"smg", &"machine_gun"]:
		var support: Vector3 = WeaponModel.SUPPORT_POINTS[id]
		arms.set_support(support)
		var error: float = _contact(arms).distance_to(support)
		_check(arms.reach_error < 0.0001 and error < 0.001,
			"%s: the palm reaches its support point (%.4f mm off)" % [id, error * 1000.0])

	# Just out of reach (measured): the arm stretches fully and the gap is reported.
	arms.set_support(WeaponModel.SUPPORT_POINTS[&"marksman"])
	_check(arms.reach_error > 0.0005 and arms.reach_error < 0.003,
		"marksman: a few millimetres short of its support point (%.2f mm)" % (arms.reach_error * 1000.0))
	arms.set_support(WeaponModel.SUPPORT_POINTS[&"shotgun"])
	_check(arms.reach_error > 0.005 and arms.reach_error < 0.02,
		"shotgun: the handguard is out of reach, the gap is measured (%.2f cm)" % (arms.reach_error * 100.0))

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
	# The arms are drawn at real size inside the half-size gun: the palm meets the
	# gun's support point as the eye sees it, at GUN_SCALE.
	var vm_contact: Vector3 = _contact(vm._arms)
	var seen: Vector3 = WeaponModel.SUPPORT_POINTS[&"smg"] * ViewModel.GUN_SCALE
	_check(vm._arms.reach_error < 0.0001 and vm_contact.distance_to(seen) < 0.001,
		"the view model's arms hold the SMG's support point (as drawn at GUN_SCALE)")
	vm.free()
	arms.free()
	quit(1 if _failures > 0 else 0)
