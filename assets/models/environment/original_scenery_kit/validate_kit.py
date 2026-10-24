"""Independent audit of delivered GLBs, not builder counts. CC0-1.0.
Run with Blender --background --factory-startup --python-exit-code 1 --python validate_kit.py
"""
import hashlib
import json
from pathlib import Path
import struct

import bpy
import numpy as np
from mathutils import Matrix,Quaternion,Vector

ROOT=Path(__file__).resolve().parent
EXPECTED={'beach_horror':['dead_tree','driftwood','stranded_hull','crooked_dock_post','fallen_fishing_net'],
          'coastal_facade':['window_shutters','door_frame','canvas_awning','small_balcony','exterior_stair','tavern_sign','wall_lantern','chimney']}
DTYPE={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}
SIZE={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}


def read(file):
    raw=file.read_bytes();assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    length,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
    n,kind=struct.unpack_from('<II',raw,20+length);assert kind==0x004e4942
    binary=raw[28+length:];assert n==len(binary)
    return json.loads(raw[20:20+length]),binary


def access(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']];dtype=np.dtype(DTYPE[a['componentType']]);size=SIZE[a['type']]
    result=np.ndarray((a['count'],size),dtype=dtype,buffer=binary,offset=v.get('byteOffset',0)+a.get('byteOffset',0),
                      strides=(v.get('byteStride',dtype.itemsize*size),dtype.itemsize)).copy()
    assert np.isfinite(result).all()
    return result


def worlds(doc):
    local=[]
    for n in doc['nodes']:
        if 'matrix' in n:m=Matrix(np.array(n['matrix']).reshape(4,4).T.tolist())
        else:
            x,y,z,w=n.get('rotation',[0,0,0,1]);m=Matrix.LocRotScale(Vector(n.get('translation',[0,0,0])),Quaternion((w,x,y,z)),Vector(n.get('scale',[1,1,1])))
        local.append(m)
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])};cache={}
    def get(i):
        if i not in cache:cache[i]=(get(parents[i]) if i in parents else Matrix.Identity(4))@local[i]
        return cache[i]
    return [get(i) for i in range(len(local))]


def audit(file,kit):
    doc,binary=read(file);transform=worlds(doc)
    assert not any(doc.get(k) for k in ['animations','skins','cameras'])
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert all('camera' not in n and 'skin' not in n for n in doc['nodes'])
    assert all('uri' not in image for image in doc['images'])
    assert all('uri' not in b for b in doc['buffers'])
    assert doc['asset']['extras']['license']=='CC0-1.0'
    assert doc['asset']['extras']['units']=='metres'
    assert len(doc['meshes'])==1,('One mesh/draw primitive per prop expected',file.name)
    assert len(doc['materials'])==1
    mat=doc['materials'][0];pbr=mat['pbrMetallicRoughness']
    assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in mat
    assert mat.get('alphaMode','OPAQUE')=='OPAQUE'
    points=[];triangles=0;primitive_count=0;minimum_area=float('inf')
    for i,node in enumerate(doc['nodes']):
        if 'mesh' not in node:continue
        assert transform[i].translation.length<1e-5,('Export root pivot moved',file.name)
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            primitive_count+=1;assert primitive.get('mode',4)==4
            a=primitive['attributes'];assert all(k in a for k in ['POSITION','NORMAL','TANGENT','TEXCOORD_0'])
            v=access(doc,binary,a['POSITION']);normal=access(doc,binary,a['NORMAL']);tangent=access(doc,binary,a['TANGENT']);uv=access(doc,binary,a['TEXCOORD_0'])
            assert len(v)==len(normal)==len(tangent)==len(uv)
            assert np.max(np.abs(np.linalg.norm(normal,axis=1)-1))<.001
            assert np.max(np.abs(np.linalg.norm(tangent[:,:3],axis=1)-1))<.001
            tangent_error=float(np.max(np.abs((normal*tangent[:,:3]).sum(axis=1))))
            assert tangent_error<.002,('Tangent is not perpendicular to normal',file.name,tangent_error)
            assert uv.min()>=0 and uv.max()<=1
            index=access(doc,binary,primitive['indices']).reshape(-1,3).astype(int)
            assert index.min()>=0 and index.max()<len(v)
            m=np.asarray(transform[i]);world=(m@np.column_stack((v,np.ones(len(v)))).T).T[:,:3]
            t=world[index];area=np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)*.5
            minimum_area=min(minimum_area,float(area.min()));assert area.min()>1e-12,('Degenerate face',file.name)
            triangles+=len(index);points.append(world)
    assert primitive_count==1
    points=np.concatenate(points);lo,hi=points.min(axis=0),points.max(axis=0);dimensions=hi-lo
    limit=2500 if kit=='beach_horror' else 800;assert triangles<=limit
    assert dimensions.min()>.015 and dimensions.max()<7
    if kit=='beach_horror':
        assert abs(lo[1])<.0001 and np.max(np.abs((lo+hi)[[0,2]]*.5))<.0001,('Base centre pivot',file.name,lo,hi)
        assert doc['asset']['extras']['forward']=='-Z'
        if file.stem=='dead_tree':assert 3<=dimensions[1]<=5
        if file.stem=='stranded_hull':assert 4<=dimensions[2]<=6
        pivot={'type':'base centre','ground_y_m':float(lo[1]),'centre_xz_m':((lo+hi)[[0,2]]*.5).tolist()}
    else:
        assert abs(lo[2])<.0001 and doc['asset']['extras']['forward']=='+Z'
        contact=points[np.abs(points[:,2])<.00001];assert len(contact)>=3
        centre=(contact.min(axis=0)+contact.max(axis=0))*.5
        assert np.linalg.norm(centre)<.0001,('Mount face centre',file.name,centre)
        assert np.ptp(contact[:,0])>.025 and np.ptp(contact[:,1])>.025
        pivot={'type':'rear mounting face centre','rear_z_m':float(lo[2]),'mounting_face_centre_m':centre.tolist(),
               'mounting_face_size_xy_m':np.ptp(contact,axis=0)[:2].tolist()}
    images=[]
    for image in doc['images']:
        view=doc['bufferViews'][image['bufferView']];b=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        assert b[:8]==b'\x89PNG\r\n\x1a\n';w,h=struct.unpack_from('>II',b,16)
        assert (w,h)==(1024,1024)
        images.append({'name':image.get('name'),'width':w,'height':h,'bytes':len(b)})
    assert len(images)==3
    return {'passed':True,'file':file.name,'sha256':hashlib.sha256(file.read_bytes()).hexdigest(),'bytes':file.stat().st_size,
            'triangles':triangles,'triangle_limit':limit,'mesh_count':len(doc['meshes']),'primitive_count':primitive_count,
            'dimensions_xyz_m':dimensions.tolist(),'bounds_min_m':lo.tolist(),'bounds_max_m':hi.tolist(),'pivot':pivot,
            'material_names':[mat['name']],'pbr_channels':['sRGB albedo','linear roughness (ORM G)','linear metallic (ORM B)','tangent normal'],
            'textures':images,'minimum_triangle_area_m2':minimum_area,'forward':doc['asset']['extras']['forward'],
            'cameras':0,'lights':0,'animations':0,'bones':0}


def main():
    result={'passed':False,'license':'CC0-1.0','kits':{},'validator':'Independent raw GLB geometry/material inspection; Blender source reopen',
            'limits':['No Godot import, integration, collision, LOD or GPU performance test.',
                      'Bounds/pivots are measured from actual exported geometry. Front orientation is the authoring/export convention.',
                      'No continuous self-intersection, structural strength or physics certification.',
                      'Original procedural PBR maps; glass is intentionally opaque/frosted, lantern has no real light.']}
    try:
        for kit,names in EXPECTED.items():
            assert {p.stem for p in (ROOT/kit).glob('*.glb')}==set(names)
            models={name:audit(ROOT/kit/(name+'.glb'),kit) for name in names}
            renders={}
            labels=names if kit=='beach_horror' else ['facade_assembly']
            for name in labels:
                path=ROOT/kit/'renders'/(name+'.png');raw=path.read_bytes();assert raw[:8]==b'\x89PNG\r\n\x1a\n'
                renders[name]={'path':'renders/'+path.name,'sha256':hashlib.sha256(raw).hexdigest(),'dimensions_px':list(struct.unpack_from('>II',raw,16))}
            result['kits'][kit]={'passed':True,'models':models,'renders':renders}
            print('KIT PASS',kit,[(n,m['triangles']) for n,m in models.items()],flush=True)
        source=ROOT/'source/scenery_kit.blend';bpy.ops.wm.open_mainfile(filepath=str(source))
        assert not any(o.type in ['CAMERA','LIGHT','ARMATURE'] for o in bpy.context.scene.objects)
        assert not bpy.data.actions
        assert all(o.animation_data is None for o in bpy.context.scene.objects)
        assert len([o for o in bpy.context.scene.objects if o.type=='MESH'])==13
        result.update(passed=True,source_reopened=True,source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
                      source_unit_scale=bpy.context.scene.unit_settings.scale_length,godot_executed=False,external_assets_downloaded=False)
        assert result['source_unit_scale']==1
    except Exception as error:
        result['error']=str(error);raise
    finally:
        (ROOT/'validation.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
        for kit,entry in result['kits'].items():
            subset={k:v for k,v in result.items() if k!='kits'};subset.update(entry)
            (ROOT/kit/'validation.json').write_text(json.dumps(subset,indent=2)+'\n',encoding='utf-8')
    print('ALL 13 SCENERY ASSETS PASSED',flush=True)


if __name__=='__main__':main()
