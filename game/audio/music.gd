class_name Music
extends Node
## Adaptive music synthesised in code. Two loops of the same length, key and
## tempo play together; their volumes crossfade with the director's phase
## (relax -> calm loop, peak -> combat loop), so the soundtrack follows the
## horde without hard cuts.

const MIX_RATE: int = 22050
const BPM: float = 120.0
const BARS: int = 4
const ROOT_HZ: float = 55.0  ## A1

static var _calm: AudioStreamWAV
static var _combat: AudioStreamWAV

var intensity: float = 0.0  ## 0 = calm, 1 = full combat (smoothed)

var _calm_player := AudioStreamPlayer.new()
var _combat_player := AudioStreamPlayer.new()


func _ready() -> void:
	if _calm == null:
		_calm = _build(false)
		_combat = _build(true)
	_calm_player.stream = _calm
	_combat_player.stream = _combat
	add_child(_calm_player)
	add_child(_combat_player)
	_calm_player.play()
	_combat_player.play()
	_apply()


## Moves the mix towards `target` (0..1) at a fixed rate per second.
func update_mix(target: float, delta: float) -> void:
	intensity = move_toward(intensity, clampf(target, 0.0, 1.0), delta * 0.5)
	_apply()


func _apply() -> void:
	_calm_player.volume_db = linear_to_db(maxf(0.001, 0.55 * (1.0 - intensity * 0.7)))
	_combat_player.volume_db = linear_to_db(maxf(0.001, 0.6 * intensity))


static func _build(combat: bool) -> AudioStreamWAV:
	var beat: float = 60.0 / BPM
	var seconds: float = beat * 4.0 * BARS
	var n: int = int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 if combat else 7
	# A minor chord tones over the root for the pad; the bass walks A-A-F-G.
	var pad: Array[float] = [1.0, 1.5, 2.0, 2.378]
	var bass_line: Array[float] = [1.0, 1.0, 0.794, 0.891]
	for i in n:
		var t: float = float(i) / MIX_RATE
		var bar: int = int(t / (beat * 4.0)) % BARS
		var in_beat: float = fmod(t, beat)
		var sample: float = 0.0
		# Pad: slow-breathing sine chord (both loops share it, so the crossfade is seamless).
		var breath: float = 0.6 + 0.4 * sin(TAU * t / seconds)
		for p in pad:
			sample += sin(TAU * ROOT_HZ * 2.0 * p * t) * 0.07 * breath
		sample += sin(TAU * ROOT_HZ * t) * 0.12
		if combat:
			# Kick on every beat: a sine that drops in pitch, with a fast decay.
			var kf: float = lerpf(120.0, 45.0, minf(1.0, in_beat * 12.0))
			sample += sin(TAU * kf * in_beat) * exp(-in_beat * 14.0) * 0.55
			# Pulsing bass on eighth notes.
			var eighth: float = fmod(t, beat * 0.5)
			sample += sin(TAU * ROOT_HZ * bass_line[bar] * t) * exp(-eighth * 6.0) * 0.3
			# Hi-hat: short noise on the off-beats.
			var off: float = fmod(t + beat * 0.5, beat)
			sample += rng.randf_range(-1.0, 1.0) * exp(-off * 60.0) * 0.12
		data.encode_s16(i * 2, int(clampf(sample, -1.0, 1.0) * 32767.0 * 0.8))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w
