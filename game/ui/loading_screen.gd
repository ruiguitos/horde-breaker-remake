class_name LoadingScreen
extends CanvasLayer
## The screen between DEPLOY and the island (or between two expedition
## parts): where you are going, what the job is, a line from Director Hale,
## and a real progress bar. It is an overlay inside main.gd, not a scene
## change, so the run (RunContext: HP, cards, the expedition part) is never
## touched; main only waits for the scenes and then builds the island under
## it.
##
## Two phases, both real:
## 1. LOADING ASSETS: ResourceLoader.load_threaded_request on every scene,
##    progress from load_threaded_get_status (LOAD_SHARE of the bar).
## 2. BUILDING THE ISLAND: main instances the island (island.gd builds the
##    terrain, sky, props in _ready). That blocks the main thread, so the
##    label is drawn first and the bar jumps to 100% when it is done.
## Then it fades out on its own: no "press to start", the run should never
## wait on a screen. On failure it shows the reason and BACK TO TITLE.
##
## Headless (tests, no window): everything is synchronous, no waits and no
## fades, so tests stay fast and deterministic.

signal progress_changed(value: float)
signal back_requested

enum Phase { LOADING, BUILDING, READY, FAILED }

## Share of the bar for loading files; the rest is building the island.
const LOAD_SHARE: float = 0.85
## Windowed only: the screen stays at least this long, enough to read the
## place and the objective (cached scenes would otherwise just flash).
const MIN_SECONDS: float = 1.2
const FADE_SECONDS: float = 0.3

var phase: Phase = Phase.LOADING
var progress: float = 0.0
## What describe() returned: the screen's content.
var info: Dictionary = {}
var error_message: String = ""
var headless: bool = DisplayServer.get_name() == "headless"
var _started_ms: int = 0
var _root: Control
var _bar: SegmentBar
var _phase_label: Label
var _percent: Label
var _radio_portrait: Portrait
var _radio_header: Label
var _radio_text: Label
var _error_panel: PanelContainer
var _error_text: Label
var _back: Button


## The screen's content for the island `ctx` is about to play. Plain data
## (names, numbers), so the screen can be built and tested without a run.
static func describe(ctx: RunContext, test_path: String = "") -> Dictionary:
	var d: Dictionary = {
		"expedition": String(ctx.expedition), "expedition_name": "", "part": ctx.island_index + 1,
		"count": ctx.island_count(), "place": "", "biome": ctx.biome,
		"mission": Expeditions.mission_name(ctx.mission),
		"objective": String(GameData.MISSIONS.get(ctx.mission, {}).get("text", "")),
		"threat": ctx.threat, "hazard_pay": ctx.hazard_pay, "test": test_path != "",
		"test_file": test_path.get_file().get_basename(),
	}
	if ctx.is_expedition():
		d["expedition_name"] = Expeditions.display_name(ctx.expedition)
		d["place"] = ctx.part_name()
	else:
		d["place"] = String(GameData.BIOMES.get(ctx.biome, {}).get("name", String(ctx.biome).capitalize()))
	return d


func _init(p_info: Dictionary = {}) -> void:
	info = p_info


func _ready() -> void:
	layer = 120  # above the island's HUD and menus
	_started_ms = Time.get_ticks_msec()
	_root = Control.new()
	_root.name = "LoadingRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UiTheme.get_theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = UiTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for edge: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + edge, 64)
	for edge: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 48)
	_root.add_child(margin)
	var screen := VBoxContainer.new()
	screen.add_theme_constant_override("separation", 0)
	margin.add_child(screen)
	_top_row(screen)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(spacer)
	_destination(screen)
	_gap(screen, 28)
	_radio_row(screen)
	_gap(screen, 28)
	_progress_rows(screen)
	_error_overlay()
	_show_tip()


func _gap(parent: Control, h: float) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	parent.add_child(c)


## DEPLOYING on the left, threat and hazard pay on the right.
func _top_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var kicker := UiTheme.label(tr("DEPLOYING"), 14, UiTheme.MUTED, true)
	kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kicker)
	if bool(info.get("hazard_pay", false)):
		row.add_child(UiTheme.chip(tr("HAZARD PAY"), UiTheme.DANGER))
	var threat := UiTheme.chip(tr("THREAT %d") % int(info.get("threat", 1)), UiTheme.DANGER if int(info.get("threat", 1)) >= 3 else UiTheme.MUTED)
	threat.name = "Threat"
	row.add_child(threat)


## Where and what: run/part line, place name, mission chip, objective, and
## the biome picture on the right.
func _destination(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	parent.add_child(row)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_END
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var where: String
	if String(info.get("expedition", "")) != "":
		where = tr("%s / PART %d OF %d") % [String(info["expedition_name"]).to_upper(), int(info["part"]), int(info["count"])]
	elif bool(info.get("test", false)):
		where = tr("TEST ISLAND / %s") % String(info.get("test_file", "")).to_upper()
	else:
		where = tr("ARCHIPELAGO / ISLAND %d OF %d") % [int(info.get("part", 1)), int(info.get("count", 1))]
	var run_line := UiTheme.label(where, 16, UiTheme.MUTED, true)
	run_line.name = "RunLine"
	col.add_child(run_line)
	var place := UiTheme.title(String(info.get("place", "")).to_upper(), 64)
	place.name = "Place"
	place.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(place)
	var mission_row := HBoxContainer.new()
	mission_row.add_theme_constant_override("separation", 12)
	col.add_child(mission_row)
	var mission := UiTheme.chip(String(info.get("mission", "")).to_upper(), UiTheme.INFO, 16)
	mission.name = "Mission"
	mission.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mission_row.add_child(mission)
	var objective := UiTheme.label(String(info.get("objective", "")), 20)
	objective.name = "Objective"
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.custom_minimum_size.x = 420
	mission_row.add_child(objective)
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(340, 190)
	plate.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(plate)
	var picture := RoutePreview.new()
	picture.biome = info.get("biome", &"beach") if GameData.BIOMES.has(info.get("biome", &"beach")) else &"beach"
	if String(info.get("expedition", "")) != "":
		picture.expedition = StringName(info["expedition"])
		picture.part = int(info.get("part", 1)) - 1
	picture.custom_minimum_size = Vector2(320, 170)
	plate.add_child(picture)


## Director Hale on the radio: portrait, header and one line.
func _radio_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.name = "Radio"
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	_radio_portrait = Portrait.new()
	_radio_portrait.custom_minimum_size = Vector2(64, 64)
	_radio_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_radio_portrait)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)
	_radio_header = UiTheme.label("", 13, UiTheme.ACCENT, true)
	col.add_child(_radio_header)
	_radio_text = UiTheme.label("", 18)
	_radio_text.name = "RadioText"
	_radio_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_radio_text)


func _progress_rows(parent: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_phase_label = UiTheme.label("", 15, UiTheme.TEXT, true)
	_phase_label.name = "Phase"
	_phase_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_phase_label)
	_percent = UiTheme.label("0%", 15, UiTheme.TEXT, true)
	_percent.name = "Percent"
	_percent.autowrap_mode = TextServer.AUTOWRAP_OFF
	_percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent.custom_minimum_size.x = 64
	row.add_child(_percent)
	_gap(parent, 8)
	_bar = SegmentBar.new()
	_bar.name = "Bar"
	_bar.custom_minimum_size.y = 12
	parent.add_child(_bar)
	_set_phase(Phase.LOADING)


## Hidden until fail(): the reason and the way back.
func _error_overlay() -> void:
	_error_panel = PanelContainer.new()
	_error_panel.name = "Error"
	_error_panel.visible = false  # the whole overlay: dim + centred box
	_error_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_error_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_root.add_child(_error_panel)
	var dim := ColorRect.new()
	dim.color = Color(UiTheme.BG, 0.8)
	_error_panel.add_child(dim)
	var center := CenterContainer.new()
	_error_panel.add_child(center)
	var box := PanelContainer.new()
	center.add_child(box)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 520
	col.add_theme_constant_override("separation", 12)
	box.add_child(col)
	col.add_child(UiTheme.title(tr("DEPLOYMENT FAILED"), 36))
	_error_text = UiTheme.label("", 18)
	_error_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_error_text)
	_back = UiTheme.button(col, tr("BACK TO TITLE"), func() -> void: back_requested.emit(), true)
	_back.name = "BackToTitle"


## A random tip until the briefing's radio line arrives.
func _show_tip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(info.get("place", ""))) + int(info.get("part", 0))
	var entry: Dictionary = Story.radio_entry(&"tips", rng)
	if not entry.is_empty():
		set_radio(String(entry["speaker"]), String(entry["text"]))


## Shows a radio line (speaker picks the portrait).
func set_radio(speaker: String, text: String) -> void:
	_radio_portrait.speaker = speaker
	_radio_header.text = tr("RADIO / %s") % speaker.to_upper()
	_radio_text.text = text


## Asks the briefing dialogue's `radio` cue for a line about this island
## (Berlenga part, threat, last island); keeps the tip if it has none.
## Not awaited by anyone: the line just appears when ready.
func fetch_radio(ctx: RunContext) -> void:
	var dm: Node = get_node_or_null("/root/DialogueManager")
	if dm == null or not ResourceLoader.exists(Briefing.RESOURCE):
		return
	_fetch_radio(weakref(self), dm, load(Briefing.RESOURCE), Briefing.new(ctx))


static func _fetch_radio(screen: WeakRef, dm: Node, res: Resource, briefing: Briefing) -> void:
	var line: Object = await dm.call("get_next_dialogue_line", res, "radio", [{"briefing": briefing}])
	var me: LoadingScreen = screen.get_ref() as LoadingScreen
	if me != null and line != null:
		me.set_radio(String(line.get("character")), String(line.get("text")))


## Loads every path; returns path -> Resource (null for a path that failed).
## Windowed: threaded, with the bar following the real progress, and at
## least MIN_SECONDS on screen. Headless: plain load(), no waiting.
func load_all(paths: PackedStringArray) -> Dictionary:
	var out: Dictionary = {}
	_set_phase(Phase.LOADING)
	if headless:
		for p in paths:
			out[p] = load(p) if ResourceLoader.exists(p) else null
		_set_progress(LOAD_SHARE)
		return out
	for p in paths:
		if not ResourceLoader.exists(p) or ResourceLoader.load_threaded_request(p, "", true) != OK:
			out[p] = null
	while out.size() < paths.size():
		var total: float = 0.0
		for p in paths:
			if out.has(p):
				total += 1.0
				continue
			var status_progress: Array = []
			match ResourceLoader.load_threaded_get_status(p, status_progress):
				ResourceLoader.THREAD_LOAD_LOADED:
					out[p] = ResourceLoader.load_threaded_get(p)
					total += 1.0
				ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					total += float(status_progress[0]) if not status_progress.is_empty() else 0.0
				_:
					out[p] = null
					total += 1.0
		_set_progress(LOAD_SHARE * total / maxf(1.0, float(paths.size())))
		await get_tree().process_frame
	_set_progress(LOAD_SHARE)
	while Time.get_ticks_msec() - _started_ms < int(MIN_SECONDS * 1000.0):
		await get_tree().process_frame
	return out


## BUILDING THE ISLAND: shown (and drawn, windowed) before main blocks the
## thread instancing the island.
func building() -> void:
	_set_phase(Phase.BUILDING)
	_set_progress(maxf(progress, LOAD_SHARE + 0.05))
	if not headless:
		await get_tree().process_frame
		await get_tree().process_frame


## The island is built: 100%, then fade out and free (headless: at once).
func finish() -> void:
	_set_phase(Phase.READY)
	_set_progress(1.0)
	if headless:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property(_root, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)


## Loading failed: the reason and BACK TO TITLE (focused; Esc/B too).
func fail(message: String) -> void:
	error_message = message
	_set_phase(Phase.FAILED)
	_error_text.text = message
	_error_panel.visible = true
	if _back.is_inside_tree():
		_back.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if phase == Phase.FAILED and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		back_requested.emit()


func _set_phase(p: Phase) -> void:
	phase = p
	if _phase_label == null:
		return
	match p:
		Phase.LOADING: _phase_label.text = tr("LOADING ASSETS")
		Phase.BUILDING: _phase_label.text = tr("BUILDING THE ISLAND")
		Phase.READY: _phase_label.text = tr("READY")
		Phase.FAILED: _phase_label.text = tr("DEPLOYMENT FAILED")
	_phase_label.add_theme_color_override("font_color", UiTheme.DANGER if p == Phase.FAILED else UiTheme.TEXT)
	if _bar != null:
		_bar.failed = p == Phase.FAILED
		_bar.queue_redraw()


func _set_progress(v: float) -> void:
	progress = clampf(maxf(progress, v), 0.0, 1.0)  # never goes backwards
	if _percent != null:
		_percent.text = "%d%%" % roundi(progress * 100.0)
	if _bar != null:
		_bar.value = progress
		_bar.queue_redraw()
	progress_changed.emit(progress)


## Tactical segmented bar: lit segments up to the value, the rest outlined.
class SegmentBar extends Control:
	const SEGMENTS: int = 48
	const GAP: float = 3.0
	var value: float = 0.0
	var failed: bool = false

	func _draw() -> void:
		var w: float = (size.x - GAP * (SEGMENTS - 1)) / SEGMENTS
		var lit: int = roundi(value * SEGMENTS)
		for i in SEGMENTS:
			var r := Rect2(Vector2(i * (w + GAP), 0), Vector2(w, size.y))
			if i < lit:
				draw_rect(r, UiTheme.DANGER if failed else UiTheme.TEXT)
			else:
				draw_rect(r, UiTheme.PANEL)
				draw_rect(r, UiTheme.LINE, false, 1.0)
