
import bpy, math, json
import numpy as np
from mathutils import Matrix, Vector, kdtree

ORIG = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_before_fix.blend"
G = {}

def setup(reload=True):
    if reload:
        bpy.ops.wm.open_mainfile(filepath=ORIG)
    G['arm'] = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
    G['body'] = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
    me = G['body'].data
    G['N'] = len(me.vertices)
    G['edges'] = np.array([[e.vertices[0], e.vertices[1]] for e in me.edges])
    G['rest'] = np.array([v.co[:] for v in me.vertices])
    G['rest_len'] = np.maximum(np.linalg.norm(G['rest'][G['edges'][:, 0]] - G['rest'][G['edges'][:, 1]], axis=1), 1e-6)
    G['mid_y'] = (G['rest'][G['edges'][:, 0], 1] + G['rest'][G['edges'][:, 1], 1]) / 2
    names0, W0 = get_W()
    dom_names = [names0[i] for i in W0.argmax(1)]
    wing_names = {f'bone_{i}' for i in list(range(20, 26)) + list(range(32, 42))}
    fore_names = {'bone_26', 'bone_42', 'bone_43'} | {n for n in names0 if n.startswith('tripo::0_')}
    hind_names = {'bone_48', 'bone_49'} | {n for n in names0 if n.startswith('tripo::1_')}
    G['S'] = {k: np.array([i for i, n in enumerate(dom_names) if n in s]) for k, s in
              (('wing', wing_names), ('fore', fore_names), ('hind', hind_names))}
    G['NM'] = {'Lsh': 'bone_20', 'Rsh': 'bone_32', 'pelvis': 'bone_1', 'LD2': 'bone_38L', 'RD2': 'bone_38',
               'neck': ['bone_10', 'bone_11', 'tripo::Head_0', 'tripo::Head_1', 'tripo::Head_2']}


def get_W():
    body = G['body']; N = G['N']; me = body.data
    names = [g.name for g in body.vertex_groups]
    W = np.zeros((N, len(names)))
    for v in me.vertices:
        for g in v.groups:
            W[v.index, g.group] = g.weight
    return names, W


def rot(bone, axis, deg):
    arm = G['arm']
    if bone not in arm.pose.bones:
        return
    pb = arm.pose.bones[bone]
    m = pb.matrix.copy()
    head = m.translation.copy()
    R = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = R @ m
    bpy.context.view_layer.update()


def reset():
    for pb in G['arm'].pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def verts():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = G['body'].evaluated_get(dg)
    m = ev.to_mesh()
    a = np.array([v.co[:] for v in m.vertices])
    ev.to_mesh_clear()
    return a


def make_poses():
    NM = G['NM']
    return {
        'wings_up': lambda: (rot(NM['Lsh'], 'X', 55), rot(NM['Rsh'], 'X', -55)),
        'wings_fold': lambda: (rot(NM['Lsh'], 'Z', 70), rot(NM['Rsh'], 'Z', -70)),
        'hip_yaw': lambda: rot(NM['pelvis'], 'Z', 25),
        'hip_pitch': lambda: rot(NM['pelvis'], 'Y', 20),
        'neck_down': lambda: [rot(b, 'Y', 8) for b in NM['neck']],
        'digits': lambda: (rot(NM['LD2'], 'X', 25), rot(NM['RD2'], 'X', -25)),
    }


def suite():
    out = {}
    S, edges, rest, rest_len, mid_y = G['S'], G['edges'], G['rest'], G['rest_len'], G['mid_y']
    for name, fn in make_poses().items():
        reset(); fn()
        v = verts()
        ratio = np.linalg.norm(v[edges[:, 0]] - v[edges[:, 1]], axis=1) / rest_len
        bad = (ratio > 1.5) | (ratio < 0.5)
        disp = np.linalg.norm(v - rest, axis=1)
        out[name] = {'max': round(float(ratio.max()), 2), 'badL/R/C': [int((bad & (mid_y > 0.03)).sum()), int((bad & (mid_y < -0.03)).sum()), int((bad & (abs(mid_y) <= 0.03)).sum())],
                     'wing': round(float(disp[S['wing']].mean()), 3), 'fore': round(float(disp[S['fore']].mean()), 3), 'hind': round(float(disp[S['hind']].mean()), 3)}
    reset()
    return out

def fix(cfg):

    arm=G['arm']; body=G['body']; N=G['N']; edges=G['edges']; rest=G['rest']
    _vl = bpy.data.scenes[0].view_layers[0]
    _vl.objects.active = arm
    arm.select_set(True)
    def _mode(m):
        with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=_vl):
            bpy.ops.object.mode_set(mode=m)
    _mode('EDIT')
    eb = arm.data.edit_bones
    chest, pelvis = eb['tripo::Spine_1'], eb['bone_1']
    for n in ['bone_18', 'bone_19', 'bone_20', 'bone_26', 'bone_32', 'bone_42']:
        eb[n].parent = chest
        eb[n].use_connect = False
    for n in ['bone_48', 'bone_49', 'tripo::1_Left_Limb_0']:
        eb[n].parent = pelvis
        eb[n].use_connect = False
    eb['bone_34'].tail = eb['bone_35'].head.copy()


    def mirror_bone(src, new, parent):
        s = eb[src]
        b = eb.new(new)
        b.head = Vector((s.head.x, -s.head.y, s.head.z))
        b.tail = Vector((s.tail.x, -s.tail.y, s.tail.z))
        b.roll = -s.roll
        b.parent = parent
        b.use_connect = False
        return b


    b38 = mirror_bone('bone_38', 'bone_38L', eb['bone_22'])
    b39 = mirror_bone('bone_39', 'bone_39L', b38)
    b40 = mirror_bone('bone_40', 'bone_40L', eb['bone_22'])
    b41 = mirror_bone('bone_41', 'bone_41L', b40)
    _mode('OBJECT')

    # ---------------------------------------------------------------- weights
    names, W = get_W()
    names += ['bone_38L', 'bone_39L', 'bone_40L', 'bone_41L']
    W = np.hstack([W, np.zeros((N, 4))])
    idx = {n: i for i, n in enumerate(names)}
    dom = W.argmax(1)
    L_set = {f'bone_{i}' for i in range(20, 26)}
    R_set = {f'bone_{i}' for i in range(32, 42)}
    Lv = np.array([i for i in range(N) if names[dom[i]] in L_set])
    Rv = np.array([i for i in range(N) if names[dom[i]] in R_set])
    mapRL = {'bone_32': 'bone_20', 'bone_33': 'bone_21', 'bone_34': 'bone_22', 'bone_35': 'bone_23', 'bone_36': 'bone_24',
             'bone_37': 'bone_25', 'bone_38': 'bone_38L', 'bone_39': 'bone_39L', 'bone_40': 'bone_40L', 'bone_41': 'bone_41L',
             'bone_42': 'bone_26'}
    center = {'tripo::Root', 'bone_1', 'bone_2', 'tripo::Spine_0', 'tripo::Spine_1', 'bone_10', 'bone_11', 'bone_16', 'bone_18',
              'bone_19'} | {n for n in names if n.startswith('tripo::Tail_') or n.startswith('tripo::Head_')}
    kd = kdtree.KDTree(len(Rv))
    for k, i in enumerate(Rv):
        kd.insert(rest[i], k)
    kd.balance()
    copied = 0
    for i in Lv:
        p = rest[i].copy()
        p[1] = -p[1]
        co, k, dist = kd.find(p)
        j = Rv[k]
        row = np.zeros(len(names))
        for gi in np.nonzero(W[j])[0]:
            t = mapRL.get(names[gi], names[gi] if names[gi] in center else None)
            if t is not None:
                row[idx[t]] += W[j, gi]
        if row.sum() > 0:
            W[i] = row / row.sum()
            copied += 1

    # Tripo bound parts of the hind feet to the FRONT leg's toe bones; move those weights to the hind leg bones
    frontR = [idx[n] for n in ['bone_42', 'bone_43', 'tripo::0_Right_Limb_0', 'tripo::0_Right_Limb_1', 'tripo::0_Right_Limb_2', 'tripo::0_Right_Limb_3'] if n in idx]
    frontL = [idx[n] for n in ['bone_26', 'tripo::0_Left_Limb_0', 'tripo::0_Left_Limb_1', 'tripo::0_Left_Limb_2', 'tripo::0_Left_Limb_3', 'tripo::0_Left_Limb_4'] if n in idx]
    hindsel = (rest[:, 0] < 0.2) & (rest[:, 2] < 0.2)
    moved = {'R': 0, 'L': 0}
    if cfg.get('foot_fix', True):
        for i in np.where(hindsel)[0]:
            if rest[i, 1] < 0:
                w = sum(W[i, g] for g in frontR)
                if w > 0:
                    for g in frontR: W[i, g] = 0
                    W[i, idx['bone_48']] += w; moved['R'] += 1
            else:
                w = sum(W[i, g] for g in frontL)
                if w > 0:
                    for g in frontL: W[i, g] = 0
                    W[i, idx['tripo::1_Left_Limb_1']] += w; moved['L'] += 1
    print('hind-foot weights moved', moved)

    # merge vertices that share a position (UV seams) so smoothing cannot open cracks
    key = np.round(rest * 1e5).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    inv = inv.reshape(-1)
    M = inv.max() + 1
    cnt_c = np.bincount(inv, minlength=M).astype(float)
    Wc = np.zeros((M, W.shape[1]))
    np.add.at(Wc, inv, W)
    Wc /= cnt_c[:, None]
    restc = np.zeros((M, 3))
    np.add.at(restc, inv, rest)
    restc /= cnt_c[:, None]
    ec = np.unique(np.sort(inv[edges], axis=1), axis=0)
    ec = ec[ec[:, 0] != ec[:, 1]]
    d = np.minimum(np.linalg.norm(restc - np.array([0.28, 0.06, 0.33]), axis=1),
                   np.linalg.norm(restc - np.array([0.28, -0.06, 0.33]), axis=1))
    dh = np.linalg.norm(restc - np.array([0.10, 0.0, 0.24]), axis=1)
    def _smooth(Wc, region, iters, alpha):
        for _ in range(iters):
            acc = np.zeros_like(Wc); cnt = np.zeros(M)
            np.add.at(acc, ec[:, 0], Wc[ec[:, 1]]); np.add.at(acc, ec[:, 1], Wc[ec[:, 0]])
            np.add.at(cnt, ec[:, 0], 1); np.add.at(cnt, ec[:, 1], 1)
            avg = acc / np.maximum(cnt, 1)[:, None]
            Wn = Wc.copy(); Wn[region] = (1 - alpha) * Wc[region] + alpha * avg[region]; Wc = Wn
        return Wc
    Wc = _smooth(Wc, d < cfg['sh_r'], cfg['sh_iters'], cfg['alpha'])
    Wc = _smooth(Wc, dh < cfg['hip_r'], cfg['hip_iters'], cfg['alpha'])
    region = np.zeros(M, bool)
    for _ in range(0):
        acc = np.zeros_like(Wc)
        cnt = np.zeros(M)
        np.add.at(acc, ec[:, 0], Wc[ec[:, 1]])
        np.add.at(acc, ec[:, 1], Wc[ec[:, 0]])
        np.add.at(cnt, ec[:, 0], 1)
        np.add.at(cnt, ec[:, 1], 1)
        avg = acc / np.maximum(cnt, 1)[:, None]
        Wn = Wc.copy()
        Wn[region] = 0.5 * Wc[region] + 0.5 * avg[region]
        Wc = Wn
    W = Wc[inv]
    drop = np.argsort(-W, axis=1)[:, 4:]
    np.put_along_axis(W, drop, 0, axis=1)
    W[W < 0.01] = 0
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)

    for vg in list(body.vertex_groups):
        body.vertex_groups.remove(vg)
    vgs = [body.vertex_groups.new(name=n) for n in names]
    for i in range(N):
        for gi in np.nonzero(W[i])[0]:
            vgs[gi].add([i], float(W[i, gi]), 'REPLACE')

    # ---------------------------------------------------------------- names
    RENAME = {
        'bone_1': 'Pelvis',
        'bone_20': 'Wing_L_Shoulder', 'bone_21': 'Wing_L_Arm', 'bone_22': 'Wing_L_Forearm',
        'bone_23': 'Wing_L_D1_0', 'bone_24': 'Wing_L_D1_1', 'bone_25': 'Wing_L_D1_2',
        'bone_38L': 'Wing_L_D2_0', 'bone_39L': 'Wing_L_D2_1', 'bone_40L': 'Wing_L_D3_0', 'bone_41L': 'Wing_L_D3_1',
        'bone_32': 'Wing_R_Shoulder', 'bone_33': 'Wing_R_Arm', 'bone_34': 'Wing_R_Forearm',
        'bone_35': 'Wing_R_D1_0', 'bone_36': 'Wing_R_D1_1', 'bone_37': 'Wing_R_D1_2',
        'bone_38': 'Wing_R_D2_0', 'bone_39': 'Wing_R_D2_1', 'bone_40': 'Wing_R_D3_0', 'bone_41': 'Wing_R_D3_1',
    }
    for old, new in RENAME.items():
        arm.data.bones[old].name = new
    gnames = [g.name for g in body.vertex_groups]
    missing = [n for n in RENAME.values() if n not in gnames]
    for old, new in RENAME.items():  # rename groups by hand if Blender did not
        if old in gnames and new not in gnames:
            body.vertex_groups[old].name = new
    gnames = [g.name for g in body.vertex_groups]
    bone_names = {b.name for b in arm.data.bones}
    unmatched = sorted(set(gnames) - bone_names)

    G['NM'].update({'Lsh': 'Wing_L_Shoulder', 'Rsh': 'Wing_R_Shoulder', 'pelvis': 'Pelvis', 'LD2': 'Wing_L_D2_0', 'RD2': 'Wing_R_D2_0'})
    return {'copied': int(copied), 'unmatched_groups': unmatched}
