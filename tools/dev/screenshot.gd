extends SceneTree
## Renders pictures of a scene for review without a GPU (software OpenGL):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1280x720 --script res://tools/dev/screenshot.gd -- <scene.tscn> <out_dir>
## Writes top.png (orthographic, whole island), four oblique views
## (view_n/e/s/w.png) and a close view of every Choke_* and Arena_* marker
## (close_<marker>.png, from 16 m south and 9 m up: about the game camera).
## Lighting is a plain sun and sky colour.

var _scene: Node3D
var _cam: Camera3D
var _out: String
var _frame: int = 0
var _shots: Array = []
var _size: float = 160.0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "res://game/world/handmade/island_template.tscn"
	_out = args[1] if args.size() > 1 else "user://shots"
	DirAccess.make_dir_recursive_absolute(_out)
	_scene = (load(path) as PackedScene).instantiate()
	root.add_child(_scene)
	if _scene.get("size") != null:
		_size = float(_scene.get("size"))
	_cam = Camera3D.new()
	_cam.far = 2000.0
	root.add_child(_cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.6, 0.75, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	root.add_child(env)
	var c := Vector3(_size * 0.5, 0, _size * 0.5)
	_shots = [
		["top", c + Vector3(0, 300, 0.01), c, true],
		["view_s", c + Vector3(0, _size * 0.55, _size * 0.95), c, false],
		["view_n", c + Vector3(0, _size * 0.55, -_size * 0.95), c, false],
		["view_e", c + Vector3(_size * 0.95, _size * 0.55, 0), c, false],
		["view_w", c + Vector3(-_size * 0.95, _size * 0.55, 0), c, false],
	]
	var markers: Node = _scene.get_node_or_null("Markers")
	if markers != null:
		for m in markers.get_children():
			if m is Node3D and (m.name.begins_with("Choke_") or m.name.begins_with("Arena_")):
				var p: Vector3 = (m as Node3D).position
				_shots.append(["close_" + String(m.name), p + Vector3(0, 9, 16), p + Vector3(0, 1, 0), false])
	var terrain: Node = _scene.get_node_or_null("Terrain3D")
	if terrain != null:
		terrain.call("set_camera", _cam)


func _process(_delta: float) -> bool:
	_frame += 1
	# Wait for the boot splash and terrain, then one shot every 20 frames.
	var start: int = 240
	if _frame < start:
		return false
	var k: int = (_frame - start) / 20
	var phase: int = (_frame - start) % 20
	if k >= _shots.size():
		print("screenshots in ", ProjectSettings.globalize_path(_out))
		quit(0)
		return true
	var s: Array = _shots[k]
	if phase == 0:
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL if s[3] else Camera3D.PROJECTION_PERSPECTIVE
		_cam.size = _size * 1.1
		_cam.fov = 60.0
		_cam.look_at_from_position(s[1], s[2])
		_cam.current = true
	elif phase == 19:
		root.get_viewport().get_texture().get_image().save_png(_out.path_join(s[0] + ".png"))
	return false
