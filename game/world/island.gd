extends Node3D
## The island scene: reads input, steps IslandRun at a fixed 60 Hz and draws
## its state with primitives (MultiMesh for the horde, orbs and debris).

## Emitted when the player leaves the end-of-island panel.
signal finished(won: bool)

@export var rng_seed: int = 7
## Play this hand-made island (F6 on island.tscn to test one). Empty: the run
## picks one from HandmadeIsland.ISLANDS_DIR for the biome, or generates.
@export var handmade_scene: PackedScene
## Disable to compare the original primitive props without removing assets.
@export var realistic_props: bool = true

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
## Sideways offset of the pivot (over the right shoulder). 1.6 m at 5.6 m
## puts the soldier in the left part of the view, clear of the crosshair;
## it shrinks when a building is right beside the soldier (_tp_pivot_pos).
@export var tp_shoulder: float = 1.6
@export var tp_pitch_min: float = -10.0
@export var tp_pitch_max: float = 45.0
@export_group("First-person camera")
@export var fp_eye_height: float = 1.72  ## the soldier's eyes (visor at ~1.8 m)
@export var fp_fov: float = 70.0
@export var fp_pitch_min: float = -60.0  ## looking up
@export var fp_pitch_max: float = 70.0  ## looking down

const DEBRIS_MAX: int = 600
## Fuel Run: cans, their beacons and the delivery ring (same colour as on
## the minimap).
const FUEL_COLOR := Minimap.FUEL_COLOR
## Where a carried can hangs (its base), in the soldier's space: right hand.
const CARRY_OFFSET := Vector3(0.38, 0.25, 0.05)
## Nests: the glowing core (same colour as the minimap marker), the mound's
## flesh and the scorch left behind.
const NEST_CORE_COLOR := Minimap.NEST_COLOR
const NEST_FLESH_COLOR := Color(0.33, 0.2, 0.24)
const NEST_SCORCH_COLOR := Color(0.09, 0.07, 0.07)
## The HP bar over a damaged nest shows within this distance (metres).
const NEST_BAR_RANGE: float = 40.0
## Intel Search: spot beacons, rings and the uplink (same colour as the
## minimap); a searched spot without intel turns this grey.
const INTEL_COLOR := Minimap.INTEL_COLOR
const SEARCHED_COLOR := Color(0.45, 0.45, 0.45)
## Light the Signals: the beacon of the next signal and the fire of a lit
## one (same colours as the minimap). The light is one OmniLight3D per
## signal, without shadows, off until the signal is lit.
const SIGNAL_COLOR := Minimap.SIGNAL_COLOR
const SIGNAL_FIRE_COLOR := Minimap.SIGNAL_LIT_COLOR
const SIGNAL_LIGHT_RANGE: float = 14.0
const LIGHTHOUSE_LIGHT_RANGE: float = 45.0
## A lighthouse signal looks for the hand-made scene's tower
## (Buildings/Lighthouse_*) this close to its marker; without one it builds
## a stone tower this tall.
const LIGHTHOUSE_SEARCH_M: float = 40.0
const LIGHTHOUSE_TOWER_M: float = 9.0
## The lighthouse beam: length (m) and turns per second once lit.
const LIGHTHOUSE_BEAM_M: float = 36.0
const LIGHTHOUSE_BEAM_SPEED: float = 0.12
## Sabotage: the switch and the charges (same colours as the minimap), the
## machines' lamps while the line is live (an OmniLight3D each, no shadows,
## off once the power is cut) and the blast's camera trauma near it.
const POWER_COLOR := Minimap.POWER_COLOR
const CHARGE_COLOR := Minimap.CHARGE_COLOR
const MACHINE_LAMP_COLOR := Color(1.0, 0.72, 0.25)
const MACHINE_LIGHT_RANGE: float = 9.0
const BLAST_SHAKE_RANGE: float = 60.0
## Escort: the route's arrows on the ground (and the minimap's line) share
## the cart's amber; one arrow every ESCORT_ARROW_STEP metres of the route
## still ahead. The cart's bar and status show within ESCORT_BAR_RANGE.
const ESCORT_COLOR := Minimap.ESCORT_COLOR
const ESCORT_STOP_COLOR := Minimap.STOP_COLOR
const ESCORT_ARROW_STEP: float = 3.0
const ESCORT_BAR_RANGE: float = 45.0

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
var _terrain_data: Object  ## its Terrain3DData (real heights), or null
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
## Phantom Camera (addon) drives the third-person camera: a SpringArm3D
## follows `_tp_pivot` (without damping, see _setup_phantom_camera).
## Null when the addon is missing.
var _pcam: Node3D
var _pcam_host: Node
var _tp_pivot: Node3D
var _enemy_mm := MultiMesh.new()
var _head_mm := MultiMesh.new()
var _arm_mm := MultiMesh.new()
var _orb_mm := MultiMesh.new()
var _cloud_mm := MultiMesh.new()
var _debris_mm := MultiMesh.new()
var _tracer_mesh := ImmediateMesh.new()
var _generators: Array[MeshInstance3D] = []
var _generator_rings: Array[MeshInstance3D] = []
var _boat_ring: MeshInstance3D
var _boat: MeshInstance3D
## Expedition parts: a post with a ring at the Exit (the path to the next part).
var _exit_post: MeshInstance3D
var _defend_ring: MeshInstance3D
## Hold Sequence: the ring and the beacon of the active point (they move on
## to the next point once one is held).
var _hold_ring: MeshInstance3D
var _hold_beacon: MeshInstance3D
## Fuel Run: one node per can (jerrycan model or an orange box, with a
## beacon above it while it waits on the ground) and the delivery ring.
var _cans: Array[Node3D] = []
var _can_beacons: Array[MeshInstance3D] = []
var _delivery_ring: MeshInstance3D
## Nests: one root per nest (mound, lumps, pulsing core, HP bar) and the
## scorch shown once it is destroyed. _nest_dead remembers which ones
## already burst (debris once).
var _nests: Array[Node3D] = []
var _nest_cores: Array[MeshInstance3D] = []
var _nest_bars: Array[Node3D] = []
var _nest_fills: Array[MeshInstance3D] = []
var _nest_scorches: Array[MeshInstance3D] = []
var _nest_dead: Array[bool] = []
## Intel Search: one root per spot (a crate, a beacon above it, a ring of
## the search radius and a disc that grows with the search), the uplink
## (an antenna with its ring and progress disc).
var _search_spots: Array[Node3D] = []
var _search_beacons: Array[MeshInstance3D] = []
var _search_rings: Array[MeshInstance3D] = []
var _search_fills: Array[MeshInstance3D] = []
var _search_crates: Array[Node3D] = []
var _search_greyed: Array[bool] = []
var _uplink: Node3D
var _uplink_ring: MeshInstance3D
var _uplink_fill: MeshInstance3D
## Light the Signals: one root per signal (a stone brazier; hidden until it
## is the next one), its beacon and ring while it waits, a disc that grows
## with the lighting, and its fire (flame meshes + light, shown once lit).
## The lighthouse adds a turning beam at the top of its tower.
var _signals: Array[Node3D] = []
var _signal_beacons: Array[MeshInstance3D] = []
var _signal_rings: Array[MeshInstance3D] = []
var _signal_fills: Array[MeshInstance3D] = []
var _signal_fires: Array[Node3D] = []
var _signal_lights: Array[OmniLight3D] = []
var _signal_beam: Node3D
## Sabotage: the switch cabinet (its lamp, ring, beacon, disc), one root per
## machine (motor housing with a live lamp and light, the charge block that
## shows once planted), their rings, beacons and discs, the blast rings
## shown during the fuse, the scorches left after it, and whether the scene
## has played the power cut and the blast yet.
var _power_switch: Node3D
var _power_lamp: MeshInstance3D
var _power_ring: MeshInstance3D
var _power_beacon: MeshInstance3D
var _power_fill: MeshInstance3D
var _machines: Array[Node3D] = []
var _machine_lamps: Array[MeshInstance3D] = []
var _machine_lights: Array[OmniLight3D] = []
var _charges: Array[MeshInstance3D] = []
var _charge_rings: Array[MeshInstance3D] = []
var _charge_beacons: Array[MeshInstance3D] = []
var _charge_fills: Array[MeshInstance3D] = []
var _blast_rings: Array[MeshInstance3D] = []
var _machine_scorches: Array[MeshInstance3D] = []
var _sabotage_seen_cut: bool = false
var _sabotage_seen_blast: bool = false
## Escort: the cart (or survivor) model, its HP bar (back and fill, both
## billboards), the status label over it, the ring of escort_radius() that
## follows it, the arrows of the route ahead (a MultiMesh, nearest last, so
## visible_instance_count hides the ones it has passed), a post at each
## stop, and the model's smoothed heading.
var _escort: EscortModel
var _escort_bar: Node3D
var _escort_fill: MeshInstance3D
var _escort_label: Label3D
var _escort_ring: MeshInstance3D
var _escort_arrows := MultiMesh.new()
var _escort_stop_posts: Array[Node3D] = []
var _escort_yaw: float = 0.0
var _survivor: MeshInstance3D
var _caches: Array[MeshInstance3D] = []
var _buildings: Array[MeshInstance3D] = []
var _building_boxes: Array[AABB] = []
var _building_detail_mats: Array[StandardMaterial3D] = []
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
var _zombies := ZombieHordeView.new()  ## common zombies and six distinct special models
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
var _power_up_visual: Node3D
var _power_up_glyph: Label3D
var _power_up_name: Label3D


func _ready() -> void:
	GameInput.setup()
	var biome: StringName = context.biome if context != null else &"beach"
	var island_seed: int = context.island_seed() if context != null else rng_seed
	var custom: IslandMap = null
	var scene: PackedScene = handmade_scene
	if scene == null and not showcase:
		scene = HandmadeIsland.pick(biome, island_seed, context.mission if context != null else &"")
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
	hud.continue_requested.connect(_finish)
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
		if realistic_props:
			var detail: Node3D = IslandProps.create(&"crate", 0.7)
			if detail != null:
				# The coloured beacon keeps cache progress readable above the wood.
				crate.mesh = _sphere(0.12)
				crate.position = _on_ground(c) + Vector3(0, 1.0, 0)
				detail.position.y -= 1.0
				crate.add_child(detail)
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
		if realistic_props:
			var detail: Node3D = IslandProps.create(&"generator", 1.0)
			if detail != null:
				gen.mesh = _sphere(0.12)
				gen.position = _on_ground(g) + Vector3(0, 1.3, 0)
				detail.position.y -= 1.3
				gen.add_child(detail)
				var can: Node3D = IslandProps.create(&"jerrycan")
				if can != null:
					var slope: float = run.map.ground_y(g + Vector3(0.8, 0, 0)) - run.map.ground_y(g)
					can.position += Vector3(0.8, -1.3 + slope, 0)
					gen.add_child(can)
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
	_hold_ring = _ring(run.site, IslandRun.hold_radius(), Color(0.3, 0.8, 1.0))
	_hold_ring.visible = run.mission == &"hold_sequence"
	_hold_beacon = MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.1
	bm.bottom_radius = 0.3
	bm.height = 4.0
	_hold_beacon.mesh = bm
	_hold_beacon.material_override = _mat(Color(0.3, 0.8, 1.0))
	_hold_beacon.position = _on_ground(run.site) + Vector3(0, 2, 0)
	_hold_beacon.visible = run.mission == &"hold_sequence"
	add_child(_hold_beacon)
	if run.mission == &"fuel_run":
		for c in run.cargo_pos.size():
			_build_fuel_can()
		_delivery_ring = _ring(run.delivery_point(), IslandRun.cargo_delivery_radius(), FUEL_COLOR)
	if run.mission == &"nests":
		for n in run.nest_pos.size():
			_build_nest(run.nest_pos[n])
	if run.mission == &"intel_search":
		for k in run.search_pos.size():
			_build_search_spot(run.search_pos[k])
		_build_uplink(run.uplink_pos)
	if run.mission == &"signals":
		for i in run.signal_pos.size():
			_build_signal(run.signal_pos[i], run.signal_lighthouse and i == run.signal_pos.size() - 1)
		for c in run.cargo_pos.size():
			_build_fuel_can()
	if run.mission == &"sabotage":
		_build_sabotage()
	if run.mission == &"escort":
		_build_escort()
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
	soldier.ground_height = ground_height
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
	add_child(_zombies)

	var tracer := MeshInstance3D.new()
	tracer.mesh = _tracer_mesh
	var tmat := _mat(Color(1, 0.9, 0.4), true)
	tracer.material_override = tmat
	add_child(tracer)

	_camera = Camera3D.new()
	_camera.fov = _camera_fov(camera_mode == Profile.CameraMode.FIRST_PERSON)
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
		var detail_material: StandardMaterial3D = null
		if realistic_props and (r.size.x == 1 or r.size.y == 1):
			var wall: MultiMeshInstance3D = IslandProps.barrier_wall(Vector3(r.size.x, h, r.size.y))
			if wall != null:
				b.mesh = null
				b.add_child(wall)
				detail_material = wall.material_override as StandardMaterial3D
		add_child(b)
		_buildings.append(b)
		_building_detail_mats.append(detail_material)
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


## One Fuel Run can: the CC0 jerrycan model (IslandProps) or, without it,
## an orange box of the same size; plus a thin beacon above it, shown while
## the can waits on the ground so it can be found from afar.
func _build_fuel_can() -> void:
	var can := Node3D.new()
	can.name = "FuelCan%d" % _cans.size()
	var model: Node3D = IslandProps.create(&"jerrycan", 0.5) if realistic_props else null
	if model != null:
		can.add_child(model)
	else:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.5, 0.36)
		box.mesh = bm
		box.position.y = 0.25
		box.material_override = _mat(FUEL_COLOR.darkened(0.2))
		can.add_child(box)
	var beacon := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.12
	cm.height = 3.0
	beacon.mesh = cm
	beacon.position.y = 2.0
	beacon.material_override = _mat(FUEL_COLOR, true)
	can.add_child(beacon)
	add_child(can)
	_cans.append(can)
	_can_beacons.append(beacon)


## One horde nest, from primitives: a squat mound of dark flesh with lumps
## around it, a glowing core on top (it pulses, faster as the nest weakens,
## and flashes white when hit) and an HP bar that faces the camera (shown
## once damaged). Sized from IslandRun.nest_radius() and NEST_HEIGHT so the
## model matches what the bullets hit. A scorch replaces it when destroyed.
func _build_nest(at: Vector3) -> void:
	var r: float = IslandRun.nest_radius()
	var root := Node3D.new()
	root.name = "Nest%d" % _nests.size()
	root.position = _on_ground(at)
	var mound := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = r
	dome.height = IslandRun.NEST_HEIGHT * 1.1
	mound.mesh = dome
	mound.position.y = IslandRun.NEST_HEIGHT * 0.3
	mound.material_override = _mat(NEST_FLESH_COLOR)
	root.add_child(mound)
	for k in 5:
		var lump := MeshInstance3D.new()
		lump.mesh = _sphere(r * (0.32 + 0.06 * (k % 3)))
		var ang: float = k * TAU / 5.0 + 0.4
		lump.position = Vector3(cos(ang) * r * 0.85, r * 0.15, sin(ang) * r * 0.85)
		lump.material_override = _mat(NEST_FLESH_COLOR.lightened(0.08 * (k % 2)))
		root.add_child(lump)
	var core := MeshInstance3D.new()
	core.mesh = _sphere(0.42)
	core.position.y = IslandRun.NEST_HEIGHT - 0.4
	var cm := _mat(NEST_CORE_COLOR)
	cm.emission_enabled = true
	cm.emission = NEST_CORE_COLOR
	cm.emission_energy_multiplier = 2.0
	core.material_override = cm
	root.add_child(core)
	# HP bar: a dark back and a fill, both billboards (they face every
	# camera); the fill shrinks towards the middle as the HP drops.
	var bar := Node3D.new()
	bar.position.y = IslandRun.NEST_HEIGHT + 0.6
	bar.visible = false
	for k in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.6, 0.16) if k == 0 else Vector2(1.5, 0.1)
		q.mesh = qm
		var bm := _mat(Color(0.05, 0.05, 0.05, 0.75) if k == 0 else UiTheme.DANGER, true)
		bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bm.billboard_keep_scale = true
		bm.no_depth_test = true
		bm.render_priority = k + 1
		if k == 0:
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		q.material_override = bm
		bar.add_child(q)
		if k == 1:
			_nest_fills.append(q)
	root.add_child(bar)
	add_child(root)
	var scorch := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = r * 1.2
	sm.bottom_radius = r * 1.3
	sm.height = 0.06
	scorch.mesh = sm
	scorch.position = _on_ground(at) + Vector3(0, 0.03, 0)
	scorch.material_override = _mat(NEST_SCORCH_COLOR)
	scorch.visible = false
	add_child(scorch)
	_nests.append(root)
	_nest_cores.append(core)
	_nest_bars.append(bar)
	_nest_scorches.append(scorch)
	_nest_dead.append(false)


## One Intel Search spot: a crate (the CC0 IslandProps model, or a brown
## box without it), a thin beacon over it while it is unsearched, a ring of
## the search radius and a flat disc inside it that grows with the search.
## Searched empty: the crate greys out; searched with intel: a green disc.
func _build_search_spot(at: Vector3) -> void:
	var root := Node3D.new()
	root.name = "SearchSpot%d" % _search_spots.size()
	root.position = _on_ground(at)
	var crate: Node3D = IslandProps.create(&"crate", 0.7) if realistic_props else null
	if crate == null:
		var box := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.7, 0.7, 0.7)
		box.mesh = bm
		box.position.y = 0.35
		box.material_override = _mat(Color(0.45, 0.32, 0.2))
		crate = box
	root.add_child(crate)
	var beacon := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.04
	cm.bottom_radius = 0.12
	cm.height = 3.0
	beacon.mesh = cm
	beacon.position.y = 2.3
	beacon.material_override = _mat(INTEL_COLOR, true)
	root.add_child(beacon)
	var fill := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = IslandRun.search_radius()
	fm.bottom_radius = IslandRun.search_radius()
	fm.height = 0.03
	fill.mesh = fm
	fill.position.y = 0.04
	var fmat := _mat(Color(INTEL_COLOR, 0.35), true)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.material_override = fmat
	fill.scale = Vector3(0.001, 1, 0.001)
	root.add_child(fill)
	add_child(root)
	_search_spots.append(root)
	_search_beacons.append(beacon)
	_search_fills.append(fill)
	_search_crates.append(crate)
	_search_greyed.append(false)
	_search_rings.append(_ring(at, IslandRun.search_radius(), INTEL_COLOR))


## The Intel Search uplink: a mast with a dish and a blinking tip, a ring of
## the transmit radius and a disc that grows with the transmission (the ring
## and disc show in the transmit phase only).
func _build_uplink(at: Vector3) -> void:
	_uplink = Node3D.new()
	_uplink.name = "Uplink"
	_uplink.position = _on_ground(at)
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.06
	mm.bottom_radius = 0.22
	mm.height = 6.0
	mast.mesh = mm
	mast.position.y = 3.0
	mast.material_override = _mat(Color(0.6, 0.65, 0.7))
	_uplink.add_child(mast)
	var dish := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = 0.9
	dm.bottom_radius = 0.2
	dm.height = 0.35
	dish.mesh = dm
	dish.position = Vector3(0, 4.2, 0)
	dish.rotation_degrees = Vector3(-35, 0, 0)
	dish.material_override = _mat(Color(0.8, 0.82, 0.85))
	_uplink.add_child(dish)
	var tip := MeshInstance3D.new()
	tip.name = "Tip"
	tip.mesh = _sphere(0.18)
	tip.position.y = 6.1
	tip.material_override = _mat(INTEL_COLOR, true)
	_uplink.add_child(tip)
	_uplink_fill = MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = IslandRun.transmit_radius()
	fm.bottom_radius = IslandRun.transmit_radius()
	fm.height = 0.03
	_uplink_fill.mesh = fm
	_uplink_fill.position.y = 0.04
	var fmat := _mat(Color(INTEL_COLOR, 0.3), true)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_uplink_fill.material_override = fmat
	_uplink_fill.scale = Vector3(0.001, 1, 0.001)
	_uplink.add_child(_uplink_fill)
	add_child(_uplink)
	_uplink_ring = _ring(at, IslandRun.transmit_radius(), INTEL_COLOR)
	_uplink_ring.visible = false


## Greys every mesh of a searched-empty spot's crate (an overlay, so the
## model's own materials stay untouched).
func _grey_out(node: Node) -> void:
	if node is GeometryInstance3D:
		var m := _mat(Color(SEARCHED_COLOR, 0.65), true)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(node as GeometryInstance3D).material_overlay = m
	for child in node.get_children():
		_grey_out(child)


func _draw_intel_search() -> void:
	var searching: bool = run.objective == IslandRun.Objective.GENERATORS and run.intel_phase == IslandRun.INTEL_SEARCH
	for k in mini(_search_spots.size(), run.search_pos.size()):
		var state: int = run.search_state[k]
		var open: bool = state == IslandRun.SPOT_UNSEARCHED
		_search_beacons[k].visible = open and searching
		_search_rings[k].visible = open and searching
		var frac: float = clampf(run.search_progress[k] / IslandRun.search_seconds(), 0.0, 1.0)
		var fm: StandardMaterial3D = _search_fills[k].material_override
		if state == IslandRun.SPOT_FOUND:
			_search_fills[k].visible = true
			_search_fills[k].scale = Vector3.ONE
			fm.albedo_color = Color(UiTheme.SUCCESS, 0.35)
		elif state == IslandRun.SPOT_EMPTY:
			_search_fills[k].visible = true
			_search_fills[k].scale = Vector3.ONE
			fm.albedo_color = Color(SEARCHED_COLOR, 0.3)
			if not _search_greyed[k]:
				_search_greyed[k] = true
				_grey_out(_search_crates[k])
		else:
			_search_fills[k].visible = frac > 0.0 and searching
			_search_fills[k].scale = Vector3(maxf(0.001, frac), 1, maxf(0.001, frac))
			var inside: bool = run.player_pos.distance_to(run.search_pos[k]) <= IslandRun.search_radius()
			var rm: StandardMaterial3D = _search_rings[k].material_override
			rm.albedo_color = Color(0.3, 1.0, 0.5) if inside else INTEL_COLOR
	if _uplink == null:
		return
	var transmitting: bool = run.objective == IslandRun.Objective.GENERATORS and run.intel_phase == IslandRun.INTEL_TRANSMIT
	_uplink_ring.visible = transmitting
	_uplink_fill.visible = transmitting and run.transmit_progress > 0.0
	var t: float = clampf(run.transmit_progress / IslandRun.transmit_seconds(), 0.0, 1.0)
	_uplink_fill.scale = Vector3(maxf(0.001, t), 1, maxf(0.001, t))
	if transmitting:
		var inside_up: bool = run.player_pos.distance_to(run.uplink_pos) <= IslandRun.transmit_radius()
		var um: StandardMaterial3D = _uplink_ring.material_override
		um.albedo_color = Color(0.3, 1.0, 0.5) if inside_up else INTEL_COLOR
	# The tip blinks while the uplink waits or sends; it stays lit once done.
	var tip: MeshInstance3D = _uplink.get_node("Tip")
	tip.visible = not transmitting or fmod(Time.get_ticks_msec() * 0.001, 0.6 if run.transmit_progress > 0.0 else 1.2) < 0.4


## One Light the Signals beacon, from primitives: a stone plinth with an
## iron bowl of firewood (the spot where the fuel is poured and the player
## stands), a thin pale beacon over it while it waits, a ring of the
## lighting radius and a disc that grows with the lighting. Its fire (two
## emissive flames and an OmniLight3D without shadows) shows once lit. The
## lighthouse variant puts the fire at the top of the scene's lighthouse
## tower (or of a stone tower it builds) with a long turning beam.
func _build_signal(at: Vector3, lighthouse: bool) -> void:
	var root := Node3D.new()
	root.name = "Signal%d" % _signals.size()
	root.position = _on_ground(at)
	var plinth := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.5
	pm.bottom_radius = 0.65
	pm.height = 0.9
	plinth.mesh = pm
	plinth.position.y = 0.45
	plinth.material_override = _mat(Color(0.42, 0.4, 0.38))
	root.add_child(plinth)
	var bowl := MeshInstance3D.new()
	var bwm := CylinderMesh.new()
	bwm.top_radius = 0.85
	bwm.bottom_radius = 0.45
	bwm.height = 0.4
	bowl.mesh = bwm
	bowl.position.y = 1.1
	bowl.material_override = _mat(Color(0.18, 0.17, 0.17))
	root.add_child(bowl)
	var wood := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(0.9, 0.18, 0.25)
	wood.mesh = wm
	wood.position.y = 1.32
	wood.rotation_degrees.y = 35.0
	wood.material_override = _mat(Color(0.32, 0.22, 0.14))
	root.add_child(wood)
	var beacon := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.14
	cm.height = 3.5
	beacon.mesh = cm
	beacon.position.y = 3.3
	beacon.material_override = _mat(SIGNAL_COLOR, true)
	root.add_child(beacon)
	var fill := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = IslandRun.signal_radius()
	fm.bottom_radius = IslandRun.signal_radius()
	fm.height = 0.03
	fill.mesh = fm
	fill.position.y = 0.04
	var fmat := _mat(Color(SIGNAL_FIRE_COLOR, 0.3), true)
	fmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.material_override = fmat
	fill.scale = Vector3(0.001, 1, 0.001)
	root.add_child(fill)
	# The fire: in the bowl, or at the top of the lighthouse.
	var fire := Node3D.new()
	fire.name = "Fire"
	fire.position.y = 1.35
	var light_range: float = SIGNAL_LIGHT_RANGE
	if lighthouse:
		light_range = LIGHTHOUSE_LIGHT_RANGE
		var top: Vector3 = _lighthouse_top(at)
		if top == Vector3.INF:
			var tower := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(1.8, LIGHTHOUSE_TOWER_M, 1.8)
			tower.mesh = tm
			tower.position = Vector3(0, LIGHTHOUSE_TOWER_M * 0.5, -2.5)
			tower.material_override = _mat(Color(0.85, 0.84, 0.8))
			root.add_child(tower)
			top = root.position + Vector3(0, LIGHTHOUSE_TOWER_M + 0.4, -2.5)
		fire.position = top - root.position
	var flame := MeshInstance3D.new()
	var flm := CylinderMesh.new()
	flm.top_radius = 0.0
	flm.bottom_radius = 0.5 if not lighthouse else 0.8
	flm.height = 1.3 if not lighthouse else 1.6
	flame.mesh = flm
	flame.position.y = flm.height * 0.5
	flame.material_override = _mat(SIGNAL_FIRE_COLOR, true)
	fire.add_child(flame)
	var core := MeshInstance3D.new()
	core.mesh = _sphere(0.3 if not lighthouse else 0.5)
	core.position.y = 0.35
	core.material_override = _mat(SIGNAL_COLOR, true)
	fire.add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.3)
	light.omni_range = light_range
	light.light_energy = 2.5
	light.shadow_enabled = false
	light.position.y = 0.8
	fire.add_child(light)
	fire.visible = false
	root.add_child(fire)
	if lighthouse:
		# The beam: a long, thin, see-through bar turning around the lamp.
		_signal_beam = Node3D.new()
		_signal_beam.name = "Beam"
		_signal_beam.position.y = 0.8
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.9, 0.9, LIGHTHOUSE_BEAM_M)
		bar.mesh = bm
		bar.position.z = LIGHTHOUSE_BEAM_M * 0.5
		var beam_mat := _mat(Color(SIGNAL_COLOR, 0.22), true)
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		bar.material_override = beam_mat
		_signal_beam.add_child(bar)
		fire.add_child(_signal_beam)
	add_child(root)
	root.visible = false
	_signals.append(root)
	_signal_beacons.append(beacon)
	_signal_fills.append(fill)
	_signal_fires.append(fire)
	_signal_lights.append(light)
	var ring := _ring(at, IslandRun.signal_radius(), SIGNAL_COLOR)
	ring.visible = false
	_signal_rings.append(ring)


## The top of the hand-made scene's lighthouse tower (a Buildings/Lighthouse_*
## node within LIGHTHOUSE_SEARCH_M of `at`), 2 m under the top of its box
## (the lantern), in island space; Vector3.INF when there is none.
func _lighthouse_top(at: Vector3) -> Vector3:
	if _handmade == null or not _handmade.is_inside_tree():
		return Vector3.INF
	var buildings: Node = _handmade.get_node_or_null("Buildings")
	if buildings == null:
		return Vector3.INF
	var to_island: Transform3D = _handmade.global_transform.affine_inverse()
	for n in buildings.get_children():
		if not String(n.name).begins_with("Lighthouse"):
			continue
		var box := AABB()
		var any: bool = false
		for mi in [n] + n.find_children("*", "MeshInstance3D", true, false):
			if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
				var a: AABB = (to_island * (mi as MeshInstance3D).global_transform) * (mi as MeshInstance3D).mesh.get_aabb()
				box = a if not any else box.merge(a)
				any = true
		if not any:
			continue
		var c: Vector3 = box.get_center()
		if Vector2(c.x - at.x, c.z - at.z).length() <= LIGHTHOUSE_SEARCH_M:
			return Vector3(c.x, box.end.y - 2.0, c.z)
	return Vector3.INF


func _draw_signals() -> void:
	var active: bool = run.objective == IslandRun.Objective.GENERATORS
	var t: float = Time.get_ticks_msec() * 0.001
	for i in mini(_signals.size(), run.signal_pos.size()):
		var lit: bool = i < run.signal_index
		var next: bool = i == run.signal_index and active
		_signals[i].visible = lit or next
		_signal_fires[i].visible = lit
		_signal_beacons[i].visible = next
		_signal_rings[i].visible = next
		var frac: float = clampf(run.signal_progress / IslandRun.signal_seconds(), 0.0, 1.0) if next else 0.0
		_signal_fills[i].visible = next and frac > 0.0
		_signal_fills[i].scale = Vector3(maxf(0.001, frac), 1, maxf(0.001, frac))
		if next:
			# The beacon turns warm once the fuel is in; the ring green inside.
			var bm: StandardMaterial3D = _signal_beacons[i].material_override
			bm.albedo_color = SIGNAL_FIRE_COLOR if run.signal_fuelled() else SIGNAL_COLOR
			var inside: bool = _flat(run.player_pos).distance_to(_flat(run.signal_pos[i])) <= IslandRun.signal_radius()
			var rm: StandardMaterial3D = _signal_rings[i].material_override
			rm.albedo_color = Color(0.3, 1.0, 0.5) if inside and run.signal_fuelled() else SIGNAL_COLOR
		if lit:
			# A cheap flicker: the flames breathe, the light wavers.
			var fl: float = sin(t * 9.0 + i * 1.7) * 0.5 + sin(t * 23.0 + i) * 0.5
			_signal_fires[i].scale = Vector3(1.0 - 0.05 * fl, 1.0 + 0.12 * fl, 1.0 - 0.05 * fl)
			_signal_lights[i].light_energy = 2.5 + 0.5 * fl
	if _signal_beam != null:
		_signal_beam.rotation.y = fmod(t * TAU * LIGHTHOUSE_BEAM_SPEED, TAU)


## Sabotage, from primitives. The power switch: a grey cabinet with a lever
## and a lamp (green while the line is live, red once cut), a cyan beacon,
## the ring of power_radius() and a disc that grows with the cut. Each
## machine: a motor housing with a drive drum and an amber lamp with an
## OmniLight3D (the machine "running"; both die with the power), a red
## beacon, the ring of charge_radius(), a disc that grows with the planting
## and the charge block (shown once planted, blinking during the fuse).
## During the fuse a red ring shows each charge's blast radius; after the
## blast the machines are gone and a scorch stays.
func _build_sabotage() -> void:
	_power_switch = Node3D.new()
	_power_switch.name = "PowerSwitch"
	_power_switch.position = _on_ground(run.power_pos)
	var cab := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(1.2, 1.8, 0.6)
	cab.mesh = cm
	cab.position = Vector3(0, 0.9, -1.2)
	cab.material_override = _mat(Color(0.5, 0.52, 0.5))
	_power_switch.add_child(cab)
	var lever := MeshInstance3D.new()
	var lm := BoxMesh.new()
	lm.size = Vector3(0.12, 0.6, 0.12)
	lever.mesh = lm
	lever.name = "Lever"
	lever.position = Vector3(0.35, 1.1, -0.85)
	lever.rotation_degrees.x = -35.0
	lever.material_override = _mat(Color(0.75, 0.15, 0.1))
	_power_switch.add_child(lever)
	_power_lamp = MeshInstance3D.new()
	_power_lamp.mesh = _sphere(0.14)
	_power_lamp.position = Vector3(-0.3, 1.55, -0.88)
	_power_lamp.material_override = _mat(Color(0.3, 1.0, 0.4), true)
	_power_switch.add_child(_power_lamp)
	_power_beacon = _beacon_mesh(POWER_COLOR)
	_power_switch.add_child(_power_beacon)
	_power_fill = _fill_disc(IslandRun.power_radius(), POWER_COLOR)
	_power_switch.add_child(_power_fill)
	add_child(_power_switch)
	_power_ring = _ring(run.power_pos, IslandRun.power_radius(), POWER_COLOR)
	for k in run.charge_pos.size():
		var at: Vector3 = run.charge_pos[k]
		var root := Node3D.new()
		root.name = "Machine%d" % k
		root.position = _on_ground(at)
		var housing := MeshInstance3D.new()
		var hm := BoxMesh.new()
		hm.size = Vector3(2.2, 1.4, 1.4)
		housing.mesh = hm
		housing.position = Vector3(0, 0.7, -1.6)
		housing.material_override = _mat(Color(0.32, 0.36, 0.3))
		root.add_child(housing)
		var drum := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = 0.55
		dm.bottom_radius = 0.55
		dm.height = 1.6
		drum.mesh = dm
		drum.position = Vector3(0, 1.0, -2.6)
		drum.rotation_degrees.z = 90.0
		drum.material_override = _mat(Color(0.22, 0.2, 0.19))
		root.add_child(drum)
		var lamp := MeshInstance3D.new()
		lamp.mesh = _sphere(0.18)
		lamp.position = Vector3(0.8, 1.55, -1.6)
		lamp.material_override = _mat(MACHINE_LAMP_COLOR, true)
		root.add_child(lamp)
		var light := OmniLight3D.new()
		light.light_color = MACHINE_LAMP_COLOR
		light.omni_range = MACHINE_LIGHT_RANGE
		light.light_energy = 1.6
		light.shadow_enabled = false
		light.position = Vector3(0.8, 2.0, -1.6)
		root.add_child(light)
		var charge := MeshInstance3D.new()
		var chm := BoxMesh.new()
		chm.size = Vector3(0.5, 0.35, 0.3)
		charge.mesh = chm
		charge.position = Vector3(-0.5, 1.55, -1.6)
		charge.material_override = _mat(CHARGE_COLOR, true)
		charge.visible = false
		root.add_child(charge)
		var beacon := _beacon_mesh(CHARGE_COLOR)
		root.add_child(beacon)
		var fill := _fill_disc(IslandRun.charge_radius(), CHARGE_COLOR)
		root.add_child(fill)
		add_child(root)
		_machines.append(root)
		_machine_lamps.append(lamp)
		_machine_lights.append(light)
		_charges.append(charge)
		_charge_beacons.append(beacon)
		_charge_fills.append(fill)
		_charge_rings.append(_ring(at, IslandRun.charge_radius(), CHARGE_COLOR))
		var blast := _ring(at, IslandRun.blast_radius(), CHARGE_COLOR)
		blast.visible = false
		_blast_rings.append(blast)
		var scorch := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 3.0
		sm.bottom_radius = 3.0
		sm.height = 0.02
		scorch.mesh = sm
		scorch.position = _on_ground(at) + Vector3(0, 0.03, -1.6)
		scorch.material_override = _mat(NEST_SCORCH_COLOR)
		scorch.visible = false
		add_child(scorch)
		_machine_scorches.append(scorch)


## A thin beacon over an objective (power switch, machines).
func _beacon_mesh(color: Color) -> MeshInstance3D:
	var beacon := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.05
	bm.bottom_radius = 0.14
	bm.height = 3.5
	beacon.mesh = bm
	beacon.position.y = 3.3
	beacon.material_override = _mat(color, true)
	return beacon


## A flat see-through disc that grows (its scale) with an objective's progress.
func _fill_disc(radius: float, color: Color) -> MeshInstance3D:
	var fill := MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = radius
	fm.bottom_radius = radius
	fm.height = 0.03
	fill.mesh = fm
	fill.position.y = 0.04
	var mat := _mat(Color(color, 0.3), true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill.material_override = mat
	fill.scale = Vector3(0.001, 1, 0.001)
	fill.visible = false
	return fill


func _draw_sabotage() -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	var active: bool = run.objective == IslandRun.Objective.GENERATORS
	var cut: bool = run.power_cut()
	var blown: bool = run.sabotage_phase == IslandRun.SAB_BLOWN
	var fuse: bool = run.sabotage_phase == IslandRun.SAB_FUSE
	if cut and not _sabotage_seen_cut:
		# The line dies: the switch lamp turns red, the machines go dark.
		_sabotage_seen_cut = true
		(_power_lamp.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.2, 0.15)
		(_power_switch.get_node("Lever") as Node3D).rotation_degrees.x = 35.0
		for k in _machines.size():
			_machine_lights[k].visible = false
			(_machine_lamps[k].material_override as StandardMaterial3D).albedo_color = Color(0.2, 0.17, 0.12)
	if blown and not _sabotage_seen_blast:
		_sabotage_seen_blast = true
		for k in _machines.size():
			var at: Vector3 = _on_ground(run.charge_pos[k]) + Vector3(0, 1.0, -1.6)
			for j in 30:
				var ang: float = j * TAU / 30.0
				var v := Vector3(cos(ang) * randf_range(3.0, 8.0), randf_range(4.0, 10.0), sin(ang) * randf_range(3.0, 8.0))
				_add_debris(at, v, Color(0.3, 0.32, 0.28) if j % 3 != 0 else CHARGE_COLOR, 1.6)
			if fx != null:
				fx.emit(&"dust", at)
			_machines[k].visible = false
			_machine_scorches[k].visible = true
		var near: bool = false
		for c in run.charge_pos:
			near = near or _flat(run.player_pos).distance_to(_flat(c)) <= BLAST_SHAKE_RANGE
		if near:
			_trauma = 1.0
	# The switch: its beacon, ring and disc until the power is cut.
	var on_switch: bool = active and not cut
	_power_beacon.visible = on_switch
	_power_ring.visible = on_switch
	var pf: float = clampf(run.power_progress / IslandRun.power_seconds(), 0.0, 1.0)
	_power_fill.visible = on_switch and pf > 0.0
	_power_fill.scale = Vector3(maxf(0.001, pf), 1, maxf(0.001, pf))
	if on_switch:
		var inside: bool = _flat(run.player_pos).distance_to(_flat(run.power_pos)) <= IslandRun.power_radius()
		(_power_ring.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.5) if inside else POWER_COLOR
	for k in mini(_machines.size(), run.charge_pos.size()):
		var planted: bool = run.charge_planted[k]
		var open: bool = active and cut and not planted
		_charge_beacons[k].visible = active and not planted
		(_charge_beacons[k].material_override as StandardMaterial3D).albedo_color = CHARGE_COLOR if cut else CHARGE_COLOR.darkened(0.5)
		_charge_rings[k].visible = open
		var f: float = clampf(run.charge_progress[k] / IslandRun.charge_seconds(), 0.0, 1.0)
		_charge_fills[k].visible = open and f > 0.0
		_charge_fills[k].scale = Vector3(maxf(0.001, f), 1, maxf(0.001, f))
		if open:
			var inside: bool = _flat(run.player_pos).distance_to(_flat(run.charge_pos[k])) <= IslandRun.charge_radius()
			(_charge_rings[k].material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.5) if inside else CHARGE_COLOR
		_charges[k].visible = planted and not blown
		if planted and fuse:
			# Blinks faster as the fuse runs out.
			var rate: float = lerpf(1.0, 6.0, 1.0 - run.fuse_left / IslandRun.fuse_seconds())
			_charges[k].visible = fmod(t * rate, 1.0) < 0.6
		_blast_rings[k].visible = fuse


## Escort: the cart (EscortModel, or the survivor with an EscortSurvivor
## marker), an HP bar and a status label over it (billboards: they face
## every camera), the ring of escort_radius() that follows it, flat amber
## arrows on the ground along the route ahead (one MultiMesh, cheap: a
## 300 m route is 100 triangles) and a stop post (a red octagon on a pole)
## beside the road at every stop.
func _build_escort() -> void:
	_escort = EscortModel.survivor_model() if run.escort_survivor else EscortModel.cart()
	add_child(_escort)
	_escort_yaw = atan2(-run.escort_dir.x, -run.escort_dir.z)
	var top: float = 2.2 if run.escort_survivor else 1.6
	_escort_bar = Node3D.new()
	_escort_bar.position.y = top
	for k in 2:
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(1.6, 0.16) if k == 0 else Vector2(1.5, 0.1)
		q.mesh = qm
		var bm := _mat(Color(0.05, 0.05, 0.05, 0.75) if k == 0 else UiTheme.SUCCESS, true)
		bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		bm.billboard_keep_scale = true
		bm.no_depth_test = true
		bm.render_priority = k + 1
		if k == 0:
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		q.material_override = bm
		_escort_bar.add_child(q)
		if k == 1:
			_escort_fill = q
	_escort.add_child(_escort_bar)
	_escort_label = Label3D.new()
	_escort_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_escort_label.no_depth_test = true
	_escort_label.fixed_size = false
	_escort_label.pixel_size = 0.008
	_escort_label.font_size = 40
	_escort_label.outline_size = 10
	_escort_label.modulate = ESCORT_COLOR
	_escort_label.position.y = top + 0.45
	_escort.add_child(_escort_label)
	_escort_ring = _ring(run.escort_pos, IslandRun.escort_radius(), ESCORT_COLOR)
	# Route arrows: flat triangles pointing along the route, from the far
	# end back to the start (index 0 = nearest the delivery point).
	var arrow := ArrayMesh.new()
	var verts := PackedVector3Array([Vector3(0, 0, -0.38), Vector3(0.32, 0, 0.26), Vector3(-0.32, 0, 0.26)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	arrow.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_setup_multimesh(_escort_arrows, arrow, false, ESCORT_COLOR, true)
	var inst: MultiMeshInstance3D = get_child(get_child_count() - 1)
	inst.name = "EscortRoute"
	(inst.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	var n: int = floori(run.escort_length / ESCORT_ARROW_STEP)
	_escort_arrows.instance_count = n
	for i in n:
		var d: float = run.escort_length - (i + 0.5) * ESCORT_ARROW_STEP
		var p: Vector3 = _on_ground(IslandMap.point_along(run.escort_path, d)) + Vector3(0, 0.08, 0)
		var ahead: Vector3 = _on_ground(IslandMap.point_along(run.escort_path, minf(run.escort_length, d + 0.6))) + Vector3(0, 0.08, 0)
		var look: Vector3 = ahead - p
		var b := Basis.IDENTITY
		if Vector2(look.x, look.z).length() > 0.05:
			b = Basis.looking_at(look, Vector3.UP)
		_escort_arrows.set_instance_transform(i, Transform3D(b, p))
	_escort_arrows.visible_instance_count = n
	for k in run.escort_stop_at.size():
		var at: Vector3 = run.stop_pos(k)
		var dir: Vector3 = IslandMap.point_along(run.escort_path, minf(run.escort_length, run.escort_stop_at[k] + 0.5)) - at
		var side := Vector3(-dir.z, 0, dir.x).normalized() if dir.length() > 0.01 else Vector3.RIGHT
		var post := Node3D.new()
		post.name = "EscortStop%d" % k
		post.position = _on_ground(at + side * 1.6)
		var pole := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.04
		pm.bottom_radius = 0.05
		pm.height = 2.2
		pole.mesh = pm
		pole.position.y = 1.1
		pole.material_override = EscortModel.material("steel")
		post.add_child(pole)
		var sign_plate := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.38
		sm.bottom_radius = 0.38
		sm.height = 0.04
		sm.radial_segments = 8
		sign_plate.mesh = sm
		sign_plate.position.y = 2.25
		sign_plate.rotation_degrees.x = 90.0
		sign_plate.material_override = _mat(ESCORT_STOP_COLOR)
		post.add_child(sign_plate)
		post.rotation.y = atan2(-dir.x, -dir.z) if dir.length() > 0.01 else 0.0
		add_child(post)
		_escort_stop_posts.append(post)


func _draw_escort() -> void:
	var dt: float = get_process_delta_time()
	var t: float = Time.get_ticks_msec() * 0.001
	var active: bool = run.objective == IslandRun.Objective.GENERATORS and not run.escort_delivered
	var p: Vector3 = _on_ground(run.escort_pos)
	_escort_yaw = lerp_angle(_escort_yaw, atan2(-run.escort_dir.x, -run.escort_dir.z), minf(1.0, dt * 6.0))
	var pitch: float = 0.0
	if not run.escort_survivor:
		# The cart follows the slope: nose up going uphill.
		var front: float = run.map.ground_y(run.escort_pos + run.escort_dir * 0.6)
		var back: float = run.map.ground_y(run.escort_pos - run.escort_dir * 0.6)
		pitch = atan2(front - back, 1.2)
	_escort.transform = Transform3D(Basis(Vector3.UP, _escort_yaw) * Basis(Vector3.RIGHT, pitch), p)
	_escort.set_motion(run.escort_dist, active and run.escort_status == IslandRun.ESC_MOVING, run.escort_broken, t)
	var near: bool = _flat(run.player_pos).distance_to(_flat(run.escort_pos)) <= ESCORT_BAR_RANGE
	_escort_bar.visible = active and near
	if run.escort_broken:
		var r: float = clampf(run.repair_progress / IslandRun.repair_seconds(), 0.0, 1.0)
		_escort_fill.scale = Vector3(maxf(0.001, r), 1, 1)
		(_escort_fill.material_override as StandardMaterial3D).albedo_color = ESCORT_COLOR
	else:
		var frac: float = clampf(run.escort_hp / IslandRun.escort_max_hp(), 0.0, 1.0)
		_escort_fill.scale = Vector3(maxf(0.001, frac), 1, 1)
		(_escort_fill.material_override as StandardMaterial3D).albedo_color = \
			UiTheme.SUCCESS if frac > 0.5 else (ESCORT_COLOR if frac > 0.25 else UiTheme.DANGER)
	var text: String = ""
	if run.escort_broken:
		text = "%s %d%%" % ["PATCH UP" if run.escort_survivor else "REPAIR", int(100.0 * run.repair_progress / IslandRun.repair_seconds())]
	elif run.escort_status == IslandRun.ESC_STOPPED:
		text = "STOP · %d s" % ceili(run.stop_left)
	elif run.escort_status == IslandRun.ESC_BLOCKED:
		text = "BLOCKED"
	elif run.escort_status == IslandRun.ESC_WAITING:
		text = "WAITING"
	_escort_label.text = text
	_escort_label.visible = active and near and text != ""
	_escort_label.modulate = UiTheme.DANGER if run.escort_broken or run.escort_status == IslandRun.ESC_BLOCKED else ESCORT_COLOR
	_escort_ring.visible = active
	if active:
		_escort_ring.position = p + Vector3(0, 0.05, 0)
		var inside: bool = _flat(run.player_pos).distance_to(_flat(run.escort_pos)) <= IslandRun.escort_radius()
		(_escort_ring.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.5) if inside else ESCORT_COLOR
	# The arrows the cart has passed (and all of them once delivered) go.
	var n: int = _escort_arrows.instance_count
	var ahead: int = clampi(ceili((run.escort_length - run.escort_dist - 1.5) / ESCORT_ARROW_STEP - 0.5), 0, n)
	_escort_arrows.visible_instance_count = ahead if active else 0
	for k in _escort_stop_posts.size():
		_escort_stop_posts[k].visible = active and k >= run.stop_index
		if k == run.stop_index and run.at_stop():
			# The stop being held pulses.
			_escort_stop_posts[k].scale = Vector3.ONE * (1.0 + 0.12 * absf(sin(t * 4.0)))
		else:
			_escort_stop_posts[k].scale = Vector3.ONE


## Flat (x, z) of a point, for distances on the ground.
func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x, p.z)


## The fuel cans of the carry system, drawn each frame. Fuel Run: every
## can; delivered ones wait in a row beside the delivery point. Light the
## Signals: only the next signal's can; once poured in it is gone.
func _draw_cans() -> void:
	var signals: bool = run.mission == &"signals"
	for c in mini(_cans.size(), run.cargo_pos.size()):
		var state: int = run.cargo_state[c]
		var shown: bool = not signals or (run.can_available(c) and state != IslandRun.CAN_DELIVERED)
		_cans[c].visible = shown
		_can_beacons[c].visible = shown and state == IslandRun.CAN_WAITING
		if state == IslandRun.CAN_CARRIED:
			# In the right hand, turning with the soldier (all camera modes:
			# in first person it shows at the hip when looking down).
			_cans[c].position = _player.position + _player.basis.orthonormalized() * CARRY_OFFSET
			_cans[c].basis = _player.basis.orthonormalized()
		elif state == IslandRun.CAN_DELIVERED:
			# Delivered cans wait in a row beside the delivery point.
			_cans[c].position = _on_ground(run.delivery_point() + Vector3(-1.0 + 0.5 * c, 0, 1.5))
		else:
			_cans[c].position = _on_ground(run.cargo_pos[c])


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
			hud.request_continue()
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
	elif event.is_action_pressed(&"interact"):
		run.interact()  # Fuel Run: pick up / put down a can
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
		for i in run.weapons.size():
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
		run.step(delta, Vector2.ZERO, Vector3(1, 0, 0), false)
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
		# This frame's yaw / pitch (crosshair_ray does not read the camera,
		# which is only placed in _process, after the simulation step).
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
		# First / third person: where the crosshair meets the ground (a spot
		# near the feet stays near the feet). Fixed camera without a mouse
		# aim (gamepad): 8 m ahead.
		var throw: Vector3 = grenade_throw() if _free_look() else aim
		if not _free_look() and throw.length() <= 1.0:
			throw = run.facing * 8.0
		run.use_ability(throw)
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
	if profile != null and _camera != null:
		var fov: float = _camera_fov(camera_mode == Profile.CameraMode.FIRST_PERSON)
		if _camera.fov != fov:
			_camera.fov = fov  # field of view changed in Settings (pause)
	_update_mouse_mode()
	_draw_player_and_camera()
	_draw_enemies()
	_draw_orbs()
	_draw_grenades()
	_draw_clouds()
	_draw_power_up()
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
		sfx.play(wid, -10.0 if wid == &"marksman" else -6.0, 0.06, 40)
	# Events announced on the radio also get a sound.
	for key in run.radio:
		match key:
			&"cache":
				sfx.play(&"cache", -6.0, 0.05)
			&"survivor_found":
				sfx.play(&"survivor", -6.0, 0.0)
			&"intel_found", &"intel_transmit", &"signal_lit", &"signals_done", &"lighthouse_lit", &"charge_planted", &"charges_set":
				sfx.play(&"cache", -6.0, 0.05)
			&"power_cut":
				sfx.play(&"generator", -4.0, 0.0)  # the line powering down
			&"escort_stop", &"escort_stop_survivor":
				sfx.play(&"generator", -6.0, 0.0)  # the cart grinds to a halt
			&"escort_broken", &"escort_broken_survivor":
				sfx.play(&"slam_hit", -8.0, 0.05)
			&"escort_done", &"escort_done_survivor":
				sfx.play(&"cache", -6.0, 0.05)
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
## through the screen centre. Computed from the current yaw / pitch and the
## eye (first person) or the shoulder camera (third person: pivot + arm, as
## _update_third_person_camera places it), never from the camera node, whose
## transform is last frame's until _process runs.
func crosshair_ray() -> Array[Vector3]:
	if camera_mode == Profile.CameraMode.FIRST_PERSON:
		return [_view_pos() + Vector3(0, fp_eye_height, 0), _look_dir()]
	var rig: Array = _tp_rig()
	return [rig[0] + _tp_back() * float(rig[1]), _look_dir()]


## Shortest grenade throw (metres) when the crosshair is on the ground at
## the soldier's feet: it lands just in front instead of on his boots.
const GRENADE_MIN_THROW: float = 1.5


## Grenade aim for the first / third-person cameras, as a flat vector from
## the player: where the crosshair ray meets the ground (at least
## GRENADE_MIN_THROW ahead; a spot right at the feet stays close), or 12 m
## along the look direction when the ray meets no ground in reach (sky).
func grenade_throw() -> Vector3:
	var hit: Variant = _crosshair_ground_hit()
	var fwd: Vector3 = _tp_forward()
	if hit == null:
		return fwd * 12.0
	var v: Vector3 = hit
	if v.length() >= GRENADE_MIN_THROW:
		return v
	# Close hit: keep its side when it is ahead, else just ahead.
	var dir: Vector3 = v.normalized() if v.dot(fwd) > 0.05 * v.length() and v.length() > 0.05 else fwd
	return dir * GRENADE_MIN_THROW


## Where the crosshair ray meets the ground, as a flat vector from the
## player; null when it meets none within reach (sky, or too far).
func _crosshair_ground_hit() -> Variant:
	var ray: Array[Vector3] = crosshair_ray()
	var d: float = 0.0
	while d <= GameData.GRENADE_RANGE + tp_distance + 2.0:
		var p: Vector3 = ray[0] + ray[1] * d
		if p.y <= run.map.ground_y(p):
			return Vector3(p.x - run.player_pos.x, 0, p.z - run.player_pos.z)
		d += 0.25
	return null


## Field of view in degrees for the camera mode (Settings > Graphics sets it).
func _camera_fov(first: bool) -> float:
	if profile == null:
		return fp_fov if first else camera_fov
	return Profile.field_of_view(profile.fov, first)


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
	_camera.fov = _camera_fov(first)
	_camera.near = 0.03 if first else 0.05  # the gun sits close to the eye
	(_player as SoldierModel).set_shadow_only(first)
	_view_model.visible = first
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
	const REACH: float = 0.95  # a bit more than the barrel's reach from the eye (~0.85 m)
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
	# No follow damping: the camera the player sees must be the one the
	# simulation aims from (crosshair_ray, same pivot + arm, this frame).
	# With 0.08 s of damping the view lagged behind while strafing and the
	# crosshair sat on one enemy while the shot went to another.
	_pcam.set("follow_damping", false)
	_pcam.set("tween_on_load", false)  # no 1 s glide either (on load or on V)
	_pcam.set("tween_duration", 0.0)
	_pcam.set("priority", 10)
	add_child(_pcam)
	_set_pcam_active(camera_mode == Profile.CameraMode.THIRD_PERSON)


func _set_pcam_active(on: bool) -> void:
	if _pcam_host != null:
		_pcam_host.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


## Space kept between the shoulder camera (and its pivot) and the ground
## under it: with the near plane at 0.05 m and a 60 degree view, 0.5 m keeps
## a slope from filling the screen or showing its underside.
const TP_GROUND_CLEARANCE: float = 0.5
## Step when walking the shoulder offset and the arm looking for ground.
const TP_PROBE_STEP: float = 0.25


## The shoulder camera as [pivot, arm length]: the camera sits at
## pivot + _tp_back() * arm. One function feeds both the camera the player
## sees and the crosshair ray, so they never disagree. In order:
##   1. pivot: chest + shoulder offset, shorter when a building or a slope is
##      beside the soldier, never under the ground;
##   2. arm: tp_distance, pulled in when a building or the ground is in the
##      way (the spring arm has no physics);
##   3. if the pulled-in camera is still too low (a steep slope right
##      behind), pivot and camera rise together: the view direction stays
##      the same, so the crosshair keeps aiming where the player looks.
func _tp_rig() -> Array:
	var pivot: Vector3 = _tp_pivot_pos()
	var back: Vector3 = _tp_back()
	var arm: float = _tp_arm(pivot, back)
	var cam: Vector3 = pivot + back * arm
	var lift: float = maxf(0.0, _camera_floor(cam) - cam.y)
	return [pivot + Vector3.UP * lift, arm]


## The third-person pivot: chest height, tp_shoulder to the right (less when
## a building or rising ground is right beside the soldier, so the view
## stays outside it), and never closer than TP_GROUND_CLEARANCE to the ground.
func _tp_pivot_pos() -> Vector3:
	var chest: Vector3 = _view_pos() + Vector3(0, tp_height, 0)
	var right: Vector3 = _tp_forward().cross(Vector3.UP).normalized()
	var side: float = tp_shoulder
	for box in _building_boxes:
		var hit: Variant = _segment_hits_box(chest, chest + right * tp_shoulder, box)
		if hit != null:
			side = minf(side, maxf(0.0, float(hit) - 0.3))
	var d: float = TP_PROBE_STEP
	while d <= side:
		var p: Vector3 = chest + right * d
		if p.y < ground_height(p) + TP_GROUND_CLEARANCE:
			side = maxf(0.0, d - TP_PROBE_STEP)
			break
		d += TP_PROBE_STEP
	var pivot: Vector3 = chest + right * side
	pivot.y = maxf(pivot.y, ground_height(pivot) + TP_GROUND_CLEARANCE)
	return pivot


## From the pivot back to the third-person camera (the opposite of _look_dir).
func _tp_back() -> Vector3:
	return (-_tp_forward() * cos(_tp_pitch) + Vector3.UP * sin(_tp_pitch)).normalized()


## Arm length from the pivot to the camera: tp_distance, shorter when a
## building or a hill is in the way (the spring arm has no physics).
func _tp_arm(pivot: Vector3, back: Vector3) -> float:
	var dist: float = tp_distance
	for box in _building_boxes:
		var hit: Variant = _segment_hits_box(pivot, pivot + back * tp_distance, box)
		if hit != null:
			dist = minf(dist, maxf(0.8, float(hit) - 0.3))
	return _terrain_limit(pivot, back, dist)


func _update_third_person_camera(jitter: Vector3) -> void:
	if _pcam != null and is_instance_valid(_pcam) and bool(_pcam.get("_has_follow_spring_arm")):
		var rig: Array = _tp_rig()
		_tp_pivot.global_position = rig[0]
		_pcam.call("set_third_person_rotation", Vector3(-_tp_pitch, _tp_yaw, 0))
		_pcam.call("set_spring_length", float(rig[1]))
		# Shake through the camera's offsets (Phantom Camera owns its transform).
		_camera.h_offset = jitter.x
		_camera.v_offset = jitter.y
		return
	_update_manual_third_person_camera(jitter)


## Fallback without Phantom Camera (same framing, no damping).
func _update_manual_third_person_camera(jitter: Vector3) -> void:
	var rig: Array = _tp_rig()
	var pivot: Vector3 = rig[0]
	_camera.position = pivot + _tp_back() * float(rig[1]) + jitter
	_camera.look_at(pivot + jitter * 0.5)


## Shortens the camera arm so the camera never ends up inside a hill: walks
## out from the pivot and stops one step before the first point closer than
## TP_GROUND_CLEARANCE to the ground (the arm's end included).
func _terrain_limit(pivot: Vector3, back: Vector3, dist: float) -> float:
	var d: float = TP_PROBE_STEP
	while d < dist + TP_PROBE_STEP:
		var at: float = minf(d, dist)
		var p: Vector3 = pivot + back * at
		if p.y < ground_height(p) + TP_GROUND_CLEARANCE:
			return maxf(0.8, at - TP_PROBE_STEP)
		d += TP_PROBE_STEP
	return dist


## Lowest height the camera may have at `cam`: the ground under it and a
## little around it (the near plane is a small square, not a point), plus
## TP_GROUND_CLEARANCE.
func _camera_floor(cam: Vector3) -> float:
	var top: float = ground_height(cam)
	for offset: Vector3 in [Vector3(0.3, 0, 0), Vector3(-0.3, 0, 0), Vector3(0, 0, 0.3), Vector3(0, 0, -0.3)]:
		top = maxf(top, ground_height(cam + offset))
	return top + TP_GROUND_CLEARANCE


## Ground height at a world point as drawn: the island map's height, or
## Terrain3D's own height when it is higher (hand-made islands average
## their vertices into cells, which cuts the top off ridges and cliff edges).
func ground_height(p: Vector3) -> float:
	var g: float = run.map.ground_y(p)
	if _terrain_data == null and _terrain != null:
		_terrain_data = _terrain.get("data")
	if _terrain_data != null:
		var h: float = _terrain_data.call("get_height", p)
		if not is_nan(h):
			g = maxf(g, h)
	return g


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
	var soldier := _player as SoldierModel
	var equipped_id: StringName = run.weapons[run.weapon_index].id
	if soldier.weapon_id != equipped_id:
		_muzzle.reparent(soldier, false)
		soldier.set_weapon(equipped_id)
		_muzzle.reparent(soldier.muzzle, false)
	var delta: float = get_process_delta_time()
	if run.noclip:
		var climb: float = float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
		var speed: float = FLY_SPEED * (3.0 if Input.is_action_pressed(&"sprint") else 1.0)
		_fly = clampf(_fly + climb * speed * delta, 0.0, FLY_MAX)
	else:
		_fly = move_toward(_fly, 0.0, FLY_SPEED * 2.0 * delta)
	var moved: float = _player.position.distance_to(_view_pos())
	_walk_speed = lerpf(_walk_speed, clampf(moved / maxf(delta, 0.001) / 6.0, 0.0, 1.0), 0.2)
	var animation_delta: float = 0.0 if paused or not run.card_choices.is_empty() or _hitstop > 0.0 or run.is_over() else delta
	soldier.carrying = run.is_carrying()
	soldier.aim_pitch = -_tp_pitch if camera_mode != Profile.CameraMode.FIXED else 0.0
	soldier.grounded = not run.noclip and _fly < 0.01
	soldier.animate(_walk_speed, Time.get_ticks_msec() / 1000.0, run.sprinting or run.dash_time > 0.0, animation_delta)
	_player.position = _view_pos()
	_player.basis = Basis.looking_at(run.facing, Vector3.UP)
	# Stretch along the dash direction while breaking through.
	if run.dash_time > 0.0:
		_player.basis = Basis.looking_at(run.dash_dir, Vector3.UP)
		if not soldier.uses_skeleton():
			_player.basis = _player.basis.scaled(Vector3(0.8, 0.9, 1.6))
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
	# Muzzle flash: a short-lived light at the gun.
	_muzzle.light_energy = maxf(0.0, _muzzle.light_energy - delta * 40.0)


func _draw_enemies() -> void:
	var h: Horde = run.horde
	var now: float = Time.get_ticks_msec() * 0.001
	_enemy_mm.instance_count = h.count
	_head_mm.instance_count = h.count
	_arm_mm.instance_count = h.count * 2
	_zombies.draw(h, run.map, now, 0.0 if paused else get_process_delta_time())
	for i in h.count:
		if _zombies.handles(h.kinds[i]):  # drawn by ZombieHordeView instead
			_enemy_mm.set_instance_transform(i, ZombieHordeView.HIDDEN)
			_head_mm.set_instance_transform(i, ZombieHordeView.HIDDEN)
			_arm_mm.set_instance_transform(i * 2, ZombieHordeView.HIDDEN)
			_arm_mm.set_instance_transform(i * 2 + 1, ZombieHordeView.HIDDEN)
			continue
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
		if h.stun[i] > 0.0 and h.freeze_time[i] <= 0.0:
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
		if h.burn_time[i] > 0.0:
			c = c.lerp(Color(1.0, 0.35, 0.08), 0.65)
		if h.poison_time[i] > 0.0:
			c = c.lerp(Color(0.65, 0.9, 0.16), 0.65)
		if h.cold_stacks[i] > 0:
			c = c.lerp(Color(0.25, 0.7, 1.0), 0.5)
		if h.freeze_time[i] > 0.0:
			c = Color(0.55, 0.92, 1.0)
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
	var radius: float = run.grenade_radius()
	for i in n:
		var p: Vector3 = _on_ground(run.grenades[i])
		# Small arc: the grenade drops onto the target as the fuse runs out.
		var t: float = 1.0 - run.grenade_fuses[i] / GameData.GRENADE_FUSE
		var height: float = 0.25 + 2.0 * (1.0 - t) * t * 4.0 * 0.5
		_grenade_mm.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, height, 0)))
		_grenade_ring_mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * radius), p + Vector3(0, 0.06, 0)))


## One batched mesh for all poison clouds; no per-cloud nodes or physics.
func _draw_clouds() -> void:
	var count: int = run.toxic_clouds.size()
	if _cloud_mm.mesh == null:
		if count == 0:
			return
		var disk := CylinderMesh.new()
		disk.top_radius = 2.0
		disk.bottom_radius = 2.0
		disk.height = 0.08
		_setup_multimesh(_cloud_mm, disk, true, Color(0.45, 0.85, 0.12), true)
	_cloud_mm.instance_count = count
	for i in count:
		_cloud_mm.set_instance_transform(i, Transform3D(Basis(), _on_ground(run.toxic_clouds[i]) + Vector3(0, 0.08, 0)))
		var fade: float = minf(1.0, run.toxic_cloud_times[i])
		_cloud_mm.set_instance_color(i, Color(0.6, 0.9, 0.3).lerp(Color(0.2, 0.4, 0.08), 1.0 - fade))


## Just one pooled icon; no per-kill nodes. Height follows terrain/bridges.
func _draw_power_up() -> void:
	var p: PowerUps = run.power_ups
	if _power_up_visual == null:
		if p.ground_kind == &"":
			return
		_power_up_visual = Node3D.new()
		_power_up_visual.name = "PowerUpPickup"
		add_child(_power_up_visual)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.45
		mesh.outer_radius = 0.55
		ring.mesh = mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = UiTheme.SUCCESS
		material.emission_enabled = true
		material.emission = UiTheme.SUCCESS
		material.emission_energy_multiplier = 2.0
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring.material_override = material
		_power_up_visual.add_child(ring)
		_power_up_glyph = Label3D.new()
		_power_up_glyph.font = UiTheme.mono_bold_font()
		_power_up_glyph.font_size = 72
		_power_up_glyph.pixel_size = 0.015
		_power_up_glyph.outline_size = 12
		_power_up_glyph.modulate = UiTheme.SUCCESS.lightened(0.35)
		_power_up_glyph.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_power_up_glyph.position.y = 1.2
		_power_up_visual.add_child(_power_up_glyph)
		_power_up_name = Label3D.new()
		_power_up_name.font = UiTheme.heading_font()
		_power_up_name.font_size = 28
		_power_up_name.pixel_size = 0.009
		_power_up_name.outline_size = 8
		_power_up_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_power_up_name.position.y = 2.0
		_power_up_visual.add_child(_power_up_name)
	_power_up_visual.visible = p.ground_kind != &"" and p.blinking_visible() and not run.is_over()
	if p.ground_kind == &"":
		return
	_power_up_visual.position = _on_ground(p.ground_pos) + Vector3(0, 0.2, 0)
	_power_up_glyph.position.y = 1.2 + sin(run.time_alive * 3.0) * 0.15
	var data: PowerUpData = GameData.power_up(p.ground_kind)
	if data == null:
		return
	_power_up_glyph.text = data.glyph
	_power_up_name.text = data.display_name
	_power_up_glyph.modulate = data.color.lightened(0.35)
	var ring_material: StandardMaterial3D = (_power_up_visual.get_child(0) as MeshInstance3D).material_override
	ring_material.albedo_color = data.color
	ring_material.emission = data.color


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
		# First person: the light sits next to the eye and lit the whole gun
		# (and the view) orange; a faint flicker is enough there.
		_muzzle.light_energy = 0.25 if camera_mode == Profile.CameraMode.FIRST_PERSON else 3.0
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
		_zombies.on_death(d, Vector3(d.x, gy, d.y), run.player_pos)  # the body falls (common zombies)
		var chunk: Color = ZombieHordeView.DEBRIS_COLOR if _zombies.handles(int(d.z)) else t.color
		for k in 3:
			var vel := Vector3(randf_range(-3, 3), randf_range(3, 7), randf_range(-3, 3))
			_add_debris(origin + Vector3(0, t.height * 0.4, 0), vel, chunk, sx)
		if d.w > 0.5:
			# Headshot: the head pops off, upwards, with a spray of red bits.
			var head_col: Color = ZombieModel.SKIN_TINT.darkened(0.3) if _zombies.handles(int(d.z)) else t.color.lerp(Color(0.85, 0.8, 0.7), 0.45)
			_add_debris(Vector3(d.x, gy + t.height + 0.1, d.y), Vector3(randf_range(-2, 2), 9.0, randf_range(-2, 2)), head_col, -sx)
			for k in 4:
				_add_debris(Vector3(d.x, gy + t.height, d.y), Vector3(randf_range(-4, 4), randf_range(4, 8), randf_range(-4, 4)), Color(0.75, 0.05, 0.05), 0.4)
		else:
			# Body shot: an arm comes off.
			_add_debris(origin + Vector3(0, t.height * 0.3, 0), Vector3(randf_range(-4, 4), 5.0, randf_range(-4, 4)), chunk, sx * 1.6)
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
		var detail: StandardMaterial3D = _building_detail_mats[i]
		if detail != null:
			detail.albedo_color.a = m.albedo_color.a
			detail.transparency = m.transparency


## Nests: the core pulses (faster as the HP drops) and flashes white when
## hit, the mound sinks a little with damage, the HP bar shows once the nest
## is hurt and near, and a destroyed nest bursts into debris and leaves a
## scorch.
func _draw_nests() -> void:
	var t: float = Time.get_ticks_msec() * 0.001
	for n in mini(_nests.size(), run.nest_pos.size()):
		var alive: bool = run.nest_alive(n)
		if not alive and not _nest_dead[n]:
			_nest_dead[n] = true
			var at: Vector3 = _on_ground(run.nest_pos[n]) + Vector3(0, 0.8, 0)
			for k in 24:
				var ang: float = k * TAU / 24.0
				var v := Vector3(cos(ang) * randf_range(2.0, 5.0), randf_range(3.0, 7.0), sin(ang) * randf_range(2.0, 5.0))
				_add_debris(at, v, NEST_FLESH_COLOR if k % 3 != 0 else NEST_CORE_COLOR, 1.4)
		_nests[n].visible = alive
		_nest_scorches[n].visible = not alive
		if not alive:
			continue
		var frac: float = clampf(run.nest_hp[n] / maxf(1.0, run.nest_max_hp), 0.0, 1.0)
		var s: float = lerpf(0.75, 1.0, frac)
		_nests[n].scale = Vector3(1.0, s, 1.0)
		var cm: StandardMaterial3D = _nest_cores[n].material_override
		var hit: bool = run.nest_flash[n] > 0.0
		var pulse: float = 0.5 + 0.5 * sin(t * lerpf(9.0, 3.0, frac))
		cm.albedo_color = Color.WHITE if hit else NEST_CORE_COLOR
		cm.emission = Color.WHITE if hit else NEST_CORE_COLOR
		cm.emission_energy_multiplier = 4.0 if hit else 1.2 + 1.8 * pulse
		_nest_cores[n].scale = Vector3.ONE * (1.0 + 0.12 * pulse)
		var near: bool = run.player_pos.distance_to(run.nest_pos[n]) <= NEST_BAR_RANGE
		_nest_bars[n].visible = near and frac < 1.0
		_nest_bars[n].scale = Vector3(1.0, 1.0 / s, 1.0)  # the mound's squash must not squash the bar
		_nest_fills[n].scale = Vector3(maxf(0.001, frac), 1.0, 1.0)


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
	if run.mission == &"hold_sequence":
		var active: bool = run.objective == IslandRun.Objective.GENERATORS
		_hold_ring.visible = active
		_hold_beacon.visible = active
		if active:
			_hold_ring.position = _on_ground(run.site) + Vector3(0, 0.05, 0)
			_hold_beacon.position = _on_ground(run.site) + Vector3(0, 2, 0)
			var inside: bool = run.player_pos.distance_to(run.site) <= IslandRun.hold_radius()
			var hm: StandardMaterial3D = _hold_ring.material_override
			hm.albedo_color = Color(0.3, 1.0, 0.5) if inside else Color(0.3, 0.8, 1.0)
			var bmat: StandardMaterial3D = _hold_beacon.material_override
			bmat.albedo_color = Color(0.3, 0.8, 1.0).lerp(Color(0.3, 1.0, 0.5), run.hold_progress / IslandRun.hold_seconds())
	if run.uses_cargo():
		_draw_cans()
	if run.mission == &"signals":
		_draw_signals()
	if run.mission == &"fuel_run":
		var ring: StandardMaterial3D = _delivery_ring.material_override
		ring.albedo_color = Color(0.3, 1.0, 0.5) if run.is_carrying() else FUEL_COLOR
		_delivery_ring.visible = run.objective == IslandRun.Objective.GENERATORS
	if run.mission == &"nests":
		_draw_nests()
	if run.mission == &"intel_search":
		_draw_intel_search()
	if run.mission == &"sabotage":
		_draw_sabotage()
	if run.mission == &"escort":
		_draw_escort()
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
