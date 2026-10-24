extends SceneTree
## The wind-up of a common enemy's blow (game/horde/horde.gd): the damage lands ATTACK_WINDUP
## seconds after the blow starts, if the player is still in reach then (otherwise the blow misses);
## the enemy keeps walking at WINDUP_SPEED_SHARE of its speed meanwhile; the interval and the damage
## stay as they were; a stun, a freeze, a loss of legs or a death in the middle cancels the blow;
## the Brute, the Grabber and the Bloater strike at once.
## Run: godot --headless --path . --script res://tests/test_horde_windup.gd

const DT: float = 1.0 / 60.0

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


## Ticks the horde `ticks` times and adds up the damage: the horde resets its output on every tick.
func _ticks(h: Horde, ticks: int) -> float:
	var total: float = 0.0
	for i in ticks:
		h.tick(DT)
		total += h.damage_to_player
	return total


func _run() -> void:
	var types: Array[GameData.EnemyType] = GameData.enemy_types()
	var walker: GameData.EnemyType = types[GameData.EnemyKind.WALKER]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var reach: float = GameData.ATTACK_REACH + GameData.PLAYER_RADIUS
	var target := Vector3(30, 0, 30)
	var in_reach: Vector3 = target + Vector3(reach - 0.3, 0, 0)

	# A walker in reach with its blow due: the blow starts, and no damage yet.
	var h := Horde.new(FlowField.new(60, 60))
	var w: int = h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	h.set_target(target)
	h.attack_cd[w] = 0.0
	var first: float = _ticks(h, 1)
	_check(h.windup[w] > 0.0 and first == 0.0, "a blow starts with a wind-up and no damage yet")
	# Before the wind-up is over (0.25 s) there is no damage; after it (0.33 s) the damage is in.
	_check(_ticks(h, 14) == 0.0, "no damage while the wind-up runs (0.25 s)")
	var landed: float = _ticks(h, 5)
	_check(is_equal_approx(landed, walker.damage), "the damage lands at the end of the wind-up (0.33 s): %.1f" % landed)
	# The interval is unchanged: the second blow starts one interval after the first (tick 61),
	# so at 1.1 s it is still winding up, and it lands by 1.5 s.
	_check(_ticks(h, 46) == 0.0, "the second blow is still winding up at 1.1 s")
	_check(is_equal_approx(_ticks(h, 25), walker.damage), "the second blow lands one wind-up after it starts")

	# A stun in the middle of the wind-up cancels the blow.
	var stunned_h := Horde.new(FlowField.new(60, 60))
	var sw: int = stunned_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	stunned_h.set_target(target)
	stunned_h.attack_cd[sw] = 0.0
	_ticks(stunned_h, 1)
	stunned_h.stun[sw] = 1.0
	_check(_ticks(stunned_h, 40) == 0.0 and stunned_h.windup[sw] == 0.0, "a stun in the middle of a blow cancels it")

	# A freeze in the middle of the wind-up cancels the blow.
	var frozen_h := Horde.new(FlowField.new(60, 60))
	var fw: int = frozen_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	frozen_h.set_target(target)
	frozen_h.attack_cd[fw] = 0.0
	_ticks(frozen_h, 1)
	frozen_h.freeze_time[fw] = 2.0
	_check(_ticks(frozen_h, 40) == 0.0 and frozen_h.windup[fw] == 0.0, "a freeze in the middle of a blow cancels it")

	# Losing both legs in the middle of the wind-up topples the walker: the blow is cancelled.
	var amp_h := Horde.new(FlowField.new(60, 60))
	var aw: int = amp_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	amp_h.set_target(target)
	amp_h.attack_cd[aw] = 0.0
	_ticks(amp_h, 1)
	amp_h.amputate(aw)
	_check(_ticks(amp_h, 40) == 0.0 and amp_h.windup[aw] == 0.0, "losing its legs in the middle of a blow cancels it")

	# A death in the middle of the wind-up: the blow does not come out, and the survivor
	# that moves into the dead enemy's slot keeps no blow of its own.
	var dead_h := Horde.new(FlowField.new(60, 60))
	var dying: int = dead_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	var other: int = dead_h.add(in_reach + Vector3(0, 0, 0.5), GameData.EnemyKind.WALKER, rng)
	dead_h.set_target(target)
	dead_h.attack_cd[dying] = 0.0
	dead_h.attack_cd[other] = 10.0
	_ticks(dead_h, 1)
	dead_h.remove(dying)
	_check(_ticks(dead_h, 40) == 0.0 and dead_h.count == 1 and dead_h.windup[0] == 0.0, "a blow whose enemy dies does not come out")

	# A blow whose player has stepped out of reach when it falls misses: no damage, and the
	# arms come back down.
	var missed_h := Horde.new(FlowField.new(60, 60))
	var mw: int = missed_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	missed_h.set_target(target)
	missed_h.attack_cd[mw] = 0.0
	_ticks(missed_h, 1)
	missed_h.set_target(target + Vector3(20, 0, 0))
	_check(_ticks(missed_h, 25) == 0.0 and missed_h.windup[mw] < 0.0,
		"a blow whose player has stepped out of reach when it falls misses")

	# A blow whose player is still in reach when it falls lands (the player moved 0.2 m toward the enemy).
	var stayed_h := Horde.new(FlowField.new(60, 60))
	var sy: int = stayed_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	stayed_h.set_target(target)
	stayed_h.attack_cd[sy] = 0.0
	_ticks(stayed_h, 1)
	stayed_h.set_target(target + Vector3(0.2, 0, 0))
	_check(is_equal_approx(_ticks(stayed_h, 25), walker.damage), "a blow lands if the player is still in reach when it falls")

	# A player who steps out and back into reach before the blow falls is hit: only the end counts.
	var back_h := Horde.new(FlowField.new(60, 60))
	var bk: int = back_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	back_h.set_target(target)
	back_h.attack_cd[bk] = 0.0
	_ticks(back_h, 1)
	back_h.set_target(target + Vector3(20, 0, 0))
	_ticks(back_h, 5)
	back_h.set_target(target)
	_check(is_equal_approx(_ticks(back_h, 20), walker.damage), "a player who steps back into reach before the blow falls is hit")

	# A miss does not touch the cooldown: it is the same as after a blow that landed.
	_check(is_equal_approx(missed_h.attack_cd[mw], stayed_h.attack_cd[sy]) and missed_h.attack_cd[mw] > 0.0,
		"a missed blow leaves the cooldown as it is (%.2f s left, as after a hit)" % missed_h.attack_cd[mw])

	# A blow on its way does not stop the enemy: it walks from the first tick of the blow...
	var first_h := Horde.new(FlowField.new(60, 60))
	var fk: int = first_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	first_h.set_target(target)
	first_h.field.compute_now(first_h.field.world_to_cell(target))
	first_h.attack_cd[fk] = 0.0
	var before_first: Vector3 = first_h.positions[fk]
	_ticks(first_h, 1)
	_check(first_h.windup[fk] > 0.0 and first_h.positions[fk] != before_first, "the enemy starts walking on the first tick of its blow")

	# ...and keeps walking at WINDUP_SPEED_SHARE of its speed. The blow is held on its way for the
	# measurement, so the walk settles at its steady pace.
	var walk_h := Horde.new(FlowField.new(60, 60))
	var ww: int = walk_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	walk_h.set_target(target)
	walk_h.field.compute_now(walk_h.field.world_to_cell(target))
	walk_h.attack_cd[ww] = 0.0
	_ticks(walk_h, 1)
	walk_h.windup[ww] = 10.0
	_ticks(walk_h, 20)
	var from: Vector3 = walk_h.positions[ww]
	_ticks(walk_h, 20)
	var walked: float = Vector2(walk_h.positions[ww].x - from.x, walk_h.positions[ww].z - from.z).length()
	var share: float = walked / (walk_h.speeds[ww] * 20.0 * DT)
	_check(walk_h.windup[ww] > 0.0 and absf(share - Horde.WINDUP_SPEED_SHARE) < 0.02,
		"a blow on its way keeps the enemy walking at %d%% of its speed (measured %.1f%%, %.3f m in 20 ticks)"
		% [int(Horde.WINDUP_SPEED_SHARE * 100.0), share * 100.0, walked])

	# The others strike at once, as before, and the wind-up is only for the common melee kinds.
	var brute_h := Horde.new(FlowField.new(60, 60))
	var bw: int = brute_h.add(in_reach, GameData.EnemyKind.BRUTE, rng)
	brute_h.set_target(target)
	brute_h.attack_cd[bw] = 0.0
	_check(is_equal_approx(_ticks(brute_h, 1), types[GameData.EnemyKind.BRUTE].damage), "a Brute strikes at once, as before")
	_check(Horde.telegraphs(GameData.EnemyKind.WALKER) and Horde.telegraphs(GameData.EnemyKind.RUNNER), "walkers and runners wind their blows up")
	_check(not Horde.telegraphs(GameData.EnemyKind.CRAWLER) and not Horde.telegraphs(GameData.EnemyKind.BRUTE) and not Horde.telegraphs(GameData.EnemyKind.GRABBER) and not Horde.telegraphs(GameData.EnemyKind.BLOATER) and not Horde.telegraphs(GameData.EnemyKind.SCREAMER) and not Horde.telegraphs(GameData.EnemyKind.BOSS), "the Crawler, the Brute, the Grabber, the Bloater, the Screamer and the boss keep their timing")

	# A killed enemy's blow does not come out, even when its wind-up ends after the death.
	var killed_h := Horde.new(FlowField.new(60, 60))
	var kw: int = killed_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	killed_h.set_target(target)
	killed_h.attack_cd[kw] = 0.0
	_ticks(killed_h, 1)
	killed_h.hp[kw] = 0.0
	_check(_ticks(killed_h, 25) == 0.0, "a blow whose enemy is killed mid wind-up does not land")

	# The survivor that moves into a removed enemy's slot keeps its blow on its way.
	var swap_h := Horde.new(FlowField.new(60, 60))
	var sa: int = swap_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	var sb: int = swap_h.add(in_reach + Vector3(0, 0, 0.5), GameData.EnemyKind.WALKER, rng)
	swap_h.set_target(target)
	swap_h.attack_cd[sa] = 10.0
	swap_h.attack_cd[sb] = 0.0
	_ticks(swap_h, 1)
	swap_h.remove(sa)
	_check(swap_h.windup[0] > 0.0 and is_equal_approx(_ticks(swap_h, 25), walker.damage), "the survivor that takes a removed enemy's slot lands its blow")

	# After the blow lands, the arms come back down over ATTACK_RECOVERY, then the state is clear.
	var recover_h := Horde.new(FlowField.new(60, 60))
	var rw: int = recover_h.add(in_reach, GameData.EnemyKind.WALKER, rng)
	recover_h.set_target(target)
	recover_h.attack_cd[rw] = 0.0
	_ticks(recover_h, 20)
	_check(recover_h.windup[rw] < 0.0, "the blow has landed and the arms are coming back down")
	_ticks(recover_h, 12)
	_check(recover_h.windup[rw] == 0.0, "the arms are back down after ATTACK_RECOVERY")

	quit(1 if _failures > 0 else 0)
