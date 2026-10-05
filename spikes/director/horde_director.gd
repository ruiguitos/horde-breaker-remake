extends RefCounted
## Left 4 Dead style horde director (headless model, no scene).
##
## Intensity (0..100) measures how stressed the player is:
##   + damage received, + enemies engaged near the player,
##   + time spent without a relax phase; decays when the player is safe.
## The director cycles BUILD_UP -> PEAK -> RELAX based on that intensity:
##   BUILD_UP: spawn pressure ramps toward the active budget.
##   PEAK:     full budget plus special events (horde call, boss).
##   RELAX:    no spawns until intensity drops (or a max time passes).
## The active budget grows with run progress from budget_start to budget_end
## and is a hard cap: spawn() never returns more than budget - active.

const EnemyTypes := preload("res://spikes/director/enemy_types.gd")

enum Phase { BUILD_UP, PEAK, RELAX }
const PHASE_NAMES: Array[String] = ["build_up", "peak", "relax"]

# --- Tunables (see README "Recomendações de parâmetros") ---
var run_length := 1500.0
var budget_start := 80
var budget_end := 150
var spawn_rate_build := 3.0  # enemies/s at the start of a build-up
var spawn_rate_peak := 12.0  # enemies/s during peak
var build_ramp_time := 60.0  # s for build-up to go from 50% to 100% of budget
var build_max := 100.0  # force a peak after this long in build-up
var peak_threshold := 70.0  # intensity that triggers a peak
var peak_duration := 20.0
var relax_min := 15.0
var relax_max := 45.0
var relax_exit := 30.0  # intensity below which relax may end
var k_damage := 0.8  # intensity per HP lost
var k_engaged := 0.15  # intensity per engaged enemy per second
var k_no_relax := 0.12  # intensity per second outside relax
var decay_relax := 3.0  # intensity decay per second in relax
var decay_safe := 1.5  # decay per second when not hurt and nobody engaged
var horde_call_size := 25
var boss_every := 300.0
# Adaptive pacing: spawn rate is capped at the player's measured kill rate
# times this factor (build-up / peak). >1 means "a bit more than you can clear".
var kill_margin_build := 1.2
var kill_margin_peak := 1.6
var kill_rate_floor := 1.0  # enemies/s allowed even if the player kills nothing
var kill_rate_smoothing := 10.0  # s, time constant of the kill-rate average

# --- State ---
var phase: Phase = Phase.BUILD_UP
var intensity := 0.0
var phase_time := 0.0
var event := ""
var relax_count := 0
var _spawn_accum := 0.0
var _boss_pending := false
var _next_boss := 300.0
var kill_rate := 2.0  # measured, enemies/s (exponential moving average)
var _last_active := 0
var _last_spawned := 0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	_next_boss = boss_every


func phase_name() -> String:
	return PHASE_NAMES[phase]


func budget(t: float) -> int:
	return int(round(lerpf(budget_start, budget_end, clampf(t / run_length, 0.0, 1.0))))


## Advances the director. Returns the enemy type indices to spawn this tick.
## active: enemies alive; engaged: enemies close enough to hurt the player;
## damage: HP the player lost this tick.
func update(t: float, dt: float, active: int, engaged: int, damage: float) -> Array[int]:
	event = ""
	# Kills since last tick = what was there + what we added - what is left.
	var killed := maxi(0, _last_active + _last_spawned - active)
	kill_rate += (killed / dt - kill_rate) * clampf(dt / kill_rate_smoothing, 0.0, 1.0)
	_update_intensity(dt, engaged, damage)
	phase_time += dt
	if t >= _next_boss:
		_boss_pending = true
		_next_boss += boss_every

	var spawns: Array[int] = []
	var cap := budget(t)
	var progress := t / run_length

	match phase:
		Phase.BUILD_UP:
			if intensity >= peak_threshold or phase_time >= build_max:
				_enter(Phase.PEAK)
				event = "peak"
				_burst(spawns, t, active, progress)
			else:
				var ramp := clampf(0.5 + 0.5 * phase_time / build_ramp_time, 0.5, 1.0)
				var rate := lerpf(spawn_rate_build, spawn_rate_peak, ramp - 0.5)
				rate = minf(rate, maxf(kill_rate_floor, kill_rate * kill_margin_build))
				_trickle(spawns, dt, rate, int(cap * ramp), active, progress)
		Phase.PEAK:
			if phase_time >= peak_duration:
				_enter(Phase.RELAX)
				relax_count += 1
				event = "relax"
			else:
				var rate := minf(spawn_rate_peak, maxf(kill_rate_floor, kill_rate * kill_margin_peak))
				_trickle(spawns, dt, rate, cap, active, progress)
		Phase.RELAX:
			var calm := intensity <= relax_exit and phase_time >= relax_min
			if calm or phase_time >= relax_max:
				_enter(Phase.BUILD_UP)
				event = "build_up"
	assert(active + spawns.size() <= cap)
	_last_active = active
	_last_spawned = spawns.size()
	return spawns


func _update_intensity(dt: float, engaged: int, damage: float) -> void:
	intensity += damage * k_damage + engaged * k_engaged * dt
	if phase != Phase.RELAX:
		intensity += k_no_relax * dt
	if phase == Phase.RELAX:
		intensity -= decay_relax * dt
	elif damage <= 0.0 and engaged == 0:
		intensity -= decay_safe * dt
	intensity = clampf(intensity, 0.0, 100.0)


func _enter(p: Phase) -> void:
	phase = p
	phase_time = 0.0
	_spawn_accum = 0.0


## Spawns at `rate`/s toward `target`, never above the hard budget.
func _trickle(out: Array[int], dt: float, rate: float, target: int, active: int, progress: float) -> void:
	_spawn_accum += rate * dt
	var room := target - active - out.size()
	while _spawn_accum >= 1.0 and room > 0:
		out.append(EnemyTypes.pick(_rng, progress))
		_spawn_accum -= 1.0
		room -= 1
	_spawn_accum = minf(_spawn_accum, 1.0)  # no backlog bursts after being capped


## Peak entry: special events. Boss first (it is the climax), then a
## Screamer-style horde call, both clipped by the remaining budget.
func _burst(out: Array[int], t: float, active: int, progress: float) -> void:
	var room := budget(t) - active
	if _boss_pending and room > 0:
		out.append(EnemyTypes.BOSS)
		_boss_pending = false
		event = "peak+boss"
		room -= 1
	var n := mini(horde_call_size, room)
	for i in n:
		out.append(EnemyTypes.pick(_rng, progress))
	if n > 0:
		event += "+horde_call"
