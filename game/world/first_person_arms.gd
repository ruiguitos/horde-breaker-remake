class_name FirstPersonArms
extends Node3D
## Weapon-specific first-person arms and hands, all using the same eight bones:
## the right hand stays on its authored grip; the left arm uses two bones so
## the palm's contact point sits on the weapon's support point
## (WeaponModel.support_point). Gun space: origin at the right grip, -Z forward.
##
## The file's rest pose is the bent grip pose (the glTF nodes), not the straight
## bind pose; the IK works from the bent lengths (0.30 m each) and keeps the
## elbow on its own side. The hands do not rotate: the palm stays flat on the
## support point, so the contact is an exact translation of the wrist.

const MODEL_DIR: String = "res://assets/models/characters/weapon_grips_original/"
## Explicit resources keep all five scenes included in an exported game.
const MODELS: Dictionary = {
	&"rifle": preload("res://assets/models/characters/weapon_grips_original/rifle/arms_firstperson.glb"),
	&"smg": preload("res://assets/models/characters/weapon_grips_original/smg/arms_firstperson.glb"),
	&"machine_gun": preload("res://assets/models/characters/weapon_grips_original/machine_gun/arms_firstperson.glb"),
	&"shotgun": preload("res://assets/models/characters/weapon_grips_original/shotgun/arms_firstperson.glb"),
	&"marksman": preload("res://assets/models/characters/weapon_grips_original/marksman/arms_firstperson.glb"),
}
## Palm contact of the rifle's left hand at rest, in gun space (the same point
## the file was checked against: WeaponModel.SUPPORT_POINTS[&"rifle"]).
const PALM_REST: Vector3 = Vector3(0, 0.077, -0.26)
## Material names in the file, and the class palette key each one takes.
const CLOTH_KEY: String = "cloth"
const GLOVE_KEY: String = "dark"
## Reload clip per weapon, where the file has one: the right hand follows the
## magazine (SMG) or the charging slide (Machine Gun), sampled by progress.
const RELOAD_CLIPS: Dictionary = {&"smg": &"reload_mag_smg", &"machine_gun": &"reload_mag_mg"}

var skeleton: Skeleton3D
var grip_weapon: StringName = &"rifle"
var palm_rest: Vector3 = PALM_REST
var _player: AnimationPlayer  ## the file's player, paused: set_reload() places the pose
var _reload_clip: StringName = &""  ## empty when the file has no reload clip yet
var reach_error: float = 0.0  ## metres the wrist fell short of the last target (0 = reached)
var _upper: int = -1
var _fore: int = -1
var _hand: int = -1
var _shoulder: Vector3  ## the left shoulder joint (head of UpperArm_L)
var _elbow_rest: Vector3
var _wrist_rest: Vector3
var _hand_basis: Basis  ## the left hand's rest orientation (kept)
var _upper_basis: Basis  ## the left upper arm's rest orientation
var _fore_basis: Basis
var _upper_len: float = 0.3
var _fore_len: float = 0.3
var _palm_offset: Vector3  ## palm contact in the hand's own space


## Loads the file and returns the arms in gun space. `palette` (SoldierModel.PALETTES
## entry) colours the sleeve and the glove for the class.
static func build(palette: Dictionary, weapon: StringName = &"rifle") -> FirstPersonArms:
	var arms := FirstPersonArms.new()
	arms.name = "FirstPersonArms"
	arms.grip_weapon = weapon if MODELS.has(weapon) else &"rifle"
	arms.palm_rest = WeaponModel.SUPPORT_POINTS[arms.grip_weapon]
	var packed: PackedScene = MODELS[arms.grip_weapon]
	var model := packed.instantiate() as Node3D
	arms.add_child(model)
	arms.skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(arms.skeleton != null, "The arms file has no skeleton")
	arms._read_rest()
	arms._colour(model, palette)
	arms._player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip: StringName = RELOAD_CLIPS.get(arms.grip_weapon, &"")
	if arms._player != null and arms._player.has_animation(clip):
		arms._reload_clip = clip
		# Paused: the frame loop never advances the clip, set_reload() does.
		arms._player.play(clip)
		arms._player.pause()
	return arms


func _read_rest() -> void:
	_upper = skeleton.find_bone("UpperArm_L")
	_fore = skeleton.find_bone("Forearm_L")
	_hand = skeleton.find_bone("Hand_L")
	assert(_upper >= 0 and _fore >= 0 and _hand >= 0, "The left arm bones are missing")
	var upper: Transform3D = skeleton.get_bone_global_rest(_upper)
	var fore: Transform3D = skeleton.get_bone_global_rest(_fore)
	var hand: Transform3D = skeleton.get_bone_global_rest(_hand)
	_shoulder = upper.origin
	_elbow_rest = fore.origin
	_wrist_rest = hand.origin
	_upper_basis = upper.basis
	_fore_basis = fore.basis
	_hand_basis = hand.basis
	_upper_len = (_elbow_rest - _shoulder).length()
	_fore_len = (_wrist_rest - _elbow_rest).length()
	# The palm contact measured on the rest pose, in the hand's own space.
	_palm_offset = hand.affine_inverse() * palm_rest
	set_support(palm_rest)


## Whether the file has a reload clip for this weapon.
func has_reload() -> bool:
	return _reload_clip != &""


## Places the arms for a reload at `progress` (0..1, ViewModel.reload). The right
## hand follows the magazine or the charging slide; the left palm is kept on its
## support by the IK, which runs after the clip, so the clip cannot move it.
func set_reload(progress: float) -> void:
	if _reload_clip == &"":
		return
	_player.seek(clampf(progress, 0.0, 1.0) * _player.get_animation(_reload_clip).length, true)


## Moves the left palm contact to `support` (gun space) and solves the arm.
func set_support(support: Vector3) -> void:
	var wrist: Vector3 = support - _hand_basis * _palm_offset
	var elbow: Vector3 = _solve_elbow(wrist)
	var reached: Vector3 = _reached_wrist(wrist)
	reach_error = wrist.distance_to(reached)
	_pose_bone(_upper, _shoulder, _upper_basis, _elbow_rest - _shoulder, elbow - _shoulder)
	_pose_bone(_fore, elbow, _fore_basis, _wrist_rest - _elbow_rest, reached - elbow)
	_pose_bone(_hand, reached, _hand_basis, Vector3.ZERO, Vector3.ZERO)
	skeleton.force_update_all_bone_transforms()


## Elbow for a wrist target: the two-bone solution (law of cosines) on the side
## of the rest elbow. The distance is clamped to what the arm can reach.
func _solve_elbow(wrist: Vector3) -> Vector3:
	var to: Vector3 = _reached_wrist(wrist) - _shoulder
	var d: float = to.length()
	if d < 0.000001:
		return _elbow_rest
	var u: Vector3 = to / d
	var a: float = (_upper_len * _upper_len - _fore_len * _fore_len + d * d) / (2.0 * d)
	var h: float = sqrt(maxf(0.0, _upper_len * _upper_len - a * a))
	var hint: Vector3 = _elbow_rest - _shoulder
	var side: Vector3 = (hint - u * hint.dot(u)).normalized()
	return _shoulder + u * a + side * h


## The wrist the arm can reach: `wrist` itself, or the nearest point on the
## reach sphere around the shoulder (the arm stretches fully and stops).
func _reached_wrist(wrist: Vector3) -> Vector3:
	var reach: float = _upper_len + _fore_len - 0.0005
	var to: Vector3 = wrist - _shoulder
	if to.length() <= reach:
		return wrist
	return _shoulder + to.normalized() * reach


## Sets a bone's global pose: `head` is its joint, and its direction turns from
## the rest direction `from` to `to`. The bone keeps its rest orientation otherwise.
func _pose_bone(bone: int, head: Vector3, rest_basis: Basis, from: Vector3, to: Vector3) -> void:
	var turn := Basis.IDENTITY
	if from.length() > 0.000001 and to.length() > 0.000001:
		turn = Basis(Quaternion(from.normalized(), to.normalized()))
	var pose := Transform3D(turn * rest_basis, head)
	skeleton.set_bone_global_pose_override(bone, pose, 1.0, true)


## Gives the sleeve and the glove the class colours. Other materials keep the file's.
func _colour(model: Node3D, palette: Dictionary) -> void:
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface: int in part.mesh.get_surface_count():
			var source := part.get_active_material(surface) as StandardMaterial3D
			if source == null:
				continue
			var key: String = String(source.resource_name)
			var colour_key: String = CLOTH_KEY if key == "sleeve_cloth" else (GLOVE_KEY if key == "glove" else "")
			if colour_key == "" or not palette.has(colour_key):
				continue
			var tinted := source.duplicate() as StandardMaterial3D
			tinted.albedo_color = palette[colour_key]
			part.set_surface_override_material(surface, tinted)
