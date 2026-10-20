extends SceneTree
## Priced cards: six complex cards are bought in the Armory for Intel, and the
## level-up offers only draw the cards the player owns
## (docs/design/PROGRESSION_AND_ECONOMY.md §3.2).
## Run: godot --headless --path . --script res://tests/test_card_unlocks.gd

const PRICED: Array[StringName] = [&"chain_lightning", &"wildfire", &"explosive_heads", &"ricochet", &"piercing_rounds", &"shockwave"]
const SAVE_PATH: String = "user://test_card_unlocks.json"

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	var all: Array[GameData.Card] = GameData.cards()
	var priced_ids: Array[StringName] = []
	for c in all:
		if c.unlock_cost > 0:
			priced_ids.append(c.id)
	_check(priced_ids.size() == PRICED.size() and PRICED.all(func(id: StringName) -> bool: return priced_ids.has(id)),
		"exactly the six chosen cards have an Intel price")
	_check(GameData.card_cost(&"chain_lightning") == 30 and GameData.card_cost(&"hollow_points") == 0 and GameData.card_cost(&"nope") == -1,
		"a priced card costs 30 Intel, a free one 0, an unknown one -1")
	var needed: bool = false
	for c in all:
		for id in c.prerequisites:
			needed = needed or PRICED.has(id)
	_check(not needed, "no card needs a priced card as a prerequisite, so locking them breaks no chain")

	var pool: Array[GameData.Card] = IslandRun.offer_pool(all, PRICED)
	_check(pool.size() == all.size() - PRICED.size() and not pool.any(func(c: GameData.Card) -> bool: return PRICED.has(c.id)),
		"the offer pool leaves out every locked card")
	_check(IslandRun.offer_pool(all, []).size() == all.size(), "with nothing locked the pool is the whole catalogue")

	var p := Profile.new()
	p.intel = 50
	_check(p.locked_card_ids().size() == PRICED.size(), "a new profile has the six priced cards locked")
	_check(p.buy_card(&"chain_lightning") and p.intel == 20 and p.owns_card(&"chain_lightning"),
		"a priced card is bought for 30 Intel")
	_check(not p.buy_card(&"chain_lightning") and p.intel == 20, "buying an owned card again costs nothing")
	_check(not p.buy_card(&"wildfire") and p.intel == 20 and not p.owns_card(&"wildfire"),
		"without enough Intel nothing changes")

	p.save(SAVE_PATH)
	var loaded: Profile = Profile.load_profile(SAVE_PATH)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	_check(loaded.owns_card(&"chain_lightning") and not loaded.owns_card(&"wildfire") and loaded.intel == 20,
		"the bought card survives saving and loading")
	_check(Profile.from_dict({}).unlocked_cards.is_empty(), "an old save without the list loads with nothing bought")
	_check(Profile.from_dict({"unlocked_cards": ["hollow_points", "nope"]}).unlocked_cards.is_empty(),
		"a free or unknown id is not stored as bought")

	# A run never offers a locked card, even over many level-ups.
	var run := IslandRun.new(7, &"beach")
	run.locked_cards.assign(PRICED)
	var none: Array[GameData.Card] = []
	var leaked: bool = false
	var offered: int = 0
	for i in 40:
		run.card_choices.clear()
		run.call("_draw_cards", none)
		for c in run.card_choices:
			offered += 1
			leaked = leaked or PRICED.has(c.id)
	_check(offered > 0 and not leaked, "a run offers cards (%d) and never a locked one in 40 level-ups" % offered)

	quit(1 if _failures > 0 else 0)
