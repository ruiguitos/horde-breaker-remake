class_name SettingsPanel
extends ColorRect
## Settings overlay (title, armory and pause menus): Master / Sound Effects /
## Music volume, graphics quality and fullscreen. Each volume row has a
## slider and an editable percentage field that stay in sync. Changes apply
## immediately and are saved in the profile.

signal closed

var profile: Profile


static func open(parent: Control, p: Profile) -> SettingsPanel:
	var s := SettingsPanel.new()
	s.profile = p
	parent.add_child(s)
	return s


func _ready() -> void:
	color = Color(0, 0, 0, 0.7)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UiTheme.get_theme()
	var box: VBoxContainer = UiTheme.centered_panel(self, 560)
	box.add_child(UiTheme.title("SETTINGS", 30))
	var first: HSlider = _volume_row(box, "Master volume", profile.master_volume,
		func(v: int) -> void: profile.master_volume = v)
	_volume_row(box, "Sound effects", profile.sfx_volume, func(v: int) -> void: profile.sfx_volume = v)
	_volume_row(box, "Music", profile.music_volume, func(v: int) -> void: profile.music_volume = v)

	var gfx := Button.new()
	gfx.text = _gfx_text()
	gfx.pressed.connect(func() -> void:
		profile.graphics_high = not profile.graphics_high
		Visuals.high_quality = profile.graphics_high
		gfx.text = _gfx_text()
		profile.save())
	box.add_child(gfx)
	var full := Button.new()
	full.text = "TOGGLE FULLSCREEN (F11)"
	full.pressed.connect(func() -> void:
		var is_full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if is_full else DisplayServer.WINDOW_MODE_FULLSCREEN))
	box.add_child(full)
	var close := Button.new()
	close.text = "BACK (Esc)"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(_close)
	box.add_child(close)
	add_child(UiSfx.new())
	first.grab_focus()


func _gfx_text() -> String:
	return "GRAPHICS: %s" % ("HIGH (bloom + SSAO)" if profile.graphics_high else "LOW")


## One row: name | slider 0-100 | editable "NN" field + "%".
## Returns the slider (so the panel can focus it for gamepad/keyboard use).
func _volume_row(parent: Control, label_text: String, value: int, setter: Callable) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(170, 0)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.value = value
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)
	var field := LineEdit.new()
	field.text = str(value)
	field.custom_minimum_size = Vector2(64, 0)
	field.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	field.max_length = 3
	row.add_child(field)
	var pct := Label.new()
	pct.text = "%"
	row.add_child(pct)

	var apply := func(v: int) -> void:
		v = clampi(v, 0, 100)
		setter.call(v)
		profile.apply_volume()
		profile.save()
	slider.value_changed.connect(func(v: float) -> void:
		if field.text != str(int(v)):
			field.text = str(int(v))
		apply.call(int(v)))
	# Typing: accept digits only; apply on Enter or when the field loses focus.
	var commit := func() -> void:
		var v: int = clampi(int(field.text) if field.text.is_valid_int() else int(slider.value), 0, 100)
		field.text = str(v)
		slider.set_value_no_signal(v)
		apply.call(v)
	field.text_submitted.connect(func(_t: String) -> void: commit.call())
	field.focus_exited.connect(commit)
	field.text_changed.connect(func(t: String) -> void:
		var digits: String = ""
		for ch in t:
			if ch >= "0" and ch <= "9":
				digits += ch
		if digits != t:
			field.text = digits
			field.caret_column = digits.length())
	return slider


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause") or (event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE):
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	profile.save()
	closed.emit()
	queue_free()
