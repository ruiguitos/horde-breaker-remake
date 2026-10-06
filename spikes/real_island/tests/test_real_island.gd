extends SceneTree
## The built island (out/real_island.tscn) loads and has its parts: terrain
## with saved regions, buildings, a lighthouse, vegetation chunks with
## instances, a camera. Skips (exit 0) when the data or the build is missing:
## both stay out of git (see README).
## Run: godot --headless --path . --script res://spikes/real_island/tests/test_real_island.gd

const SCENE: String = "res://spikes/real_island/out/real_island.tscn"

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	if not ResourceLoader.exists(SCENE):
		print("TEST: skipped (run fetch_data.py and build.gd first)")
		quit(0)
		return
	var island: Node3D = (load(SCENE) as PackedScene).instantiate()
	var terrain: Node = island.get_node_or_null("Terrain3D")
	var dir: String = terrain.get("data_directory") if terrain != null else ""
	_check(terrain != null and DirAccess.get_files_at(dir).size() > 0, "terrain with saved regions (%s)" % dir)
	_check(island.get_node_or_null("Buildings/Walls") != null and island.get_node_or_null("Buildings/Roofs") != null, "buildings: walls and roofs")
	_check(island.get_node_or_null("Buildings/Lighthouse_0") != null, "lighthouse")
	var chunks: int = 0
	var instances: int = 0
	for group in island.get_node("Nature").get_children():
		for c in group.get_children():
			chunks += 1
			instances += (c.get("transforms") as PackedFloat32Array).size() / 12
	_check(chunks > 50 and instances > 100000, "vegetation in %d chunks, %d instances" % [chunks, instances])
	_check(island.get_node_or_null("FlyCamera") is Camera3D, "fly camera")
	island.free()
	quit(1 if _failures > 0 else 0)
