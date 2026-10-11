extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var packed := load("res://demo/Recruit_v03.tscn") as PackedScene
	if packed == null:
		quit(2)
		return
	var model := packed.instantiate()
	root.add_child(model)
	await process_frame
	await process_frame
	var player: AnimationPlayer = model.get("player")
	var passed := player != null and player.current_animation == "UAL/Idle_Loop"
	print("GODOT_IMPORTED_DEMO_VALIDATION ", passed)
	quit(0 if passed else 2)
