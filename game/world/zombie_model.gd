class_name ZombieModel
extends RefCounted
## The common zombie: blocky like the Recruit (boxes, ~1.95 m), but with
## realistic materials (Poly Haven PBR: skin, cotton jersey, denim, leather,
## linen) and procedural gore in zombie.gdshader.
##
## Built in code as one ArrayMesh per variant (the garment cut: T-shirt,
## work shirt, jacket, shirtless). Each box carries its part id (which joint
## it turns about), gore amount and seed in CUSTOM0, its tint and colour
## slot in CUSTOM1 and two Show conditions in CUSTOM2. The shader poses the
## parts from the per-instance data, so a whole horde is one MultiMesh per
## variant (ZombieHordeView).
##
## Per zombie, roll_look() picks colours from realistic palettes (shirt,
## trousers, skin, hair, shoes, jacket), a shirt pattern, the sleeves, a
## hood, a missing part, the build (thin..heavy) and how bloody and torn it
## is. The view sends that look as three exact integers in the instance
## colour; the shader recolours the textures, hides the boxes whose Show
## conditions are not set (collapses their vertices) and widens or narrows
## the body. The mesh stays the same, so there are still 4 MultiMeshes.
##
## Model space: feet on y = 0, facing +Z, left side on +X. Built for an
## EnemyType of height 1.7 (the Walker); the view scales it by
## height / MODEL_HEIGHT like the old capsule, so the head stays where
## IslandRun.enemy_head() puts it. Nothing in the look moves the head.

enum Part { PELVIS, TORSO, HEAD, ARM_UPPER_L, ARM_LOWER_L, ARM_UPPER_R, ARM_LOWER_R, LEG_UPPER_L, LEG_LOWER_L, LEG_UPPER_R, LEG_LOWER_R }
enum Layer { SKIN, JERSEY, DENIM, LEATHER, LINEN }
enum Kind { SURFACE, FLESH, BONE, EYE, MOUTH }
## Where a box takes its colour from: FIXED keeps the box's own tint (belt,
## flesh, bone); the others take the zombie's palette colour (times the box
## tint, e.g. darker brows).
enum Slot { FIXED, SKIN, SHIRT, TROUSERS, SHOES, HAIR, JACKET }
## Optional boxes. Bit n of a zombie's mask = condition n holds; a box shows
## when both of its conditions hold (ALWAYS is always set). Alternatives
## (cloth or bare forearm, shoe or bare foot) are both in the mesh, and the
## mask shows exactly one. zombie.gdshader reads STUMP_L (bit 2): keep it.
## LEGS: the legs are on (a walker). LEGLESS: a Crawler, legs gone: the hip
## stumps show and zombie.gdshader lays the body down (crawl pose). The view
## sets them per zombie (legless_mask); the leg boxes need LEGS.
enum Show { ALWAYS, FOREARM_L, STUMP_L, JAW, NO_JAW, EAR_L, NO_EAR_L, FINGERS_R, NO_FINGERS_R, LONG_SLEEVES, BARE_FOREARMS, UPPER_SLEEVES, BARE_UPPER_ARMS, SHOES, BAREFOOT, HAIR, LONG_HAIR, HOOD, SHIN_R_CLOTH, SHIN_R_BARE, LEGS, LEGLESS }
enum Missing { NONE, FOREARM, JAW, EAR, FINGERS }
enum Pattern { PLAIN, STRIPES, PLAID, PRINT }
## SHORT: T-shirt sleeves, or a work shirt rolled up (bare forearms).
enum Sleeves { LONG, SHORT, TANK }
## Status tints: the instance sends an index (ZombieHordeView), the shader
## mixes in STATUS_TINTS[index].rgb by .a.
enum Status { NONE, FROZEN, STUNNED, BURNING, POISONED, COLD, FLASH }
const STATUS_TINTS: Array[Color] = [
	Color(0, 0, 0, 0), Color(0.55, 0.92, 1.0, 0.75), Color(1, 1, 1, 0.2), Color(1.0, 0.35, 0.08, 0.55),
	Color(0.65, 0.9, 0.16, 0.5), Color(0.25, 0.7, 1.0, 0.4), Color(1, 1, 1, 0.55),
]

const VARIANTS: int = 4
const VARIANT_NAMES: Array[String] = ["civilian", "worker", "jacket", "shirtless"]
const MODEL_HEIGHT: float = 1.7
## Centre of the skull box in the rest pose (model space); with the jaw the
## head spans 1.61-1.93 m. IslandRun.enemy_head() aims at height + 0.08 m:
## 1.78 m for the Walker.
const HEAD_CENTER: Vector3 = Vector3(0, 1.8, 0.03)
const SHADER: String = "res://game/world/zombie.gdshader"
const TEX: String = "res://assets/textures/polyhaven/"
## Poly Haven texture set, texture repeats per metre, cloth (tears show
## skin), rot blotches, grime, and "mean": the diffuse texture's average
## luminance (linear), measured from its 1x1 mipmap. Recolouring divides by
## it, so a box averages exactly its palette colour; re-measure if a
## texture changes (Image.resize(1, 1) of the decompressed diffuse).
const LAYERS: Array[Dictionary] = [
	{"id": "leather_white", "uv": 3.0, "cloth": 0.0, "rot": 1.0, "dirt": 0.25, "mean": 0.287},
	{"id": "cotton_jersey", "uv": 3.0, "cloth": 1.0, "rot": 0.0, "dirt": 0.5, "mean": 0.43},
	{"id": "denim_fabric_06", "uv": 2.5, "cloth": 1.0, "rot": 0.0, "dirt": 0.4, "mean": 0.0143},
	{"id": "fabric_leather_02", "uv": 2.0, "cloth": 1.0, "rot": 0.0, "dirt": 0.3, "mean": 0.0961},
	{"id": "rough_linen", "uv": 3.0, "cloth": 1.0, "rot": 0.0, "dirt": 0.5, "mean": 0.394},
]
## The old fixed skin tint (island.gd tints head debris with it).
const SKIN_TINT: Color = Color(0.74, 0.78, 0.66)

## Palettes, in sRGB (what a colour picker shows). The textures are
## recoloured to these on average, keeping their weave/grain. Clothes are
## faded, dusty and desaturated; skins are dead (grey-green, waxy, ashen)
## across light to dark tones.
const SKIN_COLORS: Array[Color] = [
	Color(0.56, 0.59, 0.48), Color(0.61, 0.59, 0.47), Color(0.53, 0.55, 0.53), Color(0.5, 0.48, 0.37),
	Color(0.43, 0.4, 0.31), Color(0.37, 0.33, 0.27), Color(0.31, 0.28, 0.24), Color(0.52, 0.53, 0.55),
]
const SHIRT_COLORS: Array[Color] = [
	Color(0.78, 0.76, 0.68), Color(0.7, 0.68, 0.6), Color(0.68, 0.62, 0.5), Color(0.62, 0.56, 0.44),
	Color(0.55, 0.55, 0.53), Color(0.28, 0.28, 0.29), Color(0.2, 0.2, 0.21), Color(0.22, 0.27, 0.38),
	Color(0.36, 0.42, 0.52), Color(0.52, 0.62, 0.7), Color(0.4, 0.48, 0.58), Color(0.18, 0.34, 0.36),
	Color(0.32, 0.5, 0.5), Color(0.2, 0.32, 0.22), Color(0.38, 0.4, 0.24), Color(0.52, 0.58, 0.48),
	Color(0.56, 0.66, 0.58), Color(0.62, 0.52, 0.3), Color(0.6, 0.44, 0.2), Color(0.58, 0.32, 0.2),
	Color(0.5, 0.24, 0.2), Color(0.58, 0.24, 0.24), Color(0.36, 0.14, 0.16), Color(0.7, 0.48, 0.42),
	Color(0.52, 0.4, 0.46), Color(0.34, 0.22, 0.32), Color(0.4, 0.34, 0.5), Color(0.38, 0.28, 0.2),
	Color(0.55, 0.5, 0.36), Color(0.66, 0.63, 0.36), Color(0.68, 0.46, 0.27), Color(0.42, 0.46, 0.5),
]
const TROUSER_COLORS: Array[Color] = [
	Color(0.14, 0.18, 0.3), Color(0.22, 0.3, 0.45), Color(0.38, 0.46, 0.58), Color(0.52, 0.58, 0.66),
	Color(0.14, 0.14, 0.15), Color(0.26, 0.26, 0.27), Color(0.45, 0.45, 0.44), Color(0.58, 0.52, 0.38),
	Color(0.55, 0.44, 0.3), Color(0.34, 0.36, 0.24), Color(0.32, 0.24, 0.18), Color(0.17, 0.2, 0.28),
	Color(0.18, 0.24, 0.18), Color(0.66, 0.6, 0.48), Color(0.44, 0.26, 0.16), Color(0.24, 0.3, 0.4),
]
## Index 0 is bald (the hair boxes hide); the colour is unused.
const HAIR_COLORS: Array[Color] = [
	Color(0, 0, 0), Color(0.07, 0.06, 0.06), Color(0.18, 0.13, 0.1), Color(0.3, 0.21, 0.14),
	Color(0.55, 0.46, 0.3), Color(0.5, 0.27, 0.15), Color(0.5, 0.5, 0.48), Color(0.72, 0.7, 0.66),
]
const SHOE_COLORS: Array[Color] = [Color(0.38, 0.27, 0.19), Color(0.13, 0.12, 0.12), Color(0.66, 0.64, 0.58), Color(0.4, 0.4, 0.4)]
const JACKET_COLORS: Array[Color] = [Color(0.12, 0.11, 0.11), Color(0.34, 0.22, 0.15), Color(0.3, 0.12, 0.11), Color(0.3, 0.32, 0.22)]
const PATTERN_COLORS: Array[Color] = [
	Color(0.82, 0.8, 0.72), Color(0.12, 0.12, 0.12), Color(0.55, 0.15, 0.14), Color(0.15, 0.19, 0.32),
	Color(0.7, 0.56, 0.22), Color(0.17, 0.3, 0.19), Color(0.5, 0.5, 0.5), Color(0.36, 0.24, 0.16),
]

## Joints of zombie.gdshader (keep both in sync).
const WAIST: Vector3 = Vector3(0, 1.02, 0)
const NECK: Vector3 = Vector3(0, 1.58, 0.02)
## Crawl pose (legless, added 2026-10-17; zombie.gdshader mirrors them):
## the upper body pitches forward about the waist and sinks by CRAWL_DROP so
## the hands reach the ground; the head is lifted (CRAWL_HEAD_NOD). Model
## metres; the Crawler's aim height in enemies.tres is 0.7 m, close to where
## its head is drawn.
const CRAWL_LEAN: float = 1.2
const CRAWL_DROP: float = 0.68
const CRAWL_HEAD_NOD: float = -0.5
## Crawl arms (2026-10-17): each hand has a cycle of CRAWL_STRIDE metres of
## travel. In the stance (CRAWL_STANCE of the cycle) the hand is planted: it
## stays on the ground and slides back in the body's frame at the crawl speed,
## so the body moves over it. In the recovery the hand lifts by CRAWL_LIFT and
## comes back forward. The arms alternate. The phase rate is set from the crawl
## speed (crawl_phase_rate), so a hand stays planted while the Crawler moves
## at its nominal speed. Two-bone IK (crawl_arm) gives the upper arm and the
## elbow bend for each hand target; the shader does the same.
const CRAWL_STRIDE: float = 0.8
const CRAWL_STANCE: float = 0.5
const CRAWL_LIFT: float = 0.1
## The hand centre on the ground, and its rest point: metres ahead of the
## model origin (world z), under the shoulders in the crawl pose.
const CRAWL_HAND_Y: float = 0.07
const CRAWL_HAND_Z: float = 0.44
## Arm bones (metres, the shader's joints): shoulder to elbow, elbow to hand.
const CRAWL_UPPER: float = 0.30
const CRAWL_FOREARM: float = 0.335
## Where a Crawler is aimed (IslandRun.enemy_head / enemy_chest), in metres
## above the ground: the posed head centre and torso centre at rest of the
## pose (crawl_points(0)). Tests check they match the pose.
const CRAWL_HEAD_HEIGHT: float = 0.685
const CRAWL_CHEST_HEIGHT: float = 0.44
## Joints of the crawl pose: the shoulder, the hand's x.
const SHOULDER: Vector3 = Vector3(0.27, 1.49, 0.0)
const HAND_X: float = 0.29
## Hip stump length per variant (metres): civilian, worker, jacket, shirtless.
const STUMP_LENGTHS: Array[float] = [0.16, 0.1, 0.13, 0.08]

static var _meshes: Array[ArrayMesh] = []
static var _materials: Array[ShaderMaterial] = []


## The per-zombie seed. The horde uses the enemy's rolled base speed
## (Horde.speeds), which travels with it when indices are compacted, so the
## same zombie always gets the same seed, variant and look.
static func seed_for(key: float) -> int:
	return hash(snappedf(key, 0.0001))


## A stable variant from any per-enemy number (see seed_for).
static func variant_for(key: float) -> int:
	return posmod(seed_for(key), VARIANTS)


## What the view sends per zombie: (variant, mask, colours, wear), the last
## three as integers below 2^24, exact in the float32 instance colour.
static func instance_look(key: float) -> Vector4:
	var look: Dictionary = roll_look(seed_for(key))
	return Vector4(look["variant"], look["mask"], look["colours"], look["wear"])


## Rolls one zombie's look from its seed: readable fields (palette indices,
## pattern, sleeves, missing part, wear 0..7) plus the packed "mask",
## "colours" and "wear" the shader decodes. Deterministic: the same seed
## gives the same zombie on every machine (RandomNumberGenerator is PCG).
static func roll_look(seed: int) -> Dictionary:
	var variant: int = posmod(seed, VARIANTS)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var l: Dictionary = {"variant": variant}
	l["shirt"] = rng.randi_range(0, SHIRT_COLORS.size() - 1)
	l["trousers"] = rng.randi_range(0, TROUSER_COLORS.size() - 1)
	l["skin"] = rng.randi_range(0, SKIN_COLORS.size() - 1)
	l["hair"] = 0 if rng.randf() < (0.35 if variant == 3 else 0.18) else rng.randi_range(1, HAIR_COLORS.size() - 1)
	l["long_hair"] = l["hair"] > 0 and rng.randf() < 0.2
	l["shoes"] = rng.randi_range(0, SHOE_COLORS.size() - 1)
	l["barefoot"] = rng.randf() < (0.45 if variant == 3 else 0.08)
	l["jacket"] = rng.randi_range(0, JACKET_COLORS.size() - 1)
	l["pattern_color"] = rng.randi_range(0, PATTERN_COLORS.size() - 1)
	var sleeves: int = Sleeves.LONG
	var hood: bool = false
	var pattern: int = Pattern.PLAIN
	match variant:
		0:  # T-shirt (55 %), long-sleeved tee, tank top, hoodie
			var cut: int = _pick(rng, [55, 12, 15, 18])
			hood = cut == 3
			sleeves = [Sleeves.SHORT, Sleeves.LONG, Sleeves.TANK, Sleeves.LONG][cut]
			pattern = _pick(rng, [60, 0, 0, 40] if hood else [40, 25, 10, 25])
		1:  # work shirt, sleeves down or rolled up; flannel plaid is common
			sleeves = Sleeves.LONG if rng.randf() < 0.6 else Sleeves.SHORT
			pattern = _pick(rng, [35, 20, 45, 0])
		2:  # jacket over a T-shirt (the pattern is on the T-shirt)
			pattern = _pick(rng, [50, 25, 0, 25])
		3:
			sleeves = Sleeves.TANK
	l["sleeves"] = sleeves
	l["hood"] = hood
	l["pattern"] = pattern
	l["missing"] = _pick(rng, [36, 16, 16, 16, 16])
	l["torn_leg"] = rng.randf() < (0.6 if variant == 3 else 0.1)
	for k: String in ["gore", "blood", "torn", "fade", "build"]:
		l[k] = rng.randi_range(0, 7)
	l["offset"] = rng.randi_range(0, 255)
	l["mask"] = _mask(l)
	l["colours"] = l["shirt"] | l["trousers"] << 5 | l["skin"] << 9 | l["hair"] << 12 | l["pattern"] << 15 \
		| l["pattern_color"] << 17 | l["shoes"] << 20 | l["jacket"] << 22
	l["wear"] = l["gore"] | l["blood"] << 3 | l["torn"] << 6 | l["fade"] << 9 | l["build"] << 12 | l["offset"] << 15
	return l


## Build of a look, -1 (thin) .. +1 (heavy), as zombie.gdshader decodes it.
static func build_of(look: Dictionary) -> float:
	return float(look["build"]) / 3.5 - 1.0


static func _pick(rng: RandomNumberGenerator, weights: Array) -> int:
	var total: float = 0.0
	for w: Variant in weights:
		total += float(w)
	var r: float = rng.randf() * total
	for k in weights.size():
		r -= float(weights[k])
		if r < 0.0:
			return k
	return weights.size() - 1


## The mask of a Crawler: the same look with the legs off and the stumps on.
static func legless_mask(mask: int) -> int:
	return (mask & ~(1 << Show.LEGS)) | (1 << Show.LEGLESS)


static func is_legless(mask: int) -> bool:
	return (mask >> Show.LEGLESS) & 1 == 1


static func _mask(l: Dictionary) -> int:
	var on: Array[int] = [Show.ALWAYS, Show.LEGS]
	var missing: int = l["missing"]
	on.append(Show.STUMP_L if missing == Missing.FOREARM else Show.FOREARM_L)
	on.append(Show.NO_JAW if missing == Missing.JAW else Show.JAW)
	on.append(Show.NO_EAR_L if missing == Missing.EAR else Show.EAR_L)
	on.append(Show.NO_FINGERS_R if missing == Missing.FINGERS else Show.FINGERS_R)
	match int(l["sleeves"]):
		Sleeves.LONG:
			on.append_array([Show.LONG_SLEEVES, Show.UPPER_SLEEVES])
		Sleeves.SHORT:
			on.append_array([Show.BARE_FOREARMS, Show.UPPER_SLEEVES])
		_:
			on.append_array([Show.BARE_FOREARMS, Show.BARE_UPPER_ARMS])
	on.append(Show.BAREFOOT if l["barefoot"] else Show.SHOES)
	if int(l["hair"]) > 0:
		on.append(Show.HAIR)
		if l["long_hair"]:
			on.append(Show.LONG_HAIR)
	if l["hood"]:
		on.append(Show.HOOD)
	on.append(Show.SHIN_R_BARE if l["torn_leg"] else Show.SHIN_R_CLOTH)
	var m: int = 0
	for s: int in on:
		m |= 1 << s
	return m


## Whether box `b` shows for a zombie with this mask (the shader's test).
static func shows(b: Dictionary, mask: int) -> bool:
	return (mask >> int(b["show_a"])) & (mask >> int(b["show_b"])) & 1 == 1


## The shared mesh of one variant (built once, then cached).
static func mesh(variant: int) -> ArrayMesh:
	if _meshes.is_empty():
		for v in VARIANTS:
			_meshes.append(_build_mesh(v))
	return _meshes[clampi(variant, 0, VARIANTS - 1)]


## Where the shader puts the skull centre (model space) for a pose: the
## same head, torso and root rotations as zombie.gdshader, so tests can check
## the drawn head stays near IslandRun.enemy_head() while walking. The build
## (thin/heavy) only scales the body and limbs sideways and in depth, never
## the head or the joints it hangs from, so it is not a parameter here.
static func head_pose(walk: float, lunge: float, flinch: float, phase: float) -> Vector3:
	var s: float = sin(phase)
	var p: Vector3 = HEAD_CENTER
	var loll: float = 0.22 * sin(phase * 0.5) + 0.1
	var head := Basis(Vector3.FORWARD, -loll) * Basis(Vector3.RIGHT, -0.18 - 0.55 * flinch + 0.2 * lunge)
	p = NECK + head * (p - NECK)
	var lean: float = 0.18 + 0.08 * walk + 0.4 * lunge - 0.5 * flinch
	p = WAIST + (Basis(Vector3.RIGHT, lean) * Basis(Vector3.UP, 0.14 * walk * s)) * (p - WAIST)
	p = Basis(Vector3.FORWARD, -(0.05 * walk * s)) * p
	return p + Vector3(0, 0.04 * walk * absf(s), 0.2 * lunge)


## The phase rate (radians per second) of a Crawler with this rolled speed:
## its nominal crawl speed over one stride, so the arms' cycle matches its
## travel (ZombieHordeView sends it as the walk phase).
static func crawl_phase_rate(base_speed: float) -> float:
	return TAU * GameData.CRAWL_SPEED_RATIO * base_speed / CRAWL_STRIDE


## Where a hand is in its cycle: the offset from the rest point (dz forward,
## dy up, metres) for cycle fraction `cycle` (0..1, wraps). Stance: the hand
## is on the ground and dz falls from +half to -half over the stance, so it
## moves back at the crawl speed. Recovery: dy is a sine (the lift) and dz
## returns forward with an ease. Mirrored by zombie.gdshader crawl_stroke().
static func crawl_stroke(cycle: float) -> Vector2:
	var u: float = fposmod(cycle, 1.0)
	var half_stride: float = CRAWL_STRIDE * CRAWL_STANCE * 0.5
	if u < CRAWL_STANCE:
		return Vector2(half_stride - 2.0 * half_stride * u / CRAWL_STANCE, 0.0)
	var v: float = (u - CRAWL_STANCE) / (1.0 - CRAWL_STANCE)
	return Vector2(-half_stride + half_stride * (1.0 - cos(PI * v)), CRAWL_LIFT * sin(PI * v))


## Two-bone IK in the arm's plane: the upper arm's reach and the elbow bend
## that put the hand centre at `hand_world` (the posed frame, after the lean
## and the drop). Angles are measured from straight down, towards +Z.
## Mirrored by zombie.gdshader crawl_arm().
static func crawl_arm(hand_world: Vector3) -> Vector2:
	var loc: Vector3 = _turn(hand_world + Vector3(0, CRAWL_DROP, 0), Basis(Vector3.RIGHT, -CRAWL_LEAN), WAIST)
	var ty: float = loc.y - SHOULDER.y
	var tz: float = loc.z - SHOULDER.z
	var d: float = maxf(sqrt(ty * ty + tz * tz), 0.001)
	var psi: float = atan2(tz, -ty)
	var beta: float = acos(clampf((CRAWL_UPPER * CRAWL_UPPER + d * d - CRAWL_FOREARM * CRAWL_FOREARM) / (2.0 * CRAWL_UPPER * d), -1.0, 1.0))
	var gamma: float = acos(clampf((CRAWL_UPPER * CRAWL_UPPER + CRAWL_FOREARM * CRAWL_FOREARM - d * d) / (2.0 * CRAWL_UPPER * CRAWL_FOREARM), -1.0, 1.0))
	return Vector2(psi - beta, PI - gamma)


## CPU mirror of the legless crawl pose in zombie.gdshader (tests and the
## design numbers): the head centre, the left hand, the lowest corner of the
## torso and the left hip stump, in model space. `cycle` is the left hand's
## cycle fraction (0..1; 0 starts its stance; the right hand is half a cycle
## behind). The hand is planted through the stance; see crawl_stroke().
static func crawl_points(cycle: float = 0.0) -> Dictionary:
	var torso := Basis(Vector3.RIGHT, CRAWL_LEAN)
	var drop := Vector3(0, -CRAWL_DROP, 0)
	var head: Vector3 = _turn(HEAD_CENTER, Basis(Vector3.RIGHT, CRAWL_HEAD_NOD), NECK)
	head = _turn(head, torso, WAIST) + drop
	var stroke: Vector2 = crawl_stroke(cycle)
	var target := Vector3(HAND_X, CRAWL_HAND_Y + stroke.y, CRAWL_HAND_Z + stroke.x)
	var angles: Vector2 = crawl_arm(target)
	var shoulder := Vector3(HAND_X, SHOULDER.y, SHOULDER.z)
	var elbow: Vector3 = shoulder + Vector3(0, -CRAWL_UPPER * cos(angles.x), CRAWL_UPPER * sin(angles.x))
	var wrist: Vector3 = elbow + Vector3(0, -CRAWL_FOREARM * cos(angles.x + angles.y), CRAWL_FOREARM * sin(angles.x + angles.y))
	var hand: Vector3 = _turn(wrist, torso, WAIST) + drop
	var stump: Vector3 = _turn(Vector3(0.12, 0.86, 0.0), torso, WAIST) + drop
	var lowest: float = INF
	var c := Vector3(0, 1.3, 0)
	var h := Vector3(0.23, 0.25, 0.13)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var corner: Vector3 = _turn(c + Vector3(h.x * sx, h.y * sy, h.z * sz), torso, WAIST) + drop
				lowest = minf(lowest, corner.y)
	var torso_centre: Vector3 = _turn(c, torso, WAIST) + drop
	return {"head": head, "hand": hand, "torso_low": lowest, "stump": stump, "torso": torso_centre}


static func _turn(p: Vector3, r: Basis, pivot: Vector3) -> Vector3:
	return pivot + r * (p - pivot)


## One material per texture layer, shared by every variant.
static func material(layer: int) -> ShaderMaterial:
	if _materials.is_empty():
		var shader := load(SHADER) as Shader
		for l: Dictionary in LAYERS:
			var m := ShaderMaterial.new()
			m.shader = shader
			m.set_shader_parameter(&"albedo_tex", _texture(l["id"], "diffuse"))
			m.set_shader_parameter(&"normal_tex", _texture(l["id"], "nor_gl"))
			m.set_shader_parameter(&"rough_tex", _texture(l["id"], "rough"))
			m.set_shader_parameter(&"uv_scale", l["uv"])
			m.set_shader_parameter(&"is_cloth", l["cloth"])
			m.set_shader_parameter(&"rot", l["rot"])
			m.set_shader_parameter(&"dirt", l["dirt"])
			m.set_shader_parameter(&"tex_mean", l["mean"])
			m.set_shader_parameter(&"skin_colors", _vec4s(SKIN_COLORS))
			m.set_shader_parameter(&"shirt_colors", _vec4s(SHIRT_COLORS))
			m.set_shader_parameter(&"trouser_colors", _vec4s(TROUSER_COLORS))
			m.set_shader_parameter(&"hair_colors", _vec4s(HAIR_COLORS))
			m.set_shader_parameter(&"shoe_colors", _vec4s(SHOE_COLORS))
			m.set_shader_parameter(&"jacket_colors", _vec4s(JACKET_COLORS))
			m.set_shader_parameter(&"pattern_colors", _vec4s(PATTERN_COLORS))
			m.set_shader_parameter(&"status_tints", _vec4s(STATUS_TINTS))
			_materials.append(m)
	return _materials[layer]


## Palettes go to the shader as plain vec4s: a PackedColorArray would be
## converted to linear by Godot for 3D shaders, and the shader already does
## that conversion itself (srgb()), as it did for the old per-box tints.
static func _vec4s(colors: Array[Color]) -> PackedVector4Array:
	var out := PackedVector4Array()
	for c: Color in colors:
		out.append(Vector4(c.r, c.g, c.b, c.a))
	return out


static func _texture(id: String, map: String) -> Texture2D:
	var path: String = TEX + "%s_%s.res" % [id, map]
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## The boxes of one variant: {c: centre, s: size, part, layer, slot, tint,
## gore (0..1), kind, seed, show_a, show_b}. Tests read them; _build_mesh
## turns them into a mesh. Optional boxes (Show) come in pairs that the
## look's mask switches between.
static func boxes(variant: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seed: float = 3.1 + variant * 7.7
	var add := func(c: Vector3, s: Vector3, part: int, layer: int, slot: int, gore: float = 0.0, kind: int = Kind.SURFACE,
			show_a: int = Show.ALWAYS, show_b: int = Show.ALWAYS, tint: Color = Color.WHITE) -> void:
		out.append({"c": c, "s": s, "part": part, "layer": layer, "slot": slot, "tint": tint, "gore": gore, "kind": kind,
			"seed": seed, "show_a": show_a, "show_b": show_b})
	var shirt_layer: int = [Layer.JERSEY, Layer.LINEN, Layer.LEATHER, Layer.SKIN][variant]
	var shirt_slot: int = [Slot.SHIRT, Slot.SHIRT, Slot.JACKET, Slot.SKIN][variant]
	var legs_layer: int = Layer.JERSEY if variant == 3 else Layer.DENIM  # chinos or jeans
	# Legs: thighs and shins hang from the hips and knees (shin + foot move together).
	for side: float in [1.0, -1.0]:
		var left: bool = side > 0.0
		var thigh: int = Part.LEG_UPPER_L if left else Part.LEG_UPPER_R
		var shin: int = Part.LEG_LOWER_L if left else Part.LEG_LOWER_R
		var x: float = 0.12 * side
		# Every leg box needs LEGS (off for a Crawler) and its own condition.
		add.call(Vector3(x, 0.71, 0), Vector3(0.17, 0.44, 0.18), thigh, legs_layer, Slot.TROUSERS, 0.35 if variant == 0 and left else 0.15,
			Kind.SURFACE, Show.LEGS)
		if left:
			add.call(Vector3(x, 0.31, 0), Vector3(0.15, 0.42, 0.16), shin, legs_layer, Slot.TROUSERS, 0.1, Kind.SURFACE, Show.LEGS)
		else:
			# The right trouser leg may be torn off: a bare, bitten shin.
			add.call(Vector3(x, 0.31, 0), Vector3(0.15, 0.42, 0.16), shin, legs_layer, Slot.TROUSERS, 0.1, Kind.SURFACE, Show.LEGS, Show.SHIN_R_CLOTH)
			add.call(Vector3(x, 0.31, 0), Vector3(0.13, 0.42, 0.14), shin, Layer.SKIN, Slot.SKIN, 0.75, Kind.SURFACE, Show.LEGS, Show.SHIN_R_BARE)
		add.call(Vector3(x, 0.045, 0.04), Vector3(0.13, 0.09, 0.25), shin, Layer.SKIN, Slot.SKIN, 0.3, Kind.SURFACE, Show.LEGS, Show.BAREFOOT)
		if variant == 1:  # work boots
			add.call(Vector3(x, 0.15, 0.0), Vector3(0.165, 0.3, 0.175), shin, Layer.LEATHER, Slot.SHOES, 0.0, Kind.SURFACE, Show.LEGS, Show.SHOES)
			add.call(Vector3(x, 0.05, 0.05), Vector3(0.16, 0.1, 0.27), shin, Layer.LEATHER, Slot.SHOES, 0.0, Kind.SURFACE, Show.LEGS, Show.SHOES)
		else:
			add.call(Vector3(x, 0.05, 0.05), Vector3(0.15, 0.1, 0.27), shin, Layer.LEATHER, Slot.SHOES, 0.0, Kind.SURFACE, Show.LEGS, Show.SHOES)
		# Crawler: the hip stump, dark flesh whose length depends on the variant
		# (a worker's is short, a civilian's long; the left one a little
		# longer). A bone tip sticks out of its end, and two blood-soaked
		# trouser flaps hang beside it, outside and behind. The crawl pose
		# turns the pelvis, so these end up behind the body.
		var stump_len: float = STUMP_LENGTHS[variant] + (0.02 if left else 0.0)
		var stump_top: float = 0.93
		var stump_end: float = stump_top - stump_len
		add.call(Vector3(x, (stump_top + stump_end) * 0.5, 0.0), Vector3(0.15, stump_len, 0.16), Part.PELVIS, Layer.SKIN, Slot.FIXED, 0.9, Kind.FLESH, Show.LEGLESS)
		add.call(Vector3(x, stump_end - 0.02, -0.03), Vector3(0.06, 0.07, 0.06), Part.PELVIS, Layer.SKIN, Slot.FIXED, 0.0, Kind.BONE, Show.LEGLESS)
		var flap_top: float = stump_top + 0.05
		var flap_end: float = stump_end + 0.02
		var flap_mid: float = (flap_top + flap_end) * 0.5
		var flap_len: float = flap_top - flap_end
		add.call(Vector3(x + 0.085 * side, flap_mid, 0.0), Vector3(0.03, flap_len, 0.15), Part.PELVIS, legs_layer, Slot.TROUSERS, 0.9, Kind.SURFACE, Show.LEGLESS)
		out.back()["rotation"] = Vector3(0.0, 0.0, 0.12 * side)
		add.call(Vector3(x, flap_mid, -0.09), Vector3(0.15, flap_len, 0.03), Part.PELVIS, legs_layer, Slot.TROUSERS, 0.9, Kind.SURFACE, Show.LEGLESS)
		out.back()["rotation"] = Vector3(-0.12, 0.0, 0.0)
	# Pelvis and belt.
	add.call(Vector3(0, 0.97, 0), Vector3(0.42, 0.2, 0.22), Part.PELVIS, legs_layer, Slot.TROUSERS, 0.1)
	add.call(Vector3(0, 1.06, 0), Vector3(0.44, 0.05, 0.235), Part.PELVIS, Layer.LEATHER, Slot.FIXED, 0.0, Kind.SURFACE, Show.ALWAYS, Show.ALWAYS, Color(0.3, 0.25, 0.22))
	# Torso.
	var torso_gore: float = [0.85, 0.6, 0.5, 0.95][variant]
	if variant != 3:  # the shirtless one's torso is built in pieces, below
		add.call(Vector3(0, 1.3, 0), Vector3(0.46, 0.5, 0.26), Part.TORSO, shirt_layer, shirt_slot, torso_gore)
	if variant == 0:
		# Hoodie: the hood bunched behind the neck, a front pocket, drawstrings.
		add.call(Vector3(0, 1.54, -0.13), Vector3(0.36, 0.13, 0.1), Part.TORSO, Layer.JERSEY, Slot.SHIRT, 0.2, Kind.SURFACE, Show.HOOD)
		add.call(Vector3(0, 1.15, 0.133), Vector3(0.27, 0.12, 0.012), Part.TORSO, Layer.JERSEY, Slot.SHIRT, 0.3, Kind.SURFACE, Show.HOOD, Show.ALWAYS, Color(0.82, 0.82, 0.82))
		for k: float in [1.0, -1.0]:
			add.call(Vector3(0.05 * k, 1.46, 0.135), Vector3(0.012, 0.13, 0.008), Part.TORSO, Layer.JERSEY, Slot.FIXED, 0.0, Kind.SURFACE, Show.HOOD, Show.ALWAYS, Color(0.7, 0.68, 0.62))
	if variant == 2:
		# Open jacket over a T-shirt soaked from the neck down.
		add.call(Vector3(0, 1.29, 0.132), Vector3(0.16, 0.46, 0.012), Part.TORSO, Layer.JERSEY, Slot.SHIRT, 0.95)
		add.call(Vector3(0, 1.53, -0.02), Vector3(0.48, 0.06, 0.29), Part.TORSO, Layer.LEATHER, Slot.JACKET)  # collar
	if variant == 3:
		# Torn-open flank, cut into the front of the torso (not a sticker on an
		# intact box). The torso is a back block plus a front wall around an
		# opening (x -0.17..0.09, y 1.14..1.34). Behind the opening is a dark
		# cavity: a floor and four inner walls of dark flesh, three ribs set back
		# inside it, and raw flesh lips at the corners, angled 45 degrees.
		add.call(Vector3(0, 1.3, -0.065), Vector3(0.46, 0.5, 0.13), Part.TORSO, shirt_layer, shirt_slot, torso_gore)
		add.call(Vector3(0, 1.445, 0.065), Vector3(0.46, 0.21, 0.13), Part.TORSO, shirt_layer, shirt_slot, torso_gore)  # above
		add.call(Vector3(0, 1.095, 0.065), Vector3(0.46, 0.09, 0.13), Part.TORSO, shirt_layer, shirt_slot, torso_gore)  # below
		add.call(Vector3(-0.2, 1.24, 0.065), Vector3(0.06, 0.2, 0.13), Part.TORSO, shirt_layer, shirt_slot, torso_gore)  # left of it
		add.call(Vector3(0.16, 1.24, 0.065), Vector3(0.14, 0.2, 0.13), Part.TORSO, shirt_layer, shirt_slot, torso_gore)  # right of it
		add.call(Vector3(-0.04, 1.24, 0.01), Vector3(0.26, 0.2, 0.02), Part.TORSO, Layer.SKIN, Slot.FIXED, 0.0, Kind.MOUTH)  # floor
		add.call(Vector3(-0.04, 1.335, 0.065), Vector3(0.26, 0.01, 0.13), Part.TORSO, Layer.SKIN, Slot.FIXED, 0.0, Kind.MOUTH)  # roof
		add.call(Vector3(-0.04, 1.145, 0.065), Vector3(0.26, 0.01, 0.13), Part.TORSO, Layer.SKIN, Slot.FIXED, 0.0, Kind.MOUTH)  # sill
		add.call(Vector3(-0.165, 1.24, 0.065), Vector3(0.01, 0.2, 0.13), Part.TORSO, Layer.SKIN, Slot.FIXED, 0.0, Kind.MOUTH)  # left wall
		add.call(Vector3(0.085, 1.24, 0.065), Vector3(0.01, 0.2, 0.13), Part.TORSO, Layer.SKIN, Slot.FIXED, 0.0, Kind.MOUTH)  # right wall
		# Ribs at uneven heights, depths and lengths, so the cavity reads as real.
		var rib_y: Array[float] = [1.19, 1.237, 1.296]
		var rib_depth: Array[float] = [0.035, 0.043, 0.029]
		var rib_len: Array[float] = [0.2, 0.17, 0.22]
		var rib_x: Array[float] = [-0.04, -0.02, -0.06]
		for k in 3:
			add.call(Vector3(rib_x[k], rib_y[k], rib_depth[k]), Vector3(rib_len[k], 0.018, 0.02), Part.TORSO, Layer.SKIN, Slot.FIXED, 0.0, Kind.BONE)  # ribs
		# Lips of torn flesh: each corner its own size and angle.
		var lip_pos: Array[Vector2] = [Vector2(-0.17, 1.34), Vector2(0.09, 1.33), Vector2(-0.16, 1.14), Vector2(0.1, 1.15)]
		var lip_size: Array[float] = [0.05, 0.065, 0.042, 0.056]
		var lip_angle: Array[float] = [PI * 0.25, -PI * 0.22, PI * 0.31, -PI * 0.27]
		for k in 4:
			var lip: Vector2 = lip_pos[k]
			add.call(Vector3(lip.x, lip.y, 0.12), Vector3(lip_size[k], lip_size[k], lip_size[k]), Part.TORSO, Layer.SKIN, Slot.FIXED, 0.0, Kind.FLESH)
			out.back()["rotation"] = Vector3(0.0, 0.0, lip_angle[k])
	add.call(Vector3(0, 1.585, 0.01), Vector3(0.12, 0.09, 0.12), Part.TORSO, Layer.SKIN, Slot.SKIN, 0.6 if variant == 2 else 0.25)  # neck
	# Arms: upper arm about the shoulder, forearm + hand about the elbow.
	for side: float in [1.0, -1.0]:
		var left: bool = side > 0.0
		var upper: int = Part.ARM_UPPER_L if left else Part.ARM_UPPER_R
		var lower: int = Part.ARM_LOWER_L if left else Part.ARM_LOWER_R
		var x: float = 0.29 * side
		var arm_gore: float = 0.4 if left and variant == 1 else 0.2
		if variant == 3:
			add.call(Vector3(x, 1.34, 0), Vector3(0.12, 0.32, 0.13), upper, Layer.SKIN, Slot.SKIN, arm_gore)
		else:
			# Sleeve; the T-shirt may be a tank top (bare upper arm instead).
			var sleeve_if: int = Show.UPPER_SLEEVES if variant == 0 else Show.ALWAYS
			add.call(Vector3(x, 1.34, 0), Vector3(0.12, 0.32, 0.13), upper, shirt_layer, shirt_slot, arm_gore, Kind.SURFACE, sleeve_if)
			if variant == 0:
				add.call(Vector3(x, 1.34, 0), Vector3(0.105, 0.31, 0.115), upper, Layer.SKIN, Slot.SKIN, arm_gore, Kind.SURFACE, Show.BARE_UPPER_ARMS)
		if left:
			# Missing forearm: a ragged stump with the bone sticking out.
			add.call(Vector3(x, 1.172, 0), Vector3(0.11, 0.025, 0.12), upper, Layer.SKIN, Slot.FIXED, 0.0, Kind.FLESH, Show.STUMP_L)
			add.call(Vector3(x + 0.01, 1.13, 0.01), Vector3(0.035, 0.08, 0.035), upper, Layer.SKIN, Slot.FIXED, 0.0, Kind.BONE, Show.STUMP_L)
		var arm_if: int = Show.FOREARM_L if left else Show.ALWAYS
		var bite: float = 0.6 if variant == 0 and not left else 0.25
		var fc := Vector3(x, 1.05, 0)
		var fs := Vector3(0.105, 0.28, 0.115)
		match variant:
			3:
				add.call(fc, fs, lower, Layer.SKIN, Slot.SKIN, bite, Kind.SURFACE, arm_if)
			2:
				add.call(fc, fs, lower, shirt_layer, shirt_slot, bite, Kind.SURFACE, arm_if)
			_:  # long sleeve, or a bare forearm (T-shirt, rolled-up sleeve)
				add.call(fc, fs, lower, shirt_layer, shirt_slot, bite, Kind.SURFACE, arm_if, Show.LONG_SLEEVES)
				add.call(fc, Vector3(0.095, 0.28, 0.105), lower, Layer.SKIN, Slot.SKIN, bite, Kind.SURFACE, arm_if, Show.BARE_FOREARMS)
		if left:
			add.call(Vector3(x, 0.855, 0.01), Vector3(0.095, 0.13, 0.11), lower, Layer.SKIN, Slot.SKIN, 0.3, Kind.SURFACE, arm_if)  # hand
		else:
			# Palm and fingers; the fingers may be bitten off (bloody stubs).
			add.call(Vector3(x, 0.885, 0.01), Vector3(0.095, 0.07, 0.11), lower, Layer.SKIN, Slot.SKIN, 0.3)
			add.call(Vector3(x, 0.82, 0.015), Vector3(0.088, 0.06, 0.1), lower, Layer.SKIN, Slot.SKIN, 0.3, Kind.SURFACE, Show.FINGERS_R)
			add.call(Vector3(x, 0.846, 0.012), Vector3(0.085, 0.012, 0.096), lower, Layer.SKIN, Slot.FIXED, 0.0, Kind.FLESH, Show.NO_FINGERS_R)
			for k: float in [1.0, -1.0]:
				add.call(Vector3(x + 0.025 * k, 0.832, 0.03), Vector3(0.016, 0.03, 0.016), lower, Layer.SKIN, Slot.FIXED, 0.0, Kind.BONE, Show.NO_FINGERS_R)
	# Head: skull, jaw (or the wound where it was torn off), face details.
	add.call(Vector3(0, 1.8, 0.03), Vector3(0.26, 0.24, 0.27), Part.HEAD, Layer.SKIN, Slot.SKIN, [0.3, 0.45, 0.4, 0.65][variant])
	add.call(Vector3(0, 1.65, 0.06), Vector3(0.22, 0.08, 0.2), Part.HEAD, Layer.SKIN, Slot.SKIN, 0.35, Kind.SURFACE, Show.JAW)
	add.call(Vector3(0, 1.665, 0.161), Vector3(0.12, 0.03, 0.01), Part.HEAD, Layer.SKIN, Slot.FIXED, 0.0, Kind.MOUTH, Show.JAW)
	# No lower jaw: upper teeth over a raw underside, tongue hanging.
	add.call(Vector3(0, 1.672, 0.06), Vector3(0.2, 0.025, 0.19), Part.HEAD, Layer.SKIN, Slot.FIXED, 0.0, Kind.FLESH, Show.NO_JAW)
	add.call(Vector3(0, 1.682, 0.147), Vector3(0.14, 0.03, 0.03), Part.HEAD, Layer.SKIN, Slot.FIXED, 0.0, Kind.BONE, Show.NO_JAW)  # teeth
	add.call(Vector3(0.01, 1.63, 0.1), Vector3(0.055, 0.07, 0.035), Part.HEAD, Layer.SKIN, Slot.FIXED, 0.0, Kind.FLESH, Show.NO_JAW)  # tongue
	add.call(Vector3(0.09, 1.655, 0.04), Vector3(0.03, 0.05, 0.1), Part.HEAD, Layer.SKIN, Slot.FIXED, 0.0, Kind.BONE, Show.NO_JAW)  # jaw stub
	for side: float in [1.0, -1.0]:
		add.call(Vector3(0.06 * side, 1.82, 0.165), Vector3(0.055, 0.035, 0.01), Part.HEAD, Layer.SKIN, Slot.FIXED, 0.0, Kind.EYE)
		add.call(Vector3(0.06 * side, 1.85, 0.17), Vector3(0.08, 0.025, 0.02), Part.HEAD, Layer.SKIN, Slot.SKIN, 0.0, Kind.SURFACE, Show.ALWAYS, Show.ALWAYS, Color(0.7, 0.7, 0.7))  # brow
		if side > 0.0:
			# The left ear may be bitten off (a raw patch).
			add.call(Vector3(0.143, 1.79, 0.02), Vector3(0.03, 0.06, 0.05), Part.HEAD, Layer.SKIN, Slot.SKIN, 0.0, Kind.SURFACE, Show.EAR_L)
			add.call(Vector3(0.133, 1.79, 0.02), Vector3(0.01, 0.056, 0.046), Part.HEAD, Layer.SKIN, Slot.FIXED, 0.0, Kind.FLESH, Show.NO_EAR_L)
		else:
			add.call(Vector3(-0.143, 1.79, 0.02), Vector3(0.03, 0.06, 0.05), Part.HEAD, Layer.SKIN, Slot.SKIN)
	add.call(Vector3(0, 1.755, 0.175), Vector3(0.04, 0.06, 0.03), Part.HEAD, Layer.SKIN, Slot.SKIN)  # nose
	# Patchy hair (or bald), sometimes long at the back.
	add.call(Vector3(0.02, 1.93, 0.0), Vector3(0.24, 0.04, 0.24), Part.HEAD, Layer.LEATHER, Slot.HAIR, 0.0, Kind.SURFACE, Show.HAIR)
	add.call(Vector3(0, 1.85, -0.11), Vector3(0.27, 0.12, 0.06), Part.HEAD, Layer.LEATHER, Slot.HAIR, 0.0, Kind.SURFACE, Show.HAIR)
	add.call(Vector3(0, 1.74, -0.125), Vector3(0.25, 0.2, 0.05), Part.HEAD, Layer.LEATHER, Slot.HAIR, 0.0, Kind.SURFACE, Show.HAIR, Show.LONG_HAIR)
	return out


static func _build_mesh(variant: int) -> ArrayMesh:
	return build_parts(boxes(variant))


## Shared packed geometry format; special enemies supply their own parts/materials.
static func build_parts(parts: Array[Dictionary], materials: Array[ShaderMaterial] = []) -> ArrayMesh:
	var by_layer: Dictionary = {}
	for b: Dictionary in parts:
		var l: int = b["layer"]
		if not by_layer.has(l):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
			st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
			st.set_custom_format(2, SurfaceTool.CUSTOM_RG_FLOAT)
			by_layer[l] = st
		_add_box(by_layer[l], b)
	var m := ArrayMesh.new()
	var layers: Array = by_layer.keys()
	layers.sort()
	for l: int in layers:
		var st: SurfaceTool = by_layer[l]
		st.index()  # 24 shared corners per box instead of 36: less vertex work
		st.generate_tangents()
		st.commit(m)
		m.surface_set_material(m.get_surface_count() - 1, materials[l] if not materials.is_empty() else material(l))
	return m


## Six faces, UVs in metres from the rest position (the shader scales them),
## so every box shows the texture at the same density, like real cloth.
static func _add_box(st: SurfaceTool, b: Dictionary) -> void:
	var c: Vector3 = b["c"]
	var h: Vector3 = (b["s"] as Vector3) * 0.5
	var tint: Color = b["tint"]
	var info := Color(float(b["part"]), float(b["seed"]), float(b["gore"]), float(b["kind"]))
	var extra := Color(tint.r, tint.g, tint.b, float(b["slot"]))
	var show := Color(float(b["show_a"]), float(b["show_b"]), 0.0, 0.0)
	var shift := Vector2(c.x * 1.7 + c.y * 0.3, c.z * 2.3 + c.y)  # avoids repeated patterns between boxes
	var rotation := Basis.from_euler(b.get("rotation", Vector3.ZERO))
	var taper: float = b.get("taper", 1.0)
	for axis in 3:
		for sgn: float in [1.0, -1.0]:
			var n := Vector3.ZERO
			n[axis] = sgn
			var u_axis := Vector3.ZERO
			var v_axis := Vector3.ZERO
			if axis == 1:
				u_axis = Vector3(1, 0, 0)
				v_axis = Vector3(0, 0, sgn)
			else:
				u_axis = Vector3(0, 0, -sgn) if axis == 0 else Vector3(sgn, 0, 0)
				v_axis = Vector3(0, -1, 0)
			var corners: Array[Vector3] = []
			for k in 4:
				var du: float = -1.0 if k == 0 or k == 3 else 1.0
				var dv: float = -1.0 if k < 2 else 1.0
				corners.append(c + n * h[axis] + u_axis * (absf(u_axis.dot(h)) * du) + v_axis * (absf(v_axis.dot(h)) * dv))
			if not is_equal_approx(taper, 1.0):
				for k in 4:
					var local: Vector3 = corners[k] - c
					var scale: float = lerpf(1.0, taper, (local.y / h.y + 1.0) * 0.5)
					local.x *= scale
					local.z *= scale
					corners[k] = c + local
				var slope: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0]).normalized()
				n = slope if slope.dot(n) > 0.0 else -slope
			var order: Array[int] = [0, 1, 2, 0, 2, 3]
			# Clockwise when seen from outside (Godot's front faces).
			var face_n: Vector3 = (corners[1] - corners[0]).cross(corners[2] - corners[0])
			if face_n.dot(n) > 0.0:
				order = [0, 2, 1, 0, 3, 2]
			for k: int in order:
				var p: Vector3 = corners[k]
				st.set_normal(rotation * n)
				st.set_uv(Vector2(p.dot(u_axis), p.dot(v_axis)) + shift)
				st.set_custom(0, info)
				st.set_custom(1, extra)
				st.set_custom(2, show)
				st.add_vertex(c + rotation * (p - c))
