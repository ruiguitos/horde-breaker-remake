class_name ViewModel
extends Node3D
## First-person placeholder weapon: a few boxes in the class kit's colours
## (SoldierModel.PALETTES) at the lower right of the view, a glove and sleeve
## under it and a muzzle flash at the tip. A child of the camera (local -Z is
## forward). Real gun models replace it later.

## Rest position in camera space: lower right, a little ahead of the eye.
const REST: Vector3 = Vector3(0.2, -0.22, -0.45)
## The boxes are modelled at real size; at the eye that filled a third of
## the screen. Drawn at 60 % it reads as a gun in the hands, not a wall.
const GUN_SCALE: float = 0.6
## Largest pull towards the eye (metres); at it the gun is also lowered.
const MAX_PULL: float = 0.3
## Barrel length per weapon id (metres); unknown ids use the rifle.
const LENGTHS: Dictionary = {&"machine_gun": 0.86, &"smg": 0.38, &"shotgun": 0.6, &"rifle": 0.66, &"marksman": 0.8}

var class_id: StringName = &"recruit"
var weapon_id: StringName = &""
var tip: Node3D  ## end of the barrel: muzzle flash and tracer start
var _gun: Node3D
var _flash: MeshInstance3D
var _flash_time: float = 0.0
var _kick: float = 0.0
var _mats: Dictionary = {}


static func create(id: StringName) -> ViewModel:
	var v := ViewModel.new()
	v.class_id = id if SoldierModel.PALETTES.has(id) else &"recruit"
	v.position = REST
	v.scale = Vector3.ONE * GUN_SCALE
	v.set_weapon(&"rifle")
	return v


## Rebuilds the boxes when the weapon changes (cheap: a handful of meshes).
func set_weapon(id: StringName) -> void:
	if id == weapon_id and _gun != null:
		return
	weapon_id = id
	if _gun != null:
		remove_child(_gun)
		_gun.queue_free()
	_gun = Node3D.new()
	add_child(_gun)
	var length: float = LENGTHS.get(id, LENGTHS[&"rifle"])
	var front: float = -length + 0.08  # barrel end (z), grip at z = 0
	# Receiver + barrel, stock (long guns), magazine or pump, rear sight.
	_box(Vector3(0.06, 0.09, length), Vector3(0, 0, front * 0.5 + 0.04), "gun")
	_box(Vector3(0.03, 0.03, 0.12), Vector3(0, 0.01, front - 0.04), "dark")  # muzzle brake
	_box(Vector3(0.05, 0.08, 0.18), Vector3(0, -0.03, 0.17), "gun")
	if id == &"shotgun":
		_box(Vector3(0.08, 0.06, 0.2), Vector3(0, -0.07, front * 0.6), "dark")
	elif id == &"machine_gun":
		_box(Vector3(0.16, 0.16, 0.14), Vector3(0.05, -0.13, -0.13), "gun")
	else:
		_box(Vector3(0.045, 0.13, 0.06), Vector3(0, -0.1, -0.05), "gun")
	if id == &"marksman":
		_box(Vector3(0.05, 0.05, 0.2), Vector3(0, 0.08, -0.08), "dark")  # scope
	else:
		_box(Vector3(0.03, 0.04, 0.04), Vector3(0, 0.065, 0.02), "dark")
	# Right hand on the grip and the sleeve going out of the view.
	_box(Vector3(0.08, 0.08, 0.09), Vector3(0.01, -0.07, 0.04), "dark")
	_box(Vector3(0.1, 0.1, 0.3), Vector3(0.04, -0.12, 0.22), "cloth", Vector3(18, 0, 0))
	tip = Node3D.new()
	tip.position = Vector3(0, 0.01, front - 0.11)
	_gun.add_child(tip)
	_flash = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.035
	s.height = 0.07
	_flash.mesh = s
	_flash.scale = Vector3(1.0, 1.0, 1.8)
	# A faint, half-transparent puff: the shot is read from the tracer and
	# the sound; a bright flash right at the eye hid the target every shot.
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(1.0, 0.8, 0.5, 0.35)
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash.material_override = fm
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.visible = false
	tip.add_child(_flash)


func _box(size: Vector3, pos: Vector3, key: String, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.rotation_degrees = rot_deg
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = SoldierModel.PALETTES[class_id][key]
		m.roughness = 0.6
		_mats[key] = m
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gun.add_child(mi)


## A shot: flash at the tip and a small recoil kick.
func fire() -> void:
	_flash_time = 0.035
	_kick = 1.0


## Per frame: `pull_back` (0..MAX_PULL metres) moves the gun towards the eye
## and tilts it down when a wall is right in front, so the barrel does not
## go through it; `walk` 0..1 bobs it, `t` in seconds.
func update(delta: float, pull_back: float, walk: float, t: float) -> void:
	_kick = maxf(0.0, _kick - delta * 14.0)
	_flash_time -= delta
	_flash.visible = _flash_time > 0.0
	if _flash.visible:
		_flash.rotation.z = randf() * TAU
	var bob := Vector3(sin(t * 9.0) * 0.008, -absf(cos(t * 9.0)) * 0.01, 0) * walk
	var near: float = clampf(pull_back / MAX_PULL, 0.0, 1.0)
	position = REST + bob + Vector3(0, -pull_back * 0.3, pull_back + _kick * 0.035)
	rotation.x = _kick * 0.06 - near * 1.1  # negative: the barrel points down
