"""Independent GLB/source audit; Blender only, never starts Godot.
SPDX-License-Identifier: CC0-1.0
Run: blender --background --python-exit-code 1 --python validate_target.py -- --only recruit
"""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
TYPES = {5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}
COUNTS = {'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}


def read(path):
    raw = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', raw)
    assert magic == 0x46546C67 and version == 2 and length == len(raw)
    count = struct.unpack_from('<I', raw, 12)[0]
    doc = json.loads(raw[20:20+count])
    binary = raw[28+count:]
    return doc, binary


def values(doc, binary, index):
    a = doc['accessors'][index]
    view = doc['bufferViews'][a['bufferView']]
    dtype = np.dtype(TYPES[a['componentType']])
    width = COUNTS[a['type']]
    offset = view.get('byteOffset',0)+a.get('byteOffset',0)
    result = np.ndarray((a['count'],width), dtype=dtype, buffer=binary, offset=offset,
                        strides=(view.get('byteStride',width*dtype.itemsize),dtype.itemsize)).copy()
    assert np.isfinite(result).all()
    return result


def local(node):
    if 'matrix' in node:
        return Matrix(np.array(node['matrix']).reshape(4,4).T.tolist())
    x,y,z,w = node.get('rotation',[0,0,0,1])
    return Matrix.LocRotScale(Vector(node.get('translation',[0,0,0])),Quaternion((w,x,y,z)),Vector(node.get('scale',[1,1,1])))


def worlds(doc):
    parents = {c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
    cache = {}
    def matrix(i):
        if i not in cache:
            cache[i] = (matrix(parents[i]) if i in parents else Matrix.Identity(4)) @ local(doc['nodes'][i])
        return cache[i]
    return [matrix(i) for i in range(len(doc['nodes']))],parents


def geometry(doc,binary):
    matrices,_ = worlds(doc)
    meshes = []
    for i,node in enumerate(doc['nodes']):
        if 'mesh' not in node:
            continue
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            assert primitive.get('mode',4)==4
            attr = primitive['attributes']
            for key in ['POSITION','NORMAL','TEXCOORD_0','TANGENT']:
                assert key in attr, (node['name'],'missing '+key)
            p = values(doc,binary,attr['POSITION'])
            n = values(doc,binary,attr['NORMAL'])
            assert np.max(np.abs(np.linalg.norm(n,axis=1)-1)) < .001
            indices = values(doc,binary,primitive['indices']).reshape(-1,3).astype(int)
            assert indices.min()>=0 and indices.max()<len(p)
            h = np.column_stack((p,np.ones(len(p))))
            if 'skin' in node:
                skin = doc['skins'][node['skin']]
                joints = values(doc,binary,attr['JOINTS_0']).astype(int)
                weights = values(doc,binary,attr['WEIGHTS_0'])
                assert np.min(weights)>=0 and np.max(np.abs(weights.sum(axis=1)-1)) < .0001
                assert joints.max()<len(skin['joints'])
                binds = values(doc,binary,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
                transforms = np.asarray([matrices[j] for j in skin['joints']]) @ binds
                world = np.zeros_like(h)
                for slot in range(4):
                    world += np.einsum('nij,nj->ni',transforms[joints[:,slot]],h)*weights[:,slot,None]
                world = world[:,:3]
            else:
                world = (h@np.asarray(matrices[i]).T)[:,:3]
            triangles = world[indices]
            area = np.linalg.norm(np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]),axis=1)/2
            assert area.min()>1e-12, (node['name'],'degenerate triangle',float(area.min()))
            meshes.append(dict(name=node['name'],points=world,indices=indices,material=primitive['material']))
    return meshes


def audit(kind):
    folder = ROOT/('recruit' if kind=='recruit' else 'assault_rifle')
    name = 'recruit_realistic' if kind=='recruit' else 'assault_rifle_realistic'
    path = folder/(name+'.glb')
    doc,binary = read(path)
    assert not doc.get('cameras') and not doc.get('animations')
    assert 'KHR_lights_punctual' not in doc.get('extensions',{})
    assert not any('camera' in n or 'KHR_lights_punctual' in n.get('extensions',{}) for n in doc['nodes'])
    meshes = geometry(doc,binary)
    points = np.concatenate([m['points'] for m in meshes])
    lo,hi = points.min(axis=0),points.max(axis=0)
    textures = []
    for image in doc['images']:
        view = doc['bufferViews'][image['bufferView']]
        offset = view.get('byteOffset',0)
        raw = binary[offset:offset+view['byteLength']]
        assert raw[:8]==b'\x89PNG\r\n\x1a\n'
        width,height = struct.unpack_from('>II',raw,16)
        assert 1<=width<=2048 and 1<=height<=2048
        textures.append(dict(name=image.get('name'),width=width,height=height))
    for material in doc['materials']:
        pbr = material['pbrMetallicRoughness']
        assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in material
    external_textures = []
    for texture in sorted((folder/'textures').glob('*.png')):
        raw = texture.read_bytes()
        assert raw[:8]==b'\x89PNG\r\n\x1a\n'
        width,height = struct.unpack_from('>II',raw,16)
        assert 1<=width<=2048 and 1<=height<=2048
        external_textures.append(dict(file='textures/'+texture.name,width=width,height=height))
    original = PROJECT/('assets/models/characters/recruit/recruit_v03.glb' if kind=='recruit' else 'assets/models/weapons/tactical_original/assault_rifle.glb')
    old,old_binary = read(original)
    report = dict(passed=False,model=name,license_new_work='CC0-1.0',units='metres',forward='-Z',
                  triangles=sum(len(m['indices']) for m in meshes),mesh_nodes=len({m['name'] for m in meshes}),
                  dimensions_m=(hi-lo).tolist(),bounds_min_m=lo.tolist(),bounds_max_m=hi.tolist(),
                  bone_count=sum(len(s['joints']) for s in doc.get('skins',[])),
                  materials=[m['name'] for m in doc['materials']],material_count=len(doc['materials']),
                  textures=textures,external_textures=external_textures,
                  pbr_channels=['albedo','roughness','metalness','tangent_normal'],
                  pbr_export='Roughness in G and metalness in B of ORM; separate PNG channels also delivered.',
                  glb_sha256=hashlib.sha256(path.read_bytes()).hexdigest(),glb_bytes=path.stat().st_size,
                  original_sha256=hashlib.sha256(original.read_bytes()).hexdigest(),
                  no_cameras_lights=True,godot_executed=False)
    current_matrices,current_parents = worlds(doc)
    old_matrices,old_parents = worlds(old)
    if kind=='recruit':
        joints = doc['skins'][0]['joints']
        before = old['skins'][0]['joints']
        names = {doc['nodes'][i]['name']:i for i in joints}
        old_names = {old['nodes'][i]['name']:i for i in before}
        assert set(names)==set(old_names) and len(names)==53, 'Exact original bone names required'
        error = 0.
        for bone,i in names.items():
            j = old_names[bone]
            parent = doc['nodes'][current_parents[i]]['name'] if i in current_parents else None
            old_parent = old['nodes'][old_parents[j]]['name'] if j in old_parents else None
            assert parent==old_parent, (bone,'hierarchy changed',parent,old_parent)
            error = max(error,float(np.max(np.abs(np.asarray(current_matrices[i])-np.asarray(old_matrices[j])))))
            assert np.max(np.abs(np.asarray(local(doc['nodes'][i]))-np.asarray(local(old['nodes'][j])))) < .00002, (bone,'local rest orientation or location changed')
        assert error < .00002, ('Global rest changed',error)
        assert abs(lo[1])<.0001 and abs(hi[1]-2.025)<.001, 'Feet pivot and original real height'
        assert all('DEF-'+part+'.'+side in names for side in ['L','R'] for part in ['thigh','shin','foot','toe','upper_arm','forearm','hand'])
        report['rig_contract'] = dict(exact_names=True,exact_parent_names=True,max_rest_matrix_component_error=error,
                                      names=sorted(names),root_origin_m=list(current_matrices[names['root']].translation),
                                      ual_basis_preserved=True,feet_ground_error_m=float(abs(lo[1])))
    else:
        assert not doc.get('skins')
        old_meshes = geometry(old,old_binary)
        def cloud_by_name(groups):
            return {n:np.unique(np.round(np.concatenate([m['points'] for m in groups if m['name']==n]),7),axis=0)
                    for n in {m['name'] for m in groups}}
        a,b = cloud_by_name(meshes),cloud_by_name(old_meshes)
        assert set(a)==set(b), 'Original part names required'
        deviation = 0.
        for part in a:
            tree = KDTree(len(b[part]))
            for i,p in enumerate(b[part]):tree.insert(Vector(p),i)
            tree.balance()
            deviation=max(deviation,max(tree.find(Vector(p))[2] for p in a[part]))
        assert deviation<.000001, ('Weapon contact geometry moved',deviation)
        by_name = {n['name']:i for i,n in enumerate(doc['nodes'])}
        old_by_name = {n['name']:i for i,n in enumerate(old['nodes'])}
        muzzle = current_matrices[by_name['Muzzle']].translation
        assert (muzzle-old_matrices[old_by_name['Muzzle']].translation).length < .000001
        support = Vector((0,.077180013,-.26))
        distance = min(BVHTree.FromPolygons(m['points'].tolist(),m['indices'].tolist(),all_triangles=True).find_nearest(support)[3] for m in meshes)
        assert distance<.0001, ('Support point lost',distance)
        assert report['triangles']==7482 and abs((hi-lo)[2]-.9608)<.00001
        report['contact_contract'] = dict(grip_origin_m=[0,0,0],support_m=list(support),support_surface_error_m=distance,
                                         muzzle_m=list(muzzle),max_original_surface_vertex_error_m=deviation,
                                         original_part_names_preserved=True)
    source = folder/'source'/(name+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(source))
    assert not any(o.type in ['CAMERA','LIGHT'] for o in bpy.context.scene.objects)
    rigs = [o for o in bpy.context.scene.objects if o.type=='ARMATURE']
    assert len(rigs)==(1 if kind=='recruit' else 0)
    if kind=='recruit':
        assert {b.name for b in rigs[0].data.bones} == set(names)
    assert not any(o.type=='CURVE' for o in bpy.context.scene.objects), 'Exportable mesh geometry only'
    report['source_blend_sha256']=hashlib.sha256(source.read_bytes()).hexdigest()
    report['source_reopened']=True
    report['provenance'] = {'base_model':str(original.relative_to(PROJECT)).replace('\\','/'),
                            'new_textures':'Original deterministic procedural maps; no downloaded inputs.',
                            'character_rig':'Existing UAL-compatible CC0 rig, unchanged.' if kind=='recruit' else None}
    report['limits'] = ['Offline structural and sampled geometric validation; no Godot import or gameplay test.',
                        'No full triangle intersection or cloth simulation proof.',
                        'No LODs, performance benchmark or full UAL clip playback validation.']
    if kind=='recruit':
        report['limits'].append('Visual candidate with original procedural textures; head and proportions remain partly stylized, not a scanned or photorealistic human.')
    report['passed']=True
    (folder/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('VALIDATION',kind,json.dumps({k:report[k] for k in ['passed','triangles','dimensions_m','bone_count','materials','glb_bytes']}),flush=True)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--only',choices=['recruit','rifle'],required=True)
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    try:
        audit(args.only)
    except Exception as error:
        folder = ROOT/('recruit' if args.only=='recruit' else 'assault_rifle')
        (folder/'validation.json').write_text(json.dumps({'passed':False,'error':str(error)},indent=2)+'\n')
        raise
