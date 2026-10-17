class_name MenuDialog
extends Control
## A shared modal with a focus cycle, input isolation and return focus.

signal closed

## Alpha of translucent boxes and buttons over the blurred game.
const GLASS_ALPHA: float = 0.55

## Translucent "glass" look (the pause family): set before the dialog enters
## the tree. No dark dim and no panel: the blurred game behind shows
## through, text carries a dark shadow and inner boxes are translucent.
var glass: bool = false
var content: VBoxContainer
var _previous_focus: Control


func _ready() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	# Glass keeps the dim invisible: it still stops clicks reaching the game.
	dim.color = Color(0, 0, 0, 0.0 if glass else 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	content = UiTheme.centered_panel(self, 620)
	if glass:
		(content.get_parent() as Control).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	call_deferred("_trap_focus")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent) -> void:
	# Keep F11 available, but prevent Q/Start/shortcuts from reaching the game.
	if event is InputEventKey and event.physical_keycode == KEY_F11:
		return
	get_viewport().set_input_as_handled()


func _trap_focus() -> void:
	var buttons: Array[Control] = []
	for node in find_children("*", "Control", true, false):
		if (node is BaseButton and not node.disabled) or node is HSlider or node is LineEdit:
			buttons.append(node as Control)
	if buttons.is_empty():
		return
	for i in buttons.size():
		var previous: NodePath = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
		var next: NodePath = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_previous = previous
		buttons[i].focus_next = next
		buttons[i].focus_neighbor_top = previous
		if buttons[i] is BaseButton:
			buttons[i].focus_neighbor_left = previous
		buttons[i].focus_neighbor_bottom = next
		if buttons[i] is BaseButton:
			buttons[i].focus_neighbor_right = next
	buttons[0].grab_focus()


func close() -> void:
	set_process_input(false)
	set_process_unhandled_input(false)
	closed.emit()
	queue_free()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()


static func settings(parent: Node, profile: Profile) -> MenuDialog:
	# Runtime load avoids a circular class dependency: SettingsPanel inherits us.
	var dialog: MenuDialog = (load("res://game/ui/settings_panel.gd") as Script).new() as MenuDialog
	dialog.set("profile", profile)
	parent.add_child(dialog)
	return dialog


static func credits(parent: Node) -> MenuDialog:
	var dialog: MenuDialog = (load("res://game/ui/credits_panel.gd") as Script).new() as MenuDialog
	parent.add_child(dialog)
	return dialog


## Intel archive: the file list on the left (a NEW tag for files not read
## before this visit), the selected file's text on the right. The NEW tags
## are read before the caller marks the archive as read.
static func archive(parent: Node, profile: Profile) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("INTEL ARCHIVE", 36))
	dialog.content.add_child(UiTheme.label("RECOVERED FILES  %02d / %02d" % [profile.lore_pages, Story.FILES.size()], 16, UiTheme.ACCENT, true))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	dialog.content.add_child(body)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 240
	body.add_child(column)
	var index := _scroll(column, 340)
	index.add_theme_constant_override("separation", 6)
	var reader := VBoxContainer.new()
	reader.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reader.add_theme_constant_override("separation", 10)
	body.add_child(reader)
	var heading := UiTheme.title("", 22)
	var text := UiTheme.label("", 16, UiTheme.TEXT)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reader.add_child(heading)
	reader.add_child(text)
	var show := func(i: int) -> void:
		var recovered: bool = i < profile.lore_pages
		heading.text = Story.FILES[i]["title"] if recovered else "FILE %02d / ENCRYPTED" % (i + 1)
		text.text = Story.FILES[i]["text"] if recovered else "Recover this file from supply caches or the Behemoth."
		text.add_theme_color_override("font_color", UiTheme.TEXT if recovered else UiTheme.MUTED)
	for i in Story.FILES.size():
		var recovered: bool = i < profile.lore_pages
		var label: String = Story.FILES[i]["title"] if recovered else "FILE %02d / ENCRYPTED" % (i + 1)
		if recovered and i >= profile.lore_read:
			label += "   NEW"
		var b := UiTheme.button(index, label, show.bind(i))
		b.name = "File%02d" % (i + 1)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 14)
	show.call(0)
	UiTheme.button(dialog.content, "CLOSE", dialog.close, true)
	return dialog

static func controls(parent: Node) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("CONTROLS", 36))
	var list := _scroll(dialog.content, 300)
	list.add_child(UiTheme.label("Your weapon fires automatically at enemies in front of you. Turn your body to choose a target.", 18, UiTheme.ACCENT))
	list.add_child(UiTheme.label("MOVE       WASD / arrows / left stick\nAIM        Right mouse / left trigger (first person)\nBREAKER    Space / A / RB\nABILITY    G / MMB / LB\nSPRINT     Shift / L3\nWEAPONS    1–2 / D-pad\nPAUSE      Esc / Start\nMENUS      Enter / A · Esc / B back\nSUPPLIES   1–3 / X · Y · B\nROUTES     4–5 / LB · RB", 18, UiTheme.TEXT, true))
	UiTheme.button(dialog.content, "BACK", dialog.close, true)
	return dialog


## Armory > START RUN: the archipelago run or an expedition. `on_pick` gets
## &"" (archipelago) or the expedition id. An expedition whose part scenes
## are not built yet is shown disabled.
static func run_choice(parent: Node, on_pick: Callable) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("CHOOSE YOUR RUN", 36))
	var runs: Array = [[&"", "ARCHIPELAGO", "By boat: two routes at every landing, %d islands, the volcano last." % RunContext.ISLAND_COUNT]]
	for id: StringName in Expeditions.INFO:
		runs.append([id, Expeditions.display_name(id).to_upper(), String(Expeditions.INFO[id]["text"])])
	for run: Array in runs:
		var id: StringName = run[0]
		var playable: bool = id == &"" or Expeditions.available(id)
		var text: String = "%s\n%s" % [run[1], run[2] if playable else "Not built yet: its part scenes are missing."]
		var pick := func() -> void:
			dialog.close()
			on_pick.call(id)
		var b := UiTheme.button(dialog.content, text, pick, id == &"")
		b.name = "Run_" + (String(id) if id != &"" else "archipelago")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 96
		b.disabled = not playable
	UiTheme.button(dialog.content, "BACK", dialog.close)
	return dialog


## Development builds (Title > TEST ISLAND): every hand-made island and a
## mission, to play one straight away. `on_pick` gets the island's path and
## the mission id.
static func test_island(parent: Node, on_pick: Callable) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("TEST ISLAND", 36))
	dialog.content.add_child(UiTheme.label("Development builds only: one island, no run around it.", 16, UiTheme.MUTED))
	var mission := OptionButton.new()
	mission.name = "Mission"
	for id: StringName in GameData.MISSIONS:
		mission.add_item("MISSION: " + String(GameData.MISSIONS[id]["name"]).to_upper())
		mission.set_item_metadata(mission.item_count - 1, id)
	dialog.content.add_child(mission)
	var list := _scroll(dialog.content, 300)
	for path in HandmadeIsland.island_paths():
		var b := UiTheme.button(list, path.get_file().get_basename().to_upper(), func() -> void:
			var id: StringName = mission.get_item_metadata(mission.selected)
			dialog.close()
			on_pick.call(path, id))
		b.name = "Island_" + path.get_file().get_basename()
	# Expedition scenes (when built): the whole island takes the mission
	# above; a part always plays its own mission.
	for entry: Dictionary in Expeditions.test_entries():
		var b := UiTheme.button(list, String(entry["label"]), func() -> void:
			var id: StringName = entry["mission"] if entry["mission"] != &"" else mission.get_item_metadata(mission.selected)
			dialog.close()
			on_pick.call(String(entry["path"]), id))
		b.name = "Expedition_" + String(entry["id"])
	UiTheme.button(dialog.content, "BACK", dialog.close, true)
	return dialog


## ABANDON RUN confirmation (pause menu): what you keep and what you lose,
## KEEP FIGHTING focused, and a button that must be held for 1 s.
## B/Esc (or KEEP FIGHTING) goes back to the pause menu.
static func abandon(parent: Node, keep: int, keep_note: String, lose: int, lose_note: String, on_abandon: Callable) -> MenuDialog:
	var dialog := MenuDialog.new()
	dialog.glass = true
	dialog.name = "AbandonDialog"
	parent.add_child(dialog)
	(dialog.content.get_parent() as Control).custom_minimum_size.x = 560
	dialog.content.add_theme_constant_override("separation", 16)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	dialog.content.add_child(head)
	head.add_child(WarningIcon.new())
	var title := ink(UiTheme.title("ABANDON THE RUN?", 38))
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.add_child(title)
	dialog.content.add_child(ink(UiTheme.label("The boat leaves without you. Your build and the extraction bonus are lost; the Intel you earned is kept.", 18)))
	var boxes := HBoxContainer.new()
	boxes.add_theme_constant_override("separation", 12)
	dialog.content.add_child(boxes)
	var sides: Array = [["YOU KEEP", keep, keep_note, UiTheme.SUCCESS, "Keep"], ["YOU LOSE", lose, lose_note, UiTheme.DANGER, "Lose"]]
	for side: Array in sides:
		var box := glass_box(boxes)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		box.add_child(col)
		col.add_child(ink(UiTheme.label(side[0], 13, UiTheme.TEXT_MUTED, true)))
		var number := ink(UiTheme.label("%d INTEL" % side[1], 26, side[3]))
		number.name = side[4]
		number.add_theme_font_override("font", UiTheme.mono_bold_font())
		col.add_child(number)
		col.add_child(ink(UiTheme.label(side[2], 14, UiTheme.TEXT_MUTED)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	dialog.content.add_child(row)
	var stay := UiTheme.button(row, "KEEP FIGHTING", dialog.close, true)
	stay.name = "KeepFighting"
	stay.custom_minimum_size.y = 54
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hold := HoldButton.new()
	hold.name = "HoldToAbandon"
	hold.text = "HOLD TO ABANDON"
	hold.custom_minimum_size.y = 54
	hold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hold.theme_type_variation = &"DangerButton"
	glass_button(hold, true)
	hold.held.connect(func() -> void:
		dialog.close()
		on_abandon.call())
	row.add_child(hold)
	var accept: String = "%s / %s" % [GameInput.prompt(&"ui_accept", false), GameInput.prompt(&"ui_accept", true)]
	var back: String = "%s / %s" % [GameInput.prompt(&"ui_cancel", false), GameInput.prompt(&"ui_cancel", true)]
	var hints := ink(UiTheme.label("[ %s ] HOLD 1 s     [ %s ] BACK" % [accept, back], 14, UiTheme.TEXT_MUTED, true))
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	dialog.content.add_child(hints)
	return dialog


## Dark outline + drop shadow so text reads straight over the game.
static func ink(l: Label, outline: int = 4) -> Label:
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.add_theme_constant_override("shadow_outline_size", outline + 2)
	return l


## Translucent panel (PANEL at GLASS_ALPHA, thin line) inside a glass screen.
static func glass_box(parent: Control, alpha: float = GLASS_ALPHA) -> PanelContainer:
	var box := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UiTheme.PANEL, alpha)
	s.border_color = Color(UiTheme.LINE, 0.9)
	s.set_border_width_all(1)
	s.set_corner_radius_all(UiTheme.RADIUS)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 12
	s.content_margin_bottom = 12
	box.add_theme_stylebox_override("panel", s)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(box)
	return box


## Translucent button states for glass screens: plain buttons get a see-
## through PANEL, danger buttons little more than their outline. Primary
## buttons keep their amber fill: the one action that must pop.
static func glass_button(b: Button, danger: bool = false) -> void:
	var styles: Dictionary = {
		"normal": [Color(UiTheme.DANGER, 0.08) if danger else Color(UiTheme.PANEL, GLASS_ALPHA), UiTheme.DANGER if danger else UiTheme.LINE],
		"hover": [Color(UiTheme.DANGER, 0.2) if danger else Color(UiTheme.PANEL_RAISED, 0.75), UiTheme.DANGER if danger else UiTheme.TEXT],
		"pressed": [Color(UiTheme.DANGER, 0.3) if danger else Color(UiTheme.PANEL, 0.8), UiTheme.DANGER if danger else UiTheme.ACCENT],
	}
	for state: String in styles:
		var s := StyleBoxFlat.new()
		s.bg_color = styles[state][0]
		s.border_color = styles[state][1]
		s.set_border_width_all(2 if danger else 1)
		s.set_corner_radius_all(UiTheme.RADIUS)
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 10
		s.content_margin_bottom = 10
		b.add_theme_stylebox_override(state, s)
	b.add_theme_stylebox_override("hover_pressed", b.get_theme_stylebox("pressed"))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	b.add_theme_constant_override("outline_size", 4)


## A button that fires `held` only after A/Enter or the mouse button is held
## on it for HOLD_TIME without letting go: releasing (or losing focus)
## resets the hold. The fill bar then drains back, but only on screen.
## Used where one mistaken press would cost the whole run.
class HoldButton extends Button:
	signal held

	const HOLD_TIME: float = 1.0
	var progress: float = 0.0  ## 0..1 of the current, unbroken hold
	var _shown: float = 0.0  ## what the bar shows (drains after a release)
	var _holding: bool = false
	var _fill := ColorRect.new()

	func _init() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_fill.name = "Fill"
		_fill.color = Color(UiTheme.DANGER, 0.35)
		_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fill.show_behind_parent = true  # under the text
		add_child(_fill)
		focus_exited.connect(_set_holding.bind(false))

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_set_holding(event.is_pressed())
			accept_event()
		elif event.is_action(&"ui_accept") and not event.is_echo():
			_set_holding(event.is_pressed())
			accept_event()

	func _set_holding(on: bool) -> void:
		_holding = on
		if not on:
			progress = 0.0  # the hold must be one continuous second

	func _process(delta: float) -> void:
		if _holding:
			progress = minf(1.0, progress + delta / HOLD_TIME)
			_shown = progress
			if progress >= 1.0:
				_set_holding(false)
				held.emit()
		else:
			_shown = maxf(0.0, _shown - delta * 3.0)
		_fill.position = Vector2.ZERO
		_fill.size = Vector2(size.x * _shown, size.y)


## Warning triangle (danger colour) drawn in code.
class WarningIcon extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(34, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Color = UiTheme.DANGER
		var tri := PackedVector2Array([Vector2(17, 2), Vector2(32, 28), Vector2(2, 28), Vector2(17, 2)])
		draw_polyline(tri, Color(0, 0, 0, 0.6), 6.0, true)
		draw_polyline(tri, c, 3.0, true)
		draw_line(Vector2(17, 11), Vector2(17, 19), c, 3.0)
		draw_line(Vector2(17, 22), Vector2(17, 25), c, 3.0)


static func _scroll(parent: Control, height: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var navigation := HBoxContainer.new()
	parent.add_child(navigation)
	for direction in [-1, 1]:
		var b := UiTheme.button(navigation, "↑ READ ABOVE" if direction < 0 else "↓ READ BELOW", func() -> void:
			scroll.scroll_vertical += direction * int(height * 0.8))
		b.name = "ScrollUp" if direction < 0 else "ScrollDown"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
	return list
