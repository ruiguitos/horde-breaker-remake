class_name SettingsPanel
extends MenuDialog
## Settings split in categories (tabs): DISPLAY (window mode, resolution,
## VSync, FPS cap), GRAPHICS (quality preset, render scale, anti-aliasing),
## AUDIO (master / effects / music percentages, dialogue voice) and CONTROLS (camera mode,
## key icons and rebinding through G.U.I.D.E, mouse sensitivity).
## Every change is applied at once through GraphicsSettings / Profile and
## saved to the profile.

const TABS: Array[String] = ["DISPLAY", "GRAPHICS", "AUDIO", "CONTROLS"]

var profile: Profile
var tab: String = "DISPLAY"
var _body: VBoxContainer
var _tab_buttons: Array[Button] = []
var _capturing: StringName = &""  ## action waiting for a new key, or empty
var _detector: Node
var _panel: Control
var _body_scroll: ScrollContainer


static func open(parent: Control, p: Profile) -> SettingsPanel:
	var panel := SettingsPanel.new()
	panel.profile = p
	parent.add_child(panel)
	return panel


func _ready() -> void:
	super()
	_panel = content.get_parent()
	_panel.name = "SettingsFrame"
	get_viewport().size_changed.connect(_size_panel)
	_size_panel()
	content.add_child(UiTheme.title("SETTINGS", 36))
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	for t in TABS:
		var b := UiTheme.button(tabs, t, _show.bind(t))
		b.name = "Tab_" + t
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_tab_buttons.append(b)
	content.add_child(HSeparator.new())
	_body_scroll = ScrollContainer.new()
	_body_scroll.name = "SettingsContent"
	_body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body_scroll.follow_focus = true
	content.add_child(_body_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_body_scroll.add_child(_body)
	content.add_child(UiTheme.label("Changes apply immediately and are saved to your profile.", 16, UiTheme.MUTED))
	UiTheme.button(content, "DONE", _close, true)
	closed.connect(func() -> void: profile.save())
	_show(tab)
	Input.joy_connection_changed.connect(_controller_changed)


## A shared frame for every tab; long content scrolls instead of resizing it.
func _size_panel() -> void:
	var available: Vector2 = get_viewport_rect().size - Vector2(32, 32)
	_panel.custom_minimum_size = Vector2(minf(720, available.x), minf(580, available.y))


func _controller_changed(_device: int, _connected: bool) -> void:
	if tab == "CONTROLS" and _capturing == &"":
		_show(tab)


## Rebuilds the tab's content. `keep_scroll` and `focus_name` are for a rebuild
## that must not move the view: pressing REBIND used to jump back to the top of the
## list, because the tab was rebuilt and the scroll reset.
func _show(t: String, keep_scroll: bool = false, focus_name: String = "") -> void:
	var keep: int = _body_scroll.scroll_vertical if keep_scroll else 0
	tab = t
	_body_scroll.scroll_vertical = 0
	for b in _tab_buttons:
		_style_tab(b, b.name == "Tab_" + t)
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	match t:
		"DISPLAY": _display()
		"GRAPHICS": _graphics()
		"AUDIO": _audio()
		"CONTROLS": _controls()
	if keep_scroll:
		call_deferred("_restore_scroll_focus", keep, focus_name)
		return
	call_deferred("_trap_focus")
	# Keep focus on the tab that was pressed (the trap focuses the first one).
	call_deferred("_focus_tab", t)


## After a rebuild that must not move the view: the same scroll offset, and focus
## on the same control (the REBIND button the player just pressed).
func _restore_scroll_focus(scroll: int, control_name: String) -> void:
	if not is_instance_valid(_body_scroll):
		return
	_body_scroll.scroll_vertical = scroll
	var target: Control = null
	if control_name != "":
		target = _body.find_child(control_name, true, false) as Control
	if target != null and target.is_visible_in_tree():
		target.grab_focus()
	else:
		_trap_focus()


## Tabs read as parts of one panel: the selected tab has an amber base rule and
## a raised fill that runs into the content; the others are flat.
func _style_tab(b: Button, selected: bool) -> void:
	b.theme_type_variation = &""
	var box := StyleBoxFlat.new()
	box.bg_color = UiTheme.PANEL_RAISED if selected else Color(0, 0, 0, 0)
	box.border_color = UiTheme.ACCENT if selected else UiTheme.LINE
	box.set_border_width_all(0)
	box.border_width_bottom = 3 if selected else 1
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	for state in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(state, box)
	b.add_theme_color_override("font_color", UiTheme.ACCENT if selected else UiTheme.MUTED)

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
	_percent_row("HUD size", profile.hud_scale, 60, func(v: int) -> void:
		profile.hud_scale = v
		profile.save()
		get_tree().call_group(&"hud", &"apply_hud_scale"))
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
	# Field of view: the island camera picks it up at once (also in the pause menu).
	var set_fov := func(v: int) -> void:
		profile.fov = v
		profile.save()
	_percent_row("Field of view", profile.fov, 60, set_fov, 120, "°")
	_body.add_child(UiTheme.label("First person: 60°–120°. Third person and fixed camera: up to %d°." % Profile.THIRD_PERSON_MAX_FOV, 16, UiTheme.MUTED))


func _audio() -> void:
	var set_audio := func(setter: Callable) -> Callable:
		return func(v: int) -> void:
			setter.call(v)
			profile.apply_volume()
			profile.save()
	_percent_row("Master volume", profile.master_volume, 0, set_audio.call(func(v: int) -> void: profile.master_volume = v))
	_percent_row("Sound effects", profile.sfx_volume, 0, set_audio.call(func(v: int) -> void: profile.sfx_volume = v))
	_percent_row("Music", profile.music_volume, 0, set_audio.call(func(v: int) -> void: profile.music_volume = v))
	_toggle("Dialogue voice", profile.dialogue_voice, func(on: bool) -> void:
		profile.dialogue_voice = on
		profile.save())


func _controls() -> void:
	# The island picks the change up at once (V also cycles it in game).
	_options("Camera", Profile.CAMERA_MODE_NAMES, profile.camera_mode, func(i: int) -> void:
		profile.camera_mode = i
		profile.save())
	_percent_row("Mouse sensitivity", profile.mouse_sensitivity, 1, func(v: int) -> void:
		profile.mouse_sensitivity = v
		profile.save())
	var set_stick_speed := func(v: int) -> void:
		profile.stick_sensitivity = v
		profile.save()
	_percent_row("Stick look speed", profile.stick_sensitivity, 10, set_stick_speed, 200, "%")
	var set_stick_deadzone := func(v: int) -> void:
		profile.stick_deadzone = v
		profile.save()
	_percent_row("Stick dead zone", profile.stick_deadzone, 5, set_stick_deadzone, 40, "%")
	var headings := HBoxContainer.new()
	headings.add_theme_constant_override("separation", 10)
	_body.add_child(headings)
	for column: Array in [["ACTION", 180], ["KEY / MOUSE", 80], ["PAD", 80]]:
		var heading := UiTheme.label(column[0], 12, UiTheme.MUTED, true)
		heading.custom_minimum_size.x = column[1]
		headings.add_child(heading)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(list)
	for action: StringName in GameInput.REBINDABLE:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		list.add_child(row)
		var name_label := Label.new()
		name_label.text = GameInput.REBINDABLE[action]
		name_label.custom_minimum_size.x = 180
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
		var key_icon := _icon_label()
		key_icon.name = "Key_" + String(action)
		row.add_child(key_icon)
		var pad: Array = GameInput.ACTIONS[action].filter(func(b: Variant) -> bool: return not GameInput.is_kbm(b)).slice(0, 1)
		var pad_icon := _icon_label()
		pad_icon.name = "Pad_" + String(action)
		row.add_child(pad_icon)
		var b := Button.new()
		b.name = "Rebind_" + String(action)
		b.text = "PRESS KEY…" if _capturing == action else "REBIND"
		b.tooltip_text = "Press a key or mouse button. Esc cancels."
		b.custom_minimum_size.x = 100
		b.pressed.connect(_start_rebind.bind(action))
		row.add_child(b)
		InputIcons.fill(key_icon, [GameInput.current_binding(action, profile.key_bindings)])
		InputIcons.fill(pad_icon, pad)
	var reset := UiTheme.button(_body, "RESET DEFAULT KEYS", func() -> void:
		profile.key_bindings.clear()
		GameInput.apply_overrides(profile.key_bindings)
		profile.save()
		_show("CONTROLS"))
	reset.name = "ResetKeys"


func _icon_label() -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.custom_minimum_size = Vector2(80, 32)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Waits for the next key or mouse button (G.U.I.D.E input detector).
func _start_rebind(action: StringName) -> void:
	_capturing = action
	# Rebuild only the button label, keeping the scroll and the focus where they were:
	# a plain _show() reset the list to the top, which read as "it jumped to the menu above".
	_show("CONTROLS", true, "Rebind_" + String(action))
	if not InputIcons.available() or not has_node("/root/GUIDE"):
		return
	if _detector == null:
		_detector = load("res://addons/guide/remapping/guide_input_detector.gd").new()
		_detector.set("detection_countdown_seconds", 0.25)
		var esc: Resource = InputIcons.to_guide(KEY_ESCAPE)
		var abort: Array[GUIDEInput] = [esc as GUIDEInput]
		_detector.set("abort_detection_on", abort)
		add_child(_detector)
		_detector.connect("input_detected", func(input: Resource) -> void: _on_detected(_capturing, input))
	var devices: Array[GUIDEInput.DeviceType] = [GUIDEInput.DeviceType.KEYBOARD, GUIDEInput.DeviceType.MOUSE]
	_detector.call("detect_bool", devices)


## New binding detected (null = cancelled with Esc).
func _on_detected(action: StringName, input: Resource) -> void:
	var binding: Variant = InputIcons.from_guide(input)
	if action != &"" and binding != null and not GameInput.same(binding, KEY_ESCAPE):
		profile.key_bindings[String(action)] = GameInput.encode(binding)
		GameInput.apply_overrides(profile.key_bindings)
		profile.save()
	_capturing = &""
	_show("CONTROLS", true, "Rebind_" + String(action) if action != &"" else "")


func _input(event: InputEvent) -> void:
	# While waiting for a key, Esc cancels the capture instead of closing.
	if _capturing != &"":
		return
	super(event)


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


## Slider + editable value field kept in sync (min..max_value, percent by default).
func _percent_row(label_text: String, value: int, min_value: int, setter: Callable, max_value: int = 100, unit: String = "%") -> HSlider:
	var row := _row(label_text)
	var slider := HSlider.new()
	slider.name = "Slider_" + label_text.replace(" ", "_")
	slider.min_value = min_value
	slider.max_value = max_value
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
	pct.text = unit
	row.add_child(pct)

	slider.value_changed.connect(func(v: float) -> void:
		if field.text != str(int(v)):
			field.text = str(int(v))
		setter.call(int(v)))
	# Typing: accept digits only; apply on Enter or when the field loses focus.
	var commit := func() -> void:
		var v: int = clampi(int(field.text) if field.text.is_valid_int() else int(slider.value), min_value, max_value)
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

