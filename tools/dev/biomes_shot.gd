extends SceneTree
## Dev tool: high-camera screenshot of every biome (no enemies).
## xvfb-run godot --rendering-driver opengl3 --path . --script res://tools/dev/biomes_shot.gd -- out_prefix
const BIOMES: Array[StringName] = [&"beach", &"town", &"jungle", &"port", &"volcano"]
var _f: int = 0
var _i: int = 0
var _island: Node
func _initialize() -> void:
	_spawn()
func _spawn() -> void:
	_island = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	var ctx := RunContext.new(31)
	ctx.biome = BIOMES[_i]
	ctx.island_index = 2 if BIOMES[_i] == &"volcano" else 0
	_island.set("context", ctx)
	root.add_child(_island)
	_f = 0
func _process(_d: float) -> bool:
	_f += 1
	var run: IslandRun = _island.get("run")
	if run != null:
		run.director.max_alive = 0
	_island.set("camera_distance", 34.0)
	_island.set("camera_pitch_deg", 50.0)
	if _f == 12:
		root.get_viewport().get_texture().get_image().save_png("%s_%s.png" % [OS.get_cmdline_user_args()[0], BIOMES[_i]])
		_island.queue_free()
		_i += 1
		if _i >= BIOMES.size():
			quit(0)
		else:
			_spawn()
	return false
