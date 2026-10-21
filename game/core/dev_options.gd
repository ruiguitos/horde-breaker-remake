class_name DevOptions
extends RefCounted
## Development options for the in-island dev menu (docs/design/DEV_MENU.md,
## zona 2). They exist only in debug builds (the editor or a debug export); a
## release build never has the menu, and these keep their defaults there.

static var invincible: bool = false  ## no damage to the player
static var infinite_ammo: bool = false  ## no ammo or magazine use
static var time_scale: float = 1.0  ## game speed, 0.1 to 2.0
static var horde_alive: int = 0  ## enemies alive set by the dev menu; 0 = the run's own limit


## Whether the dev menu and its options exist in this build.
static func enabled() -> bool:
	return OS.is_debug_build()


## Whether an option changes the balance. Such a run is not measured, saved or
## sent to telemetry, and the HUD says so.
static func changes_balance() -> bool:
	return enabled() and (invincible or infinite_ammo or time_scale != 1.0 or horde_alive > 0)


## Names of the options that are on, for the HUD line.
static func active_labels() -> PackedStringArray:
	var out := PackedStringArray()
	if invincible:
		out.append("Invincible")
	if infinite_ammo:
		out.append("Infinite ammo")
	if time_scale != 1.0:
		out.append("Game speed %.1f×" % time_scale)
	if horde_alive > 0:
		out.append("Enemies %d" % horde_alive)
	return out


## Puts every option back to its default.
static func reset() -> void:
	invincible = false
	infinite_ammo = false
	time_scale = 1.0
	horde_alive = 0
