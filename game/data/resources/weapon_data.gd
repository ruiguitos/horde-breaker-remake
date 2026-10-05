class_name WeaponData
extends Resource
## One weapon (a .tres in game/data/weapons/, listed in the YARD registry
## game/data/weapons.tres). Edit values in the inspector or in the editor's
## Registry tab (spreadsheet view); the id is the registry string id.

@export var display_name: String = ""
@export var damage: float = 10.0
@export var fire_rate: float = 1.0  ## shots per second
@export var range_m: float = 20.0
@export var pellets: int = 1
@export var spread_deg: float = 0.0
@export var pierce: int = 1  ## enemies hit per pellet
@export var max_ammo: int = -1  ## -1 = infinite
@export var knockback: float = 0.0  ## metres pushed per hit
@export var unlock_cost: int = 0  ## Intel in the Armory; 0 = starting weapon
@export var order: int = 0  ## slot order (keys 1-5)
