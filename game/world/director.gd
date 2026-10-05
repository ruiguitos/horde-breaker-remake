class_name Director
extends RefCounted
## Left 4 Dead style pacing: build up -> peak -> relax, driven by an
## "intensity" value that rises when the player is hurt or surrounded and
## decays over time. Decides how many enemies to spawn and of which kind.

enum Phase { BUILD_UP, PEAK, RELAX }

const PEAK_INTENSITY: float = 70.0
const RELAX_INTENSITY: float = 25.0

var phase: Phase = Phase.RELAX
var phase_time: float = 0.0
var intensity: float = 0.0
var elapsed: float = 0.0
var max_alive: int = GameData.MAX_ALIVE
## Multiplies the chance of Brutes and Grabbers (Elite Pack modifier).
var specials_mult: float = 1.0

var _spawn_accum: float = 0.0
var _peak_length: float = 15.0
var _rng := RandomNumberGenerator.new()


func _init(rng_seed: int = 1) -> void:
	_rng.seed = rng_seed
	phase_time = 6.0  # start with a short calm so the player can look around


static func phase_name(p: Phase) -> String:
	return ["Build up", "Peak", "Relax"][p]


## Forces a peak now (e.g. when a generator is activated).
func trigger_peak(length: float = 18.0) -> void:
	_set_phase(Phase.PEAK)
	_peak_length = length


## Returns how many enemies to spawn this frame.
func update(dt: float, alive: int, damage_taken: float, enemies_near: int) -> int:
	elapsed += dt
	intensity += damage_taken * 1.5 + enemies_near * 0.4 * dt
	intensity = maxf(0.0, intensity - 6.0 * dt)
	intensity = minf(intensity, 100.0)
	match phase:
		Phase.RELAX:
			phase_time -= dt
			if phase_time <= 0.0 and intensity < RELAX_INTENSITY:
				_set_phase(Phase.BUILD_UP)
		Phase.BUILD_UP:
			phase_time += dt
			if intensity >= PEAK_INTENSITY or phase_time > 35.0:
				_set_phase(Phase.PEAK)
				_peak_length = _rng.randf_range(12.0, 18.0)
		Phase.PEAK:
			phase_time += dt
			if phase_time >= _peak_length:
				_set_phase(Phase.RELAX)
	var rate: float = 0.0  # spawns per second
	var cap: int = max_alive
	match phase:
		Phase.BUILD_UP:
			rate = lerpf(0.6, 2.5, clampf(phase_time / 30.0, 0.0, 1.0))
			cap = int(max_alive * 0.6)
		Phase.PEAK:
			rate = 4.5
		Phase.RELAX:
			rate = 0.0
	# Difficulty creeps up slowly with time.
	rate *= 1.0 + elapsed / 600.0
	_spawn_accum += rate * dt
	var n: int = int(_spawn_accum)
	_spawn_accum -= n
	return clampi(n, 0, maxi(0, cap - alive))


func _set_phase(p: Phase) -> void:
	phase = p
	phase_time = _rng.randf_range(10.0, 15.0) if p == Phase.RELAX else 0.0


func pick_kind() -> int:
	var specials: float = clampf(elapsed / 300.0, 0.0, 1.0)
	var roll: float = _rng.randf() * 100.0
	var brute: float = (2.0 + 4.0 * specials) * specials_mult
	var grabber: float = (4.0 + 5.0 * specials) * specials_mult
	var runner: float = 15.0 + 10.0 * specials
	var bloater: float = (2.0 + 3.0 * specials) * specials_mult
	var screamer: float = (1.0 + 2.0 * specials) * specials_mult
	if roll < bloater:
		return GameData.EnemyKind.BLOATER
	roll -= bloater
	if roll < screamer:
		return GameData.EnemyKind.SCREAMER
	roll -= screamer
	if roll < brute:
		return GameData.EnemyKind.BRUTE
	if roll < brute + grabber:
		return GameData.EnemyKind.GRABBER
	if roll < brute + grabber + runner:
		return GameData.EnemyKind.RUNNER
	return GameData.EnemyKind.WALKER
