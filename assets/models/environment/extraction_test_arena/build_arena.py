"""Original CC0 extraction modules. Blender 5.2; NumPy bundled with Blender.
blender --background --factory-startup --python-exit-code 1 --python build_arena.py
Input coordinates: glTF X/Y/Z metres; Blender receives X/-Z/Y.
"""
import argparse
import importlib.util
import json
import math
from pathlib import Path
import struct
import sys
import time

import bpy
import bmesh
import numpy as np
from mathutils import Vector

ROOT=Path(__file__).resolve().parent
ROLES=['concrete','teal_paint','steel','rust','wood','amber_optic','hazard','rubber']
PARTS=[]
MODELS={}
MAT=None


def xyz(p):return Vector((p[0],-p[2],p[1]))


def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]


def texture(name,rgb,srgb=False):
    image=bpy.data.images.new(name,width=1024,height=1024,alpha=False)
    image.colorspace_settings.name='sRGB' if srgb else 'Non-Color'
    pixels=np.ones((1024,1024,4),np.float32)
    # Generated image buffers are written as encoded samples by image.save().
    # Keep the sRGB palette encoded; pre-linearising here darkens the PNG twice.
    pixels[:,:,:3]=np.clip(rgb,0,1)
    image.pixels.foreach_set(pixels.ravel());image.filepath_raw=str(ROOT/'textures'/(name+'.png'))
    image.file_format='PNG';image.save();image.pack()
    return image


def material():
    global MAT
    rgb=np.zeros((1024,1024,3));rough=np.full((1024,1024),.85)
    metal=np.zeros((1024,1024));height=np.zeros((1024,1024))
    rng=np.random.default_rng(25102026)
    palette=[(.49,.49,.45),(.18,.34,.34),(.30,.32,.32),(.36,.15,.055),
             (.36,.30,.21),(.94,.43,.07),(.88,.64,.18),(.055,.065,.065)]
    for i,role in enumerate(ROLES):
        y,x=np.mgrid[0:512,0:256]/np.array([512,256])[:,None,None]
        noise=rng.random((512,256))-.5
        cloud=np.sin(x*17+y*3)*np.sin(y*21-x*8)
        c=np.broadcast_to(np.array(palette[i])[None,None,:],(512,256,3)).copy()
        h=noise*.012;r=np.full((512,256),.8);m=np.zeros((512,256))
        if role=='concrete':
            c*=1+.13*cloud[:,:,None]+.09*noise[:,:,None]
            pores=(noise>.485);c*=1-.3*pores[:,:,None]
            seams=(np.mod(y*4,1)<.009);c*=1-.12*seams[:,:,None]
            h+=-.025*pores-.012*seams;r[:]=.94
        elif role in ['teal_paint','rust','steel']:
            rust=np.maximum(0,(cloud+.12+noise*.45))**2
            if role=='teal_paint':
                rust=np.clip((rust-.12)*2.2,0,.85);r=.68+.22*rust;m=.25*(1-rust)
            elif role=='steel':rust=np.clip(rust*.45,0,.45);r=.42+.42*rust;m=.9*(1-rust)
            else:rust=np.clip(.5+rust,0,1);r=.84+.1*noise;m=.05*(1-rust)
            c=c*(1-rust[:,:,None])+np.array([.38,.15,.045])*rust[:,:,None]
            c*=1+.05*noise[:,:,None];h+=rust*.06
        elif role=='wood':
            flow=x+.018*np.sin(y*22)+.008*np.sin(y*63)
            grain=np.sin(flow*math.tau*24)+.3*np.sin(flow*math.tau*63)
            cracks=(np.sin(flow*math.tau*39)>.985)&(np.sin(y*44+x*9)>-.3)
            c*=1+.08*grain[:,:,None]-.40*cracks[:,:,None]+.08*cloud[:,:,None]
            h+=grain*.012-.05*cracks;r[:]=.92
        elif role=='amber_optic':
            ribs=np.cos(x*math.tau*32)
            c*=1+.1*ribs[:,:,None];r[:]=.25;h+=ribs*.015
        elif role=='hazard':
            stripe=np.mod(x*6+y*3,1)<.35
            c=np.where(stripe[:,:,None],np.array([.07,.08,.075]),c)
            c*=1+.06*noise[:,:,None];r[:]=.78
        else:r[:]=.92
        ys=slice((i//4)*512,(i//4+1)*512);xs=slice(i%4*256,(i%4+1)*256)
        rgb[ys,xs]=c;rough[ys,xs]=r;metal[ys,xs]=m;height[ys,xs]=h
    dx=(np.roll(height,-1,1)-np.roll(height,1,1))*.8
    dy=(np.roll(height,-1,0)-np.roll(height,1,0))*.8
    normals=np.stack((-dx,-dy,np.ones_like(dx)),axis=2)
    normals/=np.linalg.norm(normals,axis=2,keepdims=True)
    images={'albedo':texture('arena_albedo',rgb,True),
            'normal':texture('arena_normal',normals*.5+.5),
            'orm':texture('arena_orm',np.stack((np.ones_like(rough),rough,metal),axis=2))}
    MAT=bpy.data.materials.new('Extraction_arena_PBR_1K');MAT.use_nodes=True
    nodes,links=MAT.node_tree.nodes,MAT.node_tree.links;bsdf=nodes.get('Principled BSDF')
    for key,image in images.items():
        tex=nodes.new('ShaderNodeTexImage');tex.image=image
        if key=='albedo':links.new(tex.outputs['Color'],bsdf.inputs['Base Color'])
        elif key=='normal':
            n=nodes.new('ShaderNodeNormalMap');links.new(tex.outputs['Color'],n.inputs['Color']);links.new(n.outputs[0],bsdf.inputs['Normal'])
        else:
            sep=nodes.new('ShaderNodeSeparateColor');links.new(tex.outputs['Color'],sep.inputs['Color'])
            links.new(sep.outputs['Green'],bsdf.inputs['Roughness']);links.new(sep.outputs['Blue'],bsdf.inputs['Metallic'])


def finish(obj,role,smooth=False):
    select([obj]);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    bm=bmesh.new();bm.from_mesh(obj.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(obj.data);bm.free()
    mesh=obj.data;mesh.update();uv=mesh.uv_layers.active or mesh.uv_layers.new(name='UVMap')
    points=np.array([v.co for v in mesh.vertices]);lo=points.min(0);span=np.maximum(np.ptp(points,axis=0),1e-7)
    role_i=ROLES.index(role);ox=role_i%4*.25;oy=role_i//4*.5
    for face in mesh.polygons:
        axis=int(np.argmax(np.abs(face.normal)));axes=[a for a in range(3) if a!=axis]
        for loop in face.loop_indices:
            p=points[mesh.loops[loop].vertex_index]
            u=(p[axes[0]]-lo[axes[0]])/span[axes[0]];v=(p[axes[1]]-lo[axes[1]])/span[axes[1]]
            uv.data[loop].uv=(ox+.25*(.02+.96*u),oy+.5*(.02+.96*v))
        face.use_smooth=smooth
    mesh.materials.clear();mesh.materials.append(MAT);PARTS.append(obj)
    return obj


def box(name,centre,size,role='concrete',bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1,location=xyz(centre));obj=bpy.context.object;obj.name=name
    obj.scale=(size[0],size[2],size[1]);select([obj]);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=obj.modifiers.new('Edge bevel','BEVEL');mod.width=bevel;mod.segments=1
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(obj,role)


def rod(name,a,b,r,role='steel',sides=10):
    a,b=xyz(a),xyz(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides,radius=r,depth=(b-a).length,location=(a+b)/2)
    obj=bpy.context.object;obj.name=name;obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    return finish(obj,role,True)


def custom(name,points,faces,role):
    mesh=bpy.data.meshes.new(name);mesh.from_pydata([xyz(p) for p in points],[],faces);mesh.update()
    obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
    return finish(obj,role)


def register(name,dimensions,pivot,notes,mount=None):
    objects=list(PARTS);select(objects);bpy.ops.object.join();obj=bpy.context.object;obj.name=name
    mod=obj.modifiers.new('Export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=mod.name)
    select([obj]);bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    obj['license']='CC0-1.0';obj['units']='metres';obj['up_axis']='Y';obj['forward']='+Z';obj['pivot']=pivot
    count=len(obj.data.polygons);assert count<=3000,(name,count)
    MODELS[name]={'object':obj,'triangles':count,'expected_dimensions_xyz_m':dimensions,'pivot':pivot,'notes':notes,'light_mount':mount}
    obj.hide_render=True
    PARTS.clear();print('MODULE',name,count,flush=True)


def models():
    for name,h in [('concrete_wall',2.4),('low_cover',1.1)]:
        # A full rectangular footing closes the plan projection despite corner bevels.
        box('Solid footprint',(2,.018,.2),(4,.036,.4))
        box('Cast wall',(2,h/2,.2),(4,h,.4),bevel=.025)
        # Recessed front divisions are modelled as mounted shallow cast panels.
        # A full rear body preserves the continuous collision footprint.
        for x in [.045,3.955]:
            box('Worn end facing',(x,h/2,.2),(.09,h-.08,.39),'concrete',.008)
        register(name,[4,h,.4],'lower-left corner of rear mounting face; bounds X>=0,Y>=0,Z>=0',
                 'Closed cast concrete, bevelled edges, original pore/formwork normal map; front +Z.')

    box('Closed container core',(3,1.3,1.2),(5.86,2.5,2.30),'teal_paint',.025)
    box('Continuous closed floor',(3,.035,1.2),(6,.07,2.4),'steel')
    # Corner castings, rails and corrugations stay inside the 6 x 2.6 x 2.4 envelope.
    for x in [.075,5.925]:
        for z in [.075,2.325]:
            for y in [.075,2.525]:box('Corner casting',(x,y,z),(.15,.15,.15),'rust',.012)
    for z in [.055,2.345]:
        for y in [.12,2.48]:box('Side rail',(3,y,z),(5.7,.10,.10),'steel',.01)
        for i in range(17):
            box('Pressed wall rib',(.26+i*.342,1.3,z),(.085,2.26,.095),'teal_paint',.012)
    for z in [.625,1.775]:
        box('Closed door leaf',(.045,1.3,z),(.075,2.32,1.12),'teal_paint',.012)
        for dz in [-.35,.35]:
            rod('Door locking rod',(.018,.25,z+dz),(.018,2.35,z+dz),.014)
            box('Door locking handle',(.025,1.12,z+dz),(.045,.06,.23),'rust',.007)
        for y in [.35,1.3,2.25]:box('Door hinge',(.04,y,z-.48),(.07,.09,.10),'rust',.008)
    for x in [1,2,3,4,5]:
        box('Roof stiffener',(x,2.565,1.2),(.07,.07,2.22),'teal_paint',.008)
    register('shipping_container',[6,2.6,2.4],'southwest ground corner; X length, +Z depth',
             'Sealed six-metre cargo container, corrugated sides, two closed end doors with locking rods and oxidised fittings.')

    box('Solid retaining mass',(4,.59,4),(8,1.18,8),'concrete',.025)
    box('Solid footprint',(4,.02,4),(8,.04,8))
    box('Deck centre',(4,1.19,4),(7.72,.02,7.72))
    for z in [.07,7.93]:box('Hazard deck edge',(4,1.19,z),(8,.02,.14),'hazard')
    for x in [.07,7.93]:box('Hazard deck edge',(x,1.19,4),(.14,.02,7.72),'hazard')
    register('platform',[8,1.2,8],'southwest ground corner',
             'Full solid plinth with marked deck edges; no hollow undercroft.')

    custom('Closed ramp wedge',[(0,0,0),(8,0,0),(0,0,4),(8,0,4),(0,1.2,4),(8,1.2,4)],
           [(0,2,3,1),(0,1,5,4),(2,4,5,3),(0,4,2),(1,3,5)],'concrete')
    register('ramp',[8,1.2,4],'low-edge left corner at ground; rises toward +Z',
             'Closed triangular-prism ramp, 4 m horizontal run, 8 m clear width, 1.2 m rise.')

    box('Pillar solid footing',(.6,.10,.6),(1.2,.20,1.2))
    box('Pillar shaft',(.6,3,.6),(1.04,5.70,1.04),'concrete',.035)
    box('Pillar cap',(.6,5.92,.6),(1.2,.16,1.2),'steel',.025)
    for y in [1.0,1.25,4.75]:
        for z in [.071,1.129]:box('Landmark band',(.6,y,z),(1.04,.15,.018),'hazard',.003)
    register('landmark_pillar',[1.2,6,1.2],'southwest ground corner',
             'Six-metre concrete marker with steel cap and hazard bands, visible above 2.4 m walls.')

    box('Closed square foundation',(0,.075,0),(2,.15,2))
    for a in [math.radians(v) for v in [30,150,270]]:
        foot=(.82*math.cos(a),.15,.82*math.sin(a));top=(.20*math.cos(a),2.87,.20*math.sin(a))
        rod('Tripod steel leg',foot,top,.045,'steel',10)
        box('Tripod anchor shoe',(foot[0],.17,foot[2]),(.17,.04,.17),'rust',.01)
    # Ladder is steel geometry only, within the closed base's footprint.
    for x in [-.22,.22]:rod('Ladder stile',(x,.18,.70),(x,2.81,.24),.022,'steel',8)
    for i in range(9):
        y=.30+i*.29;z=.70-(y-.18)/2.63*.46
        rod('Ladder rung',(-.22,y,z),(.22,y,z),.015,'steel',8)
    rod('Beacon head platform',(0,2.82,0),(0,2.94,0),.36,'steel',16)
    rod('Amber optical drum',(0,2.95,0),(0,3.40,0),.245,'amber_optic',16)
    rod('Beacon steel cap',(0,3.40,0),(0,3.48,0),.29,'steel',16)
    box('Beacon cap peak',(0,3.49,0),(.16,.02,.16),'steel',.006)
    register('extraction_beacon',[2,3.5,2],'ground centre of square base',
             'Steel tripod, nine-rung ladder and amber rotating-beacon optical head; no light, no animation.',[0,3.2,0])

    box('Dock closed underside',(5,.115,1.5),(10,.23,3),'wood')
    for n in range(25):
        box('Deck plank',(n*.4+.20,.265,1.5),(.388,.07,3),'wood',.006)
    for x in [.16,3.38,6.62,9.84]:
        for z in [.16,2.84]:
            box('Mooring post',(x,.75,z),(.22,1.5,.22),'wood',.02)
            box('Galvanised post collar',(x,1.18,z),(.24,.09,.24),'steel',.008)
    register('dock',[10,1.5,3],'southwest bottom corner; X length, +Z width',
             'Closed timber deck and eight posts; 0.30 m deck, 1.50 m post tops, no gaps in plan collision projection.')


def export_models():
    catalog={}
    for name,entry in MODELS.items():
        obj=entry['object'];select([obj]);obj.hide_render=False
        mount=None
        if entry['light_mount']:
            mount=bpy.data.objects.new('LightMount',None);bpy.context.collection.objects.link(mount)
            mount.location=xyz(entry['light_mount']);mount['purpose']='Attach runtime rotating light; no light exported'
            select([obj,mount])
        bpy.context.scene['license']='CC0-1.0';bpy.context.scene['units']='metres'
        path=ROOT/'modules'/name/(name+'.glb')
        pending=path.with_name('_pending_'+name+'.glb')
        bpy.ops.export_scene.gltf(filepath=str(pending),export_format='GLB',use_selection=True,
            export_yup=True,export_apply=True,export_texcoords=True,export_normals=True,export_tangents=True,
            export_animations=False,export_cameras=False,export_lights=False,export_extras=True)
        raw=pending.read_bytes();length=struct.unpack_from('<I',raw,12)[0]
        doc=json.loads(raw[20:20+length]);binary=raw[28+length:]
        doc['asset']['copyright']='CC0-1.0; original geometry and procedural textures; no external assets.'
        doc['asset']['extras']={'license':'CC0-1.0','units':'metres','up_axis':'Y','asset_id':name,
                               'pivot':entry['pivot'],'forward':'+Z'}
        payload=json.dumps(doc,separators=(',',':')).encode();payload+=b' '*((-len(payload))%4)
        pending.write_bytes(struct.pack('<III',0x46546c67,2,28+len(payload)+len(binary))+
            struct.pack('<II',len(payload),0x4e4f534a)+payload+struct.pack('<II',len(binary),0x004e4942)+binary)
        for attempt in range(4):
            try:pending.replace(path);break
            except OSError:
                if attempt==3:raise
                time.sleep(.25)
        if mount:bpy.data.objects.remove(mount,do_unlink=True)
        collection=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(collection)
        for old in list(obj.users_collection):old.objects.unlink(obj)
        collection.objects.link(obj);collection.hide_viewport=(name!='extraction_beacon');collection.hide_render=(name!='extraction_beacon')
        catalog[name]={k:v for k,v in entry.items() if k!='object'}
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/extraction_modules.blend'))
    (ROOT/'manifest.json').write_text(json.dumps({'license':'CC0-1.0','units':'metres','up_axis':'Y',
        'original_geometry':True,'original_procedural_textures':True,'texture_size':[1024,1024],
        'dimension_order':'X width/length, Y height, Z depth; see each module',
        'models':catalog},indent=2)+'\n')


def stage():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene=bpy.context.scene;scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
    scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=True
    scene.render.resolution_percentage=100;scene.view_settings.view_transform='AgX'
    scene.world=bpy.data.worlds.new('Preview sky');scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.38,.48,.58,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.65
    bpy.ops.object.light_add(type='SUN',location=(40,20,150));sun=bpy.context.object
    sun.rotation_euler=(.38,-.28,-.45);sun.data.energy=2.6;sun.data.angle=.12
    return scene


def plain_material(name,color,emission=False):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*color,1);bs.inputs['Roughness'].default_value=.9
    if emission:bs.inputs['Emission Color'].default_value=(*color,1);bs.inputs['Emission Strength'].default_value=.6
    return m


def preview_box(name,loc,size,mat):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(mat)
    return o


def text_label(text,position,size=2,color=(.8,.88,.87),rotation=(0,0,0)):
    bpy.ops.object.text_add(location=position);o=bpy.context.object;o.name='Preview label '+text
    o.data.body=text;o.data.size=size;o.data.align_x='CENTER';o.rotation_euler=rotation
    o.data.materials.append(plain_material('Preview ink '+text,color,True));return o


def assemble(items):
    cache={}
    for name in MODELS:
        bpy.ops.import_scene.gltf(filepath=str(ROOT/'modules'/name/(name+'.glb')))
        obj=next(o for o in bpy.context.selected_objects if o.type=='MESH')
        cache[name]=obj.data
        for o in list(bpy.context.selected_objects):bpy.data.objects.remove(o,do_unlink=True)
    assembled=[]
    for i,item in enumerate(items):
        obj=bpy.data.objects.new(f"{i:03d}_{item['module']}",cache[item['module']]);bpy.context.collection.objects.link(obj)
        obj.location=(item['x'],-item['z'],0);obj.rotation_euler.z=math.radians(item['rotation_deg'])
        assembled.append(obj)
    return assembled


def render_layout(items,features):
    scene=stage();assembled=assemble(items)
    floor=plain_material('Preview concrete ground',(.26,.28,.26))
    preview_box('Preview island ground',(128,-128,-.25),(256,256,.5),floor)
    sea=plain_material('Preview sea',(.065,.16,.19))
    preview_box('Preview surrounding sea',(128,-128,-.5),(600,600,.1),sea)
    # This is a source assembly in the exact asset coordinate convention.
    bpy.context.preferences.filepaths.save_version=0
    preview_lights=[o for o in scene.objects if o.type=='LIGHT']
    for light in preview_lights:scene.collection.objects.unlink(light)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'source/arena_layout.blend'))
    for light in preview_lights:scene.collection.objects.link(light)
    # The top view is a map: reflect the preview across Y so north is up,
    # east right and southwest origin bottom-left. Source/GLBs are untouched.
    for obj in assembled:
        obj.location.y*=-1;obj.rotation_euler.z*=-1;obj.scale.y=-1
    bpy.data.objects['Preview island ground'].location.y=128
    bpy.data.objects['Preview surrounding sea'].location.y=128
    # A world-space metre grid avoids hundreds of transient mesh operators.
    nodes,links=floor.node_tree.nodes,floor.node_tree.links
    geom=nodes.new('ShaderNodeNewGeometry');separate=nodes.new('ShaderNodeSeparateXYZ');links.new(geom.outputs['Position'],separate.inputs[0])
    masks=[]
    for period,threshold in [(.5,.012),(4,.04)]:
        xy=[]
        for axis in ['X','Y']:
            ping=nodes.new('ShaderNodeMath');ping.operation='PINGPONG';ping.inputs[1].default_value=period
            links.new(separate.outputs[axis],ping.inputs[0])
            test=nodes.new('ShaderNodeMath');test.operation='LESS_THAN';test.inputs[1].default_value=threshold
            links.new(ping.outputs[0],test.inputs[0]);xy.append(test)
        combine=nodes.new('ShaderNodeMath');combine.operation='MAXIMUM'
        links.new(xy[0].outputs[0],combine.inputs[0]);links.new(xy[1].outputs[0],combine.inputs[1]);masks.append(combine)
    minor=nodes.new('ShaderNodeMixRGB');minor.inputs[1].default_value=(.26,.28,.26,1);minor.inputs[2].default_value=(.33,.35,.32,1)
    links.new(masks[0].outputs[0],minor.inputs[0])
    major=nodes.new('ShaderNodeMixRGB');major.inputs[2].default_value=(.46,.48,.43,1)
    links.new(minor.outputs[0],major.inputs[1]);links.new(masks[1].outputs[0],major.inputs[0])
    links.new(major.outputs[0],nodes.get('Principled BSDF').inputs['Base Color'])
    route=plain_material('Preview escape route guide',(.24,.55,.53),True)
    for i,r in enumerate([60,90,114]):
        lo,hi=128-r,128+r
        for p,s in [((128,lo,.045),(2*r,.16,.018)),((128,hi,.045),(2*r,.16,.018)),
                    ((lo,128,.045),(.16,2*r,.018)),((hi,128,.045),(.16,2*r,.018))]:preview_box('Loop guide',p,s,route)
        text_label(f'L{i+1} / 8m',(128+r-10,128-r+8,.11),2.3,(.40,.88,.80))
    # An 80 m design-disc outline, with deliberate low cover inside it.
    ring=plain_material('Preview arena diameter ring',(.75,.61,.30),True)
    for i in range(96):
        a,b=math.tau*i/96,math.tau*(i+1)/96
        p=Vector((128+40*math.cos(a),128+40*math.sin(a),.06));q=Vector((128+40*math.cos(b),128+40*math.sin(b),.06))
        o=preview_box('Arena guide',(p+q)/2,((q-p).length,.12,.02),ring);o.rotation_euler.z=math.atan2(q.y-p.y,q.x-p.x)
    text_label('ARENA / 80m',(128,130,.12),3.8)
    text_label('COVER',(111,125,.12),1.8)
    text_label('MAIN ENTRY',(128,17,.13),2.4,(.9,.72,.35))
    text_label('BEACON',(128,242,.13),2.4,(.9,.72,.35))
    text_label('NORTH / +Z',(128,263,.13),2.6)
    text_label('EXTRACTION TEST / 256 x 256m',(128,-9,.13),3.4)
    for v in range(0,257,32):
        text_label(str(v),(v,-3,.12),1.7);text_label(str(v),(-5,v,.12),1.7)
    for point in [(128,85),(128,172),(84,128),(173,128)]:text_label('4m',(*point,.14),1.7,(.95,.73,.27))
    bpy.ops.object.camera_add(location=(128,128,330));cam=bpy.context.object
    cam.data.type='ORTHO';cam.data.ortho_scale=286;cam.data.clip_end=1000;scene.camera=cam
    scene.render.resolution_x=2048;scene.render.resolution_y=2048
    scene.render.filepath=str(ROOT/'renders/top_grid.png');bpy.ops.render.render(write_still=True)
    # Restore the assembly and remove annotations for the eye-height render.
    for obj in list(bpy.data.objects):
        if obj in assembled:obj.location.y*=-1;obj.rotation_euler.z*=-1;obj.scale.y=1
        elif obj.name not in ['Preview island ground','Preview surrounding sea'] and obj.type not in ['LIGHT','CAMERA']:
            bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.objects['Preview island ground'].location.y=-128;bpy.data.objects['Preview surrounding sea'].location.y=-128
    for link in list(floor.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].links):floor.node_tree.links.remove(link)
    cam.data.type='PERSP';cam.data.lens=24;cam.location=(98,-100,1.7)
    target=Vector((140,-146,1.9));cam.rotation_euler=(target-cam.location).to_track_quat('-Z','Y').to_euler()
    scene.render.resolution_x=1920;scene.render.resolution_y=1080;scene.cycles.samples=40
    scene.render.filepath=str(ROOT/'renders/arena_eye.png');bpy.ops.render.render(write_still=True)


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--no-render',action='store_true');parser.add_argument('--render-only',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for path in ['textures','source','renders']+['modules/'+name for name in ['concrete_wall','low_cover','shipping_container','platform','ramp','landmark_pillar','extraction_beacon','dock']]:
        (ROOT/path).mkdir(parents=True,exist_ok=True)
    spec=importlib.util.spec_from_file_location('arena_layout_builder',ROOT/'build_layout.py');layout=importlib.util.module_from_spec(spec);spec.loader.exec_module(layout)
    items,features=layout.generate();check=layout.check_layout(items,features);assert check['passed'],check['issues']
    if not args.render_only:
        bpy.ops.wm.read_factory_settings(use_empty=True);bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
        material();models();export_models()
    else:
        MODELS.update(json.loads((ROOT/'manifest.json').read_text())['models'])
    if not args.no_render:render_layout(items,features)
    print('ARENA BUILD COMPLETE',flush=True)


if __name__=='__main__':main()
