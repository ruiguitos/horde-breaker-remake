extends SceneTree
## The reload clips drive the right hand (FirstPersonArms.set_reload, fed by
## ViewModel.reload): at mid-reload the SMG's right palm sits on the dropped
## magazine, the left palm stays on its support point, and the right hand is
## back on the grip at the end. A weapon whose file has no reload clip yet
## skips the check and says so.
## Run: godot --headless --path . --script res://tests/test_first_person_reload.gd

## Inner glove palm of the right hand, in the skeleton's (gun) space, as the
## Codex audit measures it (tests/test_reload_arm_clips.gd).
const PALM_RIGHT: Vector3 = Vector3(0.0185, -0.025, 0.016)
## The SMG magazine's base in gun space, before any reload movement.
const SMG_MAGAZINE_BASE: Vector3 = Vector3(0, -0.148, -0.143)

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var vm := ViewModel.create(&"recruit")
	vm.set_weapon(&"smg")
	root.add_child(vm)
	var arms: FirstPersonArms = vm._arms
	if not arms.has_reload():
		print("TEST: the SMG file has no reload clip yet; the reload check is skipped")
		vm.free()
		quit(0)
		return
	var skeleton: Skeleton3D = arms.skeleton
	var right: int = skeleton.find_bone("Hand_R")
	var left: int = skeleton.find_bone("Hand_L")
	skeleton.force_update_all_bone_transforms()
	var rest_right: Transform3D = skeleton.get_bone_global_rest(right)
	var rest_left: Transform3D = skeleton.get_bone_global_rest(left)
	var palm_offset: Vector3 = rest_right.affine_inverse() * PALM_RIGHT
	var left_offset: Vector3 = rest_left.affine_inverse() * WeaponModel.SUPPORT_POINTS[&"smg"]

	for p: float in [0.0, 0.5, 1.0]:
		vm.reload = p
		vm.update(0.016, 0.0, 0.0, 0.0)
		skeleton.force_update_all_bone_transforms()
		var hand: Transform3D = skeleton.get_bone_global_pose(right)
		var support: Vector3 = skeleton.get_bone_global_pose(left) * left_offset
		_check(support.distance_to(WeaponModel.SUPPORT_POINTS[&"smg"]) < 0.0001,
			"the left palm stays on the SMG support at p=%.2f" % p)
		if p == 0.5:
			var base: Vector3 = SMG_MAGAZINE_BASE + ViewModel.reload_offset(p)
			var palm: Vector3 = hand * palm_offset
			_check(palm.distance_to(base) < 0.001,
				"the right palm reaches the dropped magazine base at p=0.50 (%.2f mm off)" % (palm.distance_to(base) * 1000.0))
		else:
			_check(hand.origin.distance_to(rest_right.origin) < 0.0001,
				"the right hand is back on the grip at p=%.0f" % p)

	vm.free()
	quit(1 if _failures > 0 else 0)
