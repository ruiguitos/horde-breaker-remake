extends SceneTree
## Telemetry (docs/tech/GAME_AUDIT.md, T06): the island log counts the shots fired
## with each weapon and the XP earned, so playtests can compare runs.
## Run: godot --headless --path . --script res://tests/test_island_shots.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var ctx := RunContext.new(41)
	ctx.biome = &"beach"
	ctx.mission = &"activate"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	run.director.max_alive = 0
	var first: GameData.Weapon = run.weapons[0]
	run.dev_spawn(0)
	_check(run.shots_by_weapon.is_empty(), "a new island has fired nothing")
	run._fire(first, 0)
	run._fire(first, 0)
	_check(int(run.shots_by_weapon.get(first.id, 0)) == 2, "two shots with %s are counted as two" % first.id)
	run.orbs.append(run.player_pos)
	run.orb_values.append(12)
	run._collect_xp_orb(run.orbs.size() - 1)  # the orb just added: a new island may already have orbs
	_check(run.xp_earned == 12, "an XP orb adds its value to the XP earned on the island")
	var out := RunContext.new(41)
	run.save_to_context(out)
	var entry: Dictionary = out.island_log[-1]
	var logged: Dictionary = entry.get("shots", {})
	_check(int(logged.get(String(first.id), 0)) == 2, "the island log holds the shots by weapon name")
	_check(int(entry.get("xp_earned", -1)) == 12, "the island log holds the XP earned")
	var keys: Array = logged.keys()
	_check(keys.size() == 1 and typeof(keys[0]) == TYPE_STRING, "the log keys are plain strings, as the JSON file needs")
	quit(1 if _failures > 0 else 0)
