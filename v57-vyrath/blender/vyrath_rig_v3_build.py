import bpy, math, json, os
import numpy as np
from mathutils import Matrix, Vector

SRC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_rig_fixed.blend"
OUT = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
SC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/v3_work/"

bpy.ops.wm.open_mainfile(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
me = body.data
N = len(me.vertices)
vl = bpy.data.scenes[0].view_layers[0]
edges = np.array([[e.vertices[0], e.vertices[1]] for e in me.edges])
rest = np.array([v.co[:] for v in me.vertices])
rest_len = np.maximum(np.linalg.norm(rest[edges[:, 0]] - rest[edges[:, 1]], axis=1), 1e-6)
mid_y = (rest[edges[:, 0], 1] + rest[edges[:, 1], 1]) / 2


def mode(m):
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl):
        bpy.ops.object.mode_set(mode=m)


def get_W():
    names = [g.name for g in body.vertex_groups]
    W = np.zeros((N, len(names)))
    for v in me.vertices:
        for g in v.groups:
            W[v.index, g.group] = g.weight
    return names, W


def rot(bone, axis, deg):
    if bone not in arm.pose.bones:
        return
    pb = arm.pose.bones[bone]
    m = pb.matrix.copy()
    head = m.translation.copy()
    pb.matrix = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head) @ m
    bpy.context.view_layer.update()


def move(bone, delta):
    pb = arm.pose.bones[bone]
    m = pb.matrix.copy()
    m.translation += Vector(delta)
    pb.matrix = m
    bpy.context.view_layer.update()


def reset():
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def verts():
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    m = ev.to_mesh()
    a = np.array([v.co[:] for v in m.vertices])
    ev.to_mesh_clear()
    return a


def measure(fn):
    reset()
    fn()
    v = verts()
    ratio = np.linalg.norm(v[edges[:, 0]] - v[edges[:, 1]], axis=1) / rest_len
    bad = (ratio > 1.5) | (ratio < 0.5)
    disp = np.linalg.norm(v - rest, axis=1)
    moved = disp > 0.01
    reset()
    return {'max': round(float(ratio.max()), 2), 'bad': int(bad.sum()), 'moved': int(moved.sum()),
            'moved_bbox': [rest[moved].min(0).round(2).tolist(), rest[moved].max(0).round(2).tolist()] if moved.any() else None}


OLD_TAIL = ['bone_2'] + [f'tripo::Tail_{i}' for i in range(5)]
OLD_NECK = ['bone_10', 'bone_11', 'tripo::Head_0', 'tripo::Head_1', 'tripo::Head_2']
OLD_HIND = ['bone_48', 'bone_49', 'tripo::1_Left_Limb_0', 'tripo::1_Left_Limb_1']

# ------------------------------------------------------------------ before
def b_tail(): [rot(b, 'Z', 12) for b in OLD_TAIL]
def b_neckdown(): [rot(b, 'Y', 8) for b in OLD_NECK]
def b_neckside(): [rot(b, 'Z', 7) for b in OLD_NECK]
def b_jaw(): rot('tripo::Head_4', 'Y', 25)
before = {'tail_curl_72': measure(b_tail), 'neck_down_40': measure(b_neckdown), 'neck_side_35': measure(b_neckside), 'jaw_open_25': measure(b_jaw)}

# ------------------------------------------------------------------ renames (vertex groups follow)
mode('OBJECT')
arm.data.bones['tripo::Head_3'].name = 'Head'
arm.data.bones['tripo::Head_4'].name = 'Jaw'
gn = [g.name for g in body.vertex_groups]
assert 'Head' in gn and 'Jaw' in gn, gn

B = {b.name: (np.array(b.head_local), np.array(b.tail_local)) for b in arm.data.bones}
names, W = get_W()
idx = {n: i for i, n in enumerate(names)}


def seg_dist(P, a, b):
    ab = b - a
    t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
    return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)


def project(P, pts):
    cum = [0.0]
    for a, b in zip(pts[:-1], pts[1:]):
        cum.append(cum[-1] + float(np.linalg.norm(b - a)))
    best = np.full(len(P), 1e9)
    s = np.zeros(len(P))
    for (a, b), c0 in zip(zip(pts[:-1], pts[1:]), cum[:-1]):
        ab = b - a
        L = np.linalg.norm(ab)
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        d = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
        m = d < best
        best[m] = d[m]
        s[m] = c0 + t[m] * L
    return s, cum


def point_at(pts, cum, s):
    s = min(max(s, 0), cum[-1])
    for k in range(len(pts) - 1):
        if s <= cum[k + 1] + 1e-12:
            t = (s - cum[k]) / max(cum[k + 1] - cum[k], 1e-9)
            return pts[k] + t * (pts[k + 1] - pts[k])
    return pts[-1]


def chain_from_polyline(pts, n):
    cum = [0.0]
    for a, b in zip(pts[:-1], pts[1:]):
        cum.append(cum[-1] + float(np.linalg.norm(b - a)))
    L = cum[-1]
    joints = [point_at(pts, cum, L * k / n) for k in range(n + 1)]
    return joints, L


def redistribute(old_names, new_names, joints, L, pts, sigma_frac=0.35):
    """Move the weight carried by old_names onto a denser chain, by position along the polyline."""
    oi = [idx[n] for n in old_names]
    tw = W[:, oi].sum(1)
    sel = np.where(tw > 1e-6)[0]
    s, cum = project(rest[sel], pts)
    n = len(new_names)
    seg = L / n
    sig = sigma_frac * seg
    lo = np.arange(n) * seg
    hi = lo + seg
    dist = np.maximum(0, np.maximum(lo[None, :] - s[:, None], s[:, None] - hi[None, :]))
    w = np.exp(-(dist / sig) ** 2)
    w /= w.sum(1, keepdims=True)
    for gi in oi:
        W[sel, gi] = 0
    for k, nm in enumerate(new_names):
        W[sel, idx[nm]] += tw[sel] * w[:, k]
    return len(sel)


# ------------------------------------------------------------------ geometry
neck_pts = [B[n][0] for n in ['bone_10', 'bone_11', 'tripo::Head_0', 'tripo::Head_1', 'tripo::Head_2']] + [B['Head'][0]]
tail_pts = [B[n][0] for n in ['bone_2', 'tripo::Tail_0', 'tripo::Tail_1', 'tripo::Tail_2', 'tripo::Tail_3', 'tripo::Tail_4']] + [B['tripo::Tail_4'][1]]
NECK_N, TAIL_N = 8, 12
neck_j, neck_L = chain_from_polyline(neck_pts, NECK_N)
tail_j, tail_L = chain_from_polyline(tail_pts, TAIL_N)
neck_names = [f'Neck_{i + 1:02d}' for i in range(NECK_N)]
tail_names = [f'Tail_{i + 1:02d}' for i in range(TAIL_N)]

# hind legs (left, y>0) measured from the mesh; right is the mirror
HL = {'hip': globals().get('HIP', (0.130, 0.058, 0.235)), 'knee': (0.160, 0.064, 0.145), 'ankle': (0.070, 0.072, 0.125),
      'ball': (0.072, 0.080, 0.028), 'toe': (0.128, 0.093, 0.008)}
hind = {}
for side, sg in (('L', 1), ('R', -1)):
    hind[side] = {k: np.array([v[0], sg * v[1], v[2]]) for k, v in HL.items()}
leg_bones = lambda side: [(f'HindLeg_{side}_Hip', 'hip', 'knee'), (f'HindLeg_{side}_Knee', 'knee', 'ankle'),
                          (f'HindLeg_{side}_Ankle', 'ankle', 'ball'), (f'HindLeg_{side}_Foot', 'ball', 'toe')]

# ------------------------------------------------------------------ new weights
all_new = neck_names + tail_names + [n for s in 'LR' for n, _, _ in leg_bones(s)]
names += all_new
W = np.hstack([W, np.zeros((N, len(all_new)))])
idx = {n: i for i, n in enumerate(names)}
n_neck = redistribute(OLD_NECK, neck_names, neck_j, neck_L, np.array(neck_pts), globals().get('NECK_SIG', 0.5))
n_tail = redistribute(OLD_TAIL, tail_names, tail_j, tail_L, np.array(tail_pts), globals().get('TAIL_SIG', 0.5))

oi = [idx[n] for n in OLD_HIND]
tw = W[:, oi].sum(1)
sel = np.where(tw > 1e-6)[0]
n_leg = {'L': 0, 'R': 0}
for side, sg in (('L', 1), ('R', -1)):
    ss = sel[(rest[sel, 1] >= 0) if sg == 1 else (rest[sel, 1] < 0)]
    segs = [(hind[side][a], hind[side][b]) for _, a, b in leg_bones(side)]
    D = np.stack([seg_dist(rest[ss], a, b) for a, b in segs], 1)
    w = np.exp(-((D - D.min(1, keepdims=True)) / 0.015) ** 2)
    w /= w.sum(1, keepdims=True)
    for k, (nm, _, _) in enumerate(leg_bones(side)):
        W[ss, idx[nm]] += tw[ss] * w[:, k]
    W[np.ix_(ss, oi)] = 0
    n_leg[side] = len(ss)

# Tripo left a few percent of Jaw weight on right hind-shin vertices; strip head weights from anything below the neck
head_idx = [idx[n] for n in ('Head', 'Jaw', 'bone_16') if n in idx]
low = rest[:, 2] < 0.45
for gi in head_idx:
    W[low, gi] = 0
rowsum = W.sum(1)
fix_rows = low & (rowsum > 0) & (rowsum < 0.999)
W[fix_rows] /= rowsum[fix_rows][:, None]

# merge duplicate-position vertices (UV seams) so the same position always gets the same weights
key = np.round(rest * 1e5).astype(np.int64)
_, inv = np.unique(key, axis=0, return_inverse=True)
inv = inv.reshape(-1)
Wc = np.zeros((inv.max() + 1, W.shape[1]))
np.add.at(Wc, inv, W)
Wc /= np.bincount(inv)[:, None]
W = Wc[inv]
drop = np.argsort(-W, axis=1)[:, 4:]
np.put_along_axis(W, drop, 0, axis=1)
W[W < 0.01] = 0
W /= np.maximum(W.sum(1, keepdims=True), 1e-9)

# ------------------------------------------------------------------ bones
V = lambda a: Vector(tuple(float(x) for x in a))
mode('EDIT')
eb = arm.data.edit_bones
pelvis, chest, root = eb['Pelvis'], eb['tripo::Spine_1'], eb['tripo::Root']


def add_chain(prefix_names, joints, parent, connect_first=False):
    prev = parent
    out = []
    for k, nm in enumerate(prefix_names):
        b = eb.new(nm)
        b.head, b.tail = V(joints[k]), V(joints[k + 1])
        b.parent = prev
        b.use_connect = (k > 0) or connect_first
        prev = b
        out.append(b)
    return out


nb = add_chain(neck_names, neck_j, chest)
eb['Head'].parent = nb[-1]
eb['Head'].use_connect = False
tb = add_chain(tail_names, tail_j, pelvis)
for side in 'LR':
    pts = hind[side]
    prev = pelvis
    for k, (nm, a, b) in enumerate(leg_bones(side)):
        e = eb.new(nm)
        e.head, e.tail = V(pts[a]), V(pts[b])
        e.parent = prev
        e.use_connect = k > 0
        prev = e
for old in OLD_TAIL + OLD_NECK + OLD_HIND:
    eb.remove(eb[old])

# sockets (non-deforming)
sel_head = (rest[:, 0] > 0.22) & (rest[:, 0] < 0.45) & (abs(rest[:, 1]) < 0.1) & (rest[:, 2] > 0.6)
top = np.argsort(-rest[sel_head][:, 2])[:30]
crown = rest[sel_head][top].mean(0)
s_thr, cum_n = project(np.array([[0.345, 0.0, 0.42]]), np.array(neck_pts))
thr_bone = neck_names[min(int(s_thr[0] / (neck_L / NECK_N)), NECK_N - 1)]
sockets = [
    ('Socket_Breath', (0.425, 0.0, 0.565), (0.47, 0.0, 0.565), 'Head'),
    ('Socket_Weak_Throat', (0.345, 0.0, 0.42), (0.345, 0.0, 0.45), thr_bone),
    ('Socket_Weak_Crown', tuple(crown), (crown[0], crown[1], crown[2] + 0.03), 'Head'),
]
for side, sg in (('L', 1), ('R', -1)):
    sh = eb[f'Wing_{side}_Shoulder'].head
    p = (sh.x - 0.01, sh.y + sg * 0.01, sh.z + 0.015)
    sockets.append((f'Socket_Weak_WingRoot_{side}', p, (p[0], p[1], p[2] + 0.03), f'Wing_{side}_Shoulder'))
for nm, h, t, par in sockets:
    e = eb.new(nm)
    e.head, e.tail = V(h), V(t)
    e.parent = eb[par]
    e.use_connect = False

# IK targets: head at the end of the IK chain, same direction as the paw bone after it
paws = {
    'HL': ('HindLeg_L_Ankle', 'HindLeg_L_Foot', 3),
    'HR': ('HindLeg_R_Ankle', 'HindLeg_R_Foot', 3),
    'FL': ('tripo::0_Left_Limb_1', 'tripo::0_Left_Limb_2', 3),
    'FR': ('tripo::0_Right_Limb_0', 'tripo::0_Right_Limb_1', 3),
}
for key_, (eff, paw, cnt) in paws.items():
    e = eb.new(f'IK_Paw_{key_}')
    p = eb[paw]
    e.head, e.tail = p.head.copy(), p.tail.copy()
    e.roll = p.roll
    e.parent = root
    e.use_connect = False
mode('OBJECT')

# ------------------------------------------------------------------ write weights
for vg in list(body.vertex_groups):
    body.vertex_groups.remove(vg)
bone_names = {b.name for b in arm.data.bones}
keep = [n for n in names if n in bone_names]
vgs = {n: body.vertex_groups.new(name=n) for n in keep}
ki = [idx[n] for n in keep]
lost = W[:, [i for i, n in enumerate(names) if n not in bone_names]].sum()
for i in range(N):
    for n, gi in zip(keep, ki):
        w = W[i, gi]
        if w > 0:
            vgs[n].add([i], float(w), 'REPLACE')

# ------------------------------------------------------------------ IK constraints
for key_, (eff, paw, cnt) in paws.items():
    pb = arm.pose.bones[eff]
    c = pb.constraints.new('IK')
    c.target = arm
    c.subtarget = f'IK_Paw_{key_}'
    c.chain_count = cnt
    c.use_tail = True
    pw = arm.pose.bones[paw]
    cr = pw.constraints.new('COPY_ROTATION')
    cr.target = arm
    cr.subtarget = f'IK_Paw_{key_}'
    cr.target_space = 'WORLD'
    cr.owner_space = 'WORLD'

# ------------------------------------------------------------------ after
def a_tail(): [rot(b, 'Z', 6) for b in tail_names]
def a_neckdown(): [rot(b, 'Y', 5) for b in neck_names]
def a_neckside(): [rot(b, 'Z', 35 / 8) for b in neck_names]
def a_jaw(): rot('Jaw', 'Y', 25)
def a_tailup(): [rot(b, 'Y', -5) for b in tail_names]
def a_hindlift(): move('IK_Paw_HL', (0.0, 0.0, 0.06)); move('IK_Paw_HR', (0.03, 0.0, 0.0))
def a_hindback(): move('IK_Paw_HL', (-0.04, 0.0, 0.03)); move('IK_Paw_HR', (0.0, 0.0, 0.04))
def a_frontlift(): move('IK_Paw_FL', (0.0, 0.0, 0.06)); move('IK_Paw_FR', (0.04, 0.0, 0.03))
def a_hindfk():
    cons = [c for s in 'LR' for c in arm.pose.bones[f'HindLeg_{s}_Ankle'].constraints if c.type == 'IK']
    for c in cons: c.mute = True
    bpy.context.view_layer.update()
    [rot(f'HindLeg_{s}_{b}', 'Y', d) for s in 'LR' for b, d in (('Hip', -20), ('Knee', 35), ('Ankle', -20))]
def a_unmute():
    for s in 'LR':
        for c in arm.pose.bones[f'HindLeg_{s}_Ankle'].constraints:
            if c.type == 'IK': c.mute = False
after = {'tail_curl_72': measure(a_tail), 'neck_down_40': measure(a_neckdown), 'neck_side_35': measure(a_neckside),
         'jaw_open_25': measure(a_jaw), 'tail_up_60': measure(a_tailup), 'hind_ik_lift': measure(a_hindlift),
         'hind_ik_back': measure(a_hindback), 'front_ik_lift': measure(a_frontlift), 'hind_fk_flex': measure(a_hindfk)}
a_unmute()
rest_eval = verts()
COMPACT = {k: (v['max'], v['bad'], v['moved']) for k, v in after.items() if k.startswith('hind')}
print('NECK_SIG', globals().get('NECK_SIG', 0.5), 'TAIL_SIG', globals().get('TAIL_SIG', 0.5), COMPACT)
if not globals().get('QUIET', False):
    print(json.dumps({'n_neck_verts': n_neck, 'n_tail_verts': n_tail, 'legs': n_leg, 'weight_lost_to_missing_groups': round(float(lost), 3),
                      'rest_drift_max': round(float(np.abs(rest_eval - rest).max()), 5),
                      'sockets': {s[0]: [round(float(x), 3) for x in s[1]] + [s[3]] for s in sockets}, 'throat_bone': thr_bone,
                      'bones': len(arm.data.bones), 'groups': len(body.vertex_groups), 'before': before, 'after': after}, indent=1))
    if globals().get("SAVE", True):
        bpy.ops.wm.save_as_mainfile(filepath=OUT + "/vyrath_rig_v3.blend")
