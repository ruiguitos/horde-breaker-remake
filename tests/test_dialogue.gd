extends SceneTree
## Dialogue box and radio (game/ui/dialogue_box.gd, typewriter.gd,
## dialogue_voice.gd, portrait.gd; game/data/briefing.gd, story.gd):
## typewriter complete/advance, SKIP keeps choices already applied, the
## "Dialogue voice" setting is saved, conditions pick the right lines and
## every line has a stable id.
## Run: godot --headless --path . --script res://tests/test_dialogue.gd

class MemoryProfile extends Profile:
	var saves: int = 0
	func save(_path: String = Profile.PATH) -> bool:
		saves += 1
		return true

const PROFILE_PATH: String = "user://test_dialogue_profile.json"

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	_run.call_deferred()


func _frames(n: int = 2) -> void:
	for i in n:
		await process_frame


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	root.push_input(ev)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	root.push_input(up)


func _run() -> void:
	var dm: Node = root.get_node_or_null("DialogueManager")
	_check(dm != null, "DialogueManager autoload is active")
	if dm == null:
		quit(1)
		return
	_typewriter_tests()
	await _box_tests()
	await _voice_setting_tests()
	await _condition_tests(dm)
	_radio_data_tests()
	_portrait_tests()
	quit(1 if _failures > 0 else 0)


func _typewriter_tests() -> void:
	var label := Label.new()
	var tw := Typewriter.new()
	tw.start(label, "Hello there, contractor. Move.")
	_check(label.visible_characters == 0 and not tw.is_done(), "a new line starts hidden")
	var blips: int = 0
	for i in 6:
		if tw.step(0.05):
			blips += 1
	_check(tw.shown() > 0 and tw.shown() < label.text.length() and not tw.is_done(), "it types letter by letter (%d shown)" % tw.shown())
	_check(blips >= 1, "voice blips every few letters (%d)" % blips)
	tw.complete()
	_check(tw.is_done() and label.visible_characters == -1, "complete() shows the whole line")
	var rich := RichTextLabel.new()
	rich.bbcode_enabled = true
	tw.start(rich, "[i]Ending:[/i] done.")
	tw.step(10.0)
	_check(tw.is_done(), "bbcode tags are not typed (a RichTextLabel finishes on its letters)")
	label.free()
	rich.free()


## Typing, A/Enter completing then advancing, choices, hazard pay, SKIP.
func _box_tests() -> void:
	var ctx := RunContext.new(5)
	ctx.biome = &"port"
	ctx.mission = &"defend"
	var holder := Control.new()
	root.add_child(holder)
	var box := DialogueBox.open(holder, load(Briefing.RESOURCE), "start", [{"briefing": Briefing.new(ctx)}])
	var ended: Array = []
	box.finished.connect(func() -> void: ended.append(true))
	await _frames()
	var portrait: Portrait = box.find_child("Portrait", true, false)
	_check(portrait != null and portrait.speaker == "Director Hale" and Portrait.look_id(portrait.speaker) == "hale", "Director Hale gets his portrait (not a letter)")
	_check((box.find_child("Speaker", true, false) as Label).text == "DIRECTOR HALE", "the speaker's name is shown")
	_check(box.is_typing(), "the line is typing")
	var choices: Node = box.find_child("Choices", true, false)
	_check(choices.get_child_count() == 0, "no choices while the line types")
	_press(&"ui_accept")
	await _frames(1)
	_check(not box.is_typing(), "A/Enter completes the line first")
	_check(choices.get_child_count() == 4 and (choices.get_child(0) as Button).has_focus(), "then the 4 choices appear, the first focused")
	_check(not box.advance(), "a second press does not complete again (it goes to the focused choice)")
	# Hazard pay -> Deal: the choice is applied as soon as it is picked.
	var hazard: Button = null
	for b: Node in choices.get_children():
		if (b as Button).text.contains("hazard"):
			hazard = b
	hazard.pressed.emit()
	await _frames()
	while box.is_typing() or choices.get_child_count() == 1:
		if box.is_typing():
			box.advance()
		else:
			(choices.get_child(0) as Button).pressed.emit()  # CONTINUE
		await _frames()
	var deal: Button = choices.get_child(0) as Button
	_check(deal.text.contains("Deal"), "hazard pay offers Deal")
	deal.pressed.emit()
	await _frames()
	_check(ctx.hazard_pay, "Deal sets hazard pay on the run")
	_press(&"ui_cancel")  # SKIP (Esc / B)
	await _frames()
	_check(ended.size() == 1 and not is_instance_valid(box), "SKIP ends the whole conversation")
	_check(ctx.hazard_pay, "SKIP keeps the hazard pay already accepted")
	# The SKIP button cannot take focus (Enter on it would skip by accident).
	var box2 := DialogueBox.open(holder, load(Briefing.RESOURCE), "start", [{"briefing": Briefing.new(ctx)}])
	await _frames()
	var skip: Button = box2.find_child("Skip", true, false)
	_check(skip != null and skip.focus_mode == Control.FOCUS_NONE and skip.text.contains("SKIP"), "SKIP is a mouse button with its key shown (%s)" % (skip.text if skip else ""))
	skip.pressed.emit()
	await _frames()
	_check(not is_instance_valid(box2), "the SKIP button skips too")
	holder.queue_free()
	await _frames()


func _voice_setting_tests() -> void:
	var p := MemoryProfile.new()
	_check(p.dialogue_voice, "dialogue voice is on by default")
	var holder := Control.new()
	root.add_child(holder)
	var panel := SettingsPanel.open(holder, p)
	await _frames()
	panel.call("_show", "AUDIO")
	await _frames()
	var toggle: CheckButton = panel.find_child("Toggle_Dialogue_voice", true, false)
	_check(toggle != null and toggle.button_pressed, "Settings > Audio has Dialogue voice, on")
	var saves: int = p.saves
	toggle.button_pressed = false
	_check(not p.dialogue_voice and p.saves > saves, "turning it off changes the profile and saves it")
	holder.queue_free()
	# Saved and loaded back from disk.
	var real := Profile.new()
	real.dialogue_voice = false
	real.save(PROFILE_PATH)
	_check(not Profile.load_profile(PROFILE_PATH).dialogue_voice, "the setting survives save and load")
	real.dialogue_voice = true
	real.save(PROFILE_PATH)
	_check(Profile.load_profile(PROFILE_PATH).dialogue_voice, "and back on")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PROFILE_PATH))
	# The voice obeys it.
	var voice := DialogueVoice.new()
	root.add_child(voice)
	Profile.current = p
	voice.blip("Director Hale")
	_check(voice.plays == 0, "no blips with the voice off")
	p.dialogue_voice = true
	voice.blip("Director Hale")
	_check(voice.plays == 1, "blips with the voice on")
	_check(DialogueVoice.blip_stream().data.size() > 0, "the blip is synthesised")
	voice.queue_free()
	Profile.current = null
	await _frames()


func _line(dm: Node, cue: String, ctx: RunContext) -> Object:
	return await dm.call("get_next_dialogue_line", load(Briefing.RESOURCE), cue, [{"briefing": Briefing.new(ctx)}])


## The briefing reads the run: Berlenga part, threat, previous island.
func _condition_tests(dm: Node) -> void:
	var b := Briefing.new(RunContext.new(2))
	_check(not b.is_expedition and b.part_index == 0 and b.last_result == "none" and b.threat == 1, "archipelago, first island: no part, no previous result")
	var ids: Array = ["LOAD_BERLENGA_1", "LOAD_BERLENGA_2", "LOAD_BERLENGA_3", "LOAD_BERLENGA_4"]
	for i in 4:
		var ctx := RunContext.new(2)
		ctx.start_expedition(&"berlenga", i)
		var line: Object = await _line(dm, "radio", ctx)
		_check(line != null and String(line.get("static_id")) == ids[i],
			"Berlenga part %d gets its own briefing line" % (i + 1))
	var calm := RunContext.new(2)
	_check(await _line(dm, "radio", calm) == null, "a calm first island has no special line (the screen keeps its tip)")
	var hot := RunContext.new(2)
	hot.threat = 4
	var line: Object = await _line(dm, "radio", hot)
	_check(line != null and String(line.get("text")).contains("Threat 4"), "high threat gets a warning on the loading screen")
	# The intel answer adds a threat warning and the last island's result.
	hot.island_index = 1
	hot.hp = 20.0
	hot.island_log.append({"hp_left": 20, "seconds": 400.0})
	_check(Briefing.new(hot).last_result == "hurt" and Briefing.new(hot).hp_percent == 20, "a rough last island reads as hurt")
	line = await _line(dm, "intel", hot)
	var texts: Array[String] = []
	while line != null and (line.get("responses") as Array).is_empty():
		texts.append(String(line.get("text")))
		line = await dm.call("get_next_dialogue_line", load(Briefing.RESOURCE), String(line.get("next_id")), [{"briefing": Briefing.new(hot)}])
	if line != null:
		texts.append(String(line.get("text")))
	_check(texts.any(func(t: String) -> bool: return t.contains("Threat 4")), "the intel answer warns about threat 4")
	_check(texts.any(func(t: String) -> bool: return t.contains("20 percent")), "the intel answer mentions the last island's HP")
	var fast := RunContext.new(2)
	fast.island_log.append({"hp_left": 90, "seconds": 120.0})
	_check(Briefing.new(fast).last_result == "fast", "a quick, clean island reads as fast")


## Radio lines come from radio.dialogue: stable ids, speakers, translation.
func _radio_data_tests() -> void:
	var ids: Dictionary = {}
	var all_ok: bool = true
	for cue: StringName in Story.RADIO:
		for e: Dictionary in Story.RADIO[cue]:
			all_ok = all_ok and String(e["id"]) != "" and String(e["speaker"]) != "" and String(e["text"]) != ""
			ids[e["id"]] = true
	var count: int = 0
	for cue: StringName in Story.RADIO:
		count += (Story.RADIO[cue] as Array).size()
	_check(all_ok and ids.size() == count, "every radio line has a unique stable id and a speaker (%d lines)" % count)
	_check(Story.RADIO.has(&"tips") and (Story.RADIO[&"tips"] as Array).size() >= 4, "loading tips exist")
	var speakers: Array = []
	for e: Dictionary in Story.RADIO[&"survivor_found"]:
		speakers.append(e["speaker"])
	_check(speakers.has("Surveyor"), "the surveyor speaks on the radio too")
	var rng := RandomNumberGenerator.new()
	var entry: Dictionary = Story.radio_entry(&"generator", rng)
	_check(entry.has("id") and Story.radio_line(&"generator", rng) != "", "radio_entry and radio_line give a line")
	_check(Story.translate({"id": "RADIO_X", "text": "Hello"}) == "Hello", "English is the source when no translation is loaded")
	var pot: PackedStringArray = ProjectSettings.get_setting("internationalization/locale/translations_pot_files", PackedStringArray())
	_check(pot.has(Story.RADIO_RESOURCE) and pot.has("res://game/ui/loading_screen.gd") and pot.has("res://game/ui/dialogue_box.gd"), "the new files are in the POT generation list")


func _portrait_tests() -> void:
	_check(Portrait.look_id("Director Hale") == "hale" and Portrait.look_id("Surveyor") == "surveyor" and Portrait.look_id("Nobody") == "unknown", "each speaker has a look; unknown voices get the static one")
	var p := Portrait.new()
	p.speaker = "Surveyor"
	p.talk()
	_check(p.get("_mouth") > 0.0, "talk() opens the mouth")
	p.free()
