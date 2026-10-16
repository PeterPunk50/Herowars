# Place files (not in git: too big, and kept out of iCloud-synced ~/Documents)

Folder: `~/Downloads/HeroWars_vyrath_redo/` (read-only copies in its `originals/`).

| File | Bytes | sha256 | Made by |
|---|---|---|---|
| `Vyrath_redo_testbed.rbxlx` | 258,394,345 | `891642b7b613c6d43c5c4eff7b9ce0d779e61006045f8bdd6cf8739112a4b2d9` | `tools/make_test_place.py`, Studio Import 3D of `mesh/Vyrath_all2.fbx`, `tools/setup_vyrath.luau`, File > Save to File |
| `HeroWars_V58_VyrathRedo.rbxlx` | 261,762,051 | `97ae4af838971d01a0fe422fb87e8228fb72c6b8d690b1f462f4662edb00cc2b` | `tools/build_game_place.py HeroWars_V56_BlenderMoves.rbxlx Vyrath_redo_testbed.rbxlx boss <out>` (HUD label `V58-vyrath-redo`) |

Rebuild V58 from scratch: run the README steps 2 to 4, save the test place, then `build_game_place.py`.
