extends MultiMeshInstance3D
## Copies of one mesh at the stored transforms. The builder runs headless,
## where a MultiMesh keeps no instance data, so the transforms are saved here
## (12 floats each: basis columns x, y, z and origin) and loaded on _ready.

@export var mesh: Mesh
@export var transforms: PackedFloat32Array


func _ready() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size() / 12
	for k in mm.instance_count:
		var f: int = k * 12
		var b := Basis(Vector3(transforms[f], transforms[f + 1], transforms[f + 2]),
			Vector3(transforms[f + 3], transforms[f + 4], transforms[f + 5]),
			Vector3(transforms[f + 6], transforms[f + 7], transforms[f + 8]))
		mm.set_instance_transform(k, Transform3D(b, Vector3(transforms[f + 9], transforms[f + 10], transforms[f + 11])))
	multimesh = mm
