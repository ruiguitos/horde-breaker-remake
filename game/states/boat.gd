extends Control
## The boat between islands: pick 1 of 3 rewards, then land on the next island.
## Keys: 1/2/3 pick, Enter lands. Gamepad: X/Y/B pick, A lands.

signal land_requested

var context: RunContext

var _rng := RandomNumberGenerator.new()
var _options: Array[Dictionary] = []  ## {title, text, apply: Callable}
var _buttons: Array[Button] = []
var _picked: bool = false
var _land: Button
var _status: Label
var _routes: Array[GameData.Modifier] = []
var _route_buttons: Array[Button] = []
var _route_picked: bool = false
var _route_biomes: Array[StringName] = []
var _route_missions: Array[StringName] = []
var _boat: Node3D
var _island_mat: StandardMaterial3D


func _ready() -> void:
	# The parent is a plain Node, so fill the window explicitly.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	_rng.seed = context.island_seed() + 1
	theme = UiTheme.get_theme()
	_build_scene()
	var box: VBoxContainer = UiTheme.side_panel(self, 600)
	box.add_child(UiTheme.title("THE BOAT — island %d of %d next" % [context.island_index + 1, RunContext.ISLAND_COUNT], 28))
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	var hint := Label.new()
	hint.text = "Pick one supply (1 / 2 / 3):"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	_make_options()
	for i in _options.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(186, 130)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = "%d. %s\n\n%s" % [i + 1, _options[i]["title"], _options[i]["text"]]
		b.pressed.connect(_pick.bind(i))
		row.add_child(b)
		_buttons.append(b)
	var route_hint := Label.new()
	route_hint.text = "Choose your route (4 / 5) — harder islands pay more Intel:"
	route_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(route_hint)
	var route_row := HBoxContainer.new()
	route_row.add_theme_constant_override("separation", 10)
	box.add_child(route_row)
	var mods: Array[GameData.Modifier] = GameData.modifiers()
	var a: int = _rng.randi_range(0, mods.size() - 1)
	var b2: int = (a + _rng.randi_range(1, mods.size() - 1)) % mods.size()
	_routes = [mods[a], mods[b2]]
	# Each route also has a biome (the last island is always the volcano).
	var biomes: Array[StringName] = GameData.ISLAND_BIOMES.duplicate()
	var missions: Array = GameData.MISSIONS.keys()
	for i in 2:
		_route_missions.append(missions[_rng.randi_range(0, missions.size() - 1)])
		if context.is_last_island():
			_route_biomes.append(&"volcano")
		else:
			var pick: int = _rng.randi_range(0, biomes.size() - 1)
			_route_biomes.append(biomes[pick])
			biomes.remove_at(pick)
	for i in 2:
		var rb := Button.new()
		rb.custom_minimum_size = Vector2(286, 96)
		rb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rb.text = "%d. %s · %s — %s (Intel x%.1f)\n%s" % [i + 4, GameData.BIOMES[_route_biomes[i]]["name"],
			GameData.MISSIONS[_route_missions[i]]["name"], _routes[i].title, _routes[i].intel_mult, _routes[i].description]
		rb.pressed.connect(_pick_route.bind(i))
		route_row.add_child(rb)
		_route_buttons.append(rb)
	_land = Button.new()
	_land.text = "LAND (Enter)"
	_land.custom_minimum_size = Vector2(0, 50)
	_land.disabled = true
	_land.pressed.connect(func() -> void: land_requested.emit())
	box.add_child(_land)
	_refresh_status()


## 3D backdrop: the boat bobbing on the sea, the next island on the horizon
## (coloured by the chosen route's biome), a low sun.
func _build_scene() -> void:
	var world := Node3D.new()
	add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.85, 0.6, 0.45) if not context.is_last_island() else Color(0.4, 0.18, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.42, 0.45)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = env.environment.background_color
	env.environment.fog_density = 0.003
	Visuals.apply_post(env.environment)
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-18, 160, 0)
	sun.light_color = Color(1.0, 0.8, 0.6)
	sun.shadow_enabled = true
	world.add_child(sun)
	var sea := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(500, 500)
	plane.subdivide_width = 150
	plane.subdivide_depth = 150
	sea.mesh = plane
	sea.material_override = Visuals.sea_material()
	world.add_child(sea)
	_boat = Node3D.new()
	_boat.add_child(Visuals.box(Vector3(3.2, 1.0, 8.0), Vector3(0, 0.3, 0), Color(0.45, 0.3, 0.18)))
	_boat.add_child(Visuals.box(Vector3(2.0, 1.4, 2.4), Vector3(0, 1.5, 1.4), Color(0.85, 0.85, 0.8)))
	_boat.add_child(Visuals.box(Vector3(0.15, 4.0, 0.15), Vector3(0, 3.2, -1.5), Color(0.3, 0.25, 0.2)))
	_boat.add_child(Visuals.box(Vector3(2.6, 0.12, 1.6), Vector3(0, 0.85, -2.2), Color(0.3, 0.32, 0.28)))  # map table
	world.add_child(_boat)
	# The next island on the horizon: a flattened dome in the biome's colour.
	var island := MeshInstance3D.new()
	var dome := SphereMesh.new()
	dome.radius = 26.0
	dome.height = 18.0
	island.mesh = dome
	island.position = Vector3(-80, -3, -45)
	_island_mat = Visuals.mat(Color(0.35, 0.45, 0.3))
	island.material_override = _island_mat
	world.add_child(island)
	if context.is_last_island():
		var cone := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 4.0
		cm.bottom_radius = 26.0
		cm.height = 30.0
		cone.mesh = cm
		cone.position = Vector3(-84, 14, -50)
		cone.material_override = Visuals.mat(Color(0.25, 0.18, 0.16))
		world.add_child(cone)
	var cam := Camera3D.new()
	cam.position = Vector3(14, 6, 16)
	world.add_child(cam)
	cam.look_at(Vector3(-14, 2, -30))
	cam.fov = 60.0


func _process(_delta: float) -> void:
	if _boat == null:
		return
	var t: float = Time.get_ticks_msec() * 0.001
	_boat.position.y = sin(t * 1.3) * 0.25
	_boat.rotation = Vector3(sin(t * 0.9) * 0.03, 0.6, sin(t * 1.1) * 0.05)


func _make_options() -> void:
	_options.append({"title": "Field Repairs", "text": "Heal 50 HP.",
		"apply": func() -> void: context.hp = minf(context.max_hp, context.hp + 50.0)})
	_options.append({"title": "Ammo Crate", "text": "Refill Shotgun and Heavy Pistol ammo.",
		"apply": func() -> void: context.ammo = PackedInt32Array()})  # empty = full ammo on landing
	var pool: Array[GameData.Card] = []
	for c in GameData.cards():
		if context.card_stacks.get(c.id, 0) < c.max_stacks:
			pool.append(c)
	if not pool.is_empty():
		var card: GameData.Card = pool[_rng.randi_range(0, pool.size() - 1)]
		_options.append({"title": "Card: " + card.title, "text": card.description,
			"apply": func() -> void: context.card_stacks[card.id] = context.card_stacks.get(card.id, 0) + 1})


func _pick(i: int) -> void:
	if _picked or i < 0 or i >= _options.size():
		return
	_picked = true
	(_options[i]["apply"] as Callable).call()
	for k in _buttons.size():
		_buttons[k].disabled = true
		if k == i:
			_buttons[k].text = "✔ " + _buttons[k].text
	_update_land()
	_refresh_status()


func _pick_route(i: int) -> void:
	if i < 0 or i >= _routes.size():
		return
	_route_picked = true
	context.modifier = _routes[i].id
	context.biome = _route_biomes[i]
	_island_mat.albedo_color = GameData.BIOMES[context.biome]["inland"]
	context.mission = _route_missions[i]
	for k in _route_buttons.size():
		var txt: String = _route_buttons[k].text.trim_prefix("✔ ")
		_route_buttons[k].text = ("✔ " + txt) if k == i else txt
	_update_land()


func _update_land() -> void:
	_land.disabled = not (_picked and _route_picked)
	if not _land.disabled:
		_land.grab_focus()


func _can_land() -> bool:
	return _picked and _route_picked


func _refresh_status() -> void:
	_status.text = "HP %d/%d · Level %d · Kills %d · Intel this run %d" % [
		int(context.hp), int(context.max_hp), context.level, context.kills, context.intel]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: Key = event.physical_keycode
		if key in [KEY_1, KEY_2, KEY_3]:
			_pick(key - KEY_1)
		elif key in [KEY_4, KEY_5]:
			_pick_route(key - KEY_4)
		elif key in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _can_land():
			land_requested.emit()
	elif event is InputEventJoypadButton and event.pressed:
		var pads: Array = [JOY_BUTTON_X, JOY_BUTTON_Y, JOY_BUTTON_B]
		if event.button_index in pads:
			_pick(pads.find(event.button_index))
		elif event.button_index in [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
			_pick_route(0 if event.button_index == JOY_BUTTON_LEFT_SHOULDER else 1)
		elif event.button_index == JOY_BUTTON_A and _can_land():
			land_requested.emit()
