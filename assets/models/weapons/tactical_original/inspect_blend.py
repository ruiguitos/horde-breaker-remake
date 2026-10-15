"""Geometric audit of source solids, using only Blender built-ins. CC0-1.0."""
import json
from pathlib import Path
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parent


def audit(objects):
    trees={};bounds={};samples={};self_hits=[]
    for obj in objects:
        verts=[v.co.copy() for v in obj.data.vertices]
        faces=[tuple(p.vertices) for p in obj.data.polygons]
        tree=BVHTree.FromPolygons(verts,faces,all_triangles=True,epsilon=0)
        trees[obj.name]=tree
        samples[obj.name]=verts+[sum((verts[j] for j in p.vertices),Vector())/len(p.vertices) for p in obj.data.polygons]
        bounds[obj.name]=([min(v[j] for v in verts) for j in range(3)],
                          [max(v[j] for v in verts) for j in range(3)])
        for a,b in tree.overlap(tree):
            if a>=b or set(faces[a])&set(faces[b]): continue
            self_hits.append([obj.name,a,b])
    hits=[]
    for i,a in enumerate(objects):
        for b in objects[i+1:]:
            alo,ahi=bounds[a.name];blo,bhi=bounds[b.name]
            if any(ahi[k]<blo[k]-1e-7 or bhi[k]<alo[k]-1e-7 for k in range(3)): continue
            pairs=trees[a.name].overlap(trees[b.name])
            depths=[]
            for source,target in [(a,b),(b,a)]:
                for p in samples[source.name]:
                    near,normal,index,distance=trees[target.name].find_nearest(p)
                    # Nearest normal alone misclassifies points beside a
                    # concave solid or a cap. Confirm containment with a ray.
                    if near is not None and distance>1e-5 and (p-near).dot(normal)<-1e-6 and inside(trees[target.name],p):
                        depths.append(distance)
            if depths:
                hits.append(dict(parts=[a.name,b.name],surface_crossings=len(pairs),
                                 maximum_sampled_depth_m=max(depths)))
    return dict(self_intersection_candidates=self_hits,
                interpenetration_samples=sorted(hits,key=lambda x:-x['maximum_sampled_depth_m']),
                method='BVH surface crossings; signed nearest-surface vertex and triangle-centre penetration samples. Mounts require explicit inspection; this is not exact intersection-volume proof.')


def inside(tree,point):
    direction=Vector((1,.371,.529)).normalized()
    origin=point.copy();crossings=0
    for _ in range(80):
        hit,normal,index,distance=tree.ray_cast(origin,direction)
        if hit is None: break
        crossings+=1;origin=hit+direction*1e-7
    return crossings%2==1


if __name__=='__main__':
    names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else ['assault_rifle','smg','machine_gun','shotgun','marksman']
    for name in names:
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'sources'/(name+'.blend')))
        result=audit([o for o in bpy.context.scene.objects if o.type=='MESH'])
        (ROOT/(name+'_intersections.json')).write_text(json.dumps(result,indent=2))
        print('AUDIT',name,'self candidates',len(result['self_intersection_candidates']),flush=True)
        for h in result['interpenetration_samples'][:15]: print(h,flush=True)
