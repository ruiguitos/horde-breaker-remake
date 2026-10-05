extends SceneTree
## Sandbox test map: the default PNG is an empty island, painted colours
## become buildings/trees/generators, and a sandbox run never spawns enemies.
## Run: godot --headless --path . --script res://tests/test_sandbox.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var map: IslandMap = IslandMap.from_image()
	_check(map.buildings.is_empty() and map.trees.is_empty() and map.rocks.is_empty() and map.generators.is_empty(),
		"default sandbox map is empty")
	_check(not map.field.is_blocked(int(map.player_start.x), int(map.player_start.z)), "player starts on land")
	# A painted 20x20 map: 3x2 building, a tree, a generator, the boat.
	var img := Image.create(20, 20, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	for z in range(2, 4):
		for x in range(2, 5):
			img.set_pixel(x, z, IslandMap.LEGEND[&"building"])
	img.set_pixel(10, 5, IslandMap.LEGEND[&"tree"])
	img.set_pixel(14, 6, IslandMap.LEGEND[&"generator"])
	img.set_pixel(10, 17, IslandMap.LEGEND[&"boat"])
	img.save_png("user://sandbox_test.png")
	var painted: IslandMap = IslandMap.from_image("user://sandbox_test.png")
	_check(painted.buildings == ([Rect2i(2, 2, 3, 2)] as Array[Rect2i]), "grey pixels merge into one building (%s)" % [painted.buildings])
	_check(painted.trees.size() == 1 and painted.generators.size() == 1 and painted.boat == Vector3(10.5, 0, 17.5), "tree, generator and boat read")
	_check(painted.field.is_blocked(3, 3) and not painted.field.is_blocked(6, 6), "buildings block, ground is open")
	var run := IslandRun.new(7, &"beach", map)
	run.sandbox = true
	var hp: float = run.hp
	for i in 600:
		run.step(1.0 / 60.0, Vector2(0, -1), Vector3(0, 0, -1), false)
	_check(run.horde.count == 0 and run.hp >= hp, "10 s of sandbox: no enemies, no damage")
	quit(1 if _failures > 0 else 0)
