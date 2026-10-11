class_name CardOffers
extends RefCounted
## Shared by level-ups and boat/camp supplies. Filtering never consumes RNG.

var rng := RandomNumberGenerator.new()
## Cards with any of these tags are never offered (e.g. Body Count turns
## headshots off, so headshot cards would be dead picks).
var blocked_tags: Array[StringName] = []


func _init(seed_value: int = 7) -> void:
	rng.seed = seed_value ^ 0x43415244


func eligible(catalog: Array[GameData.Card], player_class: StringName,
		weapons: Array[StringName], ranks: Dictionary) -> Array[GameData.Card]:
	var result: Array[GameData.Card] = []
	var seen: Dictionary = {}
	for card in catalog:
		if seen.has(card.id) or int(ranks.get(card.id, 0)) >= card.max_stacks:
			continue
		if not card.class_filter.is_empty() and not card.class_filter.has(player_class):
			continue
		if _intersects(card.tags, blocked_tags):
			continue
		if not card.weapon_filter.is_empty() and not _intersects(card.weapon_filter, weapons):
			continue
		if card.requires_finite_weapon and not _owns_finite_weapon(weapons):
			continue
		var ready: bool = true
		for id: StringName in card.prerequisites:
			if int(ranks.get(id, 0)) < card.prerequisites[id]:
				ready = false
				break
		if ready:
			seen[card.id] = true
			result.append(card)
	return result


## Three choices: new and upgrade first, then weighted; no duplicates.
## Rerolls prefer alternatives within each bucket without losing guarantees.
func draw(catalog: Array[GameData.Card], player_class: StringName,
		weapons: Array[StringName], ranks: Dictionary,
		avoid: Array[StringName] = []) -> Array[GameData.Card]:
	var pool: Array[GameData.Card] = eligible(catalog, player_class, weapons, ranks)
	var result: Array[GameData.Card] = []
	for upgrade: bool in [false, true]:
		var bucket: Array[GameData.Card] = []
		for c in pool:
			if (int(ranks.get(c.id, 0)) > 0) == upgrade:
				bucket.append(c)
		if not bucket.is_empty():
			var chosen: GameData.Card = _pick(_prefer(bucket, avoid), catalog, ranks, false)
			result.append(chosen)
			pool.erase(chosen)
	while result.size() < 3 and not pool.is_empty():
		var chosen: GameData.Card = _pick(_prefer(pool, avoid), catalog, ranks, true)
		result.append(chosen)
		pool.erase(chosen)
	return result


## A supply has one slot, so uses the weighted rule over all eligible cards.
func single(catalog: Array[GameData.Card], player_class: StringName,
		weapons: Array[StringName], ranks: Dictionary,
		avoid: Array[StringName] = []) -> GameData.Card:
	var pool: Array[GameData.Card] = eligible(catalog, player_class, weapons, ranks)
	return null if pool.is_empty() else _pick(_prefer(pool, avoid), catalog, ranks, true)


func weight(card: GameData.Card, catalog: Array[GameData.Card], ranks: Dictionary) -> float:
	var value: float = 1.5 if int(ranks.get(card.id, 0)) > 0 else 1.0
	for owned in catalog:
		if int(ranks.get(owned.id, 0)) > 0 and _intersects(card.tags, owned.tags):
			return value * 1.25
	return value


func _pick(pool: Array[GameData.Card], catalog: Array[GameData.Card], ranks: Dictionary,
		weighted: bool) -> GameData.Card:
	var total: float = 0.0
	for c in pool:
		total += weight(c, catalog, ranks) if weighted else 1.0
	var roll: float = rng.randf() * total
	for c in pool:
		roll -= weight(c, catalog, ranks) if weighted else 1.0
		if roll < 0.0:
			return c
	return pool.back()


static func _prefer(pool: Array[GameData.Card], avoid: Array[StringName]) -> Array[GameData.Card]:
	var alternatives: Array[GameData.Card] = []
	for c in pool:
		if not avoid.has(c.id):
			alternatives.append(c)
	return alternatives if not alternatives.is_empty() else pool


static func _intersects(a: Array[StringName], b: Array[StringName]) -> bool:
	for id in a:
		if b.has(id):
			return true
	return false


static func _owns_finite_weapon(owned: Array[StringName]) -> bool:
	for w in GameData.weapons():
		if owned.has(w.id) and w.max_ammo > 0:
			return true
	return false


## Tags the equipped perks rule out of every offer (level-ups and supplies).
static func blocked_tags_for(perks: Array[StringName]) -> Array[StringName]:
	var tags: Array[StringName] = []
	if perks.has(&"body_count"):
		tags.append(&"headshot")
	return tags
