extends SceneTree
## Walk times on a handmade island (open-island pilot, stage 5): how far, on foot, every point of
## interest is from the landing, and how far the open ground is from the nearest one.
##   godot --headless --path . --script res://tools/dev/measure_walks.gd -- [island scene]
## Distances are shortest walkable paths on the map's grid (8 neighbours, diagonals √2), turned into
## seconds at GameData.PLAYER_SPEED. Cover (grass, bushes) does not slow the player, so it is free.
## Real walks are a little longer: the player does not walk the exact shortest line.

const DEFAULT_ISLAND: String = "res://game/world/handmade/islands/beach_01.tscn"
const GOAL_SECONDS: float = 40.0  ## the plan's "nothing more than 40 s from an objective"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else DEFAULT_ISLAND
	var island: HandmadeIsland = (load(path) as PackedScene).instantiate() as HandmadeIsland
	root.add_child(island)
	await process_frame
	var problems: Array[String] = []
	var map: IslandMap = island.build_map(problems)
	var field: FlowField = map.field
	var points: Array = []  # [name, Vector3]
	for i in map.generators.size():
		points.append(["generator %d" % (i + 1), map.generators[i]])
	for p in map.side_caches:
		points.append(["side stash", p])
	for p in map.side_survivors:
		points.append(["side survivor", p])
	for p in map.side_nests:
		points.append(["side nest", p])
	for p in map.exfil_points:
		points.append(["exfil", p])
	var speed: float = GameData.PLAYER_SPEED * field.cell_size
	print("WALK island=%s size=%dx%d cells, %d points of interest" % [path.get_file(), field.width, field.height, points.size()])
	var from_boat: PackedFloat32Array = _distances(field, [field.world_to_cell(map.boat)])
	for entry in points:
		var c: Vector2i = field.world_to_cell(entry[1])
		var d: float = from_boat[c.y * field.width + c.x]
		print("WALK landing -> %-14s (%4.0f, %4.0f): %s" % [entry[0], entry[1].x, entry[1].z, _secs(d, speed)])
	var worst: float = 0.0
	for entry in points:
		var c: Vector2i = field.world_to_cell(entry[1])
		worst = maxf(worst, from_boat[c.y * field.width + c.x])
	print("WALK farthest point from the landing: %s" % _secs(worst, speed))
	var sources: Array = [field.world_to_cell(map.boat)]
	for entry in points:
		sources.append(field.world_to_cell(entry[1]))
	var nearest: PackedFloat32Array = _distances(field, sources)
	var reach: Array[float] = []
	var beyond: int = 0
	for d in nearest:
		if d < INF:
			reach.append(d)
			if d / speed > GOAL_SECONDS:
				beyond += 1
	reach.sort()
	print("WALK open ground to the nearest point: p50 %s, p95 %s, max %s; %.1f%% of walkable cells beyond %.0f s" % [
		_secs(reach[int(reach.size() * 0.5)], speed), _secs(reach[int(reach.size() * 0.95)], speed),
		_secs(reach[-1], speed), 100.0 * beyond / reach.size(), GOAL_SECONDS])
	island.queue_free()
	quit(0)


func _secs(cells: float, speed: float) -> String:
	if cells == INF:
		return "unreachable"
	return "%.0f m, %.1f s" % [cells, cells / speed]


## Shortest walkable distance (in cells) from the nearest source to every cell, on 8 neighbours
## with a diagonal only where both side cells are open (no corner cutting). Dial's algorithm with
## integer steps (10 straight, 14 diagonal), so no heap of arrays: fast and light in GDScript.
func _distances(field: FlowField, sources: Array) -> PackedFloat32Array:
	var w: int = field.width
	var h: int = field.height
	var cost := PackedInt32Array()
	cost.resize(w * h)
	cost.fill(0x3fffffff)
	var buckets: Array[PackedInt32Array] = []
	for b in 15:
		buckets.append(PackedInt32Array())
	for c: Vector2i in sources:
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			continue
		cost[c.y * w + c.x] = 0
		buckets[0].append(c.y * w + c.x)
	var dxs: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
	var dzs: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]
	var d: int = 0
	var empty_run: int = 0
	while empty_run < 15:
		var slot: int = d % 15
		var bucket: PackedInt32Array = buckets[slot]
		buckets[slot] = PackedInt32Array()
		if bucket.is_empty():
			empty_run += 1
			d += 1
			continue
		empty_run = 0
		for i in bucket:
			if cost[i] != d:
				continue
			var x: int = i % w
			var z: int = i / w
			for k in 8:
				var nx: int = x + dxs[k]
				var nz: int = z + dzs[k]
				if nx < 0 or nz < 0 or nx >= w or nz >= h or field.is_blocked(nx, nz):
					continue
				var step: int = 10
				if k >= 4:
					if field.is_blocked(nx, z) or field.is_blocked(x, nz):
						continue
					step = 14
				var ni: int = nz * w + nx
				if d + step < cost[ni]:
					cost[ni] = d + step
					buckets[(d + step) % 15].append(ni)
		d += 1
	var out := PackedFloat32Array()
	out.resize(w * h)
	for i in w * h:
		out[i] = INF if cost[i] == 0x3fffffff else cost[i] / 10.0
	return out
