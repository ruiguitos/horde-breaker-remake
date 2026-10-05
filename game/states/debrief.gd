extends Control
## End of run: results, Intel earned and the saved profile totals.

signal new_run_requested

var context: RunContext
var profile: Profile


func _ready() -> void:
	# The parent is a plain Node, so fill the window explicitly.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = UiTheme.centered_panel(self, 620)
	var heading: Label = UiTheme.title("RUN COMPLETE — EXTRACTED" if context.won else "MISSION FAILED", 34)
	heading.add_theme_color_override("font_color", Color(0.4, 0.95, 0.5) if context.won else UiTheme.DANGER)
	box.add_child(heading)
	var islands: int = context.island_index + (1 if context.won else 0)
	_row(box, "Islands cleared", "%d / %d" % [islands, RunContext.ISLAND_COUNT])
	_row(box, "Time", "%d:%02d" % [int(context.time_alive) / 60, int(context.time_alive) % 60])
	_row(box, "Kills  ·  Headshots", "%d  ·  %d" % [context.kills, context.headshots])
	_row(box, "Level reached", str(context.level))
	_row(box, "Intel earned", "+%d" % context.intel, UiTheme.ACCENT)
	_row(box, "Total Intel", str(profile.intel))
	if context.lore_found > 0:
		_row(box, "Intel files recovered", "+%d  (read them in the Armory)" % context.lore_found, UiTheme.ACCENT)
	var meta := Label.new()
	meta.text = "Runs %d · Extractions %d · Best kills %d" % [profile.runs, profile.extractions, profile.best_kills]
	meta.add_theme_color_override("font_color", UiTheme.MUTED)
	meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(meta)
	var back := Button.new()
	back.text = "BACK TO ARMORY (Enter)"
	back.custom_minimum_size = Vector2(0, 50)
	back.pressed.connect(func() -> void: new_run_requested.emit())
	box.add_child(back)
	back.grab_focus()
	add_child(UiSfx.new())


func _row(parent: Control, key: String, value: String, color: Color = UiTheme.TEXT) -> void:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_color_override("font_color", UiTheme.MUTED)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.add_theme_color_override("font_color", color)
	v.add_theme_font_size_override("font_size", 22)
	row.add_child(v)
	parent.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventKey and event.pressed and not event.echo
		and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_R, KEY_SPACE])
	go = go or (event is InputEventJoypadButton and event.pressed
		and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START])
	if go:
		new_run_requested.emit()
