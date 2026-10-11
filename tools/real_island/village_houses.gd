extends RefCounted
## Village houses for the real-island builder (build.gd): the houses inside
## the place's detail_area (Berlenga: the Bairro dos Pescadores, design from
## a Codex review). Instead of the builder's white box with a pyramid roof:
##
## - whitewashed plaster walls on a stone plinth (buried below the lowest
##   ground), a painted band above it and painted corner strips;
## - eaves about 3.1 m above the ground (one storey), not 5.5 m;
## - a clay tile roof with UVs along each slope: gabled on elongated plans,
##   hipped on compact ones, a lean-to on sheds and service buildings (OSM
##   roof:shape / roof:direction / roof:height win when mapped). Gable
##   triangles are wall, not roof. L- and U-shaped plans are split into
##   rectangular wings, each with its own roof, meeting in valleys;
## - a door on the wall nearest a path (not one touching another house) and
##   windows with painted surrounds and sills on the free outward walls;
##   colours chosen per house from its OSM id, so every build is the same
##   (one paint for a lighthouse keepers' compound);
## - buildings on the fort's islet: bare stone and a flat roof behind a
##   parapet, like the fort around them.
##
## Grid: the grid blocks what a Buildings/ mesh covers from above. The house
## body (vertical walls + the roof inside the footprint) is one node per house
## in Buildings/, so it blocks exactly the footprint, as before. Everything
## that sticks out (eaves, sills, frames, door steps) goes to one shared mesh
## in Decor/, which never blocks.

const PLASTER_METRES: float = 2.5  ## one plaster picture every 2.5 m (world triplanar)
const ROOF_METRES: float = 3.0  ## one tile picture (about 20 rows of canal tiles) every 3 m
const STONE_METRES: float = 1.6

## Per building kind: eaves above the mean ground (m), the least wall above
## the highest ground, roof style, pitch (rise / run), eaves and verge
## overhangs, door and window sizes (m), windows on side walls, chimney.
const STYLES: Dictionary = {
	"dwelling": {"eaves": 3.1, "min_wall": 2.45, "roof": "auto", "pitch": 0.5, "eave": 0.35, "verge": 0.15,
		"door": Vector2(0.9, 2.0), "window": Vector2(0.8, 1.0), "side_windows": true, "chimney": true},
	"retail": {"eaves": 3.5, "min_wall": 2.7, "roof": "gable", "pitch": 0.42, "eave": 0.4, "verge": 0.2,
		"door": Vector2(1.5, 2.2), "window": Vector2(1.2, 1.3), "side_windows": true, "chimney": false},
	"service": {"eaves": 2.8, "min_wall": 2.35, "roof": "skillion", "pitch": 0.2, "eave": 0.25, "verge": 0.12,
		"door": Vector2(1.2, 2.05), "window": Vector2(0.6, 0.6), "side_windows": true, "chimney": false},
	"shed": {"eaves": 2.3, "min_wall": 2.15, "roof": "skillion", "pitch": 0.25, "eave": 0.25, "verge": 0.1,
		"door": Vector2(1.0, 1.9), "window": Vector2(0.5, 0.5), "side_windows": false, "chimney": false},
	"kiosk": {"eaves": 2.5, "min_wall": 2.2, "roof": "hip", "pitch": 0.45, "eave": 0.3, "verge": 0.3,
		"door": Vector2(0.8, 1.95), "window": Vector2(1.0, 0.8), "side_windows": false, "chimney": false},
	# Buildings inside the fort (Forte de Sao Joao Baptista): bare stone, a
	# flat roof behind a parapet, small windows.
	"fort": {"eaves": 4.0, "min_wall": 3.0, "roof": "flat", "pitch": 0.0, "eave": 0.0, "verge": 0.0, "parapet": 0.9,
		"door": Vector2(1.3, 2.3), "window": Vector2(0.7, 0.9), "side_windows": true, "chimney": false},
}
const WING_PITCH: float = 0.45  ## wings of a lean-to style (service, shed): a gable needs a real pitch
const COMPOUND_RADIUS: float = 45.0  ## houses this close to a lighthouse share one paint (the keepers' compound)

## Painted surrounds, bands and corner strips: Portuguese blues and ochre.
const PAINTS: Array[Color] = [Color(0.1, 0.28, 0.58), Color(0.24, 0.47, 0.72), Color(0.86, 0.64, 0.18), Color(0.12, 0.3, 0.55)]
const DOORS: Array[Color] = [Color(0.13, 0.3, 0.2), Color(0.36, 0.22, 0.12), Color(0.42, 0.13, 0.1), Color(0.1, 0.24, 0.45)]
const WALLS: Array[Color] = [Color(1.85, 1.85, 1.8), Color(1.85, 1.8, 1.7)]  ## x the grey plaster picture
const BAND_GAIN: float = 1.6  ## band paint x the grey plaster picture
const ROOFS: Array[Color] = [Color(1.0, 1.0, 1.0), Color(0.95, 0.86, 0.8), Color(0.86, 0.86, 0.86)]
const COMPASS: Dictionary = {"N": 0.0, "NNE": 22.5, "NE": 45.0, "ENE": 67.5, "E": 90.0, "ESE": 112.5, "SE": 135.0,
	"SSE": 157.5, "S": 180.0, "SSW": 202.5, "SW": 225.0, "WSW": 247.5, "W": 270.0, "WNW": 292.5, "NW": 315.0, "NNW": 337.5}

var b: SceneTree  ## the builder (build.gd): height_at, _add, _role_material...
var _decor: Dictionary = {}  ## material -> Surf, shared by every house (Decor/VillageHouseDetail)
var _plain: Dictionary = {}  ## colour -> plain material
var _built: int = 0
var _wings_built: int = 0
var _fort_ring := PackedVector2Array()  ## coast ring of the fort's islet (empty: no fort)
var _fort_ready: bool = false


## One mesh surface being written: a SurfaceTool, its material and the
## origin its vertices are relative to (the house's node position).
class Surf:
	var st := SurfaceTool.new()
	var mat: Material
	var origin: Vector3
	var uv: bool  ## material uses the mesh UVs (and its normal map, tangents)
	var empty: bool = true

	func _init(m: Material, o: Vector3, with_uv: bool) -> void:
		mat = m
		origin = o
		uv = with_uv
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A triangle facing `n` (Godot draws clockwise faces: swapped if needed).
	func tri(p: Vector3, q: Vector3, r: Vector3, n: Vector3, up := Vector2.ZERO, uq := Vector2.ZERO, ur := Vector2.ZERO) -> void:
		var cr: Vector3 = (q - p).cross(r - p)
		if cr.length_squared() < 1e-8:
			return  # degenerate (a corner where two overhangs meet)
		if cr.dot(n) > 0.0:
			var t: Vector3 = q
			q = r
			r = t
			var tu: Vector2 = uq
			uq = ur
			ur = tu
		for i in 3:
			st.set_normal(n)
			st.set_uv([up, uq, ur][i])
			st.add_vertex([p, q, r][i] - origin)
		empty = false

	func quad(p: Vector3, q: Vector3, r: Vector3, s: Vector3, n: Vector3, up := Vector2.ZERO, uq := Vector2.ZERO, ur := Vector2.ZERO, us := Vector2.ZERO) -> void:
		tri(p, q, r, n, up, uq, ur)
		tri(p, r, s, n, up, ur, us)


## The roof's height over any plan point: walls rise to it, so gable ends
## and lean-to sides are wall up to the roof line.
class Roof:
	var shape: String = "hip"  ## gable, hip, skillion, flat, fan, wings
	var eaves: float
	var rise: float
	var ra: Vector2  ## gable: a ridge point; skillion: a point of the low eaves
	var rd: Vector2  ## direction of that line
	var span: float  ## gable: half width; skillion: width
	var parapet: float = 0.45  ## flat: parapet above the slab
	## wings (L- and U-shaped plans): one [plan, Roof, cut edges, turn] per
	## rectangular wing; a point takes the highest roof of the wings it is in.
	var parts: Array = []

	func height(p: Vector2) -> float:
		match shape:
			"gable":
				return eaves + rise - rise * absf((p - ra).cross(rd)) / span
			"skillion":
				return eaves + rise * absf((p - ra).cross(rd)) / span
			"flat":
				return eaves + parapet
			"wings":
				var best: float = -INF
				for w: Array in parts:
					var pl: PackedVector2Array = w[0]
					if Geometry2D.is_point_in_polygon(p, pl) or ring_dist(p, pl) < 0.03:
						best = maxf(best, (w[1] as Roof).height(p))
				return best if best > -INF else eaves
		return eaves

	static func ring_dist(p: Vector2, ring: PackedVector2Array) -> float:
		var best: float = INF
		for i in ring.size():
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, ring[i], ring[(i + 1) % ring.size()])))
		return best


func _init(builder: SceneTree) -> void:
	b = builder


## Builds house k (footprint `pts` in island metres, ground from `lo` to
## `hi`) and returns true, or false to leave it to the builder.
func place(k: int, pts: PackedVector2Array, lo: float, hi: float) -> bool:
	var c: Vector2 = b._centroid(pts)
	var area: Rect2 = b.P["detail_area"]
	if not area.has_point(c):
		return false
	var plan: PackedVector2Array = _simplify(pts)
	var closed: PackedVector2Array = plan.duplicate()
	closed.append(plan[0])  # b._area expects the closing point
	if plan.size() < 3 or absf(b._area(closed)) < 4.0:
		return false  # degenerate: left to the builder
	for i in plan.size():
		if plan[i].distance_to(plan[(i + 1) % plan.size()]) < 0.3:
			return false
	var tags: Dictionary = b._houses[k][5]
	var kind: String = b._houses[k][2]
	var fort: bool = _on_fort_islet(c)
	var style: Dictionary = STYLES["fort"] if fort else STYLES.get(kind, STYLES["dwelling"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(tags.get("osm_id", k))
	var turn: float = b._turn(plan)
	var o := Vector3(c.x, 0, c.y)
	var ref: float = 0.0  # mean ground under the corners
	for p in plan:
		ref += b.height_at(p.x, p.y)
	ref /= plan.size()
	var eaves: float = maxf(ref + float(style["eaves"]) + [-0.1, 0.0, 0.15][rng.randi() % 3], hi + float(style["min_wall"]))

	# Roof style and orientation: the plan is turned so that edges 1 and 3
	# (B-C, D-A) are the eaves of a gable / lean-to, or the long sides of a hip.
	var shape: String = _shape(plan, tags, style)
	if plan.size() == 4:
		plan = _orient(plan, tags, shape == "skillion")
	var shared: Array[bool] = _shared_walls(k, plan, turn)
	var front: int = _front(plan, turn, shared)
	if shape == "skillion" and plan.size() == 4 and not tags.has("roof:direction") and front == 3:
		# The lean-to drains to the front: B-C is the low side.
		plan = PackedVector2Array([plan[2], plan[3], plan[0], plan[1]])
		shared = [shared[2], shared[3], shared[0], shared[1]]
		front = 1

	var paint: Color = PAINTS[rng.randi() % PAINTS.size()]
	var door_paint: Color = DOORS[rng.randi() % DOORS.size()]
	var wall_m: Material = _role("plaster", PLASTER_METRES, WALLS[rng.randi() % WALLS.size()], false)
	var band_m: Material = _role("plaster", PLASTER_METRES, paint * BAND_GAIN, false)
	var stone_m: Material = _role("stone", STONE_METRES, Color(0.92, 0.9, 0.86), false)
	var roof_m: Material = _role("roof", ROOF_METRES, ROOFS[rng.randi() % ROOFS.size()], true)
	if kind in ["shed", "service"]:
		band_m = _role("plaster", PLASTER_METRES, Color(1.0, 1.0, 0.97), false)  # a grey band, no colours
	var compound: int = _compound(c)
	if compound >= 0:
		# The lighthouse keepers' houses were built and kept by one service:
		# one paint for the whole compound (drawn after the house's own draws,
		# so every other colour stays as it was).
		var crng := RandomNumberGenerator.new()
		crng.seed = 4513 + compound
		paint = PAINTS[crng.randi() % PAINTS.size()]
		door_paint = DOORS[crng.randi() % DOORS.size()]
		if kind not in ["shed", "service"]:
			band_m = _role("plaster", PLASTER_METRES, paint * BAND_GAIN, false)
	if fort:
		# Bare masonry like the fort's walls: no whitewash, no painted band;
		# stone surrounds and a darker plinth.
		# The fort's granite (landmarks.gd), when the place has it.
		var granite: bool = b._role_material("granite", 2.0) != null
		wall_m = _role("granite", 2.0, Color(1.25, 1.32, 1.4), false) if granite else _role("stone", 2.0, Color(1.3, 1.34, 1.36), false)
		band_m = wall_m
		stone_m = _role("granite", 2.0, Color(1.1, 1.17, 1.25), false) if granite else _role("stone", STONE_METRES, Color(0.95, 0.92, 0.88), false)
		paint = Color(0.8, 0.78, 0.72)
		door_paint = DOORS[1]

	var walls := Surf.new(wall_m, o, false)
	var band := Surf.new(band_m, o, false)
	var stone := Surf.new(stone_m, o, false)
	var roof_s := Surf.new(roof_m, o, true)
	var roof: Roof = null
	if shape == "wings":
		roof = _wing_roofs(plan, tags, style, eaves)
		if roof == null:
			shape = "flat"  # the plan would not split into wings: flat, as before
	if roof == null:
		roof = _roof(plan, tags, style, shape, eaves)
	# The fort's terrace: a plain lime-mortar grey, not the wall's stone.
	var slab: Surf = null
	if fort:
		var mortar: bool = b._role_material("concrete", 3.0) != null
		slab = Surf.new(_role("concrete", 3.0, Color(0.8, 0.81, 0.84), false) if mortar else _colour(Color(0.42, 0.41, 0.39), 0.95), o, false)
	_walls(plan, turn, roof, lo - 0.5, ref, walls, band, stone, slab)
	if roof.shape == "wings":
		_wing_faces(roof, style, rng, roof_s, walls, roof_m, wall_m)
	else:
		_roof_faces(plan, turn, roof, style, rng, roof_s, walls, roof_m, wall_m, [], true)
	if roof.shape == "flat" and fort:
		_coping(plan, turn, roof)

	var mesh := ArrayMesh.new()
	for s: Surf in [walls, band, stone, roof_s, slab]:
		if s == null:
			continue
		if s.empty:
			continue
		if s.uv:
			s.st.generate_tangents()
		s.st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, s.mat)
	var inst := MeshInstance3D.new()
	inst.name = "House_%d" % k
	inst.mesh = mesh
	inst.position = o
	b._add(inst, "Buildings")

	# Openings and painted details, outside the walls: decoration.
	if not fort:
		_corner_strips(plan, turn, roof, ref, shared, band_m)
	for i in plan.size():
		if shared[i]:
			continue
		_openings(plan, i, turn, roof, ref, style, kind, i == front, rng, paint, door_paint)
	_built += 1
	return true


## Called once after every house: the shared decoration mesh.
func finish() -> void:
	var mesh := ArrayMesh.new()
	for s: Surf in _decor.values():
		if s.empty:
			continue
		if s.uv:
			s.st.generate_tangents()
		s.st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, s.mat)
	if mesh.get_surface_count() > 0:
		var inst := MeshInstance3D.new()
		inst.name = "VillageHouseDetail"
		inst.mesh = mesh
		b._add(inst, "Decor")
	print("  village houses: %d built by the kit (%d split into wings), %d decoration surfaces" % [_built, _wings_built, mesh.get_surface_count()])


# ---------------------------------------------------------------- plan

## The footprint without its closing point and without corners that lie
## within 12 cm of the line between their neighbours (OSM often has a vertex
## in the middle of a wall). Only such corners: dropping a real recess would
## let the roof, which blocks the grid, cover ground outside the plan
## (found by Codex).
func _simplify(pts: PackedVector2Array) -> PackedVector2Array:
	var p: PackedVector2Array = pts.duplicate()
	if p.size() > 1 and p[0].distance_to(p[p.size() - 1]) < 0.01:
		p.remove_at(p.size() - 1)
	var changed: bool = true
	while changed and p.size() > 3:
		changed = false
		var n: int = p.size()
		for i in n:
			var a: Vector2 = p[(i + n - 1) % n]
			var m: Vector2 = p[i]
			var e: Vector2 = p[(i + 1) % n]
			if m.distance_to(a) < 0.05 or m.distance_to(Geometry2D.get_closest_point_to_segment(m, a, e)) < 0.12:
				p.remove_at(i)
				changed = true
				break
	return p


func _is_convex(plan: PackedVector2Array) -> bool:
	var sign: float = 0.0
	for i in plan.size():
		var a: Vector2 = plan[i]
		var e: Vector2 = plan[(i + 1) % plan.size()]
		var f: Vector2 = plan[(i + 2) % plan.size()]
		var cr: float = (e - a).cross(f - e)
		if absf(cr) < 1e-4:
			continue
		if sign != 0.0 and signf(cr) != sign:
			return false
		sign = signf(cr)
	return true


## gable, hip, skillion, flat, fan (a pyramid over a convex plan that is
## not a quad) or wings (a concave plan: L, U... split into rectangular
## wings, see _wing_roofs). OSM roof:shape wins; otherwise gabled when the
## plan is elongated (1.35 : 1 or more), hipped when compact.
func _shape(plan: PackedVector2Array, tags: Dictionary, style: Dictionary) -> String:
	var s: String = {"gabled": "gable", "pitched": "gable", "saltbox": "gable", "gambrel": "gable", "mansard": "hip",
		"hipped": "hip", "half-hipped": "hip", "pyramidal": "hip", "side_hipped": "hip",
		"skillion": "skillion", "lean_to": "skillion", "flat": "flat"}.get(tags.get("roof:shape", ""), "")
	if s == "":
		s = style["roof"]
	if plan.size() != 4 or not _is_convex(plan):
		if s == "flat":
			return s
		return "fan" if _is_convex(plan) else "wings"
	if s == "auto":
		var l0: float = plan[0].distance_to(plan[1]) + plan[2].distance_to(plan[3])
		var l1: float = plan[1].distance_to(plan[2]) + plan[3].distance_to(plan[0])
		s = "gable" if maxf(l0, l1) >= 1.35 * minf(l0, l1) else "hip"
	return s


## The quad turned so that edges 1 and 3 run along the eaves: the long
## sides, or the sides facing OSM roof:direction (where the slope looks).
func _orient(plan: PackedVector2Array, tags: Dictionary, skillion: bool) -> PackedVector2Array:
	var l0: float = plan[0].distance_to(plan[1]) + plan[2].distance_to(plan[3])
	var l1: float = plan[1].distance_to(plan[2]) + plan[3].distance_to(plan[0])
	var eaves_13: bool = l1 >= l0
	var dir: Vector2 = _roof_direction(tags)
	if dir != Vector2.ZERO:
		var d1: float = absf((plan[2] - plan[1]).normalized().dot(dir))
		var d0: float = absf((plan[1] - plan[0]).normalized().dot(dir))
		eaves_13 = d1 <= d0  # eaves run across the slope direction
	elif tags.get("roof:orientation", "") == "across":
		eaves_13 = not eaves_13
	var p: PackedVector2Array = plan if eaves_13 else PackedVector2Array([plan[3], plan[0], plan[1], plan[2]])
	if skillion and dir != Vector2.ZERO:
		# Low side (B-C) on the side the slope faces.
		var mid_bc: Vector2 = (p[1] + p[2]) * 0.5
		var mid_da: Vector2 = (p[3] + p[0]) * 0.5
		if (mid_bc - mid_da).dot(dir) < 0.0:
			p = PackedVector2Array([p[2], p[3], p[0], p[1]])
	return p


## OSM roof:direction (degrees or N, NE...) as a plan direction (x east,
## z south), or zero.
func _roof_direction(tags: Dictionary) -> Vector2:
	if not tags.has("roof:direction"):
		return Vector2.ZERO
	var v: String = String(tags["roof:direction"]).strip_edges().to_upper()
	var deg: float = COMPASS[v] if COMPASS.has(v) else v.to_float()
	return Vector2(sin(deg_to_rad(deg)), -cos(deg_to_rad(deg)))


## Walls with another house right outside (semi-detached halves, terraces):
## no door, windows or painted strips there.
func _shared_walls(k: int, plan: PackedVector2Array, turn: float) -> Array[bool]:
	var c: Vector2 = b._centroid(plan)
	var near: Array[PackedVector2Array] = []
	for j in b._houses.size():
		var other: PackedVector2Array = b._houses[j][0]
		if j != k and b._centroid(other).distance_to(c) < 40.0:
			near.append(other)
	var out: Array[bool] = []
	for i in plan.size():
		var a: Vector2 = plan[i]
		var e: Vector2 = plan[(i + 1) % plan.size()]
		var o3: Vector3 = b._outward(a, e, turn)
		var out2 := Vector2(o3.x, o3.z)
		var hit: bool = false
		for s: float in [0.15, 0.5, 0.85]:
			var q: Vector2 = a.lerp(e, s) + out2 * 0.6
			for poly in near:
				if Geometry2D.is_point_in_polygon(q, poly) or _dist_to_ring(q, poly) < 0.5:
					hit = true
		out.append(hit)
	return out


func _dist_to_ring(p: Vector2, ring: PackedVector2Array) -> float:
	var best: float = INF
	for i in ring.size():
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, ring[i], ring[(i + 1) % ring.size()])
		best = minf(best, p.distance_to(q))
	return best


## The main facade: the free wall (2 m or longer) closest to a path, longer
## walls preferred a little.
func _front(plan: PackedVector2Array, turn: float, shared: Array[bool]) -> int:
	var best: int = 0
	var best_score: float = INF
	for pass_shared in [false, true]:
		for i in plan.size():
			var a: Vector2 = plan[i]
			var e: Vector2 = plan[(i + 1) % plan.size()]
			var length: float = a.distance_to(e)
			if length < 2.0 or (shared[i] and not pass_shared):
				continue
			var o3: Vector3 = b._outward(a, e, turn)
			var q: Vector2 = (a + e) * 0.5 + Vector2(o3.x, o3.z) * 1.5
			var n: int = b.N
			var cell: int = clampi(int(q.y), 0, n - 1) * n + clampi(int(q.x), 0, n - 1)
			var score: float = float(b._path_d[cell]) - 0.15 * length
			if score < best_score:
				best_score = score
				best = i
		if best_score < INF:
			break
	return best


# ---------------------------------------------------------------- body

func _roof(plan: PackedVector2Array, tags: Dictionary, style: Dictionary, shape: String, eaves: float) -> Roof:
	var r := Roof.new()
	r.shape = shape
	r.eaves = eaves
	var pitch: float = style["pitch"]
	if shape == "gable":
		r.ra = (plan[0] + plan[1]) * 0.5
		r.rd = ((plan[2] + plan[3]) * 0.5 - r.ra).normalized()
		r.span = (plan[0].distance_to(plan[1]) + plan[2].distance_to(plan[3])) * 0.25
	elif shape == "skillion":
		r.ra = plan[1]
		r.rd = (plan[2] - plan[1]).normalized()
		r.span = (absf((plan[0] - r.ra).cross(r.rd)) + absf((plan[3] - r.ra).cross(r.rd))) * 0.5
	elif shape == "hip" and plan.size() == 4:
		r.span = (plan[0].distance_to(plan[1]) + plan[2].distance_to(plan[3])) * 0.25
	else:
		var c: Vector2 = b._centroid(plan)
		r.span = INF
		for i in plan.size():
			r.span = minf(r.span, c.distance_to(Geometry2D.get_closest_point_to_segment(c, plan[i], plan[(i + 1) % plan.size()])))
	r.span = maxf(r.span, 0.5)
	r.rise = pitch * r.span
	r.parapet = float(style.get("parapet", 0.45))
	if tags.has("roof:height"):
		r.rise = maxf(0.2, String(tags["roof:height"]).to_float())
	return r


## Walls from `base` (below the lowest ground) to the roof line, in strips
## of 1 m or less so the plinth and band follow the ground: stone up to
## 0.3 m above it (more on the downhill side, where the floor stays level),
## the painted band 0.55 m above that, whitewash to the top. Vertices sit
## exactly on the footprint: seen from above the walls cover nothing.
func _walls(plan: PackedVector2Array, turn: float, roof: Roof, base: float, ref: float, walls: Surf, band: Surf, stone: Surf,
		slab: Surf = null) -> void:
	for i in plan.size():
		var a: Vector2 = plan[i]
		var e: Vector2 = plan[(i + 1) % plan.size()]
		var out: Vector3 = b._outward(a, e, turn)
		var ts: Array[float] = []
		var steps: int = maxi(1, ceili(a.distance_to(e) / 1.0))
		for j in steps + 1:
			ts.append(float(j) / steps)
		if roof.shape == "gable" and (i == 0 or i == 2):
			ts.append(0.5)  # the gable's top
		elif roof.shape == "wings":
			ts.append_array(_wing_breaks(roof, a, e))
		ts.sort()
		var prev: Array = []
		var ga: float = b.height_at(a.x, a.y)
		var ge: float = b.height_at(e.x, e.y)
		for t in ts:
			var p: Vector2 = a.lerp(e, t)
			var lv: Array = _levels(p, roof, base, ref, lerpf(ga, ge, t))
			if not prev.is_empty() and (prev[0] as Vector2).distance_to(p) > 0.001:
				var q: Vector2 = prev[0]
				for s in 3:
					var y0: float = prev[1 + s]
					var y1: float = lv[1 + s]
					var y2: float = lv[2 + s]
					var y3: float = prev[2 + s]
					var surf: Surf = [stone, band, walls][s]
					surf.quad(Vector3(q.x, y0, q.y), Vector3(p.x, y1, p.y), Vector3(p.x, y2, p.y), Vector3(q.x, y3, q.y), out)
			prev = lv
	if roof.shape == "flat":
		# Parapet's inner face and the slab.
		for i in plan.size():
			var a: Vector2 = plan[i]
			var e: Vector2 = plan[(i + 1) % plan.size()]
			var out: Vector3 = b._outward(a, e, turn)
			var top: float = roof.eaves + roof.parapet
			walls.quad(Vector3(a.x, roof.eaves, a.y), Vector3(e.x, roof.eaves, e.y), Vector3(e.x, top, e.y), Vector3(a.x, top, a.y), -out)
		var idx: PackedInt32Array = Geometry2D.triangulate_polygon(plan)
		var s: Surf = walls if slab == null else slab
		for t in range(0, idx.size(), 3):
			s.tri(Vector3(plan[idx[t]].x, roof.eaves, plan[idx[t]].y), Vector3(plan[idx[t + 1]].x, roof.eaves, plan[idx[t + 1]].y),
				Vector3(plan[idx[t + 2]].x, roof.eaves, plan[idx[t + 2]].y), Vector3.UP)


## [point, base, stone top, band top, wall top] at a wall point. `line` is
## the ground on the straight line between the wall's corners: the plinth
## and band follow it (straight, as painted), but never sink under the
## real ground.
func _levels(p: Vector2, roof: Roof, base: float, ref: float, line: float) -> Array:
	var g: float = b.height_at(p.x, p.y)
	var top: float = roof.height(p)
	var s: float = clampf(maxf(line + 0.3, ref - 0.3), line + 0.25, line + 1.2)
	s = maxf(s, g + 0.12)
	var t: float = minf(s + 0.55, top - 0.6)
	s = minf(s, t - 0.05)
	return [p, base, s, t, top]


# ---------------------------------------------------------------- wings

## A concave plan (L, U, T...) as rectangular wings, each with its own tiled
## roof, as Portuguese houses are built: the plan is cut at its inner
## corners, always along the shortest cut that extends a wall (so a narrow
## wing joins the main range across its width), until every piece is convex.
## A wing whose end is a cut gets a gable roof running into the wing it
## joins; the other wings keep the usual gable or hip. Every roof face stays
## inside its wing, so the house still blocks exactly its footprint. Null
## when the plan does not split cleanly (it then gets the flat roof).
func _wing_roofs(plan: PackedVector2Array, tags: Dictionary, style: Dictionary, eaves: float) -> Roof:
	var pieces: Array = [plan]
	var turn: float = b._turn(plan)
	var i: int = 0
	var cuts_made: int = 0
	while i < pieces.size():
		var poly: PackedVector2Array = pieces[i]
		var cut: Array = _best_cut(poly, turn)
		if cut.is_empty():
			if not _is_convex(poly):
				return null
			i += 1
			continue
		cuts_made += 1
		if cuts_made > 8:
			return null
		pieces[i] = cut[0]
		pieces.append(cut[1])
	var wstyle: Dictionary = style.duplicate()
	if wstyle["roof"] == "skillion":
		wstyle["pitch"] = WING_PITCH
	var roof := Roof.new()
	roof.shape = "wings"
	roof.eaves = eaves
	for piece: PackedVector2Array in pieces:
		var pl: PackedVector2Array = _simplify(piece)
		if pl.size() < 3 or not _is_convex(pl):
			return null
		var cuts: Array[bool] = _cut_edges(pl, plan)
		var shape: String = "fan"
		if pl.size() == 4:
			var ci: int = cuts.find(true)
			if ci >= 0:
				# The cut end becomes gable end 0: the ridge runs into the
				# neighbouring wing.
				pl = PackedVector2Array([pl[ci], pl[(ci + 1) % 4], pl[(ci + 2) % 4], pl[(ci + 3) % 4]])
				shape = "gable"
			else:
				shape = {"gabled": "gable", "pitched": "gable", "hipped": "hip"}.get(tags.get("roof:shape", ""), "")
				if shape == "":
					var l0: float = pl[0].distance_to(pl[1]) + pl[2].distance_to(pl[3])
					var l1: float = pl[1].distance_to(pl[2]) + pl[3].distance_to(pl[0])
					shape = "gable" if maxf(l0, l1) >= 1.35 * minf(l0, l1) else "hip"
				pl = _orient(pl, {}, false)
			cuts = _cut_edges(pl, plan)
		# No OSM roof:height here: every wing keeps the same pitch, so the
		# narrower wing's roof dives under the wider one's (see _wing_join).
		roof.parts.append([pl, _roof(pl, {}, wstyle, shape, eaves), cuts, b._turn(pl)])
	_wings_built += 1
	return roof


## The shortest cut of a concave piece: from an inner (reflex) corner along
## one of its walls, to the far side. [piece a, piece b], or [] when the
## piece is convex or no cut leaves two real rooms (4 m2 or more).
func _best_cut(poly: PackedVector2Array, turn: float) -> Array:
	var n: int = poly.size()
	var best: Array = []
	var best_len: float = INF
	for j in n:
		var pv: Vector2 = poly[(j + n - 1) % n]
		var v: Vector2 = poly[j]
		var nx: Vector2 = poly[(j + 1) % n]
		if (v - pv).cross(nx - v) * turn > -1e-3:
			continue  # an outer corner (or a straight one)
		for dir: Vector2 in [(v - pv).normalized(), (v - nx).normalized()]:
			var hit := Vector2.ZERO
			var hk: int = -1
			var hd: float = INF
			for k in n:
				if k == j or k == (j + n - 1) % n:
					continue  # the corner's own walls
				var x: Variant = Geometry2D.segment_intersects_segment(v + dir * 0.01, v + dir * 10000.0, poly[k], poly[(k + 1) % n])
				if x != null and v.distance_to(x) < hd:
					hd = v.distance_to(x)
					hit = x
					hk = k
			if hk < 0 or hd >= best_len:
				continue
			var halves: Array = _split(poly, j, hk, hit)
			var ok: bool = true
			for h: PackedVector2Array in halves:
				ok = ok and h.size() >= 3 and absf(_shoelace(h)) >= 4.0
			if ok:
				best = halves
				best_len = hd
	return best


## The piece split by the cut from corner j to point h on edge k.
func _split(poly: PackedVector2Array, j: int, k: int, h: Vector2) -> Array:
	var n: int = poly.size()
	var a := PackedVector2Array([poly[j]])
	var idx: int = (j + 1) % n
	while true:
		a.append(poly[idx])
		if idx == k:
			break
		idx = (idx + 1) % n
	a.append(h)
	var c := PackedVector2Array([h])
	idx = (k + 1) % n
	while true:
		c.append(poly[idx])
		if idx == j:
			break
		idx = (idx + 1) % n
	return [_simplify(a), _simplify(c)]


func _shoelace(pl: PackedVector2Array) -> float:
	var s: float = 0.0
	for i in pl.size():
		s += pl[i].cross(pl[(i + 1) % pl.size()])
	return s * 0.5


## Which edges of a wing lie inside the house (cuts), not on the footprint.
## An edge partly on the footprint (the main range a wing joins) is not a cut.
func _cut_edges(pl: PackedVector2Array, outline: PackedVector2Array) -> Array[bool]:
	var out: Array[bool] = []
	for i in pl.size():
		var inner: int = 0
		for s in 7:
			var q: Vector2 = pl[i].lerp(pl[(i + 1) % pl.size()], (s + 0.5) / 7.0)
			if Roof.ring_dist(q, outline) > 0.03:
				inner += 1
		out.append(inner >= 6)
	return out


## Where the roof line over the wall a-e bends: the wings' corners and
## gable tops on it, as fractions of the wall.
func _wing_breaks(roof: Roof, a: Vector2, e: Vector2) -> Array[float]:
	var ts: Array[float] = []
	var l2: float = a.distance_squared_to(e)
	for w: Array in roof.parts:
		var pl: PackedVector2Array = w[0]
		var r: Roof = w[1]
		var pts: Array[Vector2] = []
		for q in pl:
			pts.append(q)
		if r.shape == "gable":
			pts.append((pl[0] + pl[1]) * 0.5)
			pts.append((pl[2] + pl[3]) * 0.5)
		for q in pts:
			if q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, e)) < 0.03:
				var t: float = (q - a).dot(e - a) / l2
				if t > 0.001 and t < 0.999:
					ts.append(t)
	return ts


## Every wing's roof (the biggest wing gets the chimney) and the joints.
func _wing_faces(roof: Roof, style: Dictionary, rng: RandomNumberGenerator, roof_s: Surf, walls: Surf,
		roof_m: Material, wall_m: Material) -> void:
	var biggest: int = 0
	for wi in roof.parts.size():
		if absf(_shoelace(roof.parts[wi][0])) > absf(_shoelace(roof.parts[biggest][0])):
			biggest = wi
	for wi in roof.parts.size():
		var w: Array = roof.parts[wi]
		_roof_faces(w[0], w[3], w[1], style, rng, roof_s, walls, roof_m, wall_m, w[2], wi == biggest)
		if (w[1] as Roof).shape != "gable":
			continue
		for c: int in [0, 2]:
			if w[2][c]:
				_wing_join(roof, wi, c, roof_s, walls, roof_m)


## The joint at cut end c of wing wi. When the neighbouring wing's roof
## rises from this line (the cut is along its eaves) and is wide enough, the
## gable roof runs on into it by its own half width: past that it is under
## the neighbour's slope, so the two meet in a valley, as real roofs do. The
## extension lies inside the neighbour, inside the footprint. Otherwise a
## gable wall closes the end above the neighbour's roof.
func _wing_join(roof: Roof, wi: int, c: int, roof_s: Surf, walls: Surf, roof_m: Material) -> void:
	var w: Array = roof.parts[wi]
	var pl: PackedVector2Array = w[0]
	var r: Roof = w[1]
	var a: Vector2 = pl[c]
	var e: Vector2 = pl[(c + 1) % 4]
	var m: Vector2 = (a + e) * 0.5
	var o3: Vector3 = b._outward(a, e, w[3])
	var d := Vector2(o3.x, o3.z)  # into the neighbour
	var length: float = r.span + 0.1
	var ok: bool = false
	for wj in roof.parts.size():
		var npl: PackedVector2Array = roof.parts[wj][0]
		if wj == wi or not Geometry2D.is_point_in_polygon(m + d * 0.3, npl):
			continue
		var nr: Roof = roof.parts[wj][1]
		ok = absf(nr.height(m + d * 0.02) - roof.eaves) < 0.1 and nr.height(m + d * length) >= roof.eaves + r.rise - 0.02
		for q: Vector2 in [a + d * length, e + d * length, m + d * length]:
			ok = ok and (Geometry2D.is_point_in_polygon(q, npl) or Roof.ring_dist(q, npl) < 0.03)
	var v3 := func(p: Vector2) -> Vector3: return Vector3(p.x, r.height(p), p.y)
	if ok:
		var a2: Vector2 = a + d * length
		var e2: Vector2 = e + d * length
		var m2: Vector2 = m + d * length
		_tile_face(roof_s, [v3.call(a), v3.call(m), v3.call(m2), v3.call(a2)])
		_tile_face(roof_s, [v3.call(m), v3.call(e), v3.call(e2), v3.call(m2)])
		_ridge_cap(_decor_surf(roof_m, true), v3.call(m), v3.call(m2))
		return
	for t: Array in [[0.0, 0.5], [0.5, 1.0]]:
		var p: Vector2 = a.lerp(e, t[0])
		var q: Vector2 = a.lerp(e, t[1])
		var y0: float = roof.eaves - 0.3
		walls.quad(Vector3(p.x, y0, p.y), Vector3(q.x, y0, q.y), v3.call(q), v3.call(p), o3)


## Tiles on a plane roof face (corners in order), UVs as in _roof_faces.
func _tile_face(s: Surf, pin: Array) -> void:
	var nrm := Vector3.ZERO
	for j in pin.size():
		var a: Vector3 = pin[j]
		var e: Vector3 = pin[(j + 1) % pin.size()]
		nrm += Vector3((a.y - e.y) * (a.z + e.z), (a.z - e.z) * (a.x + e.x), (a.x - e.x) * (a.y + e.y))
	nrm = nrm.normalized()
	if nrm.y < 0.0:
		nrm = -nrm
	if nrm.y < 0.05:
		return
	var hd: Vector3 = Vector3.UP.cross(nrm)
	hd = hd.normalized() if hd.length() > 0.01 else Vector3.RIGHT
	var dd: Vector3 = nrm.cross(hd)
	if dd.y > 0.0:
		dd = -dd
	var uv := func(p: Vector3) -> Vector2: return Vector2(p.dot(hd), p.dot(dd))
	for j in range(1, pin.size() - 1):
		s.tri(pin[0], pin[j], pin[j + 1], nrm, uv.call(pin[0]), uv.call(pin[j]), uv.call(pin[j + 1]))


# ---------------------------------------------------------------- roof

## The roof faces over the footprint go into the house (roof_s); the
## overhangs past the walls, their undersides, the edge boards, ridge tiles
## and the chimney into the shared decoration. `cuts` marks the edges of a
## wing that lie inside the house (no overhang there); `chimney` false skips
## the chimney (the other wings of the house).
func _roof_faces(plan: PackedVector2Array, turn: float, roof: Roof, style: Dictionary, rng: RandomNumberGenerator,
		roof_s: Surf, walls: Surf, roof_m: Material, wall_m: Material, cuts: Array, chimney: bool) -> void:
	if roof.shape == "flat":
		return
	var n: int = plan.size()
	# Overhang of each footprint edge: eaves (sloped side) or verge (gable end).
	var off: Array[float] = []
	for i in n:
		var verge: bool = roof.shape in ["gable", "skillion"] and (i == 0 or i == 2)
		off.append(float(style["verge"]) if verge else float(style["eave"]))
		if i < cuts.size() and cuts[i]:
			off[i] = 0.0
	var outs: Array[Vector2] = []
	for i in n:
		var o3: Vector3 = b._outward(plan[i], plan[(i + 1) % n], turn)
		outs.append(Vector2(o3.x, o3.z))
	# Roof points: plan position, height, extended position, footprint edges
	# it lies on.
	var p2 := PackedVector2Array()
	var ys := PackedFloat32Array()
	var ext := PackedVector2Array()
	var on: Array = []
	for i in n:
		var prev: int = (i + n - 1) % n
		p2.append(plan[i])
		ys.append(roof.height(plan[i]))
		ext.append(plan[i] + outs[prev] * off[prev] + outs[i] * off[i])
		on.append([prev, i])
	var faces: Array[PackedInt32Array] = []
	var ridge: Array[int] = []  # roof point pairs along the ridge (ridge tiles, chimney)
	var top: float = roof.eaves + roof.rise
	if roof.shape == "gable":
		for i: int in [0, 2]:
			var m: Vector2 = (plan[i] + plan[i + 1]) * 0.5
			p2.append(m)
			ys.append(top)
			ext.append(m + outs[i] * off[i])
			on.append([i])
		faces.append(PackedInt32Array([1, 2, 5, 4]))
		faces.append(PackedInt32Array([3, 0, 4, 5]))
		ridge = [4, 5]
	elif roof.shape == "skillion":
		faces.append(PackedInt32Array([0, 1, 2, 3]))
	elif roof.shape == "hip" and n == 4:
		var m0: Vector2 = (plan[0] + plan[1]) * 0.5
		var m1: Vector2 = (plan[2] + plan[3]) * 0.5
		var u: Vector2 = (m1 - m0).normalized()
		if m0.distance_to(m1) > 2.0 * roof.span + 0.2:
			for m: Vector2 in [m0 + u * roof.span, m1 - u * roof.span]:
				p2.append(m)
				ys.append(top)
				ext.append(m)
				on.append([])
			faces.append(PackedInt32Array([1, 2, 5, 4]))
			faces.append(PackedInt32Array([3, 0, 4, 5]))
			faces.append(PackedInt32Array([0, 1, 4]))
			faces.append(PackedInt32Array([2, 3, 5]))
			ridge = [4, 5]
		else:
			_apex(b._centroid(plan), top, p2, ys, ext, on, faces, n)
	else:  # fan: a pyramid over a convex plan
		_apex(b._centroid(plan), top, p2, ys, ext, on, faces, n)

	var tile_edge: Material = _colour(Color(0.5, 0.25, 0.16), 0.9)
	var under: Surf = _decor_surf(wall_m, false)
	var over: Surf = _decor_surf(roof_m, true)
	var board: Surf = _decor_surf(tile_edge, false)
	var caps: Dictionary = {}
	for f in faces:
		var pin: Array[Vector3] = []
		for j in f:
			pin.append(Vector3(p2[j].x, ys[j], p2[j].y))
		var nrm := Vector3.ZERO  # Newell's normal, facing up
		for j in pin.size():
			var a: Vector3 = pin[j]
			var e: Vector3 = pin[(j + 1) % pin.size()]
			nrm += Vector3((a.y - e.y) * (a.z + e.z), (a.z - e.z) * (a.x + e.x), (a.x - e.x) * (a.y + e.y))
		nrm = nrm.normalized()
		if nrm.y < 0.0:
			nrm = -nrm
		if nrm.y < 0.05:
			continue  # a vertical "slope": nothing to lay tiles on
		# UVs in metres: u along the slope's level lines, v down the slope
		# (the tile columns of the picture run downhill).
		var hd: Vector3 = Vector3.UP.cross(nrm)
		hd = hd.normalized() if hd.length() > 0.01 else Vector3.RIGHT
		var dd: Vector3 = nrm.cross(hd)
		if dd.y > 0.0:
			dd = -dd
		var uv := func(p: Vector3) -> Vector2: return Vector2(p.dot(hd), p.dot(dd))
		var pex: Array[Vector3] = []
		for j in f.size():
			var q: Vector2 = ext[f[j]]
			var y: float = pin[0].y - (nrm.x * (q.x - pin[0].x) + nrm.z * (q.y - pin[0].z)) / nrm.y
			pex.append(Vector3(q.x, y, q.y))
		for j in range(1, pin.size() - 1):
			roof_s.tri(pin[0], pin[j], pin[j + 1], nrm, uv.call(pin[0]), uv.call(pin[j]), uv.call(pin[j + 1]))
		for j in f.size():
			var j1: int = (j + 1) % f.size()
			var a: Vector3 = pex[j]
			var e: Vector3 = pex[j1]
			var ai: Vector3 = pin[j]
			var ei: Vector3 = pin[j1]
			over.quad(a, e, ei, ai, nrm, uv.call(a), uv.call(e), uv.call(ei), uv.call(ai))
			under.quad(a, e, ei, ai, -nrm)
			var edge: int = _common(on[f[j]], on[f[j1]])
			if edge >= 0 and a.distance_to(ai) > 0.01:
				# Edge board: the tiles' thickness along the eaves and verges.
				var o2: Vector2 = outs[edge]
				var dn := Vector3(0, -0.12, 0)
				board.quad(a, e, e + dn, a + dn, Vector3(o2.x, 0, o2.y))
			elif edge < 0:
				var key: String = "%d-%d" % [mini(f[j], f[j1]), maxi(f[j], f[j1])]
				caps[key] = [a, e]
	for key: String in caps:
		_ridge_cap(over, caps[key][0], caps[key][1])
	if bool(style["chimney"]) and chimney:
		var r0: Vector2 = p2[ridge[0]] if not ridge.is_empty() else p2[p2.size() - 1]
		var r1: Vector2 = p2[ridge[1]] if not ridge.is_empty() else p2[p2.size() - 1]
		var t: float = [0.2, 0.8][rng.randi() % 2]
		var along: Vector2 = (r1 - r0).normalized() if r0.distance_to(r1) > 0.1 else (plan[2] - plan[1]).normalized()
		var side := Vector2(-along.y, along.x) * (0.55 if rng.randf() < 0.5 else -0.55)
		var cp: Vector2 = r0.lerp(r1, t) + side
		if roof.shape == "hip" and r0.distance_to(r1) > 0.1:
			cp = r0.lerp(r1, 0.5) + side
		var clear: bool = true
		for lp: Vector2 in b._lighthouses:
			clear = clear and lp.distance_to(cp) > 5.0  # not through the lighthouse tower
		if clear:
			_chimney(cp, top, along, wall_m)


func _apex(c: Vector2, top: float, p2: PackedVector2Array, ys: PackedFloat32Array, ext: PackedVector2Array, on: Array,
		faces: Array[PackedInt32Array], n: int) -> void:
	p2.append(c)
	ys.append(top)
	ext.append(c)
	on.append([])
	for i in n:
		faces.append(PackedInt32Array([i, (i + 1) % n, n]))


## The footprint edge both roof points lie on, or -1 (ridge or hip line).
func _common(a: Array, e: Array) -> int:
	for x: int in a:
		if x in e:
			return x
	return -1


## Ridge tiles: a low rounded ridge along a ridge or hip line.
func _ridge_cap(s: Surf, a: Vector3, e: Vector3) -> void:
	var d: Vector3 = e - a
	var side := Vector3(d.z, 0, -d.x).normalized() * 0.13
	var up := Vector3(0, 0.1, 0)
	var dn := Vector3(0, -0.05, 0)
	for sg: float in [-1.0, 1.0]:
		var nrm: Vector3 = (Vector3.UP * 0.13 + side.normalized() * sg * 0.15).normalized()
		var l: float = d.length()
		s.quad(a + up, e + up, e + side * sg + dn, a + side * sg + dn, nrm,
			Vector2(0, 0), Vector2(l, 0), Vector2(l, 0.18), Vector2(0, 0.18))
	# Closed ends.
	for p: Vector3 in [a, e]:
		var out: Vector3 = (p - (a + e) * 0.5)
		out.y = 0.0
		s.tri(p + up, p + side + dn, p - side + dn, out.normalized())


## A whitewashed chimney from below the roof to 0.75 m over the ridge, with a
## tiled cap.
func _chimney(p: Vector2, top: float, along: Vector2, wall_m: Material) -> void:
	var s: Surf = _decor_surf(wall_m, false)
	var t3 := Vector3(along.x, 0, along.y)
	var n3 := Vector3(-along.y, 0, along.x)
	var y0: float = top - 1.2
	var y1: float = top + 0.75
	_box(s, Vector3(p.x, (y0 + y1) * 0.5, p.y), t3 * 0.27, Vector3(0, (y1 - y0) * 0.5, 0), n3 * 0.27, true)
	_box(s, Vector3(p.x, y1 + 0.04, p.y), t3 * 0.36, Vector3(0, 0.04, 0), n3 * 0.36, true)
	var cap: Surf = _decor_surf(_colour(Color(0.55, 0.27, 0.17), 0.9), false)
	_box(cap, Vector3(p.x, y1 + 0.17, p.y), t3 * 0.22, Vector3(0, 0.09, 0), n3 * 0.22, true)


# ---------------------------------------------------------------- facade

## Painted strips (cunhais) on the outer corners, the band's colour, from
## the band to the eaves.
func _corner_strips(plan: PackedVector2Array, turn: float, roof: Roof, ref: float, shared: Array[bool], band_m: Material) -> void:
	var s: Surf = _decor_surf(band_m, false)
	var n: int = plan.size()
	for i in n:
		var prev: int = (i + n - 1) % n
		var d0: Vector2 = (plan[i] - plan[prev]).normalized()
		var d1: Vector2 = (plan[(i + 1) % n] - plan[i]).normalized()
		if d0.cross(d1) * turn <= 0.0:
			continue  # inner corner
		var c: Vector2 = plan[i]
		var lv: Array = _levels(c, roof, 0.0, ref, b.height_at(c.x, c.y))
		var y0: float = lv[3]
		var y1: float = minf(roof.height(c), lv[4]) - 0.02
		for w: Array in [[prev, -d0], [i, d1]]:
			if shared[w[0]]:
				continue
			var o3: Vector3 = b._outward(plan[w[0]], plan[(w[0] + 1) % n], turn)
			var a: Vector2 = c + Vector2(o3.x, o3.z) * 0.008
			var e: Vector2 = a + (w[1] as Vector2) * 0.18
			s.quad(Vector3(a.x, y0, a.y), Vector3(e.x, y0, e.y), Vector3(e.x, y1, e.y), Vector3(a.x, y1, a.y), o3)


## Door and windows on wall i (from plan[i] to plan[i + 1]).
func _openings(plan: PackedVector2Array, i: int, turn: float, roof: Roof, ref: float, style: Dictionary, kind: String,
		front: bool, rng: RandomNumberGenerator, paint: Color, door_paint: Color) -> void:
	var a: Vector2 = plan[i]
	var e: Vector2 = plan[(i + 1) % plan.size()]
	var length: float = a.distance_to(e)
	var d: Vector2 = (e - a) / length
	var o3: Vector3 = b._outward(a, e, turn)
	var out := Vector2(o3.x, o3.z)
	var door: Vector2 = style["door"]
	var win: Vector2 = style["window"]
	var slots: Array[String] = []
	if front:
		var count: int = clampi(roundi((length - 0.8) / 2.6), 1, 4)
		if kind in ["shed", "kiosk"]:
			count = 1 if length < 3.5 else 2
		for j in count:
			slots.append("window")
		var di: int = floori((count - 1) * 0.5)
		if count % 2 == 0 and rng.randf() < 0.5:
			di += 1
		slots[di] = "door"
	elif bool(style["side_windows"]) or kind == "service":
		var count: int = clampi(roundi((length - 1.5) / 3.2), 0, 3)
		if kind == "service":
			count = mini(count, 1)
		for j in count:
			slots.append("window" if rng.randf() < 0.8 else "")
	for j in slots.size():
		if slots[j] == "":
			continue
		var s: float = length * (j + 0.5) / slots.size()
		var size: Vector2 = door if slots[j] == "door" else win
		if s - size.x * 0.5 < 0.35 or s + size.x * 0.5 > length - 0.35:
			continue  # no room beside the corners
		var p: Vector2 = a + d * s
		var top: float = minf(roof.height(a + d * (s - size.x * 0.5)), roof.height(a + d * (s + size.x * 0.5)))
		if slots[j] == "door":
			var g: float = -INF
			for t: float in [-0.5, 0.0, 0.5]:
				var q: Vector2 = p + d * size.x * t + out * 0.3
				g = maxf(g, b.height_at(q.x, q.y))
			var y0: float = g + 0.1
			var h: float = minf(size.y, top - 0.25 - y0)
			if h > 1.6:
				_door(p, d, out, y0, size.x, h, paint, door_paint)
		else:
			var g: float = b.height_at(p.x, p.y)
			var sill: float = maxf(g, ref) + (0.9 if size.y >= 0.9 else 1.3)
			sill = minf(sill, top - 0.35 - size.y)
			if sill > g + 0.55:
				_window(p, d, out, sill, size.x, size.y, paint)


## A window: dark glass, a white sash with a cross bar, a painted surround
## (10 cm) and a stone sill, all a few cm proud of the wall.
func _window(p: Vector2, d: Vector2, out: Vector2, sill: float, w: float, h: float, paint: Color) -> void:
	var t3 := Vector3(d.x, 0, d.y)
	var n3 := Vector3(out.x, 0, out.y)
	var up := Vector3.UP
	var c := Vector3(p.x, sill + h * 0.5, p.y)
	var glass: Surf = _decor_surf(_glass(), false)
	var g: Vector3 = c + n3 * 0.012
	glass.quad(g - t3 * w * 0.5 - up * h * 0.5, g + t3 * w * 0.5 - up * h * 0.5, g + t3 * w * 0.5 + up * h * 0.5, g - t3 * w * 0.5 + up * h * 0.5, n3)
	var sash: Surf = _decor_surf(_colour(Color(0.93, 0.93, 0.9), 0.6), false)
	var z: Vector3 = n3 * 0.014
	var cz: Vector3 = c + n3 * 0.014
	var bar: float = 0.035
	_box(sash, cz - t3 * (w * 0.5 - bar), t3 * bar, up * h * 0.5, z)
	_box(sash, cz + t3 * (w * 0.5 - bar), t3 * bar, up * h * 0.5, z)
	_box(sash, cz + up * (h * 0.5 - bar), t3 * w * 0.5, up * bar, z)
	_box(sash, cz - up * (h * 0.5 - bar), t3 * w * 0.5, up * bar, z)
	_box(sash, cz, t3 * 0.022, up * h * 0.5, z)
	_box(sash, cz + up * h * 0.15, t3 * w * 0.5, up * 0.022, z)
	var frame: Surf = _decor_surf(_colour(paint, 0.7), false)
	var fw: float = 0.1
	var fz: Vector3 = n3 * 0.012
	var fc: Vector3 = c + fz
	_box(frame, fc - t3 * (w + fw) * 0.5 + up * fw * 0.5, t3 * fw * 0.5, up * (h + fw) * 0.5, fz)
	_box(frame, fc + t3 * (w + fw) * 0.5 + up * fw * 0.5, t3 * fw * 0.5, up * (h + fw) * 0.5, fz)
	_box(frame, fc + up * (h + fw) * 0.5, t3 * w * 0.5, up * fw * 0.5, fz)
	var stone: Surf = _decor_surf(_colour(Color(0.84, 0.82, 0.77), 0.85), false)
	_box(stone, c - up * (h * 0.5 + 0.03) + n3 * 0.05, t3 * (w * 0.5 + fw + 0.04), up * 0.03, n3 * 0.05)


## A door: a painted wooden leaf with a rail, a painted surround (12 cm)
## and a stone step (buried, so it sits on sloping ground).
func _door(p: Vector2, d: Vector2, out: Vector2, y0: float, w: float, h: float, paint: Color, door_paint: Color) -> void:
	var t3 := Vector3(d.x, 0, d.y)
	var n3 := Vector3(out.x, 0, out.y)
	var up := Vector3.UP
	var c := Vector3(p.x, y0 + h * 0.5, p.y)
	var leaf: Surf = _decor_surf(_colour(door_paint, 0.75), false)
	var g: Vector3 = c + n3 * 0.015
	leaf.quad(g - t3 * w * 0.5 - up * h * 0.5, g + t3 * w * 0.5 - up * h * 0.5, g + t3 * w * 0.5 + up * h * 0.5, g - t3 * w * 0.5 + up * h * 0.5, n3)
	var rail: Surf = _decor_surf(_colour(door_paint.darkened(0.25), 0.75), false)
	var z: Vector3 = n3 * 0.012
	_box(rail, c + n3 * 0.015 - up * h * 0.08, t3 * w * 0.5, up * 0.04, z)
	_box(rail, c + n3 * 0.015 + up * h * 0.3, t3 * w * 0.5, up * 0.04, z)
	if w > 1.2:
		_box(rail, c + n3 * 0.015, t3 * 0.03, up * h * 0.5, z)  # two leaves
	else:
		# A small glazed opening (postigo) in the upper part.
		var glass: Surf = _decor_surf(_glass(), false)
		var gq: Vector3 = c + n3 * 0.03 + up * h * 0.18
		glass.quad(gq - t3 * 0.14 - up * 0.1, gq + t3 * 0.14 - up * 0.1, gq + t3 * 0.14 + up * 0.1, gq - t3 * 0.14 + up * 0.1, n3)
	var frame: Surf = _decor_surf(_colour(paint, 0.7), false)
	var fw: float = 0.12
	var fz: Vector3 = n3 * 0.016
	var fc: Vector3 = c + fz
	_box(frame, fc - t3 * (w + fw) * 0.5 + up * fw * 0.5, t3 * fw * 0.5, up * (h + fw) * 0.5, fz)
	_box(frame, fc + t3 * (w + fw) * 0.5 + up * fw * 0.5, t3 * fw * 0.5, up * (h + fw) * 0.5, fz)
	_box(frame, fc + up * (h + fw) * 0.5, t3 * (w * 0.5 + fw), up * fw * 0.5, fz)
	var step: Surf = _decor_surf(_role("stone", STONE_METRES, Color(0.85, 0.83, 0.8), false), false)
	_box(step, Vector3(p.x, y0 - 0.3, p.y) + n3 * 0.2, t3 * (w * 0.5 + 0.2), up * 0.3, n3 * 0.2)


# ---------------------------------------------------------------- places

## True when `c` is on the fort's islet (the place has a fort generator).
func _on_fort_islet(c: Vector2) -> bool:
	if not _fort_ready:
		_fort_ready = true
		if b.P["generators"].any(func(g: Array) -> bool: return g[0] == "fort"):
			var islet: Vector2 = b._fort_islet()
			for ring: PackedVector2Array in b._rings:
				if b._centroid(ring).distance_to(islet) < 1.0:
					_fort_ring = ring
	return _fort_ring.size() > 2 and Geometry2D.is_point_in_polygon(c, _fort_ring)


## The lighthouse whose keepers' compound `c` belongs to, or -1.
func _compound(c: Vector2) -> int:
	for i in b._lighthouses.size():
		if (b._lighthouses[i] as Vector2).distance_to(c) < COMPOUND_RADIUS:
			return i
	return -1


## A stone coping on the parapet: it gives the thin wall its thickness
## (half of it outside the footprint: decoration).
func _coping(plan: PackedVector2Array, turn: float, roof: Roof) -> void:
	var s: Surf = _decor_surf(_role("stone", STONE_METRES, Color(1.5, 1.47, 1.4), false), false)
	var y: float = roof.eaves + roof.parapet + 0.05
	for i in plan.size():
		var a: Vector2 = plan[i]
		var e: Vector2 = plan[(i + 1) % plan.size()]
		var d: Vector2 = (e - a).normalized()
		var o3: Vector3 = b._outward(a, e, turn)
		var m: Vector2 = (a + e) * 0.5
		_box(s, Vector3(m.x, y, m.y), Vector3(d.x, 0, d.y) * (a.distance_to(e) * 0.5 + 0.2), Vector3(0, 0.07, 0), o3 * 0.2, true)


# ---------------------------------------------------------------- helpers

## A box: centre and half axes (ax along the wall, ay up, az out of it).
## Without its back face unless `closed`.
func _box(s: Surf, c: Vector3, ax: Vector3, ay: Vector3, az: Vector3, closed: bool = false) -> void:
	var sides: Array = [[az, ax, ay], [ax, ay, az], [-ax, ay, az], [ay, ax, az], [-ay, ax, az]]
	if closed:
		sides.append([-az, ax, ay])
	for f: Array in sides:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var m: Vector3 = c + n
		s.quad(m - u - v, m + u - v, m + u + v, m - u + v, n.normalized())


func _decor_surf(m: Material, uv: bool) -> Surf:
	if not _decor.has(m):
		_decor[m] = Surf.new(m, Vector3.ZERO, uv)
	return _decor[m]


## A builder texture material (falls back to a plain colour without it).
## The tint may go above 1: the plaster picture is mid grey (about 0.5), and
## whitewash is near white, so walls take about 1.8x.
func _role(role: String, metres: float, tint: Color, uv: bool) -> Material:
	var key: String = "%s/%s/%.3f,%.3f,%.3f/%s" % [role, metres, tint.r, tint.g, tint.b, uv]
	if _plain.has(key):
		return _plain[key]
	var base: StandardMaterial3D = b._role_material(role, metres, Color.WHITE, uv)
	var m := StandardMaterial3D.new()
	if base != null:
		m = base.duplicate() as StandardMaterial3D
	m.albedo_color = Color(tint.r, tint.g, tint.b, 1.0)
	_plain[key] = m
	return m


func _colour(c: Color, rough: float) -> StandardMaterial3D:
	var key: String = "%s/%s" % [c.to_html(), rough]
	if not _plain.has(key):
		_plain[key] = b._mat(c, rough)
	return _plain[key]


func _glass() -> StandardMaterial3D:
	if not _plain.has("glass"):
		var m: StandardMaterial3D = b._mat(Color(0.12, 0.15, 0.18), 0.12)
		m.metallic_specular = 0.8
		_plain["glass"] = m
	return _plain["glass"]
