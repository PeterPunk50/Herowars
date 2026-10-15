import bpy, math, json, os
import numpy as np
from mathutils import Matrix, Vector

SC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/sig_work/"
LIB = globals().get('SIG_LIB', SC + "vyrath_sig_lib.py")
SRC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_motion_v4.blend"
OUT = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
DO_RENDER = globals().get('DO_RENDER', True)
SAVE = globals().get('SAVE', True)
DO_EXPORT = globals().get('DO_EXPORT', True)
ONLY = globals().get('ONLY', None)
exec(open(LIB).read(), globals())

G = setup(SRC)
R = Rig(G)
arm, body, scn, vl = G['arm'], G['body'], G['scn'], G['vl']
pb = arm.pose.bones
me = body.data
N = len(me.vertices)
for t in arm.animation_data.nla_tracks:
    t.mute = True
arm.animation_data.action = None


def mode(m):
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl):
        bpy.ops.object.mode_set(mode=m)


# paws placed by hand: offset (armature space) and a yaw about the body pivot, applied after R.apply
def place_paw(k, dx=0.0, dz=0.0, yaw=0.0, dy=0.0):
    m = R.paw_rest[k].copy()
    if yaw:
        m = Matrix.Translation(PIVOT) @ Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Translation(-PIVOT) @ m
    m.translation += Vector((dx, dy, dz))
    pb[f'IK_Paw_{k}'].matrix = m
    R.update()


def smooth(w):
    return w * w * (3 - 2 * w)


# ------------------------------------------------------------------ clips
def roar_params(f, L=96):
    fe = L + 1
    P = Rig.P0()
    P['rz'] = curve(f, [(1, 0), (14, -0.02), (34, 0.015), (64, 0.015), (84, -0.005), (fe, 0)])
    P['rpitch'] = curve(f, [(1, 0), (14, 4), (34, -16), (64, -16), (84, 1), (fe, 0)])
    P['pf'] = curve(f, [(1, 0), (18, 0), (30, 1), (66, 1), (82, 0), (fe, 0)])
    P['s1'] = curve(f, [(1, 0), (14, 2), (34, -4), (64, -4), (fe, 0)])
    P['neck_low'] = curve(f, [(1, 0), (14, 0.5), (34, -0.9), (64, -0.9), (fe, 0)])
    P['neck_high'] = curve(f, [(1, 0), (14, 0.3), (34, -0.7), (64, -0.7), (fe, 0)])
    P['head_p'] = curve(f, [(1, 0), (14, 4), (34, -10), (64, -10), (fe, 0)])
    P['jaw'] = curve(f, [(1, 0), (16, 0), (30, 32), (62, 30), (78, 0), (fe, 0)])
    P['throat'] = curve(f, [(1, 0), (14, 0.08), (30, 0.02), (fe, 0)]) * 0.6
    P['wup'] = curve(f, [(1, 0), (14, -4), (34, 32), (62, 30), (fe, 0)]) + 1.5 * math.sin(f * 0.9) * bump(f, 30, 66)
    P['wfwd'] = curve(f, [(1, 0), (34, 6), (62, 6), (fe, 0)])
    P['fan'] = curve(f, [(1, 0), (34, 1.0), (62, 1.0), (fe, 0)])
    P['tail_y'] = [curve(f - 0.5 * i, [(1, 0), (14, 1.0), (34, 6.5), (64, 6.0), (84, 0.5), (fe - 4, 0), (fe, 0)]) for i in range(12)]   # the rear-up pitches the tail down, so lift it
    P['tail_z'] = [curve(f - 0.9 * i, [(1, 0), (20, 0), (34, 5), (48, -5), (62, 4), (80, 0), (fe, 0)]) for i in range(12)]
    return P, {}


def flinch_params(f, L=36):
    fe = L + 1
    P = Rig.P0()
    h = bump(f, 3, 18)
    P['rx'] = -0.03 * h
    P['rz'] = -0.008 * h
    P['rpitch'] = -5 * h
    P['s1'] = -3 * h
    P['neck_low'] = -0.6 * h
    P['neck_high'] = 0.9 * h
    P['head_p'] = 12 * h
    P['jaw'] = 14 * h
    P['wup'] = 16 * h
    P['wfwd'] = -5 * h
    P['tail_z'] = [4.0 * bump(f - 0.6 * i, 3, 22) * (1 if i % 2 == 0 else -1) * 0 + 3.5 * math.sin(0.5 * i) * bump(f - 0.6 * i, 3, 24) for i in range(12)]
    P['tail_y'] = [2.0 * bump(f - 0.5 * i, 3, 20) for i in range(12)]
    return P, {}


def stagger_params(f, L=144):
    fe = L + 1
    P = Rig.P0()
    P['rx'] = curve(f, [(1, 0), (10, -0.04), (26, -0.03), (110, -0.03), (fe, 0)])
    P['rz'] = curve(f, [(1, 0), (10, -0.015), (26, -0.04), (110, -0.04), (128, -0.015), (fe, 0)])
    P['rroll'] = curve(f, [(1, 0), (10, -6), (26, 3), (60, 3), (110, 2), (fe, 0)])
    P['rpitch'] = curve(f, [(1, 0), (10, -4), (26, 8), (110, 8), (fe, 0)])
    P['s1'] = curve(f, [(1, 0), (10, -3), (26, 4), (110, 4), (fe, 0)])
    P['neck_low'] = curve(f, [(1, 0), (10, -0.6), (26, 0.9), (110, 0.85), (128, 0.4), (fe, 0)])
    P['neck_high'] = curve(f, [(1, 0), (10, 0.8), (26, 0.4), (110, 0.5), (fe, 0)])
    P['head_p'] = curve(f, [(1, 0), (10, 10), (26, 8), (110, 8), (fe, 0)])
    P['head_y'] = 3 * math.sin(f * 0.7) * bump(f, 26, 110)
    P['jaw'] = curve(f, [(1, 0), (10, 22), (26, 12), (110, 10), (124, 0), (fe, 0)])
    P['wup'] = curve(f, [(1, 0), (10, 24), (26, -14), (110, -12), (fe, 0)])
    P['wfwd'] = curve(f, [(1, 0), (10, -6), (26, 10), (110, 10), (fe, 0)])
    P['fan'] = curve(f, [(1, 0), (10, 0.8), (26, 0.2), (fe, 0)])
    P['tail_y'] = [curve(f - 0.5 * i, [(1, 0), (10, 3), (26, -2.5), (110, -2.0), (fe - 8, 0), (fe, 0)]) for i in range(12)]
    P['tail_z'] = [curve(f - 0.9 * i, [(1, 0), (10, 6), (24, -4), (40, 2), (60, 0), (fe, 0)]) for i in range(12)]
    return P, {}


def death_params(f, L=144):
    fe = L + 1
    P = Rig.P0()
    P['rz'] = curve(f, [(1, 0), (14, 0.01), (40, -0.065), (70, -0.11), (fe, -0.115)])
    P['rx'] = curve(f, [(1, 0), (40, -0.02), (70, 0.01), (fe, 0.01)])
    P['rpitch'] = curve(f, [(1, 0), (14, -6), (40, 5), (70, 3), (fe, 2)])
    P['rroll'] = curve(f, [(1, 0), (14, 0), (40, 3), (70, 4), (fe, 4)])
    P['s1'] = curve(f, [(1, 0), (14, -3), (40, 3), (70, 2), (fe, 2)])
    P['neck_low'] = curve(f, [(1, 0), (14, -0.8), (40, 4.0), (70, 11.0), (100, 12.0), (fe, 12.0)])
    P['neck_high'] = curve(f, [(1, 0), (14, -0.5), (40, 2.0), (70, 8.0), (100, 9.0), (fe, 9.0)])
    P['head_p'] = curve(f, [(1, 0), (14, -8), (40, 4), (70, 8), (fe, 6)])
    P['head_y'] = curve(f, [(1, 0), (40, 0), (80, 14), (fe, 14)])
    P['neck_yaw'] = curve(f, [(1, 0), (40, 0), (80, 10), (fe, 10)])
    P['jaw'] = curve(f, [(1, 0), (14, 26), (50, 18), (90, 8), (fe, 8)])
    P['wup'] = curve(f, [(1, 0), (14, 28), (40, 2), (70, -16), (100, -19), (fe, -19)])
    P['wfwd'] = curve(f, [(1, 0), (14, 6), (40, 0), (70, -8), (fe, -8)])
    P['fan'] = curve(f, [(1, 0), (14, 1.0), (50, 0.6), (90, 0.3), (fe, 0.3)])
    P['curl'] = curve(f, [(1, 0), (70, 4), (fe, 4)])
    P['tail_y'] = [curve(f - 0.5 * i, [(1, 0), (14, 2), (40, 2.5), (70, 4.3), (fe, 4.5)]) for i in range(12)]   # keeps the tail on the ground as the body sinks
    P['tail_z'] = [curve(f - 0.9 * i, [(1, 0), (14, 4), (36, -5), (56, 3), (80, 0.8), (fe, 0.8)]) for i in range(12)]
    # legs give way: front paws slide forward and out, hind paws back, so the body can reach the ground
    sl = curve(f, [(1, 0), (30, 0), (70, 1), (fe, 1)])
    paws = {'FL': (0.09 * sl, 0.0, 0.03 * sl), 'FR': (0.09 * sl, 0.0, -0.03 * sl), 'HL': (-0.05 * sl, 0.0, 0.02 * sl), 'HR': (-0.05 * sl, 0.0, -0.02 * sl)}
    return P, {'slide': paws}


TURN_T = 84
STEP_ORDER = ['HL', 'FL', 'HR', 'FR'] * 3
STEP_STARTS = [4 + 6 * i for i in range(12)]
STEP_LEN = 6


def turn_state(f):
    """Per-paw yaw and lift during the left turn, plus the body yaw."""
    yaw, lift = {k: 0.0 for k in ('HL', 'HR', 'FL', 'FR')}, {k: 0.0 for k in ('HL', 'HR', 'FL', 'FR')}
    for n, (k, s) in enumerate(zip(STEP_ORDER, STEP_STARTS)):
        target = 30.0 * (n // 4 + 1)
        if f >= s + STEP_LEN:
            yaw[k] = target
        elif f > s:
            w = smooth((f - s) / STEP_LEN)
            yaw[k] = target - 30.0 + 30.0 * w
            lift[k] = (0.04 if k[0] == 'H' else 0.03) * math.sin(math.pi * (f - s) / STEP_LEN)
    body = sum(yaw.values()) / 4.0
    return yaw, lift, body


def turn_params(f, L=TURN_T):
    fe = L + 1
    P = Rig.P0()
    yaw, lift, body_yaw = turn_state(f)
    P['ryaw'] = body_yaw
    P['syaw'] = 5.0 * bump(f, 4, 76)
    P['neck_yaw'] = 24 * bump(f, 2, 60)
    P['head_y'] = 6 * bump(f, 2, 60)
    P['rz'] = -0.006 * bump(f, 4, 76)
    P['tail_z'] = [-2.5 * bump(f - 0.9 * i, 4, 80) for i in range(12)]
    return P, {'paws': {k: (yaw[k], lift[k]) for k in yaw}}


RUN_T, RUN_DUTY, RUN_STRIDE = 24, 0.5, 0.18
RUN_PHASE = {'HL': 0.0, 'HR': 0.12, 'FL': 0.55, 'FR': 0.67}
RUN_LIFT = {'HL': 0.05, 'HR': 0.05, 'FL': 0.04, 'FR': 0.04}
RUN_SPEED = RUN_STRIDE / (RUN_DUTY * RUN_T / FPS)


def run_foot(k, f):
    u = ((f - 1) / RUN_T - RUN_PHASE[k]) % 1.0
    if u < RUN_DUTY:
        return RUN_STRIDE / 2 - RUN_STRIDE * (u / RUN_DUTY), 0.0, True
    w = (u - RUN_DUTY) / (1 - RUN_DUTY)
    return -RUN_STRIDE / 2 + RUN_STRIDE * smooth(w), RUN_LIFT[k] * math.sin(math.pi * w), False


def run_params(f, L=RUN_T):
    P = Rig.P0()
    ph = 2 * math.pi * (f - 1) / RUN_T
    P['rz'] = -0.02 + 0.012 * math.sin(ph + 0.4)
    P['rpitch'] = 2.5 * math.sin(ph + 1.2)
    P['s1'] = 3 * math.sin(ph + 1.2)
    P['s0'] = -2 * math.sin(ph + 1.2)
    P['neck_low'] = -0.25 + 0.25 * math.sin(ph - 0.4)
    P['neck_high'] = 0.5 - 0.2 * math.sin(ph - 0.4)
    P['head_p'] = -4 * math.sin(ph + 1.2)
    P['jaw'] = 6
    P['wup'] = -6 + 5 * math.sin(ph + 0.8)
    P['wfwd'] = -24
    P['fore'] = -6
    P['tail_y'] = [-0.5 + 1.2 * math.sin(ph - 0.5 * i) for i in range(12)]
    P['tail_z'] = [1.5 * math.sin(ph * 0.5 - 0.3 * i) * 0 for i in range(12)]
    paws = {}
    for k in ('HL', 'HR', 'FL', 'FR'):
        dx, dz, planted = run_foot(k, f)
        paws[k] = (dx, dz, planted)
    return P, {'run': paws}


SPECS = {
    'Roar': (96, roar_params), 'Hit_Flinch': (36, flinch_params), 'Stagger_WeakpointBreak': (144, stagger_params),
    'Turn_Left90': (TURN_T, turn_params), 'Charge_Run': (RUN_T, run_params), 'Death': (144, death_params),
}
LOOPS = {'Charge_Run'}
ENDS_ON_IDLE = {'Roar', 'Hit_Flinch', 'Stagger_WeakpointBreak'}
EVENTS = {
    'Roar': {'markers': {'inhale': 14, 'roar_start': 30, 'roar_end': 62, 'settled': 97}, 'interrupt_windows': [{'from': 1, 'to': 29, 'state': 'cancelable'}, {'from': 30, 'to': 62, 'state': 'committed (aggro roar, no hit)'}, {'from': 63, 'to': 97, 'state': 'free'}]},
    'Hit_Flinch': {'markers': {'impact': 3, 'peak': 10, 'recovered': 37}, 'interrupt_windows': [{'from': 1, 'to': 37, 'state': 'hit reaction, plays over any cancelable window'}]},
    'Stagger_WeakpointBreak': {'markers': {'hit': 1, 'buckle': 26, 'exposed_start': 26, 'exposed_end': 110, 'recovering': 128, 'recovered': 145},
                               'interrupt_windows': [{'from': 1, 'to': 25, 'state': 'committed (falling)'}, {'from': 26, 'to': 110, 'state': 'vulnerable (stunned, head low)'}, {'from': 111, 'to': 145, 'state': 'free'}]},
    'Turn_Left90': {'markers': {'first_step': 4, 'last_step_down': 76, 'done': 85}, 'interrupt_windows': [{'from': 1, 'to': 85, 'state': 'locomotion, cancelable'}],
                    'note': 'in place, body ends at +90 degrees yaw; mirror the yaw signs for a right turn'},
    'Charge_Run': {'markers': {'HL_down': 1, 'FL_down': 14}, 'interrupt_windows': [{'from': 1, 'to': 25, 'state': 'locomotion loop'}],
                   'note': f'in place, ground speed {RUN_SPEED:.3f} units per second ({RUN_SPEED * 35:.1f} studs per second at the 25-stud scale)'},
    'Death': {'markers': {'hit': 1, 'rear': 14, 'collapse': 40, 'down': 70, 'still': 145}, 'interrupt_windows': [{'from': 1, 'to': 145, 'state': 'terminal, holds the last frame'}]},
}

names = [n for n in SPECS if ONLY is None or n in ONLY]
acts = {}
for n in names:
    L, fn = SPECS[n]
    if n in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[n])
    a = bpy.data.actions.new(n)
    a.use_fake_user = True
    arm.animation_data.action = a
    for f in range(1, L + 2):
        ff = f
        if n in LOOPS and f == L + 1:
            ff = 1
        P, extra = fn(ff, L)
        R.apply(P)
        if 'paws' in extra:
            for k, (yaw, lift) in extra['paws'].items():
                place_paw(k, yaw=yaw, dz=lift)
        if 'run' in extra:
            for k, (dx, dz, planted) in extra['run'].items():
                place_paw(k, dx=dx, dz=dz)
        if 'slide' in extra:
            for k, (dx, dz, dy) in extra['slide'].items():
                place_paw(k, dx=dx, dz=dz, dy=dy)
        R.key(f)
    acts[n] = a
    for label, fr in EVENTS[n]['markers'].items():
        a.pose_markers.new(label).frame = fr
R.reset()

# ------------------------------------------------------------------ measure
rest_mesh = np.array([v.co[:] for v in me.vertices])
edges = np.array([[e.vertices[0], e.vertices[1]] for e in me.edges])
rest_len = np.maximum(np.linalg.norm(rest_mesh[edges[:, 0]] - rest_mesh[edges[:, 1]], axis=1), 1e-6)
gname = {i: g.name for i, g in enumerate(body.vertex_groups)}
W = np.zeros((N, len(gname)))
for v in me.vertices:
    for g in v.groups:
        W[v.index, g.group] = g.weight
dom = np.array([gname[i] for i in W.argmax(1)])
foot_groups = ['HindLeg_L_Foot', 'HindLeg_R_Foot', 'tripo::0_Left_Limb_2', 'tripo::0_Left_Limb_3', 'tripo::0_Left_Limb_4', 'tripo::0_Right_Limb_1', 'tripo::0_Right_Limb_2', 'tripo::0_Right_Limb_3']
foot_all = np.isin(dom, foot_groups)
track = {'head tip': int(np.argmax(rest_mesh[:, 0])), 'tail tip': int(np.argmin(rest_mesh[:, 0])), 'left wing tip': int(np.argmax(rest_mesh[:, 1])),
         'right wing tip': int(np.argmin(rest_mesh[:, 1])), 'chest': int(np.argmin(np.linalg.norm(rest_mesh - np.array([0.30, 0.0, 0.30]), axis=1)))}
eff = {'HL': 'HindLeg_L_Ankle', 'HR': 'HindLeg_R_Ankle', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
knee = {'HL': 'HindLeg_L_Knee', 'HR': 'HindLeg_R_Knee', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
limb_root = {'HL': 'HindLeg_L_Hip', 'HR': 'HindLeg_R_Hip', 'FL': 'bone_26', 'FR': 'bone_42'}


def mesh_now():
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    m = ev.to_mesh()
    V = np.array([v.co[:] for v in m.vertices])
    ev.to_mesh_clear()
    return V


arm.animation_data.action = bpy.data.actions['Idle']
scn.frame_set(1); R.update()
V0 = mesh_now()
idle0 = {k: V0[i] for k, i in track.items()}
report = {}
for n in names:
    L, fn = SPECS[n]
    arm.animation_data.action = acts[n]
    stats, zmin, tgt, anl, kx, trk, planted_flags = [], [], {k: [] for k in eff}, {k: [] for k in eff}, {k: [] for k in eff}, {k: [] for k in track}, {k: [] for k in eff}
    worst_edge = {}
    for f in range(1, L + 2):
        scn.frame_set(f); R.update()
        V = mesh_now()
        ratio = np.linalg.norm(V[edges[:, 0]] - V[edges[:, 1]], axis=1) / rest_len
        bad = (ratio > 1.5) | (ratio < 0.5)
        stats.append((float(ratio.max()), int(bad.sum())))
        zmin.append((float(V[foot_all, 2].min()), float(V[~foot_all, 2].min())))
        em = int(np.argmax(ratio))
        if ratio[em] > worst_edge.get('ratio', 0):
            worst_edge = {'ratio': round(float(ratio[em]), 2), 'frame': f, 'at': ((rest_mesh[edges[em, 0]] + rest_mesh[edges[em, 1]]) / 2).round(3).tolist(), 'bones': [str(dom[edges[em, 0]]), str(dom[edges[em, 1]])]}
        P, extra = fn(1 if (n in LOOPS and f == L + 1) else f, L)
        for k in eff:
            tgt[k].append(np.array(pb[f'IK_Paw_{k}'].head)); anl[k].append(np.array(pb[eff[k]].tail))
            kn = np.array(pb[knee[k]].head); rt = np.array(pb[limb_root[k]].head); b = np.array(pb[eff[k]].tail)
            kx[k].append(float(kn[0] - (rt[0] + (kn[2] - rt[2]) / (b[2] - rt[2]) * (b[0] - rt[0]))))
            if 'paws' in extra:
                planted_flags[k].append(extra['paws'][k][1] == 0.0)
            elif 'run' in extra:
                planted_flags[k].append(extra['run'][k][2])
            elif 'slide' in extra:
                planted_flags[k].append(extra['slide'][k] == (0.0, 0.0, 0.0))
            else:
                planted_flags[k].append(True)
        for k, i in track.items():
            trk[k].append(V[i])
    paws = {}
    for k in eff:
        T_ = np.array(tgt[k]); A_ = np.array(anl[k]); pl = np.array(planted_flags[k])
        # slide: movement of the target during planted stretches (run: in the ground frame)
        if n == 'Charge_Run':
            gx = np.array([RUN_SPEED * (i) / FPS for i in range(len(T_))])
            T2 = T_.copy(); T2[:, 0] += gx
        else:
            T2 = T_
        runs, cur = [], []
        for i, p_ in enumerate(pl):
            if p_:
                cur.append(i)
            elif cur:
                runs.append(cur); cur = []
        if cur:
            runs.append(cur)
        slide = max([float(np.ptp(T2[r], axis=0).max()) for r in runs if len(r) > 1] or [0.0])
        err = max(float(np.linalg.norm(T_[i] - A_[i])) for i in range(len(T_)))
        paws[k] = {'planted_frames': int(pl.sum()), 'slide_while_planted': round(slide, 5), 'ik_error_max': round(err, 4), 'knee_x': [round(min(kx[k]), 3), round(max(kx[k]), 3)],
                   'back_at_rest_at_end': bool(np.linalg.norm(T_[-1] - T_[0]) < 1e-6)}
    seam_start = max(float(np.linalg.norm(trk[k][0] - idle0[k])) for k in track)
    seam_end = max(float(np.linalg.norm(trk[k][-1] - idle0[k])) for k in track)
    loop = max(float(np.linalg.norm(trk[k][-1] - trk[k][0])) for k in track)
    report[n] = {'frames': L, 'seconds': round(L / FPS, 2), 'start_vs_idle': round(seam_start, 5), 'end_vs_idle': round(seam_end, 5), 'end_vs_start': round(loop, 5),
                 'max_stretch': round(max(s[0] for s in stats), 2), 'worst_bad_edges': max(s[1] for s in stats), 'max_edge': worst_edge,
                 'min_z': {'foot': round(min(z[0] for z in zmin), 4), 'body': round(min(z[1] for z in zmin), 4)}, 'paws': paws,
                 'motion_range': {k: [round(float(x), 3) for x in np.ptp(np.array(trk[k]), axis=0)] for k in track}, 'events': EVENTS[n]}
scn.frame_set(1)
json.dump(report, open(SC + 'moves2_report.json', 'w'))
ev_path = OUT + '/vyrath_signature_events.json'
allev = json.load(open(ev_path)) if os.path.exists(ev_path) else {}
allev.update({n: EVENTS[n] for n in names})
json.dump(allev, open(ev_path, 'w'), indent=1)
print('MEASURED', names)

if ONLY is None:
    order = ['Idle', 'Roar', 'Idle', 'Hit_Flinch', 'Idle', 'Stagger_WeakpointBreak', 'Idle', 'Turn_Left90', 'Charge_Run', 'Charge_Run', 'Charge_Run', 'Charge_Run', 'Death']
    lens = {'Idle': 96, **{n: SPECS[n][0] for n in SPECS}}
    arm.animation_data.action = None
    for t in list(arm.animation_data.nla_tracks):
        if t.name == 'Moves2':
            arm.animation_data.nla_tracks.remove(t)
    trk_ = arm.animation_data.nla_tracks.new(); trk_.name = 'Moves2'
    start = 1
    for i, n in enumerate(order):
        st = trk_.strips.new(f'{i + 1:02d} {n}', start, bpy.data.actions[n])
        st.action_frame_start, st.action_frame_end = 1, lens[n] + 1
        st.frame_end = start + lens[n]
        st.extrapolation = 'NOTHING' if n != 'Death' else 'HOLD_FORWARD'
        start += lens[n]
    for t in arm.animation_data.nla_tracks:
        t.mute = (t.name != 'Moves2')
    scn.frame_start, scn.frame_end = 1, start + 24
    scn.frame_set(1)
    print('moves2 strip frames', start + 24, 'seconds', round((start + 24) / FPS, 1))

if DO_RENDER and ONLY is None:
    IMG = SC + 'vyrath_moves2_img'
    os.makedirs(IMG, exist_ok=True)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not body:
            o.hide_render = True; o.hide_viewport = True
    scn.render.engine = 'BLENDER_WORKBENCH'
    scn.render.resolution_x, scn.render.resolution_y = 520, 300
    scn.display.shading.light = 'STUDIO'; scn.display.shading.color_type = 'TEXTURE'; scn.display.shading.background_type = 'WORLD'
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.color = (0.93, 0.93, 0.93)
    cam = next((o for o in bpy.data.objects if o.type == 'CAMERA'), None)
    if cam is None:
        cam = bpy.data.objects.new("MCam", bpy.data.cameras.new("MCam")); scn.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; scn.camera = cam
    VIEW = {'side': ((0.0, -3.0, 0.36), (90, 0, 0), 1.4), 'top': ((0.0, 0.0, 3.0), (0, 0, 0), 1.4), 'front': ((3.0, 0.0, 0.36), (90, 0, 90), 1.4)}
    SHOTS = [('Roar', 14, 'side'), ('Roar', 46, 'side'), ('Roar', 46, 'front'), ('Hit_Flinch', 10, 'side'), ('Stagger_WeakpointBreak', 10, 'side'), ('Stagger_WeakpointBreak', 60, 'side'),
             ('Turn_Left90', 1, 'top'), ('Turn_Left90', 40, 'top'), ('Turn_Left90', 85, 'top'), ('Charge_Run', 4, 'side'), ('Charge_Run', 16, 'side'), ('Death', 14, 'side'), ('Death', 50, 'side'), ('Death', 140, 'side'), ('Death', 140, 'front')]
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    for nm, f, v in SHOTS:
        arm.animation_data.action = acts[nm]
        scn.frame_set(f)
        loc, eul, sc = VIEW[v]
        cam.location = loc; cam.rotation_euler = tuple(math.radians(a) for a in eul); cam.data.ortho_scale = sc
        scn.render.filepath = f"{IMG}/{nm}_{f:03d}_{v}.png"
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = None
    for t in arm.animation_data.nla_tracks:
        t.mute = (t.name != 'Moves2')
    scn.frame_set(1)

if SAVE and ONLY is None:
    bpy.ops.wm.save_as_mainfile(filepath=OUT + "/vyrath_motion_v4.blend")

if DO_EXPORT and ONLY is None:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    keep = list(SPECS)
    for a in list(bpy.data.actions):
        if a.name not in keep:
            bpy.data.actions.remove(a)
    for n in keep:
        src = bpy.data.actions[n]
        arm.animation_data.action = src
        mode('POSE')
        with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl, selected_objects=[arm]):
            bpy.ops.pose.select_all(action='SELECT')
            bpy.ops.nla.bake(frame_start=1, frame_end=SPECS[n][0] + 1, only_selected=False, visual_keying=True, clear_constraints=False, clear_parents=False, use_current_action=False, bake_types={'POSE'})
        mode('OBJECT')
        b = arm.animation_data.action
        src.name = n + '_src'; b.name = n
    for n in keep:
        bpy.data.actions.remove(bpy.data.actions[n + '_src'])
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], view_layer=vl, active_object=arm, object=arm, selected_objects=[arm, body], selected_editable_objects=[arm, body]):
        for o in bpy.data.objects:
            o.select_set(o in (arm, body))
        bpy.ops.export_scene.gltf(filepath=OUT + "/vyrath_moves2_v4.glb", export_format='GLB', use_selection=True, export_skins=True, export_animations=True, export_force_sampling=True, export_apply=False)
    print('exported', os.path.getsize(OUT + "/vyrath_moves2_v4.glb"))
