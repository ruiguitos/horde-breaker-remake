class_name SoldierModel
extends Node3D
## Delivered Recruit v03 and Vanguard v01 rigs with UAL locomotion.
## Both face -Z, expose an equipped muzzle and support first-person shadows.
##
## Locomotion (docs/tech/LOCOMOTION.md): the model measures its own ground
## velocity from frame to frame, so island.gd only places it. The legs play
## Walk / Jog / Sprint phase-locked and as fast as the body really moves (no
## reduced foot sliding); the hips turn towards the movement (strafe) or play the
## cycle backwards (backpedal), while the spine turns back so the rifle keeps
## pointing where the soldier aims (the body's facing, level).

const RECRUIT_MODEL: String = "res://assets/models/characters/recruit/recruit_v03.glb"
const RECRUIT_ANIMATIONS: String = "res://assets/models/characters/recruit/recruit_animations.tres"
const VANGUARD_MODEL: String = "res://assets/models/characters/vanguard/vanguard_v01.glb"
const VANGUARD_ANIMATIONS: String = "res://assets/models/characters/vanguard/vanguard_animations.tres"
const VANGUARD_HOLD: String = "res://assets/models/characters/vanguard/vanguard_rifle_hold.json"
const HIP_Y: float = 0.92
const SHOULDER_Y: float = 1.52

## The UAL locomotion clips: ground speed at playback 1 (m/s, where the
## planted feet stand still), clip length (s) and the phase (0..1) where the
## left foot is furthest ahead of the right, so all three step with the same
## foot at the same phase. Measured with tools/dev/locomotion_preview.gd -- calibrate
## (both rigs give the same numbers).
const GAITS: Array = [
	{"clip": &"UAL/Walk_Loop", "speed": 1.0, "length": 1.3333334, "phase": 0.0},
	{"clip": &"UAL/Jog_Fwd_Loop", "speed": 6.0, "length": 0.93333334, "phase": 0.95},
	{"clip": &"UAL/Sprint_Loop", "speed": 8.75, "length": 0.6666667, "phase": 0.85},
]
const IDLE_CLIP: StringName = &"UAL/Idle_Loop"
const MOVE_MIN: float = 0.35  ## m/s: slower than this is standing
const TELEPORT: float = 3.0  ## m in one frame: a respawn, not a step
const VELOCITY_SMOOTH: float = 18.0  ## 1/s, measured velocity filter
const MOVE_SMOOTH: float = 12.0  ## 1/s, idle <-> moving blend
const GAIT_SMOOTH: float = 8.0  ## 1/s, walk / jog / sprint blend
const LEGS_SMOOTH: float = 12.0  ## 1/s, hips turning towards the movement
const LEGS_MAX: float = deg_to_rad(100.0)  ## hips vs aim, at most
const BACKPEDAL_ENTER: float = deg_to_rad(110.0)  ## movement vs aim (a pure strafe stays forward)
const BACKPEDAL_EXIT: float = deg_to_rad(95.0)
const TURN_STEP_START: float = deg_to_rad(50.0)  ## standing: legs catch up past this
const TURN_STEP_SPEED: float = deg_to_rad(420.0)  ## rad/s while catching up
const LEGS_DRIFT: float = deg_to_rad(90.0)  ## rad/s, small turns follow smoothly
const MAX_CYCLES: float = 2.2  ## cycles/s cap (the Breaker dash is ~20 m/s)
## A carried fuel can's handle in the soldier's space: island.gd hangs the
## can at CARRY_OFFSET (0.38, 0.25, 0.05) and the can is 0.5 m tall.
const CARRY_HAND := Vector3(0.36, 0.8, 0.05)

const PALETTES: Dictionary = {
	&"recruit": {
		"cloth": Color(0.4, 0.37, 0.28), "armor": Color(0.66, 0.61, 0.47),
		"dark": Color(0.2, 0.2, 0.18), "visor": Color(0.06, 0.07, 0.08),
		"gun": Color(0.14, 0.14, 0.14), "skin": Color(0.78, 0.62, 0.5),
	},
	&"vanguard": {
		"cloth": Color(0.19, 0.21, 0.19), "armor": Color(0.4, 0.44, 0.34),
		"dark": Color(0.13, 0.14, 0.12), "visor": Color(0.1, 0.22, 0.26),
		"gun": Color(0.1, 0.1, 0.1), "skin": Color(0.7, 0.55, 0.45),
	},
}

var class_id: StringName = &"recruit"
var muzzle: Node3D  ## tip of the gun (for flashes)
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_pivot: Node3D
var _mats: Dictionary = {}
var weapon_id: StringName = &""
var _gun_node: Node3D
var _shadow_only: bool = false
## Imported model instead of boxes; null for the placeholder.
var _model: Node3D
var _skeleton: Skeleton3D
var _tree: AnimationTree
var _rig: LocomotionRig
var _hold: SkeletonModifier3D
var _support: SkeletonModifier3D
var _feet: SkeletonModifier3D
## Optional rendered terrain sampler, receiving a world point (metres).
var ground_height: Callable
## Noclip / airborne poses must not anchor their feet to the ground.
var grounded: bool = true
var _rifle_parts: Array[MeshInstance3D] = []
var _rifle_muzzle: Node3D
var _gun_mount: Node3D  ## where placeholder guns sit (the GLB's hands)
var _left_hand: BoneAttachment3D  ## holds the gun while the right hand carries
## Hook: true while a fuel can is in the right hand (island.gd:
## soldier.carrying = run.is_carrying()). The rifle moves to the left hand.
var carrying: bool = false
## Hook: barrel elevation in radians (0 = level, as the fixed camera's flat
## shots). Third / first person could pass the camera pitch.
var aim_pitch: float = 0.0
# Locomotion state (all smoothed in animate()).
var _has_last: bool = false
var _last_pos := Vector3.ZERO
var _velocity := Vector3.ZERO
var _legs_yaw: float = 0.0  ## world yaw the hips point to
var _backward: bool = false
var _turn_steps: bool = false
var _gait: float = 0.0  ## 0 walk, 1 jog, 2 sprint
var _rate: float = 0.0  ## cycles per second, negative = backpedal
var _move: float = 0.0  ## 0 idle, 1 locomotion
var _carry: float = 0.0
var _carry_mounted: bool = false


static func create(id: StringName) -> SoldierModel:
	var s := SoldierModel.new()
	s.class_id = id if PALETTES.has(id) else &"recruit"
	s._build()
	return s


func _mat(key: String) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = PALETTES[class_id][key]
		m.roughness = 0.35 if key == "visor" else 0.85
		if key == "visor":
			m.metallic = 0.4
		_mats[key] = m
	return _mats[key]


func _box(parent: Node3D, size: Vector3, pos: Vector3, key: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.material_override = _mat(key)
	parent.add_child(mi)
	return mi


func _build() -> void:
	var model_path: String = VANGUARD_MODEL if class_id == &"vanguard" else RECRUIT_MODEL
	if ResourceLoader.exists(model_path):
		var scene := load(model_path) as PackedScene
		if scene != null:
			_build_model(scene)
			return
	var heavy: bool = class_id == &"vanguard"
	var pad: float = 1.25 if heavy else 1.0
	# Legs hang from hip pivots so they can swing.
	_leg_l = _leg(Vector3(-0.14, HIP_Y, 0), pad)
	_leg_r = _leg(Vector3(0.14, HIP_Y, 0), pad)
	# Hips and belt.
	_box(self, Vector3(0.46, 0.2, 0.28), Vector3(0, 0.98, 0), "cloth")
	_box(self, Vector3(0.48, 0.07, 0.3), Vector3(0, 1.07, 0), "dark")
	# Torso + plate carrier with three magazine pouches.
	_box(self, Vector3(0.5, 0.52, 0.3), Vector3(0, 1.36, 0), "cloth")
	_box(self, Vector3(0.46 * pad, 0.42, 0.12), Vector3(0, 1.38, -0.17), "armor")
	_box(self, Vector3(0.46 * pad, 0.42, 0.1), Vector3(0, 1.38, 0.17), "armor")
	for i in 3:
		_box(self, Vector3(0.11, 0.13, 0.07), Vector3(-0.13 + i * 0.13, 1.24, -0.25), "dark")
	# Backpack.
	_box(self, Vector3(0.38, 0.4, 0.18), Vector3(0, 1.35, 0.3), "dark")
	# Neck, head, helmet with visor.
	_box(self, Vector3(0.14, 0.08, 0.14), Vector3(0, 1.66, 0), "dark")
	_box(self, Vector3(0.22, 0.24, 0.24), Vector3(0, 1.8, 0), "skin")
	_box(self, Vector3(0.32, 0.17, 0.33), Vector3(0, 1.94, 0.01), "armor")
	_box(self, Vector3(0.34, 0.06, 0.35), Vector3(0, 1.86, 0.01), "armor")
	_box(self, Vector3(0.26, 0.09, 0.05), Vector3(0, 1.81, -0.13), "visor")
	if heavy:
		_box(self, Vector3(0.22, 0.12, 0.05), Vector3(0, 1.7, -0.13), "visor")  # face shield
	# Arms + weapon on one pivot at shoulder height (they move together).
	_arm_pivot = Node3D.new()
	_arm_pivot.position = Vector3(0, SHOULDER_Y, 0)
	add_child(_arm_pivot)
	for side in [-1.0, 1.0]:
		_box(_arm_pivot, Vector3(0.2 * pad, 0.16, 0.24 * pad), Vector3(0.31 * side, 0.04, 0), "armor")  # shoulder pad
		_box(_arm_pivot, Vector3(0.13, 0.3, 0.13), Vector3(0.31 * side, -0.16, -0.02), "cloth", Vector3(25, 0, 0))  # upper arm
	_box(_arm_pivot, Vector3(0.11, 0.11, 0.3), Vector3(0.26, -0.3, -0.2), "cloth", Vector3(0, -20, 0))  # right forearm
	_box(_arm_pivot, Vector3(0.11, 0.11, 0.34), Vector3(-0.2, -0.26, -0.24), "cloth", Vector3(0, 25, 0))  # left forearm
	_box(_arm_pivot, Vector3(0.09, 0.09, 0.09), Vector3(0.18, -0.3, -0.36), "dark")  # gloves
	_box(_arm_pivot, Vector3(0.09, 0.09, 0.09), Vector3(-0.06, -0.26, -0.46), "dark")
	set_weapon(&"shotgun" if heavy else &"rifle")


## Keep the imported hierarchy and skins intact; never reparent skinned pieces.
func _build_model(scene: PackedScene) -> void:
	_model = scene.instantiate() as Node3D
	add_child(_model)
	_skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	_rifle_muzzle = _model.find_child("Muzzle", true, false) as Node3D
	for part: MeshInstance3D in _model.find_children("Rifle_*", "MeshInstance3D", true, false):
		_rifle_parts.append(part)
	_gun_mount = Node3D.new()
	_gun_mount.name = "WeaponMount"
	_rifle_muzzle.get_parent().add_child(_gun_mount)
	_gun_mount.transform = _rifle_muzzle.transform
	_left_hand = BoneAttachment3D.new()
	_left_hand.name = "LeftHand"
	_left_hand.bone_name = "DEF-hand.L"
	_skeleton.add_child(_left_hand)
	_tree = AnimationTree.new()
	_tree.name = String(class_id).capitalize() + "AnimationTree"
	_tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var animations: String = VANGUARD_ANIMATIONS if class_id == &"vanguard" else RECRUIT_ANIMATIONS
	_tree.add_animation_library(&"UAL", load(animations) as AnimationLibrary)
	_tree.tree_root = _locomotion_tree()
	_skeleton.add_child(_tree)
	_tree.root_node = NodePath("..")
	# Modifiers run in child order: the delivered two-hand hold sets the
	# arms, the support hand adapts to the weapon, then the rig turns hips /
	# spine and levels the rifle. Ground contact corrects only the legs last.
	_hold = (load("res://game/world/recruit_rifle_hold.gd") as Script).new()
	if class_id == &"vanguard":
		_hold.set("pose_file", VANGUARD_HOLD)
	_skeleton.add_child(_hold)
	_support = (load("res://game/world/weapon_support_hold.gd") as Script).new()
	_support.name = "WeaponSupportHold"
	_support.set("grip_from_hand", _rifle_muzzle.transform * Transform3D(Basis.IDENTITY, WeaponModel.GRIP_FROM_MUZZLE))
	_skeleton.add_child(_support)
	_rig = LocomotionRig.new()
	_rig.name = "LocomotionRig"
	_rig.body = self
	_skeleton.add_child(_rig)
	_feet = (load("res://game/world/foot_contact.gd") as Script).new()
	_feet.name = "FootContact"
	_feet.set("body", self)
	_skeleton.add_child(_feet)
	set_weapon(&"rifle")


## idle --+
##        +-- move (Blend2) --> output
## gait --+-- rate (TimeScale)
## "gait" is a 1D blend space Walk(0) / Jog(1) / Sprint(2) on one shared
## 1-second timeline (each clip stretched to it and offset so the left foot
## leads at phase 0): blending never mixes two different steps, and "rate"
## (cycles per second, negative = backwards) sets the stride frequency.
func _locomotion_tree() -> AnimationNodeBlendTree:
	var blend_tree := AnimationNodeBlendTree.new()
	var idle := AnimationNodeAnimation.new()
	idle.animation = IDLE_CLIP
	var gait := AnimationNodeBlendSpace1D.new()
	gait.min_space = 0.0
	gait.max_space = 2.0
	gait.sync = true
	for i in GAITS.size():
		var g: Dictionary = GAITS[i]
		var clip := AnimationNodeAnimation.new()
		clip.animation = g.clip
		clip.use_custom_timeline = true
		clip.timeline_length = 1.0
		clip.stretch_time_scale = true
		clip.loop_mode = Animation.LOOP_LINEAR
		# start_offset counts in the stretched 1-second timeline: the phase.
		clip.start_offset = float(g.phase)
		gait.add_blend_point(clip, float(i), -1, StringName(String(g.clip).trim_prefix("UAL/")))
	var rate := AnimationNodeTimeScale.new()
	var move := AnimationNodeBlend2.new()
	blend_tree.add_node(&"idle", idle, Vector2(0, 0))
	blend_tree.add_node(&"gait", gait, Vector2(0, 160))
	blend_tree.add_node(&"rate", rate, Vector2(200, 160))
	blend_tree.add_node(&"move", move, Vector2(400, 60))
	blend_tree.connect_node(&"rate", 0, &"gait")
	blend_tree.connect_node(&"move", 0, &"idle")
	blend_tree.connect_node(&"move", 1, &"rate")
	blend_tree.connect_node(&"output", 0, &"move")
	return blend_tree


func _ready() -> void:
	if _tree != null:
		_apply_locomotion()
		_tree.advance(0.0)


func uses_skeleton() -> bool:
	return _skeleton != null


func _leg(hip: Vector3, pad: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hip
	add_child(pivot)
	_box(pivot, Vector3(0.18, 0.44, 0.2), Vector3(0, -0.22, 0), "cloth")  # thigh
	_box(pivot, Vector3(0.15, 0.42, 0.17), Vector3(0, -0.62, 0), "cloth")  # shin
	_box(pivot, Vector3(0.17 * pad, 0.13, 0.08), Vector3(0, -0.45, -0.11), "armor")  # knee pad
	_box(pivot, Vector3(0.17, 0.12, 0.3), Vector3(0, -0.86, -0.04), "dark")  # boot
	return pivot


## The equipped weapon (WeaponModel). On the delivered rigs it sits on the
## right hand at the GLB rifle's grip; the GLB rifle itself stays hidden
## (WeaponModel loads the new original GLBs).
func set_weapon(id: StringName) -> void:
	if weapon_id == id:
		return
	weapon_id = id
	if _gun_node != null:
		_gun_node.get_parent().remove_child(_gun_node)
		_gun_node.queue_free()
		_gun_node = null
	for part in _rifle_parts:
		part.visible = false
	var gun := WeaponModel.build(id)
	_gun_node = gun
	if _support != null:
		_support.set("weapon", gun)
	if _skeleton != null:
		gun.position = WeaponModel.GRIP_FROM_MUZZLE
		_gun_mount.add_child(gun)
	else:
		gun.position = Vector3(0.18, -0.24, -0.34)  # grip in the right glove
		gun.rotation_degrees = Vector3(0, -8, 0)
		_arm_pivot.add_child(gun)
	# Every equipped GLB owns the actual barrel tip, including the rifle.
	muzzle = gun.muzzle
	if _shadow_only:
		set_shadow_only(true)


## First person: the body is not drawn but still casts its shadow.
func set_shadow_only(on: bool) -> void:
	_shadow_only = on
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = mode


## Advances the animation by `delta` (0 freezes it: pause, level-up, hitstop).
## The delivered rigs read their speed and direction from their own motion
## between calls (island.gd moves the model after this call, so it is the
## previous frame's step) and only use `sprinting`; `speed` (0..1) and `t`
## drive the placeholder's box legs.
func animate(speed: float, t: float, sprinting: bool = false, delta: float = 0.0) -> void:
	if _tree != null:
		if not is_inside_tree() or delta <= 0.0:
			return
		_update_locomotion(sprinting, delta)
		_apply_locomotion()
		_feet.set("ground_height", ground_height)
		_feet.set("moving", _velocity.length() > MOVE_MIN)
		_feet.call("advance")
		_tree.advance(delta)
		return
	var swing: float = sin(t * 9.0) * 0.6 * clampf(speed, 0.0, 1.0)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_pivot.position.y = SHOULDER_Y + absf(sin(t * 9.0)) * 0.03 * speed


## Stride (m per cycle) of the gait blend at `g`.
static func gait_stride(g: float) -> float:
	var i: int = clampi(floori(g), 0, GAITS.size() - 2)
	var a: Dictionary = GAITS[i]
	var b: Dictionary = GAITS[i + 1]
	return lerpf(float(a.speed) * float(a.length), float(b.speed) * float(b.length), clampf(g - i, 0.0, 1.0))


## The gait blend position for a ground speed: Walk up to its own speed,
## then Walk -> Jog -> Sprint by speed (the game walks at 6 m/s, which is
## exactly the Jog clip's speed, and sprints at 9.6 m/s).
static func gait_for_speed(v: float) -> float:
	for i in GAITS.size() - 1:
		var lo: float = GAITS[i].speed
		var hi: float = GAITS[i + 1].speed
		if v <= hi:
			return i + clampf((v - lo) / (hi - lo), 0.0, 1.0)
	return float(GAITS.size() - 1)


func _update_locomotion(sprinting: bool, delta: float) -> void:
	var here: Vector3 = global_position
	var step := Vector3(here.x - _last_pos.x, 0.0, here.z - _last_pos.z)
	var fwd: Vector3 = -global_basis.z
	var body_yaw: float = atan2(-fwd.x, -fwd.z)
	if not _has_last or step.length() > TELEPORT:
		step = Vector3.ZERO
		_velocity = Vector3.ZERO
		if not _has_last:
			_legs_yaw = body_yaw
	_has_last = true
	_last_pos = here
	_velocity = _velocity.lerp(step / delta, 1.0 - exp(-VELOCITY_SMOOTH * delta))
	var speed: float = _velocity.length()
	var moving: bool = speed > MOVE_MIN
	if moving:
		var move_yaw: float = atan2(-_velocity.x, -_velocity.z)
		var rel: float = absf(wrapf(move_yaw - body_yaw, -PI, PI))
		# Backpedal past ~90 degrees from the aim; the hysteresis keeps a pure
		# strafe from flickering between the two.
		_backward = rel > (BACKPEDAL_EXIT if _backward else BACKPEDAL_ENTER)
		# Blend in the body's frame, never through the back: a direction
		# reversal swings the legs past the front, as a person would.
		var off_now: float = clampf(wrapf(_legs_yaw - body_yaw, -PI, PI), -LEGS_MAX, LEGS_MAX)
		var off_want: float = clampf(wrapf(move_yaw + (PI if _backward else 0.0) - body_yaw, -PI, PI), -LEGS_MAX, LEGS_MAX)
		_legs_yaw = body_yaw + lerpf(off_now, off_want, 1.0 - exp(-LEGS_SMOOTH * delta))
		_turn_steps = false
	else:
		# Standing: the legs keep their place while the torso aims; past
		# TURN_STEP_START they swivel round quickly to catch up (a walk cycle
		# in place slid the planted feet more: measured 0.91-1.08 m/s against
		# 0.85 m/s for the swivel).
		var off: float = wrapf(_legs_yaw - body_yaw, -PI, PI)
		if absf(off) > TURN_STEP_START:
			_turn_steps = true
		_legs_yaw = body_yaw + move_toward(off, 0.0, (TURN_STEP_SPEED if _turn_steps else LEGS_DRIFT) * delta)
		if _turn_steps and absf(off) < deg_to_rad(5.0):
			_turn_steps = false
	_legs_yaw = body_yaw + clampf(wrapf(_legs_yaw - body_yaw, -PI, PI), -LEGS_MAX, LEGS_MAX)
	var target_gait: float = gait_for_speed(speed)
	if sprinting and moving:
		target_gait = maxf(target_gait, 1.75)
	if _backward:
		target_gait = minf(target_gait, 1.0)  # no backwards sprint clip: jog
	# From a standstill the gait starts right at the speed (the game has no
	# acceleration); later changes (sprint on / off) blend.
	_gait = target_gait if _move < 0.5 else lerpf(_gait, target_gait, 1.0 - exp(-GAIT_SMOOTH * delta))
	# Cycles per second so the planted foot keeps up with the ground.
	var cycles: float = speed / gait_stride(_gait)
	_rate = minf(cycles, MAX_CYCLES) * (-1.0 if _backward else 1.0)
	_move = lerpf(_move, 1.0 if moving else 0.0, 1.0 - exp(-MOVE_SMOOTH * delta))
	_carry = move_toward(_carry, 1.0 if carrying else 0.0, delta * 6.0)


func _apply_locomotion() -> void:
	_tree.set(&"parameters/gait/blend_position", _gait)
	_tree.set(&"parameters/rate/scale", _rate)
	_tree.set(&"parameters/move/blend_amount", _move)
	_mount_gun(carrying)
	_support.active = not carrying
	_feet.active = grounded
	var fwd: Vector3 = -global_basis.z
	_rig.legs_offset = wrapf(_legs_yaw - atan2(-fwd.x, -fwd.z), -PI, PI)
	_rig.aim_pitch = aim_pitch
	_rig.aim_weight = 1.0 - _carry
	_rig.carry_weight = _carry
	_rig.carry_hand = CARRY_HAND
	_rig.muzzle = muzzle if not carrying else null


## The gun lives on the right hand; with a can in that hand it moves to the
## left hand, exactly where it was (the hold keeps both hands on it).
func _mount_gun(on_left: bool) -> void:
	if on_left == _carry_mounted or _hold == null:
		return
	if on_left:
		_gun_mount.reparent(_left_hand, false)
		_gun_mount.transform = _hand_left_to_right() * _rifle_muzzle.transform
	else:
		_gun_mount.reparent(_rifle_muzzle.get_parent(), false)
		_gun_mount.transform = _rifle_muzzle.transform
	_carry_mounted = on_left


## The right hand in the left hand's space under the delivered two-hand hold
## (both arms hang from the same chest bone, so this never changes).
func _hand_left_to_right() -> Transform3D:
	var bones: PackedInt32Array = _hold.get("_bones")
	var rotations: Array = _hold.get("_rotations")
	var positions: Array = _hold.get("_positions")
	var chain: Dictionary = {}
	for i in bones.size():
		chain[_skeleton.get_bone_name(bones[i])] = Transform3D(Basis(rotations[i] as Quaternion), positions[i] as Vector3)
	var hands: Array[Transform3D] = []
	for side in ["L", "R"]:
		var t := Transform3D()
		for part in ["DEF-shoulder.", "DEF-upper_arm.", "DEF-forearm.", "DEF-hand."]:
			var bone: String = part + side
			t = t * (chain[bone] if chain.has(bone) else _skeleton.get_bone_rest(_skeleton.find_bone(bone)))
		hands.append(t)
	return hands[0].affine_inverse() * hands[1]


## For tools and tests: the locomotion state in numbers and one line.
func debug_state() -> Dictionary:
	var names: Array = ["walk", "jog", "sprint"]
	var legs: float = rad_to_deg(_rig.legs_offset) if _rig != null else 0.0
	return {
		"gait": _gait, "rate": _rate, "move": _move, "backward": _backward,
		"legs_offset": legs, "speed": _velocity.length(), "turn_steps": _turn_steps, "carry": _carry,
		"text": "%s %.2f %+.2fc/s mv%.2f legs%+.0f%s" % [names[clampi(roundi(_gait), 0, 2)], _gait, _rate, _move,
			legs, " carry" if carrying else ""],
	}


## Applied after the animation and the two-hand hold, every skeleton update:
## 1. hips turn by legs_offset (legs follow the movement), the lower spine
##    turns half of it back;
## 2. carrying: the right arm hangs straight down to the can's handle;
## 3. the chest turns (yaw) and the arms pitch about the shoulder line until
##    the barrel points along the body's facing at aim_pitch.
## Everything is a pure function of these inputs and the animated pose, so a
## frozen animation (pause) gives a frozen result.
class LocomotionRig extends SkeletonModifier3D:
	var body: Node3D
	var muzzle: Node3D
	var legs_offset: float = 0.0
	var aim_pitch: float = 0.0
	var aim_weight: float = 1.0
	var carry_weight: float = 0.0
	var carry_hand := Vector3.ZERO  ## in the body's space
	var _b: Dictionary = {}

	func _ready() -> void:
		var sk: Skeleton3D = get_skeleton()
		for bone in ["DEF-hips", "DEF-spine.001", "DEF-spine.002", "DEF-spine.003", "DEF-neck", "DEF-head",
				"DEF-upper_arm.L", "DEF-upper_arm.R", "DEF-forearm.R", "DEF-hand.R"]:
			_b[bone] = sk.find_bone(bone)

	func _process_modification() -> void:
		var sk: Skeleton3D = get_skeleton()
		if sk == null or body == null or _b.is_empty():
			return
		var to_skeleton: Basis = sk.global_basis.orthonormalized().inverse()
		var up: Vector3 = (to_skeleton * Vector3.UP).normalized()
		if absf(legs_offset) > 0.0001:
			_rotate(sk, _b["DEF-hips"], up, legs_offset)
			_rotate(sk, _b["DEF-spine.001"], up, -legs_offset * 0.5)
		if carry_weight > 0.0:
			_carry_arm(sk)
		var forward: Vector3 = (to_skeleton * -body.global_basis.z).normalized()
		var want: Vector3 = forward.rotated(forward.cross(up).normalized(), aim_pitch)
		if aim_weight > 0.0 and muzzle != null and muzzle.is_inside_tree():
			_aim(sk, up, want)
		_look(sk, forward, want)

	## The head looks where the gun points (85 %): the jog and sprint clips
	## nod it down and the spine corrections would swing it about.
	func _look(sk: Skeleton3D, forward: Vector3, want: Vector3) -> void:
		var head: int = _b["DEF-head"]
		# In the rest pose the head looks along the body's forward.
		var look_local: Vector3 = (sk.get_bone_global_rest(head).basis.orthonormalized().inverse() * forward).normalized()
		for pair in [["DEF-neck", 0.5], ["DEF-head", 1.0]]:
			var now: Vector3 = (sk.get_bone_global_pose(head).basis.orthonormalized() * look_local).normalized()
			var axis: Vector3 = now.cross(want)
			if axis.length() < 0.0001:
				return
			_rotate(sk, _b[pair[0]], axis.normalized(), now.angle_to(want) * float(pair[1]) * 0.85)

	## Turns a bone by `angle` about `axis` (skeleton space) around its own
	## origin; its children follow.
	func _rotate(sk: Skeleton3D, bone: int, axis: Vector3, angle: float) -> void:
		var g: Basis = sk.get_bone_global_pose(bone).basis.orthonormalized()
		var local_axis: Vector3 = (g.inverse() * axis).normalized()
		var q: Quaternion = sk.get_bone_pose_rotation(bone) * Quaternion(local_axis, angle)
		sk.set_bone_pose_rotation(bone, q.normalized())

	## The barrel's direction in skeleton space, from the hand bone it rides
	## (node transforms below the attachment do not depend on the pose).
	func _barrel(sk: Skeleton3D) -> Vector3:
		var n: Node = muzzle
		while n != null and not n is BoneAttachment3D:
			n = n.get_parent()
		var attachment := n as BoneAttachment3D
		if attachment == null:
			return Vector3.ZERO
		var rel: Basis = attachment.global_basis.orthonormalized().inverse() * muzzle.global_basis.orthonormalized()
		var hand: Basis = sk.get_bone_global_pose(attachment.bone_idx).basis.orthonormalized()
		return (hand * rel * Vector3.FORWARD).normalized()

	func _aim(sk: Skeleton3D, up: Vector3, want: Vector3) -> void:
		# Pitch first: both arms (and the gun between them) swing about the
		# line through the two shoulders, so the hands never leave the gun.
		for i in 2:
			var b: Vector3 = _barrel(sk)
			if b == Vector3.ZERO:
				return
			var left: Vector3 = sk.get_bone_global_pose(_b["DEF-upper_arm.L"]).origin
			var right: Vector3 = sk.get_bone_global_pose(_b["DEF-upper_arm.R"]).origin
			var axis: Vector3 = (right - left).normalized()
			var pitch: float = asin(clampf(want.dot(up), -1.0, 1.0)) - asin(clampf(b.dot(up), -1.0, 1.0))
			if b.rotated(axis, 0.1).dot(up) < b.dot(up):
				pitch = -pitch  # this way round about the axis raises the barrel
			pitch = clampf(pitch, -deg_to_rad(70.0), deg_to_rad(70.0)) * aim_weight
			_rotate(sk, _b["DEF-upper_arm.L"], axis, pitch)
			_rotate(sk, _b["DEF-upper_arm.R"], axis, pitch)
		# Then yaw (about the vertical, which keeps the pitch): half on the
		# middle spine, the rest on the chest.
		for pair in [["DEF-spine.002", 0.5], ["DEF-spine.003", 1.0]]:
			var b: Vector3 = _barrel(sk)
			var flat_b: Vector3 = b - up * b.dot(up)
			var flat_w: Vector3 = want - up * want.dot(up)
			if flat_b.length() < 0.05 or flat_w.length() < 0.05:
				break
			var yaw: float = flat_b.signed_angle_to(flat_w, up)
			_rotate(sk, _b[pair[0]], up, yaw * float(pair[1]) * aim_weight)

	## Right arm straight (rest bends) and pointing at the can's handle.
	func _carry_arm(sk: Skeleton3D) -> void:
		for bone in ["DEF-forearm.R", "DEF-hand.R"]:
			var i: int = _b[bone]
			var rest: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
			sk.set_bone_pose_rotation(i, sk.get_bone_pose_rotation(i).slerp(rest, carry_weight))
		var target: Vector3 = sk.global_transform.affine_inverse() * (body.global_transform * carry_hand)
		var shoulder: Vector3 = sk.get_bone_global_pose(_b["DEF-upper_arm.R"]).origin
		for k in 2:
			var hand: Vector3 = sk.get_bone_global_pose(_b["DEF-hand.R"]).origin
			var have: Vector3 = (hand - shoulder).normalized()
			var want: Vector3 = (target - shoulder).normalized()
			var axis: Vector3 = have.cross(want)
			if axis.length() < 0.0001:
				break
			_rotate(sk, _b["DEF-upper_arm.R"], axis.normalized(), have.angle_to(want) * carry_weight)
