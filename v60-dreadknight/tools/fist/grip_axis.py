"""V60b: from Varn's two-handed captures, the line through both palms (the sword's grip) in each hand's own frame.
usage: python3 -I grip_axis.py <rig.fbx> <captures.luau> name[,name...]
Frames: Roblox rig frame (mocap_preview), cm; a hand's 'own frame' = its rest orientation, i.e. the Roblox part's local axes."""
import sys, os, site; site.addsitedir(site.getusersitepackages())
sys.path.insert(0, os.path.expanduser('~/Documents/Claude/HeroWars/rigging-src/tools'))
argv = sys.argv; sys.argv = argv[:1]; import mocap_preview as mp; sys.argv = argv
import numpy as np
rig = mp.load_rig(argv[1]); mc = mp.load_mocap(argv[2])
def centroid(part):
    m = rig['parts'][part]; w = m['W'][:, mp.R15.index(part)]; return m['V'][w > 0.5].mean(0)
C = {h: centroid(h) for h in ('RightHand', 'LeftHand')}
print('rest centroids (cm, rig frame):', {h: C[h].round(2) for h in C}, 'wrist joints', {h: rig['joint'][h].round(2) for h in C})
def posed(q, ry):
    Rw, Pw = {}, {}
    for j in mp.R15:
        R = mp.quat(q[mp.R15.index(j)]); p = mp.PARENT[j]
        if p is None: Rw[j] = R; Pw[j] = rig['joint'][j] + np.array([0, ry / 0.034, 0])
        else: Rw[j] = Rw[p] @ R; Pw[j] = Pw[p] + Rw[p] @ (rig['joint'][j] - rig['joint'][p])
    return Rw, Pw
for name in argv[3].split(','):
    cap = mc[name]; dR, dL, dist = [], [], []
    for t in np.linspace(0, cap['t'][-1], 24):
        q, ry = mp.sample(cap, t); Rw, Pw = posed(q, ry)
        w = {h: (C[h] - rig['joint'][h]) @ Rw[h].T + Pw[h] for h in C}
        v = w['LeftHand'] - w['RightHand']; dist.append(np.linalg.norm(v))
        dR.append(Rw['RightHand'].T @ v / np.linalg.norm(v)); dL.append(Rw['LeftHand'].T @ -v / np.linalg.norm(v))
    dR, dL = np.array(dR), np.array(dL); mR, mL = dR.mean(0), dL.mean(0)
    print('%-24s palms %5.1f-%5.1f cm | R->L in RightHand frame %s (spread %.2f) | L->R in LeftHand frame %s (spread %.2f)' % (
        name, min(dist), max(dist), (mR / np.linalg.norm(mR)).round(2), np.linalg.norm(dR - mR / np.linalg.norm(mR), axis=1).mean(),
        (mL / np.linalg.norm(mL)).round(2), np.linalg.norm(dL - mL / np.linalg.norm(mL), axis=1).mean()))
