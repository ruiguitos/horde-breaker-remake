"""Build Vanguard from the approved Recruit rig without writing any source file.
Blender 5.2.2 LTS: blender --background --factory-startup --python build_vanguard_v01.py
Vertex coordinates below are in Blender asset metres (+Z up, +Y forward).
The exported GLB uses +Y up, -Z forward and retains the Recruit's exact UAL rest.
"""
import bpy, bmesh, os, sys, math, json, hashlib
from mathutils import Vector, Matrix
ROOT=os.path.dirname(os.path.abspath(__file__));sys.path.insert(0,ROOT)
from recruit_render import setup_studio,look_at
WORK=os.path.join(ROOT,'vanguard_v01_work');OUT=os.path.join(ROOT,'Vanguard_v01_previews')
os.makedirs(WORK,exist_ok=True);os.makedirs(OUT,exist_ok=True)
source_files=['Horde_Braker_Recruit_v03_rigged.blend','Horde_Braker_Recruit_v03_rigged.glb','Recruit_UAL_compatible.tres','Recruit_Rifle_Hold_pose.json','AnimationLibrary_Godot_Standard.glb']
hashes={name:hashlib.sha256(open(os.path.join(ROOT,name),'rb').read()).hexdigest() for name in source_files}
ref=json.load(open(os.path.join(ROOT,'recruit_v03_work','UAL_skeleton_reference.json')))
bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,source_files[0]))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE');rig.animation_data_clear()
for pb in rig.pose.bones:pb.matrix_basis=Matrix.Identity(4)
bpy.context.view_layer.update()
meshes=[o for o in bpy.data.objects if o.type=='MESH' and not o.name.startswith('Studio_')]
assert len(meshes)==104
original_bones={o.name:o.vertex_groups[0].name for o in meshes}
muzzle=bpy.data.objects['Muzzle'];keep=set(meshes+[rig,muzzle])
for o in list(bpy.data.objects):
    if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
for action in list(bpy.data.actions):
    if action.name.startswith('Recruit_Test_'):action.name=action.name.replace('Recruit_Test_','Vanguard_Test_',1)
    else:bpy.data.actions.remove(action)
collection=bpy.data.collections.new('Vanguard_v01_Asset');bpy.context.scene.collection.children.link(collection)
for o in keep:
    for c in list(o.users_collection):c.objects.unlink(o)
    collection.objects.link(o)
rig.data.name='UAL_53_Vanguard';rig['character']='Vanguard';rig['height_m']=2.025
rig['reference']='reference_vanguard_back.png; front derived from approved Recruit with user authorization'
rig['weapon_note']='Existing replaceable Assault Rifle placeholder; no new weapon created'
rig['bone_count']=53;rig['base_pose']='T-pose';rig['forward_godot']='-Z'
# Olive field palette derived from the screenshot; skin/hair/weapon colors retained.
palette={'helmet':'858B4C','helmet_top':'9BA160','helmet_shadow':'555B36','helmet_trim':'737A42',
 'helmet_patch':'383E2C','cloth':'626B48','cloth_dark':'404A34','cloth_light':'808958',
 'pants':'535B3C','pants_shadow':'373F2A','vest':'6B7346','vest_shadow':'3A422D',
 'plate':'40472F','pouch':'515A3B','pouch_light':'626B43','pouch_flap':'353D29',
 'vest_strap':'30372A','knee':'7C8552','knee_shadow':'505A39',
 'boot':'353C2C','boot_light':'4C5540','boot_shadow':'242A21',
 'glove':'30382B','glove_shadow':'21281F','sole':'20271F'}
def srgb(v):return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
mats={m.name:m for o in meshes for m in o.data.materials}
for name,m in mats.items():
    if name in palette:
        col=tuple(srgb(int(palette[name][i:i+2],16)/255) for i in (0,2,4))+(1,)
        m.diffuse_color=col;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=col
    m.name='VG_'+name
    if name not in {'metal','metal_light','metal_dark'}:m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.94
rebuilt=[];bone_overrides={}
def replace(name,verts,faces,materials,indices=None,bone=None):
    o=bpy.data.objects[name];data=bpy.data.meshes.new(name+'_Vanguard_Mesh');data.from_pydata(verts,[],faces);data.update()
    for material in materials:data.materials.append(mats[material])
    if indices:
        for p,i in zip(data.polygons,indices):p.material_index=i
    bm=bmesh.new();bm.from_mesh(data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(data);bm.free()
    o.data=data;o.matrix_world=Matrix.Identity(4);o['geometry_revision']='Vanguard v01: rebuilt topology'
    rebuilt.append(name)
    if bone:bone_overrides[name]=bone
    return o
def ring8(cx,cy,z,hw,front,back,cut):
    return [(cx-hw+cut,cy+front,z),(cx-hw,cy+front-cut,z),(cx-hw,cy-back+cut,z),(cx-hw+cut,cy-back,z),(cx+hw-cut,cy-back,z),(cx+hw,cy-back+cut,z),(cx+hw,cy+front-cut,z),(cx+hw-cut,cy+front,z)]
def rings(name,profiles,materials):
    vs=[v for p in profiles for v in ring8(*p)];fs=[tuple(reversed(range(8)))];mi=[min(1,len(materials)-1)]
    for n in range(len(profiles)-1):
        for j in range(8):fs.append((n*8+j,n*8+(j+1)%8,(n+1)*8+(j+1)%8,(n+1)*8+j));mi.append(1 if j in (2,3,4) and len(materials)>1 else 0)
    fs.append(tuple(range((len(profiles)-1)*8,len(profiles)*8)));mi.append(2 if len(materials)>2 else 0)
    return replace(name,vs,fs,materials,mi)
def box(name,center,size,materials,bevel=.008,bone=None):
    c=Vector(center);x,y,z=size
    vs=[tuple(c+Vector((a*x/2,b*y/2,d*z/2))) for a,b,d in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)]]
    o=replace(name,vs,[(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)],materials,[min(1,len(materials)-1),0,min(1,len(materials)-1),0,min(1,len(materials)-1),0],bone)
    if bevel:
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.bevel(bm,geom=list(bm.edges),offset=bevel,segments=1,affect='EDGES',clamp_overlap=True);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    return o
def sleeve(name,a,b,width,depth):
    a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=Vector((0,1,0));u=(u-axis*u.dot(axis)).normalized();v=axis.cross(u).normalized()
    section=[(-.35,.5),(-.5,.35),(-.5,-.35),(-.35,-.5),(.35,-.5),(.5,-.35),(.5,.35),(.35,.5)]
    vs=[tuple(p+u*x*width*scale+v*y*depth*scale) for p,scale in [(a,.97),(a.lerp(b,.42),1.03),(b,.87)] for x,y in section]
    fs=[tuple(reversed(range(8)))];mi=[1]
    for n in range(2):
        for j in range(8):fs.append((n*8+j,n*8+(j+1)%8,(n+1)*8+(j+1)%8,(n+1)*8+j));mi.append(1 if j in (3,4) else 0)
    fs.append(tuple(range(16,24)));mi.append(0);replace(name,vs,fs,['cloth','cloth_dark'],mi)
def head(name):return rig.matrix_world@rig.data.bones[name].head_local
# Helmet: lower, squarer silhouette, wider lip, faceted side protection, exact top.
rings('Helmet_Crown',[(0,-.012,1.852,.195,.193,.201,.027),(0,-.012,1.980,.195,.193,.201,.027),(0,-.012,2.025,.178,.176,.184,.024)],['helmet','helmet_shadow','helmet_top'])
rings('Helmet_Brim',[(0,.002,1.824,.212,.221,.214,.027),(0,.002,1.866,.212,.221,.214,.027)],['helmet_trim','helmet_shadow','helmet'])
box('Helmet_Front_Plate',(0,.185,1.939),(.112,.033,.086),['helmet_patch'],.008)
for side,s in [('L',-1),('R',1)]:
    box('Helmet_Side_Shield_'+side,(s*.191,-.080,1.803),(.070,.244,.143),['helmet','helmet_shadow'],.014)
    a=head('DEF-upper_arm.'+side);b=head('DEF-forearm.'+side);c=head('DEF-hand.'+side)
    axis=(b-a).normalized();fore=(c-b).normalized()
    sleeve('Arm_Upper_'+side,a+axis*.025,b-axis*.014,.260,.252)
    sleeve('Arm_Forearm_'+side,b+fore*.012,c-fore*.018,.238,.235)
    box('Arm_Elbow_'+side,tuple(b),(.105,.225,.218),['cloth_dark'],.015)
    # Independent rigid shoulder plates stay on the clavicle, rather than rotating
    # entirely down with the upper arm. No extra bone or blended influence.
    box('Arm_Shoulder_Facet_'+side,(s*.317,-.018,1.609),(.235,.304,.174),['helmet','helmet_shadow'],.018,'DEF-shoulder.'+side)
    box('Arm_Upper_Patch_'+side,(s*.426,-.018,1.571),(.030,.269,.130),['cloth_light'],.008,'DEF-shoulder.'+side)
    x=s*.125
    rings('Leg_Thigh_'+side,[(x,-.018,.548,.100,.124,.130,.023),(x,-.018,.792,.116,.132,.147,.026),(x,-.018,.962,.109,.124,.138,.024)],['pants','pants_shadow'])
    rings('Leg_Shin_'+side,[(x,-.027,.209,.086,.103,.119,.019),(x,-.018,.410,.102,.117,.126,.023),(x,-.018,.534,.098,.110,.123,.022)],['pants','pants_shadow'])
    box('Kneepad_'+side,(x,.130,.535),(.204,.092,.193),['knee','knee_shadow'],.022)
    rings('Boot_'+side+'_Sole',[(x,0,0,.109,.247,.151,.018),(x,0,.047,.109,.247,.151,.018)],['sole'])
    rings('Boot_'+side+'_Vamp',[(x,0,.048,.106,.240,.147,.018),(x,0,.113,.101,.216,.141,.020),(x,0,.205,.086,.066,.131,.016)],['boot','boot_shadow','boot_light'])
    rings('Boot_'+side+'_Shaft',[(x,0,.115,.087,.066,.130,.016),(x,0,.268,.087,.066,.130,.016)],['boot','boot_shadow'])
# Rebuilt carrier and chest plate: broad mass, clipped corners, compact inherited pouches.
rings('Uniform_Torso',[(0,-.018,1.066,.230,.129,.164,.036),(0,-.018,1.405,.254,.135,.172,.039),(0,-.018,1.580,.236,.127,.163,.038)],['cloth','cloth_dark'])
rings('Uniform_Pelvis',[(0,-.024,.825,.214,.147,.154,.040),(0,-.024,1.034,.246,.163,.173,.044),(0,-.024,1.096,.237,.152,.165,.040)],['pants','pants_shadow'])
rings('Uniform_Belt',[(0,-.024,1.029,.252,.176,.184,.034),(0,-.024,1.089,.252,.176,.184,.034)],['vest_strap'])
box('Belt_Buckle',(0,.160,1.059),(.087,.025,.057),['helmet_trim'],.005)
rings('Vest_Carrier',[(0,-.012,1.087,.246,.212,.180,.036),(0,-.012,1.375,.275,.235,.188,.040),(0,-.012,1.580,.247,.215,.178,.036)],['vest','vest_shadow'])
box('Vest_Chest_Plate',(0,.228,1.466),(.431,.064,.240),['plate','vest_shadow'],.026)
box('Vest_Upper_Webbing',(0,.248,1.336),(.382,.028,.034),['vest_shadow'],.005)
for index,x in enumerate([-.108,0,.108],1):
    box('Vest_Magazine_Pouch_%02d'%index,(x,.245,1.205),(.098,.121,.237),['pouch_light' if index==2 else 'pouch'],.008)
    box('Vest_Magazine_Flap_%02d'%index,(x,.305,1.304),(.100,.023,.057),['helmet_trim'],.005)
for side,s in [('L',-1),('R',1)]:
    box('Vest_Shoulder_Strap_'+side,(s*.204,-.005,1.596),(.079,.429,.054),['vest'],.009)
    box('Vest_Front_Strap_'+side,(s*.211,.235,1.536),(.067,.037,.100),['helmet_trim'],.006)
    box('Vest_Side_Pouch_'+side,(s*.284,.014,1.176),(.089,.187,.211),['pouch'],.008)
    box('Vest_Side_Pouch_Flap_'+side,(s*.284,.017,1.267),(.093,.193,.045),['pouch_flap'],.005)
# Hanging rectangular pack: plain dark back panel with olive frame, two top hangers.
# Reuse the seven original pack pieces; no gadgets, antennas or extra pockets.
rings('Backpack_Main',[(0,-.309,1.104,.221,.105,.113,.016),(0,-.309,1.539,.243,.105,.113,.017),(0,-.309,1.579,.229,.097,.105,.016)],['helmet_trim','vest'])
box('Backpack_Rear_Pocket',(0,-.430,1.349),(.405,.028,.439),['plate'],.009)
box('Backpack_Flap',(0,-.425,1.573),(.442,.037,.041),['pouch_flap'],.006)
for side,s in [('L',-1),('R',1)]:
    box('Backpack_Retention_'+side,(s*.123,-.351,1.102),(.046,.089,.064),['vest_strap'],.005)
    box('Backpack_Shoulder_Strap_'+side,(s*.150,-.256,1.594),(.058,.171,.052),['helmet_trim'],.006)
mapping=[];triangles=0;topology=[]
for o in meshes:
    bone=bone_overrides.get(o.name,original_bones[o.name])
    o.vertex_groups.clear();vg=o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
    assert len(o.modifiers)==1 and o.modifiers[0].type=='ARMATURE' and o.modifiers[0].object==rig
    o['rigid_bone']=bone;o['rigid_weight']=1.0;o['character']='Vanguard'
    for p in o.data.polygons:p.use_smooth=False
    o.data.update();o.data.calc_loop_triangles();triangles+=len(o.data.loop_triangles)
    bm=bmesh.new();bm.from_mesh(o.data)
    assert all(e.is_manifold for e in bm.edges),o.name
    assert bm.calc_volume()>1e-10,o.name
    assert all(f.calc_area()>1e-12 for f in bm.faces),o.name
    bm.free()
    mapping.append({'piece':o.name,'bone':bone,'materials':[m.name for m in o.data.materials],'vertices':len(o.data.vertices),'rebuilt':o.name in rebuilt})
actual={b.name:b.parent.name if b.parent else '' for b in rig.data.bones}
assert actual=={b['name']:b['parent'] for b in ref['bones']} and len(actual)==53
coords=[o.matrix_world@v.co for o in meshes for v in o.data.vertices]
bounds=[[min(v[i] for v in coords) for i in range(3)],[max(v[i] for v in coords) for i in range(3)]]
assert abs(bounds[0][2])<1e-6 and abs(bounds[1][2]-2.025)<1e-5
assert triangles<6000
used={m.name for o in meshes for m in o.data.materials};assert len(used)==35,(len(used),used)
report={'blender':bpy.app.version_string,'character':'Vanguard','height_m':2.025,'bone_count':53,'mesh_count':104,'triangles':triangles,'material_count':len(used),'base_pose':'T-pose','animations_in_main_glb':0,'bounds_blender_m':bounds,'rebuilt_pieces':rebuilt,'mapping':mapping,'bones':[],'original_sha256':hashes,'palette_srgb_hex':palette,'reference':'reference_vanguard_back.png','design_authorization':'User approved Recruit face/front as basis; heavier olive armor and hanging backpack','topology':'All pieces manifold, positive volume, nondegenerate faces','notes':['Same exact skeleton rest as approved Recruit; compatible external UAL library can be reused','Existing Assault Rifle is replaceable placeholder, not a new machine gun','Gloves remain rigid; original finger bones retained']}
for b in rig.data.bones:
    w=rig.matrix_world@b.head_local;t=rig.matrix_world@b.tail_local
    report['bones'].append({'name':b.name,'parent':b.parent.name if b.parent else '', 'head_global_godot_m':[w.x,w.z,-w.y],'tail_global_godot_m':[t.x,t.z,-t.y]})
recruit_report=json.load(open(os.path.join(ROOT,'recruit_v03_work','rig_validation.json')))
report['hold_pose']=recruit_report['hold_pose'];report['hip_motion_scale']=recruit_report['hip_motion_scale']
cam,studio=setup_studio(900,20)
for o in studio.objects:
    if o.type=='LIGHT':o.location*=2.025/1.6;o.data.energy*=(2.025/1.6)**2
    o.hide_set(True)
cam.location=(-4,6,3);look_at(cam,(0,0,1));cam.data.ortho_scale=2.65
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);bpy.context.view_layer.objects.active=rig
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Horde_Braker_Vanguard_v01_rigged.blend'))
bpy.ops.object.select_all(action='DESELECT')
for o in meshes+[rig,muzzle]:o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'Horde_Braker_Vanguard_v01_rigged.glb'),export_format='GLB',use_selection=True,export_yup=True,export_normals=True,export_texcoords=False,export_materials='EXPORT',export_cameras=False,export_lights=False,export_animations=False,export_extras=True,export_def_bones=False)
json.dump(report,open(os.path.join(WORK,'rig_validation.json'),'w'),indent=2)
assert all(hashlib.sha256(open(os.path.join(ROOT,n),'rb').read()).hexdigest()==sha for n,sha in hashes.items())
print('VANGUARD BUILT',len(rebuilt),'rebuilt pieces;',triangles,'triangles; 53 bones; 104 meshes; 35 materials',flush=True)
