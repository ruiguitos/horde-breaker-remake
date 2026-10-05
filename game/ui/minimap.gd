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
			var c := Color(0.12, 0.25, 0.4, 0.85)
			var cell := Vector2i(x, z)
			if walls.has(cell):
				c = Color(0.55, 0.55, 0.58, 0.95)
			elif not f.is_blocked(x, z) or props.has(cell):
				c = Color(0.35, 0.45, 0.28, 0.9)
			img.set_pixel(x, z, c)
	_texture = ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if run == null:
		return
	var scale: float = SIZE_PX / run.field.width
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), false)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE_PX, SIZE_PX)), Color(0, 0, 0, 0.8), false, 2.0)
	# Enemies within 40 m (red dots); the boss is a big dark-red dot.
	for i in run.horde.query_radius(run.player_pos, 40.0):
		var p: Vector3 = run.horde.positions[i]
		var boss: bool = run.horde.kinds[i] == GameData.EnemyKind.BOSS
		draw_circle(Vector2(p.x, p.z) * scale, 4.0 if boss else 1.2, Color(0.6, 0.0, 0.1) if boss else Color(1, 0.25, 0.2))
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
	draw_rect(Rect2(Vector2(bp.x, bp.z) * scale - Vector2(3, 3), Vector2(6, 6)), Color(0.6, 0.4, 0.2))
	# Player: a white triangle pointing where they face.
	var pp := Vector2(run.player_pos.x, run.player_pos.z) * scale
	var fwd := Vector2(run.facing.x, run.facing.z).normalized() * 6.0
	var side := Vector2(-fwd.y, fwd.x) * 0.6
	draw_colored_polygon(PackedVector2Array([pp + fwd, pp - fwd * 0.6 + side, pp - fwd * 0.6 - side]), Color.WHITE)
