extends SceneTree
## Pictures and frame times of out/real_island.scn (needs a GPU):
##   godot --path . --resolution 1280x720 --script res://spikes/real_island/view.gd
## Saves out/shots/*.png from a few viewpoints, then flies a slow circle for
## 300 frames and prints the mean and 95th-percentile frame time.

const DIR: String = "res://spikes/real_island/"

var _scene: Node3D
var _cam: Camera3D
var _shots: Array = []
var _frame: int = 0
var _times: Array[float] = []
var _last: int = 0
var _centre: Vector3
var _ready_at: int = 0  ## waits for the boot splash (Boot Splash Plus) to fade


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)  # measure, not wait for the monitor
	var t0: int = Time.get_ticks_msec()
	_scene = (load(DIR + "out/real_island.scn") as PackedScene).instantiate()
	root.add_child(_scene)
	print("scene loaded in %d ms" % (Time.get_ticks_msec() - t0))
	_cam = _scene.get_node("FlyCamera")
	if OS.get_cmdline_user_args().has("--nofog"):
		_scene.get_node("Sky3D").set("fog_enabled", false)
	_cam.set_process(false)
	var start: Transform3D = _cam.transform  # the island root sits at the origin
	var lh: Node3D = _scene.get_node_or_null("Buildings/Lighthouse_0")
	var l: Vector3 = lh.position if lh != null else start.origin
	var pier: Node3D = _scene.get_node_or_null("Buildings/Pier_0_0")
	var p: Vector3 = pier.position if pier != null else l
	_centre = start.origin + (-start.basis.z) * 420.0
	_shots = [
		["lighthouse", l + Vector3(-45, 25, 45), l + Vector3(0, 10, 0)],
		["harbour", p + Vector3(60, 25, 70), p],
		["harbour_low", p + Vector3(25, 4, 30), p + Vector3(-20, 3, -20)],
		["cliffs_from_sea", Vector3(_centre.x - 820.0, 10.0, _centre.z + 120.0), l + Vector3(0, 20, 0)],
		["ground_level", l + Vector3(60, 0, 60), l + Vector3(0, 12, 0)],
		["overview", start.origin, _centre],
	]


func _process(_delta: float) -> bool:
	if _ready_at == 0:
		_ready_at = Time.get_ticks_msec() + 4000
	if Time.get_ticks_msec() < _ready_at:
		return false
	_frame += 1
	var settle: int = 30
	if _frame < settle:
		return false
	var k: int = (_frame - settle) / 30
	var phase: int = (_frame - settle) % 30
	if k < _shots.size():
		var s: Array = _shots[k]
		if phase == 0:
			var eye: Vector3 = s[1]
			if s[0] == "ground_level":
				var terrain: Node = _scene.get_node("Terrain3D")
				var h: float = terrain.get("data").call("get_height", eye)
				eye.y = (h if not is_nan(h) else 0.0) + 1.7
			_cam.look_at_from_position(eye, s[2])
		elif phase == 29:
			DirAccess.make_dir_recursive_absolute(DIR + "out/shots")
			root.get_viewport().get_texture().get_image().save_png(DIR + "out/shots/%s.png" % s[0])
		return false
	# Benchmark: a slow circle over the island.
	var b: int = _frame - settle - _shots.size() * 30
	var now: int = Time.get_ticks_usec()
	if b > 0:
		_times.append((now - _last) / 1000.0)
	_last = now
	var a: float = b * 0.01
	_cam.look_at_from_position(_centre + Vector3(sin(a) * 600.0, 180.0, cos(a) * 600.0), _centre)
	if b >= 300:
		_times.sort()
		var mean: float = 0.0
		for t in _times:
			mean += t
		mean /= _times.size()
		print("frames: mean %.2f ms (%.0f fps), 95th percentile %.2f ms" % [mean, 1000.0 / mean, _times[int(_times.size() * 0.95)]])
		print("pictures in ", ProjectSettings.globalize_path(DIR + "out/shots"))
		quit(0)
	return false
