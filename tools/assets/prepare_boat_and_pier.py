"""Prepare the extraction boat and one pier section for the game, using Blender.

blender --background --python-exit-code 1 --python tools/assets/prepare_boat_and_pier.py

Sources stay in the ignored assets/source/ directory; no network here.
- Boat: "Venus", a Shetland fourareen, Scottish Maritime Museum (Sketchfab), CC0-1.0.
- Pier: Modular Wooden Pier, Poly Haven, CC0-1.0 (section 02: a deck on its poles).
Each becomes one GLB with its textures at 1K, its pivot at the centre of its base, and a
validation.json with triangles, size and SHA-256.
"""
from pathlib import Path
import hashlib
import json
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCES = ROOT / 'assets/source/polyhaven'
TEXTURE_SIZE = 1024

JOBS = [
    {
        'name': 'fourareen_boat',
        'source': SOURCES / 'venus_a_shetland_fourareen/scene.gltf',
        'pick': None,  # every mesh of the file, joined
        'max_triangles': 6000,
        'output': ROOT / 'assets/models/boats/fourareen',
        'credit': '"Venus", a Shetland fourareen, Scottish Maritime Museum, CC0-1.0, '
                  'https://sketchfab.com/3d-models/venus-a-shetland-fourareen-ce4d6915e1d041459e08f2d8da521e86',
    },
    {
        'name': 'wooden_pier_section',
        'source': SOURCES / 'modular_wooden_pier_4k.blend/modular_wooden_pier_4k.blend',
        'pick': ['modular_wooden_pier_section_02'],
        'max_triangles': 2500,
        'output': ROOT / 'assets/models/polyhaven/modular_wooden_pier',
        'credit': 'Modular Wooden Pier, Poly Haven, CC0-1.0, https://polyhaven.com/a/modular_wooden_pier',
    },
]


def load(job):
    source = job['source']
    if source.suffix == '.blend':
        bpy.ops.wm.open_mainfile(filepath=str(source))
    else:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.gltf(filepath=str(source))
    meshes = [o for o in bpy.data.objects if o.type == 'MESH' and (job['pick'] is None or o.name in job['pick'])]
    assert meshes, 'no mesh picked in %s' % source
    for obj in list(bpy.data.objects):
        if obj not in meshes:
            bpy.data.objects.remove(obj, do_unlink=True)
    for obj in meshes:
        if obj.name not in bpy.context.scene.collection.all_objects:
            bpy.context.scene.collection.objects.link(obj)
        matrix = obj.matrix_world.copy()
        obj.parent = None
        obj.matrix_world = matrix
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def triangles(obj):
    obj.data.calc_loop_triangles()
    return len(obj.data.loop_triangles)


def prepare(job):
    obj = load(job)
    source_triangles = triangles(obj)
    # Weld the seams the file formats split, so the decimation can collapse across them.
    geometry = bmesh.new()
    geometry.from_mesh(obj.data)
    bmesh.ops.remove_doubles(geometry, verts=list(geometry.verts), dist=0.00001)
    geometry.to_mesh(obj.data)
    geometry.free()
    obj.data.update()
    if source_triangles > job['max_triangles']:
        modifier = obj.modifiers.new('Game geometry', 'DECIMATE')
        modifier.ratio = (job['max_triangles'] - 16) / source_triangles
        modifier.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    points = [v.co.copy() for v in obj.data.vertices]
    low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    pivot = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
    for vertex in obj.data.vertices:
        vertex.co -= pivot
    obj.location = (0, 0, 0)
    obj.name = job['name']
    textures = []
    for image in bpy.data.images:
        if image.size[0] > TEXTURE_SIZE or image.size[1] > TEXTURE_SIZE:
            image.scale(TEXTURE_SIZE, TEXTURE_SIZE)
        if image.size[0] > 0:
            textures.append({'name': image.name, 'width': image.size[0], 'height': image.size[1]})
    output = job['output']
    output.mkdir(parents=True, exist_ok=True)
    glb = output / (job['name'] + '.glb')
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(glb), export_format='GLB', use_selection=True,
                              export_image_format='JPEG', export_jpeg_quality=88,
                              export_apply=True, export_yup=True, export_animations=False)
    size = high - low
    report = {
        'passed': triangles(obj) <= job['max_triangles'],
        'model': job['name'],
        'credit': job['credit'],
        'source_triangles': source_triangles,
        'triangles': triangles(obj),
        'materials': [m.name for m in obj.data.materials if m],
        'textures': textures,
        'size_blender_xyz_m': [round(size.x, 3), round(size.y, 3), round(size.z, 3)],
        'pivot': 'centre of the base (lowest point)',
        'glb_bytes': glb.stat().st_size,
        'glb_sha256': hashlib.sha256(glb.read_bytes()).hexdigest(),
    }
    (output / 'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    (output / 'LICENSE.txt').write_text(job['credit'] + '\nhttps://creativecommons.org/publicdomain/zero/1.0/\n', encoding='utf-8')
    print('PREPARED:', json.dumps(report))
    assert report['passed'], 'too many triangles'


for item in JOBS:
    prepare(item)
