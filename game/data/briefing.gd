class_name Briefing
extends RefCounted
## The game state the boat briefing dialogue can see (Dialogue Manager:
## `game/data/dialogue/briefing.dialogue`). The dialogue reads these
## properties with {{briefing.x}} and calls take_hazard_pay() with `do`.
## Writers edit the .dialogue file; numbers and rules stay here.

const RESOURCE: String = "res://game/data/dialogue/briefing.dialogue"

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


## "Deal": the next island pays more and spawns more enemies.
func take_hazard_pay() -> void:
	hazard_pay = true
	context.hazard_pay = true
