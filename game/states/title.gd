extends Node
## Title: a solid left column (brand, logo, menu) next to the harbour art.
## The profile stats and the input hints sit in a bar along the bottom of
## the art, so nothing floats over the picture (docs/design/MENUS.md,
## "Redesenho de outubro de 2026", point 2).

signal play_requested
## QUICK REDEPLOY: the last run again (main.gd checks it can still be played).
signal quick_redeploy_requested
## TEST ISLAND (development builds): play this island with this mission.
signal test_island_requested(path: String, mission: StringName)
## DEV SANDBOX (development builds): play one island with the form's settings.
signal sandbox_requested(config: Dictionary)

## Width of the left column at the 1152x648 base size (the mockup's 467 of
## 1280 px). The art shows to the right of it.
const COLUMN_WIDTH: float = 420.0
## Height of the stats/hints bar along the bottom of the art.
const FOOTER_HEIGHT: float = 58.0

var profile: Profile
var _root: Control
var _dialog: MenuDialog
var _deploy_button: Button
var _redeploy_button: Button
var _archive_badge: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	layer.add_child(_root)
	# The art fills the screen; the opaque column covers its left part, so
	# what shows is the boat and the pier (as in the mockup).
	UiTheme.backdrop(_root, UiTheme.HARBOR)
	var column := ColorRect.new()
	column.color = UiTheme.BG
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	column.offset_right = COLUMN_WIDTH
	_root.add_child(column)
	_build_menu()
	_build_footer()
	_deploy_button.grab_focus()
	_root.add_child(UiSfx.new())
	add_child(Ambience.create(&"menu", -12.0))


func _build_menu() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	margin.offset_right = COLUMN_WIDTH
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	_root.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	box.add_child(_caption("SALVAGE & CO. / HALVARD OPERATIONS"))
	var logo := UiTheme.texture(UiTheme.WORDMARK, true)
	logo.custom_minimum_size.y = 150
	box.add_child(logo)
	box.add_child(_caption("ISLAND EXPEDITION / ZOMBIE HORDE SHOOTER", 12))
	box.add_child(HSeparator.new())
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 11)
	box.add_child(menu)
	_deploy_button = _deploy_entry(menu)
	_redeploy_button = _redeploy_entry(menu)
	_archive_entry(menu)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 11)
	menu.add_child(row)
	for item: Array in [["SETTINGS", _settings], ["CREDITS", _credits], ["QUIT", func() -> void: get_tree().quit()]]:
		var b := _menu_button(row, item[0], item[1])
		b.name = String(item[0]).capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(gap)
	var bottom := HBoxContainer.new()
	box.add_child(bottom)
	var motto := UiTheme.label("Recovery is mandatory.
Survival is encouraged.", 15, UiTheme.TEXT_MUTED)
	motto.name = "Motto"
	motto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motto.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom.add_child(motto)
	if OS.is_debug_build():  # the editor and debug exports; never a release
		bottom.add_child(_dev_entry())


## Mono caption with a little tracking, like the mockup's brand lines.
func _caption(text: String, font_size: int = 13) -> Label:
	var l := UiTheme.label(text, font_size, UiTheme.TEXT_MUTED)
	var font := FontVariation.new()
	font.base_font = UiTheme.mono_font()
	font.spacing_glyph = 1
	l.add_theme_font_override("font", font)
	return l


func _menu_button(parent: Control, text: String, action: Callable) -> Button:
	var b := UiTheme.button(parent, text, action)
	b.custom_minimum_size.y = 46
	b.add_theme_font_size_override("font_size", 21)
	return b


## Text inside a button that must not take the mouse from it.
func _inner_label(text: String, font: Font, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l


## A row laid over a button (its own text stays empty): content on the
## left, `right` on the right, inside the button's padding.
func _overlay(b: Button) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 18
	row.offset_right = -18
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	b.add_child(row)
	return row


## DEPLOY: the primary action, with what it leads to and an arrow.
func _deploy_entry(parent: Control) -> Button:
	var b := UiTheme.button(parent, "", _deploy, true)
	b.name = "Deploy"
	b.custom_minimum_size.y = 54
	b.tooltip_text = "Armory, then choose your run"
	var row := _overlay(b)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override("separation", 0)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	text.add_child(_inner_label("DEPLOY", UiTheme.title_font(), 26, UiTheme.ON_ACCENT))
	text.add_child(_inner_label("Armory, then choose your run", UiTheme.body_bold_font(), 13, Color(UiTheme.ON_ACCENT, 0.8)))
	var arrow := TextureRect.new()
	arrow.texture = _chevron()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	arrow.modulate = UiTheme.ON_ACCENT
	row.add_child(arrow)
	return b


## QUICK REDEPLOY: the last run's class and run type on the right; disabled
## with the reason when there is no previous run.
func _redeploy_entry(parent: Control) -> Button:
	var b := _menu_button(parent, "QUICK REDEPLOY", func() -> void: quick_redeploy_requested.emit())
	b.name = "QuickRedeploy"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := _overlay(b)
	row.alignment = BoxContainer.ALIGNMENT_END
	var problem: String = profile.redeploy_problem()
	var detail: String = _redeploy_detail(problem)
	var summary := _inner_label(detail, UiTheme.mono_font(), 12, UiTheme.TEXT_MUTED)
	summary.name = "Summary"
	summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	summary.size_flags_vertical = Control.SIZE_FILL
	row.add_child(summary)
	b.disabled = profile.last_run.is_empty()
	if b.disabled:
		b.focus_mode = Control.FOCUS_NONE  # the pad skips it instead of landing on a dead button
		b.tooltip_text = "Play a run first: QUICK REDEPLOY replays your last one."
	elif problem != "":
		b.tooltip_text = "%s: opens the Armory instead." % problem
	else:
		b.tooltip_text = "Same class, perks, run and Threat as last time: %s." % profile.last_run_summary()
	return b


## The short text on the QUICK REDEPLOY button ("Vanguard · Archipelago").
func _redeploy_detail(problem: String) -> String:
	if profile.last_run.is_empty() or problem != "":
		return problem
	return profile.last_run_summary().rsplit(" · ", true, 1)[0]


## INTEL ARCHIVE with a "N NEW" badge for files not seen yet.
func _archive_entry(parent: Control) -> void:
	var b := _menu_button(parent, "INTEL ARCHIVE", _archive)
	b.name = "IntelArchive"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	var row := _overlay(b)
	row.alignment = BoxContainer.ALIGNMENT_END
	_archive_badge = _inner_label("%d NEW" % profile.unread_files(), UiTheme.mono_bold_font(), 12, UiTheme.BG)
	_archive_badge.name = "Badge"
	_archive_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var pill := StyleBoxFlat.new()
	pill.bg_color = UiTheme.INFO
	pill.set_corner_radius_all(3)
	pill.content_margin_left = 7
	pill.content_margin_right = 7
	pill.content_margin_top = 2
	pill.content_margin_bottom = 2
	_archive_badge.add_theme_stylebox_override("normal", pill)
	_archive_badge.visible = profile.unread_files() > 0
	row.add_child(_archive_badge)


## DEV (development builds): a small dashed text button, out of the main menu's way.
## It opens the dev hub.
func _dev_entry() -> Button:
	var b := Button.new()
	b.name = "TestIsland"
	b.text = "DEV"
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.size_flags_vertical = Control.SIZE_SHRINK_END
	b.theme_type_variation = &"QuietButton"
	b.add_theme_font_override("font", UiTheme.mono_font())
	b.add_theme_font_size_override("font_size", 12)
	var dashed := MarkedBox.new(StyleBoxFlat.new())
	dashed.base.bg_color = Color.TRANSPARENT
	dashed.dashed = true
	dashed.dash_color = UiTheme.LINE.lightened(0.2)
	dashed.dash_width = 1.0
	dashed.dash_length = 4.0
	dashed.dash_gap = 3.0
	dashed.base.content_margin_left = 8
	dashed.base.content_margin_right = 8
	dashed.base.content_margin_top = 4
	dashed.base.content_margin_bottom = 4
	dashed.sync_margins()
	b.add_theme_stylebox_override("normal", dashed)
	b.pressed.connect(_dev_hub)
	return b


## Bar along the bottom of the art: profile stats left, input hints right.
func _build_footer() -> void:
	var bar := PanelContainer.new()
	bar.name = "Footer"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_left = COLUMN_WIDTH
	bar.offset_top = -FOOTER_HEIGHT
	var style := StyleBoxFlat.new()
	style.bg_color = UiTheme.BG
	style.border_color = UiTheme.LINE
	style.border_width_top = 1
	style.content_margin_left = 26
	style.content_margin_right = 26
	bar.add_theme_stylebox_override("panel", style)
	_root.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	bar.add_child(row)
	for stat: Array in [["INTEL", profile.intel, UiTheme.ACCENT], ["RUNS", profile.runs, UiTheme.TEXT], ["EXTRACTIONS", profile.extractions, UiTheme.TEXT]]:
		var cell := RichTextLabel.new()
		cell.name = "Stat" + String(stat[0]).capitalize()
		cell.bbcode_enabled = true
		cell.fit_content = true
		cell.autowrap_mode = TextServer.AUTOWRAP_OFF
		cell.scroll_active = false
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		cell.add_theme_font_override("normal_font", UiTheme.mono_font())
		cell.add_theme_font_override("bold_font", UiTheme.mono_bold_font())
		cell.add_theme_font_size_override("normal_font_size", 14)
		cell.add_theme_font_size_override("bold_font_size", 14)
		cell.text = "%s [b][color=#%s]%d[/color][/b]" % [stat[0], (stat[2] as Color).to_html(false), stat[1]]
		row.add_child(cell)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)
	_hint(row, _accept_bindings(), "SELECT")
	_hint(row, [KEY_F11], "FULLSCREEN")  # main.gd's fullscreen key


## One hint: the binding icons (real ones, from InputIcons) and a word.
func _hint(parent: Control, bindings: Array, word: String) -> void:
	var hint := HBoxContainer.new()
	hint.name = "Hint" + word.capitalize()
	hint.add_theme_constant_override("separation", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hint)
	var icons := RichTextLabel.new()
	icons.bbcode_enabled = true  # InputIcons writes [img] tags
	icons.fit_content = true
	icons.autowrap_mode = TextServer.AUTOWRAP_OFF
	icons.scroll_active = false
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icons.add_theme_font_override("normal_font", UiTheme.mono_font())
	icons.add_theme_font_size_override("normal_font_size", 13)
	hint.add_child(icons)
	InputIcons.fill(icons, bindings)
	var label := UiTheme.label(word, 13, UiTheme.TEXT_MUTED, true)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.add_child(label)


## What presses the focused button, read from ui_accept in the InputMap
## (GameInput adds pad A): the pad button when a gamepad is connected, else
## the first key. One glyph, for the device in hand, as in the mockup.
func _accept_bindings() -> Array:
	var key: Variant = null
	var pad: Variant = null
	for e: InputEvent in InputMap.action_get_events(&"ui_accept"):
		if key == null and e is InputEventKey:
			var k := e as InputEventKey
			key = int(k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
		elif pad == null and e is InputEventJoypadButton:
			pad = "joy:%d" % (e as InputEventJoypadButton).button_index
	var use: Variant = pad if pad != null and not Input.get_connected_joypads().is_empty() else key
	return [use] if use != null else []


## The DEPLOY arrow (white; tinted where used).
static func _chevron() -> Texture2D:
	var img := Image.new()
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='14' height='20' viewBox='0 0 14 20'><path d='M3 3l8 7-8 7' fill='none' stroke='#fff' stroke-width='3'/></svg>"
	if img.load_svg_from_string(svg, 2.0) != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(14, 20))
	return tex


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


func _credits() -> void:
	if not is_instance_valid(_dialog):
		_dialog = MenuDialog.credits(_root)


func _sandbox() -> void:
	if not is_instance_valid(_dialog):
		_dialog = DevSandbox.open(_root, func(config: Dictionary) -> void:
			sandbox_requested.emit(config))


func _tests() -> void:
	if not is_instance_valid(_dialog):
		_dialog = DevTestPanel.open(_root)


## DEV hub (development builds): the dev tools in one place, so the footer keeps its width.
func _dev_hub() -> void:
	if is_instance_valid(_dialog):
		return
	var hub := MenuDialog.new()
	_root.add_child(hub)
	_dialog = hub
	hub.content.add_child(UiTheme.title("DEV", 36))
	hub.content.add_child(UiTheme.label("Development builds only.", 14, UiTheme.MUTED))
	UiTheme.button(hub.content, "TEST ISLAND", _hub_pick.bind(hub, _test_island))
	UiTheme.button(hub.content, "SANDBOX", _hub_pick.bind(hub, _sandbox))
	UiTheme.button(hub.content, "TESTS", _hub_pick.bind(hub, _tests))


## Leaves the hub, then opens the chosen tool (each opens its own dialog).
func _hub_pick(hub: MenuDialog, action: Callable) -> void:
	hub.close()
	_dialog = null
	action.call()


func _test_island() -> void:
	if not is_instance_valid(_dialog):
		_dialog = MenuDialog.test_island(_root, func(path: String, mission: StringName) -> void:
			test_island_requested.emit(path, mission))


## Opening the archive marks its files as seen (the badge goes away).
func _archive() -> void:
	if not is_instance_valid(_dialog):
		_dialog = MenuDialog.archive(_root, profile)
		if profile.unread_files() > 0:
			profile.mark_archive_read()
			profile.save()
			_archive_badge.visible = false
