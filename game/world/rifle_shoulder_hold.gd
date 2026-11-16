extends SkeletonModifier3D
## Shoulders the long gun (third person): after the delivered two-hand pose, moves the right
## hand so the end of the stock sits in the right shoulder pocket instead of the middle of the
## chest, keeping the hand's orientation (the barrel still points where the pose put it). The
## right arm turns by two-bone IK; no bone is stretched. WeaponSupportHold then puts the left
## palm on the gun, and the LocomotionRig aims both arms together.
## Measured before (tools/dev/measure_hold.gd): stock end 20 cm left of the right shoulder,
## 13 cm below it, against the sternum; now 4 cm below the shoulder line, right of centre.

## The pocket, from the right shoulder joint: towards the neck, down and forward (metres).
## The blocky soldier's arms are short: with the stock right in the shoulder the left hand
## cannot reach a long gun's handguard (measured: 4 to 18 cm short at real size). These values
## put the stock high, just right of the chest's centre, where both hands reach (measure_hold.gd).
var inward: float = 0.16
var down: float = 0.05
var forward: float = -0.03

var weapon: WeaponModel
var grip_from_hand := Transform3D.IDENTITY
var residual: float = 0.0  ## metres the stock end missed the pocket in the last pose (tests)
var _upper: int = -1
var _forearm: int = -1
var _hand: int = -1
var _upper_left: int = -1


func _ready() -> void:
	var skeleton: Skeleton3D = get_skeleton()
	_upper = skeleton.find_bone("DEF-upper_arm.R")
	_forearm = skeleton.find_bone("DEF-forearm.R")
	_hand = skeleton.find_bone("DEF-hand.R")
	_upper_left = skeleton.find_bone("DEF-upper_arm.L")


## Where the stock ends, in skeleton space, for the current pose.
func butt(skeleton: Skeleton3D) -> Vector3:
	var stock: float = weapon.length + weapon.muzzle.position.z  # behind the grip
	return skeleton.get_bone_global_pose(_hand) * grip_from_hand * (weapon.basis * Vector3(0, 0, stock))


## The pocket in skeleton space: the right shoulder joint moved towards the neck, down and
## forward along the barrel's level direction.
func pocket(skeleton: Skeleton3D) -> Vector3:
	var right: Vector3 = skeleton.get_bone_global_pose(_upper).origin
	var left: Vector3 = skeleton.get_bone_global_pose(_upper_left).origin
	var hand: Transform3D = skeleton.get_bone_global_pose(_hand)
	var barrel: Vector3 = (hand.basis * grip_from_hand.basis * (weapon.basis * Vector3.FORWARD))
	barrel.y = 0.0
	barrel = barrel.normalized() if barrel.length_squared() > 0.0001 else Vector3.FORWARD
	return right + (left - right).normalized() * inward + Vector3.DOWN * down + barrel * forward


func _process_modification() -> void:
	if not is_instance_valid(weapon) or weapon.muzzle == null or mini(mini(_upper, _forearm), mini(_hand, _upper_left)) < 0:
		return
	var skeleton: Skeleton3D = get_skeleton()
	var delta: Vector3 = pocket(skeleton) - butt(skeleton)
	var shoulder: Vector3 = skeleton.get_bone_global_pose(_upper).origin
	var elbow: Vector3 = skeleton.get_bone_global_pose(_forearm).origin
	var wrist: Transform3D = skeleton.get_bone_global_pose(_hand)
	var hand_basis: Basis = wrist.basis.orthonormalized()
	var offset: Vector3 = wrist.origin + delta - shoulder
	if offset.length_squared() < 0.000001:
		return
	var upper_length: float = shoulder.distance_to(elbow)
	var forearm_length: float = elbow.distance_to(wrist.origin)
	var distance: float = clampf(offset.length(), absf(upper_length - forearm_length) + 0.0001, upper_length + forearm_length - 0.0001)
	var direction: Vector3 = offset.normalized()
	var bend: Vector3 = elbow - shoulder
	bend -= direction * bend.dot(direction)
	if bend.length_squared() < 0.000001:
		bend = direction.cross(Vector3.UP)
	var along: float = (upper_length * upper_length - forearm_length * forearm_length + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(upper_length * upper_length - along * along, 0.0))
	var elbow_target: Vector3 = shoulder + direction * along + bend.normalized() * height
	_rotate_towards(skeleton, _upper, elbow - shoulder, elbow_target - shoulder)
	elbow = skeleton.get_bone_global_pose(_forearm).origin
	var actual_wrist: Vector3 = skeleton.get_bone_global_pose(_hand).origin
	_rotate_towards(skeleton, _forearm, actual_wrist - elbow, shoulder + direction * distance - elbow)
	# The hand keeps its global orientation, so the gun keeps pointing where it did.
	var parent: int = skeleton.get_bone_parent(_hand)
	var local_basis: Basis = skeleton.get_bone_global_pose(parent).basis.orthonormalized().inverse() * hand_basis
	skeleton.set_bone_pose_rotation(_hand, local_basis.get_rotation_quaternion().normalized())
	residual = pocket(skeleton).distance_to(butt(skeleton))


func _rotate_towards(skeleton: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var global_basis: Basis = skeleton.get_bone_global_pose(bone).basis.orthonormalized()
	var rotation := Basis(Quaternion(from.normalized(), to.normalized()))
	var local_delta: Basis = global_basis.inverse() * rotation * global_basis
	var pose: Quaternion = skeleton.get_bone_pose_rotation(bone)
	skeleton.set_bone_pose_rotation(bone, (pose * local_delta.get_rotation_quaternion()).normalized())
