extends SceneTree
## One-off migration: writes the weapon, card and perk tables as .tres files
## (one per entry) and builds a YARD registry for each type. After this the
## .tres files are the source of truth; edit them in the inspector or in the
## editor's Registry tab. Re-running only adds missing entries.
## Run: godot --headless --path . --script res://tools/dev/build_registries.gd

const WEAPONS: Array = [
	# id, name, damage, rate, range, pellets, spread, pierce, ammo, knockback, cost
	[&"rifle", "Assault Rifle", 12.0, 9.0, 30.0, 1, 2.0, 1, -1, 0.05, 0],
	[&"shotgun", "Shotgun", 9.0, 1.4, 12.0, 8, 22.0, 2, 40, 0.6, 0],
	[&"pistol", "Heavy Pistol", 60.0, 2.2, 35.0, 1, 0.0, 4, 60, 0.3, 0],
	[&"smg", "SMG", 7.0, 16.0, 18.0, 1, 7.0, 1, 300, 0.02, 60],
	[&"marksman", "Marksman Rifle", 110.0, 1.2, 45.0, 1, 0.0, 6, 30, 0.5, 80],
]
const CARDS: Array = [
	[&"shockwave", "Shockwave Breaker", "The breaker releases a shockwave: double radius and +30 damage.", 2],
	[&"quick_breaker", "Hair Trigger", "Breaker cooldown -30%.", 2],
	[&"ricochet", "Ricochet", "Every 4th shot also hits the nearest enemy to the target.", 1],
	[&"explosive_heads", "Pop Goes the Head", "Headshot kills explode (3 m, 30 damage).", 1],
	[&"vampire", "Field Medic", "Headshot kills heal 2 HP.", 2],
	[&"hollow_points", "Hollow Points", "+25% weapon damage.", 3],
	[&"fast_hands", "Fast Hands", "+20% fire rate.", 3],
	[&"magnet", "XP Magnet", "Pickup radius x2.", 1],
	[&"adrenaline", "Adrenaline", "Each kill cuts 0.3 s off the breaker cooldown.", 1],
	[&"executioner", "Executioner", "+60% damage to stunned enemies.", 2],
	[&"bigger_mags", "Bigger Mags", "+30% max special ammo.", 2],
	[&"grenadier", "Grenadier", "Grenade cooldown -20%.", 2],
]
const PERKS: Array = [
	[&"thick_skin", "Thick Skin", "+30 max HP.", 40],
	[&"pack_rat", "Pack Rat", "+50% Shotgun and Heavy Pistol ammo.", 40],
	[&"head_hunter", "Head Hunter", "Wider headshot cone (9° -> 15°).", 60],
	[&"long_breaker", "Battering Ram", "Breaker goes 40% further.", 50],
	[&"demolitions", "Demolitions", "Grenade cooldown -35%, radius +1 m.", 50],
]


func _initialize() -> void:
	var w: Array[Resource] = []
	for i in WEAPONS.size():
		var r: Array = WEAPONS[i]
		var d := WeaponData.new()
		d.display_name = r[1]
		d.damage = r[2]
		d.fire_rate = r[3]
		d.range_m = r[4]
		d.pellets = r[5]
		d.spread_deg = r[6]
		d.pierce = r[7]
		d.max_ammo = r[8]
		d.knockback = r[9]
		d.unlock_cost = r[10]
		d.order = i
		w.append(d)
	_build("weapons", &"WeaponData", WEAPONS, w, [&"unlock_cost"])
	var c: Array[Resource] = []
	for i in CARDS.size():
		var d := CardData.new()
		d.title = CARDS[i][1]
		d.description = CARDS[i][2]
		d.max_stacks = CARDS[i][3]
		d.order = i
		c.append(d)
	_build("cards", &"CardData", CARDS, c, [&"max_stacks"])
	var p: Array[Resource] = []
	for i in PERKS.size():
		var d := PerkData.new()
		d.title = PERKS[i][1]
		d.description = PERKS[i][2]
		d.cost = PERKS[i][3]
		d.order = i
		p.append(d)
	_build("perks", &"PerkData", PERKS, p, [&"cost"])
	_build_world_data()
	quit(0)


## Second migration: enemies, modifiers, classes, biomes and missions, read
## from the GameData tables as they were before moving to .tres. Skipped
## once a registry exists (GameData then reads the registries instead).
func _build_world_data() -> void:
	if not ResourceLoader.exists("res://game/data/enemies.tres"):
		var rows: Array = []
		var res: Array[Resource] = []
		var types: Array = GameData.enemy_types()
		for i in types.size():
			var t: Object = types[i]
			var d := EnemyData.new()
			for prop in ["hp", "speed_min", "speed_max", "damage", "attack_interval", "radius_scale", "height", "color", "xp", "front_armor", "grabs", "pushable", "keep_away", "explodes"]:
				d.set(prop, t.get(prop))
			d.display_name = t.get("display_name")
			d.order = i
			rows.append([t.get("id")])
			res.append(d)
		_build("enemies", &"EnemyData", rows, res, [&"pushable"])
	if not ResourceLoader.exists("res://game/data/modifiers.tres"):
		var rows: Array = []
		var res: Array[Resource] = []
		var mods: Array = GameData.modifiers()
		for i in mods.size():
			var d := ModifierData.new()
			d.title = mods[i].title
			d.description = mods[i].description
			d.intel_mult = mods[i].intel_mult
			d.order = i
			rows.append([mods[i].id])
			res.append(d)
		_build("modifiers", &"ModifierData", rows, res, [])
	if not ResourceLoader.exists("res://game/data/classes.tres"):
		var rows: Array = []
		var res: Array[Resource] = []
		var i: int = 0
		for id: StringName in GameData.CLASS_INFO:
			var info: Dictionary = GameData.CLASS_INFO[id]
			var d := ClassData.new()
			d.display_name = info["name"]
			d.cost = info["cost"]
			d.ability = info["ability"]
			d.text = info["text"]
			d.order = i
			i += 1
			rows.append([id])
			res.append(d)
		_build("classes", &"ClassData", rows, res, [&"cost"])
	if not ResourceLoader.exists("res://game/data/biomes.tres"):
		var rows: Array = []
		var res: Array[Resource] = []
		var i: int = 0
		for id: StringName in GameData.BIOMES:
			var b: Dictionary = GameData.BIOMES[id]
			var d := BiomeData.new()
			d.display_name = b["name"]
			for prop in ["coast", "inland", "building", "foliage", "sky", "fog", "palms"]:
				d.set(prop, b[prop])
			d.on_route = GameData.ISLAND_BIOMES.has(id)
			d.order = i
			i += 1
			rows.append([id])
			res.append(d)
		_build("biomes", &"BiomeData", rows, res, [&"on_route"])
	if not ResourceLoader.exists("res://game/data/missions.tres"):
		var rows: Array = []
		var res: Array[Resource] = []
		var i: int = 0
		for id: StringName in GameData.MISSIONS:
			var d := MissionData.new()
			d.display_name = GameData.MISSIONS[id]["name"]
			d.text = GameData.MISSIONS[id]["text"]
			d.order = i
			i += 1
			rows.append([id])
			res.append(d)
		_build("missions", &"MissionData", rows, res, [])


## Saves each resource as game/data/<kind>/<id>.tres (if missing) and the
## registry game/data/<kind>.tres mapping id <-> uid, with an index.
func _build(kind: String, class_id: StringName, rows: Array, resources: Array[Resource], indexed: Array[StringName]) -> void:
	var dir: String = "res://game/data/%s/" % kind
	DirAccess.make_dir_recursive_absolute(dir)
	var reg := Registry.new()
	reg._class_restriction = class_id
	reg._scan_directory = dir
	reg._scan_auto = true
	reg._scan_remove = true
	# Fresh dictionaries: a Registry made outside the editor is read-only.
	var by_uid: Dictionary[StringName, StringName] = {}
	var by_id: Dictionary[StringName, StringName] = {}
	var index: Dictionary[StringName, Dictionary] = {}
	for prop in indexed:
		index[prop] = {}
	for i in rows.size():
		var id: StringName = rows[i][0]
		var path: String = dir + String(id) + ".tres"
		if not ResourceLoader.exists(path):
			ResourceSaver.save(resources[i], path)
		# Files saved outside the editor get no UID: give them one.
		var uid_id: int = ResourceLoader.get_resource_uid(path)
		if uid_id == ResourceUID.INVALID_ID:
			uid_id = ResourceUID.create_id()
			ResourceSaver.set_uid(path, uid_id)
		if not ResourceUID.has_id(uid_id):
			ResourceUID.add_id(uid_id, path)
		var res: Resource = load(path)
		var uid: StringName = StringName(ResourceUID.id_to_text(uid_id))
		by_uid[uid] = id
		by_id[id] = uid
		for prop in indexed:
			var v: Variant = res.get(prop)
			if not index[prop].has(v):
				index[prop][v] = {}
			index[prop][v][id] = true
	reg._uids_to_string_ids = by_uid
	reg._string_ids_to_uids = by_id
	reg._property_index = index
	var err := ResourceSaver.save(reg, "res://game/data/%s.tres" % kind)
	print("%s: %d entries -> %s" % [kind, rows.size(), error_string(err)])
