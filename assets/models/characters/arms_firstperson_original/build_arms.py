"""Original first-person rigid-weight arms, Blender 5.x built-ins only.
Run: blender --background --factory-startup --python build_arms.py
Optional: -- --no-render. SPDX-License-Identifier: CC0-1.0
Authored in gun space: +Y up, forward -Z, right-hand grip at the origin.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import bpy
import bmesh
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent
PALETTE = {'sleeve_cloth': ('485345', .94), 'glove': ('272b2b', .86), 'skin': ('b58c70', .66)}
MATS, CORES, FINGERS, JOINTS = [], {}, {}, {}
BONES = [stem+'_'+side for side in ('R', 'L') for stem in ('Shoulder', 'UpperArm', 'Forearm', 'Hand')]
PALM_L = Vector((0, .077, -.26))
WRISTS = {'R': Vector((.040, -.060, .060)), 'L': Vector((-.052, .030, -.208))}
SHOULDERS = {'R': Vector((.220, -.160, .350)), 'L': Vector((-.220, -.100, .300))}
RIG = None


def B(p):
    return Vector((p[0], -p[2], p[1]))


def G(p):
    return [float(p[0]), float(p[2]), float(-p[1])]


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def materials():
    for name, (hex_color, roughness) in PALETTE.items():
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        values = [int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4)]
        values = [v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4 for v in values]
        mat.diffuse_color = (*values, 1)
        mat.metallic, mat.roughness, mat.use_backface_culling = 0, roughness, True
        bsdf = mat.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value = (*values, 1)
        bsdf.inputs['Metallic'].default_value = 0
        bsdf.inputs['Roughness'].default_value = roughness
        MATS.append(mat)


def raw(name, vertices, faces, material):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([B(v) for v in vertices], [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    for mat in MATS:
        mesh.materials.append(mat)
    for face in mesh.polygons:
        face.material_index = list(PALETTE).index(material)
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free()
    return obj


def octagon(width, depth):
    a, b, c = width/2, depth/2, min(width, depth)*.18
    return [(-a+c, -b), (a-c, -b), (a, -b+c), (a, b-c), (a-c, b), (-a+c, b), (-a, b-c), (-a, -b+c)]


def tube(name, points, widths, depths, material, guide=(0, 1, 0)):
    points = [Vector(p) for p in points]
    vertices = []
    for i, p in enumerate(points):
        axis = (points[min(i+1, len(points)-1)]-points[max(i-1, 0)]).normalized()
        u = Vector(guide)-axis*Vector(guide).dot(axis)
        if u.length < .1:
            u = Vector((1, 0, 0))-axis*axis.x
        u.normalize(); v = axis.cross(u).normalized()
        vertices.extend(p+u*x+v*y for x, y in octagon(widths[i], depths[i]))
    faces = [tuple(range(7, -1, -1)), tuple(range((len(points)-1)*8, len(points)*8))]
    for k in range(len(points)-1):
        faces.extend((k*8+i, k*8+(i+1)%8, (k+1)*8+(i+1)%8, (k+1)*8+i) for i in range(8))
    return raw(name, vertices, faces, material)


def box(center, size, material, bevel=.002):
    vertices = [Vector(center)+Vector((x*size[0]/2, y*size[1]/2, z*size[2]/2))
                for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    obj = raw('Chamfered detail', vertices, faces, material)
    if bevel:
        activate(obj)
        mod = obj.modifiers.new('Soft block edges', 'BEVEL')
        mod.width, mod.segments = min(bevel, min(size)*.20), 1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def add(target, tool):
    activate(target)
    mod = target.modifiers.new('Closed solid union', 'BOOLEAN')
    mod.operation, mod.solver, mod.object = 'UNION', 'EXACT', tool
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.data.objects.remove(tool, do_unlink=True)
    return target


def elbow(side):
    s, w = SHOULDERS[side], WRISTS[side]
    axis = (w-s).normalized(); distance = (w-s).length
    assert distance < .6
    pole = Vector((1 if side == 'R' else -1, -1, .10))
    pole = (pole-axis*pole.dot(axis)).normalized()
    return (s+w)/2 + pole*math.sqrt(.30**2-(distance/2)**2)


def forearms_and_palms():
    for side in ('R', 'L'):
        w, e = WRISTS[side], elbow(side)
        direction = (w-e).normalized()
        JOINTS[side] = dict(shoulder=SHOULDERS[side], elbow=e, wrist=w)
        ts = [0, .035, .100, .170, .230, .270, .280]
        obj = tube('Arm_'+side, [e+direction*t for t in ts],
            [.098, .105, .096, .082, .066, .061, .062],
            [.090, .094, .086, .074, .060, .055, .056], 'sleeve_cloth', (1, 0, 0))
        # Broad plain cuff, cloth folds and a narrow skin reveal at the wrist.
        for t in (.075, .180, .263, .276):
            width = .101-.15*t
            add(obj, tube('Cuff and fabric fold', [e+direction*(t-.003), e+direction*(t+.003)],
                [width, width], [width*.90, width*.90], 'sleeve_cloth', (1, 0, 0)))
        add(obj, tube('Bare wrist', [e+direction*t for t in (.268, .291, .300, .316)],
            [.052, .051, .051, .049], [.046, .045, .045, .043], 'skin', (1, 0, 0)))
        if side == 'R':
            palm = tube('Palm_R', [(.040, -.052, .069), (.040, -.028, .040),
                (.040, -.022, .004), (.039, -.021, -.022)],
                [.048, .078, .083, .072], [.027, .035, .034, .028], 'glove')
            add(obj, palm)
            add(obj, tube('Thenar and glove heel', [w, (.040, -.031, .036), (.038, .007, .022)],
                [.049, .050, .038], [.040, .043, .029], 'glove', (1, 0, 0)))
            add(obj, box((.061, -.023, .017), (.008, .054, .041), 'glove', .003))
        else:
            add(obj, tube('Glove heel', [w, (-.027, .052, -.231), (-.012, .062, -.251)],
                [.051, .057, .066], [.044, .041, .035], 'glove', (1, 0, 0)))
            add(obj, box((0, .064, -.260), (.088, .026, .092), 'glove', .004))
            add(obj, box((-.028, .049, -.259), (.027, .010, .050), 'glove', .002))
        obj.name = 'Arm_'+side
        CORES[side] = obj


def make_finger(side, name, points, width, depth):
    # Intermediate rings make each phalanx and knuckle legible in silhouette.
    p = [Vector(v) for v in points]
    refined = [p[0]]
    for a, b in zip(p, p[1:]):
        refined.extend((a.lerp(b, .5), b))
    n = len(refined)
    widths = [width*(1-.23*i/(n-1))*(1.05 if i in (2, 4) else 1) for i in range(n)]
    depths = [depth*(1-.25*i/(n-1)) for i in range(n)]
    obj = tube(name+'_'+side, refined, widths, depths, 'glove', (0, 1, 0) if side == 'R' else (0, 0, 1))
    # Exposed work-glove knuckles, not painted emblems or textures.
    if name != 'Thumb':
        if side == 'R':
            center = p[0]+Vector((.009, 0, -.005))
            add(obj, box(center, (.012, width*.73, .019), 'skin', .0015))
        else:
            center = p[1]+Vector((.003, .005, 0))
            add(obj, box(center, (.017, .010, width*.78), 'skin', .0015))
    obj.name = name+'_'+side
    FINGERS[(side, name)] = obj


def fingers():
    make_finger('R', 'Index', [(.048, .010, -.006), (.047, .012, -.036),
        (.043, .014, -.064), (.037, .012, -.088)], .019, .022)
    for name, y, scale in [('Middle', -.016, 1), ('Ring', -.038, .95), ('Little', -.059, .80)]:
        make_finger('R', name, [(.045, y, -.015), (.040, y, -.042*scale),
            (.002, y, -.054*scale), (-.026, y, -.032*scale), (-.027, y, -.008)], .018, .022)
    make_finger('R', 'Thumb', [(.043, .014, .035), (.020, .031, .023),
        (-.012, .029, .012), (-.031, .014, -.013)], .024, .025)
    for name, z, length in [('Index', -.296, 1), ('Middle', -.273, 1.03), ('Ring', -.250, .96), ('Little', -.228, .82)]:
        make_finger('L', name, [(.027, .064, z), (.050, .082, z),
            (.054, .082+.026*length, z-.002), (.043, .082+.055*length, z-.005),
            (.020, .082+.057*length, z-.007)], .019, .021)
    make_finger('L', 'Thumb', [(-.032, .068, -.235), (-.053, .084, -.250),
        (-.051, .109, -.271), (-.037, .122, -.284)], .024, .025)


def finalize():
    result = {}
    for obj in list(CORES.values())+list(FINGERS.values()):
        bm = bmesh.new(); bm.from_mesh(obj.data)
        for vertex in bm.verts:
            vertex.co = tuple(round(c, 5) for c in vertex.co)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.0002)
        bmesh.ops.dissolve_degenerate(bm, edges=list(bm.edges), dist=.00005)
        bmesh.ops.dissolve_limit(bm, angle_limit=math.radians(.05), verts=list(bm.verts), edges=list(bm.edges), delimit={'MATERIAL'})
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bmesh.ops.triangulate(bm, faces=list(bm.faces))
        bad = sum(not edge.is_manifold for edge in bm.edges)
        deg = sum(face.calc_area() < 1e-11 for face in bm.faces)
        volume = bm.calc_volume(signed=True)
        assert bad == deg == 0 and volume > 0, (obj.name, bad, deg, volume)
        result[obj.name] = dict(triangles=len(bm.faces), nonmanifold_edges=bad, degenerate_faces=deg, volume_m3=volume)
        bm.to_mesh(obj.data); bm.free(); obj.data.update()
        for face in obj.data.polygons:
            face.use_smooth = False
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = CORES['R']
    bpy.ops.object.mode_set(mode='EDIT'); bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(1), island_margin=.0015)
    bpy.ops.uv.average_islands_scale(); bpy.ops.uv.pack_islands(rotate=True, margin=.0015)
    bpy.ops.object.mode_set(mode='OBJECT')
    return result


def bone_matrix(start, end):
    axis = (end-start).normalized()
    matrix = axis.to_track_quat('Y', 'Z').to_matrix().to_4x4()
    matrix.translation = start
    return matrix


def rig_and_bind():
    global RIG
    data = bpy.data.armatures.new('Arms')
    RIG = bpy.data.objects.new('Arms', data)
    bpy.context.collection.objects.link(RIG); activate(RIG)
    bpy.ops.object.mode_set(mode='EDIT')
    rest = {}
    for side in ('R', 'L'):
        s, w = SHOULDERS[side], WRISTS[side]
        direction = (w-s).normalized()
        edit_e, edit_w = s+direction*.30, s+direction*.60
        hand_direction = (Vector((.039, -.010, -.025)) if side == 'R' else PALM_L)-w
        hand_direction.normalize()
        points = [('Shoulder', s-Vector((.035 if side == 'R' else -.035, 0, 0)), s),
            ('UpperArm', s, edit_e), ('Forearm', edit_e, edit_w),
            ('Hand', edit_w, edit_w+hand_direction*.09)]
        parent = None
        for stem, a, b in points:
            name = stem+'_'+side
            bone = data.edit_bones.new(name)
            bone.head, bone.tail, bone.parent = B(a), B(b), parent
            if parent:
                bone.use_connect = True
            bone.use_deform = True
            rest[name] = dict(head_gun_m=list(a), tail_gun_m=list(b), length_m=(b-a).length)
            parent = bone
    bpy.ops.object.mode_set(mode='OBJECT')
    for side in ('R', 'L'):
        joints = JOINTS[side]
        s, e, w = joints['shoulder'], joints['elbow'], joints['wrist']
        target = Vector((.039, -.010, -.025)) if side == 'R' else PALM_L
        for stem, a, b in [('UpperArm', s, e), ('Forearm', e, w), ('Hand', w, w+(target-w).normalized()*.09)]:
            RIG.pose.bones[stem+'_'+side].matrix = bone_matrix(B(a), B(b))
            bpy.context.view_layer.update()
    matrices = {name: RIG.pose.bones[name].matrix @ data.bones[name].matrix_local.inverted() for name in BONES}
    blend_counts, bind_error = {}, 0.0
    for side, obj in CORES.items():
        w, e = B(WRISTS[side]), B(JOINTS[side]['elbow'])
        direction = (w-e).normalized()
        groups = {stem: obj.vertex_groups.new(name=stem+'_'+side) for stem in ('Forearm', 'Hand')}
        blend_counts[side] = 0
        desired = [vertex.co.copy() for vertex in obj.data.vertices]
        for vertex in obj.data.vertices:
            d = (vertex.co-w).dot(direction)
            blend = abs(d) <= .0065 and (vertex.co-w).length < .055
            names = ['Forearm_'+side, 'Hand_'+side] if blend else [('Hand_' if d > 0 else 'Forearm_')+side]
            weights = [.5, .5] if blend else [1.0]
            matrix = Matrix(((0, 0, 0, 0),)*4)
            for name, weight in zip(names, weights):
                matrix += matrices[name]*weight
                groups[name.split('_')[0]].add([vertex.index], weight, 'REPLACE')
            vertex.co = matrix.inverted() @ vertex.co
            blend_counts[side] += int(blend)
        mod = obj.modifiers.new('Arms rigid skin and wrist blend', 'ARMATURE'); mod.object = RIG
        obj.parent = RIG
        bpy.context.view_layer.update()
        evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
        bind_error = max(bind_error, max((v.co-p).length for v, p in zip(evaluated.data.vertices, desired)))
    for (side, name), obj in FINGERS.items():
        hand = RIG.pose.bones['Hand_'+side]
        inv = hand.matrix.inverted()
        for vertex in obj.data.vertices:
            vertex.co = inv @ vertex.co
        group = obj.vertex_groups.new(name='Hand_'+side)
        group.add(list(range(len(obj.data.vertices))), 1, 'REPLACE')
        obj.parent, obj.parent_type, obj.parent_bone = RIG, 'BONE', 'Hand_'+side
        obj.matrix_parent_inverse = Matrix.Identity(4)
        obj.location = (0, -data.bones['Hand_'+side].length, 0)
        obj.rotation_euler = (0, 0, 0); obj.scale = (1, 1, 1)
    bpy.context.view_layer.update()
    assert bind_error < 2e-5 and min(blend_counts.values()) > 0, (bind_error, blend_counts)
    posed = {name: dict(head_gun_m=G(RIG.pose.bones[name].head), tail_gun_m=G(RIG.pose.bones[name].tail)) for name in BONES}
    return dict(rest_bones=rest, default_pose_bones=posed, wrist_blended_vertices=blend_counts,
        maximum_pose_reconstruction_error_m=bind_error)


def read_glb(path):
    raw = path.read_bytes(); magic, version, size = struct.unpack_from('<III', raw)
    assert magic == 0x46546c67 and version == 2 and size == len(raw)
    offset, doc, binary = 12, None, None
    while offset < size:
        count, kind = struct.unpack_from('<II', raw, offset); offset += 8
        chunk = raw[offset:offset+count]; offset += count
        if kind == 0x4e4f534a: doc = json.loads(chunk)
        if kind == 0x004e4942: binary = chunk
    return doc, binary


def accessor(doc, binary, index):
    a = doc['accessors'][index]; view = doc['bufferViews'][a['bufferView']]
    n = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}[a['type']]
    fmt = {5121: 'B', 5123: 'H', 5125: 'I', 5126: 'f'}[a['componentType']]
    pack = struct.Struct('<'+fmt*n); start = view.get('byteOffset', 0)+a.get('byteOffset', 0)
    result = [pack.unpack_from(binary, start+i*view.get('byteStride', pack.size)) for i in range(a['count'])]
    if a.get('normalized'):
        divisor = {5121: 255, 5123: 65535}[a['componentType']]
        result = [tuple(v/divisor for v in row) for row in result]
    return result


def node_matrix(node):
    if 'matrix' in node:
        return Matrix([node['matrix'][i:i+4] for i in range(0, 16, 4)]).transposed()
    x, y, z, w = node.get('rotation', (0, 0, 0, 1))
    return Matrix.LocRotScale(Vector(node.get('translation', (0, 0, 0))), Quaternion((w, x, y, z)), Vector(node.get('scale', (1, 1, 1))))


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
        prev = polygon[-1]; dp = cross(edge0, edge1, prev)
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
    grid, pairs = {}, set()
    for i, tri in enumerate(triangles):
        assert abs(cross(*tri)) > 1e-13, 'Degenerate UV triangle'
        xs, ys = [p[0] for p in tri], [p[1] for p in tri]
        for x in range(int(min(xs)*48), int(max(xs)*48)+1):
            for y in range(int(min(ys)*48), int(max(ys)*48)+1):
                key = (x, y)
                pairs.update((other, i) for other in grid.get(key, []))
                grid.setdefault(key, []).append(i)
    overlaps = sum(overlap_area(triangles[a], triangles[b]) > 1e-10 for a, b in pairs)
    assert overlaps == 0, overlaps
    return dict(passed=True, in_0_1=True, layouts_per_mesh=1, overlapping_triangle_pairs=overlaps,
        overlap_area_tolerance=1e-10, method='Exported UV triangle pair clipping; shared atlas for all meshes.')


def validate(geometry, rig_report):
    doc, binary = read_glb(ROOT/'arms_firstperson.glb')
    assert len(doc['skins']) == 1 and len(doc['skins'][0]['joints']) == 8
    assert not any(doc.get(k) for k in ('animations', 'images', 'textures', 'cameras'))
    assert {m['name'] for m in doc['materials']} == set(PALETTE)
    parents = {child: i for i, n in enumerate(doc['nodes']) for child in n.get('children', [])}
    global_matrices = {}
    def world(i):
        if i not in global_matrices:
            global_matrices[i] = (world(parents[i]) if i in parents else Matrix.Identity(4)) @ node_matrix(doc['nodes'][i])
        return global_matrices[i]
    joints = doc['skins'][0]['joints']
    assert {doc['nodes'][i]['name'] for i in joints} == set(BONES)
    arms = next(i for i, n in enumerate(doc['nodes']) if n.get('name') == 'Arms')
    assert all(abs(world(arms)[i][j]-(1 if i == j else 0)) < 1e-6 for i in range(4) for j in range(4))
    matrices = [Matrix([row[i:i+4] for i in range(0, 16, 4)]).transposed()
        for row in accessor(doc, binary, doc['skins'][0]['inverseBindMatrices'])]
    bind = {doc['nodes'][index]['name']: list(matrix.inverted().translation) for index, matrix in zip(joints, matrices)}
    for side in ('R', 'L'):
        s, e, w = [Vector(bind[stem+'_'+side]) for stem in ('UpperArm', 'Forearm', 'Hand')]
        assert abs((e-s).length-.30) < 1e-5 and abs((w-e).length-.30) < 1e-5
        assert (e-s).normalized().dot((w-e).normalized()) > .99999
    total, blended, rigid, points = 0, 0, 0, []
    uv_triangles, densities = [], []
    palm_vertices, palm_faces = [], []
    mesh_names = []
    for index, node in enumerate(doc['nodes']):
        if 'mesh' not in node: continue
        mesh_names.append(node['name'])
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            a = primitive['attributes']
            assert {'POSITION', 'NORMAL', 'TANGENT', 'TEXCOORD_0'} <= set(a)
            vertices = accessor(doc, binary, a['POSITION'])
            uv = accessor(doc, binary, a['TEXCOORD_0'])
            assert all(-1e-6 <= v <= 1+1e-6 for p in uv for v in p)
            for normal, tangent in zip(accessor(doc, binary, a['NORMAL']), accessor(doc, binary, a['TANGENT'])):
                assert abs(Vector(normal).length-1) < 3e-4 and abs(Vector(tangent[:3]).length-1) < 3e-4
                assert abs(Vector(normal).dot(Vector(tangent[:3]))) < 3e-4 and abs(abs(tangent[3])-1) < 1e-6
            indices = [p[0] for p in accessor(doc, binary, primitive['indices'])]
            total += len(indices)//3
            posed = []
            if 'skin' in node:
                js, ws = accessor(doc, binary, a['JOINTS_0']), accessor(doc, binary, a['WEIGHTS_0'])
                for p, joint_ids, weights in zip(vertices, js, ws):
                    active = [(int(j), w) for j, w in zip(joint_ids, weights) if w > 1e-6]
                    assert len(active) in (1, 2) and abs(sum(w for _, w in active)-1) < 1e-5
                    if len(active) == 2:
                        assert all(abs(w-.5) < 1e-6 for _, w in active)
                        names = {doc['nodes'][joints[j]]['name'].split('_')[0] for j, _ in active}
                        assert names == {'Forearm', 'Hand'}
                        blended += 1
                    else: rigid += 1
                    point = sum(((world(joints[j]) @ matrices[j] @ Vector(p))*w for j, w in active), Vector((0, 0, 0)))
                    if len(active) == 2:
                        side = node['name'][-1]
                        assert {doc['nodes'][joints[j]]['name'] for j, _ in active} == {'Forearm_'+side, 'Hand_'+side}
                        assert (point-WRISTS[side]).length < .05501, 'Blend outside wrist'
                    posed.append(point)
            else:
                ancestor = parents.get(index)
                while ancestor is not None and ancestor not in joints: ancestor = parents.get(ancestor)
                assert ancestor is not None and doc['nodes'][ancestor]['name'] in ('Hand_R', 'Hand_L')
                posed = [world(index) @ Vector(p) for p in vertices]
                rigid += len(vertices)
            for i in range(0, len(indices), 3):
                ids = indices[i:i+3]
                tri = [uv[j] for j in ids]; uv_triangles.append(tri)
                pa, pb, pc = [posed[j] for j in ids]
                area = (pb-pa).cross(pc-pa).length*.5
                assert area > 1e-11
                densities.append(math.sqrt(abs(cross(*tri))*.5/area))
            points.extend(posed)
            if node['name'] == 'Arm_L':
                offset = len(palm_vertices); palm_vertices.extend(posed)
                palm_faces.extend(tuple(offset+v for v in indices[i:i+3]) for i in range(0, len(indices), 3))
    assert 2000 <= total <= 6000, total
    assert blended > 0
    assert max(densities)/min(densities) < 1.05, 'Uneven UV density'
    tree = BVHTree.FromPolygons(palm_vertices, palm_faces, all_triangles=True)
    hit = tree.find_nearest(PALM_L)
    assert hit is not None and hit[3] < 2e-5, hit
    report = dict(passed=True, file='arms_firstperson.glb', triangles=total,
        armature_name='Arms', bone_names=BONES, materials=list(PALETTE), mesh_names=mesh_names,
        material_values={m['name']: m['pbrMetallicRoughness'] for m in doc['materials']},
        axes=dict(up='+Y', forward='-Z'), origin_gun_m=[0, 0, 0],
        rest_positions_from_inverse_bind_matrices_gun_m=bind,
        default_joint_positions_gun_m={doc['nodes'][i]['name']: list(world(i).translation) for i in joints},
        left_palm_contact_gun_m=list(PALM_L), left_palm_contact_error_m=hit[3],
        right_wrist_gun_m=list(WRISTS['R']), rigid_exported_vertices=rigid, wrist_blended_exported_vertices=blended,
        weights_check='Rigid single influence; wrist only 50/50 Forearm+Hand. Fingers are rigid bone children.',
        uv_check=uv_audit(uv_triangles), texel_density_max_to_min_ratio=max(densities)/min(densities),
        normals_check=dict(passed=True, finite_unit_vectors=True),
        tangents_check=dict(passed=True, finite_unit_vectors=True, orthogonal_to_normal=True),
        geometry=geometry, source_rig=rig_report,
        bounds_min_gun_m=[min(p[i] for p in points) for i in range(3)],
        bounds_max_gun_m=[max(p[i] for p in points) for i in range(3)],
        no_rifle_cameras_lights_animations_textures=True,
        glb_sha256=hashlib.sha256((ROOT/'arms_firstperson.glb').read_bytes()).hexdigest())
    (ROOT/'validation.json').write_text(json.dumps(report, indent=2))
    print('ARMS VALIDATED '+json.dumps(dict(triangles=total, palm_error_m=hit[3], blended_vertices=blended)), flush=True)


def preview():
    scene = bpy.context.scene; scene.render.engine = 'CYCLES'; scene.cycles.samples = 40
    scene.cycles.use_denoising = True
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'OPTIX'; prefs.get_devices()
        devices = [d for d in prefs.devices if d.type == 'OPTIX']
        if devices:
            for device in prefs.devices: device.use = device in devices
            scene.cycles.device = 'GPU'
    except (KeyError, TypeError, RuntimeError): pass
    scene.render.resolution_x, scene.render.resolution_y = 1440, 1080
    scene.render.resolution_percentage = 100; scene.render.image_settings.file_format = 'PNG'
    scene.view_settings.view_transform = 'AgX'; scene.view_settings.look = 'AgX - Medium High Contrast'
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.20, .20, .20, 1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .7
    helpers = []
    for position, energy, size in [((-.8, 1.3, .7), 180, 1.5), ((1, .6, .2), 100, 1.2), ((0, .7, -1.5), 220, 1.3)]:
        data = bpy.data.lights.new('Preview light', 'AREA'); data.energy, data.size = energy, size
        obj = bpy.data.objects.new('Preview light', data); scene.collection.objects.link(obj); obj.location = B(position)
        obj.rotation_euler = (B((0, -.05, -.10))-obj.location).to_track_quat('-Z', 'Y').to_euler(); helpers.append(obj)
    data = bpy.data.cameras.new('Preview camera'); camera = bpy.data.objects.new('Preview camera', data)
    scene.collection.objects.link(camera); scene.camera = camera; helpers.append(camera)
    data.type = 'ORTHO'; data.ortho_scale = 1.0
    camera.location = B((.85, .65, .72)); target = B((0, -.08, -.08))
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(ROOT/'previews/arms_three_quarter.png'); bpy.ops.render.render(write_still=True)
    # The original rifle is an optional preview prop, never in the source/export.
    rifle = ROOT.parents[1]/'weapons/tactical_original/assault_rifle.glb'
    imported = []
    if rifle.exists():
        before = set(bpy.context.scene.objects)
        bpy.ops.import_scene.gltf(filepath=str(rifle))
        imported = [obj for obj in bpy.context.scene.objects if obj not in before]
    data.type = 'PERSP'; data.lens = 29
    camera.location = B((-.15, .16, .40)); target = B((-.03, .075, -.40))
    camera.rotation_euler = (target-camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.render.filepath = str(ROOT/'previews/first_person_rifle.png'); bpy.ops.render.render(write_still=True)
    for obj in imported: bpy.data.objects.remove(obj, do_unlink=True)
    scene.render.filepath = str(ROOT/'previews/first_person_arms.png'); bpy.ops.render.render(write_still=True)
    for obj in helpers: bpy.data.objects.remove(obj, do_unlink=True)
    scene.camera = None


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--no-render', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    (ROOT/'previews').mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for item in list(collection):
            if item.users == 0: collection.remove(item)
    bpy.context.scene.unit_settings.system = 'METRIC'; bpy.context.scene.unit_settings.scale_length = 1
    bpy.context.preferences.filepaths.save_version = 0; bpy.context.preferences.filepaths.file_preview_type = 'NONE'
    materials(); forearms_and_palms(); fingers()
    geometry = finalize(); rig_report = rig_and_bind()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'arms_firstperson.glb'), export_format='GLB', use_selection=True,
        export_yup=True, export_apply=True, export_texcoords=True, export_normals=True, export_tangents=True,
        export_skins=True, export_def_bones=False, export_leaf_bone=False, export_armature_object_remove=False,
        export_rest_position_armature=False, export_current_frame=True, export_animations=False,
        export_cameras=False, export_lights=False, export_materials='EXPORT', export_extras=False)
    validate(geometry, rig_report)
    activate(RIG); bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'arms_firstperson.blend'))
    if not args.no_render: preview()
    print('ARMS BUILD COMPLETE', flush=True)


if __name__ == '__main__': main()
