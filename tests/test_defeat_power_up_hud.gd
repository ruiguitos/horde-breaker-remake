extends SceneTree
## Native defeat navigation, Intel accounting and power-up HUD/ground render.

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _continued: int = 0


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _settle(frames: int = 3) -> void:
	for i in frames:
		await process_frame


func _accept(gamepad: bool = false) -> void:
	for pressed in [true, false]:
		if gamepad:
			var event := InputEventJoypadButton.new()
			event.button_index = JOY_BUTTON_A
			event.pressed = pressed
			Input.parse_input_event(event)
		else:
			var event := InputEventKey.new()
			event.keycode = KEY_ENTER
			event.physical_keycode = KEY_ENTER
			event.pressed = pressed
			Input.parse_input_event(event)
		await _settle()


func _run_tests() -> void:
	var ctx := RunContext.new(7)
	ctx.intel = 40
	ctx.time_alive = 100.0
	ctx.kills = 10
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	island.set("context", ctx)
	root.add_child(island)
	await _settle(5)
	island.set_physics_process(false)
	var run: IslandRun = island.get("run")
	var hud: Hud = island.get("hud")
	island.connect("finished", func(won: bool) -> void:
		_check(not won, "defeat continues as a lost run")
		_continued += 1)
	run.power_ups.ground_kind = &"double_rewards"
	run.power_ups.ground_pos = run.player_pos + Vector3(10, 0, 0)
	run.power_ups.ground_time = 25.0
	await _settle()
	_check(hud._power_up_timers.text == "" and run.power_ups.double_time == 0.0
		and run.power_ups_picked.is_empty() and hud._minimap.drawn_kinds.has(&"power_up"),
		"uncollected drop appears on the minimap without an active buff")
	run.power_ups.tick(25.0)
	await _settle()
	_check(hud._power_up_timers.text == "" and run.power_ups_picked.is_empty()
		and not hud._minimap.drawn_kinds.has(&"power_up") and not hud._messages.text.contains("DOUBLE XP / INTEL!"),
		"lost drop disappears without an active timer or collection toast")
	run.apply_power_up(&"max_shield")
	run.apply_power_up(&"insta_kill")
	run.apply_power_up(&"double_rewards")
	run.power_ups.ground_kind = &"full_power"
	run.power_ups.ground_pos = run.player_pos + Vector3(3, 0, -4)
	run.power_ups.ground_time = 25.0
	await _settle(5)
	_check(hud._shield_bar.value == 100 and hud._shield_text.text.contains("100 / 100"), "field HUD shows shield bar and numbers")
	_check(hud._power_up_timers.text.contains("INSTA-KILL  25s") and hud._power_up_timers.text.contains("XP / INTEL  25s"), "both timed buffs show icons and seconds")
	_check(hud._messages.text.contains("MAX SHIELD!"), "collection toast reaches the HUD")
	_check(hud._messages.get_global_rect().position.y >= hud._power_up_timers.get_global_rect().end.y, "toasts sit below active timers")
	var keys: Array = hud._legend.entries().map(func(e: Array) -> StringName: return e[0])
	_check(hud._minimap.drawn_kinds.has(&"power_up") and keys.has(&"power_up"), "ground pickup has a matching minimap marker and key")
	var icon: Node3D = island.get("_power_up_visual")
	var glyph: Label3D = island.get("_power_up_glyph")
	_check(icon != null and icon.visible and glyph.text == GameData.power_up_icon(&"full_power"), "ground pickup uses a large floating icon")
	run.power_ups.tick(26.0)
	await _settle()
	_check(not icon.visible and hud._power_up_timers.text == "", "expired pickup and buffs disappear visually")
	run.kills = 35
	run.headshots = 12
	run.time_alive = 184.0
	run.hp = 0.0
	run.objective = IslandRun.Objective.LOST
	await _settle()
	_check(hud._death_panel.visible and not hud._field.visible and not hud._cards_panel.visible, "defeat report replaces the field HUD and cards")
	_check(hud._death_continue.has_focus() and hud._death_continue.text.contains("DEBRIEF"), "defeat opens with Continue to Debrief focused")
	_check(hud._death_intel.text == "45" and hud._death_intel_detail.text == "40 PREVIOUS + 5 THIS ISLAND", "defeat reports all retained Intel, including previous islands")
	_check(hud._death_bonus.text.contains("+22 INTEL") and hud._death_time.text == "03:04", "report shows exact lost extraction bonus and whole-run time")
	await _accept()
	hud._death_continue.pressed.emit()
	_check(_continued == 0 and ctx.intel == 40, "keyboard and mouse cannot skip the 0.6-second defeat lock")
	await create_timer(0.65).timeout
	await _accept(true)
	_check(_continued == 1 and ctx.intel == 45 and ctx.island_log.size() == 1, "gamepad A continues to debrief and banks Intel exactly once")
	hud.request_continue()
	hud._death_continue.pressed.emit()
	_check(_continued == 1 and ctx.intel == 45, "repeat activation cannot duplicate banking")
	island.queue_free()
	await _settle()
	await _test_layout_and_mouse()
	quit(1 if _failures > 0 else 0)


func _test_layout_and_mouse() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1152, 648)
	root.add_child(viewport)
	var hud := Hud.new()
	hud.custom_viewport = viewport
	viewport.add_child(hud)
	await _settle()
	var run := IslandRun.new(7)
	run.hp = 0.0
	run.objective = IslandRun.Objective.LOST
	run.survivor_lost = true
	run.kills = 99999
	run.time_alive = 2000
	hud.refresh(run, null, 0.0)
	var accepted: Array[bool] = []
	hud.continue_requested.connect(func() -> void: accepted.append(true))
	for extent in [Vector2i(960, 540), Vector2i(1152, 648), Vector2i(1920, 1080)]:
		viewport.size = extent
		await _settle()
		hud.refresh(run, null, 0.0)
		await _settle()
		var frame := Rect2(Vector2.ZERO, Vector2(extent))
		var fits: bool = true
		for control in [hud._death_where, hud._death_reason, hud._death_kills, hud._death_heads, hud._death_time,
				hud._death_intel, hud._death_intel_detail, hud._death_bonus, hud._death_continue, hud._death_hints]:
			fits = fits and frame.encloses(control.get_global_rect())
			if not frame.encloses(control.get_global_rect()):
				print("LAYOUT: %s %s" % [control.name, control.get_global_rect()])
		_check(fits, "defeat content stays on screen at %dx%d" % [extent.x, extent.y])
	_check(hud._death_reason.text.begins_with("Survivor lost") and hud._death_continue.text.contains("FIELD TEST"), "rescue failure and standalone restart use appropriate text")
	await create_timer(0.65).timeout
	hud._death_continue.pressed.emit()
	_check(accepted.size() == 1, "native mouse button continues after the lock")
	hud.queue_free()
	viewport.queue_free()
	await _settle()
