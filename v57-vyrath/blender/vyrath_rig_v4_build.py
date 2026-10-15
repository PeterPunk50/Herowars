import bpy, math, json, os
import numpy as np
from mathutils import Matrix, Vector

SRC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_rig_v3.blend"
OUT = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
R_SH = globals().get('R_SH', 0.12)        # harmonic region radius around each wing shoulder (0 = off)
R_NK = globals().get('R_NK', 0.06)        # harmonic region radius at the neck base (0 = off)
R_PIT = globals().get('R_PIT', 0.0)       # extra region under the shoulder (0 = off)
ITERS = globals().get('ITERS', 300)
D4_ON = globals().get('D4_ON', True)
SAVE = globals().get('SAVE', True)
QUIET = globals().get('QUIET', True)
SIG_D4 = globals().get('SIG_D4', 0.03)

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
    reset()
    ab = np.abs(np.linalg.norm(v[edges[:, 0]] - v[edges[:, 1]], axis=1) - rest_len)
    return (round(float(ratio.max()), 2), int(bad.sum()), round(float(ab.max()) * 1000, 1))


neck = [f'Neck_{i + 1:02d}' for i in range(8)]
tail = [f'Tail_{i + 1:02d}' for i in range(12)]


LW, RW = 'Wing_L_', 'Wing_R_'


def sym(bone_suffix, axis, deg_l, deg_r=None):
    """Rotate the same wing bone on both sides; the right side mirrors the left."""
    return lambda: (rot(LW + bone_suffix, axis, deg_l), rot(RW + bone_suffix, axis, -deg_l if deg_r is None else deg_r))


def symZ(bone_suffix, deg):
    return lambda: (rot(LW + bone_suffix, 'Z', deg), rot(RW + bone_suffix, 'Z', -deg))


def combo(*fns):
    return lambda: [f() for f in fns]


def pose_sets(with_d4):
    train = {
        'wings_up30': sym('Shoulder', 'X', 30), 'wings_up55': sym('Shoulder', 'X', 55),
        'wings_down35': sym('Shoulder', 'X', -35), 'wings_fold35': symZ('Shoulder', 35), 'wings_fold70': symZ('Shoulder', 70),
        'wings_fwd30': symZ('Shoulder', -30), 'elbow25': symZ('Forearm', 25), 'arm_up25': sym('Arm', 'X', 25),
        'up30_fold35': combo(sym('Shoulder', 'X', 30), symZ('Shoulder', 35)),
        'down35_fwd20': combo(sym('Shoulder', 'X', -35), symZ('Shoulder', -20)),
        'fan_D1_D2_D3': combo(sym('D2_0', 'X', 15), sym('D3_0', 'X', 15), sym('D1_0', 'X', 10)),
        'neck_down40': lambda: [rot(b, 'Y', 5) for b in neck],
        'neck_side35': lambda: [rot(b, 'Z', 35 / 8) for b in neck],
        'front_ik_lift': lambda: (move('IK_Paw_FL', (0, 0, 0.06)), move('IK_Paw_FR', (0.04, 0, 0.03))),
        'up55_neck_down': combo(sym('Shoulder', 'X', 55), lambda: [rot(b, 'Y', 5) for b in neck]),
    }
    held = {
        'wings_up20': sym('Shoulder', 'X', 20), 'wings_up45': sym('Shoulder', 'X', 45), 'wings_fold50': symZ('Shoulder', 50),
        'wings_fwd15': symZ('Shoulder', -15), 'elbow40': symZ('Forearm', 40), 'D3_minus15': sym('D3_0', 'X', -15),
        'D2_25': sym('D2_0', 'X', 25), 'neck_down25': lambda: [rot(b, 'Y', 3.1) for b in neck],
        'up40_down_neck': combo(sym('Shoulder', 'X', 40), lambda: [rot(b, 'Z', 3) for b in neck]),
        'fold60_elbow20': combo(symZ('Shoulder', 60), symZ('Forearm', 20)),
    }
    if with_d4:
        train['fan_D4'] = combo(sym('D4_0', 'X', 15), sym('D2_0', 'X', 10))
        train['fan_all4'] = combo(sym('D1_0', 'X', 8), sym('D2_0', 'X', 8), sym('D3_0', 'X', 8), sym('D4_0', 'X', 8))
        held['D4_25'] = sym('D4_0', 'X', 25)
        held['D4_minus15'] = sym('D4_0', 'X', -15)
    return train, held


def tests(with_d4):
    train, held = pose_sets(with_d4)
    out = {}
    for k, f in list(train.items()) + list(held.items()):
        out[('T:' if k in train else 'H:') + k] = measure(f)
    return out


def totals(res):
    t = sum(v[1] for k, v in res.items() if k.startswith('T:'))
    h = sum(v[1] for k, v in res.items() if k.startswith('H:'))
    return {'train_bad': t, 'heldout_bad': h, 'worst_stretch': max(v[0] for v in res.values())}


before = tests(False)

# ---------------------------------------------------------------- 4th digit
names, W = get_W()
newn = []
if D4_ON:
    D4 = {'R': [(0.195, -0.200, 0.475), (0.155, -0.208, 0.405), (0.115, -0.225, 0.346)]}
    D4['L'] = [(x, -y, z) for x, y, z in D4['R']]
    mode('EDIT')
    eb = arm.data.edit_bones
    for s in 'LR':
        prev = eb[f'Wing_{s}_Forearm']
        for k in range(2):
            b = eb.new(f'Wing_{s}_D4_{k}')
            b.head = Vector(D4[s][k]); b.tail = Vector(D4[s][k + 1])
            b.parent = prev
            b.use_connect = k > 0
            prev = b
            newn.append(b.name)
    mode('OBJECT')
    names += newn
    W = np.hstack([W, np.zeros((N, len(newn)))])
    idx = {n: i for i, n in enumerate(names)}

    def seg_dist(P, a, b):
        a, b = np.array(a), np.array(b)
        ab = b - a
        t = np.clip(((P - a) @ ab) / (ab @ ab), 0, 1)
        return np.linalg.norm(P - (a + t[:, None] * ab), axis=1)

    B = {b.name: (np.array(b.head_local), np.array(b.tail_local)) for b in arm.data.bones}
    n_d4 = {}
    for s in 'LR':
        wing_groups = [n for n in names if n.startswith(f'Wing_{s}_') and '_D4_' not in n]
        # D4 only takes weight from the forearm and the digit bones, never from the shoulder or arm
        movable = [n for n in wing_groups if n.endswith('Forearm') or '_D' in n]
        mi = [idx[n] for n in movable]
        tw = W[:, mi].sum(1)
        selv = np.where(tw > 0.05)[0]
        s0, s1 = B[f'Wing_{s}_D4_0'], B[f'Wing_{s}_D4_1']
        t = np.array([seg_dist(rest[selv], *s0), seg_dist(rest[selv], *s1)])
        d4 = t.min(0)
        comp = [n for n in wing_groups if '_D' in n]
        dother = np.min(np.stack([seg_dist(rest[selv], *B[n]) for n in comp], 1), 1)
        sgm = 1 / (1 + np.exp(-(dother - d4) / SIG_D4))
        sgm[d4 > 0.1] = 0
        pick = t.argmin(0)
        for k in range(2):
            m = pick == k
            W[selv[m], idx[f'Wing_{s}_D4_{k}']] += tw[selv[m]] * sgm[m]
        for gi in mi:
            W[selv, gi] *= (1 - sgm)
        n_d4[s] = int((sgm > 0.5).sum())
else:
    idx = {n: i for i, n in enumerate(names)}
    n_d4 = {}


def write_weights(W):
    Wn = W.copy()
    drop = np.argsort(-Wn, axis=1)[:, 4:]
    np.put_along_axis(Wn, drop, 0, axis=1)
    Wn[Wn < 0.01] = 0
    Wn /= np.maximum(Wn.sum(1, keepdims=True), 1e-9)
    for vg in list(body.vertex_groups):
        body.vertex_groups.remove(vg)
    bone_names = {b.name for b in arm.data.bones}
    keep = [(n, i) for i, n in enumerate(names) if n in bone_names]
    vgs = {n: body.vertex_groups.new(name=n) for n, _ in keep}
    for i in range(N):
        for n, gi in keep:
            w = Wn[i, gi]
            if w > 0:
                vgs[n].add([i], float(w), 'REPLACE')
    return Wn


# merge duplicate-position vertices (UV seams) so the optimiser treats each position once
key = np.round(rest * 1e5).astype(np.int64)
_, first, inv = np.unique(key, axis=0, return_index=True, return_inverse=True)
inv = inv.reshape(-1)
M = inv.max() + 1
cnt_c = np.bincount(inv, minlength=M).astype(float)
Wc = np.zeros((M, W.shape[1]))
np.add.at(Wc, inv, W)
Wc /= cnt_c[:, None]
restc = rest[first]
ec = np.unique(np.sort(inv[edges], axis=1), axis=0)
ec = ec[ec[:, 0] != ec[:, 1]]
# ---- neck base: harmonic fill of the weights in a small central patch (it kept flipping between Neck_01 and Neck_03)
if globals().get('R_NK', 0.06) > 0:
    degc = np.bincount(ec.ravel(), minlength=M).astype(float)
    wing_cols0 = [i for i, n in enumerate(names) if n.startswith('Wing_')]
    nk = (np.linalg.norm(restc - np.array([0.29, 0.0, 0.38]), axis=1) < globals().get('R_NK', 0.06)) & (np.abs(restc[:, 1]) < 0.035) & (Wc[:, wing_cols0].sum(1) < 0.02)
    for _ in range(300):
        acc = np.zeros_like(Wc)
        np.add.at(acc, ec[:, 0], Wc[ec[:, 1]])
        np.add.at(acc, ec[:, 1], Wc[ec[:, 0]])
        Wn = Wc.copy()
        Wn[nk] = acc[nk] / np.maximum(degc[nk], 1)[:, None]
        Wc = Wn
    print('NECKFIX verts', int(nk.sum()))
W = Wc[inv]
W = write_weights(W)            # D4 weights now live in Blender so the poses below see them
Wc = np.zeros((M, W.shape[1])); np.add.at(Wc, inv, W); Wc /= cnt_c[:, None]

if globals().get('OPT', True):
    # ---- region: the whole wing membrane, the armpits and the neck base
    wing_cols = [i for i, n in enumerate(names) if n.startswith('Wing_')]
    reg = Wc[:, wing_cols].sum(1) > 0.02
    for sg in (1, -1):
        reg |= np.linalg.norm(restc - np.array([0.28, sg * 0.06, 0.33]), axis=1) < 0.15
    reg |= np.linalg.norm(restc - np.array([0.29, 0.0, 0.38]), axis=1) < 0.08
    Rr = np.where(reg)[0]
    Cc = np.where(Wc[Rr].max(0) > 0.005)[0]
    inR = np.zeros(M, bool); inR[Rr] = True
    sel_e = inR[ec[:, 0]] | inR[ec[:, 1]]
    Ea, Eb = ec[sel_e, 0], ec[sel_e, 1]
    l0 = np.maximum(np.linalg.norm(restc[Ea] - restc[Eb], axis=1), 1e-6)
    train, held = pose_sets(D4_ON)
    # ---- record bone transforms and the posed mesh for every training pose
    Mats, Vout = [], []
    bones_c = [arm.pose.bones[names[c]] for c in Cc]
    restmat = [arm.data.bones[names[c]].matrix_local.copy() for c in Cc]
    for pname, fn in train.items():
        reset(); fn()
        Ms = []
        for pb, rm in zip(bones_c, restmat):
            Ms.append(np.array(pb.matrix @ rm.inverted()))
        Mats.append(np.array(Ms))                      # (C,4,4)
        Vout.append(verts()[first])                    # (M,3) posed positions (current weights)
    reset()
    Mats = np.array(Mats); Vout = np.array(Vout)      # (P,C,4,4), (P,M,3)
    Pn = len(Mats)
    X = restc[Rr]
    Ppos = np.einsum('pcij,kj->pkci', Mats[:, :, :3, :3], X) + Mats[:, None, :, :3, 3]   # (P,K,C,3)
    Wr = Wc[np.ix_(Rr, Cc)].copy()
    W0r = Wr.copy()
    # check: skinning with the current weights must reproduce Blender's posed mesh
    chk = np.einsum('kc,pkci->pki', Wr / np.maximum(Wr.sum(1, keepdims=True), 1e-9), Ppos)
    skin_err = float(np.abs(chk - Vout[:, Rr]).max())

    def simplex(Y):
        U = -np.sort(-Y, axis=1)
        css = np.cumsum(U, axis=1) - 1
        ks = np.arange(1, Y.shape[1] + 1)
        cond = U - css / ks > 0
        rho = cond.sum(1)
        theta = css[np.arange(len(Y)), rho - 1] / rho
        return np.maximum(Y - theta[:, None], 0)

    LAM = globals().get('LAM', 0.2)
    mask = np.ones_like(Wr, bool)

    def evaluate(Wr_, need_grad=True):
        pos = np.einsum('kc,pkci->pki', Wr_, Ppos)
        Vf = Vout.copy()
        Vf[:, Rr] = pos
        d = Vf[:, Ea] - Vf[:, Eb]
        l = np.maximum(np.linalg.norm(d, axis=2), 1e-9)
        e = l / l0[None] - 1
        loss = float((e ** 2 + e ** 4).sum() / Pn + LAM * ((Wr_ - W0r) ** 2).sum())
        if not need_grad:
            return loss, None
        gd = ((2 * e + 4 * e ** 3) / l0[None] / l)[:, :, None] * d
        G = np.zeros_like(Vf)
        np.add.at(G, (np.arange(Pn)[:, None], Ea[None, :]), gd)
        np.add.at(G, (np.arange(Pn)[:, None], Eb[None, :]), -gd)
        grad = np.einsum('pki,pkci->kc', G[:, Rr], Ppos) / Pn + 2 * LAM * (Wr_ - W0r)
        return loss, grad

    def run(iters, mask):
        global Wr
        alpha = globals().get('ALPHA', 0.002)
        hist = []
        L0, g = evaluate(Wr)
        hist.append(round(L0, 3))
        for it in range(iters):
            g = g * mask
            D = -g / (np.linalg.norm(g, axis=1, keepdims=True) + 1e-9)   # every vertex moves the same distance, in its own best direction
            D = np.where(np.linalg.norm(g, axis=1, keepdims=True) > 1e-6, D, 0)
            ok = False
            for _ in range(10):
                Wt = simplex(np.where(mask, Wr + alpha * D, 0))
                Wt = np.where(mask, Wt, 0)
                Wt /= np.maximum(Wt.sum(1, keepdims=True), 1e-9)
                Lt, _ = evaluate(Wt, need_grad=False)
                if Lt < L0:
                    ok = True
                    break
                alpha *= 0.5
            if not ok:
                break
            Wr = Wt
            L0, g = evaluate(Wr)
            alpha = min(alpha * 1.3, 0.05)
            if it % 25 == 0:
                hist.append(round(L0, 3))
        hist.append(round(L0, 3))
        return hist

    h1 = run(globals().get('IT1', 300), mask)
    top4 = np.argsort(-Wr, axis=1)[:, :4]
    mask = np.zeros_like(Wr, bool)
    np.put_along_axis(mask, top4, True, axis=1)
    Wr = np.where(mask, Wr, 0); Wr /= np.maximum(Wr.sum(1, keepdims=True), 1e-9)
    h2 = run(globals().get('IT2', 100), mask)
    Wc[np.ix_(Rr, Cc)] = Wr
    W = Wc[inv]
    W = write_weights(W)
    print('OPT region', len(Rr), 'verts, bones', len(Cc), 'poses', Pn, 'skin_check_err', round(skin_err, 6), 'loss', h1, h2)

after = tests(D4_ON)
rest_drift = float(np.abs(verts() - rest).max())
print('PARAMS', dict(D4=D4_ON, OPT=globals().get('OPT', True), LAM=globals().get('LAM', 0.02)), 'drift', round(rest_drift, 5))
cmp_keys = [k for k in after if k in before]
print('BEFORE totals', totals({k: before[k] for k in cmp_keys}), 'AFTER totals', totals({k: after[k] for k in cmp_keys}))
print('PER-POSE', {k: (before[k], after[k]) for k in cmp_keys})
print('ABS', {k: (before[k][2], after[k][2]) for k in cmp_keys})
print('NEW', {k: after[k] for k in after if k not in before})
if SAVE:
    bpy.ops.wm.save_as_mainfile(filepath=OUT + "/vyrath_rig_v4.blend")
