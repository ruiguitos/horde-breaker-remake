class_name Dossier
extends RefCounted
## The "field dossier" look of the menus (visual direction A, chosen by the user on 2026-11-10):
## the company's case file. Paper and ink, typewriter text, a stamp, photographs clipped to the
## page. Only the menus outside the island use it: the HUD and the dialogs keep UiTheme, whose
## light text is made for dark plates over the world.
## Fonts: Special Elite, a worn typewriter face (Apache 2.0, accepted by the user for this font on
## 2026-11-11), for everything typed; Libre Franklin (OFL) for running text.

const DESK := Color("3b3a33")  ## the table under the file
const PAPER := Color("e9e2d0")
const PAPER_DARK := Color("d8cfb8")  ## a second sheet, a hovered line
const PAPER_LINE := Color("b9ae93")  ## ruled lines and dashes
const INK := Color("1e1b16")
const INK_MUTED := Color("5a5345")  ## 5.4:1 on PAPER
const STAMP := Color("8e2019")  ## the red of a rubber stamp
const PHOTO_BORDER := Color("f4efe2")
const CORK := Color("a58a63")  ## the pin board of the perks
const TYPED_FONT := "res://assets/fonts/special_elite/SpecialElite-Regular.ttf"
const BODY_FONT := "res://assets/fonts/libre_franklin/LibreFranklin-Variable.ttf"
const TYPED_SCALE := 0.82  ## a size meant for the condensed face, in the typewriter face
const OLIVE := Color("3f5a34")  ## "ok": owned, equipped (5.9:1 on PAPER)
const INK_BLUE := Color("27496b")  ## information, the combat branch

## UiTheme's names with the page's colours, so a menu's code reads the same in either look.
const TEXT := INK
const TEXT_MUTED := INK_MUTED
const MUTED := INK_MUTED
const LINE := PAPER_LINE
const ACCENT := STAMP
const ON_ACCENT := PAPER
const BG := PAPER
const PANEL := PAPER
const PANEL_RAISED := PAPER_DARK
const SUCCESS := OLIVE
const INFO := INK_BLUE
const DANGER := STAMP

static var _theme: Theme
static var _lined: Theme
static var _fonts: Dictionary = {}  ## key -> Font


## The typewriter face (one weight: a typewriter has no bold).
static func typed_font() -> Font:
	if not _fonts.has("typed"):
		_fonts["typed"] = load(TYPED_FONT) if ResourceLoader.exists(TYPED_FONT) else UiTheme.mono_bold_font()
	return _fonts["typed"]


## Running text, at a weight of the variable face (400 regular, 600 semibold).
static func body_font(weight: int = 400) -> Font:
	var key: String = "body%d" % weight
	if not _fonts.has(key):
		if ResourceLoader.exists(BODY_FONT):
			var v := FontVariation.new()
			v.base_font = load(BODY_FONT)
			v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
			_fonts[key] = v
		else:
			_fonts[key] = UiTheme.body_font()
	return _fonts[key]


## The title's theme: the page's theme with its buttons as ruled lines of an index.
static func lined_theme() -> Theme:
	if _lined != null:
		return _lined
	var t: Theme = theme().duplicate(true)
	t.default_font = typed_font()
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
	t.set_stylebox("focus", "PrimaryButton", _frame(STAMP, 3))
	var rule := StyleBoxLine.new()
	rule.color = INK
	rule.thickness = 2
	t.set_stylebox("separator", "HSeparator", rule)
	_lined = t
	return t


## The menus' theme: every box and colour of UiTheme's, turned to paper and ink. The shapes stay
## (ticks, dashes, padlocks, brackets), so the states still differ by shape and not only by colour.
static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t: Theme = UiTheme.get_theme().duplicate(true)
	for type: String in t.get_stylebox_type_list():
		for item: String in t.get_stylebox_list(type):
			_to_paper(t.get_stylebox(item, type))
	for type: String in t.get_color_type_list():
		for item: String in t.get_color_list(type):
			t.set_color(item, type, ink_of(t.get_color(item, type)))
	# Running text in Libre Franklin; every title, button and label that was condensed or mono is typed.
	var running: Array[Font] = [UiTheme.body_font(), UiTheme.body_medium_font()]
	t.default_font = body_font()
	for type: String in t.get_font_type_list():
		for item: String in t.get_font_list(type):
			var was: Font = t.get_font(item, type)
			if was in running:
				t.set_font(item, type, body_font())
			elif was == UiTheme.body_bold_font():
				t.set_font(item, type, body_font(600))
			else:
				t.set_font(item, type, typed_font())
				if t.has_font_size("font_size", type):
					t.set_font_size("font_size", type, roundi(t.get_font_size("font_size", type) * TYPED_SCALE))
	_theme = t
	return t


## A box of the dark look as the same box on paper.
static func _to_paper(box: StyleBox) -> void:
	if box is StyleBoxFlat:
		var flat := box as StyleBoxFlat
		flat.bg_color = paper_of(flat.bg_color)
		flat.border_color = paper_of(flat.border_color, true)
	elif box is StyleBoxLine:
		(box as StyleBoxLine).color = PAPER_LINE
	elif box is MarkedBox:
		var marked := box as MarkedBox
		_to_paper(marked.base)
		marked.dash_color = INK_MUTED
		marked.mark_color = ink_of(marked.mark_color)
		marked.badge_ink = PAPER
	elif box is FocusBrackets:
		(box as FocusBrackets).color = STAMP


## A fill or a border of the dark look, on paper: the amber of an action is inked in, panels are
## sheets, lines are ruled lines.
static func paper_of(c: Color, border: bool = false) -> Color:
	if c.a <= 0.0:
		return c
	var out: Color
	if c.is_equal_approx(Color(UiTheme.ACCENT, c.a)):
		out = INK
	elif c.is_equal_approx(Color(UiTheme.SUCCESS, c.a)):
		out = OLIVE
	elif c.is_equal_approx(Color(UiTheme.DANGER, c.a)):
		out = STAMP
	elif c.is_equal_approx(Color(UiTheme.INFO, c.a)):
		out = INK_BLUE
	elif c.r > 0.75 and c.g > 0.45 and c.b < 0.5:
		out = INK.lightened(0.14)  # a hovered or pressed amber: still inked in
	elif border:
		out = INK if c.get_luminance() > 0.6 else PAPER_LINE
	elif c.is_equal_approx(Color(UiTheme.PANEL_RAISED, c.a)):
		out = PAPER_DARK
	elif c.get_luminance() < 0.35:
		out = PAPER
	else:
		out = PAPER_DARK
	return Color(out, maxf(c.a, 0.96) if not border and c.a > 0.5 else c.a)


## A text colour of the dark look, on paper.
static func ink_of(c: Color) -> Color:
	var out: Color
	if c.is_equal_approx(Color(UiTheme.ON_ACCENT, c.a)) or c.is_equal_approx(Color(UiTheme.BG, c.a)):
		out = PAPER
	elif c.is_equal_approx(Color(UiTheme.TEXT_MUTED, c.a)):
		out = INK_MUTED
	elif c.is_equal_approx(Color(UiTheme.ACCENT, c.a)) or c.is_equal_approx(Color(UiTheme.DANGER, c.a)):
		out = STAMP
	elif c.is_equal_approx(Color(UiTheme.SUCCESS, c.a)):
		out = OLIVE
	elif c.is_equal_approx(Color(UiTheme.INFO, c.a)):
		out = INK_BLUE
	elif c.get_luminance() > 0.5:
		out = INK
	else:
		out = PAPER
	return Color(out, c.a)


## UiTheme.label in ink.
static func label(text: String, font_size: int = 18, color: Color = INK, mono: bool = false) -> Label:
	var l := UiTheme.label(text, font_size, color)
	l.add_theme_font_override("font", typed_font() if mono else body_font())
	return l


## UiTheme.title in ink.
static func title(text: String, font_size: int = 44) -> Label:
	# The typewriter face is about a quarter wider than the condensed one the layouts were sized for.
	var l := UiTheme.title(text, roundi(font_size * TYPED_SCALE))
	l.add_theme_color_override("font_color", INK)
	l.add_theme_font_override("font", typed_font())
	return l


## UiTheme.icon_hint with its word in ink.
static func icon_hint(parent: Control, keys: Array, pads: Array, word: String) -> HBoxContainer:
	var hint := UiTheme.icon_hint(parent, keys, pads, word)
	(hint.get_child(hint.get_child_count() - 1) as Label).add_theme_color_override("font_color", INK_MUTED)
	return hint


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
	l.add_theme_font_override("font", typed_font())
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


## A flat sheet as a panel's box: paper (or cork), a soft shadow, room for the text.
static func sheet_box(color: Color = PAPER, margin: float = 14.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(margin)
	box.shadow_color = Color(0, 0, 0, 0.3)
	box.shadow_size = 4
	return box


## A pin holding a card to the board: a round red head, centred on the card's top edge.
static func pin(color: Color = STAMP) -> Panel:
	var head := Panel.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot := StyleBoxFlat.new()
	dot.bg_color = color
	dot.set_corner_radius_all(7)
	dot.shadow_color = Color(0, 0, 0, 0.4)
	dot.shadow_size = 2
	head.add_theme_stylebox_override("panel", dot)
	head.set_anchors_preset(Control.PRESET_CENTER_TOP)
	head.offset_left = -7
	head.offset_right = 7
	head.offset_top = -7
	head.offset_bottom = 7
	return head
