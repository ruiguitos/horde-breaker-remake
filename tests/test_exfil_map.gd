extends SceneTree
## The EXFIL map (game/world/handmade/test/exfil_test.tscn): it loads, has its PlayerStart and ExfilPoint
## markers, Check map (HandmadeIsland.build_map's problems) finds nothing, the beacon is reachable on foot
## from the start along the open ground, its buildings stay under 6 m, and it is not drawn by the sandbox's
## random picks (it is not under islands/).
## Run: godot --headless --path . --script res://tests/test_exfil_map.gd

const SCENE: String = "res://game/world/handmade/test/exfil_test.tscn"
const MAX_BUILDING: float = 6.0
## The instances in extraction_test_arena/layout.json (668 pieces, 640 of them concrete walls).
const LAYOUT_PIECES: int = 668
## A walk from the start to the beacon may not be longer than this many metres (the straight line is about 170).
const MAX_WALK: int = 260

var _failures: int = 0
var _checks: int = 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("TEST: " + what)
	else:
		_failures += 1
		print("TEST FAIL: " + what)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load(SCENE)
	_check(packed != null, "the EXFIL map scene loads")
	if packed == null:
		quit(1)
		return
	var island: HandmadeIsland = packed.instantiate() as HandmadeIsland
	root.add_child(island)
	await process_frame
	await process_frame
	_check(island.get("mission") == &"exfil" and island.size == 256, "the map is 256 m, for the EXFIL mode")
	_check(island.get_node_or_null("Markers/PlayerStart") != null and island.get_node_or_null("Markers/ExfilPoint") != null
		and island.get_node_or_null("Markers/Boat") != null, "the map has PlayerStart, ExfilPoint and Boat markers")
	_check(not HandmadeIsland.island_paths().has(SCENE) and SCENE.begins_with("res://game/world/handmade/test/"),
		"the EXFIL map is under test/, so the sandbox's random picks never draw it")
	var tall: float = 0.0
	var buildings: Node = island.get_node("Buildings")
	for child: Node in buildings.get_children():
		var mesh: BoxMesh = (child as MeshInstance3D).mesh as BoxMesh if child is MeshInstance3D else null
		if mesh != null:
			tall = maxf(tall, mesh.size.y)
	_check(buildings.get_child_count() > 0 and tall <= MAX_BUILDING, "placeholder buildings stay under %d m (tallest %.1f m)" % [int(MAX_BUILDING), tall])
	# Every instance of the arena layout is in the scene: the solid ones in Buildings, the ramp and the dock in Decor
	# (Decor also holds the sea preview).
	var pieces: int = buildings.get_child_count() + island.get_node("Decor").get_child_count() - 1
	_check(pieces == LAYOUT_PIECES, "the scene holds all %d pieces of the arena layout (%d)" % [LAYOUT_PIECES, pieces])
	var terrain: Node = island.get_node("Terrain3D")
	var regions: PackedStringArray = DirAccess.get_files_at(String(terrain.get("data_directory")))
	var region_files: int = 0
	for file: String in regions:
		region_files += 1 if file.trim_suffix(".remap").begins_with("terrain3d") else 0
	_check(region_files > 0 and float(terrain.get("vertex_spacing")) == 1.0 and int(terrain.get("region_size")) == 256,
		"the Terrain3D has its region data (%d files), 1 m spacing and 256 m regions" % region_files)
	var ramp: Node3D = island.get_node("Decor").find_child("Ramp_*", false, false) as Node3D
	var top: Vector3 = ramp.transform * Vector3(0, 0, 2.09) if ramp != null else Vector3.ZERO
	_check(ramp != null and top.y > ramp.position.y + 0.5, "the ramp's top end rises to the platform (%.2f m above its middle)" % [top.y - (ramp.position.y if ramp != null else 0.0)])
	var problems: Array[String] = []
	var map: IslandMap = island.build_map(problems)
	_check(problems.is_empty(), "Check map finds no problem (%s)" % [problems])
	_check(map.boat_dir.z < -0.5, "the boat is moored to face the sea (boat_dir %s)" % [map.boat_dir])
	var walk: int = _walk(map, map.player_start, map.exfil)
	_check(walk > 0 and walk <= MAX_WALK, "the beacon is reachable on foot from PlayerStart (%d steps)" % walk)
	_check(map.exfil.x >= 0.0 and map.player_start.distance_to(map.exfil) > 150.0, "the beacon is at the far end from the start (%.0f m)" % map.player_start.distance_to(map.exfil))
	_spawns_fill_the_target(map)
	await _island_on_the_map(packed)
	island.queue_free()
	await create_timer(0.3).timeout
	print("TEST: exfil map %d checks / %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


## The spawns on this map (open ground around the start): the step's target is reached, not passed.
func _spawns_fill_the_target(map: IslandMap) -> void:
	var ctx := RunContext.new(3)
	ctx.mode = &"exfil"
	ctx.mission = &"exfil"
	ctx.biome = &"beach"
	var run := IslandRun.new(ctx.island_seed(), &"beach", map)
	run.load_context(ctx)
	run.noclip = true
	run.director.elapsed = 100.0  # the second step: 175
	var peak: int = 0
	for k in 480:
		if not run.card_choices.is_empty():
			run.choose_card(0)  # a level-up pauses the run until a card is picked, as the player does
		run.reload_left = 1000.0  # the gun stays reloading: the auto-fire would kill the horde it is counting
		run.step(0.1, Vector2.ZERO, Vector3(0, 0, -1), false)
		peak = maxi(peak, run.horde.count)
	# Kills (the gun, the horde's own deaths) keep the count below the target, so the check is the rate:
	# about 4.5 spawn requests a second for 48 s, none refused for ground, and never above the step's target.
	_check(run.spawn_requests >= 180 and run.spawn_failures == 0 and peak <= 175 and run.director.max_alive == 175,
		"on the open EXFIL map the spawns keep their rate and stop at the step's target (%d requests, %d alive, peak %d)" % [run.spawn_requests, run.horde.count, peak])


## The island itself on this map in EXFIL mode: the run has no mission, its clock shows on the HUD
## ("SURVIVE" then "EXFIL AVAILABLE" at 600 s), and the beacon's point is the map's ExfilPoint.
func _island_on_the_map(packed: PackedScene) -> void:
	var ctx := RunContext.new(3)
	ctx.apply_class(&"recruit")
	ctx.mode = &"exfil"
	ctx.mission = &"exfil"
	ctx.biome = &"beach"
	var profile := Profile.new()
	profile.camera_mode = Profile.CameraMode.FIRST_PERSON
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("handmade_scene", packed)
	island.set("context", ctx)
	island.set("profile", profile)
	root.add_child(island)
	for k in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	var hud: Hud = island.get("hud")
	_check(run.mission == &"exfil" and run.mode == &"exfil" and run.has_exfil(), "the island runs EXFIL on the map, with its beacon")
	_check(hud._objective.text.begins_with("SURVIVE"), "the HUD shows the clock in the objective's place (%s)" % hud._objective.text)
	run.exfil_clock = GameData.EXFIL_OPEN_SECONDS + 0.5  # opened: the next frames show it
	for k in 2:
		await process_frame
	_check(run.exfil_open() and hud._objective.text == "EXFIL AVAILABLE", "at 10:00 the HUD says EXFIL AVAILABLE (%s)" % hud._objective.text)
	island.queue_free()
	await create_timer(0.3).timeout


## Steps of the shortest walk from `from` to `to` over the walkable cells (4-neighbourhood), or -1.
func _walk(map: IslandMap, from: Vector3, to: Vector3) -> int:
	var f: FlowField = map.field
	var start: Vector2i = f.world_to_cell(from)
	var goal: Vector2i = f.world_to_cell(to)
	var dist := PackedInt32Array()
	dist.resize(f.width * f.height)
	dist.fill(-1)
	dist[start.y * f.width + start.x] = 0
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == goal:
			return dist[c.y * f.width + c.x]
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + o
			if n.x < 0 or n.y < 0 or n.x >= f.width or n.y >= f.height:
				continue
			var i: int = n.y * f.width + n.x
			if dist[i] != -1 or f.is_blocked(n.x, n.y):
				continue
			dist[i] = dist[c.y * f.width + c.x] + 1
			queue.append(n)
	return -1
