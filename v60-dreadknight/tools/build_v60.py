"""V60: Dread Knight Varn becomes his own hero (Peter, 2026-10-16). V59 + his kit.
usage: python3 -I build_v60.py <V56.rbxlx> <out_pre.rbxlx> <valkyra shield kit place> [greatsword kit place]
Runs v59-valkyra/tools/build_v59.py with this branch's scripts (../src) and Valkyra's winged shield, then, with the
greatsword kit (a place holding Model "GreatswordKit" = MeshPart "Greatsword" + CFrameValue "HandOffset", its CFrame
relative to his RightHand), welds the sword into his rig (ReplicatedStorage.HeroWars.Rigs.VarnT) with "GreatswordWeld".
V60b: when the kit place also holds the imported fists (RightFist, LeftFist, RightHandRef, LeftHandRef from
rigging-src/varn_fist/make_fists.py), the fists go on his hands (claws hidden), the sword grows 1.3x and sits in the right
fist by ../captures/fists.json, and LeftGripFrame/LeftGripY tell the client where the left fist holds it.
Then run build_game_place.py on out_pre to add the Vyrath boss and get V60."""
import os, re, sys, copy, json, subprocess, xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
inp, out, shield = sys.argv[1:4]; sword = sys.argv[4] if len(sys.argv) > 4 else None
V59 = os.path.join(HERE, '..', '..', 'v59-valkyra', 'tools', 'build_v59.py')
# build_v59 reads ../src next to itself; point it at this branch's scripts by running a copy from here
src = open(V59, encoding='utf8').read().replace("SRC = os.path.join(HERE, '..', 'src')", "SRC = os.path.join(HERE, '..', 'src')  # (v60 copy: this branch's src)")
tmp = os.path.join(HERE, '_build_v59_for_v60.py'); open(tmp, 'w', encoding='utf8').write(src)
try:
    subprocess.run([sys.executable, '-I', tmp, inp, out, shield], check=True)
finally:
    os.remove(tmp)
if not sword:
    print('no greatsword kit given: VarnT keeps no weapon'); sys.exit(0)


def txt(e): return '' if e is None else ''.join(e.itertext())
def props(i): return {p.get('name'): p for p in i.find('Properties')}
def name(i): return txt(props(i).get('Name')).strip()


K = ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22')
SWORD_SCALE = 1.3          # V60b (Peter: "sword needs to be a little bigger"): 4.2 -> 5.46 studs
GRIP_R, GRIP_L = 0.20, 0.094  # where each fist sits on the sword, as a fraction of its length from the pommel end: the
                              # handle runs 0.085-0.255 (guard above it); the right fist under the guard, the left 0.58 below


def setcf(el, pos, cols):
    """CoordinateFrame element <- position + rotation given as its three columns (right, up, back)."""
    vals = list(pos) + [cols[j][i] for i in range(3) for j in range(3)]
    for k, v in zip(K, vals):
        (el.find(k) if el.find(k) is not None else ET.SubElement(el, k)).text = repr(float(v))


def sub(a, b): return [x - y for x, y in zip(a, b)]
def dot(a, b): return sum(x * y for x, y in zip(a, b))
def cross(a, b): return [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
def unit(a): m = dot(a, a) ** 0.5; return [x / m for x in a]
def frame(up, look):
    """columns (X, Y, Z) with Y = up and Z = look made perpendicular to it."""
    y = unit(up); z = unit(sub(look, [c * dot(look, y) for c in y])); return [cross(y, z), y, z]


tree = ET.parse(out); root = tree.getroot()
rigs = next(i for i in root.iter('Item') if i.get('class') == 'Folder' and name(i) == 'Rigs')
rig = next(i for i in rigs.findall('Item') if name(i) == 'VarnT')
parts = {name(i): i for i in rig.iter('Item') if i.get('class') == 'MeshPart'}
hand = parts['RightHand']
for old in [i for i in rig.iter('Item') if name(i) in ('Greatsword', 'RightFist', 'LeftFist', 'LeftGripFrame')]:
    next(p for p in rig.iter('Item') if old in p.findall('Item')).remove(old)
sroot = ET.parse(sword).getroot()
kit = {name(i): i for i in sroot.iter('Item') if i.get('class') == 'MeshPart'}
# His Humanoid auto-scales (Body*Scale 0.034, from the cm FBX); a part with no OriginalSize gets shrunk by that factor
# when the character enters the workspace, so every added part carries OriginalSize = Size / scale like his body parts do.
hum = next(i for i in rig.findall('Item') if i.get('class') == 'Humanoid')
scale = {name(v): float(props(v)['Value'].text) for v in hum.findall('Item') if v.get('class') == 'NumberValue'}
added = []


def add_part(src, ref, part0, c0pos, c0cols, weldname, grow=1.0):
    new = copy.deepcopy(src)
    for c in list(new.findall('Item')):
        if c.get('class') != 'SurfaceAppearance': new.remove(c)
    p = props(new)
    for k, v in (('Anchored', 'false'), ('CanCollide', 'false'), ('CanTouch', 'false'), ('CanQuery', 'false'), ('Massless', 'true')):
        if k in p: p[k].text = v
        else: e = ET.SubElement(new.find('Properties'), 'bool', {'name': k}); e.text = v
    size = p['size']
    for k in 'XYZ': size.find(k).text = repr(float(size.find(k).text) * grow)
    new.set('referent', ref)
    osz = ET.SubElement(new, 'Item', {'class': 'Vector3Value', 'referent': ref + 'OS'}); op = ET.SubElement(osz, 'Properties')
    ET.SubElement(op, 'string', {'name': 'Name'}).text = 'OriginalSize'
    ov = ET.SubElement(op, 'Vector3', {'name': 'Value'})
    for k, s in (('X', 'BodyWidthScale'), ('Y', 'BodyHeightScale'), ('Z', 'BodyDepthScale')):
        ET.SubElement(ov, k).text = repr(float(size.find(k).text) / (scale.get(s) or 1))
    weld = ET.SubElement(new, 'Item', {'class': 'Weld', 'referent': ref + 'W'}); wp = ET.SubElement(weld, 'Properties')
    ET.SubElement(wp, 'string', {'name': 'Name'}).text = weldname
    ET.SubElement(wp, 'Ref', {'name': 'Part0'}).text = part0.get('referent')
    ET.SubElement(wp, 'Ref', {'name': 'Part1'}).text = ref
    setcf(ET.SubElement(wp, 'CoordinateFrame', {'name': 'C0'}), c0pos, c0cols)
    setcf(ET.SubElement(wp, 'CoordinateFrame', {'name': 'C1'}), (0, 0, 0), [[1, 0, 0], [0, 1, 0], [0, 0, 1]])
    rig.append(new); added.append(new)
    return new


def cfpos(i): v = props(i)['CFrame']; return [float(v.find(k).text) for k in 'XYZ']


I3 = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
fists = 'RightFist' in kit
if fists:
    # V60b (Peter: "hand grip sword grip wrong not in a fist"): Blender-curled fists (rigging-src/varn_fist/make_fists.py),
    # welded where they were modelled (offset from the untouched reference hand imported with them); the open claws hide.
    J = json.load(open(os.path.join(HERE, '..', 'captures', 'fists.json')))
    for side in ('Right', 'Left'):
        h = parts[side + 'Hand']
        f = add_part(kit[side + 'Fist'], 'RBX%sFistV60' % side, h, sub(cfpos(kit[side + 'Fist']), cfpos(kit[side + 'HandRef'])), I3, side + 'FistWeld')
        fp, hp = props(f), props(h)
        for k in ('TextureID', 'Color3uint8', 'Material'):                 # same look as his hands (the import made its own texture copy)
            if k in hp:
                if k in fp: f.find('Properties').remove(fp[k])
                f.find('Properties').append(copy.deepcopy(hp[k]))
        hp['Transparency'].text = '1'
    R, Lf = J['RightHand'], J['LeftHand']
    L = 4.2 * SWORD_SCALE; yR = (GRIP_R - 0.5) * L; yL = (GRIP_L - 0.5) * L
    # the sword's +Y (blade) leaves the right fist on its thumb side (grip_axis points at the pommel), its edges (Z) run
    # along the knuckles, so its flat (X) faces the palm
    cols = frame([-x for x in R['grip_axis']], R['fingers'])
    c0pos = [g - c * yR for g, c in zip(R['grip_point'], cols[1])]
else:
    off = props(next(i for i in sroot.iter('Item') if i.get('class') == 'CFrameValue' and name(i) == 'HandOffset'))['Value']
    vals = [float(off.find(k).text) for k in K]; c0pos = vals[:3]; cols = [[vals[3], vals[6], vals[9]], [vals[4], vals[7], vals[10]], [vals[5], vals[8], vals[11]]]
sw = add_part(kit['Greatsword'], 'RBXGreatswordV60', hand, c0pos, cols, 'GreatswordWeld', SWORD_SCALE if fists else 1.0)
if fists:
    # for the client's left-hand pin (Sig.twoHand): where on the sword the left fist goes (LeftGripY, sword space) and the
    # left fist's grip frame in LeftHand space (LeftGripFrame: Y along the handle toward the blade, Z along the knuckles)
    v = ET.SubElement(sw, 'Item', {'class': 'NumberValue', 'referent': 'RBXLeftGripYV60'}); vp = ET.SubElement(v, 'Properties')
    ET.SubElement(vp, 'string', {'name': 'Name'}).text = 'LeftGripY'; ET.SubElement(vp, 'double', {'name': 'Value'}).text = repr(yL)
    v = ET.SubElement(rig, 'Item', {'class': 'CFrameValue', 'referent': 'RBXLeftGripFrameV60'}); vp = ET.SubElement(v, 'Properties')
    ET.SubElement(vp, 'string', {'name': 'Name'}).text = 'LeftGripFrame'
    setcf(ET.SubElement(vp, 'CoordinateFrame', {'name': 'Value'}), Lf['grip_point'], frame(Lf['grip_axis'], Lf['fingers']))
keys = set()
for n in added: keys |= set(re.findall(r'<SharedString name="[^"]*">([^<]+)</SharedString>', ET.tostring(n, encoding='unicode')))
src_ss = {e.get('md5'): e for e in (sroot.find('SharedStrings') if sroot.find('SharedStrings') is not None else [])}
dst = root.find('SharedStrings')
if dst is None: dst = ET.SubElement(root, 'SharedStrings')
have = {e.get('md5') for e in dst}
for k in keys:
    if k not in have and k in src_ss: dst.append(copy.deepcopy(src_ss[k]))
tree.write(out, encoding='utf-8', xml_declaration=False)
print('VarnT: greatsword%s welded%s; wrote' % (' (x%.1f)' % SWORD_SCALE if fists else '', ', fists on both hands, claws hidden' if fists else ''), out, os.path.getsize(out) // 1024, 'KB')
