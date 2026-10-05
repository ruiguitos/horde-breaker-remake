class_name UiTheme
extends RefCounted
## Shared field-equipment style for native menus and the HUD.

const BG := Color("101410")
const PANEL := Color(0.075, 0.085, 0.07, 0.97)
const PANEL_BORDER := Color("555b4d")
const ACCENT := Color("f4b640")
const TEXT := Color("e7e5d8")
const MUTED := Color("a3ac99")
const DANGER := Color("df6156")
const SUCCESS := Color("a8c679")
const HARBOR := "res://game/ui/art/harbor.png"
const CONTRACTOR := "res://game/ui/art/contractor.png"
const WORDMARK := "res://game/ui/art/wordmark.png"

static var _theme: Theme
static var _heading: Font
static var _mono: Font


static func heading_font() -> Font:
	if _heading == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Bahnschrift", "Arial Narrow", "Liberation Sans Narrow"])
		font.font_weight = 700
		font.font_stretch = 75
		_heading = font
	return _heading


static func mono_font() -> Font:
	if _mono == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["Consolas", "Courier New", "monospace"])
		font.font_stretch = 75
		_mono = font
	return _mono


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _box(bg: Color, border: Color, width: int = 1, radius: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 2)
	t.set_font("font", "Button", heading_font())
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("normal", "Button", _box(Color("20251c"), PANEL_BORDER))
	t.set_stylebox("hover", "Button", _box(Color("303326"), ACCENT))
	t.set_stylebox("pressed", "Button", _box(Color("49412a"), ACCENT))
	t.set_stylebox("focus", "Button", _box(Color.TRANSPARENT, ACCENT, 2))
	t.set_stylebox("disabled", "Button", _box(Color("191d17"), Color("343b2f")))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(state, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(ACCENT, ACCENT))
	t.set_stylebox("hover", "PrimaryButton", _box(ACCENT.lightened(0.12), TEXT))
	t.set_stylebox("pressed", "PrimaryButton", _box(ACCENT.darkened(0.12), ACCENT))
	for state in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color"]:
		t.set_color(state, "PrimaryButton", BG)
	t.set_type_variation("SelectedButton", "Button")
	for state in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(state, "SelectedButton", _box(Color("383522"), ACCENT, 2))
	t.set_color("font_color", "SelectedButton", ACCENT)
	t.set_color("font_disabled_color", "SelectedButton", ACCENT)
	t.set_type_variation("DangerButton", "Button")
	t.set_color("font_color", "DangerButton", DANGER)
	t.set_stylebox("normal", "DangerButton", _box(Color("291a17"), DANGER.darkened(0.3)))
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, PANEL_BORDER))
	t.set_stylebox("background", "ProgressBar", _box(Color("080b08"), PANEL_BORDER))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 16)
	return t


static func label(text: String, font_size: int = 18, color: Color = TEXT, mono: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	if mono:
		l.add_theme_font_override("font", mono_font())
	return l


static func title(text: String, font_size: int = 44) -> Label:
	var l := label(text, font_size)
	l.add_theme_font_override("font", heading_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


static func button(parent: Control, text: String, action: Callable, primary: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 48
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		b.theme_type_variation = &"PrimaryButton"
	b.pressed.connect(action)
	parent.add_child(b)
	return b


static func texture(path: String, contain: bool = false) -> TextureRect:
	var rect := TextureRect.new()
	if ResourceLoader.exists(path):
		rect.texture = load(path) as Texture2D
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED if contain else TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func backdrop(parent: Control, path: String = "") -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	if path != "":
		var art := texture(path)
		art.set_anchors_preset(Control.PRESET_FULL_RECT)
		parent.add_child(art)


static func screen(parent: Control) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	parent.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	return box


static func section(parent: Control, text: String) -> void:
	parent.add_child(label(text, 16, MUTED, true))
	parent.add_child(HSeparator.new())


static func header(parent: Control, text: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var brand := label("SALVAGE & CO.\nHALVARD OPERATIONS", 16, TEXT, true)
	brand.custom_minimum_size.x = 180
	row.add_child(brand)
	var heading := title(text, 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(heading)
	var tag := label("PROJECT TIDE\nFIELD OPERATIONS", 16, MUTED, true)
	tag.custom_minimum_size.x = 160
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(tag)
	parent.add_child(HSeparator.new())


static func hints(parent: Control, text: String = "[ ENTER / A ] SELECT     [ ESC / B ] BACK", font_size: int = 16) -> void:
	var l := label(text, font_size, MUTED, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	parent.add_child(l)


static func panel(parent: Control) -> VBoxContainer:
	var plate := PanelContainer.new()
	parent.add_child(plate)
	var box := VBoxContainer.new()
	plate.add_child(box)
	return box


static func centered_panel(parent: Control, max_width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var box := panel(center)
	var width: float = minf(max_width, parent.get_viewport_rect().size.x - 64) if parent.is_inside_tree() else max_width
	(box.get_parent() as Control).custom_minimum_size.x = width
	return box


static func side_panel(parent: Control, width: float) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	margin.offset_left = -width - 32
	margin.offset_right = -32
	margin.offset_top = 32
	margin.offset_bottom = -32
	parent.add_child(margin)
	return panel(margin)
