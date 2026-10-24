extends SceneTree
## First-person gun (ViewModel): the gun is built from its named parts, the
## sights line up with the centre of the view when aiming, and the magazine and
## the charging handle move through a reload and return to rest afterwards.
## Run: godot --headless --path . --script res://tests/test_view_model.gd

const DT: float = 1.0 / 60.0

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

	call_deferred("_weight_checks")


## Weight: the gun trails a turn of the camera, settles back when the turn stops, keeps the sight
## line while aiming, and its drift is capped by LAG_MAX however fast the turn is. Deferred: the
## gun reads its camera's transform, which needs the camera in the tree.
func _weight_checks() -> void:
	var camera := Node3D.new()
	root.add_child(camera)
	var weighted: ViewModel = ViewModel.create(&"recruit")
	camera.add_child(weighted)
	weighted.update(DT, 0.0, 0.0, 0.0)
	var resting: Vector3 = weighted.position
	for k in 30:
		camera.rotation.y += 2.0 * DT
		weighted.update(DT, 0.0, 0.0, 0.0)
	var trail: Vector3 = weighted.position - resting
	_check(absf(trail.x - 0.012) < 0.002 and absf(trail.y) < 0.0005,
		"turning left at 2 rad/s, the gun trails to the right by about 12 mm (%.4f m)" % trail.x)
	for k in 60:
		weighted.update(DT, 0.0, 0.0, 0.0)
	_check(weighted.position.distance_to(resting) < 0.0005, "the gun settles back when the turn stops")
	for k in 30:
		camera.rotation.x += 2.0 * DT
		weighted.update(DT, 0.0, 0.0, 0.0)
	var lift: Vector3 = weighted.position - resting
	_check(lift.y < -0.01 and absf(lift.x) < 0.0005, "looking up at 2 rad/s, the gun drops (%.4f m)" % lift.y)
	for k in 60:
		weighted.update(DT, 0.0, 0.0, 0.0)
	weighted.aim = 1.0
	for k in 30:
		camera.rotation.y += 2.0 * DT
		weighted.update(DT, 0.0, 0.0, 0.0)
	var sight: Vector3 = weighted.position - weighted._ads_rest
	_check(absf(sight.x) < 0.0005 and absf(sight.y) < 0.0005, "aiming down the sights, a turn does not move the sight line")
	weighted.aim = 0.0
	for k in 60:
		camera.rotation.y += 20.0 * DT
		weighted.update(DT, 0.0, 0.0, 0.0)
	var spun: Vector2 = Vector2(weighted.position.x - weighted._hip_rest.x, weighted.position.y - weighted._hip_rest.y)
	_check(spun.length() <= ViewModel.LAG_MAX + 0.0005 and spun.length() > 0.02,
		"a very fast turn drifts the gun, capped at LAG_MAX (%.4f m)" % spun.length())
	# Back from third person (hidden, not updated), the gun starts from rest: no false 90 degree turn.
	var second := Node3D.new()
	root.add_child(second)
	var follower: ViewModel = ViewModel.create(&"recruit")
	second.add_child(follower)
	follower.update(DT, 0.0, 0.0, 0.0)
	var settled: Vector3 = follower.position
	for k in 30:
		second.rotation.y += 2.0 * DT
		follower.update(DT, 0.0, 0.0, 0.0)
	_check(follower._lag.length() > 0.01, "a second gun trails its turn as well (%.4f m)" % follower._lag.length())
	follower.visible = false
	second.rotation.y += PI / 2.0
	follower.visible = true
	follower.update(DT, 0.0, 0.0, 0.0)
	_check(follower.position.distance_to(settled) < 0.0005 and follower._lag.length() < 0.0001,
		"back from hiding, a 90 degree turn made meanwhile does not drift the gun (%.5f m)" % follower._lag.length())

	# Moved to another camera: its orientation is not a turn of this one.
	var third := Node3D.new()
	root.add_child(third)
	third.rotation.y = 1.0
	second.remove_child(follower)
	third.add_child(follower)
	follower.update(DT, 0.0, 0.0, 0.0)
	_check(follower._lag.length() < 0.0001, "moved to another camera, the gun starts from rest")

	# A zero or negative frame time keeps the sample and never pushes the drift past where it was.
	for k in 30:
		third.rotation.y += 2.0 * DT
		follower.update(DT, 0.0, 0.0, 0.0)
	var drifted: float = follower._lag.length()
	follower.update(0.0, 0.0, 0.0, 0.0)
	follower.update(-DT, 0.0, 0.0, 0.0)
	_check(absf(follower._lag.length() - drifted) < 0.000001, "a zero or negative frame time leaves the drift alone (%.5f m)" % drifted)
	third.rotation.y += 2.0 * DT
	follower.update(DT, 0.0, 0.0, 0.0)
	_check(follower._lag.length() > drifted, "the turn keeps counting after a zero frame time")

	# A fast diagonal spin: the drift stays within LAG_MAX on every frame, not only at the end.
	var peak: float = 0.0
	for k in 60:
		third.rotation.y += 20.0 * DT
		third.rotation.x += 5.0 * DT
		follower.update(DT, 0.0, 0.0, 0.0)
		peak = maxf(peak, follower._lag.length())
	_check(peak <= ViewModel.LAG_MAX + 0.0005 and peak > 0.02, "every frame of a fast diagonal spin stays within LAG_MAX (peak %.4f m)" % peak)

	third.free()
	second.free()
	camera.free()
	quit(1 if _failures > 0 else 0)
