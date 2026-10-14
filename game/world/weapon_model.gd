class_name WeaponModel
extends Node3D
## The five guns as blocky models (boxes, like the Recruit's delivered
## rifle) with realistic materials: Poly Haven gunmetal, polymer, walnut and
## rust. Used in the soldier's hands (SoldierModel: third person and the
## Armory) and in first person (ViewModel).
##
## Gun space: the origin is the top of the pistol grip, where the right
## hand holds it; the barrel points to -Z, +Y is up. `muzzle` is the tip.
## The rifle copies the delivered Recruit rifle's parts (recruit_v03.glb),
## so its muzzle lands on the GLB's own Muzzle node.

const TEX: String = "res://assets/textures/polyhaven/"
## The delivered rifle's grip, seen from its Muzzle node (SoldierModel mounts
## guns on the hand at the Muzzle's transform and offsets them by this).
const GRIP_FROM_MUZZLE: Vector3 = Vector3(0, -0.07, 0.6)
const IDS: Array[StringName] = [&"rifle", &"smg", &"machine_gun", &"shotgun", &"marksman"]

## Material presets: Poly Haven set, tint, metallic, roughness scale, texture
## repeats per metre (triplanar in each part's own space, so the texture
## sticks to the gun when it moves).
const MATERIALS: Dictionary = {
	"gunmetal": {"id": "blue_metal_plate", "tint": Color(0.42, 0.43, 0.46), "metal": 0.55, "rough": 0.9, "uv": 1.5},
	"steel": {"id": "blue_metal_plate", "tint": Color(0.5, 0.5, 0.52), "metal": 0.9, "rough": 0.6, "uv": 2.0},
	"polymer": {"id": "rubberized_track", "tint": Color(0.3, 0.3, 0.29), "metal": 0.0, "rough": 1.0, "uv": 1.2},
	"olive": {"id": "rubberized_track", "tint": Color(0.42, 0.44, 0.28), "metal": 0.0, "rough": 1.0, "uv": 1.2},
	"wood": {"id": "american_walnut_veneer", "tint": Color(0.72, 0.52, 0.38), "metal": 0.0, "rough": 0.75, "uv": 1.6},
	"rust": {"id": "rusty_metal_04", "tint": Color(0.55, 0.5, 0.48), "metal": 0.5, "rough": 1.0, "uv": 2.5},
	"bore": {"id": "", "tint": Color(0.02, 0.02, 0.02), "metal": 0.0, "rough": 0.6, "uv": 1.0},
}

static var _mats: Dictionary = {}

var weapon_id: StringName = &""
var muzzle: Node3D  ## the barrel's tip (flashes, tracers)
var length: float = 0.0  ## muzzle to butt (metres)


static func build(id: StringName) -> WeaponModel:
	var w := WeaponModel.new()
	w.weapon_id = id if id in IDS else &"rifle"
	w.name = "Weapon_" + String(w.weapon_id)
	w._build()
	return w


static func material(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var d: Dictionary = MATERIALS[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = d["tint"]
	m.metallic = d["metal"]
	m.roughness = d["rough"]
	var id: String = d["id"]
	if id != "" and ResourceLoader.exists(TEX + id + "_diffuse.res"):
		m.albedo_texture = load(TEX + id + "_diffuse.res") as Texture2D
		m.normal_enabled = true
		m.normal_texture = load(TEX + id + "_nor_gl.res") as Texture2D
		m.roughness_texture = load(TEX + id + "_rough.res") as Texture2D
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * float(d["uv"])
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_mats[key] = m
	return m


func _box(size: Vector3, center: Vector3, mat: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = center
	mi.rotation_degrees = rot_deg
	mi.material_override = material(mat)
	add_child(mi)
	return mi


func _tip(at: Vector3) -> void:
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = at
	add_child(muzzle)
	_box(Vector3(0.022, 0.022, 0.004), at + Vector3(0, 0, -0.001), "bore")
	var back: float = -INF
	for c in get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			back = maxf(back, mi.position.z + (mi.mesh as BoxMesh).size.z * 0.5)
	length = back - at.z


func _build() -> void:
	match weapon_id:
		&"smg":
			_smg()
		&"machine_gun":
			_machine_gun()
		&"shotgun":
			_shotgun()
		&"marksman":
			_marksman()
		_:
			_rifle()


## Assault rifle: the delivered Recruit rifle, part for part.
func _rifle() -> void:
	_box(Vector3(0.084, 0.11, 0.318), Vector3(0, 0.053, -0.057), "gunmetal")  # receiver
	_box(Vector3(0.077, 0.034, 0.339), Vector3(0, 0.117, -0.062), "steel")  # upper receiver / rail
	_box(Vector3(0.078, 0.09, 0.194), Vector3(0, 0.07, -0.3), "polymer")  # handguard
	_box(Vector3(0.035, 0.035, 0.176), Vector3(0, 0.07, -0.479), "steel")  # barrel
	_box(Vector3(0.053, 0.053, 0.048), Vector3(0, 0.07, -0.576), "gunmetal")  # muzzle brake
	_box(Vector3(0.033, 0.051, 0.032), Vector3(0, 0.13, -0.393), "gunmetal")  # front sight
	_box(Vector3(0.039, 0.032, 0.041), Vector3(0, 0.146, 0.05), "gunmetal")  # rear sight
	_box(Vector3(0.068, 0.215, 0.142), Vector3(0, -0.106, -0.155), "gunmetal", Vector3(8, 0, 0))  # magazine
	_box(Vector3(0.062, 0.139, 0.086), Vector3(0, -0.057, 0.011), "polymer", Vector3(-12, 0, 0))  # pistol grip
	_box(Vector3(0.03, 0.015, 0.106), Vector3(0, -0.036, -0.013), "gunmetal")  # trigger guard
	_box(Vector3(0.03, 0.058, 0.016), Vector3(0, -0.014, -0.061), "gunmetal")
	_box(Vector3(0.058, 0.065, 0.133), Vector3(0, 0.069, 0.161), "polymer")  # stock neck
	_box(Vector3(0.068, 0.127, 0.143), Vector3(0, 0.058, 0.272), "polymer")  # stock
	_box(Vector3(0.09, 0.142, 0.028), Vector3(0, 0.057, 0.346), "polymer")  # butt pad
	_tip(Vector3(0, 0.07, -0.6))


## SMG: compact, stamped receiver, curved magazine, retracted stock.
func _smg() -> void:
	_box(Vector3(0.06, 0.1, 0.34), Vector3(0, 0.06, -0.11), "gunmetal")  # receiver
	_box(Vector3(0.035, 0.025, 0.26), Vector3(0, 0.122, -0.11), "steel")  # top rail
	_box(Vector3(0.045, 0.04, 0.04), Vector3(0, 0.15, 0.03), "gunmetal")  # rear drum sight
	_box(Vector3(0.03, 0.045, 0.025), Vector3(0, 0.145, -0.25), "gunmetal")  # front sight
	_box(Vector3(0.068, 0.075, 0.15), Vector3(0, 0.045, -0.34), "polymer")  # handguard
	_box(Vector3(0.03, 0.03, 0.09), Vector3(0, 0.07, -0.46), "steel")  # barrel
	_box(Vector3(0.04, 0.04, 0.035), Vector3(0, 0.07, -0.51), "gunmetal")  # muzzle cap
	_box(Vector3(0.034, 0.2, 0.05), Vector3(0, -0.075, -0.215), "gunmetal", Vector3(14, 0, 0))  # magazine, raked forward
	_box(Vector3(0.05, 0.12, 0.07), Vector3(0, -0.05, 0.0), "polymer", Vector3(-15, 0, 0))  # grip
	_box(Vector3(0.025, 0.015, 0.08), Vector3(0, -0.01, -0.05), "gunmetal")  # trigger guard
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.012, 0.012, 0.15), Vector3(0.024 * side, 0.07, 0.12), "steel")  # stock rails
	_box(Vector3(0.06, 0.11, 0.025), Vector3(0, 0.05, 0.2), "polymer")  # butt plate
	_tip(Vector3(0, 0.07, -0.53))


## Machine gun: heavy receiver, rusty barrel shroud, carry handle, olive box
## magazine and a folded bipod.
func _machine_gun() -> void:
	_box(Vector3(0.09, 0.13, 0.38), Vector3(0, 0.06, -0.08), "gunmetal")  # receiver
	_box(Vector3(0.095, 0.04, 0.2), Vector3(0, 0.145, -0.12), "steel")  # feed cover
	_box(Vector3(0.03, 0.035, 0.14), Vector3(0, 0.215, -0.3), "polymer")  # carry handle
	_box(Vector3(0.025, 0.05, 0.025), Vector3(0, 0.18, -0.24), "gunmetal")
	_box(Vector3(0.025, 0.05, 0.025), Vector3(0, 0.18, -0.36), "gunmetal")
	_box(Vector3(0.065, 0.065, 0.24), Vector3(0, 0.07, -0.4), "rust")  # barrel shroud
	_box(Vector3(0.08, 0.05, 0.2), Vector3(0, 0.0, -0.36), "polymer")  # handguard
	_box(Vector3(0.036, 0.036, 0.14), Vector3(0, 0.07, -0.59), "steel")  # barrel
	_box(Vector3(0.046, 0.046, 0.05), Vector3(0, 0.07, -0.685), "gunmetal")  # flash hider
	for side: float in [-1.0, 1.0]:
		_box(Vector3(0.014, 0.014, 0.28), Vector3(0.022 * side, 0.035, -0.52), "gunmetal")  # bipod legs
	_box(Vector3(0.11, 0.13, 0.14), Vector3(-0.01, -0.1, -0.15), "olive")  # box magazine
	_box(Vector3(0.055, 0.13, 0.075), Vector3(0, -0.06, 0.02), "polymer", Vector3(-12, 0, 0))  # grip
	_box(Vector3(0.025, 0.015, 0.08), Vector3(0, -0.01, -0.03), "gunmetal")
	_box(Vector3(0.07, 0.12, 0.2), Vector3(0, 0.04, 0.2), "polymer")  # stock
	_box(Vector3(0.08, 0.15, 0.03), Vector3(0, 0.03, 0.315), "polymer")  # butt
	_tip(Vector3(0, 0.07, -0.71))


## Pump shotgun: walnut stock and forend, long barrel over the tube magazine.
func _shotgun() -> void:
	_box(Vector3(0.065, 0.1, 0.22), Vector3(0, 0.06, -0.08), "gunmetal")  # receiver
	_box(Vector3(0.036, 0.036, 0.5), Vector3(0, 0.092, -0.44), "steel")  # barrel
	_box(Vector3(0.032, 0.032, 0.4), Vector3(0, 0.048, -0.39), "gunmetal")  # tube magazine
	_box(Vector3(0.06, 0.062, 0.16), Vector3(0, 0.05, -0.36), "wood")  # pump
	_box(Vector3(0.01, 0.012, 0.01), Vector3(0, 0.116, -0.68), "steel")  # bead sight
	_box(Vector3(0.025, 0.015, 0.08), Vector3(0, -0.005, -0.04), "gunmetal")  # trigger guard
	_box(Vector3(0.052, 0.075, 0.13), Vector3(0, 0.025, 0.08), "wood", Vector3(-10, 0, 0))  # wrist
	_box(Vector3(0.056, 0.125, 0.19), Vector3(0, 0.005, 0.22), "wood")  # stock
	_box(Vector3(0.06, 0.14, 0.03), Vector3(0, 0.0, 0.33), "polymer")  # recoil pad
	_tip(Vector3(0, 0.092, -0.69))


## Marksman rifle: full walnut stock, long barrel, scope on two rings.
func _marksman() -> void:
	_box(Vector3(0.062, 0.085, 0.55), Vector3(0, 0.03, -0.12), "wood")  # fore stock
	_box(Vector3(0.058, 0.13, 0.22), Vector3(0, 0.0, 0.25), "wood")  # butt stock
	_box(Vector3(0.064, 0.14, 0.02), Vector3(0, 0.0, 0.37), "gunmetal")  # butt plate
	_box(Vector3(0.055, 0.05, 0.25), Vector3(0, 0.095, -0.08), "gunmetal")  # receiver
	_box(Vector3(0.03, 0.03, 0.32), Vector3(0, 0.09, -0.52), "steel")  # barrel
	_box(Vector3(0.042, 0.042, 0.06), Vector3(0, 0.09, -0.71), "gunmetal")  # flash hider
	_box(Vector3(0.02, 0.02, 0.2), Vector3(0, 0.058, -0.45), "gunmetal")  # gas cylinder
	_box(Vector3(0.05, 0.12, 0.09), Vector3(0, -0.06, -0.12), "gunmetal")  # magazine
	_box(Vector3(0.025, 0.015, 0.08), Vector3(0, -0.02, -0.02), "gunmetal")  # trigger guard
	_box(Vector3(0.04, 0.04, 0.3), Vector3(0, 0.175, -0.1), "gunmetal")  # scope tube
	_box(Vector3(0.056, 0.056, 0.06), Vector3(0, 0.175, -0.27), "gunmetal")  # objective
	_box(Vector3(0.05, 0.05, 0.05), Vector3(0, 0.175, 0.07), "gunmetal")  # eyepiece
	_box(Vector3(0.026, 0.03, 0.026), Vector3(0, 0.205, -0.1), "steel")  # turret
	_box(Vector3(0.03, 0.04, 0.025), Vector3(0, 0.135, -0.17), "steel")  # rings
	_box(Vector3(0.03, 0.04, 0.025), Vector3(0, 0.135, 0.0), "steel")
	_tip(Vector3(0, 0.09, -0.74))


## First person: no shadows from the gun at the eye.
func set_cast_shadow(mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	for c in get_children():
		if c is MeshInstance3D:
			(c as MeshInstance3D).cast_shadow = mode
