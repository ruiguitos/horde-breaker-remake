extends SceneTree
## Runs both directors x 3 profiles, writes CSVs to spikes/director/output/
## and prints summary tables + ASCII charts (per-minute averages).
## Run: godot --headless --path . --script res://spikes/director/run_simulation.gd

const DirectorSim := preload("res://spikes/director/director_sim.gd")
const OUT_DIR := "res://spikes/director/output/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var t0 := Time.get_ticks_msec()
	print("| director | profile | relax periods | relax s | calm s (0 near) | avg active | max active | avg intensity | deaths |")
	print("|---|---|---|---|---|---|---|---|---|")
	var charts: PackedStringArray = []
	for kind: String in ["l4d", "legacy"]:
		for profile: String in DirectorSim.PROFILES:
			var res := DirectorSim.run(kind, profile)
			var rows: Array[Dictionary] = res.rows
			var f := FileAccess.open(OUT_DIR + "%s_%s.csv" % [kind, profile], FileAccess.WRITE)
			if f == null:
				print("TEST FAIL: cannot write CSV")
				quit(1)
				return
			f.store_string(DirectorSim.to_csv(rows))
			f.close()
			var sum_a := 0.0
			var max_a := 0
			var sum_i := 0.0
			var calm := 0.0
			for r in rows:
				sum_a += r.active
				max_a = maxi(max_a, r.active)
				sum_i += r.intensity
				if r.near == 0:
					calm += DirectorSim.DT
			print("| %s | %s | %d | %.0f | %.0f | %.1f | %d | %.1f | %d |" % [kind, profile,
				res.director.relax_count, res.director.relax_time, calm, sum_a / rows.size(),
				max_a, sum_i / rows.size(), res.player.deaths])
			charts.append(_chart(kind, profile, rows))
	for c in charts:
		print(c)
	print("elapsed: %d ms" % (Time.get_ticks_msec() - t0))
	quit(0)


## One line per minute: active bar (#) and intensity bar (*), plus dominant phase.
func _chart(kind: String, profile: String, rows: Array[Dictionary]) -> String:
	var per_min := int(60.0 / DirectorSim.DT)
	var lines: PackedStringArray = ["\n%s / %s  (# = 10 active, * = 10 intensity; phase = most frequent)" % [kind, profile]]
	for m in rows.size() / per_min:
		var a := 0.0
		var i := 0.0
		var phases := {}
		for k in per_min:
			var r: Dictionary = rows[m * per_min + k]
			a += r.active
			i += r.intensity
			phases[r.phase] = int(phases.get(r.phase, 0)) + 1
		a /= per_min
		i /= per_min
		var top := ""
		for ph: String in phases:
			if top == "" or phases[ph] > phases[top]:
				top = ph
		lines.append("%2d %-9s %-16s|%-10s %3d/%2d" % [m, top, "#".repeat(roundi(a / 10.0)),
			"*".repeat(roundi(i / 10.0)), roundi(a), roundi(i)])
	return "\n".join(lines)
