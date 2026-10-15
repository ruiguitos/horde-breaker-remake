extends SceneTree
## Game data from YARD registries: every entry loads, ids and order are
## stable, derived rules (starting weapons, unlock costs) match the design,
## and the registry index answers queries without loading resources.
## Run: godot --headless --path . --script res://tests/test_data.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var weapons: Array[GameData.Weapon] = GameData.weapons()
	var ids: Array = weapons.map(func(w: GameData.Weapon) -> StringName: return w.id)
	_check(ids == [&"rifle", &"shotgun", &"marksman", &"smg", &"machine_gun"], "5 weapons in catalog order (%s)" % [ids])
	_check(GameData.starting_weapons() == ([&"rifle", &"shotgun"] as Array[StringName]), "starting weapons are the free ones")
	_check(GameData.weapon_cost(&"smg") == 60 and GameData.weapon_cost(&"marksman") == 80 and GameData.weapon_cost(&"rifle") == -1,
		"unlock costs: SMG 60, Marksman 80, Rifle not for sale")
	_check(weapons[1].pellets == 8 and is_equal_approx(weapons[0].fire_rate, 9.0), "weapon stats come from the .tres files")
	# Perk tree: 9 nodes x A/B, plus the Vanguard variants of Breaker III.
	_check(GameData.cards().size() == 39 and GameData.perks().size() == 20, "39 cards and 20 perk alternatives")
	_check(GameData.perks()[0].id == &"head_hunter" and GameData.perks()[0].node() == &"combat_1"
		and GameData.perk_rank_cost(1, 1) == 40, "perk order, node and cost")
	var reg: Registry = load(GameData.PERK_REGISTRY)
	var tier_one: Array[StringName] = reg.filter(&"tier", func(v: int) -> bool: return v == 1)
	var expected: Array[StringName] = [&"body_count", &"crowd_anchor", &"fleet_footed", &"head_hunter", &"long_breaker", &"thick_skin"]
	_check(tier_one.size() == expected.size() and expected.all(func(id: StringName) -> bool: return tier_one.has(id)),
		"registry index query: tier I perks")
	# World data: enemies follow EnemyKind, routes exclude the volcano.
	var enemies: Array[GameData.EnemyType] = GameData.enemy_types()
	_check(enemies.size() == 7 and enemies[GameData.EnemyKind.BRUTE].id == &"brute" and enemies[GameData.EnemyKind.BOSS].id == &"behemoth",
		"7 enemy types indexed by EnemyKind")
	_check(not enemies[GameData.EnemyKind.BRUTE].pushable and is_equal_approx(enemies[GameData.EnemyKind.BRUTE].front_armor, 0.75)
		and enemies[GameData.EnemyKind.BLOATER].explodes and enemies[GameData.EnemyKind.GRABBER].grabs, "enemy flags (armor, grabs, explodes)")
	_check(GameData.ISLAND_BIOMES == ([&"beach", &"town", &"jungle", &"port"] as Array[StringName]) and GameData.BIOMES.has(&"volcano"),
		"4 route biomes + the volcano")
	_check(GameData.BIOMES[&"jungle"]["palms"] and is_equal_approx(GameData.BIOMES[&"jungle"]["fog"], 0.006), "biome look values")
	_check(GameData.MISSIONS.size() == 11 and GameData.MISSIONS[&"defend"]["name"] == "Defend"
		and GameData.ROUTE_MISSIONS == ([&"activate", &"defend", &"rescue", &"hold_sequence", &"fuel_run", &"nests", &"intel_search", &"signals", &"sabotage", &"escort"] as Array[StringName]),
		"11 missions, 10 on the boat routes (holdout is expedition-only)")
	_check(GameData.CLASSES == ([&"recruit", &"vanguard"] as Array[StringName]) and GameData.CLASS_INFO[&"vanguard"]["cost"] == 150, "2 classes with costs")
	_check(GameData.modifiers().size() == 5 and is_equal_approx(GameData.modifier(&"swarm").intel_mult, 1.3), "5 route modifiers")
	_test_xp_scale(enemies)
	quit(1 if _failures > 0 else 0)


func _test_xp_scale(enemies: Array[GameData.EnemyType]) -> void:
	var costs: Dictionary[int, int] = {1: 150, 5: 630, 10: 1680, 15: 3230, 20: 5280, 25: 7830, 30: 10880}
	for level: int in costs:
		_check(GameData.xp_for_level(level) == costs[level], "level %d costs %d XP" % [level, costs[level]])
	var total: int = 0
	for level in range(1, 30):
		total += GameData.xp_for_level(level)
	_check(total == 113970, "level 1 to 30 costs 113970 received XP")
	var rewards: Array[int] = [10, 12, 100, 45, 1000, 45, 60]  # EnemyKind order
	for kind in rewards.size():
		_check(enemies[kind].xp == rewards[kind], "%s rewards %d base XP" % [enemies[kind].id, rewards[kind]])
