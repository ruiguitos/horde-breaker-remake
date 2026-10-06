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
var plateaus: Array = []           ## [Vector2 centre, radius, height, ramp angles (rad, Array)]
var rivers: Array = []             ## [PackedVector2Array, width]: carved below the sea (blocks)
var crossings: Array = []          ## [Vector2 centre, radius, "bridge" | "ford"]: land across a river
var ridges: Array = []             ## [PackedVector2Array, width, height, gaps (Array[Vector2])]
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
	rivers = []
	crossings = []
	ridges = []
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

## Dawn Beach. A creek cuts the island in two: the landing is south of it.
##   Short routes: the narrow bridge (centre), the gap in the eastern dunes,
##   the bluff's south ramp. Long routes: the wide western ford through the
##   village, round the north end of the dunes, the bluff's east ramp.
##   Arenas: the crossroads clearing, the village square.
func _design_beach() -> void:
	markers = {
		"Generator1": Vector2(55, 117), "Generator2": Vector2(206, 88), "Generator3": Vector2(132, 46),
		"Cache1": Vector2(92, 62), "Cache2": Vector2(184, 176), "Cache3": Vector2(60, 186), "Cache4": Vector2(186, 60),
		"Choke_Bridge": Vector2(128, 149), "Choke_DuneGap": Vector2(197, 95), "Choke_BluffRamp": Vector2(128, 80),
		"Arena_Crossroads": Vector2(128, 113), "Arena_Village": Vector2(55, 117),
	}
	coast_r0 = 104.0
	coast_waves = [[7.0, 3, 0.4], [4.0, 5, 1.7], [2.0, 9, 0.2]]
	hills = [[Vector2(70, 70), 18.0, 4.0], [Vector2(170, 196), 14.0, 3.0]]
	plateaus = [[Vector2(128, 50), 20.0, 7.0, [PI * 0.5, 0.0]]]
	rivers = [[_line([Vector2(0, 150), Vector2(60, 142), Vector2(100, 152), Vector2(150, 146), Vector2(200, 156), Vector2(256, 150)]), 10.0]]
	crossings = [[Vector2(128, 148.7), 3.0, "bridge"], [Vector2(55, 143.2), 8.0, "ford"]]
	ridges = [[_line([Vector2(178, 70), Vector2(197, 95), Vector2(210, 125), Vector2(214, 152)]), 6.0, 3.5, [Vector2(197, 95)]]]
	paths = [
		[_line([Vector2(128, 226), Vector2(128, 170), Vector2(128, 149), Vector2(128, 113)]), 6.0],
		[_line([Vector2(128, 192), Vector2(88, 178), Vector2(55, 160), Vector2(55, 143), Vector2(55, 117)]), 5.0],
		[_line([Vector2(70, 117), Vector2(100, 112), Vector2(128, 113)]), 5.0],
		[_line([Vector2(128, 100), Vector2(128, 78)]), 5.0],
		[_line([Vector2(146, 113), Vector2(175, 100), Vector2(197, 95), Vector2(206, 88)]), 5.0],
		[_line([Vector2(148, 50), Vector2(176, 54), Vector2(194, 66), Vector2(206, 88)]), 4.0],
	]
	plazas = [Rect2(Vector2(110, 100), Vector2(36, 26)), Rect2(Vector2(40, 104), Vector2(30, 26))]
	for p in [Vector2(36, 92), Vector2(48, 92), Vector2(60, 92), Vector2(74, 104), Vector2(74, 116), Vector2(26, 108)]:
		buildings.append([Rect2(p, Vector2(7, 6)), 3.2, Color(0.72, 0.6, 0.45), "hut"])
	buildings.append([Rect2(Vector2(118, 36), Vector2(7, 7)), 10.0, Color(0.9, 0.9, 0.85), "tower"])
	forests = [
		[Vector2(80, 62), 24.0, 40, ["CommonTree_1", "CommonTree_3"], 5.0, 8.0],
		[Vector2(176, 196), 20.0, 30, ["CommonTree_2", "CommonTree_4"], 5.0, 8.0],
		[Vector2(160, 80), 12.0, 12, ["CommonTree_5"], 5.0, 7.5],
		[Vector2(80, 200), 16.0, 18, ["CommonTree_1"], 5.0, 7.0],
	]
	rock_count = 20
	cover = [["Grass_Wispy_Tall", 900, 0.9], ["Grass_Wispy_Short", 900, 0.6], ["Bush_Common", 120, 1.2]]


## Old Town. A canal splits the old quarter (north) from the harbour side.
##   Short routes: the narrow middle bridge, the yard's front gate, the
##   church's west steps. Long routes: the side bridges, the yard's back
##   gate, the church's north ramp. Houses packed with 3 m alleys.
##   Arenas: the south square, the north market.
func _design_town() -> void:
	markers = {
		"Generator1": Vector2(41, 103), "Generator2": Vector2(220, 160), "Generator3": Vector2(128, 60),
		"Cache1": Vector2(150, 179), "Cache2": Vector2(70, 140), "Cache3": Vector2(186, 100), "Cache4": Vector2(96, 100),
		"Choke_MiddleBridge": Vector2(128, 118), "Choke_YardGate": Vector2(54, 103), "Choke_ChurchSteps": Vector2(190, 152),
		"Arena_Square": Vector2(128, 179), "Arena_Market": Vector2(128, 61),
	}
	coast_r0 = 108.0
	coast_waves = [[5.0, 2, 1.1], [3.0, 5, 0.3]]
	palette["grass"] = Color(0.45, 0.55, 0.33)
	plateaus = [[Vector2(212, 152), 16.0, 5.0, [PI, -PI * 0.5]]]
	rivers = [[_line([Vector2(0, 122), Vector2(80, 116), Vector2(176, 120), Vector2(256, 116)]), 10.0]]
	crossings = [[Vector2(128, 118), 3.0, "bridge"], [Vector2(70, 116.8), 4.5, "bridge"], [Vector2(186, 119.5), 4.5, "bridge"]]
	paths = [
		[_line([Vector2(128, 228), Vector2(128, 44)]), 10.0],
		[_line([Vector2(70, 200), Vector2(70, 60)]), 8.0],
		[_line([Vector2(186, 200), Vector2(186, 60)]), 8.0],
		[_line([Vector2(40, 84), Vector2(216, 84)]), 8.0],
		[_line([Vector2(40, 160), Vector2(196, 160)]), 8.0],
		[_line([Vector2(70, 196), Vector2(186, 196)]), 8.0],
		[_line([Vector2(186, 152), Vector2(196, 152)]), 6.0],
	]
	plazas = [Rect2(Vector2(100, 168), Vector2(56, 22)), Rect2(Vector2(96, 48), Vector2(64, 26)), Rect2(Vector2(28, 92), Vector2(26, 22))]
	# Walled yard (generator 1): front gate east, back gate north.
	_wall(Vector2(28, 92), Vector2(38, 92))
	_wall(Vector2(44, 92), Vector2(54, 92))
	_wall(Vector2(28, 114), Vector2(54, 114))
	_wall(Vector2(54, 92), Vector2(54, 100))
	_wall(Vector2(54, 106), Vector2(54, 114))
	buildings.append([Rect2(Vector2(206, 138), Vector2(10, 12)), 9.0, Color(0.8, 0.78, 0.72), "church"])
	var colors: Array = [Color(0.85, 0.8, 0.65), Color(0.75, 0.55, 0.45), Color(0.6, 0.7, 0.75), Color(0.85, 0.85, 0.82), Color(0.7, 0.62, 0.5)]
	_fill_houses(Rect2(Vector2(30, 40), Vector2(196, 180)), colors)
	forests = [
		[Vector2(40, 150), 14.0, 10, ["CommonTree_3", "CommonTree_4"], 6.0, 7.0],
		[Vector2(170, 40), 14.0, 10, ["CommonTree_5", "CommonTree_2"], 6.0, 7.0],
	]
	rock_count = 6
	cover = [["Grass_Common_Short", 900, 0.5], ["Clover_1", 400, 0.4], ["Flower_3_Group", 200, 0.5]]


## Green Hell. A river runs across the jungle north of the landing.
##   Short route: the rope bridge in the middle. Long routes: the west and
##   east fords. The temple plateau has a west and a south ramp.
##   Arenas: the southern clearing, the temple top.
func _design_jungle() -> void:
	markers = {
		"Generator1": Vector2(50, 87), "Generator2": Vector2(210, 111), "Generator3": Vector2(154, 56),
		"Cache1": Vector2(114, 162), "Cache2": Vector2(86, 196), "Cache3": Vector2(75, 62), "Cache4": Vector2(196, 196),
		"Choke_RopeBridge": Vector2(128, 126), "Choke_TempleSouthRamp": Vector2(152, 92),
		"Arena_Clearing": Vector2(114, 162), "Arena_Temple": Vector2(154, 56),
	}
	coast_r0 = 100.0
	coast_waves = [[10.0, 2, 0.8], [6.0, 4, 2.1], [3.0, 7, 0.5]]
	palette["grass"] = Color(0.28, 0.45, 0.22)
	palette["dirt"] = Color(0.42, 0.33, 0.22)
	hills = [[Vector2(75, 62), 20.0, 8.0], [Vector2(196, 196), 18.0, 6.0], [Vector2(62, 188), 14.0, 4.0]]
	plateaus = [[Vector2(152, 58), 22.0, 6.0, [PI, PI * 0.5]]]
	rivers = [[_line([Vector2(0, 108), Vector2(55, 117), Vector2(100, 112), Vector2(128, 126), Vector2(170, 138), Vector2(205, 146), Vector2(256, 160)]), 12.0]]
	crossings = [[Vector2(128, 126), 2.5, "bridge"], [Vector2(55, 117), 7.0, "ford"], [Vector2(205, 146), 7.0, "ford"]]
	paths = [
		[_line([Vector2(128, 222), Vector2(120, 186), Vector2(126, 160), Vector2(128, 126), Vector2(134, 104), Vector2(152, 92)]), 5.0],
		[_line([Vector2(120, 186), Vector2(84, 166), Vector2(56, 140), Vector2(55, 117), Vector2(50, 88)]), 5.0],
		[_line([Vector2(126, 160), Vector2(172, 166), Vector2(205, 160), Vector2(205, 146), Vector2(210, 112)]), 5.0],
		[_line([Vector2(50, 88), Vector2(90, 60), Vector2(124, 58)]), 4.0],
		[_line([Vector2(210, 112), Vector2(196, 90), Vector2(166, 86)]), 4.0],
	]
	plazas = [Rect2(Vector2(98, 150), Vector2(32, 24)), Rect2(Vector2(38, 76), Vector2(24, 22)), Rect2(Vector2(198, 100), Vector2(24, 22))]
	for r in [[Rect2(Vector2(140, 44), Vector2(6, 6)), 4.0], [Rect2(Vector2(162, 48), Vector2(5, 9)), 3.0], [Rect2(Vector2(146, 70), Vector2(10, 4)), 2.5], [Rect2(Vector2(166, 66), Vector2(4, 4)), 3.5]]:
		buildings.append([r[0], r[1], Color(0.5, 0.52, 0.45), "ruin"])
	var trees: Array = ["CommonTree_1", "CommonTree_2", "CommonTree_4", "CommonTree_5", "Pine_1", "Pine_3"]
	forests = [
		[Vector2(75, 60), 36.0, 100, trees, 4.5, 8.0], [Vector2(196, 196), 36.0, 90, trees, 4.5, 8.0],
		[Vector2(70, 185), 30.0, 70, trees, 4.5, 8.0], [Vector2(205, 80), 28.0, 50, trees, 4.5, 8.0],
		[Vector2(128, 128), 75.0, 130, trees, 5.0, 8.0],
	]
	rock_count = 36
	cover = [["Fern_1", 1200, 1.0], ["Plant_1", 500, 0.9], ["Plant_7", 400, 1.0], ["Grass_Common_Tall", 900, 0.9]]


## Rust Harbour. An inner basin reaches in from the west quay.
##   Short routes: the swing bridge over the basin, the gaps between the
##   warehouses, the narrow container aisles. Long routes: round the basin's
##   end, round the warehouse row, the wide central lane.
##   Arenas: the south quay, the central lane crossing.
func _design_port() -> void:
	markers = {
		"Generator1": Vector2(50, 124), "Generator2": Vector2(214, 124), "Generator3": Vector2(96, 44),
		"Cache1": Vector2(62, 196), "Cache2": Vector2(166, 86), "Cache3": Vector2(176, 200), "Cache4": Vector2(128, 124),
		"Choke_SwingBridge": Vector2(70, 162), "Choke_WarehouseGap": Vector2(77, 63),
		"Arena_Quay": Vector2(170, 196), "Arena_Crossing": Vector2(128, 142),
	}
	coast_r0 = 108.0
	coast_waves = [[3.0, 4, 0.2], [2.0, 6, 1.0]]
	palette["grass"] = Color(0.5, 0.52, 0.45)
	plazas = [Rect2(Vector2(36, 36), Vector2(184, 188))]
	rivers = [[_line([Vector2(0, 162), Vector2(104, 162)]), 14.0]]
	crossings = [[Vector2(70, 162), 2.5, "bridge"]]
	paths = [
		[_line([Vector2(128, 230), Vector2(128, 40)]), 10.0],
		[_line([Vector2(40, 104), Vector2(216, 104)]), 8.0],
		[_line([Vector2(40, 142), Vector2(216, 142)]), 8.0],
		[_line([Vector2(70, 142), Vector2(70, 190), Vector2(122, 196)]), 5.0],
	]
	for x in [44, 80, 146, 182]:
		buildings.append([Rect2(Vector2(x, 54), Vector2(30, 18)), 9.0, Color(0.55, 0.5, 0.45), "warehouse"])
	var paints: Array = [Color(0.75, 0.25, 0.15), Color(0.2, 0.4, 0.7), Color(0.85, 0.6, 0.15), Color(0.25, 0.55, 0.3)]
	_containers(Rect2(Vector2(36, 110), Vector2(184, 28)), paints)
	_containers(Rect2(Vector2(136, 150), Vector2(80, 16)), paints)
	for x in [40, 88]:
		buildings.append([Rect2(Vector2(x, 176), Vector2(14, 10)), 5.0, Color(0.6, 0.58, 0.55), "shed"])
	forests = [[Vector2(36, 128), 10.0, 6, ["CommonTree_2"], 6.0, 6.0], [Vector2(222, 140), 10.0, 6, ["CommonTree_4"], 6.0, 6.0]]
	rock_count = 6
	cover = [["Grass_Common_Short", 300, 0.4], ["Pebble_Square_2", 300, 0.3]]


## Thin wall from a to b (axis-aligned), 1 m thick.
func _wall(a: Vector2, b: Vector2) -> void:
	var r := Rect2(a, Vector2.ZERO).expand(b)
	r = r.grow_individual(0.5 if r.size.x < 0.1 else 0.0, 0.5 if r.size.y < 0.1 else 0.0, 0.5 if r.size.x < 0.1 else 0.0, 0.5 if r.size.y < 0.1 else 0.0)
	buildings.append([r, 2.4, Color(0.62, 0.58, 0.52), "wall"])


## Houses on every free lot of `area`: off streets, canal, plazas, plateaus
## and markers, 3 m alleys between them (the town's narrow choke points).
func _fill_houses(area: Rect2, colors: Array) -> void:
	var z: float = area.position.y
	while z < area.end.y:
		var x: float = area.position.x
		while x < area.end.x:
			var r := Rect2(Vector2(x, z), Vector2(_rng.randf_range(8, 11), _rng.randf_range(7, 10)))
			if _lot_free(r):
				buildings.append([r, _rng.randf_range(4, 8), colors[_rng.randi() % colors.size()], "house"])
				x += r.size.x + 3.0
			else:
				x += 4.0
		z += 13.0


func _lot_free(r: Rect2) -> bool:
	for corner in [r.position, r.end, Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), r.get_center()]:
		if _inland(corner.x, corner.y) < 10.0 or _path_distance(corner) < 1.5:
			return false
		for rv in rivers:
			if _line_distance(corner, rv[0]) < rv[1] * 0.5 + 5.0:
				return false
	for path in paths:
		var pts: PackedVector2Array = path[0]
		for i in pts.size() - 1:
			# A street crossing the lot (all corners clear, middle on it).
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(r.get_center(), pts[i], pts[i + 1])
			if r.grow(path[1] * 0.5 + 1.0).has_point(q):
				return false
	for pz: Rect2 in plazas:
		if pz.grow(3.0).intersects(r):
			return false
	for pl in plateaus:
		if r.get_center().distance_to(pl[0]) < pl[1] + 28.0:
			return false
	for b in buildings:
		if (b[0] as Rect2).grow(2.9).intersects(r):
			return false
	for m: String in markers:
		if r.grow(6.0).has_point(markers[m]):
			return false
	return true


## Container rows in `area`: 6 m deep rows with 3.5 m aisles, stacks of
## 1-3, a gap every few containers, the central lane kept clear.
func _containers(area: Rect2, paints: Array) -> void:
	var z: float = area.position.y
	while z + 6.0 <= area.end.y:
		var x: float = area.position.x
		while x + 12.0 <= area.end.x:
			var r := Rect2(Vector2(x, z), Vector2(12, 6))
			var clear: bool = absf(r.get_center().x - 128.0) > 13.0
			for m: String in markers:
				if r.grow(5.0).has_point(markers[m]):
					clear = false
			if clear and _rng.randf() > 0.12:
				buildings.append([r, 2.6 * _rng.randi_range(1, 3), paints[_rng.randi() % paints.size()], "containers"])
			x += 12.0 + (3.5 if _rng.randf() < 0.35 else 0.5)
		z += 9.5


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
			h += _ridge_height(Vector2(x, z)) * smoothstep(0.0, 6.0, t)
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
	# Rivers last: they cut through everything except the crossings.
	for z in N:
		for x in N:
			var p := Vector2(x, z)
			if _crossing_at(p) != -1:
				_h[z * N + x] = maxf(_h[z * N + x], 0.4)
				continue
			for rv in rivers:
				var d: float = _line_distance(p, rv[0]) - rv[1] * 0.5
				if d < 3.0:
					var bed: float = -2.0 if d <= 0.0 else lerpf(-2.0, _h[z * N + x], d / 3.0)
					_h[z * N + x] = minf(_h[z * N + x], bed)


## Plateau: flat top, a cliff all round except a ramp facing `ang`.
func _plateau(pl: Array, p: Vector2, under: float) -> float:
	var centre: Vector2 = pl[0]
	var r: float = pl[1]
	var top: float = pl[2]
	var d: float = p.distance_to(centre)
	if d <= r:
		return top
	var dir: Vector2 = (p - centre).normalized()
	var ramps: Array = pl[3] if pl[3] is Array else [pl[3]]
	for ang in ramps:
		if dir.dot(Vector2.from_angle(ang)) > 0.95 and d < r + 26.0:
			return lerpf(top, under, smoothstep(r, r + 26.0, d))  # ramp, about 1:4
	if d < r + 1.2:
		return lerpf(top, under, (d - r) / 1.2)  # cliff
	return -INF


func _line_distance(p: Vector2, pts: PackedVector2Array) -> float:
	var best: float = INF
	for i in pts.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])))
	return best


## Index of the river crossing covering `p`, or -1. A crossing is a strip
## `radius` wide (along the river) spanning the river from bank to bank.
func _crossing_at(p: Vector2) -> int:
	for i in crossings.size():
		var c: Vector2 = crossings[i][0]
		if p.distance_to(c) > 14.0:
			continue
		var along: Vector2 = _river_dir(c)
		var d: Vector2 = p - c
		if absf(d.dot(along)) <= crossings[i][1] and absf(d.dot(along.orthogonal())) <= 12.0:
			return i
	return -1


## Direction of the river nearest to `c`.
func _river_dir(c: Vector2) -> Vector2:
	var best: float = INF
	var dir := Vector2.RIGHT
	for rv in rivers:
		var pts: PackedVector2Array = rv[0]
		for i in pts.size() - 1:
			var q: Vector2 = Geometry2D.get_closest_point_to_segment(c, pts[i], pts[i + 1])
			if q.distance_to(c) < best:
				best = q.distance_to(c)
				dir = (pts[i + 1] - pts[i]).normalized()
	return dir


## Ridge (dune line, rock wall): flat crest, cliff sides, open at its gaps.
func _ridge_height(p: Vector2) -> float:
	var out: float = 0.0
	for rd in ridges:
		var d: float = _line_distance(p, rd[0]) - rd[1] * 0.5
		if d > 1.2:
			continue
		var gap: bool = false
		for g: Vector2 in rd[3]:
			if p.distance_to(g) < 5.0:
				gap = true
		if not gap:
			out = maxf(out, rd[2] if d <= 0.0 else lerpf(rd[2], 0.0, d / 1.2))
	return out


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
	var ci: int = _crossing_at(Vector2(x, z))
	if ci != -1:
		c = palette["dirt"]
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
	_place_bridges()
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
	_check_routes(map)
	_audit()


## Objects in odd places: in water, on roads or bridges, in squares, on
## cliffs, or buildings on uneven ground (one side floats, the other sinks).
## Prints every offender; the goal is zero.
func _audit() -> void:
	var issues: Dictionary = {}
	for group in ["Buildings", "Rocks", "Trees"]:
		for node in _root.get_node(group).get_children():
			var cells: Array[Vector2i] = []
			if group == "Trees":
				cells.append(Vector2i(floori(node.position.x), floori(node.position.z)))
			else:
				var r: Rect2i = _root._footprint(node)
				for z in range(r.position.y, r.end.y):
					for x in range(r.position.x, r.end.x):
						cells.append(Vector2i(x, z))
			var lo: float = INF
			var hi: float = -INF
			var why: Array[String] = []
			for c in cells:
				var p := Vector2(c.x + 0.5, c.y + 0.5)
				var h: float = height_at(p.x, p.y)
				lo = minf(lo, h)
				hi = maxf(hi, h)
				var road: float = _path_distance(p)
				if h < 0.15 and not "water" in why:
					why.append("water")
				if road < (0.0 if group == "Buildings" else 1.0) and not "road" in why:
					why.append("road")
				if _crossing_at(p) != -1 and not "bridge" in why:
					why.append("bridge")
				if group != "Buildings" and _slope(c.x, c.y) > 0.5 and not "cliff" in why:
					why.append("cliff")
				if group != "Buildings":
					for r: Rect2 in plazas:
						if r.has_point(p) and biome != &"port" and not "square" in why:
							why.append("square")
			if group == "Buildings" and hi - lo > 0.8:
				why.append("uneven ground %.1f m" % (hi - lo))
			for w in why:
				var key: String = w.get_slice(" ", 0)
				if not issues.has(key):
					issues[key] = []
				issues[key].append("%s (%d, %d)" % [node.name, int(node.position.x), int(node.position.z)])
	if issues.is_empty():
		print("  audit: no objects in odd places")
	for k: String in issues:
		print("  audit %s: %d -> %s" % [k, issues[k].size(), ", ".join(issues[k].slice(0, 6))])


## Every goal must stay reachable when any one choke point is closed:
## that is what "two routes per objective" means.
func _check_routes(map: IslandMap) -> void:
	var goals: Array[Vector3] = [map.boat]
	goals.append_array(map.generators)
	for m: String in markers:
		if not m.begins_with("Choke_"):
			continue
		var f := FlowField.new(map.field.width, map.field.height)
		f.blocked = map.field.blocked.duplicate()
		var c: Vector2 = markers[m]
		for z in range(int(c.y) - 6, int(c.y) + 7):
			for x in range(int(c.x) - 6, int(c.x) + 7):
				if x >= 0 and z >= 0 and x < N and z < N and Vector2(x, z).distance_to(c) <= 6.0:
					f.blocked[z * N + x] = 1
		f.compute_now(f.world_to_cell(map.player_start))
		var cut: Array[String] = []
		for g in goals:
			if f.distance_at(g) >= FlowField.UNREACHABLE:
				cut.append("(%d, %d)" % [int(g.x), int(g.z)])
		print("  %s closed: %s" % [m, "every goal still reachable" if cut.is_empty() else "CUT OFF " + ", ".join(cut)])


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


## Wooden decks over the bridge crossings (decoration: the crossing itself is
## land on the grid).
func _place_bridges() -> void:
	var n: int = 0
	for cr in crossings:
		if cr[2] != "bridge":
			continue
		var along: Vector2 = _river_dir(cr[0])
		n += 1
		var deck := MeshInstance3D.new()
		deck.name = "Bridge_%d" % n
		var bm := BoxMesh.new()
		bm.size = Vector3(cr[1] * 2.0, 0.3, 22.0)  # across the river (local Z)
		deck.mesh = bm
		deck.material_override = _mat(Color(0.45, 0.32, 0.2))
		deck.position = Vector3(cr[0].x, 0.45, cr[0].y)
		deck.rotation.y = -along.angle()
		_add(deck, "Decor")


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
