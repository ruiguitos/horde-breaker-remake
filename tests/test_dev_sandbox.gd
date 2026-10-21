extends SceneTree
## DEV SANDBOX (docs/design/DEV_MENU.md, zona 1): the form starts on valid
## choices, its config builds the run it names, the button hands that config to
## its caller, and a sandbox run saves nothing.
## Run: godot --headless --path . --script res://tests/test_dev_sandbox.gd

const SAVE_PATH: String = "user://test_dev_sandbox_profile.json"

var _failures: int = 0
var _picked: Dictionary = {}


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _on_pick(config: Dictionary) -> void:
	_picked = config


func _run() -> void:
	var start: Dictionary = DevSandbox.default_config()
	_check(not String(start["path"]).is_empty(), "the form starts on an existing island")
	_check(GameData.weapon(StringName(start["primary"])).primary and not GameData.weapon(StringName(start["secondary"])).primary,
		"the form starts with a primary and a secondary weapon in their slots")
	_check(int(start["threat"]) >= 1 and int(start["threat"]) <= 5, "the form starts on a threat from 1 to 5")

	var paths: PackedStringArray = HandmadeIsland.island_paths()
	var pick: Dictionary = {
		"path": paths[paths.size() - 1],
		"mission": GameData.MISSIONS.keys()[-1],
		"class": &"vanguard",
		"primary": &"machine_gun",
		"secondary": &"marksman",
		"threat": 4,
		"seed": 777,
	}
	var ctx: RunContext = DevSandbox.apply(pick, RunContext.new())
	_check(ctx.player_class == &"vanguard" and ctx.weapons == [&"machine_gun", &"marksman"] and ctx.threat == 4 and ctx.rng_seed == 777,
		"the run context carries the class, weapons, threat and seed of the form")
	_check(ctx.biome == StringName(String(paths[paths.size() - 1]).get_file().get_slice("_", 0)) and ctx.mission == pick["mission"],
		"the run context takes its biome from the island file and its mission from the form")

	var parent := Control.new()
	root.add_child(parent)
	_picked = {}
	var dialog: MenuDialog = DevSandbox.open(parent, _on_pick)
	var go := dialog.content.find_child("StartIsland", true, false) as Button
	_check(go != null, "the sandbox form has a start button")
	if go != null:
		go.pressed.emit()
	_check(_picked.size() == 7 and _picked["path"] == start["path"] and _picked["class"] == start["class"] and _picked["seed"] == start["seed"],
		"start hands the form's choices to its caller")

	DevOptions.dev_run = true
	var profile := Profile.new()
	var saved: bool = profile.save(SAVE_PATH)
	_check(not saved and not FileAccess.file_exists(SAVE_PATH), "a sandbox run writes no profile")
	DevOptions.dev_run = false
	_check(profile.save(SAVE_PATH) and FileAccess.file_exists(SAVE_PATH), "once the sandbox is over, the profile saves again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	parent.free()
	quit(1 if _failures > 0 else 0)
