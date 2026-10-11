class_name PowerUps
extends RefCounted
## Drop scheduling and timers only. IslandRun applies effects; the scene draws.

var rng := RandomNumberGenerator.new()
var ground_kind: StringName = &""
var ground_pos: Vector3 = Vector3.ZERO
var ground_time: float = 0.0
var next_drop_at: float = GameData.POWER_UP_DROP_INTERVAL
var kills_without_drop: int = 0
var insta_time: float = 0.0
var double_time: float = 0.0
var spawn_delay: float = 0.0


func _init(seed_value: int = 7) -> void:
	rng.seed = seed_value ^ 0x504f5745


func tick(dt: float) -> void:
	insta_time = maxf(0.0, insta_time - dt)
	double_time = maxf(0.0, double_time - dt)
	spawn_delay = maxf(0.0, spawn_delay - dt)
	ground_time = maxf(0.0, ground_time - dt)
	if ground_time <= 0.0:
		ground_kind = &""


func blinking_visible() -> bool:
	return ground_time > GameData.POWER_UP_BLINK_SECONDS or int(ground_time * 4.0) % 2 == 0


## Cooldown and an occupied ground slot never consume random numbers.
## Pity accumulates during the cooldown, then waits for a valid kill site.
func on_kill(kind: int, at: Vector3, now: float, field: FlowField,
		play_area: PackedVector2Array, finite_weapon: bool) -> bool:
	kills_without_drop += 1
	if ground_kind != &"" or now < next_drop_at:
		return false
	var spot: Vector3 = drop_position(at, field, play_area)
	if not spot.is_finite():
		return false
	var chance: float = GameData.POWER_UP_CHANCE if GameData.power_up_normal(kind) else GameData.POWER_UP_SPECIAL_CHANCE
	if kills_without_drop < GameData.POWER_UP_PITY_KILLS and rng.randf() >= chance:
		return false
	ground_kind = pick_kind(finite_weapon)
	ground_pos = spot
	ground_time = GameData.POWER_UP_GROUND_SECONDS
	next_drop_at = now + GameData.POWER_UP_DROP_INTERVAL
	kills_without_drop = 0
	return true


## Which power-up drops, by the `weight` of each .tres. All weights equal
## keeps the uniform draw (and the same random sequence as before weights).
func pick_kind(finite_weapon: bool) -> StringName:
	var pool: Array[StringName] = []
	var weights := PackedFloat32Array()
	for id: StringName in GameData.power_up_ids():
		var d: PowerUpData = GameData.power_up(id)
		if d.weight <= 0.0 or (d.requires_finite_weapon and not finite_weapon):
			continue
		pool.append(id)
		weights.append(d.weight)
	if pool.is_empty():
		return &""
	var uniform: bool = true
	for w in weights:
		uniform = uniform and is_equal_approx(w, weights[0])
	if uniform:
		return pool[rng.randi_range(0, pool.size() - 1)]
	return pool[rng.rand_weighted(weights)]


## Nearest safe cell within 3 m of the kill, using the current navigation
## field. Unreachable or not-yet-computed cells fail closed (no remote drop).
static func drop_position(at: Vector3, field: FlowField, play_area: PackedVector2Array) -> Vector3:
	var best := Vector3(INF, INF, INF)
	var nearest: float = INF
	var cell: Vector2i = field.world_to_cell(at)
	var reach: int = ceili(3.0 / field.cell_size)
	for z in range(cell.y - reach, cell.y + reach + 1):
		for x in range(cell.x - reach, cell.x + reach + 1):
			var p: Vector3 = field.cell_center(Vector2i(x, z))
			var d: float = Vector2(p.x - at.x, p.z - at.z).length_squared()
			if d > 9.0 or d >= nearest or field.distance_at(p) >= FlowField.UNREACHABLE:
				continue
			if Horde.overlaps_wall(field, p.x, p.z, GameData.PLAYER_RADIUS):
				continue
			if not play_area.is_empty() and not Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), play_area):
				continue
			nearest = d
			best = p
	return best


## Only active effects and scheduling cross islands; ground items stay behind.
func snapshot() -> Dictionary:
	return {"rng_state": rng.state, "next_drop_at": next_drop_at, "pity": kills_without_drop,
		"insta": insta_time, "double": double_time, "spawn_delay": spawn_delay}


func restore(data: Dictionary) -> void:
	# Ground items belong to the old island, including when reusing this object.
	ground_kind = &""
	ground_time = 0.0
	if data.is_empty():
		return
	rng.state = int(data["rng_state"])
	next_drop_at = float(data["next_drop_at"])
	kills_without_drop = int(data["pity"])
	insta_time = float(data["insta"])
	double_time = float(data["double"])
	spawn_delay = float(data["spawn_delay"])
