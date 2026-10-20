extends SceneTree
## The player model's reactions (docs/tech/LOCOMOTION.md): a flinch when the
## body is hit, rate-limited; the Breaker's roll during the dash; and the death,
## which fades in, holds its last pose and switches the posing rig off.
## Run: godot --headless --path . --script res://tests/test_soldier_reactions.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


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
