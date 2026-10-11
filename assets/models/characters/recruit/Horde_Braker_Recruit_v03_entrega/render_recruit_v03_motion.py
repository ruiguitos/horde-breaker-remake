"""Render UAL locomotion diagnostics from the editable rig; does not modify assets."""
import bpy, os, sys, json
from mathutils import Quaternion, Vector
ROOT=os.path.dirname(os.path.abspath(__file__));sys.path.insert(0,ROOT)
from recruit_render import look_at
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'Horde_Braker_Recruit_v03_rigged.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
scene=bpy.context.scene
for o in bpy.data.collections['90_Preview_Studio'].objects:o.hide_set(False)
scene.render.resolution_x=480;scene.render.resolution_y=480;scene.cycles.samples=8
cam=scene.camera;cam.location=(-4,6,3);look_at(cam,(0,.06,1.0));cam.data.ortho_scale=2.45
out=os.path.join(ROOT,'recruit_v03_work','motion_frames');os.makedirs(out,exist_ok=True)
hold=json.load(open(os.path.join(ROOT,'Recruit_Rifle_Hold_pose.json')))
for label,clip in ([] if '--hold-only' in sys.argv else [('Idle','Idle_Loop'),('Walk','Walk_Loop'),('Run_Sprint','Sprint_Loop')]):
    action=bpy.data.actions['Recruit_Test_'+clip]
    rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
    first,last=action.frame_range
    for n in range(12):
        frame=first+(last-first)*n/12;scene.frame_set(int(frame),subframe=frame-int(frame))
        scene.render.filepath=os.path.join(out,f'{label}_{n:02}.png');bpy.ops.render.render(write_still=True)
        print('MOTION',label,n,flush=True)
action=bpy.data.actions['Recruit_Test_Walk_Loop'].copy()
for layer in action.layers:
    for strip in layer.strips:
        for bag in strip.channelbags:
            for fc in list(bag.fcurves):
                if any(fc.data_path.startswith('pose.bones["'+name+'"]') for name in hold):bag.fcurves.remove(fc)
rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
for bone,values in hold.items():
    pb=rig.pose.bones[bone];q=values['quaternion_xyzw']
    pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion((q[3],q[0],q[1],q[2]));pb.location=Vector(values['location'])
first,last=action.frame_range
for n in range(12):
    frame=first+(last-first)*n/12;scene.frame_set(int(frame),subframe=frame-int(frame))
    bpy.context.view_layer.update()
    scene.render.filepath=os.path.join(out,f'Walk_hold_{n:02}.png');bpy.ops.render.render(write_still=True)
    print('MOTION Walk_hold',n,flush=True)
