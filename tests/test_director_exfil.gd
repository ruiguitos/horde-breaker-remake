extends SceneTree
## The director's EXFIL steps (game/world/director.gd): the step clock, the target of each step,
## the specials, and the spawns that fill the gap.
## Run: godot --headless --path . --script res://tests/test_director_exfil.gd

const DT: float = 0.1
const DIRECTOR_SEED: int = 7

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_check_exfil()
	quit(1 if _failures > 0 else 0)

func _check_exfil() -> void:
	var d := Director.new(DIRECTOR_SEED)
	d.exfil = true

	var steps: Array[int] = []
	for elapsed: float in [0.0, 89.0, 90.0, 270.0, 360.0, 900.0]:
		d.elapsed = elapsed
		steps.append(d.exfil_step())
	var expected_steps: Array[int] = [0, 0, 1, 3, 4, 4]
	_check(steps == expected_steps, "the EXFIL step climbs every 90 s and stops at %d (%s)" % [Director.EXFIL_STEPS, str(steps)])

	var targets: Array[int] = []
	for elapsed: float in [0.0, 90.0, 180.0, 270.0, 360.0, 9999.0]:
		d.elapsed = elapsed
		targets.append(d.exfil_target())
	var expected_targets: Array[int] = []
	for i in 5:
		expected_targets.append(GameData.MAX_ALIVE + Director.EXFIL_STEP_ALIVE * i)
	# 9999 s is the last step again: the target stays there, and under the horde cap.
	expected_targets.append(mini(GameData.HORDE_CAP, GameData.MAX_ALIVE + Director.EXFIL_STEP_ALIVE * 4))
	_check(targets == expected_targets, "the EXFIL target climbs %d per step, from %d, and never passes the horde cap (%s)" % [Director.EXFIL_STEP_ALIVE, GameData.MAX_ALIVE, str(targets)])

	d.elapsed = 180.0
	_check(is_equal_approx(d.specials_share(), 0.5), "in EXFIL the specials rise with the steps (2 of %d)" % Director.EXFIL_STEPS)

	d.elapsed = 0.0
	var full: int = 0
	for _i in 300:
		full += d.update(DT, GameData.MAX_ALIVE, 0.0, 0)
	_check(full == 0, "EXFIL spawns nothing once the step's target is reached (%d)" % full)

	var filling: int = 0
	for _i in 100:
		filling += d.update(DT, 100, 0.0, 0)
	_check(filling > 0, "EXFIL fills the gap to the target (%d in 10 s)" % filling)
