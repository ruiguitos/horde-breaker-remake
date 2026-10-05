extends Node
## Root of the game: a small run state machine.
##   TITLE -> ARMORY -> BOAT -> ISLAND -> (cleared and more islands) BOAT
##                  -> (last island cleared, or death) DEBRIEF -> ARMORY
## Each state is a scene that is freed when the state changes; RunContext is
## the only thing that crosses states.

enum GameFlow { BOAT, ISLAND, DEBRIEF, ARMORY, TITLE, SANDBOX }

const ISLAND_SCENE: String = "res://game/world/island.tscn"

var state: GameFlow = GameFlow.BOAT
var context: RunContext
var profile: Profile
var _current: Node


func _ready() -> void:
	GameInput.setup()
	profile = Profile.load_profile()
	Profile.current = profile
	GameInput.apply_overrides(profile.key_bindings)
	profile.apply_volume()
	GraphicsSettings.apply_all(profile, get_tree())
	_go(GameFlow.TITLE)


## F11 toggles fullscreen anywhere in the game.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		profile.window_mode = GraphicsSettings.WINDOWED if profile.window_mode != GraphicsSettings.WINDOWED else GraphicsSettings.BORDERLESS
		GraphicsSettings.apply_display(profile)
		profile.save()


func _new_run() -> void:
	context = RunContext.new()
	context.threat = profile.threat
	context.apply_class(profile.selected_class)
	context.apply_perks(profile.equipped_perks)
	context.weapons.append_array(profile.unlocked_weapons)
	_go(GameFlow.BOAT)


func _go(next: GameFlow) -> void:
	if _current != null:
		_current.queue_free()
	state = next
	match next:
		GameFlow.BOAT:
			var boat := Control.new()
			boat.set_script(load("res://game/states/boat.gd"))
			boat.set("context", context)
			boat.connect("land_requested", _go.bind(GameFlow.ISLAND), CONNECT_DEFERRED)
			_current = boat
		GameFlow.ISLAND:
			var island: Node = (load(ISLAND_SCENE) as PackedScene).instantiate()
			island.set("context", context)
			island.set("profile", profile)
			island.connect("finished", _on_island_finished, CONNECT_DEFERRED)
			_current = island
		GameFlow.SANDBOX:
			# Test map: no run context, nothing is saved; leaving returns to the title.
			var sandbox: Node = (load(ISLAND_SCENE) as PackedScene).instantiate()
			sandbox.set("sandbox", true)
			sandbox.set("profile", profile)
			sandbox.connect("finished", func(_won: bool) -> void: _go(GameFlow.TITLE), CONNECT_DEFERRED)
			_current = sandbox
		GameFlow.DEBRIEF:
			profile.record_run(context)
			_write_telemetry()
			profile.save()
			var debrief := Control.new()
			debrief.set_script(load("res://game/states/debrief.gd"))
			debrief.set("context", context)
			debrief.set("profile", profile)
			debrief.connect("new_run_requested", _go.bind(GameFlow.ARMORY), CONNECT_DEFERRED)
			_current = debrief
		GameFlow.TITLE:
			var title := Node.new()
			title.set_script(load("res://game/states/title.gd"))
			title.set("profile", profile)
			title.connect("play_requested", _go.bind(GameFlow.ARMORY), CONNECT_DEFERRED)
			title.connect("sandbox_requested", _go.bind(GameFlow.SANDBOX), CONNECT_DEFERRED)
			_current = title
		GameFlow.ARMORY:
			var armory := Control.new()
			armory.set_script(load("res://game/states/armory.gd"))
			armory.set("profile", profile)
			armory.connect("start_requested", _new_run, CONNECT_DEFERRED)
			armory.connect("back_requested", _go.bind(GameFlow.TITLE), CONNECT_DEFERRED)
			_current = armory
	add_child(_current)
	# Scenes build their sun/sky in _ready (Sky3D a frame later): re-apply
	# the graphics preset to whatever lights they created.
	get_tree().process_frame.connect(func() -> void: GraphicsSettings.apply_graphics(profile, get_tree()), CONNECT_ONE_SHOT)


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
		_go(GameFlow.BOAT)
	else:
		context.won = won
		if won:
			# Extracting multiplies everything earned in the run.
			context.intel = int(context.intel * GameData.EXTRACTION_INTEL_MULTIPLIER)
		_go(GameFlow.DEBRIEF)
