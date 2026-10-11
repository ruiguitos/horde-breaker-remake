class_name Profile
extends RefCounted
## Persistent player profile (meta progression), saved as versioned JSON in
## user:// (on Windows: %APPDATA%/Godot/app_userdata/Horde Breaker Remake).

const PATH: String = "user://profile.json"
## 7: perk tree (ranks per node, A/B choice); older saves migrate on load.
const VERSION: int = 7

var intel: int = 0
var runs: int = 0
var extractions: int = 0
var best_kills: int = 0
## Perk tree (GameData.perk_nodes): rank bought per node, 0..3. Both
## alternatives of a node share it.
var perk_ranks: Dictionary = {}
## Alternative picked per node (0 = A, 1 = B). Free to change in the Armory.
var perk_options: Dictionary = {}
## Rank used per node when the player picked one lower than bought (free);
## missing = the bought rank.
var perk_use_ranks: Dictionary = {}
## Equipped perk ids (class variants resolved), at most one per node and
## `slots` in total. Only these act in a run.
var equipped_perks: Array[StringName] = []
## Message for the Armory after a migration changed the equipment (not saved).
var perk_notice: String = ""
var slots: int = 1
var max_threat: int = 1  ## highest Threat unlocked (extract on N to unlock N+1)
var threat: int = 1  ## last chosen
## Volumes in percent (0..100): Master, sound effects (incl. ambience), music.
var master_volume: int = 80
var sfx_volume: int = 100
var music_volume: int = 70
## Short voice blips while dialogue and radio lines type out (Settings > Audio).
var dialogue_voice: bool = true

## The profile in use, so screens without a reference (e.g. the pause menu)
## can open the settings panel.
static var current: Profile
var unlocked_weapons: Array[StringName] = []  ## bought in the armory
var selected_primary: StringName = &"rifle"
var selected_secondary: StringName = &"shotgun"
var unlocked_classes: Array[StringName] = [&"recruit"]
var selected_class: StringName = &"recruit"
var lore_pages: int = 0
## Story ending chosen (OriginEnding.ENDINGS key), or empty if not reached.
var ending: String = ""
## Display and graphics (applied by GraphicsSettings).
var window_mode: int = GraphicsSettings.WINDOWED
var resolution: Vector2i = Vector2i(1600, 900)  ## window size when windowed
var vsync: bool = true
var max_fps: int = 0  ## 0 = unlimited
var quality: int = GraphicsSettings.HIGH  ## Low / Medium / High / Ultra preset
var render_scale: int = 100  ## 3D resolution in percent of the window
var antialias: int = GraphicsSettings.AA_FXAA
## Island camera (V cycles in game). First and third person aim with the
## centre crosshair; Fixed is the original medium camera (aim with the body).
enum CameraMode { FIRST_PERSON, THIRD_PERSON, FIXED }
const CAMERA_MODE_NAMES: Array[String] = ["First person", "Third person (shoulder)", "Fixed (top-down)"]
var camera_mode: int = CameraMode.THIRD_PERSON
var mouse_sensitivity: int = 50  ## percent
var controller_icons: int = 0  ## 0 = auto; see InputIcons.PLATFORM_NAMES
var hud_scale: int = 100  ## HUD size in percent (60..100); new profiles start at 100
## Rebound keys: action -> "key:N" / "mouse:N" (see GameInput.REBINDABLE).
var key_bindings: Dictionary = {}
## The last run started, for QUICK REDEPLOY: {"class", "perks", "threat",
## "expedition"} as JSON-friendly values ("" expedition = the archipelago).
## Empty until the first run.
var last_run: Dictionary = {}
## Intel files already seen in the archive (the title shows "N NEW").
var lore_read: int = 0
## Set by record_run when the run beat the kill record (not saved).
var new_best_kills: bool = false


static func load_profile(path: String = PATH) -> Profile:
	var p := Profile.new()
	if not FileAccess.file_exists(path):
		return p
	var text: String = FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_warning("Profile: unreadable save, starting fresh")
		return p
	return from_dict(data)


static func from_dict(d: Dictionary) -> Profile:
	var p := Profile.new()
	# Version 1 had no perks or threat: the defaults above are the migration.
	p.intel = int(d.get("intel", 0))
	p.runs = int(d.get("runs", 0))
	p.extractions = int(d.get("extractions", 0))
	p.best_kills = int(d.get("best_kills", 0))
	p.slots = clampi(int(d.get("slots", 1)), 1, GameData.SLOT_COSTS.size())
	p.max_threat = int(d.get("max_threat", 1))
	p.lore_pages = int(d.get("lore_pages", 0))
	p.ending = String(d.get("ending", ""))
	# Version 3 had one High/Low toggle; version 4 has a quality preset.
	p.quality = clampi(int(d.get("quality", GraphicsSettings.HIGH if bool(d.get("graphics_high", true)) else GraphicsSettings.LOW)), 0, GraphicsSettings.QUALITY_NAMES.size() - 1)
	p.window_mode = clampi(int(d.get("window_mode", GraphicsSettings.WINDOWED)), 0, GraphicsSettings.WINDOW_MODE_NAMES.size() - 1)
	var res: PackedStringArray = String(d.get("resolution", "1600x900")).split("x")
	if res.size() == 2 and res[0].is_valid_int() and res[1].is_valid_int():
		p.resolution = Vector2i(maxi(640, int(res[0])), maxi(360, int(res[1])))
	p.vsync = bool(d.get("vsync", true))
	p.hud_scale = clampi(int(d.get("hud_scale", 100)), 60, 100)
	# Older saves had a third_person bool (true = shoulder, false = fixed).
	var old_mode: int = CameraMode.THIRD_PERSON if bool(d.get("third_person", true)) else CameraMode.FIXED
	p.camera_mode = clampi(int(d.get("camera_mode", old_mode)), 0, CAMERA_MODE_NAMES.size() - 1)
	var kb: Variant = d.get("key_bindings", {})
	if kb is Dictionary:
		for k: Variant in kb:
			if GameInput.REBINDABLE.has(StringName(k)):
				p.key_bindings[String(k)] = String(kb[k])
	p.mouse_sensitivity = clampi(int(d.get("mouse_sensitivity", 50)), 1, 100)
	p.controller_icons = clampi(int(d.get("controller_icons", 0)), 0, InputIcons.PLATFORM_NAMES.size() - 1)
	p.max_fps = maxi(0, int(d.get("max_fps", 0)))
	p.render_scale = clampi(int(d.get("render_scale", 100)), 50, 100)
	p.antialias = clampi(int(d.get("antialias", GraphicsSettings.AA_FXAA)), 0, GraphicsSettings.AA_NAMES.size() - 1)
	# Version 2 stored one master volume 0..10; version 3 stores percentages.
	p.master_volume = clampi(int(d.get("master_volume", int(d.get("volume", 8)) * 10)), 0, 100)
	p.sfx_volume = clampi(int(d.get("sfx_volume", 100)), 0, 100)
	p.music_volume = clampi(int(d.get("music_volume", 70)), 0, 100)
	p.dialogue_voice = bool(d.get("dialogue_voice", true))
	for id in d.get("unlocked_classes", []):
		# Classes removed from the game (e.g. Field Medic) are dropped.
		if GameData.CLASSES.has(StringName(id)) and not p.unlocked_classes.has(StringName(id)):
			p.unlocked_classes.append(StringName(id))
	p.selected_class = StringName(d.get("selected_class", "recruit"))
	if not p.unlocked_classes.has(p.selected_class):
		p.selected_class = &"recruit"
	for id in d.get("unlocked_weapons", []):
		var weapon_id := StringName(id)
		if GameData.weapon(weapon_id) != null and not p.unlocked_weapons.has(weapon_id):
			p.unlocked_weapons.append(weapon_id)
	# Removed Heavy Pistol selections become the free Shotgun, without refund.
	var primary_id := StringName(d.get("selected_primary", "rifle"))
	var secondary_id := StringName(d.get("selected_secondary", d.get("selected_weapon", "shotgun")))
	var primary: GameData.Weapon = GameData.weapon(primary_id)
	if primary != null and primary.primary:
		p.select_weapon(primary_id)
	if secondary_id == &"pistol":
		secondary_id = &"shotgun"
	var secondary: GameData.Weapon = GameData.weapon(secondary_id)
	if secondary != null and not secondary.primary:
		p.select_weapon(secondary_id)
	p.threat = clampi(int(d.get("threat", 1)), 1, p.max_threat)
	# Version 7 has the perk tree; older saves had five flat perks.
	if int(d.get("version", 1)) >= 7:
		p._read_perk_tree(d)
	else:
		p.migrate_legacy_perks(d.get("owned_perks", []), d.get("equipped_perks", []))
	# Version 4 had no last run nor archive read count: no QUICK REDEPLOY
	# until the next run, and every file already recovered counts as read.
	var last: Variant = d.get("last_run", {})
	if last is Dictionary and (last as Dictionary).has("class"):
		p.last_run = {
			"class": String(last["class"]),
			"perks": (last.get("perks", []) as Array).map(func(x: Variant) -> String: return String(x)),
			"threat": int(last.get("threat", 1)),
			"expedition": String(last.get("expedition", "")),
			"primary": "rifle" if String(last.get("primary", "rifle")) == "pistol" else String(last.get("primary", "rifle")),
			"secondary": "shotgun" if String(last.get("secondary", "shotgun")) == "pistol" else String(last.get("secondary", "shotgun")),
		}
		var ranks: Variant = last.get("perk_ranks", {})
		if ranks is Dictionary:
			var clean: Dictionary = {}
			for id: Variant in ranks:
				clean[String(id)] = clampi(int(ranks[id]), 1, GameData.PERK_MAX_RANK)
			p.last_run["perk_ranks"] = clean
	p.lore_read = clampi(int(d.get("lore_read", p.lore_pages)), 0, p.lore_pages)
	return p


func save(path: String = PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("Profile: cannot write " + path)
		return false
	f.store_string(JSON.stringify({
		"version": VERSION, "intel": intel, "runs": runs,
		"extractions": extractions, "best_kills": best_kills,
		"perk_ranks": _string_keys(perk_ranks), "perk_options": _string_keys(perk_options),
		"perk_use_ranks": _string_keys(perk_use_ranks),
		"equipped_perks": equipped_perks.map(func(x: StringName) -> String: return String(x)),
		"slots": slots, "max_threat": max_threat, "threat": threat, "master_volume": master_volume, "sfx_volume": sfx_volume, "music_volume": music_volume, "dialogue_voice": dialogue_voice, "lore_pages": lore_pages, "ending": ending, "selected_class": String(selected_class),
		"unlocked_classes": unlocked_classes.map(func(x: StringName) -> String: return String(x)),
		"unlocked_weapons": unlocked_weapons.map(func(x: StringName) -> String: return String(x)),
		"selected_primary": String(selected_primary), "selected_secondary": String(selected_secondary),
		"quality": quality, "window_mode": window_mode, "resolution": "%dx%d" % [resolution.x, resolution.y],
		"vsync": vsync, "hud_scale": hud_scale, "camera_mode": camera_mode, "key_bindings": key_bindings, "mouse_sensitivity": mouse_sensitivity, "controller_icons": controller_icons, "max_fps": max_fps, "render_scale": render_scale, "antialias": antialias,
		"last_run": last_run, "lore_read": lore_read}, "  "))
	return true


## Adds a finished run's results.
func record_run(ctx: RunContext) -> void:
	runs += 1
	intel += ctx.intel
	lore_pages = mini(Story.FILES.size(), lore_pages + ctx.lore_found)
	if ctx.won:
		extractions += 1
		if ctx.threat == max_threat and max_threat < GameData.MAX_THREAT:
			max_threat += 1
	new_best_kills = ctx.kills > best_kills
	best_kills = maxi(best_kills, ctx.kills)


## Remembers the run being started (QUICK REDEPLOY replays it): the
## selected class, equipped perks and threat, and which run it is.
func remember_run(expedition: StringName) -> void:
	last_run = {
		"class": String(selected_class),
		"perks": equipped_perks.map(func(x: StringName) -> String: return String(x)),
		"perk_ranks": equipped_perk_ranks_json(),
		"threat": threat,
		"expedition": String(expedition),
		"primary": String(selected_primary), "secondary": String(selected_secondary),
	}


## Why the last run cannot be replayed as it was ("" = it can). Things
## change between runs (an old save, a perk slot sold back in a future
## version, an expedition not built), so QUICK REDEPLOY checks first and
## falls back to the Armory instead of starting a run with something the
## player does not own.
func redeploy_problem() -> String:
	if last_run.is_empty():
		return "No previous run yet"
	if not unlocked_classes.has(StringName(last_run["class"])):
		return "Class locked"
	var primary: GameData.Weapon = GameData.weapon(StringName(last_run.get("primary", "rifle")))
	var secondary: GameData.Weapon = GameData.weapon(StringName(last_run.get("secondary", "shotgun")))
	if primary == null or not primary.primary or not owns_weapon(primary.id):
		return "Primary weapon unavailable"
	if secondary == null or secondary.primary or not owns_weapon(secondary.id):
		return "Secondary weapon unavailable"
	var perks: Array = last_run["perks"]
	if perks.size() > slots:
		return "Not enough perk slots"
	var nodes: Array[StringName] = []
	for id: Variant in perks:
		var perk: GameData.Perk = GameData.perk(StringName(id))
		if perk == null or not owns_perk(perk.id):
			return "Perk not owned"
		if not perk.fits_class(StringName(last_run["class"])) or nodes.has(perk.node()):
			return "Perk unavailable for this class"
		nodes.append(perk.node())
	if int(last_run["threat"]) < 1 or int(last_run["threat"]) > max_threat:
		return "Threat locked"
	var expedition := StringName(last_run["expedition"])
	if expedition != &"" and not Expeditions.available(expedition):
		return "Expedition unavailable"
	return ""


## Selects the last run's class, perks and threat (so the Armory shows
## what is being played). Returns false, changing nothing, if it cannot.
func apply_last_run() -> bool:
	if redeploy_problem() != "":
		return false
	selected_class = StringName(last_run["class"])
	selected_primary = StringName(last_run.get("primary", "rifle"))
	selected_secondary = StringName(last_run.get("secondary", "shotgun"))
	# Same perks, same A/B choice and the same ranks (never above what is
	# bought now; older saves without ranks use the bought rank).
	equipped_perks.clear()
	var ranks: Dictionary = last_run.get("perk_ranks", {})
	for id: Variant in last_run["perks"]:
		var perk: GameData.Perk = GameData.perk(StringName(id))
		equipped_perks.append(perk.id)
		perk_options[perk.node()] = perk.option
		perk_use_ranks.erase(perk.node())
		if ranks.has(String(id)):
			set_use_rank(perk.node(), mini(int(ranks[String(id)]), node_rank(perk.node())))
	threat = int(last_run["threat"])
	return true


## The last run's expedition id (&"" = the archipelago).
func last_expedition() -> StringName:
	return StringName(last_run.get("expedition", ""))


## "Vanguard · Archipelago · T2" for the QUICK REDEPLOY buttons.
func last_run_summary() -> String:
	if last_run.is_empty():
		return ""
	var id := StringName(last_run["class"])
	var class_text: String = String(GameData.CLASS_INFO[id]["name"]) if GameData.CLASS_INFO.has(id) else String(id).capitalize()
	var expedition := last_expedition()
	var run_name: String = "Archipelago" if expedition == &"" else Expeditions.display_name(expedition).get_slice(" ", 0)
	return "%s · %s · T%d" % [class_text, run_name, int(last_run["threat"])]


## Intel files recovered but not yet seen in the archive.
func unread_files() -> int:
	return maxi(0, lore_pages - lore_read)


func mark_archive_read() -> void:
	lore_read = lore_pages


## --- Perk tree (docs/design/CARDS_WEAPONS_PERKS.md §F2) ---------------

## Rank bought in `node` (0 = not bought).
func node_rank(node: StringName) -> int:
	return int(perk_ranks.get(node, 0))


## A perk is owned when its node has rank I or more (both alternatives).
func owns_perk(id: StringName) -> bool:
	var perk: GameData.Perk = GameData.perk(id)
	return perk != null and node_rank(perk.node()) >= 1


## Rank `node` acts at when equipped: the bought rank, or a lower one picked.
func use_rank(node: StringName) -> int:
	var bought: int = node_rank(node)
	return clampi(int(perk_use_ranks.get(node, bought)), mini(1, bought), bought)


## Picks a lower bought rank (free). False if `rank` is not bought.
func set_use_rank(node: StringName, rank: int) -> bool:
	if rank < 1 or rank > node_rank(node):
		return false
	if rank == node_rank(node):
		perk_use_ranks.erase(node)
	else:
		perk_use_ranks[node] = rank
	return true


## Next lower bought rank, wrapping to the highest (Armory rank button).
func cycle_use_rank(node: StringName) -> bool:
	var bought: int = node_rank(node)
	if bought < 2:
		return false
	var rank: int = use_rank(node) - 1
	return set_use_rank(node, rank if rank >= 1 else bought)


## Rank of an equipped perk id for the run (0 when it is not equipped).
func equipped_rank(id: StringName) -> int:
	var perk: GameData.Perk = GameData.perk(id)
	return use_rank(perk.node()) if perk != null and equipped_perks.has(id) else 0


func equipped_perk_ranks() -> Dictionary:
	var ranks: Dictionary = {}
	for id in equipped_perks:
		ranks[id] = equipped_rank(id)
	return ranks


func equipped_perk_ranks_json() -> Dictionary:
	var ranks: Dictionary = {}
	for id in equipped_perks:
		ranks[String(id)] = equipped_rank(id)
	return ranks


## Intel for the next rank of `node`; -1 at rank III or for an unknown node.
func next_rank_cost(node: StringName) -> int:
	if not GameData.perk_nodes().has(node):
		return -1
	return GameData.perk_rank_cost(GameData.perk_node_tier(node), node_rank(node) + 1)


## Why the next rank of `node` cannot be bought now ("" = it can). Tier n
## needs rank I of tier n-1 in the same branch, equipped or not.
func rank_problem(node: StringName) -> String:
	var cost: int = next_rank_cost(node)
	if cost < 0:
		return "Max rank"
	var tier: int = GameData.perk_node_tier(node)
	if tier > 1:
		var before: StringName = GameData.perk_node(GameData.perk_node_branch(node), tier - 1)
		if node_rank(before) < 1:
			return "Requires %s %s rank I" % [String(GameData.perk_node_branch(node)).capitalize(), GameData.RANK_NAMES[tier - 1]]
	if intel < cost:
		return "Not enough Intel"
	return ""


## Buys the next rank of `node` for both alternatives. Never equips.
func buy_rank(node: StringName) -> bool:
	if rank_problem(node) != "":
		return false
	intel -= next_rank_cost(node)
	perk_ranks[node] = node_rank(node) + 1
	perk_use_ranks.erase(node)  # a new rank is used at once
	return true


## The equipped perk of `node` (&"" = none).
func equipped_in(node: StringName) -> StringName:
	for id in equipped_perks:
		var perk: GameData.Perk = GameData.perk(id)
		if perk != null and perk.node() == node:
			return id
	return &""


## Alternative picked in `node`: the equipped one, else the last picked.
func perk_option(node: StringName) -> int:
	var current: StringName = equipped_in(node)
	if current != &"":
		return GameData.perk(current).option
	return clampi(int(perk_options.get(node, 0)), 0, 1)


## The perk the Armory shows for `node` (picked alternative, class variant).
func perk_choice(node: StringName) -> GameData.Perk:
	return GameData.perk_for(node, perk_option(node), selected_class)


## Switches `node` between A and B (free, Armory only). An equipped node
## swaps its perk in the same slot, so the loadout never has both.
func switch_option(node: StringName) -> bool:
	var next: int = 1 - perk_option(node)
	var perk: GameData.Perk = GameData.perk_for(node, next, selected_class)
	if perk == null:
		return false
	perk_options[node] = next
	var current: StringName = equipped_in(node)
	if current != &"":
		equipped_perks[equipped_perks.find(current)] = perk.id
	return true


## Equips or removes the picked alternative of `node`.
func toggle_equip_node(node: StringName) -> bool:
	var current: StringName = equipped_in(node)
	if current != &"":
		equipped_perks.erase(current)
		return true
	var perk: GameData.Perk = perk_choice(node)
	return perk != null and toggle_equip(perk.id)


## After a class change: class variants (Breaker III) follow the class,
## keeping the node, the A/B choice and the rank. Returns true if changed.
func sync_perks_to_class() -> bool:
	var changed: bool = false
	for i in range(equipped_perks.size() - 1, -1, -1):
		var perk: GameData.Perk = GameData.perk(equipped_perks[i])
		if perk == null or perk.fits_class(selected_class):
			continue
		var variant: GameData.Perk = GameData.perk_for(perk.node(), perk.option, selected_class)
		if variant != null:
			equipped_perks[i] = variant.id
		else:
			equipped_perks.remove_at(i)
		changed = true
	return changed


## Version <= 6 saves: each old perk becomes rank III of its node, on
## alternative A, for free; earlier tiers of its branch get rank I (not
## equipped). Intel and slots are untouched. Ranks only ever go up, so
## running this again changes nothing. Demolitions is Recruit-only: equipped
## on another class it is removed (kept owned) with a notice.
func migrate_legacy_perks(old_owned: Array, old_equipped: Array) -> void:
	for raw: Variant in old_owned:
		var perk: GameData.Perk = GameData.perk(StringName(raw))
		if perk == null:
			continue
		perk_ranks[perk.node()] = maxi(node_rank(perk.node()), GameData.PERK_MAX_RANK)
		if not perk_options.has(perk.node()):
			perk_options[perk.node()] = perk.option
		for tier in range(1, perk.tier):
			var before: StringName = GameData.perk_node(perk.branch, tier)
			perk_ranks[before] = maxi(node_rank(before), 1)
	for raw: Variant in old_equipped:
		var id := StringName(raw)
		var perk: GameData.Perk = GameData.perk(id)
		if perk == null or not owns_perk(id) or equipped_perks.has(id) or equipped_in(perk.node()) != &"":
			continue
		if not perk.fits_class(selected_class):
			perk_notice = "%s is Recruit-only: removed from your %s loadout (still owned)." % [perk.title, String(GameData.CLASS_INFO[selected_class]["name"])]
			continue
		if equipped_perks.size() < slots:
			equipped_perks.append(id)


## Version 7 fields, validated (unknown nodes/perks are dropped).
func _read_perk_tree(d: Dictionary) -> void:
	var nodes: Array[StringName] = GameData.perk_nodes()
	for key: String in ["perk_ranks", "perk_options", "perk_use_ranks"]:
		var raw: Variant = d.get(key, {})
		if not raw is Dictionary:
			continue
		var target: Dictionary = get(key)
		for k: Variant in raw:
			if nodes.has(StringName(k)):
				var high: int = 1 if key == "perk_options" else GameData.PERK_MAX_RANK
				target[StringName(k)] = clampi(int(raw[k]), 0, high)
	for raw: Variant in d.get("equipped_perks", []):
		var perk: GameData.Perk = GameData.perk(StringName(raw))
		if perk != null and owns_perk(perk.id) and perk.fits_class(selected_class) \
				and equipped_in(perk.node()) == &"" and equipped_perks.size() < slots:
			equipped_perks.append(perk.id)


static func _string_keys(dict: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in dict:
		out[String(k)] = dict[k]
	return out


func buy_class(id: StringName) -> bool:
	var cost: int = int(GameData.CLASS_INFO[id]["cost"])
	if unlocked_classes.has(id) or intel < cost:
		return false
	intel -= cost
	unlocked_classes.append(id)
	return true


func buy_weapon(id: StringName) -> bool:
	var cost: int = GameData.weapon_cost(id)
	if cost < 0 or unlocked_weapons.has(id) or intel < cost:
		return false
	intel -= cost
	unlocked_weapons.append(id)
	return true


func owns_weapon(id: StringName) -> bool:
	return GameData.starting_weapons().has(id) or unlocked_weapons.has(id) and GameData.weapon(id) != null


## Selecting changes only that slot; ownership and Intel are untouched.
func select_weapon(id: StringName) -> bool:
	var entry: GameData.Weapon = GameData.weapon(id)
	if entry == null or not owns_weapon(id):
		return false
	if entry.primary:
		selected_primary = id
	else:
		selected_secondary = id
	return true


func weapon_loadout() -> Array[StringName]:
	return [selected_primary, selected_secondary]


func next_slot_cost() -> int:
	return GameData.SLOT_COSTS[slots] if slots < GameData.SLOT_COSTS.size() else -1


func buy_slot() -> bool:
	var cost: int = next_slot_cost()
	if cost < 0 or intel < cost:
		return false
	intel -= cost
	slots += 1
	return true


## Equips or unequips an owned perk (free, Armory only). Equipping the
## other alternative of an equipped node replaces it in the same slot;
## otherwise a free slot is needed.
func toggle_equip(id: StringName) -> bool:
	if equipped_perks.has(id):
		equipped_perks.erase(id)
		return true
	var perk: GameData.Perk = GameData.perk(id)
	if perk == null or not owns_perk(id) or not perk.fits_class(selected_class):
		return false
	perk_options[perk.node()] = perk.option
	var current: StringName = equipped_in(perk.node())
	if current != &"":
		equipped_perks[equipped_perks.find(current)] = id
		return true
	if equipped_perks.size() >= slots:
		return false
	equipped_perks.append(id)
	return true


## Audio buses: every sound player sends to "SFX" or "Music", both routed
## to "Master". Created in code so project.godot stays untouched.
const BUS_SFX: StringName = &"SFX"
const BUS_MUSIC: StringName = &"Music"


static func ensure_buses() -> void:
	for bus_name in [BUS_SFX, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, &"Master")


## Applies the three volumes (percent) to their buses.
func apply_volume() -> void:
	ensure_buses()
	_set_bus(&"Master", master_volume)
	_set_bus(BUS_SFX, sfx_volume)
	_set_bus(BUS_MUSIC, music_volume)


static func _set_bus(bus_name: StringName, percent: int) -> void:
	var i: int = AudioServer.get_bus_index(bus_name)
	if i == -1:
		return
	AudioServer.set_bus_mute(i, percent <= 0)
	AudioServer.set_bus_volume_db(i, linear_to_db(percent / 100.0) if percent > 0 else -80.0)
