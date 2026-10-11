class_name UiTheme
extends RefCounted
## Shared look for native menus and the HUD: palette B "Atlantic & azulejo"
## (basalt, sea, lime-wash; amber only for actions and focus), bundled OFL
## fonts and state styles that differ by shape, not only by colour:
## FOCUS = corner brackets (FocusBrackets), SELECTED = tick, DISABLED =
## dashed outline + muted text, LOCKED = dashed + padlock (MarkedBox).
##
## Theme type variations (set `theme_type_variation`):
##   Button:         PrimaryButton (amber fill), SelectedButton (tick),
##                   LockedButton (padlock when disabled), DangerButton
##                   (danger outline), QuietButton (no box until hovered).
##   PanelContainer: RaisedPanel, SelectedPanel (corner tick), DisabledPanel
##                   (dashed).
##   Label:          TitleLabel, HeadingLabel, BodyLabel, MutedLabel,
##                   MonoLabel, CaptionLabel, KeyLabel (keycap box).

# --- Palette B --------------------------------------------------------------
const BG := Color("0d1216")  ## basalt: screen background
const PANEL := Color("0f2830")  ## panels and cards
const PANEL_RAISED := Color("143540")  ## buttons, raised cards
const LINE := Color("2a5662")  ## outlines and separators
const TEXT := Color("ece6d3")  ## lime-wash: main text
const TEXT_MUTED := Color("9ab0b2")  ## secondary text, disabled text
const ACCENT := Color("f2b23a")  ## amber: ONLY actions and focus
const ON_ACCENT := Color("141210")  ## text on an amber fill
const DANGER := Color("e8705a")
const INFO := Color("6fa6e6")  ## objectives and information
const SUCCESS := Color("7fc8b8")  ## "ok": success, selected (tick). Not named OK (global Error.OK)
## Older names, kept so existing screens keep working.
const MUTED := TEXT_MUTED
const PANEL_BORDER := LINE

const HARBOR := "res://game/ui/art/harbor.png"
const CONTRACTOR := "res://game/ui/art/contractor.png"
const WORDMARK := "res://game/ui/art/wordmark.png"

# --- Fonts (OFL, assets/fonts/) ---------------------------------------------
const FONT_DIR := "res://assets/fonts/"
const TITLE_FONT := FONT_DIR + "barlow_condensed/BarlowCondensed-ExtraBold.ttf"
const HEADING_FONT := FONT_DIR + "barlow_condensed/BarlowCondensed-Bold.ttf"
const SUBHEADING_FONT := FONT_DIR + "barlow_condensed/BarlowCondensed-SemiBold.ttf"
const BODY_FONT := FONT_DIR + "barlow/Barlow-Regular.ttf"
const BODY_MEDIUM_FONT := FONT_DIR + "barlow/Barlow-Medium.ttf"
const BODY_BOLD_FONT := FONT_DIR + "barlow/Barlow-SemiBold.ttf"
const MONO_FONT := FONT_DIR + "ibm_plex_mono/IBMPlexMono-Regular.ttf"
const MONO_BOLD_FONT := FONT_DIR + "ibm_plex_mono/IBMPlexMono-SemiBold.ttf"

const RADIUS := 4

static var _theme: Theme
static var _fonts: Dictionary = {}  ## path -> Font
static var _icons: Dictionary = {}  ## name -> Texture2D


## Barlow Condensed ExtraBold: big screen titles.
static func title_font() -> Font:
	return _font(TITLE_FONT, ["Bahnschrift", "Arial Narrow"], 800)


## Barlow Condensed Bold: buttons, card names, HUD headings.
static func heading_font() -> Font:
	return _font(HEADING_FONT, ["Bahnschrift", "Arial Narrow"], 700)


## Barlow Condensed SemiBold: tabs and smaller headings.
static func subheading_font() -> Font:
	return _font(SUBHEADING_FONT, ["Bahnschrift", "Arial Narrow"], 600)


## Barlow Regular: body text (the theme's default font).
static func body_font() -> Font:
	return _font(BODY_FONT, ["Segoe UI", "Arial"], 400)


static func body_medium_font() -> Font:
	return _font(BODY_MEDIUM_FONT, ["Segoe UI", "Arial"], 500)


static func body_bold_font() -> Font:
	return _font(BODY_BOLD_FONT, ["Segoe UI", "Arial"], 600)


## IBM Plex Mono Regular: numbers, keys, codes.
static func mono_font() -> Font:
	return _font(MONO_FONT, ["Consolas", "Courier New"], 400)


static func mono_bold_font() -> Font:
	return _font(MONO_BOLD_FONT, ["Consolas", "Courier New"], 600)


## Loads a bundled font; falls back to a system font if it was not imported.
static func _font(path: String, fallback: Array, weight: int) -> Font:
	if not _fonts.has(path):
		if ResourceLoader.exists(path):
			_fonts[path] = load(path) as Font
		else:
			var sys := SystemFont.new()
			sys.font_names = PackedStringArray(fallback)
			sys.font_weight = weight
			_fonts[path] = sys
	return _fonts[path]


## A font with extra space between letters (tracking), as in the mockups'
## buttons and mono captions.
static func _spaced(base: Font, glyph_spacing: int) -> FontVariation:
	var f := FontVariation.new()
	f.base_font = base
	f.spacing_glyph = glyph_spacing
	return f


# --- Icons (drawn from SVG in code: white, tinted where they are used) -------

## Tick for SELECTED (white; tint it with SUCCESS).
static func tick_icon() -> Texture2D:
	return _icon("tick", "<path d='M3 9.5l4 4 8-9' fill='none' stroke='#fff' stroke-width='2.5'/>", 18, 18)


## Padlock for LOCKED (white; tint it with TEXT_MUTED).
static func lock_icon() -> Texture2D:
	return _icon("lock", "<rect x='3' y='8' width='12' height='9' rx='1.5' fill='none' stroke='#fff' stroke-width='2'/><path d='M6 8V5.5a3 3 0 0 1 6 0V8' fill='none' stroke='#fff' stroke-width='2'/>", 18, 18)


## Rasterised at 2x and shown at 1x, so icons stay sharp when the window is
## bigger than the 1152x648 base size (canvas_items stretch).
static func _icon(id: String, body: String, w: int, h: int) -> Texture2D:
	if not _icons.has(id):
		var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='%d' height='%d' viewBox='0 0 %d %d'>%s</svg>" % [w, h, w, h, body]
		var img := Image.new()
		var tex: ImageTexture
		if img.load_svg_from_string(svg, 2.0) == OK:
			tex = ImageTexture.create_from_image(img)
		else:
			tex = ImageTexture.create_from_image(Image.create(w * 2, h * 2, false, Image.FORMAT_RGBA8))
		tex.set_size_override(Vector2i(w, h))
		_icons[id] = tex
	return _icons[id]


static func _hex(c: Color) -> String:
	return "#" + c.to_html(false)


# --- Theme -------------------------------------------------------------------

static func get_theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


static func _box(bg: Color, border: Color, width: int = 1, radius: int = RADIUS) -> StyleBoxFlat:
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


static func _margins(s: StyleBox, h: float, v: float) -> StyleBox:
	s.content_margin_left = h
	s.content_margin_right = h
	s.content_margin_top = v
	s.content_margin_bottom = v
	return s


## SELECTED: the base box plus a tick (left of the text on short buttons, a
## corner badge on tall cards).
static func _ticked(base: StyleBoxFlat, place: MarkedBox.Place = MarkedBox.Place.AUTO) -> MarkedBox:
	var m := MarkedBox.new(base)
	m.mark_texture = tick_icon()
	m.mark_color = SUCCESS
	m.place = place
	m.sync_margins()
	return m


## DISABLED: transparent, dashed outline (LOCKED adds a padlock).
static func _dashed(locked: bool = false, color: Color = LINE.lightened(0.2)) -> MarkedBox:
	var m := MarkedBox.new(_box(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	m.dashed = true
	m.dash_color = color
	if locked:
		m.mark_texture = lock_icon()
		m.mark_color = TEXT_MUTED
	m.sync_margins()
	return m


static func focus_style() -> FocusBrackets:
	var f := FocusBrackets.new()
	f.color = ACCENT
	return f


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 18
	_labels(t)
	_buttons(t)
	_inputs(t)
	_containers(t)
	return t


static func _labels(t: Theme) -> void:
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("outline_size", "Label", 2)
	var variations := {
		"TitleLabel": [title_font(), 44, TEXT],
		"HeadingLabel": [heading_font(), 28, TEXT],
		"BodyLabel": [body_font(), 18, TEXT],
		"MutedLabel": [body_font(), 16, TEXT_MUTED],
		"MonoLabel": [mono_font(), 16, TEXT],
		"CaptionLabel": [_spaced(mono_font(), 2), 14, TEXT_MUTED],
		"KeyLabel": [mono_bold_font(), 16, TEXT],
	}
	for v: String in variations:
		t.set_type_variation(v, "Label")
		t.set_font("font", v, variations[v][0])
		t.set_font_size("font_size", v, variations[v][1])
		t.set_color("font_color", v, variations[v][2])
		t.set_constant("outline_size", v, 0)
	t.set_stylebox("normal", "KeyLabel", _margins(_box(BG, LINE, 1, 3), 8, 2))
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", body_font())
	t.set_font("bold_font", "RichTextLabel", body_bold_font())
	t.set_font("mono_font", "RichTextLabel", mono_font())
	t.set_font_size("normal_font_size", "RichTextLabel", 18)
	t.set_stylebox("panel", "TooltipPanel", _margins(_box(PANEL_RAISED, LINE), 10, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 16)


static func _buttons(t: Theme) -> void:
	var states := ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]
	var icons := ["icon_normal_color", "icon_hover_color", "icon_focus_color", "icon_pressed_color", "icon_hover_pressed_color"]
	# Plain button: raised panel, line outline; hover lights the outline.
	t.set_font("font", "Button", _spaced(heading_font(), 1))
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("normal", "Button", _box(PANEL_RAISED, LINE))
	t.set_stylebox("hover", "Button", _box(PANEL_RAISED.lightened(0.06), TEXT))
	t.set_stylebox("pressed", "Button", _box(PANEL, ACCENT))
	t.set_stylebox("hover_pressed", "Button", _box(PANEL, ACCENT))
	t.set_stylebox("focus", "Button", focus_style())
	t.set_stylebox("disabled", "Button", _dashed())
	for c in states:
		t.set_color(c, "Button", TEXT)
	for c in icons:
		t.set_color(c, "Button", TEXT)
	t.set_color("font_disabled_color", "Button", TEXT_MUTED)
	t.set_color("icon_disabled_color", "Button", TEXT_MUTED)
	t.set_constant("h_separation", "Button", 8)

	# Primary action: amber fill, dark text.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _box(ACCENT, ACCENT))
	t.set_stylebox("hover", "PrimaryButton", _box(ACCENT.lightened(0.15), ACCENT.lightened(0.15)))
	t.set_stylebox("pressed", "PrimaryButton", _box(ACCENT.darkened(0.15), ACCENT.darkened(0.15)))
	t.set_stylebox("hover_pressed", "PrimaryButton", _box(ACCENT.darkened(0.15), ACCENT.darkened(0.15)))
	t.set_stylebox("disabled", "PrimaryButton", _dashed(false, ACCENT.darkened(0.45)))
	for c in states + icons:
		t.set_color(c, "PrimaryButton", ON_ACCENT)

	# Selected (chosen route, equipped perk, active tab): tick + teal outline.
	t.set_type_variation("SelectedButton", "Button")
	var sel_bg := PANEL_RAISED.lerp(SUCCESS, 0.1)
	t.set_stylebox("normal", "SelectedButton", _ticked(_box(sel_bg, SUCCESS.darkened(0.35))))
	t.set_stylebox("hover", "SelectedButton", _ticked(_box(sel_bg.lightened(0.06), TEXT)))
	t.set_stylebox("pressed", "SelectedButton", _ticked(_box(PANEL, ACCENT)))
	t.set_stylebox("hover_pressed", "SelectedButton", _ticked(_box(PANEL, ACCENT)))
	var sel_off := _dashed()
	sel_off.mark_texture = tick_icon()
	sel_off.mark_color = SUCCESS.darkened(0.2)
	sel_off.sync_margins()
	t.set_stylebox("disabled", "SelectedButton", sel_off)
	t.set_color("font_disabled_color", "SelectedButton", TEXT)

	# Locked: the disabled state carries a padlock.
	t.set_type_variation("LockedButton", "Button")
	t.set_stylebox("disabled", "LockedButton", _dashed(true))

	# Danger (abandon, delete): danger outline, never a fill until pressed.
	t.set_type_variation("DangerButton", "Button")
	t.set_stylebox("normal", "DangerButton", _box(PANEL_RAISED.lerp(DANGER, 0.06), DANGER, 2))
	t.set_stylebox("hover", "DangerButton", _box(PANEL_RAISED.lerp(DANGER, 0.2), DANGER, 2))
	t.set_stylebox("pressed", "DangerButton", _box(PANEL_RAISED.lerp(DANGER, 0.35), DANGER, 2))
	t.set_stylebox("hover_pressed", "DangerButton", _box(PANEL_RAISED.lerp(DANGER, 0.35), DANGER, 2))
	t.set_stylebox("disabled", "DangerButton", _dashed(false, DANGER.darkened(0.45)))
	for c in states + icons:
		t.set_color(c, "DangerButton", DANGER.lightened(0.15))

	# Quiet (secondary, e.g. development entries): no box until hovered.
	t.set_type_variation("QuietButton", "Button")
	t.set_font("font", "QuietButton", _spaced(subheading_font(), 1))
	t.set_font_size("font_size", "QuietButton", 18)
	t.set_stylebox("normal", "QuietButton", _box(Color.TRANSPARENT, Color.TRANSPARENT, 0))
	t.set_stylebox("hover", "QuietButton", _box(Color.TRANSPARENT, LINE))
	for c in states + icons:
		t.set_color(c, "QuietButton", TEXT_MUTED)
	t.set_color("font_hover_color", "QuietButton", TEXT)
	t.set_color("font_focus_color", "QuietButton", TEXT)

	# OptionButton (+ its PopupMenu): values read as body text, not titles.
	t.set_font("font", "OptionButton", body_medium_font())
	t.set_font_size("font_size", "OptionButton", 18)
	t.set_stylebox("normal", "OptionButton", _box(PANEL_RAISED, LINE))
	t.set_stylebox("hover", "OptionButton", _box(PANEL_RAISED.lightened(0.06), TEXT))
	t.set_stylebox("pressed", "OptionButton", _box(PANEL, ACCENT))
	t.set_stylebox("focus", "OptionButton", focus_style())
	t.set_stylebox("disabled", "OptionButton", _dashed())
	t.set_icon("arrow", "OptionButton", _icon("arrow", "<path d='M3 6l5 5 5-5' fill='none' stroke='#fff' stroke-width='2.5'/>", 16, 16))
	t.set_constant("arrow_margin", "OptionButton", 12)
	t.set_stylebox("panel", "PopupMenu", _margins(_box(PANEL_RAISED, LINE), 6, 6))
	var popup_hover := _box(PANEL_RAISED.lightened(0.1), ACCENT, 0)
	popup_hover.border_width_left = 3
	t.set_stylebox("hover", "PopupMenu", popup_hover)
	t.set_stylebox("separator", "PopupMenu", _line(false))
	t.set_font("font", "PopupMenu", body_font())
	t.set_font_size("font_size", "PopupMenu", 18)
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", TEXT)
	t.set_color("font_disabled_color", "PopupMenu", TEXT_MUTED)
	t.set_color("font_accelerator_color", "PopupMenu", TEXT_MUTED)
	t.set_constant("v_separation", "PopupMenu", 10)
	t.set_constant("h_separation", "PopupMenu", 10)
	var ok_tick := _icon("tick_ok", "<path d='M3 9.5l4 4 8-9' fill='none' stroke='%s' stroke-width='2.5'/>" % _hex(SUCCESS), 18, 18)
	var blank := _icon("blank", "", 18, 18)
	for icon in ["radio_checked", "checked"]:
		t.set_icon(icon, "PopupMenu", ok_tick)
	for icon in ["radio_unchecked", "unchecked"]:
		t.set_icon(icon, "PopupMenu", blank)

	# CheckBox / CheckButton: the box or switch carries the state; text is body.
	var toggles := {
		"CheckBox": {
			"unchecked": _icon("cb_off", "<rect x='2' y='2' width='20' height='20' rx='3' fill='%s' stroke='%s' stroke-width='2'/>" % [_hex(BG), _hex(LINE.lightened(0.25))], 24, 24),
			"checked": _icon("cb_on", "<rect x='2' y='2' width='20' height='20' rx='3' fill='%s' stroke='%s' stroke-width='2'/><path d='M6 12.5l4 4 8-9' fill='none' stroke='%s' stroke-width='3'/>" % [_hex(PANEL_RAISED), _hex(TEXT), _hex(SUCCESS)], 24, 24),
			"unchecked_disabled": _icon("cb_off_x", "<rect x='2' y='2' width='20' height='20' rx='3' fill='none' stroke='%s' stroke-width='2' stroke-dasharray='4 3'/>" % _hex(LINE.lightened(0.2)), 24, 24),
			"checked_disabled": _icon("cb_on_x", "<rect x='2' y='2' width='20' height='20' rx='3' fill='none' stroke='%s' stroke-width='2' stroke-dasharray='4 3'/><path d='M6 12.5l4 4 8-9' fill='none' stroke='%s' stroke-width='3'/>" % [_hex(LINE.lightened(0.2)), _hex(TEXT_MUTED)], 24, 24),
		},
		"CheckButton": {
			"unchecked": _icon("sw_off", "<rect x='1' y='1' width='46' height='24' rx='12' fill='%s' stroke='%s' stroke-width='2'/><circle cx='13' cy='13' r='7' fill='%s'/>" % [_hex(BG), _hex(LINE.lightened(0.25)), _hex(TEXT_MUTED)], 48, 26),
			"checked": _icon("sw_on", "<rect x='1' y='1' width='46' height='24' rx='12' fill='%s' stroke='%s' stroke-width='2'/><path d='M8 13l3.5 3.5 6-7' fill='none' stroke='%s' stroke-width='2.5'/><circle cx='35' cy='13' r='8' fill='%s'/>" % [_hex(SUCCESS), _hex(SUCCESS), _hex(ON_ACCENT), _hex(TEXT)], 48, 26),
			"unchecked_disabled": _icon("sw_off_x", "<rect x='1' y='1' width='46' height='24' rx='12' fill='none' stroke='%s' stroke-width='2' stroke-dasharray='5 3'/><circle cx='13' cy='13' r='7' fill='%s'/>" % [_hex(LINE.lightened(0.2)), _hex(LINE)], 48, 26),
			"checked_disabled": _icon("sw_on_x", "<rect x='1' y='1' width='46' height='24' rx='12' fill='none' stroke='%s' stroke-width='2' stroke-dasharray='5 3'/><circle cx='35' cy='13' r='8' fill='%s'/>" % [_hex(LINE.lightened(0.2)), _hex(TEXT_MUTED)], 48, 26),
		},
	}
	for type: String in toggles:
		var icon_set: Dictionary = toggles[type]
		for icon: String in icon_set:
			t.set_icon(icon, type, icon_set[icon])
			# CheckBox also serves as a radio button; CheckButton has RTL copies.
			t.set_icon(icon + "_mirrored" if type == "CheckButton" else "radio_" + icon, type, icon_set[icon])
		t.set_font("font", type, body_medium_font())
		t.set_font_size("font_size", type, 18)
		t.set_stylebox("normal", type, _margins(StyleBoxEmpty.new(), 6, 6))
		t.set_stylebox("pressed", type, _margins(StyleBoxEmpty.new(), 6, 6))
		t.set_stylebox("hover", type, _margins(_box(PANEL_RAISED, Color.TRANSPARENT, 0), 6, 6))
		t.set_stylebox("hover_pressed", type, _margins(_box(PANEL_RAISED, Color.TRANSPARENT, 0), 6, 6))
		t.set_stylebox("disabled", type, _margins(StyleBoxEmpty.new(), 6, 6))
		t.set_stylebox("focus", type, focus_style())
		for c in states:
			t.set_color(c, type, TEXT)
		t.set_color("font_disabled_color", type, TEXT_MUTED)
		t.set_constant("h_separation", type, 10)


static func _inputs(t: Theme) -> void:
	# HSlider: dark track, muted fill (amber while focused/hovered), a bar
	# grabber that turns amber with focus.
	t.set_stylebox("slider", "HSlider", _margins(_box(BG, LINE, 1, 3), 0, 4))
	t.set_stylebox("grabber_area", "HSlider", _margins(_box(TEXT_MUTED, TEXT_MUTED, 0, 3), 0, 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", _margins(_box(ACCENT, ACCENT, 0, 3), 0, 4))
	var grabber := "<rect x='2' y='1' width='10' height='24' rx='2' fill='%s' stroke='%s' stroke-width='2'/>"
	t.set_icon("grabber", "HSlider", _icon("grab", grabber % [_hex(TEXT), _hex(BG)], 14, 26))
	t.set_icon("grabber_highlight", "HSlider", _icon("grab_hi", grabber % [_hex(ACCENT), _hex(BG)], 14, 26))
	t.set_icon("grabber_disabled", "HSlider", _icon("grab_x", grabber % [_hex(LINE), _hex(BG)], 14, 26))
	t.set_stylebox("focus", "HSlider", focus_style())
	t.set_constant("center_grabber", "HSlider", 0)

	# LineEdit (and the field inside SpinBox): sunk basalt field, mono digits.
	t.set_font("font", "LineEdit", mono_font())
	t.set_font_size("font_size", "LineEdit", 18)
	t.set_stylebox("normal", "LineEdit", _margins(_box(BG, LINE, 1, 3), 10, 6))
	t.set_stylebox("focus", "LineEdit", focus_style())
	t.set_stylebox("read_only", "LineEdit", _margins(_dashed(), 10, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_selected_color", "LineEdit", TEXT)
	t.set_color("font_uneditable_color", "LineEdit", TEXT_MUTED)
	t.set_color("font_placeholder_color", "LineEdit", Color(TEXT_MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", ACCENT)
	t.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))
	t.set_color("clear_button_color", "LineEdit", TEXT_MUTED)
	t.set_constant("caret_width", "LineEdit", 2)

	# Progress bars (the HUD overrides its own meters).
	t.set_stylebox("background", "ProgressBar", _margins(_box(BG, LINE, 1, 3), 0, 0))
	t.set_stylebox("fill", "ProgressBar", _margins(_box(ACCENT, ACCENT, 0, 3), 0, 0))
	t.set_font("font", "ProgressBar", mono_font())
	t.set_color("font_color", "ProgressBar", TEXT)


static func _line(vertical: bool) -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = LINE
	s.thickness = 1
	s.vertical = vertical
	return s


static func _containers(t: Theme) -> void:
	t.set_stylebox("panel", "PanelContainer", _margins(_box(Color(PANEL, 0.96), LINE), 18, 16))
	t.set_type_variation("RaisedPanel", "PanelContainer")
	t.set_stylebox("panel", "RaisedPanel", _margins(_box(PANEL_RAISED, LINE), 18, 16))
	t.set_type_variation("SelectedPanel", "PanelContainer")
	var sel := _ticked(_margins(_box(PANEL_RAISED.lerp(SUCCESS, 0.1), SUCCESS.darkened(0.35)), 18, 16) as StyleBoxFlat, MarkedBox.Place.TOP_RIGHT)
	t.set_stylebox("panel", "SelectedPanel", sel)
	t.set_type_variation("DisabledPanel", "PanelContainer")
	t.set_stylebox("panel", "DisabledPanel", _margins(_dashed(), 18, 16))
	t.set_stylebox("separator", "HSeparator", _line(false))
	t.set_constant("separation", "HSeparator", 12)
	t.set_stylebox("separator", "VSeparator", _line(true))
	t.set_constant("separation", "VBoxContainer", 12)
	t.set_constant("separation", "HBoxContainer", 16)

	# Scroll bars: slim, muted grabber that goes amber while dragged.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, _margins(_box(Color(BG, 0.6), Color.TRANSPARENT, 0), 5, 5))
		t.set_stylebox("scroll_focus", bar, _margins(_box(Color(BG, 0.6), Color.TRANSPARENT, 0), 5, 5))
		t.set_stylebox("grabber", bar, _margins(_box(LINE.lightened(0.2), Color.TRANSPARENT, 0), 5, 5))
		t.set_stylebox("grabber_highlight", bar, _margins(_box(TEXT_MUTED, Color.TRANSPARENT, 0), 5, 5))
		t.set_stylebox("grabber_pressed", bar, _margins(_box(ACCENT, Color.TRANSPARENT, 0), 5, 5))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())
	t.set_stylebox("focus", "ScrollContainer", StyleBoxEmpty.new())

	# Tabs (TabBar and TabContainer): the active tab gets the tick.
	for type in ["TabBar", "TabContainer"]:
		t.set_font("font", type, _spaced(subheading_font(), 1))
		t.set_font_size("font_size", type, 20)
		t.set_stylebox("tab_unselected", type, _margins(_box(Color.TRANSPARENT, Color.TRANSPARENT, 0), 16, 8))
		t.set_stylebox("tab_hovered", type, _margins(_box(PANEL_RAISED, LINE), 16, 8))
		t.set_stylebox("tab_selected", type, _ticked(_margins(_box(PANEL_RAISED.lerp(SUCCESS, 0.1), SUCCESS.darkened(0.35)), 16, 8) as StyleBoxFlat))
		t.set_stylebox("tab_disabled", type, _margins(_dashed(), 16, 8))
		t.set_stylebox("tab_focus", type, focus_style())
		t.set_color("font_selected_color", type, TEXT)
		t.set_color("font_hovered_color", type, TEXT)
		t.set_color("font_unselected_color", type, TEXT_MUTED)
		t.set_color("font_disabled_color", type, Color(TEXT_MUTED, 0.6))
	t.set_stylebox("panel", "TabContainer", _margins(_box(PANEL, LINE), 16, 16))


# --- Builders -----------------------------------------------------------------

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


## Screen/panel title: Barlow Condensed ExtraBold from 32 px up, Bold below
## (ExtraBold gets cramped at small sizes).
static func title(text: String, font_size: int = 44) -> Label:
	var l := label(text, font_size)
	l.add_theme_font_override("font", title_font() if font_size >= 32 else heading_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Outlined tag, e.g. chip("▲ SUPPLY SHORTAGE", UiTheme.DANGER).
static func chip(text: String, color: Color, font_size: int = 14) -> Label:
	var l := label(text, font_size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.add_theme_font_override("font", mono_bold_font())
	l.add_theme_stylebox_override("normal", _margins(_box(Color.TRANSPARENT, color, 1, 3), 10, 4))
	l.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
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


## SELECTED state (tick) on or off. Turning it off only clears the
## SelectedButton variation, so other variations are left alone.
static func set_selected(b: Button, on: bool) -> void:
	if on:
		b.theme_type_variation = &"SelectedButton"
	elif b.theme_type_variation == &"SelectedButton":
		b.theme_type_variation = &""


## LOCKED state: disabled, padlock, dashed; the reason goes to the tooltip
## (screens should also write it on the button or next to it).
static func set_locked(b: Button, locked: bool, reason: String = "") -> void:
	b.disabled = locked
	if locked:
		b.theme_type_variation = &"LockedButton"
		b.tooltip_text = reason
	elif b.theme_type_variation == &"LockedButton":
		b.theme_type_variation = &""


## Draws a tick (SELECTED) inside `rect` from a Control's _draw().
static func draw_tick(item: CanvasItem, rect: Rect2, color: Color = SUCCESS) -> void:
	item.draw_texture_rect(tick_icon(), rect, false, color)


## Draws the focus brackets around `rect` from a Control's _draw() (for
## custom-drawn cards that cannot use the "focus" stylebox).
static func draw_focus(item: CanvasItem, rect: Rect2) -> void:
	focus_style().draw(item.get_canvas_item(), rect)


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


## Card background for custom widgets (perk tree nodes): a filled box, or
## the dashed outline of a LOCKED item when `dashed`.
static func card_box(bg: Color, border: Color, width: int = 1, dashed: bool = false) -> StyleBox:
	var box: StyleBox = _dashed(false, border) if dashed else _box(bg, border, width)
	return _margins(box, 10, 8)


## One control hint: the platform's button/key icons (InputIcons, so the
## Settings "Controller icons" choice applies) and a word. `keys` are shown
## without a gamepad, `pads` ("joy:N") with one connected.
static func icon_hint(parent: Control, keys: Array, pads: Array, word: String) -> HBoxContainer:
	var hint := HBoxContainer.new()
	hint.name = "Hint" + word.to_pascal_case()
	hint.add_theme_constant_override("separation", 6)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(hint)
	var icons := RichTextLabel.new()
	icons.name = "Icons"
	icons.bbcode_enabled = true  # InputIcons writes [img] tags
	icons.fit_content = true
	icons.autowrap_mode = TextServer.AUTOWRAP_OFF
	icons.scroll_active = false
	icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icons.add_theme_font_override("normal_font", mono_font())
	icons.add_theme_font_size_override("normal_font_size", 13)
	hint.add_child(icons)
	InputIcons.fill(icons, pads if not Input.get_connected_joypads().is_empty() else keys)
	var l := label(word, 13, TEXT_MUTED, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hint.add_child(l)
	return hint


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
