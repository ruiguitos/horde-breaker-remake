extends Node
## Root of the game: owns the current island and restarts it on request.
## (The run state machine of docs/tech/ARCHITECTURE.md comes later; the slice
## only has one island.)

const ISLAND_SCENE: String = "res://game/world/island.tscn"

var _island: Node


func _ready() -> void:
	_start()


func _start() -> void:
	if _island != null:
		_island.queue_free()
	_island = (load(ISLAND_SCENE) as PackedScene).instantiate()
	_island.restart_requested.connect(_start, CONNECT_DEFERRED)
	add_child(_island)
