class_name SoldierModel
extends Node3D
## Low-poly armoured contractor built from boxes (no external assets), in the
## style of the Armory portrait: helmet with a dark visor, plate carrier with
## pouches, shoulder pads, knee pads, boots and a rifle held across the
## chest. Faces -Z, feet at y = 0, about 1.9 m tall.
##
## Variants per class:
##   recruit  - tan/khaki kit, assault rifle.
##   vanguard - dark olive heavy armour (bigger pads, face shield), shotgun.
##
## animate() swings legs and arms from pivots (hips/shoulders) so walking
## reads without skeletal animation. Real rigged models (e.g. Quaternius,
## CC0) can replace this later; see docs/tech/ASSETS.md.

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
	var heavy: bool = class_id == &"vanguard"
	var pad: float = 1.25 if heavy else 1.0
	# Legs hang from hip pivots so they can swing.
	_leg_l = _leg(Vector3(-0.14, 0.92, 0), pad)
	_leg_r = _leg(Vector3(0.14, 0.92, 0), pad)
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
	_arm_pivot.position = Vector3(0, 1.52, 0)
	add_child(_arm_pivot)
	for side in [-1.0, 1.0]:
		_box(_arm_pivot, Vector3(0.2 * pad, 0.16, 0.24 * pad), Vector3(0.31 * side, 0.04, 0), "armor")  # shoulder pad
		_box(_arm_pivot, Vector3(0.13, 0.3, 0.13), Vector3(0.31 * side, -0.16, -0.02), "cloth", Vector3(25, 0, 0))  # upper arm
	_box(_arm_pivot, Vector3(0.11, 0.11, 0.3), Vector3(0.26, -0.3, -0.2), "cloth", Vector3(0, -20, 0))  # right forearm
	_box(_arm_pivot, Vector3(0.11, 0.11, 0.34), Vector3(-0.2, -0.26, -0.24), "cloth", Vector3(0, 25, 0))  # left forearm
	_box(_arm_pivot, Vector3(0.09, 0.09, 0.09), Vector3(0.18, -0.3, -0.36), "dark")  # gloves
	_box(_arm_pivot, Vector3(0.09, 0.09, 0.09), Vector3(-0.06, -0.26, -0.46), "dark")
	_gun(heavy)


func _leg(hip: Vector3, pad: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = hip
	add_child(pivot)
	_box(pivot, Vector3(0.18, 0.44, 0.2), Vector3(0, -0.22, 0), "cloth")  # thigh
	_box(pivot, Vector3(0.15, 0.42, 0.17), Vector3(0, -0.62, 0), "cloth")  # shin
	_box(pivot, Vector3(0.17 * pad, 0.13, 0.08), Vector3(0, -0.45, -0.11), "armor")  # knee pad
	_box(pivot, Vector3(0.17, 0.12, 0.3), Vector3(0, -0.86, -0.04), "dark")  # boot
	return pivot


## Rifle (recruit) or shotgun (vanguard), held diagonally across the chest.
func _gun(shotgun: bool) -> void:
	var gun := Node3D.new()
	gun.position = Vector3(0.08, -0.26, -0.38)
	gun.rotation_degrees = Vector3(0, -8, 0)
	_arm_pivot.add_child(gun)
	var length: float = 0.62 if shotgun else 0.78
	_box(gun, Vector3(0.07, 0.11, length), Vector3(0, 0, 0), "gun")  # receiver + barrel
	_box(gun, Vector3(0.06, 0.12, 0.24), Vector3(0, -0.02, length * 0.5 + 0.1), "gun")  # stock
	if shotgun:
		_box(gun, Vector3(0.09, 0.08, 0.3), Vector3(0, -0.08, -0.12), "dark")  # pump
	else:
		_box(gun, Vector3(0.05, 0.16, 0.08), Vector3(0, -0.12, -0.04), "gun")  # magazine
		_box(gun, Vector3(0.05, 0.05, 0.14), Vector3(0, 0.08, 0.02), "dark")  # sight
	muzzle = Node3D.new()
	muzzle.position = Vector3(0, 0, -length * 0.5 - 0.05)
	gun.add_child(muzzle)


## First person: the body is not drawn but still casts its shadow.
func set_shadow_only(on: bool) -> void:
	var mode: GeometryInstance3D.ShadowCastingSetting = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if on else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	for n in find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).cast_shadow = mode


## Walk cycle: `speed` 0..1 (fraction of top speed), `t` seconds.
func animate(speed: float, t: float) -> void:
	var swing: float = sin(t * 9.0) * 0.6 * clampf(speed, 0.0, 1.0)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_pivot.position.y = 1.52 + absf(sin(t * 9.0)) * 0.03 * speed
