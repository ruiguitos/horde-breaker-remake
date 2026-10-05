class_name Hud
extends CanvasLayer
## Tactical field-equipment HUD. Reads IslandRun; never changes game rules.

signal card_chosen(index: int)
signal resume_requested
signal abandon_requested

var debug_visible: bool = false
var profile: Profile
var _pause_dialog: MenuDialog

var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _breaker_bar: ProgressBar
var _grenade_bar: ProgressBar
var _boss_bar: ProgressBar
var _minimap: Minimap
var _hit_arc: Control
var _hit_angle: float = 0.0
var _hit_alpha: float = 0.0
var _popups: Array[Label] = []
var _popup_world: Array[Vector3] = []
var _popup_life: PackedFloat32Array = PackedFloat32Array()
var _radio_panel: PanelContainer
var _radio_text: Label
var _radio_queue: PackedStringArray = PackedStringArray()
var _radio_time: float = 0.0
var _radio_rng := RandomNumberGenerator.new()
var _stamina_bar: ProgressBar
var _info: Label
var _objective: Label
var _marker: Label
var _field: Control  ## scaled by the HUD size setting
var _messages: Label
var _debug: Label
var _cards_panel: PanelContainer
var _card_buttons: Array[Button] = []
var _end_panel: PanelContainer
var _end_label: Label
var _message_log: PackedStringArray = PackedStringArray()
var _message_time: float = 0.0
var _shown_choices: int = -1
var _pause_panel: Control
var _damage_flash: ColorRect
var _last_hp: float = -1.0
var _status_panel: PanelContainer
var _abilities_panel: PanelContainer
var _weapon_panel: PanelContainer
var _hp_text: Label
var _xp_text: Label
var _stats: Label
var _weapon_name: Label
var _ammo_text: Label
var _fire_status: Label
var _breaker_status: Label
var _ability_status: Label
var _ability_name: Label
var _breaker_key: Label
var _ability_key: Label
var _sprint_key: Label
var _ability_icon: FieldIcon
var _objective_detail: Label
var _survivor_row: HBoxContainer
var _survivor_bar: ProgressBar
var _survivor_text: Label
var _boss_row: VBoxContainer
var _boss_name: Label
var _alerts: Label
var _gamepad: bool = false


## Small vector glyphs keep the HUD sharp without downloaded assets.
class FieldIcon extends Control:

	var kind: StringName = &"badge":
		set(value):
			if kind != value:
				kind = value
				queue_redraw()

	func _init(icon_kind: StringName = &"badge", extent: Vector2 = Vector2(34, 34)) -> void:
		kind = icon_kind
		custom_minimum_size = extent
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(48, 48))
		var ink: Color = UiTheme.ACCENT
		match kind:
			&"badge", &"war_cry":
				draw_polyline(PackedVector2Array([Vector2(24, 5), Vector2(39, 12), Vector2(37, 32), Vector2(24, 43), Vector2(11, 32), Vector2(9, 12), Vector2(24, 5)]), ink, 2.0, true)
				for y in [18, 26]:
					draw_polyline(PackedVector2Array([Vector2(16, y), Vector2(24, y + 6), Vector2(32, y)]), ink, 3.0, true)
			&"breaker":
				draw_circle(Vector2(28, 10), 4, ink)
				draw_polyline(PackedVector2Array([Vector2(15, 21), Vector2(24, 17), Vector2(34, 24), Vector2(42, 24)]), ink, 4.0, true)
				draw_polyline(PackedVector2Array([Vector2(24, 18), Vector2(22, 29), Vector2(13, 40)]), ink, 4.0, true)
				draw_polyline(PackedVector2Array([Vector2(22, 28), Vector2(31, 31), Vector2(32, 41)]), ink, 4.0, true)
				for y in [12, 27, 35]:
					draw_line(Vector2(3, y), Vector2(12, y), ink, 2.0, true)
			&"weapon":
				draw_colored_polygon(PackedVector2Array([Vector2(2, 16), Vector2(15, 20), Vector2(18, 15), Vector2(33, 15), Vector2(34, 19), Vector2(46, 19), Vector2(46, 23), Vector2(30, 23), Vector2(27, 35), Vector2(21, 34), Vector2(23, 23), Vector2(15, 23), Vector2(8, 29), Vector2(2, 29)]), UiTheme.TEXT)
				draw_rect(Rect2(24, 10, 6, 4), UiTheme.TEXT)
			_:
				draw_circle(Vector2(24, 28), 12.0, ink)
				draw_rect(Rect2(18, 10, 12, 7), ink)
				draw_polyline(PackedVector2Array([Vector2(21, 9), Vector2(28, 5), Vector2(36, 13), Vector2(36, 29)]), ink, 2.0, true)
				draw_line(Vector2(21, 22), Vector2(21, 32), UiTheme.BG, 2.0)


func _init() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Menus and field equipment share the same typography and palette.
	root.theme = UiTheme.get_theme()
	add_child(root)

	# Field panels live in their own full-screen layer so "HUD size"
	# (Settings > Display) can scale them; world markers stay unscaled.
	_field = Control.new()
	_field.name = "FieldPanels"
	_field.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_field)
	_build_field_hud(_field)
	add_to_group(&"hud")

	_marker = Label.new()
	_marker.add_theme_font_size_override("font_size", 18)
	_marker.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	root.add_child(_marker)

	# Damage direction: a red arc around the screen centre.
	_hit_arc = Control.new()
	_hit_arc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hit_arc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_arc.draw.connect(_draw_hit_arc)
	root.add_child(_hit_arc)

	_messages = _label("", 16)
	_messages.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_messages.position = Vector2(-215, 145)
	_messages.size = Vector2(430, 80)
	_messages.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_messages)

	_debug = Label.new()
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.position = Vector2(-280, 250)
	_debug.custom_minimum_size = Vector2(240, 0)
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_debug)

	_cards_panel = PanelContainer.new()
	_cards_panel.set_anchors_preset(Control.PRESET_CENTER)
	_cards_panel.position = Vector2(-330, -110)
	_cards_panel.visible = false
	root.add_child(_cards_panel)
	var cards_box := VBoxContainer.new()
	_cards_panel.add_child(cards_box)
	var title := Label.new()
	title.text = "LEVEL UP — pick a card (1 / 2 / 3)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cards_box.add_child(title)
	var row := HBoxContainer.new()
	cards_box.add_child(row)
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(210, 150)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.pressed.connect(func() -> void: card_chosen.emit(i))
		row.add_child(b)
		_card_buttons.append(b)

	_end_panel = PanelContainer.new()
	_end_panel.set_anchors_preset(Control.PRESET_CENTER)
	_end_panel.position = Vector2(-200, -100)
	_end_panel.custom_minimum_size = Vector2(400, 200)
	_end_panel.visible = false
	root.add_child(_end_panel)
	# Pause overlays the current game with a screen-texture blur.
	_pause_panel = ColorRect.new()
	(_pause_panel as ColorRect).color = Color(0, 0, 0, 0.75)
	var blur := Shader.new()
	blur.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap; void fragment() { COLOR = vec4(textureLod(screen_texture, SCREEN_UV, 2.2).rgb * 0.4, 1.0); }"
	var blur_material := ShaderMaterial.new()
	blur_material.shader = blur
	_pause_panel.material = blur_material
	_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_panel.visible = false
	root.add_child(_pause_panel)
	var pbox: VBoxContainer = UiTheme.centered_panel(_pause_panel, 380)
	pbox.add_child(UiTheme.label("SALVAGE & CO. / PROJECT TIDE", 16, UiTheme.MUTED, true))
	pbox.add_child(UiTheme.title("PAUSED", 44))
	UiTheme.button(pbox, "RESUME   ›", func() -> void: resume_requested.emit(), true)
	UiTheme.button(pbox, "SETTINGS", _settings)
	UiTheme.button(pbox, "CONTROLS", _controls)
	var abandon := UiTheme.button(pbox, "ABANDON RUN", func() -> void: abandon_requested.emit())
	abandon.theme_type_variation = &"DangerButton"
	pbox.add_child(HSeparator.new())
	pbox.add_child(UiTheme.label("Intel from completed islands is retained.", 16, UiTheme.MUTED, true))
	UiTheme.hints(pbox, "[ ENTER / A ] SELECT   [ ESC / B ] BACK", 14)
	# Red screen flash when the player takes damage (drawn behind panels).
	_damage_flash = ColorRect.new()
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_damage_flash.color = Color(0.8, 0, 0, 0)
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_damage_flash)
	root.move_child(_damage_flash, 0)
	_end_label = Label.new()
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_panel.add_child(_end_label)


func _plate(parent: Control, preset: Control.LayoutPreset, offset: Vector2, extent: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	panel.set_anchors_preset(preset)
	panel.position = offset
	panel.size = extent
	panel.custom_minimum_size.x = extent.x
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.07, 0.06, 0.93)
	style.border_color = UiTheme.PANEL_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	return panel


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


func _heading(parent: Control, text: String, font_size: int = 20) -> Label:
	var label := _label(text, font_size)
	label.add_theme_font_override("font", UiTheme.heading_font())
	parent.add_child(label)
	return label


func _label(text: String, font_size: int = 18, color: Color = UiTheme.TEXT, mono: bool = false) -> Label:
	var label := UiTheme.label(text, font_size, color, mono)
	# Fixed HUD labels must have stable minimum heights while containers settle.
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label


func _meter(parent: Control, color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, height)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color("080c09")
	track.border_color = Color("373f33")
	track.set_border_width_all(1)
	bar.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	parent.add_child(bar)
	return bar


func _build_field_hud(root: Control) -> void:
	_status_panel = _plate(root, Control.PRESET_BOTTOM_LEFT, Vector2(18, -128), Vector2(306, 110))
	var status := _column(_status_panel)
	var identity := _row(status)
	identity.add_child(FieldIcon.new(&"badge", Vector2(28, 28)))
	_info = _heading(identity, "RECRUIT / LVL 1")
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var health := _row(status)
	health.add_child(_label("HP", 13, UiTheme.MUTED, true))
	_hp_bar = _meter(health, UiTheme.DANGER, 15)
	_hp_text = _label("100 / 100", 14, UiTheme.TEXT, true)
	_hp_text.custom_minimum_size.x = 76
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	health.add_child(_hp_text)
	_xp_bar = _meter(status, Color("72bdc7"), 4)
	var progression := _row(status)
	_xp_text = _label("", 12, UiTheme.MUTED, true)
	_xp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progression.add_child(_xp_text)
	_stats = _label("", 12, UiTheme.MUTED, true)
	progression.add_child(_stats)

	_abilities_panel = _plate(root, Control.PRESET_CENTER_BOTTOM, Vector2(-143, -128), Vector2(286, 110))
	var abilities := _column(_abilities_panel, 7)
	var tiles := _row(abilities, 12)
	var breaker := _column(tiles, 3)
	var breaker_top := _row(breaker, 5)
	breaker_top.add_child(FieldIcon.new(&"breaker"))
	var breaker_words := _column(breaker_top, 1)
	_heading(breaker_words, "BREAKER", 17)
	_breaker_key = _label("[ SPACE ]", 12, UiTheme.MUTED, true)
	breaker_words.add_child(_breaker_key)
	_breaker_status = _label("READY", 13, UiTheme.ACCENT, true)
	breaker.add_child(_breaker_status)
	_breaker_bar = _meter(breaker, UiTheme.ACCENT, 3)
	var ability := _column(tiles, 3)
	var ability_top := _row(ability, 5)
	_ability_icon = FieldIcon.new(&"grenade")
	ability_top.add_child(_ability_icon)
	var ability_words := _column(ability_top, 1)
	_ability_name = _heading(ability_words, "GRENADE", 17)
	_ability_key = _label("[ G ]", 12, UiTheme.MUTED, true)
	ability_words.add_child(_ability_key)
	_ability_status = _label("READY", 13, UiTheme.ACCENT, true)
	ability.add_child(_ability_status)
	_grenade_bar = _meter(ability, UiTheme.ACCENT, 3)
	var sprint := _row(abilities)
	_sprint_key = _label("[ SHIFT ] SPRINT", 11, UiTheme.MUTED, true)
	sprint.add_child(_sprint_key)
	_stamina_bar = _meter(sprint, UiTheme.TEXT, 4)

	_weapon_panel = _plate(root, Control.PRESET_BOTTOM_RIGHT, Vector2(-268, -128), Vector2(250, 110))
	var weapon := _column(_weapon_panel, 3)
	var weapon_top := _row(weapon)
	weapon_top.add_child(FieldIcon.new(&"weapon", Vector2(45, 29)))
	_weapon_name = _heading(weapon_top, "ASSAULT RIFLE", 18)
	_weapon_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ammo := _row(weapon)
	_ammo_text = _heading(ammo, "∞", 34)
	_ammo_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fire_status = _label("AUTO-FIRE", 13, UiTheme.ACCENT, true)
	_fire_status.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ammo.add_child(_fire_status)
	weapon.add_child(_label("1–5 / D-PAD  ·  SWITCH WEAPON", 11, UiTheme.MUTED, true))

	var objective_panel := _plate(root, Control.PRESET_CENTER_TOP, Vector2(-215, 18), Vector2(430, 78))
	var objective := _column(objective_panel, 4)
	_objective = _heading(objective, "FIELD OBJECTIVE", 21)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective_detail = _label("", 14, UiTheme.MUTED, true)
	_objective_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective.add_child(_objective_detail)
	_survivor_row = _row(objective)
	_survivor_text = _label("SURVIVOR 100", 12, UiTheme.SUCCESS, true)
	_survivor_row.add_child(_survivor_text)
	_survivor_bar = _meter(_survivor_row, UiTheme.SUCCESS, 5)
	_survivor_row.visible = false
	_boss_row = _column(objective, 3)
	_boss_name = _label("BEHEMOTH", 13, UiTheme.DANGER, true)
	_boss_row.add_child(_boss_name)
	_boss_bar = _meter(_boss_row, UiTheme.DANGER, 8)
	_boss_bar.max_value = 1.0
	_boss_row.visible = false

	var map_panel := _plate(root, Control.PRESET_TOP_RIGHT, Vector2(-212, 18), Vector2(194, 212))
	var map_box := _column(map_panel, 4)
	var map_header := _row(map_box)
	var map_title := _label("HALVARD / FIELD MAP", 11, UiTheme.MUTED, true)
	map_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_header.add_child(map_title)
	map_header.add_child(_label("N ↑", 11, UiTheme.TEXT, true))
	_minimap = Minimap.new()
	map_box.add_child(_minimap)
	map_box.add_child(_label("● HOSTILE   ◆ OBJECTIVE", 10, UiTheme.MUTED, true))

	_radio_panel = _plate(root, Control.PRESET_BOTTOM_LEFT, Vector2(18, -238), Vector2(306, 82))
	var radio := _column(_radio_panel, 3)
	radio.add_child(_label("RADIO / DIRECTOR HALE", 12, UiTheme.ACCENT, true))
	_radio_text = _label("", 14)
	_radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio.add_child(_radio_text)
	_radio_panel.visible = false

	_alerts = _label("", 17, UiTheme.DANGER)
	_alerts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_alerts.add_theme_constant_override("outline_size", 4)
	_alerts.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_alerts.position = Vector2(-143, -225)
	_alerts.size = Vector2(286, 80)
	_alerts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_alerts)


func _input(event: InputEvent) -> void:
	# The last active input device determines prompts; stick drift is ignored.
	if event is InputEventJoypadButton and event.pressed:
		_gamepad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		_gamepad = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		_gamepad = false
	elif event is InputEventMouseMotion and event.relative.length_squared() > 4.0:
		_gamepad = false
	_breaker_key.text = "[ RB / A ]" if _gamepad else "[ SPACE ]"
	_ability_key.text = "[ LB ]" if _gamepad else "[ G ]"
	_sprint_key.text = "[ L3 ] SPRINT" if _gamepad else "[ SHIFT ] SPRINT"


func _cooldown_label(label: Label, seconds: float) -> void:
	label.text = "READY" if seconds <= 0.0 else "%.1f s" % seconds
	label.add_theme_color_override("font_color", UiTheme.ACCENT if seconds <= 0.0 else UiTheme.MUTED)


func refresh(run: IslandRun, camera: Camera3D, sim_ms: float, paused: bool = false, island_text: String = "") -> void:
	if paused and not _pause_panel.visible:
		_pause_panel.visible = true
		for b in _pause_panel.find_children("*", "Button", true, false):
			(b as Button).grab_focus()
			break
	elif not paused:
		_pause_panel.visible = false
	_update_hit_arc(run, camera)
	_update_popups(run, camera)
	if _last_hp >= 0.0 and run.hp < _last_hp:
		_damage_flash.color.a = clampf(_damage_flash.color.a + (_last_hp - run.hp) * 0.02, 0.0, 0.35)
	_last_hp = run.hp
	_damage_flash.color.a = maxf(0.0, _damage_flash.color.a - get_process_delta_time() * 1.5)
	_hp_bar.max_value = run.max_hp
	_hp_bar.value = run.hp
	_hp_text.text = "%d / %d" % [ceili(run.hp), ceili(run.max_hp)]
	_xp_bar.max_value = run.xp_needed()
	_xp_bar.value = run.xp
	_xp_text.text = "XP %d / %d" % [run.xp, run.xp_needed()]
	_stats.text = "%d KILLS / %d HS" % [run.kills, run.headshots]
	var total: float = run.breaker_cooldown_total()
	_breaker_bar.max_value = total
	_breaker_bar.value = total - run.breaker_cd
	_stamina_bar.max_value = GameData.STAMINA_MAX
	_stamina_bar.value = run.stamina
	_grenade_bar.max_value = run.ability_cooldown_total()
	_grenade_bar.value = run.ability_cooldown_total() - run.grenade_cd
	_cooldown_label(_breaker_status, run.breaker_cd)
	_cooldown_label(_ability_status, run.grenade_cd)
	match run.player_class:
		&"vanguard":
			_ability_name.text = "WAR CRY"
			_ability_icon.kind = &"war_cry"
		_:
			_ability_name.text = "GRENADE"
			_ability_icon.kind = &"grenade"
	var w: GameData.Weapon = run.weapons[run.weapon_index]
	_ammo_text.text = "∞" if w.max_ammo < 0 else str(run.ammo[run.weapon_index])
	_weapon_name.text = w.display_name.to_upper()
	_fire_status.text = "SPRINTING" if run.sprinting else "NO AMMO" if w.max_ammo >= 0 and run.ammo[run.weapon_index] == 0 else "AUTO-FIRE"
	_fire_status.add_theme_color_override("font_color", UiTheme.DANGER if _fire_status.text == "NO AMMO" else UiTheme.MUTED if run.sprinting else UiTheme.ACCENT)
	_info.text = "%s / LVL %d" % [String(GameData.CLASS_INFO[run.player_class]["name"]).to_upper(), run.level]
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
	_alerts.offset_top = -140.0 - _alerts.size.y
	_alerts.offset_bottom = -140.0
	_update_objective(run, island_text)

	_update_radio(run)
	if _minimap.run != run:
		_minimap.set_run(run)
	_boss_row.visible = run.objective == IslandRun.Objective.BOSS
	_boss_bar.value = run.boss_hp_fraction()
	_boss_name.text = "BEHEMOTH / PHASE 2" if run.boss_enraged else "BEHEMOTH"
	_update_marker(run, camera)

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

	_cards_panel.visible = not run.card_choices.is_empty()
	if _cards_panel.visible and _shown_choices != run.level:
		_shown_choices = run.level
		for i in 3:
			var has: bool = i < run.card_choices.size()
			_card_buttons[i].visible = has
			if has:
				var c: GameData.Card = run.card_choices[i]
				_card_buttons[i].text = "%d. %s\n\n%s" % [i + 1, c.title, c.description]

	_end_panel.visible = run.is_over()
	if run.is_over():
		var won: bool = run.objective == IslandRun.Objective.WON
		_end_label.text = "%s\n\nKills %d · Headshots %d · Level %d\nIntel from this island: %d\n\nEnter / A: continue" % [
			"ISLAND CLEARED!" if won else "YOU DIED", run.kills, run.headshots, run.level, run.intel_earned()]


func _update_objective(run: IslandRun, island_text: String) -> void:
	var detail: String = island_text.to_upper() if island_text != "" else "HALVARD OPERATIONS"
	match run.objective:
		IslandRun.Objective.GENERATORS:
			match run.mission:
				&"defend":
					_objective.text = "DEFEND THE UPLINK"
					detail += " / %d OF %d s" % [int(run.defend_time), int(GameData.DEFEND_TIME)]
				&"rescue":
					_objective.text = "LOCATE THE SURVIVOR"
				_:
					var completed: int = 0
					for progress in run.generator_progress:
						if progress >= GameData.GENERATOR_HOLD_SECONDS:
							completed += 1
					_objective.text = "ACTIVATE THE GENERATORS"
					detail += " / %d OF %d ONLINE" % [completed, GameData.GENERATOR_COUNT]
		IslandRun.Objective.BOSS:
			_objective.text = "ELIMINATE THE BEHEMOTH"
		IslandRun.Objective.RETURN_TO_BOAT:
			_objective.text = "EXTRACT THE SURVIVOR" if run.mission == &"rescue" and run.survivor_found and not run.survivor_lost else "RETURN TO THE BOAT"
		IslandRun.Objective.WON:
			_objective.text = "EXTRACTION COMPLETE"
		IslandRun.Objective.LOST:
			_objective.text = "CONTRACT TERMINATED"
	_objective_detail.text = detail
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
	# Longer lines grow upwards, keeping a clear gap above player health.
	_radio_panel.offset_top = -140.0 - _radio_panel.size.y
	_radio_panel.offset_bottom = -140.0


## Points at the current goal; sticks to the screen edge when off-screen.
func _update_marker(run: IslandRun, camera: Camera3D) -> void:
	var goal := Vector3.INF
	var goal_name := ""
	if run.objective == IslandRun.Objective.GENERATORS and run.mission == &"defend":
		goal = run.site
		goal_name = "Uplink"
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
		goal = run.map.boat
		goal_name = "Boat"
	if goal == Vector3.INF or camera == null:
		_marker.visible = false
		return
	_marker.visible = true
	var dist: float = run.player_pos.distance_to(goal)
	if run.objective == IslandRun.Objective.GENERATORS and run.mission != &"activate":
		_marker.text = "▼ %s %d m" % [goal_name, int(dist)]
	elif run.objective == IslandRun.Objective.GENERATORS and dist <= GameData.GENERATOR_RADIUS:
		var g_idx: int = run.map.generators.find(goal)
		_marker.text = "Holding... %d%%" % int(100.0 * run.generator_progress[g_idx] / GameData.GENERATOR_HOLD_SECONDS)
	else:
		_marker.text = "▼ %s %d m" % [goal_name, int(dist)]
	var size: Vector2 = get_viewport().get_visible_rect().size
	var screen: Vector2 = size * 0.5
	if not camera.is_position_behind(goal):
		screen = camera.unproject_position(goal + Vector3(0, 2.5, 0))
	# Keep the marker inside a margin that avoids the HUD corners.
	screen.x = clampf(screen.x, 60.0, size.x - 160.0)
	screen.y = clampf(screen.y, 155.0, size.y - 155.0)
	if screen.x > size.x - 235.0:
		screen.y = maxf(screen.y, 250.0)
	if _radio_panel.visible and screen.x < 365.0:
		screen.y = minf(screen.y, _radio_panel.position.y - 30.0)
	_marker.position = screen - Vector2(40, 0)

func _settings() -> void:
	if not is_instance_valid(_pause_dialog) and profile != null:
		_pause_dialog = MenuDialog.settings(_pause_panel, profile)


func _controls() -> void:
	if not is_instance_valid(_pause_dialog):
		_pause_dialog = MenuDialog.controls(_pause_panel)


func _unhandled_input(event: InputEvent) -> void:
	if _pause_panel.visible and not is_instance_valid(_pause_dialog) and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		resume_requested.emit()


## HUD size (Settings > Display): scales the field panels around the screen
## edges. The layer is resized to viewport / scale so anchored panels still
## hug the corners at any size.
func apply_hud_scale() -> void:
	if _field == null or not is_inside_tree():
		return
	var percent: int = profile.hud_scale if profile != null else 60
	var s: float = clampf(percent / 100.0, 0.5, 1.0)
	var view: Vector2 = get_viewport().get_visible_rect().size
	_field.scale = Vector2(s, s)
	_field.position = Vector2.ZERO
	_field.size = view / s


func _notification(what: int) -> void:
	if what == NOTIFICATION_READY:
		apply_hud_scale()
		get_viewport().size_changed.connect(apply_hud_scale)
