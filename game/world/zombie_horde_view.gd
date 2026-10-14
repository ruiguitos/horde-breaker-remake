class_name ZombieHordeView
extends Node3D
## Draws the common zombies of the horde with ZombieModel: one MultiMesh per
## variant, filled from the Horde arrays in one packed buffer per frame (no
## nodes per zombie). The pose (walk, lunge, flinch, fall) is computed in
## zombie.gdshader from four numbers per instance, so 150 zombies cost about
## what the old capsule + head + arms cost. Visual only: positions, heights
## and headshots still come from Horde / IslandRun.
##
## Kinds it does not handle (specials, the boss) keep the island's capsules.

## Enemy kinds drawn with ZombieModel (the Walker = the "Zombie normal" of the GDD).
const KINDS: Array[int] = [GameData.EnemyKind.WALKER]
## Floats per instance in MultiMesh.buffer: transform 12 + colour 4 + custom 4.
const STRIDE: int = 20
## Corpses: fall, lie, then sink into the ground.
const FALL_TIME: float = 0.8
const CORPSE_TIME: float = 5.0
const SINK_TIME: float = 1.2
const MAX_CORPSES: int = 40
## Old-capsule chunks were tinted with the kind colour; zombie chunks are flesh.
const DEBRIS_COLOR: Color = Color(0.45, 0.12, 0.1)
## Hit flash time set by IslandRun._damage (flinch scales with it).
const FLASH_TIME: float = 0.1
## A zero-size transform, for capsule instances this view draws instead.
const HIDDEN: Transform3D = Transform3D(Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO), Vector3.ZERO)

var _mm: Array[MultiMesh] = []
## All variants' instance data in one array (a packed array inside an Array
## would be copied on every write): variant v starts at _base[v] instances.
var _all: PackedFloat32Array = PackedFloat32Array()
var _base: PackedInt32Array = PackedInt32Array()
var _counts: PackedInt32Array = PackedInt32Array()
var _handles: PackedByteArray = PackedByteArray()
## This frame's zombies and the previous frame's (for corpses: by the time
## the island hears of a death, the dead one has left the horde, so its
## variant is looked up where it was last drawn).
var _last_pos: PackedVector3Array = PackedVector3Array()
var _last_info: PackedVector4Array = PackedVector4Array()  ## (variant, sx, sy, yaw)
var _prev_pos: PackedVector3Array = PackedVector3Array()
var _prev_info: PackedVector4Array = PackedVector4Array()
## Corpses: (x, y, z, yaw), (variant, sx, sy, age), headless flag.
var _corpse_pos: PackedVector4Array = PackedVector4Array()
var _corpse_info: PackedVector4Array = PackedVector4Array()
var _corpse_headless: PackedByteArray = PackedByteArray()


func _init() -> void:
	name = "ZombieHordeView"
	_handles.resize(16)
	for k: int in KINDS:
		_handles[k] = 1
	_counts.resize(ZombieModel.VARIANTS)
	_base.resize(ZombieModel.VARIANTS)
	for v in ZombieModel.VARIANTS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = ZombieModel.mesh(v)
		_mm.append(mm)
		var inst := MultiMeshInstance3D.new()
		inst.name = "Zombies_" + ZombieModel.VARIANT_NAMES[v]
		inst.multimesh = mm
		add_child(inst)


func handles(kind: int) -> bool:
	return kind >= 0 and kind < _handles.size() and _handles[kind] != 0


func instance_count(variant: int) -> int:
	return _counts[variant]


## The instance data of one variant, as sent to its MultiMesh (tests read
## poses from it).
func buffer(variant: int) -> PackedFloat32Array:
	var from: int = _base[variant] * STRIDE
	return _all.slice(from, from + _mm[variant].instance_count * STRIDE)


func corpse_count() -> int:
	return _corpse_pos.size()


## Per frame. `map` lifts positions onto the terrain; `now` drives the walk
## cycle, `delta` the corpses (0 while paused).
func draw(h: Horde, map: IslandMap, now: float, delta: float) -> void:
	_counts.fill(0)
	_prev_pos = _last_pos
	_prev_info = _last_info
	_last_pos = PackedVector3Array()
	_last_info = PackedVector4Array()
	# Local references to the horde arrays (read only: no copies) are much
	# faster in GDScript than h.positions[i] every time.
	var kinds: PackedByteArray = h.kinds
	var speeds: PackedFloat32Array = h.speeds
	var positions: PackedVector3Array = h.positions
	var velocities: PackedVector3Array = h.velocities
	var flash: PackedFloat32Array = h.flash
	var stun: PackedFloat32Array = h.stun
	var freeze: PackedFloat32Array = h.freeze_time
	var burn: PackedFloat32Array = h.burn_time
	var poison: PackedFloat32Array = h.poison_time
	var cold: PackedByteArray = h.cold_stacks
	var attack_cd: PackedFloat32Array = h.attack_cd
	var reach: float = GameData.ATTACK_REACH + GameData.PLAYER_RADIUS + 0.3
	var reach2: float = reach * reach
	var flat_ground: bool = map.heights.is_empty()
	# Variants first, so each buffer is sized once.
	var variants := PackedInt32Array()
	variants.resize(h.count)
	var needed := PackedInt32Array()
	needed.resize(ZombieModel.VARIANTS)
	for i in h.count:
		if _handles[kinds[i]] != 0:
			var v: int = ZombieModel.variant_for(speeds[i])
			variants[i] = v
			needed[v] += 1
		else:
			variants[i] = -1
	for c in _corpse_pos.size():
		needed[int(_corpse_info[c].x)] += 1
	_reserve(needed)
	for i in h.count:
		var variant: int = variants[i]
		if variant < 0:
			continue
		var t: GameData.EnemyType = h.types[kinds[i]]
		var base_speed: float = speeds[i]
		var p: Vector3 = positions[i]
		var v: Vector3 = velocities[i]
		var speed2: float = v.x * v.x + v.z * v.z
		var tx: float = h.target.x - p.x
		var tz: float = h.target.z - p.z
		var close: bool = tx * tx + tz * tz <= reach2
		var yaw: float = atan2(v.x, v.z) if speed2 > 0.09 and not close else atan2(tx, tz)
		var walk: float = minf(sqrt(speed2) / 2.5, 1.0)
		# The phase advances with the enemy's own (constant) rolled speed, so it
		# stays continuous when the horde compacts its arrays.
		var offset: float = fmod(base_speed * 977.0, TAU)
		var phase: float = offset + now * (3.0 + base_speed * 2.6)
		var act: float = 0.0
		if close:
			var since: float = t.attack_interval - attack_cd[i]
			if since >= 0.0 and since < 0.35:
				act = sin(since / 0.35 * PI)
		var w: float = minf(flash[i] / FLASH_TIME, 1.0)
		var status := Color(0, 0, 0, 0)
		if freeze[i] > 0.0:
			walk = 0.0
			phase = offset
			act = 0.0
			w = 0.0
			status = Color(0.55, 0.92, 1.0, 0.75)
		else:
			if stun[i] > 0.0:
				act = -1.0
				status = Color(1, 1, 1, 0.2)
			if burn[i] > 0.0:
				status = Color(1.0, 0.35, 0.08, 0.55)
			if poison[i] > 0.0:
				status = Color(0.65, 0.9, 0.16, 0.5)
			if cold[i] > 0:
				status = Color(0.25, 0.7, 1.0, 0.4)
		if flash[i] > 0.0:
			status = Color(1, 1, 1, 0.55)
		var sx: float = t.radius_scale
		var sy: float = t.height / ZombieModel.MODEL_HEIGHT
		var gy: float = p.y if flat_ground else p.y + map.ground_y(p)
		var cy: float = cos(yaw)
		var sn: float = sin(yaw)
		# Rows of (Basis(UP, yaw) scaled by (sx, sy, sx)) | origin, colour, custom.
		var o: int = (_base[variant] + _counts[variant]) * STRIDE
		_counts[variant] += 1
		_all[o] = cy * sx
		_all[o + 1] = 0.0
		_all[o + 2] = sn * sx
		_all[o + 3] = p.x
		_all[o + 4] = 0.0
		_all[o + 5] = sy
		_all[o + 6] = 0.0
		_all[o + 7] = gy
		_all[o + 8] = -sn * sx
		_all[o + 9] = 0.0
		_all[o + 10] = cy * sx
		_all[o + 11] = p.z
		_all[o + 12] = status.r
		_all[o + 13] = status.g
		_all[o + 14] = status.b
		_all[o + 15] = status.a
		_all[o + 16] = phase
		_all[o + 17] = walk
		_all[o + 18] = act
		_all[o + 19] = w
		_last_pos.append(Vector3(p.x, gy, p.z))
		_last_info.append(Vector4(variant, sx, sy, yaw))
	_draw_corpses(delta)
	for v in ZombieModel.VARIANTS:
		_mm[v].visible_instance_count = _counts[v]
		if _counts[v] > 0:
			_mm[v].buffer = buffer(v)


## A Horde death (IslandRun.deaths entry: x, z, kind, headshot) becomes a
## corpse that falls backwards, away from `from` (the player).
func on_death(d: Vector4, ground: Vector3, from: Vector3) -> void:
	if not handles(int(d.z)):
		return
	var info := Vector4(0, 1, 1, 0)
	var best: float = 2.25  # within 1.5 m of where a zombie was drawn
	for list: int in 2:
		var pos: PackedVector3Array = _prev_pos if list == 0 else _last_pos
		for k in pos.size():
			var q: Vector3 = pos[k]
			var d2: float = (q.x - d.x) * (q.x - d.x) + (q.z - d.y) * (q.z - d.y)
			if d2 < best:
				best = d2
				info = _prev_info[k] if list == 0 else _last_info[k]
	var yaw: float = atan2(from.x - d.x, from.z - d.y)
	if _corpse_pos.size() >= MAX_CORPSES:
		_corpse_pos.remove_at(0)
		_corpse_info.remove_at(0)
		_corpse_headless.remove_at(0)
	_corpse_pos.append(Vector4(d.x, ground.y, d.y, yaw))
	_corpse_info.append(Vector4(info.x, info.y, info.z, 0.0))
	_corpse_headless.append(1 if d.w > 0.5 else 0)


func _draw_corpses(delta: float) -> void:
	var c: int = _corpse_pos.size() - 1
	while c >= 0:
		var info: Vector4 = _corpse_info[c]
		info.w += delta
		_corpse_info[c] = info
		if info.w > CORPSE_TIME:
			_corpse_pos.remove_at(c)
			_corpse_info.remove_at(c)
			_corpse_headless.remove_at(c)
		c -= 1
	for k in _corpse_pos.size():
		var cp: Vector4 = _corpse_pos[k]
		var info: Vector4 = _corpse_info[k]
		var sink: float = clampf((info.w - (CORPSE_TIME - SINK_TIME)) / SINK_TIME, 0.0, 1.0) * 0.45
		var fall: float = clampf(info.w / FALL_TIME, 0.0, 1.0)
		var w: float = (4.0 if _corpse_headless[k] != 0 else 2.0) + fall
		_write(int(info.x), Vector3(cp.x, cp.y - sink, cp.z), cp.w, info.y, info.z, Color(0, 0, 0, 0), Vector4(0, 0, 0, w))


## Grows the MultiMeshes (powers of two, so it rarely happens) and lays the
## variants out in _all.
func _reserve(needed: PackedInt32Array) -> void:
	var grew: bool = false
	for v in ZombieModel.VARIANTS:
		if _mm[v].instance_count < needed[v]:
			_mm[v].instance_count = maxi(32, nearest_po2(needed[v]))
			grew = true
	if not grew and not _all.is_empty():
		return
	var total: int = 0
	for v in ZombieModel.VARIANTS:
		_base[v] = total
		total += _mm[v].instance_count
	_all.resize(total * STRIDE)


func _write(v: int, origin: Vector3, yaw: float, sx: float, sy: float, status: Color, custom: Vector4) -> void:
	var o: int = (_base[v] + _counts[v]) * STRIDE
	_counts[v] += 1
	var cy: float = cos(yaw)
	var sn: float = sin(yaw)
	# Rows of (Basis(UP, yaw) scaled by (sx, sy, sx)) | origin.
	_all[o] = cy * sx
	_all[o + 1] = 0.0
	_all[o + 2] = sn * sx
	_all[o + 3] = origin.x
	_all[o + 4] = 0.0
	_all[o + 5] = sy
	_all[o + 6] = 0.0
	_all[o + 7] = origin.y
	_all[o + 8] = -sn * sx
	_all[o + 9] = 0.0
	_all[o + 10] = cy * sx
	_all[o + 11] = origin.z
	_all[o + 12] = status.r
	_all[o + 13] = status.g
	_all[o + 14] = status.b
	_all[o + 15] = status.a
	_all[o + 16] = custom.x
	_all[o + 17] = custom.y
	_all[o + 18] = custom.z
	_all[o + 19] = custom.w
