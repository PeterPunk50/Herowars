"""V59: Valkyra becomes her own hero; Bulwark is Bulwark again (Peter, 2026-10-16).
usage: python3 -I build_v59.py <V56.rbxlx> <out_pre.rbxlx> [shield.rbxmx]
Writes every script listed in ../src/SCRIPTS.tsv (the edited V56 scripts) back into the V56 place by its full path.
With shield.rbxmx (a Model holding one MeshPart named WingedShield plus a CFrameValue "ArmOffset" = the shield's
CFrame relative to LeftLowerArm), Valkyra's rig (ReplicatedStorage.HeroWars.Rigs.ValkyraN) gets that mesh in place
of her round ShieldDisc, on the same ShieldWeld, so guard, parry and the shield-raise code work unchanged.
Then run vyrath-redo/tools/build_game_place.py on out_pre to add the Vyrath boss (V58's step) and get V59."""
import os, re, sys, copy, xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__)); SRC = os.path.join(HERE, '..', 'src')
inp, out = sys.argv[1:3]; shield_path = sys.argv[3] if len(sys.argv) > 3 else None


def txt(e): return '' if e is None else ''.join(e.itertext())
def props(i): return {p.get('name'): p for p in i.find('Properties')}
def name(i): return txt(props(i).get('Name')).strip()


tree = ET.parse(inp); root = tree.getroot()
by_path = {}
def walk(item, path):
    here = path + [name(item)]; by_path.setdefault('.'.join(here), []).append(item)
    for c in item.findall('Item'): walk(c, here)
for top in root.findall('Item'): walk(top, [])

# ---- 1. scripts
n = 0
for line in open(os.path.join(SRC, 'SCRIPTS.tsv')):
    path, cls, rel = line.rstrip('\n').split('\t')
    items = [i for i in by_path.get(path, []) if i.get('class') == cls]
    assert len(items) == 1, (path, len(items))
    props(items[0])['Source'].text = open(os.path.join(SRC, rel), encoding='utf8').read(); n += 1
print('scripts replaced:', n)

# ---- 2. the winged shield on Valkyra's rig
if shield_path:
    rig = [i for i in by_path.get('ReplicatedStorage.HeroWars.Rigs.ValkyraN', []) if i.get('class') == 'Model']
    assert len(rig) == 1, 'ValkyraN rig not found'
    rig = rig[0]
    disc = next(i for i in rig.iter('Item') if i.get('class') == 'MeshPart' and name(i) == 'ShieldDisc')
    weld = next(c for c in disc.findall('Item') if c.get('class') == 'Weld' and name(c) == 'ShieldWeld')
    sroot = ET.parse(shield_path).getroot()
    mp = next(i for i in sroot.iter('Item') if i.get('class') == 'MeshPart' and name(i) == 'WingedShield')
    off = next(i for i in sroot.iter('Item') if i.get('class') == 'CFrameValue' and name(i) == 'ArmOffset')
    new = copy.deepcopy(mp)
    for c in list(new.findall('Item')):            # keep the mesh's own SurfaceAppearance, drop anything else
        if c.get('class') != 'SurfaceAppearance': new.remove(c)
    p = props(new); p['Name'].text = 'ShieldDisc'
    for k, v in (('Anchored', 'false'), ('CanCollide', 'false'), ('CanTouch', 'false'), ('CanQuery', 'false'), ('Massless', 'true')):
        if k in p: p[k].text = v
        else: e = ET.SubElement(new.find('Properties'), 'bool', {'name': k}); e.text = v
    new.set('referent', disc.get('referent'))      # the weld's Part1 and anything else pointing at ShieldDisc stay valid
    wc0 = props(weld)['C0']; oc = props(off)['Value']
    for k in ('X', 'Y', 'Z', 'R00', 'R01', 'R02', 'R10', 'R11', 'R12', 'R20', 'R21', 'R22'):
        wc0.find(k).text = oc.find(k).text
    new.append(weld)
    parent = next(pp for pp in rig.iter('Item') if disc in pp.findall('Item'))
    idx = list(parent).index(disc); parent.remove(disc); parent.insert(idx, new)
    # shared strings the shield mesh references (mesh data, physics) come from the shield file
    keys = set(re.findall(r'<SharedString name="[^"]*">([^<]+)</SharedString>', ET.tostring(new, encoding='unicode')))
    src_ss = {e.get('md5'): e for e in (sroot.find('SharedStrings') if sroot.find('SharedStrings') is not None else [])}
    dst = root.find('SharedStrings')
    if dst is None: dst = ET.SubElement(root, 'SharedStrings')
    have = {e.get('md5') for e in dst}
    for k in keys:
        if k not in have and k in src_ss: dst.append(copy.deepcopy(src_ss[k]))
    print('winged shield on ValkyraN, shared strings copied:', len([k for k in keys if k not in have]))

tree.write(out, encoding='utf-8', xml_declaration=False)
print('wrote', out, os.path.getsize(out) // 1024, 'KB')
