extends SceneTree
## Soak test: a bot plays a full 3-island run (generators, boss, boat) on the
## real rules, navigating with its own flow field towards the current goal.
## The bot cannot die (HP is topped up) so the test checks the run is always
## completable and that nothing errors over many minutes of simulated play.
## Run: godot --headless --path . --script res://tests/test_soak_run.gd

const DT: float = 1.0 / 60.0
const MAX_SECONDS_PER_ISLAND: float = 600.0

var _failures: int = 0


func _initialize() -> void:
	for run_seed in [101, 202]:
		_soak(run_seed)
	quit(1 if _failures > 0 else 0)


func _soak(run_seed: int) -> void:
	var ctx := RunContext.new(run_seed)
	ctx.threat = 2
	var perks: Array[StringName] = []
	ctx.apply_perks(perks)
	var t0: int = Time.get_ticks_msec()
	for island in RunContext.ISLAND_COUNT:
		ctx.island_index = island
		ctx.modifier = GameData.modifiers()[(run_seed + island) % GameData.modifiers().size()].id
		var run := IslandRun.new(ctx.island_seed())
		run.load_context(ctx)
		var nav := FlowField.new(run.field.width, run.field.height)
		nav.blocked = run.field.blocked
		var goal := Vector3.INF
		var steps: int = 0
		while not run.is_over() and steps < int(MAX_SECONDS_PER_ISLAND / DT):
			steps += 1
			if not run.card_choices.is_empty():
				run.choose_card(0)
			run.hp = 10000.0  # invincible: this test checks completability, not balance
			var g: Vector3 = _goal(run)
			g = Vector3(floorf(g.x) + 0.5, 0, floorf(g.z) + 0.5)  # recompute only when the cell changes
			if g != goal:
				goal = g
				nav.compute_now(nav.world_to_cell(goal))
			var move := Vector2.ZERO
			var step: Vector2 = nav.direction_at(run.player_pos)
			if step != Vector2.ZERO:
				var c := Vector2(floori(run.player_pos.x) + step.x + 0.5, floori(run.player_pos.z) + step.y + 0.5)
				move = (c - Vector2(run.player_pos.x, run.player_pos.z)).normalized()
			elif run.player_pos.distance_to(goal) > 0.5:
				move = Vector2(goal.x - run.player_pos.x, goal.z - run.player_pos.z).normalized()
			var near: PackedInt32Array = run.horde.query_radius(run.player_pos, 20.0)
			var aim := Vector3(move.x, 0, move.y)
			if near.size() > 0:
				aim = run.horde.positions[near[0]] - run.player_pos
			if run.boss_index() != -1:
				aim = run.horde.positions[run.boss_index()] - run.player_pos
			run.step(DT, move, aim, near.size() > 10)
			if steps % 600 == 0:
				run.use_ability(aim)
		var ok: bool = run.objective == IslandRun.Objective.WON
		print("%s seed %d island %d (%s): %s in %.0f s, kills %d, level %d, boss %s" % [
			"TEST:" if ok else "TEST FAIL:", run_seed, island + 1, ctx.modifier, run.objective_text(),
			run.time_alive - ctx.time_alive, run.kills - ctx.kills, run.level, run.boss_killed])
		if not ok:
			_failures += 1
			return
		run.save_to_context(ctx)
	print("  (seed %d: full run simulated in %.1f s of CPU)" % [run_seed, (Time.get_ticks_msec() - t0) / 1000.0])


## Where the bot wants to go: nearest unfinished generator, then the boss,
## then the boat.
func _goal(run: IslandRun) -> Vector3:
	match run.objective:
		IslandRun.Objective.GENERATORS:
			var best := Vector3.INF
			var best_d: float = INF
			for g in GameData.GENERATOR_COUNT:
				if run.generator_progress[g] < GameData.GENERATOR_HOLD_SECONDS:
					var d: float = run.player_pos.distance_to(run.map.generators[g])
					if d < best_d:
						best_d = d
						best = run.map.generators[g]
			return best
		IslandRun.Objective.BOSS:
			var b: int = run.boss_index()
			if b != -1:
				var bp: Vector3 = run.horde.positions[b]
				# Stand 8 m away (inside rock range limit, outside the slam ring).
				var away: Vector3 = (run.player_pos - bp)
				away.y = 0.0
				return bp + away.normalized() * 8.0 if away.length() > 0.1 else bp + Vector3(8, 0, 0)
	return run.map.boat
