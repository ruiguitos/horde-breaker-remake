class_name CameraMediumRig
extends Node3D
## Third-person "medium" camera rig with three presets (BRAINSTORM §7).
##
## The rig orbits a pivot placed `pivot_height` above the target. The camera
## looks down at `pitch` degrees, sits `distance` metres back along the view
## direction and `side_offset` metres to the right (shoulder offset).
## Presets are switched with `set_preset()`; parameters blend smoothly.

const PRESET_NAMES: PackedStringArray = ["Shoulder (far)", "Medium", "High (light)"]

@export var target: Node3D
@export_group("Presets (index 0, 1, 2)")
@export var preset_pitch_deg: PackedFloat32Array = [25.0, 35.0, 45.0]
@export var preset_distance: PackedFloat32Array = [7.0, 10.0, 13.0]
@export var preset_side_offset: PackedFloat32Array = [0.8, 0.4, 0.0]
@export var preset_fov_deg: PackedFloat32Array = [65.0, 60.0, 55.0]
@export_group("Behaviour")
@export var pivot_height: float = 1.2
## Higher = faster preset blend (exponential smoothing rate, 1/s).
@export var blend_rate: float = 4.0
## Higher = camera follows the player more tightly.
@export var follow_rate: float = 12.0
@export var mouse_yaw_sensitivity: float = 0.25 # degrees per pixel
@export var stick_yaw_speed_deg: float = 140.0 # degrees per second at full tilt
@export var stick_deadzone: float = 0.2
## true: mouse motion always turns the camera. false: only while RMB is held.
@export var mouse_yaw_always: bool = false

var preset_index: int = 1
var yaw_deg: float = 0.0
# Current (blended) parameters.
var pitch_deg: float = 35.0
var distance: float = 10.0
var side_offset: float = 0.4
var fov_deg: float = 60.0

var _pivot: Vector3 = Vector3.ZERO
@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	set_preset(preset_index, true)
	if target:
		_pivot = target.global_position + Vector3.UP * pivot_height
	_update_camera()


func set_preset(index: int, instant: bool = false) -> void:
	preset_index = clampi(index, 0, preset_pitch_deg.size() - 1)
	if instant:
		pitch_deg = preset_pitch_deg[preset_index]
		distance = preset_distance[preset_index]
		side_offset = preset_side_offset[preset_index]
		fov_deg = preset_fov_deg[preset_index]
		if is_node_ready():
			_update_camera()


func preset_name() -> String:
	return PRESET_NAMES[preset_index] if preset_index < PRESET_NAMES.size() else str(preset_index)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if mouse_yaw_always or (motion.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			yaw_deg -= motion.relative.x * mouse_yaw_sensitivity
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_1: set_preset(0)
			KEY_2: set_preset(1)
			KEY_3: set_preset(2)
			KEY_T: mouse_yaw_always = not mouse_yaw_always


func _process(delta: float) -> void:
	var stick := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(stick) > stick_deadzone:
		yaw_deg -= stick * stick_yaw_speed_deg * delta
	# Exponential smoothing: frame-rate independent blend towards the preset.
	var t := 1.0 - exp(-blend_rate * delta)
	pitch_deg = lerpf(pitch_deg, preset_pitch_deg[preset_index], t)
	distance = lerpf(distance, preset_distance[preset_index], t)
	side_offset = lerpf(side_offset, preset_side_offset[preset_index], t)
	fov_deg = lerpf(fov_deg, preset_fov_deg[preset_index], t)
	if target:
		var goal := target.global_position + Vector3.UP * pivot_height
		_pivot = _pivot.lerp(goal, 1.0 - exp(-follow_rate * delta))
	_update_camera()


## Snap the pivot to the target immediately (used at start and by tests).
func snap_to_target() -> void:
	if target:
		_pivot = target.global_position + Vector3.UP * pivot_height
	_update_camera()


func _update_camera() -> void:
	camera.global_transform = compute_camera_transform(_pivot, yaw_deg, pitch_deg, distance, side_offset)
	camera.fov = fov_deg


## Pure function: camera transform for a given pivot and rig parameters.
static func compute_camera_transform(pivot: Vector3, yaw: float, pitch: float, dist: float, offset: float) -> Transform3D:
	var basis := Basis.from_euler(Vector3(deg_to_rad(-pitch), deg_to_rad(yaw), 0.0))
	# basis.z points backwards (away from where the camera looks).
	var origin := pivot + basis.z * dist + basis.x * offset
	return Transform3D(basis, origin)


## Horizontal forward/right of the camera, for camera-relative movement.
func flat_forward() -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3.FORWARD


func flat_right() -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw_deg)) * Vector3.RIGHT
