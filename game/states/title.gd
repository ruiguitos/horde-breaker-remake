extends Node
## Title screen: a live island in the background (Island in showcase mode,
## the horde milling about under an orbiting camera) with the menu on top.

signal play_requested

const ISLAND_SCENE: String = "res://game/world/island.tscn"

var profile: Profile


func _ready() -> void:
	var island: Node = (load(ISLAND_SCENE) as PackedScene).instantiate()
	island.set("showcase", true)
	island.set("rng_seed", randi() % 1000 + 1)
	add_child(island)

	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.get_theme()
	layer.add_child(root)
	# Dark gradient on the left so the menu reads over the 3D scene.
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	shade.custom_minimum_size = Vector2(460, 0)
	shade.size = Vector2(460, root.get_viewport_rect().size.y)
	root.add_child(shade)

	var box := VBoxContainer.new()
	box.position = Vector2(60, 110)
	box.custom_minimum_size = Vector2(340, 0)
	box.add_theme_constant_override("separation", 14)
	root.add_child(box)
	box.add_child(UiTheme.title("HORDE\nBREAKER", 56))
	var tag := Label.new()
	tag.text = "Salvage & Co. — Archipelago Recovery Division"
	tag.add_theme_color_override("font_color", UiTheme.MUTED)
	tag.add_theme_font_size_override("font_size", 15)
	box.add_child(tag)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 30)
	box.add_child(gap)
	var play := _button(box, "DEPLOY", func() -> void:
		var s := AudioStreamPlayer.new()
		s.bus = Profile.BUS_SFX
		s.stream = load(Sfx.PACK + String(Sfx.FILES[&"ui_start"]))
		get_tree().root.add_child(s)
		s.finished.connect(s.queue_free)
		s.play()
		play_requested.emit())
	_button(box, "SETTINGS", func() -> void:
		if profile != null:
			SettingsPanel.open(root, profile))
	_button(box, "QUIT", func() -> void: get_tree().quit())
	var stats := Label.new()
	stats.add_theme_color_override("font_color", UiTheme.MUTED)
	stats.add_theme_font_size_override("font_size", 15)
	if profile != null and profile.runs > 0:
		stats.text = "Intel %d · Runs %d · Extractions %d" % [profile.intel, profile.runs, profile.extractions]
	box.add_child(stats)
	play.grab_focus()
	root.add_child(UiSfx.new())


func _button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(action)
	parent.add_child(b)
	return b
