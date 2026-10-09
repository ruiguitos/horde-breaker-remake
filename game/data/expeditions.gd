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

## id -> what the run choice and TEST ISLAND show: name, one-line text,
## biome (look, enemies and music of every part) and the whole island scene.
const INFO: Dictionary = {
	&"berlenga": {
		"name": "Berlenga Expedition",
		"text": "One real island, four parts on foot: rescue, activate, defend, then hold the fort until the boat comes.",
		"biome": &"beach",
		"whole": DIR + "berlenga/whole.scn",
	},
}

## Tests only: id -> parts used instead of ALL (e.g. existing islands as
## stand-ins while the real part scenes are not built). Empty in the game.
static var stand_ins: Dictionary = {}


## The parts of expedition `id` (empty when unknown).
static func parts(id: StringName) -> Array:
	return stand_ins.get(id, ALL.get(id, []))


## Name shown in menus ("Berlenga Expedition").
static func display_name(id: StringName) -> String:
	return String(INFO.get(id, {}).get("name", String(id).capitalize()))


static func biome(id: StringName) -> StringName:
	return INFO.get(id, {}).get("biome", &"beach")


## True when every part scene of `id` exists, so the run can be played.
static func available(id: StringName) -> bool:
	var list: Array = parts(id)
	if list.is_empty():
		return false
	for part: Dictionary in list:
		if not ResourceLoader.exists(String(part["scene"])):
			return false
	return true


## Where a scene path sits in an expedition: {expedition, index} for a
## part, {expedition, index = -1} for the whole island, {} otherwise.
static func locate(path: String) -> Dictionary:
	for id: StringName in INFO:
		var list: Array = parts(id)
		for i in list.size():
			if String(list[i]["scene"]) == path:
				return {"expedition": id, "index": i}
		if String(INFO[id].get("whole", "")) == path:
			return {"expedition": id, "index": -1}
	return {}


## TEST ISLAND entries for the expedition scenes that exist: path, label,
## mission (&"" = the player picks one; a part brings its own).
static func test_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id: StringName in INFO:
		var short: String = display_name(id).get_slice(" ", 0).to_upper()
		var whole: String = String(INFO[id].get("whole", ""))
		if whole != "" and ResourceLoader.exists(whole):
			out.append({"path": whole, "label": "%s / WHOLE ISLAND" % short, "mission": &"",
				"id": "%s_whole" % id})
		var list: Array = parts(id)
		for i in list.size():
			var part: Dictionary = list[i]
			if ResourceLoader.exists(String(part["scene"])):
				out.append({"path": String(part["scene"]), "mission": part["mission"],
					"label": "%s %d / %s (%s)" % [short, i + 1, String(part["name"]).to_upper(), mission_name(part["mission"]).to_upper()],
					"id": "%s_%d" % [id, i + 1]})
	return out


## A mission's display name, also for ids GameData does not know yet.
static func mission_name(mission: StringName) -> String:
	return String(GameData.MISSIONS.get(mission, {}).get("name", String(mission).capitalize()))
