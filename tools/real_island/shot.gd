extends SceneTree
# Pictures of a built island as the game shows it (island.tscn, sky, light):
#   godot --path . --script res://tools/real_island/shot.gd -- <scene.scn> <out_prefix> tx,tz,dx,dy,dz [more views...]
# Each view looks at the ground at (tx, tz) + 1.5 m from (dx, dy, dz) away.
# Writes <out_prefix>_<n>.png. Needs a window (GPU), not --headless.

var _scene: Node
var _cam: Camera3D
var _t0: int
var _frame: int = -1
var _views: Array = []
var _out: String


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[1]
	for k in range(2, args.size()):
		_views.append(Array(args[k].split(",")).map(func(s: String) -> float: return s.to_float()))
	_t0 = Time.get_ticks_msec()
	_scene = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	_scene.set("handmade_scene", load(args[0]))
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	var run: IslandRun = _scene.get("run")
	run.hp = run.max_hp
	run.horde.positions.fill(Vector3(-100, 0, -100))
	if Time.get_ticks_msec() - _t0 < 8000:
		return false
	if _frame < 0:
		_cam = Camera3D.new()
		_cam.far = 3000.0
		_scene.add_child(_cam)
		_cam.current = true
		_frame = 0
	var k: int = _frame / 40
	if k >= _views.size():
		quit(0)
		return true
	var v: Array = _views[k]
	var t := Vector3(v[0], 0, v[1])
	t.y = run.map.ground_y(t) + 1.5
	run.player_pos = Vector3(v[0], 0, v[1])  # terrain detail and grass follow the player
	_cam.look_at_from_position(t + Vector3(v[2], v[3], v[4]), t)
	if _frame % 40 == 39:
		var path: String = "%s_%d.png" % [_out, k]
		root.get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	_frame += 1
	return false
