class_name HordeSim
extends RefCounted
## Horde as plain data: agent i lives at pos[i] / vel[i] / speed[i].
## No nodes, no physics bodies. Each step:
##   1. rebuild a uniform spatial hash (counting sort, O(N));
##   2. steer each agent along the flow field + separation from neighbours;
##   3. move per axis against the field's blocked cells (walls).
## The same hash answers hitscan queries.

var field: HordeFlowField
var count: int = 0
var pos: PackedVector3Array
var vel: PackedVector3Array
var speed: PackedFloat32Array
var target_pos: Vector3 = Vector3.ZERO

var agent_radius: float = 0.35
var separation_radius: float = 0.75
var separation_strength: float = 6.0
var steer_rate: float = 8.0
var arrive_radius: float = 1.0

var hash_cell: float = 1.0
var hash_w: int
var hash_h: int
# Hash as per-cell linked lists: _cell_head[c] = first agent in cell c (or -1),
# _next[i] = next agent in the same cell. Rebuild and reset only touch the
# cells that hold agents, so cost is O(N) and not O(map cells).
var _cell_head: PackedInt32Array
var _next: PackedInt32Array
var _agent_cell: PackedInt32Array
var _visit: PackedInt32Array
var _visit_stamp: int = 0


func _init(f: HordeFlowField) -> void:
	field = f
	hash_w = ceili(f.width * f.cell_size / hash_cell)
	hash_h = ceili(f.height * f.cell_size / hash_cell)
	_cell_head.resize(hash_w * hash_h)
	_cell_head.fill(-1)
	_visit.resize(hash_w * hash_h)


func add_agent(p: Vector3, spd: float) -> int:
	pos.push_back(Vector3(p.x, 0.0, p.z))
	vel.push_back(Vector3.ZERO)
	speed.push_back(spd)
	count += 1
	_next.resize(count)
	_agent_cell.resize(count)
	_agent_cell[count - 1] = 0
	_cell_head.fill(-1)
	return count - 1


func _hash_index(p: Vector3) -> int:
	var hx: int = clampi(floori(p.x / hash_cell), 0, hash_w - 1)
	var hz: int = clampi(floori(p.z / hash_cell), 0, hash_h - 1)
	return hz * hash_w + hx


func rebuild_hash() -> void:
	# Clear only the cells used last time.
	for i in count:
		_cell_head[_agent_cell[i]] = -1
	for i in count:
		var c: int = _hash_index(pos[i])
		_agent_cell[i] = c
		_next[i] = _cell_head[c]
		_cell_head[c] = i


func step(dt: float) -> void:
	rebuild_hash()
	var sep_r: float = separation_radius
	var sep_r2: float = sep_r * sep_r
	var fw: int = field.width
	var cs: float = field.cell_size
	var blend: float = minf(1.0, steer_rate * dt)
	var r: float = agent_radius
	for i in count:
		var p: Vector3 = pos[i]
		var spd: float = speed[i]

		# 1. Desired velocity from the field.
		var desired := Vector3.ZERO
		var cx: int = floori(p.x / cs)
		var cz: int = floori(p.z / cs)
		var to_t := Vector3(target_pos.x - p.x, 0.0, target_pos.z - p.z)
		var t_len2: float = to_t.length_squared()
		if t_len2 > arrive_radius * arrive_radius and cx >= 0 and cz >= 0 \
				and cx < fw and cz < field.height:
			var ci: int = cz * fw + cx
			var d: int = field.dist[ci]
			if d == 0 or d == 1:
				# Target cell or next to it: head straight for the target.
				desired = to_t / sqrt(t_len2) * spd
			elif d != HordeFlowField.UNREACHABLE:
				var f2: Vector2 = field.flow[ci]
				desired = Vector3(f2.x * spd, 0.0, f2.y * spd)

		# 2. Separation from neighbours in the 3x3 hash block.
		var push_x: float = 0.0
		var push_z: float = 0.0
		var hc: int = _agent_cell[i]
		var hx: int = hc % hash_w
		@warning_ignore("integer_division")
		var hz: int = hc / hash_w
		for oz in range(maxi(hz - 1, 0), mini(hz + 1, hash_h - 1) + 1):
			for ox in range(maxi(hx - 1, 0), mini(hx + 1, hash_w - 1) + 1):
				var c: int = oz * hash_w + ox
				var k: int = _cell_head[c]
				while k != -1:
					var j: int = k
					k = _next[k]
					if j == i:
						continue
					var q: Vector3 = pos[j]
					var dx: float = p.x - q.x
					var dz: float = p.z - q.z
					var d2: float = dx * dx + dz * dz
					if d2 >= sep_r2:
						continue
					if d2 < 0.000001:
						# Exactly overlapping: deterministic nudge by index.
						push_x += 0.5 if i > j else -0.5
						continue
					var dl: float = sqrt(d2)
					var wgt: float = (sep_r - dl) / (sep_r * dl)
					push_x += dx * wgt
					push_z += dz * wgt

		# 3. Steering (smooth blend towards desired + push), clamped speed.
		var v: Vector3 = vel[i]
		var want := Vector3(desired.x + push_x * separation_strength, 0.0,
				desired.z + push_z * separation_strength)
		v = v.lerp(want, blend)
		var max_v: float = spd * 1.5
		if v.length_squared() > max_v * max_v:
			v = v.normalized() * max_v

		# 4. Move per axis; the leading edge (centre + radius) must stay in a
		# free cell. Since radius < cell size, the centre can never enter a
		# blocked cell either.
		var nx: float = p.x + v.x * dt
		if v.x != 0.0:
			var ex: float = nx + (r if v.x > 0.0 else -r)
			if _blocked_xz(ex, p.z, cs, fw):
				v.x = 0.0
			else:
				p.x = nx
		var nz: float = p.z + v.z * dt
		if v.z != 0.0:
			var ez: float = nz + (r if v.z > 0.0 else -r)
			if _blocked_xz(p.x, ez, cs, fw):
				v.z = 0.0
			else:
				p.z = nz
		pos[i] = p
		vel[i] = v


func _blocked_xz(x: float, z: float, cs: float, fw: int) -> bool:
	var cx: int = floori(x / cs)
	var cz: int = floori(z / cs)
	if cx < 0 or cz < 0 or cx >= fw or cz >= field.height:
		return true
	return field.blocked[cz * fw + cx] != 0


## Hitscan on the XZ plane: returns the index of the first agent whose circle
## (radius `hit_radius`, default agent_radius) the ray touches, or -1.
## Walls stop the ray. Uses the spatial hash built by the last step()
## (call rebuild_hash() first if agents were moved by hand).
func hitscan(origin: Vector3, dir: Vector3, max_dist: float, hit_radius: float = -1.0) -> int:
	var d := Vector3(dir.x, 0.0, dir.z)
	if d.length_squared() < 0.000001:
		return -1
	d = d.normalized()
	var hr: float = agent_radius if hit_radius < 0.0 else hit_radius
	var hr2: float = hr * hr
	var best: int = -1
	var best_t: float = max_dist
	var wall_t: float = INF
	var step_len: float = minf(hash_cell, field.cell_size) * 0.5
	_visit_stamp += 1
	var t: float = 0.0
	# Sampled march; each sample checks the 3x3 hash block around it, so any
	# agent within one hash cell of the ray is tested. Stop when no unvisited
	# cell can hold a closer hit.
	while t <= max_dist and t <= best_t + hash_cell * 1.5:
		var s: Vector3 = origin + d * t
		if field.is_blocked_world(s):
			wall_t = t
			break
		var hc: int = _hash_index(s)
		var hx: int = hc % hash_w
		@warning_ignore("integer_division")
		var hz: int = hc / hash_w
		for oz in range(maxi(hz - 1, 0), mini(hz + 1, hash_h - 1) + 1):
			for ox in range(maxi(hx - 1, 0), mini(hx + 1, hash_w - 1) + 1):
				var c: int = oz * hash_w + ox
				if _visit[c] == _visit_stamp:
					continue
				_visit[c] = _visit_stamp
				var k: int = _cell_head[c]
				while k != -1:
					var j: int = k
					k = _next[k]
					var q: Vector3 = pos[j]
					var mx: float = q.x - origin.x
					var mz: float = q.z - origin.z
					var tc: float = mx * d.x + mz * d.z
					if tc < -hr:
						continue
					var perp2: float = mx * mx + mz * mz - tc * tc
					if perp2 > hr2:
						continue
					var th: float = maxf(tc - sqrt(hr2 - perp2), 0.0)
					if th < best_t:
						best_t = th
						best = j
		t += step_len
	if best != -1 and best_t > wall_t:
		return -1
	return best
