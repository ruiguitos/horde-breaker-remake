extends SceneTree
## Camera modes and crosshair aim: the camera_mode profile setting (and the
## old third_person bool), first / third-person auto-fire that only shoots
## what the crosshair is on (pitch included), the fixed camera's body cone,
## no laser sight, tracers from the gun and objective markers that only show
## when looked at (or are near: then they stay, on the screen edge if behind).
## Also: walls between the camera and the target, 3D hits (height and
## occlusion, with the card effects that hook into firing), the aim ray of
## the current frame and grenades aimed at the feet.
## Run: godot --headless --path . --script res://tests/test_camera_aim.gd

const DT: float = 1.0 / 60.0

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _done: bool = false


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	# Safety net: never leave the session hanging.
	create_timer(90.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "camera tests finished in time")
			_finish())
	_test_profile_migration()
	_test_crosshair_aim()
	_test_fixed_camera_unchanged()
	_test_marker_rule()
	_test_camera_occlusion()
	_test_3d_hits()
	_test_crosshair_card_effects()
	_test_pellet_path_and_sea()
	call_deferred("_scene_tests")


func _finish() -> void:
	_done = true
	if _failures > 0:
		print("TEST FAIL: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


func _test_profile_migration() -> void:
	_check(Profile.new().camera_mode == Profile.CameraMode.THIRD_PERSON, "new profiles start with the shoulder camera")
	_check(Profile.from_dict({"third_person": true}).camera_mode == Profile.CameraMode.THIRD_PERSON, "old save third_person = true -> THIRD_PERSON")
	_check(Profile.from_dict({"third_person": false}).camera_mode == Profile.CameraMode.FIXED, "old save third_person = false -> FIXED")
	_check(Profile.from_dict({}).camera_mode == Profile.CameraMode.THIRD_PERSON, "save without a camera setting -> THIRD_PERSON")
	_check(Profile.from_dict({"camera_mode": 0, "third_person": false}).camera_mode == Profile.CameraMode.FIRST_PERSON, "camera_mode wins over the old bool")
	_check(Profile.from_dict({"camera_mode": 9}).camera_mode == Profile.CameraMode.FIXED, "out-of-range camera_mode is clamped")
	var path: String = "user://test_camera_profile.json"
	var p := Profile.new()
	p.camera_mode = Profile.CameraMode.FIRST_PERSON
	p.save(path)
	var text: String = FileAccess.get_file_as_string(path)
	var back: Profile = Profile.load_profile(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(back.camera_mode == Profile.CameraMode.FIRST_PERSON and not text.contains("third_person"), "camera_mode saves and loads (no third_person key)")


## A run with one stunned enemy 8 m north of the player.
func _aim_run() -> Array:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	var p: Vector3 = run.player_pos
	var e: int = run.horde.add(p + Vector3(0, 0, -8), GameData.EnemyKind.BRUTE, run.rng)
	run.horde.stun[e] = 100.0
	var eye := Vector3(p.x, run.map.ground_y(p) + 1.72, p.z)
	return [run, e, eye]


func _shots_after(run: IslandRun, steps: int) -> int:
	var before: int = run._shots
	for k in steps:
		run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	return run._shots - before


func _test_crosshair_aim() -> void:
	var a: Array = _aim_run()
	var run: IslandRun = a[0]
	var e: int = a[1]
	var eye: Vector3 = a[2]
	var range_m: float = run.weapons[run.weapon_index].range_m
	run.set_crosshair(eye, Vector3(0, -1, -0.6))  # at the ground ~1 m ahead
	_check(run._pick_target(range_m) == -1 and _shots_after(run, 30) == 0, "crosshair at the ground with an enemy 8 m ahead: no shots")
	run.set_crosshair(eye, Vector3(0, 0.6, -1))  # at the sky
	_check(_shots_after(run, 30) == 0, "crosshair at the sky: no shots")
	run.set_crosshair(eye, Vector3(1, 0, -1))  # 45 degrees to the side
	_check(_shots_after(run, 30) == 0, "crosshair 45 degrees to the side: no shots")
	run.set_crosshair(eye, run.enemy_chest(e) - eye)
	_check(run._pick_target(range_m) == e and not run._is_headshot(e), "crosshair on the chest: target, body shot")
	_check(_shots_after(run, 30) > 0, "crosshair on an enemy: auto-fire shoots")
	run.set_crosshair(eye, run.enemy_head(e) - eye)
	_check(run._is_headshot(e), "crosshair on the head: headshot")
	# Just outside the cone: rotate the chest ray by cone + body + 2 degrees.
	var off: float = deg_to_rad(GameData.CROSSHAIR_CONE_DEG + 2.0) + atan(GameData.CROSSHAIR_BODY_RADIUS * run.horde.types[run.horde.kinds[e]].radius_scale / 8.0)
	run.set_crosshair(eye, (run.enemy_chest(e) - eye).rotated(Vector3.UP, off))
	_check(run._pick_target(range_m) == -1, "crosshair just outside the cone: no target")
	# Smallest angle wins over the nearer enemy.
	var near: int = run.horde.add(run.player_pos + Vector3(-2.5, 0, -5), GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[near] = 100.0
	run.set_crosshair(eye, run.enemy_chest(e) - eye)
	_check(run._pick_target(range_m) == e, "the enemy under the crosshair wins over a nearer one beside it")
	run.set_crosshair(eye, run.enemy_chest(near) - eye)
	_check(run._pick_target(range_m) == near, "turning the crosshair to the other enemy retargets")


func _test_fixed_camera_unchanged() -> void:
	var a: Array = _aim_run()
	var run: IslandRun = a[0]
	var e: int = a[1]
	run.clear_crosshair()
	run.facing = Vector3(0, 0, -1)
	var range_m: float = run.weapons[run.weapon_index].range_m
	_check(not run.uses_crosshair() and run._pick_target(range_m) == e and run._is_headshot(e), "fixed camera: body cone picks the enemy ahead (headshot)")
	_check(_shots_after(run, 30) > 0, "fixed camera: auto-fire shoots without a crosshair")
	run.facing = Vector3(1, 0, 0)
	_check(run._pick_target(range_m) == -1, "fixed camera: an enemy 90 degrees off is outside the body cone")


func _test_marker_rule() -> void:
	var run := IslandRun.new(7)
	var p: Vector3 = run.player_pos
	var far: Vector3 = p + Vector3(0, 0, -60)
	run.set_crosshair(p + Vector3(0, 2, 0), Vector3(0, -0.2, -1))
	_check(Hud.marker_in_view(run, far), "marker: target straight ahead is shown")
	_check(Hud.marker_in_view(run, p + Vector3(30, 0, -60)), "marker: target ~27 degrees off is shown")
	_check(not Hud.marker_in_view(run, p + Vector3(60, 0, 0)), "marker: target 90 degrees to the side is hidden")
	_check(not Hud.marker_in_view(run, p + Vector3(0, 0, 60)), "marker: target behind is hidden")
	_check(Hud.marker_in_view(run, p + Vector3(0, 0, 8)), "marker: target 8 m behind is shown (near)")
	run.set_crosshair(p + Vector3(0, 2, 0), Vector3(0, -1, -0.3))
	_check(Hud.marker_in_view(run, far), "marker: looking down at your feet keeps the target ahead")
	run.clear_crosshair()
	run.facing = Vector3(0, 0, 1)
	_check(not Hud.marker_in_view(run, far), "marker, fixed camera: hidden when the body faces away")
	run.facing = Vector3(0, 0, -1)
	_check(Hud.marker_in_view(run, far), "marker, fixed camera: shown when the body faces it")


## An open 64 m map (no walls, flat), player at (20.5, 20.5), rifle without
## spread so the 3D shot goes exactly where it is aimed.
func _open_run() -> IslandRun:
	var map := IslandMap.new()
	map.field = FlowField.new(64, 64)
	map.player_start = Vector3(20.5, 0, 20.5)
	map.boat = Vector3(20.5, 0, 50.5)
	map.generators = [Vector3(40, 0, 40), Vector3(45, 0, 40), Vector3(45, 0, 45)]
	var run := IslandRun.new(77, &"beach", map)
	run.weapons[0].spread_deg = 0.0
	run.director.max_alive = 0
	return run


## A 3 m high mound (terrain) centred on (20.5, 10.5): an enemy on top of it
## is on the same flat line as one on the flat ground in front of it, and
## a shot up at the top one passes well over the near one's head.
func _mound(run: IslandRun) -> void:
	var w: int = run.field.width
	run.map.heights.resize(w * run.field.height)
	for z in range(9, 12):
		for x in range(19, 22):
			run.map.heights[z * w + x] = 3.0


func _enemy(run: IslandRun, at: Vector3, kind: int = GameData.EnemyKind.WALKER) -> int:
	var i: int = run.horde.add(at, kind, run.rng)
	run.horde.stun[i] = 100.0
	run.horde.hp[i] = 1000.0
	return i


## A building between the shoulder camera and the target, with the soldier's
## own line clear: no target, no shots.
func _test_camera_occlusion() -> void:
	var run: IslandRun = _open_run()
	var e: int = _enemy(run, Vector3(20.5, 0, 12.5))  # 8 m ahead (north)
	var cam := Vector3(22.5, 1.9, 25.5)  # behind, over the right shoulder
	var range_m: float = run.weapons[0].range_m
	run.set_crosshair(cam, run.enemy_chest(e) - cam)
	_check(run._pick_target(range_m) == e, "open ground: the shoulder camera targets the enemy ahead")
	# Wall cells on the camera's line (x 21.3..21.6 at z 17..20) but not on
	# the player's (x 20.5).
	for z in [17, 18, 19]:
		run.sight_blocked[z * run.field.width + 21] = 1
	run.set_crosshair(cam, run.enemy_chest(e) - cam)
	_check(run.call("_line_of_sight", run.player_pos, run.horde.positions[e]) and run._pick_target(range_m) == -1
		and _shots_after(run, 30) == 0, "building between the camera and the target (player's line clear): no target, no shots")
	# A camera that starts inside a blocked cell (over the sea, against a
	# wall) still sees out of it.
	var inside := Vector3(21.5, 1.9, 18.5)
	run.set_crosshair(inside, run.enemy_chest(e) - inside)
	_check(run._pick_target(range_m) == e, "a camera inside a blocked cell sees out of it")


## First / third person: shots are 3D rays from the camera. An enemy below
## the shot on the same flat line is not hit; the fixed camera keeps the
## flat hitscan (it would be hit).
func _test_3d_hits() -> void:
	var run: IslandRun = _open_run()
	_mound(run)
	var target: int = _enemy(run, Vector3(20.5, 0, 10.5))  # 10 m ahead, on the mound
	var low: int = _enemy(run, Vector3(20.5, 0, 15.5))  # 5 m ahead, 3 m lower
	var eye := Vector3(20.5, 1.72, 20.5)
	run.set_crosshair(eye, run.enemy_chest(target) - eye)
	_check(run._pick_target(run.weapons[0].range_m) == target, "crosshair on the enemy up on a mound picks it, not the nearer one below")
	run.call("_fire", run.weapons[0], target)
	_check(run.horde.hp[target] < 1000.0 and is_equal_approx(run.horde.hp[low], 1000.0),
		"crosshair shot: the enemy at another height on the same flat line is not damaged")
	var fixed: IslandRun = _open_run()
	_mound(fixed)
	var t2: int = _enemy(fixed, Vector3(20.5, 0, 10.5))
	var h2: int = _enemy(fixed, Vector3(20.5, 0, 15.5))
	fixed.facing = Vector3(0, 0, -1)
	fixed.call("_fire", fixed.weapons[0], t2)
	_check(fixed.horde.hp[h2] < 1000.0 and is_equal_approx(fixed.horde.hp[t2], 1000.0), "fixed camera keeps the flat hitscan (nearest on the line)")
	# A wall between the target and an enemy behind it: the shot does not
	# pierce into the hidden one.
	var walled: IslandRun = _open_run()
	walled.card_stacks[&"piercing_rounds"] = 2
	var front: int = _enemy(walled, Vector3(20.5, 0, 16.5))
	var hidden: int = _enemy(walled, Vector3(20.5, 0, 10.5))
	walled.set_crosshair(eye, Vector3(20.5, 1.5, 16.5) - eye)  # would reach the one behind
	walled.sight_blocked[13 * walled.field.width + 20] = 1
	walled.call("_fire", walled.weapons[0], front)
	_check(walled.horde.hp[front] < 1000.0 and is_equal_approx(walled.horde.hp[hidden], 1000.0), "crosshair shot: no pierce through a wall")


## The card effects that hook into firing still work with 3D shots.
func _test_crosshair_card_effects() -> void:
	var eye := Vector3(20.5, 1.72, 20.5)
	# Piercing Rounds: pierce = 1 + rank, only through enemies the ray meets.
	var run: IslandRun = _open_run()
	run.card_stacks[&"piercing_rounds"] = 1
	var first: int = _enemy(run, Vector3(20.5, 0, 17.5))
	var second: int = _enemy(run, Vector3(20.5, 0, 13.5))
	var third: int = _enemy(run, Vector3(20.5, 0, 11.5))
	run.set_crosshair(eye, Vector3(20.5, 1.4, 17.5) - eye)  # a near-flat shot
	run.call("_fire", run.weapons[0], first)
	_check(run.horde.hp[first] < 1000.0 and run.horde.hp[second] < 1000.0 and is_equal_approx(run.horde.hp[third], 1000.0),
		"crosshair + Piercing Rounds: pierces into the next body on the ray (pierce 2), not a third")
	# Ricochet: every 4th rifle shot bounces to neighbours of the target.
	run = _open_run()
	run.card_stacks[&"ricochet"] = 2
	var t: int = _enemy(run, Vector3(20.5, 0, 14.5))
	var n1: int = _enemy(run, Vector3(23.5, 0, 14.5))
	var n2: int = _enemy(run, Vector3(23.5, 0, 11.5))
	run.set("_shots", 3)
	run.set_crosshair(eye, run.enemy_chest(t) - eye)
	run.call("_fire", run.weapons[0], t)
	_check(run.horde.hp[t] < 1000.0 and run.horde.hp[n1] < 1000.0 and run.horde.hp[n2] < 1000.0, "crosshair + Ricochet: the bounce reaches the neighbours")
	# Elements: Fire Rounds rank 5 burns within a few dozen hits.
	run = _open_run()
	run.card_stacks[&"fire_rounds"] = 5
	t = _enemy(run, Vector3(20.5, 0, 14.5))
	run.set_crosshair(eye, run.enemy_chest(t) - eye)
	for k in 200:
		run.call("_fire", run.weapons[0], t)
		run.horde.hp[t] = 1000.0
		if run.horde.burn_time[t] > 0.0:
			break
	_check(run.horde.burn_time[t] > 0.0, "crosshair + Fire Rounds: hits set enemies on fire")
	# Insta-Kill power-up: one crosshair hit kills a normal enemy.
	run = _open_run()
	t = _enemy(run, Vector3(20.5, 0, 14.5))
	run.apply_power_up(&"insta_kill")
	run.set_crosshair(eye, run.enemy_chest(t) - eye)
	run.call("_fire", run.weapons[0], t)
	_check(run.kills == 1, "crosshair + Insta-Kill: one hit kills")


## Each pellet stops at the first obstacle on its OWN path (a ray just
## beside the body axis can cross a wall the axis line misses), and the sea
## or steep ground (blocked for walking only) does not hide anything.
func _test_pellet_path_and_sea() -> void:
	var run: IslandRun = _open_run()
	var e: int = _enemy(run, Vector3(20.75, 0, 12.5))
	var cam := Vector3(22.4, 1.9, 25.5)
	var dir: Vector3 = (Vector3(21.05, 1.0, 12.5) - cam).normalized()  # 0.3 m right of the axis
	var cands: PackedInt32Array = run.call("_shot_candidates", cam, dir, 30.0, 0.0)
	var open_hits: Array = run.call("_crosshair_hits", cam, dir, 3, cands)
	run.sight_blocked[13 * run.field.width + 21] = 1  # on the pellet's path only
	var camera_to_axis: bool = run.call("_view_clear", cam, Vector3(20.75, 1.0, 12.5))
	var walled_hits: Array = run.call("_crosshair_hits", cam, dir, 3, cands)
	_check(open_hits.size() == 1 and camera_to_axis and walled_hits.is_empty(),
		"a pellet beside the body axis stops at a wall on its own path (%d hit(s) open, %d walled)" % [open_hits.size(), walled_hits.size()])
	# Coast: the sea between the shoulder camera and the target is blocked for
	# walking, not for the view.
	var coast: IslandRun = _open_run()
	var t: int = _enemy(coast, Vector3(20.5, 0, 12.5))
	var cam2 := Vector3(22.5, 1.9, 25.5)
	for z in range(17, 26):
		for x in range(21, 24):
			coast.field.blocked[z * coast.field.width + x] = 1  # sea
	coast.set_crosshair(cam2, coast.enemy_chest(t) - cam2)
	_check(coast._pick_target(coast.weapons[0].range_m) == t and _shots_after(coast, 30) > 0,
		"sea between the camera and the target does not hide it: target picked and shot")


# --- The real Island scene -------------------------------------------------

func _settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout
	await process_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.physical_keycode = code
		event.keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)
		await _settle()


## Points the first / third-person view at `target` (world metres).
func _look_at(island: Node, target: Vector3) -> void:
	var ray: Array[Vector3] = island.call("crosshair_ray")
	var eye: Vector3 = ray[0]
	var to: Vector3 = target - eye
	island.set("_tp_yaw", atan2(-to.x, -to.z))
	island.set("_tp_pitch", atan2(-to.y, Vector2(to.x, to.z).length()))


func _scene_tests() -> void:
	var profile := MemoryProfile.new()
	profile.camera_mode = Profile.CameraMode.FIRST_PERSON
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	root.add_child(island)
	await _settle(3)
	var run: IslandRun = island.get("run")
	var hud: Hud = island.get("hud")
	run.noclip = true  # no damage while the test waits
	run.director.max_alive = 0
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	var camera: Camera3D = island.get("_camera")
	var view_model: ViewModel = island.get("_view_model")
	var crosshair: Control = island.get("_crosshair")

	# First person: eye height, gun visible, body only casts its shadow.
	await _settle(2)
	var eye_h: float = camera.global_position.y - run.map.ground_y(run.player_pos)
	var body: MeshInstance3D = (island.get("_player") as Node).find_children("*", "MeshInstance3D", true, false)[0]
	_check(int(island.get("camera_mode")) == Profile.CameraMode.FIRST_PERSON and absf(eye_h - 1.72) < 0.2
		and view_model.visible and crosshair.visible and camera.near <= 0.05
		and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY,
		"first person: camera at eye height (%.2f m), gun and crosshair shown, body shadow only" % eye_h)

	# No laser sight: the only line mesh is the tracers'.
	var lines: int = 0
	for n in island.get_children():
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is ImmediateMesh:
			lines += 1
	_check(island.get("_laser_mesh") == null and not run.has_method("aim_info") and lines == 1, "no laser sight (%d line mesh)" % lines)

	# An enemy 8 m ahead on free ground.
	var p: Vector3 = run.player_pos
	var dir := Vector3.ZERO
	for k in 16:
		var d := Vector3(0, 0, -1).rotated(Vector3.UP, k * TAU / 16.0)
		var ok: bool = true
		for m in range(1, 11):
			var q: Vector3 = p + d * m
			ok = ok and not run.field.is_blocked(floori(q.x), floori(q.z))
		if ok:
			dir = d
			break
	_check(dir != Vector3.ZERO, "found free ground around the player")
	var e: int = run.horde.add(p + dir * 8.0, GameData.EnemyKind.BRUTE, run.rng)
	run.horde.stun[e] = 100.0
	run.horde.hp[e] = 100000.0
	# Look at the ground right in front, along that direction.
	_look_at(island, Vector3(p.x, run.map.ground_y(p), p.z) + dir * 0.8)
	await _wait(0.4)
	var shots: int = run._shots
	await _wait(0.5)
	_check(run.uses_crosshair() and run._shots == shots, "first person, crosshair at the ground: no shots (%d)" % (run._shots - shots))
	_look_at(island, run.enemy_chest(e))
	await _wait(0.5)
	_check(run._shots > shots, "first person, crosshair on the enemy: shots (%d)" % (run._shots - shots))

	# Tracers start at the gun's tip.
	run.tracers.append(PackedVector3Array([run.player_pos, run.player_pos + dir * 8.0]))
	island.call("_draw_effects", 0.0)
	var start: Vector3 = (island.get("_tracer_mesh") as ImmediateMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX][0]
	_check(start.distance_to(view_model.tip.global_position) < 0.01, "first person: tracers start at the gun's tip")

	# Objective marker: hidden when the target is behind, shown when looked at.
	var goal: Vector3 = run.map.generators[0]
	var best: float = INF
	for g in run.map.generators:
		var gd: float = Vector2(g.x - p.x, g.z - p.z).length()
		if gd < best:
			best = gd
			goal = g
	var pill: Control = hud.get("_marker_pill")
	if best > Hud.MARKER_NEAR_M + 1.0:
		var away: Vector3 = p - (goal - p)
		_look_at(island, Vector3(away.x, run.map.ground_y(p) + 1.7, away.z))
		await _wait(0.4)
		_check(not pill.visible, "marker hidden when its target is behind (%.0f m)" % best)
		_look_at(island, Vector3(goal.x, run.map.ground_y(goal) + 1.5, goal.z))
		await _wait(0.4)
		_check(pill.visible and pill.modulate.a > 0.99, "marker shown when looked at")
	else:
		_check(false, "nearest generator is far enough for the marker test (%.0f m)" % best)

	# A near objective behind the camera stays on screen, on its edge.
	var near_spot := Vector3.INF
	for k in 16:
		var cand: Vector3 = goal + Vector3(0, 0, 8).rotated(Vector3.UP, k * TAU / 16.0)
		if run.can_spawn_at(cand):
			near_spot = cand
			break
	if near_spot != Vector3.INF:
		run.player_pos = near_spot
		await _settle(2)
		var away2: Vector3 = near_spot - (goal - near_spot)
		_look_at(island, Vector3(away2.x, run.map.ground_y(near_spot) + 1.7, away2.z))
		await _wait(0.4)
		var view: Rect2 = hud.get_viewport().get_visible_rect()
		var r: Rect2 = pill.get_global_rect()
		_check(pill.visible and pill.modulate.a > 0.99 and view.encloses(r) and r.get_center().y > view.size.y * 0.5,
			"near objective (8 m) behind the camera: marker stays, on the lower screen edge (%s)" % r)
		run.player_pos = p
		await _settle(2)
	else:
		_check(false, "free spot 8 m from the nearest generator")

	# The crosshair ray is this frame's: turning the view and stepping once
	# aims the simulation along the new look (not last frame's camera).
	await physics_frame  # (emitted before the nodes' _physics_process)
	island.set("_tp_yaw", float(island.get("_tp_yaw")) + 1.3)
	await process_frame  # after this frame's step, before the camera moves
	var look: Vector3 = island.call("_look_dir")
	_check(run.crosshair_dir.distance_to(look) < 0.001, "first person: the aim ray follows this frame's yaw/pitch")

	# Grenade at the feet lands near the feet (first person, looking down).
	_look_at(island, Vector3(p.x, run.map.ground_y(p), p.z) + dir * 0.3)
	await _settle(1)
	var throw: Vector3 = island.call("grenade_throw")
	run.grenade_cd = 0.0
	island.set("_grenade_held", true)
	await physics_frame
	await physics_frame
	var landed: float = INF if run.grenades.is_empty() else Vector2(run.grenades[0].x - p.x, run.grenades[0].z - p.z).length()
	_check(throw.length() <= 1.6 and landed <= 2.0, "first person: a grenade aimed at the feet lands near them (%.1f m)" % landed)
	run.grenades.clear()
	run.grenade_fuses.clear()
	# Looking at the sky: no ground hit, a long throw ahead.
	island.set("_tp_pitch", deg_to_rad(-50.0))
	_check((island.call("grenade_throw") as Vector3).length() > 10.0, "grenade aimed at the sky: thrown far ahead")

	# Facing a wall up close, the gun is pulled back and lowered.
	var wall_spot := Vector3.INF
	var wall_aim := Vector3.ZERO
	for b: AABB in island.get("_building_boxes"):
		var spot := Vector3(b.position.x - 0.6, 0, b.get_center().z)
		var eye_y: float = run.map.ground_y(spot) + 1.72
		if b.size.y > 1.0 and b.position.y < eye_y - 0.3 and b.end.y > eye_y + 0.3 and b.size.z > 2.0 \
				and not run.field.is_blocked(floori(spot.x), floori(spot.z)):
			wall_spot = spot
			wall_aim = Vector3(b.position.x + 1.0, eye_y, spot.z)
			break
	if wall_spot != Vector3.INF:
		run.player_pos = wall_spot
		await _settle(2)
		_look_at(island, wall_aim)
		await _settle(3)
		_check(view_model.rotation.x < -0.5 and view_model.position.z > ViewModel.REST.z + 0.2,
			"first person at a wall: gun pulled back (%.2f m) and lowered (%.0f deg)" % [view_model.position.z - ViewModel.REST.z, rad_to_deg(view_model.rotation.x)])
		_look_at(island, wall_aim + Vector3(-25, 0, 0))  # the other way
		await _settle(3)
		_check(view_model.rotation.x > -0.2, "turning away from the wall raises the gun again")
		run.player_pos = p
	else:
		print("TEST: (no building wall on this island: gun pull-back not checked)")

	# V cycles First -> Third -> Fixed -> First and saves to the profile.
	await _key(KEY_V)
	_check(int(island.get("camera_mode")) == Profile.CameraMode.THIRD_PERSON and profile.camera_mode == Profile.CameraMode.THIRD_PERSON
		and not view_model.visible and body.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "V: first -> third person (gun hidden, body drawn)")
	await _settle(2)
	_check(island.call("muzzle_position").distance_to((island.get("_player") as SoldierModel).muzzle.global_position) < 0.01, "third person: tracers start at the soldier's gun")
	# Third person: the crosshair ray starts at the shoulder camera, off to
	# the right of the soldier; a grenade aimed at his feet lands near them.
	var tp_ray: Array[Vector3] = island.call("crosshair_ray")
	var right: Vector3 = (island.call("_tp_forward") as Vector3).cross(Vector3.UP)
	_check((tp_ray[0] - island.call("_view_pos")).dot(right) > 1.0, "third person: the camera sits over the right shoulder")
	var feet: Vector3 = Vector3(p.x, run.map.ground_y(p), p.z) + dir * 0.6
	for k in 4:  # the arm (and so the ray's origin) depends on the pitch
		_look_at(island, feet)
	var tp_throw: Vector3 = island.call("grenade_throw")
	_check(tp_throw.length() <= 2.5, "third person: a grenade aimed at the feet lands near them (%.1f m)" % tp_throw.length())
	# While strafing, the camera on screen is the one the simulation aims
	# from (no damping lag between the view and crosshair_ray).
	var worst: float = 0.0
	var side: Vector3 = (island.call("_tp_forward") as Vector3).cross(Vector3.UP)
	var start_pos: Vector3 = run.player_pos
	for k in 20:
		run.player_pos += side * 0.15
		await process_frame
		await process_frame
		var ray_now: Array[Vector3] = island.call("crosshair_ray")
		worst = maxf(worst, camera.global_position.distance_to(ray_now[0]))
	_check(worst < 0.05, "third person while strafing: the shown camera is the aiming camera (worst gap %.3f m)" % worst)
	run.player_pos = start_pos
	await _key(KEY_V)
	await _settle(2)
	_check(int(island.get("camera_mode")) == Profile.CameraMode.FIXED and not run.uses_crosshair() and not crosshair.visible, "V: third person -> fixed (no crosshair aim)")
	await _key(KEY_V)
	_check(int(island.get("camera_mode")) == Profile.CameraMode.FIRST_PERSON, "V: fixed -> first person")
	# Settings change it too (the island follows the profile).
	profile.camera_mode = Profile.CameraMode.FIXED
	await _settle(2)
	_check(int(island.get("camera_mode")) == Profile.CameraMode.FIXED, "a Settings change reaches the island")
	island.queue_free()
	await _settle(2)
	_finish()
