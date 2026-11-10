extends SceneTree
## The horde does not come in lines or from one side (game/horde/horde.gd, flow_field.gd and
## IslandRun._spawn_enemy). On open ground enemies walk straight at the player instead of down
## his row or column; in a corridor they keep lanes of their own; around a wall they still follow
## the flow field; and an open ring's spawns are spread over its sectors.
## Run: godot --headless --path . --script res://tests/test_horde_spread.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		_failures += 1
		print("TEST FAIL: " + what)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_open_ground()
	_test_corridor_lanes()
	_test_around_a_wall()
	_test_spawn_sectors()
	print("TEST: horde spread, %d failures" % _failures)
	quit(1 if _failures > 0 else 0)


func _field(w: int, h: int) -> FlowField:
	var f := FlowField.new(w, h, 1.0)
	f.set_blocked_rect(0, 0, w - 1, 0)
	f.set_blocked_rect(0, h - 1, w - 1, h - 1)
	f.set_blocked_rect(0, 0, 0, h - 1)
	f.set_blocked_rect(w - 1, 0, w - 1, h - 1)
	return f


func _settle(horde: Horde) -> void:
	for k in 400:
		if not horde.field.is_computing:
			break
		horde.field.step(100000)


## 72 enemies on a ring 30 m out: while they close in, few are on the target's row or column.
func _test_open_ground() -> void:
	var f := _field(80, 80)
	var horde := Horde.new(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var centre := Vector3(40.5, 0, 40.5)
	horde.set_target(centre)
	_settle(horde)
	for k in 72:
		var a: float = k * TAU / 72.0 + 0.03
		horde.add(centre + Vector3(cos(a), 0, sin(a)) * 30.0, GameData.EnemyKind.WALKER, rng)
	var on_axis: int = 0
	var seen: int = 0
	for step in 300:
		horde.tick(0.05)
		if step % 10 != 0:
			continue
		for i in horde.count:
			var d: Vector3 = horde.positions[i] - centre
			var far: float = Vector2(d.x, d.z).length()
			if far > 4.0 and far < 20.0:
				seen += 1
				if absf(d.x) < 1.0 or absf(d.z) < 1.0:
					on_axis += 1
	var share: float = float(on_axis) / maxi(seen, 1)
	_check(seen > 100 and share < 0.2, "on open ground the horde does not line up on the target's row or column (%.0f%% of %d, a line-up is above 50%%)" % [share * 100.0, seen])
	var nearest: float = INF
	for i in horde.count:
		nearest = minf(nearest, horde.positions[i].distance_to(centre))
	_check(nearest < 3.0, "the horde still reaches its target (nearest %.1f m)" % nearest)


## A corridor four cells wide that turns a corner to the target: the grid's directions lead there,
## and the enemies following them are spread across the corridor, not in single file.
func _test_corridor_lanes() -> void:
	var f := _field(60, 40)
	f.set_blocked_rect(1, 1, 58, 38)
	f.set_blocked_rect(1, 4, 55, 7, false)   # the corridor, along X
	f.set_blocked_rect(52, 4, 55, 36, false)  # its turn, along Z, to the target
	var horde := Horde.new(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	horde.set_target(Vector3(53.5, 0, 35.5))
	_settle(horde)
	for k in 12:
		horde.add(Vector3(3.5 + k * 1.2, 0, 5.5), GameData.EnemyKind.WALKER, rng)
	for step in 100:
		horde.tick(0.05)
	var lo: float = INF
	var hi: float = -INF
	for i in horde.count:
		if horde.positions[i].x < 50.0:
			lo = minf(lo, horde.positions[i].z)
			hi = maxf(hi, horde.positions[i].z)
	_check(hi - lo > 0.2, "in a corridor the enemies keep lanes of their own (%.2f m across)" % (hi - lo))


## A wall between the enemy and the target: it goes round, as the flow field says.
func _test_around_a_wall() -> void:
	var f := _field(40, 40)
	f.set_blocked_rect(20, 5, 20, 34)
	var horde := Horde.new(f)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var goal := Vector3(30.5, 0, 20.5)
	horde.set_target(goal)
	_settle(horde)
	horde.add(Vector3(10.5, 0, 20.5), GameData.EnemyKind.RUNNER, rng)
	for step in 1200:
		horde.tick(0.05)
	_check(horde.positions[0].distance_to(goal) < 3.0, "an enemy behind a wall still goes round it (%.1f m from the target)" % horde.positions[0].distance_to(goal))


## The island's own spawns, the player still: no free side of the ring is left far behind.
func _test_spawn_sectors() -> void:
	var ctx := RunContext.new(3)
	ctx.apply_class(&"recruit")
	ctx.biome = &"beach"
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	run.noclip = true
	var sectors := PackedInt32Array()
	sectors.resize(IslandRun.SPAWN_SECTORS)
	for k in 600:
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.reload_left = 1000.0
		var before: int = run.horde.count
		run.step(0.1, Vector2.ZERO, Vector3(0, 0, -1), false)
		for i in range(before, run.horde.count):
			sectors[IslandRun.spawn_sector(run.player_pos, run.horde.positions[i])] += 1
	var lo: int = 1 << 30
	var hi: int = 0
	for s in IslandRun.SPAWN_SECTORS:
		lo = mini(lo, sectors[s])
		hi = maxi(hi, sectors[s])
	_check(hi > 0 and lo * 2 >= hi, "the spawns are spread over the sectors of an open ring (%s)" % [sectors])
