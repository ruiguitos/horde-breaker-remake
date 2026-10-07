class_name Horde
extends RefCounted
## The horde as plain data (no nodes, no physics bodies), based on the
## spikes/horde_flowfield spike. Each enemy is an index into packed arrays.
## A spatial hash (linked lists per grid cell) answers "who is near here"
## for separation, attacks, the breaker and hitscan.

## Collision radius against walls and other enemies (visual size may differ).
const RADIUS: float = 0.35

var field: FlowField
var types: Array[GameData.EnemyType] = GameData.enemy_types()

var positions: PackedVector3Array = PackedVector3Array()
var velocities: PackedVector3Array = PackedVector3Array()
var speeds: PackedFloat32Array = PackedFloat32Array()
var kinds: PackedByteArray = PackedByteArray()
var hp: PackedFloat32Array = PackedFloat32Array()
var stun: PackedFloat32Array = PackedFloat32Array()
var attack_cd: PackedFloat32Array = PackedFloat32Array()
var flash: PackedFloat32Array = PackedFloat32Array()
var count: int = 0
var target: Vector3 = Vector3.ZERO

## Outputs of the last tick, read by the island.
var damage_to_player: float = 0.0
var grabbed_by: int = -1
## Position of the last enemy that hit the player (for the HUD indicator).
var damage_from: Vector3 = Vector3.ZERO

## Enemy HP multiplier (later islands are tougher).
var hp_scale: float = 1.0
var separation_strength: float = 6.0
var field_budget: int = 2000
var steering: float = 10.0

var _head: PackedInt32Array = PackedInt32Array()
var _next: PackedInt32Array = PackedInt32Array()
var _hashed: PackedInt32Array = PackedInt32Array()  ## cells written by the last rebuild_hash
var _hash_dirty: bool = true
var _stamp: PackedInt32Array = PackedInt32Array()
var _query_id: int = 0


func _init(flow_field: FlowField) -> void:
	field = flow_field
	_head.resize(field.width * field.height)
	_head.fill(-1)


func add(pos: Vector3, kind: int, rng: RandomNumberGenerator) -> int:
	var t: GameData.EnemyType = types[kind]
	positions.append(Vector3(pos.x, 0.0, pos.z))
	velocities.append(Vector3.ZERO)
	speeds.append(rng.randf_range(t.speed_min, t.speed_max))
	kinds.append(kind)
	hp.append(t.hp * hp_scale)
	stun.append(0.0)
	attack_cd.append(rng.randf_range(0.0, t.attack_interval))
	flash.append(0.0)
	_next.append(-1)
	_stamp.append(0)
	count += 1
	_hash_dirty = true
	return count - 1


## O(1) removal: the last enemy takes index i. Callers that keep indices must
## remove from the highest index down.
func remove(i: int) -> void:
	var last: int = count - 1
	positions[i] = positions[last]
	velocities[i] = velocities[last]
	speeds[i] = speeds[last]
	kinds[i] = kinds[last]
	hp[i] = hp[last]
	stun[i] = stun[last]
	attack_cd[i] = attack_cd[last]
	flash[i] = flash[last]
	positions.resize(last)
	velocities.resize(last)
	speeds.resize(last)
	kinds.resize(last)
	hp.resize(last)
	stun.resize(last)
	attack_cd.resize(last)
	flash.resize(last)
	_next.resize(last)
	_stamp.resize(last)
	count = last
	if grabbed_by == i:
		grabbed_by = -1
	elif grabbed_by == last:
		grabbed_by = i
	_hash_dirty = true


func set_target(p: Vector3) -> void:
	target = Vector3(p.x, 0.0, p.z)
	field.request_target(field.world_to_cell(target))


func rebuild_hash() -> void:
	# Clear only the cells used last time: filling the whole grid every tick
	# costs milliseconds on a 1.5 km island.
	for cell in _hashed:
		_head[cell] = -1
	_hashed.resize(count)
	var w: int = field.width
	var cs: float = field.cell_size
	for i in count:
		var p: Vector3 = positions[i]
		var cell: int = floori(p.z / cs) * w + floori(p.x / cs)
		_next[i] = _head[cell]
		_head[cell] = i
		_hashed[i] = cell
	_hash_dirty = false


func tick(dt: float) -> void:
	if field.is_computing:
		field.step(field_budget)
	if _hash_dirty:
		rebuild_hash()
	damage_to_player = 0.0
	var w: int = field.width
	var h: int = field.height
	var cs: float = field.cell_size
	var min_d: float = RADIUS * 2.0
	var min_d2: float = min_d * min_d
	var target_cell: Vector2i = field.target_cell
	var blend: float = minf(1.0, steering * dt)
	var max_step: float = cs * 0.45
	var reach: float = GameData.ATTACK_REACH + GameData.PLAYER_RADIUS
	for i in count:
		var p: Vector3 = positions[i]
		var t: GameData.EnemyType = types[kinds[i]]
		flash[i] = maxf(0.0, flash[i] - dt)
		var tx: float = target.x - p.x
		var tz: float = target.z - p.z
		var to_target2: float = tx * tx + tz * tz
		var desired := Vector3.ZERO
		if stun[i] > 0.0:
			stun[i] -= dt
		else:
			# Attack when in reach; otherwise follow the flow field.
			attack_cd[i] -= dt
			if to_target2 <= reach * reach:
				if attack_cd[i] <= 0.0:
					attack_cd[i] = t.attack_interval
					damage_to_player += t.damage
					damage_from = p
					if t.grabs and grabbed_by == -1:
						grabbed_by = i
			else:
				var cx: int = floori(p.x / cs)
				var cz: int = floori(p.z / cs)
				var dir := Vector2.ZERO
				if Vector2i(cx, cz) == target_cell:
					dir = Vector2(tx, tz).normalized()
				else:
					# Steer at the centre of the next cell: keeps enemies off wall corners.
					var step: Vector2 = field.direction_at(p)
					if step != Vector2.ZERO:
						dir = Vector2((cx + step.x + 0.5) * cs - p.x, (cz + step.y + 0.5) * cs - p.z).normalized()
				desired = Vector3(dir.x, 0.0, dir.y) * speeds[i]
				# Ranged specials back off instead of closing in.
				if t.keep_away > 0.0 and to_target2 < t.keep_away * t.keep_away:
					desired = -Vector3(tx, 0.0, tz).normalized() * speeds[i]
		# Separation against the 3x3 neighbouring hash cells.
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
								push_x += 0.05 if i < j else -0.05
					j = _next[j]
		var v: Vector3 = velocities[i].lerp(desired, blend)
		velocities[i] = v
		var mx: float = (v.x + push_x * separation_strength) * dt
		var mz: float = (v.z + push_z * separation_strength) * dt
		var m2: float = mx * mx + mz * mz
		if m2 > max_step * max_step:
			var s: float = max_step / sqrt(m2)
			mx *= s
			mz *= s
		positions[i] = move_against_walls(field, p, mx, mz, RADIUS)
	rebuild_hash()


## Axis-separated move: slides along walls, never enters them.
static func move_against_walls(f: FlowField, p: Vector3, mx: float, mz: float, r: float) -> Vector3:
	var nx: float = p.x + mx
	if not overlaps_wall(f, nx, p.z, r):
		p.x = nx
	var nz: float = p.z + mz
	if not overlaps_wall(f, p.x, nz, r):
		p.z = nz
	return p


static func overlaps_wall(f: FlowField, x: float, z: float, r: float) -> bool:
	var cs: float = f.cell_size
	var x0: int = floori((x - r) / cs)
	var x1: int = floori((x + r) / cs)
	var z0: int = floori((z - r) / cs)
	var z1: int = floori((z + r) / cs)
	return f.is_blocked(x0, z0) or f.is_blocked(x1, z0) or f.is_blocked(x0, z1) or f.is_blocked(x1, z1)


## Pushes enemy i away from `from` by `dist` metres (in small wall-safe steps).
func knock_back(i: int, from: Vector3, dist: float) -> void:
	if not types[kinds[i]].pushable:
		return
	var p: Vector3 = positions[i]
	var d := Vector2(p.x - from.x, p.z - from.z)
	if d.length_squared() < 0.0001:
		d = Vector2(1, 0)
	d = d.normalized()
	var remaining: float = dist
	while remaining > 0.0:
		var s: float = minf(remaining, 0.4)
		p = move_against_walls(field, p, d.x * s, d.y * s, RADIUS)
		remaining -= s
	positions[i] = p
	_hash_dirty = true


## Indices of enemies whose centre is within `radius` of p.
func query_radius(p: Vector3, radius: float) -> PackedInt32Array:
	if _hash_dirty:
		rebuild_hash()
	var out := PackedInt32Array()
	var cs: float = field.cell_size
	var reach: int = ceili(radius / cs)
	var cx: int = floori(p.x / cs)
	var cz: int = floori(p.z / cs)
	var r2: float = radius * radius
	for z in range(maxi(cz - reach, 0), mini(cz + reach + 1, field.height)):
		for x in range(maxi(cx - reach, 0), mini(cx + reach + 1, field.width)):
			var j: int = _head[z * field.width + x]
			while j != -1:
				var q: Vector3 = positions[j]
				if (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) <= r2:
					out.append(j)
				j = _next[j]
	return out


## Enemies hit by a ray on the XZ plane, nearest first, up to `max_hits`.
## Walls stop the ray. Returns an array of Vector2(distance, index).
func hitscan(origin: Vector3, direction: Vector3, max_dist: float, max_hits: int = 1) -> Array[Vector2]:
	if _hash_dirty:
		rebuild_hash()
	var hits: Array[Vector2] = []
	var d := Vector2(direction.x, direction.z)
	if d.length_squared() < 0.000001:
		return hits
	d = d.normalized()
	var o := Vector2(origin.x, origin.z)
	var cs: float = field.cell_size
	var w: int = field.width
	var h: int = field.height
	var r2: float = RADIUS * RADIUS * 1.6  # slightly generous hit radius
	_query_id += 1
	var qid: int = _query_id
	var limit: float = max_dist
	var cx: int = floori(o.x / cs)
	var cz: int = floori(o.y / cs)
	var step_x: int = 1 if d.x > 0.0 else -1
	var step_z: int = 1 if d.y > 0.0 else -1
	var t_delta_x: float = absf(cs / d.x) if d.x != 0.0 else INF
	var t_delta_z: float = absf(cs / d.y) if d.y != 0.0 else INF
	var t_max_x: float = INF
	if d.x != 0.0:
		t_max_x = ((cx + (1 if step_x > 0 else 0)) * cs - o.x) / d.x
	var t_max_z: float = INF
	if d.y != 0.0:
		t_max_z = ((cz + (1 if step_z > 0 else 0)) * cs - o.y) / d.y
	var t_enter: float = 0.0
	# Cut-off: once we have max_hits, stop when cells start past the farthest one.
	var worst: float = INF
	while t_enter <= limit and t_enter <= worst:
		if field.is_blocked(cx, cz):
			limit = minf(limit, t_enter)
			break
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
						var t: float = -1.0
						if c <= 0.0:
							t = 0.0
						elif b < 0.0 and b * b - c >= 0.0:
							t = -b - sqrt(b * b - c)
						if t >= 0.0 and t <= max_dist:
							hits.append(Vector2(t, j))
							if hits.size() >= max_hits:
								hits.sort()
								hits.resize(max_hits)
								worst = hits[max_hits - 1].x
					j = _next[j]
		if t_max_x < t_max_z:
			t_enter = t_max_x
			t_max_x += t_delta_x
			cx += step_x
		else:
			t_enter = t_max_z
			t_max_z += t_delta_z
			cz += step_z
	hits.sort()
	var out: Array[Vector2] = []
	for hit in hits:
		if hit.x <= limit and out.size() < max_hits:
			out.append(hit)
	return out
