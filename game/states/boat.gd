extends Control
## Supply choice followed by two routes; existing rewards and RNG order retained.

signal land_requested

var context: RunContext
var _rng := RandomNumberGenerator.new()
var _options: Array[Dictionary] = []
var _buttons: Array[Button] = []
var _picked: bool = false
var _land: Button
var _status: Label
var _routes: Array[GameData.Modifier] = []
var _route_buttons: Array[Button] = []
var _route_picked: bool = false
var _route_biomes: Array[StringName] = []
var _route_missions: Array[StringName] = []
var _map: RouteMap
var _supplies: ColorRect


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = context.island_seed() + 1
	theme = UiTheme.get_theme()
	UiTheme.backdrop(self)
	_make_options()
	_make_routes()
	var screen := UiTheme.screen(self)
	UiTheme.header(screen, "NEXT LANDING / ISLAND %02d OF %02d" % [context.island_index + 1, RunContext.ISLAND_COUNT])
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 24)
	screen.add_child(body)
	_map = RouteMap.new()
	_map.biomes = _route_biomes
	_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_map)
	for i in 2:
		var rb := Button.new()
		rb.custom_minimum_size.x = 252
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.size_flags_stretch_ratio = 0.7
		rb.pressed.connect(_pick_route.bind(i))
		rb.accessibility_name = "%s / %s / Intel ×%.1f" % [GameData.BIOMES[_route_biomes[i]]["name"], _routes[i].title, _routes[i].intel_mult]
		rb.tooltip_text = GameData.MISSIONS[_route_missions[i]]["text"]
		body.add_child(rb)
		_route_buttons.append(rb)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		for edge in ["left", "right", "top", "bottom"]:
			margin.add_theme_constant_override("margin_" + edge, 12)
		rb.add_child(margin)
		var card := VBoxContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_theme_constant_override("separation", 6)
		margin.add_child(card)
		var preview := RoutePreview.new()
		preview.biome = _route_biomes[i]
		preview.custom_minimum_size.y = 64
		card.add_child(preview)
		card.add_child(UiTheme.title(String(GameData.BIOMES[_route_biomes[i]]["name"]).to_upper(), 25))
		card.add_child(UiTheme.label(_routes[i].title.to_upper(), 20, UiTheme.SUCCESS if _routes[i].id == &"calm" else UiTheme.DANGER, true))
		card.add_child(UiTheme.label(_routes[i].description, 16, UiTheme.MUTED))
		card.add_child(HSeparator.new())
		card.add_child(UiTheme.label("OBJECTIVE", 16, UiTheme.MUTED, true))
		card.add_child(UiTheme.title(String(GameData.MISSIONS[_route_missions[i]]["name"]).to_upper(), 22))
		var gap := Control.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card.add_child(gap)
		card.add_child(UiTheme.label("INTEL MULTIPLIER / ×%.1f" % _routes[i].intel_mult, 20, UiTheme.ACCENT, true))
		var selection := UiTheme.label("[%d] / SELECT ROUTE" % (i + 4), 16, UiTheme.MUTED, true)
		selection.name = "SelectionState"
		card.add_child(selection)
	_status = UiTheme.label("", 16, UiTheme.MUTED, true)
	screen.add_child(_status)
	_land = UiTheme.button(screen, "CONFIRM ROUTE   →", _land_now, true)
	_land.disabled = true
	UiTheme.hints(screen, "[ 4–5 / LB–RB ] ROUTE     [ ENTER / A ] CONFIRM")
	_refresh_status()
	_show_supplies()
	add_child(UiSfx.new())
	add_child(Ambience.create(&"menu", -12.0))


func _make_routes() -> void:
	var mods: Array[GameData.Modifier] = GameData.modifiers()
	var a: int = _rng.randi_range(0, mods.size() - 1)
	var b: int = (a + _rng.randi_range(1, mods.size() - 1)) % mods.size()
	_routes = [mods[a], mods[b]]
	var biomes: Array[StringName] = GameData.ISLAND_BIOMES.duplicate()
	var missions: Array = GameData.MISSIONS.keys()
	for i in 2:
		_route_missions.append(missions[_rng.randi_range(0, missions.size() - 1)])
		if context.is_last_island():
			_route_biomes.append(&"volcano")
		else:
			var pick: int = _rng.randi_range(0, biomes.size() - 1)
			_route_biomes.append(biomes[pick])
			biomes.remove_at(pick)


func _make_options() -> void:
	_options.append({"title": "Field Repairs", "text": "Heal 50 HP.",
		"apply": func() -> void: context.hp = minf(context.max_hp, context.hp + 50.0)})
	_options.append({"title": "Ammo Crate", "text": "Refill Shotgun and Heavy Pistol ammo.",
		"apply": func() -> void: context.ammo = PackedInt32Array()})  # empty = full ammo on landing
	var pool: Array[GameData.Card] = []
	for c in GameData.cards():
		if context.card_stacks.get(c.id, 0) < c.max_stacks:
			pool.append(c)
	if not pool.is_empty():
		var card: GameData.Card = pool[_rng.randi_range(0, pool.size() - 1)]
		_options.append({"title": "Card: " + card.title, "text": card.description,
			"apply": func() -> void: context.card_stacks[card.id] = context.card_stacks.get(card.id, 0) + 1})


func _show_supplies() -> void:
	_supplies = ColorRect.new()
	_supplies.color = Color(0, 0, 0, 0.8)
	_supplies.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_supplies)
	var box := UiTheme.centered_panel(_supplies, 780)
	box.add_child(UiTheme.label("SALVAGE & CO. / QUARTERMASTER", 16, UiTheme.MUTED, true))
	box.add_child(UiTheme.title("01 / CHOOSE YOUR SUPPLY", 32))
	box.add_child(UiTheme.label("One allowance per landing. Generosity has a budget.", 16, UiTheme.MUTED))
	var row := HBoxContainer.new()
	box.add_child(row)
	for i in _options.size():
		var b := UiTheme.button(row, "%d / %s\n\n%s" % [i + 1, _options[i]["title"], _options[i]["text"]], _pick.bind(i))
		b.custom_minimum_size = Vector2(220, 160)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", 20)
		_buttons.append(b)
	for i in _buttons.size():
		var prev: NodePath = _buttons[i].get_path_to(_buttons[posmod(i - 1, _buttons.size())])
		var next: NodePath = _buttons[i].get_path_to(_buttons[(i + 1) % _buttons.size()])
		_buttons[i].focus_previous = prev
		_buttons[i].focus_next = next
		_buttons[i].focus_neighbor_left = prev
		_buttons[i].focus_neighbor_top = prev
		_buttons[i].focus_neighbor_right = next
		_buttons[i].focus_neighbor_bottom = next
	UiTheme.hints(box, "[ 1–3 / X–Y–B ] SUPPLY     [ ENTER / A ] SELECT")
	_buttons[0].grab_focus()


func _pick(i: int) -> void:
	if _picked or i < 0 or i >= _options.size():
		return
	_picked = true
	(_options[i]["apply"] as Callable).call()
	for k in _buttons.size():
		_buttons[k].disabled = true
		if k == i:
			_buttons[k].theme_type_variation = &"SelectedButton"
	_supplies.hide()
	_route_buttons[0].grab_focus()
	_update_land()


func _pick_route(i: int) -> void:
	if i < 0 or i >= _routes.size():
		return
	_route_picked = true
	context.modifier = _routes[i].id
	context.biome = _route_biomes[i]
	context.mission = _route_missions[i]
	_map.selected = i
	for k in _route_buttons.size():
		_route_buttons[k].theme_type_variation = &"SelectedButton" if k == i else &""
		var label: Label = _route_buttons[k].find_child("SelectionState", true, false) as Label
		label.text = "✓ SELECTED" if k == i else "[%d] / SELECT ROUTE" % (k + 4)
	_update_land()


func _update_land() -> void:
	_land.disabled = not _can_land()
	_refresh_status()
	if not _land.disabled:
		_land.grab_focus()


func _can_land() -> bool:
	return _picked and _route_picked


func _land_now() -> void:
	if _can_land():
		land_requested.emit()


func _refresh_status() -> void:
	var stage: String = "READY TO LAND" if _can_land() else ("02 / CHOOSE YOUR ROUTE" if _picked else "01 / CHOOSE YOUR SUPPLY")
	_status.text = "HP %d/%d / LEVEL %d / KILLS %d / INTEL %d   ·   %s" % [int(context.hp), int(context.max_hp), context.level, context.kills, context.intel, stage]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed():
		return
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
