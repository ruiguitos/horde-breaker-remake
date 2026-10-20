extends SceneTree
## The specials act out their real actions (docs/tech/SPECIAL_ENEMY_MODELS.md):
## a Screamer holds its call pose for SCREAM_POSE_TIME after calling the horde,
## and the Behemoth winds up its slam. Both use the lunge channel (the instance
## custom slot `act`), so the stagger of a stunned enemy still wins.
## Run: godot --headless --path . --script res://tests/test_special_poses.gd

const ACT_SLOT: int = ZombieHordeView.STRIDE - 2  ## custom = phase, walk, act, flinch

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run()
	quit(1 if _failures > 0 else 0)


## Draws one enemy of `kind` alone and returns its `act` (NAN if not drawn).
func _act_of(view: ZombieHordeView, map: IslandMap, kind: int, stunned: bool = false) -> float:
	var h := Horde.new(map.field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var i: int = h.add(Vector3(10, 0, 20), kind, rng)
	h.speeds[i] = 1.7
	h.velocities[i] = Vector3(0, 0, 2)
	h.target = Vector3(20, 0, 50)
	if stunned:
		h.stun[i] = 1.0
	view.draw(h, map, 1.0, 0.0)
	for node: Node in view.get_children():
		var instance := node as MultiMeshInstance3D
		if instance != null and instance.multimesh.visible_instance_count == 1:
			return instance.multimesh.buffer[ACT_SLOT]
	return NAN


func _run() -> void:
	var view := ZombieHordeView.new()
	root.add_child(view)
	var map := IslandMap.new()
	map.field = FlowField.new(64, 64)
	var screamer: int = GameData.EnemyKind.SCREAMER
	var boss: int = GameData.EnemyKind.BOSS

	view.scream_age = 0.0
	var at_call: float = _act_of(view, map, screamer)
	_check(absf(at_call - 1.0) < 0.001, "a Screamer poses its call the moment it calls the horde (act %.3f)" % at_call)
	view.scream_age = 0.4
	var half: float = _act_of(view, map, screamer)
	_check(absf(half - 0.5) < 0.01, "the call pose fades over 0.8 s, half way at 0.4 s (act %.3f)" % half)
	view.scream_age = 0.8
	_check(absf(_act_of(view, map, screamer)) < 0.001, "the call pose is gone after 0.8 s")
	view.scream_age = 99.0
	_check(absf(_act_of(view, map, screamer)) < 0.001, "a Screamer that has not called anything does not pose")

	view.scream_age = 0.0
	_check(absf(_act_of(view, map, screamer, true) + 1.0) < 0.001,
		"a stunned Screamer keeps its stagger, not the call pose")
	view.scream_age = 99.0

	view.slam_windup = 0.6
	var windup: float = _act_of(view, map, boss)
	_check(absf(windup - 0.6) < 0.001, "the Behemoth winds up its slam over the windup (act %.3f)" % windup)
	view.slam_windup = 0.0
	_check(absf(_act_of(view, map, boss)) < 0.001, "the Behemoth stands still between slams")

	view.scream_age = 0.0
	view.slam_windup = 0.6
	_check(absf(_act_of(view, map, GameData.EnemyKind.BRUTE)) < 0.001,
		"other kinds ignore the call and the windup")
	view.free()
