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
var card_offers: CardOffers
var _element_rng := RandomNumberGenerator.new()
var power_ups: PowerUps
var power_ups_picked: Array[StringName] = []
var _intel_checkpoint: int = 0
var _power_up_intel_bonus: int = 0

# Player
var player_pos: Vector3
var facing: Vector3 = Vector3(0, 0, -1)
var max_hp: float = GameData.PLAYER_MAX_HP
var hp: float = GameData.PLAYER_MAX_HP
var shield: float = 0.0
var max_shield: float = GameData.PLAYER_MAX_SHIELD
var perks: Array[StringName] = []
var threat: int = 1
var modifier: StringName = &"calm"
var grenade_cd: float = 0.0
## Grenades in flight/fuse: position of impact and remaining fuse time.
var grenades: PackedVector3Array = PackedVector3Array()
var grenade_fuses: PackedFloat32Array = PackedFloat32Array()
var level: int = 1
var xp: int = 0
var xp_fraction: float = 0.0
var breaker_cd: float = 0.0
var dash_time: float = 0.0
var dash_dir: Vector3 = Vector3.ZERO
var invulnerable: float = 0.0
## Debug noclip (Mouse 4/5): move through walls and sea, faster, no damage.
var noclip: bool = false
var player_class: StringName = &"recruit"
var hazard_pay: bool = false  ## boat briefing deal (see RunContext)
var war_cry_time: float = 0.0  ## > 0 while War Cry reduces damage taken
var battle_rhythm_time: float = 0.0
var _last_damage_time: float = 0.0
var _stationary: bool = true
## Poison clouds: position and seconds remaining (not enemy indices).
var toxic_clouds: PackedVector3Array = PackedVector3Array()
var toxic_cloud_times: PackedFloat32Array = PackedFloat32Array()
var stamina: float = GameData.STAMINA_MAX
var sprinting: bool = false
var _stamina_delay: float = 0.0
## Crosshair aim (first / third person camera): the camera's ray through the
## screen centre, in world metres (y includes the terrain height). A zero
## direction means no crosshair (fixed camera): auto-fire aims with the body.
var crosshair_origin: Vector3 = Vector3.ZERO
var crosshair_dir: Vector3 = Vector3.ZERO

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
## Bumps on every new card offer (level-up or reroll), even when the cards
## drawn are the same: the HUD refreshes and locks input per offer.
var card_offer: int = 0
## Card rerolls left in the run (carried between islands, see GameData.REROLLS_*).
var rerolls: int = GameData.REROLLS_START
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
var landed_time: float = 0.0  ## time_alive when this island started
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
	card_offers = CardOffers.new(rng_seed)
	power_ups = PowerUps.new(rng_seed)
	_element_rng.seed = rng_seed ^ 0x454c454d
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
	shield = ctx.shield
	max_shield = ctx.max_shield
	power_ups = PowerUps.new(ctx.rng_seed)
	power_ups.restore(ctx.power_up_state)
	level = ctx.level
	xp = ctx.xp
	xp_fraction = ctx.xp_fraction
	card_offers = CardOffers.new(ctx.rng_seed)
	if ctx.card_rng_state != 0:
		card_offers.rng.state = ctx.card_rng_state
	card_stacks = ctx.card_stacks.duplicate()
	if ctx.ammo.size() == ammo.size():
		ammo = ctx.ammo.duplicate()
	kills = ctx.kills
	_kills_at_start = kills
	headshots = ctx.headshots
	time_alive = ctx.time_alive
	_last_damage_time = time_alive
	landed_time = time_alive
	rerolls = context_rerolls(ctx)
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
		"intel": intel_earned(), "intel_hazard": intel_hazard_share(), "caches_opened": caches_opened(),
		"cards_picked": cards_picked.map(func(x: StringName) -> String: return String(x)),
		"power_ups": power_ups_picked.map(func(x: StringName) -> String: return String(x)),
		"power_up_intel_bonus": _power_up_intel_bonus, "shield_left": int(shield),
	})
	ctx.intel += intel_earned()
	ctx.hazard_pay = false  # one island only
	ctx.lore_found += lore_found
	ctx.hp = clampf(hp, 1.0, max_hp)
	ctx.max_hp = max_hp
	ctx.shield = shield
	ctx.max_shield = max_shield
	ctx.power_up_state = power_ups.snapshot()
	ctx.level = level
	ctx.xp = xp
	ctx.xp_fraction = xp_fraction
	ctx.card_rng_state = card_offers.rng.state
	ctx.card_stacks = card_stacks.duplicate()
	ctx.ammo = ammo.duplicate()
	ctx.kills = kills
	ctx.headshots = headshots
	ctx.time_alive = time_alive
	# A cleared island that is not the last earns a reroll (capped).
	var banked: int = rerolls
	if objective == Objective.WON and not ctx.is_last_island():
		banked = mini(GameData.REROLLS_MAX, banked + GameData.REROLLS_PER_ISLAND)
	set_context_rerolls(ctx, banked)


## Rerolls left in a run context. RunContext has no field for them yet, so
## they ride along as metadata until it gets one (`rerolls`).
static func context_rerolls(ctx: RunContext) -> int:
	if &"rerolls" in ctx:
		return int(ctx.get(&"rerolls"))
	return int(ctx.get_meta(&"rerolls", GameData.REROLLS_START))


static func set_context_rerolls(ctx: RunContext, n: int) -> void:
	if &"rerolls" in ctx:
		ctx.set(&"rerolls", n)
	else:
		ctx.set_meta(&"rerolls", n)


func max_ammo(w: int) -> int:
	var m: int = weapons[w].max_ammo
	if m > 0 and has_perk(&"pack_rat"):
		m = m * 3 / 2
	if m > 0:
		m = int(m * (1.0 + 0.15 * stacks(&"bigger_mags")))
	if m > 0 and modifier == &"short":
		m /= 2
	return m


func has_perk(id: StringName) -> bool:
	return perks.has(id)


func grenade_cooldown_total() -> float:
	return GameData.GRENADE_COOLDOWN * (0.65 if has_perk(&"demolitions") else 1.0) * pow(0.9, stacks(&"grenadier"))


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
				horde.knock_back(i, player_pos, 1.0 + 0.4 * stacks(&"intimidation"))
			war_cry_time = GameData.WAR_CRY_TIME
			_heal_player(5.0 * stacks(&"rally"))
			battle_rhythm_time = 3.0 if stacks(&"battle_rhythm") > 0 else 0.0
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
		if horde.kinds[i] == GameData.EnemyKind.SCREAMER and horde.stun[i] <= 0.0 and horde.freeze_time[i] <= 0.0 \
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
	var radius: float = GameData.GRENADE_RADIUS + (1.0 if has_perk(&"demolitions") else 0.0) + 0.4 * stacks(&"wide_blast")
	var i: int = grenades.size() - 1
	while i >= 0:
		grenade_fuses[i] -= dt
		if grenade_fuses[i] <= 0.0:
			var p: Vector3 = grenades[i]
			explosions.append(p)
			for j in horde.query_radius(p, radius):
				_damage(j, GameData.GRENADE_DAMAGE, p, false, true)
				horde.stun[j] = maxf(horde.stun[j], 0.6 + 0.25 * stacks(&"concussion"))
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
	return (0.7 if player_class == &"vanguard" else 1.0) * GameData.BREAKER_COOLDOWN * pow(0.9, stacks(&"quick_breaker"))


## Intel earned on this island so far. with_hazard = false leaves out the
## hazard pay +25% (for the debrief's split).
func intel_earned(with_hazard: bool = true) -> int:
	_sync_intel_bonus()
	var base: int = _intel_base() + _power_up_intel_bonus
	var hazard: float = GameData.HAZARD_INTEL_MULT if hazard_pay and with_hazard else 1.0
	return int(base * GameData.threat_intel(threat) * GameData.modifier(modifier).intel_mult * hazard)


func _intel_base() -> int:
	var extracted: bool = objective == Objective.WON and hp > 0.0
	var done: int = 0
	for p in generator_progress:
		if p >= GameData.GENERATOR_HOLD_SECONDS:
			done += 1
	var base: int = (kills - _kills_at_start) / 5 + (40 if extracted else 0)
	match mission:
		&"defend", &"holdout":
			base += 45 if defend_time >= hold_time() else int(defend_time / hold_time() * 30.0)
		&"rescue":
			base += 40 if survivor_found and not survivor_lost and extracted else 0
		_:
			base += done * 15
	base += 20 if boss_killed else 0
	base += cache_intel
	return base


## Credit only newly earned Intel during the buff. Expiry never removes it.
func _sync_intel_bonus() -> void:
	var current: int = _intel_base()
	if power_ups.double_time > 0.0:
		_power_up_intel_bonus += maxi(0, current - _intel_checkpoint)
	_intel_checkpoint = current


## The hazard pay share of intel_earned(): total minus the same Intel
## without the +25%, both truncated as the game pays them (the debrief
## cannot recover it by dividing the truncated total).
func intel_hazard_share() -> int:
	return intel_earned() - intel_earned(false)


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
	if stacks(c.id) >= c.max_stacks:
		return
	card_stacks[c.id] = mini(c.max_stacks, stacks(c.id) + 1)
	if c.id == &"thick_hide":
		max_hp += 15.0
		hp = minf(max_hp, hp + 15.0)
	cards_picked.append(c.id)
	messages.append("Card: " + c.title)
	card_choices.clear()
	_roll_cards_if_needed()


## Spends a reroll to redraw the current card offer (other cards when the
## deck has enough). False when there is no offer or no reroll left.
func reroll_cards() -> bool:
	if card_choices.is_empty() or rerolls <= 0:
		return false
	rerolls -= 1
	var previous: Array[GameData.Card] = card_choices.duplicate()
	card_choices.clear()
	_draw_cards(previous)
	return true


## One simulation step. move = desired direction (x, z), aim = facing on XZ.
func step(dt: float, move: Vector2, aim: Vector3, breaker: bool, sprint: bool = false) -> void:
	if is_paused():
		return
	_sync_intel_bonus()
	power_ups.tick(dt)
	time_alive += dt
	_hp_at_step_start = hp
	var aim_flat := Vector3(aim.x, 0, aim.z)
	if aim_flat.length_squared() > 0.0001:
		facing = aim_flat.normalized()
	_update_stamina(dt, sprint and move.length_squared() > 0.01)
	var before_move: Vector3 = player_pos
	_update_player(dt, move, breaker)
	_collect_power_up()
	_stationary = player_pos.distance_squared_to(before_move) < 0.000001
	horde.set_target(player_pos)
	horde.tick(dt)
	if invulnerable <= 0.0 and dash_time <= 0.0:
		var melee: float = minf(horde.damage_to_player, GameData.MAX_MELEE_PER_FRAME)
		_take_player_damage(melee * (0.6 if war_cry_time > 0.0 else 1.0))
	war_cry_time = maxf(0.0, war_cry_time - dt)
	battle_rhythm_time = maxf(0.0, battle_rhythm_time - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	if not sprinting:
		_auto_fire(dt)
	_update_grenades(dt)
	_update_screamers(dt)
	_update_states(dt)
	_flush_dead()
	_recycle_far(dt)
	_update_orbs(dt)
	_update_mission(dt)
	_update_caches(dt)
	_update_lava(dt)
	_regenerate(dt)
	var near: int = horde.query_radius(player_pos, 6.0).size()
	var to_spawn: int = director.update(dt, horde.count, horde.damage_to_player, near)
	if power_ups.spawn_delay > 0.0:
		to_spawn = 0
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
	_sync_intel_bonus()


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
		var radius: float = breaker_radius()
		for i in horde.query_radius(player_pos, radius):
			horde.stun[i] = maxf(horde.stun[i], GameData.BREAKER_STUN + 0.2 * stacks(&"aftershock"))
			horde.knock_back(i, player_pos, 0.6 + 0.4 * stacks(&"crowd_splitter"))
		if dash_time <= 0.0:
			_breaker_impact(radius)
		return
	if grabbed:
		return
	if move.length_squared() > 1.0:
		move = move.normalized()
	var v: Vector2 = move * GameData.PLAYER_SPEED * (1.0 + 0.04 * stacks(&"light_boots")) * (GameData.SPRINT_MULTIPLIER if sprinting else 1.0) * dt
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
	var dmg: float = GameData.BREAKER_DAMAGE + 15.0 * stacks(&"shockwave")
	for i in horde.query_radius(player_pos, radius):
		_damage(i, dmg, player_pos, false, true)
	_flush_dead()


func _auto_fire(dt: float) -> void:
	var w: GameData.Weapon = weapons[weapon_index]
	var rate: float = fire_rate()
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


func fire_rate() -> float:
	var bonus: float = 0.0
	if weapons[weapon_index].id == &"rifle":
		bonus += 0.08 * stacks(&"fast_hands")
		if _stationary:
			bonus += 0.08 * stacks(&"steady_aim")
	if battle_rhythm_time > 0.0:
		bonus += 0.08 * stacks(&"battle_rhythm")
	return weapons[weapon_index].fire_rate * (1.0 + bonus)


func breaker_radius() -> float:
	return GameData.BREAKER_RADIUS * (1.0 + 0.2 * stacks(&"shockwave"))


func _take_player_damage(amount: float) -> void:
	if amount > 0.0 and not noclip:
		var absorbed: float = minf(shield, amount)
		shield -= absorbed
		hp -= amount - absorbed
		_last_damage_time = time_alive


func add_shield(amount: float) -> void:
	shield = clampf(shield + maxf(0.0, amount), 0.0, max_shield)


func _has_finite_weapon() -> bool:
	for i in weapons.size():
		if weapon_unlocked[i] and weapons[i].max_ammo > 0:
			return true
	return false


func _collect_power_up() -> void:
	if power_ups.ground_kind == &"" or hp <= 0.0:
		return
	var d := Vector2(player_pos.x - power_ups.ground_pos.x, player_pos.z - power_ups.ground_pos.z)
	if d.length() > GameData.POWER_UP_PICKUP_RADIUS:
		return
	var kind: StringName = power_ups.ground_kind
	power_ups.ground_kind = &""
	power_ups.ground_time = 0.0
	apply_power_up(kind)


func apply_power_up(kind: StringName) -> void:
	if not GameData.POWER_UP_IDS.has(kind):
		return
	_sync_intel_bonus()
	power_ups_picked.append(kind)
	messages.append("%s!" % GameData.POWER_UP_NAMES[kind])
	match kind:
		&"insta_kill":
			power_ups.insta_time = GameData.POWER_UP_ACTIVE_SECONDS
		&"double_rewards":
			power_ups.double_time = GameData.POWER_UP_ACTIVE_SECONDS
		&"nuke":
			power_ups.spawn_delay = GameData.POWER_UP_SPAWN_DELAY
			explosions.append(player_pos)
			for i in horde.query_radius(player_pos, GameData.POWER_UP_NUKE_RADIUS):
				if _dead.has(i) or not _line_of_sight(player_pos, horde.positions[i]):
					continue
				var kind_id: int = horde.kinds[i]
				var max_health: float = boss_max_hp if kind_id == GameData.EnemyKind.BOSS and boss_max_hp > 0.0 else horde.types[kind_id].hp * horde.hp_scale
				var amount: float = horde.hp[i] if GameData.power_up_normal(kind_id) else max_health * GameData.POWER_UP_NUKE_HP_SHARE
				_damage(i, amount, player_pos, false, true, true)
		&"full_power":
			breaker_cd = 0.0
			grenade_cd = 0.0
		&"max_armor":
			add_shield(max_shield)
		&"fire_sale":
			rerolls = mini(GameData.REROLLS_MAX, rerolls + 1)
		&"max_ammo":
			for i in weapons.size():
				if weapon_unlocked[i] and weapons[i].max_ammo > 0:
					ammo[i] = max_ammo(i)


func _regenerate(dt: float) -> void:
	if hp <= 0.0:
		return
	var active: float = minf(dt, maxf(0.0, time_alive - _last_damage_time - 5.0))
	_heal_player(active * 0.5 * stacks(&"catch_your_breath"))


func _heal_player(amount: float) -> void:
	if amount > 0.0 and hp < max_hp:
		hp = minf(max_hp, hp + amount)


## Sets the crosshair ray (world metres); see crosshair_dir.
func set_crosshair(origin: Vector3, dir: Vector3) -> void:
	crosshair_origin = origin
	crosshair_dir = dir.normalized() if dir.length_squared() > 0.000001 else Vector3.ZERO


func clear_crosshair() -> void:
	crosshair_dir = Vector3.ZERO


func uses_crosshair() -> bool:
	return crosshair_dir != Vector3.ZERO


## Fixed camera: best visible enemy inside the body's aim cone. Score =
## distance + 0.4 m per degree off the facing direction, so turning towards
## an enemy (a special, the boss) makes it the target ("aim with your body").
## Enemies within 2.5 m always win: whoever is biting you gets shot first.
## First / third person: the enemy under the crosshair (_pick_crosshair_target).
func _pick_target(range_m: float) -> int:
	if uses_crosshair():
		return _pick_crosshair_target(range_m)
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


## Visible enemy in range under the crosshair: the angular gap between the
## crosshair ray and the enemy's body (a vertical capsule from the feet to
## the head, as seen from the camera) is below GameData.CROSSHAIR_CONE_DEG.
## The smallest gap wins (the nearer one if the ray is on several bodies).
## Enemies behind the player (between a shoulder camera and the soldier) and
## enemies hidden by a building or a hill are ignored. -1 = no target, so
## aiming at the ground or the sky with nobody there fires nothing.
func _pick_crosshair_target(range_m: float) -> int:
	var best: int = -1
	var best_score: float = deg_to_rad(GameData.CROSSHAIR_CONE_DEG)
	var ahead := Vector3(crosshair_dir.x, 0, crosshair_dir.z)
	for i in horde.query_radius(player_pos, range_m):
		if _dead.has(i):
			continue
		var to: Vector3 = horde.positions[i] - player_pos
		if Vector3(to.x, 0, to.z).dot(ahead) <= 0.0:
			continue
		var aim: Vector3 = _crosshair_body_point(i)
		var v: Vector3 = aim - crosshair_origin
		var dist: float = v.length()
		if dist < 0.01:
			continue
		var t: GameData.EnemyType = horde.types[horde.kinds[i]]
		# Gap to the body's silhouette (0 when the ray is on it), plus a tiny
		# distance term so the front one of a line of bodies wins.
		var gap: float = maxf(0.0, crosshair_dir.angle_to(v) - atan(GameData.CROSSHAIR_BODY_RADIUS * t.radius_scale / dist))
		var score: float = gap + dist * 0.00001
		if score >= best_score:
			continue
		if not _line_of_sight(player_pos, horde.positions[i]) or not _above_ground(crosshair_origin, aim):
			continue
		best = i
		best_score = score
	return best


## Point of enemy i's vertical axis (feet + 0.2 m up to the head centre)
## closest to the crosshair ray.
func _crosshair_body_point(i: int) -> Vector3:
	var p: Vector3 = horde.positions[i]
	var head: Vector3 = enemy_head(i)
	var low := Vector3(p.x, p.y + map.ground_y(p) + 0.2, p.z)
	var seg: Vector3 = head - low
	# Closest points between the lines origin + s * dir (dir is unit length)
	# and low + u * seg: u = (seg.w - b * dir.w) / (seg.seg - b * b).
	var w: Vector3 = crosshair_origin - low
	var b: float = crosshair_dir.dot(seg)
	var denom: float = seg.dot(seg) - b * b
	var u: float = 1.0
	if denom > 0.000001:
		u = (seg.dot(w) - b * crosshair_dir.dot(w)) / denom
	return low + seg * clampf(u, 0.0, 1.0)


## No terrain between a and b (sampled every metre; buildings are checked on
## the grid by _line_of_sight).
func _above_ground(a: Vector3, b: Vector3) -> bool:
	var n: int = ceili(a.distance_to(b))
	for k in range(1, n):
		var p: Vector3 = a.lerp(b, float(k) / n)
		if p.y < map.ground_y(p) - 0.1:
			return false
	return true


## World position (terrain height included) of an enemy's chest and head, as
## the Island scene draws them (body capsule of t.height, head on top).
func enemy_chest(i: int) -> Vector3:
	var p: Vector3 = horde.positions[i]
	var t: GameData.EnemyType = horde.types[horde.kinds[i]]
	return Vector3(p.x, p.y + map.ground_y(p) + t.height * 0.6, p.z)


func enemy_head(i: int) -> Vector3:
	var p: Vector3 = horde.positions[i]
	var t: GameData.EnemyType = horde.types[horde.kinds[i]]
	return Vector3(p.x, p.y + map.ground_y(p) + t.height + 0.08 * t.radius_scale, p.z)


## Would a shot at `target` now be a headshot? Fixed camera: the target sits
## where the body faces. Crosshair: the ray passes close to the head.
func _is_headshot(target: int) -> bool:
	if uses_crosshair():
		var v: Vector3 = enemy_head(target) - crosshair_origin
		var along: float = v.dot(crosshair_dir)
		if along <= 0.0:
			return false
		var t: GameData.EnemyType = horde.types[horde.kinds[target]]
		var radius: float = GameData.CROSSHAIR_HEAD_RADIUS * t.radius_scale
		if has_perk(&"head_hunter"):
			radius *= 15.0 / GameData.HEADSHOT_CONE_DEG
		return (v - crosshair_dir * along).length() <= radius
	var to: Vector3 = horde.positions[target] - player_pos
	to.y = 0.0
	return facing.dot(to.normalized()) >= headshot_cone_cos()


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


func _fire(w: GameData.Weapon, target: int) -> void:
	if w.id == &"rifle":
		_shots += 1
	if w.max_ammo > 0:
		ammo[weapon_index] -= 1
	var to: Vector3 = horde.positions[target] - player_pos
	to.y = 0.0
	var dir: Vector3 = to.normalized()
	var headshot: bool = _is_headshot(target)
	var rifle: bool = w.id == &"rifle"
	var dmg: float = w.damage * (1.0 + 0.10 * stacks(&"hollow_points") if rifle else 1.0)
	var pierce: int = w.pierce + (stacks(&"piercing_rounds") if rifle else 0)
	var direct_hits: Array[int] = []
	var ricochet_damage: float = dmg
	for p in w.pellets:
		var pellet_dir: Vector3 = dir
		if w.spread_deg > 0.0:
			pellet_dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-w.spread_deg, w.spread_deg) * 0.5))
		var hits: Array[Vector2] = horde.hitscan(player_pos, pellet_dir, w.range_m, pierce)
		var end: Vector3 = player_pos + pellet_dir * w.range_m
		for h in hits:
			var idx: int = int(h.y)
			end = player_pos + pellet_dir * h.x
			if _dead.has(idx):
				continue
			var is_head: bool = headshot and idx == target
			var hit_damage: float = dmg * (GameData.HEADSHOT_MULTIPLIER if is_head else 1.0)
			if rifle:
				if horde.positions[idx].distance_to(player_pos) <= 4.0:
					hit_damage *= 1.0 + 0.10 * stacks(&"point_blank")
				var full_hp: float = horde.types[horde.kinds[idx]].hp * horde.hp_scale
				if horde.hp[idx] < full_hp * 0.3:
					hit_damage *= 1.0 + 0.15 * stacks(&"finish_the_job")
				_apply_elements(idx, hit_damage)
			_damage(idx, hit_damage, player_pos, is_head, false, false, rifle)
			direct_hits.append(idx)
			if idx == target:
				ricochet_damage = hit_damage
			horde.knock_back(idx, player_pos, w.knockback + (0.15 * stacks(&"wind_rounds") if rifle else 0.0))
		tracers.append(PackedVector3Array([player_pos, end]))
	if rifle and direct_hits.has(target) and stacks(&"ricochet") > 0 and _shots % 4 == 0:
		_chain_hit(target, stacks(&"ricochet"), ricochet_damage * 0.6, direct_hits)


func _damage(i: int, amount: float, from: Vector3, headshot: bool, breaker: bool,
		secondary: bool = false, rifle_hit: bool = false) -> void:
	if _dead.has(i):
		return
	var t: GameData.EnemyType = horde.types[horde.kinds[i]]
	if power_ups.insta_time > 0.0 and not breaker and not secondary:
		amount = maxf(amount, horde.hp[i]) if GameData.power_up_normal(horde.kinds[i]) else amount * GameData.POWER_UP_STRONG_DAMAGE_MULT
	if t.front_armor > 0.0 and not breaker:
		# Armoured enemies take reduced damage from the front (where they walk to).
		var v: Vector3 = horde.velocities[i]
		var to_src: Vector3 = from - horde.positions[i]
		if v.length_squared() > 0.01 and v.normalized().dot(to_src.normalized()) > 0.3:
			amount *= 1.0 - t.front_armor
	if stacks(&"executioner") > 0 and (horde.stun[i] > 0.0 or horde.freeze_time[i] > 0.0):
		amount *= 1.0 + 0.2 * stacks(&"executioner")
	horde.hp[i] -= amount
	if not secondary:
		horde.flash[i] = 0.1  # DOT must not hide the status tint with a constant flash
	if horde.hp[i] <= 0.0:
		_dead[i] = true
		kills += 1
		_sync_intel_bonus()
		power_ups.on_kill(horde.kinds[i], horde.positions[i], time_alive, field, play_area, _has_finite_weapon())
		if stacks(&"adrenaline") > 0:
			breaker_cd = maxf(0.0, breaker_cd - 0.1 * stacks(&"adrenaline"))
		if kills % 10 == 0:
			_heal_player(2.0 * stacks(&"kill_rations"))
		if headshot:
			headshots += 1
		var p: Vector3 = horde.positions[i]
		deaths.append(Vector4(p.x, p.z, horde.kinds[i], 1.0 if headshot else 0.0))
		popups.append(Vector4(p.x, p.z, amount, 1.0 if headshot else 0.0))
		if t.explodes:
			explosions.append(p)
			if player_pos.distance_to(p) <= GameData.BLOATER_RADIUS and dash_time <= 0.0:
				_take_player_damage(GameData.BLOATER_PLAYER_DAMAGE)
			for j in horde.query_radius(p, GameData.BLOATER_RADIUS):
				_damage(j, GameData.BLOATER_DAMAGE, p, false, true, true)
				horde.knock_back(j, p, 1.5)
		orbs.append(p)
		orb_values.append(t.xp)
		if headshot and stacks(&"vampire") > 0:
			_heal_player(stacks(&"vampire"))
		if headshot:
			stamina = minf(GameData.STAMINA_MAX, stamina + 0.1 * stacks(&"second_breath"))
		if headshot and rifle_hit and not secondary and stacks(&"explosive_heads") > 0:
			explosions.append(p)
			for j in horde.query_radius(p, 3.0):
				_damage(j, 15.0 + 15.0 * stacks(&"explosive_heads"), p, false, true, true)
		if not secondary:
			if horde.burn_time[i] > 0.0:
				var used: Array[int] = [i]
				for bounce in stacks(&"wildfire"):
					var next: int = _nearest_enemy(p, 6.0, used)
					if next == -1:
						break
					used.append(next)
					horde.burn_time[next] = 3.0  # spread is secondary: no duo recursion
			if horde.poison_time[i] > 0.0 and stacks(&"toxic_cloud") > 0:
				toxic_clouds.append(p)
				toxic_cloud_times.append(1.0 + stacks(&"toxic_cloud"))


## Only direct rifle hits roll elements. Damage from states/chains/clouds
## is explicitly secondary and cannot produce another card effect.
func _apply_elements(i: int, hit_damage: float) -> void:
	if _dead.has(i):
		return
	if _element_proc(&"fire_rounds"):
		_apply_fire(i)
	if not _dead.has(i) and _element_proc(&"frost_rounds"):
		_apply_cold(i)
	if not _dead.has(i) and _element_proc(&"toxic_rounds"):
		horde.poison_time[i] = 4.0
	if not _dead.has(i) and _element_proc(&"storm_rounds"):
		var jumps: int = 1 + stacks(&"chain_lightning")
		if stacks(&"frost_rounds") > 0 and horde.cold_stacks[i] > 0:
			jumps += 1  # Conductive Frost: one bonus jump per discharge
		_chain_hit(i, jumps, hit_damage * 0.6, [i])


func _element_proc(id: StringName) -> bool:
	var rank: int = stacks(id)
	return rank > 0 and _element_rng.randf() < 0.05 * rank


func _apply_fire(i: int) -> void:
	var p: Vector3 = horde.positions[i]
	if horde.freeze_time[i] > 0.0 and stacks(&"frost_rounds") > 0:
		horde.freeze_time[i] = 0.0
		_damage(i, 30.0, p, false, true, true)  # Thermal Shock
	if not _dead.has(i):
		horde.burn_time[i] = 3.0
	# Toxic Combustion consumes a cloud before applying damage (no recursion).
	for k in range(toxic_clouds.size() - 1, -1, -1):
		if p.distance_to(toxic_clouds[k]) <= 2.0:
			var center: Vector3 = toxic_clouds[k]
			toxic_clouds.remove_at(k)
			toxic_cloud_times.remove_at(k)
			explosions.append(center)
			for j in horde.query_radius(center, 3.0):
				_damage(j, 25.0, center, false, true, true)


func _apply_cold(i: int) -> void:
	horde.cold_time[i] = 4.0
	horde.cold_stacks[i] = mini(3, horde.cold_stacks[i] + 1)
	if horde.cold_stacks[i] >= 3 and horde.kinds[i] != GameData.EnemyKind.BOSS:
		horde.cold_stacks[i] = 0
		horde.cold_time[i] = 0.0
		horde.freeze_time[i] = 1.0 + 0.25 * stacks(&"deep_freeze")
		if horde.grabbed_by == i:
			horde.grabbed_by = -1


func _nearest_enemy(p: Vector3, radius: float, excluded: Array[int]) -> int:
	var nearest: int = -1
	var best: float = INF
	for i in horde.query_radius(p, radius):
		if excluded.has(i) or _dead.has(i):
			continue
		var distance: float = p.distance_squared_to(horde.positions[i])
		if (distance < best or (is_equal_approx(distance, best) and i < nearest)) \
				and _line_of_sight(p, horde.positions[i]):
			nearest = i
			best = distance
	return nearest


func _chain_hit(start: int, jumps: int, damage: float, excluded: Array[int]) -> void:
	var visited: Array[int] = excluded.duplicate()
	if not visited.has(start):
		visited.append(start)
	var p: Vector3 = horde.positions[start]
	for bounce in jumps:
		var next: int = _nearest_enemy(p, 6.0, visited)
		if next == -1:
			break
		visited.append(next)
		var q: Vector3 = horde.positions[next]
		tracers.append(PackedVector3Array([p, q]))
		_damage(next, damage, p, false, false, true)
		p = q


func _update_states(dt: float) -> void:
	for i in horde.count:
		if _dead.has(i):
			continue
		var burn: float = minf(dt, horde.burn_time[i])
		var poison: float = minf(dt, horde.poison_time[i])
		if burn > 0.0:
			_damage(i, burn * 8.0, horde.positions[i], false, true, true)
		if poison > 0.0:
			_damage(i, poison * 6.0, horde.positions[i], false, true, true)
		horde.burn_time[i] = maxf(0.0, horde.burn_time[i] - dt)
		horde.poison_time[i] = maxf(0.0, horde.poison_time[i] - dt)
		horde.freeze_time[i] = maxf(0.0, horde.freeze_time[i] - dt)
		horde.cold_time[i] = maxf(0.0, horde.cold_time[i] - dt)
		if horde.cold_time[i] <= 0.0:
			horde.cold_stacks[i] = 0
	for k in range(toxic_clouds.size() - 1, -1, -1):
		var active: float = minf(dt, toxic_cloud_times[k])
		for i in horde.query_radius(toxic_clouds[k], 2.0):
			_damage(i, active * 6.0, toxic_clouds[k], false, true, true)
		toxic_cloud_times[k] = maxf(0.0, toxic_cloud_times[k] - dt)
		if toxic_cloud_times[k] <= 0.0:
			toxic_clouds.remove_at(k)
			toxic_cloud_times.remove_at(k)


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
	var radius: float = GameData.PICKUP_RADIUS * (1.0 + 0.4 * stacks(&"magnet"))
	var automatic: bool = level >= GameData.XP_AUTO_COLLECT_LEVEL
	var i: int = orbs.size() - 1
	while i >= 0:
		var o: Vector3 = orbs[i]
		var d: Vector3 = player_pos - o
		d.y = 0.0
		var dist: float = d.length()
		if automatic or dist < 0.8:
			_collect_xp_orb(i)
		elif dist < radius:
			orbs[i] = o + d / dist * minf(dist, 14.0 * dt)
		i -= 1
	_advance_xp_levels()
	# Crossing 30 must collect the remaining ground XP before card choices
	# pause the simulation, rather than waiting until the player picks a card.
	if not automatic and level >= GameData.XP_AUTO_COLLECT_LEVEL:
		for remaining in range(orbs.size() - 1, -1, -1):
			_collect_xp_orb(remaining)
		_advance_xp_levels()
	_roll_cards_if_needed()


func _collect_xp_orb(index: int) -> void:
	var reward_mult: float = 2.0 if power_ups.double_time > 0.0 else 1.0
	var earned: float = orb_values[index] * reward_mult * (1.0 + 0.05 * stacks(&"fast_learner")) + xp_fraction
	var whole: int = floori(earned + 0.000001)
	xp += whole
	xp_fraction = maxf(0.0, earned - whole)
	_heal_player(0.2 * stacks(&"field_dressing"))
	orbs.remove_at(index)
	orb_values.remove_at(index)


func _advance_xp_levels() -> void:
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		_pending_levels += 1


func _roll_cards_if_needed() -> void:
	if _pending_levels <= 0 or not card_choices.is_empty():
		return
	_pending_levels -= 1
	if not _draw_cards([]):
		# Every card maxed: levelling up still heals.
		hp = minf(max_hp, hp + 20.0)
		messages.append("Level up: +20 HP")
		_roll_cards_if_needed()


## Fills card_choices with up to 3 cards that are not maxed, avoiding
## `avoid` (the offer being rerolled) while the deck has others left.
func _draw_cards(avoid: Array[GameData.Card]) -> bool:
	var owned: Array[StringName] = []
	for i in weapons.size():
		if weapon_unlocked[i]:
			owned.append(weapons[i].id)
	var excluded: Array[StringName] = []
	for c in avoid:
		excluded.append(c.id)
	card_choices = card_offers.draw(all_cards, player_class, owned, card_stacks, excluded)
	if card_choices.is_empty():
		return false
	card_offer += 1
	return true


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
			_take_player_damage(GameData.LAVA_PLAYER_DPS * dt)
		for i in horde.query_radius(c, r):
			if horde.kinds[i] != GameData.EnemyKind.BOSS:
				_damage(i, GameData.LAVA_ENEMY_DPS * dt, c, false, true, true)
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
				_take_player_damage(GameData.BOSS_SLAM_DAMAGE)
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
				_take_player_damage(GameData.BOSS_ROCK_DAMAGE)
			rocks.remove_at(r)
			rock_times.remove_at(r)
			rock_origins.remove_at(r)
		r -= 1
	if _summon_cd <= 0.0 and power_ups.spawn_delay <= 0.0:
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
	if horde.count >= GameData.MAX_ALIVE or power_ups.spawn_delay > 0.0:
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
