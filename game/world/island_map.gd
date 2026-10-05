class_name IslandMap
extends RefCounted
## Builds the grey-box "Dawn Beach" island as a wall grid: the sea is blocked
## cells around an irregular coastline, buildings are blocked rectangles.

const SIZE: int = 160

var field: FlowField
var boat: Vector3
var player_start: Vector3
var generators: Array[Vector3] = []
## Wall rectangles (x0, z0, w, h) in cells, for rendering buildings.
var buildings: Array[Rect2i] = []
## Single-cell blocking props (cells), rendered as trees and rocks.
var trees: Array[Vector2i] = []
var rocks: Array[Vector2i] = []
## Optional supply caches (detours with a reward).
var caches: Array[Vector3] = []


static func build(rng_seed: int = 7) -> IslandMap:
	var map := IslandMap.new()
	var f := FlowField.new(SIZE, SIZE, 1.0)
	map.field = f
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var c: float = SIZE * 0.5
	# Coastline: radius varies smoothly with the angle.
	var phase_a: float = rng.randf() * TAU
	var phase_b: float = rng.randf() * TAU
	for z in SIZE:
		for x in SIZE:
			var dx: float = x + 0.5 - c
			var dz: float = z + 0.5 - c
			var ang: float = atan2(dz, dx)
			var radius: float = 70.0 + 5.0 * sin(ang * 3.0 + phase_a) + 3.0 * sin(ang * 7.0 + phase_b)
			if dx * dx + dz * dz > radius * radius or x == 0 or z == 0 or x == SIZE - 1 or z == SIZE - 1:
				f.blocked[z * SIZE + x] = 1
	map.boat = Vector3(c, 0.0, c + 58.0)
	map.player_start = map.boat + Vector3(0, 0, -5)
	map.generators = [Vector3(c - 38, 0, c - 20), Vector3(c + 40, 0, c - 28), Vector3(c + 2, 0, c - 52)]
	# Areas kept free of buildings.
	var keep_free: Array[Vector3] = [map.boat, map.player_start, Vector3(c, 0, c)]
	keep_free.append_array(map.generators)
	var placed: int = 0
	var attempts: int = 0
	while placed < 45 and attempts < 2000:
		attempts += 1
		var w: int = rng.randi_range(3, 12)
		var h: int = rng.randi_range(3, 12)
		if rng.randf() < 0.3:
			# Long thin walls make better choke points.
			if rng.randf() < 0.5:
				w = rng.randi_range(10, 20)
				h = 1
			else:
				w = 1
				h = rng.randi_range(10, 20)
		var x0: int = rng.randi_range(15, SIZE - 15 - w)
		var z0: int = rng.randi_range(15, SIZE - 15 - h)
		var rect := Rect2i(x0, z0, w, h)
		var ok: bool = true
		for p in keep_free:
			var grown := rect.grow(8)
			if grown.has_point(Vector2i(int(p.x), int(p.z))):
				ok = false
				break
		for other in map.buildings:
			if rect.grow(3).intersects(other):
				ok = false
				break
		if not ok:
			continue
		f.set_blocked_rect(x0, z0, x0 + w - 1, z0 + h - 1)
		map.buildings.append(rect)
		placed += 1
	# Caches: free spots away from the boat and generators.
	attempts = 0
	while map.caches.size() < 4 and attempts < 2000:
		attempts += 1
		var cp := Vector3(rng.randi_range(15, SIZE - 15) + 0.5, 0, rng.randi_range(15, SIZE - 15) + 0.5)
		var ok_cache: bool = not _blocked_near(f, Vector2i(int(cp.x), int(cp.z)), 2)
		for p in keep_free + map.caches:
			if Vector2(cp.x - p.x, cp.z - p.z).length() < 25.0:
				ok_cache = false
				break
		if ok_cache:
			map.caches.append(cp)
	keep_free.append_array(map.caches)
	# Trees and rocks: single blocked cells whose 3x3 neighbourhood is free,
	# so they add cover without ever sealing a corridor.
	var props: int = 0
	attempts = 0
	while props < 160 and attempts < 4000:
		attempts += 1
		var cell := Vector2i(rng.randi_range(2, SIZE - 3), rng.randi_range(2, SIZE - 3))
		var near_goal: bool = false
		for p in keep_free:
			if Vector2(cell.x - p.x, cell.y - p.z).length() < 7.0:
				near_goal = true
				break
		if near_goal or not _free_around(f, cell):
			continue
		f.blocked[cell.y * SIZE + cell.x] = 1
		if rng.randf() < 0.7:
			map.trees.append(cell)
		else:
			map.rocks.append(cell)
		props += 1
	return map


static func _blocked_near(f: FlowField, c: Vector2i, r: int) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if f.is_blocked(c.x + dx, c.y + dz):
				return true
	return false


static func _free_around(f: FlowField, c: Vector2i) -> bool:
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if f.is_blocked(c.x + dx, c.y + dz):
				return false
	return true
