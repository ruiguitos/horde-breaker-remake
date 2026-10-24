extends SceneTree
## Common zombie art (ZombieModel + ZombieHordeView): the four variants
## build headless with their Poly Haven materials, variants and rolled looks
## (outfit colours, patterns, missing parts, build, blood) are stable per
## enemy and varied across a horde, optional boxes hide cleanly, the drawn
## head stays where IslandRun.enemy_head() aims, poses come from the horde
## state, corpses keep their look, fall and go away, and 150 zombies are
## cheap to update (timed). Visual only: nothing here changes gameplay.
## Run: godot --headless --path . --script res://tests/test_zombie_model.gd

var _failures: int = 0


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_test_meshes()
	_test_variants()
	_test_looks()
	_test_hiding()
	_test_cavity_and_stumps()
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
		_check(arrays[Mesh.ARRAY_CUSTOM0] != null and arrays[Mesh.ARRAY_CUSTOM1] != null and arrays[Mesh.ARRAY_CUSTOM2] != null \
			and arrays[Mesh.ARRAY_TANGENT] != null and arrays[Mesh.ARRAY_INDEX] != null,
			"%s carries part/gore (CUSTOM0), tint+slot (CUSTOM1), show conditions (CUSTOM2), tangents, and is indexed" % ZombieModel.VARIANT_NAMES[v])
	_check(ZombieModel.mesh(2) == ZombieModel.mesh(2), "meshes are built once and shared")


## The boxes of variant v that a zombie with this mask shows.
func _visible(v: int, mask: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for b: Dictionary in ZombieModel.boxes(v):
		if ZombieModel.shows(b, mask):
			out.append(b)
	return out


func _kinds(boxes: Array[Dictionary]) -> Dictionary:
	var kinds: Dictionary = {}
	for b: Dictionary in boxes:
		kinds[b["kind"]] = int(kinds.get(b["kind"], 0)) + 1
	return kinds


func _parts(boxes: Array[Dictionary]) -> Dictionary:
	var parts: Dictionary = {}
	for b: Dictionary in boxes:
		parts[b["part"]] = int(parts.get(b["part"], 0)) + 1
	return parts


## The first rolled look (from walker-like speeds) that passes `test`.
func _look_where(test: Callable) -> Dictionary:
	var s: float = 1.8
	while s < 60.0:
		var l: Dictionary = ZombieModel.roll_look(ZombieModel.seed_for(s))
		if test.call(l):
			return l
		s += 0.0137
	return {}


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
	var shirtless: Array[Dictionary] = _visible(3, 1)  # only the boxes every look shows
	_check(_kinds(shirtless).get(ZombieModel.Kind.FLESH, 0) >= 2 and _kinds(shirtless).get(ZombieModel.Kind.BONE, 0) >= 3,
		"shirtless: torn-open flank with ribs (on every shirtless zombie)")
	var gore: int = 0
	for v in ZombieModel.VARIANTS:
		for b: Dictionary in ZombieModel.boxes(v):
			if float(b["gore"]) >= 0.5:
				gore += 1
	_check(gore >= 8, "strong gore: %d heavy wound boxes across the variants" % gore)


## Rolled looks: deterministic, packed exactly, and varied across a horde.
func _test_looks() -> void:
	var a: Dictionary = ZombieModel.roll_look(123456789)
	var b: Dictionary = ZombieModel.roll_look(123456789)
	_check(a == b and ZombieModel.instance_look(2.1234) == ZombieModel.instance_look(2.1234),
		"roll_look / instance_look are deterministic (same seed, same zombie)")
	_check(ZombieModel.instance_look(2.1234).x == ZombieModel.variant_for(2.1234), "the look's variant is the old variant_for (same key)")
	# 150 Walkers as the horde rolls them.
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var outfits: Dictionary = {}
	var fields: Dictionary = {}
	var exact: bool = true
	var round_trip: bool = true
	for k in 150:
		var l: Dictionary = ZombieModel.roll_look(ZombieModel.seed_for(rng.randf_range(1.8, 2.6)))
		outfits[[l["variant"], l["colours"], l["mask"]]] = true
		for f: String in ["shirt", "trousers", "skin", "hair", "pattern", "missing", "build", "sleeves"]:
			if not fields.has(f):
				fields[f] = {}
			fields[f][l[f]] = true
		var c: int = l["colours"]
		var w: int = l["wear"]
		exact = exact and c < 1 << 24 and w < 1 << 24 and int(l["mask"]) < 1 << 24 and int(float(c)) == c
		# The shader's decoding (zombie.gdshader, vertex()).
		round_trip = round_trip and c & 31 == l["shirt"] and (c >> 5) & 15 == l["trousers"] and (c >> 9) & 7 == l["skin"] \
			and (c >> 12) & 7 == l["hair"] and (c >> 15) & 3 == l["pattern"] and (c >> 17) & 7 == l["pattern_color"] \
			and (c >> 20) & 3 == l["shoes"] and (c >> 22) & 3 == l["jacket"] and w & 7 == l["gore"] and (w >> 3) & 7 == l["blood"] \
			and (w >> 6) & 7 == l["torn"] and (w >> 9) & 7 == l["fade"] and (w >> 12) & 7 == l["build"] and (w >> 15) & 255 == l["offset"]
	_check(exact, "looks pack into integers below 2^24 (exact in the float32 instance colour)")
	_check(round_trip, "the shader's bit layout decodes every packed field back")
	_check(outfits.size() >= 145, "150 zombies: %d distinct outfits (variant + colours + optional parts)" % outfits.size())
	_check(fields["shirt"].size() >= 28 and fields["trousers"].size() == 16 and fields["skin"].size() == 8 and fields["hair"].size() == 8,
		"palettes in use: %d shirt colours, %d trousers, %d skin tones, %d hair (incl. bald)" % [fields["shirt"].size(), fields["trousers"].size(), fields["skin"].size(), fields["hair"].size()])
	_check(fields["pattern"].size() == 4 and fields["missing"].size() == 5 and fields["build"].size() == 8 and fields["sleeves"].size() == 3,
		"every pattern, missing part, build and sleeve cut shows up in a horde of 150")


## Optional boxes: alternatives show exactly one, missing parts are gone,
## and the skull never hides (headshots).
func _test_hiding() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var clean: bool = true
	var skull: bool = true
	for k in 600:
		var l: Dictionary = ZombieModel.roll_look(ZombieModel.seed_for(rng.randf_range(1.8, 2.6)))
		var shown: Array[Dictionary] = _visible(l["variant"], l["mask"])
		# Boxes sharing a centre and part are alternatives: exactly one shows.
		var groups: Dictionary = {}
		for bx: Dictionary in ZombieModel.boxes(l["variant"]):
			var key: String = "%s/%d" % [(bx["c"] as Vector3).snapped(Vector3.ONE * 0.001), bx["part"]]
			groups[key] = int(groups.get(key, 0)) + (1 << 8) + (1 if ZombieModel.shows(bx, l["mask"]) else 0)
		for key: String in groups:
			var total: int = groups[key] >> 8
			var on: int = groups[key] & 255
			# A missing left forearm hides both of its alternatives.
			var want: int = 0 if l["missing"] == ZombieModel.Missing.FOREARM and key.ends_with("/%d" % ZombieModel.Part.ARM_LOWER_L) else 1
			if total > 1 and on != want:
				if clean:
					print("  alternatives %s: %d of %d shown (variant %d, mask %d)" % [key, on, total, l["variant"], l["mask"]])
				clean = false
		var head: bool = false
		for bx: Dictionary in shown:
			if bx["part"] == ZombieModel.Part.HEAD and (bx["c"] as Vector3).is_equal_approx(ZombieModel.HEAD_CENTER):
				head = true
		skull = skull and head
	_check(clean, "600 looks: every pair of alternative boxes (sleeve/bare arm, trouser/bare shin) shows exactly one")
	_check(skull, "the skull box shows on every look (headshots unchanged)")
	var arm: Dictionary = _look_where(func(l: Dictionary) -> bool: return l["missing"] == ZombieModel.Missing.FOREARM)
	var parts: Dictionary = _parts(_visible(arm["variant"], arm["mask"]))
	_check(not parts.has(ZombieModel.Part.ARM_LOWER_L) and (arm["mask"] >> ZombieModel.Show.STUMP_L) & 1 == 1,
		"missing forearm: no left forearm/hand boxes, the stump shows (and the shader lets that arm hang)")
	var jaw: Dictionary = _look_where(func(l: Dictionary) -> bool: return l["missing"] == ZombieModel.Missing.JAW)
	var kinds: Dictionary = _kinds(_visible(jaw["variant"], jaw["mask"]))
	_check(not kinds.has(ZombieModel.Kind.MOUTH) and kinds.get(ZombieModel.Kind.FLESH, 0) >= 2, "missing jaw: no mouth slit, raw underside and tongue show")
	var whole: Dictionary = _look_where(func(l: Dictionary) -> bool: return l["missing"] == ZombieModel.Missing.NONE and l["variant"] == jaw["variant"])
	var ear: Dictionary = _look_where(func(l: Dictionary) -> bool: return l["missing"] == ZombieModel.Missing.EAR and l["variant"] == jaw["variant"])
	var fingers: Dictionary = _look_where(func(l: Dictionary) -> bool: return l["missing"] == ZombieModel.Missing.FINGERS and l["variant"] == jaw["variant"])
	var ear_kinds: Dictionary = _kinds(_visible(ear["variant"], ear["mask"]))
	var whole_kinds: Dictionary = _kinds(_visible(whole["variant"], whole["mask"]))
	var ear_box: bool = false
	for bx: Dictionary in _visible(ear["variant"], ear["mask"]):
		ear_box = ear_box or (bx["c"] as Vector3).is_equal_approx(Vector3(0.143, 1.79, 0.02))
	_check(not ear_box and ear_kinds.get(ZombieModel.Kind.FLESH, 0) == whole_kinds.get(ZombieModel.Kind.FLESH, 0) + 1,
		"missing ear: the left ear box swaps for a raw patch")
	var finger_kinds: Dictionary = _kinds(_visible(fingers["variant"], fingers["mask"]))
	_check(finger_kinds.get(ZombieModel.Kind.BONE, 0) == whole_kinds.get(ZombieModel.Kind.BONE, 0) + 2, "missing fingers: bloody stubs with bone")
	var bald: Dictionary = _look_where(func(l: Dictionary) -> bool: return l["hair"] == 0)
	var hairy: bool = false
	for bx: Dictionary in _visible(bald["variant"], bald["mask"]):
		hairy = hairy or bx["slot"] == ZombieModel.Slot.HAIR
	_check(not hairy, "bald zombies show no hair boxes")
	var hood: Dictionary = _look_where(func(l: Dictionary) -> bool: return l["hood"])
	var hood_boxes: int = 0
	for bx: Dictionary in _visible(hood["variant"], hood["mask"]):
		if bx["show_a"] == ZombieModel.Show.HOOD:
			hood_boxes += 1
	_check(hood["variant"] == 0 and hood["sleeves"] == ZombieModel.Sleeves.LONG and hood_boxes >= 3, "hoodies: hood, pocket and drawstrings, long sleeves")


## The shirtless flank is a cavity cut into the torso: nothing covers the
## opening, a dark lining (MOUTH kind) lines it and the ribs sit back inside.
## The hip stumps differ in length per variant, each with a bone tip.
func _test_cavity_and_stumps() -> void:
	var open_flank: bool = true
	var dark: int = 0
	var ribs_inside: bool = true
	var ribs: int = 0
	for b: Dictionary in _visible(3, 1):
		var c: Vector3 = b["c"]
		var s: Vector3 = b["s"]
		if b["part"] == ZombieModel.Part.TORSO and c.z > 0.0:
			var covers: bool = c.x - s.x * 0.5 <= -0.17 and c.x + s.x * 0.5 >= 0.09 and c.y - s.y * 0.5 <= 1.14 and c.y + s.y * 0.5 >= 1.34
			open_flank = open_flank and not covers
		if b["kind"] == ZombieModel.Kind.MOUTH:
			dark += 1
		if b["kind"] == ZombieModel.Kind.BONE and b["part"] == ZombieModel.Part.TORSO:
			ribs += 1
			ribs_inside = ribs_inside and c.z > 0.02 and c.z < 0.06 and c.y > 1.14 and c.y < 1.34
	_check(open_flank and dark >= 5 and ribs == 3 and ribs_inside,
		"shirtless flank: an open cavity (%d dark lining boxes), three ribs set back inside it" % dark)
	var lengths: Array[float] = []
	var tips: bool = true
	for v in ZombieModel.VARIANTS:
		var flesh: Dictionary = {}
		var tip: Dictionary = {}
		for b: Dictionary in ZombieModel.boxes(v):
			if b["show_a"] != ZombieModel.Show.LEGLESS or (b["c"] as Vector3).x <= 0.0:
				continue
			if b["kind"] == ZombieModel.Kind.FLESH:
				flesh = b
			elif b["kind"] == ZombieModel.Kind.BONE:
				tip = b
		if flesh.is_empty() or tip.is_empty():
			tips = false
			continue
		lengths.append((flesh["s"] as Vector3).y)
		var flesh_end: float = (flesh["c"] as Vector3).y - (flesh["s"] as Vector3).y * 0.5
		tips = tips and (tip["c"] as Vector3).y - (tip["s"] as Vector3).y * 0.5 < flesh_end - 0.02
	var distinct: Dictionary = {}
	for l: float in lengths:
		distinct[snappedf(l, 0.001)] = true
	_check(tips and lengths.size() == ZombieModel.VARIANTS and distinct.size() == ZombieModel.VARIANTS,
		"hip stumps: %d different lengths (%s m) per variant, each with a bone tip past the flesh" % [distinct.size(), lengths])


func _test_head() -> void:
	var walker: GameData.EnemyType = GameData.enemy_types()[GameData.EnemyKind.WALKER]
	var skull: Dictionary = {}
	for b: Dictionary in ZombieModel.boxes(0):
		if skull.is_empty() and b["part"] == ZombieModel.Part.HEAD and (b["s"] as Vector3).y > 0.2:
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
	_check(total == 150 and view.handles(GameData.EnemyKind.WALKER)
		and view.instance_count(ZombieHordeView.variant_for(GameData.EnemyKind.BRUTE, 0.0)) == 10,
		"150 walkers and 10 brutes use their own model batches")
	var v0: int = ZombieModel.variant_for(h.speeds[0])
	var first: PackedFloat32Array = _instance(view, v0, 0)
	var p: Vector3 = h.positions[0]
	_check(is_equal_approx(first[3], p.x) and is_equal_approx(first[11], p.z) and is_equal_approx(first[5], 1.0),
		"instance transform: on the enemy's position, Walker height scale 1")
	_check(first[2] > 0.0 or is_equal_approx(first[10], 1.0), "walking +Z faces +Z (the model's front)")
	_check(first[17] > 0.7 and first[19] == 0.0, "walking: walk amount %.2f, no flinch" % first[17])
	var look0: Vector4 = ZombieModel.instance_look(h.speeds[0])
	_check(first[12] == ZombieModel.Status.NONE and first[13] == look0.y and first[14] == look0.z and first[15] == look0.w,
		"instance colour = (status, mask, colours, wear) of the zombie's rolled look")
	# Hit flash -> flinch; stun -> stagger; a blow on its way -> the lean-in (lunge channel).
	h.flash[0] = 0.1
	view.draw(h, map, 1.1, 0.016)
	_check(_instance(view, v0, 0)[19] > 0.9 and _instance(view, v0, 0)[12] == ZombieModel.Status.FLASH, "a hit flinches the zombie and flashes it")
	h.flash[0] = 0.0
	h.stun[0] = 1.0
	view.draw(h, map, 1.2, 0.016)
	_check(_instance(view, v0, 0)[18] < 0.0, "stunned zombies stagger")
	h.stun[0] = 0.0
	h.positions[0] = h.target + Vector3(0, 0, -1.0)
	h.velocities[0] = Vector3.ZERO
	h.windup[0] = Horde.ATTACK_WINDUP * 0.2  # 80 % of the wind-up has run: the lean-in is near its peak
	view.draw(h, map, 1.3, 0.016)
	_check(_instance(view, v0, 0)[18] > 0.5, "a zombie winding up its blow leans in")
	h.freeze_time[0] = 2.0
	view.draw(h, map, 1.4, 0.016)
	var frozen: PackedFloat32Array = _instance(view, v0, 0)
	_check(frozen[17] == 0.0 and frozen[12] == ZombieModel.Status.FROZEN and frozen[13] == look0.y, "frozen zombies stop and turn icy (and keep their look)")
	h.freeze_time[0] = 0.0
	# Compaction: removing zombie 1 moves the last one into its slot; the
	# moved zombie keeps its look (it travels with its base speed). The
	# brutes were added last: drop them so the last enemy is a walker.
	while h.kinds[h.count - 1] != GameData.EnemyKind.WALKER:
		h.remove(h.count - 1)
	var last_speed: float = h.speeds[h.count - 1]
	var last_look: Vector4 = ZombieModel.instance_look(last_speed)
	h.remove(1)
	view.draw(h, map, 1.45, 0.016)
	var kept: bool = false
	var lv: int = int(last_look.x)
	for i in view.instance_count(lv):
		var inst: PackedFloat32Array = _instance(view, lv, i)
		if is_equal_approx(inst[3], h.positions[1].x) and is_equal_approx(inst[11], h.positions[1].z):
			kept = inst[13] == last_look.y and inst[14] == last_look.z and inst[15] == last_look.w
	_check(h.speeds[1] == last_speed and kept, "a zombie moved by horde compaction keeps its outfit")
	# Death: the zombie leaves the horde, its corpse keeps its variant and look and falls.
	var dead: Vector3 = h.positions[5]
	var dead_key: float = h.speeds[5]  # the seed IslandRun.death_keys records for this death
	var dead_variant: int = ZombieModel.variant_for(dead_key)
	var dead_look: Vector4 = ZombieModel.instance_look(dead_key)
	view.draw(h, map, 1.5, 0.016)
	h.remove(5)
	view.draw(h, map, 1.52, 0.016)
	var before: int = view.instance_count(dead_variant)
	view.on_death(Vector4(dead.x, dead.z, GameData.EnemyKind.WALKER, 1.0), dead, dead + Vector3(0, 0, 5), dead_key)
	view.on_death(Vector4(50, 50, GameData.EnemyKind.BRUTE, 0.0), Vector3(50, 0, 50), Vector3.ZERO, 0.0)
	view.draw(h, map, 1.54, 0.5)
	_check(view.corpse_count() == 2 and view.instance_count(dead_variant) == before + 1
		and view.instance_count(ZombieHordeView.variant_for(GameData.EnemyKind.BRUTE, 0.0)) == 1,
		"Dead walker and brute each retain their own model as a corpse")
	var corpse: PackedFloat32Array = _instance(view, dead_variant, view.instance_count(dead_variant) - 1)
	_check(corpse[19] >= 4.0 and corpse[19] <= 5.0, "headshot corpse falls without its head (state %.2f)" % corpse[19])
	_check(corpse[13] == dead_look.y and corpse[14] == dead_look.z and corpse[15] == dead_look.w, "the corpse wears the dead zombie's outfit")
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
