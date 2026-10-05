extends SceneTree
## Headless benchmark: simulation time per tick and flow-field rebuild time.
## Run: godot --headless --path . --script res://spikes/horde_flowfield/tests/bench_horde.gd
## Measures CPU only (no rendering). Prints a table.

const COUNTS: Array[int] = [100, 150, 300, 500, 1000, 2000]
const WARMUP_TICKS: int = 30
const TICKS: int = 300
const DT: float = 1.0 / 60.0


func _initialize() -> void:
	print("CPU: %s (%d threads), %s" % [OS.get_processor_name(), OS.get_processor_count(),
			Engine.get_version_info().string])
	print("")
	print("| agents | mean ms | p95 ms | p99 ms | max ms | % of 16.7 ms (mean) |")
	print("|-------:|--------:|-------:|-------:|-------:|--------------------:|")
	for n in COUNTS:
		var s: Array[float] = _bench_sim(n)
		print("| %6d | %7.3f | %6.3f | %6.3f | %6.3f | %18.1f%% |" % [
			n, _mean(s), _pct(s, 0.95), _pct(s, 0.99), s[s.size() - 1], _mean(s) / 16.667 * 100.0])
	print("")
	_bench_field()
	_bench_hitscan()
	print("TEST: benchmark finished")
	quit(0)


func _bench_sim(n: int) -> Array[float]:
	var f := HordeMaps.make_arena()
	var player := Vector3(75.5, 0.0, 75.5)
	f.compute(f.world_to_cell(player))
	var sim := HordeSim.new(f)
	sim.target_pos = player
	HordeMaps.spawn_ring(sim, n, player, 20.0, 70.0)
	var samples: Array[float] = []
	for tick in WARMUP_TICKS + TICKS:
		var t0: int = Time.get_ticks_usec()
		sim.step(DT)
		var us: int = Time.get_ticks_usec() - t0
		if tick >= WARMUP_TICKS:
			samples.append(us / 1000.0)
	samples.sort()
	return samples


func _bench_field() -> void:
	var f := HordeMaps.make_arena()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var targets: Array[Vector2i] = []
	while targets.size() < 40:
		var c := Vector2i(rng.randi_range(1, 148), rng.randi_range(1, 148))
		if not f.is_blocked(c):
			targets.append(c)
	var sync: Array[float] = []
	for c in targets:
		var t0: int = Time.get_ticks_usec()
		f.compute(c)
		sync.append((Time.get_ticks_usec() - t0) / 1000.0)
	sync.sort()
	# Threaded: time from request to swap (latency), and main-thread cost of
	# request + poll calls (what the frame actually pays).
	var latency: Array[float] = []
	var main_cost: Array[float] = []
	for c in targets:
		var t0: int = Time.get_ticks_usec()
		var paid: int = 0
		var a: int = Time.get_ticks_usec()
		f.request_target(c)
		paid += Time.get_ticks_usec() - a
		while true:
			a = Time.get_ticks_usec()
			var swapped: bool = f.poll()
			paid += Time.get_ticks_usec() - a
			if swapped:
				break
			OS.delay_usec(100)
		latency.append((Time.get_ticks_usec() - t0) / 1000.0)
		main_cost.append(paid / 1000.0)
	latency.sort()
	main_cost.sort()
	print("Flow field 150x150 (1 m cells, %d targets):" % targets.size())
	print("| rebuild | mean ms | p95 ms | max ms |")
	print("|--------|--------:|-------:|-------:|")
	print("| sync (blocks frame) | %.3f | %.3f | %.3f |" % [_mean(sync), _pct(sync, 0.95), sync[sync.size() - 1]])
	print("| threaded latency | %.3f | %.3f | %.3f |" % [_mean(latency), _pct(latency, 0.95), latency[latency.size() - 1]])
	print("| threaded main-thread cost | %.3f | %.3f | %.3f |" % [_mean(main_cost), _pct(main_cost, 0.95), main_cost[main_cost.size() - 1]])
	print("")


func _bench_hitscan() -> void:
	var f := HordeMaps.make_arena()
	var player := Vector3(75.5, 0.0, 75.5)
	f.compute(f.world_to_cell(player))
	var sim := HordeSim.new(f)
	sim.target_pos = player
	HordeMaps.spawn_ring(sim, 500, player, 5.0, 40.0)
	sim.step(DT)
	var hits: int = 0
	var t0: int = Time.get_ticks_usec()
	for k in 1000:
		var a: float = k * 0.37
		if sim.hitscan(player, Vector3(cos(a), 0.0, sin(a)), 60.0) != -1:
			hits += 1
	var us: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("Hitscan (500 agents, 60 m rays): %.4f ms/ray, %d/1000 hit" % [us / 1000.0, hits])


func _mean(a: Array[float]) -> float:
	var s: float = 0.0
	for v in a:
		s += v
	return s / a.size()


func _pct(sorted: Array[float], p: float) -> float:
	return sorted[mini(int(ceil(p * sorted.size())) - 1, sorted.size() - 1)]
