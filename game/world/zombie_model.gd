class_name ZombieModel
extends RefCounted
## The common zombie: blocky like the Recruit (boxes, ~1.95 m), but with
## realistic materials (Poly Haven PBR: skin, cotton jersey, denim, leather,
## linen) and procedural gore in zombie.gdshader.
##
## Built in code as one ArrayMesh per variant: each box carries its part id
## (which joint it turns about), gore amount and seed in CUSTOM0 and its
## tint in CUSTOM1. The shader poses the parts from the per-instance data,
## so a whole horde is one MultiMesh per variant (ZombieHordeView).
##
## Model space: feet on y = 0, facing +Z, left side on +X. Built for an
## EnemyType of height 1.7 (the Walker); the view scales it by
## height / MODEL_HEIGHT like the old capsule, so the head stays where
## IslandRun.enemy_head() puts it.

enum Part { PELVIS, TORSO, HEAD, ARM_UPPER_L, ARM_LOWER_L, ARM_UPPER_R, ARM_LOWER_R, LEG_UPPER_L, LEG_LOWER_L, LEG_UPPER_R, LEG_LOWER_R }
enum Layer { SKIN, JERSEY, DENIM, LEATHER, LINEN }
enum Kind { SURFACE, FLESH, BONE, EYE, MOUTH }

const VARIANTS: int = 4
const VARIANT_NAMES: Array[String] = ["civilian", "worker", "jacket", "shirtless"]
const MODEL_HEIGHT: float = 1.7
## Centre of the skull box in the rest pose (model space); with the jaw the
## head spans 1.61-1.93 m. IslandRun.enemy_head() aims at height + 0.08 m:
## 1.78 m for the Walker.
const HEAD_CENTER: Vector3 = Vector3(0, 1.8, 0.03)
const SHADER: String = "res://game/world/zombie.gdshader"
const TEX: String = "res://assets/textures/polyhaven/"
## Poly Haven texture set, texture repeats per metre, cloth (tears show
## skin), rot blotches, grime.
const LAYERS: Array[Dictionary] = [
	{"id": "leather_white", "uv": 3.0, "cloth": 0.0, "rot": 1.0, "dirt": 0.25},
	{"id": "cotton_jersey", "uv": 3.0, "cloth": 1.0, "rot": 0.0, "dirt": 0.5},
	{"id": "denim_fabric_06", "uv": 2.5, "cloth": 1.0, "rot": 0.0, "dirt": 0.4},
	{"id": "fabric_leather_02", "uv": 2.0, "cloth": 1.0, "rot": 0.0, "dirt": 0.3},
	{"id": "rough_linen", "uv": 3.0, "cloth": 1.0, "rot": 0.0, "dirt": 0.5},
]
const SKIN_TINT: Color = Color(0.74, 0.78, 0.66)  # grey-green, dead

## Joints of zombie.gdshader (keep both in sync).
const WAIST: Vector3 = Vector3(0, 1.02, 0)
const NECK: Vector3 = Vector3(0, 1.58, 0.02)

static var _meshes: Array[ArrayMesh] = []
static var _materials: Array[ShaderMaterial] = []


## A stable variant from any per-enemy number (the horde uses the enemy's
## rolled base speed, which travels with it when indices are compacted).
static func variant_for(key: float) -> int:
	return posmod(hash(snappedf(key, 0.0001)), VARIANTS)


## The shared mesh of one variant (built once, then cached).
static func mesh(variant: int) -> ArrayMesh:
	if _meshes.is_empty():
		for v in VARIANTS:
			_meshes.append(_build_mesh(v))
	return _meshes[clampi(variant, 0, VARIANTS - 1)]


## Where the shader puts the skull centre (model space) for a pose: the
## same head, torso and root rotations as zombie.gdshader, so tests can check
## the drawn head stays near IslandRun.enemy_head() while walking.
static func head_pose(walk: float, lunge: float, flinch: float, phase: float) -> Vector3:
	var s: float = sin(phase)
	var p: Vector3 = HEAD_CENTER
	var loll: float = 0.22 * sin(phase * 0.5) + 0.1
	var head := Basis(Vector3.FORWARD, -loll) * Basis(Vector3.RIGHT, -0.18 - 0.55 * flinch + 0.2 * lunge)
	p = NECK + head * (p - NECK)
	var lean: float = 0.18 + 0.08 * walk + 0.4 * lunge - 0.5 * flinch
	p = WAIST + (Basis(Vector3.RIGHT, lean) * Basis(Vector3.UP, 0.14 * walk * s)) * (p - WAIST)
	p = Basis(Vector3.FORWARD, -(0.05 * walk * s)) * p
	return p + Vector3(0, 0.04 * walk * absf(s), 0.2 * lunge)


## One material per texture layer, shared by every variant.
static func material(layer: int) -> ShaderMaterial:
	if _materials.is_empty():
		var shader := load(SHADER) as Shader
		for l: Dictionary in LAYERS:
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter(&"albedo_tex", _texture(l["id"], "diffuse"))
			m.set_shader_parameter(&"normal_tex", _texture(l["id"], "nor_gl"))
			m.set_shader_parameter(&"rough_tex", _texture(l["id"], "rough"))
			m.set_shader_parameter(&"uv_scale", l["uv"])
			m.set_shader_parameter(&"is_cloth", l["cloth"])
			m.set_shader_parameter(&"rot", l["rot"])
			m.set_shader_parameter(&"dirt", l["dirt"])
			_materials.append(m)
	return _materials[layer]


static func _texture(id: String, map: String) -> Texture2D:
	var path: String = TEX + "%s_%s.res" % [id, map]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The boxes of one variant: {c: centre, s: size, part, layer, tint, gore
## (0..1), kind, seed}. Tests read them; _build_mesh turns them into a mesh.
static func boxes(variant: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seed: float = 3.1 + variant * 7.7
	var skin: Color = SKIN_TINT
	var add := func(c: Vector3, s: Vector3, part: int, layer: int, tint: Color, gore: float = 0.0, kind: int = Kind.SURFACE) -> void:
		out.append({"c": c, "s": s, "part": part, "layer": layer, "tint": tint, "gore": gore, "kind": kind, "seed": seed})
	var shirt_layer: int = Layer.JERSEY
	var shirt: Color = Color(0.86, 0.83, 0.74)
	var legs_layer: int = Layer.DENIM
	var legs: Color = Color.WHITE
	var shoes: Color = Color(0.45, 0.33, 0.25)
	match variant:
		1:
			shirt_layer = Layer.LINEN
			shirt = Color(0.42, 0.45, 0.5)
			legs = Color(0.7, 0.72, 0.75)
			shoes = Color(0.55, 0.42, 0.3)
		2:
			shirt_layer = Layer.LEATHER
			shirt = Color(0.42, 0.36, 0.33)
			legs = Color(1.05, 1.1, 1.2)
			shoes = Color(0.3, 0.27, 0.25)
		3:
			shirt_layer = Layer.SKIN
			shirt = skin
			legs_layer = Layer.JERSEY  # khaki chinos
			legs = Color(0.78, 0.68, 0.48)
	# Legs: thighs and shins hang from the hips and knees (shin + foot move together).
	for side: float in [1.0, -1.0]:
		var left: bool = side > 0.0
		var thigh: int = Part.LEG_UPPER_L if left else Part.LEG_UPPER_R
		var shin: int = Part.LEG_LOWER_L if left else Part.LEG_LOWER_R
		var x: float = 0.12 * side
		add.call(Vector3(x, 0.71, 0), Vector3(0.17, 0.44, 0.18), thigh, legs_layer, legs, 0.35 if variant == 0 and left else 0.15)
		var bare_shin: bool = variant == 3 and not left  # trouser leg torn off
		add.call(Vector3(x, 0.31, 0), Vector3(0.15, 0.42, 0.16), shin, Layer.SKIN if bare_shin else legs_layer, skin if bare_shin else legs, 0.75 if bare_shin else 0.1)
		if variant == 3:
			add.call(Vector3(x, 0.045, 0.04), Vector3(0.13, 0.09, 0.25), shin, Layer.SKIN, skin, 0.3)  # bare feet
		elif variant == 1:
			add.call(Vector3(x, 0.15, 0.0), Vector3(0.165, 0.3, 0.175), shin, Layer.LEATHER, shoes)  # work boots
			add.call(Vector3(x, 0.05, 0.05), Vector3(0.16, 0.1, 0.27), shin, Layer.LEATHER, shoes)
		else:
			add.call(Vector3(x, 0.05, 0.05), Vector3(0.15, 0.1, 0.27), shin, Layer.LEATHER, shoes)
	# Pelvis and belt.
	add.call(Vector3(0, 0.97, 0), Vector3(0.42, 0.2, 0.22), Part.PELVIS, legs_layer, legs, 0.1)
	add.call(Vector3(0, 1.06, 0), Vector3(0.44, 0.05, 0.235), Part.PELVIS, Layer.LEATHER, Color(0.3, 0.25, 0.22))
	# Torso.
	var torso_gore: float = [0.85, 0.6, 0.5, 0.95][variant]
	add.call(Vector3(0, 1.3, 0), Vector3(0.46, 0.5, 0.26), Part.TORSO, shirt_layer, shirt, torso_gore)
	if variant == 2:
		# Open leather jacket over a red T-shirt soaked from the jaw down.
		add.call(Vector3(0, 1.29, 0.132), Vector3(0.16, 0.46, 0.012), Part.TORSO, Layer.JERSEY, Color(0.75, 0.2, 0.18), 0.95)
		add.call(Vector3(0, 1.53, -0.02), Vector3(0.48, 0.06, 0.29), Part.TORSO, Layer.LEATHER, shirt)  # collar
	if variant == 3:
		# Torn-open flank: ragged flesh with ribs showing through.
		add.call(Vector3(-0.04, 1.24, 0.131), Vector3(0.22, 0.14, 0.012), Part.TORSO, Layer.SKIN, skin, 0.0, Kind.FLESH)
		add.call(Vector3(0.04, 1.14, 0.131), Vector3(0.12, 0.08, 0.012), Part.TORSO, Layer.SKIN, skin, 0.0, Kind.FLESH)
		for k in 3:
			add.call(Vector3(-0.12 + k * 0.06, 1.24 + k * 0.012, 0.137), Vector3(0.05, 0.016, 0.012), Part.TORSO, Layer.SKIN, skin, 0.0, Kind.BONE)  # ribs
	add.call(Vector3(0, 1.585, 0.01), Vector3(0.12, 0.09, 0.12), Part.TORSO, Layer.SKIN, skin, 0.6 if variant == 2 else 0.25)
	# Arms: upper arm about the shoulder, forearm + hand about the elbow.
	for side: float in [1.0, -1.0]:
		var left: bool = side > 0.0
		var upper: int = Part.ARM_UPPER_L if left else Part.ARM_UPPER_R
		var lower: int = Part.ARM_LOWER_L if left else Part.ARM_LOWER_R
		var x: float = 0.29 * side
		var sleeve_layer: int = shirt_layer
		var sleeve: Color = shirt
		add.call(Vector3(x, 1.34, 0), Vector3(0.12, 0.32, 0.13), upper, sleeve_layer, sleeve, 0.4 if variant == 1 and left else 0.2)
		if variant == 1 and left:
			# Missing forearm: a ragged stump with the bone sticking out.
			add.call(Vector3(x, 1.172, 0), Vector3(0.11, 0.025, 0.12), upper, Layer.SKIN, skin, 0.0, Kind.FLESH)
			add.call(Vector3(x + 0.01, 1.13, 0.01), Vector3(0.035, 0.08, 0.035), upper, Layer.SKIN, skin, 0.0, Kind.BONE)
			continue
		var long_sleeve: bool = variant == 1 or variant == 2
		var bite: float = 0.6 if variant == 0 and not left else 0.25
		add.call(Vector3(x, 1.05, 0), Vector3(0.105, 0.28, 0.115), lower, sleeve_layer if long_sleeve else Layer.SKIN, sleeve if long_sleeve else skin, bite)
		add.call(Vector3(x, 0.855, 0.01), Vector3(0.095, 0.13, 0.11), lower, Layer.SKIN, skin, 0.3)  # hand
	# Head: skull, jaw, face details; the jaw is half missing on variant 2.
	add.call(Vector3(0, 1.8, 0.03), Vector3(0.26, 0.24, 0.27), Part.HEAD, Layer.SKIN, skin, [0.3, 0.45, 0.4, 0.65][variant])
	if variant == 2:
		# The lower jaw is gone: upper teeth over a raw underside, tongue hanging.
		add.call(Vector3(0, 1.672, 0.06), Vector3(0.2, 0.025, 0.19), Part.HEAD, Layer.SKIN, skin, 0.0, Kind.FLESH)
		add.call(Vector3(0, 1.682, 0.147), Vector3(0.14, 0.03, 0.03), Part.HEAD, Layer.SKIN, skin, 0.0, Kind.BONE)  # teeth
		add.call(Vector3(0.01, 1.63, 0.1), Vector3(0.055, 0.07, 0.035), Part.HEAD, Layer.SKIN, skin, 0.0, Kind.FLESH)  # tongue
		add.call(Vector3(0.09, 1.655, 0.04), Vector3(0.03, 0.05, 0.1), Part.HEAD, Layer.SKIN, skin, 0.0, Kind.BONE)  # jaw stub
	else:
		add.call(Vector3(0, 1.65, 0.06), Vector3(0.22, 0.08, 0.2), Part.HEAD, Layer.SKIN, skin, 0.35)
		add.call(Vector3(0, 1.665, 0.161), Vector3(0.12, 0.03, 0.01), Part.HEAD, Layer.SKIN, skin, 0.0, Kind.MOUTH)
	for side: float in [1.0, -1.0]:
		add.call(Vector3(0.06 * side, 1.82, 0.165), Vector3(0.055, 0.035, 0.01), Part.HEAD, Layer.SKIN, skin, 0.0, Kind.EYE)
		add.call(Vector3(0.06 * side, 1.85, 0.17), Vector3(0.08, 0.025, 0.02), Part.HEAD, Layer.SKIN, skin * 0.7)  # brow
		add.call(Vector3(0.143 * side, 1.79, 0.02), Vector3(0.03, 0.06, 0.05), Part.HEAD, Layer.SKIN, skin)  # ear
	add.call(Vector3(0, 1.755, 0.175), Vector3(0.04, 0.06, 0.03), Part.HEAD, Layer.SKIN, skin)  # nose
	if variant != 3:
		# Patchy hair (variant 3 is bald with a scalp wound).
		var hair: Color = [Color(0.25, 0.2, 0.16), Color(0.2, 0.2, 0.2), Color(0.12, 0.1, 0.09)][variant]
		add.call(Vector3(0.02, 1.93, 0.0), Vector3(0.24, 0.04, 0.24), Part.HEAD, Layer.LEATHER, hair)
		add.call(Vector3(0, 1.85, -0.11), Vector3(0.27, 0.12, 0.06), Part.HEAD, Layer.LEATHER, hair)
	return out


static func _build_mesh(variant: int) -> ArrayMesh:
	var by_layer: Dictionary = {}
	for b: Dictionary in boxes(variant):
		var l: int = b["layer"]
		if not by_layer.has(l):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
			st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
			by_layer[l] = st
		_add_box(by_layer[l], b, variant)
	var m := ArrayMesh.new()
	var layers: Array = by_layer.keys()
	layers.sort()
	for l: int in layers:
		var st: SurfaceTool = by_layer[l]
		st.generate_tangents()
		st.commit(m)
		m.surface_set_material(m.get_surface_count() - 1, material(l))
	return m


## Six faces, UVs in metres from the rest position (the shader scales them),
## so every box shows the texture at the same density, like real cloth.
static func _add_box(st: SurfaceTool, b: Dictionary, variant: int) -> void:
	var c: Vector3 = b["c"]
	var h: Vector3 = (b["s"] as Vector3) * 0.5
	var tint: Color = b["tint"]
	var hangs: float = 1.0 if variant == 1 else 0.0
	var info := Color(float(b["part"]), float(b["seed"]), float(b["gore"]), float(b["kind"]))
	var extra := Color(tint.r, tint.g, tint.b, hangs)
	var shift := Vector2(c.x * 1.7 + c.y * 0.3, c.z * 2.3 + c.y)  # avoids repeated patterns between boxes
	for axis in 3:
		for sgn: float in [1.0, -1.0]:
			var n := Vector3.ZERO
			n[axis] = sgn
			var u_axis := Vector3.ZERO
			var v_axis := Vector3.ZERO
			if axis == 1:
				u_axis = Vector3(1, 0, 0)
				v_axis = Vector3(0, 0, sgn)
			else:
				u_axis = Vector3(0, 0, -sgn) if axis == 0 else Vector3(sgn, 0, 0)
				v_axis = Vector3(0, -1, 0)
			var corners: Array[Vector3] = []
			for k in 4:
				var du: float = -1.0 if k == 0 or k == 3 else 1.0
				var dv: float = -1.0 if k < 2 else 1.0
				corners.append(c + n * h[axis] + u_axis * (absf(u_axis.dot(h)) * du) + v_axis * (absf(v_axis.dot(h)) * dv))
			var order: Array[int] = [0, 1, 2, 0, 2, 3]
			# Clockwise when seen from outside (Godot's front faces).
			var face_n: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0])
			if face_n.dot(n) > 0.0:
				order = [0, 2, 1, 0, 3, 2]
			for k: int in order:
				var p: Vector3 = corners[k]
				st.set_normal(n)
				st.set_uv(Vector2(p.dot(u_axis), p.dot(v_axis)) + shift)
				st.set_custom(0, info)
				st.set_custom(1, extra)
				st.add_vertex(p)
