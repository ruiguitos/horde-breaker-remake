extends SkeletonModifier3D
## Delivered two-hand pose, cached once and layered over locomotion.

const POSE_FILE: String = "res://assets/models/characters/recruit/recruit_rifle_hold.json"
var _bones: PackedInt32Array = PackedInt32Array()
var _rotations: Array[Quaternion] = []
var _positions: Array[Vector3] = []


func _ready() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	var pose: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POSE_FILE))
	for bone: String in pose:
		var index: int = skeleton.find_bone(bone)
		if index < 0:
			continue
		var rest: Transform3D = skeleton.get_bone_rest(index)
		var values: Array = pose[bone]["quaternion_xyzw"]
		var delta := Quaternion(values[0], values[1], values[2], values[3]).normalized()
		var position: Array = pose[bone]["location"]
		_bones.append(index)
		_rotations.append((rest.basis.get_rotation_quaternion() * delta).normalized())
		_positions.append(rest.origin + rest.basis * Vector3(position[0], position[1], position[2]))


func _process_modification() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	for i in _bones.size():
		skeleton.set_bone_pose_rotation(_bones[i], _rotations[i])
		skeleton.set_bone_pose_position(_bones[i], _positions[i])
