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
## the only thing that crosses states. Every ISLAND goes through the
## LoadingScreen overlay (game/ui/loading_screen.gd), which loads the scenes
## before the island is built.

enum GameFlow { BOAT, ISLAND, DEBRIEF, ARMORY, TITLE, CAMP }

const ISLAND_SCENE: String = "res://game/world/island.tscn"

## A loading screen opened for an island (tests watch it; it frees itself).
signal loading_started(screen: LoadingScreen)

var state: GameFlow = GameFlow.BOAT
var context: RunContext
var profile: Profile
var _current: Node
var _test_path: String = ""  ## TEST ISLAND: the scene being tested, no run around it
var _test_scene: PackedScene  ## ...and that scene once loaded
var _landing: Dictionary = {}  ## RunContext.island_info() of the island being played
var _loading: LoadingScreen  ## while an island loads


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
	ctx.apply_perks(profile.equipped_perks, profile.equipped_perk_ranks())
	ctx.weapons = profile.weapon_loadout()
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
	_test_path = path
	_test_scene = null
	_go(GameFlow.ISLAND)


func _go(next: GameFlow) -> void:
	if _current != null:
		_current.queue_free()
	if _loading != null:  # leaving while an island was still loading
		_loading.queue_free()
		_loading = null
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
			_current = null
			_enter_island()  # through the loading screen; it attaches the island
			return
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
	_attach(_current)


func _attach(node: Node) -> void:
	_current = node
	add_child(node)
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


## ISLAND: opens the loading screen over everything, loads the island scene
## (and the hand-made part or test scene), builds the island under the
## screen and lets it fade. The run (context) is not touched here, so HP,
## cards and the expedition part carry over exactly as before. Headless,
## all of it happens synchronously inside this call.
func _enter_island() -> void:
	var part_path: String = _test_path if _test_path != "" else context.part_scene()
	var paths := PackedStringArray([ISLAND_SCENE])
	if part_path != "":
		paths.append(part_path)
	var screen := LoadingScreen.new(LoadingScreen.describe(context, _test_path))
	screen.name = "LoadingScreen"
	_loading = screen
	add_child(screen)
	screen.fetch_radio(context)
	loading_started.emit(screen)
	var loaded: Dictionary = await screen.load_all(paths)
	if _loading != screen:
		return  # replaced meanwhile (another _go)
	var island_scene := loaded.get(ISLAND_SCENE) as PackedScene
	var part_scene: PackedScene = loaded.get(part_path) as PackedScene if part_path != "" else null
	if island_scene == null or (part_path != "" and part_scene == null):
		var missing: String = ISLAND_SCENE if island_scene == null else part_path
		push_warning("Cannot load %s" % missing)
		screen.fail(tr("Could not load %s. This run ends here; your profile is safe.") % missing.get_file())
		screen.back_requested.connect(_on_load_failed.bind(screen), CONNECT_ONE_SHOT | CONNECT_DEFERRED)
		return
	await screen.building()
	if _loading != screen:
		return
	var island: Node = island_scene.instantiate()
	island.set("context", context)
	island.set("profile", profile)
	if _test_path != "":
		_test_scene = part_scene
	if part_scene != null:
		island.set("handmade_scene", part_scene)
	_landing = context.island_info()
	island.connect("finished", _on_island_finished, CONNECT_DEFERRED)
	_attach(island)
	_loading = null
	screen.finish()


## BACK TO TITLE on a failed load: the run is dropped, the profile kept.
func _on_load_failed(screen: LoadingScreen) -> void:
	if _loading == screen:
		_loading = null
	screen.queue_free()
	_test_path = ""
	_test_scene = null
	_go(GameFlow.TITLE)


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
		"perk_ranks": context.perks.map(func(x: StringName) -> int: return context.perk_rank(x)),
		"intel": context.intel, "total_seconds": snappedf(context.time_alive, 0.1),
		"islands": context.island_log}, "  "))


func _on_island_finished(won: bool) -> void:
	if _test_path != "":
		_test_path = ""  # a test: back to the title, nothing recorded
		_test_scene = null
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
