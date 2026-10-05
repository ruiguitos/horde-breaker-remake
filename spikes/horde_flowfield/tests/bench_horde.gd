extends SceneTree
## Benchmark: simulation cost per tick and flow field recompute cost.
## Run: godot --headless --path . --script res://spikes/horde_flowfield/tests/bench_horde.gd

const DT: float = 1.0 / 60.0
const COUNTS: Array[int] = [100, 300, 500, 1000, 2000]
const WARMUP_TICKS: int = 120
const MEASURE_TICKS: int = 600
const HITSCANS_PER_TICK: int = 10


func _initialize() -> void:
	print("Horde flow field benchmark — %s, %d threads, Godot %s" % [
		OS.get_processor_name(), OS.get_processor_count(), Engine.get_version_info()["string"]])
	print("Map 150x150 (1 m cells), %d ticks @60 Hz after %d warm-up ticks; player moves in a circle." % [MEASURE_TICKS, WARMUP_TICKS])
	_bench_field()
	print("")
	print("| agents | tick mean ms | p95 ms | p99 ms | max ms | %d hitscans mean ms | stuck* |" % HITSCANS_PER_TICK)
	print("|-------:|------------:|-------:|-------:|-------:|-----------:|------:|")
	for n in COUNTS:
		_bench_sim(n)
	print("* stuck = agents more than 25 cells (flow distance) from the player that moved less than 0.5 m in the last 5 s.")
	quit(0)


func _bench_field() -> void:
	var field := HordeMap.generate()
	var free_cells: int = 0
	for b in field.blocked:
		if b == 0:
			free_cells += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var samples: Array[float] = []
	for k in 30:
		var c := Vector2i(rng.randi_range(60, 90), rng.randi_range(60, 90))
		var t0: int = Time.get_ticks_usec()
		field.compute_now(c)
		samples.append((Time.get_ticks_usec() - t0) / 1000.0)
	print("Flow field full recompute (%d free cells): mean %.2f ms, p95 %.2f ms, max %.2f ms" % [
		free_cells, _mean(samples), _pct(samples, 0.95), _pct(samples, 1.0)])
	# Time-sliced: cost of one step with the default budget.
	var budget: int = HordeSim.new(field).field_budget
	var slice: Array[float] = []
	var slices_per_recompute: Array[float] = []
	for k in 30:
		field.request_target(Vector2i(rng.randi_range(60, 90), rng.randi_range(60, 90)))
		var n: int = 0
		while field.is_computing:
			var t0: int = Time.get_ticks_usec()
			field.step(budget)
			slice.append((Time.get_ticks_usec() - t0) / 1000.0)
			n += 1
		slices_per_recompute.append(n)
	print("Time-sliced (budget %d cells/tick): step mean %.2f ms, max %.2f ms, %.1f ticks per recompute" % [
		budget, _mean(slice), _pct(slice, 1.0), _mean(slices_per_recompute)])


func _bench_sim(n: int) -> void:
	var field := HordeMap.generate()
	var sim := HordeSim.new(field)
	var center := Vector3(75, 0, 75)
	sim.set_target(center)
	field.compute_now(field.world_to_cell(center))
	var rng := RandomNumberGenerator.new()
	rng.seed = n
	for i in n:
		sim.add_agent(HordeMap.random_free_position(field, rng), rng.randf_range(2.0, 5.0))
	var samples: Array[float] = []
	var hs: Array[float] = []
	var last_pos := PackedVector3Array()
	last_pos.resize(n)
	var stuck_check_every: int = 300
	var stuck: int = 0
	var total: int = WARMUP_TICKS + MEASURE_TICKS
	for t in total:
		var a: float = t * DT * 0.4
		var player := Vector3(75.0 + cos(a) * 10.0, 0.0, 75.0 + sin(a) * 10.0)
		var t0: int = Time.get_ticks_usec()
		sim.set_target(player)
		sim.tick(DT)
		var t1: int = Time.get_ticks_usec()
		for k in HITSCANS_PER_TICK:
			var ang: float = rng.randf_range(0.0, TAU)
			sim.hitscan(player, Vector3(cos(ang), 0, sin(ang)), 40.0)
		var t2: int = Time.get_ticks_usec()
		if t >= WARMUP_TICKS:
			samples.append((t1 - t0) / 1000.0)
			hs.append((t2 - t1) / 1000.0)
		if t % stuck_check_every == 0:
			stuck = 0
			for i in sim.count:
				var p: Vector3 = sim.positions[i]
				if t > 0 and p.distance_to(last_pos[i]) < 0.5 and field.distance_at(p) > 25:
					stuck += 1
				last_pos[i] = p
	print("| %d | %.2f | %.2f | %.2f | %.2f | %.3f | %d |" % [
		n, _mean(samples), _pct(samples, 0.95), _pct(samples, 0.99), _pct(samples, 1.0), _mean(hs), stuck])


func _mean(a: Array[float]) -> float:
	var s: float = 0.0
	for v in a:
		s += v
	return s / maxf(1.0, a.size())


func _pct(a: Array[float], p: float) -> float:
	var sorted: Array[float] = a.duplicate()
	sorted.sort()
	var idx: int = clampi(ceili(p * sorted.size()) - 1, 0, sorted.size() - 1)
	return sorted[idx]
