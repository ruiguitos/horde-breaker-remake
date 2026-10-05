extends SceneTree
## Headless tests for the horde director spike.
## Run: godot --headless --path . --script res://spikes/director/tests/test_director.gd

var _failures := 0


func _check(ok: bool, msg: String) -> void:
	if ok:
		print("TEST: ", msg)
	else:
		print("TEST FAIL: ", msg)
		_failures += 1


func _initialize() -> void:
	var DirectorSim: GDScript = load("res://spikes/director/director_sim.gd")
	var sims := {}
	for profile: String in ["weak", "medium", "strong"]:
		var sim: RefCounted = DirectorSim.new()
		sim.run("l4d", profile)
		sims[profile] = sim

	for profile: String in sims:
		var sim: RefCounted = sims[profile]
		var seen: Array[String] = sim.phases_seen()
		_check(seen.has("build_up") and seen.has("peak") and seen.has("relax"),
			"%s: all three phases occur %s" % [profile, seen])
		var changes := 0
		var rows: Array[Dictionary] = sim.rows
		for i in range(1, rows.size()):
			if rows[i]["phase"] != rows[i - 1]["phase"]:
				changes += 1
		_check(changes >= 9, "%s: phases alternate (%d changes, >= 3 full cycles)" % [profile, changes])
		var over := 0
		for r in rows:
			if int(r["active"]) > int(r["budget"]):
				over += 1
		_check(sim.budget_violations == 0 and over == 0,
			"%s: active never exceeds budget (tick violations %d, row violations %d)" % [profile, sim.budget_violations, over])

	var weak: Dictionary = sims["weak"].summary
	var strong: Dictionary = sims["strong"].summary
	_check(weak["relax_count"] > strong["relax_count"],
		"weak gets more relax periods (%d) than strong (%d)" % [weak["relax_count"], strong["relax_count"]])
	_check(weak["relax_s"] > strong["relax_s"],
		"weak gets more relax time (%d s) than strong (%d s)" % [weak["relax_s"], strong["relax_s"]])

	var legacy: RefCounted = DirectorSim.new()
	legacy.run("legacy", "medium")
	_check(legacy.summary["max_active"] <= 90, "legacy director respects cap 90 (max %d)" % legacy.summary["max_active"])

	quit(1 if _failures > 0 else 0)
