class_name RoutePreview
extends Control
## Small native illustration for each biome; no external terrain dependency.

var biome: StringName = &"beach"


func _ready() -> void:
	if custom_minimum_size.y == 0:
		custom_minimum_size.y = 92
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var info: Dictionary = GameData.BIOMES[biome]
	draw_rect(Rect2(Vector2.ZERO, size), info["sky"])
	draw_circle(size * Vector2(0.78, 0.24), 10, Color("edcc83"))
	var shore := PackedVector2Array([Vector2(0, 0.8), Vector2(0.15, 0.46), Vector2(0.3, 0.54), Vector2(0.5, 0.28), Vector2(0.7, 0.55), Vector2(1, 0.72), Vector2(1, 1), Vector2(0, 1)])
	for i in shore.size():
		shore[i] *= size
	draw_colored_polygon(shore, info["inland"])
	if biome == &"volcano":
		draw_colored_polygon(PackedVector2Array([size * Vector2(0.25, 0.86), size * Vector2(0.48, 0.15), size * Vector2(0.72, 0.86)]), Color("352925"))
		draw_line(size * Vector2(0.48, 0.18), size * Vector2(0.57, 0.82), Color("ec7035"), 5)
	elif biome == &"town":
		for i in 6:
			var pos := size * Vector2(0.1 + i * 0.14, 0.6)
			draw_rect(Rect2(pos, Vector2(20, 24)), info["building"])
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-3, 0), pos + Vector2(10, -10), pos + Vector2(23, 0)]), Color("504137"))
	elif biome == &"port":
		for i in 6:
			draw_rect(Rect2(size * Vector2(0.08 + i * 0.14, 0.67), Vector2(25, 16)), info["building"] if i % 2 == 0 else Color("536975"))
		draw_polyline(PackedVector2Array([size * Vector2(0.3, 0.7), size * Vector2(0.35, 0.16), size * Vector2(0.66, 0.32), size * Vector2(0.62, 0.7)]), Color("44494a"), 3)
	else:
		for i in 6:
			var foot := size * Vector2(0.08 + i * 0.16, 0.84)
			var crown := foot - Vector2(5, 25 + (i % 3) * 7)
			draw_line(foot, crown, Color("51442e"), 3)
			draw_colored_polygon(PackedVector2Array([crown + Vector2(-15, 7), crown + Vector2(-4, -6), crown + Vector2(15, 5), crown, crown + Vector2(-1, 12)]), info["foliage"])
	draw_rect(Rect2(Vector2(0, size.y * 0.84), Vector2(size.x, size.y * 0.16)), Color("334e55"))
