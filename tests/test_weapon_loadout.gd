extends SceneTree
## Arsenal B: one primary and one secondary, preserved ownership and legacy migration.

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _run_tests() -> void:
	var ids: Array = GameData.weapons().map(func(w: GameData.Weapon) -> StringName: return w.id)
	_check(ids.has(&"machine_gun") and not ids.has(&"pistol"), "Machine Gun replaces Heavy Pistol in the live arsenal")
	var profile := Profile.new()
	_check(profile.get("selected_primary") == &"rifle" and profile.get("selected_secondary") == &"shotgun", "new profile equips AR and Shotgun")
	_check(IslandRun.new(7).weapons.size() == 2, "run carries exactly two equipped weapons")
	profile.intel = 1000
	_check(not profile.select_weapon(&"smg") and profile.selected_primary == &"rifle", "locked primary cannot replace the equipped weapon")
	_check(profile.buy_weapon(&"smg") and profile.select_weapon(&"smg") and profile.intel == 940, "SMG unlock costs 60 Intel and equips atomically")
	_check(profile.select_weapon(&"rifle") and profile.owns_weapon(&"smg") and profile.intel == 940, "switching back to AR keeps SMG ownership without charging Intel")
	_check(profile.buy_weapon(&"machine_gun") and profile.select_weapon(&"machine_gun") and profile.selected_secondary == &"shotgun", "Machine Gun replaces only the primary slot")
	_check(profile.buy_weapon(&"marksman") and profile.select_weapon(&"marksman") and profile.selected_primary == &"machine_gun", "Marksman replaces only the secondary slot")
	_check(not profile.buy_weapon(&"machine_gun") and not profile.select_weapon(&"pistol"), "duplicate purchases and removed weapons are rejected")
	profile.save("user://test_weapon_profile.json")
	var saved: Profile = Profile.load_profile("user://test_weapon_profile.json")
	_check(saved.weapon_loadout() == profile.weapon_loadout() and saved.intel == 740, "ownership, Intel and equipped slots survive a save round-trip")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_weapon_profile.json"))
	var old := Profile.from_dict({"version": 5, "intel": 123, "unlocked_weapons": ["pistol", "smg", "smg", "missing"],
		"selected_primary": "smg", "selected_secondary": "pistol", "last_run": {"class": "recruit", "primary": "smg", "secondary": "pistol"}})
	_check(old.intel == 123 and old.unlocked_weapons == [&"smg"] and old.weapon_loadout() == [&"smg", &"shotgun"], "old pistol is removed without refund; owned SMG and Intel stay intact")
	_check(old.apply_last_run() and old.selected_secondary == &"shotgun", "legacy quick redeploy replaces pistol with Shotgun")
	var invalid := Profile.from_dict({"selected_primary": "machine_gun", "selected_secondary": "marksman"})
	_check(invalid.weapon_loadout() == [&"rifle", &"shotgun"], "invalid or locked saved selections fall back to free weapons")
	var wrong_slots := Profile.from_dict({"unlocked_weapons": ["smg", "marksman"], "selected_primary": "marksman", "selected_secondary": "smg"})
	_check(wrong_slots.weapon_loadout() == [&"rifle", &"shotgun"], "wrong-slot saved selections never cross-equip")
	profile.remember_run(&"")
	profile.select_weapon(&"rifle")
	_check(profile.apply_last_run() and profile.selected_primary == &"machine_gun" and profile.selected_secondary == &"marksman", "quick redeploy replays the saved weapon build")
	_test_combat()
	await _test_armory(profile)
	var soldier := SoldierModel.create(&"recruit")
	soldier.set_shadow_only(true)
	soldier.set_weapon(&"machine_gun")
	_check(soldier.find_children("*", "MeshInstance3D", true, false).all(func(n: Node) -> bool:
		return (n as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY), "switching guns in first person preserves the hidden third-person model")
	soldier.free()
	quit(1 if _failures > 0 else 0)


func _run(primary: StringName, secondary: StringName = &"shotgun") -> IslandRun:
	var map := IslandMap.new()
	map.field = FlowField.new(64, 64)
	map.player_start = Vector3(20, 0, 20)
	map.boat = Vector3(20, 0, 50)
	map.generators = [Vector3(40, 0, 40), Vector3(45, 0, 40), Vector3(45, 0, 45)]
	var run := IslandRun.new(77, &"beach", map)
	var context := RunContext.new(77)
	context.weapons = [primary, secondary]
	run.load_context(context)
	run.director.max_alive = 0
	run.weapons[0].spread_deg = 0.0
	return run


func _enemy(run: IslandRun, distance: float) -> int:
	var i: int = run.horde.add(run.player_pos + Vector3(distance, 0, 0), GameData.EnemyKind.WALKER, run.rng)
	run.horde.hp[i] = 10000.0
	return i


func _test_combat() -> void:
	for id: StringName in [&"rifle", &"smg", &"machine_gun"]:
		var run: IslandRun = _run(id)
		var target: int = _enemy(run, 4.0)
		var w: GameData.Weapon = run.weapons[0]
		run.card_stacks = {&"hollow_points": 2, &"fast_hands": 2, &"fire_rounds": 20}
		var expected: float = w.damage * 1.2 * (w.close_damage_mult if w.close_range >= 4.0 else 1.0)
		run._fire(w, target)
		_check(absf(10000.0 - run.horde.hp[target] - expected) < 0.005 and run.horde.burn_time[target] > 0.0,
			String(id) + " receives primary damage cards and elemental effects")
		_check(is_equal_approx(run.fire_rate(), w.fire_rate * 1.16), String(id) + " receives primary fire-rate cards")
		_check(run.ammo[0] == -1 and run.mag[0] == w.magazine - 1, String(id) + " spends magazine rounds with infinite reserve")
		var p: Vector3 = run.player_pos
		run._update_player(0.1, Vector2.RIGHT, false)
		_check(is_equal_approx(run.player_pos.x - p.x, GameData.PLAYER_SPEED * w.movement_mult * 0.1), String(id) + " movement follows the equipped weapon")
		var card_ids: Array = CardOffers.new(7).eligible(GameData.cards(), &"recruit", [id, &"shotgun"], {}).map(func(c: GameData.Card) -> StringName: return c.id)
		_check(card_ids.has(&"hollow_points") and card_ids.has(&"fire_rounds"), String(id) + " qualifies for primary and elemental card offers")
	var near: IslandRun = _run(&"smg")
	var target: int = _enemy(near, 5.0)
	near._fire(near.weapons[0], target)
	_check(is_equal_approx(10000.0 - near.horde.hp[target], 10.0), "SMG deals 25% extra damage inside six metres")
	var far: IslandRun = _run(&"smg")
	target = _enemy(far, 7.0)
	far._fire(far.weapons[0], target)
	_check(is_equal_approx(10000.0 - far.horde.hp[target], 8.0), "SMG loses its close-range bonus beyond six metres")
	for id: StringName in [&"smg", &"machine_gun"]:
		var run: IslandRun = _run(id)
		target = _enemy(run, 4.0)
		run.mag[0] = 1
		run._fire(run.weapons[0], target)
		var seconds: float = run.weapons[0].reload_seconds
		_check(run.mag[0] == 0 and is_equal_approx(run.reload_left, seconds), String(id) + " empty magazine starts its own timed reload")
		var hp: float = run.horde.hp[target]
		run._auto_fire(0.1)
		_check(run.horde.hp[target] == hp, String(id) + " cannot shoot during reload")
		run.switch_weapon(1)
		_check(run.weapon_index == 1 and run.reload_left == 0.0, "secondary can be used while " + String(id) + " reloads")
		run._update_reloads(seconds + 0.01)
		run.switch_weapon(0)
		_check(run.mag[0] == run.magazine_size(0) and run.reload_left == 0.0, String(id) + " reload finishes while holstered")
	var marksman: IslandRun = _run(&"machine_gun", &"marksman")
	marksman.card_stacks = {&"hollow_points": 5, &"fire_rounds": 20, &"bigger_mags": 2}
	target = _enemy(marksman, 4.0)
	marksman.switch_weapon(1)
	marksman._fire(marksman.weapons[1], target)
	_check(is_equal_approx(10000.0 - marksman.horde.hp[target], 110.0) and marksman.horde.burn_time[target] == 0.0, "secondary does not receive primary-only effects")
	marksman.ammo[1] = 0
	marksman.apply_power_up(&"max_ammo")
	_check(marksman.ammo[0] == -1 and marksman.ammo[1] == 39, "Max Ammo and Bigger Mags refill the chosen secondary only")
	var context := RunContext.new(77)
	context.weapons = [&"machine_gun", &"marksman"]
	marksman.ammo[1] = 7
	marksman.save_to_context(context)
	var next: IslandRun = _run(&"rifle")
	next.load_context(context)
	_check(next.weapons[0].id == &"machine_gun" and next.weapons[1].id == &"marksman" and next.ammo[1] == 7, "equipped guns and remaining ammo carry between islands")


func _test_armory(profile: Profile) -> void:
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	armory.call("_select_category", "WEAPONS")
	await process_frame
	await process_frame
	_check(armory.find_child("Weapon_machine_gun", true, false) != null and armory.find_child("Weapon_pistol", true, false) == null, "Armory lists Machine Gun and excludes Heavy Pistol")
	(armory.find_child("Weapon_rifle", true, false) as Button).pressed.emit()
	await process_frame
	_check(profile.selected_primary == &"rifle" and profile.selected_secondary == &"marksman" and profile.owns_weapon(&"machine_gun"), "Armory equip swaps a single slot while keeping owned guns")
	armory.queue_free()
	await process_frame
