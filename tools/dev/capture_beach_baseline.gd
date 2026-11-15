extends SceneTree
## Writes tests/fixtures/beach_visual_baseline.json from the current beach_01: the digests of its
## blocking, cover and heights, and every marker's position. Run it only after a deliberate change
## of the layout (as the open-island pilot's 512 m rebuild, 2026-11-15): the test that reads the
## fixture exists to catch the changes nobody meant.
## Run: godot --headless --path . --script res://tools/dev/capture_beach_baseline.gd

const BEACH: String = "res://game/world/handmade/islands/beach_01.tscn"
const OUT: String = "res://tests/fixtures/beach_visual_baseline.json"


func _initialize() -> void:
	call_deferred("_run")


func _digest(value: Variant) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(var_to_bytes(value))
	return hash.finish().hex_encode()


func _run() -> void:
	var island: HandmadeIsland = (load(BEACH) as PackedScene).instantiate()
	var problems: Array[String] = []
	var map: IslandMap = island.build_map(problems)
	var markers: Dictionary = {}
	for marker: Node3D in island.get_node("Markers").get_children():
		markers[str(marker.name)] = [marker.position.x, marker.position.y, marker.position.z]
	var data: Dictionary = {"blocked": _digest(map.field.blocked), "cover": _digest(map.cover), "heights": _digest(map.heights), "markers": markers, "problems": problems}
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ") + "\n")
	file.close()
	print("beach baseline written: %d markers, problems %s" % [markers.size(), problems])
	island.free()
	quit(0)
