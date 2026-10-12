# R66-ui10: Pyramid climbing and bot pathfinding (2026-10-12, base R66-ui9)

Peter asked for five things:
- check the pathfinding on the pyramids;
- give Bulwark a higher jump so he can get up the steps;
- let Wraithstep spider-climb automatically, with no button;
- let Bulwark pull himself up when his jump falls short;
- stop the high pyramid walls from giving flyers too much advantage.

**Build:** `HeroWars_V47_R66ui10.rbxlx`. Not play-tested yet.

## What I measured

I read HW_Temple2's collision boxes from the place file and scaled them the way the game does: 80 studs wide, which is ×0.142.
- **Pyramid tiers:** each tier is **3.8-4.1 studs high**, with only **about 1.7 studs of ledge** to land on.
- **Stairs:** the stairs side has **0.8-stud steps**, low enough to walk up without jumping. The easiest route to the top never needs more than a 1.7-stud step.
- **Top:** the top is 47 studs up. The little temple on top has walls of about 16 studs.
- **Jump height:** a normal jump (JumpPower 45) rises about 5.2 studs. That clears a tier on paper, but Bulwark is wide and slow, so landing on a 1.7-stud ledge was hit and miss. Without a pull-up he slid back down.

## Changes

| | |
|---|---|
| **Bulwark jump** | `Rules.Characters.Bulwark.JumpPower = 55`, about 7.7 studs, up from 5.2. The client and server both use the hero's JumpPower now. |
| **Bulwark ledge pull-up** | In the air while walking at a wall whose top is up to **3.5 studs above his feet**, he pulls himself up onto it (`Rules.Climb.Bulwark.Mantle`). A short jump at a tier now lands him on top. |
| **Wraithstep spider climb** | Walking into a wall climbs straight up it at 14 studs/s, with no button. At the top he pulls himself onto the ledge. Stop pushing and he drops. Stair steps don't trigger it: on the ground it only reacts to a wall at chest height. The arena's outer walls (`Boundary`) can't be climbed. |
| **Flyers vs the pyramid** | Bulwark and Wraithstep can now reach a flyer standing on the pyramid. The bot also flies up (Solarion and Tempest) or climbs or takes the stairs (Bulwark and Wraithstep) when you stand high on it. |
| **Bot pathfinding** | The bot walks straight at you and climbs like a player. When it is stuck for 0.75 s, or you are 5+ studs above or below it, it asks PathfindingService for a route (the stairs) and follows it, jumping where the path says. Routes are reused for 1.5 s and computed off the server tick. A bigger agent is used for Bulwark. The bot's `AI_State` shows "following a path". |
| **Bot jumps** | A bot walking into a wall it can get over (its jump height plus its pull-up reach) jumps. |
| **Anti-cheat** | The jump check allows the higher jump plus the pull-up (`D.jumpRise`), and doesn't snap back a Wraithstep who is on a wall. |

**New module:** `ReplicatedStorage.HeroWars.Climb` (`src/Climb__CLIMB.luau`). Your client runs it for your own fighter, and the server runs it for the sparring bot. All its settings are in `Rules.Climb`.

## Known limits

- **Not tested in Studio yet.**
- There is **no climbing animation**. Wraithstep rises in his falling pose.
- Wraithstep can climb the temple-house walls on top of the pyramid and the obstacles. Only the arena's outer walls are blocked.
- **The pull-up is a quick snap onto the ledge,** with no hand-over-hand animation.
- **The pathfinding only reads the collision boxes.** HW_Temple2's mesh parts (trees, decoration) may not match what PathfindingService builds. If the bot gets stuck somewhere specific, a screenshot and Output would help.

## Tests

- **Compile:** all 13 scripts pass `luau-compile --binary -O2 -g2` with nothing on stderr.
- **luau-analyze:** only Roblox globals and the same pre-existing type warnings as ui8.
- **Place:** XML parses, 1113/1113 unique referents, Technology 4, and all 5 changed sources round-trip exactly.
- **Script locations:** Climb sits in ReplicatedStorage/HeroWars and BotAI in ServerScriptService/HeroWars.
- **Bot AI sim:** still runs (`test/RESULTS.md`). The only change is the flyer scenario, where the bot now also flies up at a high enemy.

## Merge notes (for Codex)

- **Add ModuleScripts:** add `Climb` (referent `RBXCLIMB0001`) next to Rules, and BotAI if you haven't merged ui9. `swap.py` does both.
- **Diffs:** the diffs against ui9 are in `patch/R66ui9_to_ui10_*.diff`.
