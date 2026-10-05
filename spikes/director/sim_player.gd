extends RefCounted
## Very simple simulated player + enemy crowd.
## Enemies spawn far away ("approaching") and reach the player after
## ~approach_time s ("near"). Up to max_engaged near enemies can hit at once.
## The player's DPS grows with skill and run progress (weapon upgrades);
## damage received is divided by skill (dodging, positioning).

const EnemyTypes := preload("res://spikes/director/enemy_types.gd")

var skill := 1.0
var base_dps := 220.0
var upgrade_growth := 2.0  # DPS multiplier at run end = 1 + upgrade_growth
var approach_time := 8.0
var max_engaged := 8
var regen := 2.0  # HP/s when no enemy is near
var hit_scale := 0.35  # fraction of contact time an enemy actually lands hits
var max_hp := 100.0

var hp := 100.0
var deaths := 0
var kills := 0
var damage_total := 0.0
var approaching: Array[int] = []
var near: Array[int] = []
var _partial: Array[float] = []
var _rng := RandomNumberGenerator.new()


func _init(skill_value: float, seed_value: int = 1) -> void:
	skill = skill_value
	_rng.seed = seed_value
	for i in EnemyTypes.count():
		approaching.append(0)
		near.append(0)
		_partial.append(0.0)


func active() -> int:
	var n := 0
	for i in near.size():
		n += near[i] + approaching[i]
	return n


func near_count() -> int:
	var n := 0
	for c in near:
		n += c
	return n


func engaged() -> int:
	return mini(near_count(), max_engaged)


func add(types: Array[int]) -> void:
	for i in types:
		approaching[i] += 1


## Simulates dt seconds. Returns HP lost this tick.
func step(dt: float, progress: float) -> float:
	# Approach: each enemy reaches the player with probability dt/approach_time.
	for i in approaching.size():
		var arrived := 0
		for _k in approaching[i]:
			if _rng.randf() < dt / approach_time:
				arrived += 1
		approaching[i] -= arrived
		near[i] += arrived

	# Shooting: near enemies first, then approaching ones, in priority order.
	var dmg_out := base_dps * skill * (1.0 + upgrade_growth * progress) * dt
	dmg_out = _shoot(near, dmg_out)
	dmg_out = _shoot(approaching, dmg_out)

	# Damage received from engaged enemies (average dps of the near crowd).
	var n := near_count()
	var taken := 0.0
	if n > 0:
		var sum_dps := 0.0
		for i in near.size():
			sum_dps += near[i] * EnemyTypes.dps(i)
		taken = sum_dps / n * mini(n, max_engaged) * hit_scale * dt / skill
	elif hp < max_hp:
		hp = minf(max_hp, hp + regen * dt)
	hp -= taken
	damage_total += taken
	if hp <= 0.0:
		# Downed: counts a death, revives at full HP, near crowd is pushed back.
		deaths += 1
		hp = max_hp
		for i in near.size():
			approaching[i] += near[i]
			near[i] = 0
	return taken


func _shoot(pool: Array[int], dmg: float) -> float:
	for i in pool.size():
		while dmg > 0.0 and pool[i] > 0:
			var need := EnemyTypes.hp(i) - _partial[i]
			if dmg >= need:
				dmg -= need
				_partial[i] = 0.0
				pool[i] -= 1
				kills += 1
			else:
				_partial[i] += dmg
				dmg = 0.0
	return dmg
