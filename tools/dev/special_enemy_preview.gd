extends SceneTree
## GPU contact sheet and animation frames of all six actual horde models.
## godot --path . --script res://tools/dev/special_enemy_preview.gd -- <frame directory>
const Specials = preload("res://game/world/special_enemy_model.gd")
const SIZE := Vector2i(1200, 800)
const TILE := Vector2i(400, 400)
var _out: String
var _views: Array[Dictionary] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty() or DisplayServer.get_name() == "headless":
		print("Usage (GPU): special_enemy_preview.gd -- <frame directory>")
		quit(1)
		return
	_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	for i in 6:
		_build_view(Specials.KINDS[i], Vector2((i % 3) * TILE.x, (i / 3) * TILE.y))
	call_deferred("_render")


func _build_view(kind: int, at: Vector2) -> void:
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
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.24, 0.26, 0.29)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75, 0.78, 0.82)
	environment.environment.ambient_light_energy = 0.8
	vp.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, -35, 0)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	vp.add_child(sun)
	var plane := MeshInstance3D.new()
	var ground := PlaneMesh.new()
	ground.size = Vector2(40, 40)
	plane.mesh = ground
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.31, 0.32, 0.33)
	plane.material_override = mat
	vp.add_child(plane)
	var map := IslandMap.new()
	map.field = FlowField.new(32, 32)
	var h := Horde.new(map.field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 81 + kind
	var index: int = h.add(Vector3.ZERO, kind, rng)
	h.velocities[index] = Vector3(0, 0, h.speeds[index])
	h.attack_cd[index] = 99.0
	h.target = Vector3(0, 0, 50)
	var view := ZombieHordeView.new()
	vp.add_child(view)
	var cam := Camera3D.new()
	var type: GameData.EnemyType = h.types[kind]
	var factor: float = maxf(type.height / 1.7, type.radius_scale * 0.85)
	cam.fov = 33.0
	cam.position = Vector3(2.5, 1.8, 4.0) * factor
	vp.add_child(cam)
	cam.basis = Basis.looking_at(Vector3(0, type.height * 0.53, 0) - cam.position, Vector3.UP)
	cam.current = true
	var label := Label.new()
	label.position = at + Vector2(12, 9)
	label.text = type.display_name
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	root.add_child(label)
	_views.append({"view": view, "horde": h, "map": map})


func _render() -> void:
	await process_frame
	root.content_scale_size = SIZE
	root.size = SIZE
	DisplayServer.window_set_size(SIZE)
	for frame in 105:
		var now: float = float(frame) / 30.0
		for v: Dictionary in _views:
			(v.view as ZombieHordeView).draw(v.horde, v.map, now, 0.0)
		await process_frame
		await RenderingServer.frame_post_draw
		if frame >= 30:
			var error: Error = root.get_texture().get_image().save_png(_out.path_join("frame_%03d.png" % (frame - 30)))
			if error != OK:
				push_error(error_string(error))
				quit(1)
				return
	print("SPECIAL PREVIEW: 75 actual model frames at 30 fps")
	quit()
