extends SkeletonModifier3D
## Optional two-hand rifle hold over the UAL lower-body animation.
## Add as a child of Skeleton3D after AnimationPlayer; set influence to blend.
@export_file("*.json") var pose_file: String = "res://Recruit_Rifle_Hold_pose.json"
var _pose: Dictionary = {}

func _process_modification() -> void:
	var skeleton := get_skeleton()
	if skeleton == null:
		return
	if _pose.is_empty():
		_pose = JSON.parse_string(FileAccess.get_file_as_string(pose_file))
	for bone: String in _pose:
		var index := skeleton.find_bone(bone)
		if index < 0:
			continue
		var rest := skeleton.get_bone_rest(index)
		var values: Array = _pose[bone].quaternion_xyzw
		var delta := Quaternion(values[0], values[1], values[2], values[3]).normalized()
		var position: Array = _pose[bone].location
		var offset := Vector3(position[0], position[1], position[2])
		skeleton.set_bone_pose_rotation(index, (rest.basis.get_rotation_quaternion() * delta).normalized())
		skeleton.set_bone_pose_position(index, rest.origin + rest.basis * offset)
