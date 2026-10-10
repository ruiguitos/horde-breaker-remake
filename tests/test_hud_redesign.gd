extends SceneTree
## October 2026 HUD redesign: field HUD without panels, minimap key, level-up
## cards (focus + confirm, 0.4 s lock, rerolls), pause with the build and
## Intel, and the hold-to-abandon confirmation.

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _island: Node
var _run: IslandRun
var _hud: Hud


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _key(code: Key, pressed: bool = true) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)


func _tap(code: Key) -> void:
	_key(code, true)
	await _settle()
	_key(code, false)
	await _settle()


func _pad(button: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		Input.parse_input_event(event)
		await _settle()


func _accept(pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = pressed
	Input.parse_input_event(event)
	await _settle()


func _run_tests() -> void:
	_test_reroll_rules()
	_test_hazard_split()
	_island = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	_island.set("profile", MemoryProfile.new())
	root.add_child(_island)
	await _settle(3)
	_run = _island.get("run")
	_hud = _island.get("hud")
	_run.noclip = true  # no damage while the test waits
	_run.director.max_alive = 0
	await _test_field()
	await _test_cards()
	await _test_offers()
	await _test_pause()
	await _test_abandon()
	_island.queue_free()
	await _settle()
	await create_timer(0.1).timeout
	quit(1 if _failures > 0 else 0)


func _test_field() -> void:
	await _tap(KEY_Q)
	_check(not _run.is_over() and not _island.get("paused"), "Q does nothing while playing")
	var field: Control = _hud.get("_field")
	var panels: int = 0
	var dark_rects: int = 0
	for node in field.find_children("*", "", true, false):
		if node is PanelContainer or node is Panel:
			panels += 1
		if node is ColorRect and (node as ColorRect).color.a > 0.05:
			dark_rects += 1
	_check(panels == 0 and dark_rects == 0, "field HUD has no panel backgrounds (%d panels, %d rects)" % [panels, dark_rects])
	_check(is_equal_approx(field.scale.x, 1.0), "HUD defaults to 100%% size (scale %.2f)" % field.scale.x)
	var hp: Label = _hud.get("_hp_text")
	var radio: Label = _hud.get("_radio_text")
	_check(hp.get_theme_font_size("font_size") >= 22 and radio.get_theme_font_size("font_size") >= 16, "HP number 22 px, body text at least 16 px")
	var breaker_key: Label = _hud.get("_breaker_key")
	_check(breaker_key.text == GameInput.prompt(&"breaker", false) and breaker_key.text == "SPACE", "ability key comes from the real binding (%s)" % breaker_key.text)
	# Minimap key: every marker kind drawn has a legend entry with the same drawing.
	var minimap: Minimap = _hud.get("_minimap")
	var legend: Minimap.Legend = _hud.get("_legend")
	await _settle(3)
	var keys: Array[StringName] = []
	for e: Array in legend.entries():
		keys.append(e[0])
	var missing: Array = minimap.drawn_kinds.keys().filter(func(k: StringName) -> bool: return not keys.has(k))
	_check(not minimap.drawn_kinds.is_empty() and missing.is_empty(), "minimap legend covers every drawn marker (drawn %s, legend %s)" % [minimap.drawn_kinds.keys(), keys])
	_check(keys.has(&"generator") and keys.has(&"player") and not keys.has(&"site"), "activate legend: generators and you, no defend site")
	var defend := IslandRun.new(7)
	defend.set_mission(&"defend")
	var defend_keys: Array = Minimap.legend_entries(defend).map(func(e: Array) -> StringName: return e[0])
	_check(defend_keys.has(&"site") and not defend_keys.has(&"generator"), "defend legend: the uplink, no generators")


func _test_cards() -> void:
	var chosen: Array[int] = []
	_hud.card_chosen.connect(func(i: int) -> void: chosen.append(i))
	_run.set("_pending_levels", 1)
	_run.call("_roll_cards_if_needed")
	await _settle()
	var cards: Array = _hud.get("_cards")
	var panel: Control = _hud.get("_cards_panel")
	_check(panel.visible and (cards[1].button as Button).has_focus(), "cards open with the middle card focused")
	var title: Label = cards[0].title
	var category: Label = cards[0].category
	var rank: Label = cards[0].rank
	_check(title.text == _run.card_choices[0].title and category.text.contains(String(GameData.card_category(_run.card_choices[0].id)).replace("_", " ").to_upper()) and rank.text == "1 / %d" % _run.card_choices[0].max_stacks,
		"card shows category, name and rank")
	await _accept(true)
	await _accept(false)
	_check(chosen.is_empty() and not _run.card_choices.is_empty(), "A/Enter is ignored for 0.4 s after the cards open")
	await _wait(0.45)
	for code: Key in [KEY_1, KEY_2, KEY_3]:
		await _tap(code)
	await _pad(JOY_BUTTON_X)
	await _pad(JOY_BUTTON_B)
	_check(chosen.is_empty() and not _run.card_choices.is_empty() and _run.cards_picked.is_empty(), "1/2/3 and X/B no longer pick a card")
	# Reroll: R / Y redraws the offer and spends one of the run's rerolls.
	var before: String = ",".join(_run.card_choices.map(func(c: GameData.Card) -> String: return String(c.id)))
	await _tap(KEY_R)
	var after: String = ",".join(_run.card_choices.map(func(c: GameData.Card) -> String: return String(c.id)))
	_check(_run.rerolls == GameData.REROLLS_START - 1 and after != before, "REROLL spends one and redraws (%s -> %s)" % [before, after])
	await _tap(KEY_R)
	_check(_run.rerolls == GameData.REROLLS_START - 1, "a reroll right after another waits for the 0.4 s lock")
	await _wait(0.45)
	await _pad(JOY_BUTTON_Y)
	_check(_run.rerolls == 0, "gamepad Y rerolls too")
	await _wait(0.45)
	var last: String = ",".join(_run.card_choices.map(func(c: GameData.Card) -> String: return String(c.id)))
	await _tap(KEY_R)
	var reroll: Button = _hud.get("_reroll_button")
	var reason: Label = _hud.get("_reroll_reason")
	_check(_run.rerolls == 0 and ",".join(_run.card_choices.map(func(c: GameData.Card) -> String: return String(c.id))) == last and reroll.disabled and reason.visible and reason.text != "",
		"no reroll left: disabled with a reason")
	(cards[0].button as Button).grab_focus()
	await _settle()
	var id: StringName = _run.card_choices[0].id
	await _accept(true)
	await _accept(false)
	_check(chosen == [0] and _run.stacks(id) == 1 and _run.card_choices.is_empty() and not panel.visible, "focus + A/Enter takes the focused card")


## New offers lock and refresh even with the same cards; the pause blocks them.
func _test_offers() -> void:
	var saved: Dictionary = _run.card_stacks.duplicate()
	# Only Fast Hands (5 ranks) can be drawn: every offer is the same card.
	for c in _run.all_cards:
		if c.id != &"fast_hands":
			_run.card_stacks[c.id] = c.max_stacks
	_run.card_stacks[&"fast_hands"] = 0
	_run.set("_pending_levels", 2)
	_run.call("_roll_cards_if_needed")
	await _settle()
	var cards: Array = _hud.get("_cards")
	_check((cards[0].rank as Label).text == "1 / 5", "single-card offer shows rank 1 / 5")
	await _wait(0.45)
	var offer: int = _run.card_offer
	(cards[0].button as Button).grab_focus()
	await _accept(true)
	await _accept(false)
	_check(_run.stacks(&"fast_hands") == 1 and _run.card_offer == offer + 1 and (cards[0].rank as Label).text == "2 / 5",
		"the next pending offer of the same card refreshes its rank (%s)" % (cards[0].rank as Label).text)
	_check(_hud.call("_cards_locked"), "the next pending offer starts a new 0.4 s lock")
	await _wait(0.45)
	_run.rerolls = 1
	await _tap(KEY_R)
	_check(_run.rerolls == 0 and _run.card_choices[0].id == &"fast_hands" and _run.card_offer == offer + 2 and _hud.call("_cards_locked"),
		"a reroll that draws the same card still counts as a new offer and locks")
	# Pause over the offer: the cards drop out of focus and ignore presses.
	await _wait(0.45)
	_island.set("paused", true)
	await _settle()
	var resume: Button = _hud.get("_resume_button")
	var abandon: Button = _hud.get("_abandon_button")
	var card_button: Button = cards[0].button
	_check(card_button.focus_mode == Control.FOCUS_NONE and card_button.mouse_filter == Control.MOUSE_FILTER_IGNORE, "cards take no focus or clicks behind the pause")
	_check(resume.find_prev_valid_focus() == abandon and abandon.find_next_valid_focus() == resume, "Shift+Tab / Tab stay inside the pause menu")
	_hud.call("_take_card", 0)
	_hud.call("_request_reroll")
	_check(not _run.card_choices.is_empty() and _run.stacks(&"fast_hands") == 1, "no card can be taken behind the pause")
	_island.set("paused", false)
	await _settle()
	_check(card_button.focus_mode == Control.FOCUS_ALL, "cards take focus again after the pause")
	_run.card_choices.clear()
	_run.set("_pending_levels", 0)
	_run.card_stacks = saved
	await _settle()


## Debrief hazard pay split from the values recorded at scoring time:
## base 7 Intel with hazard pay pays 8 = 7 + 1 (not 6 + 2).
func _test_hazard_split() -> void:
	var run := IslandRun.new(7)
	run.hazard_pay = true
	run.kills = 35  # 35 kills / 5 = base 7
	var ctx := RunContext.new(3)
	run.save_to_context(ctx)
	var entry: Dictionary = ctx.island_log[-1]
	_check(int(entry["intel"]) == 8 and int(entry["intel_hazard"]) == 1, "island log records Intel 8 with a hazard share of 1 (%s / %s)" % [entry["intel"], entry.get("intel_hazard")])
	entry["hazard_pay"] = true
	var debrief := Control.new()
	debrief.set_script(load("res://game/states/debrief.gd"))
	debrief.set("context", ctx)
	debrief.set("profile", MemoryProfile.new())
	var b: Dictionary = debrief.call("intel_breakdown")
	_check(int(b["islands"]) == 7 and int(b["hazard"]) == 1, "debrief splits 8 Intel as 7 + 1 hazard pay (%d + %d)" % [b["islands"], b["hazard"]])
	entry.erase("intel_hazard")
	b = debrief.call("intel_breakdown")
	_check(int(b["islands"]) + int(b["hazard"]) == 8, "old logs without the recorded share still add up")
	debrief.free()


func _test_reroll_rules() -> void:
	var ctx := RunContext.new(11)
	var run := IslandRun.new(7)
	run.load_context(ctx)
	_check(run.rerolls == GameData.REROLLS_START, "a run starts with %d rerolls" % GameData.REROLLS_START)
	run.rerolls = 1
	run.objective = IslandRun.Objective.WON
	run.save_to_context(ctx)
	var next := IslandRun.new(8)
	next.load_context(ctx)
	_check(next.rerolls == 1 + GameData.REROLLS_PER_ISLAND, "rerolls carry to the next island, +1 for clearing one")
	next.rerolls = GameData.REROLLS_MAX
	next.objective = IslandRun.Objective.WON
	next.save_to_context(ctx)
	_check(IslandRun.context_rerolls(ctx) == GameData.REROLLS_MAX, "banked rerolls never exceed %d" % GameData.REROLLS_MAX)
	ctx.island_index = ctx.island_count() - 1
	var final := IslandRun.new(9)
	final.load_context(ctx)
	final.rerolls = 0
	final.objective = IslandRun.Objective.WON
	final.save_to_context(ctx)
	_check(IslandRun.context_rerolls(ctx) == 0, "clearing the last island earns no reroll")
	run.card_choices.clear()
	_check(not run.reroll_cards(), "no offer: reroll does nothing")


func _test_pause() -> void:
	var ctx := RunContext.new(5)
	ctx.intel = 40
	_hud.context = ctx
	_run.card_stacks[&"ricochet"] = 1
	_island.set("paused", true)
	await _settle()
	var pause: Control = _hud.get("_pause_panel")
	var resume: Button = _hud.get("_resume_button")
	_check(pause.visible and resume.has_focus(), "pause opens with RESUME focused")
	var rows: GridContainer = _hud.get("_pause_cards")
	var weapons: HFlowContainer = _hud.get("_pause_weapons")
	var owned_cards: int = _run.card_stacks.values().filter(func(n: int) -> bool: return n > 0).size()
	var owned_weapons: int = _run.weapon_unlocked.count(true)
	_check(rows.get_child_count() == owned_cards and weapons.get_child_count() == owned_weapons, "pause lists the build: %d cards, %d weapons" % [owned_cards, owned_weapons])
	var kept: int = 40 + _run.intel_earned()
	var bonus: int = int(kept * GameData.EXTRACTION_INTEL_MULTIPLIER) - kept
	_check((_hud.get("_pause_banked") as Label).text == "40" and (_hud.get("_pause_island") as Label).text == "+%d" % _run.intel_earned() and (_hud.get("_pause_bonus") as Label).text == "+%d" % bonus,
		"pause shows Intel banked, this island and the extraction bonus at risk")
	var opaque: int = 0
	for node in pause.find_children("*", "PanelContainer", true, false):
		var box := (node as PanelContainer).get_theme_stylebox("panel") as StyleBoxFlat
		if box != null and box.bg_color.a > 0.7:
			opaque += 1
	_check(opaque == 0, "pause has no dark panel: boxes are translucent")


func _test_abandon() -> void:
	var abandon: Button = _hud.get("_abandon_button")
	abandon.grab_focus()
	abandon.pressed.emit()
	await _settle()
	var dialog: MenuDialog = _hud.get("_pause_dialog")
	var content: Control = _hud.get("_pause_content")
	_check(is_instance_valid(dialog) and dialog.name == "AbandonDialog" and not content.visible, "ABANDON RUN… opens the confirmation alone")
	var stay: Button = dialog.find_child("KeepFighting", true, false)
	_check(stay != null and stay.has_focus(), "KEEP FIGHTING is focused by default")
	var keep: Label = dialog.find_child("Keep", true, false)
	_check(keep != null and keep.text == "%d INTEL" % (40 + _run.intel_earned()), "YOU KEEP shows the real Intel")
	await _tap(KEY_Q)
	_check(not _run.is_over() and _island.get("paused"), "Q does not abandon")
	await _pad(JOY_BUTTON_B)
	_check(not is_instance_valid(_hud.get("_pause_dialog")) or (_hud.get("_pause_dialog") as Node).is_queued_for_deletion(), "B closes the confirmation")
	await _settle()
	_check(content.visible and _island.get("paused") and abandon.has_focus(), "B goes back to the pause menu, focus on ABANDON RUN…")
	abandon.pressed.emit()
	await _settle()
	dialog = _hud.get("_pause_dialog")
	var hold: Button = dialog.find_child("HoldToAbandon", true, false)
	hold.grab_focus()
	await _accept(true)
	await _wait(0.7)
	await _accept(false)
	await _wait(0.05)
	await _accept(true)
	await _wait(0.5)
	_check(not _run.is_over(), "0.7 s + release + 0.5 s is not a 1 s hold: no abandon")
	await _wait(0.6)
	await _accept(false)
	_check(_run.is_over() and _run.objective == IslandRun.Objective.LOST and not _island.get("paused"), "holding A/Enter for 1 s abandons the run")
