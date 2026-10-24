extends SceneTree
## The player model's reactions (docs/tech/LOCOMOTION.md): a flinch when the
## body is hit, rate-limited; the Breaker's roll during the dash; and the death,
## which fades in, holds its last pose and switches the posing rig off. The recoil
## of the player's shots kicks the trunk back, never the legs.
## Run: godot --headless --path . --script res://tests/test_soldier_reactions.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0
var _posed: Dictionary = {}


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	for class_id: StringName in [&"recruit", &"vanguard"]:
		_test_reactions(class_id)
		await _test_recoil(class_id)
	quit(1 if _failures > 0 else 0)


## Advances the model's animation by `seconds`, one frame at a time.
func _advance(soldier: SoldierModel, seconds: float) -> void:
	for i in int(round(seconds / DT)):
		soldier.animate(0.0, 0.0, false, DT)


func _test_reactions(class_id: StringName) -> void:
	var soldier := SoldierModel.create(class_id)
	root.add_child(soldier)
	_advance(soldier, DT)
	var tree: AnimationTree = soldier.get("_tree")
	var skeleton: Skeleton3D = soldier.get("_skeleton")
	var hips: int = skeleton.find_bone("DEF-hips")

	# A flinch starts once, is not restarted inside the cooldown, and ends by itself.
	_check(soldier.react_hit(), "%s: a hit starts the flinch" % class_id)
	_check(not soldier.react_hit(), "%s: a second hit inside the cooldown does not restart it" % class_id)
	_advance(soldier, 0.1)
	_check(bool(tree.get("parameters/hit/active")), "%s: the flinch plays" % class_id)
	_advance(soldier, 1.5)
	_check(not bool(tree.get("parameters/hit/active")), "%s: the flinch ends on its own" % class_id)
	_check(soldier.react_hit(), "%s: after the cooldown a hit flinches again" % class_id)
	_advance(soldier, 1.5)

	# The dash rolls the body while it lasts and fades the roll out afterwards.
	soldier.set_dashing(true)
	_advance(soldier, DT)
	_check(bool(tree.get("parameters/dash/active")), "%s: the dash rolls the body" % class_id)
	soldier.set_dashing(false)
	_advance(soldier, 0.5)
	_check(not bool(tree.get("parameters/dash/active")), "%s: the roll fades out after the dash" % class_id)

	# Death: the clip takes the body, the posing rig stops, and the pose holds.
	skeleton.force_update_all_bone_transforms()
	var standing: Vector3 = skeleton.get_bone_global_pose(hips).origin
	soldier.die()
	_check(soldier.is_dead() and not soldier.react_hit(), "%s: a dead body takes no more flinches" % class_id)
	_advance(soldier, 0.5)
	_check(is_equal_approx(float(tree.get("parameters/death/blend_amount")), 1.0), "%s: the death pose takes over" % class_id)
	var hold: SkeletonModifier3D = soldier.get("_hold")
	var rig: SkeletonModifier3D = soldier.get("_rig")
	_check(not hold.active and not rig.active, "%s: the posing rig is off, so the arms and legs are not pulled back" % class_id)
	_advance(soldier, 2.0)
	skeleton.force_update_all_bone_transforms()
	var settled: Vector3 = skeleton.get_bone_global_pose(hips).origin
	_check(standing.distance_to(settled) > 0.05, "%s: the death clip moves the body (%.2f m)" % [class_id, standing.distance_to(settled)])
	_advance(soldier, 3.0)
	skeleton.force_update_all_bone_transforms()
	var later: Vector3 = skeleton.get_bone_global_pose(hips).origin
	_check(settled.distance_to(later) < 0.001, "%s: the death holds its last pose (%.4f m drift)" % [class_id, settled.distance_to(later)])
	soldier.free()


## The recoil: a shot of the player's kicks the trunk back a few degrees, the kick fades on
## its own, and the legs never move for it. A dash or a death clears a kick under way, in the
## rig too, and then takes no more.
func _test_recoil(class_id: StringName) -> void:
	_posed.clear()
	var kicked := SoldierModel.create(class_id)
	var still := SoldierModel.create(class_id)
	root.add_child(kicked)
	root.add_child(still)
	await process_frame
	await _frames(kicked, still, 2)
	var skeleton: Skeleton3D = kicked.get("_skeleton")
	var other: Skeleton3D = still.get("_skeleton")
	var spine: int = skeleton.find_bone("DEF-spine.002")
	var thigh: int = skeleton.find_bone("DEF-thigh.L")
	skeleton.skeleton_updated.connect(_record_pose.bind(skeleton, "kicked", spine, thigh))
	other.skeleton_updated.connect(_record_pose.bind(other, "still", spine, thigh))
	kicked.recoil()
	await _frames(kicked, still, 1)
	var kick: float = (_posed["kicked:spine"] as Quaternion).angle_to(_posed["still:spine"] as Quaternion)
	_check(kick > deg_to_rad(1.5), "%s: a shot kicks the trunk back (%.1f deg)" % [class_id, rad_to_deg(kick)])
	# Back is the body's +Z: the kicked spine's up vector must lean further towards it than the still one.
	var back: Vector3 = kicked.global_basis.z
	var lean_kicked: float = (_posed["kicked:lean"] as Vector3).dot(back)
	var lean_still: float = (_posed["still:lean"] as Vector3).dot(back)
	_check(lean_kicked > lean_still + 0.01, "%s: the kick leans the trunk back, away from the aim" % class_id)
	_check((_posed["kicked:thigh"] as Quaternion).is_equal_approx(_posed["still:thigh"] as Quaternion), "%s: the kick leaves the legs alone" % class_id)
	await _frames(kicked, still, 36)
	_check(float(kicked.get("_kick")) < 0.0005, "%s: the kick fades out on its own" % class_id)
	kicked.free()
	still.free()

	var dashing := SoldierModel.create(class_id)
	root.add_child(dashing)
	await process_frame
	dashing.recoil()
	dashing.animate(0.0, 0.0, false, DT)
	await process_frame
	var dashing_rig: Object = dashing.get("_rig")
	dashing.set_dashing(true)
	_check(float(dashing.get("_kick")) == 0.0 and float(dashing_rig.get("kick")) == 0.0, "%s: a dash clears a kick under way, in the rig too" % class_id)
	dashing.recoil()
	_check(float(dashing.get("_kick")) == 0.0, "%s: a dashing body takes no kick" % class_id)
	dashing.free()

	var dead := SoldierModel.create(class_id)
	root.add_child(dead)
	await process_frame
	dead.recoil()
	dead.animate(0.0, 0.0, false, DT)
	await process_frame
	var dead_rig: Object = dead.get("_rig")
	dead.die()
	_check(float(dead.get("_kick")) == 0.0 and float(dead_rig.get("kick")) == 0.0, "%s: a death clears a kick under way, in the rig too" % class_id)
	dead.recoil()
	_check(float(dead.get("_kick")) == 0.0, "%s: a dead body takes no kick" % class_id)
	dead.free()


## Both models take the same frames; each frame ends with the modifiers having posed the skeleton.
func _frames(a: SoldierModel, b: SoldierModel, frames: int) -> void:
	for i in frames:
		a.animate(0.0, 0.0, false, DT)
		b.animate(0.0, 0.0, false, DT)
		await process_frame


## The pose the modifiers give a skeleton on its update (see test_recruit_animation.gd). The lean is
## the spine's up vector in the world.
func _record_pose(skeleton: Skeleton3D, key: String, spine: int, thigh: int) -> void:
	_posed[key + ":spine"] = skeleton.get_bone_pose_rotation(spine)
	_posed[key + ":thigh"] = skeleton.get_bone_pose_rotation(thigh)
	_posed[key + ":lean"] = (skeleton.global_basis * skeleton.get_bone_global_pose(spine).basis.y).normalized()
