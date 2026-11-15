class_name SideTask
extends RefCounted
## One optional task of an open island (docs/design/OPEN_ISLAND_PILOT.md, stage 1): it sits at a
## point of the map, the player stands in its circle for its seconds, and it pays its reward once.
## It never opens or closes the extraction: that is the main mission's alone.

var kind: StringName  ## &"cache" (Intel stash), &"survivor" (a free card), &"nest" (health and ammo)
var position: Vector3
var progress: float = 0.0  ## seconds the player has stood in the circle
var done: bool = false
var alarmed: bool = false  ## a nest: the horde has been called (IslandRun sets it)


func _init(task_kind: StringName, at: Vector3) -> void:
	kind = task_kind
	position = at


## The task's name, as the HUD and the end screens show it.
func title() -> String:
	match kind:
		&"survivor":
			return "LOST SURVIVOR"
		&"nest":
			return "NEST"
	return "INTEL STASH"


## What it pays, in words ("+25 INTEL").
func reward_text() -> String:
	match kind:
		&"survivor":
			return "FREE CARD"
		&"nest":
			return "HEALTH + AMMO"
	return "+%d INTEL" % GameData.SIDE_CACHE_INTEL


## Seconds of standing in the circle the task needs.
func seconds() -> float:
	match kind:
		&"survivor":
			return GameData.SIDE_SURVIVOR_SECONDS
		&"nest":
			return GameData.SIDE_NEST_SECONDS
	return GameData.SIDE_CACHE_SECONDS


## Intel the task pays once done.
func intel() -> int:
	return GameData.SIDE_CACHE_INTEL if done and kind == &"cache" else 0


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
