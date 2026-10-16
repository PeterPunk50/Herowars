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
    # V60b (Peter: "his rig need to be two handed sword attacks"): every move from the Mixamo Great Sword Pack, both hands on the hilt
    ('dreadknight_idle',        'gs_idle',   CLIP, dict(loop=True, ground=H)),                                   # two-handed ready stance
    ('dreadknight_run',         'gs_run_2',  CLIP, dict(loop=True, ground=H)),                                   # forward great-sword run (gs_run is the backward one)
    ('dreadknight_light1',      'gs_slash_2', CLIP, dict(t0=0.0, t1=1.25, speed=1.25, ground=H)),               # Reaper's Cut: combo swing 1
    ('dreadknight_light2',      'gs_slash_2', CLIP, dict(t0=1.25, t1=2.35, speed=1.25, hit_t=1.6, ground=H)),              # Grave Slash: combo swing 2, the low lunge
    ('dreadknight_light3',      'gs_slash_2', CLIP, dict(t0=2.35, t1=3.57, speed=1.2, hit_t=3.0, ground=H)),               # Bone Breaker: combo swing 3, spin and rising finish
    ('dreadknight_heavy',       'gs_slash_3', CLIP, dict(ground=H)),                                             # Doom Cleave: overhead downward cleave
    ('dreadknight_grapple',     'spell_cast', CLIP, dict(ground=H)),                                             # Death Grip: one hand thrust out, chains fly
    ('dreadknight_pounce',      'jump',      CLIP, dict(hit_t=1.12, ground=H)),                                  # Soul Reaper: great-sword jump attack
    ('dreadknight_slam',        'power',     CLIP, dict(hit_t=2.83, ground=H)),                                  # Blight Ground: great-sword power up
    ('dreadknight_gravestrike', 'gs_attack', CLIP, dict(ground=H)),                                              # Grave Strike (Interrupt): hilt strike
    ('dreadknight_guard',       'gs_blocking_2', CLIP, dict(loop=True, hit='none', ground=H)),                   # two-handed block, held
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


# V60b (Peter: "two handed sword attacks"): the whole Mixamo Great Sword Pack, converted by fbx_to_glb_batch_blender.py
GS = ['gs_idle', 'gs_idle_2', 'gs_idle_3', 'gs_idle_4', 'gs_idle_5', 'gs_walk', 'gs_walk_2', 'gs_run', 'gs_run_2', 'gs_slash', 'gs_slash_2',
      'gs_slash_3', 'gs_slash_4', 'gs_slash_5', 'gs_high_spin_attack', 'gs_kick', 'gs_kick_2', 'gs_blocking', 'gs_blocking_2', 'gs_blocking_3',
      'gs_casting', 'gs_attack', 'spell_cast']
CANDIDATES_GS = [('cand_' + g, g, CLIP, dict(ground=H, loop=g.startswith(('gs_idle', 'gs_walk', 'gs_run')))) for g in GS]


def lib_of(lib):
    if lib in LIBS: return LIBS[lib]
    return (os.path.join(MX, lib + '.glb'), BONES_MIXAMO)


def main():
    out = sys.argv[1]; extra = len(sys.argv) > 2
    rig = mp.load_rig(RIG); libs = {}
    lines, report = [], []
    for name, lib, clip, opt in ((CANDIDATES_GS if sys.argv[2] == 'gs' else CANDIDATES) if extra else CHOSEN):
        if lib not in libs: libs[lib] = ur.Library(*lib_of(lib))
        s, info = libs[lib].capture(rig, clip, **opt); lines.append('%s="%s"' % (name, s)); info['name'] = name; report.append(info)
        print('%-26s %-22s %.2fs  %3d frames  hit=%s (%.2fs)' % (name, clip[:22], info['duration'], info['frames'], info['hit'], info['hit_time'] or -1))
    open(out, 'w').write('\n'.join(lines) + '\n'); json.dump(report, open(out + '.json', 'w'), indent=1)


if __name__ == '__main__': main()
