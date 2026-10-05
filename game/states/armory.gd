extends Control
## Between runs: spend Intel on perks and slots, equip perks, pick the Threat
## level and start a run. Unlocks are horizontal (new options, small bonuses)
## as in docs/design/PROGRESSION_AND_ECONOMY.md §3.

signal start_requested

var profile: Profile

var _list: VBoxContainer
var _header: Label
var _threat_row: HBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	var bg := ColorRect.new()
	bg.color = Color(0.12, 0.13, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(720, 0)
	box.add_theme_constant_override("separation", 10)
	center.add_child(box)
	var title := Label.new()
	title.text = "ARMORY"
	title.add_theme_font_size_override("font_size", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_header = Label.new()
	_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_header)
	_list = VBoxContainer.new()
	box.add_child(_list)
	var threat_label := Label.new()
	threat_label.text = "Threat (extract on your highest Threat to unlock the next):"
	box.add_child(threat_label)
	_threat_row = HBoxContainer.new()
	box.add_child(_threat_row)
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
