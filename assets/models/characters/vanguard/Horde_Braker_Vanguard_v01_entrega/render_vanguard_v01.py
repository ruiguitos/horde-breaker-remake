"""Render Vanguard base, presentation poses and optional motion diagnostics.
Use --motion-only to render only the 480px GIF frames; no assets are modified.
"""
import bpy, os, sys, math, json
from mathutils import Vector,Matrix,Quaternion
ROOT=os.path.dirname(os.path.abspath(__file__));sys.path.insert(0,ROOT)
from recruit_render import look_at
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'Horde_Braker_Vanguard_v01_rigged.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');scene=bpy.context.scene;cam=scene.camera
OUT=os.path.join(ROOT,'Vanguard_v01_previews');os.makedirs(OUT,exist_ok=True)
for o in bpy.data.collections['90_Preview_Studio'].objects:o.hide_set(False)
def reset():
    rig.animation_data_clear()
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
def render(label,view='three_quarter',scale=2.48):
    cam.location={'front':(0,6,1.35),'side':(-6,0,1.35),'back':(0,-6,1.35),'three_quarter':(-4,6,3),'back_quarter':(4,-6,3)}[view]
    look_at(cam,(0,0,1));cam.data.ortho_scale=scale
    scene.render.filepath=os.path.join(OUT,label+'.png');bpy.ops.render.render(write_still=True)
    print('VANGUARD PREVIEW',label,flush=True)
hold=json.load(open(os.path.join(ROOT,'Vanguard_Rifle_Hold_pose.json')))
def apply_hold():
    for bone,values in hold.items():
        pb=rig.pose.bones[bone];q=values['quaternion_xyzw'];pb.rotation_mode='QUATERNION';pb.rotation_quaternion=Quaternion((q[3],q[0],q[1],q[2]));pb.location=Vector(values['location'])
    bpy.context.view_layer.update()
if '--motion-only' not in sys.argv:
    reset()
    for label,view in [('base_frente','front'),('base_lado','side'),('base_tras','back')]:render(label,view,2.72)
    # Neutral display pose: arms down, shoulder armor remains on the clavicles.
    for side,s in [('L',-1),('R',1)]:
        bone='DEF-upper_arm.'+side;rest=rig.matrix_world@rig.data.bones[bone].matrix_local
        mat=Matrix.Rotation(s*math.radians(75),4,'Y')@rest;mat.translation=rest.translation
        rig.pose.bones[bone].matrix=rig.matrix_world.inverted()@mat;bpy.context.view_layer.update()
    for label,view in [('frente','front'),('perfil','side'),('costas','back'),('perspetiva_3_4','three_quarter'),('costas_3_4','back_quarter')]:render(label,view)
    reset();apply_hold();render('empunhadura_duas_maos')
    for label,clip,frame in [('Idle','Idle_Loop',25),('Walk','Walk_Loop',8),('Run_Sprint','Sprint_Loop',4)]:
        reset();action=bpy.data.actions['Vanguard_Test_'+clip];rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        scene.frame_set(frame);render(label)
if '--motion-only' in sys.argv or '--with-motion' in sys.argv:
    frames=os.path.join(ROOT,'vanguard_v01_work','motion_frames');os.makedirs(frames,exist_ok=True)
    scene.render.resolution_x=480;scene.render.resolution_y=480;scene.cycles.samples=8
    cam.location=(-4,6,3);look_at(cam,(0,.06,1));cam.data.ortho_scale=2.48
    for label,clip in [('Idle','Idle_Loop'),('Walk','Walk_Loop'),('Run_Sprint','Sprint_Loop'),('Walk_hold','Walk_Loop')]:
        reset();action=bpy.data.actions['Vanguard_Test_'+clip]
        if label.endswith('_hold'):
            action=action.copy()
            for layer in action.layers:
                for strip in layer.strips:
                    for bag in strip.channelbags:
                        for fc in list(bag.fcurves):
                            if any(fc.data_path.startswith('pose.bones["'+name+'"]') for name in hold):bag.fcurves.remove(fc)
        rig.animation_data_create();rig.animation_data.action=action;rig.animation_data.action_slot=action.slots[0]
        if label.endswith('_hold'):apply_hold()
        first,last=action.frame_range
        for n in range(12):
            f=first+(last-first)*n/12;scene.frame_set(int(f),subframe=f-int(f));bpy.context.view_layer.update()
            scene.render.filepath=os.path.join(frames,f'{label}_{n:02}.png');bpy.ops.render.render(write_still=True)
            print('VANGUARD MOTION',label,n,flush=True)
print('VANGUARD PREVIEWS COMPLETE',flush=True)
