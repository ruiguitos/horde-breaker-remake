extends SceneTree
## The DEV dialogs fit the base screen (1152 x 648) and the 960 x 540 size
## (docs/design/MENUS.md, "Apresentação e limites"): the sandbox form and the test
## panel keep a margin above and below. A dialog taller than the screen is cut.
## Run: godot --headless --path . --script res://tests/test_dev_fit.gd

const SCREENS: Array[Vector2] = [Vector2(1152, 648), Vector2(960, 540)]
const MARGIN: float = 24.0  ## room kept above and below the dialog panel

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for screen: Vector2 in SCREENS:
		await _check_dialog("sandbox", screen, func(parent: Node) -> MenuDialog:
			return DevSandbox.open(parent, func(_config: Dictionary) -> void: pass))
		await _check_dialog("tests", screen, func(parent: Node) -> MenuDialog:
			return DevTestPanel.open(parent))
	quit(1 if _failures > 0 else 0)


## Opens one dev dialog under a screen-sized parent and checks its panel height.
func _check_dialog(label: String, screen: Vector2, open: Callable) -> void:
	var parent := Control.new()
	parent.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.size = screen
	root.add_child(parent)
	var dialog: MenuDialog = open.call(parent)
	await process_frame
	await process_frame
	var panel := dialog.content.get_parent() as Control
	var height: float = panel.get_combined_minimum_size().y
	_check(height <= screen.y - MARGIN * 2.0,
		"%s dialog at %dx%d: %.0f px tall, room for %.0f px" % [label, screen.x, screen.y, height, screen.y - MARGIN * 2.0])
	parent.free()
	await process_frame
