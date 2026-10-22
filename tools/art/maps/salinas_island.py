"""Salinas: a salt-pan island, built in Blender as a hand-made map proposal.

Run from the repository root (Blender 4.x or 5.x, no GPU needed):
  "<blender>" -b --factory-startup -P tools/art/maps/salinas_island.py

It writes tools/art/maps/salinas_island.blend and tools/art/maps/salinas_markers.json,
and renders three views into docs/design/maps_review/salinas/.

Units: 1 Blender unit = 1 m. The island is 256 x 256 m with the origin at the
south-west corner. Blender (x, y, z) is the game's (x, z, height): the markers
file stores (x, y) as the game's (x, z).

Look: low-poly salt pans. White crust on the dykes, teal brine in the pans,
sand and grey-green scrub, whitewashed mills and sheds with slate and rust
roofs. Nothing in it is green and dense (Jungle), red roofs (Town), yellow
beach (Beach), containers (Port) or black basalt (Volcano).
"""

import bpy
import json
import math
import os

from mathutils import Vector

N = 256  # metres; one vertex per metre, 257 x 257 vertices
CENTRE = 128.0

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".."))
OUT_BLEND = os.path.join(ROOT, "tools", "art", "maps", "salinas_island.blend")
OUT_MARKERS = os.path.join(ROOT, "tools", "art", "maps", "salinas_markers.json")
OUT_RENDER = os.path.join(ROOT, "docs", "design", "maps_review", "salinas")

# The salt-pan field: COLS x ROWS pans, separated by DYKE metre dykes.
PAN_X0, PAN_Y0 = 54, 96
PAN_W, PAN_H, DYKE = 18, 14, 2
COLS, ROWS = 5, 4
PAN_FLOOR = -0.35
DYKE_TOP = 0.85

# A dune ridge on the north-east side of the island (game: north-east).
DUNE_A, DUNE_B = (150.0, 190.0), (206.0, 160.0)


def coast_radius(x, y):
    a = math.atan2(y - CENTRE, x - CENTRE)
    return 92.0 + 6.5 * math.sin(3.0 * a + 0.4) + 3.5 * math.sin(7.0 * a + 1.1)


def segment_distance(p, a, b):
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    length2 = dx * dx + dy * dy
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / length2))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (ay + t * dy))


def classify(x, y):
    """'pan' on a pan floor, 'dyke' on a dyke, None anywhere else."""
    px, py = PAN_W + DYKE, PAN_H + DYKE
    fx, fy = x - PAN_X0, y - PAN_Y0
    if fx < 0 or fy < 0:
        return None
    c, r = int(fx // px), int(fy // py)
    lx, ly = fx - c * px, fy - r * py
    if c < COLS and r < ROWS and lx < PAN_W and ly < PAN_H:
        return "pan"
    if fx < COLS * px - DYKE and fy < ROWS * py - DYKE:
        return "dyke"
    return None


def height(x, y):
    r = math.hypot(x - CENTRE, y - CENTRE)
    t = r - coast_radius(x, y)  # metres outside the coast (negative on land)
    if t > 0.0:
        return -0.3 - min(t, 14.0) * 0.22  # the seabed falls away from the coast
    kind = classify(x, y)
    if kind == "pan":
        return PAN_FLOOR
    if kind == "dyke":
        return DYKE_TOP
    base = 1.1 + 0.35 * math.sin(0.09 * x) * math.cos(0.07 * y)
    dune = 3.6 * math.exp(-(segment_distance((x, y), DUNE_A, DUNE_B) ** 2) / (2.0 * 6.0 ** 2))
    h = base + dune
    if t > -5.0:  # a beach: the land rises from the water over 5 m
        h *= max(0.0, -t / 5.0)
    return h


def material(name, rgb, rough=0.9):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return mat


def build_terrain(mats):
    verts = []
    for j in range(N + 1):
        for i in range(N + 1):
            verts.append((float(i), float(j), height(float(i), float(j))))
    faces, face_mats = [], []
    for j in range(N):
        for i in range(N):
            a = j * (N + 1) + i
            faces.append((a, a + 1, a + 1 + (N + 1), a + (N + 1)))
            cx, cy = i + 0.5, j + 0.5
            kind = classify(cx, cy)
            h = height(cx, cy)
            if h < -0.3 and kind is None:
                slot = "seabed"
            elif kind == "pan":
                slot = "brine"
            elif kind == "dyke":
                slot = "salt"
            elif h > 2.4:
                slot = "scrub"
            else:
                slot = "sand"
            face_mats.append(slot)
    mesh = bpy.data.meshes.new("Terrain")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    order = ["sand", "scrub", "salt", "brine", "seabed"]
    for slot in order:
        mesh.materials.append(mats[slot])
    for poly, slot in zip(mesh.polygons, face_mats):
        poly.material_index = order.index(slot)
    obj = bpy.data.objects.new("Terrain", mesh)
    bpy.context.collection.objects.link(obj)
    return obj


def add_box(name, center, size, mat, rot_z=0.0):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    obj.rotation_euler.z = rot_z
    obj.data.materials.append(mat)
    return obj


def add_cone(name, center, radius, depth, mat, verts=10, rot_z=0.0):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius, radius2=0.0, depth=depth, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler.z = rot_z
    obj.data.materials.append(mat)
    return obj


def add_cylinder(name, center, radius, depth, mat, verts=8):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=center)
    obj = bpy.context.active_object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def ground(x, y):
    return height(x, y)


def add_windmill(name, x, y, mats):
    base = ground(x, y)
    add_cylinder(name + "_Tower", (x, y, base + 4.5), 2.1, 9.0, mats["wall"])
    add_cone(name + "_Cap", (x, y, base + 10.2), 2.7, 2.8, mats["roof"], verts=8)
    hub = (x, y - 2.2, base + 9.2)
    add_cylinder(name + "_Hub", hub, 0.35, 0.8, mats["blade"], verts=6)
    for k in range(4):
        angle = k * math.pi / 2.0  # the radius in the wheel's plane (XZ)
        centre = (hub[0] + math.cos(angle) * 3.2, hub[1] - 0.2, hub[2] + math.sin(angle) * 3.2)
        blade = add_box(name + "_Blade%d" % k, centre, (0.25, 0.12, 6.0), mats["blade"])
        blade.rotation_euler.y = math.pi / 2.0 - angle  # the box's long axis (Z) along the radius


def add_shed(name, x, y, mats, rot_z=0.0):
    base = ground(x, y)
    add_box(name + "_Walls", (x, y, base + 1.6), (5.0, 4.0, 3.2), mats["wall"], rot_z)
    add_cone(name + "_Roof", (x, y, base + 4.3), 3.6, 2.4, mats["slate"], verts=4, rot_z=rot_z + math.pi / 4.0)
    add_box(name + "_Door", (x + 2.5 * math.cos(rot_z), y + 2.5 * math.sin(rot_z), base + 1.0), (0.2, 1.3, 2.0), mats["blue"], rot_z)


def add_pier(mats):
    """A wooden pier from the land straight into the sea, on the south shore."""
    x = 128.0
    # The south shore on this column: the first sea cell going south from the centre.
    y_coast = next(float(y) for y in range(int(CENTRE), 0, -1)
                   if math.hypot(x - CENTRE, y - CENTRE) > coast_radius(x, float(y)))
    y_land = y_coast + 10.0  # where the boat lands: 10 m inland
    y_sea = y_coast - 8.0
    length = y_land - y_sea
    centre_y = (y_land + y_sea) / 2.0
    add_box("Pier_Deck", (x, centre_y, 0.9), (2.2, length, 0.25), mats["wood"])
    for k in range(int(length // 4) + 1):
        py = y_sea + k * 4.0
        add_cylinder("Pier_Piling%d" % k, (x - 1.1, py, -1.2), 0.18, 3.0, mats["wood"], verts=6)
        add_cylinder("Pier_PilingB%d" % k, (x + 1.1, py, -1.2), 0.18, 3.0, mats["wood"], verts=6)
    add_box("Boat_Hull", (x + 4.0, y_sea + 2.0, -0.05), (2.2, 6.0, 0.9), mats["hull"])
    return y_land


def place_markers(land_y):
    """Goals and route markers, as game coordinates (x, y_blender, height)."""
    spots = {
        "Generator1": (73.0, 111.0), "Generator2": (113.0, 127.0), "Generator3": (133.0, 143.0),
        "Cache1": (160.0, 90.0), "Cache2": (56.0, 164.0), "Cache3": (120.0, 62.0), "Cache4": (166.0, 152.0),
        "Choke_NorthGap": (102.0, 92.0), "Choke_EastGap": (154.0, 127.0),
        "Arena_Mill": (160.0, 116.0), "Arena_Pier": (128.0, 52.0),
        "Boat": (128.0, land_y), "PlayerStart": (128.0, land_y + 7.0),
    }
    out = {}
    for name, (x, y) in spots.items():
        bpy.ops.object.empty_add(type="PLAIN_AXES", location=(x, y, ground(x, y) + 0.5))
        marker = bpy.context.active_object
        marker.name = name
        marker.empty_display_size = 1.5
        out[name] = [x, y]
    return out


def setup_scene(mats):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 48
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1280
    scene.render.resolution_y = 720
    scene.render.image_settings.file_format = "PNG"

    sun_data = bpy.data.lights.new("LowSun", "SUN")
    sun_data.energy = 4.0
    sun_data.angle = math.radians(2.0)
    sun_data.color = (1.0, 0.86, 0.68)
    sun = bpy.data.objects.new("LowSun", sun_data)
    sun.rotation_euler = (math.radians(62.0), 0.0, math.radians(-35.0))
    bpy.context.collection.objects.link(sun)

    world = bpy.data.worlds.new("Sky")
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (0.62, 0.74, 0.86, 1.0)
    bg.inputs["Strength"].default_value = 1.0
    scene.world = world


def render_view(name, location, target, ortho_scale=None, square=False):
    scene = bpy.context.scene
    scene.render.resolution_x = 1024 if square else 1280
    scene.render.resolution_y = 1024 if square else 720
    cam_data = bpy.data.cameras.new(name + "_Cam")
    if ortho_scale is not None:
        cam_data.type = "ORTHO"
        cam_data.ortho_scale = ortho_scale
    else:
        cam_data.lens = 35.0
    cam = bpy.data.objects.new(name + "_Cam", cam_data)
    bpy.context.collection.objects.link(cam)
    cam.location = location
    direction = Vector(target) - Vector(location)
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = os.path.join(OUT_RENDER, name + ".png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(cam, do_unlink=True)


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    os.makedirs(os.path.dirname(OUT_BLEND), exist_ok=True)
    os.makedirs(OUT_RENDER, exist_ok=True)

    mats = {
        "sand": material("Sand", (0.78, 0.70, 0.52), 0.9),
        "scrub": material("Scrub", (0.42, 0.47, 0.30), 0.95),
        "salt": material("SaltCrust", (0.93, 0.91, 0.86), 0.55),
        "brine": material("Brine", (0.12, 0.34, 0.35), 0.08),
        "seabed": material("Seabed", (0.22, 0.30, 0.31), 0.8),
        "sea": material("Sea", (0.10, 0.30, 0.40), 0.05),
        "wood": material("Wood", (0.42, 0.31, 0.22), 0.8),
        "wall": material("Whitewash", (0.95, 0.94, 0.90), 0.7),
        "roof": material("RustRoof", (0.60, 0.29, 0.20), 0.7),
        "slate": material("SlateRoof", (0.24, 0.35, 0.42), 0.6),
        "blue": material("BlueDoor", (0.18, 0.38, 0.55), 0.6),
        "blade": material("Blade", (0.90, 0.88, 0.80), 0.6),
        "hull": material("Hull", (0.80, 0.20, 0.16), 0.5),
    }
    setup_scene(mats)
    build_terrain(mats)

    sea = add_box("Sea", (CENTRE, CENTRE, -0.3), (N * 1.6, N * 1.6, 0.01), mats["sea"])
    sea.location.z = -0.3
    land_y = add_pier(mats)

    add_windmill("Mill_West", 50.0, 150.0, mats)
    add_windmill("Mill_East", 160.0, 108.0, mats)
    add_windmill("Mill_North", 172.0, 160.0, mats)
    add_shed("Shed_A", 166.0, 126.0, mats, rot_z=0.2)
    add_shed("Shed_B", 176.0, 134.0, mats, rot_z=-0.1)
    add_shed("Shed_C", 160.0, 140.0, mats, rot_z=0.4)
    for k, (x, y) in enumerate([(158.0, 96.0), (166.0, 100.0), (152.0, 168.0)]):
        add_cone("SaltPile%d" % k, (x, y, ground(x, y) + 0.7), 2.6, 1.4, mats["salt"], verts=10)

    markers = place_markers(land_y)
    with open(OUT_MARKERS, "w", encoding="utf-8") as f:
        json.dump(markers, f, indent=2)
    bpy.ops.wm.save_as_mainfile(filepath=OUT_BLEND)

    render_view("top", (CENTRE, CENTRE, 300.0), (CENTRE, CENTRE, 0.0), ortho_scale=262.0, square=True)
    render_view("oblique", (40.0, 30.0, 70.0), (120.0, 130.0, 2.0))
    render_view("close_pans", (95.0, 70.0, 26.0), (100.0, 118.0, 0.0))
    print("SALINAS_DONE", OUT_BLEND, OUT_MARKERS, OUT_RENDER)


if __name__ == "__main__":
    main()
