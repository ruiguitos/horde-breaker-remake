extends SceneTree
## Headless tests for the vertical slice rules (game/world/island_run.gd).
## Run: godot --headless --path . --script res://tests/test_island_run.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


func _initialize() -> void:
	_test_map_is_playable()
	_test_hitscan_orders_and_pierces()
	_test_auto_fire_kills_and_drops_xp()
	_test_enemy_xp_rewards()
	_test_cards_on_level_up()
	_test_breaker_frees_grab()
	_test_mission_flow()
	_test_bot_survives_a_while()
	_test_profile_roundtrip()
	_test_grenade()
	_test_perks_and_threat()
	_test_meta_shop()
	_test_boss_fight()
	_test_modifiers()
	_test_weapon_unlocks()
	_test_bloater_and_screamer()
	_test_sprint()
	_test_classes()
	_test_caches()
	_test_target_priority()
	_test_input_actions()
	_test_missions()
	_test_story()
	_test_spawn_sectors()
	if _failures > 0:
		print("TEST FAIL: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		print("TEST FAIL: " + what)
		_failures += 1


func _test_map_is_playable() -> void:
	var run := IslandRun.new(7)
	var f: FlowField = run.field
	var ok: bool = not Horde.overlaps_wall(f, run.player_pos.x, run.player_pos.z, GameData.PLAYER_RADIUS)
	for g in run.map.generators:
		ok = ok and f.distance_at(g) < FlowField.UNREACHABLE
	ok = ok and f.distance_at(run.map.boat) < FlowField.UNREACHABLE
	_check(ok, "player start is free; boat and generators are reachable")


func _test_hitscan_orders_and_pierces() -> void:
	var f := FlowField.new(40, 20)
	var h := Horde.new(f)
	var rng := RandomNumberGenerator.new()
	h.add(Vector3(20, 0, 5), 0, rng)
	h.add(Vector3(10, 0, 5), 0, rng)
	h.add(Vector3(15, 0, 5), 0, rng)
	var hits: Array[Vector2] = h.hitscan(Vector3(2, 0, 5), Vector3(1, 0, 0), 50.0, 2)
	_check(hits.size() == 2 and int(hits[0].y) == 1 and int(hits[1].y) == 2, "hitscan returns the 2 nearest in order")
	f.set_blocked_rect(12, 0, 12, 19)
	hits = h.hitscan(Vector3(2, 0, 5), Vector3(1, 0, 0), 50.0, 3)
	_check(hits.size() == 1, "walls stop piercing shots")


func _test_auto_fire_kills_and_drops_xp() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0  # no director spawns
	var p: Vector3 = run.player_pos
	run.horde.add(p + Vector3(0, 0, -8), GameData.EnemyKind.WALKER, run.rng)
	for t in 120:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.kills == 1 and run.headshots == 1, "auto-fire kills the walker in front with a headshot")
	_check(run.orbs.size() == 1 or run.xp > 0, "the kill drops an XP orb")
	run.horde.add(p + Vector3(0, 0, 8), GameData.EnemyKind.WALKER, run.rng)
	for t in 30:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.kills == 1, "auto-fire ignores enemies behind the player")


func _test_enemy_xp_rewards() -> void:
	var rewards: Array[int] = [10, 12, 100, 45, 1000, 45, 60]
	for kind in rewards.size():
		for boosted in [false, true]:
			var run := IslandRun.new(7)
			run.level = 20
			if boosted:
				run.card_stacks[&"fast_learner"] = 4
				run.power_ups.double_time = 25.0
			run.horde.add(run.player_pos, kind, run.rng)
			run._damage(0, 10000.0, run.player_pos, false, true, true)
			_check(run.kills == 1 and run.orb_values == PackedInt32Array([rewards[kind]]) and run.xp == 0,
				"enemy %d drops %d XP without granting it before collection" % [kind, rewards[kind]])
			run._update_orbs(0.0)
			var expected: float = rewards[kind] * (2.4 if boosted else 1.0)
			_check(is_equal_approx(run.xp_progress(), expected) and run.orbs.is_empty(),
				"enemy %d pickup grants %.2f XP (boosted: %s)" % [kind, expected, boosted])
	var run := IslandRun.new(7)
	for kill in 15:
		run.horde.add(run.player_pos, GameData.EnemyKind.WALKER, run.rng)
		run._damage(0, 1000.0, run.player_pos, false, true, true)
		run._flush_dead()
		run._update_orbs(0.0)
		if kill == 13:
			_check(run.level == 1 and run.xp == 140 and run.card_choices.is_empty(), "fourteen Walkers leave level 1 at 140/150 XP")
	_check(run.level == 2 and run.xp == 0 and run.card_choices.size() == 3,
		"fifteen Walkers still reach level 2 and offer three cards")


func _test_cards_on_level_up() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	run.orbs.append(run.player_pos)
	run.orb_values.append(run.xp_needed())
	run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.level == 2 and run.card_choices.size() == 3 and run.is_paused(), "level up offers 3 cards and pauses")
	var id: StringName = run.card_choices[0].id
	run.choose_card(0)
	_check(run.stacks(id) == 1 and not run.is_paused(), "choosing a card applies it and resumes")


func _test_breaker_frees_grab() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	run.weapon_index = 0
	var p: Vector3 = run.player_pos
	run.horde.add(p + Vector3(0.9, 0, 0), GameData.EnemyKind.GRABBER, run.rng)
	# Face away so auto-fire does not kill it first.
	for t in 60:
		run.step(DT, Vector2.ZERO, Vector3(-1, 0, 0), false)
	var grabbed: bool = run.horde.grabbed_by != -1
	var before: Vector3 = run.player_pos
	run.step(DT, Vector2(1, 0), Vector3(-1, 0, 0), false)
	var stuck: bool = run.player_pos.distance_to(before) < 0.001
	run.step(DT, Vector2(0, -1), Vector3(-1, 0, 0), true)
	_check(grabbed and stuck and run.horde.grabbed_by == -1, "grabber holds the player; the breaker frees them")


func _test_mission_flow() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	for g in run.map.generators:
		run.player_pos = g
		for t in int(GameData.GENERATOR_HOLD_SECONDS / DT) + 2:
			run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "holding the 3 generators unlocks the return")
	run.player_pos = run.map.boat
	run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() >= 85, "reaching the boat wins (intel %d)" % run.intel_earned())


## A simple bot walks between generators facing the nearest enemy.
func _test_bot_survives_a_while() -> void:
	var run := IslandRun.new(3)
	var max_alive: int = 0
	var t0: int = Time.get_ticks_usec()
	var frames: int = 0
	for t in 60 * 90:
		if run.is_over():
			break
		if not run.card_choices.is_empty():
			run.choose_card(0)
		var goal: Vector3 = run.map.boat
		for g in GameData.GENERATOR_COUNT:
			if run.generator_progress[g] < GameData.GENERATOR_HOLD_SECONDS:
				goal = run.map.generators[g]
				break
		var to_goal: Vector3 = goal - run.player_pos
		var move := Vector2(to_goal.x, to_goal.z)
		move = move.normalized() if move.length() > 1.0 else Vector2.ZERO
		var aim: Vector3 = Vector3(move.x, 0, move.y)
		var near: PackedInt32Array = run.horde.query_radius(run.player_pos, 15.0)
		if near.size() > 0:
			aim = run.horde.positions[near[0]] - run.player_pos
		run.step(DT, move, aim, near.size() > 12 and run.breaker_cd <= 0.0)
		max_alive = maxi(max_alive, run.horde.count)
		frames += 1
	var ms: float = (Time.get_ticks_usec() - t0) / 1000.0 / maxf(1.0, frames)
	print("  bot: %.0f s, objective %s, kills %d, level %d, hp %.0f, max alive %d, %.2f ms/step" % [
		run.time_alive, run.objective_text(), run.kills, run.level, run.hp, max_alive, ms])
	_check(run.kills > 20 and max_alive <= GameData.MAX_ALIVE, "bot run: enemies spawn, die and stay under the cap")


func _test_profile_roundtrip() -> void:
	var path: String = "user://test_profile.json"
	var ctx := RunContext.new(5)
	ctx.intel = 42
	ctx.kills = 300
	ctx.won = true
	var p := Profile.new()
	p.record_run(ctx)
	p.save(path)
	var q: Profile = Profile.load_profile(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(q.intel == 42 and q.runs == 1 and q.extractions == 1 and q.best_kills == 300, "profile saves and loads Intel and stats")


func _test_grenade() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	var target: Vector3 = run.player_pos + Vector3(0, 0, 8)
	for k in 6:
		run.horde.add(target + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), GameData.EnemyKind.WALKER, run.rng)
	# Face away so only the grenade can kill them.
	var thrown: bool = run.throw_grenade(Vector3(0, 0, 8))
	var again: bool = run.throw_grenade(Vector3(0, 0, 8))
	for t in 60:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(thrown and not again and run.kills == 6, "grenade kills the group; cooldown blocks a 2nd throw (kills %d)" % run.kills)


func _test_perks_and_threat() -> void:
	var ctx := RunContext.new(9)
	ctx.threat = 3
	var perks: Array[StringName] = [&"thick_skin", &"pack_rat"]
	ctx.apply_perks(perks)
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	_check(run.max_hp == 130.0 and run.hp == 130.0, "Thick Skin gives 130 max HP")
	_check(run.ammo[1] == 60 and run.ammo[0] == -1, "Pack Rat gives +50% secondary ammo; primary stays infinite")
	_check(is_equal_approx(run.horde.hp_scale, 1.4) and run.director.max_alive == 200, "Threat 3: enemy HP x1.4 and 200 alive")


func _test_meta_shop() -> void:
	var p := Profile.new()
	p.intel = 120
	var bought: bool = p.buy_rank(&"combat_1")
	var equipped: bool = p.toggle_equip(&"head_hunter")
	p.buy_rank(&"survival_1")
	var no_slot: bool = p.toggle_equip(&"thick_skin")
	var slot: bool = p.buy_slot()
	_check(bought and equipped and not no_slot and not slot and p.intel == 40,
		"buying perk ranks costs Intel and equipping respects slots")
	var ctx := RunContext.new(1)
	ctx.won = true
	ctx.threat = 1
	p.record_run(ctx)
	_check(p.max_threat == 2, "extracting on the highest Threat unlocks the next")


func _test_boss_fight() -> void:
	var ctx := RunContext.new(11)
	ctx.island_index = RunContext.ISLAND_COUNT - 1
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	run.director.max_alive = 0
	for g in GameData.GENERATOR_COUNT:
		run.generator_progress[g] = GameData.GENERATOR_HOLD_SECONDS
	run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	var b: int = run.boss_index()
	_check(run.objective == IslandRun.Objective.BOSS and b != -1, "last island: generators done spawn the Behemoth")
	# Stand next to it, facing away so auto-fire does not interfere.
	var bp: Vector3 = run.horde.positions[b]
	run.player_pos = bp + Vector3(2.5, 0, 0)
	run.hp = 1000.0
	var saw_windup: bool = false
	var hp_before: float = run.hp
	for t in 260:
		run.step(DT, Vector2.ZERO, Vector3(1, 0, 0), false)
		saw_windup = saw_windup or run.slam_time > 0.0
		run.horde.positions[run.boss_index()] = bp  # keep it in place for the test
	_check(saw_windup and run.hp <= hp_before - GameData.BOSS_SLAM_DAMAGE, "the slam is telegraphed and hurts inside the ring")
	# Keep away: the boss throws a rock that lands where the player stood.
	run.player_pos = bp + Vector3(16, 0, 0)
	run.hp = 1000.0
	var hp_far: float = run.hp
	var threw: bool = false
	for t in 330:
		run.step(DT, Vector2.ZERO, Vector3(1, 0, 0), false)
		threw = threw or run.rocks.size() > 0
		run.horde.positions[run.boss_index()] = bp
	_check(threw and run.hp < hp_far, "keeping away from the boss gets you hit by thrown rocks")
	b = run.boss_index()
	run.horde.hp[b] = run.boss_max_hp * 0.4
	run.step(DT, Vector2.ZERO, Vector3(1, 0, 0), false)
	_check(run.boss_enraged and run.horde.speeds[run.boss_index()] > 2.5, "below half HP the boss enrages (phase 2)")
	b = run.boss_index()
	run.horde.hp[b] = 1.0
	run.player_pos = bp + Vector3(6, 0, 0)
	for t in 240:
		if run.boss_index() == -1:
			break
		run.step(DT, Vector2.ZERO, Vector3(-1, 0, 0), false)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT and run.boss_killed and run.intel_earned() >= 65,
		"killing the boss unlocks the return and gives Intel (%d)" % run.intel_earned())


func _test_modifiers() -> void:
	var ctx := RunContext.new(3)
	ctx.modifier = &"short"
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	_check(run.ammo[1] == 20 and run.ammo[0] == -1, "Supply Shortage halves secondary ammo; primary stays infinite")
	ctx.modifier = &"swarm"
	var run2 := IslandRun.new(ctx.island_seed())
	run2.load_context(ctx)
	run2.kills = 50
	_check(run2.director.max_alive == GameData.MAX_ALIVE + 40 and run2.intel_earned() == 13,
		"Swarm adds 40 alive and pays Intel x1.3 (%d)" % run2.intel_earned())


func _test_weapon_unlocks() -> void:
	var run := IslandRun.new(5)
	run.switch_weapon(3)
	var locked: bool = run.weapon_index == 0
	var p := Profile.new()
	p.intel = 70
	var bought: bool = p.buy_weapon(&"smg")
	var too_poor: bool = not p.buy_weapon(&"marksman")
	var ctx := RunContext.new(5)
	ctx.weapons.append_array(p.unlocked_weapons)
	var run2 := IslandRun.new(5)
	run2.load_context(ctx)
	_check(locked and bought and too_poor and run2.weapon_index == 0 and run2.weapons[0].id == &"smg",
		"selected SMG replaces the primary on key 1")


func _test_bloater_and_screamer() -> void:
	var run := IslandRun.new(5)
	run.director.max_alive = 0
	var p: Vector3 = run.player_pos + Vector3(0, 0, -10)
	var b: int = run.horde.add(p, GameData.EnemyKind.BLOATER, run.rng)
	for k in 4:
		run.horde.add(p + Vector3(cos(k * 1.6), 0, sin(k * 1.6)) * 1.5, GameData.EnemyKind.WALKER, run.rng)
	var kills_before: int = run.kills
	run._damage(b, 1000.0, run.player_pos, false, false)  # pop the Bloater directly
	run._flush_dead()
	_check(run.kills - kills_before >= 4, "a Bloater's death blast kills nearby walkers (%d kills)" % (run.kills - kills_before))
	var run2 := IslandRun.new(5)
	run2.director.max_alive = 0
	var s: int = run2.horde.add(run2.player_pos + Vector3(0, 0, 15), GameData.EnemyKind.SCREAMER, run2.rng)
	run2.horde.hp[s] = 100000.0
	var phase_before: int = run2.director.phase
	for t in int(GameData.SCREAM_TIME / DT) + 30:
		run2.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)  # facing away: it survives
	_check(run2.director.phase == Director.Phase.PEAK and phase_before != Director.Phase.PEAK,
		"a Screamer in sight for 3 s triggers a horde peak")


func _test_sprint() -> void:
	var run := IslandRun.new(5)
	run.director.max_alive = 0
	var start: Vector3 = run.player_pos
	run.horde.add(start + Vector3(0, 0, -8), GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[0] = 10.0
	run.horde.hp[0] = 100000.0
	var mag_before: int = run.mag[0]
	for t in 30:
		run.step(DT, Vector2(1, 0), Vector3(0, 0, -1), false, true)
	var sprint_dist: float = run.player_pos.distance_to(start)
	var shots: int = mag_before - run.mag[0]
	_check(shots > 0 and sprint_dist > 0.5 * GameData.PLAYER_SPEED * GameData.SPRINT_MULTIPLIER * 0.9,
		"sprinting is faster and the gun keeps firing (%.2f m in 0.5 s, %d shots)" % [sprint_dist, shots])
	for t in int(GameData.STAMINA_MAX / DT) + 10:
		run.step(DT, Vector2(-1, 0), Vector3(0, 0, -1), false, true)
	_check(run.stamina == 0.0 and not run.sprinting, "stamina runs out and sprint stops")


func _test_classes() -> void:
	var ctx := RunContext.new(8)
	ctx.apply_class(&"vanguard")
	var perks: Array[StringName] = []
	ctx.apply_perks(perks)
	var run := IslandRun.new(8)
	run.load_context(ctx)
	run.director.max_alive = 0
	run.horde.add(run.player_pos + Vector3(3, 0, 0), GameData.EnemyKind.WALKER, run.rng)
	var cried: bool = run.use_ability(Vector3.ZERO)
	_check(run.max_hp == 140.0 and cried and run.horde.stun[0] > 1.0 and run.war_cry_time > 0.0,
		"Vanguard: 140 HP, War Cry stuns nearby enemies")
	var p := Profile.new()
	p.intel = 100
	_check(not p.buy_class(&"vanguard"), "classes need enough Intel")
	p.intel = 160
	_check(p.buy_class(&"vanguard") and p.intel == 10, "classes are bought with Intel")
	var old := Profile.from_dict({"unlocked_classes": ["recruit", "medic"], "selected_class": "medic"})
	_check(old.selected_class == &"recruit" and not old.unlocked_classes.has(&"medic"), "removed Field Medic falls back to Recruit")


func _test_caches() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	var reachable: bool = run.map.caches.size() == 4
	for c in run.map.caches:
		reachable = reachable and run.field.distance_at(c) < FlowField.UNREACHABLE
	run.player_pos = run.map.caches[0]
	for t in int(GameData.CACHE_OPEN_TIME / DT) + 5:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(reachable and run.cache_progress[0] >= GameData.CACHE_OPEN_TIME, "4 reachable caches; standing at one opens it")


func _test_target_priority() -> void:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	var p: Vector3 = run.player_pos
	var side: int = run.horde.add(p + Vector3(-3.5, 0, -5), GameData.EnemyKind.WALKER, run.rng)  # nearer, ~35° off
	var ahead: int = run.horde.add(p + Vector3(0, 0, -9), GameData.EnemyKind.BRUTE, run.rng)  # farther, dead ahead
	run.facing = Vector3(0, 0, -1)
	var range_m: float = run.weapons[run.weapon_index].range_m
	_check(run._pick_target(range_m) == ahead and run._is_headshot(ahead), "facing an enemy makes it the target (headshot) over a nearer one off to the side")
	run.horde.positions[side] = p + Vector3(-1.0, 0, -1.6)
	_check(run._pick_target(range_m) == side, "an enemy within 2.5 m always takes priority")


func _test_input_actions() -> void:
	GameInput.setup()
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	var pad_a := InputEventJoypadButton.new()
	pad_a.button_index = JOY_BUTTON_A
	pad_a.pressed = true
	var g := InputEventKey.new()
	g.physical_keycode = KEY_G
	g.pressed = true
	_check(space.is_action_pressed(&"breaker") and pad_a.is_action_pressed(&"breaker") and g.is_action_pressed(&"ability")
		and not space.is_action_pressed(&"ability"), "InputMap actions: Space and pad A break, G uses the ability")


func _test_missions() -> void:
	var run := IslandRun.new(9)
	run.set_mission(&"defend")
	run.director.max_alive = 0
	run.player_pos = run.site
	for t in int(GameData.DEFEND_TIME / DT) + 5:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.objective == IslandRun.Objective.RETURN_TO_BOAT, "Defend: holding the zone for 75 s completes the mission")
	var r := IslandRun.new(9)
	r.set_mission(&"rescue")
	r.director.max_alive = 0
	r.player_pos = r.site
	r.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(r.survivor_found and r.objective == IslandRun.Objective.RETURN_TO_BOAT, "Rescue: reaching the survivor starts the escort")
	r.player_pos = r.map.boat
	r.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(r.objective != IslandRun.Objective.WON, "Rescue: you cannot leave without the survivor")
	r.survivor_pos = r.map.boat
	r.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(r.objective == IslandRun.Objective.WON and r.intel_earned() >= 80, "Rescue: survivor at the boat wins with the bonus (%d)" % r.intel_earned())


func _test_story() -> void:
	var ctx := RunContext.new(4)
	ctx.mission = &"defend"
	var run := IslandRun.new(4)
	run.load_context(ctx)
	_check(run.radio.has(&"land_defend") and Story.radio_line(&"land_defend", run.rng) != "", "landing queues a mission briefing on the radio")
	var p := Profile.new()
	ctx.lore_found = 3
	p.record_run(ctx)
	_check(p.lore_pages == 3, "recovered Intel files are added to the profile")
	var all_keys: bool = true
	for k in [&"generator", &"boss", &"survivor_found", &"low_hp", &"screamer", &"cache"]:
		all_keys = all_keys and Story.RADIO.has(k)
	_check(all_keys and Story.FILES.size() >= 10, "every radio event has lines; 10 Intel files exist")


## An open 160 m map with the player in the middle (no walls in reach).
func _open_run(rng_seed: int) -> IslandRun:
	var map := IslandMap.new()
	map.field = FlowField.new(160, 160)
	map.player_start = Vector3(80.5, 0, 80.5)
	map.boat = Vector3(80.5, 0, 84.5)
	map.generators = [Vector3(100, 0, 100), Vector3(101, 0, 100), Vector3(100, 0, 101)]
	var run := IslandRun.new(rng_seed, &"beach", map)
	run.director.max_alive = 0
	return run


## Spawns come from every side: 4096 normal spawns and 4096 ring fallbacks
## on an open map, none of the 8 sectors above 20 %; every spot valid and at
## least SPAWN_MIN_DIST away; the same seed gives the same spots.
func _test_spawn_sectors() -> void:
	var mid: float = (GameData.SPAWN_MIN_DIST + GameData.SPAWN_MAX_DIST) * 0.5
	var radii: Array = [mid, GameData.SPAWN_MIN_DIST, GameData.SPAWN_MAX_DIST, 52.0, 60.0]
	for path in ["normal", "fallback"]:
		var run: IslandRun = _open_run(4242)
		# Normal spawns obey the director's limit (at most GameData.HORDE_CAP).
		run.director.max_alive = GameData.HORDE_CAP
		var c: Vector3 = run.player_pos
		var hist := PackedInt32Array()
		hist.resize(IslandRun.SPAWN_SECTORS)
		var valid: bool = true
		var n: int = 0
		for k in 4096:
			var p := Vector3.INF
			if path == "normal":
				run._spawn_enemy()
				if run.horde.count > 0:
					p = run.horde.positions[run.horde.count - 1]
					run.horde.remove(run.horde.count - 1)
			else:
				p = run._ring_spot(c, radii)
			if p == Vector3.INF:
				valid = false
				continue
			valid = valid and run.can_spawn_at(p) and Vector2(p.x - c.x, p.z - c.z).length() >= GameData.SPAWN_MIN_DIST - 0.01
			hist[IslandRun.spawn_sector(c, p)] += 1
			n += 1
		var top: float = 0.0
		var shares := PackedStringArray()
		for v in hist:
			top = maxf(top, float(v) / maxi(n, 1))
			shares.append("%.1f" % (100.0 * v / maxi(n, 1)))
		_check(n == 4096 and valid and top <= 0.20,
			"spawns (%s) on an open map: 8 sectors %s %%, max %.1f %%, all valid" % [path, " ".join(shares), top * 100.0])
	# Determinism: two runs with the same seed spawn on the same spots, and
	# the gameplay RNG does not move them.
	var a: IslandRun = _open_run(99)
	a.director.max_alive = GameData.HORDE_CAP
	var b: IslandRun = _open_run(99)
	b.director.max_alive = GameData.HORDE_CAP
	b.rng.randf()  # spawns have their own RNG
	var same: bool = true
	for k in 64:
		a._spawn_enemy()
		b._spawn_enemy()
		var pa: Vector3 = a._ring_spot(a.player_pos, radii)
		var pb: Vector3 = b._ring_spot(b.player_pos, radii)
		same = same and pa == pb and a.horde.positions[a.horde.count - 1] == b.horde.positions[b.horde.count - 1]
	_check(same and a.horde.count == 64, "same seed => same spawn spots (normal and fallback)")
	# A ring with only one quarter free: the fallback no longer piles the
	# spawns on one edge of the free arc.
	var q: IslandRun = _open_run(4242)
	for z in 160:
		for x in 160:
			if (x < 77 or z < 77) and (absi(x - 80) > 3 or absi(z - 80) > 3):
				q.field.blocked[z * 160 + x] = 1
	q.field.compute_now(q.field.world_to_cell(q.player_pos))
	var qh := PackedInt32Array()
	qh.resize(IslandRun.SPAWN_SECTORS)
	var q_valid: bool = true
	for k in 2048:
		var p: Vector3 = q._ring_spot(q.player_pos, radii)
		q_valid = q_valid and p != Vector3.INF and q.can_spawn_at(p)
		if p != Vector3.INF:
			qh[IslandRun.spawn_sector(q.player_pos, p)] += 1
	var q_top: int = 0
	for v in qh:
		q_top = maxi(q_top, v)
	_check(q_valid and q_top <= 2048 * 0.4, "quarter-open ring: no sector above 40 %% (max %.1f %%)" % (100.0 * q_top / 2048.0))
