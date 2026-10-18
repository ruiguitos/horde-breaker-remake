class_name ViewModel
extends Node3D
## First-person weapon: the equipped WeaponModel at the lower right of the
## view, a glove and sleeve in the class kit's colours (SoldierModel.PALETTES)
## and a muzzle flash at the tip. A child of the camera (local -Z is forward).

## Hip-fire grip position in camera space: below and right of the centre line,
## with the elbows outside the bottom edge of the first-person frame.
const REST: Vector3 = Vector3(0.16, -0.23, -0.42)
## Sights: while aiming down sights the front sight is put on the centre of the
## view, with the rear sight `EYE_TO_REAR` metres from the eye (see sight_rest).
## Used only when a gun has no sight parts in LAYOUT.
const ADS_FALLBACK: Vector3 = Vector3(0.0, -0.12, -0.4)
const EYE_TO_REAR: float = 0.12
## Reload: the magazine drops this far (gun metres) and the charging handle
## is pulled back this far (gun metres) at the end of the reload.
const MAG_DROP: float = 0.12
const CHARGE_PULL: float = 0.03
## Named parts of each GLB (node names as Godot imports them: a dot in a GLB
## name becomes an underscore, so "5.56" is "5_56") for the animations.
## `magazine` lists name prefixes (the body, floor plate and stiffeners move
## together); `charge`
## the charging handle or bolt; `front` and `rear` the sight parts. Empty where
## a gun has no such part (the Machine Gun is belt-fed, so no magazine).
const LAYOUT: Dictionary = {
	&"rifle": {"magazine": ["Curved 5_56 magazine", "Magazine floor plate", "Magazine pressed stiffener"],
		"charge": ["Charging handle"], "front": "Front sight post", "rear": "Rear sight aperture"},
	&"smg": {"magazine": ["Curved 9mm magazine", "Magazine floor plate", "Magazine pressed stiffener"],
		"charge": ["Visible bolt"], "front": "Front sight blade", "rear": "Diopter sight drum"},
	&"machine_gun": {"magazine": [], "charge": ["Charging slide"], "front": "LMG front sight post", "rear": ""},
	&"shotgun": {"magazine": [], "charge": ["Shotgun visible bolt"], "front": "", "rear": ""},
	&"marksman": {"magazine": [], "charge": ["DMR bolt handle"], "front": "", "rear": ""},
}
## The guns are drawn at real size: the arms are at real size too, and the
## hands only meet the grip and the handguard if gun and arms share one scale.
## Scaling only the gun made the fingers oversized despite correct palm markers.
const GUN_SCALE: float = 1.0
## Keep the longer LMG support arm's sleeve cap below the hip-fire frame.
const HIP_OFFSETS: Dictionary = {&"machine_gun": Vector3(0, -0.06, 0)}
## Largest pull towards the eye (metres); at it the gun is also lowered.
const MAX_PULL: float = 0.3

var class_id: StringName = &"recruit"
var weapon_id: StringName = &""
var tip: Node3D  ## end of the barrel: muzzle flash and tracer start
var _gun: Node3D
var _flash: MeshInstance3D
var _flash_time: float = 0.0
var _kick: float = 0.0
var _arms: FirstPersonArms  ## the arms and hands on the gun (FirstPersonArms)
var _model: WeaponModel  ## the gun's named parts (WeaponModel.build_parts)
var _ads_rest: Vector3 = ADS_FALLBACK
var _ads_tilt: float = 0.0  ## radians the gun tilts about its grip at full aim
var _hip_rest: Vector3 = REST
var _magazine: Array[String] = []  ## node names of the parts that drop in a reload
var _charge: Array[String] = []  ## node names of the charging handle or bolt
var _base: Dictionary = {}  ## node name -> rest position of an animated part
## 0 = hip, 1 = aiming down sights (set by the island each frame).
var aim: float = 0.0
## Reload progress 0..1 (0 when not reloading or the gun has no timed reload).
var reload: float = 0.0


static func create(id: StringName) -> ViewModel:
	var v := ViewModel.new()
	v.class_id = id if SoldierModel.PALETTES.has(id) else &"recruit"
	v.position = REST
	v.scale = Vector3.ONE * GUN_SCALE
	v.set_weapon(&"rifle")
	return v


## Rebuilds the gun when the weapon changes: the same WeaponModel as in the
## soldier's hands (realistic materials), plus a glove and sleeve.
func set_weapon(id: StringName) -> void:
	if id == weapon_id and _gun != null:
		return
	weapon_id = id
	_hip_rest = REST + (HIP_OFFSETS.get(id, Vector3.ZERO) as Vector3)
	position = _hip_rest
	if _gun != null:
		remove_child(_gun)
		_gun.queue_free()
	_gun = Node3D.new()
	add_child(_gun)
	var model := WeaponModel.build_parts(id)
	model.set_cast_shadow(GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	_gun.add_child(model)
	_model = model
	var layout: Dictionary = LAYOUT.get(model.weapon_id, {})
	_magazine = _parts_named(model, layout.get("magazine", []))
	_charge = _parts_named(model, layout.get("charge", []))
	_base.clear()
	for name: String in _magazine + _charge:
		_base[name] = (model.parts[name] as MeshInstance3D).position
	var sight: Dictionary = sight_rest(model, String(layout.get("front", "")), String(layout.get("rear", "")))
	_ads_rest = sight["position"]
	_ads_tilt = sight["tilt"]
	# The arms and hands: the right on the grip, the left on the weapon's support point.
	_arms = FirstPersonArms.build(SoldierModel.PALETTES[class_id], model.weapon_id)
	# Keep the visible fingers and the gun in the same authored metre space.
	_arms.set_support(model.support_point)
	for part: MeshInstance3D in _arms.find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_gun.add_child(_arms)
	tip = Node3D.new()
	tip.position = model.muzzle.position + Vector3(0, 0, -0.03)
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


## Gun-space offset of the magazine parts for a reload at progress `p`: out
## over the first 30 %, held, back in over the last 30 %.
static func reload_offset(p: float) -> Vector3:
	var drop: float = clampf(smoothstep(0.0, 0.3, p) - smoothstep(0.7, 1.0, p), 0.0, 1.0)
	return Vector3(0, -MAG_DROP * drop, 0)


## Gun-space offset of the charging handle: pulled back and released in the
## last fifth of the reload, so it reads as "chambering" the new magazine.
static func charge_offset(p: float) -> Vector3:
	var pull: float = sin(PI * clampf((p - 0.8) / 0.2, 0.0, 1.0))
	return Vector3(0, 0, CHARGE_PULL * pull)


## Sight alignment. The eye has to see the front sight through the rear one, so
## both must sit on the view's centre line. A gun held level keeps the rear
## sight a little off it (the sight line is not parallel to the bore), so the
## gun is tilted about its grip by the angle that levels the two sights. Returns
## the camera-space position at full aim, `tilt` (radians about X, applied while
## aiming) and the rear sight `EYE_TO_REAR` from the eye. Falls back when a sight
## is missing.
static func sight_rest(model: WeaponModel, front: String, rear: String) -> Dictionary:
	if front == "" or rear == "" or not model.parts.has(front) or not model.parts.has(rear):
		return {"position": ADS_FALLBACK, "tilt": 0.0}
	var f: Vector3 = _part_centre(model.parts[front] as MeshInstance3D)
	var r: Vector3 = _part_centre(model.parts[rear] as MeshInstance3D)
	var v: Vector3 = r - f
	var tilt: float = atan2(v.y, v.z)
	var basis := Basis(Vector3.RIGHT, tilt)
	var fr: Vector3 = basis * f
	var rr: Vector3 = basis * r
	var position := Vector3(-GUN_SCALE * fr.x, -GUN_SCALE * fr.y, -EYE_TO_REAR - GUN_SCALE * rr.z)
	return {"position": position, "tilt": tilt}


static func _part_centre(part: MeshInstance3D) -> Vector3:
	return part.transform * part.mesh.get_aabb().get_center()


## Node names of `model` that start with one of `prefixes`, in file order.
static func _parts_named(model: WeaponModel, prefixes: Array) -> Array[String]:
	var out: Array[String] = []
	for name: String in model.parts:
		for prefix: String in prefixes:
			if name.begins_with(prefix):
				out.append(name)
				break
	return out


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
	position = _hip_rest.lerp(_ads_rest, aim) + bob + Vector3(0, -pull_back * 0.3, pull_back + _kick * 0.035)
	rotation.x = _kick * 0.06 - near * 1.1  # negative: the barrel points down
	if _gun != null:
		_gun.rotation.x = _ads_tilt * aim  # levels the sights while aiming
	_animate_parts()


## The magazine drops and the charging handle is pulled during a reload; every
## part returns to its rest position when `reload` is 0.
func _animate_parts() -> void:
	if _model == null:
		return
	var drop: Vector3 = reload_offset(reload)
	for name: String in _magazine:
		(_model.parts[name] as MeshInstance3D).position = (_base[name] as Vector3) + drop
	var pull: Vector3 = charge_offset(reload)
	for name: String in _charge:
		(_model.parts[name] as MeshInstance3D).position = (_base[name] as Vector3) + pull
