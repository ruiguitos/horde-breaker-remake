extends SceneTree
## Pack the verified local CC0 source maps for Terrain3D's existing S3TC layers.
func _initialize() -> void:
	var source: String = "res://assets/source/polyhaven/beach_coast_sand_01_1k/"
	var target: String = "res://game/world/handmade/dressing/coast_sand_01_"
	for spec: Array in [["diffuse", "displacement", "albedo_height"], ["nor_gl", "rough", "normal_rough"]]:
		var rgb: Image = Image.load_from_file(source + spec[0] + ".jpg")
		var alpha: Image = Image.load_from_file(source + spec[1] + ".jpg")
		if rgb == null or alpha == null or rgb.get_size() != Vector2i(1024, 1024) or alpha.get_size() != Vector2i(1024, 1024):
			print("AUTHORING FAIL: sand sources must contain four 1K images")
			quit(1)
			return
		var packed: Image = Terrain3DUtil.pack_image(rgb, alpha, false, false, false, 0)
		packed.generate_mipmaps()
		if packed.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC) != OK or packed.get_format() != Image.FORMAT_DXT5:
			print("AUTHORING FAIL: sand compression did not match the terrain texture array")
			quit(1)
			return
		var texture: ImageTexture = ImageTexture.create_from_image(packed)
		if ResourceSaver.save(texture, target + spec[2] + ".res", ResourceSaver.FLAG_COMPRESS) != OK:
			print("AUTHORING FAIL: packed sand texture could not be saved")
			quit(1)
			return
	print("Coast Sand packed at 1K in S3TC, preserving height and roughness")
	quit()
