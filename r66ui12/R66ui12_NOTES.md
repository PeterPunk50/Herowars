# R66-ui12: tactical bots (2026-10-31, base R66-ui11c)

Peter: "The AI bot just runs up to the opponent and starts chopping. Is there a way to make them more strategic and tactical, and why do they do that?"

**Build:** `HeroWars_V47_R66ui12.rbxlx`. Changed: BotAI (ServerScriptService.HeroWars.BotAI), Rules.BotAI (Difficulty + new Styles) and the version label. Main is unchanged.

**Audit (2026-11-01):** passed everything that could be run here, but it is still **not compile-checked and not play-tested** (the Luau CLI download was blocked on the cloud machine again). Checked: block and bracket balance in BotAI, Rules, Client and Main; no unknown globals in BotAI (only Roblox ones: workspace, RaycastParams, Enum, Vector3, task, game); every field the new code reads exists (sense() fills tReach, tDefDown, tWhirl, tHeld, whiff, thp; cooldowns are stored as end ticks, so the Read check is right; every kit tactic has an Id, so the Variety penalty works); all five scripts in the place match src/ exactly; 1113 unique referents; Technology 4. One fix: BotAI.autoKit no longer builds a Throw tactic (Throw was removed in v35 and isn't a server action). Open it in Studio and watch Output for a red BotAI line on the first fight.

Behaviour notes from the audit: at the very start of a fight the bot goes in at once (its Pressure timer starts expired), and while you are under 25% health it stays in engage and won't step out. Both are on purpose for now; say if you want either changed.

## Why the bot rushed

1. Bulwark, Solarion and Wraithstep had an ideal range of 4-5 studs, so "walk straight at the enemy" was the default move.
2. Melee and Combo tactics had no condition. Once in range, attacking was always on the table, so it never waited for you to miss.
3. R66-ui11 toned it down: Easy defends 8% and Normal 20% of the time, and Easy picks a random move 45% of the time.
4. Noise (160 Easy / 120 Normal) was bigger than the 100-point gap between priorities, so a punish and a plain swing scored about the same.
5. Retreat when low only rolled 8-20%, and Bulwark had none.

## What's new: stances

The bot is always in one stance (shown live as the `AI_Stance` attribute on the bot model):

| Stance | What it does |
|---|---|
| neutral | Waits just outside your swing reach (your Light/Heavy Range + Lunge + the style's Margin) and circles. It only pokes with ranged moves, zones and Phase. |
| engage | Goes in for a burst of 1-3 moves (Burst), then |
| disengage | steps back out to the edge of your reach (hit and out), |
| retreat | backs off in a curve while low on health and behind, then comes back. |

- **Melee, Combo and GapClose only fire while engaging.** Punish, Defend, Interrupt, AntiAir, Evade, Ranged and Zone work in every stance. A miss or a stun is still punished at once, and that switches it to engage.
- **It goes in when:** you miss, you're stunned/snared, you're under 25% health, (Hard) your defensive is on cooldown, you walk into its space (Counter chance), its style rolls it, it gets impatient (1 - Patience), or nothing has happened for Pressure ticks.
- **Hit and out:** after the burst it steps out with chance Discipline x the style's HitAndOut. Otherwise it keeps swinging (the old rush, mostly on Easy).
- **Defensives:** still saved for heavy hits, but below 40% health it uses them on anything that would land.
- **Dodging:** stepping out of a noticed attack now has its own Dodge chance, and big casts and heavy blows are dodged first. It won't walk into a Whirlwind spin.
- **Variety:** the same tactic twice in a row loses Variety points, so it mixes its moves.
- **Ledges:** before stepping back or sideways it checks for floor 4 studs ahead and turns or stops if there's none.
- **New heroes:** a hero with no kit in Rules.BotAI.Kits gets one built from its own moves (`BotAI.autoKit`): Heavy punishes, leaps/charges close the gap, long-range skills poke, radius casts are zones. Before this, a hero without a kit just stood there.

## Hero styles (Rules.BotAI.Styles)

| Hero | Style | Notes |
|---|---|---|
| Bulwark | Juggernaut | Creeps forward in neutral instead of backing up, Aggro 0.6, rarely steps out, never retreats |
| Tempest | Kiter | Stays at 14 studs, steps out after almost every burst, backs off at 40% |
| Solarion | Diver | Waits about 3 studs outside your reach, pounces in, gets out, backs off at 30% |
| Wraithstep | Assassin | Most patient (Aggro 0.3), pokes with Shade Bolts, goes in on a miss or when you're low |

## Difficulty (new fields, R66-ui11's reaction/defend/punish numbers kept)

| | Easy | Normal | Hard |
|---|---|---|---|
| Burst (moves per trip in) | 1-2 | 1-3 | 2-3 |
| Discipline (steps back out) | 35% | 60% | 85% |
| Patience (waits instead of walking in) | 50% | 70% | 85% |
| Pressure (goes in anyway after) | 4 s | 3.3 s | 2.8 s |
| Dodge | 10% | 25% | 55% |
| Retreat when low | 30% | 50% | 65% |
| Variety penalty | 30 | 50 | 60 |
| Reads your defensive cooldown | no | no | yes |
| Noise (was) | 110 (160) | 70 (120) | 50 (50) |

Lower noise means its priorities matter more on Easy and Normal, which makes it slightly sharper. Turn Noise back up in Rules.BotAI.Difficulty if it feels too strong.

## Tuning

Everything is data in Rules.BotAI. Set `Debug = true` to print every stance change and press to Output.

## Merge (Codex / the 15-hero place)

- BotAI: take the whole file (patch/R66ui11_to_ui12_BotAI__BOTAI.diff).
- Rules: add the new Difficulty fields and the Styles table (patch/R66ui11_to_ui12_Rules__3.diff).
- The 15-hero place's own bot brain (rewritten 2026-10-28 on the PC: "strongest ready move first") is separate code. The same stance layer has to be put into it there.
