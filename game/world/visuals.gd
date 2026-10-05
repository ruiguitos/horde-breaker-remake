class_name Visuals
extends RefCounted
## Shared visual helpers used by more than one scene (island, boat).

## Graphics quality (Armory setting): High adds glow (bloom) and SSAO.
static var high_quality: bool = true


## Post-processing shared by 3D scenes: filmic tonemap always; bloom and
## ambient occlusion only on High.
static func apply_post(env: Environment) -> void:
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.glow_enabled = high_quality
	env.glow_intensity = 0.6
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.2
	env.ssao_enabled = high_quality
	env.ssao_radius = 1.5
	env.ssao_intensity = 1.5


## Sky with a horizon gradient instead of a flat colour.
static func sky(horizon: Color, top: Color) -> Sky:
	var mat := ProceduralSkyMaterial.new()
	mat.sky_horizon_color = horizon
	mat.sky_top_color = top
	mat.ground_horizon_color = horizon.darkened(0.2)
	mat.ground_bottom_color = horizon.darkened(0.5)
	var s := Sky.new()
	s.sky_material = mat
	return s


## Animated sea: vertices bob with two crossing sine waves (vertex shader),
## and the colour gets lighter on the crests.
static func sea_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 deep = vec3(0.1, 0.28, 0.45);
uniform vec3 crest = vec3(0.35, 0.6, 0.75);
varying float h;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	h = sin(w.x * 0.15 + TIME * 1.3) * 0.5 + sin(w.z * 0.11 - TIME * 0.9) * 0.5;
	VERTEX.y += h * 0.25;
}
void fragment() {
	ALBEDO = mix(deep, crest, clamp(h * 0.5 + 0.5, 0.0, 1.0) * 0.5);
	ROUGHNESS = 0.25;
	SPECULAR = 0.6;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func mat(c: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat(color)
	return mi
