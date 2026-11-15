class_name SideTask
extends RefCounted
## One optional task of an open island (docs/design/OPEN_ISLAND_PILOT.md, stage 1): it sits at a
## point of the map, the player stands in its circle for its seconds, and it pays its reward once.
## It never opens or closes the extraction: that is the main mission's alone.

var kind: StringName  ## &"cache" so far (the Intel stash)
var position: Vector3
var progress: float = 0.0  ## seconds the player has stood in the circle
var done: bool = false


func _init(task_kind: StringName, at: Vector3) -> void:
	kind = task_kind
	position = at


## Seconds of standing in the circle the task needs.
func seconds() -> float:
	return GameData.SIDE_CACHE_SECONDS


## Intel the task pays once done.
func intel() -> int:
	return GameData.SIDE_CACHE_INTEL if done else 0


## Advances the task with the player at `player`; true on the step it gets done.
func update(dt: float, player: Vector3) -> bool:
	if done:
		return false
	if Vector2(player.x - position.x, player.z - position.z).length() <= GameData.SIDE_TASK_RADIUS:
		progress += dt
		if progress >= seconds():
			done = true
			return true
	return false
