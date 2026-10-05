class_name HordeMap
extends RefCounted
## Builds deterministic test maps for the spike.


## 150x150 map: border walls plus random rectangular obstacles (buildings,
## walls) kept away from the central arena so the player always has room.
static func generate(size: int = 150, rng_seed: int = 1234, obstacle_count: int = 70) -> HordeFlowField:
	var field := HordeFlowField.new(size, size, 1.0)
	field.set_blocked_rect(0, 0, size - 1, 0)
	field.set_blocked_rect(0, size - 1, size - 1, size - 1)
	field.set_blocked_rect(0, 0, 0, size - 1)
	field.set_blocked_rect(size - 1, 0, size - 1, size - 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var center: int = size / 2
	var placed: int = 0
	while placed < obstacle_count:
		var long_side: int = rng.randi_range(4, 18)
		var short_side: int = rng.randi_range(1, 6)
		var horizontal: bool = rng.randf() < 0.5
		var w: int = long_side if horizontal else short_side
		var h: int = short_side if horizontal else long_side
		var x0: int = rng.randi_range(2, size - 3 - w)
		var z0: int = rng.randi_range(2, size - 3 - h)
		# Keep a 24x24 arena free around the centre.
		if x0 + w > center - 12 and x0 < center + 12 and z0 + h > center - 12 and z0 < center + 12:
			continue
		field.set_blocked_rect(x0, z0, x0 + w - 1, z0 + h - 1)
		placed += 1
	return field


## Random free position whose cell is reachable in the active field.
static func random_free_position(field: HordeFlowField, rng: RandomNumberGenerator, margin: float = 0.4) -> Vector3:
	for attempt in 1000:
		var p := Vector3(rng.randf_range(1.0, field.width - 1.0), 0.0, rng.randf_range(1.0, field.height - 1.0))
		if HordeSim.overlaps_wall(field, p.x, p.z, margin):
			continue
		if field.distance_at(p) >= HordeFlowField.UNREACHABLE:
			continue
		return p
	return field.cell_center(field.target_cell)
