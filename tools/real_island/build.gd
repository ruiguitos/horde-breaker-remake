extends SceneTree
## Builds a playable island (game/world/handmade/islands/<biome>_<place>.scn)
## from the real data fetch_data.py downloaded for a place (PLACES below):
##   - relief: elevation tiles (about 25-30 m real resolution) smoothed with
##     a cubic resize, plus noise for rock detail (little on concrete);
##   - coast: the exact OpenStreetMap coastline; cliffs (or a sea wall)
##     where it meets the sea, gentle slopes on mapped beaches;
##   - paths, steps and roads carved into ramps no steeper than PATH_SLOPE,
##     so the grid can walk every one of them (the real ground is known only
##     every 25-30 m);
##   - bridges (decks the grid walks on), buildings from their real
##     footprints and heights in the place's style, lighthouse, piers;
##   - scatter (rocks or rubble that block, grass and scrub that do not);
##   - markers: the boat at the landing, generators at real landmarks,
##     caches spread out.
## The scene is a normal HandmadeIsland: the game picks it for its biome.
## Prints the time of every stage, the grid and its problems (exit code 1
## when there are any).
## Run: python tools/real_island/fetch_data.py <place>
##      godot --headless --path . --script res://tools/real_island/build.gd -- <place> [--out-dir <res://dir/>] [--kits houses,paths,landmarks]
## (place: berlenga, hashima; default berlenga). --out-dir writes a test
## build somewhere else than the game's islands (e.g. a gitignored folder).

const DIR: String = "res://tools/real_island/"
const TEX: String = "res://assets/textures/polyhaven/"
const KIT: String = "res://assets/models/nature_megakit/"
const DEM_STEP: int = 8  ## metres between elevation samples before the cubic resize
const CLIFF: float = 4.0  ## width of the drop from the cliff top to the sea, metres
const MARGIN: int = 24  ## metres of sea kept around the main island
const SEA: float = -0.3  ## HandmadeIsland.sea_level
## Steepest carved path, m per m. The grid blocks above 0.9, and a cell's
## height is the mean of its four corners, so the edges of a ramp need room.
const PATH_SLOPE: float = 0.55
const SHOULDER: float = 2.0  ## metres beside a path carved with it
const BLEND: float = 4.0  ## metres over which a carved path meets the natural ground
const LIGHTHOUSE_HEIGHT: float = 22.0  ## a lighthouse mapped as a point, without a height
const WIDTHS: Dictionary = {"footway": 2.0, "path": 1.6, "steps": 2.2, "track": 3.0, "service": 4.0, "pedestrian": 3.0}

## What differs between places. Scatter rows: [Quaternius model, count,
## height m, min metres from the coast, drawn up to m, where]; where = land
## (anywhere gentle), cliff_top (rocks along the cliffs), green (inside the
## OSM grass and scrub areas) or rubble (beside buildings). Rock models
## block (Rocks/), the rest is decoration. outcrop = small groups of rocks on
## gentle ground far from the coast (see _outcrops). Generators: [kind, name]; kind =
## named (an OSM feature with that name), landuse (the named residential
## area), lighthouse or fort (the islet the last bridge reaches).
const PLACES: Dictionary = {
	"berlenga": {
		"out": "beach_berlenga", "biome": &"beach",
		# See HandmadeIsland.horde_radius. Enemies spawn 28-45 m away; 120
		# steps (cells, along the grid) is 85-120 m.
		"horde_radius": 120,
		"land_min": 2.0, "detail": 3.0, "tint": Color(0.88, 0.98, 0.84),
		# Cliffs from 4 to 16 m wide, from the real ground behind them (see
		# _cliff_widths); 4 m everywhere when absent.
		"cliff_width": [4.0, 16.0],
		"roof": "hip", "walls": Color(0.93, 0.92, 0.88), "roof_color": Color(0.72, 0.34, 0.22), "house_height": 5.5,
		"landing": "beach",
		"generators": [["landuse", ""], ["lighthouse", ""], ["fort", ""]],
		"caches": 6, "cache_walk": 1200,
		# Detail kits (village_houses.gd, village_paths.gd, landmarks.gd)
		# inside this rectangle (island metres). The first test covered only
		# the landing and the Bairro dos Pescadores: Rect2(830, 560, 260, 230).
		"detail_area": Rect2(0, 0, 4096, 4096),
		"scatter": [["Grass_Wispy_Short", 110000, 0.35, 6.0, 140.0, "land"], ["Grass_Common_Short", 55000, 0.3, 6.0, 120.0, "land"],
			["Grass_Wispy_Tall", 14000, 0.7, 6.0, 220.0, "land"], ["Bush_Common", 600, 0.9, 10.0, 400.0, "land"],
			["Rock_Medium_1", 450, 2.0, 2.0, 1500.0, "cliff_top"], ["Rock_Medium_2", 350, 1.5, 2.0, 1500.0, "cliff_top"],
			# Last, so the rows above keep their copies: granite outcrops on
			# the plateau (Codex's design), small and partly buried.
			["Rock_Medium_1", 160, 0.9, 25.0, 1500.0, "outcrop"], ["Rock_Medium_2", 120, 0.6, 25.0, 1500.0, "outcrop"]],
	},
	"hashima": {
		"out": "port_hashima", "biome": &"port",
		"horde_radius": 0,  # 0.5 km: the whole island
		# Reclaimed land behind a sea wall, with the old rock in the middle.
		"land_min": 5.0, "detail": 0.4, "tint": Color(0.92, 0.92, 0.9),
		"terrace": [17.0, 0.4],  # rock above 17 m; lower land flattened to 40 %
		# OSM features with their own model instead of a building box.
		"special": {"端島神社": "shrine", "ベルトコンベアー": "conveyor"},
		"roof": "flat", "walls": Color(0.78, 0.77, 0.73), "roof_color": Color(0.38, 0.38, 0.37), "house_height": 9.0,
		"landing": "pier", "parapet": true,
		"generators": [["named", "第二坑捲"], ["named", "65号棟"], ["named", "四坑上家"]],  # pit 2 (mine), block 65, pit 4
		"caches": 4, "cache_walk": 600,
		# Level design read from the real layout with Codex (island metres).
		# No choke at the pier: closing any 4 m disc 9-30 m from the landing
		# leaves the boat reachable (272 tried), so the landing has two ways.
		"chokes": {"FiftySteps": Vector2(254, 149), "WestSteps": Vector2(225, 156), "BlockAlleys": Vector2(210, 180),
			"MineSteps": Vector2(197, 286)},
		"arenas": {"NorthEast": Vector2(330, 95), "EastTerrace": Vector2(310, 255), "South": Vector2(65, 400)},
		"scatter": [["Grass_Wispy_Short", 7000, 0.35, 3.0, 120.0, "green"], ["Grass_Common_Short", 3000, 0.3, 3.0, 100.0, "green"],
			["Grass_Wispy_Tall", 1500, 0.7, 3.0, 160.0, "green"], ["Fern_1", 400, 0.8, 4.0, 200.0, "green"],
			["Plant_1", 300, 0.6, 3.0, 160.0, "green"],
			# Fallen concrete: angular blocks rather than round rocks.
			["Pebble_Square_4", 160, 0.8, 3.0, 400.0, "rubble"], ["Pebble_Square_5", 140, 0.6, 3.0, 400.0, "rubble"]],
	},
}

var P: Dictionary  ## this place's settings (PLACES)
var DATA: String
var NAME: String
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
var _paths: Array = []              ## [PackedVector2Array, width, kind, bridge, all tags + osm_id]
var _houses: Array = []             ## [PackedVector2Array, height, kind, roof:shape, name, all tags + osm_id]
var _piers: Array[PackedVector2Array] = []
var _lighthouses: Array[Vector2] = []
var _light_heights: Array[float] = []  ## metres, one per lighthouse
var _plazas: Array[PackedVector2Array] = []  ## paved squares (highway + area=yes)
var _village := Vector2(-1, -1)     ## centre of the named residential area
var _named: Dictionary = {}         ## OSM name -> centre
var _green: Array[PackedVector2Array] = []  ## grass and scrub areas
var _walls: Array[PackedVector2Array] = []  ## sea walls (retaining walls)
var _rng := RandomNumberGenerator.new()
var ISLANDS: String = "res://game/world/handmade/islands/"  ## where the island is saved (--out-dir)
const TEST_OUT: String = "res://tools/real_island/test_out/"  ## the only place --out-dir may write
var _kits: PackedStringArray = ["houses", "paths", "landmarks"]  ## --kits
var _house_kit: RefCounted  ## village_houses.gd, when the place has a detail_area
var _path_kit: RefCounted   ## village_paths.gd, idem
var _landmark_kit: RefCounted  ## landmarks.gd (lighthouse, fort), idem
var _reserved: Array[PackedVector2Array] = []  ## footprints kits add (fort walls...): no scatter there
var _materials: Dictionary = {}  ## texture role -> material (_role_material)
var _root: HandmadeIsland
var _terrain: Node3D
var _clock: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var key: String = "berlenga"
	# Every option checked before anything is written (found by Codex): a
	# test build must never land on the game's islands by mistake.
	var i: int = 0
	while i < args.size():
		var arg: String = args[i]
		var value: String = args[i + 1] if i + 1 < args.size() else ""
		if arg == "--out-dir":
			var dir: String = value.simplify_path().trim_suffix("/") + "/"
			if not dir.begins_with(TEST_OUT) or dir == TEST_OUT or ".." in value:
				print("--out-dir must be a folder inside %s (got '%s')" % [TEST_OUT, value])
				quit(1)
				return
			ISLANDS = dir
			i += 2
		elif arg == "--kits":
			_kits = value.split(",", false)
			for kit in _kits:
				if kit not in ["houses", "paths", "landmarks", "none"]:
					print("--kits takes houses, paths, landmarks or none, comma-separated (got '%s')" % value)
					quit(1)
					return
			i += 2
		elif arg.begins_with("--"):
			print("Unknown option ", arg)
			quit(1)
			return
		else:
			key = arg
			i += 1
	if not PLACES.has(key):
		print("Unknown place %s (known: %s)" % [key, ", ".join(PLACES.keys())])
		quit(1)
		return
	P = PLACES[key]
	NAME = P["out"]
	DATA = DIR + "data/" + key + "/"
	if ISLANDS.begins_with(TEST_OUT):
		DirAccess.make_dir_recursive_absolute(ISLANDS)
	if not FileAccess.file_exists(DATA + "meta.json"):
		print("No data: run  python tools/real_island/fetch_data.py %s  first." % key)
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
	_root.name = String(meta["key"]).capitalize() + "Island"
	_root.size = N
	_root.biome = P["biome"]
	_root.horde_radius = P["horde_radius"]
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
				_light_heights.append(String(tags["height"]).to_float() if tags.has("height") else LIGHTHOUSE_HEIGHT)
			if tags.has("name"):
				_named[tags["name"]] = to_local(e["lat"], e["lon"])
			continue
		var pts: PackedVector2Array = _geom(e)
		if pts.size() < 2:
			continue
		if tags.has("name") and tags.get("natural") != "coastline":
			_named[tags["name"]] = _centroid(pts)
		if tags.get("natural") in ["grassland", "scrub", "wood", "heath"] and pts.size() > 3:
			_green.append(pts)
		elif tags.get("barrier") == "retaining_wall" or tags.get("man_made") == "breakwater":
			_walls.append(pts)
		elif tags.get("natural") == "coastline":
			coast.append([e["nodes"], pts])
		elif tags.get("natural") == "beach" and pts.size() > 3:
			_beaches.append(pts)
		elif tags.get("man_made") == "lighthouse":  # a lighthouse building: one tower, its real height
			_lighthouses.append(_centroid(pts))
			_light_heights.append(String(tags.get("height", "18")).to_float())
		elif tags.has("highway") and tags.get("area") == "yes" and pts.size() > 3:
			_plazas.append(pts)  # a paved square, not a line to walk along its edge
		elif tags.has("building"):
			var kind: String = tags["building"]
			var height: float = {"shed": 3.0, "kiosk": 3.0, "service": 3.5, "retail": 4.5}.get(kind, float(P["house_height"]))
			if tags.has("building:levels"):
				height = float(tags["building:levels"]) * 3.0 + 0.5
			if tags.has("height"):
				height = float(String(tags["height"]).to_float())
			tags = tags.duplicate()
			tags["osm_id"] = int(e["id"])
			_houses.append([pts, height, kind, tags.get("roof:shape", ""), tags.get("name", ""), tags])
		elif tags.get("man_made") == "pier":
			_piers.append(pts)
		elif tags.get("landuse") == "residential" and tags.has("name"):
			_village = _centroid(pts)  # Bairro dos Pescadores
		elif tags.has("highway"):
			var kind: String = tags["highway"]
			tags = tags.duplicate()
			tags["osm_id"] = int(e["id"])
			_paths.append([pts, WIDTHS.get(kind, 2.0), kind, tags.get("bridge") == "yes", tags])
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
	for k: String in _named:
		_named[k] -= o
	for i in _green.size():
		_green[i] = _moved(_green[i], o)
	for i in _plazas.size():
		_plazas[i] = _moved(_plazas[i], o)
	for i in _walls.size():
		_walls[i] = _moved(_walls[i], o)
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

## Union of `rings` as a vertex mask: each ring filled on its own (even-odd
## scanline per row), then added. Filling all rings together with even-odd
## would cut a hole where two overlap, e.g. the margins around two
## neighbouring buildings (found by Codex).
func _fill(rings: Array[PackedVector2Array]) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(N * N)
	for ring in rings:
		if ring.size() < 3:
			continue
		var box: Rect2 = _bounds(ring)
		for z in range(maxi(0, floori(box.position.y)), mini(N, ceili(box.end.y) + 1)):
			var xs: Array[float] = []
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
	var coarse_dem: Image = dem.duplicate()
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
	var widths: PackedFloat32Array = _cliff_widths(coarse_dem)
	_h.resize(N * N)
	for i in N * N:
		var t: float = _t[i]
		var amp: float = P["detail"]
		var detail: float = (n1[i] / 255.0 - 0.5) * amp + (n2[i] / 255.0 - 0.5) * amp / 6.0
		if t > 0.0:
			var cliff: float = widths[i] if not widths.is_empty() else CLIFF
			var top: float = maxf(raw[i], P["land_min"]) + detail * smoothstep(cliff, cliff + 20.0, t)
			if _beach[i] == 1:
				_h[i] = minf(top, -0.6 + t * 0.3)  # beach: dry sand from 2 m off the water, 3 m high at 12 m
			else:
				_h[i] = lerpf(-1.5, top, smoothstep(0.0, cliff, t))  # cliff
		else:
			# Sea floor: a rocky shelf getting deeper offshore.
			_h[i] = -1.5 - minf(-t * 0.35, 20.0) + detail * 1.5
	# Two levels (Hashima, with Codex): the reclaimed land below `terrace[0]`
	# metres is flattened (its height above land_min scaled by terrace[1]); the
	# old rock above it keeps its height. In between, 2 m of steep ground: a
	# rock face the grid cannot climb, crossed only where a path or stair is
	# carved (_carve_paths runs after this).
	var terrace: Array = P.get("terrace", [])
	if not terrace.is_empty():
		var cut: float = terrace[0]
		var low: float = P["land_min"]
		for i in N * N:
			var h: float = _h[i]
			if _t[i] <= CLIFF or h <= low:
				continue
			var flat: float = low + (h - low) * float(terrace[1])
			_h[i] = lerpf(flat, h + 2.0, smoothstep(cut - 1.0, cut + 1.0, h))


## Width of the cliff (the drop from the land to the sea) per cell, when the
## place has "cliff_width" [min, max]; empty otherwise. Codex's design:
## wider where the land behind is high, narrower where it is steep, with a
## slow variation along the coast:
##   w = clamp(6 + 0.12 H - 6 smoothstep(0.25, 1.2, g) + 2 n, min, max)
## H = mean height of the land within 32 m, g = its slope, n = noise. Worked
## out on the coarse elevation grid (one sample every DEM_STEP m), smoothed,
## then resized to 1 m. Kept at CLIFF (the old 4 m) within 8 m of every path
## and bridge (their ramps and decks were made for it), blending to the new
## width over the next 12 m, and on the islets (the fort's).
func _cliff_widths(coarse: Image) -> PackedFloat32Array:
	if not P.has("cliff_width"):
		return PackedFloat32Array()
	var lo: float = P["cliff_width"][0]
	var hi: float = P["cliff_width"][1]
	var dn: int = coarse.get_width()
	var r: int = ceili(32.0 / DEM_STEP)
	var land_h := PackedFloat32Array()
	land_h.resize(dn * dn)
	var land := PackedByteArray()
	land.resize(dn * dn)
	for j in dn:
		for i in dn:
			var x: int = mini(i * DEM_STEP, N - 1)
			var z: int = mini(j * DEM_STEP, N - 1)
			land[j * dn + i] = 1 if _t[z * N + x] > 0.0 else 0
			land_h[j * dn + i] = coarse.get_pixel(i, j).r
	var mean := PackedFloat32Array()
	mean.resize(dn * dn)
	for j in dn:
		for i in dn:
			var s: float = 0.0
			var c: int = 0
			for dj in range(-r, r + 1):
				for di in range(-r, r + 1):
					var ii: int = i + di
					var jj: int = j + dj
					if di * di + dj * dj > r * r or ii < 0 or jj < 0 or ii >= dn or jj >= dn or land[jj * dn + ii] == 0:
						continue  # a disc of 32 m (found by Codex: a square reached 45 m)
					s += land_h[jj * dn + ii]
					c += 1
			mean[j * dn + i] = maxf(s / c, P["land_min"]) if c > 0 else P["land_min"]
	var noise := FastNoiseLite.new()
	noise.seed = 13
	noise.frequency = 0.01
	var w_img := Image.create_empty(dn, dn, false, Image.FORMAT_RF)
	for j in dn:
		for i in dn:
			var gx: float = (mean[j * dn + mini(i + 1, dn - 1)] - mean[j * dn + maxi(i - 1, 0)]) / (2.0 * DEM_STEP)
			var gz: float = (mean[mini(j + 1, dn - 1) * dn + i] - mean[maxi(j - 1, 0) * dn + i]) / (2.0 * DEM_STEP)
			var g: float = Vector2(gx, gz).length()
			var n: float = noise.get_noise_2d(i * DEM_STEP, j * DEM_STEP)
			w_img.set_pixel(i, j, Color(clampf(6.0 + 0.12 * mean[j * dn + i] - 6.0 * smoothstep(0.25, 1.2, g) + 2.0 * n, lo, hi), 0, 0))
	# Smoothed along the coast (a small blur on the coarse grid), then 1 m.
	w_img.resize(dn / 2, dn / 2, Image.INTERPOLATE_BILINEAR)
	w_img.resize(dn * DEM_STEP, dn * DEM_STEP, Image.INTERPOLATE_CUBIC)
	var guard: PackedFloat32Array = _guard_distance(20.0)
	# The beaches too: their sand joins the path corridors on its own (found
	# by Codex), so the cliffs beside them stay as they were.
	var sand := PackedFloat32Array()
	sand.resize(N * N)
	for i in N * N:
		sand[i] = 0.0 if _beach[i] == 1 else 1e6
	_chamfer(sand)
	for i in N * N:
		guard[i] = minf(guard[i], sand[i])
	var main_ring: Array[PackedVector2Array] = [_rings[_main_ring()]]
	var main: PackedByteArray = _fill(main_ring)
	var out := PackedFloat32Array()
	out.resize(N * N)
	var wd: PackedByteArray = w_img.get_data()
	var ww: int = w_img.get_width()
	for z in N:
		for x in N:
			var i: int = z * N + x
			var w: float = clampf(wd.decode_float((z * ww + x) * 4), lo, hi)
			w = lerpf(CLIFF, w, smoothstep(8.0, 20.0, guard[i]))
			out[i] = w if main[i] == 1 else CLIFF
	return out


## Metres from every path and bridge (bridges 2 m longer at each end, as
## their decks), up to `reach` (beyond: reach).
func _guard_distance(reach: float) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(N * N)
	d.fill(reach)
	for path in _paths:
		var pts: PackedVector2Array = path[0]
		var half: float = path[1] * 0.5
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if path[3]:
				var dir: Vector2 = (b - a).normalized()
				a -= dir * 2.0
				b += dir * 2.0
			var pad: float = half + reach
			var lo: Vector2i = Vector2i(floori(minf(a.x, b.x) - pad), floori(minf(a.y, b.y) - pad)).clamp(Vector2i.ZERO, Vector2i(N - 1, N - 1))
			var hi: Vector2i = Vector2i(ceili(maxf(a.x, b.x) + pad), ceili(maxf(a.y, b.y) + pad)).clamp(Vector2i.ZERO, Vector2i(N - 1, N - 1))
			for z in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var p := Vector2(x, z)
					var dd: float = maxf(p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - half, 0.0)
					if dd < d[z * N + x]:
						d[z * N + x] = dd
	return d


## Index of the biggest coast ring (the main island).
func _main_ring() -> int:
	var best: int = 0
	for k in _rings.size():
		if absf(_area(_rings[k])) > absf(_area(_rings[best])):
			best = k
	return best


## Paths become walkable ramps. Every cell within SHOULDER of a path (not a
## bridge) is part of the corridor; its height may change at most PATH_SLOPE
## per cell inside the corridor, so the grid never sees a cliff along a path,
## junctions included. Where the real ground is steeper (the data is 25-30 m),
## the path is cut into the slope. Around the corridor the ground blends back
## to the natural height over BLEND metres.
func _carve_paths() -> void:
	_path_d.resize(N * N)
	_path_d.fill(99.0)
	# Squares (Hashima's tour walkway): their outline counts as a path of no
	# width (distances outside), their inside as paved; filled after the loop.
	var lines: Array = _paths.duplicate()
	for plaza in _plazas:
		var ring: PackedVector2Array = plaza.duplicate()
		ring.append(plaza[0])
		lines.append([ring, 0.0, "square", false])
	for path in lines:
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
	var paved: PackedByteArray = _fill(_plazas)
	for i in N * N:
		if paved[i] == 1:
			_path_d[i] = -1.0
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
	# One more vertex than cells on each side (cell corners), padded to whole
	# Terrain3D regions with the sea floor at the edge: a region's unimported
	# part would sit at 0 m, a flat strip above the water.
	var V: int = ceili((N + 1) / 512.0) * 512
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
			# The place's tint (Berlenga: a little greener, the scrub in spring)
			# only on vegetation: bare rock keeps its own colour.
			var rock: float = 1.0 if base == 1 else (clampf(blend, 0.0, 1.0) if over == 1 else 0.0)
			var hue: Color = (P["tint"] as Color).lerp(Color.WHITE, rock)
			# Wet band: rock and shore darker in the last 2 m above the water
			# (Codex's design).
			var wet: float = (1.0 - smoothstep(SEA + 0.3, SEA + 2.0, _h[i])) * (1.0 if base == 2 else rock)
			light *= lerpf(1.0, 0.65, wet)
			color[v * 4] = int(light * 255.0 * hue.r)
			color[v * 4 + 1] = int(light * 255.0 * hue.g)
			color[v * 4 + 2] = int(light * 255.0 * hue.b)
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
	# Staged first: the island's terrain is only replaced once the new
	# island passes its checks (found by Codex).
	var stage: String = ISLANDS + NAME + "_data_build"
	_clear_dir(stage)
	DirAccess.make_dir_recursive_absolute(stage)
	data.call("save_directory", stage)
	_terrain.set("data_directory", stage)
	_lap("terrain: heights, textures per vertex, staged")
	for group in ["Buildings", "Rocks", "Bridges", "Decor", "Markers"]:
		var n := Node3D.new()
		n.name = group
		_root.add_child(n)
		n.owner = _root
	if P.has("detail_area"):
		# Loaded at run time: plain scripts, no class_name to register.
		# --kits houses (or paths, or none) builds only those, for testing one.
		if "houses" in _kits:
			_house_kit = load(DIR + "village_houses.gd").new(self)
		if "paths" in _kits:
			_path_kit = load(DIR + "village_paths.gd").new(self)
		if "landmarks" in _kits:
			_landmark_kit = load(DIR + "landmarks.gd").new(self)
	_place_paths()
	_place_bridges()
	_place_buildings()
	_lap("paths, bridges, %d buildings, lighthouse, pier" % _houses.size())
	_place_nature()
	_place_walls()
	_place_sea()
	_lap("scrub and rocks")
	var problems: Array[String] = []
	var first: IslandMap = _root.build_map(problems)
	_lap("grid (%d x %d)" % [N, N])
	if not _place_markers(first):
		print("  PROBLEM: no landing; the island was not saved")
		_clear_dir(stage)
		return false
	_lap("markers")
	# Check the finished island before saving anything of it: a failed build
	# must not replace a good island (found by Codex).
	problems.clear()
	var map: IslandMap = _root.build_map(problems)
	var err: int = OK
	if problems.is_empty():
		var final: String = ISLANDS + NAME + "_data"
		_clear_dir(final)
		DirAccess.make_dir_recursive_absolute(final)
		for f in DirAccess.get_files_at(stage):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(stage.path_join(f)), ProjectSettings.globalize_path(final.path_join(f)))
		_clear_dir(stage)
		_terrain.set("data_directory", final)
		var assets: Resource = _terrain.get("assets")
		ResourceSaver.save(assets, ISLANDS + NAME + "_ground.res")
		assets.take_over_path(ISLANDS + NAME + "_ground.res")
		var packed := PackedScene.new()
		packed.pack(_root)
		# Binary: the copies of grass and rocks make a text scene far too big and slow.
		err = ResourceSaver.save(packed, ISLANDS + NAME + ".scn", ResourceSaver.FLAG_COMPRESS)
		_lap("saved %s (%s)" % [ISLANDS + NAME + ".scn", error_string(err)])
		HandmadeIsland.grid_image(map).save_png(ISLANDS + NAME + "_grid.png")
	else:
		print("  not saved: the island has problems (below)")
		_clear_dir(stage)
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
	_check_chokes(map)
	_debug_picture(map)
	for p in problems:
		print("  PROBLEM: ", p)
	if problems.is_empty() and err == OK:
		print("  no problems")
	return problems.is_empty() and err == OK


## Choke points (PLACES "chokes"): close each one in turn (a 4 m disc) and
## say whether the boat, generators and caches can still be reached, as
## tools/dev/build_islands.gd does for the hand-made islands. A cut is
## reported, not an error: on a real island some passages are the only way.
func _check_chokes(map: IslandMap) -> void:
	var goals: Array[Vector3] = [map.boat]
	goals.append_array(map.generators)
	goals.append_array(map.caches)
	var chokes: Dictionary = P.get("chokes", {})
	for name: String in chokes:
		var c: Vector2 = chokes[name]
		# A disc over the start or a goal would "cut" it without proving
		# anything about the routes (found by Codex): move the marker.
		var on: Array = goals.filter(func(g: Vector3) -> bool: return Vector2(g.x, g.z).distance_to(c) <= 5.0)
		if Vector2(map.player_start.x, map.player_start.z).distance_to(c) <= 5.0 or not on.is_empty():
			print("  Choke_%s: placed on the start or a goal, move it" % name)
			continue
		var f := FlowField.new(N, N)
		f.blocked = map.field.blocked.duplicate()
		for z in range(int(c.y) - 4, int(c.y) + 5):
			for x in range(int(c.x) - 4, int(c.x) + 5):
				if x >= 0 and z >= 0 and x < N and z < N and Vector2(x + 0.5, z + 0.5).distance_to(c) <= 4.0:
					f.blocked[z * N + x] = 1
		f.compute_now(f.world_to_cell(map.player_start))
		var cut: PackedStringArray = []
		for g in goals:
			if f.distance_at(g) >= FlowField.UNREACHABLE:
				cut.append("(%d, %d)" % [int(g.x), int(g.z)])
		print("  Choke_%s closed: %s" % [name, "every goal still reachable" if cut.is_empty() else "CUT OFF " + ", ".join(cut)])


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
	var assets: Resource = ClassDB.instantiate(&"Terrain3DAssets")
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
	return assets  # saved next to the island only when the build succeeds


## Deletes the files in `dir` and the folder itself (if they exist).
func _clear_dir(dir: String) -> void:
	if not DirAccess.dir_exists_absolute(dir):
		return
	for f in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(f)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))


## One map of a downloaded texture. Poly Haven does not have every map for
## every texture (or has it only as .jpg): the other extension is tried,
## then a plain grey stands in (mid height, mid roughness).
func _tex(asset: String, file: String) -> Image:
	var path: String = ProjectSettings.globalize_path(DATA + "textures/%s_%s" % [asset, file])
	var other: String = path.get_basename() + (".jpg" if path.ends_with(".png") else ".png")
	var img: Image
	if FileAccess.file_exists(path):
		img = Image.load_from_file(path)
	elif FileAccess.file_exists(other):
		img = Image.load_from_file(other)
	else:
		print("  %s_%s missing: plain grey instead" % [asset, file])
		img = Image.create_empty(1024, 1024, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.5, 0.5))
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != 1024:
		img.resize(1024, 1024)
	return img


func _texture(img: Image, name: String, normal: bool = false) -> Texture2D:
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps(normal)  # normal maps: mipmaps renormalized
	if img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC) != OK:
		print("  %s: not compressed (stays RGBA8)" % name)
	var path: String = TEX + name + ".res"
	var err: int = ResourceSaver.save(ImageTexture.create_from_image(img), path)
	if err != OK:
		print("  PROBLEM: could not save %s (%s)" % [path, error_string(err)])
	return load(path)


## The place's facade texture (role "facade" in fetch_data.py) with a window
## drawn in, or null. One picture covers 3 x 3 m of wall (one floor, one
## window), see _place_buildings.
func _facade_texture() -> Texture2D:
	for asset: String in meta["textures"]:
		if meta["textures"][asset] != "facade":
			continue
		var img: Image = _tex(asset, "diffuse.jpg")
		var s: int = img.get_width()
		var frame := Rect2i(int(s * 0.27), int(s * 0.22), int(s * 0.46), int(s * 0.5))
		img.fill_rect(frame, Color(0.3, 0.3, 0.29))  # concrete frame
		var glass: Rect2i = frame.grow(-int(s * 0.03))
		img.fill_rect(glass, Color(0.07, 0.08, 0.09))  # dark, broken glass
		img.fill_rect(Rect2i(glass.position.x, glass.get_center().y, glass.size.x, int(s * 0.012)), Color(0.22, 0.22, 0.21))
		img.fill_rect(Rect2i(glass.get_center().x, glass.position.y, int(s * 0.012), glass.size.y), Color(0.22, 0.22, 0.21))
		return _texture(img, asset + "_window")
	return null


func _mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


## A material from the place's texture with that role in fetch_data.py
## (plaster, roof, stone...): colour, normal and roughness maps, tinted,
## one picture every `metres`. Projected from the sides in world space
## (triplanar) unless `uv` is true: then the mesh's own UVs, in metres
## (UV 1 = 1 m). Null when the place has no texture with that role.
func _role_material(role: String, metres: float, tint: Color = Color.WHITE, uv: bool = false) -> StandardMaterial3D:
	assert(metres > 0.0)
	var key: String = "mat/%s/%s/%s/%s" % [role, metres, tint, uv]
	if _materials.has(key):
		return _materials[key]
	var m: StandardMaterial3D = null
	for asset: String in meta["textures"]:
		if meta["textures"][asset] != role:
			continue
		m = _mat(tint, 1.0)
		m.albedo_texture = _cached_texture(asset, "diffuse.jpg")
		m.normal_enabled = true
		m.normal_texture = _cached_texture(asset, "nor_gl.jpg")
		m.roughness_texture = _cached_texture(asset, "rough.jpg")
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		if uv:
			m.uv1_scale = Vector3.ONE / metres
		else:
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE / metres
	_materials[key] = m
	return m


## One map of a texture as a compressed resource in TEX, made once per build.
func _cached_texture(asset: String, file: String) -> Texture2D:
	var name: String = "%s_%s" % [asset, file.get_basename()]  # also the .res file name
	if _materials.has(name):
		return _materials[name]
	var t: Texture2D = _texture(_tex(asset, file), name, file.begins_with("nor"))
	_materials[name] = t
	return t


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
		if _path_kit != null and _path_kit.place(path):
			continue  # inside the detail area: the kit's steps, kerbs, road
		if path[2] == "steps":
			_ribbon(stone, path[0], path[1], 0.06)
		elif path[2] == "service":
			_ribbon(road, path[0], path[1], 0.05)
	if _path_kit != null:
		_path_kit.finish()
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


## Buildings from their real footprints and heights, one node each (the grid
## blocks their footprint): walls from below the lowest ground up to the
## eaves, and the place's roof: "hip" (tiled, a fan to the centre) or "flat"
## (concrete slab inside a low parapet). Walls take the place's facade
## texture when it has one, projected from the sides (triplanar).
func _place_buildings() -> void:
	var wall_mat: StandardMaterial3D = _mat(P["walls"], 0.85)
	var facade: Texture2D = _facade_texture()
	if facade != null:
		wall_mat.albedo_texture = facade
		wall_mat.uv1_triplanar = true
		wall_mat.uv1_scale = Vector3.ONE / 3.0  # one picture (a floor with its window) every 3 m
	var roof_mat: StandardMaterial3D = _mat(P["roof_color"], 0.85)
	var balconies := SurfaceTool.new()
	balconies.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in _houses.size():
		# OSM roof:shape wins over the place's style (Hashima's pit 4 is gabled).
		var shape: String = _houses[k][3]
		var flat: bool = shape == "flat" or (shape == "" and P["roof"] == "flat")
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
		if P.get("special", {}).get(_houses[k][4], "") == "conveyor":
			_conveyor(pts, hi, k)
			continue
		if _house_kit != null and _house_kit.place(k, pts, lo, hi):
			continue  # inside the detail area: the kit's house
		var c: Vector2 = _centroid(pts)
		var base: float = lo - 0.5
		var eaves: float = hi + float(_houses[k][1])
		var walls := SurfaceTool.new()
		var roof := SurfaceTool.new()
		walls.begin(Mesh.PRIMITIVE_TRIANGLES)
		roof.begin(Mesh.PRIMITIVE_TRIANGLES)
		var turn: float = _turn(pts)
		var shortest: float = INF
		for i in pts.size():
			var a: Vector2 = pts[i] - c
			var e: Vector2 = pts[(i + 1) % pts.size()] - c
			shortest = minf(shortest, a.distance_to(e))
			var out: Vector3 = _outward(a, e, turn)
			_tri(walls, Vector3(a.x, base, a.y), Vector3(e.x, base, e.y), Vector3(e.x, eaves, e.y), out)
			_tri(walls, Vector3(a.x, base, a.y), Vector3(e.x, eaves, e.y), Vector3(a.x, eaves, a.y), out)
		if flat:
			# Slab: triangulated footprint (concave plans too), and a 0.8 m
			# parapet that hides it from the street.
			var local := PackedVector2Array()
			for p in pts:
				local.append(p - c)
			var idx: PackedInt32Array = Geometry2D.triangulate_polygon(local)
			for k3 in range(0, idx.size(), 3):
				var q: Array[Vector3] = []
				for j in 3:
					q.append(Vector3(local[idx[k3 + j]].x, eaves - 0.1, local[idx[k3 + j]].y))
				_tri(roof, q[0], q[1], q[2], Vector3.UP)
			for i in pts.size():
				var a: Vector2 = pts[i] - c
				var e: Vector2 = pts[(i + 1) % pts.size()] - c
				var out: Vector3 = _outward(a, e, turn)
				_tri(walls, Vector3(a.x, eaves, a.y), Vector3(e.x, eaves, e.y), Vector3(e.x, eaves + 0.8, e.y), out)
				_tri(walls, Vector3(a.x, eaves, a.y), Vector3(e.x, eaves + 0.8, e.y), Vector3(a.x, eaves + 0.8, a.y), out)
		elif shape in ["gabled", "pitched"]:
			var local := PackedVector2Array()
			for p in pts:
				local.append(p - c)
			_gable(roof, local, eaves, turn, walls)
		else:
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
		if flat and String(_houses[k][4]).ends_with("号棟") and float(_houses[k][1]) >= 12.0:
			_balconies(balconies, pts, hi, eaves)
	if _house_kit != null:
		_house_kit.finish()
	var gallery: ArrayMesh = balconies.commit()
	if gallery.get_surface_count() > 0:
		# Decoration, not part of the buildings: the grid blocks what a building
		# covers from above, and balconies over an alley would close it.
		var inst := MeshInstance3D.new()
		inst.name = "Balconies"
		inst.mesh = gallery
		inst.material_override = _mat(Color(0.62, 0.61, 0.58), 0.9)
		_add(inst, "Decor")
	for name: String in P.get("special", {}):
		if P["special"][name] == "shrine" and _named.has(name):
			_shrine(_named[name])
	for k in _lighthouses.size():
		if _landmark_kit != null and _landmark_kit.lighthouse(_lighthouses[k], k, _light_heights[k]):
			continue
		_lighthouse(_lighthouses[k], k, _light_heights[k])
	if _landmark_kit != null and P["generators"].any(func(g: Array) -> bool: return g[0] == "fort"):
		_landmark_kit.fort(_fort_islet())
	for k in _piers.size():
		_pier(_piers[k], k)


## A box mesh instance (size, centre in island space, colour, turned `yaw`
## around Y) added to `group`.
func _box(group: String, name: String, size: Vector3, centre: Vector3, color: Color, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color, 0.8)
	mi.transform = Transform3D(Basis(Vector3.UP, yaw), centre)
	_add(mi, group)
	return mi


## A small Shinto shrine at the OSM point (Hashima's 端島神社, with Codex):
## a wooden hall with a gabled roof on a stone base, and a torii gate in
## front. The hall and each torii pillar block (Buildings/); the torii
## beams are decoration, so the gate stays open.
func _shrine(p: Vector2) -> void:
	# The OSM point touches block 1's footprint: move to the nearest spot
	# with 3 m clear of every building (and the shrine's own 8 m).
	var taken: PackedByteArray = _fill(_grown_houses(3.0))
	var best := p
	var bd: float = INF
	for z in range(int(p.y) - 30, int(p.y) + 31):
		for x in range(int(p.x) - 30, int(p.x) + 31):
			var free: bool = true
			for o: Vector2i in [Vector2i(0, 0), Vector2i(4, 0), Vector2i(-4, 0), Vector2i(0, 4), Vector2i(0, -4), Vector2i(5, 5), Vector2i(-5, -5)]:
				var q := Vector2i(x, z) + o
				if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N or taken[q.y * N + q.x] == 1 or _slope(q.y * N + q.x) > 0.4:
					free = false
					break
			if free and p.distance_to(Vector2(x, z)) < bd:
				bd = p.distance_to(Vector2(x, z))
				best = Vector2(x + 0.5, z + 0.5)
	p = best
	var y: float = height_at(p.x, p.y)
	var yaw: float = PI * 0.25  # facing the sea to the south-east
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var side := Vector3(cos(yaw), 0, -sin(yaw))
	var c := Vector3(p.x, y, p.y)
	_box("Buildings", "ShrineBase", Vector3(4.5, 0.8, 5.5), c + Vector3(0, 0.1, 0), Color(0.5, 0.49, 0.46), yaw)
	var hall := _box("Buildings", "ShrineHall", Vector3(3.2, 2.6, 4.0), c + Vector3(0, 1.8, 0), Color(0.36, 0.24, 0.17), yaw)
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plan := PackedVector2Array([Vector2(-2.1, -2.6), Vector2(2.1, -2.6), Vector2(2.1, 2.6), Vector2(-2.1, 2.6)])
	_gable(roof, plan, 1.3, _turn(plan), roof)  # one mesh, gable ends too; hall-local: eaves 1.3 m above its centre
	var rm := MeshInstance3D.new()
	rm.name = "Roof"
	rm.mesh = roof.commit()
	rm.material_override = _mat(Color(0.22, 0.22, 0.24), 0.7)
	hall.add_child(rm)
	rm.owner = _root
	var gate: Vector3 = c + fwd * 7.0
	gate.y = height_at(gate.x, gate.z)
	var red := Color(0.55, 0.2, 0.15)
	for s: float in [-1.4, 1.4]:
		var post: Vector3 = gate + side * s
		_box("Buildings", "ToriiPillar", Vector3(0.35, 3.6, 0.35), post + Vector3(0, 1.8, 0), red, yaw)
	_box("Decor", "ToriiTop", Vector3(4.2, 0.3, 0.45), gate + Vector3(0, 3.75, 0), red, yaw)
	_box("Decor", "ToriiTie", Vector3(3.4, 0.2, 0.25), gate + Vector3(0, 3.1, 0), red, yaw)


## Hashima's conveyor belt (ベルトコンベアー): an open belt on a frame 5 m
## up along the footprint's long side, on posts every 4 m. Only the posts
## block (Buildings/); the belt is decoration, so units walk under it.
func _conveyor(pts: PackedVector2Array, ground: float, k: int) -> void:
	var u := Vector2.RIGHT
	var longest: float = 0.0
	for i in pts.size():
		var d: Vector2 = pts[(i + 1) % pts.size()] - pts[i]
		if d.length() > longest:
			longest = d.length()
			u = d.normalized()
	var umin: float = INF
	var umax: float = -INF
	for p in pts:
		umin = minf(umin, p.dot(u))
		umax = maxf(umax, p.dot(u))
	var c: Vector2 = _centroid(pts)
	var mid: Vector2 = c + u * ((umin + umax) * 0.5 - c.dot(u))
	var length: float = umax - umin
	var yaw: float = atan2(u.x, u.y)
	var belt_y: float = ground + 5.0
	_box("Decor", "Conveyor_%d" % k, Vector3(1.6, 0.5, length), Vector3(mid.x, belt_y, mid.y), Color(0.3, 0.27, 0.24), yaw)
	_box("Decor", "ConveyorRoof_%d" % k, Vector3(2.2, 0.15, length), Vector3(mid.x, belt_y + 1.6, mid.y), Color(0.42, 0.3, 0.22), yaw)
	var n: int = maxi(2, int(length / 4.0) + 1)
	for j in n:
		var q: Vector2 = mid + u * lerpf(-length * 0.5 + 0.5, length * 0.5 - 0.5, float(j) / (n - 1))
		var gy: float = height_at(q.x, q.y)
		_box("Buildings", "ConveyorPost_%d_%d" % [k, j], Vector3(0.5, belt_y - gy, 0.5), Vector3(q.x, (belt_y + gy) * 0.5, q.y), Color(0.35, 0.3, 0.26), yaw)


## A gabled roof: the ridge runs along the longest wall, through the middle
## of the plan; every point of the eaves rises to the ridge point level with
## it. Long walls get a slope, short ones a vertical gable. Before, OSM
## "gabled" fell back to a pyramid (found by Codex).
## Gabled roof over a plan: slopes into `st`, the triangular gable ends into
## `walls` (they are wall, not roof: found by Codex).
func _gable(st: SurfaceTool, pts: PackedVector2Array, eaves: float, turn: float, walls: SurfaceTool) -> void:
	var u := Vector2.RIGHT
	var longest: float = 0.0
	for i in pts.size():
		var d: Vector2 = pts[(i + 1) % pts.size()] - pts[i]
		if d.length() > longest:
			longest = d.length()
			u = d.normalized()
	var v := Vector2(-u.y, u.x)
	var vmin: float = INF
	var vmax: float = -INF
	for p in pts:
		vmin = minf(vmin, p.dot(v))
		vmax = maxf(vmax, p.dot(v))
	var vmid: float = (vmin + vmax) * 0.5
	var top: float = eaves + clampf((vmax - vmin) * 0.3, 1.0, 4.0)
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		var rp2: Vector2 = u * p.dot(u) + v * vmid
		var rq2: Vector2 = u * q.dot(u) + v * vmid
		var a := Vector3(p.x, eaves, p.y)
		var b := Vector3(q.x, eaves, q.y)
		var rp := Vector3(rp2.x, top, rp2.y)
		var rq := Vector3(rq2.x, top, rq2.y)
		var n: Vector3 = (b - a).cross(rp - a).normalized()
		if n.dot(_outward(p, q, turn)) + n.y < 0.0:
			n = -n  # slopes face up and out, gables out
		if rp2.distance_to(rq2) < 0.05:
			_tri(walls, a, b, rp, n)  # gable end
		else:
			_tri(st, a, b, rq, n)
			_tri(st, a, rq, rp, n)


## Which way a footprint winds: +1 or -1 (sign of its area, closing edge
## included). With it the outside of every wall is known, also in L- and
## U-shaped plans, where "away from the centre" points the wrong way.
func _turn(pts: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return 1.0 if a >= 0.0 else -1.0


## Outward normal of the wall from a to e (see _turn).
func _outward(a: Vector2, e: Vector2, turn: float) -> Vector3:
	var d: Vector2 = (e - a).normalized()
	return Vector3(d.y, 0, -d.x) * turn


## Hashima's flats ("<n>号棟"): an open gallery (a concrete slab 1 m deep
## with a 0.9 m parapet) along each long side, one per floor (3 m). The
## blocks had them on the outside: they are what makes them read as housing.
func _balconies(st: SurfaceTool, pts: PackedVector2Array, ground: float, eaves: float) -> void:
	var turn: float = _turn(pts)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var e: Vector2 = pts[(i + 1) % pts.size()]
		if a.distance_to(e) < 8.0:
			continue
		var d: Vector2 = (e - a).normalized()
		var out2 := Vector2(d.y, -d.x) * turn
		# Ends trimmed by the gallery's depth: at an inner corner the two
		# galleries would otherwise overlap and flicker (found by Codex).
		var a0: Vector2 = a + d * 1.0
		var e0: Vector2 = e - d * 1.0
		var a1: Vector2 = a0 + out2
		var e1: Vector2 = e0 + out2
		var out := Vector3(out2.x, 0, out2.y)
		var y: float = ground + 3.0
		while y < eaves - 1.0:
			var p: Array[Vector3] = [Vector3(a0.x, y, a0.y), Vector3(e0.x, y, e0.y), Vector3(e1.x, y, e1.y), Vector3(a1.x, y, a1.y)]
			_tri(st, p[0], p[1], p[2], Vector3.UP)  # slab top
			_tri(st, p[0], p[2], p[3], Vector3.UP)
			var down := Vector3(0, -0.15, 0)
			_tri(st, p[0] + down, p[2] + down, p[1] + down, Vector3.DOWN)
			_tri(st, p[0] + down, p[3] + down, p[2] + down, Vector3.DOWN)
			var up := Vector3(0, 0.9, 0)
			_tri(st, p[3] + down, p[2] + down, p[2] + up, out)  # parapet
			_tri(st, p[3] + down, p[2] + up, p[3] + up, out)
			_tri(st, p[3] + up, p[2] + up, p[2], -out)
			_tri(st, p[3] + up, p[2], p[3], -out)
			y += 3.0


## A lighthouse `height` metres tall (OSM height, or LIGHTHOUSE_HEIGHT for a
## point): a square tower, the lantern room and a red cap.
func _lighthouse(p: Vector2, k: int, height: float) -> void:
	var node := Node3D.new()
	node.name = "Lighthouse_%d" % k
	node.position = Vector3(p.x, height_at(p.x, p.y) - 0.5, p.y)
	_add(node, "Buildings")
	var s: float = height / 22.2  # the parts below are for a 22.2 m lighthouse
	var parts: Array = [
		[BoxMesh.new(), Vector3(4.5, 18.0, 4.5) * s, Vector3(0, 9.0, 0) * s, Color(0.95, 0.94, 0.9)],
		[CylinderMesh.new(), Vector3(2.0, 3.0, 2.0) * s, Vector3(0, 19.5, 0) * s, Color(0.15, 0.17, 0.2)],
		[CylinderMesh.new(), Vector3(2.4, 1.2, 2.4) * s, Vector3(0, 21.6, 0) * s, Color(0.7, 0.15, 0.12)],
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


## The place's scatter (PLACES "scatter"): grass and scrub (Decor) and rocks
## or rubble (Rocks: they block), as Scatter nodes in 128 m chunks that are
## drawn only near the camera: drawing every tuft of the island every frame
## costs far too much.
func _place_nature() -> void:
	var near_house: PackedByteArray = _fill(_grown_houses(2.0, false))
	var around_house: PackedByteArray = _fill(_grown_houses(5.0, false))
	# Kits' footprints (fort walls, courtyard): checked last and counted as
	# placed, and every try draws the same random numbers, accepted or not.
	# So reserving a shape removes only what would land on it and moves
	# nothing elsewhere on the island (found by the landmarks subagent).
	var reserved: PackedByteArray = _fill(_grown(_reserved, 1.0))
	var outcrops: PackedByteArray = _outcrops(around_house)
	var outcrop_cells := PackedInt32Array()  # drawn from directly: the discs are tiny
	for i in N * N:
		if outcrops[i] == 1:
			outcrop_cells.append(i)
	var green: PackedByteArray = _fill(_green)
	var near_light: Array[Vector2] = _lighthouses.duplicate()
	for spec: Array in P["scatter"]:
		var mesh: Mesh = _kit_mesh(spec[0])
		if mesh == null:
			continue
		var rock: bool = spec[5] in ["cliff_top", "rubble", "outcrop"]  # these block (Rocks/)
		var target: float = spec[2]
		var tries: int = 0
		var made: int = 0
		var chunks: Dictionary = {}
		while made < spec[1] and tries < spec[1] * 20:
			tries += 1
			var x: int = _rng.randi_range(2, N - 3)
			var z: int = _rng.randi_range(2, N - 3)
			if spec[5] == "outcrop":
				if outcrop_cells.is_empty():
					break
				var oc: int = outcrop_cells[_rng.randi() % outcrop_cells.size()]
				x = oc % N
				z = oc / N
			var jx: float = _rng.randf()
			var jz: float = _rng.randf()
			var size: float = _rng.randf_range(0.6, 1.4)
			var yaw: float = _rng.randf() * TAU
			var i: int = z * N + x
			var t: float = _t[i]
			if t < spec[3] or _beach[i] == 1:
				continue
			if _path_d[i] < (SHOULDER + BLEND + 1.0 if rock else 0.6):
				continue  # rocks keep paths and their ramps clear
			match spec[5]:
				"cliff_top":  # along the cliffs, away from buildings and the lighthouse
					if near_house[i] == 1 or t > 25.0 or _slope(i) < 0.25:
						continue
					if near_light.any(func(l: Vector2) -> bool: return l.distance_to(Vector2(x, z)) < 30.0):
						continue
				"rubble":  # fallen concrete at the foot of the buildings
					if near_house[i] == 1 or around_house[i] == 0 or _slope(i) > 0.4:
						continue
				"green":
					if green[i] == 0 or near_house[i] == 1 or _slope(i) > 0.55:
						continue
				"outcrop":
					if outcrops[i] == 0:
						continue
				_:
					if near_house[i] == 1 or _slope(i) > 0.55:
						continue
			if reserved[i] == 1:
				made += 1
				continue
			var p := Vector2(x + jx, z + jz)
			var s: float = target / maxf(mesh.get_aabb().size.y, 0.01) * size
			var y: float = height_at(p.x, p.y) - (0.4 * s if rock else 0.05)
			var key := Vector2i(floori(p.x / 128.0), floori(p.y / 128.0))
			if not chunks.has(key):
				chunks[key] = PackedFloat32Array()
			# Relative to the chunk centre: the draw distance is measured from the node.
			var o := Vector2(key.x * 128.0 + 64.0, key.y * 128.0 + 64.0)
			# Packed arrays are copied when read from a Dictionary: write it back.
			var arr: PackedFloat32Array = chunks[key]
			arr.append_array([p.x - o.x, y, p.y - o.y, yaw, s])
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


## Cells of the outcrops: 40 discs of 2 to 4 m on gentle ground (slope under
## 0.35) more than 25 m from the coast, away from paths, beaches, buildings
## (`around_house`) and 30 m from where the generators go (the village, the
## lighthouses, the fort's islet). Its own random numbers: the other
## scatter rows do not move.
func _outcrops(around_house: PackedByteArray) -> PackedByteArray:
	var mask := PackedByteArray()
	mask.resize(N * N)
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	var keep_out: Array[Vector2] = _lighthouses.duplicate()
	if _village.x >= 0.0:
		keep_out.append(_village)
	keep_out.append(_fort_islet())
	var made: int = 0
	var tries: int = 0
	while made < 40 and tries < 20000:
		tries += 1
		var c := Vector2i(rng.randi_range(8, N - 9), rng.randi_range(8, N - 9))
		var r: float = rng.randf_range(2.0, 4.0)
		var i: int = c.y * N + c.x
		if _t[i] < 25.0 or _slope(i) > 0.35 or around_house[i] == 1 or _path_d[i] < 10.0:
			continue
		if keep_out.any(func(p: Vector2) -> bool: return p.distance_to(Vector2(c)) < 30.0):
			continue
		# Every cell of the disc checked, not only the centre (found by Codex).
		for z in range(c.y - 4, c.y + 5):
			for x in range(c.x - 4, c.x + 5):
				var k: int = z * N + x
				if Vector2(x, z).distance_to(Vector2(c)) <= r and _path_d[k] > SHOULDER + BLEND + 1.0 						and _slope(k) <= 0.35 and around_house[k] == 0 and _t[k] > 20.0:
					mask[k] = 1
		made += 1
	return mask


## Building footprints (and kits' reserved shapes unless `reserved` is
## false) grown by `metres` (for "near a building" masks).
func _grown_houses(metres: float, reserved: bool = true) -> Array[PackedVector2Array]:
	var shapes: Array[PackedVector2Array] = []
	if reserved:
		shapes.append_array(_reserved)
	for b in _houses:
		shapes.append(b[0])
	return _grown(shapes, metres)


## Shapes grown by `metres`.
func _grown(shapes: Array[PackedVector2Array], metres: float) -> Array[PackedVector2Array]:
	var rings: Array[PackedVector2Array] = []
	for pts in shapes:
		var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(pts, metres)
		rings.append(grown[0] if not grown.is_empty() else pts)
	return rings


## Sea walls (OSM retaining walls and breakwaters): a 1.2 m concrete parapet
## along the top of the wall. Decoration: the drop behind it already blocks.
func _place_walls() -> void:
	if not P.get("parapet", false) or _walls.is_empty():
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for wall in _walls:
		for i in wall.size() - 1:
			var a: Vector2 = wall[i]
			var b: Vector2 = wall[i + 1]
			var n: int = maxi(1, ceili(a.distance_to(b) / 2.0))
			for k in n:
				var p: Vector2 = a.lerp(b, float(k) / n)
				var q: Vector2 = a.lerp(b, float(k + 1) / n)
				# The wall's top: the highest ground within 2 m (the line runs
				# along the edge, half way down the drop).
				var hp: float = _top_near(p)
				var hq: float = _top_near(q)
				var side := Vector3(-(q - p).y, 0, (q - p).x).normalized() * 0.2
				var p0 := Vector3(p.x, hp - 0.5, p.y)
				var q0 := Vector3(q.x, hq - 0.5, q.y)
				for s: Vector3 in [side, -side]:
					_tri(st, p0 + s, q0 + s, q0 + s + Vector3(0, 1.7, 0), s.normalized())
					_tri(st, p0 + s, q0 + s + Vector3(0, 1.7, 0), p0 + s + Vector3(0, 1.7, 0), s.normalized())
				_tri(st, p0 + side + Vector3(0, 1.7, 0), q0 + side + Vector3(0, 1.7, 0), q0 - side + Vector3(0, 1.7, 0), Vector3.UP)
				_tri(st, p0 + side + Vector3(0, 1.7, 0), q0 - side + Vector3(0, 1.7, 0), p0 - side + Vector3(0, 1.7, 0), Vector3.UP)
	var inst := MeshInstance3D.new()
	inst.name = "SeaWall"
	inst.mesh = st.commit()
	inst.material_override = _mat(Color(0.6, 0.59, 0.56))
	_add(inst, "Decor")


func _top_near(p: Vector2) -> float:
	var top: float = -INF
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			top = maxf(top, height_at(p.x + dx, p.y + dz))
	return top


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
func _place_markers(map: IslandMap) -> bool:
	var f: FlowField = map.field
	f.max_distance = 0
	# The island's walkable heart: everything reachable from the lighthouse,
	# or from the most inland open spot.
	var light: Vector2 = _lighthouses[0] if not _lighthouses.is_empty() else _most_inland(f)
	f.compute_now(_nearest_clear(f, Vector2i(light), 40))
	var heart: PackedInt32Array = f.dist.duplicate()
	# Landing: the shore cell (2-8 m from the water, dry, connected to the
	# heart) nearest the middle of the biggest beach (Berlenga: the Carreiro
	# do Mosteiro, sand first) or of the pier (Hashima: the Dolphin Pier,
	# where the tour boats tie up). The boat lies out to sea from there.
	var beach := PackedVector2Array([Vector2(N * 0.5, N * 0.5)])
	var source: Array[PackedVector2Array] = _beaches if P["landing"] == "beach" else _piers
	for b in source:
		if beach.size() < 2 or absf(_area(b)) > absf(_area(beach)) or P["landing"] == "pier":
			beach = b
			if P["landing"] == "pier":
				break
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
	if landing.x < 0:
		return false  # no dry shore cell connected to the island near the beach or pier
	print("  landing at (%d, %d) %s, %.1f m high" % [landing.x, landing.y, "on the sand" if best < 100.0 else "on the shore", _h[landing.y * N + landing.x]])
	var seaward := Vector2(_t[landing.y * N + landing.x - 1] - _t[landing.y * N + landing.x + 1],
		_t[(landing.y - 1) * N + landing.x] - _t[(landing.y + 1) * N + landing.x]).normalized()
	var boat := Vector3(landing.x + 0.5, 0, landing.y + 0.5)
	_marker("Boat", boat, Vector3(seaward.x, 0, seaward.y))
	var start: Vector2i = _nearest_clear(f, landing - Vector2i(roundi(seaward.x * 6.0), roundi(seaward.y * 6.0)), 10)
	_marker("PlayerStart", Vector3(start.x + 0.5, 0, start.y + 0.5))
	f.compute_now(start)
	var reach: PackedInt32Array = f.dist.duplicate()
	var goals: Array[Vector2] = [Vector2(landing)]
	# Generators at three real places (PLACES "generators"). Berlenga: the
	# fishermen's quarter (Bairro dos Pescadores), the lighthouse, the fort's
	# islet at the end of the Caminho do Forte. Hashima: pit 2 (the mine),
	# block 65 (the biggest flats), pit 4. The caches go to the far ends of the
	# island: optional detours.
	for k in P["generators"].size():
		var spec: Array = P["generators"][k]
		var near: Vector2 = light
		var r_min: float = 8.0
		match spec[0]:
			"landuse":
				near = _village if _village.x >= 0.0 else light
			"lighthouse":
				r_min = 10.0
			"fort":  # in the fort's courtyard when landmarks.gd built one
				near = _fort_islet()
				if _landmark_kit != null and _landmark_kit.courtyard.x >= 0.0:
					near = _landmark_kit.courtyard
				r_min = 0.0
			"named":
				if _named.has(spec[1]):
					near = _named[spec[1]]
				else:
					print("  WARNING: no OSM feature named %s" % spec[1])
		var g: Vector2 = _reachable_near(f, reach, near, r_min, 60.0)
		_marker("Generator%d" % (k + 1), Vector3(g.x + 0.5, 0, g.y + 0.5))
		goals.append(g)
	var walk: int = P["cache_walk"]
	for k in P["caches"]:
		var c: Vector2 = _farthest(f, reach, goals, walk / 10, walk, 12.0 if walk > 800 else 4.0)
		_marker("Cache%d" % (k + 1), Vector3(c.x + 0.5, 0, c.y + 0.5))
		goals.append(c)
	# Choke points and arenas: markers for the level design (they do not
	# change the game; screenshot.gd takes a close view of each).
	for kind: String in ["chokes", "arenas"]:
		var spots: Dictionary = P.get(kind, {})
		for name: String in spots:
			var p: Vector2 = spots[name]
			_marker(("Choke_" if kind == "chokes" else "Arena_") + name, Vector3(p.x, 0, p.y))
	return true


## The open, walkable cell furthest from the coast.
func _most_inland(f: FlowField) -> Vector2:
	var best := Vector2(N * 0.5, N * 0.5)
	var bt: float = -1.0
	for z in range(4, N - 4, 2):
		for x in range(4, N - 4, 2):
			var t: float = _t[z * N + x]
			if t > bt and _clear(f, Vector2i(x, z)):
				bt = t
				best = Vector2(x, z)
	return best


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
