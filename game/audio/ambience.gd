class_name Ambience
extends AudioStreamPlayer
## Looping background ambience (sea, rainforest, wind...) that fades in.
## The pack's loops are plain WAVs, so we restart them when they finish.

var target_db: float = -12.0


static func create(key: StringName, volume_db: float = -12.0) -> Ambience:
	var a := Ambience.new()
	a.stream = Sfx.ambience_stream(key)
	a.target_db = volume_db
	return a


func _ready() -> void:
	bus = Profile.BUS_SFX
	if stream == null:
		return
	volume_db = -40.0
	finished.connect(play)
	play()


func _process(delta: float) -> void:
	volume_db = move_toward(volume_db, target_db, delta * 10.0)


## A loop still playing when its island goes is reported at exit as a resource in use.
func _exit_tree() -> void:
	stop()
