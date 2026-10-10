extends SceneTree
## Kill drops, effects and carry-over, without rendering or a live profile.

var _failures: int = 0


func _initialize() -> void:
	if not FileAccess.file_exists("res://game/world/power_ups.gd"):
		_check(false, "kill-drop system exists")
		quit(1)
		return
	call_deferred("_run_tests")


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _run_tests() -> void:
	_test_drops()
	_test_shield()
	_test_effects()
	_test_rewards()
	_test_carry()
	await _test_handmade()
	quit(1 if _failures > 0 else 0)


func _open_run() -> IslandRun:
	var map := IslandMap.new()
	map.field = FlowField.new(100, 100)
	map.player_start = Vector3(30.5, 0, 30.5)
	map.boat = Vector3(5.5, 0, 5.5)
	map.generators = [Vector3(10.5, 0, 10.5), Vector3(50.5, 0, 50.5), Vector3(80.5, 0, 80.5)]
	return IslandRun.new(21, &"beach", map)


func _kill_drop(p: PowerUps, run: IslandRun, now: float, kind: int = GameData.EnemyKind.WALKER, finite: bool = true) -> bool:
	return p.on_kill(kind, run.player_pos, now, run.field, run.play_area, finite)


func _test_drops() -> void:
	var run := _open_run()
	var p := PowerUps.new(1)
	var state: int = p.rng.state
	for i in 100:
		_kill_drop(p, run, 34.9)
	_check(p.ground_kind == &"" and p.rng.state == state, "cooldown prevents early drops and consumes no RNG")
	_check(_kill_drop(p, run, 35.0), "pity waits for the cooldown, then guarantees the next eligible drop")
	var first: StringName = p.ground_kind
	for i in 100:
		_kill_drop(p, run, 80.0)
	_check(p.ground_kind == first and p.ground_time == 25.0, "an occupied ground slot cannot be replaced")
	p.tick(15.5)
	var visible: bool = p.blinking_visible()
	p.tick(0.25)
	_check(p.ground_time < 10.0 and visible != p.blinking_visible(), "drop blinks in its final ten seconds")
	p.tick(10.0)
	_check(p.ground_kind == &"" and p.ground_time == 0.0, "uncollected drop expires after 25 seconds")
	_check(not _kill_drop(p, run, 69.9) and _kill_drop(p, run, 70.0), "drops are at least 35 seconds apart")
	var a := PowerUps.new(22)
	var b := PowerUps.new(22)
	var same: bool = true
	for i in 1000:
		var now: float = 40.0 + i * 36.0
		same = same and _kill_drop(a, run, now) == _kill_drop(b, run, now)
		same = same and a.ground_kind == b.ground_kind
		a.tick(36.0)
		b.tick(36.0)
	_check(same and a.rng.state == b.rng.state, "same seed and kill sequence produce identical drops")
	var normal: int = 0
	var special: int = 0
	var ammo_offered: bool = false
	for i in 1000:
		var n := PowerUps.new(i + 1)
		var s := PowerUps.new(i + 1)
		normal += int(_kill_drop(n, run, 35.0))
		special += int(_kill_drop(s, run, 35.0, GameData.EnemyKind.BRUTE))
		n.kills_without_drop = GameData.POWER_UP_PITY_KILLS
		n.ground_kind = &""
		n.next_drop_at = 0.0
		_kill_drop(n, run, 100.0, GameData.EnemyKind.WALKER, false)
		ammo_offered = ammo_offered or n.ground_kind == &"max_ammo"
	_check(special > normal * 2, "special enemies have a higher drop chance (%d vs %d)" % [special, normal])
	_check(not ammo_offered, "Max Ammo is excluded when no finite weapon is owned")
	var before_rng: int = run.rng.state
	var before_card: int = run.card_offers.rng.state
	p.ground_kind = &""
	_kill_drop(p, run, 110.0)
	_check(run.rng.state == before_rng and run.card_offers.rng.state == before_card, "drops do not perturb combat or card RNG")
	var isolated := FlowField.new(30, 30)
	isolated.set_blocked_rect(14, 0, 16, 29)
	isolated.compute_now(Vector2i(5, 5))
	_check(not PowerUps.drop_position(Vector3(24, 0, 5), isolated, PackedVector2Array()).is_finite(), "no drop in a disconnected region")
	_check(not PowerUps.drop_position(Vector3(-10, 0, -10), isolated, PackedVector2Array()).is_finite(), "no drop outside the map")
	p = PowerUps.new(7)
	p.kills_without_drop = GameData.POWER_UP_PITY_KILLS
	p.on_kill(0, Vector3(24, 0, 5), 40.0, isolated, PackedVector2Array(), true)
	_check(p.ground_kind == &"" and p.kills_without_drop >= GameData.POWER_UP_PITY_KILLS, "invalid ground preserves pity for the next reachable kill")
	for mission in [&"activate", &"defend", &"rescue", &"holdout"]:
		run.set_mission(mission)
		run.time_alive = 40.0
		run.power_ups.ground_kind = &""
		run.power_ups.next_drop_at = 0.0
		run.power_ups.kills_without_drop = GameData.POWER_UP_PITY_KILLS
		run.horde.add(run.player_pos + Vector3(2, 0, 0), 0, run.rng)
		run._damage(run.horde.count - 1, 10000.0, run.player_pos, false, true)
		_check(run.power_ups.ground_kind != &"", "real kill triggers a drop in %s" % mission)
		run._flush_dead()
		var kills: int = run.kills
		run._collect_power_up()
		_check(run.kills == kills, "pickup does not fabricate kills")


func _test_shield() -> void:
	var run := _open_run()
	run.add_shield(30.0)
	run._take_player_damage(20.0)
	_check(run.shield == 10.0 and run.hp == 100.0, "shield absorbs damage before HP")
	run._take_player_damage(25.0)
	_check(run.shield == 0.0 and run.hp == 85.0, "overflow damage reaches HP")
	run.add_shield(1000.0)
	run.add_shield(-5.0)
	_check(run.shield == run.max_shield, "shield gain is capped and negative gain is ignored")
	run.noclip = true
	run._take_player_damage(500.0)
	_check(run.hp == 85.0 and run.shield == run.max_shield, "noclip protects both shield and health")


func _test_effects() -> void:
	var run := _open_run()
	run.apply_power_up(&"insta_kill")
	run.horde.add(Vector3(35, 0, 30), GameData.EnemyKind.WALKER, run.rng)
	run.horde.add(Vector3(35, 0, 32), GameData.EnemyKind.BRUTE, run.rng)
	run._damage(0, 1.0, run.player_pos, false, false)
	var strong_hp: float = run.horde.hp[1]
	run._damage(1, 10.0, run.player_pos, false, false)
	_check(run.kills == 1 and run.horde.hp[1] == strong_hp - 20.0, "Insta-Kill kills a normal in one shot and doubles strong-enemy damage")
	run.horde.add(Vector3(35, 0, 33), GameData.EnemyKind.RUNNER, run.rng)
	run._damage(2, 1.0, run.player_pos, false, true)
	_check(run.horde.hp[2] > 0.0, "Insta-Kill applies to shots, not breaker or secondary damage")
	run.power_ups.tick(26.0)
	run._damage(2, 1.0, run.player_pos, false, false)
	_check(run.horde.hp[2] > 0.0 and run.power_ups.insta_time == 0.0, "Insta-Kill expires")
	run = _open_run()
	run.field.set_blocked_rect(40, 0, 40, 99)
	run.field.compute_now(run.field.world_to_cell(run.player_pos))
	for entry in [[Vector3(35, 0, 30), GameData.EnemyKind.WALKER], [Vector3(35, 0, 32), GameData.EnemyKind.BRUTE],
			[Vector3(35, 0, 34), GameData.EnemyKind.BOSS], [Vector3(45, 0, 30), GameData.EnemyKind.WALKER],
			[Vector3(30, 0, 80), GameData.EnemyKind.WALKER]]:
		run.horde.add(entry[0], entry[1], run.rng)
	var brute: float = run.horde.hp[1]
	var boss: float = run.horde.hp[2]
	run.apply_power_up(&"nuke")
	_check(run.kills == 1 and run.horde.hp[1] > 0.0 and run.horde.hp[1] < brute and run.horde.hp[2] > 0.0 and run.horde.hp[2] < boss,
		"Nuke kills nearby normals and damages strong enemies and the boss")
	_check(run.horde.hp[3] > 0.0 and run.horde.hp[4] > 0.0, "Nuke respects walls and its 40 m radius")
	var count: int = run.horde.count
	run._spawn_enemy()
	_check(run.horde.count == count and run.power_ups.spawn_delay == 5.0, "Nuke blocks director spawns for five seconds")
	run.power_ups.tick(5.0)
	_check(run.power_ups.spawn_delay == 0.0, "Nuke spawn suppression expires")
	for player_class in GameData.CLASSES:
		run.player_class = player_class
		run.breaker_cd = 4.0
		run.grenade_cd = 6.0
		run.apply_power_up(&"full_power")
		_check(run.breaker_cd == 0.0 and run.grenade_cd == 0.0, "Full Power readies breaker and %s ability" % player_class)
	run.apply_power_up(&"max_armor")
	_check(run.shield == run.max_shield, "Max Armor fills the shield")
	run.rerolls = 0
	run.apply_power_up(&"fire_sale")
	_check(run.rerolls == 1, "Fire Sale grants one reroll")
	run.rerolls = GameData.REROLLS_MAX
	run.apply_power_up(&"fire_sale")
	_check(run.rerolls == GameData.REROLLS_MAX, "Fire Sale respects the reroll cap")
	run.card_stacks[&"bigger_mags"] = 2
	run.ammo[1] = 0
	var locked_ammo: int = run.ammo[4]
	run.apply_power_up(&"max_ammo")
	_check(run.ammo[0] == -1 and run.ammo[1] == run.max_ammo(1) and run.ammo[4] == locked_ammo, "Max Ammo refills owned specials to their modified capacity; infinite and locked weapons stay unchanged")
	run = _open_run()
	run.power_ups.ground_kind = &"max_armor"
	run.power_ups.ground_time = 25.0
	run.power_ups.ground_pos = run.player_pos
	run._collect_power_up()
	run._collect_power_up()
	_check(run.shield == 100.0 and run.power_ups_picked == [&"max_armor"] and run.messages.has("MAX ARMOR!"), "walking onto a drop collects once and produces a toast event")


func _test_rewards() -> void:
	var run := _open_run()
	run.kills = 10
	_check(run.intel_earned() == 2, "Intel before Double Rewards is unchanged")
	run.apply_power_up(&"double_rewards")
	run.orbs.append(run.player_pos)
	run.orb_values.append(3)
	run._update_orbs(0.1)
	_check(run.xp == 6, "Double Rewards doubles XP on collection")
	for i in 5:
		run.horde.add(Vector3(35, 0, 30), 0, run.rng)
		run._damage(i, 1000.0, run.player_pos, false, true)
	_check(run.intel_earned() == 4, "only newly earned kill Intel is doubled")
	run.cache_intel += 10
	run.generator_progress[0] = GameData.GENERATOR_HOLD_SECONDS
	_check(run.intel_earned() == 54, "Double Rewards also credits caches and objective Intel")
	run._sync_intel_bonus()
	run.power_ups.tick(26.0)
	_check(run.intel_earned() == 54, "earned bonus Intel survives buff expiry")
	run.kills += 5
	_check(run.intel_earned() == 55, "subsequent Intel uses the normal rate")
	run.apply_power_up(&"double_rewards")
	_check(run.intel_earned() == 55, "refreshing Double Rewards does not double previous earnings")
	run.power_ups.tick(2.0)
	run.apply_power_up(&"double_rewards")
	_check(run.power_ups.double_time == 25.0, "repeated timed pickups refresh instead of stacking multipliers")
	var time: float = run.power_ups.double_time
	run.card_choices.append(run.all_cards[0])
	run.step(1.0, Vector2.ZERO, Vector3.FORWARD, false)
	_check(run.power_ups.double_time == time, "card-choice pause freezes power-up timers")
	var fatal := _open_run()
	fatal.apply_power_up(&"double_rewards")
	fatal.objective = IslandRun.Objective.WON
	fatal.hp = 0.0
	fatal.horde.add(fatal.player_pos + Vector3(2, 0, 0), 0, fatal.rng)
	fatal._damage(0, 1000.0, fatal.player_pos, false, true)
	fatal.objective = IslandRun.Objective.LOST
	_check(fatal.intel_earned() == 0, "fatal extraction frame cannot bank a bonus for a failed extraction")


func _test_carry() -> void:
	var ctx := RunContext.new(71)
	var run := _open_run()
	run.load_context(ctx)
	run.apply_power_up(&"max_armor")
	run.apply_power_up(&"insta_kill")
	run.apply_power_up(&"double_rewards")
	run.power_ups.tick(3.0)
	run.time_alive = 40.0
	run.power_ups.kills_without_drop = 17
	run.power_ups.next_drop_at = 70.0
	run.objective = IslandRun.Objective.LOST
	run.save_to_context(ctx)
	var next := _open_run()
	next.load_context(ctx)
	_check(next.shield == 100.0 and next.power_ups.insta_time == 22.0 and next.power_ups.double_time == 22.0,
		"shield and remaining active effects cross island/part boundaries")
	_check(next.power_ups.rng.state == run.power_ups.rng.state and next.power_ups.next_drop_at == 70.0 and next.power_ups.kills_without_drop == 17,
		"drop RNG, cooldown and pity cross boundaries")
	_check(ctx.island_log[0]["power_ups"].size() == 3 and ctx.island_log[0]["shield_left"] == 100, "run telemetry records pickups, shield and bonus Intel")


func _test_handmade() -> void:
	var island: HandmadeIsland = (load(HandmadeIsland.ISLANDS_DIR + "beach_01.tscn") as PackedScene).instantiate()
	island.play_area = PackedVector2Array([Vector2(50, 0), Vector2(256, 0), Vector2(256, 256), Vector2(50, 256)])
	var problems: Array[String] = []
	var map: IslandMap = island.build_map(problems)
	var run := IslandRun.new(71, &"beach", map)
	run.play_area = island.play_area
	var ctx := RunContext.new(71)
	ctx.start_expedition(&"berlenga", 1)
	run.load_context(ctx)
	run.time_alive = 40.0
	run.power_ups.kills_without_drop = GameData.POWER_UP_PITY_KILLS
	run.horde.add(run.player_pos + Vector3(2, 0, 0), 0, run.rng)
	run._damage(0, 1000.0, run.player_pos, false, true)
	var p: Vector3 = run.power_ups.ground_pos
	_check(run.power_ups.ground_kind != &"" and run.field.distance_at(p) < FlowField.UNREACHABLE
		and not Horde.overlaps_wall(run.field, p.x, p.z, GameData.PLAYER_RADIUS)
		and Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), run.play_area), "real handmade expedition-part kill drops within reachable play area")
	_check(not PowerUps.drop_position(Vector3(20, 0, 50), run.field, run.play_area).is_finite(), "expedition drops never spill outside their polygon")
	island.free()
	await process_frame
