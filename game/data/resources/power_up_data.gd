class_name PowerUpData
extends Resource
## One kill power-up (game/data/power_ups/, YARD registry
## game/data/power_ups.tres). Only per-type values live here; the global
## drop rules (chance, pity, cooldown, time on the ground, blink) stay in
## GameData because they apply to every power-up alike. Values are
## playtest hypotheses. Effect fields only matter for their own power-up.

@export var display_name: String = ""
## Glyph drawn on the ground pickup, the HUD timers and the island report.
@export var glyph: String = ""
## Colour of the ground ring and glyph.
@export var color: Color = Color("7fc8b8")
## Relative chance of being THE power-up that drops (the drop itself is
## decided by the global rules). All equal = uniform draw.
@export_range(0.0, 10.0, 0.05) var weight: float = 1.0
## Only offered while the player carries a weapon with finite ammo.
@export var requires_finite_weapon: bool = false
## Timed effects (Insta-Kill, Double XP / Intel): seconds active.
@export var duration: float = 0.0
## Nuke: seconds without new spawns after the blast.
@export var spawn_delay: float = 0.0
## Extra Reroll: rerolls added (still capped by REROLLS_MAX).
@export var reroll_amount: int = 0
## Max Shield: fraction of the max shield filled (1 = full).
@export_range(0.0, 1.0, 0.05) var shield_fill: float = 0.0
## Old ids that map to this power-up (only run telemetry ever stored them).
@export var legacy_ids: Array[StringName] = []
@export var order: int = 0
