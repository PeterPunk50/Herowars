"""Write an empty Vyrath test place: baseplate, a spawn pad 70 studs out, nothing else.
usage: python3 -I make_test_place.py <out.rbxlx>
The dragon is imported into it by hand in Studio (Import 3D), then set up with setup_vyrath.luau."""
import sys

out_path = sys.argv[1]
cf = lambda x, y, z: f'<CoordinateFrame name="CFrame"><X>{x}</X><Y>{y}</Y><Z>{z}</Z><R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12><R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>'
vec = lambda n, x, y, z: f'<Vector3 name="{n}"><X>{x}</X><Y>{y}</Y><Z>{z}</Z></Vector3>'
out = f'''<roblox version="4">
<Item class="Workspace" referent="RBXW0"><Properties><string name="Name">Workspace</string></Properties>
<Item class="Part" referent="RBXW1"><Properties><string name="Name">Baseplate</string>{cf(0,-10,0)}{vec("size",512,20,512)}<bool name="Anchored">true</bool><Color3uint8 name="Color3uint8">4284900966</Color3uint8></Properties></Item>
<Item class="SpawnLocation" referent="RBXW2"><Properties><string name="Name">SpawnLocation</string>{cf(0,0.5,70)}{vec("size",12,1,12)}<bool name="Anchored">true</bool><bool name="Neutral">true</bool><int name="Duration">0</int><Color3uint8 name="Color3uint8">4288914085</Color3uint8></Properties></Item>
</Item>
<Item class="ServerScriptService" referent="RBXW3"><Properties><string name="Name">ServerScriptService</string></Properties></Item>
<Item class="ServerStorage" referent="RBXW4"><Properties><string name="Name">ServerStorage</string></Properties></Item>
</roblox>
'''
open(out_path, 'w', encoding='utf8').write(out)
print('wrote', out_path, len(out), 'bytes')
