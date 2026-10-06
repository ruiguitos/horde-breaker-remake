class_name Grading
extends RefCounted
## Colour grading per biome with the Color Grading addon (a CompositorEffect
## in Compositor/Color grading/): tints shadows, midtones and highlights and
## adjusts vibrance, so each island has its own mood.
##
## Compositor effects need RenderingDevice (Forward+ / Mobile). In the
## Compatibility renderer, headless tests or on Low/Medium it is skipped.
##
## The look of each biome lives in its data (game/data/biomes/<biome>.tres,
## field Grading): open it and tune the colour wheels in the inspector.
## SMH values are Vector4(hue 0..1, tint amount, vibrance, lightness); tint
## amounts under ~0.1 are invisible.

const SCRIPT: String = "res://Compositor/Color grading/ColorGrading.gd"


static func supported() -> bool:
	return RenderingServer.get_rendering_device() != null and ResourceLoader.exists(SCRIPT)


## A Compositor with the biome's grading, or null when not supported or the
## biome has none.
static func compositor_for(biome: StringName) -> Compositor:
	var data: Dictionary = GameData.BIOMES.get(biome, {})
	var effect: CompositorEffect = data.get("grading")
	if not supported() or effect == null:
		return null
	var c := Compositor.new()
	c.compositor_effects = [effect]
	return c


## Turns the grading of `camera` on or off for the current quality preset.
static func apply(camera: Camera3D) -> void:
	if camera == null or camera.compositor == null:
		return
	for e: CompositorEffect in camera.compositor.compositor_effects:
		e.enabled = GraphicsSettings.quality >= GraphicsSettings.HIGH
