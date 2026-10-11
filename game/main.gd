extends Node
## Root of the game: a small run state machine.
##   TITLE -> ARMORY -> BOAT -> ISLAND -> (cleared and more islands) BOAT
##                  -> (last island cleared, or death) DEBRIEF -> ARMORY
## An expedition (one real island in parts, on foot) has no boat:
##   ARMORY -> ISLAND (part 1) -> (cleared and more parts) CAMP -> ISLAND
##          -> (last part cleared, or death) DEBRIEF
## QUICK REDEPLOY (title or debrief) skips the Armory and the run choice:
## it starts the last run again (BOAT, or ISLAND for an expedition).
## Each state is a scene that is freed when the state changes; RunContext is
## the only thing that crosses states.

enum GameFlow { BOAT, ISLAND, DEBRIEF, ARMORY, TITLE, CAMP }

const ISLAND_SCENE: String = "res://game/world/island.tscn"

var state: GameFlow = GameFlow.BOAT
var context: RunContext
var profile: Profile
var _current: Node
var _test_scene: PackedScene  ## TEST ISLAND: the island being tested, no run around it
var _landing: Dictionary = {}  ## RunContext.island_info() of the island being played


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


## Starts a run from the Armory: the archipelago (`expedition` = &"") goes
## to the boat; an expedition lands straight on its first part.
func _new_run(expedition: StringName = &"") -> void:
	profile.remember_run(expedition)
	profile.save()
	context = _fresh_context()
	if expedition != &"" and context.start_expedition(expedition):
		_go(GameFlow.ISLAND)
	else:
		_go(GameFlow.BOAT)


## QUICK REDEPLOY (title, debrief): the last run again, with the same
## class, perks, threat and run type, skipping the Armory and the run
## choice (the boat or the expedition flow is the same). If something of it
## is no longer owned or available, the Armory opens instead (DEPLOY).
func _quick_redeploy() -> void:
	if profile.apply_last_run():
		_new_run(profile.last_expedition())
	else:
		_go(GameFlow.ARMORY)


## A run context with the profile's threat, class, perks and weapons.
func _fresh_context() -> RunContext:
	var ctx := RunContext.new()
	ctx.threat = profile.threat
	ctx.apply_class(profile.selected_class)
	ctx.apply_perks(profile.equipped_perks)
	ctx.weapons.append_array(profile.unlocked_weapons)
	return ctx


## TEST ISLAND (development builds): one hand-made island with the chosen
## mission, straight from the title, with the profile's class, perks and
## weapons. Its biome comes from the file name (beach_berlenga -> beach).
## An expedition part plays as that part (its biome, mission and place in
## the expedition); the whole expedition island takes the expedition biome.
func _test_island(path: String, mission: StringName) -> void:
	context = _fresh_context()
	var where: Dictionary = Expeditions.locate(path)
	if where.is_empty():
		context.biome = StringName(path.get_file().get_slice("_", 0))
	elif int(where["index"]) >= 0:
		context.start_expedition(where["expedition"], int(where["index"]))
	else:
		context.biome = Expeditions.biome(where["expedition"])
	context.mission = mission
	_test_scene = load(path)
	_go(GameFlow.ISLAND)


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
			boat.connect("exit_requested", _leave_between_islands, CONNECT_DEFERRED)
			_current = boat
		GameFlow.ISLAND:
			var island: Node = (load(ISLAND_SCENE) as PackedScene).instantiate()
			island.set("context", context)
			island.set("profile", profile)
			if _test_scene != null:
				island.set("handmade_scene", _test_scene)
			elif context.is_expedition():
				var part_scene := load(context.part_scene()) as PackedScene
				if part_scene == null:
					push_error("Expedition part scene missing: %s" % context.part_scene())
				island.set("handmade_scene", part_scene)
			_landing = context.island_info()
			island.connect("finished", _on_island_finished, CONNECT_DEFERRED)
			_current = island
		GameFlow.DEBRIEF:
			profile.record_run(context)
			_write_telemetry()
			profile.save()
			var debrief := Control.new()
			debrief.set_script(load("res://game/states/debrief.gd"))
			debrief.set("context", context)
			debrief.set("profile", profile)
			debrief.connect("new_run_requested", _go.bind(GameFlow.ARMORY), CONNECT_DEFERRED)
			debrief.connect("quick_redeploy_requested", _quick_redeploy, CONNECT_DEFERRED)
			_current = debrief
		GameFlow.TITLE:
			var title := Node.new()
			title.set_script(load("res://game/states/title.gd"))
			title.set("profile", profile)
			title.connect("play_requested", _go.bind(GameFlow.ARMORY), CONNECT_DEFERRED)
			title.connect("test_island_requested", _test_island, CONNECT_DEFERRED)
			title.connect("quick_redeploy_requested", _quick_redeploy, CONNECT_DEFERRED)
			_current = title
		GameFlow.CAMP:
			var camp := Control.new()
			camp.set_script(load("res://game/states/camp.gd"))
			camp.set("context", context)
			camp.connect("land_requested", _go.bind(GameFlow.ISLAND), CONNECT_DEFERRED)
			camp.connect("exit_requested", _leave_between_islands, CONNECT_DEFERRED)
			_current = camp
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


## Leaving a camp/boat banks only completed islands' Intel, once, without extraction.
func _leave_between_islands(to_title: bool) -> void:
	if state not in [GameFlow.BOAT, GameFlow.CAMP] or context == null:
		return
	context.won = false
	# Before the first landing this just cancels setup, not a played run.
	if not context.island_log.is_empty():
		profile.record_run(context)
		_write_telemetry()
		profile.save()
	context = null
	_landing.clear()
	_go(GameFlow.TITLE if to_title else GameFlow.ARMORY)


## Writes a JSON summary of the run to user://runs/ for balancing.
func _write_telemetry() -> void:
	DirAccess.make_dir_recursive_absolute("user://runs")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var f := FileAccess.open("user://runs/run_%s.json" % stamp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"version": 1, "won": context.won, "threat": context.threat,
		"expedition": String(context.expedition),
		"class": String(context.player_class),
		"perks": context.perks.map(func(x: StringName) -> String: return String(x)),
		"intel": context.intel, "total_seconds": snappedf(context.time_alive, 0.1),
		"islands": context.island_log}, "  "))


func _on_island_finished(won: bool) -> void:
	if _test_scene != null:
		_test_scene = null  # a test: back to the title, nothing recorded
		_go(GameFlow.TITLE)
		return
	# The island's entry in the log gets what the debrief cards show.
	if not context.island_log.is_empty():
		context.island_log[-1].merge(_landing)
	if won and not context.is_last_island():
		context.advance()
		_go(GameFlow.CAMP if context.is_expedition() else GameFlow.BOAT)
	else:
		context.won = won
		if won:
			# Extracting multiplies everything earned in the run.
			context.intel = int(context.intel * GameData.EXTRACTION_INTEL_MULTIPLIER)
		_go(GameFlow.DEBRIEF)
