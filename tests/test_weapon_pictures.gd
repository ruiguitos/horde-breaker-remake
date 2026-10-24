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

	armory.call("_select_category", "WEAPONS")
	var pellets: Array[String] = []
	var plain: Array[String] = []
	for label: Node in armory.find_children("*", "Label", true, false):
		var text: String = (label as Label).text
		if "PELLETS" in text:
			pellets.append(text)
		elif " DAMAGE /" in text:
			plain.append(text)
	var shotgun: GameData.Weapon = GameData.weapon(&"shotgun")
	var wanted: String = "%d PELLETS · %d DAMAGE EACH / " % [shotgun.pellets, int(shotgun.damage)]
	_check(pellets.size() == 1 and pellets[0].begins_with(wanted),
		"the Shotgun reads its pellets and damage each (%s, wanted '%s')" % [pellets, wanted])
	_check(not plain.is_empty(), "the other weapons keep their plain damage line (%d cards)" % plain.size())
	var fallback: Control = armory.call("_weapon_picture", &"no_such_weapon")
	_check(fallback is TextureRect and fallback.name != "WeaponPicture" and (fallback as TextureRect).texture != null,
		"a weapon with no render falls back to its silhouette")
	armory.free()

	var card: CardData = load("res://game/data/cards/bigger_mags.tres")
	_check(card.title == "Ammo Reserves" and card.description.begins_with("+15% maximum reserve ammo per rank"),
		"Bigger Mags is called Ammo Reserves, and its description names the reserve")
	quit(1 if _failures > 0 else 0)
