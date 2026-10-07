class_name Minimap
extends Control
## Small top-down map drawn with _draw(): island shape (cached texture),
## objectives, enemies near the player and the player's facing. Islands wider
## than VIEW_M scroll with the player; goals outside the window are pinned to
## its edge, so they still show the way.

const SIZE_PX: float = 170.0
## Metres shown across the minimap on big islands (smaller ones show whole).
const VIEW_M: float = 320.0
## The baked picture has at most this many pixels across (big islands are
## sampled every few cells: baking 1.5 km cell by cell takes seconds).
const BAKE_MAX: int = 768

var run: IslandRun
var _texture: ImageTexture
var _step: int = 1  ## cells per baked pixel
var _view: float = 0.0  ## metres across the minimap
var _origin := Vector2.ZERO  ## world x, z at the minimap's top-left corner


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
	var sea := Color("111e1e")
	var ground := Color("354839")
	var wall := Color("777e68")
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for pz in h:
		for px in w:
			var i: int = mini(pz * _step, f.height - 1) * f.width + mini(px * _step, f.width - 1)
			var c: Color = sea
			if walls[i] == 1:
				c = wall
			elif f.blocked[i] == 0 or walls[i] == 2:
				c = ground
			img.set_pixel(px, pz, c)
	_texture = ImageTexture.create_from_image(img)


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
	# Enemies within 40 m. The boss also has a ring, distinct from other dots.
	for i in run.horde.query_radius(run.player_pos, 40.0):
		var boss: bool = run.horde.kinds[i] == GameData.EnemyKind.BOSS
		var ep: Vector2 = _px(run.horde.positions[i])
		draw_circle(ep, 4.0 if boss else 1.5, UiTheme.DANGER)
		if boss:
			draw_arc(ep, 6.0, 0, TAU, 20, UiTheme.DANGER, 1.0, true)
	if run.mission == &"defend":
		draw_circle(_px(run.site), 5.0, Color(0.3, 0.8, 1.0))
	elif run.mission == &"rescue" and not run.survivor_lost:
		draw_circle(_px(run.survivor_pos), 4.0, Color(1.0, 0.55, 0.1))
	for g in GameData.GENERATOR_COUNT:
		if run.mission != &"activate":
			break
		var done: bool = run.generator_progress[g] >= GameData.GENERATOR_HOLD_SECONDS
		draw_circle(_px(run.map.generators[g]), 4.0, Color(0.3, 1, 0.4) if done else Color(1, 0.85, 0.2))
	for c in run.map.caches.size():
		if run.cache_progress[c] < GameData.CACHE_OPEN_TIME:
			draw_rect(Rect2(_px(run.map.caches[c]) - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.4, 0.95, 1.0))
	var boat_point: Vector2 = _px(run.map.boat)
	draw_colored_polygon(PackedVector2Array([boat_point + Vector2(0, -4), boat_point + Vector2(4, 0), boat_point + Vector2(0, 4), boat_point + Vector2(-4, 0)]), UiTheme.ACCENT)
	# Player: a white triangle pointing where they face.
	var pp: Vector2 = _px(run.player_pos)
	var fwd := Vector2(run.facing.x, run.facing.z).normalized() * 6.0
	var side := Vector2(-fwd.y, fwd.x) * 0.6
	draw_colored_polygon(PackedVector2Array([pp + fwd, pp - fwd * 0.6 + side, pp - fwd * 0.6 - side]), Color.WHITE)
