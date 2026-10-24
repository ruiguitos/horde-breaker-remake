extends Control
## Native equipment screen; progression remains owned by Profile.
## Layout follows docs/design/menu_references/armory_target.webp and
## perks_target.webp (docs/tech/ARMORY_REDESIGN.md).

## `expedition`: &"" = the archipelago run, else an Expeditions.ALL id.
signal start_requested(expedition: StringName)
signal back_requested

const Art = preload("res://game/ui/armory_art.gd")
const Shelter = preload("res://game/ui/armory_shelter.gd")
const PerkNodeView = preload("res://game/ui/perk_node_view.gd")

## Role line under the class name and the one-line card description
## (from the class data: Recruit is the balanced default, Vanguard the
## tougher frontline with +40 max HP).
const CLASS_ROLES: Dictionary = {
	&"recruit": ["BALANCED CONTRACTOR", "Balanced contractor.", "5 m blast."],
	&"vanguard": ["FRONTLINE CONTRACTOR", "Tough frontline.", "7 m stun, −40% damage."],
}
## Pale steel for weapon silhouettes, as in the mockup.
const SILHOUETTE := Color("b9d3d1")
const HEADER_HEIGHT := 72.0
const NBSP := "\u00a0"  ## no-break space
const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.02, 0.05, 0.065, 0.66);
void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 3.0).rgb;
	COLOR = vec4(mix(c, tint.rgb, tint.a), 1.0);
}
"""

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
var _blur: ShaderMaterial
var _header_title: Label
var _header_subtitle: Label
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
	_blur = ShaderMaterial.new()
	_blur.shader = Shader.new()
	_blur.shader.code = BLUR_SHADER
	# Soft dark edges: the class name (left) and the cards (bottom) stay
	# readable over the 3D scene without boxes behind them.
	add_child(_gradient("VignetteLeft", Vector2(0, 0), Vector2(1, 0), [0.0, 0.42], [0.72, 0.0]))
	add_child(_gradient("VignetteBottom", Vector2(0, 0), Vector2(0, 1), [0.62, 1.0], [0.0, 0.7]))
	_build_header_band()
	var screen := UiTheme.screen(self)
	var margin := screen.get_parent() as MarginContainer
	for edge in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 20)
	margin.add_theme_constant_override("margin_top", 10)
	screen.add_theme_constant_override("separation", 10)
	_build_header(screen)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 18)
	screen.add_child(body)
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = 160
	nav.add_theme_constant_override("separation", 10)
	body.add_child(nav)
	for category in ["CLASS", "WEAPONS", "PERKS"]:
		var b := UiTheme.button(nav, category + "   ›", _select_category.bind(category))
		_nav_style(b, 22)
		_nav.append(b)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	nav.add_child(gap)
	var archive := UiTheme.button(nav, "INTEL ARCHIVE", _archive)
	archive.name = "IntelArchive"
	archive.icon = Art.icon(&"folder", 20)
	_nav_style(archive, 19)
	var main_menu := UiTheme.button(nav, "MAIN MENU", func() -> void: back_requested.emit())
	main_menu.name = "MainMenu"
	main_menu.icon = Art.icon(&"home", 20)
	_nav_style(main_menu, 19)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_content)
	var summary_panel := PanelContainer.new()
	summary_panel.name = "LoadoutPanel"
	summary_panel.custom_minimum_size.x = 292
	var panel_box := StyleBoxFlat.new()
	panel_box.bg_color = Color(0.02, 0.06, 0.075, 0.95)
	panel_box.border_color = UiTheme.LINE
	panel_box.set_border_width_all(1)
	panel_box.set_corner_radius_all(3)
	panel_box.content_margin_left = 14
	panel_box.content_margin_right = 14
	panel_box.content_margin_top = 8
	panel_box.content_margin_bottom = 8
	summary_panel.add_theme_stylebox_override("panel", panel_box)
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


## Dark band behind the header, its bottom rule and an azulejo in each corner.
func _build_header_band() -> void:
	var band := ColorRect.new()
	band.name = "HeaderBand"
	band.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	band.offset_bottom = HEADER_HEIGHT
	band.color = Color(0.02, 0.045, 0.058, 0.94)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(band)
	var rule := ColorRect.new()
	rule.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rule.offset_top = HEADER_HEIGHT
	rule.offset_bottom = HEADER_HEIGHT + 1
	rule.color = UiTheme.LINE
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)
	for right in [false, true]:
		var tile := TextureRect.new()
		tile.name = "AzulejoRight" if right else "AzulejoLeft"
		tile.texture = Art.tile(int(HEADER_HEIGHT))
		tile.modulate = Color(1, 1, 1, 0.5)  # discreet: the azulejo frames the header, it does not compete with the character
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT if right else Control.PRESET_TOP_LEFT)
		tile.offset_left = -HEADER_HEIGHT if right else 0.0
		tile.offset_right = 0.0 if right else HEADER_HEIGHT
		tile.offset_top = 0
		tile.offset_bottom = HEADER_HEIGHT
		add_child(tile)


## Brand (left), centred title between two rules, Intel balance (right).
func _build_header(screen: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.custom_minimum_size.y = HEADER_HEIGHT - 20
	header.add_theme_constant_override("separation", 12)
	screen.add_child(header)
	var lead := Control.new()
	lead.custom_minimum_size.x = HEADER_HEIGHT - 14
	header.add_child(lead)
	var brand := UiTheme.label("SALVAGE & CO.\nHALVARD OPERATIONS", 14, UiTheme.TEXT)
	brand.add_theme_font_override("font", UiTheme._spaced(UiTheme.mono_font(), 2))
	brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	brand.custom_minimum_size.x = 200
	brand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(brand)
	var centre := VBoxContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	centre.add_theme_constant_override("separation", -2)
	header.add_child(centre)
	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 22)
	centre.add_child(title_row)
	title_row.add_child(_rule(72))
	_header_title = UiTheme.title("ARMORY", 34)
	_header_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(_header_title)
	title_row.add_child(_rule(72))
	_header_subtitle = UiTheme.label("CONTRACTOR UPGRADES", 12, UiTheme.SUCCESS)
	_header_subtitle.add_theme_font_override("font", UiTheme._spaced(UiTheme.mono_font(), 2))
	_header_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(_header_subtitle)
	var intel_row := HBoxContainer.new()
	intel_row.custom_minimum_size.x = 200
	intel_row.alignment = BoxContainer.ALIGNMENT_END
	intel_row.add_theme_constant_override("separation", 12)
	header.add_child(intel_row)
	var intel_word := UiTheme.label("INTEL", 14, UiTheme.MUTED)
	intel_word.add_theme_font_override("font", UiTheme._spaced(UiTheme.mono_font(), 2))
	intel_word.autowrap_mode = TextServer.AUTOWRAP_OFF
	intel_word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intel_row.add_child(intel_word)
	_intel = UiTheme.title("", 30)
	_intel.name = "IntelBalance"
	_intel.add_theme_font_override("font", UiTheme.mono_bold_font())
	_intel.autowrap_mode = TextServer.AUTOWRAP_OFF
	_intel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	intel_row.add_child(_intel)
	var trail := Control.new()
	trail.custom_minimum_size.x = HEADER_HEIGHT - 14
	header.add_child(trail)


func _rule(width: float) -> ColorRect:
	var line := ColorRect.new()
	line.custom_minimum_size = Vector2(width, 2)
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.color = UiTheme.SUCCESS.darkened(0.25)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _gradient(label: String, from: Vector2, to: Vector2, offsets: Array, alphas: Array) -> TextureRect:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray([Color(UiTheme.BG, alphas[0]), Color(UiTheme.BG, alphas[1])])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 256
	texture.height = 256
	var rect := TextureRect.new()
	rect.name = label
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _nav_style(b: Button, font_size: int) -> void:
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size.y = 42
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_constant_override("h_separation", 14)


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
	_intel.text = "%d" % profile.intel
	var perks: bool = _category == "PERKS"
	_header_title.text = "PERKS" if perks else "ARMORY"
	_header_subtitle.visible = perks
	# Perks: the shelter stays as a blurred, dimmed backdrop.
	_shade.material = _blur if perks else null
	_shade.color = Color(0.02, 0.05, 0.065, 0.6 if _category == "WEAPONS" else 0.0)
	_shelter.call("set_class", profile.selected_class)
	_shelter.call("set_weapon", profile.selected_primary)
	_shelter.call("show_character", _category == "CLASS")
	for i in _nav.size():
		_nav[i].theme_type_variation = &"PrimaryButton" if ["CLASS", "WEAPONS", "PERKS"][i] == _category else &""
	match _category:
		"CLASS": _classes()
		"WEAPONS": _weapons()
		"PERKS": _perks()
	if perks:
		_perk_detail()
	else:
		_loadout()
	_start_button = UiTheme.button(_summary_footer, "START RUN   →", _start, true)
	_start_button.name = "StartRun"
	_compact(_start_button, 50, 28)
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


func _role(id: StringName, index: int) -> String:
	if CLASS_ROLES.has(id):
		return CLASS_ROLES[id][index]
	return String(GameData.CLASS_INFO[id]["text"]) if index > 0 else "CONTRACTOR"


func _classes() -> void:
	_content.add_theme_constant_override("separation", 0)
	var info: Dictionary = GameData.CLASS_INFO[profile.selected_class]
	var heading := UiTheme.title(String(info["name"]).to_upper(), 46)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	heading.add_theme_constant_override("outline_size", 6)
	heading.add_theme_color_override("font_outline_color", Color(UiTheme.BG, 0.6))
	_content.add_child(heading)
	var role := UiTheme.label(_role(profile.selected_class, 0), 16, UiTheme.SUCCESS)
	role.name = "ClassRole"
	role.add_theme_font_override("font", UiTheme._spaced(UiTheme.mono_font(), 2))
	role.autowrap_mode = TextServer.AUTOWRAP_OFF
	role.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	# A dark outline keeps the role legible over any part of the shelter.
	role.add_theme_constant_override("outline_size", 6)
	role.add_theme_color_override("font_outline_color", Color(UiTheme.BG, 0.85))
	_content.add_child(role)
	var hero := Control.new()
	hero.name = "CharacterSpace"
	hero.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(hero)
	hero.add_child(_ability_card(info))
	var choices := HBoxContainer.new()
	choices.name = "ClassChoices"
	choices.alignment = BoxContainer.ALIGNMENT_CENTER
	choices.add_theme_constant_override("separation", 16)
	_content.add_child(choices)
	for id in GameData.CLASSES:
		choices.add_child(_class_card(id))


## The class ability: icon, name, effect and its current binding.
func _ability_card(info: Dictionary) -> PanelContainer:
	var ability := PanelContainer.new()
	ability.name = "ClassAbility"
	ability.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ability.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ability.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ability.offset_left = -196
	ability.offset_top = -64
	ability.offset_right = -2
	ability.offset_bottom = -10
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.02, 0.06, 0.075, 0.92)
	box.border_color = UiTheme.LINE
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	ability.add_theme_stylebox_override("panel", box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	ability.add_child(row)
	var recruit: bool = profile.selected_class == &"recruit"
	var symbol := Art.image(&"grenade" if recruit else &"war_cry", 34, UiTheme.TEXT)
	symbol.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(symbol)
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 0)
	row.add_child(detail)
	var ability_name := UiTheme.title(String(info["ability"]).to_upper(), 18)
	ability_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	ability_name.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail.add_child(ability_name)
	var effect := UiTheme.label(_role(profile.selected_class, 2), 12, UiTheme.MUTED, true)
	effect.autowrap_mode = TextServer.AUTOWRAP_OFF
	detail.add_child(effect)
	var key := UiTheme.icon_hint(row, [GameInput.current_binding(&"ability", profile.key_bindings)], ["joy:%d" % JOY_BUTTON_LEFT_SHOULDER], "")
	key.name = "AbilityKey"
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	key.get_child(1).visible = false
	key.tooltip_text = "Ability"
	return ability


## A large class card: portrait left, name and a one-line role; tick and
## teal outline when selected, price and padlock while not owned.
func _class_card(id: StringName) -> Button:
	var class_info: Dictionary = GameData.CLASS_INFO[id]
	var owned: bool = profile.unlocked_classes.has(id)
	var selected: bool = profile.selected_class == id
	var cost: int = int(class_info["cost"])
	var b := Button.new()
	b.name = "Class_" + String(id)
	b.custom_minimum_size = Vector2(250, 84)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_choose_class.bind(id))
	b.disabled = not owned and profile.intel < cost
	b.tooltip_text = String(class_info["text"])
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.03, 0.085, 0.1, 0.94) if not selected else Color(0.04, 0.13, 0.14, 0.95)
		box.border_color = UiTheme.SUCCESS if selected else UiTheme.LINE
		if state.begins_with("hover"):
			box.border_color = box.border_color.lightened(0.3)
			box.bg_color = box.bg_color.lightened(0.04)
		box.set_border_width_all(2 if selected else 1)
		box.set_corner_radius_all(3)
		if state == "disabled":
			box.bg_color.a = 0.75
		b.add_theme_stylebox_override(state, box)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 2
	row.offset_top = 2
	row.offset_bottom = -2
	row.offset_right = -8
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)
	var portrait := ClassPreview.create(id)
	portrait.face_only = true
	portrait.name = "ClassPortrait"
	portrait.custom_minimum_size = Vector2(84, 0)
	row.add_child(portrait)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var mark := TextureRect.new()
	mark.name = "SelectedTick" if selected else "LockMark"
	mark.texture = UiTheme.tick_icon() if selected else UiTheme.lock_icon()
	mark.modulate = UiTheme.SUCCESS if selected else UiTheme.MUTED
	mark.custom_minimum_size = Vector2(18, 18)
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.self_modulate.a = 1.0 if selected or not owned else 0.0
	text.add_child(mark)
	var title := UiTheme.title(String(class_info["name"]).to_upper(), 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_theme_color_override("font_color", UiTheme.TEXT if owned or not b.disabled else UiTheme.MUTED)
	text.add_child(title)
	var line := UiTheme.label(_role(id, 1) if owned else "%d INTEL" % cost, 11, UiTheme.MUTED if owned else UiTheme.ACCENT, true)
	line.autowrap_mode = TextServer.AUTOWRAP_OFF
	line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(line)
	return b


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
	_content.add_theme_constant_override("separation", 8)
	var heading := UiTheme.title("WEAPONS", 36)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(heading)
	_content.add_child(UiTheme.label("Equip one primary and one secondary. Unlocking keeps the weapon permanently.", 16, UiTheme.MUTED))
	var list := _scroll_list()
	for weapon in GameData.weapons():
		var card := UiTheme.panel(list)
		var top := HBoxContainer.new()
		card.add_child(top)
		top.add_child(Art.weapon_image(weapon.id, 150, 50, SILHOUETTE))
		var names := VBoxContainer.new()
		names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		names.add_theme_constant_override("separation", 0)
		top.add_child(names)
		var title := UiTheme.title(weapon.display_name.to_upper(), 22)
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		names.add_child(title)
		names.add_child(UiTheme.label("PRIMARY" if weapon.primary else "SECONDARY", 13, UiTheme.ACCENT, true))
		var damage_text: String = "%d PELLETS · %d DAMAGE EACH" % [weapon.pellets, int(weapon.damage)] if weapon.pellets > 1 else "%d DAMAGE" % int(weapon.damage)
		card.add_child(UiTheme.label("%s / %.1f SHOTS PER SECOND / %d M" % [damage_text, weapon.fire_rate, int(weapon.range_m)], 16, UiTheme.MUTED, true))
		card.add_child(UiTheme.label(weapon.role, 16))
		var cost: int = maxi(0, GameData.weapon_cost(weapon.id))
		var owned: bool = cost == 0 or profile.unlocked_weapons.has(weapon.id)
		var selected: bool = weapon.id in profile.weapon_loadout()
		var b := UiTheme.button(card, "EQUIPPED" if selected else "EQUIP" if owned else "UNLOCK / %d INTEL" % cost, _choose_weapon.bind(weapon.id))
		b.name = "Weapon_" + String(weapon.id)
		b.disabled = selected or not owned and profile.intel < cost
		if selected:
			b.theme_type_variation = &"SelectedButton"
	# Priced cards: Intel buys them, and they join the level-up offers.
	var cards_heading := UiTheme.title("CARDS", 28)
	cards_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	list.add_child(cards_heading)
	list.add_child(UiTheme.label("Bought cards join the level-up offers in every run.", 16, UiTheme.MUTED))
	for card in GameData.cards():
		if card.unlock_cost <= 0:
			continue
		var panel := UiTheme.panel(list)
		panel.add_child(UiTheme.title(card.title.to_upper(), 22))
		panel.add_child(UiTheme.label(card.description, 16, UiTheme.MUTED, true))
		var bought: bool = profile.owns_card(card.id)
		var buy := UiTheme.button(panel, "BOUGHT" if bought else "UNLOCK / %d INTEL" % card.unlock_cost, _choose_card.bind(card.id))
		buy.name = "Card_" + String(card.id)
		buy.disabled = bought or profile.intel < card.unlock_cost


func _choose_card(id: StringName) -> void:
	if profile.buy_card(id):
		_act(true)


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
const NUMERAL_WIDTH := 28.0


func _perks() -> void:
	_content.add_theme_constant_override("separation", 8)
	if _notice != "":
		var notice := UiTheme.label(_notice, 14, UiTheme.DANGER)
		notice.name = "PerkNotice"
		notice.autowrap_mode = TextServer.AUTOWRAP_OFF
		notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		notice.tooltip_text = _notice
		_content.add_child(notice)
	var grid := HBoxContainer.new()
	grid.name = "PerkTree"
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 8)
	_content.add_child(grid)
	_perk_buttons.clear()
	for branch in GameData.PERK_BRANCHES:
		if branch != GameData.PERK_BRANCHES[0]:
			var split := VSeparator.new()
			split.add_theme_constant_override("separation", 2)
			grid.add_child(split)
		var column := VBoxContainer.new()
		column.name = "Branch_" + String(branch)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 0)
		grid.add_child(column)
		var branch_header := HBoxContainer.new()
		branch_header.alignment = BoxContainer.ALIGNMENT_CENTER
		branch_header.add_theme_constant_override("separation", 8)
		column.add_child(branch_header)
		branch_header.add_child(Art.image(branch, 30, UiTheme.INFO.lerp(UiTheme.TEXT, 0.35)))
		var branch_title := UiTheme.title(String(branch).to_upper(), 27)
		branch_title.autowrap_mode = TextServer.AUTOWRAP_OFF
		branch_header.add_child(branch_title)
		var under := HSeparator.new()
		under.add_theme_constant_override("separation", 10)
		column.add_child(under)
		for tier in range(1, GameData.PERK_TIERS + 1):
			if tier > 1:
				column.add_child(_connector())
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 2)
			column.add_child(row)
			var numeral := UiTheme.title(GameData.RANK_NAMES[tier], 15)
			numeral.add_theme_font_override("font", UiTheme.mono_bold_font())  # serifed numerals
			numeral.add_theme_color_override("font_color", UiTheme.INFO.lerp(UiTheme.TEXT, 0.4))
			numeral.custom_minimum_size.x = NUMERAL_WIDTH
			numeral.autowrap_mode = TextServer.AUTOWRAP_OFF
			row.add_child(numeral)
			row.add_child(_perk_node(GameData.perk_node(branch, tier)))
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
	var strip := PanelContainer.new()
	strip.name = "EquippedStrip"
	var strip_box := StyleBoxFlat.new()
	strip_box.bg_color = Color(0.02, 0.06, 0.075, 0.92)
	strip_box.border_color = UiTheme.LINE
	strip_box.set_border_width_all(1)
	strip_box.set_corner_radius_all(3)
	strip_box.set_content_margin_all(10)
	strip_box.content_margin_left = 14
	strip_box.content_margin_right = 14
	strip.add_theme_stylebox_override("panel", strip_box)
	_content.add_child(strip)
	var equipped := VBoxContainer.new()
	equipped.add_theme_constant_override("separation", 6)
	strip.add_child(equipped)
	var bottom := HBoxContainer.new()
	equipped.add_child(bottom)
	var slots_heading := UiTheme.title("EQUIPPED PERKS   %d / %d" % [profile.equipped_perks.size(), profile.slots], 18)
	slots_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	slots_heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(slots_heading)
	var cost: int = profile.next_slot_cost()
	if cost > 0:
		var slot := UiTheme.button(bottom, "+ SLOT / %d INTEL" % cost, func() -> void: _act(profile.buy_slot()))
		slot.name = "PerkSlot"
		slot.disabled = profile.intel < cost
		_compact(slot, 24, 14)
	_slot_strip(equipped, true)


## Vertical link between two tiers of a branch; it takes the spare height.
func _connector() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size.y = 10
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lead := Control.new()
	lead.custom_minimum_size.x = NUMERAL_WIDTH + 2
	row.add_child(lead)
	var centre := CenterContainer.new()
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(centre)
	var link := ColorRect.new()
	link.color = UiTheme.LINE.lightened(0.15)
	link.custom_minimum_size = Vector2(2, 0)
	link.size_flags_vertical = Control.SIZE_EXPAND_FILL
	link.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# CenterContainer would collapse the line: keep it full height.
	centre.resized.connect(func() -> void: link.custom_minimum_size.y = maxf(0.0, centre.size.y - 6.0))
	centre.add_child(link)
	var pips_space := Control.new()
	pips_space.custom_minimum_size.x = 14
	row.add_child(pips_space)
	return row


## One node of the tree: a focusable button holding both alternatives (the
## picked one outlined) and the rank pips.
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
	heading.add_theme_constant_override("separation", 12)
	_summary.add_child(heading)
	heading.add_child(Art.image(perk.id, 46))
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 2)
	heading.add_child(titles)
	var name_label := UiTheme.title(perk.title.to_upper(), 26)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titles.add_child(name_label)
	# A class variant says so here (its rank still shows in the pips).
	var standing: String = "RANK %s OF III" % GameData.RANK_NAMES[rank] if rank > 0 else "NOT OWNED"
	if perk.class_filter != &"":
		standing = "%s ONLY" % String(GameData.CLASS_INFO[perk.class_filter]["name"]).to_upper()
	var where := UiTheme.label("%s %s  /  %s" % [String(branch).to_upper(), GameData.RANK_NAMES[tier], standing], 11, BRANCH_COLORS[branch].lerp(UiTheme.TEXT, 0.3), true)
	where.autowrap_mode = TextServer.AUTOWRAP_OFF
	titles.add_child(where)
	titles.add_child(_pips(rank, Vector2(14, 8), false))
	# A class-only perk does nothing for another class: say so, do not hide it.
	if perk != null and perk.class_filter != &"" and perk.class_filter != profile.selected_class:
		var warning := UiTheme.label("NO EFFECT WITH THIS CLASS: works only with the %s" % String(GameData.CLASS_INFO[perk.class_filter]["name"]).to_upper(), 13, UiTheme.DANGER)
		warning.name = "ClassWarning"
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		titles.add_child(warning)
	var options := HBoxContainer.new()
	options.add_theme_constant_override("separation", 4)
	_summary.add_child(options)
	var picked: int = profile.perk_option(node)
	for option in 2:
		var alt: GameData.Perk = GameData.perk_for(node, option, profile.selected_class)
		var ob := UiTheme.button(options, alt.title.to_upper() if alt != null else "—", _pick_option.bind(node, option))
		ob.name = "PerkOption_" + "AB"[option]
		ob.alignment = HORIZONTAL_ALIGNMENT_CENTER
		ob.icon = Art.icon(alt.id, 26)
		ob.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ob.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.clip_text = true
		ob.tooltip_text = alt.title + " / " + alt.description + "\nSwitching A ↔ B is free, in the armory only. Ranks belong to the node."
		UiTheme.set_selected(ob, option == picked)
		_compact(ob, 48, 14)
		_corner_tick(ob)
	_divider(_summary)
	# Not owned yet: nothing is active, and NEXT RANK below is rank I.
	_section(_summary, "CURRENT EFFECT", "RANK " + GameData.RANK_NAMES[profile.use_rank(node)] if rank > 0 else "NONE / NOT OWNED")
	if rank > 0:
		var effects := VBoxContainer.new()
		effects.name = "PerkEffects"
		effects.add_theme_constant_override("separation", 0)
		_summary.add_child(effects)
		_effects(effects, perk, profile.use_rank(node))
	var cost: int = profile.next_rank_cost(node)
	_divider(_summary)
	var rank_text: String = "RANK III · MAX" if cost < 0 else ("RANK I" if rank == 0 else "RANK %s → %s" % [GameData.RANK_NAMES[rank], GameData.RANK_NAMES[rank + 1]])
	var rank_label := _section(_summary, "NEXT RANK" if cost > 0 else "MAX RANK", rank_text)
	rank_label.name = "PerkRank"
	if cost > 0:
		var next := VBoxContainer.new()
		next.name = "PerkNextEffects"
		next.add_theme_constant_override("separation", 0)
		_summary.add_child(next)
		_effects(next, perk, rank + 1)
	var problem: String = profile.rank_problem(node)
	if problem != "" and problem != "Max rank":
		var why := UiTheme.label(problem, 13, UiTheme.DANGER, true)
		why.name = "PerkRequirement"
		_summary.add_child(why)
	var spring := Control.new()
	spring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary.add_child(spring)
	if cost > 0:
		var upgrade_text: String = "UNLOCK RANK I / %d INTEL" % cost if rank == 0 else "UPGRADE TO %s / %d INTEL" % [GameData.RANK_NAMES[rank + 1], cost]
		var upgrade := UiTheme.button(_summary, upgrade_text, func() -> void: _act(profile.buy_rank(node)), true)
		upgrade.name = "PerkUpgrade"
		upgrade.icon = Art.icon(&"upgrade", 20)
		upgrade.disabled = problem != ""
		# Never wider than the panel: a long label must not shift the tree.
		upgrade.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		upgrade.tooltip_text = upgrade_text
		_compact(upgrade, 36, 18)
	var equipped: bool = profile.equipped_in(node) != &""
	var full: bool = not equipped and profile.equipped_perks.size() >= profile.slots
	if equipped:
		var status := UiTheme.label("EQUIPPED", 16, UiTheme.TEXT)
		status.name = "PerkEquipped"
		status.add_theme_font_override("font", UiTheme._spaced(UiTheme.heading_font(), 1))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var badge := UiTheme._ticked(UiTheme._box(Color(UiTheme.SUCCESS, 0.14), UiTheme.SUCCESS, 1, 3))
		badge.base.content_margin_top = 3
		badge.base.content_margin_bottom = 3
		badge.place = MarkedBox.Place.LEFT
		badge.sync_margins()
		status.add_theme_stylebox_override("normal", badge)
		_summary.add_child(status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_summary.add_child(row)
	var equip_text: String = "REMOVE" if equipped else ("SLOTS FULL" if full and rank > 0 else "EQUIP")
	var equip := UiTheme.button(row, equip_text, func() -> void: _act(profile.toggle_equip_node(node)))
	equip.name = "PerkEquip"
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.disabled = not equipped and (rank == 0 or full)
	equip.tooltip_text = "Free: perks can be equipped and removed at any time in the armory."
	_compact(equip, 30, 16)
	if rank >= 2:
		var use := UiTheme.button(row, "USE RANK %s" % GameData.RANK_NAMES[profile.use_rank(node) - 1 if profile.use_rank(node) > 1 else rank],
			func() -> void: _act(profile.cycle_use_rank(node)))
		use.name = "PerkUseRank"
		use.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		use.tooltip_text = "Free: play with a lower purchased rank (milder trade-off)."
		_compact(use, 30, 16)
	var note := UiTheme.label("Switching alternatives is free.", 11, UiTheme.MUTED, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary.add_child(note)


## Tall cards show the SELECTED tick in their top-left corner, so it does
## not eat into the centred name (same teal outline as SelectedButton).
func _corner_tick(button: Button) -> void:
	if button.theme_type_variation != &"SelectedButton":
		return
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := button.get_theme_stylebox(state)
		if style is MarkedBox:
			var plain: StyleBoxFlat = (style as MarkedBox).base.duplicate()
			plain.content_margin_left = 6
			plain.content_margin_right = 6
			plain.border_color = UiTheme.SUCCESS
			plain.set_border_width_all(2)
			button.add_theme_stylebox_override(state, plain)
	var tick := TextureRect.new()
	tick.name = "SelectedTick"
	tick.texture = UiTheme.tick_icon()
	tick.modulate = UiTheme.SUCCESS
	tick.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tick.position = Vector2(6, 5)
	tick.size = Vector2(16, 16)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tick)


## Section heading with an optional value on the right; returns that value label.
func _section(parent: Control, text: String, value: String) -> Label:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var head := UiTheme.title(text, 15)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(head)
	var right := UiTheme.label(value, 11, UiTheme.MUTED, true)
	right.autowrap_mode = TextServer.AUTOWRAP_OFF
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)
	return right


## Benefit(s) and trade-off of `perk` at `rank`, as label / value rows.
func _effects(parent: VBoxContainer, perk: GameData.Perk, rank: int) -> void:
	_effect_row(parent, true, perk.benefit, perk.value(rank))
	if perk.benefit_2 != "":
		_effect_row(parent, true, perk.benefit_2, perk.value_2(rank))
	_effect_row(parent, false, perk.penalty, perk.cost_value(rank))


## One effect: "▲ Headshot cone ........ 13°". The value is pulled out of
## the data text so it lines up on the right; the full sentence stays in the
## row's tooltip. ▲/▼ and colour both mark benefit vs trade-off.
func _effect_row(parent: VBoxContainer, benefit: bool, format: String, value: float) -> void:
	var parts: Array[String] = split_effect(format, value)
	var row := HBoxContainer.new()
	row.name = "EffectRow"
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = ("▲ " if benefit else "▼ ") + GameData.perk_text(format, value)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(row)
	var colour: Color = UiTheme.SUCCESS if benefit else UiTheme.DANGER
	var what := UiTheme.label(("▲ " if benefit else "▼ ") + parts[0], 12, UiTheme.TEXT)
	what.name = "Effect"
	what.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(what)
	var amount := UiTheme.label(parts[1], 12, colour, true)
	amount.name = "Value"
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(amount)


## ["Headshot cone", "13°"] from ("Headshot cone {v}°", 13). A unit word
## right after the value (s, m, HP) moves with it.
static func split_effect(format: String, value: float) -> Array[String]:
	var words: PackedStringArray = format.split(" ")
	for i in words.size():
		if words[i].contains("{v}"):
			var amount: String = GameData.perk_text(words[i], value)
			words.remove_at(i)
			if i < words.size() and words[i] in ["s", "m", "HP"]:
				amount += " " + words[i]
				words.remove_at(i)
			# Keep "2 s" / "7 m" together when the label wraps.
			var units := RegEx.create_from_string("([0-9]) (s|m|HP)(?= |$)")
			return [units.sub(" ".join(words).strip_edges(), "$1" + NBSP + "$2", true), amount]
	return [format, ""]


func _pips(rank: int, size: Vector2, vertical: bool) -> BoxContainer:
	var pips: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	pips.add_theme_constant_override("separation", 4)
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for k in range(1, GameData.PERK_MAX_RANK + 1):
		var pip := ColorRect.new()
		pip.custom_minimum_size = size
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.color = UiTheme.ACCENT if k <= rank else UiTheme.LINE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pips.add_child(pip)
	return pips


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


## A weapon's picture in the loadout: its three-quarter render of the real model
## (tools/dev/weapon_icon_render.gd), or the silhouette while that render is missing.
func _weapon_picture(id: StringName) -> Control:
	var path: String = "res://game/ui/art/weapons/%s.png" % id
	if not ResourceLoader.exists(path):
		return Art.weapon_image(id, 118, 40, SILHOUETTE)
	var picture := TextureRect.new()
	picture.name = "WeaponPicture"
	picture.texture = load(path)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(118, 46)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return picture


func _loadout() -> void:
	_summary.add_theme_constant_override("separation", 6)
	var title := UiTheme.title("LOADOUT", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_summary.add_child(title)
	_divider(_summary)
	for id in profile.weapon_loadout():
		var weapon: GameData.Weapon = GameData.weapon(id)
		_summary.add_child(UiTheme.label("PRIMARY" if weapon.primary else "SECONDARY", 12, UiTheme.MUTED, true))
		var weapon_row := HBoxContainer.new()
		weapon_row.add_theme_constant_override("separation", 10)
		_summary.add_child(weapon_row)
		weapon_row.add_child(_weapon_picture(id))
		var weapon_name := UiTheme.label(weapon.display_name.to_upper(), 13, UiTheme.TEXT)
		weapon_name.autowrap_mode = TextServer.AUTOWRAP_OFF
		weapon_name.add_theme_font_override("font", UiTheme._spaced(UiTheme.mono_font(), 1))
		weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		weapon_row.add_child(weapon_name)
		_divider(_summary)
	var perks_head := UiTheme.title("PERKS   %d / %d" % [profile.equipped_perks.size(), profile.slots], 18)
	perks_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_summary.add_child(perks_head)
	_slot_strip(_summary, false)
	_divider(_summary)
	var threat := UiTheme.title("THREAT LEVEL", 18)
	threat.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_summary.add_child(threat)
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 8)
	_summary.add_child(levels)
	for t in range(1, GameData.MAX_THREAT + 1):
		var b := UiTheme.button(levels, "%02d" % t, func() -> void:
			profile.threat = t
			_act(true))
		b.name = "Threat_%d" % t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_override("font", UiTheme.mono_bold_font())
		b.disabled = t > profile.max_threat
		b.tooltip_text = "Extract on your highest Threat to unlock the next level."
		if t == profile.threat:
			b.theme_type_variation = &"SelectedButton"
		_compact(b, 40, 20)
		if b.disabled:
			# Locked level: a solid box with a padlock, still clearly a level.
			var locked := MarkedBox.new(UiTheme._box(Color(0.02, 0.05, 0.06, 0.9), UiTheme.LINE, 1, 3))
			locked.mark_texture = UiTheme.lock_icon()
			locked.mark_color = UiTheme.MUTED
			locked.place = MarkedBox.Place.LEFT
			locked.sync_margins()
			b.add_theme_stylebox_override("disabled", locked)
	var multiplier := HBoxContainer.new()
	_summary.add_child(multiplier)
	var word := UiTheme.label("INTEL MULTIPLIER", 13, UiTheme.MUTED, true)
	word.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	multiplier.add_child(word)
	var factor := UiTheme.label("×%.2f" % GameData.threat_intel(profile.threat), 15, UiTheme.TEXT)
	factor.name = "IntelMultiplier"
	factor.add_theme_font_override("font", UiTheme.mono_bold_font())
	factor.autowrap_mode = TextServer.AUTOWRAP_OFF
	multiplier.add_child(factor)


## Three permanent slots: equipped, empty and not-yet-purchased stay visible.
## `interactive` (Perks tab): wide slots with name, rank and pips; a press
## focuses the perk's node (or the slot purchase). Otherwise (loadout):
## square slots with a caption; a press opens the Perks tab.
func _slot_strip(parent: Control, interactive: bool) -> void:
	var row := HBoxContainer.new()
	row.name = "PerkSlots"
	row.add_theme_constant_override("separation", 8 if interactive else 12)
	parent.add_child(row)
	for i in GameData.SLOT_COSTS.size():
		var id: StringName = profile.equipped_perks[i] if i < profile.equipped_perks.size() else &""
		var perk: GameData.Perk = GameData.perk(id) if id != &"" else null
		var locked: bool = i >= profile.slots
		var slot := Button.new()
		slot.name = "EquippedSlot_%d" % i
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var dashed: bool = perk == null
		var border: Color = UiTheme.SUCCESS.darkened(0.2) if perk != null else UiTheme.LINE.lightened(0.25)
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			var box: StyleBox = UiTheme.card_box(Color(0.03, 0.085, 0.1, 0.9), border.lightened(0.3) if state.begins_with("hover") else border, 1, dashed)
			slot.add_theme_stylebox_override(state, box)
		var rank_name: String = GameData.RANK_NAMES[profile.use_rank(perk.node())] if perk != null else ""
		slot.tooltip_text = perk.title + " / " + perk.description if perk != null else ("Purchase the next perk slot." if locked else "Equip a perk in the Perks tab.")
		if interactive:
			slot.custom_minimum_size.y = 58
			_wide_slot(slot, perk, locked, rank_name, i)
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
			row.add_child(slot)
		else:
			var cell := VBoxContainer.new()
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.add_theme_constant_override("separation", 3)
			row.add_child(cell)
			slot.custom_minimum_size.y = 54
			var symbol: Texture2D = Art.icon(perk.id, 30) if perk != null else (UiTheme.lock_icon() if locked else Art.icon(&"plus", 26))
			slot.icon = symbol
			slot.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			slot.add_theme_color_override("icon_normal_color", UiTheme.TEXT if perk != null else UiTheme.MUTED)
			slot.pressed.connect(_select_category.bind("PERKS"))
			cell.add_child(slot)
			var caption := UiTheme.label("RANK " + rank_name if perk != null else ("LOCKED" if locked else "EMPTY"), 11, UiTheme.MUTED, true)
			caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			caption.autowrap_mode = TextServer.AUTOWRAP_OFF
			cell.add_child(caption)


## Perks-tab slot: icon box, name, roman rank and pips (or + EMPTY / LOCKED).
func _wide_slot(slot: Button, perk: GameData.Perk, locked: bool, rank_name: String, index: int) -> void:
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 4
	row.offset_bottom = -4
	row.offset_right = -8
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(row)
	var square := PanelContainer.new()
	square.custom_minimum_size = Vector2(50, 0)
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_theme_stylebox_override("panel", UiTheme.card_box(Color(0.02, 0.05, 0.06, 0.8), UiTheme.LINE, 1, perk == null))
	row.add_child(square)
	var symbol: StringName = perk.id if perk != null else &"plus"
	var image := Art.image(symbol, 30 if perk != null else 22, UiTheme.TEXT if perk != null else UiTheme.MUTED)
	if locked:
		image.texture = UiTheme.lock_icon()
	square.add_child(image)
	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var cost: int = GameData.SLOT_COSTS[index]
	var name_text: String = perk.title.to_upper() if perk != null else ("LOCKED / %d INTEL" % cost if locked else "EMPTY")
	var title := UiTheme.title(name_text, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_color_override("font_color", UiTheme.TEXT if perk != null else UiTheme.MUTED)
	text.add_child(title)
	if perk != null:
		var rank_row := HBoxContainer.new()
		rank_row.add_theme_constant_override("separation", 10)
		rank_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(rank_row)
		var numeral := UiTheme.title(rank_name, 16)
		numeral.custom_minimum_size.x = 18
		numeral.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		rank_row.add_child(numeral)
		rank_row.add_child(_pips(profile.node_rank(perk.node()), Vector2(10, 10), false))


## Dense detail actions keep their focus/state styles, with smaller padding.
func _compact(button: Button, height: float, font_size: int) -> void:
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", font_size)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style: StyleBox = button.get_theme_stylebox(state).duplicate()
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		if not style is MarkedBox:  # keep the room reserved for a tick/padlock
			style.content_margin_left = minf(style.content_margin_left, 10)
			style.content_margin_right = minf(style.content_margin_right, 10)
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
