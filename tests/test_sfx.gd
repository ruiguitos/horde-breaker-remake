extends SceneTree
## The synthesised sounds exist, have sane length and are neither silent nor clipping.
## Run: godot --headless --path . --script res://tests/test_sfx.gd


func _initialize() -> void:
	Sfx._build_all()
	var failures: int = 0
	if Sfx._streams.size() < 10:
		print("TEST FAIL: expected the sound bank to be built")
		failures += 1
	for sound in Sfx._streams:
		var w: AudioStreamWAV = Sfx._streams[sound]
		var n: int = w.data.size() / 2
		var peak: int = 0
		var clipped: int = 0
		for i in n:
			var v: int = absi(w.data.decode_s16(i * 2))
			peak = maxi(peak, v)
			if v >= 32767:
				clipped += 1
		var secs: float = float(n) / Sfx.MIX_RATE
		var ok: bool = secs > 0.03 and secs < 1.5 and peak > 3000 and clipped < n / 100
		print("%s %s: %.2f s, peak %d, clipped %d" % ["TEST:" if ok else "TEST FAIL:", sound, secs, peak, clipped])
		if not ok:
			failures += 1
	for combat in [false, true]:
		var m: AudioStreamWAV = Music._build(combat)
		var secs: float = float(m.data.size() / 2) / Music.MIX_RATE
		var peak: int = 0
		for i in range(0, m.data.size() / 2, 7):
			peak = maxi(peak, absi(m.data.decode_s16(i * 2)))
		var ok: bool = absf(secs - 8.0) < 0.01 and m.loop_mode == AudioStreamWAV.LOOP_FORWARD and peak > 3000 and peak < 32767
		print("%s music loop (combat=%s): %.2f s, peak %d" % ["TEST:" if ok else "TEST FAIL:", combat, secs, peak])
		if not ok:
			failures += 1
	quit(1 if failures > 0 else 0)
