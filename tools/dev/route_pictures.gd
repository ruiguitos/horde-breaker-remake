extends SceneTree
## Renders one picture per biome from the real island scene (an elevated view
## over the landing), without the HUD, into assets/ui/routes/<biome>.png. The
## route cards use these instead of the drawn miniatures when they exist.
## Needs a window (the scene is rendered): godot --path . --resolution 960x540 --script res://tools/dev/route_pictures.gd

const BIOMES: Array[StringName] = [&"beach", &"jungle", &"port", &"town", &"volcano"]


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var dir: String = ProjectSettings.globalize_path("res://assets/ui/routes")
	DirAccess.make_dir_recursive_absolute(dir)
	for b in BIOMES:
		var ctx := RunContext.new(21)
		ctx.biome = b
		ctx.mission = &"activate"
		var island: Node = (load("res://game/world/island.tscn") as PackedScene).instantiate()
		island.set("profile", Profile.new())
		island.set("context", ctx)
		root.add_child(island)
		var start_time: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - start_time < 9000:
			await process_frame
		var run: IslandRun = island.get("run")
		var start: Vector3 = run.map.player_start
		var hud: Node = island.get("hud")
		if hud != null and hud.get("visible") != null:
			hud.set("visible", false)
		var crosshair: Node = island.get("_crosshair")
		if crosshair != null:
			crosshair.set("visible", false)
		var cam := Camera3D.new()
		cam.fov = 58.0
		island.add_child(cam)
		cam.global_position = start + Vector3(0.0, run.map.ground_y(start) + 17.0, 13.0)
		cam.look_at(start + Vector3(0.0, 1.0, -16.0), Vector3.UP)
		cam.make_current()
		for i in 12:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		img.save_png("%s/%s.png" % [dir, b])
		print("saved %s" % b)
		island.queue_free()
		await process_frame
	quit(0)