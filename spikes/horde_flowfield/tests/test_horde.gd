extends SceneTree
## Headless tests for the horde flow-field spike.
## Run: godot --headless --path . --script res://spikes/horde_flowfield/tests/test_horde.gd

var failures: int = 0


func _initialize() -> void:
	_test_go_around_obstacle_and_arrive()
	_test_arena_no_wall_crossing()
	_test_threaded_matches_sync()
	_test_hitscan_nearest()
	_test_hitscan_blocked_by_wall()
	await _test_demo_scene_runs()
	quit(1 if failures > 0 else 0)


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("TEST: " + msg)
	else:
		print("TEST FAIL: " + msg)
		failures += 1


func _any_in_wall(sim: HordeSim) -> int:
	for i in sim.count:
		if sim.field.is_blocked_world(sim.pos[i]):
			return i
	return -1


## 40x40 map, a wall across z = 20 from x = 0 to 31; the only way through is
## the gap at x >= 32. Agents start at z < 10 near x = 5, target at (5, 35):
## a straight line would hit the wall, so they must go around.
func _test_go_around_obstacle_and_arrive() -> void:
	var f := HordeFlowField.new(40, 40, 1.0)
	f.set_blocked_rect(0, 20, 31, 21)
	var target := Vector3(5.5, 0.0, 35.5)
	f.compute(f.world_to_cell(target))
	var sim := HordeSim.new(f)
	sim.target_pos = target
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 40:
		sim.add_agent(Vector3(2.0 + (k % 8) * 1.1, 0.0, 3.0 + (k / 8) * 1.1), rng.randf_range(2.5, 5.0))
	var max_x: float = 0.0
	var wall_hit: int = -1
	for tick in 60 * 40:
		sim.step(1.0 / 60.0)
		for i in sim.count:
			max_x = maxf(max_x, sim.pos[i].x)
		if wall_hit == -1:
			wall_hit = _any_in_wall(sim)
	_check(wall_hit == -1, "no agent inside a wall cell (small map)")
	_check(max_x > 31.0, "agents went around the wall through the gap (max x %.1f)" % max_x)
	var arrived: int = 0
	for i in sim.count:
		if sim.pos[i].distance_to(target) < 5.0:
			arrived += 1
	_check(arrived == sim.count, "all agents reached the target area (%d/%d)" % [arrived, sim.count])


## Full arena, 1000 agents, moving target, threaded rebuilds: no agent ever
## ends a tick inside a blocked cell.
func _test_arena_no_wall_crossing() -> void:
	var f := HordeMaps.make_arena()
	var player := Vector3(75.5, 0.0, 75.5)
	f.compute(f.world_to_cell(player))
	var sim := HordeSim.new(f)
	HordeMaps.spawn_ring(sim, 1000, player, 20.0, 70.0)
	var bad: int = -1
	for tick in 600:
		player = Vector3(75.5 + 15.0 * cos(tick * 0.01), 0.0, 75.5 + 15.0 * sin(tick * 0.01))
		sim.target_pos = player
		f.poll()
		f.request_target(f.world_to_cell(player))
		sim.step(1.0 / 60.0)
		if bad == -1:
			bad = _any_in_wall(sim)
	f.wait()
	_check(bad == -1, "no agent crosses walls in the arena (1000 agents, 600 ticks)")


func _test_threaded_matches_sync() -> void:
	var a := HordeMaps.make_arena()
	var b := HordeMaps.make_arena()
	var c := Vector2i(40, 100)
	a.compute(c)
	b.request_target(Vector2i(75, 75))
	b.request_target(c)
	b.wait()
	_check(b.target_cell == c and a.dist == b.dist and a.flow == b.flow,
			"threaded rebuild (latest request wins) matches synchronous rebuild")


func _test_hitscan_nearest() -> void:
	var f := HordeFlowField.new(30, 30, 1.0)
	var sim := HordeSim.new(f)
	var far := sim.add_agent(Vector3(12.0, 0.0, 10.0), 3.0)
	var near := sim.add_agent(Vector3(5.0, 0.0, 10.2), 3.0)
	var mid := sim.add_agent(Vector3(8.0, 0.0, 9.8), 3.0)
	var off := sim.add_agent(Vector3(3.0, 0.0, 12.0), 3.0)   # closer but off the line
	var behind := sim.add_agent(Vector3(0.5, 0.0, 10.0), 3.0) # behind the origin
	sim.rebuild_hash()
	var hit: int = sim.hitscan(Vector3(1.5, 1.0, 10.0), Vector3(1, 0, 0), 50.0)
	_check(hit == near, "hitscan returns the nearest agent on the line (got %d, want %d)" % [hit, near])
	hit = sim.hitscan(Vector3(20.0, 1.0, 10.0), Vector3(-1, 0, 0), 50.0)
	_check(hit == far, "hitscan works in the opposite direction (got %d, want %d)" % [hit, far])
	hit = sim.hitscan(Vector3(1.5, 1.0, 10.0), Vector3(1, 0, 0), 3.0)
	_check(hit == -1, "hitscan respects max distance")
	hit = sim.hitscan(Vector3(1.5, 1.0, 10.0), Vector3(0, 0, -1), 50.0)
	_check(hit == -1, "hitscan misses when no agent is on the line")
	_check(mid != off and behind != off, "fixture sanity")


func _test_hitscan_blocked_by_wall() -> void:
	var f := HordeFlowField.new(30, 30, 1.0)
	f.set_blocked_rect(6, 0, 6, 29)
	var sim := HordeSim.new(f)
	sim.add_agent(Vector3(10.0, 0.0, 10.0), 3.0)
	sim.rebuild_hash()
	var hit: int = sim.hitscan(Vector3(1.5, 1.0, 10.0), Vector3(1, 0, 0), 50.0)
	_check(hit == -1, "walls stop the hitscan")


func _test_demo_scene_runs() -> void:
	var packed := load("res://spikes/horde_flowfield/horde_demo.tscn") as PackedScene
	var demo: Node3D = packed.instantiate() as Node3D
	demo.set("agent_count", 100)
	root.add_child(demo)
	await process_frame  # let _ready run inside the live tree
	for k in 5:
		demo.call("_physics_process", 1.0 / 60.0)
	var sim: HordeSim = demo.get("sim")
	_check(sim != null and sim.count == 100, "demo scene builds and steps")
	demo.free()
