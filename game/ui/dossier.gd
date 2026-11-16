class_name Dossier
extends RefCounted
## The menus' look: "super simple" (chosen by the user on 2026-11-16, replacing the field
## dossier of 2026-11-10; see docs/DECISIONS.md and docs/design/MENUS.md). One flat dark ground,
## one type family, one amber accent; no paper, frames, stamps or photographs. The class keeps
## the dossier's names (PAPER is now the ground, INK the text, STAMP the accent) so every screen
## built on it changes at once; the names are historical.
## Fonts (OFL, in assets/fonts): Barlow Condensed SemiBold for titles and choices, Barlow for
## running text.

const DESK := Color("0e0f11")  ## behind the ground (was the table under the file)
const PAPER := Color("121315")  ## the ground
const PAPER_DARK := Color("1c1d20")  ## a hovered line, a quiet block
const PAPER_LINE := Color("34353a")  ## thin rules
const INK := Color("eceae4")  ## text, 15:1 on PAPER
const INK_MUTED := Color("9a978f")  ## secondary text, 6.5:1 on PAPER
const STAMP := Color("e0a43a")  ## the accent: the chosen line, the main action
const PHOTO_BORDER := Color("121315")
const CORK := Color("1c1d20")  ## the perks' board, now a quiet block
const TYPED_FONT := "res://assets/fonts/barlow_condensed/BarlowCondensed-SemiBold.ttf"
const BODY_FONT := "res://assets/fonts/barlow/Barlow-Regular.ttf"
const BODY_BOLD_FONT := "res://assets/fonts/barlow/Barlow-SemiBold.ttf"
const TYPED_SCALE := 1.0  ## the layouts were sized for the condensed face
const OLIVE := Color("8fbf6a")  ## "ok": owned, equipped (8.8:1 on PAPER)
const INK_BLUE := Color("7fb3d5")  ## information, the combat branch (8.4:1)

## UiTheme's names with the page's colours, so a menu's code reads the same in either look.
const TEXT := INK
const TEXT_MUTED := INK_MUTED
const MUTED := INK_MUTED
const LINE := Color(0, 0, 0, 0)  ## no frames in the simple look: a border drawn in LINE disappears
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


## The title face (Barlow Condensed SemiBold); the name stays from the typewriter of the dossier.
static func typed_font() -> Font:
	if not _fonts.has("typed"):
		_fonts["typed"] = load(TYPED_FONT) if ResourceLoader.exists(TYPED_FONT) else UiTheme.mono_bold_font()
	return _fonts["typed"]


## Running text: Barlow Regular, or SemiBold from weight 500 up.
static func body_font(weight: int = 400) -> Font:
	var key: String = "body%d" % weight
	if not _fonts.has(key):
		var path: String = BODY_BOLD_FONT if weight >= 500 else BODY_FONT
		if ResourceLoader.exists(path):
			_fonts[key] = load(path)
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
		line.bg_color = Color.TRANSPARENT
		line.content_margin_left = 10
		line.content_margin_right = 10
		line.content_margin_top = 8
		line.content_margin_bottom = 8
		t.set_stylebox(state, "Button", line)
	# The chosen line is amber, with a thin amber mark on its left (colour and shape, not colour alone).
	for item: String in ["font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(item, "Button", STAMP)
	t.set_stylebox("focus", "Button", _mark())
	t.set_stylebox("focus", "PrimaryButton", _mark())
	var rule := StyleBoxLine.new()
	rule.color = PAPER_LINE
	rule.thickness = 1
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
	# The dropdown arrow is drawn white for the dark look: an ink one on paper.
	t.set_icon("arrow", "OptionButton", _arrow())
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
		marked.dash_color = PAPER_LINE  # a faint outline: no frames, but an empty slot still reads as empty
		marked.mark_color = ink_of(marked.mark_color)
		marked.badge_ink = PAPER
	elif box is FocusBrackets:
		(box as FocusBrackets).color = STAMP


## A fill or a border of UiTheme's dark look, in the simple look: the amber of an action stays
## amber, panels sink into the ground, lines are thin rules.
static func paper_of(c: Color, border: bool = false) -> Color:
	if c.a <= 0.0:
		return c
	var out: Color
	if c.is_equal_approx(Color(UiTheme.ACCENT, c.a)):
		out = STAMP
	elif c.is_equal_approx(Color(UiTheme.SUCCESS, c.a)):
		out = OLIVE
	elif c.is_equal_approx(Color(UiTheme.DANGER, c.a)):
		out = STAMP
	elif c.is_equal_approx(Color(UiTheme.INFO, c.a)):
		out = INK_BLUE
	elif c.r > 0.75 and c.g > 0.45 and c.b < 0.5:
		out = STAMP.lightened(0.14)  # a hovered or pressed amber
	elif border:
		return Color.TRANSPARENT  # no frames: only accent, success, danger and info borders stay
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


## A status word (was the dossier's rubber stamp): plain amber capitals, level with the line.
static func stamp(text: String, font_size: int = 18, _degrees: float = 0.0) -> Label:
	return typed(text, font_size, STAMP, true)


## A photograph clipped to the page: the picture in a pale border, slightly turned. The caller
## places it; it turns about its centre whatever its size.
static func photo(path: String, _degrees: float = 0.0) -> PanelContainer:
	var frame := PanelContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var picture := UiTheme.texture(path)
	picture.clip_contents = true
	frame.add_child(picture)
	frame.resized.connect(func() -> void: frame.pivot_offset = frame.size * 0.5)
	return frame


## A flat sheet as a panel's box: paper (or cork), a soft shadow, room for the text.
static func sheet_box(color: Color = PAPER, margin: float = 14.0) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_content_margin_all(margin)
	return box  # flat: no shadow in the simple look


## A pin holding a card to the board: a round red head, centred on the card's top edge.
static func pin(color: Color = STAMP) -> Panel:
	var head := Panel.new()
	head.visible = false  # no pins in the simple look
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


## The chosen line's mark: a 3 px amber bar on its left edge.
static func _mark() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color.TRANSPARENT
	s.border_color = STAMP
	s.border_width_left = 3
	s.set_expand_margin_all(0)
	s.expand_margin_left = 8
	return s


## A dropdown chevron in ink.
static func _arrow() -> Texture2D:
	var img := Image.new()
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 16 16'><path d='M3 6l5 5 5-5' fill='none' stroke='#%s' stroke-width='2.5'/></svg>" % INK.to_html(false)
	if img.load_svg_from_string(svg, 1.0) != OK:
		return null
	return ImageTexture.create_from_image(img)
