extends SceneTree
## Headless tests for the camera_medium spike.
## Run: godot --headless --path . --script res://spikes/camera_medium/tests/test_camera_medium.gd

const SCENE := "res://spikes/camera_medium/camera_medium.tscn"
const EXPECTED := [
	# pitch, distance, side offset, fov
	[25.0, 7.0, 0.8, 65.0],
	[35.0, 10.0, 0.4, 60.0],
	[45.0, 13.0, 0.0, 55.0],
]

var failures := 0


func check(cond: bool, msg: String) -> void:
	if cond:
		print("TEST: " + msg)
	else:
		print("TEST FAIL: " + msg)
		failures += 1


func _initialize() -> void:
	var packed := load(SCENE) as PackedScene
	if packed == null:
		print("TEST FAIL: scene did not load")
		quit(1)
		return
	var main: Node3D = packed.instantiate()
	root.add_child(main)
	# _ready only runs once the tree starts processing, so test on the first frame.
	process_frame.connect(_run.bind(main), CONNECT_ONE_SHOT)


func _run(main: Node3D) -> void:
	if not main.is_node_ready():
		print("TEST FAIL: scene never became ready")
		quit(1)
		return
	check(main.zombies.size() == 40, "scene loads with 40 zombies (got %d)" % main.zombies.size())
	check(main.obstacles.size() >= 6, "scene has obstacles (%d)" % main.obstacles.size())

	var rig = main.rig
	var cam: Camera3D = rig.camera
	_test_presets(rig, cam)
	_test_transition(rig)
	_test_frustum(main, rig)
	_test_aim(main, rig, cam)

	# Occlusion needs the physics space populated: test after a few physics frames.
	_frames_left = 3
	physics_frame.connect(_occlusion_step.bind(main))


var _frames_left := 0


func _occlusion_step(main) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	physics_frame.disconnect(_occlusion_step)
	# Yaw 0, medium preset: the camera sits ~8 m behind (+Z) and ~6 m above the
	# player. Standing just north of the 9 m tower at (-30, -25) puts it in between.
	main.rig.yaw_deg = 0.0
	main.rig.set_preset(1, true)
	main.player.global_position = Vector3(-30.0, 0.9, -31.0)
	main.rig.snap_to_target()
	main._update_occlusion()
	check(main.faded_count() >= 1, "tower between camera and player is faded (%d)" % main.faded_count())
	main.rig.yaw_deg = 90.0 # camera swings to the -X side: clear line of sight
	main.rig.snap_to_target()
	main._update_occlusion()
	check(main.faded_count() == 0, "nothing faded with a clear line of sight (%d)" % main.faded_count())
	main.free()
	print("TEST: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _test_presets(rig, cam: Camera3D) -> void:
	for i in EXPECTED.size():
		rig.set_preset(i, true)
		var e: Array = EXPECTED[i]
		var ok: bool = is_equal_approx(rig.pitch_deg, e[0]) and is_equal_approx(rig.distance, e[1]) \
			and is_equal_approx(rig.side_offset, e[2]) and is_equal_approx(cam.fov, e[3])
		check(ok, "preset %d values %s" % [i + 1, str(e)])
		# Geometry: camera sits `distance` from the pivot along the view axis,
		# looks down at `pitch`, and is shifted `offset` to the right.
		var pivot: Vector3 = rig.target.global_position + Vector3.UP * rig.pivot_height
		var t: Transform3D = cam.global_transform
		var rel := t.origin - pivot
		var along := rel.dot(t.basis.z)
		var side := rel.dot(t.basis.x)
		var look := -t.basis.z
		var pitch := rad_to_deg(asin(-look.y))
		check(is_equal_approx(snappedf(along, 0.001), e[1]) and is_equal_approx(snappedf(side, 0.001), e[2]) \
			and absf(pitch - e[0]) < 0.01,
			"preset %d camera geometry (dist %.3f, side %.3f, pitch %.2f)" % [i + 1, along, side, pitch])


func _test_transition(rig) -> void:
	rig.set_preset(0, true)
	rig.set_preset(2) # smooth
	rig._process(0.1)
	var mid: float = rig.distance
	check(mid > 7.0 and mid < 13.0, "transition is gradual (distance after 0.1 s = %.2f)" % mid)
	for _i in 200:
		rig._process(0.05)
	check(absf(rig.distance - 13.0) < 0.01, "transition converges to target preset")
	rig.set_preset(1, true)


func _test_frustum(main, rig) -> void:
	rig.yaw_deg = 0.0
	rig.set_preset(1, true)
	rig.snap_to_target()
	var player_pos: Vector3 = main.player.global_position
	# Camera looks towards -Z. Put 10 zombies in front, 15 behind the camera.
	for i in main.zombies.size():
		var z: Node3D = main.zombies[i]
		if i < 10:
			z.global_position = player_pos + Vector3(float(i % 5) - 2.0, 0.0, -15.0 - float(i))
		elif i < 25:
			z.global_position = player_pos + Vector3(0.0, 0.0, 30.0 + float(i))
		else:
			z.global_position = player_pos + Vector3(200.0, 0.0, 0.0) # far off to the side
	var n: int = main.count_zombies_in_frustum()
	check(n == 10, "frustum count = 10 (got %d)" % n)
	rig.yaw_deg = 180.0 # turn around: front ones leave, rear ones enter
	rig.snap_to_target()
	n = main.count_zombies_in_frustum()
	check(n == 15, "frustum count after 180° yaw = 15 (got %d)" % n)
	rig.yaw_deg = 0.0
	rig.snap_to_target()


func _test_aim(main, rig, cam: Camera3D) -> void:
	var plane_y: float = main.player.global_position.y + main.AIM_HEIGHT
	var size := cam.get_viewport().get_visible_rect().size
	for p: Vector2 in [size * 0.5, size * Vector2(0.2, 0.8), size * Vector2(0.9, 0.6)]:
		var hit: Variant = main.aim_on_player_plane(cam, p, plane_y)
		var ok := hit != null and absf((hit as Vector3).y - plane_y) < 0.001
		if ok:
			# The hit must project back onto the same screen point.
			ok = cam.unproject_position(hit).distance_to(p) < 0.5
		check(ok, "aim ray at %s hits plane y=%.2f at %s" % [p, plane_y, hit])
	# A ray aimed above the horizon must not hit.
	var none: Variant = main.aim_on_player_plane(cam, Vector2(size.x * 0.5, -size.y * 3.0), plane_y)
	check(none == null, "aim ray above the horizon returns null")
