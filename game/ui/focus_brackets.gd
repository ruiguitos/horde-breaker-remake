class_name FocusBrackets
extends StyleBox
## Focus state: four corner brackets drawn just outside the control, like a
## sight. Focus is told apart by shape (not only colour), so it still reads
## for colour-blind players and on washed-out TVs. Used as the "focus"
## stylebox of every focusable control in UiTheme.

@export var color: Color = Color("f2b23a")
@export var thickness: float = 3.0  ## stroke width in pixels
@export var length: float = 12.0  ## length of each bracket arm
@export var gap: float = 3.0  ## space between the control's edge and the stroke


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var r := rect.grow(gap + thickness)
	var arm: float = minf(length, minf(r.size.x, r.size.y) * 0.5)
	var t := thickness
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), r.end]
	for corner in corners:
		# Sign of each arm: point inwards from the corner.
		var sx: float = 1.0 if corner.x == r.position.x else -1.0
		var sy: float = 1.0 if corner.y == r.position.y else -1.0
		var x0: float = corner.x if sx > 0.0 else corner.x - arm
		var y0: float = corner.y if sy > 0.0 else corner.y - t
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(x0, y0, arm, t), color)
		x0 = corner.x if sx > 0.0 else corner.x - t
		y0 = corner.y if sy > 0.0 else corner.y - arm
		RenderingServer.canvas_item_add_rect(to_canvas_item, Rect2(x0, y0, t, arm), color)
