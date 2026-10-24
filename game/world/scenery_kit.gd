extends RefCounted
## The original scenery kit (Codex, 2026-10-24; CC0): five beach props for the
## horror preset and eight Town facade pieces. Every piece shares one ORM
## material, so the thirteen GLBs do not each carry a copy of the same 1K atlas
## (about 22 MB of duplicated textures, and thirteen copies in VRAM).
##
## The pieces are not wired into the island yet: placing them in the hand-made
## scenes is the user's decision (TODO.md). tools/dev/scenery_kit_preview.gd
## uses this file to show the whole kit in engine.
##
## No class_name on purpose: adding one needs `--import`, and the kit can be
## copied and previewed without touching the project's class registry.

const DIR: String = "res://assets/models/environment/scenery_kit/"

const BEACH: Array[String] = [
	"dead_tree", "driftwood", "stranded_hull", "crooked_dock_post", "fallen_fishing_net",
]
const COASTAL: Array[String] = [
	"window_shutters", "door_frame", "canvas_awning", "small_balcony",
	"exterior_stair", "tavern_sign", "wall_lantern", "chimney",
]

static var _material: ORMMaterial3D


## The material every piece shares: sRGB albedo, tangent normal and the ORM map
## (green = roughness, blue = metallic). Built once and reused.
static func material() -> ORMMaterial3D:
	if _material != null:
		return _material
	var m := ORMMaterial3D.new()
	m.albedo_texture = load(DIR + "textures/scenery_albedo.png") as Texture2D
	m.normal_enabled = true
	m.normal_texture = load(DIR + "textures/scenery_normal.png") as Texture2D
	m.ao_enabled = true
	m.ao_texture = load(DIR + "textures/scenery_orm.png") as Texture2D
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_material = m
	return m


## Path of one piece by name ("dead_tree", "door_frame", ...).
static func path(piece: String) -> String:
	if piece in BEACH:
		return DIR + "beach_horror/" + piece + ".glb"
	return DIR + "coastal_facade/" + piece + ".glb"


## One piece ready to place, with the shared material on every surface. The
## origin is the base centre (beach) or the wall face centre (facades), as the
## kit's README documents.
static func build(piece: String) -> Node3D:
	var packed := load(path(piece)) as PackedScene
	assert(packed != null, "Missing imported scenery piece: " + piece)
	var node := packed.instantiate() as Node3D
	_apply_material(node)
	return node


static func _apply_material(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for surface: int in mesh_instance.mesh.get_surface_count():
			mesh_instance.set_surface_override_material(surface, material())
	for child: Node in node.get_children():
		_apply_material(child)
