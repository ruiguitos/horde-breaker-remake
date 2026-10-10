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
	_check(ids == [&"rifle", &"shotgun", &"pistol", &"smg", &"marksman"], "5 weapons in slot order (%s)" % [ids])
	_check(GameData.starting_weapons() == ([&"rifle", &"shotgun", &"pistol"] as Array[StringName]), "starting weapons are the free ones")
	_check(GameData.weapon_cost(&"smg") == 60 and GameData.weapon_cost(&"marksman") == 80 and GameData.weapon_cost(&"rifle") == -1,
		"unlock costs: SMG 60, Marksman 80, Rifle not for sale")
	_check(weapons[1].pellets == 8 and is_equal_approx(weapons[0].fire_rate, 9.0), "weapon stats come from the .tres files")
	_check(GameData.cards().size() == 39 and GameData.perks().size() == 5, "39 cards and 5 perks")
	_check(GameData.perks()[0].id == &"thick_skin" and GameData.perks()[0].cost == 40, "perk order and cost")
	var reg: Registry = load(GameData.PERK_REGISTRY)
	var cheap: Array[StringName] = reg.filter(&"cost", func(v: int) -> bool: return v <= 40)
	cheap.sort()
	_check(cheap == ([&"pack_rat", &"thick_skin"] as Array[StringName]), "registry index query: perks costing <= 40 Intel")
	# World data: enemies follow EnemyKind, routes exclude the volcano.
	var enemies: Array[GameData.EnemyType] = GameData.enemy_types()
	_check(enemies.size() == 7 and enemies[GameData.EnemyKind.BRUTE].id == &"brute" and enemies[GameData.EnemyKind.BOSS].id == &"behemoth",
		"7 enemy types indexed by EnemyKind")
	_check(not enemies[GameData.EnemyKind.BRUTE].pushable and is_equal_approx(enemies[GameData.EnemyKind.BRUTE].front_armor, 0.75)
		and enemies[GameData.EnemyKind.BLOATER].explodes and enemies[GameData.EnemyKind.GRABBER].grabs, "enemy flags (armor, grabs, explodes)")
	_check(GameData.ISLAND_BIOMES == ([&"beach", &"town", &"jungle", &"port"] as Array[StringName]) and GameData.BIOMES.has(&"volcano"),
		"4 route biomes + the volcano")
	_check(GameData.BIOMES[&"jungle"]["palms"] and is_equal_approx(GameData.BIOMES[&"jungle"]["fog"], 0.006), "biome look values")
	_check(GameData.MISSIONS.size() == 4 and GameData.MISSIONS[&"defend"]["name"] == "Defend"
		and GameData.ROUTE_MISSIONS == ([&"activate", &"defend", &"rescue"] as Array[StringName]),
		"4 missions, 3 on the boat routes (holdout is expedition-only)")
	_check(GameData.CLASSES == ([&"recruit", &"vanguard"] as Array[StringName]) and GameData.CLASS_INFO[&"vanguard"]["cost"] == 150, "2 classes with costs")
	_check(GameData.modifiers().size() == 5 and is_equal_approx(GameData.modifier(&"swarm").intel_mult, 1.3), "5 route modifiers")
	quit(1 if _failures > 0 else 0)
