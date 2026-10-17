extends SceneTree
## Captures one frame per biome with the grading as it is now, into
## docs/design/grading/<biome>.png. Needs a window (the grading is a
## compositor effect, skipped without a RenderingDevice).
## Run: godot --path . --script res://tools/dev/grade_preview.gd

const BIOMES: Array[StringName] = [&"beach", &"jungle", &"port", &"town", &"volcano"]


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var dir: String = ProjectSettings.globalize_path("res://docs/design/grading")
	DirAccess.make_dir_recursive_absolute(dir)
	for b in BIOMES:
		var ctx := RunContext.new(11)
		ctx.biome = b
		ctx.mission = &"activate"
		var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
		island.set("profile", Profile.new())
		island.set("context", ctx)
		root.add_child(island)
		# The boot splash and the loading screen cover the island for a few seconds.
		var start: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - start < 9000:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/%s.png" % [dir, b])
		print("saved %s" % b)
		island.queue_free()
		await process_frame
	quit(0)