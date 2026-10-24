extends SceneTree
## Renders each weapon's model (WeaponModel.build_parts, the GLB the player holds) from a three-quarter
## view into game/ui/art/weapons/<id>.png: the loadout's weapon pictures. The renderer needs a window,
## so run it without --headless:
##   godot --path . --script res://tools/dev/weapon_icon_render.gd
## Then run the import once (godot --headless --path . --import) so the PNGs get their .import files.
##
## The picture has a transparent background, so the panel colour shows through and the gun reads on any
## card. A rim light behind and above separates the dark metal from a dark panel.

const OUT_DIR: String = "res://game/ui/art/weapons"
## Picture size of each icon (the loadout shows it at about 2.5 : 1, bigger than the picture).
const PICTURE := Vector2i(480, 192)
## Share of the framing box left as margin around the gun: less than before, so the weapon fills the card.
const MARGIN: float = 0.02
## Vertical field of view of the render camera (degrees).
const FOV: float = 30.0


func _initialize() -> void:
	call_deferred("_render_all")


func _render_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# A SubViewport with a transparent background: the window and its boot splash never enter the picture.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 384)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.3
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.35
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
	key.light_energy = 2.8
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	fill.light_energy = 1.1
	viewport.add_child(fill)
	# Rim light: from behind and above, to draw an edge on dark metal against a dark panel.
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(20.0, 150.0, 0.0)
	rim.light_energy = 2.4
	rim.light_color = Color(0.85, 0.92, 1.0)
	viewport.add_child(rim)
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.current = true
	viewport.add_child(camera)
	for id: StringName in WeaponModel.IDS:
		var weapon: WeaponModel = WeaponModel.build_parts(id)
		viewport.add_child(weapon)
		await process_frame  # the transform is only valid once the weapon is in the tree
		var bounds: AABB = _local_bounds(weapon)
		weapon.position = -bounds.get_center()
		var radius: float = bounds.size.length() * 0.5
		var distance: float = radius * 3.0 / tan(deg_to_rad(FOV) * 0.5) * 0.5
		# Three-quarter: from the muzzle side and above, looking at the middle of the gun.
		camera.position = Vector3(-0.55, 0.42, 0.72).normalized() * distance
		camera.look_at(Vector3.ZERO, Vector3.UP)
		await RenderingServer.frame_post_draw
		var frame: Image = viewport.get_texture().get_image()
		var window: Rect2i = _framing(weapon, bounds, camera, frame.get_size())
		var crop: Image = frame.get_region(window)
		crop.resize(PICTURE.x, PICTURE.y, Image.INTERPOLATE_LANCZOS)
		crop.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, id]))
		print("RENDERED %s (bounds %s)" % [id, bounds.size])
		viewport.remove_child(weapon)
		weapon.free()
	quit(0)


## The part of the frame that holds the gun: the projected corners of its bounds, grown by a margin
## and widened to the picture's aspect, kept inside the frame.
func _framing(weapon: Node3D, bounds: AABB, camera: Camera3D, frame: Vector2i) -> Rect2i:
	var box := Rect2()
	for i in 8:
		var corner: Vector3 = bounds.position + bounds.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
		var point: Vector2 = camera.unproject_position(weapon.to_global(corner))
		box = Rect2(point, Vector2.ZERO) if i == 0 else box.expand(point)
	box = box.grow(maxf(box.size.x, box.size.y) * MARGIN)
	var aspect: float = float(PICTURE.x) / PICTURE.y
	var size: Vector2 = box.size
	if size.x / size.y < aspect:
		size.x = size.y * aspect
	else:
		size.y = size.x / aspect
	var window := Rect2(box.get_center() - size * 0.5, size)
	window.position = window.position.clamp(Vector2.ZERO, Vector2(frame) - window.size)
	return Rect2i(window)


## The bounds of the vertices of every mesh of `weapon`, in the weapon's own space. The mesh's stored
## AABB is not used: it can be shorter than the geometry, and then the stock fell outside the framing.
func _local_bounds(weapon: Node3D) -> AABB:
	var low := Vector3(INF, INF, INF)
	var high := -low
	var to_weapon: Transform3D = weapon.global_transform.affine_inverse()
	for mesh: MeshInstance3D in weapon.find_children("*", "MeshInstance3D", true, false):
		var to_weapon_from_mesh: Transform3D = to_weapon * mesh.global_transform
		for vertex: Vector3 in mesh.mesh.get_faces():
			var point: Vector3 = to_weapon_from_mesh * vertex
			low = low.min(point)
			high = high.max(point)
	return AABB(low, high - low)


