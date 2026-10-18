extends SceneTree
## The Rescue survivor is the escort's human model: it stands still until it is
## found, walks (legs swing, its walked distance grows) once it follows the
## player, and is hidden when lost.
## Run: godot --headless --path . --script res://tests/test_rescue_survivor.gd

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	GameInput.setup()
	await _scene()
	quit(1 if _failures > 0 else 0)


func _scene() -> void:
	var ctx := RunContext.new(9)
	ctx.mission = &"rescue"
	ctx.biome = &"beach"
	var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	island.set("profile", MemoryProfile.new())
	island.set("context", ctx)
	root.add_child(island)
	for i in 3:
		await process_frame
	var run: IslandRun = island.get("run")
	run.director.max_alive = 0
	for i in range(run.horde.count - 1, -1, -1):
		run.horde.remove(i)
	var survivor: EscortModel = island.get("_survivor")
	_check(survivor != null and survivor.survivor and survivor.visible,
		"the rescue scene builds the human survivor, visible")
	_check(survivor.legs.size() == 2 and survivor.arms.size() == 2,
		"the survivor has legs and arms to walk and wave with")

	# Waiting at the site: not found yet, so it neither walks nor moves.
	run.survivor_found = false
	var waiting_at: Vector3 = run.survivor_pos
	run.player_pos = run.survivor_pos + Vector3(30, 0, 0)
	for i in 30:
		await process_frame
	var walked0: float = island.get("_survivor_walked")
	_check(not run.survivor_found and run.survivor_pos.distance_to(waiting_at) < 0.01,
		"the survivor waits at its spot until the player finds it")
	_check(absf(survivor.legs[0].rotation.x) < 0.001 and absf(walked0) < 0.001,
		"while waiting the survivor does not walk")

	# Found and following: it walks towards the player, legs swing, distance grows.
	run.survivor_found = true
	run.player_pos = run.survivor_pos + Vector3(8, 0, 0)
	var moved0: Vector3 = run.survivor_pos
	var swung: bool = false
	for i in 60:
		await process_frame
		if absf(survivor.legs[0].rotation.x) > 0.01:
			swung = true
	var walked1: float = island.get("_survivor_walked")
	_check(run.survivor_pos.distance_to(moved0) > 0.3 and walked1 > walked0 + 0.3,
		"the found survivor follows the player (%.2f m, walked %.2f m)" % [run.survivor_pos.distance_to(moved0), walked1 - walked0])
	_check(swung, "its legs swing while it walks")

	# Lost: hidden.
	run.survivor_lost = true
	await process_frame
	await process_frame
	_check(not survivor.visible, "a lost survivor is hidden")
	island.queue_free()
