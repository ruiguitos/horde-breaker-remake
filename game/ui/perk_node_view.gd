extends RefCounted
## Presentation of one perk node; Profile owns all progression and effects.
## A node is one focusable card, as a file card pinned to the board: the picked alternative's
## name typed large, the other one under it as "or NAME" (each with its A/B letter, for Q/E), and
## a row of rank pips along the bottom:
##   picked + owned  -> teal outline (tick when it is equipped)
##   picked, rank 0  -> light outline, full colour
##   not picked      -> muted
##   locked tier     -> muted, a padlock in place of each alternative's icon
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
	var bg := Dossier.PAPER_DARK if locked else Dossier.PAPER
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = bg.lightened(0.05) if style.begins_with("hover") else bg
		box.border_color = Dossier.LINE.lightened(0.3) if style.begins_with("hover") else Dossier.LINE
		box.set_border_width_all(1)
		box.set_corner_radius_all(3)
		b.add_theme_stylebox_override(style, box)
	b.pressed.connect(actions.bind(node))
	b.focus_entered.connect(focus.bind(node))
	b.mouse_entered.connect(func() -> void: if not b.has_focus(): b.grab_focus())
	var row := VBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8
	row.offset_right = -8
	row.offset_top = 7
	row.offset_bottom = -6
	row.add_theme_constant_override("separation", 5)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	# The button does not lay out its children: grow it to fit the content.
	row.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = maxf(78.0, row.get_combined_minimum_size().y + 13.0))
	var tag := Dossier.label("✓ EQUIPPED" if state == "EQUIPPED" else state, 11, Dossier.MUTED, true)
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
		var on: bool = option == picked
		alternatives.add_child(_alternative(perk, option, on, rank > 0, state == "EQUIPPED", locked))
	if picked == 1:
		alternatives.move_child(alternatives.get_child(1), 0)  # the picked name reads first
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
		pip.color = Dossier.ACCENT if k <= rank else Dossier.LINE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	var cost: int = profile.next_rank_cost(node)
	var count := Dossier.label("%d/%d" % [rank, GameData.PERK_MAX_RANK], 11, Dossier.MUTED, true)
	count.name = "RankCount"
	# One line: a label that wraps in the pips row would shrink to one column wide and grow the node.
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pips.add_child(count)
	if locked:
		# The padlock sits at the end of the pips row: both names keep the card's whole width.
		var padlock := TextureRect.new()
		padlock.name = "Padlock"
		padlock.texture = UiTheme.lock_icon()
		padlock.modulate = Dossier.MUTED
		padlock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		padlock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		padlock.custom_minimum_size = Vector2(13, 13)
		padlock.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
		padlock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(padlock)
	var foot: String = "Requires tier " + GameData.RANK_NAMES[GameData.perk_node_tier(node) - 1] if locked \
		else ("%d Intel" % cost if rank == 0 else "Rank " + GameData.RANK_NAMES[profile.use_rank(node)])
	b.tooltip_text = "%s / %s\n%s · %s" % [names[0], names[1], tag.text, foot]
	return b


## One alternative on one line. The picked one: its letter and its name, typed, with a padlock
## (locked tier) or a tick (equipped) at the end. The other: its letter, "or" and its name, small.
static func _alternative(perk: GameData.Perk, option: int, on: bool, _owned: bool, equipped: bool, locked: bool) -> Control:
	var tile := PanelContainer.new()
	tile.name = "Alternative" + "AB"[option]
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var line_row := HBoxContainer.new()
	line_row.add_theme_constant_override("separation", 5)
	line_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(line_row)
	var tint: Color = Dossier.TEXT if on and not locked else Dossier.MUTED
	var letter := Dossier.label("AB"[option], 10, Dossier.MUTED, true)
	letter.name = "Letter" + "AB"[option]
	letter.autowrap_mode = TextServer.AUTOWRAP_OFF
	letter.visible = false  # kept for tools and tests: the card has no room for it, and the hints name A and B
	line_row.add_child(letter)
	if not on:
		var other := Dossier.label("or", 10, Dossier.MUTED)
		other.autowrap_mode = TextServer.AUTOWRAP_OFF
		other.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line_row.add_child(other)
	# One line, never broken: a name too long for its cell is trimmed with an ellipsis.
	var line := Dossier.label(perk.title.to_upper() if perk != null else "—", 12 if on else 10, tint, on)
	line.name = "Option" + "AB"[option]
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	line.clip_text = true
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_row.add_child(line)
	var mark_texture: Texture2D = UiTheme.tick_icon() if on and equipped else null
	if mark_texture != null:
		var mark := TextureRect.new()
		mark.name = "Mark"
		mark.texture = mark_texture
		mark.modulate = Dossier.SUCCESS
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.custom_minimum_size = Vector2(13, 13)
		mark.size_flags_horizontal = Control.SIZE_SHRINK_END
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line_row.add_child(mark)
	return tile
