class_name ClassPreview
extends SubViewportContainer
## Armory turntable: the selected class's SoldierModel rendered in its own
## small 3D world (SubViewport) with a key light and a rim light, slowly
## rotating. Shows the same model the player controls on the island.

var class_id: StringName = &"recruit"
var face_only: bool = false  ## Compact class selector portrait.
var _model: SoldierModel


static func create(id: StringName) -> ClassPreview:
	var p := ClassPreview.new()
	p.class_id = id
	return p


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.45, 0.45, 0.42)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -40, 0)
	key.light_color = Color(1.0, 0.9, 0.75)  # warm side light, like the portrait
	key.light_energy = 1.4
	key.shadow_enabled = true
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 150, 0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 0.8
	vp.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.position = Vector3(0, 1.15, 4.6)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1.0, 0))
	if face_only:
		cam.position = Vector3(0, 1.5, 1.9)
		cam.look_at(Vector3(0, 1.42, 0))
	_model = SoldierModel.create(class_id)
	_model.rotation_degrees.y = 200.0  # three-quarter view to start
	vp.add_child(_model)


func _process(delta: float) -> void:
	if _model != null:
		if not face_only:
			_model.rotation.y += delta * 0.5
		_model.animate(0.0, 0.0, false, delta)
