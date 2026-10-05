class_name HordeFlowField
extends RefCounted
## Grid flow field on the XZ plane. Cell (x, z) covers world
## [x * cell_size, (x + 1) * cell_size) on both axes; y is ignored.
##
## The field is rebuilt with a BFS from the target cell (4-neighbour distances)
## and each cell then points to its lowest-distance neighbour among 8
## (diagonals only when both orthogonal cells are free, so no corner cutting).
## Rebuilds can run on the WorkerThreadPool into a back buffer (request_target
## + poll) so the game frame never waits for them.

const UNREACHABLE: int = 0x7fffffff

var width: int
var height: int
var cell_size: float
var blocked: PackedByteArray
var dist: PackedInt32Array
var flow: PackedVector2Array
var target_cell: Vector2i = Vector2i(-1, -1)

var _task_id: int = -1
var _pending_cell: Vector2i = Vector2i(-1, -1)
var _back_dist: PackedInt32Array
var _back_flow: PackedVector2Array
var _back_target: Vector2i = Vector2i(-1, -1)


func _init(w: int, h: int, cs: float = 1.0) -> void:
	width = w
	height = h
	cell_size = cs
	blocked.resize(w * h)
	dist.resize(w * h)
	dist.fill(UNREACHABLE)
	flow.resize(w * h)


func world_to_cell(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / cell_size), floori(p.z / cell_size))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * cell_size, 0.0, (c.y + 0.5) * cell_size)


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


func index(c: Vector2i) -> int:
	return c.y * width + c.x


## Out-of-bounds counts as blocked, so the map edge is always a wall.
func is_blocked(c: Vector2i) -> bool:
	return not in_bounds(c) or blocked[index(c)] != 0


func is_blocked_world(p: Vector3) -> bool:
	return is_blocked(world_to_cell(p))


## Marks cells x0..x1, z0..z1 (inclusive, clamped to the grid).
func set_blocked_rect(x0: int, z0: int, x1: int, z1: int, value: bool = true) -> void:
	for z in range(maxi(z0, 0), mini(z1, height - 1) + 1):
		for x in range(maxi(x0, 0), mini(x1, width - 1) + 1):
			blocked[z * width + x] = 1 if value else 0


## Synchronous rebuild (blocks the caller).
func compute(target: Vector2i) -> void:
	var result: Array = _build(target)
	dist = result[0]
	flow = result[1]
	target_cell = target


## Starts a rebuild on a worker thread. If one is already running, the newest
## target is remembered and started when the current one finishes (so a
## player crossing several cells quickly only causes one extra rebuild).
func request_target(target: Vector2i) -> void:
	_pending_cell = target
	if _task_id == -1 and target != target_cell:
		_start_pending()


## Call once per frame. Swaps in a finished rebuild. Returns true on swap.
func poll() -> bool:
	if _task_id == -1 or not WorkerThreadPool.is_task_completed(_task_id):
		return false
	WorkerThreadPool.wait_for_task_completion(_task_id)
	_task_id = -1
	dist = _back_dist
	flow = _back_flow
	target_cell = _back_target
	if _pending_cell != _back_target:
		_start_pending()
	return true


func is_busy() -> bool:
	return _task_id != -1


## Blocks until every requested rebuild is finished and swapped in.
func wait() -> void:
	while _task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_task_id)
		_task_id = -1
		dist = _back_dist
		flow = _back_flow
		target_cell = _back_target
		if _pending_cell != _back_target:
			_start_pending()


func _start_pending() -> void:
	_back_target = _pending_cell
	_task_id = WorkerThreadPool.add_task(_worker.bind(_back_target), false, "flow_field")


func _worker(target: Vector2i) -> void:
	var result: Array = _build(target)
	_back_dist = result[0]
	_back_flow = result[1]


## Returns [dist, flow] for the given target. Only reads `blocked`, so it is
## safe on a worker thread as long as the map is not edited meanwhile.
func _build(target: Vector2i) -> Array:
	var n: int = width * height
	var d := PackedInt32Array()
	d.resize(n)
	d.fill(UNREACHABLE)
	var f := PackedVector2Array()
	f.resize(n)
	if is_blocked(target):
		return [d, f]

	# BFS, 4-neighbour. The queue is a preallocated int array (each cell
	# enters at most once), which is much cheaper than Array.push_back.
	var queue := PackedInt32Array()
	queue.resize(n)
	var head: int = 0
	var tail: int = 0
	var ti: int = index(target)
	d[ti] = 0
	queue[tail] = ti
	tail += 1
	var w: int = width
	while head < tail:
		var i: int = queue[head]
		head += 1
		var x: int = i % w
		var nd: int = d[i] + 1
		if x > 0 and blocked[i - 1] == 0 and d[i - 1] == UNREACHABLE:
			d[i - 1] = nd
			queue[tail] = i - 1
			tail += 1
		if x < w - 1 and blocked[i + 1] == 0 and d[i + 1] == UNREACHABLE:
			d[i + 1] = nd
			queue[tail] = i + 1
			tail += 1
		if i >= w and blocked[i - w] == 0 and d[i - w] == UNREACHABLE:
			d[i - w] = nd
			queue[tail] = i - w
			tail += 1
		if i + w < n and blocked[i + w] == 0 and d[i + w] == UNREACHABLE:
			d[i + w] = nd
			queue[tail] = i + w
			tail += 1

	# Directions: only reachable cells (the ones the BFS visited).
	var inv_sqrt2: float = 1.0 / sqrt(2.0)
	for q in range(1, tail):
		var i: int = queue[q]
		var x: int = i % w
		@warning_ignore("integer_division")
		var z: int = i / w
		var best: int = d[i]
		var bx: int = 0
		var bz: int = 0
		var l: bool = x > 0 and blocked[i - 1] == 0
		var r: bool = x < w - 1 and blocked[i + 1] == 0
		var u: bool = z > 0 and blocked[i - w] == 0
		var dn: bool = z < height - 1 and blocked[i + w] == 0
		if l and d[i - 1] < best:
			best = d[i - 1]; bx = -1; bz = 0
		if r and d[i + 1] < best:
			best = d[i + 1]; bx = 1; bz = 0
		if u and d[i - w] < best:
			best = d[i - w]; bx = 0; bz = -1
		if dn and d[i + w] < best:
			best = d[i + w]; bx = 0; bz = 1
		# Diagonals win ties-by-2 (they skip a step), giving 45° movement.
		if l and u and blocked[i - w - 1] == 0 and d[i - w - 1] < best:
			best = d[i - w - 1]; bx = -1; bz = -1
		if r and u and blocked[i - w + 1] == 0 and d[i - w + 1] < best:
			best = d[i - w + 1]; bx = 1; bz = -1
		if l and dn and blocked[i + w - 1] == 0 and d[i + w - 1] < best:
			best = d[i + w - 1]; bx = -1; bz = 1
		if r and dn and blocked[i + w + 1] == 0 and d[i + w + 1] < best:
			best = d[i + w + 1]; bx = 1; bz = 1
		if bx != 0 and bz != 0:
			f[i] = Vector2(bx * inv_sqrt2, bz * inv_sqrt2)
		else:
			f[i] = Vector2(bx, bz)
	return [d, f]
