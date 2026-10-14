shader_type spatial;
// Common zombie (ZombieModel / ZombieHordeView). One shader for every
// material layer (skin, jersey, denim, leather, linen): a Poly Haven PBR
// texture set plus procedural gore on top.
//
// Vertex data (built by ZombieModel):
//   CUSTOM0 = (part id, gore seed, gore amount 0..1, kind)
//             kind: 0 surface, 1 raw flesh, 2 bone, 3 eye, 4 mouth
//   CUSTOM1 = (tint r, g, b, arm style: 0 both arms reach, 1 left arm hangs)
// Per instance (MultiMesh):
//   INSTANCE_CUSTOM = (walk phase, walk 0..1, lunge 0..1 or -stagger,
//                      flinch 0..1 | 2 + death 0..1 | 4 + headless death)
//   COLOR (instance colour) = status tint rgb, a = how much of it shows.
// The skeleton is procedural: each box belongs to a part that rotates about
// a fixed joint (same joints as ZombieModel.JOINTS), like the old soldier
// pivots, but on the GPU so 150 zombies cost one MultiMesh update.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 2.0;  // texture repeats per metre
uniform float is_cloth = 0.0;  // 1: wounds tear the cloth and show skin
uniform float rot = 0.0;       // 1: skin rot blotches and veins
uniform float dirt = 0.35;     // grime strength

varying vec3 v_rest;
varying flat vec4 v_info;
varying vec3 v_tint;
varying vec4 v_status;

const vec3 WAIST = vec3(0.0, 1.02, 0.0);
const vec3 NECK = vec3(0.0, 1.58, 0.02);
const vec3 SHOULDER_L = vec3(0.27, 1.49, 0.0);
const vec3 SHOULDER_R = vec3(-0.27, 1.49, 0.0);
const vec3 ELBOW_L = vec3(0.29, 1.19, 0.0);
const vec3 ELBOW_R = vec3(-0.29, 1.19, 0.0);
const vec3 HIP_L = vec3(0.12, 0.92, 0.0);
const vec3 HIP_R = vec3(-0.12, 0.92, 0.0);
const vec3 KNEE_L = vec3(0.12, 0.5, 0.0);
const vec3 KNEE_R = vec3(-0.12, 0.5, 0.0);

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_y(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, 0.0, -s), vec3(0.0, 1.0, 0.0), vec3(s, 0.0, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

void turn(inout vec3 p, inout vec3 n, inout vec3 t, mat3 r, vec3 pivot) {
	p = pivot + r * (p - pivot);
	n = r * n;
	t = r * t;
}

void vertex() {
	v_rest = VERTEX;
	v_info = CUSTOM0;
	v_tint = CUSTOM1.rgb;
	v_status = COLOR;
	int part = int(CUSTOM0.x + 0.5);
	vec4 ic = INSTANCE_CUSTOM;
	float phase = ic.x;
	float walk = ic.y;
	float lunge = max(ic.z, 0.0);
	float stagger = max(-ic.z, 0.0);
	float flinch = ic.w < 1.5 ? ic.w : 0.0;
	float death = 0.0;
	bool headless = false;
	if (ic.w >= 3.5) {
		death = ic.w - 4.0;
		headless = true;
	} else if (ic.w >= 1.5) {
		death = ic.w - 2.0;
	}
	float fall = 1.0 - (1.0 - death) * (1.0 - death);  // ease out
	float s = sin(phase);
	float c = cos(phase);
	float limp = 1.0 - fall;
	vec3 p = VERTEX;
	vec3 n = NORMAL;
	vec3 t = TANGENT;
	if (headless && part == 2) {
		p = NECK;  // collapsed: the head popped off (debris in island.gd)
	}
	// Legs: thigh about the hip, shin about the knee. The right leg drags.
	if (part >= 7) {
		bool left = part <= 8;
		float swing = (left ? -0.5 : 0.36) * walk * s;
		float knee = 0.7 * walk * max(0.0, left ? c : -c) + 0.9 * fall;
		if (part == 8 || part == 10) {
			turn(p, n, t, rot_x(knee), left ? KNEE_L : KNEE_R);
		}
		turn(p, n, t, rot_x(swing - 0.35 * fall), left ? HIP_L : HIP_R);
	}
	// Arms: forearm about the elbow, then the arm about the shoulder.
	if (part >= 3 && part <= 6) {
		bool left = part <= 4;
		bool hangs = left && CUSTOM1.a > 0.5;
		float reach = hangs ? 0.25 * walk * s : 1.15 + 0.12 * sin(phase + (left ? 0.0 : 1.7)) + 0.45 * lunge;
		reach = reach * limp - 0.3 * flinch;
		float spread = (left ? 1.0 : -1.0) * (0.1 + 0.15 * stagger + 0.5 * fall);
		if (part == 4 || part == 6) {
			turn(p, n, t, rot_x(-(hangs ? 0.15 : 0.35) * limp), left ? ELBOW_L : ELBOW_R);
		}
		turn(p, n, t, rot_z(spread) * rot_x(-reach), left ? SHOULDER_L : SHOULDER_R);
	}
	// Head lolls about the neck and snaps back on a hit.
	if (part == 2) {
		float loll = 0.22 * sin(phase * 0.5) + 0.1 + 0.4 * stagger * sin(phase * 3.0);
		turn(p, n, t, rot_z(loll * limp) * rot_x(-0.18 - 0.55 * flinch + 0.2 * lunge), NECK);
	}
	// Torso: hunched, twisting with the steps, lunging and recoiling.
	if (part >= 1 && part <= 6) {
		float lean = 0.18 + 0.08 * walk + 0.4 * lunge - 0.5 * flinch - 0.2 * stagger;
		turn(p, n, t, rot_x(lean * limp) * rot_y(0.14 * walk * s), WAIST);
	}
	// Whole body: bob and sway with the steps, lunge forward, fall backwards.
	vec3 root = vec3(0.0, 0.04 * walk * abs(s), 0.2 * lunge);
	turn(p, n, t, rot_z(0.05 * walk * s + 0.12 * stagger * sin(phase * 3.0)), vec3(0.0));
	p += root * limp;
	if (death > 0.0) {
		turn(p, n, t, rot_x(-1.5 * fall), vec3(0.0));
		p.y += 0.16 * fall;
	}
	VERTEX = p;
	NORMAL = normalize(n);
	TANGENT = normalize(t);
}

float hash13(vec3 q) {
	q = fract(q * 0.1031);
	q += dot(q, q.zyx + 31.32);
	return fract((q.x + q.y) * q.z);
}

float vnoise(vec3 q) {
	vec3 i = floor(q);
	vec3 f = fract(q);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), f.x), mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), f.x), mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

// Colours below are written as sRGB (what a paint picker shows); ALBEDO is linear.
vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

float fbm(vec3 q) {
	return 0.5 * vnoise(q) + 0.3 * vnoise(q * 2.03 + 7.1) + 0.2 * vnoise(q * 4.1 + 3.3);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 base = texture(albedo_tex, uv).rgb * v_tint;
	float rough = texture(rough_tex, uv).r;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	float metal = 0.0;
	float kind = v_info.w;
	float seed = v_info.y;
	float gore = v_info.z;
	vec3 q = v_rest + vec3(seed * 1.37, seed * 0.71, seed * 2.13);
	// Grime: low-frequency darkening, stronger towards the feet.
	float grime = fbm(q * 3.0) * dirt * (1.2 - clamp(v_rest.y * 0.5, 0.0, 1.0));
	base *= 1.0 - grime;
	if (rot > 0.5) {
		float blotch = smoothstep(0.45, 0.75, fbm(q * 5.0 + 11.0));
		base = mix(base, srgb(vec3(0.45, 0.48, 0.33)), blotch * 0.5);
		float bruise = smoothstep(0.55, 0.8, fbm(q * 3.5 + 23.0));
		base = mix(base, srgb(vec3(0.4, 0.3, 0.38)), bruise * 0.45);
		float vein = 1.0 - smoothstep(0.0, 0.02, abs(fbm(q * 9.0) - 0.5));
		base = mix(base, srgb(vec3(0.32, 0.3, 0.36)), vein * 0.18 * smoothstep(0.4, 0.6, vnoise(q * 2.0)));
	}
	// Wounds: noise blobs whose size grows with the box's gore amount.
	float w = fbm(q * 6.0);
	float cut = 0.76 - 0.2 * gore;
	float wound = gore > 0.01 ? smoothstep(cut, cut + 0.03, w) : 0.0;
	float rim = gore > 0.01 ? smoothstep(cut - 0.06, cut - 0.035, w) : 0.0;
	// Blood runs down: vertical streaks under wounds, plus a little spatter.
	float streak = fbm(vec3(q.x * 14.0, q.y * 1.6, q.z * 14.0));
	float below = fbm((q + vec3(0.0, 0.15, 0.0)) * 6.0);
	float drip = gore > 0.01 ? smoothstep(0.55, 0.68, streak) * smoothstep(cut - 0.12, cut - 0.02, below) : 0.0;
	float spatter = smoothstep(0.8, 0.83, vnoise(q * 28.0)) * gore;
	float fresh = smoothstep(0.5, 0.65, fbm(q * 4.0 + 5.0));
	vec3 dried = srgb(vec3(0.3, 0.07, 0.05));
	vec3 wet = srgb(vec3(0.42, 0.02, 0.02));
	// Large soaked stains (mostly dried) on the gorier boxes.
	float soak = smoothstep(0.56, 0.64, fbm(q * 2.2 + 17.0)) * smoothstep(0.25, 0.7, gore);
	float blood = clamp(max(max(rim * 0.9, soak * 0.85), max(drip, spatter)), 0.0, 1.0);
	vec3 blood_col = mix(dried, wet, fresh * (1.0 - soak * 0.6));
	float blood_rough = mix(0.85, 0.15, fresh);
	if (is_cloth > 0.5) {
		// Torn cloth shows grey skin; the frayed edge is soaked dark.
		vec3 skin = srgb(vec3(0.6, 0.62, 0.52)) * (0.8 + 0.4 * vnoise(q * 30.0));
		float torn = gore > 0.01 ? smoothstep(cut - 0.035, cut - 0.015, w) : 0.0;
		base = mix(base, skin, torn);
		rough = mix(rough, 0.6, torn);
	}
	base = mix(base, blood_col, blood);
	rough = mix(rough, blood_rough, blood);
	vec3 flesh = mix(srgb(vec3(0.28, 0.04, 0.04)), srgb(vec3(0.58, 0.18, 0.15)), vnoise(q * 40.0));
	float bone_mask = smoothstep(cut + 0.1, cut + 0.12, w) * step(0.55, gore);
	vec3 bone = srgb(vec3(0.78, 0.72, 0.58)) * (0.8 + 0.2 * vnoise(q * 50.0));
	base = mix(base, flesh, wound);
	rough = mix(rough, 0.22, wound);
	base = mix(base, bone, bone_mask);
	rough = mix(rough, 0.5, bone_mask);
	if (kind > 0.5 && kind < 1.5) {
		base = flesh;
		rough = 0.2;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (kind > 1.5 && kind < 2.5) {
		float stain = smoothstep(0.35, 0.65, fbm(q * 12.0));
		base = mix(bone, mix(dried, wet, fresh), stain * 0.8);
		rough = 0.55;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (kind > 2.5 && kind < 3.5) {
		base = srgb(vec3(0.62, 0.62, 0.5));  // milky dead eyes
		rough = 0.08;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	} else if (kind > 3.5) {
		base = srgb(vec3(0.12, 0.02, 0.02));
		rough = 0.3;
		NORMAL_MAP = vec3(0.5, 0.5, 1.0);
	}
	base = mix(base, v_status.rgb, v_status.a);
	ALBEDO = base;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = 0.4;
}
