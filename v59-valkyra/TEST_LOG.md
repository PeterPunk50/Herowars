# V59 test log (2026-10-16, Studio Play through the Studio MCP)

| Test | Result |
|---|---|
| Modules compile (Edit) | Rules, PowerFX, FlightMotion, MocapData and the rest load; `tools/check_rules.luau` shows every button maps to her moves (Interrupt and Super removed), `isPounce` true for Pounce and ValkyrieDive, Bulwark shown as "Bulwark" with Paladin first, bot heroes include Valkyra, 11 valkyra_* and 10 bulwark_* captures |
| Spawn as Valkyra | rig ValkyraN, display "Valkyra", 110/110 HP, shield present; console clean |
| Her actions (`test_hero_client.luau`) | server starts Light1, Light2, Light3, Heavy, JavelinOfLight, ValkyrieDive, WingedRush |
| Her captures (`test_tracks_client.luau`) | 0.3 s into each move: Spear Jab 0.43 s clip, Valhalla Thrust 1.57, Javelin 1.21, Dive 1.33, Rush 1.10, Aegis Wings and Block the 1.99 s guard loop |
| Practice dummy (`hit_test.py`) | Javelin at 22 studs 13, Dive from 16 studs (leapt to 1.8) 18, Winged Rush 10, Valhalla Thrust 17, Spear Jab 6 |
| Vyrath boss in full V59 (`test_vs_dragon_client.luau`) | Javelin 13, Dive 54 (throat weak point x3), Rush 10, Thrust 17, Jab 6; the boss's breath took her 110 to 61; console clean |
| Loops (`loop_check.py`, clear lane) | idle TimePosition 0.02..2.50; run 0.00..0.92, feet swing 4.49 studs, L/R correlation -0.99 |
| Bulwark | rig PaladinN, display "Bulwark", 135 HP; Heavy, Slam, Charge, Dimension Door start; knight clips (Roblox Knight idle 4.12 s, Mixamo cleave 1.60, slam 1.73, charge 1.80); table guard pose; run 0.67 s loop, feet 4.25 studs |
| Test traps | the client aims along the camera: hold the camera on the target (BindToRenderStep Last+10); the sparring bot is only hittable in its duel, practice dummies (attribute Practice) by anyone; drive walking with Humanoid:Move bound after the game's input step; x -26 spawn ran into Cover blocks (moved to x 0) |
