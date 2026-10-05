extends Node3D
## Camera spike: builds a 120x120 m test arena from primitives, a capsule
## player and a slow capsule horde, then exercises CameraMediumRig.
## Keys: WASD move, 1/2/3 presets, RMB+mouse or right stick yaw,
## T toggles "mouse always turns camera", R respawns the horde.

const ARENA_SIZE := 120.0
const AIM_HEIGHT := 1.0 # aim plane height above the player's feet

@export var zombie_count: int = 40
@export var zombie_speed: float = 1.2
@export var player_speed: float = 6.0
@export var spawn_min_radius: float = 12.0
@export var spawn_max_radius: float = 40.0
@export var occluded_alpha: float = 0.25
@export var rng_seed: int = 7

var zombies: Array[Node3D] = []
var obstacles: Array[MeshInstance3D] = []
var aim_point: Vector3 = Vector3.ZERO
var has_aim: bool = false

var _faded: Dictionary = {} # MeshInstance3D -> true
var _aim_mesh: ImmediateMesh
var _rng := RandomNumberGenerator.new()

@onready var player: CharacterBody3D = $Player
@onready var rig: CameraMediumRig = $CameraRig
@onready var overlay: Label = $Overlay/Info
@onready var reticle: Label = $Overlay/Reticle


func _ready() -> void:
	_rng.seed = rng_seed
	_build_obstacles()
	_build_aim_line()
	spawn_zombies(zombie_count)
	rig.snap_to_target()


# --- World building ---------------------------------------------------------

func _build_obstacles() -> void:
	# Fixed layout so every run (and every test) sees the same arena.
	var blocks: Array[Array] = [
		# [position x, z, size x, y, z]
		[0.0, -8.0, 6.0, 3.0, 1.0],   # wall just ahead of spawn
		[0.0, 8.0, 6.0, 4.0, 1.0],    # wall behind: occludes in default view
		[-12.0, -4.0, 2.0, 6.0, 2.0], # column
		[12.0, 4.0, 2.0, 6.0, 2.0],
		[-20.0, 20.0, 8.0, 5.0, 8.0], # "house"
		[22.0, -18.0, 10.0, 4.0, 4.0],
		[-30.0, -25.0, 3.0, 9.0, 3.0], # tall tower
		[30.0, 28.0, 3.0, 9.0, 3.0],
		[8.0, 18.0, 1.5, 3.0, 12.0],
		[-6.0, -22.0, 14.0, 2.0, 1.0], # low wall
	]
	for b: Array in blocks:
		var body := StaticBody3D.new()
		body.position = Vector3(b[0], b[3] * 0.5, b[1])
		var size := Vector3(b[2], b[3], b[4])
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.55, 0.5, 0.45)
		mesh.material_override = mat
		body.add_child(mesh)
		$Obstacles.add_child(body)
		obstacles.append(mesh)


func _build_aim_line() -> void:
	_aim_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.name = "AimLine"
	mi.mesh = _aim_mesh
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.2, 0.2)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func spawn_zombies(count: int) -> void:
	for z in zombies:
		z.queue_free()
	zombies.clear()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.6, 0.3)
	for i in count:
		var z := MeshInstance3D.new()
		z.mesh = capsule
		z.material_override = mat
		var angle := _rng.randf() * TAU
		var r := _rng.randf_range(spawn_min_radius, spawn_max_radius)
		z.position = Vector3(cos(angle) * r, 0.9, sin(angle) * r)
		$Zombies.add_child(z)
		zombies.append(z)


# --- Per frame ---------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).physical_keycode == KEY_R:
		spawn_zombies(zombie_count)


func _physics_process(delta: float) -> void:
	_move_player()
	_move_zombies(delta)
	_update_occlusion()


func _process(_delta: float) -> void:
	_update_aim()
	_update_overlay()


func _move_player() -> void:
	var input := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_W)) - float(Input.is_physical_key_pressed(KEY_S)))
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_LEFT_X), -Input.get_joy_axis(0, JOY_AXIS_LEFT_Y))
	if stick.length() > 0.2:
		input += stick
	input = input.limit_length(1.0)
	var dir := rig.flat_forward() * input.y + rig.flat_right() * input.x
	player.velocity = Vector3(dir.x * player_speed, player.velocity.y - 20.0 * get_physics_process_delta_time(), dir.z * player_speed)
	player.move_and_slide()
	if player.is_on_floor():
		player.velocity.y = 0.0


func _move_zombies(delta: float) -> void:
	# Deliberately naive: straight line to the player, no navigation.
	var target := player.global_position
	for z in zombies:
		var to := Vector3(target.x - z.position.x, 0.0, target.z - z.position.z)
		if to.length() > 1.0:
			z.position += to.normalized() * zombie_speed * delta


func _update_aim() -> void:
	var cam := rig.camera
	var vp := get_viewport()
	# The mouse drives the reticle; gamepad aiming is out of scope for this spike.
	var screen_pos := vp.get_mouse_position()
	reticle.position = screen_pos - reticle.size * 0.5
	var hit: Variant = aim_on_player_plane(cam, screen_pos, player.global_position.y + AIM_HEIGHT)
	has_aim = hit != null
	_aim_mesh.clear_surfaces()
	if has_aim:
		aim_point = hit
		var from := player.global_position + Vector3.UP * AIM_HEIGHT
		_aim_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		_aim_mesh.surface_add_vertex(from)
		_aim_mesh.surface_add_vertex(aim_point)
		_aim_mesh.surface_end()


## Ray from the camera through a screen point, intersected with the horizontal
## plane y = plane_height. Returns Vector3 or null (ray parallel / pointing up).
static func aim_on_player_plane(cam: Camera3D, screen_pos: Vector2, plane_height: float) -> Variant:
	var origin := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	return Plane(Vector3.UP, plane_height).intersects_ray(origin, dir)


func _update_occlusion() -> void:
	var space := get_world_3d().direct_space_state
	var from := rig.camera.global_position
	var now_faded: Dictionary = {}
	# Two rays (feet-ish and head) so partially hidden players still count.
	for h: float in [0.5, 1.6]:
		var to := player.global_position + Vector3.UP * (h - 0.9)
		var exclude: Array[RID] = [player.get_rid()]
		for _i in 4:
			var q := PhysicsRayQueryParameters3D.create(from, to)
			q.exclude = exclude
			var res := space.intersect_ray(q)
			if res.is_empty():
				break
			var body := res.collider as StaticBody3D
			if body == null:
				break
			for c in body.get_children():
				if c is MeshInstance3D:
					now_faded[c] = true
			exclude.append(body.get_rid())
	for m: MeshInstance3D in obstacles:
		_set_faded(m, now_faded.has(m))
	_faded = now_faded


func _set_faded(m: MeshInstance3D, faded: bool) -> void:
	var mat := m.material_override as StandardMaterial3D
	if faded:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = occluded_alpha
	else:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		mat.albedo_color.a = 1.0


func faded_count() -> int:
	return _faded.size()


## Zombies whose centre lies inside the camera frustum (ignores occlusion).
func count_zombies_in_frustum() -> int:
	var n := 0
	for z in zombies:
		if rig.camera.is_position_in_frustum(z.global_position):
			n += 1
	return n


func _update_overlay() -> void:
	overlay.text = "Preset %d: %s  (1/2/3)\npitch %.1f°  distance %.1f m  offset %.2f m  FOV %.1f°  yaw %.0f°\nyaw: %s (T toggles)\nzombies in frustum: %d / %d   occluders faded: %d\nFPS %d   R = respawn horde" % [
		rig.preset_index + 1, rig.preset_name(), rig.pitch_deg, rig.distance, rig.side_offset,
		rig.fov_deg, fposmod(rig.yaw_deg, 360.0),
		"mouse always" if rig.mouse_yaw_always else "hold RMB",
		count_zombies_in_frustum(), zombies.size(), faded_count(), Engine.get_frames_per_second()]
