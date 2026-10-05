extends SceneTree
## Dev tool: screenshot of the boat briefing dialogue.
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/dev/briefing_shot.gd -- out.png
var _f: int = 0
var _boat: Control
func _initialize() -> void:
	var ctx := RunContext.new(7)
	_boat = Control.new()
	_boat.set_script(load("res://game/states/boat.gd"))
	_boat.set("context", ctx)
	root.add_child(_boat)
func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		_boat.call("_pick", 0)
		_boat.call("_pick_route", 0)
		_boat.call("_land_now")
	if _f == 240:
		root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		return true
	return false
