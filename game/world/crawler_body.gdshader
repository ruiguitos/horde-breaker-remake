shader_type spatial;
// Crawler body (CrawlerBody): the crawler.glb model as one mesh per horde, its
// pose done on the GPU. A separate shader from zombie.gdshader, so the walkers
// are untouched. The crawl mirrors ZombieModel's crawl (the stroke and the arm
// IK) with the GLB's own joints.
//
// Vertex data (built by CrawlerBody, model space: feet on y = 0, facing +Z,
// left side on +X):
//   CUSTOM0 = (part: 0 body, 1 head, 2 left arm, 3 right arm;
//              arm weight: 0 upper arm .. 1 forearm, 2 hand; roughness, unused)
//   CUSTOM1 = (linear tint r, g, b; slot: ZombieModel.Slot, 2 shirt, 3 trousers,
//              which take the zombie's palette colour)
// Per instance (MultiMesh), as in zombie.gdshader:
//   INSTANCE_CUSTOM = (walk phase, walk 0..1, lunge 0..1 or -stagger,
//                      flinch 0..1 | 2 + death 0..1 | 4 + headless death |
//                      6 + topple progress 0..1)
//   COLOR = (status index, legless mask, colours, wear): only status and the
//           colours (shirt 5 bits, trousers 4 bits from bit 5) are read here.

uniform vec4 joints_l = vec4(0.46, 0.58, 0.056, 0.845);  // shoulder (y, z), wrist at rest (y, z)
uniform vec4 bones_l = vec4(0.26, 0.28, 0.0, 0.0);       // upper arm, forearm length; rest angles
uniform vec4 joints_r = vec4(0.46, 0.58, 0.056, 0.835);
uniform vec4 bones_r = vec4(0.26, 0.28, 0.0, 0.0);
uniform vec3 neck = vec3(0.0, 0.685, 0.755);             // head pivot (the head's joint)
uniform vec4 status_tints[8];
uniform vec4 shirt_colors[32];
uniform vec4 trouser_colors[16];

varying vec3 v_rest;
varying flat vec3 v_col;
varying flat vec4 v_status;
varying float v_rough;

// Crawl stroke and arm IK: the same constants as ZombieModel (CRAWL_*), except
// the stroke's centre: the GLB's arms reach only about 5 cm past the rest point,
// so the stroke sits 0.16 m behind it (CrawlerBody.CENTRE_Z, the same value).
const float CRAWL_STRIDE = 0.8;
const float CRAWL_STANCE = 0.5;
const float CRAWL_LIFT = 0.1;
const float CRAWL_WALK_FULL = 0.15;
const float CRAWL_CENTRE_Z = -0.16;
const float PI_C = 3.14159265;
const float TAU_C = 6.28318531;
// The topple: from 0.8 rad of rear-up to lying forward on the hands.
const float TOPPLE_ANGLE = 0.8;
// The topple's pivot (model z): just in front of the fingertips (they reach
// z 1.023), so every point behind it rises and none goes under the ground.
const float TOPPLE_PIVOT_Z = 1.03;

mat3 rot_x(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, c, s), vec3(0.0, -s, c));
}

mat3 rot_z(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat3(vec3(c, s, 0.0), vec3(-s, c, 0.0), vec3(0.0, 0.0, 1.0));
}

// Rotates (y, z) by d so that a bone's direction angle (measured from straight
// down, towards +Z) grows by d: the sense that ZombieModel.crawl_arm uses.
vec2 spin(vec2 v, float d) {
	float c = cos(d);
	float s = sin(d);
	return vec2(c * v.x + s * v.y, -s * v.x + c * v.y);
}

// One hand's offset (dz forward, dy up) for the cycle fraction (ZombieModel.crawl_stroke).
vec2 crawl_stroke(float cycle) {
	float u = fract(cycle);
	float half_stride = CRAWL_STRIDE * CRAWL_STANCE * 0.5;
	if (u < CRAWL_STANCE) {
		return vec2(half_stride - 2.0 * half_stride * u / CRAWL_STANCE, 0.0);
	}
	float v = (u - CRAWL_STANCE) / (1.0 - CRAWL_STANCE);
	return vec2(-half_stride + half_stride * (1.0 - cos(PI_C * v)), CRAWL_LIFT * sin(PI_C * v));
}

// Two-bone IK in the arm's plane: t is the wrist relative to the shoulder (y, z).
// Returns the upper arm's angle and the forearm's absolute angle.
vec2 arm_ik(vec2 t, float l1, float l2) {
	float d = max(length(t), 0.001);
	float psi = atan(t.y, -t.x);
	float beta = acos(clamp((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0));
	float gamma = acos(clamp((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0));
	float upper = psi - beta;
	return vec2(upper, upper + PI_C - gamma);
}

// Colours are written as sRGB (what a paint picker shows); ALBEDO is linear.
vec3 srgb(vec3 c) {
	return pow(c, vec3(2.2));
}

// Sun-bleached cloth, as in zombie.gdshader.
vec3 faded(vec3 c, float f) {
	float l = dot(c, vec3(0.3, 0.59, 0.11));
	return mix(c, vec3(l) * vec3(1.04, 1.0, 0.9), 0.15 + 0.4 * f) * (1.0 - 0.12 * f);
}

void vertex() {
	int part = int(CUSTOM0.x + 0.5);
	float arm_w = CUSTOM0.y;
	v_rough = CUSTOM0.z;
	v_rest = VERTEX;
	uint cols = uint(COLOR.b + 0.5);
	vec3 col = CUSTOM1.rgb;
	int slot = int(CUSTOM1.a + 0.5);
	if (slot == 2) {
		col = srgb(faded(shirt_colors[int(cols & 31u)].rgb, 0.3));
	} else if (slot == 3) {
		col = srgb(faded(trouser_colors[int((cols >> 5u) & 15u)].rgb, 0.3));
	}
	v_col = col;
	v_status = status_tints[clamp(int(COLOR.r + 0.5), 0, 7)];

	vec4 ic = INSTANCE_CUSTOM;
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
	float fall = 1.0 - (1.0 - death) * (1.0 - death);

	vec3 p = VERTEX;
	vec3 n = NORMAL;
	if (part == 1) {
		// Head: lolls and nods, or pops off (collapsed onto the neck) when shot off.
		if (headless) {
			p = neck;
		} else {
			float loll = 0.06 * sin(phase * 0.5) + 0.12 * stagger * sin(phase * 3.0);
			mat3 r = rot_z(loll) * rot_x(-0.55 * flinch + 0.2 * lunge);
			p = neck + r * (p - neck);
			n = r * n;
		}
	} else if (part == 2 || part == 3) {
		bool left = part == 2;
		vec4 j = left ? joints_l : joints_r;
		vec4 b = left ? bones_l : bones_r;
		vec2 s = j.xy;
		vec2 w = j.zw;
		// The hands plant through the stance: the stroke scales with the walk,
		// so a Crawler standing still keeps its hands where they are.
		float k = smoothstep(0.0, CRAWL_WALK_FULL, walk);
		vec2 st = (crawl_stroke(phase / TAU_C + (left ? 0.0 : 0.5)) + vec2(CRAWL_CENTRE_Z, 0.0)) * k;
		vec2 tgt = vec2(w.x + st.y, w.y + st.x);
		if (arm_w > 1.5) {
			// The hand moves with its wrist and keeps its rest orientation (flat).
			p.yz += tgt - w;
		} else {
			vec2 ang = arm_ik(tgt - s, b.x, b.y);
			float d1 = ang.x - b.z;
			float d2 = ang.y - b.w - d1;
			// Rigid bones: the upper arm turns about the shoulder, the forearm
			// about the elbow where the upper arm now ends. Blended by arm_w.
			vec2 e_rel = vec2(-cos(b.z), sin(b.z)) * b.x;
			vec2 e1 = spin(e_rel, d1);
			vec2 p1 = spin(p.yz - s, d1);
			vec2 p2 = e1 + spin(p1 - e1, d2);
			p.yz = s + mix(p1, p2, arm_w);
			vec2 n1 = spin(n.yz, d1);
			n.yz = mix(n1, spin(n1, d2), arm_w);
		}
	}
	// Lunge: the whole body moves forward when it bites.
	p.z += 0.2 * lunge * (1.0 - fall);
	if (topple >= 0.0) {
		// Toppling: the rear rises from the hands (progress 0), then the body
		// lies forward on them (progress 1).
		float ang = -(1.0 - topple) * TOPPLE_ANGLE;
		vec2 pivot = vec2(0.0, TOPPLE_PIVOT_Z);
		p.yz = pivot + spin(p.yz - pivot, ang);
		n.yz = spin(n.yz, ang);
	}
	if (death > 0.0) {
		// Dead: the body sinks flat on the ground. A flattening scale turns the
		// normals by the inverse transpose: the vertical part shrinks by 1/scale.
		float flat_y = mix(1.0, 0.35, fall);
		p.y *= flat_y;
		n.y /= flat_y;
	}
	VERTEX = p;
	NORMAL = normalize(n);
}

void fragment() {
	vec3 base = v_col;
	// Dirt towards the ground: a flat tone gets a little depth.
	base *= 1.0 - 0.25 * (1.0 - smoothstep(0.0, 0.5, v_rest.y));
	base = mix(base, v_status.rgb, v_status.a);
	ALBEDO = base;
	ROUGHNESS = v_rough;
	METALLIC = 0.0;
	SPECULAR = 0.4;
}
