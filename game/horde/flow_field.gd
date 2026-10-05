class_name FlowField
extends RefCounted
## Grid flow field (one value per cell) pointing every free cell towards a target.
##
## Distances come from a 4-neighbour BFS over free cells. The direction for a
## cell is derived lazily (and cached) from the lowest-distance neighbour among
## 8, never cutting wall corners.
##
## Recomputing can be time-sliced: request_target() starts a new BFS into a
## back buffer, step(budget) expands at most `budget` cells, and when the BFS
## finishes the buffers swap. Agents keep using the old field meanwhile, so a
## recompute never causes a frame spike.

const UNREACHABLE: int = 0x3fffffff

const _DIRS_X: Array[int] = [1, -1, 0, 0, 1, 1, -1, -1]
const _DIRS_Z: Array[int] = [0, 0, 1, -1, 1, -1, 1, -1]

var width: int
var height: int
var cell_size: float
## 1 = wall, 0 = free. Index = z * width + x.
var blocked: PackedByteArray
## Active distance field (in cells).
var dist: PackedInt32Array
var target_cell: Vector2i = Vector2i(-1, -1)
var is_computing: bool = false

var _pending_dist: PackedInt32Array
var _pending_target: Vector2i = Vector2i(-1, -1)
var _queue: PackedInt32Array
var _q_head: int = 0
var _q_tail: int = 0

# Direction cache: a cell's direction is valid when its stamp equals _version.
var _dir_cache: PackedVector2Array
var _dir_stamp: PackedInt32Array
var _version: int = 1


func _init(w: int, h: int, size: float = 1.0) -> void:
	width = w
	height = h
	cell_size = size
	var n: int = w * h
	blocked.resize(n)
	blocked.fill(0)
	dist.resize(n)
	dist.fill(UNREACHABLE)
	_pending_dist.resize(n)
	_queue.resize(n)
	_dir_cache.resize(n)
	_dir_stamp.resize(n)
	_dir_stamp.fill(0)


func set_blocked_rect(x0: int, z0: int, x1: int, z1: int, value: bool = true) -> void:
	for z in range(maxi(z0, 0), mini(z1, height - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, width - 1) + 1):
			blocked[z * width + x] = 1 if value else 0


## Out-of-bounds cells count as walls.
func is_blocked(x: int, z: int) -> bool:
	if x < 0 or z < 0 or x >= width or z >= height:
		return true
	return blocked[z * width + x] != 0


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell_size), floori(p.z / cell_size))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * cell_size, 0.0, (c.y + 0.5) * cell_size)


## Starts a (time-sliced) recompute unless the target is already current/pending.
func request_target(cell: Vector2i) -> void:
	if is_computing and cell == _pending_target:
		return
	if not is_computing and cell == target_cell:
		return
	_start(cell)


## Recomputes synchronously (used at load time and by the benchmark).
func compute_now(cell: Vector2i) -> void:
	_start(cell)
	step(1 << 30)


func _start(cell: Vector2i) -> void:
	_pending_target = cell
	_pending_dist.fill(UNREACHABLE)
	_q_head = 0
	_q_tail = 0
	is_computing = true
	if not is_blocked(cell.x, cell.y):
		var idx: int = cell.y * width + cell.x
		_pending_dist[idx] = 0
		_queue[_q_tail] = idx
		_q_tail += 1


## Expands up to `budget` cells of the pending BFS. Returns true when the
## pending field finished and became the active one.
func step(budget: int) -> bool:
	if not is_computing:
		return false
	var w: int = width
	var h: int = height
	var processed: int = 0
	# Locals are faster than member access. Packed arrays are copy-on-write,
	# so the locals are written back to the members after the loop.
	var pd: PackedInt32Array = _pending_dist
	var q: PackedInt32Array = _queue
	var head: int = _q_head
	var tail: int = _q_tail
	while head < tail and processed < budget:
		var idx: int = q[head]
		head += 1
		processed += 1
		var nd: int = pd[idx] + 1
		var x: int = idx % w
		var z: int = idx / w
		# Unrolled and inlined 4-neighbour expansion: function calls and loops
		# over small arrays are the expensive part in GDScript.
		var n: int
		if x + 1 < w:
			n = idx + 1
			if blocked[n] == 0 and pd[n] == UNREACHABLE:
				pd[n] = nd
				q[tail] = n
				tail += 1
		if x > 0:
			n = idx - 1
			if blocked[n] == 0 and pd[n] == UNREACHABLE:
				pd[n] = nd
				q[tail] = n
				tail += 1
		if z + 1 < h:
			n = idx + w
			if blocked[n] == 0 and pd[n] == UNREACHABLE:
				pd[n] = nd
				q[tail] = n
				tail += 1
		if z > 0:
			n = idx - w
			if blocked[n] == 0 and pd[n] == UNREACHABLE:
				pd[n] = nd
				q[tail] = n
				tail += 1
	_pending_dist = pd
	_queue = q
	_q_head = head
	_q_tail = tail
	if _q_head < _q_tail:
		return false
	var tmp: PackedInt32Array = dist
	dist = _pending_dist
	_pending_dist = tmp
	target_cell = _pending_target
	is_computing = false
	_version += 1
	return true


## Distance (in cells) from a world position to the active target.
func distance_at(p: Vector3) -> int:
	var c: Vector2i = world_to_cell(p)
	if is_blocked(c.x, c.y):
		return UNREACHABLE
	return dist[c.y * width + c.x]


## Cell offset (x, z), each in -1..1, of the next cell towards the target from
## world position p. ZERO at the target cell or where it is unreachable.
func direction_at(p: Vector3) -> Vector2:
	var cx: int = floori(p.x / cell_size)
	var cz: int = floori(p.z / cell_size)
	if cx < 0 or cz < 0 or cx >= width or cz >= height:
		return Vector2.ZERO
	var idx: int = cz * width + cx
	if _dir_stamp[idx] == _version:
		return _dir_cache[idx]
	var result: Vector2 = _compute_direction(cx, cz)
	_dir_cache[idx] = result
	_dir_stamp[idx] = _version
	return result


func _compute_direction(cx: int, cz: int) -> Vector2:
	var d: int = dist[cz * width + cx]
	if d == 0 or d >= UNREACHABLE:
		return Vector2.ZERO
	var best: int = d
	var best_dir: Vector2 = Vector2.ZERO
	for k in 8:
		var dx: int = _DIRS_X[k]
		var dz: int = _DIRS_Z[k]
		var nx: int = cx + dx
		var nz: int = cz + dz
		if is_blocked(nx, nz):
			continue
		# Diagonals only when both orthogonal cells are free (no corner cutting).
		if dx != 0 and dz != 0 and (is_blocked(cx + dx, cz) or is_blocked(cx, cz + dz)):
			continue
		var nd: int = dist[nz * width + nx]
		if nd < best:
			best = nd
			best_dir = Vector2(dx, dz)
	return best_dir
