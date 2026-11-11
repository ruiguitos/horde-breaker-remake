class_name Dossier
extends RefCounted
## The "field dossier" look of the menus (visual direction A, chosen by the user on 2026-11-10):
## the company's case file. Paper and ink, typewriter text, a stamp, photographs clipped to the
## page. Only the menus outside the island use it: the HUD and the dialogs keep UiTheme, whose
## light text is made for dark plates over the world.
## The typewriter voice is IBM Plex Mono, already bundled (OFL); a real typewriter face would be a
## new font to license and add.

const DESK := Color("3b3a33")  ## the table under the file
const PAPER := Color("e9e2d0")
const PAPER_DARK := Color("d8cfb8")  ## a second sheet, a hovered line
const PAPER_LINE := Color("b9ae93")  ## ruled lines and dashes
const INK := Color("1e1b16")
const INK_MUTED := Color("5a5345")  ## 5.4:1 on PAPER
const STAMP := Color("8e2019")  ## the red of a rubber stamp
const PHOTO_BORDER := Color("f4efe2")

static var _theme: Theme


## The menus' theme: UiTheme's, with the buttons and labels of a typed page.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = UiTheme.get_theme().duplicate(true)
	t.default_font = UiTheme.mono_font()
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var line := StyleBoxFlat.new()
		line.bg_color = PAPER_DARK if state in ["hover", "pressed", "hover_pressed"] else Color.TRANSPARENT
		line.border_color = PAPER_LINE
		line.border_width_bottom = 1
		line.content_margin_left = 10
		line.content_margin_right = 10
		line.content_margin_top = 8
		line.content_margin_bottom = 8
		t.set_stylebox(state, "Button", line)
	t.set_stylebox("focus", "Button", _frame(INK, 2))
	t.set_font("font", "Button", UiTheme.mono_bold_font())
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(colour, "Button", INK)
	t.set_color("font_disabled_color", "Button", INK_MUTED)
	# The primary line is inked in: paper letters on ink.
	for state: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var fill := StyleBoxFlat.new()
		fill.bg_color = INK if state == "normal" else INK.lightened(0.12)
		fill.content_margin_left = 10
		fill.content_margin_right = 10
		t.set_stylebox(state, "PrimaryButton", fill)
	t.set_stylebox("focus", "PrimaryButton", _frame(STAMP, 3))
	for colour: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(colour, "PrimaryButton", PAPER)
	t.set_color("font_color", "Label", INK)
	var rule := StyleBoxLine.new()
	rule.color = INK
	rule.thickness = 2
	t.set_stylebox("separator", "HSeparator", rule)
	_theme = t
	return t


static func _frame(color: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = color
	s.set_border_width_all(width)
	s.set_expand_margin_all(2)
	return s


## Typed text: mono, ink, no outline.
static func typed(text: String, font_size: int, color: Color = INK, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", UiTheme.mono_bold_font() if bold else UiTheme.mono_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", 0)
	return l


## A sheet of paper filling `rect`'s parent area set by the caller's anchors.
static func sheet(color: Color = PAPER) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## A rubber stamp: boxed red capitals, a few degrees off the line.
static func stamp(text: String, font_size: int = 18, degrees: float = -4.0) -> Label:
	var l := typed(text, font_size, STAMP, true)
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.border_color = STAMP
	box.set_border_width_all(3)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	l.add_theme_stylebox_override("normal", box)
	l.rotation_degrees = degrees
	return l


## A photograph clipped to the page: the picture in a pale border, slightly turned. The caller
## places it; it turns about its centre whatever its size.
static func photo(path: String, degrees: float = -1.2) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var border := StyleBoxFlat.new()
	border.bg_color = PHOTO_BORDER
	border.set_content_margin_all(10)
	border.shadow_color = Color(0, 0, 0, 0.35)
	border.shadow_size = 6
	frame.add_theme_stylebox_override("panel", border)
	var picture := UiTheme.texture(path)
	picture.clip_contents = true
	frame.add_child(picture)
	frame.rotation_degrees = degrees
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	return frame
