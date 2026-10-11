extends SceneTree
## Loading screen (game/ui/loading_screen.gd) inside main.gd: shown for
## every island, progress reaches 100%, the run context crosses an
## expedition part transition untouched, and a scene that cannot load ends
## on BACK TO TITLE instead of a crash. Headless, all of it is synchronous.
## Run: godot --headless --path . --script res://tests/test_loading_screen.gd

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

enum Flow { BOAT, ISLAND, DEBRIEF, ARMORY, TITLE, CAMP }  # mirrors main.gd GameFlow

const STAND_INS: Array[String] = [
	"res://game/world/handmade/islands/beach_01.tscn",
	"res://game/world/handmade/islands/jungle_01.tscn",
	"res://game/world/handmade/islands/port_01.tscn",
	"res://game/world/handmade/islands/town_01.tscn",
]

var _failures: int = 0
var _main: Node
var _screens: Array[LoadingScreen] = []
var _seen: Array[Dictionary] = []  ## per screen: in tree when shown, progress values


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	_run.call_deferred()


func _settle() -> void:
	await process_frame
	await process_frame


func _current() -> Node:
	return _main.get("_current")


func _state() -> int:
	return int(_main.get("state"))


func _on_loading(screen: LoadingScreen) -> void:
	_screens.append(screen)
	var seen: Dictionary = {"shown": screen.is_inside_tree() and screen.visible, "values": [], "info": screen.info}
	_seen.append(seen)
	screen.progress_changed.connect(func(v: float) -> void: (seen["values"] as Array).append(v))


func _run() -> void:
	_check(DisplayServer.get_name() == "headless", "runs headless (synchronous loading)")
	_describe_tests()
	await _direct_tests()
	var holdout: StringName = &"holdout" if GameData.MISSIONS.has(&"holdout") else &"defend"
	var missions: Array[StringName] = [&"rescue", &"activate", &"defend", holdout]
	var parts: Array = []
	for i in 4:
		parts.append({"name": "Stand-in %d" % (i + 1), "scene": STAND_INS[i], "mission": missions[i]})
	Expeditions.stand_ins[&"berlenga"] = parts
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _settle()
	var profile := MemoryProfile.new()
	_main.set("profile", profile)
	Profile.current = profile
	_main.connect("loading_started", _on_loading)
	await _part_transition()
	await _failure_path(parts)
	_main.queue_free()
	await _settle()
	Expeditions.stand_ins.clear()
	quit(1 if _failures > 0 else 0)


## What the screen says, from the run context alone.
func _describe_tests() -> void:
	var ctx := RunContext.new(3)
	ctx.biome = &"jungle"
	ctx.mission = &"defend"
	ctx.threat = 3
	var d: Dictionary = LoadingScreen.describe(ctx)
	_check(d["place"] == GameData.BIOMES[&"jungle"]["name"] and d["mission"] == Expeditions.mission_name(&"defend") and d["count"] == RunContext.ISLAND_COUNT,
		"archipelago: biome name, mission and island count")
	_check(String(d["objective"]) != "" and d["threat"] == 3, "the objective line and threat are there")
	var exp := RunContext.new(3)
	exp.start_expedition(&"berlenga", 1)
	d = LoadingScreen.describe(exp)
	_check(d["expedition"] == "berlenga" and d["place"] == exp.part_name() and d["part"] == 2 and d["count"] == 4, "expedition: part name and PART 2 OF 4")
	d = LoadingScreen.describe(exp, "res://x/part_2.scn")
	_check(d["test"] and d["test_file"] == "part_2", "a test island is marked as one")


## The screen on its own: load, build, finish; and its labels.
func _direct_tests() -> void:
	var ctx := RunContext.new(4)
	ctx.start_expedition(&"berlenga", 0)
	var screen := LoadingScreen.new(LoadingScreen.describe(ctx))
	root.add_child(screen)
	_check((screen.find_child("Place", true, false) as Label).text == ctx.part_name().to_upper(), "the place name is the title")
	_check((screen.find_child("Phase", true, false) as Label).text == "LOADING ASSETS", "first phase: LOADING ASSETS")
	_check((screen.find_child("RadioText", true, false) as Label).text != "", "a radio tip is shown from the start")
	var loaded: Dictionary = await screen.load_all(PackedStringArray(["res://game/world/island.tscn"]))
	_check(loaded.get("res://game/world/island.tscn") is PackedScene, "load_all returns the scene")
	_check(is_equal_approx(screen.progress, LoadingScreen.LOAD_SHARE), "loading fills its share of the bar (%.2f)" % screen.progress)
	await screen.building()
	_check((screen.find_child("Phase", true, false) as Label).text == "BUILDING THE ISLAND", "second phase: BUILDING THE ISLAND")
	screen.finish()
	_check(is_equal_approx(screen.progress, 1.0) and (screen.find_child("Percent", true, false) as Label).text == "100%", "finish: 100%")
	_check(screen.is_queued_for_deletion(), "headless: freed at once, no fade")
	await _settle()


## Expedition part 1 -> camp -> part 2: a screen each time, 100% each time,
## and the run (same RunContext) carries HP, level and cards.
func _part_transition() -> void:
	_main.call("_new_run", &"berlenga")
	_check(_screens.size() == 1 and _seen[0]["shown"], "landing opens the loading screen over the game")
	var values: Array = _seen[0]["values"]
	_check(not values.is_empty() and is_equal_approx(values[-1], 1.0), "progress reaches 100%% (%s)" % [values])
	var rising: bool = true
	for i in range(1, values.size()):
		rising = rising and values[i] >= values[i - 1]
	_check(rising, "progress never goes backwards")
	_check(_screens[0].phase == LoadingScreen.Phase.READY, "the screen ends READY")
	_check(_state() == Flow.ISLAND and _current() != null and _current().get("run") != null, "the island is built synchronously (headless)")
	await _settle()
	_check(not is_instance_valid(_screens[0]), "the screen is gone once the island runs")
	var ctx: RunContext = _main.get("context")
	var run1: IslandRun = _current().get("run")
	run1.level = 3
	run1.card_stacks = {&"carry_test": 2}
	run1.hp = 55.0
	run1.objective = IslandRun.Objective.WON
	_current().call("_finish")
	await _settle()
	_check(_state() == Flow.CAMP, "the won part leads to the camp")
	_current().call("_pick", 1)  # a supply that does not heal
	var hp_before: float = ctx.hp  # 55 (Field Repairs may add to it at CONTINUE)
	_current().call("_land_now")
	await _settle()
	_check(_screens.size() == 2 and is_equal_approx((_seen[1]["values"] as Array)[-1], 1.0), "the next part loads through the screen to 100%")
	_check(_screens.size() == 2 and int(_seen[1]["info"]["part"]) == 2, "the screen names part 2")
	_check(_main.get("context") == ctx and ctx.island_index == 1 and ctx.is_expedition(), "the same run context, on part 2")
	var run2: IslandRun = _current().get("run")
	_check(run2 != null and run2.level == 3 and run2.card_stacks.get(&"carry_test", 0) == 2 and is_equal_approx(run2.hp, ctx.hp) and is_equal_approx(hp_before, 55.0) and ctx.hp >= hp_before,
		"level, cards and HP carried over (%.0f)" % (run2.hp if run2 else -1.0))
	await _settle()


## A part scene that cannot load: the screen says so and goes back to the
## title, nothing crashes and nothing half-built is left.
func _failure_path(parts: Array) -> void:
	var broken: Array = parts.duplicate(true)
	broken[1]["scene"] = "res://game/world/handmade/islands/does_not_exist.tscn"
	Expeditions.stand_ins[&"berlenga"] = broken
	_main.call("_go", Flow.TITLE)
	await _settle()
	_main.call("_new_run", &"berlenga")
	await _settle()
	var run: IslandRun = _current().get("run")
	run.objective = IslandRun.Objective.WON
	_current().call("_finish")
	await _settle()
	var before: int = _screens.size()
	_current().call("_pick", 1)
	_current().call("_land_now")
	await _settle()
	var screen: LoadingScreen = _screens[-1] if _screens.size() > before else null
	_check(screen != null and is_instance_valid(screen) and screen.phase == LoadingScreen.Phase.FAILED, "a missing scene shows DEPLOYMENT FAILED")
	if screen == null or not is_instance_valid(screen):
		return
	var error: Control = screen.find_child("Error", true, false)
	_check(error.is_visible_in_tree() and screen.error_message.contains("does_not_exist"), "the message names what failed")
	_check(_current() == null, "no half-built island")
	var back: Button = screen.find_child("BackToTitle", true, false)
	_check(back != null and back.has_focus(), "BACK TO TITLE has focus")
	back.pressed.emit()
	await _settle()
	_check(_state() == Flow.TITLE and not is_instance_valid(screen), "back on the title, the screen gone")
	Expeditions.stand_ins[&"berlenga"] = parts
