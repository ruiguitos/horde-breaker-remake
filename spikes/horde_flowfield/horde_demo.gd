extends Node3D
## Visual demo: arena + horde rendered with MultiMeshInstance3D.
## The "player" (red box) moves with WASD / arrows; the field is rebuilt on a
## worker thread whenever the player changes cell. Left click = hitscan from
## the player towards the mouse; the hit agent respawns at the map edge.

@export var agent_count: int = 500

var field: HordeFlowField
var sim: HordeSim
var player_pos := Vector3(75.5, 0.0, 75.5)
var player_speed: float = 6.0

var _agents_mm: MultiMesh
var _player: MeshInstance3D
var _camera: Camera3D
var _label: Label
var _sim_ms: float = 0.0
var _last_hit: int = -1


func _ready() -> void:
	field = HordeMaps.make_arena()
	field.compute(field.world_to_cell(player_pos))
	sim = HordeSim.new(field)
	sim.target_pos = player_pos
	HordeMaps.spawn_ring(sim, agent_count, player_pos, 30.0, 70.0)
	_build_scene()


func _build_scene() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(150, 150)
	ground.mesh = plane
	ground.position = Vector3(75, 0, 75)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.25, 0.3, 0.22)
	ground.material_override = gmat
	add_child(ground)

	# Walls: one MultiMesh of unit boxes, one instance per blocked cell.
	var walls := MultiMesh.new()
	walls.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = Vector3(1, 2, 1)
	walls.mesh = box
	var cells: Array[Vector3] = []
	for z in field.height:
		for x in field.width:
			if field.blocked[z * field.width + x] != 0:
				cells.append(Vector3(x + 0.5, 1.0, z + 0.5))
	walls.instance_count = cells.size()
	for k in cells.size():
		walls.set_instance_transform(k, Transform3D(Basis(), cells[k]))
	var wmi := MultiMeshInstance3D.new()
	wmi.multimesh = walls
	var wmat := StandardMaterial3D.new()
	wmat.albedo_color = Color(0.5, 0.5, 0.55)
	wmi.material_override = wmat
	add_child(wmi)

	_agents_mm = MultiMesh.new()
	_agents_mm.transform_format = MultiMesh.TRANSFORM_3D
	var cap := CapsuleMesh.new()
	cap.radius = 0.35
	cap.height = 1.7
	cap.radial_segments = 8
	cap.rings = 2
	_agents_mm.mesh = cap
	_agents_mm.instance_count = sim.count
	var ami := MultiMeshInstance3D.new()
	ami.multimesh = _agents_mm
	var amat := StandardMaterial3D.new()
	amat.albedo_color = Color(0.55, 0.75, 0.45)
	ami.material_override = amat
	add_child(ami)

	_player = MeshInstance3D.new()
	var pbox := BoxMesh.new()
	pbox.size = Vector3(0.8, 1.8, 0.8)
	_player.mesh = pbox
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.9, 0.2, 0.2)
	_player.material_override = pmat
	add_child(_player)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 30, 0)
	add_child(sun)
	_camera = Camera3D.new()
	add_child(_camera)
	_label = Label.new()
	var layer := CanvasLayer.new()
	layer.add_child(_label)
	add_child(layer)


func _physics_process(delta: float) -> void:
	var input := Vector3(
		Input.get_axis("ui_left", "ui_right"), 0.0, Input.get_axis("ui_up", "ui_down"))
	if input != Vector3.ZERO:
		var np := player_pos + input.normalized() * player_speed * delta
		if not field.is_blocked_world(np):
			player_pos = np
	field.poll()
	var cell: Vector2i = field.world_to_cell(player_pos)
	if cell != field.target_cell:
		field.request_target(cell)
	sim.target_pos = player_pos

	var t0: int = Time.get_ticks_usec()
	sim.step(delta)
	_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.1)

	for i in sim.count:
		_agents_mm.set_instance_transform(i, Transform3D(Basis(), sim.pos[i] + Vector3(0, 0.85, 0)))
	_player.position = player_pos + Vector3(0, 0.9, 0)
	_camera.position = player_pos + Vector3(0, 28, 18)
	_camera.look_at(player_pos)
	_label.text = "agents %d  sim %.2f ms  fps %d  last hit %d  (WASD/arrows, click = shoot)" % [
		sim.count, _sim_ms, Engine.get_frames_per_second(), _last_hit]


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var from: Vector3 = _camera.project_ray_origin(mb.position)
	var dir: Vector3 = _camera.project_ray_normal(mb.position)
	if absf(dir.y) < 0.0001:
		return
	var ground_hit: Vector3 = from + dir * (-from.y / dir.y)
	_last_hit = sim.hitscan(player_pos, ground_hit - player_pos, 60.0)
	if _last_hit != -1:
		# "Kill" = respawn at the first reachable cell along the map edge.
		for x in range(1, field.width - 1):
			var c := Vector2i(x, 1)
			if not field.is_blocked(c) and field.dist[field.index(c)] != HordeFlowField.UNREACHABLE:
				sim.pos[_last_hit] = field.cell_center(c)
				break
