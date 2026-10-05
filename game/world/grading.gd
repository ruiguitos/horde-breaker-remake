class_name Grading
extends RefCounted
## Colour grading per biome with the Color Grading addon (a CompositorEffect
## in Compositor/Color grading/): tints shadows, midtones and highlights and
## adjusts vibrance, so each island has its own mood.
##
## Compositor effects need RenderingDevice (Forward+ / Mobile). In the
## Compatibility renderer, headless tests or on Low/Medium it is skipped.
##
## SMH values are Vector4(hue 0..1, tint amount, vibrance, lightness).

const SCRIPT: String = "res://Compositor/Color grading/ColorGrading.gd"
const LOOKS: Dictionary = {
	# Warm sunny highlights, cool teal shadows (classic beach look).
	&"beach": {"shadows": Vector4(0.55, 0.12, 1.0, 1.0), "midtones": Vector4(0.2, 0.03, 1.1, 1.0), "highlights": Vector4(0.2, 0.12, 1.0, 1.02)},
	# Slightly desaturated, cold grey town.
	&"town": {"shadows": Vector4(0.6, 0.1, 0.9, 1.0), "midtones": Vector4(0.6, 0.03, 0.9, 1.0), "highlights": Vector4(0.15, 0.05, 1.0, 1.0)},
	# Lush greens, humid yellow-green highlights.
	&"jungle": {"shadows": Vector4(0.45, 0.12, 1.1, 0.98), "midtones": Vector4(0.38, 0.05, 1.2, 1.0), "highlights": Vector4(0.28, 0.08, 1.05, 1.0)},
	# Industrial port: blue shadows, orange sodium highlights.
	&"port": {"shadows": Vector4(0.62, 0.15, 1.0, 1.0), "midtones": Vector4(0.6, 0.04, 1.0, 1.0), "highlights": Vector4(0.15, 0.12, 1.0, 1.0)},
	# Volcano: red-orange everything, dark crushed shadows.
	&"volcano": {"shadows": Vector4(0.02, 0.2, 1.0, 0.92), "midtones": Vector4(0.07, 0.1, 1.1, 1.0), "highlights": Vector4(0.12, 0.15, 1.0, 1.03)},
}


static func supported() -> bool:
	return RenderingServer.get_rendering_device() != null and ResourceLoader.exists(SCRIPT)


## A Compositor with the biome's grading, or null when not supported.
static func compositor_for(biome: StringName) -> Compositor:
	if not supported():
		return null
	var effect: CompositorEffect = load(SCRIPT).new()
	var look: Dictionary = LOOKS.get(biome, LOOKS[&"beach"])
	for key: String in look:
		effect.set(key, look[key])
	var c := Compositor.new()
	c.compositor_effects = [effect]
	return c


## Turns the grading of `camera` on or off for the current quality preset.
static func apply(camera: Camera3D) -> void:
	if camera == null or camera.compositor == null:
		return
	for e: CompositorEffect in camera.compositor.compositor_effects:
		e.enabled = GraphicsSettings.quality >= GraphicsSettings.HIGH
