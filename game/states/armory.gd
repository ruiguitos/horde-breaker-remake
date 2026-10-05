extends Control
## Between runs: spend Intel on perks and slots, equip perks, pick the Threat
## level and start a run. Unlocks are horizontal (new options, small bonuses)
## as in docs/design/PROGRESSION_AND_ECONOMY.md §3.

signal start_requested

var profile: Profile

var _list: VBoxContainer
var _header: Label
var _threat_row: HBoxContainer
var _volume_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	theme = UiTheme.get_theme()
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box: VBoxContainer = UiTheme.centered_panel(self, 760)
	box.add_child(UiTheme.title("ARMORY", 34))
	if profile.runs == 0:
		var tips := Label.new()
		tips.text = "First time? Your gun fires by itself at enemies in front of you: aim with your body (the laser turns red for headshots). Space = breaker dash through the horde, G = grenade, Shift = sprint. Activate 3 generators, then get back to the boat."
		tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tips.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tips.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
		box.add_child(tips)
	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_header)
	# The list scrolls so the menu fits small windows (default 1152x648).
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 230 if profile.runs == 0 else 280)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var threat_label := Label.new()
	threat_label.text = "Threat (extract on your highest Threat to unlock the next):"
	box.add_child(threat_label)
	_threat_row = HBoxContainer.new()
	box.add_child(_threat_row)
	var settings := HBoxContainer.new()
	box.add_child(settings)
	_volume_label = Label.new()
	_volume_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings.add_child(_volume_label)
	for delta in [-1, 1]:
		var vb := Button.new()
		vb.text = " - " if delta < 0 else " + "
		vb.pressed.connect(func() -> void:
			profile.volume = clampi(profile.volume + delta, 0, 10)
			profile.apply_volume()
			_act(true))
		settings.add_child(vb)
	var start := Button.new()
	start.text = "START RUN (Enter)"
	start.custom_minimum_size = Vector2(0, 50)
	start.pressed.connect(_start)
	box.add_child(start)
	_rebuild()
	start.grab_focus()


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	for c in _threat_row.get_children():
		c.queue_free()
	_header.text = "Intel: %d   ·   Perk slots: %d (%d equipped)" % [
		profile.intel, profile.slots, profile.equipped_perks.size()]
	_volume_label.text = "Volume: %d/10   ·   F11: fullscreen" % profile.volume
	for id in GameData.CLASSES:
		var info: Dictionary = GameData.CLASS_INFO[id]
		var crow := HBoxContainer.new()
		var cl := Label.new()
		cl.text = "Class: %s — %s" % [info["name"], info["text"]]
		cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		crow.add_child(cl)
		var cb := Button.new()
		cb.custom_minimum_size = Vector2(150, 0)
		if not profile.unlocked_classes.has(id):
			cb.text = "Buy (%d)" % int(info["cost"])
			cb.disabled = profile.intel < int(info["cost"])
			cb.pressed.connect(func() -> void: _act(profile.buy_class(id)))
		elif profile.selected_class == id:
			cb.text = "✔ Selected"
			cb.disabled = true
		else:
			cb.text = "Select"
			cb.pressed.connect(func() -> void:
				profile.selected_class = id
				_act(true))
		crow.add_child(cb)
		_list.add_child(crow)
	for perk in GameData.perks():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s — %s" % [perk.title, perk.description]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 0)
		if not profile.owned_perks.has(perk.id):
			b.text = "Buy (%d)" % perk.cost
			b.disabled = profile.intel < perk.cost
			b.pressed.connect(func() -> void: _act(profile.buy_perk(perk)))
		elif profile.equipped_perks.has(perk.id):
			b.text = "✔ Equipped"
			b.pressed.connect(func() -> void: _act(profile.toggle_equip(perk.id)))
		else:
			b.text = "Equip"
			b.disabled = profile.equipped_perks.size() >= profile.slots
			b.pressed.connect(func() -> void: _act(profile.toggle_equip(perk.id)))
		row.add_child(b)
		_list.add_child(row)
	for w in GameData.weapons():
		if not GameData.WEAPON_COSTS.has(w.id):
			continue
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "Weapon: %s — %d dmg, %.0f shots/s, %d m" % [w.display_name, int(w.damage), w.fire_rate, int(w.range_m)]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var b := Button.new()
		b.custom_minimum_size = Vector2(150, 0)
		var cost_w: int = int(GameData.WEAPON_COSTS[w.id])
		if profile.unlocked_weapons.has(w.id):
			b.text = "✔ Unlocked"
			b.disabled = true
		else:
			b.text = "Buy (%d)" % cost_w
			b.disabled = profile.intel < cost_w
			b.pressed.connect(func() -> void: _act(profile.buy_weapon(w.id)))
		row.add_child(b)
		_list.add_child(row)
	var cost: int = profile.next_slot_cost()
	if cost > 0:
		var slot := Button.new()
		slot.text = "Buy perk slot %d (%d Intel)" % [profile.slots + 1, cost]
		slot.disabled = profile.intel < cost
		slot.pressed.connect(func() -> void: _act(profile.buy_slot()))
		_list.add_child(slot)
	for t in range(1, GameData.MAX_THREAT + 1):
		var tb := Button.new()
		tb.text = "Threat %d%s  (Intel x%.2f)" % [t, " ✔" if t == profile.threat else "", GameData.threat_intel(t)]
		tb.disabled = t > profile.max_threat
		tb.pressed.connect(func() -> void:
			profile.threat = t
			_act(true))
		_threat_row.add_child(tb)


func _act(changed: bool) -> void:
	if changed:
		profile.save()
		_rebuild()


func _start() -> void:
	profile.save()
	start_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey and event.pressed and not event.echo
			and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]):
		_start()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START:
		_start()
