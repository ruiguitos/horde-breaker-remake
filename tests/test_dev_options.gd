extends SceneTree
## Dev options (docs/design/DEV_MENU.md, zona 2): off by default, each one
## changes the run it is for, the horde limit stops at the hard cap, and a run
## that changes the balance saves no profile. Infinite ammo is checked as a
## flag only: the fire path needs a live target, which the scene tests cover.
## Run: godot --headless --path . --script res://tests/test_dev_options.gd

const PROFILE_PATH: String = "user://test_dev_options_profile.json"

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DevOptions.reset()
	_check(DevOptions.enabled() == OS.is_debug_build(), "the dev options exist only where OS.is_debug_build() is true")
	_check(not DevOptions.changes_balance(), "by default no option changes the balance")

	var run := IslandRun.new(7, &"beach")
	run.shield = 0.0
	var hp: float = run.hp
	DevOptions.invincible = true
	run._take_player_damage(10.0, &"test")
	_check(is_equal_approx(run.hp, hp), "invincible: a hit does no damage")
	DevOptions.invincible = false
	run._take_player_damage(10.0, &"test")
	_check(run.hp < hp, "without it the same hit lands")

	run.set_horde_alive(50)
	_check(run.director.max_alive == 50, "the enemies-alive limit can be set (50)")
	run.set_horde_alive(999)
	_check(run.director.max_alive == GameData.HORDE_CAP, "the enemies-alive limit stops at the hard cap (%d)" % GameData.HORDE_CAP)

	var before: int = run.horde.count
	run.dev_spawn(GameData.EnemyKind.BRUTE)
	_check(run.horde.count == before + 1 and run.horde.kinds[before] == GameData.EnemyKind.BRUTE,
		"spawn adds one enemy of the chosen kind")

	var level: int = run.level
	var xp: int = run.xp
	run.dev_grant_xp(100)
	_check(run.level > level or run.xp > xp, "granting XP raises the XP or the level")

	DevOptions.infinite_ammo = true
	_check(DevOptions.changes_balance() and DevOptions.active_labels().has("Infinite ammo"),
		"infinite ammo is listed as a balance change")
	DevOptions.reset()
	_check(not DevOptions.changes_balance(), "reset puts every option back to its default")

	DevOptions.invincible = true
	var profile := Profile.new()
	var saved: bool = profile.save(PROFILE_PATH)
	_check(not saved and not FileAccess.file_exists(PROFILE_PATH), "a run that changes the balance writes no profile")
	DevOptions.reset()
	_check(profile.save(PROFILE_PATH) and FileAccess.file_exists(PROFILE_PATH), "a run that keeps the defaults saves its profile")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))

	var menu := DevMenu.new()
	menu.run = run
	root.add_child(menu)
	await process_frame  # the panel is built in _ready, on the next frame
	_check(not menu.is_open(), "the dev panel starts closed")
	menu.toggle()
	_check(menu.is_open(), "F2 (toggle) opens the dev panel")
	menu.toggle()
	_check(not menu.is_open(), "toggle again closes it")
	menu.free()
	DevOptions.reset()
	quit(1 if _failures > 0 else 0)
