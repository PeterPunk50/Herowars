# V57: Vyrath, the Storm-Crowned Dragon (raid boss), 2026-10-15

A four-legged, two-winged dragon raid boss joins the V48-V56 line of HeroWars (Claude's line, built on V47 R66-ui8).
The place file (`HeroWars_V57_Vyrath.rbxlx`, 249 MB) is too big for GitHub; it lives in `~/Documents/Claude/HeroWars/` on Peter's Mac
(read-only copy in `originals/`). Everything that made it is here.

- `boss/Boss.luau` the controller: no Humanoid, plays 19 clips through an AnimationController, moves with PivotTo at the
  clips' ground speeds and rate-limited turns, steers round blocks, state machine (idle, walk, charge, turn, roar, thunder
  breath, tail sweep, flinch, weak-point stagger, death), breath wedge with a mouth sight line and a ground telegraph, tail
  capsules, weak points on socket bones, stagger on a break, death that holds.
- `boss/BossData.luau` every number (frames, ranges, damage, HP 2000, weak points). First guesses.
- `boss/BossLink.luau` the HeroWars adapter (summon with B, hero attack boxes against the dragon's capsules, boss damage
  through the fighters' state with block, parry and invulnerability, pause).
- `boss/VyrathHud.client.luau` HP bar and B key. `BossHarness.server.luau` and `BossHud.client.luau` are the standalone
  test bed versions.
- `tools/build_v57_vyrath.py` builds V57 from V56 and the Studio test bed (`Vyrath_import.rbxlx`, the dragon model plus its
  clips as KeyframeSequences); patches Main at five exact anchors (see `src/Main_V56.luau` for the base).
- `blender/` the scripts that built the rig and keyed every clip in Blender 5.2 (from the Tripo quadruped rig), with the
  event frames and breath/tail hit data as json.
- `kit/` the pilot prompt, Codex's review, the rig and animation notes (`RIG_NOTES.md`, read this), what is left (`LATER.md`),
  and the contact sheets.

Tested in Studio Play on V57: B summons it; it charges 100 studs across the Park arena round the obstacles; three breaths
took Solarion 115 to 34; 73 Sun Jabs took it 2000 to 1648; no console errors. Not done: raid party and bots, tuning, death in
a real fight, publishing the clips as animation assets, sounds and effects, beams and lock-on moves hitting the dragon.
