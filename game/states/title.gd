extends Node
## Illustrated harbor with native, focusable controls.

signal play_requested
## TEST ISLAND (development builds): play this island with this mission.
signal test_island_requested(path: String, mission: StringName)

var profile: Profile
var _root: Control
var _dialog: MenuDialog


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	layer.add_child(_root)
	UiTheme.backdrop(_root, UiTheme.HARBOR)
	var shade := ColorRect.new()
	shade.color = Color(0.035, 0.045, 0.03, 0.97)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.offset_right = 420
	_root.add_child(shade)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = 420
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 36)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 28)
	_root.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	box.add_child(UiTheme.label("SALVAGE & CO.\nHALVARD OPERATIONS", 16, UiTheme.TEXT, true))
	var logo := UiTheme.texture(UiTheme.WORDMARK, true)
	logo.custom_minimum_size.y = 172
	box.add_child(logo)
	box.add_child(UiTheme.label("ISLAND EXPEDITION / ZOMBIE HORDE SHOOTER", 14, UiTheme.MUTED, true))
	box.add_child(HSeparator.new())
	var deploy := UiTheme.button(box, "DEPLOY", _deploy, true)
	deploy.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var arrow := UiTheme.title("›", 26)
	arrow.add_theme_color_override("font_color", UiTheme.BG)
	arrow.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	arrow.offset_left = -36
	arrow.offset_right = -12
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	deploy.add_child(arrow)
	var items: Array = [["SETTINGS", _settings], ["INTEL ARCHIVE", _archive], ["QUIT", func() -> void: get_tree().quit()]]
	if OS.is_debug_build():  # the editor and debug exports; never a release
		items.push_front(["TEST ISLAND", _test_island])
	for item in items:
		var b := UiTheme.button(box, item[0], item[1])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(gap)
	box.add_child(UiTheme.label("Recovery is mandatory.\nSurvival is encouraged.", 16, UiTheme.MUTED, true))
	if profile.runs > 0:
		box.add_child(UiTheme.label("Intel %d / Runs %d / Extractions %d" % [profile.intel, profile.runs, profile.extractions], 16, UiTheme.MUTED, true))
	var hint := UiTheme.label("[ ENTER / A ] SELECT · F11 FULLSCREEN", 16, UiTheme.TEXT, true)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint.offset_left = -440
	hint.offset_right = -32
	hint.offset_top = -48
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(hint)
	deploy.grab_focus()
	_root.add_child(UiSfx.new())
	add_child(Ambience.create(&"menu", -12.0))


func _deploy() -> void:
	var sound := AudioStreamPlayer.new()
	sound.bus = Profile.BUS_SFX
	sound.stream = load(Sfx.PACK + String(Sfx.FILES[&"ui_start"]))
	get_tree().root.add_child(sound)
	sound.finished.connect(sound.queue_free)
	sound.play()
	play_requested.emit()


func _settings() -> void:
	if not is_instance_valid(_dialog):
		_dialog = MenuDialog.settings(_root, profile)


func _test_island() -> void:
	if not is_instance_valid(_dialog):
		_dialog = MenuDialog.test_island(_root, func(path: String, mission: StringName) -> void:
			test_island_requested.emit(path, mission))


func _archive() -> void:
	if not is_instance_valid(_dialog):
		_dialog = MenuDialog.archive(_root, profile)
