class_name SettingsPanel
extends MenuDialog
## Three audio percentages share the menus' modal focus and input isolation.

var profile: Profile


static func open(parent: Control, p: Profile) -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.profile = p
	parent.add_child(panel)
	return panel


func _ready() -> void:
	super()
	content.add_child(UiTheme.title("SETTINGS", 36))
	content.add_child(UiTheme.label("SALVAGE & CO. / PERSONAL PREFERENCES", 16, UiTheme.MUTED, true))
	_volume_row(content, "Master volume", profile.master_volume, func(v: int) -> void: profile.master_volume = v)
	_volume_row(content, "Sound effects", profile.sfx_volume, func(v: int) -> void: profile.sfx_volume = v)
	_volume_row(content, "Music", profile.music_volume, func(v: int) -> void: profile.music_volume = v)
	var graphics := Button.new()
	graphics.custom_minimum_size.y = 48
	graphics.text = _gfx_text()
	content.add_child(graphics)
	graphics.pressed.connect(func() -> void:
		profile.graphics_high = not profile.graphics_high
		Visuals.high_quality = profile.graphics_high
		graphics.text = _gfx_text()
		for environment in get_tree().root.find_children("*", "WorldEnvironment", true, false):
			Visuals.apply_post((environment as WorldEnvironment).environment)
		profile.save())
	UiTheme.button(content, "TOGGLE FULLSCREEN / F11", func() -> void:
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN))
	content.add_child(UiTheme.label("Changes apply immediately and are saved to your profile.", 16, UiTheme.MUTED))
	UiTheme.button(content, "DONE", _close, true)
	closed.connect(func() -> void: profile.save())


func _gfx_text() -> String:
	return "GRAPHICS: " + ("HIGH / BLOOM + SSAO" if profile.graphics_high else "LOW")


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


func _close() -> void:
	close()
