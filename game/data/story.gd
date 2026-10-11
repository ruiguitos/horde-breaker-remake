class_name Story
extends RefCounted
## Story content: the radio voice of Salvage & Co. and the recovered Intel
## files that slowly explain what happened on the archipelago. Text only, so
## writers can edit it without touching gameplay code: the radio lines and
## loading tips live in RADIO_RESOURCE, the Intel files here.

const SPEAKER: String = "Director Hale — Salvage & Co."

## Radio lines per event (cue -> [{id, speaker, text}]), read from
## RADIO_RESOURCE. It uses Dialogue Manager's format so every line has a
## stable [ID:] and Godot's POT generation finds it; it is read here as
## plain data (no choices, no conditions), so the HUD gets it at once.
const RADIO_RESOURCE: String = "res://game/data/dialogue/radio.dialogue"
static var RADIO: Dictionary = _load_cues(RADIO_RESOURCE)

## Intel files, unlocked in order (caches and bosses recover them).
const FILES: Array[Dictionary] = [
	{"title": "Memo 01 — Acquisition", "text": "Salvage & Co. has acquired the Halvard Archipelago research leases at a very reasonable price. The previous tenants left in a hurry. Their equipment did not."},
	{"title": "Survey Log — Dawn Beach", "text": "Day 3. The locals don't talk. They don't sleep either. They just walk towards the generators when we switch them on."},
	{"title": "Lab Note — Project TIDE", "text": "TIDE reacts to electricity. The specimens follow the current like moths. We are told this is 'a feature'."},
	{"title": "Email — Re: Re: Containment", "text": "Containment failed at 03:12. Please stop replying-all with screaming."},
	{"title": "Field Report — The Big One", "text": "Something on the volcano is eating the others and getting bigger. We are calling it the Behemoth because 'Gary' was voted down."},
	{"title": "Memo 02 — Contractors", "text": "Effective immediately, the recovery of data from the archipelago will be outsourced to contractors. Contractors are cheaper than staff, and easier to replace."},
	{"title": "Audio Transcript — Uplink", "text": "If anyone gets this: the generators aren't for the lights. They're for the signal. The signal is what keeps them... calm. Don't let it go dark."},
	{"title": "Personal Note — Dr. Ines Varga", "text": "I am the last surveyor. I've hidden the core logs where only someone stupid enough to come here would find them. Hale, if this is you: you knew."},
	{"title": "Memo 03 — Discretion", "text": "Any contractor who reads Dr. Varga's notes is to be offered a promotion. Please do not ask what the promotion involves."},
	{"title": "Core Log — Origin", "text": "TIDE did not escape. It was released. The archipelago is a test site, and Salvage & Co. is the client. The test is you."},
]


## Text of a random line for radio event `key` ("" when none).
static func radio_line(key: StringName, rng: RandomNumberGenerator) -> String:
	return String(radio_entry(key, rng).get("text", ""))


## A random line of event `key`: {id, speaker, text}, the text already
## translated ({} when the event has no lines).
static func radio_entry(key: StringName, rng: RandomNumberGenerator) -> Dictionary:
	var lines: Array = RADIO.get(key, [])
	if lines.is_empty():
		return {}
	var entry: Dictionary = (lines[rng.randi_range(0, lines.size() - 1)] as Dictionary).duplicate()
	entry["text"] = translate(entry)
	return entry


## A line's text the way Dialogue Manager translates it (the stable id is
## the key, context "dialogue"); the English source when no translation is
## loaded or the id is missing from it.
static func translate(entry: Dictionary) -> String:
	var text: String = String(entry.get("text", ""))
	var id: String = String(entry.get("id", ""))
	if id == "" or TranslationServer.get_loaded_locales().is_empty():
		return text
	var out: String = String(TranslationServer.translate(StringName(id), &"dialogue"))
	return text if out == id else out


## Every cue of a .dialogue file as plain lines, cue -> [{id, speaker,
## text}], following each cue until it ends.
static func _load_cues(path: String) -> Dictionary:
	var out: Dictionary = {}
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	if res == null:
		push_warning("Story: cannot load " + path)
		return out
	var cues: Dictionary = res.get("cues")
	var lines: Dictionary = res.get("lines")
	for cue: String in cues:
		var list: Array[Dictionary] = []
		var id: String = String(cues[cue])
		while lines.has(id):
			var line: Dictionary = lines[id]
			var kind: String = String(line.get("type", ""))
			if kind == "dialogue":
				list.append({"id": String(line.get("static_id", "")), "speaker": String(line.get("character", "")),
					"text": String(line.get("text", ""))})
			elif kind != "cue":
				break
			id = String(line.get("next_id", ""))
		out[StringName(cue)] = list
	return out


