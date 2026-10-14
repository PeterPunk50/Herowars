# Phase 0 two-client test in Studio

**File:** `HeroEngine_Phase0_Test.rbxlx`. It is a separate, unpublished test place. Don't publish it, and
don't open it over the HeroWars game.

## Steps (Windows PC, about 2 minutes)

1. In Studio, use **File > Open from File** to open `HeroEngine_Phase0_Test.rbxlx`.
2. Open the **Test** tab. Under **Clients and Servers**, set the players box to **2**, then click **Start**.
   Three windows open: Server, Player1 and Player2.
3. **Player1** is Solarion. Click into the Player1 window and press **1**.
4. **What you should see:**
   - Player2 (Wraithstep) flashes red and a **6** pops up over his head.
   - The panel at the top left of both player windows shows
     `Result: PASS 1: Solarion Sun Jab damaged Wraithstep through HeroEngine for 6 (100 -> 94)`.
   - The Server window's Output shows the same line, starting with `[Phase0] PASS`.
5. **Optional:**
   - Press 1 three times quickly for the combo (6, 7, 9).
   - Press **2** for Solar Hammer (three pulses of 9).
   - Press **R** to put both fighters back on their spots at full health.
   - Player2 can hit back with 1 and 2.
6. **Send back:** a screenshot of a player window, or the `[Phase0]` lines from Output. If it says FAIL, or
   nothing happens, copy any red lines from the Output window too.

If someone walks away, press R. Both fighters start 4 studs apart, facing each other, and the server aims
for you, so you only need to press the key.

## What the test proves

- The client only asks to use an ability. The server picks the target and the ability from the engine
  (`AbilitySystem`), runs it frame by frame at 60 Hz (`Simulation`) and finds the hit (`HitboxAdapter` with
  `CombatRules` boxes).
- `DamageCalculator` sets the damage, and `CharacterStats` takes it off Wraithstep on the server. The
  Humanoid shows that number and nothing else changes health.
- The server compares the damage with the live game's own Rules (Sun Jab = 6) before it prints PASS.
- Both clients hear about the hit.

The same path also runs offline: `phase0/HeroEngine/Tests/run.luau` (52 checks) and
`run_server_mock.py` (the test place's real server script against a mock of Roblox, 10 checks).
