class_name WeaponModel
extends Node3D
## Original Blender GLBs, cached and batched by PBR material for runtime.
## Grip origin, +Y up, -Z forward; Muzzle stays in the same local space.
## The legacy material helper is retained for EscortModel's own equipment.

const TEX: String = "res://assets/textures/polyhaven/"
## Grip calibration in the delivered character rifle muzzle frame. The new
## weapon grip uses this frame; each equipped GLB supplies its own shot tip.
const GRIP_FROM_MUZZLE: Vector3 = Vector3(0, -0.07, 0.6)
const IDS: Array[StringName] = [&"rifle", &"smg", &"machine_gun", &"shotgun", &"marksman"]

## Material presets: Poly Haven set, tint, metallic, roughness scale, texture
## repeats per metre (triplanar in each part's own space, so the texture
## sticks to the gun when it moves).
const MATERIALS: Dictionary = {
	"gunmetal": {"id": "blue_metal_plate", "tint": Color(0.42, 0.43, 0.46), "metal": 0.55, "rough": 0.9, "uv": 1.5},
	"steel": {"id": "blue_metal_plate", "tint": Color(0.5, 0.5, 0.52), "metal": 0.9, "rough": 0.6, "uv": 2.0},
	"polymer": {"id": "rubberized_track", "tint": Color(0.3, 0.3, 0.29), "metal": 0.0, "rough": 1.0, "uv": 1.2},
	"olive": {"id": "rubberized_track", "tint": Color(0.42, 0.44, 0.28), "metal": 0.0, "rough": 1.0, "uv": 1.2},
	"wood": {"id": "american_walnut_veneer", "tint": Color(0.72, 0.52, 0.38), "metal": 0.0, "rough": 0.75, "uv": 1.6},
	"rust": {"id": "rusty_metal_04", "tint": Color(0.55, 0.5, 0.48), "metal": 0.5, "rough": 1.0, "uv": 2.5},
	"bore": {"id": "", "tint": Color(0.02, 0.02, 0.02), "metal": 0.0, "rough": 0.6, "uv": 1.0},
}

## Weapons whose GLB materials get the Poly Haven normal and roughness maps
## (matched by the material name in the GLB). Their colours stay the Blender
## ones: a diffuse map multiplied by them shifted the approved colours, so only
## the surface response changes. The others stay flat until checked the same way
## with tools/dev/zombie_preview.gd.
const TEXTURED: Array[StringName] = [&"rifle"]

const MODEL_DIR: String = "res://assets/models/weapons/tactical_original/"
const FILES: Dictionary = {
	&"rifle": "assault_rifle.glb", &"smg": "smg.glb", &"machine_gun": "machine_gun.glb",
	&"shotgun": "shotgun.glb", &"marksman": "marksman.glb",
}
## Palm contact on the underside of each model's forearm, in grip space.
const SUPPORT_POINTS: Dictionary = {
	&"rifle": Vector3(0, 0.077, -0.26), &"smg": Vector3(0, 0.065, -0.23),
	&"machine_gun": Vector3(0, 0.078, -0.31), &"shotgun": Vector3(0, 0.012, -0.335),
	&"marksman": Vector3(0, 0.094, -0.31),
}

static var _mats: Dictionary = {}
static var _assets: Dictionary = {}

var weapon_id: StringName = &""
var muzzle: Node3D  ## the barrel's tip (flashes, tracers)
var length: float = 0.0  ## muzzle to butt (metres)
var support_point: Vector3  ## left palm contact, in grip space


static func build(id: StringName) -> WeaponModel:
	var w := WeaponModel.new()
	w.weapon_id = id if id in IDS else &"rifle"
	w.name = "Weapon_" + String(w.weapon_id)
	w._build()
	return w


static func material(key: String) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var d: Dictionary = MATERIALS[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = d["tint"]
	m.metallic = d["metal"]
	m.roughness = d["rough"]
	_add_maps(m, d)
	_mats[key] = m
	return m


## The Poly Haven maps of a MATERIALS entry on `m` (triplanar, so they stick
## to the part). Keys without a set keep the flat colour.
static func _add_maps(m: StandardMaterial3D, d: Dictionary) -> void:
	var id: String = d["id"]
	if id == "" or not ResourceLoader.exists(TEX + id + "_diffuse.res"):
		return
	m.albedo_texture = load(TEX + id + "_diffuse.res") as Texture2D
	_add_surface_maps(m, d)


## Normal and roughness only: the surface relief and wear, with the colour left
## to the material (see TEXTURED).
static func _add_surface_maps(m: StandardMaterial3D, d: Dictionary) -> void:
	var id: String = d["id"]
	if id == "" or not ResourceLoader.exists(TEX + id + "_nor_gl.res"):
		return
	m.normal_enabled = true
	m.normal_texture = load(TEX + id + "_nor_gl.res") as Texture2D
	m.roughness_texture = load(TEX + id + "_rough.res") as Texture2D
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * float(d["uv"])
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


## Read each imported scene once; combine only its static surfaces with the
## same original material. UVs, normals, tangents and triangle counts survive.
static func _asset(id: StringName) -> Dictionary:
	if _assets.has(id):
		return _assets[id]
	var path: String = MODEL_DIR + String(FILES[id])
	var packed := load(path) as PackedScene
	assert(packed != null, "Missing imported weapon GLB: " + path)
	var source := packed.instantiate() as Node3D
	var source_muzzle := source.find_child("Muzzle", true, false) as Node3D
	assert(source_muzzle != null, "Missing Muzzle in " + path)
	var groups: Dictionary = {}
	for part: MeshInstance3D in source.find_children("*", "MeshInstance3D", true, false):
		for surface: int in part.mesh.get_surface_count():
			var mat: Material = _surface_material(id, part.get_active_material(surface))
			if not groups.has(mat):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tool.set_material(mat)
				groups[mat] = tool
			(groups[mat] as SurfaceTool).append_from(part.mesh, surface, _in_root(part, source))
	var merged := ArrayMesh.new()
	for mat: Material in groups:
		(groups[mat] as SurfaceTool).commit(merged)
	var data: Dictionary = {"mesh": merged, "muzzle": _in_root(source_muzzle, source)}
	_assets[id] = data
	source.free()
	return data


## The textured material for a GLB material with a Poly Haven set (by name);
## the GLB material itself for the rest, and for weapons not in TEXTURED.
static func _surface_material(id: StringName, mat: Material) -> Material:
	if not TEXTURED.has(id) or not mat is StandardMaterial3D:
		return mat
	var key: String = String(mat.resource_name)
	if not MATERIALS.has(key) or String(MATERIALS[key]["id"]) == "":
		return mat
	# Keep the Blender colour and finish; the maps only add the surface.
	var cache_key: String = "%s/%s" % [id, key]
	if _mats.has(cache_key):
		return _mats[cache_key]
	var src := mat as StandardMaterial3D
	var textured := StandardMaterial3D.new()
	textured.resource_name = key  # the GLB name stays the material's identity
	textured.albedo_color = src.albedo_color
	textured.metallic = src.metallic
	textured.roughness = src.roughness
	_add_surface_maps(textured, MATERIALS[key])
	_mats[cache_key] = textured
	return textured


## Relative transforms without entering the SceneTree (no global queries).
static func _in_root(node: Node3D, root: Node3D) -> Transform3D:
	var result: Transform3D = node.transform
	var parent: Node3D = node.get_parent() as Node3D
	while parent != null and parent != root:
		result = parent.transform * result
		parent = parent.get_parent() as Node3D
	return result


func _build() -> void:
	support_point = SUPPORT_POINTS[weapon_id]
	var data: Dictionary = _asset(weapon_id)
	var geometry := MeshInstance3D.new()
	geometry.name = "Geometry"
	geometry.mesh = data.mesh as ArrayMesh
	add_child(geometry)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.transform = data.muzzle as Transform3D
	add_child(muzzle)
	length = geometry.mesh.get_aabb().size.z


## First person: no shadows from the gun at the eye.
func set_cast_shadow(mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	for part: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		part.cast_shadow = mode
