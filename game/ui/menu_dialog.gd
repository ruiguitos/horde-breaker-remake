class_name MenuDialog
extends Control
## A shared modal with a focus cycle, input isolation and return focus.

signal closed

var content: VBoxContainer
var _previous_focus: Control


func _ready() -> void:
	_previous_focus = get_viewport().gui_get_focus_owner()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.get_theme()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	content = UiTheme.centered_panel(self, 620)
	call_deferred("_trap_focus")


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		close()


func _unhandled_input(event: InputEvent) -> void:
	# Keep F11 available, but prevent Q/Start/shortcuts from reaching the game.
	if event is InputEventKey and event.physical_keycode == KEY_F11:
		return
	get_viewport().set_input_as_handled()


func _trap_focus() -> void:
	var buttons: Array[Control] = []
	for node in find_children("*", "Control", true, false):
		if (node is Button and not node.disabled) or node is HSlider or node is LineEdit:
			buttons.append(node as Control)
	if buttons.is_empty():
		return
	for i in buttons.size():
		var previous: NodePath = buttons[i].get_path_to(buttons[posmod(i - 1, buttons.size())])
		var next: NodePath = buttons[i].get_path_to(buttons[(i + 1) % buttons.size()])
		buttons[i].focus_previous = previous
		buttons[i].focus_next = next
		buttons[i].focus_neighbor_top = previous
		if buttons[i] is Button:
			buttons[i].focus_neighbor_left = previous
		buttons[i].focus_neighbor_bottom = next
		if buttons[i] is Button:
			buttons[i].focus_neighbor_right = next
	buttons[0].grab_focus()


func close() -> void:
	set_process_input(false)
	set_process_unhandled_input(false)
	closed.emit()
	queue_free()
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()


static func settings(parent: Node, profile: Profile) -> MenuDialog:
	# Runtime load avoids a circular class dependency: SettingsPanel inherits us.
	var dialog: MenuDialog = (load("res://game/ui/settings_panel.gd") as Script).new() as MenuDialog
	dialog.set("profile", profile)
	parent.add_child(dialog)
	return dialog


static func archive(parent: Node, profile: Profile) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("INTEL ARCHIVE", 36))
	dialog.content.add_child(UiTheme.label("RECOVERED FILES  %02d / %02d" % [profile.lore_pages, Story.FILES.size()], 16, UiTheme.ACCENT, true))
	var list := _scroll(dialog.content, 320)
	for i in Story.FILES.size():
		var recovered: bool = i < profile.lore_pages
		list.add_child(UiTheme.title(Story.FILES[i]["title"] if recovered else "FILE %02d / ENCRYPTED" % (i + 1), 22))
		list.add_child(UiTheme.label(Story.FILES[i]["text"] if recovered else "Recover this file from supply caches or the Behemoth.", 16, UiTheme.TEXT if recovered else UiTheme.MUTED))
		list.add_child(HSeparator.new())
	UiTheme.button(dialog.content, "CLOSE", dialog.close, true)
	return dialog


static func controls(parent: Node) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("CONTROLS", 36))
	var list := _scroll(dialog.content, 300)
	list.add_child(UiTheme.label("Your weapon fires automatically at enemies in front of you. Turn your body to choose a target.", 18, UiTheme.ACCENT))
	list.add_child(UiTheme.label("MOVE       WASD / arrows / left stick\nAIM        Mouse / right stick\nBREAKER    Space / RMB / A / RB\nABILITY    G / MMB / LB\nSPRINT     Shift / L3\nWEAPONS    1–5 / D-pad\nPAUSE      Esc / Start\nMENUS      Enter / A · Esc / B back\nSUPPLIES   1–3 / X · Y · B\nROUTES     4–5 / LB · RB", 18, UiTheme.TEXT, true))
	UiTheme.button(dialog.content, "BACK", dialog.close, true)
	return dialog


## Armory > START RUN: the archipelago run or an expedition. `on_pick` gets
## &"" (archipelago) or the expedition id. An expedition whose part scenes
## are not built yet is shown disabled.
static func run_choice(parent: Node, on_pick: Callable) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("CHOOSE YOUR RUN", 36))
	var runs: Array = [[&"", "ARCHIPELAGO", "By boat: two routes at every landing, %d islands, the volcano last." % RunContext.ISLAND_COUNT]]
	for id: StringName in Expeditions.INFO:
		runs.append([id, Expeditions.display_name(id).to_upper(), String(Expeditions.INFO[id]["text"])])
	for run: Array in runs:
		var id: StringName = run[0]
		var playable: bool = id == &"" or Expeditions.available(id)
		var text: String = "%s\n%s" % [run[1], run[2] if playable else "Not built yet: its part scenes are missing."]
		var pick := func() -> void:
			dialog.close()
			on_pick.call(id)
		var b := UiTheme.button(dialog.content, text, pick, id == &"")
		b.name = "Run_" + (String(id) if id != &"" else "archipelago")
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size.y = 96
		b.disabled = not playable
	UiTheme.button(dialog.content, "BACK", dialog.close)
	return dialog


## Development builds (Title > TEST ISLAND): every hand-made island and a
## mission, to play one straight away. `on_pick` gets the island's path and
## the mission id.
static func test_island(parent: Node, on_pick: Callable) -> MenuDialog:
	var dialog := MenuDialog.new()
	parent.add_child(dialog)
	dialog.content.add_child(UiTheme.title("TEST ISLAND", 36))
	dialog.content.add_child(UiTheme.label("Development builds only: one island, no run around it.", 16, UiTheme.MUTED))
	var mission := OptionButton.new()
	mission.name = "Mission"
	for id: StringName in GameData.MISSIONS:
		mission.add_item("MISSION: " + String(GameData.MISSIONS[id]["name"]).to_upper())
		mission.set_item_metadata(mission.item_count - 1, id)
	dialog.content.add_child(mission)
	var list := _scroll(dialog.content, 300)
	for path in HandmadeIsland.island_paths():
		var b := UiTheme.button(list, path.get_file().get_basename().to_upper(), func() -> void:
			var id: StringName = mission.get_item_metadata(mission.selected)
			dialog.close()
			on_pick.call(path, id))
		b.name = "Island_" + path.get_file().get_basename()
	# Expedition scenes (when built): the whole island takes the mission
	# above; a part always plays its own mission.
	for entry: Dictionary in Expeditions.test_entries():
		var b := UiTheme.button(list, String(entry["label"]), func() -> void:
			var id: StringName = entry["mission"] if entry["mission"] != &"" else mission.get_item_metadata(mission.selected)
			dialog.close()
			on_pick.call(String(entry["path"]), id))
		b.name = "Expedition_" + String(entry["id"])
	UiTheme.button(dialog.content, "BACK", dialog.close, true)
	return dialog


static func _scroll(parent: Control, height: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var navigation := HBoxContainer.new()
	parent.add_child(navigation)
	for direction in [-1, 1]:
		var b := UiTheme.button(navigation, "↑ READ ABOVE" if direction < 0 else "↓ READ BELOW", func() -> void:
			scroll.scroll_vertical += direction * int(height * 0.8))
		b.name = "ScrollUp" if direction < 0 else "ScrollDown"
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 18)
	return list
