extends SceneTree
## The whole original scenery kit in one studio picture: the five beach props in
## the back row and the eight facade pieces in the front row.
##   godot --path . --resolution 1280x720 --windowed --script res://tools/dev/scenery_kit_preview.gd -- <out.png>
## Needs the kit imported: open the editor once, or run `--headless --import`.

const KIT = preload("res://game/world/scenery_kit.gd")
const GAP: float = 0.7  ## metres between two pieces of the same row

var _out: String = "user://scenery_kit.png"
var _frame: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0]
	# This is a studio, not a game start: the boot splash would cover the picture.
	var splash: Node = root.get_node_or_null("BootSplashPlus")
	if splash != null:
		splash.queue_free()
	var stage := Node3D.new()
	root.add_child(stage)
	_studio(stage)
	_row(stage, KIT.BEACH, -2.6)
	_row(stage, KIT.COASTAL, 2.6)
	var camera := Camera3D.new()
	camera.fov = 52.0
	stage.add_child(camera)
	# look_at() needs the node in the tree, which it is not during _initialize().
	camera.look_at_from_position(Vector3(0, 5.5, 13.5), Vector3(0, 1.1, 0), Vector3.UP)
	camera.current = true


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame >= 40:
		root.get_viewport().get_texture().get_image().save_png(_out)
		print("saved ", _out)
		quit(0)
	return false


## Ground, sky and one key light, so the preview reads without the game.
func _studio(stage: Node3D) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(36, 18)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.16, 0.17, 0.18)
	ground_material.roughness = 0.95
	ground.material_override = ground_material
	stage.add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-44, 205, 0)  # from behind the camera: the pieces face us
	sun.light_energy = 2.6
	stage.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 20, 0)
	fill.light_energy = 0.45
	fill.light_color = Color(0.75, 0.82, 0.95)
	stage.add_child(fill)
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.22, 0.24, 0.27)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.70, 0.76, 0.84)
	environment.ambient_light_energy = 1.4
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.5
	world.environment = environment
	stage.add_child(world)


## Lays one row out centred on x, spaced by each piece's own width.
func _row(stage: Node3D, pieces: Array[String], z: float) -> void:
	var built: Array[Node3D] = []
	var total: float = 0.0
	for piece: String in pieces:
		var node := KIT.build(piece) as Node3D
		built.append(node)
		total += _width(node) + GAP
	total -= GAP
	var x: float = -total * 0.5
	for node: Node3D in built:
		var width: float = _width(node)
		node.position = Vector3(x + width * 0.5, 0, z)
		stage.add_child(node)
		x += width + GAP


## Width (x) of a piece, from its meshes, before it enters the tree.
func _width(node: Node) -> float:
	var widest: float = 0.1
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			widest = maxf(widest, mesh_instance.mesh.get_aabb().size.x * mesh_instance.scale.x)
	for child: Node in node.get_children():
		widest = maxf(widest, _width(child))
	return widest
