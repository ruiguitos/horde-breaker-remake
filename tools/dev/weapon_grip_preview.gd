extends SceneTree
## GPU captures of the five fitted first-person grips, with an isolated world.
## godot --path . --script res://tools/dev/weapon_grip_preview.gd -- [weapon] [view]
## Views: first_person, left, right, ads, wall. No args captures all five guns.

const OUTPUT: String = "res://docs/design/weapon_grips/"
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var model: ViewModel
var jobs: Array[Dictionary] = []
var job_index: int = 0
var frames: int = 0

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for weapon: StringName in WeaponModel.IDS:
		if not args.is_empty() and String(weapon) != args[0]:
			continue
		for view: String in ["first_person", "left", "right", "ads", "wall"]:
			if args.size() > 1 and view != args[1]:
				continue
			jobs.append({"weapon": weapon, "view": view})
	if jobs.is_empty():
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.34, 0.38, 0.41)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	var env := WorldEnvironment.new()
	env.environment = environment
	world.add_child(env)
	for angles: Vector3 in [Vector3(-35, -30, 0), Vector3(-20, 135, 0)]:
		var light := DirectionalLight3D.new()
		light.rotation_degrees = angles
		light.light_energy = 1.5
		world.add_child(light)
	camera = Camera3D.new()
	camera.near = 0.025
	world.add_child(camera)
	camera.make_current()
	next_job()

func next_job() -> void:
	if model != null:
		model.queue_free()
	model = ViewModel.create(&"recruit")
	world.add_child(model)
	var job: Dictionary = jobs[job_index]
	model.set_weapon(job["weapon"])
	var view: String = job["view"]
	camera.transform = Transform3D.IDENTITY
	camera.fov = 70.0
	if view in ["left", "right"]:
		model.transform = Transform3D.IDENTITY
		var target: Vector3 = model._model.support_point + Vector3(0, 0.025, 0)
		var offset := Vector3(0.25, 0.16, 0.16)
		if view == "right":
			target = Vector3(0, -0.015, 0.025)
			if job["weapon"] == &"shotgun":
				target = Vector3(0, 0.0, 0.065)
			offset = Vector3(-0.27, 0.11, 0.21)
		camera.position = target + offset
		camera.look_at(target)
		camera.fov = 43.0
	elif view == "ads":
		model.aim = 1.0
		model.update(0.0, 0.0, 0.0, 0.0)
		camera.fov *= 0.75
	elif view == "wall":
		model.update(0.0, ViewModel.MAX_PULL, 0.0, 0.0)
	frames = 0

func _process(_delta: float) -> bool:
	if model == null:
		return false
	frames += 1
	if frames == 12:
		RenderingServer.frame_post_draw.connect(capture, CONNECT_ONE_SHOT)
	return false

func capture() -> void:
	var job: Dictionary = jobs[job_index]
	var path: String = OUTPUT + String(job["weapon"]) + "_" + String(job["view"]) + ".png"
	var error: Error = viewport.get_texture().get_image().save_png(path)
	if error != OK:
		print("CAPTURE FAILED: ", path, " ", error)
		quit(1)
		return
	print("CAPTURE: ", path)
	job_index += 1
	if job_index == jobs.size():
		quit()
	else:
		next_job.call_deferred()
