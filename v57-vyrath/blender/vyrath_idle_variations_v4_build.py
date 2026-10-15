import bpy, math, json, os
import numpy as np
from mathutils import Matrix, Vector

SRC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_motion_v4.blend"
OUT = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
SC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/idle_var_work/"
FPS = 24
BREATH = 96                        # one breath per 96 frames, every clip is a whole number of breaths so it joins the idle at its start pose
DROP = 0.015
TAIL_LIFT = 1.5
DO_RENDER = globals().get('DO_RENDER', True)
SAVE = globals().get('SAVE', True)
DO_EXPORT = globals().get('DO_EXPORT', True)

bpy.ops.wm.open_mainfile(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
me = body.data
N = len(me.vertices)
vl = bpy.data.scenes[0].view_layers[0]
scn = bpy.context.scene
scn.render.fps = FPS
pb = arm.pose.bones
neck = [f'Neck_{i + 1:02d}' for i in range(8)]
tail = [f'Tail_{i + 1:02d}' for i in range(12)]
ANIM = ['tripo::Root', 'Pelvis', 'tripo::Spine_0', 'tripo::Spine_1', 'Jaw', 'Head'] + \
       [f'Wing_{s}_{b}' for s in 'LR' for b in ('Shoulder', 'Arm', 'Forearm', 'D1_0', 'D2_0', 'D3_0', 'D4_0')] + neck + tail + \
       ['IK_Paw_HL', 'IK_Paw_HR', 'IK_Paw_FL', 'IK_Paw_FR']


def mode(m):
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl):
        bpy.ops.object.mode_set(mode=m)


def reset():
    for p in pb:
        p.location = (0, 0, 0)
        p.rotation_mode = 'QUATERNION'
        p.rotation_quaternion = (1, 0, 0, 0)
        p.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def rot(bone, axis, deg):
    p = pb[bone]
    m = p.matrix.copy()
    head = m.translation.copy()
    p.matrix = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head) @ m
    bpy.context.view_layer.update()


def shift(bone, delta):
    p = pb[bone]
    m = p.matrix.copy()
    m.translation += Vector(delta)
    p.matrix = m
    bpy.context.view_layer.update()


def ss(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


def bump(f, a, b):
    if f < a or f > b:
        return 0.0
    return math.sin(math.pi * (f - a) / (b - a)) ** 2


def curve(f, pts):
    """Smooth path through (frame, value) points."""
    if f <= pts[0][0]:
        return pts[0][1]
    for (f0, v0), (f1, v1) in zip(pts[:-1], pts[1:]):
        if f <= f1:
            return v0 + (v1 - v0) * ss((f - f0) / max(f1 - f0, 1e-9))
    return pts[-1][1]


def base(f, flick=False):
    """The standing idle: breathing, weight shift, head sway, tail wave. Identical to the Idle action."""
    ph = 2 * math.pi * (f - 1) / BREATH
    br = math.sin(ph)
    shift('tripo::Root', (0, 0, -DROP + 0.004 * br))
    rot('tripo::Spine_1', 'Y', -1.2 * br)
    rot('tripo::Spine_0', 'Y', -0.6 * br)
    rot('Pelvis', 'Z', 2.0 * math.sin(ph + 0.5))
    rot('Pelvis', 'X', 1.2 * math.sin(ph - 1.0))
    for b in neck:
        rot(b, 'Y', -0.25 * br + 0.3 * math.sin(ph - 0.8))
        rot(b, 'Z', (6.0 / 8) * math.sin(ph + 1.3) + (1.5 / 8) * math.sin(2 * ph))
    rot('Jaw', 'Y', 2.0 * (0.5 + 0.5 * math.sin(ph + 2.0)))
    fl = bump(f, 56, 78) if flick else 0.0
    for side, sg in (('L', 1), ('R', -1)):
        rot(f'Wing_{side}_Shoulder', 'X', sg * (1.2 * br + 5.0 * fl))
        rot(f'Wing_{side}_Shoulder', 'Z', sg * 6.0 * fl)
        rot(f'Wing_{side}_Forearm', 'Z', sg * 4.0 * fl)
    for i, b in enumerate(tail):
        rot(b, 'Z', 2.4 * math.sin(ph - 0.35 * (i + 1)))
        rot(b, 'Y', TAIL_LIFT + 0.6 * math.sin(2 * ph - 0.5 * (i + 1)))


# ---------------------------------------------------------------- variations: each adds to the idle and is zero at its first and last frame
EVENTS = {}


def look_around(f, L):
    Y = curve(f, [(1, 0), (30, 0), (58, 1), (78, 1), (122, -1), (146, -1), (176, 0), (L + 1, 0)])
    P = curve(f, [(1, 0), (110, 0), (126, 1), (146, 1), (176, 0), (L + 1, 0)])       # a slight look-down on the right
    wsum = sum(range(1, 9))
    for i, b in enumerate(neck):
        rot(b, 'Z', 30.0 * Y * (i + 1) / wsum)
        rot(b, 'Y', 0.5 * P)
    rot('Head', 'Z', 8.0 * Y)
    rot('tripo::Spine_1', 'Z', -3.0 * Y)
    rot('tripo::Spine_0', 'Z', -1.5 * Y)
    for i, b in enumerate(tail):
        rot(b, 'Z', -0.9 * Y * (1 + 0.1 * i))
    EVENTS['Idle_LookAround'] = {'turn_left_peak': 58, 'turn_right_peak': 122, 'back_to_centre': 176}


def paw_stomp(f, L):
    lift = curve(f, [(1, 0), (18, 0), (38, 1), (42, 1), (49, 0), (L + 1, 0)])
    fwd = curve(f, [(1, 0), (18, 0), (38, 1), (42, 1), (49, 0), (L + 1, 0)])
    shift('IK_Paw_FR', (0.012 * fwd, 0, globals().get('STOMP_LIFT', 0.035) * lift))
    imp = bump(f, 49, 70)
    shift('tripo::Root', (0, 0, -0.008 * imp))
    rot('tripo::Spine_1', 'Y', 2.0 * imp)
    for b in neck:
        rot(b, 'Y', 0.4 * imp)
    for i, b in enumerate(tail):
        rot(b, 'Y', 2.0 * imp * math.cos(0.6 * i))
    shift('tripo::Root', (0, 0.004 * ss((f - 14) / 8) * (1 - ss((f - 60) / 12)), 0))      # weight goes to the left while the right paw is up
    EVENTS['Idle_PawStomp'] = {'paw_lift_start': 18, 'paw_top': 38, 'impact': 49}


def paw_shift(f, L):
    S = curve(f, [(1, 0), (14, 0), (30, 1), (70, 1), (86, 0), (L + 1, 0)])
    lift = curve(f, [(1, 0), (34, 0), (46, 1), (52, 1), (62, 0), (L + 1, 0)])
    shift('tripo::Root', (0, 0.008 * S, 0))
    rot('Pelvis', 'X', 2.0 * S)
    rot('tripo::Spine_0', 'X', -1.0 * S)
    shift('IK_Paw_HR', (-0.01 * lift, 0, 0.03 * lift))
    EVENTS['Idle_PawShift'] = {'weight_to_left': 30, 'hind_right_paw_up': 46, 'paw_down': 62}


def wing_stretch(f, L):
    S = curve(f, [(1, 0), (20, 0), (62, 1), (122, 1), (170, 0), (L + 1, 0)])
    tremble = 0.04 * math.sin(2 * math.pi * f / 5.0) * ss((f - 62) / 10) * (1 - ss((f - 112) / 10))
    for side, sg in (('L', 1), ('R', -1)):
        rot(f'Wing_{side}_Shoulder', 'X', sg * 38.0 * (S + tremble))
        rot(f'Wing_{side}_Shoulder', 'Z', -sg * 8.0 * S)
        rot(f'Wing_{side}_Arm', 'X', sg * 8.0 * S)
        rot(f'Wing_{side}_Forearm', 'Z', -sg * 5.0 * S)
        for d, a in (('D1_0', 7.0), ('D2_0', 5.0), ('D3_0', 3.0), ('D4_0', 1.5)):
            rot(f'Wing_{side}_{d}', 'X', sg * a * S)
    for b in neck:
        rot(b, 'Y', -0.5 * S)
    rot('tripo::Spine_1', 'Y', -2.0 * S)
    shift('tripo::Root', (0, 0, 0.003 * S))
    EVENTS['Idle_WingStretch'] = {'spreading': 20, 'full_spread': 62, 'folding_back': 122, 'rest': 170}


def snort(f, L):
    inh = curve(f, [(1, 0), (10, 0), (30, 1), (34, 1), (48, 0), (L + 1, 0)])
    puff = bump(f, 34, 52)
    for b in neck:
        rot(b, 'Y', -0.6 * inh + 1.0 * puff)
    rot('tripo::Spine_1', 'Y', -3.0 * inh + 3.0 * puff)
    rot('Jaw', 'Y', 10.0 * puff)
    shift('tripo::Root', (0, 0, 0.003 * inh - 0.006 * puff))
    for i, b in enumerate(tail):
        rot(b, 'Z', 4.0 * puff * math.sin(0.7 * i - 0.2 * f))
    EVENTS['Idle_Snort'] = {'inhale_start': 10, 'inhale_peak': 30, 'puff': 40, 'settled': 52}


def tail_swish(f, L):
    A = bump(f, 18, 78)
    for i, b in enumerate(tail):
        rot(b, 'Z', 5.5 * A * math.sin(2 * math.pi * (f - 18) / 60.0 - 0.5 * (i + 1)))
    for b in neck:
        rot(b, 'Z', 1.2 * A * math.sin(2 * math.pi * (f - 18) / 60.0 - 1.5))
    EVENTS['Idle_TailSwish'] = {'sweep_start': 18, 'sweep_end': 78}


VARS = {
    'Idle_LookAround': (192, look_around), 'Idle_PawStomp': (96, paw_stomp), 'Idle_PawShift': (96, paw_shift),
    'Idle_WingStretch': (192, wing_stretch), 'Idle_Snort': (96, snort), 'Idle_TailSwish': (96, tail_swish),
}


def pose_var(name, f):
    L, fn = VARS[name]
    reset()
    base(1 + (f - 1) % BREATH)          # the breath repeats every 96 frames
    fn(f, L)


def key_frame(f):
    for n in ANIM:
        pb[n].keyframe_insert('location', frame=f)
        pb[n].keyframe_insert('rotation_quaternion', frame=f)


for a in list(bpy.data.actions):
    a.use_fake_user = True
arm.animation_data_create()
for t in list(arm.animation_data.nla_tracks):
    arm.animation_data.nla_tracks.remove(t)          # a re-run must not evaluate the old showcase strip underneath
made = {}
for name, (L, fn) in VARS.items():
    if name in bpy.data.actions:
        bpy.data.actions.remove(bpy.data.actions[name])
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    for f in range(1, L + 2):
        pose_var(name, 1 if f == L + 1 else f)
        key_frame(f)
    made[name] = act
reset()

# ---------------------------------------------------------------- markers (event frames; they do not export to glTF, so they are also written to a json)
for name, ev in EVENTS.items():
    for label, fr in ev.items():
        mk = made[name].pose_markers.new(label)
        mk.frame = fr

# ---------------------------------------------------------------- measure every clip
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
track = {'head tip': int(np.argmax(rest_mesh[:, 0])), 'tail tip': int(np.argmin(rest_mesh[:, 0])), 'left wing tip': int(np.argmax(rest_mesh[:, 1])),
         'right wing tip': int(np.argmin(rest_mesh[:, 1])), 'chest': int(np.argmin(np.linalg.norm(rest_mesh - np.array([0.30, 0.0, 0.30]), axis=1)))}
eff = {'HL': 'HindLeg_L_Ankle', 'HR': 'HindLeg_R_Ankle', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
knee = {'HL': 'HindLeg_L_Knee', 'HR': 'HindLeg_R_Knee', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
limb_root = {'HL': 'HindLeg_L_Hip', 'HR': 'HindLeg_R_Hip', 'FL': 'bone_26', 'FR': 'bone_42'}


def mesh_at(f):
    scn.frame_set(f)
    bpy.context.view_layer.update()
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    m = ev.to_mesh()
    V = np.array([v.co[:] for v in m.vertices])
    ev.to_mesh_clear()
    return V


def sample_track(V):
    return {k: V[i] for k, i in track.items()}


def ankle_pos():
    return {k: np.array(pb[b].tail) for k, b in eff.items()}


arm.animation_data.action = bpy.data.actions['Idle']
idle0 = (sample_track(mesh_at(1)), ankle_pos())
report = {}
for name, (L, fn) in VARS.items():
    arm.animation_data.action = made[name]
    stats, zmin, tg, anl, kx, tr = [], [], {k: [] for k in eff}, {k: [] for k in eff}, {k: [] for k in eff}, {k: [] for k in track}
    worst_edge = {}
    for f in range(1, L + 2):
        V = mesh_at(f)
        ratio = np.linalg.norm(V[edges[:, 0]] - V[edges[:, 1]], axis=1) / rest_len
        bad = (ratio > 1.5) | (ratio < 0.5)
        stats.append((float(ratio.max()), int(bad.sum())))
        zmin.append((float(V[foot_all, 2].min()), float(V[tail_all, 2].min()), float(V[~foot_all & ~tail_all, 2].min())))
        em = int(np.argmax(ratio))
        if ratio[em] > worst_edge.get('ratio', 0):
            worst_edge = {'ratio': round(float(ratio[em]), 2), 'frame': f, 'at': ((rest_mesh[edges[em, 0]] + rest_mesh[edges[em, 1]]) / 2).round(3).tolist(),
                          'bones': [str(dom[edges[em, 0]]), str(dom[edges[em, 1]])]}
        for k in eff:
            tg[k].append(np.array(pb[f'IK_Paw_{k}'].head))
            anl[k].append(np.array(pb[eff[k]].tail))
            kn = np.array(pb[knee[k]].head); rt = np.array(pb[limb_root[k]].head); b = np.array(pb[eff[k]].tail)
            kx[k].append(float(kn[0] - (rt[0] + (kn[2] - rt[2]) / (b[2] - rt[2]) * (b[0] - rt[0]))))
        for k, p in sample_track(V).items():
            tr[k].append(p)
    first = (sample_track(mesh_at(1)), ankle_pos())
    seam_loop = max(float(np.linalg.norm(tr[k][0] - tr[k][-1])) for k in track)
    seam_idle = max(max(float(np.linalg.norm(first[0][k] - idle0[0][k])) for k in track), max(float(np.linalg.norm(first[1][k] - idle0[1][k])) for k in eff))
    paw_off = {}
    for k in eff:
        A = np.array(tg[k])
        rest_t = A[0]
        d = np.linalg.norm(A - rest_t, axis=1)
        moved = int((d > 1e-6).sum())
        paw_off[k] = {'frames_off_rest': moved, 'peak_lift_and_reach': round(float(d.max()), 4), 'ends_back_at_rest': bool(d[-1] < 1e-6),
                      'ik_error_max': round(max(float(np.linalg.norm(A[i] - np.array(anl[k][i]))) for i in range(len(A))), 5),
                      'knee_x': [round(min(kx[k]), 3), round(max(kx[k]), 3)]}
    mr = {k: [round(float(x), 3) for x in np.ptp(np.array(tr[k]), axis=0)] for k in track}
    report[name] = {'frames': L, 'seconds': round(L / FPS, 1), 'paws': paw_off, 'seam_end_vs_start': round(seam_loop, 6), 'seam_start_vs_idle': round(seam_idle, 6),
                    'max_stretch': round(max(s[0] for s in stats), 2), 'worst_bad_edges': max(s[1] for s in stats), 'max_edge': worst_edge,
                    'clearance': {'foot': round(min(z[0] for z in zmin), 4), 'tail': round(min(z[1] for z in zmin), 4), 'body': round(min(z[2] for z in zmin), 4)},
                    'motion_range': mr, 'events': EVENTS.get(name)}
scn.frame_set(1)
json.dump(report, open(SC + 'idle_var_report.json', 'w'))
json.dump(EVENTS, open(OUT + '/vyrath_idle_variation_events.json', 'w'), indent=1)
print('MEASURED', list(report))

# ---------------------------------------------------------------- showcase strip: every variation, each between two idles
idle_act = bpy.data.actions['Idle']
order = ['Idle', 'Idle_LookAround', 'Idle', 'Idle_PawStomp', 'Idle', 'Idle_PawShift', 'Idle_WingStretch', 'Idle', 'Idle_Snort', 'Idle', 'Idle_TailSwish', 'Idle']
arm.animation_data.action = None
for t in list(arm.animation_data.nla_tracks):
    arm.animation_data.nla_tracks.remove(t)
trk = arm.animation_data.nla_tracks.new()
trk.name = 'Showcase'
start = 1
lens = {'Idle': 96, **{k: v[0] for k, v in VARS.items()}}
for i, n in enumerate(order):
    act = bpy.data.actions[n]
    strip = trk.strips.new(f'{i + 1:02d} {n}', start, act)
    strip.action_frame_start, strip.action_frame_end = 1, lens[n] + 1
    strip.frame_end = start + lens[n]
    strip.extrapolation = 'NOTHING'
    start += lens[n]
total = start
scn.frame_start, scn.frame_end = 1, total - 1
scn.frame_set(1)
print('showcase frames', total - 1, 'seconds', round((total - 1) / FPS, 1))

# ---------------------------------------------------------------- renders: key frames of each clip
if DO_RENDER:
    IMG = SC + 'vyrath_var_img'
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
        cam = bpy.data.objects.new("VarCam", bpy.data.cameras.new("VarCam")); scn.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    scn.camera = cam
    VIEW = {'side': ((0.0, -3.0, 0.36), (90, 0, 0), 1.4), 'top': ((0.0, 0.0, 3.0), (0, 0, 0), 1.4), 'front': ((3.0, 0.0, 0.36), (90, 0, 90), 1.4)}
    SHOTS = [('Idle_LookAround', 1, 'top'), ('Idle_LookAround', 58, 'top'), ('Idle_LookAround', 122, 'top'),
             ('Idle_PawStomp', 1, 'side'), ('Idle_PawStomp', 38, 'side'), ('Idle_PawStomp', 52, 'side'),
             ('Idle_PawShift', 1, 'front'), ('Idle_PawShift', 50, 'front'),
             ('Idle_WingStretch', 1, 'front'), ('Idle_WingStretch', 90, 'front'),
             ('Idle_Snort', 1, 'side'), ('Idle_Snort', 30, 'side'), ('Idle_Snort', 40, 'side'),
             ('Idle_TailSwish', 1, 'top'), ('Idle_TailSwish', 36, 'top'), ('Idle_TailSwish', 58, 'top')]
    arm.animation_data.action = None
    saved_tracks = [t.mute for t in arm.animation_data.nla_tracks]
    for t in arm.animation_data.nla_tracks:
        t.mute = True
    for nm, f, v in SHOTS:
        arm.animation_data.action = made[nm]
        scn.frame_set(f)
        loc, eul, sc = VIEW[v]
        cam.location = loc; cam.rotation_euler = tuple(math.radians(a) for a in eul); cam.data.ortho_scale = sc
        scn.render.filepath = f"{IMG}/{nm}_{f:03d}_{v}.png"
        bpy.ops.render.render(write_still=True)
    arm.animation_data.action = None
    for t, m in zip(arm.animation_data.nla_tracks, saved_tracks):
        t.mute = m
    scn.frame_set(1)

if SAVE:
    bpy.ops.wm.save_as_mainfile(filepath=OUT + "/vyrath_motion_v4.blend")

# ---------------------------------------------------------------- bake every clip and export them as separate animations
if DO_EXPORT:
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
    for a in list(bpy.data.actions):
        if a.name == 'Walk':
            bpy.data.actions.remove(a)
    names = ['Idle'] + list(VARS)
    baked = {}
    for n in names:
        src = bpy.data.actions[n]
        arm.animation_data.action = src
        L = lens[n]
        mode('POSE')
        with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl, selected_objects=[arm]):
            bpy.ops.pose.select_all(action='SELECT')
            bpy.ops.nla.bake(frame_start=1, frame_end=L + 1, only_selected=False, visual_keying=True, clear_constraints=False,
                             clear_parents=False, use_current_action=False, bake_types={'POSE'})
        mode('OBJECT')
        b = arm.animation_data.action
        baked[n] = b
        src.name = n + '_src'
        b.name = n
    for n in names:
        bpy.data.actions.remove(bpy.data.actions[n + '_src'])
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], view_layer=vl, active_object=arm, object=arm,
                                   selected_objects=[arm, body], selected_editable_objects=[arm, body]):
        for o in bpy.data.objects:
            o.select_set(o in (arm, body))
        bpy.ops.export_scene.gltf(filepath=OUT + "/vyrath_idle_variations_v4.glb", export_format='GLB', use_selection=True, export_skins=True,
                                  export_animations=True, export_force_sampling=True, export_apply=False)
    print('exported variations glb', os.path.getsize(OUT + "/vyrath_idle_variations_v4.glb"))
