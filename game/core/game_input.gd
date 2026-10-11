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
	&"confirm": [KEY_ENTER, KEY_KP_ENTER, KEY_R, "joy:%d" % JOY_BUTTON_A, "joy:%d" % JOY_BUTTON_START],
	&"debug": [KEY_F3],
	## Debug: walk through everything, take no damage (mouse side buttons).
	&"noclip": ["mouse:%d" % MOUSE_BUTTON_XBUTTON1, "mouse:%d" % MOUSE_BUTTON_XBUTTON2],
	&"camera_toggle": [KEY_V, "joy:%d" % JOY_BUTTON_BACK],
	## Level-up cards are chosen with focus + ui_accept; R / Y redraws them.
	## card_1..3 are the boat's supply picks.
	&"card_reroll": [KEY_R, "joy:%d" % JOY_BUTTON_Y],
	&"card_1": [KEY_1, "joy:%d" % JOY_BUTTON_X],
	&"card_2": [KEY_2, "joy:%d" % JOY_BUTTON_Y],
	&"card_3": [KEY_3, "joy:%d" % JOY_BUTTON_B],
	&"menu_route_1": [KEY_4, "joy:%d" % JOY_BUTTON_LEFT_SHOULDER],
	&"menu_route_2": [KEY_5, "joy:%d" % JOY_BUTTON_RIGHT_SHOULDER],
	&"weapon_1": [KEY_1, "joy:%d" % JOY_BUTTON_DPAD_LEFT],
	&"weapon_2": [KEY_2, "joy:%d" % JOY_BUTTON_DPAD_UP],
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


## Actions the player can rebind (keyboard/mouse slot), with menu names.
## The first keyboard-or-mouse binding of each action is the "primary" one
## that a rebind replaces; arrows and gamepad bindings stay as they are.
const REBINDABLE: Dictionary = {
	&"move_up": "Move forward", &"move_down": "Move back",
	&"move_left": "Move left", &"move_right": "Move right",
	&"breaker": "Breaker (charge)", &"ability": "Class ability",
	&"sprint": "Sprint", &"camera_toggle": "Camera view",
	&"weapon_1": "Primary weapon", &"weapon_2": "Secondary weapon",
	&"pause": "Pause",
}


## True for a keyboard key or a mouse button binding (the remappable kind).
static func is_kbm(binding: Variant) -> bool:
	return binding is int or String(binding).begins_with("mouse:")


## The default primary keyboard/mouse binding of `action`.
static func default_binding(action: StringName) -> Variant:
	for b: Variant in ACTIONS.get(action, []):
		if is_kbm(b):
			return b
	return null


## The binding in use: the player's override, else the default.
static func current_binding(action: StringName, overrides: Dictionary) -> Variant:
	if overrides.has(String(action)):
		return _decode(overrides[String(action)])
	return default_binding(action)


## Applies the player's rebinds to the InputMap. Only the primary
## keyboard/mouse binding changes; secondary ones (arrows) and the gamepad
## stay as they are.
static func apply_overrides(overrides: Dictionary) -> void:
	for action: StringName in REBINDABLE:
		if not InputMap.has_action(action):
			continue
		var secondary: Array = []
		for b: Variant in ACTIONS.get(action, []):
			if is_kbm(b) and not same(b, default_binding(action)):
				secondary.append(b)
		for e: InputEvent in InputMap.action_get_events(action):
			var b: Variant = _binding_of(e)
			if b != null and not secondary.has(b):
				InputMap.action_erase_event(action, e)
		var now: Variant = current_binding(action, overrides)
		if now != null:
			InputMap.action_add_event(action, _event(now))


## InputEvent -> binding (int key or "mouse:N"), or null.
static func _binding_of(e: InputEvent) -> Variant:
	if e is InputEventKey:
		return int((e as InputEventKey).physical_keycode)
	if e is InputEventMouseButton:
		return "mouse:%d" % (e as InputEventMouseButton).button_index
	return null


## Bindings mix ints (keys) and strings: compare type first.
static func same(a: Variant, b: Variant) -> bool:
	return typeof(a) == typeof(b) and a == b


## Profile storage: bindings as strings ("key:87", "mouse:2").
static func encode(binding: Variant) -> String:
	return "key:%d" % int(binding) if binding is int else String(binding)


static func _decode(text: String) -> Variant:
	if text.begins_with("key:"):
		return int(text.substr(4))
	return text


## Movement vector from keys or the left stick (analog strength kept).
static func move_vector() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", MOVE_DEADZONE)


## Short prompt for an action as the player has it bound right now (read
## from the InputMap, so rebinds show up): "SPACE", "RMB", or the gamepad
## buttons "RB / A". HUD and menus use it instead of hard-coded keys.
static func prompt(action: StringName, gamepad: bool) -> String:
	if not InputMap.has_action(action):
		return "—"
	var pads: PackedStringArray = []
	var primary: String = ""
	var secondary: String = ""
	for e: InputEvent in InputMap.action_get_events(action):
		if e is InputEventJoypadButton:
			pads.append(pad_name((e as InputEventJoypadButton).button_index))
		elif e is InputEventKey or e is InputEventMouseButton:
			var b: Variant = _binding_of(e)
			if e is InputEventKey and int(b) == 0:  # built-in ui_* actions use keycode
				b = int((e as InputEventKey).keycode)
			# The primary (rebindable) key wins: apply_overrides re-adds it
			# at the end, after secondary keys such as the arrows.
			if not _is_secondary(action, b):
				primary = binding_name(b) if primary == "" else primary
			elif secondary == "":
				secondary = binding_name(b)
	if gamepad:
		return " / ".join(pads) if not pads.is_empty() else "—"
	return primary if primary != "" else secondary if secondary != "" else "—"


static func _is_secondary(action: StringName, b: Variant) -> bool:
	for d: Variant in ACTIONS.get(action, []):
		if is_kbm(d) and same(d, b) and not same(d, default_binding(action)):
			return true
	return false


## Key/mouse binding -> short upper-case name ("SPACE", "G", "RMB").
static func binding_name(b: Variant) -> String:
	if b == null:
		return "—"
	if b is int:
		return OS.get_keycode_string(b).to_upper()
	var parts: PackedStringArray = String(b).split(":")
	if parts[0] == "mouse":
		return {1: "LMB", 2: "RMB", 3: "MMB", 8: "MOUSE 4", 9: "MOUSE 5"}.get(int(parts[1]), "MOUSE %s" % parts[1])
	return String(b)


## Xbox-style gamepad button names (the prompts the game shows).
static func pad_name(button: int) -> String:
	return {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
		JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
		JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
		JOY_BUTTON_START: "START", JOY_BUTTON_BACK: "VIEW",
		JOY_BUTTON_DPAD_UP: "D-UP", JOY_BUTTON_DPAD_DOWN: "D-DOWN",
		JOY_BUTTON_DPAD_LEFT: "D-LEFT", JOY_BUTTON_DPAD_RIGHT: "D-RIGHT"}.get(button, "PAD %d" % button)
