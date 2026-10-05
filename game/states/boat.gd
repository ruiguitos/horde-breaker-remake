extends Control
## The boat between islands: pick 1 of 3 rewards, then land on the next island.
## Keys: 1/2/3 pick, Enter lands. Gamepad: X/Y/B pick, A lands.

signal land_requested

var context: RunContext

var _rng := RandomNumberGenerator.new()
var _options: Array[Dictionary] = []  ## {title, text, apply: Callable}
var _buttons: Array[Button] = []
var _picked: bool = false
var _land: Button
var _status: Label


func _ready() -> void:
	# The parent is a plain Node, so fill the window explicitly.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	_rng.seed = context.island_seed() + 1
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.16, 0.24)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# CenterContainer keeps the menu centred at any window size.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(680, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)
	var title := Label.new()
	title.text = "THE BOAT — next: island %d of %d" % [context.island_index + 1, RunContext.ISLAND_COUNT]
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var hint := Label.new()
	hint.text = "Pick one supply (1 / 2 / 3):"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_make_options()
	for i in _options.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(220, 140)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%d. %s\n\n%s" % [i + 1, _options[i]["title"], _options[i]["text"]]
		b.pressed.connect(_pick.bind(i))
		row.add_child(b)
		_buttons.append(b)
	_land = Button.new()
	_land.text = "LAND (Enter)"
	_land.custom_minimum_size = Vector2(0, 50)
	_land.disabled = true
	_land.pressed.connect(func() -> void: land_requested.emit())
	box.add_child(_land)
	_refresh_status()


func _make_options() -> void:
	_options.append({"title": "Field Repairs", "text": "Heal 50 HP.",
		"apply": func() -> void: context.hp = minf(GameData.PLAYER_MAX_HP, context.hp + 50.0)})
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


func _pick(i: int) -> void:
	if _picked or i < 0 or i >= _options.size():
		return
	_picked = true
	(_options[i]["apply"] as Callable).call()
	for k in _buttons.size():
		_buttons[k].disabled = true
		if k == i:
			_buttons[k].text = "✔ " + _buttons[k].text
	_land.disabled = false
	_land.grab_focus()
	_refresh_status()


func _refresh_status() -> void:
	_status.text = "HP %d/%d · Level %d · Kills %d · Intel this run %d" % [
		int(context.hp), int(GameData.PLAYER_MAX_HP), context.level, context.kills, context.intel]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key in [KEY_1, KEY_2, KEY_3]:
			_pick(key - KEY_1)
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _picked:
			land_requested.emit()
	elif event is InputEventJoypadButton and event.pressed:
		var pads: Array = [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B]
		if event.button_index in pads:
			_pick(pads.find(event.button_index))
		elif event.button_index == JOY_BUTTON_A and _picked:
			land_requested.emit()
