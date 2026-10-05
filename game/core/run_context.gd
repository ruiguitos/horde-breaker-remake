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


func _init(p_seed: int = 0) -> void:
	rng_seed = p_seed if p_seed != 0 else randi()


## Seed for the current island (each island has its own layout).
func island_seed() -> int:
	return rng_seed + island_index * 7919


func is_last_island() -> bool:
	return island_index >= ISLAND_COUNT - 1
