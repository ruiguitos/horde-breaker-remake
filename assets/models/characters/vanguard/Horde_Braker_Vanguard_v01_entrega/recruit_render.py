import bpy, math, os, sys
from mathutils import Vector

def look_at(obj, point):
    obj.rotation_euler=(Vector(point)-obj.location).to_track_quat('-Z','Y').to_euler()

def setup_studio(resolution=900, samples=32):
    scene=bpy.context.scene
    for o in list(bpy.data.objects):
        if o.type in {'CAMERA','LIGHT'}:bpy.data.objects.remove(o,do_unlink=True)
    studio=bpy.data.collections.get('90_Preview_Studio')
    if studio:
        for o in list(studio.objects):bpy.data.objects.remove(o,do_unlink=True)
    else:
        studio=bpy.data.collections.new('90_Preview_Studio');scene.collection.children.link(studio)
    def link(o):
        for c in list(o.users_collection):c.objects.unlink(o)
        studio.objects.link(o)
    bpy.ops.object.camera_add(location=(3,5,2.6))
    cam=bpy.context.object;cam.name='Preview_Camera';link(cam)
    cam.data.type='ORTHO';cam.data.ortho_scale=1.88;cam.data.lens=55
    cam.data.clip_end=1000
    scene.camera=cam
    for name,loc,power,size in [('Key',(-3,4,6),500,4),('Fill',(4,3,3),245,4),('Rim',(-2,-4,4),300,3)]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        o=bpy.context.object;o.name='Studio_'+name;link(o);o.data.energy=power;o.data.shape='DISK';o.data.size=size;look_at(o,(0,0,.8))
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.002))
    ground=bpy.context.object;ground.name='Studio_Ground';link(ground)
    mat=bpy.data.materials.get('Studio_Backdrop') or bpy.data.materials.new('Studio_Backdrop');mat.diffuse_color=(.035,.049,.055,1);mat.use_nodes=True
    bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=mat.diffuse_color;bsdf.inputs['Roughness'].default_value=.92
    ground.data.materials.clear();ground.data.materials.append(mat)
    world=bpy.data.worlds.new('Recruit_Studio_World');scene.world=world;world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.04,.055,.065,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5
    scene.render.engine='CYCLES';scene.cycles.device='CPU';scene.cycles.samples=samples;scene.cycles.use_denoising=True
    scene.render.resolution_x=resolution;scene.render.resolution_y=resolution;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None';scene.view_settings.exposure=0;scene.view_settings.gamma=1
    scene.render.image_settings.color_mode='RGBA'
    return cam,studio

def render_view(cam,path,view='front',close=False,height=1.6):
    positions={'front':(0,5,1.08),'profile':(-5,0,1.08),'back':(0,-5,1.08),'three_quarter':(-3.6,5,2.65),'face':(-1.4,5,2.0)}
    target=(0,0,1.42) if close else (0,0,.8)
    scale=height/1.6
    cam.location=Vector(positions[view])*scale;look_at(cam,Vector(target)*scale);cam.data.ortho_scale=(.55 if close else 1.85)*scale
    bpy.context.scene.render.filepath=path
    bpy.ops.render.render(write_still=True)

if __name__=='__main__':
    root=os.path.dirname(__file__)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(root,'Horde_Braker_Recruit_v01.blend'))
    cam,studio=setup_studio(720,24)
    for v in (['front'] if '--front-only' in sys.argv else ['front','profile','back','three_quarter']):
        render_view(cam,os.path.join(root,'recruit_v02_work','original_'+v+'.png'),v)
