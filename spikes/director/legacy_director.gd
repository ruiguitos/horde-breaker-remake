extends RefCounted
## Original Horde Breaker director (docs/legacy/GDD.md, "Inimigos"):
## escalation only by time. Level 1 lasts 110 s, converging to 75 s by level 5.
## Each level adds enemies, heavier types and faster spawns; boss every
## 5 levels; global cap of 90 active enemies. No intensity, no relax.
## Same interface as horde_director.gd so the simulation can swap them.

const EnemyTypes := preload("res://spikes/director/enemy_types.gd")

var run_length := 1500.0
var cap := 90
var level := 1
var intensity := 0.0  # not used by this director; kept for the CSV
var event := ""
var relax_count := 0
var _level_end := 110.0
var _spawn_accum := 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func phase_name() -> String:
	return "level_%d" % level


func budget(_t: float) -> int:
	return cap


static func level_duration(lv: int) -> float:
	return lerpf(110.0, 75.0, clampf((lv - 1) / 4.0, 0.0, 1.0))


func update(t: float, dt: float, active: int, _engaged: int, _damage: float) -> Array[int]:
	event = ""
	var spawns: Array[int] = []
	if t >= _level_end:
		level += 1
		_level_end += level_duration(level)
		event = "level_up"
		if level % 5 == 0 and active < cap:
			spawns.append(EnemyTypes.BOSS)
			event = "level_up+boss"
	var target := mini(cap, 20 + 12 * level)
	var rate := 1.0 + 0.5 * level
	_spawn_accum += rate * dt
	var progress := t / run_length
	var heavy := 0.15 * (level - 1)
	while _spawn_accum >= 1.0 and active + spawns.size() < target:
		spawns.append(EnemyTypes.pick(_rng, progress, heavy))
		_spawn_accum -= 1.0
	_spawn_accum = minf(_spawn_accum, 1.0)
	return spawns
