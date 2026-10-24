extends SceneTree
## Scenery graphics (proposal "Gráficos: estrada, bioma e praia"): the road is dark in the horror preset
## only; each biome's grading is discreet and keeps its mood; the beach's grass and pebbles stay within
## 400 instances and 60 m, and are off on the Low preset. Times are printed as measurements (ms).
## Run: godot --headless --path . --script res://tests/test_scenery_graphics.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


## The grading effect of a biome: its shadows, midtones and highlights (hue, amount, vibrance, lightness).
func _grade(biome: StringName) -> CompositorEffect:
	return GameData.BIOMES[biome]["grading"] as CompositorEffect


func _run() -> void:
	# The horror road: dark asphalt, far darker than the sand.
	var asphalt: StandardMaterial3D = IslandRoads.horror_material()
	var lum: float = asphalt.albedo_color.get_luminance()
	_check(absf(lum - 0.3) < 0.03, "the horror road is dark asphalt, about 0.30 (luminance %.2f)" % lum)

	# Biome grading: discreet (every tint amount small), and each biome keeps its mood.
	var discreet: bool = true
	for biome: StringName in [&"beach", &"jungle", &"port", &"town", &"volcano"]:
		var grade: CompositorEffect = _grade(biome)
		for band: String in ["shadows", "midtones", "highlights"]:
			var v: Vector4 = grade.get(band)
			discreet = discreet and v.y <= 0.25
	_check(discreet, "every biome's grading is discreet: no tint above 0.25")
	var port: CompositorEffect = _grade(&"port")
	var port_tints: float = maxf(maxf((port.get("shadows") as Vector4).y, (port.get("midtones") as Vector4).y), (port.get("highlights") as Vector4).y)
	_check(port_tints <= 0.1, "the port reads grey: its tints are under 0.1 (%.2f)" % port_tints)
	var volcano_highlights: Vector4 = _grade(&"volcano").get("highlights")
	_check(volcano_highlights.x >= 0.02 and volcano_highlights.x <= 0.12 and volcano_highlights.y >= 0.15,
		"the volcano's highlights are orange and visible (hue %.2f, amount %.2f)" % [volcano_highlights.x, volcano_highlights.y])
	var jungle_midtones: Vector4 = _grade(&"jungle").get("midtones")
	_check(jungle_midtones.x >= 0.25 and jungle_midtones.x <= 0.4, "the jungle's midtones are green (hue %.2f)" % jungle_midtones.x)
	var beach_highlights: Vector4 = _grade(&"beach").get("highlights")
	_check(beach_highlights.x >= 0.1 and beach_highlights.x <= 0.2, "the beach's highlights are warm (hue %.2f)" % beach_highlights.x)

	# The beach cover: placed on open sand, within 400 instances and 60 m, and off on the Low preset.
	var t0: int = Time.get_ticks_usec()
	var map: IslandMap = IslandMap.build(7, &"beach")
	map.mark_roads(IslandRoads.plan(map))  # the roads are marked before the cover is drawn, as the island does
	var t1: int = Time.get_ticks_usec()
	var cover: BeachVegetation = BeachVegetation.for_map(map, 7)
	root.add_child(cover)
	var t2: int = Time.get_ticks_usec()
	var player: Vector3 = map.player_start
	cover.follow(player)
	var t3: int = Time.get_ticks_usec()
	var shown: Vector2i = cover.shown()
	_check(shown.x + shown.y <= BeachVegetation.MAX_INSTANCES and shown.x + shown.y > 0,
		"the beach cover shows %d grass tufts and %d pebbles, within %d" % [shown.x, shown.y, BeachVegetation.MAX_INSTANCES])
	var far: int = 0
	for o: Vector3 in cover.shown_origins():
		far += 1 if Vector2(o.x - player.x, o.z - player.z).length() > BeachVegetation.RADIUS + 0.5 else 0
	_check(far == 0, "every shown instance stands within %d m of the player (%d outside)" % [int(BeachVegetation.RADIUS), far])
	var places: int = cover.get("_places").size()
	print("MEASURE beach island: map %.0f ms, cover build %.1f ms, placing %.2f ms, %d places drawn, %d shown (%d grass, %d pebbles)" % [
		(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0, places, shown.x + shown.y, shown.x, shown.y])

	# Low preset: no cover at all, and it comes back when the preset changes back.
	GraphicsSettings.quality = GraphicsSettings.LOW
	cover.follow(player)
	_check(cover.shown() == Vector2i(0, 0), "on the Low preset the beach has no grass or pebbles")
	GraphicsSettings.quality = GraphicsSettings.HIGH
	cover.follow(player)
	_check(cover.shown() != Vector2i(0, 0), "back on a higher preset, the cover is placed again")

	# Low clears the origins too, so the two ways of reading the cover agree.
	GraphicsSettings.quality = GraphicsSettings.LOW
	cover.follow(player)
	_check(cover.shown_origins().size() == 0 and cover.shown() == Vector2i(0, 0), "on Low, the origins and the counts both read empty")
	GraphicsSettings.quality = GraphicsSettings.HIGH

	# Walking less than MOVE_REFRESH does not place again, and every shown instance is still within 60 m.
	GraphicsSettings.quality = GraphicsSettings.HIGH
	cover.follow(player)
	var walked: Vector3 = player + Vector3(5.5, 0.0, 0.0)
	cover.follow(walked)
	var beyond: int = 0
	for o: Vector3 in cover.shown_origins():
		beyond += 1 if Vector2(o.x - walked.x, o.z - walked.z).length() > BeachVegetation.RADIUS else 0
	_check(beyond == 0, "after walking 5.5 m without a new placement, every shown instance is within 60 m (%d beyond)" % beyond)

	# The places are open sand: no road cell (the roads are marked before the cover is drawn), no deck, no sea.
	var bad_places: int = 0
	for p: Vector3 in cover.get("_places"):
		var cell: Vector2i = map.field.world_to_cell(p)
		var on_road: bool = not map.cover.is_empty() and map.cover[cell.y * map.field.width + cell.x] != 0
		bad_places += 1 if on_road or map.surface_at(p) != &"sand" or p.y < 0.0 else 0
	_check(bad_places == 0, "every place is open sand off the roads and the decks (%d bad)" % bad_places)

	# The generated road's lamps keep their materials when the horror asphalt goes on the road.
	var parent := Node3D.new()
	root.add_child(parent)
	var path := PackedVector3Array([Vector3(0, 0, 0), Vector3(12, 0, 0), Vector3(24, 0, 0), Vector3(36, 0, 0)])
	var paths: Array[PackedVector3Array] = [path]
	var roads: Node3D = IslandRoads.build(parent, paths)
	var lamps: Array[MeshInstance3D] = []
	var lamp_materials: Array[Material] = []
	if roads != null:
		# The lamps are StreetLamp nodes under the road manager, each with its pole, arm and bulb meshes.
		for mesh: Node in roads.find_children("*", "MeshInstance3D", true, false):
			if mesh.get_parent().name.begins_with("StreetLamp"):
				lamps.append(mesh as MeshInstance3D)
				lamp_materials.append((mesh as MeshInstance3D).material_override)
	IslandRoads.darken(parent)
	var surface_dark: bool = roads != null and roads.get("material_resource") is StandardMaterial3D \
		and absf((roads.get("material_resource") as StandardMaterial3D).albedo_color.get_luminance() - 0.3) < 0.03
	_check(surface_dark, "a generated road takes the dark asphalt as its surface")
	var lamps_kept: bool = lamps.size() > 0
	for i in lamps.size():
		lamps_kept = lamps_kept and is_same(lamps[i].material_override, lamp_materials[i])
	_check(lamps_kept, "the lamps on a generated road keep their own materials (%d lamps)" % lamps.size())
	parent.free()

	cover.free()
	quit(1 if _failures > 0 else 0)
