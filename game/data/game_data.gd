class_name GameData
extends RefCounted
## Data definitions for the vertical slice. Values are playtest hypotheses:
## tweak them here, nothing else hardcodes balance numbers.


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

## Biomes: look and feel of each island. Islands 1-2 pick one on the boat;
## the last island is always the volcano.
const BIOMES: Dictionary = {
	&"beach": {"name": "Beach", "coast": Color(0.78, 0.7, 0.5), "inland": Color(0.62, 0.6, 0.42),
		"building": Color(0.55, 0.42, 0.3), "foliage": Color(0.3, 0.55, 0.25), "sky": Color(0.5, 0.7, 0.85),
		"fog": 0.0, "palms": true},
	&"town": {"name": "Coastal Town", "coast": Color(0.7, 0.66, 0.5), "inland": Color(0.4, 0.4, 0.38),
		"building": Color(0.62, 0.55, 0.5), "foliage": Color(0.25, 0.42, 0.22), "sky": Color(0.55, 0.62, 0.7),
		"fog": 0.0, "palms": false},
	&"jungle": {"name": "Jungle", "coast": Color(0.6, 0.58, 0.4), "inland": Color(0.2, 0.35, 0.15),
		"building": Color(0.4, 0.42, 0.36), "foliage": Color(0.12, 0.38, 0.14), "sky": Color(0.3, 0.42, 0.34),
		"fog": 0.006, "palms": true},
	&"port": {"name": "Industrial Port", "coast": Color(0.5, 0.5, 0.48), "inland": Color(0.36, 0.36, 0.36),
		"building": Color(0.7, 0.3, 0.2), "foliage": Color(0.25, 0.4, 0.22), "sky": Color(0.6, 0.62, 0.66),
		"fog": 0.0, "palms": false},
	&"volcano": {"name": "Volcano", "coast": Color(0.22, 0.2, 0.2), "inland": Color(0.32, 0.28, 0.26),
		"building": Color(0.3, 0.27, 0.26), "foliage": Color(0.16, 0.13, 0.12), "sky": Color(0.35, 0.18, 0.14),
		"fog": 0.0, "palms": false},
}
const ISLAND_BIOMES: Array[StringName] = [&"beach", &"town", &"jungle", &"port"]
const LAVA_PLAYER_DPS: float = 18.0
const LAVA_ENEMY_DPS: float = 30.0

## Missions (one per island, shown with the route on the boat)
const MISSIONS: Dictionary = {
	&"activate": {"name": "Activate 3", "text": "Power up three generators."},
	&"defend": {"name": "Defend", "text": "Hold the uplink zone for 75 s."},
	&"rescue": {"name": "Rescue", "text": "Find the survivor and bring them to the boat alive."},
}
const DEFEND_TIME: float = 75.0
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

## Weapons available from the start; the others are bought in the armory.
const STARTING_WEAPONS: Array[StringName] = [&"rifle", &"shotgun", &"pistol"]
const WEAPON_COSTS: Dictionary = {&"smg": 60, &"marksman": 80}

## Classes: passive + active ability. The Recruit is free; the others are bought.
const CLASSES: Array[StringName] = [&"recruit", &"vanguard"]
const CLASS_INFO: Dictionary = {
	&"recruit": {"name": "Recruit", "cost": 0, "ability": "Grenade",
		"text": "Balanced. Ability: Grenade (5 m blast)."},
	&"vanguard": {"name": "Vanguard", "cost": 150, "ability": "War Cry",
		"text": "+40 max HP, breaker cooldown -30%. Ability: War Cry (stun 7 m, -40% damage taken for 5 s)."},
}
const WAR_CRY_RADIUS: float = 7.0
const WAR_CRY_TIME: float = 5.0
const WAR_CRY_COOLDOWN: float = 16.0

## Meta progression
const SLOT_COSTS: Array[int] = [0, 100, 250]  ## cost of the 1st, 2nd, 3rd perk slot
const MAX_THREAT: int = 3
const EXTRACTION_INTEL_MULTIPLIER: float = 1.5

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


static func enemy_types() -> Array[EnemyType]:
	var walker := EnemyType.new(&"walker", "Walker", 30.0, Vector2(1.8, 2.6), 8.0, 1.0, 1.0, 1.7, Color(0.45, 0.6, 0.35), 1)
	var runner := EnemyType.new(&"runner", "Runner", 18.0, Vector2(4.6, 5.4), 6.0, 0.7, 0.85, 1.6, Color(0.85, 0.75, 0.25), 1)
	var brute := EnemyType.new(&"brute", "Brute", 260.0, Vector2(1.6, 1.9), 25.0, 1.6, 1.6, 2.4, Color(0.55, 0.25, 0.25), 6)
	brute.front_armor = 0.75
	brute.pushable = false
	var grabber := EnemyType.new(&"grabber", "Grabber", 70.0, Vector2(2.8, 3.2), 4.0, 0.5, 1.1, 1.9, Color(0.55, 0.35, 0.75), 3)
	grabber.grabs = true
	var boss := EnemyType.new(&"behemoth", "Behemoth", 1800.0, Vector2(1.7, 1.7), 35.0, 1.4, 3.0, 4.2, Color(0.3, 0.12, 0.15), 40)
	boss.front_armor = 0.5
	boss.pushable = false
	var bloater := EnemyType.new(&"bloater", "Bloater", 90.0, Vector2(1.3, 1.5), 10.0, 1.2, 1.7, 1.6, Color(0.5, 0.65, 0.2), 3)
	bloater.explodes = true
	var screamer := EnemyType.new(&"screamer", "Screamer", 45.0, Vector2(3.0, 3.4), 3.0, 1.0, 0.8, 1.8, Color(0.95, 0.9, 0.55), 4)
	screamer.keep_away = 11.0
	return [walker, runner, brute, grabber, boss, bloater, screamer]


static func weapons() -> Array[Weapon]:
	return [
		Weapon.new(&"rifle", "Assault Rifle", 12.0, 9.0, 30.0, 1, 2.0, 1, -1, 0.05),
		Weapon.new(&"shotgun", "Shotgun", 9.0, 1.4, 12.0, 8, 22.0, 2, 40, 0.6),
		Weapon.new(&"pistol", "Heavy Pistol", 60.0, 2.2, 35.0, 1, 0.0, 4, 60, 0.3),
		Weapon.new(&"smg", "SMG", 7.0, 16.0, 18.0, 1, 7.0, 1, 300, 0.02),
		Weapon.new(&"marksman", "Marksman Rifle", 110.0, 1.2, 45.0, 1, 0.0, 6, 30, 0.5),
	]


static func cards() -> Array[Card]:
	return [
		Card.new(&"shockwave", "Shockwave Breaker", "The breaker releases a shockwave: double radius and +30 damage.", 2),
		Card.new(&"quick_breaker", "Hair Trigger", "Breaker cooldown -30%.", 2),
		Card.new(&"ricochet", "Ricochet", "Every 4th shot also hits the nearest enemy to the target.", 1),
		Card.new(&"explosive_heads", "Pop Goes the Head", "Headshot kills explode (3 m, 30 damage).", 1),
		Card.new(&"vampire", "Field Medic", "Headshot kills heal 2 HP.", 2),
		Card.new(&"hollow_points", "Hollow Points", "+25% weapon damage.", 3),
		Card.new(&"fast_hands", "Fast Hands", "+20% fire rate.", 3),
		Card.new(&"magnet", "XP Magnet", "Pickup radius x2.", 1),
		Card.new(&"adrenaline", "Adrenaline", "Each kill cuts 0.3 s off the breaker cooldown.", 1),
		Card.new(&"executioner", "Executioner", "+60% damage to stunned enemies.", 2),
		Card.new(&"bigger_mags", "Bigger Mags", "+30% max special ammo.", 2),
		Card.new(&"grenadier", "Grenadier", "Grenade cooldown -20%.", 2),
	]


static func perks() -> Array[Perk]:
	return [
		Perk.new(&"thick_skin", "Thick Skin", "+30 max HP.", 40),
		Perk.new(&"pack_rat", "Pack Rat", "+50% Shotgun and Heavy Pistol ammo.", 40),
		Perk.new(&"head_hunter", "Head Hunter", "Wider headshot cone (9° -> 15°).", 60),
		Perk.new(&"long_breaker", "Battering Ram", "Breaker goes 40% further.", 50),
		Perk.new(&"demolitions", "Demolitions", "Grenade cooldown -35%, radius +1 m.", 50),
	]


## Threat level rules: enemy HP and Intel multipliers, extra enemies alive.
static func threat_hp(threat: int) -> float:
	return 1.0 + 0.2 * (threat - 1)


static func threat_intel(threat: int) -> float:
	return 1.0 + 0.25 * (threat - 1)


static func threat_extra_alive(threat: int) -> int:
	return 25 * (threat - 1)


## Island modifiers offered as routes on the boat: harder islands pay more Intel.
static func modifiers() -> Array[Modifier]:
	return [
		Modifier.new(&"calm", "Calm Waters", "No modifier.", 1.0),
		Modifier.new(&"swarm", "Swarm", "+40 enemies alive at once.", 1.3),
		Modifier.new(&"elite", "Elite Pack", "Brutes and Grabbers twice as common.", 1.3),
		Modifier.new(&"fog", "Sea Fog", "Thick fog: you see enemies late.", 1.2),
		Modifier.new(&"short", "Supply Shortage", "Special ammo halved; generators refill less.", 1.2),
	]


static func modifier(id: StringName) -> Modifier:
	for m in modifiers():
		if m.id == id:
			return m
	return modifiers()[0]
