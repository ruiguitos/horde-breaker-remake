"""Original progress-sampled reload clips. SPDX-License-Identifier: CC0-1.0

Run with Blender 5.x --background --python reload_clips.py.
Append animation and morph data; never re-export the original base geometry.
The static builder calls add_reload() after creating its unchanged grip asset.
"""
import argparse
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent
C = Matrix(((1, 0, 0, 0), (0, 0, 1, 0), (0, -1, 0, 0), (0, 0, 0, 1)))
CI = C.inverted()
FPS = 400
OPEN_STEPS = 24
CLIPS = {'smg': 'reload_mag_smg', 'machine_gun': 'reload_mag_mg'}
PALM = Vector((.0185, -.025, .016))  # Flat inner glove face, not the wrist.
BONES = ('UpperArm_R', 'Forearm_R', 'Hand_R')
GRIP_SURFACE = None
ACTIVE_WEAPON = None


def helpers():
    spec = importlib.util.spec_from_file_location('arm_codec', ROOT.parent/'arms_firstperson_original/build_arms.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def smooth(a, b, p):
    x = min(1., max(0., (p-a)/(b-a)))
    return x*x*(3-2*x)


def magazine_offset(p):
    return Vector((0, -.12*(smooth(0, .3, p)-smooth(.7, 1, p)), 0))


def charge_offset(p):
    return Vector((0, 0, .03*math.sin(math.pi*min(1, max(0, (p-.8)/.2)))))


def finger_open(weapon, p):
    start, end = ((.10, .125) if weapon == 'smg' else (.80, .82))
    return smooth(start, end, p)*(1-smooth(.99, 1., p))


def open_weights(u):
    return [max(0., 1-abs(u*OPEN_STEPS-i)) for i in range(1, OPEN_STEPS+1)]


def key_times(weapon):
    # The 10 ms return needs denser morph samples to avoid interpolating a
    # chord through the grip between distant finger-release shapes.
    start, end = ((.10, .125) if weapon == 'smg' else (.80, .82))
    values = [i/FPS for i in range(FPS+1)]
    values += [start+i*.00025 for i in range(round((end-start)/.00025)+1)]
    values += [.99+i*.000125 for i in range(81)]
    return sorted({round(p, 9) for p in values})


def relaxed(point, u, name):
    """Uncurl around the grip surface before withdrawing, using morph targets.

    Radial arcs avoid the chord through the grip that a single open morph
    would create. Only the three curled fingers and thumb are affected.
    """
    front = GRIP_SURFACE.ray_cast(Vector((0, point.y, -.4)), Vector((0, 0, 1)), .8)[0]
    back = GRIP_SURFACE.ray_cast(Vector((0, point.y, .4)), Vector((0, 0, -1)), .8)[0]
    center_z = (front.z+back.z)*.5 if front is not None and back is not None else .006-point.y*.35
    x, z = point.x, point.z-center_z
    angle = math.atan2(-z, x)
    if name == 'Thumb_R' and angle > math.pi/2:
        angle -= 2*math.pi
    elif name != 'Thumb_R' and angle < -math.pi/2:
        angle += 2*math.pi
    radius = math.hypot(x, z)
    center = Vector((0, point.y, center_z))
    def surface(a, origin=center):
        direction = Vector((math.cos(a), 0, -math.sin(a)))
        hit = GRIP_SURFACE.ray_cast(origin+direction*.4, -direction, .8)[0]
        return (hit-origin).length if hit is not None else radius
    old_angle = angle
    angle *= 1-smooth(.35 if name == 'Ring_R' else .15, 1., u)*.88
    # Follow the real non-circular grip section while uncurling. Extend only
    # after crossing to the outer side, away from the trigger and guard.
    original_clearance = radius-surface(old_angle)
    clear = smooth(0, .04, u)
    clearance = original_clearance*(1-clear)+max(.006, original_clearance)*clear
    if name == 'Ring_R':
        # The MG guard sits 9 mm higher; lower the ring finger before the
        # first outward release, rather than grazing its bottom edge.
        fan = smooth(0, .15, u) if ACTIVE_WEAPON == 'machine_gun' else smooth(.10, .35, u)
        y = point.y-.032*abs(old_angle)/math.pi*fan
        front = GRIP_SURFACE.ray_cast(Vector((0, y, -.4)), Vector((0, 0, 1)), .8)[0]
        back = GRIP_SURFACE.ray_cast(Vector((0, y, .4)), Vector((0, 0, -1)), .8)[0]
        center.y = y
        if front is not None and back is not None:
            center.z = (front.z+back.z)*.5
    radius = surface(angle, center)+clearance
    radius += .040*abs(old_angle)/math.pi*smooth(.65, 1., u)
    target = Vector((radius*math.cos(angle), center.y, center.z-radius*math.sin(angle)))
    if ACTIVE_WEAPON == 'machine_gun' and name == 'Middle_R':
        clear = smooth(0, .20, u)
        target.y += .0005*clear
        target.z += .003*clear  # Clear the guard's sloping rear strut.
        target.x += .0045*smooth(0, .04, u)  # Release sideways before uncurling.
    if ACTIVE_WEAPON == 'machine_gun' and name == 'Ring_R':
        target.x -= .0005*smooth(0, .04, u)  # Clear the outer traction rib.
    return target


def source_fingers(rig):
    for obj in bpy.context.scene.objects:
        if obj.name not in ['Middle_R', 'Ring_R', 'Little_R', 'Thumb_R']:
            continue
        if obj.data.shape_keys:
            obj.shape_key_clear()
        obj.shape_key_add(name='Basis')
        matrix = C @ obj.matrix_world
        for i in range(1, OPEN_STEPS+1):
            key = obj.shape_key_add(name='ReloadOpen%02d' % i)
            for vertex, original in zip(key.data, obj.data.vertices):
                vertex.co = matrix.inverted() @ relaxed(matrix @ original.co, i/OPEN_STEPS, obj.name)
            driver = key.driver_add('value').driver
            variable = driver.variables.new()
            variable.name = 'u'
            variable.targets[0].id = rig
            variable.targets[0].data_path = '["reload_open"]'
            driver.expression = 'max(0,1-abs(u*%d-%d))' % (OPEN_STEPS, i)


def worlds(doc, codec):
    parents = {child: i for i, node in enumerate(doc['nodes']) for child in node.get('children', [])}
    cache = {}
    def world(i):
        if i not in cache:
            cache[i] = (world(parents[i]) if i in parents else Matrix.Identity(4)) @ codec.node_matrix(doc['nodes'][i])
        return cache[i]
    return [world(i) for i in range(len(doc['nodes']))]


def reference(weapon, codec):
    doc, binary = codec.read_glb(ROOT.parents[1]/'weapons/tactical_original'/(weapon+'.glb'))
    matrices = worlds(doc, codec)
    part = 'Magazine floor plate' if weapon == 'smg' else 'Charging slide'
    i = next(i for i, node in enumerate(doc['nodes']) if node.get('name') == part)
    vertices = [matrices[i] @ Vector(p) for primitive in doc['meshes'][doc['nodes'][i]['mesh']]['primitives']
                for p in codec.accessor(doc, binary, primitive['attributes']['POSITION'])]
    lo = Vector([min(p[i] for p in vertices) for i in range(3)])
    hi = Vector([max(p[i] for p in vertices) for i in range(3)])
    target = (lo+hi)*.5
    if weapon == 'smg':
        target.y = lo.y
    else:
        target.x = hi.x
        target.z = hi.z  # Rear end stays clear of the separate, fixed knob.
    return target


def path(weapon, p, anchor, target):
    """A clearance route outside the receiver; the contact section follows code."""
    identity = Quaternion()
    if weapon == 'smg':
        turn = (Matrix.Rotation(math.radians(-60), 4, 'Y') @ Matrix.Rotation(math.radians(-90), 4, 'Z')).to_quaternion()
        contact = lambda t: target+magazine_offset(t)
        keys = [(0., anchor, identity), (.125, anchor, identity),
                (.17, anchor+Vector((.12, -.04, 0)), identity),
                (.22, Vector((.14, -.33, target.z)), turn), (.30, contact(.30), turn),
                (.95, contact(.95), turn), (.9675, contact(.95)+Vector((.14, -.04, 0)), turn),
                (.98, anchor+Vector((.14, -.07, 0)), identity),
                (.99, anchor, identity), (1., anchor, identity)]
        if .30 <= p <= .95:
            return contact(p), turn
    else:
        turn = Matrix.Rotation(math.pi/2, 4, 'Y').to_quaternion()
        contact = lambda t: target+charge_offset(t)
        keys = [(0., anchor, identity), (.82, anchor, identity),
                (.84, anchor+Vector((.12, -.01, 0)), identity),
                (.86, contact(.86)+Vector((.12, 0, .06)), turn),
                (.89, contact(.89), turn), (.95, contact(.95), turn),
                (.9675, contact(.95)+Vector((.12, 0, .06)), turn),
                (.98, anchor+Vector((.12, -.01, 0)), identity),
                (.99, anchor, identity), (1., anchor, identity)]
        if .89 <= p <= .95:
            return contact(p), turn
    for (a, start, qa), (b, end, qb) in zip(keys, keys[1:]):
        if a <= p <= b:
            f = smooth(a, b, p)
            return start.lerp(end, f), qa.slerp(qb, f)
    raise ValueError(p)


def pose(rig, base, delta):
    """Two 0.30 m bones, same elbow plane as the original grip, no stretching."""
    shoulder = base['UpperArm_R'].translation
    elbow = base['Forearm_R'].translation
    wrist = (delta @ base['Hand_R']).translation
    axis = (wrist-shoulder).normalized()
    distance = (wrist-shoulder).length
    a = (elbow-shoulder).length
    b = (base['Hand_R'].translation-elbow).length
    assert abs(a-b)+1e-5 < distance < a+b-1e-5, 'Reload exceeds arm reach'
    along = (a*a-b*b+distance*distance)/(2*distance)
    pole = elbow-shoulder
    pole = (pole-axis*pole.dot(axis)).normalized()
    bend = shoulder+axis*along+pole*math.sqrt(max(0., a*a-along*along))
    for name, head, before, after in [
            ('UpperArm_R', shoulder, elbow-shoulder, bend-shoulder),
            ('Forearm_R', bend, base['Hand_R'].translation-elbow, wrist-bend)]:
        rotation = before.normalized().rotation_difference(after.normalized()).to_matrix().to_4x4()
        value = rotation @ base[name]
        value.translation = head
        rig.pose.bones[name].matrix = CI @ value
        bpy.context.view_layer.update()
    rig.pose.bones['Hand_R'].matrix = CI @ delta @ base['Hand_R']
    bpy.context.view_layer.update()


def write_clip(file, samples, clip, codec, weapon, sample_times):
    doc, binary = codec.read_glb(file)
    if doc.get('animations'):
        previous = doc['animations']
        assert len(previous) == 1 and previous[0]['name'] == clip, 'Unexpected existing animation'
        original = previous[0]['extras']['static_asset']
        binary = binary[:original['buffer_bytes']]
        doc['accessors'] = doc['accessors'][:original['accessors']]
        doc['bufferViews'] = doc['bufferViews'][:original['views']]
        for mesh in doc['meshes']:
            mesh.pop('weights', None)
            mesh.pop('extras', None)
            for primitive in mesh['primitives']:
                primitive.pop('targets', None)
    static = dict(buffer_bytes=len(binary), accessors=len(doc['accessors']), views=len(doc['bufferViews']))
    output = bytearray(binary)
    def append(values, kind):
        output.extend(b'\x00'*((-len(output)) % 4))
        offset = len(output)
        for value in values:
            output.extend(struct.pack('<'+'f'*len(value), *value))
        view = len(doc['bufferViews'])
        doc['bufferViews'].append(dict(buffer=0, byteOffset=offset, byteLength=len(output)-offset))
        index = len(doc['accessors'])
        accessor = dict(bufferView=view, componentType=5126, count=len(values), type=kind)
        if kind in ['SCALAR', 'VEC3']:
            accessor.update(min=[min(v[i] for v in values) for i in range(len(values[0]))],
                            max=[max(v[i] for v in values) for i in range(len(values[0]))])
        doc['accessors'].append(accessor)
        return index
    times = append([(p,) for p in sample_times], 'SCALAR')
    animation = dict(name=clip, samplers=[], channels=[], extras=dict(static_asset=static, sampled_by='p * duration', license='CC0-1.0'))
    for name in BONES:
        node = next(i for i, node in enumerate(doc['nodes']) if node.get('name') == name)
        values = [row[name] for row in samples]
        values[0] = values[-1] = doc['nodes'][node]['rotation'][:]
        data = append(values, 'VEC4')
        animation['samplers'].append(dict(input=times, output=data, interpolation='LINEAR'))
        animation['channels'].append(dict(sampler=len(animation['samplers'])-1, target=dict(node=node, path='rotation')))
    default = worlds(doc, codec)
    for node, definition in enumerate(doc['nodes']):
        if definition.get('name') not in ['Middle_R', 'Ring_R', 'Little_R', 'Thumb_R']:
            continue
        mesh = doc['meshes'][definition['mesh']]
        mesh['weights'] = [0.]*OPEN_STEPS
        mesh['extras'] = dict(targetNames=['ReloadOpen%02d' % i for i in range(1, OPEN_STEPS+1)])
        for primitive in mesh['primitives']:
            vertices = codec.accessor(doc, binary, primitive['attributes']['POSITION'])
            primitive['targets'] = []
            inverse = default[node].inverted()
            for i in range(1, OPEN_STEPS+1):
                values = [tuple(inverse @ relaxed(default[node] @ Vector(v), i/OPEN_STEPS, definition['name'])-Vector(v)) for v in vertices]
                primitive['targets'].append(dict(POSITION=append(values, 'VEC3')))
        weights = [(weight,) for p in sample_times for weight in open_weights(finger_open(weapon, p))]
        data = append(weights, 'SCALAR')
        animation['samplers'].append(dict(input=times, output=data, interpolation='LINEAR'))
        animation['channels'].append(dict(sampler=len(animation['samplers'])-1, target=dict(node=node, path='weights')))
    doc['animations'] = [animation]
    doc['buffers'][0]['byteLength'] = len(output)
    encoded = json.dumps(doc, separators=(',', ':')).encode('utf-8')
    encoded += b' '*((-len(encoded)) % 4)
    output.extend(b'\x00'*((-len(output)) % 4))
    file.write_bytes(struct.pack('<III', 0x46546C67, 2, 28+len(encoded)+len(output))+
                     struct.pack('<II', len(encoded), 0x4E4F534A)+encoded+
                     struct.pack('<II', len(output), 0x004E4942)+output)


def add_reload(weapon):
    global GRIP_SURFACE, ACTIVE_WEAPON
    ACTIVE_WEAPON = weapon
    codec = helpers()
    gun_doc, gun_binary = codec.read_glb(ROOT.parents[1]/'weapons/tactical_original'/(weapon+'.glb'))
    gun_worlds = worlds(gun_doc, codec)
    grip_points, grip_faces = [], []
    for i, node in enumerate(gun_doc['nodes']):
        if not node.get('name', '').startswith(('Pistol grip', 'Grip moulded insert', 'Grip traction rib')):
            continue
        for primitive in gun_doc['meshes'][node['mesh']]['primitives']:
            offset = len(grip_points)
            grip_points += [gun_worlds[i] @ Vector(v) for v in codec.accessor(gun_doc, gun_binary, primitive['attributes']['POSITION'])]
            indices = [v[0] for v in codec.accessor(gun_doc, gun_binary, primitive['indices'])]
            grip_faces += [tuple(offset+j for j in indices[k:k+3]) for k in range(0, len(indices), 3)]
    GRIP_SURFACE = BVHTree.FromPolygons(grip_points, grip_faces, all_triangles=True)
    source = ROOT/'source'/('arms_'+weapon+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = bpy.data.objects['Arms']
    if rig.animation_data:
        rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    # Saving at frame 0 always retains the original authored bent grip pose.
    base = {bone.name: C @ bone.matrix for bone in rig.pose.bones}
    basis = {bone.name: bone.matrix_basis.copy() for bone in rig.pose.bones}
    anchor = PALM.copy()
    if weapon == 'machine_gun':
        # Touch the narrow slide with the extended index; the palm remains
        # outside the receiver. The separate, stationary cocking knob is avoided.
        points = []
        for obj in bpy.context.scene.objects:
            if obj.type == 'MESH' and obj.name == 'Index_R':
                ev = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
                points += [C @ ev.matrix_world @ v.co for v in ev.data.vertices]
        anchor = min(points, key=lambda p: p.z).copy()
    target = reference(weapon, codec)
    rig['reload_open'] = 0.
    source_fingers(rig)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.render.fps_base = 1
    scene.frame_start, scene.frame_end = 0, FPS
    rig.animation_data_create().action = bpy.data.actions.new(CLIPS[weapon])
    samples, measured = [], []
    sample_times = key_times(weapon)
    for p in sample_times:
        frame = p*FPS
        scene.frame_set(int(frame), subframe=frame-int(frame))
        rig['reload_open'] = finger_open(weapon, p)
        rig.keyframe_insert(data_path='["reload_open"]', frame=frame, group='Finger release')
        for name in BONES:
            rig.pose.bones[name].matrix_basis = basis[name]
            rig.pose.bones[name].rotation_mode = 'QUATERNION'
        bpy.context.view_layer.update()
        point, rotation = path(weapon, p, anchor, target)
        delta = Matrix.Translation(point) @ rotation.to_matrix().to_4x4() @ Matrix.Translation(-anchor)
        if p != 0 and p != 1 and not (weapon == 'machine_gun' and p <= .82) and not (weapon == 'smg' and p <= .125):
            pose(rig, base, delta)
        for name in BONES:
            bone = rig.pose.bones[name]
            bone.keyframe_insert(data_path='rotation_quaternion', frame=frame, group=name)
        bpy.context.view_layer.update()
        row = {}
        for name in BONES:
            bone = rig.pose.bones[name]
            local = bone.parent.matrix.inverted() @ bone.matrix
            q = local.to_quaternion()
            row[name] = [q.x, q.y, q.z, q.w]
        samples.append(row)
        hand = C @ rig.pose.bones['Hand_R'].matrix
        moved = hand @ base['Hand_R'].inverted()
        if p in [0., .25, .5, .75, 1.]:
            measured.append(dict(p=p, wrist_gun_m=list(hand.translation), palm_gun_m=list(moved @ PALM), contact_gun_m=list(moved @ anchor)))
    for layer in rig.animation_data.action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for curve in bag.fcurves:
                    for key in curve.keyframe_points:
                        key.interpolation = 'LINEAR'
    scene.frame_set(0)
    bpy.context.view_layer.update()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    file = ROOT/weapon/'arms_firstperson.glb'
    write_clip(file, samples, CLIPS[weapon], codec, weapon, sample_times)
    report = dict(name=CLIPS[weapon], duration_s=1., keyframe_times_s=sample_times,
                  interpolation='LINEAR (quaternion slerp)', sample_by='p * duration_s',
                  right_palm_landmark_rest_gun_m=list(PALM), contact_landmark_rest_gun_m=list(anchor),
                  reference_contact_rest_gun_m=list(target), sampled_right_hand=measured,
                  finger_release='%d additive morph targets per curled finger; zero at p=0/1. Original grip vertices and eight bones preserved.' % OPEN_STEPS,
                  magazine_base_at_p_050_gun_m=list(target+magazine_offset(.5)) if weapon == 'smg' else None,
                  source_blend_sha256=hashlib.sha256(source.read_bytes()).hexdigest(), license='CC0-1.0')
    for name in ['validation.json', 'grip_validation.json']:
        path_report = ROOT/weapon/name
        data = json.loads(path_report.read_text())
        data['reload_clip'] = report
        data['glb_sha256'] = hashlib.sha256(file.read_bytes()).hexdigest()
        if name == 'validation.json':
            data.pop('no_rifle_cameras_lights_animations_textures', None)
            data['no_weapons_cameras_lights_textures'] = True
        path_report.write_text(json.dumps(data, indent=2)+'\n')
    print('RELOAD BUILT '+weapon+' '+json.dumps(measured), flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--weapon', choices=list(CLIPS))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for weapon in ([args.weapon] if args.weapon else CLIPS):
        add_reload(weapon)
