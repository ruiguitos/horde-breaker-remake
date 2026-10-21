class_name DevSandbox
extends RefCounted
## DEV SANDBOX on the title screen (docs/design/DEV_MENU.md, zona 1): a one-island
## test built from a form (island, mission, class, weapons, threat, seed). Debug
## builds only; the run saves nothing (DevOptions.dev_run). The island is played
## with no run around it, like TEST ISLAND.

const CLASSES: Array[StringName] = [&"recruit", &"vanguard"]
const THREATS: Array[int] = [1, 2, 3, 4, 5]


## The weapons the form offers for the primary slot (`primary` true) or the secondary.
static func weapons_for(primary: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	for w in GameData.weapons():
		if w.primary == primary:
			out.append(w.id)
	return out


## The form's starting values: the first island, mission, class and weapons.
static func default_config() -> Dictionary:
	var islands: PackedStringArray = HandmadeIsland.island_paths()
	var missions: Array = GameData.MISSIONS.keys()
	var primaries: Array[StringName] = weapons_for(true)
	var secondaries: Array[StringName] = weapons_for(false)
	return {
		"path": islands[0] if not islands.is_empty() else "",
		"mission": missions[0] if not missions.is_empty() else &"activate",
		"class": CLASSES[0],
		"primary": primaries[0],
		"secondary": secondaries[0],
		"threat": THREATS[0],
		"seed": 1,
	}


## The run context for a sandbox config: the class, weapons, threat, seed, biome
## and mission it names. Perks and cards come from `base`, the profile's.
static func apply(config: Dictionary, base: RunContext) -> RunContext:
	var loadout: Array[StringName] = [StringName(config["primary"]), StringName(config["secondary"])]
	base.apply_class(StringName(config["class"]))
	base.weapons = loadout
	base.threat = int(config["threat"])
	base.rng_seed = int(config["seed"])
	base.biome = StringName(String(config["path"]).get_file().get_slice("_", 0))
	base.mission = StringName(config["mission"])
	return base


## Opens the sandbox form over `parent`. `on_start` receives the chosen config.
static func open(parent: Node, on_start: Callable) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	var start: Dictionary = default_config()
	dialog.content.add_child(UiTheme.title("DEV SANDBOX", 36))
	dialog.content.add_child(UiTheme.label("Development builds only. One island with the settings below; nothing is saved.", 16, UiTheme.MUTED))
	var island := _choice(dialog.content, "Island", _island_items(), start["path"])
	var mission := _choice(dialog.content, "Mission", _mission_items(), start["mission"])
	var class_id := _choice(dialog.content, "Class", _class_items(), start["class"])
	var primary := _choice(dialog.content, "Primary weapon", _weapon_items(true), start["primary"])
	var secondary := _choice(dialog.content, "Secondary weapon", _weapon_items(false), start["secondary"])
	var threat := _choice(dialog.content, "Threat", _threat_items(), start["threat"])
	dialog.content.add_child(UiTheme.label("Seed", 14, UiTheme.MUTED))
	var seed_box := SpinBox.new()
	seed_box.min_value = 1
	seed_box.max_value = 99999
	seed_box.step = 1
	seed_box.value = start["seed"]
	dialog.content.add_child(seed_box)
	var go := UiTheme.button(dialog.content, "START ISLAND", func() -> void:
		var config := {
			"path": island.get_item_metadata(island.selected),
			"mission": mission.get_item_metadata(mission.selected),
			"class": class_id.get_item_metadata(class_id.selected),
			"primary": primary.get_item_metadata(primary.selected),
			"secondary": secondary.get_item_metadata(secondary.selected),
			"threat": threat.get_item_metadata(threat.selected),
			"seed": int(seed_box.value),
		}
		dialog.close()
		on_start.call(config))
	go.name = "StartIsland"
	return dialog


## One labelled OptionButton. Each item keeps its value as metadata; `value` is selected.
static func _choice(parent: Control, text: String, items: Array, value: Variant) -> OptionButton:
	parent.add_child(UiTheme.label(text, 14, UiTheme.MUTED))
	var box := OptionButton.new()
	for item: Array in items:
		box.add_item(item[0])
		box.set_item_metadata(box.item_count - 1, item[1])
		if item[1] == value:
			box.select(box.item_count - 1)
	parent.add_child(box)
	return box


static func _island_items() -> Array:
	var out: Array = []
	for path: String in HandmadeIsland.island_paths():
		out.append([path.get_file().get_basename().to_upper(), path])
	return out


static func _mission_items() -> Array:
	var out: Array = []
	for id: StringName in GameData.MISSIONS:
		out.append(["MISSION: " + String(GameData.MISSIONS[id]["name"]).to_upper(), id])
	return out


static func _class_items() -> Array:
	return [["Recruit", CLASSES[0]], ["Vanguard", CLASSES[1]]]


static func _weapon_items(primary: bool) -> Array:
	var out: Array = []
	for w in GameData.weapons():
		if w.primary == primary:
			out.append([w.display_name, w.id])
	return out


static func _threat_items() -> Array:
	var out: Array = []
	for t: int in THREATS:
		out.append(["Threat %d" % t, t])
	return out
