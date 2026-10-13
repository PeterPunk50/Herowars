# R66-ui11: Bot toned down (2026-10-13, base R66-ui10)

Peter asked: "tone down the bot: make Easy a lot lower and double the time taken to react or even more; Normal can be Easy and Normal Hard."

**Build:** `HeroWars_V47_R66ui11b.rbxlx` (label R66-ui11b). Only Rules and the version label changed. Not play-tested yet.

| | New Easy | New Normal (= old Easy) | New Hard (= old Normal) |
|---|---|---|---|
| Reaction to a wind-up | 1.0-1.6 s | 0.5-0.8 s | 0.3-0.5 s |
| Plans every | 0.8-1.2 s | 0.4-0.6 s | 0.2-0.33 s |
| Defends a noticed threat | 8% | 20% | 50% |
| Punishes a miss | 10% | 25% | 60% |
| Combo presses | 1 | 1-2 | 2-3 |
| Anti-air / Interrupt / stun break | 10% / 5% / 10% | 25% / 15% / 25% | 60% / 50% / 60% |
| Random wrong choice | 45% | 30% | 10% |
| Keeps its range | 15% | 30% | 70% |
| Holds off hitting into Parry / spin / shield | never | 10% | 60% |

The old Hard (learns your rhythm, baits spam) is gone. Damage, health and speed are the same on every level.

## R66-ui11b: Earth Slam cooldown (Peter: "reduce the cd on Bulwark's big attack but don't let him spam")

His big attack is taken to be Earth Slam (key 2). Titan Cleave is already 1 s.
- **Cooldown:** 3 s, down from 5 s.
- **Anti-spam:** each Slam used within 6 s of it coming ready waits 1.5 s longer, so spammed Slams go 3 s, 4.5 s, then 6 s.
- **Reset:** it resets to 3 s after 6 s without a Slam.
- **Unchanged:** it still costs 35 Fury, triggers the GCD and stuns for 0.8 s under the stun diminishing returns.
- **Mechanism:** the same ramp as Solar Hammer and Whirlwind (`RampStep 90`, `RampMax 360`, `RampReset 360`).

**Sim against simple attack spam** (`test/RESULTS.md`), wins out of 16:
- Easy: 0-4.
- Normal: 3-15.
- Hard: 3-16.

Bulwark stays weak against spam on every level.

**Checks:**
- All scripts compile clean.
- XML has 1113/1113 unique referents and Technology 4.
- The changed sources round-trip exactly.

**Merge for Codex:** paste the new `Difficulty` block from `patch/R66ui10_to_ui11_Rules.diff`.
