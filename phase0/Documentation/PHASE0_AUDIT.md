# Phase 0 audit: the outside plan vs the HeroWars code (2026-10-14)

Checked against the newest Claude-side build, R66-ui11c (`r66ui11/src/`), and `HANDOVER_CODEX.md`.
Codex's R67-R71 on Peter's PC is not in the repo, so anything Codex changed since R66 is not covered here.

## Verdict

The plan's direction is right, but about two thirds of what it calls Phase 0 already exists in HeroWars.
It just lives inside one 2,827-line server script (`Main`) instead of separate modules. The useful part
of Phase 0 is pulling the combat core out of `Main` into modules that can be tested without Studio.
Rebuilding systems the game already has, such as the bot AI and server authority, would be wasted work.

## The plan's five steps against what exists

| Plan step | What HeroWars already has | Gap |
|---|---|---|
| 1. Audit, preserve what works | Everything in R66-ui11c works and is kept. Phase 0 changes no game script. | None |
| 2. Isolated foundation (folder, branch, unpublished test place) | Builds are versioned rN folders swapped into `.rbxlx` by Python. There is no Rojo and no source sync. | Now `phase0/` on its own branch, with a Rojo project and a pre-built test place |
| 3. Common interfaces | Every hero's moves are `Rules.Moves` plus per-hero overrides read through `Rules.heroMove`. All heroes go through one `startAttack` / `tryInput` / `applyHit` with the same cooldown, Fury, global cooldown and ramp rules. | Health lives on the Roblox Humanoid. "State" is about 40 loose timer fields (`s.stunned`, `s.dashUntil`, `s.parryUntil`, `s.hitstop`...), not a state machine. Hero specials are `if s.hero == "Bulwark"` branches and move flags inside `applyHit`. |
| 4. Server authority | Already done (v30-v36). Clients send `(action, data, seq)` on one RemoteEvent. The server checks a whitelist and enforces cooldown, Fury, GCD and the input buffer. It finds hits with server hitboxes and lag-compensated rewind. It checks movement speed (`Rules.moveCheck`) and snaps cheaters back. | None for combat |
| 5. One integration test (Solaris attack damages Wraithstep, two clients) | The offline bot sim (`r66ui9/test`) uses a simplified duel, not the server's code. | Now built: the same `Simulation.tick` runs offline and in the test place |

## The plan's modules against our code

| Proposed module | Where it lives today | Phase 0 file |
|---|---|---|
| Core/CombatRules | `Rules.phase`, `Rules.defend`, `Rules.drStun`, `Rules.boxesOverlap` (already pure Luau) | `HeroEngine/Core/CombatRules.luau`: ported, with parity tests against the originals |
| Core/DamageCalculator | Inline in `Main.applyHit` (about 230 lines with Fury, parry, riposte, DoTs and splat) | `DamageCalculator.luau`: the generic order (base, sweet spot, counter, modifiers, guard, absorb). Hero specials become `DamageModifiers` hooks |
| Core/AbilitySystem | `Main.startAttack` and `tryInput`, with data in `Rules.Moves` | `AbilitySystem.luau`: define, tryUse, step, pulses, ramping cooldowns, chains |
| Core/CharacterStats | `Rules.Characters`, with health on the Humanoid | `CharacterStats.luau`: the server owns `hp`, and the Humanoid only mirrors it |
| Core/StateMachine | Loose timer fields in Main | `StateMachine.luau`: Idle, Startup, Active, Recovery, Stunned and Dead, with allowed transitions |
| AI/StrategyEngine + PrioritySystem | **Already built:** `BotAI` (522 lines) plus `Rules.BotAI`, with P1/P2/P3 priority scores, per-hero tactics and Easy/Normal/Hard | Not rebuilt. See `HeroEngine/AI/README.md` |
| RobloxAdapters/NetworkService | `Main.onServerEvent` plus `validActions` | `NetworkService.luau`: whitelist and a per-player rate limit (Main has none) |
| RobloxAdapters/HitboxAdapter | `Main.hitTargets`, `toBox`, `snapshot` | `HitboxAdapter.luau`: same box shapes, but no rewind or limb boxes yet |
| RobloxAdapters/AnimationAdapter | The client's Mocap and FlightMotion code (about 5,400 lines) | `AnimationAdapter.luau`: a placeholder swing and hit flash for plain avatars |
| HeroWarsGame/Characters | `Rules.Characters`, `HeroMoves`, `HeroSkills` and `Skins` | `Solarion.luau` and `Wraithstep.luau` read their numbers from the live Rules, so nothing is copied |

## Where the plan fits and where it doesn't

- **Good fit:** the split between rules and platform. `Rules` already has zero Roblox calls, so the engine
  core can be plain Luau. The offline tests prove that: the engine runs in the Luau CLI and matches the
  game's own rules on 2,000+ cases.
- **Good fit:** one integration test before more framework. It stops Phase 0 growing for months.
- **Duplicates work:** the AI folder (BotAI already does this), and server authority (already done).
- **Two numbers sources would be a mistake.** The character files read `Rules` through
  `HeroWarsGame/LegacyRules.luau`. Balance changes made by Peter, Claude or Codex reach the engine
  automatically. When the engine takes over (Phase 1), the numbers can move into the character files for good.
- **Rojo for the live game is not worth it yet.** The live place is 5 MB of XML with the arenas and temples
  baked in. Rojo would mean splitting those into model files, and Peter would need the Rojo plugin on the
  PC. Phase 0 uses Rojo only to build the small test place. Peter gets the built `.rbxlx` and installs nothing.
- **Renamed:** the plan's "Solaris" is our Solarion.

## What Codex would have to merge

- **Now: nothing.** Phase 0 is additive. It lives only in `phase0/` on branch `claude/project-thread-cy57r0`.
  No playtest build or game script changed, and R66-ui11c and Codex's R71 are untouched.
- **Phase 1 (when the engine replaces Main's combat):** `startAttack`, `tryInput`, `applyHit`,
  `hitTargets` and the per-tick action loop in `Main` would call the engine instead. Codex has been editing
  Main on the PC, so these are the functions that would conflict. Two things keep that safe:
  1. Swap one hero at a time behind a flag (`Rules.UseEngine = {Solarion = true}`), and keep the parity
     tests green, so the live game plays the same.
  2. Only one builder edits Main during the swap. Codex's R71 sources should be in the repo first.
- **Still to port in Phase 1 (Main does these, the engine doesn't yet):** input buffer and cancels, cast bars
  and interrupt lockout, stun DR on hits, sneak bonus, Dots/Zap/Juggernaut/parry riposte/mist, lag-compensated
  rewind and limb hurtboxes, hurtbox states (crouch/air/down), teleports, Pounce, Charge leap, Whirlwind lock-on,
  flight, blocking input. Pulses (Solar Hammer) and ramping cooldowns are already in.

## Recommendation

1. Run the two-client test (`Documentation/INTEGRATION_TEST.md`). It needs about two minutes in Studio.
2. If it passes, Phase 1 means moving Main's combat core into the engine one hero at a time, behind the
   flag. It does not mean building more framework. Start with Solarion, since his kit is the smallest.
3. Get Codex's R71 sources into the repo before Phase 1 touches Main.
4. Keep BotAI as the AI layer. Move it under `HeroEngine/AI` in Phase 1 as a file move, not a rewrite.
