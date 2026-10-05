class_name HordeMaps
extends RefCounted
## Test maps and spawn helpers shared by the demo, tests and benchmark.


## 150x150 m arena (1 m cells): long walls with gaps plus scattered boxes.
## Deterministic for a given seed. The centre 20x20 m stays open.
static func make_arena(rng_seed: int = 1) -> HordeFlowField:
	var f := HordeFlowField.new(150, 150, 1.0)
	# Long walls with gaps (corridors / chokepoints).
	f.set_blocked_rect(20, 30, 129, 31)
	f.set_blocked_rect(60, 30, 66, 31, false)
	f.set_blocked_rect(100, 30, 104, 31, false)
	f.set_blocked_rect(20, 118, 129, 119)
	f.set_blocked_rect(40, 118, 44, 119, false)
	f.set_blocked_rect(85, 118, 92, 119, false)
	f.set_blocked_rect(30, 40, 31, 110)
	f.set_blocked_rect(30, 70, 31, 78, false)
	f.set_blocked_rect(118, 40, 119, 110)
	f.set_blocked_rect(118, 55, 119, 60, false)
	f.set_blocked_rect(118, 90, 119, 96, false)
	# Scattered boxes (houses, rocks).
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	for k in 220:
		var w: int = rng.randi_range(2, 6)
		var h: int = rng.randi_range(2, 6)
		var x: int = rng.randi_range(2, 147 - w)
		var z: int = rng.randi_range(2, 147 - h)
		if x + w > 65 and x < 85 and z + h > 65 and z < 85:
			continue
		f.set_blocked_rect(x, z, x + w - 1, z + h - 1)
	return f


## Random positions in free, reachable cells at distance [min_r, max_r] from
## `center`. Needs a computed field (dist) so agents never spawn sealed in.
static func spawn_ring(sim: HordeSim, n: int, center: Vector3, min_r: float,
		max_r: float, rng_seed: int = 7) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var f: HordeFlowField = sim.field
	var placed: int = 0
	var tries: int = 0
	while placed < n and tries < n * 200:
		tries += 1
		var a: float = rng.randf() * TAU
		var rr: float = rng.randf_range(min_r, max_r)
		var p := center + Vector3(cos(a) * rr, 0.0, sin(a) * rr)
		var c: Vector2i = f.world_to_cell(p)
		if f.is_blocked(c) or f.dist[f.index(c)] == HordeFlowField.UNREACHABLE:
			continue
		# Spawn at the cell centre so the radius check starts valid.
		sim.add_agent(f.cell_center(c) + Vector3(rng.randf_range(-0.1, 0.1), 0.0,
				rng.randf_range(-0.1, 0.1)), rng.randf_range(2.5, 5.0))
		placed += 1
