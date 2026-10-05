extends RefCounted
## Left 4 Dead style director: measures intensity and cycles
## BUILD_UP -> PEAK -> RELAX, under an active-enemy budget (80 -> 150).

enum Phase { BUILD_UP, PEAK, RELAX }
const PHASE_NAMES: Array[String] = ["build_up", "peak", "relax"]

# --- Tunables (see README "Recomendações") ---
var run_length: float = 1500.0
var budget_start: int = 80
var budget_end: int = 150
var intensity_from_damage: float = 2.5 ## per HP lost
var intensity_from_near: float = 0.12 ## per near enemy per second
var intensity_from_no_pause: float = 0.02 ## per second-of-combat, per second
var intensity_decay: float = 6.0 ## per second while calm (< calm_near enemies near)
var calm_near: int = 3
var peak_threshold: float = 60.0
var peak_hold: float = 3.0 ## seconds at peak before relaxing
var max_build_up: float = 90.0 ## forced peak if the player never gets stressed
var relax_exit: float = 20.0 ## intensity to leave relax
var relax_min: float = 10.0
var relax_max: float = 35.0
var base_spawn_rate: float = 1.2 ## enemies/s at minute 0 in build-up
var late_spawn_rate: float = 4.0 ## enemies/s at minute 25 in build-up
var build_ramp_time: float = 60.0 ## seconds for build-up rate to double
var build_ramp_max: float = 2.0
var relax_trickle: float = 0.15 ## enemies/s during relax (keeps the world alive)
var peak_rate_mult: float = 1.0 ## spawn rate multiplier while holding the peak
var rush_every: float = 240.0 ## special event: horde rush (Screamer-style)
var rush_size: int = 30
var boss_every: float = 375.0 ## special event: The Breaker

# --- State ---
var phase: Phase = Phase.BUILD_UP
var intensity: float = 0.0
var budget: int = 80
var relax_count: int = 0
var relax_time: float = 0.0
var events: Array[String] = []
var cull_far_on_relax: bool = true ## despawn enemies not yet engaged when relax starts
var relax_started: bool = false ## true only on the step a relax begins
var _phase_time: float = 0.0
var _no_pause: float = 0.0
var _spawn_acc: float = 0.0
var _next_rush: float = 0.0
var _next_boss: float = 0.0
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 1) -> void:
	_rng.seed = seed_value
	_next_rush = rush_every
	_next_boss = boss_every


func phase_name() -> String:
	return PHASE_NAMES[phase]


## Budget grows linearly with run time: 80 at start, 150 at the end.
func budget_at(t: float) -> int:
	return int(lerpf(budget_start, budget_end, clampf(t / run_length, 0.0, 1.0)))


## Returns the enemy types to spawn this step. Never exceeds the budget.
func update(t: float, dt: float, active: int, near: int, damage: float) -> Array[String]:
	budget = budget_at(t)
	events.clear()
	relax_started = false
	_update_intensity(dt, near, damage)
	_phase_time += dt
	_update_phase()
	if phase == Phase.RELAX:
		relax_time += dt
	var wanted := 0
	match phase:
		Phase.BUILD_UP:
			var rate := lerpf(base_spawn_rate, late_spawn_rate, t / run_length)
			rate *= minf(1.0 + _phase_time / build_ramp_time, build_ramp_max) # pressure ramps inside the build-up
			_spawn_acc += rate * dt
		Phase.PEAK:
			_spawn_acc += lerpf(base_spawn_rate, late_spawn_rate, t / run_length) * peak_rate_mult * dt
		Phase.RELAX:
			_spawn_acc += relax_trickle * dt
	wanted = int(_spawn_acc)
	_spawn_acc -= wanted
	var out: Array[String] = []
	var room := budget - active
	# Special events wait for a non-relax phase (the director never breaks a relax).
	if phase != Phase.RELAX:
		if t >= _next_boss and room > 0:
			out.append("breaker")
			events.append("boss")
			_next_boss += boss_every
		if t >= _next_rush:
			wanted += rush_size
			events.append("rush")
			_next_rush += rush_every
	wanted = mini(wanted, room - out.size())
	for i in maxi(wanted, 0):
		out.append(pick_type(t))
	return out


## Composition by run time: heavier and faster types weigh more later.
func pick_type(t: float) -> String:
	var k := clampf(t / run_length, 0.0, 1.0)
	var weights := {
		"normal": lerpf(0.75, 0.40, k),
		"runner": lerpf(0.15, 0.25, k),
		"spitter": lerpf(0.07, 0.18, k),
		"brute": lerpf(0.03, 0.17, k),
	}
	if phase == Phase.PEAK: # peaks favour runners: fast, readable pressure
		weights.runner *= 1.5
	var total := 0.0
	for w: float in weights.values():
		total += w
	var r := _rng.randf() * total
	for type_name: String in weights:
		r -= float(weights[type_name])
		if r <= 0.0:
			return type_name
	return "normal"


func _update_intensity(dt: float, near: int, damage: float) -> void:
	_no_pause = _no_pause + dt if near > 0 else 0.0
	intensity += damage * intensity_from_damage
	intensity += near * intensity_from_near * dt
	intensity += _no_pause * intensity_from_no_pause * dt
	if near < calm_near and damage <= 0.0:
		intensity -= intensity_decay * dt
	intensity = clampf(intensity, 0.0, 100.0)


func _update_phase() -> void:
	match phase:
		Phase.BUILD_UP:
			if intensity >= peak_threshold or _phase_time >= max_build_up:
				_set_phase(Phase.PEAK)
		Phase.PEAK:
			if _phase_time >= peak_hold:
				_set_phase(Phase.RELAX)
				relax_count += 1
				relax_started = cull_far_on_relax
		Phase.RELAX:
			var calm := intensity <= relax_exit and _phase_time >= relax_min
			if calm or _phase_time >= relax_max:
				_set_phase(Phase.BUILD_UP)


func _set_phase(p: Phase) -> void:
	phase = p
	_phase_time = 0.0
