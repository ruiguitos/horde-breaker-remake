"""Audit actual glTF reload channels, deformed meshes and reopened Blender sources.
SPDX-License-Identifier: CC0-1.0
blender --background --python validate_reload_clips.py [-- --baseline-dir PATH]
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location('reload_author', ROOT/'reload_clips.py')
author = importlib.util.module_from_spec(spec)
spec.loader.exec_module(author)
codec = author.helpers()


def animated_worlds(doc, binary, p):
    local = [codec.node_matrix(n) for n in doc['nodes']]
    animation = doc['animations'][0]
    for channel in animation['channels']:
        if channel['target']['path'] != 'rotation':
            continue
        sampler = animation['samplers'][channel['sampler']]
        times = [v[0] for v in codec.accessor(doc, binary, sampler['input'])]
        values = codec.accessor(doc, binary, sampler['output'])
        end = next((i for i, t in enumerate(times) if t >= p), len(times)-1)
        start = max(0, end-1)
        f = 0 if end == start else (p-times[start])/(times[end]-times[start])
        a, b = values[start], values[end]
        q = Quaternion((a[3], *a[:3])).slerp(Quaternion((b[3], *b[:3])), f)
        i = channel['target']['node']
        local[i] = Matrix.LocRotScale(local[i].translation, q, local[i].to_scale())
    parents = {child: i for i, n in enumerate(doc['nodes']) for child in n.get('children', [])}
    cache = {}
    def world(i):
        if i not in cache:
            cache[i] = (world(parents[i]) if i in parents else Matrix.Identity(4)) @ local[i]
        return cache[i]
    return [world(i) for i in range(len(local))]


def groups(doc, binary):
    result = []
    for i, node in enumerate(doc['nodes']):
        if 'mesh' not in node:
            continue
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            attr = primitive['attributes']
            points = np.asarray(codec.accessor(doc, binary, attr['POSITION']), dtype=float)
            points = np.column_stack((points, np.ones(len(points))))
            indices = np.asarray(codec.accessor(doc, binary, primitive['indices']), dtype=int).reshape(-1, 3)
            weights = joints = binds = None
            if 'skin' in node:
                skin = doc['skins'][node['skin']]
                weights = np.asarray(codec.accessor(doc, binary, attr['WEIGHTS_0']))
                joints = np.asarray(codec.accessor(doc, binary, attr['JOINTS_0']), dtype=int)
                binds = np.asarray(codec.accessor(doc, binary, skin['inverseBindMatrices'])).reshape(-1, 4, 4).transpose(0, 2, 1)
            morphs = np.asarray([codec.accessor(doc, binary, target['POSITION']) for target in primitive.get('targets', [])])
            weight_samples = None
            for animation in doc.get('animations', []):
                for channel in animation['channels']:
                    if channel['target'] == dict(node=i, path='weights'):
                        sampler = animation['samplers'][channel['sampler']]
                        time = np.asarray(codec.accessor(doc, binary, sampler['input']))[:, 0]
                        values = np.asarray(codec.accessor(doc, binary, sampler['output'])).reshape(len(time), len(morphs))
                        weight_samples = (time, values)
            result.append(dict(node=i, name=node['name'], material=doc['materials'][primitive['material']]['name'],
                               points=points, indices=indices, weights=weights, joints=joints, binds=binds,
                               morphs=morphs, weight_samples=weight_samples))
    return result


def posed(group, matrices, doc, p=0.):
    points = group['points']
    if group['weight_samples'] is not None:
        time, values = group['weight_samples']
        i = min(len(time)-1, int(np.searchsorted(time, p)))
        previous = max(0, i-1)
        f = 0 if i == previous else (p-time[previous])/(time[i]-time[previous])
        weight = values[previous]*(1-f)+values[i]*f
        points = points.copy()
        points[:, :3] += np.einsum('m,mnj->nj', weight, group['morphs'])
    if group['weights'] is None:
        return (points @ np.asarray(matrices[group['node']]).T)[:, :3]
    skin = doc['skins'][doc['nodes'][group['node']]['skin']]
    transforms = np.asarray([matrices[i] for i in skin['joints']]) @ group['binds']
    out = np.zeros_like(group['points'])
    for slot in range(group['weights'].shape[1]):
        out += np.einsum('nij,nj->ni', transforms[group['joints'][:, slot]], points) * group['weights'][:, slot, None]
    return out[:, :3]


def collision_gauge(weapon):
    doc, binary = codec.read_glb(ROOT.parents[1]/'weapons/tactical_original'/(weapon+'.glb'))
    matrices = author.worlds(doc, codec)
    result = []
    for group in groups(doc, binary):
        points = posed(group, matrices, doc)
        result.append(dict(name=group['name'], tree=BVHTree.FromPolygons(points.tolist(), group['indices'].tolist(), all_triangles=True),
                           lo=points.min(axis=0), hi=points.max(axis=0)))
    return result


def static_signature(doc, binary):
    static = doc['animations'][0]['extras']['static_asset'] if doc.get('animations') else dict(buffer_bytes=len(binary))
    metadata = {k: doc.get(k) for k in ['nodes', 'meshes', 'materials', 'skins', 'scenes', 'scene']}
    metadata = json.loads(json.dumps(metadata))
    for mesh in metadata['meshes']:
        mesh.pop('weights', None)
        mesh.pop('extras', None)
        for primitive in mesh['primitives']:
            primitive.pop('targets', None)
    return dict(binary_sha256=hashlib.sha256(binary[:static['buffer_bytes']]).hexdigest(),
                scene_sha256=hashlib.sha256(json.dumps(metadata, sort_keys=True).encode()).hexdigest())


def audit(weapon, baseline_dir=None):
    file = ROOT/weapon/'arms_firstperson.glb'
    doc, binary = codec.read_glb(file)
    assert [a['name'] for a in doc.get('animations', [])] == [author.CLIPS[weapon]]
    assert not any(doc.get(k) for k in ['cameras', 'images', 'textures'])
    assert len(doc['materials']) == 3 and len(doc['skins'][0]['joints']) == 8
    assert len(doc['meshes']) == 12
    signature = static_signature(doc, binary)
    if baseline_dir:
        old_doc, old_binary = codec.read_glb(baseline_dir/(weapon+'.glb'))
        assert signature == static_signature(old_doc, old_binary), 'Static binary or rest scene changed'
    mesh_groups = groups(doc, binary)
    triangles = sum(len(g['indices']) for g in mesh_groups)
    assert triangles == (2568 if weapon == 'smg' else 2658)
    node_ids = {node['name']: i for i, node in enumerate(doc['nodes'])}
    rest = author.worlds(doc, codec)
    right, left = node_ids['Hand_R'], node_ids['Hand_L']
    fit = json.loads((ROOT/weapon/'grip_validation.json').read_text())
    info = fit['reload_clip']
    palm = rest[right].inverted() @ Vector(info['right_palm_landmark_rest_gun_m'])
    contact = rest[right].inverted() @ Vector(info['contact_landmark_rest_gun_m'])
    left_offset = rest[left].inverted() @ Vector(fit['support_gun_m'])
    target = author.reference(weapon, codec)
    gauge = collision_gauge(weapon)
    max_left = max_rest = max_contact = 0.
    collision_records = []
    baseline_depth = {}
    max_new_penetration = 0.
    max_unallowed_penetration = 0.
    # Include all keys and the midpoint between each pair of keys.
    keys = info['keyframe_times_s']
    sample_times = sorted(set(keys+[(a+b)/2 for a, b in zip(keys, keys[1:])]))
    sample_count = len(sample_times)
    for step, p in enumerate(sample_times):
        matrices = animated_worlds(doc, binary, p)
        max_left = max(max_left, (matrices[left] @ left_offset-Vector(fit['support_gun_m'])).length)
        if step in [0, sample_count-1]:
            max_rest = max(max_rest, max((matrices[i].translation-rest[i].translation).length for i in doc['skins'][0]['joints']))
            assert max(abs(matrices[i][r][c]-rest[i][r][c]) for i in doc['skins'][0]['joints'] for r in range(4) for c in range(4)) < 1e-5
        if (weapon == 'smg' and .3 <= p <= .95) or (weapon == 'machine_gun' and .89 <= p <= .95):
            expected = target+(author.magazine_offset(p) if weapon == 'smg' else author.charge_offset(p))
            max_contact = max(max_contact, (matrices[right] @ contact-expected).length)
        if weapon == 'machine_gun' and p <= .8:
            assert (matrices[right].translation-rest[right].translation).length < .0001
        for group in mesh_groups:
            if not group['name'].endswith('_R'):
                continue
            pts = posed(group, matrices, doc, p)
            # Audit vertices, edge midpoints and triangle centroids, including
            # wrist skin blends. Sleeves alone may intersect the magazine.
            tri = pts[group['indices']]
            pts = np.unique(np.round(np.concatenate((pts, tri.mean(axis=1), (tri[:, 0]+tri[:, 1])/2,
                                                     (tri[:, 1]+tri[:, 2])/2, (tri[:, 2]+tri[:, 0])/2)), 8), axis=0)
            for part in gauge:
                magazine = part['name'].startswith(('Curved 9mm magazine', 'Magazine floor plate', 'Magazine pressed stiffener'))
                if magazine and group['material'] == 'sleeve_cloth':
                    continue
                offset = author.magazine_offset(p) if magazine else (author.charge_offset(p) if part['name'].startswith('Charging slide') else Vector())
                q = pts-np.asarray(offset)
                inside = q[np.all((q >= part['lo']-1e-7) & (q <= part['hi']+1e-7), axis=1)]
                depth = 0.
                for point in inside:
                    hit = part['tree'].find_nearest(Vector(point))
                    if hit[0] is not None:
                        depth = max(depth, -(Vector(point)-hit[0]).dot(hit[1]))
                key = (group['name'], group['material'], part['name'])
                if step == 0:
                    baseline_depth[key] = depth
                extra = max(0., depth-baseline_depth.get(key, 0.))
                max_new_penetration = max(max_new_penetration, extra)
                allowed = baseline_depth.get(key, 0.)+.0001
                # The original grip audit allows 1.5 mm local glove-pad
                # contact. Retain that existing convention only for finger
                # meshes already touching the same piece of grip furniture;
                # never extend it to the receiver, arm or a new contact pair.
                furniture = part['name'].startswith(('Pistol grip', 'Grip moulded insert', 'Grip traction rib'))
                if furniture and group['name'] != 'Arm_R' and baseline_depth.get(key, 0.) > 0:
                    allowed = max(allowed, .0015)
                excess = max(0., depth-allowed)
                max_unallowed_penetration = max(max_unallowed_penetration, excess)
                if excess > 1e-8:
                    collision_records.append(dict(p=p, mesh=group['name'], material=group['material'], part=part['name'], depth_m=depth, extra_depth_m=extra))
        if step % author.FPS == 0:
            print('RELOAD AUDIT', weapon, p, 'new penetration', max_new_penetration, flush=True)
    assert max_left < .0001 and max_rest < .0001 and max_contact < .001
    source = ROOT/'source'/('arms_'+weapon+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    rig = bpy.data.objects['Arms']
    assert len(bpy.data.actions) == 1 and rig.animation_data.action.name == author.CLIPS[weapon]
    assert len(rig.data.bones) == 8 and {m.name for m in bpy.data.materials} == {'sleeve_cloth', 'glove', 'skin'}
    assert len([o for o in bpy.data.objects if o.type == 'MESH']) == 12
    assert not any(o.type in ['CAMERA', 'LIGHT'] for o in bpy.data.objects)
    max_source = max_source_mesh = 0.
    for p in [0., .1, .10125, .1125, .12, .25, .3, .5, .7, .75, .8, .803, .81, .815, .85, .875, .9, .95, .975, .995, .9975, .999, 1.]:
        frame = p*author.FPS
        bpy.context.scene.frame_set(int(frame), subframe=frame-int(frame))
        matrices = animated_worlds(doc, binary, p)
        for name in ['Hand_R', 'Hand_L', 'Forearm_R', 'UpperArm_R']:
            value = author.C @ rig.pose.bones[name].matrix
            max_source = max(max_source, (value.translation-matrices[node_ids[name]].translation).length)
        for obj in bpy.context.scene.objects:
            if obj.type != 'MESH':
                continue
            exported = np.concatenate([posed(g, matrices, doc, p) for g in mesh_groups if g['name'] == obj.name])
            tree = KDTree(len(exported))
            for i, point in enumerate(exported):
                tree.insert(Vector(point), i)
            tree.balance()
            evaluated = obj.evaluated_get(bpy.context.evaluated_depsgraph_get())
            for vertex in evaluated.data.vertices:
                point = author.C @ evaluated.matrix_world @ vertex.co
                max_source_mesh = max(max_source_mesh, tree.find(point)[2])
    assert max_source < .0001, ('Source differs from GLB', max_source)
    assert max_source_mesh < .0001, ('Source mesh differs from GLB', max_source_mesh)
    report = dict(passed=not collision_records, clip=author.CLIPS[weapon], triangles=triangles,
                  static_asset_signature=signature, progress_samples=sample_count, max_left_contact_error_m=max_left,
                  max_endpoint_joint_error_m=max_rest, max_moving_contact_error_m=max_contact,
                  max_source_glb_joint_error_m=max_source, max_source_glb_vertex_error_m=max_source_mesh,
                  max_new_penetration_m=max_new_penetration, max_existing_rest_penetration_m=max(baseline_depth.values()),
                  max_unallowed_penetration_m=max_unallowed_penetration,
                  collision_sample_method='Vertices, edge midpoints and triangle centroids against each weapon part; 0.1 mm new-penetration tolerance. Existing finger/grip-furniture contact pairs retain the original grip audit limit of 1.5 mm absolute (or their unchanged deeper rest contact). No such allowance for receivers, forearms or new contact pairs. Not a continuous swept-volume proof.',
                  collision_records=sorted(collision_records, key=lambda x: -x['extra_depth_m'])[:40])
    (ROOT/weapon/'reload_validation.json').write_text(json.dumps(report, indent=2)+'\n')
    for filename in ['validation.json', 'grip_validation.json']:
        path = ROOT/weapon/filename
        data = json.loads(path.read_text())
        if filename == 'validation.json':
            data['passed'] = report['passed']
        data['reload_clip']['validation'] = {k: v for k, v in report.items() if k != 'collision_records'}
        path.write_text(json.dumps(data, indent=2)+'\n')
    source_report = ROOT/'source_validation.json'
    if source_report.exists():
        data = json.loads(source_report.read_text())
        entry = data['weapons'][weapon]
        entry.pop('no_weapons_cameras_lights_actions_textures', None)
        entry.update(no_weapons_cameras_lights_textures=True, actions=[author.CLIPS[weapon]],
                     blend_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                     max_reload_source_glb_joint_error_m=max_source,
                     max_reload_source_glb_vertex_error_m=max_source_mesh)
        source_report.write_text(json.dumps(data, indent=2)+'\n')
    print('RELOAD RESULT', weapon, json.dumps({k: v for k, v in report.items() if k != 'collision_records'}), flush=True)
    for item in report['collision_records'][:8]:
        print('COLLISION', item, flush=True)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--baseline-dir', type=Path)
    parser.add_argument('--weapon', choices=list(author.CLIPS))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    reports = [audit(w, args.baseline_dir) for w in ([args.weapon] if args.weapon else author.CLIPS)]
    assert all(r['passed'] for r in reports), 'Reload geometry collision audit failed'
