extends SkeletonModifier3D
## Weapon-specific support palm over the delivered two-arm pose, before aim.
## Rotates the left upper arm / forearm only; never stretches bones.

const PALM_LOCAL := Vector3(0.000000342, 0.07845914, -0.000000016)
## Furthest the palm slides back along the handguard (gun metres) to stay within the arm's reach.
const MAX_SLIDE: float = 0.16
var weapon: WeaponModel
var grip_from_hand := Transform3D.IDENTITY
var slide: float = 0.0  ## gun metres the palm slid back from the support point in the last pose
var _upper: int = -1
var _forearm: int = -1
var _hand: int = -1
var _right: int = -1


func _ready() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	_upper = skeleton.find_bone("DEF-upper_arm.L")
	_forearm = skeleton.find_bone("DEF-forearm.L")
	_hand = skeleton.find_bone("DEF-hand.L")
	_right = skeleton.find_bone("DEF-hand.R")


func _process_modification() -> void:
	if not is_instance_valid(weapon) or mini(mini(_upper, _forearm), mini(_hand, _right)) < 0:
		return
	var skeleton: Skeleton3D = get_skeleton()
	var shoulder: Vector3 = skeleton.get_bone_global_pose(_upper).origin
	var elbow: Vector3 = skeleton.get_bone_global_pose(_forearm).origin
	var wrist: Transform3D = skeleton.get_bone_global_pose(_hand)
	# Preserve the delivered palm/finger orientation; solve the wrist location
	# which places that palm landmark on the new weapon's forearm.
	var hand_basis: Basis = wrist.basis.orthonormalized()
	var upper_length: float = shoulder.distance_to(elbow)
	var forearm_length: float = elbow.distance_to(wrist.origin)
	# The palm goes to the gun's support point; when the short arm cannot reach it, it slides back
	# along the handguard (gun -Z axis) by up to MAX_SLIDE, the first point it reaches.
	# weapon.basis: the gun may be drawn larger than real (SoldierModel.TP_GUN_SCALE).
	var grip: Transform3D = skeleton.get_bone_global_pose(_right) * grip_from_hand
	var target: Vector3
	slide = 0.0
	while true:
		var palm_target: Vector3 = grip * (weapon.basis * (weapon.support_point + Vector3(0, 0, slide)))
		target = palm_target - hand_basis * PALM_LOCAL
		if target.distance_to(shoulder) <= upper_length + forearm_length - 0.002 or slide >= MAX_SLIDE:
			break
		slide = minf(slide + 0.005, MAX_SLIDE)
	var offset: Vector3 = target - shoulder
	if offset.length_squared() < 0.000001:
		return
	var distance: float = clampf(offset.length(), absf(upper_length - forearm_length) + 0.0001, upper_length + forearm_length - 0.0001)
	var direction: Vector3 = offset.normalized()
	var bend: Vector3 = elbow - shoulder
	bend -= direction * bend.dot(direction)
	if bend.length_squared() < 0.000001:
		bend = direction.cross(Vector3.UP)
		if bend.length_squared() < 0.000001:
			bend = direction.cross(Vector3.RIGHT)
	var along: float = (upper_length * upper_length - forearm_length * forearm_length + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var elbow_target: Vector3 = shoulder + direction * along + bend.normalized() * height
	_rotate_towards(skeleton, _upper, elbow - shoulder, elbow_target - shoulder)
	elbow = skeleton.get_bone_global_pose(_forearm).origin
	var actual_wrist: Vector3 = skeleton.get_bone_global_pose(_hand).origin
	_rotate_towards(skeleton, _forearm, actual_wrist - elbow, shoulder + direction * distance - elbow)
	var parent: int = skeleton.get_bone_parent(_hand)
	var local_basis: Basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * hand_basis
	skeleton.set_bone_pose_rotation(_hand, local_basis.get_rotation_quaternion().normalized())


func _rotate_towards(skeleton: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var global_basis: Basis = skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	var rotation := Basis(Quaternion(from.normalized(), to.normalized()))
	var local_delta: Basis = global_basis.inverse() * rotation * global_basis
	var pose: Quaternion = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (pose * local_delta.get_rotation_quaternion()).normalized())
