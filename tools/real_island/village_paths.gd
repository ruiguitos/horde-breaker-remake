extends RefCounted
## Paths, steps and the road for the real-island builder (build.gd) inside
## the place's detail_area. Stub: the builder's own ribbons until filled in.

var b: SceneTree  ## the builder (build.gd): height_at, _add, _tri, _role_material...


func _init(builder: SceneTree) -> void:
	b = builder


## Builds `path` ([points, width, kind, bridge, tags]) and returns true, or
## false to leave it to the builder.
func place(_path: Array) -> bool:
	return false


## Called once after every path: commit shared meshes here.
func finish() -> void:
	pass
