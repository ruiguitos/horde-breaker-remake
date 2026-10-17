extends SceneTree
## Aim down sights (first person): right mouse aims, the breaker has left
## the right mouse button, aiming tightens the spread, the gun moves to the
## centre of the view. Run: godot --headless --path . --script res://tests/test_aim.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	var aim_mouse: bool = InputMap.action_get_events(&"aim").any(func(e: InputEvent) -> bool:
		return e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT)
	_check(aim_mouse, "aim is on the right mouse button")
	var breaker_mouse: bool = InputMap.action_get_events(&"breaker").any(func(e: InputEvent) -> bool:
		return e is InputEventMouseButton)
	_check(not breaker_mouse and InputMap.action_get_events(&"breaker").size() > 0, "the breaker no longer uses the mouse")
	var ctx := RunContext.new(7)
	ctx.biome = &"beach"
	ctx.mission = &"activate"
	var run := IslandRun.new(ctx.island_seed(), ctx.biome)
	run.load_context(ctx)
	var w: GameData.Weapon = run.weapons[run.weapon_index]
	run.aiming = false
	var hip: float = run.weapon_spread(w)
	run.aiming = true
	var ads: float = run.weapon_spread(w)
	_check(hip > 0.0 and is_equal_approx(ads, hip * IslandRun.ADS_SPREAD_MULT), "aiming down sights gives %.2f of the hip spread (%.2f vs %.2f)" % [IslandRun.ADS_SPREAD_MULT, ads, hip])
	var vm := ViewModel.create(&"recruit")
	vm.aim = 0.0
	vm.update(0.016, 0.0, 0.0, 0.0)
	var at_hip: Vector3 = vm.position
	vm.aim = 1.0
	vm.update(0.016, 0.0, 0.0, 0.0)
	var at_sight: Vector3 = vm.position
	_check(at_sight.x < at_hip.x and absf(at_sight.x) < 0.05, "the gun moves to the centre of the view (x %.2f -> %.2f)" % [at_hip.x, at_sight.x])
	vm.free()
	quit(1 if _failures > 0 else 0)