extends SceneTree
## Render actual Recruit/Vanguard locomotion to PNG frames (GPU required).
## godot --path . --script res://tools/dev/movement_preview.gd -- <frame directory>
const DT: float = 1.0 / 30.0
const TILE := Vector2i(300, 300)
var _views: Array[Dictionary] = []
var _out: String


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		print("Usage (GPU): movement_preview.gd -- <frame directory>")
		quit(1)
		return
	_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	DisplayServer.window_set_size(Vector2i(900, 600))
	root.size = Vector2i(900, 600)
	var speeds: Array[float] = [1.0, 6.0, 9.6]
	var names: Array[String] = ["Walk", "Jog", "Sprint"]
	for row in 2:
		for column in 3:
			_build_view(&"recruit" if row == 0 else &"vanguard", speeds[column], column == 2,
				Vector2(column * TILE.x, row * TILE.y), names[column])
	call_deferred("_render")


func _build_view(id: StringName, speed: float, sprint: bool, at: Vector2, title: String) -> void:
	var vp := SubViewport.new()
	vp.size = TILE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	var image := TextureRect.new()
	image.texture = vp.get_texture()
	image.position = at
	image.size = Vector2(TILE)
	root.add_child(image)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.28, 0.30, 0.33)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.78, 0.82)
	env.environment.ambient_light_energy = 0.7
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	vp.add_child(sun)
	var pattern := Image.create(2, 2, false, Image.FORMAT_RGB8)
	for x in 2:
		for y in 2:
			pattern.set_pixel(x, y, Color(0.45, 0.45, 0.44) if x == y else Color(0.36, 0.36, 0.35))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(pattern)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.uv1_scale = Vector3(40, 40, 1)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.material_override = mat
	vp.add_child(ground)
	var soldier := SoldierModel.create(id)
	vp.add_child(soldier)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.current = true
	vp.add_child(cam)
	var label := Label.new()
	label.position = at + Vector2(8, 6)
	label.text = "%s / %s\n%.1f m/s" % [String(id).capitalize(), title, speed]
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	root.add_child(label)
	_views.append({"soldier": soldier, "camera": cam, "speed": speed, "sprint": sprint})


func _render() -> void:
	await process_frame
	root.content_scale_size = Vector2i(900, 600)
	root.size = Vector2i(900, 600)
	DisplayServer.window_set_size(Vector2i(900, 600))
	for frame in 114:
		for view: Dictionary in _views:
			var soldier: SoldierModel = view.soldier
			soldier.animate(1.0, 0.0, view.sprint, DT)
			soldier.position += Vector3.FORWARD * float(view.speed) * DT
			var cam: Camera3D = view.camera
			cam.position = soldier.position + Vector3(4.0, 1.6, -2.0)
			cam.look_at(soldier.position + Vector3(0, 1.0, 0))
		await process_frame
		await RenderingServer.frame_post_draw
		if frame >= 30:
			var error: Error = root.get_texture().get_image().save_png(_out.path_join("frame_%03d.png" % (frame - 30)))
			if error != OK:
				push_error("Cannot save locomotion preview frame: %s" % error_string(error))
				quit(1)
				return
	print("MOVEMENT PREVIEW: 84 frames at 30 fps saved to " + _out)
	quit()
