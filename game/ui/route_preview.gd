class_name RoutePreview
extends Control
## Small native illustration for each biome; no external terrain dependency.
## Expedition parts (a real island, e.g. the Berlenga) get their own picture:
## bare granite cliffs, low scrub and the part's landmark, never palms.

const GRANITE := Color("8b8079")
const GRANITE_DARK := Color("5d5551")
const GRANITE_SHADOW := Color("463f3d")
const SCRUB_GREEN := Color("6f7d45")
const SCRUB_OCHRE := Color("a68b4a")
const SEA := Color("2f5f73")
const SEA_DEEP := Color("244b5c")
const SURF := Color("e3ece9")
const WHITEWASH := Color("eae5d9")
const ROOF := Color("a5523a")
const FORT_STONE := Color("b49a72")

var biome: StringName = &"beach"
## Set for an expedition part: expedition id and 0-based part index.
var expedition: StringName = &""
var part: int = 0


func _ready() -> void:
	if custom_minimum_size.y == 0:
		custom_minimum_size.y = 92
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if expedition != &"":
		_draw_granite_island()
		return
	var info: Dictionary = GameData.BIOMES[biome]
	var sky: Color = info["sky"]
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y * 0.6)]), PackedColorArray([sky.darkened(0.2), sky.darkened(0.2), sky.lightened(0.12), sky.lightened(0.12)]))
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
			draw_rect(Rect2(pos + Vector2(4, 22), Vector2(22, 5)), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(pos, Vector2(20, 24)), info["building"])
			draw_rect(Rect2(pos, Vector2(20, 3)), info["building"].lightened(0.2))
			draw_colored_polygon(PackedVector2Array([pos + Vector2(-3, 0), pos + Vector2(10, -10), pos + Vector2(23, 0)]), Color("504137"))
	elif biome == &"port":
		for i in 6:
			var box_pos: Vector2 = size * Vector2(0.08 + i * 0.14, 0.67)
			draw_rect(Rect2(box_pos + Vector2(4, 14), Vector2(25, 4)), Color(0, 0, 0, 0.25))
			draw_rect(Rect2(box_pos, Vector2(25, 16)), info["building"] if i % 2 == 0 else Color("536975"))
			draw_rect(Rect2(box_pos, Vector2(25, 3)), (info["building"] if i % 2 == 0 else Color("536975")).lightened(0.2))
		draw_polyline(PackedVector2Array([size * Vector2(0.3, 0.7), size * Vector2(0.35, 0.16), size * Vector2(0.66, 0.32), size * Vector2(0.62, 0.7)]), Color("44494a"), 3)
	else:
		for i in 6:
			var foot := size * Vector2(0.08 + i * 0.16, 0.84)
			var crown := foot - Vector2(5, 25 + (i % 3) * 7)
			draw_ground_shadow(foot)
			draw_line(foot, crown, Color("51442e"), 3)
			draw_colored_polygon(PackedVector2Array([crown + Vector2(-15, 7), crown + Vector2(-4, -6), crown + Vector2(15, 5), crown, crown + Vector2(-1, 12)]), info["foliage"])
	draw_rect(Rect2(Vector2(0, size.y * 0.84), Vector2(size.x, size.y * 0.16)), Color("334e55"))


## Polygon in 0..1 coordinates, scaled to the control.
## A soft ground shadow under an object standing at oot.
func draw_ground_shadow(foot: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([foot + Vector2(-9, 1), foot + Vector2(0, -2), foot + Vector2(12, 1), foot + Vector2(3, 4)]), Color(0, 0, 0, 0.22))


func _poly(points: Array, color: Color) -> void:
	var out := PackedVector2Array()
	for pt: Vector2 in points:
		out.append(pt * size)
	draw_colored_polygon(out, color)


## Low bush: a flat half-ellipse sitting on the ground.
func _scrub(center: Vector2, w: float, h: float, color: Color) -> void:
	var c: Vector2 = center * size
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = PI + PI * i / 9.0
		pts.append(c + Vector2(cos(a) * w, sin(a) * h))
	draw_colored_polygon(pts, color)


## A bare granite island in the Atlantic: cliffs, low green/ochre scrub,
## surf, and one landmark per part (village, lighthouse, coast, fort).
func _draw_granite_island() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("a9c6d3"))
	draw_rect(Rect2(Vector2(0, size.y * 0.42), Vector2(size.x, size.y * 0.1)), Color("bcd2da"))
	draw_circle(size * Vector2(0.86, 0.2), minf(size.y * 0.07, 10.0), Color("f1dfa8"))
	draw_rect(Rect2(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5)), SEA)
	draw_rect(Rect2(Vector2(0, size.y * 0.86), Vector2(size.x, size.y * 0.14)), SEA_DEEP)
	# Main island: a flat plateau on steep cliffs.
	var top: Array = [Vector2(0.0, 0.42), Vector2(0.12, 0.36), Vector2(0.3, 0.33), Vector2(0.48, 0.3),
		Vector2(0.62, 0.34), Vector2(0.72, 0.4)]
	if part == 3:
		top = [Vector2(0.0, 0.4), Vector2(0.14, 0.35), Vector2(0.3, 0.33), Vector2(0.46, 0.36), Vector2(0.55, 0.42)]
	var last: Vector2 = top[-1]
	var body: Array = top.duplicate()
	body.append_array([Vector2(last.x + 0.05, 0.62), Vector2(last.x + 0.08, 0.76), Vector2(0.0, 0.76)])
	_poly(body, GRANITE)
	# Cliff faces: darker rock under the plateau edge, cracks in the granite.
	_poly([Vector2(last.x - 0.1, 0.46), last, Vector2(last.x + 0.05, 0.62), Vector2(last.x + 0.08, 0.76),
		Vector2(last.x - 0.06, 0.76), Vector2(last.x - 0.09, 0.6)], GRANITE_DARK)
	_poly([Vector2(0.2, 0.64), Vector2(0.26, 0.6), Vector2(0.3, 0.76), Vector2(0.17, 0.76)], GRANITE_SHADOW)
	for i in 4:
		var x: float = 0.05 + i * 0.12
		draw_line(size * Vector2(x, 0.5), size * Vector2(x + 0.03, 0.72), GRANITE_SHADOW, 2)
	# Low scrub on the plateau (no trees: the island is bare rock).
	for i in 7:
		var x: float = 0.04 + i * (last.x - 0.1) / 6.0
		var y: float = _top_y(top, x) + 0.025
		_scrub(Vector2(x, y), size.x * (0.035 + (i % 3) * 0.01), size.y * 0.035, SCRUB_GREEN if i % 2 == 0 else SCRUB_OCHRE)
	_draw_surf(Vector2(0.0, 0.76), Vector2(last.x + 0.08, 0.76))
	match part:
		0:
			_draw_village(top)
		1:
			_draw_lighthouse(top)
		2:
			_draw_coast()
		3:
			_draw_fort()


## Plateau height at x, along the top outline.
func _top_y(top: Array, x: float) -> float:
	for i in top.size() - 1:
		var a: Vector2 = top[i]
		var b: Vector2 = top[i + 1]
		if x >= a.x and x <= b.x:
			return lerpf(a.y, b.y, (x - a.x) / maxf(0.001, b.x - a.x))
	return (top[-1] as Vector2).y


func _draw_surf(from: Vector2, to: Vector2) -> void:
	draw_line(size * from, size * to, SURF, 2)
	for i in 5:
		var x: float = from.x + (to.x - from.x) * (i + 0.5) / 5.0
		draw_line(size * Vector2(x - 0.03, 0.8), size * Vector2(x + 0.02, 0.8), Color(SURF, 0.6), 1.5)


## Part 1: whitewashed houses above the cove and the path climbing up.
func _draw_village(top: Array) -> void:
	var path := PackedVector2Array()
	for pt: Vector2 in [Vector2(0.44, 0.74), Vector2(0.38, 0.62), Vector2(0.45, 0.52), Vector2(0.4, _top_y(top, 0.4) + 0.02)]:
		path.append(pt * size)
	draw_polyline(path, Color("d3c29a"), 2)
	for i in 4:
		var base := size * Vector2(0.5 + i * 0.055, 0.72 - (i % 2) * 0.04)
		var w: float = size.x * 0.04
		var h: float = size.y * 0.07
		draw_rect(Rect2(base - Vector2(0, h), Vector2(w, h)), WHITEWASH)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-2, -h), base + Vector2(w * 0.5, -h * 1.45), base + Vector2(w + 2, -h)]), ROOF)
	var boat := size * Vector2(0.84, 0.82)
	draw_colored_polygon(PackedVector2Array([boat + Vector2(-12, 0), boat + Vector2(12, 0), boat + Vector2(8, 5), boat + Vector2(-8, 5)]), Color("c9563c"))


## Part 2: the lighthouse on the plateau, with the keeper's house.
func _draw_lighthouse(top: Array) -> void:
	var x: float = 0.4
	var base := size * Vector2(x, _top_y(top, x) + 0.01)
	# Short pictures (the camp strip) still show the lantern and roof.
	var h: float = minf(size.y * 0.24, base.y - 20.0)
	var w: float = clampf(size.x * 0.022, 6.0, 16.0)
	var house := base + Vector2(w * 1.4, 0)
	draw_rect(Rect2(house - Vector2(0, size.y * 0.06), Vector2(size.x * 0.09, size.y * 0.06)), WHITEWASH)
	draw_rect(Rect2(house - Vector2(0, size.y * 0.075), Vector2(size.x * 0.09, size.y * 0.016)), ROOF)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w, 0), base + Vector2(w, 0), base + Vector2(w * 0.7, -h), base + Vector2(-w * 0.7, -h)]), WHITEWASH)
	draw_rect(Rect2(base + Vector2(-w * 0.9, -h - 8), Vector2(w * 1.8, 8)), Color("f4d27a"))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 1.1, -h - 8), base + Vector2(0, -h - 16), base + Vector2(w * 1.1, -h - 8)]), Color("6d2f27"))
	var beam := base + Vector2(0, -h - 4)
	draw_colored_polygon(PackedVector2Array([beam, beam + Vector2(size.x * 0.22, -10), beam + Vector2(size.x * 0.22, 4)]), Color(1, 0.95, 0.7, 0.35))


## Part 3: the open southwest coast, sea stacks and heavy surf.
func _draw_coast() -> void:
	for st: Vector3 in [Vector3(0.87, 0.2, 0.04), Vector3(0.95, 0.13, 0.025), Vector3(0.8, 0.08, 0.02)]:
		_poly([Vector2(st.x - st.z, 0.78), Vector2(st.x - st.z * 0.6, 0.78 - st.y), Vector2(st.x + st.z * 0.5, 0.78 - st.y * 1.05), Vector2(st.x + st.z, 0.78)], GRANITE_DARK)
		draw_line(size * Vector2(st.x - st.z - 0.02, 0.78), size * Vector2(st.x + st.z + 0.02, 0.78), SURF, 2)
	for i in 3:
		var y: float = 0.66 + i * 0.05
		draw_line(size * Vector2(0.78 + i * 0.03, y), size * Vector2(0.84, y), Color(SURF, 0.45), 1.5)


## Part 4: the fort on its islet, joined to the island by a narrow bridge.
func _draw_fort() -> void:
	_poly([Vector2(0.72, 0.78), Vector2(0.74, 0.58), Vector2(0.8, 0.53), Vector2(0.92, 0.55), Vector2(0.96, 0.62), Vector2(0.98, 0.78)], GRANITE_DARK)
	draw_line(size * Vector2(0.6, 0.6), size * Vector2(0.75, 0.6), Color("8c7a62"), 3)
	var left: float = 0.76
	var right: float = 0.95
	var y_top: float = 0.4
	var y_base: float = 0.57
	_poly([Vector2(left, y_base), Vector2(left + 0.01, y_top), Vector2(right - 0.01, y_top), Vector2(right, y_base)], FORT_STONE)
	for i in 6:
		var x: float = left + 0.01 + (right - left - 0.02) * (i + 0.25) / 6.0
		_poly([Vector2(x, y_top), Vector2(x, y_top - 0.04), Vector2(x + 0.018, y_top - 0.04), Vector2(x + 0.018, y_top)], FORT_STONE)
	_poly([Vector2(0.845, y_base), Vector2(0.845, 0.49), Vector2(0.855, 0.47), Vector2(0.865, 0.47), Vector2(0.875, 0.49), Vector2(0.875, y_base)], Color("3a302a"))
	draw_line(size * Vector2(0.7, 0.8), size * Vector2(1.0, 0.8), SURF, 2)
