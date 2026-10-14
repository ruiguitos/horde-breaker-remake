extends SceneTree
## Run and gun (decided by the user on 2026-10-14): sprinting no longer
## silences the gun. Auto-fire keeps shooting while sprinting in all three
## cameras (fixed: body cone; first / third person: the crosshair), in the
## simulation and in the real Island scene with the real inputs. A fuel can
## in the hands still blocks both firing and sprinting.
## Run: godot --headless --path . --script res://tests/test_run_and_gun.gd

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
	create_timer(90.0).timeout.connect(func() -> void:
		if not _done:
			_check(false, "run-and-gun tests finished in time")
			_finish())
	_test_simulation()
	_test_carry_blocks()
	call_deferred("_scene_tests")


func _finish() -> void:
	_done = true
	if _failures > 0:
		print("TEST FAIL: %d failure(s)" % _failures)
	quit(1 if _failures > 0 else 0)


## A quiet run with one stunned, very tough enemy `dist` m east.
func _run_with_target(dist: float = 7.0) -> Array:
	var run := IslandRun.new(7)
	run.director.max_alive = 0
	var e: int = run.horde.add(run.player_pos + Vector3(dist, 0, 0), GameData.EnemyKind.BRUTE, run.rng)
	run.horde.stun[e] = 100.0
	run.horde.hp[e] = 1.0e6
	return [run, e]


## IslandRun alone: the fixed camera (no crosshair) and the crosshair
## cameras (first / third person differ only in where the ray starts).
func _test_simulation() -> void:
	var eye_offsets: Dictionary = {"fixed": null, "first person": Vector3(0, 1.72, 0), "third person": Vector3(0.6, 1.9, 2.8)}
	for camera: String in eye_offsets:
		var a: Array = _run_with_target()
		var run: IslandRun = a[0]
		var e: int = a[1]
		var shots: int = run._shots
		var sprinted: bool = true
		for k in 20:
			if eye_offsets[camera] == null:
				run.clear_crosshair()
			else:
				var p: Vector3 = run.player_pos
				var eye: Vector3 = Vector3(p.x, run.map.ground_y(p), p.z) + (eye_offsets[camera] as Vector3)
				run.set_crosshair(eye, run.enemy_chest(e) - eye)
			run.step(DT, Vector2(1, 0), Vector3(1, 0, 0), false, true)
			sprinted = sprinted and run.sprinting
		_check(sprinted and run._shots > shots and run.horde.hp[e] < 1.0e6,
			"%s camera: sprinting and firing at once (%d shots)" % [camera, run._shots - shots])


## A fuel can in the hands: no sprint and no shots, even holding sprint.
func _test_carry_blocks() -> void:
	var run := IslandRun.new(41, &"beach")
	run.director.max_alive = 0
	run.set_mission(&"fuel_run")
	var p0: Vector3 = run.cargo_pos[0]
	run.player_pos = p0
	run.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.is_carrying(), "carrying a fuel can")
	var e: int = run.horde.add(p0 + Vector3(0, 0, -2.0), GameData.EnemyKind.WALKER, run.rng)
	run.horde.stun[e] = 100.0
	var shots: int = run._shots
	var sprinted: bool = false
	for k in 30:
		run.player_pos = p0
		run.step(DT, Vector2(1, 0), Vector3(0, 0, -1), false, true)
		sprinted = sprinted or run.sprinting
	_check(not sprinted and run._shots == shots, "with a can: holding sprint neither sprints nor fires (%d shots)" % (run._shots - shots))
	run.drop_cargo()
	for k in 30:
		run.player_pos = p0
		run.step(DT, Vector2(1, 0), Vector3(0, 0, -1), false, true)
	_check(run.sprinting and run._shots > shots, "can down: sprinting fires again")


# --- The real Island scene -------------------------------------------------

func _settle(frames: int = 2) -> void:
	for i in frames:
		await process_frame


func _look_at(island: Node, target: Vector3) -> void:
	var ray: Array[Vector3] = island.call("crosshair_ray")
	var to: Vector3 = target - ray[0]
	island.set("_tp_yaw", atan2(-to.x, -to.z))
	island.set("_tp_pitch", atan2(-to.y, Vector2(to.x, to.z).length()))


func _scene_tests() -> void:
	var profile := MemoryProfile.new()
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", profile)
	root.add_child(island)
	await _settle(3)
	var run: IslandRun = island.get("run")
	run.noclip = true
	run.director.max_alive = 0
	var modes: Dictionary = {"fixed": Profile.CameraMode.FIXED, "first person": Profile.CameraMode.FIRST_PERSON,
		"third person": Profile.CameraMode.THIRD_PERSON}
	for camera: String in modes:
		profile.camera_mode = modes[camera]  # the island follows the profile
		island.call("_set_camera_mode", modes[camera], false)
		for i in range(run.horde.count - 1, -1, -1):
			run.horde.remove(i)
		run.stamina = GameData.STAMINA_MAX
		var e: int = run.horde.add(run.player_pos + Vector3(7, 0, 0), GameData.EnemyKind.BRUTE, run.rng)
		run.horde.stun[e] = 100.0
		run.horde.hp[e] = 1.0e6
		run.facing = Vector3(1, 0, 0)
		if camera != "fixed":
			for k in 4:
				_look_at(island, run.enemy_chest(e))
		var shots: int = run._shots
		var sprinted: bool = false
		Input.action_press(&"sprint")
		Input.action_press(&"move_right" if camera == "fixed" else &"move_up")
		for k in 20:
			if camera != "fixed":
				_look_at(island, run.enemy_chest(e))
			await physics_frame
			sprinted = sprinted or run.sprinting
		Input.action_release(&"sprint")
		Input.action_release(&"move_right")
		Input.action_release(&"move_up")
		await _settle()
		_check(int(island.get("camera_mode")) == modes[camera] and sprinted and run._shots > shots,
			"real scene, %s camera: Shift + move sprints and the gun keeps firing (sprinted %s, %d shots)" % [camera, sprinted, run._shots - shots])
	island.queue_free()
	await _settle(2)
	_finish()
