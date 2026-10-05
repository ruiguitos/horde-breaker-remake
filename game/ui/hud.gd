class_name Hud
extends CanvasLayer
## Grey-box HUD built in code: bars, weapon, objective + marker, messages,
## card choice and end screen. Reads IslandRun every frame.

signal card_chosen(index: int)

var debug_visible: bool = true

var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _breaker_bar: ProgressBar
var _grenade_bar: ProgressBar
var _boss_bar: ProgressBar
var _info: Label
var _objective: Label
var _marker: Label
var _messages: Label
var _debug: Label
var _cards_panel: PanelContainer
var _card_buttons: Array[Button] = []
var _end_panel: PanelContainer
var _end_label: Label
var _message_log: PackedStringArray = PackedStringArray()
var _message_time: float = 0.0
var _shown_choices: int = -1
var _pause_label: Label
var _damage_flash: ColorRect
var _last_hp: float = -1.0


func _init() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Dark outline so text reads over any background.
	var theme := Theme.new()
	theme.set_constant("outline_size", "Label", 5)
	theme.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	root.theme = theme
	add_child(root)

	var bars := VBoxContainer.new()
	bars.position = Vector2(16, 16)
	bars.custom_minimum_size = Vector2(280, 0)
	root.add_child(bars)
	_hp_bar = _bar(bars, "HP", Color(0.85, 0.2, 0.2))
	_xp_bar = _bar(bars, "XP", Color(0.3, 0.8, 1.0))
	_breaker_bar = _bar(bars, "Breaker", Color(1.0, 0.75, 0.2))
	_grenade_bar = _bar(bars, "Grenade", Color(0.5, 0.85, 0.3))
	_info = Label.new()
	bars.add_child(_info)

	_objective = Label.new()
	_objective.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_objective.position = Vector2(-250, 16)
	_objective.custom_minimum_size = Vector2(500, 0)
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_objective.add_theme_font_size_override("font_size", 22)
	root.add_child(_objective)

	_marker = Label.new()
	_marker.add_theme_font_size_override("font_size", 18)
	_marker.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	root.add_child(_marker)

	# Boss health bar under the objective.
	_boss_bar = ProgressBar.new()
	_boss_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_boss_bar.position = Vector2(-250, 52)
	_boss_bar.custom_minimum_size = Vector2(500, 22)
	_boss_bar.show_percentage = false
	var boss_fill := StyleBoxFlat.new()
	boss_fill.bg_color = Color(0.7, 0.1, 0.15)
	_boss_bar.add_theme_stylebox_override("fill", boss_fill)
	_boss_bar.max_value = 1.0
	_boss_bar.visible = false
	root.add_child(_boss_bar)

	_messages = Label.new()
	_messages.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_messages.position = Vector2(-250, 56)
	_messages.custom_minimum_size = Vector2(500, 0)
	_messages.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_messages)

	_debug = Label.new()
	_debug.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug.position = Vector2(-260, 16)
	_debug.custom_minimum_size = Vector2(240, 0)
	_debug.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(_debug)

	var help := Label.new()
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(16, -40)
	help.text = "WASD move · mouse aims (auto-fire) · Space/RMB breaker · G/MMB grenade · 1-5 weapons · Esc pause · F3 debug"
	help.modulate = Color(1, 1, 1, 0.7)
	root.add_child(help)

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
	_pause_label = Label.new()
	_pause_label.set_anchors_preset(Control.PRESET_CENTER)
	_pause_label.position = Vector2(-200, -40)
	_pause_label.custom_minimum_size = Vector2(400, 0)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.add_theme_font_size_override("font_size", 26)
	_pause_label.text = "PAUSED\n\nEsc: resume · Q: abandon run"
	_pause_label.visible = false
	root.add_child(_pause_label)
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


func _bar(parent: Control, label: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	row.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(200, 18)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar


func refresh(run: IslandRun, camera: Camera3D, sim_ms: float, paused: bool = false, island_text: String = "") -> void:
	_pause_label.visible = paused
	if _last_hp >= 0.0 and run.hp < _last_hp:
		_damage_flash.color.a = clampf(_damage_flash.color.a + (_last_hp - run.hp) * 0.02, 0.0, 0.35)
	_last_hp = run.hp
	_damage_flash.color.a = maxf(0.0, _damage_flash.color.a - get_process_delta_time() * 1.5)
	_hp_bar.max_value = run.max_hp
	_hp_bar.value = run.hp
	_xp_bar.max_value = run.xp_needed()
	_xp_bar.value = run.xp
	var total: float = run.breaker_cooldown_total()
	_breaker_bar.max_value = total
	_breaker_bar.value = total - run.breaker_cd
	_grenade_bar.max_value = run.grenade_cooldown_total()
	_grenade_bar.value = run.grenade_cooldown_total() - run.grenade_cd
	var w: GameData.Weapon = run.weapons[run.weapon_index]
	var ammo_text: String = "∞" if w.max_ammo < 0 else str(run.ammo[run.weapon_index])
	_info.text = "Level %d   Kills %d   Headshots %d\n[%d] %s  %s" % [
		run.level, run.kills, run.headshots, run.weapon_index + 1, w.display_name, ammo_text]
	if run.horde.grabbed_by != -1:
		_info.text += "\nGRABBED! Use the breaker!"
	if run.scream_progress > 0.3:
		_info.text += "\nA SCREAMER SEES YOU! (%d%%)" % int(100.0 * run.scream_progress / GameData.SCREAM_TIME)
	_objective.text = (island_text + " — " if island_text != "" else "") + run.objective_text()

	_boss_bar.visible = run.objective == IslandRun.Objective.BOSS
	_boss_bar.value = run.boss_hp_fraction()
	_messages.position.y = 84.0 if _boss_bar.visible else 56.0
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


## Points at the current goal; sticks to the screen edge when off-screen.
func _update_marker(run: IslandRun, camera: Camera3D) -> void:
	var goal := Vector3.INF
	var goal_name := ""
	if run.objective == IslandRun.Objective.GENERATORS:
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
	if run.objective == IslandRun.Objective.GENERATORS and dist <= GameData.GENERATOR_RADIUS:
		var g_idx: int = run.map.generators.find(goal)
		_marker.text = "Holding... %d%%" % int(100.0 * run.generator_progress[g_idx] / GameData.GENERATOR_HOLD_SECONDS)
	else:
		_marker.text = "▼ %s %d m" % [goal_name, int(dist)]
	var size: Vector2 = get_viewport().get_visible_rect().size
	var screen: Vector2 = size * 0.5
	if not camera.is_position_behind(goal):
		screen = camera.unproject_position(goal + Vector3(0, 2.5, 0))
	# Keep the marker inside a margin that avoids the HUD corners.
	screen.x = clampf(screen.x, 60.0, size.x - 200.0)
	screen.y = clampf(screen.y, 170.0, size.y - 80.0)
	_marker.position = screen - Vector2(40, 0)
