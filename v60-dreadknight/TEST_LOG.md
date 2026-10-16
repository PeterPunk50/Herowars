# V60 test log (2026-10-16, Studio Play through the Studio MCP, V60_pre = V59 + Dread Knight, no dragon)

| Test | Result |
|---|---|
| Modules compile (Edit) | Rules, PowerFX, FlightMotion, MocapData load; buttons: Light Reaper's Cut (7), Heavy Doom Cleave (18), Skill1 Death Grip, Skill2 Soul Reaper, Skill3 Blight Ground, Interrupt Grave Strike; Super and Flight removed; Bulwark's skin list no longer has the Dread Knight; bot heroes include DreadKnight; 11 dreadknight_* captures |
| Spawn | rig VarnT, display "Dread Knight", 125/125 HP, no shield; console clean |
| Actions | server starts Light1, Light2, Light3, Heavy, DeathGrip, SoulReaper, BlightGround, Interrupt |
| Captures | Reaper's Cut 0.80 s clip, Doom Cleave 1.83 (Mixamo great-sword slash), Death Grip 0.50, Soul Reaper 2.20 (Mixamo jump attack), Blight Ground 3.53 (Mixamo power up, from 0.2 s), Grave Strike 0.87, guard 1.99; idle 1.67 (Sword_Idle) |
| Practice dummy (`hit_test.py`) | Death Grip from 25 studs pulled it to 3.5, 8 damage; Soul Reaper leapt 14 studs, 14 + drain ticks; Doom Cleave 18; Reaper's Cut 7; Grave Strike 4 |
| Blight Ground | zone up; burned the dummy 8 in 3 s; Reaper's Cut inside it about 9 (7 x 1.25) |

Not done: the greatsword is generated (Tripo, `~/Downloads/HeroWars_dreadknight/DreadKnight_Greatsword.glb`) but not imported:
Studio's Import 3D needs the screen and the Mac went to its lock screen. Cold-fire eyes and footprints are in the client
but have not been seen on screen (display capture needs the unlocked screen).

## V60b: fists, two-handed attacks, bigger sword (2026-10-16 evening)

Peter: "hand grip sword grip wrong not in a fist", "his rig need to be two handed sword attacks and sword needs to be a
little bigger".

- **Two-handed moves.** The Mixamo Great Sword Pack (51 clips, downloaded through Peter's Chrome sign-in) went through
  `tools/fbx_to_glb_batch_blender.py`, and `build_dreadknight_captures.py` now takes every move from it:
  - Idle: `gs_idle`.
  - Run: `gs_run_2`, the forward run (`gs_run` is the backward one, found by hip travel).
  - Reaper's Cut, Grave Slash and Bone Breaker: the three swings of the combo slash `gs_slash_2`, hits at 0.47, 1.6 and 3.0 s.
  - Doom Cleave: the downward slash `gs_slash_3`.
  - Death Grip: `spell_cast`.
  - Grave Strike: the hilt strike `gs_attack`.
  - Guard: `gs_blocking_2`.
  - Soul Reaper and Blight Ground: unchanged.

  Contact sheets were rendered to choose. MocapData was updated.
- **Fists.** `tools/fist/make_fists.py` (Blender, headless) curls both hands' claws around the grip line and exports
  `varn_fists.fbx`.
  - The grip line is measured by `tools/fist/grip_axis.py`: the line through both palms in the two-handed idle, right hand
    (-0.29,-0.48,0.82). The left fist uses the mirror, because the retarget twists that wrist.
  - Imported into `DreadKnight_sword_import.rbxlx` as RightFist, LeftFist, RightHandRef and LeftHandRef (uploaded,
    approved).
  - The reference hands came in at exactly his hand sizes, unrotated, so `captures/fists.json` offsets apply 1:1.
- **Build.** `build_v60.py` welds the fists to his hands and hides the open claws (Transparency 1; the client copies any
  fade to the fist).
  - The sword is 1.3× (5.46 studs) and sits in the right fist just under the guard.
  - LeftGripFrame and LeftGripY tell the client where the left fist holds the sword.
- **Client.** `Sig.twoHand`: after each frame's pose, a two-bone IK puts the left fist on the hilt (elbow kept on the
  captured side), except during Death Grip.
  - The retargeted palms drift up to about 30 cm apart in fast swings; in the idle they are 16 cm apart.
- **Play check (V60_pre, 2026-10-16 17:40-18:00).**
  - Sword 5.46 studs; both fists full size; open claws hidden (Transparency 1).
  - The left fist's grip point lands on the hilt at LeftGripY to within 0.00001 studs.
  - First pass: over 1,501 frames of combo and Doom Cleave, the left fist left the hilt in 10% of frames, every one because
    the hilt was beyond the left arm's reach (up to 1.45× arm length).
  - Fix: `Sig.twoHand` now pulls the sword and right arm in toward the left shoulder by the shortfall (`Sig.solveArm` for
    both arms). Rerun: 0 of 1,437 frames off the hilt.
  - Every move plays its new capture: Light 1.00 s, Doom Cleave 1.83 s, Death Grip 1.17 s, Soul Reaper 2.20 s,
    Blight Ground 3.53 s, Grave Strike 1.23 s, block 1.00 s.
  - Console clean. Screenshots: `~/Downloads/HeroWars_dreadknight/V60b_*.jpg`.
