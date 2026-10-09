extends SceneTree
## TEST ISLAND (title, development builds): the island list, the picker and
## the flow title -> chosen island -> title, with nothing recorded.

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _check(ok: bool, message: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("TEST FAIL: " + message)


func _settle() -> void:
	await process_frame
	await process_frame


func _run_tests() -> void:
	var all: PackedStringArray = HandmadeIsland.island_paths()
	# The Berlenga is an expedition now (Expeditions.test_entries), not an island.
	_check(all.has(HandmadeIsland.ISLANDS_DIR + "port_hashima.scn") and not Array(all).any(func(p: String) -> bool: return "berlenga" in p), "the list has Hashima, not the Berlenga")
	_check(Expeditions.test_entries().size() == 5, "the Berlenga's whole island and 4 parts are listed (%d)" % Expeditions.test_entries().size())
	var port: PackedStringArray = HandmadeIsland.island_paths(&"port")
	_check(port.size() >= 2 and Array(port).all(func(p: String) -> bool: return p.get_file().begins_with("port_")), "a biome lists only its islands")
	# The picker: choosing a mission, then an island, hands both over.
	var holder := Control.new()
	root.add_child(holder)
	var picked: Array = []
	var dialog: MenuDialog = MenuDialog.test_island(holder, func(path: String, mission: StringName) -> void: picked.append([path, mission]))
	await _settle()
	var mission: OptionButton = dialog.find_child("Mission", true, false)
	_check(mission != null and mission.item_count == GameData.MISSIONS.size(), "one entry per mission")
	var defend: int = -1
	for i in mission.item_count:
		if mission.get_item_metadata(i) == &"defend":
			defend = i
	mission.select(defend)
	# Expedition scenes are listed only once built (tests/test_expedition.gd
	# covers them with stand-ins).
	var entries: Array[Dictionary] = Expeditions.test_entries()
	var listed: Array = dialog.find_children("Expedition_*", "Button", true, false)
	_check(listed.size() == entries.size() and entries.all(func(e: Dictionary) -> bool: return dialog.find_child("Expedition_" + String(e["id"]), true, false) != null), "one button per built expedition scene (%d)" % entries.size())
	var button: Button = dialog.find_child("Island_beach_01", true, false)
	_check(button != null, "one button per island")
	button.pressed.emit()
	await _settle()
	_check(picked.size() == 1 and picked[0][0] == HandmadeIsland.ISLANDS_DIR + "beach_01.tscn" and picked[0][1] == &"defend", "the picker hands over the island and the mission")
	holder.queue_free()
	# The game: title -> the island (that scene, that mission) -> title.
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await _settle()
	var runs: int = (main.get("profile") as Profile).runs
	main.call("_test_island", HandmadeIsland.ISLANDS_DIR + "beach_01.tscn", &"rescue")
	await _settle()
	var island: Node = main.get("_current")
	_check(main.get("state") == 1, "the game goes straight to the island")  # GameFlow.ISLAND
	_check(island.get("handmade_scene") != null and (island.get("handmade_scene") as PackedScene).resource_path.ends_with("beach_01.tscn"), "the chosen island is played")
	var context: RunContext = main.get("context")
	_check(context.biome == &"beach" and context.mission == &"rescue", "biome from the file name, chosen mission")
	main.call("_on_island_finished", true)
	await _settle()
	_check(main.get("state") == 4, "back to the title when it ends")  # GameFlow.TITLE
	_check((main.get("profile") as Profile).runs == runs, "a test is not recorded as a run")
	main.queue_free()
	await _settle()
	if _failures == 0:
		print("TEST: test island OK (%d checks)" % _checks)
	quit(1 if _failures > 0 else 0)
