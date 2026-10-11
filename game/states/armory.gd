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
	UiTheme.hints(screen)
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
	_loadout()
	if focus_name != "":
		call_deferred("_restore_focus", focus_name)


func _restore_focus(focus_name: String) -> void:
	for node in find_children(focus_name, "Button", true, false):
		var candidate := node as Button
		if candidate.is_visible_in_tree() and not candidate.disabled:
			candidate.grab_focus()
			return


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


func _perks() -> void:
	_content.add_child(UiTheme.title("PERKS", 36))
	_content.add_child(UiTheme.label("Choose how you break the horde. Equipped perks: %d / %d." % [profile.equipped_perks.size(), profile.slots], 16, UiTheme.MUTED))
	var list := _scroll_list()
	for perk in GameData.perks():
		var card := UiTheme.panel(list)
		card.add_child(UiTheme.title(perk.title.to_upper(), 22))
		card.add_child(UiTheme.label(perk.description, 16))
		var owned: bool = profile.owned_perks.has(perk.id)
		var equipped: bool = profile.equipped_perks.has(perk.id)
		var text: String = "EQUIPPED / REMOVE" if equipped else ("EQUIP" if owned else "UNLOCK / %d INTEL" % perk.cost)
		var b := UiTheme.button(card, text, func() -> void:
			_act(profile.toggle_equip(perk.id) if owned else profile.buy_perk(perk)))
		b.name = "Perk_" + String(perk.id)
		b.disabled = (not owned and profile.intel < perk.cost) or (owned and not equipped and profile.equipped_perks.size() >= profile.slots)
		if equipped:
			b.theme_type_variation = &"SelectedButton"
	var cost: int = profile.next_slot_cost()
	if cost > 0:
		var slot := UiTheme.button(list, "UNLOCK SLOT %d / %d INTEL" % [profile.slots + 1, cost], func() -> void: _act(profile.buy_slot()))
		slot.disabled = profile.intel < cost


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
			for perk in GameData.perks():
				if perk.id == profile.equipped_perks[i]:
					name_text = perk.title.to_upper()
					description = perk.description
					break
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
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		get_viewport().set_input_as_handled()
		_start()
