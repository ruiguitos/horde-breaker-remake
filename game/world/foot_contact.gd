extends SkeletonModifier3D
## Final leg-only correction: sole clearance and a bounded stance contact.
## World-space anchors reduce stance drift; swing follows source clearance.

const HEEL_DROP: float = 0.205
const CLEARANCE: float = 0.002
const PLANT_HEIGHT: float = 0.025
const RELEASE_HEIGHT: float = 0.075
const MAX_LOCK_OFFSET: float = 0.18
## A foot came down after a swing: `point` is its sole landmark in world space.
## Sent only for a contact that the rejection below keeps.
signal planted(point: Vector3)
var body: Node3D
var ground_height: Callable
var moving: bool = false
var _legs: Array[Dictionary] = []
var _tick: int = 0
var _last_tick: int = -1
var _last_body := Vector3.ZERO
var _has_last: bool = false


func _ready() -> void:
	var sk: Skeleton3D = get_skeleton()
	for side: String in ["L", "R"]:
		var leg: Dictionary = {"locked": false, "anchor": Vector3.ZERO, "toe_anchor": false, "lifted": false}
		for part: String in ["thigh", "shin", "foot", "toe"]:
			leg[part] = sk.find_bone("DEF-" + part + "." + side)
		_legs.append(leg)


## The animation clock, rather than render callbacks, owns contact state.
## Repeated skeleton updates and paused rendering cannot advance a stance.
func advance() -> void:
	_tick += 1


## The legs start over (after noclip or a flight): no stance, and no lift yet, so the
## first step after landing follows a lift.
func reset() -> void:
	for leg: Dictionary in _legs:
		leg.locked = false
		leg.lifted = false


func _height(point: Vector3) -> float:
	if ground_height.is_valid():
		var height: float = ground_height.call(point)
		if is_finite(height):
			return height
	return body.global_position.y


func _process_modification() -> void:
	if body == null or _legs.is_empty():
		return
	var sk: Skeleton3D = get_skeleton()
	var xf: Transform3D = sk.global_transform
	var fresh: bool = _tick != _last_tick
	if fresh:
		if _has_last and body.global_position.distance_to(_last_body) > 3.0:
			for leg: Dictionary in _legs:
				leg.locked = false
				leg.lifted = false  # a respawn is not a step
		_last_body = body.global_position
		_has_last = true
		_last_tick = _tick
	for leg: Dictionary in _legs:
		if mini(mini(leg.thigh, leg.shin), mini(leg.foot, leg.toe)) < 0:
			continue
		var ankle: Transform3D = sk.get_bone_global_pose(leg.foot)
		var world_ankle: Vector3 = xf * ankle.origin
		var heel: Vector3 = world_ankle - Vector3.UP * HEEL_DROP
		var toe: Vector3 = xf * sk.get_bone_global_pose(leg.toe).origin
		var heel_h: float = heel.y - _height(heel)
		var toe_h: float = toe.y - _height(toe)
		# The source clip owns stance timing. Sampling height above the terrain
		# here would plant an uphill swing early and drag it along the slope.
		var sole_h: float = minf(heel.y, toe.y) - body.global_position.y
		# A footstep is a plant after the foot was lifted; a re-anchor while it stays down is not.
		var strike: bool = false
		if fresh:
			var landmark: Vector3 = toe if leg.toe_anchor else heel
			var offset: Vector3 = landmark - (leg.anchor as Vector3)
			offset.y = 0.0
			if not moving or sole_h > RELEASE_HEIGHT or offset.length() > MAX_LOCK_OFFSET:
				leg.locked = false
			if moving and not leg.locked and sole_h <= PLANT_HEIGHT:
				leg.toe_anchor = toe_h < heel_h
				leg.anchor = toe if leg.toe_anchor else heel
				leg.locked = true
				strike = leg.lifted
			if sole_h > RELEASE_HEIGHT:
				leg.lifted = true
		var correction := Vector3.ZERO
		if leg.locked:
			var landmark: Vector3 = toe if leg.toe_anchor else heel
			var weight: float = clampf((RELEASE_HEIGHT - sole_h) / (RELEASE_HEIGHT - PLANT_HEIGHT), 0.0, 1.0)
			correction = ((leg.anchor as Vector3) - landmark) * weight
			correction.y = 0.0
		# Warp the whole swing trajectory onto the local terrain, preserving
		# its clearance and timing. Both sole endpoints must clear the surface.
		var clearance: float = maxf(sole_h, CLEARANCE)
		correction.y = maxf(_height(heel + correction) + clearance - heel.y,
			_height(toe + correction) + clearance - toe.y)
		# Reject distant ground (noclip/cliffs); IK is a small visual correction.
		if absf(correction.y) > 0.22:
			leg.locked = false
			continue
		if strike:
			leg.lifted = false
			planted.emit(leg.anchor as Vector3)
		_solve(sk, leg, xf.affine_inverse() * (world_ankle + correction), ankle.basis.orthonormalized())


func _solve(sk: Skeleton3D, leg: Dictionary, target: Vector3, foot_basis: Basis) -> void:
	var hip: Vector3 = sk.get_bone_global_pose(leg.thigh).origin
	var knee: Vector3 = sk.get_bone_global_pose(leg.shin).origin
	var ankle: Vector3 = sk.get_bone_global_pose(leg.foot).origin
	var upper: float = hip.distance_to(knee)
	var lower: float = knee.distance_to(ankle)
	var offset: Vector3 = target - hip
	if offset.length_squared() < 0.000001:
		return
	var distance: float = clampf(offset.length(), absf(upper - lower) + 0.0001, upper + lower - 0.0001)
	var direction: Vector3 = offset.normalized()
	var bend: Vector3 = knee - hip
	bend -= direction * bend.dot(direction)
	if bend.length_squared() < 0.000001:
		bend = foot_basis * Vector3.FORWARD
		bend -= direction * bend.dot(direction)
	var along: float = (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height: float = sqrt(maxf(upper * upper - along * along, 0.0))
	var knee_target: Vector3 = hip + direction * along + bend.normalized() * height
	_rotate(sk, leg.thigh, knee - hip, knee_target - hip)
	knee = sk.get_bone_global_pose(leg.shin).origin
	ankle = sk.get_bone_global_pose(leg.foot).origin
	_rotate(sk, leg.shin, ankle - knee, hip + direction * distance - knee)
	var parent_basis: Basis = sk.get_bone_global_pose(sk.get_bone_parent(leg.foot)).basis.orthonormalized()
	sk.set_bone_pose_rotation(leg.foot, (parent_basis.inverse() * foot_basis).get_rotation_quaternion().normalized())


func _rotate(sk: Skeleton3D, bone: int, from: Vector3, to: Vector3) -> void:
	if from.length_squared() < 0.000001 or to.length_squared() < 0.000001:
		return
	var basis: Basis = sk.get_bone_global_pose(bone).basis.orthonormalized()
	var local_delta: Basis = basis.inverse() * Basis(Quaternion(from.normalized(), to.normalized())) * basis
	sk.set_bone_pose_rotation(bone, (sk.get_bone_pose_rotation(bone) * local_delta.get_rotation_quaternion()).normalized())
