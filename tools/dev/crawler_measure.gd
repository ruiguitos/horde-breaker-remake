extends SceneTree
## Measures the Codex crawler model in its bind pose: the height of each named
## part above the ground, so the crawl pose can be checked against the game's
## head and chest heights (ZombieModel.CRAWL_HEAD_HEIGHT / CRAWL_CHEST_HEIGHT).
## Run: godot --headless --path . --script res://tools/dev/crawler_measure.gd

func _initialize() -> void:
	var scene: Node = (load("res://assets/models/characters/crawler_original/crawler.glb") as PackedScene).instantiate()
	root.add_child(scene)
	for n in scene.find_children("*", "Node3D", true, false):
		var node := n as Node3D
		if node.name in ["Head", "Torso", "Hand_Left", "Hand_Right", "Hip_Stump_Left", "Hip_Stump_Right", "Arm_Left", "Arm_Right"]:
			print("%-16s origin y=%.3f  global y=%.3f  x=%.3f  z=%.3f" % [node.name, node.position.y, node.global_position.y, node.global_position.x, node.global_position.z])
	var lo := INF
	var hi := -INF
	for m in scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		lo = minf(lo, aabb.position.y)
		hi = maxf(hi, aabb.end.y)
	print("mesh y range: %.3f .. %.3f m" % [lo, hi])
	quit(0)