extends SceneTree
## Right-stick look: the dead zone ignores small tilts, the rest is rescaled
## and multiplied by the sensitivity; the defaults keep today's behaviour;
## the values are clamped, saved, and offered in Settings > Controls.
## Run: godot --headless --path . --script res://tests/test_stick.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_check(Profile.stick_look(Vector2(0.1, 0.1), 100, 20) == Vector2.ZERO, "a tilt inside the dead zone does nothing")
	var full: Vector2 = Profile.stick_look(Vector2(1.0, 0.0), 100, 20)
	_check(absf(full.x - 1.0) < 0.001 and absf(full.y) < 0.001, "full tilt gives full look at 100%% (%s)" % [full])
	var half: Vector2 = Profile.stick_look(Vector2(0.6, 0.0), 100, 20)
	_check(absf(half.x - 0.5) < 0.001, "a tilt just past the dead zone starts from zero (0.6 gives 0.5, got %.3f)" % half.x)
	var fast: Vector2 = Profile.stick_look(Vector2(1.0, 0.0), 200, 20)
	_check(absf(fast.x - 2.0) < 0.001, "sensitivity 200%% doubles the look")
	var slow: Vector2 = Profile.stick_look(Vector2(1.0, 0.0), 10, 20)
	_check(absf(slow.x - 0.1) < 0.001, "sensitivity 10%% is a tenth of the look")
	var old_default: Vector2 = Profile.stick_look(Vector2(0.25, 0.0), 100, 20)
	_check(absf(old_default.x - 0.0625) < 0.001, "defaults keep the stick response smooth past 20%%")
	_check(Profile.new().stick_sensitivity == 100 and Profile.new().stick_deadzone == 20, "new profiles use 100% sensitivity and a 20% dead zone")
	_check(Profile.from_dict({"stick_sensitivity": 900, "stick_deadzone": 1}).stick_sensitivity == 200
		and Profile.from_dict({"stick_sensitivity": 900, "stick_deadzone": 1}).stick_deadzone == 5, "stored values are clamped to 10..200 and 5..40")
	_check(Profile.from_dict({}).stick_deadzone == 20, "old saves get the default dead zone")

	var host := Control.new()
	root.add_child(host)
	var profile := Profile.new()
	var panel := SettingsPanel.open(host, profile)
	await process_frame
	await process_frame
	panel.call("_show", "CONTROLS")
	await process_frame
	var speed: HSlider = panel.find_child("Slider_Stick_look_speed", true, false)
	var dead: HSlider = panel.find_child("Slider_Stick_dead_zone", true, false)
	_check(speed != null and speed.max_value == 200 and speed.min_value == 10, "Controls offers the stick look speed, 10 to 200%")
	_check(dead != null and dead.max_value == 40 and dead.min_value == 5, "Controls offers the stick dead zone, 5 to 40%")
	if speed != null:
		speed.value = 150
		_check(profile.stick_sensitivity == 150, "the speed slider is saved to the profile")
	if dead != null:
		dead.value = 30
		_check(profile.stick_deadzone == 30, "the dead zone slider is saved to the profile")
	quit(1 if _failures > 0 else 0)
