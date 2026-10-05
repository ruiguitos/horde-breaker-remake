extends RefCounted
## Static enemy table shared by both directors and the simulated player.
## hp: health; dps: damage per second dealt to the player while engaged;
## w0/w1: spawn weight at run start / run end (lerped by progress);
## from: minimum run progress (0..1) before the type can spawn.
## Order matters: the simulated player shoots types in this priority order
## (fast and dangerous specials first, like a real player would).

const TYPES: Array[Dictionary] = [
	{"name": "screamer", "hp": 80.0, "dps": 0.5, "w0": 0.0, "w1": 2.0, "from": 0.15},
	{"name": "grabber", "hp": 120.0, "dps": 2.0, "w0": 0.0, "w1": 3.0, "from": 0.25},
	{"name": "runner", "hp": 60.0, "dps": 1.2, "w0": 10.0, "w1": 18.0, "from": 0.0},
	{"name": "bloater", "hp": 150.0, "dps": 3.0, "w0": 0.0, "w1": 3.0, "from": 0.3},
	{"name": "spitter", "hp": 80.0, "dps": 1.5, "w0": 3.0, "w1": 8.0, "from": 0.05},
	{"name": "normal", "hp": 100.0, "dps": 1.0, "w0": 85.0, "w1": 45.0, "from": 0.0},
	{"name": "brute", "hp": 320.0, "dps": 2.5, "w0": 2.0, "w1": 14.0, "from": 0.1},
	{"name": "armored", "hp": 400.0, "dps": 1.5, "w0": 0.0, "w1": 7.0, "from": 0.4},
	{"name": "boss", "hp": 1200.0, "dps": 6.0, "w0": 0.0, "w1": 0.0, "from": 2.0},
]

const BOSS := 8


static func count() -> int:
	return TYPES.size()


static func hp(i: int) -> float:
	return TYPES[i]["hp"]


static func dps(i: int) -> float:
	return TYPES[i]["dps"]


## Picks a type index by weighted random for a given progress (0..1).
## extra_weight lets a caller bias a type (legacy director uses "heavier" levels).
static func pick(rng: RandomNumberGenerator, progress: float, heavy_bias: float = 0.0) -> int:
	var total := 0.0
	var weights: Array[float] = []
	for t: Dictionary in TYPES:
		var w := 0.0
		if progress >= float(t["from"]):
			w = lerpf(float(t["w0"]), float(t["w1"]), clampf(progress, 0.0, 1.0))
			if float(t["hp"]) >= 300.0:
				w *= 1.0 + heavy_bias
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0 and weights[i] > 0.0:
			return i
	return 5  # normal
