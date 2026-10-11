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
@export_group("Cargo")
## Fuel Run (`points` = how many cans): metres from a can at which the
## player picks it up (walking over it, or the interact action).
@export var pickup_radius: float = 0.0
## Fuel Run: metres from the delivery point (the map's Delivery marker, else
## the extraction point) at which a carried can counts as delivered.
@export var delivery_radius: float = 0.0
## Fuel Run: walking speed multiplier while carrying a can (carrying also
## means no sprint, no firing and no class ability).
@export var carry_speed_mult: float = 0.0
## Fuel Run: seconds of horde spike when a can is picked up the first time.
@export var spike_seconds: float = 0.0
@export_group("Boat draw")
## Biomes where the boat offers this mission more often: its "signature"
## islands (it can still be drawn anywhere).
@export var preferred_biomes: Array[StringName] = []
## Weight of this mission in the boat's draw on a preferred biome (every
## mission weighs 1 elsewhere): 3 = three times as likely as any other.
@export var preferred_weight: int = 1
