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
## A place with "parts" (the Berlenga expedition) is written instead to
## game/world/handmade/expeditions/<place>/: the shared island (base.scn,
## no markers), the whole island (whole.scn) and one scene per part
## (part_1.scn...), all on one Terrain3D data folder (terrain/). whole.scn
## and the parts are scenes inherited from base.scn: they store only their
## markers, play area and boundary walls (see _save_inherited).
## Prints the time of every stage, the grid and its problems (exit code 1
## when there are any).
## Run: python tools/real_island/fetch_data.py <place>
##      godot --headless --path . --script res://tools/real_island/build.gd -- <place> [--out-dir <res://dir/>] [--kits houses,paths,landmarks]
## (place: berlenga, hashima; default berlenga). --out-dir writes a test
## build somewhere else than the game's islands (e.g. a gitignored folder),
## with the same files.

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
## Tints of the construction textures (fetch_data.py roles), as the target
## colour over the picture's mean colour: the low-poly palette stays, the
## picture adds grain, stains and relief. Metres per picture follow the
## real size Poly Haven gives for each scan.
const CONCRETE_M: float = 3.0  ## dirty_concrete: 3 x 3 m
const CONCRETE_TINT := Color(0.95, 0.97, 1.0)  ## weathered grey (piers, galleries, steps)
const SLAB_TINT := Color(0.8, 0.82, 0.86)  ## Hashima's flat roofs: darker, rain-stained
const WHITE_CONCRETE := Color(1.75, 1.8, 1.9)  ## painted concrete (Hashima's lighthouse)
const WOOD_M: float = 2.0  ## weathered_planks: 2 x 2 m
const WOOD_TINT := Color(1.25, 1.25, 1.25)  ## grey, sun-bleached planks
const TORII_RED := Color(1.75, 0.75, 0.65)  ## the planks painted red
const METAL_M: float = 2.0  ## rusty_metal_04: 2 x 2 m
const METAL_TINT := Color(0.9, 0.9, 0.9)  ## rusty steel (conveyor)
const IRON_TINT := Color(0.45, 0.6, 0.8)  ## dark painted iron
const RED_METAL := Color(1.75, 0.45, 0.4)  ## red painted iron (lighthouse caps)
const SHEET_M: float = 2.0  ## rusty_corrugated_iron: 2 x 2 m
const GRANITE_M: float = 2.0  ## stone_wall_04 (1.7 m scan): stones about 0.4 m
const GRANITE_TINT := Color(1.25, 1.32, 1.4)  ## cool light grey granite, as the fort's
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
		# The fort's pier (OSM man_made=pier) is a walkable deck in Bridges/,
		# level with the foot of the fort's steps: the final boards there.
		"pier_deck": true,
		# Expedition (docs/design/BERLENGA_EXPEDITION.md): the island played
		# in four parts, in order, on foot. Codex's polygons (island metres);
		# exit = [point near the crossing, OSM way of the path that crosses]:
		# the next part's entry. Part 1 starts at the landing, part 4 ends
		# on the pier. horde_radius -1 = measured (0 when the part is small).
		"expedition": "berlenga",
		"parts": [
			{"mission": &"rescue", "horde_radius": 120,
				"polygon": [Vector2(650, 0), Vector2(1466, 0), Vector2(1466, 1466), Vector2(880, 1466), Vector2(880, 800), Vector2(865, 630), Vector2(800, 540), Vector2(650, 400)],
				"exit": [Vector2(835, 589), 441503021],
				"rescue": Vector2(1011, 720), "caches": [Vector2(1059, 768), Vector2(909, 560)]},
			# Light the Signals: two beacons on the plateau's edges (the old
			# generator spots east and southwest of the lighthouse), then the
			# lighthouse itself (Farol da Berlenga, OSM; its tower centre).
			# Each fuel waits at the door of a house of the lighthouse
			# compound (the keepers' houses), so every leg crosses it.
			{"mission": &"signals", "horde_radius": 120,
				"polygon": [Vector2(0, 0), Vector2(650, 0), Vector2(650, 400), Vector2(800, 540), Vector2(865, 630), Vector2(880, 800), Vector2(523, 800), Vector2(0, 800)],
				"exit": [Vector2(521, 800), 233892909],
				"signals": [Vector2(745, 665), Vector2(675, 674)], "lighthouse": Vector2(706, 624),
				"fuel": [Vector2(717, 616), Vector2(686, 645), Vector2(688, 616)], "caches": [Vector2(621, 642)]},
			# Hold Sequence: three lookouts held in order, out from the start
			# and back to the Exit beside it (the last one is the old
			# DefendZone spot).
			{"mission": &"hold_sequence", "horde_radius": -1,
				"polygon": [Vector2(0, 800), Vector2(523, 800), Vector2(523, 850), Vector2(500, 880), Vector2(500, 1466), Vector2(0, 1466)],
				"exit": [Vector2(523, 822), 38298331],
				"holds": [Vector2(447, 837), Vector2(408, 918), Vector2(431, 983)], "caches": [Vector2(301, 1052)]},
			{"mission": &"holdout", "horde_radius": -1,
				"polygon": [Vector2(523, 800), Vector2(880, 800), Vector2(880, 1466), Vector2(500, 1466), Vector2(500, 880), Vector2(523, 850)],
				"exit": "pier",
				"defend": Vector2(637, 1045), "caches": [Vector2(536, 835)]},
		],
		# Crossings between parts that stay shut, [point, OSM way]: the
		# Caminho do Forte between parts 2 and 4.
		"closed": [[Vector2(559, 800), 233892907]],
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
const EXPEDITIONS: String = "res://game/world/handmade/expeditions/"  ## places with "parts" (_paths_for)
## Where this build writes (_paths_for): the folder, the scene the game plays
## (whole island), the Terrain3D data folder, its textures, the grid picture
## and, for expeditions, the shared scene the others inherit from.
var OUT: String
var SCENE: String
var TERRAIN: String
var GROUND: String
var GRID: String
var BASE: String
var _custom_out: bool = false  ## --out-dir given
var _fail_part: int = 0  ## --fail-part <n>: force part n to fail after it is written (tests the restore)
var _crossings: Array = []  ## expedition: [point, direction from part k into k + 1, portal polygon] per crossing
var _kit_meshes: Dictionary = {}  ## model -> Mesh (_kit_mesh_cached)
var _whole_markers: Array[Node] = []  ## expedition: the whole island's markers, kept off _root while the parts are built
var _pier_top: float = 0.0  ## height of the walkable pier deck (pier_deck), for the boat marker
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
			_custom_out = true
			i += 2
		elif arg == "--fail-part":
			# Test of the atomic save: this part fails its read-back check after
			# being written, so the build must put the previous files back.
			_fail_part = int(value)
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
	_paths_for()
	if ISLANDS.begins_with(TEST_OUT) or P.has("expedition"):
		DirAccess.make_dir_recursive_absolute(OUT)
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


## Output files. A plain island: islands/<biome>_<place>.scn with its
## _data/ folder, _ground.res and _grid.png. An expedition: its own folder
## (EXPEDITIONS/<place>/, out of the islands the routes pick from) with
## base.scn, whole.scn, part_<n>.scn, terrain/, ground.res and *_grid.png.
## --out-dir keeps the same names inside the test folder.
func _paths_for() -> void:
	if P.has("expedition"):
		OUT = ISLANDS if _custom_out else EXPEDITIONS + String(P["expedition"]) + "/"
		SCENE = OUT + "whole.scn"
		TERRAIN = OUT + "terrain"
		GROUND = OUT + "ground.res"
		GRID = OUT + "whole_grid.png"
		BASE = OUT + "base.scn"
	else:
		OUT = ISLANDS
		SCENE = ISLANDS + NAME + ".scn"
		TERRAIN = ISLANDS + NAME + "_data"
		GROUND = ISLANDS + NAME + "_ground.res"
		GRID = ISLANDS + NAME + "_grid.png"
		BASE = ""


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
	# An expedition stages its terrain outside its folder: the folder is
	# replaced as a whole (_publish_expedition).
	var stage: String = (OUT.trim_suffix("/") + "_terrain_build") if P.has("parts") else TERRAIN + "_build"
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
	_island_report(map)
	# Expedition parts: built and checked in memory too, before anything is saved.
	var parts: Array = []
	if problems.is_empty() and P.has("parts"):
		parts = _build_parts(map)
		_lap("expedition parts")
	var err: int = OK
	var parts_ok: bool = parts.all(func(part: Dictionary) -> bool: return part["problems"].is_empty())
	if P.has("parts"):
		# All or nothing: the expedition's folder is only replaced when the
		# whole island and every part passed, and comes back as it was when
		# anything fails while writing or reading back (found by Codex).
		if problems.is_empty() and parts_ok:
			err = _publish_expedition(stage, parts, map)
		else:
			print("  nothing saved: the island or a part has problems")
			_clear_dir(stage)
	elif problems.is_empty():
		_clear_dir(TERRAIN)
		DirAccess.make_dir_recursive_absolute(TERRAIN)
		for f in DirAccess.get_files_at(stage):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(stage.path_join(f)), ProjectSettings.globalize_path(TERRAIN.path_join(f)))
		_clear_dir(stage)
		_terrain.set("data_directory", TERRAIN)
		var assets: Resource = _terrain.get("assets")
		ResourceSaver.save(assets, GROUND)
		assets.take_over_path(GROUND)
		var packed := PackedScene.new()
		packed.pack(_root)
		# Binary: the copies of grass and rocks make a text scene far too big and slow.
		err = ResourceSaver.save(packed, SCENE, ResourceSaver.FLAG_COMPRESS)
		_lap("saved %s (%s)" % [SCENE, error_string(err)])
		HandmadeIsland.grid_image(map).save_png(GRID)
	else:
		print("  not saved: the island has problems (below)")
		_clear_dir(stage)
	for p in problems:
		print("  PROBLEM: ", p)
	if problems.is_empty() and err == OK and parts_ok:
		print("  no problems")
	elif not parts_ok:
		print("  PROBLEM: some expedition parts have problems (above)")
	elif err != OK:
		print("  PROBLEM: saving failed (%s)" % error_string(err))
	return problems.is_empty() and err == OK and parts_ok


## The whole island's numbers: cells, the Activate route, choke points, and
## data/reach.png.
func _island_report(map: IslandMap) -> void:
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
	_debug_picture(map, DATA + "reach.png")


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
## Expedition parts (data/reach_part_<n>.png) add `marks`, [point, colour]
## pairs: the boundary walls and rocks, the markers.
func _debug_picture(map: IslandMap, file: String, marks: Array = []) -> void:
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
	for m: Array in marks:
		var p: Vector2 = m[0]
		if p.x >= 0.0 and p.y >= 0.0 and p.x < N and p.y < N:
			img.set_pixel(int(p.x), int(p.y), m[1])
	img.save_png(file)


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
## (UV 1 = 1 m). `local` projects in the object's own space instead of the
## world's: planks and blocks then follow a turned box (bridge decks, pier
## blocks, posts), and the box must not be scaled. Null when the place has
## no texture with that role. Cached: one material per combination.
func _role_material(role: String, metres: float, tint: Color = Color.WHITE, uv: bool = false, local: bool = false) -> StandardMaterial3D:
	assert(metres > 0.0)
	var key: String = "mat/%s/%s/%s/%s/%s" % [role, metres, tint, uv, local]
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
			m.uv1_world_triplanar = not local
			m.uv1_scale = Vector3.ONE / metres
	_materials[key] = m
	return m


## _role_material, or a plain `fallback` colour when the place has no
## texture with that role (cached too, so boxes share one material).
func _role_or(role: String, metres: float, tint: Color, fallback: Color, local: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = _role_material(role, metres, tint, false, local)
	if m != null:
		return m
	var key: String = "plain/%s" % fallback
	if not _materials.has(key):
		_materials[key] = _mat(fallback, 0.8)
	return _materials[key]


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
		inst.material_override = _role_or("concrete", CONCRETE_M, CONCRETE_TINT, item[2])
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


## Bridges: one deck per straight span (HandmadeIsland walks the grid
## over Bridges/ at the deck's top), from the path height at one end to the
## other, with low parapets as decoration. The OSM surface picks the
## texture: wood planks, concrete, or granite (pebblestone and the rest).
func _place_bridges() -> void:
	var count: int = 0
	for path in _paths:
		if not path[3]:
			continue
		var deck_mat: StandardMaterial3D = _bridge_material(String((path[4] as Dictionary).get("surface", "")))
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


## A bridge deck's material from its OSM surface. Projected in the deck's
## own space, so planks and stones follow a turned deck.
func _bridge_material(surface: String) -> StandardMaterial3D:
	var plain := Color(0.55, 0.52, 0.47)
	if surface == "wood":
		return _role_or("wood", WOOD_M, WOOD_TINT, plain, true)
	if surface in ["concrete", "paved", "asphalt"]:
		return _role_or("concrete", CONCRETE_M, CONCRETE_TINT, plain, true)
	var m: StandardMaterial3D = _role_material("granite", GRANITE_M, GRANITE_TINT, false, true)
	return m if m != null else _role_or("concrete", CONCRETE_M, CONCRETE_TINT, plain, true)


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
		for asset: String in meta["textures"]:
			if meta["textures"][asset] == "facade":  # the scan's relief: cracks, formwork, stains
				wall_mat.normal_enabled = true
				wall_mat.normal_texture = _cached_texture(asset, "nor_gl.jpg")
				wall_mat.roughness = 1.0
				wall_mat.roughness_texture = _cached_texture(asset, "rough.jpg")
				wall_mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	var roof_mat: StandardMaterial3D = _mat(P["roof_color"], 0.85)
	# Hashima: concrete slabs, and corrugated iron on the gabled pit 4.
	var slab_mat: StandardMaterial3D = _role_or("concrete", CONCRETE_M, SLAB_TINT, P["roof_color"])
	var sheet_mat: StandardMaterial3D = _role_or("sheet", SHEET_M, Color.WHITE, P["roof_color"])
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
		mesh.surface_set_material(1, slab_mat if flat else (sheet_mat if shape in ["gabled", "pitched"] else roof_mat))
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
		inst.material_override = _role_or("concrete", CONCRETE_M, CONCRETE_TINT, Color(0.62, 0.61, 0.58))
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
## around Y) added to `group`; `mat` (a texture material) replaces the
## plain colour.
func _box(group: String, name: String, size: Vector3, centre: Vector3, color: Color, yaw: float = 0.0, mat: Material = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = name
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat if mat != null else _mat(color, 0.8)
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
	var stone_c := Color(0.5, 0.49, 0.46)
	_box("Buildings", "ShrineBase", Vector3(4.5, 0.8, 5.5), c + Vector3(0, 0.1, 0), stone_c, yaw, _role_or("concrete", CONCRETE_M, Color(0.95, 0.96, 0.98), stone_c, true))
	var wood_c := Color(0.36, 0.24, 0.17)
	var hall := _box("Buildings", "ShrineHall", Vector3(3.2, 2.6, 4.0), c + Vector3(0, 1.8, 0), wood_c, yaw, _role_or("wood", WOOD_M, Color(1.15, 0.95, 0.8), wood_c, true))
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plan := PackedVector2Array([Vector2(-2.1, -2.6), Vector2(2.1, -2.6), Vector2(2.1, 2.6), Vector2(-2.1, 2.6)])
	_gable(roof, plan, 1.3, _turn(plan), roof)  # one mesh, gable ends too; hall-local: eaves 1.3 m above its centre
	var rm := MeshInstance3D.new()
	rm.name = "Roof"
	rm.mesh = roof.commit()
	rm.material_override = _role_or("concrete", CONCRETE_M, Color(0.45, 0.45, 0.48), Color(0.22, 0.22, 0.24))  # dark grey roof
	hall.add_child(rm)
	rm.owner = _root
	var gate: Vector3 = c + fwd * 7.0
	gate.y = height_at(gate.x, gate.z)
	var red := Color(0.55, 0.2, 0.15)
	var red_m: StandardMaterial3D = _role_or("wood", WOOD_M, TORII_RED, red, true)
	for s: float in [-1.4, 1.4]:
		var post: Vector3 = gate + side * s
		_box("Buildings", "ToriiPillar", Vector3(0.35, 3.6, 0.35), post + Vector3(0, 1.8, 0), red, yaw, red_m)
	_box("Decor", "ToriiTop", Vector3(4.2, 0.3, 0.45), gate + Vector3(0, 3.75, 0), red, yaw, red_m)
	_box("Decor", "ToriiTie", Vector3(3.4, 0.2, 0.25), gate + Vector3(0, 3.1, 0), red, yaw, red_m)


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
	var steel: StandardMaterial3D = _role_or("metal", METAL_M, METAL_TINT, Color(0.3, 0.27, 0.24), true)
	_box("Decor", "Conveyor_%d" % k, Vector3(1.6, 0.5, length), Vector3(mid.x, belt_y, mid.y), Color(0.3, 0.27, 0.24), yaw, steel)
	_box("Decor", "ConveyorRoof_%d" % k, Vector3(2.2, 0.15, length), Vector3(mid.x, belt_y + 1.6, mid.y), Color(0.42, 0.3, 0.22), yaw,
		_role_or("sheet", SHEET_M, Color.WHITE, Color(0.42, 0.3, 0.22), true))
	var n: int = maxi(2, int(length / 4.0) + 1)
	for j in n:
		var q: Vector2 = mid + u * lerpf(-length * 0.5 + 0.5, length * 0.5 - 0.5, float(j) / (n - 1))
		var gy: float = height_at(q.x, q.y)
		_box("Buildings", "ConveyorPost_%d_%d" % [k, j], Vector3(0.5, belt_y - gy, 0.5), Vector3(q.x, (belt_y + gy) * 0.5, q.y), Color(0.35, 0.3, 0.26), yaw, steel)


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
		[BoxMesh.new(), Vector3(4.5, 18.0, 4.5) * s, Vector3(0, 9.0, 0) * s, _role_or("concrete", CONCRETE_M, WHITE_CONCRETE, Color(0.95, 0.94, 0.9), true)],
		[CylinderMesh.new(), Vector3(2.0, 3.0, 2.0) * s, Vector3(0, 19.5, 0) * s, _role_or("metal", METAL_M, IRON_TINT, Color(0.15, 0.17, 0.2), true)],
		[CylinderMesh.new(), Vector3(2.4, 1.2, 2.4) * s, Vector3(0, 21.6, 0) * s, _role_or("metal", METAL_M, RED_METAL, Color(0.7, 0.15, 0.12), true)],
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
		mi.material_override = part[3]
		node.add_child(mi)
		mi.owner = _root


## The pier at the fort: a 4 m wide stone block along each side of its OSM
## outline. Decoration, unless the place has "pier_deck": then every block
## is a deck in Bridges/ (the grid walks it, also over the water) whose top
## is just above the highest dry ground of the outline, where the fort's
## steps come down (Berlenga: 0.6 m), so the steps lead onto it.
func _pier(pts: PackedVector2Array, k: int) -> void:
	var deck: bool = P.get("pier_deck", false)
	var top: float = 1.55  # the decoration's old top
	if deck:
		var land: float = 0.6
		for p in pts:
			var h: float = height_at(p.x, p.y)
			if h > SEA + 0.3:
				land = maxf(land, h)
		top = land + 0.1
		_pier_top = top
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var mi := MeshInstance3D.new()
		mi.name = "Pier_%d_%d" % [k, i]
		var bm := BoxMesh.new()
		# A deck reaches down to the sea floor (4 m): no gap under it.
		var tall: float = top + 4.0 if deck else 2.5
		bm.size = Vector3(4.0, tall, a.distance_to(b) + 2.0)
		mi.mesh = bm
		mi.material_override = _role_or("concrete", CONCRETE_M, CONCRETE_TINT, Color(0.6, 0.58, 0.54), true)
		var dir := Vector3(b.x - a.x, 0, b.y - a.y).normalized()
		mi.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), Vector3((a.x + b.x) * 0.5, top - tall * 0.5, (a.y + b.y) * 0.5))
		_add(mi, "Bridges" if deck else "Decor")
	if deck:
		print("  pier %d: walkable deck, %d blocks, top %.2f m" % [k, pts.size() - 1, top])


## _kit_mesh, loaded once per build.
func _kit_mesh_cached(model: String) -> Mesh:
	if not _kit_meshes.has(model):
		_kit_meshes[model] = _kit_mesh(model)
	return _kit_meshes[model]


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
	inst.material_override = _role_or("concrete", CONCRETE_M, CONCRETE_TINT, Color(0.6, 0.59, 0.56))
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


func _nearest_clear(f: FlowField, c: Vector2i, r: int, clear: int = 2) -> Vector2i:
	var best := c
	var bd: float = INF
	for z in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			var d: float = Vector2(c).distance_to(Vector2(x, z))
			if d < bd and _clear(f, Vector2i(x, z), clear):
				bd = d
				best = Vector2i(x, z)
	return best


## Clear (every cell within `clear` metres walkable), reachable cell nearest
## to `p`, between r_min and r_max metres away.
func _reachable_near(f: FlowField, reach: PackedInt32Array, p: Vector2, r_min: float, r_max: float, clear: int = 4) -> Vector2:
	var best := p
	var bd: float = INF
	for z in range(int(p.y - r_max), int(p.y + r_max) + 1):
		for x in range(int(p.x - r_max), int(p.x + r_max) + 1):
			if x < 2 or z < 2 or x >= N - 2 or z >= N - 2:
				continue
			var d: float = p.distance_to(Vector2(x, z))
			if d < r_min or d > r_max or d >= bd or reach[z * N + x] >= FlowField.UNREACHABLE:
				continue
			if _clear(f, Vector2i(x, z), clear):
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


# ---------------------------------------------------------------- expedition parts

const PORTAL_WIDTH: float = 12.0  ## the strip two parts share at a crossing: metres across the path...
const PORTAL_DEPTH: float = 12.0  ## ...and how far it reaches into each part along the path
## Reachable cells under which a part plays without horde_radius (the
## horde's field covers the whole part, as on Hashima: 51 thousand cells).
const SMALL_PART: int = 60000
const WALL_TINT := Color(1.75, 1.72, 1.66)  ## landmarks.gd STONE_TINT: the "stone" picture as warm grey granite
## Flat stones of the dry-stone walls (about 0.4 m, laid at 1.3-1.7 x) and
## the boulders of the rock bands (about 3 m, laid at 0.4-0.8 x).
const WALL_STONES: Array[String] = ["Pebble_Square_1", "Pebble_Square_2", "Pebble_Square_3", "Pebble_Square_4", "Pebble_Square_5", "Pebble_Square_6"]
const BAND_ROCKS: Array[String] = ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
const TYPE_INSTANTIATED: int = 0x7FFFFFFF  ## SceneState: a node that comes from the base scene
const FLAG_ID_IS_PATH: int = 1 << 30  ## SceneState: a parent given as a path (node_paths)
const NAME_MASK: int = (1 << 18) - 1  ## SceneState: the name index (the bits above hold the node's index)


func _poly(spec: Dictionary) -> PackedVector2Array:
	return PackedVector2Array(spec["polygon"])


## Shoelace area of an open polygon (the last point joins the first).
func _area_open(pts: PackedVector2Array) -> float:
	var a: float = 0.0
	for i in pts.size():
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		a += p.x * q.y - q.x * p.y
	return a * 0.5


func _cell3(c: Vector2) -> Vector3:
	return Vector3(floorf(c.x) + 0.5, 0, floorf(c.y) + 0.5)


## Builds the parts (PLACES "parts") on _root in memory, one after the
## other, and checks each; nothing is saved here. Returns one Dictionary per
## part (see _build_part). The whole island's markers wait in _whole_markers.
func _build_parts(whole: IslandMap) -> Array:
	var parts: Array = P["parts"]
	_crossings.clear()
	for k in parts.size() - 1:
		var ex: Array = parts[k]["exit"]
		var c: Array = _crossing(_poly(parts[k]), ex[0], ex[1])
		if c.is_empty() or (c[0] as Vector2).distance_to(ex[0]) > 15.0:
			# No crossing found: the given point, heading for the next part.
			print("  WARNING: way %d does not cross part %d's outline near (%d, %d)" % [ex[1], k + 1, int(ex[0].x), int(ex[0].y)])
			c = [ex[0], (_centroid(_poly(parts[k + 1])) - ex[0]).normalized()]
		# Only over the two parts it joins: a rectangle near a corner of the
		# outlines (part 3's, at (523, 800)) would reach into a third part.
		var pair: PackedVector2Array = _biggest(Geometry2D.merge_polygons(_poly(parts[k]), _poly(parts[k + 1])))
		_crossings.append([c[0], c[1], _biggest(Geometry2D.intersect_polygons(_portal(c[0], c[1]), pair))])
	# Two portals into the same part (part 3: in at (521, 800), out at
	# (523, 822)) may overlap there: that ground stays only in the part they
	# share, else parts 2 and 4 would share cells (found by Codex).
	var raw: Array = _crossings.map(func(cr: Array) -> PackedVector2Array: return cr[2])
	for k in _crossings.size() - 1:
		for both: PackedVector2Array in Geometry2D.intersect_polygons(raw[k], raw[k + 1]):
			for j: int in [k, k + 1]:
				_crossings[j][2] = _biggest(Geometry2D.clip_polygons(_crossings[j][2], both))
	for k in _crossings.size():
		var cr: Array = _crossings[k]
		print("  crossing part %d > %d at (%.1f, %.1f), path heading (%.2f, %.2f): portal %.0f m2 (at most %d x %d m)"
			% [k + 1, k + 2, cr[0].x, cr[0].y, cr[1].x, cr[1].y, absf(_area_open(cr[2])), int(PORTAL_WIDTH), int(PORTAL_DEPTH * 2.0)])
	var markers: Node = _root.get_node("Markers")
	_whole_markers.clear()
	for m in markers.get_children():
		markers.remove_child(m)
		_whole_markers.append(m)
	var out: Array = []
	for k in parts.size():
		out.append(_build_part(k, whole))
	_root.play_area = PackedVector2Array()
	_root.mission = &""
	_root.horde_radius = P["horde_radius"]
	_check_overlaps(out)
	return out


## The largest polygon of a Geometry2D result (empty when none).
func _biggest(polys: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	for poly in polys:
		if absf(_area_open(poly)) > absf(_area_open(best)):
			best = poly
	return best


## No cell may be walkable in two parts that are not consecutive, and two
## consecutive parts share only cells of their portal. Problems go to the
## later part of each pair (it is then not saved, nor is anything else).
func _check_overlaps(parts: Array) -> void:
	var walk: Array[PackedByteArray] = []
	for part: Dictionary in parts:
		walk.append(part["blocked"])
	var n: int = walk.size()
	var gates: Array[PackedVector2Array] = []
	for cr: Array in _crossings:
		gates.append(Geometry2D.offset_polygon(cr[2], 0.5)[0])
	var shared: Dictionary = {}  # "a,b" -> [count, first cell, cells outside the portal]
	for i in N * N:
		var mask: int = 0
		for k in n:
			if walk[k][i] == 0:
				mask |= 1 << k
		if mask & (mask - 1) == 0:
			continue  # one part or none
		for a in n:
			for b in range(a + 1, n):
				if mask & (1 << a) == 0 or mask & (1 << b) == 0:
					continue
				var key: String = "%d,%d" % [a, b]
				if not shared.has(key):
					shared[key] = [0, Vector2i(i % N, i / N), 0]
				shared[key][0] += 1
				if b == a + 1 and not Geometry2D.is_point_in_polygon(Vector2(i % N + 0.5, i / N + 0.5), gates[a]):
					shared[key][2] += 1
	for key: String in shared:
		var ab: PackedStringArray = key.split(",")
		var a: int = int(ab[0])
		var b: int = int(ab[1])
		var s: Array = shared[key]
		var why: String = ""
		if b != a + 1:
			why = "%d cells walkable in both part %d and part %d, e.g. (%d, %d)" % [s[0], a + 1, b + 1, s[1].x, s[1].y]
		elif s[2] > 0:
			why = "%d cells walkable in parts %d and %d outside their portal" % [s[2], a + 1, b + 1]
		if why != "":
			parts[b]["problems"].append(why)
			print("  PROBLEM: ", why)
		print("  parts %d and %d share %d walkable cells%s" % [a + 1, b + 1, s[0], " (their portal)" if b == a + 1 and s[2] == 0 else ""])


## Where the OSM way `way_id` crosses the polygon's outline, nearest to
## `near`: [point, the way's direction there pointing out of the polygon],
## or [] when it does not cross.
func _crossing(poly: PackedVector2Array, near: Vector2, way_id: int) -> Array:
	var best: Array = []
	var bd: float = INF
	for path: Array in _paths:
		if int(path[4].get("osm_id", -1)) != way_id:
			continue
		var pts: PackedVector2Array = path[0]
		for i in pts.size() - 1:
			for j in poly.size():
				var hit: Variant = Geometry2D.segment_intersects_segment(pts[i], pts[i + 1], poly[j], poly[(j + 1) % poly.size()])
				if hit == null or (hit as Vector2).distance_to(near) >= bd:
					continue
				bd = (hit as Vector2).distance_to(near)
				var d: Vector2 = (pts[i + 1] - pts[i]).normalized()
				if Geometry2D.is_point_in_polygon(hit + d, poly):
					d = -d
				best = [hit, d]
	return best


## The strip both parts share at a crossing: PORTAL_WIDTH across the path,
## PORTAL_DEPTH along it into each part, so the way through is walkable from
## both sides (the Exit of one part and the start of the next lie in it).
func _portal(c: Vector2, d: Vector2) -> PackedVector2Array:
	var side := Vector2(-d.y, d.x) * PORTAL_WIDTH * 0.5
	var a: Vector2 = c - d * PORTAL_DEPTH
	var e: Vector2 = c + d * PORTAL_DEPTH
	return PackedVector2Array([a - side, e - side, e + side, a + side])


## Part k's play_area: its polygon joined with the portals at its entry and exit.
func _play_area(k: int) -> PackedVector2Array:
	var area: PackedVector2Array = _poly(P["parts"][k])
	for j: int in [k - 1, k]:
		if j < 0 or j >= _crossings.size():
			continue
		var best := area
		var ba: float = 0.0
		for piece: PackedVector2Array in Geometry2D.merge_polygons(area, _crossings[j][2]):
			if absf(_area_open(piece)) > ba:
				ba = absf(_area_open(piece))
				best = piece
		area = best
	return area


## One part on _root: its play area, mission and markers, the boundary
## dressing, then the checks (build_map's problems, closed crossings) and
## its numbers. Its nodes are taken off _root again at the end. Returns
## {name, area, mission, horde_radius, markers, decor, problems, grid}.
func _build_part(k: int, whole: IslandMap) -> Dictionary:
	var spec: Dictionary = P["parts"][k]
	var name: String = "part_%d" % (k + 1)
	var poly: PackedVector2Array = _poly(spec)
	var area: PackedVector2Array = _play_area(k)
	var last: bool = not spec["exit"] is Array
	_root.play_area = area
	_root.mission = spec["mission"]
	_root.horde_radius = 0
	var ignored: Array[String] = []
	var f: FlowField = _root.build_map(ignored).field  # no markers yet: its problems do not count
	f.max_distance = 0
	# Entry: part 1 lands on the beach like the whole island; the others start
	# 8 m into the part along the path that came in. Every marker sits on a
	# reachable cell with 4 m clear around it (the pier boat: 1 m, the deck is
	# narrow).
	var start: Vector2i
	if k == 0:
		start = f.world_to_cell(whole.player_start)
	else:
		var cr: Array = _crossings[k - 1]
		start = _nearest_clear(f, Vector2i(((cr[0] as Vector2) + cr[1] * 8.0).floor()), 12, 4)
	f.compute_now(start)
	var reach: PackedInt32Array = f.dist.duplicate()
	_marker("PlayerStart", _cell3(Vector2(start)))
	if k == 0:
		_marker("Boat", whole.boat, whole.boat_dir)
	elif not last:
		# The game hides this boat (the way back is on foot); IslandMap needs one.
		var cr: Array = _crossings[k - 1]
		var b: Vector2 = _reachable_near(f, reach, (cr[0] as Vector2) + cr[1] * 3.0, 0.0, 10.0)
		_marker("Boat", _cell3(b), Vector3(-cr[1].x, 0, -cr[1].y))
	if last:
		# The rescue boat at the end of the fort's pier.
		var b: Vector2 = _reachable_near(f, reach, _pier_end(), 0.0, 12.0, 1)
		_marker("Boat", _cell3(b), _seaward(Vector2i(b)))
		var mk: Node3D = _root.get_node("Markers/Boat")
		mk.position.y = maxf(mk.position.y, _pier_top)  # on the deck, not the sea floor
	else:
		var cr: Array = _crossings[k]
		_marker("Exit", _cell3(_reachable_near(f, reach, (cr[0] as Vector2) + cr[1] * 4.0, 0.0, 10.0)))
	if spec.has("rescue"):
		_marker("RescueTarget", _cell3(_reachable_near(f, reach, spec["rescue"], 0.0, 30.0)))
	var gens: Array = spec.get("generators", [])
	for g in gens.size():
		_marker("Generator%d" % (g + 1), _cell3(_reachable_near(f, reach, gens[g], 0.0, 30.0)))
	if spec.has("defend"):
		_marker("DefendZone", _cell3(_reachable_near(f, reach, spec["defend"], 0.0, 30.0)))
	var holds: Array = spec.get("holds", [])
	for h in holds.size():
		_marker("HoldPoint_%d" % (h + 1), _cell3(_reachable_near(f, reach, holds[h], 0.0, 30.0)))
	# Light the Signals: the signals (4 m clear), the lighthouse beside its
	# tower (2 m clear: the courtyard of the keepers' house is narrow), and
	# each signal's fuel at a house door (1 m clear).
	var signals: Array = spec.get("signals", [])
	for s in signals.size():
		_marker("Signal_%d" % (s + 1), _cell3(_reachable_near(f, reach, signals[s], 0.0, 30.0)))
	if spec.has("lighthouse"):
		_marker("Lighthouse", _cell3(_reachable_near(f, reach, spec["lighthouse"], 0.0, 30.0, 2)))
	var fuel: Array = spec.get("fuel", [])
	for u in fuel.size():
		_marker("Fuel_%d" % (u + 1), _cell3(_reachable_near(f, reach, fuel[u], 0.0, 30.0, 1)))
	var caches: Array = spec.get("caches", [])
	for c in caches.size():
		_marker("Cache%d" % (c + 1), _cell3(_reachable_near(f, reach, caches[c], 0.0, 30.0)))
	var dressing: Array = _boundary(k, poly, f, reach, whole.field)
	var boundary: Node3D = dressing[0]
	_add(boundary, "Decor")
	for n in boundary.find_children("*", "", true, false):
		n.owner = _root
	# The checks, on the part as it will be saved.
	var problems: Array[String] = []
	var map: IslandMap = _root.build_map(problems)
	var mf: FlowField = map.field
	mf.max_distance = 0
	var t0: int = Time.get_ticks_usec()
	mf.compute_now(start)
	var bfs_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	var open: int = 0
	for b in mf.blocked:
		open += 1 if b == 0 else 0
	var reached: int = 0
	for d in mf.dist:
		reached += 1 if d < FlowField.UNREACHABLE else 0
	var closed_txt: PackedStringArray = []
	for c: Array in P.get("closed", []):
		var cross: Array = _crossing(poly, c[0], c[1])
		if cross.is_empty() or (cross[0] as Vector2).distance_to(c[0]) > 20.0:
			continue  # not on this part's outline
		for portal: Array in _crossings:
			if Geometry2D.is_point_in_polygon(cross[0], Geometry2D.offset_polygon(portal[2], 4.0)[0]):
				problems.append("a portal opens the closed crossing at (%d, %d)" % [int(c[0].x), int(c[0].y)])
		var far: Vector3 = _cell3((cross[0] as Vector2) + cross[1] * 8.0)
		var shut: bool = mf.distance_at(far) >= FlowField.UNREACHABLE
		if not shut:
			problems.append("the closed crossing at (%d, %d) can be walked through" % [int(c[0].x), int(c[0].y)])
		closed_txt.append("(%d, %d) %s" % [int(c[0].x), int(c[0].y), "closed" if shut else "OPEN"])
	var hr: int = spec["horde_radius"]
	if hr < 0:
		hr = 0 if reached <= SMALL_PART else int(P["horde_radius"])
	var route: Array = _route(map)
	print("%s (%s): walkable %d cells inside the play area, %d reachable from the start (full horde field %.0f ms) -> horde_radius %d"
		% [name, spec["mission"], open, reached, bfs_ms, hr])
	print("  route %s: %s = %d m" % [" > ".join(route[0]), " + ".join(route[1]), route[2]])
	if not closed_txt.is_empty():
		print("  closed crossings: ", ", ".join(closed_txt))
	print("  boundary: ", dressing[1])
	var marks: Array = dressing[2]
	for m: Node3D in _root.get_node("Markers").get_children():
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				marks.append([Vector2(m.position.x + dx, m.position.z + dz), Color.RED])
	_debug_picture(map, DATA + "reach_%s.png" % name, marks)
	for p in problems:
		print("  PROBLEM: ", p)
	var grid: Image = HandmadeIsland.grid_image(map)
	# Off _root again: the next part, base.scn and whole.scn must not have them.
	var nodes: Array[Node] = []
	var markers: Node = _root.get_node("Markers")
	for m in markers.get_children():
		markers.remove_child(m)
		nodes.append(m)
	_root.get_node("Decor").remove_child(boundary)
	var decor: Array[Node] = [boundary]
	return {"name": name, "area": area, "mission": spec["mission"], "horde_radius": hr, "markers": nodes,
		"decor": decor, "problems": problems, "grid": grid, "blocked": mf.blocked}


## The mission's walk on the grid: start > generators (nearest first) >
## rescue target or defence zone > Exit (the last part: the boat on the
## pier). Returns [labels, metres per leg as text, total metres].
func _route(map: IslandMap) -> Array:
	var f: FlowField = map.field
	var labels: PackedStringArray = ["start"]
	var legs: PackedStringArray = []
	var total: int = 0
	var cur: Vector3 = map.player_start
	var gens: Array[Vector3] = []
	gens.assign(map.generators)
	var stops: Array = []  # [label, point]
	while not gens.is_empty():
		f.compute_now(f.world_to_cell(cur))
		var best: int = 0
		for g in gens.size():
			if f.distance_at(gens[g]) < f.distance_at(gens[best]):
				best = g
		stops.append(["Generator", gens[best]])
		cur = gens[best]
		gens.remove_at(best)
	if map.rescue_target.x >= 0.0:
		stops.append(["RescueTarget", map.rescue_target])
	if map.defend_zone.x >= 0.0:
		stops.append(["DefendZone", map.defend_zone])
	for h in map.hold_points.size():
		stops.append(["HoldPoint_%d" % (h + 1), map.hold_points[h]])
	for s in map.signal_points.size():  # each signal's fuel, then the signal
		if s < map.signal_fuel.size():
			stops.append(["Fuel_%d" % (s + 1), map.signal_fuel[s]])
		var last: bool = map.signal_lighthouse and s == map.signal_points.size() - 1
		stops.append(["Lighthouse" if last else "Signal_%d" % (s + 1), map.signal_points[s]])
	stops.append(["Exit", map.exit] if map.exit.x >= 0.0 else ["Boat", map.boat])
	cur = map.player_start
	for s: Array in stops:
		f.compute_now(f.world_to_cell(s[1]))
		var d: int = f.distance_at(cur)
		labels.append(s[0])
		legs.append(str(d) if d < FlowField.UNREACHABLE else "unreachable")
		total += d if d < FlowField.UNREACHABLE else 0
		cur = s[1]
	return [labels, legs, total]


## The pier's point over the deepest water (the rescue boat's mooring).
func _pier_end() -> Vector2:
	var best := Vector2(N * 0.5, N * 0.5)
	var low: float = INF
	for pier in _piers:
		for p in pier:
			if height_at(p.x, p.y) < low:
				low = height_at(p.x, p.y)
				best = p
	return best


## Out to sea from cell `c` (towards lower coast distance), for the boat's +Z.
func _seaward(c: Vector2i) -> Vector3:
	var i: int = c.y * N + c.x
	var s := Vector2(_t[i - 1] - _t[i + 1], _t[i - N] - _t[i + N]).normalized()
	return Vector3(s.x, 0, s.y)


## Natural limits of a part: where its polygon crosses open land (the cell
## 1.5 m inside is reached from the start and the ground 2.5 m outside is
## open on the whole island), dry-stone walls and bands of granite boulders
## just outside the polygon. Decoration: the play area already blocks.
## Never across a portal (the path's way through stays open, like a gap in a
## field wall). Each run closes gaps of up to 3 m, goes on 3 m into the
## cliff or rock it meets, and starts and ends with boulders; a closed
## crossing gets boulders over the path (a rockfall), not a wall. The same
## random numbers every build. Returns [Node3D "Boundary", summary, marks
## for the reach picture].
func _boundary(k: int, poly: PackedVector2Array, f: FlowField, reach: PackedInt32Array, whole: FlowField) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + k
	var gates: Array[PackedVector2Array] = []
	for j: int in [k - 1, k]:
		if j >= 0 and j < _crossings.size():
			gates.append(Geometry2D.offset_polygon(_crossings[j][2], 2.0)[0])
	var closed: Array[Vector2] = []
	for c: Array in P.get("closed", []):
		closed.append(c[0])
	# Samples every metre round the outline: point, outward normal, open?
	var pos := PackedVector2Array()
	var nor := PackedVector2Array()
	var open: Array[bool] = []
	var gate: Array[bool] = []
	var n: int = poly.size()
	for i in n:
		var a: Vector2 = poly[i]
		var e: Vector2 = poly[(i + 1) % n]
		var length: float = a.distance_to(e)
		if length < 1.0:
			continue
		var t: Vector2 = (e - a) / length
		var out := Vector2(-t.y, t.x)
		if Geometry2D.is_point_in_polygon((a + e) * 0.5 + out * 0.5, poly):
			out = -out
		for s in int(length):
			var p: Vector2 = a + t * (s + 0.5)
			var in_gate: bool = gates.any(func(g: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(p, g))
			var inside := Vector2i((p - out * 1.5).floor())
			var outside := Vector2i((p + out * 2.5).floor())
			var reached: bool = inside.x > 0 and inside.y > 0 and inside.x < N - 1 and inside.y < N - 1 \
				and reach[inside.y * N + inside.x] < FlowField.UNREACHABLE
			pos.append(p)
			nor.append(out)
			gate.append(in_gate)
			open.append(not in_gate and reached and not whole.is_blocked(outside.x, outside.y))
	var count: int = pos.size()
	var mark: Array[bool] = open.duplicate()
	for i in count:
		if open[i] or gate[i]:
			continue
		var before: bool = false
		var after: bool = false
		for d in range(1, 4):
			before = before or open[(i - d + count) % count]
			after = after or open[(i + d) % count]
		mark[i] = before and after
	for i in count:
		if not open[i]:
			continue
		for dir: int in [-1, 1]:
			if open[(i + dir + count) % count]:
				continue
			for d in range(1, 4):
				var j: int = (i + dir * d + count) % count
				if gate[j]:
					break
				mark[j] = true
	# Runs of marked samples, starting the walk on an unmarked one.
	var s0: int = mark.find(false)
	var runs: Array[PackedInt32Array] = []
	var run := PackedInt32Array()
	for m in count:
		var i: int = (maxi(s0, 0) + m) % count
		if mark[i]:
			run.append(i)
		elif not run.is_empty():
			runs.append(run)
			run = PackedInt32Array()
	if not run.is_empty():
		runs.append(run)
	var stones: Dictionary = {}  # model -> PackedFloat32Array (x, y, z, yaw, size in island space)
	var rocks: Dictionary = {}
	var core := SurfaceTool.new()
	core.begin(Mesh.PRIMITIVE_TRIANGLES)
	var marks: Array = []
	var tally: Dictionary = {"nudged": 0, "dropped": 0}  # copies moved out / left out: they would stand on walkable cells
	var wall_m: int = 0
	var rock_m: int = 0
	for r in runs:
		var length: int = r.size()
		var walls: Array[bool] = []
		walls.resize(length)
		walls.fill(false)
		if length >= 10:  # boulders 3-5 m at each end, walls and bands between
			var m: int = rng.randi_range(3, 5)
			var e: int = length - rng.randi_range(3, 5)
			var is_wall: bool = true
			while m < e:
				var piece: int = rng.randi_range(10, 28) if is_wall else rng.randi_range(4, 9)
				for q in range(m, mini(m + piece, e)):
					walls[q] = is_wall
				m += piece
				is_wall = not is_wall
		for q in length:
			if closed.any(func(c: Vector2) -> bool: return c.distance_to(pos[r[q]]) < 8.0):
				walls[q] = false
		var q0: int = 0
		while q0 < length:
			var q1: int = q0
			while q1 < length and walls[q1] == walls[q0]:
				q1 += 1
			var pts := PackedVector2Array()
			var nrm := PackedVector2Array()
			for q in range(q0, q1):
				pts.append(pos[r[q]])
				nrm.append(nor[r[q]])
				marks.append([pos[r[q]] + nor[r[q]], Color.MAGENTA if walls[q0] else Color.WHITE])
			if walls[q0]:
				_wall(pts, nrm, rng, stones, core, f, tally)
				wall_m += pts.size()
			else:
				_rock_band(pts, nrm, rng, rocks, f, tally)
				rock_m += pts.size()
			q0 = q1
	var node := Node3D.new()
	node.name = "Boundary"
	var stone: Material = _role_material("granite", GRANITE_M, GRANITE_TINT)  # the fort's granite
	if stone == null:
		stone = _role_material("stone", 1.8, WALL_TINT)
	if stone == null:
		stone = _mat(Color(0.62, 0.6, 0.56))
	var mesh: ArrayMesh = core.commit()
	if mesh.get_surface_count() > 0:
		var inst := MeshInstance3D.new()
		inst.name = "WallCore"
		inst.mesh = mesh
		inst.material_override = stone
		node.add_child(inst)
	var n_stones: int = 0
	var n_rocks: int = 0
	for kind: Array in [[stones, "Wall_", stone], [rocks, "Band_", null]]:
		var models: Dictionary = kind[0]
		for model: String in models:
			var arr: PackedFloat32Array = models[model]
			var centre := Vector3.ZERO
			for c in arr.size() / 5:
				centre += Vector3(arr[c * 5], arr[c * 5 + 1], arr[c * 5 + 2])
			centre /= maxi(arr.size() / 5, 1)
			for c in arr.size() / 5:  # relative to the node
				arr[c * 5] -= centre.x
				arr[c * 5 + 1] -= centre.y
				arr[c * 5 + 2] -= centre.z
			var sc := Scatter.new()
			sc.name = String(kind[1]) + model
			sc.position = centre
			sc.mesh = _kit_mesh_cached(model)
			sc.data = arr
			if kind[2] != null:
				sc.material_override = kind[2]
			node.add_child(sc)
			if kind[1] == "Wall_":
				n_stones += arr.size() / 5
			else:
				n_rocks += arr.size() / 5
	var summary: String = "%d m along open land in %d runs: %d m of dry-stone wall (%d stones), %d m of boulders (%d rocks); %d boulders moved out, %d copies left out (over walkable cells)" 		% [wall_m + rock_m, runs.size(), wall_m, n_stones, rock_m, n_rocks, tally["nudged"], tally["dropped"]]
	return [node, summary, marks]


## A dry-stone wall along `pts` (one per metre), 0.6-1.2 m outside the
## outline (`nrm`: outward), gently winding: a battered core in the "stone" material, and
## 4-6 courses of flat stones laid on it, staggered, the top course broken.
func _wall(pts: PackedVector2Array, nrm: PackedVector2Array, rng: RandomNumberGenerator, stones: Dictionary, core: SurfaceTool, f: FlowField, tally: Dictionary) -> void:
	var m: int = pts.size()
	var phase: float = rng.randf() * TAU
	var courses: int = rng.randi_range(4, 6)
	var line := PackedVector2Array()
	var ground := PackedFloat32Array()
	for q in m:
		var c: Vector2 = pts[q] + nrm[q] * (0.9 + 0.3 * sin(q * 0.15 + phase))
		line.append(c)
		ground.append(minf(height_at(c.x - nrm[q].x * 0.4, c.y - nrm[q].y * 0.4), height_at(c.x + nrm[q].x * 0.4, c.y + nrm[q].y * 0.4)))
	var h: float = courses * 0.2 - 0.12
	for q in m - 1:
		var lo: Array[Vector3] = []
		var hi: Array[Vector3] = []
		for side: float in [-1.0, 1.0]:
			for j: int in [q, q + 1]:
				var b: Vector2 = line[j] + nrm[j] * side * 0.32
				var t: Vector2 = line[j] + nrm[j] * side * 0.22
				lo.append(Vector3(b.x, ground[j] - 0.4, b.y))
				hi.append(Vector3(t.x, ground[j] + h, t.y))
		var foot := PackedVector2Array([Vector2(lo[0].x, lo[0].z), Vector2(lo[1].x, lo[1].z), Vector2(lo[3].x, lo[3].z), Vector2(lo[2].x, lo[2].z)])
		if _covers_walkable(f, foot):
			tally["dropped"] += 1
			continue
		for s in 2:  # the two faces (lo/hi 0-1 inner side, 2-3 outer side)
			var face_n := Vector3(nrm[q].x * (2 * s - 1), 0.15, nrm[q].y * (2 * s - 1)).normalized()
			_tri(core, lo[s * 2], lo[s * 2 + 1], hi[s * 2 + 1], face_n)
			_tri(core, lo[s * 2], hi[s * 2 + 1], hi[s * 2], face_n)
		_tri(core, hi[0], hi[1], hi[3], Vector3.UP)
		_tri(core, hi[0], hi[3], hi[2], Vector3.UP)
		for end: int in ([0] if q == 0 else []) + ([1] if q == m - 2 else []):  # the wall's ends
			var along := Vector3(line[q + 1].x - line[q].x, 0, line[q + 1].y - line[q].y).normalized() * (2 * end - 1)
			_tri(core, lo[end], lo[2 + end], hi[2 + end], along)
			_tri(core, lo[end], hi[2 + end], hi[end], along)
	for q in m:
		var t: Vector2 = (line[mini(q + 1, m - 1)] - line[maxi(q - 1, 0)]).normalized()
		if t == Vector2.ZERO:
			t = Vector2(-nrm[q].y, nrm[q].x)
		var yaw: float = atan2(-t.y, t.x)
		for c in courses:
			for s in 2:
				var along: float = s * 0.5 + (c % 2) * 0.25 + rng.randf_range(-0.05, 0.05)
				var size: float = rng.randf_range(1.3, 1.7)
				var model: String = WALL_STONES[rng.randi() % WALL_STONES.size()]
				var skip: bool = (c == courses - 1 and rng.randf() < 0.25) or (q == m - 1 and along > 0.3)
				if skip:
					continue
				var p: Vector2 = line[q] + t * along + nrm[q] * rng.randf_range(-0.04, 0.04)
				var at := Vector3(p.x, ground[q] - 0.1 + c * 0.2 + rng.randf() * 0.03, p.y)
				var turn: float = yaw + rng.randf_range(-0.2, 0.2)
				if not _off_walkable(f, _kit_mesh_cached(model).get_aabb(), at, turn, size):
					tally["dropped"] += 1
					continue
				var arr: PackedFloat32Array = stones.get(model, PackedFloat32Array())
				arr.append_array([at.x, at.y, at.z, turn, size])
				stones[model] = arr


## A band of granite boulders along `pts`, outside the outline: touching or
## overlapping (one every 1.2-2 m, 1.4-2.8 m wide), partly buried, and most
## with a smaller one further out, so the band reads as a barrier and not
## as stones one could walk between. Starts 1.5 m before the section and
## ends 1.5 m after it, over the ends of the walls beside it.
func _rock_band(pts: PackedVector2Array, nrm: PackedVector2Array, rng: RandomNumberGenerator, rocks: Dictionary, f: FlowField, tally: Dictionary) -> void:
	var m: int = pts.size()
	var q: float = -1.5 + rng.randf() * 0.5
	while q < m + 1.5:
		var i: int = clampi(int(q), 0, m - 1)
		var t: Vector2 = (pts[mini(i + 1, m - 1)] - pts[maxi(i - 1, 0)]).normalized()
		if t == Vector2.ZERO:
			t = Vector2(-nrm[i].y, nrm[i].x)
		var s: float = rng.randf_range(0.45, 0.85)
		var at: Vector2 = pts[i] + t * (q - i)
		for second in 2:
			if second == 1:
				if rng.randf() < 0.3:
					break
				s *= rng.randf_range(0.5, 0.75)
			var off: float = 0.4 + 1.5 * s + rng.randf_range(-0.2, 0.3) + (1.6 if second == 1 else 0.0)
			var c: Vector2 = at + nrm[i] * off + t * rng.randf_range(-0.3, 0.3)
			var model: String = BAND_ROCKS[rng.randi() % BAND_ROCKS.size()]
			var yaw: float = rng.randf() * TAU
			# Its box seen from above, after turning and scaling, must not cover a
			# walkable cell (the play area, the portals): pushed out up to 3 m,
			# else left out (found by Codex).
			var placed: bool = false
			for nudge in 7:
				var cc: Vector2 = c + nrm[i] * (nudge * 0.5)
				var g: float = minf(height_at(cc.x, cc.y), minf(height_at(cc.x - nrm[i].x, cc.y - nrm[i].y), height_at(cc.x + nrm[i].x, cc.y + nrm[i].y)))
				var pos := Vector3(cc.x, g - 0.65 * s, cc.y)
				if _off_walkable(f, _kit_mesh_cached(model).get_aabb(), pos, yaw, s):
					var arr: PackedFloat32Array = rocks.get(model, PackedFloat32Array())
					arr.append_array([pos.x, pos.y, pos.z, yaw, s])
					rocks[model] = arr
					tally["nudged"] += 1 if nudge > 0 else 0
					placed = true
					break
			if not placed:
				tally["dropped"] += 1
		q += 0.8 + 1.6 * s * rng.randf_range(0.45, 0.65)


## True when no walkable cell of the part (cell centre) lies under the box
## `box` of a copy at `p`, turned `yaw` and scaled `s` (as Scatter draws it),
## seen from above.
func _off_walkable(f: FlowField, box: AABB, p: Vector3, yaw: float, s: float) -> bool:
	var b: AABB = Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * s), p) * box
	for z in range(floori(b.position.z - 0.5), ceili(b.end.z) + 1):
		for x in range(floori(b.position.x - 0.5), ceili(b.end.x) + 1):
			var cx: float = x + 0.5
			var cz: float = z + 0.5
			if cx >= b.position.x and cx <= b.end.x and cz >= b.position.z and cz <= b.end.z and not f.is_blocked(x, z):
				return false
	return true


## True when a walkable cell centre lies inside `poly` (seen from above).
func _covers_walkable(f: FlowField, poly: PackedVector2Array) -> bool:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	for z in range(floori(r.position.y), ceili(r.end.y) + 1):
		for x in range(floori(r.position.x), ceili(r.end.x) + 1):
			if not f.is_blocked(x, z) and Geometry2D.is_point_in_polygon(Vector2(x + 0.5, z + 0.5), poly):
				return true
	return false


## Publishes the expedition, all or nothing. The folder in place moves
## aside (<folder>.previous), a new one is written (terrain, ground.res,
## base.scn, whole.scn, the parts) and every scene is read back from disk and
## checked. Only when everything passed is the old folder deleted; on any
## error the new folder is deleted and the old one moved back. Files of the
## old folder the build does not make (the editor's .import of the grid
## pictures) are kept.
func _publish_expedition(stage: String, parts: Array, map: IslandMap) -> int:
	var old: String = OUT.trim_suffix("/") + ".previous"
	_remove_tree(old)  # left by a build that crashed half way
	var had_old: bool = DirAccess.dir_exists_absolute(OUT)
	var err: int = OK
	if had_old:
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(OUT), ProjectSettings.globalize_path(old))
		if err != OK:
			print("  PROBLEM: could not move %s aside (%s): nothing saved" % [OUT, error_string(err)])
			_clear_dir(stage)
			return err
	err = DirAccess.make_dir_recursive_absolute(OUT)
	if err == OK:
		err = DirAccess.rename_absolute(ProjectSettings.globalize_path(stage), ProjectSettings.globalize_path(TERRAIN))
		if err != OK:
			print("  PROBLEM: could not move the terrain into %s (%s)" % [TERRAIN, error_string(err)])
	if err == OK:
		_terrain.set("data_directory", TERRAIN)
		var assets: Resource = _terrain.get("assets")
		err = ResourceSaver.save(assets, GROUND)
		assets.take_over_path(GROUND)
	if err == OK:
		err = _save_expedition(parts)
	if err == OK:
		err = HandmadeIsland.grid_image(map).save_png(GRID)
	if err != OK:
		print("  PROBLEM: the expedition failed while saving (%s): %s put back as it was" % [error_string(err), OUT])
		_remove_tree(OUT)
		_clear_dir(stage)
		if had_old:
			DirAccess.rename_absolute(ProjectSettings.globalize_path(old), ProjectSettings.globalize_path(OUT))
		return err
	if had_old:
		for f in DirAccess.get_files_at(old):
			if f.ends_with(".import") and FileAccess.file_exists(OUT + f.trim_suffix(".import")):
				DirAccess.copy_absolute(old.path_join(f), OUT + f)
		_remove_tree(old)
	print("  published %s" % OUT)
	return OK


## Deletes `dir` with everything in it; only expedition folders (game or test).
func _remove_tree(dir: String) -> void:
	dir = dir.trim_suffix("/")
	if not DirAccess.dir_exists_absolute(dir):
		return
	if not (dir.begins_with(EXPEDITIONS) or dir.begins_with(TEST_OUT)) or dir + "/" in [EXPEDITIONS, TEST_OUT]:
		print("  WARNING: refusing to delete %s" % dir)
		return
	for sub in DirAccess.get_directories_at(dir):
		_remove_tree(dir.path_join(sub))
	_clear_dir(dir)


## Saves base.scn (the island without markers, the big file), whole.scn and
## the parts as scenes inherited from base.scn. Each is read back from disk
## and checked with build_map; the first error stops it.
func _save_expedition(parts: Array) -> int:
	var base := PackedScene.new()
	var err: int = base.pack(_root)  # Markers is empty: the markers live in the inherited scenes
	if err == OK:
		err = ResourceSaver.save(base, BASE, ResourceSaver.FLAG_COMPRESS)
	base.take_over_path(BASE)
	_lap("saved %s (%s), %s" % [BASE, error_string(err), _size(BASE)])
	if err != OK:
		return err
	err = _save_inherited(base, SCENE, {}, _whole_markers, [])
	for part: Dictionary in parts:
		if err != OK:
			break
		var path: String = OUT + String(part["name"]) + ".scn"
		var props: Dictionary = {"play_area": part["area"], "mission": part["mission"], "horde_radius": part["horde_radius"]}
		err = _save_inherited(base, path, props, part["markers"], part["decor"])
		if err == OK:
			err = (part["grid"] as Image).save_png(OUT + String(part["name"]) + "_grid.png")
	_lap("saved whole.scn and the parts")
	return err


## A scene inherited from `base` that only stores its differences: these
## root properties, and new nodes under the base's Markers/ and Decor/.
## Godot makes inherited scenes in the editor only (New Inherited Scene), so
## the scene's data is written here as the editor would: the new nodes are
## packed on their own, then the root and the group nodes are turned into
## references to the base's (_inherited). Read back and checked.
func _save_inherited(base: PackedScene, path: String, props: Dictionary, markers: Array[Node], decor: Array[Node]) -> int:
	var tree := Node3D.new()
	tree.name = _root.name
	for group: String in ["Markers", "Decor"]:
		var g := Node3D.new()
		g.name = group
		tree.add_child(g)
		g.owner = tree
		for n: Node in (markers if group == "Markers" else decor):
			if n.get_parent() != null:
				n.get_parent().remove_child(n)
			g.add_child(n)
			n.owner = tree
			for c in n.find_children("*", "", true, false):
				c.owner = tree
	var diff := PackedScene.new()
	var err: int = diff.pack(tree)
	tree.free()
	var packed: PackedScene = _inherited(base, diff, props, markers.size()) if err == OK else null
	if packed == null:
		print("  PROBLEM: %s: could not make the inherited scene, not saved" % path)
		return FAILED
	err = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		print("  PROBLEM: saving %s failed (%s)" % [path, error_string(err)])
		return err
	var loaded: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var back: HandmadeIsland = loaded.instantiate() as HandmadeIsland if loaded != null else null
	if back == null:
		print("  PROBLEM: %s does not load back as a HandmadeIsland" % path)
		return FAILED
	var problems: Array[String] = []
	var map: IslandMap = back.build_map(problems)
	if _fail_part > 0 and path.ends_with("part_%d.scn" % _fail_part):
		problems.append("forced failure (--fail-part %d)" % _fail_part)
	print("  saved %s (%s), %s; read back: %d markers, mission '%s', %d generators, %s"
		% [path, error_string(err), _size(path), back.get_node("Markers").get_child_count(), back.mission, map.generators.size(),
			"no problems" if problems.is_empty() else "PROBLEMS %s" % [problems]])
	back.free()
	return OK if problems.is_empty() else FAILED


## `diff` (a root with the groups Markers/Decor holding new nodes) as a
## scene inherited from `base`: the root becomes the base's root with
## `props` set, the group nodes become paths into the base, the new nodes
## keep their data. The same layout Godot gives an inherited .tscn
## ([node name=... instance=ExtResource(base)], parent="Markers"...).
## This writes PackedScene's internal data (_bundled, version 3, Godot 4.7):
## anything unexpected in it returns null, and the build saves nothing.
func _inherited(base: PackedScene, diff: PackedScene, props: Dictionary, n_markers: int) -> PackedScene:
	var b: Dictionary = diff.get("_bundled")
	var keys: Array = b.keys()
	keys.sort()
	var expected: Array = ["conn_count", "conns", "editable_instances", "id_paths", "names", "node_count", "node_ids", "node_paths", "nodes", "variants", "version"]
	if keys != expected or int(b["version"]) != 3 or int(b["conn_count"]) != 0 or not (b["node_paths"] as Array).is_empty():
		print("  PROBLEM: PackedScene data not as expected (version %s, keys %s): update _inherited for this Godot" % [b.get("version"), keys])
		return null
	var names: PackedStringArray = b["names"]
	var variants: Array = b["variants"]
	var nodes: PackedInt32Array = b["nodes"]
	# Per node: parent, owner, type, name, instance, then property count,
	# (name, value) pairs, group count, groups.
	var list: Array = []
	var i: int = 0
	while i + 6 < nodes.size():
		var pc: int = nodes[i + 5]
		if i + 6 + pc * 2 >= nodes.size():
			break
		var end: int = i + 7 + pc * 2 + nodes[i + 6 + pc * 2]
		var parent: int = nodes[i]
		# Plain nodes only: the root has no parent, the others a parent read
		# before them; no instanced scenes.
		var plain: bool = (parent == -1) == list.is_empty() and parent < list.size() and nodes[i + 4] == -1
		if not plain or end > nodes.size():
			break
		list.append([parent, nodes[i + 1], nodes[i + 2], nodes[i + 3], nodes[i + 4], nodes.slice(i + 5, end)])
		i = end
	if i != nodes.size() or list.size() != int(b["node_count"]) or (b["node_ids"] as PackedInt32Array).size() != list.size():
		print("  PROBLEM: PackedScene node data not as expected (%d of %d nodes read): update _inherited for this Godot" % [list.size(), b["node_count"]])
		return null
	var out := PackedInt32Array([-1, -1, TYPE_INSTANTIATED, list[0][3], -1, props.size()])
	for key: String in props:
		names.append(key)
		variants.append(props[key])
		out.append_array([names.size() - 1, variants.size() - 1])
	out.append(0)  # groups
	var paths: Array[NodePath] = []
	var index: Dictionary = {0: 0}
	var count: int = 1
	for j in range(1, list.size()):
		var nd: Array = list[j]
		if nd[0] == 0:  # Markers/Decor: the base's own node
			paths.append(NodePath("./" + names[nd[3] & NAME_MASK]))
			index[j] = FLAG_ID_IS_PATH | (paths.size() - 1)
			continue
		index[j] = count
		count += 1
		out.append_array([index[nd[0]], 0, nd[2], nd[3], nd[4]])
		out.append_array(nd[5])
	variants.append(base)
	var ids := PackedInt32Array()
	ids.resize(count)
	ids.fill(0)
	var id_paths: Array = []
	for p in paths:
		id_paths.append(PackedInt32Array())
	b["names"] = names
	b["variants"] = variants
	b["node_count"] = count
	b["nodes"] = out
	b["node_ids"] = ids
	b["node_paths"] = paths
	b["id_paths"] = id_paths
	b["editable_instances"] = []
	b["base_scene"] = variants.size() - 1
	var packed := PackedScene.new()
	packed.set("_bundled", b)
	# In memory first: the base's nodes plus exactly the new markers.
	var probe: Node = packed.instantiate()
	var ok: bool = probe != null and probe.get_node_or_null("Terrain3D") != null and probe.get_node_or_null("Markers") != null
	ok = ok and probe.get_node("Markers").get_child_count() == n_markers
	if probe != null:
		probe.free()
	if not ok:
		print("  PROBLEM: the inherited scene does not instantiate as expected: update _inherited for this Godot")
		return null
	return packed


func _size(path: String) -> String:
	var bytes: int = FileAccess.get_file_as_bytes(path).size()
	return "%.2f MB" % (bytes / 1048576.0) if bytes > 1048576 else "%d KB" % (bytes / 1024)
