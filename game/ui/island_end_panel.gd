class_name IslandEndPanel
extends Control
## End-of-island report, shown when an island or an expedition part is won.
## Same "glass" family as the pause and defeat screens: the blurred island
## stays behind, no dark plate, text with a shadow, one translucent box.
##
## It answers three questions, in this order: did I make it (header with a
## tick, shape + colour), how did THIS island go (big numbers) and what is
## next (one primary button). Run totals sit below in small type, labelled,
## so they are never mistaken for this island's numbers.

signal continue_pressed

## Presses are ignored this long after the panel opens: the pad's A is also
## the Breaker, so a press meant for the fight must not skip the report.
const LOCK_MS: int = 600

var opened_ms: int = -100000
var title: Label
var where: Label
var scope: Label
var kills: Label
var headshots: Label
var intel: Label
var level: Label
var level_gain: Label
var cards: Label
var power_ups: Label
var run_totals: Label
var next_step: Label
var continue_button: Button
var hint: Label
var _tick: TextureRect


func _init() -> void:
	name = "IslandEnd"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	add_child(Hud._blur(0.42))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.custom_minimum_size.x = 720
	content.add_theme_constant_override("separation", 10)
	center.add_child(content)

	content.add_child(_text("SALVAGE & CO.  /  FIELD REPORT", 13, UiTheme.TEXT_MUTED, true))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	content.add_child(head)
	_tick = TextureRect.new()
	_tick.texture = UiTheme.tick_icon()
	_tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tick.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_tick.custom_minimum_size = Vector2(40, 40)
	_tick.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tick.modulate = UiTheme.SUCCESS
	head.add_child(_tick)
	title = MenuDialog.ink(UiTheme.title("ISLAND CLEARED", 52), 5)
	title.name = "Title"
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_color_override("font_color", UiTheme.SUCCESS)
	head.add_child(title)
	where = _text("", 15, UiTheme.TEXT_MUTED, true)
	where.name = "Where"
	content.add_child(where)

	# This island: the numbers that matter, big, in one translucent box.
	scope = _text("THIS ISLAND", 13, UiTheme.TEXT_MUTED, true)
	scope.name = "Scope"
	content.add_child(scope)
	var box := MenuDialog.glass_box(content)
	box.name = "ThisIsland"
	var inside := VBoxContainer.new()
	inside.add_theme_constant_override("separation", 8)
	box.add_child(inside)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 16)
	inside.add_child(stats)
	kills = _stat(stats, "KILLS", UiTheme.TEXT)
	headshots = _stat(stats, "HEADSHOTS", UiTheme.TEXT)
	intel = _stat(stats, "INTEL EARNED", UiTheme.SUCCESS)
	var level_col: VBoxContainer = _column(stats, "LEVEL REACHED")
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 8)
	level_col.add_child(level_row)
	level = _number(UiTheme.TEXT)
	level.name = "Level"
	level_row.add_child(level)
	level_gain = _text("", 16, UiTheme.INFO, true)
	level_gain.name = "LevelGain"
	level_gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	level_row.add_child(level_gain)
	inside.add_child(HSeparator.new())
	cards = _detail(inside, "CARDS")
	power_ups = _detail(inside, "POWER-UPS")

	# Whole run: smaller, and labelled, so it never reads as this island.
	run_totals = _text("", 14, UiTheme.TEXT_MUTED, true)
	run_totals.name = "RunTotals"
	content.add_child(run_totals)
	content.add_child(HSeparator.new())

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	content.add_child(bottom)
	var next_col := VBoxContainer.new()
	next_col.add_theme_constant_override("separation", 0)
	next_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(next_col)
	next_col.add_child(_text("NEXT", 13, UiTheme.TEXT_MUTED, true))
	next_step = MenuDialog.ink(UiTheme.label("", 24, UiTheme.INFO), 5)
	next_step.name = "Next"
	next_step.autowrap_mode = TextServer.AUTOWRAP_OFF
	next_step.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	next_step.add_theme_font_override("font", UiTheme.heading_font())
	next_col.add_child(next_step)
	var action := VBoxContainer.new()
	action.add_theme_constant_override("separation", 4)
	action.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(action)
	continue_button = UiTheme.button(action, "CONTINUE  ›", _on_continue, true)
	continue_button.name = "Continue"
	continue_button.custom_minimum_size = Vector2(260, 54)
	# The only button: focus never leaves it (d-pad, Tab).
	for side in ["focus_neighbor_top", "focus_neighbor_bottom", "focus_neighbor_left", "focus_neighbor_right", "focus_next", "focus_previous"]:
		continue_button.set(side, NodePath("."))
	hint = _text("", 13, UiTheme.TEXT_MUTED, true)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action.add_child(hint)


## Shows the report for a won island. `ctx` is null for a lone island (F6).
func open(run: IslandRun, ctx: RunContext, gamepad: bool) -> void:
	var s: Dictionary = summary(run, ctx)
	title.text = s["title"]
	where.text = s["where"]
	scope.text = "THIS PART" if ctx != null and ctx.is_expedition() else "THIS ISLAND"
	kills.text = str(s["kills"])
	headshots.text = str(s["headshots"])
	intel.text = "+%d" % s["intel"]
	level.text = str(s["level"])
	level_gain.text = "+%d" % s["levels_gained"] if s["levels_gained"] > 0 else ""
	cards.text = s["cards"] if s["cards"] != "" else "none this island"
	power_ups.text = s["power_ups"] if s["power_ups"] != "" else "none this island"
	run_totals.text = s["run_totals"]
	run_totals.visible = s["run_totals"] != ""
	next_step.text = "›  " + s["next"]
	set_prompt(gamepad)
	opened_ms = Time.get_ticks_msec()
	visible = true
	# Dimmed until it answers: the player sees it is not live yet.
	continue_button.modulate.a = 0.45
	create_tween().tween_property(continue_button, "modulate:a", 1.0, 0.15).set_delay(LOCK_MS / 1000.0)
	continue_button.grab_focus.call_deferred()


func _on_continue() -> void:
	if visible and not is_locked():
		continue_pressed.emit()


func set_prompt(gamepad: bool) -> void:
	hint.text = "[ %s ] CONTINUE" % GameInput.prompt(&"ui_accept", gamepad)


func is_locked() -> bool:
	return Time.get_ticks_msec() - opened_ms < LOCK_MS


## While locked, presses (keys, mouse and pad buttons) stop here, before the
## button sees them; F11 still works.
func _input(event: InputEvent) -> void:
	if not visible or not is_locked():
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F11:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


## Everything the panel shows, as plain data (tests read it too).
##   title     "ISLAND CLEARED", "PART CLEARED" or "EXTRACTED" (run's last)
##   where     "ISLAND 1 OF 3 · BEACH · ACTIVATE · 04:12 ON THE ISLAND"
##   kills, headshots, intel, level, levels_gained   this island only
##   cards, power_ups   taken on this island ("" = none)
##   run_totals   whole run so far ("" without a run around the island)
##   next      where CONTINUE goes
static func summary(run: IslandRun, ctx: RunContext) -> Dictionary:
	var last: bool = ctx != null and ctx.is_last_island()
	var expedition: bool = ctx != null and ctx.is_expedition()
	var title_text: String = "ISLAND CLEARED"
	if run.mission == &"holdout" or last:
		title_text = "EXTRACTED"
	elif expedition or run.has_exit():
		title_text = "PART CLEARED"
	var place: String = "FIELD TEST"
	if expedition:
		place = "%s · PART %d OF %d" % [ctx.part_name().to_upper(), ctx.island_index + 1, ctx.island_count()]
	elif ctx != null:
		place = "ISLAND %d OF %d · %s" % [ctx.island_index + 1, ctx.island_count(), String(GameData.BIOMES[run.map.biome]["name"]).to_upper()]
	var seconds: int = int(run.time_alive - run.landed_time)
	var where_text: String = "%s · %s · %02d:%02d %s" % [place, Expeditions.mission_name(run.mission).to_upper(),
		seconds / 60, seconds % 60, "IN THIS PART" if expedition else "ON THE ISLAND"]
	# The context still holds the values from the landing until the island
	# writes back (IslandRun.save_to_context runs after CONTINUE).
	var kills_before: int = ctx.kills if ctx != null else 0
	var heads_before: int = ctx.headshots if ctx != null else 0
	var level_before: int = ctx.level if ctx != null else 1
	var intel_here: int = run.intel_earned()
	var totals: String = ""
	if ctx != null:
		var run_seconds: int = int(run.time_alive)
		totals = "RUN TOTAL  ·  KILLS %d  ·  HEADSHOTS %d  ·  INTEL BANKED %d  ·  %02d:%02d" % [
			run.kills, run.headshots, ctx.intel + intel_here, run_seconds / 60, run_seconds % 60]
	return {
		"title": title_text, "where": where_text,
		"kills": run.kills - kills_before, "headshots": run.headshots - heads_before,
		"intel": intel_here, "level": run.level, "levels_gained": maxi(0, run.level - level_before),
		"cards": _cards_text(run), "power_ups": _power_ups_text(run),
		"run_totals": totals, "next": next_text(ctx),
	}


## Where CONTINUE leads (main.gd: boat, expedition camp or debrief).
static func next_text(ctx: RunContext) -> String:
	if ctx == null:
		return "RESTART FIELD TEST"
	if ctx.is_last_island():
		return "DEBRIEF  ·  EXTRACTION BONUS ×%.1f" % GameData.EXTRACTION_INTEL_MULTIPLIER
	if ctx.is_expedition():
		var next_name: String = IslandRun.next_part_name(ctx)
		return "CAMP, THEN %s" % (next_name.to_upper() if next_name != "" else "PART %d" % (ctx.island_index + 2))
	# The boat no longer offers routes between islands: it draws one and
	# leaves on a countdown (boat.gd).
	return "BOAT  ·  NEXT ISLAND %d OF %d IN %d S" % [ctx.island_index + 2, ctx.island_count(), int(GameData.NEXT_ISLAND_COUNTDOWN)]


## Cards taken here, in pick order, each once with the rank it ended at.
static func _cards_text(run: IslandRun) -> String:
	var names := PackedStringArray()
	var seen := {}
	for id: StringName in run.cards_picked:
		if seen.has(id):
			continue
		seen[id] = true
		var card_title: String = String(id).capitalize()
		for c in run.all_cards:
			if c.id == id:
				card_title = c.title
				break
		names.append("%s %s" % [card_title, Hud.roman(run.stacks(id))])
	return "  ·  ".join(names)


## Power-ups picked here: icon + name, "×2" when taken more than once.
static func _power_ups_text(run: IslandRun) -> String:
	var order: Array[StringName] = []
	var count := {}
	for id: StringName in run.power_ups_picked:
		if not count.has(id):
			order.append(id)
			count[id] = 0
		count[id] += 1
	var parts := PackedStringArray()
	for id in order:
		var text: String = "%s %s" % [GameData.power_up_icon(id), GameData.power_up_name(id)]
		parts.append(text + (" ×%d" % count[id] if count[id] > 1 else ""))
	return "  ·  ".join(parts)


# --- Builders -------------------------------------------------------------------

func _text(text: String, font_size: int, color: Color, mono: bool = false) -> Label:
	var l := UiTheme.label(text, font_size, color, mono)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return MenuDialog.ink(l)


func _column(parent: Control, caption: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)
	col.add_child(_text(caption, 12, UiTheme.TEXT_MUTED, true))
	return col


func _number(color: Color) -> Label:
	var n := MenuDialog.ink(UiTheme.label("0", 34, color), 5)
	n.autowrap_mode = TextServer.AUTOWRAP_OFF
	n.add_theme_font_override("font", UiTheme.mono_bold_font())
	return n


func _stat(parent: Control, caption: String, color: Color) -> Label:
	var n: Label = _number(color)
	n.name = caption.capitalize().replace(" ", "")
	_column(parent, caption).add_child(n)
	return n


## "CARDS    Piercing Rounds II · Fast Learner I" (one line, "…" if long).
func _detail(parent: Control, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var key := _text(caption, 12, UiTheme.TEXT_MUTED, true)
	key.custom_minimum_size.x = 92
	row.add_child(key)
	var value := MenuDialog.ink(UiTheme.label("", 16, UiTheme.TEXT))
	value.name = caption.capitalize().replace(" ", "").replace("-", "")
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.clip_text = true
	row.add_child(value)
	return value
