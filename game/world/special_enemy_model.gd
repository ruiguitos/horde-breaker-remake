extends RefCounted
## Original special-enemy geometry. Same packed joints/PBR as common zombies,
## with six independently authored silhouettes, proportions and pose profiles.
const Part = ZombieModel.Part
const Layer = ZombieModel.Layer
const Kind = ZombieModel.Kind
const KINDS: Array[int] = [GameData.EnemyKind.RUNNER, GameData.EnemyKind.BRUTE, GameData.EnemyKind.GRABBER,
	GameData.EnemyKind.BOSS, GameData.EnemyKind.BLOATER, GameData.EnemyKind.SCREAMER]
const NAMES: Array[String] = ["runner", "brute", "grabber", "behemoth", "bloater", "screamer"]
static var _meshes: Dictionary = {}


static func profile(kind: int) -> Dictionary:
	var type: GameData.EnemyType = GameData.enemy_types()[kind]
	# Preserve the simulation's head centre, including its radius-scaled offset.
	var head_y: float = (type.height + 0.08 * type.radius_scale) / type.height * ZombieModel.MODEL_HEIGHT
	var p: Dictionary = {"head_y": head_y, "hip": Vector3(0.12, 0.92, 0), "knee": Vector3(0.12, 0.50, 0),
		"shoulder": Vector3(0.25, 1.49, 0), "elbow": Vector3(0.27, 1.19, 0),
		"waist": Vector3(0, 1.02, 0), "neck": Vector3(0, head_y - 0.21, 0.02)}
	match kind:
		GameData.EnemyKind.BRUTE:
			p.shoulder = Vector3(0.38, 1.48, 0)
			p.elbow = Vector3(0.42, 1.12, 0)
			p.hip.x = 0.18
			p.knee.x = 0.18
		GameData.EnemyKind.GRABBER:
			p.shoulder = Vector3(0.27, 1.49, 0)
			p.elbow = Vector3(0.38, 1.04, 0)
		GameData.EnemyKind.BOSS:
			p.shoulder = Vector3(0.44, 1.46, 0)
			p.elbow = Vector3(0.51, 1.08, 0)
			p.hip.x = 0.20
			p.knee.x = 0.20
		GameData.EnemyKind.BLOATER:
			p.hip = Vector3(0.23, 0.67, 0)
			p.knee = Vector3(0.24, 0.34, 0)
			p.waist = Vector3(0, 0.80, 0)
			p.shoulder = Vector3(0.43, 1.42, 0)
			p.elbow = Vector3(0.48, 1.08, 0)
	return p


static func mesh(kind: int) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	assert(kind in KINDS)
	var p: Dictionary = profile(kind)
	var materials: Array[ShaderMaterial] = []
	for layer in ZombieModel.LAYERS.size():
		var mat := ZombieModel.material(layer).duplicate() as ShaderMaterial
		mat.set_shader_parameter(&"creature_type", kind)
		for pair: Array in [["WAIST", "waist"], ["NECK", "neck"], ["HIP_L", "hip"], ["KNEE_L", "knee"], ["SHOULDER_L", "shoulder"], ["ELBOW_L", "elbow"]]:
			var point: Vector3 = p[pair[1]]
			mat.set_shader_parameter(pair[0], point)
			if String(pair[0]).ends_with("_L"):
				mat.set_shader_parameter(String(pair[0]).trim_suffix("_L") + "_R", Vector3(-point.x, point.y, point.z))
		materials.append(mat)
	var result: ArrayMesh = ZombieModel.build_parts(parts(kind), materials)
	# Include reaching arms and fallen bodies in shader animation bounds.
	result.custom_aabb = AABB(Vector3(-2, -0.6, -2.5), Vector3(4, 3.2, 5))
	result.resource_name = NAMES[KINDS.find(kind)]
	_meshes[kind] = result
	return result


static func _add(out: Array[Dictionary], c: Vector3, size: Vector3, part: int, layer: int,
		color: Color, gore: float = 0.2, detail: int = Kind.SURFACE, taper: float = 1.0,
		rotation: Vector3 = Vector3.ZERO) -> void:
	out.append({"c": c, "s": size, "part": part, "layer": layer, "slot": ZombieModel.Slot.FIXED,
		"tint": color, "gore": gore, "kind": detail, "seed": out.size() * 0.731 + 2.3,
		"show_a": ZombieModel.Show.ALWAYS, "show_b": ZombieModel.Show.ALWAYS,
		"taper": taper, "rotation": rotation})


static func parts(kind: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var p: Dictionary = profile(kind)
	var skin := Color(0.49, 0.53, 0.43)
	var cloth := Color(0.20, 0.22, 0.23)
	var width: float = 0.15
	var hand_y: float = 0.87
	match kind:
		GameData.EnemyKind.RUNNER:
			skin = Color(0.50, 0.47, 0.42)
			cloth = Color(0.28, 0.19, 0.17)
			width = 0.125
		GameData.EnemyKind.BRUTE:
			skin = Color(0.42, 0.39, 0.33)
			width = 0.23
			hand_y = 0.78
		GameData.EnemyKind.GRABBER:
			skin = Color(0.42, 0.37, 0.46)
			width = 0.11
			hand_y = 0.48
		GameData.EnemyKind.BOSS:
			skin = Color(0.38, 0.27, 0.26)
			cloth = Color(0.16, 0.14, 0.13)
			width = 0.25
			hand_y = 0.68
		GameData.EnemyKind.BLOATER:
			skin = Color(0.47, 0.54, 0.30)
			width = 0.19
			hand_y = 0.79
		GameData.EnemyKind.SCREAMER:
			skin = Color(0.63, 0.57, 0.38)
			cloth = Color(0.34, 0.29, 0.15)
			width = 0.12
	# Individually proportioned legs and arms, with matching shader pivots.
	for sign: float in [1.0, -1.0]:
		var thigh: int = Part.LEG_UPPER_L if sign > 0 else Part.LEG_UPPER_R
		var shin: int = Part.LEG_LOWER_L if sign > 0 else Part.LEG_LOWER_R
		var upper: int = Part.ARM_UPPER_L if sign > 0 else Part.ARM_UPPER_R
		var lower: int = Part.ARM_LOWER_L if sign > 0 else Part.ARM_LOWER_R
		var hip: Vector3 = p.hip
		var knee: Vector3 = p.knee
		var shoulder: Vector3 = p.shoulder
		var elbow: Vector3 = p.elbow
		_add(out, Vector3(hip.x * sign, (hip.y + knee.y) * 0.5, 0), Vector3(width, hip.y - knee.y + 0.035, width * 1.1), thigh, Layer.DENIM, cloth, 0.4)
		_add(out, Vector3(knee.x * sign, knee.y * 0.5 + 0.03, 0), Vector3(width * 0.8, knee.y - 0.03, width), shin, Layer.SKIN, skin, 0.5)
		_add(out, Vector3(knee.x * sign, 0.055, 0.07), Vector3(width, 0.11, 0.27), shin, Layer.LEATHER, cloth, 0.15)
		var arm_width: float = width * (1.35 if kind in [GameData.EnemyKind.BRUTE, GameData.EnemyKind.BOSS] else 0.8)
		_add(out, Vector3((shoulder.x + elbow.x) * 0.5 * sign, (shoulder.y + elbow.y) * 0.5, 0), Vector3(arm_width, shoulder.y - elbow.y + 0.04, arm_width), upper, Layer.SKIN, skin, 0.45, Kind.SURFACE, 0.82)
		_add(out, Vector3(elbow.x * sign, (elbow.y + hand_y) * 0.5, 0), Vector3(arm_width * 0.85, elbow.y - hand_y + 0.04, arm_width * 0.9), lower, Layer.SKIN, skin, 0.5)
		_add(out, Vector3(elbow.x * sign, hand_y - 0.04, 0.02), Vector3(arm_width, 0.13, arm_width * 1.05), lower, Layer.SKIN, skin, 0.35)
		if kind == GameData.EnemyKind.GRABBER:
			for finger in 3:
				_add(out, Vector3((elbow.x - 0.04 + finger * 0.04) * sign, hand_y - 0.18, 0.045), Vector3(0.022, 0.19, 0.025), lower, Layer.SKIN, Color(0.51, 0.45, 0.36), 0.1, Kind.BONE, 0.25)
	_add(out, Vector3(0, (p.hip as Vector3).y + 0.015, 0), Vector3((p.hip as Vector3).x * 2 + width, 0.22, 0.24), Part.PELVIS, Layer.DENIM, cloth, 0.3)
	# The chest is authored separately for each class, not a recoloured Walker.
	match kind:
		GameData.EnemyKind.RUNNER:
			_add(out, Vector3(0, 1.30, -0.025), Vector3(0.34, 0.51, 0.21), Part.TORSO, Layer.JERSEY, cloth, 0.7, Kind.SURFACE, 0.80)
			_add(out, Vector3(0, 1.49, -0.10), Vector3(0.25, 0.10, 0.14), Part.TORSO, Layer.SKIN, skin, 0.65)
			for rib in 4:
				_add(out, Vector3(0, 1.17 + rib * 0.065, 0.095), Vector3(0.25 - rib * 0.02, 0.022, 0.035), Part.TORSO, Layer.SKIN, skin, 0.3, Kind.BONE)
		GameData.EnemyKind.BRUTE:
			_add(out, Vector3(0, 1.31, 0), Vector3(0.68, 0.54, 0.35), Part.TORSO, Layer.SKIN, skin, 0.6)
			for sign: float in [-1.0, 1.0]:
				_add(out, Vector3(sign * 0.20, 1.36, 0.19), Vector3(0.29, 0.38, 0.065), Part.TORSO, Layer.LEATHER, Color(0.20, 0.23, 0.18), 0.5, Kind.SURFACE, 0.88)
				_add(out, Vector3(sign * 0.38, 1.48, 0), Vector3(0.32, 0.23, 0.38), Part.ARM_UPPER_L if sign > 0 else Part.ARM_UPPER_R, Layer.LEATHER, Color(0.22, 0.24, 0.18), 0.3)
				_add(out, Vector3(sign * 0.42, 1.0, 0.08), Vector3(0.26, 0.30, 0.13), Part.ARM_LOWER_L if sign > 0 else Part.ARM_LOWER_R, Layer.LEATHER, Color(0.26, 0.25, 0.20), 0.3)
		GameData.EnemyKind.GRABBER:
			_add(out, Vector3(0, 1.29, 0), Vector3(0.32, 0.53, 0.19), Part.TORSO, Layer.LINEN, cloth, 0.9, Kind.SURFACE, 1.15)
			for rib in 5:
				_add(out, Vector3(0, 1.14 + rib * 0.065, 0.1), Vector3(0.23, 0.02, 0.026), Part.TORSO, Layer.SKIN, skin, 0.1, Kind.BONE)
		GameData.EnemyKind.BOSS:
			_add(out, Vector3(0, 1.27, -0.035), Vector3(0.76, 0.62, 0.43), Part.TORSO, Layer.SKIN, skin, 0.85, Kind.SURFACE, 1.12)
			for row in 3:
				_add(out, Vector3(0, 1.10 + row * 0.16, 0.205), Vector3(0.62 - row * 0.035, 0.12, 0.09), Part.TORSO, Layer.LEATHER, Color(0.19, 0.16, 0.15), 0.4, Kind.SURFACE, 0.75)
			for sign: float in [-1.0, 1.0]:
				_add(out, Vector3(sign * 0.44, 1.46, -0.015), Vector3(0.36, 0.29, 0.43), Part.ARM_UPPER_L if sign > 0 else Part.ARM_UPPER_R, Layer.SKIN, skin, 0.7)
				for spike in 3:
					_add(out, Vector3(sign * (0.26 + spike * 0.14), 1.65 + 0.04 * spike, -0.14), Vector3(0.105, 0.30 + spike * 0.045, 0.105), Part.TORSO, Layer.SKIN, Color(0.42, 0.31, 0.25), 0.1, Kind.BONE, 0.10, Vector3(-0.45, 0, -sign * 0.40))
			_add(out, Vector3(0.17, 1.28, -0.27), Vector3(0.22, 0.32, 0.12), Part.TORSO, Layer.SKIN, Color(0.58, 0.21, 0.16), 0.4, Kind.FLESH) # exposed back weak spot
		GameData.EnemyKind.BLOATER:
			_add(out, Vector3(0, 1.10, 0.08), Vector3(0.84, 0.78, 0.69), Part.TORSO, Layer.SKIN, skin, 0.8, Kind.SURFACE, 0.80)
			_add(out, Vector3(0, 1.47, 0.015), Vector3(0.40, 0.29, 0.35), Part.TORSO, Layer.SKIN, skin, 0.5, Kind.SURFACE, 0.65)
			_add(out, Vector3(0, 0.94, 0.34), Vector3(0.60, 0.38, 0.16), Part.TORSO, Layer.SKIN, Color(0.55, 0.48, 0.25), 0.65, Kind.SURFACE, 0.88)
			for n in 9:
				var angle: float = float(n) * 2.39996
				_add(out, Vector3(cos(angle) * 0.34, 1.04 + sin(n * 1.7) * 0.22, 0.30 + absf(sin(angle)) * 0.12), Vector3(0.11, 0.12, 0.07), Part.TORSO, Layer.SKIN, Color(0.61, 0.55, 0.23), 0.35, Kind.SURFACE, 0.65)
			_add(out, Vector3(-0.07, 1.03, 0.465), Vector3(0.20, 0.10, 0.025), Part.TORSO, Layer.SKIN, Color(0.38, 0.17, 0.10), 0.4, Kind.FLESH)
		GameData.EnemyKind.SCREAMER:
			_add(out, Vector3(0, 1.28, 0), Vector3(0.35, 0.52, 0.20), Part.TORSO, Layer.LINEN, cloth, 0.7, Kind.SURFACE, 1.12)
			_add(out, Vector3(0, 1.51, 0.10), Vector3(0.21, 0.23, 0.17), Part.TORSO, Layer.SKIN, Color(0.57, 0.39, 0.26), 0.6)
			for rib in 4:
				_add(out, Vector3(0, 1.12 + rib * 0.07, 0.11), Vector3(0.26, 0.022, 0.025), Part.TORSO, Layer.SKIN, skin, 0.1, Kind.BONE)
	# Face anatomy stays centred on the gameplay head target for all heights.
	var head_y: float = p.head_y
	var head_size := Vector3(0.26, 0.24, 0.26)
	if kind == GameData.EnemyKind.RUNNER:
		head_size = Vector3(0.21, 0.23, 0.25)
	elif kind == GameData.EnemyKind.GRABBER:
		head_size = Vector3(0.22, 0.29, 0.24)
	elif kind == GameData.EnemyKind.BOSS:
		head_size = Vector3(0.28, 0.25, 0.29)
	_add(out, Vector3(0, head_y - 0.18, 0.01), Vector3(0.12, 0.14, 0.12), Part.TORSO, Layer.SKIN, skin, 0.4)
	_add(out, Vector3(0, head_y, 0.03), head_size, Part.HEAD, Layer.SKIN, skin, 0.55)
	var scream: bool = kind == GameData.EnemyKind.SCREAMER
	_add(out, Vector3(0, head_y - (0.17 if scream else 0.13), 0.10), Vector3(0.23, 0.07, 0.21), Part.HEAD, Layer.SKIN, skin, 0.7)
	_add(out, Vector3(0, head_y - (0.09 if scream else 0.10), 0.167), Vector3(0.16, 0.17 if scream else 0.04, 0.025), Part.HEAD, Layer.SKIN, Color(0.12, 0.04, 0.035), 0.0, Kind.MOUTH)
	for sign: float in [-1.0, 1.0]:
		_add(out, Vector3(sign * 0.062, head_y + 0.028, 0.166), Vector3(0.052, 0.033, 0.018), Part.HEAD, Layer.SKIN, Color(0.65, 0.67, 0.46), 0.0, Kind.EYE)
		_add(out, Vector3(sign * 0.065, head_y + 0.063, 0.17), Vector3(0.095, 0.028, 0.028), Part.HEAD, Layer.SKIN, skin, 0.3)
		for tooth in 3:
			_add(out, Vector3(sign * (0.025 + tooth * 0.018), head_y - 0.07, 0.185), Vector3(0.013, 0.022, 0.015), Part.HEAD, Layer.SKIN, Color(0.6, 0.55, 0.42), 0.0, Kind.BONE)
		if kind == GameData.EnemyKind.BRUTE:
			_add(out, Vector3(sign * 0.08, head_y + 0.078, 0.18), Vector3(0.14, 0.065, 0.06), Part.HEAD, Layer.LEATHER, Color(0.24, 0.26, 0.22), 0.15)
		elif kind == GameData.EnemyKind.BOSS:
			_add(out, Vector3(sign * 0.10, head_y - 0.10, 0.19), Vector3(0.047, 0.15, 0.05), Part.HEAD, Layer.SKIN, Color(0.52, 0.43, 0.32), 0.1, Kind.BONE, 0.18, Vector3(-0.15, 0, -sign * 0.15))
		elif kind == GameData.EnemyKind.SCREAMER:
			_add(out, Vector3(sign * 0.125, head_y - 0.06, 0.13), Vector3(0.055, 0.18, 0.075), Part.HEAD, Layer.SKIN, skin, 0.45)
	return out
