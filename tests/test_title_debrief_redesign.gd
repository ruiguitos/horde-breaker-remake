extends SceneTree
## Title and debrief redesign (docs/design/MENUS.md, October 2026): QUICK
## REDEPLOY remembered, saved, loaded, replayed and its fallback to the
## Armory; the debrief's 0.6 s input lock, per-island cards and Intel
## numbers; the title fits the 1152x648 base size.
## Run: godot --headless --path . --script res://tests/test_title_debrief_redesign.gd

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

const SAVE_PATH: String = "user://test_title_debrief_profile.json"

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("TEST FAIL: " + message)


func _settle(frames: int = 3) -> void:
	for i in frames:
		await process_frame


func _run_tests() -> void:
	_profile_tests()
	await _main_tests()
	await _debrief_tests(true)
	await _debrief_tests(false)
	await _title_layout_tests()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _failures == 0:
		print("TEST: title/debrief redesign OK (%d checks)" % _checks)
	quit(1 if _failures > 0 else 0)


func _veteran() -> Profile:
	var p := MemoryProfile.new()
	p.intel = 400
	p.unlocked_classes = [&"recruit", &"vanguard"]
	p.selected_class = &"vanguard"
	p.perk_ranks = {&"survival_1": 3}
	p.equipped_perks = [&"thick_skin"]
	p.max_threat = 2
	p.threat = 2
	return p


# --- QUICK REDEPLOY in the profile ------------------------------------------

func _profile_tests() -> void:
	var p := _veteran()
	_check(p.redeploy_problem() == "No previous run yet", "no QUICK REDEPLOY before the first run")
	_check(not p.apply_last_run(), "nothing to apply without a last run")
	p.remember_run(&"")
	_check(p.redeploy_problem() == "", "the remembered run can be replayed")
	_check(p.last_run_summary().begins_with("Vanguard · Archipelago"), "summary names class and run ('%s')" % p.last_run_summary())
	# Saved and loaded (Profile.save of the base class, to a test file).
	var real := Profile.from_dict({})
	real.unlocked_classes = p.unlocked_classes.duplicate()
	real.selected_class = p.selected_class
	real.perk_ranks = p.perk_ranks.duplicate()
	real.equipped_perks = p.equipped_perks.duplicate()
	real.max_threat = 2
	real.threat = 2
	real.lore_pages = 3
	real.lore_read = 1
	real.remember_run(&"")
	_check(real.save(SAVE_PATH), "the profile saves")
	var loaded := Profile.load_profile(SAVE_PATH)
	_check(loaded.last_run.get("class") == "vanguard" and loaded.last_run.get("threat") == 2
		and loaded.last_run.get("perks") == ["thick_skin"] and loaded.last_run.get("expedition") == "",
		"the last run survives save/load (%s)" % str(loaded.last_run))
	_check(loaded.unread_files() == 2, "unread archive files survive save/load")
	# A version 4 save (no last run, no read count) still loads.
	var old := Profile.from_dict({"version": 4, "intel": 50, "lore_pages": 2, "selected_class": "recruit"})
	_check(old.last_run.is_empty() and old.redeploy_problem() != "" and old.unread_files() == 0 and old.intel == 50,
		"an old save loads: no last run, no spurious NEW badge")
	# Something no longer owned or unlocked: no replay.
	var changed := _veteran()
	changed.remember_run(&"")
	changed.unlocked_classes = [&"recruit"]
	_check(changed.redeploy_problem() == "Class locked" and not changed.apply_last_run(), "a locked class blocks the replay")
	changed = _veteran()
	changed.remember_run(&"")
	changed.perk_ranks.clear()
	_check(changed.redeploy_problem() == "Perk not owned", "a perk no longer owned blocks the replay")
	changed = _veteran()
	changed.remember_run(&"")
	changed.max_threat = 1
	_check(changed.redeploy_problem() == "Threat locked", "a locked threat blocks the replay")
	changed = _veteran()
	changed.remember_run(&"no_such_expedition")
	_check(changed.redeploy_problem() == "Expedition unavailable", "an unavailable expedition blocks the replay")
	# Applying the last run restores what was played.
	var again := _veteran()
	again.remember_run(&"")
	again.selected_class = &"recruit"
	again.equipped_perks.clear()
	again.threat = 1
	_check(again.apply_last_run() and again.selected_class == &"vanguard" and again.equipped_perks == [&"thick_skin"] and again.threat == 2,
		"apply_last_run selects the last class, perks and threat")
	# The record flag.
	var ctx := RunContext.new(3)
	ctx.kills = 10
	again.best_kills = 5
	again.record_run(ctx)
	_check(again.new_best_kills, "beating the kill record sets the flag")
	again.record_run(ctx)
	_check(not again.new_best_kills, "matching the record is not a new one")


# --- QUICK REDEPLOY in the game flow -----------------------------------------

func _main_tests() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	var p := _veteran()
	main.set("profile", p)
	main.call("_go", 4)  # TITLE
	await _settle()
	var title: Node = main.get("_current")
	var button: Button = title.find_child("QuickRedeploy", true, false)
	_check(button != null and button.disabled, "title: QUICK REDEPLOY disabled without a previous run")
	main.call("_quick_redeploy")
	await _settle()
	_check(main.get("state") == 3, "no previous run: QUICK REDEPLOY falls back to the Armory")  # ARMORY
	# A run started from the Armory is remembered...
	p.threat = 2
	main.call("_new_run", &"")
	await _settle()
	_check(main.get("state") == 0 and p.last_run.get("class") == "vanguard", "starting a run remembers it")
	# ...and the title replays it, skipping the Armory and the run choice.
	p.selected_class = &"recruit"
	p.threat = 1
	main.call("_go", 4)
	await _settle()
	title = main.get("_current")
	button = title.find_child("QuickRedeploy", true, false)
	var summary: Label = button.find_child("Summary", true, false)
	_check(not button.disabled and summary.text == "Vanguard · Archipelago", "title shows the last run ('%s')" % summary.text)
	button.pressed.emit()
	await _settle()
	var ctx: RunContext = main.get("context")
	_check(main.get("state") == 0, "QUICK REDEPLOY goes straight to the boat")  # BOAT
	_check(ctx.player_class == &"vanguard" and ctx.threat == 2 and ctx.perks == [&"thick_skin"] and ctx.perk_rank(&"thick_skin") == 3 and not ctx.is_expedition(),
		"the replayed run has the last class, perks, threat and run type")
	# Something no longer owned: the Armory instead.
	p.perk_ranks.clear()
	p.equipped_perks.clear()
	main.call("_quick_redeploy")
	await _settle()
	_check(main.get("state") == 3, "a perk no longer owned: QUICK REDEPLOY opens the Armory")
	main.queue_free()
	await _settle()


# --- Debrief -----------------------------------------------------------------

func _run_context(won: bool) -> RunContext:
	var ctx := RunContext.new(11)
	ctx.apply_class(&"vanguard")
	ctx.threat = 2
	var rows: Array = [["beach", "defend", "elite", false, 100], ["jungle", "activate", "fog", true, 125]]
	if won:
		rows.append(["volcano", "rescue", "swarm", false, 140])
	for i in rows.size():
		var r: Array = rows[i]
		ctx.island_log.append({"island": i + 1, "modifier": r[2], "result": "cleared" if won or i == 0 else "died",
			"seconds": 300.0, "kills": 120, "intel": r[4], "biome": r[0], "mission": r[1], "hazard_pay": r[3], "part": ""})
		ctx.intel += int(r[4])
		ctx.kills += 120
	ctx.island_index = rows.size() - 1
	ctx.won = won
	if won:
		ctx.intel = int(ctx.intel * GameData.EXTRACTION_INTEL_MULTIPLIER)
	return ctx


func _accept(pressed: bool) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = KEY_ENTER
	e.physical_keycode = KEY_ENTER
	e.pressed = pressed
	return e


func _debrief_tests(won: bool) -> void:
	var p := _veteran()
	p.intel = 200
	p.best_kills = 100
	p.remember_run(&"")
	var ctx := _run_context(won)
	p.record_run(ctx)
	var debrief := Control.new()
	debrief.set_script(load("res://game/states/debrief.gd"))
	debrief.set("context", ctx)
	debrief.set("profile", p)
	var emitted: Array = []
	debrief.connect("new_run_requested", func() -> void: emitted.append(&"back"))
	debrief.connect("quick_redeploy_requested", func() -> void: emitted.append(&"redeploy"))
	root.add_child(debrief)
	await _settle()
	var tag: String = "won" if won else "lost"
	var back: Button = debrief.find_child("BackToArmory", true, false)
	_check(back != null and back.has_focus(), "%s: BACK TO ARMORY has the focus" % tag)
	_check(debrief.find_child("QuickRedeploy", true, false) != null, "%s: QUICK REDEPLOY is offered" % tag)
	_check(debrief.call("input_locked"), "%s: input is locked when the screen opens" % tag)
	root.push_input(_accept(true))
	root.push_input(_accept(false))
	await _settle()
	_check(emitted.is_empty(), "%s: a held button cannot skip the debrief in its first 0.6 s" % tag)
	# Cards: one per island of the run; unreached ones are there too.
	var grid: GridContainer = debrief.find_child("Islands", true, false)
	_check(grid != null and grid.get_child_count() == RunContext.ISLAND_COUNT, "%s: one card per island" % tag)
	var card2: Control = grid.get_child(1)
	_check((card2.find_child("Place", true, false) as Label).text == String(GameData.BIOMES[&"jungle"]["name"]).to_upper(), "%s: the card names the biome" % tag)
	_check((card2.find_child("Intel", true, false) as Label).text == "+125", "%s: the card shows the island's Intel" % tag)
	if not won:
		_check((grid.get_child(2).find_child("Place", true, false) as Label).text == "NOT REACHED", "lost: the third island was not reached")
		_check(debrief.find_child("RowLost", true, false) != null, "lost: the panel shows what death cost")
	# Intel numbers (after the count-up) agree with the profile.
	await create_timer(1.0).timeout
	var b: Dictionary = debrief.call("intel_breakdown")
	_check(int(b["islands"]) + int(b["hazard"]) + int(b["extraction"]) == ctx.intel, "%s: the breakdown adds up to the Intel earned (%s)" % [tag, str(b)])
	_check(int(b["hazard"]) == 125 - int(round(125 / GameData.HAZARD_INTEL_MULT)), "%s: hazard pay is its share of island 2" % tag)
	_check(int(b["after"]) == p.intel and int(b["after"]) - int(b["before"]) == ctx.intel, "%s: before -> after match the profile" % tag)
	var earned: Label = debrief.find_child("Earned", true, false)
	_check(earned.text == "+%d" % ctx.intel, "%s: EARNED counts up to the run's Intel (%s)" % [tag, earned.text])
	var total: RichTextLabel = debrief.find_child("Total", true, false)
	_check(total.get_parsed_text() == "%d → %d" % [p.intel - ctx.intel, p.intel], "%s: TOTAL shows before -> after (%s)" % [tag, total.get_parsed_text()])
	_check((debrief.find_child("Record", true, false) != null) == p.new_best_kills, "%s: RECORD only on a new best" % tag)
	# In reach: only things affordable and not owned, at most 2.
	var items: Array = debrief.call("items_in_reach")
	_check(items.size() <= 2 and items.all(func(i: Dictionary) -> bool: return int(i["cost"]) <= p.intel), "%s: in reach = affordable, at most 2" % tag)
	_check((debrief.find_child("InReach", true, false) != null) == not items.is_empty(), "%s: the in-reach row hides when empty" % tag)
	# After the lock, Enter presses the focused button.
	_check(not debrief.call("input_locked"), "%s: the lock ends" % tag)
	root.push_input(_accept(true))
	root.push_input(_accept(false))
	await _settle()
	_check(emitted == [&"back"], "%s: after 0.6 s Enter goes back to the Armory (%s)" % [tag, str(emitted)])
	_check(_inside(debrief, "%s debrief" % tag), "%s: the debrief fits 1152x648" % tag)
	debrief.queue_free()
	await _settle()


# --- Title fits the base size ------------------------------------------------

func _title_layout_tests() -> void:
	var p := _veteran()
	p.intel = 123456
	p.runs = 999
	p.extractions = 999
	p.lore_pages = 4
	p.remember_run(&"")
	var title := Node.new()
	title.set_script(load("res://game/states/title.gd"))
	title.set("profile", p)
	root.add_child(title)
	await _settle(4)
	_check(root.get_visible_rect().size == Vector2(1152, 648), "the test runs at the 1152x648 base size (%s)" % str(root.get_visible_rect().size))
	_check(_inside(title, "title"), "title: every control is inside 1152x648")
	var footer: Control = title.find_child("Footer", true, false)
	var motto: Control = title.find_child("Motto", true, false)
	var deploy: Control = title.find_child("Deploy", true, false)
	_check(footer.get_global_rect().position.x >= 420.0 - 0.5, "title: the stats bar sits under the art, not the menu")
	_check(motto.get_global_rect().end.y <= 648.0 and motto.get_global_rect().end.x <= 420.0, "title: the motto fits in the column")
	_check(deploy.has_focus(), "title: DEPLOY has the focus")
	var badge: Label = title.find_child("Badge", true, false)
	_check(badge.visible and badge.text == "4 NEW", "title: the archive badge counts unread files")
	var menu: Array[Control] = []
	for n: String in ["Deploy", "QuickRedeploy", "IntelArchive", "Settings", "Quit", "TestIsland"]:
		var c: Control = title.find_child(n, true, false)
		if c != null:
			menu.append(c)
	var overlap: bool = false
	for i in menu.size():
		for j in range(i + 1, menu.size()):
			overlap = overlap or menu[i].get_global_rect().intersects(menu[j].get_global_rect())
		overlap = overlap or menu[i].get_global_rect().intersects(footer.get_global_rect())
	_check(not overlap, "title: menu entries and the stats bar do not overlap")
	title.queue_free()
	await _settle()


## Every visible Control of `node` lies inside the 1152x648 viewport, and no
## Label needs more width than it got (that would draw past its box).
func _inside(node: Node, what: String) -> bool:
	var view := Rect2(Vector2.ZERO, Vector2(1152, 648)).grow(0.5)
	var ok: bool = true
	for c: Node in node.find_children("*", "Control", true, false):
		var control := c as Control
		if not control.is_visible_in_tree():
			continue
		var r: Rect2 = control.get_global_rect()
		if r.size.x > 0.0 and not view.encloses(r):
			print("  %s: %s outside the screen: %s" % [what, control.get_path(), str(r)])
			ok = false
		if control is Label and (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF \
				and (control as Label).text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING \
				and control.get_combined_minimum_size().x > control.size.x + 0.5:
			print("  %s: %s text wider than its box" % [what, control.get_path()])
			ok = false
	return ok
