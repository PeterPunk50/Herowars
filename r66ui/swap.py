# R66-ui: swap script sources into a place by class + referent (never first-name match). Usage: python3 swap.py base.rbxlx out.rbxlx
import sys,os,html,re
here=os.path.dirname(os.path.abspath(__file__))
s=open(sys.argv[1],encoding='utf-8').read()
JOBS=[('LocalScript','10','HeroWarsClient__10.luau'),('Script','7','Main__7.luau')]
def esc(t): return t.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
for cls,ref,fn in JOBS:
    i=s.index('<Item class="%s" referent="%s"'%(cls,ref))
    j=s.index('<ProtectedString name="Source">',i)+len('<ProtectedString name="Source">')
    k=s.index('</ProtectedString>',j)
    old=html.unescape(s[j:k].replace('<![CDATA[','').replace(']]>',''))
    new=open(os.path.join(here,'src',fn),encoding='utf-8').read()
    print(fn,'changed' if old!=new else 'same')
    s=s[:j]+esc(new)+s[k:]
open(sys.argv[2],'w',encoding='utf-8').write(s)
