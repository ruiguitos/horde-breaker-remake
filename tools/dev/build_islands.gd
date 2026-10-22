extends SceneTree
## Builds the hand-made route islands (beach, town, jungle, port) as
## HandmadeIsland scenes in game/world/handmade/islands/: sculpts the
## Terrain3D (coast, hills, plateaus with ramps and cliffs, flattened building
## plots, painted paths), places buildings, trees, rocks, ground cover and the
## markers from a layout written per biome below.
## The scenes are then ordinary editor scenes: open and tweak them by hand
## (re-running this script overwrites them).
## Run: godot --headless --path . --script res://tools/dev/build_islands.gd [-- beach town ...]
## Experiment: add --roadgen to build the roads with the Road Generator
## addon instead; the result goes to game/world/handmade/trials/<biome>_roadgen.tscn
## (not used by the run).

const OUT: String = "res://game/world/handmade/islands/"
const TRIALS: String = "res://game/world/handmade/trials/"
const RG: String = "res://addons/road-generator/nodes/"
const KIT: String = "res://assets/models/nature_megakit/"
const N: int = 256  ## island size = one Terrain3D region (256 m)
const C: float = N * 0.5
## Clearances per object kind, in metres (see _spot_problem).
const COAST_CLEAR: Dictionary = {"building": 10.0, "rock": 8.0, "tree": 8.0, "cover": 3.0, "lava": 8.0}
const RIVER_CLEAR: Dictionary = {"building": 3.5, "rock": 3.5, "tree": 3.5, "cover": 1.5, "lava": 3.5}
const ROAD_CLEAR: Dictionary = {"building": 0.5, "rock": 1.0, "tree": 1.5, "cover": 0.8, "lava": 2.0}
const MAX_SLOPE: Dictionary = {"rock": 0.4, "tree": 0.5, "cover": 0.6, "lava": 0.45}
## Lava pools (the volcano): kept this far from every goal, beyond their own radius.
const LAVA_GOAL_CLEAR: float = 10.0
## Most the ground under a candidate pool may vary (m): a bigger drop cannot be levelled
## without a cliff at the edge of the 3 m blend (see _flatten_pool).
const LAVA_RANGE: float = 1.2
## Road meshes: height above the terrain (asphalt over sidewalks, so the
## asphalt always shows where they overlap), sidewalk width, bridge decks.
const ROAD_LIFT: float = 0.06
const WALK_LIFT: float = 0.03
const SIDEWALK: float = 1.8
const DECK_THICKNESS: float = 0.3
## Longest straight cut of a rounded corner (metres from the corner).
const MAX_CORNER_CUT: float = 6.0
## Radius of the openings in ridges, and of the area closed at each choke
## point by the route check (larger, so a closed choke really is closed).
const GAP_RADIUS: float = 6.5
const CHOKE_CLOSE_RADIUS: float = 7.5

## Current layout (filled by the _design_* functions).
var biome: StringName
var coast_r0: float = 100.0
var coast_waves: Array = []        ## [amplitude, frequency, phase]
var hills: Array = []              ## [Vector2 centre, radius, height]
var plateaus: Array = []           ## [Vector2 centre, radius, height, ramp angles (rad, Array), ramp length (optional, 26 m)]
var rivers: Array = []             ## [PackedVector2Array, width]: carved below the sea (blocks)
var crossings: Array = []          ## [Vector2 centre, radius, "bridge" | "ford"]: land across a river
var ridges: Array = []             ## [PackedVector2Array, width, height, gaps (Array[Vector2])]
var paths: Array = []              ## [PackedVector2Array, width]
var plazas: Array = []             ## Rect2 paved / cleared areas
var buildings: Array = []          ## [Rect2, height, Color, kind]
var forests: Array = []            ## [Vector2 centre, radius, count, models, spacing, height]
var rock_count: int = 30
var lava_pools: int = 0            ## pools to place after the terrain (see _place_lava)
var cover: Array = []              ## [model, count, height]
var markers: Dictionary = {}
var palette: Dictionary = {}

var _h := PackedFloat32Array()     ## vertex heights (N x N)
var _rng := RandomNumberGenerator.new()
var _pending: Array = []
var _terrain: Node3D
var _root: HandmadeIsland
var _frames: int = 0
var _failed: bool = false          ## any island with problems: exit code 1
var _roadgen: bool = false         ## --roadgen: Road Generator roads (experiment)
var _cover_spots: Array = []       ## [model, Vector2]: every tuft placed (the audit reads it)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_roadgen = args.has("--roadgen")
	var names: Array = Array(args).filter(func(a: String) -> bool: return not a.begins_with("--"))
	_pending = names if not names.is_empty() else ["beach", "town", "jungle", "port"]
	DirAccess.make_dir_recursive_absolute(OUT)
	_start_next()


func _start_next() -> void:
	if _pending.is_empty():
		quit(1 if _failed else 0)
		return
	_reset(StringName(_pending.pop_front()))
	call("_design_" + String(biome))
	_prepare_paths()
	_sculpt()
	_place_lava()
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
	lava_pools = 0
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
	ridges = [[_line([Vector2(182, 80), Vector2(197, 95), Vector2(210, 125), Vector2(214, 152)]), 6.0, 3.5, [Vector2(197, 95)]]]
	paths = [
		[_line([Vector2(128, 218), Vector2(128, 170), Vector2(128, 149), Vector2(128, 113)]), 6.0],
		[_line([Vector2(128, 192), Vector2(88, 178), Vector2(55, 160), Vector2(55, 143), Vector2(55, 117)]), 5.0],
		[_line([Vector2(70, 117), Vector2(100, 112), Vector2(128, 113)]), 5.0],
		[_line([Vector2(128, 100), Vector2(128, 68)]), 5.0],
		[_line([Vector2(146, 113), Vector2(175, 103), Vector2(190, 99), Vector2(197, 95), Vector2(204, 91), Vector2(206, 88)]), 5.0],
		[_line([Vector2(148, 50), Vector2(168, 54), Vector2(180, 62), Vector2(188, 70), Vector2(198, 80), Vector2(206, 88)]), 4.0],
	]
	plazas = [Rect2(Vector2(110, 100), Vector2(36, 26)), Rect2(Vector2(40, 104), Vector2(30, 26))]
	for p in [Vector2(48, 92), Vector2(60, 92), Vector2(72, 92), Vector2(74, 104), Vector2(76, 121), Vector2(84, 96)]:
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
##   gate, the church's south-west ramp. Houses packed with 3 m alleys.
##   Arenas: the south square, the north market.
func _design_town() -> void:
	markers = {
		"Generator1": Vector2(49, 99), "Generator2": Vector2(220, 160), "Generator3": Vector2(128, 60),
		"Cache1": Vector2(150, 179), "Cache2": Vector2(70, 140), "Cache3": Vector2(186, 100), "Cache4": Vector2(96, 100),
		"Choke_MiddleBridge": Vector2(128, 118), "Choke_YardGate": Vector2(62, 99), "Choke_ChurchSteps": Vector2(204, 152),
		"Arena_Square": Vector2(128, 179), "Arena_Market": Vector2(128, 61),
	}
	coast_r0 = 108.0
	coast_waves = [[5.0, 2, 1.1], [3.0, 5, 0.3]]
	palette["grass"] = Color(0.45, 0.55, 0.33)
	plateaus = [[Vector2(220, 152), 14.0, 5.0, [PI, PI * 2.0 / 3.0], 14.0]]
	rivers = [[_line([Vector2(0, 122), Vector2(80, 116), Vector2(176, 120), Vector2(256, 116)]), 10.0]]
	crossings = [[Vector2(128, 118), 3.0, "bridge"], [Vector2(70, 116.8), 4.5, "bridge"], [Vector2(186, 119.5), 4.5, "bridge"]]
	paths = [
		[_line([Vector2(128, 225), Vector2(128, 44)]), 10.0],
		[_line([Vector2(70, 200), Vector2(70, 60)]), 8.0],
		[_line([Vector2(186, 200), Vector2(186, 60)]), 8.0],
		[_line([Vector2(40, 84), Vector2(216, 84)]), 8.0],
		[_line([Vector2(40, 160), Vector2(190, 160)]), 8.0],
		[_line([Vector2(70, 196), Vector2(186, 196)]), 8.0],
		[_line([Vector2(186, 152), Vector2(210, 152)]), 6.0],
		[_line([Vector2(186, 196), Vector2(198, 186), Vector2(206, 176), Vector2(213, 165)]), 6.0],
	]
	plazas = [Rect2(Vector2(100, 168), Vector2(56, 22)), Rect2(Vector2(96, 48), Vector2(64, 26)), Rect2(Vector2(36, 90), Vector2(26, 18))]
	# Walled yard (generator 1): front gate east, back gate north.
	_wall(Vector2(36, 90), Vector2(46, 90))
	_wall(Vector2(52, 90), Vector2(62, 90))
	_wall(Vector2(36, 108), Vector2(62, 108))
	_wall(Vector2(36, 90), Vector2(36, 108))
	_wall(Vector2(62, 90), Vector2(62, 96))
	_wall(Vector2(62, 102), Vector2(62, 108))
	buildings.append([Rect2(Vector2(214, 140), Vector2(10, 12)), 9.0, Color(0.8, 0.78, 0.72), "church"])
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
		"Cache1": Vector2(114, 162), "Cache2": Vector2(86, 196), "Cache3": Vector2(82, 56), "Cache4": Vector2(196, 196),
		"Choke_RopeBridge": Vector2(128, 126), "Choke_TempleSouthRamp": Vector2(152, 92),
		"Arena_Clearing": Vector2(114, 162), "Arena_Temple": Vector2(154, 56),
	}
	coast_r0 = 100.0
	coast_waves = [[10.0, 2, 0.8], [6.0, 4, 2.1], [3.0, 7, 0.5]]
	palette["grass"] = Color(0.28, 0.45, 0.22)
	palette["dirt"] = Color(0.42, 0.33, 0.22)
	hills = [[Vector2(82, 56), 18.0, 7.0], [Vector2(196, 196), 18.0, 6.0], [Vector2(62, 188), 14.0, 4.0]]
	plateaus = [[Vector2(152, 58), 22.0, 6.0, [PI, PI * 0.5]]]
	rivers = [[_line([Vector2(0, 108), Vector2(55, 117), Vector2(100, 112), Vector2(128, 126), Vector2(170, 138), Vector2(205, 146), Vector2(256, 160)]), 12.0]]
	crossings = [[Vector2(128, 126), 2.5, "bridge"], [Vector2(55, 117), 7.0, "ford"], [Vector2(205, 146), 7.0, "ford"]]
	paths = [
		[_line([Vector2(128, 214), Vector2(120, 186), Vector2(126, 160), Vector2(128, 126), Vector2(134, 104), Vector2(152, 92), Vector2(152, 78)]), 5.0],
		[_line([Vector2(120, 186), Vector2(84, 166), Vector2(56, 140), Vector2(55, 117), Vector2(50, 88)]), 5.0],
		[_line([Vector2(126, 160), Vector2(172, 166), Vector2(205, 160), Vector2(205, 146), Vector2(210, 112)]), 5.0],
		[_line([Vector2(50, 88), Vector2(90, 60), Vector2(134, 58)]), 4.0],
		[_line([Vector2(210, 112), Vector2(196, 90), Vector2(166, 86)]), 4.0],
	]
	plazas = [Rect2(Vector2(98, 150), Vector2(32, 24)), Rect2(Vector2(38, 76), Vector2(24, 22)), Rect2(Vector2(198, 100), Vector2(24, 22))]
	for r in [[Rect2(Vector2(136, 48), Vector2(6, 6)), 4.0], [Rect2(Vector2(155, 63), Vector2(5, 9)), 3.0], [Rect2(Vector2(138, 66), Vector2(10, 4)), 2.5], [Rect2(Vector2(166, 66), Vector2(4, 4)), 3.5]]:
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
		"Choke_SwingBridge": Vector2(70, 162), "Choke_WarehouseGap": Vector2(84, 74),
		"Arena_Quay": Vector2(170, 196), "Arena_Crossing": Vector2(128, 142),
	}
	coast_r0 = 108.0
	coast_waves = [[3.0, 4, 0.2], [2.0, 6, 1.0]]
	palette["grass"] = Color(0.5, 0.52, 0.45)
	plazas = [Rect2(Vector2(36, 36), Vector2(184, 188))]
	rivers = [[_line([Vector2(0, 162), Vector2(104, 162)]), 14.0]]
	crossings = [[Vector2(70, 162), 2.5, "bridge"]]
	paths = [
		[_line([Vector2(128, 226), Vector2(128, 40)]), 10.0],
		[_line([Vector2(40, 104), Vector2(216, 104)]), 8.0],
		[_line([Vector2(40, 142), Vector2(216, 142)]), 8.0],
		[_line([Vector2(70, 142), Vector2(70, 190), Vector2(122, 196)]), 5.0],
	]
	for x in [56, 86, 144, 174]:
		buildings.append([Rect2(Vector2(x, 66), Vector2(26, 16)), 9.0, Color(0.55, 0.5, 0.45), "warehouse"])
	var paints: Array = [Color(0.75, 0.25, 0.15), Color(0.2, 0.4, 0.7), Color(0.85, 0.6, 0.15), Color(0.25, 0.55, 0.3)]
	_containers(Rect2(Vector2(36, 110), Vector2(184, 28)), paints)
	_containers(Rect2(Vector2(136, 150), Vector2(80, 16)), paints)
	for x in [52, 88]:
		buildings.append([Rect2(Vector2(x, 173), Vector2(12, 10)), 5.0, Color(0.6, 0.58, 0.55), "shed"])
	forests = [[Vector2(36, 128), 10.0, 6, ["CommonTree_2"], 6.0, 6.0], [Vector2(222, 140), 10.0, 6, ["CommonTree_4"], 6.0, 6.0]]
	rock_count = 6
	cover = [["Grass_Common_Short", 300, 0.4], ["Pebble_Square_2", 300, 0.3]]


## Ash Cone. A volcano fills the island; its crater is a lava lake, and the
##   landing is on the south shore at the foot of the cone.
##   Short routes: the south road up the slope, the lava-field plateau to the
##   east. Long routes: the west loop round the flank, the east ridge road.
##   Arenas: the crater rim, the observatory clearing on the slope.
func _design_volcano() -> void:
	markers = {
		"Generator1": Vector2(62, 178), "Generator2": Vector2(196, 150), "Generator3": Vector2(88, 66),
		"Cache1": Vector2(110, 198), "Cache2": Vector2(164, 186), "Cache3": Vector2(60, 128), "Cache4": Vector2(206, 132),
		"Choke_WestPass": Vector2(108, 141), "Choke_EastPass": Vector2(176, 124),
		"Arena_Crater": Vector2(128, 112), "Arena_Clearing": Vector2(112, 128),
	}
	coast_r0 = 96.0
	coast_waves = [[6.0, 3, 0.4], [3.0, 5, 1.7]]
	lava_pools = 7
	palette["sand"] = Color(0.18, 0.16, 0.15)
	palette["grass"] = Color(0.2, 0.2, 0.19)
	palette["dirt"] = Color(0.26, 0.2, 0.17)
	palette["cliff"] = Color(0.16, 0.14, 0.13)
	hills = [[Vector2(128, 104), 90.0, 34.0], [Vector2(128, 104), 11.0, -16.0], [Vector2(60, 170), 22.0, 10.0], [Vector2(200, 180), 20.0, 8.0]]
	paths = [
		[_line([Vector2(126, 206), Vector2(126, 180), Vector2(120, 150), Vector2(124, 118)]), 5.0],
		[_line([Vector2(120, 150), Vector2(96, 132), Vector2(84, 108), Vector2(84, 92)]), 4.0],
		[_line([Vector2(124, 120), Vector2(166, 112), Vector2(200, 120)]), 4.0],
	]
	plazas = [Rect2(Vector2(74, 78), Vector2(20, 20))]
	buildings.append([Rect2(Vector2(92, 162), Vector2(14, 10)), 4.5, Color(0.35, 0.33, 0.32), "ruin"])
	buildings.append([Rect2(Vector2(160, 150), Vector2(12, 9)), 4.0, Color(0.4, 0.36, 0.34), "shed"])
	buildings.append([Rect2(Vector2(62, 160), Vector2(12, 10)), 4.0, Color(0.38, 0.35, 0.33), "shed"])
	var trees: Array = ["Pine_1", "Pine_3"]
	forests = [[Vector2(60, 180), 30.0, 40, trees, 5.0, 8.0], [Vector2(196, 170), 26.0, 30, trees, 5.0, 8.0]]
	rock_count = 60
	cover = [["Grass_Common_Short", 200, 0.3], ["Pebble_Square_2", 300, 0.3]]


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
	# Every cell of the lot, not just its corners: a wavy coast can cut in
	# between them. +1.5 m for the roof overhang (the grid footprint).
	for p in _points_in(r):
		if _inland(p.x, p.y) < COAST_CLEAR["building"] + 1.5 or _path_distance(p) < 1.5 or _river_distance(p) < 5.0:
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


## The paths as they are drawn: straight over each bridge (in line with the
## deck) and with rounded corners. Runs once after the design and before
## sculpting, so the terrain, the paint, the clearances and the road meshes
## all follow the same lines.
func _prepare_paths() -> void:
	for path in paths:
		var pts: PackedVector2Array = path[0]
		for ci in crossings.size():
			if crossings[ci][2] == "bridge":
				pts = _through_bridge(pts, ci, path[1])
		path[0] = _rounded(pts, path[1])


## `pts` with a straight run over bridge `ci` when the path crosses it: the
## crossing centre plus a point on each side, far enough that the rounded
## corners start beyond the deck.
func _through_bridge(pts: PackedVector2Array, ci: int, width: float) -> PackedVector2Array:
	var c: Vector2 = crossings[ci][0]
	for i in pts.size() - 1:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(c, pts[i], pts[i + 1])
		if q.distance_to(c) > 2.0:
			continue
		var across: Vector2 = _river_dir(c).orthogonal()
		if across.dot(pts[i + 1] - pts[i]) < 0.0:
			across = -across
		var k: float = _deck_half_length(c) + 2.0 + minf(width * 1.5, MAX_CORNER_CUT)
		# Points closer to the bridge than k are replaced by the straight run.
		var out := PackedVector2Array()
		for j in i + 1:
			if pts[j].distance_to(c) > k:
				out.append(pts[j])
		out.append_array([c - across * k, c, c + across * k])
		for j in range(i + 1, pts.size()):
			if pts[j].distance_to(c) > k:
				out.append(pts[j])
		return out
	return pts


## Corners replaced by short curves (quadratic Bézier from the corner's
## neighbours), at most MAX_CORNER_CUT or 45 % of a segment from the corner.
func _rounded(pts: PackedVector2Array, width: float) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array([pts[0]])
	for i in range(1, pts.size() - 1):
		var a: Vector2 = pts[i - 1]
		var b: Vector2 = pts[i]
		var c: Vector2 = pts[i + 1]
		var turn: float = absf((b - a).angle_to(c - b))
		if turn < 0.05:
			out.append(b)
			continue
		var t: float = minf(minf(width * 1.5, MAX_CORNER_CUT), 0.45 * minf(a.distance_to(b), b.distance_to(c)))
		var p1: Vector2 = b + (a - b).normalized() * t
		var p2: Vector2 = b + (c - b).normalized() * t
		var steps: int = maxi(3, ceili(turn / deg_to_rad(12.0)))
		for k in steps + 1:
			var f: float = float(k) / steps
			out.append(p1.lerp(b, f).lerp(b.lerp(p2, f), f))
	out.append(pts[pts.size() - 1])
	return out


## Points along `pts` at most `step` metres apart (the corners kept).
func _resample(pts: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([pts[0]])
	for i in pts.size() - 1:
		var n: int = maxi(1, ceili(pts[i].distance_to(pts[i + 1]) / step))
		for k in range(1, n + 1):
			out.append(pts[i].lerp(pts[i + 1], float(k) / n))
	return out


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
			if t > 1.0:  # a plateau at the shore ends in a sea cliff
				for pl in plateaus:
					h = maxf(h, _plateau(pl, Vector2(x, z), h))
			h += _ridge_height(Vector2(x, z)) * smoothstep(0.0, 6.0, t)
			_h[z * N + x] = h
	# Paths: smooth the ground along them (a road never has bumps). Reads an
	# unchanged copy, so the result does not depend on the scan order.
	var src: PackedFloat32Array = _h.duplicate()
	for z in N:
		for x in N:
			var pd: float = _path_distance(Vector2(x, z))
			if pd < 2.0 and src[z * N + x] > 0.0:
				_h[z * N + x] = lerpf(src[z * N + x], _smoothed(src, x, z, 3), clampf(1.0 - pd / 2.0, 0.0, 1.0))
	# Plazas, then building plots (so a plot on a plaza stays exactly flat):
	# flat at their mean height, blended into the ground around them. Plazas
	# get a wide rim: one on a hillside would otherwise end in a steep bank.
	var flats: Array = []
	for r: Rect2 in plazas:
		flats.append([r, 7.0])
	for b in buildings:
		flats.append([b[0], 3.0])
	for f in flats:
		var r: Rect2 = f[0]
		var rim: float = f[1]
		var mean: float = _mean_height(r)
		var grown: Rect2 = r.grow(rim)
		for z in range(maxi(0, int(grown.position.y)), mini(N, int(grown.end.y) + 1)):
			for x in range(maxi(0, int(grown.position.x)), mini(N, int(grown.end.x) + 1)):
				if _inland(x, z) < 4.0:
					continue  # plots never push land into the sea
				var k: float = 1.0 - smoothstep(0.0, rim, _rect_distance(r, Vector2(x, z)))
				_h[z * N + x] = lerpf(_h[z * N + x], mean, k)
	# Rivers last: they cut through everything except the fords. Bridges
	# span the water (their deck is the walkable ground, see _place_bridges).
	for z in N:
		for x in N:
			var p := Vector2(x, z)
			var ci: int = _crossing_at(p)
			if ci != -1 and crossings[ci][2] == "ford":
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
	var run: float = pl[4] if pl.size() > 4 else 26.0
	for ang in ramps:
		var dot: float = dir.dot(Vector2.from_angle(ang))
		if dot > 0.93 and d < r + run:
			# Ramp (26 m: about 1:4). Its sides blend over a few degrees: near
			# the foot that is a gentle bank (no wall across the roads beside
			# it), near the top it is still a cliff.
			var ramp: float = lerpf(top, under, smoothstep(r, r + run, d))
			return lerpf(under, ramp, smoothstep(0.93, 0.97, dot))
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
			if p.distance_to(g) < GAP_RADIUS:
				gap = true
		if not gap:
			out = maxf(out, rd[2] if d <= 0.0 else lerpf(rd[2], 0.0, d / 1.2))
	return out


func _smoothed(src: PackedFloat32Array, x: int, z: int, k: int) -> float:
	var s: float = 0.0
	var n: int = 0
	for dz in range(-k, k + 1):
		for dx in range(-k, k + 1):
			var xx: int = clampi(x + dx, 0, N - 1)
			var zz: int = clampi(z + dz, 0, N - 1)
			s += src[zz * N + xx]
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
	if ci != -1 and crossings[ci][2] == "ford":
		c = palette["dirt"]
	var pd: float = _path_distance(Vector2(x, z))
	if pd < 0.0:
		c = palette["paved"] if biome in [&"town", &"port"] else palette["dirt"]
	elif biome == &"town" and pd < SIDEWALK:
		c = palette["paved"]
	elif biome in [&"beach", &"jungle"] and pd < 1.5:
		c = c.lerp(palette["dirt"], 0.5)
	return c.darkened(_rng.randf() * 0.05)


# ---------------------------------------------------------------- scene

func _build_scene() -> void:
	var name: String = ("%s_roadgen" if _roadgen else "%s_01") % biome
	var out: String = TRIALS if _roadgen else OUT
	DirAccess.make_dir_recursive_absolute(out)
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
	var dir: String = out + name + "_data"
	for f in DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray():
		DirAccess.remove_absolute(dir.path_join(f))
	DirAccess.make_dir_recursive_absolute(dir)
	data.call("save_directory", dir)
	_terrain.set("data_directory", dir)
	for group in ["Buildings", "Trees", "Rocks", "Bridges", "Decor", "Markers"]:
		var n := Node3D.new()
		n.name = group
		_root.add_child(n)
		n.owner = _root
	_place_sea()
	_place_bridges()
	_place_roads()
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
	var err := ResourceSaver.save(packed, out + name + ".tscn")
	var problems: Array[String] = []
	var map: IslandMap = _root.build_map(problems)
	HandmadeIsland.grid_image(map).save_png(out + name + "_grid.png")
	var open: int = 0
	for b in map.field.blocked:
		open += 1 if b == 0 else 0
	print("%s: %s, walkable %d, buildings %d, trees %d, problems %s" % [name, error_string(err), open, map.buildings.size(), map.trees.size(), problems])
	_failed = _failed or err != OK or not problems.is_empty()
	_check_routes(map)
	_audit()


## Objects in odd places: in water or rivers, on roads or bridges, in
## squares, on cliffs, or buildings on uneven ground (one side floats, the
## other sinks). Uses the same rules as placement (_spot_problem) on what is
## really in the scene: footprints as the grid sees them, tree trunks, and
## every tuft of ground cover. Prints every offender; the goal is zero.
func _audit() -> void:
	var issues: Dictionary = {}
	for group in ["Buildings", "Rocks", "Trees"]:
		for node: Node3D in _root.get_node(group).get_children():
			var pts: PackedVector2Array
			var kind: String = {"Buildings": "building", "Rocks": "rock", "Trees": "tree"}[group]
			if group == "Trees":
				var p := Vector2(node.position.x, node.position.z)
				pts = _points_in(Rect2(p - Vector2.ONE * 0.6, Vector2.ONE * 1.2))
			else:
				pts = _footprint_points(node)
			_note(issues, _spot_problem(pts, kind), "%s (%d, %d)" % [node.name, int(node.position.x), int(node.position.z)])
	# MultiMesh transforms are not kept without a GPU: read the spots placed.
	for spot in _cover_spots:
		_note(issues, _cover_problem(spot[1]), "%s (%d, %d)" % [spot[0], int(spot[1].x), int(spot[1].y)])
	_audit_roads(issues)
	_audit_lava(issues)
	_failed = _failed or not issues.is_empty()
	if issues.is_empty():
		print("  audit: no objects in odd places")
	for k: String in issues:
		print("  audit %s: %d -> %s" % [k, issues[k].size(), ", ".join(issues[k].slice(0, 6))])


## Lava pools (lava_pools of them, volcano only): walkable ground well away from
## the goals, so a pool never sits on a cliff or on an objective. Chosen after the
## terrain exists, in a seeded shuffle of candidate cells, so the layout repeats.
func _place_lava() -> void:
	if lava_pools <= 0:
		return  # no shuffle here: other islands must keep their random sequence
	var goals: Array = _goal_points()
	var cells: Array = []
	for z in range(8, N - 8, 4):
		for x in range(8, N - 8, 4):
			cells.append(Vector2(x + 0.5, z + 0.5))
	for i in range(cells.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: Vector2 = cells[i]
		cells[i] = cells[j]
		cells[j] = swap
	var placed: Array = []
	for p: Vector2 in cells:
		if placed.size() >= lava_pools:
			break
		if _lava_clear(p, goals, placed):
			placed.append(p)
	if placed.size() < lava_pools:
		print("  lava: only %d of %d pools fit" % [placed.size(), lava_pools])
		_failed = true
	for p: Vector2 in placed:
		_flatten_pool(p)
	for i in placed.size():
		markers["Lava%d" % (i + 1)] = placed[i]


## Levels the ground under a lava pool to its mean height, blending over 3 m beyond
## the rim, so the disc lies flat on the land instead of half-burying itself.
func _flatten_pool(p: Vector2) -> void:
	var r: float = HandmadeIsland.LAVA_RADIUS
	var sum: float = 0.0
	var count: int = 0
	for z in range(maxi(0, floori(p.y - r)), mini(N, ceili(p.y + r) + 1)):
		for x in range(maxi(0, floori(p.x - r)), mini(N, ceili(p.x + r) + 1)):
			if Vector2(x, z).distance_to(p) <= r:
				sum += _h[z * N + x]
				count += 1
	var mean: float = sum / maxf(1.0, count)
	for z in range(maxi(0, floori(p.y - r - 3.0)), mini(N, ceili(p.y + r + 3.0) + 1)):
		for x in range(maxi(0, floori(p.x - r - 3.0)), mini(N, ceili(p.x + r + 3.0) + 1)):
			var d: float = Vector2(x, z).distance_to(p) - r
			var k: float = 1.0 - smoothstep(0.0, 3.0, d)
			_h[z * N + x] = lerpf(_h[z * N + x], mean, k)


## Whether a lava pool centred on `p` may stand there, away from `goals` and `others`.
func _lava_clear(p: Vector2, goals: Array, others: Array) -> bool:
	for q: Vector2 in goals + others:
		if p.distance_to(q) < LAVA_GOAL_CLEAR + HandmadeIsland.LAVA_RADIUS:
			return false
	for b in buildings:  # the pool and its levelled rim stay off every building plot
		if (b[0] as Rect2).grow(HandmadeIsland.LAVA_RADIUS + 3.0).has_point(p):
			return false
	var lo: float = INF
	var hi: float = -INF
	for q2: Vector2 in _lava_points(p):
		lo = minf(lo, height_at(q2.x, q2.y))
		hi = maxf(hi, height_at(q2.x, q2.y))
	if hi - lo > LAVA_RANGE:
		return false
	return _spot_problem(_lava_points(p), "lava") == ""


## The centre and eight points on the rim of a pool at `p`: what _spot_problem reads.
func _lava_points(p: Vector2) -> PackedVector2Array:
	var pts := PackedVector2Array([p])
	for k in 8:
		pts.append(p + Vector2.from_angle(TAU * k / 8.0) * HandmadeIsland.LAVA_RADIUS)
	return pts


## The positions the lava pools must keep clear of: generators, caches, the route
## and arena markers, the boat and the landing.
func _goal_points() -> Array:
	var out: Array = []
	for key: String in markers:
		if key.begins_with("Generator") or key.begins_with("Cache") or key.begins_with("Choke") or key.begins_with("Arena") or key in ["Boat", "PlayerStart"]:
			out.append(markers[key])
	return out


## Every Lava marker must pass the same rules as _place_lava.
func _audit_lava(issues: Dictionary) -> void:
	var goals: Array = _goal_points()
	for key: String in markers:
		if not key.begins_with("Lava"):
			continue
		var others: Array = []
		for other: String in markers:
			if other.begins_with("Lava") and other != key:
				others.append(markers[other])
		var p: Vector2 = markers[key]
		var reason: String = _spot_problem(_lava_points(p), "lava")
		if reason == "" and not _lava_clear(p, goals, others):
			reason = "near a goal or another pool"
		_note(issues, reason, key)


func _note(issues: Dictionary, why: String, what: String) -> void:
	if why == "":
		return
	if not issues.has(why):
		issues[why] = []
	issues[why].append(what)


## Every goal must stay reachable when any one choke point is closed:
## that is what "two routes per objective" means.
func _check_routes(map: IslandMap) -> void:
	var goals: Array[Vector3] = [map.boat]
	goals.append_array(map.generators)
	goals.append_array(map.caches)
	for m: String in markers:
		if not m.begins_with("Choke_"):
			continue
		var f := FlowField.new(map.field.width, map.field.height)
		f.blocked = map.field.blocked.duplicate()
		var c: Vector2 = markers[m]
		var k: int = ceili(CHOKE_CLOSE_RADIUS)
		for z in range(int(c.y) - k, int(c.y) + k + 1):
			for x in range(int(c.x) - k, int(c.x) + k + 1):
				if x >= 0 and z >= 0 and x < N and z < N and Vector2(x, z).distance_to(c) <= CHOKE_CLOSE_RADIUS:
					f.blocked[z * N + x] = 1
		f.compute_now(f.world_to_cell(map.player_start))
		var cut: Array[String] = []
		for g in goals:
			if f.distance_at(g) >= FlowField.UNREACHABLE:
				cut.append("(%d, %d)" % [int(g.x), int(g.z)])
		print("  %s closed: %s" % [m, "every goal still reachable" if cut.is_empty() else "CUT OFF " + ", ".join(cut)])
		_failed = _failed or not cut.is_empty()


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


## Wooden bridges over the rivers: a deck from bank to bank (sloping when
## the banks differ in height) with a rail on each side. The deck is the
## walkable ground there: HandmadeIsland reads the Bridges group.
func _place_bridges() -> void:
	var n: int = 0
	for cr in crossings:
		if cr[2] != "bridge":
			continue
		var c: Vector2 = cr[0]
		var along: Vector2 = _river_dir(c)
		var across := Vector2(-along.y, along.x)
		var half: float = _deck_half_length(c)
		var ha: float = height_at(c.x - across.x * half, c.y - across.y * half)
		var hb: float = height_at(c.x + across.x * half, c.y + across.y * half)
		n += 1
		var deck := MeshInstance3D.new()
		deck.name = "Bridge_%d" % n
		var span := Vector3(across.x * half * 2.0, hb - ha, across.y * half * 2.0)  # bank to bank
		var bm := BoxMesh.new()
		bm.size = Vector3(cr[1] * 2.0, DECK_THICKNESS, span.length())  # local X along the river, Z across
		deck.mesh = bm
		deck.material_override = _mat(Color(0.45, 0.32, 0.2))
		var x_axis := Vector3(along.x, 0.0, along.y)
		var z_axis: Vector3 = span.normalized()
		deck.basis = Basis(x_axis, z_axis.cross(x_axis), z_axis)
		# Top surface level with the ground at both ends (5 cm above it).
		deck.position = Vector3(c.x, (ha + hb) * 0.5 + 0.05, c.y) - deck.basis.y * DECK_THICKNESS * 0.5
		_add(deck, "Bridges")
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			rail.name = "Rail_%s" % ("L" if side < 0.0 else "R")
			var rm := BoxMesh.new()
			rm.size = Vector3(0.15, 0.9, span.length())
			rail.mesh = rm
			rail.material_override = _mat(Color(0.35, 0.24, 0.15))
			rail.position = Vector3(side * (cr[1] - 0.1), DECK_THICKNESS * 0.5 + 0.45, 0.0)
			deck.add_child(rail)
			rail.owner = _root


## Half the length of the bridge at crossing `c`: the river, its 3 m banks and
## 1 m on solid ground at each end.
func _deck_half_length(c: Vector2) -> float:
	return _river_width(c) * 0.5 + 4.0


func _river_width(c: Vector2) -> float:
	var best: float = INF
	var width: float = 0.0
	for rv in rivers:
		var d: float = _line_distance(c, rv[0])
		if d < best:
			best = d
			width = rv[1]
	return width


## True when `p` is on a bridge deck (the strip the deck covers).
func _on_bridge(p: Vector2, margin: float = 0.0) -> bool:
	for cr in crossings:
		if cr[2] != "bridge":
			continue
		var along: Vector2 = _river_dir(cr[0])
		var d: Vector2 = p - cr[0]
		if absf(d.dot(along)) <= cr[1] + margin and absf(d.dot(along.orthogonal())) <= _deck_half_length(cr[0]) + margin:
			return true
	return false


## Road surfaces: a ribbon mesh along every path, draped on the terrain at
## the path's width with sharp edges (the terrain paint is only 1 m per
## pixel). Town streets get sidewalks and the town and port main roads a
## dashed centre line; beach and jungle get dirt tracks. Where two roads
## meet, the later one stops just inside the earlier one, and asphalt sits
## above the sidewalks, so no two surfaces fight at the same height.
## Decoration only (Decor/Roads): the grid ignores it.
func _place_roads() -> void:
	var town: bool = biome == &"town"
	var urban: bool = biome in [&"town", &"port"]
	var road := SurfaceTool.new()
	var walk := SurfaceTool.new()
	var line := SurfaceTool.new()
	for st: SurfaceTool in [road, walk, line]:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in paths.size():
		var w: float = paths[i][1]
		var pts: PackedVector2Array = _resample(paths[i][0], 1.0)
		var stagger: float = 0.002 * i  # later roads a hair lower: the earlier one shows on top
		if not _roadgen:
			_ribbon(road, pts, -w * 0.5, w * 0.5, ROAD_LIFT - stagger, func(p: Vector2) -> bool: return _road_hidden(p, i, -1.0, true), func(p: Vector2) -> float: return _bridge_taper(p, w))
		if town:
			for side in [-1.0, 1.0]:
				var inner: float = side * (w * 0.5 - 0.2)  # tucked 0.2 m under the asphalt
				var outer: float = side * (w * 0.5 + SIDEWALK)
				_ribbon(walk, pts, minf(inner, outer), maxf(inner, outer), WALK_LIFT - stagger, func(p: Vector2) -> bool: return _on_bridge(p, 4.0) or _steep(p) or _road_hidden(p, i, 0.0, false))
		if urban and w >= 8.0 and not _roadgen:
			# Dashes: 2 m painted, 3 m gap; none across junctions.
			var dash := PackedVector2Array()
			for k in pts.size():
				if k % 5 < 3:
					dash.append(pts[k])
				elif dash.size() > 1:
					_ribbon(line, dash, -0.1, 0.1, ROAD_LIFT + 0.01, func(p: Vector2) -> bool: return _road_hidden(p, i, 1.0, false))
					dash.clear()
				else:
					dash.clear()
	var looks: Dictionary = {
		&"beach": Color(0.68, 0.58, 0.4), &"jungle": Color(0.37, 0.28, 0.18),
		&"town": Color(0.25, 0.25, 0.27), &"port": Color(0.33, 0.33, 0.34),
	}
	_add_roads_mesh(road, "Surface", looks.get(biome, palette["dirt"]))
	_add_roads_mesh(walk, "Sidewalks", Color(0.62, 0.6, 0.56))
	_add_roads_mesh(line, "Markings", Color(0.92, 0.9, 0.82))
	if _roadgen:
		_place_roadgen()


## Experiment (--roadgen): the roads with the Road Generator addon. Every
## path is cut where it meets another; each junction becomes a
## RoadIntersection and each piece between junctions a chain of RoadPoints
## (one every ~8 m, at the terrain height). Bridges also cut the chains: the
## deck is the road there. The addon draws asphalt, lanes and shoulders.
func _place_roadgen() -> void:
	var manager := Node3D.new()
	manager.set_script(load(RG + "road_manager.gd"))
	manager.name = "RoadNetwork"
	_add(manager, "Decor")
	var container := Node3D.new()
	container.set_script(load(RG + "road_container.gd"))
	container.name = "Streets"
	container.set("flatten_terrain", false)  # the builder already shaped the ground
	manager.add_child(container)
	container.owner = _root
	# Junctions: a path end on another path (T) or two paths crossing (X).
	var junctions: Array = []  # [Vector2 centre, radius]
	for i in paths.size():
		var pts: PackedVector2Array = paths[i][0]
		for j in paths.size():
			if j == i:
				continue
			var other: PackedVector2Array = paths[j][0]
			for end: Vector2 in [pts[0], pts[pts.size() - 1]]:
				var q: Vector2 = _closest_on(end, other)
				if end.distance_to(q) < paths[j][1] * 0.5 + 0.5:
					_merge_junction(junctions, q, maxf(paths[i][1], paths[j][1]))
			if j > i:
				for a in pts.size() - 1:
					for b in other.size() - 1:
						var x: Variant = Geometry2D.segment_intersects_segment(pts[a], pts[a + 1], other[b], other[b + 1])
						if x != null:
							_merge_junction(junctions, x, maxf(paths[i][1], paths[j][1]))
	var nodes: Array[Node3D] = []
	for k in junctions.size():
		var c: Vector2 = junctions[k][0]
		var ix := Node3D.new()
		ix.set_script(load(RG + "road_intersection.gd"))
		ix.name = "Junction_%02d" % k
		ix.position = Vector3(c.x, height_at(c.x, c.y) + 0.08, c.y)
		container.add_child(ix)
		ix.owner = _root
		nodes.append(ix)
	# Chains: runs of samples off junctions, bridges and water.
	var n: int = 0
	for i in paths.size():
		var w: float = paths[i][1]
		var pts: PackedVector2Array = _resample(paths[i][0], 1.0)
		var run := PackedVector2Array()
		var start_j: int = -1
		for k in pts.size() + 1:
			var p: Vector2 = pts[mini(k, pts.size() - 1)]
			var j: int = _junction_at(junctions, p)
			var stop: bool = k == pts.size() or j != -1 or _on_bridge(p) or height_at(p.x, p.y) < 0.2
			if not stop:
				if run.is_empty():
					start_j = _junction_at(junctions, pts[maxi(k - 1, 0)], 1.5)
				run.append(p)
				continue
			if run.size() >= 3:
				n += 1
				_roadgen_chain(container, run, w, "Road_%02d" % n,
					nodes[start_j] if start_j != -1 else null, nodes[j] if j != -1 else null)
			run = PackedVector2Array()


## RoadPoints along `run` (one every ~8 m), connected in order, the ends
## joined to the junctions `from` / `to` when given.
func _roadgen_chain(container: Node3D, run: PackedVector2Array, w: float, name: String, from: Node3D, to: Node3D) -> void:
	var count: int = maxi(2, ceili(run.size() / 8.0) + 1)
	var rps: Array[Node3D] = []
	var shoulder: float = 0.8
	for k in count:
		var idx: int = roundi(float(k) / (count - 1) * (run.size() - 1))
		var p: Vector2 = run[idx]
		var a: Vector2 = run[maxi(idx - 1, 0)]
		var b: Vector2 = run[mini(idx + 1, run.size() - 1)]
		var dir := Vector3(b.x - a.x, 0.0, b.y - a.y).normalized()
		var rp := Node3D.new()
		rp.set_script(load(RG + "road_point.gd"))
		rp.name = "%s_%02d" % [name, k]
		rp.set("auto_lanes", false)
		var dirs: Array[int] = [2, 1]  # one lane each way (REVERSE, FORWARD)
		var types: Array[int] = [5, 5]  # TWO_WAY: white edge line, yellow centre
		rp.set("traffic_dir", dirs)
		rp.set("lanes", types)
		rp.set("lane_width", (w - shoulder * 2.0) * 0.5)
		rp.set("shoulder_width_l", shoulder)
		rp.set("shoulder_width_r", shoulder)
		rp.set("gutter_profile", Vector2(0.4, -0.12))
		rp.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), Vector3(p.x, height_at(p.x, p.y) + 0.08, p.y))
		var span: float = run.size() / float(count - 1) * 0.4
		rp.set("prior_mag", span)
		rp.set("next_mag", span)
		container.add_child(rp)
		rp.owner = _root
		rps.append(rp)
	for k in rps.size() - 1:
		rps[k].call("connect_roadpoint", 0, rps[k + 1], 1)  # NEXT -> PRIOR
	if from != null:
		from.call("add_branch", rps[0])
	if to != null:
		to.call("add_branch", rps[rps.size() - 1])


func _closest_on(p: Vector2, pts: PackedVector2Array) -> Vector2:
	var best: Vector2 = pts[0]
	for i in pts.size() - 1:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		if q.distance_to(p) < best.distance_to(p):
			best = q
	return best


## Adds a junction at `c` (radius from the widest road meeting there), or
## merges it with one less than 4 m away.
func _merge_junction(junctions: Array, c: Vector2, width: float) -> void:
	for jn in junctions:
		if (jn[0] as Vector2).distance_to(c) < 4.0:
			jn[1] = maxf(jn[1], width * 0.5 + 2.0)
			return
	junctions.append([c, width * 0.5 + 2.0])


## Index of the junction whose area covers `p` (grown by `grow`), or -1.
func _junction_at(junctions: Array, p: Vector2, grow: float = 0.0) -> int:
	for k in junctions.size():
		if p.distance_to(junctions[k][0]) < junctions[k][1] + grow:
			return k
	return -1


## Adds a strip along `pts` between the side offsets `left` and `right`
## (metres from the centre line, negative = left), draped on the terrain
## `lift` above it, one vertex per metre along and across (so it follows the
## ground). Samples where `hidden` returns true for the strip's middle are
## left out: the strip breaks there. `taper` (optional) scales the offsets
## at each sample (a wide street narrowing onto a bridge).
func _ribbon(st: SurfaceTool, pts: PackedVector2Array, left: float, right: float, lift: float, hidden: Callable, taper: Callable = Callable()) -> void:
	var cols: int = maxi(1, ceili(right - left))
	var prev := PackedVector3Array()
	for k in pts.size():
		var t: Vector2 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x)
		if hidden.call(pts[k] + n * (left + right) * 0.5):
			prev.clear()
			continue
		var f: float = taper.call(pts[k]) if taper.is_valid() else 1.0
		var row := PackedVector3Array()
		for j in cols + 1:
			var q: Vector2 = pts[k] + n * lerpf(left, right, float(j) / cols) * f
			row.append(Vector3(q.x, height_at(q.x, q.y) + lift, q.y))
		if not prev.is_empty():
			for j in cols:
				# Clockwise seen from above: Godot's front faces.
				for v: Vector3 in [prev[j], row[j + 1], prev[j + 1], prev[j], row[j], row[j + 1]]:
					st.set_normal(_ground_normal(v.x, v.z))
					st.add_vertex(v)
		prev = row


## Whether a road piece of path `i` at `p` is left out: on a bridge (the deck
## is the road there), in the water, or inside another road. `own` = true
## only checks the roads drawn before path `i` (a road stops 1 m inside the
## one it joins); otherwise every other road, grown by `grow` metres.
func _road_hidden(p: Vector2, i: int, grow: float, own: bool) -> bool:
	if _on_bridge(p) or height_at(p.x, p.y) < 0.2:
		return true
	for j in paths.size():
		if j == i or (own and j > i):
			continue
		if _line_distance(p, paths[j][0]) < paths[j][1] * 0.5 + (-1.0 if own else grow):
			return true
	return false


## True on a cliff or a ramp's side bank: a sidewalk there would climb it.
func _steep(p: Vector2) -> bool:
	return _slope(clampi(floori(p.x), 0, N - 1), clampi(floori(p.y), 0, N - 1)) > 0.45


## Width factor for a road `w` metres wide at `p`: it narrows to the deck's
## width over the last 4 m before a narrower bridge.
func _bridge_taper(p: Vector2, w: float) -> float:
	var f: float = 1.0
	for cr in crossings:
		var deck_w: float = cr[1] * 2.0
		if cr[2] != "bridge" or w <= deck_w:
			continue
		var along: Vector2 = _river_dir(cr[0])
		var d: Vector2 = p - cr[0]
		if absf(d.dot(along)) > w:
			continue
		var beyond: float = absf(d.dot(along.orthogonal())) - _deck_half_length(cr[0])
		f = minf(f, lerpf(deck_w / w, 1.0, clampf(beyond / 4.0, 0.0, 1.0)))
	return f


func _ground_normal(x: float, z: float) -> Vector3:
	return Vector3(height_at(x - 0.5, z) - height_at(x + 0.5, z), 1.0, height_at(x, z - 0.5) - height_at(x, z + 0.5)).normalized()


func _add_roads_mesh(st: SurfaceTool, name: String, colour: Color) -> void:
	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return
	if not _root.has_node("Decor/Roads"):
		var group := Node3D.new()
		group.name = "Roads"
		_add(group, "Decor")
	var inst := MeshInstance3D.new()
	inst.name = name
	inst.mesh = mesh
	inst.material_override = _mat(colour)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.get_node("Decor/Roads").add_child(inst)
	inst.owner = _root


## Roads the player would notice are wrong: running through water (away
## from bridges and fords) or over a cliff. Samples the centre and both
## edges every metre.
func _audit_roads(issues: Dictionary) -> void:
	for i in paths.size():
		var w: float = paths[i][1]
		var pts: PackedVector2Array = _resample(paths[i][0], 1.0)
		for k in pts.size():
			var t: Vector2 = (pts[mini(k + 1, pts.size() - 1)] - pts[maxi(k - 1, 0)]).normalized()
			for off in [-w * 0.5, 0.0, w * 0.5]:
				var p: Vector2 = pts[k] + Vector2(-t.y, t.x) * off
				if _on_bridge(p, w * 0.5 + 0.5) or _crossing_at(p) != -1:
					continue  # bridges and fords; a road wider than its bridge narrows there
				var c := Vector2i(clampi(floori(p.x), 0, N - 1), clampi(floori(p.y), 0, N - 1))
				var why: String = "road in water" if height_at(p.x, p.y) < 0.15 else ("road on cliff" if _slope(c.x, c.y) > 0.6 else "")
				if why != "":
					_note(issues, why, "path %d (%d, %d)" % [i, int(p.x), int(p.y)])
					break


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


## Why an object of `kind` ("building", "rock", "tree", "cover") standing on
## the ground points `pts` would look wrong, or "" when the spot is fine. The placement
## functions and _audit() both use it, so a placed object always passes the
## audit. Buildings may stand on squares and need flat ground (one side would
## float, the other sink); everything else needs a gentle slope.
func _spot_problem(pts: PackedVector2Array, kind: String) -> String:
	var lo: float = INF
	var hi: float = -INF
	for p in pts:
		var c := Vector2i(clampi(floori(p.x), 0, N - 1), clampi(floori(p.y), 0, N - 1))
		var h: float = height_at(p.x, p.y)
		lo = minf(lo, h)
		hi = maxf(hi, h)
		if h < 0.15:
			return "water"
		if _inland(p.x, p.y) < COAST_CLEAR[kind]:
			return "coast"
		if _river_distance(p) < RIVER_CLEAR[kind]:
			return "river"
		if _crossing_at(p) != -1:
			return "bridge"
		if _path_distance(p) < ROAD_CLEAR[kind]:
			return "road"
		if kind != "building":
			if _in_plaza(p) and not (kind == "tree" and biome == &"port"):
				return "square"
			if _slope(c.x, c.y) > MAX_SLOPE[kind]:
				return "cliff"
	if kind == "building" and hi - lo > 0.8:
		return "uneven"
	if kind == "rock" and hi - lo > 0.6:
		return "cliff"
	return ""


## Metres from `p` to the nearest river bank (negative in the water).
func _river_distance(p: Vector2) -> float:
	var best: float = INF
	for rv in rivers:
		best = minf(best, _line_distance(p, rv[0]) - rv[1] * 0.5)
	return best


func _in_plaza(p: Vector2) -> bool:
	for r: Rect2 in plazas:
		if r.has_point(p):
			return true
	return false


## Cell centres inside `r` (at least its centre), as ground sample points.
func _points_in(r: Rect2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for z in range(floori(r.position.y), ceili(r.end.y)):
		for x in range(floori(r.position.x), ceili(r.end.x)):
			if x >= 0 and z >= 0 and x < N and z < N and r.has_point(Vector2(x + 0.5, z + 0.5)):
				out.append(Vector2(x + 0.5, z + 0.5))
	if out.is_empty():
		out.append(r.get_center())
	return out


## Free spot for a tree or rock of radius `radius`: a clean spot (see
## _spot_problem), off building plots and markers, at least `spacing` from
## `taken`.
func _free(p: Vector2, kind: String, radius: float, taken: Array[Vector2], spacing: float) -> bool:
	if p.x < 4 or p.y < 4 or p.x > N - 5 or p.y > N - 5:
		return false
	for b in buildings:
		if (b[0] as Rect2).grow(radius + 2.0).has_point(p):
			return false
	for m: String in markers:
		if p.distance_to(markers[m]) < 7.0:
			return false
	for q in taken:
		if p.distance_squared_to(q) < spacing * spacing:
			return false
	var r := Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)
	return _spot_problem(_points_in(r), kind) == ""


func _place_trees(taken: Array[Vector2]) -> void:
	var n: int = 0
	for f in forests:
		var placed: int = 0
		var tries: int = 0
		while placed < f[2] and tries < f[2] * 40:
			tries += 1
			var p: Vector2 = f[0] + Vector2.from_angle(_rng.randf() * TAU) * sqrt(_rng.randf()) * f[1]
			p = Vector2(floorf(p.x) + 0.5, floorf(p.y) + 0.5)  # trunk on a cell centre (it blocks that cell)
			if not _free(p, "tree", 0.6, taken, f[4]):
				continue
			var model: String = f[3][_rng.randi() % f[3].size()]
			var tree: Node3D = (load(KIT + model + ".gltf") as PackedScene).instantiate()
			n += 1
			tree.name = "Tree_%03d" % n
			var target: float = f[5] * _rng.randf_range(0.8, 1.2)
			tree.scale = Vector3.ONE * _model_scale(tree, target)
			tree.rotation.y = _rng.randf() * TAU
			tree.position = Vector3(p.x, _lowest(p, 0.6) - 0.1, p.y)
			_add(tree, "Trees")
			taken.append(p)
			placed += 1


func _place_rocks(taken: Array[Vector2]) -> void:
	var n: int = 0
	var tries: int = 0
	while n < rock_count and tries < 4000:
		tries += 1
		var p := Vector2(_rng.randf_range(10, N - 10), _rng.randf_range(10, N - 10))
		if not _free(p, "rock", 1.5, taken, 10.0):
			continue
		var rock: Node3D = (load(KIT + "Rock_Medium_%d.gltf" % _rng.randi_range(1, 3)) as PackedScene).instantiate()
		rock.scale = Vector3.ONE * _model_scale(rock, _rng.randf_range(1.2, 2.0))
		rock.rotation.y = _rng.randf() * TAU
		rock.position = Vector3(p.x, 0.0, p.y)
		_add(rock, "Rocks")
		# Check the real footprint (what the grid and the audit see), not a guess.
		var cells: PackedVector2Array = _footprint_points(rock)
		if _spot_problem(cells, "rock") != "":
			rock.get_parent().remove_child(rock)
			rock.free()
			continue
		var lo: float = INF
		for c in cells:
			lo = minf(lo, height_at(c.x, c.y))
		rock.position.y = lo - 0.2  # sunk to its lowest corner: never floats
		n += 1
		rock.name = "Rock_%02d" % n
		taken.append(p)


## Ground cover: one MultiMesh per model (cheap, never blocks).
func _place_cover() -> void:
	_cover_spots.clear()
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
			var blocked: bool = _cover_problem(p) != ""
			for b in buildings:
				if (b[0] as Rect2).grow(0.5).has_point(p):
					blocked = true
					break
			if blocked:
				continue
			_cover_spots.append([c[0], p])
			var s: float = NatureKit.scale_for(m, c[2]) * _rng.randf_range(0.7, 1.3)
			xf.append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, height_at(p.x, p.y) - 0.05, p.y)))
		mm.instance_count = xf.size()
		for i in xf.size():
			mm.set_instance_transform(i, xf[i])
		var inst := MultiMeshInstance3D.new()
		inst.name = "Cover_" + String(c[0])
		inst.multimesh = mm
		_add(inst, "Decor")


## Why a tuft of ground cover at `p` would look wrong, or "".
func _cover_problem(p: Vector2) -> String:
	return _spot_problem(PackedVector2Array([p]), "cover")


## Centres of the cells under `node` as the grid sees them
## (HandmadeIsland._footprint).
func _footprint_points(node: Node3D) -> PackedVector2Array:
	var r: Rect2i = _root._footprint(node)
	var out := PackedVector2Array()
	for z in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			out.append(Vector2(x + 0.5, z + 0.5))
	return out


## Lowest ground within `radius` of `p` (a base sunk to it never floats).
func _lowest(p: Vector2, radius: float) -> float:
	var lo: float = height_at(p.x, p.y)
	for o: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		lo = minf(lo, height_at(p.x + o.x * radius, p.y + o.y * radius))
	return lo


func _model_scale(n: Node3D, target: float) -> float:
	var box := AABB()
	for m in n.find_children("*", "MeshInstance3D", true, false):
		box = box.merge((m as MeshInstance3D).get_aabb())
	return target / box.size.y if box.size.y > 0.01 else 1.0
