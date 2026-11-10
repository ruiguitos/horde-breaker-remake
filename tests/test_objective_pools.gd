extends SceneTree
## Objectives drawn from authored pools by seed. beach_01 has six Generator markers and each run
## uses three of them (IslandRun.pick_generators); the EXFIL map has three ExfilPoint markers and
## each EXFIL run extracts at one of them. The same seed gives the same draw; a map with exactly
## three generators keeps them all.
## Run: godot --headless --path . --script res://tests/test_objective_pools.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		_failures += 1
		print("TEST FAIL: " + what)


func _initialize() -> void:
	call_deferred("_run")


func _map(path: String, problems: Array[String]) -> IslandMap:
	var island: HandmadeIsland = (load(path) as PackedScene).instantiate() as HandmadeIsland
	root.add_child(island)
	await process_frame
	await process_frame
	var map: IslandMap = island.build_map(problems)
	island.queue_free()
	return map


func _run() -> void:
	# The draw itself.
	var pool: Array[Vector3] = [Vector3(0, 0, 0), Vector3(100, 0, 0), Vector3(0, 0, 100), Vector3(100, 0, 100), Vector3(5, 0, 5), Vector3(50, 0, 160)]
	var seen: Dictionary = {}
	var spaced: bool = true
	for s in 40:
		var picks: Array[Vector3] = IslandRun.pick_generators(pool, s)
		seen[str(picks)] = true
		spaced = spaced and picks.size() == GameData.GENERATOR_COUNT
		for a in picks.size():
			for b in range(a + 1, picks.size()):
				spaced = spaced and picks[a].distance_to(picks[b]) >= GameData.GENERATOR_MIN_SPACING
	_check(spaced, "a draw is %d generators, at least %d m apart" % [GameData.GENERATOR_COUNT, int(GameData.GENERATOR_MIN_SPACING)])
	_check(seen.size() >= 4, "different seeds draw different generators (%d layouts in 40 seeds)" % seen.size())
	_check(IslandRun.pick_generators(pool, 9) == IslandRun.pick_generators(pool, 9), "the same seed draws the same generators")
	var three: Array[Vector3] = [Vector3(1, 0, 1), Vector3(2, 0, 2), Vector3(3, 0, 3)]
	_check(IslandRun.pick_generators(three, 5) == three, "a map with exactly three generators keeps them all")

	# beach_01: a pool of six, Check map clean, and a run on it holds three of the six.
	var problems: Array[String] = []
	var beach: IslandMap = await _map("res://game/world/handmade/islands/beach_01.tscn", problems)
	_check(beach.generators.size() == 6 and problems.is_empty(), "beach_01 has a pool of 6 generators and Check map finds no problem (%s)" % [problems])
	var all: Array[Vector3] = beach.generators.duplicate()
	var run := IslandRun.new(11, &"beach", beach)
	var inside: bool = run.map.generators.size() == GameData.GENERATOR_COUNT
	for g: Vector3 in run.map.generators:
		inside = inside and all.has(g)
	_check(inside and run.generator_progress.size() == GameData.GENERATOR_COUNT, "a run on beach_01 uses three of its six generators (%s)" % [run.map.generators])

	# The EXFIL map: three points, each one drawn by some seed, hidden until the extraction opens.
	problems = []
	var arena: IslandMap = await _map("res://game/world/handmade/test/exfil_test.tscn", problems)
	_check(arena.exfil_points.size() == 3 and problems.is_empty(), "the EXFIL map has 3 extraction points and Check map finds no problem (%s)" % [problems])
	var drawn: Dictionary = {}
	var first: Vector3 = Vector3.INF
	for s in 24:
		var ctx := RunContext.new(s)
		ctx.apply_class(&"recruit")
		ctx.mode = &"exfil"
		ctx.mission = &"exfil"
		ctx.biome = &"beach"
		var exfil := IslandRun.new(ctx.island_seed(), &"beach", arena)
		exfil.load_context(ctx)
		drawn[exfil.exfil_pos] = true
		if s == 0:
			first = exfil.exfil_pos
			_check(arena.exfil_points.has(exfil.exfil_pos) and not exfil.exfil_beacon_on(), "an EXFIL run extracts at one of the map's points, hidden until 10:00")
			var again := IslandRun.new(ctx.island_seed(), &"beach", arena)
			again.load_context(ctx)
			_check(again.exfil_pos == first, "the same seed extracts at the same point")
	_check(drawn.size() == 3, "over 24 seeds every extraction point is drawn (%d of 3)" % drawn.size())
	arena.field.compute_now(arena.field.world_to_cell(arena.player_start))
	var reach: bool = true
	for p: Vector3 in arena.exfil_points:
		reach = reach and arena.field.distance_at(p) < FlowField.UNREACHABLE and p.distance_to(arena.player_start) > 100.0
	_check(reach, "every extraction point is reachable on foot and over 100 m from the start")
	print("TEST: objective pools, %d failures" % _failures)
	await create_timer(0.3).timeout
	quit(1 if _failures > 0 else 0)
