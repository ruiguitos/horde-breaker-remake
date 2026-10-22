class_name DevMenu
extends Control
## The in-island dev menu (docs/design/DEV_MENU.md, zona 2). F2 opens the panel
## on the right; the line at the top left lists the options that change the
## balance, open or not. The island creates it only in debug builds. The game
## keeps running while the panel is open, and the mouse is free.

const PANEL_WIDTH: float = 300.0

var run: IslandRun  ## bound by the island; the controls act on it
var _panel: PanelContainer
var _balance: Label
var _speed: Label
var _horde: Label
var _weapons: Array[Button] = []
var _skip_boss: Button
var _skip_end: Button


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	theme = UiTheme.get_theme()
	Engine.time_scale = DevOptions.time_scale
	_balance = Label.new()
	_balance.position = Vector2(12, 12)
	_balance.add_theme_color_override("font_color", UiTheme.ACCENT)
	_balance.add_theme_font_size_override("font_size", 13)
	add_child(_balance)
	_panel = PanelContainer.new()
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_WIDTH
	_panel.offset_right = 0.0
	_panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.PANEL
	style.border_width_left = 1
	style.border_color = UiTheme.LINE
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)
	var scroll := ScrollContainer.new()
	_panel.add_child(scroll)
	var body := VBoxContainer.new()
	body.custom_minimum_size.x = PANEL_WIDTH - 32.0
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)
	_build(body)


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(_delta: float) -> void:
	_balance.visible = DevOptions.changes_balance()
	if _balance.visible:
		_balance.text = "Balance changed: " + ", ".join(DevOptions.active_labels())
	if _panel.visible:
		_refresh_skip()  # the run can finish while the panel is open


## Opens or closes the panel. Opening refreshes the readouts.
func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_refresh()


func is_open() -> bool:
	return _panel.visible


func _build(body: VBoxContainer) -> void:
	var title := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Dev menu"
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(name_label)
	var hint := Label.new()
	hint.text = "F2 closes"
	hint.add_theme_color_override("font_color", UiTheme.MUTED)
	hint.add_theme_font_size_override("font_size", 12)
	title.add_child(hint)
	body.add_child(title)

	_heading(body, "Player")
	_check(body, "Invincible", DevOptions.invincible, func(on: bool) -> void: DevOptions.invincible = on)
	_check(body, "Infinite ammo", DevOptions.infinite_ammo, func(on: bool) -> void: DevOptions.infinite_ammo = on)
	_check(body, "Noclip", run != null and run.noclip, func(on: bool) -> void:
		if run != null:
			run.noclip = on)

	_heading(body, "Game speed")
	_speed = Label.new()
	body.add_child(_speed)
	var speed := _slider(body, 0.1, 2.0, 0.1, DevOptions.time_scale)
	speed.value_changed.connect(func(v: float) -> void:
		DevOptions.time_scale = v
		Engine.time_scale = v
		_speed.text = "%.1f×" % v)

	_heading(body, "Enemies alive")
	_horde = Label.new()
	body.add_child(_horde)
	var horde := _slider(body, 1.0, float(GameData.HORDE_CAP), 1.0, _horde_value())
	horde.value_changed.connect(func(v: float) -> void:
		DevOptions.horde_alive = int(v)
		if run != null:
			run.set_horde_alive(int(v))
		_horde.text = "%d of %d (hard cap)" % [int(v), GameData.HORDE_CAP])

	_heading(body, "Spawn at aim point")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for i in GameData.enemy_types().size():
		var kind: int = i
		var enemy_name: String = GameData.enemy_types()[i].display_name
		_button(grid, enemy_name, func() -> void:
			if run != null:
				run.dev_spawn(kind))

	_heading(body, "Weapon")
	var weapons := VBoxContainer.new()
	weapons.add_theme_constant_override("separation", 6)
	body.add_child(weapons)
	if run != null:
		for i in run.weapons.size():
			var index: int = i
			var b := _button(weapons, run.weapons[i].display_name, func() -> void:
				if run != null:
					run.switch_weapon(index)
					_refresh())
			_weapons.append(b)

	_heading(body, "Progress")
	var progress := HBoxContainer.new()
	progress.add_theme_constant_override("separation", 6)
	body.add_child(progress)
	_button(progress, "+1 level", func() -> void:
		if run != null and run.xp_needed() > run.xp:
			run.dev_grant_xp(run.xp_needed() - run.xp))
	_button(progress, "+100 XP", func() -> void:
		if run != null:
			run.dev_grant_xp(100))

	_heading(body, "Skip")
	var skip := HBoxContainer.new()
	skip.add_theme_constant_override("separation", 6)
	body.add_child(skip)
	_skip_boss = _button(skip, "To boss", func() -> void:
		if run != null:
			run.dev_skip_to_boss()
			_refresh())
	_skip_boss.name = "SkipToBoss"
	_skip_end = _button(skip, "To end", func() -> void:
		if run != null:
			run.dev_skip_to_end()
			_refresh())
	_skip_end.name = "SkipToEnd"

	var footer := Label.new()
	footer.text = "Dev run: no profile, Intel or telemetry is saved."
	footer.add_theme_color_override("font_color", UiTheme.MUTED)
	footer.add_theme_font_size_override("font_size", 11)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(footer)
	_refresh()


func _refresh() -> void:
	_speed.text = "%.1f×" % DevOptions.time_scale
	_horde.text = "%d of %d (hard cap)" % [_horde_value(), GameData.HORDE_CAP]
	_refresh_skip()
	if run != null:
		for i in _weapons.size():
			var name_text: String = run.weapons[i].display_name
			_weapons[i].text = ("> " if i == run.weapon_index else "") + name_text


func _refresh_skip() -> void:
	_skip_boss.disabled = run == null or not run.has_boss or run.objective != IslandRun.Objective.GENERATORS
	_skip_end.disabled = run == null or run.is_over()


func _horde_value() -> int:
	if DevOptions.horde_alive > 0:
		return DevOptions.horde_alive
	return run.director.max_alive if run != null else GameData.MAX_ALIVE


func _heading(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", UiTheme.MUTED)
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("line_spacing", 0)
	parent.add_child(label)


func _check(parent: Control, text: String, on: bool, action: Callable) -> void:
	var box := CheckButton.new()
	box.text = text
	box.button_pressed = on
	box.toggled.connect(action)
	parent.add_child(box)


func _slider(parent: Control, low: float, high: float, step: float, value: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = PANEL_WIDTH - 40.0
	parent.add_child(slider)
	return slider


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b
