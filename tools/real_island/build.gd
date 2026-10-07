extends SceneTree
## Builds the playable Berlenga Grande (game/world/handmade/islands/
## beach_berlenga.scn) from real data downloaded by fetch_data.py:
##   - relief: elevation tiles (about 25-30 m real resolution) smoothed with
##     a cubic resize, plus fine noise for rock detail;
##   - coast: the exact OpenStreetMap coastline; cliffs where it meets the
##     sea, gentle slopes on mapped beaches;
##   - paths, steps and the service road carved into ramps no steeper than
##     PATH_SLOPE, so the grid can walk every one of them (the real ground is
##     known only every 25-30 m: the stairs down to the fort are steeper);
##   - bridges (decks the grid walks on), buildings from their real
##     footprints, the lighthouse, the fort's pier;
##   - rocks along the cliff tops (they block), scrub (decoration);
##   - markers: the boat on the Carreiro do Mosteiro beach, generators at the
##     lighthouse, at the fort and far inland, caches spread out.
## The scene is a normal HandmadeIsland: the game picks it for Beach routes.
## Prints the time of every stage, the grid and its problems (exit code 1
## when there are any).
## Run: python tools/real_island/fetch_data.py
##      godot --headless --path . --script res://tools/real_island/build.gd

const DIR: String = "res://tools/real_island/"
const DATA: String = DIR + "data/"
const ISLANDS: String = "res://game/world/handmade/islands/"
const NAME: String = "beach_berlenga"
const TEX: String = "res://assets/textures/polyhaven/"
const KIT: String = "res://assets/models/nature_megakit/"
const DEM_STEP: int = 8  ## metres between elevation samples before the cubic resize
const CLIFF: float = 4.0  ## width of the drop from the cliff top to the sea, metres
const MARGIN: int = 24  ## metres of sea kept around the main island
## Steepest carved path, m per m. The grid blocks above 0.9, and a cell's
## height is the mean of its four corners, so the edges of a ramp need room.
const PATH_SLOPE: float = 0.55
const SHOULDER: float = 2.0  ## metres beside a path carved with it
const BLEND: float = 4.0  ## metres over which a carved path meets the natural ground
## See HandmadeIsland.horde_radius. Enemies spawn 28-45 m away; 120 steps
## (cells, along the grid) is 85-120 m.
const HORDE_RADIUS: int = 120
const WIDTHS: Dictionary = {"footway": 2.0, "path": 1.6, "steps": 2.2, "track": 3.0, "service": 4.0, "pedestrian": 3.0}

var meta: Dictionary
var N: int  ## side of the island square, metres (cells)
var lat0: float
var lon0: float
var mx: float  ## metres per degree of longitude here
var mz: float  ## metres per degree of latitude
var _off: Vector2  ## where (lat0, lon0) lands on the island square
var _h := PackedFloat32Array()
var _t := PackedFloat32Array()      ## metres from the coastline (+ land, - sea)
var _beach := PackedByteArray()
var _path_d := PackedFloat32Array() ## metres from the nearest path edge (capped)
var _rings: Array[PackedVector2Array] = []
var _beaches: Array[PackedVector2Array] = []
var _paths: Array = []              ## [PackedVector2Array, width, kind, bridge]
var _houses: Array = []             ## [PackedVector2Array, height, kind]
var _piers: Array[PackedVector2Array] = []
var _lighthouses: Array[Vector2] = []
var _village := Vector2(-1, -1)     ## centre of the fishermen's quarter
var _rng := RandomNumberGenerator.new()
var _root: HandmadeIsland
var _terrain: Node3D
var _clock: int = 0


func _initialize() -> void:
	if not FileAccess.file_exists(DATA + "meta.json"):
		print("No data: run  python tools/real_island/fetch_data.py  first.")
		quit(1)
		return
	meta = JSON.parse_string(FileAccess.get_file_as_string(DATA + "meta.json"))
	lat0 = meta["lat"]
	lon0 = meta["lon"]
	mx = 111320.0 * cos(deg_to_rad(lat0))
	mz = 110574.0
	_off = Vector2.ONE * float(meta["size"]) * 0.5
	_rng.seed = 7
	_clock = Time.get_ticks_msec()
	_read_osm()
	_crop()
	_lap("OSM read: %d coast rings, %d paths, %d buildings, %d lighthouses, %d piers; island square %d m"
		% [_rings.size(), _paths.size(), _houses.size(), _lighthouses.size(), _piers.size(), N])
	_coast_distance()
	_lap("land mask and coast distance")
	_relief()
	_lap("relief (elevation tiles + noise)")
	_carve_paths()
	_lap("paths carved")
	_root = HandmadeIsland.new()
	_root.name = "BerlengaIsland"
	_root.size = N
	_root.biome = &"beach"
	_root.horde_radius = HORDE_RADIUS
	root.add_child(_root)
	_terrain = ClassDB.instantiate(&"Terrain3D")
	_terrain.name = "Terrain3D"
	_terrain.set("region_size", 512)
	_terrain.set("vertex_spacing", 1.0)
	_terrain.set("collision_mode", 0)
	_root.add_child(_terrain)
	_terrain.owner = _root


func _process(_delta: float) -> bool:
	if _terrain == null or _terrain.get("data") == null:
		return false
	var ok: bool = _build_scene()
	_terrain = null
	quit(0 if ok else 1)
	return true


func _lap(what: String) -> void:
	var now: int = Time.get_ticks_msec()
	print("%6d ms  %s" % [now - _clock, what])
	_clock = now


# ---------------------------------------------------------------- data

func to_local(lat: float, lon: float) -> Vector2:
	return Vector2((lon - lon0) * mx + _off.x, (lat0 - lat) * mz + _off.y)


func _geom(e: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	for g: Dictionary in e.get("geometry", []):
		out.append(to_local(g["lat"], g["lon"]))
	return out


func _read_osm() -> void:
	var osm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DATA + "osm.json"))
	var coast: Array = []  # [node ids, points]
	for e: Dictionary in osm["elements"]:
		var tags: Dictionary = e.get("tags", {})
		if e["type"] == "node":
			if tags.get("man_made") == "lighthouse":
				_lighthouses.append(to_local(e["lat"], e["lon"]))
			continue
		var pts: PackedVector2Array = _geom(e)
		if pts.size() < 2:
			continue
		if tags.get("natural") == "coastline":
			coast.append([e["nodes"], pts])
		elif tags.get("natural") == "beach" and pts.size() > 3:
			_beaches.append(pts)
		elif tags.has("building"):
			var kind: String = tags["building"]
			var height: float = {"shed": 3.0, "kiosk": 3.0, "service": 3.5, "retail": 4.5}.get(kind, 5.5)
			if tags.has("building:levels"):
				height = float(tags["building:levels"]) * 3.0 + 0.5
			if tags.has("height"):
				height = float(String(tags["height"]).to_float())
			_houses.append([pts, height, kind])
			if tags.get("man_made") == "lighthouse":
				_lighthouses.append(_centroid(pts))
		elif tags.get("man_made") == "lighthouse":
			_lighthouses.append(_centroid(pts))
		elif tags.get("man_made") == "pier":
			_piers.append(pts)
		elif tags.get("landuse") == "residential" and tags.has("name"):
			_village = _centroid(pts)  # Bairro dos Pescadores
		elif tags.has("highway"):
			var kind: String = tags["highway"]
			_paths.append([pts, WIDTHS.get(kind, 2.0), kind, tags.get("bridge") == "yes"])
	# Coastline ways joined end to end into closed rings (one per island).
	var used: Array[bool] = []
	used.resize(coast.size())
	for i in coast.size():
		if used[i]:
			continue
		used[i] = true
		var ids: Array = coast[i][0].duplicate()
		var ring: PackedVector2Array = coast[i][1]
		var grew: bool = true
		while grew and ids[0] != ids[ids.size() - 1]:
			grew = false
			for j in coast.size():
				if not used[j] and coast[j][0][0] == ids[ids.size() - 1]:
					used[j] = true
					ids.append_array(coast[j][0].slice(1))
					var more: PackedVector2Array = coast[j][1]
					ring.append_array(more.slice(1))
					grew = true
		_rings.append(ring)


## The island square: the biggest coast ring (Berlenga Grande) plus MARGIN
## of sea. Everything read so far moves so that the square starts at (0, 0);
## islets outside it are dropped.
func _crop() -> void:
	var main := Rect2()
	var best: float = -1.0
	for ring in _rings:
		var area: float = absf(_area(ring))
		if area > best:
			best = area
			main = Rect2(ring[0], Vector2.ZERO)
			for p in ring:
				main = main.expand(p)
	var o := Vector2(floorf(main.position.x) - MARGIN, floorf(main.position.y) - MARGIN)
	N = ceili(maxf(main.size.x, main.size.y)) + MARGIN * 2
	_off -= o
	var square := Rect2(Vector2.ZERO, Vector2(N, N))
	var kept: Array[PackedVector2Array] = []
	for ring in _rings:
		var moved: PackedVector2Array = _moved(ring, o)
		if square.encloses(_bounds(moved)):
			kept.append(moved)
	_rings = kept
	for i in _beaches.size():
		_beaches[i] = _moved(_beaches[i], o)
	for i in _piers.size():
		_piers[i] = _moved(_piers[i], o)
	for path in _paths:
		path[0] = _moved(path[0], o)
	for b in _houses:
		b[0] = _moved(b[0], o)
	for i in _lighthouses.size():
		_lighthouses[i] -= o
	_village -= o
	_paths = _paths.filter(func(p: Array) -> bool: return square.encloses(_bounds(p[0])))
	_houses = _houses.filter(func(b: Array) -> bool: return square.encloses(_bounds(b[0])))


func _moved(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p - o)
	return out


func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


func _area(pts: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in pts.size() - 1:
		a += pts[i].x * pts[i + 1].y - pts[i + 1].x * pts[i].y
	return a * 0.5


func _centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxi(pts.size(), 1)


# ---------------------------------------------------------------- terrain

## Even-odd fill of `rings` into a vertex mask (scanline per row).
func _fill(rings: Array[PackedVector2Array]) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(N * N)
	for z in N:
		var xs: Array[float] = []
		for ring in rings:
			for i in ring.size():
				var a: Vector2 = ring[i]
				var b: Vector2 = ring[(i + 1) % ring.size()]  # closes open rings too
				if (a.y <= z) != (b.y <= z):
					xs.append(a.x + (z - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			for x in range(maxi(0, ceili(xs[k])), mini(N, floori(xs[k + 1]) + 1)):
				mask[z * N + x] = 1
	return mask


## Signed distance to the coastline (chamfer 3-4, two passes), metres.
func _coast_distance() -> void:
	var land: PackedByteArray = _fill(_rings)
	_beach = _fill(_beaches)
	var big: float = 1e6
	var d_in := PackedFloat32Array()
	var d_out := PackedFloat32Array()
	d_in.resize(N * N)
	d_out.resize(N * N)
	for i in N * N:
		d_in[i] = big if land[i] == 1 else 0.0   # land: distance to the sea
		d_out[i] = 0.0 if land[i] == 1 else big  # sea: distance to land
	_chamfer(d_in)
	_chamfer(d_out)
	_t.resize(N * N)
	for i in N * N:
		_t[i] = d_in[i] if land[i] == 1 else -d_out[i]


func _chamfer(d: PackedFloat32Array) -> void:
	var a: float = 1.0
	var b: float = 1.4142
	for z in N:
		for x in N:
			var i: int = z * N + x
			var v: float = d[i]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, d[i - 1] + a)
			if z > 0:
				v = minf(v, d[i - N] + a)
				if x > 0:
					v = minf(v, d[i - N - 1] + b)
				if x < N - 1:
					v = minf(v, d[i - N + 1] + b)
			d[i] = v
	for z in range(N - 1, -1, -1):
		for x in range(N - 1, -1, -1):
			var i: int = z * N + x
			var v: float = d[i]
			if v == 0.0:
				continue
			if x < N - 1:
				v = minf(v, d[i + 1] + a)
			if z < N - 1:
				v = minf(v, d[i + N] + a)
				if x < N - 1:
					v = minf(v, d[i + N + 1] + b)
				if x > 0:
					v = minf(v, d[i + N - 1] + b)
			d[i] = v


## Elevation (metres) at a point from the terrarium tiles, bilinear.
var _tiles: Dictionary = {}
func _elevation(lat: float, lon: float) -> float:
	var n: float = pow(2.0, int(meta["zoom"]))
	var fx: float = (lon + 180.0) / 360.0 * n * 256.0 - 0.5
	var fy: float = (1.0 - log(tan(deg_to_rad(lat)) + 1.0 / cos(deg_to_rad(lat))) / PI) / 2.0 * n * 256.0 - 0.5
	var x0: int = floori(fx)
	var y0: int = floori(fy)
	var e00: float = _pixel(x0, y0)
	var e10: float = _pixel(x0 + 1, y0)
	var e01: float = _pixel(x0, y0 + 1)
	var e11: float = _pixel(x0 + 1, y0 + 1)
	return lerpf(lerpf(e00, e10, fx - x0), lerpf(e01, e11, fx - x0), fy - y0)


func _pixel(px: int, py: int) -> float:
	var key := Vector2i(floori(px / 256.0), floori(py / 256.0))
	if not _tiles.has(key):
		var path: String = ProjectSettings.globalize_path(DATA + "dem/%d_%d_%d.png" % [meta["zoom"], key.x, key.y])
		_tiles[key] = Image.load_from_file(path) if FileAccess.file_exists(path) else null
	var t: Image = _tiles[key]
	if t == null:
		return 0.0
	var c: Color = t.get_pixel(posmod(px, 256), posmod(py, 256))
	return (roundf(c.r * 255.0) * 256.0 + roundf(c.g * 255.0) + c.b) - 32768.0


func _relief() -> void:
	# Real elevation every DEM_STEP metres, smoothed up to 1 m with a cubic resize.
	var dn: int = N / DEM_STEP + 1
	var dem := Image.create_empty(dn, dn, false, Image.FORMAT_RF)
	for j in dn:
		for i in dn:
			var lat: float = lat0 - (j * DEM_STEP - _off.y) / mz
			var lon: float = lon0 + (i * DEM_STEP - _off.x) / mx
			dem.set_pixel(i, j, Color(_elevation(lat, lon), 0, 0))
	dem.resize(dn * DEM_STEP, dn * DEM_STEP, Image.INTERPOLATE_CUBIC)
	var raw := PackedFloat32Array()
	raw.resize(N * N)
	var src: PackedByteArray = dem.get_data()
	var w: int = dem.get_width()
	for z in N:
		for x in N:
			raw[z * N + x] = src.decode_float((z * w + x) * 4)
	# Rock detail: the tiles are 25-30 m data, far smoother than real rock.
	var coarse := FastNoiseLite.new()
	coarse.seed = 11
	coarse.frequency = 0.035
	coarse.fractal_octaves = 4
	var fine := FastNoiseLite.new()
	fine.seed = 12
	fine.frequency = 0.25
	var n1: PackedByteArray = coarse.get_image(N, N, false, false, false).get_data()
	var n2: PackedByteArray = fine.get_image(N, N, false, false, false).get_data()
	_h.resize(N * N)
	for i in N * N:
		var t: float = _t[i]
		var detail: float = (n1[i] / 255.0 - 0.5) * 3.0 + (n2[i] / 255.0 - 0.5) * 0.5
		if t > 0.0:
			var top: float = maxf(raw[i], 2.0) + detail * smoothstep(CLIFF, CLIFF + 20.0, t)
			if _beach[i] == 1:
				_h[i] = minf(top, -0.6 + t * 0.3)  # beach: dry sand from 2 m off the water, 3 m high at 12 m
			else:
				_h[i] = lerpf(-1.5, top, smoothstep(0.0, CLIFF, t))  # cliff
		else:
			# Sea floor: a rocky shelf getting deeper offshore.
			_h[i] = -1.5 - minf(-t * 0.35, 20.0) + detail * 1.5


## Paths become walkable ramps. Every cell within SHOULDER of a path (not a
## bridge) is part of the corridor; its height may change at most PATH_SLOPE
## per cell inside the corridor, so the grid never sees a cliff along a path,
## junctions included. Where the real ground is steeper (the data is 25-30 m),
## the path is cut into the slope. Around the corridor the ground blends back
## to the natural height over BLEND metres.
func _carve_paths() -> void:
	_path_d.resize(N * N)
	_path_d.fill(99.0)
	for path in _paths:
		if path[3]:
			continue  # bridges are decks above the ground
		var pts: PackedVector2Array = path[0]
		var half: float = path[1] * 0.5
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var pad: float = half + SHOULDER + BLEND + 1.0
			var lo: Vector2i = Vector2i(floori(minf(a.x, b.x) - pad), floori(minf(a.y, b.y) - pad)).clamp(Vector2i.ZERO, Vector2i(N - 1, N - 1))
			var hi: Vector2i = Vector2i(ceili(maxf(a.x, b.x) + pad), ceili(maxf(a.y, b.y) + pad)).clamp(Vector2i.ZERO, Vector2i(N - 1, N - 1))
			for z in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var p := Vector2(x, z)
					var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - half
					var k: int = z * N + x
					if d < _path_d[k]:
						_path_d[k] = d
	# Corridor heights: smoothed natural ground, never under the sea. Beach
	# sand above the water joins the corridor as it is: where a path ends at a
	# beach closed in by cliffs, path and sand meet in a ramp.
	var corridor := PackedInt32Array()
	var src: PackedFloat32Array = _h.duplicate()
	for z in range(2, N - 2):
		for x in range(2, N - 2):
			var i: int = z * N + x
			if _beach[i] == 1 and _t[i] > 2.0 and _path_d[i] > SHOULDER:
				corridor.append(i)
				continue
			if _path_d[i] > SHOULDER:
				continue
			corridor.append(i)
			var s: float = 0.0
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					s += src[i + dz * N + dx]
			_h[i] = maxf(s / 25.0, 0.6)
	var inside := PackedByteArray()
	inside.resize(N * N)
	for i in corridor:
		inside[i] = 1
	# Every corridor cell may be at most PATH_SLOPE per step above any other
	# (min over the corridor of h + slope * steps): the path is cut down into
	# the slope, never raised. A cell that changes passes the change on to its
	# corridor neighbours (a queue), until nothing moves.
	var queue := corridor.duplicate()
	var queued := inside.duplicate()
	var head: int = 0
	var updates: int = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		queued[i] = 0
		for n: int in [i - 1, i + 1, i - N, i + N]:
			if inside[n] != 0 and _h[i] + PATH_SLOPE < _h[n] - 0.0001:
				_h[n] = _h[i] + PATH_SLOPE
				updates += 1
				if queued[n] == 0:
					queued[n] = 1
					queue.append(n)
	print("  corridor of %d cells, slope limited with %d updates" % [corridor.size(), updates])
	# Around the corridor: the nearest corridor height, blended into the ground.
	var near := PackedFloat32Array()
	near.resize(N * N)
	near.fill(NAN)
	queue = corridor.duplicate()
	for i in corridor:
		near[i] = _h[i]
	head = 0
	while head < queue.size():
		var i: int = queue[head]
		head += 1
		for n: int in [i - 1, i + 1, i - N, i + N]:
			if n < 0 or n >= N * N or not is_nan(near[n]) or _path_d[n] > SHOULDER + BLEND:
				continue
			near[n] = near[i]
			queue.append(n)
			var k: float = smoothstep(SHOULDER, SHOULDER + BLEND, _path_d[n])
			_h[n] = lerpf(near[n], src[n], k)


func height_at(x: float, z: float) -> float:
	var fx: float = clampf(x, 0.0, N - 1.001)
	var fz: float = clampf(z, 0.0, N - 1.001)
	var x0: int = int(fx)
	var z0: int = int(fz)
	var a: float = lerpf(_h[z0 * N + x0], _h[z0 * N + x0 + 1], fx - x0)
	var b: float = lerpf(_h[(z0 + 1) * N + x0], _h[(z0 + 1) * N + x0 + 1], fx - x0)
	return lerpf(a, b, fz - z0)


func _slope(i: int) -> float:
	var x: int = i % N
	var z: int = i / N
	if x == 0 or z == 0 or x == N - 1 or z == N - 1:
		return 0.0
	return maxf(maxf(absf(_h[i + 1] - _h[i]), absf(_h[i - 1] - _h[i])), maxf(absf(_h[i + N] - _h[i]), absf(_h[i - N] - _h[i])))


# ---------------------------------------------------------------- scene

func _build_scene() -> bool:
	_clock = Time.get_ticks_msec()
	# Terrain3D wants one more vertex than cells on each side (cell corners).
	var V: int = N + 1
	var hv := PackedFloat32Array()
	hv.resize(V * V)
	var control := PackedFloat32Array()
	control.resize(V * V)
	var color := PackedByteArray()
	color.resize(V * V * 4)
	var tint := FastNoiseLite.new()
	tint.seed = 21
	tint.frequency = 0.01
	var patch := FastNoiseLite.new()
	patch.seed = 22
	patch.frequency = 0.06
	var tints: PackedByteArray = tint.get_image(N, N).get_data()
	var patches: PackedByteArray = patch.get_image(N, N).get_data()
	# Textures: 0 ground (grass and rock), 1 cliff rock, 2 shore, 3 gravel path.
	for vz in V:
		for vx in V:
			var i: int = mini(vz, N - 1) * N + mini(vx, N - 1)
			var v: int = vz * V + vx
			hv[v] = _h[i]
			var s: float = _slope(i)
			var t: float = _t[i]
			var base: int = 0
			var over: int = 1
			var blend: float = smoothstep(0.35, 0.8, s) + (patches[i] / 255.0 - 0.5) * 0.6
			if t < 6.0 and _beach[i] == 1 or t <= 0.0:
				base = 2
				over = 1
				blend = smoothstep(0.5, 1.0, s)
			elif _path_d[i] < 0.0:
				base = 3
				blend = 0.0
			elif _path_d[i] < 1.0:
				over = 3
				blend = 1.0 - _path_d[i]
			if s > 0.9:  # walls the grid blocks: rock, never grass in streaks
				base = 1
				blend = 0.0
			var b: int = clampi(roundi(clampf(blend, 0.0, 1.0) * 255.0), 0, 255)
			control[v] = Terrain3DUtil.as_float(Terrain3DUtil.enc_base(base) | Terrain3DUtil.enc_overlay(over) | Terrain3DUtil.enc_blend(b))
			var light: float = 0.88 + tints[i] / 255.0 * 0.12  # slight light/dark variation
			color[v * 4] = int(light * 225.0)
			color[v * 4 + 1] = int(light * 250.0)  # a little greener: the scrub in spring
			color[v * 4 + 2] = int(light * 215.0)
			color[v * 4 + 3] = 255
	var height_img := Image.create_from_data(V, V, false, Image.FORMAT_RF, hv.to_byte_array())
	var control_img := Image.create_from_data(V, V, false, Image.FORMAT_RF, control.to_byte_array())
	var color_img := Image.create_from_data(V, V, false, Image.FORMAT_RGBA8, color)
	_terrain.set("assets", _ground_assets())
	var mat: Object = _terrain.get("material")
	mat.set("world_background", 0)
	mat.set("auto_shader", false)
	# Cliffs: project the textures sideways instead of stretching them down.
	mat.call("set_shader_param", "enable_projection", true)
	mat.call("set_shader_param", "projection_threshold", 0.6)
	mat.call("set_shader_param", "enable_macro_variation", true)
	var data: Object = _terrain.get("data")
	data.call("import_images", [height_img, control_img, color_img], Vector3.ZERO, 0.0, 1.0)
	var dir: String = ISLANDS + NAME + "_data"
	for f in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	DirAccess.make_dir_recursive_absolute(dir)
	data.call("save_directory", dir)
	_terrain.set("data_directory", dir)
	_lap("terrain: heights, textures per vertex, saved")
	for group in ["Buildings", "Rocks", "Bridges", "Decor", "Markers"]:
		var n := Node3D.new()
		n.name = group
		_root.add_child(n)
		n.owner = _root
	_place_paths()
	_place_bridges()
	_place_buildings()
	_lap("paths, bridges, %d buildings, lighthouse, pier" % _houses.size())
	_place_nature()
	_place_sea()
	_lap("scrub and rocks")
	var problems: Array[String] = []
	var first: IslandMap = _root.build_map(problems)
	_lap("grid (%d x %d)" % [N, N])
	_place_markers(first)
	_lap("markers")
	var packed := PackedScene.new()
	packed.pack(_root)
	# Binary: the copies of grass and rocks make a text scene far too big and slow.
	var err: int = ResourceSaver.save(packed, ISLANDS + NAME + ".scn", ResourceSaver.FLAG_COMPRESS)
	_lap("saved %s (%s)" % [ISLANDS + NAME + ".scn", error_string(err)])
	problems.clear()
	var map: IslandMap = _root.build_map(problems)
	HandmadeIsland.grid_image(map).save_png(ISLANDS + NAME + "_grid.png")
	var open: int = 0
	for b in map.field.blocked:
		open += 1 if b == 0 else 0
	map.field.max_distance = 0
	map.field.compute_now(map.field.world_to_cell(map.player_start))
	var reach: int = 0
	for d in map.field.dist:
		reach += 1 if d < FlowField.UNREACHABLE else 0
	print("%s: %d x %d m, walkable %d cells, %d reachable from the landing, %d buildings, %d rock cells" % [NAME, N, N, open, reach, map.buildings.size(), map.rocks.size()])
	var legs: PackedStringArray = []
	var stops: Array[Vector3] = [map.player_start]
	stops.append_array(map.generators)
	stops.append(map.boat)
	for k in stops.size() - 1:
		map.field.compute_now(map.field.world_to_cell(stops[k + 1]))
		legs.append(str(map.field.distance_at(stops[k])))
	print("  Activate route on the grid (landing > generators 1, 2, 3 > boat), metres per leg: %s" % ", ".join(legs))
	for k in map.generators.size():
		print("  Generator%d at (%d, %d)" % [k + 1, int(map.generators[k].x), int(map.generators[k].z)])
	_debug_picture(map)
	for p in problems:
		print("  PROBLEM: ", p)
	if problems.is_empty() and err == OK:
		print("  no problems")
	return problems.is_empty() and err == OK


## data/reach.png (not in git): where the paths are and what the grid can
## reach from the landing. Black sea, dark red cliffs, grey ground out of
## reach, green reachable, yellow paths (cliffs on a path are red).
func _debug_picture(map: IslandMap) -> void:
	var f: FlowField = map.field
	f.max_distance = 0
	f.compute_now(f.world_to_cell(map.player_start))
	var img := Image.create_empty(N, N, false, Image.FORMAT_RGB8)
	for z in N:
		for x in N:
			var i: int = z * N + x
			var c := Color(0.45, 0.45, 0.45)
			if f.blocked[i] != 0:
				c = Color.BLACK if _h[i] < 0.0 else Color(0.35, 0.1, 0.05)
			elif f.dist[i] < FlowField.UNREACHABLE:
				c = Color(0.2, 0.6, 0.25)
			if _path_d[i] < 0.0:
				c = Color(1, 0.1, 0.1) if f.blocked[i] != 0 else (Color(1, 0.9, 0.2) if f.dist[i] < FlowField.UNREACHABLE else Color(0.75, 0.6, 0.2))
			img.set_pixel(x, z, c)
	img.save_png(DATA + "reach.png")


## Terrain3D textures from the Poly Haven maps: colour + displacement (height
## for blending) and normal + roughness packed the way Terrain3D wants,
## compressed (DXT5) into assets/textures/polyhaven/.
func _ground_assets() -> Resource:
	DirAccess.make_dir_recursive_absolute(TEX)
	var assets: Object = ClassDB.instantiate(&"Terrain3DAssets")
	var names: Array = (meta["textures"] as Dictionary).keys()
	var scales: Dictionary = {"ground": 0.12, "cliff": 0.08, "shore": 0.15, "path": 0.3}
	var order: Array = ["ground", "cliff", "shore", "path"]
	for id in order.size():
		var asset: String = ""
		for n: String in names:
			if meta["textures"][n] == order[id]:
				asset = n
		var albedo: Image = Terrain3DUtil.pack_image(_tex(asset, "diffuse.jpg"), _tex(asset, "displacement.png"), false, false, false, 0)
		var normal: Image = Terrain3DUtil.pack_image(_tex(asset, "nor_gl.jpg"), _tex(asset, "rough.jpg"), false, false, false, 0)
		var ta: Object = ClassDB.instantiate(&"Terrain3DTextureAsset")
		ta.set("name", order[id])
		ta.set("id", id)
		ta.set("albedo_texture", _texture(albedo, "%s_albedo_height" % asset))
		ta.set("normal_texture", _texture(normal, "%s_normal_rough" % asset))
		ta.set("uv_scale", scales[order[id]])
		ta.set("detiling_rotation", 0.3)
		assets.call("set_texture", id, ta)
	var path: String = ISLANDS + NAME + "_ground.res"
	ResourceSaver.save(assets, path)
	return load(path)


func _tex(asset: String, file: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(DATA + "textures/%s_%s" % [asset, file]))
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != 1024:
		img.resize(1024, 1024)
	return img


func _texture(img: Image, name: String) -> Texture2D:
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	if img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC) != OK:
		print("  %s: not compressed (stays RGBA8)" % name)
	var path: String = TEX + name + ".res"
	ResourceSaver.save(ImageTexture.create_from_image(img), path)
	return load(path)


func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _add(n: Node, group: String) -> void:
	_root.get_node(group).add_child(n)
	n.owner = _root


## A triangle facing `n` (Godot draws clockwise faces: swap if needed).
func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tmp: Vector3 = b
		b = c
		c = tmp
	for v: Vector3 in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


## Stone steps and the concrete service road as meshes on the carved ground
## (gravel paths are only the terrain texture). Decoration: the grid reads
## the ground under them.
func _place_paths() -> void:
	var stone := SurfaceTool.new()
	var road := SurfaceTool.new()
	for st: SurfaceTool in [stone, road]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path in _paths:
		if path[3]:
			continue
		if path[2] == "steps":
			_ribbon(stone, path[0], path[1], 0.06)
		elif path[2] == "service":
			_ribbon(road, path[0], path[1], 0.05)
	for item in [[stone, "Steps", Color(0.62, 0.6, 0.56)], [road, "Road", Color(0.58, 0.56, 0.52)]]:
		var mesh: ArrayMesh = (item[0] as SurfaceTool).commit()
		if mesh.get_surface_count() == 0:
			continue
		var inst := MeshInstance3D.new()
		inst.name = item[1]
		inst.mesh = mesh
		inst.material_override = _mat(item[2])
		_add(inst, "Decor")


## Strip draped on the ground every metre.
func _ribbon(st: SurfaceTool, pts: PackedVector2Array, w: float, lift: float) -> void:
	var prev := PackedVector3Array()
	var samples := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var n: int = maxi(1, ceili(pts[i].distance_to(pts[i + 1])))
		for k in range(1, n + 1):
			samples.append(pts[i].lerp(pts[i + 1], float(k) / n))
	for k in samples.size():
		var t: Vector2 = (samples[mini(k + 1, samples.size() - 1)] - samples[maxi(k - 1, 0)]).normalized()
		var side := Vector2(-t.y, t.x) * w * 0.5
		var row := PackedVector3Array()
		for q: Vector2 in [samples[k] - side, samples[k], samples[k] + side]:
			row.append(Vector3(q.x, height_at(q.x, q.y) + lift, q.y))
		if not prev.is_empty():
			for j in 2:
				_tri(st, prev[j], prev[j + 1], row[j + 1], Vector3.UP)
				_tri(st, prev[j], row[j + 1], row[j], Vector3.UP)
		prev = row


## Stone bridges: one deck per straight span (HandmadeIsland walks the grid
## over Bridges/ at the deck's top), from the path height at one end to the
## other, with low parapets as decoration.
func _place_bridges() -> void:
	var deck_mat: StandardMaterial3D = _mat(Color(0.55, 0.52, 0.47))
	var count: int = 0
	for path in _paths:
		if not path[3]:
			continue
		var pts: PackedVector2Array = path[0]
		var w: float = path[1] + 0.6
		for i in pts.size() - 1:
			# The deck lands 2 m onto each bank, at the ground's height there:
			# the bank's edge is a cliff the grid would not let you step onto,
			# and a deck that only continued its slope would end below the
			# bank on one side and in the water on the other.
			var dir2: Vector2 = (pts[i + 1] - pts[i]).normalized()
			var pa: Vector2 = pts[i] - dir2 * 2.0
			var pb: Vector2 = pts[i + 1] + dir2 * 2.0
			var a := Vector3(pa.x, maxf(height_at(pa.x, pa.y), 0.6), pa.y)
			var b := Vector3(pb.x, maxf(height_at(pb.x, pb.y), 0.6), pb.y)
			var length: float = a.distance_to(b)
			var deck := MeshInstance3D.new()
			deck.name = "Bridge_%d" % count
			count += 1
			var box := BoxMesh.new()
			box.size = Vector3(w, 0.5, length)
			deck.mesh = box
			deck.material_override = deck_mat
			var forward: Vector3 = (b - a).normalized()
			var basis := Basis.looking_at(forward, Vector3.UP)
			deck.transform = Transform3D(basis, (a + b) * 0.5 - basis.y * 0.25)  # top face through both ends
			_add(deck, "Bridges")
			for side: float in [-1.0, 1.0]:
				var rail := MeshInstance3D.new()
				var rb := BoxMesh.new()
				rb.size = Vector3(0.3, 0.9, length)
				rail.mesh = rb
				rail.material_override = deck_mat
				rail.position = Vector3(side * (w * 0.5 - 0.15), 0.7, 0.0)
				deck.add_child(rail)
				rail.owner = _root


## Buildings from their real footprints, one node each (the grid blocks
## their footprint): whitewashed walls from below the lowest ground up to the
## eaves and a tiled hip roof (a fan to the centre).
func _place_buildings() -> void:
	var wall_mat: StandardMaterial3D = _mat(Color(0.93, 0.92, 0.88), 0.85)
	var roof_mat: StandardMaterial3D = _mat(Color(0.72, 0.34, 0.22), 0.85)
	for k in _houses.size():
		var pts: PackedVector2Array = _houses[k][0]
		if pts.size() > 1 and pts[0].distance_to(pts[pts.size() - 1]) < 0.01:
			pts = pts.slice(0, pts.size() - 1)
		if pts.size() < 3:
			continue
		var lo: float = INF
		var hi: float = -INF
		for p in pts:
			lo = minf(lo, height_at(p.x, p.y))
			hi = maxf(hi, height_at(p.x, p.y))
		var c: Vector2 = _centroid(pts)
		var base: float = lo - 0.5
		var eaves: float = hi + float(_houses[k][1])
		var walls := SurfaceTool.new()
		var roof := SurfaceTool.new()
		walls.begin(Mesh.PRIMITIVE_TRIANGLES)
		roof.begin(Mesh.PRIMITIVE_TRIANGLES)
		var shortest: float = INF
		for i in pts.size():
			var a: Vector2 = pts[i] - c
			var e: Vector2 = pts[(i + 1) % pts.size()] - c
			shortest = minf(shortest, a.distance_to(e))
			var out := Vector3((e - a).y, 0, -(e - a).x).normalized()
			if out.dot(Vector3(a.x, 0, a.y)) < 0.0:
				out = -out
			_tri(walls, Vector3(a.x, base, a.y), Vector3(e.x, base, e.y), Vector3(e.x, eaves, e.y), out)
			_tri(walls, Vector3(a.x, base, a.y), Vector3(e.x, eaves, e.y), Vector3(a.x, eaves, a.y), out)
		var ridge := Vector3(0, eaves + clampf(shortest * 0.35, 1.0, 2.5), 0)
		for i in pts.size():
			var a := Vector3(pts[i].x - c.x, eaves, pts[i].y - c.y)
			var e := Vector3(pts[(i + 1) % pts.size()].x - c.x, eaves, pts[(i + 1) % pts.size()].y - c.y)
			var n: Vector3 = (e - a).cross(ridge - a).normalized()
			if n.y < 0.0:
				n = -n
			_tri(roof, a, e, ridge, n)
		var mesh: ArrayMesh = walls.commit()
		roof.commit(mesh)
		mesh.surface_set_material(0, wall_mat)
		mesh.surface_set_material(1, roof_mat)
		var inst := MeshInstance3D.new()
		inst.name = "House_%d" % k
		inst.mesh = mesh
		inst.position = Vector3(c.x, 0, c.y)
		_add(inst, "Buildings")
	for k in _lighthouses.size():
		_lighthouse(_lighthouses[k], k)
	for k in _piers.size():
		_pier(_piers[k], k)


func _lighthouse(p: Vector2, k: int) -> void:
	var node := Node3D.new()
	node.name = "Lighthouse_%d" % k
	node.position = Vector3(p.x, height_at(p.x, p.y) - 0.5, p.y)
	_add(node, "Buildings")
	var parts: Array = [
		[BoxMesh.new(), Vector3(4.5, 18.0, 4.5), Vector3(0, 9.0, 0), Color(0.95, 0.94, 0.9)],
		[CylinderMesh.new(), Vector3(2.0, 3.0, 2.0), Vector3(0, 19.5, 0), Color(0.15, 0.17, 0.2)],
		[CylinderMesh.new(), Vector3(2.4, 1.2, 2.4), Vector3(0, 21.6, 0), Color(0.7, 0.15, 0.12)],
	]
	for part in parts:
		var mi := MeshInstance3D.new()
		var mesh: PrimitiveMesh = part[0]
		if mesh is BoxMesh:
			(mesh as BoxMesh).size = part[1]
		else:
			(mesh as CylinderMesh).top_radius = part[1].x * 0.5
			(mesh as CylinderMesh).bottom_radius = part[1].x * 0.5
			(mesh as CylinderMesh).height = part[1].y
		mi.mesh = mesh
		mi.position = part[2]
		mi.material_override = _mat(part[3], 0.6)
		node.add_child(mi)
		mi.owner = _root


## The pier at the fort: over the water, so decoration (not walkable).
func _pier(pts: PackedVector2Array, k: int) -> void:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mi := MeshInstance3D.new()
		mi.name = "Pier_%d_%d" % [k, i]
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 2.5, a.distance_to(b) + 2.0)
		mi.mesh = bm
		mi.material_override = _mat(Color(0.6, 0.58, 0.54))
		var dir := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
		mi.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3((a.x + b.x) * 0.5, 0.3, (a.y + b.y) * 0.5))
		_add(mi, "Decor")


func _kit_mesh(model: String) -> Mesh:
	var scene: Node = (load(KIT + model + ".gltf") as PackedScene).instantiate()
	var found: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	scene.free()
	return m


## Low scrub on the plateau (Decor) and rocks on the cliff tops (Rocks: they
## block), as Scatter nodes in 128 m chunks that are drawn only near the
## camera: drawing every tuft of the island every frame costs far too much.
func _place_nature() -> void:
	var rings: Array[PackedVector2Array] = []
	for b in _houses:
		var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(b[0], 2.0)
		rings.append(grown[0] if not grown.is_empty() else b[0])
	var near_house: PackedByteArray = _fill(rings)
	# [model, count, height m, min metres from the coast, drawn up to m]
	var specs: Array = [["Grass_Wispy_Short", 110000, 0.35, 6.0, 140.0], ["Grass_Common_Short", 55000, 0.3, 6.0, 120.0],
		["Grass_Wispy_Tall", 14000, 0.7, 6.0, 220.0], ["Bush_Common", 600, 0.9, 10.0, 400.0],
		["Rock_Medium_1", 450, 2.0, 2.0, 1500.0], ["Rock_Medium_2", 350, 1.5, 2.0, 1500.0]]
	var near_light: Array[Vector2] = _lighthouses.duplicate()
	for spec in specs:
		var mesh: Mesh = _kit_mesh(spec[0])
		if mesh == null:
			continue
		var rock: bool = String(spec[0]).begins_with("Rock")
		var target: float = spec[2]
		var tries: int = 0
		var made: int = 0
		var chunks: Dictionary = {}
		while made < spec[1] and tries < spec[1] * 20:
			tries += 1
			var x: int = _rng.randi_range(2, N - 3)
			var z: int = _rng.randi_range(2, N - 3)
			var i: int = z * N + x
			var t: float = _t[i]
			if t < spec[3] or near_house[i] == 1 or _beach[i] == 1:
				continue
			if _path_d[i] < (SHOULDER + BLEND + 1.0 if rock else 0.6):
				continue  # rocks keep paths and their ramps clear
			if rock and (t > 25.0 or _slope(i) < 0.25):
				continue  # rocks along the cliff tops
			if not rock and _slope(i) > 0.55:
				continue
			if rock and near_light.any(func(l: Vector2) -> bool: return l.distance_to(Vector2(x, z)) < 30.0):
				continue
			var p := Vector2(x + _rng.randf(), z + _rng.randf())
			var s: float = target / maxf(mesh.get_aabb().size.y, 0.01) * _rng.randf_range(0.6, 1.4)
			var y: float = height_at(p.x, p.y) - (0.4 * s if rock else 0.05)
			var key := Vector2i(floori(p.x / 128.0), floori(p.y / 128.0))
			if not chunks.has(key):
				chunks[key] = PackedFloat32Array()
			# Relative to the chunk centre: the draw distance is measured from the node.
			var o := Vector2(key.x * 128.0 + 64.0, key.y * 128.0 + 64.0)
			# Packed arrays are copied when read from a Dictionary: write it back.
			var arr: PackedFloat32Array = chunks[key]
			arr.append_array([p.x - o.x, y, p.y - o.y, _rng.randf() * TAU, s])
			chunks[key] = arr
			made += 1
		var group := Node3D.new()  # grass: one folder per model in Decor/
		group.name = spec[0]
		if not rock:
			_add(group, "Decor")
		for key: Vector2i in chunks:
			var inst := Scatter.new()
			inst.name = "%s_%d_%d" % [spec[0], key.x, key.y]
			inst.position = Vector3(key.x * 128.0 + 64.0, 0.0, key.y * 128.0 + 64.0)
			inst.mesh = mesh
			inst.data = chunks[key]
			inst.visibility_range_end = spec[4] + 90.0  # + half a chunk diagonal
			inst.visibility_range_end_margin = 20.0
			inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if not rock:
				inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if rock:
				_add(inst, "Rocks")  # Rocks/ children block: one Scatter per chunk
			else:
				group.add_child(inst)
				inst.owner = _root
		if rock:
			group.free()  # never added to the scene


## A flat sea for the editor only (the game draws its own animated sea).
func _place_sea() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "SeaPreview"
	var plane := PlaneMesh.new()
	plane.size = Vector2(N * 2, N * 2)
	sea.mesh = plane
	sea.position = Vector3(N * 0.5, -0.3, N * 0.5)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.06, 0.22, 0.3, 0.88)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = water
	_add(sea, "Decor")


# ---------------------------------------------------------------- markers

## Markers on the grid the game will use (`map`, built without markers):
## the boat on the beach, the generators at real landmarks, the caches as far
## from everything as possible. Every spot is walkable, clear around and
## reachable from the landing.
func _place_markers(map: IslandMap) -> void:
	var f: FlowField = map.field
	f.max_distance = 0
	# The island's walkable heart: everything reachable from the lighthouse.
	var light: Vector2 = _lighthouses[0] if not _lighthouses.is_empty() else Vector2(N * 0.5, N * 0.5)
	f.compute_now(_nearest_clear(f, Vector2i(light), 40))
	var heart: PackedInt32Array = f.dist.duplicate()
	# Landing: the shore cell (2-8 m from the water, dry, connected to the
	# heart) nearest the middle of the biggest beach, the Carreiro do Mosteiro
	# (its sand is closed in by cliffs: the nearest connected shore is the
	# harbour). The boat lies out to sea from there.
	var beach := PackedVector2Array([Vector2(N * 0.5, N * 0.5)])
	for b in _beaches:
		if beach.size() < 3 or absf(_area(b)) > absf(_area(beach)):
			beach = b
	var mid: Vector2 = _centroid(beach)
	var landing := Vector2i(-1, -1)
	var best: float = INF
	for z in range(int(mid.y) - 250, int(mid.y) + 250):
		for x in range(int(mid.x) - 250, int(mid.x) + 250):
			if x < 2 or z < 2 or x >= N - 2 or z >= N - 2:
				continue
			var i: int = z * N + x
			# Sand first: any other shore counts 100 m further away.
			var d: float = mid.distance_to(Vector2(x, z)) + (0.0 if _beach[i] == 1 else 100.0)
			if d < best and _t[i] >= 2.0 and _t[i] <= 8.0 and _h[i] > 0.2 and heart[i] < FlowField.UNREACHABLE and _clear(f, Vector2i(x, z)):
				best = d
				landing = Vector2i(x, z)
	print("  landing at (%d, %d) %s, %.1f m high" % [landing.x, landing.y, "on the beach" if best < 100.0 else "beside the beach", _h[landing.y * N + landing.x]])
	var seaward := Vector2(_t[landing.y * N + landing.x - 1] - _t[landing.y * N + landing.x + 1],
		_t[(landing.y - 1) * N + landing.x] - _t[(landing.y + 1) * N + landing.x]).normalized()
	var boat := Vector3(landing.x + 0.5, 0, landing.y + 0.5)
	_marker("Boat", boat, Vector3(seaward.x, 0, seaward.y))
	var start: Vector2i = _nearest_clear(f, landing - Vector2i(roundi(seaward.x * 6.0), roundi(seaward.y * 6.0)), 10)
	_marker("PlayerStart", Vector3(start.x + 0.5, 0, start.y + 0.5))
	f.compute_now(start)
	var reach: PackedInt32Array = f.dist.duplicate()
	var goals: Array[Vector2] = [Vector2(landing)]
	# Generators at three real places: 1 the fishermen's quarter (Bairro dos
	# Pescadores), 2 beside the lighthouse, 3 the fort's islet (at the end of
	# the Caminho do Forte steps and bridges). The caches go to the far ends
	# of the island: optional detours.
	var fort: Vector2 = _fort_islet()
	var village: Vector2 = _village if _village.x >= 0.0 else light
	var gens: Array[Vector2] = [
		_reachable_near(f, reach, village, 8.0, 40.0),
		_reachable_near(f, reach, light, 10.0, 40.0),
		_reachable_near(f, reach, fort, 0.0, 60.0),
	]
	for k in gens.size():
		_marker("Generator%d" % (k + 1), Vector3(gens[k].x + 0.5, 0, gens[k].y + 0.5))
		goals.append(gens[k])
	for k in 6:
		var c: Vector2 = _farthest(f, reach, goals, 120, 1200, 12.0)
		_marker("Cache%d" % (k + 1), Vector3(c.x + 0.5, 0, c.y + 0.5))
		goals.append(c)


func _marker(name: String, p: Vector3, out: Vector3 = Vector3.ZERO) -> void:
	var mk := Marker3D.new()
	mk.name = name
	mk.gizmo_extents = 3.0
	mk.position = Vector3(p.x, height_at(p.x, p.z), p.z)
	if out != Vector3.ZERO:
		mk.basis = Basis.looking_at(-out, Vector3.UP)  # +Z points out to the boat
	_add(mk, "Markers")


## Every cell within `r` metres is walkable (r 4: a generator's 3.5 m ring
## fits, with no wall or rock inside it).
func _clear(f: FlowField, c: Vector2i, r: int = 2) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dz * dz <= r * r and f.is_blocked(c.x + dx, c.y + dz):
				return false
	return true


func _nearest_clear(f: FlowField, c: Vector2i, r: int) -> Vector2i:
	var best := c
	var bd: float = INF
	for z in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var d: float = Vector2(c).distance_to(Vector2(x, z))
			if d < bd and _clear(f, Vector2i(x, z)):
				bd = d
				best = Vector2i(x, z)
	return best


## Clear, reachable cell nearest to `p`, between r_min and r_max metres away.
func _reachable_near(f: FlowField, reach: PackedInt32Array, p: Vector2, r_min: float, r_max: float) -> Vector2:
	var best := p
	var bd: float = INF
	for z in range(int(p.y - r_max), int(p.y + r_max) + 1):
		for x in range(int(p.x - r_max), int(p.x + r_max) + 1):
			if x < 2 or z < 2 or x >= N - 2 or z >= N - 2:
				continue
			var d: float = p.distance_to(Vector2(x, z))
			if d < r_min or d > r_max or d >= bd or reach[z * N + x] >= FlowField.UNREACHABLE:
				continue
			if _clear(f, Vector2i(x, z), 4):
				bd = d
				best = Vector2(x, z)
	if bd == INF:
		print("  WARNING: nothing reachable near (%d, %d)" % [int(p.x), int(p.y)])
	return best


## Clear, reachable inland cell between min_walk and max_walk metres on foot
## from the landing, as far as possible from every point in `away`.
func _farthest(f: FlowField, reach: PackedInt32Array, away: Array[Vector2], min_walk: int, max_walk: int, inland: float) -> Vector2:
	var best := Vector2.ZERO
	var bd: float = -1.0
	for z in range(4, N - 4, 3):
		for x in range(4, N - 4, 3):
			var i: int = z * N + x
			var walk: int = reach[i]
			if walk < min_walk or walk > max_walk or _t[i] < inland:
				continue
			var d: float = INF
			for a in away:
				d = minf(d, a.distance_to(Vector2(x, z)))
			if d > bd and _clear(f, Vector2i(x, z), 3):
				bd = d
				best = Vector2(x, z)
	return best


## Centre of the fort's islet: the ring that the last bridge of the Caminho
## do Forte lands on (the bridge end furthest from the main island).
func _fort_islet() -> Vector2:
	var main_i: int = 0
	for k in _rings.size():
		if absf(_area(_rings[k])) > absf(_area(_rings[main_i])):
			main_i = k
	var best := Vector2(N * 0.5, N * 0.5)
	var bd: float = INF
	for path in _paths:
		if not path[3]:
			continue
		for p: Vector2 in path[0]:
			for k in _rings.size():
				if k == main_i or absf(_area(_rings[k])) < 1000.0:
					continue
				if Geometry2D.is_point_in_polygon(p, _rings[k]) or _dist_to_ring(p, _rings[k]) < 4.0:
					var c: Vector2 = _centroid(_rings[k])
					var d: float = p.distance_to(c)
					if d < bd:
						bd = d
						best = c
	return best


func _dist_to_ring(p: Vector2, ring: PackedVector2Array) -> float:
	var d: float = INF
	for i in ring.size() - 1:
		d = minf(d, p.distance_to(Geometry2D.get_closest_point_to_segment(p, ring[i], ring[i + 1])))
	return d
