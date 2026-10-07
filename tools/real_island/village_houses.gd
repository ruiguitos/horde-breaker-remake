extends RefCounted
## Village houses for the real-island builder (build.gd): the houses inside
## the place's detail_area. Stub: the builder's own houses until filled in.

var b: SceneTree  ## the builder (build.gd): height_at, _add, _tri, _role_material...


func _init(builder: SceneTree) -> void:
	b = builder


## Builds house k (footprint `pts` in island metres, ground from `lo` to
## `hi`) and returns true, or false to leave it to the builder.
func place(_k: int, _pts: PackedVector2Array, _lo: float, _hi: float) -> bool:
	return false


## Called once after every house: commit shared meshes here.
func finish() -> void:
	pass
