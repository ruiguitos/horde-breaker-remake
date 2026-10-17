extends ClassPreview
## A coastal equipment shelter at dusk, rendered behind the Armory UI.
## Warm lantern-lit stone interior; a big stone arch opens onto a bright
## Atlantic with a cliff islet and a white lighthouse. Reuses the playable
## rig and the CC0 textures/props already bundled (assets/LICENSES.md);
## everything else is primitive geometry built here.
##
## Cheap on purpose: one SubViewport, six lights (two with shadows), no
## volumetrics. The sun only lights the exterior (render layer 2) so the
## interior keeps its warm lantern mood.

const EXTERIOR_LAYER := 2
const PEDESTAL_TOP := 0.22
const MODEL_AT := Vector3(0.3, PEDESTAL_TOP, 0.55)
const ARCH_CENTER_X := 3.1
const ARCH_HALF_WIDTH := 2.0
const ARCH_SPRING := 1.7
const WALL_Z := -3.2

var _world: SubViewport


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = SubViewport.new()
	_world.own_world_3d = true
	_world.msaa_3d = Viewport.MSAA_2X
	add_child(_world)
	_environment()
	var camera := Camera3D.new()
	camera.position = Vector3(0.7, 1.5, 6.6)
	camera.fov = 42.0
	_world.add_child(camera)
	camera.look_at(Vector3(1.0, 1.0, 0))
	_lights()
	_room()
	_arch()
	_dressing()
	_exterior()
	set_class(class_id)


func _environment() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("1d4a6e")
	sky.sky_horizon_color = Color("5f8ba3")
	sky.ground_horizon_color = Color("5f8ba3")
	sky.ground_bottom_color = Color("1f4c6b")
	sky.sky_energy_multiplier = 1.3
	environment.sky.sky_material = sky
	# Interior light comes from the lanterns; ambient is a dim warm fill and
	# the sky is not reflected indoors.
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("6a5240")
	environment.ambient_light_energy = 0.9
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.05
	environment.glow_enabled = true
	environment.glow_intensity = 0.9
	environment.glow_bloom = 0.05
	environment.glow_hdr_threshold = 1.1
	environment.ssr_enabled = true  # wet floor picks up the lanterns and the arch
	environment.ssr_max_steps = 48
	var env := WorldEnvironment.new()
	env.environment = environment
	_world.add_child(env)


func _lights() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-28, 28, 0)
	sun.light_energy = 1.7
	sun.light_color = Color("ffe9cc")
	sun.light_cull_mask = 1 << (EXTERIOR_LAYER - 1)
	_world.add_child(sun)
	# Key on the contractor: warm, from the lantern side.
	var key := SpotLight3D.new()
	key.name = "KeyLight"
	key.position = Vector3(-2.4, 3.4, 3.6)
	key.light_color = Color("ffd3a0")
	key.light_energy = 6.0
	key.spot_range = 10.0
	key.spot_angle = 26.0
	key.shadow_enabled = true
	_world.add_child(key)
	key.look_at(MODEL_AT + Vector3(0, 0.9, 0))
	_omni("WallLanternLight", Vector3(-2.5, 2.2, -2.5), Color("ff9d45"), 4.5, 7.0, true)
	_omni("CrateLanternLight", Vector3(-2.75, 1.05, 0.05), Color("ffa552"), 3.2, 5.0, false)
	# Low warm fill so the foreground cases read against the dark floor.
	_omni("ForegroundFill", Vector3(-3.0, 1.6, 2.6), Color("ffb36b"), 1.4, 4.0, false)
	# Cool daylight spilling in through the arch.
	_omni("ArchSpill", Vector3(ARCH_CENTER_X - 0.4, 1.6, WALL_Z + 0.9), Color("bcd6f2"), 2.2, 5.0, false)


func _omni(label: String, at: Vector3, colour: Color, energy: float, reach: float, shadow: bool) -> void:
	var light := OmniLight3D.new()
	light.name = label
	light.position = at
	light.light_color = colour
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.4
	light.shadow_enabled = shadow
	_world.add_child(light)


func _room() -> void:
	var floor_mat := _surface("stone_wall_02", Vector2(0.9, 0.9), Color(0.5, 0.45, 0.4))
	floor_mat.roughness_texture = null
	floor_mat.roughness = 0.22  # wet stone
	_box("Floor", Vector3(18, 0.2, 13), Vector3(0, -0.1, -1.0), floor_mat)
	var stone := _surface("stone_wall_04", Vector2(1.6, 1.6), Color(0.62, 0.52, 0.44))
	_box("LeftWall", Vector3(0.6, 6, 10), Vector3(-6.6, 3, 0.8), stone)
	_box("RightWall", Vector3(0.6, 6, 10), Vector3(7.6, 3, 0.8), stone)
	_box("Ceiling", Vector3(16, 0.3, 10), Vector3(0, 4.7, 0.8), _plain(Color("2a1d15")))
	for x in [-4.5, -1.5, 1.5, 4.5]:
		_box("CeilingBeam", Vector3(0.25, 0.35, 10), Vector3(x, 4.45, 0.8), _plain(Color("3b2a1e")))
	var pedestal := MeshInstance3D.new()
	pedestal.name = "ContractorPlatform"
	var disc := CylinderMesh.new()
	disc.top_radius = 1.15
	disc.bottom_radius = 1.25
	disc.height = PEDESTAL_TOP
	disc.radial_segments = 40
	pedestal.mesh = disc
	pedestal.material_override = _surface("stone_wall_02", Vector2(0.6, 0.6), Color(0.72, 0.66, 0.6))
	pedestal.position = Vector3(MODEL_AT.x, PEDESTAL_TOP * 0.5, MODEL_AT.z)
	_world.add_child(pedestal)
	var rim := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.12
	ring.outer_radius = 1.2
	rim.mesh = ring
	rim.material_override = _plain(Color("3a3029"))
	rim.position = Vector3(MODEL_AT.x, PEDESTAL_TOP, MODEL_AT.z)
	_world.add_child(rim)


## Back wall with a round-headed opening, carved with CSG once at load,
## framed by protruding voussoirs and jamb stones.
func _arch() -> void:
	var stone := _surface("stone_wall_04", Vector2(1.6, 1.6), Color(0.62, 0.52, 0.44))
	var wall := CSGCombiner3D.new()
	wall.name = "BackWall"
	wall.material_override = stone
	_world.add_child(wall)
	var block := CSGBox3D.new()
	block.size = Vector3(15, 6, 0.8)
	block.position = Vector3(0.5, 3, WALL_Z)
	wall.add_child(block)
	var opening := CSGBox3D.new()
	opening.operation = CSGShape3D.OPERATION_SUBTRACTION
	opening.size = Vector3(ARCH_HALF_WIDTH * 2, ARCH_SPRING + 0.2, 1.2)
	opening.position = Vector3(ARCH_CENTER_X, ARCH_SPRING * 0.5 - 0.1, WALL_Z)
	wall.add_child(opening)
	var round_head := CSGCylinder3D.new()
	round_head.operation = CSGShape3D.OPERATION_SUBTRACTION
	round_head.radius = ARCH_HALF_WIDTH
	round_head.height = 1.2
	round_head.sides = 32
	round_head.rotation_degrees = Vector3(90, 0, 0)
	round_head.position = Vector3(ARCH_CENTER_X, ARCH_SPRING, WALL_Z)
	wall.add_child(round_head)
	var trim := _surface("stone_wall_02", Vector2(0.5, 0.5), Color(0.66, 0.58, 0.5))
	var count := 13
	for i in count:
		var angle: float = PI * float(i) / float(count - 1)
		var radius: float = ARCH_HALF_WIDTH + 0.2
		var at := Vector3(ARCH_CENTER_X + cos(angle) * radius, ARCH_SPRING + sin(angle) * radius, WALL_Z + 0.1)
		var voussoir := _box("Voussoir", Vector3(0.42, 0.5, 1.0), at, trim)
		voussoir.rotation.z = angle - PI * 0.5
	for side in [-1.0, 1.0]:
		_box("ArchJamb", Vector3(0.42, ARCH_SPRING, 1.0), Vector3(ARCH_CENTER_X + side * (ARCH_HALF_WIDTH + 0.2), ARCH_SPRING * 0.5, WALL_Z + 0.1), trim)


func _dressing() -> void:
	_flag()
	_lantern("WallLantern", Vector3(-2.5, 2.05, -2.62), true)
	# Military cases and crates, left foreground and by the arch.
	var olive := _plain(Color("2c3427"))
	olive.roughness = 0.55
	var black := _plain(Color("1b1f1f"))
	black.roughness = 0.5
	_case(Vector3(-3.6, 0, 1.0), Vector3(1.3, 0.55, 0.75), black, 12.0)
	_case(Vector3(-3.5, 0.55, 0.95), Vector3(1.1, 0.42, 0.65), olive, 8.0)
	_case(Vector3(-2.6, 0, 2.6), Vector3(1.2, 0.5, 0.7), black, -6.0)
	_case(Vector3(-4.9, 0, -0.4), Vector3(1.3, 0.6, 0.8), olive, 25.0)
	_case(Vector3(-4.4, 0, -2.4), Vector3(1.5, 0.7, 0.6), black, 0.0)
	_case(Vector3(-2.7, 0, -0.05), Vector3(0.8, 0.5, 0.55), olive, -15.0)
	_case(Vector3(1.0, 0, -2.45), Vector3(1.1, 0.55, 0.6), olive, 4.0)
	_case(Vector3(1.05, 0.55, -2.45), Vector3(0.9, 0.4, 0.5), black, -8.0)
	_case(Vector3(5.9, 0, -2.2), Vector3(1.0, 0.6, 0.7), olive, -10.0)
	_prop(&"crate", Vector3(-5.6, 0, 1.6), 0.9)
	_prop(&"crate", Vector3(-1.5, 0, -2.5), 0.6)
	_prop(&"generator", Vector3(-2.3, 0, -2.45), 0.6)
	_prop(&"jerrycan", Vector3(-3.0, 0.97, 0.95), 0.42)
	_lantern("CrateLantern", Vector3(-2.75, 0.5, 0.0), false)
	var brass := _plain(Color("c8963c"))
	brass.metallic = 0.85
	brass.roughness = 0.3
	for i in 4:
		var cartridge := MeshInstance3D.new()
		cartridge.name = "Ammo"
		var shell := CylinderMesh.new()
		shell.top_radius = 0.028
		shell.bottom_radius = 0.032
		shell.height = 0.2
		cartridge.mesh = shell
		cartridge.material_override = brass
		cartridge.position = Vector3(-2.38 + i * 0.08, 0.6, 0.12)
		_world.add_child(cartridge)
	var helmet_green := _plain(Color("4a5236"))
	helmet_green.roughness = 0.7
	_helmet(Vector3(-4.0, 0.97, 1.0), helmet_green)
	_helmet(Vector3(-4.75, 0.6, -0.35), _plain(Color("6b6447")))
	var rope := MeshInstance3D.new()
	rope.name = "RopeCoil"
	var coil := TorusMesh.new()
	coil.inner_radius = 0.22
	coil.outer_radius = 0.4
	rope.mesh = coil
	rope.material_override = _plain(Color("6e5636"))
	rope.position = Vector3(5.4, 0.08, -1.3)
	_world.add_child(rope)


## Company flag: navy, anchor over three waves (original drawing).
func _flag() -> void:
	var svg := "<svg xmlns='http://www.w3.org/2000/svg' width='120' height='170' viewBox='0 0 120 170'>" \
		+ "<rect width='120' height='170' fill='#1c2c4c'/><rect x='5' y='5' width='110' height='160' fill='none' stroke='#2b416a' stroke-width='3'/>" \
		+ "<g fill='none' stroke='#b9cbe0' stroke-width='7' stroke-linecap='round' stroke-linejoin='round'>" \
		+ "<circle cx='60' cy='30' r='8'/><path d='M60 38v58M44 50h32M32 74c2 15 13 24 28 24s26-9 28-24M26 80l6-8 7 7M81 79l7-7 6 8'/>" \
		+ "<path d='M22 120c8-7 15-7 23 0s15 7 23 0 15-7 23 0 15 7 23 0' stroke-width='5'/><path d='M22 136c8-7 15-7 23 0s15 7 23 0 15-7 23 0 15 7 23 0' stroke-width='5'/></g></svg>"
	var image := Image.new()
	var material := _plain(Color.WHITE)
	if image.load_svg_from_string(svg, 2.0) == OK:
		image.generate_mipmaps()
		material.albedo_texture = ImageTexture.create_from_image(image)
	else:
		material.albedo_color = Color("1c2c4c")
	material.roughness = 0.95
	var cloth := MeshInstance3D.new()
	cloth.name = "CompanyFlag"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.25, 1.77)
	cloth.mesh = quad
	cloth.material_override = material
	cloth.position = Vector3(-1.45, 1.85, WALL_Z + 0.43)
	_world.add_child(cloth)
	var pole := MeshInstance3D.new()
	pole.name = "FlagPole"
	var rod := CylinderMesh.new()
	rod.top_radius = 0.025
	rod.bottom_radius = 0.025
	rod.height = 1.45
	pole.mesh = rod
	pole.material_override = _plain(Color("3b2a1e"))
	pole.rotation_degrees.z = 90
	pole.position = Vector3(-1.45, 2.76, WALL_Z + 0.45)
	_world.add_child(pole)


## Hurricane lantern: dark frame, glowing glass, plus a hanging bracket.
func _lantern(label: String, at: Vector3, on_wall: bool) -> void:
	var root := Node3D.new()
	root.name = label
	root.position = at
	_world.add_child(root)
	var metal := _plain(Color("1d1a17"))
	metal.metallic = 0.6
	metal.roughness = 0.45
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("ffcf8a")
	glass.emission_enabled = true
	glass.emission = Color("ffad55")
	glass.emission_energy_multiplier = 4.0
	_cylinder(root, 0.13, 0.14, 0.06, Vector3(0, 0.03, 0), metal)
	_cylinder(root, 0.09, 0.09, 0.24, Vector3(0, 0.18, 0), glass)
	_cylinder(root, 0.04, 0.12, 0.08, Vector3(0, 0.34, 0), metal)
	for x in [-0.1, 0.1]:
		_cylinder(root, 0.012, 0.012, 0.3, Vector3(x, 0.18, 0), metal)
	if on_wall:
		var bracket := _box("LanternBracket", Vector3(0.05, 0.05, 0.4), at + Vector3(0, 0.5, -0.12), metal)
		bracket.rotation_degrees.x = 0
		_box("LanternHook", Vector3(0.03, 0.12, 0.03), at + Vector3(0, 0.43, 0.06), metal)


func _cylinder(parent: Node3D, top: float, bottom: float, height: float, at: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 12
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)


## Hard-shell equipment case: body, a lid seam and two latches.
func _case(at: Vector3, size: Vector3, material: StandardMaterial3D, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "MilitaryCase"
	root.position = at
	root.rotation_degrees.y = yaw
	_world.add_child(root)
	var body := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	body.mesh = box
	body.material_override = material
	body.position.y = size.y * 0.5
	root.add_child(body)
	var seam := MeshInstance3D.new()
	var band := BoxMesh.new()
	band.size = Vector3(size.x + 0.02, 0.025, size.z + 0.02)
	seam.mesh = band
	seam.material_override = _plain(material.albedo_color.darkened(0.45))
	seam.position.y = size.y * 0.72
	root.add_child(seam)
	var steel := _plain(Color("8d8a80"))
	steel.metallic = 0.8
	steel.roughness = 0.35
	for side in [-0.3, 0.3]:
		var latch := MeshInstance3D.new()
		var piece := BoxMesh.new()
		piece.size = Vector3(0.09, 0.08, 0.03)
		latch.mesh = piece
		latch.material_override = steel
		latch.position = Vector3(side * size.x, size.y * 0.72, size.z * 0.5 + 0.015)
		root.add_child(latch)


func _helmet(at: Vector3, material: StandardMaterial3D) -> void:
	var helmet := MeshInstance3D.new()
	helmet.name = "Helmet"
	var dome := SphereMesh.new()
	dome.radius = 0.16
	dome.height = 0.16
	dome.is_hemisphere = true
	helmet.mesh = dome
	helmet.material_override = material
	helmet.position = at
	helmet.scale = Vector3(1.0, 1.0, 1.12)
	_world.add_child(helmet)
	var brim := MeshInstance3D.new()
	var lip := CylinderMesh.new()
	lip.top_radius = 0.18
	lip.bottom_radius = 0.18
	lip.height = 0.02
	brim.mesh = lip
	brim.material_override = material
	brim.position = at + Vector3(0, 0.01, 0)
	_world.add_child(brim)


## Terrace, railing, sea and the islet with its lighthouse, sun-lit only.
func _exterior() -> void:
	var dark := _plain(Color("1e2426"))
	dark.metallic = 0.5
	dark.roughness = 0.4
	var rail_z := WALL_Z - 1.9
	for x in [0.9, 2.1, 3.3, 4.5, 5.7]:
		_outside(_box("RailingPost", Vector3(0.06, 1.0, 0.06), Vector3(x, 0.5, rail_z), dark))
	_outside(_box("Railing", Vector3(6.0, 0.06, 0.06), Vector3(3.3, 1.0, rail_z), dark))
	_outside(_box("RailingLow", Vector3(6.0, 0.04, 0.04), Vector3(3.3, 0.55, rail_z), dark))
	_outside(_box("TerraceEdge", Vector3(9, 0.5, 0.5), Vector3(3.0, -0.25, rail_z - 0.2), _surface("stone_wall_02", Vector2(0.8, 0.8), Color(0.75, 0.7, 0.65))))
	_ocean()
	var rock := _surface("rock_face_03", Vector2(0.5, 0.5), Color(0.8, 0.74, 0.66))
	var islet := Vector3(5.2, -0.8, -34)
	for i in 5:
		var cliff := MeshInstance3D.new()
		cliff.name = "IsletCliff"
		var sphere := SphereMesh.new()
		sphere.radius = 1.0
		sphere.height = 2.0
		sphere.radial_segments = 14
		sphere.rings = 7
		cliff.mesh = sphere
		cliff.scale = Vector3(4.2 - i * 0.55, 3.0 - i * 0.25, 2.6)
		cliff.rotation_degrees = Vector3(6 * i, 33 * i, 4 * i)
		cliff.position = islet + Vector3(-3.0 + i * 1.6, 0, i * 0.4)
		cliff.material_override = rock
		_outside(cliff)
		_world.add_child(cliff)
	var grass := _plain(Color("5f7a3c"))
	var top := MeshInstance3D.new()
	top.name = "IsletTop"
	var cap := SphereMesh.new()
	cap.radius = 1.0
	cap.height = 2.0
	top.mesh = cap
	top.scale = Vector3(4.4, 0.35, 2.3)
	top.position = islet + Vector3(0.6, 2.25, 0.3)
	top.material_override = grass
	_outside(top)
	_world.add_child(top)
	var lime := _plain(Color("f1ede2"))
	var roof := _plain(Color("b4553a"))
	for house: Array in [[Vector3(-1.3, 2.75, 0.6), Vector3(1.2, 0.7, 0.9)], [Vector3(0.2, 2.8, 0.2), Vector3(1.4, 0.8, 1.0)], [Vector3(1.8, 2.7, 0.5), Vector3(0.9, 0.6, 0.8)]]:
		var at: Vector3 = islet + (house[0] as Vector3)
		var size: Vector3 = house[1]
		_outside(_box("IsletHouse", size, at, lime))
		_outside(_box("IsletRoof", Vector3(size.x + 0.15, 0.18, size.z + 0.15), at + Vector3(0, size.y * 0.5 + 0.09, 0), roof))
	var tower := islet + Vector3(2.6, 2.6, 0.2)
	_outside(_tower_part(Vector3(tower.x, tower.y + 1.2, tower.z), 0.32, 0.42, 2.4, lime))
	_outside(_tower_part(Vector3(tower.x, tower.y + 2.55, tower.z), 0.36, 0.36, 0.3, _plain(Color("d8e6ee"))))
	_outside(_tower_part(Vector3(tower.x, tower.y + 2.85, tower.z), 0.05, 0.42, 0.35, roof))


func _tower_part(at: Vector3, top: float, bottom: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "Lighthouse"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 16
	mesh.mesh = cylinder
	mesh.material_override = material
	mesh.position = at
	_world.add_child(mesh)
	return mesh


## Exterior objects: lit by the sun only (and by the ambient fill).
func _outside(mesh: GeometryInstance3D) -> void:
	mesh.layers = 1 << (EXTERIOR_LAYER - 1)


func set_class(id: StringName) -> void:
	class_id = id
	if _world == null or (_model != null and _model.class_id == id):
		return
	if _model != null:
		_world.remove_child(_model)
		_model.queue_free()
	_model = SoldierModel.create(id)
	_model.position = MODEL_AT
	_model.rotation_degrees.y = 235.0
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
	plane.size = Vector2(240, 160)
	plane.subdivide_width = 48
	plane.subdivide_depth = 48
	sea.mesh = plane
	sea.position = Vector3(0, -0.8, -86)
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = """
		shader_type spatial;
		varying float depth;
		void vertex() {
			VERTEX.y += sin(VERTEX.x * 0.25 + TIME * 0.5) * 0.08
				+ cos(VERTEX.z * 0.4 + TIME * 0.7) * 0.06;
			depth = clamp((VERTEX.z + 80.0) / 160.0, 0.0, 1.0);
		}
		void fragment() {
			float wave = sin(UV.y * 300.0 + sin(UV.x * 40.0) * 2.0 + TIME * 0.6) * 0.5 + 0.5;
			vec3 deep = mix(vec3(0.10, 0.36, 0.52), vec3(0.04, 0.24, 0.40), depth);
			ALBEDO = mix(deep, vec3(0.30, 0.58, 0.68), wave * wave * 0.45);
			ROUGHNESS = 0.18;
			METALLIC = 0.1;
			SPECULAR = 0.7;
		}
	"""
	sea.material_override = material
	_outside(sea)
	_world.add_child(sea)


func _box(label: String, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	var box := BoxMesh.new()
	box.size = dimensions
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	_world.add_child(mesh)
	return mesh


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


func _surface(id: String, uv: Vector2, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var material := _plain(tint)
	var path: String = "res://assets/textures/polyhaven/" + id
	material.albedo_texture = load(path + "_diffuse.res") as Texture2D
	material.normal_enabled = true
	material.normal_texture = load(path + "_nor_gl.res") as Texture2D
	material.roughness_texture = load(path + "_rough.res") as Texture2D
	material.uv1_scale = Vector3(uv.x, uv.y, 1)
	material.uv1_triplanar = true
	return material
