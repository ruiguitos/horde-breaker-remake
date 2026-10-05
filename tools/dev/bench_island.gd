extends SceneTree
## Dev benchmark: IslandRun step cost with the worst-case horde (Threat 3 +
## Swarm = up to 240 alive), a bot that keeps the player alive and moving.
## godot --headless --path . --script res://tools/dev/bench_island.gd


func _initialize() -> void:
	var ctx := RunContext.new(21)
	ctx.threat = 3
	ctx.modifier = &"swarm"
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	var samples: Array[float] = []
	var max_alive: int = 0
	for t in 60 * 120:
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.hp = 1000.0
		var a: float = t * 0.004
		var move := Vector2(cos(a), sin(a))
		var near: PackedInt32Array = run.horde.query_radius(run.player_pos, 15.0)
		var aim: Vector3 = (run.horde.positions[near[0]] - run.player_pos) if near.size() > 0 else Vector3(move.x, 0, move.y)
		var t0: int = Time.get_ticks_usec()
		run.step(1.0 / 60.0, move, aim, false)
		if t > 60 * 30:
			samples.append((Time.get_ticks_usec() - t0) / 1000.0)
		max_alive = maxi(max_alive, run.horde.count)
	samples.sort()
	var mean: float = 0.0
	for v in samples:
		mean += v
	mean /= samples.size()
	print("IslandRun.step, %d alive max, %d samples: mean %.2f ms, p95 %.2f, p99 %.2f, max %.2f" % [
		max_alive, samples.size(), mean, samples[int(samples.size() * 0.95)], samples[int(samples.size() * 0.99)], samples[-1]])
	quit(0)
