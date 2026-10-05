extends RefCounted
## Simulated player: deals `dps` to the closest enemies within reach and takes
## damage from enemies in melee range, reduced by `mitigation` (dodging, kiting).

const MAX_HP := 100.0
const REGEN_PER_S := 8.0
const REGEN_DELAY := 3.0
const REACH_ETA := 3.0 ## enemies this many seconds away are already shootable

var name: String
var dps: float
var mitigation: float
var hp: float = MAX_HP
var deaths: int = 0
var _since_hit: float = 0.0


func _init(p_name: String, p_dps: float, p_mitigation: float) -> void:
	name = p_name
	dps = p_dps
	mitigation = p_mitigation


## Returns damage taken this step. `enemies` is mutated (hp/kills).
func step(enemies: Array[Dictionary], dt: float, types: Dictionary) -> float:
	var damage := 0.0
	for e: Dictionary in enemies:
		if e.eta <= 0.0:
			damage += float(types[e.type].dps) * dt
	damage *= 1.0 - mitigation
	hp -= damage
	if damage > 0.0:
		_since_hit = 0.0
	else:
		_since_hit += dt
		if _since_hit >= REGEN_DELAY:
			hp = minf(MAX_HP, hp + REGEN_PER_S * dt)
	if hp <= 0.0:
		deaths += 1
		hp = MAX_HP ## respawn so all runs last the full 25 minutes
		enemies.clear() ## a death wipes the local pressure
		return damage
	# Shoot closest first.
	enemies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.eta < b.eta)
	var budget := dps * dt
	for e: Dictionary in enemies:
		if budget <= 0.0 or e.eta > REACH_ETA:
			break
		var used := minf(budget, e.hp)
		e.hp -= used
		budget -= used
	var alive: Array[Dictionary] = []
	for e: Dictionary in enemies:
		if e.hp > 0.0:
			alive.append(e)
	enemies.assign(alive)
	return damage
