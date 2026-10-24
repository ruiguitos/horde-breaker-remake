class_name RunContext
extends RefCounted
## State that crosses islands within one run: health, level, cards, ammo
## and score. IslandRun loads it on landing and writes it back on extraction.

const ISLAND_COUNT: int = 3

var island_index: int = 0  ## 0-based island currently being played / next
var rng_seed: int = 0
var hp: float = GameData.PLAYER_MAX_HP
var shield: float = 0.0
var max_shield: float = GameData.PLAYER_MAX_SHIELD
var power_up_state: Dictionary = {}
var level: int = 1
var xp: int = 0
var xp_fraction: float = 0.0
## Dedicated card RNG carries between level-ups, supplies and islands.
var card_rng_state: int = 0
var card_stacks: Dictionary = {}
## Extra rerolls (Extra Reroll power-up) waiting for the next level-up
## card screen; it may be on the next island. Spent when that screen opens.
var bonus_rerolls: int = 0
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
## DEV preset of this run: &"horror" (beach_01 at dawn, see island.gd), else &"normal".
var atmosphere: StringName = &"normal"
## The assault rifle's model in this run: &"realistic" for the DEV visual test, &"" for the current one.
var rifle_model: StringName = &""
## Story pages recovered during this run.
var lore_found: int = 0
var perks: Array[StringName] = []
## Rank (1..3) of each equipped perk id.
var perk_ranks: Dictionary = {}
var max_hp: float = GameData.PLAYER_MAX_HP
## Equipped primary and secondary; ownership stays in Profile.
var weapons: Array[StringName] = GameData.starting_weapons()
var player_class: StringName = &"recruit"
## Priced cards the player has not bought: kept out of the offers.
var locked_cards: Array[StringName] = []
## Hazard pay accepted in the boat briefing: +25% Intel, +25% enemies on
## the next island only (reset when the island ends).
var hazard_pay: bool = false
## Telemetry: one Dictionary per island played (see IslandRun.save_to_context).
var island_log: Array[Dictionary] = []
## Expedition being played (Expeditions.ALL id); &"" = the archipelago run
## (boat, routes, 3 islands, volcano). In an expedition island_index is the
## index of the part being played, so seeds, difficulty and telemetry work
## the same way in both runs.
var expedition: StringName = &""
## The expedition's parts (name, scene, mission), copied when it starts.
var expedition_parts: Array = []


## Sets the class; call before apply_perks (both change max HP).
func apply_class(id: StringName) -> void:
	player_class = id
	if id == &"vanguard":
		max_hp += 40.0
	hp = max_hp


## Applies the equipped perks (ids -> rank 1..3; a missing rank counts as
## III, the rank old perks migrate to). Only these act during the run;
## perks for another class are dropped. Call after apply_class.
func apply_perks(p_perks: Array[StringName], ranks: Dictionary = {}) -> void:
	perks.clear()
	perk_ranks.clear()
	for id in p_perks:
		var perk: GameData.Perk = GameData.perk(id)
		if perk == null or not perk.fits_class(player_class) or perks.has(id):
			continue
		perks.append(id)
		perk_ranks[id] = clampi(int(ranks.get(id, GameData.PERK_MAX_RANK)), 1, GameData.PERK_MAX_RANK)
	max_hp += perk_value(&"thick_skin") - perk_cost(&"fleet_footed")
	hp = max_hp


func has_perk(id: StringName) -> bool:
	return perks.has(id)


## Rank of an equipped perk (0 = not equipped).
func perk_rank(id: StringName) -> int:
	return int(perk_ranks.get(id, 0)) if perks.has(id) else 0


## Benefit / trade-off totals of an equipped perk at its rank (0 if not).
func perk_value(id: StringName) -> float:
	var perk: GameData.Perk = GameData.perk(id)
	return perk.value(perk_rank(id)) if perk != null else 0.0


func perk_cost(id: StringName) -> float:
	var perk: GameData.Perk = GameData.perk(id)
	return perk.cost_value(perk_rank(id)) if perk != null else 0.0


## Healing outside the island (boat/camp) follows Thick Skin's trade-off.
func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount * (1.0 - perk_cost(&"thick_skin") / 100.0))


## Secondary weapons' reserve multiplier from perks (Pack Rat / Quick Draw);
## primaries are never changed. Card bonuses are added before this.
func secondary_ammo_mult() -> float:
	return (1.0 + perk_value(&"pack_rat") / 100.0) * (1.0 - perk_cost(&"quick_draw") / 100.0)


## Applies a supply card with the same instant-health rule as level-ups.
func grant_card(card: GameData.Card) -> void:
	var rank: int = int(card_stacks.get(card.id, 0))
	if rank >= card.max_stacks:
		return
	card_stacks[card.id] = rank + 1
	if card.id == &"thick_hide":
		max_hp += 15.0
		hp = minf(max_hp, hp + 15.0)


func _init(p_seed: int = 0) -> void:
	rng_seed = p_seed if p_seed != 0 else randi()


## Seed for the current island (each island has its own layout).
func island_seed() -> int:
	return rng_seed + island_index * 7919


## Islands (or expedition parts) in this run.
func island_count() -> int:
	return expedition_parts.size() if is_expedition() else ISLAND_COUNT


func is_last_island() -> bool:
	return island_index >= island_count() - 1


func is_expedition() -> bool:
	return expedition != &""


## Starts expedition `id` at part `index`: biome and mission come from the
## part. Returns false (context unchanged) for an unknown id or index.
func start_expedition(id: StringName, index: int = 0) -> bool:
	var list: Array = Expeditions.parts(id)
	if index < 0 or index >= list.size():
		return false
	expedition = id
	expedition_parts = list.duplicate(true)
	island_index = index
	_apply_part()
	return true


## Moves on to the next island (archipelago) or part (expedition).
func advance() -> void:
	island_index += 1
	if is_expedition():
		_apply_part()


## What the debrief shows about the island being played: biome, mission,
## modifier, hazard pay and part name. Taken on landing (hazard pay is
## reset when the island ends) and added to its island_log entry.
func island_info() -> Dictionary:
	return {"biome": String(biome), "mission": String(mission), "modifier": String(modifier),
		"hazard_pay": hazard_pay, "part": part_name()}


## The part being played (empty outside an expedition).
func part() -> Dictionary:
	if not is_expedition() or island_index < 0 or island_index >= expedition_parts.size():
		return {}
	return expedition_parts[island_index]


## Name of the part being played ("Carreiro do Mosteiro"); "" outside one.
func part_name() -> String:
	return String(part().get("name", ""))


## Scene of the part being played; "" outside an expedition.
func part_scene() -> String:
	return String(part().get("scene", ""))


func _apply_part() -> void:
	var p: Dictionary = part()
	if p.is_empty():
		return
	biome = Expeditions.biome(expedition)
	mission = p["mission"]
	modifier = &"calm"  # no route choice on foot
