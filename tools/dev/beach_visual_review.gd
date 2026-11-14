extends SceneTree
## Actual game cameras, isolated in-memory profile, repeatable poses and light.
## godot --path . --resolution 1280x720 --script res://tools/dev/beach_visual_review.gd -- <scene> <out_dir> [normal|horror]
var _world: Node3D
var _out: String
var _frame: int = 0
var _grid_saved: bool = false
var _views: Array[Dictionary] = [
	{"name":"village_third", "pose":Vector2(55, 128), "mode":Profile.CameraMode.THIRD_PERSON, "yaw":0.0},
	{"name":"village_first", "pose":Vector2(55, 128), "mode":Profile.CameraMode.FIRST_PERSON, "yaw":0.0},
	{"name":"village_fixed", "pose":Vector2(55, 128), "mode":Profile.CameraMode.FIXED, "yaw":0.0},
	{"name":"shore_third", "pose":Vector2(128, 205), "mode":Profile.CameraMode.THIRD_PERSON, "yaw":PI},
	{"name":"bridge_fixed", "pose":Vector2(128, 140), "mode":Profile.CameraMode.FIXED, "yaw":0.0},
	{"name":"tower_third", "pose":Vector2(121.5, 62), "mode":Profile.CameraMode.THIRD_PERSON, "yaw":0.0},
]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected scene and output directory")
		quit(1)
		return
	if args.size() > 3:
		_views = _views.filter(func(view: Dictionary) -> bool: return view.name == args[3])
		if _views.is_empty():
			push_error("Unknown capture view: " + args[3])
			quit(1)
			return
	_out = args[1]
	DirAccess.make_dir_recursive_absolute(_out)
	Profile.current = Profile.new()
	Profile.current.camera_mode = Profile.CameraMode.THIRD_PERSON
	var context := RunContext.new(7)
	context.biome = &"beach"
	context.atmosphere = StringName(args[2]) if args.size() > 2 else &"normal"
	_world = load("res://game/world/island.tscn").instantiate()
	_world.set("handmade_scene", load(args[0]))
	_world.set("context", context)
	root.add_child(_world)
	_world.set_process_input(false)
	_world.set_process_unhandled_input(false)

func _process(_delta: float) -> bool:
	_frame += 1
	var run: IslandRun = _world.get("run")
	if run == null:
		return false
	if not _grid_saved:
		if not _save_image(HandmadeIsland.grid_image(run.map), "grid.png"):
			return true
		_grid_saved = true
	run.hp = run.max_hp
	run.noclip = false
	_world.set("_fly", 0.0)
	run.director.max_alive = 0
	if _frame < 240:
		return false
	var view_index: int = (_frame - 240) / 180
	var phase: int = (_frame - 240) % 180
	if view_index >= _views.size():
		print("TEST: beach review captures saved in ", _out)
		quit()
		return true
	var view: Dictionary = _views[view_index]
	var point: Vector2 = view.pose
	run.player_pos = Vector3(point.x, run.map.ground_y(Vector3(point.x, 0, point.y)), point.y)
	run.facing = Vector3.FORWARD.rotated(Vector3.UP, view.yaw)
	_world.set("_tp_yaw", view.yaw)
	if phase == 0:
		_world.call("_set_camera_mode", view.mode, false)
	if phase == 179:
		if not _save_image(root.get_texture().get_image(), view.name + ".png"):
			return true
	return false

func _save_image(image: Image, filename: String) -> bool:
	var result: Error = image.save_png(_out.path_join(filename))
	if result != OK:
		push_error("Capture could not save %s: %s" % [filename, error_string(result)])
		quit(1)
		return false
	return true
