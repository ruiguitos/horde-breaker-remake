extends SceneTree
## Fuel Run (docs/design/OBJECTIVES_PROPOSAL.md, step 2): carry fuel cans,
## one at a time, to the boat. Carrying slows the player, stops sprint,
## firing and the class ability; the can can be dropped to fight and picked
## up again. Each can's first pickup calls a horde spike; the extraction
## opens only once every can is delivered. Also: Cargo_* / Delivery
## markers, the fallback spots, the boat draw (no repeat, Beach preference),
## death and redeploy, a bot run and the Island scene in the three cameras.
## Run: godot --headless --path . --script res://tests/test_fuel_run.gd

const DT: float = 1.0 / 60.0

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _done: bool = false


func _initialize() -> void:
	GameInput.setup()
	create_timer(600.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "fuel run tests finished in time")
			_finish())
	_test_data()
	_test_fallback_spots()
	_test_handmade_islands()
	_test_markers()
	_test_pickup_and_spike()
	_test_carry_rules()
	_test_drop_and_pickup_again()
	_test_delivery_and_extraction()
	_test_death_and_redeploy()
	_test_draw()
	_test_bot()
	_test_scene.call_deferred()


func _finish() -> void:
	_done = true
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if ok:
		print("TEST: " + what)
	else:
		print("TEST FAIL: " + what)
		_failures += 1


func _step(run: IslandRun, n: int = 1, move: Vector2 = Vector2.ZERO, sprint: bool = false) -> void:
	for k in n:
		run.step(DT, move, Vector3(0, 0, -1), false, sprint)


## A run on a generated island with no enemies (rules only).
func _quiet_run(rng_seed: int, biome: StringName = &"beach") -> IslandRun:
	var run := IslandRun.new(rng_seed, biome)
	run.director.max_alive = 0
	run.set_mission(&"fuel_run")
	return run


func _flat_dist(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _test_data() -> void:
	var m: Dictionary = GameData.MISSIONS.get(&"fuel_run", {})
	_check(not m.is_empty() and m["name"] == "Fuel Run" and int(m["points"]) == 3
		and is_equal_approx(float(m["carry_speed_mult"]), 0.8) and float(m["pickup_radius"]) > 0.0
		and float(m["delivery_radius"]) > 0.0 and float(m["spike_seconds"]) > 0.0,
		"fuel_run.tres: %d cans, pickup %.1f m, delivery %.1f m, carry speed x%.2f, spike %.0f s" % [int(m.get("points", 0)),
		float(m.get("pickup_radius", 0)), float(m.get("delivery_radius", 0)), float(m.get("carry_speed_mult", 0)), float(m.get("spike_seconds", 0))])
	_check(GameData.ROUTE_MISSIONS.has(&"fuel_run"), "Fuel Run is offered on archipelago routes")
	_check(IslandRun.cargo_count_wanted() == 3 and IslandRun.carry_speed_mult() == float(m.get("carry_speed_mult", 0))
		and IslandRun.cargo_pickup_radius() == float(m.get("pickup_radius", 0))
		and IslandRun.cargo_delivery_radius() == float(m.get("delivery_radius", 0)), "the run reads its numbers from the data")
	_check(Story.RADIO.has(&"land_fuel_run") and Story.RADIO.has(&"fuel_pickup") and Story.RADIO.has(&"fuel_delivered")
		and Story.RADIO.has(&"fuel_done"), "radio lines for landing, pickup, delivery and the end")
	_check(Briefing.ADVICE.has(&"fuel_run"), "briefing advice for Fuel Run")
	_check(InputMap.has_action(&"interact") and GameInput.REBINDABLE.has(&"interact"), "an interact action (pick up / drop), rebindable")


## Every can reachable from the start, off the boat, spread apart.
func _check_spots(map: IslandMap, pts: Array[Vector3], label: String) -> void:
	var f: FlowField = map.field
	var saved: int = f.max_distance
	f.max_distance = 0
	f.compute_now(f.world_to_cell(map.player_start))
	var bad: int = 0
	var spacing: float = INF
	for i in pts.size():
		if f.distance_at(pts[i]) >= FlowField.UNREACHABLE or _flat_dist(pts[i], map.boat) < IslandMap.HOLD_MIN_FROM_BOAT:
			bad += 1
		for j in range(i + 1, pts.size()):
			spacing = minf(spacing, _flat_dist(pts[i], pts[j]))
	f.max_distance = saved
	_check(pts.size() == 3 and bad == 0 and spacing >= IslandMap.HOLD_MIN_SPACING,
		"%s: 3 cans reachable, >= %d m from the boat, min spacing %.0f m" % [label, int(IslandMap.HOLD_MIN_FROM_BOAT), spacing])


func _test_fallback_spots() -> void:
	for biome: StringName in [&"beach", &"town", &"jungle", &"port", &"volcano"]:
		for s in [3, 77]:
			var a := _quiet_run(s, biome)
			var b := _quiet_run(s, biome)
			_check(a.cargo_pos == b.cargo_pos, "%s seed %d: same seed, same cans" % [biome, s])
			_check_spots(a.map, a.cargo_pos, "%s seed %d" % [biome, s])
	var x := _quiet_run(3)
	var y := _quiet_run(4)
	_check(x.cargo_pos != y.cargo_pos, "another seed, other cans")
	var h := IslandRun.new(3, &"beach")
	h.set_mission(&"hold_sequence")
	_check(h.hold_points != x.cargo_pos, "the cans are not on the Hold Sequence spots of the same seed")


## The archipelago's hand-made islands have no Cargo markers: the fallback
## must work on their real grids.
func _test_handmade_islands() -> void:
	for path in HandmadeIsland.island_paths():
		var scene: PackedScene = load(path)
		if scene == null:
			_check(false, "%s loads" % path)
			continue
		var hm: HandmadeIsland = scene.instantiate()
		root.add_child(hm)
		var map: IslandMap = hm.build_map()
		hm.free()
		var pts: Array[Vector3] = map.cargo_points if not map.cargo_points.is_empty() else IslandMap.pick_cargo_points(map, 3, 9)
		_check_spots(map, pts, path.get_file())


func _test_markers() -> void:
	var hm := HandmadeIsland.new()
	hm.size = 120
	var markers := Node3D.new()
	markers.name = "Markers"
	hm.add_child(markers)
	var spots: Dictionary = {"Boat": Vector3(60, 0, 110), "PlayerStart": Vector3(60, 0, 104), "Delivery": Vector3(70, 0, 100),
		"Cargo_10": Vector3(90, 0, 30), "Cargo_2": Vector3(30, 0, 50), "Cargo_1": Vector3(60, 0, 70)}
	for n: String in spots:
		var m := Marker3D.new()
		m.name = n
		m.position = spots[n]
		markers.add_child(m)
	root.add_child(hm)
	hm.mission = &"fuel_run"
	var problems: Array[String] = []
	var map: IslandMap = hm.build_map(problems)
	var want: Array[Vector3] = [Vector3(60.5, 0, 70.5), Vector3(30.5, 0, 50.5), Vector3(90.5, 0, 30.5)]
	_check(map.cargo_points == want and map.delivery == Vector3(70.5, 0, 100.5),
		"Cargo_1, _2, _10 in number order, Delivery read (%s, %s)" % [map.cargo_points, map.delivery])
	_check(problems.is_empty(), "markers reachable, no problems (%s)" % [problems])
	var run := IslandRun.new(1, &"beach", map)
	run.set_mission(&"fuel_run")
	_check(run.cargo_pos == want and run.delivery_point() == map.delivery and run.delivery_name() == "Fuel drop",
		"the run uses the markers, not picked spots, and delivers at the Delivery marker")
	hm.play_area = PackedVector2Array([Vector2(10, 40), Vector2(110, 40), Vector2(110, 118), Vector2(10, 118)])
	problems.clear()
	hm.build_map(problems)
	var reported: bool = false
	for p in problems:
		if p.begins_with("Cargo at (90, 30)"):
			reported = true
	_check(reported, "an unreachable Cargo marker is reported (%s)" % [problems])
	_check(HandmadeIsland.marker_number("Cargo_3", "Cargo") == 3 and HandmadeIsland.hold_point_number("HoldPoint_12") == 12,
		"marker suffix numbers")
	hm.free()


func _test_pickup_and_spike() -> void:
	var ctx := RunContext.new(5)
	ctx.mission = &"fuel_run"
	var run := IslandRun.new(33)
	run.load_context(ctx)
	run.director.max_alive = 0
	_check(run.radio.has(&"land_fuel_run") and run.cargo_pos.size() == 3 and not run.is_carrying(),
		"landing: radio line, 3 cans waiting, hands empty")
	_check(run.site == run.cargo_pos[run.nearest_waiting_can()], "the goal is the nearest can")
	run.radio.clear()
	run.director.phase = Director.Phase.RELAX
	run.player_pos = run.cargo_pos[1] + Vector3(0.5, 0, 0)
	_step(run)
	_check(run.carrying == 1 and run.cargo_state[1] == IslandRun.CAN_CARRIED, "walking over a can picks it up")
	_check(run.director.phase == Director.Phase.PEAK and run.radio.has(&"fuel_pickup"), "the first pickup calls a horde spike and a radio line")
	_check(run.site == run.delivery_point() and run.objective_text().begins_with("Fuel 0 / 3"),
		"carrying: the goal is the boat ('%s')" % run.objective_text())
	# Other cans are not picked up while one is carried.
	run.player_pos = run.cargo_pos[2]
	_step(run)
	_check(run.carrying == 1 and run.cargo_state[2] == IslandRun.CAN_WAITING, "one can at a time")


func _test_carry_rules() -> void:
	var run := _quiet_run(41)
	var p0: Vector3 = run.cargo_pos[0]
	run.player_pos = p0
	_step(run)
	_check(run.is_carrying(), "carrying can 1")
	# Speed: the best of four directions from the can's spot, carrying vs not.
	var carried: float = _best_walk(run, p0)
	_step(run, 1, Vector2.ZERO)
	_step(run, 20, Vector2(1, 0), true)
	_check(not run.sprinting and run.is_carrying(), "no sprint with a can")
	run.player_pos = p0
	run.drop_cargo()
	var free: float = _best_walk(run, p0)
	_check(not run.is_carrying() and absf(carried / free - IslandRun.carry_speed_mult()) < 0.03,
		"carrying walks at x%.2f (%.2f m vs %.2f m in 8 steps)" % [carried / free, carried, free])
	# No firing with a can: an enemy right next to the player is not shot.
	run.player_pos = p0
	run.interact()
	_check(run.is_carrying(), "interact picks the can up again")
	var e: int = run.horde.add(p0 + Vector3(0, 0, -2.0), GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[e] = 100.0
	var shots: int = run._shots
	for k in 60:
		run.player_pos = p0
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run._shots == shots, "no shots while carrying (%d)" % (run._shots - shots))
	# The ability button puts the can down instead of throwing.
	run.grenade_cd = 0.0
	var used: bool = run.use_ability(Vector3(0, 0, -6))
	_check(not used and run.grenades.is_empty() and not run.is_carrying() and run.cargo_state[0] == IslandRun.CAN_WAITING,
		"ability with a can: no grenade, the can is dropped")
	for k in 60:
		run.player_pos = p0
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run._shots > shots, "hands free: the gun fires again (%d shots)" % (run._shots - shots))


## Metres walked in 8 steps from `from`, the best of four directions (the
## can's spot has open ground around it, IslandMap.pick_cargo_points).
func _best_walk(run: IslandRun, from: Vector3) -> float:
	var best: float = 0.0
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		run.player_pos = from
		_step(run, 8, d)
		best = maxf(best, _flat_dist(run.player_pos, from))
	run.player_pos = from
	return best


func _test_drop_and_pickup_again() -> void:
	var run := _quiet_run(52)
	var c: int = 0
	run.player_pos = run.cargo_pos[c]
	_step(run)
	# Carry it a little, then drop it where the player stands.
	var walked: Vector3 = run.player_pos
	_step(run, 30, Vector2(1, 0))
	_step(run, 30, Vector2(0, 1))
	walked = run.player_pos
	_check(run.drop_cargo() and not run.is_carrying() and _flat_dist(run.cargo_pos[c], walked) < 0.01
		and run.cargo_state[c] == IslandRun.CAN_WAITING, "drop: the can lies at the player's feet")
	var cell: Vector2i = run.field.world_to_cell(run.cargo_pos[c])
	_check(not run.field.is_blocked(cell.x, cell.y), "the dropped can is on walkable ground")
	_step(run, 30)
	_check(not run.is_carrying(), "standing on the dropped can does not grab it back")
	_check(run.interact() and run.carrying == c, "interact picks it up again")
	run.drop_cargo()
	run.player_pos = run.cargo_pos[c] + Vector3(IslandRun.cargo_pickup_radius() + 3.0, 0, 0)
	_step(run)
	run.player_pos = run.cargo_pos[c]
	_step(run)
	_check(run.carrying == c, "after stepping away, walking over it picks it up again")
	# A re-pickup does not call another spike.
	_check(run.cargo_touched[c] and run.radio.count(&"fuel_pickup") == 1,
		"only the first pickup of a can calls the horde (%d radio lines)" % run.radio.count(&"fuel_pickup"))
	# Dropped while flying (noclip) over a wall: it lands on the last walkable spot.
	var blocked := Vector3(-1, 0, -1)
	for z in run.field.height:
		for x in run.field.width:
			if run.field.is_blocked(x, z):
				blocked = Vector3(x + 0.5, 0, z + 0.5)
				break
		if blocked.x >= 0.0:
			break
	var safe: Vector3 = run.player_pos
	run.noclip = true
	run.player_pos = blocked
	_step(run)
	run.drop_cargo()
	run.noclip = false
	var spot: Vector2i = run.field.world_to_cell(run.cargo_pos[c])
	_check(blocked.x >= 0.0 and not run.field.is_blocked(spot.x, spot.y) and _flat_dist(run.cargo_pos[c], safe) < 1.0,
		"dropped over a wall in noclip: lands on the last walkable spot (%s, last %s)" % [run.cargo_pos[c], safe])


func _test_delivery_and_extraction() -> void:
	var ctx := RunContext.new(7)
	ctx.mission = &"fuel_run"
	var run := IslandRun.new(61)
	run.load_context(ctx)
	run.director.max_alive = 0
	run.radio.clear()
	var boat: Vector3 = run.map.boat
	# At the boat with empty hands: nothing happens, no extraction.
	run.player_pos = boat
	_step(run, 10)
	_check(run.objective == IslandRun.Objective.GENERATORS and run.cargo_delivered() == 0, "empty hands at the boat: no extraction")
	var spikes: int = 0
	for k in run.cargo_pos.size():
		run.director.phase = Director.Phase.RELAX
		run.player_pos = run.cargo_pos[k]
		_step(run)
		if run.director.phase == Director.Phase.PEAK:
			spikes += 1
		run.player_pos = boat
		_step(run, 2)
		if k < run.cargo_pos.size() - 1:
			_check(run.objective == IslandRun.Objective.GENERATORS and run.cargo_delivered() == k + 1
				and run.objective_text().begins_with("Fuel %d / 3" % (k + 1)),
				"can %d delivered, extraction still locked ('%s')" % [k + 1, run.objective_text()])
	_check(spikes == 3, "a spike at each can's first pickup (%d of 3)" % spikes)
	_check(run.radio.count(&"fuel_delivered") == 2 and run.radio.has(&"fuel_done"), "radio after each delivery and at the end")
	_check(run.objective == IslandRun.Objective.WON and run.intel_earned() > 0,
		"all cans delivered: extraction opens, at the boat the run is won (Intel %d)" % run.intel_earned())


func _test_death_and_redeploy() -> void:
	var ctx := RunContext.new(9)
	ctx.mission = &"fuel_run"
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	run.director.max_alive = 0
	run.player_pos = run.cargo_pos[0]
	_step(run)
	run.hp = 0.0
	_step(run)
	_check(run.objective == IslandRun.Objective.LOST and run.is_over() and not run.interact(),
		"dying with a can ends the island; interact does nothing after")
	# Quick Redeploy / a new run with the same context: everything fresh.
	var again := IslandRun.new(ctx.island_seed())
	again.load_context(ctx)
	_check(not again.is_carrying() and again.cargo_delivered() == 0 and again.cargo_pos == run.cargo_pos
		and Array(again.cargo_state).all(func(s: int) -> bool: return s == IslandRun.CAN_WAITING),
		"a redeployed island starts with every can back in place")
	# Another mission on the same run object clears the Fuel Run state.
	again.player_pos = again.cargo_pos[0]
	_step(again)
	again.set_mission(&"activate")
	_check(not again.is_carrying() and again.cargo_pos.is_empty(),
		"switching mission clears the cans")


func _test_draw() -> void:
	_check(GameData.mission_weight(&"fuel_run", &"beach") == 3 and GameData.mission_weight(&"fuel_run", &"town") == 1
		and GameData.mission_weight(&"activate", &"beach") == 1, "weights: Fuel Run x3 on the Beach, 1 elsewhere")
	_check(not GameData.route_missions_after(&"fuel_run").has(&"fuel_run"), "never Fuel Run twice in a row")
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var beach: int = 0
	var town: int = 0
	var repeats: int = 0
	var n: int = 4000
	for k in n:
		if GameData.pick_route_mission(rng, &"", &"beach") == &"fuel_run":
			beach += 1
		if GameData.pick_route_mission(rng, &"", &"town") == &"fuel_run":
			town += 1
		if GameData.pick_route_mission(rng, &"fuel_run", &"beach") == &"fuel_run":
			repeats += 1
	# Fuel Run weighs 3 on the Beach; on the Town it weighs 1 next to the
	# Town's own signature (Intel Search, 3): weight over the pool's total.
	var want_beach: float = GameData.mission_share(&"fuel_run", &"beach")
	var want_town: float = GameData.mission_share(&"fuel_run", &"town")
	_check(absf(beach / float(n) - want_beach) < 0.03 and absf(town / float(n) - want_town) < 0.03,
		"draw shares: Beach %.0f%% (expected %.0f%%), Town %.0f%% (expected %.0f%%)" % [100.0 * beach / n, 100.0 * want_beach, 100.0 * town / n, 100.0 * want_town])
	_check(repeats == 0, "no repeat even on the Beach")
	# The boat itself: deterministic, never the last mission, Fuel Run more
	# often on Beach routes.
	var boat_script: Script = load("res://game/states/boat.gd")
	var deterministic: bool = true
	var draws: int = 0
	var repeats_boat: int = 0
	var on_beach: Array[int] = [0, 0]  # [fuel runs, routes]
	var elsewhere: Array[int] = [0, 0]
	for s in range(1, 61):
		for prev: StringName in GameData.ROUTE_MISSIONS:
			var first: Array = _boat_routes(boat_script, s, prev)
			if first != _boat_routes(boat_script, s, prev):
				deterministic = false
			for i in 2:
				var m: StringName = first[0][i]
				var b: StringName = first[1][i]
				draws += 1
				if GameData.mission_family(m) == GameData.mission_family(prev):
					repeats_boat += 1
				if prev == &"fuel_run":
					continue
				var bucket: Array[int] = on_beach if b == &"beach" else elsewhere
				bucket[1] += 1
				if m == &"fuel_run":
					bucket[0] += 1
	_check(deterministic and repeats_boat == 0 and draws > 0, "boat routes: %d draws, deterministic, %d repeats" % [draws, repeats_boat])
	var share_beach: float = on_beach[0] / maxf(1.0, on_beach[1])
	var share_other: float = elsewhere[0] / maxf(1.0, elsewhere[1])
	_check(share_beach > share_other * 1.5 and elsewhere[0] > 0,
		"boat routes: Fuel Run on %.0f%% of Beach routes, %.0f%% elsewhere (still possible)" % [100.0 * share_beach, 100.0 * share_other])


## [missions, biomes] of the two routes the boat draws for seed `s` after `prev`.
func _boat_routes(boat_script: Script, s: int, prev: StringName) -> Array:
	var ctx := RunContext.new(s)
	ctx.island_index = 1
	ctx.mission = prev
	var boat := Control.new()
	boat.set_script(boat_script)
	boat.set("context", ctx)
	(boat.get("_rng") as RandomNumberGenerator).seed = ctx.island_seed() + 1
	boat.call("_make_routes")
	var out: Array = [(boat.get("_route_missions") as Array).duplicate(), (boat.get("_route_biomes") as Array).duplicate()]
	boat.free()
	return out


## A bot picks up each can and carries it to the boat, then extracts (the
## soak test's navigation; invincible: this checks completability). It
## drops the can when crowded and picks it up again after clearing them.
func _test_bot() -> void:
	for s in [404, 505]:
		var ctx := RunContext.new(s)
		ctx.threat = 2
		ctx.mission = &"fuel_run"
		ctx.biome = &"town" if s == 404 else &"beach"
		var run := IslandRun.new(ctx.island_seed(), ctx.biome)
		run.load_context(ctx)
		_bot(run, "bot seed %d (%s)" % [s, ctx.biome])


func _bot(run: IslandRun, label: String) -> void:
	var nav := FlowField.new(run.field.width, run.field.height)
	nav.blocked = run.field.blocked
	var goal := Vector3.INF
	var steps: int = 0
	var drops: int = 0
	var fight: int = 0
	var peak_enemies: int = 0
	while not run.is_over() and steps < int(900.0 / DT):
		steps += 1
		if not run.card_choices.is_empty():
			run.choose_card(0)
		run.hp = 10000.0
		var near: PackedInt32Array = run.horde.query_radius(run.player_pos, 6.0)
		# Crowded with a can: put it down and fight for a while.
		if run.is_carrying() and near.size() > 12:
			run.drop_cargo()
			drops += 1
			fight = int(4.0 / DT)
		var move := Vector2.ZERO
		if fight > 0:
			fight -= 1
			if fight == 0:
				run.interact()  # pick it back up (still at our feet)
		else:
			var g: Vector3 = run.site if run.objective == IslandRun.Objective.GENERATORS else run.extraction_point()
			g = Vector3(floorf(g.x) + 0.5, 0, floorf(g.z) + 0.5)
			if g != goal:
				goal = g
				nav.compute_now(nav.world_to_cell(goal))
			var stp: Vector2 = nav.direction_at(run.player_pos)
			if stp != Vector2.ZERO:
				var c := Vector2(floori(run.player_pos.x) + stp.x + 0.5, floori(run.player_pos.z) + stp.y + 0.5)
				move = (c - Vector2(run.player_pos.x, run.player_pos.z)).normalized()
			elif run.player_pos.distance_to(goal) > 0.5:
				move = Vector2(goal.x - run.player_pos.x, goal.z - run.player_pos.z).normalized()
		var close: PackedInt32Array = run.horde.query_radius(run.player_pos, 20.0)
		var aim := Vector3(move.x, 0, move.y)
		if close.size() > 0:
			aim = run.horde.positions[close[0]] - run.player_pos
		run.step(DT, move, aim, close.size() > 10)
		peak_enemies = maxi(peak_enemies, run.horde.count)
	_check(run.objective == IslandRun.Objective.WON and run.cargo_delivered() == run.cargo_pos.size(),
		"%s: %s in %.0f s, %d cans, %d drops to fight, %d kills, up to %d enemies alive" % [label,
		run.objective_text(), run.time_alive - run.landed_time, run.cargo_delivered(), drops, run.kills, peak_enemies])


## The Island scene with a Fuel Run, in each camera mode: the carried can
## follows the soldier, the HUD and the minimap key show the fuel.
func _test_scene() -> void:
	var profile := MemoryProfile.new()
	var ctx := RunContext.new(5)
	ctx.mission = &"fuel_run"
	ctx.biome = &"beach"
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	island.set("context", ctx)
	root.add_child(island)
	for i in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	var cans: Array = island.get("_cans")
	_check(cans.size() == run.cargo_pos.size() and island.get("_delivery_ring") != null, "the scene builds %d cans and the delivery ring" % cans.size())
	var legend: Array = Minimap.legend_entries(run).map(func(e: Array) -> StringName: return e[0])
	_check(legend.has(&"fuel") and legend.has(&"delivery"), "the minimap key shows FUEL and DELIVERY")
	var hud: Hud = island.get("hud")
	for mode in [Profile.CameraMode.FIRST_PERSON, Profile.CameraMode.THIRD_PERSON, Profile.CameraMode.FIXED]:
		island.call("_set_camera_mode", mode, false)
		run.player_pos = run.cargo_pos[0]
		for i in 4:
			await physics_frame
			await process_frame
		var player: Node3D = island.get("_player")
		var can: Node3D = cans[0]
		var objective: Label = hud.get("_objective")
		_check(run.is_carrying() and can.visible and can.position.distance_to(player.position) < 1.0
			and objective.text.begins_with("FUEL 0 / 3"),
			"%s: the can is carried at the soldier's side (%.2f m), HUD '%s'" % [Profile.CAMERA_MODE_NAMES[mode],
			can.position.distance_to(player.position), objective.text])
		# The ability slot tells the truth: with a can, the button drops it.
		var ability: Label = hud.get("_ability_status")
		var ring: Control = hud.get("_ability_ring")
		_check(ability.text == "DROP CAN" and ring.modulate.a < 0.5,
			"%s: carrying, the ability slot reads '%s' (dimmed icon)" % [Profile.CAMERA_MODE_NAMES[mode], ability.text])
		run.drop_cargo()
		run.player_pos = run.cargo_pos[0] + Vector3(IslandRun.cargo_pickup_radius() + 3.0, 0, 0)
		for i in 2:
			await physics_frame
			await process_frame
		_check(not run.is_carrying() and (island.get("_can_beacons") as Array)[0].visible,
			"%s: dropped can on the ground with its beacon" % Profile.CAMERA_MODE_NAMES[mode])
		var after: Label = hud.get("_ability_status")
		_check(after.text in ["READY", "COOLDOWN"] and (hud.get("_ability_ring") as Control).modulate.a == 1.0,
			"%s: hands free, the ability slot is back to '%s'" % [Profile.CAMERA_MODE_NAMES[mode], after.text])
		# Back on it next loop: stepping away above re-enabled walking pickup.
	island.queue_free()
	await process_frame
	_finish()
