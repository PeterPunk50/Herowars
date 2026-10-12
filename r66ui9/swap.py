# R66-ui9: swap script sources into a place by class + referent (never first-name match), and add the BotAI
# ModuleScript next to Main if the place hasn't got it. Usage: python3 swap.py base.rbxlx out.rbxlx
import sys,os,html,uuid
here=os.path.dirname(os.path.abspath(__file__))
s=open(sys.argv[1],encoding='utf-8').read()
JOBS=[('LocalScript','10','HeroWarsClient__10.luau'),('Script','7','Main__7.luau'),('ModuleScript','3','Rules__3.luau')]
def esc(t): return t.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
def src(fn): return open(os.path.join(here,'src',fn),encoding='utf-8').read()
for cls,ref,fn in JOBS:
    i=s.index('<Item class="%s" referent="%s"'%(cls,ref))
    j=s.index('<ProtectedString name="Source">',i)+len('<ProtectedString name="Source">')
    k=s.index('</ProtectedString>',j)
    old=html.unescape(s[j:k].replace('<![CDATA[','').replace(']]>',''))
    new=src(fn)
    print(fn,'changed' if old!=new else 'same')
    s=s[:j]+esc(new)+s[k:]
REF='RBXBOTAI0001'
if 'referent="%s"'%REF in s:
    i=s.index('<Item class="ModuleScript" referent="%s"'%REF)
    j=s.index('<ProtectedString name="Source">',i)+len('<ProtectedString name="Source">')
    k=s.index('</ProtectedString>',j)
    s=s[:j]+esc(src('BotAI__BOTAI.luau'))+s[k:]; print('BotAI updated')
else:
    item=('<Item class="ModuleScript" referent="%s">\n        <Properties>\n          <ProtectedString name="Source">%s</ProtectedString>\n'
      '          <string name="ScriptGuid">{%s}</string>\n          <BinaryString name="AttributesSerialize">\n          </BinaryString>\n'
      '          <SecurityCapabilities name="Capabilities">0</SecurityCapabilities>\n          <bool name="DefinesCapabilities">false</bool>\n'
      '          <UniqueId name="HistoryId">00000000000000000000000000000000</UniqueId>\n          <string name="Name">BotAI</string>\n'
      '          <BinaryString name="SerializedOverrides">\n          </BinaryString>\n          <int64 name="SourceAssetId">-1</int64>\n'
      '          <UniqueId name="UniqueId">%s</UniqueId>\n        </Properties>\n      </Item>\n      ')%(REF,esc(src('BotAI__BOTAI.luau')),str(uuid.uuid4()).upper(),uuid.uuid4().hex)
    i=s.index('<Item class="Script" referent="7"')
    s=s[:i]+item+s[i:]; print('BotAI added')
open(sys.argv[2],'w',encoding='utf-8').write(s)
