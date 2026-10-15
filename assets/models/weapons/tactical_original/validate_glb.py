"""Independent GLB contract checks, Python standard library only. CC0-1.0."""
import json
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parent
TARGETS=dict(assault_rifle=.96,smg=.74,machine_gun=1.04,shotgun=1.04,marksman=1.12)


def read_glb(path):
    data=Path(path).read_bytes()
    magic,version,total=struct.unpack_from('<III',data)
    assert magic==0x46546c67 and version==2 and total==len(data)
    pos=12;doc=None;binary=None
    while pos<len(data):
        size,kind=struct.unpack_from('<II',data,pos);pos+=8
        payload=data[pos:pos+size];pos+=size
        if kind==0x4e4f534a: doc=json.loads(payload)
        if kind==0x004e4942: binary=payload
    assert doc is not None and binary is not None
    return doc,binary


def accessor(doc,binary,index):
    a=doc['accessors'][index];v=doc['bufferViews'][a['bufferView']]
    count={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    fmt={5121:'B',5123:'H',5125:'I',5126:'f'}[a['componentType']]
    pack=struct.Struct('<'+fmt*count)
    stride=v.get('byteStride',pack.size)
    start=v.get('byteOffset',0)+a.get('byteOffset',0)
    values=[pack.unpack_from(binary,start+i*stride) for i in range(a['count'])]
    assert all(math.isfinite(c) for p in values for c in p)
    return values


def cross2(a,b,c): return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])


def triangle_overlap_area(a,b):
    polygon=list(a)
    if cross2(*b)<0: b=(b[0],b[2],b[1])
    for j in range(3):
        edge0,edge1=b[j],b[(j+1)%3]
        output=[]
        if not polygon: return 0
        prev=polygon[-1];dp=cross2(edge0,edge1,prev)
        for curr in polygon:
            dc=cross2(edge0,edge1,curr)
            if (dc>=0)!=(dp>=0):
                t=dp/(dp-dc)
                output.append((prev[0]+t*(curr[0]-prev[0]),prev[1]+t*(curr[1]-prev[1])))
            if dc>=0: output.append(curr)
            prev,dp=curr,dc
        polygon=output
    return abs(sum(polygon[i][0]*polygon[(i+1)%len(polygon)][1]-
                   polygon[(i+1)%len(polygon)][0]*polygon[i][1] for i in range(len(polygon))))*.5


def uv_check(triangles):
    # Spatial broadphase then exact convex clipping. Shared UV edges have zero
    # intersection area. Float32 roundoff below 1e-10 UV² is ignored.
    cells={};tested=set();overlaps=[];minimum=1;maximum=0;zero=0
    for i,tri in enumerate(triangles):
        for uv in tri:
            minimum=min(minimum,*uv);maximum=max(maximum,*uv)
        if abs(cross2(*tri))<1e-13: zero+=1
        x0,x1=int(min(p[0] for p in tri)*96),int(max(p[0] for p in tri)*96)
        y0,y1=int(min(p[1] for p in tri)*96),int(max(p[1] for p in tri)*96)
        for x in range(x0,x1+1):
            for y in range(y0,y1+1):
                cell=cells.setdefault((x,y),[])
                for other in cell:
                    pair=(other,i)
                    if pair in tested: continue
                    tested.add(pair)
                    area=triangle_overlap_area(triangles[other],tri)
                    if area>1e-10: overlaps.append(dict(triangles=pair,area_uv2=area))
                cell.append(i)
    return dict(passed=minimum>=-1e-6 and maximum<=1+1e-6 and not overlaps and zero==0,
                layers=1,min=minimum,max=maximum,overlapping_triangle_pairs=len(overlaps),
                degenerate_uv_triangles=zero,overlap_area_tolerance_uv2=1e-10,
                overlap_examples=overlaps[:8])


def validate(name):
    doc,bin=read_glb(ROOT/(name+'.glb'))
    assert len(doc['scenes'])==1 and doc.get('scene',0)==0
    assert not any(doc.get(k) for k in ['cameras','skins','animations','images','textures'])
    assert not doc.get('extensions',{}).get('KHR_lights_punctual')
    roots=doc['scenes'][0]['nodes'];assert len(roots)==1
    root=doc['nodes'][roots[0]];assert root['name']==name
    identities=[]
    for n in doc['nodes']:
        if n['name']=='Muzzle': continue
        identities.append(n.get('translation',[0,0,0])==[0,0,0] and
                          n.get('rotation',[0,0,0,1])==[0,0,0,1] and
                          n.get('scale',[1,1,1])==[1,1,1] and 'matrix' not in n)
    assert all(identities)
    muzzle=[n for n in doc['nodes'] if n['name']=='Muzzle'];assert len(muzzle)==1
    muzzle=muzzle[0]
    assert muzzle.get('rotation',[0,0,0,1])==[0,0,0,1]
    assert muzzle.get('scale',[1,1,1])==[1,1,1]
    triangles=0;positions=[];uvtris=[];densities=[];ndev=0;tdev=0;orthodev=0;mindeg=1
    for m in doc['meshes']:
        for p in m['primitives']:
            assert p.get('mode',4)==4
            attrs=p['attributes']
            assert all(k in attrs for k in ['POSITION','NORMAL','TANGENT','TEXCOORD_0'])
            assert 'TEXCOORD_1' not in attrs
            pos=accessor(doc,bin,attrs['POSITION']);positions.extend(pos)
            uv=accessor(doc,bin,attrs['TEXCOORD_0'])
            normals=accessor(doc,bin,attrs['NORMAL']);tangents=accessor(doc,bin,attrs['TANGENT'])
            for n,t in zip(normals,tangents):
                assert sum(v*v for v in t[:3])>.9,(name,m.get('name'),'invalid tangent',t)
                ndev=max(ndev,abs(math.sqrt(sum(v*v for v in n))-1))
                tdev=max(tdev,abs(math.sqrt(sum(v*v for v in t[:3]))-1))
                orthodev=max(orthodev,abs(sum(n[j]*t[j] for j in range(3))))
                assert abs(abs(t[3])-1)<1e-6
            idx=[v[0] for v in accessor(doc,bin,p['indices'])]
            assert len(idx)%3==0;triangles+=len(idx)//3
            for i in range(0,len(idx),3):
                ids=idx[i:i+3];a,b,c=[pos[j] for j in ids]
                ab=[b[k]-a[k] for k in range(3)];ac=[c[k]-a[k] for k in range(3)]
                cr=[ab[1]*ac[2]-ab[2]*ac[1],ab[2]*ac[0]-ab[0]*ac[2],ab[0]*ac[1]-ab[1]*ac[0]]
                area=.5*math.sqrt(sum(v*v for v in cr));mindeg=min(mindeg,area)
                u=[uv[j] for j in ids];uvtris.append(u)
                if area>1e-12: densities.append(math.sqrt(abs(cross2(*u))*.5/area))
    lo=[min(v[j] for v in positions) for j in range(3)]
    hi=[max(v[j] for v in positions) for j in range(3)]
    length=hi[2]-lo[2]
    assert abs(length-TARGETS[name])<=.02,(name,length)
    assert 4000<=triangles<=9000,(name,triangles)
    assert mindeg>1e-12,(name,'degenerate exported triangles',mindeg)
    assert max(ndev,tdev,orthodev)<5e-4,(name,ndev,tdev,orthodev)
    assert abs(muzzle['translation'][2]-lo[2])<.00001
    uv=uv_check(uvtris)
    assert uv['passed'],(name,uv)
    densities.sort()
    p05=densities[int(len(densities)*.05)];p95=densities[int(len(densities)*.95)]
    materials=[m['name'] for m in doc['materials']]
    assert len(materials)==len(set(materials)) and set(materials)<=set(['gunmetal','steel','polymer','wood','rust','bore'])
    for m in doc['materials']:
        pbr=m['pbrMetallicRoughness']
        assert all(k in pbr for k in ['baseColorFactor','metallicFactor','roughnessFactor'])
    return dict(length_m=length,target_length_m=TARGETS[name],triangles=triangles,
        mesh_count=len(doc['meshes']),material_names=materials,
        muzzle_position_godot_m=muzzle['translation'],muzzle_forward_local=[0,0,-1],
        bounds_min_godot_m=lo,bounds_max_godot_m=hi,
        origin_check=dict(passed=True,grip_point_godot_m=[0,0,0],all_mesh_and_root_transforms_identity=True,
                          definition='Top of the right-hand pistol grip / shotgun wrist; artist placement'),
        uv_check={**uv,'texel_density_p95_over_p05':p95/p05,
                  'texel_density_min':densities[0],'texel_density_max':densities[-1]},
        normals_and_tangents_check=dict(passed=True,all_primitives_have_normals_and_tangents=True,
            max_normal_length_error=ndev,max_tangent_length_error=tdev,max_normal_tangent_dot=orthodev),
        minimum_triangle_area_m2=mindeg,single_scene=True,embedded_textures=0,
        cameras=0,lights=0,armatures=0,animations=0,
        material_pbr={m['name']:m['pbrMetallicRoughness'] for m in doc['materials']})


def main():
    previous=ROOT/'validation.json'
    report=json.loads(previous.read_text(encoding='utf-8')) if previous.exists() else {'weapons':{}}
    report['validator']='Independent GLB accessors, float32 values; standard library only'
    for name in TARGETS:
        report['weapons'].setdefault(name,{}).update(validate(name))
        print(name,json.dumps({k:report['weapons'][name][k] for k in ['length_m','triangles','mesh_count','uv_check']}),flush=True)
    report['export_contract_passed']=True
    report['geometry_validation_limits']='Grip placement is an artist landmark. BVH and sampled penetration checks do not constitute an exact volumetric-intersection proof.'
    (ROOT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')


if __name__=='__main__': main()
