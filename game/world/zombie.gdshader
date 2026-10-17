shader_type spatial;
// Common zombie (ZombieModel / ZombieHordeView). One shader for every
// material layer (skin, jersey, denim, leather, linen): a Poly Haven PBR
// texture set, recoloured per zombie, plus procedural gore on top.
//
// Vertex data (built by ZombieModel):
//   CUSTOM0 = (part id, gore seed, gore amount 0..1, kind)
//             kind: 0 surface, 1 raw flesh, 2 bone, 3 eye, 4 mouth
//   CUSTOM1 = (tint r, g, b, colour slot: ZombieModel.Slot)
//   CUSTOM2 = (show condition a, show condition b): ZombieModel.Show bits
// Per instance (MultiMesh):
//   INSTANCE_CUSTOM = (walk phase, walk 0..1, lunge 0..1 or -stagger,
//                      flinch 0..1 | 2 + death 0..1 | 4 + headless death)
//   COLOR (instance colour) = (status index, show mask, colours, wear): the
//   last three are integers below 2^24 packed by ZombieModel.roll_look,
//   exact in float32 (Forward+ keeps the multimesh buffer in float32).
//     colours: shirt 5 bits | trousers 4 | skin 3 | hair 3 | pattern 2 |
//              pattern colour 3 | shoes 2 | jacket 2
//     wear:    gore 3 bits | blood 3 | torn 3 | fade 3 | build 3 | offset 8
//   mask bit 21 (LEGLESS, a Crawler) switches to the crawl pose: the legs are
//   hidden by the mask (bit 20, LEGS) and the hip stumps show instead.
// The skeleton is procedural: each box belongs to a part that rotates about
// a fixed joint (same joints as ZombieModel), like the old soldier pivots,
// but on the GPU so 150 zombies cost one MultiMesh update.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_roughness_r, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float uv_scale = 2.0;  // texture repeats per metre
uniform float is_cloth = 0.0;  // 1: wounds and rips tear the cloth and show skin
uniform float rot = 0.0;       // 1: skin rot blotches and veins
uniform float dirt = 0.35;     // grime strength
uniform float tex_mean = 0.3;  // the albedo texture's average luminance (linear)
uniform int creature_type = 0; // EnemyKind: 0 common, 1 runner .. 6 screamer
// Palettes (sRGB), from ZombieModel.
uniform vec4 skin_colors[8];
uniform vec4 shirt_colors[32];
uniform vec4 trouser_colors[16];
uniform vec4 hair_colors[8];
uniform vec4 shoe_colors[4];
uniform vec4 jacket_colors[4];
uniform vec4 pattern_colors[8];
uniform vec4 status_tints[8];

varying vec3 v_rest;
varying flat vec4 v_info;
varying flat vec3 v_col;      // linear albedo: palette colour (recoloured) or the box tint
varying flat vec4 v_look;     // recolour 0/1, pattern, slot, unused
varying flat vec3 v_pat_col;
varying flat vec3 v_skin;     // this zombie's skin (for torn cloth)
varying flat vec4 v_wear;     // gore scale, blood -1..1, torn 0..1, noise offset
varying flat vec4 v_status;

uniform vec3 WAIST = vec3(0.0, 1.02, 0.0);
uniform vec3 NECK = vec3(0.0, 1.58, 0.02);
uniform vec3 SHOULDER_L = vec3(0.27, 1.49, 0.0);
uniform vec3 SHOULDER_R = vec3(-0.27, 1.49, 0.0);
uniform vec3 ELBOW_L = vec3(0.29, 1.19, 0.0);
uniform vec3 ELBOW_R = vec3(-0.29, 1.19, 0.0);
uniform vec3 HIP_L = vec3(0.12, 0.92, 0.0);
uniform vec3 HIP_R = vec3(-0.12, 0.92, 0.0);
uniform vec3 KNEE_L = vec3(0.12, 0.5, 0.0);
uniform vec3 KNEE_R = vec3(-0.12, 0.5, 0.0);
const vec3 LUMA = vec3(0.3, 0.59, 0.11);
const uint SHOW_STUMP_L = 2u;  // ZombieModel.Show.STUMP_L
const uint SHOW_LEGLESS = 21u; // ZombieModel.Show.LEGLESS: a Crawler (crawl pose)
// Crawl pose (ZombieModel.CRAWL_*): torso pitched forward, sunk to the ground.
const float CRAWL_LEAN = 1.2;
const float CRAWL_DROP = 0.68;
const float CRAWL_HEAD_NOD = -0.5;
// Crawl arms (ZombieModel.CRAWL_*): a planted hand moves back in the body's
// frame at the crawl speed during its stance, then lifts and returns.
const float CRAWL_STRIDE = 0.8;
const float CRAWL_STANCE = 0.5;
const float CRAWL_LIFT = 0.1;
const float CRAWL_HAND_Y = 0.07;
const float CRAWL_HAND_Z = 0.44;
const float CRAWL_UPPER = 0.3;
const float CRAWL_FOREARM = 0.335;
const float CRAWL_WALK_FULL = 0.15;  // walk share at which the hands stride at full length
const float PI_C = 3.14159265;
const float TAU_C = 6.28318531;

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

// One hand of a Crawler (ZombieModel.crawl_stroke): the offset from its rest
// point (x: dz forward, y: dy up) for the cycle fraction. Stance: on the ground,
// dz falls from +half to -half, so the hand slides back at the crawl speed while
// the body moves over it. Recovery: the hand lifts (sine) and comes back forward.
vec2 crawl_stroke(float cycle) {
	float u = fract(cycle);
	float half_stride = CRAWL_STRIDE * CRAWL_STANCE * 0.5;
	if (u < CRAWL_STANCE) {
		return vec2(half_stride - 2.0 * half_stride * u / CRAWL_STANCE, 0.0);
	}
	float v = (u - CRAWL_STANCE) / (1.0 - CRAWL_STANCE);
	return vec2(-half_stride + half_stride * (1.0 - cos(PI_C * v)), CRAWL_LIFT * sin(PI_C * v));
}

// Two-bone IK in the arm's plane (ZombieModel.crawl_arm): the upper arm's reach
// and the elbow bend that put the hand centre at `hand` (before the lean and the
// drop). The angles are from straight down, towards +Z.
vec2 crawl_arm(vec3 hand) {
	vec3 loc = rot_x(-CRAWL_LEAN) * (hand + vec3(0.0, CRAWL_DROP, 0.0) - WAIST) + WAIST;
	vec2 t = loc.yz - SHOULDER_L.yz;
	float d = max(length(t), 0.001);
	float psi = atan(t.y, -t.x);
	float beta = acos(clamp((CRAWL_UPPER * CRAWL_UPPER + d * d - CRAWL_FOREARM * CRAWL_FOREARM) / (2.0 * CRAWL_UPPER * d), -1.0, 1.0));
	float gamma = acos(clamp((CRAWL_UPPER * CRAWL_UPPER + CRAWL_FOREARM * CRAWL_FOREARM - d * d) / (2.0 * CRAWL_UPPER * CRAWL_FOREARM), -1.0, 1.0));
	return vec2(psi - beta, PI_C - gamma);
}

void turn(inout vec3 p, inout vec3 n, inout vec3 t, mat3 r, vec3 pivot) {
	p = pivot + r * (p - pivot);
	n = r * n;
	t = r * t;
}

// Colours are written as sRGB (what a paint picker shows); ALBEDO is linear.
vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

// Sun-bleached, dusty cloth: desaturate towards a warm grey and darken a
// bit. Every garment gets some (0.15), the most worn ones much more.
vec3 faded(vec3 c, float f) {
	float l = dot(c, LUMA);
	return mix(c, vec3(l) * vec3(1.04, 1.0, 0.9), 0.15 + 0.4 * f) * (1.0 - 0.12 * f);
}

void vertex() {
	v_rest = VERTEX;
	v_info = CUSTOM0;
	int part = int(CUSTOM0.x + 0.5);
	int slot = int(CUSTOM1.a + 0.5);
	uint mask = uint(COLOR.g + 0.5);
	uint cols = uint(COLOR.b + 0.5);
	uint wear = uint(COLOR.a + 0.5);
	v_status = status_tints[clamp(int(COLOR.r + 0.5), 0, 7)];
	// This zombie's colours: the box takes its slot's palette colour.
	float fade = float((wear >> 9u) & 7u) / 7.0;
	vec3 skin = srgb(skin_colors[int((cols >> 9u) & 7u)].rgb);
	v_skin = skin;
	vec3 col = CUSTOM1.rgb;
	float recolour = 1.0;
	float pattern = 0.0;
	if (slot == 1) {
		col *= skin;
	} else if (slot == 2) {
		col *= srgb(faded(shirt_colors[int(cols & 31u)].rgb, fade));
		pattern = float((cols >> 15u) & 3u);
	} else if (slot == 3) {
		col *= srgb(faded(trouser_colors[int((cols >> 5u) & 15u)].rgb, fade));
	} else if (slot == 4) {
		col *= srgb(shoe_colors[int((cols >> 20u) & 3u)].rgb);
	} else if (slot == 5) {
		col *= srgb(hair_colors[int((cols >> 12u) & 7u)].rgb);
	} else if (slot == 6) {
		col *= srgb(faded(jacket_colors[int((cols >> 22u) & 3u)].rgb, fade * 0.6));
	} else {
		recolour = 0.0;
	}
	v_col = col;
	v_pat_col = srgb(faded(pattern_colors[int((cols >> 17u) & 7u)].rgb, fade));
	v_look = vec4(recolour, pattern, float(slot), 0.0);
	v_wear = vec4(mix(0.7, 1.2, float(wear & 7u) / 7.0), float((wear >> 3u) & 7u) / 3.5 - 1.0,
			float((wear >> 6u) & 7u) / 7.0, float((wear >> 15u) & 255u));
	vec4 ic = INSTANCE_CUSTOM;
	// A Crawler toppling after its legs went sends 6 + progress (0 = standing,
	// 1 = crawling): the slot is free above the death range (4 to 5).
	float topple = -1.0;
	if (ic.w >= 5.5) {
		topple = clamp(ic.w - 6.0, 0.0, 1.0);
		ic.w = 0.0;
	}
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
	// Optional boxes the look does not show collapse to a point (no pixels).
	uint sa = uint(CUSTOM2.x + 0.5);
	uint sb = uint(CUSTOM2.y + 0.5);
	bool shown = (((mask >> sa) & (mask >> sb)) & 1u) == 1u;
	if (!shown) {
		p = vec3(0.0, 1.3, 0.0);
	}
	bool legless = ((mask >> SHOW_LEGLESS) & 1u) == 1u;
	// How far the crawl pose is in: 0 standing (just amputated), 1 crawling.
	float crawl = legless ? (topple >= 0.0 ? topple : 1.0) : 0.0;
	if (headless && part == 2) {
		p = NECK;  // collapsed: the head popped off (debris in island.gd)
	}
	// Build, -1 thin .. +1 heavy: wider/narrower body and limbs and a belly,
	// sideways and in depth only (the head and its height never change).
	float build = creature_type == 0 ? float((wear >> 12u) & 7u) / 3.5 - 1.0 : 0.0;
	float wx = 1.0 + 0.14 * build;
	float wl = 1.0 + 0.12 * build;
	float arm_shift = 0.23 * (wx - 1.0);
	if (part <= 1) {
		p.x *= wx;
		float belly = 0.4 * max(build, 0.0) * clamp((1.55 - p.y) / 0.45, 0.0, 1.0) * clamp((p.y - 0.8) / 0.25, 0.0, 1.0);
		p.z *= p.z > 0.0 ? 1.0 + belly + 0.06 * build : 1.0 + 0.08 * build;
	} else if (part >= 3 && part <= 6) {
		float cx = part <= 4 ? 0.29 : -0.29;
		p.x = cx + (p.x - cx) * wl + sign(cx) * arm_shift;
		p.z *= mix(wl, 1.0, crawl);  // a Crawler's arms keep their length (planted hands)
	} else if (part >= 7) {
		float cx = part <= 8 ? 0.12 : -0.12;
		p.x = cx * wx + (p.x - cx) * wl;
		p.z *= p.y > 0.11 ? wl : 1.0;
	}
	// Legs: thigh about the hip, shin about the knee. The right leg drags.
	if (part >= 7) {
		bool left = part <= 8;
		float swing = (left ? -0.5 : 0.36) * walk * s;
		float knee = 0.7 * walk * max(0.0, left ? c : -c) + 0.9 * fall;
		if (creature_type > 0) {
			float stride = creature_type == 1 ? 0.85 : (creature_type == 2 || creature_type == 4 ? 0.25 : 0.40);
			if (creature_type == 5) { stride = 0.25; }
			swing = (left ? -stride : stride) * walk * s;
			knee = (creature_type == 1 ? 1.05 : 0.48) * walk * max(0.0, left ? c : -c) + 0.9 * fall;
		}
		vec3 hip = (left ? HIP_L : HIP_R) * vec3(wx, 1.0, 1.0);
		if (part == 8 || part == 10) {
			turn(p, n, t, rot_x(knee), (left ? KNEE_L : KNEE_R) * vec3(wx, 1.0, 1.0));
		}
		turn(p, n, t, rot_x(swing - 0.35 * fall), hip);
	}
	// Arms: forearm about the elbow, then the arm about the shoulder. With
	// the left forearm gone, that arm hangs.
	if (part >= 3 && part <= 6) {
		bool left = part <= 4;
		bool hangs = creature_type == 0 && left && ((mask >> SHOW_STUMP_L) & 1u) == 1u;
		float reach = hangs ? 0.25 * walk * s : 1.15 + 0.12 * sin(phase + (left ? 0.0 : 1.7)) + 0.45 * lunge;
		float elbow_bend = hangs ? 0.15 : 0.35;
		if (creature_type == 1) { reach = 0.2 + (left ? 0.7 : -0.7) * walk * s + 0.35 * lunge; elbow_bend = 0.85; }
		if (creature_type == 2 || creature_type == 4) { reach = 0.15 + 0.13 * walk * s + 0.75 * lunge; elbow_bend = 0.25; }
		if (creature_type == 3) { reach = 0.85 + 0.08 * sin(phase) + 0.5 * lunge; elbow_bend = 0.15; }
		if (creature_type == 5) { reach = -0.1 + 0.12 * walk * s; elbow_bend = 0.15; }
		if (creature_type == 6) { reach = 1.7 + 0.08 * sin(phase); elbow_bend = 1.15; }
		if (legless) {
			// Crawling, with the hands planted. Each hand has a cycle (the right
			// one half a cycle behind): stance, when it stays on the ground and
			// the body moves over it, then recovery, when it lifts and returns
			// (crawl_stroke). The shoulder and elbow angles come from IK on that
			// target (crawl_arm). The stroke scales with the walk, so a Crawler
			// standing still keeps its hands put.
			vec2 ca;
			if (left && ((mask >> SHOW_STUMP_L) & 1u) == 1u) {
				// No forearm: the stump stays at its rest point, tucked up off
				// the ground (it does not plant); the right hand does the pulling.
				ca = crawl_arm(vec3(0.0, CRAWL_HAND_Y, CRAWL_HAND_Z));
			} else {
				float k = smoothstep(0.0, CRAWL_WALK_FULL, walk);
				vec2 st = crawl_stroke(phase / TAU_C + (left ? 0.0 : 0.5)) * k;
				ca = crawl_arm(vec3(0.0, CRAWL_HAND_Y + st.y, CRAWL_HAND_Z + st.x));
			}
			reach = mix(reach, ca.x, crawl);
			elbow_bend = mix(elbow_bend, ca.y, crawl);
		}
		reach = reach * limp - 0.3 * flinch * (1.0 - crawl);
		float spread = (left ? 1.0 : -1.0) * (0.1 + 0.15 * stagger + 0.5 * fall);
		vec3 shift = vec3(left ? arm_shift : -arm_shift, 0.0, 0.0);
		if (part == 4 || part == 6) {
			turn(p, n, t, rot_x(-elbow_bend * limp), (left ? ELBOW_L : ELBOW_R) + shift);
		}
		turn(p, n, t, rot_z(spread) * rot_x(-reach), (left ? SHOULDER_L : SHOULDER_R) + shift);
	}
	// Head lolls about the neck and snaps back on a hit.
	if (part == 2) {
		float loll = 0.22 * sin(phase * 0.5) + 0.1 + 0.4 * stagger * sin(phase * 3.0);
		if (creature_type > 0) { loll = 0.035 * sin(phase * 0.5) + 0.15 * stagger * sin(phase * 3.0); }
		float nod = creature_type == 6 ? -0.30 : (creature_type > 0 ? -0.05 : -0.18);
		if (legless) { nod = mix(nod, CRAWL_HEAD_NOD, crawl); }
		turn(p, n, t, rot_z(loll * limp) * rot_x(nod - 0.55 * flinch + 0.2 * lunge), NECK);
	}
	// Torso: hunched, twisting with the steps, lunging and recoiling. A
	// Crawler pitches the whole upper body (pelvis too) forward and sinks it.
	if ((part >= 1 && part <= 6) || (legless && part == 0)) {
		float lean = 0.18 + 0.08 * walk + 0.4 * lunge - 0.5 * flinch - 0.2 * stagger;
		float twist = 0.14;
		if (creature_type > 0) {
			lean = (creature_type == 1 ? 0.10 : 0.025) + 0.02 * walk + 0.12 * lunge - 0.3 * flinch - 0.15 * stagger;
			twist = 0.04;
		}
		if (legless) {
			lean = mix(lean, CRAWL_LEAN, crawl);
			twist = mix(twist, 0.0, crawl);
		}
		turn(p, n, t, rot_x(lean * limp) * rot_y(twist * walk * s), WAIST);
	}
	if (legless) {
		p.y -= CRAWL_DROP * crawl;
	}
	// Whole body: bob and sway with the steps, lunge forward, fall backwards.
	vec3 root = vec3(0.0, 0.04 * walk * abs(s), 0.2 * lunge);
	float sway = 0.05;
	if (creature_type > 0) { root = vec3(0.0, 0.02 * walk * abs(s), 0.08 * lunge); sway = creature_type == 5 ? 0.04 : 0.02; }
	// A Crawler's body does not bob or roll: its hands stay on the ground.
	root.y *= 1.0 - crawl;
	sway *= 1.0 - crawl;
	turn(p, n, t, rot_z(sway * walk * s + 0.12 * stagger * sin(phase * 3.0)), vec3(0.0));
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

float fbm(vec3 q) {
	return 0.5 * vnoise(q) + 0.3 * vnoise(q * 2.03 + 7.1) + 0.2 * vnoise(q * 4.1 + 3.3);
}

// Anti-aliased band of a repeating pattern: 1 where the triangle wave of x
// is above `edge` (fwidth keeps distant stripes from shimmering).
float band(float x, float edge) {
	float tri = abs(fract(x) - 0.5) * 2.0;
	float aa = fwidth(x) * 2.0 + 0.001;
	return smoothstep(edge - aa, edge + aa, tri);
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 tex = texture(albedo_tex, uv).rgb;
	// Recoloured boxes keep the texture's detail (luminance over its mean),
	// softened so high-contrast weaves (denim) do not darken the colour.
	// Skin uses less of the leather's grain (0.3, not 0.6): its mottling shows instead.
	float detail = clamp(mix(1.0, dot(tex, LUMA) / tex_mean, rot > 0.5 ? 0.3 : 0.6), 0.35, 1.8);
	vec3 base = v_look.x > 0.5 ? v_col * detail : tex * v_col;
	// Shirt patterns, in rest space (they follow the body).
	int pat = int(v_look.y + 0.5);
	if (pat == 1) {
		base = mix(base, v_pat_col * detail, band(v_rest.y * 12.0, 0.55));  // stripes
	} else if (pat == 2) {
		float a = band(v_rest.y * 6.0, 0.5);
		float b = band((v_rest.x + v_rest.z) * 6.0, 0.5);
		base = mix(base, v_pat_col * detail, 0.42 * (a + b));  // plaid: crossing bands
		float thin = max(band(v_rest.y * 18.0, 0.9), band((v_rest.x + v_rest.z) * 18.0, 0.9));
		base *= 1.0 - 0.35 * thin;
	} else if (pat == 3 && v_rest.z > 0.12 && v_info.x > 0.5 && v_info.x < 1.5) {
		// A cracked, faded print on the chest front.
		vec2 d = vec2(v_rest.x, v_rest.y - 1.37);
		float r = length(d * vec2(1.0, 1.15));
		float logo = (1.0 - smoothstep(0.075, 0.08, r)) * (1.0 - (smoothstep(0.035, 0.04, r) - smoothstep(0.05, 0.055, r)));
		logo *= smoothstep(0.3, 0.5, vnoise(v_rest * 60.0));
		base = mix(base, v_pat_col, logo * 0.9);
	}
	float rough = texture(rough_tex, uv).r;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	float metal = 0.0;
	float kind = v_info.w;
	float seed = v_info.y;
	float gore = clamp(v_info.z * v_wear.x, 0.0, 1.0);
	float bl = v_wear.y;
	// Each zombie samples the noise somewhere else: wounds move around.
	vec3 q = v_rest + vec3(seed * 1.37, seed * 0.71, seed * 2.13) + v_wear.w * vec3(0.731, 0.419, 0.577);
	// Grime: low-frequency darkening, stronger towards the feet.
	float grime = fbm(q * 3.0) * dirt * (1.2 - clamp(v_rest.y * 0.5, 0.0, 1.0));
	base *= 1.0 - grime;
	if (rot > 0.5) {
		// Dead skin, relative to its own tone so light and dark skins both work.
		// Mottling: fine patches, a little warmer or cooler. Lividity: purple
		// blood pooled in blotches, heavier on the low body (gravity), with dark
		// veins running through it. A few greenish patches of decay on top.
		float mottle = 0.5 * vnoise(q * 9.0) + 0.5 * vnoise(q * 23.0);
		base *= 0.82 + 0.34 * mottle;
		base *= mix(vec3(1.05, 0.97, 0.9), vec3(0.9, 0.98, 1.07), vnoise(q * 4.0 + 8.0));
		float low = smoothstep(1.3, 0.6, v_rest.y);
		float pool = smoothstep(0.38, 0.66, fbm(q * 2.6 + 31.0)) * (0.3 + 0.7 * low);
		base = mix(base, base * vec3(0.45, 0.38, 0.78), pool * 0.75);
		float vein = (1.0 - smoothstep(0.0, 0.035, abs(fbm(q * 11.0 + 5.0) - 0.5))) * pool;
		base = mix(base, base * vec3(0.4, 0.36, 0.6), vein * 0.7);
		float blotch = smoothstep(0.5, 0.78, fbm(q * 5.0 + 11.0));
		base = mix(base, base * vec3(0.78, 0.84, 0.6), blotch * 0.45);
	}
	// Sunken eye sockets (the head's front): dark skin set back around each eye,
	// the bowl's normal tilting in towards the eye.
	float socket = 0.0;
	vec2 sock_d = vec2(0.0);
	if (abs(v_info.x - 2.0) < 0.5 && v_rest.z > 0.12 && v_rest.y > 1.7 && v_rest.y < 1.92) {
		vec2 dl = v_rest.xy - vec2(0.06, 1.82);
		vec2 dr = v_rest.xy - vec2(-0.06, 1.82);
		sock_d = length(dl) < length(dr) ? dl : dr;
		socket = 1.0 - smoothstep(0.03, 0.065, length(sock_d));
		base *= mix(1.0, 0.3, socket);
		vec3 bowl = normalize(vec3(-sock_d.x * 10.0, sock_d.y * 10.0, 1.0));  // tangent space: x along the face, y flipped
		NORMAL_MAP = mix(NORMAL_MAP, bowl * 0.5 + 0.5, socket);
	}
	// Wounds: noise blobs whose size grows with the box's gore amount.
	float w = fbm(q * 6.0);
	float cut = 0.76 - 0.2 * gore;
	float wound = gore > 0.01 ? smoothstep(cut, cut + 0.03, w) : 0.0;
	float rim = gore > 0.01 ? smoothstep(cut - 0.06, cut - 0.035, w) : 0.0;
	// Blood runs down: vertical streaks under wounds, plus a little spatter.
	float streak = fbm(vec3(q.x * 14.0, q.y * 1.6, q.z * 14.0));
	float below = fbm((q + vec3(0.0, 0.15, 0.0)) * 6.0);
	float drip = gore > 0.01 ? smoothstep(0.57 - 0.04 * bl, 0.7 - 0.04 * bl, streak) * smoothstep(cut - 0.12, cut - 0.02, below) : 0.0;
	float spatter = smoothstep(0.81 - 0.03 * bl, 0.84 - 0.03 * bl, vnoise(q * 28.0)) * gore;
	float fresh = smoothstep(0.5, 0.65, fbm(q * 4.0 + 5.0));
	vec3 dried = srgb(vec3(0.3, 0.07, 0.05));
	vec3 wet = srgb(vec3(0.42, 0.02, 0.02));
	// Large soaked stains (mostly dried); bloodier zombies soak more boxes.
	float soak = smoothstep(0.58 - 0.05 * bl, 0.66 - 0.05 * bl, fbm(q * 2.2 + 17.0)) * smoothstep(0.25, 0.7, gore);
	float blood = clamp(max(max(rim * 0.9, soak * 0.85), max(drip, spatter)), 0.0, 1.0);
	vec3 blood_col = mix(dried, wet, fresh * (1.0 - soak * 0.6));
	float blood_rough = mix(0.85, 0.15, fresh);
	if (is_cloth > 0.5 && v_look.z > 1.5) {
		// Torn cloth shows this zombie's skin; the frayed edge is dark. Rips
		// grow with the torn amount, wounds tear the cloth around them.
		vec3 skin = v_skin * (0.8 + 0.4 * vnoise(q * 30.0));
		float torn = gore > 0.01 ? smoothstep(cut - 0.035, cut - 0.015, w) : 0.0;
		float rn = fbm(q * 3.3 + 41.0);
		float rc = 0.88 - 0.1 * v_wear.z;
		float rip = smoothstep(rc, rc + 0.015, rn);
		// The frayed edge is a flat dark tone, and the torn cloth gets a smooth
		// normal: the weave of the cloth does not show along a rip.
		float edge = smoothstep(rc - 0.03, rc - 0.005, rn) - rip;
		base = mix(base, v_col * 0.45, edge);
		torn = max(torn, rip);
		base = mix(base, skin, torn);
		NORMAL_MAP = mix(NORMAL_MAP, vec3(0.5, 0.5, 1.0), max(torn, edge));
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
		// Dead eyes: a domed, glassy milky eyeball with a dark, dilated pupil.
		float side = v_rest.x >= 0.0 ? 0.06 : -0.06;
		vec2 e = (v_rest.xy - vec2(side, 1.82)) / vec2(0.0275, 0.0175);  // the eye box, -1..1
		float pupil = 1.0 - smoothstep(0.3, 0.45, length(e));
		base = mix(srgb(vec3(0.62, 0.62, 0.5)), srgb(vec3(0.02, 0.02, 0.02)), pupil);
		rough = mix(0.08, 0.25, pupil);
		NORMAL_MAP = vec3(normalize(vec3(e.x * 0.4, -e.y * 0.4, 1.0)) * 0.5 + 0.5);
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
