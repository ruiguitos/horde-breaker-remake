extends SceneTree
## Windowed captures of the zombie and weapon art (needs a GPU; not a test).
##   godot --path . --script res://tools/dev/zombie_preview.gd -- <PNG path> <shot>
## Shots: lineup (Recruit + the 4 zombie variants), walk (mid-stride, side
## view), closeup (faces, gore and missing parts), back, corpses, variety
## (24 random looks), crowd (48 random zombies), weapons (the 5 guns),
## rifle (the assault rifle alone, close),
## hands (Recruit holding each gun), hands_vanguard, fp_<weapon id> (first person),
## specials / specials_back (all kinds), bench_specials (150 mixed enemies), bench
## and bench_empty (GPU/CPU timings of 150 zombies), crawl (3 Crawlers, 3/4
## front), crawl_side, crawl_close (one Crawler, low side view: the hands),
## legless (two legs-gone zombies mid-topple), flank (shirtless flank wound),
## face (eyes and sockets). A third argument sets the animation time (seconds)
## of a still, e.g. crawl_close 0.4.

const CENTER := Vector3(20, 0, 20)

var _out: String
var _shot: String = "lineup"
## Animation time of the still (optional 3rd argument): stride frames of a Crawler.
var _now: float = -1.0
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
		print("Usage: zombie_preview.gd -- <PNG path> [lineup|walk|closeup|back|corpses|variety|crowd|weapons|hands|fp_<id>|bench|bench_empty]")
		quit(1)
		return
	_out = args[0]
	if args.size() > 1:
		_shot = args[1]
	if args.size() > 2:
		_now = float(args[2])
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


## Soldier, weapon and view-model scripts are loaded only by the shots that
## use them, so the zombie shots still run while those files are being
## edited (no static dependency at compile time).
func _script(file: String) -> GDScript:
	return load("res://game/world/%s.gd" % file) as GDScript


## A base speed whose rolled look (ZombieModel.roll_look) passes `test`.
func _speed_where(test: Callable, skip: int = 0) -> float:
	var s: float = 1.8
	while s < 40.0:
		if test.call(ZombieModel.roll_look(ZombieModel.seed_for(s))):
			if skip == 0:
				return s
			skip -= 1
		s += 0.0137
	return s


func _zombie(pos: Vector3, variant: int, velocity: Vector3 = Vector3.ZERO, skip: int = 0) -> int:
	return _zombie_at(pos, _speed_for(variant, skip), velocity)


func _zombie_at(pos: Vector3, speed: float, velocity: Vector3 = Vector3.ZERO) -> int:
	var rng := RandomNumberGenerator.new()
	var i: int = _horde.add(pos, GameData.EnemyKind.WALKER, rng)
	_horde.speeds[i] = speed
	_horde.velocities[i] = velocity
	_horde.attack_cd[i] = 99.0
	return i


## A Crawler walking towards +Z (its legs are gone from the start).
func _crawler(pos: Vector3, speed: float) -> int:
	var rng := RandomNumberGenerator.new()
	var i: int = _horde.add(pos, GameData.EnemyKind.CRAWLER, rng)
	_horde.speeds[i] = speed
	_horde.velocities[i] = Vector3(0, 0, 0.9)
	_horde.attack_cd[i] = 99.0
	return i


func _setup() -> void:
	_horde.target = CENTER + Vector3(0, 0, 40)
	match _shot:
		"specials", "specials_back":
			var types: Array[GameData.EnemyType] = GameData.enemy_types()
			var rng := RandomNumberGenerator.new()
			rng.seed = 41
			for kind in types.size():
				var pos: Vector3 = CENTER + Vector3(-7.5 + kind * 2.5, 0, 0)
				var i: int = _horde.add(pos, kind, rng)
				_horde.velocities[i] = Vector3(0, 0, 0.3)
				_horde.attack_cd[i] = 99.0
				var label := Label3D.new()
				label.text = types[kind].display_name
				label.position = pos + Vector3(0, -0.01, 0.65)
				label.pixel_size = 0.009
				label.font_size = 48
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.no_depth_test = true
				_world.add_child(label)
			_camera.position = CENTER + Vector3(0.4, 4.5, -18.0 if _shot == "specials_back" else 18.0)
			_camera.look_at(CENTER + Vector3(0, 1.7, 0))
			_camera.fov = 56
		"lineup", "back":
			var soldier: Variant = _script("soldier_model").create(&"recruit")
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
			# One per variant, each missing something: jaw, ear, fingers, forearm.
			var missing: Array[int] = [ZombieModel.Missing.JAW, ZombieModel.Missing.EAR, ZombieModel.Missing.FINGERS, ZombieModel.Missing.FOREARM]
			for v in ZombieModel.VARIANTS:
				var m: int = missing[v]
				var s: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == v and l["missing"] == m and l["hair"] > 0)
				_zombie_at(CENTER + Vector3(-1.05 + v * 0.7, 0, 0), s, Vector3(0, 0, 0.2))
			_camera.position = CENTER + Vector3(0, 1.75, 2.6)
			_camera.look_at(CENTER + Vector3(0, 1.45, 0))
		"variety":
			# 24 random zombies in three rows, facing the camera: the outfits.
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			for k in 24:
				var row: int = k / 8
				var pos: Vector3 = CENTER + Vector3(-3.5 + (k % 8) * 1.0 + row * 0.33, 0, -row * 1.5)
				_zombie_at(pos, rng.randf_range(1.8, 2.6), Vector3(0, 0, 0.3))
			_camera.position = CENTER + Vector3(0, 1.9, 7.8)
			_camera.look_at(CENTER + Vector3(0, 0.95, -1.5))
			_camera.fov = 45
		"crowd":
			# 48 random zombies shambling at the camera, seen from the
			# third-person camera height.
			var rng := RandomNumberGenerator.new()
			rng.seed = 3
			for k in 48:
				var pos: Vector3 = CENTER + Vector3(rng.randf_range(-5.5, 5.5), 0, rng.randf_range(-12.0, 1.5))
				var dir := Vector3(rng.randf_range(-0.5, 0.5), 0, 1).normalized()
				_zombie_at(pos, rng.randf_range(1.8, 2.6), dir * rng.randf_range(0.8, 2.4))
			_camera.position = CENTER + Vector3(0, 2.6, 7.0)
			_camera.look_at(CENTER + Vector3(0, 0.9, -3.0))
			_camera.fov = 60
		"corpses":
			for v in ZombieModel.VARIANTS:
				var p: Vector3 = CENTER + Vector3(-2.4 + v * 1.6, 0, 0)
				_zombie(p, v)
			_camera.position = CENTER + Vector3(0, 2.6, 6.5)
			_camera.look_at(CENTER + Vector3(0, 0.2, 0))
		"weapons":
			var y: float = 1.9
			for id: StringName in _script("weapon_model").IDS:
				var w: Variant = _script("weapon_model").build(id)
				w.position = CENTER + Vector3(0, y, 0)
				w.rotation_degrees.y = 90  # barrels to the left (-X)
				_world.add_child(w)
				y -= 0.36
			_camera.position = CENTER + Vector3(0, 1.2, 2.7)
			_camera.look_at(CENTER + Vector3(0, 1.18, 0))
		"rifle":
			# The assault rifle alone, close, from the front-right: receiver, grip, stock.
			var rifle: Variant = _script("weapon_model").build(&"rifle")
			rifle.position = CENTER + Vector3(0, 1.25, 0)
			rifle.rotation_degrees.y = 90  # barrel to the left (-X)
			_world.add_child(rifle)
			_camera.position = CENTER + Vector3(0.55, 1.45, 0.9)
			_camera.look_at(CENTER + Vector3(0, 1.25, 0))
		"hands", "hands_vanguard":
			var x: float = -3.2
			for id: StringName in _script("weapon_model").IDS:
				var soldier: Variant = _script("soldier_model").create(&"vanguard" if _shot == "hands_vanguard" or id == &"machine_gun" else &"recruit")
				soldier.position = CENTER + Vector3(x, 0, 0)
				soldier.rotation_degrees.y = 150
				_world.add_child(soldier)
				soldier.set_weapon(id)
				x += 1.6
			_camera.position = CENTER + Vector3(0, 1.5, 6.5)
			_camera.look_at(CENTER + Vector3(0, 1.2, 0))
		"bench", "bench_empty", "bench_specials", "bench_crawl", "bench_crawl_proc":
			# 150 walking zombies (the alive cap) seen from the third-person
			# height; "bench_empty" is the same scene without them. bench_crawl:
			# 150 Crawlers (their travel grows 2.2 m/s in _process); bench_crawl_proc
			# the same with the procedural Crawler (CrawlerBody switched off).
			if _shot == "bench_crawl_proc":
				CrawlerBody.enabled = false
			if _shot != "bench_empty":
				for k in 150:
					var pos: Vector3 = CENTER + Vector3(-9.0 + (k % 15) * 1.3, 0, -12.0 + (k / 15) * 1.3)
					if _shot.begins_with("bench_crawl"):
						_crawler(pos, 1.0)
					elif _shot == "bench_specials":
						var kinds: Array[int] = [0, 0, 0, 1, 2, 3, 5, 6]
						var rng := RandomNumberGenerator.new()
						rng.seed = 100 + k
						var i: int = _horde.add(pos, GameData.EnemyKind.BOSS if k == 149 else kinds[k % kinds.size()], rng)
						_horde.velocities[i] = Vector3(0, 0, 2.2)
					else:
						_zombie(pos, k % ZombieModel.VARIANTS, Vector3(0, 0, 2.2), k / ZombieModel.VARIANTS)
			_camera.position = CENTER + Vector3(0, 3.0, 9.0)
			_camera.look_at(CENTER + Vector3(0, 1.0, -4.0))
			_camera.fov = 70
			DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
			RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(), true)
		"crawl", "crawl_side", "crawl_close":
			# Crawlers moving towards +Z: a civilian, a worker with a missing
			# forearm (the stump hand) and a shirtless one (the flank wound).
			var civ: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == 0 and l["missing"] == ZombieModel.Missing.NONE)
			var stump: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == 1 and l["missing"] == ZombieModel.Missing.FOREARM)
			var shirtless: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == 3 and l["missing"] == ZombieModel.Missing.NONE)
			if _shot == "crawl":
				_crawler(CENTER + Vector3(-1.5, 0, 0), civ)
				_crawler(CENTER + Vector3(0, 0, 0), stump)
				_crawler(CENTER + Vector3(1.5, 0, 0), shirtless)
				_camera.position = CENTER + Vector3(0.6, 1.5, 4.6)
				_camera.look_at(CENTER + Vector3(0, 0.45, 0))
				_camera.fov = 45
			elif _shot == "crawl_close":
				_crawler(CENTER, civ)
				_camera.position = CENTER + Vector3(1.25, 0.5, 0.6)
				_camera.look_at(CENTER + Vector3(0, 0.3, 0.3))
				_camera.fov = 40
			else:
				_crawler(CENTER, stump)
				_camera.position = CENTER + Vector3(2.4, 0.95, 0.2)
				_camera.look_at(CENTER + Vector3(0, 0.4, 0))
				_camera.fov = 40
		"crawl_topple":
			# Three Crawlers mid-topple: progress 0 (rear up on the hands), 0.5, 1 (crawling).
			for k in 3:
				var i: int = _crawler(CENTER + Vector3(-1.8 + k * 1.8, 0, 0), 0.0)
				_horde.crawl_delay[i] = GameData.CRAWL_TRANSITION_TIME * (1.0 - k * 0.5)
				_horde.velocities[i] = Vector3.ZERO
			_camera.position = CENTER + Vector3(0.0, 2.2, 7.0)
			_camera.look_at(CENTER + Vector3(0, 0.5, 0))
			_camera.fov = 45
		"crawl_death":
			# Crawlers killed a moment ago (0.45 s of fall): one normal, one headless.
			for k in 2:
				var at: Vector3 = CENTER + Vector3(-1.0 + k * 2.0, 0, 0)
				var i: int = _crawler(at, 0.0)
				_horde.velocities[i] = Vector3.ZERO
			_view.draw(_horde, _map, 0.0, 0.0)
			for k in range(_horde.count - 1, -1, -1):
				var p: Vector3 = _horde.positions[k]
				_horde.remove(k)
				_view.draw(_horde, _map, 0.0, 0.0)
				_view.on_death(Vector4(p.x, p.z, GameData.EnemyKind.CRAWLER, 1.0 if k == 1 else 0.0), p, p + Vector3(0, 0, 5))
			_view.draw(_horde, _map, 0.0, 0.45)
			_camera.position = CENTER + Vector3(0.0, 2.0, 5.0)
			_camera.look_at(CENTER + Vector3(0, 0.2, 0))
			_camera.fov = 45
		"crawl_stride", "crawl_crowd":
			# Four Crawlers that have travelled 0, 0.2, 0.4, 0.6 m (the hands' phase
			# follows the travel): the planting through a stride. crawl_crowd: 60
			# random Crawlers moving towards the camera, at random travel.
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			if _shot == "crawl_stride":
				for k in 4:
					var i: int = _crawler(CENTER + Vector3(-2.1 + k * 1.4, 0, 0), 2.0 + k * 0.1)
					_horde.travel[i] = k * 0.2
				_camera.position = CENTER + Vector3(0.9, 1.4, 6.4)
				_camera.look_at(CENTER + Vector3(0, 0.35, 0))
				_camera.fov = 45
			else:
				for k in 60:
					var pos: Vector3 = CENTER + Vector3(rng.randf_range(-9.0, 9.0), 0, rng.randf_range(-9.0, 9.0))
					var i: int = _crawler(pos, rng.randf_range(0.6, 2.4))
					_horde.travel[i] = rng.randf_range(0.0, 4.0)
				_camera.position = CENTER + Vector3(0, 9.0, 13.0)
				_camera.look_at(CENTER + Vector3(0, 0.0, 0))
				_camera.fov = 40
		"legless":
			# Legs just gone: a worker with a missing forearm and a shirtless
			# zombie half-way through the topple (progress 0.5).
			var stump: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == 1 and l["missing"] == ZombieModel.Missing.FOREARM)
			var shirtless: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == 3 and l["missing"] == ZombieModel.Missing.NONE)
			var a: int = _zombie_at(CENTER + Vector3(-0.8, 0, 0), stump)
			_horde.amputate(a)
			_horde.crawl_delay[a] = GameData.CRAWL_TRANSITION_TIME * 0.5
			var b: int = _zombie_at(CENTER + Vector3(0.8, 0, 0), shirtless)
			_horde.amputate(b)
			_horde.crawl_delay[b] = GameData.CRAWL_TRANSITION_TIME * 0.5
			_camera.position = CENTER + Vector3(0.6, 1.4, 3.6)
			_camera.look_at(CENTER + Vector3(0, 0.6, 0))
			_camera.fov = 45
		"flank":
			var shirtless: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == 3 and l["missing"] == ZombieModel.Missing.NONE)
			_zombie_at(CENTER, shirtless)
			_camera.position = CENTER + Vector3(0.5, 1.35, 1.5)
			_camera.look_at(CENTER + Vector3(0, 1.2, 0))
			_camera.fov = 40
		"face":
			var hair: float = _speed_where(func(l: Dictionary) -> bool: return l["variant"] == 0 and l["hair"] > 0 and l["missing"] == ZombieModel.Missing.NONE)
			_zombie_at(CENTER, hair)
			_camera.position = CENTER + Vector3(0, 1.8, 1.1)
			_camera.look_at(CENTER + Vector3(0, 1.75, 0))
			_camera.fov = 28
		_:
			if _shot.begins_with("fp_") or _shot.begins_with("fpads_") or _shot.begins_with("fpreload_"):
				# fp_<id> hip, fpads_<id> aiming down the sights, fpreload_<id> half way through a reload.
				var id := StringName(_shot.substr(_shot.find("_") + 1))
				_camera.position = CENTER + Vector3(0, 1.72, 6)
				_camera.look_at(CENTER + Vector3(0, 1.5, 0))
				_camera.fov = 75
				_camera.near = 0.03
				var vm: Variant = _script("view_model").create(&"recruit")
				_camera.add_child(vm)
				vm.set_weapon(id)
				vm.aim = 1.0 if _shot.begins_with("fpads_") else 0.0
				vm.reload = 0.5 if _shot.begins_with("fpreload_") else 0.0
				vm.update(0.0, 0.0, 0.0, 0.0)
				for v in ZombieModel.VARIANTS:
					_zombie(CENTER + Vector3(-2.4 + v * 1.6, 0, 1.0 - v * 0.5), v, Vector3(0, 0, 1.5))


func _process(delta: float) -> bool:
	_frames += 1
	_t += delta
	if _frames == 1:
		_setup()  # look_at needs the nodes in the tree
	for child: Node in _world.get_children():
		if child.has_method("animate"):
			child.call("animate", 0.0, _t, false, delta)
	var now: float = _now if _now >= 0.0 else (0.35 if _shot != "walk" else 0.55)
	if _shot.begins_with("bench"):
		now = _t
		if _frames > 60 and _frames <= 560:
			_bench_gpu += RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			_bench_cpu += RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			_bench_frame += delta
		if _frames == 560:
			print("BENCH %s: GPU %.3f ms, render CPU %.3f ms, frame %.3f ms (500 frames, vsync off)" % [_shot, _bench_gpu / 500.0, _bench_cpu / 500.0, _bench_frame / 500.0 * 1000.0])
	if _shot.begins_with("bench_crawl"):
		for i in _horde.count:
			_horde.travel[i] += delta * 2.2  # the hands move with the metres walked
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
