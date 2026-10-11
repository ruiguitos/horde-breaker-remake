extends SceneTree
## Credits opened from the real title menu, readable at small window sizes.

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_tests")


func _run_tests() -> void:
	root.size = Vector2i(1152, 648)
	var title: Node = (load("res://game/states/title.gd") as Script).new()
	title.set("profile", Profile.new())
	root.add_child(title)
	await process_frame
	var button: Button = title.find_child("Credits", true, false)
	_check(button != null, "Title offers a Credits button")
	if button == null:
		title.free()
		quit(1)
		return
	button.grab_focus()
	button.pressed.emit()
	await process_frame
	await process_frame
	var dialog: MenuDialog = title.get("_dialog")
	_check(is_instance_valid(dialog), "Credits opens a modal from Title")
	if not is_instance_valid(dialog):
		title.free()
		quit(1)
		return
	button.pressed.emit()
	_check(title.get("_dialog") == dialog, "Repeated Credits requests keep the existing modal")
	var osm: Label = dialog.find_child("OpenStreetMapCredit", true, false)
	var sky: Label = dialog.find_child("MilkyWayCredit", true, false)
	_check(osm != null and osm.text == "© OpenStreetMap contributors", "Credits shows the exact OpenStreetMap attribution")
	_check(sky != null and sky.text == "The Milky Way panorama by ESO/S. Brunier, licensed under CC BY 4.0 and used in original and modified forms.", "Credits names the sky author, licence and modifications")
	var links: Array[String] = []
	for link: LinkButton in dialog.find_children("*", "LinkButton", true, false):
		links.append(String(link.get_meta("url", "")))
		_check(not link.focus_next.is_empty() and dialog.is_ancestor_of(link.get_node(link.focus_next)), "Attribution link stays in the modal focus cycle")
	_check(links.has("https://www.openstreetmap.org/copyright") and links.has("https://www.eso.org/public/images/eso0932a/")
		and links.has("https://creativecommons.org/licenses/by/4.0/"), "Attributions include source and licence links")
	var scroll: ScrollContainer = dialog.find_child("CreditsContent", true, false)
	var frame: Control = dialog.find_child("CreditsFrame", true, false)
	_check(scroll != null and frame != null and root.get_visible_rect().encloses(frame.get_global_rect()), "Credits frame fits the standard window")
	var down: Button = dialog.find_child("ScrollDown", true, false)
	var back: Button = dialog.find_child("Back", true, false)
	_check(down != null and back != null and not down.focus_next.is_empty() and not back.focus_next.is_empty(), "Controller can reach the read and Back buttons")
	if down != null and scroll != null:
		down.pressed.emit()
		await process_frame
		_check(scroll.scroll_vertical > 0, "Read below scrolls the credits without a mouse")
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	_check(root.get_visible_rect().encloses(frame.get_global_rect()) and frame.get_global_rect().encloses(back.get_global_rect()), "Credits and Back remain inside a 640x360 window")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	dialog.call("_input", escape)
	await process_frame
	_check(not is_instance_valid(dialog) and root.gui_get_focus_owner() == button, "Escape closes Credits and returns focus to its Title button")
	root.size = Vector2i(1152, 648)
	button.pressed.emit()
	await process_frame
	await process_frame
	dialog = title.get("_dialog")
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_B
	cancel.pressed = true
	dialog.call("_input", cancel)
	await process_frame
	_check(not is_instance_valid(dialog), "Controller Back closes Credits")
	title.queue_free()
	await process_frame
	(load("res://addons/guide/ui/guide_input_formatter.gd") as Script).cleanup()
	quit(0 if _failures == 0 else 1)
