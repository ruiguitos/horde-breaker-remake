"""Independent binary glTF validation. Requires numpy; writes a JSON report."""
import json, struct, os, hashlib, numpy as np
ROOT=os.path.dirname(os.path.abspath(__file__))
def read_glb(name):
    data=open(os.path.join(ROOT,name),'rb').read()
    magic,version,total=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and total==len(data)
    pos=12;doc=None;binary=None
    while pos<len(data):
        length,kind=struct.unpack_from('<II',data,pos);pos+=8
        payload=data[pos:pos+length];pos+=length
        if kind==0x4e4f534a:doc=json.loads(payload)
        if kind==0x004e4942:binary=payload
    return doc,binary
def accessor(doc,binary,index):
    a=doc['accessors'][index];view=doc['bufferViews'][a['bufferView']]
    dtype={5120:'i1',5121:'u1',5122:'<i2',5123:'<u2',5125:'<u4',5126:'<f4'}[a['componentType']]
    components={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}[a['type']]
    start=view.get('byteOffset',0)+a.get('byteOffset',0)
    stride=view.get('byteStride',np.dtype(dtype).itemsize*components)
    array=np.ndarray((a['count'],components),dtype=dtype,buffer=binary,offset=start,strides=(stride,np.dtype(dtype).itemsize)).copy()
    assert np.isfinite(array).all()
    return array
def matrix(node):
    if 'matrix' in node:return np.array(node['matrix']).reshape(4,4).T
    x,y,z,w=node.get('rotation',[0,0,0,1])
    r=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
                [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
                [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])
    m=np.eye(4);m[:3,:3]=r@np.diag(node.get('scale',[1,1,1]));m[:3,3]=node.get('translation',[0,0,0]);return m
def world_matrices(doc):
    parents={c:i for i,n in enumerate(doc['nodes']) for c in n.get('children',[])}
    cache={}
    def world(i):
        if i not in cache:cache[i]=(world(parents[i]) if i in parents else np.eye(4))@matrix(doc['nodes'][i])
        return cache[i]
    return [world(i) for i in range(len(doc['nodes']))],parents
def run():
    target,binary=read_glb('Horde_Braker_Recruit_v03_rigged.glb')
    source,_=read_glb('Horde_Braker_Recruit_v02_escala_jogo.glb')
    report=json.load(open(os.path.join(ROOT,'recruit_v03_work','rig_validation.json')))
    reference=json.load(open(os.path.join(ROOT,'recruit_v03_work','UAL_skeleton_reference.json')))
    assert not target.get('animations') and not target.get('images') and not target.get('textures')
    assert len(target['skins'])==1 and len(target['skins'][0]['joints'])==53
    skin=target['skins'][0];joints=skin['joints'];joint_set=set(joints)
    worlds,parents=world_matrices(target)
    actual={target['nodes'][j]['name']:target['nodes'][parents[j]]['name'] if parents.get(j) in joint_set else '' for j in joints}
    assert actual=={b['name']:b['parent'] for b in reference['bones']}
    expected={entry['piece']:entry['bone'] for entry in report['mapping']}
    inverse_binds=accessor(target,binary,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    bounds=[];triangles=0;render_vertices=0;piece_names=[];max_bind_error=0.
    for i,node in enumerate(target['nodes']):
        if 'mesh' not in node:continue
        name=node['name'];piece_names.append(name);assert name in expected and node['skin']==0
        for primitive in target['meshes'][node['mesh']]['primitives']:
            attrs=primitive['attributes'];v=accessor(target,binary,attrs['POSITION']);weights=accessor(target,binary,attrs['WEIGHTS_0']);indices=accessor(target,binary,attrs['JOINTS_0'])
            assert np.allclose(weights[:,0],1,atol=1e-7) and np.all(weights[:,1:]==0)
            unique=np.unique(indices[:,0]);assert len(unique)==1
            index=int(unique[0]);assert target['nodes'][joints[index]]['name']==expected[name]
            bone_matrix=worlds[joints[index]]@inverse_binds[index]
            # For a skinned node glTF ignores the node's world transform. The
            # builder bakes vertices in asset space, so world bind must be identity.
            max_bind_error=max(max_bind_error,float(np.max(np.abs(bone_matrix-np.eye(4)))))
            transformed=(bone_matrix@np.c_[v,np.ones(len(v))].T).T[:,:3];bounds.append(transformed)
            render_vertices+=len(v)
            assert primitive.get('mode',4)==4
            tri=len(accessor(target,binary,primitive['indices']))//3 if 'indices' in primitive else len(v)//3
            triangles+=tri
    assert len(piece_names)==104 and set(piece_names)==set(expected) and triangles==4000
    assert max_bind_error<1e-5
    all_vertices=np.concatenate(bounds);lo=all_vertices.min(axis=0);hi=all_vertices.max(axis=0)
    assert abs(lo[1])<1e-5 and abs(hi[1]-2.025)<1e-5
    palette=lambda doc:{m['name']:m.get('pbrMetallicRoughness',{}) for m in doc['materials']}
    assert palette(target)==palette(source) and len(target['materials'])==35
    assert all(hashlib.sha256(open(os.path.join(ROOT,n),'rb').read()).hexdigest()==sha for n,sha in report['original_sha256'].items())
    muzzle_index=next(i for i,n in enumerate(target['nodes']) if n.get('name')=='Muzzle')
    assert parents[muzzle_index] in joint_set and target['nodes'][parents[muzzle_index]]['name']=='DEF-hand.R'
    barrel=-worlds[muzzle_index][:3,2];barrel/=np.linalg.norm(barrel)
    assert np.dot(barrel,[0,0,-1])>.99999
    result={'passed':True,'joints':53,'pieces':104,'triangles':triangles,'materials':35,'render_vertices':render_vertices,'animations':0,'textures':0,'single_weight_per_piece':True,'source_material_properties_exact':True,'source_hashes_unchanged':True,'bounds_min_godot_m':lo.tolist(),'bounds_max_godot_m':hi.tolist(),'height_m':float(hi[1]-lo[1]),'maximum_bind_matrix_error':max_bind_error,'muzzle_forward_world':barrel.tolist(),'muzzle_forward_local_axis':'-Z','muzzle_position_world_m':worlds[muzzle_index][:3,3].tolist()}
    json.dump(result,open(os.path.join(ROOT,'recruit_v03_work','glb_validation.json'),'w'),indent=2)
    print(json.dumps(result,indent=2))
if __name__=='__main__':run()
