class_name InputIcons
extends RefCounted
## Key, mouse and gamepad icons from G.U.I.D.E (addons/guide): turns one of
## GameInput's bindings into a GUIDEInput and asks GUIDEInputFormatter for
## rich text with the icon ([img] tags), so menus show the real key/button
## art instead of plain text. Falls back to text when G.U.I.D.E is missing.

const ICON_SIZE: int = 28
## Platform index -> G.U.I.D.E's JoyType (Sony and Nintendo use another order).
const GUIDE_TYPES: Array[int] = [0, 1, 3, 2, 4]

static var _formatters: Dictionary = {}


static func available() -> bool:
	return ClassDB.class_exists(&"GUIDEInputKey") or ResourceLoader.exists("res://addons/guide/inputs/guide_input_key.gd")


## GameInput binding (int key, "mouse:N", "joy:N", "axis:A:S") -> GUIDEInput.
static func to_guide(binding: Variant) -> Resource:
	if binding == null:
		return null
	if binding is int:
		var k: Resource = load("res://addons/guide/inputs/guide_input_key.gd").new()
		k.set("key", binding)
		return k
	var parts: PackedStringArray = String(binding).split(":")
	match parts[0]:
		"mouse":
			var m: Resource = load("res://addons/guide/inputs/guide_input_mouse_button.gd").new()
			m.set("button", int(parts[1]))
			return m
		"joy":
			var j: Resource = load("res://addons/guide/inputs/guide_input_joy_button.gd").new()
			j.set("button", int(parts[1]))
			return j
		"axis":
			var a: Resource = load("res://addons/guide/inputs/guide_input_joy_direction.gd").new()
			a.set("axis", int(parts[1]))
			a.set("direction", 1 if float(parts[2]) < 0 else 0)
			return a
	return null


## GUIDEInput (from the input detector) -> GameInput binding, or null.
static func from_guide(input: Resource) -> Variant:
	if input == null:
		return null
	var script_path: String = (input.get_script() as Script).resource_path
	if script_path.ends_with("guide_input_key.gd"):
		return int(input.get("key"))
	if script_path.ends_with("guide_input_mouse_button.gd"):
		return "mouse:%d" % int(input.get("button"))
	return null


## Plain-text name of a binding (fallback and tests).
static func text(binding: Variant, platform: int = -1) -> String:
	if binding == null:
		return "—"
	if binding is int:
		return OS.get_keycode_string(binding)
	var parts: PackedStringArray = String(binding).split(":")
	match parts[0]:
		"mouse":
			return ["", "Left mouse", "Right mouse", "Middle mouse"][clampi(int(parts[1]), 0, 3)] if int(parts[1]) <= 3 else "Mouse %s" % parts[1]
		"joy":
			var button: int = int(parts[1])
			var style: int = resolved_platform(platform)
			var names: Array[String] = ["A", "B", "X", "Y", "Back", "Guide", "Start", "L3", "R3", "LB", "RB"]
			if style == 2:
				names = ["Cross", "Circle", "Square", "Triangle", "Share", "PS", "Options", "L3", "R3", "L1", "R1"]
			elif style == 3:
				names = ["B", "A", "Y", "X", "−", "Home", "+", "L3", "R3", "L", "R"]
			return names[button] if button >= 0 and button < names.size() else GameInput.pad_name(button)
		"axis":
			return "Left stick" if int(parts[1]) in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y] else "Right stick"
	return String(binding)


## Gamepad style: `platform` (1..4) when given, else the first connected
## pad's, else Xbox.
static func resolved_platform(platform: int = -1) -> int:
	if platform > 0:
		return clampi(platform, 1, GUIDE_TYPES.size() - 1)
	var pads: Array[int] = Input.get_connected_joypads()
	return platform_for_name(Input.get_joy_name(pads[0])) if not pads.is_empty() else 1


static func platform_for_name(device_name: String) -> int:
	var lower: String = device_name.to_lower()
	for marker in ["dualsense", "dualshock", "playstation", "ps3", "ps4", "ps5"]:
		if lower.contains(marker):
			return 2
	if lower.contains("nintendo") or lower.contains("switch"):
		return 3
	if lower.contains("steam deck") or lower.contains("steam controller"):
		return 4
	return 1


## Fills `label` with the icon(s) of `bindings` (async: icons are rendered
## on first use). Text first, so there is never an empty label.
static func fill(label: RichTextLabel, bindings: Array, platform: int = -1) -> void:
	var style: int = resolved_platform(platform)
	var generation: int = int(label.get_meta(&"icon_generation", 0)) + 1
	label.set_meta(&"icon_generation", generation)
	var plain: PackedStringArray = []
	for b: Variant in bindings:
		plain.append(text(b, style))
	label.text = "  ".join(plain)
	label.tooltip_text = label.text
	if not available() or DisplayServer.get_name() == "headless":
		return
	if not _formatters.has(style):
		var formatter: Object = load("res://addons/guide/ui/guide_input_formatter.gd").new(ICON_SIZE)
		var options: Object = formatter.get("formatting_options")
		options.set("joy_rendering", 2)  # FORCE_JOY_TYPE
		options.set("preferred_joy_type", GUIDE_TYPES[style])
		_formatters[style] = formatter
	var formatter: Object = _formatters[style]
	var parts: PackedStringArray = []
	for b: Variant in bindings:
		var input: Resource = to_guide(b)
		if input != null:
			parts.append(await formatter.call("input_as_richtext_async", input))
	if is_instance_valid(label) and int(label.get_meta(&"icon_generation", 0)) == generation and not parts.is_empty():
		label.text = "  ".join(parts)
