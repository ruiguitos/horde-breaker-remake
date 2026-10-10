extends Node3D
## The island scene: reads input, steps IslandRun at a fixed 60 Hz and draws
## its state with primitives (MultiMesh for the horde, orbs and debris).

## Emitted when the player leaves the end-of-island panel.
signal finished(won: bool)

@export var rng_seed: int = 7
## Play this hand-made island (F6 on island.tscn to test one). Empty: the run
## picks one from HandmadeIsland.ISLANDS_DIR for the biome, or generates.
@export var handmade_scene: PackedScene

## Set by main before the scene enters the tree; null when run with F6.
var context: RunContext
var profile: Profile
var paused: bool = false
## Title-screen backdrop: no HUD, no input, hidden immortal player in the
## middle (the horde gathers around), slowly orbiting camera.
var showcase: bool = false
var _handmade: HandmadeIsland
@export_group("Camera")
@export var camera_pitch_deg: float = 35.0
@export var camera_distance: float = 10.0
@export var camera_fov: float = 60.0
@export_group("Third-person camera")
@export var tp_distance: float = 5.6
## Pivot height (chest). The pivot sits at the screen centre, so the soldier
## is framed above the bottom HUD panels and left of the crosshair.
@export var tp_height: float = 1.2
@export var tp_shoulder: float = 1.0  ## sideways offset (over the right shoulder)
@export var tp_pitch_min: float = -10.0
@export var tp_pitch_max: float = 45.0
@export_group("First-person camera")
@export var fp_eye_height: float = 1.72  ## the soldier's eyes (visor at ~1.8 m)
@export var fp_fov: float = 70.0
@export var fp_pitch_min: float = -60.0  ## looking up
@export var fp_pitch_max: float = 70.0  ## looking down

const DEBRIS_MAX: int = 600

var run: IslandRun
var hud: Hud
var sfx: Sfx
var fx: Fx
var music: Music
var _audio_hp: float = -1.0
var _audio_xp: int = 0
var _audio_dashing: bool = false
var _audio_cards: bool = false
var _audio_slam: bool = false
var _audio_generators: int = 0
var _audio_scream_cd: float = 0.0
var _audio_over: bool = false

var _camera: Camera3D
var _terrain: Node3D  ## Terrain3D ground, or null (flat tiles)
var _player: Node3D
var _walk_speed: float = 0.0  ## 0..1, drives the soldier's walk cycle
## Profile.CameraMode. First and third person: yaw/pitch in radians; the
## mouse (captured) or the right stick turns the view, WASD moves relative to
## it and auto-fire shoots what the centre crosshair is on. Fixed: the
## original medium camera, auto-fire aims with the body.
var camera_mode: int = Profile.CameraMode.THIRD_PERSON
var _tp_yaw: float = 0.0
## Positive looks down. 8 degrees puts the crosshair on chests from ~3 to ~20 m.
var _tp_pitch: float = deg_to_rad(8.0)
var _crosshair: Control
var _view_model: ViewModel  ## first-person placeholder gun (child of the camera)
var _camera_placed: bool = false  ## the camera has been positioned once
## Phantom Camera (addon) drives the third-person camera: a SpringArm3D
## follows `_tp_pivot` with damping. Null when the addon is missing.
var _pcam: Node3D
var _pcam_host: Node
var _tp_pivot: Node3D
var _enemy_mm := MultiMesh.new()
var _head_mm := MultiMesh.new()
var _arm_mm := MultiMesh.new()
var _orb_mm := MultiMesh.new()
var _debris_mm := MultiMesh.new()
var _tracer_mesh := ImmediateMesh.new()
var _generators: Array[MeshInstance3D] = []
var _generator_rings: Array[MeshInstance3D] = []
var _boat_ring: MeshInstance3D
var _boat: MeshInstance3D
## Expedition parts: a post with a ring at the Exit (the path to the next part).
var _exit_post: MeshInstance3D
var _defend_ring: MeshInstance3D
var _survivor: MeshInstance3D
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
	var biome: StringName = context.biome if context != null else &"beach"
	var island_seed: int = context.island_seed() if context != null else rng_seed
	var custom: IslandMap = null
	var scene: PackedScene = handmade_scene
	if scene == null and not showcase:
		scene = HandmadeIsland.pick(biome, island_seed)
	if scene != null:
		_handmade = scene.instantiate() as HandmadeIsland
		add_child(_handmade)
		var problems: Array[String] = []
		custom = _handmade.build_map(problems)
		for p in problems:
			push_warning("Hand-made island %s: %s" % [scene.resource_path, p])
	run = IslandRun.new(island_seed, biome, custom)
	if _handmade != null:
		run.play_area = _handmade.play_area
	if context != null:
		run.load_context(context)
	_build_world()
	sfx = Sfx.new()
	add_child(sfx)
	fx = Fx.new()
	add_child(fx)
	music = Music.new()
	add_child(music)
	add_child(Ambience.create(run.map.biome, -14.0 if not showcase else -18.0))
	if showcase:
		_player.visible = false
		sfx.process_mode = Node.PROCESS_MODE_DISABLED
		run.player_pos = Vector3(run.field.width * 0.5, 0, run.field.height * 0.5)
		run.director.trigger_peak(1000000.0)
		camera_mode = Profile.CameraMode.FIXED
		return
	camera_mode = profile.camera_mode if profile != null else Profile.CameraMode.THIRD_PERSON
	_tp_yaw = atan2(-run.facing.x, -run.facing.z)
	# Centre crosshair for the first / third-person cameras (auto-fire shoots
	# what it is on).
	var layer := CanvasLayer.new()
	add_child(layer)
	_crosshair = CenterContainer.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := Label.new()
	dot.text = "+"
	dot.add_theme_font_size_override("font_size", 28)
	dot.add_theme_color_override("font_outline_color", Color.BLACK)
	dot.add_theme_constant_override("outline_size", 6)
	_crosshair.add_child(dot)
	layer.add_child(_crosshair)
	_set_camera_mode(camera_mode, false)
	hud = Hud.new()
	hud.profile = profile if profile != null else Profile.new()
	hud.context = context
	hud.add_child(UiSfx.new())
	hud.card_chosen.connect(func(i: int) -> void: run.choose_card(i))
	hud.reroll_requested.connect(func() -> void: run.reroll_cards())
	hud.resume_requested.connect(func() -> void: paused = false)
	hud.abandon_requested.connect(_abandon)
	add_child(hud)


func _build_world() -> void:
	var island_i: int = context.island_index if context != null else 0
	if not _build_sky3d(island_i):
		_build_simple_sky(island_i)

	var f: FlowField = run.field
	var sea := MeshInstance3D.new()
	var sea_mesh := PlaneMesh.new()
	var sea_side: float = maxf(600.0, maxf(f.width, f.height) * 2.5)  # big islands need a bigger sea
	sea_mesh.size = Vector2(sea_side, sea_side)
	sea.mesh = sea_mesh
	sea.position = Vector3(f.width * 0.5, -0.3, f.height * 0.5)
	var sea_rows: int = clampi(int(sea_side / 5.0), 120, 400)  # vertices every 5-9 m for the waves
	sea_mesh.subdivide_width = sea_rows
	sea_mesh.subdivide_depth = sea_rows
	sea.material_override = Visuals.sea_material()
	add_child(sea)

	if _handmade != null:
		_use_handmade_world()
	else:
		_build_generated_world()
	for c in run.map.caches:
		var crate := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(1.0, 0.7, 0.7)
		crate.mesh = cm
		crate.position = _on_ground(c) + Vector3(0, 0.35, 0)
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
		gen.position = _on_ground(g) + Vector3(0, 1, 0)
		gen.material_override = _mat(Color(0.7, 0.2, 0.15))
		add_child(gen)
		_generators.append(gen)
		_generator_rings.append(_ring(g, GameData.GENERATOR_RADIUS, Color(1, 0.8, 0.2)))
		if run.mission != &"activate":
			gen.visible = false
			_generator_rings[-1].visible = false
	# Defend: an antenna in the middle of a big ring. Rescue: the survivor.
	var holds: bool = run.mission == &"defend" or run.mission == &"holdout"
	_defend_ring = _ring(run.site, GameData.DEFEND_RADIUS, Color(0.3, 0.8, 1.0))
	_defend_ring.visible = holds
	if holds:
		var mast := MeshInstance3D.new()
		var mm := CylinderMesh.new()
		mm.top_radius = 0.08
		mm.bottom_radius = 0.25
		mm.height = 6.0
		mast.mesh = mm
		mast.position = _on_ground(run.site) + Vector3(0, 3, 0)
		mast.material_override = _mat(Color(0.6, 0.65, 0.7))
		add_child(mast)
	_survivor = MeshInstance3D.new()
	_survivor.mesh = _capsule(0.35, 1.7)
	_survivor.material_override = _mat(Color(1.0, 0.55, 0.1))
	_survivor.visible = run.mission == &"rescue"
	add_child(_survivor)

	var boat := MeshInstance3D.new()
	var hull := BoxMesh.new()
	hull.size = Vector3(4, 1.2, 8)
	boat.mesh = hull
	boat.position = _boat_spot()
	boat.rotation.y = atan2(run.map.boat_dir.x, run.map.boat_dir.z)
	boat.material_override = _mat(Color(0.45, 0.3, 0.18))
	boat.visible = run.shows_boat()
	add_child(boat)
	_boat = boat
	# The extraction ring: at the Exit on expedition parts, else at the boat.
	_boat_ring = _ring(run.extraction_point(), GameData.BOAT_RADIUS, Color(0.3, 1, 0.4))
	_boat_ring.visible = false
	if run.has_exit():
		_exit_post = MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.12
		pm.bottom_radius = 0.18
		pm.height = 3.0
		_exit_post.mesh = pm
		_exit_post.position = _on_ground(run.map.exit) + Vector3(0, 1.5, 0)
		_exit_post.material_override = _mat(Color(0.3, 1, 0.4))
		add_child(_exit_post)
	_slam_ring = _ring(Vector3.ZERO, GameData.BOSS_SLAM_RADIUS, Color(1, 0.2, 0.1))
	_slam_ring.visible = false

	# Low-poly contractor in the selected class's kit (SoldierModel).
	var soldier := SoldierModel.create(run.player_class)
	_player = soldier
	_muzzle = OmniLight3D.new()
	_muzzle.light_color = Color(1, 0.8, 0.4)
	_muzzle.omni_range = 6.0
	_muzzle.light_energy = 0.0
	soldier.muzzle.add_child(_muzzle)
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

	_camera = Camera3D.new()
	_camera.fov = camera_fov
	add_child(_camera)
	_view_model = ViewModel.create(run.player_class)
	_view_model.visible = false
	_camera.add_child(_view_model)
	if _terrain != null:
		_terrain.call("set_camera", _camera)  # terrain LOD follows this camera
	# Biome colour grading (Color Grading addon; Forward+ only, High/Ultra).
	_camera.compositor = Grading.compositor_for(run.map.biome)
	Grading.apply(_camera)
	_setup_phantom_camera()


## Generated islands: ground (Terrain3D or tiles), buildings, props, roads,
## lava and the volcano, all drawn from the grid map.
func _build_generated_world() -> void:
	var f: FlowField = run.field
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
	if _build_terrain(cells, coast, rng):
		cells = []  # Terrain3D replaces the flat tiles
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
	IslandRoads.build(self, IslandRoads.plan(run.map))
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


## Hand-made islands: the scene already holds terrain, models and decor.
## Only the camera boxes come from it (buildings and rocks, real heights).
func _use_handmade_world() -> void:
	_terrain = _handmade.get_node_or_null("Terrain3D")
	var preview: Node3D = _handmade.get_node_or_null("Decor/SeaPreview")
	if preview != null:
		preview.visible = false  # the game draws its own animated sea
	_building_boxes.append_array(_handmade.object_boxes())


## Terrain3D ground (sloping sea floor, colour-mapped land). False when the
## addon is unavailable, so the flat tile ground is used instead.
func _build_terrain(cells: Array[Vector2i], coast: PackedInt32Array, rng: RandomNumberGenerator) -> bool:
	var f: FlowField = run.field
	var land := PackedByteArray()
	land.resize(f.width * f.height)
	var colors := PackedColorArray()
	colors.resize(f.width * f.height)
	var sand: Color = _biome()["coast"]
	var grass: Color = _biome()["inland"]
	for c in cells:
		var i: int = c.y * f.width + c.x
		land[i] = 1
		colors[i] = sand.lerp(grass, clampf((coast[i] - 4) / 8.0, 0.0, 1.0)).darkened(rng.randf() * 0.06)
	var terrain: Node3D = IslandTerrain.build(self, f.width, f.height, land, colors, sand.darkened(0.25))
	if terrain == null:
		return false
	_terrain = terrain
	return true


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
	var biome: StringName = run.map.biome
	if NatureKit.available() and NatureKit.TREES.has(biome):
		_build_kit_trees(rng, NatureKit.TREES[biome], 4.5 if biome != &"volcano" else 4.0)
	else:
		_build_primitive_trees(rng)
	if NatureKit.available():
		_build_kit_rocks(rng)
		_build_ground_cover(rng)
	else:
		_build_primitive_rocks(rng)


## Quaternius trees: one MultiMesh per model variant (each tree picks one).
func _build_kit_trees(rng: RandomNumberGenerator, models: Array, height: float) -> void:
	_scatter_models(rng, run.map.trees, models, height, 0.25)


func _build_kit_rocks(rng: RandomNumberGenerator) -> void:
	_scatter_models(rng, run.map.rocks, NatureKit.ROCKS, 1.0, 0.3)


## Grass, flowers, ferns or pebbles on free inland cells (decoration only:
## the cells stay walkable, so it is small and never hides enemies).
func _build_ground_cover(rng: RandomNumberGenerator) -> void:
	var models: Array = NatureKit.COVER.get(run.map.biome, [])
	if models.is_empty():
		return
	var f: FlowField = run.field
	var cells: Array[Vector2i] = []
	for i in 900:
		var c := Vector2i(rng.randi_range(2, f.width - 3), rng.randi_range(2, f.height - 3))
		if not f.is_blocked(c.x, c.y) and not f.is_blocked(c.x + 1, c.y) and not f.is_blocked(c.x, c.y + 1):
			cells.append(c)
	_scatter_models(rng, cells, models, 0.45, 0.4)


## Places one model per cell (random variant, rotation and size) using one
## MultiMesh per variant: a few draw calls for hundreds of props.
func _scatter_models(rng: RandomNumberGenerator, cells: Array[Vector2i], models: Array, height: float, size_jitter: float) -> void:
	var groups: Array[Array] = []
	for m in models:
		groups.append([])
	for c in cells:
		groups[rng.randi_range(0, models.size() - 1)].append(c)
	for k in models.size():
		var mesh: Mesh = NatureKit.mesh(models[k])
		if mesh == null or groups[k].is_empty():
			continue
		var base: float = NatureKit.scale_for(mesh, height)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = groups[k].size()
		for i in groups[k].size():
			var c: Vector2i = groups[k][i]
			var sc: float = base * rng.randf_range(1.0 - size_jitter, 1.0 + size_jitter)
			var jitter := Vector3(rng.randf_range(-0.25, 0.25), 0, rng.randf_range(-0.25, 0.25))
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(c.x + 0.5, 0, c.y + 0.5) + jitter))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		add_child(mmi)


func _build_primitive_trees(rng: RandomNumberGenerator) -> void:
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


func _build_primitive_rocks(rng: RandomNumberGenerator) -> void:
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


## Sky3D addon (MIT): physically based sky, clouds, sun and moon driven by a
## time-of-day clock. Returns false if the addon is missing (fallback below).
## Loaded by path so the game still parses without the addon.
const SKY3D_SCRIPT: String = "res://addons/sky_3d/src/Sky3D.gd"
## Starting hour per island: morning, golden afternoon, dusk on the volcano.
const ISLAND_HOURS: Array[float] = [9.0, 16.5, 16.25]


func _build_sky3d(island_i: int) -> bool:
	if not ResourceLoader.exists(SKY3D_SCRIPT):
		return false
	var sky: WorldEnvironment = (load(SKY3D_SCRIPT) as GDScript).new()
	add_child(sky)
	sky.set("current_time", ISLAND_HOURS[mini(island_i, ISLAND_HOURS.size() - 1)])
	# About one in-game hour per 5 real minutes: light shifts slowly while you play.
	sky.set("minutes_per_day", 120.0)
	sky.set("game_time_enabled", not showcase)
	sky.set("sun_energy", 1.1)
	if _is_volcano():
		# Dark ash reflects little light: lift the ambient so enemies still read.
		sky.set("ambient_energy", 1.8)
	var env: Environment = sky.environment
	_apply_biome_fog(env, false)
	GraphicsSettings.apply_environment(env)
	return true


## Fallback: flat procedural sky and a fixed sun (no addon needed).
func _build_simple_sky(island_i: int) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	var bio: Dictionary = _biome()
	env.environment.background_color = bio["sky"]
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.4, 0.42, 0.48)
	if _is_volcano():
		env.environment.ambient_light_color = Color(0.42, 0.34, 0.32)
	_apply_biome_fog(env.environment, true)
	if not env.environment.fog_enabled or float(bio["fog"]) > 0.0:
		env.environment.background_mode = Environment.BG_SKY
		env.environment.sky = Visuals.sky(Color(bio["sky"]).lightened(0.15), Color(bio["sky"]).darkened(0.35))
	GraphicsSettings.apply_environment(env.environment)
	add_child(env)
	var sun := DirectionalLight3D.new()
	GraphicsSettings.apply_sun(sun)
	match island_i:
		0:
			sun.rotation_degrees = Vector3(-55, -30, 0)
			sun.light_energy = 0.85
		1:
			sun.rotation_degrees = Vector3(-28, -65, 0)
			sun.light_color = Color(1.0, 0.82, 0.6)
			sun.light_energy = 0.95
		_:
			sun.rotation_degrees = Vector3(-18, -100, 0)
			sun.light_color = Color(1.0, 0.72, 0.58) if _is_volcano() else Color(1.0, 0.6, 0.45)
			sun.light_energy = 0.8
	add_child(sun)


## Jungle haze and the Sea Fog modifier, on whichever environment is used.
func _apply_biome_fog(env: Environment, flat_background: bool) -> void:
	var bio: Dictionary = _biome()
	if float(bio["fog"]) > 0.0:
		env.fog_enabled = true
		env.fog_light_color = Color(bio["sky"])
		env.fog_density = bio["fog"]
	if context != null and context.modifier == &"fog":
		env.fog_enabled = true
		env.fog_light_color = Color(0.48, 0.52, 0.56)
		env.fog_density = 0.018
		if flat_background:
			env.background_color = Color(0.48, 0.52, 0.56)



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
	ring.position = _on_ground(center) + Vector3(0, 0.05, 0)
	ring.material_override = _mat(color, true)
	add_child(ring)
	return ring


# --- Input and simulation -------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if showcase:
		return
	if _free_look() and event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = 0.0006 * (profile.mouse_sensitivity if profile != null else 50) / 10.0
		_tp_yaw -= event.relative.x * sens
		var limits: Vector2 = _pitch_limits()
		_tp_pitch = clampf(_tp_pitch + event.relative.y * sens, limits.x, limits.y)
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
	elif paused or not run.card_choices.is_empty():
		# The pause menu and the level-up cards are focus-driven HUD screens
		# (A/Enter on the focused button; the HUD handles reroll). Abandoning
		# needs the pause menu's hold-to-confirm: no shortcut key.
		return
	elif event.is_action_pressed(&"breaker"):
		_breaker_held = true
	elif event.is_action_pressed(&"ability"):
		_grenade_held = true
	elif event.is_action_pressed(&"weapon_next"):
		run.cycle_weapon()
	elif event.is_action_pressed(&"debug"):
		hud.debug_visible = not hud.debug_visible
	elif event.is_action_pressed(&"noclip"):
		run.noclip = not run.noclip
		run.messages.append("NOCLIP ON (Space up, Ctrl down, no walls, no damage)" if run.noclip else "NOCLIP OFF")
	elif event.is_action_pressed(&"camera_toggle"):
		# V cycles First person -> Third person -> Fixed.
		_set_camera_mode((camera_mode + 1) % Profile.CAMERA_MODE_NAMES.size())
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
		run.clear_crosshair()
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
	if _free_look():
		# Right stick turns the camera; movement is relative to where it looks
		# and auto-fire shoots what the centre crosshair is on.
		if right.length() > 0.2:
			_tp_yaw -= right.x * 2.6 * delta
			var limits: Vector2 = _pitch_limits()
			_tp_pitch = clampf(_tp_pitch + right.y * 1.6 * delta, limits.x, limits.y)
		var m3 := Vector3(move.x, 0, move.y).rotated(Vector3.UP, _tp_yaw)
		move = Vector2(m3.x, m3.z)
		aim = _tp_forward() * 12.0
		var ray: Array[Vector3] = crosshair_ray()
		run.set_crosshair(ray[0], ray[1])
	else:
		run.clear_crosshair()
		if right.length() > 0.3:
			aim = Vector3(right.x, 0, right.y)
		elif stick.length() > 0.2 and aim == Vector3.ZERO:
			aim = Vector3(stick.x, 0, stick.y)
	var t0: int = Time.get_ticks_usec()
	var sprint: bool = Input.is_action_pressed(&"sprint")
	run.step(delta, move, aim, _breaker_held, sprint)
	if _grenade_held:
		# First / third person: where the crosshair meets the ground. Without
		# a mouse (gamepad, fixed camera) throw 8 m ahead.
		var throw: Vector3 = _crosshair_ground_aim() if _free_look() else aim
		run.use_ability(throw if throw.length() > 1.0 else run.facing * 8.0)
		_grenade_held = false
	_sim_ms = lerpf(_sim_ms, (Time.get_ticks_usec() - t0) / 1000.0, 0.05)
	_breaker_held = false


func _mouse_aim() -> Vector3:
	if _free_look() or _camera == null or DisplayServer.get_name() == "headless":
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
	if profile != null and not showcase and profile.camera_mode != camera_mode:
		_set_camera_mode(profile.camera_mode, false)  # changed in Settings (pause)
	_update_mouse_mode()
	_draw_player_and_camera()
	_draw_enemies()
	_draw_orbs()
	_draw_grenades()
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
		if context.is_expedition():
			label = "%s %d/%d" % [context.part_name(), context.island_index + 1, context.island_count()]
		else:
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
		var wid: StringName = run.weapons[run.weapon_index].id
		var shot: StringName = {&"shotgun": &"shotgun", &"pistol": &"pistol", &"marksman": &"marksman"}.get(wid, &"rifle")
		sfx.play(shot, -10.0 if shot == &"pistol" or shot == &"marksman" else -6.0, 0.06, 40)
	# Events announced on the radio also get a sound.
	for key in run.radio:
		match key:
			&"cache":
				sfx.play(&"cache", -6.0, 0.05)
			&"survivor_found":
				sfx.play(&"survivor", -6.0, 0.0)
			&"low_hp":
				sfx.play(&"low_hp", -4.0, 0.0)
	if _audio_slam and run.slam_time <= 0.0:
		sfx.play(&"slam_hit", 0.0, 0.05)
	if run.is_over() and not _audio_over:
		_audio_over = true
		sfx.play(&"success" if run.objective == IslandRun.Objective.WON else &"game_over", -2.0, 0.0)
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


# --- First / third-person camera ------------------------------------------

## Horizontal direction the first / third-person camera looks at.
func _tp_forward() -> Vector3:
	return Vector3(0, 0, -1).rotated(Vector3.UP, _tp_yaw)


## Full look direction (yaw + pitch; positive pitch looks down).
func _look_dir() -> Vector3:
	return Basis.from_euler(Vector3(-_tp_pitch, _tp_yaw, 0)) * Vector3.FORWARD


## First or third person: mouse / right-stick look and the centre crosshair.
func _free_look() -> bool:
	return camera_mode != Profile.CameraMode.FIXED


func _pitch_limits() -> Vector2:
	if camera_mode == Profile.CameraMode.FIRST_PERSON:
		return Vector2(deg_to_rad(fp_pitch_min), deg_to_rad(fp_pitch_max))
	return Vector2(deg_to_rad(tp_pitch_min), deg_to_rad(tp_pitch_max))


## The crosshair ray [origin, direction] in world metres: from the camera
## through the screen centre, as seen. Before the camera is first placed it
## is derived from yaw/pitch (the eye, or the shoulder pivot).
func crosshair_ray() -> Array[Vector3]:
	if _camera_placed:
		return [_camera.global_position, -_camera.global_basis.z]
	if camera_mode == Profile.CameraMode.FIRST_PERSON:
		return [_view_pos() + Vector3(0, fp_eye_height, 0), _look_dir()]
	var right: Vector3 = _tp_forward().cross(Vector3.UP).normalized()
	return [_view_pos() + Vector3(0, tp_height, 0) + right * tp_shoulder, _look_dir()]


## Where the crosshair ray meets the ground, as a flat vector from the player
## (for the grenade); 12 m ahead when it points at the sky or too far.
func _crosshair_ground_aim() -> Vector3:
	var ray: Array[Vector3] = crosshair_ray()
	var d: float = 0.5
	while d <= GameData.GRENADE_RANGE + tp_distance + 2.0:
		var p: Vector3 = ray[0] + ray[1] * d
		if p.y <= run.map.ground_y(p):
			return Vector3(p.x - run.player_pos.x, 0, p.z - run.player_pos.z)
		d += 0.5
	return _tp_forward() * 12.0


## Switches the island camera (V cycles; Settings > Controls sets it too).
func _set_camera_mode(mode: int, save: bool = true) -> void:
	var was_free: bool = _free_look()
	camera_mode = clampi(mode, 0, Profile.CAMERA_MODE_NAMES.size() - 1)
	if was_free and not _free_look():
		# Keep the soldier facing where the camera was looking.
		run.facing = _tp_forward()
	elif _free_look() and not was_free:
		_tp_yaw = atan2(-run.facing.x, -run.facing.z)
	var limits: Vector2 = _pitch_limits()
	_tp_pitch = clampf(_tp_pitch, limits.x, limits.y)
	var first: bool = camera_mode == Profile.CameraMode.FIRST_PERSON
	if _crosshair != null:
		_crosshair.visible = _free_look()
	_set_pcam_active(camera_mode == Profile.CameraMode.THIRD_PERSON)
	_camera.h_offset = 0.0
	_camera.v_offset = 0.0
	_camera.fov = fp_fov if first else camera_fov
	_camera.near = 0.03 if first else 0.05  # the gun sits close to the eye
	(_player as SoldierModel).set_shadow_only(first)
	_view_model.visible = first
	_camera_placed = false  # the new camera is placed on the next frame
	if not _free_look():
		run.clear_crosshair()
	if save and profile != null:
		profile.camera_mode = camera_mode
		profile.save()


## Where shots leave the gun: the first-person gun's tip, else the soldier's.
func muzzle_position() -> Vector3:
	if camera_mode == Profile.CameraMode.FIRST_PERSON:
		return _view_model.tip.global_position
	return (_player as SoldierModel).muzzle.global_position


## Eye height, yaw + pitch. The body only casts its shadow; the placeholder
## gun is pulled back when a wall or slope is right in front of it.
func _update_first_person_camera(jitter: Vector3, delta: float) -> void:
	var eye: Vector3 = _view_pos() + Vector3(0, fp_eye_height, 0)
	var look: Vector3 = _look_dir()
	_camera.global_transform = Transform3D(Basis.from_euler(Vector3(-_tp_pitch, _tp_yaw, 0)), eye + jitter * 0.3)
	const REACH: float = 1.1  # a bit more than the barrel's reach from the eye
	var free: float = REACH
	for box in _building_boxes:
		var hit: Variant = _segment_hits_box(eye, eye + look * REACH, box)
		if hit != null:
			free = minf(free, float(hit))
	var d: float = 0.1
	while d < free:
		var p: Vector3 = eye + look * d
		if p.y < run.map.ground_y(p) + 0.05:
			free = d
			break
		d += 0.1
	_view_model.set_weapon(run.weapons[run.weapon_index].id)
	_view_model.update(delta, clampf(REACH - free, 0.0, ViewModel.MAX_PULL), _walk_speed, Time.get_ticks_msec() / 1000.0)


## The mouse is captured (hidden, turns the camera) only while playing in
## third person; menus, cards, pause and the end screen get it back.
func _update_mouse_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var playing: bool = _free_look() and not paused and run.card_choices.is_empty() and not run.is_over()
	var want: Input.MouseMode = Input.MOUSE_MODE_CAPTURED if playing else Input.MOUSE_MODE_VISIBLE
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	if _crosshair != null:
		_crosshair.visible = playing


## Over-the-shoulder: orbit behind the player at (yaw, pitch), offset to the
## right shoulder, and pulled closer when a building is in the way.
const PCAM_SCRIPT: String = "res://addons/phantom_camera/scripts/phantom_camera/phantom_camera_3d.gd"
const PCAM_HOST_SCRIPT: String = "res://addons/phantom_camera/scripts/phantom_camera_host/phantom_camera_host.gd"


## Phantom Camera in Third Person mode: the pivot node follows the player's
## chest + shoulder offset; the PCam's spring arm orbits it at (pitch, yaw).
func _setup_phantom_camera() -> void:
	if showcase or not ResourceLoader.exists(PCAM_SCRIPT) or not Engine.has_singleton(&"PhantomCameraManager"):
		return
	_tp_pivot = Node3D.new()
	_tp_pivot.name = "CameraPivot"
	add_child(_tp_pivot)
	_tp_pivot.global_position = _view_pos() + Vector3(0, tp_height, 0)
	_pcam_host = (load(PCAM_HOST_SCRIPT) as GDScript).new()
	_camera.add_child(_pcam_host)
	_pcam = (load(PCAM_SCRIPT) as GDScript).new()
	_pcam.set("follow_mode", 6)  # THIRD_PERSON
	_pcam.set("follow_target", _tp_pivot)
	_pcam.set("spring_length", tp_distance)
	_pcam.set("collision_mask", 0)  # buildings are not physics bodies; see below
	_pcam.set("follow_damping", true)
	_pcam.set("follow_damping_value", Vector3(0.08, 0.08, 0.08))
	_pcam.set("priority", 10)
	add_child(_pcam)
	_set_pcam_active(camera_mode == Profile.CameraMode.THIRD_PERSON)


func _set_pcam_active(on: bool) -> void:
	if _pcam_host != null:
		_pcam_host.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _update_third_person_camera(jitter: Vector3) -> void:
	if _pcam != null and is_instance_valid(_pcam) and bool(_pcam.get("_has_follow_spring_arm")):
		var fwd: Vector3 = _tp_forward()
		var right: Vector3 = fwd.cross(Vector3.UP).normalized()
		_tp_pivot.global_position = _view_pos() + Vector3(0, tp_height, 0) + right * tp_shoulder
		_pcam.call("set_third_person_rotation", Vector3(-_tp_pitch, _tp_yaw, 0))
		# Spring arm without physics: shorten it ourselves when a building is
		# between the pivot and the camera.
		var back: Vector3 = (-fwd * cos(_tp_pitch) + Vector3.UP * sin(_tp_pitch)).normalized()
		var dist: float = tp_distance
		for box in _building_boxes:
			var hit: Variant = _segment_hits_box(_tp_pivot.global_position, _tp_pivot.global_position + back * tp_distance, box)
			if hit != null:
				dist = minf(dist, maxf(0.8, float(hit) - 0.3))
		dist = _terrain_limit(_tp_pivot.global_position, back, dist)
		_pcam.call("set_spring_length", dist)
		# Shake through the camera's offsets (Phantom Camera owns its transform).
		_camera.h_offset = jitter.x
		_camera.v_offset = jitter.y
		return
	_update_manual_third_person_camera(jitter)


## Fallback without Phantom Camera (same framing, no damping).
func _update_manual_third_person_camera(jitter: Vector3) -> void:
	var fwd: Vector3 = _tp_forward()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var pivot: Vector3 = _view_pos() + Vector3(0, tp_height, 0) + right * tp_shoulder
	var back: Vector3 = (-fwd * cos(_tp_pitch) + Vector3.UP * sin(_tp_pitch)).normalized()
	var dist: float = tp_distance
	for box in _building_boxes:
		var hit: Variant = _segment_hits_box(pivot, pivot + back * tp_distance, box)
		if hit != null:
			dist = minf(dist, maxf(0.8, float(hit) - 0.3))
	dist = _terrain_limit(pivot, back, dist)
	_camera.position = pivot + back * dist + jitter
	_camera.look_at(pivot + jitter * 0.5)


## Shortens the camera arm so the camera never ends up inside a hill.
func _terrain_limit(pivot: Vector3, back: Vector3, dist: float) -> float:
	var d: float = 0.5
	while d <= dist:
		var p: Vector3 = pivot + back * d
		if p.y < run.map.ground_y(p) + 0.4:
			return maxf(0.8, d - 0.5)
		d += 0.5
	return dist


## Distance along the segment a→b to the box, or null if it does not hit.
func _segment_hits_box(a: Vector3, b: Vector3, box: AABB) -> Variant:
	var hit: Variant = box.intersects_segment(a, b)
	return null if hit == null else a.distance_to(hit)


## Noclip flight: height above the ground, only visual (the simulation stays
## on the 2D grid). Space rises, Ctrl descends; noclip off lands you again.
var _fly: float = 0.0
const FLY_SPEED: float = 12.0
const FLY_MAX: float = 120.0


## A simulation point (y = 0) lifted onto the terrain.
func _on_ground(p: Vector3) -> Vector3:
	return Vector3(p.x, p.y + run.map.ground_y(p), p.z)


func _view_pos() -> Vector3:
	return _on_ground(run.player_pos) + Vector3(0, _fly, 0)


func _draw_player_and_camera() -> void:
	var delta: float = get_process_delta_time()
	if run.noclip:
		var climb: float = float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
		var speed: float = FLY_SPEED * (3.0 if Input.is_action_pressed(&"sprint") else 1.0)
		_fly = clampf(_fly + climb * speed * delta, 0.0, FLY_MAX)
	else:
		_fly = move_toward(_fly, 0.0, FLY_SPEED * 2.0 * delta)
	var moved: float = _player.position.distance_to(_view_pos())
	_walk_speed = lerpf(_walk_speed, clampf(moved / maxf(delta, 0.001) / 6.0, 0.0, 1.0), 0.2)
	(_player as SoldierModel).animate(_walk_speed, Time.get_ticks_msec() / 1000.0)
	_player.position = _view_pos()
	_player.basis = Basis.looking_at(run.facing, Vector3.UP)
	# Stretch along the dash direction while breaking through.
	if run.dash_time > 0.0:
		_player.basis = Basis.looking_at(run.dash_dir, Vector3.UP).scaled(Vector3(0.8, 0.9, 1.6))
		if not _was_dashing:
			_trauma = minf(1.0, _trauma + 0.35)
			fx.emit(&"dust", _on_ground(run.player_pos) + Vector3(0, 0.3, 0))
	_was_dashing = run.dash_time > 0.0
	# Camera shake ("trauma" model): damage adds trauma, it decays quickly and
	# the offset grows with trauma squared so small hits stay subtle.
	if _last_hp >= 0.0 and run.hp < _last_hp:
		_trauma = minf(1.0, _trauma + (_last_hp - run.hp) * 0.04)
	_last_hp = run.hp
	_trauma = maxf(0.0, _trauma - delta * 1.8)
	var shake: float = _trauma * _trauma * 0.6
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake
	match camera_mode:
		Profile.CameraMode.FIRST_PERSON:
			_update_first_person_camera(jitter, delta)
		Profile.CameraMode.THIRD_PERSON:
			_update_third_person_camera(jitter)
		_:
			var pitch: float = deg_to_rad(camera_pitch_deg)
			var offset := Vector3(0, sin(pitch), cos(pitch)) * camera_distance
			_camera.position = _view_pos() + Vector3(0, 1, 0) + offset + jitter
			_camera.look_at(_view_pos() + Vector3(0, 1, 0) + jitter * 0.5)
	_camera_placed = not showcase
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
		var center: Vector3 = _on_ground(h.positions[i]) + Vector3(0, t.height * 0.5 + bob, 0)
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


## Where a tracer ends: 1.2 m up, or (crosshair aim) at the height of the
## crosshair ray over that spot, so shots fly to what the crosshair is on.
func _tracer_end(hit: Vector3, from_player: bool) -> Vector3:
	var end: Vector3 = _on_ground(hit) + Vector3(0, 1.2, 0)
	if not from_player or not run.uses_crosshair():
		return end
	var o: Vector3 = run.crosshair_origin
	var dir: Vector3 = run.crosshair_dir
	var flat: float = Vector2(dir.x, dir.z).length()
	if flat < 0.05:
		return end
	var along: float = Vector2(hit.x - o.x, hit.z - o.z).length() / flat
	var ground: float = end.y - 1.2
	end.y = clampf(o.y + dir.y * along, ground + 0.2, ground + 2.5)
	return end


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
		_rock_ring_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * GameData.BOSS_ROCK_RADIUS), _on_ground(target) + Vector3(0, 0.07, 0)))


func _draw_grenades() -> void:
	var n: int = run.grenades.size()
	_grenade_mm.instance_count = n
	_grenade_ring_mm.instance_count = n
	var radius: float = GameData.GRENADE_RADIUS + (1.0 if run.has_perk(&"demolitions") else 0.0)
	for i in n:
		var p: Vector3 = _on_ground(run.grenades[i])
		# Small arc: the grenade drops onto the target as the fuse runs out.
		var t: float = 1.0 - run.grenade_fuses[i] / GameData.GRENADE_FUSE
		var height: float = 0.25 + 2.0 * (1.0 - t) * t * 4.0 * 0.5
		_grenade_mm.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, height, 0)))
		_grenade_ring_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * radius), p + Vector3(0, 0.06, 0)))


func _draw_orbs() -> void:
	_orb_mm.instance_count = run.orbs.size()
	var bob: float = sin(Time.get_ticks_msec() * 0.006) * 0.15
	for i in run.orbs.size():
		_orb_mm.set_instance_transform(i, Transform3D(Basis(), _on_ground(run.orbs[i]) + Vector3(0, 0.5 + bob, 0)))


func _draw_effects(delta: float) -> void:
	# Tracers: keep the last frame's shots visible for a few frames.
	if not run.tracers.is_empty():
		# Sparks where shots land (a few per frame is plenty).
		for k in mini(run.tracers.size(), 4):
			var seg: PackedVector3Array = run.tracers[k]
			fx.emit(&"spark", _on_ground(seg[1]) + Vector3(0, 1.2, 0), seg[0] - seg[1])
		_tracers = run.tracers.duplicate()
		_muzzle.light_energy = 3.0
		if camera_mode == Profile.CameraMode.FIRST_PERSON:
			_view_model.fire()
		run.tracers.clear()
		_tracer_life = 0.05
	_tracer_life -= delta
	_tracer_mesh.clear_surfaces()
	if _tracer_life > 0.0 and not _tracers.is_empty():
		_tracer_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
		var muzzle: Vector3 = muzzle_position()
		for seg in _tracers:
			# Shots start at the gun; ricochets go from enemy to enemy.
			var from_player: bool = Vector2(seg[0].x - run.player_pos.x, seg[0].z - run.player_pos.z).length() < 1.0
			_tracer_mesh.surface_add_vertex(muzzle if from_player else _on_ground(seg[0]) + Vector3(0, 1.2, 0))
			_tracer_mesh.surface_add_vertex(_tracer_end(seg[1], from_player))
		_tracer_mesh.surface_end()

	# Dismemberment with primitives: chunks fly off killed enemies.
	for d in run.deaths:
		var t: GameData.EnemyType = run.horde.types[int(d.z)]
		var gy: float = run.map.ground_y(Vector3(d.x, 0, d.y))
		fx.emit(&"blood", Vector3(d.x, gy + t.height * 0.7, d.y))
		if int(d.z) in [GameData.EnemyKind.BRUTE, GameData.EnemyKind.BOSS]:
			_hitstop = 0.08  # freeze the simulation briefly: the kill "lands"
			_trauma = minf(1.0, _trauma + 0.3)
		var origin := Vector3(d.x, gy + 1.0, d.y)
		var sx: float = t.radius_scale
		for k in 3:
			var vel := Vector3(randf_range(-3, 3), randf_range(3, 7), randf_range(-3, 3))
			_add_debris(origin + Vector3(0, t.height * 0.4, 0), vel, t.color, sx)
		if d.w > 0.5:
			# Headshot: the head pops off, upwards, with a spray of red bits.
			var head_col: Color = t.color.lerp(Color(0.85, 0.8, 0.7), 0.45)
			_add_debris(Vector3(d.x, gy + t.height + 0.1, d.y), Vector3(randf_range(-2, 2), 9.0, randf_range(-2, 2)), head_col, -sx)
			for k in 4:
				_add_debris(Vector3(d.x, gy + t.height, d.y), Vector3(randf_range(-4, 4), randf_range(4, 8), randf_range(-4, 4)), Color(0.75, 0.05, 0.05), 0.4)
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
			var floor_y: float = run.map.ground_y(p) + 0.12
			if p.y < floor_y:
				p.y = floor_y
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
		boom.position = _on_ground(e) + Vector3(0, 0.5, 0)
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
		# First person: the camera is the soldier's eyes, nothing to see through.
		var hit: bool = camera_mode != Profile.CameraMode.FIRST_PERSON and _building_boxes[i].grow(0.3).intersects_segment(from, to) != null
		var m: StandardMaterial3D = _buildings[i].material_override
		var target: float = 0.25 if hit else 1.0
		m.albedo_color.a = move_toward(m.albedo_color.a, target, delta * 4.0)
		# Opaque materials are cheaper and cast shadows: only go transparent when needed.
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if m.albedo_color.a >= 0.999 else BaseMaterial3D.TRANSPARENCY_ALPHA


## Where the boat model floats: moored 3 m out from the Boat marker; the
## holdout's rescue boat starts 90 m out to sea and glides in as it arrives.
func _boat_spot() -> Vector3:
	var out: float = 3.0
	if run.mission == &"holdout":
		var t: float = run.boat_arrival()
		out = lerpf(90.0, 3.0, 1.0 - (1.0 - t) * (1.0 - t))  # eases into the pier
	var p: Vector3 = run.map.boat + run.map.boat_dir * out
	return Vector3(p.x, 0.3 + sin(Time.get_ticks_msec() * 0.0015) * 0.08, p.z)


func _draw_mission() -> void:
	if run.mission == &"rescue":
		_survivor.visible = not run.survivor_lost
		_survivor.position = _on_ground(run.survivor_pos) + Vector3(0, 0.85 + (0.0 if run.survivor_found else absf(sin(Time.get_ticks_msec() * 0.006)) * 0.3), 0)
	if run.mission == &"defend" or run.mission == &"holdout":
		var m2: StandardMaterial3D = _defend_ring.material_override
		var inside: bool = run.player_pos.distance_to(run.site) <= GameData.DEFEND_RADIUS
		m2.albedo_color = Color(0.3, 1.0, 0.5) if inside else Color(0.3, 0.8, 1.0)
		_defend_ring.visible = run.objective == IslandRun.Objective.GENERATORS
	for g in _generators.size():
		var p: float = run.generator_progress[g] / GameData.GENERATOR_HOLD_SECONDS
		var m: StandardMaterial3D = _generators[g].material_override
		if p >= 1.0:
			m.albedo_color = Color(0.2, 0.85, 0.3)
			_generator_rings[g].visible = false
		elif p > 0.0:
			m.albedo_color = Color(0.7, 0.2, 0.15).lerp(Color(1, 0.85, 0.2), p)
	_boat_ring.visible = run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.boat_eta <= 0.0
	if run.mission == &"holdout":
		# The rescue boat sails in from the sea to the pier once called.
		_boat.visible = run.shows_boat()
		_boat.position = _boat_spot()
	for c in _caches.size():
		var opened: bool = run.cache_progress[c] >= GameData.CACHE_OPEN_TIME
		var m: StandardMaterial3D = _caches[c].material_override
		m.albedo_color = Color(0.25, 0.25, 0.25) if opened else Color(0.3, 0.75, 0.85).lerp(Color.WHITE, run.cache_progress[c] / GameData.CACHE_OPEN_TIME)
	# Boss slam telegraph: a ring that pulses faster as the slam gets closer.
	_slam_ring.visible = run.slam_time > 0.0
	if _slam_ring.visible:
		_slam_ring.position = _on_ground(run.slam_pos) + Vector3(0, 0.08, 0)
		var urgency: float = 1.0 - run.slam_time / GameData.BOSS_SLAM_WINDUP
		var m: StandardMaterial3D = _slam_ring.material_override
		m.albedo_color = Color(1, 0.2, 0.1).lerp(Color(1, 1, 1), absf(sin(urgency * urgency * 30.0)))
