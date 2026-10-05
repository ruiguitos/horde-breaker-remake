extends SceneTree
## Dev tool: runs the game for N frames with a scripted player and saves a
## screenshot. Needs a display (e.g. xvfb-run) and a non-headless renderer:
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/dev/screenshot.gd -- out.png 600

var _frames: int = 0
var _target: int = 600
var _out: String = "user://screenshot.png"
var _island: Node


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	if args.size() > 1:
		_target = int(args[1])
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	_frames += 1
	var island: Node = root.get_node("Main").get_child(0)
	var run: IslandRun = island.get("run")
	if run != null:
		if _frames == 2:
			for k in 40:
				var a: float = k * 0.7
				var pos: Vector3 = run.player_pos + Vector3(cos(a), 0, sin(a)) * (6.0 + k * 0.15)
				if not Horde.overlaps_wall(run.field, pos.x, pos.z, 0.4):
					run.horde.add(pos, k % 4, run.rng)
		run.choose_card(0)
		# Walk towards the first generator and keep healthy for the picture.
		var to: Vector3 = run.map.generators[0] - run.player_pos
		if to.length() > 2.0:
			run.player_pos = Horde.move_against_walls(run.field, run.player_pos, to.normalized().x * 0.1, to.normalized().z * 0.1, 0.4)
		run.hp = GameData.PLAYER_MAX_HP
		var near: PackedInt32Array = run.horde.query_radius(run.player_pos, 20.0)
		if near.size() > 0:
			run.facing = (run.horde.positions[near[0]] - run.player_pos).normalized()
	if _frames >= _target:
		var img: Image = root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out, " ", img.get_size())
		quit(0)
	return false
