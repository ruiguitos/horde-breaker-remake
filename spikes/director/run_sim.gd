extends SceneTree
## Runs the 25-minute simulation for 3 player profiles x 2 directors,
## writes CSVs to spikes/director/output/ and prints summaries + ASCII charts.
## Run: godot --headless --path . --script res://spikes/director/run_sim.gd


func _initialize() -> void:
	var DirectorSim: GDScript = load("res://spikes/director/director_sim.gd")
	var out_dir := "res://spikes/director/output"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var summaries: Array[Dictionary] = []
	for kind: String in ["l4d", "legacy"]:
		print("\n== director: %s (one char = 30 s) ==" % kind)
		for profile: String in ["weak", "medium", "strong"]:
			var sim: RefCounted = DirectorSim.new()
			var t0 := Time.get_ticks_msec()
			sim.run(kind, profile)
			var ms := Time.get_ticks_msec() - t0
			var path := "%s/%s_%s.csv" % [out_dir, kind, profile]
			if sim.write_csv(path) != OK:
				print("FAIL: could not write ", path)
				quit(1)
				return
			summaries.append(sim.summary)
			print("%-6s phase     |%s|" % [profile, sim.phase_strip()])
			if kind == "l4d":
				print("%-6s intensity |%s|" % [profile, sim.sparkline("intensity", 100.0)])
			print("%-6s active    |%s|" % [profile, sim.sparkline("active", 150.0)])
			print("%-6s near      |%s|" % [profile, sim.sparkline("near", 30.0)])
			print("%-6s hp        |%s|   (sim %d ms)" % [profile, sim.sparkline("hp", 100.0), ms])
	print("\n| director | profile | mean I | relax n | relax s | peak s | calm s | damage | deaths | kills | spawns | max active |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|")
	for s in summaries:
		print("| %s | %s | %s | %d | %d | %d | %d | %d | %d | %d | %d | %d |" % [
			s["director"], s["profile"], s["mean_intensity"], s["relax_count"],
			int(s["relax_s"]), int(s["peak_s"]), int(s["calm_s"]), int(s["damage"]),
			s["deaths"], s["kills"], s["spawns"], s["max_active"]])
	quit(0)
