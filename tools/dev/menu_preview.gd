extends SceneTree
## Capture real Godot menus without modifying the player's profile.
## --script res://tools/dev/menu_preview.gd -- <absolute PNG path> <screen>

class PreviewProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _main: Node
var _frames: int = 0
var _screen: String = "title"
var _out: String
var _elapsed: float = 0.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		print("Usage: menu_preview.gd -- <PNG path> [title|armory|routes|supplies|pause|settings|archive|weapons|perks]")
		quit(1)
		return
	_out = args[0]
	if args.size() > 1:
		_screen = args[1]
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _process(delta: float) -> bool:
	_elapsed += delta
	_frames += 1
	if _frames == 1:
		var profile := PreviewProfile.new()
		profile.intel = 3716
		profile.slots = 3
		profile.perk_ranks = {&"combat_1": 2, &"survival_1": 1}
		profile.equipped_perks = [&"head_hunter", &"thick_skin"]
		profile.selected_primary = &"machine_gun"
		profile.selected_secondary = &"marksman"
		profile.unlocked_weapons = [&"machine_gun", &"marksman"]
		profile.unlocked_classes = [&"recruit", &"vanguard"]
		profile.selected_class = &"recruit"
		profile.max_threat = 2
		profile.threat = 2
		profile.lore_pages = 3
		_main.set("profile", profile)
		_main.call("_go", 4)
	if _frames == 2:
		match _screen:
			"armory", "weapons", "perks": _main.call("_go", 3)
			"routes", "supplies": _main.call("_new_run")
			"pause":
				_main.set("context", RunContext.new(7))
				_main.call("_go", 1)
	if _frames == 4:
		var current: Node = _main.get("_current")
		match _screen:
			"weapons": current.call("_select_category", "WEAPONS")
			"perks": current.call("_select_category", "PERKS")
			"routes":
				current.call("_pick", 0)
				current.call("_pick_route", 0)
			"pause": current.set("paused", true)
			"settings": current.call("_settings")
			"archive": current.call("_archive")
	if _frames == 6 and _screen == "perks":
		# As in the mockup: the first node focused, its detail on the right.
		(_main.get("_current").get("_perk_buttons")[&"combat_1"] as Button).grab_focus()
	# BootSplashPlus stays visible for at least 2.3 s, irrespective of FPS.
	if _frames >= 12 and _elapsed >= 3.0:
		var screenshot := root.get_texture().get_image()
		var error: Error = screenshot.save_png(_out)
		print("PREVIEW: %s %dx%d / save %d" % [_screen, screenshot.get_width(), screenshot.get_height(), error])
		_frames = -10000
		call_deferred("_finish", 0 if error == OK else 1)
	return false


func _finish(code: int) -> void:
	_main.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.1).timeout
	quit(code)
