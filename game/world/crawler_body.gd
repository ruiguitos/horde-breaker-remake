class_name CrawlerBody
extends RefCounted
## The Crawler's body: the blocky crawler.glb (Codex, CC0), drawn as one mesh
## per horde by crawler_body.gdshader. The GLB is read at runtime with
## GLTFDocument (no editor import needed) and merged into one ArrayMesh whose
## vertices carry their part (body, head, left or right arm) and their arm
## weight; the shader poses the head and the arms about the GLB's own joints,
## with the same stroke and arm IK as ZombieModel's crawl, so the hands stay
## planted while the Crawler travels. The torso and hip stumps are static.
##
## Model frame (as the walkers): feet and hands on y = 0, facing +Z, left side
## on +X. The GLB faces -Z, so the mesh is turned 180 degrees about Y here.
##
## If the GLB does not load, `available()` is false and ZombieHordeView draws
## the walker models in the legless pose (the procedural Crawler).
## `enabled = false` forces that fallback (tests).

const GLB_PATH: String = "res://assets/models/characters/crawler_original/crawler.glb"
const SHADER: String = "res://game/world/crawler_body.gdshader"
## Triangles of the GLB file (the file's own count; the merged mesh drops its zero-area ones).
const TRIANGLES: int = 4728
const NODE_NAMES: Array[String] = ["Torso", "Head", "Arm_Left", "Hand_Left", "Arm_Right", "Hand_Right",
	"Hip_Stump_Left", "Hip_Stump_Right"]
## Part ids (CUSTOM0.x): the body and the stumps, the head, the left and right arms.
const PART_BODY: int = 0
const PART_HEAD: int = 1
const PART_LEFT: int = 2
const PART_RIGHT: int = 3
## Arm weight of a hand (rigid with its wrist, not blended).
const WEIGHT_HAND: float = 2.0
## The left elbow at rest (model frame). Estimated from the arm solid: the upper
## arm hangs from the shoulder (y 0.46) to the elbow near y 0.2, the forearm lies
## forward to the wrist. The bones' lengths and the IK come from it.
const ELBOW_LEFT: Vector3 = Vector3(0.25, 0.2, 0.61)

## The stroke's centre, metres behind the rest point (the same value as in
## crawler_body.gdshader). The GLB's arms reach only ~5 cm past the rest point,
## so a stroke centred on it would stretch the forward end out of reach.
const CENTRE_Z: float = -0.16
## Walk speed (0..1) at which the hands stride at full length (as ZombieModel).
const WALK_FULL: float = 0.15
## The topple (the same values as crawler_body.gdshader): the body rears up by
## TOPPLE_ANGLE about a pivot just in front of the fingertips, and lies on its hands.
const TOPPLE_ANGLE: float = 0.8
const TOPPLE_PIVOT_Z: float = 1.03

## Set to false to draw the procedural Crawler (tests, or to compare).
static var enabled: bool = true
static var _mesh: ArrayMesh = null
static var _tried: bool = false
## Joints and bones of the last successful build (see build()).
static var _info: Dictionary = {}


## The merged mesh, built once from the GLB; null if it does not load.
static func mesh() -> ArrayMesh:
	if not _tried:
		_tried = true
		_mesh = build(GLB_PATH, _info)
		if _mesh == null:
			push_warning("crawler.glb did not load: the Crawler is drawn with the walker models (procedural)")
	return _mesh


## Whether the GLB body is drawn (loaded and not switched off).
static func available() -> bool:
	return enabled and mesh() != null


## Measured data of the loaded GLB (triangles, top and bottom, pivots, arms).
static func info() -> Dictionary:
	mesh()
	return _info


## Builds the merged mesh from a GLB file. Fills `info` with the joints and the
## measured numbers (see the keys below). Returns null if the file or one of
## the NODE_NAMES is missing.
static func build(path: String, info: Dictionary = {}) -> ArrayMesh:
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_buffer(bytes, "", state) != OK:
		return null
	var scene: Node = doc.generate_scene(state)
	if scene == null:
		return null
	var nodes: Dictionary = {}
	for n: Node in scene.find_children("*", "MeshInstance3D", true, false):
		nodes[String(n.name)] = n
	for node_name: String in NODE_NAMES:
		if not nodes.has(node_name):
			scene.free()
			return null
	# Joints, from the node pivots (GLB frame converted to the model frame).
	var arms: Array[Dictionary] = []
	for side: int in 2:
		var shoulder: Vector3 = _model(_chain(nodes["Arm_Left" if side == 0 else "Arm_Right"], scene).origin)
		var wrist: Vector3 = _model(_chain(nodes["Hand_Left" if side == 0 else "Hand_Right"], scene).origin)
		var elbow: Vector3 = ELBOW_LEFT if side == 0 else Vector3(-ELBOW_LEFT.x, ELBOW_LEFT.y, ELBOW_LEFT.z)
		var upper: float = (Vector2(elbow.y, elbow.z) - Vector2(shoulder.y, shoulder.z)).length()
		var fore: float = (Vector2(wrist.y, wrist.z) - Vector2(elbow.y, elbow.z)).length()
		var rest: Vector2 = arm_ik(Vector2(wrist.y, wrist.z) - Vector2(shoulder.y, shoulder.z), upper, fore)
		arms.append({"shoulder3": shoulder, "elbow3": elbow, "wrist3": wrist,
			"shoulder": Vector2(shoulder.y, shoulder.z), "wrist": Vector2(wrist.y, wrist.z),
			"bones": Vector4(upper, fore, rest.x, rest.y)})
	var head: Vector3 = _model(_chain(nodes["Head"], scene).origin)
	# Geometry: every vertex in the model frame, with its part, arm weight, roughness and tint.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	st.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	var low: float = INF
	var high: float = -INF
	var triangles: int = 0
	var degenerate: int = 0
	for node_name: String in NODE_NAMES:
		var mi: MeshInstance3D = nodes[node_name]
		var chain: Transform3D = _chain(mi, scene)
		var part: int = _part_of(node_name)
		var side: int = 0 if node_name.ends_with("Left") else 1
		var source: ArrayMesh = mi.mesh as ArrayMesh
		for s in source.get_surface_count():
			var arrays: Array = source.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
			var order: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(verts.size()))
			var mat: StandardMaterial3D = source.surface_get_material(s) as StandardMaterial3D
			var rough: float = mat.roughness if mat else 0.8
			var albedo: Color = mat.albedo_color if mat else Color.WHITE
			var slot: int = ZombieModel.Slot.FIXED
			if mat and mat.resource_name == "cloth_shirt":
				slot = ZombieModel.Slot.SHIRT
			elif mat and mat.resource_name == "cloth_trousers":
				slot = ZombieModel.Slot.TROUSERS
			for t in range(0, order.size(), 3):
				var ks: Array[int] = [order[t], order[t + 1], order[t + 2]]
				var ps: Array[Vector3] = []
				for k: int in ks:
					ps.append(_model(chain * verts[k]))
				# Zero-area triangles (a few in the GLB) are dropped: they draw nothing.
				if (ps[1] - ps[0]).cross(ps[2] - ps[0]).length_squared() <= 0.000000000001:
					degenerate += 1
					continue
				triangles += 1
				for c in 3:
					var k: int = ks[c]
					var p: Vector3 = ps[c]
					var n: Vector3 = _model_dir(chain.basis * normals[k])
					var weight: float = 0.0
					if part == PART_LEFT or part == PART_RIGHT:
						weight = WEIGHT_HAND if node_name.begins_with("Hand_") else _arm_weight(p, arms[side])
					var tint: Color = Color.WHITE if slot != ZombieModel.Slot.FIXED else albedo * (colours[k] if not colours.is_empty() else Color.WHITE)
					st.set_normal(n)
					st.set_uv(Vector2(p.x, p.y))
					st.set_custom(0, Color(float(part), weight, rough, 0.0))
					st.set_custom(1, Color(tint.r, tint.g, tint.b, float(slot)))
					st.add_vertex(p)
					low = minf(low, p.y)
					high = maxf(high, p.y)
	st.index()
	st.generate_tangents()
	var out: ArrayMesh = st.commit()
	out.surface_set_material(0, _material(arms, head))
	info.clear()
	info["triangles"] = triangles
	info["degenerate"] = degenerate
	info["top"] = high
	info["bottom"] = low
	info["head_pivot"] = head
	info["arms"] = arms
	info["hands_y"] = [arms[0]["wrist3"].y, arms[1]["wrist3"].y]
	scene.free()
	return out


## Keys of `info` after build(): triangles (kept), degenerate (zero-area, dropped),
## top, bottom (model metres), head_pivot,
## hands_y (both wrists), arms (per side: shoulder3, elbow3, wrist3 in the model
## frame; shoulder and wrist (y, z); bones (upper, forearm, rest angles)).


## The hand's offset from its rest point (dz, dy) for a cycle and a walk speed:
## the crawl stroke about CENTRE_Z, scaled by the walk (standing still, the hands
## stay at rest). CPU mirror of the shader's `st`.
static func hand_stroke(cycle: float, walk: float = 1.0) -> Vector2:
	var k: float = smoothstep(0.0, WALK_FULL, walk)
	return (ZombieModel.crawl_stroke(cycle) + Vector2(CENTRE_Z, 0.0)) * k


## The arm's turn at a stroke, for one vertex (CPU mirror of crawler_body.gdshader,
## for tests): `arm` 0 left, 1 right; `weight` the vertex's arm weight; `stroke`
## the hand's offset (dz, dy) as ZombieModel.crawl_stroke gives it.
static func arm_pose(p: Vector3, arm: int, weight: float, stroke: Vector2) -> Vector3:
	var a: Dictionary = info()["arms"][arm]
	var s: Vector2 = a["shoulder"]
	var w: Vector2 = a["wrist"]
	var bones: Vector4 = a["bones"]
	var tgt := Vector2(w.x + stroke.y, w.y + stroke.x)
	if weight > 1.5:
		return p + Vector3(0, tgt.x - w.x, tgt.y - w.y)
	var ang: Vector2 = arm_ik(tgt - s, bones.x, bones.y)
	var d1: float = ang.x - bones.z
	var d2: float = ang.y - bones.w - d1
	var e1: Vector2 = spin(Vector2(-cos(bones.z), sin(bones.z)) * bones.x, d1)
	var p1: Vector2 = spin(Vector2(p.y, p.z) - s, d1)
	var p2: Vector2 = e1 + spin(p1 - e1, d2)
	var yz: Vector2 = s + p1.lerp(p2, weight)
	return Vector3(p.x, yz.x, yz.y)


## Two-bone IK in the arm's plane (CPU mirror of arm_ik in crawler_body.gdshader):
## t is the wrist relative to the shoulder (y, z); returns the upper arm's angle
## and the forearm's absolute angle, from straight down towards +Z.
static func arm_ik(t: Vector2, l1: float, l2: float) -> Vector2:
	var d: float = maxf(t.length(), 0.001)
	var psi: float = atan2(t.y, -t.x)
	var beta: float = acos(clampf((l1 * l1 + d * d - l2 * l2) / (2.0 * l1 * d), -1.0, 1.0))
	var gamma: float = acos(clampf((l1 * l1 + l2 * l2 - d * d) / (2.0 * l1 * l2), -1.0, 1.0))
	var upper: float = psi - beta
	return Vector2(upper, upper + PI - gamma)


## Turns (y, z) by d, as the shader's spin(): a bone's angle grows by d.
static func spin(v: Vector2, d: float) -> Vector2:
	var c: float = cos(d)
	var s: float = sin(d)
	return Vector2(c * v.x + s * v.y, -s * v.x + c * v.y)


static func _part_of(node_name: String) -> int:
	if node_name == "Head":
		return PART_HEAD
	if node_name.ends_with("Left"):
		return PART_LEFT if node_name.begins_with("Arm") or node_name.begins_with("Hand") else PART_BODY
	if node_name.ends_with("Right"):
		return PART_RIGHT if node_name.begins_with("Arm") or node_name.begins_with("Hand") else PART_BODY
	return PART_BODY


## 0 at the upper arm, 1 at the forearm, blended over the elbow.
static func _arm_weight(p: Vector3, arm: Dictionary) -> float:
	var du: float = _segment_distance(p, arm["shoulder3"], arm["elbow3"])
	var df: float = _segment_distance(p, arm["elbow3"], arm["wrist3"])
	return smoothstep(0.35, 0.65, du / maxf(du + df, 0.000001))


static func _segment_distance(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return (p - (a + ab * t)).length()


## Transform of a node from the scene root (the GLB's own hierarchy).
static func _chain(node: Node, root: Node) -> Transform3D:
	var t := Transform3D()
	var cur: Node = node
	while cur is Node3D:
		t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t


## GLB frame (facing -Z) to model frame (facing +Z): a turn of 180 degrees about Y.
static func _model(g: Vector3) -> Vector3:
	return Vector3(-g.x, g.y, -g.z)


static func _model_dir(g: Vector3) -> Vector3:
	return Vector3(-g.x, g.y, -g.z).normalized()


static func _material(arms: Array[Dictionary], head: Vector3) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(SHADER) as Shader
	for side: int in 2:
		var suffix: String = "l" if side == 0 else "r"
		var a: Dictionary = arms[side]
		var s: Vector2 = a["shoulder"]
		var w: Vector2 = a["wrist"]
		m.set_shader_parameter(StringName("joints_" + suffix), Vector4(s.x, s.y, w.x, w.y))
		m.set_shader_parameter(StringName("bones_" + suffix), a["bones"])
	m.set_shader_parameter(&"neck", head)
	m.set_shader_parameter(&"status_tints", _vec4s(ZombieModel.STATUS_TINTS))
	m.set_shader_parameter(&"shirt_colors", _vec4s(ZombieModel.SHIRT_COLORS))
	m.set_shader_parameter(&"trouser_colors", _vec4s(ZombieModel.TROUSER_COLORS))
	return m


static func _vec4s(colors: Array[Color]) -> PackedVector4Array:
	var out := PackedVector4Array()
	for c: Color in colors:
		out.append(Vector4(c.r, c.g, c.b, c.a))
	return out
