extends RefCounted
## Landmarks for the real-island builder (build.gd) inside the place's
## detail_area: the lighthouse and the fort. Stub: the builder's own
## lighthouse and no fort until filled in.

var b: SceneTree  ## the builder (build.gd): height_at, _add, _tri, _role_material...


func _init(builder: SceneTree) -> void:
	b = builder


## Builds lighthouse k at `p` (island metres), `height` metres tall, and
## returns true, or false to leave it to the builder.
func lighthouse(_p: Vector2, _k: int, _height: float) -> bool:
	return false


## Builds the fort on the islet centred near `islet` (island metres).
func fort(_islet: Vector2) -> void:
	pass
