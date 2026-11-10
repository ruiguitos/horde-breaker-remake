"""Original CC0 test arena layout; standard Python only, no engine calls."""
import csv
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent

# All collision footprints are measured again from the final exported meshes.
BOUNDS = {
    'concrete_wall': (0, 0, 4, .4), 'low_cover': (0, 0, 4, .4),
    'shipping_container': (0, 0, 6, 2.4), 'platform': (0, 0, 8, 8),
    'ramp': (0, 0, 8, 4), 'landmark_pillar': (0, 0, 1.2, 1.2),
    'extraction_beacon': (-1, -1, 1, 1), 'dock': (0, 0, 10, 3),
}


def transform(x, z, angle):
    return {0: (x, z), 90: (z, -x), 180: (-x, -z), 270: (-z, x)}[angle]


def footprint(item, bounds=BOUNDS):
    x0, z0, x1, z1 = bounds[item['module']]
    points = [transform(x, z, item['rotation_deg']) for x, z in [(x0,z0),(x1,z0),(x1,z1),(x0,z1)]]
    return (min(p[0] for p in points)+item['x'], min(p[1] for p in points)+item['z'],
            max(p[0] for p in points)+item['x'], max(p[1] for p in points)+item['z'])


def rect_distance(a, b):
    dx = max(a[0]-b[2], b[0]-a[2], 0)
    dz = max(a[1]-b[3], b[1]-a[3], 0)
    return math.hypot(dx, dz)


def overlap(a, b):
    return max(0, min(a[2],b[2])-max(a[0],b[0])) * max(0, min(a[3],b[3])-max(a[1],b[1]))


def generate():
    items, groups = [], []
    def add(module, x, z, rotation=0, group='scenery'):
        assert all(isinstance(v, int) for v in [x,z,rotation])
        items.append({'module': module, 'x': x, 'z': z, 'rotation_deg': rotation})
        groups.append(group)
    # Orthogonal stepped funnels allow cardinal rotations and reusable 4 m walls.
    for radius, opening in [(42,4),(78,12),(104,16),(124,24)]:
        lo, hi, left, right = 128-radius, 128+radius, 128-opening//2, 128+opening//2
        for start, end in [(lo,left),(right,hi)]:
            for p in range(start,end,4):
                add('concrete_wall',p,lo,0,f'ring_{radius}_south')
                add('concrete_wall',p,hi,0,f'ring_{radius}_north')
                # West projects outward to -X, east outward to +X: no corner overlap.
                add('concrete_wall',lo,p,270,f'ring_{radius}_west')
                add('concrete_wall',hi,p+4,90,f'ring_{radius}_east')
    for ox, oz in [(104,106),(144,106),(104,144),(144,144)]:
        add('low_cover',ox,oz,group='cover_cluster')
        add('low_cover',ox,oz+6,group='cover_cluster')
        add('low_cover',ox+10,oz,group='cover_cluster')
    for x,z in [(94,94),(160,94),(94,160),(160,160)]:
        add('landmark_pillar',x,z,group='landmark')
    for x,z in [(100,176),(148,176),(100,74),(148,74)]:
        add('shipping_container',x,z,group='container')
    for x,z in [(178,110),(178,160),(76,110),(76,160)]:
        add('shipping_container',x,z,90,group='container')
    add('platform',175,140,group='platform_assembly')
    add('ramp',175,136,group='platform_assembly')
    add('extraction_beacon',128,250,group='extraction')
    add('dock',126,10,90,group='arrival')
    (ROOT/'layout.json').write_text(json.dumps(items,indent=2)+'\n')
    features = {
        'license':'CC0-1.0','island_size_m':[256,256],
        'coordinate_origin':'southwest; X east, Z north; Y up for GLB',
        'rotation_formula':'x=cos(a)*local_x+sin(a)*local_z; z=-sin(a)*local_x+cos(a)*local_z',
        'arena':{'centre_xz_m':[128,128],'design_open_disc_diameter_m':80,
                 'inner_walled_square_approx_m':83.2,'low_cover_is_intentional':True},
        'main_entry_xz_m':[128,16], 'extraction_goal_xz_m':[128,246],
        'beacon_pivot_xz_m':[128,250],
        'funnel_rings':[{'radius_m':r,'aperture_m':g} for r,g in [(42,4),(78,12),(104,16),(124,24)]],
        'escape_loops':[{'name':f'escape_loop_{i+1}','square_radius_m':r,'reserved_width_m':8,
                         'minimum_clearance_each_side_m':4} for i,r in enumerate([60,90,114])],
        'platform':{'module_index':groups.index('platform_assembly'),'rise_m':1.2,
                    'ramp_horizontal_run_m':4,'ramp_width_m':8,'slope_degrees':math.degrees(math.atan(1.2/4)),
                    'nominal_6mps_horizontal_travel_seconds':4/6,
                    'nominal_6mps_surface_travel_seconds':math.hypot(4,1.2)/6},
        'instance_groups':groups,
        'limits':['Stepped/cardinal funnels, not diagonal walls.',
                  'Height traversal and collision-layer configuration require future engine integration; no Godot was run.']}
    (ROOT/'layout_features.json').write_text(json.dumps(features,indent=2)+'\n')
    return items, features


def check_layout(items, features, bounds=BOUNDS, write=True):
    rectangles = [footprint(item,bounds) for item in items]
    issues=[];nearest=[(float('inf'),-1) for _ in items];contacts=[];narrow=[]
    for i,(item,box) in enumerate(zip(items,rectangles)):
        assert item['rotation_deg'] in [0,90,180,270]
        assert isinstance(item['x'],int) and isinstance(item['z'],int)
        if min(box[0],box[1]) < -1e-5 or max(box[2],box[3]) > 256+1e-5:issues.append(['outside',i,box])
    out = open(ROOT/'piece_distances.csv','w',newline='',encoding='utf-8') if write else None
    writer=csv.writer(out) if out else None
    if writer:writer.writerow(['instance_a','instance_b','minimum_plan_distance_m','shared_boundary','overlap_area_m2'])
    pairs=0;min_positive=float('inf')
    for i,a in enumerate(rectangles):
        for j in range(i+1,len(rectangles)):
            b=rectangles[j];distance=rect_distance(a,b);area=overlap(a,b);pairs+=1
            if area > 1e-5:issues.append(['overlap',i,j,area])
            if distance < 1e-5:contacts.append([i,j])
            else:
                min_positive=min(min_positive,distance)
                if distance < 3-1e-5:narrow.append([i,j,distance])
            if distance < nearest[i][0]:nearest[i]=(distance,j)
            if distance < nearest[j][0]:nearest[j]=(distance,i)
            if writer:writer.writerow([i,j,f'{distance:.6f}',int(distance<1e-5),f'{area:.8f}'])
    if out:out.close()
    if narrow:issues.append(['unclassified_gap_below_3m',narrow])
    corridors=[]
    # A free rectangle represents the full required width, not a sampled centre line.
    def free_rectangle(name,box,width):
        blockers=[i for i,r in enumerate(rectangles) if overlap(box,r)>1e-5]
        if blockers:issues.append(['corridor_blocked',name,blockers])
        corridors.append({'name':name,'width_m':width,'clear_rectangle_xz_m':box,'blocking_instances':blockers})
    for i,r in enumerate([60,90,114]):
        lo,hi=128-r,128+r
        for side,box in [('south',(lo-4,lo-4,hi+4,lo+4)),('north',(lo-4,hi-4,hi+4,hi+4)),
                         ('west',(lo-4,lo-4,lo+4,hi+4)),('east',(hi-4,lo-4,hi+4,hi+4))]:
            free_rectangle(f'escape_loop_{i+1}_{side}',box,8)
    for side,box in [('south',(126,16,130,86)),('north',(126,170.4,130,247)),
                     ('west',(16,126,86,130)),('east',(170.4,126,248,130))]:
        free_rectangle(f'funnel_{side}_continuous_throat_route',box,4)
    gates=[]
    for r,g in [(42,4),(78,12),(104,16),(124,24)]:
        for side in ['south','north','west','east']:
            line=128-r+.2 if side=='south' else 128+r+.2 if side in ['north','east'] else 128-r-.2
            horizontal=side in ['north','south']
            intervals=[(a,c) if horizontal else (b,d) for a,b,c,d in rectangles
                       if ((b+1e-5<line<d-1e-5) if horizontal else (a+1e-5<line<c-1e-5))]
            left=max(c for a,c in intervals if c<=128+1e-5)
            right=min(a for a,c in intervals if a>=128-1e-5)
            measured=right-left
            if abs(measured-g)>1e-4:issues.append(['gate_width',r,side,g,measured])
            gates.append({'name':f'ring_{r}_{side}','required_width_m':g,'clear_width_m':round(measured,6),
                          'measured_section_coordinate_m':line,'edge_coordinates_m':[left,right]})
    # Flood-fill at 1 m: a cell is blocked if its interior intersects any solid footprint.
    blocked=set()
    for a,b,c,d in rectangles:
        for x in range(max(0,math.floor(a+1e-6)),min(256,math.ceil(c-1e-6))):
            for z in range(max(0,math.floor(b+1e-6)),min(256,math.ceil(d-1e-6))):blocked.add((x,z))
    start=(128,16);queue=[start];seen={start}
    for x,z in queue:
        for q in [(x-1,z),(x+1,z),(x,z-1),(x,z+1)]:
            if 0<=q[0]<256 and 0<=q[1]<256 and q not in seen and q not in blocked:seen.add(q);queue.append(q)
    goals={'arena':(128,128),'extraction':(128,246),'west_gate':(84,128),'east_gate':(172,128)}
    reachable={name:p in seen for name,p in goals.items()}
    if not all(reachable.values()):issues.append(['unreachable',reachable])
    report={'passed':not issues,'instance_count':len(items),'pair_count':pairs,'issues':issues,
            'coordinate_units':'metres','overlap_count':sum(e[0]=='overlap' for e in issues),
            'pair_distances_file':'piece_distances.csv','distance_method':'Exact Euclidean distance between filled rectangular projections measured from the exported GLBs; cardinal rotations.',
            'contacts_count':len(contacts),'contacts_are':'Shared assembly boundaries, not passages; no positive area overlap.',
            'minimum_noncontact_separation_m':min_positive,
            'unclassified_gaps_below_3m':narrow,'gate_widths':gates,'corridors':corridors,
            'navigation_1m':{'method':'cell-interior intersection; four-neighbour flood-fill, no agent-radius erosion',
                             'start':start,'reachable_goals':reachable,'reachable_cells':len(seen)},
            'nearest_neighbours':[{'instance':i,'module':items[i]['module'],'nearest_instance':j,'distance_m':round(d,6)} for i,(d,j) in enumerate(nearest)],
            'limits':['Plan-only geometry checks; not Godot collision, navigation, character motion or spawn tests.',
                      'Corridor reserved rectangles are checked continuously in plan; path turns included by overlapping rectangles.',
                      'Flood-fill is only a secondary 1 m connectivity check, not proof of agent-radius navigation.',
                      'Contacting wall seams and platform/ramp mounting seam are not corridors.',
                      'Side clearance on escape loops is 4 m each side of their defined centre line; reserved total width 8 m.']}
    if write:
        (ROOT/'layout_validation.json').write_text(json.dumps(report,indent=2)+'\n')
        with open(ROOT/'corridor_widths.csv','w',newline='',encoding='utf-8') as f:
            writer=csv.writer(f);writer.writerow(['corridor','type','minimum_clear_width_m','required_half_width_m','continuous_plan_check_passed'])
            for entry in corridors:writer.writerow([entry['name'],'reserved_route',entry['width_m'],entry['width_m']/2,not entry['blocking_instances']])
            for gate in gates:writer.writerow([gate['name'],'measured_gate_section',gate['clear_width_m'],gate['required_width_m']/2,abs(gate['clear_width_m']-gate['required_width_m'])<1e-4])
        with open(ROOT/'nearest_distances.csv','w',newline='',encoding='utf-8') as f:
            writer=csv.writer(f);writer.writerow(['instance','module','nearest_instance','minimum_plan_distance_m'])
            for i,(d,j) in enumerate(nearest):writer.writerow([i,items[i]['module'],j,f'{d:.6f}'])
    return report


if __name__=='__main__':
    ROOT.mkdir(parents=True,exist_ok=True)
    items,features=generate();result=check_layout(items,features)
    print('LAYOUT',result['instance_count'],'PAIRS',result['pair_count'],'PASS',result['passed'])
    if result['issues']:print(json.dumps(result['issues'],indent=2));raise SystemExit(1)
