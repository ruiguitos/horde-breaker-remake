extends "res://game/states/boat.gd"
## Expedition camp, between two parts of the same island (on foot, no boat):
## the boat's supplies (Field Repairs, Ammo Crate, a card) with their RNG
## order, but no route choice and no briefing. The context already points at
## the next part (RunContext.advance), so this screen shows where you go.
## It extends boat.gd so the supply rules live in one place; only the layout
## and the framing change.

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
	var screen := UiTheme.screen(self)
	UiTheme.header(screen, "FIELD CAMP / PART %02d OF %02d" % [context.island_index + 1, context.island_count()])
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	screen.add_child(body)
	body.add_child(_trail())
	body.add_child(_next_part())
	_status = UiTheme.label("", 16, UiTheme.MUTED, true)
	screen.add_child(_status)
	_land = UiTheme.button(screen, "MARCH ON   →", _land_now, true)
	_land.name = "MarchOn"
	_land.disabled = true
	UiTheme.hints(screen, "[ 1–3 / X–Y–B ] SUPPLY     [ ENTER / A ] MARCH ON")
	_refresh_status()
	_show_supplies("FIELD CAMP / SUPPLY CACHE", "One cache per camp. The next stretch is on foot.")
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


## The expedition's parts: done, next, still ahead.
func _trail() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 320
	UiTheme.section(box, Expeditions.display_name(context.expedition).to_upper() + " / ON FOOT")
	for i in context.expedition_parts.size():
		var part: Dictionary = context.expedition_parts[i]
		var mark: String = "✓" if i < context.island_index else ("›" if i == context.island_index else "·")
		var color: Color = UiTheme.SUCCESS if i < context.island_index else (UiTheme.ACCENT if i == context.island_index else UiTheme.MUTED)
		var row := UiTheme.label("%s %d  %s" % [mark, i + 1, String(part["name"]).to_upper()], 18, color, true)
		row.name = "Trail_%d" % (i + 1)
		box.add_child(row)
	return box


## Where the next part is and what it asks.
func _next_part() -> Control:
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	plate.add_child(box)
	var tag: String = "FINAL PART" if context.is_last_island() else "NEXT PART"
	box.add_child(UiTheme.label("%s / %02d" % [tag, context.island_index + 1], 16, UiTheme.MUTED, true))
	var heading := UiTheme.title(context.part_name().to_upper(), 36)
	heading.name = "PartName"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(heading)
	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("OBJECTIVE", 16, UiTheme.MUTED, true))
	var mission := UiTheme.title(Expeditions.mission_name(context.mission).to_upper(), 24)
	mission.name = "Mission"
	box.add_child(mission)
	var text: String = String(GameData.MISSIONS.get(context.mission, {}).get("text", FALLBACK_TEXT.get(context.mission, "")))
	var about := UiTheme.label(text, 16)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(about)
	return plate


func _focus_after_supply() -> void:
	pass  # no routes: _update_land focuses MARCH ON


func _can_land() -> bool:
	return _picked


## No briefing on foot: straight on to the next part.
func _land_now() -> void:
	if _can_land():
		land_requested.emit()


func _refresh_status() -> void:
	var stage: String = "READY TO MARCH" if _can_land() else "01 / CHOOSE YOUR SUPPLY"
	_status.text = "HP %d/%d / LEVEL %d / KILLS %d / INTEL %d   ·   %s" % [int(context.hp), int(context.max_hp), context.level, context.kills, context.intel, stage]
