"""Original block-built crawler. Blender 5.x; no external Python packages.

Run: blender --background --factory-startup --python build_crawler.py
Optional: -- --no-render (geometry and contract checks still run).
Construction axes: X right, Y forward, Z up. glTF: X right, Y up, -Z forward.
SPDX-License-Identifier: CC0-1.0
"""
import argparse
import json
import math
from pathlib import Path
import struct
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parent
NAMES = ('Head', 'Torso', 'Arm_Left', 'Arm_Right', 'Hip_Stump_Left',
         'Hip_Stump_Right', 'Hand_Left', 'Hand_Right')
PALETTE = {
    'skin_rot': ('788779', .86),
    'cloth_shirt': ('343d36', .94),
    'cloth_trousers': ('363d43', .96),
    'flesh_wound': ('702024', .32),
    'bone': ('d3c5a2', .79),
    'hair_dark': ('262822', .92),
}
MATERIALS = []
PARTS = {}
HEAD_CENTER = Vector((0, .811, .690))
HEAD_LIFT = .095  # Translate the completed Head only; retain its mesh and UVs.
CHEST_CENTER = Vector((0, .510, .440))
REST_PIVOTS = {
    'Torso': (0, 0, 0), 'Head': (0, .755, .590),
    'Arm_Left': (-.205, .580, .460), 'Arm_Right': (.205, .580, .460),
    'Hip_Stump_Left': (-.085, .015, .245),
    'Hip_Stump_Right': (.085, .015, .245),
    'Hand_Left': (-.242, .845, .056), 'Hand_Right': (.242, .835, .056),
}
PIVOTS = dict(REST_PIVOTS)
PIVOTS['Head'] = (0, .755, .685)


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def linear(channel):
    return channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4


def materials():
    for name, (hex_color, roughness) in PALETTE.items():
        color = tuple(linear(int(hex_color[k:k+2], 16) / 255) for k in (0, 2, 4)) + (1,)
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        mat.diffuse_color = color
        mat.metallic = 0
        mat.roughness = roughness
        nodes = mat.node_tree.nodes
        bsdf = nodes.get('Principled BSDF')
        bsdf.inputs['Metallic'].default_value = 0
        bsdf.inputs['Roughness'].default_value = roughness
        bsdf.inputs['Base Color'].default_value = color
        # Only blood needs vertex tint. All six materials retain explicit PBR
        # base colours; no texture or importer-specific material extension.
        if name == 'flesh_wound':
            vc = nodes.new('ShaderNodeVertexColor')
            vc.layer_name = 'SurfaceTint'
            mix = nodes.new('ShaderNodeMix')
            mix.data_type = 'RGBA'
            mix.blend_type = 'MULTIPLY'
            mix.inputs[0].default_value = 1
            mix.inputs[6].default_value = color
            mat.node_tree.links.new(vc.outputs['Color'], mix.inputs[7])
            mat.node_tree.links.new(mix.outputs[2], bsdf.inputs['Base Color'])
        mat.use_backface_culling = True
        MATERIALS.append(mat)


def raw_mesh(label, vertices, faces, material):
    data = bpy.data.meshes.new(label)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(label, data)
    bpy.context.collection.objects.link(obj)
    for mat in MATERIALS:
        data.materials.append(mat)
    for face in data.polygons:
        face.material_index = list(PALETTE).index(material)
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(data)
    bm.free()
    return obj


def box(center, size, material, bevel=.003, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    obj.rotation_euler = tuple(math.radians(v) for v in rotation)
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for mat in MATERIALS:
        obj.data.materials.append(mat)
    for face in obj.data.polygons:
        face.material_index = list(PALETTE).index(material)
    if bevel:
        mod = obj.modifiers.new('Small block edge chamfer', 'BEVEL')
        mod.width = min(bevel, min(size) * .19)
        mod.segments = 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def octagon(width, depth, chamfer=.18):
    a, b = width / 2, depth / 2
    c = min(width, depth) * chamfer
    return [(-a+c, -b), (a-c, -b), (a, -b+c), (a, b-c),
            (a-c, b), (-a+c, b), (-a, b-c), (-a, -b+c)]


def loft(label, sections, material, axis='Y'):
    """Hand-designed chamfered rectangular rings; faceted, never sculpted."""
    vertices = []
    for center, width, depth in sections:
        for a, b in octagon(width, depth):
            vertices.append((center[0]+a, center[1], center[2]+b) if axis == 'Y'
                            else (center[0]+a, center[1]+b, center[2]))
    n = len(sections)
    faces = [tuple(range(7, -1, -1))]
    for ring in range(n-1):
        for i in range(8):
            j = (i+1) % 8
            faces.append((ring*8+i, ring*8+j, (ring+1)*8+j, (ring+1)*8+i))
    faces.append(tuple(range((n-1)*8, n*8)))
    return raw_mesh(label, vertices, faces, material)


def beam(start, end, width, depth, material, end_scale=.85):
    start, end = Vector(start), Vector(end)
    axis = end-start
    basis = axis.to_track_quat('Z', 'Y').to_matrix()
    points = []
    for pos, scale in [(start, 1), (end, end_scale)]:
        points.extend(pos + basis @ Vector((x, y, 0)) for x, y in octagon(width*scale, depth*scale))
    faces = [tuple(range(7, -1, -1)), tuple(range(8, 16))]
    faces.extend((i, (i+1) % 8, (i+1) % 8+8, i+8) for i in range(8))
    return raw_mesh('Angular limb', points, faces, material)


def boolean(target, tool, operation='UNION'):
    activate(target)
    mod = target.modifiers.new('Solid construction', 'BOOLEAN')
    mod.operation = operation
    mod.solver = 'EXACT'
    mod.object = tool
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool, do_unlink=True)
    return target


def add(target, *details):
    for detail in details:
        boolean(target, detail)
    return target


def pocket(target, center, size, rotation=(0, 0, 0)):
    return boolean(target, box(center, size, 'flesh_wound', .001, rotation), 'DIFFERENCE')


def torso():
    core = loft('Torso', [((0, -.035, .255), .285, .195),
        ((0, .075, .285), .305, .210), ((0, .260, .350), .275, .205),
        ((0, .480, .425), .370, .240), ((0, .590, .460), .405, .230),
        ((0, .685, .490), .325, .190)], 'skin_rot')
    shirt = loft('Torn shirt', [((0, .105, .304), .315, .218),
        ((0, .270, .354), .290, .220), ((0, .480, .427), .384, .254),
        ((0, .595, .462), .415, .244), ((0, .695, .485), .344, .207)], 'cloth_shirt')
    # A real open side, not a decal. Core underneath becomes visible.
    pocket(shirt, (-.178, .375, .449), (.130, .290, .220), (0, 0, 5))
    pocket(shirt, (.055, .420, .563), (.175, .235, .120), (0, 0, -14))
    for y, x in [(.14, -.08), (.155, .045), (.180, .125)]:
        pocket(shirt, (x, y, .405), (.040, .080, .070), (0, 0, -18))
    add(core, shirt)
    # Back laceration: deep, stepped negative spaces, blood-coloured walls.
    pocket(core, (.055, .424, .574), (.130, .190, .120), (0, 0, -14))
    pocket(core, (.002, .476, .570), (.083, .093, .100), (0, 0, 12))
    pocket(core, (-.174, .380, .452), (.080, .225, .140), (0, 0, 5))
    # Open chest wound reads from the front as well as in the flank view.
    pocket(core, (-.045, .709, .482), (.120, .100, .104), (0, 0, -8))
    # Five square-section exposed ribs arch from the flank into the back.
    for i in range(5):
        y = .290 + i * .044
        z = .370 + i * .017
        a, b, c = (-.124, y, z-.004), (-.158, y+.006, z+.031), (-.153, y+.013, z+.069)
        add(core, beam(a, b, .014, .018, 'bone', 1),
            beam(b, c, .014, .018, 'bone', .88))
    # Clavicle and the neck connect into the torso solid.
    add(core, beam((0, .650, .515), (0, .752, .620), .123, .122, 'skin_rot', .80))
    # Raised, ragged shirt edges and old blood tracks intersect their base.
    for x, y, z, length in [(.120, .380, .508, .110), (-.036, .535, .543, .078),
                             (.102, .295, .481, .090), (-.093, .208, .442, .065)]:
        add(core, box((x, y, z), (.017, length, .018), 'flesh_wound', .002, (17, 0, -11)))
    # Wound floor ridges remain connected to the deep pocket floor.
    for i in range(3):
        add(core, box((.035+i*.026, .404, .520), (.018, .103, .017),
                      'flesh_wound', .002, (0, 0, -14)))
    PARTS['Torso'] = core


def head():
    sections = []
    for z, width, depth in [(-.130, .120, .146), (-.104, .171, .206),
                            (-.030, .208, .235), (.062, .213, .228),
                            (.125, .180, .190)]:
        sections.append(((0, HEAD_CENTER.y-z*.14, HEAD_CENTER.z+z), width, depth))
    obj = loft('Head', sections, 'skin_rot', 'Z')
    # A narrow hair cap with distinct block tufts, no round helmet.
    hair = loft('Hair cap', [((0, .803, .777), .204, .221),
        ((0, .799, .815), .181, .195), ((0, .792, .834), .141, .153)], 'hair_dark', 'Z')
    add(obj, hair)
    for x, y, z in [(-.075, .755, .786), (.069, .744, .778), (.020, .745, .800)]:
        add(obj, box((x, y, z), (.039, .052, .052), 'hair_dark', .002, (8, 0, 13)))
    # Deep eye sockets, recessed pale eyes, asymmetric brow, broken nose.
    for side in (-1, 1):
        x = side * .053
        pocket(obj, (x, .932, .723), (.071, .075, .053), (0, side*4, side*5))
        add(obj, box((x, .899, .722), (.035, .018, .025), 'bone', .002),
            box((x+side*.004, .909, .721), (.010, .007, .014), 'hair_dark', .001),
            box((x, .920, .754), (.071, .036, .025), 'skin_rot', .004, (0, 0, side*6)))
    add(obj, box((-.006, .938, .686), (.045, .076, .064), 'skin_rot', .006, (-9, 0, 0)),
        box((-.008, .972, .670), (.053, .041, .030), 'skin_rot', .004))
    for side in (-1, 1):
        add(obj, box((side*.107, .802, .697), (.034, .048, .079), 'skin_rot', .004, (0, side*9, 0)))
    pocket(obj, (.008, .935, .621), (.140, .086, .047), (0, 0, -5))
    pocket(obj, (-.077, .913, .649), (.057, .075, .067), (0, 9, -10))
    for i in range(5):
        add(obj, box((-.045+i*.022, .906, .640), (.015, .026, .022 if i != 3 else .015), 'bone', .001))
    for i in range(3):
        add(obj, box((-.026+i*.023, .910, .605), (.015, .025, .019), 'bone', .001))
    add(obj, box((.083, .922, .657), (.019, .018, .067), 'flesh_wound', .002, (0, 0, -14)))
    PARTS['Head'] = obj


def arms():
    for name, side, dy in [('Left', -1, 0), ('Right', 1, -.010)]:
        shoulder = Vector(PIVOTS['Arm_'+name])
        elbow = Vector((side*.242, .565+dy, .068))
        wrist = Vector(PIVOTS['Hand_'+name])
        obj = beam(shoulder, elbow, .116, .112, 'skin_rot', .85)
        add(obj, beam(elbow, wrist+Vector((0, .008, 0)), .097, .130, 'skin_rot', .77))
        # Ragged short sleeve; the forearm remains almost horizontal.
        end = shoulder.lerp(elbow, .38)
        add(obj, beam(shoulder+Vector((0, -.002, .008)), end, .127, .126, 'cloth_shirt', .91))
        pocket(obj, (side*.284, .577+dy, .334), (.055, .090, .070), (0, 0, side*13))
        # Exposed elbow pad is torn flesh, plus a long forearm abrasion.
        add(obj, box((side*.254, .585+dy, .106), (.076, .075, .027), 'flesh_wound', .004),
            box((side*.252, .713+dy, .106), (.043, .107, .013), 'flesh_wound', .002, (0, 0, side*7)))
        PARTS['Arm_'+name] = obj


def hands():
    for name, side in [('Left', -1), ('Right', 1)]:
        wrist = Vector(PIVOTS['Hand_'+name])
        # Dorsal hand slopes down to the knuckles; palm rests on ground.
        obj = loft('Hand_'+name, [((wrist.x, wrist.y-.013, .052), .075, .066),
            ((wrist.x, wrist.y+.055, .039), .098, .070),
            ((wrist.x, wrist.y+.103, .031), .090, .054)], 'skin_rot')
        lengths = [.068, .088, .078, .060]
        for finger, length in enumerate(lengths):
            x = wrist.x + (finger-1.5)*.023
            if name == 'Right' and finger in (2, 3):
                # Two severed digits: short, bloody, closed ends; no detached props.
                add(obj, box((x, wrist.y+.110, .028), (.020, .031, .035), 'flesh_wound', .002),
                    box((x, wrist.y+.126, .030), (.008, .012, .012), 'bone', .001))
                continue
            start = Vector((x, wrist.y+.086, .031))
            end = Vector((x+side*.007, wrist.y+.088+length, .020))
            add(obj, beam(start, end, .020, .036, 'skin_rot', .83))
            nail = end - Vector((0, .009, -.013))
            add(obj, box(nail, (.013, .019, .005), 'bone', .001))
        # Opposable thumb is abducted but touches the palm, not a floating cube.
        add(obj, beam((wrist.x-side*.035, wrist.y+.032, .035),
                      (wrist.x-side*.080, wrist.y+.094, .022), .032, .039, 'skin_rot', .66))
        add(obj, box((wrist.x+.008, wrist.y+.053, .076), (.036, .048, .016), 'flesh_wound', .002, (0, 0, -11)))
        # The palm/fingertips make actual ground contact, without penetration.
        contact = min(v.co.z for v in obj.data.vertices)
        for vertex in obj.data.vertices:
            vertex.co.z -= contact
        PARTS['Hand_'+name] = obj


def stumps():
    for name, side in [('Left', -1), ('Right', 1)]:
        x = side*.086
        # Short stubs only: no thigh, knee or lower leg geometry.
        obj = loft('Hip_Stump_'+name, [((x, .050, .239), .154, .174),
            ((x+side*.010, -.075, .224), .160, .158),
            ((x+side*.014, -.183, .191), .139, .139),
            ((x+side*.014, -.235, .179), .125, .118)], 'cloth_trousers')
        # Uneven cloth bite at the hem; base remains a sealed solid.
        pocket(obj, (x+side*.050, -.226, .211), (.061, .080, .064), (0, 0, side*15))
        pocket(obj, (x-side*.034, -.226, .138), (.042, .083, .038), (0, 0, -side*13))
        flesh = loft('Torn hip flesh', [((x+side*.010, -.195, .181), .117, .110),
            ((x+side*.014, -.255, .176), .121, .106),
            ((x+side*.010, -.281, .180), .088, .078)], 'flesh_wound')
        add(obj, flesh)
        for j in range(3):
            add(obj, beam((x-.030+j*.029, -.245, .195),
                          (x-.028+j*.028, -.286-(j % 2)*.006, .178+j*.005),
                          .025, .023, 'flesh_wound', .50))
        add(obj, beam((x+side*.006, -.254, .177), (x+side*.012, -.307, .184),
                      .034, .033, 'bone', .70))
        # Cloth fold, intersecting the stump rather than resting as a decal.
        add(obj, box((x-side*.047, -.123, .279), (.024, .093, .021), 'cloth_trousers', .002, (17, 0, 0)))
        PARTS['Hip_Stump_'+name] = obj


def finalize_geometry():
    for name, obj in PARTS.items():
        obj.name = name
        activate(obj)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        # Exact Boolean intersections can leave micron-wide coplanar slivers.
        # A 10-micron construction grid removes numerical residue, far below
        # the smallest authored detail (1 mm), before the final triangulation.
        for vertex in bm.verts:
            vertex.co = tuple(round(c, 5) for c in vertex.co)
        # Weld sub-0.2 mm fragments: these are Boolean residue, not features.
        # They otherwise create extremely skinny triangles and zero Mikk tangents.
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.0002)
        bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=.00005)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(.05),
            verts=list(bm.verts), edges=list(bm.edges), delimit={'MATERIAL'})
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method='BEAUTY', ngon_method='BEAUTY')
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
        # Flat broad facets with geometric chamfers preserve the voxel language.
        for face in obj.data.polygons:
            face.use_smooth = False
        tint = obj.data.color_attributes.new(name='SurfaceTint', type='FLOAT_COLOR', domain='CORNER')
        obj.data.color_attributes.active_color = tint
        for face in obj.data.polygons:
            c = face.center
            noise = .90 + .10 * math.sin(c.x*48+c.y*31+c.z*23)**2
            color = (1, 1, 1, 1)
            if face.material_index == 3:
                # Distinct near-black dried streaks and red, glossier fresh cuts.
                dry = (name == 'Torso' and c.y < .34) or (name.startswith('Arm') and c.y > .65)
                color = (.34, .24, .20, 1) if dry else (.82+noise*.18, .72+noise*.28, .72+noise*.28, 1)
            for loop in face.loop_indices:
                tint.data[loop].color = color


def unwrap():
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS.values():
        obj.select_set(True)
    bpy.context.view_layer.objects.active = PARTS['Torso']
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(1), island_margin=.002,
                             area_weight=0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    # A few skinny Boolean triangles need their own planar UV island.
    repaired = 0
    for obj in PARTS.values():
        uv = obj.data.uv_layers.active.data
        for face in obj.data.polygons:
            ids = list(face.loop_indices)
            a, b, c = [uv[i].uv.copy() for i in ids]
            if abs((b-a).cross(c-a)) > 1e-12:
                continue
            points = [obj.data.vertices[i].co for i in face.vertices]
            edge = (points[1]-points[0]).normalized()
            normal = (points[1]-points[0]).cross(points[2]-points[0]).normalized()
            up = normal.cross(edge)
            for index, point in zip(ids, points):
                d = point-points[0]
                uv[index].uv = (2+repaired*.1+d.dot(edge), 2+d.dot(up))
            repaired += 1
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True, margin=.002)
    bpy.ops.object.mode_set(mode='OBJECT')
    for obj in PARTS.values():
        obj.data.uv_layers.active.name = 'UVMap'


def topology():
    results = {}
    for name, obj in PARTS.items():
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.verts.ensure_lookup_table()
        bm.faces.ensure_lookup_table()
        todo = set(bm.verts)
        volumes = []
        while todo:
            stack = [todo.pop()]
            component = set(stack)
            while stack:
                for edge in stack.pop().link_edges:
                    for v in edge.verts:
                        if v in todo:
                            todo.remove(v)
                            component.add(v)
                            stack.append(v)
            faces = {f for v in component for f in v.link_faces}
            volume = sum(f.verts[0].co.dot(f.verts[1].co.cross(f.verts[2].co))/6 for f in faces)
            volumes.append(volume)
        tree = BVHTree.FromBMesh(bm, epsilon=0)
        hits = []
        for a, b in tree.overlap(tree):
            if a >= b or set(bm.faces[a].verts) & set(bm.faces[b].verts):
                continue
            hits.append((a, b))
        item = dict(triangles=len(bm.faces), connected_components=len(volumes),
            component_volumes_m3=volumes, signed_volume_m3=bm.calc_volume(signed=True),
            nonmanifold_edges=sum(not e.is_manifold for e in bm.edges),
            degenerate_faces=sum(f.calc_area() < 1e-11 for f in bm.faces),
            self_intersection_candidates=len(hits))
        results[name] = item
        bm.free()
    return results


def arrange_pivots():
    for name, obj in PARTS.items():
        pivot = Vector(REST_PIVOTS[name])
        for vertex in obj.data.vertices:
            vertex.co -= pivot
        obj.location = pivot
    root = PARTS['Torso']
    for name, obj in PARTS.items():
        if name == 'Torso':
            continue
        parent_name = name.replace('Hand_', 'Arm_') if name.startswith('Hand_') else 'Torso'
        obj.parent = PARTS[parent_name]
        obj.location = Vector(PIVOTS[name])-Vector(PIVOTS[parent_name])
        obj.rotation_euler = (0, 0, 0)
        obj.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    return root


def neck_vertex_distance():
    head, torso = PARTS['Head'], PARTS['Torso']
    tree = KDTree(len(head.data.vertices))
    for i, vertex in enumerate(head.data.vertices):
        tree.insert(head.matrix_world @ vertex.co, i)
    tree.balance()
    return min(tree.find(torso.matrix_world @ v.co)[2] for v in torso.data.vertices)


def close_neck_gap():
    """Extend only the torso neck to the existing skull base; preserve UVs.

    The cap ring reuses the Head's eight lowest vertex positions exactly.
    New UV islands are placed in unused atlas rectangles; other parts and
    existing torso UV coordinates are never repacked.
    """
    if neck_vertex_distance() < 1e-6:
        return
    head, torso = PARTS['Head'], PARTS['Torso']
    points = [head.matrix_world @ v.co for v in head.data.vertices]
    low = min(p.z for p in points)
    cap = [p for p in points if abs(p.z-low) < 1e-6]
    assert len(cap) == 8, len(cap)
    cy = sum(p.y for p in cap)/8
    cap.sort(key=lambda p: math.atan2(p.y-cy, p.x))
    vertices = []
    for y, z, width, depth in [(.740, .590, .110, .090), (.785, .628, .113, .116)]:
        ring = [Vector((x, y+b, z)) for x, b in octagon(width, depth)]
        ring.sort(key=lambda p: math.atan2(p.y-y, p.x))
        vertices.extend(ring)
    vertices.extend(cap)
    faces = [tuple(range(7, -1, -1)), tuple(range(16, 24))]
    for k in range(2):
        faces.extend((k*8+i, k*8+(i+1)%8, (k+1)*8+(i+1)%8, (k+1)*8+i) for i in range(8))
    tool = raw_mesh('Neck extension', vertices, faces, 'skin_rot')
    tool_uv = tool.data.uv_layers.new(name='UVMap', do_init=False)
    for item in tool_uv.data:
        item.uv = (0, 0)
    boolean(torso, tool)
    bm = bmesh.new(); bm.from_mesh(torso.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.0001)
    bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=.00001)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.to_mesh(torso.data); bm.free(); torso.data.update()
    # Retain exact shared cap positions after the Boolean operation.
    for vertex in torso.data.vertices:
        nearest = min(cap, key=lambda p: (vertex.co-p).length_squared)
        if (vertex.co-nearest).length < .0002:
            vertex.co = nearest
    torso.data.update()
    uv = torso.data.uv_layers.active.data
    new_faces = []
    for face in torso.data.polygons:
        ids = list(face.loop_indices)
        a, b, c = [uv[i].uv for i in ids]
        if abs((b-a).cross(c-a)) < 1e-15:
            new_faces.append(face)
    # Exact triangle packing into existing atlas gaps, without repacking it.
    size = 512
    retained, bins = [], {}
    def cells(coords):
        xs, ys = [p[0] for p in coords], [p[1] for p in coords]
        return [(x, y) for x in range(int(min(xs)*64), int(max(xs)*64)+1)
                for y in range(int(min(ys)*64), int(max(ys)*64)+1)]
    def insert(coords):
        index = len(retained)
        retained.append(coords)
        for cell in cells(coords):
            bins.setdefault(cell, set()).add(index)
    new_ids = {face.index for face in new_faces}
    density_sum, area_sum = 0.0, 0.0
    for obj in PARTS.values():
        data_uv = obj.data.uv_layers.active.data
        for face in obj.data.polygons:
            if obj == torso and face.index in new_ids:
                continue
            coords = [data_uv[i].uv for i in face.loop_indices]
            insert([tuple(p) for p in coords])
            density_sum += abs((coords[1]-coords[0]).cross(coords[2]-coords[0]))*.5
            area_sum += face.area
    density = math.sqrt(density_sum/area_sum)
    islands = []
    for face in new_faces:
        p = [torso.data.vertices[i].co for i in face.vertices]
        a, b = max(((0, 1), (1, 2), (2, 0)), key=lambda pair: (p[pair[1]]-p[pair[0]]).length)
        e = (p[b]-p[a]).normalized()
        n = (p[1]-p[0]).cross(p[2]-p[0]).normalized()
        up = n.cross(e)
        coords = [Vector(((v-p[0]).dot(e)*density, (v-p[0]).dot(up)*density)) for v in p]
        low_uv = Vector((min(v.x for v in coords), min(v.y for v in coords)))
        coords = [v-low_uv for v in coords]
        islands.append((face.area, face, coords))
    for _, face, coords in sorted(islands, key=lambda item: -item[0]):
        found = None
        for turn in range(4):
            rotated = [Vector((v.x*math.cos(turn*math.pi/2)-v.y*math.sin(turn*math.pi/2),
                               v.x*math.sin(turn*math.pi/2)+v.y*math.cos(turn*math.pi/2))) for v in coords]
            offset = Vector((min(v.x for v in rotated), min(v.y for v in rotated)))
            rotated = [v-offset for v in rotated]
            w, h = math.ceil(max(v.x for v in rotated)*size)+2, math.ceil(max(v.y for v in rotated)*size)+2
            for y in range(1, size-h):
                for x in range(1, size-w):
                    candidate = [tuple(v+Vector((x/size, y/size))) for v in rotated]
                    center = sum((Vector(v) for v in candidate), Vector((0, 0)))/3
                    guard = [tuple(center+(Vector(v)-center)*1.015) for v in candidate]
                    nearby = set().union(*(bins.get(cell, set()) for cell in cells(guard)))
                    if all(overlap_area(guard, retained[i]) < 1e-14 for i in nearby):
                        found = candidate; break
                if found is not None:
                    break
            if found is not None:
                break
        assert found is not None, 'No free UV triangle slot'
        insert(found)
        for loop, coord in zip(face.loop_indices, found):
            uv[loop].uv = coord
    colors = torso.data.color_attributes.get('SurfaceTint')
    if colors:
        for color in colors.data:
            if color.color[3] == 0:
                color.color = (1, 1, 1, 1)
    assert neck_vertex_distance() < 1e-6


def read_glb(path):
    raw = path.read_bytes()
    magic, version, size = struct.unpack_from('<III', raw)
    assert magic == 0x46546c67 and version == 2 and size == len(raw)
    offset = 12
    doc, binary = None, None
    while offset < size:
        length, kind = struct.unpack_from('<II', raw, offset)
        offset += 8
        chunk = raw[offset:offset+length]
        offset += length
        if kind == 0x4e4f534a:
            doc = json.loads(chunk)
        elif kind == 0x004e4942:
            binary = chunk
    return doc, binary


def accessor(doc, binary, index):
    item = doc['accessors'][index]
    view = doc['bufferViews'][item['bufferView']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4}[item['type']]
    fmt = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}[item['componentType']]
    pack = struct.Struct('<'+fmt*n)
    offset = view.get('byteOffset', 0)+item.get('byteOffset', 0)
    result = [pack.unpack_from(binary, offset+i*view.get('byteStride', pack.size)) for i in range(item['count'])]
    assert all(math.isfinite(v) for row in result for v in row)
    return result


def cross(a, b, c):
    return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def overlap_area(a, b):
    polygon = list(a)
    if cross(*b) < 0:
        b = (b[0], b[2], b[1])
    for i in range(3):
        if not polygon:
            return 0
        edge0, edge1 = b[i], b[(i+1) % 3]
        output = []
        prev = polygon[-1]
        dp = cross(edge0, edge1, prev)
        for point in polygon:
            d = cross(edge0, edge1, point)
            if (d >= 0) != (dp >= 0):
                t = dp/(dp-d)
                output.append((prev[0]+t*(point[0]-prev[0]), prev[1]+t*(point[1]-prev[1])))
            if d >= 0:
                output.append(point)
            prev, dp = point, d
        polygon = output
    return abs(sum(p[0]*polygon[(i+1) % len(polygon)][1]-p[1]*polygon[(i+1) % len(polygon)][0]
                   for i, p in enumerate(polygon)))*.5


def uv_audit(triangles):
    grid = {}
    pairs = set()
    degenerate = 0
    for i, tri in enumerate(triangles):
        if abs(cross(*tri)) < 1e-13:
            degenerate += 1
        xs, ys = [p[0] for p in tri], [p[1] for p in tri]
        for x in range(int(min(xs)*48), int(max(xs)*48)+1):
            for y in range(int(min(ys)*48), int(max(ys)*48)+1):
                key = (x, y)
                for other in grid.get(key, []):
                    pairs.add((other, i))
                grid.setdefault(key, []).append(i)
    overlaps = [(a, b) for a, b in pairs if overlap_area(triangles[a], triangles[b]) > 1e-10]
    return dict(in_0_1=all(-1e-6 <= v <= 1+1e-6 for tri in triangles for p in tri for v in p),
                degenerate_triangles=degenerate, overlapping_triangle_pairs=len(overlaps),
                overlap_area_tolerance=1e-10)


def validate_glb(geometry):
    doc, binary = read_glb(ROOT/'crawler.glb')
    assert len(doc['scenes']) == 1 and doc.get('scene', 0) == 0
    assert not any(doc.get(k) for k in ('animations', 'skins', 'cameras', 'images', 'textures'))
    assert not doc.get('extensions', {}).get('KHR_lights_punctual')
    nodes = {n['name']: n for n in doc['nodes']}
    assert set(nodes) == set(NAMES) and len(nodes) == len(doc['nodes']) == 8
    assert len(doc['meshes']) == 8 and all('mesh' in n for n in nodes.values())
    root = nodes['Torso']
    assert doc['scenes'][0]['nodes'] == [doc['nodes'].index(root)]
    assert root.get('translation', [0, 0, 0]) == [0, 0, 0]
    assert all(n.get('scale', [1, 1, 1]) == [1, 1, 1] and
               n.get('rotation', [0, 0, 0, 1]) == [0, 0, 0, 1] and 'matrix' not in n for n in nodes.values())
    assert {m['name'] for m in doc['materials']} == set(PALETTE)
    materials_info = {}
    for mat in doc['materials']:
        pbr = mat['pbrMetallicRoughness']
        assert pbr.get('metallicFactor', 1) == 0
        assert not any('Texture' in k for k in pbr)
        materials_info[mat['name']] = dict(base_color=pbr['baseColorFactor'],
            metallic=pbr['metallicFactor'], roughness=pbr['roughnessFactor'])
    bounds = []
    all_uvs = []
    all_densities = []
    mesh_info = {}
    world_vertices = {}
    total = 0
    for name, node in nodes.items():
        world_translation = Vector((PIVOTS[name][0], PIVOTS[name][2], -PIVOTS[name][1]))
        expected_parent = name.replace('Hand_', 'Arm_') if name.startswith('Hand_') else 'Torso'
        local = world_translation if name == 'Torso' else world_translation - Vector(
            (PIVOTS[expected_parent][0], PIVOTS[expected_parent][2], -PIVOTS[expected_parent][1]))
        assert (Vector(node.get('translation', [0, 0, 0]))-local).length < 1e-6
        if name != 'Torso':
            assert doc['nodes'].index(node) in nodes[expected_parent].get('children', [])
        triangles, densities = [], []
        node_bounds = []
        count = 0
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            attrs = primitive['attributes']
            assert {'POSITION', 'NORMAL', 'TANGENT', 'TEXCOORD_0', 'COLOR_0'} <= set(attrs)
            assert 'TEXCOORD_1' not in attrs
            pos, normal, tangent, uv = [accessor(doc, binary, attrs[k]) for k in ('POSITION', 'NORMAL', 'TANGENT', 'TEXCOORD_0')]
            for n, t in zip(normal, tangent):
                assert abs(Vector(n).length-1) < 2e-4 and abs(Vector(t[:3]).length-1) < 2e-4
                assert abs(Vector(n).dot(Vector(t[:3]))) < 2e-4 and abs(abs(t[3])-1) < 1e-6
            node_bounds.extend(Vector(p)+world_translation for p in pos)
            indices = [row[0] for row in accessor(doc, binary, primitive['indices'])]
            assert len(indices) % 3 == 0
            count += len(indices)//3
            for i in range(0, len(indices), 3):
                ids = indices[i:i+3]
                tri = [uv[j] for j in ids]
                triangles.append(tri)
                a, b, c = [Vector(pos[j]) for j in ids]
                area = (b-a).cross(c-a).length*.5
                assert area > 1e-11
                densities.append(math.sqrt(abs(cross(*tri))*.5/area))
        total += count
        world_vertices[name] = node_bounds
        bounds.extend(node_bounds)
        all_densities.extend(densities)
        all_uvs.extend(triangles)
        check = uv_audit(triangles)
        mesh_info[name] = dict(triangles=count, pivot_godot_m=list(world_translation),
            bounds_min_godot_m=[min(p[i] for p in node_bounds) for i in range(3)],
            bounds_max_godot_m=[max(p[i] for p in node_bounds) for i in range(3)],
            ground_clearance_m=min(p.y for p in node_bounds),
            uv=check, uv_density_min=min(densities), uv_density_max=max(densities))
        assert check['in_0_1'] and check['degenerate_triangles'] == 0 and check['overlapping_triangle_pairs'] == 0, (name, check)
    lo = [min(p[i] for p in bounds) for i in range(3)]
    hi = [max(p[i] for p in bounds) for i in range(3)]
    assert 2000 <= total <= 5000, total
    assert 1.20 <= hi[2]-lo[2] <= 1.40 and .55 <= hi[0]-lo[0] <= .66
    assert lo[1] >= -.02
    assert all(abs(mesh_info[name]['ground_clearance_m']) < 1e-5 for name in ('Hand_Left', 'Hand_Right'))
    for item in geometry.values():
        assert item['connected_components'] == 1 and min(item['component_volumes_m3']) > 0, item
        assert item['nonmanifold_edges'] == item['degenerate_faces'] == item['self_intersection_candidates'] == 0, item
    atlas = uv_audit(all_uvs)
    assert atlas['overlapping_triangle_pairs'] == 0
    density_ratio = max(all_densities)/min(all_densities)
    assert density_ratio < 1.05, density_ratio
    head_bounds_center = (mesh_info['Head']['bounds_min_godot_m'][1]+mesh_info['Head']['bounds_max_godot_m'][1])/2
    head_center = HEAD_CENTER + Vector((0, 0, HEAD_LIFT))
    assert abs(head_bounds_center-head_center.z) < .015
    head_to_stumps = max(mesh_info[name]['bounds_max_godot_m'][2]
        for name in ('Hip_Stump_Left', 'Hip_Stump_Right'))-mesh_info['Head']['bounds_min_godot_m'][2]
    neck_tree = KDTree(len(world_vertices['Torso']))
    for index, point in enumerate(world_vertices['Torso']):
        neck_tree.insert(point, index)
    neck_tree.balance()
    neck_distance = min(neck_tree.find(point)[2] for point in world_vertices['Head'])
    assert neck_distance < 1e-6, neck_distance
    report = dict(blender_version=bpy.app.version_string, file='crawler.glb',
        all_checks_passed=True, units='metres', axes=dict(up='+Y', forward='-Z'),
        height_definition='Head: authored skull centre. Chest: sternum-region centre; not skin surface or joint pivot.',
        head_height_m=head_center.z, chest_height_m=CHEST_CENTER.z,
        head_pivot_height_m=nodes['Head']['translation'][1], mesh_top_height_m=hi[1],
        head_torso_minimum_vertex_distance_m=neck_distance, neck_gap_closed=True,
        head_bounds_center_height_m=head_bounds_center,
        head_landmark_godot_m=[head_center.x, head_center.z, -head_center.y],
        chest_landmark_godot_m=[CHEST_CENTER.x, CHEST_CENTER.z, -CHEST_CENTER.y],
        total_length_m=hi[2]-lo[2], total_width_m=hi[0]-lo[0],
        head_to_stumps_length_m=head_to_stumps,
        bounds_min_godot_m=lo, bounds_max_godot_m=hi, minimum_ground_clearance_m=lo[1],
        triangle_count=total, mesh_count=8, node_names=sorted(nodes), material_names=sorted(materials_info),
        materials=materials_info, meshes=mesh_info, geometry=geometry,
        origin_check=dict(passed=True, root='Torso', position_m=[0, 0, 0],
            description='Ground directly under hips; joint translations preserved, all rotations identity and scales one.'),
        uv_check=dict(passed=True, layouts_per_mesh=1, global_atlas=atlas,
            texel_density_max_to_min_ratio=density_ratio,
            method='Smart planar islands, average world area scale, one global non-overlapping 0-1 pack. Exported UV triangles clipped pairwise.'),
        hands_ground_contact_check=dict(passed=True, tolerance_m=1e-5),
        normals_check=dict(passed=True, source='Every GLB primitive', finite_unit_vectors=True),
        tangents_check=dict(passed=True, source='Every GLB primitive', finite_unit_vectors=True, orthogonal_to_normal=True),
        no_textures_cameras_lights_armatures_animations=True,
        limitations=['BVH non-adjacent triangle audit is a numerical check, not an exact solid-intersection proof.',
                    'Anatomical height landmarks are authored markers, not automatically inferred from the silhouette.'])
    (ROOT/'validation.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print('CRAWLER VALIDATED: '+json.dumps(dict(triangles=total, length=report['total_length_m'], width=report['total_width_m'])))
    return report


def preview():
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    # Prefer a locally available GPU, retaining a CPU-only headless fallback.
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'OPTIX'
        prefs.get_devices()
        available = [device for device in prefs.devices if device.type == 'OPTIX']
        if available:
            for device in prefs.devices:
                device.use = device in available
            scene.cycles.device = 'GPU'
            print('PREVIEW DEVICE: '+', '.join(d.name for d in available), flush=True)
    except (KeyError, TypeError, RuntimeError):
        scene.cycles.device = 'CPU'
    scene.render.resolution_x = 1440
    scene.render.resolution_y = 1080
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Medium High Contrast'
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.23, .23, .23, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .65
    temporary = []
    grey = bpy.data.materials.new('Preview only grey')
    grey.diffuse_color = (.22, .22, .22, 1)
    bpy.ops.mesh.primitive_plane_add(size=200, location=(0, 0, -.004))
    floor = bpy.context.object
    floor.data.materials.append(grey)
    temporary.append(floor)
    points = [obj.matrix_world @ v.co for obj in PARTS.values() for v in obj.data.vertices]
    lo = Vector(tuple(min(p[i] for p in points) for i in range(3)))
    hi = Vector(tuple(max(p[i] for p in points) for i in range(3)))
    target = (lo+hi)/2
    for position, energy, size in [((-1.7, 1.4, 2.6), 210, 2.0),
                                   ((1.6, .4, 1.5), 120, 1.7), ((-.2, -1.6, 2.2), 200, 1.4)]:
        data = bpy.data.lights.new('Preview softbox', 'AREA')
        data.energy, data.shape, data.size = energy, 'DISK', size
        obj = bpy.data.objects.new('Preview softbox', data)
        scene.collection.objects.link(obj)
        obj.location = position
        obj.rotation_euler = (target-obj.location).to_track_quat('-Z', 'Y').to_euler()
        temporary.append(obj)
    data = bpy.data.cameras.new('Preview camera')
    camera = bpy.data.objects.new('Preview camera', data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    temporary.append(camera)
    data.type = 'ORTHO'
    for name, direction, scale in [('front', (0, 3, .32), 1.48),
                                   ('side', (-3, 0, .10), 1.75),
                                   ('three_quarter', (-2.1, 2.3, 1.55), 1.78),
                                   ('rear_detail', (-1.25, -2.7, 1.35), 1.65)]:
        camera.location = target+Vector(direction)
        camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
        basis = camera.rotation_euler.to_matrix().transposed()
        corners = [basis @ (Vector((x, y, z))-target)
            for x in (lo.x, hi.x) for y in (lo.y, hi.y) for z in (lo.z, hi.z)]
        span_x = max(v.x for v in corners)-min(v.x for v in corners)
        span_y = max(v.y for v in corners)-min(v.y for v in corners)
        aspect = scene.render.resolution_x/scene.render.resolution_y
        data.ortho_scale = max(scale, max(span_x, span_y*aspect)*1.12)
        scene.render.filepath = str(ROOT/'previews'/('crawler_'+name+'.png'))
        bpy.ops.render.render(write_still=True)
    for obj in temporary:
        bpy.data.objects.remove(obj, do_unlink=True)
    scene.camera = None
    bpy.data.materials.remove(grey)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--no-render', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    (ROOT/'previews').mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.materials, bpy.data.meshes, bpy.data.cameras, bpy.data.lights):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.preferences.filepaths.file_preview_type = 'NONE'
    materials()
    for build in (torso, head, arms, hands, stumps):
        build()
        print('BUILT '+build.__name__, flush=True)
    finalize_geometry()
    geometry = topology()
    print('GEOMETRY '+json.dumps(geometry), flush=True)
    (ROOT/'geometry_check.json').write_text(json.dumps(geometry, indent=2), encoding='utf-8')
    unwrap()
    arrange_pivots()
    close_neck_gap()
    geometry = topology()
    (ROOT/'geometry_check.json').write_text(json.dumps(geometry, indent=2), encoding='utf-8')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'crawler.glb'), export_format='GLB',
        use_selection=True, export_yup=True, export_apply=True, export_texcoords=True,
        export_normals=True, export_tangents=True, export_materials='EXPORT',
        export_vertex_color='ACTIVE', export_all_vertex_colors=False,
        export_animations=False, export_skins=False, export_cameras=False,
        export_lights=False, export_extras=False)
    validate_glb(geometry)
    # Source contains only the eight model meshes. Preview helpers are temporary.
    activate(PARTS['Torso'])
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'crawler.blend'))
    if not args.no_render:
        preview()
    print('CRAWLER BUILD COMPLETE', flush=True)


if __name__ == '__main__':
    main()
