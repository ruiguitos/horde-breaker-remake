extends SceneTree
## Boat and camp on one screen (MENUS.md, October 2026 redesign): no supply
## modal over the routes, useless supplies disabled with a reason, DEPLOY
## names the destination, LB/RB pick routes, focus goes routes -> supplies
## -> DEPLOY, B opens the exit choices and never picks a supply, the supply is applied
## on DEPLOY, and the camp shows the next expedition part.

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("TEST FAIL: " + message)


func _settle() -> void:
	await process_frame
	await process_frame


func _press(event: InputEvent) -> void:
	event.set("pressed", true)
	Input.parse_input_event(event)
	await _settle()


func _pad(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = button
	return e


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	return e


func _open(script: String, context: RunContext) -> Control:
	var screen := Control.new()
	screen.set_script(load(script))
	screen.set("context", context)
	root.add_child(screen)
	await _settle()
	return screen


func _text(screen: Node, node_name: String) -> String:
	var l: Label = screen.find_child(node_name, true, false) as Label
	return l.text if l != null else "<missing %s>" % node_name


func _run_tests() -> void:
	await _fresh_boat()
	await _hurt_boat()
	await _camp()
	await create_timer(0.1).timeout  # let the audio mixer release UI playbacks
	print("TEST: boat redesign %d checks / %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## First landing: full HP, full ammo, so only the card is worth taking.
func _fresh_boat() -> void:
	var context := RunContext.new(7)
	var boat: Control = await _open("res://game/states/boat.gd", context)
	var routes: Array = boat.get("_route_buttons")
	var supplies: Array = boat.get("_buttons")
	var land: Button = boat.get("_land")
	var view: Rect2 = root.get_visible_rect()
	# One screen: routes, supplies and DEPLOY are all visible at once.
	var all_visible: bool = true
	for c: Control in routes + supplies + [land]:
		all_visible = all_visible and c.is_visible_in_tree() and view.encloses(c.get_global_rect())
	_check(all_visible, "routes, supplies and DEPLOY are visible together on one screen")
	_check(boat.get("_supplies") == null and boat.find_children("*", "CenterContainer", true, false).is_empty(), "no supply modal over the routes")
	_check(not routes[0].get_global_rect().intersects(supplies[0].get_global_rect()), "route cards and supply tiles do not overlap")
	_check(supplies.size() == 3, "three supplies offered (got %d)" % supplies.size())
	_check(supplies[0].disabled and _text(supplies[0], "Reason") == "HP already full", "Field Repairs disabled at full HP, with the reason")
	_check(supplies[1].disabled and _text(supplies[1], "Reason") == "Ammo already full", "Ammo Crate disabled with full ammo, with the reason")
	_check(supplies[0].focus_mode == Control.FOCUS_NONE, "a disabled supply cannot take focus")
	_check(not supplies[2].disabled and int(boat.get("_supply")) == 2, "the first useful supply (the card) is preselected")
	_check(_text(supplies[2], "Effect") != "" and String((boat.get("_options") as Array)[2]["title"]).begins_with("Card: "), "the card supply shows its name and effect")
	boat.call("_pick", 0)
	_check(int(boat.get("_supply")) == 2, "a useless supply cannot be picked")
	# DEPLOY names the destination and the choices.
	var biomes: Array = boat.get("_route_biomes")
	var first: String = String(GameData.BIOMES[biomes[0]]["name"]).to_upper()
	_check(_text(boat, "DeployTitle") == "DEPLOY TO " + first, "DEPLOY names route A's island (%s)" % _text(boat, "DeployTitle"))
	var card: String = String((boat.get("_options") as Array)[2]["short"])
	var sub: String = _text(boat, "DeploySub")
	_check(sub == "%s · with %s" % [Expeditions.mission_name(context.mission), card], "DEPLOY's sub-line is '<mission> · with <supply>' (%s)" % sub)
	_check(not land.disabled and boat.call("_can_land"), "with route A and the card preselected, DEPLOY is ready")
	# Focus: starts on route A; down -> selected supply -> DEPLOY.
	_check(root.gui_get_focus_owner() == routes[0], "focus opens on route A")
	await _press(_key(KEY_DOWN))
	_check(root.gui_get_focus_owner() == supplies[2], "down from the routes goes to the selected supply")
	await _press(_key(KEY_DOWN))
	_check(root.gui_get_focus_owner() == land, "down from the supplies goes to DEPLOY")
	await _press(_pad(JOY_BUTTON_B))
	var dialog: MenuDialog = boat.get("_exit_dialog")
	_check(is_instance_valid(dialog), "B opens the exit menu from DEPLOY")
	_check(int(boat.get("_supply")) == 2, "B never picks a supply (card_3 is ignored from the pad)")
	await _press(_pad(JOY_BUTTON_B))
	_check(root.gui_get_focus_owner() == land, "B closes the exit menu and restores DEPLOY focus")
	await _press(_key(KEY_UP))
	_check(root.gui_get_focus_owner() == supplies[2], "up from DEPLOY returns to the supplies")
	await _press(_key(KEY_UP))
	_check(root.gui_get_focus_owner() == routes[0], "up from the supplies returns to the routes")
	# LB/RB switch routes without moving focus.
	await _press(_pad(JOY_BUTTON_RIGHT_SHOULDER))
	_check(int(boat.get("_route")) == 1 and context.biome == biomes[1], "RB selects route B")
	_check(root.gui_get_focus_owner() == routes[0], "RB does not move focus")
	_check(_text(boat, "DeployTitle") == "DEPLOY TO " + String(GameData.BIOMES[biomes[1]]["name"]).to_upper(), "DEPLOY follows the selected route")
	_check((routes[1].find_child("SelectionState", true, false) as Control).visible and not (routes[0].find_child("SelectionState", true, false) as Control).visible, "only the selected route shows the tick")
	await _press(_pad(JOY_BUTTON_LEFT_SHOULDER))
	_check(int(boat.get("_route")) == 0, "LB selects route A")
	await _press(_key(KEY_RIGHT))
	_check(root.gui_get_focus_owner() == routes[1], "right moves focus along the route row")
	routes[1].pressed.emit()
	await _settle()
	_check(int(boat.get("_route")) == 1 and root.gui_get_focus_owner() == supplies[2], "choosing a route card moves on to the supplies")
	boat.queue_free()
	await _settle()


## Later landing: hurt and short of ammo, so every supply is useful; the
## supply is applied on DEPLOY only.
func _hurt_boat() -> void:
	var context := RunContext.new(11)
	context.island_index = 1
	context.hp = 20.0
	var weapons: Array[GameData.Weapon] = GameData.weapons()
	var ammo := PackedInt32Array()
	var spent: bool = false
	for w in weapons:
		ammo.append(w.max_ammo)
		if not spent and w.max_ammo > 0:
			ammo[ammo.size() - 1] = w.max_ammo / 2
			if not context.weapons.has(w.id):
				context.weapons.append(w.id)
			spent = true
	context.ammo = ammo
	var boat: Control = await _open("res://game/states/boat.gd", context)
	var supplies: Array = boat.get("_buttons")
	_check(not supplies[0].disabled and not supplies[1].disabled, "Field Repairs and Ammo Crate are offered when they help")
	_check(int(boat.get("_supply")) == 0, "Field Repairs is preselected when hurt")
	boat.call("_pick", 1)
	_check(int(boat.get("_supply")) == 1 and root.gui_get_focus_owner() == boat.get("_land"), "picking a supply selects it and focuses DEPLOY")
	_check((supplies[1].find_child("SelectionState", true, false) as Control).visible, "the selected supply shows the tick")
	boat.call("_pick", 0)
	_check(context.hp == 20.0, "choosing a supply does not apply it yet")
	boat.call("_land_now")
	await _settle()
	_check(context.hp == 70.0, "DEPLOY applies the chosen supply (HP %d)" % int(context.hp))
	boat.call("_land_now")
	_check(context.hp == 70.0, "the supply applies once")
	boat.queue_free()
	await _settle()


## Camp between expedition parts: same layout, the next part instead of routes.
func _camp() -> void:
	var context := RunContext.new(5)
	_check(context.start_expedition(&"berlenga", 0), "Berlenga expedition starts")
	context.advance()
	context.hp = 50.0
	var camp: Control = await _open("res://game/states/camp.gd", context)
	var part: String = String(Expeditions.parts(&"berlenga")[1]["name"])
	_check(_text(camp, "PartName") == part.to_upper(), "the camp names the next part (%s)" % _text(camp, "PartName"))
	_check(_text(camp, "MissionText") == String(GameData.MISSIONS[context.mission]["text"]), "the next part's mission is written out")
	_check(camp.find_child("Trail_1", true, false) != null and camp.find_child("Trail_4", true, false) != null, "the chart lists the 4 parts")
	_check(camp.find_child("Route_1", true, false) == null, "the camp has no routes")
	_check(_text(camp, "DeployTitle") == "CONTINUE TO " + part.to_upper(), "the button names the next part (%s)" % _text(camp, "DeployTitle"))
	var supplies: Array = camp.get("_buttons")
	_check(root.gui_get_focus_owner() == supplies[0], "focus opens on the preselected supply")
	await _press(_key(KEY_DOWN))
	_check(root.gui_get_focus_owner() == camp.get("_land"), "down from the supplies goes to CONTINUE")
	await _press(_key(KEY_ESCAPE))
	var dialog: MenuDialog = camp.get("_exit_dialog")
	_check(is_instance_valid(dialog), "Escape opens exit choices in a camp without routes")
	if is_instance_valid(dialog):
		var keep: Button = dialog.find_child("KeepPlaying", true, false)
		_check(root.gui_get_focus_owner() == keep, "keep playing is focused when exit choices open")
		_check(dialog.find_child("ReturnToArmory", true, false) != null
			and dialog.find_child("ReturnToTitle", true, false) != null, "camp offers both classes and the main menu")
		var before: int = context.rerolls
		await _press(_key(KEY_R))
		await _press(_key(KEY_3))
		_check(context.rerolls == before and context.hp == 50.0 and not bool(camp.get("_applied")),
			"exit choices block rerolls, supply selection and deployment behind the dialog")
		await _press(_key(KEY_ESCAPE))
		_check(root.gui_get_focus_owner() == camp.get("_land") and not is_instance_valid(camp.get("_exit_dialog")),
			"Escape closes exit choices and restores the camp without ending the run")
		# A visible Back button gives mouse users the same choices.
		var back: Button = camp.find_child("Back", true, false)
		_check(back != null, "camp has a clickable Back button")
		if back != null:
			back.pressed.emit()
			await _settle()
			_check(is_instance_valid(camp.get("_exit_dialog")), "clicking Back opens the same exit choices")
	camp.queue_free()
	await _settle()
