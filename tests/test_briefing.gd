extends SceneTree
## Boat briefing (Dialogue Manager): the .dialogue compiles, lines read the
## run state, choices branch, and "hazard pay" changes the next island.
## Run: godot --headless --path . --script res://tests/test_briefing.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var dm: Node = root.get_node_or_null("DialogueManager")
	_check(dm != null, "DialogueManager autoload is active")
	if dm == null:
		quit(1)
		return
	var res: Resource = load(Briefing.RESOURCE)
	_check(res != null, "briefing.dialogue compiles")
	var ctx := RunContext.new(5)
	ctx.biome = &"port"
	ctx.mission = &"defend"
	var b := Briefing.new(ctx)
	var states: Array = [{"briefing": b}]
	var line: Object = await dm.call("get_next_dialogue_line", res, "start", states)
	_check(line != null and String(line.get("text")).contains("Industrial Port") and String(line.get("text")).contains("Defend"),
		"first line names the island and mission")
	var responses: Array = line.get("responses")
	_check(responses.size() == 4, "four choices at the start (%d)" % responses.size())
	# Follow "I want hazard pay." -> "Deal."
	var hazard: Object = responses.filter(func(r: Object) -> bool: return String(r.get("text")).contains("hazard"))[0]
	line = await dm.call("get_next_dialogue_line", res, String(hazard.get("next_id")), states)
	while line != null and (line.get("responses") as Array).is_empty():
		line = await dm.call("get_next_dialogue_line", res, String(line.get("next_id")), states)
	var deal: Object = (line.get("responses") as Array)[0]
	line = await dm.call("get_next_dialogue_line", res, String(deal.get("next_id")), states)
	_check(ctx.hazard_pay, "choosing Deal sets hazard pay on the run")
	# The sim applies it: more enemies, more Intel, then it resets.
	var run := IslandRun.new(5, &"port")
	run.load_context(ctx)
	var plain_ctx := RunContext.new(5)
	plain_ctx.biome = &"port"
	plain_ctx.mission = &"defend"
	var plain := IslandRun.new(5, &"port")
	plain.load_context(plain_ctx)
	_check(run.director.max_alive > plain.director.max_alive, "hazard pay raises the enemy cap (%d > %d)" % [run.director.max_alive, plain.director.max_alive])
	run.kills = 100
	plain.kills = 100
	_check(run.intel_earned() > plain.intel_earned(), "hazard pay raises Intel (%d > %d)" % [run.intel_earned(), plain.intel_earned()])
	run.save_to_context(ctx)
	_check(not ctx.hazard_pay, "hazard pay lasts one island")
	# Once taken, the option is hidden.
	line = await dm.call("get_next_dialogue_line", res, "choice", [{"briefing": Briefing.new(RunContext.new(1))}])
	var b2 := Briefing.new(ctx)
	b2.hazard_pay = true
	line = await dm.call("get_next_dialogue_line", res, "start", [{"briefing": b2}])
	var allowed: Array = (line.get("responses") as Array).filter(func(r: Object) -> bool: return bool(r.get("is_allowed")))
	_check(allowed.size() == 3, "hazard pay choice hidden after accepting (%d left)" % allowed.size())
	quit(1 if _failures > 0 else 0)
