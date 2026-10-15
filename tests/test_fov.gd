extends SceneTree
## Field of view setting: default 60, range 60..120, saved with the profile,
## and the Graphics slider writes it to the profile.
## Run: godot --headless --path . --script res://tests/test_fov.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_check(Profile.new().fov == 60, "new profiles start at 60 degrees")
	_check(Profile.from_dict({}).fov == 60, "old saves without fov default to 60")
	_check(Profile.from_dict({"fov": 200}).fov == 120 and Profile.from_dict({"fov": 10}).fov == 60,
		"fov loaded from a save is clamped to 60..120")
	var path: String = "user://test_fov_profile.json"
	var p := Profile.new()
	p.fov = 95
	p.save(path)
	var loaded: Profile = Profile.load_profile(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(loaded.fov == 95, "fov survives saving and loading")
	_check(Profile.field_of_view(120, true) == 120.0 and Profile.field_of_view(60, true) == 60.0,
		"first person uses the whole 60..120 range")
	_check(Profile.field_of_view(120, false) == 75.0 and Profile.field_of_view(75, false) == 75.0 and Profile.field_of_view(60, false) == 60.0,
		"third person and fixed are capped at 75")
	var host := Control.new()
	root.add_child(host)
	var profile := Profile.new()
	var panel := SettingsPanel.open(host, profile)
	await process_frame
	await process_frame
	panel.call("_show", "GRAPHICS")
	await process_frame
	var slider: HSlider = panel.find_child("Slider_Field_of_view", true, false)
	_check(slider != null and slider.min_value == 60 and slider.max_value == 120, "Graphics tab has a field of view slider from 60 to 120")
	if slider != null:
		slider.value = 200
		_check(profile.fov == 120, "slider maximum (120) is saved to the profile")
		slider.value = 75
		_check(profile.fov == 75, "slider value is saved to the profile")
	quit(1 if _failures > 0 else 0)
