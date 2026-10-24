extends SceneTree
## Both delivered contractor rigs must be active, not just imported, and
## their locomotion must match the body's motion (docs/tech/LOCOMOTION.md):
## gait and playback rate from the measured speed, backpedal / strafe from
## the direction, the rifle on the aim, planted feet that do not slide.

const DT: float = 1.0 / 60.0
const WALK: float = 6.0  ## GameData.PLAYER_SPEED
const SPRINT: float = 9.6  ## x GameData.SPRINT_MULTIPLIER

var _failures: int = 0
## Filled from skeleton_updated (the final, modified pose).
var _probe: Dictionary = {}


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	for class_id: StringName in [&"recruit", &"vanguard"]:
		await _test_soldier(class_id)
		await _test_aim_layer(class_id)
	await _test_locomotion(&"recruit")
	var preview := ClassPreview.create(&"vanguard")
	preview.size = Vector2(320, 420)
	root.add_child(preview)
	await process_frame
	var model: SoldierModel = preview.get("_model")
	var tree: AnimationTree = model.find_child("VanguardAnimationTree", true, false)
	_check(model.uses_skeleton() and tree != null, "Armory previews the same Vanguard rig used in the game")
	if tree != null:
		var skeleton: Skeleton3D = model.find_child("Skeleton3D", true, false)
		var spine: int = skeleton.find_bone("DEF-spine.003")
		var before: Quaternion = skeleton.get_bone_pose_rotation(spine)
		for i in 20:
			await process_frame
		_check(not skeleton.get_bone_pose_rotation(spine).is_equal_approx(before), "Armory advances the delivered idle animation")
		_check(absf(float(model.debug_state().legs_offset)) < 10.0, "The Armory turntable does not twist the legs")
	preview.free()
	quit(0 if _failures == 0 else 1)


## One island frame as island.gd does it: animate, then place the model.
func _drive(soldier: SoldierModel, velocity: Vector3, facing: Vector3, frames: int, sprint: bool = false) -> void:
	for i in frames:
		soldier.animate(1.0, 0.0, sprint, DT)
		soldier.position += velocity * DT
		soldier.basis = Basis.looking_at(facing, Vector3.UP)
		await process_frame


func _watch(soldier: SoldierModel, skeleton: Skeleton3D) -> void:
	_probe = {"soldier": soldier, "skeleton": skeleton, "last": [], "num": 0.0, "den": 0.0, "pitch": 0.0, "yaw": 0.0}
	if not skeleton.skeleton_updated.is_connected(_on_skeleton_updated):
		skeleton.skeleton_updated.connect(_on_skeleton_updated)


func _reset_probe() -> void:
	for key in ["num", "den", "pitch", "yaw"]:
		_probe[key] = 0.0
	_probe["last"] = []


## Planted feet's world speed (toe and heel points within 4 cm of the
## ground, weighted by how close) and the barrel's worst error vs facing.
func _on_skeleton_updated() -> void:
	var soldier: SoldierModel = _probe.get("soldier")
	var skeleton: Skeleton3D = _probe.get("skeleton")
	if soldier == null or skeleton == null or not is_instance_valid(soldier):
		return
	var xf: Transform3D = skeleton.global_transform
	var points: Array[Vector3] = []
	for bone in ["DEF-foot.L", "DEF-toe.L", "DEF-foot.R", "DEF-toe.R"]:
		var p: Vector3 = xf * skeleton.get_bone_global_pose(skeleton.find_bone(bone)).origin
		points.append(p - Vector3(0, 0.205, 0) if bone.begins_with("DEF-foot") else p)
	var last: Array = _probe["last"]
	if last.size() == points.size():
		for k in points.size():
			var h: float = ((points[k] as Vector3).y + (last[k] as Vector3).y) * 0.5 - soldier.global_position.y
			var w: float = clampf((0.04 - h) / 0.04, 0.0, 1.0)
			var d: Vector3 = points[k] - (last[k] as Vector3)
			_probe["num"] = float(_probe["num"]) + w * Vector2(d.x, d.z).length() / DT
			_probe["den"] = float(_probe["den"]) + w
	_probe["last"] = points
	_probe["hand_r"] = soldier.global_transform.affine_inverse() * (xf * skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.R")).origin)
	var gun: Node = soldier.get("_gun_node")
	var tip: Node3D = gun.get("muzzle") if gun != null else soldier.muzzle
	var barrel: Vector3 = -tip.global_basis.z.normalized()
	var facing: Vector3 = -soldier.global_basis.z
	_probe["pitch"] = maxf(float(_probe["pitch"]), absf(rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0)))))
	_probe["yaw"] = maxf(float(_probe["yaw"]), absf(rad_to_deg(Vector2(facing.x, facing.z).angle_to(Vector2(barrel.x, barrel.z)))))


func _slide() -> float:
	return float(_probe["num"]) / maxf(float(_probe["den"]), 0.0001)


func _test_locomotion(class_id: StringName) -> void:
	var soldier := SoldierModel.create(class_id)
	root.add_child(soldier)
	soldier.position = Vector3(20, 0, 20)
	await process_frame
	var skeleton: Skeleton3D = soldier.find_child("Skeleton3D", true, false)
	_watch(soldier, skeleton)
	var fwd := Vector3(0, 0, -1)
	await _drive(soldier, Vector3.ZERO, fwd, 5)
	_check(float(soldier.debug_state().move) < 0.01, "Standing still stays in Idle")
	# The UAL clips step with the same foot at the same phase.
	var tree: AnimationTree = soldier.get("_tree")
	var aligned: bool = true
	for g in [0.0, 1.0, 2.0]:
		tree.set(&"parameters/gait/blend_position", g)
		tree.set(&"parameters/move/blend_amount", 1.0)
		tree.set(&"parameters/rate/scale", 1.0)
		var best: Array = [-INF, 0.0]
		for k in 20:
			tree.advance(0.0 if k == 0 else 0.05)
			var lead: float = skeleton.get_bone_global_pose(skeleton.find_bone("DEF-foot.L")).origin.z - skeleton.get_bone_global_pose(skeleton.find_bone("DEF-foot.R")).origin.z
			var phase: float = fposmod(0.05 * k, 1.0)
			if lead > best[0]:
				best = [lead, phase]
		tree.set(&"parameters/rate/scale", -1.0)
		tree.advance(0.95)  # back to phase 0
		aligned = aligned and (float(best[1]) < 0.06 or float(best[1]) > 0.94)
	_check(aligned, "Walk, Jog and Sprint lead with the left foot at the same phase")
	# Forward at walking speed: Jog at playback 1 (6 m/s is the clip's speed).
	await _drive(soldier, fwd * WALK, fwd, 40)
	_reset_probe()
	await _drive(soldier, fwd * WALK, fwd, 60)
	var d: Dictionary = soldier.debug_state()
	_check(absf(float(d.gait) - 1.0) < 0.05 and not bool(d.backward), "6 m/s forward plays the Jog clip (gait %.2f)" % float(d.gait))
	_check(absf(float(d.rate) * SoldierModel.gait_stride(float(d.gait)) - WALK) < 0.3, "Playback rate x stride = body speed (%.2f cycles/s)" % float(d.rate))
	_check(_slide() < 1.0, "Planted feet barely slide walking forward (%.2f m/s; the old Walk clip slid 5.2)" % _slide())
	_check(float(_probe.yaw) < 2.0 and float(_probe.pitch) < 2.0, "The rifle points along the facing, level (yaw %.1f, pitch %.1f deg)" % [float(_probe.yaw), float(_probe.pitch)])
	# Slower (a fuel can, x0.8): the rate follows the speed.
	await _drive(soldier, fwd * WALK * 0.8, fwd, 60)
	d = soldier.debug_state()
	_check(absf(float(d.rate) * SoldierModel.gait_stride(float(d.gait)) - WALK * 0.8) < 0.3, "Playback rate scales with a slower speed (%.2f cycles/s)" % float(d.rate))
	# Backpedal: the forward cycle played backwards, hips still on the aim.
	await _drive(soldier, -fwd * WALK, fwd, 40)
	_reset_probe()
	await _drive(soldier, -fwd * WALK, fwd, 60)
	d = soldier.debug_state()
	_check(bool(d.backward) and float(d.rate) < 0.0 and absf(float(d.legs_offset)) < 10.0, "Moving away from the aim backpedals (rate %.2f, legs %+.0f deg)" % [float(d.rate), float(d.legs_offset)])
	_check(_slide() < 1.0, "Planted feet barely slide backpedalling (%.2f m/s; was 6.8)" % _slide())
	# Strafe right: the hips turn to the movement, the chest stays on the aim.
	await _drive(soldier, Vector3.RIGHT * WALK, fwd, 40)
	_reset_probe()
	await _drive(soldier, Vector3.RIGHT * WALK, fwd, 60)
	d = soldier.debug_state()
	_check(not bool(d.backward) and absf(float(d.legs_offset) + 90.0) < 10.0, "Strafing right turns the legs to the right (legs %+.0f deg)" % float(d.legs_offset))
	_check(_slide() < 1.0, "Planted feet barely slide strafing (%.2f m/s; was 6.1)" % _slide())
	_check(float(_probe.yaw) < 2.0 and float(_probe.pitch) < 2.0, "Strafing keeps the rifle on the aim (yaw %.1f, pitch %.1f deg)" % [float(_probe.yaw), float(_probe.pitch)])
	# Run and gun: sprinting sideways still aims level along the facing.
	await _drive(soldier, Vector3.LEFT * SPRINT, fwd, 40, true)
	_reset_probe()
	await _drive(soldier, Vector3.LEFT * SPRINT, fwd, 60, true)
	d = soldier.debug_state()
	_check(absf(float(d.gait) - 2.0) < 0.05 and absf(float(d.rate) * SoldierModel.gait_stride(float(d.gait)) - SPRINT) < 0.4, "Sprint plays the Sprint clip at the body's speed (gait %.2f, %.2f cycles/s)" % [float(d.gait), float(d.rate)])
	_check(_slide() < 1.3, "Planted feet barely slide sprinting sideways (%.2f m/s; was 12.9)" % _slide())
	_check(float(_probe.yaw) < 2.0 and float(_probe.pitch) < 2.0, "Sprinting keeps the rifle level on the aim (yaw %.1f, pitch %.1f deg; was 48 / 54)" % [float(_probe.yaw), float(_probe.pitch)])
	# Stop: back to Idle.
	await _drive(soldier, Vector3.ZERO, fwd, 30)
	_check(float(soldier.debug_state().move) < 0.05, "Stopping returns to Idle")
	# Turn in place: the legs hold, then swivel round to the new facing.
	await _drive(soldier, Vector3.ZERO, Vector3.RIGHT, 2)
	var twisted: float = absf(float(soldier.debug_state().legs_offset))
	await _drive(soldier, Vector3.ZERO, Vector3.RIGHT, 40)
	_check(twisted > 45.0 and absf(float(soldier.debug_state().legs_offset)) < 5.0, "A quick turn twists the hips first, then the legs catch up (%.0f deg)" % twisted)
	# A fuel can in the right hand: the gun moves to the left hand.
	soldier.carrying = true
	await _drive(soldier, fwd * WALK * 0.8, fwd, 40)
	var mount: Node3D = soldier.get("_gun_mount")
	var hand_local: Vector3 = _probe.get("hand_r", Vector3.ZERO)
	_check(mount.get_parent().name == &"LeftHand", "Carrying a can moves the gun to the left hand")
	_check(hand_local.distance_to(SoldierModel.CARRY_HAND) < 0.2, "The right hand reaches down to the can's handle (%.2f m off)" % hand_local.distance_to(SoldierModel.CARRY_HAND))
	soldier.carrying = false
	await _drive(soldier, fwd * WALK, fwd, 30)
	var returned_attachment := mount.get_parent() as BoneAttachment3D
	_check(returned_attachment != null and returned_attachment.bone_name == &"DEF-hand.R", "Putting the can down gives the gun back to the right hand")
	# Pause / level-up: zero delta freezes the pose.
	var foot: int = skeleton.find_bone("DEF-foot.L")
	var frozen: Quaternion = skeleton.get_bone_pose_rotation(foot)
	soldier.animate(0.0, 0.0, false, 0.0)
	await process_frame
	_check(skeleton.get_bone_pose_rotation(foot).is_equal_approx(frozen), "Zero animation delta freezes the pose for pause and level-up")
	skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
	_probe = {}
	soldier.free()


## The aim pose sits on the trunk only: aiming up or down bends the trunk, and the legs
## stay where the locomotion puts them. The barrel pitch maps to the blend, clamped past the limits.
func _test_aim_layer(class_id: StringName) -> void:
	_check(SoldierModel.aim_position(0.0) == 0.0 and SoldierModel.aim_position(SoldierModel.AIM_UP_MAX) == 1.0 and SoldierModel.aim_position(-SoldierModel.AIM_DOWN_MAX) == -1.0 and SoldierModel.aim_position(1.0) == 1.0 and SoldierModel.aim_position(-1.0) == -1.0, "%s: the aim pitch maps to the Down, Neutral and Up poses and clamps past them" % class_id)
	var probe := SoldierModel.create(class_id)
	root.add_child(probe)
	await process_frame
	var tree: AnimationTree = probe.find_child(String(class_id).capitalize() + "AnimationTree", true, false)
	var trunk := (tree.tree_root as AnimationNodeBlendTree).get_node(&"aim_trunk") as AnimationNodeBlend2
	var on_trunk: bool = true
	for bone: String in ["DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head"]:
		on_trunk = on_trunk and trunk.is_path_filtered(NodePath(".:" + bone))
	var off_trunk: bool = true
	for bone: String in ["DEF-hips", "DEF-thigh.L", "DEF-shin.R", "DEF-upper_arm.L", "DEF-hand.R"]:
		off_trunk = off_trunk and not trunk.is_path_filtered(NodePath(".:" + bone))
	_check(on_trunk and off_trunk, "%s: the aim layer moves the trunk, neck and head, and never the hips, legs or arms" % class_id)
	var aim := (tree.tree_root as AnimationNodeBlendTree).get_node(&"aim") as AnimationNodeBlendSpace1D
	var clip_at: Dictionary = {}
	for point in aim.get_blend_point_count():
		clip_at[aim.get_blend_point_position(point)] = (aim.get_blend_point_node(point) as AnimationNodeAnimation).animation
	_check(clip_at.get(-1.0) == &"UAL/Pistol_Aim_Down" and clip_at.get(0.0) == &"UAL/Pistol_Aim_Neutral" and clip_at.get(1.0) == &"UAL/Pistol_Aim_Up", "%s: Down sits at -1, Neutral at 0 and Up at +1, so the aim picks the right pose" % class_id)
	_check(trunk.filter_enabled, "%s: the aim layer is filtered, so it cannot reach the legs or the arms" % class_id)
	probe.free()
	# Two models advanced the same frames: one aims up, one down. Comparing them at one time
	# keeps the idle's own breathing out of the comparison.
	var up := SoldierModel.create(class_id)
	var down := SoldierModel.create(class_id)
	root.add_child(up)
	root.add_child(down)
	await process_frame
	up.aim_pitch = SoldierModel.AIM_UP_MAX
	down.aim_pitch = -SoldierModel.AIM_DOWN_MAX
	var up_skeleton: Skeleton3D = up.find_child("Skeleton3D", true, false)
	var down_skeleton: Skeleton3D = down.find_child("Skeleton3D", true, false)
	var spine: int = up_skeleton.find_bone("DEF-spine.002")
	var thigh: int = up_skeleton.find_bone("DEF-thigh.L")
	_posed.clear()
	up_skeleton.skeleton_updated.connect(_record_pose.bind(up_skeleton, "up", spine, thigh))
	down_skeleton.skeleton_updated.connect(_record_pose.bind(down_skeleton, "down", spine, thigh))
	await _settle(up, 30)
	await _settle(down, 30)
	var bend: float = (_posed["up:spine"] as Quaternion).angle_to(_posed["down:spine"] as Quaternion)
	_check(bend > deg_to_rad(4.0), "%s: aiming up and down bends the trunk apart (%.1f deg)" % [class_id, rad_to_deg(bend)])
	_check((_posed["up:thigh"] as Quaternion).is_equal_approx(_posed["down:thigh"] as Quaternion), "%s: the legs do not follow the aim" % class_id)
	# Walking still moves the legs under the layer: both models walk the same frames.
	var stepped: Quaternion = _posed["up:thigh"]
	await _walk(up, down, 6)
	_check((_posed["up:thigh"] as Quaternion).angle_to(stepped) > deg_to_rad(2.0), "%s: walking still moves the legs under the aim layer" % class_id)
	_check((_posed["up:thigh"] as Quaternion).is_equal_approx(_posed["down:thigh"] as Quaternion), "%s: walking, the legs match under both aims" % class_id)
	up.free()
	down.free()


var _posed: Dictionary = {}


## The pose the modifiers give a skeleton on its update: a read after an await can still be the
## pose before them, so the checks read what this recorded.
func _record_pose(skeleton: Skeleton3D, key: String, spine: int, thigh: int) -> void:
	_posed[key + ":spine"] = skeleton.get_bone_pose_rotation(spine)
	_posed[key + ":thigh"] = skeleton.get_bone_pose_rotation(thigh)


## Walks both models forward, as island.gd moves the body: the position changes and animate() reads the speed from it.
func _walk(up_model: SoldierModel, down_model: SoldierModel, frames: int) -> void:
	for i in frames:
		for model: SoldierModel in [up_model, down_model]:
			model.position += Vector3(0, 0, -6.0 / 60.0)
			model.animate(1.0, 0.0, false, 1.0 / 60.0)
		await process_frame


func _settle(soldier: SoldierModel, frames: int) -> void:
	for i in frames:
		soldier.animate(0.0, 0.0, false, 1.0 / 60.0)
		await process_frame  # the modifiers pose the skeleton at the end of the frame


func _test_soldier(class_id: StringName) -> void:
	var soldier := SoldierModel.create(class_id)
	root.add_child(soldier)
	await process_frame
	var skeleton: Skeleton3D = soldier.find_child("Skeleton3D", true, false)
	var tree: AnimationTree = soldier.find_child(String(class_id).capitalize() + "AnimationTree", true, false)
	_check(skeleton != null and skeleton.get_bone_count() == 53 and tree != null, String(class_id) + " uses the delivered 53-bone rig and an animation tree")
	if skeleton == null or tree == null:
		soldier.free()
		return
	_check(float(soldier.debug_state().move) == 0.0, String(class_id) + " starts in the rifle-hold idle pose")
	_check(tree.get_animation_list().size() == 46 and (soldier.get("_model") as Node).find_children("*", "MeshInstance3D", true, false).filter(func(n: Node) -> bool:
		return not String(n.get_path()).contains("WeaponMount")).size() == 104,
		"Delivered 46 clips and 104 rigid pieces remain intact")
	var fwd := Vector3(0, 0, -1)
	for id: StringName in [&"shotgun", &"smg", &"machine_gun", &"marksman", &"rifle"]:
		soldier.set_weapon(id)
		_watch(soldier, skeleton)
		await _drive(soldier, Vector3.ZERO, fwd, 4)
		_check(soldier.muzzle != null and soldier.muzzle.is_inside_tree(), String(id) + " has a live muzzle on the animated hand")
		_check(float(_probe.yaw) < 2.0 and float(_probe.pitch) < 2.0, String(id) + " is held level along the facing (yaw %.1f, pitch %.1f deg)" % [float(_probe.yaw), float(_probe.pitch)])
		# WeaponModel replaces the delivered rifle (its rifle copies the GLB's parts).
		var rifle_visible: bool = (soldier.find_child("Rifle_Barrel", true, false) as MeshInstance3D).visible
		var guns: Array[Node] = soldier.find_children("Weapon_*", "Node3D", true, false)
		_check(not rifle_visible and guns.size() == 1 and guns[0].name == "Weapon_" + String(id), String(id) + " shows only its equipped weapon")
		soldier.set_shadow_only(true)
		_check(soldier.find_children("*", "MeshInstance3D", true, false).all(func(n: Node) -> bool:
			return (n as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), String(id) + " stays shadow-only in first person")
	skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
	_probe = {}
	soldier.set_shadow_only(false)
	var hand: int = skeleton.find_bone("DEF-hand.R")
	var foot: int = skeleton.find_bone("DEF-foot.L")
	var muzzle_check: Array = [0, 0.0]
	var support_check: Array = [0.0]
	# Inspect the final modified pose before Godot restores the animation input.
	var probe := func() -> void:
		var local_tip := Transform3D.IDENTITY
		var node: Node3D = soldier.muzzle
		while node != null and not node is BoneAttachment3D:
			local_tip = node.transform * local_tip
			node = node.get_parent() as Node3D
		var expected: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand) * local_tip
		muzzle_check[0] += 1
		muzzle_check[1] = maxf(muzzle_check[1], soldier.muzzle.global_position.distance_to(expected.origin))
		# Palm landmark from the delivered rigs, contact from the equipped GLB.
		var left: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.L"))
		var right: Transform3D = skeleton.get_bone_global_pose(hand)
		var palm: Vector3 = left * Vector3(0.000000342, 0.07845914, -0.000000016)
		var delivered_tip: Node3D = soldier.get("_rifle_muzzle")
		var grip_from_hand: Transform3D = delivered_tip.transform * Transform3D(Basis.IDENTITY, WeaponModel.GRIP_FROM_MUZZLE)
		var held_gun: WeaponModel = soldier.get("_gun_node") as WeaponModel
		var foregrip: Vector3 = right * grip_from_hand * held_gun.support_point
		support_check[0] = maxf(support_check[0], palm.distance_to(foregrip))
	skeleton.skeleton_updated.connect(probe)
	var foot_before: Transform3D = skeleton.get_bone_global_pose(foot)
	await _drive(soldier, fwd * WALK, fwd, 20)
	_check(not skeleton.get_bone_global_pose(foot).is_equal_approx(foot_before), "Walk moves the actual skeleton bones")
	await _drive(soldier, Vector3.RIGHT * WALK, fwd, 20, true)
	var attachment: Node = soldier.muzzle
	while attachment != null and not attachment is BoneAttachment3D:
		attachment = attachment.get_parent()
	_check(muzzle_check[0] > 0 and muzzle_check[1] < 0.002 and attachment.bone_name == &"DEF-hand.R", "Rifle muzzle follows the animated right hand")
	_check(support_check[0] < 0.002, "Left hand stays on the equipped rifle foregrip while the arms aim (%.4f m)" % support_check[0])
	_check((-soldier.muzzle.global_basis.z).dot(fwd) > cos(deg_to_rad(3.0)), "Held rifle remains facing forward")
	skeleton.skeleton_updated.disconnect(probe)
	soldier.free()
