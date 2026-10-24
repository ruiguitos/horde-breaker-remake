"""Original rigged Walker, two LODs, four in-place clips. Blender 5.x only.
SPDX-License-Identifier: CC0-1.0
Run: blender --background --factory-startup --python-exit-code 1 --python build_walker.py
Construction: Blender +Y forward, +Z up; glTF -Z forward, +Y up.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Quaternion, Vector

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[3]
FPS = 100
CLIPS = {'walk':1.10,'run':.64,'attack':1.0,'death':1.20}
SPEEDS = {'walk':1.,'run':5.}
STANCES = {'walk':.58,'run':.28}
SKULL = Vector((0,-.03,1.8))
REGIONS = {'skin':(0,.5,.5,.5),'shirt':(.5,.5,.5,.5),'pants':(0,0,.5,.5),
           'leather':(.5,0,.25,.25),'flesh':(.75,0,.25,.25),'hair':(.5,.25,.125,.25),
           'eye':(.625,.25,.125,.125),'mouth':(.625,.375,.125,.125),'bone':(.75,.25,.25,.25)}
PARTS = []
RIG = None
MATERIAL = None
REST = {}
JOINTS = {}
OMITTED = []


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def smooth(a,b,p):
    u = min(1.,max(0.,(p-a)/(b-a)))
    return u*u*(3-2*u)


def save_image(name, rgb, color=False):
    size = rgb.shape[0]
    image = bpy.data.images.new(name,width=size,height=size,alpha=False)
    image.colorspace_settings.name = 'sRGB' if color else 'Non-Color'
    values = np.ones((size,size,4),np.float32)
    if color:
        rgb = np.where(rgb<=.04045,rgb/12.92,((rgb+.055)/1.055)**2.4)
    values[:,:,:3] = np.clip(rgb,0,1)
    image.pixels.foreach_set(values.ravel())
    image.file_format='PNG'
    image.filepath_raw=str(ROOT/'textures'/(name+'.png'))
    image.save()
    image.pack()
    return image


def materials():
    global MATERIAL
    (ROOT/'textures').mkdir(exist_ok=True)
    size=1024
    albedo=np.full((size,size,3),.1)
    roughness=np.full((size,size),.8)
    height=np.zeros((size,size))
    palette={'skin':(.54,.51,.45),'shirt':(.34,.32,.27),'pants':(.17,.20,.23),
             'leather':(.15,.11,.085),'flesh':(.28,.055,.045),'hair':(.08,.085,.067),
             'eye':(.51,.53,.49),'mouth':(.065,.033,.027),'bone':(.52,.47,.36)}
    rng=np.random.default_rng(24062026)
    for role,(ox,oy,w,h) in REGIONS.items():
        x0,y0,ww,hh=[round(v*size) for v in (ox,oy,w,h)]
        yy,xx=np.mgrid[0:hh,0:ww]/max(ww,hh)
        grain=rng.normal(0,1,(hh,ww))
        broad=np.zeros((hh,ww))
        for i in range(7):
            f,g=rng.integers(1,14,2)
            broad+=np.sin(math.tau*(xx*f+yy*g)+rng.random()*math.tau)/(i+2)
        broad/=2.5
        grime=np.clip((broad+.04)*1.1,0,.7)
        color=np.array(palette[role])[None,None,:]*(1+.035*broad[:,:,None]+.015*grain[:,:,None])
        bump=.004*grain
        r=.85+grain*.012
        if role in ['shirt','pants']:
            weave=np.sin(math.tau*xx*150)*np.sin(math.tau*(yy*150+xx*35))
            bump+=.025*weave
            color*=1+.035*weave[:,:,None]
            # Original maroon stains and faded fabric; no external photographs.
            blood=np.clip((broad-.32)*1.4,0,.45)
            color=color*(1-blood[:,:,None])+np.array([.16,.047,.035])*blood[:,:,None]
            r=.91+.025*grain
        elif role=='skin':
            veins=np.clip(.015-np.abs(np.sin(math.tau*(xx*7+yy*3)+np.sin(yy*15))),0,.015)*3
            color=color*(1-veins[:,:,None])+np.array([.26,.25,.20])*veins[:,:,None]
            color*=1-grime[:,:,None]*.15
            bump+=.012*np.sin(math.tau*xx*190)*np.sin(math.tau*yy*170)
            r=.70+.025*grain+grime*.1
        elif role in ['eye','flesh','mouth']:
            r=(.30 if role=='eye' else .63)+.02*grain
        albedo[y0:y0+hh,x0:x0+ww]=np.clip(color,0,1)
        roughness[y0:y0+hh,x0:x0+ww]=np.clip(r,.15,.98)
        height[y0:y0+hh,x0:x0+ww]=bump
    dx=(np.roll(height,-1,axis=1)-np.roll(height,1,axis=1))*.8
    dy=(np.roll(height,-1,axis=0)-np.roll(height,1,axis=0))*.8
    normal=np.stack((-dx,-dy,np.ones_like(dx)),axis=2)
    normal/=np.linalg.norm(normal,axis=2,keepdims=True)
    images={'albedo':save_image('walker_albedo',albedo,True),
            'normal':save_image('walker_normal',normal*.5+.5),
            'orm':save_image('walker_orm',np.stack((np.ones_like(dx),roughness,np.zeros_like(dx)),axis=2))}
    save_image('walker_roughness',np.repeat(roughness[:,:,None],3,axis=2))
    save_image('walker_metalness',np.zeros_like(albedo))
    MATERIAL=bpy.data.materials.new('Walker_PBR_1K')
    MATERIAL.use_nodes=True
    nodes,links=MATERIAL.node_tree.nodes,MATERIAL.node_tree.links
    bsdf=nodes.get('Principled BSDF')
    for role,img in images.items():
        node=nodes.new('ShaderNodeTexImage');node.image=img;node.label=role
        if role=='albedo':links.new(node.outputs['Color'],bsdf.inputs['Base Color'])
        elif role=='normal':
            n=nodes.new('ShaderNodeNormalMap');n.inputs['Strength'].default_value=.6
            links.new(node.outputs['Color'],n.inputs['Color']);links.new(n.outputs['Normal'],bsdf.inputs['Normal'])
        else:
            n=nodes.new('ShaderNodeSeparateColor');links.new(node.outputs['Color'],n.inputs['Color'])
            links.new(n.outputs['Green'],bsdf.inputs['Roughness']);links.new(n.outputs['Blue'],bsdf.inputs['Metallic'])


def rig():
    global RIG,REST,JOINTS,OMITTED
    source=PROJECT/'assets/models/characters/recruit/Horde_Braker_Recruit_v03_entrega/Horde_Braker_Recruit_v03_rigged.blend'
    bpy.ops.wm.open_mainfile(filepath=str(source))
    RIG=bpy.data.objects['Rig']
    RIG.animation_data_clear()
    for obj in list(bpy.data.objects):
        if obj!=RIG:bpy.data.objects.remove(obj,do_unlink=True)
    for action in list(bpy.data.actions):bpy.data.actions.remove(action)
    for bone in RIG.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    # Preserve the Recruit's names and parent graph. Rest proportions/axes are
    # authored for this Walker; direct playback of unrelated UAL clips is not promised.
    activate(RIG);bpy.ops.object.mode_set(mode='EDIT')
    OMITTED=[b.name for b in RIG.data.edit_bones if b.name.startswith(('DEF-f_','DEF-thumb.'))]
    for name in OMITTED:RIG.data.edit_bones.remove(RIG.data.edit_bones[name])
    specs={'root':((0,0,0),(0,0,.15)), 'DEF-hips':((0,0,.97),(0,0,1.08)),
           'DEF-spine.001':((0,0,1.08),(0,-.015,1.28)),
           'DEF-spine.002':((0,-.015,1.28),(0,-.005,1.44)),
           'DEF-spine.003':((0,-.005,1.44),(0,0,1.56)),
           'DEF-neck':((0,0,1.57),(0,-.015,1.68)),
           'DEF-head':((0,-.015,1.68),(0,-.03,1.90))}
    for side,s in [('L',-1),('R',1)]:
        specs.update({
            'DEF-shoulder.'+side:((s*.07,0,1.50),(s*.24,0,1.50)),
            'DEF-upper_arm.'+side:((s*.24,0,1.50),(s*.29,.025,1.19)),
            'DEF-forearm.'+side:((s*.29,.025,1.19),(s*.29,.07,.91)),
            'DEF-hand.'+side:((s*.29,.07,.91),(s*.29,.085,.78)),
            'DEF-thigh.'+side:((s*.105,0,.96),(s*.12,.025,.535)),
            'DEF-shin.'+side:((s*.12,.025,.535),(s*.12,-.01,.12)),
            'DEF-foot.'+side:((s*.12,-.01,.12),(s*.12,.14,.045)),
            'DEF-toe.'+side:((s*.12,.14,.045),(s*.12,.26,.035))})
    inverse=RIG.matrix_world.inverted()
    for name,(head,tail) in specs.items():
        bone=RIG.data.edit_bones[name];bone.use_connect=False
        bone.head=inverse@Vector(head);bone.tail=inverse@Vector(tail)
        bone.roll=0.
    bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update()
    REST={b.name:RIG.matrix_world@b.matrix_local for b in RIG.data.bones}
    JOINTS={name:(Vector(a),Vector(b)) for name,(a,b) in specs.items()}
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene.render.fps=FPS;scene.frame_start=0;scene.frame_end=120


def finish(obj,role,bone,blend=None):
    activate(obj)
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    if not obj.data.uv_layers:
        bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=1.1,island_margin=.02);bpy.ops.object.mode_set(mode='OBJECT')
    ox,oy,w,h=REGIONS[role]
    for uv in obj.data.uv_layers.active.data:
        uv.uv=(ox+w*(.01+.98*uv.uv.x),oy+h*(.01+.98*uv.uv.y))
    obj.data.materials.clear();obj.data.materials.append(MATERIAL)
    obj.parent=RIG;obj.matrix_parent_inverse=RIG.matrix_world.inverted()
    groups={bone:obj.vertex_groups.new(name=bone)}
    if blend:groups[blend[0]]=obj.vertex_groups.new(name=blend[0])
    for vertex in obj.data.vertices:
        f=0.
        if blend:
            name,axis,point,span=blend
            f=max(0,min(.5,.5-(vertex.co[axis]-point)/span))
        groups[bone].add([vertex.index],1-f,'REPLACE')
        if f:groups[blend[0]].add([vertex.index],f,'REPLACE')
    arm=obj.modifiers.new('Walker skin','ARMATURE');arm.object=RIG
    for p in obj.data.polygons:p.use_smooth=True
    PARTS.append(obj)
    return obj


def mesh(name,vertices,faces,role,bone,blend=None,uv=None):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    obj=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(obj)
    if uv:
        layer=data.uv_layers.new(name='UVMap')
        for face in data.polygons:
            for loop in face.loop_indices:layer.data[loop].uv=uv[data.loops[loop].vertex_index]
    return finish(obj,role,bone,blend)


def tube(name,a,b,radii,role,bone,rings=10,sides=12,wrinkle=0.,blend=None,jagged=False):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized()
    u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized()
    vertices=[];uv=[]
    for j in range(rings+1):
        t=j/rings;centre=a.lerp(b,t)
        radius=radii[0]*(1-t)+radii[1]*t
        for k in range(sides):
            angle=math.tau*k/sides
            r=radius+wrinkle*math.sin(t*17+math.sin(angle*2))*math.sin(math.pi*t)
            extra=.014*math.sin(k*7.8) if jagged and j==rings else 0.
            vertices.append(centre+axis*extra+u*(math.cos(angle)*r)+v*(math.sin(angle)*r*.92));uv.append((k/sides,t))
    faces=[tuple(range(sides-1,-1,-1))]
    faces += [(j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k)
              for j in range(rings) for k in range(sides)]
    faces.append(tuple(rings*sides+k for k in range(sides)))
    return mesh(name,vertices,faces,role,bone,blend,uv)


def ellipsoid(name,centre,scale,role,bone,segments=16,rings=10):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,location=centre)
    obj=bpy.context.object;obj.name=name;obj.scale=scale
    return finish(obj,role,bone)


def limb(name,a,b,c,radii,role,upper,lower,crease):
    # Continuous clothing/skin at elbow and knee; blend across the joint rings.
    a,b,c=Vector(a),Vector(b),Vector(c)
    axis=(c-a).normalized();u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u).normalized()
    vertices=[];uv=[];sides=12;rings=16
    for j in range(rings+1):
        t=j/rings
        first=t<=.5
        local=t*2 if first else (t-.5)*2
        centre=a.lerp(b,local) if first else b.lerp(c,local)
        r0,r1=(radii[0],radii[1]) if first else (radii[1],radii[2])
        radius=r0*(1-local)+r1*local
        # A subtle muscle/fabric bulge, with extra folds close to articulation.
        radius+=.004*math.sin(math.pi*local)
        for k in range(sides):
            theta=math.tau*k/sides
            wrinkle=crease*math.sin(t*42+math.sin(theta*2))*math.sin(math.pi*t)
            vertices.append(centre+u*math.cos(theta)*(radius+wrinkle)+v*math.sin(theta)*(radius+wrinkle)*.92)
            uv.append((k/sides,t))
    faces=[tuple(range(sides-1,-1,-1))]+[(j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k)
            for j in range(rings) for k in range(sides)]+[tuple(rings*sides+k for k in range(sides))]
    obj=mesh(name,vertices,faces,role,upper,uv=uv)
    obj.vertex_groups.clear();g0=obj.vertex_groups.new(name=upper);g1=obj.vertex_groups.new(name=lower)
    for vertex in obj.data.vertices:
        j=vertex.index//sides;t=j/rings;w=smooth(.42,.58,t)
        g0.add([vertex.index],1-w,'REPLACE');g1.add([vertex.index],w,'REPLACE')
    return obj


def box(name,centre,size,role,bone):
    bpy.ops.mesh.primitive_cube_add(size=1,location=centre)
    obj=bpy.context.object;obj.name=name;obj.scale=size
    return finish(obj,role,bone)


def body():
    # Closed, shaped ring sections give a torso with shoulder, rib and waist taper.
    sections=[(.98,.18,.105),(1.07,.175,.105),(1.17,.19,.12),(1.30,.22,.13),
              (1.43,.235,.125),(1.50,.225,.115),(1.54,.12,.082)]
    verts=[];uv=[];sides=16
    for j,(z,w,d) in enumerate(sections):
        for k in range(sides):
            a=math.tau*k/sides
            hem=.012*math.sin(k*4.3) if j==0 else 0
            verts.append((math.cos(a)*w,math.sin(a)*d,z+hem));uv.append((k/sides,j/(len(sections)-1)))
    faces=[tuple(range(sides-1,-1,-1))]
    faces += [(j*sides+k,j*sides+(k+1)%sides,(j+1)*sides+(k+1)%sides,(j+1)*sides+k)
              for j in range(len(sections)-1) for k in range(sides)]
    faces.append(tuple((len(sections)-1)*sides+k for k in range(sides)))
    torso=mesh('Torn_work_shirt',verts,faces,'shirt','DEF-spine.002',uv=uv)
    # Smooth torso weights across the retained spine joints, rather than rigid blocks.
    torso.vertex_groups.clear()
    nodes=[('DEF-hips',.99),('DEF-spine.001',1.15),('DEF-spine.002',1.34),('DEF-spine.003',1.48)]
    groups={n:torso.vertex_groups.new(name=n) for n,_ in nodes}
    for vertex in torso.data.vertices:
        z=vertex.co.z
        index=next((i for i in range(len(nodes)-1) if z<nodes[i+1][1]),len(nodes)-2)
        a,b=nodes[index],nodes[index+1];t=max(0,min(1,(z-a[1])/(b[1]-a[1])))
        groups[a[0]].add([vertex.index],1-t,'REPLACE');groups[b[0]].add([vertex.index],t,'REPLACE')
    ellipsoid('Pelvis', (0,0,1.0),(.19,.115,.14),'pants','DEF-hips',16,8)
    tube('Neck',(0,0,1.51),(0,-.015,1.71),(.061,.068),'skin','DEF-neck',6,12)
    skull=ellipsoid('Skull',SKULL,(.110,.110,.15),'skin','DEF-head',24,16)
    # Keep the skull's extrema fixed; only interior front vertices are shaped.
    inv=skull.matrix_world.inverted()
    for vertex in skull.data.vertices:
        p=skull.matrix_world@vertex.co
        if p.y>SKULL.y:
            front=max(0,min(1,(p.y-SKULL.y)/.110))
            for x in [-.055,.055]:
                p.y-=.010*math.exp(-((p.x-x)/.030)**2-((p.z-1.821)/.023)**2)*front
                p.y+=.008*math.exp(-((p.x-x)/.038)**2-((p.z-1.765)/.025)**2)*front
            vertex.co=inv@p
    jaw_sections=[(1.625,.035,.040,.034),(1.65,.065,.069,.025),
                  (1.69,.079,.085,.010),(1.73,.090,.102,-.015),(1.765,.090,.103,-.020)]
    jaw_vertices=[(math.cos(math.tau*k/16)*w,cy+math.sin(math.tau*k/16)*d,z)
                  for z,w,d,cy in jaw_sections for k in range(16)]
    jaw_faces=[tuple(range(15,-1,-1))]+[(j*16+k,j*16+(k+1)%16,(j+1)*16+(k+1)%16,(j+1)*16+k)
                for j in range(4) for k in range(16)]+[tuple(64+k for k in range(16))]
    mesh('Lower_face',jaw_vertices,jaw_faces,'skin','DEF-head')
    ellipsoid('Open_mouth',(0,.105,1.737),(.044,.004,.012),'mouth','DEF-head',16,8)
    ellipsoid('Nose_bridge',(0,.096,1.783),(.018,.028,.033),'skin','DEF-head',12,8)
    for s in [-1,1]:
        ellipsoid('Sunken_socket',(s*.046,.084,1.821),(.026,.007,.016),'mouth','DEF-head',12,8)
        ellipsoid('Clouded_eye',(s*.046,.092,1.821),(.013,.005,.007),'eye','DEF-head',12,8)
        tube('Brow',(s*.022,.094,1.839),(s*.078,.087,1.837),(.007,.008),'skin','DEF-head',3,8)
        ellipsoid('Ear',(s*.124,-.025,1.797),(.019,.025,.037),'skin','DEF-head',12,8)
        for i in range(3):
            box('Broken_tooth',(s*(.008+i*.011),.109,1.741),(.007,.003,.008-i*.001),'bone','DEF-head')
    # Bald cranium: the skull itself sets the 1.95 m visual height and aim centre.
    # Skin under tears, cuff fragments and discrete bite injuries.
    mesh('Shirt_chest_tear',[(.086,.118,1.399),(.115,.119,1.374),(.110,.120,1.336),
                           (.101,.119,1.302),(.088,.118,1.349)],[(0,1,2),(0,2,4),(2,3,4)],
         'flesh','DEF-spine.002')
    tube('Torn_collar',(-.075,.033,1.52),(.074,.033,1.52),(.018,.017),'shirt','DEF-spine.003',4,8)
    for side,s in [('L',-1),('R',1)]:
        upper='DEF-upper_arm.'+side;fore='DEF-forearm.'+side;hand='DEF-hand.'+side
        hip,knee=JOINTS['DEF-thigh.'+side];_,ankle=JOINTS['DEF-shin.'+side]
        shoulder,elbow=JOINTS[upper];_,wrist=JOINTS[fore];_,tip=JOINTS[hand]
        limb('Trouser_leg_'+side,hip+Vector((0,0,.06)),knee,ankle+Vector((0,0,.025)),
             (.099,.080,.060),'pants','DEF-thigh.'+side,'DEF-shin.'+side,.004)
        limb('Arm_'+side,shoulder,elbow,wrist,(.080,.061,.041),'skin',upper,fore,.0006)
        sleeve_end=shoulder.lerp(elbow,.63)
        tube('Ripped_sleeve_'+side,shoulder,sleeve_end,(.094,.082),'shirt',upper,6,12,.002,jagged=True)
        axis=(tip-wrist).normalized()
        ellipsoid('Palm_'+side,wrist+axis*.045,(.041,.029,.056),'skin',hand,12,8)
        for i in range(4):
            off=Vector(((i-1.5)*.019,0,0))
            tube('Finger_'+side,wrist+axis*.085+off,wrist+axis*(.16 if i in [1,2] else .145)+off,
                 (.008,.0055),'skin',hand,3,8)
        tube('Thumb_'+side,wrist+Vector((s*.038,.01,-.012)),wrist+Vector((s*.055,.018,-.075)),(.011,.008),'skin',hand,4,8)
        ellipsoid('Forearm_bite_'+side,wrist.lerp(elbow,.55)+Vector((0,.046,0)),(.015,.0015,.032),'flesh',fore,12,8)
        # Shoe geometry, with a rigid toe segment sharing the foot pose.
        ellipsoid('Shoe_upper_'+side,(s*.12,.055,.076),(.076,.146,.073),'leather','DEF-foot.'+side,16,8)
        box('Shoe_sole_'+side,(s*.12,.060,.013),(.145,.280,.026),'leather','DEF-foot.'+side)
        box('Waist_belt',(s*.09,.110,1.06),(.17,.018,.035),'leather','DEF-hips')
        box('Trouser_pocket_'+side,(s*.164,.025,.855),(.018,.105,.135),'pants','DEF-thigh.'+side)
    # Keep the anatomical cranium separate for a real geometric centre audit.
    rest=[obj for obj in PARTS if obj!=skull]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in rest:obj.select_set(True)
    bpy.context.view_layer.objects.active=torso;bpy.ops.object.join()
    torso.name='Body_LOD0';skull.name='Skull_LOD0'
    for obj in [torso,skull]:
        activate(obj)
        mod=obj.modifiers.new('Triangles','TRIANGULATE');bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        obj.data.validate(verbose=True,clean_customdata=False)
        obj.data.update()
    return [torso,skull]


def bone_world(name):
    return RIG.matrix_world@RIG.pose.bones[name].matrix


def set_world(name,matrix):
    RIG.pose.bones[name].matrix=RIG.matrix_world.inverted()@matrix
    bpy.context.view_layer.update()


def rotate(name,axis,angle):
    before=bone_world(name);after=Quaternion(Vector(axis),angle).to_matrix().to_4x4()@before
    after.translation=before.translation;set_world(name,after)


def solve(a,b,goal,pole):
    start=bone_world(a).translation
    old_a,old_elbow=JOINTS[a];old_b,old_tip=JOINTS[b]
    l1=(old_elbow-old_a).length;l2=(old_tip-old_b).length
    axis=Vector(goal)-start;distance=axis.length;axis.normalize()
    assert abs(l1-l2)+.00001<distance<l1+l2-.00001,(a,'unreachable',distance,l1+l2)
    along=(l1*l1-l2*l2+distance*distance)/(2*distance)
    p=Vector(pole);p=(p-axis*p.dot(axis)).normalized()
    elbow=start+axis*along+p*math.sqrt(max(0,l1*l1-along*along))
    for name,head,old_dir,new_dir in [(a,start,old_elbow-old_a,elbow-start),(b,elbow,old_tip-old_b,Vector(goal)-elbow)]:
        q=old_dir.rotation_difference(new_dir)
        matrix=q.to_matrix().to_4x4()@REST[name];matrix.translation=head;set_world(name,matrix)


def orient(name,position,direction):
    a,b=JOINTS[name]
    q=(b-a).rotation_difference(Vector(direction))
    matrix=q.to_matrix().to_4x4()@REST[name];matrix.translation=position;set_world(name,matrix)


def pose(clip,t):
    for b in RIG.pose.bones:b.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    death=smooth(.16,1.,t) if clip=='death' else 0.
    attack=smooth(.20,.60,t)*(1-smooth(.60,1.,t)) if clip=='attack' else 0.
    bob=0.;drop=0.;lean=0.
    if clip in SPEEDS:
        p=t/CLIPS[clip];bob=.010*math.sin(math.tau*p*2)
        drop=-.075 if clip=='walk' else -.17
        lean=.045 if clip=='walk' else .16
    hips=REST['DEF-hips'].copy()
    hips=Quaternion(Vector((1,0,0)),death*math.pi/2).to_matrix().to_4x4()@hips
    hips.translation=REST['DEF-hips'].translation+Vector((0,-.10*death,drop+bob-.78*death))
    set_world('DEF-hips',hips)
    for name in ['DEF-spine.001','DEF-spine.002','DEF-spine.003']:
        rotate(name,(1,0,0),-(lean+.15*attack)/3)
    if clip in SPEEDS:
        rotate('DEF-head',(0,1,0),.025*math.sin(math.tau*t/CLIPS[clip]))
    feet={}
    for side,s,offset in [('L',-1,0.),('R',1,.5)]:
        if clip in SPEEDS:
            phase=(t/CLIPS[clip]+offset)%1
            stance=STANCES[clip];travel=SPEEDS[clip]*CLIPS[clip]*stance
            if phase<stance:
                y=travel/2-SPEEDS[clip]*CLIPS[clip]*phase;z=.12
            else:
                u=(phase-stance)/(1-stance)
                y=-travel/2+travel*smooth(0,1,u)
                z=.12+(.105 if clip=='walk' else .20)*math.sin(math.pi*u)
            goal=Vector((s*.12,y-.01,z))
        else:
            goal=JOINTS['DEF-foot.'+side][0].lerp(Vector((s*.16,.68,.12)),death)
        solve('DEF-thigh.'+side,'DEF-shin.'+side,goal,(0,1,0))
        orient('DEF-foot.'+side,goal,JOINTS['DEF-foot.'+side][1]-JOINTS['DEF-foot.'+side][0])
        feet[side]=goal
        rest=JOINTS['DEF-hand.'+side][0]
        if clip in SPEEDS:
            phase=math.tau*(t/CLIPS[clip]+offset)
            goal=rest+Vector((0,.045*math.sin(phase),.025*math.cos(phase)))
        else:
            target=Vector((s*.24,.56 if side=='R' else .53,1.25))
            goal=rest.lerp(target,attack)
            if clip=='death':
                upper_world=bone_world('DEF-upper_arm.'+side)
                shoulder=upper_world.translation
                carried=upper_world@REST['DEF-upper_arm.'+side].inverted()@rest-shoulder
                goal=shoulder+carried.lerp(Vector((s*.14,.29,-.125)),death)
        solve('DEF-upper_arm.'+side,'DEF-forearm.'+side,goal,(s*.5,-.25,-.15))
        direction=(JOINTS['DEF-hand.'+side][1]-rest).normalized().lerp(Vector((0,1,0)),max(attack,death)).normalized()
        orient('DEF-hand.'+side,goal,direction)


def clips():
    RIG.animation_data_create()
    for name,duration in CLIPS.items():
        action=bpy.data.actions.new(name);action.use_fake_user=True;RIG.animation_data.action=action
        for frame in range(round(duration*FPS)+1):
            bpy.context.scene.frame_set(frame);pose(name,frame/FPS)
            for bone in RIG.pose.bones:
                bone.rotation_mode='QUATERNION'
                bone.keyframe_insert(data_path='location',frame=frame,group=bone.name)
                bone.keyframe_insert(data_path='rotation_quaternion',frame=frame,group=bone.name)
        for layer in action.layers:
            for strip in layer.strips:
                for bag in strip.channelbags:
                    for curve in bag.fcurves:
                        for key in curve.keyframe_points:key.interpolation='LINEAR'
        print('CLIP',name,duration,flush=True)
    RIG.animation_data.action=None
    for bone in RIG.pose.bones:bone.matrix_basis=Matrix.Identity(4)
    bpy.context.scene.frame_set(0);bpy.context.view_layer.update()


def lods(high):
    low=[]
    for obj in high:
        duplicate=obj.copy();duplicate.data=obj.data.copy();bpy.context.collection.objects.link(duplicate)
        duplicate.name=obj.name.replace('LOD0','LOD1');activate(duplicate)
        mod=duplicate.modifiers.new('LOD1 collapse','DECIMATE');mod.ratio=.235
        mod.use_collapse_triangulate=True;bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)
        duplicate.data.validate(verbose=True,clean_customdata=False)
        duplicate.data.update()
        low.append(duplicate)
    return low


def export(objects,name):
    bpy.ops.object.select_all(action='DESELECT');RIG.select_set(True)
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=RIG
    file=ROOT/(name+'.glb')
    bpy.ops.export_scene.gltf(filepath=str(file),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_skins=True,export_def_bones=False,export_leaf_bone=False,
        export_texcoords=True,export_normals=True,export_tangents=True,export_materials='EXPORT',
        export_animations=True,export_animation_mode='ACTIONS',export_frame_range=False,
        export_force_sampling=True,export_frame_step=1,export_rest_position_armature=True,
        export_cameras=False,export_lights=False,export_extras=False)
    raw=file.read_bytes();size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+size]);binary=raw[28+size:]
    for animation in doc.get('animations',[]):
        clip=animation['name']
        animation['extras']={'loop':clip in SPEEDS,'root_motion':False}
        if clip in SPEEDS:animation['extras'].update(ground_speed_mps=SPEEDS[clip],stride_m=SPEEDS[clip]*CLIPS[clip],stance_fraction=STANCES[clip])
        if clip=='attack':animation['extras']['contact_time_s']=.6
        if clip=='death':animation['extras']['hold_from_s']=1.
    doc['asset']['copyright']='CC0-1.0; original Walker geometry, textures and clips; existing UAL bone naming convention.'
    payload=json.dumps(doc,separators=(',',':')).encode();payload+=b' '*((-len(payload))%4)
    file.write_bytes(struct.pack('<III',0x46546c67,2,28+len(payload)+len(binary))+struct.pack('<II',len(payload),0x4e4f534a)+payload+struct.pack('<II',len(binary),0x004e4942)+binary)


def render(high,low):
    for o in low:o.hide_render=True
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
    scene.render.resolution_x=1000;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
    scene.view_settings.view_transform='AgX';scene.world=bpy.data.worlds.new('Transient studio');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.045,.055,.06,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.5
    def look(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    target=(0,0,1.0)
    for location,power,size in [((-3,4,5),700,3),((3,3,2),350,3),((2,-4,4),900,2)]:
        bpy.ops.object.light_add(type='AREA',location=location);o=bpy.context.object;o.data.energy=power;o.data.size=size;look(o,target)
    bpy.ops.object.camera_add(location=(2.7,5,2.1));cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=2.35;look(cam,target)
    for label,clip,t in [('front_rest',None,0),('walk_midstep','walk',.275),('attack_contact','attack',.6)]:
        if clip:
            action=bpy.data.actions[clip];RIG.animation_data.action=action;RIG.animation_data.action_slot=action.slots[0]
            scene.frame_set(round(t*FPS))
        else:
            RIG.animation_data.action=None
            for bone in RIG.pose.bones:bone.matrix_basis=Matrix.Identity(4)
            bpy.context.view_layer.update()
        if label=='front_rest':cam.location=(0,5,1.15)
        else:cam.location=(2.7,5,2.1)
        look(cam,target);scene.render.filepath=str(ROOT/'renders'/(label+'.png'));bpy.ops.render.render(write_still=True)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for directory in ['textures','source','renders']:(ROOT/directory).mkdir(exist_ok=True)
    rig();materials();high=body();low=lods(high)
    for objects,limit in [(high,8000),(low,2000)]:
        count=sum(len(o.data.loop_triangles) if o.data.loop_triangles else sum(len(p.vertices)-2 for p in o.data.polygons) for o in objects)
        assert count<=limit,('Triangle budget',count,limit)
        print('TRIANGLES',count,limit,flush=True)
    clips()
    for mat in list(bpy.data.materials):
        if mat.users==0:bpy.data.materials.remove(mat)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/walker.blend'))
    export(high,'walker_lod0');export(low,'walker_lod1')
    contract={'license':'CC0-1.0','height_nominal_m':1.7,'height_visual_target_m':1.95,
              'height_resolution':'User approved preserving existing skull and silhouette; 1.70 m is the game nominal height.',
              'skull_center_gltf_m':[0,1.8,.03],'attack_contact_s':.6,'attack_plane_gltf_z_m':-.72,
              'clip_durations_s':CLIPS,'ground_speeds_mps':SPEEDS,'bone_names':list(JOINTS),'omitted_bones':OMITTED,
              'rig_basis_note':'Same UAL body names and parent hierarchy; rest anatomy authored for Walker, not an unchanged Recruit bind pose.',
              'source_references':['assets/models/characters/crawler_original/ (original appearance/palette only, not the standing Walker)',
                                   'game/world/zombie_model.gd (standing Walker silhouette and skull)',
                                   'assets/models/characters/recruit/recruit_v03.glb (bone naming/parent contract)']}
    (ROOT/'contract.json').write_text(json.dumps(contract,indent=2)+'\n')
    if not args.no_render:render(high,low)
    print('WALKER BUILD COMPLETE',flush=True)


if __name__=='__main__':main()
