extends RefCounted
## Runs one 25-minute simulation (director + simulated player) and collects
## one row per second plus a summary. Pure logic, no scene, deterministic seed.

const SimPlayer := preload("res://spikes/director/sim_player.gd")
const HordeDirector := preload("res://spikes/director/horde_director.gd")
const LegacyDirector := preload("res://spikes/director/legacy_director.gd")

const PROFILES := {"weak": 0.6, "medium": 1.0, "strong": 1.5}
const RUN_LENGTH := 1500.0
const DT := 0.25

var rows: Array[Dictionary] = []
var summary := {}
var budget_violations := 0


## kind: "l4d" or "legacy".
func run(kind: String, profile: String, seed_value: int = 7) -> void:
	var director: RefCounted
	if kind == "legacy":
		director = LegacyDirector.new(seed_value)
	else:
		director = HordeDirector.new(seed_value)
	var player := SimPlayer.new(PROFILES[profile], seed_value + 1)
	var t := 0.0
	var spawns_second := 0
	var events: Array[String] = []
	var last_damage := 0.0
	var phase_seconds := {}
	var calm_seconds := 0.0
	var intensity_sum := 0.0
	var max_active := 0
	var total_spawns := 0
	var steps_per_row := int(1.0 / DT)
	var step_i := 0
	while t < RUN_LENGTH:
		var spawns: Array[int] = director.update(t, DT, player.active(), player.engaged(), last_damage)
		if player.active() + spawns.size() > director.budget(t):
			budget_violations += 1
		player.add(spawns)
		spawns_second += spawns.size()
		total_spawns += spawns.size()
		if director.event != "":
			events.append(director.event)
		last_damage = player.step(DT, t / RUN_LENGTH)
		max_active = maxi(max_active, player.active())
		var ph: String = director.phase_name()
		if kind == "legacy":
			ph = "escalate"
		phase_seconds[ph] = phase_seconds.get(ph, 0.0) + DT
		if player.near_count() == 0:
			calm_seconds += DT
		intensity_sum += director.intensity * DT
		t += DT
		step_i += 1
		if step_i % steps_per_row == 0:
			rows.append({
				"time": int(round(t)),
				"intensity": snappedf(director.intensity, 0.1),
				"phase": director.phase_name(),
				"active": player.active(),
				"near": player.near_count(),
				"budget": director.budget(t),
				"spawns": spawns_second,
				"hp": snappedf(player.hp, 0.1),
				"kills": player.kills,
				"deaths": player.deaths,
				"event": "|".join(events),
			})
			spawns_second = 0
			events.clear()
	summary = {
		"director": kind,
		"profile": profile,
		"mean_intensity": snappedf(intensity_sum / RUN_LENGTH, 0.1),
		"relax_count": director.relax_count,
		"relax_s": phase_seconds.get("relax", 0.0),
		"peak_s": phase_seconds.get("peak", 0.0),
		"calm_s": calm_seconds,
		"damage": snappedf(player.damage_total, 1.0),
		"deaths": player.deaths,
		"kills": player.kills,
		"spawns": total_spawns,
		"max_active": max_active,
	}


func phases_seen() -> Array[String]:
	var seen: Array[String] = []
	for r in rows:
		if not seen.has(r["phase"]):
			seen.append(r["phase"])
	return seen


func write_csv(path: String) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	var keys: Array = rows[0].keys()
	f.store_line(",".join(keys))
	for r in rows:
		var vals: PackedStringArray = []
		for k in keys:
			vals.append(str(r[k]))
		f.store_line(",".join(vals))
	f.close()
	return OK


## One character per bucket of `bucket_s` seconds: mean of `field` mapped to
## " .:-=+*#%@" over [0, max_value].
func sparkline(field: String, max_value: float, bucket_s: int = 30) -> String:
	const RAMP := " .:-=+*#%@"
	var out := ""
	var i := 0
	while i < rows.size():
		var s := 0.0
		var n := 0
		for j in range(i, mini(i + bucket_s, rows.size())):
			s += float(rows[j][field])
			n += 1
		var v := clampf(s / n / max_value, 0.0, 0.999)
		out += RAMP[int(v * RAMP.length())]
		i += bucket_s
	return out


## Same idea for phases: B(uild), P(eak), R(elax) by majority in the bucket.
func phase_strip(bucket_s: int = 30) -> String:
	var out := ""
	var i := 0
	while i < rows.size():
		var counts := {}
		for j in range(i, mini(i + bucket_s, rows.size())):
			var p: String = rows[j]["phase"]
			counts[p] = counts.get(p, 0) + 1
		var best := ""
		for p: String in counts:
			if best == "" or counts[p] > counts[best]:
				best = p
		out += best.substr(0, 1).to_upper() if not best.begins_with("level") else str(int(best.substr(6)) % 10)
		i += bucket_s
	return out
