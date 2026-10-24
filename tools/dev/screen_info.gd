extends SceneTree
## Prints what the display tells Godot: every screen in logical pixels, its
## scale, the usable rect and the window size. Answers "why can I not pick a
## bigger resolution?". Run it windowed:
##   godot --path . --script res://tools/dev/screen_info.gd


func _initialize() -> void:
	var count: int = DisplayServer.get_screen_count()
	print("SCREENS count=%d current=%d window=%s" % [count, DisplayServer.window_get_current_screen(),
		str(DisplayServer.window_get_size())])
	for i in count:
		var size: Vector2i = DisplayServer.screen_get_size(i)
		var usable: Rect2i = DisplayServer.screen_get_usable_rect(i)
		print("SCREEN %d size=%s usable=%s pos=%s scale=%.3f dpi=%d" % [
			i, str(size), str(usable), str(DisplayServer.screen_get_position(i)),
			DisplayServer.screen_get_scale(i), DisplayServer.screen_get_dpi(i)])
	var project: Vector2i = Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	print("PROJECT viewport=%s stretch=%s" % [str(project), ProjectSettings.get_setting("display/window/stretch/mode")])
	quit(0)
