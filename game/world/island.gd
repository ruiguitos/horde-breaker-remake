extends Node3D
## The island scene: reads input, steps IslandRun at a fixed 60 Hz and draws
## its state with primitives (MultiMesh for the horde, orbs and debris).

## Emitted when the player leaves the end-of-island panel.
signal finished(won: bool)

@export var rng_seed: int = 7

## Set by main before the scene enters the tree; null when run with F6.
var context: RunContext
var paused: bool = false
## Title-screen backdrop: no HUD, no input, hidden immortal player in the
## middle (the horde gathers around), slowly orbiting camera.
var showcase: bool = false
@export_group("Camera")
@export var camera_pitch_deg: float = 35.0
@export var camera_distance: float = 10.0
@export var camera_fov: float = 60.0

const DEBRIS_MAX: int = 600

var run: IslandRun
var hud: Hud
var sfx: Sfx
var music: Music
var _audio_hp: float = -1.0
var _audio_xp: int = 0
var _audio_dashing: bool = false
var _audio_cards: bool = false
var _audio_slam: bool = false
var _audio_generators: int = 0
var _audio_scream_cd: float = 0.0

var _camera: Camera3D
var _player: Node3D
var _enemy_mm := MultiMesh.new()
var _head_mm := MultiMesh.new()
var _arm_mm := MultiMesh.new()
var _orb_mm := MultiMesh.new()
var _debris_mm := MultiMesh.new()
var _tracer_mesh := ImmediateMesh.new()
var _laser_mesh := ImmediateMesh.new()
var _laser_mat: StandardMaterial3D
var _generators: Array[MeshInstance3D] = []
var _generator_rings: Array[MeshInstance3D] = []
var _boat_ring: MeshInstance3D
var _caches: Array[MeshInstance3D] = []
var _buildings: Array[MeshInstance3D] = []
var _building_boxes: Array[AABB] = []
var _slam_ring: MeshInstance3D
var _explosions: Array[MeshInstance3D] = []
var _tracers: Array[PackedVector3Array] = []
var _tracer_life: float = 0.0
var _debris_pos := PackedVector3Array()
var _debris_vel := PackedVector3Array()
var _debris_life := PackedFloat32Array()
var _debris_color := PackedColorArray()
## Debris size; a negative value marks a severed head (drawn as a sphere).
var _debris_size := PackedFloat32Array()
var _head_debris_mm := MultiMesh.new()
var _breaker_held: bool = false
var _trauma: float = 0.0
var _last_hp: float = -1.0
var _was_dashing: bool = false
var _muzzle: OmniLight3D
var _hitstop: float = 0.0
var _grenade_held: bool = false
var _grenade_mm := MultiMesh.new()
var _grenade_ring_mm := MultiMesh.new()
var _rock_mm := MultiMesh.new()
var _rock_ring_mm := MultiMesh.new()
var _sim_ms: float = 0.0


func _ready() -> void:
	GameInput.setup()
	run = IslandRun.new(context.island_seed() if context != null else rng_seed,
		context.biome if context != null else &"beach")
	if context != null:
		run.load_context(context)
	_build_world()
	sfx = Sfx.new()
	add_child(sfx)
	music = Music.new()
	add_child(music)
	if showcase:
		_player.visible = false
		sfx.process_mode = Node.PROCESS_MODE_DISABLED
		run.player_pos = Vector3(run.field.width * 0.5, 0, run.field.height * 0.5)
		run.director.trigger_peak(1000000.0)
		return
	hud = Hud.new()
	hud.card_chosen.connect(func(i: int) -> void: run.choose_card(i))
	hud.resume_requested.connect(func() -> void: paused = false)
	hud.abandon_requested.connect(_abandon)
	add_child(hud)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	var bio: Dictionary = _biome()
	env.environment.background_color = bio["sky"]
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.4, 0.42, 0.48)
	if _is_volcano():
		env.environment.ambient_light_color = Color(0.5, 0.3, 0.25)
	if float(bio["fog"]) > 0.0:
		# Jungle haze: green-tinted, light enough to still read enemies.
		env.environment.fog_enabled = true
		env.environment.fog_light_color = Color(bio["sky"])
		env.environment.fog_density = bio["fog"]
	if context != null and context.modifier == &"fog":
		env.environment.fog_enabled = true
		env.environment.fog_light_color = Color(0.62, 0.66, 0.7)
		env.environment.fog_density = 0.025
		env.environment.background_color = Color(0.62, 0.66, 0.7)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.8
	if _is_volcano():
		sun.light_color = Color(1.0, 0.6, 0.4)
	add_child(sun)

	var f: FlowField = run.field
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	sea_mesh.size = Vector2(600, 600)
	sea.mesh = sea_mesh
	sea.position = Vector3(f.width * 0.5, -0.3, f.height * 0.5)
	sea_mesh.subdivide_width = 120
	sea_mesh.subdivide_depth = 120
	sea.material_override = _sea_material()
	add_child(sea)

	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	# Island ground: one flat tile per walkable or building cell (one draw call).
	var cells: Array[Vector2i] = []
	var in_building := {}
	for r in run.map.buildings:
		for z in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				in_building[Vector2i(x, z)] = true
	# Trees and rocks stand on ground too (otherwise the sea shows through).
	for c in run.map.trees + run.map.rocks:
		in_building[c] = true
	for z in f.height:
		for x in f.width:
			if not f.is_blocked(x, z) or in_building.has(Vector2i(x, z)):
				cells.append(Vector2i(x, z))
	# Distance to the sea (multi-source BFS) colours the ground: sand on the
	# coast blending into grass inland, with a little per-tile noise.
	var coast: PackedInt32Array = _coast_distance(in_building)
	var ground_mm := MultiMesh.new()
	ground_mm.transform_format = MultiMesh.TRANSFORM_3D
	ground_mm.use_colors = true
	var tile := BoxMesh.new()
	tile.size = Vector3(1, 0.3, 1)
	ground_mm.mesh = tile
	ground_mm.instance_count = cells.size()
	for i in cells.size():
		ground_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(cells[i].x + 0.5, -0.15, cells[i].y + 0.5)))
		var d: int = coast[cells[i].y * f.width + cells[i].x]
		var sand: Color = _biome()["coast"]
		var grass: Color = _biome()["inland"]
		var c: Color = sand.lerp(grass, clampf((d - 4) / 8.0, 0.0, 1.0))
		ground_mm.set_instance_color(i, c.darkened(rng.randf() * 0.06))
	var ground := MultiMeshInstance3D.new()
	ground.multimesh = ground_mm
	var gm := _mat(Color.WHITE)
	gm.vertex_color_use_as_albedo = true
	ground.material_override = gm
	add_child(ground)

	for r in run.map.buildings:
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		var h: float = rng.randf_range(2.0, 5.0) if r.size.x > 1 and r.size.y > 1 else 1.6
		box.size = Vector3(r.size.x, h, r.size.y)
		b.mesh = box
		b.position = Vector3(r.position.x + r.size.x * 0.5, h * 0.5, r.position.y + r.size.y * 0.5)
		b.material_override = _mat(_building_color(r, rng))
		add_child(b)
		_buildings.append(b)
		_building_boxes.append(AABB(Vector3(r.position.x, 0, r.position.y), Vector3(r.size.x, h, r.size.y)))

	_build_props(rng)
	for k in run.map.lava.size():
		var pool := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = run.map.lava_radius[k]
		disc.bottom_radius = run.map.lava_radius[k]
		disc.height = 0.08
		pool.mesh = disc
		pool.position = run.map.lava[k] + Vector3(0, 0.03, 0)
		pool.material_override = _mat(Color(1.0, 0.4, 0.05), true)
		add_child(pool)
		var heat := OmniLight3D.new()
		heat.light_color = Color(1, 0.45, 0.1)
		heat.omni_range = run.map.lava_radius[k] * 2.5
		heat.light_energy = 0.6
		heat.position = run.map.lava[k] + Vector3(0, 1.0, 0)
		add_child(heat)
	if _is_volcano():
		# The volcano itself, rising from the sea north of the island.
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 7.0
		cm.bottom_radius = 45.0
		cm.height = 40.0
		cone.mesh = cm
		cone.position = Vector3(f.width * 0.5, 19.0, -40.0)
		cone.material_override = _mat(Color(0.2, 0.16, 0.15))
		add_child(cone)
		var lava := MeshInstance3D.new()
		lava.mesh = _sphere(6.5)
		lava.position = cone.position + Vector3(0, 20.0, 0)
		var lm := _mat(Color(1.0, 0.45, 0.1), true)
		lava.material_override = lm
		add_child(lava)
		var glow := OmniLight3D.new()
		glow.light_color = Color(1, 0.4, 0.1)
		glow.omni_range = 60.0
		glow.light_energy = 2.0
		glow.position = lava.position
		add_child(glow)
	for c in run.map.caches:
		var crate := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(1.0, 0.7, 0.7)
		crate.mesh = cm
		crate.position = c + Vector3(0, 0.35, 0)
		crate.material_override = _mat(Color(0.3, 0.75, 0.85))
		add_child(crate)
		_caches.append(crate)

	for g in run.map.generators:
		var gen := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.8
		cyl.bottom_radius = 1.0
		cyl.height = 2.0
		gen.mesh = cyl
		gen.position = g + Vector3(0, 1, 0)
		gen.material_override = _mat(Color(0.7, 0.2, 0.15))
		add_child(gen)
		_generators.append(gen)
		_generator_rings.append(_ring(g, GameData.GENERATOR_RADIUS, Color(1, 0.8, 0.2)))

	var boat := MeshInstance3D.new()
	var hull := BoxMesh.new()
	hull.size = Vector3(4, 1.2, 8)
	boat.mesh = hull
	boat.position = run.map.boat + Vector3(0, 0.3, 3)
	boat.material_override = _mat(Color(0.45, 0.3, 0.18))
	add_child(boat)
	_boat_ring = _ring(run.map.boat, GameData.BOAT_RADIUS, Color(0.3, 1, 0.4))
	_boat_ring.visible = false
	_slam_ring = _ring(Vector3.ZERO, GameData.BOSS_SLAM_RADIUS, Color(1, 0.2, 0.1))
	_slam_ring.visible = false

	_player = Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = GameData.PLAYER_RADIUS
	cap.height = 1.8
	body.mesh = cap
	body.position.y = 0.9
	body.material_override = _mat(Color(0.2, 0.45, 0.95))
	_player.add_child(body)
	# Simple soldier: helmet head, backpack and a rifle pointing forward (-Z).
	var head := MeshInstance3D.new()
	head.mesh = _sphere(0.26)
	head.position = Vector3(0, 1.95, 0)
	head.material_override = _mat(Color(0.85, 0.7, 0.55))
	_player.add_child(head)
	var helmet := MeshInstance3D.new()
	var helmet_mesh := SphereMesh.new()
	helmet_mesh.radius = 0.3
	helmet_mesh.height = 0.36
	helmet_mesh.is_hemisphere = true
	helmet.mesh = helmet_mesh
	helmet.position = Vector3(0, 2.0, 0)
	helmet.material_override = _mat(Color(0.25, 0.35, 0.2))
	_player.add_child(helmet)
	var pack := MeshInstance3D.new()
	var pack_mesh := BoxMesh.new()
	pack_mesh.size = Vector3(0.5, 0.6, 0.25)
	pack.mesh = pack_mesh
	pack.position = Vector3(0, 1.25, 0.42)
	pack.material_override = _mat(Color(0.3, 0.3, 0.22))
	_player.add_child(pack)
	var gun := MeshInstance3D.new()
	var gun_mesh := BoxMesh.new()
	gun_mesh.size = Vector3(0.12, 0.16, 0.9)
	gun.mesh = gun_mesh
	gun.position = Vector3(0.22, 1.2, -0.55)
	gun.material_override = _mat(Color(0.12, 0.12, 0.12))
	_player.add_child(gun)
	_muzzle = OmniLight3D.new()
	_muzzle.position = Vector3(0.22, 1.2, -1.1)
	_muzzle.light_color = Color(1, 0.8, 0.4)
	_muzzle.omni_range = 6.0
	_muzzle.light_energy = 0.0
	_player.add_child(_muzzle)
	add_child(_player)

	_setup_multimesh(_enemy_mm, _capsule(0.35, 1.7), true)
	# Heads and arms: separate MultiMeshes that follow the body transform.
	_setup_multimesh(_head_mm, _sphere(0.24), true)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.13, 0.13, 0.65)
	_setup_multimesh(_arm_mm, arm, true)
	_setup_multimesh(_orb_mm, _sphere(0.18), false, Color(0.3, 0.9, 1.0), true)
	_setup_multimesh(_grenade_mm, _sphere(0.22), false, Color(0.15, 0.3, 0.1))
	var warn := TorusMesh.new()
	warn.inner_radius = 0.92
	warn.outer_radius = 1.0
	_setup_multimesh(_grenade_ring_mm, warn, false, Color(1, 0.25, 0.1), true)
	_setup_multimesh(_rock_mm, _sphere(0.6), false, Color(0.3, 0.22, 0.2))
	_setup_multimesh(_rock_ring_mm, warn, false, Color(1, 0.5, 0.1), true)
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.25, 0.25, 0.25)
	_setup_multimesh(_debris_mm, chunk, true)
	_setup_multimesh(_head_debris_mm, _sphere(0.24), true)

	var tracer := MeshInstance3D.new()
	tracer.mesh = _tracer_mesh
	var tmat := _mat(Color(1, 0.9, 0.4), true)
	tracer.material_override = tmat
	add_child(tracer)

	var laser := MeshInstance3D.new()
	laser.mesh = _laser_mesh
	_laser_mat = _mat(Color(1, 1, 1, 0.35), true)
	_laser_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	laser.material_override = _laser_mat
	add_child(laser)

	_camera = Camera3D.new()
	_camera.fov = camera_fov
	add_child(_camera)


## Animated sea: vertices bob with two crossing sine waves (vertex shader),
## and the colour gets lighter on the crests.
func _sea_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 deep = vec3(0.1, 0.28, 0.45);
uniform vec3 crest = vec3(0.35, 0.6, 0.75);
varying float h;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = sin(w.x * 0.15 + TIME * 1.3) * 0.5 + sin(w.z * 0.11 - TIME * 0.9) * 0.5;
	VERTEX.y += h * 0.25;
}
void fragment() {
	ALBEDO = mix(deep, crest, clamp(h * 0.5 + 0.5, 0.0, 1.0) * 0.5);
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _coast_distance(in_building: Dictionary) -> PackedInt32Array:
	var f: FlowField = run.field
	var dist := PackedInt32Array()
	dist.resize(f.width * f.height)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for z in f.height:
		for x in f.width:
			var cell := Vector2i(x, z)
			if f.is_blocked(x, z) and not in_building.has(cell):
				dist[z * f.width + x] = 0
				queue.append(z * f.width + x)
	var head: int = 0
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		var x: int = idx % f.width
		var z: int = idx / f.width
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + o.x
			var nz: int = z + o.y
			if nx < 0 or nz < 0 or nx >= f.width or nz >= f.height:
				continue
			var n: int = nz * f.width + nx
			if dist[n] == -1:
				dist[n] = dist[idx] + 1
				queue.append(n)
	return dist


## Trees (trunk + two-tier crown) and rocks, as MultiMeshes.
func _build_props(rng: RandomNumberGenerator) -> void:
	var trunk_mm := MultiMesh.new()
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.15
	trunk.bottom_radius = 0.22
	trunk.height = 2.2
	_setup_multimesh(trunk_mm, trunk, false, Color(0.4, 0.28, 0.18))
	var crown_mm := MultiMesh.new()
	var crown := CylinderMesh.new()
	crown.top_radius = 0.0
	crown.bottom_radius = 1.1
	crown.height = 2.4
	_setup_multimesh(crown_mm, crown, true)
	var trees: Array[Vector2i] = run.map.trees
	trunk_mm.instance_count = trees.size()
	crown_mm.instance_count = trees.size() * 2
	for i in trees.size():
		var p := Vector3(trees[i].x + 0.5, 0, trees[i].y + 0.5)
		var sc: float = rng.randf_range(0.8, 1.3)
		trunk_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sc), p + Vector3(0, 1.1 * sc, 0)))
		var green: Color = Color(_biome()["foliage"]).lightened(rng.randf() * 0.15)
		if _biome()["palms"]:
			# Palm: tall thin trunk, one flat wide crown.
			trunk_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(0.7, 1.5, 0.7) * sc), p + Vector3(0, 1.65 * sc, 0)))
			crown_mm.set_instance_transform(i * 2, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(1.7, 0.3, 1.7) * sc), p + Vector3(0, 3.4 * sc, 0)))
			crown_mm.set_instance_color(i * 2, green)
			crown_mm.set_instance_transform(i * 2 + 1, Transform3D(Basis().scaled(Vector3.ZERO), p))
			continue
		for k in 2:
			var ks: float = sc * (1.0 - 0.3 * k)
			crown_mm.set_instance_transform(i * 2 + k, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * ks), p + Vector3(0, (2.4 + 1.1 * k) * sc, 0)))
			crown_mm.set_instance_color(i * 2 + k, green)
	var rock_mm := MultiMesh.new()
	var rock := SphereMesh.new()
	rock.radius = 0.6
	rock.height = 0.9
	rock.radial_segments = 7
	rock.rings = 4
	_setup_multimesh(rock_mm, rock, false, Color(0.45, 0.44, 0.42))
	rock_mm.instance_count = run.map.rocks.size()
	for i in run.map.rocks.size():
		var c: Vector2i = run.map.rocks[i]
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(rng.randf_range(0.8, 1.1), rng.randf_range(0.7, 1.2), rng.randf_range(0.8, 1.1)))
		rock_mm.set_instance_transform(i, Transform3D(b, Vector3(c.x + 0.5, 0.25, c.y + 0.5)))


func _setup_multimesh(mm: MultiMesh, mesh: Mesh, colors: bool, color: Color = Color.WHITE, unshaded: bool = false) -> void:
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors
	mm.mesh = mesh
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	var m := _mat(color, unshaded)
	m.vertex_color_use_as_albedo = colors
	inst.material_override = m
	add_child(inst)


func _mat(c: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _ring(center: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = radius - 0.12
	torus.outer_radius = radius
	ring.mesh = torus
	ring.position = center + Vector3(0, 0.05, 0)
	ring.material_override = _mat(color, true)
	add_child(ring)
	return ring


# --- Input and simulation -------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if showcase:
		return
	# Actions come from GameInput (InputMap): keyboard, mouse and gamepad alike.
	if event.is_echo() or not event.is_pressed():
		return
	if run.is_over():
		if event.is_action_pressed(&"confirm"):
			_finish()
		return
	if event.is_action_pressed(&"pause"):
		paused = not paused
	elif paused:
		if event.is_action_pressed(&"abandon"):
			_abandon()
	elif not run.card_choices.is_empty():
		for i in 3:
			if event.is_action_pressed(StringName("card_%d" % (i + 1))):
				run.choose_card(i)
	elif event.is_action_pressed(&"breaker"):
		_breaker_held = true
	elif event.is_action_pressed(&"ability"):
		_grenade_held = true
	elif event.is_action_pressed(&"weapon_next"):
		run.cycle_weapon()
	elif event.is_action_pressed(&"debug"):
		hud.debug_visible = not hud.debug_visible
	else:
		for i in 5:
			if event.is_action_pressed(StringName("weapon_%d" % (i + 1))):
				run.switch_weapon(i)


func _abandon() -> void:
	run.hp = 0.0
	run.objective = IslandRun.Objective.LOST
	paused = false


func _finish() -> void:
	var won: bool = run.objective == IslandRun.Objective.WON
	if context != null:
		run.save_to_context(context)
		finished.emit(won)
	else:
		get_tree().reload_current_scene()


func _physics_process(delta: float) -> void:
	if showcase:
		run.hp = run.max_hp
		run.card_choices.clear()
		run.step(delta, Vector2.ZERO, Vector3(1, 0, 0), false, true)  # sprint = gun silent
		return
	if paused:
		return
	if _hitstop > 0.0:
		_hitstop -= delta
		return
	var move: Vector2 = GameInput.move_vector()
	var stick: Vector2 = move
	var aim: Vector3 = _mouse_aim()
	var right := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if right.length() > 0.3:
		aim = Vector3(right.x, 0, right.y)
	elif stick.length() > 0.2 and aim == Vector3.ZERO:
		aim = Vector3(stick.x, 0, stick.y)
	var t0: int = Time.get_ticks_usec()
	var sprint: bool = Input.is_action_pressed(&"sprint")
	run.step(delta, move, aim, _breaker_held, sprint)
	if _grenade_held:
		# Without a mouse (gamepad) throw 8 m ahead.
		run.use_ability(aim if aim.length() > 1.0 else run.facing * 8.0)
		_grenade_held = false
	_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
	_breaker_held = false


func _mouse_aim() -> Vector3:
	if _camera == null or DisplayServer.get_name() == "headless":
		return Vector3.ZERO
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = _camera.project_ray_origin(mouse)
	var dir: Vector3 = _camera.project_ray_normal(mouse)
	if dir.y > -0.001:
		return Vector3.ZERO
	var hit: Vector3 = from + dir * ((1.0 - from.y) / dir.y)
	return Vector3(hit.x - run.player_pos.x, 0, hit.z - run.player_pos.z)


# --- Rendering -------------------------------------------------------------

func _process(delta: float) -> void:
	_play_audio()  # before drawing: the draw functions consume the run's events
	_draw_player_and_camera()
	_draw_enemies()
	_draw_orbs()
	_draw_grenades()
	_draw_laser()
	_draw_rocks()
	_draw_effects(delta)
	_draw_mission()
	_fade_occluders(delta)
	if showcase:
		var a: float = Time.get_ticks_msec() * 0.00006
		var c := Vector3(run.field.width * 0.5, 0, run.field.height * 0.5)
		_camera.position = c + Vector3(cos(a) * 45.0, 28.0, sin(a) * 45.0)
		_camera.look_at(c)
		return
	var label: String = ""
	if context != null:
		label = "Island %d/%d" % [context.island_index + 1, RunContext.ISLAND_COUNT]
		if context.modifier != &"calm":
			label += " [%s]" % GameData.modifier(context.modifier).title
	hud.refresh(run, _camera, _sim_ms, paused, label)


## Turns this frame's gameplay events into sounds.
func _play_audio() -> void:
	if showcase:
		music.update_mix(0.15, get_process_delta_time())
		run.tracers.clear()
		return
	# Music follows the director: peak = combat, build-up = halfway, relax = calm.
	var target: float = [0.5, 1.0, 0.0][run.director.phase]
	if run.objective == IslandRun.Objective.BOSS:
		target = 1.0
	music.update_mix(target if not run.is_over() else 0.0, get_process_delta_time())
	if not run.tracers.is_empty():
		sfx.play([&"rifle", &"shotgun", &"pistol", &"rifle", &"pistol"][run.weapon_index], -6.0, 0.06, 40)
	for d in run.deaths:
		if d.w > 0.5:
			sfx.play(&"headshot", -4.0, 0.1, 50)
		else:
			sfx.play(&"kill", -8.0, 0.15, 50)
	if not run.explosions.is_empty():
		sfx.play(&"explosion", 0.0, 0.1, 80)
	if run.dash_time > 0.0 and not _audio_dashing:
		sfx.play(&"breaker", -2.0)
	_audio_dashing = run.dash_time > 0.0
	if _audio_hp >= 0.0 and run.hp < _audio_hp:
		sfx.play(&"hurt", -6.0, 0.1, 180)
	_audio_hp = run.hp
	var total_xp: int = run.level * 1000 + run.xp
	if total_xp > _audio_xp and _audio_xp > 0:
		sfx.play(&"pickup", -12.0, 0.15, 45)
	_audio_xp = total_xp
	var cards: bool = not run.card_choices.is_empty()
	if cards and not _audio_cards:
		sfx.play(&"level_up", -4.0, 0.0)
	_audio_cards = cards
	var slam: bool = run.slam_time > 0.0
	if slam and not _audio_slam:
		sfx.play(&"slam_warn", 0.0, 0.0)
	_audio_slam = slam
	if run._scream_cd > _audio_scream_cd:
		sfx.play(&"scream", 0.0, 0.05)
	_audio_scream_cd = run._scream_cd
	var gens: int = 0
	for g in run.generator_progress:
		if g >= GameData.GENERATOR_HOLD_SECONDS:
			gens += 1
	if gens > _audio_generators:
		sfx.play(&"generator", -2.0, 0.0)
	_audio_generators = gens


func _draw_player_and_camera() -> void:
	var delta: float = get_process_delta_time()
	_player.position = run.player_pos
	_player.basis = Basis.looking_at(run.facing, Vector3.UP)
	# Stretch along the dash direction while breaking through.
	if run.dash_time > 0.0:
		_player.basis = Basis.looking_at(run.dash_dir, Vector3.UP).scaled(Vector3(0.8, 0.9, 1.6))
		if not _was_dashing:
			_trauma = minf(1.0, _trauma + 0.35)
	_was_dashing = run.dash_time > 0.0
	# Camera shake ("trauma" model): damage adds trauma, it decays quickly and
	# the offset grows with trauma squared so small hits stay subtle.
	if _last_hp >= 0.0 and run.hp < _last_hp:
		_trauma = minf(1.0, _trauma + (_last_hp - run.hp) * 0.04)
	_last_hp = run.hp
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	var shake: float = _trauma * _trauma * 0.6
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake
	var pitch: float = deg_to_rad(camera_pitch_deg)
	var offset := Vector3(0, sin(pitch), cos(pitch)) * camera_distance
	_camera.position = run.player_pos + Vector3(0, 1, 0) + offset + jitter
	_camera.look_at(run.player_pos + Vector3(0, 1, 0) + jitter * 0.5)
	# Muzzle flash: a short-lived light at the gun.
	_muzzle.light_energy = maxf(0.0, _muzzle.light_energy - delta * 40.0)


func _draw_enemies() -> void:
	var h: Horde = run.horde
	var now: float = Time.get_ticks_msec() * 0.001
	_enemy_mm.instance_count = h.count
	_head_mm.instance_count = h.count
	_arm_mm.instance_count = h.count * 2
	for i in h.count:
		var t: GameData.EnemyType = h.types[h.kinds[i]]
		var v: Vector3 = h.velocities[i]
		var speed: float = Vector2(v.x, v.z).length()
		var yaw: float = atan2(v.x, v.z) if speed > 0.1 else 0.0
		var sy: float = t.height / 1.7
		# Zombie waddle without bones: roll side to side, bob and lean forward
		# in proportion to speed. Stunned enemies wobble harder.
		var walk: float = clampf(speed / 2.5, 0.0, 1.0)
		var phase: float = now * (4.0 + speed * 2.0) + i * 1.7
		var roll: float = sin(phase) * 0.14 * walk
		var lean: float = 0.18 * walk
		if h.stun[i] > 0.0:
			roll = sin(now * 25.0 + i) * 0.3
			lean = -0.25
		var rot := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, lean) * Basis(Vector3.FORWARD, roll)
		var sx: float = t.radius_scale
		var bob: float = absf(sin(phase)) * 0.12 * walk
		var center: Vector3 = h.positions[i] + Vector3(0, t.height * 0.5 + bob, 0)
		_enemy_mm.set_instance_transform(i, Transform3D(rot.scaled(Vector3(sx, sy, sx)), center))
		# Local +Z is the walking direction (yaw = atan2(v.x, v.z)).
		var head_pos: Vector3 = center + rot * Vector3(0, t.height * 0.5 + 0.08 * sx, 0.06 * sx)
		_head_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * sx), head_pos))
		var swing: float = sin(phase) * 0.25 * walk
		for side in 2:
			var sign: float = -1.0 if side == 0 else 1.0
			var arm_rot: Basis = rot * Basis(Vector3.RIGHT, -0.15 + swing * sign)
			var arm_pos: Vector3 = center + rot * Vector3(0.3 * sign * sx, t.height * 0.28, 0.3 * sx)
			_arm_mm.set_instance_transform(i * 2 + side, Transform3D(arm_rot.scaled(Vector3.ONE * sx), arm_pos))
		var c: Color = t.color
		if h.flash[i] > 0.0:
			c = Color.WHITE
		elif h.stun[i] > 0.0:
			c = c.lightened(0.35)
		_enemy_mm.set_instance_color(i, c)
		_arm_mm.set_instance_color(i * 2, c)
		_arm_mm.set_instance_color(i * 2 + 1, c)
		# Heads are paler so they read as the target for headshots.
		_head_mm.set_instance_color(i, c if h.flash[i] > 0.0 else c.lerp(Color(0.85, 0.8, 0.7), 0.45))


## Laser sight from the gun: to the current target, red when a shot now
## would be a headshot, faint white otherwise.
func _draw_laser() -> void:
	_laser_mesh.clear_surfaces()
	if showcase or run.is_paused() or run.sprinting:
		return
	var info: Array = run.aim_info()
	var right := Vector3(-run.facing.z, 0, run.facing.x)
	var from: Vector3 = run.player_pos + Vector3(0, 1.2, 0) + right * 0.22 + run.facing * 0.9
	var to: Vector3 = from + run.facing * 12.0
	if info[0] != -1:
		to = run.horde.positions[info[0]] + Vector3(0, 1.5, 0)
	_laser_mat.albedo_color = Color(1, 0.15, 0.1, 0.8) if info[1] else Color(1, 1, 1, 0.3)
	_laser_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_laser_mesh.surface_add_vertex(from)
	_laser_mesh.surface_add_vertex(to)
	_laser_mesh.surface_end()


func _is_volcano() -> bool:
	return run.map.biome == &"volcano"


func _biome() -> Dictionary:
	return GameData.BIOMES.get(run.map.biome, GameData.BIOMES[&"beach"])


## Building colour by biome: painted houses in town, bright containers in the
## port, weathered stone elsewhere.
func _building_color(r: Rect2i, rng: RandomNumberGenerator) -> Color:
	match run.map.biome:
		&"town":
			var paints: Array[Color] = [Color(0.85, 0.8, 0.65), Color(0.75, 0.55, 0.45), Color(0.6, 0.7, 0.75), Color(0.85, 0.85, 0.82)]
			return paints[rng.randi_range(0, paints.size() - 1)]
		&"port":
			var paints: Array[Color] = [Color(0.75, 0.25, 0.15), Color(0.2, 0.4, 0.7), Color(0.85, 0.6, 0.15), Color(0.25, 0.55, 0.3)]
			return paints[rng.randi_range(0, paints.size() - 1)]
	return Color(_biome()["building"]).darkened(rng.randf() * 0.2)


func _draw_rocks() -> void:
	var n: int = run.rocks.size()
	_rock_mm.instance_count = n
	_rock_ring_mm.instance_count = n
	for i in n:
		var t: float = 1.0 - run.rock_times[i] / GameData.BOSS_ROCK_FLIGHT
		var target: Vector3 = run.rocks[i]
		var p: Vector3 = run.rock_origins[i].lerp(target, t) + Vector3(0, sin(t * PI) * 6.0, 0)
		_rock_mm.set_instance_transform(i, Transform3D(Basis(), p))
		_rock_ring_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * GameData.BOSS_ROCK_RADIUS), target + Vector3(0, 0.07, 0)))


func _draw_grenades() -> void:
	var n: int = run.grenades.size()
	_grenade_mm.instance_count = n
	_grenade_ring_mm.instance_count = n
	var radius: float = GameData.GRENADE_RADIUS + (1.0 if run.has_perk(&"demolitions") else 0.0)
	for i in n:
		var p: Vector3 = run.grenades[i]
		# Small arc: the grenade drops onto the target as the fuse runs out.
		var t: float = 1.0 - run.grenade_fuses[i] / GameData.GRENADE_FUSE
		var height: float = 0.25 + 2.0 * (1.0 - t) * t * 4.0 * 0.5
		_grenade_mm.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, height, 0)))
		_grenade_ring_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * radius), p + Vector3(0, 0.06, 0)))


func _draw_orbs() -> void:
	_orb_mm.instance_count = run.orbs.size()
	var bob: float = sin(Time.get_ticks_msec() * 0.006) * 0.15
	for i in run.orbs.size():
		_orb_mm.set_instance_transform(i, Transform3D(Basis(), run.orbs[i] + Vector3(0, 0.5 + bob, 0)))


func _draw_effects(delta: float) -> void:
	# Tracers: keep the last frame's shots visible for a few frames.
	if not run.tracers.is_empty():
		_tracers = run.tracers.duplicate()
		_muzzle.light_energy = 3.0
		run.tracers.clear()
		_tracer_life = 0.05
	_tracer_life -= delta
	_tracer_mesh.clear_surfaces()
	if _tracer_life > 0.0 and not _tracers.is_empty():
		_tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		for seg in _tracers:
			_tracer_mesh.surface_add_vertex(seg[0] + Vector3(0, 1.2, 0))
			_tracer_mesh.surface_add_vertex(seg[1] + Vector3(0, 1.2, 0))
		_tracer_mesh.surface_end()

	# Dismemberment with primitives: chunks fly off killed enemies.
	for d in run.deaths:
		var t: GameData.EnemyType = run.horde.types[int(d.z)]
		if int(d.z) in [GameData.EnemyKind.BRUTE, GameData.EnemyKind.BOSS]:
			_hitstop = 0.08  # freeze the simulation briefly: the kill "lands"
			_trauma = minf(1.0, _trauma + 0.3)
		var origin := Vector3(d.x, 1.0, d.y)
		var sx: float = t.radius_scale
		for k in 3:
			var vel := Vector3(randf_range(-3, 3), randf_range(3, 7), randf_range(-3, 3))
			_add_debris(origin + Vector3(0, t.height * 0.4, 0), vel, t.color, sx)
		if d.w > 0.5:
			# Headshot: the head pops off, upwards, with a spray of red bits.
			var head_col: Color = t.color.lerp(Color(0.85, 0.8, 0.7), 0.45)
			_add_debris(Vector3(d.x, t.height + 0.1, d.y), Vector3(randf_range(-2, 2), 9.0, randf_range(-2, 2)), head_col, -sx)
			for k in 4:
				_add_debris(Vector3(d.x, t.height, d.y), Vector3(randf_range(-4, 4), randf_range(4, 8), randf_range(-4, 4)), Color(0.75, 0.05, 0.05), 0.4)
		else:
			# Body shot: an arm comes off.
			_add_debris(origin + Vector3(0, t.height * 0.3, 0), Vector3(randf_range(-4, 4), 5.0, randf_range(-4, 4)), t.color, sx * 1.6)
	run.deaths.clear()
	var i: int = _debris_pos.size() - 1
	while i >= 0:
		_debris_life[i] -= delta
		if _debris_life[i] <= 0.0:
			_debris_pos.remove_at(i)
			_debris_vel.remove_at(i)
			_debris_life.remove_at(i)
			_debris_color.remove_at(i)
			_debris_size.remove_at(i)
		else:
			var v: Vector3 = _debris_vel[i]
			v.y -= 20.0 * delta
			var p: Vector3 = _debris_pos[i] + v * delta
			if p.y < 0.12:
				p.y = 0.12
				v = Vector3(v.x * 0.5, -v.y * 0.3, v.z * 0.5)
			_debris_pos[i] = p
			_debris_vel[i] = v
		i -= 1
	var heads: int = 0
	for sz in _debris_size:
		if sz < 0.0:
			heads += 1
	_debris_mm.instance_count = _debris_pos.size() - heads
	_head_debris_mm.instance_count = heads
	var bi: int = 0
	var hi: int = 0
	for k in _debris_pos.size():
		var sz: float = _debris_size[k]
		# Chunks tumble as they fly (rotation from remaining life).
		var spin := Basis(Vector3(1, 1, 0).normalized(), _debris_life[k] * 8.0)
		if sz < 0.0:
			_head_debris_mm.set_instance_transform(hi, Transform3D(Basis().scaled(Vector3.ONE * -sz), _debris_pos[k]))
			_head_debris_mm.set_instance_color(hi, _debris_color[k])
			hi += 1
		else:
			var scale := Vector3(sz, sz, sz) if sz < 1.2 else Vector3(0.5, 0.5, sz * 1.5)
			_debris_mm.set_instance_transform(bi, Transform3D(spin.scaled(scale), _debris_pos[k]))
			_debris_mm.set_instance_color(bi, _debris_color[k])
			bi += 1

	for e in run.explosions:
		var boom := MeshInstance3D.new()
		boom.mesh = _sphere(3.0)
		boom.position = e + Vector3(0, 0.5, 0)
		var bm := _mat(Color(1, 0.55, 0.1, 0.55), true)
		bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		boom.material_override = bm
		boom.scale = Vector3.ONE * 0.2
		add_child(boom)
		_explosions.append(boom)
	run.explosions.clear()
	for k in range(_explosions.size() - 1, -1, -1):
		var b: MeshInstance3D = _explosions[k]
		b.scale += Vector3.ONE * delta * 5.0
		(b.material_override as StandardMaterial3D).albedo_color.a = 0.55 * (1.0 - b.scale.x)
		if b.scale.x >= 1.0:
			b.queue_free()
			_explosions.remove_at(k)


func _add_debris(p: Vector3, v: Vector3, c: Color, size: float = 1.0) -> void:
	if _debris_pos.size() >= DEBRIS_MAX:
		return
	_debris_size.append(size)
	_debris_pos.append(p)
	_debris_vel.append(v)
	_debris_life.append(1.5)
	_debris_color.append(c)


## Buildings between the camera and the player fade out so the player is
## never hidden (AABB vs segment test: ~50 boxes per frame is cheap).
func _fade_occluders(delta: float) -> void:
	var from: Vector3 = _camera.global_position
	var to: Vector3 = run.player_pos + Vector3(0, 1.0, 0)
	for i in _buildings.size():
		var hit: bool = _building_boxes[i].grow(0.3).intersects_segment(from, to) != null
		var m: StandardMaterial3D = _buildings[i].material_override
		var target: float = 0.25 if hit else 1.0
		m.albedo_color.a = move_toward(m.albedo_color.a, target, delta * 4.0)
		# Opaque materials are cheaper and cast shadows: only go transparent when needed.
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if m.albedo_color.a >= 0.999 else BaseMaterial3D.TRANSPARENCY_ALPHA


func _draw_mission() -> void:
	for g in _generators.size():
		var p: float = run.generator_progress[g] / GameData.GENERATOR_HOLD_SECONDS
		var m: StandardMaterial3D = _generators[g].material_override
		if p >= 1.0:
			m.albedo_color = Color(0.2, 0.85, 0.3)
			_generator_rings[g].visible = false
		elif p > 0.0:
			m.albedo_color = Color(0.7, 0.2, 0.15).lerp(Color(1, 0.85, 0.2), p)
	_boat_ring.visible = run.objective == IslandRun.Objective.RETURN_TO_BOAT
	for c in _caches.size():
		var opened: bool = run.cache_progress[c] >= GameData.CACHE_OPEN_TIME
		var m: StandardMaterial3D = _caches[c].material_override
		m.albedo_color = Color(0.25, 0.25, 0.25) if opened else Color(0.3, 0.75, 0.85).lerp(Color.WHITE, run.cache_progress[c] / GameData.CACHE_OPEN_TIME)
	# Boss slam telegraph: a ring that pulses faster as the slam gets closer.
	_slam_ring.visible = run.slam_time > 0.0
	if _slam_ring.visible:
		_slam_ring.position = run.slam_pos + Vector3(0, 0.08, 0)
		var urgency: float = 1.0 - run.slam_time / GameData.BOSS_SLAM_WINDUP
		var m: StandardMaterial3D = _slam_ring.material_override
		m.albedo_color = Color(1, 0.2, 0.1).lerp(Color(1, 1, 1), absf(sin(urgency * urgency * 30.0)))
