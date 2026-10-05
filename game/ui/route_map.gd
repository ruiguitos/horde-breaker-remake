class_name RouteMap
extends Control
## Decorative chart: selected markers correspond to the two offered routes.

var biomes: Array[StringName] = []
var selected: int = -1:
	set(value):
		selected = value
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(340, 240)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("141a15"))
	for x in range(0, int(size.x), 28):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.5, 0.6, 0.45, 0.12))
	for y in range(0, int(size.y), 28):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.5, 0.6, 0.45, 0.12))
	var centers: Array[Vector2] = [Vector2(0.28, 0.27), Vector2(0.68, 0.68), Vector2(0.74, 0.2), Vector2(0.2, 0.79), Vector2(0.55, 0.4)]
	for i in centers.size():
		for contour in range(8, 0, -1):
			var points := PackedVector2Array()
			for step in 65:
				var a: float = step * TAU / 64.0
				var radius: float = minf(size.x, size.y) * (0.045 + contour * 0.012) * (1.0 + 0.2 * sin(3.0 * a + i) + 0.12 * cos(7.0 * a - i))
				points.append(centers[i] * size + Vector2(cos(a), sin(a) * 1.25) * radius)
			if contour == 8:
				draw_colored_polygon(points, Color("242f20"))
			draw_polyline(points, Color(0.45, 0.52, 0.32, 0.55), 1.0, true)
	var origin := Vector2(0.45, 0.92) * size
	for i in mini(2, biomes.size()):
		var marker: Vector2 = centers[i] * size
		var color: Color = UiTheme.ACCENT if selected == i else UiTheme.MUTED
		for segment in range(0, 12, 2):
			draw_line(origin.lerp(marker, segment / 12.0), origin.lerp(marker, (segment + 1) / 12.0), color, 1.0, true)
		draw_arc(marker, 12, 0, TAU, 32, color, 2.0, true)
		draw_circle(marker, 5, color)
		var label_text: String = "%d / %s" % [i + 4, String(GameData.BIOMES[biomes[i]]["name"]).to_upper()]
		var label_width: float = UiTheme.mono_font().get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		var label_x: float = clampf(marker.x + 18, 16, maxf(16, size.x - label_width - 16))
		draw_string(UiTheme.mono_font(), Vector2(label_x, marker.y + 28), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)
	draw_circle(origin, 4, UiTheme.TEXT)
	draw_string(UiTheme.mono_font(), Vector2(16, 24), "N ↑ / HALVARD ARCHIPELAGO", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.MUTED)
	draw_string(UiTheme.mono_font(), Vector2(16, size.y - 16), "TACTICAL OVERVIEW / SCHEMATIC", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, UiTheme.MUTED)
