class_name Typewriter
extends RefCounted
## Reveals a Label's or RichTextLabel's text letter by letter (dialogue box,
## HUD radio). The owner calls step(delta) every frame; step returns true
## when a voice blip is due (every BLIP_EVERY letters, spaces and punctuation
## do not count), so the sound stays in the owner and the reveal stays
## testable without audio. complete() shows the whole line at once.
##
## Why visible_characters and not visible_ratio: it counts letters, so the
## speed is the same for short and long lines, and bbcode tags in a
## RichTextLabel ([i]...) are not "typed".

const CHARS_PER_SECOND: float = 48.0
const BLIP_EVERY: int = 3
## Extra pause after . ! ? (in letters' worth of time): reads more naturally.
const STOP_PAUSE: float = 6.0

var speed: float = CHARS_PER_SECOND
var _label: Control
var _plain: String = ""
var _shown: float = 0.0
var _letters: int = 0  ## letters (not spaces) revealed since the last blip


## Starts typing `text` into `label` (Label or RichTextLabel).
func start(label: Control, text: String) -> void:
	_label = label
	label.set("text", text)
	_plain = _strip_tags(text) if label is RichTextLabel else text
	_shown = 0.0
	_letters = 0
	label.set("visible_characters", 0)


## Advances the reveal; true when a voice blip should play now.
func step(delta: float) -> bool:
	if _label == null or is_done():
		return false
	var before: int = int(_shown)
	var rate: float = speed
	if before > 0 and before <= _plain.length() and ".!?".contains(_plain[before - 1]):
		rate = speed / STOP_PAUSE  # hold briefly at the end of a sentence
	_shown = minf(float(_plain.length()), _shown + delta * rate)
	var now: int = int(_shown)
	_label.set("visible_characters", -1 if now >= _plain.length() else now)
	var blip: bool = false
	for i in range(before, now):
		var ch: String = _plain[i]
		if ch != " " and not ".,!?;:'\"-—…".contains(ch):
			_letters += 1
			if _letters >= BLIP_EVERY:
				_letters = 0
				blip = true
	return blip


## Shows the whole line now.
func complete() -> void:
	if _label == null:
		return
	_shown = float(_plain.length())
	_label.set("visible_characters", -1)


func is_done() -> bool:
	return _label == null or int(_shown) >= _plain.length()


## Letters shown so far (tests).
func shown() -> int:
	return int(_shown)


## Text without bbcode tags: what a RichTextLabel counts as characters.
static func _strip_tags(text: String) -> String:
	var re := RegEx.create_from_string("\\[[^\\]]*\\]")
	return re.sub(text, "", true)
