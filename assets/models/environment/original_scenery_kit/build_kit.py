"""Original CC0 scenery. Blender 5.2, metres, no external assets.
SPDX-License-Identifier: CC0-1.0
blender --background --factory-startup --python-exit-code 1 --python build_kit.py
Blender Z up / +Y forward -> glTF Y up / -Z forward.
Facade geometry faces Blender -Y -> glTF +Z, mounting plane at zero.
"""
import argparse
import json
import math
from pathlib import Path
import random
import struct
import sys

import bpy
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
ROLES=['wood','bark','rope','paint','plaster','cloth','iron','glass']
PARTS=[]
MAT=None
CATALOG={}
RNG=random.Random(242026)


def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]


def image(name,rgb,color=False):
    img=bpy.data.images.new(name,width=1024,height=1024,alpha=False)
    img.colorspace_settings.name='sRGB' if color else 'Non-Color'
    rgba=np.ones((1024,1024,4),np.float32)
    if color:rgb=np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    rgba[:,:,:3]=np.clip(rgb,0,1);img.pixels.foreach_set(rgba.ravel())
    img.filepath_raw=str(ROOT/'textures'/(name+'.png'));img.file_format='PNG';img.save();img.pack()
    return img


def material():
    global MAT
    rgb=np.zeros((1024,1024,3));rough=np.ones((1024,1024))*.8
    metal=np.zeros((1024,1024));height=np.zeros((1024,1024));rng=np.random.default_rng(242026)
    palette=[(.40,.33,.24),(.25,.24,.20),(.48,.43,.32),(.20,.36,.33),
             (.72,.68,.57),(.66,.57,.42),(.16,.15,.13),(.20,.28,.27)]
    for index,role in enumerate(ROLES):
        y0=(index//4)*512;x0=(index%4)*256
        y,x=np.mgrid[0:512,0:256]/np.array([512,256])[:,None,None]
        # Longitudinal grain, irregular cracks, low entropy fine surface wear.
        flow=x+.015*np.sin(y*22)+.007*np.sin(y*53+x*9)
        grain=np.sin(flow*math.tau*37)+.45*np.sin(flow*math.tau*81)
        noise=rng.integers(-2,3,(512,256))/2
        h=.009*grain;r=.84+.015*noise
        stain=.035*np.sin(x*19+y*7)*np.sin(y*13-x*4)
        c=np.array(palette[index])[None,None,:]*(1+stain[:,:,None])
        c=np.broadcast_to(c,(512,256,3)).copy()
        if role in ['wood','bark','paint']:
            cracks=(np.sin(flow*math.tau*29)>.985)&(np.sin(y*31+x*11)>.05)
            knots=np.exp(-((x-.35)**2/.008+(y-.36)**2/.0015))
            c*=1+.055*grain[:,:,None]-.37*cracks[:,:,None]-.19*knots[:,:,None]
            h+=-.045*cracks+.04*knots
            if role=='bark':h*=2;c*=1-.10*np.cos(flow*math.tau*11)[:,:,None]
            if role=='paint':
                flake=(np.sin(x*79+np.sin(y*39))*np.sin(y*83+x*15)>.70)
                c=np.where(flake[:,:,None],np.array([.42,.36,.27]),c)
                h+=flake*.015
        elif role=='rope':
            spiral=np.sin((x*10-y*24)*math.tau)
            c*=1+.12*spiral[:,:,None];h=.05*spiral;r[:]=.94
        elif role=='plaster':
            h=.018*noise;c*=1+.025*noise[:,:,None];r[:]=.96
        elif role=='cloth':
            stripe=((x*7)%1<.38)
            c=np.where(stripe[:,:,None],np.array([.34,.23,.19]),c)
            weave=np.sin(x*math.tau*120)*np.sin(y*math.tau*190)
            c*=1+.035*weave[:,:,None];h=.013*weave;r[:]=.96
        elif role=='iron':
            rust=np.maximum(0,np.sin(x*27+y*13)*np.sin(y*31-x*8))
            c=c*(1-rust[:,:,None]*.7)+np.array([.26,.11,.045])*rust[:,:,None]*.7
            metal[y0:y0+512,x0:x0+256]=.82*(1-rust)
            h=.02*rust;r=.60+.20*rust
        elif role=='glass':r[:]=.33;h[:]=.001
        rgb[y0:y0+512,x0:x0+256]=np.clip(c,0,1)
        rough[y0:y0+512,x0:x0+256]=r;height[y0:y0+512,x0:x0+256]=h
    dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.65
    dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.65
    normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=2);normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    imgs={'albedo':image('scenery_albedo',rgb,True),'normal':image('scenery_normal',normal*.5+.5),
          'orm':image('scenery_orm',np.stack((np.ones_like(rough),rough,metal),axis=2))}
    MAT=bpy.data.materials.new('Weathered_scenery_PBR_1K');MAT.use_nodes=True
    nodes,links=MAT.node_tree.nodes,MAT.node_tree.links;bsdf=nodes.get('Principled BSDF')
    for role,img in imgs.items():
        tex=nodes.new('ShaderNodeTexImage');tex.image=img
        if role=='albedo':links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        elif role=='normal':
            n=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],bsdf.inputs['Normal'])
        else:
            sep=nodes.new('ShaderNodeSeparateColor');links.new(tex.outputs['Color'],sep.inputs['Color'])
            links.new(sep.outputs['Green'],bsdf.inputs['Roughness']);links.new(sep.outputs['Blue'],bsdf.inputs['Metallic'])


def finish(obj,role,uv=None,smooth=False):
    select([obj]);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    data=obj.data;layer=data.uv_layers.active or data.uv_layers.new(name='UVMap')
    points=np.array([v.co for v in data.vertices]);lo=points.min(axis=0);span=np.maximum(points.max(axis=0)-lo,1e-6)
    longest=int(np.argmax(span));index=ROLES.index(role);ox=(index%4)/4;oy=(index//4)/2
    for face in data.polygons:
        normal=np.abs(np.array(face.normal));axis=int(np.argmax(normal))
        axes=[a for a in range(3) if a!=axis]
        vertical=longest if longest in axes else axes[1];horizontal=next(a for a in axes if a!=vertical)
        for loop in face.loop_indices:
            i=data.loops[loop].vertex_index
            u,v=uv[i] if uv else ((points[i,horizontal]-lo[horizontal])/span[horizontal],(points[i,vertical]-lo[vertical])/span[vertical])
            layer.data[loop].uv=(ox+.25*(.018+.964*u),oy+.5*(.018+.964*v))
        # A thin solid's side walls need their own UVs: reusing the top/bottom
        # UVs collapses the side island and makes the normal-map tangent invalid.
        face_uv=[layer.data[i].uv.copy() for i in face.loop_indices]
        signed_area=sum(a.x*b.y-b.x*a.y for a,b in zip(face_uv,face_uv[1:]+face_uv[:1]))
        if abs(signed_area)<1e-10:
            for loop in face.loop_indices:
                p=points[data.loops[loop].vertex_index]
                u=(p[horizontal]-lo[horizontal])/span[horizontal];v=(p[vertical]-lo[vertical])/span[vertical]
                layer.data[loop].uv=(ox+.25*(.018+.964*u),oy+.5*(.018+.964*v))
        face.use_smooth=smooth
    data.materials.clear();data.materials.append(MAT);PARTS.append(obj)
    return obj


def mesh(name,vertices,faces,role,uv=None,smooth=False):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    return finish(obj,role,uv,smooth)


def box(name,centre,size,role,bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=centre);o=bpy.context.object;o.name=name;o.scale=size
    select([o]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new('Worn edges','BEVEL');mod.width=bevel;mod.segments=1;bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,role)


def beam(name,a,b,width,depth,role):
    a,b=Vector(a),Vector(b);o=box(name,(a+b)/2,(width,depth,(b-a).length),role)
    # Geometry is already in world coordinates: rotate around the beam midpoint.
    q=Vector((0,0,1)).rotation_difference(b-a);centre=(a+b)/2
    for v in o.data.vertices:v.co=centre+q@(v.co-centre)
    return o


def tube(name,points,radii,role,sides=8):
    points=[Vector(p) for p in points];vertices=[];uv=[]
    for j,p in enumerate(points):
        direction=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
        side=direction.cross(Vector((0,1,0)))
        if side.length<.01:side=direction.cross(Vector((1,0,0)))
        side.normalize();up=direction.cross(side).normalized()
        r=radii[j] if isinstance(radii,(list,tuple)) else radii
        for k in range(sides):
            angle=math.tau*k/sides
            vertices.append(p+side*(r*math.cos(angle))+up*(r*math.sin(angle)))
            uv.append((k/sides,j/(len(points)-1)))
    faces=[tuple(range(sides-1,-1,-1))]
    faces += [(j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k)
              for j in range(len(points)-1) for k in range(sides)]
    faces.append(tuple((len(points)-1)*sides+k for k in range(sides)))
    return mesh(name,vertices,faces,role,uv,True)


def clear_parts():
    PARTS.clear()


def register(name,kit,notes):
    objects=list(PARTS);points=[v.co for o in objects for v in o.data.vertices]
    if kit=='beach_horror':
        lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
        offset=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z))
    else:
        # Trim small beam end overhangs flush to the wall, preserving the plates
        # as the mounting surface rather than shifting the whole piece outward.
        for vertex in points:vertex.y=min(0.,vertex.y)
        rear=max(v.y for v in points);contact=[v for v in points if abs(v.y-rear)<1e-5]
        offset=Vector(((min(v.x for v in contact)+max(v.x for v in contact))/2,rear,
                       (min(v.z for v in contact)+max(v.z for v in contact))/2))
    for obj in objects:
        for v in obj.data.vertices:v.co-=offset
        select([obj]);mod=obj.modifiers.new('Export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.data.validate(clean_customdata=False);obj.data.update();obj.hide_render=True
    select(objects);bpy.ops.object.join()
    objects=[bpy.context.object];objects[0].name=name
    count=sum(len(o.data.polygons) for o in objects);limit=2500 if kit=='beach_horror' else 800
    assert count<=limit,(name,count,limit)
    CATALOG[name]={'objects':objects,'kit':kit,'notes':notes,'triangles':count,'limit':limit}
    print('MODEL',name,count,limit,flush=True)


def beach():
    clear_parts()
    trunk=[(0,0,0),(.10,.04,.65),(-.06,.08,1.4),(.10,0,2.15),(.28,.04,3.0),(.22,.10,4.25)]
    tube('Twisted_trunk',trunk,[.29,.235,.19,.145,.08,.012],'bark',10)
    branches=[([(-.03,.06,1.35),(-.65,.09,1.95),(-1.12,.18,2.78),(-1.26,.30,3.22)],[.15,.10,.052,.008]),
              ([(.10,0,2.1),(.72,-.13,2.53),(1.13,-.20,3.13),(1.28,-.31,3.63)],[.12,.08,.035,.006]),
              ([(.27,.04,2.95),(.08,.65,3.33),(-.18,.94,3.84)],[.075,.04,.006]),
              ([(-.67,.1,1.95),(-.98,-.36,2.22),(-1.34,-.55,2.50)],[.065,.035,.005]),
              ([(.73,-.13,2.53),(1.16,.27,2.73),(1.66,.40,2.86)],[.06,.03,.006]),
              ([(-1.10,.18,2.78),(-.88,.46,3.03),(-.73,.55,3.46)],[.04,.026,.004]),
              ([(.12,.02,2.35),(-.10,-.65,2.60),(-.22,-.85,2.98)],[.075,.04,.006])]
    for points,radii in branches:tube('Bare_branch',points,radii,'bark',7)
    for i in range(5):
        a=math.tau*i/5;tube('Exposed_root',[(0,0,.36),(.35*math.cos(a),.35*math.sin(a),.10),(.64*math.cos(a),.64*math.sin(a),.015)],[.13,.09,.015],'wood',6)
    register('dead_tree','beach_horror','Bare salt-killed tree, exposed roots, snapped tapering limbs. Target height 3-5 m.')

    clear_parts()
    tube('Bleached_drift_log',[(-1.4,0,.17),(-.92,.06,.18),(-.35,-.02,.21),(.30,.03,.19),(.9,.14,.15),(1.35,.2,.12)],
         [.10,.18,.21,.18,.12,.055],'wood',12)
    for points in [[(-.70,.04,.19),(-.55,.40,.28),(-.34,.65,.27)],[(.30,.03,.22),(.45,-.22,.46),(.39,-.35,.59)],[(1.08,.18,.12),(1.38,.35,.19),(1.58,.45,.15)]]:
        tube('Broken_drift_branch',points,[.09,.055,.009],'wood',7)
    for j in range(4):tube('Split_grain',[(-1.35,.015+j*.025,.19),(-1.55,-.01+j*.02,.12)],[.025,.004],'wood',4)
    register('driftwood','beach_horror','Bleached driftwood with split ends and worn branch stubs.')

    clear_parts()
    def section(y,t):
        w=.13+.86*max(0,1-(abs(y)/2.65)**2)**.65
        return Vector((w*(t/.9),y,.16+.85*(abs(t)/.9)**1.65+.20*(abs(y)/2.65)**3))
    ys=[-2.6,-1.95,-1.30,-.65,0,.65,1.3,1.95,2.6]
    tube('Keel',[(0,y,.12+.20*(abs(y)/2.65)**3) for y in ys],.065,'wood',6)
    for j,y in enumerate(ys):
        rib=[section(y,t) for t in [-.90,-.62,-.32,0,.32,.62,.90]]
        tube('Exposed_rib',rib,.038,'wood',5)
    for side in [-1,1]:
        for row in range(4):
            a,b=side*(.18+row*.18),side*(.18+(row+1)*.18-.025)
            for j in range(len(ys)-1):
                if (side==1 and row in [1,2] and j in [5,6]) or (side==-1 and row==3 and j==1):continue
                v=[section(y,t) for y,t in [(ys[j]+.012,a),(ys[j+1]-.012,a),(ys[j+1]-.012,b),(ys[j]+.012,b)]]
                outward=Vector((side*.018,0,0));v+= [p+outward for p in v]
                faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
                if side==-1:faces=[tuple(reversed(f)) for f in faces]
                mesh('Rotten_hull_plank',v,faces,'wood')
        tube('Gunwale',[section(y,side*.91) for y in ys],.04,'bark',6)
    for y in [-1.25,.10,1.30]:
        w=section(y,.78).x
        box('Broken_thwart',(0,y,.66+.10*abs(y)),(w*1.6,.20,.07),'wood',.008)
    for x in [-.28,-.10,.10,.28]:beam('Bilge_board',(x,-1.9,.25),(x,1.9,.25),.13,.045,'wood')
    register('stranded_hull','beach_horror','Open 5.2 m wooden hull, missing planks, visible ribs and rotten thwarts. No intact deck or hidden filler mesh.')

    clear_parts()
    tube('Leaning_pile',[(0,0,0),(.04,.02,.55),(.15,.03,1.18),(.28,.06,1.83)],[.16,.155,.135,.12],'bark',10)
    for z in [.50,.58,.66]:
        points=[(.05+.175*math.cos(math.tau*i/16),.02+.175*math.sin(math.tau*i/16),z+.012*math.sin(math.tau*i/16)) for i in range(17)]
        tube('Old_rope_turn',points,.021,'rope',5)
    for i in range(4):tube('Splintered_crown',[(.27+.06*math.cos(i*1.5),.06+.06*math.sin(i*1.5),1.76),(.30+.09*math.cos(i*1.5),.08+.08*math.sin(i*1.5),1.96+i*.025)],[.035,.003],'wood',5)
    register('crooked_dock_post','beach_horror','Leaning timber mooring pile with frayed crown and rope wraps.')

    clear_parts()
    def net(u,v):
        return Vector((2.4*(u-.5),1.75*(v-.5),.035+.21*math.exp(-((u-.82)/.16)**2)*(.55+.45*math.sin(v*7)**2)+.025*math.sin(u*12+v*8)**2))
    for i in range(10):tube('Net_warp',[net(i/9,j/12) for j in range(13)],.008,'rope',3)
    for i in range(8):tube('Net_weft',[net(j/12,i/7) for j in range(13)],.008,'rope',3)
    for k in [0,1]:
        tube('Net_edge',[net(k,j/12) for j in range(13)],.016,'rope',4)
        tube('Net_edge',[net(j/12,k) for j in range(13)],.016,'rope',4)
    for u in [.12,.38,.64,.90]:
        p=net(u,1);tube('Wooden_float',[p+Vector((-.05,0,.01)),p+Vector((.05,0,.01))],.034,'wood',7)
    register('fallen_fishing_net','beach_horror','Loose folded rope net with actual open cells, perimeter rope and four wooden floats; no alpha cutout.')


def facade():
    clear_parts()
    for x in [-.55,.55]:box('Window_jamb',(x,-.075,0),(.12,.15,1.48),'paint',.012)
    for z in [-.70,.70]:box('Window_lintel',(0,-.075,z),(1.22,.15,.12),'paint',.012)
    box('Window_sill',(0,-.13,-.78),(1.40,.26,.10),'plaster',.012)
    box('Clouded_glazing',(0,-.045,0),(1.0,.035,1.30),'glass')
    box('Central_mullion',(0,-.095,0),(.045,.08,1.32),'paint')
    box('Cross_mullion',(0,-.095,.10),(1.02,.08,.045),'paint')
    for side in [-1,1]:
        # Portadas held open, pitched outward from the wall.
        start=len(PARTS);hinge=Vector((side*.65,-.065,0))
        for j in range(4):box('Shutter_board',(side*(.65+.045+j*.083),-.085,0),(.078,.055,1.36),'paint')
        for z in [-.48,.48]:box('Shutter_brace',(side*.81,-.12,z),(.34,.035,.065),'wood')
        angle=-side*math.radians(25)
        for o in PARTS[start:]:
            for v in o.data.vertices:
                p=v.co-hinge;v.co=hinge+Vector((math.cos(angle)*p.x-math.sin(angle)*p.y,math.sin(angle)*p.x+math.cos(angle)*p.y,p.z))
        for z in [-.50,.50]:box('Window_hinge',(side*.63,-.09,z),(.055,.055,.12),'iron')
    register('window_shutters','coastal_facade','Painted timber frame, cross mullions, opaque salt-clouded glazing and two open shutters.')

    clear_parts()
    for x in [-.55,.55]:box('Door_jamb',(x,-.075,0),(.13,.15,2.24),'plaster',.012)
    box('Door_lintel',(0,-.085,1.08),(1.22,.17,.14),'plaster',.012)
    for i in range(6):box('Door_plank',(-.416+i*.166,-.065,-.02),(.160,.10,2.08),'wood',.004)
    for z in [-.66,.66]:box('Door_cross_brace',(0,-.135,z),(1.0,.045,.10),'wood')
    beam('Door_diagonal',(-.43,-.135,-.63),(.43,-.135,.63),.085,.045,'wood')
    box('Latch_plate',(.33,-.133,-.05),(.07,.025,.18),'iron')
    tube('Door_handle',[(.33,-.15,-.11),(.33,-.19,-.09),(.33,-.19,-.01),(.33,-.15,.01)],.013,'iron',6)
    for z in [-.75,.75]:box('Door_hinge',(-.40,-.14,z),(.17,.035,.055),'iron')
    register('door_frame','coastal_facade','Weathered plank door with limewashed frame, cross bracing and iron latch.')

    clear_parts()
    vertices=[];nx=8;ny=4
    for layer in [0,1]:
        for j in range(ny+1):
            t=j/ny
            for i in range(nx+1):
                x=-1.05+i*2.10/nx;y=-.015-t*1.18
                z=.22-.38*t-.085*math.sin(math.pi*t)+.016*math.cos(x*10)*t-layer*.008
                vertices.append((x,y,z))
    faces=[];n=(nx+1)*(ny+1)
    for j in range(ny):
        for i in range(nx):
            a=j*(nx+1)+i;faces.extend([(a,a+1,a+nx+2,a+nx+1),(n+a+nx+1,n+a+nx+2,n+a+1,n+a)])
    boundary=list(range(nx+1))+[j*(nx+1)+nx for j in range(1,ny+1)]+[ny*(nx+1)+i for i in range(nx-1,-1,-1)]+[j*(nx+1) for j in range(ny-1,0,-1)]
    faces += [(a,b,n+b,n+a) for a,b in zip(boundary,boundary[1:]+boundary[:1])]
    mesh('Sagging_canvas',vertices,faces,'cloth',uv=[(i/nx,j/ny) for layer in [0,1] for j in range(ny+1) for i in range(nx+1)])
    for i in range(8):
        x=-1.05+i*2.1/8;x1=x+2.1/8
        mesh('Scalloped_valance',[(x,-1.20,-.16),(x1,-1.20,-.16),(x1,-1.20,-.30),((x+x1)/2,-1.205,-.34),(x,-1.20,-.30)],
             [(0,1,2,3,4),(4,3,2,1,0)],'cloth')
    for x in [-1.,1.]:
        box('Awning_wall_plate',(x,-.025,.03),(.09,.05,.46),'iron')
        tube('Awning_brace',[(x,-.03,-.17),(x,-1.19,-.15),(x,-.03,.22)],.018,'iron',6)
    beam('Awning_front_bar',(-1.06,-1.18,-.15),(1.06,-1.18,-.15),.03,.03,'iron')
    register('canvas_awning','coastal_facade','Faded striped canvas, slight sag, scalloped edge and steel support arms. Double-sided valance geometry.')

    clear_parts()
    for i in range(8):box('Balcony_floor',(-.79+i*.225,-.46,-.45),(.215,.86,.075),'wood',.004)
    for x in [-.9,.9]:
        box('Balcony_mount',(x,-.035,-.24),(.10,.07,1.10),'iron')
        beam('Balcony_under_brace',(x,-.03,-.75),(x,-.84,-.44),.05,.05,'iron')
    for i in range(9):tube('Baluster',[(-.9+i*.225,-.90,-.43),(-.9+i*.225,-.90,.55)],.017,'iron',5)
    for x in [-.9,.9]:
        tube('Side_baluster',[(x,-.45,-.43),(x,-.45,.55)],.017,'iron',5)
        beam('Balcony_side_rail',(x,-.02,.55),(x,-.93,.55),.045,.045,'iron')
    beam('Balcony_front_rail',(-.93,-.90,.55),(.93,-.90,.55),.045,.045,'iron')
    register('small_balcony','coastal_facade','Small timber platform, rusted iron balusters and two wall braces; no opaque railing filler.')

    clear_parts()
    for j in range(7):box('Stone_tread',(0,-.13-j*.25,.60-j*.19),(1.04,.27,.115),'plaster',.008)
    for x in [-.44,.44]:beam('Stair_stringer',(x,-.015,.55),(x,-1.78,-.76),.09,.12,'wood')
    for x in [-.56,.56]:
        box('Stair_anchor',(x,-.025,.98),(.10,.05,1.10),'iron')
        for j in [0,2,4,6]:
            z=.64-j*.19;tube('Stair_rail_post',[(x,-.13-j*.25,z),(x,-.13-j*.25,z+.85)],.020,'iron',5)
        beam('Stair_handrail',(x,-.02,1.57),(x,-1.73,.27),.04,.04,'iron')
    register('exterior_stair','coastal_facade','Seven stone treads, timber stringers and two steel handrails; projects outward from the wall.')

    clear_parts()
    box('Sign_mount',(0,-.035,.28),(.11,.07,.48),'iron')
    beam('Sign_bracket',(0,-.035,.43),(0,-.80,.43),.035,.035,'iron')
    beam('Sign_bracket_brace',(0,-.035,.12),(0,-.65,.43),.025,.025,'iron')
    for y in [-.28,-.67]:tube('Sign_hanger',[(0,y,.43),(0,y,.23)],.012,'iron',5)
    for j in range(3):box('Sign_plank',(0,-.47,-.02+j*.14),(.065,.62,.132),'wood',.004)
    for x in [-.035,.035]:
        # Raised fish silhouette; no typeface or third-party graphic.
        vertices=[(x,-.68,.11),(x,-.57,.17),(x,-.42,.16),(x,-.32,.10),(x,-.23,.19),(x,-.23,.02),(x,-.32,.10),(x,-.43,.04),(x,-.57,.04)]
        faces=[(0,1,2,3,7,8),(3,4,5)]
        if x<0:faces=[tuple(reversed(f)) for f in faces]
        mesh('Tavern_fish_emblem',vertices,faces,'plaster')
    register('tavern_sign','coastal_facade','Hanging timber tavern sign perpendicular to wall, iron cantilever and original fish emblem. No font dependency.')

    clear_parts()
    box('Lantern_mount',(0,-.025,.17),(.12,.05,.34),'iron',.006)
    tube('Lantern_hook',[(0,-.04,.31),(0,-.15,.43),(0,-.35,.43),(0,-.41,.34)],.016,'iron',6)
    box('Lantern_glazing',(0,-.40,.02),(.20,.20,.30),'glass')
    for x in [-.115,.115]:
        for y in [-.515,-.285]:box('Lantern_corner',(x,y,.02),(.020,.020,.34),'iron')
    for z in [-.16,.20]:box('Lantern_rim',(0,-.40,z),(.26,.26,.035),'iron')
    mesh('Pitched_lantern_roof',[(-.16,-.56,.22),(.16,-.56,.22),(.16,-.24,.22),(-.16,-.24,.22),(0,-.40,.34)],
         [(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],'iron')
    register('wall_lantern','coastal_facade','Unlit iron wall lantern with opaque frosted glazing. No light node, emission or transparent sorting dependency.')

    clear_parts()
    box('Chimney_stack',(0,-.29,0),(.52,.58,1.18),'plaster',.008)
    box('Chimney_lower_course',(0,-.32,-.57),(.62,.64,.10),'plaster',.006)
    box('Chimney_crown',(0,-.34,.59),(.68,.68,.11),'plaster',.006)
    # Open eight-sided flue: inner wall, ring cap and dark interior, not a solid lid.
    vs=[]
    for z,r in [(.64,.16),(.98,.16),(.98,.105),(.67,.105)]:
        vs += [(math.cos(math.tau*k/10)*r,-.34+math.sin(math.tau*k/10)*r,z) for k in range(10)]
    fs=[(j*10+k,j*10+(k+1)%10,(j+1)*10+(k+1)%10,(j+1)*10+k) for j in range(3) for k in range(10)]
    fs.append(tuple(30+k for k in range(10)))
    mesh('Hollow_chimney_pot',vs,fs,'wood')
    for j in range(4):
        z=-.4+j*.25
        for x in [-.16,.045]:box('Exposed_brick',(x,-.588,z),(.18,.018,.08),'wood')
    register('chimney','coastal_facade','Limewashed wall chimney with exposed masonry courses, projecting crown and genuinely open flue.')


def export_asset(name,entry):
    select(entry['objects']);file=ROOT/entry['kit']/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(file),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_normals=True,export_tangents=True,export_texcoords=True,
        export_animations=False,export_skins=False,export_cameras=False,export_lights=False,export_extras=False)
    raw=file.read_bytes();size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size]);binary=raw[28+size:]
    doc['asset']['copyright']='CC0-1.0; original procedural geometry and textures; no third-party assets.'
    doc['asset']['extras']={'asset_id':name,'units':'metres','forward':'-Z' if entry['kit']=='beach_horror' else '+Z',
                          'pivot':'base centre' if entry['kit']=='beach_horror' else 'centre of rear mounting face at Z=0',
                          'license':'CC0-1.0','notes':entry['notes']}
    payload=json.dumps(doc,separators=(',',':')).encode();payload+=b' '*((-len(payload))%4)
    file.write_bytes(struct.pack('<III',0x46546c67,2,28+len(payload)+len(binary))+struct.pack('<II',len(payload),0x4e4f534a)+payload+struct.pack('<II',len(binary),0x004e4942)+binary)


def render_exports():
    # Everything is re-imported from delivered GLBs; staging is transient.
    for name,entry in CATALOG.items():
        if entry['kit']!='beach_horror':continue
        stage();bpy.ops.import_scene.gltf(filepath=str(ROOT/'beach_horror'/(name+'.glb')))
        objects=[o for o in bpy.context.selected_objects if o.type=='MESH']
        points=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
        lo=Vector(tuple(min(v[i] for v in points) for i in range(3)));hi=Vector(tuple(max(v[i] for v in points) for i in range(3)))
        centre=(lo+hi)/2;span=max(hi.x-lo.x,hi.y-lo.y,hi.z-lo.z)
        floor();camera(centre+Vector((span*1.25,span*1.75,span*1.05)),centre,span*1.38)
        save_render(ROOT/'beach_horror/renders'/(name+'.png'))
    if any(e['kit']=='coastal_facade' for e in CATALOG.values()):
        stage();wall=bpy.data.materials.new('Transient warm test wall');wall.diffuse_color=(.43,.39,.30,1)
        bpy.ops.mesh.primitive_cube_add(size=1,location=(0,.18,2.85));o=bpy.context.object;o.scale=(8.5,.36,5.7);o.data.materials.append(wall)
        placements={'door_frame':(-2.35,0,1.17),'canvas_awning':(-2.35,0,2.64),
                    'window_shutters':(.15,0,4.15),'small_balcony':(.15,0,3.18),
                    'exterior_stair':(2.50,0,2.35),'tavern_sign':(-1.15,0,2.27),
                    'wall_lantern':(-3.25,0,2.05),'chimney':(3.12,0,4.70)}
        for name,location in placements.items():
            bpy.ops.import_scene.gltf(filepath=str(ROOT/'coastal_facade'/(name+'.glb')))
            for obj in bpy.context.selected_objects:
                if obj.parent is None:obj.location+=Vector(location)
        floor();camera((9,-13,8),(0,-.5,2.75),9.4)
        save_render(ROOT/'coastal_facade/renders/facade_assembly.png')


def stage():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.resolution_x=1200;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.world=bpy.data.worlds.new('Transient studio');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.075,.090,.10,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.45
    for location,power,size in [((-4,4,7),1200,5),((5,-3,4),850,4),((-3,-5,5),1000,3)]:
        bpy.ops.object.light_add(type='AREA',location=location);o=bpy.context.object;o.data.energy=power;o.data.size=size
        o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()


def floor():
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.012));o=bpy.context.object
    mat=bpy.data.materials.new('Transient studio ground');mat.diffuse_color=(.105,.115,.11,1);mat.roughness=.95;o.data.materials.append(mat)


def camera(location,target,span):
    bpy.ops.object.camera_add(location=location);cam=bpy.context.object;cam.data.type='ORTHO';cam.data.ortho_scale=span
    cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();bpy.context.scene.camera=cam


def save_render(path):
    bpy.context.scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)


def write_assets(no_render):
    manifest={'license':'CC0-1.0','original_work':True,'external_assets':False,'models':{}}
    for name,entry in CATALOG.items():
        export_asset(name,entry)
        manifest['models'][name]={k:v for k,v in entry.items() if k!='objects'}
    (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
    # Collection names allow editing one model at a time in the source file.
    for name,entry in CATALOG.items():
        col=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(col)
        for obj in entry['objects']:
            for old in list(obj.users_collection):old.objects.unlink(obj)
            col.objects.link(obj);obj.hide_render=False
        col.hide_viewport=(name!='dead_tree');col.hide_render=(name!='dead_tree')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/scenery_kit.blend'))
    if not no_render:render_exports()
    print('SCENERY BUILD COMPLETE',flush=True)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--beach-only',action='store_true');parser.add_argument('--no-render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for p in ['textures','source','beach_horror/renders','coastal_facade/renders']:(ROOT/p).mkdir(parents=True,exist_ok=True)
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    material();beach()
    if not args.beach_only:facade()
    write_assets(args.no_render)


if __name__=='__main__':main()
