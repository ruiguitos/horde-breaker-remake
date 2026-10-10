class_name Hud
extends CanvasLayer
## In-run HUD, level-up cards and the pause menu. Reads IslandRun and never
## changes game rules: choices leave as signals for the island to apply.
##
## Field HUD has no panels: text and icons sit straight on the game with a
## dark outline and shadow (MenuDialog.ink), so the island stays visible.
## Only world markers (objective pill, threat arrows) keep a small dark pill,
## because they float over anything. Layout follows the October 2026 mockup:
## objective top-centre, map top-right, status bottom-left, abilities
## bottom-centre, weapon bottom-right.

signal card_chosen(index: int)
signal reroll_requested
signal resume_requested
signal abandon_requested

## Cards ignore presses this long after they open (or are rerolled), so a
## button mashed in combat cannot take a card blind.
const CARD_LOCK_MS: int = 400
## Specials and the boss closer than this get an arrow at the screen edge.
const THREAT_RANGE: float = 40.0
const THREAT_ARROWS_MAX: int = 4
## Category marks: shape and colour (never colour alone).
const CATEGORY_GLYPH: Dictionary = {&"breaker": "◆", &"firearms": "●", &"survival": "■"}
const ROMAN: Array[String] = ["0", "I", "II", "III", "IV", "V", "VI"]
## Pill behind world markers (dark sea blue, mostly opaque).
const MARKER_BG := Color(0.04, 0.1, 0.125, 0.86)

var debug_visible: bool = false
var profile: Profile
var context: RunContext  ## set by the island; null when the island runs alone (F6)
var _pause_dialog: MenuDialog
var _run: IslandRun

# Field HUD (scaled by Settings > Display > HUD size)
var _field: Control
var _objective_box: VBoxContainer
var _objective: Label
var _objective_detail: Label
var _objective_pips: Pips
var _survivor_row: HBoxContainer
var _survivor_bar: ProgressBar
var _survivor_text: Label
var _boss_row: VBoxContainer
var _boss_name: Label
var _boss_bar: ProgressBar
var _map_box: VBoxContainer
var _minimap: Minimap
var _legend: Minimap.Legend
var _status_panel: VBoxContainer
var _info: Label
var _hp_text: Label
var _hp_max: Label
var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _xp_text: Label
var _stats: Label
var _abilities_panel: VBoxContainer
var _breaker_ring: AbilityRing
var _ability_ring: AbilityRing
var _breaker_status: Label
var _ability_status: Label
var _ability_name: Label
var _ability_icon: FieldIcon
var _breaker_key: Label
var _ability_key: Label
var _sprint_row: HBoxContainer
var _sprint_key: Label
var _stamina_bar: ProgressBar
var _weapon_panel: VBoxContainer
var _weapon_name: Label
var _ammo_text: Label
var _weapon_slots: WeaponSlots
var _fire_status: Label
var _switch_hint: Label
var _radio_panel: VBoxContainer
var _radio_text: Label
var _radio_queue: PackedStringArray = PackedStringArray()
var _radio_time: float = 0.0
var _radio_rng := RandomNumberGenerator.new()
var _alerts: Label

# World overlays (not scaled)
var _marker_pill: PanelContainer
var _marker: Label
var _threats: ThreatArrows
var _hit_arc: Control
var _hit_angle: float = 0.0
var _hit_alpha: float = 0.0
var _popups: Array[Label] = []
var _popup_world: Array[Vector3] = []
var _popup_life: PackedFloat32Array = PackedFloat32Array()
var _messages: Label
var _message_log: PackedStringArray = PackedStringArray()
var _message_time: float = 0.0
var _debug: Label
var _damage_flash: ColorRect
var _last_hp: float = -1.0
var _end_panel: PanelContainer
var _end_label: Label

# Level-up cards
var _cards_panel: Control
var _cards: Array[CardView] = []
var _card_row: HBoxContainer
var _cards_title: Label
var _cards_offer: int = -1  ## IslandRun.card_offer shown now (-1 = none)
var _cards_opened_ms: int = -100000
var _take_key: Label
var _reroll_button: Button
var _reroll_reason: Label
var _build_strip: HBoxContainer

# Pause
var _pause_panel: Control
var _pause_content: VBoxContainer
var _pause_where: Label
var _pause_stats: Label
var _pause_weapons: HFlowContainer
var _pause_cards: GridContainer
var _pause_banked: Label
var _pause_island: Label
var _pause_bonus: Label
var _pause_hints: Label
var _resume_button: Button
var _abandon_button: Button
var _gamepad: bool = false


## Small vector glyphs keep the HUD sharp without downloaded assets. Each is
## drawn twice: a soft dark copy first, so it reads on sand or snow.
class FieldIcon extends Control:

	var kind: StringName = &"badge":
		set(value):
			if kind != value:
				kind = value
				queue_redraw()

	func _init(icon_kind: StringName = &"badge", extent: Vector2 = Vector2(34, 34)) -> void:
		kind = icon_kind
		custom_minimum_size = extent
		size = extent
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var k: Vector2 = size / Vector2(48, 48)
		draw_set_transform(Vector2(1, 1.5), 0.0, k)
		_shape(Color(0, 0, 0, 0.55), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, k)
		_shape(UiTheme.ACCENT, 0.0)

	func _shape(ink: Color, extra: float) -> void:
		match kind:
			&"badge", &"war_cry":
				draw_polyline(PackedVector2Array([Vector2(24, 5), Vector2(39, 12), Vector2(37, 32), Vector2(24, 43), Vector2(11, 32), Vector2(9, 12), Vector2(24, 5)]), ink, 2.5 + extra, true)
				for y in [18, 26]:
					draw_polyline(PackedVector2Array([Vector2(16, y), Vector2(24, y + 6), Vector2(32, y)]), ink, 3.0 + extra, true)
			&"breaker":
				draw_circle(Vector2(28, 10), 4 + extra * 0.5, ink)
				draw_polyline(PackedVector2Array([Vector2(15, 21), Vector2(24, 17), Vector2(34, 24), Vector2(42, 24)]), ink, 4.0 + extra, true)
				draw_polyline(PackedVector2Array([Vector2(24, 18), Vector2(22, 29), Vector2(13, 40)]), ink, 4.0 + extra, true)
				draw_polyline(PackedVector2Array([Vector2(22, 28), Vector2(31, 31), Vector2(32, 41)]), ink, 4.0 + extra, true)
				for y in [12, 27, 35]:
					draw_line(Vector2(3, y), Vector2(12, y), ink, 2.0 + extra, true)
			_:
				draw_circle(Vector2(24, 28), 12.0 + extra * 0.5, ink)
				draw_rect(Rect2(18, 10, 12, 7), ink)
				draw_polyline(PackedVector2Array([Vector2(21, 9), Vector2(28, 5), Vector2(36, 13), Vector2(36, 29)]), ink, 2.0 + extra, true)
				if extra == 0.0:
					draw_line(Vector2(21, 22), Vector2(21, 32), UiTheme.BG, 2.0)


## Ability cooldown: amber ring and icon when ready; while recharging a
## muted ring fills clockwise in amber and the seconds left sit inside.
class AbilityRing extends Control:
	var fraction: float = 1.0  ## 0 = just used, 1 = ready
	var seconds: float = 0.0
	var icon: FieldIcon

	func _init(kind: StringName) -> void:
		custom_minimum_size = Vector2(48, 48)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon = FieldIcon.new(kind, Vector2(28, 28))
		icon.position = Vector2(10, 10)
		add_child(icon)

	func set_state(p_fraction: float, p_seconds: float) -> void:
		if is_equal_approx(p_fraction, fraction) and is_equal_approx(p_seconds, seconds):
			return
		fraction = clampf(p_fraction, 0.0, 1.0)
		seconds = maxf(0.0, p_seconds)
		icon.visible = seconds <= 0.0
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 3.0
		draw_arc(c, r, 0.0, TAU, 48, Color(0, 0, 0, 0.55), 6.0, true)
		if seconds <= 0.0:
			draw_arc(c, r, 0.0, TAU, 48, UiTheme.ACCENT, 3.0, true)
			return
		draw_arc(c, r, 0.0, TAU, 48, Color(UiTheme.TEXT_MUTED, 0.55), 3.0, true)
		draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * fraction, 48, UiTheme.ACCENT, 3.0, true)
		var font: Font = UiTheme.mono_bold_font()
		var text: String = "%ds" % ceili(seconds)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		var at := Vector2(c.x - w * 0.5, c.y + 6.0)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.85))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.TEXT)


## Progress pips: rings (objective) or short bars (card rank).
class Pips extends Control:
	var count: int = 0
	var filled: int = 0
	var color: Color = UiTheme.INFO
	var bars: bool = false

	func _init(as_bars: bool = false) -> void:
		bars = as_bars
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func set_state(p_count: int, p_filled: int, p_color: Color) -> void:
		if p_count == count and p_filled == filled and p_color == color:
			return
		count = p_count
		filled = p_filled
		color = p_color
		var step: float = 22.0 if bars else 24.0
		custom_minimum_size = Vector2(maxf(0.0, count * step - 4.0), 8.0 if bars else 20.0)
		queue_redraw()

	func _draw() -> void:
		for k in count:
			if bars:
				var r := Rect2(k * 22.0, (size.y - 6.0) * 0.5, 18.0, 6.0)
				draw_rect(r, color if k < filled else UiTheme.LINE)
			else:
				# Done = solid disc, to do = ring: told apart by shape.
				var c := Vector2(k * 24.0 + 10.0, size.y * 0.5)
				if k < filled:
					draw_circle(c, 10.0, Color(0, 0, 0, 0.6))
					draw_circle(c, 8.5, color)
				else:
					draw_arc(c, 8.0, 0.0, TAU, 24, Color(0, 0, 0, 0.6), 4.5, true)
					draw_arc(c, 8.0, 0.0, TAU, 24, color, 2.5, true)


## Weapon slots 1-5: amber = in hand, outline = owned (key and ammo), red
## outline = owned but empty, dashed = not owned in this run.
class WeaponSlots extends Control:
	var slots: Array = []  ## [state, text]

	func _init() -> void:
		custom_minimum_size = Vector2(0, 24)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_slots(p_slots: Array) -> void:
		if p_slots != slots:
			slots = p_slots
			queue_redraw()

	func _draw() -> void:
		var n: int = 5
		var gap: float = 4.0
		var w: float = (size.x - gap * (n - 1)) / n
		var font: Font = UiTheme.mono_bold_font()
		for k in slots.size():
			var r := Rect2(k * (w + gap), 0.0, w, size.y)
			var text: String = slots[k][1]
			var ink: Color = UiTheme.TEXT
			match slots[k][0]:
				&"active":
					draw_rect(r, UiTheme.ACCENT)
					ink = UiTheme.ON_ACCENT
				&"owned":
					draw_rect(r.grow(1.0), Color(0, 0, 0, 0.45), false, 3.0)
					draw_rect(r, Color(UiTheme.TEXT, 0.75), false, 1.0)
				&"dry":
					draw_rect(r.grow(1.0), Color(0, 0, 0, 0.45), false, 3.0)
					draw_rect(r, UiTheme.DANGER, false, 1.5)
					ink = UiTheme.DANGER
				_:
					MarkedBox.draw_dashed_rect(get_canvas_item(), r, Color(UiTheme.TEXT_MUTED, 0.7), 1.0, 4.0, 3.0)
					ink = Color(UiTheme.TEXT_MUTED, 0.85)
			var fs: int = 12
			var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var at := Vector2(r.position.x + maxf(2.0, (w - tw) * 0.5), r.position.y + r.size.y * 0.5 + fs * 0.36)
			if slots[k][0] != &"active":
				draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, w - 4.0, fs, 3, Color(0, 0, 0, 0.8))
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, w - 4.0, fs, ink)


## Arrows at the screen edge for specials and the boss out of view: danger
## triangle pointing at them plus a short name on a dark pill.
class ThreatArrows extends Control:
	var items: Array = []  ## [edge point, direction, name]

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_items(p_items: Array) -> void:
		if p_items.is_empty() and items.is_empty():
			return
		items = p_items
		queue_redraw()

	func _draw() -> void:
		var font: Font = UiTheme.mono_bold_font()
		for it: Array in items:
			var p: Vector2 = it[0]
			var d: Vector2 = it[1]
			var side := Vector2(-d.y, d.x)
			var tri := PackedVector2Array([p + d * 13.0, p - d * 6.0 + side * 10.0, p - d * 6.0 - side * 10.0])
			draw_colored_polygon(PackedVector2Array([tri[0] + d * 2.0, tri[1] - d + side * 2.0, tri[2] - d - side * 2.0]), Color(0, 0, 0, 0.6))
			draw_colored_polygon(tri, UiTheme.DANGER)
			var text: String = it[2]
			var tw: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			# The name sits inward of the arrow, clear of the triangle.
			var c: Vector2 = p - d * (16.0 + (tw * 0.5 + 6.0) * absf(d.x) + 12.0 * absf(d.y))
			var pill := Rect2(c.x - tw * 0.5 - 5.0, c.y - 9.0, tw + 10.0, 18.0)
			draw_rect(pill, MARKER_BG)
			draw_string(font, Vector2(pill.position.x + 5.0, c.y + 4.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UiTheme.DANGER)


## Card category picture: shockwave (breaker), sight (firearms), cross
## (survival), in the category colour.
class CategoryIcon extends Control:
	var category: StringName = &"survival"
	var color: Color = UiTheme.SUCCESS

	func _init() -> void:
		custom_minimum_size = Vector2(56, 56)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	func show_category(p_category: StringName, p_color: Color) -> void:
		category = p_category
		color = p_color
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var w: float = 3.5
		match category:
			&"breaker":
				draw_circle(c, 5.0, color)
				for r in [13.0, 22.0]:
					draw_arc(c, r, PI * 1.15, PI * 1.85, 16, color, w, true)
					draw_arc(c, r, PI * 0.15, PI * 0.85, 16, color, w, true)
			&"firearms":
				draw_arc(c, 15.0, 0.0, TAU, 32, color, w, true)
				draw_circle(c, 3.0, color)
				for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
					draw_line(c + d * 9.0, c + d * 24.0, color, w, true)
			_:
				var a: float = 7.0
				var b: float = 21.0
				draw_polyline(PackedVector2Array([c + Vector2(-a, -b), c + Vector2(a, -b), c + Vector2(a, -a), c + Vector2(b, -a), c + Vector2(b, a), c + Vector2(a, a), c + Vector2(a, b), c + Vector2(-a, b), c + Vector2(-a, a), c + Vector2(-b, a), c + Vector2(-b, -a), c + Vector2(-a, -a), c + Vector2(-a, -b)]), color, w, true)


## One level-up card: the button (focus and press) and its labels.
class CardView:
	var slot: Control
	var button: Button
	var category: Label
	var tag: Label
	var icon: CategoryIcon
	var title: Label
	var text: Label
	var pips: Pips
	var rank: Label
	var synergy: Label
	var style_idle: StyleBoxFlat
	var style_focus: StyleBoxFlat


func _init() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Menus and field equipment share the same typography and palette.
	root.theme = UiTheme.get_theme()
	add_child(root)

	# Red screen flash when the player takes damage (drawn behind all).
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.8, 0, 0, 0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)

	# Field elements live in their own full-screen layer so "HUD size"
	# (Settings > Display) can scale them; world markers stay unscaled.
	_field = Control.new()
	_field.name = "FieldPanels"
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_field)
	_build_field_hud(_field)
	add_to_group(&"hud")

	_build_marker(root)
	_threats = ThreatArrows.new()
	_threats.name = "ThreatArrows"
	_threats.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_threats)

	# Damage direction: a red arc around the screen centre.
	_hit_arc = Control.new()
	_hit_arc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_arc.draw.connect(_draw_hit_arc)
	root.add_child(_hit_arc)

	_messages = _label("", 17)
	_messages.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_messages.position = Vector2(-240, 132)
	_messages.size = Vector2(480, 80)
	_messages.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_messages)

	_debug = _label("", 16, UiTheme.TEXT, true)
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.position = Vector2(-280, 270)
	_debug.custom_minimum_size = Vector2(240, 0)
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_debug)

	_build_cards(root)

	_end_panel = PanelContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.position = Vector2(-200, -100)
	_end_panel.custom_minimum_size = Vector2(400, 200)
	_end_panel.visible = false
	root.add_child(_end_panel)
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_panel.add_child(_end_label)

	_build_pause(root)
	_update_prompts()


# --- Builders -------------------------------------------------------------

## Adds `c` to `parent`, anchored to a screen edge/corner. Blocks on the
## bottom or right grow up/left when their content grows.
func _place(parent: Control, c: Control, preset: Control.LayoutPreset, offset: Vector2, extent: Vector2) -> void:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	c.set_anchors_preset(preset)
	c.position = offset
	c.size = extent
	if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT]:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	if preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM]:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH


func _column(parent: Control, gap: int = 5) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", gap)
	parent.add_child(col)
	return col


func _row(parent: Control, gap: int = 8) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", gap)
	parent.add_child(row)
	return row


## HUD text: theme fonts, no wrapping, dark outline + shadow.
func _label(text: String, font_size: int = 18, color: Color = UiTheme.TEXT, mono: bool = false) -> Label:
	var label := UiTheme.label(text, font_size, color, mono)
	# Fixed HUD labels must have stable minimum heights while containers settle.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return MenuDialog.ink(label, 5 if font_size >= 20 else 4)


func _heading(parent: Control, text: String, font_size: int = 20, extra_bold: bool = false) -> Label:
	var label := _label(text, font_size)
	label.add_theme_font_override("font", UiTheme.title_font() if extra_bold else UiTheme.heading_font())
	parent.add_child(label)
	return label


func _mono_bold(text: String, font_size: int, color: Color = UiTheme.TEXT) -> Label:
	var label := _label(text, font_size, color, true)
	label.add_theme_font_override("font", UiTheme.mono_bold_font())
	return label


## One-line text for menus (cards, pause): no wrapping, so short labels in
## rows keep their width.
static func _plain(text: String, font_size: int, color: Color = UiTheme.TEXT, mono: bool = false) -> Label:
	var label := UiTheme.label(text, font_size, color, mono)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


## Outlined keycap with the real binding ("SPACE", "A / RB").
func _keycap(text: String) -> Label:
	var label := _mono_bold(text, 13)
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.35)
	s.border_color = UiTheme.TEXT
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 0
	s.content_margin_bottom = 0
	label.add_theme_stylebox_override("normal", s)
	label.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return label


## Thin bar with a see-through dark track: a gauge, not a panel.
func _meter(parent: Control, color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0, 0, 0, 0.5)
	track.border_color = Color(0, 0, 0, 0.6)
	track.set_border_width_all(1)
	track.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _build_field_hud(field: Control) -> void:
	# Objective, top centre: what to do now, with progress pips.
	_objective_box = VBoxContainer.new()
	_objective_box.add_theme_constant_override("separation", 4)
	_place(field, _objective_box, Control.PRESET_CENTER_TOP, Vector2(-250, 10), Vector2(500, 60))
	var head := _row(_objective_box, 16)
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 0)
	head.add_child(words)
	_objective = _heading(words, "FIELD OBJECTIVE", 28, true)
	_objective_detail = _label("", 14, UiTheme.TEXT_MUTED, true)
	words.add_child(_objective_detail)
	_objective_pips = Pips.new()
	head.add_child(_objective_pips)
	_survivor_row = _row(_objective_box, 8)
	_survivor_row.custom_minimum_size.x = 320
	_survivor_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_survivor_text = _mono_bold("SURVIVOR 100", 14, UiTheme.SUCCESS)
	_survivor_row.add_child(_survivor_text)
	_survivor_bar = _meter(_survivor_row, UiTheme.SUCCESS, 8)
	_survivor_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_survivor_row.visible = false
	_boss_row = _column(_objective_box, 3)
	_boss_row.custom_minimum_size.x = 380
	_boss_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_boss_name = _mono_bold("BEHEMOTH", 15, UiTheme.DANGER)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_row.add_child(_boss_name)
	_boss_bar = _meter(_boss_row, UiTheme.DANGER, 10)
	_boss_bar.max_value = 1.0
	_boss_row.visible = false

	# Minimap, top right: the map as drawn, no panel; its key underneath.
	_map_box = VBoxContainer.new()
	_map_box.add_theme_constant_override("separation", 6)
	_place(field, _map_box, Control.PRESET_TOP_RIGHT, Vector2(-14 - Minimap.SIZE_PX, 12), Vector2(Minimap.SIZE_PX, 220))
	_minimap = Minimap.new()
	_map_box.add_child(_minimap)
	_legend = Minimap.Legend.new()
	_map_box.add_child(_legend)

	# Status, bottom left: who you are and how alive.
	_status_panel = VBoxContainer.new()
	_status_panel.name = "Status"
	_status_panel.add_theme_constant_override("separation", 4)
	_place(field, _status_panel, Control.PRESET_BOTTOM_LEFT, Vector2(16, -96), Vector2(290, 80))
	var identity := _row(_status_panel, 6)
	_info = _heading(identity, "RECRUIT · LVL 1", 22)
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.size_flags_vertical = Control.SIZE_SHRINK_END
	_hp_text = _mono_bold("100", 22)
	identity.add_child(_hp_text)
	_hp_max = _label("/ 100", 15, UiTheme.TEXT_MUTED, true)
	_hp_max.size_flags_vertical = Control.SIZE_SHRINK_END
	identity.add_child(_hp_max)
	_hp_bar = _meter(_status_panel, UiTheme.DANGER, 14)
	_xp_bar = _meter(_status_panel, UiTheme.INFO, 5)
	var progression := _row(_status_panel, 8)
	_xp_text = _label("", 14, UiTheme.TEXT_MUTED, true)
	_xp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression.add_child(_xp_text)
	_stats = _label("", 14, UiTheme.TEXT_MUTED, true)
	progression.add_child(_stats)

	# Radio subtitles, just above the status block.
	_radio_panel = VBoxContainer.new()
	_radio_panel.name = "Radio"
	_radio_panel.add_theme_constant_override("separation", 2)
	_place(field, _radio_panel, Control.PRESET_BOTTOM_LEFT, Vector2(16, -190), Vector2(320, 80))
	_radio_panel.add_child(_label("RADIO / DIRECTOR HALE", 13, UiTheme.ACCENT, true))
	_radio_text = _label("", 17)
	_radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_text.custom_minimum_size.x = 320
	_radio_panel.add_child(_radio_text)
	_radio_panel.visible = false

	# Abilities, bottom centre: cooldown rings, real keys, ready state.
	_abilities_panel = VBoxContainer.new()
	_abilities_panel.name = "Abilities"
	_abilities_panel.add_theme_constant_override("separation", 6)
	_place(field, _abilities_panel, Control.PRESET_CENTER_BOTTOM, Vector2(-160, -102), Vector2(320, 86))
	var tiles := _row(_abilities_panel, 18)
	tiles.alignment = BoxContainer.ALIGNMENT_CENTER
	var breaker := _ability_tile(tiles, &"breaker", "BREAKER")
	_breaker_ring = breaker[0]
	_breaker_key = breaker[2]
	_breaker_status = breaker[3]
	var ability := _ability_tile(tiles, &"grenade", "GRENADE")
	_ability_ring = ability[0]
	_ability_icon = _ability_ring.icon
	_ability_name = ability[1]
	_ability_key = ability[2]
	_ability_status = ability[3]
	# Sprint stamina: only shown while it is not full.
	_sprint_row = _row(_abilities_panel, 8)
	_sprint_key = _label("SHIFT SPRINT", 12, UiTheme.TEXT_MUTED, true)
	_sprint_row.add_child(_sprint_key)
	_stamina_bar = _meter(_sprint_row, UiTheme.TEXT, 5)
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Weapon, bottom right: name, ammo and the five slots.
	_weapon_panel = VBoxContainer.new()
	_weapon_panel.name = "Weapon"
	_weapon_panel.add_theme_constant_override("separation", 5)
	_place(field, _weapon_panel, Control.PRESET_BOTTOM_RIGHT, Vector2(-266, -98), Vector2(250, 82))
	var weapon_top := _row(_weapon_panel, 8)
	_weapon_name = _heading(weapon_top, "ASSAULT RIFLE", 22)
	_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ammo_text = _mono_bold("∞", 22)
	weapon_top.add_child(_ammo_text)
	_weapon_slots = WeaponSlots.new()
	_weapon_panel.add_child(_weapon_slots)
	var weapon_foot := _row(_weapon_panel, 8)
	_fire_status = _label("AUTO-FIRE", 13, UiTheme.ACCENT, true)
	_fire_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weapon_foot.add_child(_fire_status)
	_switch_hint = _label("", 13, UiTheme.TEXT_MUTED, true)
	weapon_foot.add_child(_switch_hint)

	_alerts = _label("", 18, UiTheme.DANGER)
	_alerts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alerts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place(field, _alerts, Control.PRESET_CENTER_BOTTOM, Vector2(-170, -200), Vector2(340, 80))


## Ring + [name, key, state] column. Returns [ring, name, key, state].
func _ability_tile(parent: Control, kind: StringName, title: String) -> Array:
	var tile := _row(parent, 8)
	var ring := AbilityRing.new(kind)
	ring.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.add_child(ring)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.add_theme_constant_override("separation", 2)
	words.custom_minimum_size.x = 92
	tile.add_child(words)
	var name_label := _heading(words, title, 19)
	var key := _keycap("—")
	words.add_child(key)
	var state := _label("READY", 13, UiTheme.ACCENT, true)
	words.add_child(state)
	return [ring, name_label, key, state]


func _build_marker(root: Control) -> void:
	_marker_pill = PanelContainer.new()
	_marker_pill.name = "MarkerPill"
	_marker_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s := StyleBoxFlat.new()
	s.bg_color = MARKER_BG
	s.border_color = UiTheme.INFO
	s.set_border_width_all(2)
	s.set_corner_radius_all(18)
	s.content_margin_left = 9
	s.content_margin_right = 13
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	_marker_pill.add_theme_stylebox_override("panel", s)
	root.add_child(_marker_pill)
	var row := _row(_marker_pill, 7)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(14, 14)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.draw.connect(func() -> void: dot.draw_arc(dot.size * 0.5, 5.5, 0.0, TAU, 20, UiTheme.INFO, 3.0, true))
	row.add_child(dot)
	_marker = UiTheme.label("", 16, UiTheme.TEXT, true)
	_marker.autowrap_mode = TextServer.AUTOWRAP_OFF
	_marker.add_theme_font_override("font", UiTheme.mono_bold_font())
	row.add_child(_marker)
	_marker_pill.visible = false


## Full-screen blur of the game behind a screen (brightness: 1 = as is).
static func _blur(brightness: float) -> ColorRect:
	var rect := ColorRect.new()
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap; uniform float brightness = 0.5; void fragment() { COLOR = vec4(textureLod(screen_texture, SCREEN_UV, 2.2).rgb * brightness, 1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("brightness", brightness)
	rect.material = material
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	return rect


# --- Level-up cards -----------------------------------------------------------

func _build_cards(root: Control) -> void:
	_cards_panel = Control.new()
	_cards_panel.name = "Cards"
	_cards_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cards_panel.visible = false
	root.add_child(_cards_panel)
	_cards_panel.add_child(_blur(0.4))
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -64  # room for the build strip
	_cards_panel.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)
	_cards_title = _label("LEVEL UP / 2", 14, UiTheme.ACCENT, true)
	_cards_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_cards_title)
	var choose := MenuDialog.ink(UiTheme.title("CHOOSE ONE", 42))
	col.add_child(choose)
	_card_row = HBoxContainer.new()
	_card_row.add_theme_constant_override("separation", 26)
	_card_row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(_card_row)
	for i in 3:
		_cards.append(_card_view(i))
	var hints := _row(col, 22)
	hints.alignment = BoxContainer.ALIGNMENT_CENTER
	var browse := _row(hints, 6)
	browse.add_child(_keycap("← →"))
	browse.add_child(_label("BROWSE", 14, UiTheme.TEXT, true))
	var take := _row(hints, 6)
	_take_key = _keycap("ENTER")
	take.add_child(_take_key)
	take.add_child(_label("TAKE", 14, UiTheme.TEXT, true))
	_reroll_button = Button.new()
	_reroll_button.name = "Reroll"
	_reroll_button.focus_mode = Control.FOCUS_NONE  # Y / R or a click: keeps the card row clean
	_reroll_button.custom_minimum_size = Vector2(170, 34)
	_reroll_button.add_theme_font_size_override("font_size", 17)
	_reroll_button.pressed.connect(_request_reroll)
	hints.add_child(_reroll_button)
	_reroll_reason = _label("", 14, UiTheme.TEXT_MUTED, true)
	hints.add_child(_reroll_reason)
	# The current build: small chips at the bottom left.
	var strip_box := MenuDialog.glass_box(_cards_panel, 0.8)
	strip_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	strip_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	strip_box.position = Vector2(20, -16)
	(strip_box.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_top = 6
	(strip_box.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_bottom = 6
	_build_strip = HBoxContainer.new()
	_build_strip.name = "BuildStrip"
	_build_strip.add_theme_constant_override("separation", 8)
	strip_box.add_child(_build_strip)


func _card_style(border: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UiTheme.PANEL, 0.97)
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(6)
	return s


func _card_view(i: int) -> CardView:
	var v := CardView.new()
	v.slot = Control.new()
	v.slot.custom_minimum_size = Vector2(270, 364)
	v.slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_row.add_child(v.slot)
	v.button = Button.new()
	v.button.name = "Card%d" % i
	v.button.position = Vector2(0, 14)
	v.button.size = Vector2(270, 350)
	v.style_idle = _card_style(UiTheme.LINE, 1)
	v.style_focus = _card_style(UiTheme.ACCENT, 2)
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		v.button.add_theme_stylebox_override(state, v.style_idle)
	v.button.pressed.connect(_take_card.bind(i))
	v.button.focus_entered.connect(_on_card_focus.bind(i, true))
	v.button.focus_exited.connect(_on_card_focus.bind(i, false))
	# Hover and focus are one state: the mouse moves the focus.
	v.button.mouse_entered.connect(func() -> void:
		if _cards_panel.visible:
			v.button.grab_focus())
	v.slot.add_child(v.button)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 16)
	v.button.add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)
	var top := _row(col, 8)
	v.category = _plain("", 13, UiTheme.ACCENT, true)
	v.category.add_theme_font_override("font", UiTheme.mono_bold_font())
	v.category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(v.category)
	v.tag = UiTheme.chip("NEW", UiTheme.SUCCESS, 12)
	top.add_child(v.tag)
	var art := PanelContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size.y = 86
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = UiTheme.PANEL_RAISED
	art_style.set_corner_radius_all(4)
	art.add_theme_stylebox_override("panel", art_style)
	col.add_child(art)
	v.icon = CategoryIcon.new()
	art.add_child(v.icon)
	v.title = UiTheme.label("", 28)
	v.title.add_theme_font_override("font", UiTheme.title_font())
	col.add_child(v.title)
	v.text = UiTheme.label("", 17)
	col.add_child(v.text)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	col.add_child(HSeparator.new())
	var rank_row := _row(col, 6)
	rank_row.add_child(_plain("RANK", 12, UiTheme.TEXT_MUTED, true))
	v.pips = Pips.new(true)
	rank_row.add_child(v.pips)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rank_row.add_child(gap)
	v.rank = _plain("", 13, UiTheme.TEXT_MUTED, true)
	rank_row.add_child(v.rank)
	v.synergy = UiTheme.label("", 14, UiTheme.TEXT_MUTED)
	col.add_child(v.synergy)
	return v


static func category_color(category: StringName) -> Color:
	match category:
		&"breaker":
			return UiTheme.ACCENT
		&"firearms":
			return UiTheme.INFO
	return UiTheme.SUCCESS


static func roman(n: int) -> String:
	return ROMAN[n] if n >= 0 and n < ROMAN.size() else str(n)


func _fill_card(v: CardView, c: GameData.Card, run: IslandRun) -> void:
	var owned: int = run.stacks(c.id)
	var category: StringName = GameData.card_category(c.id)
	var color: Color = category_color(category)
	v.category.text = "%s %s" % [CATEGORY_GLYPH[category], String(category).to_upper()]
	v.category.add_theme_color_override("font_color", color)
	var tag_color: Color = UiTheme.ACCENT if owned > 0 else UiTheme.SUCCESS
	v.tag.text = "UPGRADE" if owned > 0 else "NEW"
	v.tag.add_theme_color_override("font_color", tag_color)
	(v.tag.get_theme_stylebox("normal") as StyleBoxFlat).border_color = tag_color
	v.icon.show_category(category, color)
	v.title.text = c.title
	v.text.text = c.description
	v.pips.set_state(c.max_stacks, owned + 1, color)
	v.rank.text = "%d / %d" % [owned + 1, c.max_stacks]
	v.synergy.text = _synergy(c, category, owned, run)


## One honest line about how the card fits the build (no synergy data yet:
## it names your rank or another card of the same category you own).
func _synergy(c: GameData.Card, category: StringName, owned: int, run: IslandRun) -> String:
	if owned > 0:
		return "You own rank %s." % roman(owned)
	for other in run.all_cards:
		if other.id != c.id and run.stacks(other.id) > 0 and GameData.card_category(other.id) == category:
			return "Pairs with your %s." % other.title
	return "Your first %s card." % String(category)


func _on_card_focus(i: int, on: bool) -> void:
	var v: CardView = _cards[i]
	v.button.position.y = 0.0 if on else 14.0  # the focused card is raised
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		v.button.add_theme_stylebox_override(state, v.style_focus if on else v.style_idle)


## Cards behind the pause (or its abandon confirmation) take no focus,
## clicks or presses.
func _set_cards_interactive(on: bool) -> void:
	for v in _cards:
		v.button.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
		v.button.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE
	_reroll_button.mouse_filter = Control.MOUSE_FILTER_STOP if on else Control.MOUSE_FILTER_IGNORE


func _cards_locked() -> bool:
	return Time.get_ticks_msec() - _cards_opened_ms < CARD_LOCK_MS


func _take_card(i: int) -> void:
	if not _cards_panel.visible or _pause_panel.visible or _cards_locked():
		return
	card_chosen.emit(i)


func _request_reroll() -> void:
	if not _cards_panel.visible or _pause_panel.visible or _cards_locked() or _run == null or _run.rerolls <= 0:
		return
	reroll_requested.emit()


func _update_cards(run: IslandRun) -> void:
	var offer: bool = not run.card_choices.is_empty() and not run.is_over()
	if not offer:
		_cards_panel.visible = false
		_cards_offer = -1
		return
	var opening: bool = not _cards_panel.visible
	_cards_panel.visible = true
	# Every new offer (next pending level-up, reroll) refreshes and locks,
	# even when it shows the same cards.
	if opening or run.card_offer != _cards_offer:
		_cards_offer = run.card_offer
		_cards_opened_ms = Time.get_ticks_msec()  # opening or a reroll: lock again
		var focus_at: int = 1 if run.card_choices.size() >= 3 else 0
		for i in _cards.size():
			var has: bool = i < run.card_choices.size()
			_cards[i].slot.visible = has
			if has:
				_fill_card(_cards[i], run.card_choices[i], run)
			if _cards[i].button.has_focus():
				focus_at = mini(i, run.card_choices.size() - 1)
		_cards_title.text = "LEVEL UP / %d" % run.level
		_fill_build_strip(run)
		if not _pause_panel.visible:
			_cards[focus_at].button.grab_focus()
	# Rerolls: count, or why there are none.
	var left: int = run.rerolls
	var key: String = GameInput.prompt(&"card_reroll", _gamepad)
	_reroll_button.text = "[ %s ]  REROLL ×%d" % [key, left]
	UiTheme.set_locked(_reroll_button, left <= 0, "No rerolls left: clear an island to earn one.")
	_reroll_reason.text = "NONE LEFT · CLEAR AN ISLAND FOR +1" if left <= 0 else ""
	_reroll_reason.visible = left <= 0
	# The lock shows as a quick fade-in of the cards.
	var t: float = clampf(float(Time.get_ticks_msec() - _cards_opened_ms) / CARD_LOCK_MS, 0.0, 1.0)
	_card_row.modulate.a = lerpf(0.55, 1.0, t)


func _fill_build_strip(run: IslandRun) -> void:
	for child in _build_strip.get_children():
		child.queue_free()
	_build_strip.add_child(_plain("BUILD", 13, UiTheme.TEXT_MUTED, true))
	var any: bool = false
	for c in run.all_cards:
		var n: int = run.stacks(c.id)
		if n <= 0:
			continue
		any = true
		var category: StringName = GameData.card_category(c.id)
		var chip := UiTheme.chip("%s %s %s" % [CATEGORY_GLYPH[category], c.title, roman(n)], UiTheme.TEXT, 13)
		(chip.get_theme_stylebox("normal") as StyleBoxFlat).border_color = category_color(category)
		_build_strip.add_child(chip)
	if not any:
		_build_strip.add_child(_plain("No cards yet: this is your first.", 13, UiTheme.TEXT, true))


# --- Pause ------------------------------------------------------------------

func _build_pause(root: Control) -> void:
	# Pause shows the blurred game; no dark panel, text with shadow, and
	# see-through buttons and boxes (MenuDialog glass helpers).
	_pause_panel = Control.new()
	_pause_panel.name = "Pause"
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	root.add_child(_pause_panel)
	var blur := _blur(0.55)
	_pause_panel.add_child(blur)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.add_child(center)
	_pause_content = VBoxContainer.new()
	_pause_content.name = "PauseContent"
	_pause_content.custom_minimum_size = Vector2(820, 0)
	_pause_content.add_theme_constant_override("separation", 14)
	center.add_child(_pause_content)

	var head := HBoxContainer.new()
	_pause_content.add_child(head)
	var title_col := VBoxContainer.new()
	title_col.add_theme_constant_override("separation", 0)
	title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title_col)
	title_col.add_child(MenuDialog.ink(UiTheme.label("SALVAGE & CO. / PROJECT TIDE", 13, UiTheme.TEXT_MUTED, true)))
	var paused_title := MenuDialog.ink(UiTheme.title("PAUSED", 46), 5)
	paused_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_col.add_child(paused_title)
	_pause_where = MenuDialog.ink(UiTheme.label("", 14, UiTheme.TEXT_MUTED, true))
	_pause_where.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pause_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pause_where.size_flags_vertical = Control.SIZE_SHRINK_END
	head.add_child(_pause_where)
	_pause_content.add_child(HSeparator.new())

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	body.custom_minimum_size.y = 320
	_pause_content.add_child(body)
	var menu := VBoxContainer.new()
	menu.custom_minimum_size.x = 270
	menu.add_theme_constant_override("separation", 12)
	body.add_child(menu)
	_resume_button = UiTheme.button(menu, "RESUME", func() -> void: resume_requested.emit(), true)
	_resume_button.name = "Resume"
	_resume_button.custom_minimum_size.y = 54
	var settings := UiTheme.button(menu, "SETTINGS", _settings)
	settings.name = "Settings"
	MenuDialog.glass_button(settings)
	var controls := UiTheme.button(menu, "CONTROLS", _controls)
	controls.name = "Controls"
	MenuDialog.glass_button(controls)
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu.add_child(push)
	_abandon_button = UiTheme.button(menu, "ABANDON RUN…", _open_abandon)
	_abandon_button.name = "Abandon"
	_abandon_button.theme_type_variation = &"DangerButton"
	MenuDialog.glass_button(_abandon_button, true)
	menu.add_child(MenuDialog.ink(UiTheme.label("Asks you to confirm.", 14, UiTheme.TEXT_MUTED)))
	# A closed focus loop: Tab, Shift+Tab and the d-pad never leave the menu
	# (a card offer may be open underneath).
	var loop: Array[Button] = [_resume_button, settings, controls, _abandon_button]
	for i in loop.size():
		var prev: NodePath = loop[i].get_path_to(loop[posmod(i - 1, loop.size())])
		var next: NodePath = loop[i].get_path_to(loop[(i + 1) % loop.size()])
		loop[i].focus_previous = prev
		loop[i].focus_neighbor_top = prev
		loop[i].focus_next = next
		loop[i].focus_neighbor_bottom = next
		loop[i].focus_neighbor_left = loop[i].get_path_to(loop[i])
		loop[i].focus_neighbor_right = loop[i].get_path_to(loop[i])

	var build_box := MenuDialog.glass_box(body)
	build_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var build := VBoxContainer.new()
	build.add_theme_constant_override("separation", 10)
	build_box.add_child(build)
	var build_head := HBoxContainer.new()
	build.add_child(build_head)
	var build_title := MenuDialog.ink(UiTheme.label("YOUR BUILD", 24))
	build_title.add_theme_font_override("font", UiTheme.heading_font())
	build_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build_head.add_child(build_title)
	_pause_stats = MenuDialog.ink(UiTheme.label("", 14, UiTheme.TEXT_MUTED, true))
	_pause_stats.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pause_stats.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	build_head.add_child(_pause_stats)
	build.add_child(MenuDialog.ink(UiTheme.label("WEAPONS", 12, UiTheme.TEXT_MUTED, true)))
	_pause_weapons = HFlowContainer.new()
	_pause_weapons.add_theme_constant_override("h_separation", 8)
	_pause_weapons.add_theme_constant_override("v_separation", 8)
	build.add_child(_pause_weapons)
	build.add_child(MenuDialog.ink(UiTheme.label("CARDS", 12, UiTheme.TEXT_MUTED, true)))
	_pause_cards = GridContainer.new()
	_pause_cards.columns = 2
	_pause_cards.add_theme_constant_override("h_separation", 8)
	_pause_cards.add_theme_constant_override("v_separation", 8)
	build.add_child(_pause_cards)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build.add_child(fill)
	build.add_child(HSeparator.new())
	var intel := HBoxContainer.new()
	intel.add_theme_constant_override("separation", 22)
	build.add_child(intel)
	_pause_banked = _intel_stat(intel, "INTEL BANKED", UiTheme.SUCCESS)
	_pause_island = _intel_stat(intel, "THIS ISLAND (KEPT)", UiTheme.TEXT)
	_pause_bonus = _intel_stat(intel, "EXTRACTION BONUS AT RISK", UiTheme.ACCENT)

	_pause_hints = MenuDialog.ink(UiTheme.label("", 13, UiTheme.TEXT_MUTED, true))
	_pause_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pause_content.add_child(_pause_hints)


func _intel_stat(parent: Control, caption: String, color: Color) -> Label:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	parent.add_child(col)
	col.add_child(MenuDialog.ink(_plain(caption, 12, UiTheme.TEXT_MUTED, true)))
	var number := MenuDialog.ink(_plain("0", 22, color, true))
	number.add_theme_font_override("font", UiTheme.mono_bold_font())
	col.add_child(number)
	return number


## Intel numbers for the pause and the abandon confirmation: banked (from
## finished islands), this island so far (kept even on death: Intel is kept
## when you fall, DECISIONS 2026-10-05) and the extraction bonus you only
## get by finishing the run.
func _intel(run: IslandRun) -> Dictionary:
	var banked: int = context.intel if context != null else 0
	var island: int = run.intel_earned()
	var kept: int = banked + island
	return {"banked": banked, "island": island, "kept": kept,
		"bonus": int(kept * GameData.EXTRACTION_INTEL_MULTIPLIER) - kept}


func _fill_pause(run: IslandRun) -> void:
	var where: String = "FIELD TEST"
	if context != null:
		if context.is_expedition():
			where = "%s · PART %d OF %d" % [context.part_name().to_upper(), context.island_index + 1, context.island_count()]
		else:
			where = "ISLAND %d OF %d" % [context.island_index + 1, context.island_count()]
	var mission: String = String(GameData.MISSIONS.get(run.mission, {"name": run.mission})["name"]).to_upper()
	var on_island: int = int(run.time_alive - run.landed_time)
	_pause_where.text = "%s · %s (%s)\n%02d:%02d ON THE ISLAND" % [where, mission, _mission_progress(run), on_island / 60, on_island % 60]
	_pause_stats.text = "%s · LVL %d · HP %d/%d" % [String(GameData.CLASS_INFO[run.player_class]["name"]).to_upper(), run.level, ceili(run.hp), ceili(run.max_hp)]
	for child in _pause_weapons.get_children():
		child.queue_free()
	for i in run.weapons.size():
		if not run.weapon_unlocked[i]:
			continue
		var w: GameData.Weapon = run.weapons[i]
		var ammo: String = "∞" if w.max_ammo < 0 else str(run.ammo[i])
		var chip := MenuDialog.glass_box(_pause_weapons, 0.6)
		var s := chip.get_theme_stylebox("panel") as StyleBoxFlat
		s.bg_color = Color(UiTheme.PANEL_RAISED, 0.6)
		s.border_color = UiTheme.ACCENT if i == run.weapon_index else Color(UiTheme.LINE, 0.9)
		s.content_margin_top = 4
		s.content_margin_bottom = 4
		s.content_margin_left = 10
		s.content_margin_right = 10
		chip.add_child(MenuDialog.ink(_plain("%d · %s %s" % [i + 1, w.display_name, ammo], 16)))
	for child in _pause_cards.get_children():
		child.queue_free()
	var owned: int = 0
	for c in run.all_cards:
		var n: int = run.stacks(c.id)
		if n <= 0:
			continue
		owned += 1
		var category: StringName = GameData.card_category(c.id)
		var box := MenuDialog.glass_box(_pause_cards, 0.0)
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var s := box.get_theme_stylebox("panel") as StyleBoxFlat
		s.content_margin_top = 5
		s.content_margin_bottom = 5
		s.content_margin_left = 10
		s.content_margin_right = 10
		var row := HBoxContainer.new()
		box.add_child(row)
		var glyph := MenuDialog.ink(_plain(CATEGORY_GLYPH[category], 15, category_color(category), true))
		row.add_child(glyph)
		var name_label := MenuDialog.ink(UiTheme.label(c.title, 16))
		name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		row.add_child(MenuDialog.ink(_plain("%s / %s" % [roman(n), roman(c.max_stacks)], 13, UiTheme.TEXT_MUTED, true)))
	if owned == 0:
		_pause_cards.add_child(MenuDialog.ink(UiTheme.label("No cards yet: level up to draw some.", 16, UiTheme.TEXT_MUTED)))
	var intel: Dictionary = _intel(run)
	_pause_banked.text = str(intel["banked"])
	_pause_island.text = "+%d" % intel["island"]
	_pause_bonus.text = "+%d" % intel["bonus"]
	_pause_hints.text = "[ %s ] SELECT     [ %s ] RESUME" % [GameInput.prompt(&"ui_accept", _gamepad), GameInput.prompt(&"ui_cancel", _gamepad)]


## Short progress of the island's mission ("1/3", "33/75 s").
func _mission_progress(run: IslandRun) -> String:
	match run.objective:
		IslandRun.Objective.GENERATORS:
			match run.mission:
				&"defend", &"holdout":
					return "%d/%d s" % [int(run.defend_time), int(run.hold_time())]
				&"rescue":
					return "searching"
				_:
					return "%d/%d" % [_generators_done(run), GameData.GENERATOR_COUNT]
		IslandRun.Objective.BOSS:
			return "boss"
		IslandRun.Objective.RETURN_TO_BOAT:
			return "extract"
	return "over"


func _generators_done(run: IslandRun) -> int:
	var done: int = 0
	for progress in run.generator_progress:
		if progress >= GameData.GENERATOR_HOLD_SECONDS:
			done += 1
	return done


func _open_abandon() -> void:
	if is_instance_valid(_pause_dialog) or _run == null:
		return
	var intel: Dictionary = _intel(_run)
	var keep_note: String = "banked %d + %d from this island" % [intel["banked"], intel["island"]]
	_pause_dialog = MenuDialog.abandon(_pause_panel, intel["kept"], keep_note, intel["bonus"],
		"the extraction bonus (×%.1f)" % GameData.EXTRACTION_INTEL_MULTIPLIER,
		func() -> void: abandon_requested.emit())
	# The dialog took note of the focused button first; now only it shows.
	_pause_content.visible = false
	_pause_dialog.closed.connect(func() -> void: _pause_content.visible = true)


func _settings() -> void:
	if not is_instance_valid(_pause_dialog) and profile != null:
		_pause_dialog = MenuDialog.settings(_pause_panel, profile)


func _controls() -> void:
	if not is_instance_valid(_pause_dialog):
		_pause_dialog = MenuDialog.controls(_pause_panel)


# --- Input --------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# The last active input device determines prompts; stick drift is ignored.
	var was: bool = _gamepad
	if event is InputEventJoypadButton and event.pressed:
		_gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		_gamepad = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_gamepad = false
	elif event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		_gamepad = false
	if was != _gamepad:
		_update_prompts()


## Key prompts from the real bindings (GameInput reads the InputMap, so
## rebinds and the active device show up).
func _update_prompts() -> void:
	_breaker_key.text = GameInput.prompt(&"breaker", _gamepad)
	_ability_key.text = GameInput.prompt(&"ability", _gamepad)
	_sprint_key.text = "%s SPRINT" % GameInput.prompt(&"sprint", _gamepad)
	_take_key.text = GameInput.prompt(&"ui_accept", _gamepad)
	_switch_hint.text = "%s NEXT" % GameInput.prompt(&"weapon_next", true) if _gamepad else ""


func _unhandled_input(event: InputEvent) -> void:
	if _pause_panel.visible and not is_instance_valid(_pause_dialog) and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()
	elif _cards_panel.visible and not _pause_panel.visible and event.is_action_pressed(&"card_reroll"):
		get_viewport().set_input_as_handled()
		_request_reroll()


# --- Per-frame update -----------------------------------------------------------

func refresh(run: IslandRun, camera: Camera3D, sim_ms: float, paused: bool = false, island_text: String = "") -> void:
	_run = run
	if paused and not _pause_panel.visible:
		_pause_panel.visible = true
		_pause_content.visible = true
		_set_cards_interactive(false)
		_fill_pause(run)
		_resume_button.grab_focus()
	elif not paused and _pause_panel.visible:
		_pause_panel.visible = false
		if is_instance_valid(_pause_dialog):
			_pause_dialog.close()
		_set_cards_interactive(true)
		_update_prompts()  # bindings may have changed in Settings
		if _cards_panel.visible:
			_cards[1 if run.card_choices.size() >= 3 else 0].button.grab_focus()
	_update_hit_arc(run, camera)
	_update_popups(run, camera)
	if _last_hp >= 0.0 and run.hp < _last_hp:
		_damage_flash.color.a = clampf(_damage_flash.color.a + (_last_hp - run.hp) * 0.02, 0.0, 0.35)
	_last_hp = run.hp
	_damage_flash.color.a = maxf(0.0, _damage_flash.color.a - get_process_delta_time() * 1.5)

	_info.text = "%s · LVL %d" % [String(GameData.CLASS_INFO[run.player_class]["name"]).to_upper(), run.level]
	_hp_bar.max_value = run.max_hp
	_hp_bar.value = run.hp
	_hp_text.text = str(ceili(run.hp))
	_hp_max.text = "/ %d" % ceili(run.max_hp)
	_hp_text.add_theme_color_override("font_color", UiTheme.DANGER if run.hp <= run.max_hp * 0.25 else UiTheme.TEXT)
	_xp_bar.max_value = run.xp_needed()
	_xp_bar.value = run.xp
	_xp_text.text = "XP %d/%d" % [run.xp, run.xp_needed()]
	_stats.text = "%d KILLS · %d HS" % [run.kills, run.headshots]

	var total: float = run.breaker_cooldown_total()
	_breaker_ring.set_state(1.0 - run.breaker_cd / total if total > 0.0 else 1.0, run.breaker_cd)
	_cooldown_label(_breaker_status, run.breaker_cd)
	var ability_total: float = run.ability_cooldown_total()
	_ability_ring.set_state(1.0 - run.grenade_cd / ability_total if ability_total > 0.0 else 1.0, run.grenade_cd)
	_cooldown_label(_ability_status, run.grenade_cd)
	match run.player_class:
		&"vanguard":
			_ability_name.text = "WAR CRY"
			_ability_icon.kind = &"war_cry"
		_:
			_ability_name.text = "GRENADE"
			_ability_icon.kind = &"grenade"
	_stamina_bar.max_value = GameData.STAMINA_MAX
	_stamina_bar.value = run.stamina
	_sprint_row.modulate.a = 1.0 if run.sprinting or run.stamina < GameData.STAMINA_MAX - 0.01 else 0.0

	var w: GameData.Weapon = run.weapons[run.weapon_index]
	_ammo_text.text = "∞" if w.max_ammo < 0 else str(run.ammo[run.weapon_index])
	_weapon_name.text = w.display_name.to_upper()
	_fire_status.text = "SPRINTING" if run.sprinting else "NO AMMO" if w.max_ammo >= 0 and run.ammo[run.weapon_index] == 0 else "AUTO-FIRE"
	_fire_status.add_theme_color_override("font_color", UiTheme.DANGER if _fire_status.text == "NO AMMO" else UiTheme.TEXT_MUTED if run.sprinting else UiTheme.ACCENT)
	_update_weapon_slots(run)

	var warnings := PackedStringArray()
	if run.horde.grabbed_by != -1:
		warnings.append("GRABBED! USE BREAKER")
	if run.scream_progress > 0.3:
		warnings.append("SCREAMER SEES YOU / %d%%" % int(100.0 * run.scream_progress / GameData.SCREAM_TIME))
	if run.hp > 0.0 and run.hp <= run.max_hp * 0.25:
		warnings.append("LOW HEALTH")
	if run.survivor_lost:
		warnings.append("SURVIVOR LOST")
	_alerts.add_theme_color_override("font_color", UiTheme.SUCCESS if warnings.is_empty() else UiTheme.DANGER)
	if run.war_cry_time > 0.0:
		warnings.append("WAR CRY / -40%% DAMAGE / %.1f s" % run.war_cry_time)
	_alerts.text = "\n".join(warnings)
	# Even simultaneous warnings grow upwards rather than covering abilities.
	# (positions, not offsets: a block taller than planned grows past its offsets)
	var alerts_h: float = _alerts.get_combined_minimum_size().y
	_alerts.size.y = alerts_h
	_alerts.position.y = _abilities_panel.position.y - 10.0 - alerts_h
	_update_objective(run, island_text)

	_update_radio(run)
	if _minimap.run != run:
		_minimap.set_run(run)
		_legend.run = run
	_boss_row.visible = run.objective == IslandRun.Objective.BOSS
	_boss_bar.value = run.boss_hp_fraction()
	_boss_name.text = "BEHEMOTH / PHASE 2" if run.boss_enraged else "BEHEMOTH"
	_update_marker(run, camera)
	_update_threats(run, camera)

	_message_time -= get_process_delta_time()
	if not run.messages.is_empty():
		_message_log.append_array(run.messages)
		run.messages.clear()
		while _message_log.size() > 3:
			_message_log.remove_at(0)
		_message_time = 3.0
	_messages.text = "\n".join(_message_log) if _message_time > 0.0 else ""

	_debug.visible = debug_visible
	_debug.text = "FPS %d\nEnemies %d / %d\nSim %.2f ms\nDirector: %s (%.0f)" % [
		Engine.get_frames_per_second(), run.horde.count, run.director.max_alive, sim_ms,
		Director.phase_name(run.director.phase), run.director.intensity]

	_update_cards(run)

	_end_panel.visible = run.is_over()
	if run.is_over():
		var won: bool = run.objective == IslandRun.Objective.WON
		_end_label.text = "%s\n\nKills %d · Headshots %d · Level %d\nIntel earned here: %d\n\nEnter / A: continue" % [
			_cleared_text(run) if won else "YOU DIED", run.kills, run.headshots, run.level, run.intel_earned()]


func _cooldown_label(label: Label, seconds: float) -> void:
	label.text = "READY" if seconds <= 0.0 else "COOLDOWN"
	label.add_theme_color_override("font_color", UiTheme.ACCENT if seconds <= 0.0 else UiTheme.TEXT_MUTED)


func _update_weapon_slots(run: IslandRun) -> void:
	var slots: Array = []
	for k in mini(5, run.weapons.size()):
		var key: String = str(k + 1) if _gamepad else GameInput.prompt(StringName("weapon_%d" % (k + 1)), false)
		if not run.weapon_unlocked[k]:
			slots.append([&"empty", key])
		elif k == run.weapon_index:
			slots.append([&"active", key])
		else:
			var finite: bool = run.weapons[k].max_ammo >= 0
			var ammo: String = str(run.ammo[k]) if finite else "∞"
			slots.append([&"dry" if finite and run.ammo[k] == 0 else &"owned", "%s·%s" % [key, ammo]])
	_weapon_slots.set_slots(slots)


## End panel title for a win: the fort's extraction, an expedition part, or an island.
func _cleared_text(run: IslandRun) -> String:
	if run.mission == &"holdout":
		return "EXTRACTED!"
	return "PART CLEARED!" if run.has_exit() else "ISLAND CLEARED!"


func _update_objective(run: IslandRun, island_text: String) -> void:
	var detail: String = island_text.to_upper() if island_text != "" else "HALVARD OPERATIONS"
	var pips: int = 0
	match run.objective:
		IslandRun.Objective.GENERATORS:
			match run.mission:
				&"defend":
					_objective.text = "DEFEND THE UPLINK"
					detail += " · %d OF %d s" % [int(run.defend_time), int(GameData.DEFEND_TIME)]
				&"holdout":
					_objective.text = "HOLD THE FORT"
					detail += " · %d OF %d s" % [int(run.defend_time), int(run.hold_time())]
				&"rescue":
					_objective.text = "LOCATE THE SURVIVOR"
				_:
					_objective.text = "ACTIVATE THE GENERATORS"
					detail += " · %d OF %d ONLINE" % [_generators_done(run), GameData.GENERATOR_COUNT]
					pips = GameData.GENERATOR_COUNT
		IslandRun.Objective.BOSS:
			_objective.text = "ELIMINATE THE BEHEMOTH"
		IslandRun.Objective.RETURN_TO_BOAT:
			if run.mission == &"rescue" and run.survivor_found and not run.survivor_lost:
				_objective.text = "EXTRACT THE SURVIVOR"
			elif run.mission == &"holdout":
				_objective.text = "BOAT INBOUND" if run.boat_eta > 0.0 else "BOARD THE BOAT"
				if run.boat_eta > 0.0:
					detail += " · DOCKING IN %d s" % ceili(run.boat_eta)
			elif run.has_exit():
				_objective.text = ("HEAD TO " + run.exit_label).to_upper() if run.exit_label != "" else "LEAVE ALONG THE PATH"
			else:
				_objective.text = "RETURN TO THE BOAT"
		IslandRun.Objective.WON:
			_objective.text = "EXTRACTION COMPLETE"
		IslandRun.Objective.LOST:
			_objective.text = "CONTRACT TERMINATED"
	_objective_detail.text = detail
	_objective_pips.set_state(pips, _generators_done(run), UiTheme.INFO)
	_objective_pips.visible = pips > 0
	_survivor_row.visible = run.mission == &"rescue" and run.survivor_found and not run.survivor_lost and not run.is_over()
	_survivor_text.text = "SURVIVOR %d" % ceili(run.survivor_hp)
	_survivor_bar.max_value = GameData.SURVIVOR_HP
	_survivor_bar.value = run.survivor_hp


func _update_hit_arc(run: IslandRun, camera: Camera3D) -> void:
	if _last_hp >= 0.0 and run.hp < _last_hp and run.horde.damage_to_player > 0.0 and camera != null:
		# Screen-space direction from the player to the attacker.
		var a: Vector2 = camera.unproject_position(run.player_pos)
		var b: Vector2 = camera.unproject_position(run.horde.damage_from)
		_hit_angle = (b - a).angle()
		_hit_alpha = 1.0
	_hit_alpha = maxf(0.0, _hit_alpha - get_process_delta_time() * 1.5)
	_hit_arc.queue_redraw()


func _draw_hit_arc() -> void:
	if _hit_alpha <= 0.0:
		return
	var c: Vector2 = _hit_arc.get_viewport_rect().size * 0.5
	_hit_arc.draw_arc(c, 150.0, _hit_angle - 0.45, _hit_angle + 0.45, 24, Color(1, 0.1, 0.05, _hit_alpha * 0.85), 10.0)


## Floating damage numbers for headshots and kills (rise and fade).
func _update_popups(run: IslandRun, camera: Camera3D) -> void:
	var dt: float = get_process_delta_time()
	for p in run.popups:
		if _popups.size() >= 24:
			break
		var l := Label.new()
		l.text = str(int(p.z)) + ("!" if p.w > 0.5 else "")
		l.add_theme_font_size_override("font_size", 22 if p.w > 0.5 else 16)
		l.add_theme_color_override("font_color", UiTheme.ACCENT if p.w > 0.5 else UiTheme.TEXT)
		MenuDialog.ink(l, 4)
		_hit_arc.add_child(l)
		_popups.append(l)
		_popup_world.append(Vector3(p.x, 2.2, p.y))
		_popup_life.append(0.8)
	run.popups.clear()
	var i: int = _popups.size() - 1
	while i >= 0:
		_popup_life[i] -= dt
		_popup_world[i].y += dt * 1.5
		if _popup_life[i] <= 0.0 or camera == null or camera.is_position_behind(_popup_world[i]):
			_popups[i].queue_free()
			_popups.remove_at(i)
			_popup_world.remove_at(i)
			_popup_life.remove_at(i)
		else:
			_popups[i].position = camera.unproject_position(_popup_world[i]) - Vector2(12, 10)
			_popups[i].modulate.a = clampf(_popup_life[i] / 0.4, 0.0, 1.0)
		i -= 1


## Shows queued radio lines one at a time, typed out letter by letter.
func _update_radio(run: IslandRun) -> void:
	for key in run.radio:
		var line: String = Story.radio_line(key, _radio_rng)
		if line != "" and _radio_queue.size() < 3:
			_radio_queue.append(line)
	run.radio.clear()
	var dt: float = get_process_delta_time()
	if _radio_time > 0.0:
		_radio_time -= dt
		_radio_text.visible_ratio = minf(1.0, _radio_text.visible_ratio + dt * 2.0)
		if _radio_time <= 0.0:
			_radio_panel.visible = false
	elif not _radio_queue.is_empty():
		_radio_text.text = _radio_queue[0]
		_radio_queue.remove_at(0)
		_radio_text.visible_ratio = 0.0
		_radio_time = 2.5 + _radio_text.text.length() * 0.045
		_radio_panel.visible = true
	# Longer lines grow upwards, keeping a clear gap above the status block.
	var radio_h: float = _radio_panel.get_combined_minimum_size().y
	_radio_panel.size.y = radio_h
	_radio_panel.position.y = _status_panel.position.y - 12.0 - radio_h


## Points at the current goal; sticks to the screen edge when off-screen.
func _update_marker(run: IslandRun, camera: Camera3D) -> void:
	var goal := Vector3.INF
	var goal_name := ""
	if run.objective == IslandRun.Objective.GENERATORS and run.mission == &"defend":
		goal = run.site
		goal_name = "Uplink"
	elif run.objective == IslandRun.Objective.GENERATORS and run.mission == &"holdout":
		goal = run.site
		goal_name = "Courtyard"
	elif run.objective == IslandRun.Objective.GENERATORS and run.mission == &"rescue":
		goal = run.survivor_pos
		goal_name = "Survivor"
	elif run.objective == IslandRun.Objective.GENERATORS:
		var best: float = INF
		for g in GameData.GENERATOR_COUNT:
			if run.generator_progress[g] < GameData.GENERATOR_HOLD_SECONDS:
				var d: float = run.player_pos.distance_to(run.map.generators[g])
				if d < best:
					best = d
					goal = run.map.generators[g]
					goal_name = "Generator"
	elif run.objective == IslandRun.Objective.BOSS and run.boss_index() != -1:
		goal = run.horde.positions[run.boss_index()]
		goal_name = "Behemoth"
	elif run.objective == IslandRun.Objective.RETURN_TO_BOAT:
		goal = run.extraction_point()
		goal_name = run.extraction_name()
	if goal == Vector3.INF or camera == null:
		_marker_pill.visible = false
		_marker.text = ""
		return
	_marker_pill.visible = true
	var dist: float = run.player_pos.distance_to(goal)
	if run.objective == IslandRun.Objective.GENERATORS and run.mission == &"activate" and dist <= GameData.GENERATOR_RADIUS:
		var g_idx: int = run.map.generators.find(goal)
		_marker.text = "HOLDING · %d%%" % int(100.0 * run.generator_progress[g_idx] / GameData.GENERATOR_HOLD_SECONDS)
	else:
		_marker.text = "%s · %d m" % [goal_name.to_upper(), int(dist)]
	var view: Vector2 = get_viewport().get_visible_rect().size
	var pill: Vector2 = _marker_pill.get_combined_minimum_size()
	_marker_pill.size = pill
	var screen: Vector2 = view * 0.5
	if not camera.is_position_behind(goal):
		screen = camera.unproject_position(goal + Vector3(0, 2.5, 0))
	# Keep the pill inside a margin that avoids the HUD corners.
	screen.x = clampf(screen.x, 20.0 + pill.x * 0.5, view.x - 20.0 - pill.x * 0.5)
	screen.y = clampf(screen.y, 150.0, view.y - 150.0)
	if screen.x + pill.x * 0.5 > view.x - 200.0:
		screen.y = maxf(screen.y, 270.0)  # under the minimap and its key
	if _radio_panel.visible and screen.x - pill.x * 0.5 < 360.0:
		screen.y = minf(screen.y, _radio_panel.get_global_rect().position.y - 30.0)
	_marker_pill.position = screen - Vector2(pill.x * 0.5, pill.y)


## Edge arrows for specials and the boss that are out of view.
func _update_threats(run: IslandRun, camera: Camera3D) -> void:
	if camera == null or run.is_over() or not camera.is_inside_tree():
		_threats.set_items([])
		return
	var view: Vector2 = get_viewport().get_visible_rect().size
	var centre: Vector2 = view * 0.5
	var near: Array = []
	for i in run.horde.query_radius(run.player_pos, THREAT_RANGE):
		var kind: int = run.horde.kinds[i]
		if kind == GameData.EnemyKind.WALKER or kind == GameData.EnemyKind.RUNNER:
			continue
		near.append([run.player_pos.distance_squared_to(run.horde.positions[i]), i])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var items: Array = []
	var inner := Rect2(Vector2.ZERO, view).grow(-24.0)
	for entry: Array in near:
		if items.size() >= THREAT_ARROWS_MAX:
			break
		var i: int = entry[1]
		var p: Vector3 = run.horde.positions[i] + Vector3(0, 1.0, 0)
		var dir: Vector2
		if camera.is_position_behind(p):
			var local: Vector3 = camera.global_transform.affine_inverse() * p
			dir = Vector2(local.x, local.z)  # behind the camera: towards the bottom
		else:
			var s: Vector2 = camera.unproject_position(p)
			if inner.has_point(s):
				continue  # on screen: no arrow needed
			dir = s - centre
		if dir.length_squared() < 0.0001:
			continue
		dir = dir.normalized()
		var half: Vector2 = centre - Vector2(30, 30)
		var t: float = minf(half.x / maxf(absf(dir.x), 0.0001), half.y / maxf(absf(dir.y), 0.0001))
		var edge: Vector2 = centre + dir * t
		edge.y = minf(edge.y, view.y - 140.0)  # above the bottom HUD
		var crowded: bool = false
		for it: Array in items:
			crowded = crowded or (it[0] as Vector2).distance_to(edge) < 36.0
		if not crowded:
			items.append([edge, dir, run.horde.types[run.horde.kinds[i]].display_name.to_upper()])
	_threats.set_items(items)


## HUD size (Settings > Display): scales the field elements around the
## screen edges. The layer is resized to viewport / scale so anchored
## blocks still hug the corners at any size.
func apply_hud_scale() -> void:
	if _field == null or not is_inside_tree():
		return
	var percent: int = profile.hud_scale if profile != null else 100
	var s: float = clampf(percent / 100.0, 0.5, 1.0)
	var view: Vector2 = get_viewport().get_visible_rect().size
	_field.scale = Vector2(s, s)
	_field.position = Vector2.ZERO
	_field.size = view / s


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		apply_hud_scale()
		get_viewport().size_changed.connect(apply_hud_scale)
