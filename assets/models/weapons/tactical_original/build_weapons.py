"""Original game props; Blender 5.x, built-in modules only.

Run: blender --background --factory-startup --python build_weapons.py
Optional after --: --only assault_rifle --no-render
Coordinates during construction: X right, Y forward, Z up. glTF converts to
X right, Y up, -Z forward. Dimensions below are visual prop dimensions only.
SPDX-License-Identifier: CC0-1.0
"""
import argparse
import json
import math
from pathlib import Path
import struct
import sys

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parent
sys.path.insert(0,str(ROOT))
TARGETS = dict(assault_rifle=.96, smg=.74, machine_gun=1.04, shotgun=1.04, marksman=1.12)
PARTS = []
MATS = {}


def activate(obj):
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def finish(obj, name, mat, bevel=0, segments=2):
    obj.name = name
    activate(obj)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if bevel:
        bevel = min(bevel, min(obj.dimensions)*.20)
        mod = obj.modifiers.new('Machined edge radii', 'BEVEL')
        mod.width = bevel
        mod.segments = segments
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.materials.clear()
    obj.data.materials.append(MATS[mat])
    # Smooth continuous curved surfaces; keep broad planar receiver faces flat.
    for poly in obj.data.polygons:
        poly.use_smooth = len(poly.vertices) == 4 and poly.area < .001
    obj['construction'] = 'original procedural closed solid'
    PARTS.append(obj)
    return obj


def mesh(name, verts, faces, mat='gunmetal', bevel=0, segments=2):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, mat, bevel, segments)


def box(name, center, size, mat='gunmetal', bevel=.001, segments=2):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    return finish(obj, name, mat, bevel, segments)


def profile(name, points, width, mat='gunmetal', bevel=.0015, x=0, segments=2):
    # Extrude a designed side silhouette, not a stretched primitive box.
    n = len(points)
    verts = [(x + side*width/2, y, z) for side in [-1, 1] for y, z in points]
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    return mesh(name, verts, faces, mat, bevel, segments)


def ring_profile(name, outer, inner, width, mat='gunmetal', x=0, bevel=.0006):
    n = len(outer)
    assert len(inner) == n
    verts = [(x+s*width/2,y,z) for s in [-1,1] for loop in [outer,inner] for y,z in loop]
    faces = []
    for i in range(n):
        j = (i+1)%n
        faces += [(i,j,n+j,n+i), (2*n+i,3*n+i,3*n+j,2*n+j),
                  (i,2*n+i,2*n+j,j), (n+i,n+j,3*n+j,3*n+i)]
    return mesh(name, verts, faces, mat, bevel, 1)


def lathe(name, sections, center=(0,0,0), mat='gunmetal', sides=24, axis='Y', closed_profile=False):
    # Closed revolution of an arbitrary profile; positive radii only. Sections
    # can fold back to form a real recessed bore, closed at the inner back wall.
    cx,cy,cz = center
    verts = []
    for along,r in sections:
        for j in range(sides):
            a = j*math.tau/sides
            if axis == 'Y': p=(cx+r*math.cos(a),cy+along,cz+r*math.sin(a))
            elif axis == 'X': p=(cx+along,cy+r*math.cos(a),cz+r*math.sin(a))
            else: p=(cx+r*math.cos(a),cy+r*math.sin(a),cz+along)
            verts.append(p)
    faces = [] if closed_profile else [tuple(range(sides-1,-1,-1))]
    for k in range(len(sections)-1):
        for i in range(sides):
            j = (i+1)%sides
            faces.append((k*sides+i,k*sides+j,(k+1)*sides+j,(k+1)*sides+i))
    if closed_profile:
        k=len(sections)-1
        faces.extend((k*sides+i,k*sides+(i+1)%sides,(i+1)%sides,i) for i in range(sides))
    else:
        faces.append(tuple(range((len(sections)-1)*sides,len(sections)*sides)))
    return mesh(name, verts, faces, mat)


def cylinder(name, center, radius, length, mat='gunmetal', sides=16, axis='Y'):
    b = min(radius*.16,length*.15,.0008)
    return lathe(name,[(-length/2,radius-b),(-length/2+b,radius),
                       (length/2-b,radius),(length/2,radius-b)],center,mat,sides,axis)


def rod(name, start, end, radius, mat='gunmetal', sides=12):
    start,end = Vector(start),Vector(end)
    bpy.ops.mesh.primitive_cylinder_add(vertices=sides, radius=radius,
                                      depth=(end-start).length, location=(start+end)/2)
    obj=bpy.context.object
    obj.rotation_euler = (end-start).to_track_quat('Z','Y').to_euler()
    return finish(obj,name,mat,0)


def sweep_rod(name, points, radius, mat='gunmetal', sides=6):
    verts=[]
    for i,p in enumerate(points):
        direction=Vector(points[min(i+1,len(points)-1)])-Vector(points[max(i-1,0)])
        normal=direction.normalized().cross(Vector((1,0,0))).normalized()
        for k in range(sides):
            a=k*math.tau/sides
            v=Vector(p)+Vector((1,0,0))*math.cos(a)*radius+normal*math.sin(a)*radius
            verts.append(tuple(v))
    faces=[tuple(range(sides-1,-1,-1))]
    for i in range(len(points)-1):
        faces.extend((i*sides+k,i*sides+(k+1)%sides,(i+1)*sides+(k+1)%sides,(i+1)*sides+k) for k in range(sides))
    faces.append(tuple(range((len(points)-1)*sides,len(points)*sides)))
    return mesh(name,verts,faces,mat)


def cut(obj, cutter):
    activate(obj)
    mod=obj.modifiers.new('Real mechanical recess','BOOLEAN')
    mod.operation='DIFFERENCE'
    mod.solver='EXACT'
    mod.object=cutter
    bpy.ops.object.modifier_apply(modifier=mod.name)
    PARTS.remove(cutter)
    bpy.data.objects.remove(cutter,do_unlink=True)


def pin(name,y,z,width=.065,r=.0035,mat='steel'):
    return cylinder(name,(0,y,z),r,width,mat,12,'X')


def screw(name,x,y,z,r=.003):
    obj=cylinder(name,(x,y,z),r,.002,'steel',12,'X')
    slot=box('_slot',(x+math.copysign(.001,x),y,z),(.003,r*1.45,.0009),bevel=0)
    cut(obj,slot)
    return obj


def rail(y0,y1,z,width=.021):
    box('Rail dovetail',(0,(y0+y1)/2,z),(width*.8,y1-y0,.006),bevel=.0006,segments=1)
    count=max(2,int((y1-y0)/.011))
    for i in range(count):
        y=y0+.003+i*(y1-y0-.006)/max(1,count-1)
        box('Rail cross lug %02d'%i,(0,y,z+.0045),(width,.005,.003),bevel=.0004,segments=1)


def trigger(y=.045,z=-.006):
    outer=[(y-.036,z+.031),(y+.045,z+.031),(y+.046,z-.022),
           (y+.031,z-.042),(y-.026,z-.042),(y-.037,z-.023)]
    inner=[(y-.030,z+.012),(y+.037,z+.012),(y+.038,z-.019),
           (y+.026,z-.033),(y-.021,z-.033),(y-.029,z-.019)]
    guard=ring_profile('Trigger guard',outer,inner,.012)
    cut(guard,box('_open trigger guard top',(0,y+.002,z+.029),(.020,.045,.039),bevel=0))
    profile('Curved trigger',[(y-.004,z+.035),(y+.005,z+.034),(y+.006,z-.006),
                             (y+.015,z-.022),(y+.011,z-.026),(y-.001,z-.009)],.006,'steel',.0004,segments=1)


def grip(mat='polymer',dy=0):
    obj=profile('Pistol grip',[(dy-.025,.033),(dy+.022,.029),(dy+.011,-.025),
                (dy-.015,-.103),(dy-.045,-.105),(dy-.052,-.092)],.032,mat,.003)
    for s in [-1,1]:
        # Actual moulded ribs on both grip faces, with a base insert.
        panel=profile('Grip moulded insert',[(dy-.026,-.017),(dy+.007,-.027),
                       (dy-.017,-.090),(dy-.037,-.091)],.002,mat,.0006,x=s*.016)
        for i in range(6):
            y=dy-.009-i*.0032
            z=-.034-i*.009
            rod('Grip traction rib',(s*.0175,y-.012,z),(s*.0175,y+.008,z+.004),.0009,mat,8)
    return obj


def magazine(name,top_y,top_z,height,width,depth,bend,mat='gunmetal'):
    n=7
    verts=[]
    # Chamfered rectangular sections sweep along a curved magazine spine.
    for k in range(n):
        t=k/(n-1)
        y=top_y+bend*t*t
        z=top_z-height*t
        w=width*(1-.08*t)/2
        d=depth/2
        c=.003
        for xx,yy in [(-w+c,-d),(w-c,-d),(w,-d+c),(w,d-c),
                      (w-c,d),(-w+c,d),(-w,d-c),(-w,-d+c)]:
            verts.append((xx,y+yy,z))
    faces=[tuple(range(7,-1,-1))]
    for k in range(n-1):
        faces.extend((k*8+i,k*8+(i+1)%8,(k+1)*8+(i+1)%8,(k+1)*8+i) for i in range(8))
    faces.append(tuple(range((n-1)*8,n*8)))
    obj=mesh(name,verts,faces,mat,.0007,1)
    box('Magazine floor plate',(0,top_y+bend,top_z-height-.002),(width+.004,depth+.004,.004),mat,.0008,1)
    for side in [-1,1]:
        for lane in [-1,0,1]:
            pts=[]
            for k in range(6):
                t=.13+k*.145
                pts.append((side*(width*(1-.08*t)/2+.0003),top_y+bend*t*t+lane*depth*.23,top_z-height*t))
            sweep_rod('Magazine pressed stiffener',pts,.0008,mat,6)
    return obj


def muzzle(tip,z,radius=.011,bore=.003,device='Flash hider'):
    obj=lathe(device,[(tip-.045,radius*.85),(tip-.042,radius),
              (tip-.002,radius),(tip,radius*.92),(tip,bore*1.18),
              (tip-.001,bore),(tip-.025,bore)],(0,0,z),'gunmetal',24)
    # Cut actual through-wall vents, leaving uncut front/rear bands.
    for s in [-1,1]:
        cut(obj,box('_vent',(s*radius,tip-.022,z),(radius,.020,.004),bevel=.0004,segments=1))
    cylinder('Bore shadow',(0,tip-.0255,z),bore*.98,.001,'bore',20)
    return obj


def reset():
    global PARTS,MATS
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for collection in [bpy.data.meshes,bpy.data.materials,bpy.data.cameras,bpy.data.lights]:
        for item in list(collection):
            if item.users==0: collection.remove(item)
    PARTS=[]
    specs={'gunmetal':((.022,.028,.035,1),.82,.42),
           'steel':((.38,.42,.46,1),.94,.23),
           'polymer':((.008,.012,.008,1),0,.68),
           'wood':((.065,.018,.006,1),0,.42),
           'rust':((.21,.063,.019,1),.18,.88),
           'bore':((.004,.005,.006,1),.1,.93)}
    MATS={}
    for name,(color,metal,rough) in specs.items():
        m=bpy.data.materials.new(name)
        m.use_nodes=True
        bsdf=m.node_tree.nodes.get('Principled BSDF')
        bsdf.inputs['Base Color'].default_value=color
        bsdf.inputs['Metallic'].default_value=metal
        bsdf.inputs['Roughness'].default_value=rough
        m.diffuse_color=color
        MATS[name]=m
    bpy.context.scene.unit_settings.system='METRIC'
    bpy.context.scene.unit_settings.scale_length=1
    bpy.context.preferences.filepaths.save_version=0
    bpy.context.preferences.filepaths.file_preview_type='NONE'


def assault_rifle():
    z=.105
    # 0.34 m behind the grip; 0.62 m forward. Extended stock, 0.96 m total.
    cylinder('Receiver extension',(0,-.178,z),.014,.19,'gunmetal',20)
    profile('Extended stock', [(-.329,.128),(-.189,.128),(-.166,.104),
             (-.186,.067),(-.257,-.011),(-.329,-.017)],.041,'polymer',.003)
    stock=PARTS[-1]
    cut(stock,profile('_stock opening',[(-.294,.080),(-.214,.086),(-.263,.018),(-.294,.018)],.06,bevel=.003))
    box('Butt recoil pad',(0,-.334,.055),(.046,.012,.147),'polymer',.003)
    box('Stock adjustment latch',(0,-.208,.059),(.025,.044,.009),'polymer',.002)
    for i in range(7):
        box('Butt pad traction',(0,-.340,.002+i*.017),(.039,.0016,.003),'polymer',.0003,1)
    lower=profile('Lower receiver',[(-.092,.093),(.109,.093),(.137,.066),(.132,.013),
                 (.077,.006),(.059,.031),(.006,.026),(-.036,.010),(-.092,.034)],.046,'gunmetal',.002)
    upper=profile('Upper receiver',[(-.103,.100),(-.100,.135),(-.073,.149),
                 (.125,.149),(.140,.129),(.140,.102)],.048,'gunmetal',.0017)
    cut(upper,box('_ejection pocket',(.024,.045,.123),(.011,.080,.020),bevel=.002))
    box('Bolt face in ejection port',(.019,.045,.123),(.001,.074,.016),'steel',.001,1)
    box('Port cover open',(.032,.045,.105),(.016,.080,.002),'gunmetal',.0007,1)
    pin('Port cover hinge',.043,.106,.066,.002)
    rod('Forward assist housing',(.019,-.049,.123),(.043,-.072,.125),.008)
    cylinder('Forward assist button',(.045,-.075,.125),.008,.004,'gunmetal',16,'X')
    box('Charging handle stem',(0,-.109,.142),(.012,.028,.007),'steel',.0006,1)
    box('Charging handle T latch',(0,-.122,.142),(.062,.009,.009),bevel=.001)
    grip()
    trigger(.047,.000)
    magazine('Curved 5.56 magazine',.130,.012,.172,.025,.061,.032)
    cut(lower,box('_magazine well',(0,.130,.009),(.027,.064,.032),bevel=.001,segments=1))
    # Handguard has an actual longitudinal cavity around a separate barrel.
    guard=lathe('Handguard',[(.144,.028),(.151,.030),(.351,.026),(.356,.024),
                   (.356,.022),(.144,.022)],(0,0,z),'polymer',16,closed_profile=True)
    for s in [-1,1]:
        for i in range(5):
            cut(guard,box('_handguard vent',(s*.026,.174+i*.034,z+.002),(.024,.022,.008),bevel=.001,segments=1))
    cylinder('Barrel',(0,.344,z),.0085,.383,'gunmetal',24)
    cylinder('Barrel collar',(0,.365,z),.012,.018,'steel',20)
    cylinder('Gas block',(0,.469,z),.014,.022,'gunmetal',16)
    rod('Gas tube',(0,.139,z+.017),(0,.468,z+.017),.0028,'steel',12)
    profile('Front sight tower',[(.457,.113),(.481,.113),(.478,.178),
                 (.470,.195),(.463,.178)],.011,'gunmetal',.001)
    box('Front sight post',(0,.470,.197),(.003,.004,.012),'steel',.0003,1)
    muzzle(.620,z,.012,.003)
    cylinder('Exposed barrel nose',(0,.553,z),.0085,.043,'gunmetal',24)
    rail(-.086,.126,.151)
    profile('Rear sight base',[(-.072,.163),(-.047,.163),(-.046,.182),(-.073,.182)],.032,bevel=.001)
    cylinder('Rear sight aperture',(0,-.059,.186),.009,.007,'gunmetal',16)
    aperture=PARTS[-1]
    cut(aperture,cylinder('_aperture',(0,-.059,.186),.003,.014,'bore',12))
    for y,zz in [(-.073,.057),(.061,.054)]: pin('Receiver takedown pin',y,zz,.050,.0035)
    for s in [-1,1]:
        screw('Selector pivot',s*.025,-.020,.061,.004)
        rod('Selector lever',(s*.026,-.020,.061),(s*.026,-.044,.054),.0025,'gunmetal',10)
        screw('Stock cross pin',s*.023,-.271,.102)
    box('Magazine release',(.026,.095,.059),(.005,.018,.011),'steel',.001,1)
    return .620,z


def smg():
    z=.106
    profile('Fixed polymer shoulder stock',[(-.291,.125),(-.093,.112),(-.083,.066),
           (-.163,.054),(-.249,-.018),(-.291,-.018)],.041,'polymer',.004)
    box('SMG recoil pad',(0,-.295,.052),(.046,.010,.151),'polymer',.002)
    for s in [-1,1]:
        screw('Stock retaining pin',s*.023,-.107,.086,.004)
    rec=lathe('Stamped upper receiver',[(-.098,.022),(-.090,.027),(.140,.027),
              (.149,.023)],(0,0,z),'gunmetal',24)
    cut(rec,box('_ejection pocket',(.025,.045,.115),(.014,.063,.020),bevel=.002))
    box('Visible bolt',(.019,.045,.115),(.001,.057,.015),'steel',.0002,1)
    profile('SMG lower trigger housing',[(-.087,.084),(.122,.084),(.139,.054),
             (.115,.019),(.065,.012),(.046,.026),(-.043,.022),(-.087,.043)],.041,'polymer',.002)
    grip();trigger(.041,-.003)
    magazine('Curved 9mm magazine',.109,.018,.162,.023,.038,.034)
    guard=lathe('Wide polymer forearm',[(.151,.027),(.160,.032),(.289,.028),
               (.305,.022),(.305,.016),(.151,.018)],(0,0,.095),'polymer',20,closed_profile=True)
    for s in [-1,1]:
        for i in range(4):
            cut(guard,box('_SMG vent',(s*.030,.177+i*.027,.100),(.015,.015,.009),bevel=.001,segments=1))
    cylinder('Short exposed barrel',(0,.354,z),.009,.100,'gunmetal',24)
    cylinder('Cocking tube',(0,.225,.144),.009,.169,'gunmetal',20)
    rod('Cocking lever',(-.006,.263,.145),(-.037,.263,.150),.0035,'steel',12)
    cylinder('Cocking lever grip',(-.039,.263,.150),.005,.013,'polymer',12,'X')
    cylinder('Front trunnion',(0,.314,z),.016,.018,'gunmetal',20)
    profile('Front sight support',[(.321,.112),(.339,.112),(.336,.159),(.324,.159)],.013,bevel=.001)
    hood=lathe('Front sight protective hood',[(.324,.014),(.334,.014),
                (.334,.010),(.324,.010)],(0,0,.163),'gunmetal',20,closed_profile=True)
    rod('Front sight blade',(0,.329,.151),(0,.329,.164),.0016,'steel',8)
    muzzle(.440,z,.0105,.0045,'Three lug muzzle')
    for a in [0,math.tau/3,2*math.tau/3]:
        box('Muzzle mounting lug',(.011*math.cos(a),.394,z+.011*math.sin(a)),(.005,.006,.005),bevel=.0004,segments=1)
    rail(-.056,.108,.137)
    box('Diopter sight pedestal',(0,-.074,.142),(.025,.025,.024),bevel=.001,segments=2)
    cylinder('Diopter sight drum',(0,-.074,.159),.012,.013,'gunmetal',16,'Z')
    for y,zz in [(-.071,.055),(.113,.045)]: pin('SMG receiver pin',y,zz,.045,.003)
    for s in [-1,1]:
        screw('Selector axle',s*.022,-.022,.050,.004)
        rod('SMG selector',(s*.024,-.022,.050),(s*.024,-.043,.044),.002,'gunmetal',10)
    box('Magazine release paddle',(0,.074,.001),(.010,.015,.016),'steel',.001,1)
    return .440,z


def machine_gun():
    z=.139
    profile('LMG polymer stock',[(-.337,.163),(-.119,.155),(-.089,.109),
              (-.133,.073),(-.266,-.020),(-.337,-.017)],.049,'polymer',.004)
    box('LMG recoil pad',(0,-.344,.073),(.056,.012,.186),'polymer',.002)
    cylinder('Recoil buffer',(0,-.104,.125),.025,.044,'steel',20)
    receiver=profile('Formed receiver',[(-.095,.065),(.231,.065),(.240,.109),
                      (.226,.177),(-.089,.177)],.074,bevel=.0025)
    cut(receiver,box('_LMG ejection',(.038,.144,.097),(.013,.073,.031),bevel=.002))
    box('LMG bolt carrier',(.032,.144,.097),(.001,.066,.025),'steel',.0002,1)
    box('Feed cover',(0,.060,.184),(.077,.277,.013),'gunmetal',.003)
    pin('Feed cover hinge',.196,.181,.087,.005)
    grip();trigger(.047,.006)
    profile('Trigger housing',[(-.056,.065),(.105,.065),(.095,.020),
               (.063,.020),(.048,.037),(-.038,.028)],.041,bevel=.002)
    box('Ammunition box',(0,.200,-.014),(.130,.162,.145),'polymer',.004)
    box('Ammo box lid',(0,.200,.060),(.137,.168,.009),'polymer',.0015)
    for s in [-1,1]:
        for j in range(4):
            box('Ammunition box moulding',(s*.066,.150+j*.034,-.015),(.002,.004,.104),'polymer',.0005,1)
        screw('Ammo box clasp',s*.069,.172,.034,.004)
    # Visible feed belt with closed cartridge forms and dark linking clips.
    for i in range(5):
        x=-.047-i*.010
        lathe('Linked visual cartridge',[(.077,.0037),(.113,.0037),(.123,.0028),
                  (.134,.0007)],(x,0,.146),'steel',10)
        box('Belt link',(x,.095,.147),(.008,.008,.009),'gunmetal',.0005,1)
    cylinder('Quick change barrel',(0,.447,z),.0095,.419,'gunmetal',24)
    cylinder('Gas piston tube',(0,.397,.104),.011,.322,'gunmetal',20)
    shield=lathe('Perforated heat shield',[(.243,.027),(.250,.031),(.448,.028),
                 (.456,.024),(.456,.020),(.243,.022)],(0,0,z),'gunmetal',20,closed_profile=True)
    cut(shield,box('_heat shield lower clearance',(0,.350,.102),(.10,.25,.040),bevel=0))
    for s in [-1,1]:
        for i in range(6):
            cut(shield,box('_cooling slot',(s*.028,.267+i*.030,z+.007),(.025,.018,.011),bevel=.002,segments=1))
    handguard=profile('Lower polymer handguard',[(.239,.100),(.449,.103),(.443,.074),
                (.263,.068)],.057,'polymer',.003)
    cut(handguard,cylinder('_gas tube relief',(0,.397,.104),.0116,.330,sides=20))
    rail(-.063,.164,.195,.028)
    rod('Carry handle upright',(-.028,.244,.162),(-.028,.253,.249),.004,'steel',12)
    rod('Carry handle horizontal',(-.028,.253,.249),(-.028,.352,.249),.008,'polymer',16)
    cylinder('Carry handle pivot',(-.028,.244,.164),.010,.016,'steel',16,'X')
    box('Charging slide',(.041,.033,.106),(.009,.072,.013),'steel',.001,1)
    rod('Cocking handle',(.043,.023,.107),(.078,.023,.107),.005,'steel',12)
    cylinder('Cocking knob',(.079,.023,.107),.009,.016,'polymer',16,'X')
    cylinder('Bipod collar',(0,.498,z),.016,.020,'gunmetal',20)
    for s in [-1,1]:
        start=(s*.014,.498,.125);end=(s*.078,.432,-.145)
        rod('Partly deployed bipod leg',start,end,.006,'gunmetal',12)
        rod('Bipod telescoping shaft',(s*.057,.454,-.059),end,.0035,'steel',12)
        box('Bipod foot',(s*.078,.431,-.148),(.024,.031,.007),'gunmetal',.001,1)
    pin('Bipod hinge',.497,.127,.043,.0045)
    profile('LMG front sight tower',[(.560,.142),(.582,.142),(.579,.209),
                   (.566,.209)],.012,bevel=.001)
    rod('LMG front sight post',(0,.573,.207),(0,.573,.220),.002,'steel',8)
    muzzle(.690,z,.013,.003)
    cylinder('Muzzle collar',(0,.635,z),.012,.023,'steel',20)
    for y in [-.063,.067,.208]: pin('Receiver rivet',y,.151,.078,.003)
    screw('Worn feed latch',-.041,-.055,.168,.005)
    cylinder('Small oxidised latch washer',(-.040,-.055,.168),.0065,.001,'rust',16,'X')
    return .690,z


def shotgun():
    z=.106
    # Conventional wrist grip: origin lies at the top of the right-hand wrist.
    stock=profile('Walnut shoulder stock',[(-.370,.070),(-.183,.099),(-.057,.079),
             (.007,.038),(.003,.009),(-.076,.011),(-.151,-.042),(-.370,-.094)],.041,'wood',.006)
    box('Shotgun recoil pad',(0,-.376,-.012),(.046,.008,.168),'polymer',.003)
    # Two slim sculpted side cheek facets and a contrasting pad spacer.
    for s in [-1,1]:
        profile('Walnut cheek panel',[(-.340,.045),(-.188,.073),(-.112,.042),
                (-.173,-.010),(-.339,-.053)],.002,'wood',.001,x=s*.020)
        screw('Stock pad screw',s*.019,-.373,.032,.0028)
    receiver=profile('870 class rounded receiver',[(-.043,.047),(.154,.047),
            (.166,.068),(.166,.132),(.150,.145),(-.045,.145)],.044,bevel=.004)
    cut(receiver,box('_shotgun ejection',(.023,.083,.111),(.012,.092,.034),bevel=.003))
    box('Shotgun visible bolt',(.018,.083,.111),(.001,.085,.027),'steel',.0002,1)
    trigger(.038,.018)
    # A real circular bore, with a short blind termination hidden in the receiver.
    lathe('Shotgun barrel',[(.159,.0125),(.166,.0127),(.658,.0127),(.660,.012),
             (.660,.00925),(.657,.00925),(.173,.00925)],(0,0,z),'gunmetal',32)
    cylinder('Shotgun bore shadow',(0,.174,z),.0091,.001,'bore',24)
    cylinder('Tube magazine',(0,.353,.075),.0105,.376,'gunmetal',24)
    cylinder('Magazine cap',(0,.549,.075),.013,.015,'gunmetal',24)
    for i in range(10):
        a=i*math.tau/10
        rod('Magazine cap knurl',(.013*math.cos(a),.544,.075+.013*math.sin(a)),
                 (.013*math.cos(a),.555,.075+.013*math.sin(a)),.0007,'gunmetal',6)
    # Lathed walnut slide with actual grooves and a bore around the magazine.
    sections=[(.255,.018),(.264,.025)]
    for i in range(9):
        y=.269+i*.016
        sections += [(y,.0255),(y+.003,.0235),(y+.006,.0255)]
    sections += [(.410,.024),(.419,.018),(.419,.012),(.255,.012)]
    pump=lathe('Grooved walnut pump slide',sections,(0,0,.075),'wood',20,closed_profile=True)
    cut(pump,cylinder('_pump barrel clearance',(0,.337,z),.0135,.19,sides=32))
    for s in [-1,1]:
        box('Pump action bar',(s*.016,.217,.070),(.003,.098,.007),'steel',.0005,1)
    # Mounting saddle is hollow around the magazine; the two tubes remain clear.
    ring_profile('Barrel magazine clamp',[(.517,.121),(.537,.121),(.537,.060),(.517,.060)],
                   [(.521,.115),(.533,.115),(.533,.066),(.521,.066)],.027,bevel=.0005)
    cylinder('Bead sight base',(0,.644,.121),.003,.003,'gunmetal',12,'Z')
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=.0023,location=(0,.644,.124))
    finish(bpy.context.object,'Brass class sight bead','steel')
    for y in [.010,.125]: pin('Shotgun trigger plate pin',y,.064,.046,.003)
    pin('Cross bolt safety',-.004,.048,.051,.003)
    box('Slide release',(-.024,.010,.046),(.005,.022,.007),'steel',.0005,1)
    for obj in PARTS:
        for vertex in obj.data.vertices: vertex.co.z-=.038
        obj.data.update()
    return .660,z-.038


def marksman():
    z=.123
    # Original compact DMR with walnut furniture and a thumbhole stock.
    outer=[(-.350,.125),(-.107,.131),(-.041,.085),(.018,.020),
             (-.011,-.085),(-.105,-.051),(-.287,-.051),(-.350,-.048)]
    inner=[(-.295,.072),(-.134,.083),(-.086,.052),(-.049,.009),
             (-.062,-.025),(-.126,-.018),(-.286,-.018),(-.296,.016)]
    ring_profile('Walnut thumbhole stock',outer,inner,.041,'wood',bevel=.003)
    profile('Walnut grip web',[(-.102,.080),(-.048,.073),(.014,.015),
               (-.009,-.087),(-.040,-.082),(-.030,-.007)],.033,'wood',.003)
    box('DMR recoil pad',(0,-.355,.038),(.045,.010,.181),'polymer',.003)
    profile('Raised cheek rest',[(-.309,.127),(-.146,.128),(-.137,.152),
              (-.297,.157)],.046,'polymer',.003)
    for s in [-1,1]:
        screw('Cheek rest screw',s*.025,-.180,.141,.003)
        screw('Stock through bolt',s*.022,-.102,.091,.004)
    receiver=profile('DMR milled receiver',[(-.091,.059),(.193,.059),(.207,.087),
                (.204,.154),(-.089,.154)],.045,bevel=.0025)
    cover=profile('DMR receiver cover',[(-.086,.157),(.178,.157),(.181,.176),
                (-.072,.182)],.043,bevel=.002)
    cut(receiver,box('_DMR ejection',(.023,.096,.128),(.012,.091,.028),bevel=.002))
    box('DMR bolt carrier',(.018,.096,.128),(.001,.084,.022),'steel',.0002,1)
    rod('DMR bolt handle',(.021,.071,.132),(.052,.071,.137),.004,'steel',12)
    cylinder('DMR cocking knob',(.053,.071,.137),.005,.010,'gunmetal',12,'X')
    trigger(.049,.030)
    magazine('Ten round DMR magazine',.143,.052,.103,.030,.069,.012)
    handguard=lathe('Walnut ventilated handguard',[(.208,.025),(.216,.030),
                  (.406,.027),(.414,.023),(.414,.017),(.208,.018)],(0,0,z),'wood',20,closed_profile=True)
    for s in [-1,1]:
        for j in range(5):
            cut(handguard,box('_DMR vent',(s*.027,.236+j*.033,z+.005),(.021,.018,.011),bevel=.002,segments=1))
    cylinder('DMR barrel',(0,.559,z),.009,.293,'gunmetal',28)
    cylinder('DMR gas tube',(0,.345,.159),.007,.283,'gunmetal',20)
    profile('Gas block',[ (.466,.120),(.487,.120),(.486,.169),(.470,.169)],.020,bevel=.001)
    cylinder('Handguard retaining band',(0,.412,z),.028,.010,'gunmetal',20)
    brake=muzzle(.760,z,.013,.004,'DMR muzzle brake')
    for y in [.724,.737]:
        cut(brake,box('_brake top port',(0,y,z+.012),(.013,.006,.010),bevel=.0005,segments=1))
    # Mount and paired split rings. The scope body is tapered at both ends.
    box('Scope side dovetail',(-.027,.001,.150),(.010,.117,.013),'gunmetal',.001,1)
    for y in [-.010,.111]:
        profile('Scope support',[ (y-.010,.151),(y+.010,.151),(y+.012,.221),
                    (y-.012,.221)],.014,bevel=.001,x=-.019)
        # Hollow clamping ring, rather than a cylinder through the scope.
        lathe('Scope mounting ring',[(y-.007,.018),(y+.007,.018),
              (y+.007,.0145),(y-.007,.0145)],(0,0,.231),'gunmetal',20,closed_profile=True)
        for s in [-1,1]: screw('Scope ring screw',s*.019,y,.239,.0025)
    lathe('Scope optical housing',[(-.123,.019),(-.118,.022),(-.078,.022),
             (-.055,.014),(.135,.014),(.186,.027),(.226,.027),
             (.231,.026),(.231,.0235),(.218,.0235)],(0,0,.231),'gunmetal',32)
    cylinder('Objective lens',(0,.220,.231),.0232,.002,'steel',32)
    cylinder('Eyepiece lens',(0,-.123,.231),.0167,.001,'steel',24)
    cylinder('Ocular rubber collar',(0,-.112,.231),.023,.014,'polymer',24)
    cylinder('Elevation turret',(0,.035,.254),.012,.020,'gunmetal',20,'Z')
    cylinder('Windage turret',(.022,.035,.231),.011,.019,'gunmetal',20,'X')
    for i in range(12):
        a=i*math.tau/12
        rod('Turret knurl',(.012*math.cos(a),.035+.012*math.sin(a),.255),
                    (.012*math.cos(a),.035+.012*math.sin(a),.262),.0007,'gunmetal',6)
    for s in [-1,1]:
        screw('DMR receiver pin',s*.024,-.058,.091,.003)
    box('DMR selector lever',(.026,-.024,.109),(.004,.055,.008),'gunmetal',.0007,1)
    return .760,z


def topology():
    result=[]
    for obj in PARTS:
        bm=bmesh.new();bm.from_mesh(obj.data)
        bad=sum(not e.is_manifold for e in bm.edges)
        deg=sum(f.calc_area()<1e-12 for f in bm.faces)
        volume=bm.calc_volume(signed=True)
        result.append(dict(part=obj.name,nonmanifold_edges=bad,degenerate_faces=deg,volume_m3=volume))
        bm.free()
    assert all(r['nonmanifold_edges']==0 and r['degenerate_faces']==0 and r['volume_m3']>0 for r in result), json.dumps([r for r in result if r['nonmanifold_edges'] or r['degenerate_faces'] or r['volume_m3']<=0])
    return result


def triangulate():
    for obj in PARTS:
        bm=bmesh.new();bm.from_mesh(obj.data)
        # Exact Boolean intersections can leave coincident points at tangent
        # groove cuts. Weld only sub-micrometre duplicates before triangulation.
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=1e-7)
        bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=1e-7)
        bmesh.ops.triangulate(bm,faces=list(bm.faces),quad_method='BEAUTY',ngon_method='BEAUTY')
        bm.to_mesh(obj.data);bm.free()
        obj.data.update()
        # Split normals at sharp machined edges, smoothly shade curved panels.
        for face in obj.data.polygons: face.use_smooth=True
        obj.data.set_sharp_from_angle(angle=math.radians(40))


def preview(name):
    scene=bpy.context.scene
    scene.render.engine='CYCLES'
    scene.cycles.samples=24
    scene.cycles.use_denoising=True
    scene.render.resolution_x=1440
    scene.render.resolution_y=960
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='AgX'
    scene.view_settings.look='AgX - Medium High Contrast'
    scene.view_settings.exposure=-.2
    scene.world.use_nodes=True
    scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.23,.23,.23,1)
    scene.world.node_tree.nodes['Background'].inputs[1].default_value=.6
    verts=[v.co for o in PARTS for v in o.data.vertices]
    lo=Vector(tuple(min(v[i] for v in verts) for i in range(3)))
    hi=Vector(tuple(max(v[i] for v in verts) for i in range(3)))
    center=(lo+hi)/2
    temporary=[]
    for pos,power,size in [((.8,.3,1.3),160,1.1),((-.7,.7,.8),210,.8),((.4,-.9,.7),100,.7)]:
        data=bpy.data.lights.new('Studio softbox','AREA');data.energy=power;data.shape='DISK';data.size=size
        obj=bpy.data.objects.new('Studio softbox',data);scene.collection.objects.link(obj)
        obj.location=Vector(pos)+center
        obj.rotation_euler=(center-obj.location).to_track_quat('-Z','Y').to_euler()
        temporary.append(obj)
    data=bpy.data.cameras.new('Preview camera')
    camera=bpy.data.objects.new('Preview camera',data);scene.collection.objects.link(camera)
    temporary.append(camera);scene.camera=camera;data.type='ORTHO'
    views={'side':(1,0,.02),'front':(0,1,.04),'three_quarter':(.90,.65,.36)}
    for label,direction in views.items():
        direction=Vector(direction).normalized()
        camera.location=center+direction*2.5
        camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler()
        # Fit projected bounds, with enough margin around the bipod and scope.
        basis=camera.rotation_euler.to_matrix().transposed()
        corners=[basis@(Vector((x,y,z))-center) for x in [lo.x,hi.x] for y in [lo.y,hi.y] for z in [lo.z,hi.z]]
        spanx=max(v.x for v in corners)-min(v.x for v in corners)
        spany=max(v.y for v in corners)-min(v.y for v in corners)
        data.ortho_scale=max(spanx,spany*1.5)*1.18
        scene.render.filepath=str(ROOT/'previews'/(name+'_'+label+'.png'))
        bpy.ops.render.render(write_still=True)
    for obj in temporary: bpy.data.objects.remove(obj,do_unlink=True)
    scene.camera=None


def unwrap():
    # One multi-object atlas: smart projection followed by common scale and
    # packing, without mirrored or stacked islands, shared across all parts.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in PARTS: obj.select_set(True)
    bpy.context.view_layer.objects.active=PARTS[0]
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(40),island_margin=.001,
                             area_weight=0,correct_aspect=True,scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    # Smart projection occasionally collapses very thin Boolean sidewalls.
    # Give those faces a separate isometric projection before the final pack.
    repaired=0
    for obj in PARTS:
        uvs=obj.data.uv_layers.active.data
        for face in obj.data.polygons:
            loops=list(face.loop_indices)
            a,b,c=[uvs[j].uv.copy() for j in loops]
            if abs((b-a).cross(c-a))>1e-12: continue
            vertices=[obj.data.vertices[j].co for j in face.vertices]
            edge=(vertices[1]-vertices[0]).normalized()
            normal=(vertices[1]-vertices[0]).cross(vertices[2]-vertices[0]).normalized()
            up=normal.cross(edge)
            for j,p in zip(loops,vertices):
                delta=p-vertices[0]
                uvs[j].uv=(2+repaired*.1+delta.dot(edge),2+delta.dot(up))
            repaired+=1
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.average_islands_scale()
    bpy.ops.uv.pack_islands(rotate=True,margin=.001)
    bpy.ops.object.mode_set(mode='OBJECT')


def export(name,tip,z):
    root=bpy.data.objects.new(name,None)
    bpy.context.collection.objects.link(root)
    root['grip_origin']='top of right-hand grip; metres'
    for obj in PARTS: obj.parent=root
    empty=bpy.data.objects.new('Muzzle',None)
    bpy.context.collection.objects.link(empty)
    empty.parent=root
    empty.location=(0,tip,z)
    # glTF exporter conjugates empty rotations; glTF -Z maps Blender +Y.
    # With an unrotated empty the glTF local -Z remains world -Z.
    empty.empty_display_type='ARROWS'
    empty.empty_display_size=.035
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(ROOT/(name+'.glb')),export_format='GLB',
        use_selection=True,export_yup=True,export_apply=True,
        export_texcoords=True,export_normals=True,export_tangents=True,
        export_materials='EXPORT',export_animations=False,export_skins=False,
        export_cameras=False,export_lights=False,export_extras=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'sources'/(name+'.blend')))


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--only',choices=list(TARGETS))
    parser.add_argument('--no-render',action='store_true')
    args=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
    for folder in ['sources','checks','previews']:
        (ROOT/folder).mkdir(exist_ok=True)
        (ROOT/folder/'.gdignore').touch()
    from validate_glb import validate
    from inspect_blend import audit
    saved_report=ROOT/'validation.json'
    report=json.loads(saved_report.read_text(encoding='utf-8')) if args.only and saved_report.exists() else {'weapons':{}}
    report['blender_version']=bpy.app.version_string
    for name in ([args.only] if args.only else TARGETS):
        reset()
        tip,z=globals()[name]()
        triangulate()
        checks=topology()
        unwrap()
        triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in PARTS)
        print('BUILD',name,'triangles',triangles,'meshes',len(PARTS),flush=True)
        export(name,tip,z)
        intersections=audit(PARTS)
        (ROOT/'checks'/(name+'_geometry.json')).write_text(json.dumps(dict(topology=checks,intersections=intersections),indent=2))
        assert not intersections['self_intersection_candidates'],intersections['self_intersection_candidates'][:4]
        result=validate(name)
        result['source_topology_check']={'passed':True,'closed_manifold_solids':len(checks),
            'positive_volumes':True,'degenerate_faces':0,'self_intersection_candidates':0}
        mount_review_path=ROOT/'mount_review.json'
        reviewed=False
        if mount_review_path.exists():
            approved=json.loads(mount_review_path.read_text(encoding='utf-8'))['weapons'][name]
            approved_pairs={tuple(sorted(p['parts'])):p for p in approved}
            for contact in intersections['interpenetration_samples']:
                key=tuple(sorted(contact['parts']))
                assert key in approved_pairs,('Unreviewed contact',name,key)
                assert contact['maximum_sampled_depth_m']<=approved_pairs[key]['maximum_depth_m']+1e-5,(name,key,'mount depth changed')
            reviewed=True
        result['interpenetration_check']={'report':'checks/'+name+'_geometry.json',
            'method':intersections['method'],'mounts_reviewed':reviewed,
            'approved_contact_pairs':len(intersections['interpenetration_samples']) if reviewed else 0,
            'limitation':'Sampled containment and surface BVH, not an exact constructive-solid-geometry proof.'}
        report['weapons'][name]=result
        if not args.no_render: preview(name)
    report['export_contract_passed']=set(report['weapons'])==set(TARGETS)
    report['geometry_validation_limits']='Grip placement is an artist landmark. BVH and sampled penetration checks do not constitute an exact volumetric-intersection proof.'
    (ROOT/'validation.json').write_text(json.dumps(report,indent=2),encoding='utf-8')


if __name__=='__main__': main()
