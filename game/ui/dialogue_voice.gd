class_name DialogueVoice
extends AudioStreamPlayer
## The "voice" of typed dialogue: a very short synthesised blip every few
## letters (Typewriter.step), pitched per speaker, like Animal Crossing or
## Undertale. No voice acting needed, and it tells the ear who is talking.
##
## The blip is one AudioStreamWAV built once in code (like Sfx), not an
## AudioStreamGenerator: a 50 ms sound does not need a live audio stream,
## and a prebuilt buffer costs nothing per frame. Settings > Audio >
## "Dialogue voice" (Profile.dialogue_voice) turns it off.

const MIX_RATE: int = 22050
## Speaker -> base pitch (pitch_scale of the blip). Unknown speakers: 1.0.
const PITCH: Dictionary = {
	"Director Hale": 0.8,
	"Surveyor": 1.3,
	"Contractor": 1.0,
}

static var _blip: AudioStreamWAV
var _rng := RandomNumberGenerator.new()
var plays: int = 0  ## blips played (tests)


func _ready() -> void:
	bus = Profile.BUS_SFX
	volume_db = -14.0
	stream = blip_stream()


## True when the profile wants dialogue blips (on by default).
static func enabled() -> bool:
	return Profile.current == null or Profile.current.dialogue_voice


## One blip for `speaker`, with a little pitch wobble so it does not drone.
func blip(speaker: String) -> void:
	if not enabled():
		return
	plays += 1
	if not is_inside_tree() or DisplayServer.get_name() == "headless":
		return
	pitch_scale = float(PITCH.get(speaker, 1.0)) * _rng.randf_range(0.93, 1.07)
	play()


## 50 ms of a soft square-ish tone (fundamental + odd harmonics) with a
## fast attack and decay: reads as a syllable, not a beep.
static func blip_stream() -> AudioStreamWAV:
	if _blip != null:
		return _blip
	var seconds: float = 0.05
	var n: int = int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var freq: float = 330.0
	for i in n:
		var t: float = float(i) / MIX_RATE
		var env: float = minf(1.0, t * 600.0) * exp(-t * 55.0)
		var ph: float = TAU * freq * t
		var s: float = sin(ph) + sin(ph * 3.0) * 0.3 + sin(ph * 5.0) * 0.12
		data.encode_s16(i * 2, int(clampf(s * env * 0.45, -1.0, 1.0) * 32767.0))
	_blip = AudioStreamWAV.new()
	_blip.format = AudioStreamWAV.FORMAT_16_BITS
	_blip.mix_rate = MIX_RATE
	_blip.stereo = false
	_blip.data = data
	return _blip
