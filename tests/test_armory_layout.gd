extends SceneTree
## Approved shelter/tree layout: bounds, next-rank honesty and slot navigation.

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("TEST FAIL: " + message)


func _settle() -> void:
	for i in 4:
		await process_frame


func _fits(armory: Control) -> bool:
	var bounds := root.get_visible_rect()
	for control: Control in [armory.get("_content"), armory.get("_summary"), armory.get("_start_button"), armory.get("_hints")]:
		if not bounds.encloses(control.get_global_rect()):
			print("BOUNDS: %s / %s / viewport %s" % [control.name, control.get_global_rect(), bounds])
			return false
	return true


func _run() -> void:
	root.size = Vector2i(1152, 648)
	root.content_scale_size = Vector2i(1152, 648)
	var profile := MemoryProfile.new()
	profile.intel = 2000
	profile.unlocked_classes = [&"recruit", &"vanguard"]
	profile.slots = 3
	profile.perk_ranks = {&"combat_1": 2, &"survival_1": 1}
	profile.equipped_perks = [&"head_hunter", &"thick_skin"]
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	await _settle()
	_check(_fits(armory), "class loadout and hints fit 1152x648")
	_check(armory.find_children("*", "ScrollContainer", true, false).is_empty(), "fixed loadout needs no scrolling")
	var shelter: ClassPreview = armory.get("_shelter")
	var model: SoldierModel = shelter.get("_model")
	_check(model.uses_skeleton() and model.class_id == &"recruit", "shelter uses the playable Recruit rig")
	armory.call("_choose_class", &"vanguard")
	await _settle()
	model = shelter.get("_model")
	_check(model.uses_skeleton() and model.class_id == &"vanguard", "class selection updates the shelter rig")
	armory.call("_select_category", "PERKS")
	await _settle()
	_check(not model.visible, "perk tree hides the character behind its cards")
	var nodes: Dictionary = armory.get("_perk_buttons")
	for node: StringName in nodes:
		var a: Label = nodes[node].find_child("OptionA", true, false)
		var b: Label = nodes[node].find_child("OptionB", true, false)
		_check(a.get_global_rect().end.x <= b.get_global_rect().position.x and absf(a.global_position.y - b.global_position.y) < 1.0,
			"alternatives are side by side in " + String(node))
		(nodes[node] as Button).grab_focus()
		await _settle()
		_check(_fits(armory), "all perk effects/actions/hints fit for " + String(node))
		var perk: GameData.Perk = profile.perk_choice(node)
		var next: Control = armory.find_child("PerkNextEffects", true, false)
		_check(next != null and (next.get_child(0) as Label).text == "▲ " + GameData.perk_text(perk.benefit, perk.value(profile.node_rank(node) + 1)),
			"next-rank benefit comes from data for " + String(node))
	# Purchased rank II, using rank I: next purchase is still rank III.
	profile.set_use_rank(&"combat_1", 1)
	armory.call("_rebuild")
	await _settle()
	(armory.get("_perk_buttons")[&"combat_1"] as Button).grab_focus()
	await _settle()
	var current: Control = armory.find_child("PerkEffects", true, false)
	var next: Control = armory.find_child("PerkNextEffects", true, false)
	_check((current.get_child(0) as Label).text.contains("11°") and (next.get_child(0) as Label).text.contains("15°"),
		"lower used rank changes current effect, not the next purchase")
	_check((next.get_child(1) as Label).text.contains("−15%"), "next-rank penalty is visible before buying")
	# Slot strip opens the equipped perk's node, without removing it.
	var slot: Button = armory.find_child("EquippedSlot_1", true, false)
	slot.pressed.emit()
	await _settle()
	_check(armory.get("_perk_focus") == &"survival_1" and profile.equipped_perks.size() == 2,
		"equipped slot focuses its perk without changing equipment")
	for node: StringName in GameData.perk_nodes():
		profile.perk_ranks[node] = 3
	armory.call("_rebuild")
	await _settle()
	for node: StringName in GameData.perk_nodes():
		(armory.get("_perk_buttons")[node] as Button).grab_focus()
		await _settle()
		_check(armory.find_child("PerkNextEffects", true, false) == null and armory.find_child("PerkUpgrade", true, false) == null,
			"max rank offers no fictitious upgrade for " + String(node))
		_check(_fits(armory), "max-rank detail fits for " + String(node))
	root.size = Vector2i(1920, 1080)
	for category: String in ["CLASS", "WEAPONS", "PERKS"]:
		armory.call("_select_category", category)
		await _settle()
		_check(_fits(armory), category + " fits Full HD")
	# Fresh profile: slot purchase is focusable; locked slots remain visible.
	root.size = Vector2i(1152, 648)
	profile.slots = 1
	profile.equipped_perks = [&"head_hunter"]
	armory.call("_select_category", "PERKS")
	await _settle()
	_check(_fits(armory), "slot-purchase strip fits 1152x648")
	var locked_slot: Button = armory.find_child("EquippedSlot_2", true, false)
	locked_slot.pressed.emit()
	await _settle()
	_check(root.gui_get_focus_owner().name == "PerkSlot", "locked slot leads to the slot purchase action")
	(armory.find_child("PerkSlot", true, false) as Button).pressed.emit()
	await _settle()
	_check(profile.slots == 2 and profile.intel == 1900, "slot purchase preserves the 100 Intel cost")
	armory.set("_notice", "Recruit-only perk removed from Vanguard. The node is still owned; choose a class variant.")
	armory.call("_rebuild")
	await _settle()
	_check(_fits(armory), "migration notice and slot purchase fit together")
	armory.set("_notice", "")
	for class_id: StringName in GameData.CLASSES:
		profile.selected_class = class_id
		profile.slots = 3
		for node: StringName in GameData.perk_nodes():
			profile.perk_ranks[node] = 2
		for option in 2:
			for node: StringName in GameData.perk_nodes():
				profile.perk_options[node] = option
			armory.call("_rebuild")
			await _settle()
			for node: StringName in GameData.perk_nodes():
				(armory.get("_perk_buttons")[node] as Button).grab_focus()
				await _settle()
				_check(_fits(armory), "%s option %d rank II effects/actions fit for %s" % [class_id, option, node])
	armory.queue_free()
	await _settle()
	print("TEST: armory layout %d checks / %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)
