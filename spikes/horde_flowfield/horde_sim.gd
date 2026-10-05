class_name HordeSim
extends RefCounted
## Horde as plain data: no nodes, no physics bodies.
##
## Each agent is an index into packed arrays (position, velocity, speed). A
## spatial hash (one bucket per grid cell, stored as linked lists in two int
## arrays) answers "who is near here" for separation and hitscan.

const AGENT_RADIUS: float = 0.35

var field: HordeFlowField
var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var speeds: PackedFloat32Array = PackedFloat32Array()
var count: int = 0
var target: Vector3 = Vector3.ZERO

## How strongly overlapping agents push apart (m/s per m of overlap).
var separation_strength: float = 6.0
## Agents closer than this to the target stop (they would attack here).
var arrive_radius: float = 0.9
## BFS cells expanded per tick while a recompute is pending.
var field_budget: int = 2000
## How fast velocity turns towards the desired one (1/s).
var steering: float = 10.0

# Spatial hash: _head[cell] = first agent in the cell, _next[agent] = next one.
var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _hash_dirty: bool = true
# Hitscan de-duplication stamps.
var _stamp: PackedInt32Array = PackedInt32Array()
var _query_id: int = 0


func _init(flow_field: HordeFlowField) -> void:
	field = flow_field
	_head.resize(field.width * field.height)


func add_agent(pos: Vector3, speed: float) -> int:
	positions.append(Vector3(pos.x, 0.0, pos.z))
	velocities.append(Vector3.ZERO)
	speeds.append(speed)
	_next.append(-1)
	_stamp.append(0)
	count += 1
	_hash_dirty = true
	return count - 1


## O(1) removal: the last agent takes index i.
func remove_agent(i: int) -> void:
	var last: int = count - 1
	positions[i] = positions[last]
	velocities[i] = velocities[last]
	speeds[i] = speeds[last]
	positions.resize(last)
	velocities.resize(last)
	speeds.resize(last)
	_next.resize(last)
	_stamp.resize(last)
	count = last
	_hash_dirty = true


func set_target(p: Vector3) -> void:
	target = Vector3(p.x, 0.0, p.z)
	field.request_target(field.world_to_cell(target))


func rebuild_hash() -> void:
	_head.fill(-1)
	var w: int = field.width
	var cs: float = field.cell_size
	for i in count:
		var p: Vector3 = positions[i]
		var cell: int = floori(p.z / cs) * w + floori(p.x / cs)
		_next[i] = _head[cell]
		_head[cell] = i
	_hash_dirty = false


func tick(dt: float) -> void:
	if field.is_computing:
		field.step(field_budget)
	if _hash_dirty:
		rebuild_hash()
	var w: int = field.width
	var h: int = field.height
	var cs: float = field.cell_size
	var min_d: float = AGENT_RADIUS * 2.0
	var min_d2: float = min_d * min_d
	var target_cell: Vector2i = field.target_cell
	var blend: float = minf(1.0, steering * dt)
	var max_step: float = cs * 0.45
	for i in count:
		var p: Vector3 = positions[i]
		var speed: float = speeds[i]
		# 1) Desired velocity from the flow field (direct steering in the target cell).
		var tx: float = target.x - p.x
		var tz: float = target.z - p.z
		var to_target2: float = tx * tx + tz * tz
		var desired := Vector3.ZERO
		if to_target2 > arrive_radius * arrive_radius:
			var cx: int = floori(p.x / cs)
			var cz: int = floori(p.z / cs)
			var dir: Vector2
			if Vector2i(cx, cz) == target_cell:
				dir = Vector2(tx, tz).normalized()
			else:
				# Steer at the centre of the next cell, not along the raw grid
				# direction: this keeps agents off wall corners.
				var step: Vector2 = field.direction_at(p)
				if step != Vector2.ZERO:
					dir = Vector2((cx + step.x + 0.5) * cs - p.x, (cz + step.y + 0.5) * cs - p.z).normalized()
			desired = Vector3(dir.x * speed, 0.0, dir.y * speed)
		# 2) Separation against the 3x3 neighbouring hash cells.
		var push_x: float = 0.0
		var push_z: float = 0.0
		var hx: int = floori(p.x / cs)
		var hz: int = floori(p.z / cs)
		for z in range(maxi(hz - 1, 0), mini(hz + 2, h)):
			var row: int = z * w
			for x in range(maxi(hx - 1, 0), mini(hx + 2, w)):
				var j: int = _head[row + x]
				while j != -1:
					if j != i:
						var q: Vector3 = positions[j]
						var dx: float = p.x - q.x
						var dz: float = p.z - q.z
						var d2: float = dx * dx + dz * dz
						if d2 < min_d2:
							if d2 > 0.000001:
								var d: float = sqrt(d2)
								var k: float = (min_d - d) / d
								push_x += dx * k
								push_z += dz * k
							else:
								# Exactly on top of each other: split by index.
								push_x += 0.05 if i < j else -0.05
					j = _next[j]
		var v: Vector3 = velocities[i].lerp(desired, blend)
		velocities[i] = v
		var mx: float = (v.x + push_x * separation_strength) * dt
		var mz: float = (v.z + push_z * separation_strength) * dt
		# Never move more than ~half a cell per tick (keeps wall checks exact).
		var m2: float = mx * mx + mz * mz
		if m2 > max_step * max_step:
			var s: float = max_step / sqrt(m2)
			mx *= s
			mz *= s
		# 3) Axis-separated move against the wall grid (slides along walls).
		var nx: float = p.x + mx
		if not overlaps_wall(field, nx, p.z, AGENT_RADIUS):
			p.x = nx
		var nz: float = p.z + mz
		if not overlaps_wall(field, p.x, nz, AGENT_RADIUS):
			p.z = nz
		positions[i] = p
	rebuild_hash()


## True if a square of half-size r centred at (x, z) touches a wall cell.
static func overlaps_wall(f: HordeFlowField, x: float, z: float, r: float) -> bool:
	var cs: float = f.cell_size
	var x0: int = floori((x - r) / cs)
	var x1: int = floori((x + r) / cs)
	var z0: int = floori((z - r) / cs)
	var z1: int = floori((z + r) / cs)
	return f.is_blocked(x0, z0) or f.is_blocked(x1, z0) or f.is_blocked(x0, z1) or f.is_blocked(x1, z1)


## First agent hit by a ray on the XZ plane. Walls stop the ray.
## Returns {"index": int (-1 = miss), "distance": float, "hit_wall": bool}.
func hitscan(origin: Vector3, direction: Vector3, max_dist: float) -> Dictionary:
	if _hash_dirty:
		rebuild_hash()
	var result: Dictionary = {"index": -1, "distance": INF, "hit_wall": false}
	var d := Vector2(direction.x, direction.z)
	if d.length_squared() < 0.000001:
		return result
	d = d.normalized()
	var o := Vector2(origin.x, origin.z)
	var cs: float = field.cell_size
	var w: int = field.width
	var h: int = field.height
	var r2: float = AGENT_RADIUS * AGENT_RADIUS
	_query_id += 1
	var qid: int = _query_id
	var best_t: float = INF
	var best_i: int = -1
	var limit: float = max_dist
	# Amanatides-Woo grid traversal.
	var cx: int = floori(o.x / cs)
	var cz: int = floori(o.y / cs)
	var step_x: int = 1 if d.x > 0.0 else -1
	var step_z: int = 1 if d.y > 0.0 else -1
	var t_delta_x: float = absf(cs / d.x) if d.x != 0.0 else INF
	var t_delta_z: float = absf(cs / d.y) if d.y != 0.0 else INF
	var t_max_x: float = INF
	if d.x != 0.0:
		var bx: float = (cx + (1 if step_x > 0 else 0)) * cs
		t_max_x = (bx - o.x) / d.x
	var t_max_z: float = INF
	if d.y != 0.0:
		var bz: float = (cz + (1 if step_z > 0 else 0)) * cs
		t_max_z = (bz - o.y) / d.y
	var t_enter: float = 0.0
	var wall_hit: bool = false
	while t_enter <= limit and t_enter <= best_t:
		if field.is_blocked(cx, cz):
			# Wall: nothing beyond this point can be hit.
			wall_hit = true
			limit = minf(limit, t_enter)
			break
		# An agent hit at t lies within one cell of the ray cell at t, so
		# checking the 3x3 block around each visited cell finds all of them.
		for z in range(maxi(cz - 1, 0), mini(cz + 2, h)):
			for x in range(maxi(cx - 1, 0), mini(cx + 2, w)):
				var j: int = _head[z * w + x]
				while j != -1:
					if _stamp[j] != qid:
						_stamp[j] = qid
						var q: Vector3 = positions[j]
						var mx: float = o.x - q.x
						var mz: float = o.y - q.z
						var b: float = mx * d.x + mz * d.y
						var c: float = mx * mx + mz * mz - r2
						if c <= 0.0:
							# Origin inside the agent.
							if 0.0 < best_t:
								best_t = 0.0
								best_i = j
						elif b < 0.0:
							var disc: float = b * b - c
							if disc >= 0.0:
								var t: float = -b - sqrt(disc)
								if t < best_t:
									best_t = t
									best_i = j
					j = _next[j]
		if t_max_x < t_max_z:
			t_enter = t_max_x
			t_max_x += t_delta_x
			cx += step_x
		else:
			t_enter = t_max_z
			t_max_z += t_delta_z
			cz += step_z
	if best_i != -1 and best_t <= limit:
		result["index"] = best_i
		result["distance"] = best_t
	elif wall_hit:
		result["hit_wall"] = true
		result["distance"] = limit
	return result
