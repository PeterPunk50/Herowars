"""V59: Valkyra's own capture set (valkyra_*), retargeted from the Quaternius UAL clips onto her arms-down R15 rig.
usage: python3 -I build_valkyra_hero_captures.py <out fragment.luau>
Uses rigging-src/tools/ual_retarget.py and mocap_preview.py (same pipeline as build_valkyra_captures.py, which made V52's bulwark_* set).
Capture names follow the client's rule: lower(hero) .. "_" .. lower(Sig.alias(move)); Valkyra's aliases are
JavelinOfLight=Lightning, ValkyrieDive=Pounce, WingedRush=Charge, SkyToss=Throw (so the generic pose keys are her fallback)."""
import sys, os, json
TOOLS = os.path.expanduser('~/Documents/Claude/HeroWars/rigging-src/tools'); sys.path.insert(0, TOOLS)
argv = sys.argv; sys.argv = sys.argv[:1]
import mocap_preview as mp
import ual_retarget as ur
sys.argv = argv
Q = os.path.join(TOOLS, '..', 'quaternius')
UAL1 = os.path.join(Q, 'ual1', 'Animation Library[Standard]', 'Godot', 'AnimationLibrary_Godot_Standard.glb')
UAL2 = os.path.join(Q, 'ual2', 'Universal Animation Library 2[Standard]', 'Unreal-Godot', 'UAL2_Standard.glb')
RIG = os.path.join(TOOLS, '..', 'skins', 'valkyra', 'HW_valkyra_native_R15.fbx')
H = 'hybrid'
CHOSEN = [
    ('valkyra_idle',           2, 'Idle_Shield_Loop',  dict(loop=True, ground=H)),
    ('valkyra_run',            1, 'Jog_Fwd_Loop',      dict(loop=True, ground=H)),
    ('valkyra_light1',         2, 'Sword_Regular_A',   dict(ground=H)),                                   # Spear Jab
    ('valkyra_light2',         2, 'Sword_Regular_B',   dict(ground=H)),                                   # Shield Bash
    ('valkyra_light3',         2, 'Sword_Regular_C',   dict(t1=1.0, hit_t=0.42, ground=H)),                                   # Rising Wing
    ('valkyra_heavy',          2, 'Sword_Dash',        dict(ground=H)),                                   # Valhalla Thrust: lunging thrust
    ('valkyra_lightning',      2, 'OverhandThrow',     dict(t0=0.12, hit_t=0.67, ground=H)),              # right (spear) hand, released at the hit
    ('valkyra_pounce',         2, 'Sword_Heavy_Combo', dict(t0=2.17, t1=3.50, hit_t=2.67, ground=H)),     # leap and drive down
    ('valkyra_charge',         2, 'Shield_Dash',       dict(hit_t=0.30, ground=H)),                        # low wing-boosted dash, shield first
    ('valkyra_throw',          2, 'Melee_Hook',        dict(ground=H)),                                   # grab and fling up
    ('valkyra_guard',          2, 'Sword_Block',       dict(mirror=True, t0=0.18, t1=0.70, speed=0.5, loop=True, pingpong=True, hit='none', ground=H)),
]


def main():
    out = sys.argv[1]
    rig = mp.load_rig(RIG); libs = {1: ur.Library(UAL1, ur.BONES_UAL1), 2: ur.Library(UAL2, ur.BONES_UAL2)}
    lines, report = [], []
    for name, lib, clip, opt in CHOSEN:
        s, info = libs[lib].capture(rig, clip, **opt); lines.append('%s="%s"' % (name, s)); info['name'] = name; report.append(info)
        print('%-24s %-20s %.2fs  %3d frames  hit=%s (%.2fs)' % (name, clip, info['duration'], info['frames'], info['hit'], info['hit_time'] or -1))
    open(out, 'w').write('\n'.join(lines) + '\n'); json.dump(report, open(out + '.json', 'w'), indent=1)


if __name__ == '__main__': main()
