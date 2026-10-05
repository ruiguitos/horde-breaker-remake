class_name UiTheme
extends RefCounted
## One Theme for every menu and the HUD, built in code (no assets): dark
## "field equipment" panels, amber accents and clear focus states so menus
## also work with a gamepad. Apply it to a root Control and every child
## inherits it.

const BG := Color(0.07, 0.08, 0.07)
const PANEL := Color(0.12, 0.13, 0.11, 0.94)
const PANEL_BORDER := Color(0.32, 0.3, 0.22)
const ACCENT := Color(1.0, 0.72, 0.2)
const TEXT := Color(0.9, 0.88, 0.8)
const MUTED := Color(0.6, 0.6, 0.55)
const DANGER := Color(0.9, 0.25, 0.2)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _box(bg: Color, border: Color, width: int = 2, radius: int = 4) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	# Labels: light text with a dark outline (readable over the 3D world).
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 4)
	# Buttons: dark plates, amber border when hovered/focused.
	t.set_stylebox("normal", "Button", _box(Color(0.16, 0.17, 0.14), PANEL_BORDER))
	t.set_stylebox("hover", "Button", _box(Color(0.22, 0.22, 0.16), ACCENT))
	t.set_stylebox("pressed", "Button", _box(Color(0.3, 0.24, 0.1), ACCENT))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), ACCENT, 3))
	t.set_stylebox("disabled", "Button", _box(Color(0.1, 0.1, 0.09), Color(0.2, 0.2, 0.18)))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_focus_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, PANEL_BORDER, 2, 6))
	# Progress bars: dark track.
	t.set_stylebox("background", "ProgressBar", _box(Color(0.05, 0.05, 0.05, 0.8), Color(0, 0, 0, 0.9), 1, 2))
	return t


## Title-style label (big amber text).
static func title(text: String, size: int = 44) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", ACCENT)
	l.add_theme_constant_override("outline_size", 8)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## A panel docked to the right edge (full height, with margins), so a 3D
## scene stays visible on the left.
static func side_panel(parent: Control, width: float) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	margin.offset_left = -width - 24
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.add_theme_constant_override("margin_right", 24)
	parent.add_child(margin)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(width, 0)
	margin.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(box)
	return box


## A centred panel filling at most `max_width`, returned with its content box.
static func centered_panel(parent: Control, max_width: float) -> VBoxContainer:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(max_width, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	return box
