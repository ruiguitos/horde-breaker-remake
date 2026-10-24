"""Offline visual candidates. Blender 5.x; no downloads or game integration.

SPDX-License-Identifier: CC0-1.0 (new geometry, textures and script).
The Recruit skeleton is the project's existing UAL-compatible CC0 rig.
Run: blender --background --python-exit-code 1 --python build_target.py -- --only recruit
"""
import argparse
import math
from pathlib import Path
import sys

import bpy
import bmesh
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
MATERIALS = {}


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def image_file(folder, name, rgb, color=True):
    size = rgb.shape[0]
    image = bpy.data.images.new(name, width=size, height=size, alpha=False)
    image.colorspace_settings.name = 'sRGB' if color else 'Non-Color'
    rgba = np.ones((size, size, 4), np.float32)
    rgba[:, :, :3] = np.clip(rgb, 0, 1)
    image.pixels.foreach_set(rgba.ravel())
    image.filepath_raw = str(folder/(name+'.png'))
    image.file_format = 'PNG'
    image.save()
    image.pack()
    return image


def material(folder, name, base, kind='cloth', size=1024, metal=0., rough=.75):
    """Original seamless maps, including separate channels and packed glTF ORM."""
    rng = np.random.default_rng(sum(map(ord, name)))
    y, x = np.mgrid[0:size, 0:size]/size
    grain = rng.random((size, size), dtype=np.float32)-.5
    broad = np.zeros_like(x)
    for i in range(7):
        fx, fy = rng.integers(1, 20, 2)
        broad += np.sin(math.tau*(fx*x+fy*y)+rng.random()*math.tau)/(i+2)
    broad /= 2.5
    wear = np.clip((broad-.12)*1.5, 0, 1)
    if kind in ['cloth', 'webbing']:
        count = 190 if kind == 'cloth' else 95
        weave = (np.sin(math.tau*x*count)*np.sin(math.tau*y*count))
        ripstop = ((np.cos(math.tau*x*18)>.97) | (np.cos(math.tau*y*18)>.97)).astype(float)
        height = .43+.045*weave+.012*grain+.015*ripstop
        value = 1+.13*broad+.10*grain+.035*weave+.04*ripstop
        # Low-contrast, original field camouflage; no branded pattern copied.
        if kind == 'cloth':
            camo = np.sin(math.tau*(3*x+2*y)+np.sin(math.tau*5*y))
            value += .15*np.tanh(3*camo)
    elif kind == 'skin':
        height = .5+.045*grain+.006*np.sin(math.tau*x*210)
        value = 1+.075*broad+.055*grain
    elif kind == 'metal':
        scratches = np.maximum(0, np.sin(math.tau*(x*233+y*7))-.996)*80
        height = .5+.008*grain-.008*scratches
        value = 1+.08*broad+.07*grain+.20*scratches
    else:
        height = .5+.025*grain+.01*np.sin(math.tau*x*110)*np.sin(math.tau*y*110)
        value = 1+.10*broad+.065*grain
    albedo = np.asarray(base)[None, None, :]*value[:, :, None]
    dust = wear[:, :, None]*.045
    albedo = albedo*(1-dust)+np.array([.48,.41,.30])*dust
    roughness = np.clip(rough+.08*broad+.045*grain-wear*.07, .12, 1)
    metalness = np.full_like(x, metal)
    dx = (np.roll(height, -1, axis=1)-np.roll(height, 1, axis=1))*1.7
    dy = (np.roll(height, -1, axis=0)-np.roll(height, 1, axis=0))*1.7
    normal = np.stack((-dx, -dy, np.ones_like(dx)), axis=2)
    normal /= np.linalg.norm(normal, axis=2, keepdims=True)
    normal = normal*.5+.5
    folder.mkdir(parents=True, exist_ok=True)
    images = dict(albedo=image_file(folder, name+'_albedo', albedo),
                  roughness=image_file(folder, name+'_roughness', np.repeat(roughness[:, :, None], 3, axis=2), False),
                  metalness=image_file(folder, name+'_metalness', np.repeat(metalness[:, :, None], 3, axis=2), False),
                  normal=image_file(folder, name+'_normal', normal, False),
                  orm=image_file(folder, name+'_orm', np.stack((np.ones_like(x), roughness, metalness), axis=2), False))
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.diffuse_color = (*base, 1)
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes.get('Principled BSDF')
    for channel in ['albedo', 'normal', 'orm']:
        node = nodes.new('ShaderNodeTexImage')
        node.image = images[channel]
        node.label = channel
        node.location = (-650, {'albedo': 250, 'normal': -250, 'orm': 0}[channel])
        if channel == 'albedo':
            links.new(node.outputs['Color'], bsdf.inputs['Base Color'])
        elif channel == 'normal':
            n = nodes.new('ShaderNodeNormalMap')
            n.inputs['Strength'].default_value = .40
            links.new(node.outputs['Color'], n.inputs['Color'])
            links.new(n.outputs['Normal'], bsdf.inputs['Normal'])
        else:
            split = nodes.new('ShaderNodeSeparateColor')
            links.new(node.outputs['Color'], split.inputs['Color'])
            links.new(split.outputs['Green'], bsdf.inputs['Roughness'])
            links.new(split.outputs['Blue'], bsdf.inputs['Metallic'])
    if kind == 'cloth':
        bsdf.inputs['Sheen Weight'].default_value = .18
    if kind == 'skin':
        bsdf.inputs['Subsurface Weight'].default_value = .08
    MATERIALS[name] = mat
    return mat


def unwrap(obj):
    activate(obj)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.025)
    bpy.ops.object.mode_set(mode='OBJECT')


def rounded_box(name, centre, size, mat, rig, bone, radius=.003):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre)
    obj = bpy.context.object
    obj.name, obj.scale = name, size
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bevel = obj.modifiers.new('Sewn edges', 'BEVEL')
    bevel.width, bevel.segments = min(radius, min(size)*.22), 3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    obj.data.materials.append(mat)
    bind(obj, rig, bone)
    unwrap(obj)
    return obj


def line(name, points, thickness, mat, rig, bone):
    data = bpy.data.curves.new(name, 'CURVE')
    data.dimensions = '3D'
    data.bevel_depth, data.bevel_resolution = thickness, 2
    spline = data.splines.new('POLY')
    spline.points.add(len(points)-1)
    for p, co in zip(spline.points, points):
        p.co = (*co, 1)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    activate(obj)
    bpy.ops.object.convert(target='MESH')
    obj = bpy.context.object
    obj.data.materials.append(mat)
    bind(obj, rig, bone)
    unwrap(obj)
    return obj


def boot(side, x, rig, leather, rubber, nylon):
    profile = [(-.135,.025,.16),(-.125,.070,.22),(-.075,.085,.265),
               (0,.088,.245),(.070,.091,.17),(.15,.092,.11),(.21,.075,.09),(.24,.025,.07)]
    verts = []
    count = 24
    for y, width, top in profile:
        for i in range(count):
            a = math.tau*i/count
            verts.append((x+width*math.cos(a), y, .035+(top-.035)*(.5+.5*math.sin(a))))
    faces = [tuple(range(count-1,-1,-1))]
    faces += [(j*count+i,j*count+(i+1)%count,(j+1)*count+(i+1)%count,(j+1)*count+i)
              for j in range(len(profile)-1) for i in range(count)]
    faces.append(tuple((len(profile)-1)*count+i for i in range(count)))
    mesh = bpy.data.meshes.new('Boot leather')
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new('Boot_'+side+'_stitched_upper', mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(leather)
    for p in mesh.polygons:
        p.use_smooth = True
    bind(obj, rig, 'DEF-foot.'+side)
    unwrap(obj)
    # Continuous sole reaches exactly z=0; no floating boot or detached vamp.
    rounded_box('Boot_'+side+'_sole', (x,.045,.022), (.185,.38,.044), rubber, rig, 'DEF-foot.'+side, .014)
    for j in range(7):
        y = -.055+j*.025
        z = .258-max(0,y)*.72
        line('Boot_'+side+'_lace_'+str(j), [(x-.036,y,z),(x+.036,y+.018,z-.007)], .0022, nylon, rig, 'DEF-foot.'+side)
        line('Boot_'+side+'_lace_cross_'+str(j), [(x+.036,y,z),(x-.036,y+.018,z-.007)], .0022, nylon, rig, 'DEF-foot.'+side)
    for y in [-.08,-.025,.03,.085,.14,.19]:
        rounded_box('Boot_'+side+'_tread', (x,y,.005), (.170,.025,.010), rubber, rig, 'DEF-foot.'+side, .002)


def bind(obj, rig, bone):
    group = obj.vertex_groups.new(name=bone)
    group.add(list(range(len(obj.data.vertices))), 1., 'REPLACE')
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()
    modifier = obj.modifiers.new('UAL skin', 'ARMATURE')
    modifier.object = rig


def smooth_mesh(obj, subdiv=1):
    activate(obj)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-6)
    bmesh.ops.dissolve_limit(bm, angle_limit=.001, verts=list(bm.verts), edges=list(bm.edges))
    bm.to_mesh(obj.data)
    bm.free()
    if subdiv:
        mod = obj.modifiers.new('Soft sewn silhouette', 'SUBSURF')
        mod.subdivision_type = 'CATMULL_CLARK'
        mod.levels = subdiv
        # Geometry modifications precede the armature, preserving skin weights.
        bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    for face in obj.data.polygons:
        face.use_smooth = True


def tube(name, start, end, radii, mat, rig, bone, folds=.003, sections=26, sides=20):
    a, b = Vector(start), Vector(end)
    axis = (b-a).normalized()
    u = axis.cross(Vector((0, 1, 0))).normalized()
    v = axis.cross(u).normalized()
    verts = []
    for j in range(sections+1):
        t = j/sections
        bulge = math.sin(math.pi*t)**.6
        radius = radii[0]*(1-t)+radii[1]*t
        for k in range(sides):
            angle = math.tau*k/sides
            envelope = .35+.65*abs(2*t-1)
            wrinkle = folds*math.sin(t*math.pi*7+math.sin(angle*2)*1.1)*bulge*envelope
            r = radius*(.90+.10*bulge)+wrinkle
            p = a.lerp(b, t)+u*(math.cos(angle)*r)+v*(math.sin(angle)*r*.90)
            verts.append(p)
    faces = [tuple(range(sides-1, -1, -1))]
    faces += [(j*sides+k, j*sides+(k+1)%sides, (j+1)*sides+(k+1)%sides, (j+1)*sides+k)
              for j in range(sections) for k in range(sides)]
    faces.append(tuple(sections*sides+k for k in range(sides)))
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for p in data.polygons:
        p.use_smooth = True
    bind(obj, rig, bone)
    unwrap(obj)
    return obj


def ellipsoid(name, centre, scale, mat, rig, bone, segments=40, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=centre)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    activate(obj)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    for p in obj.data.polygons:
        p.use_smooth = True
    bind(obj, rig, bone)
    return obj


def remove(obj):
    bpy.data.objects.remove(obj, do_unlink=True)


def prepare_scene():
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.
    for obj in list(scene.objects):
        if obj.type in ['CAMERA', 'LIGHT'] or obj.name.startswith('Studio_'):
            remove(obj)


def save_export(folder, name):
    prepare_scene()
    bpy.context.scene.camera = None
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    # Triangulate before tangent generation: closed caps otherwise have ngons.
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        activate(obj)
        mod = obj.modifiers.new('Export triangles', 'TRIANGULATE')
        if len(obj.modifiers)>1:
            bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.object.select_all(action='SELECT')
    source = folder/'source'
    source.mkdir(exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(folder/(name+'.glb')), export_format='GLB',
        use_selection=True, export_yup=True, export_apply=True,
        export_texcoords=True, export_normals=True, export_tangents=True,
        export_skins=True, export_def_bones=False, export_leaf_bone=False,
        export_rest_position_armature=True, export_current_frame=True,
        export_animations=False, export_cameras=False, export_lights=False,
        export_materials='EXPORT', export_extras=False)


def render(folder, name, subject, target, ortho, views):
    """Transient studio: saved sources and GLBs never contain these nodes."""
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.samples = 32
    scene.cycles.use_denoising = True
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 1400 if subject == 'recruit' else 800
    scene.render.resolution_percentage = 100
    scene.world = bpy.data.worlds.new('Transient studio')
    scene.world.use_nodes = True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value = (.10,.13,.16,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value = .45
    scene.view_settings.view_transform = 'AgX'
    def look(obj):
        obj.rotation_euler = (Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()
    for loc, power, size in [((3,4,5),750,3),((-3,2,3),500,3),((1,-4,4),900,2)]:
        bpy.ops.object.light_add(type='AREA', location=loc)
        light = bpy.context.object
        light.data.energy, light.data.size = power, size
        look(light)
    bpy.ops.object.camera_add()
    cam = bpy.context.object
    scene.camera = cam
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = ortho
    for label, loc in views:
        cam.location = loc
        look(cam)
        scene.render.filepath = str(folder/(name+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)


def recruit():
    folder = ROOT/'recruit'
    folder.mkdir(exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=str(PROJECT/'assets/models/characters/recruit/Horde_Braker_Recruit_v03_entrega/Horde_Braker_Recruit_v03_rigged.blend'))
    prepare_scene()
    rig = bpy.data.objects['Rig']
    rig.animation_data_clear()
    for action in list(bpy.data.actions):
        bpy.data.actions.remove(action)
    for bone in rig.pose.bones:
        bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    tex = folder/'textures'
    cloth = material(tex, 'field_ripstop', (.13,.15,.105), 'cloth')
    nylon = material(tex, 'carrier_cordura', (.10,.11,.075), 'webbing')
    rubber = material(tex, 'tread_rubber', (.055,.060,.052), 'rubber', 512, rough=.88)
    leather = material(tex, 'boot_leather', (.060,.045,.035), 'leather', rough=.68)
    polymer = material(tex, 'helmet_composite', (.08,.10,.06), 'polymer', rough=.78)
    steel = material(tex, 'hardware_steel', (.29,.30,.28), 'metal', 512, .85, .42)
    skin = material(tex, 'weathered_skin', (.52,.32,.23), 'skin', rough=.53)
    eye = material(tex, 'eye_dark', (.045,.050,.043), 'polymer', 256, rough=.24)
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH':
            continue
        if obj.name.startswith('Rifle'):
            remove(obj)
            continue
        old = [m.name.lower() for m in obj.data.materials]
        for i, name in enumerate(old):
            mat = skin if any(x in name for x in ['skin','nose']) else (
                eye if any(x in name for x in ['eyes','brow','mouth','hair']) else (
                leather if name.startswith('boot') else (rubber if name=='sole' else (
                steel if name.startswith('metal') else (polymer if name.startswith(('helmet','knee','plate')) else (
                cloth if name.startswith(('cloth','pants')) else nylon))))))
            obj.data.materials[i] = mat
        if obj.name.startswith(('Head_Face','Face_', 'Helmet_Crown','Helmet_Brim','Helmet_Side_Shield','Head_Sideburn', 'Head_Ear_', 'Neck_', 'Boot_', 'Glove_', 'Helmet_Ear_Protection', 'Knee_Strap_', 'Kneepad_')):
            remove(obj)
            continue
        if obj.name.startswith(('Arm_Upper_', 'Arm_Forearm_', 'Leg_Thigh_', 'Leg_Shin_', 'Arm_Elbow_', 'Arm_Shoulder_Facet_')) and 'Patch' not in obj.name:
            remove(obj)
            continue
        smooth_mesh(obj, 1 if obj.name.startswith(('Boot_', 'Glove_', 'Backpack_', 'Vest_','Uniform_','Thigh_')) else 0)
        unwrap(obj)
    world = rig.matrix_world
    bonepoint = lambda name: world @ rig.data.bones[name].head_local
    for side in ['L','R']:
        shoulder, elbow, wrist = [bonepoint('DEF-'+part+'.'+side) for part in ['upper_arm','forearm','hand']]
        hip, knee, ankle = [bonepoint('DEF-'+part+'.'+side) for part in ['thigh','shin','foot']]
        tube('Sleeve_upper_'+side, shoulder, elbow, (.100,.085), cloth, rig, 'DEF-upper_arm.'+side, .0018)
        tube('Sleeve_fore_'+side, elbow, wrist, (.088,.061), cloth, rig, 'DEF-forearm.'+side, .0018)
        tube('Trouser_thigh_'+side, hip+Vector((0,0,.045)), knee-Vector((0,0,.025)), (.112,.094), cloth, rig, 'DEF-thigh.'+side, .0022)
        tube('Trouser_calf_'+side, knee+Vector((0,0,.030)), ankle+Vector((0,0,.025)), (.091,.074), cloth, rig, 'DEF-shin.'+side, .0022)
        boot(side, ankle.x, rig, leather, rubber, nylon)
        ellipsoid('Kneepad_'+side, (knee.x,.095,knee.z-.015), (.077,.033,.079), polymer, rig, 'DEF-shin.'+side, 32, 16)
        # Real finger chains use the original 30 finger bones, without new joints.
        outward = (wrist-elbow).normalized()
        palm = ellipsoid('Glove_'+side+'_Palm', wrist+outward*.037, (.060,.044,.039), leather, rig, 'DEF-hand.'+side, 32, 16)
        for finger in ['f_index','f_middle','f_ring','f_pinky','thumb']:
            for segment in [1,2,3]:
                name = 'DEF-'+finger+'.%02d.' % segment+side
                bone = rig.data.bones[name]
                radius = .008 if finger=='f_pinky' else .010
                tube('Glove_'+name, world@bone.head_local, world@bone.tail_local, (radius,radius*.86), leather, rig, name, .0003, 4, 12)
    ellipsoid('Neck_anatomical', (0,.012,1.622), (.061,.062,.090), skin, rig, 'DEF-neck', 32, 20)
    # Anatomical head silhouette and subdued facial structure, all on DEF-head.
    head = ellipsoid('Head_anatomical', (0,.015,1.782), (.108,.125,.143), skin, rig, 'DEF-head', 64, 40)
    for vertex in head.data.vertices:
        p = vertex.co
        lower = max(0., -p.z/.143)
        p.x *= 1-.25*lower
        if p.y > 0:
            p.y += .005*math.exp(-((p.z+.04)/.035)**2)
            for x in [-.045,.045]:
                p.y -= .009*math.exp(-((p.x-x)/.022)**2-((p.z-.02)/.017)**2)
    ellipsoid('Nasal_bridge', (0,.131,1.779), (.014,.024,.034), skin, rig, 'DEF-head', 24, 16)
    ellipsoid('Nose_tip', (0,.149,1.755), (.022,.019,.014), skin, rig, 'DEF-head', 24, 12)
    for side in [-1,1]:
        rounded_box('Goggle_frame_'+str(side), (side*.044,.139,1.805), (.080,.024,.042), rubber, rig, 'DEF-head', .009)
        rounded_box('Goggle_lens_'+str(side), (side*.044,.155,1.805), (.066,.012,.029), eye, rig, 'DEF-head', .006)
        ellipsoid('Ear_'+str(side), (side*.108,.004,1.763), (.020,.027,.045), skin, rig, 'DEF-head', 24, 16)
        ellipsoid('Comms_earcup_'+str(side), (side*.137,-.010,1.761), (.025,.048,.060), polymer, rig, 'DEF-head', 32, 16)
        ellipsoid('Nostril_'+str(side), (side*.014,.159,1.751), (.005,.003,.003), eye, rig, 'DEF-head', 16, 8)
    ellipsoid('Lip_upper', (0,.137,1.719), (.031,.006,.004), skin, rig, 'DEF-head', 24, 10)
    ellipsoid('Lip_shadow', (0,.140,1.715), (.028,.003,.0015), eye, rig, 'DEF-head', 24, 8)
    # Rounded ballistic shell. Bottom rim stays above the eyes and ears.
    rounded_box('Goggle_bridge', (0,.151,1.814), (.018,.017,.010), rubber, rig, 'DEF-head', .003)
    helmet = ellipsoid('Helmet_ballistic_shell', (0,-.005,1.885), (.144,.154,.140), polymer, rig, 'DEF-head', 48, 24)
    bm = bmesh.new()
    bm.from_mesh(helmet.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z<-.057], context='VERTS')
    edge = [e for e in bm.edges if e.is_boundary]
    bmesh.ops.holes_fill(bm, edges=edge, sides=0)
    bm.to_mesh(helmet.data)
    bm.free()
    unwrap(helmet)
    # Sewn webbing and retaining stitches make the carrier readable up close.
    for z in [1.38,1.43,1.48]:
        rounded_box('Carrier_MOLLE_row', (0,.217,z), (.32,.011,.020), nylon, rig, 'DEF-spine.003', .002)
        for x in [-.14,-.10,-.06,-.02,.02,.06,.10,.14]:
            line('Carrier_bar_tack', [(x,.224,z-.007),(x,.224,z+.007)], .00065, cloth, rig, 'DEF-spine.003')
    for x in [-.13,0,.13]:
        rounded_box('Carrier_retention_buckle', (x,.230,1.505), (.025,.012,.024), rubber, rig, 'DEF-spine.003', .003)
    # One skinned mesh with shared PBR slots instead of a draw call per seam.
    body = [o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in body:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(o for o in body if o.name=='Uniform_Torso')
    bpy.ops.object.join()
    bpy.context.object.name = 'Recruit_Realistic_Body'
    save_export(folder, 'recruit_realistic')
    render(folder, 'recruit_realistic', 'recruit', (0,0,1.02), 2.65,
           [('front',(2.8,5,2.45)), ('back',(-3,-5,2.45))])
    print('BUILT Recruit visual candidate', flush=True)


def rifle():
    folder = ROOT/'assault_rifle'
    folder.mkdir(exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(PROJECT/'assets/models/weapons/tactical_original/assault_rifle.glb'))
    tex = folder/'textures'
    mats = {
        'gunmetal': material(tex, 'gunmetal', (.095,.108,.120), 'metal', 2048, .85, .40),
        'steel': material(tex, 'steel', (.31,.33,.35), 'metal', 1024, .98, .28),
        'polymer': material(tex, 'polymer', (.105,.110,.095), 'polymer', 2048, 0., .72),
        'bore': material(tex, 'bore', (.018,.020,.023), 'metal', 256, .5, .85),
    }
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH':
            continue
        for i, mat in enumerate(obj.data.materials):
            obj.data.materials[i] = mats[mat.name.split('.')[0]]
        if not obj.data.uv_layers:
            unwrap(obj)
    for mat in list(bpy.data.materials):
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    for name, mat in mats.items():
        mat.name = name
    save_export(folder, 'assault_rifle_realistic')
    render(folder, 'assault_rifle_realistic', 'rifle', (0,.10,.025), 1.18,
           [('side',(2,1.4,.8)), ('detail',(-1.6,1.3,.65))])
    print('BUILT Rifle visual candidate', flush=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--only', choices=['recruit','rifle'], required=True)
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    {'recruit': recruit, 'rifle': rifle}[args.only]()
