extends RefCounted
## Presentation of one perk node; Profile owns all progression and effects.
## A node is one focusable card holding its two alternatives stacked, each on one line
## (A/B letter, icon, name), and a row of rank pips along the bottom:
##   picked + owned  -> teal outline (tick when it is equipped)
##   picked, rank 0  -> light outline, full colour
##   not picked      -> muted
##   locked tier     -> muted, small padlock on each alternative
## The state word (EQUIPPED / OWNED / NEW / LOCKED) stays in a hidden
## "State" label and in the tooltip, for tests and screen readers.

const Art = preload("res://game/ui/armory_art.gd")

const ICON_SIZE := 18


static func create(profile: Profile, node: StringName, state: String, focus: Callable, actions: Callable) -> Button:
	var b := Button.new()
	b.name = "PerkNode_" + String(node)
	b.custom_minimum_size = Vector2(0, 78)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var locked: bool = state == "LOCKED"
	var bg := Color(0.035, 0.085, 0.1, 0.78 if locked else 0.92)
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = bg.lightened(0.05) if style.begins_with("hover") else bg
		box.border_color = UiTheme.LINE.lightened(0.3) if style.begins_with("hover") else UiTheme.LINE
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		b.add_theme_stylebox_override(style, box)
	b.pressed.connect(actions.bind(node))
	b.focus_entered.connect(focus.bind(node))
	b.mouse_entered.connect(func() -> void: if not b.has_focus(): b.grab_focus())
	var row := VBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 3
	row.offset_right = -5
	row.offset_top = 3
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 3)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	# The button does not lay out its children: grow it to fit the content.
	row.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = maxf(78.0, row.get_combined_minimum_size().y + 6.0))
	var tag := UiTheme.label("✓ EQUIPPED" if state == "EQUIPPED" else state, 11, UiTheme.MUTED, true)
	tag.name = "State"
	tag.visible = false
	row.add_child(tag)
	var picked: int = profile.perk_option(node)
	var rank: int = profile.node_rank(node)
	var alternatives := VBoxContainer.new()
	alternatives.name = "Alternatives"
	alternatives.add_theme_constant_override("separation", 2)
	alternatives.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alternatives.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(alternatives)
	var names: Array[String] = []
	for option in 2:
		var perk: GameData.Perk = GameData.perk_for(node, option, profile.selected_class)
		names.append(perk.title if perk != null else "—")
		var on: bool = option == picked and not locked
		alternatives.add_child(_alternative(perk, option, on, rank > 0, state == "EQUIPPED", locked))
	# The rank pips run along the bottom of the node, in one line with the rank count.
	var pips := HBoxContainer.new()
	pips.name = "Pips"
	pips.alignment = BoxContainer.ALIGNMENT_BEGIN
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pips)
	for k in range(1, GameData.PERK_MAX_RANK + 1):
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(9, 9)
		pip.color = UiTheme.ACCENT if k <= rank else UiTheme.LINE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	var cost: int = profile.next_rank_cost(node)
	var count := UiTheme.label("%d/%d" % [rank, GameData.PERK_MAX_RANK], 11, UiTheme.MUTED, true)
	count.name = "RankCount"
	# One line: a label that wraps in the pips row would shrink to one column wide and grow the node.
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pips.add_child(count)
	var foot: String = "Requires tier " + GameData.RANK_NAMES[GameData.perk_node_tier(node) - 1] if locked \
		else ("%d Intel" % cost if rank == 0 else "Rank " + GameData.RANK_NAMES[profile.use_rank(node)])
	b.tooltip_text = "%s / %s\n%s · %s" % [names[0], names[1], tag.text, foot]
	return b


## One alternative: its A/B letter, icon and name on one line, inside a box that marks the pick.
static func _alternative(perk: GameData.Perk, option: int, on: bool, owned: bool, equipped: bool, locked: bool) -> Control:
	var tile := PanelContainer.new()
	tile.name = "Alternative" + "AB"[option]
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := StyleBoxFlat.new()
	box.set_corner_radius_all(2)
	box.content_margin_left = 3
	box.content_margin_right = 3
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	box.bg_color = Color.TRANSPARENT
	if on and owned:
		box.bg_color = Color(UiTheme.SUCCESS, 0.1)
		box.border_color = UiTheme.SUCCESS
		box.set_border_width_all(2)
	elif on:
		box.border_color = UiTheme.LINE.lightened(0.25)
		box.set_border_width_all(1)
	tile.add_theme_stylebox_override("panel", box)
	var line_row := HBoxContainer.new()
	line_row.add_theme_constant_override("separation", 4)
	line_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(line_row)
	var tint: Color = UiTheme.TEXT if on else (Color(UiTheme.MUTED, 0.55) if locked else UiTheme.MUTED)
	var letter := UiTheme.label("AB"[option], 12, tint, true)
	letter.name = "Letter" + "AB"[option]
	letter.autowrap_mode = TextServer.AUTOWRAP_OFF
	line_row.add_child(letter)
	line_row.add_child(Art.image(perk.id if perk != null else &"", ICON_SIZE, tint))
	# One line, never broken: a name too long for its cell is trimmed with an ellipsis.
	var line := UiTheme.label(perk.title.to_upper() if perk != null else "—", 13, tint)
	line.name = "Option" + "AB"[option]
	line.add_theme_font_override("font", UiTheme.heading_font())
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.clip_text = true
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_row.add_child(line)
	# Marks: tick on the equipped pick, padlock on locked tiers. At the end of the line, so it
	# takes its own width and never covers the name.
	var mark_texture: Texture2D = UiTheme.tick_icon() if on and equipped else (UiTheme.lock_icon() if locked else null)
	if mark_texture != null:
		var mark := TextureRect.new()
		mark.name = "Mark"
		mark.texture = mark_texture
		mark.modulate = UiTheme.SUCCESS if on else UiTheme.MUTED
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.custom_minimum_size = Vector2(12, 12)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_END
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_row.add_child(mark)
	return tile
