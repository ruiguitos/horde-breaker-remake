class_name NatureKit
extends RefCounted
## Meshes from Quaternius' Stylized Nature MegaKit (CC0, free version) in
## assets/models/nature_megakit/. Each glTF scene holds one mesh; we take the
## Mesh (with its materials) so it can be drawn many times in a MultiMesh.
##
## Missing files return null, so the island falls back to primitive props.

const DIR: String = "res://assets/models/nature_megakit/"

## Which models each biome uses for trees (blocking props on the grid).
## Beach and port keep the procedural palms: the free kit has no palms.
const TREES: Dictionary = {
	&"town": ["CommonTree_1", "CommonTree_2", "CommonTree_3", "CommonTree_4", "CommonTree_5"],
	&"jungle": ["CommonTree_1", "CommonTree_2", "CommonTree_4", "CommonTree_5", "Pine_1"],
	&"volcano": ["DeadTree_1", "DeadTree_2", "DeadTree_3", "DeadTree_4", "DeadTree_5"],
}
const ROCKS: Array[String] = ["Rock_Medium_1", "Rock_Medium_2", "Rock_Medium_3"]
## Ground cover (decoration only, walkable): grass, bushes, flowers, ferns.
const COVER: Dictionary = {
	&"beach": ["Grass_Wispy_Short", "Grass_Wispy_Tall", "Pebble_Round_2"],
	&"town": ["Grass_Common_Short", "Clover_1", "Flower_3_Group"],
	&"jungle": ["Fern_1", "Plant_1", "Plant_7", "Bush_Common", "Grass_Common_Tall"],
	&"port": ["Grass_Common_Short", "Pebble_Square_2"],
	&"volcano": ["Pebble_Round_1", "Pebble_Square_3", "Mushroom_Laetiporus"],
}

static var _cache: Dictionary = {}


static func available() -> bool:
	return ResourceLoader.exists(DIR + "CommonTree_1.gltf")


## The model's mesh, or null when the file is missing.
static func mesh(model: String) -> Mesh:
	if _cache.has(model):
		return _cache[model]
	var m: Mesh = null
	var path: String = DIR + model + ".gltf"
	if ResourceLoader.exists(path):
		var scene: Node = (load(path) as PackedScene).instantiate()
		var found: Array[Node] = scene.find_children("*", "MeshInstance3D", true, false)
		if not found.is_empty():
			m = (found[0] as MeshInstance3D).mesh
		scene.free()
	_cache[model] = m
	return m


## Scale that makes the model `target_height` metres tall.
static func scale_for(m: Mesh, target_height: float) -> float:
	var h: float = m.get_aabb().size.y
	return target_height / h if h > 0.001 else 1.0
