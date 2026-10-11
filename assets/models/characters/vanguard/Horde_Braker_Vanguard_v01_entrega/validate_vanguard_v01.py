"""Independent GLB validation: rigid weights, exact Recruit rest, colors and size."""
from pathlib import Path
import json,hashlib,numpy as np
from gltf_inspect_utils import read_glb,accessor,world_matrices
ROOT=Path(__file__).resolve().parent;WORK=ROOT/'vanguard_v01_work'
def run():
    doc,binary=read_glb('Horde_Braker_Vanguard_v01_rigged.glb')
    recruit,_=read_glb('Horde_Braker_Recruit_v03_rigged.glb')
    report=json.loads((WORK/'rig_validation.json').read_text())
    reference=json.loads((WORK/'UAL_skeleton_reference.json').read_text())
    assert not doc.get('animations') and not doc.get('textures') and not doc.get('images')
    assert len(doc['skins'])==1 and len(doc['skins'][0]['joints'])==53
    skin=doc['skins'][0];joints=skin['joints'];jointset=set(joints);worlds,parents=world_matrices(doc)
    hierarchy={doc['nodes'][j]['name']:doc['nodes'][parents[j]]['name'] if parents.get(j) in jointset else '' for j in joints}
    assert hierarchy=={b['name']:b['parent'] for b in reference['bones']}
    rworlds,_=world_matrices(recruit);rrests={recruit['nodes'][j]['name']:rworlds[j] for j in recruit['skins'][0]['joints']}
    rest_error=max(float(np.max(np.abs(worlds[j]-rrests[doc['nodes'][j]['name']]))) for j in joints)
    assert rest_error<1e-6
    inverse=accessor(doc,binary,skin['inverseBindMatrices']).reshape(-1,4,4).transpose(0,2,1)
    mapping={entry['piece']:entry['bone'] for entry in report['mapping']};seen=[];triangles=vertices=0;positions=[];bind_error=0.
    for index,node in enumerate(doc['nodes']):
        if 'mesh' not in node:continue
        name=node['name'];assert name in mapping and node['skin']==0;seen.append(name)
        for primitive in doc['meshes'][node['mesh']]['primitives']:
            attrs=primitive['attributes'];v=accessor(doc,binary,attrs['POSITION']);w=accessor(doc,binary,attrs['WEIGHTS_0']);j=accessor(doc,binary,attrs['JOINTS_0'])
            assert np.allclose(w[:,0],1,atol=1e-7) and np.all(w[:,1:]==0)
            used=np.unique(j[:,0]);assert len(used)==1
            b=int(used[0]);assert doc['nodes'][joints[b]]['name']==mapping[name]
            transform=worlds[joints[b]]@inverse[b];bind_error=max(bind_error,float(np.max(np.abs(transform-np.eye(4)))))
            positions.append((transform@np.c_[v,np.ones(len(v))].T).T[:,:3]);vertices+=len(v)
            indices=accessor(doc,binary,primitive['indices']).ravel().astype(int)
            assert primitive.get('mode',4)==4 and len(indices)%3==0 and indices.max()<len(v)
            t=v[indices.reshape(-1,3)];areas=np.linalg.norm(np.cross(t[:,1]-t[:,0],t[:,2]-t[:,0]),axis=1)/2
            assert np.all(areas>1e-12),name;triangles+=len(t)
    assert set(seen)==set(mapping) and len(seen)==104 and triangles==report['triangles'] and triangles<6000
    assert bind_error<1e-5
    allverts=np.concatenate(positions);low=allverts.min(axis=0);high=allverts.max(axis=0)
    assert abs(low[1])<1e-5 and abs(high[1]-2.025)<1e-5
    assert len(doc['materials'])==35
    material_colors={m['name']:m['pbrMetallicRoughness']['baseColorFactor'] for m in doc['materials']}
    def linear(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
    for name,hexcolor in report['palette_srgb_hex'].items():
        expected=[linear(int(hexcolor[i:i+2],16)/255) for i in (0,2,4)]+[1]
        assert np.allclose(material_colors['VG_'+name],expected,atol=1e-6)
    source_colors={m['name']:m['pbrMetallicRoughness']['baseColorFactor'] for m in recruit['materials']}
    for name in ['skin','skin_shadow','nose','eyes','brow','mouth','hair','metal','metal_dark','metal_light']:
        assert np.allclose(source_colors[name],material_colors['VG_'+name],atol=1e-7)
    muzzle=next(i for i,n in enumerate(doc['nodes']) if n.get('name')=='Muzzle')
    assert parents[muzzle] in jointset and doc['nodes'][parents[muzzle]]['name']=='DEF-hand.R'
    direction=-worlds[muzzle][:3,2];direction/=np.linalg.norm(direction)
    assert np.dot(direction,[0,0,-1])>.99999
    assert all(hashlib.sha256((ROOT/name).read_bytes()).hexdigest()==digest for name,digest in report['original_sha256'].items())
    result={'passed':True,'joints':53,'pieces':104,'triangles':triangles,'materials':35,'render_vertices':vertices,'animations':0,'textures':0,'rigid_one_weight_per_piece':True,'height_m':float(high[1]-low[1]),'bounds_min_godot_m':low.tolist(),'bounds_max_godot_m':high.tolist(),'max_bind_matrix_error':bind_error,'maximum_rest_difference_from_recruit':rest_error,'olive_palette_verified':True,'skin_and_weapon_colors_preserved':True,'original_hashes_unchanged':True,'muzzle_local_forward':'-Z','muzzle_world_forward':direction.tolist()}
    (WORK/'glb_validation.json').write_text(json.dumps(result,indent=2))
    print(json.dumps(result,indent=2))
if __name__=='__main__':run()
