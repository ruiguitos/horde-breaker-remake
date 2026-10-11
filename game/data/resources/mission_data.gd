class_name MissionData
extends Resource
## One island mission (game/data/missions/). Rules are code (IslandRun).

@export var display_name: String = ""
@export_multiline var text: String = ""
## Offered on the boat's routes (false: only in expeditions, e.g. holdout).
@export var on_route: bool = true
@export var order: int = 0
@export_group("Hold points")
## Hold Sequence: how many points to hold, one after the other (the map's
## HoldPoint_* markers win when it has them).
@export var points: int = 0
## Seconds the player must stand in each point (leaving pauses it).
@export var seconds_per_point: float = 0.0
## Radius of each point, in metres.
@export var radius: float = 0.0
