import bpy, math, json, os, time
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


def mode(m):
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl):
        bpy.ops.object.mode_set(mode=m)


for t in arm.animation_data.nla_tracks:
    t.mute = True
arm.animation_data.action = None


# ------------------------------------------------------------------ the two grounded actions
def breath_params(f, L=168):
    fend = L + 1
    P = Rig.P0()
    pant = bump(f, 108, 148) * 1.5 * math.sin(2 * math.pi * (f - 108) / 12.0)
    P['rz'] = curve(f, [(1, 0), (14, -0.012), (56, -0.016), (62, -0.024), (100, -0.016), (124, -0.020), (148, -0.012), (fend, 0)])
    P['rx'] = curve(f, [(1, 0), (56, 0), (62, -0.010), (100, -0.004), (118, 0), (fend, 0)])
    P['s1'] = curve(f, [(1, 0), (14, 1.5), (54, -5), (62, 3.5), (100, 3.0), (124, 4.0), (148, 2.0), (fend, 0)]) + pant
    P['s0'] = curve(f, [(1, 0), (54, -2), (62, 1.5), (124, 2.0), (fend, 0)])
    P['neck_low'] = curve(f, [(1, 0), (14, 0), (54, -0.7), (60, 0.5), (100, 0.5), (124, 0.45), (148, 0.35), (fend, 0)])
    P['neck_high'] = curve(f, [(1, 0), (14, 0), (54, 0.5), (60, 0.35), (100, 0.4), (124, 0.75), (148, 0.6), (fend, 0)])
    P['head_p'] = curve(f, [(1, 0), (14, 0), (54, -5), (60, 6), (100, 6), (124, 12), (148, 9), (fend, 0)])
    P['neck_yaw'] = curve(f, [(1, 0), (50, 0), (58, 26), (98, -26), (118, 0), (fend, 0)])
    P['head_y'] = 0.2 * P['neck_yaw']
    P['jaw'] = curve(f, [(1, 0), (14, 0), (40, 5), (56, 5), (64, 28), (98, 28), (112, 8), (130, 4), (fend, 0)])
    P['throat'] = curve(f, [(1, 0), (20, 0), (54, 0.14), (62, 0.10), (98, 0.02), (118, 0), (fend, 0)])
    P['wup'] = curve(f, [(1, 0), (14, 0), (54, 8), (62, 14), (100, 10), (130, 3), (fend, 0)])
    P['wfwd'] = curve(f, [(1, 0), (54, 4), (62, 6), (120, 2), (fend, 0)])
    P['fan'] = curve(f, [(1, 0), (54, 0.4), (62, 0.6), (130, 0.1), (fend, 0)])
    P['tail_y'] = [curve(f - 0.5 * i, [(1, 0), (14, 0), (54, 2.0), (62, 3.0), (100, 2.0), (130, 0), (fend, 0)]) for i in range(12)]
    P['tail_z'] = [curve(f - 0.9 * i, [(1, 0), (56, 0), (64, 4), (80, -3), (100, 2), (120, 0), (fend, 0)]) for i in range(12)]
    P['rz'] *= 0.4          # a deep sink drags the front legs and shoulder; this keeps them calm
    P['throat'] *= 0.6
    P['jaw'] *= 0.85
    return P


def tail_sweep_params(f, L=108):
    fend = L + 1
    P = Rig.P0()
    P['neck_yaw'] = curve(f, [(1, 0), (18, 24), (70, 24), (94, 0), (fend, 0)])
    P['head_y'] = curve(f, [(1, 0), (18, 8), (70, 8), (94, 0), (fend, 0)])
    P['pel_yaw'] = curve(f, [(1, 0), (18, 2), (36, -7), (44, -7), (56, 10), (68, 10), (80, -2), (94, 0), (fend, 0)])
    P['syaw'] = curve(f, [(1, 0), (18, 3), (36, -3), (44, -3), (56, 5), (68, 5), (80, 0), (fend, 0)])
    P['rz'] = curve(f, [(1, 0), (18, 0), (36, -0.012), (44, -0.016), (58, -0.012), (80, -0.004), (94, 0), (fend, 0)])
    P['wup'] = curve(f, [(1, 0), (44, 0), (56, 6), (80, 1), (fend, 0)])
    P['tail_z'] = [curve(f - 0.9 * i, [(1, 0), (18, 0), (36, -5), (44, -5), (58, 9), (68, 9), (78, -2.5), (92, 0), (fend, 0)]) for i in range(12)]
    P['tail_y'] = [curve(f - 0.5 * i, [(1, 0), (36, 2.5), (58, 1.0), (80, 0.5), (92, 0), (fend, 0)]) for i in range(12)]
    return P


SPECS = {
    'Sig_ThunderBreath': (168, breath_params),
    'Sig_TailSweep': (108, tail_sweep_params),
    'Sig_Takeoff': (108, takeoff_params),
    'Sig_Landing': (120, landing_params),
    'Flight_Hover': (48, lambda f, L=48: hover_params(2 * math.pi * (((f - 1) % 48)) / 48.0)),
}
EVENTS = {
    'Sig_ThunderBreath': {'markers': {'plant': 14, 'cone_warning_start': 26, 'inhale_peak': 54, 'breath_start': 56, 'sweep_left_peak': 58, 'sweep_right_end': 98,
                                      'exhale': 100, 'exposed_window_start': 108, 'exposed_window_end': 148, 'recovered': 169},
                          'interrupt_windows': [{'from': 1, 'to': 55, 'state': 'cancelable (charging)'}, {'from': 56, 'to': 99, 'state': 'committed'},
                                                {'from': 100, 'to': 148, 'state': 'vulnerable (throat exposed)'}, {'from': 149, 'to': 169, 'state': 'free'}],
                          'warning_frames': [26, 56], 'cone': {'half_angle_deg': 12, 'range': 0.85, 'active_frames': [56, 100]}},
    'Sig_TailSweep': {'markers': {'flank_check': 18, 'coil': 36, 'plant': 44, 'contact_start': 50, 'contact_end': 60, 'recoil_peak': 78, 'recovered': 109},
                      'interrupt_windows': [{'from': 1, 'to': 40, 'state': 'cancelable (checking and coiling)'}, {'from': 41, 'to': 70, 'state': 'committed'},
                                            {'from': 71, 'to': 94, 'state': 'vulnerable (recoil)'}, {'from': 95, 'to': 109, 'state': 'free'}],
                      'hit_frames': [50, 60]},
    'Sig_Takeoff': {'markers': {'load_peak': 22, 'wings_unfolded': 34, 'front_paws_leave_ground': 32, 'hind_paws_leave_ground': 38, 'first_downstroke_end': 58,
                                'second_downstroke_start': 80, 'bank_peak': 96, 'level_in_hover': 109},
                    'interrupt_windows': [{'from': 1, 'to': 30, 'state': 'cancelable (loading)'}, {'from': 31, 'to': 109, 'state': 'committed (airborne)'}]},
    'Sig_Landing': {'markers': {'flare': 30, 'forefeet_contact': 62, 'hindfeet_contact': 70, 'compress_peak': 80, 'settled': 121},
                    'interrupt_windows': [{'from': 1, 'to': 61, 'state': 'committed (airborne)'}, {'from': 62, 'to': 96, 'state': 'vulnerable (grounded, compressing)'},
                                          {'from': 97, 'to': 121, 'state': 'free'}]},
    'Flight_Hover': {'markers': {'wings_top': 1, 'downstroke_end': 25}, 'interrupt_windows': [{'from': 1, 'to': 49, 'state': 'airborne loop'}]},
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
        R.apply(fn(f if n != 'Flight_Hover' or f <= L else 1, L))
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
foot_groups = ['HindLeg_L_Foot', 'HindLeg_R_Foot', 'tripo::0_Left_Limb_2', 'tripo::0_Left_Limb_3', 'tripo::0_Left_Limb_4',
               'tripo::0_Right_Limb_1', 'tripo::0_Right_Limb_2', 'tripo::0_Right_Limb_3']
foot_all = np.isin(dom, foot_groups)
tail_all = np.array([d.startswith('Tail_') for d in dom])
sh_c = {'L': np.array([0.28, 0.06, 0.33]), 'R': np.array([0.28, -0.06, 0.33])}
d_sh = np.minimum(np.linalg.norm(rest_mesh - sh_c['L'], axis=1), np.linalg.norm(rest_mesh - sh_c['R'], axis=1))
wing_far = np.where(np.array([d.startswith('Wing_') for d in dom]) & (d_sh > 0.12))[0]
fore_set = np.where(np.isin(dom, ['bone_26', 'bone_42', 'bone_43']) | np.array([d.startswith('tripo::0_') for d in dom]))[0]
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


def min_wing_fore(V):
    A, B = V[wing_far], V[fore_set]
    best = 9.0
    for i in range(0, len(A), 400):
        d = np.linalg.norm(A[i:i + 400, None, :] - B[None, :, :], axis=2)
        best = min(best, float(d.min()))
    return best


# the pose at idle frame 1, for seams and the baseline wing-to-foreleg gap
arm.animation_data.action = bpy.data.actions['Idle'] if 'Idle' in bpy.data.actions else None
scn.frame_set(1); R.update()
V0 = mesh_now()
idle0 = ({k: V0[i] for k, i in track.items()}, {k: np.array(pb[b].tail) for k, b in eff.items()})
base_gap = min_wing_fore(V0)
report = {'baseline_wing_to_foreleg_gap': round(base_gap, 4)}
hit = {}
ends = {}
for n in names:
    L, fn = SPECS[n]
    arm.animation_data.action = acts[n]
    stats, zmin, gaps, tgt, anl, kx, trk = [], [], [], {k: [] for k in eff}, {k: [] for k in eff}, {k: [] for k in eff}, {k: [] for k in track}
    wts = []
    worst_edge = {}
    for f in range(1, L + 2):
        scn.frame_set(f); R.update()
        V = mesh_now()
        ratio = np.linalg.norm(V[edges[:, 0]] - V[edges[:, 1]], axis=1) / rest_len
        bad = (ratio > 1.5) | (ratio < 0.5)
        stats.append((float(ratio.max()), int(bad.sum())))
        zmin.append((float(V[foot_all, 2].min()), float(V[tail_all, 2].min()), float(V[:, 2].min())))
        if f % 2 == 1:
            gaps.append(min_wing_fore(V))
        em = int(np.argmax(ratio))
        if ratio[em] > worst_edge.get('ratio', 0):
            worst_edge = {'ratio': round(float(ratio[em]), 2), 'len0': round(float(rest_len[em]), 4), 'len1': round(float(ratio[em] * rest_len[em]), 4), 'frame': f, 'at': ((rest_mesh[edges[em, 0]] + rest_mesh[edges[em, 1]]) / 2).round(3).tolist(),
                          'bones': [str(dom[edges[em, 0]]), str(dom[edges[em, 1]])]}
        Pf = fn(f if n != 'Flight_Hover' or f <= L else 1, L)
        wts.append((Pf['pf'], Pf['ph']))
        for k in eff:
            tgt[k].append(np.array(pb[f'IK_Paw_{k}'].head))
            anl[k].append(np.array(pb[eff[k]].tail))
            kn = np.array(pb[knee[k]].head); rt = np.array(pb[limb_root[k]].head); b = np.array(pb[eff[k]].tail)
            kx[k].append(float(kn[0] - (rt[0] + (kn[2] - rt[2]) / (b[2] - rt[2]) * (b[0] - rt[0]))))
        for k, i in track.items():
            trk[k].append(V[i])
        if n == 'Sig_ThunderBreath' and 56 <= f <= 100:
            hit.setdefault(n, {})[f] = {'origin': [round(float(x), 4) for x in pb['Socket_Breath'].head], 'direction': [round(float(x), 4) for x in (np.array(pb['Socket_Breath'].tail) - np.array(pb['Socket_Breath'].head)) / 0.045]}
        if n == 'Sig_TailSweep' and 44 <= f <= 68:
            hit.setdefault(n, {})[f] = {t: {'from': [round(float(x), 4) for x in pb[t].head], 'to': [round(float(x), 4) for x in pb[t].tail], 'radius': round(0.05 - 0.003 * (int(t[-2:]) - 4), 3)}
                                        for t in R.tail[3:]}
    ends[n] = ({k: trk[k][0] for k in track}, {k: trk[k][-1] for k in track})
    first_idle = ({k: trk[k][0] for k in track}, {k: anl[k][0] for k in eff})
    paws = {}
    for k in eff:
        T_ = np.array(tgt[k]); A_ = np.array(anl[k])
        wk = np.array([w[0] if k[0] == 'F' else w[1] for w in wts])
        planted = wk <= 1e-9
        runs, cur = [], []
        for i, pl in enumerate(planted):
            if pl:
                cur.append(i)
            elif cur:
                runs.append(cur); cur = []
        if cur:
            runs.append(cur)
        slide = max([float(np.ptp(T_[r], axis=0).max()) for r in runs if len(r) > 1] or [0.0])
        slide_a = max([float(np.ptp(A_[r], axis=0).max()) for r in runs if len(r) > 1] or [0.0])
        err = max(float(np.linalg.norm(T_[i] - A_[i])) for i in range(len(T_)))
        paws[k] = {'planted_frames': int(planted.sum()), 'slide_target': round(slide, 6), 'slide_ankle': round(slide_a, 6),
                   'ik_error_max': round(err, 4), 'ik_error_at_planted_max': round(max([float(np.linalg.norm(T_[i] - A_[i])) for i in range(len(T_)) if planted[i]] or [0.0]), 6),
                   'knee_x': [round(min(kx[k]), 3), round(max(kx[k]), 3)]}
    seam_start = max(max(float(np.linalg.norm(first_idle[0][k] - idle0[0][k])) for k in track), max(float(np.linalg.norm(first_idle[1][k] - idle0[1][k])) for k in eff))
    seam_end = max(float(np.linalg.norm(trk[k][-1] - idle0[0][k])) for k in track)
    report[n] = {'frames': L, 'seconds': round(L / FPS, 2), 'start_vs_idle': round(seam_start, 6), 'end_vs_idle': round(seam_end, 5),
                 'end_vs_start': round(max(float(np.linalg.norm(trk[k][-1] - trk[k][0])) for k in track), 6),
                 'max_stretch': round(max(s[0] for s in stats), 2), 'worst_bad_edges': max(s[1] for s in stats), 'max_edge': worst_edge,
                 'min_z': {'foot': round(min(z[0] for z in zmin), 4), 'tail': round(min(z[1] for z in zmin), 4), 'any': round(min(z[2] for z in zmin), 4)},
                 'wing_to_foreleg_min_gap': round(min(gaps), 4), 'paws': paws,
                 'motion_range': {k: [round(float(x), 3) for x in np.ptp(np.array(trk[k]), axis=0)] for k in track}, 'events': EVENTS[n]}
if all(n in ends for n in ('Sig_Takeoff', 'Flight_Hover', 'Sig_Landing')):
    def dd(a, b):
        return round(max(float(np.linalg.norm(a[k] - b[k])) for k in track), 6)
    report['chain'] = {'takeoff_end_vs_hover_start': dd(ends['Sig_Takeoff'][1], ends['Flight_Hover'][0]), 'landing_start_vs_hover_start': dd(ends['Sig_Landing'][0], ends['Flight_Hover'][0]),
                       'hover_loop_seam': dd(ends['Flight_Hover'][1], ends['Flight_Hover'][0]), 'landing_end_vs_idle': report['Sig_Landing']['end_vs_idle']}
scn.frame_set(1)
json.dump(report, open(SC + 'sig_report.json', 'w'))
json.dump(hit, open(OUT + '/vyrath_signature_hit_data.json', 'w'))
json.dump({n: EVENTS[n] for n in names}, open(OUT + '/vyrath_signature_events.json', 'w'), indent=1)
print('MEASURED', names)

# ------------------------------------------------------------------ showcase strip
if ONLY is None:
    order = ['Idle', 'Sig_ThunderBreath', 'Idle', 'Sig_TailSweep', 'Idle', 'Sig_Takeoff', 'Flight_Hover', 'Flight_Hover', 'Sig_Landing', 'Idle']
    lens = {'Idle': 96, **{n: SPECS[n][0] for n in SPECS}}
    arm.animation_data.action = None
    for t in list(arm.animation_data.nla_tracks):
        if t.name == 'Signature':
            arm.animation_data.nla_tracks.remove(t)
    trk_ = arm.animation_data.nla_tracks.new()
    trk_.name = 'Signature'
    start = 1
    for i, n in enumerate(order):
        st = trk_.strips.new(f'{i + 1:02d} {n}', start, bpy.data.actions[n])
        st.action_frame_start, st.action_frame_end = 1, lens[n] + 1
        st.frame_end = start + lens[n]
        st.extrapolation = 'NOTHING'
        start += lens[n]
    for t in arm.animation_data.nla_tracks:
        t.mute = (t.name != 'Signature')
    scn.frame_start, scn.frame_end = 1, start - 1
    scn.frame_set(1)
    print('signature strip frames', start - 1, 'seconds', round((start - 1) / FPS, 1))

# ------------------------------------------------------------------ renders
if DO_RENDER and ONLY is None:
    IMG = SC + 'vyrath_sig_img'
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
        cam = bpy.data.objects.new("SigCam", bpy.data.cameras.new("SigCam")); scn.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    scn.camera = cam
    VIEW = {'side': ((0.0, -3.0, 0.36), (90, 0, 0), 1.4), 'top': ((0.0, 0.0, 3.0), (0, 0, 0), 1.4), 'sidehi': ((0.0, -3.0, 0.5), (90, 0, 0), 1.8)}
    SHOTS = [('Sig_ThunderBreath', 1, 'side'), ('Sig_ThunderBreath', 26, 'side'), ('Sig_ThunderBreath', 54, 'side'), ('Sig_ThunderBreath', 70, 'top'), ('Sig_ThunderBreath', 98, 'top'), ('Sig_ThunderBreath', 128, 'side'),
             ('Sig_TailSweep', 1, 'top'), ('Sig_TailSweep', 18, 'top'), ('Sig_TailSweep', 40, 'top'), ('Sig_TailSweep', 52, 'top'), ('Sig_TailSweep', 60, 'top'), ('Sig_TailSweep', 78, 'top'),
             ('Sig_Takeoff', 1, 'sidehi'), ('Sig_Takeoff', 22, 'sidehi'), ('Sig_Takeoff', 36, 'sidehi'), ('Sig_Takeoff', 46, 'sidehi'), ('Sig_Takeoff', 70, 'sidehi'), ('Sig_Takeoff', 96, 'sidehi'),
             ('Sig_Landing', 1, 'sidehi'), ('Sig_Landing', 30, 'sidehi'), ('Sig_Landing', 56, 'sidehi'), ('Sig_Landing', 66, 'sidehi'), ('Sig_Landing', 80, 'sidehi'), ('Sig_Landing', 106, 'sidehi')]
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
        t.mute = (t.name != 'Signature')
    scn.frame_set(1)

if SAVE and ONLY is None:
    bpy.ops.wm.save_as_mainfile(filepath=OUT + "/vyrath_motion_v4.blend")

# ------------------------------------------------------------------ bake and export
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
            bpy.ops.nla.bake(frame_start=1, frame_end=SPECS[n][0] + 1, only_selected=False, visual_keying=True, clear_constraints=False,
                             clear_parents=False, use_current_action=False, bake_types={'POSE'})
        mode('OBJECT')
        b = arm.animation_data.action
        src.name = n + '_src'
        b.name = n
    for n in keep:
        bpy.data.actions.remove(bpy.data.actions[n + '_src'])
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], view_layer=vl, active_object=arm, object=arm,
                                   selected_objects=[arm, body], selected_editable_objects=[arm, body]):
        for o in bpy.data.objects:
            o.select_set(o in (arm, body))
        bpy.ops.export_scene.gltf(filepath=OUT + "/vyrath_signature_actions_v4.glb", export_format='GLB', use_selection=True, export_skins=True,
                                  export_animations=True, export_force_sampling=True, export_apply=False)
    print('exported', os.path.getsize(OUT + "/vyrath_signature_actions_v4.glb"))
