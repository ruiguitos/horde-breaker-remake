@tool
class_name Scatter
extends MultiMeshInstance3D
## Many copies of one mesh (grass, rocks), drawn as one MultiMesh. The copies
## are saved as plain numbers and the MultiMesh is rebuilt when the node
## loads: a MultiMesh made by a headless script (tools/real_island/build.gd)
## is saved without its copies. Inside Rocks/ of a HandmadeIsland every copy
## blocks the cells under it; anywhere else it is decoration.

## The mesh every copy shows.
@export var mesh: Mesh:
	set(value):
		mesh = value
		if is_node_ready():
			rebuild()
## 5 numbers per copy: x, y, z (relative to this node), turn around Y
## (radians) and size.
@export var data: PackedFloat32Array:
	set(value):
		data = value
		if is_node_ready():
			rebuild()

const STRIDE: int = 5


func _ready() -> void:
	rebuild()


## The MultiMesh is rebuilt on load, so it is not saved in the scene (it
## would store every copy a second time).
func _validate_property(property: Dictionary) -> void:
	if property.name == "multimesh":
		property.usage &= ~PROPERTY_USAGE_STORAGE


func count() -> int:
	return data.size() / STRIDE


## Transform of copy `i`, relative to this node.
func instance_transform(i: int) -> Transform3D:
	var k: int = i * STRIDE
	var b := Basis(Vector3.UP, data[k + 3]).scaled(Vector3.ONE * data[k + 4])
	return Transform3D(b, Vector3(data[k], data[k + 1], data[k + 2]))


func rebuild() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count()
	for i in mm.instance_count:
		mm.set_instance_transform(i, instance_transform(i))
	multimesh = mm
