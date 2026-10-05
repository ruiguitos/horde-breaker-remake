extends Node
## Root of the game: a small run state machine.
##   ARMORY -> BOAT -> ISLAND -> (cleared and more islands) BOAT
##                  -> (last island cleared, or death) DEBRIEF -> ARMORY
## Each state is a scene that is freed when the state changes; RunContext is
## the only thing that crosses states.

enum State { BOAT, ISLAND, DEBRIEF, ARMORY }

const ISLAND_SCENE: String = "res://game/world/island.tscn"

var state: State = State.BOAT
var context: RunContext
var profile: Profile
var _current: Node


func _ready() -> void:
	GameInput.setup()
	profile = Profile.load_profile()
	profile.apply_volume()
	_go(State.ARMORY)


## F11 toggles fullscreen anywhere in the game.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var full: bool = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)


func _new_run() -> void:
	context = RunContext.new()
	context.threat = profile.threat
	context.apply_class(profile.selected_class)
	context.apply_perks(profile.equipped_perks)
	context.weapons.append_array(profile.unlocked_weapons)
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
			_write_telemetry()
			profile.save()
			var debrief := Control.new()
			debrief.set_script(load("res://game/states/debrief.gd"))
			debrief.set("context", context)
			debrief.set("profile", profile)
			debrief.connect("new_run_requested", _go.bind(State.ARMORY), CONNECT_DEFERRED)
			_current = debrief
		State.ARMORY:
			var armory := Control.new()
			armory.set_script(load("res://game/states/armory.gd"))
			armory.set("profile", profile)
			armory.connect("start_requested", _new_run, CONNECT_DEFERRED)
			_current = armory
	add_child(_current)


## Writes a JSON summary of the run to user://runs/ for balancing.
func _write_telemetry() -> void:
	DirAccess.make_dir_recursive_absolute("user://runs")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open("user://runs/run_%s.json" % stamp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": 1, "won": context.won, "threat": context.threat,
		"class": String(context.player_class),
		"perks": context.perks.map(func(x: StringName) -> String: return String(x)),
		"intel": context.intel, "total_seconds": snappedf(context.time_alive, 0.1),
		"islands": context.island_log}, "  "))


func _on_island_finished(won: bool) -> void:
	if won and not context.is_last_island():
		context.island_index += 1
		_go(State.BOAT)
	else:
		context.won = won
		if won:
			# Extracting multiplies everything earned in the run.
			context.intel = int(context.intel * GameData.EXTRACTION_INTEL_MULTIPLIER)
		_go(State.DEBRIEF)
