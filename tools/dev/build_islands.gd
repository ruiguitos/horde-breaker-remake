extends SceneTree
## Builds the hand-made route islands (beach, town, jungle, port) as
## HandmadeIsland scenes in game/world/handmade/islands/: sculpts the
## Terrain3D (coast, hills, plateaus with ramps and cliffs, flattened building
## plots, painted paths), places buildings, trees, rocks, ground cover and the
## markers from a layout written per biome below.
## The scenes are then ordinary editor scenes: open and tweak them by hand
## (re-running this script overwrites them).
## Run: godot --headless --path . --script res://tools/dev/build_islands.gd [-- beach town ...]

const OUT: String = "res://game/world/handmade/islands/"
const KIT: String = "res://assets/models/nature_megakit/"
const N: int = 256  ## island size = one Terrain3D region (256 m)
const C: float = N * 0.5

## Current layout (filled by the _design_* functions).
var biome: StringName
var coast_r0: float = 100.0
var coast_waves: Array = []        ## [amplitude, frequency, phase]
var hills: Array = []              ## [Vector2 centre, radius, height]
var plateaus: Array = []           ## [Vector2 centre, radius, height, ramp angle (rad)]
var paths: Array = []              ## [PackedVector2Array, width]
var plazas: Array = []             ## Rect2 paved / cleared areas
var buildings: Array = []          ## [Rect2, height, Color, kind]
var forests: Array = []            ## [Vector2 centre, radius, count, models, spacing, height]
var rock_count: int = 30
var cover: Array = []              ## [model, count, height]
var markers: Dictionary = {}
var palette: Dictionary = {}

var _h := PackedFloat32Array()     ## vertex heights (N x N)
var _rng := RandomNumberGenerator.new()
var _pending: Array = []
var _terrain: Node3D
var _root: HandmadeIsland
var _frames: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_pending = Array(args) if not args.is_empty() else ["beach", "town", "jungle", "port"]
	DirAccess.make_dir_recursive_absolute(OUT)
	_start_next()


func _start_next() -> void:
	if _pending.is_empty():
		quit(0)
		return
	_reset(StringName(_pending.pop_front()))
	call("_design_" + String(biome))
	_sculpt()
	_root = HandmadeIsland.new()
	_root.name = String(biome).capitalize() + "Island"
	_root.size = N
	_root.biome = biome
	root.add_child(_root)
	_terrain = ClassDB.instantiate(&"Terrain3D")
	_terrain.name = "Terrain3D"
	_terrain.set("region_size", 256)
	_terrain.set("vertex_spacing", 1.0)
	_terrain.set("collision_mode", 0)
	_root.add_child(_terrain)
	_terrain.owner = _root
	_frames = 0


func _process(_delta: float) -> bool:
	if _terrain == null:
		return false
	_frames += 1
	if _terrain.get("data") == null:
		return false
	_build_scene()
	_root.queue_free()
	_terrain = null
	_start_next()
	return false


func _reset(b: StringName) -> void:
	biome = b
	_rng.seed = hash(String(b))
	coast_r0 = 100.0
	coast_waves = []
	hills = []
	plateaus = []
	paths = []
	plazas = []
	buildings = []
	forests = []
	rock_count = 30
	cover = []
	markers = {}
	palette = {
		"sand": Color(0.86, 0.78, 0.55), "grass": Color(0.42, 0.56, 0.3),
		"dirt": Color(0.55, 0.43, 0.3), "cliff": Color(0.45, 0.4, 0.35),
		"paved": Color(0.55, 0.55, 0.52), "seabed": Color(0.6, 0.55, 0.4),
	}


# ---------------------------------------------------------------- layouts

## Dawn Beach: a wide crescent with dunes, a fishing village west of the
## landing, a lighthouse bluff in the north (ramp from the south) and three
## groves. The boardwalk leads from the boat to a crossroads.
func _design_beach() -> void:
	coast_r0 = 104.0
	coast_waves = [[7.0, 3, 0.4], [4.0, 5, 1.7], [2.0, 9, 0.2]]
	hills = [[Vector2(62, 92), 20.0, 5.0], [Vector2(196, 84), 24.0, 6.5], [Vector2(205, 165), 16.0, 4.0]]
	plateaus = [[Vector2(128, 50), 20.0, 7.0, PI * 0.5]]
	paths = [
		[_line([Vector2(128, 222), Vector2(128, 170), Vector2(128, 128)]), 7.0],
		[_line([Vector2(128, 128), Vector2(96, 122), Vector2(58, 118)]), 5.0],
		[_line([Vector2(128, 128), Vector2(165, 126), Vector2(200, 128)]), 5.0],
		[_line([Vector2(128, 128), Vector2(128, 96), Vector2(128, 70)]), 5.0],
		[_line([Vector2(128, 170), Vector2(100, 165), Vector2(78, 158)]), 4.0],
	]
	for i in 8:
		var p := Vector2(66 + (i % 4) * 14, 140 + (i / 4) * 30)
		buildings.append([Rect2(p, Vector2(7, 6)), 3.2, Color(0.72, 0.6, 0.45), "hut"])
	buildings.append([Rect2(Vector2(122, 38), Vector2(8, 8)), 10.0, Color(0.9, 0.9, 0.85), "tower"])
	forests = [
		[Vector2(70, 62), 26.0, 45, ["CommonTree_1", "CommonTree_3"], 5.0, 8.0],
		[Vector2(186, 158), 22.0, 35, ["CommonTree_2", "CommonTree_4"], 5.0, 8.0],
		[Vector2(170, 90), 16.0, 18, ["CommonTree_5"], 5.0, 7.5],
		[Vector2(200, 60), 14.0, 12, ["CommonTree_1"], 5.0, 7.0],
	]
	rock_count = 26
	cover = [["Grass_Wispy_Tall", 900, 0.9], ["Grass_Wispy_Short", 900, 0.6], ["Bush_Common", 120, 1.2]]
	markers = {
		"Boat": Vector2(128, 226), "PlayerStart": Vector2(128, 218),
		"Generator1": Vector2(56, 118), "Generator2": Vector2(202, 128), "Generator3": Vector2(132, 46),
		"Cache1": Vector2(92, 62), "Cache2": Vector2(178, 186), "Cache3": Vector2(52, 172), "Cache4": Vector2(214, 96),
	}


## Old Town: a grid of streets with blocks of houses, a central plaza with a
## fountain park, a church on a hill to the east (ramp from the west).
func _design_town() -> void:
	coast_r0 = 108.0
	coast_waves = [[5.0, 2, 1.1], [3.0, 5, 0.3]]
	plateaus = [[Vector2(212, 128), 18.0, 5.0, PI]]
	palette["grass"] = Color(0.45, 0.55, 0.33)
	var xs: Array = [56, 92, 128, 164, 200]
	var zs: Array = [64, 100, 136, 172, 208]
	for x in xs:
		paths.append([_line([Vector2(x, 64), Vector2(x, 208)]), 8.0])
	for z in zs:
		paths.append([_line([Vector2(56, z), Vector2(200, z)]), 8.0])
	paths.append([_line([Vector2(128, 228), Vector2(128, 208)]), 8.0])
	paths.append([_line([Vector2(194, 128), Vector2(212, 128)]), 6.0])
	plazas = [Rect2(Vector2(96, 104), Vector2(28, 28))]
	var colors: Array = [Color(0.85, 0.8, 0.65), Color(0.75, 0.55, 0.45), Color(0.6, 0.7, 0.75), Color(0.85, 0.85, 0.82), Color(0.7, 0.62, 0.5)]
	for bx in xs.size() - 1:
		for bz in zs.size() - 1:
			var block := Rect2(Vector2(xs[bx] + 6, zs[bz] + 6), Vector2(24, 24))
			if block.intersects(plazas[0]):
				continue
			# Two to four houses per block, leaving a cross-shaped alley.
			for q in 4:
				if _rng.randf() < 0.2:
					continue
				var w: float = _rng.randf_range(8, 10)
				var d: float = _rng.randf_range(7, 10)
				var px: float = block.position.x + (0.0 if q % 2 == 0 else 24.0 - w)
				var pz: float = block.position.y + (0.0 if q < 2 else 24.0 - d)
				buildings.append([Rect2(Vector2(px, pz), Vector2(w, d)), _rng.randf_range(4, 8), colors[_rng.randi() % colors.size()], "house"])
	buildings.append([Rect2(Vector2(208, 120), Vector2(10, 16)), 9.0, Color(0.8, 0.78, 0.72), "church"])
	forests = [
		[Vector2(110, 118), 9.0, 8, ["CommonTree_1", "CommonTree_2"], 5.0, 6.0],
		[Vector2(40, 150), 16.0, 14, ["CommonTree_3", "CommonTree_4"], 6.0, 7.0],
		[Vector2(170, 40), 16.0, 12, ["CommonTree_5", "CommonTree_2"], 6.0, 7.0],
	]
	rock_count = 10
	cover = [["Grass_Common_Short", 900, 0.5], ["Clover_1", 400, 0.4], ["Flower_3_Group", 200, 0.5]]
	markers = {
		"Boat": Vector2(128, 230), "PlayerStart": Vector2(128, 222),
		"Generator1": Vector2(56, 82), "Generator2": Vector2(200, 190), "Generator3": Vector2(146, 64),
		"Cache1": Vector2(74, 190), "Cache2": Vector2(110, 118), "Cache3": Vector2(182, 82), "Cache4": Vector2(222, 128),
	}


## Green Hell: dense forest cut by winding trails, clearings around the
## goals, hills and a temple plateau (ramp from the west) with ruins.
func _design_jungle() -> void:
	coast_r0 = 100.0
	coast_waves = [[10.0, 2, 0.8], [6.0, 4, 2.1], [3.0, 7, 0.5]]
	palette["grass"] = Color(0.28, 0.45, 0.22)
	palette["dirt"] = Color(0.42, 0.33, 0.22)
	hills = [[Vector2(70, 80), 22.0, 9.0], [Vector2(200, 170), 20.0, 7.0], [Vector2(80, 180), 16.0, 5.0]]
	plateaus = [[Vector2(160, 70), 22.0, 6.0, PI]]
	paths = [
		[_line([Vector2(128, 222), Vector2(120, 190), Vector2(132, 160), Vector2(118, 128)]), 6.0],
		[_line([Vector2(118, 128), Vector2(90, 120), Vector2(66, 128), Vector2(50, 116)]), 5.0],
		[_line([Vector2(118, 128), Vector2(140, 112), Vector2(130, 76), Vector2(138, 70)]), 5.0],
		[_line([Vector2(132, 160), Vector2(170, 150), Vector2(196, 128), Vector2(214, 120)]), 5.0],
		[_line([Vector2(120, 190), Vector2(100, 202), Vector2(86, 196)]), 4.0],
	]
	plazas = [Rect2(Vector2(40, 106), Vector2(22, 22)), Rect2(Vector2(204, 110), Vector2(20, 20)), Rect2(Vector2(108, 118), Vector2(20, 20))]
	for r in [[Rect2(Vector2(150, 58), Vector2(6, 6)), 4.0], [Rect2(Vector2(168, 62), Vector2(5, 9)), 3.0], [Rect2(Vector2(156, 80), Vector2(10, 4)), 2.5]]:
		buildings.append([r[0], r[1], Color(0.5, 0.52, 0.45), "ruin"])
	var trees: Array = ["CommonTree_1", "CommonTree_2", "CommonTree_4", "CommonTree_5", "Pine_1", "Pine_3"]
	forests = [
		[Vector2(70, 70), 40.0, 120, trees, 4.5, 8.0], [Vector2(190, 190), 40.0, 110, trees, 4.5, 8.0],
		[Vector2(70, 175), 34.0, 80, trees, 4.5, 8.0], [Vector2(200, 80), 30.0, 60, trees, 4.5, 8.0],
		[Vector2(128, 128), 70.0, 120, trees, 5.0, 8.0],
	]
	rock_count = 40
	cover = [["Fern_1", 1200, 1.0], ["Plant_1", 500, 0.9], ["Plant_7", 400, 1.0], ["Grass_Common_Tall", 900, 0.9]]
	markers = {
		"Boat": Vector2(128, 228), "PlayerStart": Vector2(128, 220),
		"Generator1": Vector2(50, 116), "Generator2": Vector2(214, 120), "Generator3": Vector2(162, 70),
		"Cache1": Vector2(118, 128), "Cache2": Vector2(86, 196), "Cache3": Vector2(70, 80), "Cache4": Vector2(200, 170),
	}


## Rust Harbour: a flat concrete port. Warehouses in the north, a container
## yard with straight aisles in the middle, cranes on the south quay.
func _design_port() -> void:
	coast_r0 = 108.0
	coast_waves = [[3.0, 4, 0.2], [2.0, 6, 1.0]]
	palette["grass"] = Color(0.5, 0.52, 0.45)
	plazas = [Rect2(Vector2(40, 40), Vector2(176, 180))]
	paths = [
		[_line([Vector2(128, 230), Vector2(128, 40)]), 10.0],
		[_line([Vector2(40, 104), Vector2(216, 104)]), 8.0],
		[_line([Vector2(40, 200), Vector2(216, 200)]), 8.0],
	]
	for i in 4:
		buildings.append([Rect2(Vector2(46 + i * 44 + (10 if i >= 2 else 0), 56), Vector2(30, 18)), 9.0, Color(0.55, 0.5, 0.45), "warehouse"])
	var paints: Array = [Color(0.75, 0.25, 0.15), Color(0.2, 0.4, 0.7), Color(0.85, 0.6, 0.15), Color(0.25, 0.55, 0.3)]
	for side in 2:
		for row in 6:
			var x0: float = (52.0 if side == 0 else 140.0)
			var z: float = 116 + row * 13
			if row == 3:
				continue  # cross aisle
			for k in 3:
				if _rng.randf() < 0.15:
					continue
				var stack: int = _rng.randi_range(1, 3)
				buildings.append([Rect2(Vector2(x0 + k * 21, z), Vector2(18, 7)), 2.6 * stack, paints[_rng.randi() % paints.size()], "containers"])
	forests = [[Vector2(36, 128), 12.0, 8, ["CommonTree_2"], 6.0, 6.0], [Vector2(222, 140), 12.0, 8, ["CommonTree_4"], 6.0, 6.0]]
	rock_count = 8
	cover = [["Grass_Common_Short", 300, 0.4], ["Pebble_Square_2", 300, 0.3]]
	markers = {
		"Boat": Vector2(128, 230), "PlayerStart": Vector2(122, 222),
		"Generator1": Vector2(48, 150), "Generator2": Vector2(212, 160), "Generator3": Vector2(128, 48),
		"Cache1": Vector2(90, 150), "Cache2": Vector2(166, 80), "Cache3": Vector2(78, 206), "Cache4": Vector2(178, 206),
	}


# ---------------------------------------------------------------- terrain

func _line(points: Array) -> PackedVector2Array:
	return PackedVector2Array(points)


func _coast(ang: float) -> float:
	var r: float = coast_r0
	for w in coast_waves:
		r += w[0] * sin(ang * w[1] + w[2])
	return r


## Metres inland from the coast (negative at sea).
func _inland(x: float, z: float) -> float:
	var v := Vector2(x - C, z - C)
	return _coast(v.angle()) - v.length()


func _path_distance(p: Vector2) -> float:
	var best: float = INF
	for path in paths:
		var pts: PackedVector2Array = path[0]
		for i in pts.size() - 1:
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			best = minf(best, p.distance_to(q) - path[1] * 0.5)
	return best


func _sculpt() -> void:
	# The landing is always on the south shore, 10 m inland from the coast.
	var shore: float = C + _coast(PI * 0.5)
	markers["Boat"] = Vector2(C, shore - 10.0)
	markers["PlayerStart"] = Vector2(C, shore - 17.0)
	var noise := FastNoiseLite.new()
	noise.seed = _rng.randi()
	noise.frequency = 0.02
	_h.resize(N * N)
	for z in N:
		for x in N:
			var t: float = _inland(x, z)
			# Shore: sea floor at -3 m rising to a low beach; inland a gentle
			# undulation (never steep enough to block).
			var land: float = 0.35 + (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 1.2 * smoothstep(4.0, 30.0, t)
			var h: float = lerpf(-3.0, land, smoothstep(-10.0, 6.0, t))
			for hill in hills:
				var d: float = Vector2(x, z).distance_to(hill[0])
				h += hill[2] * exp(-d * d / (hill[1] * hill[1] * 0.5)) * smoothstep(0.0, 10.0, t)
			for pl in plateaus:
				h = maxf(h, _plateau(pl, Vector2(x, z), h))
			_h[z * N + x] = h
	# Paths: smooth the ground along them (a road never has bumps).
	for z in N:
		for x in N:
			var pd: float = _path_distance(Vector2(x, z))
			if pd < 2.0 and _h[z * N + x] > 0.0:
				_h[z * N + x] = lerpf(_h[z * N + x], _smoothed(x, z, 3), clampf(1.0 - pd / 2.0, 0.0, 1.0))
	# Building plots and plazas: flat at their mean height, blended at the rim.
	var flats: Array = []
	for b in buildings:
		flats.append(b[0])
	flats.append_array(plazas)
	for r: Rect2 in flats:
		var mean: float = _mean_height(r)
		var grown: Rect2 = r.grow(3.0)
		for z in range(maxi(0, int(grown.position.y)), mini(N, int(grown.end.y) + 1)):
			for x in range(maxi(0, int(grown.position.x)), mini(N, int(grown.end.x) + 1)):
				if _inland(x, z) < 4.0:
					continue  # plots never push land into the sea
				var out: float = _rect_distance(r, Vector2(x, z))
				var k: float = clampf(1.0 - out / 3.0, 0.0, 1.0)
				_h[z * N + x] = lerpf(_h[z * N + x], mean, k)


## Plateau: flat top, a cliff all round except a ramp facing `ang`.
func _plateau(pl: Array, p: Vector2, under: float) -> float:
	var centre: Vector2 = pl[0]
	var r: float = pl[1]
	var top: float = pl[2]
	var d: float = p.distance_to(centre)
	if d <= r:
		return top
	var dir: Vector2 = (p - centre).normalized()
	var facing: float = dir.dot(Vector2.from_angle(pl[3]))
	if facing > 0.93 and d < r + 26.0:
		return lerpf(top, under, smoothstep(r, r + 26.0, d))  # ramp, about 1:4
	if d < r + 1.2:
		return lerpf(top, under, (d - r) / 1.2)  # cliff
	return -INF


func _smoothed(x: int, z: int, k: int) -> float:
	var s: float = 0.0
	var n: int = 0
	for dz in range(-k, k + 1):
		for dx in range(-k, k + 1):
			var xx: int = clampi(x + dx, 0, N - 1)
			var zz: int = clampi(z + dz, 0, N - 1)
			s += _h[zz * N + xx]
			n += 1
	return s / n


func _mean_height(r: Rect2) -> float:
	var s: float = 0.0
	var n: int = 0
	for z in range(int(r.position.y), int(r.end.y) + 1):
		for x in range(int(r.position.x), int(r.end.x) + 1):
			if x >= 0 and z >= 0 and x < N and z < N:
				s += _h[z * N + x]
				n += 1
	return maxf(s / maxi(n, 1), 0.3)


func _rect_distance(r: Rect2, p: Vector2) -> float:
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dz: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return Vector2(dx, dz).length()


func height_at(x: float, z: float) -> float:
	var fx: float = clampf(x, 0.0, N - 1.001)
	var fz: float = clampf(z, 0.0, N - 1.001)
	var x0: int = int(fx)
	var z0: int = int(fz)
	var a: float = lerpf(_h[z0 * N + x0], _h[z0 * N + x0 + 1], fx - x0)
	var b: float = lerpf(_h[(z0 + 1) * N + x0], _h[(z0 + 1) * N + x0 + 1], fx - x0)
	return lerpf(a, b, fz - z0)


func _slope(x: int, z: int) -> float:
	var h: float = _h[z * N + x]
	var s: float = 0.0
	for o: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
		var xx: int = clampi(x + o.x, 0, N - 1)
		var zz: int = clampi(z + o.y, 0, N - 1)
		s = maxf(s, absf(_h[zz * N + xx] - h))
	return s


func _colour(x: int, z: int) -> Color:
	var h: float = _h[z * N + x]
	if h < -0.3:
		return palette["seabed"].darkened(clampf(-h / 6.0, 0.0, 0.4))
	var t: float = _inland(x, z)
	var c: Color = palette["sand"].lerp(palette["grass"], smoothstep(4.0, 14.0, t))
	for r: Rect2 in plazas:
		if r.grow(1.0).has_point(Vector2(x, z)):
			c = palette["paved"] if biome in [&"town", &"port"] else palette["dirt"].lerp(c, 0.3)
	if _slope(x, z) > 0.6:
		c = palette["cliff"]
	var pd: float = _path_distance(Vector2(x, z))
	if pd < 0.0:
		c = palette["paved"] if biome in [&"town", &"port"] else palette["dirt"]
	elif pd < 1.5:
		c = c.lerp(palette["dirt"], 0.5)
	return c.darkened(_rng.randf() * 0.05)


# ---------------------------------------------------------------- scene

func _build_scene() -> void:
	var name: String = "%s_01" % biome
	var height := Image.create_empty(N, N, false, Image.FORMAT_RF)
	var color := Image.create_empty(N, N, false, Image.FORMAT_RGBA8)
	for z in N:
		for x in N:
			height.set_pixel(x, z, Color(_h[z * N + x], 0, 0))
			color.set_pixel(x, z, _colour(x, z))
	var mat: Object = _terrain.get("material")
	if mat != null:
		mat.set("world_background", 0)
	_terrain.set("assets", load("res://game/world/handmade/ground_assets.res"))
	var data: Object = _terrain.get("data")
	data.call("import_images", [height, null, color], Vector3.ZERO, 0.0, 1.0)
	var dir: String = OUT + name + "_data"
	for f in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray():
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.make_dir_recursive_absolute(dir)
	data.call("save_directory", dir)
	_terrain.set("data_directory", dir)
	for group in ["Buildings", "Trees", "Rocks", "Decor", "Markers"]:
		var n := Node3D.new()
		n.name = group
		_root.add_child(n)
		n.owner = _root
	_place_sea()
	_place_buildings()
	var taken: Array[Vector2] = []
	for m: String in markers:
		taken.append(markers[m])
	_place_trees(taken)
	_place_rocks(taken)
	_place_cover()
	for m: String in markers:
		var mk := Marker3D.new()
		mk.name = m
		mk.gizmo_extents = 3.0
		var p: Vector2 = markers[m]
		mk.position = Vector3(p.x, height_at(p.x, p.y), p.y)
		_add(mk, "Markers")
	var packed := PackedScene.new()
	packed.pack(_root)
	var err := ResourceSaver.save(packed, OUT + name + ".tscn")
	var problems: Array[String] = []
	var map: IslandMap = _root.build_map(problems)
	HandmadeIsland.grid_image(map).save_png(OUT + name + "_grid.png")
	var open: int = 0
	for b in map.field.blocked:
		open += 1 if b == 0 else 0
	print("%s: %s, walkable %d, buildings %d, trees %d, problems %s" % [name, error_string(err), open, map.buildings.size(), map.trees.size(), problems])


func _add(n: Node, group: String) -> void:
	_root.get_node(group).add_child(n)
	n.owner = _root


func _place_sea() -> void:
	var sea := MeshInstance3D.new()
	sea.name = "SeaPreview"
	var plane := PlaneMesh.new()
	plane.size = Vector2(700, 700)
	sea.mesh = plane
	sea.position = Vector3(C, -0.3, C)
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.15, 0.35, 0.55, 0.8)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sea.material_override = water
	_add(sea, "Decor")


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _place_buildings() -> void:
	var count: Dictionary = {}
	for b in buildings:
		var r: Rect2 = b[0]
		var h: float = b[1]
		var kind: String = b[3]
		count[kind] = count.get(kind, 0) + 1
		var node := Node3D.new()
		node.name = "%s_%02d" % [kind.capitalize(), count[kind]]
		var base: float = height_at(r.get_center().x, r.get_center().y)
		node.position = Vector3(r.get_center().x, base, r.get_center().y)
		_add(node, "Buildings")
		if kind == "containers":
			var levels: int = maxi(1, roundi(h / 2.6))
			for k in levels:
				var box := MeshInstance3D.new()
				box.name = "Container%d" % k
				var bm := BoxMesh.new()
				bm.size = Vector3(r.size.x, 2.5, r.size.y)
				box.mesh = bm
				box.position = Vector3(0, 1.25 + k * 2.6, 0)
				box.material_override = _mat(Color(b[2]).darkened(k * 0.12))
				node.add_child(box)
				box.owner = _root
			continue
		var body := MeshInstance3D.new()
		body.name = "Body"
		var bm := BoxMesh.new()
		bm.size = Vector3(r.size.x, h, r.size.y)
		body.mesh = bm
		body.position = Vector3(0, h * 0.5 - 0.3, 0)  # sunk a little: no gaps on slopes
		body.material_override = _mat(b[2])
		node.add_child(body)
		body.owner = _root
		if kind in ["house", "hut", "church"]:
			var roof := MeshInstance3D.new()
			roof.name = "Roof"
			var pm := PrismMesh.new()
			pm.size = Vector3(r.size.x + 0.8, 2.2, r.size.y + 0.8)
			roof.mesh = pm
			roof.position = Vector3(0, h - 0.3 + 1.1, 0)
			roof.material_override = _mat(Color(0.55, 0.25, 0.18) if kind != "hut" else Color(0.75, 0.65, 0.4))
			node.add_child(roof)
			roof.owner = _root
		if kind == "church" or kind == "tower":
			var spire := MeshInstance3D.new()
			spire.name = "Spire"
			var sm := CylinderMesh.new()
			sm.top_radius = 0.2
			sm.bottom_radius = 2.0
			sm.height = 6.0
			spire.mesh = sm
			spire.position = Vector3(0, h + 3.0, 0)
			spire.material_override = _mat(Color(0.35, 0.3, 0.3))
			node.add_child(spire)
			spire.owner = _root


## Free spot for a tree or rock: on land, flat enough, off paths, plazas,
## building plots and markers, at least `spacing` from `taken`.
func _free(p: Vector2, taken: Array[Vector2], spacing: float) -> bool:
	if p.x < 4 or p.y < 4 or p.x > N - 5 or p.y > N - 5:
		return false
	if _inland(p.x, p.y) < 8.0 or _slope(int(p.x), int(p.y)) > 0.5 or height_at(p.x, p.y) < 0.2:
		return false
	if _path_distance(p) < 2.5:
		return false
	for r: Rect2 in plazas:
		if r.grow(1.0).has_point(p) and biome not in [&"port", &"town"]:
			return false
	for b in buildings:
		if (b[0] as Rect2).grow(3.0).has_point(p):
			return false
	for m: String in markers:
		if p.distance_to(markers[m]) < 7.0:
			return false
	for q in taken:
		if p.distance_squared_to(q) < spacing * spacing:
			return false
	return true


func _place_trees(taken: Array[Vector2]) -> void:
	var n: int = 0
	for f in forests:
		var placed: int = 0
		var tries: int = 0
		while placed < f[2] and tries < f[2] * 40:
			tries += 1
			var p: Vector2 = f[0] + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * f[1]
			if not _free(p, taken, f[4]):
				continue
			var model: String = f[3][_rng.randi() % f[3].size()]
			var tree: Node3D = (load(KIT + model + ".gltf") as PackedScene).instantiate()
			n += 1
			tree.name = "Tree_%03d" % n
			var target: float = f[5] * _rng.randf_range(0.8, 1.2)
			tree.scale = Vector3.ONE * _model_scale(tree, target)
			tree.rotation.y = _rng.randf() * TAU
			tree.position = Vector3(floorf(p.x) + 0.5, height_at(p.x, p.y) - 0.1, floorf(p.y) + 0.5)
			_add(tree, "Trees")
			taken.append(p)
			placed += 1


func _place_rocks(taken: Array[Vector2]) -> void:
	var n: int = 0
	var tries: int = 0
	while n < rock_count and tries < 4000:
		tries += 1
		var p := Vector2(_rng.randf_range(10, N - 10), _rng.randf_range(10, N - 10))
		if not _free(p, taken, 10.0):
			continue
		var rock: Node3D = (load(KIT + "Rock_Medium_%d.gltf" % _rng.randi_range(1, 3)) as PackedScene).instantiate()
		n += 1
		rock.name = "Rock_%02d" % n
		rock.scale = Vector3.ONE * _model_scale(rock, _rng.randf_range(1.2, 2.0))
		rock.rotation.y = _rng.randf() * TAU
		rock.position = Vector3(p.x, height_at(p.x, p.y) - 0.2, p.y)
		_add(rock, "Rocks")
		taken.append(p)


## Ground cover: one MultiMesh per model (cheap, never blocks).
func _place_cover() -> void:
	for c in cover:
		var m: Mesh = NatureKit.mesh(c[0])
		if m == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = m
		var xf: Array[Transform3D] = []
		var tries: int = 0
		while xf.size() < c[1] and tries < c[1] * 10:
			tries += 1
			var p := Vector2(_rng.randf_range(4, N - 4), _rng.randf_range(4, N - 4))
			if _inland(p.x, p.y) < 3.0 or _path_distance(p) < 0.5 or height_at(p.x, p.y) < 0.1:
				continue
			var blocked: bool = false
			for b in buildings:
				if (b[0] as Rect2).grow(0.5).has_point(p):
					blocked = true
					break
			for r: Rect2 in plazas:
				if r.has_point(p) and biome in [&"town", &"port"]:
					blocked = true
			if blocked:
				continue
			var s: float = NatureKit.scale_for(m, c[2]) * _rng.randf_range(0.7, 1.3)
			xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, height_at(p.x, p.y) - 0.05, p.y)))
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Cover_" + String(c[0])
		inst.multimesh = mm
		_add(inst, "Decor")


func _model_scale(n: Node3D, target: float) -> float:
	var box := AABB()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		box = box.merge((m as MeshInstance3D).get_aabb())
	return target / box.size.y if box.size.y > 0.01 else 1.0
