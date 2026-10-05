class_name Sfx
extends Node
## Sound effects synthesised in code (no audio assets): each sound is a short
## PCM buffer built from noise, sine sweeps and an envelope, wrapped in an
## AudioStreamWAV. A small pool of players avoids cutting sounds off, and a
## per-sound cooldown stops 50 kills in one frame from making 50 pops.

const MIX_RATE: int = 22050
const PACK: String = "res://assets/audio/ovani_sfx_starter_vol1/"

## Recorded sounds from the Ovani pack (see assets/LICENSES.md) that replace
## the synthesised ones. Missing files fall back to synthesis, so the game
## never breaks if the pack is trimmed.
const FILES: Dictionary = {
	&"pistol": "Hollywood/Titan Handgun.wav",
	&"marksman": "Sci-Fi/Pulse Sniper.wav",
	&"explosion": "Hollywood/Mega Bomb.wav",
	&"breaker": "Motions and Impacts/Swoosh Thunder.wav",
	&"hurt": "Hollywood/Deathpunch.wav",
	&"level_up": "Jingles & Stingers/Level Up.wav",
	&"generator": "Jingles & Stingers/Milestone.wav",
	&"scream": "Horror/It Laughs At You.wav",
	&"slam_warn": "Hollywood/Earthquake Loop.wav",
	&"slam_hit": "Motions and Impacts/Impact Axe Fall.wav",
	&"cache": "Hollywood/Wooden Crate Destruction.wav",
	&"survivor": "Jingles & Stingers/Area Discovered.wav",
	&"success": "Jingles & Stingers/Success.wav",
	&"game_over": "Jingles & Stingers/Game Over.wav",
	&"low_hp": "Jingles & Stingers/Health Low.wav",
	&"ui_hover": "UI & Menus/Hover Over.wav",
	&"ui_select": "UI & Menus/Select.wav",
	&"ui_start": "UI & Menus/Start.wav",
}

## Looping ambience per biome (and the menus).
const AMBIENCE: Dictionary = {
	&"beach": "Environment/Ocean Loop.wav",
	&"jungle": "Environment/Rain Forest Loop.wav",
	&"town": "Environment/Wind Loop.wav",
	&"port": "Environment/Wind Loop.wav",
	&"volcano": "Hollywood/Earthquake Loop.wav",
	&"menu": "Environment/Ocean Loop.wav",
}
const POOL_SIZE: int = 16

## Generated once and shared by every island.
static var _streams: Dictionary = {}

var _players: Array[AudioStreamPlayer] = []
var _next: int = 0
var _last_played: Dictionary = {}  ## name -> msec


func _ready() -> void:
	if _streams.is_empty():
		_build_all()
		_load_recorded()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = Profile.BUS_SFX
		add_child(p)
		_players.append(p)


## Plays a sound. min_gap_ms limits how often the same sound can start.
func play(sound: StringName, volume_db: float = 0.0, pitch_jitter: float = 0.08, min_gap_ms: int = 30) -> void:
	if not _streams.has(sound):
		return
	var now: int = Time.get_ticks_msec()
	if now - int(_last_played.get(sound, -100000)) < min_gap_ms:
		return
	_last_played[sound] = now
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = volume_db
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Replaces synthesised sounds with recorded ones where the file exists.
static func _load_recorded() -> void:
	for key: StringName in FILES:
		var path: String = PACK + String(FILES[key])
		if ResourceLoader.exists(path):
			var s: AudioStream = load(path)
			if s != null:
				_streams[key] = s


static func ambience_stream(key: StringName) -> AudioStream:
	var path: String = PACK + String(AMBIENCE.get(key, AMBIENCE[&"menu"]))
	return load(path) if ResourceLoader.exists(path) else null


static func _build_all() -> void:
	# Gunshots: a noise crack with a fast decay; heavier guns are longer and lower.
	_streams[&"rifle"] = _make(0.09, 0.0, 0.0, 1.0, 40.0, 0.35)
	_streams[&"shotgun"] = _make(0.28, 90.0, 50.0, 1.0, 14.0, 0.6)
	_streams[&"pistol"] = _make(0.2, 140.0, 60.0, 0.8, 18.0, 0.5)
	_streams[&"hit"] = _make(0.05, 900.0, 600.0, 0.3, 60.0, 0.0)
	_streams[&"kill"] = _make(0.12, 300.0, 90.0, 0.6, 25.0, 0.4)
	_streams[&"headshot"] = _make(0.1, 1400.0, 700.0, 0.4, 30.0, 0.0)
	_streams[&"breaker"] = _make(0.35, 70.0, 220.0, 0.5, 6.0, 0.5)
	_streams[&"explosion"] = _make(0.9, 60.0, 25.0, 1.0, 4.5, 0.7)
	_streams[&"hurt"] = _make(0.18, 220.0, 110.0, 0.2, 15.0, 0.0)
	_streams[&"pickup"] = _make(0.07, 880.0, 1320.0, 0.0, 30.0, 0.0)
	_streams[&"level_up"] = _make_chord([523.25, 659.25, 783.99, 1046.5], 0.5)
	_streams[&"generator"] = _make_chord([392.0, 587.33, 783.99], 0.6)
	_streams[&"scream"] = _make(0.8, 500.0, 1400.0, 0.35, 2.5, 0.0)
	_streams[&"slam_warn"] = _make(0.5, 55.0, 110.0, 0.2, 2.0, 0.0)


## One sound: a sine sweep (freq_from -> freq_to) mixed with white noise,
## shaped by an exponential decay. `body` adds a low thump for weight.
static func _make(seconds: float, freq_from: float, freq_to: float, noise: float, decay: float, body: float) -> AudioStreamWAV:
	var n: int = int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	var thump_phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = int(freq_from * 13.0 + seconds * 1000.0)
	for i in n:
		var t: float = float(i) / MIX_RATE
		var k: float = t / seconds
		var env: float = exp(-decay * t) * minf(1.0, t * 800.0)  # 1 ms attack avoids clicks
		var freq: float = lerpf(freq_from, freq_to, k)
		phase += TAU * freq / MIX_RATE
		thump_phase += TAU * lerpf(110.0, 40.0, k) / MIX_RATE
		var tone: float = sin(phase) * (1.0 - noise) if freq_from > 0.0 else 0.0
		var sample: float = tone + rng.randf_range(-1.0, 1.0) * noise + sin(thump_phase) * body * exp(-12.0 * t)
		data.encode_s16(i * 2, int(clampf(sample * env * 0.6, -1.0, 1.0) * 32767.0))
	return _wav(data)


## A short arpeggio of sine notes (for rewards).
static func _make_chord(freqs: Array, seconds: float) -> AudioStreamWAV:
	var n: int = int(seconds * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var step: float = seconds / (freqs.size() + 1)
	for i in n:
		var t: float = float(i) / MIX_RATE
		var sample: float = 0.0
		for j in freqs.size():
			var start: float = j * step
			if t >= start:
				var lt: float = t - start
				sample += sin(TAU * float(freqs[j]) * lt) * exp(-5.0 * lt) * minf(1.0, lt * 400.0)
		data.encode_s16(i * 2, int(clampf(sample * 0.25, -1.0, 1.0) * 32767.0))
	return _wav(data)


static func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MIX_RATE
	w.stereo = false
	w.data = data
	return w
