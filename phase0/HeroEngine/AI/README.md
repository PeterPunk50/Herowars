# HeroEngine AI

Not rebuilt in Phase 0, because HeroWars already has this layer:

- `BotAI` (`r66ui11/src/BotAI__BOTAI.luau`): sense, memory, tactics, priority choice, act, move.
- `Rules.BotAI`: per-hero strategy kits, the P1/P2/P3 priority scores (the plan's PrioritySystem) and
  Easy/Normal/Hard.

BotAI already presses buttons through the same server checks as a player (`doAction`). In Phase 1 it moves
here as a file move: its `ctx.doAction` points at `AbilitySystem.tryUse` instead of Main.
