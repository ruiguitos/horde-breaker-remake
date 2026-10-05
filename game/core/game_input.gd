class_name GameInput
extends RefCounted
## Registers the game's input actions in the InputMap at startup, so code
## asks "is `breaker` pressed?" instead of checking keys and buttons. Each
## action lists its keyboard/mouse and gamepad bindings in one place (and can
## be rebound later). Defined in code rather than in project.godot so the
## bindings are readable and reviewed like any other code.

const MOVE_DEADZONE: float = 0.2

## action -> list of bindings: Key, MouseButton (as "mouse:N"), JoyButton
## (as "joy:N") or joystick axis (as "axis:AXIS:SIGN").
static var ACTIONS: Dictionary = {
	&"move_left": [KEY_A, KEY_LEFT, "axis:%d:-1" % JOY_AXIS_LEFT_X],
	&"move_right": [KEY_D, KEY_RIGHT, "axis:%d:1" % JOY_AXIS_LEFT_X],
	&"move_up": [KEY_W, KEY_UP, "axis:%d:-1" % JOY_AXIS_LEFT_Y],
	&"move_down": [KEY_S, KEY_DOWN, "axis:%d:1" % JOY_AXIS_LEFT_Y],
	&"breaker": [KEY_SPACE, "mouse:%d" % MOUSE_BUTTON_RIGHT, "joy:%d" % JOY_BUTTON_A, "joy:%d" % JOY_BUTTON_RIGHT_SHOULDER],
	&"ability": [KEY_G, "mouse:%d" % MOUSE_BUTTON_MIDDLE, "joy:%d" % JOY_BUTTON_LEFT_SHOULDER],
	&"sprint": [KEY_SHIFT, "joy:%d" % JOY_BUTTON_LEFT_STICK],
	&"pause": [KEY_ESCAPE, "joy:%d" % JOY_BUTTON_START],
	&"abandon": [KEY_Q],
	&"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_R, "joy:%d" % JOY_BUTTON_A, "joy:%d" % JOY_BUTTON_START],
	&"debug": [KEY_F3],
	&"camera_toggle": [KEY_V, "joy:%d" % JOY_BUTTON_BACK],
	&"card_1": [KEY_1, "joy:%d" % JOY_BUTTON_X],
	&"card_2": [KEY_2, "joy:%d" % JOY_BUTTON_Y],
	&"card_3": [KEY_3, "joy:%d" % JOY_BUTTON_B],
	&"menu_route_1": [KEY_4, "joy:%d" % JOY_BUTTON_LEFT_SHOULDER],
	&"menu_route_2": [KEY_5, "joy:%d" % JOY_BUTTON_RIGHT_SHOULDER],
	&"weapon_1": [KEY_1, "joy:%d" % JOY_BUTTON_DPAD_LEFT],
	&"weapon_2": [KEY_2, "joy:%d" % JOY_BUTTON_DPAD_UP],
	&"weapon_3": [KEY_3, "joy:%d" % JOY_BUTTON_DPAD_RIGHT],
	&"weapon_4": [KEY_4],
	&"weapon_5": [KEY_5],
	&"weapon_next": ["joy:%d" % JOY_BUTTON_DPAD_DOWN],
}


static func setup() -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action, 0.2)
		for binding: Variant in ACTIONS[action]:
			InputMap.action_add_event(action, _event(binding))
	# Built-in UI actions may only contain keyboard defaults in this project.
	# Merge controller bindings so native Buttons and modal Back work alike.
	var menu_bindings: Dictionary = {
		&"ui_accept": ["joy:%d" % JOY_BUTTON_A],
		&"ui_cancel": ["joy:%d" % JOY_BUTTON_B],
		&"ui_left": ["joy:%d" % JOY_BUTTON_DPAD_LEFT, "axis:%d:-1" % JOY_AXIS_LEFT_X],
		&"ui_right": ["joy:%d" % JOY_BUTTON_DPAD_RIGHT, "axis:%d:1" % JOY_AXIS_LEFT_X],
		&"ui_up": ["joy:%d" % JOY_BUTTON_DPAD_UP, "axis:%d:-1" % JOY_AXIS_LEFT_Y],
		&"ui_down": ["joy:%d" % JOY_BUTTON_DPAD_DOWN, "axis:%d:1" % JOY_AXIS_LEFT_Y],
	}
	for action: StringName in menu_bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for binding: Variant in menu_bindings[action]:
			var event := _event(binding)
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


static func _event(binding: Variant) -> InputEvent:
	if binding is int:
		var k := InputEventKey.new()
		k.physical_keycode = binding
		return k
	var parts: PackedStringArray = String(binding).split(":")
	match parts[0]:
		"mouse":
			var m := InputEventMouseButton.new()
			m.button_index = int(parts[1]) as MouseButton
			return m
		"joy":
			var j := InputEventJoypadButton.new()
			j.button_index = int(parts[1]) as JoyButton
			return j
		_:
			var a := InputEventJoypadMotion.new()
			a.axis = int(parts[1]) as JoyAxis
			a.axis_value = float(parts[2])
			return a


## Movement vector from keys or the left stick (analog strength kept).
static func move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", MOVE_DEADZONE)
