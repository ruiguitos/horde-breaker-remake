extends SceneTree
## The assault rifle gets the Poly Haven normal and roughness maps on its named
## materials, with its Blender colours left as they are; the other weapons stay
## flat until they are checked the same way.
## Run: godot --headless --path . --script res://tests/test_weapon_texture.gd

var _failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("TEST: " if ok else "TEST FAIL: ") + what)
	if not ok:
		_failures += 1


func _surface_materials(w: WeaponModel) -> Array[StandardMaterial3D]:
	var out: Array[StandardMaterial3D] = []
	var geometry := w.get_node("Geometry") as MeshInstance3D
	for surface: int in geometry.mesh.get_surface_count():
		out.append(geometry.mesh.surface_get_material(surface) as StandardMaterial3D)
	return out


func _initialize() -> void:
	var rifle: WeaponModel = WeaponModel.build(&"rifle")
	var rifle_mats: Array[StandardMaterial3D] = _surface_materials(rifle)
	var with_normal: int = 0
	var with_colour_map: int = 0
	for m: StandardMaterial3D in rifle_mats:
		if m != null and m.normal_texture != null:
			with_normal += 1
		if m != null and m.albedo_texture != null:
			with_colour_map += 1
	_check(with_normal >= 2, "the rifle's named materials get a normal map (%d surfaces)" % with_normal)
	_check(with_colour_map == 0, "the rifle keeps its Blender colours, no diffuse map")
	var roughness_ok: bool = true
	for m: StandardMaterial3D in rifle_mats:
		if m != null and m.normal_texture != null:
			roughness_ok = roughness_ok and m.roughness_texture != null and m.uv1_triplanar
	_check(roughness_ok, "textured rifle surfaces have a roughness map and triplanar mapping")

	var again: WeaponModel = WeaponModel.build(&"rifle")
	var first_textured: StandardMaterial3D = null
	var second_textured: StandardMaterial3D = null
	for m: StandardMaterial3D in rifle_mats:
		if m != null and m.normal_texture != null:
			first_textured = m
			break
	for m: StandardMaterial3D in _surface_materials(again):
		if m != null and m.normal_texture != null:
			second_textured = m
			break
	_check(first_textured != null and first_textured == second_textured,
		"a second rifle reuses the textured material (no new material per gun)")

	var smg: WeaponModel = WeaponModel.build(&"smg")
	var smg_textured: int = 0
	for m: StandardMaterial3D in _surface_materials(smg):
		if m != null and m.normal_texture != null:
			smg_textured += 1
	_check(smg_textured == 0, "the SMG stays flat until it is checked")

	rifle.free()
	again.free()
	smg.free()
	quit(1 if _failures > 0 else 0)
