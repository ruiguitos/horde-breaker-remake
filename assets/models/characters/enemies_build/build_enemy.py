"""Blocky enemies for Horde Breaker (Blender 5.2, CC0 output). See docs/tech/MODELS_ROUND_BRIEF.md.

  blender -b --factory-startup --python build_enemy.py -- <walker|brute|grabber|bloater|screamer|behemoth>

Each enemy is chamfered boxes grouped into the parts the game's shader animates
(Head, Torso, Arm_Left, Arm_Right, Leg_Left, Leg_Right, plus Belly / Armor_Front),
with the pivot of each part at its joint. Blender axes: Z up, +Y = the enemy's front
(the glTF exporter turns that into +Y up, -Z forward); anatomical Left is -X.
Materials share one 1K atlas per model (base colour, roughness, normal), one 512 px
quadrant per material, generated here with numpy noise. No downloaded meshes or textures.
"""
import bpy, bmesh, json, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
CHAR_DIR = os.path.abspath(os.path.join(HERE, ".."))
ATLAS = 1024
QUAD = {0: (0.0, 0.5), 1: (0.5, 0.5), 2: (0.0, 0.0), 3: (0.5, 0.0)}  # material slot -> UV origin

# Base colour (linear), roughness, grain scale, blotch colour, height strength per material.
MATS = {
    "skin_rot": ((0.17, 0.21, 0.14), 0.78, 18, (0.07, 0.08, 0.05), 0.5),
    "cloth_shirt": ((0.24, 0.235, 0.22), 0.92, 70, (0.11, 0.085, 0.06), 0.35),
    "cloth_trousers": ((0.15, 0.15, 0.155), 0.95, 60, (0.07, 0.06, 0.05), 0.35),
    "flesh_wound": ((0.33, 0.035, 0.03), 0.45, 26, (0.12, 0.01, 0.01), 0.8),
    "bone": ((0.62, 0.58, 0.47), 0.6, 30, (0.40, 0.33, 0.24), 0.4),
    "scrap_metal": ((0.30, 0.27, 0.24), 0.7, 40, (0.32, 0.13, 0.05), 0.6),
}


def B(c, s, mat, rot=(0, 0, 0)):
    """A box: centre, size (m), material name, rotation (degrees XYZ)."""
    return (Vector(c), Vector(s), mat, rot)


def mirror(boxes):
    return [(Vector((-c.x, c.y, c.z)), s, m, (r[0], -r[1], -r[2])) for c, s, m, r in boxes]


# ---------------------------------------------------------------- the enemies
def walker():
    """1.95 m common zombie (also drawn as the Runner), on ZombieModel's joints: hip (±0.12, 0.92),
    shoulder (±0.25, 1.49), neck 1.58; the skull centre near 1.80 m, where the game aims headshots."""
    leg_l = [
        B((-0.12, 0, 0.72), (0.17, 0.19, 0.40), "cloth_trousers"),
        B((-0.12, 0, 0.40), (0.155, 0.17, 0.26), "cloth_trousers"),
        B((-0.12, 0.005, 0.17), (0.12, 0.13, 0.22), "skin_rot"),          # torn trouser: bare shin
        B((-0.12, 0.0, 0.29), (0.165, 0.18, 0.05), "cloth_trousers", (6, 0, 4)),  # ragged hem
        B((-0.12, 0.05, 0.04), (0.12, 0.27, 0.08), "skin_rot"),
        B((-0.12, 0.17, 0.035), (0.11, 0.05, 0.06), "skin_rot", (12, 0, 0)),
    ]
    leg_r = mirror(leg_l)
    leg_r[2] = B((0.12, 0.005, 0.17), (0.12, 0.13, 0.22), "flesh_wound")  # chewed shin
    leg_r.append(B((0.12, 0.0, 0.17), (0.035, 0.035, 0.30), "skin_rot"))   # shin bone
    torso = [
        B((0, 0, 0.97), (0.38, 0.22, 0.16), "cloth_trousers"),
        B((0, 0, 1.13), (0.35, 0.20, 0.18), "cloth_shirt"),
        B((0, 0.03, 1.33), (0.44, 0.24, 0.26), "cloth_shirt", (-10, 0, 0)),
        B((0, 0.05, 1.47), (0.47, 0.22, 0.08), "cloth_shirt", (-14, 0, 0)),
        B((0, 0.05, 1.59), (0.15, 0.14, 0.18), "skin_rot", (-20, 0, 0)),
        # Torn belly: the shirt is ripped open on the front left, flesh and ribs show.
        B((-0.07, 0.096, 1.15), (0.17, 0.02, 0.15), "flesh_wound"),
        B((-0.07, 0.11, 1.12), (0.15, 0.016, 0.016), "skin_rot"),
        B((-0.07, 0.11, 1.16), (0.15, 0.016, 0.016), "skin_rot"),
        B((-0.07, 0.11, 1.20), (0.15, 0.016, 0.016), "skin_rot"),
        B((0.10, 0.122, 1.30), (0.12, 0.012, 0.16), "flesh_wound"),         # blood down the chest
        B((0.11, 0.118, 1.36), (0.18, 0.02, 0.05), "cloth_shirt", (0, 18, 0)),  # torn flap
        B((-0.05, -0.122, 1.36), (0.20, 0.01, 0.12), "flesh_wound"),       # bite on the back
    ]
    # The whole head hangs forward: every box turns 15 degrees about the neck (0, 1.55).
    neck = Vector((0, 0, 1.55))
    tilt = Euler((math.radians(-15), 0, 0)).to_matrix()
    head = [(neck + tilt @ (c - neck) + Vector((0, 0.07, 0.125)), sz, m, (r[0] - 15, r[1], r[2])) for c, sz, m, r in [
        B((0, 0.01, 1.69), (0.25, 0.25, 0.25), "skin_rot"),
        B((0, 0.035, 1.585), (0.175, 0.17, 0.06), "skin_rot", (8, 0, 0)),    # dropped jaw
        B((0, 0.12, 1.615), (0.15, 0.02, 0.04), "flesh_wound"),           # open mouth
        B((-0.055, 0.132, 1.70), (0.05, 0.012, 0.035), "flesh_wound"),       # eye sockets
        B((0.055, 0.132, 1.70), (0.05, 0.012, 0.035), "flesh_wound"),
        B((0, 0.145, 1.655), (0.045, 0.03, 0.05), "skin_rot"),
        B((-0.132, 0.0, 1.68), (0.03, 0.06, 0.07), "skin_rot"),
        B((0.132, 0.0, 1.68), (0.03, 0.06, 0.07), "skin_rot"),
        B((0.06, -0.03, 1.80), (0.10, 0.13, 0.02), "flesh_wound"),          # scalp torn off
        B((-0.04, -0.02, 1.805), (0.11, 0.17, 0.015), "cloth_trousers"),    # dark matted hair
    ]]
    arm_l = [
        B((-0.275, 0, 1.36), (0.12, 0.135, 0.27), "cloth_shirt"),
        B((-0.28, 0.0, 1.075), (0.10, 0.11, 0.30), "skin_rot"),
        B((-0.28, 0.01, 0.865), (0.09, 0.05, 0.12), "skin_rot"),
        B((-0.265, 0.025, 0.79), (0.02, 0.022, 0.06), "skin_rot"),
        B((-0.285, 0.025, 0.785), (0.02, 0.022, 0.07), "skin_rot"),
        B((-0.305, 0.025, 0.79), (0.02, 0.022, 0.06), "skin_rot"),
        B((-0.28, 0.058, 1.10), (0.07, 0.01, 0.12), "flesh_wound"),
    ]
    arm_r = mirror(arm_l)
    arm_r[1] = B((0.28, 0.0, 1.075), (0.10, 0.11, 0.30), "flesh_wound")     # flayed forearm
    arm_r.append(B((0.28, 0.0, 1.075), (0.04, 0.12, 0.31), "skin_rot"))
    parts = {
        "Torso": (Vector((0, 0, 0)), torso),
        "Head": (Vector((0, 0.02, 1.58)), head),
        "Arm_Left": (Vector((-0.25, 0, 1.49)), arm_l),
        "Arm_Right": (Vector((0.25, 0, 1.49)), arm_r),
        "Leg_Left": (Vector((-0.12, 0, 0.92)), leg_l),
        "Leg_Right": (Vector((0.12, 0, 0.92)), leg_r),
    }
    return {"height": 1.95, "budget": (1500, 2500),
            "materials": ["skin_rot", "cloth_shirt", "cloth_trousers", "flesh_wound"], "parts": parts}


ENEMIES = {"walker": walker}


# ---------------------------------------------------------------- textures
def _noise(size, scale, seed):
    """Tileable value noise with three octaves, 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for octave in range(3):
        cells = max(2, int(scale * (2 ** octave) / 8))
        grid = rng.random((cells, cells))
        x = np.linspace(0, cells, size, endpoint=False)
        i0 = np.floor(x).astype(int)
        f = x - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % cells
        a = grid[np.ix_(i0, i0)]; b = grid[np.ix_(i0, i1)]
        c = grid[np.ix_(i1, i0)]; d = grid[np.ix_(i1, i1)]
        fx = f[None, :]; fy = f[:, None]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        total += amp
        amp *= 0.5
    return out / total


def build_atlas(names, seed):
    half = ATLAS // 2
    col = np.zeros((ATLAS, ATLAS, 4), np.float32); col[..., 3] = 1
    rough = np.zeros((ATLAS, ATLAS, 4), np.float32); rough[..., 3] = 1
    height = np.zeros((ATLAS, ATLAS), np.float32)
    for slot, name in enumerate(names):
        base, r, grain, blotch, hs = MATS[name]
        n1 = _noise(half, grain, seed + slot)
        n2 = _noise(half, grain * 4, seed + 10 + slot)
        mask = np.clip((_noise(half, 10, seed + 20 + slot) - 0.55) * 4, 0, 1)
        c = np.array(base)[None, None, :] * (0.8 + 0.4 * n1[..., None])
        c = c * (1 - mask[..., None]) + np.array(blotch)[None, None, :] * mask[..., None]
        if name == "cloth_shirt" or name == "cloth_trousers":   # dried blood stains on cloth
            blood = np.clip((_noise(half, 7, seed + 40 + slot) - 0.62) * 5, 0, 1)
            c = c * (1 - blood[..., None]) + np.array((0.12, 0.012, 0.01))[None, None, :] * blood[..., None]
        ox, oy = QUAD[slot]
        x0, y0 = int(ox * ATLAS), int(oy * ATLAS)
        col[y0:y0 + half, x0:x0 + half, :3] = c
        rough[y0:y0 + half, x0:x0 + half, :3] = np.clip(r + (n2 - 0.5) * 0.2 - mask * 0.1, 0, 1)[..., None]
        height[y0:y0 + half, x0:x0 + half] = (n2 * 0.6 + n1 * 0.4) * hs
    gy, gx = np.gradient(height * 6.0)
    nrm = np.stack([-gx, -gy, np.ones_like(gx)], axis=2)
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    normal = np.ones((ATLAS, ATLAS, 4), np.float32)
    normal[..., :3] = nrm * 0.5 + 0.5
    return col, rough, normal


def save_image(name, pixels, path, srgb):
    img = bpy.data.images.new(name, ATLAS, ATLAS)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    px = pixels.copy()
    if srgb:  # linear -> sRGB for an 8-bit PNG
        rgb = px[..., :3]
        px[..., :3] = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(rgb, 1 / 2.4) - 0.055)
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.source = "FILE"
    img.filepath = path
    img.reload()
    return img


def make_materials(names, tex_dir, model):
    col, rough, normal = build_atlas(names, seed=sum(map(ord, model)))
    os.makedirs(tex_dir, exist_ok=True)
    ic = save_image(model + "_basecolor", col, os.path.join(tex_dir, model + "_basecolor.png"), True)
    ir = save_image(model + "_roughness", rough, os.path.join(tex_dir, model + "_roughness.png"), False)
    inn = save_image(model + "_normal", normal, os.path.join(tex_dir, model + "_normal.png"), False)
    mats = []
    for name in names:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Metallic"].default_value = 0.4 if name == "scrap_metal" else 0.0
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = ic
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = ir
        nt.links.new(t.outputs["Color"], bsdf.inputs["Roughness"])
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = inn
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        mats.append(m)
    return mats


# ---------------------------------------------------------------- geometry
def build_part(name, pivot, boxes, names, mats, span):
    bm = bmesh.new()
    for c, s, mat, rot in boxes:
        geom = bmesh.ops.create_cube(bm, size=1.0)
        verts = geom["verts"]
        m = Matrix.Translation(c - pivot) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() @ Matrix.Diagonal(s.to_4d())
        bmesh.ops.transform(bm, matrix=m, verts=verts)
        idx = names.index(mat)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = idx  # before the bevel: its new faces take the material of their box
        edges = {e for v in verts for e in v.link_edges}
        bevel = min(0.012, 0.22 * min(s))
        res = bmesh.ops.bevel(bm, geom=list(verts) + list(edges), offset=bevel, segments=1, affect="EDGES",
                              profile=0.5, clamp_overlap=True)
        for f in res.get("faces", []):
            f.material_index = idx
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        ox, oy = QUAD[f.material_index]
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co + pivot
            a, b = [(p.y, p.z), (p.x, p.z), (p.x, p.y)][ax]
            u = ((a / span) + 0.5) % 1.0
            v = ((b / span) + 0.5) % 1.0
            l[uv].uv = (ox + 0.004 + u * 0.492, oy + 0.004 + v * 0.492)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    ob.location = pivot
    bpy.context.scene.collection.objects.link(ob)
    return ob


def render_views(model, height, out_dir):
    scn = bpy.context.scene
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else engines[0]
    scn.render.resolution_x, scn.render.resolution_y = 900, 1000
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.57, 0.6, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scn.world = w
    for d, e in (((1.0, 1.4, -1.5), 3.2), ((-1.2, -0.6, -0.4), 1.0)):
        s = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        s.data.energy = e
        s.rotation_euler = Vector(d).to_track_quat("-Z", "Y").to_euler()
        scn.collection.objects.link(s)
    bpy.ops.mesh.primitive_plane_add(size=40)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam); scn.camera = cam
    mid = Vector((0, 0, height * 0.5))
    d = height * 2.6
    views = {"front": Vector((0, d, 0.1)), "side": Vector((d, 0, 0.1)),
             "three_quarter": Vector((d * 0.7, d * 0.7, height * 0.35))}
    for name, off in views.items():
        cam.location = mid + off
        cam.rotation_euler = (-off).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 50
        scn.render.filepath = os.path.join(out_dir, "%s_%s.png" % (model, name))
        bpy.ops.render.render(write_still=True)
    # Game camera: 16 m away, 9 m up, looking at the enemy.
    scn.render.resolution_x, scn.render.resolution_y = 1280, 720
    off = Vector((0, 16, 9))
    cam.location = mid + off
    cam.rotation_euler = (-off).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 35
    scn.render.filepath = os.path.join(out_dir, "%s_game_camera.png" % model)
    bpy.ops.render.render(write_still=True)


def main():
    model = sys.argv[sys.argv.index("--") + 1]
    spec = ENEMIES[model]()
    out = os.path.join(CHAR_DIR, model + "_original")
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    names = spec["materials"]
    mats = make_materials(names, os.path.join(out, "textures"), model)
    objs = {}
    for pname, (pivot, boxes) in spec["parts"].items():
        objs[pname] = build_part(pname, pivot, boxes, names, mats, spec["height"])
    for pname, ob in objs.items():
        if pname != "Torso":
            ob.parent = objs["Torso"]
    bpy.context.view_layer.update()
    n_tris = 0
    for ob in objs.values():
        ob.data.calc_loop_triangles(); n_tris += len(ob.data.loop_triangles)
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for ob in objs.values():
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    for ob in bpy.context.scene.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, model + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True, export_cameras=False,
                              export_lights=False, export_animations=False, export_skins=False,
                              export_image_format="NONE")
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source", model + ".blend"))
    lo_b, hi_b = spec["budget"]
    report = {
        "model": model, "license": "CC0-1.0", "units": "metres", "forward": "-Z", "up": "+Y",
        "triangles": n_tris, "triangle_budget": [lo_b, hi_b],
        "height_m": round(hi.z, 4), "height_target_m": spec["height"],
        "lowest_point_m": round(lo.z, 4),
        "width_m": round(hi.x - lo.x, 4), "depth_m": round(hi.y - lo.y, 4),
        "materials": names,
        "pivots_m_godot": {k: [round(v[0].x, 4), round(v[0].z, 4), round(-v[0].y, 4)] for k, v in spec["parts"].items()},
        "textures": ["textures/%s_basecolor.png" % model, "textures/%s_roughness.png" % model,
                     "textures/%s_normal.png" % model],
        "texture_source": "numpy noise in build_enemy.py (CC0)",
        "passed": lo_b <= n_tris <= hi_b and abs(hi.z - spec["height"]) <= 0.03 and lo.z >= -0.001,
    }
    with open(os.path.join(out, "validation.json"), "w") as f:
        json.dump(report, f, indent=2)
    with open(os.path.join(out, "LICENSE.txt"), "w") as f:
        f.write("CC0-1.0. Original work for Horde Breaker Remake; built by enemies_build/build_enemy.py.\n")
    render_views(model, spec["height"], os.path.join(out, "renders"))
    print("RESULT", json.dumps({k: report[k] for k in ("passed", "triangles", "height_m", "lowest_point_m")}))


main()
