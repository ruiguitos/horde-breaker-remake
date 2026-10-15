class_name ZombieHordeView
extends Node3D
## Draws the common zombies of the horde with ZombieModel: one MultiMesh per
## variant, filled from the Horde arrays in one packed buffer per frame (no
## nodes per zombie). The pose (walk, lunge, flinch, fall) is computed in
## zombie.gdshader from four numbers per instance (INSTANCE_CUSTOM); the
## instance colour carries the status tint index and the zombie's look
## (ZombieModel.roll_look: outfit colours, pattern, missing part, build,
## blood), rolled once per zombie and cached. Visual only: positions,
## heights and headshots still come from Horde / IslandRun.
##
## Common zombies and the six specials share batching, status and corpse handling.

## Enemy kinds drawn with ZombieModel (the Walker = the "Zombie normal" of the GDD).
const Specials = preload("res://game/world/special_enemy_model.gd")
const KINDS: Array[int] = [GameData.EnemyKind.WALKER, GameData.EnemyKind.RUNNER, GameData.EnemyKind.BRUTE,
	GameData.EnemyKind.GRABBER, GameData.EnemyKind.BOSS, GameData.EnemyKind.BLOATER, GameData.EnemyKind.SCREAMER]
const VARIANTS: int = ZombieModel.VARIANTS + 6
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
## Looks are cached per base speed (the per-zombie key) and the cache is
## cleared past this size (a long run spawns thousands of zombies).
const MAX_LOOKS: int = 4096

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
var _last_look: PackedVector3Array = PackedVector3Array()  ## (mask, colours, wear)
var _prev_pos: PackedVector3Array = PackedVector3Array()
var _prev_info: PackedVector4Array = PackedVector4Array()
var _prev_look: PackedVector3Array = PackedVector3Array()
## Corpses: (x, y, z, yaw), (variant, sx, sy, age), look, headless flag.
var _corpse_pos: PackedVector4Array = PackedVector4Array()
var _corpse_info: PackedVector4Array = PackedVector4Array()
var _corpse_look: PackedVector3Array = PackedVector3Array()
var _corpse_headless: PackedByteArray = PackedByteArray()
## Base speed -> ZombieModel.instance_look() = (variant, mask, colours, wear).
var _looks: Dictionary = {}


func _init() -> void:
	name = "ZombieHordeView"
	_handles.resize(16)
	for k: int in KINDS:
		_handles[k] = 1
	_counts.resize(VARIANTS)
	_base.resize(VARIANTS)
	for v in VARIANTS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = ZombieModel.mesh(v) if v < ZombieModel.VARIANTS else Specials.mesh(Specials.KINDS[v - ZombieModel.VARIANTS])
		_mm.append(mm)
		var inst := MultiMeshInstance3D.new()
		inst.name = "Zombies_" + (ZombieModel.VARIANT_NAMES[v] if v < ZombieModel.VARIANTS else Specials.NAMES[v - ZombieModel.VARIANTS])
		inst.multimesh = mm
		add_child(inst)


func handles(kind: int) -> bool:
	return kind >= 0 and kind < _handles.size() and _handles[kind] != 0


static func variant_for(kind: int, key: float) -> int:
	if kind == GameData.EnemyKind.WALKER:
		return ZombieModel.variant_for(key)
	var special: int = Specials.KINDS.find(kind)
	return ZombieModel.VARIANTS + special if special >= 0 else -1


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
	_prev_look = _last_look
	_last_pos = PackedVector3Array()
	_last_info = PackedVector4Array()
	_last_look = PackedVector3Array()
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
	# Looks (and so variants) first, so each buffer is sized once. A zombie's
	# look is rolled the first time it is drawn, then read from the cache.
	var variants := PackedInt32Array()
	variants.resize(h.count)
	var looks := PackedVector4Array()
	looks.resize(h.count)
	var needed := PackedInt32Array()
	needed.resize(VARIANTS)
	for i in h.count:
		if _handles[kinds[i]] != 0:
			var key: float = speeds[i]
			var cached: Variant = _looks.get(key)
			if cached == null:
				if _looks.size() >= MAX_LOOKS:
					_looks.clear()
				cached = ZombieModel.instance_look(key)
				_looks[key] = cached
			var look: Vector4 = cached
			look.x = variant_for(kinds[i], key)
			var v: int = int(look.x)
			variants[i] = v
			looks[i] = look
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
		var status: int = ZombieModel.Status.NONE  # tint colours: ZombieModel.STATUS_TINTS
		if freeze[i] > 0.0:
			walk = 0.0
			phase = offset
			act = 0.0
			w = 0.0
			status = ZombieModel.Status.FROZEN
		else:
			if stun[i] > 0.0:
				act = -1.0
				status = ZombieModel.Status.STUNNED
			if burn[i] > 0.0:
				status = ZombieModel.Status.BURNING
			if poison[i] > 0.0:
				status = ZombieModel.Status.POISONED
			if cold[i] > 0:
				status = ZombieModel.Status.COLD
		if flash[i] > 0.0:
			status = ZombieModel.Status.FLASH
		var look: Vector4 = looks[i]
		var sx: float = t.radius_scale
		var sy: float = t.height / ZombieModel.MODEL_HEIGHT
		var gy: float = p.y if flat_ground else p.y + map.ground_y(p)
		var cy: float = cos(yaw)
		var sn: float = sin(yaw)
		# Rows of (Basis(UP, yaw) scaled by (sx, sy, sx)) | origin, then the
		# colour (status, mask, colours, wear) and the pose (custom).
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
		_all[o + 12] = status
		_all[o + 13] = look.y
		_all[o + 14] = look.z
		_all[o + 15] = look.w
		_all[o + 16] = phase
		_all[o + 17] = walk
		_all[o + 18] = act
		_all[o + 19] = w
		_last_pos.append(Vector3(p.x, gy, p.z))
		_last_info.append(Vector4(variant, sx, sy, yaw))
		_last_look.append(Vector3(look.y, look.z, look.w))
	_draw_corpses(delta)
	for v in VARIANTS:
		_mm[v].visible_instance_count = _counts[v]
		if _counts[v] > 0:
			_mm[v].buffer = buffer(v)


## A Horde death (IslandRun.deaths entry: x, z, kind, headshot) becomes a
## corpse that falls backwards, away from `from` (the player).
func on_death(d: Vector4, ground: Vector3, from: Vector3) -> void:
	if not handles(int(d.z)):
		return
	var fallback: Vector4 = ZombieModel.instance_look(d.x + d.y)
	fallback.x = variant_for(int(d.z), d.x + d.y)
	var type: GameData.EnemyType = GameData.enemy_types()[int(d.z)]
	var info := Vector4(fallback.x, type.radius_scale, type.height / ZombieModel.MODEL_HEIGHT, 0)
	var look := Vector3(fallback.y, fallback.z, fallback.w)
	var best: float = 2.25  # within 1.5 m of where a zombie was drawn
	for list: int in 2:
		var pos: PackedVector3Array = _prev_pos if list == 0 else _last_pos
		var infos: PackedVector4Array = _prev_info if list == 0 else _last_info
		for k in pos.size():
			var candidate: Vector4 = infos[k]
			# Neighbours can occupy the same point. A corpse must never borrow
			# a different class's silhouette, even when its distance is zero.
			if int(d.z) == GameData.EnemyKind.WALKER:
				if int(candidate.x) >= ZombieModel.VARIANTS:
					continue
			elif int(candidate.x) != int(fallback.x):
				continue
			var q: Vector3 = pos[k]
			var d2: float = (q.x - d.x) * (q.x - d.x) + (q.z - d.y) * (q.z - d.y)
			if d2 < best:
				best = d2
				info = candidate
				look = _prev_look[k] if list == 0 else _last_look[k]
	var yaw: float = atan2(from.x - d.x, from.z - d.y)
	if _corpse_pos.size() >= MAX_CORPSES:
		_corpse_pos.remove_at(0)
		_corpse_info.remove_at(0)
		_corpse_look.remove_at(0)
		_corpse_headless.remove_at(0)
	_corpse_pos.append(Vector4(d.x, ground.y, d.y, yaw))
	_corpse_info.append(Vector4(info.x, info.y, info.z, 0.0))
	_corpse_look.append(look)
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
			_corpse_look.remove_at(c)
			_corpse_headless.remove_at(c)
		c -= 1
	for k in _corpse_pos.size():
		var cp: Vector4 = _corpse_pos[k]
		var info: Vector4 = _corpse_info[k]
		var sink: float = clampf((info.w - (CORPSE_TIME - SINK_TIME)) / SINK_TIME, 0.0, 1.0) * 0.45
		var fall: float = clampf(info.w / FALL_TIME, 0.0, 1.0)
		var w: float = (4.0 if _corpse_headless[k] != 0 else 2.0) + fall
		var look: Vector3 = _corpse_look[k]
		_write(int(info.x), Vector3(cp.x, cp.y - sink, cp.z), cp.w, info.y, info.z, Color(ZombieModel.Status.NONE, look.x, look.y, look.z), Vector4(0, 0, 0, w))


## Grows the MultiMeshes (powers of two, so it rarely happens) and lays the
## variants out in _all.
func _reserve(needed: PackedInt32Array) -> void:
	var grew: bool = false
	for v in VARIANTS:
		if _mm[v].instance_count < needed[v]:
			_mm[v].instance_count = maxi(32, nearest_po2(needed[v]))
			grew = true
	if not grew and not _all.is_empty():
		return
	var total: int = 0
	for v in VARIANTS:
		_base[v] = total
		total += _mm[v].instance_count
	_all.resize(total * STRIDE)


## `colour` = (status index, mask, colours, wear), as the shader reads COLOR.
func _write(v: int, origin: Vector3, yaw: float, sx: float, sy: float, colour: Color, custom: Vector4) -> void:
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
	_all[o + 12] = colour.r
	_all[o + 13] = colour.g
	_all[o + 14] = colour.b
	_all[o + 15] = colour.a
	_all[o + 16] = custom.x
	_all[o + 17] = custom.y
	_all[o + 18] = custom.z
	_all[o + 19] = custom.w
