extends SceneTree
## The beach's grass and pebbles on a HAND-MADE island (beach_01, built by island.gd through
## _build_beach_cover): the cover is there, its instances stand within the radius, and none is on a
## road or deck cell or in the sea. A hand-made island of another biome (jungle_01) has none.
## Built as islands are in the game (island.tscn with the scene as handmade_scene), so the call that
## makes the cover is the one under test. Run: godot --headless --path . --script res://tests/test_beach_cover_handmade.gd

const ISLAND: String = "res://game/world/island.tscn"
const BEACH: String = "res://game/world/handmade/islands/beach_01.tscn"
const JUNGLE: String = "res://game/world/handmade/islands/jungle_01.tscn"

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	GraphicsSettings.quality = GraphicsSettings.HIGH
	var beach: Node = await _island(BEACH, &"beach")
	if beach != null:
		_beach_checks(beach)
		await _free(beach)
	var jungle: Node = await _island(JUNGLE, &"jungle")
	if jungle != null:
		var map: IslandMap = jungle.run.map
		_check(map.biome == &"jungle" and jungle.get("_vegetation") == null, "a hand-made jungle island has no grass or pebbles (biome %s)" % map.biome)
		await _free(jungle)
	quit(1 if _failures > 0 else 0)


func _beach_checks(beach: Node) -> void:
	var map: IslandMap = beach.run.map
	var f: FlowField = map.field
	_check(map.handmade and map.biome == &"beach", "beach_01 is a hand-made beach island")
	var road_cells: int = 0
	for c: int in map.cover:
		road_cells += 1 if c == IslandMap.COVER_ROAD else 0
	_check(map.cover.size() == f.width * f.height and road_cells > 0, "beach_01 has road cells for the cover to keep off (%d)" % road_cells)
	var cover: BeachVegetation = beach.get("_vegetation")
	_check(cover != null and cover.get_parent() == beach, "a hand-made beach has its grass and pebbles")
	if cover == null:
		return
	# Every candidate place is open ground: not blocked, not road or deck, above the sea.
	var places: PackedVector3Array = cover.get("_places")
	var bad_places: int = 0
	for p: Vector3 in places:
		bad_places += 1 if _bad_place(map, p) else 0
	_check(places.size() > 0 and bad_places == 0, "every place of the hand-made beach is open ground, off the roads and decks and above the sea (%d places, %d bad)" % [places.size(), bad_places])
	# The shown instances: a positive count within the cap, all listed, all within the radius, none on a bad place.
	var player: Vector3 = beach.run.player_pos
	cover.follow(player)
	var shown: Vector2i = cover.shown()
	var origins: PackedVector3Array = cover.shown_origins()
	var total: int = shown.x + shown.y
	_check(total > 0 and total <= BeachVegetation.MAX_INSTANCES and origins.size() == total,
		"the hand-made beach shows %d grass and %d pebbles, all listed (%d origins)" % [shown.x, shown.y, origins.size()])
	var far: int = 0
	var bad: int = 0
	for o: Vector3 in origins:
		far += 1 if Vector2(o.x - player.x, o.z - player.z).length() > BeachVegetation.RADIUS else 0
		bad += 1 if _bad_place(map, o) else 0
	_check(far == 0, "every shown instance stands within %d m of the player (%d outside)" % [int(BeachVegetation.RADIUS), far])
	_check(bad == 0, "no shown instance is on a road or deck cell, in the sea or on a blocked cell (%d bad)" % bad)
	# Low clears the cover; back on High, the same places get the same cover again (the same origins, in order).
	var before: PackedVector3Array = cover.shown_origins()  # a packed array is copied on assignment
	GraphicsSettings.quality = GraphicsSettings.LOW
	cover.follow(player)
	_check(cover.shown() == Vector2i.ZERO and cover.shown_origins().is_empty(), "on Low the hand-made beach has no grass or pebbles")
	GraphicsSettings.quality = GraphicsSettings.HIGH
	cover.follow(player)
	_check(cover.shown_origins() == before, "back on High, the same places get the same cover (%d grass, %d pebbles)" % [cover.shown().x, cover.shown().y])


## Whether a point (a place, or a shown origin lifted above the ground) is not open ground: a blocked
## cell, a road or deck cell, the sea, or a cell outside the map. The ground height is read at the
## point's x and z, so a lifted origin is judged by the ground under it. The Terrain3D paint is not
## read: the map has no per-cell material, so "sand" is the beach biome's ground, not a checked texture.
func _bad_place(map: IslandMap, p: Vector3) -> bool:
	var f: FlowField = map.field
	var cell: Vector2i = f.world_to_cell(p)
	if cell.x < 0 or cell.y < 0 or cell.x >= f.width or cell.y >= f.height:
		return true
	var covered: bool = map.cover[cell.y * f.width + cell.x] != 0
	var in_sea: bool = map.ground_y(Vector3(p.x, 0.0, p.z)) < BeachVegetation.SEA_LEVEL
	return f.is_blocked(cell.x, cell.y) or covered or in_sea


## An island built as the game builds one: island.tscn with the hand-made scene and a run context of `biome`.
func _island(path: String, biome: StringName) -> Node:
	var ctx := RunContext.new(1)
	ctx.biome = biome
	var profile := Profile.new()
	profile.camera_mode = Profile.CameraMode.FIRST_PERSON
	var island: Node = (load(ISLAND) as PackedScene).instantiate()
	island.set("handmade_scene", load(path))
	island.set("context", ctx)
	island.set("profile", profile)
	root.add_child(island)
	await _settle(2)
	return island


## Frames for queued frees to run: a node still alive at quit keeps its resources in use.
func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


## Frees `node` and waits until it is really gone, then lets a stopped sound release (the audio thread
## mixes it a few hundred milliseconds later under the headless driver).
func _free(node: Node) -> void:
	node.queue_free()
	var frames: int = 0
	while is_instance_valid(node) and frames < 120:
		await process_frame
		frames += 1
	await create_timer(0.3).timeout
