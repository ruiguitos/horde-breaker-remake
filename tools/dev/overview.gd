extends SceneTree
## Dev tool: photographs an island from a high camera (no enemies).
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/dev/overview.gd -- out.png
var _f: int = 0
func _initialize() -> void:
	root.add_child((load("res://game/world/island.tscn") as PackedScene).instantiate())
func _process(_d: float) -> bool:
	_f += 1
	var island: Node = root.get_child(root.get_child_count() - 1)
	var run: IslandRun = island.get("run")
	if run != null:
		run.director.max_alive = 0
	island.set("camera_distance", 26.0)
	if _f == 20:
		root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		quit(0)
	return false
