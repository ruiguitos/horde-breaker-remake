extends SceneTree
## Capture the actual in-game HUD without loading or writing a saved profile.
## --script res://tools/dev/hud_preview.gd -- <PNG path> [normal|danger|boss|third_person]

var _island: Node3D
var _frames: int = 0
var _out: String
var _state: String = "normal"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		quit(1)
		return
	_out = args[0]
	if args.size() > 1:
		_state = args[1]
	_island = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	var profile := Profile.new()
	profile.third_person = _state == "third_person"
	_island.set("profile", profile)
	var context := RunContext.new(7)
	context.biome = &"town"
	context.mission = &"rescue"
	_island.set("context", context)
	root.add_child(_island)
	_island.set_physics_process(false)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 2:
		var run: IslandRun = _island.get("run")
		run.objective = IslandRun.Objective.RETURN_TO_BOAT
		run.survivor_found = true
		run.player_pos = Vector3(run.field.width * 0.5, 0, run.field.height * 0.5)
		run.survivor_pos = run.player_pos + Vector3(2, 0, 1)
		run.kills = 36
		run.headshots = 8
		run.xp = 7
		run.radio.clear()
		run.radio.append(&"survivor_found")
		if _state == "danger":
			run.hp = 23
			run.breaker_cd = 4.2
			run.grenade_cd = 9.5
			run.stamina = 1.2
			run.horde.grabbed_by = 0
			run.scream_progress = 1.5
			run.survivor_hp = 62
		elif _state == "boss":
			run.objective = IslandRun.Objective.BOSS
			run.player_class = &"vanguard"
			run.boss_enraged = true
			run.boss_max_hp = 1000
			run.horde.add(run.player_pos + Vector3(0, 0, -9), GameData.EnemyKind.BOSS, run.rng)
			run.horde.hp[run.boss_index()] = 450
			run.mission = &"activate"
			run.weapon_index = 1
			run.ammo[1] = 17
		for i in 22:
			var enemy_pos := run.player_pos + Vector3(-7 + i % 7 * 2.1, 0, -8 - i / 7 * 2)
			var cell: Vector2i = run.field.world_to_cell(enemy_pos)
			if not run.field.is_blocked(cell.x, cell.y):
				run.horde.add(enemy_pos, GameData.EnemyKind.WALKER, run.rng)
	if _frames == 12:
		var run: IslandRun = _island.get("run")
		run.radio.clear()
		var hud: Hud = _island.get("hud")
		hud._radio_queue.clear()
		hud._radio_time = 0.0
		run.radio.append(&"survivor_found")
	if _frames >= 18:
		var hud: Hud = _island.get("hud")
		hud._radio_text.visible_ratio = 1.0
		# Wait for the next draw, so the screenshot includes complete subtitles.
		if _frames == 18:
			return false
		var screenshot := root.get_texture().get_image()
		var error: Error = screenshot.save_png(_out)
		print("HUD PREVIEW: %s %dx%d / save %d" % [_state, screenshot.get_width(), screenshot.get_height(), error])
		_frames = -10000
		call_deferred("_finish", 0 if error == OK else 1)
	return false


func _finish(code: int) -> void:
	_island.queue_free()
	await process_frame
	await process_frame
	quit(code)
