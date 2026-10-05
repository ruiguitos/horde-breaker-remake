class_name ClassData
extends Resource
## One playable class (game/data/classes/). Abilities are code (IslandRun);
## this holds the text and price shown in the Armory.

@export var display_name: String = ""
@export var cost: int = 0  ## Intel; 0 = free
@export var ability: String = ""
@export_multiline var text: String = ""
@export var order: int = 0
