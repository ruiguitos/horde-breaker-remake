extends "res://game/states/boat.gd"
## Expedition camp, between two parts of the same island (on foot, no boat):
## the boat's screen and supplies (Field Repairs, Ammo Crate, a card, with
## their RNG order), but no route choice and no briefing. The context
## already points at the next part (RunContext.advance), so the left panel
## shows the expedition's parts and the right one the part ahead.
## It extends boat.gd so the supply rules and the layout live in one place;
## only the content and the framing change.

## What the next objective asks, for missions GameData may not describe yet.
const FALLBACK_TEXT: Dictionary = {
	&"holdout": "Hold the fort's courtyard until the rescue boat arrives, then board it at the pier.",
}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = context.island_seed() + 1
	theme = UiTheme.get_theme()
	_camp_backdrop()
	_make_options()
	var screen := _screen()
	_header(screen, "FIELD CAMP / ON FOOT", "NEXT PART / PART %d OF %d" % [context.island_index + 1, context.island_count()])
	var body := _body(screen)
	var chart := _chart_panel(body)
	var trail := _trail()
	chart.add_child(trail)
	chart.move_child(trail, 0)
	var right := _right_column(body)
	right.add_child(_next_part())
	_supply_row(right, "SUPPLY CACHE / ONE PER CAMP")
	_footer(screen, false)
	_select_supply(_first_useful())
	_supply_target().grab_focus()
	add_child(UiSfx.new())
	add_child(Ambience.create(&"town", -14.0))  # wind on the plateau, not the boat's sea


## Night camp instead of the boat's deck: dark ground and a fire glow.
func _camp_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = Color("0c1012")
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.95, 0.45, 0.12, 0.35))
	gradient.set_color(1, Color(0.95, 0.45, 0.12, 0.0))
	var glow := GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 1.0)
	glow.fill_to = Vector2(0.5, 0.25)
	var rect := TextureRect.new()
	rect.texture = glow
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(rect)


## The expedition's parts as a trail: done (tick), next (amber ring), ahead
## (dashed), with the part names from Expeditions.
func _trail() -> Control:
	var box := VBoxContainer.new()
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	box.add_child(UiTheme.label(Expeditions.display_name(context.expedition).to_upper(), 12, UiTheme.MUTED, true))
	for i in context.expedition_parts.size():
		var part: Dictionary = context.expedition_parts[i]
		var done: bool = i < context.island_index
		var here: bool = i == context.island_index
		if i > 0:
			box.add_child(_trail_link(done or here))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		box.add_child(row)
		var state: RouteMap.Step = RouteMap.Step.DONE if done else (RouteMap.Step.CURRENT if here else RouteMap.Step.AHEAD)
		row.add_child(RouteMap.StepPip.new(state, str(i + 1)))
		var label := UiTheme.label(String(part["name"]).to_upper(), 15, UiTheme.SUCCESS if done else (UiTheme.ACCENT if here else UiTheme.MUTED))
		label.add_theme_font_override("font", UiTheme.mono_bold_font() if here else UiTheme.mono_font())
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		label.name = "Trail_%d" % (i + 1)
		row.add_child(label)
	return box


## Short vertical line between two pips (solid once walked, faint ahead).
func _trail_link(walked: bool) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(26, 14)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var line := ColorRect.new()
	line.color = UiTheme.SUCCESS if walked else UiTheme.LINE
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.position = Vector2(12, 0)
	line.size = Vector2(2, 14)
	holder.add_child(line)
	return holder


## The part ahead: picture, name and what it asks (where the boat shows two
## routes, the camp shows the one way on).
func _next_part() -> Control:
	var plate := PanelContainer.new()
	plate.name = "NextPart"
	plate.size_flags_vertical = Control.SIZE_EXPAND_FILL
	plate.add_theme_stylebox_override("panel", _style(UiTheme.PANEL_RAISED, UiTheme.ACCENT, 2, 12))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	plate.add_child(box)
	var preview := RoutePreview.new()
	preview.biome = context.biome
	if context.is_expedition():
		preview.expedition = context.expedition
		preview.part = context.island_index
	preview.custom_minimum_size.y = PICTURE_HEIGHT
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(preview)
	var tag: String = "FINAL PART" if context.is_last_island() else "NEXT PART"
	box.add_child(UiTheme.label("%s / %d OF %d" % [tag, context.island_index + 1, context.island_count()], 12, UiTheme.MUTED, true))
	var heading := UiTheme.title(context.part_name().to_upper(), 32)
	heading.name = "PartName"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	var text: String = String(GameData.MISSIONS.get(context.mission, {}).get("text", FALLBACK_TEXT.get(context.mission, "")))
	box.add_child(_mission_lines(context.mission, text))
	box.add_child(HSeparator.new())
	box.add_child(_tagged_line("● ON FOOT", UiTheme.TEXT_MUTED, "no route modifiers; your HP, level and cards carry over"))
	return plate


func _land_text() -> String:
	return "CONTINUE TO " + context.part_name().to_upper()


func _can_land() -> bool:
	return _supply_ready()


## No briefing on foot: apply the supply and go straight on to the next part.
func _land_now() -> void:
	if _can_land() and not _applied and not _exit_sent and not is_instance_valid(_exit_dialog):
		_apply_supply()
		land_requested.emit()
