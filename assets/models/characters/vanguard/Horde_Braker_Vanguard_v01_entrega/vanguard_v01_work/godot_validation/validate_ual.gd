extends SceneTree

var workspace: String
var checks: Dictionary = {"errors": [], "clips": {}}
var hold_skeleton: Skeleton3D
var hold_offsets: Dictionary
var hold_contact_error := 0.0
var hold_min_forward := 1.0
var hold_callbacks := 0

func inspect_hold() -> void:
	var left := hold_skeleton.global_transform * hold_skeleton.get_bone_global_pose(hold_skeleton.find_bone("DEF-hand.L"))
	var right := hold_skeleton.global_transform * hold_skeleton.get_bone_global_pose(hold_skeleton.find_bone("DEF-hand.R"))
	var a: Array = hold_offsets.left_palm_in_left_hand
	var b: Array = hold_offsets.support_in_right_hand
	var c: Array = hold_offsets.barrel_direction_in_right_hand
	var lp := left * Vector3(a[0], a[1], a[2])
	var rp := right * Vector3(b[0], b[1], b[2])
	hold_contact_error = max(hold_contact_error, lp.distance_to(rp))
	hold_min_forward = min(hold_min_forward, (right.basis * Vector3(c[0], c[1], c[2])).normalized().dot(Vector3(0, 0, -1)))
	hold_callbacks += 1

func _initialize() -> void:
	workspace = OS.get_cmdline_user_args()[0]
	call_deferred("_run")

func require_condition(value: bool, message: String) -> void:
	if not value:
		checks.errors.append(message)
		push_error(message)

func load_glb(path: String) -> Node:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err := doc.append_from_file(path, state)
	require_condition(err == OK, "Cannot parse GLB: " + path)
	var node := doc.generate_scene(state)
	root.add_child(node)
	return node

func nodes_of_type(node: Node, kind: String, result: Array = []) -> Array:
	if node.is_class(kind):
		result.append(node)
	for child in node.get_children():
		nodes_of_type(child, kind, result)
	return result

func _run() -> void:
	var ref: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(workspace.path_join("vanguard_v01_work/UAL_skeleton_reference.json")))
	var source := load_glb(workspace.path_join("AnimationLibrary_Godot_Standard.glb"))
	var model := load_glb(workspace.path_join("Horde_Braker_Vanguard_v01_rigged.glb"))
	await process_frame
	var source_skeletons := nodes_of_type(source, "Skeleton3D", [])
	var target_skeletons := nodes_of_type(model, "Skeleton3D", [])
	require_condition(source_skeletons.size() == 1, "Source must contain one skeleton")
	require_condition(target_skeletons.size() == 1, "Vanguard must contain one skeleton")
	if source_skeletons.size() != 1 or target_skeletons.size() != 1:
		finish(); return
	var src: Skeleton3D = source_skeletons[0]
	var dst: Skeleton3D = target_skeletons[0]
	checks.godot_version = Engine.get_version_info()
	checks.source_bone_count = src.get_bone_count()
	checks.target_bone_count = dst.get_bone_count()
	checks.target_skeleton_path = str(model.get_path_to(dst))
	checks.target_skeleton_transform = str(dst.global_transform)
	require_condition(src.get_bone_count() == 53 and dst.get_bone_count() == 53, "Exact 53 bones required; got " + str(dst.get_bone_count()))
	var max_rest_angle := 0.0
	for entry in ref.bones:
		var i := dst.find_bone(entry.name)
		var j := src.find_bone(entry.name)
		require_condition(i >= 0 and j >= 0, "Missing bone " + entry.name)
		if i < 0 or j < 0:
			continue
		var parent_index := dst.get_bone_parent(i)
		var parent_name: String = "" if parent_index < 0 else str(dst.get_bone_name(parent_index))
		require_condition(parent_name == entry.parent, "Wrong parent for " + entry.name)
		var qr := src.get_bone_rest(j).basis.get_rotation_quaternion()
		var qt := dst.get_bone_rest(i).basis.get_rotation_quaternion()
		max_rest_angle = max(max_rest_angle, qr.angle_to(qt))
	checks.max_local_rest_angle_rad = max_rest_angle
	var instances := nodes_of_type(model, "MeshInstance3D", [])
	checks.mesh_count = instances.size()
	require_condition(instances.size() == 104, "Expected 104 rigid pieces")
	var material_ids: Dictionary = {}
	var rigid_vertex_count := 0
	for item: MeshInstance3D in instances:
		require_condition(item.skin != null, "Mesh has no skin: " + item.name)
		for surface in item.mesh.get_surface_count():
			var arrays: Array = item.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var stride: int = weights.size() / vertices.size()
			var single_bone := -1
			for vi in vertices.size():
				var count := 0
				for k in stride:
					var weight := weights[vi * stride + k]
					if weight > 0.00001:
						count += 1
						require_condition(abs(weight - 1.0) < 0.00001, "Weight not 1.0: " + item.name)
						var index := bones[vi * stride + k]
						if single_bone < 0:
							single_bone = index
						require_condition(index == single_bone, "Piece spans multiple bones: " + item.name)
				require_condition(count == 1, "Vertex does not have exactly one influence: " + item.name)
				rigid_vertex_count += 1
			var mat := item.mesh.surface_get_material(surface)
			material_ids[mat.get_instance_id()] = true
	checks.material_count = material_ids.size()
	checks.rigid_vertices = rigid_vertex_count
	require_condition(material_ids.size() == 35, "Expected 35 materials")
	var muzzle := model.find_child("Muzzle", true, false)
	require_condition(muzzle != null, "Missing Muzzle node")
	checks.muzzle_class = "missing" if muzzle == null else muzzle.get_class()
	checks.muzzle_parent_class = "missing" if muzzle == null else muzzle.get_parent().get_class()
	checks.muzzle_path = "missing" if muzzle == null else str(model.get_path_to(muzzle))
	if not checks.errors.is_empty():
		finish(); return
	var source_player: AnimationPlayer = nodes_of_type(source, "AnimationPlayer", [])[0]
	source_player.stop()
	var player := AnimationPlayer.new()
	dst.add_child(player)
	player.root_node = NodePath("..")
	var library := AnimationLibrary.new()
	var motion_scale: float = dst.get_bone_global_rest(dst.find_bone("DEF-hips")).origin.y / src.get_bone_global_rest(src.find_bone("DEF-hips")).origin.y
	checks.motion_scale = motion_scale
	var adapted_track_count := 0
	for clip_name: StringName in source_player.get_animation_list():
		if clip_name == &"RESET":
			continue
		var anim: Animation = source_player.get_animation(clip_name).duplicate(true)
		for track in range(anim.get_track_count() - 1, -1, -1):
			var path := anim.track_get_path(track)
			if path.get_subname_count() != 1 or dst.find_bone(path.get_subname(0)) < 0:
				anim.remove_track(track)
				continue
			var bone: String = path.get_subname(0)
			var sr := src.get_bone_rest(src.find_bone(bone))
			var tr := dst.get_bone_rest(dst.find_bone(bone))
			anim.track_set_path(track, NodePath(".:" + bone))
			var correction := tr.basis.get_rotation_quaternion() * sr.basis.get_rotation_quaternion().inverse()
			for key in anim.track_get_key_count(track):
				match anim.track_get_type(track):
					Animation.TYPE_POSITION_3D:
						var value: Vector3 = anim.track_get_key_value(track, key)
						var factor: float = motion_scale if bone == "root" or bone == "DEF-hips" else 1.0
						anim.track_set_key_value(track, key, tr.origin + (value - sr.origin) * factor)
					Animation.TYPE_ROTATION_3D:
						var value: Quaternion = anim.track_get_key_value(track, key)
						anim.track_set_key_value(track, key, (correction * value).normalized())
					Animation.TYPE_SCALE_3D:
						var value: Vector3 = anim.track_get_key_value(track, key)
						anim.track_set_key_value(track, key, tr.basis.get_scale() * value / sr.basis.get_scale())
			adapted_track_count += 1
		library.add_animation(clip_name, anim)
	player.add_animation_library(&"UAL", library)
	var save_error := ResourceSaver.save(library, workspace.path_join("Vanguard_UAL_compatible.tres"))
	require_condition(save_error == OK, "Cannot save compatible external AnimationLibrary")
	checks.clip_count = library.get_animation_list().size()
	checks.adapted_track_count = adapted_track_count
	checks.animation_names = Array(library.get_animation_list())
	var right_index := dst.find_bone("DEF-hand.R")
	var muzzle_relative: Transform3D = (dst.global_transform * dst.get_bone_global_rest(right_index)).affine_inverse() * muzzle.global_transform
	var max_muzzle_error := 0.0
	var max_scale_error := 0.0
	# Test all supplied clips at five points; Idle/Walk/Sprint at seventeen points.
	for clip_name: StringName in library.get_animation_list():
		var clip := library.get_animation(clip_name)
		var count := 17 if clip_name in [&"Idle_Loop", &"Walk_Loop", &"Sprint_Loop"] else 5
		var max_distance_from_root := 0.0
		player.play("UAL/" + str(clip_name))
		for sample in count:
			player.seek(clip.length * float(sample) / float(count - 1), true)
			dst.force_update_all_bone_transforms()
			await process_frame
			var root_position := dst.get_bone_global_pose(dst.find_bone("root")).origin
			for bi in dst.get_bone_count():
				var pose := dst.get_bone_global_pose(bi)
				require_condition(pose.origin.is_finite() and pose.basis.x.is_finite() and pose.basis.y.is_finite() and pose.basis.z.is_finite(), "Nonfinite pose in " + str(clip_name))
				max_distance_from_root = max(max_distance_from_root, pose.origin.distance_to(root_position))
				var scale := pose.basis.get_scale()
				max_scale_error = max(max_scale_error, max(abs(scale.x - 1.0), max(abs(scale.y - 1.0), abs(scale.z - 1.0))))
			var predicted := dst.global_transform * dst.get_bone_global_pose(right_index) * muzzle_relative
			max_muzzle_error = max(max_muzzle_error, predicted.origin.distance_to(muzzle.global_position))
		checks.clips[str(clip_name)] = {"samples": count, "length_s": clip.length, "max_bone_distance_from_root_m": max_distance_from_root}
	checks.maximum_muzzle_attachment_error_m = max_muzzle_error
	checks.maximum_bone_scale_error = max_scale_error
	require_condition(max_muzzle_error < 0.0001, "Muzzle detached from hand during playback")
	require_condition(max_scale_error < 0.001, "Animation stretches rigid pieces")
	# Test optional two-hand overlay in the actual engine, after AnimationPlayer.
	var loader_script := load(workspace.path_join("Vanguard_UAL_loader.gd")) as Script
	require_condition(loader_script != null and loader_script.can_instantiate(), "Loader script does not compile")
	var hold_script := load(workspace.path_join("Vanguard_Rifle_Hold.gd")) as Script
	require_condition(hold_script != null and hold_script.can_instantiate(), "Rifle hold script does not compile")
	var hold := SkeletonModifier3D.new()
	hold.set_script(hold_script)
	hold.set("pose_file", workspace.path_join("Vanguard_Rifle_Hold_pose.json"))
	hold_skeleton = dst
	hold_offsets = JSON.parse_string(FileAccess.get_file_as_string(workspace.path_join("vanguard_v01_work/rig_validation.json"))).hold_pose
	hold.modification_processed.connect(inspect_hold)
	dst.add_child(hold)
	for clip_name in ["Idle_Loop", "Walk_Loop", "Sprint_Loop"]:
		player.play("UAL/" + clip_name)
		for sample in 9:
			player.seek(library.get_animation(clip_name).length * float(sample) / 9.0, true)
			await process_frame
			await process_frame
	checks.hold_callbacks = hold_callbacks
	checks.maximum_hold_contact_error_m = hold_contact_error
	checks.minimum_hold_forward_dot = hold_min_forward
	require_condition(hold_callbacks > 0, "Rifle hold modifier did not execute")
	require_condition(hold_contact_error < 0.002, "Left hand separates from rifle foregrip")
	# The source locomotion tilts the torso, so the rifle follows that body lean.
	# Its forward component must remain -Z; horizontal aim needs separate world IK.
	require_condition(hold_min_forward > 0.0, "Held rifle points into the backward hemisphere")
	hold.queue_free()
	player.queue_free()
	await process_frame
	model.set_script(loader_script)
	model.set("animation_library", library)
	model.set("use_rifle_hold", true)
	model.call("_ready")
	await process_frame
	await process_frame
	var loader_player: AnimationPlayer = model.get("player")
	checks.loader_playback = str(loader_player.current_animation) if loader_player != null else "missing"
	require_condition(checks.loader_playback == "UAL/Idle_Loop", "Loader did not start Idle on the model")
	finish()

func finish() -> void:
	checks.passed = checks.errors.is_empty()
	var file := FileAccess.open(workspace.path_join("vanguard_v01_work/godot_validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(checks, "\t"))
	print("GODOT_VALIDATION ", JSON.stringify(checks))
	quit(0 if checks.passed else 2)
