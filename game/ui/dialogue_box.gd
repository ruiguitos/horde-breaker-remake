class_name DialogueBox
extends CanvasLayer
## Dialogue balloon in the game's UI style (instead of the addon's example
## balloon): speaker portrait letter, line text and one button per response,
## all keyboard/gamepad navigable. Lines come from Dialogue Manager
## (DialogueManager.get_next_dialogue_line), so the conversation itself
## lives in a .dialogue file.

signal finished

var resource: Resource
var states: Array = []
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _line: Object  ## current DialogueLine


static func open(parent: Node, dialogue: Resource, cue: String, extra_states: Array) -> DialogueBox:
	var box := DialogueBox.new()
	box.resource = dialogue
	box.states = extra_states
	parent.add_child(box)
	box._next(cue)
	return box


func _ready() -> void:
	layer = 50
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows upwards to fit
	for edge in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	root.add_child(margin)
	var panel := PanelContainer.new()
	margin.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var portrait := UiTheme.title("H", 56)
	portrait.custom_minimum_size = Vector2(90, 90)
	portrait.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)
	_speaker = UiTheme.label("", 18, UiTheme.ACCENT, true)
	col.add_child(_speaker)
	_text = UiTheme.label("", 22)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	col.add_child(_choices)
	root.add_child(UiSfx.new())


## Fetches the line with id `key` and shows it (or ends the conversation).
func _next(key: String) -> void:
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm == null or resource == null:
		_end()
		return
	_line = await dm.call("get_next_dialogue_line", resource, key, states)
	if _line == null:
		_end()
		return
	_show_line()


func _show_line() -> void:
	_speaker.text = String(_line.get("character")).to_upper()
	_text.text = String(_line.get("text"))
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()
	var responses: Array = _line.get("responses")
	var first: Button
	if responses.is_empty():
		first = UiTheme.button(_choices, "CONTINUE   ›", func() -> void: _next(String(_line.get("next_id"))))
		first.name = "Continue"
	else:
		var n: int = 0
		for r: Object in responses:
			if not bool(r.get("is_allowed")):
				continue
			n += 1
			var b := UiTheme.button(_choices, "%d / %s" % [n, String(r.get("text"))], func() -> void: _next(String(r.get("next_id"))))
			b.name = "Choice_%d" % n
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 18)
			b.custom_minimum_size.y = 40
			if first == null:
				first = b
	if first != null:
		first.grab_focus()


## Number keys pick a response directly.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = (event as InputEventKey).physical_keycode - KEY_1
	var buttons: Array[Node] = _choices.get_children()
	if k >= 0 and k < buttons.size() and buttons[k] is Button:
		get_viewport().set_input_as_handled()
		(buttons[k] as Button).pressed.emit()


func _end() -> void:
	finished.emit()
	queue_free()
