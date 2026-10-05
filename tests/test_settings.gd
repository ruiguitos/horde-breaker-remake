extends SceneTree
## Settings panel: slider and text field stay in sync, values are clamped,
## volumes reach the audio buses, and old profiles migrate.
## Run: godot --headless --path . --script res://tests/test_settings.gd

var _failures: int = 0
var _frames: int = 0
var _panel: SettingsPanel
var _profile: Profile


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


func _process(_delta: float) -> bool:
	_frames += 1
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
	quit(1 if _failures > 0 else 0)
	return false
