# HeroEngine Phase 0

This is the platform-neutral combat foundation for HeroWars, kept apart from the live game. Nothing here
is in a playtest build. The audit, and what is and isn't ported yet, are in `Documentation/PHASE0_AUDIT.md`.

```
phase0/
  HeroEngine/Core/            plain Luau, no Roblox calls: CombatRules, DamageCalculator, AbilitySystem,
                              CharacterStats, StateMachine, Simulation (the 60 Hz combat tick)
  HeroEngine/RobloxAdapters/  NetworkService (requests in, results out), HitboxAdapter, AnimationAdapter
  HeroEngine/AI/              notes only: BotAI already is this layer
  HeroEngine/Tests/           offline tests (Luau CLI)
  HeroWarsGame/Characters/    Solarion, Wraithstep: stats, abilities, inputs, looks (numbers read from Rules)
  HeroWarsGame/LegacyRules    points at the live HeroWars Rules, so there is one source of numbers
  TestPlace/                  the unpublished two-client test place (server + client scripts)
  default.project.json        Rojo project that builds the test place
```

## Commands (repo root)

| What | Command |
|---|---|
| Engine tests | `LUAU=/path/to/luau bash phase0/HeroEngine/Tests/run.sh` |
| Server script against a Roblox mock | `LUAU=/path/to/luau python3 phase0/HeroEngine/Tests/run_server_mock.py` |
| Build the test place | `cd phase0 && rojo build . -o HeroEngine_Phase0_Test.rbxlx` (Rojo 7.4) |

The Luau CLI is from https://github.com/luau-lang/luau/releases, and Rojo is from https://github.com/rojo-rbx/rojo/releases.

## Rules for modules

- `Core` must never call Roblox. Vectors are `{x, y, z}` arrays, and time is 60 Hz ticks.
- Every module runs in both places. The pattern is
  `if script then require(script.Parent.X) else require("./X")`.
- Clients send requests, never results. The server decides targets, damage and health.
