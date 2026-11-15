"""Build <id>_realistic/ from tactical_original/<id>.glb (Blender 5.2, CC0 output).

Same recipe as assault_rifle_realistic: the tactical geometry (origin at the grip, Muzzle,
part names and lengths already calibrated) gets world-scale box UVs (1.17 UV per metre)
and PBR materials with albedo, normal and ORM maps. gunmetal/steel/polymer/bore maps are
the rifle's own (CC0, this project); wood is generated here (procedural bake).

  blender -b --factory-startup --python build_realistic.py -- <smg|machine_gun|shotgun|marksman>
"""
import bpy, bmesh, json, os, shutil, sys
import numpy as np
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RIFLE_TEX = os.path.join(ROOT, "assault_rifle_realistic", "textures")
UV_PER_M = 1.17
# Tactical file name per game id, overall length (m) and triangle budget.
SPEC = {
    "smg": ("smg", 0.74, (6000, 8000)),
    "machine_gun": ("machine_gun", 1.04, (7000, 9000)),
    "shotgun": ("shotgun", 1.04, (5000, 7000)),
    "marksman": ("marksman", 1.12, (7000, 9000)),
}
# Materials of the tactical models mapped to the realistic set ("rust" folds into steel).
MAT_MAP = {"gunmetal": "gunmetal", "steel": "steel", "bore": "bore", "polymer": "polymer",
           "wood": "wood", "rust": "steel"}
TEX_SIZE = {"gunmetal": 2048, "polymer": 2048, "steel": 1024, "bore": 256, "wood": 1024}


def tris(objs):
    n = 0
    for o in objs:
        o.data.calc_loop_triangles()
        n += len(o.data.loop_triangles)
    return n


def box_uv(o):
    me = o.data
    while me.uv_layers:
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name="UVMap")
    bm = bmesh.new()
    bm.from_mesh(me)
    uv = bm.loops.layers.uv.active
    mw = o.matrix_world
    for f in bm.faces:
        n = (mw.to_3x3() @ f.normal)
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = mw @ l.vert.co
            a, b = [(p.y, p.z), (p.x, p.z), (p.x, p.y)][ax]
            l[uv].uv = (a * UV_PER_M, b * UV_PER_M)
    bm.to_mesh(me)
    bm.free()


def bake_wood(out_dir):
    """Walnut-like wood: 1K albedo, normal and ORM baked from procedural nodes."""
    scn = bpy.data.scenes.new("wood_bake")
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 4
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    plane = bpy.context.active_object
    bpy.context.collection.objects.unlink(plane)
    scn.collection.objects.link(plane)
    mat = bpy.data.materials.new("wood_proc")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    mp = nt.nodes.new("ShaderNodeMapping")
    # Grain runs along U (the gun's length on side faces): stretch features along X.
    mp.inputs["Scale"].default_value = (0.25, 1.0, 1.0)
    nt.links.new(tc.outputs["UV"], mp.inputs["Vector"])
    wave = nt.nodes.new("ShaderNodeTexWave")
    wave.bands_direction = "Y"
    wave.inputs["Scale"].default_value = 30.0
    wave.inputs["Distortion"].default_value = 2.0
    wave.inputs["Detail"].default_value = 2.0
    nt.links.new(mp.outputs["Vector"], wave.inputs["Vector"])
    noise = nt.nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 6.0
    nt.links.new(mp.outputs["Vector"], noise.inputs["Vector"])
    mix = nt.nodes.new("ShaderNodeMix")
    mix.data_type = "FLOAT"
    mix.inputs["Factor"].default_value = 0.35
    nt.links.new(wave.outputs["Fac"], mix.inputs["A"])
    nt.links.new(noise.outputs["Fac"], mix.inputs["B"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (0.035, 0.015, 0.007, 1)
    ramp.color_ramp.elements[1].color = (0.13, 0.06, 0.027, 1)
    nt.links.new(mix.outputs["Result"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    rr = nt.nodes.new("ShaderNodeMapRange")
    rr.inputs["To Min"].default_value = 0.48
    rr.inputs["To Max"].default_value = 0.72
    nt.links.new(mix.outputs["Result"], rr.inputs["Value"])
    nt.links.new(rr.outputs["Result"], bsdf.inputs["Roughness"])
    bump = nt.nodes.new("ShaderNodeBump")
    bump.inputs["Strength"].default_value = 0.35
    nt.links.new(wave.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
    plane.data.materials.append(mat)
    img_node = nt.nodes.new("ShaderNodeTexImage")
    nt.nodes.active = img_node
    bpy.context.window.scene = scn if bpy.context.window else scn
    for o in scn.objects:
        o.select_set(o == plane)
    bpy.context.view_layer.objects.active = plane
    results = {}
    for kind in ("DIFFUSE", "ROUGHNESS", "NORMAL"):
        img = bpy.data.images.new("wood_" + kind, 1024, 1024, float_buffer=False)
        if kind != "DIFFUSE":
            img.colorspace_settings.name = "Non-Color"
        img_node.image = img
        kw = {"type": kind}
        if kind == "DIFFUSE":
            scn.render.bake.use_pass_direct = False
            scn.render.bake.use_pass_indirect = False
            scn.render.bake.use_pass_color = True
        bpy.ops.object.bake(**kw)
        results[kind] = np.array(img.pixels[:], dtype=np.float32).reshape(1024, 1024, 4)
    os.makedirs(out_dir, exist_ok=True)
    rough = results["ROUGHNESS"][:, :, 0]
    orm = np.stack([np.ones_like(rough), rough, np.zeros_like(rough), np.ones_like(rough)], axis=2)
    save_png(results["DIFFUSE"], os.path.join(out_dir, "wood_albedo.png"), srgb=True)
    save_png(results["NORMAL"], os.path.join(out_dir, "wood_normal.png"))
    save_png(orm, os.path.join(out_dir, "wood_orm.png"))
    bpy.data.objects.remove(plane)
    bpy.data.scenes.remove(scn)


def save_png(pixels, path, srgb=False):
    h, w = pixels.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h)
    if not srgb:
        img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(pixels.astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def make_material(name, tex_dir):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")

    def tex(kind, non_color):
        n = nt.nodes.new("ShaderNodeTexImage")
        n.image = bpy.data.images.load(os.path.join(tex_dir, "%s_%s.png" % (name, kind)))
        n.image.name = "%s_%s" % (name, kind)
        if non_color:
            n.image.colorspace_settings.name = "Non-Color"
        return n
    alb = tex("albedo", False)
    nt.links.new(alb.outputs["Color"], bsdf.inputs["Base Color"])
    orm = tex("orm", True)
    sep = nt.nodes.new("ShaderNodeSeparateColor")
    nt.links.new(orm.outputs["Color"], sep.inputs["Color"])
    nt.links.new(sep.outputs["Green"], bsdf.inputs["Roughness"])
    nt.links.new(sep.outputs["Blue"], bsdf.inputs["Metallic"])
    nor = tex("normal", True)
    nm = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nor.outputs["Color"], nm.inputs["Color"])
    nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
    return mat


def add_bevels(meshes, target):
    """Raise a model under its triangle budget with small chamfers on the largest parts."""
    for o in sorted(meshes, key=lambda m: -len(m.data.polygons)):
        if tris(meshes) >= target:
            break
        if "bore" in [m.name.split(".")[0] for m in o.data.materials if m]:
            continue
        mod = o.modifiers.new("chamfer", "BEVEL")
        mod.width = 0.0012
        mod.segments = 2
        mod.limit_method = "ANGLE"
        mod.angle_limit = 0.5
        mod.harden_normals = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)


def render(objs, out_dir, gid):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else scn.render.engine
    scn.render.resolution_x, scn.render.resolution_y = 1280, 720
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.2, 0.24, 0.28, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
    scn.world = world
    sun = bpy.data.objects.new("key", bpy.data.lights.new("key", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = Vector((1.0, 1.2, -1.4)).to_track_quat("-Z", "Y").to_euler()
    scn.collection.objects.link(sun)
    fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "SUN"))
    fill.data.energy = 1.2
    fill.rotation_euler = Vector((0.8, -1.0, -0.3)).to_track_quat("-Z", "Y").to_euler()
    scn.collection.objects.link(fill)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam)
    scn.camera = cam
    os.makedirs(out_dir, exist_ok=True)
    # Blender axes: +Y = game forward (-Z), +Z up.
    views = {
        "left": (Vector((-2.6, 0.12, 0.04)), Vector((0, 0.12, 0.04)), 26.0),
        "three_quarter": (Vector((-1.7, -1.1, 0.75)), Vector((0, 0.12, 0.02)), 30.0),
        # Eye above and left of the stock, looking down the range: the gun sits lower right.
        "first_person": (Vector((-0.13, -0.12, 0.2)), Vector((-0.02, 1.0, -0.02)), 60.0),
    }
    for name, (eye, at, fov) in views.items():
        cam.location = eye
        cam.rotation_euler = (at - eye).to_track_quat("-Z", "Y").to_euler()
        cam.data.angle = np.radians(fov)
        cam.data.clip_start = 0.01
        scn.render.filepath = os.path.join(out_dir, "%s_realistic_%s.png" % (gid, name))
        bpy.ops.render.render(write_still=True)
    for o in (sun, fill, cam):
        bpy.data.objects.remove(o)


def main():
    gid = sys.argv[sys.argv.index("--") + 1]
    src_name, length, (tmin, tmax) = SPEC[gid]
    out = os.path.join(ROOT, gid + "_realistic")
    tex_dir = os.path.join(out, "textures")
    os.makedirs(tex_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT, "tactical_original", src_name + ".glb"))
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    used = sorted({MAT_MAP[m.name.split(".")[0]] for o in meshes for m in o.data.materials if m})
    for name in used:
        if name == "wood":
            bake_wood(tex_dir)
            continue
        for kind in ("albedo", "normal", "orm"):
            shutil.copyfile(os.path.join(RIFLE_TEX, "%s_%s.png" % (name, kind)),
                            os.path.join(tex_dir, "%s_%s.png" % (name, kind)))
    bpy.context.window.scene = bpy.context.scene if bpy.context.window else None
    if tris(meshes) < tmin:
        add_bevels(meshes, tmin + 300)
    mats = {name: make_material(name, tex_dir) for name in used}
    for o in meshes:
        for i, slot in enumerate(o.material_slots):
            if slot.material:
                o.material_slots[i].material = mats[MAT_MAP[slot.material.name.split(".")[0]]]
        box_uv(o)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    n_tris = tris(meshes)
    glb = os.path.join(out, gid + "_realistic.glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", export_yup=True,
                              export_cameras=False, export_lights=False, export_animations=False,
                              export_skins=False, export_apply=True)
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source", gid + "_realistic.blend"))
    # Validation in game axes (x, z, -y).
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for o in meshes:
        for v in o.data.vertices:
            p = o.matrix_world @ v.co
            g = Vector((p.x, p.z, -p.y))
            lo = Vector(map(min, lo, g)); hi = Vector(map(max, hi, g))
    mz = next(o for o in bpy.context.scene.objects if o.name.startswith("Muzzle")).matrix_world.translation
    report = {
        "passed": tmin <= n_tris <= tmax and abs((hi.z - lo.z) - length) <= 0.001 + 1e-6,
        "model": gid + "_realistic", "source_geometry": "tactical_original/%s.glb" % src_name,
        "license_new_work": "CC0-1.0", "units": "metres", "forward": "-Z",
        "triangles": n_tris, "triangle_budget": [tmin, tmax], "mesh_nodes": len(meshes),
        "length_m": round(hi.z - lo.z, 4), "length_target_m": length,
        "bounds_min_m": list(lo), "bounds_max_m": list(hi),
        "muzzle_m": [mz.x, mz.z, -mz.y], "bone_count": 0,
        "materials": used, "material_count": len(used),
        "textures": [{"name": i.name, "width": i.size[0], "height": i.size[1]}
                     for i in bpy.data.images if i.size[0] > 0],
        "texture_sources": {"gunmetal/steel/polymer/bore": "assault_rifle_realistic/textures (CC0, this project)",
                            "wood": "procedural bake in build_realistic.py (CC0)"},
        "parts": sorted(o.name for o in meshes),
    }
    with open(os.path.join(out, "validation.json"), "w") as f:
        json.dump(report, f, indent=2)
    with open(os.path.join(out, "LICENSE.txt"), "w") as f:
        f.write("CC0-1.0. Original work for Horde Breaker Remake; no third-party meshes or textures.\n"
                "https://creativecommons.org/publicdomain/zero/1.0/\n")
    render(meshes, os.path.join(out, "renders"), gid)
    print("RESULT", json.dumps({k: report[k] for k in ("passed", "triangles", "length_m", "materials")}))


main()
