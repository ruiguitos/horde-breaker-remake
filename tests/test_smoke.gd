extends SceneTree
## Smoke test: the main scene loads and instantiates.
## Run: godot --headless --path . --script res://tests/test_smoke.gd


func _initialize() -> void:
	var failures := 0
	var packed := load("res://game/main.tscn") as PackedScene
	if packed == null:
		print("TEST FAIL: main scene did not load")
		failures += 1
	else:
		var root := packed.instantiate()
		if root == null:
			print("TEST FAIL: main scene did not instantiate")
			failures += 1
		else:
			print("TEST: main scene instantiates")
			root.free()
	quit(1 if failures > 0 else 0)
