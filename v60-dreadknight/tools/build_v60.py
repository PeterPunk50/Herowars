"""V60: Dread Knight Varn becomes his own hero (Peter, 2026-10-16). V59 + his kit.
usage: python3 -I build_v60.py <V56.rbxlx> <out_pre.rbxlx> <valkyra shield kit place> [greatsword kit place]
Runs v59-valkyra/tools/build_v59.py with this branch's scripts (../src) and Valkyra's winged shield, then, with the
greatsword kit (a place holding Model "GreatswordKit" = MeshPart "Greatsword" + CFrameValue "HandOffset", its CFrame
relative to his RightHand), welds the sword into his rig (ReplicatedStorage.HeroWars.Rigs.VarnT) with "GreatswordWeld".
Then run build_game_place.py on out_pre to add the Vyrath boss and get V60."""
import os, re, sys, copy, subprocess, xml.etree.ElementTree as ET

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


tree = ET.parse(out); root = tree.getroot()
rigs = next(i for i in root.iter('Item') if i.get('class') == 'Folder' and name(i) == 'Rigs')
rig = next(i for i in rigs.findall('Item') if name(i) == 'VarnT')
hand = next(i for i in rig.iter('Item') if i.get('class') == 'MeshPart' and name(i) == 'RightHand')
for old in [i for i in rig.iter('Item') if name(i) == 'Greatsword']:
    next(p for p in rig.iter('Item') if old in p.findall('Item')).remove(old)
sroot = ET.parse(sword).getroot()
mp = next(i for i in sroot.iter('Item') if i.get('class') == 'MeshPart' and name(i) == 'Greatsword')
off = next(i for i in sroot.iter('Item') if i.get('class') == 'CFrameValue' and name(i) == 'HandOffset')
new = copy.deepcopy(mp)
for c in list(new.findall('Item')):
    if c.get('class') != 'SurfaceAppearance': new.remove(c)
p = props(new)
for k, v in (('Anchored', 'false'), ('CanCollide', 'false'), ('CanTouch', 'false'), ('CanQuery', 'false'), ('Massless', 'true')):
    if k in p: p[k].text = v
    else: e = ET.SubElement(new.find('Properties'), 'bool', {'name': k}); e.text = v
new.set('referent', 'RBXGreatswordV60')
# His Humanoid auto-scales (Body*Scale 0.034, from the cm FBX); a part with no OriginalSize gets shrunk by that factor
# when the character enters the workspace, so the sword carries OriginalSize = Size / scale like his body parts do.
hum = next(i for i in rig.findall('Item') if i.get('class') == 'Humanoid')
scale = {name(v): float(props(v)['Value'].text) for v in hum.findall('Item') if v.get('class') == 'NumberValue'}
size = props(new)['size']
osz = ET.SubElement(new, 'Item', {'class': 'Vector3Value', 'referent': 'RBXGreatswordOrigSizeV60'}); op = ET.SubElement(osz, 'Properties')
ET.SubElement(op, 'string', {'name': 'Name'}).text = 'OriginalSize'
ov = ET.SubElement(op, 'Vector3', {'name': 'Value'})
for k, s in (('X', 'BodyWidthScale'), ('Y', 'BodyHeightScale'), ('Z', 'BodyDepthScale')):
    ET.SubElement(ov, k).text = repr(float(size.find(k).text) / (scale.get(s) or 1))
weld =ET.SubElement(new, 'Item', {'class': 'Weld', 'referent': 'RBXGreatswordWeldV60'}); wp = ET.SubElement(weld, 'Properties')
ET.SubElement(wp, 'string', {'name': 'Name'}).text = 'GreatswordWeld'
ET.SubElement(wp, 'Ref', {'name': 'Part0'}).text = hand.get('referent')
ET.SubElement(wp, 'Ref', {'name': 'Part1'}).text = 'RBXGreatswordV60'
c0 = ET.SubElement(wp, 'CoordinateFrame', {'name': 'C0'})
for k in ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'):
    ET.SubElement(c0, k).text = props(off)['Value'].find(k).text
c1 = ET.SubElement(wp, 'CoordinateFrame', {'name': 'C1'})
for k, v in zip(('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'), '0 0 0 1 0 0 0 1 0 0 0 1'.split()):
    ET.SubElement(c1, k).text = v
rig.append(new)
keys = set(re.findall(r'<SharedString name="[^"]*">([^<]+)</SharedString>', ET.tostring(new, encoding='unicode')))
src_ss = {e.get('md5'): e for e in (sroot.find('SharedStrings') if sroot.find('SharedStrings') is not None else [])}
dst = root.find('SharedStrings')
if dst is None: dst = ET.SubElement(root, 'SharedStrings')
have = {e.get('md5') for e in dst}
for k in keys:
    if k not in have and k in src_ss: dst.append(copy.deepcopy(src_ss[k]))
tree.write(out, encoding='utf-8', xml_declaration=False)
print('greatsword welded into VarnT; wrote', out, os.path.getsize(out) // 1024, 'KB')
