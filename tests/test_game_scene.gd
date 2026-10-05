extends SceneTree
## The game scene runs 300 frames headless and the island simulation advances.
## Run: godot --headless --path . --script res://tests/test_game_scene.gd

var _frames: int = 0


func _initialize() -> void:
	root.add_child((load("res://game/main.tscn") as PackedScene).instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 1200:
		return false
	var island: Node = root.get_node("Main").get_child(0)
	var run: IslandRun = island.get("run")
	var ok: bool = run != null and run.time_alive > 3.0 and run.horde.count > 0
	if ok:
		print("TEST: game scene runs (%.1f s simulated, %d enemies)" % [run.time_alive, run.horde.count])
	else:
		print("TEST FAIL: game scene did not simulate (run %s)" % [str(run.time_alive) + " s, " + str(run.horde.count) + " enemies" if run != null else "null"])
	quit(0 if ok else 1)
	return false
