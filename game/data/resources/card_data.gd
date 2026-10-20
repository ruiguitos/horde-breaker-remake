class_name CardData
extends Resource
## One level-up card (game/data/cards/, YARD registry game/data/cards.tres).

@export var title: String = ""
@export_multiline var description: String = ""
@export var max_stacks: int = 1
@export_enum("primary_weapon", "elements", "defense", "sustain", "utility", "breaker", "class_recruit", "class_vanguard") var category: String = "utility"
## Vector glyph drawn by the HUD; no external icon asset required.
@export var icon: StringName = &"utility"
@export var tags: Array[StringName] = []
@export var class_filter: Array[StringName] = []
@export var weapon_filter: Array[StringName] = []
@export var requires_finite_weapon: bool = false
## Card ID -> minimum owned rank.
@export var prerequisites: Dictionary[StringName, int] = {}
@export var order: int = 0
## Intel to buy the card in the Armory; 0 = in the offers from the start.
@export var unlock_cost: int = 0
