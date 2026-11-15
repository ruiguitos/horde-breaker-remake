class_name RouteMap
extends Control
## The chart of the selected route: the real island it lands on, drawn from the hand-made scene's
## grid picture (HandmadeIsland.grid_image, saved as <scene>_grid.png), as a nautical chart. A
## biome with no hand-made island keeps the decorative chart of the two routes.
## Also home of the progress pips shared by the boat and the camp (StepPip):
## done = filled + tick, current = amber ring, ahead = dashed ring.

enum Step { DONE, CURRENT, AHEAD }

## Route letters, as on the route cards ("A · JUNGLE").
const LETTERS: Array[String] = ["A", "B"]

var biomes: Array[StringName] = []
var selected: int = -1:
	set(value):
		selected = value
		queue_redraw()


func _ready() -> void:
	if custom_minimum_size == Vector2.ZERO:
		custom_minimum_size = Vector2(260, 220)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


## Chart colours: the sea is the panel's dark ground.
const CHART_SEA := Color("141a15")
const CHART_LAND := Color("33402b")
const CHART_HIGH := Color("4a5a3d")  ## raised ground
const CHART_CLIFF := Color("1f2719")
const CHART_BUILDING := Color("8a8f7c")
const CHART_COAST := Color(0.62, 0.68, 0.48)

static var _charts: Dictionary = {}  ## biome -> [Texture2D, boat pixel] (or [] without an island)


## The selected route's island as a chart texture, and where its boat is (in grid pixels).
static func island_chart(biome: StringName) -> Array:
	if _charts.has(biome):
		return _charts[biome]
	var out: Array = []
	var paths: PackedStringArray = HandmadeIsland.island_paths(biome)
	var path: String = paths[0].get_basename() + "_grid.png" if not paths.is_empty() else ""
	if path != "" and ResourceLoader.exists(path):
		var grid: Image = (load(path) as Texture2D).get_image()
		grid.decompress()
		var w: int = grid.get_width()
		var h: int = grid.get_height()
		var chart := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
		var boat := Vector2.ZERO
		var boat_n: int = 0
		var sea := PackedByteArray()
		sea.resize(w * h)
		for z in h:
			for x in w:
				var c: Color = grid.get_pixel(x, z)
				sea[z * w + x] = 1 if c.b > 0.6 and c.r < 0.3 and c.g < 0.5 else 0
		for z in h:
			for x in w:
				if sea[z * w + x] == 1:
					continue
				var c: Color = grid.get_pixel(x, z)
				var ink: Color = CHART_LAND.lerp(CHART_HIGH, clampf((c.r - 0.55) * 2.5, 0.0, 1.0))
				if c.r > 0.9 and c.g > 0.9 and c.b < 0.3:
					boat += Vector2(x, z)
					boat_n += 1
				elif c.r < 0.3 and c.g < 0.25 and c.b < 0.2:
					ink = CHART_CLIFF
				elif absf(c.r - c.g) < 0.03 and absf(c.g - c.b) < 0.03 and c.r > 0.5 and c.r < 0.7:
					ink = CHART_BUILDING
				var coast: bool = false
				for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var n := Vector2i(x, z) + o
					if n.x >= 0 and n.y >= 0 and n.x < w and n.y < h and sea[n.y * w + n.x] == 1:
						coast = true
				chart.set_pixel(x, z, CHART_COAST if coast else ink)
		out = [ImageTexture.create_from_image(chart), boat / maxi(boat_n, 1), Vector2(w, h)]
	_charts[biome] = out
	return out


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), CHART_SEA)
	var shown: int = selected if selected >= 0 and selected < biomes.size() else 0
	var chart: Array = island_chart(biomes[shown]) if shown < biomes.size() else []
	if not chart.is_empty():
		_draw_island(chart, shown)
		return
	for x in range(0, int(size.x), 28):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.5, 0.6, 0.45, 0.12))
	for y in range(0, int(size.y), 28):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.5, 0.6, 0.45, 0.12))
	var centers: Array[Vector2] = [Vector2(0.28, 0.3), Vector2(0.68, 0.64), Vector2(0.74, 0.22), Vector2(0.2, 0.79), Vector2(0.55, 0.4)]
	for i in centers.size():
		for contour in range(8, 0, -1):
			var points := PackedVector2Array()
			for step in 65:
				var a: float = step * TAU / 64.0
				var radius: float = minf(size.x, size.y) * (0.045 + contour * 0.012) * (1.0 + 0.2 * sin(3.0 * a + i) + 0.12 * cos(7.0 * a - i))
				points.append(centers[i] * size + Vector2(cos(a), sin(a) * 1.25) * radius)
			if contour == 8:
				draw_colored_polygon(points, Color("242f20"))
			# The chosen route's island gets an amber coastline.
			var coast: Color = UiTheme.ACCENT if i == selected and i < biomes.size() else Color(0.45, 0.52, 0.32, 0.55)
			draw_polyline(points, coast, 2.0 if coast == UiTheme.ACCENT and contour == 8 else 1.0, true)
	var origin := Vector2(0.45, 0.92) * size
	for i in mini(2, biomes.size()):
		var marker: Vector2 = centers[i] * size
		var chosen: bool = selected == i
		var color: Color = UiTheme.ACCENT if chosen else UiTheme.MUTED
		for segment in range(0, 12, 2):
			draw_line(origin.lerp(marker, segment / 12.0), origin.lerp(marker, (segment + 1) / 12.0), color, 3.0 if chosen else 1.0, true)
		draw_arc(marker, 12, 0, TAU, 32, color, 2.0, true)
		draw_circle(marker, 5, color)
		var font: Font = UiTheme.mono_bold_font() if chosen else UiTheme.mono_font()
		var label_text: String = "%s · %s" % [LETTERS[i], String(GameData.BIOMES[biomes[i]]["name"]).to_upper()]
		var label_width: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var label_x: float = clampf(marker.x - label_width * 0.5, 8, maxf(8, size.x - label_width - 8))
		# Above the marker (the route line comes in from below), on a dark tag
		# so the contour lines do not cut through the letters.
		var tag := Rect2(label_x - 4, marker.y - 34, label_width + 8, 19)
		draw_rect(tag, UiTheme.BG)
		draw_rect(tag, color if chosen else Color(color, 0.4), false, 1.0)
		draw_string(font, Vector2(label_x, marker.y - 20), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
	draw_circle(origin, 5, UiTheme.TEXT)
	draw_string(UiTheme.mono_font(), Vector2(10, 20), "N ↑ / HALVARD ARCHIPELAGO", HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 12, UiTheme.MUTED)


## One progress step (island or expedition part), drawn centred on `c`.
static func draw_step(item: CanvasItem, c: Vector2, r: float, state: Step, number: String) -> void:
	var font: Font = UiTheme.mono_bold_font()
	var font_size: int = int(r)
	match state:
		Step.DONE:
			item.draw_circle(c, r, UiTheme.SUCCESS)
			item.draw_texture_rect(UiTheme.tick_icon(), Rect2(c - Vector2.ONE * r * 0.6, Vector2.ONE * r * 1.2), false, UiTheme.BG)
			return
		Step.CURRENT:
			item.draw_arc(c, r - 1.0, 0, TAU, 40, UiTheme.ACCENT, 2.0, true)
		Step.AHEAD:
			# Dashed ring: 12 short arcs.
			for k in 12:
				var a: float = k * TAU / 12.0
				item.draw_arc(c, r - 0.5, a, a + TAU / 24.0, 4, UiTheme.MUTED, 1.0, true)
	var color: Color = UiTheme.ACCENT if state == Step.CURRENT else UiTheme.MUTED
	var w: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = c.y + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
	item.draw_string(font, Vector2(c.x - w * 0.5, baseline), number, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


## A row of progress pips joined by short lines (the screen header).
class Pips extends Control:
	const R: float = 12.0
	const LINK: float = 20.0
	var count: int = 3
	var current: int = 0

	func _init(p_count: int, p_current: int) -> void:
		count = p_count
		current = p_current
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(count * R * 2.0 + maxi(count - 1, 0) * LINK, R * 2.0 + 2.0)

	func _draw() -> void:
		var x0: float = size.x - (count * R * 2.0 + maxi(count - 1, 0) * LINK)  # right-aligned
		for i in count:
			var c := Vector2(x0 + R + i * (R * 2.0 + LINK), size.y * 0.5)
			if i > 0:
				draw_line(c - Vector2(R + LINK, 0), c - Vector2(R, 0), UiTheme.LINE, 2.0)
			var state: Step = Step.DONE if i < current else (Step.CURRENT if i == current else Step.AHEAD)
			RouteMap.draw_step(self, c, R, state, str(i + 1))


## A single progress pip (the camp's trail of parts).
class StepPip extends Control:
	var state: Step = Step.AHEAD
	var number: String = ""

	func _init(p_state: Step, p_number: String) -> void:
		state = p_state
		number = p_number
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(26, 26)

	func _draw() -> void:
		RouteMap.draw_step(self, size * 0.5, 12.0, state, number)


## The real island of route `shown`: the chart fitted in the panel, a grid over the sea, the
## landing at the boat and the route line in from the bottom edge.
func _draw_island(chart: Array, shown: int) -> void:
	for x in range(0, int(size.x), 28):
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.5, 0.6, 0.45, 0.12))
	for y in range(0, int(size.y), 28):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.5, 0.6, 0.45, 0.12))
	var pixels: Vector2 = chart[2]
	var room := Rect2(Vector2(12, 34), size - Vector2(24, 52))
	var scale: float = minf(room.size.x / pixels.x, room.size.y / pixels.y)
	var drawn := Rect2(room.position + (room.size - pixels * scale) * 0.5, pixels * scale)
	draw_texture_rect(chart[0], drawn, false)
	var boat: Vector2 = drawn.position + (chart[1] as Vector2) * scale
	var entry := Vector2(boat.x, size.y - 4)
	for segment in range(0, 12, 2):
		draw_line(entry.lerp(boat, segment / 12.0), entry.lerp(boat, (segment + 1) / 12.0), UiTheme.ACCENT, 3.0, true)
	draw_arc(boat, 10, 0, TAU, 32, UiTheme.ACCENT, 2.0, true)
	draw_circle(boat, 4, UiTheme.ACCENT)
	var font: Font = UiTheme.mono_bold_font()
	var title: String = "N ↑ / %s · %s" % [LETTERS[shown] if shown < LETTERS.size() else "", String(GameData.BIOMES[biomes[shown]]["name"]).to_upper()]
	draw_string(font, Vector2(10, 20), title, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, 13, UiTheme.ACCENT)
	draw_string(UiTheme.mono_font(), Vector2(10, size.y - 8), "LANDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, UiTheme.MUTED)
