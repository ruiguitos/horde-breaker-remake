extends SceneTree
## Run: godot --headless --path . --script res://spikes/director/tests/test_director.gd

const DirectorSim := preload("res://spikes/director/director_sim.gd")


func _initialize() -> void:
	var failures := 0
	var results := {}
	for profile: String in DirectorSim.PROFILES:
		results[profile] = DirectorSim.run("l4d", profile)

	# 1. Phases alternate: every profile visits all three phases, in order, many times.
	for profile: String in results:
		var rows: Array[Dictionary] = results[profile].rows
		var seq: PackedStringArray = []
		for r in rows:
			if seq.is_empty() or seq[-1] != r.phase:
				seq.append(r.phase)
		var bad_order := false
		var next_of := {"build_up": "peak", "peak": "relax", "relax": "build_up"}
		for i in range(1, seq.size()):
			if next_of[seq[i - 1]] != seq[i]:
				bad_order = true
		if bad_order or results[profile].director.relax_count < 5:
			print("TEST FAIL: phases do not alternate for %s (%d transitions)" % [profile, seq.size()])
			failures += 1
		else:
			print("TEST: phases alternate for %s (%d relax periods)" % [profile, results[profile].director.relax_count])

	# 2. Budget is never exceeded and stays within 80..150.
	for profile: String in results:
		var over := 0
		for r: Dictionary in results[profile].rows:
			if r.active > r.budget or r.budget < 80 or r.budget > 150:
				over += 1
		if over > 0:
			print("TEST FAIL: budget exceeded %d times for %s" % [over, profile])
			failures += 1
		else:
			print("TEST: budget respected for %s" % profile)

	# 3. Weak player gets more relief than strong.
	var weak = results.weak.director
	var strong = results.strong.director
	if weak.relax_count > strong.relax_count:
		print("TEST: weak gets more relief (%d vs %d periods)" % [weak.relax_count, strong.relax_count])
	else:
		print("TEST FAIL: weak %d relax periods <= strong %d" % [weak.relax_count, strong.relax_count])
		failures += 1

	# 4. Legacy director never exceeds its cap of 90.
	var legacy := DirectorSim.run("legacy", "medium")
	var max_active := 0
	for r: Dictionary in legacy.rows:
		max_active = maxi(max_active, r.active)
	if max_active > 90:
		print("TEST FAIL: legacy exceeded cap (%d)" % max_active)
		failures += 1
	else:
		print("TEST: legacy cap respected (max %d)" % max_active)

	quit(1 if failures > 0 else 0)
