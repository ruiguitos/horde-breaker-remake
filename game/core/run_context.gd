class_name RunContext
extends RefCounted
## State that crosses islands within one run: health, level, cards, ammo
## and score. IslandRun loads it on landing and writes it back on extraction.

const ISLAND_COUNT: int = 3

var island_index: int = 0  ## 0-based island currently being played / next
var rng_seed: int = 0
var hp: float = GameData.PLAYER_MAX_HP
var level: int = 1
var xp: int = 0
var card_stacks: Dictionary = {}
var ammo: PackedInt32Array = PackedInt32Array()
var kills: int = 0
var headshots: int = 0
var time_alive: float = 0.0
var intel: int = 0
var won: bool = false
var threat: int = 1
## Modifier of the island being played (chosen on the boat as a route).
var modifier: StringName = &"calm"
## Biome of the island being played (chosen with the route).
var biome: StringName = &"beach"
## Mission of the island being played: activate, defend or rescue.
var mission: StringName = &"activate"
## Story pages recovered during this run.
var lore_found: int = 0
var perks: Array[StringName] = []
var max_hp: float = GameData.PLAYER_MAX_HP
## Weapons usable in this run (starting ones + armory unlocks).
var weapons: Array[StringName] = GameData.STARTING_WEAPONS.duplicate()
var player_class: StringName = &"recruit"
## Telemetry: one Dictionary per island played (see IslandRun.save_to_context).
var island_log: Array[Dictionary] = []


## Sets the class; call before apply_perks (both change max HP).
func apply_class(id: StringName) -> void:
	player_class = id
	if id == &"vanguard":
		max_hp += 40.0
	hp = max_hp


## Applies the equipped perks that change starting values.
func apply_perks(p_perks: Array[StringName]) -> void:
	perks = p_perks.duplicate()
	if perks.has(&"thick_skin"):
		max_hp += 30.0
	hp = max_hp


func has_perk(id: StringName) -> bool:
	return perks.has(id)


func _init(p_seed: int = 0) -> void:
	rng_seed = p_seed if p_seed != 0 else randi()


## Seed for the current island (each island has its own layout).
func island_seed() -> int:
	return rng_seed + island_index * 7919


func is_last_island() -> bool:
	return island_index >= ISLAND_COUNT - 1
