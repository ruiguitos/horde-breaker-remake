class_name SettingsPanel
extends MenuDialog
## Settings split in three categories (tabs): DISPLAY (window mode,
## resolution, VSync, FPS cap), GRAPHICS (quality preset, render scale,
## anti-aliasing) and AUDIO (master / effects / music percentages).
## Every change is applied at once through GraphicsSettings / Profile and
## saved to the profile.

const TABS: Array[String] = ["DISPLAY", "GRAPHICS", "AUDIO"]

var profile: Profile
var tab: String = "DISPLAY"
var _body: VBoxContainer
var _tab_buttons: Array[Button] = []


static func open(parent: Control, p: Profile) -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.profile = p
	parent.add_child(panel)
	return panel


func _ready() -> void:
	super()
	content.get_parent().custom_minimum_size.x = 720
	content.add_child(UiTheme.title("SETTINGS", 36))
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	for t in TABS:
		var b := UiTheme.button(tabs, t, _show.bind(t))
		b.name = "Tab_" + t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_buttons.append(b)
	content.add_child(HSeparator.new())
	_body = VBoxContainer.new()
	_body.custom_minimum_size.y = 300
	_body.add_theme_constant_override("separation", 10)
	content.add_child(_body)
	content.add_child(UiTheme.label("Changes apply immediately and are saved to your profile.", 16, UiTheme.MUTED))
	UiTheme.button(content, "DONE", _close, true)
	closed.connect(func() -> void: profile.save())
	_show(tab)


func _show(t: String) -> void:
	tab = t
	for b in _tab_buttons:
		b.theme_type_variation = &"SelectedButton" if b.name == "Tab_" + t else &""
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	match t:
		"DISPLAY": _display()
		"GRAPHICS": _graphics()
		"AUDIO": _audio()
	call_deferred("_trap_focus")
	# Keep focus on the tab that was pressed (the trap focuses the first one).
	call_deferred("_focus_tab", t)


func _focus_tab(t: String) -> void:
	for b in _tab_buttons:
		if b.name == "Tab_" + t:
			b.grab_focus()


func _display() -> void:
	_options("Window mode", GraphicsSettings.WINDOW_MODE_NAMES, profile.window_mode, func(i: int) -> void:
		profile.window_mode = i
		_apply_display())
	var names: Array[String] = []
	for r in GraphicsSettings.RESOLUTIONS:
		names.append("%d × %d" % [r.x, r.y])
	var res := _options("Resolution", names, GraphicsSettings.resolution_index(profile.resolution), func(i: int) -> void:
		profile.resolution = GraphicsSettings.RESOLUTIONS[i]
		_apply_display())
	res.disabled = profile.window_mode != GraphicsSettings.WINDOWED
	res.tooltip_text = "Fullscreen modes use the monitor's resolution; lower the 3D render scale (Graphics) for more FPS."
	_toggle("VSync", profile.vsync, func(on: bool) -> void:
		profile.vsync = on
		_apply_display())
	var caps: Array[String] = []
	for c in GraphicsSettings.FPS_CAPS:
		caps.append("Unlimited" if c == 0 else str(c))
	_options("FPS limit", caps, maxi(0, GraphicsSettings.FPS_CAPS.find(profile.max_fps)), func(i: int) -> void:
		profile.max_fps = GraphicsSettings.FPS_CAPS[i]
		_apply_display())


func _graphics() -> void:
	var info := UiTheme.label(GraphicsSettings.QUALITY_INFO[profile.quality], 16, UiTheme.MUTED)
	_options("Quality", GraphicsSettings.QUALITY_NAMES, profile.quality, func(i: int) -> void:
		profile.quality = i
		info.text = GraphicsSettings.QUALITY_INFO[i]
		_apply_graphics())
	_body.add_child(info)
	_percent_row("3D render scale", profile.render_scale, 50, func(v: int) -> void:
		profile.render_scale = v
		_apply_graphics())
	_options("Anti-aliasing", GraphicsSettings.AA_NAMES, profile.antialias, func(i: int) -> void:
		profile.antialias = i
		_apply_graphics())


func _audio() -> void:
	var set_audio := func(setter: Callable) -> Callable:
		return func(v: int) -> void:
			setter.call(v)
			profile.apply_volume()
			profile.save()
	_percent_row("Master volume", profile.master_volume, 0, set_audio.call(func(v: int) -> void: profile.master_volume = v))
	_percent_row("Sound effects", profile.sfx_volume, 0, set_audio.call(func(v: int) -> void: profile.sfx_volume = v))
	_percent_row("Music", profile.music_volume, 0, set_audio.call(func(v: int) -> void: profile.music_volume = v))


func _apply_display() -> void:
	GraphicsSettings.apply_display(profile)
	profile.save()
	_show("DISPLAY")  # refresh (e.g. Resolution is only editable in a window)


func _apply_graphics() -> void:
	GraphicsSettings.apply_graphics(profile, get_tree())
	profile.save()


func _row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_body.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(190, 0)
	row.add_child(label)
	return row


func _options(label_text: String, items: Array[String], selected: int, on_change: Callable) -> OptionButton:
	var row := _row(label_text)
	var ob := OptionButton.new()
	ob.name = "Option_" + label_text.replace(" ", "_")
	for item in items:
		ob.add_item(item)
	ob.select(selected)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ob.item_selected.connect(func(i: int) -> void: on_change.call(i))
	row.add_child(ob)
	return ob


func _toggle(label_text: String, on: bool, on_change: Callable) -> CheckButton:
	var row := _row(label_text)
	var cb := CheckButton.new()
	cb.name = "Toggle_" + label_text.replace(" ", "_")
	cb.button_pressed = on
	cb.text = "ON" if on else "OFF"
	cb.toggled.connect(func(v: bool) -> void:
		cb.text = "ON" if v else "OFF"
		on_change.call(v))
	row.add_child(cb)
	return cb


## Slider + editable percentage field kept in sync (min..100).
func _percent_row(label_text: String, value: int, min_value: int, setter: Callable) -> HSlider:
	var row := _row(label_text)
	var slider := HSlider.new()
	slider.name = "Slider_" + label_text.replace(" ", "_")
	slider.min_value = min_value
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

	slider.value_changed.connect(func(v: float) -> void:
		if field.text != str(int(v)):
			field.text = str(int(v))
		setter.call(int(v)))
	# Typing: accept digits only; apply on Enter or when the field loses focus.
	var commit := func() -> void:
		var v: int = clampi(int(field.text) if field.text.is_valid_int() else int(slider.value), min_value, 100)
		field.text = str(v)
		slider.set_value_no_signal(v)
		setter.call(v)
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
