class_name MissionData
extends Resource
## One island mission (game/data/missions/). Rules are code (IslandRun).

@export var display_name: String = ""
@export_multiline var text: String = ""
## Offered on the boat's routes (false: only in expeditions, e.g. holdout).
@export var on_route: bool = true
@export var order: int = 0
