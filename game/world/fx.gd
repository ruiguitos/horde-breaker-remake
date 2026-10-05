class_name Fx
extends Node3D
## One-shot GPU particle effects (sparks, blood, dust) from small pools of
## GPUParticles3D that are moved and restarted, instead of creating nodes
## per shot. Each effect is a ParticleProcessMaterial + a tiny mesh.

const POOL: int = 12

var _pools: Dictionary = {}  ## name -> Array[GPUParticles3D]
var _next: Dictionary = {}   ## name -> int


func _ready() -> void:
	_pools[&"spark"] = _make_pool(_spark_material(), _mesh(0.06, Color(1.0, 0.85, 0.4), true), 10, 0.25)
	_pools[&"blood"] = _make_pool(_blood_material(), _mesh(0.12, Color(0.55, 0.05, 0.05), false), 18, 0.7)
	_pools[&"dust"] = _make_pool(_dust_material(), _mesh(0.35, Color(0.75, 0.7, 0.6, 0.6), false), 24, 0.8)
	for k in _pools:
		_next[k] = 0


func emit(effect: StringName, pos: Vector3, direction: Vector3 = Vector3.UP) -> void:
	var pool: Array = _pools.get(effect, [])
	if pool.is_empty():
		return
	var i: int = _next[effect]
	_next[effect] = (i + 1) % pool.size()
	var p: GPUParticles3D = pool[i]
	p.global_position = pos
	if direction.length_squared() > 0.001:
		p.look_at(pos + direction, Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.RIGHT)
	p.restart()


func _make_pool(material: ParticleProcessMaterial, mesh: Mesh, amount: int, lifetime: float) -> Array:
	var pool: Array = []
	for i in POOL:
		var p := GPUParticles3D.new()
		p.one_shot = true
		p.emitting = false
		p.amount = amount
		p.lifetime = lifetime
		p.explosiveness = 0.95
		p.process_material = material
		p.draw_pass_1 = mesh
		p.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
		add_child(p)
		pool.append(p)
	return pool


func _mesh(size: float, color: Color, glow: bool) -> Mesh:
	var m := BoxMesh.new()
	m.size = Vector3.ONE * size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow:
		# Emissive sparks pick up the bloom on High graphics.
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 3.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.material = mat
	return m


## Sparks fly back along -Z of the emitter (towards the shooter) and fall.
func _spark_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0.3, 1)
	m.spread = 35.0
	m.initial_velocity_min = 4.0
	m.initial_velocity_max = 9.0
	m.gravity = Vector3(0, -14, 0)
	m.scale_min = 0.6
	m.scale_max = 1.2
	return m


func _blood_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 70.0
	m.initial_velocity_min = 2.0
	m.initial_velocity_max = 5.5
	m.gravity = Vector3(0, -12, 0)
	m.scale_min = 0.5
	m.scale_max = 1.3
	return m


func _dust_material() -> ParticleProcessMaterial:
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 0.4, 0)
	m.spread = 180.0
	m.flatness = 0.8
	m.initial_velocity_min = 1.5
	m.initial_velocity_max = 3.5
	m.gravity = Vector3(0, 0.5, 0)
	m.damping_min = 2.0
	m.damping_max = 3.0
	m.scale_min = 0.6
	m.scale_max = 1.6
	return m
