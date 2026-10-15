class_name EscortModel
extends Node3D
## The Escort's moving objective, blocky like the guns (WeaponModel) and with
## the same kind of realistic materials (Poly Haven): a mine cart (a rusted
## steel tub on a timber frame, four steel wheels that turn as it rolls, a
## push handle, crates under a linen tarp) or a survivor (orange jersey,
## denim, leather boots, a bandaged head) who walks the route.
##
## Model space: the origin is on the ground at the model's centre, it faces
## -Z (the way it travels), +Y is up. set_motion() animates it.

const TEX: String = WeaponModel.TEX
const WHEEL_RADIUS: float = 0.22
## Cloth and skin for the survivor (same layout as WeaponModel.MATERIALS:
## Poly Haven set, tint, metallic, roughness, texture repeats per metre).
const MATERIALS: Dictionary = {
	"jersey": {"id": "cotton_jersey", "tint": Color(1.0, 0.55, 0.18), "metal": 0.0, "rough": 1.0, "uv": 2.0},
	"denim": {"id": "denim_fabric_06", "tint": Color(0.62, 0.68, 0.82), "metal": 0.0, "rough": 1.0, "uv": 2.0},
	"leather": {"id": "fabric_leather_02", "tint": Color(0.45, 0.32, 0.22), "metal": 0.0, "rough": 0.8, "uv": 2.0},
	"linen": {"id": "rough_linen", "tint": Color(0.72, 0.66, 0.5), "metal": 0.0, "rough": 1.0, "uv": 1.5},
	"skin": {"id": "", "tint": Color(0.86, 0.66, 0.52), "metal": 0.0, "rough": 0.7, "uv": 1.0},
	"hair": {"id": "", "tint": Color(0.17, 0.12, 0.09), "metal": 0.0, "rough": 0.9, "uv": 1.0},
	"bandage": {"id": "", "tint": Color(0.92, 0.9, 0.84), "metal": 0.0, "rough": 0.9, "uv": 1.0},
}

static var _mats: Dictionary = {}

var survivor: bool = false
## The part that tilts or lies down (the whole model but its shadow-free
## root), the cart's wheels and the survivor's limbs (pivots at the joints).
var body: Node3D
var wheels: Array[Node3D] = []
var legs: Array[Node3D] = []
var arms: Array[Node3D] = []


static func cart() -> EscortModel:
	var m := EscortModel.new()
	m.name = "EscortCart"
	m._build_cart()
	return m


static func survivor_model() -> EscortModel:
	var m := EscortModel.new()
	m.name = "EscortSurvivor"
	m.survivor = true
	m._build_survivor()
	return m


## Cloth keys from MATERIALS; any other key is a WeaponModel material
## (rust, steel, gunmetal, wood...).
static func material(key: String) -> StandardMaterial3D:
	if not MATERIALS.has(key):
		return WeaponModel.material(key)
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


## `travelled`: metres along the route (wheels turn, legs swing with it);
## `moving`: it is under way now; `broken`: broken down (the cart sags on a
## lost wheel, the survivor lies on the ground); `t`: seconds, for idling.
func set_motion(travelled: float, moving: bool, broken: bool, t: float) -> void:
	if survivor:
		var swing: float = sin(travelled * 2.4) * 0.55 if moving else 0.0
		for k in legs.size():
			legs[k].rotation.x = swing * (1.0 if k == 0 else -1.0)
		for k in arms.size():
			arms[k].rotation.x = -swing * 0.7 * (1.0 if k == 0 else -1.0) + (0.0 if moving else sin(t * 1.3 + k) * 0.04)
		# Broken = down: lying on the side, on the ground.
		body.rotation = Vector3(0, 0, PI * 0.5) if broken else Vector3.ZERO
		body.position = Vector3(0.25, 0.18, 0) if broken else Vector3.ZERO
		return
	for w in wheels:
		w.rotation.x = -travelled / WHEEL_RADIUS
	# Broken: the front left wheel is off and the cart sags onto that corner.
	wheels[0].visible = not broken
	body.rotation = Vector3(-0.08, 0, 0.14) if broken else Vector3.ZERO


func _box(parent: Node3D, size: Vector3, center: Vector3, mat: String, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = center
	mi.rotation_degrees = rot_deg
	mi.material_override = material(mat)
	parent.add_child(mi)
	return mi


func _build_cart() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	# Timber frame: two long beams and the cross pieces the axles hang from.
	for x: float in [-0.42, 0.42]:
		_box(body, Vector3(0.12, 0.12, 1.75), Vector3(x, 0.36, 0), "wood")
	for z: float in [-0.55, 0.55]:
		_box(body, Vector3(0.96, 0.1, 0.14), Vector3(0, 0.33, z), "wood")
		var axle := MeshInstance3D.new()
		var am := CylinderMesh.new()
		am.top_radius = 0.035
		am.bottom_radius = 0.035
		am.height = 1.12
		axle.mesh = am
		axle.position = Vector3(0, WHEEL_RADIUS, z)
		axle.rotation_degrees.z = 90.0
		axle.material_override = material("steel")
		body.add_child(axle)
	# Wheels: a steel disc each with a hub bar across it, so the turning
	# reads in every camera. Order: front left, front right, back left, back
	# right (front = -Z).
	for z: float in [-0.55, 0.55]:
		for x: float in [-0.54, 0.54]:
			var pivot := Node3D.new()
			pivot.position = Vector3(x, WHEEL_RADIUS, z)
			var disc := MeshInstance3D.new()
			var dm := CylinderMesh.new()
			dm.top_radius = WHEEL_RADIUS
			dm.bottom_radius = WHEEL_RADIUS
			dm.height = 0.07
			dm.radial_segments = 14
			disc.mesh = dm
			disc.rotation_degrees.z = 90.0
			disc.material_override = material("gunmetal")
			pivot.add_child(disc)
			_box(pivot, Vector3(0.09, 0.05, WHEEL_RADIUS * 1.9), Vector3(signf(x) * 0.03, 0, 0), "rust")
			body.add_child(pivot)
			wheels.append(pivot)
	# The tub: rusted steel, floor and four walls, steel rims on top.
	var tub_y: float = 0.47
	_box(body, Vector3(1.0, 0.07, 1.45), Vector3(0, tub_y, 0), "rust")
	for x: float in [-0.5, 0.5]:
		_box(body, Vector3(0.06, 0.55, 1.45), Vector3(x, tub_y + 0.27, 0), "rust")
		_box(body, Vector3(0.09, 0.05, 1.5), Vector3(x, tub_y + 0.56, 0), "steel")
	for z: float in [-0.72, 0.72]:
		_box(body, Vector3(1.0, 0.55, 0.06), Vector3(0, tub_y + 0.27, z), "rust")
		_box(body, Vector3(1.05, 0.05, 0.09), Vector3(0, tub_y + 0.56, z), "steel")
	# Cargo: two crates under a linen tarp.
	_box(body, Vector3(0.55, 0.4, 0.5), Vector3(-0.15, tub_y + 0.24, -0.3), "wood", Vector3(0, 8, 0))
	_box(body, Vector3(0.45, 0.32, 0.45), Vector3(0.17, tub_y + 0.2, 0.35), "wood", Vector3(0, -12, 0))
	_box(body, Vector3(0.9, 0.06, 1.25), Vector3(0, tub_y + 0.52, 0), "linen", Vector3(3, 0, -2))
	# Push handle at the back (+Z): two timber arms and a bar.
	for x: float in [-0.36, 0.36]:
		_box(body, Vector3(0.07, 0.07, 0.55), Vector3(x, tub_y + 0.62, 0.95), "wood", Vector3(-25, 0, 0))
	_box(body, Vector3(0.82, 0.08, 0.08), Vector3(0, tub_y + 0.74, 1.2), "wood")


func _build_survivor() -> void:
	body = Node3D.new()
	body.name = "Body"
	add_child(body)
	# Legs (pivot at the hip) with boots.
	for x: float in [-0.12, 0.12]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.9, 0)
		_box(hip, Vector3(0.17, 0.82, 0.19), Vector3(0, -0.41, 0), "denim")
		_box(hip, Vector3(0.19, 0.12, 0.3), Vector3(0, -0.84, -0.05), "leather")
		body.add_child(hip)
		legs.append(hip)
	# Torso, a satchel strap, the head with hair and a bandage.
	_box(body, Vector3(0.46, 0.62, 0.27), Vector3(0, 1.22, 0), "jersey")
	_box(body, Vector3(0.06, 0.66, 0.29), Vector3(0, 1.22, 0), "leather", Vector3(0, 0, 32))
	_box(body, Vector3(0.24, 0.27, 0.25), Vector3(0, 1.69, 0), "skin")
	_box(body, Vector3(0.26, 0.08, 0.27), Vector3(0, 1.84, 0.01), "hair")
	_box(body, Vector3(0.27, 0.06, 0.27), Vector3(0, 1.76, 0), "bandage", Vector3(0, 0, -6))
	# Arms (pivot at the shoulder) with hands.
	for x: float in [-0.3, 0.3]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(x, 1.5, 0)
		_box(shoulder, Vector3(0.13, 0.6, 0.15), Vector3(0, -0.3, 0), "jersey")
		_box(shoulder, Vector3(0.11, 0.12, 0.12), Vector3(0, -0.66, 0), "skin")
		body.add_child(shoulder)
		arms.append(shoulder)
