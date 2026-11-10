extends SceneTree
## EXFIL mode (DEV sandbox): no mission, the spawn target climbs in steps of 90 s (150 to 250, under
## the 300 cap) with the specials at the same pace and no relief, the clock runs on the HUD, the
## extraction (the exfil point) opens at 600 s and ends the run as an extraction, dying ends it, and the
## island log records the mode and the seconds survived. The Expedition path is not touched.
## Run: godot --headless --path . --script res://tests/test_exfil.gd

var _failures: int = 0
var _checks: int = 0


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("TEST: " + what)
	else:
		_failures += 1
		print("TEST FAIL: " + what)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_director_steps()
	_test_real_spawns_follow_the_steps()
	_test_no_mission()
	_test_beacon_and_extraction()
	_test_death_ends_exfil()
	_test_sandbox_and_log()
	_test_rules_around_the_run()
	await _test_sandbox_form()
	print("TEST: exfil %d checks / %d failures" % [_checks, _failures])
	await create_timer(0.3).timeout
	quit(1 if _failures > 0 else 0)


## A run in EXFIL mode on a generated island, its point at the boat (the scene's ExfilPoint is in test_exfil_map).
func _exfil_run() -> IslandRun:
	var ctx := RunContext.new(5)
	ctx.apply_class(&"recruit")
	ctx.mode = &"exfil"
	ctx.mission = &"exfil"
	ctx.biome = &"beach"
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	run.exfil_pos = run.map.boat  # the beacon's point, as the scene's ExfilPoint would give
	return run


## The director in EXFIL: the step of each 90 s, the cap that comes with it, the specials' share, no relief.
func _test_director_steps() -> void:
	var d := Director.new(3)
	d.exfil = true
	var steps: Array[int] = []
	var caps: Array[int] = []
	var shares: Array[float] = []
	for t: float in [0.0, 89.9, 90.0, 180.0, 270.0, 360.0, 900.0]:
		d.elapsed = t
		steps.append(d.exfil_step())
		caps.append(d.call("_exfil_spawns", 1000.0, 0))  # a huge dt fills the target from empty
		shares.append(d.specials_share())
	_check(steps == [0, 0, 1, 2, 3, 4, 4], "EXFIL steps every 90 s, four at most (%s)" % [steps])
	_check(caps == [150, 150, 175, 200, 225, 250, 250], "EXFIL spawn target 150 to 250 by step, under the 300 cap (%s)" % [caps])
	_check(shares == [0.0, 0.0, 0.25, 0.5, 0.75, 1.0, 1.0], "EXFIL specials rise over the same steps (%s)" % [shares])
	# No relief and no peaks: the first second from empty spawns the steady rate (4 or 5), the phase never
	# changes, and after 120 s the count has filled the second step's target (175).
	var phase_before: int = d.phase
	var fresh := Director.new(3)
	fresh.exfil = true
	var first: int = fresh.update(1.0, 0, 0.0, 0)
	var alive: int = first
	for k in 119:
		alive += fresh.update(1.0, alive, 0.0, 0)
	_check(first == 4 or first == 5, "EXFIL spawns at the steady rate from the first second (%d)" % first)
	_check(fresh.phase == phase_before and alive == 175, "EXFIL has no relief or peak phase; after 120 s it holds 175 (%d)" % alive)
	# Outside EXFIL the director is the usual one: a peak still changes its phase.
	var normal := Director.new(3)
	normal.trigger_peak(10.0)
	_check(normal.phase == Director.Phase.PEAK and not normal.exfil, "a normal director still runs its peaks")


## Through the island's own step (its spawn gate, not only the director): the horde climbs to the step's
## target, and never past it. No damage (noclip, a dev flag) so the count is what the spawns make.
func _test_real_spawns_follow_the_steps() -> void:
	var run := _exfil_run()
	run.noclip = true
	run.director.elapsed = 100.0  # the second step: a target of 175
	var peak: int = 0
	for k in 480:  # 48 s at 0.1 s
		if not run.card_choices.is_empty():
			run.choose_card(0)  # a level-up pauses the run until a card is picked, as the player does
		run.reload_left = 1000.0  # the gun stays reloading: the auto-fire would kill the horde it is counting
		run.step(0.1, Vector2.ZERO, Vector3(0, 0, -1), false)
		peak = maxi(peak, run.horde.count)
	# The generated island's ring is partly sea: the fill is checked on the open EXFIL map (test_exfil_map).
	_check(peak <= 175 and run.horde.count > 0, "EXFIL's real spawns never pass the step's target of 175 (%d alive, peak %d)" % [run.horde.count, peak])


## The rules around the run: a hit that kills is not healed back to life, an EXFIL run is its own last island,
## and an Exit marker never replaces the beacon.
func _test_rules_around_the_run() -> void:
	var run := _exfil_run()
	run.hp = 0.0
	run._heal_player(20.0)
	_check(run.hp == 0.0, "a heal never brings a dead player back (hp %.1f)" % run.hp)
	run.hp = 50.0
	run._heal_player(20.0)
	_check(is_equal_approx(run.hp, 70.0), "a heal still heals a living player (hp %.1f)" % run.hp)
	var ctx := RunContext.new(2)
	ctx.mode = &"exfil"
	_check(ctx.is_last_island() and not RunContext.new(2).is_last_island(), "an EXFIL run is its last island; an Expedition's first is not")
	run.map.exit = Vector3(10.5, 0, 10.5)
	_check(not run.has_exit() and run.extraction_point() == run.exfil_pos, "an Exit marker does not replace the EXFIL beacon")
	var panel: Dictionary = IslandEndPanel.summary(run, ctx)
	_check(panel["title"] == "EXTRACTED" and String(panel["where"]).begins_with("EXFIL") and String(panel["next"]).begins_with("DEBRIEF"),
		"the end panel of an EXFIL run says EXTRACTED and leads to the debrief (%s / %s)" % [panel["title"], panel["next"]])


## No mission in EXFIL: no generator, survivor or nest starts, and nothing ends on an objective.
func _test_no_mission() -> void:
	var run := _exfil_run()
	_check(run.mission == &"exfil" and run.mode == &"exfil" and not run._main_task_done(),
		"EXFIL: the mission is exfil, which no objective completes")
	_check(run.objective_text() == "Survive: extraction opens in 10:00", "EXFIL: the objective reads the clock (%s)" % [run.objective_text()])
	var gen: Vector3 = run.map.generators[0] if not run.map.generators.is_empty() else run.player_pos
	run.player_pos = gen
	for k in 30:
		run._update_mission(10.0)  # five minutes next to a generator
	_check(run.generator_progress.size() == 0 or run.generator_progress[0] == 0.0,
		"EXFIL: standing on a generator starts nothing")
	_check(run.objective == IslandRun.Objective.GENERATORS and not run.is_over(),
		"EXFIL: the run stays on its clock until the extraction or a death (%s)" % [run.objective_text()])
	_check(IslandRun.clock_text(221.0) == "3:41", "the clock reads m:ss (221 s is 3:41)")


## Beacon: closed before 600 s (and the point does nothing), open after; reaching it then extracts.
func _test_beacon_and_extraction() -> void:
	var run := _exfil_run()
	run.player_pos = run.exfil_pos  # standing on the point
	run._update_exfil(100.0)
	_check(run.objective == IslandRun.Objective.GENERATORS and not run.is_over() and not run.exfil_open(),
		"before 600 s the exfil point does nothing (clock %.0f s)" % run.exfil_clock)
	_check(not run.exfil_beacon_on(), "the beacon is closed before 600 s")
	run.player_pos = run.exfil_pos + Vector3(40, 0, 0)  # away from the point when it opens
	run._update_exfil(499.0)
	_check(not run.exfil_open() and not run.exfil_beacon_on(), "the beacon is still closed at 599 s")
	run._update_exfil(1.0)
	_check(run.exfil_open() and run.exfil_beacon_on() and run.objective == IslandRun.Objective.GENERATORS,
		"at 600 s the extraction opens; the run is not over until the point is reached")
	_check(run.objective_text() == "Get to the exfil point!", "after 600 s the objective says so (%s)" % [run.objective_text()])
	run._update_exfil(1.0)
	_check(not run.is_over(), "the open extraction waits for the player at the point")
	run.player_pos = run.exfil_pos
	run._update_exfil(1.0)
	_check(run.objective == IslandRun.Objective.WON and run.is_over(), "reaching the open point ends the run as an extraction")


## Death ends an EXFIL run, as always.
func _test_death_ends_exfil() -> void:
	var run := _exfil_run()
	run.director.max_alive = 0
	run.hp = 0.0
	run.step(0.016, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(run.objective == IslandRun.Objective.LOST and run.is_over(), "dying ends an EXFIL run (LOST)")
	# The DEV skip-to-end opens the extraction and ends the run at its point, even before 10:00.
	var skip := _exfil_run()
	var skipped: bool = skip.dev_skip_to_end()
	_check(skipped and skip.objective == IslandRun.Objective.WON and skip.exfil_open(), "the DEV skip-to-end ends an EXFIL run at its point, the extraction opened")


## The sandbox form: "Mode: Exfil" sends the mode with START; Expedition sends the usual keys only.
func _test_sandbox_form() -> void:
	var sent: Array = []
	var dialog: MenuDialog = DevSandbox.open(root, func(config: Dictionary) -> void: sent.append(config))
	await process_frame
	var mode: OptionButton = null
	for box: Node in dialog.find_children("*", "OptionButton", true, false):
		if (box as OptionButton).get_item_text(0).begins_with("Mode:"):
			mode = box as OptionButton
	_check(mode != null and mode.item_count == 2, "the sandbox form has a Mode choice: Expedition or Exfil")
	if mode == null:
		return
	mode.select(1)
	(dialog.find_child("StartIsland", true, false) as Button).emit_signal("pressed")
	await process_frame
	var again: MenuDialog = DevSandbox.open(root, func(config: Dictionary) -> void: sent.append(config))
	await process_frame
	(again.find_child("StartIsland", true, false) as Button).emit_signal("pressed")
	await process_frame
	_check(sent.size() == 2 and sent[0].get("mode") == &"exfil" and not sent[1].has("mode"),
		"START sends the Exfil mode when picked, and the usual keys for Expedition")


## The sandbox names the mode; the island log records it and the seconds survived.
func _test_sandbox_and_log() -> void:
	var config: Dictionary = {"primary": &"rifle", "secondary": &"pistol", "class": &"recruit", "threat": 1, "seed": 4,
		"path": "res://game/world/handmade/islands/beach_01.tscn", "mission": &"activate", "mode": &"exfil"}
	var ctx: RunContext = DevSandbox.apply(config, RunContext.new(1))
	_check(ctx.mode == &"exfil" and ctx.mission == &"exfil" and ctx.biome == &"beach", "the sandbox's EXFIL config is a run with no mission on a beach")
	config.erase("mode")
	var plain: RunContext = DevSandbox.apply(config, RunContext.new(1))
	_check(plain.mode == &"expedition" and plain.mission == &"activate", "without the mode the sandbox is the Expedition, as before")
	var run := _exfil_run()
	run._update_exfil(612.0)
	run.player_pos = run.exfil_pos
	run._update_exfil(1.0)
	var log_ctx := RunContext.new(5)
	run.save_to_context(log_ctx)
	var entry: Dictionary = log_ctx.island_log[-1]
	_check(entry["mode"] == "exfil" and absf(float(entry["survived"]) - snappedf(run.exfil_clock, 0.1)) < 0.11 and entry["result"] == "cleared",
		"the island log records the mode and the seconds survived (%s s, %s)" % [entry["survived"], entry["result"]])
