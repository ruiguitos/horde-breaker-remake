extends SceneTree
## Drives the real game scenes headless through a run:
## boat -> island (simulates) -> cleared -> boat -> island -> death -> debrief.
## Run: godot --headless --path . --script res://tests/test_game_scene.gd

var _frames: int = 0
var _step: int = 0
var _main: Node
var _failures: int = 0


func _initialize() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _current() -> Node:
	return _main.get("_current")


func _process(_delta: float) -> bool:
	_frames += 1
	match _step:
		0:
			_check(_main.get("state") == 3, "the game opens in the armory")
			_current().call("_start")
			_step = 10
		10:
			_check(_main.get("state") == 0, "starting a run goes to the boat")
			_current().call("_pick", 0)
			_current().call("_pick_route", 0)
			_check(_current().call("_can_land"), "the boat allows landing after a supply and a route")
			_current().emit_signal("land_requested")
			_step = 1
			_frames = 0
		1:
			if _frames == 2:
				_check(_main.get("state") == 1, "landing opens the island")
			var run: IslandRun = _current().get("run") if _frames > 1 else null
			if run != null and (run.time_alive > 12.0 or _frames > 6000):
				_check(run.time_alive > 10.0 and run.horde.count > 0,
					"island simulates (%.1f s, %d enemies)" % [run.time_alive, run.horde.count])
				run.objective = IslandRun.Objective.WON
				_current().call("_finish")
				_step = 2
				_frames = 0
		2:
			if _frames == 2:
				var ctx: RunContext = _main.get("context")
				_check(_main.get("state") == 0 and ctx.island_index == 1, "clearing island 1 returns to the boat for island 2")
				_current().call("_pick", 0)
				_current().emit_signal("land_requested")
			if _frames == 6:
				var run: IslandRun = _current().get("run")
				_check(run.horde.hp_scale > 1.0, "island 2 is tougher (enemy HP x%.1f)" % run.horde.hp_scale)
				run.objective = IslandRun.Objective.LOST
				_current().call("_finish")
			if _frames == 10:
				_check(_main.get("state") == 2, "death ends the run in the debrief")
				_current().emit_signal("new_run_requested")
			if _frames == 14:
				_check(_main.get("state") == 3, "the debrief returns to the armory")
				quit(1 if _failures > 0 else 0)
	return false
