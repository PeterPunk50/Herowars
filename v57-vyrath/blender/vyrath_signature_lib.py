import bpy, math, json, os
import numpy as np
from mathutils import Matrix, Vector

FPS = 24
DROP = 0.015
TAIL_LIFT = 1.5
HOVER_H = 0.30
PIVOT = Vector((0.15, 0.0, 0.30))          # the body pitches and rolls about roughly its centre of mass


def setup(src):
    G = {}
    bpy.ops.wm.open_mainfile(filepath=src)
    G['arm'] = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    G['body'] = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
    G['vl'] = bpy.data.scenes[0].view_layers[0]
    G['scn'] = bpy.context.scene
    G['scn'].render.fps = FPS
    return G


class Rig:
    def __init__(self, G):
        self.G = G
        self.arm = G['arm']
        self.pb = self.arm.pose.bones
        self.neck = [f'Neck_{i + 1:02d}' for i in range(8)]
        self.tail = [f'Tail_{i + 1:02d}' for i in range(12)]
        self.ANIM = ['tripo::Root', 'Pelvis', 'tripo::Spine_0', 'tripo::Spine_1', 'Jaw', 'Head'] + \
                    [f'Wing_{s}_{b}' for s in 'LR' for b in ('Shoulder', 'Arm', 'Forearm', 'D1_0', 'D2_0', 'D3_0', 'D4_0')] + self.neck + self.tail + \
                    ['IK_Paw_HL', 'IK_Paw_HR', 'IK_Paw_FL', 'IK_Paw_FR']
        self.SCALED = ['Neck_03', 'Neck_04', 'Neck_05']
        self.root_rest = self.arm.data.bones['tripo::Root'].matrix_local.copy()
        self.paw_rest = {k: self.arm.data.bones[f'IK_Paw_{k}'].matrix_local.copy() for k in ('HL', 'HR', 'FL', 'FR')}
        self.TUCK = {'HL': (-0.07, 0.0, 0.0), 'HR': (-0.07, 0.0, 0.0), 'FL': (-0.015, 0.0, 0.0), 'FR': (-0.015, 0.0, 0.0)}   # in flight the hind legs trail back and the front legs hang a touch back; a deeper tuck folds the chest
        self.reset()
        self.base()
        self.T_idle = self.pb['tripo::Root'].matrix @ self.root_rest.inverted()

    # ---------------------------------------------------------------- primitives
    def update(self):
        bpy.context.view_layer.update()

    def reset(self):
        for p in self.pb:
            p.location = (0, 0, 0)
            p.rotation_mode = 'QUATERNION'
            p.rotation_quaternion = (1, 0, 0, 0)
            p.scale = (1, 1, 1)
        self.update()

    def rot(self, bone, axis, deg):
        if abs(deg) < 1e-9:
            return
        p = self.pb[bone]
        m = p.matrix.copy()
        head = m.translation.copy()
        p.matrix = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head) @ m
        self.update()

    def rot_about(self, bone, axis, deg, pivot):
        if abs(deg) < 1e-9:
            return
        p = self.pb[bone]
        m = p.matrix.copy()
        p.matrix = Matrix.Translation(pivot) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-pivot) @ m
        self.update()

    def shift(self, bone, delta):
        p = self.pb[bone]
        m = p.matrix.copy()
        m.translation += Vector(delta)
        p.matrix = m
        self.update()

    # ---------------------------------------------------------------- the standing idle at breath phase 0 (every clip starts and ends on this)
    def base(self):
        self.shift('tripo::Root', (0, 0, -DROP))
        self.rot('Pelvis', 'Z', 2.0 * math.sin(0.5))
        self.rot('Pelvis', 'X', 1.2 * math.sin(-1.0))
        for b in self.neck:
            self.rot(b, 'Y', 0.3 * math.sin(-0.8))
            self.rot(b, 'Z', (6.0 / 8) * math.sin(1.3))
        self.rot('Jaw', 'Y', 2.0 * (0.5 + 0.5 * math.sin(2.0)))
        for i, b in enumerate(self.tail):
            self.rot(b, 'Z', 2.4 * math.sin(-0.35 * (i + 1)))
            self.rot(b, 'Y', TAIL_LIFT + 0.6 * math.sin(-0.5 * (i + 1)))

    # ---------------------------------------------------------------- parameters -> pose
    @staticmethod
    def P0():
        return dict(rx=0, ry=0, rz=0, rpitch=0, rroll=0, ryaw=0, s1=0, s0=0, syaw=0, pel_yaw=0, pel_roll=0, pel_pitch=0,
                    neck_low=0, neck_high=0, neck_yaw=0, head_p=0, head_y=0, jaw=0, throat=0,
                    wup=0, wfwd=0, arm=0, fore=0, fan=0, curl=0, tail_z=[0.0] * 12, tail_y=[0.0] * 12, pf=0, ph=0)

    def apply(self, P):
        self.reset()
        self.base()
        pb = self.pb
        # body
        self.shift('tripo::Root', (P['rx'], P['ry'], P['rz']))
        piv = PIVOT + Vector((P['rx'], P['ry'], P['rz']))
        self.rot_about('tripo::Root', 'Y', P['rpitch'], piv)
        self.rot_about('tripo::Root', 'X', P['rroll'], piv)
        self.rot_about('tripo::Root', 'Z', P['ryaw'], piv)
        Tcur = pb['tripo::Root'].matrix @ self.root_rest.inverted()
        self.rot('tripo::Spine_1', 'Y', P['s1'])
        self.rot('tripo::Spine_0', 'Y', P['s0'])
        self.rot('tripo::Spine_1', 'Z', 0.6 * P['syaw'])
        self.rot('tripo::Spine_0', 'Z', 0.4 * P['syaw'])
        self.rot('Pelvis', 'Z', P['pel_yaw'])
        self.rot('Pelvis', 'X', P['pel_roll'])
        self.rot('Pelvis', 'Y', P['pel_pitch'])
        for i, b in enumerate(self.neck):
            self.rot(b, 'Y', P['neck_low'] if i < 4 else P['neck_high'])
            self.rot(b, 'Z', P['neck_yaw'] * (0.5 / 8 + 0.5 * (i + 1) / 36.0))
        self.rot('Head', 'Y', P['head_p'])
        self.rot('Head', 'Z', P['head_y'])
        self.rot('Jaw', 'Y', P['jaw'])
        if P['throat']:
            for b in self.SCALED:
                pb[b].scale = (1 + P['throat'], 1.0, 1 + P['throat'])
            self.update()
        for side, sg in (('L', 1), ('R', -1)):
            self.rot(f'Wing_{side}_Shoulder', 'X', sg * P['wup'])
            self.rot(f'Wing_{side}_Shoulder', 'Z', -sg * P['wfwd'])
            self.rot(f'Wing_{side}_Arm', 'X', sg * P['arm'])
            self.rot(f'Wing_{side}_Forearm', 'Z', sg * P['fore'])
            for d, a in (('D1_0', 7.0), ('D2_0', 5.0), ('D3_0', 3.0), ('D4_0', 1.5)):
                self.rot(f'Wing_{side}_{d}', 'X', sg * (a * P['fan'] + P['curl']))
        for i, b in enumerate(self.tail):
            self.rot(b, 'Z', P['tail_z'][i])
            self.rot(b, 'Y', P['tail_y'][i])
        # paws: planted at their rest spots, or carried by the body and tucked
        for k in ('HL', 'HR', 'FL', 'FR'):
            w = P['ph'] if k[0] == 'H' else P['pf']
            if w <= 0:
                continue
            att = Tcur @ self.T_idle.inverted() @ self.paw_rest[k]
            att.translation += Tcur.to_3x3() @ Vector(self.TUCK[k])
            pb[f'IK_Paw_{k}'].matrix = self.paw_rest[k].lerp(att, w) if w < 1 else att
            self.update()

    def key(self, f):
        for n in self.ANIM:
            self.pb[n].keyframe_insert('location', frame=f)
            self.pb[n].keyframe_insert('rotation_quaternion', frame=f)
        for n in self.SCALED:
            self.pb[n].keyframe_insert('scale', frame=f)


def ss(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def curve(f, pts):
    if f <= pts[0][0]:
        return pts[0][1]
    for (f0, v0), (f1, v1) in zip(pts[:-1], pts[1:]):
        if f <= f1:
            return v0 + (v1 - v0) * ss((f - f0) / max(f1 - f0, 1e-9))
    return pts[-1][1]


def bump(f, a, b):
    if f < a or f > b:
        return 0.0
    return math.sin(math.pi * (f - a) / (b - a)) ** 2


def lerp_param(A, B, w):
    out = {}
    for k in A:
        if isinstance(A[k], list):
            out[k] = [a + (b - a) * w for a, b in zip(A[k], B[k])]
        else:
            out[k] = A[k] + (B[k] - A[k]) * w
    return out


# ---------------------------------------------------------------- flight
def hover_params(phi):
    P = Rig.P0()
    c, s = math.cos(phi), math.sin(phi)
    P['wup'] = 8 + 38 * c
    P['fore'] = 5.0 * (1 + c) - 2.0 * (1 - c)
    P['fan'] = 0.75 - 0.25 * c
    P['arm'] = 6 * c
    P['curl'] = 3 * c
    P['wfwd'] = 6 + 4 * s
    P['rz'] = HOVER_H - 0.022 * math.cos(phi - 0.6)
    P['rpitch'] = -2 + 3 * math.sin(phi - 0.3)
    P['rroll'] = 2 * math.sin(phi + 1.0)
    P['s1'] = -2 * c
    P['neck_low'] = -0.2
    P['neck_high'] = 0.3
    P['neck_yaw'] = 3 * math.sin(phi * 0.5 + 0.0) * 0 + 3 * math.sin(phi)
    P['tail_z'] = [3.0 * math.sin(phi - 0.45 * (i + 1)) for i in range(12)]
    P['tail_y'] = [-1.0 + 0.8 * math.sin(phi - 0.4 * i) for i in range(12)]
    P['pf'] = 1.0
    P['ph'] = 1.0
    return P


def takeoff_params(f, L=108):
    fend = L + 1
    P = Rig.P0()
    # ---- crouch, unfold, leap, ascend
    P['rz'] = curve(f, [(1, 0), (22, -0.04), (30, -0.04), (46, 0.10), (70, 0.20), (96, 0.27), (fend, HOVER_H)])
    P['rpitch'] = curve(f, [(1, 0), (22, 5), (28, 5), (46, -16), (70, -8), (fend, -2)])
    P['s1'] = curve(f, [(1, 0), (22, 3), (34, -3), (60, -3), (fend, 0)])
    P['neck_low'] = curve(f, [(1, 0), (22, 0.4), (34, -0.5), (60, -0.2), (fend, -0.2)])
    P['neck_high'] = curve(f, [(1, 0), (22, -0.6), (34, 0.6), (60, 0.3), (fend, 0.3)])
    P['head_p'] = curve(f, [(1, 0), (22, 6), (36, -8), (70, -3), (fend, 0)])
    P['jaw'] = curve(f, [(1, 0), (30, 0), (38, 12), (52, 12), (66, 0), (fend, 0)])
    wup = curve(f, [(1, 0), (14, 20), (30, 46), (36, 46), (58, -32), (80, 40), (96, -28), (fend, 8 + 38)])
    P['wup'] = wup
    P['wfwd'] = curve(f, [(1, 0), (14, 4), (34, 8), (60, 6), (fend, 6)])
    P['arm'] = curve(f, [(1, 0), (30, 8), (58, 0), (80, 6), (fend, 6)])
    P['fore'] = curve(f, [(1, 0), (30, -6), (58, -4), (80, 12), (96, -4), (fend, 8)])
    P['fan'] = curve(f, [(1, 0), (14, 0.5), (30, 1.0), (58, 1.0), (80, 0.5), (96, 1.0), (fend, 0.5)])
    P['curl'] = curve(f, [(1, 0), (58, -4), (80, 6), (fend, 3)])
    P['tail_y'] = [curve(f - 0.5 * i, [(1, 0), (22, 1.5), (40, 3.0), (70, 0.5), (fend, -1.0)]) for i in range(12)]
    P['tail_z'] = [curve(f - 0.9 * i, [(1, 0), (30, 0), (46, 4), (62, -3), (80, 3), (fend, 0)]) for i in range(12)]
    P['pf'] = curve(f, [(1, 0), (32, 0), (42, 1), (fend, 1)])
    P['ph'] = curve(f, [(1, 0), (38, 0), (48, 1), (fend, 1)])
    # ---- the last third hands over to the hover cycle, which finishes exactly on its first frame
    phi = 2 * math.pi * (f - fend) / 48.0
    H = hover_params(phi)
    w = ss((f - 80) / 29.0)
    P = lerp_param(P, H, w)
    P['rroll'] += -14 * bump(f, 84, fend)          # the bank
    return P


def landing_params(f, L=120):
    fend = L + 1
    # hover cycle runs on at the start; the landing takes over
    Hh = hover_params(2 * math.pi * (f - 1) / 48.0)
    P = Rig.P0()
    P['rz'] = curve(f, [(1, HOVER_H), (10, HOVER_H), (40, 0.18), (58, 0.05), (64, 0.0), (72, -0.01), (80, -0.045), (96, -0.01), (fend, 0)])
    P['rpitch'] = curve(f, [(1, -2), (14, -6), (30, -20), (52, -16), (62, 4), (72, 2), (84, 0), (fend, 0)])
    P['s1'] = curve(f, [(1, 0), (30, -3), (62, 2), (80, 3), (fend, 0)])
    P['neck_low'] = curve(f, [(1, -0.2), (30, -0.5), (60, 0.2), (80, 0.5), (96, 0.1), (fend, 0)])
    P['neck_high'] = curve(f, [(1, 0.3), (30, 0.6), (60, 0.0), (80, 0.8), (96, 0.1), (fend, 0)])
    P['head_p'] = curve(f, [(1, 0), (30, -6), (62, 4), (80, 8), (fend, 0)])
    P['jaw'] = curve(f, [(1, 0), (28, 0), (36, 10), (56, 10), (68, 0), (fend, 0)])
    P['wup'] = curve(f, [(1, 46), (12, -10), (28, 44), (44, 40), (56, 14), (70, 24), (88, 30), (104, 12), (fend, 0)])
    P['wfwd'] = curve(f, [(1, 6), (20, 14), (44, 22), (62, 10), (88, 4), (fend, 0)])
    P['arm'] = curve(f, [(1, 6), (30, 10), (62, 4), (fend, 0)])
    P['fore'] = curve(f, [(1, 8), (12, -6), (28, -5), (60, 6), (80, 14), (96, 10), (fend, 0)])
    P['fan'] = curve(f, [(1, 0.5), (28, 1.0), (56, 1.0), (88, 0.6), (fend, 0)])
    P['curl'] = curve(f, [(1, 3), (28, -2), (70, 5), (fend, 0)])
    P['tail_y'] = [curve(f - 0.5 * i, [(1, -1.0), (22, 4.0), (56, 5.0), (72, 2.0), (92, 2.5), (108, 0), (fend, 0)]) for i in range(12)]
    P['tail_z'] = [curve(f - 0.9 * i, [(1, 0), (30, 3), (60, -3), (80, 2), (100, 0), (fend, 0)]) for i in range(12)]
    P['pf'] = curve(f, [(1, 1), (50, 1), (62, 0), (fend, 0)])
    P['ph'] = curve(f, [(1, 1), (58, 1), (70, 0), (fend, 0)])
    # at the very start the hover cycle is the pose; fade it out over the first 20 frames
    w = 1 - ss((f - 4) / 20.0)
    P = lerp_param(P, Hh, w) if w > 0 else P
    return P
