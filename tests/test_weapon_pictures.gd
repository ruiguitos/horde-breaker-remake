extends SceneTree
## Menus, phase 5: the loadout shows each weapon's render of its real model (tools/dev/weapon_icon_render.gd),
## the Shotgun card reads pellets and damage each, and the Bigger Mags card is called Ammo Reserves.
## Run: godot --headless --path . --script res://tests/test_weapon_pictures.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _initialize() -> void:
	call_deferred("_run")


## The picture has a transparent background, so a pixel with alpha is the gun.
func _is_gun(pixel: Color) -> bool:
	return pixel.a > 0.1


func _run() -> void:
	for id: StringName in WeaponModel.IDS:
		var path: String = "res://game/ui/art/weapons/%s.png" % id
		var texture: Texture2D = load(path) if ResourceLoader.exists(path) else null
		_check(texture != null, "%s has its render" % id)
		if texture == null:
			continue
		var image: Image = texture.get_image()
		_check(image.get_size() == Vector2i(480, 192), "%s render is 480 x 192 (%s)" % [id, image.get_size()])
		# The background is transparent: a pixel with alpha is the gun.
		var gun: int = 0
		for y in range(0, image.get_height(), 2):
			for x in range(0, image.get_width(), 2):
				if _is_gun(image.get_pixel(x, y)):
					gun += 1
		_check(gun > 60, "%s render shows the gun, not an empty picture (%d opaque pixels)" % [id, gun])
		var touching: int = 0
		for x in image.get_width():
			if _is_gun(image.get_pixel(x, 0)) or _is_gun(image.get_pixel(x, image.get_height() - 1)):
				touching += 1
		for y in image.get_height():
			if _is_gun(image.get_pixel(0, y)) or _is_gun(image.get_pixel(image.get_width() - 1, y)):
				touching += 1
		_check(touching == 0, "%s render keeps the whole gun inside the frame (%d edge pixels touched)" % [id, touching])

	var profile := Profile.new()
	var armory := Control.new()
	armory.set_script(load("res://game/states/armory.gd"))
	armory.set("profile", profile)
	root.add_child(armory)
	call_deferred("_check_screens", armory, profile)


func _check_screens(armory: Control, profile: Profile) -> void:
	var pictures: Array[Node] = armory.find_children("WeaponPicture", "TextureRect", true, false)
	var loadout: int = profile.weapon_loadout().size()
	_check(pictures.size() == loadout and loadout > 0, "the loadout shows a picture per equipped weapon (%d of %d)" % [pictures.size(), loadout])
	var all_textured: bool = true
	for picture: Node in pictures:
		all_textured = all_textured and (picture as TextureRect).texture != null
	_check(all_textured, "every loadout picture has its texture")

	# The issue form (2026-11-11): a list of items and one item's sheet, with its figures. The
	# shotgun's damage reads "damage × pellets"; a single-pellet weapon reads its damage alone.
	armory.call("_select_category", "WEAPONS")
	var shotgun: GameData.Weapon = GameData.weapon(&"shotgun")
	var rifle: GameData.Weapon = GameData.weapon(&"rifle")
	var sheet: VBoxContainer = armory.find_child("ItemSheet", true, false).get_child(0) as VBoxContainer
	armory.call("_show_weapon", sheet, &"shotgun")
	var wanted: String = "%d × %d" % [int(shotgun.damage), shotgun.pellets]
	_check(_texts(sheet).has(wanted), "the Shotgun's sheet reads its damage and pellets ('%s')" % wanted)
	armory.call("_show_weapon", sheet, &"rifle")
	_check(_texts(sheet).has("%d" % int(rifle.damage)) and not _texts(sheet).has(wanted), "a single-pellet weapon reads its plain damage")
	var fallback: Control = armory.call("_weapon_picture", &"no_such_weapon")
	_check(fallback is TextureRect and fallback.name != "WeaponPicture" and (fallback as TextureRect).texture != null,
		"a weapon with no render falls back to its silhouette")
	armory.free()

	var card: CardData = load("res://game/data/cards/bigger_mags.tres")
	_check(card.title == "Ammo Reserves" and card.description.begins_with("+15% maximum reserve ammo per rank"),
		"Bigger Mags is called Ammo Reserves, and its description names the reserve")
	quit(1 if _failures > 0 else 0)


## The texts of every Label under `node`.
func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for label: Node in node.find_children("*", "Label", true, false):
		out.append((label as Label).text)
	return out
