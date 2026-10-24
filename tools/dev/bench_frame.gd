extends SceneTree
## Full-frame benchmark on a real island: terrain, sea, HUD, horde, weapons and effects.
##   godot --path . --resolution 1600x900 --windowed --script res://tools/dev/bench_frame.gd -- <first|third|fixed> [seconds] [rifle_variant]
## Vsync off and fps unlimited. The player stands still while the horde piles up, so this
## measures the frame cost of the scene, not a human run and not the balance.
## Prints the mean, p95 and p99 frame time, the draw calls and the enemies alive.

const ISLAND: String = "res://game/world/handmade/islands/beach_01.tscn"
const SPAWNED: int = 150  ## the horde cap the decision fixed (GameData.MAX_ALIVE)
const SPAWN_RADIUS_MIN: float = 9.0
const SPAWN_RADIUS_MAX: float = 24.0
const WARM_SECONDS: float = 3.0

var _camera: String = "third"
var _seconds: float = 10.0
var _variant: StringName = &""
var _island: Node
var _run: IslandRun
var _seeded: bool = false
var _elapsed: float = 0.0
var _samples: Array[float] = []
var _draw_calls: int = 0
var _alive_max: int = 0
var _alive_min: int = 9999
var _done: bool = false


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_camera = args[0] if args.size() > 0 else "third"
	_seconds = float(args[1]) if args.size() > 1 else 10.0
	if args.size() > 2:
		_variant = StringName(args[2])
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	# A fresh profile in memory: the bench never reads or writes the player's own.
	if Profile.current == null:
		Profile.current = Profile.new()
	Profile.current.camera_mode = {
		"first": Profile.CameraMode.FIRST_PERSON,
		"third": Profile.CameraMode.THIRD_PERSON,
		"fixed": Profile.CameraMode.FIXED,
	}.get(_camera, Profile.CameraMode.THIRD_PERSON)
	var ctx := RunContext.new(7)
	ctx.biome = &"beach"
	ctx.threat = 3
	ctx.modifier = &"swarm"
	ctx.rifle_model = _variant
	_island = (load("res://game/world/island.tscn") as PackedScene).instantiate()
	_island.set("handmade_scene", load(ISLAND))
	_island.set("context", ctx)
	root.add_child(_island)


func _process(delta: float) -> bool:
	if _done:
		return true
	if not _seeded:
		_seed_world()
		return false
	_elapsed += delta
	if _elapsed < WARM_SECONDS:
		return false
	_samples.append(delta * 1000.0)
	_draw_calls = maxi(_draw_calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_alive_min = mini(_alive_min, _run.horde.count)
	_alive_max = maxi(_alive_max, _run.horde.count)
	if _samples.size() >= int(_seconds * 60.0):
		_report()
	return false


## Waits for the island to build the run, then fills the horde.
func _seed_world() -> void:
	_run = _island.get("run") as IslandRun
	if _run == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var centre: Vector3 = _run.player_pos
	var kinds: Array[int] = [
		GameData.EnemyKind.BRUTE, GameData.EnemyKind.GRABBER, GameData.EnemyKind.GRABBER,
		GameData.EnemyKind.BLOATER, GameData.EnemyKind.BLOATER, GameData.EnemyKind.SCREAMER,
	]
	for i in SPAWNED:
		var angle: float = TAU * float(i) / float(SPAWNED)
		var radius: float = lerpf(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX, float((i * 37) % SPAWNED) / float(SPAWNED))
		var spot: Vector3 = centre + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var kind: int = kinds[i] if i < kinds.size() else GameData.EnemyKind.WALKER
		_run.horde.add(spot, kind, rng)
	_run.horde.set_target(centre)
	_seeded = true


func _report() -> void:
	_done = true
	_samples.sort()
	var mean: float = 0.0
	for v in _samples:
		mean += v
	mean /= float(_samples.size())
	var p50: float = _samples[int(_samples.size() * 0.50)]
	var p95: float = _samples[int(_samples.size() * 0.95)]
	var p99: float = _samples[int(_samples.size() * 0.99)]
	print("BENCH camera=%s rifle=%s samples=%d alive=%d..%d draws=%d mean=%.2fms p50=%.2f p95=%.2f p99=%.2f max=%.2f (%.1f fps mean)" % [
		_camera, String(_variant) if _variant != &"" else "current", _samples.size(),
		_alive_min, _alive_max, _draw_calls, mean, p50, p95, p99, _samples[-1], 1000.0 / mean])
	quit(0)
