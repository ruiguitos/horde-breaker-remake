extends SceneTree
## Dev tool: screenshot of the title screen after N frames.
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/dev/title_shot.gd -- out.png 60
var _f: int = 0
func _initialize() -> void:
	root.add_child((load("res://game/main.tscn") as PackedScene).instantiate())
func _process(_d: float) -> bool:
	_f += 1
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if _f >= (int(args[1]) if args.size() > 1 else 60):
		root.get_viewport().get_texture().get_image().save_png(args[0])
		quit(0)
	return false
