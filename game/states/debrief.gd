extends Control
## End of run: the result, one card per island (or expedition part), where
## the Intel came from, what it now buys at the Armory, and the way back
## (docs/design/MENUS.md, "Redesenho de outubro de 2026", point 7).
## Input is ignored for the first INPUT_LOCK seconds, so a fire or breaker
## button still held from the fight cannot skip the screen.

signal new_run_requested
## QUICK REDEPLOY: the same run again (main.gd checks it can be played).
signal quick_redeploy_requested

const INPUT_LOCK: float = 0.6  ## seconds before any button answers
const COUNT_TIME: float = 0.8  ## seconds the Intel numbers take to count up
const INTEL_PANEL_WIDTH: float = 306.0

var context: RunContext
var profile: Profile
var _ending: DialogueBox
var _age: float = 0.0
var _back: Button
var _redeploy: Button
var _buttons: HBoxContainer
var _intel_rows: VBoxContainer
var _total: RichTextLabel
var _meta: Label
var _breakdown: Dictionary = {}


func _ready() -> void:
	# The parent is a plain Node: the anchors then follow the window.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_breakdown = intel_breakdown()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 22)
	add_child(margin)
	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 14)
	margin.add_child(screen)
	_header(screen)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	screen.add_child(body)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 9)
	body.add_child(left)
	_island_cards(left)
	_in_reach(left)
	_intel_panel(body)
	_footer(screen)
	_back.grab_focus()
	add_child(UiSfx.new())
	_count_up()
	# The story finale: all Intel files recovered and the run won.
	if OriginEnding.due(profile, context) and ResourceLoader.exists(OriginEnding.RESOURCE) and has_node("/root/DialogueManager"):
		_ending = DialogueBox.open(self, load(OriginEnding.RESOURCE), "start", [{"origin": OriginEnding.new(profile)}])
		_ending.finished.connect(_refresh_after_ending)


func _process(delta: float) -> void:
	_age += delta


## True while the screen ignores input (its first INPUT_LOCK seconds).
func input_locked() -> bool:
	return _age < INPUT_LOCK


## Runs before the buttons see anything: while locked, presses and releases
## of keys, mouse buttons and pad buttons stop here (F11 still works).
func _input(event: InputEvent) -> void:
	if not input_locked():
		return
	if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_F11:
		return
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		get_viewport().set_input_as_handled()


## B / Esc: back to the Armory, like the primary button.
func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_ending) or input_locked():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		new_run_requested.emit()


# --- Data ---------------------------------------------------------------------

## Where the run's Intel came from, as the game computes it:
##   islands   Intel of the islands (parts), without the hazard pay share
##   hazard    the +25% hazard pay share of the islands that took it
##   extraction  the x1.5 extraction bonus (0 on death)
##   lost      what that bonus would have paid when the run was lost
##   files     Intel files recovered
##   earned    added to the profile (= islands + hazard + extraction)
##   before / after  the profile's Intel before and after this run
func intel_breakdown() -> Dictionary:
	var mult: float = GameData.EXTRACTION_INTEL_MULTIPLIER
	var islands_total: int = 0
	var hazard: int = 0
	if context.island_log.is_empty():
		islands_total = int(round(context.intel / mult)) if context.won else context.intel
	for entry: Dictionary in context.island_log:
		var value: int = int(entry.get("intel", 0))
		islands_total += value
		if entry.has("intel_hazard"):
			hazard += int(entry["intel_hazard"])  # recorded when the island was scored
		elif bool(entry.get("hazard_pay", false)):
			# Older logs: estimate the share from the truncated total.
			hazard += value - int(round(value / GameData.HAZARD_INTEL_MULT))
	var extraction: int = context.intel - islands_total if context.won else 0
	var lost: int = 0 if context.won else int(islands_total * mult) - islands_total
	return {
		"islands": islands_total - hazard, "hazard": hazard, "extraction": extraction,
		"lost": lost, "files": context.lore_found, "earned": context.intel,
		"before": profile.intel - context.intel, "after": profile.intel,
	}


## Up to 2 Armory items the player can afford now and has not bought:
## first those this run's Intel brought into reach, then the dearest.
## Each is {name, kind, cost}.
func items_in_reach() -> Array[Dictionary]:
	var all: Array[Dictionary] = []
	for id: StringName in GameData.CLASSES:
		if not profile.unlocked_classes.has(id):
			all.append({"name": "Class: " + String(GameData.CLASS_INFO[id]["name"]), "kind": "New class", "cost": int(GameData.CLASS_INFO[id]["cost"])})
	for weapon in GameData.weapons():
		var cost: int = GameData.weapon_cost(weapon.id)
		if cost > 0 and not profile.unlocked_weapons.has(weapon.id):
			all.append({"name": weapon.display_name, "kind": "Weapon", "cost": cost})
	for node in GameData.perk_nodes():
		var problem: String = profile.rank_problem(node)
		if problem == "" or problem == "Not enough Intel":
			var choice: GameData.Perk = profile.perk_choice(node)
			var rank: int = profile.node_rank(node) + 1
			all.append({"name": "Perk: %s %s" % [choice.title if choice != null else String(node).capitalize(), GameData.RANK_NAMES[rank]],
				"kind": "Perk rank (A and B)", "cost": profile.next_rank_cost(node)})
	if profile.next_slot_cost() > 0:
		all.append({"name": "Perk slot %d" % (profile.slots + 1), "kind": "One more perk per run", "cost": profile.next_slot_cost()})
	var before: int = int(_breakdown.get("before", profile.intel - context.intel))
	var reach: Array[Dictionary] = []
	for item: Dictionary in all:
		if int(item["cost"]) <= profile.intel:
			reach.append(item)
	reach.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var new_a: bool = int(a["cost"]) > before
		var new_b: bool = int(b["cost"]) > before
		if new_a != new_b:
			return new_a
		return int(a["cost"]) > int(b["cost"]))
	return reach.slice(0, 2)


## One card per island of the run: its log entry (from IslandRun, plus the
## biome/mission/modifier main.gd adds on landing), or {} if not reached.
func island_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i in maxi(context.island_count(), context.island_log.size()):
		out.append(context.island_log[i] if i < context.island_log.size() else {})
	return out


# --- Layout -------------------------------------------------------------------

func _header(parent: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 2)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var class_title: String = String(GameData.CLASS_INFO.get(context.player_class, {}).get("name", String(context.player_class).capitalize()))
	var run_title: String = Expeditions.display_name(context.expedition) if context.is_expedition() else "Archipelago"
	var seconds: int = int(context.time_alive)
	var caption := _caption("DEBRIEF / RUN %d · %s · %s · THREAT %d · %02d:%02d" % [profile.runs, class_title.to_upper(), run_title.to_upper(), context.threat, seconds / 60, seconds % 60])
	caption.name = "Caption"
	left.add_child(caption)
	var result := HBoxContainer.new()
	result.add_theme_constant_override("separation", 12)
	left.add_child(result)
	var color: Color = UiTheme.SUCCESS if context.won else UiTheme.DANGER
	var icon := TextureRect.new()
	icon.texture = UiTheme.tick_icon() if context.won else _cross_icon()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.modulate = color
	result.add_child(icon)
	var heading := UiTheme.title("EXTRACTED" if context.won else "RUN LOST", 46)
	heading.name = "Result"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	heading.add_theme_color_override("font_color", color)
	result.add_child(heading)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 20)
	stats.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(stats)
	_stat(stats, "KILLS", context.kills)
	if profile.new_best_kills:
		var record := _pill("RECORD", UiTheme.ACCENT, UiTheme.ON_ACCENT)
		record.name = "Record"
		stats.get_child(0).add_child(record)
	_stat(stats, "HEADSHOTS", context.headshots)
	_stat(stats, "LEVEL", context.level)
	parent.add_child(HSeparator.new())


func _stat(parent: Control, key: String, value: int) -> void:
	var cell := HBoxContainer.new()
	cell.name = "Stat" + key.capitalize()
	cell.add_theme_constant_override("separation", 7)
	parent.add_child(cell)
	var k := UiTheme.label(key, 15, UiTheme.TEXT_MUTED, true)
	k.autowrap_mode = TextServer.AUTOWRAP_OFF
	cell.add_child(k)
	var v := UiTheme.label(str(value), 15, UiTheme.TEXT)
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_theme_font_override("font", UiTheme.mono_bold_font())
	cell.add_child(v)


func _island_cards(parent: Control) -> void:
	var entries := island_entries()
	parent.add_child(_caption("PARTS" if context.is_expedition() else "ISLANDS"))
	var grid := GridContainer.new()
	grid.name = "Islands"
	grid.columns = maxi(1, entries.size())
	grid.add_theme_constant_override("h_separation", 11)
	grid.add_theme_constant_override("v_separation", 11)
	parent.add_child(grid)
	for i in entries.size():
		grid.add_child(_island_card(i, entries[i]))


func _island_card(i: int, entry: Dictionary) -> PanelContainer:
	var reached: bool = not entry.is_empty()
	var card := PanelContainer.new()
	card.name = "Island%d" % (i + 1)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_FILL
	card.add_theme_stylebox_override("panel", _card_style(reached))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	var number := _caption("%s %d" % ["PART" if context.is_expedition() else "ISLAND", i + 1])
	number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(number)
	var cleared: bool = String(entry.get("result", "")) == "cleared"
	if reached:
		var mark := TextureRect.new()
		mark.name = "Result"
		mark.texture = UiTheme.tick_icon() if cleared else _cross_icon()
		mark.modulate = UiTheme.SUCCESS if cleared else UiTheme.DANGER
		mark.tooltip_text = "Cleared" if cleared else "Lost here"
		mark.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		top.add_child(mark)
	var part: Dictionary = context.expedition_parts[i] if context.is_expedition() and i < context.expedition_parts.size() else {}
	var place: String
	if not part.is_empty():
		place = String(part.get("name", ""))
	elif entry.has("biome"):
		place = String(GameData.BIOMES.get(StringName(entry["biome"]), {}).get("name", String(entry["biome"]).capitalize()))
	else:
		place = "Not reached" if not reached else "Island %d" % (i + 1)
	var name_label := UiTheme.label(place.to_upper(), 24 if part.is_empty() else 19, UiTheme.TEXT if reached else UiTheme.TEXT_MUTED)
	name_label.name = "Place"
	name_label.add_theme_font_override("font", UiTheme.title_font() if part.is_empty() else UiTheme.heading_font())
	box.add_child(name_label)
	var mission: String = String(entry.get("mission", part.get("mission", "")))
	if mission != "":
		box.add_child(_trimmed(_line("● " + Expeditions.mission_name(StringName(mission)).to_upper(), UiTheme.INFO if reached else UiTheme.TEXT_MUTED, true)))
	if reached:
		var modifier := StringName(entry.get("modifier", "calm"))
		var calm: bool = modifier == &"calm"
		box.add_child(_trimmed(_line(("– " if calm else "▲ ") + GameData.modifier(modifier).title.to_upper(), UiTheme.TEXT_MUTED if calm else UiTheme.DANGER)))
		if bool(entry.get("hazard_pay", false)):
			box.add_child(_line("◆ HAZARD PAY", UiTheme.ACCENT))
		var gap := Control.new()
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		box.add_child(gap)
		var foot_line := HSeparator.new()
		foot_line.add_theme_constant_override("separation", 4)
		box.add_child(foot_line)
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 6)
		box.add_child(foot)
		var seconds: int = int(float(entry.get("seconds", 0.0)))
		foot.add_child(_line("%02d:%02d" % [seconds / 60, seconds % 60], UiTheme.TEXT))
		var kills := _line("%d kills" % int(entry.get("kills", 0)), UiTheme.TEXT)
		kills.name = "Kills"
		kills.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		kills.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		foot.add_child(kills)
		var intel := _line("+%d" % int(entry.get("intel", 0)), UiTheme.ACCENT)
		intel.name = "Intel"
		foot.add_child(intel)
	elif not part.is_empty():
		box.add_child(_line("NOT REACHED", UiTheme.TEXT_MUTED))
	return card


func _card_style(reached: bool) -> StyleBox:
	if not reached:
		var dashed := MarkedBox.new(StyleBoxFlat.new())
		dashed.base.bg_color = Color.TRANSPARENT
		dashed.dashed = true
		dashed.dash_color = UiTheme.LINE.lightened(0.2)
		for side: int in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			dashed.base.set_content_margin(side, 13)
		dashed.sync_margins()
		return dashed
	var s := StyleBoxFlat.new()
	s.bg_color = UiTheme.PANEL
	s.border_color = UiTheme.LINE
	s.set_border_width_all(1)
	s.set_corner_radius_all(UiTheme.RADIUS)
	s.set_content_margin_all(13)
	return s


## "Now in reach at the Armory": hidden when nothing is affordable.
func _in_reach(parent: Control) -> void:
	var items := items_in_reach()
	if items.is_empty():
		return
	var gap := Control.new()
	gap.custom_minimum_size.y = 4
	parent.add_child(gap)
	parent.add_child(_caption("NOW IN REACH AT THE ARMORY"))
	var grid := GridContainer.new()
	grid.name = "InReach"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 11)
	parent.add_child(grid)
	for item: Dictionary in items:
		var plate := PanelContainer.new()
		plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s := StyleBoxFlat.new()
		s.bg_color = Color.TRANSPARENT
		s.border_color = UiTheme.ACCENT
		s.set_border_width_all(1)
		s.set_corner_radius_all(UiTheme.RADIUS)
		s.content_margin_left = 13
		s.content_margin_right = 13
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		plate.add_theme_stylebox_override("panel", s)
		grid.add_child(plate)
		var row := HBoxContainer.new()
		plate.add_child(row)
		var text := VBoxContainer.new()
		text.add_theme_constant_override("separation", 0)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text)
		var title := UiTheme.label(String(item["name"]), 19)
		title.add_theme_font_override("font", UiTheme.heading_font())
		text.add_child(title)
		text.add_child(UiTheme.label(String(item["kind"]), 14, UiTheme.TEXT_MUTED))
		var cost := UiTheme.label(str(item["cost"]), 15, UiTheme.ACCENT)
		cost.autowrap_mode = TextServer.AUTOWRAP_OFF
		cost.add_theme_font_override("font", UiTheme.mono_bold_font())
		cost.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cost)


func _intel_panel(parent: Control) -> void:
	var panel := PanelContainer.new()
	panel.name = "IntelPanel"
	panel.custom_minimum_size.x = INTEL_PANEL_WIDTH
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	box.add_child(_caption("INTEL"))
	_intel_rows = VBoxContainer.new()
	_intel_rows.add_theme_constant_override("separation", 7)
	box.add_child(_intel_rows)
	var b := _breakdown
	_intel_row("Parts cleared" if context.is_expedition() else "Islands", "+%d", int(b["islands"]), "Islands")
	if int(b["hazard"]) > 0:
		_intel_row("Hazard pay", "+%d", int(b["hazard"]), "Hazard")
	if context.won:
		_intel_row("Extraction ×%.1f" % GameData.EXTRACTION_INTEL_MULTIPLIER, "+%d", int(b["extraction"]), "Extraction")
	var files: int = int(b["files"])
	_intel_row("Intel files found", "%d new" if files > 0 else "%d", files, "Files", UiTheme.INFO if files > 0 else UiTheme.TEXT_MUTED, false)
	box.add_child(HSeparator.new())
	var earned_row := HBoxContainer.new()
	box.add_child(earned_row)
	var earned_key := UiTheme.label("EARNED", 22)
	earned_key.add_theme_font_override("font", UiTheme.heading_font())
	earned_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	earned_row.add_child(earned_key)
	var earned := UiTheme.label("+0", 30, UiTheme.ACCENT)
	earned.autowrap_mode = TextServer.AUTOWRAP_OFF
	earned.name = "Earned"
	earned.add_theme_font_override("font", UiTheme.mono_bold_font())
	earned.set_meta(&"format", "+%d")
	earned.set_meta(&"target", int(b["earned"]))
	earned_row.add_child(earned)
	var total_row := HBoxContainer.new()
	box.add_child(total_row)
	var total_key := UiTheme.label("TOTAL", 15, UiTheme.TEXT_MUTED, true)
	total_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_row.add_child(total_key)
	_total = RichTextLabel.new()
	_total.name = "Total"
	_total.bbcode_enabled = true
	_total.fit_content = true
	_total.autowrap_mode = TextServer.AUTOWRAP_OFF
	_total.scroll_active = false
	_total.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_total.add_theme_font_override("normal_font", UiTheme.mono_font())
	_total.add_theme_font_override("bold_font", UiTheme.mono_bold_font())
	_total.add_theme_font_size_override("normal_font_size", 15)
	_total.add_theme_font_size_override("bold_font_size", 15)
	_total.add_theme_color_override("default_color", UiTheme.TEXT_MUTED)
	total_row.add_child(_total)
	_set_total(int(b["before"]))
	if not context.won and int(b["lost"]) > 0:
		# Under the total, not in the sum: dying keeps the Intel but loses
		# the extraction bonus.
		var lost := UiTheme.label("Lost on death: %d Intel (no ×%.1f extraction bonus)" % [int(b["lost"]), GameData.EXTRACTION_INTEL_MULTIPLIER], 14, UiTheme.DANGER)
		lost.name = "RowLost"
		box.add_child(lost)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	_meta = UiTheme.label(_meta_text(), 14, UiTheme.TEXT_MUTED)
	_meta.name = "Meta"
	box.add_child(_meta)


func _intel_row(key: String, format: String, value: int, id: String, color: Color = UiTheme.TEXT, count: bool = true) -> void:
	var row := HBoxContainer.new()
	row.name = "Row" + id
	_intel_rows.add_child(row)
	var k := UiTheme.label(key, 16)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	var v := UiTheme.label(format % (0 if count else value), 16, color)
	v.name = "Value"
	v.autowrap_mode = TextServer.AUTOWRAP_OFF
	v.add_theme_font_override("font", UiTheme.mono_bold_font())
	if count:
		v.set_meta(&"format", format)
		v.set_meta(&"target", value)
	row.add_child(v)


func _set_total(value: int) -> void:
	_total.text = "%d → [b][color=#%s]%d[/color][/b]" % [int(_breakdown["before"]), UiTheme.TEXT.to_html(false), value]


func _meta_text() -> String:
	var text: String = "Runs %d · Extractions %d · Best kills %d" % [profile.runs, profile.extractions, profile.best_kills]
	if context.lore_found > 0:
		text += "\nRead new files in the Intel Archive."
	if profile.ending != "":
		text += "\nStory ending: %s" % OriginEnding.ENDINGS.get(profile.ending, "")
	return text


func _footer(parent: Control) -> void:
	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	_buttons.add_theme_constant_override("separation", 14)
	parent.add_child(_buttons)
	_redeploy = UiTheme.button(_buttons, "QUICK REDEPLOY", func() -> void: quick_redeploy_requested.emit())
	_redeploy.name = "QuickRedeploy"
	_redeploy.custom_minimum_size = Vector2(0, 50)
	_redeploy.add_theme_font_size_override("font_size", 21)
	var problem: String = profile.redeploy_problem()
	if profile.last_run.is_empty():
		_redeploy.disabled = true
		_redeploy.focus_mode = Control.FOCUS_NONE
		_redeploy.tooltip_text = "No previous run to repeat."
	else:
		_redeploy.tooltip_text = ("%s: opens the Armory instead." % problem) if problem != "" else "The same run again: %s." % profile.last_run_summary()
	_back = UiTheme.button(_buttons, "BACK TO ARMORY", func() -> void: new_run_requested.emit(), true)
	_back.name = "BackToArmory"
	_back.custom_minimum_size = Vector2(0, 50)
	_back.add_theme_font_override("font", UiTheme.title_font())
	_back.add_theme_font_size_override("font_size", 23)
	for b: Button in [_redeploy, _back]:
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(b)
	_back.focus_neighbor_left = _back.get_path_to(_redeploy)
	_redeploy.focus_neighbor_right = _redeploy.get_path_to(_back)
	# The buttons "wake up" when the input lock ends.
	_buttons.modulate.a = 0.45
	create_tween().tween_property(_buttons, "modulate:a", 1.0, 0.15).set_delay(INPUT_LOCK)


## Counts every number with a "target" from 0 (TOTAL from the old value).
func _count_up() -> void:
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for node in find_children("*", "Label", true, false):
		if node.has_meta(&"target"):
			var label := node as Label
			var format: String = label.get_meta(&"format")
			tween.tween_method(func(v: float) -> void: label.text = format % int(round(v)), 0.0, float(label.get_meta(&"target")), COUNT_TIME)
	tween.tween_method(func(v: float) -> void: _set_total(int(round(v))), float(_breakdown["before"]), float(_breakdown["after"]), COUNT_TIME)


func _caption(text: String) -> Label:
	var l := UiTheme.label(text, 13, UiTheme.TEXT_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var font := FontVariation.new()
	font.base_font = UiTheme.mono_font()
	font.spacing_glyph = 1
	l.add_theme_font_override("font", font)
	return l


func _line(text: String, color: Color, bold: bool = false) -> Label:
	var l := UiTheme.label(text, 13, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", UiTheme.mono_bold_font() if bold else UiTheme.mono_font())
	return l


## Long lines in narrow cards (4 expedition parts) end in "…" instead of
## widening the card past the screen.
func _trimmed(l: Label) -> Label:
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.tooltip_text = l.text
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	return l


func _pill(text: String, bg: Color, ink: Color) -> Label:
	var l := UiTheme.label(text, 12, ink)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.add_theme_font_override("font", UiTheme.mono_bold_font())
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(3)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 1
	s.content_margin_bottom = 1
	l.add_theme_stylebox_override("normal", s)
	return l


## RUN LOST: a cross, so the result reads by shape as well as by colour.
static func _cross_icon() -> Texture2D:
	var img := Image.new()
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='18' height='18' viewBox='0 0 18 18'><path d='M4 4l10 10M14 4L4 14' fill='none' stroke='#fff' stroke-width='2.6'/></svg>"
	if img.load_svg_from_string(svg, 2.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(18, 18))
	return tex


## After the story ending: its bonus joins the Intel panel and the total.
func _refresh_after_ending() -> void:
	profile.save()
	if profile.ending == "":
		return
	_intel_row("Story ending", "+%d", OriginEnding.BONUS_INTEL, "Ending", UiTheme.ACCENT, false)
	_breakdown["after"] = profile.intel
	_set_total(profile.intel)
	_meta.text = _meta_text()
