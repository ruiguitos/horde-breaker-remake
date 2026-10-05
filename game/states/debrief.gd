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
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	var islands: int = context.island_index + (1 if context.won else 0)
	label.text = "%s\n\nIslands cleared: %d / %d\nTime %d s · Kills %d · Headshots %d · Level %d\n\nIntel earned: %d\nTotal Intel: %d   (runs %d, extractions %d, best kills %d)\n\nEnter / A: armory" % [
		"EXTRACTED — RUN COMPLETE!" if context.won else "MISSION FAILED",
		islands, RunContext.ISLAND_COUNT, int(context.time_alive), context.kills, context.headshots,
		context.level, context.intel, profile.intel, profile.runs, profile.extractions, profile.best_kills]
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	var go: bool = (event is InputEventKey and event.pressed and not event.echo
		and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_R, KEY_SPACE])
	go = go or (event is InputEventJoypadButton and event.pressed
		and event.button_index in [JOY_BUTTON_A, JOY_BUTTON_START])
	if go:
		new_run_requested.emit()
