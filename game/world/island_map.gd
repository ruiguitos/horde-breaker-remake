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
## Light the Signals: the signal beacons, in the order to light them
## (Signal_* markers in number order, then the Lighthouse marker last;
## empty = the run picks spots, pick_signal_points), whether the last one is
## a lighthouse (a Lighthouse marker), and the fuel for each signal (Fuel_*
## markers in number order: Fuel_1 feeds the first signal; missing ones are
## picked near their signal, pick_signal_fuel_points).
var signal_points: Array[Vector3] = []
var signal_lighthouse: bool = false
var signal_fuel: Array[Vector3] = []
## Sabotage: the power switch to cut first (PowerSwitch marker; x < 0 = the
## run picks it, pick_power_switch), the machines to plant the charges on
## (Machine_* markers in number order; empty = picked near the switch,
## pick_machine_points) and where to get out after (ExfilPoint marker;
## x < 0 = the usual extraction point, the boat).
var power_switch := Vector3(-1, 0, -1)
var machine_points: Array[Vector3] = []
var exfil := Vector3(-1, 0, -1)
## Escort: the cart's route (EscortRoute_* markers in number order; the
## first is where it waits; empty = the run picks a route,
## pick_escort_route), the stops on the way (EscortStop_* markers in number
## order, each moved onto the route; empty = at even shares of the route),
## where it is delivered (EscortEnd marker; x < 0 = the extraction point)
## and whether a survivor walks the route instead of a cart (an
## EscortSurvivor marker: where the survivor waits, the route's first
## point, before the EscortRoute_* ones).
var escort_route: Array[Vector3] = []
var escort_stops: Array[Vector3] = []
var escort_end := Vector3(-1, 0, -1)
var escort_survivor: bool = false
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
## Walking surfaces, for footstep sounds (see surface_at): one byte per cell, row-major
## like `field`. Empty until a map sets it; the cells not marked are the biome's ground.
var cover: PackedByteArray = PackedByteArray()
const COVER_ROAD: int = 1
const COVER_DECK: int = 2
## Surface of the open ground in each biome.
const GROUND_SURFACE: Dictionary = {&"beach": &"sand", &"jungle": &"sand", &"town": &"stone", &"port": &"metal", &"volcano": &"stone"}
## Half the width of a generated road, in cells (about 5 m across).
const ROAD_HALF_WIDTH: int = 2


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


## The surface under a world point, for footstep sounds: decks (bridges, piers)
## are wood, roads are stone, and the rest of the ground follows the biome.
func surface_at(p: Vector3) -> StringName:
	var c: Vector2i = field.world_to_cell(p)
	if not cover.is_empty() and c.x >= 0 and c.y >= 0 and c.x < field.width and c.y < field.height:
		var kind: int = cover[c.y * field.width + c.x]
		if kind == COVER_DECK:
			return &"wood"
		if kind == COVER_ROAD:
			return &"stone"
	return GROUND_SURFACE.get(biome, &"sand")


## Generated islands: the road paths of IslandRoads.plan() become road cells. The
## built road curves a little between the path's points; the cells are close enough.
func mark_roads(paths: Array[PackedVector3Array]) -> void:
	if cover.is_empty():
		cover.resize(field.width * field.height)
	for path in paths:
		for k in range(path.size() - 1):
			var a: Vector3 = path[k]
			var b: Vector3 = path[k + 1]
			var steps: int = maxi(1, ceili(a.distance_to(b) * 2.0))  # a sample every half metre
			for s in range(steps + 1):
				var c: Vector2i = field.world_to_cell(a.lerp(b, float(s) / steps))
				for dz in range(-ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 1):
					for dx in range(-ROAD_HALF_WIDTH, ROAD_HALF_WIDTH + 1):
						var x: int = c.x + dx
						var z: int = c.y + dz
						if x >= 0 and z >= 0 and x < field.width and z < field.height:
							cover[z * field.width + x] = COVER_ROAD


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


## Light the Signals on a map without Signal_* markers: the same search as
## the hold points (reachable, at least HOLD_MIN_FROM_BOAT from the boat,
## spread apart, fixed per seed) with its own salt and 3 m of open ground.
## pick_hold_points orders them by walking distance from the start, so each
## signal is farther in than the one before: lighting one leads on.
static func pick_signal_points(map: IslandMap, count: int, rng_seed: int) -> Array[Vector3]:
	return pick_hold_points(map, count, rng_seed ^ 0x5349474e, 3.0)


## Where the fuel for a signal waits: this many metres from it (flat), and
## at most SIGNAL_FUEL_WALK metres of walking away, so the can is "near the
## signal" for the legs too, not across a wall. A can keeps
## SIGNAL_FUEL_MIN from every other signal (it must not sit on one) and
## SIGNAL_FUEL_APART from the other cans.
const SIGNAL_FUEL_MIN: float = 15.0
const SIGNAL_FUEL_MAX: float = 30.0
const SIGNAL_FUEL_WALK: int = 60
const SIGNAL_FUEL_APART: float = 8.0

## Light the Signals: one fuel spot per signal, for the signals without a
## Fuel_* marker (`given[i]` with x >= 0 is kept as it is). Candidates are
## the hold-point candidates (reachable from the start, off the boat, 2 m
## open, shuffled per seed); the first one within the distance band of its
## signal wins. None in the band: the reachable candidate (walking) closest
## to the middle of the band; none at all: the signal itself (the can is
## then delivered as soon as it is picked up: never a softlock).
static func pick_signal_fuel_points(map: IslandMap, signals: Array[Vector3], rng_seed: int,
		given: Array[Vector3] = []) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var candidates: Array[Vector3] = []
	var searched: bool = false
	for i in signals.size():
		if i < given.size() and given[i].x >= 0.0:
			out.append(given[i])
			continue
		if not searched:  # only when a signal has no Fuel_* marker
			searched = true
			candidates = _hold_candidates(map, rng_seed ^ 0x46554c53, 2.0)[0]
		var s: Vector3 = signals[i]
		var walk: Dictionary = _walk_from(map.field, s, SIGNAL_FUEL_WALK)
		var best := Vector3(-1, 0, -1)
		var best_off: float = INF
		for p in candidates:
			if not walk.has(int(p.z) * map.field.width + int(p.x)):
				continue
			var d: float = Vector2(p.x - s.x, p.z - s.z).length()
			var ok: bool = true
			for j in signals.size():
				if j != i and Vector2(p.x - signals[j].x, p.z - signals[j].z).length() < SIGNAL_FUEL_MIN:
					ok = false
			for q in out:
				if Vector2(p.x - q.x, p.z - q.z).length() < SIGNAL_FUEL_APART:
					ok = false
			if not ok:
				continue
			if d >= SIGNAL_FUEL_MIN and d <= SIGNAL_FUEL_MAX:
				best = p
				break
			var off: float = absf(d - (SIGNAL_FUEL_MIN + SIGNAL_FUEL_MAX) * 0.5)
			if off < best_off:
				best_off = off
				best = p
		out.append(best if best.x >= 0.0 else s)
	return out


## Sabotage on a map without a PowerSwitch marker: a hold-point candidate
## (reachable, HOLD_MIN_FROM_BOAT off the boat, 4 m of open ground) at
## least POWER_FAR_SHARE of the farthest candidate's walk from the start,
## the first in the seeded shuffle: deep in the island, but not always the
## same spot. x < 0 = none (a map too small to pick from).
const POWER_FAR_SHARE: float = 0.6

static func pick_power_switch(map: IslandMap, rng_seed: int) -> Vector3:
	var cands: Array = _hold_candidates(map, rng_seed ^ 0x504f5752, 4.0)
	var candidates: Array[Vector3] = cands[0]
	var dist: Dictionary = cands[1]
	var w: int = map.field.width
	var far: int = 0
	for p in candidates:
		far = maxi(far, int(dist[int(p.z) * w + int(p.x)]))
	for p in candidates:
		if int(dist[int(p.z) * w + int(p.x)]) >= int(far * POWER_FAR_SHARE):
			return p
	return Vector3(-1, 0, -1)


## Sabotage: where the machines stand (the charges) on a map without
## Machine_* markers: this many metres (flat) from the power switch, so the
## cut and the charges are two places, and MACHINE_APART from each other
## (spread: one blast does not cover the other's approach). Candidates are
## the hold-point candidates (reachable from the start, off the boat, 3 m
## open, shuffled per seed); the first ones in the band win. Too few in the
## band: the remaining candidates closest to the middle of the band; none
## at all: the switch itself (never a softlock).
const MACHINE_MIN: float = 30.0
const MACHINE_MAX: float = 60.0
const MACHINE_APART: float = 12.0

static func pick_machine_points(map: IslandMap, switch: Vector3, count: int, rng_seed: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 0:
		return out
	var candidates: Array[Vector3] = _hold_candidates(map, rng_seed ^ 0x4d414348, 3.0)[0]
	var apart := func(p: Vector3, spacing: float) -> bool:
		for q in out:
			if Vector2(p.x - q.x, p.z - q.z).length() < spacing:
				return false
		return true
	for p in candidates:
		var d: float = Vector2(p.x - switch.x, p.z - switch.z).length()
		if d >= MACHINE_MIN and d <= MACHINE_MAX and apart.call(p, MACHINE_APART):
			out.append(p)
			if out.size() == count:
				return out
	# Not enough in the band: the closest to its middle, still apart.
	var mid: float = (MACHINE_MIN + MACHINE_MAX) * 0.5
	var rest: Array[Vector3] = candidates.duplicate()
	rest.sort_custom(func(a: Vector3, b: Vector3) -> bool:
		return absf(Vector2(a.x - switch.x, a.z - switch.z).length() - mid) < absf(Vector2(b.x - switch.x, b.z - switch.z).length() - mid))
	for p in rest:
		if out.size() == count:
			break
		if Vector2(p.x - switch.x, p.z - switch.z).length() >= HOLD_MIN_SPACING and apart.call(p, MACHINE_APART * 0.5):
			out.append(p)
	while out.size() < count:
		out.append(switch)
	return out


## Escort on a map without EscortRoute_* markers: a route of
## ESCORT_WAYPOINTS + 1 points, from a start `min_walk`..`max_walk` metres
## on foot from `end` (the delivery point) to just before it. The start is
## the first hold-point candidate (reachable from the landing, 3 m open, off
## the boat, out of the lava; shuffled per seed, its own salt) in that band;
## none in the band: the candidate farthest on foot from `end`; none at all:
## `end` itself (a route of length 0: delivered at once, never a softlock).
## The other points sit at even shares of the walk from the start to `end`,
## so a map's route always follows walkable ground. `end` is not included.
const ESCORT_WAYPOINTS: int = 3

static func pick_escort_route(map: IslandMap, end: Vector3, rng_seed: int, min_walk: float, max_walk: float) -> Array[Vector3]:
	var f: FlowField = map.field
	var goal: Vector3 = _walkable_near(f, end)
	var nav := FlowField.new(f.width, f.height)
	nav.blocked = f.blocked
	nav.max_distance = int(max_walk) + 30
	nav.compute_now(nav.world_to_cell(goal))
	var candidates: Array[Vector3] = _hold_candidates(map, rng_seed ^ 0x45534352, 3.0)[0]
	var start := Vector3(-1, 0, -1)
	var far := Vector3(-1, 0, -1)
	var far_d: int = -1
	for p in candidates:
		var d: int = nav.distance_at(p)
		if d >= FlowField.UNREACHABLE:
			continue
		if d >= int(min_walk) and d <= int(max_walk):
			start = p
			break
		if d > far_d:
			far_d = d
			far = p
	if start.x < 0.0:
		start = far if far_d >= 0 else goal
	var out: Array[Vector3] = [start]
	var walk: PackedVector3Array = _descend(nav, start, goal)
	if walk.size() < 2:
		return out
	var length: float = polyline_length(walk)
	for k in range(1, ESCORT_WAYPOINTS + 1):
		out.append(point_along(walk, length * k / float(ESCORT_WAYPOINTS + 1)))
	return out


## The path the escort follows through `waypoints` (in order; the last one
## is the delivery point), on walkable ground: each leg is walked on the
## grid (a breadth-first search from the leg's far end, limited to
## ESCORT_LEG_FACTOR times its straight length plus ESCORT_LEG_SLACK metres,
## so it never searches all of a 2-million-cell Berlenga; three times wider
## when that is not enough; a straight leg when even that fails), then its
## corners are cut where a straight line keeps ESCORT_CLEARANCE metres from
## every blocked cell (leg by leg: the path still passes every waypoint).
## Points on the simulation plane (y = 0).
const ESCORT_LEG_FACTOR: float = 3.0
const ESCORT_LEG_SLACK: int = 40
const ESCORT_CLEARANCE: float = 0.45
## How many path points a straight cut may skip (bounds the line checks).
const ESCORT_CUT_MAX: int = 40

static func escort_path(map: IslandMap, waypoints: Array[Vector3]) -> PackedVector3Array:
	var f: FlowField = map.field
	var dense := PackedVector3Array()
	if waypoints.is_empty():
		return dense
	var pts: Array[Vector3] = []
	for p in waypoints:
		pts.append(_walkable_near(f, p))
	dense.append(pts[0])
	if pts.size() == 1:
		return dense
	var nav := FlowField.new(f.width, f.height)
	nav.blocked = f.blocked
	for k in range(1, pts.size()):
		var a: Vector3 = pts[k - 1]
		var b: Vector3 = pts[k]
		var limit: int = int(Vector2(a.x - b.x, a.z - b.z).length() * ESCORT_LEG_FACTOR) + ESCORT_LEG_SLACK
		for attempt in 2:
			nav.max_distance = limit
			nav.compute_now(nav.world_to_cell(b))
			if nav.distance_at(a) < FlowField.UNREACHABLE:
				break
			limit *= 3
		var leg: PackedVector3Array = _descend(nav, a, b) if nav.distance_at(a) < FlowField.UNREACHABLE else PackedVector3Array([a, b])
		# Straightened leg by leg: every waypoint stays on the path.
		leg = _straighten(f, leg)
		for i in range(1, leg.size()):
			dense.append(leg[i])
	return dense


## Steps down the walking distances of `nav` (its target is `to`) from
## `from`: the cell centres on the way, `from` first and `to` last.
static func _descend(nav: FlowField, from: Vector3, to: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array([from])
	var p: Vector3 = from
	var guard: int = mini(nav.distance_at(from), 100000) * 2 + 8
	while guard > 0:
		guard -= 1
		var d: Vector2 = nav.direction_at(p)
		if d == Vector2.ZERO:
			break
		p = Vector3(floorf(p.x) + d.x + 0.5, 0, floorf(p.z) + d.y + 0.5)
		out.append(p)
	if nav.world_to_cell(out[out.size() - 1]) == nav.world_to_cell(to) and out.size() > 1:
		out[out.size() - 1] = to
	elif out[out.size() - 1] != to:
		out.append(to)
	return out


## Corner cutting: from each kept point, the farthest later point (at most
## ESCORT_CUT_MAX on) that a straight, clear line reaches.
static func _straighten(f: FlowField, pts: PackedVector3Array) -> PackedVector3Array:
	if pts.size() <= 2:
		return pts
	var out := PackedVector3Array([pts[0]])
	var i: int = 0
	while i < pts.size() - 1:
		var j: int = i + 1
		while j + 1 < pts.size() and j + 1 - i <= ESCORT_CUT_MAX and _clear_line(f, pts[i], pts[j + 1]):
			j += 1
		out.append(pts[j])
		i = j
	return out


## True when the straight line a-b stays ESCORT_CLEARANCE off blocked
## cells (sampled every 0.5 m, on the line and to both sides of it).
static func _clear_line(f: FlowField, a: Vector3, b: Vector3) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var length: float = d.length()
	if length < 0.01:
		return true
	var side: Vector2 = Vector2(-d.y, d.x) / length * ESCORT_CLEARANCE
	var n: int = ceili(length / 0.5)
	for k in n + 1:
		var t: float = float(k) / n
		var p := Vector2(a.x, a.z) + d * t
		for o: Vector2 in [Vector2.ZERO, side, -side]:
			if f.is_blocked(floori(p.x + o.x), floori(p.y + o.y)):
				return false
	return true


## The walkable cell centre nearest to `p` within 8 m (`p` itself when its
## cell is open or nothing is): routes start and end on open ground.
static func _walkable_near(f: FlowField, p: Vector3) -> Vector3:
	var c: Vector2i = f.world_to_cell(p)
	if not f.is_blocked(c.x, c.y):
		return Vector3(p.x, 0, p.z)
	for r in range(1, 9):
		var best := Vector3(-1, 0, -1)
		var bd: float = INF
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r or f.is_blocked(c.x + dx, c.y + dz):
					continue
				var q := Vector3(c.x + dx + 0.5, 0, c.y + dz + 0.5)
				var d: float = Vector2(q.x - p.x, q.z - p.z).length()
				if d < bd:
					bd = d
					best = q
		if best.x >= 0.0:
			return best
	return Vector3(p.x, 0, p.z)


## Length (flat metres) of a polyline.
static func polyline_length(pts: PackedVector3Array) -> float:
	var total: float = 0.0
	for i in range(1, pts.size()):
		total += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
	return total


## The point `at` metres along a polyline (clamped to its ends).
static func point_along(pts: PackedVector3Array, at: float) -> Vector3:
	var left: float = at
	for i in range(1, pts.size()):
		var seg: float = Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		if left <= seg and seg > 0.0:
			return pts[i - 1].lerp(pts[i], left / seg)
		left -= seg
	return pts[pts.size() - 1]


## Breadth-first walk (4 neighbours) from `from` over open cells, up to
## `max_walk` metres: cell index -> metres walked.
static func _walk_from(f: FlowField, from: Vector3, max_walk: int) -> Dictionary:
	var w: int = f.width
	var c0: Vector2i = f.world_to_cell(from)
	var dist := {}
	if f.is_blocked(c0.x, c0.y):
		return dist
	dist[c0.y * w + c0.x] = 0
	var queue: Array[Vector2i] = [c0]
	var head: int = 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		var d: int = dist[c.y * w + c.x]
		if d >= max_walk:
			continue
		for n: Vector2i in [Vector2i(c.x + 1, c.y), Vector2i(c.x - 1, c.y), Vector2i(c.x, c.y + 1), Vector2i(c.x, c.y - 1)]:
			if f.is_blocked(n.x, n.y) or dist.has(n.y * w + n.x):
				continue
			dist[n.y * w + n.x] = d + 1
			queue.append(n)
	return dist


## `near_building` > 0: only candidates within that many cells of one of
## map.buildings (rectangles up to 60 m across: bigger ones are terrain
## pieces, not buildings).
static func pick_hold_points(map: IslandMap, count: int, rng_seed: int, radius: float = 5.0, near_building: int = 0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if count <= 0:
		return out
	var cands: Array = _hold_candidates(map, rng_seed, radius, near_building)
	var candidates: Array[Vector3] = cands[0]
	var dist: Dictionary = cands[1]
	var w: int = map.field.width
	if candidates.is_empty():
		return out
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


## The hold-point candidates: every third cell the player can walk to from
## the start (within HOLD_MAX_WALK), with `radius` metres of open ground,
## at least HOLD_MIN_FROM_BOAT from the boat and clear of lava, shuffled
## with the seed. Returns [candidates, walking distance per cell index].
static func _hold_candidates(map: IslandMap, rng_seed: int, radius: float, near_building: int = 0) -> Array:
	var f: FlowField = map.field
	var w: int = f.width
	var start: Vector2i = f.world_to_cell(map.player_start)
	var none: Array[Vector3] = []
	if f.is_blocked(start.x, start.y):
		return [none, {}]
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
	# Deterministic shuffle (the callers then pick in this order).
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed ^ 0x484f4c44
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var t: Vector3 = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = t
	return [candidates, dist]


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
