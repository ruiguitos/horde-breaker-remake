class_name Minimap
extends Control
## Small top-down map drawn with _draw(): island shape (cached texture),
## objectives, enemies near the player and the player's facing.

const SIZE_PX: float = 170.0

var run: IslandRun
var _texture: ImageTexture


func _init() -> void:
	custom_minimum_size = Vector2(SIZE_PX, SIZE_PX)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_run(r: IslandRun) -> void:
	run = r
	# Bake the terrain once: sea, walkable ground, walls/buildings.
	var f: FlowField = r.field
	var img := Image.create(f.width, f.height, false, Image.FORMAT_RGBA8)
	var props := {}
	for c in r.map.trees + r.map.rocks:
		props[c] = true
	var walls := {}
	for b in r.map.buildings:
		for z in range(b.position.y, b.end.y):
			for x in range(b.position.x, b.end.x):
				walls[Vector2i(x, z)] = true
	for z in f.height:
		for x in f.width:
			var c := Color("111e1e")
			var cell := Vector2i(x, z)
			if walls.has(cell):
				c = Color("777e68")
			elif not f.is_blocked(x, z) or props.has(cell):
				c = Color("354839")
			img.set_pixel(x, z, c)
	_texture = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var scale: float = SIZE_PX / run.field.width
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), false)
	for axis in range(1, 5):
		var grid: float = SIZE_PX * axis / 5.0
		draw_line(Vector2(grid, 0), Vector2(grid, SIZE_PX), Color(0.65, 0.72, 0.6, 0.12))
		draw_line(Vector2(0, grid), Vector2(SIZE_PX, grid), Color(0.65, 0.72, 0.6, 0.12))
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), UiTheme.PANEL_BORDER, false, 1.0)
	# Enemies within 40 m. The boss also has a ring, distinct from other dots.
	for i in run.horde.query_radius(run.player_pos, 40.0):
		var p: Vector3 = run.horde.positions[i]
		var boss: bool = run.horde.kinds[i] == GameData.EnemyKind.BOSS
		var ep := Vector2(p.x, p.z) * scale
		draw_circle(ep, 4.0 if boss else 1.5, UiTheme.DANGER)
		if boss:
			draw_arc(ep, 6.0, 0, TAU, 20, UiTheme.DANGER, 1.0, true)
	if run.mission == &"defend":
		draw_circle(Vector2(run.site.x, run.site.z) * scale, 5.0, Color(0.3, 0.8, 1.0))
	elif run.mission == &"rescue" and not run.survivor_lost:
		draw_circle(Vector2(run.survivor_pos.x, run.survivor_pos.z) * scale, 4.0, Color(1.0, 0.55, 0.1))
	for g in GameData.GENERATOR_COUNT:
		if run.mission != &"activate":
			break
		var done: bool = run.generator_progress[g] >= GameData.GENERATOR_HOLD_SECONDS
		var gp: Vector3 = run.map.generators[g]
		draw_circle(Vector2(gp.x, gp.z) * scale, 4.0, Color(0.3, 1, 0.4) if done else Color(1, 0.85, 0.2))
	for c in run.map.caches.size():
		if run.cache_progress[c] < GameData.CACHE_OPEN_TIME:
			var cp: Vector3 = run.map.caches[c]
			draw_rect(Rect2(Vector2(cp.x, cp.z) * scale - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.4, 0.95, 1.0))
	var bp: Vector3 = run.map.boat
	var boat_point := Vector2(bp.x, bp.z) * scale
	draw_colored_polygon(PackedVector2Array([boat_point + Vector2(0, -4), boat_point + Vector2(4, 0), boat_point + Vector2(0, 4), boat_point + Vector2(-4, 0)]), UiTheme.ACCENT)
	# Player: a white triangle pointing where they face.
	var pp := Vector2(run.player_pos.x, run.player_pos.z) * scale
	var fwd := Vector2(run.facing.x, run.facing.z).normalized() * 6.0
	var side := Vector2(-fwd.y, fwd.x) * 0.6
	draw_colored_polygon(PackedVector2Array([pp + fwd, pp - fwd * 0.6 + side, pp - fwd * 0.6 - side]), Color.WHITE)
