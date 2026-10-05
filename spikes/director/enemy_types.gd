extends RefCounted
## Abstract enemy stats for the headless simulation (from docs/legacy/GDD.md).
## "approach" = seconds from spawn point (>= 12 m) until in melee range.

const TYPES: Dictionary = {
	"normal": {"hp": 100.0, "dps": 0.6, "approach": 8.0},
	"runner": {"hp": 60.0, "dps": 0.8, "approach": 4.5},
	"brute": {"hp": 320.0, "dps": 2.0, "approach": 10.0},
	"spitter": {"hp": 80.0, "dps": 0.5, "approach": 6.0},
	"breaker": {"hp": 1200.0, "dps": 4.0, "approach": 12.0},
}
