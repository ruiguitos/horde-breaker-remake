extends SceneTree
## Perk tree (docs/design/CARDS_WEAPONS_PERKS.md §F2): costs, prerequisites,
## ranks shared by A/B, free switching, slots, only equipped perks act,
## save migration (v6 and older, run twice), class variants, Quick Redeploy,
## every perk's benefit and trade-off, the Body Count card filter, Kill
## Chain (direct primary kills only), Skirmisher (no speed bonus while sprinting)
## and the Armory screen (focus, LB/RB, icon hints, layout).
## Run: godot --headless --path . --script res://tests/test_perk_tree.gd

const DT: float = 1.0 / 60.0
const SAVE_PATH: String = "user://test_perk_tree_profile.json"

class MemoryProfile extends Profile:
	func save(_path: String = Profile.PATH) -> bool:
		return true

var _failures: int = 0
var _checks: int = 0


func _initialize() -> void:
	GameInput.setup()
	call_deferred("_run_all")


func _run_all() -> void:
	_test_catalog()
	_test_costs_and_prerequisites()
	_test_shared_ranks_and_switching()
	_test_slots_and_equipping()
	_test_only_equipped_act()
	_test_migration()
	_test_class_variants()
	_test_redeploy()
	_test_combat_effects()
	_test_survival_effects()
	_test_breaker_effects()
	_test_body_count_cards()
	_test_kill_chain_direct_only()
	_test_skirmisher_sprint_fire()
	_test_logistics_costs()
	_test_logistics_effects()
	_test_logistics_integration()
	await _test_logistics_one_click()
	await _test_armory_screen()
	await _test_perk_layout_1600()
	await _test_perk_containment()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if _failures == 0:
		print("TEST: perk tree OK (%d checks)" % _checks)
	# Freed armories and their sounds are released by the audio thread a few hundred ms later.
	await create_timer(0.3).timeout
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if ok:
		print("TEST: " + what)
	else:
		_failures += 1
		print("TEST FAIL: " + what)


func _settle() -> void:
	await process_frame
	await process_frame


## An island run with these perks equipped ({id: rank}).
func _run(perks: Dictionary, player_class: StringName = &"recruit") -> IslandRun:
	var ctx := RunContext.new(5)
	ctx.apply_class(player_class)
	var ids: Array[StringName] = []
	for id: StringName in perks:
		ids.append(id)
	ctx.apply_perks(ids, perks)
	var run := IslandRun.new(ctx.island_seed())
	run.load_context(ctx)
	run.director.max_alive = 0
	return run


## A walker `dist` m away, `angle_deg` off the facing (0, 0, -1).
func _enemy(run: IslandRun, dist: float, angle_deg: float, hp: float = 1000.0) -> int:
	var dir := Vector3(0, 0, -1).rotated(Vector3.UP, deg_to_rad(angle_deg))
	var i: int = run.horde.add(run.player_pos + dir * dist, GameData.EnemyKind.WALKER, run.rng)
	run.horde.hp[i] = hp
	run.horde.stun[i] = 10.0
	run.facing = Vector3(0, 0, -1)
	return i


## Damage of one primary shot at a body (not head) target.
func _body_shot(run: IslandRun) -> float:
	var i: int = _enemy(run, 5.0, 25.0)
	var before: float = run.horde.hp[i]
	run.call("_fire", run.weapons[0], i)
	return before - run.horde.hp[i]


func _profile(intel: int = 2000) -> Profile:
	var p := MemoryProfile.new()
	p.intel = intel
	return p


# --- Data ---------------------------------------------------------------------

func _test_catalog() -> void:
	var nodes: Array[StringName] = GameData.perk_nodes()
	_check(nodes.size() == 12 and nodes[0] == &"combat_1" and nodes[8] == &"breaker_3" and nodes[11] == &"logistics_3",
		"12 nodes: 4 branches x 3 tiers, Logistics last")
	var complete: bool = true
	for node in nodes:
		var logistics: bool = GameData.perk_node_branch(node) == &"logistics"
		for option in 2:
			for player_class in GameData.CLASSES:
				var perk: GameData.Perk = GameData.perk_for(node, option, player_class)
				if perk == null or perk.benefit_values.size() != 3 or perk.benefit == "":
					complete = false
					continue
				# The three old branches give every alternative a trade-off; Logistics gives benefits only.
				if logistics:
					complete = complete and perk.penalty == "" and perk.penalty_values.is_empty()
				else:
					complete = complete and perk.penalty != "" and perk.penalty_values.size() == 3
	_check(complete, "every node has A and B for every class with 3 rank values; combat, survival and breaker add a trade-off, logistics none")
	for id: StringName in [&"thick_skin", &"pack_rat", &"head_hunter", &"long_breaker", &"demolitions"]:
		_check(GameData.perk(id) != null and GameData.perk(id).option == 0, "old perk id %s kept as alternative A" % id)
	_check(GameData.perk_text("Headshot cone {v}°", 13.0) == "Headshot cone 13°" and GameData.perk_text("{v} HP", 0.4) == "0.4 HP",
		"perk text formats whole and decimal values")


# --- Profile ------------------------------------------------------------------

func _test_costs_and_prerequisites() -> void:
	var expected: Array = [[40, 60, 80], [60, 90, 120], [100, 140, 180]]
	var ok: bool = true
	for tier in range(1, 4):
		for rank in range(1, 4):
			ok = ok and GameData.perk_rank_cost(tier, rank) == expected[tier - 1][rank - 1]
	_check(ok, "rank costs per tier: 40/60/80, 60/90/120, 100/140/180")
	var p := _profile(1000)
	_check(p.rank_problem(&"combat_2").begins_with("Requires") and not p.buy_rank(&"combat_2") and p.intel == 1000,
		"tier II needs rank I of tier I in the branch")
	_check(p.buy_rank(&"combat_1") and p.intel == 960, "rank I of a tier I node costs 40")
	_check(p.buy_rank(&"combat_2") and p.intel == 900 and p.rank_problem(&"breaker_2").begins_with("Requires"),
		"tier II unlocks with rank I above (other branches stay locked)")
	_check(p.equipped_perks.is_empty(), "buying ranks never equips")
	p.buy_rank(&"combat_1")
	p.buy_rank(&"combat_1")
	_check(p.node_rank(&"combat_1") == 3 and p.intel == 760 and p.rank_problem(&"combat_1") == "Max rank" and not p.buy_rank(&"combat_1"),
		"three ranks per node, then max (40 + 60 + 80)")
	var poor := _profile(30)
	_check(poor.rank_problem(&"combat_1") == "Not enough Intel" and not poor.buy_rank(&"combat_1") and poor.intel == 30, "needs the Intel")
	var p3 := _profile(1000)
	p3.buy_rank(&"survival_1")
	p3.buy_rank(&"survival_2")
	_check(p3.buy_rank(&"survival_3") and p3.intel == 1000 - 40 - 60 - 100, "tier III costs 100 once tier II has rank I")


func _test_shared_ranks_and_switching() -> void:
	var p := _profile(1000)
	p.buy_rank(&"combat_1")
	p.buy_rank(&"combat_1")
	_check(p.owns_perk(&"head_hunter") and p.owns_perk(&"body_count"), "a node's rank unlocks both alternatives")
	p.toggle_equip(&"head_hunter")
	var intel: int = p.intel
	_check(p.switch_option(&"combat_1") and p.equipped_perks == [&"body_count"] and p.intel == intel,
		"switching A -> B is free and swaps the equipped perk in place")
	_check(p.equipped_rank(&"body_count") == 2, "B uses the rank bought for the node")
	p.switch_option(&"combat_1")
	_check(p.equipped_perks == [&"head_hunter"] and p.equipped_rank(&"head_hunter") == 2 and p.intel == intel, "and back to A, still free")
	_check(p.set_use_rank(&"combat_1", 1) and p.equipped_rank(&"head_hunter") == 1 and p.intel == intel,
		"choosing a lower bought rank is free")
	_check(not p.set_use_rank(&"combat_1", 3), "a rank not bought cannot be chosen")
	p.buy_rank(&"combat_1")
	_check(p.equipped_rank(&"head_hunter") == 3, "a new rank is used at once")
	_check(p.cycle_use_rank(&"combat_1") and p.use_rank(&"combat_1") == 2 and p.cycle_use_rank(&"combat_1") and p.use_rank(&"combat_1") == 1
		and p.cycle_use_rank(&"combat_1") and p.use_rank(&"combat_1") == 3, "the rank button cycles III -> II -> I -> III")


func _test_slots_and_equipping() -> void:
	var p := _profile(1000)
	for node: StringName in [&"combat_1", &"survival_1", &"breaker_1", &"combat_2"]:
		p.buy_rank(node)
	_check(p.slots == 1 and p.toggle_equip(&"head_hunter") and not p.toggle_equip(&"thick_skin"), "one free slot")
	_check(p.toggle_equip(&"body_count") and p.equipped_perks == [&"body_count"], "the other alternative replaces, never both")
	_check(p.next_slot_cost() == 100 and p.buy_slot() and p.toggle_equip(&"thick_skin"), "2nd slot costs 100 Intel")
	_check(p.next_slot_cost() == 250 and p.buy_slot() and p.toggle_equip(&"long_breaker") and p.slots == 3, "3rd slot costs 250 Intel")
	_check(not p.toggle_equip(&"steady_grip") and p.next_slot_cost() == -1, "no 4th slot")
	_check(p.toggle_equip(&"thick_skin") and not p.equipped_perks.has(&"thick_skin") and p.toggle_equip(&"steady_grip"),
		"removing frees the slot (no branch quota)")
	_check(not p.toggle_equip(&"opening_volley"), "a perk whose node has no rank cannot be equipped")


func _test_only_equipped_act() -> void:
	var p := _profile(1000)
	p.buy_rank(&"survival_1")
	p.buy_rank(&"survival_1")
	p.buy_rank(&"survival_1")
	var ctx := RunContext.new(3)
	ctx.apply_class(p.selected_class)
	ctx.apply_perks(p.equipped_perks, p.equipped_perk_ranks())
	_check(ctx.max_hp == GameData.PLAYER_MAX_HP and ctx.perks.is_empty(), "owned but unequipped perks do nothing")
	p.toggle_equip(&"thick_skin")
	ctx = RunContext.new(3)
	ctx.apply_class(p.selected_class)
	ctx.apply_perks(p.equipped_perks, p.equipped_perk_ranks())
	_check(ctx.max_hp == GameData.PLAYER_MAX_HP + 30.0 and ctx.perk_rank(&"thick_skin") == 3, "equipped: Thick Skin III gives +30 HP")
	var run := IslandRun.new(3)
	run.load_context(ctx)
	_check(run.has_perk(&"thick_skin") and not run.has_perk(&"fleet_footed") and is_equal_approx(run.perk_speed_mult(), 1.0),
		"the run only knows the equipped perk")


func _test_migration() -> void:
	var v6: Dictionary = {"version": 6, "intel": 77, "slots": 2, "selected_class": "vanguard",
		"unlocked_classes": ["recruit", "vanguard"],
		"owned_perks": ["thick_skin", "head_hunter", "demolitions", "pack_rat"],
		"equipped_perks": ["demolitions", "thick_skin"],
		"last_run": {"class": "vanguard", "perks": ["thick_skin"], "threat": 1, "expedition": ""}}
	var p := Profile.from_dict(v6)
	_check(p.node_rank(&"survival_1") == 3 and p.node_rank(&"survival_2") == 3 and p.node_rank(&"combat_1") == 3 and p.node_rank(&"breaker_3") == 3,
		"old perks become rank III of their node")
	_check(p.node_rank(&"breaker_1") == 1 and p.node_rank(&"breaker_2") == 1 and p.node_rank(&"combat_2") == 0 and p.node_rank(&"survival_3") == 0,
		"predecessors get rank I; nothing else is granted")
	_check(p.perk_option(&"combat_1") == 0 and p.perk_option(&"survival_2") == 0, "migrated nodes are on alternative A")
	_check(p.intel == 77 and p.slots == 2, "Intel and slots preserved")
	_check(p.equipped_perks == [&"thick_skin"] and p.perk_notice.contains("Recruit-only"),
		"Demolitions equipped on a Vanguard is removed with a notice (still owned)")
	_check(p.owns_perk(&"demolitions"), "Demolitions stays owned")
	# Idempotent: migrating again changes nothing; a v7 save does not migrate.
	var ranks: Dictionary = p.perk_ranks.duplicate()
	p.migrate_legacy_perks(v6["owned_perks"], v6["equipped_perks"])
	_check(p.perk_ranks == ranks and p.equipped_perks == [&"thick_skin"] and p.intel == 77, "running the migration twice is a no-op")
	_check(p.save(SAVE_PATH), "migrated profile saves")
	var text: String = FileAccess.get_file_as_string(SAVE_PATH)
	var saved: Dictionary = JSON.parse_string(text)
	_check(int(saved["version"]) == 7 and not saved.has("owned_perks"), "saves as version 7 without the flat perk list")
	var again := Profile.load_profile(SAVE_PATH)
	_check(again.perk_ranks == p.perk_ranks and again.equipped_perks == p.equipped_perks and again.perk_options == p.perk_options
		and again.intel == 77 and again.perk_notice == "", "loading the v7 save keeps the tree and does not migrate again")
	var twice := Profile.from_dict(saved)
	twice.migrate_legacy_perks(v6["owned_perks"], [])
	_check(twice.perk_ranks == p.perk_ranks, "a migrated save migrated again is unchanged")
	# A Recruit keeps Demolitions equipped.
	var recruit := Profile.from_dict({"version": 6, "owned_perks": ["demolitions"], "equipped_perks": ["demolitions"]})
	_check(recruit.equipped_perks == [&"demolitions"] and recruit.perk_notice == "", "a Recruit keeps Demolitions equipped")
	# Very old saves (no perks at all) still load.
	var v1 := Profile.from_dict({"intel": 12})
	_check(v1.perk_ranks.is_empty() and v1.equipped_perks.is_empty() and v1.intel == 12 and v1.slots == 1, "a version 1 save loads with an empty tree")
	# Version 6 weapon fields survive the bump.
	var weapons := Profile.from_dict({"version": 6, "unlocked_weapons": ["smg", "marksman"], "selected_primary": "smg",
		"selected_secondary": "marksman"})
	_check(weapons.selected_primary == &"smg" and weapons.selected_secondary == &"marksman",
		"v6 weapon fields still load")


func _test_class_variants() -> void:
	_check(GameData.perk_for(&"breaker_3", 0, &"recruit").id == &"demolitions" and GameData.perk_for(&"breaker_3", 0, &"vanguard").id == &"bulwark"
		and GameData.perk_for(&"breaker_3", 1, &"recruit").id == &"concussion_blast" and GameData.perk_for(&"breaker_3", 1, &"vanguard").id == &"intimidating_cry",
		"Breaker III has a variant per class")
	_check(GameData.perk_for(&"combat_1", 0, &"vanguard").id == &"head_hunter", "other nodes are shared by both classes")
	var p := _profile(1000)
	p.unlocked_classes = [&"recruit", &"vanguard"]
	for node: StringName in [&"breaker_1", &"breaker_2", &"breaker_3"]:
		p.buy_rank(node)
	_check(p.toggle_equip(&"demolitions") and not p.toggle_equip(&"bulwark"), "a Recruit cannot equip the Vanguard variant")
	p.selected_class = &"vanguard"
	_check(p.sync_perks_to_class() and p.equipped_perks == [&"bulwark"], "changing class swaps to that class's variant (same node, A/B)")
	var ctx := RunContext.new(2)
	ctx.apply_class(&"vanguard")
	var ids: Array[StringName] = [&"demolitions", &"bulwark"]
	ctx.apply_perks(ids, {&"demolitions": 3, &"bulwark": 1})
	_check(ctx.perks == [&"bulwark"] and ctx.perk_rank(&"bulwark") == 1, "a run drops perks of another class")


func _test_redeploy() -> void:
	var p := _profile(2000)
	p.unlocked_classes = [&"recruit", &"vanguard"]
	for k in 3:
		p.buy_rank(&"combat_1")
	p.buy_slot()
	p.buy_rank(&"breaker_1")
	p.switch_option(&"combat_1")
	p.toggle_equip(&"body_count")
	p.set_use_rank(&"combat_1", 2)
	p.toggle_equip(&"long_breaker")
	p.remember_run(&"")
	_check(p.last_run["perks"] == ["body_count", "long_breaker"] and p.last_run["perk_ranks"] == {"body_count": 2, "long_breaker": 1},
		"the last run remembers perks, A/B and ranks")
	p.switch_option(&"combat_1")
	p.set_use_rank(&"combat_1", 3)
	p.toggle_equip(&"long_breaker")
	_check(p.redeploy_problem() == "" and p.apply_last_run(), "the run can be replayed")
	_check(p.equipped_perks == [&"body_count", &"long_breaker"] and p.equipped_rank(&"body_count") == 2 and p.perk_option(&"combat_1") == 1,
		"redeploy restores the perks with their A/B choice and ranks")
	var main_script: GDScript = load("res://game/main.gd")
	var main: Node = main_script.new()
	main.set("profile", p)
	var ctx: RunContext = main.call("_fresh_context")
	_check(ctx.perks == [&"body_count", &"long_breaker"] and ctx.perk_rank(&"body_count") == 2 and ctx.perk_rank(&"long_breaker") == 1,
		"the redeployed run context carries the perks and ranks")
	main.free()
	# Falls back safely: a rank above what is bought is clamped; old saves
	# without ranks use the bought rank; a perk not owned opens the Armory.
	p.last_run["perk_ranks"] = {"body_count": 3, "long_breaker": 3}
	_check(p.apply_last_run() and p.equipped_rank(&"long_breaker") == 1 and p.equipped_rank(&"body_count") == 3,
		"ranks above the bought rank are clamped")
	p.last_run.erase("perk_ranks")
	_check(p.apply_last_run() and p.equipped_rank(&"body_count") == 3, "a last run without ranks uses the bought rank")
	p.last_run["perks"] = ["opening_volley"]
	_check(p.redeploy_problem() == "Perk not owned" and not p.apply_last_run(), "a perk not owned blocks the replay")
	p.last_run["perks"] = ["demolitions"]
	p.last_run["class"] = "vanguard"
	_check(p.redeploy_problem() != "", "a perk of another class blocks the replay")


# --- Effects: each benefit and trade-off ----------------------------------------

## Logistics (the fourth branch): the same costs and prerequisites as the others.
func _test_logistics_costs() -> void:
	var p := _profile(1000)
	_check(p.rank_problem(&"logistics_2").begins_with("Requires") and not p.buy_rank(&"logistics_2") and p.intel == 1000,
		"logistics II needs rank I of logistics I")
	_check(p.buy_rank(&"logistics_1") and p.intel == 960, "logistics I costs 40")
	_check(p.buy_rank(&"logistics_2") and p.intel == 900 and p.buy_rank(&"logistics_3") and p.intel == 800,
		"logistics II costs 60 and III costs 100 once the tier above has rank I")
	_check(p.rank_problem(&"logistics_1") == "" and p.node_rank(&"logistics_1") == 1 and p.equipped_perks.is_empty(),
		"buying logistics ranks never equips")


## Each logistics alternative acts on the system it names, at its rank, and only when equipped.
func _test_logistics_effects() -> void:
	var weapon: int = -1
	var probe := _run({})
	for w in probe.weapons.size():
		if probe.weapons[w].max_ammo > 0 and weapon == -1:
			weapon = w
	# Supply Run III: a cache heals 30 HP and restocks half of a finite weapon's ammo.
	var supply := _run({&"supply_run": 3})
	supply.hp = 50.0
	supply.ammo[weapon] = 0
	supply.call("_logistics_on_cache")
	_check(is_equal_approx(supply.hp, 80.0), "Supply Run III: a supply cache heals 30 HP (%.0f)" % supply.hp)
	_check(supply.ammo[weapon] == int(supply.max_ammo(weapon) * 50.0 / 100.0), "Supply Run III: a cache restocks 50%% of the finite ammo (%d)" % supply.ammo[weapon])
	var plain := _run({})
	plain.hp = 50.0
	plain.call("_logistics_on_cache")
	_check(is_equal_approx(plain.hp, 50.0), "without Supply Run a cache adds no healing of its own")
	# Archivist II: each cache gives 20 Intel on top of its own.
	var archivist := _run({&"archivist": 2})
	archivist.cache_intel = 0
	archivist.call("_logistics_on_cache")
	_check(archivist.cache_intel == 20, "Archivist II: a cache gives 20 Intel (%d)" % archivist.cache_intel)
	# First Find II: the first two caches of the island give a card screen each; later ones give none.
	var find := _run({&"first_find": 2})
	find._pending_levels = 0
	for k in 3:
		find.call("_logistics_on_cache")
	_check(find._pending_levels == 2 and find.cache_cards_left == 0, "First Find II: the first two caches give a card, the third does not (%d)" % find._pending_levels)
	# Spare Rerolls II: the island's first card screen gets two more redraws, and only that one.
	var spare := _run({&"spare_rerolls": 2})
	spare._pending_levels = 2
	spare._roll_cards_if_needed()
	var first: int = spare.rerolls
	spare.choose_card(0)  # the next screen opens at once
	_check(first == GameData.REROLLS_PER_SCREEN + 2 and spare.rerolls == GameData.REROLLS_PER_SCREEN and spare.spare_rerolls_left == 0,
		"Spare Rerolls II: the first card screen has %d rerolls, the next one the usual %d" % [first, spare.rerolls])
	# Quick Hands I: a cache takes 25% less time to open (0.5 s of standing there gives 0.625 s of progress).
	var quick := _run({&"quick_hands": 1})
	quick.player_pos = quick.map.caches[0]
	quick.call("_update_caches", 0.5)
	_check(is_equal_approx(quick.cache_progress[0], 0.625), "Quick Hands I: interactions run 25%% faster (%.3f)" % quick.cache_progress[0])
	var slow := _run({})
	slow.player_pos = slow.map.caches[0]
	slow.call("_update_caches", 0.5)
	_check(is_equal_approx(slow.cache_progress[0], 0.5), "without Quick Hands the same interaction runs at normal speed")
	# Resupply Drop I: a drop refills 30% more than the usual third.
	var drop := _run({&"resupply_drop": 1})
	drop.ammo[weapon] = 0
	drop.call("_refill_third", drop.resupply_mult())
	var boosted: int = drop.ammo[weapon]
	drop.ammo[weapon] = 0
	drop.call("_refill_third")
	_check(is_equal_approx(drop.resupply_mult(), 1.3) and boosted == int(drop.max_ammo(weapon) / 3.0 * drop.resupply_mult()) and drop.ammo[weapon] == drop.max_ammo(weapon) / 3,
		"Resupply Drop I: a generator, signal or escort stop refills 30%% more; other refills stay the same (%d / %d)" % [boosted, drop.ammo[weapon]])


## Logistics through the real updates: a cache that opens (once), a generator that comes online, the
## per-island counters on a second island, the rank values of each perk, and a lower used rank.
func _test_logistics_integration() -> void:
	var weapon: int = -1
	var probe := _run({})
	for w in probe.weapons.size():
		if probe.weapons[w].max_ammo > 0 and weapon == -1:
			weapon = w
	# A cache opens once: its Supply Run, Archivist and First Find rewards land exactly once.
	var cache := _run({&"supply_run": 1, &"archivist": 1, &"first_find": 1})
	cache.player_pos = cache.map.caches[0]
	cache.call("_update_caches", GameData.CACHE_OPEN_TIME + 0.1)
	cache.call("_update_caches", 1.0)
	var supply_lines: int = 0
	var archivist_lines: int = 0
	for line: String in cache.messages:
		supply_lines += 1 if line.begins_with("Supply Run") else 0
		archivist_lines += 1 if line.begins_with("Archivist") else 0
	_check(supply_lines == 1 and archivist_lines == 1 and cache._pending_levels == 1,
		"a cache opened by standing there pays each logistics reward once (%d, %d, %d card screens)" % [supply_lines, archivist_lines, cache._pending_levels])
	# A generator held for its time comes online once, with a 30% bigger drop (Resupply Drop I).
	var gen := _run({&"resupply_drop": 1})
	if gen.map.generators.size() >= GameData.GENERATOR_COUNT and weapon != -1:
		gen.player_pos = gen.map.generators[0]
		gen.ammo[weapon] = 0
		gen.call("_update_generators", GameData.GENERATOR_HOLD_SECONDS)
		_check(gen.ammo[weapon] == int(gen.max_ammo(weapon) / 2.0 * 1.3), "a generator that comes online refills 30%% more (%d)" % gen.ammo[weapon])
	# The next island starts its counters again (First Find, Spare Rerolls), and a bonus reroll adds to the first screen.
	var ctx := RunContext.new(5)
	var ids: Array[StringName] = [&"first_find", &"spare_rerolls"]
	ctx.apply_perks(ids, {&"first_find": 2, &"spare_rerolls": 2})
	var first := IslandRun.new(ctx.island_seed())
	first.load_context(ctx)
	first.call("_logistics_on_cache")
	first.call("_logistics_on_cache")
	var second := IslandRun.new(ctx.island_seed())
	second.load_context(ctx)
	_check(first.cache_cards_left == 0 and second.cache_cards_left == 2 and second.spare_rerolls_left == 2,
		"each island starts with its own First Find (2) and Spare Rerolls (2) counters")
	second._pending_levels = 1
	second.bonus_rerolls = 1
	second._roll_cards_if_needed()
	_check(second.rerolls == GameData.REROLLS_PER_SCREEN + 1 + 2 and second.spare_rerolls_left == 0,
		"Spare Rerolls adds to the Extra Reroll bonus on the first screen (%d rerolls)" % second.rerolls)
	# Each logistics perk has its values at ranks I, II and III.
	var values: Dictionary = {
		&"supply_run": [[10, 20, 30], [20, 35, 50]], &"quick_hands": [[25, 35, 45], []], &"archivist": [[10, 20, 30], []],
		&"resupply_drop": [[30, 45, 60], []], &"first_find": [[1, 2, 3], []], &"spare_rerolls": [[1, 2, 3], []],
	}
	var table_ok: bool = true
	for id: StringName in values:
		var perk: GameData.Perk = GameData.perk(id)
		for rank in range(1, 4):
			table_ok = table_ok and perk != null and is_equal_approx(perk.value(rank), values[id][0][rank - 1])
			if values[id][1].size() == 3:
				table_ok = table_ok and is_equal_approx(perk.value_2(rank), values[id][1][rank - 1])
	_check(table_ok, "the six logistics perks have their rank I/II/III values")
	# A bought rank III used at rank I acts at rank I (Use Rank), like every other perk.
	var profile := _profile(1000)
	for k in 3:
		profile.buy_rank(&"logistics_1")
	profile.toggle_equip(&"supply_run")
	profile.set_use_rank(&"logistics_1", 1)
	_check(profile.equipped_perk_ranks()[&"supply_run"] == 1, "a bought rank III used at rank I equips at rank I")


## One click on a node that is not owned yet buys its rank I; an owned node opens its actions instead;
## a locked node buys nothing; a click with too little Intel buys nothing.
func _test_logistics_one_click() -> void:
	var profile := _profile(500)
	profile.unlocked_classes = [&"recruit", &"vanguard"]
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	await _settle()
	armory.call("_select_category", "PERKS")
	await _settle()
	(armory.get("_perk_buttons")[&"logistics_2"] as Button).pressed.emit()
	await _settle()
	_check(profile.node_rank(&"logistics_2") == 0 and profile.intel == 500, "a locked node is not bought by a click")
	_check((armory.find_child("PerkRequirement", true, false) as Label) != null, "a locked node says what it needs")
	(armory.get("_perk_buttons")[&"logistics_1"] as Button).pressed.emit()
	await _settle()
	_check(profile.node_rank(&"logistics_1") == 1 and profile.intel == 460, "one click buys logistics I (40 Intel)")
	(armory.get("_perk_buttons")[&"logistics_1"] as Button).pressed.emit()
	await _settle()
	_check(profile.node_rank(&"logistics_1") == 1 and profile.intel == 460, "a click on an owned node buys no rank: its actions open")
	(armory.get("_perk_buttons")[&"logistics_2"] as Button).pressed.emit()
	await _settle()
	_check(profile.node_rank(&"logistics_2") == 1 and profile.intel == 400, "the next tier is one click away once the tier above is owned")
	profile.intel = 30
	(armory.get("_perk_buttons")[&"logistics_3"] as Button).pressed.emit()
	await _settle()
	_check(profile.node_rank(&"logistics_3") == 0 and profile.intel == 30, "a click without enough Intel buys nothing")
	var equip: Button = null
	(armory.get("_perk_buttons")[&"logistics_1"] as Button).pressed.emit()
	await _settle()
	equip = armory.find_child("PerkEquip", true, false) as Button
	_check(equip != null and not equip.disabled, "equipping still works from the actions of an owned node")
	armory.free()
	await _settle()


func _test_combat_effects() -> void:
	var base := _run({})
	var base_body: float = _body_shot(base)
	_check(is_equal_approx(base.headshot_cone_deg(), 9.0) and is_equal_approx(base_body, 12.0), "baseline: 9° cone, 12 body damage")
	var hh := _run({&"head_hunter": 2})
	_check(is_equal_approx(hh.headshot_cone_deg(), 13.0) and is_equal_approx(_body_shot(hh), 12.0 * 0.9), "Head Hunter II: 13° cone, body damage −10%")
	var head := _enemy(hh, 5.0, 0.0)
	_check(hh.call("_is_headshot", head), "Head Hunter: a target in the cone is a headshot")
	var bc := _run({&"body_count": 2})
	var straight := _enemy(bc, 5.0, 0.0)
	_check(not bc.call("_is_headshot", straight) and is_equal_approx(_body_shot(bc), 12.0 * 1.2), "Body Count II: no headshots, body damage +20%")
	var sg := _run({&"steady_grip": 2})
	var rifle: GameData.Weapon = sg.weapons[0]
	_check(is_equal_approx(sg.weapon_spread(rifle), rifle.spread_deg * 0.6) and is_equal_approx(sg.fire_rate(), rifle.fire_rate),
		"Steady Grip II standing: primary spread −40%")
	sg.set("_stationary", false)
	_check(is_equal_approx(sg.weapon_spread(rifle), rifle.spread_deg) and is_equal_approx(sg.fire_rate(), rifle.fire_rate * 0.9),
		"Steady Grip II moving: fire rate −10%")
	_check(is_equal_approx(sg.weapon_spread(sg.weapons[1]), sg.weapons[1].spread_deg), "Steady Grip leaves the secondary alone")
	var sk := _run({&"skirmisher": 2})
	_check(is_equal_approx(sk.weapon_spread(rifle), rifle.spread_deg * 1.4) and is_equal_approx(sk.perk_speed_mult(), 1.0),
		"Skirmisher II standing: spread +40%, no speed without firing")
	sk.set("_firing_time", 0.2)
	_check(is_equal_approx(sk.perk_speed_mult(), 1.08), "Skirmisher II moving and firing: speed +8%")
	sk.sprinting = true
	_check(is_equal_approx(sk.perk_speed_mult(), 1.0), "Skirmisher's bonus never applies while sprinting")
	var ov := _run({&"opening_volley": 2})
	_check(is_equal_approx(ov.breaker_cooldown_total(), GameData.BREAKER_COOLDOWN + 1.0), "Opening Volley II: Breaker cooldown +1 s")
	ov.call("_breaker_impact", 1.0)
	_check(is_equal_approx(ov.opening_volley_time, GameData.OPENING_VOLLEY_SECONDS) and is_equal_approx(_body_shot(ov), 12.0 * 1.2),
		"Opening Volley II: after a Breaker, primary damage +20% for 2 s")
	for t in int(2.1 / DT):
		ov.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(ov.opening_volley_time == 0.0 and is_equal_approx(_body_shot(ov), 12.0), "Opening Volley: the bonus ends after 2 s")
	var kc := _run({&"kill_chain": 2})
	_check(is_equal_approx(_body_shot(kc), 12.0 * 0.9), "Kill Chain II: primary damage −10%")
	var shotgun := _run({&"kill_chain": 3})
	shotgun.weapon_index = 1
	var target: int = _enemy(shotgun, 3.0, 25.0)
	var before: float = shotgun.horde.hp[target]
	shotgun.call("_fire", shotgun.weapons[1], target)
	var pellets: float = before - shotgun.horde.hp[target]
	_check(pellets > 0.0 and is_equal_approx(fmod(pellets, 9.0), 0.0), "Kill Chain does not lower the secondary's damage")


func _test_survival_effects() -> void:
	var ts := _run({&"thick_skin": 2})
	_check(ts.max_hp == 120.0, "Thick Skin II: +20 max HP")
	ts.hp = 50.0
	ts.call("_heal_player", 10.0)
	_check(is_equal_approx(ts.hp, 59.0), "Thick Skin II: healing received −10%")
	var ctx := RunContext.new(1)
	var ids: Array[StringName] = [&"thick_skin"]
	ctx.apply_perks(ids, {&"thick_skin": 3})
	ctx.hp = 50.0
	ctx.heal(20.0)
	_check(is_equal_approx(ctx.hp, 67.0), "Thick Skin's trade-off also applies to boat/camp healing")
	var ff := _run({&"fleet_footed": 2})
	_check(ff.max_hp == 80.0 and is_equal_approx(ff.perk_speed_mult(), 1.08), "Fleet Footed II: speed +8%, max HP −20")
	var start: Vector3 = ff.player_pos
	var plain := _run({})
	var plain_start: Vector3 = plain.player_pos
	for t in 30:
		ff.step(DT, Vector2(1, 0), Vector3(0, 0, -1), false)
		plain.step(DT, Vector2(1, 0), Vector3(0, 0, -1), false)
	_check(ff.player_pos.distance_to(start) > plain.player_pos.distance_to(plain_start) * 1.05, "Fleet Footed moves the player further")
	var pr := _run({&"pack_rat": 2})
	_check(pr.max_ammo(1) == 54 and pr.max_ammo(0) == -1 and pr.ammo[1] == 54, "Pack Rat II: secondary ammo +35%, primary untouched")
	_check(pr.magazine_size(0) == pr.weapons[0].magazine and is_equal_approx(pr.perk_speed_mult(), 0.96), "Pack Rat II: no magazine change; speed −4%")
	var marks := RunContext.new(4)
	var pack: Array[StringName] = [&"pack_rat"]
	marks.apply_perks(pack, {&"pack_rat": 3})
	marks.weapons = [&"machine_gun", &"marksman"]
	var mr := IslandRun.new(marks.island_seed())
	mr.load_context(marks)
	_check(mr.max_ammo(1) == 45 and mr.max_ammo(0) == GameData.weapon(&"machine_gun").max_ammo, "Pack Rat III: Marksman +50%, Machine Gun unchanged")
	var qd := _run({&"quick_draw": 2})
	_check(qd.max_ammo(1) == 26, "Quick Draw II: secondary max ammo −35%")
	var shotgun_rate: float = qd.weapons[1].fire_rate
	qd.switch_weapon(1)
	_check(is_equal_approx(qd.quick_draw_time, GameData.QUICK_DRAW_SECONDS) and is_equal_approx(qd.fire_rate(), shotgun_rate * 1.25),
		"Quick Draw II: switching to the secondary gives +25% fire rate for 2 s")
	qd.switch_weapon(0)
	qd.quick_draw_time = 0.0
	qd.switch_weapon(1)
	_check(qd.quick_draw_time == 0.0, "Quick Draw triggers at most once per 8 s")
	var tr := _run({&"trail_rations": 2})
	_check(is_equal_approx(tr.pickup_radius(), GameData.PICKUP_RADIUS * 0.8), "Trail Rations II: pickup radius −20%")
	tr.hp = 50.0
	tr.orbs.append(tr.player_pos)
	tr.orb_values.append(1)
	tr.call("_collect_xp_orb", 0)
	_check(is_equal_approx(tr.hp, 50.4), "Trail Rations II: each orb heals 0.4 HP")
	var sv := _run({&"surveyor": 2})
	_check(is_equal_approx(sv.pickup_radius(), GameData.PICKUP_RADIUS * 1.75), "Surveyor II standing: pickup radius +75%")
	sv.set("_stationary", false)
	_check(is_equal_approx(sv.pickup_radius(), GameData.PICKUP_RADIUS * 0.8), "Surveyor II moving: pickup radius −20%")


func _test_breaker_effects() -> void:
	var base := _run({})
	_check(is_equal_approx(base.breaker_distance(), GameData.BREAKER_DISTANCE) and is_equal_approx(base.breaker_cooldown_total(), GameData.BREAKER_COOLDOWN),
		"baseline Breaker: 5 m, 6 s")
	var ram := _run({&"long_breaker": 2})
	_check(is_equal_approx(ram.breaker_distance(), 5.0 * 1.27) and is_equal_approx(ram.breaker_cooldown_total(), 7.0), "Battering Ram II: +27% distance, +1 s cooldown")
	var ram3 := _run({&"long_breaker": 3})
	_check(is_equal_approx(ram3.breaker_distance(), 7.0), "Battering Ram III keeps the old 7 m")
	var anchor := _run({&"crowd_anchor": 2})
	_check(is_equal_approx(anchor.breaker_distance(), 4.0), "Crowd Anchor II: distance −20%")
	var pushed := _push_after_impact(anchor)
	var unpushed := _push_after_impact(_run({}))
	_check(pushed > unpushed + 1.5, "Crowd Anchor II: the final pulse pushes 2 m (%.2f vs %.2f m)" % [pushed, unpushed])
	var rec := _run({&"recovery": 2})
	_check(is_equal_approx(rec.breaker_cooldown_total(), 6.0 * 0.9) and is_equal_approx(rec.breaker_distance(), 4.0), "Recovery II: cooldown −10%, distance −20%")
	var heavy := _run({&"heavy_impact": 2})
	_check(is_equal_approx(heavy.breaker_cooldown_total(), 8.0), "Heavy Impact II: cooldown +2 s")
	var i: int = _enemy(heavy, 0.8, 0.0)
	var before: float = heavy.horde.hp[i]
	heavy.call("_breaker_impact", 2.0)
	_check(is_equal_approx(before - heavy.horde.hp[i], GameData.BREAKER_DAMAGE * 1.6), "Heavy Impact II: Breaker damage +60%")
	var demo := _run({&"demolitions": 2})
	_check(is_equal_approx(demo.grenade_cooldown_total(), 12.0 * 0.76) and is_equal_approx(demo.grenade_radius(), 5.6)
		and is_equal_approx(demo.grenade_damage(), 90.0 * 0.8), "Demolitions II: cooldown −24%, radius +0.6 m, damage −20%")
	var demo3 := _run({&"demolitions": 3})
	_check(is_equal_approx(demo3.grenade_cooldown_total(), 12.0 * 0.65) and is_equal_approx(demo3.grenade_radius(), 6.0),
		"Demolitions III keeps the old −35% / +1 m")
	var conc := _run({&"concussion_blast": 2})
	_check(is_equal_approx(conc.grenade_damage(), 45.0), "Concussion II: grenade damage −50%")
	var c: int = _enemy(conc, 4.0, 0.0)
	conc.horde.stun[c] = 0.0
	conc.throw_grenade(Vector3(0, 0, -4))
	for t in int((GameData.GRENADE_FUSE + 0.05) / DT):
		conc.step(DT, Vector2.ZERO, Vector3(0, 0, -1), false)
	_check(conc.horde.count > 0 and conc.horde.stun[0] > 2.0, "Concussion II: the grenade stuns 2 s longer (%.2f s)" % (conc.horde.stun[0] if conc.horde.count > 0 else 0.0))
	var bulwark := _run({&"bulwark": 2}, &"vanguard")
	_check(is_equal_approx(bulwark.war_cry_duration(), GameData.WAR_CRY_TIME + 1.0), "Bulwark II: War Cry +1 s")
	bulwark.use_ability(Vector3.ZERO)
	_check(is_equal_approx(bulwark.perk_speed_mult(), 0.8), "Bulwark II: speed −20% during War Cry")
	var cry := _run({&"intimidating_cry": 2}, &"vanguard")
	_check(is_equal_approx(cry.war_cry_duration(), GameData.WAR_CRY_TIME - 2.0), "Intimidating Cry II: protection −2 s")
	var near: int = _enemy(cry, 2.0, 0.0)
	var start: Vector3 = cry.horde.positions[near]
	cry.use_ability(Vector3.ZERO)
	var plain := _run({}, &"vanguard")
	var near_plain: int = _enemy(plain, 2.0, 0.0)
	var start_plain: Vector3 = plain.horde.positions[near_plain]
	plain.use_ability(Vector3.ZERO)
	_check(cry.horde.positions[near].distance_to(start) > plain.horde.positions[near_plain].distance_to(start_plain) + 1.5,
		"Intimidating Cry II: War Cry pushes 2 m further")
	var recruit := _run({&"bulwark": 3}, &"recruit")
	_check(not recruit.has_perk(&"bulwark"), "a Vanguard perk never acts for the Recruit")


## Metres an enemy next to the player is moved by the Breaker's impact.
func _push_after_impact(run: IslandRun) -> float:
	var i: int = _enemy(run, 1.0, 90.0)
	var start: Vector3 = run.horde.positions[i]
	run.call("_breaker_impact", 2.0)
	return run.horde.positions[i].distance_to(start)


# --- Cards, Kill Chain, sprint -------------------------------------------------

func _test_body_count_cards() -> void:
	var headshot_cards: Array[StringName] = []
	for card in GameData.cards():
		if card.tags.has(&"headshot"):
			headshot_cards.append(card.id)
	_check(headshot_cards.has(&"vampire") and headshot_cards.has(&"explosive_heads") and headshot_cards.has(&"second_breath"),
		"Field Medic, Pop Goes the Head and Second Breath depend on headshots")
	var run := _run({&"body_count": 1})
	_check(run.card_offers.blocked_tags == ([&"headshot"] as Array[StringName]), "Body Count blocks headshot cards in the run's offers")
	var weapons: Array[StringName] = [&"rifle", &"shotgun"]
	var eligible: Array[GameData.Card] = run.card_offers.eligible(GameData.cards(), &"recruit", weapons, {})
	var leaked: bool = false
	for card in eligible:
		leaked = leaked or card.tags.has(&"headshot")
	_check(not leaked and not eligible.is_empty(), "no headshot card is eligible with Body Count")
	var seen: bool = false
	for k in 60:
		for card in run.card_offers.draw(GameData.cards(), &"recruit", weapons, {}):
			seen = seen or card.tags.has(&"headshot")
		var supply: GameData.Card = run.card_offers.single(GameData.cards(), &"recruit", weapons, {})
		seen = seen or supply.tags.has(&"headshot")
	_check(not seen, "60 level-up offers and supplies never show a headshot card")
	var plain := _run({})
	_check(plain.card_offers.blocked_tags.is_empty() and _run({&"head_hunter": 3}).card_offers.blocked_tags.is_empty(),
		"without Body Count headshot cards stay in the deck")
	var ctx := RunContext.new(8)
	var ids: Array[StringName] = [&"body_count"]
	ctx.apply_perks(ids, {&"body_count": 1})
	var boat := Control.new()
	boat.set_script(load("res://game/states/boat.gd"))
	boat.set("context", ctx)
	root.add_child(boat)
	var offers: CardOffers = boat.get("_card_offers")
	_check(offers != null and offers.blocked_tags.has(&"headshot"), "the boat/camp supply card uses the same filter")
	boat.free()


func _test_kill_chain_direct_only() -> void:
	var run := _run({&"kill_chain": 2})
	run.mag[0] = 10
	var i: int = _enemy(run, 5.0, 25.0, 1.0)
	run.call("_fire", run.weapons[0], i)
	run.call("_flush_dead")
	_check(run.kills == 1 and run.mag[0] == 11, "a direct primary kill puts 2 rounds back (10 - 1 + 2 = %d)" % run.mag[0])
	run.mag[0] = run.magazine_size(0) - 1
	i = _enemy(run, 5.0, 25.0, 1.0)
	run.call("_fire", run.weapons[0], i)
	run.call("_flush_dead")
	_check(run.mag[0] == run.magazine_size(0), "never above the magazine capacity")
	run.mag[0] = 10
	i = _enemy(run, 5.0, 25.0, 1.0)
	run.call("_damage", i, 50.0, run.player_pos, false, true, true)  # e.g. burn, chain, cloud
	run.call("_flush_dead")
	_check(run.kills == 3 and run.mag[0] == 10, "indirect kills (states, chains, explosions) do not count")
	i = _enemy(run, 2.0, 0.0, 1.0)
	run.call("_damage", i, 50.0, run.player_pos, false, true)  # Breaker / grenade
	run.call("_flush_dead")
	_check(run.kills == 4 and run.mag[0] == 10, "Breaker and grenade kills do not count")
	run.weapon_index = 1
	i = _enemy(run, 3.0, 25.0, 1.0)
	run.call("_fire", run.weapons[1], i)
	run.call("_flush_dead")
	_check(run.kills == 5 and run.mag[0] == 10, "secondary kills do not count")
	var smg_ctx := RunContext.new(6)
	var ids: Array[StringName] = [&"kill_chain"]
	smg_ctx.apply_perks(ids, {&"kill_chain": 3})
	smg_ctx.weapons = [&"smg", &"shotgun"]
	var smg := IslandRun.new(smg_ctx.island_seed())
	smg.load_context(smg_ctx)
	smg.mag[0] = 1
	i = _enemy(smg, 4.0, 25.0, 1.0)
	smg.call("_fire", smg.weapons[0], i)
	_check(smg.reload_left > 0.0 and smg.mag[0] == 0, "an emptied magazine still reloads (no refill mid-reload)")


func _test_skirmisher_sprint_fire() -> void:
	var run := _run({&"skirmisher": 3})
	var i: int = _enemy(run, 6.0, 0.0, 1000.0)
	var mag_before: int = run.mag[0]
	for t in 20:
		run.step(DT, Vector2(1, 0), Vector3(0, 0, -1), false, true)
	_check(run.sprinting and run.mag[0] < mag_before and run.horde.hp[i] < 1000.0 and is_equal_approx(run.perk_speed_mult(), 1.0),
		"Skirmisher: sprinting fires (run and gun) but gets no speed bonus")
	for t in 20:
		run.step(DT, Vector2(1, 0), Vector3(0, 0, -1), false, false)
	_check(not run.sprinting and is_equal_approx(run.perk_speed_mult(), 1.12), "walking and firing gets +12% speed")


# --- Armory screen ------------------------------------------------------------

## The perk tree at 1600 x 900: every name on one line (none trimmed), each A/B letter inside its
## node, and the rank pips in one row under the two alternatives.
func _test_perk_layout_1600() -> void:
	var original: Vector2i = root.size
	root.size = Vector2i(1600, 900)
	await _settle()
	var profile := _profile(500)
	profile.unlocked_classes = [&"recruit", &"vanguard"]
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	await _settle()
	armory.call("_select_category", "PERKS")
	await _settle()
	var nodes: Dictionary = armory.get("_perk_buttons")
	var trimmed: Array[String] = []
	var loose_pips: Array[String] = []
	var missing_letters: int = 0
	for node: StringName in nodes:
		var button: Button = nodes[node]
		for option: String in ["A", "B"]:
			var line: Label = button.find_child("Option" + option, true, false) as Label
			var size: int = line.get_theme_font_size("font_size")
			var wanted: float = line.get_theme_font("font").get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			if wanted > line.size.x + 0.5:
				trimmed.append("%s %s (%.0f of %.0f px)" % [node, line.text, wanted, line.size.x])
			if button.find_child("Letter" + option, true, false) == null:
				missing_letters += 1
		var pips: Control = button.find_child("Pips", true, false)
		var pip_rows: Array[float] = []
		for pip: Node in pips.get_children():
			if pip is ColorRect:
				pip_rows.append((pip as Control).global_position.y)
		var alternatives: Control = button.find_child("Alternatives", true, false)
		var below: bool = pips.global_position.y >= alternatives.global_position.y + alternatives.size.y - 1.0
		if pip_rows.is_empty() or pip_rows.any(func(y: float) -> bool: return not is_equal_approx(y, pip_rows[0])) or not below:
			loose_pips.append(String(node))
	_check(trimmed.is_empty(), "at 1600 x 900 every perk name fits its cell on one line (%s)" % [trimmed])
	_check(missing_letters == 0, "each alternative carries its A or B letter")
	_check(loose_pips.is_empty(), "the rank pips run in one row under the alternatives (%s)" % [loose_pips])
	armory.free()
	root.size = original
	await _settle()


## Every part of every node stays inside its node at 1600 x 900, the tick and the rank count included,
## with an equipped perk and with the Vanguard's perk names (the longer ones), and no name is trimmed.
func _test_perk_containment() -> void:
	var original: Vector2i = root.size
	root.size = Vector2i(1600, 900)
	await _settle()
	var profile := _profile(500)
	profile.unlocked_classes = [&"recruit", &"vanguard"]
	profile.buy_rank(&"combat_1")
	profile.toggle_equip(&"head_hunter")
	profile.selected_class = &"vanguard"
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	await _settle()
	armory.call("_select_category", "PERKS")
	await _settle()
	var nodes: Dictionary = armory.get("_perk_buttons")
	var outside: Array[String] = []
	var trimmed: Array[String] = []
	var ticked: bool = false
	for node: StringName in nodes:
		var button: Button = nodes[node]
		var frame: Rect2 = button.get_global_rect()
		for child: Node in button.find_children("*", "Control", true, false):
			var control: Control = child as Control
			if control.is_visible_in_tree() and not frame.encloses(control.get_global_rect()):
				outside.append("%s %s" % [node, control.name])
			if control.name == "Mark" and node == &"combat_1":
				ticked = true
		for option: String in ["A", "B"]:
			var line: Label = button.find_child("Option" + option, true, false) as Label
			var font_size: int = line.get_theme_font_size("font_size")
			var wanted: float = line.get_theme_font("font").get_string_size(line.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if wanted > line.size.x + 0.5:
				trimmed.append("%s %s" % [node, line.text])
	_check(ticked, "the equipped perk shows its tick inside its node")
	_check(outside.is_empty(), "with Vanguard and an equipped perk, every part of every node stays inside it (%s)" % [outside])
	_check(trimmed.is_empty(), "with Vanguard names, none is trimmed at 1600 x 900 (%s)" % [trimmed])
	armory.free()
	root.size = original
	await _settle()


func _test_armory_screen() -> void:
	var profile := _profile(500)
	profile.unlocked_classes = [&"recruit", &"vanguard"]
	profile.buy_rank(&"combat_1")
	profile.buy_rank(&"combat_1")
	profile.toggle_equip(&"head_hunter")
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	await _settle()
	armory.call("_select_category", "PERKS")
	await _settle()
	var nodes: Dictionary = armory.get("_perk_buttons")
	_check(nodes.size() == 12, "twelve nodes in four columns")
	var screen := root.get_visible_rect()
	var inside: bool = true
	for node: StringName in nodes:
		inside = inside and screen.encloses((nodes[node] as Button).get_global_rect())
	var start: Button = armory.get("_start_button")
	_check(inside and screen.encloses(start.get_global_rect()), "all nodes and START RUN fit the window")
	var c1: Button = nodes[&"combat_1"]
	var c2: Button = nodes[&"combat_2"]
	var s1: Button = nodes[&"survival_1"]
	_check(c1.get_node(c1.focus_neighbor_bottom) == c2 and c1.get_node(c1.focus_neighbor_right) == s1, "D-pad: down the branch, right across")
	_check((c1.find_child("State", true, false) as Label).text == "✓ EQUIPPED" and (c2.find_child("State", true, false) as Label).text == "NEW"
		and ((nodes[&"combat_3"] as Button).find_child("State", true, false) as Label).text == "LOCKED", "EQUIPPED / NEW / LOCKED states")
	var pips: Array = (c1.find_child("Pips", true, false) as Control).get_children().filter(func(n: Node) -> bool: return n is ColorRect)
	var rank_count: Label = c1.find_child("RankCount", true, false) as Label
	_check(rank_count != null and rank_count.text == "2/%d" % GameData.PERK_MAX_RANK, "rank count reads 2/3 next to the pips")
	c1.grab_focus()
	await _settle()
	var effects: Control = armory.find_child("PerkEffects", true, false)
	var lines: Array = effects.get_children().map(func(row: Control) -> String: return row.tooltip_text)
	var values: Array = effects.get_children().map(func(row: Control) -> String: return (row.find_child("Value", false, false) as Label).text)
	_check(values == ["13°", "−10%"], "effect values line up on the right (%s)" % [values])
	_check(lines.size() == 2 and lines[0].begins_with("▲ Headshot cone 13°") and lines[1].begins_with("▼ Body-shot damage −10%"),
		"detail shows benefit and trade-off at the rank (%s)" % [lines])
	_check((armory.find_child("PerkRank", true, false) as Label).text == "RANK II → III"
		and (armory.find_child("PerkUpgrade", true, false) as Button).text == "UPGRADE TO III / 80 INTEL", "detail shows rank → next rank and cost")
	# LB/RB (here Q) switches A/B for free, keeping the slot.
	var intel: int = profile.intel
	var q := InputEventKey.new()
	q.physical_keycode = KEY_Q
	q.pressed = true
	Input.parse_input_event(q)
	await _settle()
	_check(profile.equipped_perks == [&"body_count"] and profile.intel == intel, "Q / LB switches the focused node to B for free")
	_check(root.gui_get_focus_owner() == armory.get("_perk_buttons")[&"combat_1"], "focus stays on the node after switching")
	# A opens the actions; B returns to the tree.
	(armory.get("_perk_buttons")[&"combat_1"] as Button).pressed.emit()
	await _settle()
	var focus := root.gui_get_focus_owner()
	_check(focus != null and focus.name == "PerkUpgrade", "A on a node focuses its actions")
	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _settle()
	_check(root.gui_get_focus_owner() == armory.get("_perk_buttons")[&"combat_1"], "B from the actions goes back to the node")
	(armory.find_child("PerkUpgrade", true, false) as Button).pressed.emit()
	await _settle()
	_check(profile.node_rank(&"combat_1") == 3 and profile.intel == intel - 80, "UPGRADE buys the next rank")
	# Locked nodes stay focusable and say why.
	(armory.get("_perk_buttons")[&"combat_3"] as Button).grab_focus()
	await _settle()
	var why: Label = armory.find_child("PerkRequirement", true, false)
	_check(why != null and why.text == "Requires Combat II rank I" and (armory.find_child("PerkUpgrade", true, false) as Button).disabled,
		"a locked node shows its requirement")
	# Hints use the platform icons (InputIcons), not hard-coded text.
	var hints: Control = armory.find_child("Hints", true, false)
	var icons: RichTextLabel = null
	for hint in (hints.get_children() if hints != null else []):
		if hint.get_child_count() == 2 and (hint.get_child(1) as Label).text == "SWITCH A ↔ B":
			icons = hint.get_child(0) as RichTextLabel
	_check(icons != null and icons.text == InputIcons.text(KEY_Q) + "  " + InputIcons.text(KEY_E), "the A/B hint comes from InputIcons (%s)" % (icons.text if icons else "none"))
	# Class change: Breaker III follows the class.
	for node: StringName in [&"breaker_1", &"breaker_2", &"breaker_3"]:
		profile.perk_ranks[node] = 1
	profile.equipped_perks = [&"demolitions"]
	armory.call("_choose_class", &"vanguard")
	await _settle()
	_check(profile.equipped_perks == [&"bulwark"], "choosing Vanguard swaps Demolitions for Bulwark")
	armory.call("_select_category", "PERKS")
	await _settle()
	var b3: Button = armory.get("_perk_buttons")[&"breaker_3"]
	_check((b3.find_child("OptionA", true, false) as Label).text == "BULWARK" and (b3.find_child("OptionB", true, false) as Label).text == "INTIMIDATING CRY",
		"Breaker III shows the class's variants")
	armory.queue_free()
	await _settle()
	# A migration notice is shown in the Perks tab.
	var migrated := Profile.from_dict({"version": 6, "selected_class": "vanguard", "unlocked_classes": ["vanguard"],
		"owned_perks": ["demolitions"], "equipped_perks": ["demolitions"]})
	var noticed := Control.new()
	noticed.set_script(load("res://game/states/armory.gd"))
	noticed.set("profile", migrated)
	root.add_child(noticed)
	await _settle()
	var notice: Label = noticed.find_child("PerkNotice", true, false)
	_check(notice != null and notice.text.contains("Recruit-only") and migrated.perk_notice == "", "the migration notice is shown once in the Armory")
	noticed.queue_free()
	await _settle()
