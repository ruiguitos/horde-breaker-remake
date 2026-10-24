"""Independent audit of actual exported skinning, animation and texture data.
Blender only; no Godot, no network. SPDX-License-Identifier: CC0-1.0
Run: blender --background --python-exit-code 1 --python validate_walker.py
"""
import hashlib
import json
import math
from pathlib import Path
import struct

import bpy
import numpy as np
from mathutils import Matrix,Quaternion,Vector

ROOT=Path(__file__).resolve().parent
PROJECT=ROOT.parents[3]
DTYPES={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}
WIDTHS={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
EXPECTED={'walk':1.1,'run':.64,'attack':1.,'death':1.2}


def read(file):
    raw=file.read_bytes();magic,version,length=struct.unpack_from('<III',raw)
    assert (magic,version,length)==(0x46546c67,2,len(raw))
    size=struct.unpack_from('<I',raw,12)[0]
    return json.loads(raw[20:20+size]),raw[28+size:]


def access(doc,binary,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    dtype=np.dtype(DTYPES[a['componentType']]);width=WIDTHS[a['type']]
    v=np.ndarray((a['count'],width),dtype=dtype,buffer=binary,
                 offset=view.get('byteOffset',0)+a.get('byteOffset',0),
                 strides=(view.get('byteStride',dtype.itemsize*width),dtype.itemsize)).copy()
    assert np.isfinite(v).all()
    return v


def matrix(node):
    if 'matrix' in node:return Matrix(np.array(node['matrix']).reshape(4,4).T.tolist())
    x,y,z,w=node.get('rotation',[0,0,0,1])
    return Matrix.LocRotScale(Vector(node.get('translation',[0,0,0])),Quaternion((w,x,y,z)),Vector(node.get('scale',[1,1,1])))


def tracks(doc,binary,clip):
    result=[]
    for c in clip['channels']:
        sampler=clip['samplers'][c['sampler']]
        assert sampler.get('interpolation','LINEAR') in ['LINEAR','STEP']
        result.append((c['target']['node'],c['target']['path'],access(doc,binary,sampler['input'])[:,0],
                       access(doc,binary,sampler['output']),sampler.get('interpolation','LINEAR')))
    return result


def worlds(doc,channels=(),t=0.):
    local=[matrix(n) for n in doc['nodes']]
    for node,path,time,values,interpolation in channels:
        end=min(len(time)-1,int(np.searchsorted(time,t)));start=max(0,end-1)
        f=0. if end==start or interpolation=='STEP' else max(0,min(1,(t-float(time[start]))/float(time[end]-time[start])))
        position,rotation,scale=local[node].decompose()
        a,b=values[start],values[end]
        if path=='translation':position=Vector(a).lerp(Vector(b),f)
        elif path=='rotation':rotation=Quaternion((a[3],*a[:3])).slerp(Quaternion((b[3],*b[:3])),f)
        elif path=='scale':scale=Vector(a).lerp(Vector(b),f)
        else:raise AssertionError('Unexpected animation channel '+path)
        local[node]=Matrix.LocRotScale(position,rotation,scale)
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
    cache={}
    def evaluate(i):
        if i not in cache:cache[i]=(evaluate(parents[i]) if i in parents else Matrix.Identity(4))@local[i]
        return cache[i]
    return [evaluate(i) for i in range(len(local))]


def meshes(doc,binary):
    result=[]
    assert len(doc['skins'])==1
    skin=doc['skins'][0]
    bind=access(doc,binary,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    for node in doc['nodes']:
        if 'mesh' not in node:continue
        assert node['skin']==0
        for p in doc['meshes'][node['mesh']]['primitives']:
            a=p['attributes']
            assert all(k in a for k in ['POSITION','NORMAL','TANGENT','TEXCOORD_0','JOINTS_0','WEIGHTS_0'])
            assert p.get('mode',4)==4
            vertices=access(doc,binary,a['POSITION'])
            normals=access(doc,binary,a['NORMAL'])
            assert np.max(np.abs(np.linalg.norm(normals,axis=1)-1))<.001
            weights=access(doc,binary,a['WEIGHTS_0']);joints=access(doc,binary,a['JOINTS_0']).astype(int)
            assert weights.min()>=0 and np.max(np.abs(weights.sum(axis=1)-1))<.0001
            assert joints.max()<len(skin['joints'])
            indices=access(doc,binary,p['indices']).reshape(-1,3).astype(int)
            assert indices.min()>=0 and indices.max()<len(vertices)
            result.append(dict(name=node['name'],points=np.column_stack((vertices,np.ones(len(vertices)))),
                               weights=weights,joints=joints,bind=bind,indices=indices))
    return result


def deform(group,doc,matrices):
    transforms=np.asarray([matrices[i] for i in doc['skins'][0]['joints']])@group['bind']
    out=np.zeros_like(group['points'])
    for slot in range(4):
        out+=np.einsum('nij,nj->ni',transforms[group['joints'][:,slot]],group['points'])*group['weights'][:,slot,None]
    return out[:,:3]


def pose_points(groups,doc,matrices):
    return np.concatenate([deform(g,doc,matrices) for g in groups])


def audit(file,limit):
    doc,binary=read(file);rest=worlds(doc);groups=meshes(doc,binary)
    assert not doc.get('cameras') and 'KHR_lights_punctual' not in doc.get('extensions',{})
    assert not any('camera' in n or 'KHR_lights_punctual' in n.get('extensions',{}) for n in doc['nodes'])
    joints=doc['skins'][0]['joints'];ids={doc['nodes'][i]['name']:i for i in joints}
    reference,_=read(PROJECT/'assets/models/characters/recruit/recruit_v03.glb')
    source_bones={reference['nodes'][i]['name'] for i in reference['skins'][0]['joints']}
    omitted=sorted(n for n in source_bones if n.startswith(('DEF-f_','DEF-thumb.')))
    assert set(ids)==source_bones-set(omitted) and len(ids)==23
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
    old_parents={c:i for i,n in enumerate(reference['nodes']) for c in n.get('children',[])}
    old_ids={n['name']:i for i,n in enumerate(reference['nodes'])}
    parent_report={}
    for name,i in ids.items():
        new=doc['nodes'][parents[i]]['name'];old=reference['nodes'][old_parents[old_ids[name]]]['name']
        assert new==old,(name,new,old)
        parent_report[name]=new
    count=sum(len(g['indices']) for g in groups)
    assert count<=limit,(file.name,count,limit)
    points=pose_points(groups,doc,rest);lo,hi=points.min(axis=0),points.max(axis=0)
    assert abs(lo[1])<.005 and abs(hi[1]-1.95)<.012
    for g in groups:
        tris=deform(g,doc,rest)[g['indices']]
        area=np.linalg.norm(np.cross(tris[:,1]-tris[:,0],tris[:,2]-tris[:,0]),axis=1)/2
        assert area.min()>1e-12,(g['name'],'degenerate triangles',float(area.min()))
    skull=next(g for g in groups if g['name'].startswith('Skull_'))
    cranium=deform(skull,doc,rest)
    centre=(cranium.min(axis=0)+cranium.max(axis=0))/2
    target=np.array([0,1.8,.03]);skull_error=float(np.linalg.norm(centre-target))
    assert skull_error<=.02,(file.name,'Skull displaced',centre,skull_error)
    texture_report=[]
    for image in doc['images']:
        view=doc['bufferViews'][image['bufferView']];offset=view.get('byteOffset',0)
        raw=binary[offset:offset+view['byteLength']]
        assert raw[:8]==b'\x89PNG\r\n\x1a\n'
        width,height=struct.unpack_from('>II',raw,16)
        assert width<=1024 and height<=1024
        texture_report.append(dict(name=image.get('name'),width=width,height=height,bytes=len(raw)))
    assert len(doc['materials'])==1
    material=doc['materials'][0]
    assert all(k in material['pbrMetallicRoughness'] for k in ['baseColorTexture','metallicRoughnessTexture'])
    assert 'normalTexture' in material
    assert file.stat().st_size<8_000_000, 'Compact 1K asset budget'
    animations={a['name']:a for a in doc['animations']}
    assert set(animations)==set(EXPECTED)
    reports={};root=ids['root'];rig=parents[root]
    pivot=rest[root].translation
    assert pivot.length<.0001,('Root pivot displaced',list(pivot))
    for clip,duration in EXPECTED.items():
        animation=animations[clip];channels=tracks(doc,binary,animation)
        begin=min(float(c[2][0]) for c in channels);end=max(float(c[2][-1]) for c in channels)
        assert abs(begin)<1e-6 and abs(end-duration)<1e-6,(clip,begin,end)
        extras=animation['extras']
        assert extras['loop']==(clip in ['walk','run']) and extras['root_motion'] is False
        frames=[worlds(doc,channels,float(t)) for t in np.linspace(0,duration,round(duration*100)+1)]
        root_error=max(float(np.max(np.abs(np.asarray(m[i])-np.asarray(rest[i])))) for m in frames for i in [root,rig])
        assert root_error<.00001,(clip,'Root motion',root_error)
        ground_min=math.inf;max_corpse=0.;hold_error=0.;head_deviation=0.
        for step,m in enumerate(frames):
            posed=pose_points(groups,doc,m)
            assert np.isfinite(posed).all()
            ground_min=min(ground_min,float(posed[:,1].min()))
            cranium=deform(skull,doc,m)
            c=(cranium.min(axis=0)+cranium.max(axis=0))/2
            head_deviation=max(head_deviation,float(np.linalg.norm(c-target)))
            if clip=='death' and step>=100:
                max_corpse=max(max_corpse,float(posed[:,1].max()))
                hold_error=max(hold_error,float(np.max(np.abs(posed-pose_points(groups,doc,frames[100])))))
        assert ground_min>=-.008,(file.name,clip,'Ground penetration',ground_min)
        entry=dict(duration_s=end,samples=len(frames),loop=extras['loop'],root_matrix_error=root_error,
                   min_ground_clearance_m=ground_min,max_skull_deviation_from_rest_m=head_deviation)
        if clip in ['walk','run']:
            loop_error=max(float(np.max(np.abs(np.asarray(a)-np.asarray(b)))) for a,b in zip(frames[0],frames[-1]))
            assert loop_error<.0001,(clip,'Cycle discontinuity',loop_error)
            speed=1. if clip=='walk' else 5.;stance=.58 if clip=='walk' else .28
            error=0.;contact_samples=0
            for side,offset in [('L',0.),('R',.5)]:
                i=ids['DEF-foot.'+side]
                for k in range(len(frames)-1):
                    p0=(k*.01/duration+offset)%1;p1=((k+1)*.01/duration+offset)%1
                    if p1>=p0 and p1<stance and p0<stance:
                        velocity=(frames[k+1][i].translation-frames[k][i].translation)/.01
                        error=max(error,(velocity-Vector((0,0,speed))).length);contact_samples+=1
            assert contact_samples>10 and error<.005,(clip,'Stance speed error',error)
            assert extras['ground_speed_mps']==speed
            entry.update(ground_speed_mps=speed,stride_m=speed*duration,stance_speed_error_mps=error,
                         stance_intervals_checked=contact_samples,loop_matrix_error=loop_error)
        if clip=='attack':
            assert extras['contact_time_s']==.6
            m=frames[60];tip=m[ids['DEF-hand.R']]@Vector((0,.16,0))
            assert abs(tip.z-(-.72))<.005,('Contact at .6 s',list(tip))
            forward=[(frame[ids['DEF-hand.R']]@Vector((0,.16,0))).z for frame in frames]
            peak=int(np.argmin(forward))/100
            assert abs(peak-.6)<=.01,('Attack reach peaks at wrong time',peak)
            entry.update(contact_time_s=.6,right_fingertip_at_contact_m=list(tip),contact_plane_z_m=-.72,
                         peak_reach_time_s=peak)
        if clip=='death':
            assert max_corpse<.55 and hold_error<.00001,('Corpse hold',max_corpse,hold_error)
            entry.update(hold_from_s=1.,hold_error_m=hold_error,final_max_height_m=max_corpse)
        reports[clip]=entry
    return dict(passed=True,file=file.name,sha256=hashlib.sha256(file.read_bytes()).hexdigest(),bytes=file.stat().st_size,
                triangles=count,triangle_limit=limit,mesh_count=len(groups),material_count=1,
                material_names=[material['name']],textures=texture_report,
                dimensions_m=(hi-lo).tolist(),bounds_min_m=lo.tolist(),bounds_max_m=hi.tolist(),
                skull_center_rest_m=centre.tolist(),skull_error_m=skull_error,bone_count=len(ids),
                bone_names=sorted(ids),bone_parents=parent_report,omitted_bones=omitted,
                clips=reports,units='metres',forward='-Z',pivot_m=list(pivot),nominal_game_height_m=1.7,
                height_resolution='User approved visual height ~1.95 m to retain the current skull target.',
                godot_executed=False)


def main():
    report={'passed':False,'license':'CC0-1.0','lods':{},'validation_tool':'Blender / independent glTF channel evaluation'}
    try:
        for file,limit in [('walker_lod0.glb',8000),('walker_lod1.glb',2000)]:
            report['lods'][file]=audit(ROOT/file,limit)
            print('AUDIT PASS',file,report['lods'][file]['triangles'],flush=True)
        source=ROOT/'source/walker.blend';bpy.ops.wm.open_mainfile(filepath=str(source))
        assert not any(o.type in ['LIGHT','CAMERA'] for o in bpy.context.scene.objects)
        rig=next(o for o in bpy.context.scene.objects if o.type=='ARMATURE')
        assert len(rig.data.bones)==23
        assert {a.name for a in bpy.data.actions}==set(EXPECTED)
        for file in (ROOT/'textures').glob('*.png'):
            width,height=struct.unpack_from('>II',file.read_bytes(),16);assert max(width,height)<=1024
        report.update(passed=True,source_reopened=True,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                      bones_omitted_except_requested_fingers=[],source_materials_original=True,
                      visual_status='Original procedural mesh and PBR surface treatment; realistic hero-level anatomical sculpting and authored fabric detail remain unfinished. Technical pass does not certify visual realism.',
                      limits=['Offline validation only; no Godot import, horde integration or GPU performance measurement.',
                              'Skull centre is the anatomical cranium bounds centre; jaw/hair do not redefine the aim landmark.',
                              'Names and parents match UAL; Walker-specific bind axes/proportions require retargeting for unrelated UAL clips.',
                              'Sampled at 100 Hz; not a continuous collision or self-intersection proof.',
                              'Attack contact uses a reference plane; no player collider or actual damage was simulated.'])
    except Exception as error:
        report['error']=str(error)
        raise
    finally:
        (ROOT/'validation.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print('WALKER VALIDATION PASSED',flush=True)


if __name__=='__main__':main()
