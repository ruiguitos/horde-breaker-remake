extends SceneTree
## Check direct and native imports, seeking by normalized reload progress.
const BASE: String = "res://assets/models/characters/weapon_grips_original/"
var failures: int = 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("TEST FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for variant: Dictionary in [
		{"weapon": "smg", "native": false}, {"weapon": "machine_gun", "native": false},
		{"weapon": "smg", "native": true}, {"weapon": "machine_gun", "native": true},
	]:
		var weapon: String = variant["weapon"]
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var settings := ConfigFile.new()
		check(settings.load(BASE + weapon + "/arms_firstperson.glb.import") == OK, weapon + " has an import preset")
		var bake_fps: float = float(settings.get_value("params", "animation/fps", 30.0))
		check(document.append_from_file(BASE + weapon + "/arms_firstperson.glb", state) == OK, weapon + " imports")
		var scene: Node
		if variant["native"]:
			var packed := ResourceLoader.load(BASE + weapon + "/arms_firstperson.glb", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			check(packed != null, weapon + " has a native imported scene")
			if packed == null:
				continue
			scene = packed.instantiate()
		else:
			scene = document.generate_scene(state, bake_fps)
		root.add_child(scene)
		var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clip: String = "reload_mag_smg" if weapon == "smg" else "reload_mag_mg"
		check(player != null and player.has_animation(clip), weapon + " contains " + clip)
		if player == null or not player.has_animation(clip):
			scene.free()
			continue
		check(skeleton.get_bone_count() == 8, weapon + " preserves eight bones")
		var right: int = skeleton.find_bone("Hand_R")
		var left: int = skeleton.find_bone("Hand_L")
		var rest_right: Transform3D = skeleton.get_bone_global_rest(right)
		var rest_left: Transform3D = skeleton.get_bone_global_rest(left)
		var left_offset: Vector3 = rest_left.affine_inverse() * WeaponModel.SUPPORT_POINTS[StringName(weapon)]
		# The inner flat glove palm surface, distinct from the wrist/bone origin.
		var palm_rest := Vector3(0.0185, -0.025, 0.016)
		var palm_offset: Vector3 = rest_right.affine_inverse() * palm_rest
		var animation: Animation = player.get_animation(clip)
		check(player.get_animation_list().size() == 1, weapon + " contains only the requested clip")
		check(is_equal_approx(animation.length, 1.0), weapon + " normalized one-second clip")
		check(animation.loop_mode == Animation.LOOP_NONE, weapon + " does not loop")
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASE + weapon + "/grip_validation.json"))
		var contact_values: Array = report["reload_clip"]["contact_landmark_rest_gun_m"]
		var mg_contact: Vector3 = rest_right.affine_inverse() * Vector3(contact_values[0], contact_values[1], contact_values[2])
		player.play(clip)
		for step: int in 401:
			var p: float = float(step) / 400.0
			player.seek(p * animation.length, true)
			skeleton.force_update_all_bone_transforms()
			var hand: Transform3D = skeleton.get_bone_global_pose(right)
			var support: Vector3 = skeleton.get_bone_global_pose(left) * left_offset
			check(support.distance_to(WeaponModel.SUPPORT_POINTS[StringName(weapon)]) < 0.0001,
				weapon + " left palm fixed at p=" + str(p))
			if step == 0 or step == 400:
				check(hand.origin.distance_to(rest_right.origin) < 0.0001, weapon + " endpoint wrist returns to rest")
				check(hand.basis.get_rotation_quaternion().angle_to(rest_right.basis.get_rotation_quaternion()) < 0.0001,
					weapon + " endpoint hand orientation returns to rest")
				for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
					for shape: int in mesh.mesh.get_blend_shape_count():
						check(absf(mesh.get_blend_shape_value(shape)) < 0.00001, weapon + " endpoint preserves original finger grip")
			if weapon == "smg" and step == 200:
				var dropped_base := Vector3(0, -0.148, -0.143) + ViewModel.reload_offset(p)
				check((hand * palm_offset).distance_to(dropped_base) < 0.001, "SMG palm reaches dropped magazine base at p=0.50")
			if weapon == "machine_gun" and p <= 0.8:
				check(hand.origin.distance_to(rest_right.origin) < 0.0001, "MG stays on grip until p=0.80")
			if weapon == "machine_gun" and p >= 0.89 and p <= 0.95:
				var slide := Vector3(0.0455, 0.106, 0.003) + ViewModel.charge_offset(p)
				check((hand * mg_contact).distance_to(slide) < 0.001, "MG index follows the actual slide curve at %.4f (%.3f mm, bake %.0f)" % [p, (hand * mg_contact).distance_to(slide) * 1000.0, state.bake_fps])
		print("TEST: %s %s clip sampled at 401 progress values" % [weapon, "native" if variant["native"] else "direct"])
		scene.free()
	quit(0 if failures == 0 else 1)
