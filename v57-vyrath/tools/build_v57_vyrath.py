"""V57: Vyrath, the Storm-Crowned Dragon, joins HeroWars as a raid boss (Peter, 2026-10-15: "wire the boss into HeroWars").
Takes the V56 place, copies the dragon model and its 19 clips out of the Studio test bed, adds the boss modules and the
boss HUD, and patches Main so hero attacks hit the dragon, its breath and tail hurt fighters, B summons it, and Pause stops it.
usage: build_v57_vyrath.py <V56.rbxlx> <Vyrath_import.rbxlx (test bed)> <boss source dir> <out.rbxlx>"""
import sys, re, os, xml.etree.ElementTree as ET
inp, bed, bossdir, out = sys.argv[1:5]
def txt(e): return ''.join(e.itertext()).strip()
def props(i): return {p.get('name'): p for p in i.find('Properties')}
def named(root, cls, name):
    return next(i for i in root.iter('Item') if i.get('class') == cls and txt(props(i)['Name']) == name)

# ---- 1. pull the dragon and its clips out of the test bed by string scanning (the file is 258 MB; no full parse)
bedtxt = open(bed, encoding='utf-8').read()
tok = re.compile(r'<Item\b|</Item>')
stack, spans = [], []
for m in tok.finditer(bedtxt):
    if m.group(0) == '</Item>':
        start = stack.pop(); spans.append((start, m.end()))
    else:
        stack.append(m.start())
def item_named(name, cls):
    for a, b in spans:
        head = bedtxt[a:a + 400]
        if ('class="%s"' % cls) in head:
            nxt = bedtxt.find('<Item', a + 5, b)
            own = bedtxt[a:nxt if nxt != -1 else b]
            if '<string name="Name">%s</string>' % name in own: return bedtxt[a:b]
    raise SystemExit('not found in test bed: ' + name)
model_xml = item_named('Vyrath', 'Model')
saves_xml = item_named('RBX_ANIMSAVES', 'Model')
keys = set(re.findall(r'<SharedString name="[^"]*">([^<]+)</SharedString>', model_xml + saves_xml))
shared = {}
for m in re.finditer(r'<SharedString md5="([^"]+)">([^<]*)</SharedString>', bedtxt):
    if m.group(1) in keys: shared[m.group(1)] = m.group(2)
assert keys <= set(shared), 'shared strings missing: %s' % (keys - set(shared))
model = ET.fromstring(model_xml); saves = ET.fromstring(saves_xml)
clips = next(i for i in saves.findall('Item'))      # RBX_ANIMSAVES (Model) > Vyrath_all2 (ObjectValue, as the Animation Editor stores saves) > Armature|<clip> x19
props(clips)['Name'].text = 'Clips'
nclips = len([i for i in clips.findall('Item') if i.get('class') == 'KeyframeSequence'])
assert nclips == 19, nclips
# the model sits in Workspace of the test bed; in the game it lives in ServerStorage until summoned
props(model)['Name'].text = 'Vyrath'

# ---- 2. the V56 place
tree = ET.parse(inp); root = tree.getroot()
def service(cls): return next(i for i in root.findall('Item') if i.get('class') == cls)
def folder(name, ref):
    f = ET.Element('Item', {'class': 'Folder', 'referent': ref}); p = ET.SubElement(f, 'Properties')
    n = ET.SubElement(p, 'string', {'name': 'Name'}); n.text = name; return f
def script_item(cls, name, src, ref):
    it = ET.Element('Item', {'class': cls, 'referent': ref}); p = ET.SubElement(it, 'Properties')
    n = ET.SubElement(p, 'string', {'name': 'Name'}); n.text = name
    s = ET.SubElement(p, 'ProtectedString', {'name': 'Source'}); s.text = src
    if cls != 'ModuleScript':
        d = ET.SubElement(p, 'bool', {'name': 'Disabled'}); d.text = 'false'
    return it
ss = service('ServerStorage')
vb = folder('VyrathBoss', 'RBXVyrathBossStore'); vb.append(model); vb.append(clips); ss.append(vb)
parent = {c: p for p in root.iter() for c in p}
hw = parent[named(root, 'Script', 'Main')]  # ServerScriptService.HeroWars (holds Main and Appearance)
code = folder('VyrathBoss', 'RBXVyrathBossCode')
for name, fn in (('Boss', 'Boss.luau'), ('BossData', 'BossData.luau'), ('BossLink', 'BossLink.luau')):
    code.append(script_item('ModuleScript', name, open(os.path.join(bossdir, fn)).read(), 'RBXVyrath' + name))
hw.append(code)
sps = named(root, 'StarterPlayerScripts', 'StarterPlayerScripts')
sps.append(script_item('LocalScript', 'VyrathHud', open(os.path.join(bossdir, 'VyrathHud.client.luau')).read(), 'RBXVyrathHud'))
shared_el = root.find('SharedStrings')
if shared_el is None: shared_el = ET.SubElement(root, 'SharedStrings')
have = {e.get('md5') for e in shared_el}
for k, v in shared.items():
    if k not in have:
        e = ET.SubElement(shared_el, 'SharedString', {'md5': k}); e.text = v

# ---- 3. Main patches (exact anchors; each must occur once)
main = named(root, 'Script', 'Main'); ms = props(main)['Source']; t = ms.text
def patch(old, new):
    global t
    assert t.count(old) == 1, old[:60]
    t = t.replace(old, new)
patch('local foe=function(_s,_t) return true end\n',
      'local foe=function(_s,_t) return true end\n'
      '-- V57: the Vyrath raid boss (ServerScriptService.HeroWars.VyrathBoss). Set up once the locals below exist (before the tick loop).\n'
      'local bossLink=nil\n')
patch(' local box=toBox(center,size)\n for key,t in states do\n',
      ' local box=toBox(center,size)\n'
      ' if bossLink and bossLink.alive() then bossLink.tryHit(s,a,center,size) end -- V57: the dragon is a target too\n'
      ' for key,t in states do\n')
patch(' if action=="Leaderboard" then D.sendBoard(player); return end\n',
      ' if action=="Leaderboard" then D.sendBoard(player); return end\n'
      ' if action=="Boss" then if bossLink then bossLink.command(player,data) end; return end -- V57: B summons or dismisses Vyrath\n')
patch('local validActions={Vote=true,', 'local validActions={Boss=true,Vote=true,')
patch('RunService.Heartbeat:Connect(function(dt)\n if paused then accumulator=0; return end',
      'bossLink=require(script.Parent.VyrathBoss.BossLink)\n'
      'bossLink.init({states=states,alive=alive,remote=remote,notify=notify,tick=function() return tick end,paused=function() return paused end,\n'
      ' fury=Rules.Fury,super=Rules.Super,endInvisible=function(s) endInvisible(s) end})\n'
      'RunService.Heartbeat:Connect(function(dt)\n if paused then accumulator=0; return end')
ms.text = t
# version label on the client HUD
cl = named(root, 'LocalScript', 'HeroWarsClient'); cs = props(cl)['Source']; c = cs.text
if c.count('R66-ui8 •') == 1: cs.text = c.replace('R66-ui8 •', 'V57-vyrath •')
tree.write(out, encoding='utf-8', xml_declaration=False)
print('wrote', out, os.path.getsize(out) // 1048576, 'MB; clips', nclips, 'shared strings copied', len(shared))
