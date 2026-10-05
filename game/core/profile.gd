class_name Profile
extends RefCounted
## Persistent player profile (meta progression), saved as versioned JSON in
## user:// (on Windows: %APPDATA%/Godot/app_userdata/Horde Breaker Remake).

const PATH: String = "user://profile.json"
const VERSION: int = 1

var intel: int = 0
var runs: int = 0
var extractions: int = 0
var best_kills: int = 0


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
	# Future versions migrate here, e.g. if d.version == 1: ...
	p.intel = int(d.get("intel", 0))
	p.runs = int(d.get("runs", 0))
	p.extractions = int(d.get("extractions", 0))
	p.best_kills = int(d.get("best_kills", 0))
	return p


func save(path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Profile: cannot write " + path)
		return false
	f.store_string(JSON.stringify({
		"version": VERSION, "intel": intel, "runs": runs,
		"extractions": extractions, "best_kills": best_kills}, "  "))
	return true


## Adds a finished run's results.
func record_run(ctx: RunContext) -> void:
	runs += 1
	intel += ctx.intel
	if ctx.won:
		extractions += 1
	best_kills = maxi(best_kills, ctx.kills)
