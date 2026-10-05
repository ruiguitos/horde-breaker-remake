class_name InputIcons
extends RefCounted
## Key, mouse and gamepad icons from G.U.I.D.E (addons/guide): turns one of
## GameInput's bindings into a GUIDEInput and asks GUIDEInputFormatter for
## rich text with the icon ([img] tags), so menus show the real key/button
## art instead of plain text. Falls back to text when G.U.I.D.E is missing.

const ICON_SIZE: int = 28

static var _formatter: Object


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
			var a: Resource = load("res://addons/guide/inputs/guide_input_joy_axis_1d.gd").new()
			a.set("axis", int(parts[1]))
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
static func text(binding: Variant) -> String:
	if binding == null:
		return "—"
	if binding is int:
		return OS.get_keycode_string(binding)
	var parts: PackedStringArray = String(binding).split(":")
	match parts[0]:
		"mouse":
			return ["", "Left mouse", "Right mouse", "Middle mouse"][clampi(int(parts[1]), 0, 3)] if int(parts[1]) <= 3 else "Mouse %s" % parts[1]
		"joy":
			return "Pad button %s" % parts[1]
	return String(binding)


## Fills `label` with the icon(s) of `bindings` (async: icons are rendered
## on first use). Text first, so there is never an empty label.
static func fill(label: RichTextLabel, bindings: Array) -> void:
	var plain: PackedStringArray = []
	for b: Variant in bindings:
		plain.append(text(b))
	label.text = "  ".join(plain)
	if not available() or DisplayServer.get_name() == "headless":
		return
	if _formatter == null:
		_formatter = load("res://addons/guide/ui/guide_input_formatter.gd").new(ICON_SIZE)
	var parts: PackedStringArray = []
	for b: Variant in bindings:
		var input: Resource = to_guide(b)
		if input != null:
			parts.append(await _formatter.call("input_as_richtext_async", input))
	if is_instance_valid(label) and not parts.is_empty():
		label.text = "  ".join(parts)
