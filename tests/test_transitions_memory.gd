extends SceneTree
## Repeated screen changes do not leak (docs/tech/GAME_AUDIT.md, T08): the title
## and the Armory are opened and closed many times. After a warm-up, the main
## scene keeps the same children and the live object count stops growing.
## Only the title and the Armory are used: the debrief and the island save the
## real profile, and this test must not write it.
## Run: godot --headless --path . --script res://tests/test_transitions_memory.gd

const CYCLES: int = 12
const WARM_UP: int = 3
const OBJECT_TOLERANCE: int = 10  ## live objects allowed to grow after warm-up
## GameFlow values in game/main.gd (enum GameFlow { BOAT, ISLAND, DEBRIEF, ARMORY, TITLE, CAMP }).
const ARMORY: int = 3
const TITLE: int = 4

var _main: Node
var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_main = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	await _settle()
	var samples: Array = []  # [live objects, children of the main scene] after each cycle
	for cycle in CYCLES:
		_main.call("_go", ARMORY)
		await _settle()
		_main.call("_go", TITLE)
		await _settle()
		samples.append([Performance.get_monitor(Performance.OBJECT_COUNT), _main.get_child_count()])
	var warm: Array = samples[WARM_UP - 1]
	var last: Array = samples[-1]
	print("samples (objects, children): %s" % str(samples))
	_check(int(last[1]) == int(warm[1]), "the main scene keeps the same children after %d cycles (%d)" % [CYCLES, int(last[1])])
	var growth: int = int(last[0]) - int(warm[0])
	_check(growth <= OBJECT_TOLERANCE, "live objects grow by %d after warm-up (limit %d)" % [growth, OBJECT_TOLERANCE])
	_main.queue_free()
	await _settle()
	quit(1 if _failures > 0 else 0)


## Two frames: a screen freed with queue_free is gone, and the next one has run _ready.
func _settle() -> void:
	await process_frame
	await process_frame
