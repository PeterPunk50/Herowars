import bpy, math, json, os
import numpy as np
from mathutils import Matrix, Vector

SRC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_rig_v4.blend"
OUT = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
SC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/walk_work/"

FPS = 24
T = globals().get('WALK_T', 48)               # frames per cycle
DUTY = globals().get('WALK_DUTY', 0.75)       # fraction of the cycle each foot is planted
STRIDE = globals().get('WALK_STRIDE', 0.14)   # distance a foot travels back while planted
DROP = globals().get('WALK_DROP', 0.02)       # body lowered so the nearly straight front legs have slack
LIFTH = globals().get('WALK_LIFTH', 0.05)
LIFTF = globals().get('WALK_LIFTF', 0.03)
LIFT = {'HL': LIFTH, 'HR': LIFTH, 'FL': LIFTF, 'FR': LIFTF}
PHASE = {'HL': 0.0, 'FL': 0.25, 'HR': 0.5, 'FR': 0.75}   # lateral-sequence walk: HL, FL, HR, FR
SPEED = STRIDE / (DUTY * T / FPS)             # body speed (units per second) that keeps planted feet still on the ground
TAIL_LIFT = globals().get('TAIL_LIFT', 2.0)   # degrees per tail bone, so the tip clears the ground
DO_BAKE = globals().get('DO_BAKE', True)
DO_RENDER = globals().get('DO_RENDER', True)
SAVE = globals().get('SAVE', True)

bpy.ops.wm.open_mainfile(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
me = body.data
N = len(me.vertices)
vl = bpy.data.scenes[0].view_layers[0]
scn = bpy.context.scene
scn.render.fps = FPS


def mode(m):
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl):
        bpy.ops.object.mode_set(mode=m)


# ------------------------------------------------------------------ a ground bone above the body and the IK targets
mode('EDIT')
eb = arm.data.edit_bones
g = eb.new('Ground')
g.head, g.tail = Vector((0, 0, 0)), Vector((0, 0, 0.05))
root = eb['tripo::Root']
root.parent = g
for n in ('IK_Paw_HL', 'IK_Paw_HR', 'IK_Paw_FL', 'IK_Paw_FR'):
    eb[n].parent = g
    eb[n].use_connect = False
mode('OBJECT')


# ------------------------------------------------------------------ optional hip fix: the dorsal midline above the hips was split between the two thigh bones
R_HIP = globals().get('R_HIP', 0.10)
if R_HIP > 0:
    names_ = [gr.name for gr in body.vertex_groups]
    W_ = np.zeros((N, len(names_)))
    for v in me.vertices:
        for gg in v.groups:
            W_[v.index, gg.group] = gg.weight
    rest_ = np.array([v.co[:] for v in me.vertices])
    key_ = np.round(rest_ * 1e5).astype(np.int64)
    _, first_, inv_ = np.unique(key_, axis=0, return_index=True, return_inverse=True)
    inv_ = inv_.reshape(-1)
    M_ = inv_.max() + 1
    cnt_ = np.bincount(inv_, minlength=M_).astype(float)
    Wc_ = np.zeros((M_, W_.shape[1])); np.add.at(Wc_, inv_, W_); Wc_ /= cnt_[:, None]
    restc_ = rest_[first_]
    ed_ = np.edges_unique if False else None
    e0 = np.array([[e.vertices[0], e.vertices[1]] for e in me.edges])
    ec_ = np.unique(np.sort(inv_[e0], axis=1), axis=0); ec_ = ec_[ec_[:, 0] != ec_[:, 1]]
    deg_ = np.bincount(ec_.ravel(), minlength=M_).astype(float)
    reg_ = (np.linalg.norm(restc_ - np.array([0.124, 0.0, globals().get('HIP_Z', 0.27)]), axis=1) < R_HIP) & (np.abs(restc_[:, 1]) < globals().get('HIP_Y', 0.08))
    for _ in range(300):
        acc_ = np.zeros_like(Wc_)
        np.add.at(acc_, ec_[:, 0], Wc_[ec_[:, 1]]); np.add.at(acc_, ec_[:, 1], Wc_[ec_[:, 0]])
        Wn_ = Wc_.copy(); Wn_[reg_] = acc_[reg_] / np.maximum(deg_[reg_], 1)[:, None]; Wc_ = Wn_
    W_ = Wc_[inv_]
    drop_ = np.argsort(-W_, axis=1)[:, 4:]; np.put_along_axis(W_, drop_, 0, axis=1); W_[W_ < 0.01] = 0
    W_ /= np.maximum(W_.sum(1, keepdims=True), 1e-9)
    for vg in list(body.vertex_groups):
        body.vertex_groups.remove(vg)
    vgs_ = {n: body.vertex_groups.new(name=n) for n in names_}
    for i in range(N):
        for gi in np.nonzero(W_[i])[0]:
            vgs_[names_[gi]].add([i], float(W_[i, gi]), 'REPLACE')
    print('HIPFIX verts', int(reg_.sum()))

pb = arm.pose.bones
neck = [f'Neck_{i + 1:02d}' for i in range(8)]
tail = [f'Tail_{i + 1:02d}' for i in range(12)]
ANIM = ['tripo::Root', 'Pelvis', 'tripo::Spine_0', 'tripo::Spine_1'] + neck + tail + ['IK_Paw_HL', 'IK_Paw_HR', 'IK_Paw_FL', 'IK_Paw_FR']


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


def smooth(w):
    return w * w * (3 - 2 * w)


def foot_offset(key, f):
    """Offset of a paw target from its rest position (armature space): x forward, z up."""
    u = ((f - 1) / T - PHASE[key]) % 1.0
    if u < DUTY:                                   # planted: slides back at body speed
        return (STRIDE / 2 - STRIDE * (u / DUTY), 0.0), True
    w = (u - DUTY) / (1 - DUTY)                    # swing: forward with a lift
    return (-STRIDE / 2 + STRIDE * smooth(w), LIFT[key] * math.sin(math.pi * w)), False


def pose_frame(f):
    reset()
    ph = 2 * math.pi * (f - 1) / T
    # body: lowered, bobbing twice per cycle (once per footfall pair)
    shift('tripo::Root', (0, 0, -DROP + 0.006 * math.sin(2 * ph + 0.6)))
    rot('Pelvis', 'Z', 4.0 * math.sin(ph))
    rot('tripo::Spine_0', 'Z', -2.0 * math.sin(ph))
    rot('tripo::Spine_1', 'Z', -3.0 * math.sin(ph))
    for i, b in enumerate(tail):                   # a wave travelling down the tail
        rot(b, 'Z', 2.2 * math.sin(ph - 0.45 * (i + 1)))
        rot(b, 'Y', TAIL_LIFT + 0.8 * math.sin(2 * ph - 0.5 * (i + 1)))
    for i, b in enumerate(neck):                   # head stays level against the shoulder sway
        rot(b, 'Z', 3.0 * math.sin(ph + math.pi) / 8 * 3)
        rot(b, 'Y', 0.7 * math.sin(2 * ph + 1.0))
    for key in ('HL', 'HR', 'FL', 'FR'):
        (dx, dz), planted = foot_offset(key, f)
        shift(f'IK_Paw_{key}', (dx, 0, dz))


def key_frame(f):
    for n in ANIM:
        pb[n].keyframe_insert('location', frame=f)
        pb[n].keyframe_insert('rotation_quaternion', frame=f)


# ------------------------------------------------------------------ key the cycle
if arm.animation_data and arm.animation_data.action:
    bpy.data.actions.remove(arm.animation_data.action)
arm.animation_data_create()
arm.animation_data.action = bpy.data.actions.new('Walk')
for f in range(1, T + 2):
    pose_frame(1 if f == T + 1 else f)
    key_frame(f)
reset()
for fc in arm.animation_data.action.fcurves if hasattr(arm.animation_data.action, 'fcurves') else []:
    for kp in fc.keyframe_points:
        kp.interpolation = 'LINEAR'
scn.frame_start, scn.frame_end = 1, T

# ------------------------------------------------------------------ measure
rest_mesh = np.array([v.co[:] for v in me.vertices])
edges = np.array([[e.vertices[0], e.vertices[1]] for e in me.edges])
rest_len = np.maximum(np.linalg.norm(rest_mesh[edges[:, 0]] - rest_mesh[edges[:, 1]], axis=1), 1e-6)
gname = {i: gr.name for i, gr in enumerate(body.vertex_groups)}
W = np.zeros((N, len(gname)))
for v in me.vertices:
    for gg in v.groups:
        W[v.index, gg.group] = gg.weight
dom = np.array([gname[i] for i in W.argmax(1)])
toe_idx = {}
foot_groups = {'HL': ['HindLeg_L_Foot'], 'HR': ['HindLeg_R_Foot'], 'FL': ['tripo::0_Left_Limb_2', 'tripo::0_Left_Limb_3', 'tripo::0_Left_Limb_4'],
               'FR': ['tripo::0_Right_Limb_1', 'tripo::0_Right_Limb_2', 'tripo::0_Right_Limb_3']}
for k, gs in foot_groups.items():
    idx = np.where(np.isin(dom, gs))[0]
    toe_idx[k] = idx[np.argmin(rest_mesh[idx, 2])]          # lowest vertex of that foot at rest
eff = {'HL': 'HindLeg_L_Ankle', 'HR': 'HindLeg_R_Ankle', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
knee = {'HL': 'HindLeg_L_Knee', 'HR': 'HindLeg_R_Knee', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
limb_root = {'HL': 'HindLeg_L_Hip', 'HR': 'HindLeg_R_Hip', 'FL': 'bone_26', 'FR': 'bone_42'}
data = {k: {'target': [], 'ball': [], 'toe': [], 'planted': [], 'knee_x': []} for k in eff}
mesh_stats = []
foot_all = np.isin(dom, sum(foot_groups.values(), []))
tail_all = np.array([d.startswith('Tail_') for d in dom])
zmins = []
worst = {'bad': -1}
maxedge = {}
for f in range(1, T + 1):
    scn.frame_set(f)
    bpy.context.view_layer.update()
    gx = SPEED * (f - 1) / FPS                                  # the ground has moved this far back under the body
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    m = ev.to_mesh()
    V = np.array([v.co[:] for v in m.vertices])
    ev.to_mesh_clear()
    ratio = np.linalg.norm(V[edges[:, 0]] - V[edges[:, 1]], axis=1) / rest_len
    badm = (ratio > 1.5) | (ratio < 0.5)
    mesh_stats.append((float(ratio.max()), int(badm.sum()), float(V[:, 2].min())))
    zmins.append((float(V[foot_all, 2].min()), float(V[tail_all, 2].min()), float(V[~foot_all & ~tail_all, 2].min())))
    em = int(np.argmax(ratio))
    if ratio[em] > maxedge.get('ratio', 0):
        maxedge = {'ratio': round(float(ratio[em]), 2), 'frame': f, 'at': ((rest_mesh[edges[em, 0]] + rest_mesh[edges[em, 1]]) / 2).round(3).tolist(),
                   'bones': [str(dom[edges[em, 0]]), str(dom[edges[em, 1]])], 'len0': round(float(rest_len[em]), 4), 'len1': round(float(ratio[em] * rest_len[em]), 4)}
    if badm.sum() > worst['bad']:
        mp = (rest_mesh[edges[badm, 0]] + rest_mesh[edges[badm, 1]]) / 2
        worst = {'bad': int(badm.sum()), 'frame': f, 'bbox_min': mp.min(0).round(2).tolist() if badm.any() else None,
                 'bbox_max': mp.max(0).round(2).tolist() if badm.any() else None,
                 'pairs': {}}
        from collections import Counter
        cnt = Counter()
        for e in np.where(badm)[0]:
            cnt[tuple(sorted((dom[edges[e, 0]], dom[edges[e, 1]])))] += 1
        worst['pairs'] = [(list(k), c) for k, c in cnt.most_common(5)]
    for k in eff:
        t = np.array(pb[f'IK_Paw_{k}'].head)
        b = np.array(pb[eff[k]].tail)
        toe = V[toe_idx[k]]
        (_, _), planted = foot_offset(k, f)
        data[k]['target'].append([t[0] + gx, t[1], t[2]])
        data[k]['ball'].append([b[0] + gx, b[1], b[2]])
        data[k]['toe'].append([toe[0] + gx, toe[1], toe[2]])
        data[k]['planted'].append(bool(planted))
        kn = np.array(pb[knee[k]].head)
        rt = np.array(pb[limb_root[k]].head)
        fr = (kn[2] - rt[2]) / (b[2] - rt[2])
        data[k]['knee_x'].append(float(kn[0] - (rt[0] + fr * (b[0] - rt[0]))))   # + = joint bows forward of the hip-to-foot line
scn.frame_set(1)

report = {'speed': round(SPEED, 4), 'stride': STRIDE, 'cycle_s': T / FPS, 'duty': DUTY, 'drop': DROP, 'feet': {}}
for k in eff:
    pl = np.array(data[k]['planted'])
    out = {}
    for what in ('target', 'ball', 'toe'):
        A1 = np.array(data[k][what])
        A = np.concatenate([A1, A1])                    # the cycle twice, with ground offset kept continuous
        A[:, 0] += SPEED * (np.arange(2 * T) // T * T) / FPS * 0   # (x already includes the offset of its own cycle position)
        shift_x = np.concatenate([np.zeros(T), np.full(T, -SPEED * T / FPS)])   # second pass: ground has moved on a whole cycle
        A[:, 0] += shift_x * -1
        pl2 = np.concatenate([pl, pl])
        runs, cur = [], []
        for i in range(2 * T):
            if pl2[i]:
                cur.append(i)
            else:
                if cur and cur[0] > 0:
                    runs.append(cur)
                cur = []
        runs = [r for r in runs if r[-1] < 2 * T - 1]
        drift_x = max(float(np.ptp(A[r, 0])) for r in runs)
        drift_y = max(float(np.ptp(A[r, 1])) for r in runs)
        zr = max(float(np.ptp(A[r, 2])) for r in runs)
        out[what] = {'slide_x': round(drift_x, 5), 'slide_y': round(drift_y, 5), 'height_change': round(zr, 5)}
    ik_err = [float(np.linalg.norm(np.array(data[k]['target'][i]) - np.array(data[k]['ball'][i]))) for i in range(T)]
    out['ik_error_max'] = round(max(ik_err), 5)
    kx = np.array(data[k]['knee_x'])
    out['knee_x_range'] = [round(float(kx.min()), 3), round(float(kx.max()), 3)]
    report['feet'][k] = out
report['clearance'] = {'foot_min_z': round(min(z[0] for z in zmins), 4), 'tail_min_z': round(min(z[1] for z in zmins), 4), 'body_min_z': round(min(z[2] for z in zmins), 4)}
report['worst_frame'] = worst
report['max_edge'] = maxedge
report['mesh'] = {'max_stretch': round(max(s[0] for s in mesh_stats), 2), 'worst_bad_edges_in_a_frame': max(s[1] for s in mesh_stats),
                  'lowest_vertex_z': round(min(s[2] for s in mesh_stats), 4), 'rest_lowest_z': round(float(rest_mesh[:, 2].min()), 4)}
json.dump({'report': report, 'data': {k: {w: (v if w == 'planted' or w == 'knee_x' else np.array(v).round(5).tolist()) for w, v in d.items()} for k, d in data.items()},
           'T': T, 'fps': FPS, 'speed': SPEED}, open(SC + 'walk_data.json', 'w'))
print(json.dumps(report) if not globals().get('COMPACT_ONLY') else '')
if globals().get('COMPACT_ONLY'):
    ff = report['feet']
    print('CFG drop', DROP, 'liftF', LIFTF, 'liftH', LIFTH, 'tailLift', TAIL_LIFT, '| bad', report['mesh']['worst_bad_edges_in_a_frame'], 'max', report['mesh']['max_stretch'],
          '| toe slide mm', {k: round(ff[k]['toe']['slide_x'] * 1000, 1) for k in ff}, '| ikerr', max(ff[k]['ik_error_max'] for k in ff),
          '| maxedge', report['max_edge'], '| clear', report['clearance'], '| worst', report['worst_frame']['frame'], report['worst_frame']['pairs'][:3])

# ------------------------------------------------------------------ renders
if DO_RENDER:
    IMG = SC + 'vyrath_walk_img'
    os.makedirs(IMG, exist_ok=True)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not body:
            o.hide_render = True; o.hide_viewport = True
    scn.render.engine = 'BLENDER_WORKBENCH'
    scn.render.resolution_x, scn.render.resolution_y = 520, 300
    scn.display.shading.light = 'STUDIO'
    scn.display.shading.color_type = 'TEXTURE'
    scn.display.shading.background_type = 'WORLD'
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.color = (0.93, 0.93, 0.93)
    cd = bpy.data.cameras.new("WalkCam"); cd.type = 'ORTHO'; cd.ortho_scale = 1.4
    cam = bpy.data.objects.new("WalkCam", cd); scn.collection.objects.link(cam); scn.camera = cam
    cam.location = (0.0, -3.0, 0.36); cam.rotation_euler = (math.radians(90), 0, 0)
    # a ground line so planted feet can be seen against it
    for f in range(1, T + 1, T // 8):
        scn.frame_set(f)
        scn.render.filepath = f"{IMG}/walk_{f:02d}.png"
        bpy.ops.render.render(write_still=True)
    scn.frame_set(1)

if SAVE:
    bpy.ops.wm.save_as_mainfile(filepath=OUT + "/vyrath_walk_v4.blend")

if DO_BAKE:
    # bake every bone's final pose (IK and copy-rotation included) into plain keys so the animation survives glTF export
    mode('POSE')
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl, selected_objects=[arm]):
        bpy.ops.pose.select_all(action='SELECT')
        bpy.ops.nla.bake(frame_start=1, frame_end=T + 1, only_selected=False, visual_keying=True, clear_constraints=False,
                         clear_parents=False, use_current_action=False, bake_types={'POSE'})
    mode('OBJECT')
    baked = arm.animation_data.action
    stale = bpy.data.actions.get('Walk')
    if stale is not None and stale is not baked:
        bpy.data.actions.remove(stale)          # export only the baked action, once
    baked.name = 'Walk'
    print('baked action:', arm.animation_data.action.name if arm.animation_data and arm.animation_data.action else None)
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], view_layer=vl, active_object=arm, object=arm,
                                   selected_objects=[arm, body], selected_editable_objects=[arm, body]):
        for o in bpy.data.objects:
            o.select_set(o in (arm, body))
        try:
            bpy.ops.export_scene.gltf(filepath=OUT + "/vyrath_walk_v4.glb", export_format='GLB', use_selection=True, export_skins=True,
                                      export_animations=True, export_force_sampling=True, export_apply=False)
        except TypeError as ex:
            print('export option problem:', ex)
            bpy.ops.export_scene.gltf(filepath=OUT + "/vyrath_walk_v4.glb", export_format='GLB', use_selection=True, export_skins=True,
                                      export_animations=True, export_apply=False)
    print('exported walk glb', os.path.getsize(OUT + "/vyrath_walk_v4.glb"))

