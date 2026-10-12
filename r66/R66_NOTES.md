# R66 (2026-10-12, base R65e)

Peter: "A How to Play card for phone and PC. It shows on first join and stays in MENU after that. And a 60-90 second guided first fight against the bot. Design and do a video."

This is from the onboarding audit (knowledge/HeroWars/ONBOARDING_AUDIT_R64.md), items 2 and 4.

## How to Play card (client)
- **What it shows:** your device's controls, with your own keys and your hero's move names. There are six rows: move, target, attack, skills, defence and MENU.
- **Phone version:** the rows read stick / tap / ATTACK / round skill buttons / defence / MENU.
- **When it opens:**
  - by itself once, on first join, after the welcome screen and the lobby have closed and your fighter is standing;
  - again any time from MENU > **How to play** (a tile on phones).
- **Buttons:** START GUIDED FIGHT (it says GUIDED FIGHT AGAIN once you've finished it) and GOT IT.

## Guided fight (client + a little server)
- **Format:** up to 8 steps against the sparring bot.
  - One line at a time sits on the left (top-left on phones).
  - The button to press glows gold, and the bot gets a gold outline.
  - The next step starts as soon as you've done the current one.
  - SKIP ends it.
- **Starting it:** from the card, or from MENU > **Guided fight** (press it again to stop).

| # | Step | Done when |
|---|---|---|
| 1 | Walk up to the bot | within 14 studs |
| 2 | Target it (click / Tab / tap) | a target is set |
| 3 | ATTACK three times | 3 presses |
| 4 | Use each skill once | each skill pressed |
| 5 | Dodge (only heroes with a dash) | Dodge pressed |
| 6 | The bot swings at you: use Defensive (or Dodge) | pressed after the swing starts |
| 7 | The bot starts a cast: Interrupt it, or hit it (any hit stops a cast) | pressed after the cast starts |
| 8 | Finish it | bot KO (60 s limit) |

- **Step numbering:** counts only the steps your hero gets. Heroes with no dash have 7 steps.
- **Time limits:** a step never holds you longer than 30 s.
- **At the end:** confetti and a "GUIDED FIGHT COMPLETE • Hero in Training" banner, then the tip "Open MENU and press QUEUE".
- **Server action `Coach` (steps 6-7):**
  - The bot turns to you and swings, using its Light or Heavy.
  - Or it starts its first ready cast that does damage (for example Wraithstep's Grapple).
  - It only works when the bot isn't in a match, you aren't in a duel, and you're within 22 studs. At most once every 2.5 s per player.
- **Saved progress:** "seen the card" and "finished the guided fight" are kept in DataStore `HeroWarsProgress`, key `p_<UserId>`, through server actions `Progress` / `SaveProgress`. At most one write every 6 s.
  - In an unpublished place, or in Studio without API access, the card opens on every join. That's expected.

## Kept from R65e
- The walk code (R65d/e: PlayerModule for default WASD/arrows, `HW_Walk` for strafe and rebinds, `Sig.binds`) is unchanged.

## Files
- `HeroWars_V47_R66.rbxlx` is R65e's place with two scripts swapped in by class + referent:
  - the client (LocalScript 10);
  - Main (Script 7).
- `apply66.py` plus `patch_*.luau` re-apply R66 onto a fresh r65/src. Use this if R65 changes again.
- `HeroWars_R66_HowToPlay_GuidedFight_preview.mp4`, 90 s:
  - a mock-up made from Blender renders of the real arenas and the hero renders;
  - **not** recorded in Roblox Studio, because no thread can run or record Studio;
  - first the PC run (Solarion on Jungle Temples), then the phone run (Wraithstep on City Park).

## Checks
- All 11 scripts compile with `luau-compile --binary -O2 -g2` and print nothing on stderr. The new client code is in its own `;(function() ... end)()`.
- luau-analyze: no unknown globals other than Roblox's own.
- The place has 1111/1111 unique referents, Technology=4, and temples baked in (add_temples.py).
- The place has no Bodies or Avatars folders, the same as R65 (the R line doesn't use them).
- Not tested in Studio.
