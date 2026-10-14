extends SceneTree
## HUD state checks: cooldowns, input prompts, mission states and safe layout.

var _failures: int = 0
var _hud: Hud
var _run: IslandRun
var _viewport: SubViewport


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1152, 648)
	root.add_child(_viewport)
	_hud = Hud.new()
	_hud.custom_viewport = _viewport
	_viewport.add_child(_hud)
	_run = IslandRun.new(7)
	call_deferred("_test")


## 30-round magazine, infinite reserve: counts down per shot, refills at 0
## at once (rifle.reload_seconds = 0), and Bigger Mags does not touch it.
func _test_rifle_magazine() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	run.horde.add(run.player_pos + Vector3(0, 0, -6), GameData.EnemyKind.BRUTE, run.rng)
	run.horde.hp[0] = 1e9
	var rifle: GameData.Weapon = run.weapons[0]
	_check(rifle.id == &"rifle" and run.magazine_size(0) == 30 and run.mag[0] == 30 and rifle.reload_seconds == 0.0, "rifle starts with a full 30-round magazine and instant reload")
	run._fire(rifle, 0)
	_check(run.mag[0] == 29 and run.ammo[0] == -1 and Hud.ammo_text(run, 0) == "29 / ∞", "one shot takes one round; the reserve stays infinite")
	for i in 28:
		run._fire(rifle, 0)
	_check(Hud.ammo_text(run, 0) == "1 / ∞", "magazine counts down to its last round")
	run._fire(rifle, 0)
	_check(run.mag[0] == 30 and run.reload_left == 0.0, "an empty magazine refills at once with no pause")
	var shots: int = run.get("_shots")
	run.facing = Vector3(0, 0, -1)
	run.set("_fire_cd", 0.0)
	run._auto_fire(40.0 / rifle.fire_rate)
	var fired: int = int(run.get("_shots")) - shots
	_check(fired > 30 and run.mag[0] == 30 - fired % 30 and run.reload_left == 0.0, "auto-fire keeps shooting through a magazine change in one frame (%d shots)" % fired)
	run.card_stacks[&"bigger_mags"] = 3
	_check(run.magazine_size(0) == 30 and run.max_ammo(0) == -1 and Hud.ammo_text(run, 1) == str(run.ammo[1]), "Bigger Mags leaves the rifle magazine alone; other weapons keep their plain ammo count")


func _test() -> void:
	await process_frame
	await process_frame
	_hud.refresh(_run, null, 0, false, "Island 1/3")
	_check(not _hud._debug.visible, "debug is hidden until F3")
	_check(_hud._ammo_text.text == "30 / ∞" and _hud._breaker_status.text == "READY", "rifle shows a full 30-round magazine over an infinite reserve and ready breaker")
	_test_rifle_magazine()
	_run.hp = 23
	_run.breaker_cd = 4.2
	_run.grenade_cd = 9.5
	_run.stamina = 1.5
	_run.sprinting = true
	_hud.refresh(_run, null, 0)
	_check(_hud._hp_text.text == "23" and _hud._hp_max.text == "/ 100" and _hud._alerts.text.contains("LOW HEALTH"), "low health remains readable numerically and as a warning")
	_check(_hud._breaker_status.text == "COOLDOWN" and is_equal_approx(_hud._breaker_ring.seconds, 4.2) and is_equal_approx(_hud._ability_ring.seconds, 9.5), "cooldowns show state and remaining seconds in the ring")
	_check(_hud._fire_status.text == "AUTO-FIRE" and is_equal_approx(_hud._stamina_bar.value, 1.5), "sprint keeps auto-fire (run and gun) and shows stamina")
	_run.sprinting = false
	_run.weapon_index = 1
	_run.ammo[1] = 0
	_hud.refresh(_run, null, 0)
	_check(_hud._ammo_text.text == "0" and _hud._fire_status.text == "NO AMMO", "empty finite weapon has a warning")
	_run.ammo[1] = 17
	_hud.refresh(_run, null, 0)
	_check(_hud._ammo_text.text == "17" and _hud._weapon_name.text == "SHOTGUN", "weapon swap updates finite ammo and name")
	_run.player_class = &"vanguard"
	_run.war_cry_time = 5
	_run.horde.grabbed_by = 0
	_run.scream_progress = 1.5
	_hud.refresh(_run, null, 0)
	_check(_hud._ability_name.text == "WAR CRY" and _hud._ability_icon.kind == &"war_cry", "Vanguard uses the War Cry tile")
	_check(_hud._alerts.text.contains("GRABBED") and _hud._alerts.text.contains("SCREAMER") and _hud._alerts.text.contains("WAR CRY"), "grab, scream and buff warnings survive the redesign")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_RIGHT_SHOULDER
	joy.pressed = true
	_hud._input(joy)
	_check(_hud._breaker_key.text == GameInput.prompt(&"breaker", true) and _hud._breaker_key.text.contains("RB") and _hud._ability_key.text == "LB", "controller prompts match the actual InputMap")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_SPACE
	key.pressed = true
	_hud._input(key)
	_check(_hud._breaker_key.text == "SPACE", "keyboard input restores keyboard prompts")
	_run.hp = 100
	_run.horde.grabbed_by = -1
	_run.scream_progress = 0
	_run.war_cry_time = 0
	_run.set_mission(&"rescue")
	_run.survivor_found = true
	_run.survivor_hp = 62
	_run.objective = IslandRun.Objective.RETURN_TO_BOAT
	_hud.refresh(_run, null, 0, false, "Island 2/3 [Sea Fog]")
	_check(_hud._objective.text == "EXTRACT THE SURVIVOR" and _hud._objective_detail.text.contains("SEA FOG"), "rescue objective and route modifier are retained")
	_check(_hud._survivor_row.visible and _hud._survivor_bar.value == 62, "escort shows survivor health separately")
	_run.survivor_lost = true
	_hud.refresh(_run, null, 0)
	_check(not _hud._survivor_row.visible and _hud._objective.text == "RETURN TO THE BOAT" and _hud._alerts.text.contains("SURVIVOR LOST"), "lost survivor cannot appear alive or still escorting")
	_run.set_mission(&"defend")
	_run.objective = IslandRun.Objective.GENERATORS
	_run.defend_time = 33
	_hud.refresh(_run, null, 0)
	_check(_hud._objective_detail.text.contains("33 OF 75"), "defend objective shows elapsed and required time")
	_run.set_mission(&"activate")
	_run.generator_progress[0] = GameData.GENERATOR_HOLD_SECONDS
	_hud.refresh(_run, null, 0)
	_check(_hud._objective_detail.text.contains("1 OF 3 ONLINE"), "generator objective shows completed count")
	_run.objective = IslandRun.Objective.BOSS
	_run.boss_enraged = true
	_hud.refresh(_run, null, 0)
	_check(_hud._boss_row.visible and _hud._boss_name.text.contains("PHASE 2"), "boss health and second phase remain visible")
	_run.card_choices.assign(_run.all_cards.slice(0, 3))
	_hud.refresh(_run, null, 0)
	_check(_hud._cards_panel.visible and _hud._cards[0].button is Button and _hud._cards[0].title.text == _run.card_choices[0].title, "card choices remain interactive native buttons")
	_run.card_choices.clear()
	_run.radio.append(&"survivor_found")
	_hud.refresh(_run, null, 0)
	await process_frame
	await process_frame
	_hud.refresh(_run, null, 0)
	_check(_hud._radio_panel.visible and _hud._radio_text.text != "" and _hud._radio_panel.get_global_rect().end.y < _hud._status_panel.get_global_rect().position.y, "radio subtitles stay on-screen above health")
	_run.objective = IslandRun.Objective.LOST
	_hud.refresh(_run, null, 0)
	_check(_hud._death_panel.visible and not _hud._end_panel.visible and _hud._death_intel.text == str(_run.intel_earned()), "defeat report shows retained Intel")
	_run.horde.grabbed_by = 0
	_run.scream_progress = 2
	_run.hp = 10
	_run.survivor_lost = true
	_run.war_cry_time = 5
	_hud.refresh(_run, null, 0)
	await _test_layout(Vector2i(960, 540))
	await _test_layout(Vector2i(1152, 648))
	await _test_layout(Vector2i(1920, 1080))
	_hud.queue_free()
	await process_frame
	quit(1 if _failures > 0 else 0)


func _test_layout(extent: Vector2i) -> void:
	_viewport.size = extent
	await process_frame
	await process_frame
	_hud.refresh(_run, null, 0)
	await process_frame
	var panels: Array[Control] = [_hud._status_panel, _hud._abilities_panel, _hud._weapon_panel]
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(extent))
	var contained: bool = true
	var separated: bool = true
	for i in panels.size():
		contained = contained and viewport_rect.encloses(panels[i].get_global_rect())
		for j in range(i + 1, panels.size()):
			separated = separated and not panels[i].get_global_rect().intersects(panels[j].get_global_rect())
	_check(contained and separated, "status, abilities and weapon fit without overlap at %dx%d" % [extent.x, extent.y])
	# The 8 px gap shrinks with the HUD size setting (panels are scaled).
	var gap: float = 8.0 * _hud._field.scale.y
	_check(_hud._alerts.get_global_rect().end.y <= _hud._abilities_panel.get_global_rect().position.y - gap + 0.01, "simultaneous warnings leave abilities clear at %dx%d" % [extent.x, extent.y])
