"""Build five original weapon-specific arm/hand variants. SPDX-License-Identifier: CC0-1.0
Run in Blender 5.x: blender --background --factory-startup --python build_weapon_grips.py
Uses the adjacent original arm builder and project weapon GLBs as fitting gauges.
No weapon meshes are included in the exported arm assets.
"""
import argparse
import importlib.util
import json
import math
from pathlib import Path
import sys
import bpy
import bmesh
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent
SOURCES = ROOT/'source'
WEAPONS = {
    'rifle': dict(file='assault_rifle', left='Handguard', center=.105, z=-.260, end=76, shoulder=.300),
    'smg': dict(file='smg', left='Wide polymer forearm', center=.095, z=-.230, end=55, shoulder=.300),
    'machine_gun': dict(file='machine_gun', left='Lower polymer handguard', center=.086, z=-.350, end=35, shoulder=.240),
    'shotgun': dict(file='shotgun', left='Grooved walnut pump slide', center=.037, z=-.335, end=40, shoulder=.260),
    'marksman': dict(file='marksman', left='Walnut ventilated handguard', center=.123, z=-.310, end=60, shoulder=.270),
}
BUILD = None
SPEC = None
LEFT = RIGHT = WHOLE = None
R_TRANSFORM = None
CONTACTS = []
FACE_NAMES = []


def fresh_builder():
    path = ROOT.parent/'arms_firstperson_original/build_arms.py'
    module_spec = importlib.util.spec_from_file_location('original_arm_builder', path)
    module = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(module)
    return module


def tree(objects, transform=None):
    vertices, faces = [], []
    for obj in objects:
        offset = len(vertices)
        points = [Vector((p.x, p.z, -p.y)) for p in (obj.matrix_world @ v.co for v in obj.data.vertices)]
        vertices.extend((transform @ p if transform else p) for p in points)
        faces.extend(tuple(offset+i for i in face.vertices) for face in obj.data.polygons)
    assert faces
    return BVHTree.FromPolygons(vertices, faces)


def gauge(weapon):
    global LEFT, RIGHT, WHOLE, R_TRANSFORM, FACE_NAMES
    path = ROOT.parents[1]/'weapons/tactical_original'/(SPEC['file']+'.glb')
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    LEFT = tree([obj for obj in objects if obj.name == SPEC['left']])
    R_TRANSFORM = Matrix.Translation(Vector((0, -.012, .025))) @ Matrix.Rotation(math.radians(-65), 4, 'X') if weapon == 'shotgun' else Matrix.Identity(4)
    right_names = ('Walnut shoulder stock',) if weapon == 'shotgun' else (('Walnut grip web',) if weapon == 'marksman' else ('Pistol grip', 'Grip moulded insert', 'Grip traction rib'))
    RIGHT = tree([obj for obj in objects if obj.name.startswith(right_names)], R_TRANSFORM.inverted())
    WHOLE = tree(objects)
    FACE_NAMES = [obj.name for obj in objects for face in obj.data.polygons]
    origin = Vector((0, -.2, SPEC['z']))
    hit = LEFT.ray_cast(origin, Vector((0, 1, 0)), .5)
    assert hit[0] is not None, weapon
    target = hit[0].copy()
    for obj in list(bpy.context.scene.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    # The weapon is a transient fitting gauge; even orphaned mesh/material
    # datablocks must be absent from the saved arm-only source file.
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for item in list(collection):
            if item.users == 0:
                collection.remove(item)
    return target


def radial(surface, center, direction, thickness, name, fraction):
    direction = Vector(direction).normalized()
    hit, normal, _, _ = surface.ray_cast(center+direction*.4, -direction, .8)
    if hit is None or normal.dot(direction) < .2 or (hit-center).dot(direction) < .004:
        # A narrow vent can cross the ray. Seat the pad on its real rim.
        for offset in (.006, -.006, .011, -.011, .018, -.018):
            displaced = center+Vector((0, 0, offset))
            hit, normal, _, _ = surface.ray_cast(displaced+direction*.4, -direction, .8)
            if hit is not None and normal.dot(direction) >= .2 and (hit-center).dot(direction) >= .004:
                break
        assert hit is not None and normal.dot(direction) >= .2 and (hit-center).dot(direction) >= .004, (name, list(center), list(direction))
        # The broad finger pad bridges the slot; keep its centreline straight
        # across the furniture rather than forcing it into the narrow opening.
        hit.z = center.z
    assert hit is not None, (name, list(center), list(direction))
    # Tube depth tapers along the finger. A small mounting clearance allows
    # for straight phalanx chords between sampled contacts on curved furniture.
    radius = thickness*(1-.25*fraction)*.5
    point = hit+normal*(radius+.0012)
    CONTACTS.append(dict(finger=name, point_gun_m=list(R_TRANSFORM @ hit if name.endswith('_R') else hit),
        normal_gun=list(R_TRANSFORM.to_3x3() @ normal if name.endswith('_R') else normal)))
    return point


def right_point(point):
    return R_TRANSFORM @ Vector(point)


def palms_and_sleeves():
    b = BUILD
    for side in ('R', 'L'):
        w, e = b.WRISTS[side], b.elbow(side)
        direction = (w-e).normalized()
        b.JOINTS[side] = dict(shoulder=b.SHOULDERS[side], elbow=e, wrist=w)
        ts = [0, .035, .100, .170, .230, .270, .280]
        obj = b.tube('Arm_'+side, [e+direction*t for t in ts],
            [.098, .105, .096, .082, .066, .061, .062],
            [.090, .094, .086, .074, .060, .055, .056], 'sleeve_cloth', (1, 0, 0))
        for t in (.075, .180, .263, .276):
            width = .101-.15*t
            b.add(obj, b.tube('Plain cuff', [e+direction*(t-.003), e+direction*(t+.003)],
                [width, width], [width*.9, width*.9], 'sleeve_cloth', (1, 0, 0)))
        b.add(obj, b.tube('Bare wrist', [e+direction*t for t in (.268, .291, .300, .316)],
            [.052, .051, .051, .049], [.046, .045, .045, .043], 'skin', (1, 0, 0)))
        if side == 'L':
            p = b.PALM_L
            b.add(obj, b.tube('Glove heel', [w, p+Vector((-.026, -.024, .024)), p+Vector((-.010, -.014, .009))],
                [.051, .057, .066], [.044, .041, .035], 'glove', (1, 0, 0)))
            b.add(obj, b.box(p+Vector((0, -.013, 0)), (.088, .026, .092), 'glove', .003))
        else:
            # Right palm stays beside the grip. The shotgun rotates this solid
            # into a conventional stock-wrist grasp, not a pistol-grip pose.
            palm = b.box((.032, -.028, .020), (.027, .081, .061), 'glove', .003)
            for vertex in palm.data.vertices:
                vertex.co = b.B(right_point(b.G(vertex.co)))
            b.add(obj, palm)
            b.add(obj, b.tube('Right glove heel', [w, right_point((.048, -.050, .038)), right_point((.039, -.030, .028))],
                [.042, .035, .031], [.040, .040, .035], 'glove', (1, 0, 0)))
        obj.name = 'Arm_'+side
        b.CORES[side] = obj


def fingers(weapon):
    b = BUILD
    for name, offset in [('Index', -.034), ('Middle', -.011), ('Ring', .012), ('Little', .034)]:
        center = Vector((0, SPEC['center'], SPEC['z']+offset))
        angles = [-58, -20, 15, SPEC['end']-10, SPEC['end']]
        points = [radial(LEFT, center, (math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0),
            .021, name+'_L', i/4) for i, angle in enumerate(angles)]
        # Root is seated in the outer palm, not floating beside the cuff.
        points[0] = b.PALM_L+Vector((.031, -.012, offset))
        b.make_finger('L', name, points, .019 if name != 'Little' else .017, .021)
    p = b.PALM_L
    thumb_z = p.z+.017
    angles = [212, 178, 150, 180-SPEC['end']]
    points = [radial(LEFT, Vector((0, SPEC['center'], thumb_z)),
        (math.cos(math.radians(angle)), math.sin(math.radians(angle)), 0), .025, 'Thumb_L', i/3)
        for i, angle in enumerate(angles)]
    points[0] = p+Vector((-.031, -.014, .019))
    b.make_finger('L', 'Thumb', points, .024, .025)
    for name, height in [('Middle', -.014), ('Ring', -.038), ('Little', -.061)]:
        # Measure a section through the actual pistol grip / stock wrist.
        a = RIGHT.ray_cast(Vector((0, height, -.45)), Vector((0, 0, 1)), .9)[0]
        c = RIGHT.ray_cast(Vector((0, height, .45)), Vector((0, 0, -1)), .9)[0]
        assert a is not None and c is not None, (weapon, name)
        center = (a+c)*.5
        angles = [20, 62, 106, 148, 176]
        points = [radial(RIGHT, center, (math.cos(math.radians(angle)), 0, -math.sin(math.radians(angle))),
            .022, name+'_R', i/4) for i, angle in enumerate(angles)]
        b.make_finger('R', name, [right_point(point) for point in points], .018 if name != 'Little' else .017, .022)
    if weapon == 'shotgun':
        index = [(.033, .001, .028), (.035, .002, -.015), (.033, .001, -.051), (.029, -.003, -.083)]
        thumb = [(.033, .023, .075), (.013, .055, .066), (-.017, .052, .048), (-.033, .021, .030)]
    else:
        h = .038 if weapon == 'marksman' else (.017 if weapon == 'machine_gun' else .011)
        index = [(.032, .005, .008), (.035, h, -.022), (.034, h+.002, -.055), (.030, h, -.083)]
        thumb = [(.032, -.008, .049), (.014, .005, .064), (-.014, .006, .060), (-.029, -.011, .027)]
        if weapon == 'marksman':
            thumb = [(.032, .006, .046), (.014, .032, .083), (-.017, .030, .079), (-.030, .009, .043)]
    b.make_finger('R', 'Index', index, .019, .022)
    b.make_finger('R', 'Thumb', thumb, .024, .025)


def audit_fingers():
    result = {}
    for (side, name), obj in BUILD.FINGERS.items():
        values = []
        worst = None
        # This audit runs in authored gun space before the inverse bind step.
        for vertex in obj.data.vertices:
            point = Vector(BUILD.G(vertex.co))
            hit = WHOLE.find_nearest(point)
            if hit is not None:
                distance = (point-hit[0]).dot(hit[1])
                values.append(distance)
                if worst is None or distance < worst['distance_m']:
                    worst = dict(distance_m=distance, point_gun_m=list(point), part=FACE_NAMES[hit[2]])
        result[name+'_'+side] = dict(minimum_signed_vertex_clearance_m=min(values),
            deepest_vertex_penetration_m=max(0, -min(values)), worst_vertex=worst)
    return result


def seat_contact_pads():
    """Flatten local glove pads against the actual furniture, with clearance.

    The authored phalanx paths remain the shape guide. Only shallow local
    collisions are corrected; a badly placed finger must be re-authored.
    """
    b = BUILD
    for obj in list(b.FINGERS.values())+list(b.CORES.values()):
        finger = obj in b.FINGERS.values()
        bm = bmesh.new(); bm.from_mesh(obj.data)
        for iteration in range(3):
            for vertex in bm.verts:
                if not finger and not any(face.material_index == 1 for face in vertex.link_faces):
                    continue
                point = Vector(b.G(vertex.co))
                for _ in range(8):
                    hit = WHOLE.find_nearest(point)
                    signed = (point-hit[0]).dot(hit[1])
                    if signed >= .0005 or hit[3] > .02:
                        break
                    assert signed > -.012, (obj.name, list(point), signed, FACE_NAMES[hit[2]])
                    point += hit[1]*(.0006-signed)
                vertex.co = b.B(point)
            if iteration == 2:
                break
            # Add only contact-edge samples, avoiding an arbitrary triangle pad.
            edges = []
            for edge in bm.edges:
                if not finger and not any(face.material_index == 1 for face in edge.link_faces):
                    continue
                point = Vector(b.G((edge.verts[0].co+edge.verts[1].co)*.5))
                hit = WHOLE.find_nearest(point)
                if hit[3] < .012 and (point-hit[0]).dot(hit[1]) < -.0004:
                    edges.append(edge)
            if not edges:
                break
            bmesh.ops.subdivide_edges(bm, edges=edges, cuts=1, use_grid_fill=False)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(obj.data); bm.free(); obj.data.update()


def build(weapon):
    global BUILD, SPEC, CONTACTS
    BUILD = fresh_builder(); b = BUILD; SPEC = WEAPONS[weapon]; CONTACTS = []
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    for collection in (bpy.data.meshes, bpy.data.materials, bpy.data.armatures, bpy.data.cameras, bpy.data.lights):
        for item in list(collection):
            if item.users == 0: collection.remove(item)
    b.PALM_L = gauge(weapon)
    b.ROOT = ROOT/weapon; b.ROOT.mkdir(parents=True, exist_ok=True)
    b.WRISTS['L'] = b.PALM_L+Vector((-.052, -.047, .052))
    b.SHOULDERS['L'].z = SPEC['shoulder']
    b.WRISTS['R'] = Vector((.045, -.045, .120)) if weapon == 'shotgun' else Vector((.035, -.065, .075))
    b.HAND_TARGET_R = right_point((.032, -.025, .016))
    bpy.context.scene.unit_settings.system = 'METRIC'; bpy.context.scene.unit_settings.scale_length = 1
    bpy.context.preferences.filepaths.save_version = 0; bpy.context.preferences.filepaths.file_preview_type = 'NONE'
    b.materials(); palms_and_sleeves(); fingers(weapon); seat_contact_pads()
    # A small closed palm pad retains an exact authored contact landmark even
    # when the surrounding glove conforms to sloping or grooved furniture.
    b.add(b.CORES['L'], b.box(b.PALM_L+Vector((0, -.002, 0)), (.008, .004, .008), 'glove', .0005))
    geometry = b.finalize(); contact_audit = audit_fingers(); rig = b.rig_and_bind()
    assert max(item['deepest_vertex_penetration_m'] for item in contact_audit.values()) < .0015, contact_audit
    assert max(item['minimum_signed_vertex_clearance_m'] for item in contact_audit.values()) < .004, contact_audit
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(b.ROOT/'arms_firstperson.glb'), export_format='GLB', use_selection=True,
        export_yup=True, export_apply=True, export_texcoords=True, export_normals=True, export_tangents=True,
        export_skins=True, export_def_bones=False, export_leaf_bone=False, export_armature_object_remove=False,
        export_rest_position_armature=False, export_current_frame=True, export_animations=False,
        export_cameras=False, export_lights=False, export_materials='EXPORT', export_extras=False)
    b.validate(geometry, rig)
    SOURCES.mkdir(exist_ok=True)
    (SOURCES/'.gdignore').touch()
    b.activate(b.RIG); bpy.ops.wm.save_as_mainfile(filepath=str(SOURCES/('arms_'+weapon+'.blend')))
    fit = dict(weapon=weapon, support_gun_m=list(b.PALM_L), right_hand_target_gun_m=list(b.HAND_TARGET_R),
        source_weapon_file=SPEC['file']+'.glb', shoulder_left_gun_m=list(b.SHOULDERS['L']),
        finger_surface_audit=contact_audit, sampled_contacts=CONTACTS)
    (b.ROOT/'grip_validation.json').write_text(json.dumps(fit, indent=2))
    print('GRIP BUILT '+weapon+' '+json.dumps(dict(support=list(b.PALM_L), audit=contact_audit)), flush=True)
    return fit


def main():
    parser = argparse.ArgumentParser(); parser.add_argument('--weapon', choices=list(WEAPONS))
    args = parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    profile_file = ROOT/'grip_profiles.json'
    profiles = json.loads(profile_file.read_text()) if args.weapon and profile_file.exists() else {}
    for weapon in ([args.weapon] if args.weapon else WEAPONS):
        profiles[weapon] = build(weapon)
    (ROOT/'grip_profiles.json').write_text(json.dumps(profiles, indent=2))


if __name__ == '__main__': main()
