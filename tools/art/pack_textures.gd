extends SceneTree
## Packs the Poly Haven maps downloaded by fetch_polyhaven_textures.py into
## assets/textures/polyhaven/<id>_<map>.res, the same format as the island
## textures (tools/real_island/build.gd): RGBA8 -> mipmaps -> S3TC, saved as
## an ImageTexture. Zombie maps are halved to 512 px (they are small on
## screen); weapon maps stay at 1k (first person shows them up close).
##   godot --headless --path . --script res://tools/art/pack_textures.gd -- <download_dir>

const OUT: String = "res://assets/textures/polyhaven/"
const SIZES: Dictionary = {
	"leather_white": 512, "cotton_jersey": 512, "denim_fabric_06": 512,
	"fabric_leather_02": 512, "rough_linen": 512,
	"blue_metal_plate": 1024, "rubberized_track": 1024, "american_walnut_veneer": 1024,
}
const MAPS: Array[String] = ["diffuse", "nor_gl", "rough"]
## Diffuse maps turned grey so the material tint sets the colour (black or
## olive polymer from a red rubber; blued or bare steel from blue paint).
const GREY: Array[String] = ["rubberized_track", "blue_metal_plate"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		print("TEST FAIL: pass the download folder after --")
		quit(1)
		return
	var bad: int = 0
	for id: String in SIZES:
		for map: String in MAPS:
			var src: String = args[0].path_join("%s_%s.jpg" % [id, map])
			var img := Image.load_from_file(src)
			if img == null:
				print("missing ", src)
				bad += 1
				continue
			img.convert(Image.FORMAT_RGBA8)
			if map == "diffuse" and id in GREY:
				_desaturate(img)
			var size: int = SIZES[id]
			if img.get_width() != size:
				img.resize(size, size, Image.INTERPOLATE_LANCZOS)
			img.generate_mipmaps(map == "nor_gl")
			if img.compress(Image.COMPRESS_S3TC, Image.COMPRESS_SOURCE_GENERIC) != OK:
				print("  %s_%s: not compressed (stays RGBA8)" % [id, map])
			var path: String = OUT + "%s_%s.res" % [id, map]
			if ResourceSaver.save(ImageTexture.create_from_image(img), path) != OK:
				bad += 1
			print("  ", path)
	quit(0 if bad == 0 else 1)


## Luminance only, rescaled so the mean is mid grey (0.5): the tint then
## reads as the colour.
func _desaturate(img: Image) -> void:
	var sum: float = 0.0
	var n: int = img.get_width() * img.get_height()
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			sum += c.get_luminance()
	var k: float = 0.5 / maxf(sum / n, 0.01)
	for y in img.get_height():
		for x in img.get_width():
			var l: float = clampf(img.get_pixel(x, y).get_luminance() * k, 0.0, 1.0)
			img.set_pixel(x, y, Color(l, l, l))
