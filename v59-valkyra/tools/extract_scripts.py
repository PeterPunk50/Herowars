"""Write every Script / LocalScript / ModuleScript in a place to <out>/<Service>/<...>/<Name>.<kind>.luau.
usage: python3 -I extract_scripts.py <place.rbxlx> <out dir>     (also writes <out>/SCRIPTS.tsv: path, class, file)"""
import os, sys, xml.etree.ElementTree as ET
place, out = sys.argv[1:3]
root = ET.parse(place).getroot()
KIND = {'Script': 'server', 'LocalScript': 'client', 'ModuleScript': 'module'}
def props(i): return {p.get('name'): p for p in i.find('Properties')}
def txt(e): return '' if e is None else ''.join(e.itertext())
rows = []
def walk(item, path):
    p = props(item); name = txt(p.get('Name')).strip(); here = path + [name]
    if item.get('class') in KIND:
        rel = os.path.join(*here[:-1], f"{name}.{KIND[item.get('class')]}.luau")
        os.makedirs(os.path.join(out, os.path.dirname(rel)), exist_ok=True)
        open(os.path.join(out, rel), 'w', encoding='utf8').write(txt(p.get('Source')))
        rows.append(('.'.join(here), item.get('class'), rel))
    for c in item.findall('Item'): walk(c, here)
for top in root.findall('Item'): walk(top, [])
open(os.path.join(out, 'SCRIPTS.tsv'), 'w').write(''.join('\t'.join(r) + '\n' for r in rows))
print(len(rows), 'scripts written to', out)
