class_name UiSfx
extends Node
## Add as a child of any menu: every Button under the menu (including ones
## created later, e.g. rebuilt lists) plays a hover sound when hovered or
## focused and a select sound when pressed.

var _player := AudioStreamPlayer.new()
var _last_hover: int = 0


func _ready() -> void:
	_player.bus = Profile.BUS_SFX
	add_child(_player)
	var menu: Node = get_parent()
	for b in menu.find_children("*", "Button", true, false):
		_hook(b as Button)
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Button and get_parent() != null and get_parent().is_ancestor_of(n):
		_hook(n as Button)


func _hook(b: Button) -> void:
	if b.has_meta(&"ui_sfx"):
		return
	b.set_meta(&"ui_sfx", true)
	b.mouse_entered.connect(_hover)
	b.focus_entered.connect(_hover)
	b.pressed.connect(func() -> void: _play(&"ui_select", -8.0))


func _hover() -> void:
	# Rebuilding a menu moves focus around: don't machine-gun the hover sound.
	var now: int = Time.get_ticks_msec()
	if now - _last_hover > 60:
		_last_hover = now
		_play(&"ui_hover", -16.0)


func _play(key: StringName, db: float) -> void:
	if Sfx._streams.is_empty():
		Sfx._build_all()
		Sfx._load_recorded()
	if not Sfx._streams.has(key) or not is_inside_tree():
		return
	_player.stream = Sfx._streams[key]
	_player.volume_db = db
	_player.play()
