class_name IslandRun
extends RefCounted
## All gameplay rules of one island, without nodes: player, auto-fire,
## breaker, horde, director, XP/cards and the "Activate 3" mission.
## The Island scene feeds input into step() and draws the resulting state,
## so the whole game loop can also run headless in tests.

enum Objective { GENERATORS, BOSS, RETURN_TO_BOAT, WON, LOST }

var map: IslandMap
var field: FlowField
var horde: Horde
var director: Director
var rng := RandomNumberGenerator.new()

# Player
var player_pos: Vector3
var facing: Vector3 = Vector3(0, 0, -1)
var max_hp: float = GameData.PLAYER_MAX_HP
var hp: float = GameData.PLAYER_MAX_HP
var perks: Array[StringName] = []
var threat: int = 1
var modifier: StringName = &"calm"
var grenade_cd: float = 0.0
## Grenades in flight/fuse: position of impact and remaining fuse time.
var grenades: PackedVector3Array = PackedVector3Array()
var grenade_fuses: PackedFloat32Array = PackedFloat32Array()
var level: int = 1
var xp: int = 0
var breaker_cd: float = 0.0
var dash_time: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var invulnerable: float = 0.0
## Debug noclip (Mouse 4/5): move through walls and sea, faster, no damage.
var noclip: bool = false
var player_class: StringName = &"recruit"
var hazard_pay: bool = false  ## boat briefing deal (see RunContext)
var war_cry_time: float = 0.0  ## > 0 while War Cry reduces damage taken
var stamina: float = GameData.STAMINA_MAX
var sprinting: bool = false
var _stamina_delay: float = 0.0

# Weapons
var weapons: Array[GameData.Weapon] = GameData.weapons()
var weapon_index: int = 0
## Which weapons can be used this run (locked ones are skipped).
var weapon_unlocked: Array[bool] = []
var ammo: PackedInt32Array = PackedInt32Array()
var _fire_cd: float = 0.0
var _shots: int = 0

# Cards
var all_cards: Array[GameData.Card] = GameData.cards()
var card_stacks: Dictionary = {}  ## StringName -> int
var card_choices: Array[GameData.Card] = []
var _pending_levels: int = 0
var _recycle_cd: float = 0.0

# Pickups
var orbs: PackedVector3Array = PackedVector3Array()
var orb_values: PackedInt32Array = PackedInt32Array()

# Mission
var objective: Objective = Objective.GENERATORS
var generator_progress: PackedFloat32Array = PackedFloat32Array()
var generator_started: Array[bool] = []
## The last island ends with a boss fight before the return to the boat.
var has_boss: bool = false
var mission: StringName = &"activate"
## Defend / rescue / holdout site: the map's RescueTarget / DefendZone
## marker when it has one, else the generator spot farthest from the boat.
var site: Vector3 = Vector3.ZERO
var defend_time: float = 0.0
## Holdout (final of an expedition): seconds until the rescue boat reaches
## the pier, counting down once the zone is held (-1 = not called yet).
var boat_eta: float = -1.0
## Expedition parts: the next part's name, for "Head to <name>" (empty =
## "Leave along the path"). load_context fills it; the scene may too.
var exit_label: String = ""
## Expedition parts: the walkable polygon (island metres) of this part, from
## HandmadeIsland.play_area (set by the Island scene). Empty = whole island.
## Only the minimap uses it: the grid already blocks the cells outside.
var play_area: PackedVector2Array = PackedVector2Array()
var _defend_peak_cd: float = 0.0
var survivor_pos: Vector3 = Vector3.ZERO
var survivor_hp: float = GameData.SURVIVOR_HP
var survivor_found: bool = false
var survivor_lost: bool = false
var cache_progress: PackedFloat32Array = PackedFloat32Array()  ## >= CACHE_OPEN_TIME = opened
var cache_intel: int = 0
var damage_taken: float = 0.0
var _hp_at_step_start: float = 0.0
var cards_picked: Array[StringName] = []
var boss_max_hp: float = 0.0
var slam_pos: Vector3 = Vector3.ZERO
var slam_time: float = 0.0  ## > 0 while a slam is winding up
var boss_killed: bool = false
## Phase 2 below half HP: faster, slams more often, summons a Brute too.
var boss_enraged: bool = false
## Rocks thrown by the boss: target point and remaining flight time.
var rocks: PackedVector3Array = PackedVector3Array()
var rock_times: PackedFloat32Array = PackedFloat32Array()
var rock_origins: PackedVector3Array = PackedVector3Array()
var _rock_cd: float = 3.0
var _slam_cd: float = 2.0
var _summon_cd: float = GameData.BOSS_SUMMON_INTERVAL

# Stats
var kills: int = 0
var headshots: int = 0
var time_alive: float = 0.0
## Spawn statistics (tests, F3): enemies the director asked for, how many
## needed the ring fallback and how many found no spot at all.
var spawn_requests: int = 0
var spawn_fallbacks: int = 0
var spawn_failures: int = 0

# Render events, consumed (cleared) by the scene every frame.
var tracers: Array[PackedVector3Array] = []
var deaths: Array[Vector4] = []  ## (x, z, kind, headshot 0/1)
var explosions: PackedVector3Array = PackedVector3Array()
var messages: PackedStringArray = PackedStringArray()
## Radio events (Story.RADIO keys), consumed by the HUD.
var radio: Array[StringName] = []
## Damage numbers for the HUD: (x, z, damage, headshot 0/1), consumed per frame.
var popups: Array[Vector4] = []
## Intel files recovered on this island (caches, boss).
var lore_found: int = 0
var _low_hp_cd: float = 0.0

var _kills_at_start: int = 0
var scream_progress: float = 0.0  ## seconds a Screamer has seen the player
var _scream_cd: float = 0.0
var _dead: Dictionary = {}  ## enemy index -> true, removed at the end of step()


## `custom_map`: a ready map (e.g. HandmadeIsland.build_map()) instead of
## generating one from the seed.
func _init(rng_seed: int = 7, biome: StringName = &"beach", custom_map: IslandMap = null) -> void:
	rng.seed = rng_seed
	map = custom_map if custom_map != null else IslandMap.build(rng_seed, biome)
	field = map.field
	horde = Horde.new(field)
	if field.max_distance > 0:
		horde.field_budget = 4000  # big island: a fresher field around the player (~1 ms more per step)
	director = Director.new(rng_seed)
	player_pos = map.player_start
	field.compute_now(field.world_to_cell(player_pos))
	horde.set_target(player_pos)
	for w in weapons:
		ammo.append(w.max_ammo)
		weapon_unlocked.append(GameData.starting_weapons().has(w.id))
	for c in map.caches:
		cache_progress.append(0.0)
	for i in GameData.GENERATOR_COUNT:
		generator_progress.append(0.0)
		generator_started.append(false)


## Loads the run state carried from previous islands and scales difficulty.
func load_context(ctx: RunContext) -> void:
	perks = ctx.perks.duplicate()
	set_mission(ctx.mission)
	exit_label = next_part_name(ctx)
	radio.append(StringName("land_" + String(mission)))
	# The last island has the Behemoth; the expedition's holdout is itself
	# the finale (hold the fort, then the boat), so it has none.
	has_boss = ctx.is_last_island() and mission != &"holdout"
	if has_boss:
		radio.append(&"land_boss")
	player_class = ctx.player_class
	for w in weapons.size():
		weapon_unlocked[w] = ctx.weapons.has(weapons[w].id)
	threat = ctx.threat
	max_hp = ctx.max_hp
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
	horde.hp_scale = (1.0 + 0.3 * ctx.island_index) * GameData.threat_hp(threat)
	director.max_alive = GameData.MAX_ALIVE + GameData.threat_extra_alive(threat)
	modifier = ctx.modifier
	hazard_pay = ctx.hazard_pay
	if hazard_pay:
		director.max_alive = int(director.max_alive * GameData.HAZARD_ALIVE_MULT)
	if map.biome == &"jungle":
		director.specials_mult *= 1.4
	match modifier:
		&"swarm":
			director.max_alive += 40
		&"elite":
			director.specials_mult = 2.0
	# Fresh ammo (start or Ammo Crate) fills to the max; carried ammo is capped.
	for w in weapons.size():
		if weapons[w].max_ammo > 0:
			ammo[w] = max_ammo(w) if ctx.ammo.size() != ammo.size() else mini(ammo[w], max_ammo(w))
	# A head start makes the director spawn more specials on later islands.
	director.elapsed = 120.0 * ctx.island_index


## Expedition runs: the name of the part after the current one ("" when the
## run is not an expedition or this is its last part). In an expedition
## island_index is the part being played (RunContext.expedition_parts).
static func next_part_name(ctx: RunContext) -> String:
	var parts: Variant = ctx.get(&"expedition_parts")
	if not parts is Array:
		return ""
	var next: int = ctx.island_index + 1
	return String(parts[next].get("name", "")) if next < parts.size() else ""


## Writes the run state back when the island ends.
func save_to_context(ctx: RunContext) -> void:
	ctx.island_log.append({
		"island": ctx.island_index + 1, "modifier": String(modifier),
		"result": "cleared" if objective == Objective.WON else "died",
		"seconds": snappedf(time_alive - ctx.time_alive, 0.1),
		"kills": kills - _kills_at_start, "headshots": headshots - ctx.headshots,
		"damage_taken": int(damage_taken), "hp_left": int(hp), "level": level,
		"intel": intel_earned(), "caches_opened": caches_opened(),
		"cards_picked": cards_picked.map(func(x: StringName) -> String: return String(x)),
	})
	ctx.intel += intel_earned()
	ctx.hazard_pay = false  # one island only
	ctx.lore_found += lore_found
	ctx.hp = clampf(hp, 1.0, max_hp)
	ctx.level = level
	ctx.xp = xp
	ctx.card_stacks = card_stacks.duplicate()
	ctx.ammo = ammo.duplicate()
	ctx.kills = kills
	ctx.headshots = headshots
	ctx.time_alive = time_alive


func max_ammo(w: int) -> int:
	var m: int = weapons[w].max_ammo
	if m > 0 and has_perk(&"pack_rat"):
		m = m * 3 / 2
	if m > 0:
		m = int(m * (1.0 + 0.3 * stacks(&"bigger_mags")))
	if m > 0 and modifier == &"short":
		m /= 2
	return m


func has_perk(id: StringName) -> bool:
	return perks.has(id)


func grenade_cooldown_total() -> float:
	return GameData.GRENADE_COOLDOWN * (0.65 if has_perk(&"demolitions") else 1.0) * pow(0.8, stacks(&"grenadier"))


## Throws a grenade towards `aim` (vector from the player; its length is the
## throw distance, clamped to the grenade range).
## Uses the class ability (Recruit: grenade, Vanguard: War Cry).
func use_ability(aim: Vector3) -> bool:
	if grenade_cd > 0.0 or is_paused():
		return false
	match player_class:
		&"vanguard":
			for i in horde.query_radius(player_pos, GameData.WAR_CRY_RADIUS):
				horde.stun[i] = maxf(horde.stun[i], 1.5)
				horde.knock_back(i, player_pos, 1.0)
			war_cry_time = GameData.WAR_CRY_TIME
			grenade_cd = ability_cooldown_total()
			explosions.append(player_pos)
			messages.append("WAR CRY!")
			return true
	return throw_grenade(aim)


func ability_cooldown_total() -> float:
	match player_class:
		&"vanguard":
			return GameData.WAR_CRY_COOLDOWN
	return grenade_cooldown_total()


func throw_grenade(aim: Vector3) -> bool:
	if grenade_cd > 0.0 or is_paused():
		return false
	var flat := Vector3(aim.x, 0, aim.z)
	if flat.length_squared() < 0.01:
		flat = facing * 6.0
	flat = flat.limit_length(GameData.GRENADE_RANGE)
	# Stop the throw at the first wall cell along the way.
	var target: Vector3 = player_pos
	var n: int = ceili(flat.length() / 0.5)
	for k in range(1, n + 1):
		var p: Vector3 = player_pos + flat * (float(k) / n)
		if field.is_blocked(floori(p.x), floori(p.z)):
			break
		target = p
	grenades.append(target)
	grenade_fuses.append(GameData.GRENADE_FUSE)
	grenade_cd = grenade_cooldown_total()
	return true


## A Screamer that sees the player for SCREAM_TIME seconds calls a horde peak.
func _update_screamers(dt: float) -> void:
	_scream_cd = maxf(0.0, _scream_cd - dt)
	var seen: bool = false
	for i in horde.count:
		if horde.kinds[i] == GameData.EnemyKind.SCREAMER and horde.stun[i] <= 0.0 \
				and horde.positions[i].distance_to(player_pos) <= GameData.SCREAM_RANGE \
				and _line_of_sight(horde.positions[i], player_pos):
			seen = true
			break
	scream_progress = scream_progress + dt if seen else maxf(0.0, scream_progress - dt)
	if scream_progress >= GameData.SCREAM_TIME and _scream_cd <= 0.0:
		scream_progress = 0.0
		_scream_cd = GameData.SCREAM_COOLDOWN
		director.trigger_peak(15.0)
		messages.append("A Screamer called the horde!")
		radio.append(&"screamer")


func _update_grenades(dt: float) -> void:
	grenade_cd = maxf(0.0, grenade_cd - dt)
	var radius: float = GameData.GRENADE_RADIUS + (1.0 if has_perk(&"demolitions") else 0.0)
	var i: int = grenades.size() - 1
	while i >= 0:
		grenade_fuses[i] -= dt
		if grenade_fuses[i] <= 0.0:
			var p: Vector3 = grenades[i]
			explosions.append(p)
			for j in horde.query_radius(p, radius):
				_damage(j, GameData.GRENADE_DAMAGE, p, false, true)
				horde.stun[j] = maxf(horde.stun[j], 0.6)
				horde.knock_back(j, p, 2.0)
			grenades.remove_at(i)
			grenade_fuses.remove_at(i)
		i -= 1


func set_mission(id: StringName) -> void:
	mission = id
	var marker: Vector3 = map.rescue_target if mission == &"rescue" else map.defend_zone
	if mission in [&"rescue", &"defend", &"holdout"] and marker.x >= 0.0:
		site = marker
	elif not map.generators.is_empty():
		var best: float = -1.0
		for g in map.generators:
			var d: float = g.distance_to(map.boat)
			if d > best:
				best = d
				site = g
	else:
		site = map.exit if has_exit() else map.boat
	survivor_pos = site


## Expedition parts: true when the map has an Exit marker (the way on to the
## next part), so the extraction is there, on foot, not at the boat. The
## holdout (the final) always ends on the rescue boat.
func has_exit() -> bool:
	return map.exit.x >= 0.0 and mission != &"holdout"


## Where the island ends: the Exit on expedition parts, else the boat (the
## holdout's rescue boat docks at the Boat marker, the fort pier).
func extraction_point() -> Vector3:
	return map.exit if has_exit() else map.boat


## Short name of the extraction point (HUD marker).
func extraction_name() -> String:
	if has_exit():
		return exit_label if exit_label != "" else "Exit"
	return "Pier" if mission == &"holdout" else "Boat"


## Seconds the zone must be held (Defend, or the expedition's final holdout).
func hold_time() -> float:
	return GameData.HOLDOUT_TIME if mission == &"holdout" else GameData.DEFEND_TIME


## True when the boat model belongs in the world now. Parts 2-3 keep the
## Boat marker inland at their entry only because build_map needs one: there
## the hull would sit on land, so it is hidden. The holdout's boat shows once
## it has been called (it sails in from the sea).
func shows_boat() -> bool:
	if mission == &"holdout":
		return boat_eta >= 0.0
	if map.exit.x < 0.0 or map.heights.is_empty():
		return true
	for d: float in [3.0, 6.0, 9.0]:
		var p: Vector3 = map.boat + map.boat_dir * d
		if p.x < 0.0 or p.z < 0.0 or p.x >= field.width or p.z >= field.height or map.ground_y(p) <= 0.0:
			return true  # water under the hull: the landing boat stays as scenery
	return false


## 0 while the holdout boat is far out at sea (or not called), 1 once docked.
func boat_arrival() -> float:
	if boat_eta < 0.0:
		return 0.0
	return 1.0 - boat_eta / GameData.BOAT_ARRIVAL_TIME


## True once the island's main task is done (the boss / boat come next).
func _main_task_done() -> bool:
	match mission:
		&"defend", &"holdout":
			return defend_time >= hold_time()
		&"rescue":
			return survivor_found or survivor_lost
	for p in generator_progress:
		if p < GameData.GENERATOR_HOLD_SECONDS:
			return false
	return true


func is_paused() -> bool:
	return not card_choices.is_empty() or is_over()


func is_over() -> bool:
	return objective == Objective.WON or objective == Objective.LOST


func xp_needed() -> int:
	return GameData.xp_for_level(level)


func stacks(id: StringName) -> int:
	return card_stacks.get(id, 0)


func breaker_cooldown_total() -> float:
	return (0.7 if player_class == &"vanguard" else 1.0) * GameData.BREAKER_COOLDOWN * pow(0.7, stacks(&"quick_breaker"))


func intel_earned() -> int:
	var done: int = 0
	for p in generator_progress:
		if p >= GameData.GENERATOR_HOLD_SECONDS:
			done += 1
	var base: int = (kills - _kills_at_start) / 5 + (40 if objective == Objective.WON else 0)
	match mission:
		&"defend", &"holdout":
			base += 45 if defend_time >= hold_time() else int(defend_time / hold_time() * 30.0)
		&"rescue":
			base += 40 if survivor_found and not survivor_lost and objective == Objective.WON else 0
		_:
			base += done * 15
	base += 20 if boss_killed else 0
	base += cache_intel
	var hazard: float = GameData.HAZARD_INTEL_MULT if hazard_pay else 1.0
	return int(base * GameData.threat_intel(threat) * GameData.modifier(modifier).intel_mult * hazard)


func switch_weapon(i: int) -> void:
	if i >= 0 and i < weapons.size() and ammo[i] != 0 and weapon_unlocked[i]:
		weapon_index = i


## Next usable weapon (gamepad cycling).
func cycle_weapon() -> void:
	for k in range(1, weapons.size() + 1):
		var i: int = (weapon_index + k) % weapons.size()
		if weapon_unlocked[i] and ammo[i] != 0:
			weapon_index = i
			return


func choose_card(i: int) -> void:
	if i < 0 or i >= card_choices.size():
		return
	var c: GameData.Card = card_choices[i]
	card_stacks[c.id] = stacks(c.id) + 1
	cards_picked.append(c.id)
	messages.append("Card: " + c.title)
	card_choices.clear()
	_roll_cards_if_needed()


## One simulation step. move = desired direction (x, z), aim = facing on XZ.
func step(dt: float, move: Vector2, aim: Vector3, breaker: bool, sprint: bool = false) -> void:
	if is_paused():
		return
	time_alive += dt
	_hp_at_step_start = hp
	var aim_flat := Vector3(aim.x, 0, aim.z)
	if aim_flat.length_squared() > 0.0001:
		facing = aim_flat.normalized()
	_update_stamina(dt, sprint and move.length_squared() > 0.01)
	_update_player(dt, move, breaker)
	horde.set_target(player_pos)
	horde.tick(dt)
	if invulnerable <= 0.0 and dash_time <= 0.0:
		var melee: float = minf(horde.damage_to_player, GameData.MAX_MELEE_PER_FRAME)
		hp -= melee * (0.6 if war_cry_time > 0.0 else 1.0)
	war_cry_time = maxf(0.0, war_cry_time - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	if not sprinting:
		_auto_fire(dt)
	_update_grenades(dt)
	_update_screamers(dt)
	_flush_dead()
	_recycle_far(dt)
	_update_orbs(dt)
	_update_mission(dt)
	_update_caches(dt)
	_update_lava(dt)
	var near: int = horde.query_radius(player_pos, 6.0).size()
	var to_spawn: int = director.update(dt, horde.count, horde.damage_to_player, near)
	for k in to_spawn:
		_spawn_enemy()
	if noclip:
		hp = maxf(hp, _hp_at_step_start)  # no damage while testing
	damage_taken += maxf(0.0, _hp_at_step_start - hp)
	_low_hp_cd -= dt
	if hp < max_hp * 0.3 and _low_hp_cd <= 0.0 and hp > 0.0:
		_low_hp_cd = 40.0
		radio.append(&"low_hp")
	if hp <= 0.0:
		hp = 0.0
		objective = Objective.LOST


## Sprint drains stamina; it regenerates after a short pause. Running on
## empty is not possible, so the player must pick when to run.
func _update_stamina(dt: float, wants_sprint: bool) -> void:
	sprinting = wants_sprint and stamina > 0.0 and horde.grabbed_by == -1
	if sprinting:
		stamina = maxf(0.0, stamina - dt)
		_stamina_delay = GameData.STAMINA_REGEN_DELAY
	else:
		_stamina_delay -= dt
		if _stamina_delay <= 0.0:
			stamina = minf(GameData.STAMINA_MAX, stamina + GameData.STAMINA_REGEN * dt)


func _update_player(dt: float, move: Vector2, breaker: bool) -> void:
	breaker_cd = maxf(0.0, breaker_cd - dt)
	if noclip:
		horde.grabbed_by = -1
		if move.length_squared() > 1.0:
			move = move.normalized()
		var fly: Vector2 = move * GameData.PLAYER_SPEED * (6.0 if sprinting else 3.0) * dt
		player_pos.x = clampf(player_pos.x + fly.x, 0.5, field.width - 0.5)
		player_pos.z = clampf(player_pos.z + fly.y, 0.5, field.height - 0.5)
		return
	var grabbed: bool = horde.grabbed_by != -1
	if breaker and breaker_cd <= 0.0 and dash_time <= 0.0:
		_start_breaker(move)
	if dash_time > 0.0:
		dash_time -= dt
		var speed: float = GameData.BREAKER_DISTANCE * (1.4 if has_perk(&"long_breaker") else 1.0) / GameData.BREAKER_DURATION
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
	var v: Vector2 = move * GameData.PLAYER_SPEED * (GameData.SPRINT_MULTIPLIER if sprinting else 1.0) * dt
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
## Best visible enemy inside the aim cone. Score = distance + 0.4 m per
## degree off the facing direction, so turning towards an enemy (a special,
## the boss) makes it the target ("aim with your body"). Enemies within
## 2.5 m always win: whoever is biting you gets shot first.
func _pick_target(range_m: float) -> int:
	var best: int = -1
	var best_score: float = INF
	var cos_cone: float = cos(deg_to_rad(GameData.AIM_CONE_DEG))
	for i in horde.query_radius(player_pos, range_m):
		if _dead.has(i):
			continue
		var to: Vector3 = horde.positions[i] - player_pos
		var d: float = sqrt(to.x * to.x + to.z * to.z)
		if d < 0.01:
			continue
		var c: float = facing.dot(Vector3(to.x, 0, to.z) / d)
		if c < cos_cone:
			continue
		var score: float = d + rad_to_deg(acos(clampf(c, -1.0, 1.0))) * 0.4
		if d < 2.5:
			score -= 100.0
		if score >= best_score:
			continue
		if not _line_of_sight(player_pos, horde.positions[i]):
			continue
		best = i
		best_score = score
	return best


func _line_of_sight(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	var n: int = ceili(d.length() / 0.5)
	for k in range(1, n):
		var p: Vector3 = a + d * (float(k) / n)
		if field.is_blocked(floori(p.x), floori(p.z)):
			return false
	return true


func headshot_cone_cos() -> float:
	return cos(deg_to_rad(15.0 if has_perk(&"head_hunter") else GameData.HEADSHOT_CONE_DEG))


## For the laser sight: current auto-fire target (-1 if none) and whether a
## shot now would be a headshot.
func aim_info() -> Array:
	var target: int = _pick_target(weapons[weapon_index].range_m)
	if target == -1:
		return [-1, false]
	var to: Vector3 = horde.positions[target] - player_pos
	to.y = 0.0
	return [target, facing.dot(to.normalized()) >= headshot_cone_cos()]


func _fire(w: GameData.Weapon, target: int) -> void:
	_shots += 1
	if w.max_ammo > 0:
		ammo[weapon_index] -= 1
	var to: Vector3 = horde.positions[target] - player_pos
	to.y = 0.0
	var dir: Vector3 = to.normalized()
	# Headshot when the target sits where the player is facing.
	var headshot: bool = facing.dot(dir) >= headshot_cone_cos()
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
	if stacks(&"executioner") > 0 and horde.stun[i] > 0.0:
		amount *= 1.0 + 0.6 * stacks(&"executioner")
	horde.hp[i] -= amount
	horde.flash[i] = 0.1
	if horde.hp[i] <= 0.0:
		_dead[i] = true
		kills += 1
		if stacks(&"adrenaline") > 0:
			breaker_cd = maxf(0.0, breaker_cd - 0.3)
		if headshot:
			headshots += 1
		var p: Vector3 = horde.positions[i]
		deaths.append(Vector4(p.x, p.z, horde.kinds[i], 1.0 if headshot else 0.0))
		popups.append(Vector4(p.x, p.z, amount, 1.0 if headshot else 0.0))
		if t.explodes:
			explosions.append(p)
			if player_pos.distance_to(p) <= GameData.BLOATER_RADIUS and dash_time <= 0.0:
				hp -= GameData.BLOATER_PLAYER_DAMAGE
			for j in horde.query_radius(p, GameData.BLOATER_RADIUS):
				_damage(j, GameData.BLOATER_DAMAGE, p, false, true)
				horde.knock_back(j, p, 1.5)
		orbs.append(p)
		orb_values.append(t.xp)
		if headshot and stacks(&"vampire") > 0:
			hp = minf(max_hp, hp + 2.0 * stacks(&"vampire"))
		if headshot and stacks(&"explosive_heads") > 0:
			explosions.append(p)
			for j in horde.query_radius(p, 3.0):
				_damage(j, 30.0, p, false, true)


## Big islands (field.max_distance set): the horde's flow field only covers
## the area around the player, so enemies left behind outside it would stand
## still. They are removed (no XP) and the director spawns new ones nearby.
func _recycle_far(dt: float) -> void:
	if field.max_distance <= 0:
		return
	# Count down every tick; once due, wait only for a finished field (while
	# the player runs a recompute is almost always under way, and counting
	# only between them stretched 1 s to about 8 s: found by Codex).
	_recycle_cd -= dt
	if _recycle_cd > 0.0 or field.is_computing:
		return
	_recycle_cd = 1.0
	var far2: float = GameData.SPAWN_MAX_DIST * GameData.SPAWN_MAX_DIST
	for i in range(horde.count - 1, -1, -1):
		if horde.kinds[i] == GameData.EnemyKind.BOSS:
			continue
		var p: Vector3 = horde.positions[i]
		if field.distance_at(p) >= FlowField.UNREACHABLE and p.distance_squared_to(player_pos) > far2:
			horde.remove(i)


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
	if pool.is_empty():
		# Every card maxed: levelling up still heals.
		hp = minf(max_hp, hp + 20.0)
		messages.append("Level up: +20 HP")
		_roll_cards_if_needed()
		return
	for k in mini(3, pool.size()):
		var pick: int = rng.randi_range(0, pool.size() - 1)
		card_choices.append(pool[pick])
		pool.remove_at(pick)


func _update_mission(dt: float) -> void:
	match objective:
		Objective.GENERATORS:
			match mission:
				&"defend", &"holdout":
					_update_defend(dt)
				&"rescue":
					_update_rescue(dt)
				_:
					_update_generators(dt)
			if _main_task_done() and has_boss:
				objective = Objective.BOSS
				_spawn_boss()
				messages.append("Something huge is coming... Kill the Behemoth!")
				radio.append(&"boss")
			elif _main_task_done():
				_start_extraction()
				director.trigger_peak(25.0)
				if mission != &"rescue":
					radio.append(&"objective_done_on_foot" if has_exit() else &"objective_done")
		Objective.BOSS:
			_update_rescue(dt)
			var b: int = boss_index()
			if b == -1:
				boss_killed = true
				rocks.clear()
				rock_times.clear()
				rock_origins.clear()
				slam_time = 0.0
				director.trigger_peak(20.0)
				messages.append("Behemoth down!")
				_start_extraction()
				radio.append(&"boss_down")
				lore_found += 1
			else:
				_update_boss(dt, b)
		Objective.RETURN_TO_BOAT:
			_update_rescue(dt)
			if boat_eta > 0.0:
				boat_eta = maxf(0.0, boat_eta - dt)
				if boat_eta == 0.0:
					messages.append("The boat is at the pier. Get on board!")
				return  # the holdout's boat is still out at sea
			# A rescued survivor must make it out too.
			var out: Vector3 = extraction_point()
			var survivor_ok: bool = mission != &"rescue" or survivor_lost or survivor_pos.distance_to(out) <= GameData.BOAT_RADIUS + 2.0
			if player_pos.distance_to(out) <= GameData.BOAT_RADIUS and survivor_ok:
				objective = Objective.WON


## The main task (and the boss) is done: head for the extraction point. The
## holdout calls the rescue boat, which needs BOAT_ARRIVAL_TIME to dock.
func _start_extraction() -> void:
	objective = Objective.RETURN_TO_BOAT
	if mission == &"holdout":
		boat_eta = GameData.BOAT_ARRIVAL_TIME
		messages.append("The rescue boat is coming! Make for the pier!")
	elif has_exit():
		messages.append("Objective complete. %s!" % _exit_order())
	else:
		messages.append("Objective complete. Get back to the boat!")


func _exit_order() -> String:
	return "Head to " + exit_label if exit_label != "" else "Leave along the path"


func _update_defend(dt: float) -> void:
	if player_pos.distance_to(site) <= GameData.DEFEND_RADIUS:
		if defend_time == 0.0:
			messages.append("Hold the courtyard until the boat is called!" if mission == &"holdout" else "Uplink started: hold the zone!")
		defend_time += dt
		_defend_peak_cd -= dt
		if _defend_peak_cd <= 0.0:
			_defend_peak_cd = 25.0
			director.trigger_peak(18.0)


## The survivor waits at the site, then follows the player and can be hurt.
func _update_rescue(dt: float) -> void:
	if mission != &"rescue" or survivor_lost:
		return
	if not survivor_found:
		if player_pos.distance_to(survivor_pos) <= GameData.SURVIVOR_FIND_RADIUS:
			survivor_found = true
			messages.append("Survivor found! Escort them %s." % ("out along the path" if has_exit() else "to the boat"))
			radio.append(&"survivor_found")
		return
	var to: Vector3 = player_pos - survivor_pos
	to.y = 0.0
	if to.length() > 2.0:
		# Follow the flow field (it leads to the player round cliffs and
		# trees); straight at the player only when already in the same cell.
		var step: Vector2 = field.direction_at(survivor_pos)
		if step != Vector2.ZERO:
			var cell := Vector3(floorf(survivor_pos.x) + step.x + 0.5, 0, floorf(survivor_pos.z) + step.y + 0.5)
			to = cell - Vector3(survivor_pos.x, 0, survivor_pos.z)
		var v: Vector3 = to.normalized() * GameData.SURVIVOR_SPEED * dt
		survivor_pos = Horde.move_against_walls(field, survivor_pos, v.x, v.z, 0.35)
	var touching: int = horde.query_radius(survivor_pos, 1.3).size()
	survivor_hp -= mini(touching, 6) * GameData.SURVIVOR_HIT_DPS * dt
	if survivor_hp <= 0.0:
		survivor_lost = true
		messages.append("The survivor is dead.")
		radio.append(&"survivor_lost")


func _update_generators(dt: float) -> void:
	for g in GameData.GENERATOR_COUNT:
		if generator_progress[g] >= GameData.GENERATOR_HOLD_SECONDS:
			continue
		if player_pos.distance_to(map.generators[g]) <= GameData.GENERATOR_RADIUS:
			if not generator_started[g]:
				generator_started[g] = true
				director.trigger_peak(GameData.GENERATOR_HOLD_SECONDS + 10.0)
				messages.append("Generator starting: hold the zone!")
			generator_progress[g] += dt
			if generator_progress[g] >= GameData.GENERATOR_HOLD_SECONDS:
				messages.append("Generator online")
				radio.append(&"generator")
				for w in weapons.size():
					if weapons[w].max_ammo > 0:
						ammo[w] = mini(max_ammo(w), ammo[w] + max_ammo(w) / 2)


## Lava pools burn the player (unless dashing) and enemies alike.
func _update_lava(dt: float) -> void:
	for k in map.lava.size():
		var c: Vector3 = map.lava[k]
		var r: float = map.lava_radius[k]
		if dash_time <= 0.0 and Vector2(player_pos.x - c.x, player_pos.z - c.z).length() <= r:
			hp -= GameData.LAVA_PLAYER_DPS * dt
		for i in horde.query_radius(c, r):
			if horde.kinds[i] != GameData.EnemyKind.BOSS:
				_damage(i, GameData.LAVA_ENEMY_DPS * dt, c, false, true)
	_flush_dead()


func caches_opened() -> int:
	var n: int = 0
	for p in cache_progress:
		if p >= GameData.CACHE_OPEN_TIME:
			n += 1
	return n


func _update_caches(dt: float) -> void:
	for c in map.caches.size():
		if cache_progress[c] >= GameData.CACHE_OPEN_TIME:
			continue
		if player_pos.distance_to(map.caches[c]) <= GameData.CACHE_RADIUS:
			cache_progress[c] += dt
			if cache_progress[c] >= GameData.CACHE_OPEN_TIME:
				_open_cache()
		else:
			cache_progress[c] = 0.0


func _open_cache() -> void:
	radio.append(&"cache")
	# Half the caches also hold an Intel file (story page).
	if rng.randf() < 0.5:
		lore_found += 1
		messages.append("Intel file recovered!")
	match rng.randi_range(0, 3):
		0:
			hp = minf(max_hp, hp + 30.0)
			messages.append("Cache: med supplies (+30 HP)")
		1:
			for w in weapons.size():
				if weapons[w].max_ammo > 0:
					ammo[w] = max_ammo(w)
			messages.append("Cache: ammo (specials refilled)")
		2:
			orbs.append(player_pos)
			orb_values.append(xp_needed() / 2)
			messages.append("Cache: field notes (XP)")
		_:
			cache_intel += 10
			messages.append("Cache: Intel (+10)")


## Index of the boss in the horde, or -1 (indices change when enemies die).
func boss_index() -> int:
	for i in horde.count:
		if horde.kinds[i] == GameData.EnemyKind.BOSS:
			return i
	return -1


func boss_hp_fraction() -> float:
	var b: int = boss_index()
	return horde.hp[b] / boss_max_hp if b != -1 and boss_max_hp > 0.0 else 0.0


func _spawn_boss() -> void:
	# Arrives from the far side of the player's position, on reachable ground.
	for attempt in 40:
		var ang: float = rng.randf() * TAU
		var p: Vector3 = player_pos + Vector3(cos(ang), 0, sin(ang)) * 22.0
		if Horde.overlaps_wall(field, p.x, p.z, Horde.RADIUS + 0.05):
			continue
		if field.distance_at(p) >= FlowField.UNREACHABLE:
			continue
		var i: int = horde.add(p, GameData.EnemyKind.BOSS, rng)
		boss_max_hp = horde.hp[i]
		return
	# Fallback (narrow places, expedition parts without generators): the
	# first free, reachable spot on rings around the player; at worst on the
	# player, the one cell known to be walkable.
	var spot: Vector3 = _ring_spot(player_pos, [12.0, 18.0, 26.0, 8.0, 5.0])
	var j: int = horde.add(spot if spot != Vector3.INF else player_pos, GameData.EnemyKind.BOSS, rng)
	boss_max_hp = horde.hp[j]


func _update_boss(dt: float, b: int) -> void:
	var bp: Vector3 = horde.positions[b]
	if not boss_enraged and horde.hp[b] < boss_max_hp * 0.5:
		boss_enraged = true
		horde.speeds[b] = 2.7
		messages.append("The Behemoth is ENRAGED!")
	_slam_cd -= dt
	_summon_cd -= dt
	if slam_time > 0.0:
		# Winding up: the boss stands still while the ring is shown.
		horde.stun[b] = maxf(horde.stun[b], 0.05)
		slam_time -= dt
		if slam_time <= 0.0:
			explosions.append(slam_pos)
			if dash_time <= 0.0 and player_pos.distance_to(slam_pos) <= GameData.BOSS_SLAM_RADIUS:
				hp -= GameData.BOSS_SLAM_DAMAGE
				messages.append("SLAMMED!")
			for j in horde.query_radius(slam_pos, GameData.BOSS_SLAM_RADIUS):
				if j != b:
					horde.knock_back(j, slam_pos, 2.0)
	elif _slam_cd <= 0.0 and bp.distance_to(player_pos) <= GameData.BOSS_SLAM_RANGE:
		slam_pos = bp
		slam_time = GameData.BOSS_SLAM_WINDUP
		_slam_cd = GameData.BOSS_SLAM_COOLDOWN * (0.6 if boss_enraged else 1.0)
	# Kiting the boss gets punished with rocks aimed where the player stands.
	_rock_cd -= dt
	if _rock_cd <= 0.0 and slam_time <= 0.0 and bp.distance_to(player_pos) >= GameData.BOSS_ROCK_MIN_RANGE:
		_rock_cd = GameData.BOSS_ROCK_COOLDOWN * (0.6 if boss_enraged else 1.0)
		rocks.append(player_pos)
		rock_times.append(GameData.BOSS_ROCK_FLIGHT)
		rock_origins.append(bp + Vector3(0, 4.0, 0))
	var r: int = rocks.size() - 1
	while r >= 0:
		rock_times[r] -= dt
		if rock_times[r] <= 0.0:
			explosions.append(rocks[r])
			if dash_time <= 0.0 and player_pos.distance_to(rocks[r]) <= GameData.BOSS_ROCK_RADIUS:
				hp -= GameData.BOSS_ROCK_DAMAGE
			rocks.remove_at(r)
			rock_times.remove_at(r)
			rock_origins.remove_at(r)
		r -= 1
	if _summon_cd <= 0.0:
		_summon_cd = GameData.BOSS_SUMMON_INTERVAL
		if boss_enraged:
			var bpos: Vector3 = bp + Vector3(0, 0, 3.5)
			if can_spawn_at(bpos):
				horde.add(bpos, GameData.EnemyKind.BRUTE, rng)
		for k in GameData.BOSS_SUMMON_COUNT:
			var p: Vector3 = bp + Vector3(cos(k * 1.05), 0, sin(k * 1.05)) * 3.0
			# Free and reachable: a summon behind a wall (in a closed yard, or
			# outside an expedition part's play area) would never reach the fight.
			if can_spawn_at(p):
				horde.add(p, GameData.EnemyKind.RUNNER, rng)


## True when an enemy can appear at `p`: inside the grid, clear of walls
## (the sea, cliffs and the cells outside an expedition part's play area are
## all blocked) and connected to the player by the horde's flow field.
func can_spawn_at(p: Vector3) -> bool:
	if p.x < 1 or p.z < 1 or p.x > field.width - 1 or p.z > field.height - 1:
		return false
	if Horde.overlaps_wall(field, p.x, p.z, Horde.RADIUS + 0.05):
		return false
	return field.distance_at(p) < FlowField.UNREACHABLE


## The first spot that can_spawn_at() on rings of these radii around
## `center` (36 directions each, every ring from its own random angle, so a
## narrow path missed on one ring is found on the next); INF when none.
func _ring_spot(center: Vector3, radii: Array) -> Vector3:
	for r: float in radii:
		var start: float = rng.randf() * TAU
		for k in 36:
			var ang: float = start + k * TAU / 36.0
			var p: Vector3 = center + Vector3(cos(ang), 0, sin(ang)) * r
			if can_spawn_at(p):
				return p
	return Vector3.INF


func _spawn_enemy() -> void:
	if horde.count >= GameData.MAX_ALIVE:
		return
	spawn_requests += 1
	for attempt in 12:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(GameData.SPAWN_MIN_DIST, GameData.SPAWN_MAX_DIST)
		var p: Vector3 = player_pos + Vector3(cos(ang), 0, sin(ang)) * dist
		if can_spawn_at(p):
			horde.add(p, director.pick_kind(), rng)
			return
	# Near the edge of a play area, on a narrow path or a pier most of the
	# ring is blocked and 12 random tries can all miss: scan rings (out to
	# 60 m) so the pressure keeps up there too.
	spawn_fallbacks += 1
	var mid: float = (GameData.SPAWN_MIN_DIST + GameData.SPAWN_MAX_DIST) * 0.5
	var spot: Vector3 = _ring_spot(player_pos, [mid, GameData.SPAWN_MIN_DIST, GameData.SPAWN_MAX_DIST, 52.0, 60.0])
	if spot == Vector3.INF:
		spawn_failures += 1
		return
	horde.add(spot, director.pick_kind(), rng)


## Objective text for the HUD.
func objective_text() -> String:
	match objective:
		Objective.GENERATORS:
			if mission == &"defend":
				return "Hold the uplink zone (%d / %d s)" % [int(defend_time), int(GameData.DEFEND_TIME)]
			if mission == &"holdout":
				return "Hold the fort courtyard (%d / %d s)" % [int(defend_time), int(hold_time())]
			if mission == &"rescue":
				return "Find the survivor"
			var done: int = 0
			for p in generator_progress:
				if p >= GameData.GENERATOR_HOLD_SECONDS:
					done += 1
			return "Activate the generators (%d/%d)" % [done, GameData.GENERATOR_COUNT]
		Objective.BOSS:
			return "Kill the Behemoth!"
		Objective.RETURN_TO_BOAT:
			if boat_eta > 0.0:
				return "The boat is coming (%d s): make for the pier!" % ceili(boat_eta)
			if mission == &"holdout":
				return "Board the rescue boat!"
			var where: String = "to the boat"
			if has_exit():
				where = "to " + exit_label if exit_label != "" else "out along the path"
			if mission == &"rescue" and survivor_found and not survivor_lost:
				return "Escort the survivor %s! (HP %d)" % [where, int(survivor_hp)]
			if has_exit():
				return _exit_order() + "!"
			return "Return to the boat!"
		Objective.WON:
			return "Extracted!"
	return "You died"
