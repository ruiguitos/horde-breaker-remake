class_name Story
extends RefCounted
## Story content: the radio voice of Salvage & Co. and the recovered Intel
## files that slowly explain what happened on the archipelago. Text only, so
## writers can edit it here without touching gameplay code.

const SPEAKER: String = "Director Hale — Salvage & Co."

## Radio lines per event. One is picked at random each time.
const RADIO: Dictionary = {
	&"land_activate": [
		"Three generators, contractor. Turn them on, don't turn into one of them.",
		"Power's out on this rock. Fix that. Overtime is not authorised.",
	],
	&"land_defend": [
		"The uplink needs seventy-five seconds of uninterrupted transmission. Interrupt nothing.",
		"Plant yourself in the antenna zone. Think of it as a very aggressive meeting.",
	],
	&"land_rescue": [
		"One of our surveyors is still alive. Probably. Bring them back, they owe us a report.",
		"Survivor signal detected. Retrieval is billable, so let's do it right.",
	],
	&"land_boss": [
		"Thermal readings on the volcano are... large. Do the job, then leave before it notices.",
	],
	&"generator": [
		"Generator online. Accounting thanks you.",
		"That's one. The other two won't switch themselves on.",
		"Power restored. Try not to stand in it.",
	],
	&"objective_done": [
		"Objective complete. Get to the boat, the meter's running.",
		"Good work. Now leave, quickly, with all your limbs.",
	],
	&"survivor_found": [
		"Survivor located. Keep them breathing, the paperwork for the other outcome is awful.",
	],
	&"survivor_lost": [
		"Survivor lost. I'll file it under 'acceptable'. You won't.",
	],
	&"boss": [
		"That is the Behemoth. Company policy is: shoot it until it stops.",
		"Large specimen inbound. Its rocks are not covered by your insurance.",
	],
	&"boss_down": [
		"Behemoth down. Legal says we can now call this a 'successful outcome'.",
	],
	&"low_hp": [
		"Your vitals are trending towards 'former employee'.",
		"Medical says you're leaking. Stop that.",
	],
	&"screamer": [
		"That noise was a Screamer. Everything heard it. Everything.",
	],
	&"cache": [
		"Supply cache cracked. Look, free stuff. Don't get used to it.",
	],
	&"extract": [
		"On the boat. Nicely done, contractor.",
	],
}

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


static func radio_line(key: StringName, rng: RandomNumberGenerator) -> String:
	var lines: Array = RADIO.get(key, [])
	if lines.is_empty():
		return ""
	return lines[rng.randi_range(0, lines.size() - 1)]
