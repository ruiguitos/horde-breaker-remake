extends SceneTree
## Common zombie art (ZombieModel + ZombieHordeView): the four variants
## build headless with their Poly Haven materials, variants are stable per
## enemy, the drawn head stays where IslandRun.enemy_head() aims, poses come
## from the horde state, corpses fall and go away, and 150 zombies are cheap
## to update (timed). Visual only: nothing here changes gameplay.
## Run: godot --headless --path . --script res://tests/test_zombie_model.gd

var _failures: int = 0


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_test_meshes()
	_test_variants()
	_test_head()
	_test_view()
	_test_timing()
	quit(1 if _failures > 0 else 0)


func _test_meshes() -> void:
	for v in ZombieModel.VARIANTS:
		var m: ArrayMesh = ZombieModel.mesh(v)
		var ok: bool = m != null and m.get_surface_count() >= 3
		var textured: bool = true
		for s in m.get_surface_count():
			var mat := m.surface_get_material(s) as ShaderMaterial
			textured = textured and mat != null and mat.get_shader_parameter(&"albedo_tex") != null \
				and mat.get_shader_parameter(&"normal_tex") != null and mat.get_shader_parameter(&"rough_tex") != null
		var box: AABB = m.get_aabb()
		_check(ok and textured, "%s: %d material layers, each with Poly Haven albedo/normal/roughness" % [ZombieModel.VARIANT_NAMES[v], m.get_surface_count()])
		_check(absf(box.position.y) < 0.01 and box.end.y > 1.9 and box.end.y < 2.0,
			"%s stands on the ground, %.2f m tall (Recruit: 2.03 m with helmet)" % [ZombieModel.VARIANT_NAMES[v], box.end.y])
		var arrays: Array = m.surface_get_arrays(0)
		_check(arrays[Mesh.ARRAY_CUSTOM0] != null and arrays[Mesh.ARRAY_CUSTOM1] != null and arrays[Mesh.ARRAY_TANGENT] != null,
			"%s carries part/gore (CUSTOM0), tint (CUSTOM1) and tangents for the normal maps" % ZombieModel.VARIANT_NAMES[v])
	_check(ZombieModel.mesh(2) == ZombieModel.mesh(2), "meshes are built once and shared")


func _parts(v: int) -> Dictionary:
	var parts: Dictionary = {}
	for b: Dictionary in ZombieModel.boxes(v):
		parts[b["part"]] = true
	return parts


func _kinds(v: int) -> Dictionary:
	var kinds: Dictionary = {}
	for b: Dictionary in ZombieModel.boxes(v):
		kinds[b["kind"]] = int(kinds.get(b["kind"], 0)) + 1
	return kinds


func _test_variants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var seen: Dictionary = {}
	var stable: bool = true
	for k in 400:
		var speed: float = rng.randf_range(1.8, 2.6)  # Walker speed range
		var v: int = ZombieModel.variant_for(speed)
		stable = stable and v == ZombieModel.variant_for(speed) and v >= 0 and v < ZombieModel.VARIANTS
		seen[v] = int(seen.get(v, 0)) + 1
	_check(stable, "variant_for is deterministic")
	var spread: bool = seen.size() == ZombieModel.VARIANTS
	for v: int in seen:
		spread = spread and int(seen[v]) > 40
	_check(spread, "the Walker speed range spreads over all 4 variants %s" % [seen])
	_check(not _parts(1).has(ZombieModel.Part.ARM_LOWER_L) and _kinds(1).get(ZombieModel.Kind.BONE, 0) > 0,
		"worker: left forearm missing, bone sticking out of the stump")
	_check(not _kinds(2).has(ZombieModel.Kind.MOUTH) or _kinds(2)[ZombieModel.Kind.MOUTH] == 1, "jacket: the lower jaw is gone (one throat box, no mouth slit)")
	_check(_kinds(3).get(ZombieModel.Kind.FLESH, 0) >= 2 and _kinds(3).get(ZombieModel.Kind.BONE, 0) >= 3, "shirtless: torn-open flank with ribs")
	var gore: int = 0
	for v in ZombieModel.VARIANTS:
		for b: Dictionary in ZombieModel.boxes(v):
			if float(b["gore"]) >= 0.5:
				gore += 1
	_check(gore >= 8, "strong gore: %d heavy wound boxes across the variants" % gore)


func _test_head() -> void:
	var walker: GameData.EnemyType = GameData.enemy_types()[GameData.EnemyKind.WALKER]
	var skull: Dictionary = {}
	for b: Dictionary in ZombieModel.boxes(0):
		if b["part"] == ZombieModel.Part.HEAD and (b["s"] as Vector3).y > 0.2:
			skull = b
	_check(not skull.is_empty() and (skull["c"] as Vector3).is_equal_approx(ZombieModel.HEAD_CENTER), "HEAD_CENTER is the skull box centre")
	# IslandRun.enemy_head(): ground + height + 0.08 * radius_scale.
	var logic_y: float = walker.height + 0.08 * walker.radius_scale
	var drawn_y: float = ZombieModel.HEAD_CENTER.y * walker.height / ZombieModel.MODEL_HEIGHT
	_check(absf(drawn_y - logic_y) < 0.03, "rest head at %.3f m, headshot logic at %.3f m" % [drawn_y, logic_y])
	# The crosshair test measures the distance from the aim ray to that point
	# (0.4 m for a Walker). The zombie leans and lunges toward the player,
	# i.e. mostly along the aim ray, so sideways and height drift matter most.
	var side: float = 0.0
	var up: float = 0.0
	var fwd: float = 0.0
	var walking: float = 0.0
	for walk: float in [0.0, 0.5, 1.0]:
		for lunge: float in [0.0, 1.0]:
			for flinch: float in [0.0, 1.0]:
				for k in 12:
					var p: Vector3 = ZombieModel.head_pose(walk, lunge, flinch, k * TAU / 12.0) * Vector3(walker.radius_scale, walker.height / ZombieModel.MODEL_HEIGHT, walker.radius_scale)
					var d := p - Vector3(0, logic_y, 0)
					side = maxf(side, absf(d.x))
					up = maxf(up, absf(d.y))
					fwd = maxf(fwd, absf(d.z))
					if lunge == 0.0 and flinch == 0.0:
						walking = maxf(walking, d.length())
	_check(side < 0.2 and up < 0.2, "posed head: at most %.2f m sideways and %.2f m in height from the headshot point (aim radius %.1f m)" % [side, up, GameData.CROSSHAIR_HEAD_RADIUS])
	_check(walking < 0.3, "walking head within %.2f m of the headshot point; lunges reach %.2f m forward, toward the player" % [walking, fwd])


func _horde(walkers: int, brutes: int) -> Array:
	var map := IslandMap.new()
	map.field = FlowField.new(64, 64)
	var h := Horde.new(map.field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in walkers:
		var i: int = h.add(Vector3(5 + (k % 15) * 1.2, 0, 5 + (k / 15) * 1.2), GameData.EnemyKind.WALKER, rng)
		h.velocities[i] = Vector3(0, 0, 2.0)
	for k in brutes:
		h.add(Vector3(40 + k, 0, 40), GameData.EnemyKind.BRUTE, rng)
	h.target = Vector3(30, 0, 60)
	return [h, map]


## Instance i of variant v in the view's buffer: [transform 12, colour 4, custom 4].
func _instance(view: ZombieHordeView, v: int, i: int) -> PackedFloat32Array:
	return view.buffer(v).slice(i * ZombieHordeView.STRIDE, (i + 1) * ZombieHordeView.STRIDE)


func _test_view() -> void:
	var setup: Array = _horde(150, 10)
	var h: Horde = setup[0]
	var map: IslandMap = setup[1]
	var view := ZombieHordeView.new()
	root.add_child(view)
	view.draw(h, map, 1.0, 0.016)
	var total: int = 0
	for v in ZombieModel.VARIANTS:
		total += view.instance_count(v)
	_check(total == 150 and view.handles(GameData.EnemyKind.WALKER) and not view.handles(GameData.EnemyKind.BRUTE),
		"150 walkers drawn as zombies; the 10 brutes stay capsules (special enemies later)")
	var v0: int = ZombieModel.variant_for(h.speeds[0])
	var first: PackedFloat32Array = _instance(view, v0, 0)
	var p: Vector3 = h.positions[0]
	_check(is_equal_approx(first[3], p.x) and is_equal_approx(first[11], p.z) and is_equal_approx(first[5], 1.0),
		"instance transform: on the enemy's position, Walker height scale 1")
	_check(first[2] > 0.0 or is_equal_approx(first[10], 1.0), "walking +Z faces +Z (the model's front)")
	_check(first[17] > 0.7 and first[19] == 0.0, "walking: walk amount %.2f, no flinch" % first[17])
	# Hit flash -> flinch; stun -> stagger; just attacked in reach -> lunge.
	h.flash[0] = 0.1
	view.draw(h, map, 1.1, 0.016)
	_check(_instance(view, v0, 0)[19] > 0.9 and _instance(view, v0, 0)[15] > 0.3, "a hit flinches the zombie and flashes it")
	h.flash[0] = 0.0
	h.stun[0] = 1.0
	view.draw(h, map, 1.2, 0.016)
	_check(_instance(view, v0, 0)[18] < 0.0, "stunned zombies stagger")
	h.stun[0] = 0.0
	h.positions[0] = h.target + Vector3(0, 0, -1.0)
	h.velocities[0] = Vector3.ZERO
	h.attack_cd[0] = h.types[GameData.EnemyKind.WALKER].attack_interval - 0.15
	view.draw(h, map, 1.3, 0.016)
	_check(_instance(view, v0, 0)[18] > 0.5, "a zombie that just hit the player lunges")
	h.freeze_time[0] = 2.0
	view.draw(h, map, 1.4, 0.016)
	var frozen: PackedFloat32Array = _instance(view, v0, 0)
	_check(frozen[17] == 0.0 and frozen[15] > 0.5, "frozen zombies stop and turn icy")
	h.freeze_time[0] = 0.0
	# Death: the zombie leaves the horde, its corpse keeps its variant and falls.
	var dead: Vector3 = h.positions[5]
	var dead_variant: int = ZombieModel.variant_for(h.speeds[5])
	view.draw(h, map, 1.5, 0.016)
	h.remove(5)
	view.draw(h, map, 1.52, 0.016)
	var before: int = view.instance_count(dead_variant)
	view.on_death(Vector4(dead.x, dead.z, GameData.EnemyKind.WALKER, 1.0), dead, dead + Vector3(0, 0, 5))
	view.on_death(Vector4(50, 50, GameData.EnemyKind.BRUTE, 0.0), Vector3(50, 0, 50), Vector3.ZERO)
	view.draw(h, map, 1.54, 0.5)
	_check(view.corpse_count() == 1 and view.instance_count(dead_variant) == before + 1, "a dead walker becomes one corpse of its own variant (brutes do not)")
	var corpse: PackedFloat32Array = _instance(view, dead_variant, view.instance_count(dead_variant) - 1)
	_check(corpse[19] >= 4.0 and corpse[19] <= 5.0, "headshot corpse falls without its head (state %.2f)" % corpse[19])
	view.draw(h, map, 2.0, ZombieHordeView.CORPSE_TIME)
	_check(view.corpse_count() == 0, "corpses sink and are removed after %.0f s" % ZombieHordeView.CORPSE_TIME)
	view.free()


func _test_timing() -> void:
	var setup: Array = _horde(150, 0)
	var h: Horde = setup[0]
	var map: IslandMap = setup[1]
	var view := ZombieHordeView.new()
	root.add_child(view)
	view.draw(h, map, 0.0, 0.016)
	var frames: int = 300
	var t0: int = Time.get_ticks_usec()
	for f in frames:
		view.draw(h, map, f / 60.0, 1.0 / 60.0)
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / frames
	# The previous capsule + head + 2 arms path, per enemy, for comparison
	# (same transforms/colours it set each frame).
	var mms: Array[MultiMesh] = []
	for k in 3:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.instance_count = h.count * (2 if k == 2 else 1)
		mms.append(mm)
	t0 = Time.get_ticks_usec()
	for f in frames:
		for i in h.count:
			var v: Vector3 = h.velocities[i]
			var rot := Basis(Vector3.UP, atan2(v.x, v.z)) * Basis(Vector3.RIGHT, 0.18) * Basis(Vector3.FORWARD, sin(f * 0.1 + i) * 0.14)
			var c := Vector3(h.positions[i].x, 0.85, h.positions[i].z)
			mms[0].set_instance_transform(i, Transform3D(rot, c))
			mms[1].set_instance_transform(i, Transform3D(Basis(), c + rot * Vector3(0, 0.93, 0.06)))
			for side in 2:
				mms[2].set_instance_transform(i * 2 + side, Transform3D(rot, c + rot * Vector3(0.3, 0.48, 0.3)))
				mms[2].set_instance_color(i * 2 + side, Color.GREEN)
			mms[0].set_instance_color(i, Color.GREEN)
			mms[1].set_instance_color(i, Color.GREEN)
	var old_ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / frames
	print("PERF: 150 zombies, ZombieHordeView.draw = %.3f ms/frame (old capsule path, headless: %.3f ms)" % [ms, old_ms])
	_check(ms < 3.0, "150 zombies update in %.3f ms per frame (CPU, headless; budget 3 ms)" % ms)
	var t1: int = Time.get_ticks_usec()
	ZombieModel._meshes.clear()
	for v in ZombieModel.VARIANTS:
		ZombieModel.mesh(v)
	print("PERF: building the 4 variant meshes = %.1f ms (once per session)" % ((Time.get_ticks_usec() - t1) / 1000.0))
	view.free()
