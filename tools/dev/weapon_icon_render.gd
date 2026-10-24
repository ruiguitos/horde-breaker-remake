extends SceneTree
## Renders each weapon's model (WeaponModel.build_parts, the GLB the player holds) from a three-quarter
## view into game/ui/art/weapons/<id>.png: the loadout's weapon pictures. The renderer needs a window,
## so run it without --headless:
##   godot --path . --script res://tools/dev/weapon_icon_render.gd
## Then run the import once (godot --headless --path . --import) so the PNGs get their .import files.

const OUT_DIR: String = "res://game/ui/art/weapons"
## Picture size of each icon (the loadout shows it at about 2.5 : 1).
const PICTURE := Vector2i(240, 96)
## The panel colour behind the icons (UiTheme.PANEL), so no alpha is needed.
const BACKGROUND := Color("0f2830")
## Vertical field of view of the render camera (degrees).
const FOV: float = 30.0


func _initialize() -> void:
	call_deferred("_render_all")


func _render_all() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	# The boot splash and the other interface nodes sit in the same root: hide them, or they cover the gun.
	for child: Node in root.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		elif child is CanvasItem:
			(child as CanvasItem).visible = false
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = BACKGROUND
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 0.7
	var world := WorldEnvironment.new()
	world.environment = environment
	root.add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35.0, -40.0, 0.0)
	key.light_energy = 1.3
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	fill.light_energy = 0.4
	root.add_child(fill)
	var camera := Camera3D.new()
	camera.fov = FOV
	camera.current = true
	root.add_child(camera)
	for id: StringName in WeaponModel.IDS:
		var weapon: WeaponModel = WeaponModel.build_parts(id)
		root.add_child(weapon)
		var bounds: AABB = _local_bounds(weapon)
		weapon.position = -bounds.get_center()
		var radius: float = bounds.size.length() * 0.5
		var distance: float = radius * 3.0 / tan(deg_to_rad(FOV) * 0.5) * 0.5
		# Three-quarter: from the muzzle side and above, looking at the middle of the gun.
		camera.position = Vector3(-0.55, 0.42, 0.72).normalized() * distance
		camera.look_at(Vector3.ZERO, Vector3.UP)
		await RenderingServer.frame_post_draw
		var frame: Image = root.get_texture().get_image()
		var window: Rect2i = _framing(weapon, bounds, camera, frame.get_size())
		var crop: Image = frame.get_region(window)
		crop.resize(PICTURE.x, PICTURE.y, Image.INTERPOLATE_LANCZOS)
		crop.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT_DIR, id]))
		print("RENDERED %s (bounds %s)" % [id, bounds.size])
		root.remove_child(weapon)
		weapon.free()
	quit(0)


## The part of the frame that holds the gun: the projected corners of its bounds, grown by a margin
## and widened to the picture's aspect, kept inside the frame. A crop of the whole frame cut the stocks.
func _framing(weapon: Node3D, bounds: AABB, camera: Camera3D, frame: Vector2i) -> Rect2i:
	var box := Rect2()
	for i in 8:
		var corner: Vector3 = bounds.position + bounds.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1)
		var point: Vector2 = camera.unproject_position(weapon.to_global(corner))
		box = Rect2(point, Vector2.ZERO) if i == 0 else box.expand(point)
	box = box.grow(maxf(box.size.x, box.size.y) * 0.2)
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
