extends SceneTree
## Dev tool: screenshot of an island with the third-person camera.
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/dev/tp_shot.gd -- out.png [biome]
var _f: int = 0
var _island: Node
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_island = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	var ctx := RunContext.new(31)
	ctx.biome = StringName(args[1]) if args.size() > 1 else &"town"
	_island.set("context", ctx)
	root.add_child(_island)
func _process(_d: float) -> bool:
	_f += 1
	var run: IslandRun = _island.get("run")
	if run != null and _f < 5:
		run.director.max_alive = 40
	if _f == 40:
		root.get_viewport().get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
		return true
	return false
