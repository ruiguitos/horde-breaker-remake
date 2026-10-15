class_name Briefing
extends RefCounted
## The game state the boat briefing dialogue can see (Dialogue Manager:
## `game/data/dialogue/briefing.dialogue`). The dialogue reads these
## properties with {{briefing.x}} and calls take_hazard_pay() with `do`.
## Writers edit the .dialogue file; numbers and rules stay here.

const RESOURCE: String = "res://game/data/dialogue/briefing.dialogue"
## last_result: "hurt" under this share of max HP, "fast" under these seconds.
const HURT_RATIO: float = 0.35
const FAST_SECONDS: float = 240.0

## Short lore per biome, in Director Hale's voice.
const ISLAND_LORE: Dictionary = {
	&"beach": "A holiday resort, once. The brochures promised 'unforgettable crowds'. Accurate.",
	&"town": "A fishing town. The streets are a grid, so they come at you from every corner. Watch the junctions.",
	&"jungle": "Thick canopy, bad sight lines. The specials love it here. So do the insects.",
	&"port": "Our old container terminal. Narrow aisles between the stacks. Good for choke points, bad for running.",
	&"volcano": "Project TIDE's main lab sits under that mountain. So does the Behemoth. Lava is warm, by the way. Avoid it.",
}
const ADVICE: Dictionary = {
	&"activate": "Generators need you standing next to them. Clear a space first, then hold.",
	&"defend": "The uplink zone is a circle. Stay inside it. Use the breaker to push them out, not to leave.",
	&"rescue": "The surveyor follows you, slowly, and they don't heal. Take the short way back.",
	&"hold_sequence": "The points come one at a time. Leave a point and its clock stops. Clear a space, then hold.",
	&"fuel_run": "One can at a time, and you can't shoot with your hands full. Put it down to fight, pick it up after.",
	&"nests": "Nests keep breeding while they stand. Pick your order, thin the crowd, then put everything you have into the mound.",
	&"intel_search": "Not every marked spot has something. Search, don't linger: when the clock runs out you send what you have.",
	&"signals": "Only the next beacon is marked, and its fuel lies close by. Carry it in, stay while it catches, then follow the light.",
	&"sabotage": "Switch first: the charges won't take while the line is live. Then wire the machine and run. Be well clear when the fuse runs out.",
	&"escort": "It only moves while you walk beside it, and nothing gets past what stands in front of it. Clear the road, hold at the stops, fix it when it breaks.",
	&"holdout": "Hold the courtyard until I can send the boat. When it comes, run for the pier. It won't wait.",
}

var context: RunContext
var hazard_pay: bool = false


func _init(ctx: RunContext) -> void:
	context = ctx
	hazard_pay = ctx.hazard_pay


var island_name: String:
	get:
		return String(GameData.BIOMES[context.biome]["name"])

var mission_name: String:
	get:
		return String(GameData.MISSIONS[context.mission]["name"])

var mission_text: String:
	get:
		return String(GameData.MISSIONS[context.mission]["text"])

var island_lore: String:
	get:
		return ISLAND_LORE.get(context.biome, "We know nothing. That's why we're paying you.")

var advice: String:
	get:
		return ADVICE.get(context.mission, "Don't die.")

## Conditions the dialogue can test (`if briefing.threat >= 3`): the run's
## threat, the expedition and part being played, and how the previous
## island of this run went.
var threat: int:
	get:
		return context.threat

var is_expedition: bool:
	get:
		return context.is_expedition()

## Expedition id ("berlenga"), "" on the archipelago.
var expedition: String:
	get:
		return String(context.expedition)

## 1-based part number in an expedition (0 on the archipelago).
var part_index: int:
	get:
		return context.island_index + 1 if context.is_expedition() else 0

var part_name: String:
	get:
		return context.part_name()

## 1-based island (or part) number in this run.
var island_number: int:
	get:
		return context.island_index + 1

## Islands (or parts) already played in this run.
var islands_done: int:
	get:
		return context.island_log.size()

## How the previous island went: "none" (first island), "hurt" (left with
## under HURT_RATIO of max HP), "fast" (cleared in under FAST_SECONDS) or
## "cleared".
var last_result: String:
	get:
		if context.island_log.is_empty():
			return "none"
		var last: Dictionary = context.island_log[-1]
		if float(last.get("hp_left", context.max_hp)) < context.max_hp * HURT_RATIO:
			return "hurt"
		if float(last.get("seconds", 9999.0)) < FAST_SECONDS:
			return "fast"
		return "cleared"

## Current health in percent of max (what the run carries to this island).
var hp_percent: int:
	get:
		return roundi(100.0 * context.hp / maxf(1.0, context.max_hp))


## "Deal": the next island pays more and spawns more enemies.
func take_hazard_pay() -> void:
	hazard_pay = true
	context.hazard_pay = true
