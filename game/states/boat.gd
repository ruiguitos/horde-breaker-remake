extends Control
## The boat before the first island, on one screen: the chart (left), the
## two routes and the quartermaster's supplies (right), and DEPLOY (bottom
## right), which names where you go and with what. Cards use the shared
## filtered offers. The expedition camp (camp.gd) extends this script: same
## supplies, no routes.
##
## Between islands (island_index > 0, decided by the user on 2026-10-14)
## there is no route choice: the boat draws ONE route with the same draw
## (draw_routes: seeded by the run, no mission twice in a row, biome
## signature weights), shows "NEXT ISLAND IN 5…" and departs on its own.
## The supplies stay (the first useful one is preselected and can be changed
## while the clock runs), hazard pay is a toggle instead of the briefing,
## DEPLOY (or confirm) leaves at once, and Esc / B (leave the run?) holds
## the clock. The camp counts down the same way ("NEXT PART IN 5…").
##
## Selection and focus are separate: LB/RB (or 4/5) pick a route from
## anywhere; up/down move focus between the route row, the supply row and
## DEPLOY; A picks what is focused and moves on to the next row. Route A and
## the first useful supply start selected, so a quick player can deploy at
## once. The supply is applied on DEPLOY, so changing your mind is free.

signal land_requested
signal exit_requested(to_title: bool)

## Supply tile height and route picture height, at the 1152x648 base size.
const SUPPLY_HEIGHT: float = 104.0
const PICTURE_HEIGHT: float = 56.0
## Between islands: seconds before the boat leaves on its own.
const COUNTDOWN_SECONDS: float = GameData.NEXT_ISLAND_COUNTDOWN

var context: RunContext
var _rng := RandomNumberGenerator.new()
var _card_offers: CardOffers
var _card_reroll: Button
## Supplies: title, short (for DEPLOY's sub-line), text, reason (why it
## would do nothing; "" = useful), apply.
var _options: Array[Dictionary] = []
var _buttons: Array[Button] = []  ## supply tiles, same order as _options
var _supply: int = -1  ## selected supply (-1 = none)
var _applied: bool = false
var _land: Button
var _land_title: Label
var _land_sub: Label
var _land_content: Control  ## DEPLOY's labels; their width sizes the button
var _status: Label
var _routes: Array[GameData.Modifier] = []
var _route_buttons: Array[Button] = []
var _route: int = -1  ## selected route (-1 = none)
var _route_biomes: Array[StringName] = []
var _route_missions: Array[StringName] = []
var _map: RouteMap
var _briefing: DialogueBox
var _exit_dialog: MenuDialog
var _exit_sent: bool = false
## The card supply's rerolls: like a level-up screen, one free reroll per
## boat / camp screen (GameData.REROLLS_PER_SCREEN), not banked.
var _supply_rerolls: int = GameData.REROLLS_PER_SCREEN
## Seconds left before departing on its own (-1 = no countdown: the first
## boat waits for DEPLOY).
var countdown_left: float = -1.0
var _countdown_word: String = "ISLAND"
var _heading: Label
var _hazard: Button  ## between islands: hazard pay toggle (the briefing's offer)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = context.island_seed() + 1
	theme = UiTheme.get_theme()
	UiTheme.backdrop(self)
	_make_options()
	_make_routes()
	var transit: bool = in_transit()
	if transit:
		# One route, drawn for the player (route A of the same draw).
		_routes.resize(1)
		_route_biomes.resize(1)
		_route_missions.resize(1)
	var screen := _screen()
	_header(screen, "SALVAGE & CO. / BOAT", "NEXT LANDING / ISLAND %d OF %d" % [context.island_index + 1, RunContext.ISLAND_COUNT])
	var body := _body(screen)
	var chart := _chart_panel(body)
	_map = RouteMap.new()
	_map.biomes = _route_biomes
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chart.add_child(_map)
	chart.move_child(_map, 0)
	var right := _right_column(body)
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 18)
	right.add_child(row)
	for i in _routes.size():
		var card: Button = _route_card(i)
		if transit:
			card.focus_mode = Control.FOCUS_NONE  # nothing to choose
		row.add_child(card)
	if transit:
		right.add_child(_hazard_toggle())
	_supply_row(right)
	_footer(screen, not transit)
	_select_route(0)
	_select_supply(_first_useful())
	if transit:
		_start_countdown("ISLAND")
		_supply_target().grab_focus()
	else:
		_route_buttons[0].grab_focus()
	add_child(UiSfx.new())
	add_child(Ambience.create(&"menu", -12.0))


func _make_routes() -> void:
	for route: Dictionary in draw_routes(context, _rng):
		_routes.append(route["modifier"])
		_route_biomes.append(route["biome"])
		_route_missions.append(route["mission"])


## Between islands: the boat chooses the route and leaves on its own.
func in_transit() -> bool:
	return context.island_index > 0


## The two routes A and B: {modifier: Modifier, biome, mission}. `rng`
## defaults to the boat's own seed (island_seed + 1), so the same run seed
## always draws the same routes. Between islands the boat takes route A.
static func draw_routes(ctx: RunContext, rng: RandomNumberGenerator = null) -> Array[Dictionary]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = ctx.island_seed() + 1
	var mods: Array[GameData.Modifier] = GameData.modifiers()
	var a: int = rng.randi_range(0, mods.size() - 1)
	var b: int = (a + rng.randi_range(1, mods.size() - 1)) % mods.size()
	var picked: Array[GameData.Modifier] = [mods[a], mods[b]]
	var biomes: Array[StringName] = GameData.ISLAND_BIOMES.duplicate()
	# Route missions (not the expedition-only holdout), never the mission
	# just played again: context.mission still holds it after island 1.
	# The biome is drawn first so the mission draw can favour the biome's
	# signature mission (GameData.pick_route_mission: Fuel Run on the Beach,
	# Nests in the Jungle and the Volcano, Intel Search in the Town,
	# Sabotage in the Industrial Port; Light the Signals has no signature
	# biome: weight 1 everywhere).
	var previous: StringName = ctx.mission if ctx.island_index > 0 else &""
	var out: Array[Dictionary] = []
	for i in 2:
		var biome: StringName = &"volcano"
		if not ctx.is_last_island():
			var pick: int = rng.randi_range(0, biomes.size() - 1)
			biome = biomes[pick]
			biomes.remove_at(pick)
		out.append({"modifier": picked[i], "biome": biome,
			"mission": GameData.pick_route_mission(rng, previous, biome)})
	return out


## Starts "NEXT <word> IN 5…" (word: ISLAND, PART).
func _start_countdown(word: String) -> void:
	_countdown_word = word
	countdown_left = COUNTDOWN_SECONDS
	if _heading == null:
		_heading = find_child("Heading", true, false) as Label
	_refresh_countdown()


## "NEXT ISLAND IN 5…": whole seconds, rounded up (5, 4, 3, 2, 1).
func countdown_text() -> String:
	return "NEXT %s IN %d…" % [_countdown_word, maxi(1, ceili(countdown_left))]


func _refresh_countdown() -> void:
	if _heading != null and countdown_left >= 0.0:
		_heading.text = countdown_text()


## True while the clock holds: the leave-the-run dialog is open (the boat's
## pause), or the boat is already leaving.
func countdown_held() -> bool:
	return is_instance_valid(_exit_dialog) or _exit_sent or _applied


## Advances the clock; at zero the boat departs as if DEPLOY was pressed.
func tick_countdown(delta: float) -> void:
	if countdown_left < 0.0 or countdown_held():
		return
	countdown_left = maxf(0.0, countdown_left - delta)
	_refresh_countdown()
	if countdown_left <= 0.0:
		_depart()


func _process(delta: float) -> void:
	tick_countdown(delta)


## Countdown at zero: leave with what is selected (the preselected supply
## if the player picked nothing else).
func _depart() -> void:
	if _applied or _exit_sent:
		return
	if _supply < 0 and _first_useful() >= 0:
		_select_supply(_first_useful())
	_land_now()


## Hazard pay without the briefing: +25% Intel, more enemies, this island
## only (as Briefing.take_hazard_pay; IslandRun clears it when the island ends).
func _hazard_toggle() -> Button:
	_hazard = Button.new()
	_hazard.name = "HazardPay"
	_hazard.toggle_mode = true
	_hazard.button_pressed = context.hazard_pay
	_hazard.add_theme_font_size_override("font_size", 13)
	_hazard.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hazard.toggled.connect(_set_hazard_pay)
	_refresh_hazard()
	return _hazard


func _set_hazard_pay(on: bool) -> void:
	if _applied or _exit_sent or is_instance_valid(_exit_dialog):
		_hazard.set_pressed_no_signal(context.hazard_pay)
		return
	context.hazard_pay = on
	_refresh_hazard()
	_update_land()


func _refresh_hazard() -> void:
	if _hazard == null:
		return
	_hazard.text = "HAZARD PAY · %s  (+%d%% INTEL, MORE ENEMIES)" % ["ON" if context.hazard_pay else "OFF",
		roundi((GameData.HAZARD_INTEL_MULT - 1.0) * 100.0)]
	_hazard.tooltip_text = "Director Hale's offer: more Intel on this island, and the island knows you are coming."


func _make_options() -> void:
	var hurt: bool = context.hp < context.max_hp
	_options.append({"title": "Field Repairs", "short": "Field Repairs",
		"text": "Heal 50 HP (now %d/%d)." % [int(context.hp), int(context.max_hp)],
		"reason": "" if hurt else "HP already full",
		"apply": func() -> void: context.heal(50.0)})
	_options.append({"title": "Ammo Crate", "short": "Ammo Crate",
		"text": "Refill your equipped secondary weapon's ammo.",
		"reason": "Ammo already full" if _ammo_full() else "",
		"apply": func() -> void: context.ammo = PackedInt32Array()})  # empty = full ammo on landing
	_card_offers = CardOffers.new(context.rng_seed)
	if context.card_rng_state != 0:
		_card_offers.rng.state = context.card_rng_state
	_card_offers.blocked_tags = CardOffers.blocked_tags_for(context.perks)
	_options.append(_card_option())


func _card_option(avoid: Array[StringName] = []) -> Dictionary:
	var card: GameData.Card = _card_offers.single(GameData.cards(), context.player_class,
		context.weapons, context.card_stacks, avoid)
	if card == null:
		return {"title": "Training: +20 HP", "short": "+20 HP", "text": "No eligible cards. Recover 20 HP.",
			"reason": "HP already full" if context.hp >= context.max_hp else "",
			"apply": func() -> void: context.heal(20.0)}
	var owned: int = int(context.card_stacks.get(card.id, 0))
	return {"title": "Card: " + card.title, "short": card.title, "card": card,
		"meta": "%s · %s %d/%d" % [String(card.category).replace("_", " ").to_upper(),
			"UPGRADE" if owned > 0 else "NEW", owned + 1, card.max_stacks],
		"text": card.description, "reason": "",
		"apply": func() -> void: context.grant_card(card)}


## One free reroll per screen (its own, not the level-up's, not banked);
## changing supplies never spends a card.
func reroll_supply() -> bool:
	if _applied or _exit_sent or is_instance_valid(_exit_dialog) or _supply_rerolls <= 0 or not _options[2].has("card"):
		return false
	var old: GameData.Card = _options[2]["card"]
	_options[2] = _card_option([old.id])
	_supply_rerolls -= 1
	context.card_rng_state = _card_offers.rng.state
	var b: Button = _buttons[2]
	(b.find_child("SupplyTitle", true, false) as Label).text = _options[2]["title"]
	(b.find_child("Effect", true, false) as Label).text = _options[2]["text"]
	var meta: Label = b.find_child("CardMeta", true, false) as Label
	meta.text = _options[2]["meta"]
	meta.add_theme_color_override("font_color", Hud.category_color((_options[2]["card"] as GameData.Card).category))
	b.tooltip_text = _options[2]["text"]
	b.accessibility_name = "%s: %s" % [_options[2]["title"], _options[2]["text"]]
	_refresh_card_reroll()
	_select_supply(_supply)
	return true


func _refresh_card_reroll() -> void:
	if _card_reroll == null:
		return
	_card_reroll.text = "REROLL CARD · %d · %s" % [_supply_rerolls,
		GameInput.prompt(&"card_reroll", not Input.get_connected_joypads().is_empty())]
	_card_reroll.disabled = _applied or _supply_rerolls <= 0 or not _options[2].has("card")
	_card_reroll.tooltip_text = "Reroll used." if _supply_rerolls <= 0 else "Redraw the card supply (one free reroll here)."


## True when an Ammo Crate would change nothing: every owned weapon that
## uses ammo is at its maximum (the same maximum IslandRun.max_ammo uses,
## before a route's Supply Shortage). Empty ammo = full on landing.
func _ammo_full() -> bool:
	var weapons: Array[GameData.Weapon] = GameData.loadout(context.weapons)
	if context.ammo.size() != weapons.size():
		return true
	for w in weapons.size():
		var most: int = weapons[w].max_ammo
		if most <= 0 or not context.weapons.has(weapons[w].id):
			continue
		most = int(most * (1.0 + 0.15 * context.card_stacks.get(&"bigger_mags", 0)))
		if not weapons[w].primary:
			most = int(most * context.secondary_ammo_mult())
		if context.ammo[w] < most:
			return false
	return true


func _first_useful() -> int:
	for i in _options.size():
		if _options[i]["reason"] == "":
			return i
	return -1


# --- Layout --------------------------------------------------------------------

func _screen() -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 32)
	for edge in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 22)
	add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	return box


## Kicker (left), screen title (centre), progress pips (right), then a line.
func _header(screen: VBoxContainer, kicker: String, heading_text: String) -> void:
	var row := HBoxContainer.new()
	screen.add_child(row)
	var left := UiTheme.label(kicker, 13, UiTheme.MUTED, true)
	left.autowrap_mode = TextServer.AUTOWRAP_OFF
	left.custom_minimum_size.x = 230
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(left)
	var heading := UiTheme.title(heading_text, 32)
	heading.name = "Heading"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(heading)
	var pips := RouteMap.Pips.new(context.island_count(), context.island_index)
	pips.name = "Progress"
	pips.custom_minimum_size.x = maxf(230, pips.custom_minimum_size.x)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pips)
	screen.add_child(HSeparator.new())


func _body(screen: VBoxContainer) -> HBoxContainer:
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 20)
	screen.add_child(body)
	return body


## Left panel: whatever the chart is, with the run status line under it.
func _chart_panel(body: HBoxContainer) -> VBoxContainer:
	var plate := PanelContainer.new()
	plate.custom_minimum_size.x = 300
	plate.add_theme_stylebox_override("panel", _style(UiTheme.PANEL, UiTheme.LINE, 1, 12))
	body.add_child(plate)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	plate.add_child(box)
	_status = UiTheme.label("", 14, UiTheme.MUTED, true)
	_status.name = "Status"
	box.add_child(_status)
	_refresh_status()
	return box


func _right_column(body: HBoxContainer) -> VBoxContainer:
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 14)
	body.add_child(right)
	return right


## One route: picture, "A · JUNGLE" (+ tick when selected), the mission in
## words, then the modifier (▲ penalty) and the Intel multiplier (◆).
func _route_card(i: int) -> Button:
	var biome_name: String = String(GameData.BIOMES[_route_biomes[i]]["name"])
	var mission: Dictionary = GameData.MISSIONS[_route_missions[i]]
	var mod: GameData.Modifier = _routes[i]
	var rb := Button.new()
	rb.name = "Route_%d" % (i + 1)
	rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rb.accessibility_name = "Route %s: %s, %s. %s. %s, Intel ×%.1f" % [RouteMap.LETTERS[i], biome_name, mission["name"], mission["text"], mod.title, mod.intel_mult]
	rb.tooltip_text = "%s: %s" % [mission["name"], mission["text"]]
	rb.pressed.connect(_on_route_pressed.bind(i))
	var card := _card_content(rb, 12)
	var preview := RoutePreview.new()
	preview.biome = _route_biomes[i]
	preview.custom_minimum_size.y = PICTURE_HEIGHT
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL  # spare height goes to the picture
	card.add_child(preview)
	var name_row := HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(name_row)
	var title := UiTheme.title("%s · %s" % [RouteMap.LETTERS[i], biome_name.to_upper()], 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	name_row.add_child(title)
	var mark := _tick_tag("SELECTED")
	mark.name = "SelectionState"
	mark.visible = false
	name_row.add_child(mark)
	card.add_child(_mission_lines(_route_missions[i], mission["text"]))
	card.add_child(HSeparator.new())
	# Calm Waters is no penalty: neutral dot, not a red triangle.
	if mod.id == &"calm":
		card.add_child(_tagged_line("● " + mod.title.to_upper(), UiTheme.TEXT_MUTED, "no modifier"))
	else:
		card.add_child(_tagged_line("▲ " + mod.title.to_upper(), UiTheme.DANGER, mod.description))
	var intel := _tagged_line("◆ INTEL ×%.1f" % mod.intel_mult, UiTheme.ACCENT if mod.intel_mult > 1.0 else UiTheme.TEXT_MUTED,
		"more Intel for the risk" if mod.intel_mult > 1.0 else "standard pay")
	card.add_child(intel)
	_route_buttons.append(rb)
	return rb


## Mission chip (INFO colour) and the one plain sentence of what to do.
func _mission_lines(mission: StringName, text: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Mission"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var chip := UiTheme.label("● " + Expeditions.mission_name(mission).to_upper(), 13, UiTheme.INFO)
	chip.add_theme_font_override("font", UiTheme.mono_bold_font())
	chip.name = "MissionName"
	box.add_child(chip)
	var about := UiTheme.label(text, 16)
	about.name = "MissionText"
	box.add_child(about)
	return box


## "▲ SEA FOG · you see enemies late": coloured mono tag, plain explanation.
func _tagged_line(tag: String, color: Color, text: String) -> RichTextLabel:
	var line := RichTextLabel.new()
	line.fit_content = true
	line.scroll_active = false
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.focus_mode = Control.FOCUS_NONE
	line.push_font(UiTheme.mono_bold_font(), 13)
	line.push_color(color)
	line.add_text(tag)
	line.pop()
	line.pop()
	line.push_font(UiTheme.body_font(), 14)
	line.add_text("  · " + text)
	line.pop()
	return line


## Tick + word, in the "selected" colour.
func _tick_tag(text: String) -> HBoxContainer:
	var tag := HBoxContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_theme_constant_override("separation", 4)
	var icon := TextureRect.new()
	icon.texture = UiTheme.tick_icon()
	icon.modulate = UiTheme.SUCCESS
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tag.add_child(icon)
	if text != "":
		var word := UiTheme.label(text, 12, UiTheme.SUCCESS)
		word.add_theme_font_override("font", UiTheme.mono_bold_font())
		word.autowrap_mode = TextServer.AUTOWRAP_OFF
		word.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_child(word)
	return tag


## A margin + VBox laid over a Button, so a card can hold several labels.
func _card_content(b: Button, pad: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, pad)
	b.add_child(margin)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return box


## "QUARTERMASTER / ONE SUPPLY PER LANDING" and the supply tiles. A supply
## that would do nothing is disabled (dashed) and says why.
func _supply_row(parent: VBoxContainer, caption: String = "QUARTERMASTER / ONE SUPPLY PER LANDING") -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	parent.add_child(box)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var head := UiTheme.label(caption, 12, UiTheme.MUTED, true)
	head.name = "SupplyCaption"
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(head)
	_card_reroll = Button.new()
	_card_reroll.name = "CardReroll"
	_card_reroll.add_theme_font_size_override("font_size", 12)
	_card_reroll.pressed.connect(reroll_supply)
	heading.add_child(_card_reroll)
	_refresh_card_reroll()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for i in _options.size():
		var option: Dictionary = _options[i]
		var useless: bool = option["reason"] != ""
		var b := Button.new()
		b.name = "Supply_%d" % (i + 1)
		b.custom_minimum_size.y = SUPPLY_HEIGHT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.disabled = useless
		b.focus_mode = Control.FOCUS_NONE if useless else Control.FOCUS_ALL
		b.tooltip_text = option["reason"] if useless else option["text"]
		b.accessibility_name = "%s: %s" % [option["title"], option["reason"] if useless else option["text"]]
		b.pressed.connect(_on_supply_pressed.bind(i))
		var card := _card_content(b, 10)
		card.add_theme_constant_override("separation", 2)
		var title_row := HBoxContainer.new()
		title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_row.add_theme_constant_override("separation", 6)
		card.add_child(title_row)
		var mark := _tick_tag("")
		mark.name = "SelectionState"
		mark.visible = false
		title_row.add_child(mark)
		var title := UiTheme.label(option["title"], 20, UiTheme.TEXT_MUTED if useless else UiTheme.TEXT)
		title.name = "SupplyTitle"
		title.add_theme_font_override("font", UiTheme.heading_font())
		title.autowrap_mode = TextServer.AUTOWRAP_OFF
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_row.add_child(title)
		if option.has("meta"):
			var meta := UiTheme.label(option["meta"], 11, Hud.category_color((option["card"] as GameData.Card).category), true)
			meta.name = "CardMeta"
			card.add_child(meta)
		var text := UiTheme.label(option["reason"] if useless else option["text"], 14, UiTheme.TEXT_MUTED if useless else UiTheme.TEXT)
		text.name = "Reason" if useless else "Effect"
		text.max_lines_visible = 2
		text.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		card.add_child(text)
		row.add_child(b)
		_buttons.append(b)


## Hints from the real bindings (left) and the primary button (right).
func _footer(screen: VBoxContainer, routes: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	screen.add_child(row)
	var hints := HBoxContainer.new()
	hints.name = "Hints"
	hints.add_theme_constant_override("separation", 16)
	hints.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(hints)
	var pad: bool = not Input.get_connected_joypads().is_empty()
	if routes:
		_hint(hints, [_key_name(&"menu_route_1", pad), _key_name(&"menu_route_2", pad)], "ROUTE")
	_hint(hints, ["D-PAD" if pad else "↑↓←→"], "MOVE")
	_hint(hints, [_key_name(&"ui_accept", pad)], "CHOOSE")
	var back := UiTheme.button(hints, "%s BACK" % _key_name(&"ui_cancel", pad), _back)
	back.name = "Back"
	back.focus_mode = Control.FOCUS_NONE  # Escape/B is the keyboard/pad equivalent.
	back.custom_minimum_size.y = 32
	back.add_theme_font_size_override("font_size", 13)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	_land = Button.new()
	_land.name = "Deploy"
	_land.theme_type_variation = &"PrimaryButton"
	_land.custom_minimum_size = Vector2(400, 56)
	_land.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_land.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_land.pressed.connect(_land_now)
	row.add_child(_land)
	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 14)
	_land.add_child(margin)
	_land_content = margin
	var inner := HBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(inner)
	var words := VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.add_theme_constant_override("separation", 0)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(words)
	_land_title = UiTheme.label("", 26, UiTheme.ON_ACCENT)
	_land_title.name = "DeployTitle"
	_land_title.add_theme_font_override("font", UiTheme.title_font())
	_land_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(_land_title)
	_land_sub = UiTheme.label("", 14, UiTheme.ON_ACCENT)
	_land_sub.name = "DeploySub"
	_land_sub.add_theme_font_override("font", UiTheme.body_bold_font())
	_land_sub.autowrap_mode = TextServer.AUTOWRAP_OFF
	words.add_child(_land_sub)
	var key := UiTheme.label(_key_name(&"ui_accept", pad), 14, UiTheme.ACCENT)
	key.name = "DeployKey"
	key.add_theme_font_override("font", UiTheme.mono_bold_font())
	key.add_theme_stylebox_override("normal", _style(UiTheme.ON_ACCENT, UiTheme.ON_ACCENT, 0, 6, 12))
	key.autowrap_mode = TextServer.AUTOWRAP_OFF
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	inner.add_child(key)


## One hint: keycaps then a word ("[LB] [RB] ROUTE").
func _hint(parent: HBoxContainer, keys: Array, word: String) -> void:
	var hint := HBoxContainer.new()
	hint.add_theme_constant_override("separation", 6)
	parent.add_child(hint)
	for k: String in keys:
		var cap := Label.new()
		cap.theme_type_variation = &"KeyLabel"
		cap.text = k
		cap.add_theme_font_size_override("font_size", 13)
		cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hint.add_child(cap)
	var label := UiTheme.label(word, 13, UiTheme.MUTED, true)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	hint.add_child(label)


## Short name of the first binding of `action` for the device in use:
## gamepad button (LB, A…) when a pad is connected, else the key.
func _key_name(action: StringName, pad: bool) -> String:
	var bindings: Array = GameInput.ACTIONS.get(action, [])
	if bindings.is_empty() and InputMap.has_action(action):
		for e: InputEvent in InputMap.action_get_events(action):
			if pad and e is InputEventJoypadButton:
				return _pad_name((e as InputEventJoypadButton).button_index)
			if not pad and e is InputEventKey:
				var k := e as InputEventKey
				var code: Key = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
				return "ESC" if code == KEY_ESCAPE else OS.get_keycode_string(code).to_upper()
	for b: Variant in bindings:
		if pad and b is String and String(b).begins_with("joy:"):
			return _pad_name(int(String(b).get_slice(":", 1)))
		if not pad and b is int:
			return OS.get_keycode_string(b).to_upper()
	# ui_* actions: GameInput only adds the pad side; the keys are Godot's.
	if action == &"ui_accept":
		return "A" if pad else "ENTER"
	if action == &"ui_cancel":
		return "B" if pad else "ESC"
	return "?"


static func _pad_name(button: int) -> String:
	match button:
		JOY_BUTTON_A: return "A"
		JOY_BUTTON_B: return "B"
		JOY_BUTTON_X: return "X"
		JOY_BUTTON_Y: return "Y"
		JOY_BUTTON_LEFT_SHOULDER: return "LB"
		JOY_BUTTON_RIGHT_SHOULDER: return "RB"
		JOY_BUTTON_START: return "START"
		JOY_BUTTON_BACK: return "VIEW"
	return "PAD %d" % button


static func _style(bg: Color, border: Color, width: int, pad: int, radius: int = UiTheme.RADIUS) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	return s


## Card look by state: selected = 2 px outline (`selected_color`) on a
## raised panel; otherwise panel + line, lit outline on hover. Focus keeps
## the theme's brackets; disabled keeps the theme's dashed box.
func _paint(b: Button, selected: bool, selected_color: Color) -> void:
	var base: StyleBoxFlat
	var hover: StyleBoxFlat
	if selected:
		base = _style(UiTheme.PANEL_RAISED, selected_color, 2, 0)
		hover = _style(UiTheme.PANEL_RAISED.lightened(0.05), selected_color, 2, 0)
	else:
		base = _style(UiTheme.PANEL, UiTheme.LINE, 1, 0)
		hover = _style(UiTheme.PANEL_RAISED, UiTheme.TEXT, 1, 0)
	b.add_theme_stylebox_override("normal", base)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", base)
	b.add_theme_stylebox_override("hover_pressed", hover)
	var mark: Control = b.find_child("SelectionState", true, false) as Control
	if mark != null:
		mark.visible = selected


# --- Choices and focus ---------------------------------------------------------

func _on_route_pressed(i: int) -> void:
	_pick_route(i)
	_supply_target().grab_focus()


func _on_supply_pressed(i: int) -> void:
	_pick(i)


## Selects supply `i` (if it would do something) and moves focus to DEPLOY.
## Applied on DEPLOY, not here.
func _pick(i: int) -> void:
	if _applied or _exit_sent or is_instance_valid(_exit_dialog) or not _select_supply(i):
		return
	if is_inside_tree():
		_land.grab_focus()


func _select_supply(i: int) -> bool:
	if i < 0 or i >= _options.size() or _options[i]["reason"] != "":
		return false
	_supply = i
	for k in _buttons.size():
		if not _buttons[k].disabled:
			_paint(_buttons[k], k == i, UiTheme.SUCCESS)
	_update_land()
	return true


## Selects route `i` (LB/RB, 4/5, or A on its card). Focus does not move.
func _pick_route(i: int) -> void:
	if _applied or _exit_sent or is_instance_valid(_exit_dialog):
		return
	_select_route(i)


func _select_route(i: int) -> void:
	if i < 0 or i >= _routes.size():
		return
	_route = i
	context.modifier = _routes[i].id
	context.biome = _route_biomes[i]
	context.mission = _route_missions[i]
	_map.selected = i
	for k in _route_buttons.size():
		_paint(_route_buttons[k], k == i, UiTheme.ACCENT)
	_update_land()


func _useful_supplies() -> Array[Button]:
	var out: Array[Button] = []
	for b in _buttons:
		if not b.disabled:
			out.append(b)
	return out


## Where "down" from the routes (or "back" from DEPLOY) lands.
func _supply_target() -> Control:
	if _supply >= 0:
		return _buttons[_supply]
	var useful := _useful_supplies()
	return useful[0] if not useful.is_empty() else _land


func _route_target() -> Control:
	return _route_buttons[maxi(_route, 0)] if not _route_buttons.is_empty() else null


## Focus neighbours: routes (left/right) -> supplies (left/right) -> DEPLOY.
## Rewired after each choice so "down" goes to what is selected.
func _wire_focus() -> void:
	var supplies := _useful_supplies()
	var up_from_supplies: Control = _route_target()
	var order: Array[Control] = []
	for b in _route_buttons:
		order.append(b)
	for b in supplies:
		order.append(b)
	if not _card_reroll.disabled:
		order.append(_card_reroll)
		_card_reroll.focus_neighbor_top = _card_reroll.get_path_to(up_from_supplies if up_from_supplies != null else _supply_target())
		_card_reroll.focus_neighbor_bottom = _card_reroll.get_path_to(_supply_target())
	order.append(_land)
	for row: Array in [_route_buttons, supplies]:
		for k in row.size():
			var b: Control = row[k]
			b.focus_neighbor_left = b.get_path_to(row[posmod(k - 1, row.size())])
			b.focus_neighbor_right = b.get_path_to(row[(k + 1) % row.size()])
	for b in _route_buttons:
		b.focus_neighbor_top = b.get_path_to(b)
		b.focus_neighbor_bottom = b.get_path_to(_supply_target())
	var below_supplies: Control = _hazard if _hazard != null else _land
	for b in supplies:
		b.focus_neighbor_top = b.get_path_to(up_from_supplies if up_from_supplies != null else b)
		b.focus_neighbor_bottom = b.get_path_to(below_supplies)
	var above: Control = _supply_target()
	if above == _land:
		above = up_from_supplies if up_from_supplies != null else _land
	if _hazard != null:
		order.insert(order.size() - 1, _hazard)
		_hazard.focus_neighbor_top = _hazard.get_path_to(above)
		_hazard.focus_neighbor_bottom = _hazard.get_path_to(_land)
		_hazard.focus_neighbor_left = _hazard.get_path_to(_hazard)
		_hazard.focus_neighbor_right = _hazard.get_path_to(_hazard)
		above = _hazard
	_land.focus_neighbor_top = _land.get_path_to(above)
	_land.focus_neighbor_bottom = _land.get_path_to(_land)
	_land.focus_neighbor_left = _land.get_path_to(_land)
	_land.focus_neighbor_right = _land.get_path_to(_land)
	for k in order.size():
		order[k].focus_next = order[k].get_path_to(order[(k + 1) % order.size()])
		order[k].focus_previous = order[k].get_path_to(order[posmod(k - 1, order.size())])


## B / Esc: choose whether to stay or end the run at the Armory/title.
func _back() -> void:
	if _applied or _exit_sent or is_instance_valid(_exit_dialog) or is_instance_valid(_briefing):
		return
	_exit_dialog = MenuDialog.new()
	_exit_dialog.name = "RunExitDialog"
	add_child(_exit_dialog)
	_exit_dialog.content.add_child(UiTheme.title("LEAVE THE RUN?", 36))
	var note := UiTheme.label("Returning to the Armory or main menu ends this run. Your level, cards and build are lost.", 18)
	_exit_dialog.content.add_child(note)
	var intel := UiTheme.label("You keep %d Intel earned so far. The extraction bonus is not awarded." % context.intel, 18, UiTheme.SUCCESS)
	intel.name = "ExitConsequences"
	_exit_dialog.content.add_child(intel)
	var keep := UiTheme.button(_exit_dialog.content, "KEEP PLAYING", _exit_dialog.close, true)
	keep.name = "KeepPlaying"
	var armory := UiTheme.button(_exit_dialog.content, "RETURN TO ARMORY / CLASSES", _request_exit.bind(false))
	armory.name = "ReturnToArmory"
	var title := UiTheme.button(_exit_dialog.content, "MAIN MENU", _request_exit.bind(true))
	title.name = "ReturnToTitle"
	_exit_dialog.content.add_child(UiTheme.label("ESC / B: stay in this run", 14, UiTheme.MUTED, true))


func _request_exit(to_title: bool) -> void:
	if _exit_sent or _applied or not is_instance_valid(_exit_dialog):
		return
	_exit_sent = true
	_exit_dialog.close()
	exit_requested.emit(to_title)


func _update_land() -> void:
	if _land == null:
		return
	_land.disabled = not _can_land()
	_land_title.text = _land_text()
	_land_sub.text = _land_detail()
	_land_title.add_theme_color_override("font_color", UiTheme.TEXT_MUTED if _land.disabled else UiTheme.ON_ACCENT)
	_land_sub.add_theme_color_override("font_color", UiTheme.TEXT_MUTED if _land.disabled else UiTheme.ON_ACCENT)
	_land.accessibility_name = "%s, %s" % [_land_title.text, _land_sub.text]
	# A Button does not grow with its children: size it to the longest text.
	_land.custom_minimum_size.x = maxf(400, _land_content.get_combined_minimum_size().x)
	_wire_focus()


## A supply must be chosen, unless none would do anything.
func _supply_ready() -> bool:
	return _supply >= 0 or _first_useful() < 0


func _can_land() -> bool:
	return _route >= 0 and _supply_ready()


func _land_text() -> String:
	if _route < 0:
		return "CHOOSE A ROUTE"
	var place: String = String(GameData.BIOMES[_route_biomes[_route]]["name"]).to_upper()
	return ("DEPART NOW TO " if in_transit() else "DEPLOY TO ") + place


## "<mission> · with <supply>".
func _land_detail() -> String:
	var what: String = Expeditions.mission_name(context.mission) if _route >= 0 or _routes.is_empty() else "Pick a route"
	if context.hazard_pay and _hazard != null:
		what += " · hazard pay"
	if _supply >= 0:
		return "%s · with %s" % [what, _options[_supply]["short"]]
	return "%s · %s" % [what, "no supply needed" if _supply_ready() else "choose a supply"]


func _apply_supply() -> void:
	if _applied:
		return
	_applied = true
	context.card_rng_state = _card_offers.rng.state
	if _supply >= 0:
		(_options[_supply]["apply"] as Callable).call()
	_refresh_status()
	_refresh_card_reroll()


## DEPLOY: apply the supply, then Director Hale's briefing (Dialogue
## Manager), then land. Between islands there is no briefing (the boat
## leaves on a clock; hazard pay is the toggle): it lands straight away.
func _land_now() -> void:
	if not _can_land() or _applied or _exit_sent or is_instance_valid(_exit_dialog):
		return  # also stops a second press while the briefing is open
	_apply_supply()
	if in_transit():
		land_requested.emit()
		return
	var dialogue: Resource = load(Briefing.RESOURCE) if ResourceLoader.exists(Briefing.RESOURCE) else null
	if dialogue == null or get_node_or_null("/root/DialogueManager") == null:
		land_requested.emit()  # addon missing: land straight away
		return
	_briefing = DialogueBox.open(self, dialogue, "start", [{"briefing": Briefing.new(context)}])
	_briefing.finished.connect(func() -> void: land_requested.emit())


func _refresh_status() -> void:
	if _status != null:
		_status.text = "HP %d/%d · LVL %d · INTEL %d" % [int(context.hp), int(context.max_hp), context.level, context.intel]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or is_instance_valid(_briefing):
		return
	if event.is_action_pressed(&"ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"card_reroll"):
		reroll_supply()
		get_viewport().set_input_as_handled()
		return
	# Number keys pick a supply; the pad's X/Y/B (also bound to card_N) do
	# not, so B only ever means "back" here.
	if event is InputEventKey:
		for i in 3:
			if event.is_action_pressed(StringName("card_%d" % (i + 1))):
				_pick(i)
				get_viewport().set_input_as_handled()
				return
	for i in _routes.size():
		if event.is_action_pressed(StringName("menu_route_%d" % (i + 1))):
			_pick_route(i)
			get_viewport().set_input_as_handled()
			return
	if event.is_action_pressed(&"confirm") and _can_land():
		get_viewport().set_input_as_handled()
		_land_now()
