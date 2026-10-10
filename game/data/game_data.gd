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

	func _init(p_id: StringName, p_name: String, p_damage: float, p_rate: float, p_range: float,
			p_pellets: int, p_spread: float, p_pierce: int, p_ammo: int, p_knockback: float) -> void:
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


class Card:
	var id: StringName
	var title: String
	var description: String
	var max_stacks: int

	func _init(p_id: StringName, p_title: String, p_desc: String, p_max: int) -> void:
		id = p_id
		title = p_title
		description = p_desc
		max_stacks = p_max


class Perk:
	var id: StringName
	var title: String
	var description: String
	var cost: int

	func _init(p_id: StringName, p_title: String, p_desc: String, p_cost: int) -> void:
		id = p_id
		title = p_title
		description = p_desc
		cost = p_cost


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
const MAX_THREAT: int = 3
const EXTRACTION_INTEL_MULTIPLIER: float = 1.5

## Level-up cards: rerolls (PROVISIONAL: the user still has to decide,
## docs/design/PROGRESSION_AND_ECONOMY.md §1.6 P9). A reroll redraws the
## offer. The run starts with REROLLS_START; every island cleared that is
## not the last adds REROLLS_PER_ISLAND, never above REROLLS_MAX banked.
const REROLLS_START: int = 2
const REROLLS_PER_ISLAND: int = 1
const REROLLS_MAX: int = 3

## Card categories. PROVISIONAL: the card data has no category yet, so it
## is derived here from what each card changes (breaker, guns, staying
## alive). Unknown cards fall back to survival. Move this into CardData
## when the deck grows.
const CARD_CATEGORIES: Dictionary = {
	&"quick_breaker": &"breaker", &"shockwave": &"breaker",
	&"adrenaline": &"breaker", &"executioner": &"breaker",
	&"hollow_points": &"firearms", &"fast_hands": &"firearms",
	&"ricochet": &"firearms", &"explosive_heads": &"firearms",
	&"bigger_mags": &"firearms", &"grenadier": &"firearms",
	&"magnet": &"survival", &"vampire": &"survival",
}


static func card_category(id: StringName) -> StringName:
	return CARD_CATEGORIES.get(id, &"survival")


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
	# Quadratic: early levels come fast, later ones need real effort.
	# First playtest: the old linear curve (6 + 5n) maxed every card by ~300 kills.
	return 8 + level * 6 + level * level


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
			d.pellets, d.spread_deg, d.pierce, d.max_ammo, d.knockback))
	return list


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
			_cards.append(Card.new(e[0], d.title, d.description, d.max_stacks))
	return _cards.duplicate()


static func perks() -> Array[Perk]:
	if _perks.is_empty():
		for e: Array in _entries(PERK_REGISTRY):
			var d: PerkData = e[1]
			_perks.append(Perk.new(e[0], d.title, d.description, d.cost))
	return _perks.duplicate()


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
		out[e[0]] = {"name": d.display_name, "text": d.text, "on_route": d.on_route}
	return out


static func _route_missions() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: StringName in MISSIONS:
		if MISSIONS[id]["on_route"]:
			ids.append(id)
	return ids


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
