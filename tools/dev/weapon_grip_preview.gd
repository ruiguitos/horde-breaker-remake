extends SceneTree
## GPU captures of the five fitted first-person grips, with an isolated world.
## godot --path . --script res://tools/dev/weapon_grip_preview.gd -- [weapon] [view] [output] [fov] [aim]
## Views: first_person, left, right, ads, wall. No args captures all five guns.

const OUTPUT: String = "res://docs/design/weapon_grips/"
var viewport: SubViewport
var world: Node3D
var camera: Camera3D
var model: ViewModel
var jobs: Array[Dictionary] = []
var job_index: int = 0
var frames: int = 0
var output: String = OUTPUT
var base_fov: float = 70.0
var ads_amount: float = 1.0
var scope: Control

func _initialize() -> void:
	call_deferred("setup")

func setup() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 2:
		output = args[2].trim_suffix("/") + "/"
	if args.size() > 3:
		base_fov = float(args[3])
	if args.size() > 4:
		ads_amount = clampf(float(args[4]), 0, 1)
	DirAccess.make_dir_recursive_absolute(output)
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
	var layer := CanvasLayer.new()
	viewport.add_child(layer)
	scope = (load("res://game/ui/scope_overlay.gd") as GDScript).new()
	layer.add_child(scope)
	# A distant checkerboard makes a blocked optic or central sight line visible.
	if output != OUTPUT:
		for x: int in range(-6, 7):
			for y: int in range(-4, 5):
				var tile := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2.ONE
				tile.mesh = quad
				tile.position = Vector3(x, y, -8)
				var material := StandardMaterial3D.new()
				material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				material.albedo_color = Color(0.55, 0.64, 0.68) if (x + y) % 2 == 0 else Color(0.36, 0.44, 0.49)
				tile.material_override = material
				world.add_child(tile)
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
	camera.fov = base_fov
	scope.visible = false
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
		model.aim = ads_amount
		model.update(0.0, 0.0, 0.0, 0.0)
		camera.fov *= lerpf(1.0, 0.75, ads_amount)
		scope.visible = model.is_scoped()
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
	var path: String = output + String(job["weapon"]) + "_" + String(job["view"]) + ".png"
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
