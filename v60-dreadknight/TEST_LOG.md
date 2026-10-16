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
