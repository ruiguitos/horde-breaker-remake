"""Prepare the CC0 Poly Haven Boulder 01 for the beach pilot, using Blender.

blender --background --python-exit-code 1 --python tools/assets/prepare_beach_boulder.py
Source files remain in the ignored assets/source/ directory; no network here.
"""
from pathlib import Path
import hashlib
import json
import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'assets/source/polyhaven/beach_boulder_01_1k/boulder_01_1k.gltf'
OUTPUT = ROOT / 'assets/models/polyhaven/boulder_01'
MAX_TRIANGLES = 4000

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(SOURCE))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert objects, 'Source has no mesh'
for obj in objects:
    obj.data.calc_loop_triangles()
rock = max(objects, key=lambda o: len(o.data.loop_triangles))
matrix = rock.matrix_world.copy()
rock.parent = None
rock.matrix_world = matrix
for obj in list(bpy.context.scene.objects):
    if obj != rock:
        bpy.data.objects.remove(obj, do_unlink=True)
rock.select_set(True)
bpy.context.view_layer.objects.active = rock
bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
rock.data.calc_loop_triangles()
source_triangles = len(rock.data.loop_triangles)
source_vertices = len(rock.data.vertices)
# glTF duplicates vertices at UV/normal seams. Weld coincident geometry while
# retaining per-corner UVs before decimating; otherwise islands resist collapse.
geometry = bmesh.new()
geometry.from_mesh(rock.data)
bmesh.ops.remove_doubles(geometry, verts=list(geometry.verts), dist=0.00001)
geometry.to_mesh(rock.data)
geometry.free()
rock.data.update()
print('WELD:', source_vertices, '->', len(rock.data.vertices), 'vertices')
if source_triangles > MAX_TRIANGLES:
    modifier = rock.modifiers.new('Beach game geometry', 'DECIMATE')
    modifier.ratio = (MAX_TRIANGLES - 16) / source_triangles
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
rock.name = 'Boulder01'
points = [v.co.copy() for v in rock.data.vertices]
low = Vector(tuple(min(p[i] for p in points) for i in range(3)))
high = Vector(tuple(max(p[i] for p in points) for i in range(3)))
pivot = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
for vertex in rock.data.vertices:
    vertex.co -= pivot
rock.location = (0, 0, 0)
rock.data.calc_loop_triangles()
triangles = len(rock.data.loop_triangles)
assert triangles <= MAX_TRIANGLES, triangles
images = [im for im in bpy.data.images if im.type == 'IMAGE' and im.users > 0]
assert all(max(im.size) <= 1024 for im in images), 'Texture exceeds 1K'
OUTPUT.mkdir(parents=True, exist_ok=True)
target = OUTPUT / 'boulder_01_game.glb'
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB', use_selection=True,
                          export_animations=False, export_cameras=False, export_lights=False,
                          export_texcoords=True, export_normals=True, export_tangents=True)
report = {'source':'https://polyhaven.com/a/boulder_01', 'author':'Rico Cilliers',
          'license':'CC0-1.0', 'source_triangles':source_triangles, 'source_vertices':source_vertices, 'triangles':triangles,
          'dimensions_blender_m':list(high - low), 'pivot':'base centre',
          'materials':len(rock.data.materials),
          'textures':[{'name':im.name, 'size':list(im.size)} for im in images],
          'bytes':target.stat().st_size, 'sha256':hashlib.sha256(target.read_bytes()).hexdigest(),
          'validation_limit':'Offline geometry/export checks; engine import and appearance checked separately.'}
(OUTPUT / 'validation.json').write_text(json.dumps(report, indent=2)+'\n')
(OUTPUT / 'LICENSE.txt').write_text('Boulder 01 by Rico Cilliers / Poly Haven. CC0-1.0.\n'
    'Source: https://polyhaven.com/a/boulder_01\nLicense: https://polyhaven.com/license\n'
    'Modified for this project: reduced geometry, largest source mesh only, base-centred pivot.\n')
(OUTPUT / 'download_manifest.json').write_bytes((SOURCE.parent / 'download_manifest.json').read_bytes())
print('BEACH BOULDER:', triangles, 'triangles;', target.stat().st_size, 'bytes')
