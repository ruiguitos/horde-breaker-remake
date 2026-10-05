extends SceneTree
## Debug noclip (Mouse 4/5): crosses blocked cells and takes no damage.
## Run: godot --headless --path . --script res://tests/test_noclip.gd

func _initialize() -> void:
	var fails: int = 0
	GameInput.setup()
	var run := IslandRun.new(7, &"town")
	run.director.max_alive = 0
	# Walk straight at a building: blocked without noclip, through with it.
	var b: Rect2i = run.map.buildings[0]
	var start := Vector3(b.position.x - 2.0, 0, b.position.y + b.size.y * 0.5)
	run.player_pos = start
	for i in 120:
		run.step(1.0 / 60.0, Vector2(1, 0), Vector3(1, 0, 0), false)
	var blocked_x: float = run.player_pos.x
	run.noclip = true
	run.player_pos = start
	for i in 120:
		run.step(1.0 / 60.0, Vector2(1, 0), Vector3(1, 0, 0), false)
	var ok1: bool = blocked_x < b.position.x and run.player_pos.x > b.end.x
	print(("TEST: " if ok1 else "TEST FAIL: ") + "noclip walks through a building (%.1f vs %.1f)" % [blocked_x, run.player_pos.x])
	fails += 0 if ok1 else 1
	run.hp = 50.0
	run.horde.damage_to_player = 30.0
	run.step(1.0 / 60.0, Vector2.ZERO, Vector3(1, 0, 0), false)
	var ok2: bool = run.hp >= 50.0
	print(("TEST: " if ok2 else "TEST FAIL: ") + "noclip takes no damage")
	fails += 0 if ok2 else 1
	var ok3: bool = InputMap.has_action(&"noclip") and InputMap.action_get_events(&"noclip").any(func(e: InputEvent) -> bool: return e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_XBUTTON1)
	print(("TEST: " if ok3 else "TEST FAIL: ") + "noclip is bound to Mouse 4/5")
	fails += 0 if ok3 else 1
	quit(1 if fails > 0 else 0)
