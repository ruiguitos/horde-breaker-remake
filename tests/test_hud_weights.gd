extends SceneTree
## Visual weight of the field HUD (the proposal's "peso só onde importa"): health, ammo, the breaker and the
## warnings keep a strong outline; the XP, the counters and the minimap's legend sit at 85 % with a lighter
## outline. The minimal HUD of the horror preset still hides the soft group, and brings it back at 85 %.
## Run: godot --headless --path . --script res://tests/test_hud_weights.gd

var _failures: int = 0
var _hud: Hud
var _run: IslandRun
var _viewport: SubViewport


func _check(ok: bool, description: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + description)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1152, 648)
	root.add_child(_viewport)
	_hud = Hud.new()
	_hud.custom_viewport = _viewport
	_viewport.add_child(_hud)
	_run = IslandRun.new(7)
	call_deferred("_test")


func _alpha(name: String) -> float:
	return (_hud.get(name) as Control).modulate.a


func _outline(name: String) -> float:
	return (_hud.get(name) as Label).get_theme_color("font_outline_color").a


func _test() -> void:
	_hud.refresh(_run, null, 0)
	await process_frame
	for name: String in ["_xp_text", "_stats", "_xp_bar"]:
		_check(absf(_alpha(name) - 0.85) < 0.001, "%s rests at 85 %% (%.2f)" % [name, _alpha(name)])
	var legend: Control = _hud.get("_legend")
	_check(absf(legend.modulate.a - 0.85) < 0.001, "the minimap's legend rests at 85 %% (%.2f)" % legend.modulate.a)
	for name: String in ["_hp_text", "_alerts"]:
		_check(absf(_alpha(name) - 1.0) < 0.001, "%s keeps full strength (%.2f)" % [name, _alpha(name)])
	_check(_outline("_xp_text") < 0.5 and absf(_outline("_hp_text") - 0.8) < 0.001,
		"the soft text has a lighter outline (XP %.2f, health %.2f)" % [_outline("_xp_text"), _outline("_hp_text")])
	var track: StyleBoxFlat = (_hud.get("_xp_bar") as ProgressBar).get_theme_stylebox("background") as StyleBoxFlat
	_check(absf(track.border_color.a - 0.3) < 0.001, "the XP gauge's track has a lighter border (%.2f)" % track.border_color.a)

	# The strong group keeps its outlines: the health gauge's border stays at 0.6 next to the lighter XP gauge.
	var health_track: StyleBoxFlat = (_hud.get("_hp_bar") as ProgressBar).get_theme_stylebox("background") as StyleBoxFlat
	_check(absf(health_track.border_color.a - 0.6) < 0.001 and absf(_outline("_alerts") - 0.8) < 0.001,
		"the strong group keeps its outlines: health gauge border 0.6, warnings 0.8")

	# The horror preset's minimal HUD hides the soft group, and leaving it brings the soft group back at 85 %.
	# Two full cycles, with a refresh between the transitions: the group ends where it started.
	var soft: Array[String] = ["_xp_bar", "_xp_text", "_xp_bonus", "_stats", "_survivor_row", "_legend"]
	for cycle in 2:
		_hud.set_minimal(true)
		_hud.call("_process", 0.0)
		var hidden: bool = true
		for name: String in soft:
			# The legend keeps its own 85 % but hides through its minimap box, which is the minimal control.
			var shown: float = _alpha("_map_box") if name == "_legend" else _alpha(name)
			hidden = hidden and shown == 0.0
		_check(hidden, "minimal (cycle %d): the XP, the counters and the legend are hidden" % (cycle + 1))
		_check(absf(_alpha("_hp_text") - 1.0) < 0.001, "minimal (cycle %d): health stays on screen" % (cycle + 1))
		_hud.set_minimal(false)
		_hud.refresh(_run, null, 0)
		await process_frame
		var rest: bool = true
		for name: String in soft:
			rest = rest and absf(_alpha(name) - 0.85) < 0.001
		_check(rest, "leaving the minimal HUD (cycle %d), the XP, the counters and the legend return to 85 %%" % (cycle + 1))
	_check(absf(_alpha("_hp_text") - 1.0) < 0.001, "after two cycles health is still at full strength")

	_hud.free()
	_viewport.free()
	quit(1 if _failures > 0 else 0)
