class_name GraphicsSettings
extends RefCounted
## Applies the Display and Graphics settings of the Profile to the real
## engine: window mode, resolution, VSync, FPS cap, 3D render scale,
## anti-aliasing, and a quality preset that changes shadows, ambient
## occlusion, bloom and level of detail. Every value has a visible effect.
##
## Display calls are skipped when there is no window (headless tests).

enum { WINDOWED, BORDERLESS, FULLSCREEN }
const WINDOW_MODE_NAMES: Array[String] = ["Windowed", "Borderless fullscreen", "Exclusive fullscreen"]

enum { LOW, MEDIUM, HIGH, ULTRA }
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High", "Ultra"]
## What each preset turns on (shown in the menu, so players know the cost).
const QUALITY_INFO: Array[String] = [
	"No shadows, no bloom, no ambient occlusion. Fastest.",
	"Sun shadows (2 splits) and bloom.",
	"Soft 4-split shadows, bloom, ambient occlusion (SSAO) and colour grading.",
	"High + sharper shadows, indirect light (SSIL) and full detail at distance.",
]

enum { AA_OFF, AA_FXAA, AA_MSAA2, AA_MSAA4, AA_TAA }
const AA_NAMES: Array[String] = ["Off", "FXAA (fast)", "MSAA 2x", "MSAA 4x", "TAA (smooth)"]

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900),
	Vector2i(1920, 1080), Vector2i(2560, 1440), Vector2i(3840, 2160),
]
const FPS_CAPS: Array[int] = [0, 30, 60, 120, 144, 165, 240]

## Preset currently applied (read by scenes when they build lights/sky).
static var quality: int = HIGH


static func has_window() -> bool:
	return DisplayServer.get_name() != "headless"


## Everything: display + the 3D settings of the running scenes.
static func apply_all(profile: Profile, tree: SceneTree) -> void:
	apply_display(profile)
	apply_graphics(profile, tree)


static func apply_display(profile: Profile) -> void:
	Engine.max_fps = profile.max_fps
	if not has_window():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if profile.vsync else DisplayServer.VSYNC_DISABLED)
	match profile.window_mode:
		BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var screen: Vector2i = DisplayServer.screen_get_size()
			var size := Vector2i(mini(profile.resolution.x, screen.x), mini(profile.resolution.y, screen.y))
			DisplayServer.window_set_size(size)
			DisplayServer.window_set_position(DisplayServer.screen_get_position() + (screen - size) / 2)


## Quality preset, render scale and anti-aliasing on the root viewport, plus
## every WorldEnvironment and DirectionalLight3D already in the tree.
static func apply_graphics(profile: Profile, tree: SceneTree) -> void:
	quality = profile.quality
	Visuals.high_quality = quality >= HIGH
	var vp: Viewport = tree.root
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = profile.render_scale / 100.0
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_taa = false
	match profile.antialias:
		AA_FXAA:
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		AA_MSAA2:
			vp.msaa_3d = Viewport.MSAA_2X
		AA_MSAA4:
			vp.msaa_3d = Viewport.MSAA_4X
		AA_TAA:
			vp.use_taa = true
	# Level of detail: higher threshold = simpler meshes sooner.
	vp.mesh_lod_threshold = [4.0, 2.0, 1.0, 0.0][quality]
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096, 8192][quality], true)
	for n in tree.root.find_children("*", "WorldEnvironment", true, false):
		var we := n as WorldEnvironment
		if we.environment != null:
			apply_environment(we.environment)
	for n in tree.root.find_children("*", "DirectionalLight3D", true, false):
		apply_sun(n as DirectionalLight3D)
	for n in tree.root.find_children("*", "Camera3D", true, false):
		Grading.apply(n as Camera3D)


## Post-processing for the current preset (tonemap is always on).
static func apply_environment(env: Environment) -> void:
	Visuals.apply_post(env)
	env.glow_enabled = quality >= MEDIUM
	env.ssao_enabled = quality >= HIGH
	env.ssil_enabled = quality >= ULTRA


static func apply_sun(sun: DirectionalLight3D) -> void:
	# A light marked "no_shadows" (the horror preset's backlight) keeps them off at every quality.
	sun.shadow_enabled = quality >= MEDIUM and not sun.has_meta(&"no_shadows")
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if quality == MEDIUM else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = [40.0, 60.0, 90.0, 140.0][quality]
	sun.shadow_blur = 1.5 if quality >= HIGH else 1.0


static func resolution_index(r: Vector2i) -> int:
	var i: int = RESOLUTIONS.find(r)
	return i if i >= 0 else 2
