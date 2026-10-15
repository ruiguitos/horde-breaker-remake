extends SceneTree
## The support palm must follow each GLB forearm while the skeleton aims.

const DT: float = 1.0 / 60.0
const PALM_LOCAL := Vector3(0.000000342, 0.07845914, -0.000000016)
var _failures: int = 0
var _max_error: float = 0.0
var _samples: int = 0


func _check(ok: bool, message: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + message)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for class_id: StringName in [&"recruit", &"vanguard"]:
		var soldier := SoldierModel.create(class_id)
		root.add_child(soldier)
		await process_frame
		var skeleton := soldier.find_child("Skeleton3D", true, false) as Skeleton3D
		var left: int = skeleton.find_bone("DEF-hand.L")
		var right: int = skeleton.find_bone("DEF-hand.R")
		var delivered_tip: Node3D = soldier.get("_rifle_muzzle")
		var grip_from_hand: Transform3D = delivered_tip.transform * Transform3D(Basis.IDENTITY, WeaponModel.GRIP_FROM_MUZZLE)
		var probe := func() -> void:
			var gun: WeaponModel = soldier.get("_gun_node") as WeaponModel
			var palm: Vector3 = skeleton.get_bone_global_pose(left) * PALM_LOCAL
			var target: Vector3 = skeleton.get_bone_global_pose(right) * grip_from_hand * gun.support_point
			_max_error = maxf(_max_error, palm.distance_to(target))
			_samples += 1
		skeleton.skeleton_updated.connect(probe)
		for id: StringName in WeaponModel.IDS:
			soldier.set_weapon(id)
			await process_frame
			_max_error = 0.0
			_samples = 0
			for i in 24:
				soldier.aim_pitch = deg_to_rad(15.0) * sin(float(i) * 0.15)
				soldier.animate(1.0, 0.0, i >= 12, DT)
				soldier.position += Vector3(6.0 if i >= 12 else 0.0, 0.0, -6.0 if i < 12 else 0.0) * DT
				await process_frame
			_check(_samples > 0 and _max_error < 0.002, "%s %s: support palm stays on its own forearm (%.4f m, %d samples)" % [class_id, id, _max_error, _samples])
		skeleton.skeleton_updated.disconnect(probe)
		soldier.free()
	quit(0 if _failures == 0 else 1)
