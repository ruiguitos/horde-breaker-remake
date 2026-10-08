class_name Expeditions
extends RefCounted
## Expeditions: one big real island played in parts, in order, on foot
## (docs/design/BERLENGA_EXPEDITION.md). Each part is a HandmadeIsland scene
## built by tools/real_island/build.gd; reaching its Exit marker leads to the
## next part, the last one ends the run.

const DIR: String = "res://game/world/handmade/expeditions/"

## id -> parts: name (shown in game), scene, mission.
const ALL: Dictionary = {
	&"berlenga": [
		{"name": "Carreiro do Mosteiro", "scene": DIR + "berlenga/part_1.scn", "mission": &"rescue"},
		{"name": "Lighthouse Plateau", "scene": DIR + "berlenga/part_2.scn", "mission": &"activate"},
		{"name": "Southwest Coast", "scene": DIR + "berlenga/part_3.scn", "mission": &"defend"},
		{"name": "Fort of Sao Joao Baptista", "scene": DIR + "berlenga/part_4.scn", "mission": &"holdout"},
	],
}


## The parts of expedition `id` (empty when unknown).
static func parts(id: StringName) -> Array:
	return ALL.get(id, [])
