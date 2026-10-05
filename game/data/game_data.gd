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


enum EnemyKind { WALKER, RUNNER, BRUTE, GRABBER }

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

## Grenade (Recruit active ability)
const GRENADE_COOLDOWN: float = 12.0
const GRENADE_RANGE: float = 14.0
const GRENADE_FUSE: float = 0.8
const GRENADE_RADIUS: float = 5.0
const GRENADE_DAMAGE: float = 90.0

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
	return 6 + level * 5


static func enemy_types() -> Array[EnemyType]:
	var walker := EnemyType.new(&"walker", "Walker", 30.0, Vector2(1.8, 2.6), 8.0, 1.0, 1.0, 1.7, Color(0.45, 0.6, 0.35), 1)
	var runner := EnemyType.new(&"runner", "Runner", 18.0, Vector2(4.6, 5.4), 6.0, 0.7, 0.85, 1.6, Color(0.85, 0.75, 0.25), 1)
	var brute := EnemyType.new(&"brute", "Brute", 260.0, Vector2(1.6, 1.9), 25.0, 1.6, 1.6, 2.4, Color(0.55, 0.25, 0.25), 6)
	brute.front_armor = 0.75
	brute.pushable = false
	var grabber := EnemyType.new(&"grabber", "Grabber", 70.0, Vector2(2.8, 3.2), 4.0, 0.5, 1.1, 1.9, Color(0.55, 0.35, 0.75), 3)
	grabber.grabs = true
	return [walker, runner, brute, grabber]


static func weapons() -> Array[Weapon]:
	return [
		Weapon.new(&"rifle", "Assault Rifle", 12.0, 9.0, 30.0, 1, 2.0, 1, -1, 0.05),
		Weapon.new(&"shotgun", "Shotgun", 9.0, 1.4, 12.0, 8, 22.0, 2, 40, 0.6),
		Weapon.new(&"pistol", "Heavy Pistol", 60.0, 2.2, 35.0, 1, 0.0, 4, 60, 0.3),
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
