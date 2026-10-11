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
## Spawn positions have their own RNG (derived from the run seed), so the
## same seed gives the same spawn spots whatever else used `rng`.
var _spawn_rng := RandomNumberGenerator.new()
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
## Rank (1..3) of each equipped perk; only equipped perks act.
var perk_ranks: Dictionary = {}
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
## Perk timers: Opening Volley after a Breaker, Quick Draw after switching
## to the secondary (and its internal cooldown), Skirmisher "firing" window.
var opening_volley_time: float = 0.0
var quick_draw_time: float = 0.0
var _quick_draw_cd: float = 0.0
var _firing_time: float = 0.0
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
## Cells that block the VIEW (row-major, 1 = blocked): buildings, rocks and
## trees. The flow field also blocks the sea, steep slopes and the outside
## of a play area, which the camera and the bullets see / fly over (hills
## are checked by height, _above_ground). Built in _init (_build_sight).
var sight_blocked: PackedByteArray = PackedByteArray()
# Per-shot caches of the crosshair broad phase (_shot_candidates).
var _shot_low := PackedVector3Array()
var _shot_seg := PackedVector3Array()
var _shot_r := PackedFloat32Array()
var _shot_los: Dictionary = {}  ## enemy index -> the soldier's line is clear

# Weapons
var weapons: Array[GameData.Weapon] = GameData.loadout(GameData.starting_weapons())
var weapon_index: int = 0
## Which weapons can be used this run (locked ones are skipped).
var weapon_unlocked: Array[bool] = []
var ammo: PackedInt32Array = PackedInt32Array()
## Rounds left in each weapon's magazine (only weapons with a magazine, see
## magazine_size; the others read 0). Every island starts with full magazines.
var mag: PackedInt32Array = PackedInt32Array()
## Independent reload timers; the HUD reads the currently equipped weapon.
var reload_times: PackedFloat32Array = PackedFloat32Array()
var reload_left: float:
	get: return reload_times[weapon_index] if weapon_index < reload_times.size() else 0.0
## True while a Nuke resolves: its kills credit XP/Intel but roll no new drop.
var _nuking: bool = false
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
## Hold Sequence: the points to hold, in order (the map's HoldPoint_*
## markers, else picked per seed), the one being held (== size: all held),
## seconds spent in it (leaving pauses it) and whether its spike fired.
var hold_points: Array[Vector3] = []
var hold_index: int = 0
var hold_progress: float = 0.0
var hold_started: bool = false
## Fuel Run: one entry per fuel can. Its position (where it waits, or the
## player's while carried), its state (CAN_*) and whether its pickup spike
## has fired (only the first pickup calls the horde). `carrying` is the can
## in the player's hands (-1 = none). `_cargo_dropped` is the can just put
## down: walking over it does not pick it up again until the player has
## stepped away (the interact action still does), so dropping to fight
## does not grab it back on the next frame.
const CAN_WAITING: int = 0
const CAN_CARRIED: int = 1
const CAN_DELIVERED: int = 2
var cargo_pos: Array[Vector3] = []
var cargo_state: PackedInt32Array = PackedInt32Array()
var cargo_touched: Array[bool] = []
var carrying: int = -1
var _cargo_dropped: int = -1
## Last spot the player stood on walkable ground (not in noclip): a can
## dropped while flying over a wall lands here instead, so it can't be lost.
var _last_walkable: Vector3 = Vector3.ZERO
## The seed this island was built with (fallback hold points, fuel cans).
var run_seed: int = 7
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
	run_seed = rng_seed
	card_offers = CardOffers.new(rng_seed)
	power_ups = PowerUps.new(rng_seed)
	_element_rng.seed = rng_seed ^ 0x454c454d
	_spawn_rng.seed = rng_seed ^ 0x5350574e
	map = custom_map if custom_map != null else IslandMap.build(rng_seed, biome)
	field = map.field
	horde = Horde.new(field)
	if field.max_distance > 0:
		horde.field_budget = 4000  # big island: a fresher field around the player (~1 ms more per step)
	director = Director.new(rng_seed)
	player_pos = map.player_start
	_last_walkable = player_pos
	field.compute_now(field.world_to_cell(player_pos))
	horde.set_target(player_pos)
	for w in weapons:
		ammo.append(w.max_ammo)
		mag.append(w.magazine)
		weapon_unlocked.append(true)
		reload_times.append(0.0)
	_build_sight()
	for c in map.caches:
		cache_progress.append(0.0)
	for i in GameData.GENERATOR_COUNT:
		generator_progress.append(0.0)
		generator_started.append(false)


## sight_blocked from the map: the real wall cells of a hand-made island (or
## the building rectangles of a generated one), plus rocks and trees.
func _build_sight() -> void:
	var w: int = field.width
	sight_blocked.resize(w * field.height)
	sight_blocked.fill(0)
	if not map.wall_cells.is_empty():
		for i in map.wall_cells:
			sight_blocked[i] = 1
	else:
		for r in map.buildings:
			for z in range(maxi(r.position.y, 0), mini(r.end.y, field.height)):
				for x in range(maxi(r.position.x, 0), mini(r.end.x, w)):
					sight_blocked[z * w + x] = 1
	for c in map.rocks + map.trees:
		if c.x >= 0 and c.y >= 0 and c.x < w and c.y < field.height:
			sight_blocked[c.y * w + c.x] = 1


func sight_is_blocked(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= field.width or z >= field.height:
		return false
	return sight_blocked[z * field.width + x] != 0


## Loads the run state carried from previous islands and scales difficulty.
func load_context(ctx: RunContext) -> void:
	perks = ctx.perks.duplicate()
	perk_ranks = ctx.perk_ranks.duplicate()
	set_mission(ctx.mission)
	exit_label = next_part_name(ctx)
	radio.append(StringName("land_" + String(mission)))
	# The last island has the Behemoth; the expedition's holdout is itself
	# the finale (hold the fort, then the boat), so it has none.
	has_boss = ctx.is_last_island() and mission != &"holdout"
	if has_boss:
		radio.append(&"land_boss")
	player_class = ctx.player_class
	weapons = GameData.loadout(ctx.weapons)
	weapon_index = 0
	mag.clear()
	ammo.clear()
	weapon_unlocked.clear()
	reload_times.clear()
	for entry in weapons:
		mag.append(entry.magazine)
		ammo.append(entry.max_ammo)
		weapon_unlocked.append(true)
		reload_times.append(0.0)
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
	card_offers.blocked_tags = CardOffers.blocked_tags_for(perks)
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


## Magazine capacity of weapon `w` (0 = no magazine). The one place a
## future card ("Extended Mags") would change it; Bigger Mags only raises
## the finite reserve (max_ammo), so the rifle's 30 stays as it is.
func magazine_size(w: int) -> int:
	return weapons[w].magazine


## An empty magazine refills instantly or starts this weapon's timed reload.
func _reload(w: int) -> void:
	reload_times[w] = weapons[w].reload_seconds
	mag[w] = magazine_size(w) if reload_times[w] <= 0.0 else 0


func _update_reloads(dt: float) -> void:
	for w in reload_times.size():
		if reload_times[w] <= 0.0:
			continue
		reload_times[w] = maxf(0.0, reload_times[w] - dt)
		if reload_times[w] <= 0.0:
			mag[w] = magazine_size(w)


## Card bonuses add up first; perks then multiply, and only the
## secondaries' reserve (Pack Rat / Quick Draw).
func max_ammo(w: int) -> int:
	var m: int = weapons[w].max_ammo
	if m > 0:
		m = int(m * (1.0 + 0.15 * stacks(&"bigger_mags")))
	if m > 0 and not weapons[w].primary:
		m = int(m * (1.0 + perk_value(&"pack_rat") / 100.0) * (1.0 - perk_cost(&"quick_draw") / 100.0))
	if m > 0 and modifier == &"short":
		m /= 2
	return m


func has_perk(id: StringName) -> bool:
	return perks.has(id)


## Rank of an equipped perk (0 = not equipped). Contexts from before the
## tree (no ranks) count as rank III.
func perk_rank(id: StringName) -> int:
	return int(perk_ranks.get(id, GameData.PERK_MAX_RANK)) if perks.has(id) else 0


## Benefit (up), second benefit and trade-off (down) totals of an equipped perk.
func perk_value(id: StringName) -> float:
	var perk: GameData.Perk = GameData.perk(id)
	return perk.value(perk_rank(id)) if perk != null else 0.0


func perk_value_2(id: StringName) -> float:
	var perk: GameData.Perk = GameData.perk(id)
	return perk.value_2(perk_rank(id)) if perk != null else 0.0


func perk_cost(id: StringName) -> float:
	var perk: GameData.Perk = GameData.perk(id)
	return perk.cost_value(perk_rank(id)) if perk != null else 0.0


func grenade_cooldown_total() -> float:
	return GameData.GRENADE_COOLDOWN * pow(0.9, stacks(&"grenadier")) * (1.0 - perk_value(&"demolitions") / 100.0)


func grenade_radius() -> float:
	return GameData.GRENADE_RADIUS + perk_value_2(&"demolitions") + 0.4 * stacks(&"wide_blast")


## Demolitions and Concussion trade grenade damage for cooldown/stun.
func grenade_damage() -> float:
	return GameData.GRENADE_DAMAGE * (1.0 - perk_cost(&"demolitions") / 100.0) * (1.0 - perk_cost(&"concussion_blast") / 100.0)


## War Cry protection time: Bulwark adds, Intimidating Cry takes away.
func war_cry_duration() -> float:
	return maxf(0.0, GameData.WAR_CRY_TIME + perk_value(&"bulwark") - perk_cost(&"intimidating_cry"))


## Throws a grenade towards `aim` (vector from the player; its length is the
## throw distance, clamped to the grenade range).
## Uses the class ability (Recruit: grenade, Vanguard: War Cry).
func use_ability(aim: Vector3) -> bool:
	if is_paused():
		return false
	if carrying >= 0:
		# Hands full: the ability button puts the fuel can down instead, so
		# "I want to fight" works without learning the interact key.
		drop_cargo()
		return false
	if grenade_cd > 0.0:
		return false
	match player_class:
		&"vanguard":
			for i in horde.query_radius(player_pos, GameData.WAR_CRY_RADIUS):
				horde.stun[i] = maxf(horde.stun[i], 1.5)
				horde.knock_back(i, player_pos, 1.0 + 0.4 * stacks(&"intimidation") + perk_value(&"intimidating_cry"))
			war_cry_time = war_cry_duration()
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
	if grenade_cd > 0.0 or is_paused() or carrying >= 0:
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
	var radius: float = grenade_radius()
	var i: int = grenades.size() - 1
	while i >= 0:
		grenade_fuses[i] -= dt
		if grenade_fuses[i] <= 0.0:
			var p: Vector3 = grenades[i]
			explosions.append(p)
			for j in horde.query_radius(p, radius):
				_damage(j, grenade_damage(), p, false, true)
				horde.stun[j] = maxf(horde.stun[j], 0.6 + 0.25 * stacks(&"concussion") + perk_value(&"concussion_blast"))
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
	hold_points.clear()
	hold_index = 0
	hold_progress = 0.0
	hold_started = false
	if mission == &"hold_sequence":
		hold_points = map.hold_points.duplicate()
		if hold_points.is_empty():
			hold_points = IslandMap.pick_hold_points(map, hold_count_wanted(), run_seed, hold_radius())
		if hold_points.is_empty():
			hold_points.append(site)  # a map too small to pick from: one point
		site = hold_points[0]
	cargo_pos.clear()
	cargo_state.clear()
	cargo_touched.clear()
	carrying = -1
	_cargo_dropped = -1
	if mission == &"fuel_run":
		cargo_pos = map.cargo_points.duplicate()
		if cargo_pos.is_empty():
			cargo_pos = IslandMap.pick_cargo_points(map, cargo_count_wanted(), run_seed)
		if cargo_pos.is_empty():
			cargo_pos.append(site)  # a map too small to pick from: one can
		for c in cargo_pos.size():
			cargo_state.append(CAN_WAITING)
			cargo_touched.append(false)
		site = fuel_goal()


## Fuel Run numbers, from the mission's data (fuel_run.tres).
static func cargo_count_wanted() -> int:
	return int(GameData.mission_value(&"fuel_run", "points", 3.0))


static func cargo_pickup_radius() -> float:
	return GameData.mission_value(&"fuel_run", "pickup_radius", 1.8)


static func cargo_delivery_radius() -> float:
	return GameData.mission_value(&"fuel_run", "delivery_radius", 6.0)


static func carry_speed_mult() -> float:
	return GameData.mission_value(&"fuel_run", "carry_speed_mult", 0.8)


static func cargo_spike_seconds() -> float:
	return GameData.mission_value(&"fuel_run", "spike_seconds", 20.0)


## True while the player has a fuel can in their hands (no firing, no
## sprint, no class ability, slower walk).
func is_carrying() -> bool:
	return carrying >= 0


## Fuel cans delivered so far.
func cargo_delivered() -> int:
	var n: int = 0
	for s in cargo_state:
		if s == CAN_DELIVERED:
			n += 1
	return n


## Where the fuel goes: the map's Delivery marker, else the extraction
## point (the boat; the Exit on an expedition part).
func delivery_point() -> Vector3:
	return map.delivery if map.delivery.x >= 0.0 else extraction_point()


## Short name of the delivery point (HUD marker, objective text).
func delivery_name() -> String:
	return "Fuel drop" if map.delivery.x >= 0.0 else extraction_name()


## Where the player should go next in a Fuel Run: the delivery point while
## carrying, else the nearest can still waiting (the delivery point when
## none is left).
func fuel_goal() -> Vector3:
	if carrying >= 0:
		return delivery_point()
	var c: int = nearest_waiting_can()
	return cargo_pos[c] if c >= 0 else delivery_point()


## The waiting can nearest to the player (-1 = none). `reach` > 0: only
## cans within that many metres; `skip`: a can to leave out.
func nearest_waiting_can(reach: float = INF, skip: int = -1) -> int:
	var best: int = -1
	var best_d: float = reach
	for c in cargo_pos.size():
		if cargo_state[c] != CAN_WAITING or c == skip:
			continue
		var d: float = Vector2(cargo_pos[c].x - player_pos.x, cargo_pos[c].z - player_pos.z).length()
		if d <= best_d:
			best_d = d
			best = c
	return best


## The interact action (E / pad X): drops the can being carried, else picks
## up a can within reach (even the one just dropped).
func interact() -> bool:
	if mission != &"fuel_run" or is_paused():
		return false
	if carrying >= 0:
		return drop_cargo()
	var c: int = nearest_waiting_can(cargo_pickup_radius())
	if c == -1:
		return false
	_pick_up_can(c)
	return true


## Puts the carried can down at the player's feet, on walkable ground, so
## the player can fight; it can be picked up again. False if not carrying.
func drop_cargo() -> bool:
	if carrying < 0:
		return false
	var cell: Vector2i = field.world_to_cell(player_pos)
	var spot: Vector3 = Vector3(player_pos.x, 0, player_pos.z)
	if noclip or field.is_blocked(cell.x, cell.y):
		spot = _last_walkable
	cargo_pos[carrying] = spot
	cargo_state[carrying] = CAN_WAITING
	_cargo_dropped = carrying
	carrying = -1
	site = fuel_goal()
	messages.append("Fuel can dropped")
	return true


func _pick_up_can(c: int) -> void:
	carrying = c
	cargo_state[c] = CAN_CARRIED
	_cargo_dropped = -1
	if not cargo_touched[c]:
		cargo_touched[c] = true
		director.trigger_peak(cargo_spike_seconds())
		var where: String = "fuel drop" if map.delivery.x >= 0.0 else ("exit" if has_exit() else "boat")
		messages.append("Fuel can %d of %d: get it to the %s!" % [cargo_delivered() + 1, cargo_pos.size(), where])
		radio.append(&"fuel_pickup")
	else:
		messages.append("Fuel can picked up")
	site = fuel_goal()


## Hold Sequence numbers, from the mission's data (hold_sequence.tres).
static func hold_count_wanted() -> int:
	return int(GameData.mission_value(&"hold_sequence", "points", 3.0))


static func hold_seconds() -> float:
	return GameData.mission_value(&"hold_sequence", "seconds", 20.0)


static func hold_radius() -> float:
	return GameData.mission_value(&"hold_sequence", "radius", 5.0)


## Points held so far (Hold Sequence).
func holds_done() -> int:
	return mini(hold_index, hold_points.size())


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
		&"hold_sequence":
			return hold_index >= hold_points.size()
		&"fuel_run":
			return cargo_delivered() >= cargo_pos.size()
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


## Earned progress includes the fractions banked by Fast Learner.
func xp_progress() -> float:
	return xp + xp_fraction


func fast_learner_bonus() -> float:
	return 0.05 * stacks(&"fast_learner")


func stacks(id: StringName) -> int:
	return card_stacks.get(id, 0)


## Class and cards first; Recovery multiplies; Battering Ram, Heavy Impact
## and Opening Volley add seconds.
func breaker_cooldown_total() -> float:
	var base: float = (0.7 if player_class == &"vanguard" else 1.0) * GameData.BREAKER_COOLDOWN * pow(0.9, stacks(&"quick_breaker"))
	return base * (1.0 - perk_value(&"recovery") / 100.0) \
		+ perk_cost(&"long_breaker") + perk_cost(&"heavy_impact") + perk_cost(&"opening_volley")


func breaker_distance() -> float:
	return GameData.BREAKER_DISTANCE * (1.0 + perk_value(&"long_breaker") / 100.0) \
		* (1.0 - perk_cost(&"crowd_anchor") / 100.0) * (1.0 - perk_cost(&"recovery") / 100.0)


## Walking speed multiplier from perks (cards and the weapon apply apart).
func perk_speed_mult() -> float:
	var mult: float = (1.0 + perk_value(&"fleet_footed") / 100.0) * (1.0 - perk_cost(&"pack_rat") / 100.0)
	if _firing_time > 0.0 and not sprinting:
		mult *= 1.0 + perk_value(&"skirmisher") / 100.0
	if war_cry_time > 0.0:
		mult *= 1.0 - perk_cost(&"bulwark") / 100.0
	return mult


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
		&"hold_sequence":
			base += holds_done() * 15
		&"fuel_run":
			base += cargo_delivered() * 15
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
		_set_weapon(i)


## Next usable weapon (gamepad cycling).
func cycle_weapon() -> void:
	for k in range(1, weapons.size() + 1):
		var i: int = (weapon_index + k) % weapons.size()
		if weapon_unlocked[i] and ammo[i] != 0:
			_set_weapon(i)
			return


## Quick Draw: switching from the primary to the secondary speeds the
## secondary up for a moment, at most once per QUICK_DRAW_COOLDOWN.
func _set_weapon(i: int) -> void:
	var drawing: bool = i != weapon_index and weapons[weapon_index].primary and not weapons[i].primary
	weapon_index = i
	if drawing and has_perk(&"quick_draw") and _quick_draw_cd <= 0.0:
		quick_draw_time = GameData.QUICK_DRAW_SECONDS
		_quick_draw_cd = GameData.QUICK_DRAW_COOLDOWN


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
	_update_reloads(dt)
	time_alive += dt
	_hp_at_step_start = hp
	var aim_flat := Vector3(aim.x, 0, aim.z)
	if aim_flat.length_squared() > 0.0001:
		facing = aim_flat.normalized()
	# A fuel can in the hands: no sprint (and no firing, below).
	_update_stamina(dt, sprint and move.length_squared() > 0.01 and carrying < 0)
	var before_move: Vector3 = player_pos
	_update_player(dt, move, breaker)
	if not noclip:
		var cell: Vector2i = field.world_to_cell(player_pos)
		if not field.is_blocked(cell.x, cell.y):
			_last_walkable = Vector3(player_pos.x, 0, player_pos.z)
	_collect_power_up()
	_stationary = player_pos.distance_squared_to(before_move) < 0.000001
	horde.set_target(player_pos)
	horde.tick(dt)
	if invulnerable <= 0.0 and dash_time <= 0.0:
		var melee: float = minf(horde.damage_to_player, GameData.MAX_MELEE_PER_FRAME)
		_take_player_damage(melee * (0.6 if war_cry_time > 0.0 else 1.0))
	war_cry_time = maxf(0.0, war_cry_time - dt)
	battle_rhythm_time = maxf(0.0, battle_rhythm_time - dt)
	opening_volley_time = maxf(0.0, opening_volley_time - dt)
	quick_draw_time = maxf(0.0, quick_draw_time - dt)
	_quick_draw_cd = maxf(0.0, _quick_draw_cd - dt)
	_firing_time = maxf(0.0, _firing_time - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	if not sprinting and carrying < 0:
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
		var speed: float = breaker_distance() / GameData.BREAKER_DURATION
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
	var v: Vector2 = move * GameData.PLAYER_SPEED * weapons[weapon_index].movement_mult * (1.0 + 0.04 * stacks(&"light_boots")) * perk_speed_mult() * (GameData.SPRINT_MULTIPLIER if sprinting else 1.0) * dt
	if carrying >= 0:
		v *= carry_speed_mult()
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
	var dmg: float = (GameData.BREAKER_DAMAGE + 15.0 * stacks(&"shockwave")) * (1.0 + perk_value(&"heavy_impact") / 100.0)
	var pulse: float = perk_value(&"crowd_anchor")  # Crowd Anchor: final push
	for i in horde.query_radius(player_pos, radius):
		_damage(i, dmg, player_pos, false, true)
		if pulse > 0.0 and not _dead.has(i):
			horde.knock_back(i, player_pos, pulse)
	if has_perk(&"opening_volley"):
		opening_volley_time = GameData.OPENING_VOLLEY_SECONDS
	_flush_dead()


func _auto_fire(dt: float) -> void:
	var w: GameData.Weapon = weapons[weapon_index]
	var rate: float = fire_rate()
	_fire_cd -= dt
	if reload_left > 0.0:
		_fire_cd = maxf(_fire_cd, 0.0)
		return
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
		if reload_left > 0.0 or target in _dead or target >= horde.count:
			break


## Card bonuses add up; perk effects then multiply.
func fire_rate() -> float:
	var bonus: float = 0.0
	var mult: float = 1.0
	if weapons[weapon_index].primary:
		bonus += 0.08 * stacks(&"fast_hands")
		if _stationary:
			bonus += 0.08 * stacks(&"steady_aim")
		else:
			mult *= 1.0 - perk_cost(&"steady_grip") / 100.0
	elif quick_draw_time > 0.0:
		mult *= 1.0 + perk_value(&"quick_draw") / 100.0
	if battle_rhythm_time > 0.0:
		bonus += 0.08 * stacks(&"battle_rhythm")
	return weapons[weapon_index].fire_rate * (1.0 + bonus) * mult


## Spread of weapon `w` now: Steady Grip tightens the primary standing
## still; Skirmisher widens it standing still.
func weapon_spread(w: GameData.Weapon) -> float:
	if not w.primary or not _stationary:
		return w.spread_deg
	return w.spread_deg * (1.0 - perk_value(&"steady_grip") / 100.0) * (1.0 + perk_cost(&"skirmisher") / 100.0)


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
	# Expired drops are lost, even if called before the timer cleanup.
	if power_ups.ground_time <= 0.0:
		power_ups.ground_kind = &""
		power_ups.ground_time = 0.0
		return
	var d := Vector2(player_pos.x - power_ups.ground_pos.x, player_pos.z - power_ups.ground_pos.z)
	if d.length() > GameData.POWER_UP_PICKUP_RADIUS:
		return
	var kind: StringName = power_ups.ground_kind
	power_ups.ground_kind = &""
	power_ups.ground_time = 0.0
	apply_power_up(kind)


func apply_power_up(kind: StringName) -> void:
	kind = GameData.power_up_id(kind)
	var data: PowerUpData = GameData.power_up(kind)
	if data == null:
		return
	_sync_intel_bonus()
	power_ups_picked.append(kind)
	messages.append("%s!" % data.display_name)
	match kind:
		&"insta_kill":
			power_ups.insta_time = data.duration
		&"double_rewards":
			power_ups.double_time = data.duration
		&"nuke":
			_nuke(data.spawn_delay)
		&"full_power":
			breaker_cd = 0.0
			grenade_cd = 0.0
		&"max_shield":
			add_shield(max_shield * data.shield_fill)
		&"extra_reroll":
			rerolls = mini(GameData.REROLLS_MAX, rerolls + data.reroll_amount)
		&"max_ammo":
			for i in weapons.size():
				if weapon_unlocked[i] and weapons[i].max_ammo > 0:
					ammo[i] = max_ammo(i)


## Every living enemy on the island dies, boss included, wherever it is.
## Kills, XP orbs and Intel are credited as usual (the boss objective sees
## the boss gone on the next mission update), but Nuke kills roll no new
## power-up drop and bloaters do not chain-explode on the player.
func _nuke(spawn_delay: float) -> void:
	power_ups.spawn_delay = spawn_delay
	explosions.append(player_pos)
	_nuking = true
	for i in horde.count:
		if not _dead.has(i):
			_damage(i, horde.hp[i], player_pos, false, true, true)
	_nuking = false


func _regenerate(dt: float) -> void:
	if hp <= 0.0:
		return
	var active: float = minf(dt, maxf(0.0, time_alive - _last_damage_time - 5.0))
	_heal_player(active * 0.5 * stacks(&"catch_your_breath"))


## Every heal in the island goes through here (Thick Skin's trade-off).
func _heal_player(amount: float) -> void:
	amount *= 1.0 - perk_cost(&"thick_skin") / 100.0
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
## enemies hidden by a building or a hill are ignored: both the player's
## line and the camera's line to the body must be clear (_crosshair_visible).
## -1 = no target, so aiming at the ground or the sky with nobody there
## fires nothing.
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
		if not _crosshair_visible(i, aim):
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


## Can the crosshair camera see enemy i's body point `aim`, and can the
## player shoot it? The player's line and the camera's line must be clear of
## visual obstacles (sight_blocked: a building between a shoulder camera and
## the target hides it even when the soldier's own line is clear; the sea
## and steep slopes do not), and the camera's line must stay above the
## terrain.
func _crosshair_visible(i: int, aim: Vector3) -> bool:
	return _view_clear(player_pos, horde.positions[i]) and _view_clear(crosshair_origin, aim) \
		and _above_ground(crosshair_origin, aim)


## No visual obstacle (sight_blocked, every 0.5 m) between a and b. A view
## that starts inside an obstacle (a camera pushed against a wall) sees out
## of it: obstacle cells at the start of the line are skipped; any one after
## the first free cell hides `b`.
func _view_clear(a: Vector3, b: Vector3) -> bool:
	var d: Vector3 = b - a
	var n: int = ceili(Vector2(d.x, d.z).length() / 0.5)
	var outside: bool = not sight_is_blocked(floori(a.x), floori(a.z))
	for k in range(1, n):
		var p: Vector3 = a + d * (float(k) / n)
		var blocked: bool = sight_is_blocked(floori(p.x), floori(p.z))
		if blocked and outside:
			return false
		outside = outside or not blocked
	return true


## Distance along the ray origin + s * dir (unit) to its first obstacle: a
## visual obstacle cell (skipping those it starts in, as _view_clear) or the
## terrain above it. `max_s` when nothing is in the way before it.
func _ray_block(origin: Vector3, dir: Vector3, max_s: float) -> float:
	var flat: float = Vector2(dir.x, dir.z).length()
	var step: float = 0.5 / maxf(flat, 0.25)  # ~0.5 m across the grid
	var outside: bool = not sight_is_blocked(floori(origin.x), floori(origin.z))
	var s: float = step
	while s < max_s:
		var p: Vector3 = origin + dir * s
		var blocked: bool = sight_is_blocked(floori(p.x), floori(p.z))
		if (blocked and outside) or p.y < map.ground_y(p) - 0.1:
			return s
		outside = outside or not blocked
		s += step
	return max_s


## No terrain between a and b (sampled every metre; buildings are checked on
## the grid by _line_of_sight / _view_clear).
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
	if has_perk(&"body_count"):
		return false  # Body Count: no headshots at all
	if uses_crosshair():
		var v: Vector3 = enemy_head(target) - crosshair_origin
		var along: float = v.dot(crosshair_dir)
		if along <= 0.0:
			return false
		var t: GameData.EnemyType = horde.types[horde.kinds[target]]
		var radius: float = GameData.CROSSHAIR_HEAD_RADIUS * t.radius_scale
		radius *= headshot_cone_deg() / GameData.HEADSHOT_CONE_DEG
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
	return cos(deg_to_rad(headshot_cone_deg()))


## Head Hunter sets the cone (11/13/15 degrees); crosshair cameras scale the
## head radius by the same cone / 9.
func headshot_cone_deg() -> float:
	return perk_value(&"head_hunter") if has_perk(&"head_hunter") else GameData.HEADSHOT_CONE_DEG


func _fire(w: GameData.Weapon, target: int) -> void:
	_firing_time = GameData.SKIRMISHER_FIRING_WINDOW
	if w.primary:
		_shots += 1
	if w.max_ammo > 0:
		ammo[weapon_index] -= 1
	if magazine_size(weapon_index) > 0:
		mag[weapon_index] -= 1
		if mag[weapon_index] <= 0:
			_reload(weapon_index)
	# Fixed camera: a flat ray from the player (horde.hitscan). First / third
	# person: a 3D ray from the camera to the picked body point
	# (_crosshair_hits), so an enemy above or below the shot on the same
	# flat line is not hit, and nothing hidden from the camera is.
	var crosshair: bool = uses_crosshair()
	var origin: Vector3 = player_pos
	var dir: Vector3
	if crosshair:
		origin = crosshair_origin
		dir = (_crosshair_body_point(target) - origin).normalized()
	else:
		var to: Vector3 = horde.positions[target] - player_pos
		to.y = 0.0
		dir = to.normalized()
	var headshot: bool = _is_headshot(target)
	var rifle: bool = w.primary
	var dmg: float = w.damage * (1.0 + 0.10 * stacks(&"hollow_points") if rifle else 1.0)
	if rifle:  # perks multiply after the cards
		dmg *= (1.0 - perk_cost(&"kill_chain") / 100.0) * (1.0 + (perk_value(&"opening_volley") / 100.0 if opening_volley_time > 0.0 else 0.0))
	var spread: float = weapon_spread(w)
	var pierce: int = w.pierce + (stacks(&"piercing_rounds") if rifle else 0)
	var direct_hits: Array[int] = []
	var ricochet_damage: float = dmg
	var candidates := PackedInt32Array()
	if crosshair:
		candidates = _shot_candidates(origin, dir, w.range_m, spread * 0.5)
	for p in w.pellets:
		var pellet_dir: Vector3 = dir
		if spread > 0.0:
			pellet_dir = dir.rotated(Vector3.UP, deg_to_rad(rng.randf_range(-spread, spread) * 0.5))
		var hits: Array[Vector2] = _crosshair_hits(origin, pellet_dir, pierce, candidates) if crosshair \
			else horde.hitscan(player_pos, pellet_dir, w.range_m, pierce)
		var end: Vector3 = player_pos + Vector3(pellet_dir.x, 0, pellet_dir.z).normalized() * w.range_m
		for h in hits:
			var idx: int = int(h.y)
			if crosshair:
				var at: Vector3 = origin + pellet_dir * h.x
				end = Vector3(at.x, 0, at.z)  # tracers are simulation points (y = 0)
			else:
				end = player_pos + pellet_dir * h.x
			if _dead.has(idx):
				continue
			var is_head: bool = headshot and idx == target
			var hit_damage: float = dmg * (GameData.HEADSHOT_MULTIPLIER if is_head else body_damage_mult())
			if w.close_range > 0.0 and horde.positions[idx].distance_to(player_pos) <= w.close_range:
				hit_damage *= w.close_damage_mult
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


## Broad phase of a crosshair shot (once per shot, not per pellet): live
## enemies in range and in front of the player whose body can be within
## reach of a pellet, i.e. near the shot's line on the ground (body radius
## plus what `half_spread_deg` can add at that distance). Also caches, for
## _crosshair_hits, each candidate's body axis and radius and (lazily) the
## soldier's own line to it.
func _shot_candidates(origin: Vector3, dir: Vector3, range_m: float, half_spread_deg: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	_shot_low.clear()
	_shot_seg.clear()
	_shot_r.clear()
	_shot_los.clear()
	var d2 := Vector2(dir.x, dir.z)
	if d2.length_squared() < 0.000001:
		d2 = Vector2(facing.x, facing.z)
	d2 = d2.normalized()
	var o2 := Vector2(origin.x, origin.z)
	var p0 := Vector2(player_pos.x, player_pos.z)
	var widen: float = tan(deg_to_rad(half_spread_deg))
	for i in horde.query_radius(player_pos, range_m):
		if _dead.has(i):
			continue
		var p: Vector3 = horde.positions[i]
		var q := Vector2(p.x, p.z)
		if (q - p0).dot(d2) <= 0.0:
			continue
		var along: float = (q - o2).dot(d2)
		var r: float = GameData.CROSSHAIR_BODY_RADIUS * horde.types[horde.kinds[i]].radius_scale
		if absf((q - o2).cross(d2)) <= r + 0.05 + maxf(along, 0.0) * widen:
			out.append(i)
			var low := Vector3(p.x, p.y + map.ground_y(p) + 0.2, p.z)
			_shot_low.append(low)
			_shot_seg.append(enemy_head(i) - low)
			_shot_r.append(r)
	return out


## Enemies a crosshair pellet hits, from the shot's `candidates` (call
## _shot_candidates first: it fills the caches): the 3D ray origin + s * dir
## (unit) passes within the body radius of the enemy's axis (feet to head,
## as in _crosshair_body_point) before the pellet's first obstacle on its
## own path (_ray_block: buildings, rocks, trees, terrain), and the
## soldier's own line to the enemy is clear. Nearest first, at most
## `max_hits` (the weapon's pierce). Returns Vector2(distance along the ray,
## index), like Horde.hitscan.
func _crosshair_hits(origin: Vector3, dir: Vector3, max_hits: int, candidates: PackedInt32Array) -> Array[Vector2]:
	var hits: Array[Vector2] = []
	var d2 := Vector2(dir.x, dir.z)
	var flat: float = d2.length()
	if flat > 0.000001:
		d2 /= flat
	var o2 := Vector2(origin.x, origin.z)
	for k in candidates.size():
		var i: int = candidates[k]
		if _dead.has(i):
			continue
		var low: Vector3 = _shot_low[k]
		var r: float = _shot_r[k]
		# Cheap 2D reject: the pellet's line on the ground misses the body.
		if flat > 0.000001 and absf((Vector2(low.x, low.z) - o2).cross(d2)) > r:
			continue
		var seg: Vector3 = _shot_seg[k]
		# Closest points between the ray and the body axis (clamped to the
		# segment, then the ray point re-projected onto it).
		var w: Vector3 = origin - low
		var b: float = dir.dot(seg)
		var ss: float = maxf(seg.dot(seg), 0.000001)
		var denom: float = ss - b * b
		var u: float = 0.0
		if denom > 0.000001:
			u = clampf((seg.dot(w) - b * dir.dot(w)) / denom, 0.0, 1.0)
		var s: float = maxf(0.0, dir.dot(low + seg * u - origin))
		var on_ray: Vector3 = origin + dir * s
		var on_axis: Vector3 = low + seg * clampf((on_ray - low).dot(seg) / ss, 0.0, 1.0)
		if on_ray.distance_to(on_axis) > r:
			continue
		hits.append(Vector2(s, i))
	if hits.is_empty():
		return hits
	hits.sort()
	# The pellet stops at its first obstacle: march only as far as the hits
	# it can still take (further only if the soldier cannot see one of them).
	var out: Array[Vector2] = []
	var marched: float = 0.0
	var block: float = INF
	for h in hits:
		if out.size() >= max_hits:
			break
		if h.x >= marched and block == INF:
			var upto: float = hits[mini(hits.size(), hits.find(h) + max_hits - out.size()) - 1].x + 0.01
			var b: float = _ray_block(origin, dir, upto)
			if b < upto:
				block = b
			marched = upto
		if h.x >= block:
			break
		var i: int = int(h.y)
		if not _shot_los.has(i):
			_shot_los[i] = _view_clear(player_pos, horde.positions[i])
		if _shot_los[i]:
			out.append(h)
	return out


func _damage(i: int, amount: float, from: Vector3, headshot: bool, breaker: bool,
		secondary: bool = false, rifle_hit: bool = false) -> void:
	if _dead.has(i):
		return
	var t: GameData.EnemyType = horde.types[horde.kinds[i]]
	if t.front_armor > 0.0 and not breaker:
		# Armoured enemies take reduced damage from the front (where they walk to).
		var v: Vector3 = horde.velocities[i]
		var to_src: Vector3 = from - horde.positions[i]
		if v.length_squared() > 0.01 and v.normalized().dot(to_src.normalized()) > 0.3:
			amount *= 1.0 - t.front_armor
	if stacks(&"executioner") > 0 and (horde.stun[i] > 0.0 or horde.freeze_time[i] > 0.0):
		amount *= 1.0 + 0.2 * stacks(&"executioner")
	# Insta-Kill: any shot kills any enemy (elites, specials, the boss), after
	# front armour so a shield cannot save it. Not breaker or secondary damage.
	if power_ups.insta_time > 0.0 and not breaker and not secondary:
		amount = maxf(amount, horde.hp[i])
	horde.hp[i] -= amount
	if not secondary:
		horde.flash[i] = 0.1  # DOT must not hide the status tint with a constant flash
	if horde.hp[i] <= 0.0:
		_dead[i] = true
		kills += 1
		_sync_intel_bonus()
		if not _nuking:
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
		if t.explodes and not _nuking:
			explosions.append(p)
			if player_pos.distance_to(p) <= GameData.BLOATER_RADIUS and dash_time <= 0.0:
				_take_player_damage(GameData.BLOATER_PLAYER_DAMAGE)
			for j in horde.query_radius(p, GameData.BLOATER_RADIUS):
				_damage(j, GameData.BLOATER_DAMAGE, p, false, true, true)
				horde.knock_back(j, p, 1.5)
		orbs.append(p)
		orb_values.append(t.xp)
		if rifle_hit and not secondary and has_perk(&"kill_chain"):
			_kill_chain_refill()
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


## Body-shot damage: Body Count raises it, Head Hunter's trade-off lowers it.
func body_damage_mult() -> float:
	return (1.0 + perk_value(&"body_count") / 100.0) * (1.0 - perk_cost(&"head_hunter") / 100.0)


## Kill Chain: a direct primary kill puts rounds back in the magazine of the
## primary being fired, up to its capacity (not while it reloads).
func _kill_chain_refill() -> void:
	var w: int = weapon_index
	if not weapons[w].primary or magazine_size(w) <= 0 or reload_times[w] > 0.0:
		return
	mag[w] = mini(magazine_size(w), mag[w] + int(perk_value(&"kill_chain")))


## Only direct primary hits roll elements. Damage from states/chains/clouds
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
	var radius: float = pickup_radius()
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


## XP attraction radius: XP Magnet adds; Trail Rations and Surveyor
## (moving) shrink it; Surveyor standing still widens it.
func pickup_radius() -> float:
	var radius: float = GameData.PICKUP_RADIUS * (1.0 + 0.4 * stacks(&"magnet")) * (1.0 - perk_cost(&"trail_rations") / 100.0)
	if has_perk(&"surveyor"):
		radius *= 1.0 + perk_value(&"surveyor") / 100.0 if _stationary else 1.0 - perk_cost(&"surveyor") / 100.0
	return radius


func _collect_xp_orb(index: int) -> void:
	var reward_mult: float = 2.0 if power_ups.double_time > 0.0 else 1.0
	var earned: float = orb_values[index] * reward_mult * (1.0 + fast_learner_bonus()) + xp_fraction
	var whole: int = floori(earned + 0.000001)
	xp += whole
	xp_fraction = maxf(0.0, earned - whole)
	_heal_player(0.2 * stacks(&"field_dressing") + perk_value(&"trail_rations"))
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
		_heal_player(20.0)
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
				&"hold_sequence":
					_update_hold_sequence(dt)
				&"fuel_run":
					_update_fuel_run()
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
				if mission == &"hold_sequence" and not has_exit():
					radio.append(&"hold_done")
				elif mission == &"fuel_run" and not has_exit():
					radio.append(&"fuel_done")
				elif mission != &"rescue":
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


## Hold Sequence: stand in the active point for hold_seconds(); leaving
## pauses it. Each point's first step in calls a spike of the horde; once
## held, the next point becomes the site (the extraction waits for all).
func _update_hold_sequence(dt: float) -> void:
	if hold_index >= hold_points.size():
		return
	if player_pos.distance_to(hold_points[hold_index]) > hold_radius():
		return
	if not hold_started:
		hold_started = true
		director.trigger_peak(hold_seconds() + 10.0)
		messages.append("Point %d of %d: hold it!" % [hold_index + 1, hold_points.size()])
	hold_progress += dt
	if hold_progress < hold_seconds():
		return
	hold_index += 1
	hold_progress = 0.0
	hold_started = false
	for w in weapons.size():
		if weapons[w].max_ammo > 0:
			ammo[w] = mini(max_ammo(w), ammo[w] + max_ammo(w) / 3)
	if hold_index < hold_points.size():
		site = hold_points[hold_index]
		messages.append("Point secured. Move to point %d!" % (hold_index + 1))
		radio.append(&"hold_point")


## Fuel Run: walking over a waiting can picks it up (one at a time); the
## carried can moves with the player and counts as delivered within
## cargo_delivery_radius() of delivery_point(). `site` follows the next
## goal (the HUD marker, the minimap and the test bots read it).
func _update_fuel_run() -> void:
	if carrying >= 0:
		cargo_pos[carrying] = Vector3(player_pos.x, 0, player_pos.z)
		var to: Vector3 = delivery_point()
		if Vector2(to.x - player_pos.x, to.z - player_pos.z).length() <= cargo_delivery_radius():
			cargo_state[carrying] = CAN_DELIVERED
			cargo_pos[carrying] = to
			carrying = -1
			for w in weapons.size():
				if weapons[w].max_ammo > 0:
					ammo[w] = mini(max_ammo(w), ammo[w] + max_ammo(w) / 3)
			if cargo_delivered() < cargo_pos.size():
				messages.append("Fuel delivered (%d / %d). Go get the next can!" % [cargo_delivered(), cargo_pos.size()])
				radio.append(&"fuel_delivered")
	else:
		if _cargo_dropped >= 0 and Vector2(cargo_pos[_cargo_dropped].x - player_pos.x,
				cargo_pos[_cargo_dropped].z - player_pos.z).length() > cargo_pickup_radius() + 1.0:
			_cargo_dropped = -1  # stepped away: walking over it picks it up again
		var c: int = nearest_waiting_can(cargo_pickup_radius(), _cargo_dropped)
		if c >= 0:
			_pick_up_can(c)
	site = fuel_goal()


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
			_heal_player(30.0)
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


## Sectors (equal angles around the player) for the fallback spawn.
const SPAWN_SECTORS: int = 8
## A sector with at least this many valid spots counts in full when one is
## drawn; one with fewer (a sliver at the edge of a wall or the play area)
## counts in proportion, so it does not get a full share on two spots.
const SPAWN_SECTOR_FULL: int = 4


## A spot that can_spawn_at() on rings of these radii around `center` (36
## directions each, every ring from its own random angle); INF when none.
## Every valid spot of every ring is sorted into SPAWN_SECTORS sectors
## around `center`; a sector is drawn uniformly among those with spots
## (slivers with fewer than SPAWN_SECTOR_FULL spots weigh less), then a spot
## inside it. The old rule (the first valid spot after a random angle)
## piled the spawns on one edge of the free arc: always the same side.
func _ring_spot(center: Vector3, radii: Array) -> Vector3:
	var spots := PackedVector3Array()
	var sectors := PackedInt32Array()
	var per_sector := PackedInt32Array()
	per_sector.resize(SPAWN_SECTORS)
	for r: float in radii:
		var start: float = _spawn_rng.randf() * TAU
		for k in 36:
			var ang: float = start + k * TAU / 36.0
			var p: Vector3 = center + Vector3(cos(ang), 0, sin(ang)) * r
			if can_spawn_at(p):
				var sector: int = spawn_sector(center, p)
				spots.append(p)
				sectors.append(sector)
				per_sector[sector] += 1
	var total: int = 0
	for sector in SPAWN_SECTORS:
		total += mini(per_sector[sector], SPAWN_SECTOR_FULL)
	if total == 0:
		return Vector3.INF
	var roll: int = _spawn_rng.randi_range(0, total - 1)
	var chosen: int = 0
	while roll >= mini(per_sector[chosen], SPAWN_SECTOR_FULL):
		roll -= mini(per_sector[chosen], SPAWN_SECTOR_FULL)
		chosen += 1
	var nth: int = _spawn_rng.randi_range(0, per_sector[chosen] - 1)
	for k in spots.size():
		if sectors[k] == chosen:
			if nth == 0:
				return spots[k]
			nth -= 1
	return Vector3.INF  # not reached


## Which of the SPAWN_SECTORS sectors around `center` `p` is in (sector 0
## starts at +X and they go towards +Z).
static func spawn_sector(center: Vector3, p: Vector3) -> int:
	var ang: float = fposmod(atan2(p.z - center.z, p.x - center.x), TAU)
	return mini(int(ang / (TAU / SPAWN_SECTORS)), SPAWN_SECTORS - 1)


func _spawn_enemy() -> void:
	if horde.count >= GameData.MAX_ALIVE or power_ups.spawn_delay > 0.0:
		return
	spawn_requests += 1
	# Uniform over the free ground of the ring (rejection sampling): no side
	# is favoured beyond how much free ground it has (measured: see
	# test_island_run's spawn histogram).
	for attempt in 12:
		var ang: float = _spawn_rng.randf() * TAU
		var dist: float = _spawn_rng.randf_range(GameData.SPAWN_MIN_DIST, GameData.SPAWN_MAX_DIST)
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
			if mission == &"hold_sequence":
				return "Hold point %d / %d (%d / %d s)" % [mini(hold_index + 1, hold_points.size()), hold_points.size(),
					int(hold_progress), int(hold_seconds())]
			if mission == &"fuel_run":
				if carrying >= 0:
					return "Fuel %d / %d: carry the can to the %s" % [cargo_delivered(), cargo_pos.size(), delivery_name().to_lower()]
				return "Fuel %d / %d: find a fuel can" % [cargo_delivered(), cargo_pos.size()]
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
