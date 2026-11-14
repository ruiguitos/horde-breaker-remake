"""Audit delivered bytes and source meshes independently of build counts.
Blender 5.2, NumPy bundled with Blender. No Godot invocation.
SPDX-License-Identifier: CC0-1.0
"""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import struct

import bpy
import bmesh
import numpy as np

ROOT=Path(__file__).resolve().parent
EXPECTED={'concrete_wall':[4,2.4,.4],'low_cover':[4,1.1,.4],
          'shipping_container':[6,2.6,2.4],'platform':[8,1.2,8],
          'ramp':[8,1.2,4],'landmark_pillar':[1.2,6,1.2],
          'extraction_beacon':[2,3.5,2],'dock':[10,1.5,3]}
DTYPES={5121:'u1',5123:'<u2',5125:'<u4',5126:'<f4'}
WIDTH={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}


def read(path):
    raw=path.read_bytes();assert struct.unpack_from('<III',raw)==(0x46546c67,2,len(raw))
    length,kind=struct.unpack_from('<II',raw,12);assert kind==0x4e4f534a
    n,kind=struct.unpack_from('<II',raw,20+length);assert kind==0x004e4942
    doc=json.loads(raw[20:20+length]);binary=raw[28+length:];assert len(binary)==n
    return doc,binary


def access(doc,binary,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    dtype=np.dtype(DTYPES[a['componentType']]);width=WIDTH[a['type']]
    result=np.ndarray((a['count'],width),dtype=dtype,buffer=binary,
        offset=view.get('byteOffset',0)+a.get('byteOffset',0),
        strides=(view.get('byteStride',dtype.itemsize*width),dtype.itemsize)).copy()
    assert np.isfinite(result).all()
    return result


def polygon_area(poly):
    return abs(sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1])))*.5 if len(poly)>2 else 0


def clip(subject,clipper):
    # Convex polygon intersection, used to prove a pair of ground triangles
    # covers the entire rectangular projection, rather than sampling a few rays.
    clipper=list(map(tuple,clipper));subject=list(map(tuple,subject))
    signed=sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(clipper,clipper[1:]+clipper[:1]))
    if signed<0:clipper.reverse()
    def cross(a,b,p):return (b[0]-a[0])*(p[1]-a[1])-(b[1]-a[1])*(p[0]-a[0])
    for a,b in zip(clipper,clipper[1:]+clipper[:1]):
        old=subject;subject=[]
        if not old:break
        p=old[-1];pd=cross(a,b,p)
        for q in old:
            qd=cross(a,b,q)
            if (pd>=-1e-9)!=(qd>=-1e-9):
                t=pd/(pd-qd);subject.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1])))
            if qd>=-1e-9:subject.append(q)
            p,pd=q,qd
    return subject


def audit_glb(name):
    path=ROOT/'modules'/name/(name+'.glb');doc,binary=read(path)
    assert len(doc['scenes'])==1 and len(doc['meshes'])==1
    assert not any(doc.get(k) for k in ['animations','skins','cameras'])
    assert 'KHR_lights_punctual' not in doc.get('extensionsUsed',[])
    assert doc['asset']['extras']['license']=='CC0-1.0' and doc['asset']['extras']['units']=='metres'
    assert all('uri' not in image for image in doc.get('images',[]))
    assert len(doc['materials'])==1
    material=doc['materials'][0];pbr=material['pbrMetallicRoughness']
    assert 'baseColorTexture' in pbr and 'metallicRoughnessTexture' in pbr and 'normalTexture' in material
    assert material.get('alphaMode','OPAQUE')=='OPAQUE'
    mesh_nodes=[n for n in doc['nodes'] if 'mesh' in n]
    assert len(mesh_nodes)==1
    for node in mesh_nodes:
        assert 'matrix' not in node
        assert np.linalg.norm(node.get('translation',[0,0,0]))<1e-6
        assert np.max(np.abs(np.array(node.get('rotation',[0,0,0,1]))-[0,0,0,1]))<1e-6
        assert np.max(np.abs(np.array(node.get('scale',[1,1,1]))-1))<1e-6
    mesh=doc['meshes'][0];assert len(mesh['primitives'])==1
    primitive=mesh['primitives'][0];assert primitive.get('mode',4)==4
    a=primitive['attributes'];assert all(key in a for key in ['POSITION','NORMAL','TANGENT','TEXCOORD_0'])
    v=access(doc,binary,a['POSITION']);normal=access(doc,binary,a['NORMAL']);tangent=access(doc,binary,a['TANGENT']);uv=access(doc,binary,a['TEXCOORD_0'])
    index=access(doc,binary,primitive['indices']).reshape(-1,3).astype(int)
    assert index.min()>=0 and index.max()<len(v)
    triangles=v[index].astype(float);count=len(index);assert count<=3000
    lo,hi=v.min(0),v.max(0);dims=hi-lo
    assert np.max(np.abs(dims-EXPECTED[name]))<.00015,(name,dims,EXPECTED[name])
    expected_lo=np.array([-1,0,-1]) if name=='extraction_beacon' else np.zeros(3)
    assert np.max(np.abs(lo-expected_lo))<.0001,(name,lo)
    assert np.max(np.abs(np.linalg.norm(normal,axis=1)-1))<.001
    assert np.max(np.abs(np.linalg.norm(tangent[:,:3],axis=1)-1))<.001
    dot=float(np.max(np.abs((normal*tangent[:,:3]).sum(1))));assert dot<.002
    assert uv.min()>=0 and uv.max()<=1
    areas=np.linalg.norm(np.cross(triangles[:,1]-triangles[:,0],triangles[:,2]-triangles[:,0]),axis=1)*.5
    assert areas.min()>1e-11,(name,areas.min())
    uv_tri=uv[index];uv_det=(uv_tri[:,1,0]-uv_tri[:,0,0])*(uv_tri[:,2,1]-uv_tri[:,0,1])-(uv_tri[:,1,1]-uv_tri[:,0,1])*(uv_tri[:,2,0]-uv_tri[:,0,0])
    assert np.abs(uv_det).min()>1e-12,(name,'collapsed UV')
    # A complete rectangular bottom face proves the union of vertical projection
    # is the full envelope, including below the deck / tripod and bevel corners.
    ground=triangles[np.all(np.abs(triangles[:,:,1])<1e-5,axis=1)][:,:,[0,2]]
    rectangle_area=float(dims[0]*dims[2]);coverage=None
    for i,aa in enumerate(ground):
        for bb in ground[i+1:]:
            area=polygon_area(aa.tolist())+polygon_area(bb.tolist())-polygon_area(clip(aa,bb))
            if abs(area-rectangle_area)<max(.00001,rectangle_area*1e-6):coverage=area;break
        if coverage is not None:break
    assert coverage is not None,(name,'not filled in plan',len(ground))
    images=[]
    for image in doc['images']:
        view=doc['bufferViews'][image['bufferView']];payload=binary[view.get('byteOffset',0):view.get('byteOffset',0)+view['byteLength']]
        assert payload[:8]==b'\x89PNG\r\n\x1a\n'
        w,h=struct.unpack_from('>II',payload,16);assert (w,h)==(1024,1024)
        images.append({'name':image.get('name'),'size':[w,h],'sha256':hashlib.sha256(payload).hexdigest()})
    assert len(images)==3
    mount=next((n for n in doc['nodes'] if n.get('name')=='LightMount'),None)
    if name=='extraction_beacon':assert mount and np.linalg.norm(np.array(mount['translation'])-[0,3.2,0])<1e-5
    return {'passed':True,'file':name+'.glb','sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
        'triangles':count,'triangle_limit':3000,'mesh_count':1,'primitive_count':1,
        'dimensions_xyz_m':[round(float(x),6) for x in dims],
        'bounds_min_xyz_m':[round(float(x),6) for x in lo],'bounds_max_xyz_m':[round(float(x),6) for x in hi],
        'pivot':{'local_position_m':[0,0,0],'type':doc['asset']['extras']['pivot'],'identity_mesh_transform':True},
        'material_names':[material['name']],'textures':images,'pbr_channels':['sRGB albedo','tangent normal','linear ORM: R=1,G=roughness,B=metallic'],
        'uv_check':{'inside_0_1':True,'nondegenerate_triangles':True,'shared_role_atlas_uvs_overlap_intentionally':True},
        'normals_and_tangents':{'exported':True,'normalised':True,'maximum_normal_tangent_dot':dot},
        'minimum_triangle_area_m2':float(areas.min()),
        'plan_projection':{'filled_rectangle':True,'verified_ground_face_area_m2':coverage,
                           'footprint_xz_m':[round(float(lo[0]),6),round(float(lo[2]),6),round(float(hi[0]),6),round(float(hi[2]),6)]},
        'lights':0,'cameras':0,'animations':0,'armatures':0,
        'light_mount':mount.get('translation') if mount else None}


def audit_source():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source/extraction_modules.blend'))
    assert len([o for o in bpy.data.objects if o.type=='MESH'])==8
    assert not any(o.type in ['LIGHT','CAMERA','ARMATURE'] for o in bpy.data.objects)
    result={}
    for obj in bpy.data.objects:
        if obj.type!='MESH':continue
        assert np.max(np.abs(np.asarray(obj.matrix_world)-np.eye(4)))<1e-6
        bm=bmesh.new();bm.from_mesh(obj.data)
        assert all(edge.is_manifold for edge in bm.edges),(obj.name,'open component')
        unseen=set(bm.verts);volumes=[]
        while unseen:
            first=next(iter(unseen));queue=[first];verts={first};unseen.remove(first)
            for vertex in queue:
                for edge in vertex.link_edges:
                    other=edge.other_vert(vertex)
                    if other in unseen:unseen.remove(other);verts.add(other);queue.append(other)
            faces={face for vertex in verts for face in vertex.link_faces};volume=0
            for face in faces:
                assert len(face.verts)==3
                a,b,c=[v.co for v in face.verts];volume+=a.dot(b.cross(c))/6
            assert volume>1e-10,(obj.name,'nonpositive closed component',volume)
            volumes.append(volume)
        result[obj.name]={'closed_components':len(volumes),'positive_component_volumes':True,
                          'minimum_component_volume_m3':min(volumes),
                          'combined_component_volume_m3_not_boolean_union':sum(volumes)}
        bm.free()
    return result


def main():
    result={'passed':False,'license':'CC0-1.0','godot_run':False,'modules':{},
            'limits':['No Godot invocation, import or game changes.',
                      'No physics, AI, gameplay, spawn, FPS, controller or traversal verification.',
                      'Joined mounted solids are closed components; internal mounting intersections are not Boolean-union/self-intersection audited.',
                      'Shared tiled role UVs are intentional, not a unique non-overlapping baking atlas.',
                      'Beacon is an unanimated optical assembly plus LightMount; runtime light/rotation require code later.']}
    for name in EXPECTED:
        entry=audit_glb(name);result['modules'][name]=entry;print('RAW GLB PASS',name,entry['triangles'],flush=True)
    source=audit_source()
    texture_sets={tuple(image['sha256'] for image in entry['textures']) for entry in result['modules'].values()}
    assert len(texture_sets)==1,'GLBs contain inconsistent atlas revisions'
    for name,entry in result['modules'].items():
        entry['source_topology']=source[name]
        (ROOT/'modules'/name/'validation.json').write_text(json.dumps(entry,indent=2)+'\n')
    spec=importlib.util.spec_from_file_location('layout_audit',ROOT/'build_layout.py');layout=importlib.util.module_from_spec(spec);spec.loader.exec_module(layout)
    items=json.loads((ROOT/'layout.json').read_text());features=json.loads((ROOT/'layout_features.json').read_text())
    measured={name:entry['plan_projection']['footprint_xz_m'] for name,entry in result['modules'].items()}
    check=layout.check_layout(items,features,measured);assert check['passed'],check['issues']
    result['layout']={k:v for k,v in check.items() if k not in ['nearest_neighbours','corridors','gate_widths']}
    result['layout']['report']='layout_validation.json'
    result['source_sha256']=hashlib.sha256((ROOT/'source/extraction_modules.blend').read_bytes()).hexdigest()
    if (ROOT/'source/arena_layout.blend').exists():
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'source/arena_layout.blend'))
        assert not any(o.type in ['LIGHT','CAMERA','ARMATURE'] for o in bpy.data.objects),'Source layout contains preview-only lights/cameras'
        result['layout_source']={'sha256':hashlib.sha256((ROOT/'source/arena_layout.blend').read_bytes()).hexdigest(),
                                 'lights':0,'cameras':0,'mesh_objects_including_two_preview_ground_boxes':len([o for o in bpy.data.objects if o.type=='MESH'])}
    result['passed']=True
    (ROOT/'validation.json').write_text(json.dumps(result,indent=2)+'\n')
    print('ARENA VALIDATION PASS',len(items),'instances',check['pair_count'],'pairs',flush=True)


if __name__=='__main__':main()
