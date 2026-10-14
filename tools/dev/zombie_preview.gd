extends SceneTree
## Windowed captures of the zombie and weapon art (needs a GPU; not a test).
##   godot --path . --script res://tools/dev/zombie_preview.gd -- <PNG path> <shot>
## Shots: lineup (Recruit + the 4 zombie variants), walk (mid-stride, side
## view), closeup (faces and gore), back, corpses, weapons (the 5 guns),
## hands (Recruit holding each gun), fp_<weapon id> (first person).

const CENTER := Vector3(20, 0, 20)

var _out: String
var _shot: String = "lineup"
var _frames: int = 0
var _world: Node3D
var _camera: Camera3D
var _view: ZombieHordeView
var _horde: Horde
var _map: IslandMap
var _t: float = 0.0
var _bench_gpu: float = 0.0
var _bench_cpu: float = 0.0
var _bench_frame: float = 0.0
var _bench_draw: float = 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Usage: zombie_preview.gd -- <PNG path> [lineup|walk|closeup|back|corpses|weapons|hands|fp_<id>]")
		quit(1)
		return
	_out = args[0]
	if args.size() > 1:
		_shot = args[1]
	DisplayServer.window_set_size(Vector2i(1600, 900))
	_world = Node3D.new()
	root.add_child(_world)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Visuals.sky(Color(0.7, 0.75, 0.8), Color(0.35, 0.5, 0.7))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	Visuals.apply_post(env)
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	_world.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.position = CENTER
	ground.material_override = Visuals.mat(Color(0.42, 0.4, 0.34))
	_world.add_child(ground)
	_camera = Camera3D.new()
	_camera.fov = 40
	_world.add_child(_camera)
	_camera.make_current()
	_map = IslandMap.new()
	_map.field = FlowField.new(64, 64)
	_horde = Horde.new(_map.field)
	_view = ZombieHordeView.new()
	_world.add_child(_view)


## A base speed that gives `variant` (the view picks variants from it).
func _speed_for(variant: int, skip: int = 0) -> float:
	var s: float = 1.8
	while true:
		if ZombieModel.variant_for(s) == variant:
			if skip == 0:
				return s
			skip -= 1
		s += 0.0137
	return s


func _zombie(pos: Vector3, variant: int, velocity: Vector3 = Vector3.ZERO, skip: int = 0) -> int:
	var rng := RandomNumberGenerator.new()
	var i: int = _horde.add(pos, GameData.EnemyKind.WALKER, rng)
	_horde.speeds[i] = _speed_for(variant, skip)
	_horde.velocities[i] = velocity
	_horde.attack_cd[i] = 99.0
	return i


func _setup() -> void:
	_horde.target = CENTER + Vector3(0, 0, 40)
	match _shot:
		"lineup", "back":
			var soldier := SoldierModel.create(&"recruit")
			soldier.position = CENTER + Vector3(-3.2, 0, 0)
			soldier.rotation_degrees.y = 180  # soldiers face -Z
			_world.add_child(soldier)
			for v in ZombieModel.VARIANTS:
				_zombie(CENTER + Vector3(-1.6 + v * 1.6, 0, 0), v, Vector3(0, 0, 0.6))
			var behind: float = -1.0 if _shot == "back" else 1.0
			_camera.position = CENTER + Vector3(-0.8, 1.3, 7.5 * behind)
			_camera.look_at(CENTER + Vector3(-0.8, 1.0, 0))
		"walk":
			for v in ZombieModel.VARIANTS:
				_zombie(CENTER + Vector3(-3.0 + v * 2.0, 0, 0), v, Vector3(0, 0, 2.4))
			_camera.position = CENTER + Vector3(7.5, 1.4, 2.5)
			_camera.look_at(CENTER + Vector3(0, 1.0, 0))
		"closeup":
			for v in ZombieModel.VARIANTS:
				_zombie(CENTER + Vector3(-1.05 + v * 0.7, 0, 0), v, Vector3(0, 0, 0.2))
			_camera.position = CENTER + Vector3(0, 1.75, 2.6)
			_camera.look_at(CENTER + Vector3(0, 1.45, 0))
		"corpses":
			for v in ZombieModel.VARIANTS:
				var p: Vector3 = CENTER + Vector3(-2.4 + v * 1.6, 0, 0)
				_zombie(p, v)
			_camera.position = CENTER + Vector3(0, 2.6, 6.5)
			_camera.look_at(CENTER + Vector3(0, 0.2, 0))
		"weapons":
			var y: float = 1.9
			for id: StringName in WeaponModel.IDS:
				var w := WeaponModel.build(id)
				w.position = CENTER + Vector3(0, y, 0)
				w.rotation_degrees.y = 90  # barrels to the left (-X)
				_world.add_child(w)
				y -= 0.36
			_camera.position = CENTER + Vector3(0, 1.2, 2.7)
			_camera.look_at(CENTER + Vector3(0, 1.18, 0))
		"hands":
			var x: float = -3.2
			for id: StringName in WeaponModel.IDS:
				var soldier := SoldierModel.create(&"vanguard" if id == &"machine_gun" else &"recruit")
				soldier.position = CENTER + Vector3(x, 0, 0)
				soldier.rotation_degrees.y = 150
				_world.add_child(soldier)
				soldier.set_weapon(id)
				x += 1.6
			_camera.position = CENTER + Vector3(0, 1.5, 6.5)
			_camera.look_at(CENTER + Vector3(0, 1.2, 0))
		"bench", "bench_empty":
			# 150 walking zombies (the alive cap) seen from the third-person
			# height; "bench_empty" is the same scene without them.
			if _shot == "bench":
				for k in 150:
					var pos: Vector3 = CENTER + Vector3(-9.0 + (k % 15) * 1.3, 0, -12.0 + (k / 15) * 1.3)
					_zombie(pos, k % ZombieModel.VARIANTS, Vector3(0, 0, 2.2), k / ZombieModel.VARIANTS)
			_camera.position = CENTER + Vector3(0, 3.0, 9.0)
			_camera.look_at(CENTER + Vector3(0, 1.0, -4.0))
			_camera.fov = 70
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		_:
			if _shot.begins_with("fp_"):
				var id := StringName(_shot.substr(3))
				_camera.position = CENTER + Vector3(0, 1.72, 6)
				_camera.look_at(CENTER + Vector3(0, 1.5, 0))
				_camera.fov = 75
				_camera.near = 0.03
				var vm := ViewModel.create(&"recruit")
				_camera.add_child(vm)
				vm.set_weapon(id)
				for v in ZombieModel.VARIANTS:
					_zombie(CENTER + Vector3(-2.4 + v * 1.6, 0, 1.0 - v * 0.5), v, Vector3(0, 0, 1.5))


func _process(delta: float) -> bool:
	_frames += 1
	_t += delta
	if _frames == 1:
		_setup()  # look_at needs the nodes in the tree
	var now: float = 0.35 if _shot != "walk" else 0.55
	if _shot.begins_with("bench"):
		now = _t
		if _frames > 60 and _frames <= 560:
			_bench_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			_bench_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			_bench_frame += delta
		if _frames == 560:
			print("BENCH %s: GPU %.3f ms, render CPU %.3f ms, frame %.3f ms (500 frames, vsync off)" % [_shot, _bench_gpu / 500.0, _bench_cpu / 500.0, _bench_frame / 500.0 * 1000.0])
	var t0: int = Time.get_ticks_usec()
	_view.draw(_horde, _map, now, 0.0)
	if _shot.begins_with("bench") and _frames > 60 and _frames <= 560:
		_bench_draw += (Time.get_ticks_usec() - t0) / 1000.0
		if _frames == 560:
			print("BENCH %s: ZombieHordeView.draw %.3f ms" % [_shot, _bench_draw / 500.0])
	if _shot == "corpses" and _horde.count > 0 and _t > 1.5:
		# Kill them: two fall normally, two lose their heads; staggered times.
		for k in range(_horde.count - 1, -1, -1):
			var p: Vector3 = _horde.positions[k]
			_horde.remove(k)
			_view.draw(_horde, _map, now, 0.0)
			_view.on_death(Vector4(p.x, p.z, GameData.EnemyKind.WALKER, 1.0 if k % 2 == 1 else 0.0), p, p + Vector3(0, 0, 5))
	if _shot == "corpses" and _horde.count == 0:
		_view.draw(_horde, _map, now, delta)  # corpses age in real time (gone after 5 s)
	# BootSplashPlus covers the window for at least 2.3 s.
	if _frames >= (600 if _shot.begins_with("bench") else 40) and _t >= 3.2:
		_frames = -100000
		var img := root.get_texture().get_image()
		var err: Error = img.save_png(_out)
		print("PREVIEW: %s %dx%d save %d" % [_shot, img.get_width(), img.get_height(), err])
		quit(0 if err == OK else 1)
	return false
