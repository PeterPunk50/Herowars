# Start screen scenery (2026-10-27)

`HW_StartScenery` is one LocalScript that upgrades the start-screen arena on each player's screen:
torches get burning flames and flickering light, the blue portal column turns to glowing energy with rising motes and two
orbiting rings, the crossed swords become polished steel with gold hilts, a glint and a spark "clash" every 6 s, the short
column under the dragon gets gold trim and a slow rune ring, and the dragon breathes, turns its head, smokes and puffs fire
every 8 to 12 s (if the dragon has bones named wing/tail/neck/head/jaw, those move too). It adds a soft Bloom so Neon glows,
unless the place already has one.

Install: Studio > Explorer > StarterPlayer > StarterPlayerScripts > right-click > Insert from File > `HW_StartScenery.rbxmx`.
It finds objects by name (torch, portal/pillar/column/gate, sword, dragon/vyrath). Anything it misses: add a Tag in Properties
(`HW_Torch`, `HW_Portal`, `HW_Swords`, `HW_Dragon`, `HW_Plinth`). Output prints what it found.
Client side only; no gameplay, collision or server changes. Not compile-checked with the Luau CLI (not available here).
