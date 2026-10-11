extends Control
## Native equipment screen; progression remains owned by Profile.

## `expedition`: &"" = the archipelago run, else an Expeditions.ALL id.
signal start_requested(expedition: StringName)
signal back_requested

var profile: Profile
var _category: String = "CLASS"
var _content: VBoxContainer
var _summary: VBoxContainer
var _summary_footer: VBoxContainer
var _nav: Array[Button] = []
var _start_button: Button
var _dialog: MenuDialog
var _hints: HBoxContainer
## Perk tree: node buttons by node id, and the node shown in the detail.
var _perk_buttons: Dictionary = {}
var _perk_focus: StringName = &"combat_1"
## A migration notice (e.g. Demolitions removed from a Vanguard), shown
## while the Armory is open.
var _notice: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	UiTheme.backdrop(self)
	var screen := UiTheme.screen(self)
	UiTheme.header(screen, "ARMORY / CONTRACTOR EQUIPMENT")
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	screen.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 160
	body.add_child(nav)
	for category in ["CLASS", "WEAPONS", "PERKS"]:
		var b := UiTheme.button(nav, category + "   ›", _select_category.bind(category))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		_nav.append(b)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(gap)
	UiTheme.button(nav, "INTEL ARCHIVE", _archive)
	UiTheme.button(nav, "MAIN MENU", func() -> void: back_requested.emit())
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	body.add_child(VSeparator.new())
	var summary_column := VBoxContainer.new()
	summary_column.custom_minimum_size.x = 272
	body.add_child(summary_column)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	summary_column.add_child(scroll)
	_summary = VBoxContainer.new()
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_summary)
	_summary_footer = VBoxContainer.new()
	summary_column.add_child(_summary_footer)
	_hints = HBoxContainer.new()
	_hints.name = "Hints"
	_hints.alignment = BoxContainer.ALIGNMENT_END
	_hints.add_theme_constant_override("separation", 18)
	screen.add_child(_hints)
	_notice = profile.perk_notice
	profile.perk_notice = ""
	if _notice != "":
		_category = "PERKS"
	_rebuild()
	_start_button.grab_focus()
	add_child(UiSfx.new())


func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _select_category(category: String) -> void:
	_category = category
	_rebuild()


func _rebuild() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_name: String = String(focused.name) if focused != null else ""
	_clear(_content)
	_clear(_summary)
	_clear(_summary_footer)
	for i in _nav.size():
		_nav[i].theme_type_variation = &"PrimaryButton" if ["CLASS", "WEAPONS", "PERKS"][i] == _category else &""
	match _category:
		"CLASS": _classes()
		"WEAPONS": _weapons()
		"PERKS": _perks()
	# The perk detail is denser than the loadout summary.
	if _category == "PERKS":
		_summary.add_theme_constant_override("separation", 6)
	else:
		_summary.remove_theme_constant_override("separation")
	if _category == "PERKS":
		_perk_detail()
		_start_button = UiTheme.button(_summary_footer, "START RUN   →", _start, true)
		_start_button.name = "StartRun"
	else:
		_loadout()
	_build_hints()
	if focus_name != "":
		call_deferred("_restore_focus", focus_name)


func _restore_focus(focus_name: String) -> void:
	for node in find_children(focus_name, "Button", true, false):
		var candidate := node as Button
		if candidate.is_visible_in_tree() and not candidate.disabled:
			candidate.grab_focus()
			return
	# A perk action that is gone (e.g. max rank): back to its node.
	if _category == "PERKS" and _perk_buttons.has(_perk_focus):
		(_perk_buttons[_perk_focus] as Button).grab_focus()


## Control hints with the platform's icons (InputIcons); the perk tree
## adds its node / A-B / actions controls.
func _build_hints() -> void:
	_clear(_hints)
	if _category == "PERKS":
		UiTheme.icon_hint(_hints, [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT],
			["joy:%d" % JOY_BUTTON_DPAD_UP, "joy:%d" % JOY_BUTTON_DPAD_DOWN, "joy:%d" % JOY_BUTTON_DPAD_LEFT, "joy:%d" % JOY_BUTTON_DPAD_RIGHT], "NODES")
		UiTheme.icon_hint(_hints, [KEY_Q, KEY_E], ["joy:%d" % JOY_BUTTON_LEFT_SHOULDER, "joy:%d" % JOY_BUTTON_RIGHT_SHOULDER], "SWITCH A ↔ B")
	UiTheme.icon_hint(_hints, [KEY_ENTER], ["joy:%d" % JOY_BUTTON_A], "ACTIONS" if _category == "PERKS" else "SELECT")
	UiTheme.icon_hint(_hints, [KEY_ESCAPE], ["joy:%d" % JOY_BUTTON_B], "BACK")


func _classes() -> void:
	var info: Dictionary = GameData.CLASS_INFO[profile.selected_class]
	_content.add_child(UiTheme.label("SELECTED CLASS", 16, UiTheme.MUTED, true))
	var heading := UiTheme.title(String(info["name"]).to_upper(), 40)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(heading)
	var hero := HBoxContainer.new()
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(hero)
	# 3D turntable of the class's model (the one you play on the island).
	var portrait := ClassPreview.create(profile.selected_class)
	portrait.name = "ClassPreview"
	portrait.custom_minimum_size = Vector2(200, 280)
	portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero.add_child(portrait)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 180
	detail.alignment = BoxContainer.ALIGNMENT_CENTER
	hero.add_child(detail)
	detail.add_child(UiTheme.label("CLASS ABILITY / G", 16, UiTheme.MUTED, true))
	detail.add_child(UiTheme.title(String(info["ability"]).to_upper(), 24))
	detail.add_child(UiTheme.label(String(info["text"]), 16))
	detail.add_child(HSeparator.new())
	detail.add_child(UiTheme.label("Steady lines.\nStronger teams.\nMore island tomorrows.", 16, UiTheme.MUTED, true))
	var choices := HBoxContainer.new()
	_content.add_child(choices)
	for id in GameData.CLASSES:
		var class_info: Dictionary = GameData.CLASS_INFO[id]
		var owned: bool = profile.unlocked_classes.has(id)
		var selected: bool = profile.selected_class == id
		var status: String = "SELECTED" if selected else ("SELECT" if owned else "%d INTEL" % int(class_info["cost"]))
		var b := UiTheme.button(choices, String(class_info["name"]).to_upper() + "\n" + status, _choose_class.bind(id))
		b.name = "Class_" + String(id)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		b.disabled = not owned and profile.intel < int(class_info["cost"])
		if selected:
			b.theme_type_variation = &"SelectedButton"


func _choose_class(id: StringName) -> void:
	if not profile.unlocked_classes.has(id) and not profile.buy_class(id):
		return
	profile.selected_class = id
	profile.sync_perks_to_class()  # Breaker III follows the class
	_act(true)


func _scroll_list() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	_content.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func _weapons() -> void:
	_content.add_child(UiTheme.title("WEAPONS", 36))
	_content.add_child(UiTheme.label("Equip one primary and one secondary. Unlocking keeps the weapon permanently.", 16, UiTheme.MUTED))
	var list := _scroll_list()
	for weapon in GameData.weapons():
		var card := UiTheme.panel(list)
		card.add_child(UiTheme.title(weapon.display_name.to_upper(), 22))
		card.add_child(UiTheme.label("PRIMARY" if weapon.primary else "SECONDARY", 13, UiTheme.ACCENT, true))
		card.add_child(UiTheme.label("%d DAMAGE / %.1f SHOTS PER SECOND / %d M" % [int(weapon.damage), weapon.fire_rate, int(weapon.range_m)], 16, UiTheme.MUTED, true))
		card.add_child(UiTheme.label(weapon.role, 16))
		var cost: int = maxi(0, GameData.weapon_cost(weapon.id))
		var owned: bool = cost == 0 or profile.unlocked_weapons.has(weapon.id)
		var selected: bool = weapon.id in profile.weapon_loadout()
		var b := UiTheme.button(card, "EQUIPPED" if selected else "EQUIP" if owned else "UNLOCK / %d INTEL" % cost, _choose_weapon.bind(weapon.id))
		b.name = "Weapon_" + String(weapon.id)
		b.disabled = selected or not owned and profile.intel < cost
		if selected:
			b.theme_type_variation = &"SelectedButton"


func _choose_weapon(id: StringName) -> void:
	if not profile.owns_weapon(id) and not profile.buy_weapon(id):
		return
	_act(profile.select_weapon(id))


## PERKS: the tree (docs/design/CARDS_WEAPONS_PERKS.md §F2). Three linked
## columns of nodes; each node shows A/B, rank pips and its state. The
## focused node's detail (benefit, trade-off, rank and the actions) takes
## the summary column. D-pad moves between nodes, LB/RB (Q/E) switch A/B,
## A opens the actions, B goes back to the tree.
const BRANCH_COLORS: Dictionary = {&"combat": UiTheme.INFO, &"survival": UiTheme.SUCCESS, &"breaker": UiTheme.ACCENT}
const BRANCH_SHAPES: Dictionary = {&"combat": "●", &"survival": "■", &"breaker": "◆"}


func _perks() -> void:
	var top := HBoxContainer.new()
	_content.add_child(top)
	var heading := UiTheme.title("PERKS", 36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var status := UiTheme.label("INTEL %d   SLOTS %d / %d" % [profile.intel, profile.equipped_perks.size(), profile.slots], 15, UiTheme.TEXT, true)
	status.name = "PerkStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(status)
	if _notice != "":
		var notice := UiTheme.label(_notice, 14, UiTheme.DANGER)
		notice.name = "PerkNotice"
		_content.add_child(notice)
	var grid := HBoxContainer.new()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 12)
	_content.add_child(grid)
	_perk_buttons.clear()
	for branch in GameData.PERK_BRANCHES:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		grid.add_child(column)
		column.add_child(UiTheme.label("%s %s" % [BRANCH_SHAPES[branch], String(branch).to_upper()], 13, BRANCH_COLORS[branch], true))
		for tier in range(1, GameData.PERK_TIERS + 1):
			var link := ColorRect.new()
			link.color = UiTheme.LINE
			link.custom_minimum_size = Vector2(2, 6 if tier == 1 else 12)
			link.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			link.mouse_filter = Control.MOUSE_FILTER_IGNORE
			column.add_child(link)
			column.add_child(_perk_node(GameData.perk_node(branch, tier)))
	# D-pad / arrows: up/down inside a column, left/right across tiers.
	for node: StringName in _perk_buttons:
		var b: Button = _perk_buttons[node]
		var branch_i: int = GameData.PERK_BRANCHES.find(GameData.perk_node_branch(node))
		var tier: int = GameData.perk_node_tier(node)
		for dir: Array in [["focus_neighbor_left", -1, 0], ["focus_neighbor_right", 1, 0], ["focus_neighbor_top", 0, -1], ["focus_neighbor_bottom", 0, 1]]:
			var bi: int = branch_i + int(dir[1])
			var ti: int = tier + int(dir[2])
			if bi >= 0 and bi < GameData.PERK_BRANCHES.size() and ti >= 1 and ti <= GameData.PERK_TIERS:
				b.set(dir[0], b.get_path_to(_perk_buttons[GameData.perk_node(GameData.PERK_BRANCHES[bi], ti)]))
	var bottom := HBoxContainer.new()
	_content.add_child(bottom)
	var cost: int = profile.next_slot_cost()
	if cost > 0:
		var slot := UiTheme.button(bottom, "UNLOCK SLOT %d / %d INTEL" % [profile.slots + 1, cost], func() -> void: _act(profile.buy_slot()))
		slot.name = "PerkSlot"
		slot.add_theme_font_size_override("font_size", 18)
		slot.custom_minimum_size.y = 40
		slot.disabled = profile.intel < cost
	else:
		bottom.add_child(UiTheme.label("ALL PERK SLOTS UNLOCKED", 13, UiTheme.MUTED, true))


## One node of the tree: a focusable button holding the tier, its state,
## both alternatives (the picked one filled) and the rank pips.
func _perk_node(node: StringName) -> Button:
	var b := Button.new()
	b.name = "PerkNode_" + String(node)
	b.custom_minimum_size = Vector2(0, 96)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var state: String = _node_state(node)
	var bg: Color = Color.TRANSPARENT if state == "LOCKED" else (UiTheme.PANEL_RAISED if state == "EQUIPPED" else UiTheme.PANEL)
	var border: Color = UiTheme.SUCCESS if state == "EQUIPPED" else UiTheme.LINE
	for style in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box: StyleBox = UiTheme.card_box(bg, border.lightened(0.25) if style.begins_with("hover") else border, 1, state == "LOCKED")
		b.add_theme_stylebox_override(style, box)
	b.pressed.connect(_open_perk_actions.bind(node))
	b.focus_entered.connect(_focus_perk.bind(node))
	b.mouse_entered.connect(func() -> void: if not b.has_focus(): b.grab_focus())
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_right = -10
	box.offset_top = 7
	box.offset_bottom = -7
	box.add_theme_constant_override("separation", 3)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	# The button does not lay out its children: grow it to fit the content.
	box.minimum_size_changed.connect(func() -> void: b.custom_minimum_size.y = maxf(96.0, box.get_combined_minimum_size().y + 14.0))
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
	for option in 2:
		var perk: GameData.Perk = GameData.perk_for(node, option, profile.selected_class)
		var on: bool = option == picked and state != "LOCKED"
		var line := UiTheme.label("%s · %s" % ["AB"[option], perk.title if perk != null else "—"], 15, UiTheme.ON_ACCENT if on else UiTheme.MUTED)
		line.name = "Option" + "AB"[option]
		line.add_theme_font_override("font", UiTheme.heading_font())
		line.autowrap_mode = TextServer.AUTOWRAP_OFF
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var fill: StyleBox = UiTheme.card_box(UiTheme.ACCENT if on else Color.TRANSPARENT, UiTheme.ACCENT if on else Color.TRANSPARENT, 1 if on else 0)
		fill.content_margin_top = 1
		fill.content_margin_bottom = 1
		fill.content_margin_left = 6
		line.add_theme_stylebox_override("normal", fill)
		box.add_child(line)
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
	_perk_buttons[node] = b
	return b


## LOCKED (the tier above has no rank I), NEW (buyable, rank 0), OWNED or
## EQUIPPED. Locked nodes stay focusable to read their requirement.
func _node_state(node: StringName) -> String:
	if profile.equipped_in(node) != &"":
		return "EQUIPPED"
	if profile.node_rank(node) > 0:
		return "OWNED"
	return "LOCKED" if profile.rank_problem(node).begins_with("Requires") else "NEW"


func _focus_perk(node: StringName) -> void:
	if _perk_focus == node and _summary.get_child_count() > 0:
		return
	_perk_focus = node
	_clear(_summary)
	_perk_detail()


## A on a node: focus its first available action (upgrade, else equip).
func _open_perk_actions(node: StringName) -> void:
	_focus_perk(node)
	for action_name in ["PerkUpgrade", "PerkEquip", "PerkUseRank"]:
		var action := _summary.find_child(action_name, true, false) as Button
		if action != null and not action.disabled:
			action.grab_focus()
			return


## Detail panel of the focused node, in the summary column.
func _perk_detail() -> void:
	var node: StringName = _perk_focus
	var branch: StringName = GameData.perk_node_branch(node)
	var tier: int = GameData.perk_node_tier(node)
	var rank: int = profile.node_rank(node)
	_summary.add_child(UiTheme.label("%s %s · TIER %s" % [BRANCH_SHAPES[branch], String(branch).to_upper(), GameData.RANK_NAMES[tier]], 12, BRANCH_COLORS[branch], true))
	var options := VBoxContainer.new()
	options.add_theme_constant_override("separation", 4)
	_summary.add_child(options)
	var picked: int = profile.perk_option(node)
	for option in 2:
		var alt: GameData.Perk = GameData.perk_for(node, option, profile.selected_class)
		var ob := UiTheme.button(options, "%s · %s" % ["AB"[option], alt.title.to_upper() if alt != null else "—"], _pick_option.bind(node, option))
		ob.name = "PerkOption_" + "AB"[option]
		ob.alignment = HORIZONTAL_ALIGNMENT_LEFT
		ob.custom_minimum_size.y = 28
		ob.add_theme_font_size_override("font_size", 16)
		ob.clip_text = true
		ob.tooltip_text = "Switching A ↔ B is free, in the armory only. Ranks belong to the node."
		UiTheme.set_selected(ob, option == picked)
	var perk: GameData.Perk = profile.perk_choice(node)
	if perk == null:
		return
	if perk.class_filter != &"":
		_summary.add_child(UiTheme.label("%s ONLY · CLASS VARIANT" % String(GameData.CLASS_INFO[perk.class_filter]["name"]).to_upper(), 11, UiTheme.MUTED, true))
	_summary.add_child(UiTheme.label(perk.description, 14))
	var shown: int = maxi(1, profile.use_rank(node))
	var effects := VBoxContainer.new()
	effects.name = "PerkEffects"
	effects.add_theme_constant_override("separation", 2)
	_summary.add_child(effects)
	var suffix: String = " (%s)" % GameData.RANK_NAMES[shown]
	effects.add_child(UiTheme.label("▲ " + GameData.perk_text(perk.benefit, perk.value(shown)) + suffix, 13, UiTheme.SUCCESS))
	if perk.benefit_2 != "":
		effects.add_child(UiTheme.label("▲ " + GameData.perk_text(perk.benefit_2, perk.value_2(shown)) + suffix, 13, UiTheme.SUCCESS))
	effects.add_child(UiTheme.label("▼ " + GameData.perk_text(perk.penalty, perk.cost_value(shown)) + suffix, 13, UiTheme.DANGER))
	var cost: int = profile.next_rank_cost(node)
	var rank_row := HBoxContainer.new()
	_summary.add_child(rank_row)
	var rank_text: String = "RANK III · MAX" if cost < 0 else "RANK %s → %s" % [GameData.RANK_NAMES[rank], GameData.RANK_NAMES[rank + 1]]
	var rank_label := UiTheme.label(rank_text, 13, UiTheme.TEXT, true)
	rank_label.name = "PerkRank"
	rank_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_child(rank_label)
	if cost > 0:
		var price := UiTheme.label("%d INTEL" % cost, 13, UiTheme.ACCENT, true)
		price.autowrap_mode = TextServer.AUTOWRAP_OFF
		rank_row.add_child(price)
	var problem: String = profile.rank_problem(node)
	if problem != "" and problem != "Max rank":
		var why := UiTheme.label(problem, 13, UiTheme.DANGER, true)
		why.name = "PerkRequirement"
		_summary.add_child(why)
	if cost > 0:
		var upgrade_text: String = "UNLOCK RANK I · %d" % cost if rank == 0 else "UPGRADE TO %s · %d" % [GameData.RANK_NAMES[rank + 1], cost]
		var upgrade := UiTheme.button(_summary, upgrade_text, func() -> void: _act(profile.buy_rank(node)), true)
		upgrade.name = "PerkUpgrade"
		upgrade.custom_minimum_size.y = 38
		upgrade.add_theme_font_size_override("font_size", 19)
		upgrade.disabled = problem != ""
	var equipped: bool = profile.equipped_in(node) != &""
	var full: bool = not equipped and profile.equipped_perks.size() >= profile.slots
	var equip_text: String = "✓ EQUIPPED · REMOVE" if equipped else ("SLOTS FULL" if full and rank > 0 else "EQUIP")
	var equip := UiTheme.button(_summary, equip_text, func() -> void: _act(profile.toggle_equip_node(node)))
	equip.name = "PerkEquip"
	equip.custom_minimum_size.y = 34
	equip.add_theme_font_size_override("font_size", 17)
	equip.disabled = not equipped and (rank == 0 or full)
	if rank >= 2:
		var use := UiTheme.button(_summary, "USE RANK %s (FREE)" % GameData.RANK_NAMES[profile.use_rank(node) - 1 if profile.use_rank(node) > 1 else rank],
			func() -> void: _act(profile.cycle_use_rank(node)))
		use.name = "PerkUseRank"
		use.custom_minimum_size.y = 30
		use.add_theme_font_size_override("font_size", 15)


func _pick_option(node: StringName, option: int) -> void:
	if profile.perk_option(node) != option:
		_act(profile.switch_option(node))


## LB/RB (Q/E) on the tree or the detail: switch the focused node A <-> B.
func _switch_focused_perk() -> void:
	if _perk_focus != &"":
		_act(profile.switch_option(_perk_focus))


func _perk_actions_focused() -> bool:
	var focus := get_viewport().gui_get_focus_owner()
	return focus != null and _summary.is_ancestor_of(focus)


func _loadout() -> void:
	UiTheme.section(_summary, "LOADOUT SUMMARY")
	var row := HBoxContainer.new()
	_summary.add_child(row)
	var threat := UiTheme.label("THREAT LEVEL", 16, UiTheme.MUTED, true)
	threat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(threat)
	var value := UiTheme.label("%02d" % profile.threat, 24, UiTheme.TEXT, true)
	value.custom_minimum_size.x = 32
	row.add_child(value)
	var levels := HBoxContainer.new()
	_summary.add_child(levels)
	for t in range(1, GameData.MAX_THREAT + 1):
		var b := UiTheme.button(levels, "%02d" % t, func() -> void:
			profile.threat = t
			_act(true))
		b.name = "Threat_%d" % t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = t > profile.max_threat
		b.tooltip_text = "Extract on your highest Threat to unlock the next level."
		if t == profile.threat:
			b.theme_type_variation = &"SelectedButton"
	_summary.add_child(UiTheme.label("INTEL MULTIPLIER / ×%.2f" % GameData.threat_intel(profile.threat), 16, UiTheme.MUTED, true))
	_summary.add_child(HSeparator.new())
	_summary.add_child(UiTheme.label("INTEL  %d" % profile.intel, 28, UiTheme.TEXT, true))
	for id in profile.weapon_loadout():
		var weapon: GameData.Weapon = GameData.weapon(id)
		_summary.add_child(UiTheme.label(("PRIMARY / " if weapon.primary else "SECONDARY / ") + weapon.display_name, 16))
	_summary.add_child(UiTheme.label("PERK SLOTS  %d / %d" % [profile.equipped_perks.size(), profile.slots], 16, UiTheme.MUTED, true))
	for i in profile.slots:
		var plate := UiTheme.panel(_summary)
		var name_text: String = "+ EMPTY SLOT"
		var description: String = "Equip a perk in the Perks tab."
		if i < profile.equipped_perks.size():
			var perk: GameData.Perk = GameData.perk(profile.equipped_perks[i])
			if perk != null:
				name_text = "%s  %s" % [perk.title.to_upper(), GameData.RANK_NAMES[profile.use_rank(perk.node())]]
				description = perk.description
		plate.add_child(UiTheme.title(name_text, 18))
		(plate.get_parent() as Control).tooltip_text = description
	_start_button = UiTheme.button(_summary_footer, "START RUN   →", _start, true)
	_start_button.name = "StartRun"


func _archive() -> void:
	if not is_instance_valid(_dialog):
		_dialog = MenuDialog.archive(self, profile)
		profile.mark_archive_read()
		profile.save()


func _act(changed: bool) -> void:
	if changed:
		profile.save()
		_rebuild()


## START RUN: asks which run (archipelago or an expedition) first.
func _start() -> void:
	if is_instance_valid(_dialog):
		return
	_dialog = MenuDialog.run_choice(self, _start_run)


func _start_run(expedition: StringName) -> void:
	profile.save()
	start_requested.emit(expedition)


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(_dialog):
		return
	if _category == "PERKS" and _is_switch_event(event):
		get_viewport().set_input_as_handled()
		_switch_focused_perk()
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _category == "PERKS" and _perk_actions_focused() and _perk_buttons.has(_perk_focus):
			(_perk_buttons[_perk_focus] as Button).grab_focus()  # B: back to the tree
			return
		back_requested.emit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		get_viewport().set_input_as_handled()
		_start()


## LB / RB on a gamepad, Q / E on the keyboard.
static func _is_switch_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed:
		return (event as InputEventJoypadButton).button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]
	if event is InputEventKey and event.pressed and not event.echo:
		return (event as InputEventKey).physical_keycode in [KEY_Q, KEY_E]
	return false
