class_name IslandRun
extends RefCounted
## All gameplay rules of one island, without nodes: player, auto-fire,
## breaker, horde, director, XP/cards and the "Activate 3" mission.
## The Island scene feeds input into step() and draws the resulting state,
## so the whole game loop can also run headless in tests.

enum Objective { GENERATORS, RETURN_TO_BOAT, WON, LOST }

var map: IslandMap
var field: FlowField
var horde: Horde
var director: Director
var rng := RandomNumberGenerator.new()

# Player
var player_pos: Vector3
var facing: Vector3 = Vector3(0, 0, -1)
var hp: float = GameData.PLAYER_MAX_HP
var level: int = 1
var xp: int = 0
var breaker_cd: float = 0.0
var dash_time: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var invulnerable: float = 0.0

# Weapons
var weapons: Array[GameData.Weapon] = GameData.weapons()
var weapon_index: int = 0
var ammo: PackedInt32Array = PackedInt32Array()
var _fire_cd: float = 0.0
var _shots: int = 0

# Cards
var all_cards: Array[GameData.Card] = GameData.cards()
var card_stacks: Dictionary = {}  ## StringName -> int
var card_choices: Array[GameData.Card] = []
var _pending_levels: int = 0

# Pickups
var orbs: PackedVector3Array = PackedVector3Array()
var orb_values: PackedInt32Array = PackedInt32Array()

# Mission
var objective: Objective = Objective.GENERATORS
var generator_progress: PackedFloat32Array = PackedFloat32Array()
var generator_started: Array[bool] = []

# Stats
var kills: int = 0
var headshots: int = 0
var time_alive: float = 0.0

# Render events, consumed (cleared) by the scene every frame.
var tracers: Array[PackedVector3Array] = []
var deaths: Array[Vector4] = []  ## (x, z, kind, headshot 0/1)
var explosions: PackedVector3Array = PackedVector3Array()
var messages: PackedStringArray = PackedStringArray()

var _kills_at_start: int = 0
var _dead: Dictionary = {}  ## enemy index -> true, removed at the end of step()


func _init(rng_seed: int = 7) -> void:
	rng.seed = rng_seed
	map = IslandMap.build(rng_seed)
	field = map.field
	horde = Horde.new(field)
	director = Director.new(rng_seed)
	player_pos = map.player_start
	field.compute_now(field.world_to_cell(player_pos))
	horde.set_target(player_pos)
	for w in weapons:
		ammo.append(w.max_ammo)
	for i in GameData.GENERATOR_COUNT:
		generator_progress.append(0.0)
		generator_started.append(false)


## Loads the run state carried from previous islands and scales difficulty.
func load_context(ctx: RunContext) -> void:
	hp = ctx.hp
	level = ctx.level
	xp = ctx.xp
	card_stacks = ctx.card_stacks.duplicate()
	if ctx.ammo.size() == ammo.size():
		ammo = ctx.ammo.duplicate()
	kills = ctx.kills
	_kills_at_start = kills
	headshots = ctx.headshots
	time_alive = ctx.time_alive
	horde.hp_scale = 1.0 + 0.3 * ctx.island_index
	# A head start makes the director spawn more specials on later islands.
	director.elapsed = 120.0 * ctx.island_index


## Writes the run state back when the island ends.
func save_to_context(ctx: RunContext) -> void:
	ctx.intel += intel_earned()
	ctx.hp = maxf(hp, 1.0)
	ctx.level = level
	ctx.xp = xp
	ctx.card_stacks = card_stacks.duplicate()
	ctx.ammo = ammo.duplicate()
	ctx.kills = kills
	ctx.headshots = headshots
	ctx.time_alive = time_alive


func is_paused() -> bool:
	return not card_choices.is_empty() or is_over()


func is_over() -> bool:
	return objective == Objective.WON or objective == Objective.LOST


func xp_needed() -> int:
	return GameData.xp_for_level(level)


func stacks(id: StringName) -> int:
	return card_stacks.get(id, 0)


func breaker_cooldown_total() -> float:
	return GameData.BREAKER_COOLDOWN * pow(0.7, stacks(&"quick_breaker"))


func intel_earned() -> int:
	var done: int = 0
	for p in generator_progress:
		if p >= GameData.GENERATOR_HOLD_SECONDS:
			done += 1
	return (kills - _kills_at_start) / 5 + done * 15 + (40 if objective == Objective.WON else 0)


func switch_weapon(i: int) -> void:
	if i >= 0 and i < weapons.size() and ammo[i] != 0:
		weapon_index = i


func choose_card(i: int) -> void:
	if i < 0 or i >= card_choices.size():
		return
	var c: GameData.Card = card_choices[i]
	card_stacks[c.id] = stacks(c.id) + 1
	messages.append("Card: " + c.title)
	card_choices.clear()
	_roll_cards_if_needed()


## One simulation step. move = desired direction (x, z), aim = facing on XZ.
func step(dt: float, move: Vector2, aim: Vector3, breaker: bool) -> void:
	if is_paused():
		return
	time_alive += dt
	var aim_flat := Vector3(aim.x, 0, aim.z)
	if aim_flat.length_squared() > 0.0001:
		facing = aim_flat.normalized()
	_update_player(dt, move, breaker)
	horde.set_target(player_pos)
	horde.tick(dt)
	if invulnerable <= 0.0 and dash_time <= 0.0:
		hp -= horde.damage_to_player
	invulnerable = maxf(0.0, invulnerable - dt)
	_auto_fire(dt)
	_flush_dead()
	_update_orbs(dt)
	_update_mission(dt)
	var near: int = horde.query_radius(player_pos, 6.0).size()
	var to_spawn: int = director.update(dt, horde.count, horde.damage_to_player, near)
	for k in to_spawn:
		_spawn_enemy()
	if hp <= 0.0:
		hp = 0.0
		objective = Objective.LOST


func _update_player(dt: float, move: Vector2, breaker: bool) -> void:
	breaker_cd = maxf(0.0, breaker_cd - dt)
	var grabbed: bool = horde.grabbed_by != -1
	if breaker and breaker_cd <= 0.0 and dash_time <= 0.0:
		_start_breaker(move)
	if dash_time > 0.0:
		dash_time -= dt
		var speed: float = GameData.BREAKER_DISTANCE / GameData.BREAKER_DURATION
		player_pos = Horde.move_against_walls(field, player_pos, dash_dir.x * speed * dt, dash_dir.z * speed * dt, GameData.PLAYER_RADIUS)
		# Shove everything along the path out of the way.
		var radius: float = GameData.BREAKER_RADIUS * (2.0 if stacks(&"shockwave") > 0 else 1.0)
		for i in horde.query_radius(player_pos, radius):
			horde.stun[i] = maxf(horde.stun[i], GameData.BREAKER_STUN)
			horde.knock_back(i, player_pos, 0.6)
		if dash_time <= 0.0:
			_breaker_impact(radius)
		return
	if grabbed:
		return
	if move.length_squared() > 1.0:
		move = move.normalized()
	var v: Vector2 = move * GameData.PLAYER_SPEED * dt
	player_pos = Horde.move_against_walls(field, player_pos, v.x, v.y, GameData.PLAYER_RADIUS)


func _start_breaker(move: Vector2) -> void:
	dash_dir = Vector3(move.x, 0, move.y).normalized() if move.length_squared() > 0.01 else facing
	dash_time = GameData.BREAKER_DURATION
	breaker_cd = breaker_cooldown_total()
	invulnerable = 0.4
	if horde.grabbed_by != -1:
		var g: int = horde.grabbed_by
		horde.stun[g] = 2.0
		horde.knock_back(g, player_pos, 2.5)
		horde.grabbed_by = -1
		messages.append("Broke free!")


func _breaker_impact(radius: float) -> void:
	var dmg: float = GameData.BREAKER_DAMAGE + 30.0 * stacks(&"shockwave")
	for i in horde.query_radius(player_pos, radius):
		_damage(i, dmg, player_pos, false, true)
	_flush_dead()


func _auto_fire(dt: float) -> void:
	var w: GameData.Weapon = weapons[weapon_index]
	var rate: float = w.fire_rate * (1.0 + 0.2 * stacks(&"fast_hands"))
	_fire_cd -= dt
	if _fire_cd > 0.0:
		return
	var target: int = _pick_target(w.range_m)
	if target == -1:
		_fire_cd = 0.0
		return
	while _fire_cd <= 0.0:
		_fire_cd += 1.0 / rate
		_fire(w, target)
		if ammo[weapon_index] == 0:
			messages.append(w.display_name + " out of ammo")
			weapon_index = 0
			break
		if target in _dead or target >= horde.count:
			break


## Nearest visible enemy inside the aim cone.
func _pick_target(range_m: float) -> int:
	var best: int = -1
	var best_d2: float = INF
	var cos_cone: float = cos(deg_to_rad(GameData.AIM_CONE_DEG))
	for i in horde.query_radius(player_pos, range_m):
		if _dead.has(i):
			continue
		var to: Vector3 = horde.positions[i] - player_pos
		var d2: float = to.x * to.x + to.z * to.z
		if d2 >= best_d2 or d2 < 0.0001:
			continue
		if facing.dot(Vector3(to.x, 0, to.z) / sqrt(d2)) < cos_cone:
			continue
		if not _line_of_sight(player_pos, horde.positions[i]):
			continue
		best = i
		best_d2 = d2
	return best


func _line_of_sight(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	var n: int = ceili(d.length() / 0.5)
	for k in range(1, n):
		var p: Vector3 = a + d * (float(k) / n)
		if field.is_blocked(floori(p.x), floori(p.z)):
			return false
	return true


func _fire(w: GameData.Weapon, target: int) -> void:
	_shots += 1
	if w.max_ammo > 0:
		ammo[weapon_index] -= 1
	var to: Vector3 = horde.positions[target] - player_pos
	to.y = 0.0
	var dir: Vector3 = to.normalized()
	# Headshot when the target sits where the player is facing.
	var headshot: bool = facing.dot(dir) >= cos(deg_to_rad(GameData.HEADSHOT_CONE_DEG))
	var dmg: float = w.damage * (1.0 + 0.25 * stacks(&"hollow_points"))
	for p in w.pellets:
		var pellet_dir: Vector3 = dir
		if w.spread_deg > 0.0:
			pellet_dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-w.spread_deg, w.spread_deg) * 0.5))
		var hits: Array[Vector2] = horde.hitscan(player_pos, pellet_dir, w.range_m, w.pierce)
		var end: Vector3 = player_pos + pellet_dir * w.range_m
		for h in hits:
			var idx: int = int(h.y)
			end = player_pos + pellet_dir * h.x
			if _dead.has(idx):
				continue
			var is_head: bool = headshot and idx == target
			_damage(idx, dmg * (GameData.HEADSHOT_MULTIPLIER if is_head else 1.0), player_pos, is_head, false)
			horde.knock_back(idx, player_pos, w.knockback)
		tracers.append(PackedVector3Array([player_pos, end]))
	if stacks(&"ricochet") > 0 and _shots % 4 == 0:
		var near: PackedInt32Array = horde.query_radius(horde.positions[target], 6.0)
		for j in near:
			if j != target and not _dead.has(j):
				tracers.append(PackedVector3Array([horde.positions[target], horde.positions[j]]))
				_damage(j, dmg, horde.positions[target], false, false)
				break


func _damage(i: int, amount: float, from: Vector3, headshot: bool, breaker: bool) -> void:
	if _dead.has(i):
		return
	var t: GameData.EnemyType = horde.types[horde.kinds[i]]
	if t.front_armor > 0.0 and not breaker:
		# Armoured enemies take reduced damage from the front (where they walk to).
		var v: Vector3 = horde.velocities[i]
		var to_src: Vector3 = from - horde.positions[i]
		if v.length_squared() > 0.01 and v.normalized().dot(to_src.normalized()) > 0.3:
			amount *= 1.0 - t.front_armor
	horde.hp[i] -= amount
	horde.flash[i] = 0.1
	if horde.hp[i] <= 0.0:
		_dead[i] = true
		kills += 1
		if headshot:
			headshots += 1
		var p: Vector3 = horde.positions[i]
		deaths.append(Vector4(p.x, p.z, horde.kinds[i], 1.0 if headshot else 0.0))
		orbs.append(p)
		orb_values.append(t.xp)
		if headshot and stacks(&"vampire") > 0:
			hp = minf(GameData.PLAYER_MAX_HP, hp + 2.0 * stacks(&"vampire"))
		if headshot and stacks(&"explosive_heads") > 0:
			explosions.append(p)
			for j in horde.query_radius(p, 3.0):
				_damage(j, 30.0, p, false, true)


func _flush_dead() -> void:
	if _dead.is_empty():
		return
	var idx: Array = _dead.keys()
	idx.sort()
	idx.reverse()
	for i in idx:
		horde.remove(i)
	_dead.clear()


func _update_orbs(dt: float) -> void:
	var radius: float = GameData.PICKUP_RADIUS * (2.0 if stacks(&"magnet") > 0 else 1.0)
	var i: int = orbs.size() - 1
	while i >= 0:
		var o: Vector3 = orbs[i]
		var d: Vector3 = player_pos - o
		d.y = 0.0
		var dist: float = d.length()
		if dist < 0.8:
			xp += orb_values[i]
			orbs.remove_at(i)
			orb_values.remove_at(i)
		elif dist < radius:
			orbs[i] = o + d / dist * minf(dist, 14.0 * dt)
		i -= 1
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		_pending_levels += 1
	_roll_cards_if_needed()


func _roll_cards_if_needed() -> void:
	if _pending_levels <= 0 or not card_choices.is_empty():
		return
	_pending_levels -= 1
	var pool: Array[GameData.Card] = []
	for c in all_cards:
		if stacks(c.id) < c.max_stacks:
			pool.append(c)
	for k in mini(3, pool.size()):
		var pick: int = rng.randi_range(0, pool.size() - 1)
		card_choices.append(pool[pick])
		pool.remove_at(pick)


func _update_mission(dt: float) -> void:
	match objective:
		Objective.GENERATORS:
			var all_done: bool = true
			for g in GameData.GENERATOR_COUNT:
				if generator_progress[g] >= GameData.GENERATOR_HOLD_SECONDS:
					continue
				all_done = false
				if player_pos.distance_to(map.generators[g]) <= GameData.GENERATOR_RADIUS:
					if not generator_started[g]:
						generator_started[g] = true
						director.trigger_peak(GameData.GENERATOR_HOLD_SECONDS + 10.0)
						messages.append("Generator starting: hold the zone!")
					generator_progress[g] += dt
					if generator_progress[g] >= GameData.GENERATOR_HOLD_SECONDS:
						messages.append("Generator online")
						for w in weapons.size():
							if weapons[w].max_ammo > 0:
								ammo[w] = mini(weapons[w].max_ammo, ammo[w] + weapons[w].max_ammo / 2)
			if all_done:
				objective = Objective.RETURN_TO_BOAT
				director.trigger_peak(25.0)
				messages.append("All generators online. Get back to the boat!")
		Objective.RETURN_TO_BOAT:
			if player_pos.distance_to(map.boat) <= GameData.BOAT_RADIUS:
				objective = Objective.WON


func _spawn_enemy() -> void:
	if horde.count >= GameData.MAX_ALIVE:
		return
	for attempt in 12:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(GameData.SPAWN_MIN_DIST, GameData.SPAWN_MAX_DIST)
		var p: Vector3 = player_pos + Vector3(cos(ang), 0, sin(ang)) * dist
		if p.x < 1 or p.z < 1 or p.x > field.width - 1 or p.z > field.height - 1:
			continue
		if Horde.overlaps_wall(field, p.x, p.z, Horde.RADIUS + 0.05):
			continue
		if field.distance_at(p) >= FlowField.UNREACHABLE:
			continue
		horde.add(p, director.pick_kind(), rng)
		return


## Objective text for the HUD.
func objective_text() -> String:
	match objective:
		Objective.GENERATORS:
			var done: int = 0
			for p in generator_progress:
				if p >= GameData.GENERATOR_HOLD_SECONDS:
					done += 1
			return "Activate the generators (%d/%d)" % [done, GameData.GENERATOR_COUNT]
		Objective.RETURN_TO_BOAT:
			return "Return to the boat!"
		Objective.WON:
			return "Extracted!"
	return "You died"
