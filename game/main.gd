extends Node
## Root of the game: a small run state machine.
##   BOAT -> ISLAND -> (cleared and more islands) BOAT
##                  -> (last island cleared, or death) DEBRIEF -> BOAT (new run)
## Each state is a scene that is freed when the state changes; RunContext is
## the only thing that crosses states.

enum State { BOAT, ISLAND, DEBRIEF }

const ISLAND_SCENE: String = "res://game/world/island.tscn"

var state: State = State.BOAT
var context: RunContext
var profile: Profile
var _current: Node


func _ready() -> void:
	profile = Profile.load_profile()
	_new_run()


func _new_run() -> void:
	context = RunContext.new()
	_go(State.BOAT)


func _go(next: State) -> void:
	if _current != null:
		_current.queue_free()
	state = next
	match next:
		State.BOAT:
			var boat := Control.new()
			boat.set_script(load("res://game/states/boat.gd"))
			boat.set("context", context)
			boat.connect("land_requested", _go.bind(State.ISLAND), CONNECT_DEFERRED)
			_current = boat
		State.ISLAND:
			var island: Node = (load(ISLAND_SCENE) as PackedScene).instantiate()
			island.set("context", context)
			island.connect("finished", _on_island_finished, CONNECT_DEFERRED)
			_current = island
		State.DEBRIEF:
			profile.record_run(context)
			profile.save()
			var debrief := Control.new()
			debrief.set_script(load("res://game/states/debrief.gd"))
			debrief.set("context", context)
			debrief.set("profile", profile)
			debrief.connect("new_run_requested", _new_run, CONNECT_DEFERRED)
			_current = debrief
	add_child(_current)


func _on_island_finished(won: bool) -> void:
	if won and not context.is_last_island():
		context.island_index += 1
		_go(State.BOAT)
	else:
		context.won = won
		_go(State.DEBRIEF)
