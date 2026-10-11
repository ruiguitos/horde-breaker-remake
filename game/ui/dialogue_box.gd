class_name DialogueBox
extends CanvasLayer
## Dialogue balloon in the game's UI style (instead of the addon's example
## balloon): speaker portrait, name, typed-out line and one button per
## response, all keyboard/gamepad navigable. Lines come from Dialogue
## Manager (DialogueManager.get_next_dialogue_line), so the conversation
## itself lives in a .dialogue file.
##
## Flow: the line types out with a voice blip every few letters. A/Enter
## (or a click) first completes the line; the responses (or CONTINUE) only
## appear once it is complete, so the same press never skips a choice by
## accident. SKIP (Esc/B or the button) ends the whole conversation; what
## the player already chose stays applied (`do` mutations run as soon as a
## response is picked, e.g. hazard pay).

signal finished

var resource: Resource
var states: Array = []
var typewriter := Typewriter.new()
var _portrait: Portrait
var _speaker: Label
var _text: RichTextLabel
var _choices: VBoxContainer
var _skip: Button
var _voice: DialogueVoice
var _line: Object  ## current DialogueLine
var _ended: bool = false
var _gamepad: bool = false


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
	dim.gui_input.connect(_on_click)
	root.add_child(dim)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	margin.grow_vertical = Control.GROW_DIRECTION_BEGIN  # grows upwards to fit
	for edge in ["left", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 40)
	root.add_child(margin)
	var panel := PanelContainer.new()
	panel.gui_input.connect(_on_click)
	margin.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	_portrait = Portrait.new()
	_portrait.name = "Portrait"
	_portrait.custom_minimum_size = Vector2(112, 112)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	row.add_child(col)
	var head := HBoxContainer.new()
	col.add_child(head)
	_speaker = UiTheme.label("", 18, UiTheme.ACCENT, true)
	_speaker.name = "Speaker"
	_speaker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_speaker)
	# Mouse-only button (no focus): Enter/A on it would skip by accident.
	_skip = UiTheme.button(head, "", skip)
	_skip.name = "Skip"
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.add_theme_font_size_override("font_size", 14)
	_skip.custom_minimum_size = Vector2(0, 30)
	_text = RichTextLabel.new()
	_text.name = "Text"
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.custom_minimum_size.y = 60
	_text.add_theme_font_override("normal_font", UiTheme.body_font())
	_text.add_theme_font_size_override("normal_font_size", 22)
	_text.add_theme_font_size_override("italics_font_size", 22)
	_text.add_theme_color_override("default_color", UiTheme.TEXT)
	col.add_child(_text)
	_choices = VBoxContainer.new()
	_choices.name = "Choices"
	_choices.add_theme_constant_override("separation", 6)
	col.add_child(_choices)
	root.add_child(UiSfx.new())
	_voice = DialogueVoice.new()
	add_child(_voice)
	_refresh_skip()


## Fetches the line with id `key` and shows it (or ends the conversation).
func _next(key: String) -> void:
	_clear_choices()
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm == null or resource == null:
		_end()
		return
	_line = await dm.call("get_next_dialogue_line", resource, key, states)
	if _ended:
		return  # skipped while the next line was being fetched
	if _line == null:
		_end()
		return
	_show_line()


func _show_line() -> void:
	var who: String = String(_line.get("character"))
	_speaker.text = who.to_upper()
	_portrait.speaker = who
	typewriter.start(_text, String(_line.get("text")))
	_clear_choices()


func _process(delta: float) -> void:
	if _line == null or _ended or typewriter.is_done():
		return
	if typewriter.step(delta):
		_voice.blip(String(_line.get("character")))
		_portrait.talk()
	if typewriter.is_done():
		_show_choices()


## A/Enter or a click: completes the line being typed (the second press then
## goes to the focused response or CONTINUE). Returns true if it completed.
func advance() -> bool:
	if _line == null or _ended or typewriter.is_done():
		return false
	typewriter.complete()
	_show_choices()
	return true


## Ends the whole conversation now. Choices already made stay applied.
func skip() -> void:
	_end()


## True while the current line is still typing.
func is_typing() -> bool:
	return _line != null and not typewriter.is_done()


func _show_choices() -> void:
	if _choices.get_child_count() > 0:
		return
	var responses: Array = _line.get("responses")
	var first: Button
	if responses.is_empty():
		first = UiTheme.button(_choices, tr("CONTINUE") + "   ›", func() -> void: _next(String(_line.get("next_id"))))
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
	if first != null and is_inside_tree():
		first.grab_focus()


func _clear_choices() -> void:
	for c in _choices.get_children():
		_choices.remove_child(c)
		c.queue_free()


func _on_click(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		advance()


## Before the GUI: while a line types, A/Enter completes it (no button has
## focus yet) and Esc/B skips the conversation at any time.
func _input(event: InputEvent) -> void:
	if _ended or event.is_echo() or not event.is_pressed():
		return
	var pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
	if pad != _gamepad and (pad or event is InputEventKey):
		_gamepad = pad
		_refresh_skip()
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		skip()
	elif is_typing() and event.is_action_pressed(&"ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


## Number keys pick a response directly.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var k: int = (event as InputEventKey).physical_keycode - KEY_1
	var buttons: Array[Node] = _choices.get_children()
	if k >= 0 and k < buttons.size() and buttons[k] is Button:
		get_viewport().set_input_as_handled()
		(buttons[k] as Button).pressed.emit()


func _refresh_skip() -> void:
	if _skip != null:
		_skip.text = "%s  [ %s ]" % [tr("SKIP"), GameInput.prompt(&"ui_cancel", _gamepad)]


func _end() -> void:
	if _ended:
		return
	_ended = true
	finished.emit()
	queue_free()
