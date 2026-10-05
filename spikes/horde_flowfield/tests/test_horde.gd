extends SceneTree
## Headless tests for the horde flow field spike.
## Run: godot --headless --path . --script res://spikes/horde_flowfield/tests/test_horde.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


func _initialize() -> void:
	_test_time_sliced_matches_full()
	_test_agents_go_around_obstacle()
	_test_no_agent_crosses_walls()
	_test_hitscan_returns_closest()
	_test_hitscan_matches_brute_force()
	if _failures > 0:
		print("TEST FAIL: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		print("TEST FAIL: " + what)
		_failures += 1


func _test_time_sliced_matches_full() -> void:
	var a := HordeMap.generate(150, 7)
	var b := HordeMap.generate(150, 7)
	a.compute_now(Vector2i(75, 75))
	b.request_target(Vector2i(75, 75))
	var steps: int = 0
	while not b.step(500):
		steps += 1
	_check(a.dist == b.dist and steps > 10, "time-sliced BFS equals full BFS (%d slices)" % steps)


## 30x30 map with a long wall between spawn and target: agents must go around.
func _test_agents_go_around_obstacle() -> void:
	var field := HordeFlowField.new(30, 30)
	field.set_blocked_rect(0, 0, 29, 0)
	field.set_blocked_rect(0, 29, 29, 29)
	field.set_blocked_rect(0, 0, 0, 29)
	field.set_blocked_rect(29, 0, 29, 29)
	field.set_blocked_rect(14, 4, 15, 28)  # gap only at z = 1..3
	var sim := HordeSim.new(field)
	var target := Vector3(25.5, 0.0, 20.5)
	sim.set_target(target)
	field.compute_now(field.world_to_cell(target))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 20:
		sim.add_agent(Vector3(rng.randf_range(3.0, 8.0), 0.0, rng.randf_range(16.0, 24.0)), rng.randf_range(2.5, 4.0))
	var went_around: bool = false
	var arrived: bool = false
	var ticks: int = 0
	for t in 2400:
		sim.tick(DT)
		ticks = t
		for i in sim.count:
			var p: Vector3 = sim.positions[i]
			if p.x > 13.0 and p.x < 17.0 and p.z < 4.0:
				went_around = true
		var all_close: bool = true
		for i in sim.count:
			if sim.positions[i].distance_to(target) > 3.0:
				all_close = false
				break
		if all_close:
			arrived = true
			break
	_check(went_around, "agents pass through the gap around the wall")
	_check(arrived, "all 20 agents reach the target (within 3 m) in %.1f s" % (ticks * DT))


## 500 agents on the big map, target moving: no agent ever overlaps a wall.
func _test_no_agent_crosses_walls() -> void:
	var field := HordeMap.generate(150, 1234)
	var sim := HordeSim.new(field)
	sim.set_target(Vector3(75, 0, 75))
	field.compute_now(Vector2i(75, 75))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 500:
		sim.add_agent(HordeMap.random_free_position(field, rng), rng.randf_range(2.0, 5.0))
	var violations: int = 0
	for t in 900:
		var a: float = t * DT * 0.5
		sim.set_target(Vector3(75.0 + cos(a) * 8.0, 0.0, 75.0 + sin(a) * 8.0))
		sim.tick(DT)
		for i in sim.count:
			var p: Vector3 = sim.positions[i]
			# Slightly smaller than the radius to ignore float rounding at the boundary.
			if HordeSim.overlaps_wall(field, p.x, p.z, HordeSim.AGENT_RADIUS - 0.001):
				violations += 1
	_check(violations == 0, "no agent overlaps a wall over 900 ticks with 500 agents (%d violations)" % violations)


func _test_hitscan_returns_closest() -> void:
	var field := HordeFlowField.new(40, 20)
	field.set_blocked_rect(30, 0, 30, 19)
	var sim := HordeSim.new(field)
	var near := sim.add_agent(Vector3(10, 0, 5), 3.0)
	var _mid := sim.add_agent(Vector3(14, 0, 5), 3.0)
	var far := sim.add_agent(Vector3(20, 0, 5), 3.0)
	var _off := sim.add_agent(Vector3(6, 0, 7), 3.0)  # off the line
	var behind_wall := sim.add_agent(Vector3(35, 0, 12), 3.0)
	var hit: Dictionary = sim.hitscan(Vector3(2, 0, 5), Vector3(1, 0, 0), 50.0)
	_check(hit["index"] == near and absf(hit["distance"] - (8.0 - HordeSim.AGENT_RADIUS)) < 0.001,
		"hitscan +x returns the nearest agent on the line (d=%.3f)" % hit["distance"])
	hit = sim.hitscan(Vector3(28, 0, 5), Vector3(-1, 0, 0), 50.0)
	_check(hit["index"] == far, "hitscan -x returns the nearest agent from the other side")
	hit = sim.hitscan(Vector3(2, 0, 5), Vector3(1, 0, 0), 5.0)
	_check(hit["index"] == -1, "hitscan respects max distance")
	hit = sim.hitscan(Vector3(25, 0, 12), Vector3(1, 0, 0), 50.0)
	_check(hit["index"] == -1 and hit["hit_wall"] and behind_wall >= 0, "walls block the hitscan")
	hit = sim.hitscan(Vector3(2, 0, 5.3), Vector3(1, 0, 0), 50.0)
	_check(hit["index"] == near, "hitscan grazing the agent edge still hits")


## Random rays on an open map vs a brute-force loop over all agents.
func _test_hitscan_matches_brute_force() -> void:
	var field := HordeFlowField.new(60, 60)
	var sim := HordeSim.new(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for i in 400:
		sim.add_agent(Vector3(rng.randf_range(1, 59), 0, rng.randf_range(1, 59)), 3.0)
	var mismatches: int = 0
	for k in 500:
		var o := Vector3(rng.randf_range(1, 59), 0, rng.randf_range(1, 59))
		var a: float = rng.randf_range(0.0, TAU)
		var dir := Vector3(cos(a), 0, sin(a))
		var hit: Dictionary = sim.hitscan(o, dir, 30.0)
		var best_t: float = INF
		for i in sim.count:
			var t: float = _ray_circle(o, dir, sim.positions[i], HordeSim.AGENT_RADIUS)
			if t <= 30.0 and t < best_t:
				best_t = t
		var expected_hit: bool = best_t < INF
		var got_hit: bool = hit["index"] != -1
		if expected_hit != got_hit or (got_hit and absf(hit["distance"] - best_t) > 0.001):
			mismatches += 1
	_check(mismatches == 0, "hitscan matches brute force on 500 random rays (%d mismatches)" % mismatches)


func _ray_circle(o: Vector3, d: Vector3, c: Vector3, r: float) -> float:
	var mx: float = o.x - c.x
	var mz: float = o.z - c.z
	var b: float = mx * d.x + mz * d.z
	var cc: float = mx * mx + mz * mz - r * r
	if cc <= 0.0:
		return 0.0
	if b >= 0.0:
		return INF
	var disc: float = b * b - cc
	if disc < 0.0:
		return INF
	return -b - sqrt(disc)
