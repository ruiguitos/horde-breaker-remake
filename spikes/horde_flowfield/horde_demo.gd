extends Node3D
## Visual demo: the horde chases the player on the 150x150 map.
## WASD moves the player, left click fires a hitscan towards the mouse,
## +/- (keypad or main row) adds/removes 100 agents.

@export var agent_count: int = 150
@export var player_speed: float = 6.0

var field: HordeFlowField
var sim: HordeSim
var player_pos: Vector3 = Vector3(75, 0, 75)
var rng := RandomNumberGenerator.new()

var _multimesh := MultiMesh.new()
var _player: MeshInstance3D
var _camera: Camera3D
var _label: Label
var _tracer: MeshInstance3D
var _tracer_time: float = 0.0
var _sim_ms: float = 0.0


func _ready() -> void:
	rng.seed = 42
	field = HordeMap.generate()
	sim = HordeSim.new(field)
	sim.set_target(player_pos)
	field.compute_now(field.world_to_cell(player_pos))
	for i in agent_count:
		_spawn_agent()
	_build_world()


func _spawn_agent() -> void:
	sim.add_agent(HordeMap.random_free_position(field, rng), rng.randf_range(2.0, 5.0))


func _build_world() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(field.width, field.height)
	ground.mesh = plane
	ground.position = Vector3(field.width * 0.5, 0.0, field.height * 0.5)
	ground.material_override = _material(Color(0.25, 0.3, 0.25))
	add_child(ground)

	# Walls: one MultiMesh of unit boxes, one instance per blocked cell.
	var wall_mm := MultiMesh.new()
	wall_mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(1, 2, 1)
	wall_mm.mesh = box
	var cells: Array[Vector2i] = []
	for z in field.height:
		for x in field.width:
			if field.is_blocked(x, z):
				cells.append(Vector2i(x, z))
	wall_mm.instance_count = cells.size()
	for i in cells.size():
		wall_mm.set_instance_transform(i, Transform3D(Basis(), field.cell_center(cells[i]) + Vector3(0, 1, 0)))
	var walls := MultiMeshInstance3D.new()
	walls.multimesh = wall_mm
	walls.material_override = _material(Color(0.5, 0.5, 0.55))
	add_child(walls)

	# Agents: capsules, one MultiMesh, transforms rewritten every frame.
	var capsule := CapsuleMesh.new()
	capsule.radius = HordeSim.AGENT_RADIUS
	capsule.height = 1.7
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.mesh = capsule
	var agents := MultiMeshInstance3D.new()
	agents.multimesh = _multimesh
	agents.material_override = _material(Color(0.75, 0.2, 0.15))
	add_child(agents)

	_player = MeshInstance3D.new()
	var pm := CapsuleMesh.new()
	pm.radius = 0.4
	pm.height = 1.8
	_player.mesh = pm
	_player.material_override = _material(Color(0.2, 0.5, 0.9))
	add_child(_player)

	_tracer = MeshInstance3D.new()
	_tracer.material_override = _material(Color(1, 0.9, 0.3))
	add_child(_tracer)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60, 30, 0)
	add_child(sun)
	_camera = Camera3D.new()
	add_child(_camera)
	_label = Label.new()
	_label.position = Vector2(10, 10)
	var layer := CanvasLayer.new()
	layer.add_child(_label)
	add_child(layer)


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _physics_process(delta: float) -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if input != Vector2.ZERO:
		input = input.normalized() * player_speed * delta
		if not HordeSim.overlaps_wall(field, player_pos.x + input.x, player_pos.z, 0.4):
			player_pos.x += input.x
		if not HordeSim.overlaps_wall(field, player_pos.x, player_pos.z + input.y, 0.4):
			player_pos.z += input.y
	var t0: int = Time.get_ticks_usec()
	sim.set_target(player_pos)
	sim.tick(delta)
	_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)


func _process(delta: float) -> void:
	if _multimesh.instance_count != sim.count:
		_multimesh.instance_count = sim.count
	for i in sim.count:
		var p: Vector3 = sim.positions[i]
		var v: Vector3 = sim.velocities[i]
		var basis := Basis()
		if v.length_squared() > 0.01:
			basis = Basis(Vector3.UP, atan2(v.x, v.z))
		_multimesh.set_instance_transform(i, Transform3D(basis, p + Vector3(0, 0.85, 0)))
	_player.position = player_pos + Vector3(0, 0.9, 0)
	_camera.position = player_pos + Vector3(0, 28, 16)
	_camera.look_at(player_pos)
	_tracer_time -= delta
	_tracer.visible = _tracer_time > 0.0
	_label.text = "FPS %d | agents %d | sim %.2f ms | field %s\nWASD move, click shoot, +/- agents" % [
		Engine.get_frames_per_second(), sim.count, _sim_ms, "recomputing" if field.is_computing else "ready"]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_shoot(event.position)
	elif event is InputEventKey and event.pressed:
		if event.keycode in [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]:
			for i in 100:
				_spawn_agent()
		elif event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			for i in mini(100, sim.count):
				sim.remove_agent(sim.count - 1)


func _shoot(screen_pos: Vector2) -> void:
	var from: Vector3 = _camera.project_ray_origin(screen_pos)
	var dir: Vector3 = _camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return
	var aim: Vector3 = from + dir * (-from.y / dir.y)
	var hit: Dictionary = sim.hitscan(player_pos, aim - player_pos, 60.0)
	var length: float = minf(hit["distance"], 60.0)
	var shot_dir: Vector3 = Vector3(aim.x - player_pos.x, 0, aim.z - player_pos.z).normalized()
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINES)
	line.surface_add_vertex(player_pos + Vector3(0, 1, 0))
	line.surface_add_vertex(player_pos + shot_dir * length + Vector3(0, 1, 0))
	line.surface_end()
	_tracer.mesh = line
	_tracer_time = 0.1
	if hit["index"] != -1:
		sim.remove_agent(hit["index"])
		_spawn_agent()
