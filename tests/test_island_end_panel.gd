extends SceneTree
## End-of-island report (IslandEndPanel) and the shoulder camera on slopes.
##   - this island's numbers vs the labelled run totals, cards and power-ups;
##   - the header (ISLAND / PART CLEARED, EXTRACTED) and the NEXT line;
##   - presses ignored for the first 0.6 s, then Enter, pad A and the mouse
##     continue, once;
##   - on the steepest walkable slope of a Berlenga part, the camera (and the
##     crosshair ray's origin) never goes under the ground, whatever the view.
## Run: godot --headless --path . --script res://tests/test_island_end_panel.gd

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _finished: Array[bool] = []
var _done: bool = false


func _initialize() -> void:
	GameInput.setup()
	create_timer(150.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "end panel tests finished in time")
			_quit())
	call_deferred("_run_tests")


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _quit() -> void:
	_done = true
	if _failures > 0:
		print("TEST FAIL: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _settle(frames: int = 3) -> void:
	for i in frames:
		await process_frame


func _press(gamepad: bool, button: JoyButton = JOY_BUTTON_A) -> void:
	for pressed in [true, false]:
		if gamepad:
			var pad := InputEventJoypadButton.new()
			pad.button_index = button
			pad.pressed = pressed
			Input.parse_input_event(pad)
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER
			key.physical_keycode = KEY_ENTER
			key.pressed = pressed
			Input.parse_input_event(key)
		await _settle()


func _run_tests() -> void:
	_test_texts()
	await _test_island_report()
	await _test_pad_and_mouse()
	await _test_camera_on_slope()
	_quit()


## Header and NEXT line for every kind of island, without a scene.
func _test_texts() -> void:
	_check(IslandEndPanel.next_text(null) == "RESTART FIELD TEST", "lone island (F6): NEXT restarts the field test")
	var arch := RunContext.new(5)
	_check(IslandEndPanel.next_text(arch).begins_with("BOAT") and IslandEndPanel.next_text(arch).contains("NEXT ISLAND 2 OF 3 IN 5 S"),
		"archipelago island 1: NEXT is the boat's countdown to island 2 of 3 (%s)" % IslandEndPanel.next_text(arch))
	arch.island_index = 2
	_check(IslandEndPanel.next_text(arch).begins_with("DEBRIEF"), "archipelago last island: NEXT is the debrief")
	var part_ctx := RunContext.new(5)
	part_ctx.start_expedition(&"berlenga", 0)
	var second: String = String(Expeditions.parts(&"berlenga")[1]["name"]).to_upper()
	_check(IslandEndPanel.next_text(part_ctx) == "CAMP, THEN " + second, "expedition part 1: NEXT names the camp and the next part (%s)" % IslandEndPanel.next_text(part_ctx))
	var run := IslandRun.new(5)
	run.load_context(part_ctx)
	_check(IslandEndPanel.summary(run, part_ctx)["title"] == "PART CLEARED", "expedition part: PART CLEARED")
	var last := RunContext.new(5)
	last.start_expedition(&"berlenga", Expeditions.parts(&"berlenga").size() - 1)
	var final_run := IslandRun.new(5)
	final_run.load_context(last)
	_check(IslandEndPanel.summary(final_run, last)["title"] == "EXTRACTED" and IslandEndPanel.next_text(last).begins_with("DEBRIEF"),
		"expedition final: EXTRACTED, NEXT is the debrief")
	var lone := IslandRun.new(5)
	var s: Dictionary = IslandEndPanel.summary(lone, null)
	_check(s["title"] == "ISLAND CLEARED" and s["run_totals"] == "", "lone island: ISLAND CLEARED and no run totals")


## A won archipelago island in the real scene: numbers, focus, lock, Enter.
func _test_island_report() -> void:
	var ctx := RunContext.new(7)
	ctx.kills = 7700
	ctx.headshots = 1200
	ctx.level = 5
	ctx.intel = 300
	ctx.time_alive = 600.0
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	island.set("context", ctx)
	root.add_child(island)
	await _settle(5)
	island.set_physics_process(false)
	island.connect("finished", func(won: bool) -> void: _finished.append(won))
	var run: IslandRun = island.get("run")
	var hud: Hud = island.get("hud")
	var panel: IslandEndPanel = hud._end_panel
	run.kills = 7700 + 31
	run.headshots = 1200 + 9
	run.level = 7
	var card: GameData.Card = run.all_cards[0]
	run.card_stacks[card.id] = 1
	run.cards_picked.append(card.id)
	run.power_ups_picked.append_array([&"nuke", &"nuke"])
	run.time_alive = 600.0 + 125.0
	_check(not panel.visible, "no report while the island is being played")
	run.objective = IslandRun.Objective.WON
	await _settle()
	_check(panel.visible and not hud._field.visible, "winning shows the report instead of the field HUD")
	_check(panel.title.text == "ISLAND CLEARED" and panel.where.text.begins_with("ISLAND 1 OF 3") and panel.where.text.contains("02:05 ON THE ISLAND"),
		"header: ISLAND CLEARED, island 1 of 3 and the time on this island (%s)" % panel.where.text)
	_check(panel.kills.text == "31" and panel.headshots.text == "9" and panel.level.text == "7" and panel.level_gain.text == "+2",
		"THIS ISLAND: 31 kills, 9 headshots, level 7 (+2), not the run's numbers")
	_check(panel.intel.text == "+%d" % run.intel_earned(), "THIS ISLAND: Intel earned here (%s)" % panel.intel.text)
	_check(panel.run_totals.text.begins_with("RUN TOTAL") and panel.run_totals.text.contains("KILLS 7731")
		and panel.run_totals.text.contains("INTEL BANKED %d" % (300 + run.intel_earned())),
		"run totals are labelled RUN TOTAL (%s)" % panel.run_totals.text)
	_check(panel.cards.text.contains(card.title) and panel.power_ups.text.contains("NUKE ×2"), "cards and power-ups taken on this island")
	_check(panel.next_step.text.contains("NEXT ISLAND 2 OF 3 IN 5 S"), "NEXT: the boat's countdown to the next island")
	_check(panel.continue_button.has_focus(), "CONTINUE has the focus")
	_check(panel.hint.text == "[ %s ] CONTINUE" % GameInput.prompt(&"ui_accept", false), "hint uses the real binding (%s)" % panel.hint.text)
	var frame := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var content: Control = panel.get_node("CenterContainer/Content") if panel.has_node("CenterContainer/Content") else panel.find_child("Content", true, false)
	_check(content != null and frame.encloses(content.get_global_rect()), "report fits the %dx%d screen" % [int(frame.size.x), int(frame.size.y)])
	# Locked: a mashed Breaker (pad A), Enter, R and a click do nothing.
	await _press(true)
	await _press(false)
	panel.continue_button.pressed.emit()
	hud.request_continue()
	_check(_finished.is_empty() and ctx.island_log.is_empty(), "the first 0.6 s ignore pad A, Enter, the mouse and CONTINUE calls")
	await create_timer(0.65).timeout
	await _press(false)
	_check(_finished == [true] and ctx.island_log.size() == 1, "after 0.6 s Enter continues (won), once")
	await _press(false)
	panel.continue_button.pressed.emit()
	_check(_finished.size() == 1 and ctx.island_log.size() == 1, "further presses do not continue twice")
	island.queue_free()
	await _settle()


## A bare HUD: the pad's A and the mouse (button press) continue too.
func _test_pad_and_mouse() -> void:
	for via_pad in [true, false]:
		var hud := Hud.new()
		root.add_child(hud)
		await _settle()
		var run := IslandRun.new(9)
		var count: Array[int] = [0]
		hud.continue_requested.connect(func() -> void: count[0] += 1)
		run.objective = IslandRun.Objective.WON
		hud.refresh(run, null, 0.0)
		await _settle()
		var panel: IslandEndPanel = hud._end_panel
		_check(panel.visible and panel.next_step.text.contains("RESTART FIELD TEST"), "lone island report opens")
		await create_timer(0.65).timeout
		if via_pad:
			await _press(true)
			_check(count[0] == 1, "after 0.6 s the pad's A continues")
		else:
			panel.continue_button.pressed.emit()
			_check(count[0] == 1, "after 0.6 s clicking CONTINUE continues")
		hud.queue_free()
		await _settle()


## Steepest walkable cell near the start of a Berlenga part (cliffs and
## ramps): every yaw and pitch keeps the camera over the ground.
func _test_camera_on_slope() -> void:
	var ctx := RunContext.new(31)
	ctx.start_expedition(&"berlenga", 0)
	var profile := MemoryProfile.new()
	profile.camera_mode = Profile.CameraMode.THIRD_PERSON
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	island.set("context", ctx)
	island.set("handmade_scene", load(ctx.part_scene()))
	root.add_child(island)
	await _settle(5)
	island.set_physics_process(false)
	var run: IslandRun = island.get("run")
	run.noclip = true
	run.director.max_alive = 0
	var spot := Vector3.ZERO
	var best: float = 0.0
	var p0: Vector3 = run.player_pos
	for dz in range(-60, 61):
		for dx in range(-60, 61):
			var x: int = int(p0.x) + dx
			var z: int = int(p0.z) + dz
			if run.field.is_blocked(x, z) or run.field.is_blocked(x + 2, z) or run.field.is_blocked(x - 2, z) or run.field.is_blocked(x, z + 2) or run.field.is_blocked(x, z - 2):
				continue
			var c := Vector3(x + 0.5, 0, z + 0.5)
			var grade: float = Vector2(run.map.ground_y(c + Vector3(2, 0, 0)) - run.map.ground_y(c - Vector3(2, 0, 0)),
				run.map.ground_y(c + Vector3(0, 0, 2)) - run.map.ground_y(c - Vector3(0, 0, 2))).length() / 4.0
			if grade > best:
				best = grade
				spot = c
	_check(best > 0.5, "found a steep walkable slope (grade %.2f)" % best)
	run.player_pos = spot
	var worst: float = INF
	for k in 96:
		island.set("_tp_yaw", (k % 24) * TAU / 24.0 + 0.01)
		island.set("_tp_pitch", deg_to_rad([-10.0, 0.0, 15.0, 45.0][k / 24]))
		var cam: Vector3 = island.call("crosshair_ray")[0]
		worst = minf(worst, cam.y - float(island.call("ground_height", cam)))
		worst = minf(worst, cam.y - run.map.ground_y(cam))
	_check(worst >= 0.45, "on the slope the shoulder camera stays over the ground at every angle (lowest %.2f m)" % worst)
	# The camera the player sees is the one the crosshair ray starts from.
	island.set("_tp_yaw", PI * 0.75)
	island.set("_tp_pitch", deg_to_rad(-10.0))
	await _settle(4)
	var shown: Vector3 = (island.get("_camera") as Camera3D).global_position
	var ray: Array = island.call("crosshair_ray")
	_check(shown.distance_to(ray[0]) < 0.05 and shown.y >= float(island.call("ground_height", shown)),
		"shown camera = crosshair origin, above the ground (gap %.3f m)" % shown.distance_to(ray[0]))
	island.queue_free()
	await _settle()
