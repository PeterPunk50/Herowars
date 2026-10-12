# R66-ui9: Tactical bot AI (2026-10-12, base R66-ui8, built by Claude)

Peter asked for "Hero Wars: Bot AI Strategy & Priority System", applied to **only the four heroes we have now**: Bulwark, Tempest, Solarion and Wraithstep.

The goal: the sparring bot stops just chasing and swinging. Instead it reads what the player does, picks a tactic by priority, carries out combos, and changes approach. Easy, Normal and Hard differ in how well it does this, never in damage, health or speed.

**Build:** `HeroWars_V47_R66ui9.rbxlx`. It is R66-ui8 plus this change and has not been play-tested in Studio yet.

## What changed (change log)

| Where | Change |
|---|---|
| **New** `ServerScriptService/HeroWars/BotAI` (ModuleScript, `src/BotAI__BOTAI.luau`) | The AI itself: sensing, pattern memory, tactic checks, priority scoring, combo planner, movement (spacing, circling, baiting, evading, flight) and telemetry. |
| `Rules` (ModuleScript 3) | New `Rules.BotAI` data table: difficulty settings, priority scores and a strategy kit per hero. Nothing else in Rules changed. |
| `Main` (Script 7) | The old `botThink` (about 140 lines of hard-coded chances) is replaced by a 15-line wrapper. It only checks that the bot is in its match's FIGHT phase, then calls `BotAI.think`. |
| Client (LocalScript 10) | Only the version label: `R66-ui9`. |

**Unchanged:** player controls, the moves, damage, cooldowns, server hit checks, the bot level button (Easy / Normal / Hard / Off), the bot hero button, votes and the guided fight's Coach.

## How the AI decides

**Every tick (60 Hz):**
- **Sense.** It finds the nearest visible enemy player in its duel and reads the enemy's current attack:
  - wind-up, active or recovery;
  - frames until impact;
  - whether the attack reaches the bot;
  - whether it is a cast;
  - whether it missed.

  It also reads whether the enemy is flying, stunned, snared, spun, parrying, shielded or invulnerable.
- **Memory.** The enemy's last 8 attack starts are kept. Three starts within 2.5 s count as **spam**. Hard also learns the rhythm, the average gap between attacks, and expects the next one.
- **Move.** It holds the hero's preferred range, circles, backs off, steps out for a bait, sidesteps a ranged line, or flies at the enemy's height.

**At each decision:** decisions come every Think ticks, and also at once when it notices a new enemy attack or wakes from a stun.
- Every tactic in the hero's kit checks whether it fits.
- Each fitting tactic scores `P1 300 / P2 200 / P3 100` plus its bonus plus random noise.
- The highest score is pressed through Main's normal `doAction`, the same path a player's button takes.
- A combo tactic queues the rest of its chain and fires each press as the last one connects.

**Fair play rules (Hard included):**
- An enemy wind-up is only noticed **React** ticks after it starts. Hard is 12-18 ticks (0.2-0.3 s), or half that when it predicted the attack from the player's rhythm.
- It can't target an invisible player. Bulwark can slam where the player was last seen, as a person would.
- Cooldowns, Fury, the GCD, recovery, the 15-frame input buffer and the server's hit checks all apply to it, exactly as to a player.
- It keeps the existing wind-up tracking rule: with a target it turns to face it during startup, the same as a player with a target selected.

## Difficulty (Rules.BotAI.Difficulty)

| | Easy | Normal | Hard |
|---|---|---|---|
| Reaction to a wind-up | 0.5-0.8 s | 0.3-0.5 s | 0.2-0.3 s |
| Plans every | 0.4-0.6 s | 0.2-0.33 s | 0.1-0.2 s |
| Defends a noticed threat | 20% | 50% | 70% |
| Punishes a miss / opening | 25% | 60% | 85% |
| Combo presses | 1-2 | 2-3 | 3-4 |
| Anti-air / Interrupt / stun break | 25% / 15% / 25% | 60% / 50% / 60% | 85% / 80% / 85% |
| Random noise in choices | big (120) | some (50) | small (20) |
| Random wrong choice | 30% | 10% | 3% |
| Learns rhythm, baits spam | no | no | yes (60%) |
| Saves Fury for anti-air vs a flyer | no | yes | yes |
| Holds off hitting into Parry / spin / shield | 10% | 60% | 90% |

Defence chances are rolled once per enemy attack, so they are real frequencies and not guarantees.

## Strategy kits (Rules.BotAI.Kits)

Only the moves each hero actually has in R66 are used; nothing was invented. P1 = critical, P2 = standard combat, P3 = setup / positioning.

**Bulwark (tank, likes 5 studs).**
- P1:
  - Shield Parry against a noticed attack about to land, and as a stun breaker;
  - Shield Throw to interrupt a cast, and against a flyer within 33;
  - Charge-leap at a flyer;
  - Titan Cleave or Earth Slam on a miss or a held enemy.
- P2:
  - Earth Slam where a vanished enemy was;
  - Dimension Door to a flyer;
  - Cleave then Slam;
  - Slam;
  - Charge in from 7-16;
  - step out of a noticed swing.
- P3: Dimension Door in from 22-62.
- Keeps Fury for Shield Throw against flying heroes.

**Tempest (kiter, likes 14, pushes enemies off inside 9).**
- P1:
  - Tailwind out of big attacks, or when low and the enemy is close;
  - Whirlwind when low;
  - Lightning Snare or Whirlwind to stop a cast;
  - Snare a flyer;
  - Storm Fist on a miss;
  - Snare an enemy walking into melee.
- P2:
  - Lightning on a held enemy;
  - Lightning at a flyer;
  - Spark Jab x3 into Storm Fist;
  - Storm Fist;
  - sidestep ranged shots.
- P3: Lightning from 22-48, and fly up after a flyer.
- Keeps Fury for Snare against flying heroes.

**Solarion (aerial brawler, likes 4).**
- P1:
  - Solar Shield against big attacks, when low, and as a stun breaker;
  - Solar Hammer at a flyer;
  - Pounce or Sun Jab on a miss.
- P2:
  - fly after a flyer;
  - Solar Absorb up close;
  - Sun Jab x3 into Hammer;
  - Hammer from 8-28.
- P3: Pounce in from 10-24, and fly when kited at range for 2 s.
- **Flight:** it lands at 35 energy, or when the enemy is grounded and close, so it never hovers forever.

**Wraithstep (counter assassin, likes 4).**
- P1:
  - Vanish out of big attacks, when low, and as a stun breaker;
  - Grapple a flyer;
  - Grave Scythe or Shade Slash on a miss.
- P2:
  - Shadow Circle on a held enemy (e.g. after a Grapple);
  - Shade Slash x3 into Scythe;
  - Shade Bolts while phased;
  - Grapple a kiter from 14-60.
- P3: Phase when the enemy is 12+ away or flying (the bolts lock on to flyers).
- **Hard bait:** against spam it steps just outside the expected attack, then punishes the miss.

## How to tune without rewriting code

Everything lives in `Rules.BotAI` in the Rules module (search for `R66-ui9 Tactical bot AI`).
- **Make a level easier or harder:** change its row in `Difficulty`. React and Think are in ticks; the chances run 0-1.
- **Change what a hero prefers:** change a tactic's `P` (1-3) or `Bonus`, or its `Min` / `Max` range. Delete a line to drop a tactic.
- **Change spacing:** `Ideal` and `Min` per kit.
- **Change spam detection:** `SpamCount` and `SpamWindow`.
- **Change survival mode:** `LowHealth` (0.3 = under 30% health).

## Watching it work (telemetry)

- **Live attributes:** select the bot's model in the Explorer while it fights and watch the Properties panel:
  - `AI_State` (closing in / circling / retreating / baiting / evading / sidestepping / flying);
  - `AI_Tactic`, `AI_Priority`, `AI_Score`, `AI_Move`;
  - `AI_React` (ticks it took to react);
  - `AI_Reject` (the last tactic that fitted but was on cooldown, short of Fury, GCD or busy);
  - `AI_Hits` and `AI_Misses`.
- **Output log:** set `Rules.BotAI.Debug = true` and every decision prints, e.g. `[BotAI] t=520 Hard Solarion: PouncePunish P1 Skill2 (score 328, reacted in 7 ticks, anticipated)`.

## Tests

- **Compile:** all 12 scripts pass `luau-compile --binary -O2 -g2` with nothing on stderr. luau-analyze shows only Roblox globals, plus Main's old math.max warning at about line 1008, which was already there.
- **Place:** XML parses, 1112/1112 unique referents, Technology 4, and all 4 changed sources round-trip exactly. BotAI sits in the ServerScriptService HeroWars folder next to Main.
- **Offline fight simulation:** `test/botai_sim.luau`, run with `bash test/run_sim.sh <luau>`; full tables in `test/RESULTS.md`. It runs the real BotAI and the real Rules against scripted players in five scenarios:
  - attack spam;
  - flight vs ground;
  - a retreating kiter;
  - a caster;
  - low health.

  That covers 4 heroes x 3 levels, 8-16 fights each, about 440,000 ticks.

**What it shows:**
- **Levels separate:**
  - Hard reacts in about 13-25 ticks, against 17-35 on Normal and 35-55 on Easy.
  - Hard punishes far more. Against spam, Wraithstep punishes 12.2 times per fight on Hard, 4.2 on Normal and 0.6 on Easy.
  - Hard uses anti-air more. Solarion goes from 3.9 per fight on Easy to 12.4 on Normal and 19.2 on Hard.
  - Hard interrupts casts. Bulwark interrupts 1.5 casts per fight on Hard, 0.6 on Normal and none on Easy.
  - Only Hard baits.
- **Normal beats Easy almost everywhere** on threats avoided and damage taken.
- **Cost:** about 6 microseconds per server tick for one bot, so it is negligible for the server and does nothing to phones (it is server only).

**Honest limits of the sim:**
- It has no hitbox shapes, so a sidestep never dodges a ranged line there. Hard's evades look useless in the sim but work in the game.
- Hard sometimes avoids fewer hits than Normal there, because it spends time evading and baiting.
- The scripted players are simple. Real play is the test that matters.

## Known limitations

- **Not play-tested in Studio or on a phone.** First test: Test > Start, MENU > Bot level Hard, START FIGHT. Then watch the AI_* attributes on the bot.
- **Bulwark stays the weakest bot against fast jab spam** on every level (about 15% avoided in the sim). He has no jab, he's slow, and Parry has a 12 s cooldown. That is his kit, not the AI.
- **The AI can't see hitbox shapes.** It judges reach as range + lunge + leap + area. Lock-on moves (Snare, Whirlwind, Shade Bolts) can't be walked out of, so it uses its defensive for those.
- **No pathfinding,** by design (the brief asks to avoid it). Around the centre pyramid it walks straight and can be blocked by walls.
- The brief's other five characters (the design bible's six heroes and three villains) are not in the game, so they have no kits. Add them as new `Kits` entries once their moves exist.

## Merge notes (for Codex's R67+ line)

- **Add the new ModuleScript `BotAI`** next to Main in ServerScriptService/HeroWars; the source is `src/BotAI__BOTAI.luau`. `swap.py` adds it with referent `RBXBOTAI0001`.
- **Rules:** paste the `Rules.BotAI = {...}` block, which goes just before `function Rules.canInterrupt`.
- **Main:** replace the whole old `local function botThink(s)` with the ui9 version. It includes the `D.BotAI` and `D.botCtx` lines above it, and has no new top-level locals.
- **Diffs against ui8:** `patch/R66ui8_to_ui9_*.diff`.
