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
	# The Behemoth holds its enraged pose while it is enraged; a larger slam windup wins over it.
	view.slam_windup = 0.0
	view.boss_enraged = true
	var rage: float = _act_of(view, map, boss)
	_check(absf(rage - ZombieHordeView.ENRAGED_POSE) < 0.001, "the enraged Behemoth holds its pose (act %.3f)" % rage)
	view.slam_windup = 0.6
	_check(absf(_act_of(view, map, boss) - 0.6) < 0.001, "a slam windup past the enraged pose wins over it")
	_check(absf(_act_of(view, map, boss, true) + 1.0) < 0.001, "a stunned enraged Behemoth keeps its stagger")
	view.slam_windup = 0.0
	view.boss_enraged = false
	_check(absf(_act_of(view, map, boss)) < 0.001, "the Behemoth does not pose before it is enraged")

	# A Bloater's corpse swells over POP_TIME and bursts there; a walker's corpse lies on.
	var empty := Horde.new(map.field)
	var bloater: int = ZombieHordeView.variant_for(GameData.EnemyKind.BLOATER, 0.0)
	view.on_death(Vector4(10, 20, GameData.EnemyKind.BLOATER, 0), Vector3(10, 0, 20), Vector3.ZERO, 0.5)
	view.on_death(Vector4(12, 22, GameData.EnemyKind.WALKER, 0), Vector3(12, 0, 22), Vector3.ZERO, 0.5)
	view.draw(empty, map, 1.0, 0.0)
	var sy_0: float = view.buffer(bloater)[5]
	view.draw(empty, map, 1.0, ZombieHordeView.POP_TIME * 0.5)
	var grown: float = view.buffer(bloater)[5] / sy_0
	_check(absf(grown - (1.0 + ZombieHordeView.POP_GROWTH * 0.5)) < 0.01,
		"a Bloater's corpse swells over POP_TIME (x%.3f at half time)" % grown)
	view.draw(empty, map, 1.0, ZombieHordeView.POP_TIME * 0.5 + 0.01)
	_check(view.corpse_count() == 1, "a Bloater's corpse bursts at POP_TIME, and a walker's corpse lies on (%d left)" % view.corpse_count())

	# A Bloater killed by a headshot does not fall either: it swells on both axes, with its death at 0 (w = 4).
	view.on_death(Vector4(14, 24, GameData.EnemyKind.BLOATER, 1.0), Vector3(14, 0, 24), Vector3.ZERO, 0.5)
	view.draw(empty, map, 1.0, 0.0)
	var headless_w: float = view.buffer(bloater)[19]
	var wide_0: float = view.buffer(bloater)[0]
	view.draw(empty, map, 1.0, ZombieHordeView.POP_TIME * 0.5)
	var wide: float = view.buffer(bloater)[0] / wide_0
	_check(is_equal_approx(headless_w, 4.0) and absf(wide - (1.0 + ZombieHordeView.POP_GROWTH * 0.5)) < 0.01,
		"a headless Bloater swells on both axes and holds its standing pose (w %.1f, x%.3f)" % [headless_w, wide])

	# A Bloater's death fills bloat_pops, not explosions: its fireball and body share POP_TIME.
	var run := IslandRun.new(11)
	run.director.max_alive = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var pop_at := Vector3(40, 0, 40)
	var b: int = run.horde.add(pop_at, GameData.EnemyKind.BLOATER, rng)
	run._damage(b, 99999.0, pop_at, false, false)
	_check(run.bloat_pops.size() == 1 and run.explosions.is_empty(),
		"a Bloater's death fills bloat_pops, not explosions (%d, %d)" % [run.bloat_pops.size(), run.explosions.size()])

	view.free()
