extends SceneTree
## Settings panel: slider and text field stay in sync, values are clamped,
## volumes reach the audio buses, and old profiles migrate.
## Run: godot --headless --path . --script res://tests/test_settings.gd

var _failures: int = 0
var _frames: int = 0
var _panel: SettingsPanel
var _profile: Profile
var _layout_done: bool = false
var _display_tested: bool = false


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_profile = Profile.new()
	_profile.master_volume = 80
	var host := Control.new()
	root.add_child(host)
	_panel = SettingsPanel.open(host, _profile)
	call_deferred("_test_layout")


func _test_layout() -> void:
	await process_frame
	await process_frame
	var panel: Control = _panel.content.get_parent()
	var initial: Rect2 = panel.get_global_rect()
	for category in SettingsPanel.TABS:
		_panel.call("_show", category)
		await process_frame
		await process_frame
		_check(panel.get_global_rect().is_equal_approx(initial), "Settings keeps the same position and size on " + category)
	var icons: OptionButton = _panel.find_child("Option_Controller_icons", true, false)
	_check(icons != null, "Controls offers automatic and platform-specific controller icons")
	if icons != null:
		icons.item_selected.emit(2)
		_check(_profile.get("controller_icons") == 2, "PlayStation icon preference is saved to the profile")
	_check(InputIcons.text("joy:0", 2) == "Cross" and InputIcons.text("joy:0", 1) == "A", "same physical button has PlayStation and Xbox labels")
	_check(InputIcons.text("joy:0", 3) == "B" and InputIcons.platform_for_name("DualSense Wireless Controller") == 2
		and InputIcons.platform_for_name("Nintendo Switch Pro Controller") == 3 and InputIcons.platform_for_name("Steam Deck") == 4,
		"Nintendo button positions and automatic controller identification")
	var direction: Resource = InputIcons.to_guide("axis:0:-1")
	_check(direction.get("direction") == 1, "movement icon retains its left/up direction")
	_profile.save("user://test_icon_profile.json")
	_check(Profile.load_profile("user://test_icon_profile.json").controller_icons == 2, "controller icon choice survives saving and loading")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_icon_profile.json"))
	_check(Profile.from_dict({"controller_icons": 900}).controller_icons == 4 and Profile.from_dict({}).controller_icons == 0,
		"old saves use automatic icons and invalid preferences are clamped")
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	for category in SettingsPanel.TABS:
		_panel.call("_show", category)
		await process_frame
		await process_frame
		var bounds: Rect2 = panel.get_global_rect()
		_check(root.get_visible_rect().encloses(bounds), "Settings frame fits a 640x360 window on " + category)
	root.size = Vector2i(1152, 648)
	_panel.call("_show", "DISPLAY")
	_layout_done = true


## Display and Graphics tabs: the options exist and change the engine.
func _test_display_graphics() -> void:
	_check(_panel.find_child("Option_Window_mode", true, false) != null and _panel.find_child("Toggle_VSync", true, false) != null,
		"Display tab: window mode, resolution, VSync, FPS limit")
	var fps: OptionButton = _panel.find_child("Option_FPS_limit", true, false)
	fps.select(2)
	fps.item_selected.emit(2)
	_check(_profile.max_fps == 60 and Engine.max_fps == 60, "FPS limit 60 caps the engine")
	_panel.call("_show", "GRAPHICS")
	var q: OptionButton = _panel.find_child("Option_Quality", true, false)
	q.select(GraphicsSettings.LOW)
	q.item_selected.emit(GraphicsSettings.LOW)
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	GraphicsSettings.apply_environment(env)
	GraphicsSettings.apply_sun(sun)
	_check(not env.ssao_enabled and not env.glow_enabled and not sun.shadow_enabled, "Low: no SSAO, bloom or shadows")
	q.select(GraphicsSettings.ULTRA)
	q.item_selected.emit(GraphicsSettings.ULTRA)
	GraphicsSettings.apply_environment(env)
	GraphicsSettings.apply_sun(sun)
	_check(env.ssao_enabled and env.ssil_enabled and sun.shadow_enabled, "Ultra: SSAO, SSIL and shadows")
	var scale: HSlider = _panel.find_child("Slider_3D_render_scale", true, false)
	scale.value = 70
	_check(is_equal_approx(root.scaling_3d_scale, 0.7), "render scale 70% reaches the viewport")
	var aa: OptionButton = _panel.find_child("Option_Anti-aliasing", true, false)
	aa.select(GraphicsSettings.AA_MSAA4)
	aa.item_selected.emit(GraphicsSettings.AA_MSAA4)
	_check(root.msaa_3d == Viewport.MSAA_4X, "MSAA 4x reaches the viewport")
	sun.free()
	Engine.max_fps = 0
	# HUD size: the slider scales the HUD's field panels live.
	var hud := Hud.new()
	hud.profile = _profile
	root.add_child(hud)
	_panel.call("_show", "DISPLAY")
	var hud_slider: HSlider = _panel.find_child("Slider_HUD_size", true, false)
	hud_slider.value = 70
	var field: Control = hud.find_child("FieldPanels", true, false)
	_check(_profile.hud_scale == 70 and field != null and is_equal_approx(field.scale.x, 0.7)
		and is_equal_approx(field.size.x * 0.7, root.get_visible_rect().size.x), "HUD size 70% scales the panels and keeps them full-screen")
	hud.queue_free()


## Controls tab: rebinding through the G.U.I.D.E detector result updates the
## InputMap and the profile; reset restores the defaults.
func _test_controls() -> void:
	GameInput.setup()
	_panel.call("_show", "CONTROLS")
	_check(_panel.find_child("Rebind_breaker", true, false) != null, "Controls tab lists rebindable actions")
	var key_f: Resource = InputIcons.to_guide(KEY_F)
	_check(InputIcons.from_guide(key_f) == KEY_F, "G.U.I.D.E key input converts both ways")
	_panel.call("_start_rebind", &"breaker")
	_panel.call("_on_detected", &"breaker", key_f)
	var has_f: bool = false
	var has_space: bool = false
	for e in InputMap.action_get_events(&"breaker"):
		if e is InputEventKey:
			has_f = has_f or e.physical_keycode == KEY_F
			has_space = has_space or e.physical_keycode == KEY_SPACE
	_check(has_f and not has_space and _profile.key_bindings.get("breaker") == "key:%d" % KEY_F,
		"rebinding Breaker to F replaces Space and is saved")
	var pad_kept: bool = InputMap.action_get_events(&"breaker").any(func(e: InputEvent) -> bool: return e is InputEventJoypadButton)
	_check(pad_kept, "gamepad bindings survive a keyboard rebind")
	var reset: Button = _panel.find_child("ResetKeys", true, false)
	reset.pressed.emit()
	var space_back: bool = InputMap.action_get_events(&"breaker").any(func(e: InputEvent) -> bool: return e is InputEventKey and e.physical_keycode == KEY_SPACE)
	_check(space_back and _profile.key_bindings.is_empty(), "reset restores Space")


func _process(_delta: float) -> bool:
	_frames += 1
	if not _layout_done:
		return false
	if not _display_tested:
		_display_tested = true
		_test_display_graphics()
		_panel.call("_show", "AUDIO")
		_frames = 0
		return false
	if _frames < 2:
		return false
	var sliders: Array = _panel.find_children("*", "HSlider", true, false)
	var fields: Array = _panel.find_children("*", "LineEdit", true, false)
	_check(sliders.size() == 3 and fields.size() == 3, "three volume rows (master, sfx, music)")
	var master_slider: HSlider = sliders[0]
	var master_field: LineEdit = fields[0]
	master_slider.value = 35
	_check(master_field.text == "35" and _profile.master_volume == 35, "moving the slider updates the field and the profile")
	var sfx_field: LineEdit = fields[1]
	sfx_field.text = "250"
	sfx_field.text_submitted.emit(sfx_field.text)
	_check(_profile.sfx_volume == 100 and sfx_field.text == "100" and (sliders[1] as HSlider).value == 100,
		"typing 250 is clamped to 100% and moves the slider")
	sfx_field.text = "4a2"
	sfx_field.text_changed.emit(sfx_field.text)
	_check(sfx_field.text == "42", "the field only accepts digits")
	sfx_field.text_submitted.emit(sfx_field.text)
	var bus: int = AudioServer.get_bus_index(Profile.BUS_SFX)
	_check(bus != -1 and is_equal_approx(AudioServer.get_bus_volume_db(bus), linear_to_db(0.42)), "the SFX bus volume follows the setting")
	# Migration from profile version 2 (single 0..10 volume).
	var path: String = "user://test_old_profile.json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string('{"version": 2, "volume": 6}')
	f.close()
	var old: Profile = Profile.load_profile(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(old.master_volume == 60 and old.sfx_volume == 100, "a v2 profile volume of 6/10 becomes 60%")
	_test_controls()
	var v3 := Profile.from_dict({"version": 3, "graphics_high": false})
	_check(v3.quality == GraphicsSettings.LOW, "a v3 Graphics: Low profile becomes the Low preset")
	quit(1 if _failures > 0 else 0)
	return false
