extends ClassPreview
## A real coastal equipment shelter, rendered once behind the Armory UI.
## Reuses the playable rig and CC0 textures/props already bundled with the game.

var _world: SubViewport


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = SubViewport.new()
	_world.own_world_3d = true
	_world.msaa_3d = Viewport.MSAA_2X
	add_child(_world)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("487c9d")
	sky.sky_horizon_color = Color("bbd7db")
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("adc9d5")
	environment.ambient_light_energy = 0.55
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var env := WorldEnvironment.new()
	env.environment = environment
	_world.add_child(env)
	var daylight := DirectionalLight3D.new()
	daylight.rotation_degrees = Vector3(-38, -125, 0)
	daylight.light_energy = 1.2
	daylight.light_color = Color("c7e5f2")
	daylight.shadow_enabled = true
	_world.add_child(daylight)
	var camera := Camera3D.new()
	camera.position = Vector3(0.4, 1.9, 6.3)
	camera.fov = 38.0
	_world.add_child(camera)
	camera.look_at(Vector3(0.4, 1.25, 0))
	var stone := _surface("stone_wall_04", Vector2(2, 2))
	var floor_mat := _surface("dirty_concrete", Vector2(3, 3))
	var wood := _surface("weathered_planks", Vector2.ONE)
	_box("Floor", Vector3(18, 0.2, 14), Vector3(0, -0.1, -2), floor_mat)
	# Opening on the right: the room and Atlantic are part of the same world.
	_box("BackWall", Vector3(7, 5, 0.5), Vector3(-3.8, 2.5, -2.8), stone)
	_box("DoorJamb", Vector3(0.6, 5, 0.7), Vector3(0, 2.5, -2.8), stone)
	_box("DoorLintel", Vector3(6.5, 0.8, 0.7), Vector3(3.3, 3.3, -2.8), stone)
	_box("RightWall", Vector3(1, 5, 0.5), Vector3(6.8, 2.5, -2.8), stone)
	_box("Roof", Vector3(17, 0.3, 10), Vector3(0, 3.9, -1), wood)
	for x in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		_box("RoofBeam", Vector3(0.18, 0.3, 9), Vector3(x, 3.7, -1), wood)
	var pedestal := MeshInstance3D.new()
	pedestal.name = "ContractorPlatform"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.1
	disc.bottom_radius = 1.16
	disc.height = 0.12
	pedestal.mesh = disc
	pedestal.material_override = floor_mat
	pedestal.position = Vector3(-0.6, -0.05, 0.1)
	_world.add_child(pedestal)
	var dark := _plain(Color("253b42"))
	_box("Workbench", Vector3(2.8, 0.16, 0.8), Vector3(-2.7, 0.85, -1.85), wood)
	for x in [-3.8, -1.6]:
		_box("BenchLeg", Vector3(0.12, 0.8, 0.6), Vector3(x, 0.4, -1.85), dark)
	_prop(&"crate", Vector3(-3.2, 0, 0.2), 0.8)
	_prop(&"crate", Vector3(-4.0, 0, 0.8), 0.65)
	_prop(&"crate", Vector3(1.5, 0, -2.3), 0.6)
	_prop(&"generator", Vector3(-1.7, 0, -2.15), 0.65)
	_prop(&"jerrycan", Vector3(-3.1, 0.94, -1.85), 0.4)
	_box("CompanyFlag", Vector3(0.8, 1.35, 0.04), Vector3(-1.8, 2.45, -2.5), _plain(Color("143540")))
	var sign := Label3D.new()
	sign.text = "S&C\nHALVARD"
	sign.font = UiTheme.heading_font()
	sign.font_size = 48
	sign.pixel_size = 0.002
	sign.modulate = UiTheme.TEXT
	sign.position = Vector3(-1.8, 2.45, -2.45)
	_world.add_child(sign)
	var lamp := _plain(Color("ffcb7a"))
	lamp.emission_enabled = true
	lamp.emission = Color("ffb95b")
	lamp.emission_energy_multiplier = 2.0
	_box("WorkLight", Vector3(0.14, 0.32, 0.14), Vector3(-2.9, 2.5, -2.4), lamp)
	var light := OmniLight3D.new()
	light.position = Vector3(-2.0, 2.5, 0.6)
	light.light_color = Color("ffc17e")
	light.light_energy = 4.0
	light.omni_range = 7.0
	light.shadow_enabled = true
	_world.add_child(light)
	_ocean()
	var rock := _surface("rock_face_03", Vector2.ONE)
	for i in 4:
		var cliff := MeshInstance3D.new()
		cliff.name = "DistantIsland"
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 12
		sphere.rings = 6
		cliff.mesh = sphere
		cliff.scale = Vector3(3.3, 1.4 + i * 0.15, 2)
		cliff.rotation_degrees = Vector3(13 * i, 27 * i, 11 * i)
		cliff.position = Vector3(3.2 + i * 1.3, -0.3, -23 - i * 0.5)
		cliff.material_override = rock
		_world.add_child(cliff)
	_box("Lighthouse", Vector3(0.45, 2.4, 0.45), Vector3(5.3, 2, -24), _plain(UiTheme.TEXT))
	_box("LighthouseRoof", Vector3(0.7, 0.2, 0.7), Vector3(5.3, 3.25, -24), _plain(Color("93432f")))
	for x in [0.7, 2.7, 4.7, 6.7]:
		_box("RailingPost", Vector3(0.07, 1.1, 0.07), Vector3(x, 0.55, -4.3), dark)
	_box("Railing", Vector3(6, 0.06, 0.06), Vector3(3.7, 1, -4.3), dark)
	set_class(class_id)


func set_class(id: StringName) -> void:
	class_id = id
	if _world == null or (_model != null and _model.class_id == id):
		return
	if _model != null:
		_world.remove_child(_model)
		_model.queue_free()
	_model = SoldierModel.create(id)
	_model.position = Vector3(-0.6, 0, 0.1)
	_model.rotation_degrees.y = 240.0
	_world.add_child(_model)


func _process(delta: float) -> void:
	if _model != null and _model.visible:
		_model.animate(0.0, 0.0, false, delta)


func show_character(on: bool) -> void:
	if _model != null:
		_model.visible = on


func set_weapon(id: StringName) -> void:
	if _model != null:
		_model.set_weapon(id)


func _ocean() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "Atlantic"
	var plane := PlaneMesh.new()
	plane.size = Vector2(180, 140)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	sea.mesh = plane
	sea.position = Vector3(0, -0.6, -76)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
		shader_type spatial;
		void vertex() {
			VERTEX.y += sin(VERTEX.x * 0.25 + TIME * 0.5) * 0.08
				+ cos(VERTEX.z * 0.4 + TIME * 0.7) * 0.06;
		}
		void fragment() {
			float wave = sin(UV.y * 280.0 + TIME * 0.5) * 0.5 + 0.5;
			ALBEDO = mix(vec3(0.055, 0.20, 0.26), vec3(0.18, 0.40, 0.44), wave);
			ROUGHNESS = 0.26;
			METALLIC = 0.25;
		}
	"""
	sea.material_override = material
	_world.add_child(sea)


func _box(label: String, dimensions: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	_world.add_child(mesh)


func _prop(id: StringName, at: Vector3, height: float) -> void:
	var prop: Node3D = IslandProps.create(id, height)
	if prop != null:
		prop.position += at
		_world.add_child(prop)


func _plain(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


func _surface(id: String, uv: Vector2) -> StandardMaterial3D:
	var material := _plain(Color.WHITE)
	var path: String = "res://assets/textures/polyhaven/" + id
	material.albedo_texture = load(path + "_diffuse.res") as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(path + "_nor_gl.res") as Texture2D
	material.roughness_texture = load(path + "_rough.res") as Texture2D
	material.uv1_scale = Vector3(uv.x, uv.y, 1)
	material.uv1_triplanar = true
	return material
