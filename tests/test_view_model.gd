extends SceneTree
## First-person gun (ViewModel): the gun is built from its named parts, the
## sights line up with the centre of the view when aiming, and the magazine and
## the charging handle move through a reload and return to rest afterwards.
## Run: godot --headless --path . --script res://tests/test_view_model.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var rifle: WeaponModel = WeaponModel.build_parts(&"rifle")
	var meshes: int = rifle.find_children("*", "MeshInstance3D", true, false).size()
	_check(meshes > 50 and rifle.parts.has("Curved 5_56 magazine") and rifle.parts.has("Charging handle stem")
		and rifle.parts.has("Front sight post") and rifle.parts.has("Rear sight aperture") and rifle.muzzle.get_parent() == rifle,
		"the rifle keeps %d named parts (not batched), with its sights and muzzle" % meshes)
	rifle.free()
	for id: StringName in [&"machine_gun", &"marksman"]:
		var aimed: ViewModel = ViewModel.create(&"recruit")
		aimed.set_weapon(id)
		aimed.aim = 1.0
		aimed.update(0.0, 0.0, 0.0, 0.0)
		var anchor_name: String = "LMG front sight post" if id == &"machine_gun" else "Eyepiece lens"
		var anchor: Vector3 = aimed.transform * aimed._gun.transform * ViewModel._part_centre(aimed._model.parts[anchor_name])
		_check(absf(anchor.x) < 0.001 and absf(anchor.y) < 0.008,
			"%s: ADS follows the sight axis instead of entering the receiver" % id)
		if id == &"machine_gun":
			_check(aimed._model.parts.has("LMG rear sight aperture"), "machine_gun: a rear aperture completes the iron sights")
			var rear: Vector3 = aimed.transform * aimed._gun.transform * ViewModel._part_centre(aimed._model.parts["LMG rear sight aperture"])
			_check(rear.distance_to(Vector3(0, 0, -ViewModel.EYE_TO_REAR)) < 0.001,
				"machine_gun: the eye stays behind the centred rear aperture")
		else:
			_check(not aimed._gun.visible, "marksman: the opaque model does not obstruct the scoped view")
			_check(absf(anchor.z + ViewModel.EYE_TO_REAR) < 0.001, "marksman: the eye stays behind the ocular lens")
			aimed.aim = 0.5
			aimed.update(0.0, 0.0, 0.0, 0.0)
			_check(aimed._gun.visible and not aimed.is_scoped(), "marksman: raising ADS keeps the weapon visible before entering the scope")
			aimed.aim = 0.0
			aimed.update(0.0, 0.0, 0.0, 0.0)
			_check(aimed._gun.visible, "marksman: lowering the scope restores the gun and hands")
		aimed.free()

	_check(ViewModel.reload_offset(0.0).is_zero_approx() and ViewModel.reload_offset(1.0).is_zero_approx(),
		"the magazine is in place before and after a reload")
	_check(absf(ViewModel.reload_offset(0.5).y + ViewModel.MAG_DROP) < 0.0001 and absf(ViewModel.reload_offset(0.5).z) < 0.0001,
		"the magazine is fully dropped half way through the reload")
	var mid_out: float = ViewModel.reload_offset(0.15).y
	_check(mid_out < 0.0 and mid_out > -ViewModel.MAG_DROP, "the magazine is part way out at 15 % of the reload")
	_check(ViewModel.charge_offset(0.5).is_zero_approx() and ViewModel.charge_offset(1.0).is_zero_approx(),
		"the charging handle does not move until the last fifth of a reload, and is back at the end")
	_check(absf(ViewModel.charge_offset(0.9).z - ViewModel.CHARGE_PULL) < 0.0001,
		"the charging handle is pulled fully back at 90 % of the reload")

	for id: StringName in [&"rifle", &"smg"]:
		var vm: ViewModel = ViewModel.create(&"recruit")
		vm.set_weapon(id)
		vm.aim = 1.0
		vm.update(0.0, 0.0, 0.0, 0.0)
		var layout: Dictionary = ViewModel.LAYOUT[id]
		var model: WeaponModel = vm._model
		# Gun part -> camera space: the gun's tilt, then the view model's scale and place.
		var to_camera: Transform3D = vm.transform * vm._gun.transform
		var front: Vector3 = to_camera * ViewModel._part_centre(model.parts[layout["front"]] as MeshInstance3D)
		var rear: Vector3 = to_camera * ViewModel._part_centre(model.parts[layout["rear"]] as MeshInstance3D)
		_check(absf(front.x) < 0.001 and absf(front.y) < 0.001,
			"%s: the front sight is on the centre of the view when aiming (%.4f, %.4f m)" % [id, front.x, front.y])
		_check(absf(rear.x) < 0.001 and absf(rear.y) < 0.001 and absf(rear.z + ViewModel.EYE_TO_REAR) < 0.001,
			"%s: the rear sight is %.2f m from the eye, on the same line" % [id, ViewModel.EYE_TO_REAR])
		vm.free()

	var vm: ViewModel = ViewModel.create(&"recruit")
	vm.set_weapon(&"smg")
	var mag: MeshInstance3D = vm._model.parts["Curved 9mm magazine"] as MeshInstance3D
	var rest: Vector3 = mag.position
	vm.reload = 0.5
	vm.update(0.0, 0.0, 0.0, 0.0)
	_check(absf((mag.position - rest).y + ViewModel.MAG_DROP) < 0.0001, "smg: the magazine drops during the reload")
	vm.reload = 0.0
	vm.update(0.0, 0.0, 0.0, 0.0)
	_check(mag.position.is_equal_approx(rest), "smg: the magazine is back at rest after the reload")
	vm.free()

	quit(1 if _failures > 0 else 0)
