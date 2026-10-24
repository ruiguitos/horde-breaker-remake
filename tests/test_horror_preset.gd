extends SceneTree
## The HORROR preset (DEV SANDBOX, debug builds): beach_01 at 04:24 under a steel-blue
## sky, mist in layers, a cold backlight behind the figures (no shadows, following the
## camera), the shoulder camera at the start of the run (V still changes it for that run
## only), a wind layer, no music for the first minute of game time, and a minimal HUD
## (F4 brings the full one back). A normal island keeps the usual sky, light, camera, HUD
## and music. The sandbox's realistic rifle reaches the island's soldier and view model.
## Run: godot --headless --path . --script res://tests/test_horror_preset.gd

const ISLAND: String = "res://game/world/island.tscn"
const BEACH_HANDMADE: String = "res://game/world/handmade/islands/beach_01.tscn"
## The HUD the preset keeps: visible, not transparent.
const KEPT: Array[String] = ["_hp_bar", "_shield_bar", "_ammo_text", "_breaker_ring", "_ability_ring"]
## The HUD the preset makes transparent (the same list as Hud._minimal_controls()): the
## radio, the objective, the minimap, the XP, the counters, the alerts and the rest.
const HIDDEN: Array[String] = ["_objective_box", "_survivor_row", "_boss_row", "_map_box", "_radio_panel",
	"_xp_bar", "_xp_text", "_xp_bonus", "_info", "_stats", "_power_up_timers", "_weapon_slots", "_fire_status",
	"_switch_hint", "_threats", "_hit_arc", "_messages", "_alerts"]
## Parts whose transparency the game's own logic also writes (the sprint bar, the marker):
## the minimal HUD makes them transparent, and nothing restores them to a fixed value.
const LOGIC_ALPHA: Array[String] = ["_marker_pill", "_sprint_row"]
## The HUD parts whose visibility belongs to the game's logic: the minimal HUD must leave it alone.
const LOGIC_OWNED: Array[String] = ["_radio_panel", "_survivor_row", "_boss_row", "_xp_bonus"]

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _sandbox_buttons()
	await _music_alone()
	var normal: Node = await _island(&"normal")
	if normal != null:
		_check(_sky(normal).get("current_time") > 8.9 and _sky(normal).get("current_time") < 9.1, "a normal island starts at its own hour (9:00 on the beach)")
		_check(_sky(normal).get("lights_enabled") == true, "a normal island keeps the Sky3D sun")
		_check(normal.get("_horror_light") == null, "a normal island has no backlight of its own")
		_check(normal.get("camera_mode") == Profile.CameraMode.FIRST_PERSON, "a normal island follows the profile's camera")
		_check(_sky(normal).environment.ambient_light_energy < 1.2, "a normal island keeps its own scene light, under the horror preset's (%.2f)" % _sky(normal).environment.ambient_light_energy)
		_check(_ambience_count(normal) == 1, "a normal island has only the sea ambience")
		_check(not normal.music.silenced(), "a normal island plays its music from the start")
		_check(not normal.hud.minimal and not normal.hud._survivor_row.visible and not normal.hud._boss_row.visible, "a normal island has the full HUD, with its survivor and boss rows still hidden")
		_check(normal.get("_player").get("_gun_node").get("variant") == &"", "a normal island holds the current rifle")
		var normal_surface: MeshInstance3D = normal.find_child("Roads", true, false).find_child("Surface", true, false) as MeshInstance3D
		_check(normal_surface != null and normal_surface.material_override is StandardMaterial3D and (normal_surface.material_override as StandardMaterial3D).albedo_color.get_luminance() > 0.4, "a normal island keeps its usual, light road surface")
		await _free(normal)
	var rifle_island: Node = await _island(&"normal", &"realistic")
	if rifle_island != null:
		_check(rifle_island.get("_view_model").get("_model").get("variant") == &"realistic", "the sandbox's realistic rifle reaches the first-person view model")
		_check(rifle_island.get("_player").get("_gun_node").get("variant") == &"realistic", "the sandbox's realistic rifle reaches the soldier in the world")
		await _free(rifle_island)
	var horror: Node = await _island(&"horror")
	if horror != null:
		var horror_surface: MeshInstance3D = horror.find_child("Roads", true, false).find_child("Surface", true, false) as MeshInstance3D
		_check(horror_surface != null and horror_surface.material_override is StandardMaterial3D and absf((horror_surface.material_override as StandardMaterial3D).albedo_color.get_luminance() - 0.3) < 0.03, "the horror preset's road is dark asphalt, about 0.30")
		await _horror_checks(horror)
		await _free(horror)
	quit(1 if _failures > 0 else 0)


func _horror_checks(horror: Node) -> void:
	var preset: Dictionary = (horror.get_script() as Script).get_script_constant_map()
	var sky: WorldEnvironment = _sky(horror)
	_check(absf(float(sky.get("current_time")) - float(preset["HORROR_HOUR"])) < 0.01, "the horror preset starts at 04:24 (the sky stays steel blue; 05:00 turns pink)")
	_check(sky.get("game_time_enabled") == false, "the horror clock is frozen")
	_check(sky.get("lights_enabled") == false and sky.get("fog_enabled") == false, "the horror preset turns off the Sky3D sun and its own fog pass")
	var env: Environment = sky.environment
	_check(env.fog_enabled and is_equal_approx(env.fog_density, float(preset["HORROR_FOG_DENSITY"])) and env.fog_height_density < 0.0, "the horror mist is in layers: thin far away, denser by the ground")
	_check(is_equal_approx(env.ambient_light_energy, float(preset["HORROR_AMBIENT_ENERGY"])), "the horror preset lifts its scene light to %.2f (was Sky3D's 1.0)" % env.ambient_light_energy)
	var light: DirectionalLight3D = horror.get("_horror_light")
	_check(light != null and light.light_energy > 0.0 and light.light_energy < 0.6, "the horror preset has a weak cold backlight")
	_check(light != null and not light.shadow_enabled, "the backlight casts no shadows at the start")
	if light != null:
		GraphicsSettings.apply_sun(light)  # what apply_graphics() does to every light
		_check(not light.shadow_enabled, "the backlight casts no shadows after the graphics settings are applied")
	_check(light != null and light.rotation_degrees.x > -12.0 and light.rotation_degrees.x < -3.0, "the backlight is a few degrees below the horizontal")
	# The backlight travels towards the camera for any yaw (flat directions, so the pitch does not matter).
	var toward_camera: bool = true
	for yaw: float in [float(horror.get("_tp_yaw")), 1.2, -2.4]:
		horror.set("_tp_yaw", yaw)
		await _settle(1)
		toward_camera = toward_camera and _travels_towards_yaw(light, yaw)
	_check(toward_camera, "the backlight travels towards the camera for each yaw, on the frame the yaw changes")
	_check(horror.get("camera_mode") == Profile.CameraMode.THIRD_PERSON, "the horror preset starts on the shoulder camera, whatever the profile says")
	_check(_ambience_count(horror) == 2, "the horror preset adds a wind layer over the sea")
	_check(horror.music.silenced(), "the horror preset has no music at the start")
	_check(horror.music._calm_player.volume_db <= -79.0, "the horror music is silent from the first frame")
	# A pause does not end the silence: the music stands still while the game does.
	var left: float = horror.music._silent_for
	horror.paused = true
	horror._play_audio()
	horror._play_audio()
	horror.paused = false
	_check(absf(horror.music._silent_for - left) < 0.001, "a paused island keeps its silence (%.2f s left)" % horror.music._silent_for)
	# V changes the camera for this run; the profile keeps its own choice and the sync does not undo it.
	horror._set_camera_mode(Profile.CameraMode.FIRST_PERSON, false)
	await _settle(1)
	_check(horror.camera_mode == Profile.CameraMode.FIRST_PERSON and horror.profile.camera_mode == Profile.CameraMode.FIRST_PERSON, "V changes the horror run's camera without a new profile choice")
	horror._set_camera_mode(Profile.CameraMode.THIRD_PERSON, false)
	await _settle(1)
	await _hud_checks(horror)
	# The music: the silence is measured from what is left of it, so it does not depend on the frames before.
	var remaining: float = horror.music._silent_for
	horror.music.update_mix(0.0, remaining - 1.0)
	_check(horror.music.silenced(), "the horror preset is still silent one second before its music")
	horror.music.update_mix(0.0, 1.0)
	_check(not horror.music.silenced(), "the horror preset's music starts when the silence ends")
	horror.music.update_mix(0.0, 2.5)
	_check(is_equal_approx(horror.music._gain, 1.0), "the horror preset's music has faded in two seconds later")
	# The fallback sky (no Sky3D) gets the same mist.
	horror.call("_build_simple_sky", 0)
	var fallback: bool = false
	for child in horror.get_children():
		if child is WorldEnvironment and child.get("current_time") == null:
			fallback = is_equal_approx(child.environment.fog_density, float(preset["HORROR_FOG_DENSITY"])) and is_equal_approx(child.environment.ambient_light_energy, float(preset["HORROR_AMBIENT_ENERGY"]))
	_check(fallback, "the fallback sky of the horror preset has the same mist and scene light")


## The minimal HUD: the listed parts are transparent, the kept ones stay, the game's own
## visibility is untouched by F4, and the radio keeps its logic while it is toggled.
func _hud_checks(horror: Node) -> void:
	var hud: Hud = horror.hud
	var key := InputEventKey.new()
	key.keycode = KEY_F4
	key.pressed = true
	# A radio line on the air, as the game plays it.
	hud._radio_queue.append({"speaker": "Director Hale", "text": "Three generators, contractor."})
	await _settle(2)
	_check(hud.minimal, "the horror preset starts with the minimal HUD")
	var hidden_ok: bool = true
	for part: String in HIDDEN + LOGIC_ALPHA:
		hidden_ok = hidden_ok and (hud.get(part) as Control).modulate.a == 0.0
	var kept_ok: bool = true
	for part: String in KEPT:
		kept_ok = kept_ok and (hud.get(part) as Control).is_visible_in_tree() and (hud.get(part) as Control).modulate.a > 0.99
	_check(hidden_ok, "the minimal HUD makes the radio, objective, minimap, XP, counters and marker transparent")
	_check(kept_ok, "the minimal HUD keeps health, shield, ammo and the abilities on screen")
	var before: Array = []
	for part: String in LOGIC_OWNED:
		before.append((hud.get(part) as Control).visible)
	horror._unhandled_input(key)  # the full HUD
	var after: Array = []
	for part: String in LOGIC_OWNED:
		after.append((hud.get(part) as Control).visible)
	var full_ok: bool = true
	# The XP and the counters rest at 85 % (the HUD's visual weights); the minimap box and the rest at full strength.
	for part: String in HIDDEN:
		var rest: float = 0.85 if part in ["_xp_bar", "_xp_text", "_xp_bonus", "_stats", "_survivor_row"] else 1.0
		full_ok = full_ok and absf((hud.get(part) as Control).modulate.a - rest) < 0.001
	_check(not hud.minimal and full_ok, "F4 brings the full HUD back (the minimap shows again, the XP and counters at 85 %)")
	_check(before == after, "F4 leaves the game's own visibility alone (radio, survivor, boss, XP bonus)")
	horror._unhandled_input(key)  # minimal again
	await _settle(1)
	var again: bool = hud.minimal
	for part: String in HIDDEN:
		again = again and (hud.get(part) as Control).modulate.a == 0.0
	_check(again, "F4 again returns the minimal HUD")
	_check(hud._marker_pill.modulate.a == 0.0, "the minimal HUD makes the marker transparent even while the game fades it")


## Whether the backlight's travel direction points back at the camera's view for `yaw`
## (flat directions: the pitch does not matter).
func _travels_towards_yaw(light: DirectionalLight3D, yaw: float) -> bool:
	if light == null:
		return false
	var travel: Vector3 = -light.global_basis.z
	travel.y = 0.0
	var view: Vector3 = Vector3(0, 0, -1).rotated(Vector3.UP, yaw)
	return travel.normalized().dot(view) < -0.99


## Both sandbox buttons send their config: START sends the form as it is, and HORROR
## the same form on beach_01 with the horror atmosphere. A realistic rifle is sent
## only when it is picked.
func _sandbox_buttons() -> void:
	var sent: Array = []
	var start: MenuDialog = DevSandbox.open(root, func(config: Dictionary) -> void: sent.append(config))
	await process_frame
	(start.find_child("StartIsland", true, false) as Button).emit_signal("pressed")
	var horror: MenuDialog = DevSandbox.open(root, func(config: Dictionary) -> void: sent.append(config))
	await process_frame
	(horror.find_child("StartHorror", true, false) as Button).emit_signal("pressed")
	var rifle: MenuDialog = DevSandbox.open(root, func(config: Dictionary) -> void: sent.append(config))
	await process_frame
	# The primary weapon is the fourth choice of the form; its second item is the realistic rifle.
	var choices: Array = rifle.find_children("*", "OptionButton", true, false)
	(choices[3] as OptionButton).select(1)
	(rifle.find_child("StartIsland", true, false) as Button).emit_signal("pressed")
	_check(sent.size() == 3, "all three sandbox buttons send a config (%d)" % sent.size())
	if sent.size() != 3:
		return
	var plain: Dictionary = sent[0]
	var preset: Dictionary = sent[1]
	var realistic: Dictionary = sent[2]
	_check(plain.size() == 7 and not plain.has("atmosphere") and not plain.has("rifle_model"), "START sends the form's seven values and no atmosphere or test rifle")
	_check(preset.get("atmosphere") == &"horror" and preset.get("path") == BEACH_HANDMADE, "HORROR sends beach_01 with the horror atmosphere")
	_check(preset.get("mission") == plain.get("mission") and preset.get("class") == plain.get("class") and preset.get("seed") == plain.get("seed"), "HORROR keeps the form's mission, class and seed")
	_check(realistic.get("primary") == &"rifle" and realistic.get("rifle_model") == &"realistic" and realistic.size() == 8, "the realistic rifle is sent as the rifle with its test model")
	var ctx: RunContext = DevSandbox.apply(preset, RunContext.new(1))
	_check(ctx.atmosphere == &"horror" and ctx.biome == &"beach" and ctx.rifle_model == &"", "the horror config starts a beach run with the horror atmosphere")
	var real_ctx: RunContext = DevSandbox.apply(realistic, RunContext.new(1))
	_check(real_ctx.rifle_model == &"realistic" and real_ctx.atmosphere == &"normal", "the realistic rifle is set on the run and the atmosphere stays normal")
	await _settle(2)


## The music on its own: silent from its first frame when muted; the fade in starts
## when the silence ends, not before; and a music that is not muted keeps its volume.
func _music_alone() -> void:
	var music := Music.new()
	music.mute_for(60.0)
	root.add_child(music)
	await process_frame
	_check(music._calm_player.volume_db <= -79.0 and music._combat_player.volume_db <= -79.0, "a muted music is silent from its first frame")
	music.update_mix(0.0, 59.5)
	_check(music.silenced() and music._gain == 0.0, "the muted music stays silent until 60 s")
	music.update_mix(0.0, 1.0)  # 60.5 s: half a second of silence, then half a second of fade
	_check(not music.silenced() and is_equal_approx(music._gain, 0.25), "the fade starts when the silence ends (gain %.2f)" % music._gain)
	music.update_mix(0.0, 2.0)  # 62.5 s: the fade is done
	_check(is_equal_approx(music._gain, 1.0), "the fade has finished by 62.5 s")
	_check(absf(music._calm_player.volume_db - linear_to_db(0.55)) < 0.01, "the music plays at its usual volume once it is back (%.2f dB)" % music._calm_player.volume_db)
	await _free(music)


## An island built with `atmosphere` (and the sandbox's rifle model), after two frames
## (the scene builds its sky in _ready).
func _island(atmosphere: StringName, rifle: StringName = &"") -> Node:
	var ctx := RunContext.new(1)
	ctx.biome = &"beach"
	ctx.atmosphere = atmosphere
	ctx.rifle_model = rifle
	var profile := Profile.new()
	profile.camera_mode = Profile.CameraMode.FIRST_PERSON
	var island: Node = (load(ISLAND) as PackedScene).instantiate()
	island.set("handmade_scene", load(BEACH_HANDMADE))
	island.set("context", ctx)
	island.set("profile", profile)
	root.add_child(island)
	await _settle(2)
	return island


## Frames for queued frees to run: a node still alive at quit keeps its resources
## (the ambience loops) in use, which the engine reports at exit.
func _settle(frames: int) -> void:
	for i in frames:
		await process_frame


## Frees `node` and waits until it is really gone (a capped number of frames), so that
## nothing of it is still alive when the test quits.
func _free(node: Node) -> void:
	node.queue_free()
	var frames: int = 0
	while is_instance_valid(node) and frames < 120:
		await process_frame
		frames += 1
	# A stopped sound is released by the audio thread at its next mix, which under the headless
	# audio driver can come a few hundred milliseconds later (0.05 s left a leak in 2 of 10 runs).
	await create_timer(0.3).timeout


## The Sky3D node of the island (the fallback sky has no clock).
func _sky(island: Node) -> WorldEnvironment:
	for child in island.get_children():
		if child is WorldEnvironment and child.get("current_time") != null:
			return child
	return null


func _ambience_count(island: Node) -> int:
	var count: int = 0
	for child in island.get_children():
		if child is Ambience:
			count += 1
	return count
