extends SceneTree
## Regression coverage for purchases, route gates, modal isolation and focus.

class MemoryProfile extends Profile:
	var saves: int = 0
	func save(_path: String = Profile.PATH) -> bool:
		saves += 1
		return true

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


func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)


func _run_tests() -> void:
	var profile := MemoryProfile.new()
	profile.intel = 150
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	await _settle()
	var start: Button = armory.get("_start_button")
	_check(root.get_visible_rect().encloses(start.get_global_rect()), "Start Run fits viewport")
	armory.call("_choose_class", &"vanguard")
	await _settle()
	_check(profile.selected_class == &"vanguard" and profile.intel == 0, "class purchase selects and charges once")
	armory.call("_choose_class", &"vanguard")
	_check(profile.intel == 0, "owned class is not charged twice")
	_check(armory.find_child("Class_medic", true, false) == null, "Field Medic class is gone")
	profile.intel = 80
	armory.call("_select_category", "PERKS")
	await _settle()
	var node: Button = armory.find_child("PerkNode_survival_1", true, false) as Button
	node.grab_focus()
	await _settle()
	node.pressed.emit()
	await _settle()
	# A on a new node buys its rank I at once (one click); it never equips.
	_check(profile.node_rank(&"survival_1") == 1 and profile.intel == 40 and profile.equipped_perks.is_empty(),
		"A on a new perk node buys its rank I with the existing economy and never equips")
	# A on the owned node opens its actions: the next rank is out of reach with 40 Intel, so equip has the focus.
	node = armory.find_child("PerkNode_survival_1", true, false) as Button
	node.pressed.emit()
	await _settle()
	var upgrade: Button = armory.find_child("PerkUpgrade", true, false) as Button
	var equip: Button = armory.find_child("PerkEquip", true, false) as Button
	_check(upgrade != null and upgrade.disabled and root.gui_get_focus_owner() == equip,
		"A on an owned perk node focuses its first available action (equip)")
	equip.pressed.emit()
	await _settle()
	_check(profile.equipped_perks == [&"thick_skin"], "owned perk equips")
	profile.perk_ranks[&"combat_1"] = 1
	armory.call("_rebuild")
	await _settle()
	(armory.find_child("PerkNode_combat_1", true, false) as Button).grab_focus()
	await _settle()
	equip = armory.find_child("PerkEquip", true, false) as Button
	_check(equip.disabled and equip.text == "SLOTS FULL", "full slots prevent additional equipment")
	start = armory.get("_start_button")
	start.grab_focus()
	var saves_before: int = profile.saves
	var nav_texts: Array = armory.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	_check(not nav_texts.has("SETTINGS"), "Armory no longer has a Settings tab")
	armory.set("_dialog", MenuDialog.settings(armory, profile))
	await _settle()
	var dialog: MenuDialog = armory.get("_dialog")
	var focus := root.gui_get_focus_owner()
	_check(dialog.is_ancestor_of(focus), "settings take focus")
	_check(dialog.is_ancestor_of(focus.get_node(focus.focus_next)), "settings focus cycles inside modal")
	_key(KEY_ESCAPE)
	await _settle()
	_check(not is_instance_valid(dialog), "Escape closes settings")
	_check(profile.saves == saves_before + 1, "settings save on close")
	_check(root.gui_get_focus_owner() == start, "settings restore prior focus")
	# The Armory no longer carries the archive: the title screen does.
	armory.set("_dialog", MenuDialog.archive(armory, profile))
	await _settle()
	dialog = armory.get("_dialog")
	var archive_scroll: ScrollContainer = dialog.find_children("*", "ScrollContainer", true, false)[0] as ScrollContainer
	var read_more: Button = dialog.find_child("ScrollDown", true, false) as Button
	read_more.pressed.emit()
	await _settle()
	_check(archive_scroll.scroll_vertical > 0, "archive can scroll via a native controller-accessible button")
	_key(KEY_ESCAPE)
	await _settle()
	_check(not is_instance_valid(dialog), "archive closes without triggering underlying menu")
	armory.queue_free()
	await _settle()
	var context := RunContext.new(7)
	context.hp = 20
	var boat := Control.new()
	boat.set_script(load("res://game/states/boat.gd"))
	boat.set("context", context)
	root.add_child(boat)
	await _settle()
	# One screen (no supply modal): route A and the first useful supply start
	# selected; the supply is applied on DEPLOY (tests/test_boat_redesign.gd).
	_check(boat.call("_can_land") and int(boat.get("_supply")) == 0, "hurt: Field Repairs preselected, ready to land")
	boat.call("_pick", 0)
	await _settle()
	_check(context.hp == 20, "choosing a supply does not apply it yet")
	boat.call("_pick_route", 1)
	var biomes: Array = boat.get("_route_biomes")
	_check(context.biome == biomes[1], "route updates run context")
	var route_buttons: Array = boat.get("_route_buttons")
	var selection: Control = route_buttons[1].find_child("SelectionState", true, false) as Control
	_check(selection.visible and route_buttons[1].get_global_rect().encloses(selection.get_global_rect()), "route selection fits its card")
	boat.call("_land_now")
	await _settle()
	_check(context.hp == 70, "supply applies on landing")
	boat.call("_land_now")
	_check(context.hp == 70, "supply applies once")
	boat.queue_free()
	await _settle()
	context = RunContext.new(9)
	context.island_index = RunContext.ISLAND_COUNT - 1
	for card in GameData.cards():
		context.card_stacks[card.id] = card.max_stacks
	boat = Control.new()
	boat.set_script(load("res://game/states/boat.gd"))
	boat.set("context", context)
	root.add_child(boat)
	await _settle()
	_check((boat.get("_buttons") as Array).size() == 3 and (boat.get("_buttons") as Array)[2].disabled, "maxed cards at full HP disable the healing fallback")
	biomes = boat.get("_route_biomes")
	_check(biomes.size() == 1 and biomes[0] == &"volcano", "last island: one drawn route, on the volcano")
	boat.call("_pick", 1)
	boat.call("_pick_route", 0)
	_check(boat.call("_can_land"), "exhausted supply state can land")
	_check(int(boat.get("_supply")) == -1, "full HP and ammo, cards maxed: nothing to pick, DEPLOY still allowed")
	boat.queue_free()
	await _settle()
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	root.add_child(island)
	island.set("paused", true)
	await _settle()
	var hud: Hud = island.get("hud")
	hud.call("_settings")
	await _settle()
	_key(KEY_Q)
	await _settle()
	var run: IslandRun = island.get("run")
	_check(not run.is_over() and island.get("paused"), "settings block abandon shortcut under modal")
	_key(KEY_ESCAPE)
	await _settle()
	_check(island.get("paused"), "closing settings retains pause")
	_check(not is_instance_valid(hud.get("_pause_dialog")), "closing settings removes pause dialog")
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	Input.parse_input_event(cancel)
	await _settle()
	_check(not island.get("paused"), "gamepad Back resumes pause")
	island.queue_free()
	await _settle()
	# Allow the audio mixer to release playbacks from the freed UI/world.
	await create_timer(0.3).timeout
	print("TEST: menus %d checks / %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
