extends SceneTree
## Footsteps: a sound for each foot that comes down while the body really walks, on
## the surface under that foot (IslandMap.surface_at). None while standing, turning
## on the spot, paused, dashing, in noclip or in the air, or after a stop.
## Run: godot --headless --path . --script res://tests/test_footsteps.gd

const DT: float = 1.0 / 60.0
const WALK: Vector3 = Vector3(0, 0, -6.0)  ## metres per second, the jog pace
const BEACH_HANDMADE: String = "res://game/world/handmade/islands/beach_01.tscn"

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_sounds()
	_surfaces()
	for id: StringName in [&"recruit", &"vanguard"]:
		await _walking(id)
	await _walking_at_high_frame_rate()
	await _stopping()
	await _without_steps()
	await _paused_while_walking()
	quit(1 if _failures > 0 else 0)


## Each surface plays its own sound; volume and pitch vary a little between steps.
func _sounds() -> void:
	var sfx := Sfx.new()
	root.add_child(sfx)
	var heard: Array = []  # [sound, volume_db, pitch] of each sound played
	sfx.played.connect(func(sound: StringName, volume_db: float, pitch: float) -> void:
		heard.append([sound, volume_db, pitch]))
	var expected: Dictionary = {&"sand": &"step_sand", &"stone": &"step_stone", &"wood": &"step_wood", &"metal": &"step_metal"}
	for surface: StringName in expected:
		heard.clear()
		sfx.play_step(surface)
		_check(heard.size() == 1 and heard[0][0] == expected[surface], "a %s step plays %s" % [surface, expected[surface]])
	heard.clear()
	sfx.play_step(&"carpet")
	_check(heard.size() == 1 and heard[0][0] == &"step_sand", "a surface with no sound of its own steps like sand")
	heard.clear()
	for i in 20:
		sfx.play_step(&"wood")  # all in one frame: none may be dropped
	var volumes: Dictionary = {}
	var pitches: Dictionary = {}
	var within: bool = true
	for entry: Array in heard:
		volumes[snappedf(entry[1], 0.001)] = true
		pitches[snappedf(entry[2], 0.001)] = true
		within = within and absf(entry[1] - Sfx.STEP_VOLUME_DB) <= Sfx.STEP_VOLUME_JITTER_DB + 0.001
		within = within and absf(entry[2] - 1.0) <= Sfx.STEP_PITCH_JITTER + 0.001
	_check(heard.size() == 20, "twenty steps in one frame are all started (%d)" % heard.size())
	_check(within, "steps vary volume and pitch only within their limits")
	_check(volumes.size() > 1 and pitches.size() > 1, "twenty steps do not all sound the same")
	sfx.queue_free()


## The surface under a point comes from the map: decks are wood, roads are stone,
## and the rest of the ground follows the biome.
func _surfaces() -> void:
	var expected: Dictionary = {&"beach": &"sand", &"town": &"stone", &"port": &"metal", &"volcano": &"stone"}
	for biome: StringName in expected:
		var map: IslandMap = IslandMap.build(7, biome)
		var cell: Vector3 = _open_cell(map)
		_check(cell != Vector3.INF and map.surface_at(cell) == expected[biome], "the open ground of a %s island is %s" % [biome, expected[biome]])
	var map: IslandMap = IslandMap.build(7, &"beach")
	var f: FlowField = map.field
	map.cover.resize(f.width * f.height)
	map.cover[20 * f.width + 20] = IslandMap.COVER_ROAD
	map.cover[30 * f.width + 30] = IslandMap.COVER_DECK
	_check(map.surface_at(Vector3(20.5, 0, 20.5)) == &"stone", "a road cell is stone")
	_check(map.surface_at(Vector3(30.5, 0, 30.5)) == &"wood", "a deck cell is wood")
	# A road the planner lays out on a generated island is stone along its line.
	var paths: Array[PackedVector3Array] = IslandRoads.plan(map)
	map.mark_roads(paths)
	_check(not paths.is_empty() and map.surface_at(paths[0][paths[0].size() / 2]) == &"stone", "a planned road on a generated island is stone")
	# A hand-made island: its bridge deck is wood, its road mesh is stone, the rest is sand.
	var island: HandmadeIsland = (load(BEACH_HANDMADE) as PackedScene).instantiate()
	var problems: Array[String] = []
	var hand: IslandMap = island.build_map(problems)
	var bridge: Node3D = island.get_node("Bridges/Bridge_1")
	_check(hand.surface_at(bridge.position) == &"wood", "the bridge deck of beach_01 is wood")
	var road: MeshInstance3D = island.get_node("Decor/Roads/Surface")
	var verts: PackedVector3Array = (road.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var on_road: int = 0
	for i in mini(verts.size(), 40):
		if _near(hand, road.transform * verts[i], &"stone"):
			on_road += 1
	_check(on_road >= 30, "the road mesh of beach_01 is stone (%d of 40 vertices)" % on_road)
	_check(hand.surface_at(_open_cell(hand)) == &"sand", "the open ground of beach_01 is sand")
	island.free()


## Walking on flat ground: one footstep for each foot that comes down, and no more
## than about four a second (a double sound on every stride would be twice that).
func _walking(id: StringName) -> void:
	var soldier := SoldierModel.create(id)
	root.add_child(soldier)
	soldier.position = Vector3(20, 0, 20)
	var feet: Node = soldier.find_child("FootContact", true, false)
	var planted: Array = [0]
	var steps: Array = [0]
	feet.connect(&"planted", func(_point: Vector3) -> void: planted[0] += 1)
	soldier.footstep.connect(func(_point: Vector3) -> void: steps[0] += 1)
	for i in 180:
		soldier.grounded = true
		soldier.animate(1.0, 0.0, false, DT)
		soldier.position += WALK * DT
		await process_frame
	# The jog clip is 0.93 s per stride and plants each foot once a stride: about six
	# footsteps in 3 s. A second sound on each plant would make about twelve.
	_check(steps[0] >= 5 and steps[0] <= 8, "%s: walking 3 s at jog pace makes %d footsteps" % [id, steps[0]])
	_check(steps[0] == planted[0], "%s: each planted foot makes one footstep (%d plants)" % [id, planted[0]])
	soldier.queue_free()
	await process_frame


## After a stop the smoothed speed still drives the legs for a moment; a tenth of a
## second after the stop no footstep may come.
func _stopping() -> void:
	var soldier := SoldierModel.create(&"recruit")
	root.add_child(soldier)
	soldier.position = Vector3(20, 0, 20)
	var steps: Array = [0]
	soldier.footstep.connect(func(_point: Vector3) -> void: steps[0] += 1)
	for i in 60:
		soldier.grounded = true
		soldier.animate(1.0, 0.0, false, DT)
		soldier.position += WALK * DT
		await process_frame
	var settled: int = 0
	for i in 60:
		soldier.grounded = true
		soldier.animate(0.0, 0.0, false, DT)
		await process_frame
		if i == 6:
			settled = steps[0]
	_check(steps[0] == settled, "after a stop, no footsteps once a tenth of a second has passed (%d in the first tenth)" % settled)
	soldier.queue_free()
	await process_frame


## Standing, turning on the spot, paused, dashing, in noclip or in the air: no footsteps.
func _without_steps() -> void:
	var soldier := SoldierModel.create(&"recruit")
	root.add_child(soldier)
	soldier.position = Vector3(20, 0, 20)
	var steps: Array = [0]
	soldier.footstep.connect(func(_point: Vector3) -> void: steps[0] += 1)
	for i in 120:
		soldier.grounded = true
		soldier.animate(0.0, 0.0, false, DT)
		await process_frame
	_check(steps[0] == 0, "standing still makes no footsteps (%d)" % steps[0])
	for i in 120:
		soldier.grounded = true
		soldier.rotation.y += 0.04
		soldier.animate(0.0, 0.0, false, DT)
		await process_frame
	_check(steps[0] == 0, "turning on the spot makes no footsteps (%d)" % steps[0])
	for i in 120:
		soldier.grounded = true
		soldier.animate(1.0, 0.0, false, 0.0)  # paused: the frame time is zero
		soldier.position += WALK * DT
		await process_frame
	_check(steps[0] == 0, "a paused body makes no footsteps (%d)" % steps[0])
	for i in 120:
		soldier.grounded = true
		soldier.set_dashing(true)
		soldier.animate(1.0, 0.0, false, DT)
		soldier.position += WALK * DT
		await process_frame
	_check(steps[0] == 0, "dashing makes no footsteps (%d)" % steps[0])
	soldier.set_dashing(false)
	for i in 120:
		soldier.grounded = false  # noclip, or the flight that follows it
		soldier.animate(1.0, 0.0, false, DT)
		soldier.position += WALK * DT
		await process_frame
	_check(steps[0] == 0, "walking in noclip or in the air makes no footsteps (%d)" % steps[0])
	soldier.queue_free()
	await process_frame


## Rendering faster than the physics (144 frames for each 60 physics steps a second):
## the body moves on some frames only, and the footsteps stay about six in 3 s.
func _walking_at_high_frame_rate() -> void:
	var soldier := SoldierModel.create(&"recruit")
	root.add_child(soldier)
	soldier.position = Vector3(20, 0, 20)
	var steps: Array = [0]
	soldier.footstep.connect(func(_point: Vector3) -> void: steps[0] += 1)
	var frame: float = 1.0 / 144.0
	var physics_left: float = 0.0  # time not yet spent on a physics step
	for i in 432:
		soldier.grounded = true
		soldier.animate(1.0, 0.0, false, frame)
		physics_left += frame
		while physics_left >= 1.0 / 60.0:
			physics_left -= 1.0 / 60.0
			soldier.position += WALK / 60.0
		await process_frame
	_check(steps[0] >= 5 and steps[0] <= 8, "walking 3 s at 144 frames a second makes %d footsteps" % steps[0])
	soldier.queue_free()
	await process_frame


## A pause while walking makes no footsteps: the game clock stands still.
func _paused_while_walking() -> void:
	var soldier := SoldierModel.create(&"recruit")
	root.add_child(soldier)
	soldier.position = Vector3(20, 0, 20)
	var steps: Array = [0]
	soldier.footstep.connect(func(_point: Vector3) -> void: steps[0] += 1)
	for i in 120:
		soldier.grounded = true
		soldier.animate(1.0, 0.0, false, DT)
		soldier.position += WALK * DT
		await process_frame
	var walked: int = steps[0]
	for i in 120:  # paused: the game does not move the body, and the frame time is zero
		soldier.grounded = true
		soldier.animate(1.0, 0.0, false, 0.0)
		await process_frame
	_check(walked >= 2 and steps[0] == walked, "a pause while walking makes no footsteps (%d walking, %d paused)" % [walked, steps[0] - walked])
	soldier.queue_free()
	await process_frame


## The centre of the first cell that is open ground (no surface of its own), or Vector3.INF.
func _open_cell(map: IslandMap) -> Vector3:
	var f: FlowField = map.field
	for z in f.height:
		for x in f.width:
			var covered: bool = not map.cover.is_empty() and map.cover[z * f.width + x] != 0
			if not f.is_blocked(x, z) and not covered:
				return Vector3(x + 0.5, 0, z + 0.5)
	return Vector3.INF


## Whether `surface` is found in the cell under `p` or in one of its eight neighbours.
func _near(map: IslandMap, p: Vector3, surface: StringName) -> bool:
	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if map.surface_at(p + Vector3(dx, 0, dz)) == surface:
				return true
	return false
