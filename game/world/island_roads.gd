class_name IslandRoads
extends RefCounted
## Roads with the Road Generator addon (addons/road-generator): a road from
## the boat landing to each objective (generators, or caches when the mission
## has none). Roads are decoration: gameplay stays on the grid.
##
## plan() is pure data (testable headless): a breadth-first search over the
## walkable cells that prefers cells with room around them (so the road does
## not cut through buildings), simplified into a few control points.
## build() turns each path into RoadPoints inside a RoadContainer; the addon
## generates the curved road mesh with lane markings between them.

const SCRIPT_MANAGER: String = "res://addons/road-generator/nodes/road_manager.gd"
const SCRIPT_CONTAINER: String = "res://addons/road-generator/nodes/road_container.gd"
const SCRIPT_POINT: String = "res://addons/road-generator/nodes/road_point.gd"
const LANE_WIDTH: float = 2.4
const CLEARANCE: int = 3  ## preferred free cells on each side of the road centre
const POINT_SPACING: int = 9  ## cells between RoadPoints
const ROAD_Y: float = 0.03  ## just above the flat ground


static func available() -> bool:
	return ResourceLoader.exists(SCRIPT_POINT) and ResourceLoader.exists(SCRIPT_CONTAINER)


## Paths (world positions, y = 0) from the boat to each objective.
static func plan(map: IslandMap) -> Array[PackedVector3Array]:
	var f: FlowField = map.field
	var clearance: PackedInt32Array = _clearance(f)
	var targets: Array[Vector3] = map.generators.duplicate()
	if targets.is_empty():
		targets = map.caches.duplicate()
	var start: Vector2i = f.world_to_cell(map.boat)
	var parents: PackedInt32Array = _search(f, clearance, start)
	var used := {}  # cells already covered by a road (to join, not overlap)
	var paths: Array[PackedVector3Array] = []
	for t in targets:
		var cells: Array[Vector2i] = _trace(f, parents, start, f.world_to_cell(t))
		if cells.size() < 6:
			continue
		# Later roads branch off the existing one: start at the last cell that
		# still touches it (they share the way out of the landing).
		if not used.is_empty():
			for i in range(cells.size() - 1, -1, -1):
				if _near(used, cells[i], 3):
					cells = cells.slice(i)
					break
		for c in cells:
			used[c] = true
		var pts := PackedVector3Array()
		for i in range(0, cells.size(), POINT_SPACING):
			pts.append(f.cell_center(cells[i]))
		if (cells.size() - 1) % POINT_SPACING != 0:
			pts.append(f.cell_center(cells[cells.size() - 1]))
		if pts.size() >= 2:
			paths.append(pts)
	return paths


## Builds the roads under `parent`. Returns the RoadManager, or null when the
## addon is missing.
static func build(parent: Node3D, paths: Array[PackedVector3Array]) -> Node3D:
	if not available() or paths.is_empty():
		return null
	var manager := Node3D.new()
	manager.set_script(load(SCRIPT_MANAGER))
	manager.name = "Roads"
	parent.add_child(manager)
	for path in paths:
		var container := Node3D.new()
		container.set_script(load(SCRIPT_CONTAINER))
		container.set("flatten_terrain", false)  # the island is already flat
		container.set("create_edge_curves", false)
		manager.add_child(container)
		var points: Array[Node3D] = []
		for i in path.size():
			var rp := Node3D.new()
			rp.set_script(load(SCRIPT_POINT))
			rp.set("auto_lanes", false)
			# One lane each way (LaneDir REVERSE=2, FORWARD=1; LaneType SLOW=2).
			var dirs: Array[int] = [2, 1]
			var types: Array[int] = [2, 2]
			rp.set("traffic_dir", dirs)
			rp.set("lanes", types)
			rp.set("lane_width", LANE_WIDTH)
			rp.set("shoulder_width_l", 0.4)
			rp.set("shoulder_width_r", 0.4)
			rp.set("gutter_profile", Vector2(0.6, -0.15))
			container.add_child(rp)
			var prev: Vector3 = path[maxi(i - 1, 0)]
			var next: Vector3 = path[mini(i + 1, path.size() - 1)]
			var dir: Vector3 = (next - prev).normalized()
			# RoadPoints point their "next" handle along +Z.
			rp.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), path[i] + Vector3(0, ROAD_Y, 0))
			var span: float = POINT_SPACING * 0.4
			rp.set("prior_mag", span)
			rp.set("next_mag", span)
			points.append(rp)
		for i in points.size() - 1:
			points[i].call("connect_roadpoint", 0, points[i + 1], 1)  # NEXT -> PRIOR
		_add_lamps(manager, path)
	return manager


## Street lamps on alternate sides of the road: a pole, an emissive bulb and
## a warm OmniLight (3D light; the Lit addon only lights 2D scenes).
static func _add_lamps(parent: Node3D, path: PackedVector3Array) -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color(0.18, 0.18, 0.2)
	var bulb_mat := StandardMaterial3D.new()
	bulb_mat.albedo_color = Color(1.0, 0.85, 0.55)
	bulb_mat.emission_enabled = true
	bulb_mat.emission = Color(1.0, 0.8, 0.5)
	bulb_mat.emission_energy_multiplier = 4.0
	for i in range(1, path.size() - 1, 2):
		var dir: Vector3 = (path[i + 1] - path[i - 1]).normalized()
		var side: Vector3 = dir.cross(Vector3.UP).normalized() * (1.0 if i % 4 == 1 else -1.0)
		var base: Vector3 = path[i] + side * (LANE_WIDTH + 1.0)
		var lamp := Node3D.new()
		lamp.name = "StreetLamp"
		lamp.position = base
		parent.add_child(lamp)
		var pole := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.06
		cyl.bottom_radius = 0.09
		cyl.height = 4.2
		pole.mesh = cyl
		pole.position.y = 2.1
		pole.material_override = pole_mat
		lamp.add_child(pole)
		var arm := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 1.0)
		arm.mesh = box
		arm.material_override = pole_mat
		arm.transform = Transform3D(Basis.looking_at(-side, Vector3.UP), Vector3(0, 4.15, 0) - side * 0.5)
		lamp.add_child(arm)
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.16
		sphere.height = 0.24
		bulb.mesh = sphere
		bulb.position = Vector3(0, 4.05, 0) - side * 1.0
		bulb.material_override = bulb_mat
		lamp.add_child(bulb)
		var light := OmniLight3D.new()
		light.position = bulb.position + Vector3(0, -0.2, 0)
		light.light_color = Color(1.0, 0.82, 0.55)
		light.light_energy = 1.6
		light.omni_range = 9.0
		light.omni_attenuation = 1.2
		lamp.add_child(light)


## Free cells around each walkable cell (BFS from blocked cells), capped.
static func _clearance(f: FlowField) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(f.width * f.height)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for z in f.height:
		for x in f.width:
			if f.is_blocked(x, z):
				dist[z * f.width + x] = 0
				queue.append(z * f.width + x)
	var head: int = 0
	while head < queue.size():
		var idx: int = queue[head]
		head += 1
		var x: int = idx % f.width
		var z: int = idx / f.width
		for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + o.x
			var nz: int = z + o.y
			if nx < 0 or nz < 0 or nx >= f.width or nz >= f.height:
				continue
			var n: int = nz * f.width + nx
			if dist[n] == -1:
				dist[n] = dist[idx] + 1
				queue.append(n)
	return dist


## Shortest walkable paths from `start`, preferring roomy cells: a cell with
## less than CLEARANCE free cells around it costs extra (simple Dijkstra on a
## small integer cost, done with buckets).
static func _search(f: FlowField, clearance: PackedInt32Array, start: Vector2i) -> PackedInt32Array:
	var n: int = f.width * f.height
	var cost := PackedInt32Array()
	cost.resize(n)
	cost.fill(1 << 30)
	var parents := PackedInt32Array()
	parents.resize(n)
	parents.fill(-1)
	var s: int = start.y * f.width + start.x
	cost[s] = 0
	var buckets: Array[PackedInt32Array] = [PackedInt32Array([s])]
	var c: int = 0
	while c < buckets.size():
		var bucket: PackedInt32Array = buckets[c]
		var i: int = 0
		while i < bucket.size():
			var idx: int = bucket[i]
			i += 1
			if cost[idx] != c:
				continue
			var x: int = idx % f.width
			var z: int = idx / f.width
			for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + o.x
				var nz: int = z + o.y
				if nx < 0 or nz < 0 or nx >= f.width or nz >= f.height or f.is_blocked(nx, nz):
					continue
				var nb: int = nz * f.width + nx
				var step: int = 1 + maxi(0, CLEARANCE - clearance[nb]) * 4
				var nc: int = c + step
				if nc < cost[nb]:
					cost[nb] = nc
					parents[nb] = idx
					while buckets.size() <= nc:
						buckets.append(PackedInt32Array())
					buckets[nc].append(nb)
		buckets[c] = bucket
		c += 1
	return parents


static func _trace(f: FlowField, parents: PackedInt32Array, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var s: int = start.y * f.width + start.x
	var idx: int = goal.y * f.width + goal.x
	if idx < 0 or idx >= parents.size() or (parents[idx] == -1 and idx != s):
		return cells
	while idx != -1:
		cells.append(Vector2i(idx % f.width, idx / f.width))
		if idx == s:
			break
		idx = parents[idx]
	cells.reverse()
	return cells


static func _near(used: Dictionary, c: Vector2i, r: int) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if used.has(c + Vector2i(dx, dz)):
				return true
	return false
