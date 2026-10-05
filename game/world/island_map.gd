class_name IslandMap
extends RefCounted
## Builds the grey-box "Dawn Beach" island as a wall grid: the sea is blocked
## cells around an irregular coastline, buildings are blocked rectangles.

## Island grid size in metres (cells). Change this one number for bigger
## maps: coast, objectives and prop counts scale with it (see K).
const SIZE: int = 160
## Scale relative to the original 160 m island.
const K: float = SIZE / 160.0

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
## Biome id: beach, town, jungle, port or volcano (see GameData.BIOMES).
var biome: StringName = &"beach"
## Lava pools (volcano): centre and radius; they hurt anyone standing in them.
var lava: Array[Vector3] = []
var lava_radius: PackedFloat32Array = PackedFloat32Array()


static func build(rng_seed: int = 7, biome: StringName = &"beach") -> IslandMap:
	var map := IslandMap.new()
	map.biome = biome
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
			var radius: float = K * (70.0 + 5.0 * sin(ang * 3.0 + phase_a) + 3.0 * sin(ang * 7.0 + phase_b))
			if dx * dx + dz * dz > radius * radius or x == 0 or z == 0 or x == SIZE - 1 or z == SIZE - 1:
				f.blocked[z * SIZE + x] = 1
	map.boat = Vector3(c, 0.0, c + 58.0 * K)
	map.player_start = map.boat + Vector3(0, 0, -5)
	# Generator sites move a little per island so routes differ.
	map.generators = [Vector3(c - 38 * K, 0, c - 20 * K), Vector3(c + 40 * K, 0, c - 28 * K), Vector3(c + 2 * K, 0, c - 52 * K)]
	for i in map.generators.size():
		map.generators[i] += Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8))
		map.generators[i] = Vector3(floorf(map.generators[i].x) + 0.5, 0, floorf(map.generators[i].z) + 0.5)
	# Areas kept free of buildings.
	var keep_free: Array[Vector3] = [map.boat, map.player_start, Vector3(c, 0, c)]
	keep_free.append_array(map.generators)
	var attempts: int = 0
	match biome:
		&"town":
			_town_blocks(map, rng, keep_free)
		&"port":
			_container_rows(map, rng, keep_free)
		&"jungle":
			_scatter_buildings(map, rng, keep_free, int(12 * K * K), Vector2i(3, 6), 0.4)
		&"beach":
			_scatter_buildings(map, rng, keep_free, int(18 * K * K), Vector2i(3, 5), 0.15)
		_:
			_scatter_buildings(map, rng, keep_free, int(45 * K * K), Vector2i(3, 12), 0.3)
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
	# Props per area: the count grows with the island surface (K squared).
	var prop_target: int = int({&"town": 40, &"port": 30, &"jungle": 520, &"beach": 220}.get(biome, 160) * K * K)
	var spacing: int = 1 if biome == &"jungle" else 2
	var tree_ratio: float = {&"beach": 0.5, &"port": 0.2, &"volcano": 0.5}.get(biome, 0.75)
	while props < prop_target and attempts < int(8000 * K * K):
		attempts += 1
		var cell := Vector2i(rng.randi_range(2, SIZE - 3), rng.randi_range(2, SIZE - 3))
		var near_goal: bool = false
		for p in keep_free:
			if Vector2(cell.x - p.x, cell.y - p.z).length() < 7.0:
				near_goal = true
				break
		if near_goal or not _free_around(f, cell, spacing):
			continue
		f.blocked[cell.y * SIZE + cell.x] = 1
		if rng.randf() < tree_ratio:
			map.trees.append(cell)
		else:
			map.rocks.append(cell)
		props += 1
	if biome == &"volcano":
		_lava_pools(map, rng, keep_free)
	return map


static func _blocked_near(f: FlowField, c: Vector2i, r: int) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if f.is_blocked(c.x + dx, c.y + dz):
				return true
	return false


static func _free_around(f: FlowField, c: Vector2i, r: int = 2) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if f.is_blocked(c.x + dx, c.y + dz):
				return false
	return true


## Random rectangles (houses, ruins, walls) that never touch each other.
static func _scatter_buildings(map: IslandMap, rng: RandomNumberGenerator, keep_free: Array[Vector3],
		count: int, size_range: Vector2i, thin_chance: float) -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < maxi(3000, count * 70):
		attempts += 1
		var w: int = rng.randi_range(size_range.x, size_range.y)
		var h: int = rng.randi_range(size_range.x, size_range.y)
		if rng.randf() < thin_chance:
			# Long thin walls make choke points.
			if rng.randf() < 0.5:
				w = rng.randi_range(10, 20)
				h = 1
			else:
				w = 1
				h = rng.randi_range(10, 20)
		var x0: int = rng.randi_range(15, SIZE - 15 - w)
		var z0: int = rng.randi_range(15, SIZE - 15 - h)
		if _try_place(map, Rect2i(x0, z0, w, h), keep_free, 3):
			placed += 1


## A town: blocks on a grid separated by 4-5 m streets; some blocks are
## left empty as squares, some are split into two houses.
static func _town_blocks(map: IslandMap, rng: RandomNumberGenerator, keep_free: Array[Vector3]) -> void:
	var step: int = 14
	var ox: int = rng.randi_range(0, step - 1)
	var oz: int = rng.randi_range(0, step - 1)
	for bz in range(ox % step + 10, SIZE - 20, step):
		for bx in range(oz % step + 10, SIZE - 20, step):
			if rng.randf() < 0.2:
				continue  # town square
			var w: int = rng.randi_range(6, 9)
			var h: int = rng.randi_range(6, 9)
			if rng.randf() < 0.4:
				_try_place(map, Rect2i(bx, bz, w / 2, h), keep_free, 0)
				_try_place(map, Rect2i(bx + w / 2 + 2, bz, w / 2, h), keep_free, 0)
			else:
				_try_place(map, Rect2i(bx, bz, w, h), keep_free, 0)


## A port: rows of 2 x 6 shipping containers with narrow aisles.
static func _container_rows(map: IslandMap, rng: RandomNumberGenerator, keep_free: Array[Vector3]) -> void:
	for row in range(18, SIZE - 22, 5):
		var x: int = rng.randi_range(12, 20)
		while x < SIZE - 20:
			var horizontal: bool = rng.randf() < 0.7
			var rect := Rect2i(x, row, 6, 2) if horizontal else Rect2i(x, row - 1, 2, 4)
			if rng.randf() < 0.75:
				_try_place(map, rect, keep_free, 0)
			x += rect.size.x + rng.randi_range(2, 5)


static func _try_place(map: IslandMap, rect: Rect2i, keep_free: Array[Vector3], gap: int) -> bool:
	var f: FlowField = map.field
	for p in keep_free:
		if rect.grow(8).has_point(Vector2i(int(p.x), int(p.z))):
			return false
	for other in map.buildings:
		if rect.grow(maxi(gap, 1)).intersects(other):
			return false
	# Only on land, never into the sea.
	for z in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if f.is_blocked(x, z):
				return false
	f.set_blocked_rect(rect.position.x, rect.position.y, rect.end.x - 1, rect.end.y - 1)
	map.buildings.append(rect)
	return true


## Lava pools: walkable but deadly, away from goals.
static func _lava_pools(map: IslandMap, rng: RandomNumberGenerator, keep_free: Array[Vector3]) -> void:
	var attempts: int = 0
	while map.lava.size() < 7 and attempts < 500:
		attempts += 1
		var p := Vector3(rng.randf_range(25, SIZE - 25), 0, rng.randf_range(25, SIZE - 25))
		var r: float = rng.randf_range(2.5, 4.5)
		var ok: bool = not map.field.is_blocked(int(p.x), int(p.z))
		for k in keep_free + map.caches + map.lava:
			if Vector2(k.x - p.x, k.z - p.z).length() < 10.0 + r:
				ok = false
				break
		if ok:
			map.lava.append(p)
			map.lava_radius.append(r)
