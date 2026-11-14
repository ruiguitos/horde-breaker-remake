class_name BeachVegetation
extends Node3D
## Low cover on the beach: grass tufts and pebbles, drawn with two MultiMeshes. At most MAX_INSTANCES of
## them stand within RADIUS metres of the player. The places are drawn once per island from a fixed seed,
## so the cover does not shift as the player walks. Off on the Low preset.

const MAX_INSTANCES: int = 400
const RADIUS: float = 60.0
## Places drawn per island; the nearest ones within RADIUS (up to MAX_INSTANCES) are shown.
const CANDIDATES: int = 2400
const GRASS_SHARE: float = 0.75  ## of the places, the rest are pebbles
const MOVE_REFRESH: float = 6.0  ## metres walked before the cover is placed again
## Places are chosen within this distance, so that after walking up to MOVE_REFRESH with no new placement
## every shown instance is still within RADIUS.
const SHOWN_RADIUS: float = RADIUS - MOVE_REFRESH
const SEA_LEVEL: float = 0.0  ## ground under this is the sea: no cover in the water

var _grass: MultiMeshInstance3D
var _pebbles: MultiMeshInstance3D
var _places: PackedVector3Array = PackedVector3Array()  ## ground points, on open sand
var _is_grass: PackedByteArray = PackedByteArray()  ## 1: a grass tuft, 0: a pebble
var _turn: PackedFloat32Array = PackedFloat32Array()  ## yaw of each place
var _scale: PackedFloat32Array = PackedFloat32Array()  ## size of each place
var _centre: Vector3 = Vector3(INF, 0.0, INF)  ## where the cover was last placed
var _shown_origins: PackedVector3Array = PackedVector3Array()  ## origins of the instances placed by the last follow()


## The cover of `map` (a beach island). Places are on open sand only: not on a road, a deck, a building
## or in the water.
static func for_map(map: IslandMap, rng_seed: int, natural_grass: bool = false) -> BeachVegetation:
	var out := BeachVegetation.new()
	out.name = "BeachCover"
	out._draw_places(map, rng_seed)
	out._grass = MultiMeshInstance3D.new()
	out._grass.name = "Grass"
	out._grass.multimesh = _multimesh(_natural_grass_mesh() if natural_grass else _grass_mesh())
	out.add_child(out._grass)
	out._pebbles = MultiMeshInstance3D.new()
	out._pebbles.name = "Pebbles"
	out._pebbles.multimesh = _multimesh(_pebble_mesh())
	out.add_child(out._pebbles)
	return out


## Keeps the cover around `player`: nothing on the Low preset, else the nearest places within RADIUS.
func follow(player: Vector3) -> void:
	if GraphicsSettings.quality == GraphicsSettings.LOW:
		_show(0, 0)
		_shown_origins.clear()
		_centre = Vector3(INF, 0.0, INF)  # placed again as soon as the preset changes back
		return
	var here := Vector3(player.x, 0.0, player.z)
	if here.distance_to(_centre) < MOVE_REFRESH:
		return
	_centre = here
	_shown_origins.clear()
	var grass: int = 0
	var pebbles: int = 0
	for i in _places.size():
		if grass + pebbles >= MAX_INSTANCES:
			break
		var p: Vector3 = _places[i]
		if Vector2(p.x - here.x, p.z - here.z).length() > SHOWN_RADIUS:
			continue
		var s: float = _scale[i]
		var basis := Basis(Vector3.UP, _turn[i]).scaled(Vector3(s, s, s))
		if _is_grass[i] == 1:
			# The tuft stands on its place: its origin is lifted by half its height.
			var lifted: Vector3 = p + Vector3(0.0, 0.22 * s, 0.0)
			_grass.multimesh.set_instance_transform(grass, Transform3D(basis, lifted))
			_shown_origins.append(lifted)
			grass += 1
		else:
			var lifted: Vector3 = p + Vector3(0.0, 0.05 * s, 0.0)
			_pebbles.multimesh.set_instance_transform(pebbles, Transform3D(basis, lifted))
			_shown_origins.append(lifted)
			pebbles += 1
	_show(grass, pebbles)


## Origins of the instances placed by the last follow(), in placement order (grass and pebbles mixed). The
## test reads these: the headless renderer does not keep MultiMesh transforms.
func shown_origins() -> PackedVector3Array:
	return _shown_origins


## How many grass tufts and pebbles are shown now.
func shown() -> Vector2i:
	return Vector2i(_grass.multimesh.visible_instance_count, _pebbles.multimesh.visible_instance_count)


## The places: candidate cells of the map, kept when they are open sand above the sea. Drawn with one
## seed, so the same island always gets the same cover.
func _draw_places(map: IslandMap, rng_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var f: FlowField = map.field
	var tries: int = 0
	while _places.size() < CANDIDATES and tries < CANDIDATES * 20:
		tries += 1
		var cell := Vector2i(rng.randi_range(0, f.width - 1), rng.randi_range(0, f.height - 1))
		if f.is_blocked(cell.x, cell.y):
			continue
		if not map.cover.is_empty() and map.cover[cell.y * f.width + cell.x] != 0:
			continue
		var p: Vector3 = f.cell_center(cell)
		p.y = map.ground_y(p)
		if p.y < SEA_LEVEL or map.surface_at(p) != &"sand":
			continue
		_places.append(p)
		_is_grass.append(1 if rng.randf() < GRASS_SHARE else 0)
		_turn.append(rng.randf() * TAU)
		_scale.append(rng.randf_range(0.8, 1.25))


func _show(grass: int, pebbles: int) -> void:
	_grass.multimesh.visible_instance_count = grass
	_pebbles.multimesh.visible_instance_count = pebbles
	_grass.visible = grass > 0
	_pebbles.visible = pebbles > 0


static func _multimesh(mesh: Mesh) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	return mm


## A grass tuft: a double-sided card, about 0.45 m tall.
## Kept for maps outside the authored beach pilot.
static func _grass_mesh() -> QuadMesh:
	var card := QuadMesh.new()
	card.size = Vector2(0.4, 0.45)
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.28, 0.45, 0.2)
	green.cull_mode = BaseMaterial3D.CULL_DISABLED
	card.material = green
	return card


## Small tapered blades instead of an opaque rectangular card. Same origin,
## height, instance budget and placement rules as the original cover.
static func _natural_grass_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 9:
		var angle: float = i * 2.39996
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.022
		var base := Vector3(sin(i * 1.7) * 0.09, -0.225, cos(i * 2.3) * 0.09)
		var bend: Vector3 = base + Vector3(cos(angle) * 0.035, 0.24 + (i % 3) * 0.025, sin(angle) * 0.035)
		var tip: Vector3 = base + Vector3(cos(angle) * 0.08, 0.36 + (i % 4) * 0.027, sin(angle) * 0.08)
		var vertices: Array[Vector3] = [base - side, bend - side * 0.55, base + side,
			base + side, bend - side * 0.55, bend + side * 0.55,
			bend - side * 0.55, tip, bend + side * 0.55]
		for vertex: Vector3 in vertices:
			surface.set_color(Color(0.34, 0.4, 0.18).lerp(Color(0.55, 0.48, 0.25), float(i % 4) / 5.0))
			surface.add_vertex(vertex)
	surface.generate_normals()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.albedo_color = Color(0.5, 0.55, 0.28)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	surface.set_material(material)
	return surface.commit()


## A pebble: a small flattened sphere.
static func _pebble_mesh() -> SphereMesh:
	var stone := SphereMesh.new()
	stone.radius = 0.1
	stone.height = 0.1
	stone.radial_segments = 6
	stone.rings = 3
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.5, 0.47, 0.42)
	stone.material = grey
	return stone
