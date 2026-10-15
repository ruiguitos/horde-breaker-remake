extends SceneTree
## Final skinned sole landmarks must clear the ground without stretching legs.

const DT: float = 1.0 / 60.0
const HEEL_DROP: float = 0.205
var _failures: int = 0
var _samples: Array[Array] = []
var _frame: int = 0
var _sample_frame: int = -1
var _length_error: float = 0.0
var _rest_lengths: Array[float] = []
var _soldier: SoldierModel
var _sk: Skeleton3D
var _terrain: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + message)
	if not ok:
		_failures += 1


func _run() -> void:
	for id: StringName in [&"recruit", &"vanguard"]:
		for scenario: Dictionary in [
			{"name": "walk", "velocity": Vector3(0, 0, -1.0), "sprint": false},
			{"name": "jog", "velocity": Vector3(0, 0, -6.0), "sprint": false},
			{"name": "back", "velocity": Vector3(0, 0, 6.0), "sprint": false},
			{"name": "strafe", "velocity": Vector3(6.0, 0, 0), "sprint": false},
			{"name": "sprint", "velocity": Vector3(0, 0, -9.6), "sprint": true},
			{"name": "ramp", "velocity": Vector3(0, 0, -6.0), "sprint": false, "terrain": true},
		]:
			await _scenario(id, scenario)
	quit(0 if _failures == 0 else 1)


func _scenario(id: StringName, scenario: Dictionary) -> void:
	_soldier = SoldierModel.create(id)
	_terrain = scenario.get("terrain", false)
	if _terrain:
		_soldier.ground_height = _ground
	root.add_child(_soldier)
	_soldier.position = Vector3(20, 0, 20)
	_soldier.position.y = _ground(_soldier.position)
	_sk = _soldier.find_child("Skeleton3D", true, false) as Skeleton3D
	_rest_lengths.clear()
	for side: String in ["L", "R"]:
		for part: String in ["shin", "foot"]:
			_rest_lengths.append(_sk.get_bone_rest(_sk.find_bone("DEF-" + part + "." + side)).origin.length())
	_samples.clear()
	_length_error = 0.0
	_sample_frame = -1
	_sk.skeleton_updated.connect(_capture)
	await process_frame
	for i in 225:
		_frame += 1
		_soldier.animate(1.0, 0.0, scenario.sprint, DT)
		_soldier.position += (scenario.velocity as Vector3) * DT
		_soldier.position.y = _ground(_soldier.position)
		await process_frame
	var minimum: float = INF
	var slide: float = 0.0
	var weight: float = 0.0
	# Ignore initial velocity/gait convergence; inspect at least three strides.
	for i in range(60, _samples.size()):
		for j in 4:
			var p: Vector3 = _samples[i][j]
			var previous: Vector3 = _samples[i - 1][j]
			minimum = minf(minimum, p.y - _ground(p))
			var h: float = (p.y - _ground(p) + previous.y - _ground(previous)) * 0.5
			var w: float = clampf((0.04 - h) / 0.04, 0.0, 1.0)
			slide += Vector2(p.x - previous.x, p.z - previous.z).length() / DT * w
			weight += w
	slide /= maxf(weight, 0.0001)
	var label: String = "%s %s" % [id, scenario.name]
	_check(minimum >= -0.005, "%s soles clear ground (min %.4f m)" % [label, minimum])
	_check(slide < 0.45, "%s planted soles slide less than 0.45 m/s (%.3f)" % [label, slide])
	_check(_length_error < 0.0002, "%s keeps original thigh/shin lengths" % label)
	# Advancing the rendered skeleton during pause must leave contacts frozen.
	var before: Array = _samples[-1].duplicate()
	for i in 5:
		_soldier.animate(0.0, 0.0, false, 0.0)
		await process_frame
	var pause_error: float = 0.0
	for j in 4:
		pause_error = maxf(pause_error, (before[j] as Vector3).distance_to(_samples[-1][j]))
	_check(pause_error < 0.0001, "%s freezes contacts while paused" % label)
	_soldier.position += Vector3(25, 0, 10)
	_soldier.position.y = _ground(_soldier.position)
	for i in 3:
		_frame += 1
		_soldier.animate(0.0, 0.0, false, DT)
		await process_frame
	var max_distance: float = 0.0
	for p: Vector3 in _samples[-1]:
		max_distance = maxf(max_distance, Vector2(p.x - _soldier.position.x, p.z - _soldier.position.z).length())
	_check(max_distance < 1.5, "%s drops contacts after a teleport" % label)
	_sk.skeleton_updated.disconnect(_capture)
	_soldier.free()


func _ground(point: Vector3) -> float:
	return point.x * 0.08 - point.z * 0.12 if _terrain else 0.0


func _capture() -> void:
	var points: Array = []
	var index: int = 0
	for side: String in ["L", "R"]:
		for part: String in ["foot", "toe"]:
			var pose: Transform3D = _sk.get_bone_global_pose(_sk.find_bone("DEF-" + part + "." + side))
			var p: Vector3 = _sk.global_transform * pose.origin
			points.append(p - Vector3.UP * HEEL_DROP if part == "foot" else p)
		for part: String in ["shin", "foot"]:
			var bone: int = _sk.find_bone("DEF-" + part + "." + side)
			var distance: float = _sk.get_bone_global_pose(bone).origin.distance_to(_sk.get_bone_global_pose(_sk.get_bone_parent(bone)).origin)
			_length_error = maxf(_length_error, absf(distance - _rest_lengths[index]))
			index += 1
	if _sample_frame == _frame and not _samples.is_empty():
		_samples[-1] = points
	else:
		_samples.append(points)
	_sample_frame = _frame
