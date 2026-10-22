extends SceneTree
## The profile survives a second save and a damaged file (docs/tech/GAME_AUDIT.md,
## T04 and T05): a save replaces the file, the last readable save is kept as .bak,
## and an unreadable file is copied aside (.damaged-<time>) before the backup loads.
## Run: godot --headless --path . --script res://tests/test_profile_save.gd

const PATH: String = "user://test_profile_save.json"

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_clean()
	var first := Profile.new()
	first.intel = 100
	_check(first.save(PATH) and FileAccess.file_exists(PATH), "the first save writes the profile")
	var second := Profile.new()
	second.intel = 250
	_check(second.save(PATH), "a second save replaces the existing profile")
	_check(Profile.load_profile(PATH).intel == 250, "the file holds the second save")
	_check(_intel_in(PATH + ".bak") == 100, "the .bak keeps the save before the last one")
	_check(not FileAccess.file_exists(PATH + ".tmp"), "no temporary file is left behind")

	var damaged := FileAccess.open(PATH, FileAccess.WRITE)
	damaged.store_string("{ this is not json")
	damaged.close()
	_check(Profile.load_profile(PATH).intel == 100, "an unreadable profile loads the last good save")
	_check(_damaged_copies().size() == 1, "the unreadable file is kept as a .damaged copy")
	if _damaged_copies().size() == 1:
		var copy := FileAccess.get_file_as_string("user://" + _damaged_copies()[0])
		_check(copy == "{ this is not json", "the .damaged copy has the original bytes")
	_clean()
	quit(1 if _failures > 0 else 0)


## The intel of the profile saved at `path`, or -1 when it cannot be read.
func _intel_in(path: String) -> int:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(data.get("intel", -1)) if data is Dictionary else -1


## Names of the .damaged copies made for PATH (in user://).
func _damaged_copies() -> PackedStringArray:
	var out := PackedStringArray()
	for file_name: String in DirAccess.get_files_at("user://"):
		if file_name.begins_with("test_profile_save.json.damaged-"):
			out.append(file_name)
	return out


func _clean() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(PATH + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH + suffix))
	for file_name: String in _damaged_copies():
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + file_name))
