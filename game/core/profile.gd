class_name Profile
extends RefCounted
## Persistent player profile (meta progression), saved as versioned JSON in
## user:// (on Windows: %APPDATA%/Godot/app_userdata/Horde Breaker Remake).

const PATH: String = "user://profile.json"
const VERSION: int = 3

var intel: int = 0
var runs: int = 0
var extractions: int = 0
var best_kills: int = 0
var owned_perks: Array[StringName] = []
var equipped_perks: Array[StringName] = []
var slots: int = 1
var max_threat: int = 1  ## highest Threat unlocked (extract on N to unlock N+1)
var threat: int = 1  ## last chosen
## Volumes in percent (0..100): Master, sound effects (incl. ambience), music.
var master_volume: int = 80
var sfx_volume: int = 100
var music_volume: int = 70

## The profile in use, so screens without a reference (e.g. the pause menu)
## can open the settings panel.
static var current: Profile
var unlocked_weapons: Array[StringName] = []  ## bought in the armory
var unlocked_classes: Array[StringName] = [&"recruit"]
var selected_class: StringName = &"recruit"
var lore_pages: int = 0
var graphics_high: bool = true  ## Intel files unlocked (Story.FILES, in order)


static func load_profile(path: String = PATH) -> Profile:
	var p := Profile.new()
	if not FileAccess.file_exists(path):
		return p
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_warning("Profile: unreadable save, starting fresh")
		return p
	var d: Dictionary = data
	# Version 1 had no perks or threat: the defaults above are the migration.
	p.intel = int(d.get("intel", 0))
	p.runs = int(d.get("runs", 0))
	p.extractions = int(d.get("extractions", 0))
	p.best_kills = int(d.get("best_kills", 0))
	for id in d.get("owned_perks", []):
		p.owned_perks.append(StringName(id))
	for id in d.get("equipped_perks", []):
		p.equipped_perks.append(StringName(id))
	p.slots = int(d.get("slots", 1))
	p.max_threat = int(d.get("max_threat", 1))
	p.lore_pages = int(d.get("lore_pages", 0))
	p.graphics_high = bool(d.get("graphics_high", true))
	# Version 2 stored one master volume 0..10; version 3 stores percentages.
	p.master_volume = clampi(int(d.get("master_volume", int(d.get("volume", 8)) * 10)), 0, 100)
	p.sfx_volume = clampi(int(d.get("sfx_volume", 100)), 0, 100)
	p.music_volume = clampi(int(d.get("music_volume", 70)), 0, 100)
	for id in d.get("unlocked_classes", []):
		if not p.unlocked_classes.has(StringName(id)):
			p.unlocked_classes.append(StringName(id))
	p.selected_class = StringName(d.get("selected_class", "recruit"))
	if not p.unlocked_classes.has(p.selected_class):
		p.selected_class = &"recruit"
	for id in d.get("unlocked_weapons", []):
		p.unlocked_weapons.append(StringName(id))
	p.threat = clampi(int(d.get("threat", 1)), 1, p.max_threat)
	return p


func save(path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Profile: cannot write " + path)
		return false
	f.store_string(JSON.stringify({
		"version": VERSION, "intel": intel, "runs": runs,
		"extractions": extractions, "best_kills": best_kills,
		"owned_perks": owned_perks.map(func(x: StringName) -> String: return String(x)),
		"equipped_perks": equipped_perks.map(func(x: StringName) -> String: return String(x)),
		"slots": slots, "max_threat": max_threat, "threat": threat, "master_volume": master_volume, "sfx_volume": sfx_volume, "music_volume": music_volume, "lore_pages": lore_pages, "graphics_high": graphics_high, "selected_class": String(selected_class),
		"unlocked_classes": unlocked_classes.map(func(x: StringName) -> String: return String(x)),
		"unlocked_weapons": unlocked_weapons.map(func(x: StringName) -> String: return String(x))}, "  "))
	return true


## Adds a finished run's results.
func record_run(ctx: RunContext) -> void:
	runs += 1
	intel += ctx.intel
	lore_pages = mini(Story.FILES.size(), lore_pages + ctx.lore_found)
	if ctx.won:
		extractions += 1
		if ctx.threat == max_threat and max_threat < GameData.MAX_THREAT:
			max_threat += 1
	best_kills = maxi(best_kills, ctx.kills)


## Buys a perk or the next slot. Returns false if not affordable.
func buy_perk(perk: GameData.Perk) -> bool:
	if owned_perks.has(perk.id) or intel < perk.cost:
		return false
	intel -= perk.cost
	owned_perks.append(perk.id)
	return true


func buy_class(id: StringName) -> bool:
	var cost: int = int(GameData.CLASS_INFO[id]["cost"])
	if unlocked_classes.has(id) or intel < cost:
		return false
	intel -= cost
	unlocked_classes.append(id)
	return true


func buy_weapon(id: StringName) -> bool:
	var cost: int = int(GameData.WEAPON_COSTS.get(id, -1))
	if cost < 0 or unlocked_weapons.has(id) or intel < cost:
		return false
	intel -= cost
	unlocked_weapons.append(id)
	return true


func next_slot_cost() -> int:
	return GameData.SLOT_COSTS[slots] if slots < GameData.SLOT_COSTS.size() else -1


func buy_slot() -> bool:
	var cost: int = next_slot_cost()
	if cost < 0 or intel < cost:
		return false
	intel -= cost
	slots += 1
	return true


## Equips or unequips an owned perk, respecting the slot count.
func toggle_equip(id: StringName) -> bool:
	if equipped_perks.has(id):
		equipped_perks.erase(id)
		return true
	if owned_perks.has(id) and equipped_perks.size() < slots:
		equipped_perks.append(id)
		return true
	return false


## Audio buses: every sound player sends to "SFX" or "Music", both routed
## to "Master". Created in code so project.godot stays untouched.
const BUS_SFX: StringName = &"SFX"
const BUS_MUSIC: StringName = &"Music"


static func ensure_buses() -> void:
	for bus_name in [BUS_SFX, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")


## Applies the three volumes (percent) to their buses.
func apply_volume() -> void:
	ensure_buses()
	_set_bus(&"Master", master_volume)
	_set_bus(BUS_SFX, sfx_volume)
	_set_bus(BUS_MUSIC, music_volume)


static func _set_bus(bus_name: StringName, percent: int) -> void:
	var i: int = AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, percent <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(percent / 100.0) if percent > 0 else -80.0)
