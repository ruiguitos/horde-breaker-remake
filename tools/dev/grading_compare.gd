extends SceneTree
## Renders a hand-made island in the game with the colour grading on, then
## off, saves both pictures to user:// and prints how much the image changed
## (mean colour difference, 0..1; under ~0.01 nobody notices).
##   godot --path . --resolution 1280x720 --script res://tools/dev/grading_compare.gd -- <island scene>
var _scene: Node
var _f: int = 0
var _a: Image

func _arg() -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	return args[0] if not args.is_empty() else "res://game/world/handmade/islands/beach_01.tscn"


func _initialize() -> void:
	GraphicsSettings.quality = GraphicsSettings.ULTRA
	_scene = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	_scene.set("handmade_scene", load(_arg()))
	root.add_child(_scene)

func _process(_d: float) -> bool:
	_f += 1
	var cam: Camera3D = _scene.get("_camera")
	if _f == 2:
		print("grading supported: %s, on the active camera: %s" % [Grading.supported(), cam == root.get_viewport().get_camera_3d() and cam.compositor != null])
		if cam.compositor == null:
			quit(1)
			return true
	if _f == 700:
		_a = root.get_viewport().get_texture().get_image()
		for e in cam.compositor.compositor_effects:
			e.enabled = false
	if _f == 704:
		var b: Image = root.get_viewport().get_texture().get_image()
		var diff: float = 0.0
		var n: int = 0
		for y in range(0, _a.get_height(), 8):
			for x in range(0, _a.get_width(), 8):
				var ca: Color = _a.get_pixel(x, y)
				var cb: Color = b.get_pixel(x, y)
				diff += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
				n += 1
		print("mean abs diff on/off: %.4f" % (diff / n / 3.0))
		_a.save_png("user://grading_on_%s.png" % _arg().get_file().get_basename())
		b.save_png("user://grading_off_%s.png" % _arg().get_file().get_basename())
		print("pictures in ", ProjectSettings.globalize_path("user://"))
		quit(0)
	return false
