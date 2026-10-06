extends Camera3D
## Free flight to look at the island (F6 on out/real_island.scn):
## WASD move, Q/E down/up, hold right mouse to look, Shift fast, wheel = speed.
## Also adds the colour grading (Color Grading addon; needs Forward+).

const GRADING: String = "res://Compositor/Color grading/ColorGrading.gd"

var speed: float = 25.0
var _yaw: float
var _pitch: float


func _ready() -> void:
	current = true
	_yaw = rotation.y
	_pitch = rotation.x
	var terrain: Node = get_parent().get_node_or_null("Terrain3D")
	if terrain != null:
		terrain.call("set_camera", self)
	if ResourceLoader.exists(GRADING) and RenderingServer.get_rendering_device() != null:
		var effect: CompositorEffect = load(GRADING).new()
		effect.set("shadows", Vector4(0.55, 0.3, 1.1, 0.95))  # teal shadows
		effect.set("midtones", Vector4(0.12, 0.08, 1.1, 1.0))
		effect.set("highlights", Vector4(0.2, 0.1, 1.05, 1.02))  # warm light
		compositor = Compositor.new()
		compositor.compositor_effects = [effect]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.5, 1.5)
		rotation = Vector3(_pitch, _yaw, 0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed *= 1.25
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed /= 1.25


func _process(delta: float) -> void:
	var move := Vector3(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_E)) - float(Input.is_key_pressed(KEY_Q)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	var fast: float = 4.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0
	translate(move * speed * fast * delta)
