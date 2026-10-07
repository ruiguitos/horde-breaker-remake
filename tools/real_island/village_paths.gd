extends RefCounted
## Paths, steps and the concrete road for the real-island builder (build.gd),
## for every way that enters the place's detail_area (Berlenga: the landing,
## the road up and the Bairro dos Pescadores). A way that enters the area is
## built whole here, so there is no seam where the area ends.
##
## All of it is decoration in Decor/: the grid and the player walk the carved
## terrain (build.gd height_at, ramps of at most PATH_SLOPE), so every mesh
## stays within about one riser of that ground.
##
## - Steps (highway=steps): horizontal treads and risers that follow the
##   carved ramp. A riser is placed where the ramp has moved more than half a
##   riser away from the current tread, so steep stretches become flights and
##   flat stretches (or corners) become landings. Risers are 15-18 cm, or the
##   OSM step_count when it fits the carved height. Concrete steps get low
##   stone kerbs; handrail=yes gets a steel rail on the open (lower) side.
## - Concrete / paved ways (the 700 m service road, the village footways):
##   a slab draped on the ground, UVs in metres along the way, transverse
##   joints, worn uneven edges that crumble into the ground, and short kerbs
##   only where the ground falls away beside the way.
## - Dirt, gravel and rock trails stay the terrain's path texture, with a few
##   loose stones along their edges (never a continuous border).
## Corners use a mitre (limited): the inner edge meets in one point, so the
## strips never fold over themselves.

const PAVED: Array[String] = ["concrete", "paved", "asphalt", "paving_stones", "sett", "cobblestone", "concrete:plates", "concrete:lanes"]
const RISER_MIN: float = 0.15
const RISER_MAX: float = 0.18
const TREAD_MIN: float = 0.2   ## shortest tread (steep cliff steps; ramps up to 0.78 m/m)
const KERB_W: float = 0.2      ## stone kerb beside concrete steps
const KERB_UP: float = 0.1     ## kerb top above the walking surface: < 15 cm, never a wall
const TREAD_LIFT: float = 0.05  ## treads sit this much above the carved ramp
const SINK: float = 0.25       ## vertical faces reach this far under the ground
const BURIED: float = 0.3      ## a tread the ground covers by more is left out (hairpins)
const MAX_TURN: float = 2.3    ## radians; sharper corners are mitred as if this sharp

var b: SceneTree  ## the builder (build.gd): height_at, _add, _role_material, P...
var _concrete := SurfaceTool.new()  ## slabs and concrete treads (UVs, vertex colours)
var _stone := SurfaceTool.new()     ## rock steps, kerbs, loose stones
var _metal := SurfaceTool.new()     ## handrails
var _used: Dictionary = {}          ## SurfaceTool -> true once it has triangles
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _area: Rect2
# The way being built (_prepare).
var _pts := PackedVector2Array()
var _cum := PackedFloat32Array()     ## metres along the way at each point
var _zone := PackedFloat32Array()    ## half length of each point's corner zone
var _miter := PackedVector2Array()   ## each corner's offset to its "a" side edge
var _half: float = 1.0
var _built: int = 0


func _init(builder: SceneTree) -> void:
	b = builder
	for st: SurfaceTool in [_concrete, _stone, _metal]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_noise.seed = 7
	_noise.frequency = 0.15


## Builds `path` ([points, width, kind, bridge, tags]) and returns true, or
## false to leave it to the builder (ways that never enter the detail area).
func place(path: Array) -> bool:
	_area = b.P["detail_area"]
	var raw: PackedVector2Array = path[0]
	if path[3] or not _enters(raw):
		return false
	var tags: Dictionary = path[4]
	var kind: String = path[2]
	var surface: String = tags.get("surface", "")
	# The builder's width: the corridor carved for the way has it, and a
	# wider mesh would hang over its shoulders (found by Codex).
	var w: float = float(path[1])
	_prepare(raw, w * 0.5)
	if _pts.size() < 2:
		return false
	_rng.seed = int(tags["osm_id"])
	var what: String
	if kind == "steps":
		what = _steps(tags, surface in PAVED)
	elif surface in PAVED or (kind == "service" and surface == ""):
		what = _slab(3.5 if kind == "service" else 2.0)
	else:
		what = _trail()
	_built += 1
	print("  paths kit: %d %s (%s) %.1f m: %s" % [int(tags["osm_id"]), kind, surface if surface != "" else "-", _cum[_cum.size() - 1], what])
	return true


## Called once after every path: one mesh per material in Decor/.
func finish() -> void:
	# Concrete: the plaster scan reads as cast concrete. Stone: the cliff
	# granite, so rock-cut steps, kerbs and loose stones match the cliffs.
	var concrete: StandardMaterial3D = b._role_material("plaster", 2.5, Color(0.9, 0.89, 0.86), true)
	var stone: StandardMaterial3D = b._role_material("cliff", 2.0, Color(1, 1, 1), true)
	concrete = concrete.duplicate() if concrete != null else b._mat(Color(0.62, 0.6, 0.56))
	stone = stone.duplicate() if stone != null else b._mat(Color(0.5, 0.48, 0.45))
	for m: StandardMaterial3D in [concrete, stone]:
		m.vertex_color_use_as_albedo = true  # joints, worn edges, tone per step
	var metal: StandardMaterial3D = b._mat(Color(0.2, 0.24, 0.22), 0.45)
	metal.metallic = 0.6
	_commit(_concrete, "PathConcrete", concrete, true)
	_commit(_stone, "PathStone", stone, true)
	_commit(_metal, "Handrails", metal, false)
	print("  paths kit: %d ways built in the detail area" % _built)


func _commit(st: SurfaceTool, name: String, mat: Material, tangents: bool) -> void:
	if not _used.has(st):
		return
	if tangents:
		st.generate_tangents()  # normal maps with the meshes' own UVs
	var inst := MeshInstance3D.new()
	inst.name = name
	inst.mesh = st.commit()
	inst.material_override = mat
	b._add(inst, "Decor")


# ---------------------------------------------------------------- the way

func _enters(pts: PackedVector2Array) -> bool:
	for i in pts.size() - 1:
		var n: int = maxi(1, ceili(pts[i].distance_to(pts[i + 1])))
		for k in n + 1:
			if _area.has_point(pts[i].lerp(pts[i + 1], float(k) / n)):
				return true
	return false


## Points without duplicates, distances along, and the mitre of each corner:
## a zone of `_zone[j]` metres on each side of corner j where the strip turns
## around the mitre line, so the inner edge meets in one point.
func _prepare(raw: PackedVector2Array, half: float) -> void:
	_pts = PackedVector2Array()
	for p in raw:
		if _pts.is_empty() or p.distance_to(_pts[_pts.size() - 1]) > 0.05:
			_pts.append(p)
	_half = half
	var n: int = _pts.size()
	_cum = PackedFloat32Array([0.0])
	for i in range(1, n):
		_cum.append(_cum[i - 1] + _pts[i].distance_to(_pts[i - 1]))
	_zone = PackedFloat32Array()
	_zone.resize(n)
	_miter = PackedVector2Array()
	_miter.resize(n)
	for j in range(1, n - 1):
		var t0: Vector2 = (_pts[j] - _pts[j - 1]).normalized()
		var t1: Vector2 = (_pts[j + 1] - _pts[j]).normalized()
		var turn: float = minf(acos(clampf(t0.dot(t1), -1.0, 1.0)), MAX_TURN)
		if turn < 0.02:
			continue
		var bis: Vector2 = (Vector2(-t0.y, t0.x) + Vector2(-t1.y, t1.x)).normalized()
		_zone[j] = minf(half * tan(turn * 0.5), 0.45 * minf(_cum[j] - _cum[j - 1], _cum[j + 1] - _cum[j]))
		_miter[j] = bis * half / maxf(cos(turn * 0.5), 0.4)


## [centre, a edge, b edge] of the cross-section `d` metres along the way.
func _frame(d: float) -> PackedVector2Array:
	d = clampf(d, 0.0, _cum[_cum.size() - 1])
	for j in range(1, _pts.size() - 1):
		var s: float = d - _cum[j]
		if _zone[j] > 0.0 and absf(s) < _zone[j]:
			var edge: PackedVector2Array = _straight(j - 1 if s < 0.0 else j, _cum[j] + (-_zone[j] if s < 0.0 else _zone[j]))
			var corner := PackedVector2Array([_pts[j], _pts[j] + _miter[j], _pts[j] - _miter[j]])
			var k: float = absf(s) / _zone[j]
			return PackedVector2Array([corner[0].lerp(edge[0], k), corner[1].lerp(edge[1], k), corner[2].lerp(edge[2], k)])
	return _straight(clampi(_cum.bsearch(d) - 1, 0, _pts.size() - 2), d)


func _straight(i: int, d: float) -> PackedVector2Array:
	var t: Vector2 = (_pts[i + 1] - _pts[i]).normalized()
	var c: Vector2 = _pts[i] + t * (d - _cum[i])
	var n := Vector2(-t.y, t.x) * _half
	return PackedVector2Array([c, c + n, c - n])


## The point at fraction `f` across a frame: 0 centre, 1 the a edge, -1 b.
func _at(fr: PackedVector2Array, f: float) -> Vector2:
	return fr[0].lerp(fr[1], f) if f >= 0.0 else fr[0].lerp(fr[2], -f)


func _in_zone(d: float, pad: float) -> bool:
	for j in range(1, _pts.size() - 1):
		if _zone[j] > 0.0 and absf(d - _cum[j]) < _zone[j] + pad:
			return true
	return false


## Distances of the corner-zone edges and corners strictly inside (d0, d1).
func _corner_stations(d0: float, d1: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for j in range(1, _pts.size() - 1):
		if _zone[j] <= 0.0:
			continue
		for d: float in [_cum[j] - _zone[j], _cum[j], _cum[j] + _zone[j]]:
			if d > d0 + 0.001 and d < d1 - 0.001:
				out.append(d)
	return out


func _g(p: Vector2) -> float:
	return b.height_at(p.x, p.y)


func _normal(p: Vector2) -> Vector3:
	var e: float = 0.5
	return Vector3(_g(p - Vector2(e, 0)) - _g(p + Vector2(e, 0)), 2.0 * e, _g(p - Vector2(0, e)) - _g(p + Vector2(0, e))).normalized()


# ---------------------------------------------------------------- steps

## Treads and risers along the carved ramp. Returns the line for the log.
func _steps(tags: Dictionary, concrete: bool) -> String:
	var length: float = _cum[_cum.size() - 1]
	var n: int = maxi(2, ceili(length / 0.05))
	var ds: float = length / n
	var hs := PackedFloat32Array()  # the carved ground under the centre line
	for k in n + 1:
		hs.append(_g(_frame(k * ds)[0]))
	var win: int = mini(n, int(2.0 / ds))
	var steep: float = 0.0
	for k in n + 1 - win:
		steep = maxf(steep, absf(hs[k + win] - hs[k]) / (win * ds))
	# Riser: steep ramps need taller risers to keep treads TREAD_MIN deep.
	var riser: float = clampf(steep * 0.25, RISER_MIN, RISER_MAX)
	var note: String = ""
	var count: int = String(tags.get("step_count", "")).to_int()
	if count > 0:
		var r: float = absf(hs[n] - hs[0]) / count
		if r >= 0.12 and r <= 0.2:
			riser = r
			note = ", OSM step_count %d kept" % count
		else:
			note = ", OSM step_count %d would be %.0f cm risers here" % [count, r * 100.0]
	# A riser where the ground has left the tread by more than half a riser.
	var risers := PackedFloat32Array()
	var levels := PackedFloat32Array([hs[0]])
	var level: float = hs[0]
	var last: float = 0.0
	var worst: float = 0.0
	for k in n + 1:
		var d: float = k * ds
		var diff: float = hs[k] - level
		# Risers inside a corner zone are winders: the zone's cross-sections
		# all meet at the inner mitre point, so they fan without overlapping.
		if absf(diff) > riser * 0.55 and d - last >= TREAD_MIN - ds * 0.5 and length - d >= TREAD_MIN * 0.5:
			level += signf(diff) * riser
			risers.append(d)
			levels.append(level)
			last = d
		worst = maxf(worst, absf(hs[k] - level))
	var bounds := PackedFloat32Array([0.0])
	bounds.append_array(risers)
	bounds.append(length)
	var inner: float = 1.0 - KERB_W / _half if concrete else 1.0
	var st: SurfaceTool = _concrete if concrete else _stone
	# Each tread: its stations (corners inside it) and its cross tilt. Where
	# the stair runs across a hillside the carved ground is tilted sideways
	# too (up to PATH_SLOPE per metre), and the grid walks that ground: a
	# level tread would be half buried. Treads stay level along the way but
	# lean across like the ground (smoothed over neighbours, capped).
	var stations: Array[PackedFloat32Array] = []
	var frames: Array = []
	var tilts := PackedFloat32Array()
	for t in levels.size():
		var at := PackedFloat32Array([bounds[t]])
		at.append_array(_corner_stations(bounds[t], bounds[t + 1]))
		at.append(bounds[t + 1])
		var frs: Array[PackedVector2Array] = []
		var tilt: float = 0.0
		for d in at:
			var fr: PackedVector2Array = _frame(d)
			frs.append(fr)
			tilt += (_g(fr[1]) - _g(fr[2])) * 0.5 / at.size()
		stations.append(at)
		frames.append(frs)
		tilts.append(clampf(tilt, -0.6, 0.6))
	var smooth := tilts.duplicate()
	for t in tilts.size():
		smooth[t] = (tilts[maxi(t - 1, 0)] + 2.0 * tilts[t] + tilts[mini(t + 1, tilts.size() - 1)]) * 0.25
	var cross: float = 0.0  # ground above a drawn tread, worst case
	var skipped: int = 0  # treads left out: the ground covers them
	var lean: float = 0.0
	var flights: int = 0
	for t in levels.size():
		# (height at the centre, rise per unit of f), a little above the
		# ground like the slabs, so a long landing is not hidden by it.
		var lv := Vector2(levels[t] + TREAD_LIFT, smooth[t])
		var prev: Vector2 = Vector2(levels[t - 1] + TREAD_LIFT, smooth[t - 1]) if t > 0 else lv
		var next: Vector2 = Vector2(levels[t + 1] + TREAD_LIFT, smooth[t + 1]) if t + 1 < levels.size() else lv
		if t > 0 and (t == 1 or bounds[t] - bounds[t - 1] > 1.0):
			flights += 1  # a riser after a landing (or the first) starts a flight
		var at: PackedFloat32Array = stations[t]
		var frs: Array[PackedVector2Array] = frames[t]
		lean = maxf(lean, absf(lv.y))
		var over: float = 0.0
		for fr in frs:
			for f: float in [-1.0, -0.5, 0.5, 1.0]:
				over = maxf(over, _g(_at(fr, f)) - (lv.x + lv.y * f))
		if over > BURIED:
			skipped += 1
			continue  # a hairpin: the stair stops and the ground is the landing (found by Codex)
		cross = maxf(cross, over)
		var tone: float = _rng.randf_range(0.84, 1.0)
		var col := Color(tone, tone, tone * 0.98) if concrete else Color(tone, tone * 0.97, tone * 0.93)
		_block(st, at, frs, -inner, inner, lv, prev, next, col)
		if concrete:
			var kc := Color(1, 1, 1) * _rng.randf_range(0.8, 1.0)
			var up := Vector2(KERB_UP, 0)
			for side: float in [-1.0, 1.0]:
				_block(_stone, at, frs, minf(side, side * inner), maxf(side, side * inner), lv + up, prev + up, next + up, kc)
	var rail: String = ""
	if tags.get("handrail") == "yes":
		rail = _handrail(risers, levels, smooth)
	return "%d steps (riser %.1f cm) in %d flights, centre %.0f cm off the ground at most, lean up to %.0f cm, ground up to %.0f cm over a tread, %d treads left to the ground%s%s%s" % [
		risers.size(), riser * 100.0, flights, worst * 100.0, lean * 100.0, maxf(cross, 0.0) * 100.0, skipped, ", stone kerbs" if concrete else "", rail, note]


## A solid along the stations `at` (frames `frs`) between fractions f0 and
## f1 across. `top` = (height at the centre line, rise per unit of f): level
## along the way, leaning across. The end faces reach down to the
## neighbouring treads (`prev`, `next`) and every vertical face SINK under
## the ground, so no tread floats.
func _block(st: SurfaceTool, at: PackedFloat32Array, frs: Array[PackedVector2Array], f0: float, f1: float, top: Vector2, prev: Vector2, next: Vector2, col: Color) -> void:
	var n: int = at.size()
	for i in n - 1:
		var p := PackedVector3Array()
		var uv := PackedVector2Array()
		for q: Vector2 in [Vector2(i, f0), Vector2(i, f1), Vector2(i + 1, f1), Vector2(i + 1, f0)]:
			var v: Vector2 = _at(frs[int(q.x)], q.y)
			p.append(Vector3(v.x, top.x + top.y * q.y, v.y))
			uv.append(Vector2(q.y * _half, at[int(q.x)]))
		_flat(st, p, uv, col, Vector3.UP)
	for f: float in [f0, f1]:
		var y: float = top.x + top.y * f
		for i in n - 1:
			var a: Vector2 = _at(frs[i], f)
			var c: Vector2 = _at(frs[i + 1], f)
			if a.distance_to(c) < 0.002:
				continue  # the inner edge of a mitred corner
			var out: Vector2 = _at(frs[i], f1) - _at(frs[i], f0)
			if f == f0:
				out = -out
			var ya: float = _bottom(a, y, y)
			var yc: float = _bottom(c, y, y)
			_flat(st, PackedVector3Array([Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(c.x, yc, c.y), Vector3(a.x, ya, a.y)]),
				PackedVector2Array([Vector2(at[i], y), Vector2(at[i + 1], y), Vector2(at[i + 1], yc), Vector2(at[i], ya)]), col, Vector3(out.x, 0, out.y))
	for e in 2:
		var k: int = 0 if e == 0 else n - 1
		var nb: Vector2 = prev if e == 0 else next
		var t: Vector2 = frs[mini(k + 1, n - 1)][0] - frs[maxi(k - 1, 0)][0]
		if e == 0:
			t = -t
		var a: Vector2 = _at(frs[k], f0)
		var c: Vector2 = _at(frs[k], f1)
		var ta: float = top.x + top.y * f0
		var tc: float = top.x + top.y * f1
		var ya: float = _bottom(a, ta, nb.x + nb.y * f0)
		var yc: float = _bottom(c, tc, nb.x + nb.y * f1)
		_flat(st, PackedVector3Array([Vector3(a.x, ta, a.y), Vector3(c.x, tc, c.y), Vector3(c.x, yc, c.y), Vector3(a.x, ya, a.y)]),
			PackedVector2Array([Vector2(f0 * _half, ta), Vector2(f1 * _half, tc), Vector2(f1 * _half, yc), Vector2(f0 * _half, ya)]), col, Vector3(t.x, 0, t.y))


func _bottom(p: Vector2, top: float, neighbour: float) -> float:
	return minf(minf(top, neighbour) - 0.05, _g(p) - SINK)


## Steel posts every 2 m (and at corners) on the open side, two rails.
func _handrail(risers: PackedFloat32Array, levels: PackedFloat32Array, tilts: PackedFloat32Array) -> String:
	var length: float = _cum[_cum.size() - 1]
	var drop: float = 0.0  # > 0: the a side is lower
	var d: float = 0.5
	while d < length:
		var fr: PackedVector2Array = _frame(d)
		var out: Vector2 = (fr[1] - fr[0]).normalized() * 1.5
		drop += _g(fr[2] - out) - _g(fr[1] + out)
		d += 1.0
	var side: float = 1.0 if drop > 0.0 else -1.0
	var stops := PackedFloat32Array([0.25])
	var n: int = maxi(1, ceili((length - 0.5) / 2.0))
	for k in range(1, n):
		stops.append(0.25 + (length - 0.5) * k / n)
	for j in range(1, _pts.size() - 1):
		if _zone[j] > 0.0:
			stops.append(_cum[j])
	stops.append(length - 0.25)
	stops.sort()
	var tops: Array[Vector3] = []
	for s in stops:
		var f: float = side * (1.0 - 0.12 / _half)
		var p: Vector2 = _at(_frame(s), f)
		var t: int = risers.bsearch(s, false)
		var y: float = levels[t] + TREAD_LIFT + tilts[t] * f + 0.95
		var top := Vector3(p.x, y, p.y)
		tops.append(top)
		_beam(_metal, top - Vector3(0.025, 0, 0), top + Vector3(0.025, 0, 0), 0.05, 1.1, Color.WHITE)
	for k in tops.size() - 1:
		for drop_y: float in [0.0, 0.45]:
			var down := Vector3(0, drop_y, 0)
			_beam(_metal, tops[k] - down, tops[k + 1] - down, 0.045, 0.045, Color.WHITE)
	return ", handrail (%d posts, %s side)" % [tops.size(), "a" if side > 0.0 else "b"]


# ---------------------------------------------------------------- slabs

## A concrete slab draped on the ground with joints every `joint` metres.
func _slab(joint: float) -> String:
	var length: float = _cum[_cum.size() - 1]
	var stations: Array[Vector2] = []  # (metres along, 1 at a joint line)
	var d: float = 0.0
	while d < length:
		stations.append(Vector2(d, 0))
		d += 1.0
	stations.append(Vector2(length, 0))
	var joints: int = 0
	d = joint
	while d < length - 0.5:
		if not _in_zone(d, 0.1):
			stations.append_array([Vector2(d - 0.04, 0), Vector2(d, 1), Vector2(d + 0.04, 0)])
			joints += 1
		d += joint
	for s in _corner_stations(0.0, length):
		stations.append(Vector2(s, 0))
	stations.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
	var clean: Array[Vector2] = []
	for s in stations:
		if clean.is_empty() or s.x - clean[clean.size() - 1].x > 0.005:
			clean.append(s)
		elif s.y > 0.0:
			clean[clean.size() - 1] = s
	stations = clean
	var frs: Array[PackedVector2Array] = []
	for s in stations:
		frs.append(_frame(s.x))
	# Kerbs: only where the ground beside falls away (a built-up edge), in
	# runs of at least 2 m, inside the detail area.
	var kerb: Array[PackedByteArray] = []
	for side in 2:
		var f: float = 1.0 if side == 0 else -1.0
		var flags := PackedByteArray()
		flags.resize(stations.size())
		for i in stations.size():
			var e: Vector2 = _at(frs[i], f)
			var out: Vector2 = (e - frs[i][0]).normalized()
			flags[i] = 1 if _area.has_point(e) and _g(e) - _g(e + out * 1.2) > 0.45 else 0
		var i: int = 0
		while i < flags.size():
			var j: int = i
			while j < flags.size() and flags[j] == 1:
				j += 1
			if j > i and stations[j - 1].x - stations[i].x < 2.0:
				for k in range(i, j):
					flags[k] = 0
			i = j + 1
		kerb.append(flags)
	# Rows across: worn lip, edge, ..., centre, ..., edge, worn lip.
	const F: Array[float] = [-1.0, -0.75, -0.35, 0.0, 0.35, 0.75, 1.0]
	var seed_y: float = float(_rng.randi_range(0, 1000))
	var prev: Array = []
	var kerb_m: float = 0.0
	for i in stations.size():
		var s: Vector2 = stations[i]
		var fr: PackedVector2Array = frs[i]
		var wear := PackedFloat32Array()  # metres the edge has crumbled on each side
		for side in 2:
			if kerb[side][i] == 1:
				wear.append(0.0)
			else:
				var w: float = 0.5 + 0.5 * _noise.get_noise_2d(s.x, seed_y + side * 200.0) + 0.25 * _noise.get_noise_2d(s.x * 6.0, seed_y + side * 200.0 + 50.0)
				wear.append(clampf(0.04 + 0.16 * w, 0.02, minf(0.22, _half * 0.2)))
		var tone: float = 0.93 + 0.07 * _noise.get_noise_2d(s.x * 0.5, seed_y + 500.0)
		var row: Array = []  # [point, y, uv, colour] per column
		var cols: Array[float] = [-1.0 - 0.3 / _half]
		cols.append_array(F)
		cols.append(1.0 + 0.3 / _half)
		for c in cols.size():
			var f: float = cols[c]
			var side: int = 0 if f > 0.0 else 1
			var lip: bool = c == 0 or c == cols.size() - 1
			var eff: float = 1.0 - wear[side] / _half
			var across: float = f * eff if not lip else signf(f) * (eff + 0.3 / _half)
			var p: Vector2 = _at(fr, across)
			var lift: float = 0.05
			var col := Color(tone, tone * 0.99, tone * 0.96)
			if lip:
				lift = -0.05
				col = Color(0.5, 0.46, 0.38)
			elif absf(f) == 1.0:
				lift = 0.03
				col = Color(tone * 0.8, tone * 0.77, tone * 0.7)
			elif absf(f) == 0.75:
				col = col * 0.95
			if s.y > 0.0 and not lip:
				col = Color(col.r * 0.6, col.g * 0.6, col.b * 0.6)
			row.append([p, _g(p) + lift, Vector2(across * _half, s.x), col])
		if not prev.is_empty():
			for c in row.size() - 1:
				var q: Array = [prev[c], prev[c + 1], row[c + 1], row[c]]
				var ps := PackedVector3Array()
				var ns := PackedVector3Array()
				var uvs := PackedVector2Array()
				var cs := PackedColorArray()
				for v: Array in q:
					var p2: Vector2 = v[0]
					ps.append(Vector3(p2.x, v[1], p2.y))
					ns.append(_normal(p2))
					uvs.append(v[2])
					cs.append(v[3])
				_quad(_concrete, ps, ns, uvs, cs, Vector3.UP)
			# Kerb pieces on the slab's outer 12 cm, 10 cm above it.
			for side in 2:
				if kerb[side][i] == 1 and kerb[side][i - 1] == 1:
					var f: float = (1.0 if side == 0 else -1.0) * (1.0 - 0.06 / _half)
					var a: Vector2 = _at(frs[i - 1], f)
					var c: Vector2 = _at(fr, f)
					_beam(_stone, Vector3(a.x, _g(a) + 0.05 + KERB_UP, a.y), Vector3(c.x, _g(c) + 0.05 + KERB_UP, c.y), 0.12, 0.4, Color(0.8, 0.78, 0.74))
					kerb_m += a.distance_to(c)
		prev = row
	return "concrete slab %.1f m wide, %d joints, %.0f m of kerbs" % [_half * 2.0, joints, kerb_m]


# ---------------------------------------------------------------- trails

## Dirt and rock trails keep the terrain texture: a few loose stones beside
## them inside the detail area.
func _trail() -> String:
	var length: float = _cum[_cum.size() - 1]
	var count: int = 0
	var d: float = _rng.randf_range(1.0, 4.0)
	while d < length:
		var side: float = 1.0 if _rng.randf() < 0.5 else -1.0
		var p: Vector2 = _at(_frame(d), side * (1.0 + _rng.randf_range(0.05, 0.3) / _half))
		if _area.has_point(p):
			var t: Vector2 = (_frame(d + 0.5)[0] - _frame(d - 0.5)[0]).normalized().rotated(_rng.randf_range(-0.6, 0.6))
			var half_len: float = _rng.randf_range(0.09, 0.2)
			var a: Vector2 = p - t * half_len
			var c: Vector2 = p + t * half_len
			var top: float = maxf(_g(a), _g(c)) + _rng.randf_range(0.04, 0.1)
			var tone: float = _rng.randf_range(0.7, 0.95)
			_beam(_stone, Vector3(a.x, top, a.y), Vector3(c.x, top, c.y), _rng.randf_range(0.14, 0.28), 0.35, Color(tone, tone * 0.97, tone * 0.92))
			count += 1
		d += _rng.randf_range(2.5, 7.0)
	return "terrain texture, %d loose edge stones" % count


# ---------------------------------------------------------------- meshes

## A box whose top runs from `a` to `c` (centre line), `w` wide, `h` deep
## straight down (sloped tops keep vertical ends, so pieces chain).
func _beam(st: SurfaceTool, a: Vector3, c: Vector3, w: float, h: float, col: Color) -> void:
	var flat := Vector2(c.x - a.x, c.z - a.z)
	var side := Vector3(1, 0, 0) * w * 0.5
	if flat.length() > 0.001:
		side = Vector3(-flat.y, 0, flat.x).normalized() * w * 0.5
	var top := PackedVector3Array([a + side, c + side, c - side, a - side])
	var down := Vector3(0, -h, 0)
	var mid: Vector3 = (a + c) * 0.5
	_flat(st, top, PackedVector2Array([Vector2(top[0].x, top[0].z), Vector2(top[1].x, top[1].z), Vector2(top[2].x, top[2].z), Vector2(top[3].x, top[3].z)]), col, Vector3.UP)
	for k in 4:
		var p: Vector3 = top[k]
		var q: Vector3 = top[(k + 1) % 4]
		var along := Vector3(q.x - p.x, 0, q.z - p.z).normalized()
		var hint: Vector3 = (p + q) * 0.5 - mid
		hint.y = 0.0
		_flat(st, PackedVector3Array([p, q, q + down, p + down]),
			PackedVector2Array([Vector2(p.dot(along), p.y), Vector2(q.dot(along), q.y), Vector2(q.dot(along), q.y - h), Vector2(p.dot(along), p.y - h)]), col, hint)


## A flat quad (loop order) facing `hint`, one colour.
func _flat(st: SurfaceTool, p: PackedVector3Array, uv: PackedVector2Array, col: Color, hint: Vector3) -> void:
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if n.length() < 1e-6:
		n = (p[2] - p[0]).cross(p[3] - p[0])
	if n.length() < 1e-6:
		return
	n = n.normalized()
	if n.dot(hint) < 0.0:
		n = -n
	_quad(st, p, PackedVector3Array([n, n, n, n]), uv, PackedColorArray([col, col, col, col]), n)


func _quad(st: SurfaceTool, p: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, c: PackedColorArray, face: Vector3) -> void:
	_tri(st, p, n, uv, c, [0, 1, 2], face)
	_tri(st, p, n, uv, c, [0, 2, 3], face)


## A triangle facing `face` (Godot draws clockwise faces: swapped if needed).
func _tri(st: SurfaceTool, p: PackedVector3Array, n: PackedVector3Array, uv: PackedVector2Array, c: PackedColorArray, idx: Array, face: Vector3) -> void:
	var nrm: Vector3 = (p[idx[1]] - p[idx[0]]).cross(p[idx[2]] - p[idx[0]])
	if nrm.length_squared() < 1e-10:
		return  # no area (mitred corners): it would break the tangents (found by Codex)
	if nrm.dot(face) > 0.0:
		idx = [idx[0], idx[2], idx[1]]
	for k: int in idx:
		st.set_normal(n[k])
		st.set_uv(uv[k])
		st.set_color(c[k])
		st.add_vertex(p[k])
	_used[st] = true
