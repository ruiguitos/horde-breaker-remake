extends RefCounted
## Landmarks for the real-island builder (build.gd) inside the place's
## detail_area (Berlenga Grande): the lighthouse and the Forte de São João
## Baptista.
##
## - Lighthouse (design from a Codex review): a square, slightly tapering
##   whitewashed masonry tower with stone quoins (cunhais) on its corners,
##   narrow vertical windows, a cornice with a gallery and railing near the
##   top, and a glazed lantern with mullions under a red dome. The plan
##   sizes are metres (a taller tower is not a fatter one); only the heights
##   follow the OSM height (29 m at Berlenga, never the 121 m light height,
##   which is above the sea). The keepers' houses around it come from
##   village_houses.gd.
## - Fort: an APPROXIMATION. OSM has no outline of the fort, only the islet's
##   coastline. Descriptions call its plan an irregular polygon (a heptagon)
##   fitted to the rock, with sloped stone walls, embrasures to the sea and
##   rooms around an inner courtyard, reached by an arched bridge. So: walls
##   that follow the islet's coast a few metres inside it, simplified to a
##   few straight faces, with a front wall square to the last bridge of the
##   Caminho do Forte and the gate where that bridge lands. Sloped stone
##   faces (talus) up to a cordon, a parapet with embrasures, sentry boxes
##   (guaritas) on the corners and a paved open courtyard.
##
## Grid: the grid blocks every cell a Buildings/ mesh covers seen from above,
## so only bodies that stand on the ground go there (tower and lantern, the
## fort's walls). What overhangs or spans an opening (gallery, railing,
## quoins, cordon, sentry boxes, the lintel over the gate, paving) goes to
## Decor/, which never blocks: a lintel in Buildings/ would close the gate.

const PLASTER_METRES: float = 2.5
const STONE_METRES: float = 1.8
const WHITEWASH := Color(1.85, 1.85, 1.8)  ## x the mid-grey plaster picture (see village_houses.gd)
const STONE_TINT := Color(1.75, 1.72, 1.66)  ## x the dark brown ashlar picture: warm grey granite
const QUOIN_TINT := Color(2.2, 2.17, 2.1)  ## lighter dressed stone: quoins, cordon, surrounds
const DOME_RED := Color(0.6, 0.11, 0.08)
const IRON := Color(0.13, 0.14, 0.15)
const SLOT := Color(0.06, 0.065, 0.07)  ## window and door openings

# Lighthouse. Plan sizes in metres, heights as fractions of the OSM height.
const TOWER_HALF_BASE: float = 2.3
const TOWER_HALF_TOP: float = 1.95
const LANTERN_R: float = 1.35  ## glazing, octagon circumradius
const SHAFT_FRACTION: float = 0.77  ## masonry shaft; the rest is lantern

# Fort.
const COAST_INSET: float = 2.5  ## wall foot this far inside the islet's coastline
const FRONT_GAP: float = 1.0  ## front wall foot this far beyond the bridge deck's end
const SIMPLIFY: float = 2.5  ## metres a straight wall face may stray from the coast line
const MIN_EDGE: float = 5.0  ## shortest wall face
const WALL_H: float = 5.0  ## wall walk above the courtyard
const BATTER: float = 0.8  ## the talus leans in this much from its foot to the walk
const THICK: float = 3.0  ## parapet + wall walk, from the outer face in
const PARAPET_H: float = 1.1
const PARAPET_T: float = 0.7
const SILL_H: float = 0.45  ## parapet height in an embrasure
const GATE_W: float = 3.6
const GATE_H: float = 3.4
## Add the tower's and the fort's plans to the builder's _reserved (no grass
## or rocks there). build.gd's _place_nature draws the same random numbers
## on every try, so this removes only what would land on them.
const RESERVE_SCATTER: bool = true

var b: SceneTree  ## the builder (build.gd): height_at, _add, _role_material...
## The fort's open courtyard: the point furthest from its walls and buildings
## (a generator fits there: see the report on build.gd's _place_markers).
var courtyard := Vector2(-1, -1)
var _mats: Dictionary = {}


## One mesh surface being written, in island coordinates.
class Surf:
	var st := SurfaceTool.new()
	var empty: bool = true

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	## A triangle facing `n` (Godot draws clockwise faces: swapped if needed).
	func tri(p: Vector3, q: Vector3, r: Vector3, n: Vector3) -> void:
		tri3(p, q, r, n, n, n)

	## Same, with a normal per vertex (smooth curved surfaces).
	func tri3(p: Vector3, q: Vector3, r: Vector3, np: Vector3, nq: Vector3, nr: Vector3) -> void:
		var cr: Vector3 = (q - p).cross(r - p)
		if cr.length_squared() < 1e-10:
			return
		if cr.dot(np + nq + nr) > 0.0:
			var t: Vector3 = q
			q = r
			r = t
			var tn: Vector3 = nq
			nq = nr
			nr = tn
		st.set_normal(np)
		st.add_vertex(p)
		st.set_normal(nq)
		st.add_vertex(q)
		st.set_normal(nr)
		st.add_vertex(r)
		empty = false

	func quad(p: Vector3, q: Vector3, r: Vector3, s: Vector3, n: Vector3) -> void:
		tri(p, q, r, n)
		tri(p, r, s, n)


func _init(builder: SceneTree) -> void:
	b = builder


# ---------------------------------------------------------------- lighthouse

## Builds lighthouse k at `p` (island metres), `height` metres tall, and
## returns true. Tower body and lantern in Buildings/Lighthouse_<k>; quoins,
## windows, gallery and railing in Decor/Lighthouse_<k>_Detail.
func lighthouse(p: Vector2, k: int, height: float) -> bool:
	# Square to the building it stands in (Berlenga: the keepers' U-shaped
	# house), and kept inside its footprint: the house already blocks there.
	var axis := Vector2.RIGHT
	var house: PackedVector2Array = _house_at(p)
	if not house.is_empty():
		axis = _longest_edge(house)
		p = _keep_inside(p, house, TOWER_HALF_BASE + 0.05)
	var side := Vector2(-axis.y, axis.x)
	var g: float = _h(p)
	var lo: float = g
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			lo = minf(lo, _h(p + (axis * sx + side * sz) * TOWER_HALF_BASE))
	var base: float = lo - 0.5
	var shaft_top: float = g + height * SHAFT_FRACTION
	var lh: float = height * (1.0 - SHAFT_FRACTION)  # lantern part: watch room, glazing, dome
	var body: Dictionary = {}
	var detail: Dictionary = {}
	var plaster: Material = _role("plaster", PLASTER_METRES, WHITEWASH, Color(0.95, 0.95, 0.92))
	var stone: Material = _role("stone", STONE_METRES, QUOIN_TINT, Color(0.7, 0.68, 0.63))
	var red: Material = _plain(DOME_RED, 0.45)
	var iron: Material = _plain(IRON, 0.5)

	# Shaft: four faces leaning in, its top closed (the grid reads that cap).
	var bottom: PackedVector3Array = _square(p, axis, TOWER_HALF_BASE, base)
	var top: PackedVector3Array = _square(p, axis, TOWER_HALF_TOP, shaft_top)
	_loft(_surf(body, plaster), bottom, top, Vector3(p.x, 0, p.y))
	_cap(_surf(body, plaster), top, true)
	var half_at := func(y: float) -> float:
		return lerpf(TOWER_HALF_BASE, TOWER_HALF_TOP, (y - base) / (shaft_top - base))

	# Quoins: dressed stone blocks on each corner, long and short in turn.
	var qs: Surf = _surf(detail, stone)
	var course: float = 0.55
	var n_courses: int = int((shaft_top - 0.6 - g) / course)
	for c in n_courses:
		var y0: float = g + c * course
		var hh: float = half_at.call(y0 + course * 0.5)
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var la: float = 0.8 if (c % 2 == 0) == (sx * sz > 0.0) else 0.45
				var lb: float = 1.25 - la
				var lo_a: float = hh - la
				var lo_b: float = hh - lb
				var hi: float = hh + 0.05
				var ca: float = (lo_a + hi) * 0.5 * sx
				var cb: float = (lo_b + hi) * 0.5 * sz
				var centre2: Vector2 = p + axis * ca + side * cb
				_box(qs, Vector3(centre2.x, y0 + course * 0.5 - 0.02, centre2.y),
					_v3(axis) * (hi - lo_a) * 0.5, Vector3.UP * (course * 0.5 - 0.03), _v3(side) * (hi - lo_b) * 0.5)

	# Narrow vertical windows lighting the stair, staggered round the faces,
	# each in a stone surround.
	var slot: Material = _plain(SLOT, 0.4)
	var level: int = 0
	var y: float = g + 5.0
	while y + 1.3 < shaft_top - 2.0:
		for f in 4:
			if (level + f) % 2 == 1:
				continue
			var out: Vector2 = [axis, side, -axis, -side][f]
			var along: Vector2 = Vector2(-out.y, out.x)
			var hh: float = half_at.call(y + 0.65)
			var c2: Vector2 = p + out * hh
			_box(_surf(detail, stone), Vector3(c2.x, y + 0.65, c2.y), _v3(along) * 0.36, Vector3.UP * 0.78, _v3(out) * 0.06)
			var w: Vector2 = c2 + out * 0.075
			var a2: Vector2 = w - along * 0.22
			var e2: Vector2 = w + along * 0.22
			_surf(detail, slot).quad(Vector3(a2.x, y, a2.y), Vector3(e2.x, y, e2.y), Vector3(e2.x, y + 1.3, e2.y),
				Vector3(a2.x, y + 1.3, a2.y), _v3(out))
		level += 1
		y += 4.2

	# Cornice and gallery: a coved overhang, a stone slab, the railing.
	var cove_lo: PackedVector3Array = _square(p, axis, TOWER_HALF_TOP, shaft_top - 0.7)
	var cove_hi: PackedVector3Array = _square(p, axis, TOWER_HALF_TOP + 0.5, shaft_top - 0.2)
	_loft(_surf(detail, plaster), cove_lo, cove_hi, Vector3(p.x, 0, p.y))
	_cap(_surf(detail, plaster), cove_hi, false)
	var slab_lo: PackedVector3Array = _square(p, axis, TOWER_HALF_TOP + 0.6, shaft_top - 0.2)
	var slab_hi: PackedVector3Array = _square(p, axis, TOWER_HALF_TOP + 0.6, shaft_top + 0.1)
	_loft(_surf(detail, stone), slab_lo, slab_hi, Vector3(p.x, 0, p.y))
	_cap(_surf(detail, stone), slab_hi, true)
	_cap(_surf(detail, stone), slab_lo, false)
	_railing(_surf(detail, iron), _square(p, axis, TOWER_HALF_TOP + 0.5, shaft_top + 0.1), 1.0)

	# Watch room: a square whitewashed block on the gallery floor.
	var wr_top: float = shaft_top + lh * 0.22
	var wr_lo: PackedVector3Array = _square(p, axis, 1.55, shaft_top + 0.1)
	var wr_hi: PackedVector3Array = _square(p, axis, 1.55, wr_top)
	_loft(_surf(body, plaster), wr_lo, wr_hi, Vector3(p.x, 0, p.y))
	_cap(_surf(body, stone), _square(p, axis, 1.65, wr_top), true)
	var door: Vector2 = p + side * 1.56
	var da: Vector2 = door - axis * 0.4
	var de: Vector2 = door + axis * 0.4
	_surf(detail, slot).quad(Vector3(da.x, shaft_top + 0.1, da.y), Vector3(de.x, shaft_top + 0.1, de.y),
		Vector3(de.x, shaft_top + 0.1 + minf(1.9, lh * 0.2), de.y), Vector3(da.x, shaft_top + 0.1 + minf(1.9, lh * 0.2), da.y), _v3(side))

	# Lantern: octagonal glazing between bands, with mullions and a middle bar.
	var glaze_lo: float = wr_top
	var glaze_hi: float = wr_top + lh * 0.4
	var c3 := Vector3(p.x, 0, p.y)
	var yaw: float = atan2(axis.y, axis.x) + PI / 8.0
	_loft(_surf(body, _glass()), _ngon(c3, LANTERN_R, 8, glaze_lo, yaw), _ngon(c3, LANTERN_R, 8, glaze_hi, yaw), c3)
	for band: Vector2 in [Vector2(glaze_lo, 0.18), Vector2((glaze_lo + glaze_hi) * 0.5, 0.06), Vector2(glaze_hi - 0.12, 0.12)]:
		var r: float = LANTERN_R + 0.03
		_loft(_surf(body, red), _ngon(c3, r, 8, band.x, yaw), _ngon(c3, r, 8, band.x + band.y, yaw), c3)
	for i in 8:
		var a: float = yaw + TAU * i / 8.0
		var out := Vector3(cos(a), 0, sin(a))
		var tang := Vector3(-sin(a), 0, cos(a))
		var m: Vector3 = c3 + out * (LANTERN_R + 0.01)
		_box(_surf(body, red), Vector3(m.x, (glaze_lo + glaze_hi) * 0.5, m.z), tang * 0.05, Vector3.UP * (glaze_hi - glaze_lo) * 0.5, out * 0.05)
	# A warm lamp inside, seen through the glass.
	_box(_surf(body, _lamp()), Vector3(p.x, glaze_lo + (glaze_hi - glaze_lo) * 0.45, p.y), Vector3(0.35, 0, 0), Vector3(0, 0.5, 0), Vector3(0, 0, 0.35))

	# Red rounded cap: a ring, a dome, a ventilator ball and a lightning rod.
	var ring_y: float = glaze_hi
	_loft(_surf(body, red), _ngon(c3, LANTERN_R + 0.18, 16, ring_y, 0.0), _ngon(c3, LANTERN_R + 0.18, 16, ring_y + 0.15, 0.0), c3)
	_cap(_surf(body, red), _ngon(c3, LANTERN_R + 0.18, 16, ring_y, 0.0), false)
	var dome_h: float = lh * 0.25
	_dome(_surf(body, red), Vector3(p.x, ring_y + 0.15, p.y), LANTERN_R + 0.1, dome_h)
	var top_y: float = ring_y + 0.15 + dome_h
	_dome(_surf(body, red), Vector3(p.x, top_y + 0.05, p.y), 0.22, 0.22)
	_dome(_surf(body, red), Vector3(p.x, top_y + 0.05, p.y), 0.22, -0.22)
	_box(_surf(detail, iron), Vector3(p.x, top_y + 0.6, p.y), Vector3(0.025, 0, 0), Vector3(0, 0.45, 0), Vector3(0, 0, 0.025))

	_commit(body, "Lighthouse_%d" % k, "Buildings")
	_commit(detail, "Lighthouse_%d_Detail" % k, "Decor")
	var foot := PackedVector2Array()
	for v: Vector3 in bottom:
		foot.append(Vector2(v.x, v.z))
	if RESERVE_SCATTER:
		b._reserved.append(foot)
	print("  landmarks: lighthouse %d at (%d, %d), %.0f m, %.1f m wide at the foot" % [k, int(p.x), int(p.y), height, TOWER_HALF_BASE * 2.0])
	return true


## Posts every ~0.5 m and two rails round a closed ring, `h` metres high.
func _railing(s: Surf, ring: PackedVector3Array, h: float) -> void:
	for i in ring.size():
		var a: Vector3 = ring[i]
		var e: Vector3 = ring[(i + 1) % ring.size()]
		var d: Vector3 = (e - a).normalized()
		var out: Vector3 = d.cross(Vector3.UP).normalized()
		var n: int = maxi(1, int(a.distance_to(e) / 0.5))
		for j in n:
			var q: Vector3 = a.lerp(e, float(j) / n)
			_box(s, q + Vector3.UP * h * 0.5, d * 0.025, Vector3.UP * h * 0.5, out * 0.025)
		for rail: float in [h * 0.5, h]:
			_box(s, (a + e) * 0.5 + Vector3.UP * rail, d * (a.distance_to(e) * 0.5 + 0.03), Vector3.UP * 0.03, out * 0.035)


## The building footprint (OSM, closed) that holds `p`, or empty.
func _house_at(p: Vector2) -> PackedVector2Array:
	for h: Array in b._houses:
		var pts: PackedVector2Array = h[0]
		if Geometry2D.is_point_in_polygon(p, pts):
			return pts
	return PackedVector2Array()


func _longest_edge(pts: PackedVector2Array) -> Vector2:
	var best := Vector2.RIGHT
	var longest: float = 0.0
	for i in pts.size() - 1:
		if pts[i].distance_to(pts[i + 1]) > longest:
			longest = pts[i].distance_to(pts[i + 1])
			best = (pts[i + 1] - pts[i]).normalized()
	return best


## `p`, or the nearest point at least `margin` inside the footprint.
func _keep_inside(p: Vector2, pts: PackedVector2Array, margin: float) -> Vector2:
	var inner: Array[PackedVector2Array] = Geometry2D.offset_polygon(_open(pts), -margin, Geometry2D.JOIN_MITER)
	var best: Vector2 = p
	var bd: float = INF
	for poly in inner:
		if Geometry2D.is_point_in_polygon(p, poly):
			return p
		for i in poly.size():
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
			if q.distance_to(p) < bd:
				bd = q.distance_to(p)
				best = q
	return best if bd < 2.0 else p


# ---------------------------------------------------------------- fort

## Builds the fort on the islet centred near `islet` (island metres). An
## approximation anchored to the real data: the islet's coastline and the
## last bridge of the Caminho do Forte. Walls in Buildings/Fort_Walls, the
## rest in Decor/.
func fort(islet: Vector2) -> void:
	var ring: PackedVector2Array = _islet_ring(islet)
	var arrival: Array = _arrival(ring) if ring.size() > 3 else []
	if arrival.is_empty():
		print("  WARNING: landmarks: no islet or bridge for the fort")
		return
	var d: Vector2 = arrival[1]  # the bridge's direction, onto the islet
	var deck_end: Vector2 = arrival[0] + d * 2.0  # _place_bridges lands the deck 2 m onto the bank
	var front: Vector2 = deck_end + d * FRONT_GAP
	var plan: PackedVector2Array = _enclosure(ring, front, d)
	if plan.size() < 3:
		print("  WARNING: landmarks: no room for the fort on the islet")
		return
	var n_v: int = plan.size()
	var ccw: bool = _signed_area(plan) > 0.0
	# Outward normal of each wall face, and the mitred inward step at each corner.
	var normals: Array[Vector2] = []
	for i in n_v:
		var e: Vector2 = (plan[(i + 1) % n_v] - plan[i]).normalized()
		normals.append(Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x))
	var miters: Array[Vector2] = []
	for i in n_v:
		var n0: Vector2 = normals[(i + n_v - 1) % n_v]
		var n1: Vector2 = normals[i]
		var m: Vector2 = (n0 + n1) / maxf(1.0 + n0.dot(n1), 0.15)
		miters.append(m.limit_length(2.5))
	# Four lines round the fort: the foot of the talus (F), its top under the
	# parapet (T), the parapet's inner face (P) and the inner face (I).
	var lines: Array[PackedVector2Array] = []
	for t: float in [0.0, BATTER, BATTER + PARAPET_T, BATTER + THICK]:
		var line := PackedVector2Array()
		for i in n_v:
			line.append(plan[i] - miters[i] * t)
		lines.append(line)
	var inner: PackedVector2Array = lines[3]
	var ref: float = _median_ground(inner)
	var walk: float = ref + WALL_H
	var gate_floor: float = _h(front + d * 2.0)

	var walls: Dictionary = {}
	var detail: Dictionary = {}
	var stone: Material = _role("stone", STONE_METRES, STONE_TINT, Color(0.6, 0.58, 0.54))
	var dressed: Material = _role("stone", STONE_METRES, QUOIN_TINT, Color(0.7, 0.68, 0.63))
	var plaster: Material = _role("plaster", PLASTER_METRES, WHITEWASH, Color(0.95, 0.95, 0.92))
	var slot: Material = _plain(SLOT, 0.5)
	var front_edge: int = -1
	for i in n_v:
		if absf((plan[i] - front).dot(d)) < 0.1 and absf((plan[(i + 1) % n_v] - front).dot(d)) < 0.1:
			front_edge = i
	if front_edge < 0:
		# The simplified plan lost a corner of the front face: a fort without
		# its gate would shut the generator in. No fort rather than a closed
		# one (found by Codex).
		print("  landmarks: the fort's front face was lost, no fort built")
		return
	var embrasures: int = 0
	for i in n_v:
		var j: int = (i + 1) % n_v
		var n3: Vector3 = _v3(normals[i])
		var length: float = plan[i].distance_to(plan[j])
		# Stations along the face (fractions per line); the gate cuts the
		# front face square across the wall.
		var stations: Array = []
		var gate_at: int = -1  # the station where the gate begins
		if i == front_edge:
			var e: Vector2 = (plan[j] - plan[i]).normalized()
			var sg: float = (front - plan[i]).dot(e)
			var metres: Array[float] = _steps(0.0, sg - GATE_W * 0.5)
			gate_at = metres.size() - 1
			metres.append_array(_steps(sg + GATE_W * 0.5, length))
			for s_m: float in metres:
				var fs: Array = []
				for line: PackedVector2Array in lines:
					var s0: float = (line[i] - plan[i]).dot(e)
					var s1: float = (line[j] - plan[i]).dot(e)
					fs.append(0.0 if absf(s1 - s0) < 1e-4 else clampf((s_m - s0) / (s1 - s0), 0.0, 1.0))
				stations.append(fs)
		else:
			for f: float in _steps(0.0, 1.0, 4.0 / length):
				stations.append([f, f, f, f])
		var ws: Surf = _surf(walls, stone)
		for s in stations.size() - 1:
			var f0: Array = stations[s]
			var f1: Array = stations[s + 1]
			if s == gate_at:
				continue  # the gate
			var a: Array[Vector2] = []
			var c: Array[Vector2] = []
			for L in 4:
				a.append(lines[L][i].lerp(lines[L][j], f0[L]))
				c.append(lines[L][i].lerp(lines[L][j], f1[L]))
			var fa: float = _foot_y(a[0], normals[i])
			var fc: float = _foot_y(c[0], normals[i])
			var ia: float = _h(a[3]) - 0.6
			var ic: float = _h(c[3]) - 0.6
			# Talus (leaning out), wall walk, inner face.
			var tal_n: Vector3 = (n3 * (walk - (fa + fc) * 0.5) + Vector3.UP * BATTER).normalized()
			ws.quad(_p3(a[0], fa), _p3(c[0], fc), _p3(c[1], walk), _p3(a[1], walk), tal_n)
			ws.quad(_p3(a[2], walk), _p3(c[2], walk), _p3(c[3], walk), _p3(a[3], walk), Vector3.UP)
			ws.quad(_p3(a[3], walk), _p3(c[3], walk), _p3(c[3], ic), _p3(a[3], ia), -n3)
			# Gate jambs: the wall's cut ends.
			if gate_at >= 0 and (s == gate_at - 1 or s == gate_at + 1):
				var before: bool = s == gate_at - 1
				var cut: Array[Vector2] = c if before else a
				var cf: float = fc if before else fa
				var ci: float = ic if before else ia
				var along: Vector3 = _v3((plan[j] - plan[i]).normalized()) * (1.0 if before else -1.0)
				ws.quad(_p3(cut[0], cf), _p3(cut[1], walk), _p3(cut[3], walk), _p3(cut[3], ci), along)
		# Parapet: solid on the front, with embrasures towards the sea.
		var ps: Surf = _surf(walls, stone)
		if gate_at >= 0:
			_parapet(ps, lines, i, j, stations[0], stations[gate_at], walk, walk + PARAPET_H, n3)
			_parapet(ps, lines, i, j, stations[gate_at + 1], stations[stations.size() - 1], walk, walk + PARAPET_H, n3)
		else:
			var n_emb: int = int(length / 7.0) if length > 9.0 else 0
			var w: float = 0.9 / length
			var f_prev: float = 0.0
			for k in n_emb:
				var fe: float = (k + 0.5) / n_emb
				_parapet(ps, lines, i, j, _f4(f_prev), _f4(fe - w * 0.5), walk, walk + PARAPET_H, n3)
				_parapet(ps, lines, i, j, _f4(fe - w * 0.5), _f4(fe + w * 0.5), walk, walk + SILL_H, n3)
				f_prev = fe + w * 0.5
				embrasures += 1
			_parapet(ps, lines, i, j, _f4(f_prev), _f4(1.0), walk, walk + PARAPET_H, n3)
		# Cordon: a rounded stone band where the talus meets the parapet.
		var cs: Surf = _surf(detail, dressed)
		var t0: Vector2 = lines[1][i] + miters[i] * 0.18
		var t1: Vector2 = lines[1][j] + miters[j] * 0.18
		cs.quad(_p3(lines[1][i], walk - 0.25), _p3(lines[1][j], walk - 0.25), _p3(t1, walk - 0.08), _p3(t0, walk - 0.08), (n3 - Vector3.UP).normalized())
		cs.quad(_p3(t0, walk - 0.08), _p3(t1, walk - 0.08), _p3(t1, walk + 0.08), _p3(t0, walk + 0.08), n3)
		cs.quad(_p3(t0, walk + 0.08), _p3(t1, walk + 0.08), _p3(lines[1][j], walk + 0.2), _p3(lines[1][i], walk + 0.2), (n3 + Vector3.UP).normalized())
		# Casemate doors on the inner face (rooms under the walls).
		if i != front_edge and length > 10.0:
			var n_doors: int = int(length / 9.0)
			for k in n_doors:
				var f: float = (k + 0.5) / n_doors
				var q: Vector2 = lines[3][i].lerp(lines[3][j], f) - normals[i] * 0.04
				var along2: Vector2 = (plan[j] - plan[i]).normalized()
				var y0: float = _h(q)
				_box(_surf(detail, dressed), _p3(q, y0 + 1.25), _v3(along2) * 0.85, Vector3.UP * 1.3, _v3(normals[i]) * 0.04)
				var qa: Vector2 = q - along2 * 0.6 - normals[i] * 0.05
				var qe: Vector2 = q + along2 * 0.6 - normals[i] * 0.05
				_surf(detail, slot).quad(_p3(qa, y0 - 0.1), _p3(qe, y0 - 0.1), _p3(qe, y0 + 2.3), _p3(qa, y0 + 2.3), -n3)

	# Sentry boxes on the corners either side of the gate and the two most
	# salient others.
	var corners: Array[int] = []
	if front_edge >= 0:
		corners.append_array([front_edge, (front_edge + 1) % n_v])
	var salient: Array = []
	for i in n_v:
		var n0: Vector2 = normals[(i + n_v - 1) % n_v]
		if i in corners or n0.dot(normals[i]) > 0.9:
			continue
		var convex: bool = (n0.cross(normals[i]) > 0.0) == ccw
		if convex:
			salient.append([n0.dot(normals[i]), i])
	salient.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for k in mini(2, salient.size()):
		corners.append(salient[k][1])
	for i in corners:
		var out: Vector2 = miters[i].normalized()
		_guarita(detail, lines[1][i] + out * 0.35, walk, out)

	# The gate: a stone lintel over the passage and a whitewashed frontispiece
	# rising over the parapet (Decor: a lintel in Buildings/ would close it).
	if front_edge >= 0:
		var along: Vector2 = (plan[(front_edge + 1) % n_v] - plan[front_edge]).normalized()
		var depth_lo: Vector2 = front - d * 0.25  # just proud of the talus
		var depth_hi: Vector2 = front + d * (BATTER + THICK)
		var mid: Vector2 = (depth_lo + depth_hi) * 0.5
		var lintel_lo: float = gate_floor + GATE_H
		_box(_surf(detail, stone), _p3(mid, (lintel_lo + walk) * 0.5), _v3(along) * (GATE_W * 0.5 + 0.3),
			Vector3.UP * (walk - lintel_lo) * 0.5, _v3(d) * (BATTER + THICK + 0.25) * 0.5)
		var face: Vector2 = front + d * (BATTER * (1.0 - (lintel_lo - gate_floor) / (walk - gate_floor))) - d * 0.12
		_box(_surf(detail, dressed), _p3(face, lintel_lo + 0.2), _v3(along) * (GATE_W * 0.5 + 0.35), Vector3.UP * 0.25, _v3(d) * 0.15)
		for sgn: float in [-1.0, 1.0]:
			var jamb: Vector2 = front + along * sgn * (GATE_W * 0.5 + 0.2) - d * 0.1
			_box(_surf(detail, dressed), _p3(jamb, (gate_floor + lintel_lo) * 0.5), _v3(along) * 0.25,
				Vector3.UP * (lintel_lo - gate_floor) * 0.5 + Vector3.UP * 0.1, _v3(d) * 0.25)
		var fp: Vector2 = front + d * (BATTER + PARAPET_T * 0.5)  # over the parapet
		_box(_surf(detail, plaster), _p3(fp, walk + 0.95), _v3(along) * (GATE_W * 0.5 + 1.0), Vector3.UP * 0.95, _v3(d) * (PARAPET_T * 0.5 + 0.05))
		_box(_surf(detail, dressed), _p3(fp, walk + 1.98), _v3(along) * (GATE_W * 0.5 + 1.1), Vector3.UP * 0.1, _v3(d) * (PARAPET_T * 0.5 + 0.12))
		var plaque: Vector2 = fp - d * (PARAPET_T * 0.5 + 0.08)
		_box(_surf(detail, dressed), _p3(plaque, walk + 1.0), _v3(along) * 0.55, Vector3.UP * 0.65, _v3(d) * 0.05)

	# Paving: the courtyard and the gate passage, draped on the ground.
	_paving(detail, inner, front, d, deck_end)

	_commit(walls, "Fort_Walls", "Buildings")
	_commit(detail, "Fort_Detail", "Decor")
	if RESERVE_SCATTER:
		b._reserved.append(plan)
	courtyard = _open_spot(inner, front + d * (BATTER + THICK))
	print("  landmarks: fort with %d wall faces, gate at (%d, %d), %d embrasures, walk %.1f m, courtyard centre (%d, %d)"
		% [n_v, int(front.x), int(front.y), embrasures, walk, int(courtyard.x), int(courtyard.y)])


## Stations from `a` to `b` no more than `step` apart, both ends included.
func _steps(a: float, e: float, step: float = 4.0) -> Array[float]:
	var n: int = maxi(1, ceili(absf(e - a) / step))
	var out: Array[float] = []
	for k in n + 1:
		out.append(lerpf(a, e, float(k) / n))
	return out


## The same fraction on all four wall lines.
func _f4(f: float) -> Array:
	return [f, f, f, f]


## One parapet block between stations f0 and f1 of face i (fractions per
## wall line; lines T to P), from `y0` to `y1`, closed on every side.
func _parapet(s: Surf, lines: Array[PackedVector2Array], i: int, j: int, f0: Array, f1: Array, y0: float, y1: float, n3: Vector3) -> void:
	var to: Vector2 = lines[1][i].lerp(lines[1][j], f0[1])
	var t1: Vector2 = lines[1][i].lerp(lines[1][j], f1[1])
	var po: Vector2 = lines[2][i].lerp(lines[2][j], f0[2])
	var p1: Vector2 = lines[2][i].lerp(lines[2][j], f1[2])
	if to.distance_to(t1) < 0.01:
		return
	var along: Vector3 = _v3(t1 - to).normalized()
	s.quad(_p3(to, y0), _p3(t1, y0), _p3(t1, y1), _p3(to, y1), n3)
	s.quad(_p3(po, y0), _p3(p1, y0), _p3(p1, y1), _p3(po, y1), -n3)
	s.quad(_p3(to, y1), _p3(t1, y1), _p3(p1, y1), _p3(po, y1), Vector3.UP)
	s.quad(_p3(to, y0), _p3(po, y0), _p3(po, y1), _p3(to, y1), -along)
	s.quad(_p3(t1, y0), _p3(p1, y0), _p3(p1, y1), _p3(t1, y1), along)


## A round stone sentry box corbelled out over a corner, with slits and a dome.
func _guarita(detail: Dictionary, p: Vector2, walk: float, out: Vector2) -> void:
	var s: Surf = _surf(detail, _role("stone", STONE_METRES, QUOIN_TINT, Color(0.7, 0.68, 0.63)))
	var c := Vector3(p.x, 0, p.y)
	_loft(s, _ngon(c, 0.2, 12, walk - 1.3, 0.0), _ngon(c, 0.85, 12, walk, 0.0), c)
	_loft(s, _ngon(c, 0.8, 12, walk, 0.0), _ngon(c, 0.8, 12, walk + 2.1, 0.0), c)
	_loft(s, _ngon(c, 0.9, 12, walk + 2.1, 0.0), _ngon(c, 0.9, 12, walk + 2.25, 0.0), c)
	_cap(s, _ngon(c, 0.9, 12, walk + 2.1, 0.0), false)
	_dome(s, Vector3(p.x, walk + 2.25, p.y), 0.85, 0.75)
	_dome(s, Vector3(p.x, walk + 3.0, p.y), 0.12, 0.25)
	var slot: Surf = _surf(detail, _plain(SLOT, 0.5))
	var o3: Vector3 = _v3(out)
	for a: float in [-1.0, 0.0, 1.0]:
		var dir: Vector3 = o3.rotated(Vector3.UP, a * 1.1)
		var m: Vector3 = c + dir * 0.81
		var t: Vector3 = dir.cross(Vector3.UP) * 0.07
		slot.quad(m - t + Vector3.UP * (walk + 0.9), m + t + Vector3.UP * (walk + 0.9), m + t + Vector3.UP * (walk + 1.6), m - t + Vector3.UP * (walk + 1.6), dir)


## The talus foot's height at `p`: below the ground there and just outside
## (the islet's edge falls to the sea), so it never floats.
func _foot_y(p: Vector2, n: Vector2) -> float:
	return minf(_h(p), _h(p + n * 1.5)) - 1.0


## Courtyard and gate passage paving: 1 m tiles on the ground, Decor.
func _paving(detail: Dictionary, inner: PackedVector2Array, front: Vector2, d: Vector2, deck_end: Vector2) -> void:
	var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(inner, 0.6, Geometry2D.JOIN_MITER)
	var court: PackedVector2Array = grown[0] if not grown.is_empty() else inner
	var side := Vector2(-d.y, d.x)
	var passage := PackedVector2Array([deck_end - side * GATE_W * 0.5, deck_end + side * GATE_W * 0.5,
		front + d * (BATTER + THICK + 1.0) + side * GATE_W * 0.5, front + d * (BATTER + THICK + 1.0) - side * GATE_W * 0.5])
	var s: Surf = _surf(detail, _role("cliff", 2.5, Color(0.95, 0.93, 0.88), Color(0.6, 0.58, 0.54)))
	var box: Rect2 = Rect2(court[0], Vector2.ZERO)
	for q in court:
		box = box.expand(q)
	for q in passage:
		box = box.expand(q)
	for z in range(floori(box.position.y), ceili(box.end.y)):
		for x in range(floori(box.position.x), ceili(box.end.x)):
			var c := Vector2(x + 0.5, z + 0.5)
			if not Geometry2D.is_point_in_polygon(c, court) and not Geometry2D.is_point_in_polygon(c, passage):
				continue
			var corners: Array[Vector3] = []
			for o: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
				corners.append(Vector3(x + o.x, b.height_at(x + o.x, z + o.y) + 0.05, z + o.y))
			s.quad(corners[0], corners[1], corners[2], corners[3], Vector3.UP)


## The islet's coastline (open, without the closing point), or empty.
func _islet_ring(islet: Vector2) -> PackedVector2Array:
	for ring: PackedVector2Array in b._rings:
		var c: Vector2 = b._centroid(ring)
		if c.distance_to(islet) < 1.0:
			return _open(ring)
	return PackedVector2Array()


## [the bridge end on the islet nearest its centre, the bridge's direction
## onto the islet], or empty: as build.gd's _fort_islet finds the islet.
func _arrival(ring: PackedVector2Array) -> Array:
	var c: Vector2 = _centroid_open(ring)
	var best: Array = []
	var bd: float = INF
	for path: Array in b._paths:
		if not path[3]:
			continue
		var pts: PackedVector2Array = path[0]
		for end: int in [0, pts.size() - 1]:
			var p: Vector2 = pts[end]
			var near: bool = Geometry2D.is_point_in_polygon(p, ring) or _dist_to_ring(p, ring) < 4.0
			if near and p.distance_to(c) < bd:
				bd = p.distance_to(c)
				var prev: Vector2 = pts[1] if end == 0 else pts[end - 1]
				best = [p, (p - prev).normalized()]
	return best


## The fort's plan: the coastline COAST_INSET inside, cut by the front wall
## (square to the bridge, through `front`), with its faces straightened.
func _enclosure(ring: PackedVector2Array, front: Vector2, d: Vector2) -> PackedVector2Array:
	var inset: Array[PackedVector2Array] = Geometry2D.offset_polygon(ring, -COAST_INSET, Geometry2D.JOIN_MITER)
	var side := Vector2(-d.y, d.x)
	var half := PackedVector2Array([front + side * 1000.0, front - side * 1000.0, front - side * 1000.0 + d * 1000.0, front + side * 1000.0 + d * 1000.0])
	var best := PackedVector2Array()
	for poly in inset:
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, half):
			if absf(_signed_area(piece)) > absf(_signed_area(best)):
				best = piece
	if best.size() < 3:
		return best
	var plan: PackedVector2Array = _simplify(best, SIMPLIFY)
	# Drop corners that leave a face shorter than MIN_EDGE (never the two
	# corners of the front face).
	var changed: bool = true
	while changed and plan.size() > 4:
		changed = false
		for i in plan.size():
			var j: int = (i + 1) % plan.size()
			if plan[i].distance_to(plan[j]) >= MIN_EDGE:
				continue
			var on_front := func(q: Vector2) -> bool: return absf((q - front).dot(d)) < 0.1
			var drop: int = j if on_front.call(plan[i]) else i
			if on_front.call(plan[drop]):
				continue
			plan.remove_at(drop)
			changed = true
			break
	return plan


## Douglas-Peucker on a closed polygon: corners kept while the line between
## the kept ones strays more than `tol` from the original.
func _simplify(poly: PackedVector2Array, tol: float) -> PackedVector2Array:
	# Start from the two corners furthest apart.
	var a: int = 0
	var far: int = 0
	var fd: float = -1.0
	for i in poly.size():
		if poly[i].distance_to(poly[0]) > fd:
			fd = poly[i].distance_to(poly[0])
			far = i
	a = far
	fd = -1.0
	var e: int = 0
	for i in poly.size():
		if poly[i].distance_to(poly[a]) > fd:
			fd = poly[i].distance_to(poly[a])
			e = i
	var keep: Array[bool] = []
	keep.resize(poly.size())
	keep[a] = true
	keep[e] = true
	_dp(poly, a, e, tol, keep)
	_dp(poly, e, a, tol, keep)
	var out := PackedVector2Array()
	for i in poly.size():
		if keep[i]:
			out.append(poly[i])
	return out


func _dp(poly: PackedVector2Array, i0: int, i1: int, tol: float, keep: Array[bool]) -> void:
	var n: int = poly.size()
	var worst: int = -1
	var wd: float = tol
	var k: int = (i0 + 1) % n
	while k != i1:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(poly[k], poly[i0], poly[i1])
		if q.distance_to(poly[k]) > wd:
			wd = q.distance_to(poly[k])
			worst = k
		k = (k + 1) % n
	if worst >= 0:
		keep[worst] = true
		_dp(poly, i0, worst, tol, keep)
		_dp(poly, worst, i1, tol, keep)


## Median ground height over the points inside a polygon (1 m steps).
func _median_ground(poly: PackedVector2Array) -> float:
	var hs: Array[float] = []
	var box: Rect2 = Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		box = box.expand(q)
	for z in range(int(box.position.y), int(box.end.y), 2):
		for x in range(int(box.position.x), int(box.end.x), 2):
			if Geometry2D.is_point_in_polygon(Vector2(x, z), poly):
				hs.append(b.height_at(x, z))
	if hs.is_empty():
		return _h(poly[0])
	hs.sort()
	return hs[hs.size() / 2]


## The courtyard point furthest from the walls and from any building inside,
## a little nearer the gate when it is a tie.
func _open_spot(inner: PackedVector2Array, gate: Vector2) -> Vector2:
	var houses: Array[PackedVector2Array] = []
	for h: Array in b._houses:
		var pts: PackedVector2Array = h[0]
		if Geometry2D.is_point_in_polygon(b._centroid(pts), inner):
			houses.append(pts)
	var best: Vector2 = gate
	var bs: float = -INF
	var box: Rect2 = Rect2(inner[0], Vector2.ZERO)
	for q in inner:
		box = box.expand(q)
	for z in range(int(box.position.y), int(box.end.y)):
		for x in range(int(box.position.x), int(box.end.x)):
			var p := Vector2(x + 0.5, z + 0.5)
			if not Geometry2D.is_point_in_polygon(p, inner):
				continue
			var clear: float = _dist_to_ring(p, inner, true)
			for h in houses:
				clear = minf(clear, 0.0 if Geometry2D.is_point_in_polygon(p, h) else _dist_to_ring(p, h))
			var score: float = minf(clear, 10.0) - p.distance_to(gate) * 0.02
			if score > bs:
				bs = score
				best = p
	return best


# ---------------------------------------------------------------- meshes

## Side faces between two closed rings of the same size (flat, facing away
## from the axis through `centre`).
func _loft(s: Surf, lower: PackedVector3Array, upper: PackedVector3Array, centre: Vector3) -> void:
	var n: int = lower.size()
	for i in n:
		var j: int = (i + 1) % n
		var mid: Vector3 = (lower[i] + lower[j] + upper[i] + upper[j]) * 0.25
		var nrm: Vector3 = (lower[j] - lower[i]).cross(upper[i] - lower[i]).normalized()
		var away := Vector3(mid.x - centre.x, 0, mid.z - centre.z)
		if nrm.dot(away) < 0.0:
			nrm = -nrm
		s.quad(lower[i], lower[j], upper[j], upper[i], nrm)


## A flat fan closing a ring, facing up or down.
func _cap(s: Surf, ring: PackedVector3Array, up: bool) -> void:
	var c := Vector3.ZERO
	for v in ring:
		c += v
	c /= ring.size()
	for i in ring.size():
		s.tri(c, ring[i], ring[(i + 1) % ring.size()], Vector3.UP if up else Vector3.DOWN)


## A half ellipsoid on a circle of radius `r` at `base`, `h` high (negative:
## hanging down), smooth.
func _dome(s: Surf, base: Vector3, r: float, h: float) -> void:
	var seg: int = 16
	var rings: int = 6
	var pts: Array[PackedVector3Array] = []
	var nrm: Array[PackedVector3Array] = []
	for k in rings + 1:
		var t: float = float(k) / rings * PI * 0.5
		var row := PackedVector3Array()
		var nrow := PackedVector3Array()
		for i in seg:
			var a: float = TAU * i / seg
			var v := Vector3(cos(a) * cos(t) * r, sin(t) * h, sin(a) * cos(t) * r)
			row.append(base + v)
			var nv := Vector3(v.x / (r * r), v.y / (h * h), v.z / (r * r)).normalized()
			nrow.append(nv if k < rings else Vector3.UP * signf(h))
		pts.append(row)
		nrm.append(nrow)
	for k in rings:
		for i in seg:
			var j: int = (i + 1) % seg
			s.tri3(pts[k][i], pts[k][j], pts[k + 1][j], nrm[k][i], nrm[k][j], nrm[k + 1][j])
			s.tri3(pts[k][i], pts[k + 1][j], pts[k + 1][i], nrm[k][i], nrm[k + 1][j], nrm[k + 1][i])


## A box: centre and half axes, all six faces.
func _box(s: Surf, c: Vector3, ax: Vector3, ay: Vector3, az: Vector3) -> void:
	for f: Array in [[az, ax, ay], [-az, ax, ay], [ax, ay, az], [-ax, ay, az], [ay, ax, az], [-ay, ax, az]]:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var m: Vector3 = c + n
		s.quad(m - u - v, m + u - v, m + u + v, m - u + v, n.normalized())


## The square of half side `half` round `p`, turned along `axis`, at height y.
func _square(p: Vector2, axis: Vector2, half: float, y: float) -> PackedVector3Array:
	var side := Vector2(-axis.y, axis.x)
	var out := PackedVector3Array()
	for o: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var q: Vector2 = p + (axis * o.x + side * o.y) * half
		out.append(Vector3(q.x, y, q.y))
	return out


## A regular polygon of `n` corners on radius `r` round `c` at height y.
func _ngon(c: Vector3, r: float, n: int, y: float, turn: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	for i in n:
		var a: float = turn + TAU * i / n
		out.append(Vector3(c.x + cos(a) * r, y, c.z + sin(a) * r))
	return out


func _surf(group: Dictionary, m: Material) -> Surf:
	if not group.has(m):
		group[m] = Surf.new()
	return group[m]


## One node for a group of surfaces (one per material).
func _commit(group: Dictionary, name: String, parent: String) -> void:
	var mesh := ArrayMesh.new()
	for m: Material in group:
		var s: Surf = group[m]
		if s.empty:
			continue
		s.st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, m)
	if mesh.get_surface_count() == 0:
		return
	var inst := MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	b._add(inst, parent)


## A builder texture material tinted (above 1 to whiten the mid-grey
## plaster), or a plain colour when the place has no such texture.
func _role(role: String, metres: float, tint: Color, fallback: Color) -> Material:
	var key: String = "%s/%s/%s" % [role, metres, tint]
	if not _mats.has(key):
		var m: StandardMaterial3D = b._role_material(role, metres, tint, false)
		_mats[key] = m if m != null else b._mat(fallback, 0.9)
	return _mats[key]


func _plain(c: Color, rough: float) -> Material:
	var key: String = "plain/%s/%s" % [c.to_html(), rough]
	if not _mats.has(key):
		_mats[key] = b._mat(c, rough)
	return _mats[key]


func _glass() -> Material:
	if not _mats.has("glass"):
		var m: StandardMaterial3D = b._mat(Color(0.16, 0.22, 0.24, 0.55), 0.05)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic_specular = 0.9
		_mats["glass"] = m
	return _mats["glass"]


func _lamp() -> Material:
	if not _mats.has("lamp"):
		var m: StandardMaterial3D = b._mat(Color(1.0, 0.85, 0.55), 0.3)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.8, 0.45)
		m.emission_energy_multiplier = 1.5
		_mats["lamp"] = m
	return _mats["lamp"]


# ---------------------------------------------------------------- geometry

func _h(p: Vector2) -> float:
	return b.height_at(p.x, p.y)


func _p3(p: Vector2, y: float) -> Vector3:
	return Vector3(p.x, y, p.y)


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


## Without the closing point OSM rings repeat.
func _open(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() > 1 and pts[0].distance_to(pts[pts.size() - 1]) < 0.01:
		return pts.slice(0, pts.size() - 1)
	return pts


func _signed_area(poly: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in poly.size():
		var j: int = (i + 1) % poly.size()
		a += poly[i].x * poly[j].y - poly[j].x * poly[i].y
	return a * 0.5


func _centroid_open(poly: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for q in poly:
		c += q
	return c / maxf(poly.size(), 1)


## Distance from `p` to a ring's edges (closed: the last point joins the first).
func _dist_to_ring(p: Vector2, ring: PackedVector2Array, closed: bool = true) -> float:
	var d: float = INF
	var n: int = ring.size()
	for i in (n if closed else n - 1):
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, ring[i], ring[(i + 1) % n])))
	return d
