extends SceneTree
## Reapply the beach pilot without rebuilding its authored layout.
const PATH: String = "res://game/world/handmade/islands/beach_01.tscn"
const BUILDER: Script = preload("res://tools/dev/beach_dressing.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var original: String = FileAccess.get_file_as_string(PATH)
	var packed: PackedScene = load(PATH) as PackedScene
	if packed == null or original.is_empty():
		print("AUTHORING FAIL: beach scene could not load")
		quit(1)
		return
	var island: HandmadeIsland = packed.instantiate()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(128, 50, 180)
	root.add_child(island)
	island.get_node("Terrain3D").call("set_camera", camera)
	await process_frame
	var problems: Array[String] = BUILDER.apply(island)
	if not problems.is_empty() or FileAccess.get_file_as_string(PATH) != original:
		print("AUTHORING FAIL: ", problems, "; scene changed externally or authoring failed")
		island.free()
		quit(1)
		return
	var resources: Dictionary = {}
	var targets: Dictionary = {}
	var indices: Dictionary = {}
	for group: String in ["Buildings", "Bridges", "Decor/Roads", "Rocks"]:
		for node: MeshInstance3D in island.get_node(group).find_children("*", "MeshInstance3D", true, false):
			var material: Material = node.material_override
			if material != null and material.resource_path.begins_with(BUILDER.DIR):
				var id: String = "beach_material_" + material.resource_path.get_file().get_basename()
				resources[material.resource_path] = id
				var path: String = str(island.get_path_to(node))
				targets[path] = id
				indices[path] = node.get_index()
	var additions: String = ""
	for path: String in resources:
		additions += '[ext_resource type="Material" path="%s" id="%s"]\n' % [path, resources[path]]
	additions += '[ext_resource type="PackedScene" path="%s" id="beach_dressing"]\n' % BUILDER.SCENE
	var owned_resources := RegEx.create_from_string('(?m)^\\[ext_resource[^\\n]* id="(?:beach_material_[^"]+|beach_dressing)"\\]\\n')
	var updated: String = owned_resources.sub(original, "", true)
	updated = updated.insert(updated.find("[sub_resource"), additions + "\n")
	updated = updated.replace('path="res://game/world/handmade/ground_assets.res"', 'path="' + BUILDER.DIR + 'beach_01_ground.tres"')
	var blocks: PackedStringArray = updated.split("\n[node ")
	var name_rx := RegEx.create_from_string('name="([^"]+)"')
	var parent_rx := RegEx.create_from_string('parent="([^"]+)"')
	var material_rx := RegEx.create_from_string('material_override = [^\n]+')
	var changed: Dictionary = {}
	for i in range(1, blocks.size()):
		var header: String = blocks[i].get_slice("\n", 0)
		var name: String = name_rx.search(header).get_string(1)
		var parent_match: RegExMatch = parent_rx.search(header)
		if parent_match == null:
			if not blocks[i].contains("metadata/beach_visual_pilot"):
				blocks[i] += "metadata/beach_visual_pilot = true\n"
			continue
		var parent: String = parent_match.get_string(1)
		var path: String = name if parent == "." else parent + "/" + name
		if targets.has(path):
			var override: String = 'material_override = ExtResource("%s")' % targets[path]
			blocks[i] = material_rx.sub(blocks[i], override) if material_rx.search(blocks[i]) != null else blocks[i] + override + "\n"
			changed[path] = true
		if parent == "Rocks":
			blocks[i] = blocks[i].replace("\nvisible = false\n", "\n")
	updated = "\n[node ".join(blocks)
	for path: String in targets:
		if not changed.has(path) and path.begins_with("Rocks/"):
			updated += '\n[node name="%s" parent="%s" index="%d"]\nmaterial_override = ExtResource("%s")\n' % [path.get_file(), path.get_base_dir(), indices[path], targets[path]]
			var instance_path: String = "/".join(path.split("/").slice(0, 2))
			if not updated.contains('[editable path="' + instance_path + '"]'):
				updated += '\n[editable path="%s"]\n' % instance_path
			changed[path] = true
	if changed.size() != targets.size():
		print("AUTHORING FAIL: not every material override could be persisted")
		island.free()
		quit(1)
		return
	if not updated.contains('name="Dressing" parent="Decor"'):
		updated += '\n[node name="Dressing" parent="Decor" instance=ExtResource("beach_dressing")]\n'
	updated = RegEx.create_from_string("\n{3,}").sub(updated, "\n\n", true)
	var output := FileAccess.open(PATH, FileAccess.WRITE)
	if output == null:
		print("AUTHORING FAIL: could not write beach scene")
		island.free()
		quit(1)
		return
	output.store_string(updated)
	output.close()
	print("Beach visual layer baked without rebuilding the layout")
	island.free()
	quit()
