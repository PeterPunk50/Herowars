"""V60: Dread Knight Varn's own capture set (dreadknight_*), retargeted onto his Tripo R15 rig (HW_varn_tripo_6k_R15.fbx)
from the Mixamo great-sword clips (converted to glb by fbx_to_glb_blender.py) and the Quaternius UAL libraries.
usage: python3 -I build_dreadknight_captures.py <out fragment.luau> [candidates]
Names follow the client rule lower(hero) .. "_" .. lower(Sig.alias(move)); his aliases: DeathGrip=Grapple, SoulReaper=Pounce,
BlightGround=Slam (so the generic pose keys are his fallback); Grave Strike (Interrupt) uses dreadknight_gravestrike."""
import sys, os, json
TOOLS = os.path.expanduser('~/Documents/Claude/HeroWars/rigging-src/tools'); sys.path.insert(0, TOOLS)
argv = sys.argv; sys.argv = sys.argv[:1]
import mocap_preview as mp
import ual_retarget as ur
sys.argv = argv
HERE = os.path.dirname(os.path.abspath(__file__)); Q = os.path.join(TOOLS, '..', 'quaternius'); MX = os.path.join(HERE, '..', 'captures', 'mixamo_glb')
UAL1 = os.path.join(Q, 'ual1', 'Animation Library[Standard]', 'Godot', 'AnimationLibrary_Godot_Standard.glb')
UAL2 = os.path.join(Q, 'ual2', 'Universal Animation Library 2[Standard]', 'Unreal-Godot', 'UAL2_Standard.glb')
RIG = os.path.join(TOOLS, '..', 'tripo_out', 'HW_varn_tripo_6k_R15.fbx')
M = 'mixamorig:'
BONES_MIXAMO = dict(LowerTorso=M+'Hips', UpperTorso=M+'Spine2', Head=M+'Head', LeftUpperArm=M+'LeftArm', LeftLowerArm=M+'LeftForeArm', LeftHand=M+'LeftHand',
                    RightUpperArm=M+'RightArm', RightLowerArm=M+'RightForeArm', RightHand=M+'RightHand', LeftUpperLeg=M+'LeftUpLeg', LeftLowerLeg=M+'LeftLeg',
                    LeftFoot=M+'LeftFoot', RightUpperLeg=M+'RightUpLeg', RightLowerLeg=M+'RightLeg', RightFoot=M+'RightFoot')
CLIP = 'Armature|mixamo.com|Layer0'
LIBS = {1: (UAL1, ur.BONES_UAL1), 2: (UAL2, ur.BONES_UAL2), 'slash': (os.path.join(MX, 'great_sword_slash.glb'), BONES_MIXAMO),
        'jump': (os.path.join(MX, 'great_sword_jump_attack.glb'), BONES_MIXAMO), 'power': (os.path.join(MX, 'great_sword_power_up.glb'), BONES_MIXAMO)}
H = 'hybrid'
CHOSEN = [
    ('dreadknight_idle',        1,       'Sword_Idle',         dict(loop=True, ground=H)),                         # hunched over the blade
    ('dreadknight_run',         1,       'Walk_Loop',          dict(loop=True, ground=H, speed=2.0)),              # heavy stride, sped to his pace
    ('dreadknight_light1',      1,       'Sword_Attack',       dict(t0=0.10, t1=0.90, ground=H)),                  # Reaper's Cut: lunging strike
    ('dreadknight_light2',      2,       'Sword_Heavy_Combo',  dict(t0=0.0, t1=1.20, ground=H)),                   # Grave Slash
    ('dreadknight_light3',      2,       'Sword_Heavy_Combo',  dict(t0=1.30, t1=2.30, hit_t=1.79, ground=H)),      # Bone Breaker
    ('dreadknight_heavy',       'slash', CLIP,                 dict(hit_t=0.63, ground=H)),                        # Doom Cleave: two-handed great-sword slash
    ('dreadknight_grapple',     1,       'Spell_Simple_Shoot', dict(hit_t=0.25, ground=H)),                        # Death Grip: thrusts the hand out, chains fly
    ('dreadknight_pounce',      'jump',  CLIP,                 dict(hit_t=1.12, ground=H)),                        # Soul Reaper: great-sword jump attack
    ('dreadknight_slam',        'power', CLIP,                 dict(hit_t=2.83, ground=H)),                        # Blight Ground: great-sword power up
    ('dreadknight_gravestrike', 1,       'Punch_Jab',          dict(ground=H)),                                     # Grave Strike (Interrupt)
    ('dreadknight_guard',       2,       'Sword_Block',        dict(t0=0.18, t1=0.70, speed=0.5, loop=True, pingpong=True, hit='none', ground=H)),
]
CANDIDATES = [
    ('cand_gs_slash',      'slash', CLIP,                dict(ground=H)),
    ('cand_gs_jump',       'jump',  CLIP,                dict(ground=H)),
    ('cand_gs_power',      'power', CLIP,                dict(ground=H)),
    ('cand_sword_idle',    1,       'Sword_Idle',        dict(loop=True, ground=H)),
    ('cand_sword_attack',  1,       'Sword_Attack',      dict(ground=H)),
    ('cand_heavy_combo',   2,       'Sword_Heavy_Combo', dict(ground=H)),
    ('cand_spell_shoot',   1,       'Spell_Simple_Shoot', dict(ground=H)),
    ('cand_punch_jab',     1,       'Punch_Jab',         dict(ground=H)),
    ('cand_walk_formal',   1,       'Walk_Formal_Loop',  dict(loop=True, ground=H)),
    ('cand_sword_block',   2,       'Sword_Block',       dict(ground=H)),
]


def main():
    out = sys.argv[1]; extra = len(sys.argv) > 2
    rig = mp.load_rig(RIG); libs = {}
    lines, report = [], []
    for name, lib, clip, opt in (CANDIDATES if extra else CHOSEN):
        if lib not in libs: libs[lib] = ur.Library(*LIBS[lib])
        s, info = libs[lib].capture(rig, clip, **opt); lines.append('%s="%s"' % (name, s)); info['name'] = name; report.append(info)
        print('%-26s %-22s %.2fs  %3d frames  hit=%s (%.2fs)' % (name, clip[:22], info['duration'], info['frames'], info['hit'], info['hit_time'] or -1))
    open(out, 'w').write('\n'.join(lines) + '\n'); json.dump(report, open(out + '.json', 'w'), indent=1)


if __name__ == '__main__': main()
