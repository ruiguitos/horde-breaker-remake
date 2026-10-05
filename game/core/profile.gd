class_name Profile
extends RefCounted
## Persistent player profile (meta progression), saved as versioned JSON in
## user:// (on Windows: %APPDATA%/Godot/app_userdata/Horde Breaker Remake).

const PATH: String = "user://profile.json"
const VERSION: int = 2

var intel: int = 0
var runs: int = 0
var extractions: int = 0
var best_kills: int = 0
var owned_perks: Array[StringName] = []
var equipped_perks: Array[StringName] = []
var slots: int = 1
var max_threat: int = 1  ## highest Threat unlocked (extract on N to unlock N+1)
var threat: int = 1  ## last chosen
var volume: int = 8  ## master volume, 0..10


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
	p.volume = clampi(int(d.get("volume", 8)), 0, 10)
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
		"slots": slots, "max_threat": max_threat, "threat": threat, "volume": volume}, "  "))
	return true


## Adds a finished run's results.
func record_run(ctx: RunContext) -> void:
	runs += 1
	intel += ctx.intel
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


## Applies the master volume (0 = mute, 10 = full) to the Master audio bus.
func apply_volume() -> void:
	AudioServer.set_bus_mute(0, volume == 0)
	AudioServer.set_bus_volume_db(0, linear_to_db(volume / 10.0) if volume > 0 else -80.0)
