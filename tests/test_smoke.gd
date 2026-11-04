extends SceneTree
## Smoke test: the main scene loads and instantiates, and every script under game/ compiles.
## The game's states are loaded at run time, so a parse error in one of them would pass every
## test that never loads it.
## Run: godot --headless --path . --script res://tests/test_smoke.gd

const GAME_ROOT: String = "res://game"


func _initialize() -> void:
	var failures := 0
	var packed := load("res://game/main.tscn") as PackedScene
	if packed == null:
		print("TEST FAIL: main scene did not load")
		failures += 1
	else:
		var root := packed.instantiate()
		if root == null:
			print("TEST FAIL: main scene did not instantiate")
			failures += 1
		else:
			print("TEST: main scene instantiates")
			root.free()
	var scripts: Array[String] = scripts_under(GAME_ROOT)
	var broken: Array[String] = broken_among(scripts)
	if scripts.is_empty():
		print("TEST FAIL: no scripts found under %s" % GAME_ROOT)
		failures += 1
	elif broken.is_empty():
		print("TEST: all %d scripts under game/ compile" % scripts.size())
	else:
		print("TEST FAIL: scripts that do not compile: %s" % ", ".join(PackedStringArray(broken)))
		failures += 1
	quit(1 if failures > 0 else 0)


## Every .gd file under `root`, recursively. A folder that cannot be read adds nothing.
static func scripts_under(root: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(root)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(scripts_under(root.path_join(sub)))
	for file_name in dir.get_files():
		if file_name.ends_with(".gd"):
			found.append(root.path_join(file_name))
	return found


## The paths that do not compile. A script with a parse error still comes back from load()
## (the error is logged), but it cannot be instantiated: the check asks the script itself.
static func broken_among(paths: Array[String]) -> Array[String]:
	var broken: Array[String] = []
	for path in paths:
		var script := load(path) as Script
		if script == null or not script.can_instantiate():
			broken.append(path)
	return broken
