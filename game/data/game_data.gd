class_name GameData
extends RefCounted
## Game data. Content tables (weapons, cards, perks, enemies, modifiers,
## classes, biomes, missions) are .tres files in YARD registries under
## game/data/; global balance numbers and rules stay here as constants.


class EnemyType:
	var id: StringName
	var display_name: String
	var hp: float
	var speed_min: float
	var speed_max: float
	var damage: float          ## per hit on the player
	var attack_interval: float ## seconds between hits
	var radius_scale: float    ## visual size multiplier
	var height: float
	var color: Color
	var xp: int
	var front_armor: float     ## 0..1 damage reduction when hit from the front
	var grabs: bool            ## holds the player until killed or broken free
	var pushable: bool         ## breaker pushes it away
	var keep_away: float = 0.0 ## > 0: backs off when the player is closer than this
	var explodes: bool = false ## blows up on death, hurting everyone around

	func _init(p_id: StringName, p_name: String, p_hp: float, p_speed: Vector2, p_damage: float,
			p_interval: float, p_scale: float, p_height: float, p_color: Color, p_xp: int) -> void:
		id = p_id
		display_name = p_name
		hp = p_hp
		speed_min = p_speed.x
		speed_max = p_speed.y
		damage = p_damage
		attack_interval = p_interval
		radius_scale = p_scale
		height = p_height
		color = p_color
		xp = p_xp
		front_armor = 0.0
		grabs = false
		pushable = true


class Weapon:
	var id: StringName
	var display_name: String
	var damage: float
	var fire_rate: float    ## shots per second
	var range_m: float
	var pellets: int
	var spread_deg: float
	var pierce: int         ## enemies hit per pellet
	var max_ammo: int       ## -1 = infinite
	var knockback: float    ## metres pushed per hit
	var magazine: int       ## rounds per magazine; 0 = none (shots come straight from the reserve)
	var primary: bool = false
	var reload_seconds: float = 0.0
	var movement_mult: float = 1.0
	var close_damage_mult: float = 1.0
	var close_range: float = 0.0
	var role: String = ""

	func _init(p_id: StringName, p_name: String, p_damage: float, p_rate: float, p_range: float,
			p_pellets: int, p_spread: float, p_pierce: int, p_ammo: int, p_knockback: float,
			p_magazine: int = 0) -> void:
		id = p_id
		display_name = p_name
		damage = p_damage
		fire_rate = p_rate
		range_m = p_range
		pellets = p_pellets
		spread_deg = p_spread
		pierce = p_pierce
		max_ammo = p_ammo
		knockback = p_knockback
		magazine = p_magazine


class Card:
	var id: StringName
	var title: String
	var description: String
	var max_stacks: int
	var category: StringName = &"utility"
	var icon: StringName = &"utility"
	var tags: Array[StringName] = []
	var class_filter: Array[StringName] = []
	var weapon_filter: Array[StringName] = []
	var requires_finite_weapon: bool = false
	var prerequisites: Dictionary[StringName, int] = {}

	func _init(p_id: StringName, p_title: String, p_desc: String, p_max: int) -> void:
		id = p_id
		title = p_title
		description = p_desc
		max_stacks = p_max


## One alternative (A/B) of a perk tree node; see PerkData.
class Perk:
	var id: StringName
	var title: String
	var description: String
	var branch: StringName
	var tier: int
	var option: int  ## 0 = A, 1 = B
	var class_filter: StringName  ## &"" = every class
	var benefit: String
	var benefit_values: PackedFloat32Array
	var benefit_2: String
	var benefit_2_values: PackedFloat32Array
	var penalty: String
	var penalty_values: PackedFloat32Array

	func _init(p_id: StringName, p_title: String, p_desc: String) -> void:
		id = p_id
		title = p_title
		description = p_desc

	## "combat_2": the node this alternative belongs to (ranks are per node).
	func node() -> StringName:
		return GameData.perk_node(branch, tier)

	func fits_class(player_class: StringName) -> bool:
		return class_filter == &"" or class_filter == player_class

	## Totals at `rank` (1..3); 0 at rank 0.
	func value(rank: int) -> float:
		return _at(benefit_values, rank)

	func value_2(rank: int) -> float:
		return _at(benefit_2_values, rank)

	func cost_value(rank: int) -> float:
		return _at(penalty_values, rank)

	static func _at(values: PackedFloat32Array, rank: int) -> float:
		if rank <= 0 or values.is_empty():
			return 0.0
		return values[mini(rank, values.size()) - 1]


class Modifier:
	var id: StringName
	var title: String
	var description: String
	var intel_mult: float

	func _init(p_id: StringName, p_title: String, p_desc: String, p_mult: float) -> void:
		id = p_id
		title = p_title
		description = p_desc
		intel_mult = p_mult


enum EnemyKind { WALKER, RUNNER, BRUTE, GRABBER, BOSS, BLOATER, SCREAMER }

## Player
const PLAYER_MAX_HP: float = 100.0
const PLAYER_SPEED: float = 6.0
const PLAYER_RADIUS: float = 0.4
const BREAKER_DISTANCE: float = 5.0
const BREAKER_DURATION: float = 0.18
const BREAKER_COOLDOWN: float = 6.0
const BREAKER_RADIUS: float = 2.2
const BREAKER_DAMAGE: float = 15.0
const BREAKER_STUN: float = 1.0
const PICKUP_RADIUS: float = 3.0
const XP_AUTO_COLLECT_LEVEL: int = 30
## Auto-fire picks targets inside this cone around where the player faces.
const AIM_CONE_DEG: float = 50.0
## Targets this close to the facing direction get headshots.
const HEADSHOT_CONE_DEG: float = 9.0
const HEADSHOT_MULTIPLIER: float = 2.5
## First / third person: auto-fire only shoots an enemy whose body lies
## within this angle of the crosshair ray (seen from the camera), so pointing
## at the ground or the sky with nobody there fires nothing.
const CROSSHAIR_CONE_DEG: float = 6.0
## Body radius (metres, times the enemy's size) for the crosshair test: the
## ray anywhere on a body counts as 0 degrees off (close enemies are wide).
const CROSSHAIR_BODY_RADIUS: float = 0.35
## Crosshair headshot: the ray passes this close (metres, times the enemy's
## size) to the centre of the head. Head Hunter widens it like its cone.
const CROSSHAIR_HEAD_RADIUS: float = 0.4

## Max melee damage taken in one frame: being swarmed is dangerous, but never
## an instant death without a chance to react (telegraphed boss attacks are
## not capped).
const MAX_MELEE_PER_FRAME: float = 25.0

## Sprint: faster, but the gun stays silent while running.
const SPRINT_MULTIPLIER: float = 1.6
const STAMINA_MAX: float = 3.0       ## seconds of sprint
const STAMINA_REGEN: float = 0.75    ## per second
const STAMINA_REGEN_DELAY: float = 0.8

## Grenade (Recruit active ability)
const GRENADE_COOLDOWN: float = 12.0
const GRENADE_RANGE: float = 14.0
const GRENADE_FUSE: float = 0.8
const GRENADE_RADIUS: float = 5.0
const GRENADE_DAMAGE: float = 90.0

## Bloater explosion and Screamer call
const BLOATER_RADIUS: float = 3.5
const BLOATER_DAMAGE: float = 45.0         ## to enemies
const BLOATER_PLAYER_DAMAGE: float = 20.0
const SCREAM_RANGE: float = 22.0
const SCREAM_TIME: float = 3.0             ## seconds in sight before it screams
const SCREAM_COOLDOWN: float = 15.0

## Boss rock throw (when the player keeps their distance)
const BOSS_ROCK_MIN_RANGE: float = 12.0
const BOSS_ROCK_FLIGHT: float = 1.5     ## time to land: the ring shows where
const BOSS_ROCK_RADIUS: float = 2.5
const BOSS_ROCK_DAMAGE: float = 20.0
const BOSS_ROCK_COOLDOWN: float = 3.5

## Biomes, missions and classes come from YARD registries (game/data/
## biomes.tres, missions.tres, classes.tres), exposed in the same shape the
## game always used: id -> Dictionary.
static var BIOMES: Dictionary = _load_biomes()
## Biomes offered on the boat; the last island is always the volcano.
static var ISLAND_BIOMES: Array[StringName] = _route_biomes()
const LAVA_PLAYER_DPS: float = 18.0
const LAVA_ENEMY_DPS: float = 30.0

## Missions (one per island, shown with the route on the boat).
static var MISSIONS: Dictionary = _load_missions()
## Missions the boat offers on archipelago routes (not the expedition-only
## holdout).
static var ROUTE_MISSIONS: Array[StringName] = _route_missions()
const DEFEND_TIME: float = 75.0
## Holdout (the Berlenga's final, in the fort): hold the courtyard a bit
## longer than a Defend, then the rescue boat needs this long to dock.
const HOLDOUT_TIME: float = 90.0
const BOAT_ARRIVAL_TIME: float = 20.0
## Hazard pay (boat briefing): bonus Intel and extra enemies, one island.
const HAZARD_INTEL_MULT: float = 1.25
const HAZARD_ALIVE_MULT: float = 1.25
const DEFEND_RADIUS: float = 6.0
const SURVIVOR_SPEED: float = 5.6
const SURVIVOR_HP: float = 100.0
const SURVIVOR_HIT_DPS: float = 7.0   ## per enemy touching the survivor
const SURVIVOR_FIND_RADIUS: float = 3.0

## Supply caches
const CACHE_RADIUS: float = 2.0
const CACHE_OPEN_TIME: float = 1.5

## Boss (last island)
const BOSS_SLAM_RANGE: float = 9.0     ## starts a slam when the player is this close
const BOSS_SLAM_RADIUS: float = 6.0
const BOSS_SLAM_WINDUP: float = 1.2    ## telegraph time: get out of the ring!
const BOSS_SLAM_DAMAGE: float = 30.0
const BOSS_SLAM_COOLDOWN: float = 5.0
const BOSS_SUMMON_INTERVAL: float = 9.0
const BOSS_SUMMON_COUNT: int = 4

## Classes: passive + active ability (abilities are code in IslandRun).
static var CLASS_INFO: Dictionary = _load_classes()
static var CLASSES: Array[StringName] = _class_ids()
const WAR_CRY_RADIUS: float = 7.0
const WAR_CRY_TIME: float = 5.0
const WAR_CRY_COOLDOWN: float = 16.0

## Meta progression
const SLOT_COSTS: Array[int] = [0, 100, 250]  ## cost of the 1st, 2nd, 3rd perk slot
## Perk tree (docs/design/CARDS_WEAPONS_PERKS.md §F2): three branches of
## three tiers. Intel to buy rank I, II and III of a node, per tier.
const PERK_BRANCHES: Array[StringName] = [&"combat", &"survival", &"breaker"]
const PERK_TIERS: int = 3
const PERK_MAX_RANK: int = 3
const PERK_RANK_COSTS: Array = [[40, 60, 80], [60, 90, 120], [100, 140, 180]]
## Timed perk rules (playtest hypotheses, like the values in the .tres).
const OPENING_VOLLEY_SECONDS: float = 2.0
const QUICK_DRAW_SECONDS: float = 2.0
const QUICK_DRAW_COOLDOWN: float = 8.0
## Skirmisher counts the player as "firing" this long after a shot.
const SKIRMISHER_FIRING_WINDOW: float = 0.3
const MAX_THREAT: int = 3
const EXTRACTION_INTEL_MULTIPLIER: float = 1.5

## Level-up cards: rerolls (PROVISIONAL: the user still has to decide,
## docs/design/PROGRESSION_AND_ECONOMY.md §1.6 P9). A reroll redraws the
## offer. The run starts with REROLLS_START; every island cleared that is
## not the last adds REROLLS_PER_ISLAND, never above REROLLS_MAX banked.
const REROLLS_START: int = 2
const REROLLS_PER_ISLAND: int = 1
const REROLLS_MAX: int = 3

# Kill power-ups: provisional playtest values, independent of cards/weapons.
const POWER_UP_CHANCE: float = 0.015
const POWER_UP_SPECIAL_CHANCE: float = 0.05
const POWER_UP_PITY_KILLS: int = 60
const POWER_UP_DROP_INTERVAL: float = 35.0
const POWER_UP_GROUND_SECONDS: float = 25.0
const POWER_UP_BLINK_SECONDS: float = 10.0
const POWER_UP_PICKUP_RADIUS: float = 1.4
const PLAYER_MAX_SHIELD: float = 100.0
## Everything per power-up (name, glyph, colour, weight, duration, effect
## amounts, old ids) lives in game/data/power_ups/ (YARD registry
## game/data/power_ups.tres). The drop rules above apply to all of them.
const POWER_UP_REGISTRY: String = "res://game/data/power_ups.tres"
static var _power_ups: Dictionary = {}  ## id -> PowerUpData, registry order
static var _power_up_legacy: Dictionary = {}  ## old id -> current id


static func _power_up_table() -> Dictionary:
	if _power_ups.is_empty():
		for e: Array in _entries(POWER_UP_REGISTRY):
			var d: PowerUpData = e[1]
			_power_ups[e[0]] = d
			for old: StringName in d.legacy_ids:
				_power_up_legacy[old] = e[0]
	return _power_ups


## Power-up ids in registry order (the order of the drop pool).
static func power_up_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in _power_up_table():
		ids.append(id)
	return ids


## Ids used before the renames (Max Armor -> Max Shield, Fire Sale -> Extra
## Reroll) are mapped to the current id; read from each .tres `legacy_ids`.
static func power_up_legacy_ids() -> Dictionary:
	_power_up_table()
	return _power_up_legacy.duplicate()


static func power_up_id(id: StringName) -> StringName:
	_power_up_table()
	return _power_up_legacy.get(id, id)


## Data of a power-up (old ids accepted); null if unknown.
static func power_up(id: StringName) -> PowerUpData:
	return _power_up_table().get(power_up_id(id))


static func power_up_name(id: StringName) -> String:
	var d: PowerUpData = power_up(id)
	return d.display_name if d != null else String(id).to_upper()


static func power_up_icon(id: StringName) -> String:
	var d: PowerUpData = power_up(id)
	return d.glyph if d != null else "•"


static func power_up_normal(kind: int) -> bool:
	return kind == EnemyKind.WALKER or kind == EnemyKind.RUNNER


static func card_category(id: StringName) -> StringName:
	for card in cards():
		if card.id == id:
			return card.category
	return &"utility"


## Horde
const MAX_ALIVE: int = 150
const SPAWN_MIN_DIST: float = 28.0
const SPAWN_MAX_DIST: float = 45.0
const ATTACK_REACH: float = 1.1

## Mission
const GENERATOR_COUNT: int = 3
const GENERATOR_HOLD_SECONDS: float = 8.0
const GENERATOR_RADIUS: float = 3.5
const BOAT_RADIUS: float = 4.0

## XP needed to go from level n to n+1.
static func xp_for_level(level: int) -> int:
	# Costs and Walker rewards share a x10 scale, preserving baseline pacing.
	# Specials pay more relative XP; later levels still require more kills.
	return 10 * (8 + level * 6 + level * level)


## Enemy types from game/data/enemies/ (order = EnemyKind). Fresh objects
## each call.
static func enemy_types() -> Array[EnemyType]:
	var list: Array[EnemyType] = []
	for e: Array in _entries(ENEMY_REGISTRY):
		var d: EnemyData = e[1]
		var t := EnemyType.new(e[0], d.display_name, d.hp, Vector2(d.speed_min, d.speed_max), d.damage,
			d.attack_interval, d.radius_scale, d.height, d.color, d.xp)
		t.front_armor = d.front_armor
		t.grabs = d.grabs
		t.pushable = d.pushable
		t.keep_away = d.keep_away
		t.explodes = d.explodes
		list.append(t)
	return list


## Weapons, cards and perks live in .tres files (one per entry) listed in
## YARD registries (addons/yard): edit them in the inspector or in the
## editor's Registry tab. Loaded once and cached; ordered by `order`.
const WEAPON_REGISTRY: String = "res://game/data/weapons.tres"
const CARD_REGISTRY: String = "res://game/data/cards.tres"
const PERK_REGISTRY: String = "res://game/data/perks.tres"
const ENEMY_REGISTRY: String = "res://game/data/enemies.tres"
const MODIFIER_REGISTRY: String = "res://game/data/modifiers.tres"
const CLASS_REGISTRY: String = "res://game/data/classes.tres"
const BIOME_REGISTRY: String = "res://game/data/biomes.tres"
const MISSION_REGISTRY: String = "res://game/data/missions.tres"

static var _weapon_data: Array = []  ## [id, WeaponData] sorted by order
static var _cards: Array[Card] = []
static var _perks: Array[Perk] = []
static var _modifiers: Array[Modifier] = []


## [id, resource] pairs of a registry, sorted by the resources' `order`.
static func _entries(registry_path: String) -> Array:
	var reg: Resource = load(registry_path)
	if reg == null:
		push_error("GameData: missing registry " + registry_path)
		return []
	var all: Dictionary = reg.call("load_all_blocking")
	var out: Array = []
	for id: StringName in all:
		out.append([id, all[id]])
	out.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1].get("order")) < int(b[1].get("order")))
	return out


static func _weapon_entries() -> Array:
	if _weapon_data.is_empty():
		_weapon_data = _entries(WEAPON_REGISTRY)
	return _weapon_data


## Fresh Weapon objects each call (IslandRun may change them with cards).
static func weapons() -> Array[Weapon]:
	var list: Array[Weapon] = []
	for e: Array in _weapon_entries():
		var d: WeaponData = e[1]
		list.append(Weapon.new(e[0], d.display_name, d.damage, d.fire_rate, d.range_m,
			d.pellets, d.spread_deg, d.pierce, d.max_ammo, d.knockback, d.magazine))
		var weapon: Weapon = list[-1]
		weapon.primary = d.primary
		weapon.reload_seconds = d.reload_seconds
		weapon.movement_mult = d.movement_mult
		weapon.close_damage_mult = d.close_damage_mult
		weapon.close_range = d.close_range
		weapon.role = d.role
	return list


static func weapon(id: StringName) -> Weapon:
	for entry in weapons():
		if entry.id == id:
			return entry
	return null


## Exactly two slots: the last valid primary and secondary, or free defaults.
static func loadout(ids: Array[StringName]) -> Array[Weapon]:
	var selected: Array[Weapon] = [weapon(&"rifle"), weapon(&"shotgun")]
	for id in ids:
		var entry: Weapon = weapon(&"shotgun" if id == &"pistol" else id)
		if entry != null:
			selected[0 if entry.primary else 1] = entry
	return selected


## Weapons every run starts with (unlock cost 0).
static func starting_weapons() -> Array[StringName]:
	var ids: Array[StringName] = []
	for e: Array in _weapon_entries():
		if (e[1] as WeaponData).unlock_cost <= 0:
			ids.append(e[0])
	return ids


## Intel cost to unlock a weapon in the Armory; -1 if it is not for sale.
static func weapon_cost(id: StringName) -> int:
	for e: Array in _weapon_entries():
		if e[0] == id:
			var cost: int = (e[1] as WeaponData).unlock_cost
			return cost if cost > 0 else -1
	return -1


static func cards() -> Array[Card]:
	if _cards.is_empty():
		for e: Array in _entries(CARD_REGISTRY):
			var d: CardData = e[1]
			var c := Card.new(e[0], d.title, d.description, d.max_stacks)
			c.category = StringName(d.category)
			c.icon = d.icon
			c.tags = d.tags.duplicate()
			c.class_filter = d.class_filter.duplicate()
			c.weapon_filter = d.weapon_filter.duplicate()
			c.requires_finite_weapon = d.requires_finite_weapon
			c.prerequisites = d.prerequisites.duplicate()
			_cards.append(c)
	return _cards.duplicate()


## Every perk alternative of the tree (all classes), in registry order.
static func perks() -> Array[Perk]:
	if _perks.is_empty():
		for e: Array in _entries(PERK_REGISTRY):
			var d: PerkData = e[1]
			var item := Perk.new(e[0], d.title, d.description)
			item.branch = StringName(d.branch)
			item.tier = d.tier
			item.option = d.option
			item.class_filter = d.class_filter
			item.benefit = d.benefit
			item.benefit_values = d.benefit_values
			item.benefit_2 = d.benefit_2
			item.benefit_2_values = d.benefit_2_values
			item.penalty = d.penalty
			item.penalty_values = d.penalty_values
			_perks.append(item)
	return _perks.duplicate()


static func perk(id: StringName) -> Perk:
	for entry in perks():
		if entry.id == id:
			return entry
	return null


static func perk_node(branch: StringName, tier: int) -> StringName:
	return StringName("%s_%d" % [branch, tier])


## Every node id, branch by branch, tier I first.
static func perk_nodes() -> Array[StringName]:
	var ids: Array[StringName] = []
	for branch in PERK_BRANCHES:
		for tier in range(1, PERK_TIERS + 1):
			ids.append(perk_node(branch, tier))
	return ids


static func perk_node_branch(node: StringName) -> StringName:
	return StringName(String(node).get_slice("_", 0))


static func perk_node_tier(node: StringName) -> int:
	return int(String(node).get_slice("_", 1))


## The alternative `option` (0 = A, 1 = B) of `node` for `player_class`
## (Breaker III has one per class); null when none fits.
static func perk_for(node: StringName, option: int, player_class: StringName) -> Perk:
	for entry in perks():
		if entry.node() == node and entry.option == option and entry.fits_class(player_class):
			return entry
	return null


## Intel to buy rank `rank` (1..3) of a node of tier `tier`; -1 if invalid.
static func perk_rank_cost(tier: int, rank: int) -> int:
	if tier < 1 or tier > PERK_RANK_COSTS.size() or rank < 1 or rank > PERK_MAX_RANK:
		return -1
	return int(PERK_RANK_COSTS[tier - 1][rank - 1])


## "Headshot cone 13°": a perk text format with its value at a rank.
static func perk_text(format: String, value: float) -> String:
	var shown: String = str(int(value)) if is_equal_approx(value, roundf(value)) else String.num(value, 1)
	return format.replace("{v}", shown)


const RANK_NAMES: Array[String] = ["—", "I", "II", "III"]


## Threat level rules: enemy HP and Intel multipliers, extra enemies alive.
static func threat_hp(threat: int) -> float:
	return 1.0 + 0.2 * (threat - 1)


static func threat_intel(threat: int) -> float:
	return 1.0 + 0.25 * (threat - 1)


static func threat_extra_alive(threat: int) -> int:
	return 25 * (threat - 1)


## Island modifiers offered as routes on the boat: harder islands pay more
## Intel (game/data/modifiers/).
static func modifiers() -> Array[Modifier]:
	if _modifiers.is_empty():
		for e: Array in _entries(MODIFIER_REGISTRY):
			var d: ModifierData = e[1]
			_modifiers.append(Modifier.new(e[0], d.title, d.description, d.intel_mult))
	return _modifiers.duplicate()


static func modifier(id: StringName) -> Modifier:
	for m in modifiers():
		if m.id == id:
			return m
	return modifiers()[0]


static func _load_biomes() -> Dictionary:
	var out: Dictionary = {}
	for e: Array in _entries(BIOME_REGISTRY):
		var d: BiomeData = e[1]
		out[e[0]] = {"name": d.display_name, "coast": d.coast, "inland": d.inland, "building": d.building,
			"foliage": d.foliage, "sky": d.sky, "fog": d.fog, "palms": d.palms, "on_route": d.on_route,
			"grading": d.grading}
	return out


static func _route_biomes() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in BIOMES:
		if BIOMES[id]["on_route"]:
			ids.append(id)
	return ids


static func _load_missions() -> Dictionary:
	var out: Dictionary = {}
	for e: Array in _entries(MISSION_REGISTRY):
		var d: MissionData = e[1]
		out[e[0]] = {"name": d.display_name, "text": d.text, "on_route": d.on_route,
			"points": d.points, "seconds": d.seconds_per_point, "radius": d.radius,
			"pickup_radius": d.pickup_radius, "delivery_radius": d.delivery_radius,
			"carry_speed_mult": d.carry_speed_mult, "spike_seconds": d.spike_seconds,
			"nest_hp": d.nest_hp, "spawn_interval": d.spawn_interval, "spawn_count": d.spawn_count,
			"brood_cap": d.brood_cap, "wake_range": d.wake_range, "priority_range": d.priority_range,
			"preferred_biomes": d.preferred_biomes.duplicate(), "preferred_weight": d.preferred_weight}
	return out


static func _route_missions() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in MISSIONS:
		if MISSIONS[id]["on_route"]:
			ids.append(id)
	return ids


## Missions that feel the same (Defend and the expedition's Holdout both
## hold one zone) share a family; the rest are their own family.
static func mission_family(id: StringName) -> StringName:
	return &"defend" if id == &"holdout" else id


## The route missions the boat may draw after an island played with
## `previous` (&"" = first island): never the same mission, or one of its
## family, twice in a row (OBJECTIVES_PROPOSAL §4). Falls back to every
## route mission if that would leave none.
static func route_missions_after(previous: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in ROUTE_MISSIONS:
		if previous == &"" or mission_family(id) != mission_family(previous):
			out.append(id)
	return out if not out.is_empty() else ROUTE_MISSIONS.duplicate()


## Weight of mission `id` in the boat's draw for an island of `biome`: 1,
## or its preferred_weight on one of its preferred_biomes (Fuel Run is the
## Beach's signature: more likely there, still possible elsewhere).
static func mission_weight(id: StringName, biome: StringName) -> int:
	var m: Dictionary = MISSIONS.get(id, {})
	if biome in (m.get("preferred_biomes", []) as Array):
		return maxi(1, int(m.get("preferred_weight", 1)))
	return 1


## The boat's draw of one route mission for an island of `biome`, after an
## island played with `previous`: route_missions_after() (no repeat), each
## mission weighted by mission_weight(). A weighted lottery: add up the
## weights, roll below the total, walk the list until the roll is used up.
static func pick_route_mission(rng: RandomNumberGenerator, previous: StringName, biome: StringName) -> StringName:
	var pool: Array[StringName] = route_missions_after(previous)
	var total: int = 0
	for id: StringName in pool:
		total += mission_weight(id, biome)
	var roll: int = rng.randi_range(0, total - 1)
	for id: StringName in pool:
		roll -= mission_weight(id, biome)
		if roll < 0:
			return id
	return pool[-1]


## A number of a mission's data (e.g. &"hold_sequence", &"points"), or
## `default` when the mission or the key is missing.
static func mission_value(id: StringName, key: String, default: float) -> float:
	var v: float = float(MISSIONS.get(id, {}).get(key, 0.0))
	return v if v > 0.0 else default


static func _load_classes() -> Dictionary:
	var out: Dictionary = {}
	for e: Array in _entries(CLASS_REGISTRY):
		var d: ClassData = e[1]
		out[e[0]] = {"name": d.display_name, "cost": d.cost, "ability": d.ability, "text": d.text}
	return out


static func _class_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in CLASS_INFO:
		ids.append(id)
	return ids
