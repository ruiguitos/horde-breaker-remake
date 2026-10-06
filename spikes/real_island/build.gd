extends SceneTree
## Builds out/real_island.tscn from real data (run fetch_data.py first):
##   - relief: elevation tiles (about 25-30 m real resolution) smoothed with
##     a cubic resize, plus fine noise for rock detail;
##   - coast: the exact OpenStreetMap coastline; cliffs where it meets the
##     sea, gentle slopes on mapped beaches;
##   - ground: four CC0 textures (grass and rock, cliff rock, shore, gravel
##     paths) chosen per vertex by slope, coast distance and paths;
##   - OSM paths (gravel), steps (stone), service roads, bridges, buildings
##     (white walls, tiled roofs), lighthouse and pier;
##   - low scrub and rocks (Quaternius CC0), sea, Sky3D sky; the camera adds
##     the colour grading when the scene runs (it needs the GPU).
## Prints the time of every stage and a horde-grid measurement (1 m cells).
## Run: godot --headless --path . --script res://spikes/real_island/build.gd

const DIR: String = "res://spikes/real_island/"
const DATA: String = DIR + "data/"
const OUT: String = DIR + "out/"
const KIT: String = "res://assets/models/nature_megakit/"
const SKY3D: String = "res://addons/sky_3d/src/Sky3D.gd"
const DEM_STEP: int = 8  ## metres between elevation samples before the cubic resize
const CLIFF: float = 4.0  ## width of the drop from the cliff top to the sea, metres
const WIDTHS: Dictionary = {"footway": 2.0, "path": 1.6, "steps": 2.2, "track": 3.0, "service": 4.0, "pedestrian": 3.0}

var meta: Dictionary
var N: int
var lat0: float
var lon0: float
var mx: float  ## metres per degree of longitude here
var mz: float  ## metres per degree of latitude
var _h := PackedFloat32Array()
var _t := PackedFloat32Array()      ## metres from the coastline (+ land, - sea)
var _beach := PackedByteArray()
var _path_d := PackedFloat32Array() ## metres from the nearest gravel path edge (capped)
var _rings: Array[PackedVector2Array] = []
var _beaches: Array[PackedVector2Array] = []
var _paths: Array = []              ## [PackedVector2Array, width, kind, bridge]
var _houses: Array = []             ## [PackedVector2Array, height, kind]
var _piers: Array[PackedVector2Array] = []
var _lighthouses: Array[Vector2] = []
var _rng := RandomNumberGenerator.new()
var _root: Node3D
var _terrain: Node3D
var _clock: int = 0


func _initialize() -> void:
	if not FileAccess.file_exists(DATA + "meta.json"):
		print("No data: run  python spikes/real_island/fetch_data.py  first.")
		quit(1)
		return
	meta = JSON.parse_string(FileAccess.get_file_as_string(DATA + "meta.json"))
	N = int(meta["size"])
	lat0 = meta["lat"]
	lon0 = meta["lon"]
	mx = 111320.0 * cos(deg_to_rad(lat0))
	mz = 110574.0
	_rng.seed = 7
	_clock = Time.get_ticks_msec()
	_read_osm()
	_lap("OSM read: %d coast rings, %d paths, %d buildings, %d lighthouses, %d piers" % [_rings.size(), _paths.size(), _houses.size(), _lighthouses.size(), _piers.size()])
	_coast_distance()
	_lap("land mask and coast distance")
	_relief()
	_lap("relief (elevation tiles + noise)")
	_shape_paths()
	_lap("paths carved")
	_measure_grid()
	DirAccess.make_dir_recursive_absolute(OUT + "textures")
	_root = Node3D.new()
	_root.name = "RealIsland"
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
	_build_scene()
	_terrain = null
	quit(0)
	return true


func _lap(what: String) -> void:
	var now: int = Time.get_ticks_msec()
	print("%6d ms  %s" % [now - _clock, what])
	_clock = now


# ---------------------------------------------------------------- data

func to_local(lat: float, lon: float) -> Vector2:
	return Vector2((lon - lon0) * mx + N * 0.5, (lat0 - lat) * mz + N * 0.5)


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
			for i in ring.size() - 1:
				var a: Vector2 = ring[i]
				var b: Vector2 = ring[i + 1]
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
	for d in [d_in, d_out]:
		_chamfer(d)
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
		var img: Image = Image.load_from_file(ProjectSettings.globalize_path(DATA + "dem/%d_%d_%d.png" % [meta["zoom"], key.x, key.y]))
		_tiles[key] = img
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
			var lat: float = lat0 - (j * DEM_STEP - N * 0.5) / mz
			var lon: float = lon0 + (i * DEM_STEP - N * 0.5) / mx
			dem.set_pixel(i, j, Color(_elevation(lat, lon), 0, 0))
	dem.resize(N + DEM_STEP, N + DEM_STEP, Image.INTERPOLATE_CUBIC)
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
				_h[i] = lerpf(-0.6, minf(top, 3.0), smoothstep(0.0, 30.0, t))  # beach: a gentle slope
			else:
				_h[i] = lerpf(-1.5, top, smoothstep(0.0, CLIFF, t))  # cliff
		else:
			# Sea floor: a rocky shelf getting deeper offshore.
			_h[i] = -1.5 - minf(-t * 0.35, 20.0) + detail * 1.5


## Paths: distance band rasterised per segment (cheaper than every cell to
## every path), ground smoothed across them so they have no bumps.
func _shape_paths() -> void:
	_path_d.resize(N * N)
	_path_d.fill(99.0)
	for path in _paths:
		if path[3] or path[2] == "steps":
			continue  # bridges float; steps keep their slope
		var pts: PackedVector2Array = path[0]
		var half: float = path[1] * 0.5
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var lo: Vector2i = Vector2i(floori(minf(a.x, b.x) - 4), floori(minf(a.y, b.y) - 4)).clamp(Vector2i.ZERO, Vector2i(N - 1, N - 1))
			var hi: Vector2i = Vector2i(ceili(maxf(a.x, b.x) + 4), ceili(maxf(a.y, b.y) + 4)).clamp(Vector2i.ZERO, Vector2i(N - 1, N - 1))
			for z in range(lo.y, hi.y + 1):
				for x in range(lo.x, hi.x + 1):
					var p := Vector2(x, z)
					var d: float = p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) - half
					var k: int = z * N + x
					if d < _path_d[k]:
						_path_d[k] = d
	var src: PackedFloat32Array = _h.duplicate()
	for z in range(2, N - 2):
		for x in range(2, N - 2):
			var i: int = z * N + x
			if _path_d[i] > 2.0 or _t[i] <= 0.0:
				continue
			var s: float = 0.0
			for dz in range(-2, 3):
				for dx in range(-2, 3):
					s += src[i + dz * N + dx]
			_h[i] = lerpf(src[i], s / 25.0, clampf(1.0 - _path_d[i] / 2.0, 0.0, 1.0))


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


## How the horde grid would cope: 1 m cells, walkable = above the sea and no
## step over 0.9 m; breadth-first search from the middle of the island.
func _measure_grid() -> void:
	var t0: int = Time.get_ticks_msec()
	var blocked := PackedByteArray()
	blocked.resize(N * N)
	var land: int = 0
	var start: int = -1
	var best: float = -1.0
	for i in N * N:
		var b: bool = _h[i] < 0.15 or _slope(i) > 0.9
		blocked[i] = 1 if b else 0
		if not b:
			land += 1
			if _t[i] > best:
				best = _t[i]
				start = i
	var t1: int = Time.get_ticks_msec()
	var dist := PackedInt32Array()
	dist.resize(N * N)
	dist.fill(-1)
	var queue := PackedInt32Array()
	queue.resize(N * N)
	var head: int = 0
	var tail: int = 0
	queue[tail] = start
	tail += 1
	dist[start] = 0
	while head < tail:
		var i: int = queue[head]
		head += 1
		for o: int in [1, -1, N, -N]:
			var j: int = i + o
			if j >= 0 and j < N * N and blocked[j] == 0 and dist[j] < 0:
				dist[j] = dist[i] + 1
				queue[tail] = j
				tail += 1
	var t2: int = Time.get_ticks_msec()
	print("  grid %d x %d (%d cells): %d walkable, %d reachable from the middle" % [N, N, N * N, land, tail])
	print("  grid build %d ms, one full flow-field search %d ms (GDScript)" % [t1 - t0, t2 - t1])
	_clock = Time.get_ticks_msec()


# ---------------------------------------------------------------- scene

func _build_scene() -> void:
	_clock = Time.get_ticks_msec()
	var control := PackedFloat32Array()
	control.resize(N * N)
	var color := PackedByteArray()
	color.resize(N * N * 4)
	var tint := FastNoiseLite.new()
	tint.seed = 21
	tint.frequency = 0.01
	var patch := FastNoiseLite.new()
	patch.seed = 22
	patch.frequency = 0.06
	var tints: PackedByteArray = tint.get_image(N, N).get_data()
	var patches: PackedByteArray = patch.get_image(N, N).get_data()
	# Textures: 0 ground (grass and rock), 1 cliff rock, 2 shore, 3 gravel path.
	for i in N * N:
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
		if s > 1.2:
			base = 1
			blend = 0.0
		var b: int = clampi(roundi(clampf(blend, 0.0, 1.0) * 255.0), 0, 255)
		control[i] = Terrain3DUtil.as_float(Terrain3DUtil.enc_base(base) | Terrain3DUtil.enc_overlay(over) | Terrain3DUtil.enc_blend(b))
		var v: float = 0.88 + tints[i] / 255.0 * 0.12  # slight light/dark variation
		color[i * 4] = int(v * 225.0)
		color[i * 4 + 1] = int(v * 250.0)  # a little greener: the scrub in spring
		color[i * 4 + 2] = int(v * 215.0)
		color[i * 4 + 3] = 255
	var height_img := Image.create_from_data(N, N, false, Image.FORMAT_RF, _h.to_byte_array())
	var control_img := Image.create_from_data(N, N, false, Image.FORMAT_RF, control.to_byte_array())
	var color_img := Image.create_from_data(N, N, false, Image.FORMAT_RGBA8, color)
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
	var dir: String = OUT + "terrain"
	for f in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray():
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.make_dir_recursive_absolute(dir)
	data.call("save_directory", dir)
	_terrain.set("data_directory", dir)
	_lap("terrain: heights, textures per vertex, saved")
	for group in ["Buildings", "Paths", "Nature", "Sea"]:
		var n := Node3D.new()
		n.name = group
		_root.add_child(n)
		n.owner = _root
	_place_paths()
	_place_buildings()
	_lap("paths, bridges, %d buildings, lighthouse, pier" % _houses.size())
	_place_nature()
	_lap("scrub and rocks")
	_place_world()
	var packed := PackedScene.new()
	packed.pack(_root)
	var err: int = ResourceSaver.save(packed, OUT + "real_island.tscn")
	_lap("saved %s (%s)" % [OUT + "real_island.tscn", error_string(err)])


## Terrain3D textures from the Poly Haven maps: colour + displacement (height
## for blending) and normal + roughness packed the way Terrain3D wants.
func _ground_assets() -> Resource:
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
		ta.set("albedo_texture", _texture(albedo, "%s_albedo" % order[id]))
		ta.set("normal_texture", _texture(normal, "%s_normal" % order[id]))
		ta.set("uv_scale", scales[order[id]])
		ta.set("detiling_rotation", 0.3)
		assets.call("set_texture", id, ta)
	ResourceSaver.save(assets, OUT + "ground_assets.res")
	return load(OUT + "ground_assets.res")


func _tex(asset: String, file: String) -> Image:
	var img: Image = Image.load_from_file(ProjectSettings.globalize_path(DATA + "textures/%s_%s" % [asset, file]))
	img.convert(Image.FORMAT_RGBA8)
	if img.get_width() != 1024:
		img.resize(1024, 1024)
	return img


func _texture(img: Image, name: String) -> Texture2D:
	img.convert(Image.FORMAT_RGBA8)
	img.generate_mipmaps()
	var path: String = OUT + "textures/" + name + ".res"
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


func _place_paths() -> void:
	var stone := SurfaceTool.new()
	var road := SurfaceTool.new()
	var deck := SurfaceTool.new()
	for st: SurfaceTool in [stone, road, deck]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for path in _paths:
		var pts: PackedVector2Array = path[0]
		var w: float = path[1]
		if path[3]:
			_bridge(deck, pts, w)
		elif path[2] == "steps":
			_ribbon(stone, pts, w, 0.06)
		elif path[2] == "service":
			_ribbon(road, pts, w, 0.05)
	for item in [[stone, "Steps", Color(0.62, 0.6, 0.56)], [road, "Roads", Color(0.58, 0.56, 0.52)], [deck, "Bridges", Color(0.55, 0.52, 0.47)]]:
		var mesh: ArrayMesh = (item[0] as SurfaceTool).commit()
		if mesh.get_surface_count() == 0:
			continue
		var inst := MeshInstance3D.new()
		inst.name = item[1]
		inst.mesh = mesh
		inst.material_override = _mat(item[2])
		_add(inst, "Paths")


## Strip draped on the ground every metre (gravel paths are only texture).
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


## A stone bridge: straight deck between the ground at its two ends, with
## low parapets.
func _bridge(st: SurfaceTool, pts: PackedVector2Array, w: float) -> void:
	var a: Vector2 = pts[0]
	var b: Vector2 = pts[pts.size() - 1]
	var ha: float = height_at(a.x, a.y) + 0.1
	var hb: float = height_at(b.x, b.y) + 0.1
	var dir: Vector2 = (b - a).normalized()
	var side := Vector2(-dir.y, dir.x) * (w * 0.5 + 0.3)
	var p := [Vector3(a.x - side.x, ha, a.y - side.y), Vector3(a.x + side.x, ha, a.y + side.y), Vector3(b.x + side.x, hb, b.y + side.y), Vector3(b.x - side.x, hb, b.y - side.y)]
	_tri(st, p[0], p[1], p[2], Vector3.UP)
	_tri(st, p[0], p[2], p[3], Vector3.UP)
	var down := Vector3(0, -0.6, 0)
	var up := Vector3(0, 0.9, 0)
	for e: Array in [[p[0], p[3]], [p[1], p[2]]]:
		var out := Vector3(e[0].x - (p[0].x + p[1].x) * 0.5, 0, e[0].z - (p[0].z + p[1].z) * 0.5).normalized()
		_tri(st, e[0] + down, e[1] + down, e[1] + up, out)  # side and parapet
		_tri(st, e[0] + down, e[1] + up, e[0] + up, out)
		_tri(st, e[0] + up, e[1] + up, e[1] + up - out * 0.3, Vector3.UP)
		_tri(st, e[0] + up, e[1] + up - out * 0.3, e[0] + up - out * 0.3, Vector3.UP)
		_tri(st, e[0] - out * 0.3, e[1] - out * 0.3, e[1] + up - out * 0.3, -out)
		_tri(st, e[0] - out * 0.3, e[1] + up - out * 0.3, e[0] + up - out * 0.3, -out)


## Buildings from their real footprints: whitewashed walls from below the
## lowest ground up to the eaves, and a tiled hip roof (a fan to the centre).
func _place_buildings() -> void:
	var walls := SurfaceTool.new()
	var roofs := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	roofs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in _houses:
		var pts: PackedVector2Array = b[0]
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
		var eaves: float = hi + float(b[1])
		var shortest: float = INF
		for i in pts.size():
			var a: Vector2 = pts[i]
			var e: Vector2 = pts[(i + 1) % pts.size()]
			shortest = minf(shortest, a.distance_to(e))
			var out := Vector3((e - a).y, 0, -(e - a).x).normalized()
			if out.dot(Vector3(a.x - c.x, 0, a.y - c.y)) < 0.0:
				out = -out
			_tri(walls, Vector3(a.x, base, a.y), Vector3(e.x, base, e.y), Vector3(e.x, eaves, e.y), out)
			_tri(walls, Vector3(a.x, base, a.y), Vector3(e.x, eaves, e.y), Vector3(a.x, eaves, a.y), out)
		var ridge := Vector3(c.x, eaves + clampf(shortest * 0.35, 1.0, 2.5), c.y)
		for i in pts.size():
			var a := Vector3(pts[i].x, eaves, pts[i].y)
			var e := Vector3(pts[(i + 1) % pts.size()].x, eaves, pts[(i + 1) % pts.size()].y)
			var n: Vector3 = (e - a).cross(ridge - a).normalized()
			if n.y < 0.0:
				n = -n
			_tri(roofs, a, e, ridge, n)
	for item in [[walls, "Walls", Color(0.93, 0.92, 0.88)], [roofs, "Roofs", Color(0.72, 0.34, 0.22)]]:
		var inst := MeshInstance3D.new()
		inst.name = item[1]
		inst.mesh = (item[0] as SurfaceTool).commit()
		inst.material_override = _mat(item[2], 0.85)
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
		_add(mi, "Buildings")


func _kit_mesh(model: String) -> Mesh:
	var scene: Node = (load(KIT + model + ".gltf") as PackedScene).instantiate()
	var found: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (found[0] as MeshInstance3D).mesh if not found.is_empty() else null
	scene.free()
	return m


## Low scrub on the plateau and rocks on the cliff tops (MultiMesh: cheap).
func _place_nature() -> void:
	var near_house := PackedByteArray()
	near_house.resize(N * N)
	var rings: Array[PackedVector2Array] = []
	for b in _houses:
		rings.append(Geometry2D.offset_polygon(b[0], 2.0)[0] if not Geometry2D.offset_polygon(b[0], 2.0).is_empty() else b[0])
	near_house = _fill(rings)
	# [model, count, height m, min metres from the coast, drawn up to m]
	var specs: Array = [["Grass_Wispy_Short", 120000, 0.35, 6.0, 140.0], ["Grass_Common_Short", 60000, 0.3, 6.0, 120.0],
		["Grass_Wispy_Tall", 15000, 0.7, 6.0, 220.0], ["Bush_Common", 600, 0.9, 10.0, 400.0],
		["Rock_Medium_1", 500, 2.0, 2.0, 1500.0], ["Rock_Medium_2", 400, 1.5, 2.0, 1500.0]]
	for spec in specs:
		var mesh: Mesh = _kit_mesh(spec[0])
		if mesh == null:
			continue
		var rock: bool = String(spec[0]).begins_with("Rock")
		var target: float = spec[2]
		var xf: Array[Transform3D] = []
		var tries: int = 0
		while xf.size() < spec[1] and tries < spec[1] * 20:
			tries += 1
			var x: int = _rng.randi_range(2, N - 3)
			var z: int = _rng.randi_range(2, N - 3)
			var i: int = z * N + x
			var t: float = _t[i]
			if t < spec[3] or near_house[i] == 1 or _path_d[i] < 0.6 or _beach[i] == 1:
				continue
			if rock and (t > 25.0 or _slope(i) < 0.25):
				continue  # rocks along the cliff tops
			if not rock and _slope(i) > 0.55:
				continue
			var p := Vector2(x + _rng.randf(), z + _rng.randf())
			var s: float = target / maxf(mesh.get_aabb().size.y, 0.01) * _rng.randf_range(0.6, 1.4)
			var basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
			xf.append(Transform3D(basis, Vector3(p.x, height_at(p.x, p.y) - (0.4 * s if rock else 0.05), p.y)))
		# One node per 128 m chunk, hidden beyond its draw distance: drawing
		# every tuft of the island every frame costs far too much.
		var chunks: Dictionary = {}
		for t: Transform3D in xf:
			var key := Vector2i(floori(t.origin.x / 128.0), floori(t.origin.z / 128.0))
			if not chunks.has(key):
				chunks[key] = PackedFloat32Array()
			# Relative to the chunk centre: the draw distance is measured from the node.
			var o: Vector3 = t.origin - Vector3(key.x * 128.0 + 64.0, 0.0, key.y * 128.0 + 64.0)
			# Packed arrays are copied when read from a Dictionary: write it back.
			var arr: PackedFloat32Array = chunks[key]
			arr.append_array([t.basis.x.x, t.basis.x.y, t.basis.x.z, t.basis.y.x, t.basis.y.y, t.basis.y.z,
				t.basis.z.x, t.basis.z.y, t.basis.z.z, o.x, o.y, o.z])
			chunks[key] = arr
		var group := Node3D.new()
		group.name = spec[0]
		_add(group, "Nature")
		for key: Vector2i in chunks:
			var inst := MultiMeshInstance3D.new()
			inst.name = "%d_%d" % [key.x, key.y]
			inst.position = Vector3(key.x * 128.0 + 64.0, 0.0, key.y * 128.0 + 64.0)
			inst.set_script(load(DIR + "scatter.gd"))
			inst.set("mesh", mesh)
			inst.set("transforms", chunks[key])
			inst.visibility_range_end = spec[4] + 90.0  # + half a chunk diagonal
			inst.visibility_range_end_margin = 20.0
			inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			if not rock:
				inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			group.add_child(inst)
			inst.owner = _root


func _place_world() -> void:
	# Sea: dark transparent water with moving-looking normals.
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var plane := PlaneMesh.new()
	plane.size = Vector2(N * 3, N * 3)
	sea.mesh = plane
	sea.position = Vector3(N * 0.5, 0.0, N * 0.5)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.06, 0.22, 0.3, 0.88)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.06
	water.metallic_specular = 0.8
	var waves := NoiseTexture2D.new()
	waves.seamless = true
	waves.as_normal_map = true
	waves.bump_strength = 4.0
	var wn := FastNoiseLite.new()
	wn.frequency = 0.03
	waves.noise = wn
	water.normal_enabled = true
	water.normal_texture = waves
	water.normal_scale = 0.5
	water.uv1_scale = Vector3(N * 3 / 24.0, N * 3 / 24.0, 1)
	sea.material_override = water
	_add(sea, "Sea")
	# Sky3D: sky, clouds and sun at a golden afternoon hour.
	if ResourceLoader.exists(SKY3D):
		var sky: WorldEnvironment = (load(SKY3D) as GDScript).new()
		sky.name = "Sky3D"
		_root.add_child(sky)
		sky.owner = _root
		sky.set("current_time", 15.0)
		sky.set("game_time_enabled", false)
		var env: Environment = sky.environment
		if env != null:
			env.tonemap_mode = Environment.TONE_MAPPER_ACES
			env.ssao_enabled = true
			env.glow_enabled = true
			env.glow_intensity = 0.5
			env.fog_enabled = true
			env.fog_density = 0.00012  # a light sea haze far away
			env.fog_aerial_perspective = 0.4
	# Camera: free flight (fly_camera.gd), with the colour grading.
	var cam := Camera3D.new()
	cam.name = "FlyCamera"
	cam.set_script(load(DIR + "fly_camera.gd"))
	cam.far = 6000.0
	var middle := Vector2.ZERO
	var count: int = 0
	for i in range(0, N * N, 97):
		if _t[i] > 30.0:
			middle += Vector2(i % N, i / N)
			count += 1
	middle /= maxi(count, 1)
	var target := Vector3(middle.x, height_at(middle.x, middle.y), middle.y)
	_root.add_child(cam)
	cam.owner = _root
	cam.look_at_from_position(target + Vector3(-120, 170, 380), target)  # needs to be in the tree
