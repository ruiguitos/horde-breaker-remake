"""Blocky enemies for Horde Breaker (Blender 5.2, CC0 output). See docs/tech/MODELS_ROUND_BRIEF.md.

  blender -b --factory-startup --python build_enemy.py -- <walker|brute|grabber|bloater|screamer|behemoth>

Each enemy is chamfered boxes grouped into the parts the game's shader animates
(Head, Torso, Arm_Left, Arm_Right, Leg_Left, Leg_Right, plus Belly / Armor_Front),
with the pivot of each part at its joint. Blender axes: Z up, +Y = the enemy's front
(the glTF exporter turns that into +Y up, -Z forward); anatomical Left is -X.
Materials share one 1K atlas per model (base colour, roughness, normal), one 512 px
quadrant per material, generated here with numpy noise. No downloaded meshes or textures.
"""
import bpy, bmesh, json, math, os, sys
import numpy as np
from mathutils import Vector, Matrix, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
CHAR_DIR = os.path.abspath(os.path.join(HERE, ".."))
ATLAS = 1024
QUAD = {0: (0.0, 0.5), 1: (0.5, 0.5), 2: (0.0, 0.0), 3: (0.5, 0.0)}  # material slot -> UV origin

# Base colour (linear), roughness, grain scale, blotch colour, height strength per material.
MATS = {
    "skin_rot": ((0.17, 0.21, 0.14), 0.78, 18, (0.07, 0.08, 0.05), 0.5),
    "cloth_shirt": ((0.24, 0.235, 0.22), 0.92, 70, (0.11, 0.085, 0.06), 0.35),
    "cloth_trousers": ((0.15, 0.15, 0.155), 0.95, 60, (0.07, 0.06, 0.05), 0.35),
    "flesh_wound": ((0.33, 0.035, 0.03), 0.45, 26, (0.12, 0.01, 0.01), 0.8),
    "bone": ((0.62, 0.58, 0.47), 0.6, 30, (0.40, 0.33, 0.24), 0.4),
    "scrap_metal": ((0.30, 0.27, 0.24), 0.7, 40, (0.32, 0.13, 0.05), 0.6),
}


def B(c, s, mat, rot=(0, 0, 0)):
    """A box: centre, size (m), material name, rotation (degrees XYZ)."""
    return (Vector(c), Vector(s), mat, rot)


def mirror(boxes):
    return [(Vector((-c.x, c.y, c.z)), s, m, (r[0], -r[1], -r[2])) for c, s, m, r in boxes]


# ---------------------------------------------------------------- the enemies
def walker():
    """1.95 m common zombie (also drawn as the Runner), on ZombieModel's joints: hip (±0.12, 0.92),
    shoulder (±0.25, 1.49), neck 1.58; the skull centre near 1.80 m, where the game aims headshots."""
    leg_l = [
        B((-0.12, 0, 0.72), (0.17, 0.19, 0.40), "cloth_trousers"),
        B((-0.12, 0, 0.40), (0.155, 0.17, 0.26), "cloth_trousers"),
        B((-0.12, 0.005, 0.17), (0.12, 0.13, 0.22), "skin_rot"),          # torn trouser: bare shin
        B((-0.12, 0.0, 0.29), (0.165, 0.18, 0.05), "cloth_trousers", (6, 0, 4)),  # ragged hem
        B((-0.12, 0.05, 0.04), (0.12, 0.27, 0.08), "skin_rot"),
        B((-0.12, 0.17, 0.035), (0.11, 0.05, 0.06), "skin_rot", (12, 0, 0)),
    ]
    leg_r = mirror(leg_l)
    leg_r[2] = B((0.12, 0.005, 0.17), (0.12, 0.13, 0.22), "flesh_wound")  # chewed shin
    leg_r.append(B((0.12, 0.0, 0.17), (0.035, 0.035, 0.30), "skin_rot"))   # shin bone
    torso = [
        B((0, 0, 0.97), (0.38, 0.22, 0.16), "cloth_trousers"),
        B((0, 0, 1.13), (0.35, 0.20, 0.18), "cloth_shirt"),
        B((0, 0.03, 1.33), (0.44, 0.24, 0.26), "cloth_shirt", (-10, 0, 0)),
        B((0, 0.05, 1.47), (0.47, 0.22, 0.08), "cloth_shirt", (-14, 0, 0)),
        B((0, 0.05, 1.59), (0.15, 0.14, 0.18), "skin_rot", (-20, 0, 0)),
        # Torn belly: the shirt is ripped open on the front left, flesh and ribs show.
        B((-0.07, 0.096, 1.15), (0.17, 0.02, 0.15), "flesh_wound"),
        B((-0.07, 0.11, 1.12), (0.15, 0.016, 0.016), "skin_rot"),
        B((-0.07, 0.11, 1.16), (0.15, 0.016, 0.016), "skin_rot"),
        B((-0.07, 0.11, 1.20), (0.15, 0.016, 0.016), "skin_rot"),
        B((0.10, 0.122, 1.30), (0.12, 0.012, 0.16), "flesh_wound"),         # blood down the chest
        B((0.11, 0.118, 1.36), (0.18, 0.02, 0.05), "cloth_shirt", (0, 18, 0)),  # torn flap
        B((-0.05, -0.122, 1.36), (0.20, 0.01, 0.12), "flesh_wound"),       # bite on the back
    ]
    # The whole head hangs forward: every box turns 15 degrees about the neck (0, 1.55).
    neck = Vector((0, 0, 1.55))
    tilt = Euler((math.radians(-15), 0, 0)).to_matrix()
    head = [(neck + tilt @ (c - neck) + Vector((0, 0.07, 0.125)), sz, m, (r[0] - 15, r[1], r[2])) for c, sz, m, r in [
        B((0, 0.01, 1.69), (0.25, 0.25, 0.25), "skin_rot"),
        B((0, 0.035, 1.585), (0.175, 0.17, 0.06), "skin_rot", (8, 0, 0)),    # dropped jaw
        B((0, 0.12, 1.615), (0.15, 0.02, 0.04), "flesh_wound"),           # open mouth
        B((-0.055, 0.132, 1.70), (0.05, 0.012, 0.035), "flesh_wound"),       # eye sockets
        B((0.055, 0.132, 1.70), (0.05, 0.012, 0.035), "flesh_wound"),
        B((0, 0.145, 1.655), (0.045, 0.03, 0.05), "skin_rot"),
        B((-0.132, 0.0, 1.68), (0.03, 0.06, 0.07), "skin_rot"),
        B((0.132, 0.0, 1.68), (0.03, 0.06, 0.07), "skin_rot"),
        B((0.06, -0.03, 1.80), (0.10, 0.13, 0.02), "flesh_wound"),          # scalp torn off
        B((-0.04, -0.02, 1.805), (0.11, 0.17, 0.015), "cloth_trousers"),    # dark matted hair
    ]]
    arm_l = [
        B((-0.275, 0, 1.36), (0.12, 0.135, 0.27), "cloth_shirt"),
        B((-0.28, 0.0, 1.075), (0.10, 0.11, 0.30), "skin_rot"),
        B((-0.28, 0.01, 0.865), (0.09, 0.05, 0.12), "skin_rot"),
        B((-0.265, 0.025, 0.79), (0.02, 0.022, 0.06), "skin_rot"),
        B((-0.285, 0.025, 0.785), (0.02, 0.022, 0.07), "skin_rot"),
        B((-0.305, 0.025, 0.79), (0.02, 0.022, 0.06), "skin_rot"),
        B((-0.28, 0.058, 1.10), (0.07, 0.01, 0.12), "flesh_wound"),
    ]
    arm_r = mirror(arm_l)
    arm_r[1] = B((0.28, 0.0, 1.075), (0.10, 0.11, 0.30), "flesh_wound")     # flayed forearm
    arm_r.append(B((0.28, 0.0, 1.075), (0.04, 0.12, 0.31), "skin_rot"))
    parts = {
        "Torso": (Vector((0, 0, 0)), torso),
        "Head": (Vector((0, 0.02, 1.58)), head),
        "Arm_Left": (Vector((-0.25, 0, 1.49)), arm_l),
        "Arm_Right": (Vector((0.25, 0, 1.49)), arm_r),
        "Leg_Left": (Vector((-0.12, 0, 0.92)), leg_l),
        "Leg_Right": (Vector((0.12, 0, 0.92)), leg_r),
    }
    return {"height": 1.95, "budget": (1500, 2500),
            "materials": ["skin_rot", "cloth_shirt", "cloth_trousers", "flesh_wound"], "parts": parts}


# Specials are authored in the game's model space (special_enemy_model.gd: the joints of
# profile(kind), a body about 1.95 m tall) and exported at their real size: scale =
# EnemyType.height / 1.7 (ZombieModel.MODEL_HEIGHT). The game divides it back out, so the
# shader's joints and the headshot height line up. Profiles copied from profile(kind).
def _prof(hip=(0.12, 0.92), knee=(0.12, 0.50), shoulder=(0.25, 1.49), elbow=(0.27, 1.19), waist=1.02,
          head_y=1.79):
    return {"hip": hip, "knee": knee, "shoulder": shoulder, "elbow": elbow, "waist": waist, "head_y": head_y}


def _head_y(height, radius_scale):
    return (height + 0.08 * radius_scale) / height * 1.7


def humanoid(p, lw, aw, hand_y, chest_d=0.24, top="cloth_shirt", bottom="cloth_trousers",
             skull=0.25, hunch=-12, head_tilt=-15):
    """A base body on the profile p: lists of boxes per part (Blender axes, left on -X)."""
    hx, hy = p["hip"]; kx, ky = p["knee"]; sx, sy = p["shoulder"]; ex, ey = p["elbow"]
    wy, head_y = p["waist"], p["head_y"]
    neck_y = head_y - 0.21
    leg_l = [
        B((-hx, 0, (hy + ky) / 2), (lw, lw * 1.1, hy - ky + 0.05), bottom),
        B((-kx, 0, ky / 2 + 0.05), (lw * 0.85, lw * 0.95, ky - 0.04), bottom),
        B((-kx, 0.06, 0.045), (lw * 0.85, 0.26, 0.09), "skin_rot"),
    ]
    chest_w = 2 * sx - 0.04
    torso = [
        B((0, 0, wy - 0.03), (2 * hx + lw, 0.22, 0.2), bottom),
        B((0, 0.01, (wy + sy - 0.3) / 2 + 0.02), (chest_w * 0.82, chest_d * 0.9, sy - 0.3 - wy + 0.06), top),
        B((0, 0.03, sy - 0.16), (chest_w, chest_d, 0.3), top, (hunch, 0, 0)),
        B((0, 0.05, sy - 0.01), (chest_w + 0.04, chest_d * 0.9, 0.08), top, (hunch - 4, 0, 0)),
        B((0, 0.05, (sy + neck_y) / 2 + 0.02), (0.15, 0.14, neck_y - sy + 0.12), "skin_rot", (-20, 0, 0)),
    ]
    neck = Vector((0, 0.02, neck_y))
    tilt = Euler((math.radians(head_tilt), 0, 0)).to_matrix()
    k = skull / 0.25
    raw = [
        B((0, 0.01, head_y - 0.11 * k), (skull, skull, skull), "skin_rot"),
        B((0, 0.035, head_y - 0.215 * k), (skull * 0.7, skull * 0.68, 0.06), "skin_rot", (8, 0, 0)),
        B((0, 0.01 + skull * 0.44, head_y - 0.185 * k), (skull * 0.6, 0.02, 0.04), "flesh_wound"),
        B((-0.055 * k, 0.012 + skull / 2, head_y - 0.1 * k), (0.05 * k, 0.012, 0.035 * k), "flesh_wound"),
        B((0.055 * k, 0.012 + skull / 2, head_y - 0.1 * k), (0.05 * k, 0.012, 0.035 * k), "flesh_wound"),
        B((0, 0.02 + skull / 2, head_y - 0.145 * k), (0.045 * k, 0.03, 0.05 * k), "skin_rot"),
        B((-skull / 2 - 0.007, 0.0, head_y - 0.12 * k), (0.03, 0.06 * k, 0.07 * k), "skin_rot"),
        B((skull / 2 + 0.007, 0.0, head_y - 0.12 * k), (0.03, 0.06 * k, 0.07 * k), "skin_rot"),
    ]
    # +0.1 m: the skull centre lands on head_y, where the game aims headshots.
    head = [(neck + tilt @ (c - neck) + Vector((0, 0.05, 0.1)), sz, m, (r[0] + head_tilt, r[1], r[2])) for c, sz, m, r in raw]
    arm_l = [
        B((-(sx + ex) / 2, 0, (sy + ey) / 2), (aw, aw * 1.05, sy - ey + 0.05), "skin_rot"),
        B((-ex, 0, (ey + hand_y) / 2), (aw * 0.85, aw * 0.9, ey - hand_y + 0.04), "skin_rot"),
        B((-ex, 0.01, hand_y - 0.05), (aw * 0.95, aw * 0.55, 0.13), "skin_rot"),
    ]
    pivots = {"Torso": Vector((0, 0, 0)), "Head": neck, "Arm_Left": Vector((-sx, 0, sy)),
              "Arm_Right": Vector((sx, 0, sy)), "Leg_Left": Vector((-hx, 0, hy)), "Leg_Right": Vector((hx, 0, hy))}
    return {"Torso": torso, "Head": head, "Arm_Left": arm_l, "Arm_Right": mirror(arm_l),
            "Leg_Left": leg_l, "Leg_Right": mirror(leg_l)}, pivots


def _assemble(boxes, pivots, extra=None):
    parts = {name: (pivots[name], boxes[name]) for name in boxes}
    for name, (pivot, bx) in (extra or {}).items():
        parts[name] = (pivot, bx)
    return parts


def _fingers(x, y, z, length, mat, n=3, spread=0.04, w=0.022):
    return [B((x - spread + i * spread, y, z - length / 2), (w, w * 1.1, length), mat) for i in range(n)]


def brute():
    """Very broad, 2.4 m in game: scrap armour plate on the chest front (blocks frontal shots)."""
    p = _prof(hip=(0.18, 0.92), knee=(0.18, 0.50), shoulder=(0.38, 1.48), elbow=(0.42, 1.12),
              head_y=_head_y(2.4, 1.6))
    b, pv = humanoid(p, lw=0.22, aw=0.21, hand_y=0.78, chest_d=0.36, top="skin_rot", skull=0.23, hunch=-16, head_tilt=-8)
    b["Torso"] += [
        B((0.0, -0.13, 1.44), (0.5, 0.16, 0.16), "skin_rot", (-10, 0, 0)),          # hunched back muscle
        B((-0.24, 0.18, 1.16), (0.12, 0.02, 0.18), "flesh_wound"),                  # gash beside the plate
        B((0.0, -0.19, 1.2), (0.3, 0.02, 0.2), "flesh_wound"),                      # torn back
    ]
    for side in (-1, 1):
        b["Arm_Left" if side < 0 else "Arm_Right"] += [
            B((0.42 * side, 0.02, 0.68), (0.2, 0.16, 0.14), "skin_rot"),                # big fist
            B((0.40 * side, 0.0, 1.40), (0.25, 0.25, 0.14), "scrap_metal", (0, 0, 8 * side)),  # pauldron
            B((0.43 * side, 0.12, 1.0), (0.1, 0.02, 0.16), "flesh_wound"),
        ]
    armor = [
        B((0, 0.215, 1.30), (0.62, 0.05, 0.42), "scrap_metal", (-14, 0, 0)),
        B((0, 0.23, 1.04), (0.46, 0.05, 0.2), "scrap_metal", (-4, 0, 2)),
        B((-0.2, 0.25, 1.42), (0.05, 0.02, 0.05), "scrap_metal"),
        B((0.2, 0.25, 1.42), (0.05, 0.02, 0.05), "scrap_metal"),
        B((-0.2, 0.25, 1.17), (0.05, 0.02, 0.05), "scrap_metal"),
        B((0.2, 0.25, 1.17), (0.05, 0.02, 0.05), "scrap_metal"),
        B((-0.33, 0.12, 1.3), (0.05, 0.28, 0.06), "cloth_trousers", (0, 0, 30)),    # straps
        B((0.33, 0.12, 1.3), (0.05, 0.28, 0.06), "cloth_trousers", (0, 0, -30)),
    ]
    return {"height_game": 2.4, "budget": (2500, 4000), "segments": 2, "round_above": 0.12,
            "materials": ["skin_rot", "cloth_trousers", "flesh_wound", "scrap_metal"],
            "parts": _assemble(b, pv, {"Armor_Front": (Vector((0, 0, 1.02)), armor)})}


def grabber():
    """Thin and stooped, 1.9 m in game: long arms with bony reaching fingers."""
    p = _prof(shoulder=(0.27, 1.49), elbow=(0.38, 1.04), head_y=_head_y(1.9, 1.1))
    b, pv = humanoid(p, lw=0.11, aw=0.09, hand_y=0.48, chest_d=0.2, top="skin_rot", skull=0.23, hunch=-22, head_tilt=-22)
    b["Torso"] += [B((0.07 * s, 0.12, 1.12 + 0.045 * i), (0.12, 0.016, 0.016), "bone")
                   for s in (-1, 1) for i in range(4)]                                # ribs through the skin
    b["Torso"] += [B((0, 0.11, 1.14), (0.06, 0.012, 0.2), "flesh_wound"),
                   B((0, -0.11, 1.3), (0.04, 0.02, 0.36), "bone")]                    # spine ridge
    for side in (-1, 1):
        arm = b["Arm_Left" if side < 0 else "Arm_Right"]
        arm += _fingers(0.38 * side, 0.03, 0.43, 0.2, "bone")
        arm += [B((0.38 * side, 0.05, 0.8), (0.07, 0.02, 0.18), "flesh_wound")]
    b["Leg_Left"] += [B((-0.12, 0.06, 0.62), (0.1, 0.012, 0.12), "flesh_wound")]
    return {"height_game": 1.9, "budget": (2000, 3500), "segments": 2, "round_above": 0.1,
            "materials": ["skin_rot", "cloth_trousers", "flesh_wound", "bone"],
            "parts": _assemble(b, pv)}


def bloater():
    """Squat, 1.6 m in game: a swollen belly (its own part) that bursts."""
    p = _prof(hip=(0.23, 0.67), knee=(0.24, 0.34), shoulder=(0.43, 1.42), elbow=(0.48, 1.08), waist=0.80,
              head_y=_head_y(1.6, 1.7))
    b, pv = humanoid(p, lw=0.2, aw=0.17, hand_y=0.79, chest_d=0.32, skull=0.24, hunch=-6, head_tilt=-6)
    belly = [
        B((0, 0.14, 1.02), (0.74, 0.58, 0.56), "skin_rot"),
        B((0, 0.3, 0.98), (0.6, 0.36, 0.42), "skin_rot"),
        B((0, 0.1, 1.27), (0.56, 0.4, 0.12), "cloth_shirt", (-8, 0, 0)),          # shirt rolled up
        B((0.18, 0.47, 1.08), (0.14, 0.04, 0.12), "flesh_wound"),                 # pustules and splits
        B((-0.16, 0.47, 0.9), (0.1, 0.04, 0.1), "flesh_wound"),
        B((0.02, 0.48, 0.82), (0.16, 0.03, 0.05), "flesh_wound"),
        B((-0.33, 0.24, 1.08), (0.06, 0.12, 0.1), "flesh_wound"),
        B((0.34, 0.2, 0.92), (0.05, 0.1, 0.1), "flesh_wound"),
        B((0, 0.42, 1.14), (0.3, 0.04, 0.03), "flesh_wound"),
    ]
    return {"height_game": 1.6, "budget": (2500, 4000), "segments": 2,
            "materials": ["skin_rot", "cloth_shirt", "cloth_trousers", "flesh_wound"],
            "parts": _assemble(b, pv, {"Belly": (Vector((0, 0, 0.8)), belly)})}


def screamer():
    """Thin, 1.8 m in game: head thrown back, jaw wide open."""
    p = _prof(head_y=_head_y(1.8, 0.8))
    b, pv = humanoid(p, lw=0.12, aw=0.1, hand_y=0.87, chest_d=0.2, skull=0.24, hunch=-4, head_tilt=28)
    neck = pv["Head"]
    open_jaw = Euler((math.radians(-40), 0, 0)).to_matrix()
    jaw_pivot = Vector((0, 0.1, neck.z + 0.05))
    b["Head"][1] = (jaw_pivot + open_jaw @ (b["Head"][1][0] - jaw_pivot), b["Head"][1][1], "skin_rot", (-10, 0, 0))
    b["Head"] += [B((0, 0.13, neck.z + 0.17), (0.17, 0.08, 0.12), "flesh_wound", (28, 0, 0)),  # gaping mouth
                  B((0, 0.05, neck.z + 0.08), (0.06, 0.1, 0.1), "flesh_wound")]               # torn throat
    b["Torso"] += [B((0.08, 0.11, 1.2), (0.14, 0.02, 0.18), "flesh_wound"),
                   B((-0.1, 0.12, 1.33), (0.16, 0.02, 0.06), "cloth_shirt", (0, 25, 0))]      # torn shirt flap
    for side in (-1, 1):
        b["Arm_Left" if side < 0 else "Arm_Right"] += _fingers(0.27 * side, 0.02, 0.8, 0.07, "skin_rot", w=0.018)
    return {"height_game": 1.8, "height": 1.9, "budget": (2000, 3500), "segments": 2, "round_above": 0.1,
            "materials": ["skin_rot", "cloth_shirt", "cloth_trousers", "flesh_wound"],
            "parts": _assemble(b, pv)}


def behemoth():
    """The boss, 4.2 m in game: heavy arms, bone spikes, plates, a readable weak head."""
    p = _prof(hip=(0.2, 0.92), knee=(0.2, 0.50), shoulder=(0.44, 1.46), elbow=(0.51, 1.08),
              head_y=_head_y(4.2, 3.0))
    b, pv = humanoid(p, lw=0.24, aw=0.26, hand_y=0.68, chest_d=0.42, top="skin_rot", bottom="skin_rot",
                     skull=0.26, hunch=-18, head_tilt=-10)
    # The weak point: the skull is split and the brain shows, bright and easy to read.
    nz = pv["Head"].z
    b["Head"] += [B((0, 0.05, nz + 0.3), (0.2, 0.2, 0.05), "flesh_wound"),
                  B((0, 0.05, nz + 0.33), (0.12, 0.14, 0.03), "flesh_wound")]
    b["Torso"] += [B((0.1 * s, 0.22, 1.12 + 0.06 * i), (0.16, 0.02, 0.02), "bone") for s in (-1, 1) for i in range(5)]
    b["Torso"].append(B((0, 0.215, 1.24), (0.3, 0.02, 0.36), "flesh_wound"))                   # open chest
    b["Torso"] += [B((0, -0.2, 1.1 + 0.11 * i), (0.06, 0.06, 0.06), "bone") for i in range(4)]  # spine
    # Bone spikes along the back and shoulders.
    for i, (x, z, ang) in enumerate([(-0.16, 1.48, 30), (0.16, 1.48, -30), (-0.26, 1.38, 40), (0.26, 1.38, -40),
                                     (-0.1, 1.28, 25), (0.1, 1.28, -25), (0.0, 1.55, 0)]):
        b["Torso"].append(B((x, -0.22, z + 0.08), (0.05, 0.05, 0.22), "bone", (-35, ang * 0.3, ang)))
    b["Torso"] += [B((0, -0.16, 1.3), (0.6, 0.12, 0.4), "scrap_metal", (12, 0, 0)),             # chained plate
                   B((0, 0.0, 0.98), (0.56, 0.3, 0.06), "scrap_metal")]                          # belt of scrap
    for side in (-1, 1):
        arm = b["Arm_Left" if side < 0 else "Arm_Right"]
        x = 0.51 * side
        arm += [B((x, 0.02, 0.56), (0.3, 0.26, 0.22), "skin_rot"),                                   # huge fist
                B((x, 0.13, 0.56), (0.28, 0.04, 0.06), "bone"),                                       # knuckle bones
                B((0.46 * side, 0.0, 1.42), (0.34, 0.34, 0.18), "scrap_metal", (0, 0, 10 * side)),
                B((0.47 * side, 0.15, 1.2), (0.16, 0.03, 0.22), "flesh_wound"),
                B((0.5 * side, -0.15, 0.95), (0.05, 0.05, 0.2), "bone", (40, 0, 0)),                  # elbow spike
                B((x, 0.14, 0.86), (0.14, 0.03, 0.14), "flesh_wound")]
        leg = b["Leg_Left" if side < 0 else "Leg_Right"]
        leg += [B((0.2 * side, 0.15, 0.55), (0.18, 0.06, 0.14), "scrap_metal"),                   # knee plate
                B((0.2 * side, 0.14, 0.75), (0.12, 0.03, 0.14), "flesh_wound"),
                B((0.2 * side, 0.1, 0.03), (0.26, 0.38, 0.06), "skin_rot")]                         # wide feet
    return {"height_game": 4.2, "budget": (6000, 9000), "segments": 2,
            "materials": ["skin_rot", "flesh_wound", "bone", "scrap_metal"],
            "parts": _assemble(b, pv)}


ENEMIES = {"walker": walker, "brute": brute, "grabber": grabber, "bloater": bloater,
           "screamer": screamer, "behemoth": behemoth}


# ---------------------------------------------------------------- textures
def _noise(size, scale, seed):
    """Tileable value noise with three octaves, 0..1."""
    rng = np.random.default_rng(seed)
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for octave in range(3):
        cells = max(2, int(scale * (2 ** octave) / 8))
        grid = rng.random((cells, cells))
        x = np.linspace(0, cells, size, endpoint=False)
        i0 = np.floor(x).astype(int)
        f = x - i0
        f = f * f * (3 - 2 * f)
        i1 = (i0 + 1) % cells
        a = grid[np.ix_(i0, i0)]; b = grid[np.ix_(i0, i1)]
        c = grid[np.ix_(i1, i0)]; d = grid[np.ix_(i1, i1)]
        fx = f[None, :]; fy = f[:, None]
        out += amp * ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy)
        total += amp
        amp *= 0.5
    return out / total


def build_atlas(names, seed):
    half = ATLAS // 2
    col = np.zeros((ATLAS, ATLAS, 4), np.float32); col[..., 3] = 1
    rough = np.zeros((ATLAS, ATLAS, 4), np.float32); rough[..., 3] = 1
    height = np.zeros((ATLAS, ATLAS), np.float32)
    for slot, name in enumerate(names):
        base, r, grain, blotch, hs = MATS[name]
        n1 = _noise(half, grain, seed + slot)
        n2 = _noise(half, grain * 4, seed + 10 + slot)
        mask = np.clip((_noise(half, 10, seed + 20 + slot) - 0.55) * 4, 0, 1)
        c = np.array(base)[None, None, :] * (0.8 + 0.4 * n1[..., None])
        c = c * (1 - mask[..., None]) + np.array(blotch)[None, None, :] * mask[..., None]
        if name == "cloth_shirt" or name == "cloth_trousers":   # dried blood stains on cloth
            blood = np.clip((_noise(half, 7, seed + 40 + slot) - 0.62) * 5, 0, 1)
            c = c * (1 - blood[..., None]) + np.array((0.12, 0.012, 0.01))[None, None, :] * blood[..., None]
        ox, oy = QUAD[slot]
        x0, y0 = int(ox * ATLAS), int(oy * ATLAS)
        col[y0:y0 + half, x0:x0 + half, :3] = c
        rough[y0:y0 + half, x0:x0 + half, :3] = np.clip(r + (n2 - 0.5) * 0.2 - mask * 0.1, 0, 1)[..., None]
        height[y0:y0 + half, x0:x0 + half] = (n2 * 0.6 + n1 * 0.4) * hs
    gy, gx = np.gradient(height * 6.0)
    nrm = np.stack([-gx, -gy, np.ones_like(gx)], axis=2)
    nrm /= np.linalg.norm(nrm, axis=2, keepdims=True)
    normal = np.ones((ATLAS, ATLAS, 4), np.float32)
    normal[..., :3] = nrm * 0.5 + 0.5
    return col, rough, normal


def save_image(name, pixels, path, srgb):
    img = bpy.data.images.new(name, ATLAS, ATLAS)
    img.colorspace_settings.name = "sRGB" if srgb else "Non-Color"
    px = pixels.copy()
    if srgb:  # linear -> sRGB for an 8-bit PNG
        rgb = px[..., :3]
        px[..., :3] = np.where(rgb <= 0.0031308, rgb * 12.92, 1.055 * np.power(rgb, 1 / 2.4) - 0.055)
    img.pixels.foreach_set(px.ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.source = "FILE"
    img.filepath = path
    img.reload()
    return img


def make_materials(names, tex_dir, model):
    col, rough, normal = build_atlas(names, seed=sum(map(ord, model)))
    os.makedirs(tex_dir, exist_ok=True)
    ic = save_image(model + "_basecolor", col, os.path.join(tex_dir, model + "_basecolor.png"), True)
    ir = save_image(model + "_roughness", rough, os.path.join(tex_dir, model + "_roughness.png"), False)
    inn = save_image(model + "_normal", normal, os.path.join(tex_dir, model + "_normal.png"), False)
    mats = []
    for name in names:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
        bsdf.inputs["Metallic"].default_value = 0.4 if name == "scrap_metal" else 0.0
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = ic
        nt.links.new(t.outputs["Color"], bsdf.inputs["Base Color"])
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = ir
        nt.links.new(t.outputs["Color"], bsdf.inputs["Roughness"])
        t = nt.nodes.new("ShaderNodeTexImage"); t.image = inn
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nt.links.new(t.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], bsdf.inputs["Normal"])
        mats.append(m)
    return mats


# ---------------------------------------------------------------- geometry
def build_part(name, pivot, boxes, names, mats, span, scale=1.0, segments=1, round_above=0.0):
    bm = bmesh.new()
    pivot = pivot * scale
    for c, s, mat, rot in boxes:
        c, s = c * scale, s * scale
        geom = bmesh.ops.create_cube(bm, size=1.0)
        verts = geom["verts"]
        m = Matrix.Translation(c - pivot) @ Euler([math.radians(a) for a in rot]).to_matrix().to_4x4() @ Matrix.Diagonal(s.to_4d())
        bmesh.ops.transform(bm, matrix=m, verts=verts)
        idx = names.index(mat)
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = idx  # before the bevel: its new faces take the material of their box
        edges = {e for v in verts for e in v.link_edges}
        bevel = min(0.012, 0.22 * min(s))
        res = bmesh.ops.bevel(bm, geom=list(verts) + list(edges), offset=bevel, segments=segments if min(s) >= round_above * scale else 1, affect="EDGES",
                              profile=0.5, clamp_overlap=True)
        for f in res.get("faces", []):
            f.material_index = idx
    uv = bm.loops.layers.uv.new("UVMap")
    for f in bm.faces:
        ox, oy = QUAD[f.material_index]
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            p = l.vert.co + pivot
            a, b = [(p.y, p.z), (p.x, p.z), (p.x, p.y)][ax]
            u = ((a / span) + 0.5) % 1.0
            v = ((b / span) + 0.5) % 1.0
            l[uv].uv = (ox + 0.004 + u * 0.492, oy + 0.004 + v * 0.492)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    ob = bpy.data.objects.new(name, me)
    ob.location = pivot
    bpy.context.scene.collection.objects.link(ob)
    return ob


def render_views(model, height, out_dir):
    scn = bpy.context.scene
    engines = [i.identifier for i in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items]
    scn.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in engines else engines[0]
    scn.render.resolution_x, scn.render.resolution_y = 900, 1000
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    w.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.57, 0.6, 1)
    w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    scn.world = w
    for d, e in (((1.0, 1.4, -1.5), 3.2), ((-1.2, -0.6, -0.4), 1.0)):
        s = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
        s.data.energy = e
        s.rotation_euler = Vector(d).to_track_quat("-Z", "Y").to_euler()
        scn.collection.objects.link(s)
    bpy.ops.mesh.primitive_plane_add(size=40)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scn.collection.objects.link(cam); scn.camera = cam
    mid = Vector((0, 0, height * 0.5))
    d = height * 2.6
    views = {"front": Vector((0, d, 0.1)), "side": Vector((d, 0, 0.1)),
             "three_quarter": Vector((d * 0.7, d * 0.7, height * 0.35))}
    for name, off in views.items():
        cam.location = mid + off
        cam.rotation_euler = (-off).to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = 50
        scn.render.filepath = os.path.join(out_dir, "%s_%s.png" % (model, name))
        bpy.ops.render.render(write_still=True)
    # Game camera: 16 m away, 9 m up, looking at the enemy.
    scn.render.resolution_x, scn.render.resolution_y = 1280, 720
    off = Vector((0, 16, 9))
    cam.location = mid + off
    cam.rotation_euler = (-off).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = 35
    scn.render.filepath = os.path.join(out_dir, "%s_game_camera.png" % model)
    bpy.ops.render.render(write_still=True)


def main():
    model = sys.argv[sys.argv.index("--") + 1]
    spec = ENEMIES[model]()
    # Specials are authored in model space (body ~1.95 m) and exported at game size.
    scale = spec.get("height_game", 1.7) / 1.7
    spec.setdefault("height", 1.95 * scale)
    out = os.path.join(CHAR_DIR, model + "_original")
    os.makedirs(out, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    names = spec["materials"]
    mats = make_materials(names, os.path.join(out, "textures"), model)
    objs = {}
    for pname, (pivot, boxes) in spec["parts"].items():
        objs[pname] = build_part(pname, pivot, boxes, names, mats, spec["height"], scale, spec.get("segments", 1),
                                    spec.get("round_above", 0.0))
    for pname, ob in objs.items():
        if pname != "Torso":
            ob.parent = objs["Torso"]
    bpy.context.view_layer.update()
    n_tris = 0
    for ob in objs.values():
        ob.data.calc_loop_triangles(); n_tris += len(ob.data.loop_triangles)
    lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
    for ob in objs.values():
        for v in ob.data.vertices:
            p = ob.matrix_world @ v.co
            lo = Vector(map(min, lo, p)); hi = Vector(map(max, hi, p))
    for ob in bpy.context.scene.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, model + ".glb"), export_format="GLB",
                              export_yup=True, use_selection=True, export_cameras=False,
                              export_lights=False, export_animations=False, export_skins=False,
                              export_image_format="NONE")
    os.makedirs(os.path.join(out, "source"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "source", model + ".blend"))
    lo_b, hi_b = spec["budget"]
    report = {
        "model": model, "license": "CC0-1.0", "units": "metres", "forward": "-Z", "up": "+Y",
        "triangles": n_tris, "triangle_budget": [lo_b, hi_b],
        "height_m": round(hi.z, 4), "model_space_scale": round(scale, 4),
        "game_height_m": spec.get("height_game", 1.7),
        "lowest_point_m": round(lo.z, 4),
        "width_m": round(hi.x - lo.x, 4), "depth_m": round(hi.y - lo.y, 4),
        "materials": names,
        "pivots_m_godot": {k: [round(v[0].x * scale, 4), round(v[0].z * scale, 4), round(-v[0].y * scale, 4)] for k, v in spec["parts"].items()},
        "textures": ["textures/%s_basecolor.png" % model, "textures/%s_roughness.png" % model,
                     "textures/%s_normal.png" % model],
        "texture_source": "numpy noise in build_enemy.py (CC0)",
        "passed": lo_b <= n_tris <= hi_b and abs(hi.z - spec["height"]) <= 0.15 * scale and lo.z >= -0.001,
    }
    with open(os.path.join(out, "validation.json"), "w") as f:
        json.dump(report, f, indent=2)
    with open(os.path.join(out, "LICENSE.txt"), "w") as f:
        f.write("CC0-1.0. Original work for Horde Breaker Remake; built by enemies_build/build_enemy.py.\n")
    render_views(model, spec["height"], os.path.join(out, "renders"))
    print("RESULT", json.dumps({k: report[k] for k in ("passed", "triangles", "height_m", "lowest_point_m")}))


main()
