extends SceneTree
## The director's pacing (game/world/director.gd): the calm start, the build-up, peak and
## relax cycle, the cap, the same seed giving the same spawns.
## Pure logic with fixed seeds: no scene is built.
## Run: godot --headless --path . --script res://tests/test_director_cycle.gd

const DT: float = 0.1
const DIRECTOR_SEED: int = 7

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


## Advances `seconds` of game time with no damage and no enemies near; returns the spawns.
func _quiet(d: Director, seconds: float, alive: int = 0) -> int:
	var spawned: int = 0
	for _i in int(round(seconds / DT)):
		spawned += d.update(DT, alive, 0.0, 0)
	return spawned


## Seconds of game time, with no damage, until `d` leaves the phase `current` (capped at `limit`).
func _seconds_until_leaving(d: Director, current: Director.Phase, limit: float) -> float:
	var t: float = 0.0
	while d.phase == current and t < limit:
		d.update(DT, 0, 0.0, 0)
		t += DT
	return t


## A director in its peak: past the calm start and the build-up, then a hard hit.
func _in_peak() -> Director:
	var d := Director.new(DIRECTOR_SEED)
	_quiet(d, 7.0)  # the calm start ends at about 6 s: the build-up has begun
	d.update(DT, 0, 50.0, 0)  # 75 intensity: over the 70 peak threshold
	return d


func _initialize() -> void:
	_check_calm_start()
	_check_build_up_ends_in_peak()
	_check_peak_length()
	_check_relax_holds_while_hurt()
	_check_cap()
	_check_same_seed()
	quit(1 if _failures > 0 else 0)


func _check_calm_start() -> void:
	var d := Director.new(DIRECTOR_SEED)
	_check(d.phase == Director.Phase.RELAX, "the director starts relaxed")
	var early: int = _quiet(d, 5.0)
	_check(early == 0 and d.phase == Director.Phase.RELAX, "the first 5 s are calm, with no spawns (%d)" % early)
	_quiet(d, 2.0)
	_check(d.phase == Director.Phase.BUILD_UP, "the calm ends after about 6 s and the build-up starts")


func _check_build_up_ends_in_peak() -> void:
	var hurt := Director.new(DIRECTOR_SEED)
	_quiet(hurt, 7.0)
	hurt.update(DT, 0, 50.0, 0)
	_check(hurt.phase == Director.Phase.PEAK, "a hard hit in the build-up brings the peak at once")
	var timed := Director.new(DIRECTOR_SEED)
	_quiet(timed, 7.0)
	_quiet(timed, 36.0)  # no damage: the build-up gives way after 35 s
	_check(timed.phase == Director.Phase.PEAK, "without damage the build-up ends after 35 s")


func _check_peak_length() -> void:
	var d := _in_peak()
	var peak: float = _seconds_until_leaving(d, Director.Phase.PEAK, 60.0)
	_check(peak >= 12.0 - DT and peak <= 18.0 + DT, "a peak lasts 12 to 18 s (%.1f s)" % peak)
	_check(d.phase == Director.Phase.RELAX, "the peak gives way to the relax")


func _check_relax_holds_while_hurt() -> void:
	var d := _in_peak()
	_seconds_until_leaving(d, Director.Phase.PEAK, 60.0)  # now relaxed, with the intensity spent
	# Keep the player hurt for 20 s: the intensity stays above RELAX_INTENSITY, so the relax holds.
	for _i in int(round(20.0 / DT)):
		d.update(DT, 0, 1.0, 0)
	_check(d.phase == Director.Phase.RELAX, "the relax holds while the player is still hurt")
	# Once the damage stops, the intensity decays and the next build-up starts.
	_quiet(d, 25.0)
	_check(d.phase == Director.Phase.BUILD_UP, "the relax ends once the intensity has decayed")


func _check_cap() -> void:
	var full := _in_peak()
	var over_cap: int = 0
	for _i in 100:
		over_cap += full.update(DT, full.max_alive, 0.0, 0)
	_check(over_cap == 0, "the peak never spawns past max_alive (%d)" % over_cap)

	var build := Director.new(DIRECTOR_SEED)
	_quiet(build, 7.0)
	var built: int = 0
	for _i in 200:
		built += build.update(DT, int(build.max_alive * 0.6), 0.0, 0)
	_check(build.phase == Director.Phase.BUILD_UP and built == 0, "the build-up stops at 60 %% of max_alive (%d)" % built)

	var peak := _in_peak()
	var filled: int = 0
	for _i in 100:
		filled += peak.update(DT, 0, 0.0, 0)
	_check(filled > 0, "the peak spawns when the horde is empty (%d in 10 s)" % filled)


func _check_same_seed() -> void:
	var a := Director.new(DIRECTOR_SEED)
	var b := Director.new(DIRECTOR_SEED)
	var other := Director.new(DIRECTOR_SEED + 1)
	var same: bool = true
	var differs: bool = false
	for i in 600:
		var hit: float = 50.0 if i == 80 else 0.0
		var x: int = a.update(DT, 20, hit, 3)
		var y: int = b.update(DT, 20, hit, 3)
		var z: int = other.update(DT, 20, hit, 3)
		if x != y:
			same = false
		if x != z:
			differs = true
	_check(same, "the same seed gives the same spawns, update by update")
	_check(differs, "another seed gives other spawns")

