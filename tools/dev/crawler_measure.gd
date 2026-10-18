extends SceneTree
## Measures the Codex crawler model's parts above the ground, straight from the
## GLB (no editor import needed), against the game's head and chest heights.
## Run: godot --headless --path . --script res://tools/dev/crawler_measure.gd

var _scene: Node
var _done: bool = false


func _initialize() -> void:
	var path: String = ProjectSettings.globalize_path("res://assets/models/characters/crawler_original/crawler.glb")
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	var err: int = doc.append_from_file(path, state)
	if err != OK:
		print("ERROR: cannot read crawler.glb (code %d)" % err)
		quit(1)
		return
	_scene = doc.generate_scene(state)
	root.add_child(_scene)


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	var lo := INF
	var hi := -INF
	for n in _scene.find_children("*", "Node3D", true, false):
		var node := n as Node3D
		if node.name in ["Head", "Torso", "Hand_Left", "Hand_Right", "Hip_Stump_Left", "Hip_Stump_Right", "Arm_Left", "Arm_Right"]:
			print("%-16s global y=%.3f  x=%.3f  z=%.3f" % [node.name, node.global_position.y, node.global_position.x, node.global_position.z])
	for m in _scene.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		lo = minf(lo, box.position.y)
		hi = maxf(hi, box.end.y)
	print("mesh y range: %.3f .. %.3f m" % [lo, hi])
	quit(0)
	return false