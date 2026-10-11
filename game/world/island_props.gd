class_name IslandProps
extends RefCounted
## Small CC0 prop set. Missing assets leave the original primitives intact.

const DIR: String = "res://assets/models/polyhaven/"
const MODELS: Dictionary = {
	&"generator": "portable_generator",
	&"jerrycan": "metal_jerrycan_green",
	&"crate": "wooden_crate_02",
	&"barrier": "concrete_road_barrier_02",
}


static func create(id: StringName, height: float = 0.0) -> Node3D:
	if not MODELS.has(id):
		return null
	var asset: String = MODELS[id]
	var path: String = DIR + asset + "/" + asset + "_1k.gltf"
	if not ResourceLoader.exists(path):
		return null
	var model := Node3D.new()
	model.name = "PolyHaven_" + String(id)
	model.add_child((load(path) as PackedScene).instantiate())
	var box: AABB = bounds(model)
	var scale: float = height / box.size.y if height > 0.0 and box.size.y > 0.001 else 1.0
	model.scale = Vector3.ONE * scale
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * scale
	return model


## Bounds in the parent's space, including all source-node transforms.
static func bounds(model: Node3D) -> AABB:
	var result := AABB()
	var first: bool = true
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var transform := Transform3D.IDENTITY
		var node: Node3D = mesh
		while node != model:
			transform = node.transform * transform
			node = node.get_parent() as Node3D
		var box: AABB = model.transform * transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## Replaces an already-blocked thin wall; never creates new obstacles.
static func barrier_wall(size: Vector3) -> MultiMeshInstance3D:
	var model: Node3D = create(&"barrier")
	if model == null:
		return null
	var mesh: Mesh = (model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	model.free()
	var transforms: Array[Transform3D] = barrier_transforms(mesh.get_aabb(), size)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
	var wall := MultiMeshInstance3D.new()
	wall.name = "PolyHaven_barrier_wall"
	wall.multimesh = multimesh
	# Per-wall alpha supports camera fading without changing shared materials.
	wall.material_override = mesh.surface_get_material(0).duplicate()
	return wall


## CPU layout is also verifiable with RenderingServer's headless dummy.
static func barrier_transforms(box: AABB, size: Vector3) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	var horizontal: bool = size.x > size.z
	var length: float = size.x if horizontal else size.z
	var scale: float = size.y / box.size.y
	var count: int = maxi(1, ceili(length / (box.size.x * scale)))
	var segment: float = length / count
	var basis: Basis = Basis(Vector3.UP, 0.0 if horizontal else PI * 0.5) * Basis.from_scale(Vector3(segment / box.size.x, scale, scale))
	for i in count:
		var offset: float = -length * 0.5 + segment * (i + 0.5)
		var centre := Vector3(offset, 0, 0) if horizontal else Vector3(0, 0, offset)
		transforms.append(Transform3D(basis, centre - basis * box.get_center()))
	return transforms
