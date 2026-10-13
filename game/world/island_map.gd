class_name IslandMap
extends RefCounted
## Builds the grey-box "Dawn Beach" island as a wall grid: the sea is blocked
## cells around an irregular coastline, buildings are blocked rectangles.

## Island grid size in metres (cells). Change this one number for bigger
## maps: coast, objectives and prop counts scale with it (see K).
const SIZE: int = 256
## Scale relative to the original 160 m island.
const K: float = SIZE / 160.0

var field: FlowField
var boat: Vector3
## Direction from the landing point out to the moored boat (flat, unit).
var boat_dir: Vector3 = Vector3(0, 0, 1)
var player_start: Vector3
var generators: Array[Vector3] = []
## Wall rectangles (x0, z0, w, h) in cells, for rendering buildings.
var buildings: Array[Rect2i] = []
## Hand-made islands: the cells their buildings and rocks really block
## (z * width + x); the rectangles above are only the boxes around them.
var wall_cells: PackedInt32Array = PackedInt32Array()
## Single-cell blocking props (cells), rendered as trees and rocks.
var trees: Array[Vector2i] = []
var rocks: Array[Vector2i] = []
## Expedition parts (see HandmadeIsland markers): the way on to the next
## part, the survivor to rescue, the zone to defend. x < 0 = none.
var exit := Vector3(-1, 0, -1)
var rescue_target := Vector3(-1, 0, -1)
var defend_zone := Vector3(-1, 0, -1)
## Hold Sequence points (HoldPoint_* markers), in the order to hold them.
## Empty = the run picks them (pick_hold_points).
var hold_points: Array[Vector3] = []
## Fuel Run: where the fuel cans start (Cargo_* markers, in number order;
## empty = the run picks spots, pick_cargo_points) and where they are
## delivered (Delivery marker; x < 0 = the extraction point).
var cargo_points: Array[Vector3] = []
var delivery := Vector3(-1, 0, -1)
## Nests: where the horde nests stand (Nest_* markers, in number order;
## empty = the run picks spots, pick_nest_points).
var nest_points: Array[Vector3] = []
## Intel Search: the spots to search (Search_* markers, in number order;
## empty = the run picks spots, pick_search_points) and where the intel is
## transmitted (Uplink marker; x < 0 = the run picks it, pick_uplink_point).
var search_points: Array[Vector3] = []
var uplink := Vector3(-1, 0, -1)
## Optional supply caches (detours with a reward).
var caches: Array[Vector3] = []
## Biome id: beach, town, jungle, port or volcano (see GameData.BIOMES).
var biome: StringName = &"beach"
## Lava pools (volcano): centre and radius; they hurt anyone standing in them.
var lava: Array[Vector3] = []
var lava_radius: PackedFloat32Array = PackedFloat32Array()
## True when the map comes from a hand-made scene (HandmadeIsland).
var handmade: bool = false
## Ground height per cell (row-major); empty on generated (flat) islands.
var heights: PackedFloat32Array = PackedFloat32Array()


## Ground height under a world point (0 on flat, generated islands):
## bilinear between cell centres, so units glide smoothly over hills.
func ground_y(p: Vector3) -> float:
	if heights.is_empty():
		return 0.0
	var w: int = field.width
	var h: int = field.height
	var fx: float = clampf(p.x - 0.5, 0.0, w - 1.0)
	var fz: float = clampf(p.z - 0.5, 0.0, h - 1.0)
	var x0: int = mini(int(fx), w - 2)
	var z0: int = mini(int(fz), h - 2)
	var tx: float = fx - x0
	var tz: float = fz - z0
	var a: float = lerpf(heights[z0 * w + x0], heights[z0 * w + x0 + 1], tx)
	var b: float = lerpf(heights[(z0 + 1) * w + x0], heights[(z0 + 1) * w + x0 + 1], tx)
	return maxf(lerpf(a, b, tz), -0.3)  # never under the sea surface


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


## Hold Sequence on a map without HoldPoint_* markers: up to `count` spots
## the player can walk to from the start, with `radius` metres of open
## ground around them, at least HOLD_MIN_FROM_BOAT from the boat and well
## apart from each other (spacing relaxes only when the map is too small).
## Same map and seed, same points. Ordered by walking distance from the
## start, so the sequence leads across the island, through the horde.
const HOLD_MIN_FROM_BOAT: float = 30.0
const HOLD_SPACING: float = 40.0
const HOLD_MIN_SPACING: float = 12.0
## Walking distance searched from the start (m): bounds the search on big
## hand-made islands (a 1.5 km Berlenga has two million cells).
const HOLD_MAX_WALK: int = 240

## Fuel Run on a map without Cargo_* markers: the same search as the hold
## points (reachable from the start, at least HOLD_MIN_FROM_BOAT from the
## boat, spread apart, fixed per seed), with another salt on the seed so
## the cans do not land on the spots a Hold Sequence would use, and a
## smaller open area (3 m: room to put a can down and fight beside it).
static func pick_cargo_points(map: IslandMap, count: int, rng_seed: int) -> Array[Vector3]:
	return pick_hold_points(map, count, rng_seed ^ 0x4655454c, 3.0)


## Nests on a map without Nest_* markers: the same search again (reachable,
## at least HOLD_MIN_FROM_BOAT from the boat, spread apart, fixed per seed)
## with its own salt, and 4 m of open ground around each nest so the mound
## does not touch a wall and there is room to fight around it.
static func pick_nest_points(map: IslandMap, count: int, rng_seed: int) -> Array[Vector3]:
	return pick_hold_points(map, count, rng_seed ^ 0x4e455354, 4.0)


## Intel Search on a map without Search_* markers: the same search as the
## hold points (reachable, at least HOLD_MIN_FROM_BOAT from the boat,
## spread apart, fixed per seed) with its own salt and 2 m of open ground,
## but only at spots within SEARCH_NEAR_BUILDING cells of a building or
## rock (the "doorways" a search makes sense at). A map with too few such
## spots (a bare beach) falls back to open ground anywhere.
const SEARCH_NEAR_BUILDING: int = 3
static func pick_search_points(map: IslandMap, count: int, rng_seed: int) -> Array[Vector3]:
	var out: Array[Vector3] = pick_hold_points(map, count, rng_seed ^ 0x53524348, 2.0, SEARCH_NEAR_BUILDING)
	if out.size() < count:
		out = pick_hold_points(map, count, rng_seed ^ 0x53524348, 2.0)
	return out


## Metres the picked uplink keeps from every search spot.
const UPLINK_MIN_FROM_SPOT: float = 10.0

## Intel Search on a map without an Uplink marker: the reachable spot (5 m
## of open ground, HOLD_MIN_FROM_BOAT from the boat) closest to the middle
## of the search spots, so the transmission happens in the heart of the
## searched area, not at the edge of the island. x < 0 = none fits.
static func pick_uplink_point(map: IslandMap, spots: Array[Vector3], rng_seed: int) -> Vector3:
	var options: Array[Vector3] = pick_hold_points(map, 12, rng_seed ^ 0x55504c4b, 5.0)
	if options.is_empty():
		return Vector3(-1, 0, -1)
	var middle := Vector3.ZERO
	for p in spots:
		middle += p
	middle = middle / maxf(1.0, spots.size()) if not spots.is_empty() else map.player_start
	# Not on top of a search spot (their rings would overlap), unless every
	# option is.
	var apart: Array[Vector3] = []
	for p in options:
		var ok: bool = true
		for q in spots:
			if Vector2(p.x - q.x, p.z - q.z).length() < UPLINK_MIN_FROM_SPOT:
				ok = false
				break
		if ok:
			apart.append(p)
	if apart.is_empty():
		apart = options
	var best: Vector3 = apart[0]
	for p in apart:
		if Vector2(p.x - middle.x, p.z - middle.z).length() < Vector2(best.x - middle.x, best.z - middle.z).length():
			best = p
	return best


## `near_building` > 0: only candidates within that many cells of one of
## map.buildings (rectangles up to 60 m across: bigger ones are terrain
## pieces, not buildings).
static func pick_hold_points(map: IslandMap, count: int, rng_seed: int, radius: float = 5.0, near_building: int = 0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var f: FlowField = map.field
	var w: int = f.width
	var start: Vector2i = f.world_to_cell(map.player_start)
	if count <= 0 or f.is_blocked(start.x, start.y):
		return out
	# Breadth-first walk (4 neighbours: what it reaches, the player reaches).
	var dist := {}  # cell index -> metres walked
	dist[start.y * w + start.x] = 0
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var d: int = dist[c.y * w + c.x]
		if d >= HOLD_MAX_WALK:
			continue
		for n: Vector2i in [Vector2i(c.x + 1, c.y), Vector2i(c.x - 1, c.y), Vector2i(c.x, c.y + 1), Vector2i(c.x, c.y - 1)]:
			if f.is_blocked(n.x, n.y) or dist.has(n.y * w + n.x):
				continue
			dist[n.y * w + n.x] = d + 1
			queue.append(n)
	# Candidates: every third cell, open around, away from the boat and lava.
	var open_r: int = ceili(radius * 0.5)
	var near := PackedByteArray()
	if near_building > 0:
		near.resize(w * f.height)
		for r in map.buildings:
			if r.size.x > 60 or r.size.y > 60:
				continue
			var g: Rect2i = r.grow(near_building).intersection(Rect2i(0, 0, w, f.height))
			for z in range(g.position.y, g.end.y):
				for x in range(g.position.x, g.end.x):
					near[z * w + x] = 1
	var candidates: Array[Vector3] = []
	for c: Vector2i in queue:
		if c.x % 3 != 0 or c.y % 3 != 0:
			continue
		if near_building > 0 and near[c.y * w + c.x] == 0:
			continue
		var p := Vector3(c.x + 0.5, 0, c.y + 0.5)
		if Vector2(p.x - map.boat.x, p.z - map.boat.z).length() < HOLD_MIN_FROM_BOAT:
			continue
		if not _free_around(f, c, open_r):
			continue
		var in_lava: bool = false
		for k in map.lava.size():
			if Vector2(p.x - map.lava[k].x, p.z - map.lava[k].z).length() < map.lava_radius[k] + radius + 2.0:
				in_lava = true
				break
		if not in_lava:
			candidates.append(p)
	# Deterministic shuffle, then greedy picks with the widest spacing that fits.
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed ^ 0x484f4c44
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Vector3 = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = t
	var spacing: float = HOLD_SPACING
	while true:
		out.clear()
		for p in candidates:
			var ok: bool = true
			for q in out:
				if Vector2(p.x - q.x, p.z - q.z).length() < spacing:
					ok = false
					break
			if ok:
				out.append(p)
				if out.size() == count:
					break
		if out.size() == count or spacing <= HOLD_MIN_SPACING:
			break
		spacing = maxf(HOLD_MIN_SPACING, spacing * 0.75)
	out.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return int(dist[int(a.z) * w + int(a.x)]) < int(dist[int(b.z) * w + int(b.x)]))
	return out


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
