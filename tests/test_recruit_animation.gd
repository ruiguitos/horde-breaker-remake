extends SceneTree
## Both delivered contractor rigs must be active, not just imported.

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	for class_id: StringName in [&"recruit", &"vanguard"]:
		await _test_soldier(class_id)
	var preview := ClassPreview.create(&"vanguard")
	preview.size = Vector2(320, 420)
	root.add_child(preview)
	await process_frame
	var model: SoldierModel = preview.get("_model")
	var player: AnimationPlayer = model.find_child("VanguardAnimationPlayer", true, false)
	_check(model.uses_skeleton() and player != null, "Armory previews the same Vanguard rig used in the game")
	if player != null:
		var before: float = player.current_animation_position
		await process_frame
		await process_frame
		_check(player.current_animation_position > before, "Armory advances the delivered idle animation")
	preview.free()
	quit(0 if _failures == 0 else 1)


func _test_soldier(class_id: StringName) -> void:
	var soldier := SoldierModel.create(class_id)
	root.add_child(soldier)
	await process_frame
	var skeleton: Skeleton3D = soldier.find_child("Skeleton3D", true, false)
	var player: AnimationPlayer = soldier.find_child(String(class_id).capitalize() + "AnimationPlayer", true, false)
	_check(skeleton != null and skeleton.get_bone_count() == 53 and player != null, String(class_id) + " uses the delivered 53-bone rig and an animation player")
	if skeleton == null or player == null:
		soldier.free()
		return
	_check(player.current_animation == "UAL/Idle_Loop", String(class_id) + " starts in the rifle-hold idle pose")
	_check(player.get_animation_list().size() == 46 and (soldier.get("_model") as Node).find_children("*", "MeshInstance3D", true, false).size() == 104,
		"Delivered 46 clips and 104 rigid pieces remain intact")
	soldier.call("animate", 1.0, 0.1, false, 0.1)
	_check(player.current_animation == "UAL/Walk_Loop", "Movement selects Walk")
	soldier.call("animate", 1.0, 0.2, true, 0.1)
	_check(player.current_animation == "UAL/Sprint_Loop", "Sprint selects the delivered Sprint clip")
	soldier.call("animate", 0.0, 0.3, false, 0.1)
	_check(player.current_animation == "UAL/Idle_Loop", "Stopping returns to Idle")
	var before: float = player.current_animation_position
	soldier.call("animate", 0.0, 0.4, false, 0.0)
	_check(is_equal_approx(player.current_animation_position, before), "Zero animation delta freezes the pose for pause and level-up")
	for id: StringName in [&"shotgun", &"smg", &"machine_gun", &"marksman", &"rifle"]:
		soldier.set_weapon(id)
		await process_frame
		_check(soldier.muzzle != null and soldier.muzzle.is_inside_tree(), String(id) + " has a live muzzle on the animated hand")
		var rifle_visible: bool = (soldier.find_child("Rifle_Barrel", true, false) as MeshInstance3D).visible
		_check(rifle_visible == (id == &"rifle"), String(id) + " shows only its equipped weapon")
		soldier.set_shadow_only(true)
		_check(soldier.find_children("*", "MeshInstance3D", true, false).all(func(n: Node) -> bool:
			return (n as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), String(id) + " stays shadow-only in first person")
	soldier.set_shadow_only(false)
	var hand: int = skeleton.find_bone("DEF-hand.R")
	var foot: int = skeleton.find_bone("DEF-foot.L")
	var muzzle_check: Array = [0, 0.0]
	var support_check: Array = [0.0]
	# Inspect the final modified pose before Godot restores the animation input.
	skeleton.skeleton_updated.connect(func() -> void:
		var expected: Transform3D = skeleton.global_transform * skeleton.get_bone_global_pose(hand) * soldier.muzzle.transform
		muzzle_check[0] += 1
		muzzle_check[1] = maxf(muzzle_check[1], soldier.muzzle.global_position.distance_to(expected.origin))
		# Contact offsets supplied by both deliveries' rig_validation.json.
		var left: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("DEF-hand.L"))
		var right: Transform3D = skeleton.get_bone_global_pose(hand)
		var palm: Vector3 = left * Vector3(0.000000342, 0.07845914, -0.000000016)
		var foregrip: Vector3 = right * Vector3(0.05442105, 0.13151488, 0.358172)
		support_check[0] = maxf(support_check[0], palm.distance_to(foregrip)))
	soldier.call("animate", 1.0, 1.0, false, 0.1)
	await process_frame
	var foot_before: Transform3D = skeleton.get_bone_global_pose(foot)
	soldier.call("animate", 1.0, 1.3, false, 0.3)
	await process_frame
	_check(not skeleton.get_bone_global_pose(foot).is_equal_approx(foot_before), "Walk moves the actual skeleton bones")
	var attachment: BoneAttachment3D = soldier.muzzle.get_parent()
	_check(muzzle_check[0] > 0 and muzzle_check[1] < 0.002 and attachment.bone_name == &"DEF-hand.R", "Rifle muzzle follows the animated right hand")
	_check(support_check[0] < 0.002, "Left hand stays on the delivered rifle foregrip")
	_check((-soldier.muzzle.global_basis.z).dot(Vector3.FORWARD) > 0.0, "Held rifle remains facing forward")
	soldier.free()

