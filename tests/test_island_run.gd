extends SceneTree
## Headless tests for the vertical slice rules (game/world/island_run.gd).
## Run: godot --headless --path . --script res://tests/test_island_run.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


func _initialize() -> void:
	_test_map_is_playable()
	_test_hitscan_orders_and_pierces()
	_test_auto_fire_kills_and_drops_xp()
	_test_cards_on_level_up()
	_test_breaker_frees_grab()
	_test_mission_flow()
	_test_bot_survives_a_while()
	_test_profile_roundtrip()
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
