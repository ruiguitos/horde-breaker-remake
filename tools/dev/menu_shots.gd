extends SceneTree
## Dev tool: pictures of the screens outside the main menus, to check they share the title's
## dossier look: the expedition camp, the loading screen, the end-of-island panel, the boat
## briefing dialogue and the defeat report. Needs a window (not headless):
##   godot --path . --resolution 1600x900 --windowed --position 3000,3000 --script res://tools/dev/menu_shots.gd -- <out dir>

var _out: String
var _f: int = 0
var _step: int = 0
var _node: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else "user://menu_shots"
	DirAccess.make_dir_recursive_absolute(_out)
	if Profile.current == null:
		Profile.current = Profile.new()


func _process(_d: float) -> bool:
	_f += 1
	if _f < 30 or (_step == 0 and _node == null and _f < 420):  # past the boot splash first
		return false
	if _node == null:
		_node = _make(_step)
		if _node == null:
			return true
		root.add_child(_node)
		_f = 0
		return false
	if _f == 200:
		var image: Image = root.get_viewport().get_texture().get_image()
		image.convert(Image.FORMAT_RGB8)
		image.save_png(_out.path_join("%d_%s.png" % [_step, ["camp", "loading", "end_panel", "briefing", "defeat"][_step]]))
		_node.queue_free()
		_node = null
		_step += 1
		_f = 0
	return false


func _make(step: int) -> Node:
	var ctx := RunContext.new(7)
	ctx.apply_class(&"recruit")
	ctx.biome = &"beach"
	ctx.mission = &"activate"
	match step:
		0:
			var camp := Control.new()
			camp.set_script(load("res://game/states/camp.gd"))
			camp.set("context", ctx)
			return camp
		1:
			return LoadingScreen.new(LoadingScreen.describe(ctx))
		2:
			var holder := Control.new()
			holder.set_anchors_preset(Control.PRESET_FULL_RECT)
			var panel := IslandEndPanel.new()
			holder.add_child(panel)
			var run := IslandRun.new(ctx.island_seed())
			run.load_context(ctx)
			panel.call_deferred("open", run, ctx, false)
			return holder
		3:
			var boat := Control.new()
			boat.set_script(load("res://game/states/boat.gd"))
			boat.set("context", ctx)
			boat.ready.connect(func() -> void:
				boat.call("_pick", 0)
				boat.call("_pick_route", 0)
				boat.call("_land_now"))
			return boat
		4:
			var hud := Hud.new()
			hud.ready.connect(func() -> void: (hud.get("_death_panel") as Control).visible = true)
			return hud
	return null
