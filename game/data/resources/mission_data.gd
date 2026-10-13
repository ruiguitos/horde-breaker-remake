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
@export_group("Nests")
## Nests (`points` = how many nests, `radius` = a nest's radius in metres,
## `spike_seconds` = the horde spike when one is destroyed): hit points of
## a nest before the island's enemy HP scaling (threat and island number
## multiply it like they multiply every enemy's HP).
@export var nest_hp: float = 0.0
## Nests: seconds between two broods of a living nest.
@export var spawn_interval: float = 0.0
## Nests: enemies per brood.
@export var spawn_count: int = 0
## Nests: a nest stops spawning while this many enemies are already within
## 12 m of it (its own trickle is capped; the global caps still apply).
@export var brood_cap: int = 0
## Nests: only nests within this many metres of the player spawn (a far
## nest's brood would be lost on the way, or recycled on big islands).
@export var wake_range: float = 0.0
## Nests: auto-fire shoots any enemy within this many metres before a nest
## (enemies keep priority; see IslandRun._pick_target).
@export var priority_range: float = 0.0
@export_group("Intel search")
## Intel Search (`points` = how many search spots hold intel,
## `seconds_per_point` = seconds to search one spot, `radius` = metres from
## a spot to search it, `spike_seconds` = the horde spike when a search
## starts): how many spots the island offers (the map's Search_* markers win
## when it has them). Which spots hold the intel is seeded and hidden.
@export var search_spots: int = 0
## Intel Search: seconds from the landing to find the intel. When it runs
## out the search ends with what was found (zero: straight to extraction).
@export var time_limit: float = 0.0
## Intel Search: seconds the player must stand at the uplink to transmit
## the intel found (leaving pauses it), and the uplink's radius in metres.
@export var transmit_seconds: float = 0.0
@export var transmit_radius: float = 0.0
## Intel Search: Intel paid per intel item found (before the threat,
## route and hazard multipliers, like every mission's Intel).
@export var intel_reward: int = 0
@export_group("Boat draw")
## Biomes where the boat offers this mission more often: its "signature"
## islands (it can still be drawn anywhere).
@export var preferred_biomes: Array[StringName] = []
## Weight of this mission in the boat's draw on a preferred biome (every
## mission weighs 1 elsewhere): 3 = three times as likely as any other.
@export var preferred_weight: int = 1
