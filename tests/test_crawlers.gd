extends SceneTree
## Crawlers and leg loss (added 2026-10-17). A grenade's uniform damage is
## applied first; a walker that survives it (real HP) may lose both legs,
## rolled once, keeping its remaining HP. It becomes a Crawler: it topples for
## GameData.CRAWL_TRANSITION_TIME, then crawls at 40 % of the walker's speed
## with the walker's HP, reach and damage. Only walkers convert; bullets, the
## breaker, Grabbers and Bloaters never do. The director spawns Crawlers from
## the second island on (never on a boss island, never from nests), within the
## 150 alive cap. The legless state survives horde compaction, the model builds
## headless, the crawl pose lies low and hides the legs, the aim follows the
## posed model, and a leg loss queues its debris for the island scene.
## Run: godot --headless --path . --script res://tests/test_crawlers.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


## The island scene saves its profile on exit: keep the test off the disk.
class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_test_leg_loss_rules()
	_test_crawl_speed_and_reach()
	_test_topple_and_compaction()
	_test_knockback_is_the_same()
	_test_spawn_rules()
	_test_legless_survives_compaction()
	_test_model_and_pose()
	_test_posed_aim()
	await _test_debris()
	_test_timing()
	quit(1 if _failures > 0 else 0)


## Walkers (or other kinds) on a ring of radius `r` around `centre`, at real HP.
func _ring(run: IslandRun, centre: Vector3, r: float, count: int, kind: int) -> Array[int]:
	var out: Array[int] = []
	for k in count:
		var a: float = k * TAU / count
		out.append(run.horde.add(centre + Vector3(cos(a), 0, sin(a)) * r, kind, run.rng))
	return out


## Survivors of a blast, with real HP: a walker hit for 25 of its 30 HP keeps 5.
## (The grenade's own 90 damage kills every walker in reach, so a real survivor
## is made with a smaller hit; the roll itself is the same.)
func _survivors(run: IslandRun, ids: Array[int], centre: Vector3) -> void:
	for i in ids:
		run._damage(i, 25.0, centre, false, true)


func _test_leg_loss_rules() -> void:
	var radius: float = 5.0
	_check(is_equal_approx(IslandRun.leg_loss_chance(0.0, radius), GameData.LEG_LOSS_CHANCE)
		and is_equal_approx(IslandRun.leg_loss_chance(2.5, radius), GameData.LEG_LOSS_CHANCE * 0.5)
		and IslandRun.leg_loss_chance(radius, radius) == 0.0 and IslandRun.leg_loss_chance(radius + 1.0, radius) == 0.0,
		"leg loss chance: 75 % at the centre, half at mid radius, 0 at the edge and beyond")
	# Bullets and the breaker never take legs.
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	var at: Vector3 = run.player_pos + Vector3(0, 0, 6)
	var shot: int = run.horde.add(at, GameData.EnemyKind.WALKER, run.rng)
	run._damage(shot, 5.0, run.player_pos, false, false)
	var breaker: int = run.horde.add(at + Vector3(2, 0, 0), GameData.EnemyKind.WALKER, run.rng)
	run._damage(breaker, 5.0, run.player_pos, false, true)
	_check(run.horde.kinds[shot] == GameData.EnemyKind.WALKER and run.horde.kinds[breaker] == GameData.EnemyKind.WALKER
		and run.leg_losses.is_empty(), "bullets and the breaker never take a walker's legs")
	# The real grenade: uniform 90 damage kills walkers (30 HP) inside the
	# radius, so no leg is lost; nothing outside is touched.
	var blast_run := IslandRun.new(7)
	blast_run.director.max_alive = 0
	var centre: Vector3 = blast_run.player_pos + Vector3(0, 0, 6)
	var blast_radius: float = blast_run.grenade_radius()
	var inside: Array[int] = _ring(blast_run, centre, 0.5, 30, GameData.EnemyKind.WALKER)
	var outside: Array[int] = _ring(blast_run, centre, blast_radius + 0.5, 30, GameData.EnemyKind.WALKER)
	blast_run.grenades.append(centre)
	blast_run.grenade_fuses.append(0.0)
	blast_run._update_grenades(DT)
	var dead: int = 0
	for i in inside:
		if blast_run.horde.kinds[i] == GameData.EnemyKind.WALKER and blast_run.horde.hp[i] <= 0.0:
			dead += 1
	var outside_kept: bool = outside.all(func(i: int) -> bool: return blast_run.horde.kinds[i] == GameData.EnemyKind.WALKER \
		and blast_run.horde.hp[i] == blast_run.horde.types[GameData.EnemyKind.WALKER].hp)
	_check(blast_run.leg_losses.is_empty() and outside_kept,
		"a grenade's 90 damage kills walkers in reach outright (%d of 30 died), so no legs come off; outside is untouched" % dead)
	# Survivors (real HP left after a 25 hit): about 67 % lose their legs at
	# 0.5 m (0.75 x (1 - 0.5 / 5)); converted walkers keep their HP.
	var first: Dictionary = _roll_survivors(2026)
	var near: int = first["near"]
	_check(near >= 30 and near <= 52, "a surviving walker 0.5 m from the blast loses its legs about 67 %% of the time (%d of 60)" % near)
	_check(first["far"] == 0, "walkers outside the blast radius keep their legs")
	_check(first["events"] == near and first["hp_kept"], "one leg-loss event per converted walker, and its HP is kept (%d)" % first["events"])
	_check(_roll_survivors(2026)["near"] == near, "the leg roll is deterministic for a given seed")
	# Only walkers convert: a surviving Grabber, Bloater or Runner keeps its legs.
	var mixed := IslandRun.new(7)
	mixed.director.max_alive = 0
	mixed.limb_rng.seed = 3
	var at_c: Vector3 = mixed.player_pos + Vector3(0, 0, 6)
	var others: Array[int] = [GameData.EnemyKind.GRABBER, GameData.EnemyKind.BLOATER, GameData.EnemyKind.RUNNER, GameData.EnemyKind.CRAWLER]
	var ids: Array[int] = []
	for k in others:
		var i: int = mixed.horde.add(at_c + Vector3(0.3, 0, 0), k, mixed.rng)
		ids.append(i)
		mixed.horde.hp[i] = 500.0
		mixed._roll_leg_loss(i, at_c, blast_radius)
	_check(mixed.leg_losses.is_empty() and mixed.horde.kinds[ids[0]] == GameData.EnemyKind.GRABBER
		and mixed.horde.kinds[ids[1]] == GameData.EnemyKind.BLOATER and mixed.horde.kinds[ids[2]] == GameData.EnemyKind.RUNNER,
		"Grabbers, Bloaters and Runners never lose their legs")


## Survivors on a ring at 0.5 m and at the far edge; rolls each once.
func _roll_survivors(limb_seed: int) -> Dictionary:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	var centre: Vector3 = run.player_pos + Vector3(0, 0, 6)
	var radius: float = run.grenade_radius()
	var near: Array[int] = _ring(run, centre, 0.5, 60, GameData.EnemyKind.WALKER)
	var far: Array[int] = _ring(run, centre, radius + 0.5, 60, GameData.EnemyKind.WALKER)
	_survivors(run, near, centre)
	_survivors(run, far, centre)
	run.limb_rng.seed = limb_seed
	for i in near:
		run._roll_leg_loss(i, centre, radius)
	for i in far:
		run._roll_leg_loss(i, centre, radius)
	var far_changed: int = 0
	for i in far:
		if run.horde.kinds[i] != GameData.EnemyKind.WALKER:
			far_changed += 1
	var near_changed: int = 0
	var hp_kept: bool = true
	for i in near:
		if run.horde.kinds[i] == GameData.EnemyKind.CRAWLER:
			near_changed += 1
			hp_kept = hp_kept and run.horde.hp[i] == 5.0
	var events: int = run.leg_losses.size()
	for i in near:
		if run.horde.kinds[i] == GameData.EnemyKind.CRAWLER:
			run._roll_leg_loss(i, centre, radius)  # a converted Crawler is not rolled again
	return {"near": near_changed, "far": far_changed, "events": events,
		"hp_kept": hp_kept and run.leg_losses.size() == events}


func _test_crawl_speed_and_reach() -> void:
	_check(is_equal_approx(GameData.CRAWL_SPEED_RATIO, 0.4), "Crawler speed ratio is 40 % of the walker's")
	var h := Horde.new(FlowField.new(60, 60))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var walker: int = h.add(Vector3(10, 0, 10), GameData.EnemyKind.WALKER, rng)
	var crawler: int = h.add(Vector3(20, 0, 10), GameData.EnemyKind.CRAWLER, rng)
	h.speeds[crawler] = h.speeds[walker]  # same rolled speed, so only the crawl differs
	h.set_target(Vector3(15, 0, 55))
	for f in 240:
		h.tick(DT)
	var walk_speed: float = h.velocities[walker].length()
	var crawl_speed: float = h.velocities[crawler].length()
	var ratio: float = crawl_speed / maxf(walk_speed, 0.0001)
	_check(walk_speed > 0.5 and absf(ratio - 0.4) < 0.02 and is_equal_approx(h.speed_multiplier(crawler), 0.4),
		"a Crawler walks at 40 %% of the walker's speed (%.2f vs %.2f m/s)" % [crawl_speed, walk_speed])
	# Reach and damage are the walker's: a Crawler hits from the same distance.
	var target := Vector3(30, 0, 30)
	var reach: float = GameData.ATTACK_REACH + GameData.PLAYER_RADIUS
	var near_h := Horde.new(FlowField.new(60, 60))
	var c_near: int = near_h.add(target + Vector3(reach - 0.3, 0, 0), GameData.EnemyKind.CRAWLER, rng)
	near_h.set_target(target)
	near_h.attack_cd[c_near] = 0.0
	near_h.tick(DT)
	var far_h := Horde.new(FlowField.new(60, 60))
	var c_far: int = far_h.add(target + Vector3(reach + 1.0, 0, 0), GameData.EnemyKind.CRAWLER, rng)
	far_h.set_target(target)
	far_h.attack_cd[c_far] = 0.0
	far_h.tick(DT)
	var types: Array[GameData.EnemyType] = GameData.enemy_types()
	var crawler_type: GameData.EnemyType = types[GameData.EnemyKind.CRAWLER]
	var walker_type: GameData.EnemyType = types[GameData.EnemyKind.WALKER]
	_check(is_equal_approx(near_h.damage_to_player, walker_type.damage) and far_h.damage_to_player == 0.0,
		"a Crawler hits in the walker's reach for the walker's damage (%.1f)" % near_h.damage_to_player)
	_check(is_equal_approx(crawler_type.attack_interval, walker_type.attack_interval) and is_equal_approx(crawler_type.damage, walker_type.damage)
		and crawler_type.hp == walker_type.hp and crawler_type.xp == walker_type.xp,
		"Crawler data keeps the walker's HP, damage, attack interval and XP")


## After its legs go a Crawler topples for the transition time (no steps, no
## attacks), then crawls; the timer moves with the enemy on compaction.
func _test_topple_and_compaction() -> void:
	var h := Horde.new(FlowField.new(60, 60))
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var i: int = h.add(Vector3(10, 0, 10), GameData.EnemyKind.WALKER, rng)
	var hp_before: float = h.hp[i]
	h.amputate(i)
	_check(h.kinds[i] == GameData.EnemyKind.CRAWLER and h.hp[i] == hp_before
		and is_equal_approx(h.crawl_delay[i], GameData.CRAWL_TRANSITION_TIME),
		"amputation makes a Crawler that keeps its HP and topples for %.1f s" % GameData.CRAWL_TRANSITION_TIME)
	h.set_target(Vector3(15, 0, 55))
	var start := Vector3(10, 0, 10)
	for f in 20:  # about 0.33 s: still toppling
		h.tick(DT)
	_check(h.positions[i].distance_to(start) < 0.001 and h.crawl_delay[i] > 0.0, "a toppling Crawler stands still")
	for f in 30:
		h.tick(DT)
	_check(h.crawl_delay[i] == 0.0 and h.positions[i].distance_to(start) > 0.05, "then it crawls off")
	var g := Horde.new(FlowField.new(60, 60))
	for k in 3:
		g.add(Vector3(10 + k, 0, 10), GameData.EnemyKind.WALKER, rng)
	g.amputate(2)
	g.remove(0)  # the last enemy (the Crawler) moves into slot 0
	_check(g.kinds[0] == GameData.EnemyKind.CRAWLER and is_equal_approx(g.crawl_delay[0], GameData.CRAWL_TRANSITION_TIME)
		and g.crawl_delay[1] == 0.0, "the topple timer moves with its Crawler on removal")


func _test_knockback_is_the_same() -> void:
	var h := Horde.new(FlowField.new(60, 60))
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var walker: int = h.add(Vector3(20, 0, 20), GameData.EnemyKind.WALKER, rng)
	var crawler: int = h.add(Vector3(30, 0, 20), GameData.EnemyKind.CRAWLER, rng)
	h.knock_back(walker, Vector3(22, 0, 20), 2.0)
	h.knock_back(crawler, Vector3(32, 0, 20), 2.0)
	var moved_walker: float = h.positions[walker].distance_to(Vector3(20, 0, 20))
	var moved_crawler: float = h.positions[crawler].distance_to(Vector3(30, 0, 20))
	_check(moved_crawler > 1.5 and absf(moved_walker - moved_crawler) < 0.001,
		"a Crawler is knocked back exactly like a walker (%.2f m)" % moved_crawler)


func _crawler_picks(director: Director, n: int) -> int:
	var picks: int = 0
	for k in n:
		if director.pick_kind() == GameData.EnemyKind.CRAWLER:
			picks += 1
	return picks


func _test_spawn_rules() -> void:
	var ctx := RunContext.new(5)
	ctx.island_index = 0
	var first := IslandRun.new(ctx.island_seed())
	first.load_context(ctx)
	_check(first.director.crawler_share == 0.0 and _crawler_picks(first.director, 20000) == 0,
		"the first island spawns no Crawlers")
	ctx.island_index = 1
	var second := IslandRun.new(ctx.island_seed())
	second.load_context(ctx)
	var fraction: float = float(_crawler_picks(second.director, 20000)) / 20000.0
	_check(not second.has_boss and absf(fraction - GameData.CRAWLER_SPAWN_SHARE / 100.0) < 0.01,
		"from the second island Crawlers are about %.0f %% of spawns (%.1f %%)" % [GameData.CRAWLER_SPAWN_SHARE, fraction * 100.0])
	ctx.island_index = RunContext.ISLAND_COUNT - 1
	ctx.mission = &"activate"
	var boss := IslandRun.new(ctx.island_seed())
	boss.load_context(ctx)
	_check(boss.has_boss and boss.director.crawler_share == 0.0 and _crawler_picks(boss.director, 20000) == 0,
		"the boss island spawns no Crawlers")
	second.objective = IslandRun.Objective.BOSS
	_check(second._crawler_share() == 0.0, "no Crawlers once the boss fight starts")
	second.objective = IslandRun.Objective.GENERATORS
	# Nests call pick_kind(false): they never produce a Crawler, even at 100 %.
	second.director.crawler_share = 100.0
	var nest_crawlers: int = 0
	for k in 200:
		if second.director.pick_kind(false) == GameData.EnemyKind.CRAWLER:
			nest_crawlers += 1
	_check(nest_crawlers == 0 and second.director.pick_kind() == GameData.EnemyKind.CRAWLER,
		"nests spawn no Crawlers (pick_kind(false)); the horde director does")
	# The alive cap holds: fill to 140, then ask for spawns with Crawlers only.
	second.director.max_alive = GameData.MAX_ALIVE
	for k in GameData.MAX_ALIVE - 10:
		second.horde.add(second.player_pos + Vector3(cos(k), 0, sin(k)) * 0.2, GameData.EnemyKind.WALKER, second.rng)
	for k in 40:
		second._spawn_enemy()
	var crawlers: int = 0
	for i in second.horde.count:
		if second.horde.kinds[i] == GameData.EnemyKind.CRAWLER:
			crawlers += 1
	_check(second.horde.count == GameData.MAX_ALIVE and crawlers == GameData.MAX_ALIVE - (GameData.MAX_ALIVE - 10),
		"Crawler spawns stop at the 150 alive cap (%d alive, %d Crawlers)" % [second.horde.count, crawlers])


func _test_legless_survives_compaction() -> void:
	var h := Horde.new(FlowField.new(40, 20))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var kind_of: Dictionary = {}
	var speed_of: Dictionary = {}
	for k in 12:
		var x: float = 2.0 + k
		var kind: int = GameData.EnemyKind.CRAWLER if k % 3 == 0 else GameData.EnemyKind.WALKER
		var i: int = h.add(Vector3(x, 0, 5), kind, rng)
		kind_of[x] = kind
		speed_of[x] = h.speeds[i]
	# Turn one walker into a Crawler in place, then remove from the front: each
	# removal moves the last enemy into the gap.
	h.amputate(1)
	kind_of[h.positions[1].x] = GameData.EnemyKind.CRAWLER
	for i in 5:
		h.remove(0)
	var kept: bool = h.count == 7
	for i in h.count:
		var x: float = h.positions[i].x
		kept = kept and kind_of.has(x) and h.kinds[i] == kind_of[x] and is_equal_approx(h.speeds[i], speed_of[x])
	_check(kept, "a Crawler keeps its legless state, and its outfit key, when the horde compacts")


func _test_model_and_pose() -> void:
	var built: bool = true
	for v in ZombieModel.VARIANTS:
		var m: ArrayMesh = ZombieModel.mesh(v)
		built = built and m != null and m.get_surface_count() > 0
	_check(built, "the four common zombie models build headless (Crawlers use them)")
	var boxes: Array[Dictionary] = ZombieModel.boxes(0)
	var normal: int = ZombieModel.roll_look(ZombieModel.seed_for(2.2))["mask"]
	var legless: int = ZombieModel.legless_mask(normal)
	var legs_on: int = 0
	var legs_off: int = 0
	var stumps_legless: int = 0
	var stumps_normal: int = 0
	var stump_parts_ok: bool = true
	var stump_flaps: int = 0
	for b: Dictionary in boxes:
		var part: int = b["part"]
		if part >= ZombieModel.Part.LEG_UPPER_L and part <= ZombieModel.Part.LEG_LOWER_R:
			if ZombieModel.shows(b, normal):
				legs_on += 1
			if ZombieModel.shows(b, legless):
				legs_off += 1
		if b["show_a"] == ZombieModel.Show.LEGLESS:
			stump_parts_ok = stump_parts_ok and part == ZombieModel.Part.PELVIS
			if b["kind"] == ZombieModel.Kind.FLESH or b["kind"] == ZombieModel.Kind.BONE:
				if ZombieModel.shows(b, legless):
					stumps_legless += 1
				if ZombieModel.shows(b, normal):
					stumps_normal += 1
			elif b["slot"] == ZombieModel.Slot.TROUSERS and ZombieModel.shows(b, legless):
				stump_flaps += 1
	_check(legs_on >= 4 and legs_off == 0, "the legless pose hides the legs (walker shows %d leg boxes, Crawler %d)" % [legs_on, legs_off])
	_check(stumps_legless == 4 and stumps_normal == 0 and stump_parts_ok and stump_flaps == 4,
		"a Crawler shows its two hip stumps (flesh and bone tip) and four blood-soaked trouser flaps; a walker none")
	_check(ZombieModel.is_legless(legless) and not ZombieModel.is_legless(normal) and ZombieModel.legless_mask(legless) == legless,
		"legless_mask sets the Crawler bit and only that")
	var pose: Dictionary = ZombieModel.crawl_points(0.0)
	var head: Vector3 = pose["head"]
	var hand: Vector3 = pose["hand"]
	var torso_low: float = pose["torso_low"]
	var stump: Vector3 = pose["stump"]
	_check(head.y > 0.55 and head.y < 0.85 and absf(hand.y - ZombieModel.CRAWL_HAND_Y) < 0.005 and torso_low > 0.1 and torso_low < 0.35 and stump.z < 0.0,
		"crawl pose: head %.2f m, hand %.3f m, torso %.2f m off the ground, stumps behind" % [head.y, hand.y, torso_low])
	# Planted: through the stance (the first half of the cycle) the hand stays
	# on the ground and moves back in the body's frame by exactly the distance
	# the body travels, so it does not slide.
	var planted: bool = true
	var stance_steps: int = 20
	for k in stance_steps:
		var f: float = float(k) / float(stance_steps) * ZombieModel.CRAWL_STANCE * 0.99
		var a: Vector3 = ZombieModel.crawl_points(f)["hand"]
		var b: Vector3 = ZombieModel.crawl_points(f + 0.01)["hand"]
		planted = planted and absf(a.y - ZombieModel.CRAWL_HAND_Y) < 0.002 and absf(b.y - ZombieModel.CRAWL_HAND_Y) < 0.002
		planted = planted and absf((a.z - b.z) - 0.01 * ZombieModel.CRAWL_STRIDE) < 0.002
	_check(planted, "the planted hand stays on the ground through its stance and moves back %.2f m per stride" % ZombieModel.CRAWL_STRIDE)
	# Recovery: the hand lifts off the ground, comes forward and lands at the start.
	var top: float = 0.0
	var front: float = -INF
	var back_z: float = INF
	for k in 21:
		var f: float = ZombieModel.CRAWL_STANCE + (1.0 - ZombieModel.CRAWL_STANCE) * float(k) / 20.0
		var r: Vector3 = ZombieModel.crawl_points(f)["hand"]
		top = maxf(top, r.y)
		back_z = minf(back_z, r.z)
		front = maxf(front, r.z)
	var landed: Vector3 = ZombieModel.crawl_points(1.0)["hand"]
	var start: Vector3 = ZombieModel.crawl_points(0.0)["hand"]
	_check(top > ZombieModel.CRAWL_HAND_Y + 0.07 and top < ZombieModel.CRAWL_HAND_Y + ZombieModel.CRAWL_LIFT + 0.01
		and landed.distance_to(start) < 0.001 and front > back_z + 0.5 * ZombieModel.CRAWL_STRIDE * ZombieModel.CRAWL_STANCE,
		"recovery: the hand lifts %.2f m and comes forward %.2f m, back to its start" % [top - ZombieModel.CRAWL_HAND_Y, front - back_z])
	# The arm's phase runs at the crawl speed over one stride: the body's
	# travel per second equals the hand's stance speed, so the planting holds.
	var speed: float = 2.2 * GameData.CRAWL_SPEED_RATIO
	var rate: float = ZombieModel.crawl_phase_rate(2.2)
	_check(absf(rate * ZombieModel.CRAWL_STRIDE / TAU - speed) < 0.0001,
		"the crawl phase rate (%.2f rad/s) matches the crawl speed (%.2f m/s) over one stride" % [rate, speed])
	var dt: float = 0.02
	var moved: float = ZombieModel.crawl_points(0.1)["hand"].z - ZombieModel.crawl_points(0.1 + rate * dt / TAU)["hand"].z
	_check(absf(moved - speed * dt) < 0.002,
		"in %.2f s the Crawler moves %.1f mm and its planted hand moves back %.1f mm (same)" % [dt, speed * dt * 1000.0, moved * 1000.0])
	_check(ZombieModel.crawl_stroke(0.25).y == 0.0 and ZombieModel.crawl_stroke(0.75).y > 0.0 and ZombieModel.crawl_stroke(1.0).x == ZombieModel.crawl_stroke(0.0).x,
		"crawl_stroke: stance on the ground, recovery lifted, the cycle wraps")


## Aim follows the posed model (not the standing height): the head and chest
## points used for headshots and body hits are the crawl pose's.
func _test_posed_aim() -> void:
	var pose: Dictionary = ZombieModel.crawl_points(0.0)
	_check(absf(float(pose["head"].y) - ZombieModel.CRAWL_HEAD_HEIGHT) < 0.005
		and absf(float(pose["torso"].y) - ZombieModel.CRAWL_CHEST_HEIGHT) < 0.005,
		"the aim constants match the posed model (head %.3f m, chest %.3f m)" % [pose["head"].y, pose["torso"].y])
	var run := IslandRun.new(7)
	var i: int = run.horde.add(run.player_pos + Vector3(0, 0, 6), GameData.EnemyKind.CRAWLER, run.rng)
	var base: float = run.map.ground_y(run.horde.positions[i])
	_check(absf(run.enemy_head(i).y - base - ZombieModel.CRAWL_HEAD_HEIGHT) < 0.001
		and absf(run.enemy_chest(i).y - base - ZombieModel.CRAWL_CHEST_HEIGHT) < 0.001,
		"a Crawler's head and chest are aimed where the posed model draws them")


## A leg loss queues two leg chunks for the island scene (flesh colour).
func _test_debris() -> void:
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	root.add_child(island)
	for i in 4:
		await process_frame
	island.set("paused", true)
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	var blast_at: Vector3 = run.player_pos + Vector3(0, 0, 6)
	var walkers: Array[int] = _ring(run, blast_at, 0.5, 30, GameData.EnemyKind.WALKER)
	_survivors(run, walkers, blast_at)
	run.limb_rng.seed = 7
	for i in walkers:
		run._roll_leg_loss(i, blast_at, run.grenade_radius())
	var events: int = run.leg_losses.size()
	var before: int = (island.get("_debris_pos") as PackedVector3Array).size()
	island.call("_draw_effects", DT)
	var added: int = (island.get("_debris_pos") as PackedVector3Array).size() - before
	var colours: PackedColorArray = island.get("_debris_color")
	_check(events > 0 and added >= 2 * events and run.leg_losses.is_empty() and colours.has(ZombieHordeView.DEBRIS_COLOR),
		"a leg loss flies two leg chunks off in flesh colour (%d events, %d chunks)" % [events, added])
	island.free()


func _horde_of(kind: int, count: int, map: IslandMap) -> Horde:
	var h := Horde.new(map.field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 150
	for k in count:
		h.add(Vector3(10 + rng.randf_range(0.0, 40.0), 0, 10 + rng.randf_range(0.0, 40.0)), kind, rng)
	h.target = Vector3(32, 0, 32)
	return h


func _draw_ms(view: ZombieHordeView, h: Horde, map: IslandMap) -> float:
	view.draw(h, map, 0.0, 0.016)
	var frames: int = 300
	var t0: int = Time.get_ticks_usec()
	for f in frames:
		view.draw(h, map, f / 60.0, DT)
	return (Time.get_ticks_usec() - t0) / 1000.0 / frames


## CPU time of ZombieHordeView.draw, headless (no GPU here: not a frame-cost
## measurement of the game). Crawlers reuse the walker MultiMeshes.
func _test_timing() -> void:
	var map := IslandMap.new()
	map.field = FlowField.new(64, 64)
	var view := ZombieHordeView.new()
	root.add_child(view)
	var walkers_ms: float = _draw_ms(view, _horde_of(GameData.EnemyKind.WALKER, 150, map), map)
	var crawlers_ms: float = _draw_ms(view, _horde_of(GameData.EnemyKind.CRAWLER, 150, map), map)
	print("PERF: 150 walkers %.3f ms/frame, 150 Crawlers %.3f ms/frame (CPU, headless; not a GPU measurement)"
		% [walkers_ms, crawlers_ms])
	_check(crawlers_ms < 3.0, "150 Crawlers draw in %.3f ms per frame on the CPU (headless; budget 3 ms)" % crawlers_ms)
	_check(crawlers_ms < walkers_ms * 1.5 + 0.05, "Crawlers cost about the same CPU time as walkers (%.3f vs %.3f ms)" % [crawlers_ms, walkers_ms])
	view.free()
