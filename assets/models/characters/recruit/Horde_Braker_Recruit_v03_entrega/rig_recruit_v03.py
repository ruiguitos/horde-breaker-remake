"""Recruit rigid 53-bone UAL rig. Blender 5.2 background, no external Python packages.

Run: blender --background --factory-startup --python rig_recruit_v03.py
Inputs: the approved v02 game-scale GLB and original UAL GLB, plus extracted reference JSON.
The main GLB contains no animation. Original files are never written.
"""
import bpy,bmesh,json,math,os,sys,hashlib
from mathutils import Vector,Matrix,Quaternion
ROOT=os.path.dirname(os.path.abspath(__file__));sys.path.insert(0,ROOT)
from recruit_render import setup_studio,look_at
WORK=os.path.join(ROOT,'recruit_v03_work');OUT=os.path.join(ROOT,'Recruit_v03_previews')
os.makedirs(OUT,exist_ok=True)
REF=os.path.join(WORK,'UAL_skeleton_reference.json')
with open(REF) as f:reference=json.load(f)
assert reference['bone_count']==53 and len(reference['bones'])==53
required={b['name']:b['parent'] for b in reference['bones']}
hashes={}
for fn in ['Horde_Braker_Recruit_v02_escala_jogo.glb','Horde_Braker_Recruit_v02_escala_jogo.blend','AnimationLibrary_Godot_Standard.glb']:
    with open(os.path.join(ROOT,fn),'rb') as f:hashes[fn]=hashlib.sha256(f.read()).hexdigest()
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT,'AnimationLibrary_Godot_Standard.glb'))
source=next(o for o in bpy.data.objects if o.type=='ARMATURE')
source.name='UAL_Source_Rig'
assert {b.name:(b.parent.name if b.parent else '') for b in source.data.bones}==required
source_rest={b.name:b.matrix_local.copy() for b in source.data.bones}
source_tail={b.name:b.tail_local.copy() for b in source.data.bones}
source_actions={a.name:a for a in bpy.data.actions}
for a in source_actions.values():a.use_fake_user=True
# Check actual reference coordinates, not only the JSON's declared forward metadata.
json_error=max((source_rest[b['name']].translation-Vector((b['head_global_m'][0],-b['head_global_m'][2],b['head_global_m'][1]))).length for b in reference['bones'])
assert json_error<2e-5
for o in list(bpy.data.objects):
    if o!=source:bpy.data.objects.remove(o,do_unlink=True)
source.hide_render=True;source.hide_set(True)
bpy.ops.import_scene.gltf(filepath=os.path.join(ROOT,'Horde_Braker_Recruit_v02_escala_jogo.glb'))
meshes=[o for o in bpy.data.objects if o.type=='MESH']
assert len(meshes)==104
for o in meshes:
    # glTF duplicates vertices at flat-normal boundaries. Rejoin coincident
    # vertices per rigid part before checking topology; retain flat polygons.
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-6)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    for p in o.data.polygons:p.use_smooth=False
bpy.context.view_layer.update()
original_matrices={o.name:o.matrix_world.copy() for o in meshes}
original_vertices={o.name:[o.matrix_world@v.co for v in o.data.vertices] for o in meshes}
original_materials={o.name:[m.name for m in o.data.materials] for o in meshes}
old_rifle=bpy.data.objects['Weapon_AssaultRifle'].matrix_world.copy()
old_palette={m.name:list(m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value) for o in meshes for m in o.data.materials}
for o in meshes:o.parent=None;o.matrix_world=original_matrices[o.name]
for o in list(bpy.data.objects):
    if o!=source and o.type!='MESH':bpy.data.objects.remove(o,do_unlink=True)
collection=bpy.data.collections.new('Recruit_v03_Asset');bpy.context.scene.collection.children.link(collection)
data=source.data.copy();data.name='UAL_53_Recruit'
rig=bpy.data.objects.new('Rig',data);collection.objects.link(rig)
# Source +Z forward (Godot) is the opposite of the Recruit. A fixed container yaw
# preserves every local bone orientation and every animation rotation channel.
rig.rotation_euler.z=math.pi
rig.show_in_front=True;rig.data.display_type='STICK'
rig['source']='Universal Animation Library / Quaternius / CC0'
rig['joint_count']=53;rig['forward_godot']='-Z';rig['base_pose']='T-pose'
rig['orientation_note']='Source toes point +Z; fixed 180-degree container yaw faces Recruit toward -Z without changing local rest axes.'
bpy.context.view_layer.update()
WORLD=rig.matrix_world.copy();INV=WORLD.inverted();K=2.025/1.6
P=lambda x,y,z:Vector((x,y,z))*K
target={
 'root':Vector((0,0,0)),
 'DEF-hips':P(0,-.024,.790),
 'DEF-spine.001':P(0,-.024,.910),
 'DEF-spine.002':P(0,-.024,1.055),
 'DEF-spine.003':P(0,-.024,1.170),
 'DEF-neck':P(0,-.008,1.257),
 'DEF-head':P(0,0,1.306),
}
oldj={};newj={};deltas={}
def transform_between(a,b,c,d):
    rot=(Vector(b)-Vector(a)).rotation_difference(Vector(d)-Vector(c)).to_matrix().to_4x4()
    return Matrix.Translation(c)@rot@Matrix.Translation(-Vector(a))
for side,s in [('L',-1),('R',1)]:
    shoulder=P(s*.218,-.012,1.226)
    elbow=P(s*(.280 if side=='L' else .276),.019 if side=='L' else .028,.948 if side=='L' else 1.003)
    wrist=P(-.173,.268,.881) if side=='L' else P(.132,.247,.986)
    oldj[side]={'shoulder':shoulder,'elbow':elbow,'wrist':wrist}
    upper_dir=(WORLD.to_3x3()@source_rest['DEF-upper_arm.'+side].to_3x3().col[1]).normalized()
    fore_dir=(WORLD.to_3x3()@source_rest['DEF-forearm.'+side].to_3x3().col[1]).normalized()
    newelbow=shoulder+upper_dir*(elbow-shoulder).length
    newwrist=newelbow+fore_dir*(wrist-elbow).length
    target['DEF-shoulder.'+side]=P(s*.075,-.025,1.245)
    target['DEF-upper_arm.'+side]=shoulder
    target['DEF-forearm.'+side]=newelbow
    target['DEF-hand.'+side]=newwrist
    newj[side]={'shoulder':shoulder,'elbow':newelbow,'wrist':newwrist}
    deltas['upper_'+side]=transform_between(shoulder,elbow,shoulder,newelbow)
    deltas['fore_'+side]=transform_between(elbow,wrist,newelbow,newwrist)
    palm=bpy.data.objects['Glove_'+side+'_Palm']
    palm_center=sum(original_vertices[palm.name],Vector())/len(original_vertices[palm.name])
    hand_dir=(WORLD.to_3x3()@source_rest['DEF-hand.'+side].to_3x3().col[1]).normalized()
    deltas['hand_'+side]=transform_between(wrist,palm_center,newwrist,newwrist+hand_dir*(palm_center-wrist).length)
    hip=P(s*.099,-.017,.759);knee=P(s*.147,-.005,.437);ankle=P(s*.180,-.025,.175)
    newhip=hip.copy();newknee=P(s*.099,-.005,.437);newankle=P(s*.099,-.025,.175)
    target['DEF-thigh.'+side]=newhip;target['DEF-shin.'+side]=newknee;target['DEF-foot.'+side]=newankle
    target['DEF-toe.'+side]=P(s*.099,.145,.030)
    deltas['thigh_'+side]=transform_between(hip,knee,newhip,newknee)
    deltas['shin_'+side]=transform_between(knee,ankle,newknee,newankle)
    foot_pivot=P(s*.180,-.028,.080)
    deltas['foot_'+side]=Matrix.Translation(P(s*(.099-.180),0,0))@Matrix.Translation(foot_pivot)@Matrix.Rotation(s*math.radians(7),4,'Z')@Matrix.Translation(-foot_pivot)
    # Finger bones are preserved; rigid glove pieces use the hand bone as requested.
    for name,rest in source_rest.items():
        if name.endswith('.'+side) and ('DEF-f_' in name or 'DEF-thumb.' in name):
            target[name]=newwrist+WORLD.to_3x3()@(rest.translation-source_rest['DEF-hand.'+side].translation)*.58
assert set(target)==set(required)
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.object.mode_set(mode='EDIT')
for eb in rig.data.edit_bones:
    mat=source_rest[eb.name].copy();mat.translation=INV@target[eb.name]
    eb.use_connect=False;eb.matrix=mat
    children=[n for n,p in required.items() if p==eb.name]
    eb.length=max(.025,min(.30,(target[children[0]]-target[eb.name]).length)) if children else (.20 if eb.name=='DEF-head' else .035)
    eb.use_deform=True
bpy.ops.object.mode_set(mode='OBJECT');bpy.context.view_layer.update()
assert {b.name:(b.parent.name if b.parent else '') for b in rig.data.bones}==required
def orientation_error(a,b):
    angle=a.to_quaternion().rotation_difference(b.to_quaternion()).angle
    return min(angle,abs(2*math.pi-angle))
errors={b.name:orientation_error(source_rest[b.name],b.matrix_local) for b in rig.data.bones}
angle_error=max(errors.values())
print('REST ORIENTATION ERRORS',sorted(errors.items(),key=lambda x:-x[1])[:6],flush=True)
assert angle_error<.001
mapping=[]
# Unpose each rigid piece, retaining its topology, dimensions and materials.
for o in meshes:
    name=o.name;delta=Matrix.Identity(4)
    side=name[-1] if name.endswith(('_L','_R')) else None
    if name.startswith('Rifle_'):bone='DEF-hand.R'
    elif name.startswith('Head_') or name.startswith('Face_') or name.startswith('Helmet_'):bone='DEF-head'
    elif name=='Neck_Skin' or name.startswith('Uniform_Collar_'):bone='DEF-neck'
    elif name.startswith(('Vest_','Backpack_')):bone='DEF-spine.003'
    elif name=='Uniform_Torso':bone='DEF-spine.002'
    elif name.startswith(('Uniform_Pelvis','Uniform_Belt','Belt_')):bone='DEF-hips'
    elif name.startswith(('Arm_Upper_','Arm_Shoulder_')):
        bone='DEF-upper_arm.'+side;delta=deltas['upper_'+side]
    elif name.startswith(('Arm_Forearm_','Arm_Elbow_','Glove_Cuff_')):
        bone='DEF-forearm.'+side;delta=deltas['fore_'+side]
    elif name.startswith('Glove_'):
        side=name.split('_')[1];bone='DEF-hand.'+side;delta=deltas['hand_'+side]
    elif name.startswith(('Leg_Thigh_','Thigh_Utility_')):
        bone='DEF-thigh.'+side;delta=deltas['thigh_'+side]
    elif name.startswith(('Leg_Shin_','Knee')):
        bone='DEF-shin.'+side;delta=deltas['shin_'+side]
    elif name.startswith('Boot_'):
        side=name.split('_')[1];bone='DEF-foot.'+side;delta=deltas['foot_'+side]
    else:raise RuntimeError('Unmapped piece: '+name)
    if not name.startswith('Rifle_'):
        for v,w in zip(o.data.vertices,original_vertices[name]):v.co=delta@w
    o.parent=None;o.matrix_world=Matrix.Identity(4)
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o)
    o.vertex_groups.clear();vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1.0,'REPLACE')
    mod=o.modifiers.new('Rigid_UAL_Skin','ARMATURE');mod.object=rig;mod.use_deform_preserve_volume=False
    o.parent=rig;o.matrix_world=Matrix.Identity(4)
    o['rigid_bone']=bone;o['rigid_weight']=1.0
    mapping.append({'piece':name,'bone':bone,'vertices':len(o.data.vertices),'materials':original_materials[name]})
    o.data.update()
# Rifle points along Blender +Y == Godot -Z; grip stays beside the T-pose right hand.
right_palm=bpy.data.objects['Glove_R_Palm']
palm_center=sum((v.co for v in right_palm.data.vertices),Vector())/len(right_palm.data.vertices)
gun_rot=Matrix(((0,-1,0),(1,0,0),(0,0,1))).to_4x4()
gun_rest=Matrix.Translation(palm_center)@gun_rot
gun_delta=gun_rest@old_rifle.inverted()
for o in meshes:
    if o.name.startswith('Rifle_'):
        for v,w in zip(o.data.vertices,original_vertices[o.name]):v.co=gun_delta@w
        o.data.update()
tip_old=P(.4555,0,.013)-P(-.028,0,-.088)
tip_rest=gun_rest@tip_old
muzzle=bpy.data.objects.new('Muzzle',None);collection.objects.link(muzzle)
muzzle.empty_display_type='ARROWS';muzzle.empty_display_size=.06
muzzle.parent=rig;muzzle.parent_type='BONE';muzzle.parent_bone='DEF-hand.R'
bpy.context.view_layer.update();muzzle.matrix_world=Matrix.Translation(tip_rest)
muzzle['forward']='Local -Z follows barrel in Godot; world -Z at base pose'
rig['weapon_note']='T-pose requires separated hands; Hold diagnostic pose demonstrates two-hand grip. Generic UAL locomotion clips are not rifle-aim clips.'
hip_motion_scale=target['DEF-hips'].z/source_rest['DEF-hips'].translation.z
# Blender actions are already relative to rest. Copy and scale root/hips motion only.
actions={}
for name,action in source_actions.items():
    copy=action.copy();copy.name='Recruit_Test_'+name;copy.use_fake_user=True
    for layer in copy.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    if fc.data_path in ['pose.bones["root"].location','pose.bones["DEF-hips"].location']:
                        for kp in fc.keyframe_points:
                            kp.co.y*=hip_motion_scale;kp.handle_left.y*=hip_motion_scale;kp.handle_right.y*=hip_motion_scale
    actions[name]=copy
bpy.data.objects.remove(source,do_unlink=True)
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
report={'blender':bpy.app.version_string,'bone_count':len(rig.data.bones),'reference_json_coordinate_error_m':json_error,'maximum_rest_orientation_error_rad':angle_error,'base_pose':'T-pose','mesh_count':len(meshes),'mapping':mapping,'bones':[], 'original_sha256':hashes,'animations_in_main_glb':0,'hip_motion_scale':hip_motion_scale,'source_forward_observation':'JSON says -Z, but toes extend toward +Z. Fixed 180-degree rig-container yaw preserves source local orientations and model -Z forward.','notes':['104 rigid pieces; one bone and weight 1.0 per vertex','Finger bones preserved, rigid mitts attached to hand','Source has 46 clips; Run is Sprint_Loop, not a clip named Run','Generic Idle/Walk/Sprint do not maintain two-handed rifle aiming']}
for b in rig.data.bones:
    w=WORLD@b.head_local;t=WORLD@b.tail_local
    report['bones'].append({'name':b.name,'parent':b.parent.name if b.parent else '', 'head_global_godot_m':[w.x,w.z,-w.y],'tail_global_godot_m':[t.x,t.z,-t.y],'local_rest_matrix_blender':[list(r) for r in b.matrix_local]})
coords=[v.co for o in meshes for v in o.data.vertices]
report['base_bounds_blender']=[[min(v[i] for v in coords) for i in range(3)],[max(v[i] for v in coords) for i in range(3)]]
assert abs(report['base_bounds_blender'][0][2])<1e-5 and abs(report['base_bounds_blender'][1][2]-2.025)<1e-5
triangles=0
for o in meshes:
    o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    assert len(o.vertex_groups)==1 and all(len(v.groups)==1 and abs(v.groups[0].weight-1)<1e-6 for v in o.data.vertices)
    bm=bmesh.new();bm.from_mesh(o.data);assert all(e.is_manifold for e in bm.edges);assert bm.calc_volume()>0;bm.free()
report['triangles']=triangles;assert triangles==4000
report['material_count']=len(set(m.name for o in meshes for m in o.data.materials));assert report['material_count']==35
cam,studio=setup_studio(900,24)
for o in studio.objects:
    if o.type=='LIGHT':o.location*=K;o.data.energy*=K*K
    o.hide_set(True)
cam.location=(-4,6,3);look_at(cam,(0,0,1.0));cam.data.ortho_scale=2.65
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_location=(0,0,1)
            area.spaces.active.region_3d.view_distance=3.5
            area.spaces.active.region_3d.view_rotation=cam.rotation_euler.to_quaternion()
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Horde_Braker_Recruit_v03_rigged.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in [rig,muzzle]+meshes:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'Horde_Braker_Recruit_v03_rigged.glb'),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=False,export_materials='EXPORT',export_cameras=False,export_lights=False,export_animations=False,export_extras=True,export_def_bones=False)
with open(os.path.join(WORK,'rig_validation.json'),'w') as f:json.dump(report,f,indent=2)
print('RIG EXPORTED',len(rig.data.bones),triangles,'orientation error',angle_error,flush=True)
for o in studio.objects:o.hide_set(False)
def render(label,view='three_quarter',wide=False):
    pos={'front':(0,6,1.35),'side':(-6,0,1.35),'back':(0,-6,1.35),'three_quarter':(-4,6,3)}[view]
    cam.location=pos;look_at(cam,(0,.06,1.0));cam.data.ortho_scale=2.70 if wide else 2.45
    bpy.context.scene.render.filepath=os.path.join(OUT,label+'.png');bpy.ops.render.render(write_still=True)
for label,view in [('base_frente','front'),('base_lado','side'),('base_tras','back')]:render(label,view,True)
def set_action(action):
    rig.animation_data_create();rig.animation_data.action=action
    rig.animation_data.action_slot=action.slots[0]
    for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
for label,name,frame in [('Idle','Idle_Loop',25),('Walk','Walk_Loop',8),('Run_Sprint','Sprint_Loop',4)]:
    set_action(actions[name]);bpy.context.scene.frame_set(frame);bpy.context.view_layer.update();render(label)
    print('PREVIEW',label,flush=True)
# Analytic two-bone solve for a separate static rifle-hold demonstration.
rig.animation_data_clear()
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
right_rest=WORLD@rig.data.bones['DEF-hand.R'].matrix_local
relative=right_rest.inverted()@gun_rest
gun_hold=Matrix.Translation(Vector((.04,.27,1.38)))@gun_rot
desiredR=gun_hold@relative.inverted()
def solve_arm(side,handmat):
    a=target['DEF-upper_arm.'+side];goal=handmat.translation
    l1=(target['DEF-forearm.'+side]-a).length;l2=(target['DEF-hand.'+side]-target['DEF-forearm.'+side]).length
    direction=(goal-a).normalized();dist=min((goal-a).length,l1+l2-.001)
    along=(l1*l1-l2*l2+dist*dist)/(2*dist);h=math.sqrt(max(0,l1*l1-along*along))
    pole=Vector((-1 if side=='L' else 1,0,-1));pole=(pole-direction*pole.dot(direction)).normalized()
    elbow=a+direction*along+pole*h
    for name,old_a,old_b,new_a,new_b in [('DEF-upper_arm.'+side,a,target['DEF-forearm.'+side],a,elbow),('DEF-forearm.'+side,target['DEF-forearm.'+side],target['DEF-hand.'+side],elbow,goal)]:
        rest=WORLD@rig.data.bones[name].matrix_local
        q=(old_b-old_a).rotation_difference(new_b-new_a)
        mat=q.to_matrix().to_4x4()@rest;mat.translation=new_a
        rig.pose.bones[name].matrix=INV@mat;bpy.context.view_layer.update()
    rig.pose.bones['DEF-hand.'+side].matrix=INV@handmat;bpy.context.view_layer.update()
solve_arm('R',desiredR)
left_rest=WORLD@rig.data.bones['DEF-hand.L'].matrix_local
leftpalm=bpy.data.objects['Glove_L_Palm']
leftcenter=sum((v.co for v in leftpalm.data.vertices),Vector())/len(leftpalm.data.vertices)
leftoffset=left_rest.inverted()@leftcenter
support=gun_hold@(P(.255,-.015,-.045)-P(-.028,0,-.088))
leftmat=left_rest.copy()
q=Vector((-1,0,0)).rotation_difference(Vector((0,1,0)))
leftmat=q.to_matrix().to_4x4()@left_rest;leftmat.translation=support-leftmat.to_3x3()@leftoffset
solve_arm('L',leftmat);render('empunhadura_duas_maos')
hold={}
for side in ['L','R']:
    for part in ['shoulder','upper_arm','forearm','hand']:
        name='DEF-'+part+'.'+side;pb=rig.pose.bones[name]
        q=pb.matrix_basis.to_quaternion();loc=pb.matrix_basis.translation
        hold[name]={'quaternion_xyzw':[q.x,q.y,q.z,q.w],'location':list(loc)}
with open(os.path.join(ROOT,'Recruit_Rifle_Hold_pose.json'),'w') as f:json.dump(hold,f,indent=2)
report['hold_pose']={'gun_grip_world_blender':list(gun_hold.translation),'support_target_world_blender':list(support),'overridden_bones':list(hold),'left_palm_in_left_hand':list(leftoffset),'support_in_right_hand':list(relative@(P(.255,-.015,-.045)-P(-.028,0,-.088))),'barrel_direction_in_right_hand':list(right_rest.to_3x3().inverted()@Vector((0,1,0))),'role':'Optional upper-body overlay; base rig remains T-pose; original UAL clips unchanged in intent.'}
with open(os.path.join(WORK,'rig_validation.json'),'w') as f:json.dump(report,f,indent=2)
print('ALL RIG PREVIEWS COMPLETE',flush=True)
