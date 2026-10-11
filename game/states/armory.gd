extends Control
## Native equipment screen; progression remains owned by Profile.

## `expedition`: &"" = the archipelago run, else an Expeditions.ALL id.
signal start_requested(expedition: StringName)
signal back_requested

const Art = preload("res://game/ui/armory_art.gd")
const Shelter = preload("res://game/ui/armory_shelter.gd")
const PerkNodeView = preload("res://game/ui/perk_node_view.gd")

var profile: Profile
var _category: String = "CLASS"
var _content: VBoxContainer
var _summary: VBoxContainer
var _summary_footer: VBoxContainer
var _nav: Array[Button] = []
var _start_button: Button
var _dialog: MenuDialog
var _hints: HBoxContainer
var _shelter: ClassPreview
var _shade: ColorRect
var _header_title: Label
var _intel: Label
## Perk tree: node buttons by node id, and the node shown in the detail.
var _perk_buttons: Dictionary = {}
var _perk_focus: StringName = &"combat_1"
## A migration notice (e.g. Demolitions removed from a Vanguard), shown
## while the Armory is open.
var _notice: String = ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	_shelter = Shelter.new()
	_shelter.class_id = profile.selected_class
	_shelter.name = "ArmoryShelter"
	_shelter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shelter)
	_shade = ColorRect.new()
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	var header_back := ColorRect.new()
	header_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	header_back.offset_bottom = 72
	header_back.color = Color(0.02, 0.055, 0.07, 0.85)
	header_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(header_back)
	var screen := UiTheme.screen(self)
	for edge in ["left", "right", "top", "bottom"]:
		(screen.get_parent() as MarginContainer).add_theme_constant_override("margin_" + edge, 20)
	screen.add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	screen.add_child(header)
	var tile := TextureRect.new()
	tile.texture = Art.tile()
	tile.custom_minimum_size = Vector2(36, 36)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(tile)
	var brand := UiTheme.label("SALVAGE & CO.\nHALVARD OPERATIONS", 13, UiTheme.TEXT, true)
	brand.custom_minimum_size.x = 180
	header.add_child(brand)
	_header_title = UiTheme.title("ARMORY", 30)
	_header_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_header_title)
	_intel = UiTheme.label("", 18, UiTheme.TEXT, true)
	_intel.name = "IntelBalance"
	_intel.custom_minimum_size.x = 180
	_intel.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_intel)
	_divider(screen)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	screen.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 152
	nav.add_theme_constant_override("separation", 10)
	body.add_child(nav)
	for category in ["CLASS", "WEAPONS", "PERKS"]:
		var b := UiTheme.button(nav, category + "   ›", _select_category.bind(category))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 20)
		_nav.append(b)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(gap)
	UiTheme.button(nav, "INTEL ARCHIVE", _archive).add_theme_font_size_override("font_size", 18)
	UiTheme.button(nav, "MAIN MENU", func() -> void: back_requested.emit()).add_theme_font_size_override("font_size", 18)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	var summary_panel := PanelContainer.new()
	summary_panel.name = "LoadoutPanel"
	summary_panel.custom_minimum_size.x = 292
	summary_panel.add_theme_stylebox_override("panel", UiTheme.card_box(Color(0.025, 0.08, 0.1, 0.94), UiTheme.LINE))
	body.add_child(summary_panel)
	var summary_column := VBoxContainer.new()
	summary_column.add_theme_constant_override("separation", 8)
	summary_panel.add_child(summary_column)
	_summary = VBoxContainer.new()
	_summary.name = "Summary"
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary.add_theme_constant_override("separation", 6)
	summary_column.add_child(_summary)
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
	_intel.text = "INTEL  %d" % profile.intel
	_header_title.text = "PERKS / CONTRACTOR UPGRADES" if _category == "PERKS" else "ARMORY"
	_header_title.add_theme_font_size_override("font_size", 24 if _category == "PERKS" else 30)
	_shade.color = Color(0.02, 0.05, 0.065, 0.72 if _category == "PERKS" else 0.55 if _category == "WEAPONS" else 0.15)
	_shelter.call("set_class", profile.selected_class)
	_shelter.call("set_weapon", profile.selected_primary)
	_shelter.call("show_character", _category == "CLASS")
	for i in _nav.size():
		_nav[i].theme_type_variation = &"PrimaryButton" if ["CLASS", "WEAPONS", "PERKS"][i] == _category else &""
	match _category:
		"CLASS": _classes()
		"WEAPONS": _weapons()
		"PERKS": _perks()
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
	var heading := UiTheme.title(String(info["name"]).to_upper(), 42)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(heading)
	_content.add_child(UiTheme.label("BALANCED CONTRACTOR" if profile.selected_class == &"recruit" else "FRONTLINE / CONTROL / SURVIVE", 13, UiTheme.SUCCESS, true))
	var hero := Control.new()
	hero.name = "CharacterSpace"
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(hero)
	var ability := PanelContainer.new()
	ability.name = "ClassAbility"
	ability.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ability.offset_left = -200
	ability.offset_top = -108
	ability.offset_bottom = -8
	ability.add_theme_stylebox_override("panel", UiTheme.card_box(Color(0.035, 0.1, 0.12, 0.93), UiTheme.LINE))
	hero.add_child(ability)
	var row := HBoxContainer.new()
	ability.add_child(row)
	row.add_child(Art.image(&"grenade" if profile.selected_class == &"recruit" else &"war_cry", 32, UiTheme.SUCCESS))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	detail.add_child(UiTheme.title(String(info["ability"]).to_upper(), 20))
	detail.add_child(UiTheme.label("5 m blast." if profile.selected_class == &"recruit" else "Reduce incoming damage.", 14))
	UiTheme.icon_hint(detail, [GameInput.current_binding(&"ability", profile.key_bindings)], ["joy:%d" % JOY_BUTTON_LEFT_SHOULDER], "ABILITY")
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
		var portrait := ClassPreview.create(id)
		portrait.face_only = true
		portrait.name = "ClassPortrait"
		portrait.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
		portrait.offset_left = 40
		portrait.offset_right = 96
		portrait.offset_top = 4
		portrait.offset_bottom = -4
		b.add_child(portrait)
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
	_content.add_theme_constant_override("separation", 4)
	var top := HBoxContainer.new()
	_content.add_child(top)
	var heading := UiTheme.label("BUILD / " + String(GameData.CLASS_INFO[profile.selected_class]["name"]).to_upper(), 13, UiTheme.MUTED, true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var status := UiTheme.label("A / B · FREE SWITCH", 11, UiTheme.MUTED, true)
	status.name = "PerkStatus"
	status.autowrap_mode = TextServer.AUTOWRAP_OFF
	status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(status)
	if _notice != "":
		var notice := UiTheme.label(_notice, 14, UiTheme.DANGER)
		notice.name = "PerkNotice"
		notice.autowrap_mode = TextServer.AUTOWRAP_OFF
		notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		notice.tooltip_text = _notice
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
		var branch_header := HBoxContainer.new()
		column.add_child(branch_header)
		branch_header.add_child(Art.image(branch, 28, UiTheme.SUCCESS))
		var branch_title := UiTheme.title(String(branch).to_upper(), 23)
		branch_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		branch_header.add_child(branch_title)
		_divider(column)
		for tier in range(1, GameData.PERK_TIERS + 1):
			var link := ColorRect.new()
			link.color = UiTheme.LINE
			link.custom_minimum_size = Vector2(2, 5 if tier == 1 else 10)
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
	var equipped := UiTheme.panel(_content)
	(equipped.get_parent() as Control).name = "EquippedStrip"
	(equipped.get_parent() as PanelContainer).add_theme_stylebox_override("panel", UiTheme.card_box(UiTheme.PANEL, UiTheme.LINE))
	equipped.add_theme_constant_override("separation", 4)
	var bottom := HBoxContainer.new()
	equipped.add_child(bottom)
	var slots_heading := UiTheme.label("EQUIPPED  %d / %d" % [profile.equipped_perks.size(), profile.slots], 12, UiTheme.TEXT, true)
	slots_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(slots_heading)
	var cost: int = profile.next_slot_cost()
	if cost > 0:
		var slot := UiTheme.button(bottom, "+ SLOT · %d INTEL" % cost, func() -> void: _act(profile.buy_slot()))
		slot.name = "PerkSlot"
		slot.add_theme_font_size_override("font_size", 14)
		slot.custom_minimum_size.y = 26
		slot.add_theme_stylebox_override("normal", UiTheme.card_box(UiTheme.PANEL_RAISED, UiTheme.LINE))
		slot.disabled = profile.intel < cost
		_compact(slot, 26, 14)
	else:
		var all_slots := UiTheme.label("ALL SLOTS UNLOCKED", 10, UiTheme.MUTED, true)
		all_slots.autowrap_mode = TextServer.AUTOWRAP_OFF
		bottom.add_child(all_slots)
	_slot_strip(equipped, true)


## One node of the tree: a focusable button holding the tier, its state,
## both alternatives (the picked one filled) and the rank pips.
func _perk_node(node: StringName) -> Button:
	var button: Button = PerkNodeView.create(profile, node, _node_state(node), _focus_perk, _open_perk_actions)
	_perk_buttons[node] = button
	return button

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
	_summary.add_theme_constant_override("separation", 4)
	var node: StringName = _perk_focus
	var branch: StringName = GameData.perk_node_branch(node)
	var tier: int = GameData.perk_node_tier(node)
	var rank: int = profile.node_rank(node)
	var perk: GameData.Perk = profile.perk_choice(node)
	if perk == null:
		return
	var heading := HBoxContainer.new()
	_summary.add_child(heading)
	heading.add_child(Art.image(perk.id, 32))
	var name_label := UiTheme.title(perk.title.to_upper(), 26)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(name_label)
	_summary.add_child(UiTheme.label("%s %s · TIER %s" % [BRANCH_SHAPES[branch], String(branch).to_upper(), GameData.RANK_NAMES[tier]], 12, BRANCH_COLORS[branch], true))
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 4)
	_summary.add_child(options)
	var picked: int = profile.perk_option(node)
	for option in 2:
		var alt: GameData.Perk = GameData.perk_for(node, option, profile.selected_class)
		var ob := UiTheme.button(options, "%s · %s" % ["AB"[option], alt.title.to_upper() if alt != null else "—"], _pick_option.bind(node, option))
		ob.name = "PerkOption_" + "AB"[option]
		ob.alignment = HORIZONTAL_ALIGNMENT_CENTER
		ob.text = "AB"[option]
		ob.icon = Art.icon(alt.id, 20)
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.custom_minimum_size.y = 34
		ob.add_theme_font_size_override("font_size", 13)
		ob.clip_text = true
		ob.tooltip_text = alt.title + " / " + alt.description + "\nSwitching A ↔ B is free, in the armory only. Ranks belong to the node."
		UiTheme.set_selected(ob, option == picked)
		_compact(ob, 34, 13)
	if perk.class_filter != &"":
		_summary.add_child(UiTheme.label("%s ONLY · CLASS VARIANT" % String(GameData.CLASS_INFO[perk.class_filter]["name"]).to_upper(), 11, UiTheme.MUTED, true))
	var shown: int = maxi(1, profile.use_rank(node))
	_divider(_summary)
	_summary.add_child(UiTheme.label("CURRENT EFFECT" if rank > 0 else "NOT PURCHASED / RANK I PREVIEW", 11, UiTheme.TEXT, true))
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
	_divider(_summary)
	if cost > 0:
		_summary.add_child(UiTheme.label("NEXT RANK / " + GameData.RANK_NAMES[rank + 1], 11, UiTheme.TEXT, true))
		var next := VBoxContainer.new()
		next.name = "PerkNextEffects"
		next.add_theme_constant_override("separation", 2)
		_summary.add_child(next)
		next.add_child(UiTheme.label("▲ " + GameData.perk_text(perk.benefit, perk.value(rank + 1)), 13, UiTheme.SUCCESS))
		if perk.benefit_2 != "":
			next.add_child(UiTheme.label("▲ " + GameData.perk_text(perk.benefit_2, perk.value_2(rank + 1)), 13, UiTheme.SUCCESS))
		next.add_child(UiTheme.label("▼ " + GameData.perk_text(perk.penalty, perk.cost_value(rank + 1)), 13, UiTheme.DANGER))
	else:
		_summary.add_child(UiTheme.label("MAX RANK / III", 13, UiTheme.SUCCESS, true))
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
		upgrade.custom_minimum_size.y = 34
		upgrade.add_theme_font_size_override("font_size", 18)
		upgrade.disabled = problem != ""
		_compact(upgrade, 34, 18)
	var equipped: bool = profile.equipped_in(node) != &""
	var full: bool = not equipped and profile.equipped_perks.size() >= profile.slots
	var equip_text: String = "✓ EQUIPPED · REMOVE" if equipped else ("SLOTS FULL" if full and rank > 0 else "EQUIP")
	var equip := UiTheme.button(_summary, equip_text, func() -> void: _act(profile.toggle_equip_node(node)))
	equip.name = "PerkEquip"
	equip.custom_minimum_size.y = 34
	equip.add_theme_font_size_override("font_size", 17)
	equip.disabled = not equipped and (rank == 0 or full)
	UiTheme.set_selected(equip, equipped)
	if equipped:
		equip.text = "EQUIPPED · REMOVE"
	_compact(equip, 30, 17)
	if rank >= 2:
		var use := UiTheme.button(_summary, "USE RANK %s (FREE)" % GameData.RANK_NAMES[profile.use_rank(node) - 1 if profile.use_rank(node) > 1 else rank],
			func() -> void: _act(profile.cycle_use_rank(node)))
		use.name = "PerkUseRank"
		use.custom_minimum_size.y = 30
		use.add_theme_font_size_override("font_size", 15)
		_compact(use, 28, 15)
	_summary.add_child(UiTheme.label("Switching alternatives is free.", 11, UiTheme.MUTED))


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
	_summary.add_theme_constant_override("separation", 4)
	_summary.add_child(UiTheme.title("LOADOUT", 25))
	_divider(_summary)
	for id in profile.weapon_loadout():
		var weapon: GameData.Weapon = GameData.weapon(id)
		_summary.add_child(UiTheme.label("PRIMARY" if weapon.primary else "SECONDARY", 12, UiTheme.MUTED, true))
		var weapon_row := HBoxContainer.new()
		_summary.add_child(weapon_row)
		weapon_row.add_child(Art.image(id, 36, UiTheme.SUCCESS))
		var weapon_name := UiTheme.title(weapon.display_name.to_upper(), 23)
		weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_row.add_child(weapon_name)
		_divider(_summary)
	_summary.add_child(UiTheme.label("PERKS  %d / %d" % [profile.equipped_perks.size(), profile.slots], 13, UiTheme.TEXT, true))
	_slot_strip(_summary, false)
	_divider(_summary)
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
		b.custom_minimum_size.y = 38
		b.disabled = t > profile.max_threat
		b.tooltip_text = "Extract on your highest Threat to unlock the next level."
		b.theme_type_variation = &"LockedButton" if b.disabled else &""
		if t == profile.threat:
			b.theme_type_variation = &"SelectedButton"
	_summary.add_child(UiTheme.label("INTEL MULTIPLIER / ×%.2f" % GameData.threat_intel(profile.threat), 12, UiTheme.MUTED, true))
	_start_button = UiTheme.button(_summary_footer, "START RUN   →", _start, true)
	_start_button.name = "StartRun"


## Three permanent slots: equipped, empty and not-yet-purchased stay visible.
func _slot_strip(parent: Control, interactive: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "PerkSlots"
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	for i in GameData.SLOT_COSTS.size():
		var id: StringName = profile.equipped_perks[i] if i < profile.equipped_perks.size() else &""
		var perk: GameData.Perk = GameData.perk(id) if id != &"" else null
		var locked: bool = i >= profile.slots
		var slot := Button.new()
		slot.name = "EquippedSlot_%d" % i
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.custom_minimum_size.y = 48 if interactive else 52
		slot.clip_text = true
		slot.add_theme_stylebox_override("normal", UiTheme.card_box(UiTheme.PANEL_RAISED, UiTheme.SUCCESS if perk != null else UiTheme.LINE, 1, locked or perk == null))
		slot.add_theme_font_size_override("font_size", 13)
		slot.text = ((perk.title + "\n") if interactive else "") + "RANK " + GameData.RANK_NAMES[profile.use_rank(perk.node())] if perk != null else ("LOCKED" if locked else "+\nEMPTY")
		if perk != null:
			slot.icon = Art.icon(perk.id, 24)
		slot.tooltip_text = perk.title + " / " + perk.description if perk != null else ("Purchase the next perk slot." if locked else "Equip a perk in the Perks tab.")
		slot.theme_type_variation = &"LockedButton" if locked else &""
		if interactive:
			if perk != null:
				slot.pressed.connect(func() -> void:
					(_perk_buttons[perk.node()] as Button).grab_focus())
			else:
				slot.pressed.connect(func() -> void:
					var purchase := find_child("PerkSlot", true, false) as Button
					if purchase != null and not purchase.disabled:
						purchase.grab_focus()
					else:
						(_perk_buttons[_perk_focus] as Button).grab_focus())
		else:
			slot.pressed.connect(_select_category.bind("PERKS"))
		row.add_child(slot)


## Dense detail actions keep their focus/state styles, with smaller padding.
func _compact(button: Button, height: float, font_size: int) -> void:
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		button.add_theme_stylebox_override(state, style)


func _divider(parent: Control) -> void:
	var line := HSeparator.new()
	line.add_theme_constant_override("separation", 4)
	parent.add_child(line)


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
