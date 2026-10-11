extends RefCounted
## Presentation of one perk node; Profile owns all progression and effects.

const Art = preload("res://game/ui/armory_art.gd")


static func create(profile: Profile, node: StringName, state: String, focus: Callable, actions: Callable) -> Button:
	var b := Button.new()
	b.name = "PerkNode_" + String(node)
	b.custom_minimum_size = Vector2(0, 88)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_vertical = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var bg: Color = Color.TRANSPARENT if state == "LOCKED" else (UiTheme.PANEL_RAISED if state == "EQUIPPED" else UiTheme.PANEL)
	var border: Color = UiTheme.SUCCESS if state == "EQUIPPED" else UiTheme.LINE
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBox = UiTheme.card_box(bg, border.lightened(0.25) if style.begins_with("hover") else border, 1, state == "LOCKED")
		if box is MarkedBox:
			(box as MarkedBox).base.bg_color = Color(0.04, 0.1, 0.12, 0.95)
		b.add_theme_stylebox_override(style, box)
	b.pressed.connect(actions.bind(node))
	b.focus_entered.connect(focus.bind(node))
	b.mouse_entered.connect(func() -> void: if not b.has_focus(): b.grab_focus())
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 5
	box.offset_bottom = -5
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	# The button does not lay out its children: grow it to fit the content.
	box.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = maxf(88.0, box.get_combined_minimum_size().y + 10.0))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var tier_label := UiTheme.label("TIER " + GameData.RANK_NAMES[GameData.perk_node_tier(node)], 11, UiTheme.MUTED, true)
	tier_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tier_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(tier_label)
	var tag_colors: Dictionary = {"LOCKED": UiTheme.MUTED, "EQUIPPED": UiTheme.SUCCESS, "OWNED": UiTheme.TEXT, "NEW": UiTheme.ACCENT}
	var tag := UiTheme.label("✓ EQUIPPED" if state == "EQUIPPED" else state, 11, tag_colors[state], true)
	tag.name = "State"
	tag.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(tag)
	var picked: int = profile.perk_option(node)
	var alternatives := HBoxContainer.new()
	alternatives.name = "Alternatives"
	alternatives.add_theme_constant_override("separation", 6)
	alternatives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alternatives.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(alternatives)
	for option in 2:
		var perk: GameData.Perk = GameData.perk_for(node, option, profile.selected_class)
		var on: bool = option == picked and state != "LOCKED"
		var tile := VBoxContainer.new()
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		alternatives.add_child(tile)
		var symbol_row := HBoxContainer.new()
		symbol_row.alignment = BoxContainer.ALIGNMENT_CENTER
		symbol_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(symbol_row)
		symbol_row.add_child(Art.image(perk.id, 24, UiTheme.SUCCESS if on else UiTheme.MUTED))
		if on:
			var tick := Art.image(perk.id, 12, UiTheme.SUCCESS)
			tick.texture = UiTheme.tick_icon()
			symbol_row.add_child(tick)
		var line := UiTheme.label("%s · %s" % ["AB"[option], perk.title if perk != null else "—"], 13, UiTheme.TEXT if on else UiTheme.MUTED)
		line.name = "Option" + "AB"[option]
		line.add_theme_font_override("font", UiTheme.heading_font())
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var fill: StyleBox = UiTheme.card_box(UiTheme.PANEL_RAISED if on else Color.TRANSPARENT, UiTheme.SUCCESS if on else Color.TRANSPARENT, 1 if on else 0)
		fill.content_margin_top = 1
		fill.content_margin_bottom = 1
		fill.content_margin_left = 2
		fill.content_margin_right = 2
		line.add_theme_stylebox_override("normal", fill)
		tile.add_child(line)
	var foot := HBoxContainer.new()
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(foot)
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.add_theme_constant_override("separation", 4)
	pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.add_child(pips)
	for k in range(1, GameData.PERK_MAX_RANK + 1):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(18, 6)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = UiTheme.ACCENT if k <= profile.node_rank(node) else UiTheme.LINE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	var rank: int = profile.node_rank(node)
	var foot_text: String = "REQ. TIER " + GameData.RANK_NAMES[GameData.perk_node_tier(node) - 1] if state == "LOCKED" else ("%d INTEL" % profile.next_rank_cost(node) if rank == 0 else "RANK " + GameData.RANK_NAMES[profile.use_rank(node)])
	var foot_label := UiTheme.label(foot_text, 11, UiTheme.MUTED, true)
	foot_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	foot.add_child(foot_label)
	return b

