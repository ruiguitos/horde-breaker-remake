extends SceneTree
## Card eligibility, isolated RNG and behaviour promises (headless).

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _ids(cards: Array[GameData.Card]) -> Array[StringName]:
	var result: Array[StringName] = []
	for c in cards:
		result.append(c.id)
	return result


func _initialize() -> void:
	var catalog: Array[GameData.Card] = GameData.cards()
	_check(catalog.size() == 39, "39 implemented cards; deferred systems excluded")
	var offers := CardOffers.new(77)
	var weapons: Array[StringName] = [&"rifle", &"shotgun"]
	var recruit: Array[StringName] = _ids(offers.eligible(catalog, &"recruit", weapons, {}))
	var vanguard: Array[StringName] = _ids(offers.eligible(catalog, &"vanguard", weapons, {}))
	for id: StringName in [&"grenadier", &"wide_blast", &"concussion"]:
		_check(recruit.has(id) and not vanguard.has(id), "Recruit-only offer: " + String(id))
	for id: StringName in [&"rally", &"intimidation", &"battle_rhythm"]:
		_check(vanguard.has(id) and not recruit.has(id), "Vanguard-only offer: " + String(id))
	var pistol: Array[StringName] = [&"marksman"]
	var pistol_ids: Array[StringName] = _ids(offers.eligible(catalog, &"recruit", pistol, {}))
	_check(not pistol_ids.has(&"hollow_points") and not pistol_ids.has(&"fire_rounds") and pistol_ids.has(&"bigger_mags"), "rifle and finite weapon filters")
	var rifle: Array[StringName] = [&"rifle"]
	_check(not _ids(offers.eligible(catalog, &"recruit", rifle, {})).has(&"bigger_mags"), "Bigger Mags requires an owned finite weapon")
	_check(not recruit.has(&"wildfire") and _ids(offers.eligible(catalog, &"recruit", weapons, {&"fire_rounds": 1})).has(&"wildfire"), "element upgrades require the base card")
	_check(not _ids(offers.eligible(catalog, &"recruit", weapons, {&"fire_rounds": 5})).has(&"fire_rounds"), "max rank excluded")
	var same := CardOffers.new(77)
	var ranks: Dictionary = {&"hollow_points": 1, &"fast_hands": 1}
	var guaranteed: bool = true
	var deterministic: bool = true
	for iteration in 100:
		var a: Array[GameData.Card] = offers.draw(catalog, &"recruit", weapons, ranks)
		var b: Array[GameData.Card] = same.draw(catalog, &"recruit", weapons, ranks)
		deterministic = deterministic and _ids(a) == _ids(b)
		var novel: bool = false
		var upgrade: bool = false
		var unique: Dictionary = {}
		for c in a:
			novel = novel or int(ranks.get(c.id, 0)) == 0
			upgrade = upgrade or int(ranks.get(c.id, 0)) > 0
			unique[c.id] = true
		guaranteed = guaranteed and novel and upgrade and unique.size() == 3
	_check(guaranteed and deterministic, "100 offers: new, upgrade, no duplicates and deterministic RNG")
	for c in catalog:
		if c.id == &"hollow_points":
			_check(is_equal_approx(offers.weight(c, catalog, ranks), 1.875), "upgrade weight 1.5 times shared tag 1.25")
	_test_offer_edges(catalog)
	_test_maxed_offer_exclusion(catalog)
	_test_auto_xp()
	_test_fast_learner_ranks()
	for card in catalog:
		_test_card(card.id)
	_test_states()
	_test_boundaries()
	_test_carry()
	_test_supplies.call_deferred()


func _run() -> IslandRun:
	var map := IslandMap.new()
	map.field = FlowField.new(64, 64)
	map.player_start = Vector3(20, 0, 20)
	map.boat = Vector3(20, 0, 50)
	map.generators = [Vector3(40, 0, 40), Vector3(45, 0, 40), Vector3(45, 0, 45)]
	var run := IslandRun.new(77, &"beach", map)
	run.weapons[0].spread_deg = 0.0
	run.director.max_alive = 0
	return run


func _test_maxed_offer_exclusion(catalog: Array[GameData.Card]) -> void:
	var ranks: Dictionary = {}
	for card in catalog:
		ranks[card.id] = card.max_stacks
	ranks[&"magnet"] -= 1
	var offers := CardOffers.new(23)
	var weapons: Array[StringName] = [&"rifle", &"shotgun"]
	var clean: bool = true
	for draw in 30:
		clean = clean and _ids(offers.draw(catalog, &"recruit", weapons, ranks)) == [&"magnet"]
		var supply: GameData.Card = offers.single(catalog, &"recruit", weapons, ranks)
		clean = clean and supply != null and supply.id == &"magnet"
	_check(clean, "level-up and supply offers exclude every maxed card even when fewer than three choices remain")
	var run: IslandRun = _run()
	run.card_stacks = ranks.duplicate()
	run.hp = 30.0
	run.set("_pending_levels", 2)
	run._roll_cards_if_needed()
	_check(run.reroll_cards() and _ids(run.card_choices) == [&"magnet"], "rerolls cannot reintroduce maxed cards")
	run.choose_card(0)
	_check(run.card_choices.is_empty() and run.stacks(&"magnet") == ranks[&"magnet"] + 1 and run.hp == 50.0,
		"taking the last available rank excludes that card from the next queued level-up")


func _test_auto_xp() -> void:
	var run: IslandRun = _run()
	run.level = 29
	run.orbs = PackedVector3Array([Vector3(60, 0, 60)])
	run.orb_values = PackedInt32Array([7])
	run._update_orbs(0.1)
	_check(run.xp == 0 and run.orbs.size() == 1, "level 29 still requires approaching distant XP")
	for player_level in [30, 31]:
		run = _run()
		run.level = player_level
		run.orbs = PackedVector3Array([Vector3(60, 0, 60), Vector3(62, 0, 62)])
		run.orb_values = PackedInt32Array([5, 7])
		run._update_orbs(0.1)
		_check(run.xp == 12 and run.orbs.is_empty() and run.orb_values.is_empty(), "level %d collects all ground XP regardless of distance" % player_level)
	run = _run()
	run.level = 29
	run.xp = run.xp_needed() - 1
	run.orbs = PackedVector3Array([Vector3(60, 0, 60), Vector3(62, 0, 62), run.player_pos])
	run.orb_values = PackedInt32Array([5, 7, 1])
	run._update_orbs(0.1)
	_check(run.level == 30 and run.xp == 12 and run.orbs.is_empty(), "reaching level 30 collects existing distant XP before opening the card choice")
	run = _run()
	run.level = 30
	run.hp = 60.0
	run.card_stacks = {&"fast_learner": 1, &"field_dressing": 1}
	run.apply_power_up(&"double_rewards")
	run.orbs = PackedVector3Array([Vector3(60, 0, 60), Vector3(62, 0, 62)])
	run.orb_values = PackedInt32Array([3, 3])
	run._update_orbs(0.1)
	_check(run.xp == 12 and is_equal_approx(run.xp_fraction, 0.6) and is_equal_approx(run.hp, 60.4),
		"automatic XP preserves Double Rewards, Fast Learner fractions and Field Dressing healing")
	var earned: int = run.xp
	run._update_orbs(0.1)
	_check(run.xp == earned and is_equal_approx(run.hp, 60.4), "automatic XP consumes each orb exactly once")
	run.orbs.append(Vector3(60, 0, 60))
	run.orb_values.append(3)
	run._update_orbs(0.1)
	_check(run.xp == 18 and run.orbs.is_empty(), "new XP drops also collect automatically after level 30")
	run = _run()
	run.level = 30
	run.xp = run.xp_needed() - 1
	run.orbs.append(Vector3(60, 0, 60))
	run.orb_values.append(1)
	run._update_orbs(0.1)
	_check(run.level == 31 and run.xp == 0 and not run.card_choices.is_empty(), "automatic XP continues levelling and offering eligible cards")


func _test_fast_learner_ranks() -> void:
	for rank in range(6):
		var run: IslandRun = _run()
		run.level = 20  # avoid level-ups while measuring ten one-XP pickups
		run.card_stacks = {&"fast_learner": rank}
		for pickup in 10:
			run.orbs.append(run.player_pos)
			run.orb_values.append(1)
			run._update_orbs(0.0)
		var expected: float = 10.0 * (1.0 + 0.05 * rank)
		_check(is_equal_approx(run.xp + run.xp_fraction, expected),
			"Fast Learner rank %d: ten base XP grant %.2f XP without losing fractions" % [rank, expected])
	var run: IslandRun = _run()
	run.level = 20
	run.card_stacks = {&"fast_learner": 4}
	run.power_ups.double_time = 10.0
	run.orbs.append(run.player_pos)
	run.orb_values.append(1)
	run._update_orbs(0.0)
	_check(is_equal_approx(run.xp + run.xp_fraction, 2.4), "rank 4 and Double XP grant 2.4 XP from one base XP")
	var ctx := RunContext.new(77)
	run.save_to_context(ctx)
	var next: IslandRun = _run()
	next.load_context(ctx)
	next.power_ups.double_time = 0.0
	next.orbs.append(next.player_pos)
	next.orb_values.append(1)
	next._update_orbs(0.0)
	_check(is_equal_approx(next.xp + next.xp_fraction, 3.6), "rank 4 and fractional XP still apply after changing island")


func _enemy(run: IslandRun, offset: Vector3 = Vector3(3, 0, 0), health: float = 1000.0,
		kind: int = GameData.EnemyKind.WALKER) -> int:
	var i: int = run.horde.add(run.player_pos + offset, kind, run.rng)
	run.horde.hp[i] = health
	return i


func _test_offer_edges(catalog: Array[GameData.Card]) -> void:
	var offers := CardOffers.new(33)
	var rifle: Array[StringName] = [&"rifle"]
	var rank: Dictionary = {}
	for c in catalog:
		_check(c.max_stacks in [3, 5] and not c.tags.is_empty() and c.icon != &"" and c.category != &"", "metadata: " + String(c.id))
		rank[c.id] = c.max_stacks
	var state: int = offers.rng.state
	offers.eligible(catalog, &"vanguard", rifle, rank)
	_check(offers.rng.state == state, "filtering consumes no RNG")
	_check(offers.draw(catalog, &"vanguard", rifle, rank).is_empty(), "exhausted deck returns no cards")
	var run: IslandRun = _run()
	run.card_stacks = rank.duplicate()
	run.hp = 35.0
	run.set("_pending_levels", 2)
	run.call("_roll_cards_if_needed")
	_check(run.card_choices.is_empty() and is_equal_approx(run.hp, 75.0), "exhausted level-ups heal 20 HP each")
	var tiny: Array[GameData.Card] = [catalog[0], catalog[0], catalog[1]]
	var drawn: Array[GameData.Card] = offers.draw(tiny, &"recruit", rifle, {})
	_check(drawn.size() == 2 and drawn[0].id != drawn[1].id, "duplicate catalogue IDs and small decks are safe")
	var new_only: Array[GameData.Card] = offers.draw(catalog, &"recruit", rifle, {})
	_check(new_only.size() == 3, "new-only build fills three choices")
	var upgrade_only: Array[GameData.Card] = offers.draw(tiny, &"recruit", rifle, {catalog[0].id: 1, catalog[1].id: 1})
	_check(upgrade_only.size() == 2, "upgrade-only small build remains offerable")
	run = _run()
	state = run.rng.state
	run._draw_cards([])
	_check(run.rng.state == state, "card offers do not perturb gameplay RNG")


## One behaviour check per catalogue entry, through the live rules.
func _test_card(id: StringName) -> void:
	var run: IslandRun = _run()
	run.card_stacks[id] = 2
	var enemy: int = _enemy(run)
	var ok: bool = false
	match id:
		&"hollow_points", &"point_blank":
			run.call("_fire", run.weapons[0], enemy)
			ok = is_equal_approx(1000.0 - run.horde.hp[enemy], 14.4)
		&"finish_the_job":
			run.horde.hp[enemy] = run.horde.types[GameData.EnemyKind.WALKER].hp * 0.2
			var before: float = run.horde.hp[enemy]
			run.call("_fire", run.weapons[0], enemy)
			ok = is_equal_approx(before - run.horde.hp[enemy], 15.6)
		&"fast_hands", &"steady_aim":
			ok = is_equal_approx(run.fire_rate(), 9.0 * 1.16)
			if id == &"steady_aim":
				run.step(0.1, Vector2.UP, Vector3.FORWARD, false)
				ok = ok and is_equal_approx(run.fire_rate(), 9.0)
			run.weapon_index = 1
			ok = ok and is_equal_approx(run.fire_rate(), run.weapons[1].fire_rate)
		&"ricochet":
			var near: int = _enemy(run, Vector3(3, 0, 1))
			var far: int = _enemy(run, Vector3(3, 0, 4))
			run.set("_shots", 3)
			run.call("_fire", run.weapons[0], enemy)
			ok = is_equal_approx(1000.0 - run.horde.hp[near], 7.2) and is_equal_approx(1000.0 - run.horde.hp[far], 7.2) \
				and is_equal_approx(1000.0 - run.horde.hp[enemy], 12.0)
		&"explosive_heads":
			var neighbour: int = _enemy(run, Vector3(3, 0, 2))
			run.horde.hp[enemy] = 1.0
			run.facing = Vector3.RIGHT
			run.call("_fire", run.weapons[0], enemy)
			ok = run.kills == 1 and is_equal_approx(1000.0 - run.horde.hp[neighbour], 45.0)
		&"piercing_rounds":
			var second: int = _enemy(run, Vector3(5, 0, 0))
			var third: int = _enemy(run, Vector3(7, 0, 0))
			var fourth: int = _enemy(run, Vector3(9, 0, 0))
			run.call("_fire", run.weapons[0], enemy)
			ok = run.horde.hp[second] < 1000.0 and run.horde.hp[third] < 1000.0 and is_equal_approx(run.horde.hp[fourth], 1000.0)
		&"vampire", &"second_breath", &"adrenaline", &"kill_rations":
			run.hp = 50.0
			run.stamina = 1.0
			run.breaker_cd = 5.0
			run.kills = 9
			run.call("_damage", enemy, 10000.0, run.player_pos, true, true)
			match id:
				&"vampire": ok = is_equal_approx(run.hp, 52.0)
				&"second_breath": ok = is_equal_approx(run.stamina, 1.2)
				&"adrenaline": ok = is_equal_approx(run.breaker_cd, 4.8)
				&"kill_rations": ok = is_equal_approx(run.hp, 54.0)
		&"quick_breaker":
			ok = is_equal_approx(run.breaker_cooldown_total(), GameData.BREAKER_COOLDOWN * 0.81)
		&"grenadier":
			ok = is_equal_approx(run.grenade_cooldown_total(), GameData.GRENADE_COOLDOWN * 0.81)
		&"shockwave":
			var extra: int = _enemy(run, Vector3(GameData.BREAKER_RADIUS * 1.3, 0, 0))
			run.call("_breaker_impact", run.breaker_radius())
			ok = is_equal_approx(1000.0 - run.horde.hp[extra], GameData.BREAKER_DAMAGE + 30.0)
		&"executioner":
			run.horde.stun[enemy] = 1.0
			run.call("_damage", enemy, 10.0, run.player_pos, false, true)
			ok = is_equal_approx(1000.0 - run.horde.hp[enemy], 14.0)
		&"bigger_mags":
			var before: int = run.ammo[1]
			ok = run.max_ammo(1) == int(run.weapons[1].max_ammo * 1.3) and run.ammo[1] == before
		&"magnet":
			var point: Vector3 = run.player_pos + Vector3(GameData.PICKUP_RADIUS * 1.7, 0, 0)
			run.orbs.append(point)
			run.orb_values.append(1)
			run.call("_update_orbs", 0.1)
			ok = run.orbs[0].distance_to(run.player_pos) < point.distance_to(run.player_pos)
		&"field_dressing", &"fast_learner":
			run.hp = 50.0
			for orb in 10:
				run.orbs.append(run.player_pos)
				run.orb_values.append(1)
			run.call("_update_orbs", 0.0)
			ok = is_equal_approx(run.hp, 54.0) if id == &"field_dressing" else run.xp == 11
		&"catch_your_breath":
			run.hp = 50.0
			run.time_alive = 4.9
			run.call("_regenerate", 1.0)
			ok = is_equal_approx(run.hp, 50.0)
			run.time_alive = 6.0
			run.call("_regenerate", 1.0)
			ok = ok and is_equal_approx(run.hp, 51.0)
			run.call("_take_player_damage", 1.0)
			run.time_alive = 10.0
			run.call("_regenerate", 1.0)
			ok = ok and is_equal_approx(run.hp, 50.0)
		&"light_boots":
			var before: Vector3 = run.player_pos
			run.call("_update_player", 0.1, Vector2.UP, false)
			ok = is_equal_approx(run.player_pos.distance_to(before), GameData.PLAYER_SPEED * 1.08 * 0.1)
		&"thick_hide":
			run.card_stacks.clear()
			run.hp = 50.0
			for card in run.all_cards:
				if card.id == id:
					run.card_choices = [card]
					run.choose_card(0)
			ok = is_equal_approx(run.max_hp, 115.0) and is_equal_approx(run.hp, 65.0)
		&"aftershock", &"crowd_splitter":
			run.horde.positions[enemy] = run.player_pos + Vector3(0.8, 0, 0)
			run.horde.rebuild_hash()
			var before: Vector3 = run.horde.positions[enemy]
			run.dash_time = 0.2
			run.dash_dir = Vector3.ZERO
			run.call("_update_player", 0.01, Vector2.ZERO, false)
			ok = is_equal_approx(run.horde.stun[enemy], GameData.BREAKER_STUN + 0.4) if id == &"aftershock" \
				else is_equal_approx(run.horde.positions[enemy].distance_to(before), 1.4)
		&"wide_blast", &"concussion":
			run.horde.positions[enemy] = run.player_pos + Vector3(GameData.GRENADE_RADIUS + 0.6 if id == &"wide_blast" else 1.0, 0, 0)
			run.horde.rebuild_hash()
			run.grenades.append(run.player_pos)
			run.grenade_fuses.append(0.0)
			run.call("_update_grenades", 0.0)
			ok = run.horde.hp[enemy] < 1000.0 if id == &"wide_blast" else is_equal_approx(run.horde.stun[enemy], 1.1)
		&"rally", &"intimidation", &"battle_rhythm":
			run.player_class = &"vanguard"
			run.hp = 50.0
			var before: Vector3 = run.horde.positions[enemy]
			run.use_ability(Vector3.ZERO)
			match id:
				&"rally": ok = is_equal_approx(run.hp, 60.0)
				&"intimidation": ok = is_equal_approx(run.horde.positions[enemy].distance_to(before), 1.8)
				&"battle_rhythm":
					ok = is_equal_approx(run.fire_rate(), 9.0 * 1.16)
					run.step(3.1, Vector2.ZERO, Vector3.FORWARD, false)
					ok = ok and is_equal_approx(run.fire_rate(), 9.0)
		&"wind_rounds":
			var before: Vector3 = run.horde.positions[enemy]
			run.call("_fire", run.weapons[0], enemy)
			ok = is_equal_approx(run.horde.positions[enemy].distance_to(before), run.weapons[0].knockback + 0.3)
		&"fire_rounds", &"frost_rounds", &"storm_rounds", &"toxic_rounds":
			var neighbour: int = _enemy(run, Vector3(3, 0, 2))
			for hit in 200:
				run.call("_fire", run.weapons[0], enemy)
				if id == &"frost_rounds" and run.horde.freeze_time[enemy] > 0.0:
					break
				if run.horde.hp[enemy] < 300.0:
					run.horde.hp[enemy] = 1000.0
			match id:
				&"fire_rounds": ok = is_equal_approx(run.horde.burn_time[enemy], 3.0)
				&"frost_rounds": ok = run.horde.freeze_time[enemy] > 0.0
				&"storm_rounds": ok = run.horde.hp[neighbour] < 1000.0
				&"toxic_rounds": ok = is_equal_approx(run.horde.poison_time[enemy], 4.0)
		&"wildfire":
			var first: int = _enemy(run, Vector3(3, 0, 1))
			var second: int = _enemy(run, Vector3(3, 0, 2))
			var third: int = _enemy(run, Vector3(3, 0, 3))
			run.horde.burn_time[enemy] = 3.0
			run.call("_damage", enemy, 10000.0, run.player_pos, false, true)
			ok = run.horde.burn_time[first] > 0.0 and run.horde.burn_time[second] > 0.0 and run.horde.burn_time[third] == 0.0
		&"deep_freeze":
			for hit in 3:
				run.call("_apply_cold", enemy)
			ok = is_equal_approx(run.horde.freeze_time[enemy], 1.5)
		&"chain_lightning":
			run.card_stacks[&"storm_rounds"] = 5
			for offset in [Vector3(3, 0, 2), Vector3(3, 0, 4), Vector3(3, 0, 6), Vector3(3, 0, 8)]:
				_enemy(run, offset, 100000.0)
			for hit in 200:
				run.call("_apply_elements", enemy, 10.0)
			ok = run.horde.hp[1] < 100000.0 and run.horde.hp[2] < 100000.0 and run.horde.hp[3] < 100000.0 and is_equal_approx(run.horde.hp[4], 100000.0)
		&"toxic_cloud":
			run.horde.poison_time[enemy] = 4.0
			var neighbour: int = _enemy(run, Vector3(3, 0, 1))
			run.call("_damage", enemy, 10000.0, run.player_pos, false, true)
			ok = run.toxic_clouds.size() == 1 and is_equal_approx(run.toxic_cloud_times[0], 3.0)
			run.call("_update_states", 4.0)
			ok = ok and run.toxic_clouds.is_empty() and is_equal_approx(1000.0 - run.horde.hp[neighbour], 18.0)
		_:
			_check(false, "missing behaviour test for " + String(id))
	_check(ok, "card effect: " + String(id))


func _test_states() -> void:
	var run: IslandRun = _run()
	var i: int = _enemy(run)
	run.call("_apply_fire", i)
	run.call("_apply_fire", i)
	run.horde.poison_time[i] = 4.0
	run.call("_update_states", 10.0)
	_check(is_equal_approx(run.horde.hp[i], 952.0), "burn 24 + poison 24; refresh does not stack damage or overrun duration")
	_check(run.horde.flash[i] == 0.0, "damage over time leaves status colours visible")
	run.call("_apply_cold", i)
	_check(is_equal_approx(run.horde.speed_multiplier(i), 0.85), "cold slows 15 percent")
	run.call("_update_states", 4.1)
	_check(run.horde.cold_stacks[i] == 0, "cold expires after four seconds")
	for hit in 3:
		run.call("_apply_cold", i)
	_check(run.horde.cold_stacks[i] == 0 and is_equal_approx(run.horde.freeze_time[i], 1.0), "three applications freeze and consume cold")
	var before: Vector3 = run.horde.positions[i]
	run.horde.tick(0.1)
	_check(run.horde.positions[i] == before and run.horde.damage_to_player == 0.0, "frozen enemy cannot move or attack")
	var boss: int = _enemy(run, Vector3(8, 0, 0), 1000.0, GameData.EnemyKind.BOSS)
	for hit in 10:
		run.call("_apply_cold", boss)
	_check(run.horde.freeze_time[boss] == 0.0 and is_equal_approx(run.horde.speed_multiplier(boss), 0.775), "boss never freezes; cold capped at three half-strength stacks")
	run.horde.burn_time[boss] = 1.2
	run.horde.poison_time[boss] = 2.3
	run.horde.remove(0)
	_check(run.horde.kinds[0] == GameData.EnemyKind.BOSS and is_equal_approx(run.horde.burn_time[0], 1.2) \
		and is_equal_approx(run.horde.poison_time[0], 2.3) and run.horde.cold_stacks[0] == 3, "swap removal preserves all status arrays")
	run = _run()
	i = _enemy(run)
	run.card_stacks = {&"fire_rounds": 1, &"frost_rounds": 1, &"wildfire": 3, &"toxic_cloud": 3}
	run.horde.freeze_time[i] = 1.0
	run.call("_apply_fire", i)
	_check(run.horde.freeze_time[i] == 0.0 and is_equal_approx(run.horde.hp[i], 970.0), "Thermal Shock deals 30 damage and thaws")
	run.toxic_clouds.append(run.horde.positions[i])
	run.toxic_cloud_times.append(3.0)
	run.call("_apply_fire", i)
	_check(run.toxic_clouds.is_empty() and is_equal_approx(run.horde.hp[i], 945.0), "Toxic Combustion consumes cloud and deals 25 damage")
	var neighbour: int = _enemy(run, Vector3(3, 0, 1))
	run.horde.poison_time[i] = 4.0
	run.call("_damage", i, 10000.0, run.player_pos, false, true, true)
	run.call("_damage", i, 10000.0, run.player_pos, false, true, true)
	_check(run.kills == 1 and run.toxic_clouds.is_empty() and run.horde.burn_time[neighbour] == 0.0, "secondary kills do not chain card effects or count twice")
	run = _run()
	i = _enemy(run, Vector3(3, 0, 0), 100000.0)
	_enemy(run, Vector3(3, 0, 2), 100000.0)
	_enemy(run, Vector3(3, 0, 4), 100000.0)
	run.card_stacks = {&"storm_rounds": 5, &"frost_rounds": 1}
	# Reapply cold to hold the source cold without letting the proc freeze it.
	for hit in 200:
		run.horde.cold_stacks[i] = 1
		run.horde.cold_time[i] = 4.0
		run.call("_apply_elements", i, 10.0)
	_check(run.horde.hp[2] < 100000.0 and is_equal_approx(run.horde.hp[0], 100000.0), "Conductive Frost adds a jump; discharge never repeats its source")


func _test_carry() -> void:
	var run: IslandRun = _run()
	var ctx := RunContext.new(77)
	run.load_context(ctx)
	run._draw_cards([])
	run.max_hp = 130.0
	run.hp = 95.0
	run.xp_fraction = 0.6
	run.save_to_context(ctx)
	var next_run: IslandRun = _run()
	next_run.load_context(ctx)
	_check(next_run.max_hp == 130.0 and next_run.hp == 95.0 and next_run.xp_fraction == 0.6, "maximum HP and fractional XP carry between islands")
	run.card_choices.clear()
	run._draw_cards([])
	next_run._draw_cards([])
	_check(_ids(run.card_choices) == _ids(next_run.card_choices), "card RNG sequence carries between islands")


func _test_boundaries() -> void:
	var run: IslandRun = _run()
	var target: int = _enemy(run, Vector3(4.01, 0, 0))
	run.card_stacks = {&"hollow_points": 5, &"point_blank": 3, &"fire_rounds": 5, &"ricochet": 3}
	run.weapons[1] = GameData.weapon(&"marksman")
	run.weapon_index = 1
	run.set("_shots", 3)
	run.call("_fire", run.weapons[1], target)
	_check(is_equal_approx(run.horde.hp[target], 1000.0 - run.weapons[1].damage) and run.horde.burn_time[target] == 0.0 and run.get("_shots") == 3,
		"primary cards do not change secondary damage, statuses or primary shot counter")
	run.card_stacks = {&"point_blank": 3}
	run.weapon_index = 0
	run.call("_fire", run.weapons[0], target)
	_check(is_equal_approx(run.horde.hp[target], 878.0), "Point Blank excludes targets beyond four metres")
	run = _run()
	target = _enemy(run)
	run.card_stacks = {&"finish_the_job": 3}
	run.horde.hp[target] = run.horde.types[GameData.EnemyKind.WALKER].hp * 0.31
	var before: float = run.horde.hp[target]
	run.call("_fire", run.weapons[0], target)
	_check(is_equal_approx(before - run.horde.hp[target], 12.0), "Finish the Job excludes targets above thirty percent HP")
	run = _run()
	run.hp = 150.0
	run.time_alive = 10.0
	run.call("_regenerate", 1.0)
	run.orbs.append(run.player_pos)
	run.orb_values.append(1)
	run.call("_update_orbs", 0.0)
	_check(run.hp == 150.0, "zero healing never reduces health")
	var ctx := RunContext.new(77)
	for c in GameData.cards():
		if c.id == &"thick_hide":
			for grant in 6:
				ctx.grant_card(c)
	_check(ctx.max_hp == 175.0 and ctx.card_stacks.get(&"thick_hide", 0) == 5, "supply card grants respect the rank cap")
	run = _run()
	_enemy(run)
	var last: int = _enemy(run, Vector3(5, 0, 0))
	run.horde.burn_time[last] = 1.1
	run.horde.poison_time[last] = 2.2
	run.horde.cold_time[last] = 3.3
	run.horde.cold_stacks[last] = 2
	run.horde.freeze_time[last] = 0.7
	run.horde.remove(0)
	_check(is_equal_approx(run.horde.burn_time[0], 1.1) and is_equal_approx(run.horde.poison_time[0], 2.2) \
		and is_equal_approx(run.horde.cold_time[0], 3.3) and run.horde.cold_stacks[0] == 2 \
		and is_equal_approx(run.horde.freeze_time[0], 0.7) and run.horde.freeze_time.size() == run.horde.count,
		"swap removal preserves positive timers, stacks and array lengths")
	for rank in range(1, 6):
		run.card_stacks = {&"fire_rounds": rank}
		var hits: int = 0
		for roll in 10000:
			if run.call("_element_proc", &"fire_rounds"):
				hits += 1
		_check(absf(float(hits) / 10000.0 - rank * 0.05) < 0.015, "element chance is five percentage points per rank (%d: %.3f)" % [rank, float(hits) / 10000.0])


func _test_supplies() -> void:
	GameInput.setup()
	for screen: String in ["boat", "camp"]:
		var ctx := RunContext.new(77)
		ctx.player_class = &"vanguard"
		ctx.weapons = [&"rifle", &"shotgun"]
		for c in GameData.cards():
			if c.id != &"thick_hide":
				ctx.card_stacks[c.id] = c.max_stacks
		ctx.hp = 50.0
		if screen == "camp":
			ctx.start_expedition(&"berlenga", 1)
		var menu := Control.new()
		menu.set_script(load("res://game/states/%s.gd" % screen))
		menu.set("context", ctx)
		root.add_child(menu)
		await process_frame
		var options: Array = menu.get("_options")
		_check(options.size() == 3 and (options[2]["card"] as GameData.Card).id == &"thick_hide", screen + " supply uses class, weapon and rank filters")
		_check(menu.call("reroll_supply") and ctx.rerolls == 1 and ctx.card_stacks.get(&"thick_hide", 0) == 0, screen + " reroll shares bank and does not grant a card")
		menu.call("_pick", 2)
		menu.call("_apply_supply")
		menu.call("_apply_supply")
		_check(ctx.card_stacks.get(&"thick_hide", 0) == 1 and ctx.max_hp == 115.0 and ctx.hp == 65.0, screen + " supply applies once, including instant HP")
		_check(not menu.call("reroll_supply"), screen + " cannot reroll an applied supply")
		menu.queue_free()
		await process_frame
		for c in GameData.cards():
			ctx.card_stacks[c.id] = c.max_stacks
		menu = Control.new()
		menu.set_script(load("res://game/states/%s.gd" % screen))
		menu.set("context", ctx)
		root.add_child(menu)
		await process_frame
		options = menu.get("_options")
		_check(not options[2].has("card") and options[2]["title"] == "Training: +20 HP", screen + " exhausted deck offers healing")
		menu.call("_pick", 2)
		menu.call("_apply_supply")
		_check(ctx.hp == 85.0, screen + " fallback heals 20 HP")
		menu.queue_free()
		await process_frame
	print("TEST: CARD CATALOG COMPLETE (%d failures)" % _failures)
	quit(1 if _failures > 0 else 0)
