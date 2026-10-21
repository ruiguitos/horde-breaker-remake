extends Control
## A clear scoped camera view with a circular field stop, behind the HUD.
## The camera supplies the existing ADS zoom; no second world render is needed.


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var centre: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.44
	# Four corner strips close the area outside the circle at any aspect ratio.
	for quadrant: int in 4:
		var start := Vector2(cos(quadrant * PI / 2.0), sin(quadrant * PI / 2.0))
		var end := Vector2(cos((quadrant + 1) * PI / 2.0), sin((quadrant + 1) * PI / 2.0))
		var outer: float = size.length() * 2
		var polygon := PackedVector2Array([centre + start * outer,
			centre + (start + end) * outer, centre + end * outer])
		for step: int in 65:
			var angle: float = (quadrant + 1 - step / 64.0) * PI / 2.0
			polygon.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(polygon, Color(0.015, 0.018, 0.02))
	draw_arc(centre, radius, 0, TAU, 192, Color.BLACK, 4.0, true)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(centre + direction * 4, centre + direction * radius, Color(0.03, 0.035, 0.03), 1.5, true)
	draw_circle(centre, 1.5, Color(0.5, 0.12, 0.08), true, -1.0, true)
