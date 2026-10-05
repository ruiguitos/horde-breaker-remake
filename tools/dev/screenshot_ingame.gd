extends SceneTree
## In-game picture of a hand-made island: island.tscn with the scene set as
## handmade_scene, third-person camera, after a few seconds of play.
##   xvfb-run ... godot --path . --rendering-driver opengl3 --script res://tools/dev/screenshot_ingame.gd -- <scene> <out.png> [x z]

var _island: Node
var _frame: int = 0
var _out: String


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[1] if args.size() > 1 else "user://ingame.png"
	_island = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	_island.set("handmade_scene", load(args[0]))
	root.add_child(_island)
	(_island.get("run") as IslandRun).noclip = true  # no damage while posing
	if args.size() > 3:
		var run: IslandRun = _island.get("run")
		run.player_pos = Vector3(float(args[2]), 0, float(args[3]))


func _process(_delta: float) -> bool:
	_frame += 1
	var run: IslandRun = _island.get("run")
	run.hp = run.max_hp  # stay alive while posing
	if _frame == 320:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit(0)
	return false
