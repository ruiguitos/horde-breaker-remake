extends RefCounted
## Original Horde Breaker director: escalates by time only.
## Level duration 110 s -> 75 s (by level 5), cap of 90 active, boss every 5 levels.

const CAP := 90
var level: int = 1
var budget: int = CAP
var relax_count: int = 0 ## always 0: the original has no relief phase
var relax_time: float = 0.0
var intensity: float = 0.0 ## not used for decisions; reported for comparison
var events: Array[String] = []
var _level_time: float = 0.0
var _spawn_acc: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value


func phase_name() -> String:
	return "level_%d" % level


func level_duration(l: int) -> float:
	return lerpf(110.0, 75.0, clampf((l - 1) / 4.0, 0.0, 1.0))


func update(_t: float, dt: float, active: int, _near: int, _damage: float) -> Array[String]:
	events.clear()
	_level_time += dt
	if _level_time >= level_duration(level):
		_level_time = 0.0
		level += 1
	var target := mini(CAP, 20 + level * 8)
	var rate := 1.0 + level * 0.35 # shorter intervals as levels rise
	_spawn_acc += rate * dt
	var wanted := mini(int(_spawn_acc), target - active)
	_spawn_acc -= int(_spawn_acc)
	var out: Array[String] = []
	if level % 5 == 0 and _level_time < dt and active < CAP:
		out.append("breaker")
		events.append("boss")
	for i in maxi(mini(wanted, CAP - active - out.size()), 0):
		out.append(_pick_type())
	return out


func _pick_type() -> String:
	var heavy := clampf(level / 16.0, 0.0, 1.0)
	var r := _rng.randf()
	if r < 0.04 + 0.16 * heavy:
		return "brute"
	if r < 0.14 + 0.24 * heavy:
		return "spitter"
	if r < 0.30 + 0.30 * heavy:
		return "runner"
	return "normal"
