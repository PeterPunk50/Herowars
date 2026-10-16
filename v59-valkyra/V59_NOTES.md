# HeroWars V59: Valkyra is her own hero (2026-10-16)

Peter: "valkyrie can rig her ... with her own shield and move different to bulwark". Chosen: her own hero slot, new
abilities, a new winged shield. Kit approved before building.

## What changed (all in `src/`, diff against the first commit on this branch = V56)

| Area | Change |
|---|---|
| Rules | `Characters.Valkyra` 110 HP, speed 17, dash 48, flies. `Defensives.Valkyra` Aegis Wings (Shield kind, 60% less damage 2 s, 18 s). New moves `JavelinOfLight` (40-stud line strike, grounds flyers), `ValkyrieDive` (`Pounce = true`: the Pounce leap/landing/splash code), `WingedRush` (16-stud lunge, `Untouchable` 18 ticks), `SkyToss` (throw + lift). `HeroMoves.Valkyra` Spear Jab / Shield Bash / Rising Wing / Valhalla Thrust. Skin set `Skins.Valkyra` (rig `ValkyraN`). `Rules.isPounce`, `Rules.isMelee` extended. `Rules.Display` cleared: Bulwark shows as Bulwark; Paladin is his first skin again. Bot heroes include Valkyra. |
| Main | `Rules.isPounce` replaces the six `name=="Pounce"` checks; `move.Untouchable`; Valkyra in spawn, preview and practice-dummy lists (spawn x 0: x +-22..30 has Cover blocks 12 studs out). |
| Client | Lobby tab, role and per-move help; hero sound set, reactions, trails; `Sig.ALIAS.Valkyra` maps her moves onto the generic pose keys (Lightning, Pounce, Charge, Throw), so her captures are `valkyra_lightning`, `valkyra_pounce`, `valkyra_charge`, `valkyra_throw`; captured idle and run loops; shield guard pose; Dive landing ring and Javelin aim line; hover and cruise flight poses; Bulwark's role text says "his shield" again. |
| PowerFX | Her gold light-and-feathers kit (javelin streak, dive pillar, rush streak, spear/shield combo flashes, Aegis Wings), wrapped around the shared functions. |
| FlightMotion | Valkyra flies (ground profile with the shield arm carried). |
| MocapData | `bulwark_*` back to his V51 knight set (V52 had given his slot her clips); 11 new `valkyra_*` from the Quaternius UAL (`tools/build_valkyra_hero_captures.py`, contact sheet `captures/VALKYRA_HERO_MOVES.png`). |

## Build

`tools/build_v59.py <V56> <out_pre> [shield.rbxmx]` writes the scripts back into V56 (and swaps her shield when the
shield file is given), then `tools/build_game_place.py <out_pre> <Vyrath test bed> boss <out> V59-valkyra` adds the
Vyrath boss as in V58. Place files: `~/Downloads/HeroWars_valkyra/` (not in git: 249 MB).

## Not done

- Sky Toss is defined but no hero has a throw button in this version (throws left the action bar earlier), so it is
  unused. It could go on her free Interrupt key (8).
- Numbers are first guesses; no PvP test against another player.

## Shield (done 2026-10-16)

The Tripo winged shield (mesh `rbxassetid://139531211590273`, colour/normal/metal-rough maps uploaded) is Valkyra's
`ShieldDisc` on her `ShieldWeld`, 1.9 studs tall. Its rest fit (the weld C0) was measured over her shield idle
(`tools/measure_idle_arm_client.luau`) and set on the kit (`tools/set_shield_fit.luau`):
`-0.4249 0.0166 -0.0669 0.98293 0.04404 -0.17861 0.16737 0.18874 0.96766 0.07633 -0.98104 0.17814`.
In guard the client now stands her shield upright in front of her chest, crest facing where she faces (the other
heroes keep the old turn). Play check (`tools/shield_check_client.luau`): rest crest forward 1.00, upright 1.00;
guard crest forward 1.00, upright 1.00, covering her from the lower torso to just above her head in the braced crouch.
