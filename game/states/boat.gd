extends Control
## The boat between islands, on one screen: the chart (left), the two routes
## and the quartermaster's supplies (right), and DEPLOY (bottom right), which
## names where you go and with what. Existing rewards and RNG order retained.
## The expedition camp (camp.gd) extends this script: same supplies, no routes.
##
## Selection and focus are separate: LB/RB (or 4/5) pick a route from
## anywhere; up/down move focus between the route row, the supply row and
## DEPLOY; A picks what is focused and moves on to the next row. Route A and
## the first useful supply start selected, so a quick player can deploy at
## once. The supply is applied on DEPLOY, so changing your mind is free.

signal land_requested

## Supply tile height and route picture height, at the 1152x648 base size.
const SUPPLY_HEIGHT: float = 80.0
const PICTURE_HEIGHT: float = 56.0

var context: RunContext
var _rng := RandomNumberGenerator.new()
## Supplies: title, short (for DEPLOY's sub-line), text, reason (why it
## would do nothing; "" = useful), apply.
var _options: Array[Dictionary] = []
var _buttons: Array[Button] = []  ## supply tiles, same order as _options
var _supply: int = -1  ## selected supply (-1 = none)
var _applied: bool = false
var _land: Button
var _land_title: Label
var _land_sub: Label
var _land_content: Control  ## DEPLOY's labels; their width sizes the button
var _status: Label
var _routes: Array[GameData.Modifier] = []
var _route_buttons: Array[Button] = []
var _route: int = -1  ## selected route (-1 = none)
var _route_biomes: Array[StringName] = []
var _route_missions: Array[StringName] = []
var _map: RouteMap
var _briefing: DialogueBox


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = context.island_seed() + 1
	theme = UiTheme.get_theme()
	UiTheme.backdrop(self)
	_make_options()
	_make_routes()
	var screen := _screen()
	_header(screen, "SALVAGE & CO. / BOAT", "NEXT LANDING / ISLAND %d OF %d" % [context.island_index + 1, RunContext.ISLAND_COUNT])
	var body := _body(screen)
	var chart := _chart_panel(body)
	_map = RouteMap.new()
	_map.biomes = _route_biomes
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.add_child(_map)
	chart.move_child(_map, 0)
	var right := _right_column(body)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	right.add_child(row)
	for i in 2:
		row.add_child(_route_card(i))
	_supply_row(right)
	_footer(screen, true)
	_select_route(0)
	_select_supply(_first_useful())
	_route_buttons[0].grab_focus()
	add_child(UiSfx.new())
	add_child(Ambience.create(&"menu", -12.0))


func _make_routes() -> void:
	var mods: Array[GameData.Modifier] = GameData.modifiers()
	var a: int = _rng.randi_range(0, mods.size() - 1)
	var b: int = (a + _rng.randi_range(1, mods.size() - 1)) % mods.size()
	_routes = [mods[a], mods[b]]
	var biomes: Array[StringName] = GameData.ISLAND_BIOMES.duplicate()
	var missions: Array = GameData.ROUTE_MISSIONS  # not the expedition-only holdout
	for i in 2:
		_route_missions.append(missions[_rng.randi_range(0, missions.size() - 1)])
		if context.is_last_island():
			_route_biomes.append(&"volcano")
		else:
			var pick: int = _rng.randi_range(0, biomes.size() - 1)
			_route_biomes.append(biomes[pick])
			biomes.remove_at(pick)


func _make_options() -> void:
	var hurt: bool = context.hp < context.max_hp
	_options.append({"title": "Field Repairs", "short": "Field Repairs",
		"text": "Heal 50 HP (now %d/%d)." % [int(context.hp), int(context.max_hp)],
		"reason": "" if hurt else "HP already full",
		"apply": func() -> void: context.hp = minf(context.max_hp, context.hp + 50.0)})
	_options.append({"title": "Ammo Crate", "short": "Ammo Crate",
		"text": "Refill Shotgun and Heavy Pistol ammo.",
		"reason": "Ammo already full" if _ammo_full() else "",
		"apply": func() -> void: context.ammo = PackedInt32Array()})  # empty = full ammo on landing
	var pool: Array[GameData.Card] = []
	for c in GameData.cards():
		if context.card_stacks.get(c.id, 0) < c.max_stacks:
			pool.append(c)
	if not pool.is_empty():
		var card: GameData.Card = pool[_rng.randi_range(0, pool.size() - 1)]
		_options.append({"title": "Card: " + card.title, "short": card.title, "text": card.description, "reason": "",
			"apply": func() -> void: context.card_stacks[card.id] = context.card_stacks.get(card.id, 0) + 1})


## True when an Ammo Crate would change nothing: every owned weapon that
## uses ammo is at its maximum (the same maximum IslandRun.max_ammo uses,
## before a route's Supply Shortage). Empty ammo = full on landing.
func _ammo_full() -> bool:
	var weapons: Array[GameData.Weapon] = GameData.weapons()
	if context.ammo.size() != weapons.size():
		return true
	for w in weapons.size():
		var most: int = weapons[w].max_ammo
		if most <= 0 or not context.weapons.has(weapons[w].id):
			continue
		if context.has_perk(&"pack_rat"):
			most = most * 3 / 2
		most = int(most * (1.0 + 0.3 * context.card_stacks.get(&"bigger_mags", 0)))
		if context.ammo[w] < most:
			return false
	return true


func _first_useful() -> int:
	for i in _options.size():
		if _options[i]["reason"] == "":
			return i
	return -1


# --- Layout --------------------------------------------------------------------

func _screen() -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


## Kicker (left), screen title (centre), progress pips (right), then a line.
func _header(screen: VBoxContainer, kicker: String, heading_text: String) -> void:
	var row := HBoxContainer.new()
	screen.add_child(row)
	var left := UiTheme.label(kicker, 13, UiTheme.MUTED, true)
	left.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.custom_minimum_size.x = 230
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	var heading := UiTheme.title(heading_text, 32)
	heading.name = "Heading"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(heading)
	var pips := RouteMap.Pips.new(context.island_count(), context.island_index)
	pips.name = "Progress"
	pips.custom_minimum_size.x = maxf(230, pips.custom_minimum_size.x)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	screen.add_child(HSeparator.new())


func _body(screen: VBoxContainer) -> HBoxContainer:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	screen.add_child(body)
	return body


## Left panel: whatever the chart is, with the run status line under it.
func _chart_panel(body: HBoxContainer) -> VBoxContainer:
	var plate := PanelContainer.new()
	plate.custom_minimum_size.x = 300
	plate.add_theme_stylebox_override("panel", _style(UiTheme.PANEL, UiTheme.LINE, 1, 12))
	body.add_child(plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	plate.add_child(box)
	_status = UiTheme.label("", 14, UiTheme.MUTED, true)
	_status.name = "Status"
	box.add_child(_status)
	_refresh_status()
	return box


func _right_column(body: HBoxContainer) -> VBoxContainer:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)
	return right


## One route: picture, "A · JUNGLE" (+ tick when selected), the mission in
## words, then the modifier (▲ penalty) and the Intel multiplier (◆).
func _route_card(i: int) -> Button:
	var biome_name: String = String(GameData.BIOMES[_route_biomes[i]]["name"])
	var mission: Dictionary = GameData.MISSIONS[_route_missions[i]]
	var mod: GameData.Modifier = _routes[i]
	var rb := Button.new()
	rb.name = "Route_%d" % (i + 1)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rb.accessibility_name = "Route %s: %s, %s. %s. %s, Intel ×%.1f" % [RouteMap.LETTERS[i], biome_name, mission["name"], mission["text"], mod.title, mod.intel_mult]
	rb.tooltip_text = "%s: %s" % [mission["name"], mission["text"]]
	rb.pressed.connect(_on_route_pressed.bind(i))
	var card := _card_content(rb, 12)
	var preview := RoutePreview.new()
	preview.biome = _route_biomes[i]
	preview.custom_minimum_size.y = PICTURE_HEIGHT
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL  # spare height goes to the picture
	card.add_child(preview)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_row)
	var title := UiTheme.title("%s · %s" % [RouteMap.LETTERS[i], biome_name.to_upper()], 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_row.add_child(title)
	var mark := _tick_tag("SELECTED")
	mark.name = "SelectionState"
	mark.visible = false
	name_row.add_child(mark)
	card.add_child(_mission_lines(_route_missions[i], mission["text"]))
	card.add_child(HSeparator.new())
	# Calm Waters is no penalty: neutral dot, not a red triangle.
	if mod.id == &"calm":
		card.add_child(_tagged_line("● " + mod.title.to_upper(), UiTheme.TEXT_MUTED, "no modifier"))
	else:
		card.add_child(_tagged_line("▲ " + mod.title.to_upper(), UiTheme.DANGER, mod.description))
	var intel := _tagged_line("◆ INTEL ×%.1f" % mod.intel_mult, UiTheme.ACCENT if mod.intel_mult > 1.0 else UiTheme.TEXT_MUTED,
		"more Intel for the risk" if mod.intel_mult > 1.0 else "standard pay")
	card.add_child(intel)
	_route_buttons.append(rb)
	return rb


## Mission chip (INFO colour) and the one plain sentence of what to do.
func _mission_lines(mission: StringName, text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Mission"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var chip := UiTheme.label("● " + Expeditions.mission_name(mission).to_upper(), 13, UiTheme.INFO)
	chip.add_theme_font_override("font", UiTheme.mono_bold_font())
	chip.name = "MissionName"
	box.add_child(chip)
	var about := UiTheme.label(text, 16)
	about.name = "MissionText"
	box.add_child(about)
	return box


## "▲ SEA FOG · you see enemies late": coloured mono tag, plain explanation.
func _tagged_line(tag: String, color: Color, text: String) -> RichTextLabel:
	var line := RichTextLabel.new()
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.focus_mode = Control.FOCUS_NONE
	line.push_font(UiTheme.mono_bold_font(), 13)
	line.push_color(color)
	line.add_text(tag)
	line.pop()
	line.pop()
	line.push_font(UiTheme.body_font(), 14)
	line.add_text("  · " + text)
	line.pop()
	return line


## Tick + word, in the "selected" colour.
func _tick_tag(text: String) -> HBoxContainer:
	var tag := HBoxContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = UiTheme.tick_icon()
	icon.modulate = UiTheme.SUCCESS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(icon)
	if text != "":
		var word := UiTheme.label(text, 12, UiTheme.SUCCESS)
		word.add_theme_font_override("font", UiTheme.mono_bold_font())
		word.autowrap_mode = TextServer.AUTOWRAP_OFF
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_child(word)
	return tag


## A margin + VBox laid over a Button, so a card can hold several labels.
func _card_content(b: Button, pad: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, pad)
	b.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return box


## "QUARTERMASTER / ONE SUPPLY PER LANDING" and the supply tiles. A supply
## that would do nothing is disabled (dashed) and says why.
func _supply_row(parent: VBoxContainer, caption: String = "QUARTERMASTER / ONE SUPPLY PER LANDING") -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var head := UiTheme.label(caption, 12, UiTheme.MUTED, true)
	head.name = "SupplyCaption"
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for i in _options.size():
		var option: Dictionary = _options[i]
		var useless: bool = option["reason"] != ""
		var b := Button.new()
		b.name = "Supply_%d" % (i + 1)
		b.custom_minimum_size.y = SUPPLY_HEIGHT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.disabled = useless
		b.focus_mode = Control.FOCUS_NONE if useless else Control.FOCUS_ALL
		b.tooltip_text = option["reason"] if useless else option["text"]
		b.accessibility_name = "%s: %s" % [option["title"], option["reason"] if useless else option["text"]]
		b.pressed.connect(_on_supply_pressed.bind(i))
		var card := _card_content(b, 10)
		card.add_theme_constant_override("separation", 2)
		var title_row := HBoxContainer.new()
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_theme_constant_override("separation", 6)
		card.add_child(title_row)
		var mark := _tick_tag("")
		mark.name = "SelectionState"
		mark.visible = false
		title_row.add_child(mark)
		var title := UiTheme.label(option["title"], 20, UiTheme.TEXT_MUTED if useless else UiTheme.TEXT)
		title.add_theme_font_override("font", UiTheme.heading_font())
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		var text := UiTheme.label(option["reason"] if useless else option["text"], 14, UiTheme.TEXT_MUTED if useless else UiTheme.TEXT)
		text.name = "Reason" if useless else "Effect"
		text.max_lines_visible = 2
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(text)
		row.add_child(b)
		_buttons.append(b)


## Hints from the real bindings (left) and the primary button (right).
func _footer(screen: VBoxContainer, routes: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	screen.add_child(row)
	var hints := HBoxContainer.new()
	hints.name = "Hints"
	hints.add_theme_constant_override("separation", 16)
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hints)
	var pad: bool = not Input.get_connected_joypads().is_empty()
	if routes:
		_hint(hints, [_key_name(&"menu_route_1", pad), _key_name(&"menu_route_2", pad)], "ROUTE")
	_hint(hints, ["D-PAD" if pad else "↑↓←→"], "MOVE")
	_hint(hints, [_key_name(&"ui_accept", pad)], "CHOOSE")
	_hint(hints, [_key_name(&"ui_cancel", pad)], "BACK")
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_land = Button.new()
	_land.name = "Deploy"
	_land.theme_type_variation = &"PrimaryButton"
	_land.custom_minimum_size = Vector2(400, 56)
	_land.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_land.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_land.pressed.connect(_land_now)
	row.add_child(_land)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 14)
	_land.add_child(margin)
	_land_content = margin
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(inner)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(words)
	_land_title = UiTheme.label("", 26, UiTheme.ON_ACCENT)
	_land_title.name = "DeployTitle"
	_land_title.add_theme_font_override("font", UiTheme.title_font())
	_land_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(_land_title)
	_land_sub = UiTheme.label("", 14, UiTheme.ON_ACCENT)
	_land_sub.name = "DeploySub"
	_land_sub.add_theme_font_override("font", UiTheme.body_bold_font())
	_land_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(_land_sub)
	var key := UiTheme.label(_key_name(&"ui_accept", pad), 14, UiTheme.ACCENT)
	key.name = "DeployKey"
	key.add_theme_font_override("font", UiTheme.mono_bold_font())
	key.add_theme_stylebox_override("normal", _style(UiTheme.ON_ACCENT, UiTheme.ON_ACCENT, 0, 6, 12))
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(key)


## One hint: keycaps then a word ("[LB] [RB] ROUTE").
func _hint(parent: HBoxContainer, keys: Array, word: String) -> void:
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 6)
	parent.add_child(hint)
	for k: String in keys:
		var cap := Label.new()
		cap.theme_type_variation = &"KeyLabel"
		cap.text = k
		cap.add_theme_font_size_override("font_size", 13)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hint.add_child(cap)
	var label := UiTheme.label(word, 13, UiTheme.MUTED, true)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_child(label)


## Short name of the first binding of `action` for the device in use:
## gamepad button (LB, A…) when a pad is connected, else the key.
func _key_name(action: StringName, pad: bool) -> String:
	var bindings: Array = GameInput.ACTIONS.get(action, [])
	if bindings.is_empty() and InputMap.has_action(action):
		for e: InputEvent in InputMap.action_get_events(action):
			if pad and e is InputEventJoypadButton:
				return _pad_name((e as InputEventJoypadButton).button_index)
			if not pad and e is InputEventKey:
				var k := e as InputEventKey
				var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
				return "ESC" if code == KEY_ESCAPE else OS.get_keycode_string(code).to_upper()
	for b: Variant in bindings:
		if pad and b is String and String(b).begins_with("joy:"):
			return _pad_name(int(String(b).get_slice(":", 1)))
		if not pad and b is int:
			return OS.get_keycode_string(b).to_upper()
	# ui_* actions: GameInput only adds the pad side; the keys are Godot's.
	if action == &"ui_accept":
		return "A" if pad else "ENTER"
	if action == &"ui_cancel":
		return "B" if pad else "ESC"
	return "?"


static func _pad_name(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "START"
		JOY_BUTTON_BACK: return "VIEW"
	return "PAD %d" % button


static func _style(bg: Color, border: Color, width: int, pad: int, radius: int = UiTheme.RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


## Card look by state: selected = 2 px outline (`selected_color`) on a
## raised panel; otherwise panel + line, lit outline on hover. Focus keeps
## the theme's brackets; disabled keeps the theme's dashed box.
func _paint(b: Button, selected: bool, selected_color: Color) -> void:
	var base: StyleBoxFlat
	var hover: StyleBoxFlat
	if selected:
		base = _style(UiTheme.PANEL_RAISED, selected_color, 2, 0)
		hover = _style(UiTheme.PANEL_RAISED.lightened(0.05), selected_color, 2, 0)
	else:
		base = _style(UiTheme.PANEL, UiTheme.LINE, 1, 0)
		hover = _style(UiTheme.PANEL_RAISED, UiTheme.TEXT, 1, 0)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", base)
	b.add_theme_stylebox_override("hover_pressed", hover)
	var mark: Control = b.find_child("SelectionState", true, false) as Control
	if mark != null:
		mark.visible = selected


# --- Choices and focus ---------------------------------------------------------

func _on_route_pressed(i: int) -> void:
	_pick_route(i)
	_supply_target().grab_focus()


func _on_supply_pressed(i: int) -> void:
	_pick(i)


## Selects supply `i` (if it would do something) and moves focus to DEPLOY.
## Applied on DEPLOY, not here.
func _pick(i: int) -> void:
	if _applied or not _select_supply(i):
		return
	if is_inside_tree():
		_land.grab_focus()


func _select_supply(i: int) -> bool:
	if i < 0 or i >= _options.size() or _options[i]["reason"] != "":
		return false
	_supply = i
	for k in _buttons.size():
		if not _buttons[k].disabled:
			_paint(_buttons[k], k == i, UiTheme.SUCCESS)
	_update_land()
	return true


## Selects route `i` (LB/RB, 4/5, or A on its card). Focus does not move.
func _pick_route(i: int) -> void:
	if _applied:
		return
	_select_route(i)


func _select_route(i: int) -> void:
	if i < 0 or i >= _routes.size():
		return
	_route = i
	context.modifier = _routes[i].id
	context.biome = _route_biomes[i]
	context.mission = _route_missions[i]
	_map.selected = i
	for k in _route_buttons.size():
		_paint(_route_buttons[k], k == i, UiTheme.ACCENT)
	_update_land()


func _useful_supplies() -> Array[Button]:
	var out: Array[Button] = []
	for b in _buttons:
		if not b.disabled:
			out.append(b)
	return out


## Where "down" from the routes (or "back" from DEPLOY) lands.
func _supply_target() -> Control:
	if _supply >= 0:
		return _buttons[_supply]
	var useful := _useful_supplies()
	return useful[0] if not useful.is_empty() else _land


func _route_target() -> Control:
	return _route_buttons[maxi(_route, 0)] if not _route_buttons.is_empty() else null


## Focus neighbours: routes (left/right) -> supplies (left/right) -> DEPLOY.
## Rewired after each choice so "down" goes to what is selected.
func _wire_focus() -> void:
	var supplies := _useful_supplies()
	var up_from_supplies: Control = _route_target()
	var order: Array[Control] = []
	for b in _route_buttons:
		order.append(b)
	for b in supplies:
		order.append(b)
	order.append(_land)
	for row: Array in [_route_buttons, supplies]:
		for k in row.size():
			var b: Control = row[k]
			b.focus_neighbor_left = b.get_path_to(row[posmod(k - 1, row.size())])
			b.focus_neighbor_right = b.get_path_to(row[(k + 1) % row.size()])
	for b in _route_buttons:
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(_supply_target())
	for b in supplies:
		b.focus_neighbor_top = b.get_path_to(up_from_supplies if up_from_supplies != null else b)
		b.focus_neighbor_bottom = b.get_path_to(_land)
	var above: Control = _supply_target()
	if above == _land:
		above = up_from_supplies if up_from_supplies != null else _land
	_land.focus_neighbor_top = _land.get_path_to(above)
	_land.focus_neighbor_bottom = _land.get_path_to(_land)
	_land.focus_neighbor_left = _land.get_path_to(_land)
	_land.focus_neighbor_right = _land.get_path_to(_land)
	for k in order.size():
		order[k].focus_next = order[k].get_path_to(order[(k + 1) % order.size()])
		order[k].focus_previous = order[k].get_path_to(order[posmod(k - 1, order.size())])


## B / Esc: one row back up (DEPLOY -> supplies -> routes).
func _back() -> void:
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus == _land:
		var above: Control = _land.get_node(_land.focus_neighbor_top) as Control
		if above != null:
			above.grab_focus()
	elif focus != null and _buttons.has(focus):
		var target: Control = _route_target()
		if target != null:
			target.grab_focus()


func _update_land() -> void:
	if _land == null:
		return
	_land.disabled = not _can_land()
	_land_title.text = _land_text()
	_land_sub.text = _land_detail()
	_land_title.add_theme_color_override("font_color", UiTheme.TEXT_MUTED if _land.disabled else UiTheme.ON_ACCENT)
	_land_sub.add_theme_color_override("font_color", UiTheme.TEXT_MUTED if _land.disabled else UiTheme.ON_ACCENT)
	_land.accessibility_name = "%s, %s" % [_land_title.text, _land_sub.text]
	# A Button does not grow with its children: size it to the longest text.
	_land.custom_minimum_size.x = maxf(400, _land_content.get_combined_minimum_size().x)
	_wire_focus()


## A supply must be chosen, unless none would do anything.
func _supply_ready() -> bool:
	return _supply >= 0 or _first_useful() < 0


func _can_land() -> bool:
	return _route >= 0 and _supply_ready()


func _land_text() -> String:
	if _route < 0:
		return "CHOOSE A ROUTE"
	return "DEPLOY TO " + String(GameData.BIOMES[_route_biomes[_route]]["name"]).to_upper()


## "<mission> · with <supply>".
func _land_detail() -> String:
	var what: String = Expeditions.mission_name(context.mission) if _route >= 0 or _routes.is_empty() else "Pick a route"
	if _supply >= 0:
		return "%s · with %s" % [what, _options[_supply]["short"]]
	return "%s · %s" % [what, "no supply needed" if _supply_ready() else "choose a supply"]


func _apply_supply() -> void:
	if _applied:
		return
	_applied = true
	if _supply >= 0:
		(_options[_supply]["apply"] as Callable).call()
	_refresh_status()


## DEPLOY: apply the supply, then Director Hale's briefing (Dialogue
## Manager), then land.
func _land_now() -> void:
	if not _can_land() or _applied:
		return  # also stops a second press while the briefing is open
	_apply_supply()
	var dialogue: Resource = load(Briefing.RESOURCE) if ResourceLoader.exists(Briefing.RESOURCE) else null
	if dialogue == null or get_node_or_null("/root/DialogueManager") == null:
		land_requested.emit()  # addon missing: land straight away
		return
	_briefing = DialogueBox.open(self, dialogue, "start", [{"briefing": Briefing.new(context)}])
	_briefing.finished.connect(func() -> void: land_requested.emit())


func _refresh_status() -> void:
	if _status != null:
		_status.text = "HP %d/%d · LVL %d · INTEL %d" % [int(context.hp), int(context.max_hp), context.level, context.intel]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or is_instance_valid(_briefing):
		return
	if event.is_action_pressed(&"ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
		return
	# Number keys pick a supply; the pad's X/Y/B (also bound to card_N) do
	# not, so B only ever means "back" here.
	if event is InputEventKey:
		for i in 3:
			if event.is_action_pressed(StringName("card_%d" % (i + 1))):
				_pick(i)
				get_viewport().set_input_as_handled()
				return
	for i in 2:
		if event.is_action_pressed(StringName("menu_route_%d" % (i + 1))):
			_pick_route(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"confirm") and _can_land():
		get_viewport().set_input_as_handled()
		_land_now()
