extends SceneTree
## Locomotion check for the delivered soldier rigs (Recruit, Vanguard).
## Drives SoldierModel exactly like island.gd does (animate() with the
## smoothed walk speed, then position and basis from the simulation) through
## a list of movement scenarios, and measures what the eye sees.
##
##   godot --headless --path . --script res://tools/dev/locomotion_preview.gd -- measure [recruit|vanguard]
##   godot --headless --path . --script res://tools/dev/locomotion_preview.gd -- calibrate [recruit|vanguard]
##   godot --path . --script res://tools/dev/locomotion_preview.gd -- sheet <out prefix> [recruit|vanguard] [scale]
##
## measure:   per scenario, foot sliding (planted feet's world speed), body
##            speed, ground contact, legs vs movement, rifle aim vs facing,
##            plus a timeline of the animation state for start/stop and turn.
## calibrate: ground speed, stride and phase of each UAL locomotion clip
##            (the numbers SoldierModel's LOCOMOTION table uses).
## sheet:     needs a window (GPU). Saves <prefix>_side.png (3/4 view) and
##            <prefix>_fixed.png (the fixed camera, 35 degrees, 10 m, same
##            pixel size as a 1080p screen). Footprints: green = planted,
##            yellow/red = sliding; red line = barrel, green = facing (aim).

const DT: float = 1.0 / 60.0
const TILE := Vector2i(300, 340)
const COLUMNS: int = 6
const CONTACT_H: float = 0.04  ## a sole point within 4 cm of the ground is planted
const HEEL_DROP: float = 0.205  ## ankle bone to heel sole (measured in Idle)
const CARRY_OFFSET := Vector3(0.38, 0.25, 0.05)  ## island.gd's, can base

var _mode: String = "measure"
var _out: String = ""
var _class_id: StringName = &"recruit"
var _soldier: SoldierModel
var _skeleton: Skeleton3D
var _scenarios: Array[Dictionary] = []
var _scenario: int = -1
var _t: float = 0.0
var _pos := Vector3.ZERO
var _facing := Vector3(0, 0, -1)
var _walk_speed: float = 0.0
var _samples: Array[Dictionary] = []
var _side_vp: SubViewport
var _fixed_vp: SubViewport
var _side_cam: Camera3D
var _fixed_cam: Camera3D
var _side_label: Label
var _fixed_label: Label
var _sheet_side: Image
var _sheet_fixed: Image
var _capture_at: Array[float] = []
var _pending_capture: int = -1
var _decals: Node3D
var _marks: Array[MeshInstance3D] = []
var _world: Node3D
var _wait_frames: int = 0
var _bones: Dictionary = {}
var _scale: float = 1.0  ## sheet: final image scale (docs use 0.6)
var _lines: Array[MeshInstance3D] = []  ## barrel (red), facing (green)
var _can: MeshInstance3D  ## the carried fuel can, where island.gd hangs it


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_mode = args[0]
	var rest: Array = args.slice(1)
	if _mode == "sheet":
		if rest.is_empty():
			print("Usage: locomotion_preview.gd -- sheet <out prefix> [recruit|vanguard]")
			quit(1)
			return
		_out = rest.pop_front()
	if not rest.is_empty():
		_class_id = StringName(rest[0])
	if rest.size() > 1:
		_scale = clampf(float(rest[1]), 0.1, 1.0)
	_world = Node3D.new()
	root.add_child(_world)
	_build_scenarios()
	if _mode == "calibrate":
		call_deferred("_calibrate")
		return
	if _mode == "sheet":
		_build_stage()
	_soldier = SoldierModel.create(_class_id)
	_world.add_child(_soldier)
	_skeleton = _soldier.find_child("Skeleton3D", true, false) as Skeleton3D
	if _skeleton == null:
		print("LOCOMOTION FAIL: no skeleton")
		quit(1)
		return
	for b in ["DEF-foot.L", "DEF-foot.R", "DEF-toe.L", "DEF-toe.R", "DEF-thigh.L", "DEF-thigh.R", "DEF-hips"]:
		_bones[b] = _skeleton.find_bone(b)
	_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	_wait_frames = 3


# --- Scenarios --------------------------------------------------------------

## move: world direction (x, z) the simulation moves in; facing: the aim.
## Speeds are the game's (GameData.PLAYER_SPEED 6 m/s, sprint x1.6, a fuel
## can x0.8), so the numbers match the island.
func _build_scenarios() -> void:
	var walk: float = GameData.PLAYER_SPEED
	var sprint: float = GameData.PLAYER_SPEED * GameData.SPRINT_MULTIPLIER
	var fwd := Vector3(0, 0, -1)
	# Steady scenarios measure 0.8 .. 2.67 s: two Jog cycles, three Sprint.
	_add("idle", 2.67, Vector3.ZERO, 0.0)
	_add("walk_fwd", 2.67, fwd, walk)
	_add("walk_back", 2.67, -fwd, walk)
	_add("strafe_left", 2.67, Vector3.LEFT, walk)
	_add("strafe_right", 2.67, Vector3.RIGHT, walk)
	_add("diag_fwd_left", 2.67, Vector3(-1, 0, -1).normalized(), walk)
	_add("diag_back_right", 2.67, Vector3(1, 0, 1).normalized(), walk)
	_add("sprint_fwd", 2.67, fwd, sprint, {"sprint": true})
	_add("sprint_strafe", 2.67, Vector3.RIGHT, sprint, {"sprint": true})  # run and gun
	_add("carry_fwd", 2.67, fwd, walk * 0.8, {"carry": true})
	_add("turn_in_place", 1.4, Vector3.ZERO, 0.0, {"turn": true, "cap": [0.2, 1.2], "window": [0.2, 1.4]})
	_add("start_stop", 2.0, fwd, walk, {"start": 0.4, "stop": 1.2, "cap": [0.3, 1.55], "window": [0.2, 2.0]})


func _add(id: String, duration: float, move: Vector3, speed: float, extra: Dictionary = {}) -> void:
	var s: Dictionary = {"id": id, "duration": duration, "move": move, "speed": speed,
		"sprint": false, "carry": false, "turn": false, "start": 0.0, "stop": 99.0, "cap": [0.8, 1.6],
		"window": [0.8, duration]}
	s.merge(extra, true)
	_scenarios.append(s)


## The simulation's state at time t of scenario s: [move velocity, facing, sprinting].
func _input_at(s: Dictionary, t: float) -> Array:
	var moving: bool = t >= float(s.start) and t < float(s.stop)
	var vel: Vector3 = (s.move as Vector3) * float(s.speed) if moving else Vector3.ZERO
	var facing := Vector3(0, 0, -1)
	if s.turn:
		# A quick mouse flick: 180 degrees in 0.3 s, then hold.
		var k: float = clampf((t - 0.3) / 0.3, 0.0, 1.0)
		facing = Vector3(0, 0, -1).rotated(Vector3.UP, -PI * k)
	return [vel, facing, bool(s.sprint) and moving]


# --- Driver -----------------------------------------------------------------

func _process(_delta: float) -> bool:
	if _soldier == null:
		return false
	if _pending_capture >= 0:
		_grab(_pending_capture)
		_pending_capture = -1
	if _wait_frames > 0:
		_wait_frames -= 1
		return false
	if _scenario < 0 or _t >= float(_scenarios[_scenario].duration):
		if _scenario >= 0:
			_report(_scenarios[_scenario])
		_scenario += 1
		if _scenario >= _scenarios.size():
			_finish()
			return false
		_start_scenario()
	_step()
	return false


func _start_scenario() -> void:
	var s: Dictionary = _scenarios[_scenario]
	_t = 0.0
	_samples.clear()
	_pos = Vector3(20, 0, 20)
	_facing = Vector3(0, 0, -1)
	_walk_speed = 0.0
	# A fresh soldier per scenario: no state carried over.
	if _soldier != null:
		_skeleton.skeleton_updated.disconnect(_on_skeleton_updated)
		_soldier.free()
	_soldier = SoldierModel.create(_class_id)
	_world.add_child(_soldier)
	_soldier.position = _pos
	_skeleton = _soldier.find_child("Skeleton3D", true, false) as Skeleton3D
	_skeleton.skeleton_updated.connect(_on_skeleton_updated)
	if "carrying" in _soldier:
		_soldier.set("carrying", bool(s.carry))
	for m in _marks:
		m.queue_free()
	_marks.clear()
	_capture_at.clear()
	var cap: Array = s.cap
	for i in COLUMNS:
		_capture_at.append(lerpf(float(cap[0]), float(cap[1]), float(i) / float(COLUMNS - 1)))


## One island frame, in island.gd's order (_draw_player_and_camera).
func _step() -> void:
	var s: Dictionary = _scenarios[_scenario]
	var input: Array = _input_at(s, _t)
	var vel: Vector3 = input[0]
	_facing = input[1]
	var sprinting: bool = input[2]
	var new_pos: Vector3 = _pos + vel * DT
	var moved: float = _soldier.position.distance_to(new_pos)
	_walk_speed = lerpf(_walk_speed, clampf(moved / DT / 6.0, 0.0, 1.0), 0.2)
	_soldier.animate(_walk_speed, _t, sprinting, DT)
	_pos = new_pos
	_soldier.position = _pos
	_soldier.basis = Basis.looking_at(_facing, Vector3.UP)
	_t += DT
	if _mode == "sheet":
		_place_cameras()
		for i in _capture_at.size():
			if _capture_at[i] >= 0.0 and _t >= _capture_at[i]:
				_capture_at[i] = -1.0
				_set_captions(s)
				_pending_capture = i  # grab once this frame is drawn
				break


func _on_skeleton_updated() -> void:
	if _scenario < 0 or _soldier == null:
		return
	var xf: Transform3D = _skeleton.global_transform
	var smp: Dictionary = {"t": _t, "pos": _soldier.global_position, "facing": _facing}
	var soles: Array = []
	for side in ["L", "R"]:
		var foot: Vector3 = xf * _skeleton.get_bone_global_pose(_bones["DEF-foot." + side]).origin
		var toe: Vector3 = xf * _skeleton.get_bone_global_pose(_bones["DEF-toe." + side]).origin
		soles.append(foot - Vector3(0, HEEL_DROP, 0))
		soles.append(toe)
	smp["soles"] = soles
	var hip_l: Vector3 = xf * _skeleton.get_bone_global_pose(_bones["DEF-thigh.L"]).origin
	var hip_r: Vector3 = xf * _skeleton.get_bone_global_pose(_bones["DEF-thigh.R"]).origin
	var legs: Vector3 = (hip_l - hip_r).cross(Vector3.UP)
	smp["legs"] = Vector3(legs.x, 0, legs.z).normalized()
	smp["hips_y"] = (xf * _skeleton.get_bone_global_pose(_bones["DEF-hips"]).origin).y - _soldier.global_position.y
	var muzzle: Node3D = _gun_muzzle()
	smp["barrel"] = -muzzle.global_basis.z.normalized()
	smp["muzzle"] = muzzle.global_position
	smp["state"] = _state_text()
	if not _samples.is_empty():
		var prev: Dictionary = _samples[-1]
		if is_equal_approx(float(prev.t), _t):
			_samples[-1] = smp  # several updates in one frame: keep the last
			return
	_samples.append(smp)
	if _mode == "sheet":
		_mark_contacts(smp)


## The visible gun's tip (with a can in the right hand the gun rides the
## left hand; SoldierModel.muzzle stays the right hand's rifle muzzle).
func _gun_muzzle() -> Node3D:
	var gun: Node = _soldier.get("_gun_node")
	if gun != null and gun.get("muzzle") is Node3D:
		return gun.get("muzzle")
	return _soldier.muzzle


func _state_text() -> String:
	if _soldier.has_method("debug_state"):
		var d: Dictionary = _soldier.call("debug_state")
		return str(d.get("text", ""))
	var player: AnimationPlayer = _soldier.find_child("*AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return ""
	return "%s x%.2f" % [String(player.current_animation).trim_prefix("UAL/").trim_suffix("_Loop"), player.speed_scale]


# --- Measurements -----------------------------------------------------------

func _report(s: Dictionary) -> void:
	var cap: Array = s.window
	var steady: Array[Dictionary] = []
	for smp in _samples:
		if float(smp.t) >= float(cap[0]) and float(smp.t) <= float(cap[1]):
			steady.append(smp)
	var slide_num: float = 0.0
	var slide_den: float = 0.0
	var body: float = 0.0
	var min_h: float = INF
	var aim_yaw: Array[float] = []
	var aim_pitch: Array[float] = []
	var legs_off: Array[float] = []
	var hips: Array[float] = [INF, -INF]
	var states: Dictionary = {}
	for i in range(1, steady.size()):
		var a: Dictionary = steady[i - 1]
		var b: Dictionary = steady[i]
		var dt: float = maxf(float(b.t) - float(a.t), 0.0001)
		var bv: Vector3 = (b.pos as Vector3) - (a.pos as Vector3)
		body += Vector2(bv.x, bv.z).length() / dt
		for k in 4:
			var p0: Vector3 = a.soles[k]
			var p1: Vector3 = b.soles[k]
			var h: float = (p0.y + p1.y) * 0.5 - (b.pos as Vector3).y
			min_h = minf(min_h, h)
			var w: float = clampf((CONTACT_H - h) / CONTACT_H, 0.0, 1.0)
			if w > 0.0:
				slide_num += w * Vector2(p1.x - p0.x, p1.z - p0.z).length() / dt
				slide_den += w
		var f: Vector3 = b.facing
		var barrel: Vector3 = b.barrel
		aim_yaw.append(rad_to_deg(Vector2(f.x, f.z).angle_to(Vector2(barrel.x, barrel.z))))
		aim_pitch.append(rad_to_deg(asin(clampf(barrel.y, -1.0, 1.0))))
		legs_off.append(rad_to_deg(Vector2(f.x, f.z).angle_to(Vector2((b.legs as Vector3).x, (b.legs as Vector3).z))))
		hips[0] = minf(hips[0], float(b.hips_y))
		hips[1] = maxf(hips[1], float(b.hips_y))
		states[b.state] = int(states.get(b.state, 0)) + 1
	var n: int = maxi(steady.size() - 1, 1)
	body /= n
	var slide: float = slide_num / maxf(slide_den, 0.0001)
	var top_state: String = ""
	var top: int = 0
	for k in states:
		if int(states[k]) > top:
			top = int(states[k])
			top_state = String(k)
	print("LOCO %-16s body %4.1f m/s | slide %4.2f m/s (%3.0f%% of body) planted feet %.2f | sole min %+.3f m | hips %.2f..%.2f | legs vs aim %+4.0f deg (move %+4.0f) | barrel yaw err %4.1f/%4.1f deg pitch %+5.1f..%+5.1f | %s" % [
		s.id, body, slide, 100.0 * slide / maxf(body, 0.01) if body > 0.1 else 0.0,
		slide_den / (2.0 * n), min_h, hips[0], hips[1], _mean(legs_off),
		_move_angle(s), _mean_abs(aim_yaw), _max_abs(aim_yaw), _min(aim_pitch), _max(aim_pitch), top_state])
	if s.id == "start_stop" or s.id == "turn_in_place":
		var line: String = "LOCO   timeline %s:" % s.id
		var next: float = 0.0
		for smp in _samples:
			if float(smp.t) + 0.0001 >= next:
				var f: Vector3 = smp.facing
				var legs: Vector3 = smp.legs
				line += "\n LOCO     t=%.2f legs%+4.0f  %s" % [float(smp.t), rad_to_deg(Vector2(f.x, f.z).angle_to(Vector2(legs.x, legs.z))), smp.state]
				next += 0.1
		print(line)


func _move_angle(s: Dictionary) -> float:
	var m: Vector3 = s.move
	if m == Vector3.ZERO:
		return 0.0
	return rad_to_deg(Vector2(0, -1).angle_to(Vector2(m.x, m.z)))


func _mean(a: Array[float]) -> float:
	var t: float = 0.0
	for v in a:
		t += v
	return t / maxf(a.size(), 1)


func _mean_abs(a: Array[float]) -> float:
	var t: float = 0.0
	for v in a:
		t += absf(v)
	return t / maxf(a.size(), 1)


func _max_abs(a: Array[float]) -> float:
	var t: float = 0.0
	for v in a:
		t = maxf(t, absf(v))
	return t


func _min(a: Array[float]) -> float:
	var t: float = INF
	for v in a:
		t = minf(t, v)
	return t


func _max(a: Array[float]) -> float:
	var t: float = -INF
	for v in a:
		t = maxf(t, v)
	return t


# --- Clip calibration ---------------------------------------------------------

## Plays each locomotion clip in place and finds the body speed at which the
## planted feet stand still (weighted by how close each sole point is to the
## ground), the stride per cycle, and the phase where the left foot lands.
func _calibrate() -> void:
	var soldier := SoldierModel.create(_class_id)
	_world.add_child(soldier)
	await process_frame
	var sk: Skeleton3D = soldier.find_child("Skeleton3D", true, false)
	var player := AnimationPlayer.new()
	sk.add_child(player)
	player.root_node = NodePath("..")
	var lib_path: String = SoldierModel.VANGUARD_ANIMATIONS if _class_id == &"vanguard" else SoldierModel.RECRUIT_ANIMATIONS
	player.add_animation_library(&"UAL", load(lib_path) as AnimationLibrary)
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for mixer: Node in sk.find_children("*", "AnimationMixer", false, false):
		if mixer != player:
			(mixer as AnimationMixer).active = false
	for clip in ["Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Crouch_Fwd_Loop", "Walk_Formal_Loop"]:
		var a: Animation = player.get_animation("UAL/" + clip)
		player.play("UAL/" + clip)
		var n: int = 240
		var dt: float = a.length / n
		var rows: Array = []
		var left_fwd: Array = [-INF, 0.0]  # [left foot ahead of the right (m), phase]
		for i in n + 1:
			player.seek(a.length * i / n, true)
			sk.force_update_all_bone_transforms()
			var row: Array = []
			for side in ["L", "R"]:
				var f: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("DEF-foot." + side)).origin
				var t: Vector3 = sk.global_transform * sk.get_bone_global_pose(sk.find_bone("DEF-toe." + side)).origin
				row.append(f - Vector3(0, HEEL_DROP, 0))
				row.append(t)
			# The model faces -Z: the leading foot has the smaller z.
			var lead: float = (row[2] as Vector3).z - (row[0] as Vector3).z
			if lead > left_fwd[0]:
				left_fwd = [lead, float(i) / n]
			rows.append(row)
		var best: Array = [0.0, INF]
		for vi in 241:
			var v: float = vi * 0.05
			var num: float = 0.0
			var den: float = 0.0
			for i in n:
				for k in 4:
					var p0: Vector3 = rows[i][k]
					var p1: Vector3 = rows[i + 1][k]
					var w: float = clampf((CONTACT_H - (p0.y + p1.y) * 0.5) / CONTACT_H, 0.0, 1.0)
					if w > 0.0:
						num += w * Vector2(p1.x - p0.x, (p1.z - p0.z) - v * dt).length() / dt
						den += w
			var slide: float = num / maxf(den, 0.0001)
			if slide < best[1]:
				best = [v, slide]
		print("CALIBRATE %s %-16s length %.3f s | ground speed %.2f m/s (residual slide %.2f m/s) | stride %.2f m per cycle | left foot furthest ahead at phase %.3f" % [
			_class_id, clip, a.length, best[0], best[1], float(best[0]) * a.length, left_fwd[1]])
	soldier.free()
	quit(0)


# --- Contact sheet ----------------------------------------------------------

func _build_stage() -> void:
	DisplayServer.window_set_size(Vector2i(640, 360))
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.68, 0.74)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.ambient_light_energy = 0.7
	var we := WorldEnvironment.new()
	we.environment = env
	_world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	_world.add_child(sun)
	# A 1 m checker floor, so motion over the ground reads in a still frame.
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(0.5, 0.48, 0.42))
	img.set_pixel(1, 1, Color(0.5, 0.48, 0.42))
	img.set_pixel(1, 0, Color(0.42, 0.4, 0.35))
	img.set_pixel(0, 1, Color(0.42, 0.4, 0.35))
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = ImageTexture.create_from_image(img)
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	floor_mat.uv1_scale = Vector3(40, 40, 1)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_mesh.mesh = plane
	floor_mesh.material_override = floor_mat
	floor_mesh.position = Vector3(20, 0, 20)
	_world.add_child(floor_mesh)
	_decals = Node3D.new()
	_world.add_child(_decals)
	var made: Array = []
	for i in 2:
		var vp := SubViewport.new()
		vp.size = TILE
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vp.msaa_3d = Viewport.MSAA_4X
		root.add_child(vp)
		var cam := Camera3D.new()
		vp.add_child(cam)
		cam.current = true
		var label := Label.new()
		label.position = Vector2(6, 4)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		vp.add_child(label)
		made.append([vp, cam, label])
	_side_vp = made[0][0]
	_side_cam = made[0][1]
	_side_label = made[0][2]
	_fixed_vp = made[1][0]
	_fixed_cam = made[1][1]
	_fixed_label = made[1][2]
	_side_cam.fov = 30.0
	# The game's fixed camera (fov 60 on a 1080p screen) seen through a
	# 340 px tall window: same pixels per metre as in the game.
	_fixed_cam.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(30.0)) * TILE.y / 1080.0))
	var rows: int = _scenarios.size()
	_sheet_side = Image.create(TILE.x * COLUMNS, TILE.y * rows, false, Image.FORMAT_RGBA8)
	_sheet_fixed = Image.create(TILE.x * COLUMNS, TILE.y * rows, false, Image.FORMAT_RGBA8)
	# The fuel can of the carry scenario: island.gd's box fallback (0.18 x
	# 0.5 x 0.36) at CARRY_OFFSET (0.38, 0.25, 0.05) in the soldier's space.
	_can = MeshInstance3D.new()
	var can_mesh := BoxMesh.new()
	can_mesh.size = Vector3(0.18, 0.5, 0.36)
	_can.mesh = can_mesh
	var can_mat := StandardMaterial3D.new()
	can_mat.albedo_color = Color(0.75, 0.3, 0.1)
	_can.material_override = can_mat
	_world.add_child(_can)
	# The barrel / facing lines (thin boxes, redrawn each frame).
	for c in [Color(1, 0.15, 0.1), Color(0.1, 0.9, 0.2)]:
		var line := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.025, 3.0)
		line.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		line.material_override = m
		_world.add_child(line)
		_lines.append(line)


func _place_cameras() -> void:
	var at: Vector3 = _pos + Vector3(0, 0.95, 0)
	_side_cam.position = _pos + Vector3(4.2, 1.7, -2.0)
	_side_cam.look_at(at)
	var pitch: float = deg_to_rad(35.0)
	var focus: Vector3 = _pos + Vector3(0, 1, 0)
	_fixed_cam.position = focus + Vector3(0, sin(pitch), cos(pitch)) * 10.0
	_fixed_cam.look_at(focus)
	var carry: bool = bool(_scenarios[_scenario].carry)
	_can.visible = carry
	if carry:
		_can.global_transform = Transform3D(_soldier.basis.orthonormalized(), _pos + _soldier.basis.orthonormalized() * (CARRY_OFFSET + Vector3(0, 0.25, 0)))
	# Barrel (red) from the muzzle; facing (green) at the same height.
	if _lines.size() >= 2 and _gun_muzzle() != null:
		var m: Vector3 = _gun_muzzle().global_position
		var barrel: Vector3 = -_gun_muzzle().global_basis.z.normalized()
		var red: MeshInstance3D = _lines[0]
		red.global_transform = Transform3D(Basis.looking_at(barrel, Vector3.UP), m + barrel * 1.5)
		var green: MeshInstance3D = _lines[1]
		green.global_transform = Transform3D(Basis.looking_at(_facing, Vector3.UP), m + _facing * 1.5 + Vector3(0, 0.03, 0))


func _mark_contacts(smp: Dictionary) -> void:
	if _samples.size() < 2:
		return
	var prev: Dictionary = _samples[-2]
	var dt: float = maxf(float(smp.t) - float(prev.t), 0.0001)
	for k in [1, 3]:  # toes: one mark per frame per planted foot
		var p0: Vector3 = prev.soles[k]
		var p1: Vector3 = smp.soles[k]
		if p1.y - (smp.pos as Vector3).y > CONTACT_H:
			continue
		var slide: float = Vector2(p1.x - p0.x, p1.z - p0.z).length() / dt
		var mark := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.035
		cyl.bottom_radius = 0.035
		cyl.height = 0.006
		mark.mesh = cyl
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.1, 0.85, 0.2) if slide < 0.4 else Color(1.0, 0.85, 0.1) if slide < 1.5 else Color(1.0, 0.15, 0.1)
		mark.material_override = m
		mark.position = Vector3(p1.x, 0.01, p1.z)
		_decals.add_child(mark)
		_marks.append(mark)


func _set_captions(s: Dictionary) -> void:
	var state: String = _samples[-1].state if not _samples.is_empty() else ""
	var text: String = "%s  t=%.2f\n%s" % [s.id, _t, state]
	_side_label.text = text
	_fixed_label.text = text


func _grab(column: int) -> void:
	var at := Vector2i(column * TILE.x, _scenario * TILE.y)
	var a: Image = _side_vp.get_texture().get_image()
	a.convert(Image.FORMAT_RGBA8)
	_sheet_side.blit_rect(a, Rect2i(Vector2i.ZERO, TILE), at)
	var b: Image = _fixed_vp.get_texture().get_image()
	b.convert(Image.FORMAT_RGBA8)
	_sheet_fixed.blit_rect(b, Rect2i(Vector2i.ZERO, TILE), at)


func _finish() -> void:
	if _mode == "sheet":
		for img in [_sheet_side, _sheet_fixed]:
			if _scale < 1.0:
				img.resize(int(img.get_width() * _scale), int(img.get_height() * _scale), Image.INTERPOLATE_LANCZOS)
		var e1: Error = _sheet_side.save_png(_out + "_side.png")
		var e2: Error = _sheet_fixed.save_png(_out + "_fixed.png")
		print("LOCOMOTION SHEET: %s_side.png (%d) %s_fixed.png (%d)" % [_out, e1, _out, e2])
	_soldier.free()
	_soldier = null
	quit(0)
