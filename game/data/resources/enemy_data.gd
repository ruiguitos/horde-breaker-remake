class_name EnemyData
extends Resource
## One enemy type (game/data/enemies/, YARD registry game/data/enemies.tres).
## `order` must match GameData.EnemyKind (the simulation indexes by it).

@export var display_name: String = ""
@export var hp: float = 30.0
@export var speed_min: float = 2.0
@export var speed_max: float = 2.5
@export var damage: float = 8.0  ## per hit on the player
@export var attack_interval: float = 1.0  ## seconds between hits
@export var radius_scale: float = 1.0  ## visual size multiplier
@export var height: float = 1.7
@export var color: Color = Color.WHITE
@export var xp: int = 1
@export_range(0.0, 1.0) var front_armor: float = 0.0  ## damage reduction when hit from the front
@export var grabs: bool = false  ## holds the player until killed or broken free
@export var pushable: bool = true  ## the breaker pushes it away
@export var keep_away: float = 0.0  ## > 0: backs off when the player is closer
@export var explodes: bool = false  ## blows up on death, hurting everyone around
@export var order: int = 0
