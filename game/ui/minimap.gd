class_name Minimap
extends Control
## Small top-down map drawn with _draw(): island shape (cached texture),
## objectives, enemies near the player and the player's facing. Islands wider
## than VIEW_M scroll with the player; goals outside the window are pinned to
## its edge, so they still show the way. On an expedition part the land
## outside the play area is drawn darker (blocked, but not sea) and the Exit
## shows as a green chevron. Every marker is drawn by draw_marker(), and the
## Legend below the map draws the same shapes and colours for the kinds
## this run can show, so the key always matches the map.

const SIZE_PX: float = 170.0
## Metres shown across the minimap on big islands (smaller ones show whole).
const VIEW_M: float = 320.0
## The baked picture has at most this many pixels across (big islands are
## sampled every few cells: baking 1.5 km cell by cell takes seconds).
const BAKE_MAX: int = 768

## Marker colours (unchanged from the first minimap).
const SITE_COLOR := Color(0.3, 0.8, 1.0)
const SURVIVOR_COLOR := Color(1.0, 0.55, 0.1)
const GENERATOR_COLOR := Color(1, 0.85, 0.2)
const GENERATOR_ON_COLOR := Color(0.3, 1, 0.4)
const CACHE_COLOR := Color(0.4, 0.95, 1.0)

var run: IslandRun
var _texture: ImageTexture
var _step: int = 1  ## cells per baked pixel
var _view: float = 0.0  ## metres across the minimap
var _origin := Vector2.ZERO  ## world x, z at the minimap's top-left corner
## Marker kinds drawn in the last frame (tests compare them with the legend).
var drawn_kinds: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_run(r: IslandRun) -> void:
	run = r
	_origin = Vector2.ZERO  # a minimap reused after a big island must not keep its window
	# Bake the terrain once: sea, walkable ground, walls/buildings.
	var f: FlowField = r.field
	_step = maxi(1, ceili(maxf(f.width, f.height) / float(BAKE_MAX)))
	_view = VIEW_M if maxf(f.width, f.height) > VIEW_M * 1.5 else float(f.width)
	var w: int = ceili(f.width / float(_step))
	var h: int = ceili(f.height / float(_step))
	var walls := PackedByteArray()
	walls.resize(f.width * f.height)
	if not r.map.handmade:
		for b in r.map.buildings:
			for z in range(b.position.y, b.end.y):
				for x in range(b.position.x, b.end.x):
					walls[z * f.width + x] = 1
	for i in r.map.wall_cells:  # hand-made islands: the real shapes, alleys open
		walls[i] = 1
	for c in r.map.trees + r.map.rocks:
		walls[c.y * f.width + c.x] = 2
	# The sea is a light see-through tint: the HUD has no dark panels, so
	# the island shape floats over the game instead of a dark square.
	var sea := Color("111e1e", 0.3)
	var ground := Color("354839")
	var wall := Color("777e68")
	var outside := Color("232b24")  ## land beyond an expedition part's play area
	var part: bool = not r.play_area.is_empty() and not r.map.heights.is_empty()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for pz in h:
		var z: int = mini(pz * _step, f.height - 1)
		var spans: PackedFloat32Array = _row_spans(r.play_area, z + 0.5) if part else PackedFloat32Array()
		for px in w:
			var x: int = mini(px * _step, f.width - 1)
			var i: int = z * f.width + x
			var c: Color = sea
			if part and not _inside(spans, x + 0.5):
				# Outside the part: land (above the sea) is darkened, sea stays sea.
				if r.map.heights[i] > 0.0:
					c = outside.lerp(wall, 0.25) if walls[i] == 1 else outside
			elif walls[i] == 1:
				c = wall
			elif f.blocked[i] == 0 or walls[i] == 2:
				c = ground
			img.set_pixel(px, pz, c)
	_texture = ImageTexture.create_from_image(img)


## Sorted x where row `y` crosses the polygon's edges (even-odd rule, as
## HandmadeIsland._block_outside).
static func _row_spans(poly: PackedVector2Array, y: float) -> PackedFloat32Array:
	var xs := PackedFloat32Array()
	var n: int = poly.size()
	for k in n:
		var a: Vector2 = poly[k]
		var b: Vector2 = poly[(k + 1) % n]
		if (a.y <= y) != (b.y <= y):
			xs.append(a.x + (y - a.y) / (b.y - a.y) * (b.x - a.x))
	xs.sort()
	return xs


static func _inside(xs: PackedFloat32Array, x: float) -> bool:
	var crossed: int = 0
	for v in xs:
		if v <= x:
			crossed += 1
	return crossed % 2 == 1


func _process(_delta: float) -> void:
	queue_redraw()


## Minimap pixel of a world point, pinned inside the frame.
func _px(p: Vector3) -> Vector2:
	var q := (Vector2(p.x, p.z) - _origin) * (SIZE_PX / _view)
	return q.clamp(Vector2(3, 3), Vector2(SIZE_PX - 3, SIZE_PX - 3))


func _draw() -> void:
	if run == null:
		return
	var f: FlowField = run.field
	if _view < f.width:
		var room := Vector2(f.width, f.height) - Vector2(_view, _view)
		_origin = (Vector2(run.player_pos.x, run.player_pos.z) - Vector2(_view, _view) * 0.5).clamp(Vector2.ZERO, room)
	draw_texture_rect_region(_texture, Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), Rect2(_origin / _step, Vector2(_view, _view) / _step))
	for axis in range(1, 5):
		var grid: float = SIZE_PX * axis / 5.0
		draw_line(Vector2(grid, 0), Vector2(grid, SIZE_PX), Color(0.65, 0.72, 0.6, 0.12))
		draw_line(Vector2(0, grid), Vector2(SIZE_PX, grid), Color(0.65, 0.72, 0.6, 0.12))
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), UiTheme.PANEL_BORDER, false, 1.0)
	drawn_kinds.clear()
	# Enemies within 40 m. The boss also has a ring, distinct from other dots.
	for i in run.horde.query_radius(run.player_pos, 40.0):
		var boss: bool = run.horde.kinds[i] == GameData.EnemyKind.BOSS
		_mark(&"boss" if boss else &"hostile", _px(run.horde.positions[i]))
	if run.mission == &"defend" or run.mission == &"holdout":
		_mark(&"site", _px(run.site))
	elif run.mission == &"rescue" and not run.survivor_lost:
		_mark(&"survivor", _px(run.survivor_pos))
	for g in GameData.GENERATOR_COUNT:
		if run.mission != &"activate":
			break
		var done: bool = run.generator_progress[g] >= GameData.GENERATOR_HOLD_SECONDS
		_mark(&"generator_on" if done else &"generator", _px(run.map.generators[g]))
	for c in run.map.caches.size():
		if run.cache_progress[c] < GameData.CACHE_OPEN_TIME:
			_mark(&"cache", _px(run.map.caches[c]))
	if run.has_exit():
		_mark(&"exit", _px(run.map.exit))
	if run.shows_boat() or run.mission == &"holdout":
		# The holdout's pier shows before the boat comes: it is where to go.
		_mark(&"boat", _px(run.map.boat))
	_mark(&"player", _px(run.player_pos), Vector2(run.facing.x, run.facing.z))


func _mark(kind: StringName, at: Vector2, facing: Vector2 = Vector2(0, -1)) -> void:
	drawn_kinds[kind] = true
	draw_marker(self, kind, at, 1.0, facing)


## Draws one map marker: shape and colour say what it is.
static func draw_marker(item: CanvasItem, kind: StringName, p: Vector2, s: float = 1.0, facing: Vector2 = Vector2(0, -1)) -> void:
	match kind:
		&"hostile":
			item.draw_circle(p, 1.5 * s, UiTheme.DANGER)
		&"boss":
			item.draw_circle(p, 4.0 * s, UiTheme.DANGER)
			item.draw_arc(p, 6.0 * s, 0, TAU, 20, UiTheme.DANGER, 1.0, true)
		&"site":
			item.draw_circle(p, 5.0 * s, SITE_COLOR)
		&"survivor":
			item.draw_circle(p, 4.0 * s, SURVIVOR_COLOR)
		&"generator":
			item.draw_circle(p, 4.0 * s, GENERATOR_COLOR)
		&"generator_on":
			item.draw_circle(p, 4.0 * s, GENERATOR_ON_COLOR)
		&"cache":
			item.draw_rect(Rect2(p - Vector2(2.5, 2.5) * s, Vector2(5, 5) * s), CACHE_COLOR)
		&"exit":
			# The Exit: a green chevron pointing up (the way on).
			item.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5) * s, p + Vector2(5, 3) * s, p + Vector2(0, 0.5) * s, p + Vector2(-5, 3) * s]), UiTheme.SUCCESS)
		&"boat":
			item.draw_colored_polygon(PackedVector2Array([p + Vector2(0, -4) * s, p + Vector2(4, 0) * s, p + Vector2(0, 4) * s, p + Vector2(-4, 0) * s]), UiTheme.ACCENT)
		&"player":
			# Player: a white triangle pointing where they face.
			var fwd := facing.normalized() * 6.0 * s
			var side := Vector2(-fwd.y, fwd.x) * 0.6
			item.draw_colored_polygon(PackedVector2Array([p + fwd, p - fwd * 0.6 + side, p - fwd * 0.6 - side]), Color.WHITE)


## Marker kinds this run can show, in legend order, with their names.
static func legend_entries(r: IslandRun) -> Array[Array]:
	var out: Array[Array] = [[&"player", "YOU"], [&"hostile", "HOSTILE"]]
	if r == null:
		return out
	if r.has_boss:
		out.append([&"boss", "BEHEMOTH"])
	match r.mission:
		&"defend":
			out.append([&"site", "UPLINK"])
		&"holdout":
			out.append([&"site", "COURTYARD"])
		&"rescue":
			out.append([&"survivor", "SURVIVOR"])
		&"activate":
			out.append([&"generator", "GENERATOR"])
			out.append([&"generator_on", "ONLINE"])
	if not r.map.caches.is_empty():
		out.append([&"cache", "CACHE"])
	if r.has_exit():
		out.append([&"exit", "EXIT"])
	if r.shows_boat() or r.mission == &"holdout":
		out.append([&"boat", "PIER" if r.mission == &"holdout" and not r.shows_boat() else "BOAT"])
	return out


## The map's key: the same shapes and colours as the markers, two columns,
## text with a dark outline (no panel behind it).
class Legend extends Control:
	const ROW: float = 16.0
	const FONT_SIZE: int = 12
	var run: IslandRun
	var _entries: Array[Array] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(SIZE_PX, ROW)

	func entries() -> Array[Array]:
		return _entries

	func _process(_delta: float) -> void:
		var now: Array[Array] = Minimap.legend_entries(run)
		if now != _entries:
			_entries = now
			custom_minimum_size.y = ceilf(_entries.size() / 2.0) * ROW
		queue_redraw()

	func _draw() -> void:
		var font: Font = UiTheme.mono_font()
		var col_w: float = size.x * 0.5
		for i in _entries.size():
			var at := Vector2((i % 2) * col_w, floorf(i / 2.0) * ROW)
			var icon := at + Vector2(7, ROW * 0.5)
			Minimap.draw_marker(self, _entries[i][0], icon, 1.3 if _entries[i][0] != &"hostile" else 2.2)
			var base := at + Vector2(17, ROW * 0.5 + FONT_SIZE * 0.36)
			draw_string_outline(font, base, _entries[i][1], HORIZONTAL_ALIGNMENT_LEFT, col_w - 18, FONT_SIZE, 4, Color(0, 0, 0, 0.85))
			draw_string(font, base, _entries[i][1], HORIZONTAL_ALIGNMENT_LEFT, col_w - 18, FONT_SIZE, UiTheme.TEXT_MUTED.lightened(0.15))
