extends RefCounted
## Runs one 25-minute simulation of a director against a simulated player.

const EnemyTypes := preload("res://spikes/director/enemy_types.gd")
const SimPlayer := preload("res://spikes/director/sim_player.gd")
const HordeDirector := preload("res://spikes/director/horde_director.gd")
const LegacyDirector := preload("res://spikes/director/legacy_director.gd")

const RUN_LENGTH := 1500.0
const DT := 0.5
const PROFILES: Dictionary = {
	"weak": {"dps": 260.0, "mitigation": 0.0},
	"medium": {"dps": 380.0, "mitigation": 0.3},
	"strong": {"dps": 540.0, "mitigation": 0.55},
}
const CSV_HEADER := "time,intensity,phase,active,budget,spawns,near,hp,deaths,events"


## Returns {rows: Array[Dictionary], director, player}.
static func run(director_kind: String, profile: String, seed_value: int = 7) -> Dictionary:
	var p: Dictionary = PROFILES[profile]
	var player = SimPlayer.new(profile, p.dps, p.mitigation)
	var director = HordeDirector.new(seed_value) if director_kind == "l4d" else LegacyDirector.new(seed_value)
	var enemies: Array[Dictionary] = []
	var rows: Array[Dictionary] = []
	var damage := 0.0
	var t := 0.0
	while t < RUN_LENGTH:
		var near := 0
		for e: Dictionary in enemies:
			if e.eta <= 0.0:
				near += 1
		var spawned: Array[String] = director.update(t, DT, enemies.size(), near, damage)
		if director_kind == "l4d" and director.relax_started:
			# Off-screen culling: enemies still walking in are removed (not killed).
			enemies.assign(enemies.filter(func(e: Dictionary) -> bool:
				return e.eta <= SimPlayer.REACH_ETA))
		for type_name in spawned:
			var s: Dictionary = EnemyTypes.TYPES[type_name]
			enemies.append({"type": type_name, "hp": s.hp, "eta": s.approach})
		var active_after_spawn := enemies.size()
		for e: Dictionary in enemies:
			e.eta -= DT
		damage = player.step(enemies, DT, EnemyTypes.TYPES)
		# Intensity of the legacy director is computed the same way, for comparison only.
		if director_kind != "l4d":
			director.intensity = clampf(director.intensity + damage * 1.6 + near * 0.12 * DT
				- (6.0 * DT if near < 3 and damage <= 0.0 else 0.0), 0.0, 100.0)
		rows.append({
			"time": t, "intensity": director.intensity, "phase": director.phase_name(),
			"active": active_after_spawn, "budget": director.budget, "spawns": spawned.size(),
			"near": near, "hp": player.hp, "deaths": player.deaths,
			"events": "|".join(director.events),
		})
		t += DT
	return {"rows": rows, "director": director, "player": player}


static func to_csv(rows: Array[Dictionary]) -> String:
	var lines: PackedStringArray = [CSV_HEADER]
	for r in rows:
		lines.append("%.1f,%.1f,%s,%d,%d,%d,%d,%.1f,%d,%s" % [r.time, r.intensity, r.phase,
			r.active, r.budget, r.spawns, r.near, r.hp, r.deaths, r.events])
	return "\n".join(lines) + "\n"
