class_name PerkData
extends Resource
## One perk of the Armory tree (game/data/perks/, YARD registry
## game/data/perks.tres). The tree has three branches x three tiers; each
## node has two alternatives (A/B) with a trade-off. Ranks are bought per
## NODE (both alternatives share them); the values below are totals per
## rank I/II/III, not increments. All numbers are playtest hypotheses.
## Text formats take one value with "%s" (e.g. "Headshot cone %s°").

@export var title: String = ""
## One-line play style shown in the Armory detail panel.
@export_multiline var description: String = ""
@export_enum("combat", "survival", "breaker", "logistics") var branch: String = "combat"
@export_range(1, 3) var tier: int = 1
## 0 = alternative A, 1 = alternative B.
@export_range(0, 1) var option: int = 0
## Class that can use this perk (Breaker III has class variants); empty = all.
@export var class_filter: StringName = &""
## Benefit (▲), an optional second benefit and the trade-off (▼).
@export var benefit: String = ""
@export var benefit_values: PackedFloat32Array = PackedFloat32Array()
@export var benefit_2: String = ""
@export var benefit_2_values: PackedFloat32Array = PackedFloat32Array()
@export var penalty: String = ""
@export var penalty_values: PackedFloat32Array = PackedFloat32Array()
@export var order: int = 0
