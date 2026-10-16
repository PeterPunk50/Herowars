# Vyrath redo: mesh to Studio to test, from scratch (2026-10-16)

A clean re-run of the dragon setup, versioned step by step on the `vyrath-redo` branch.

| Step | Input | Output |
|---|---|---|
| 1. Mesh | `mesh/Vyrath_all2.fbx` (+ `.fbm` textures): Tripo mesh, 83-bone custom rig, 19 baked clips (Blender export). `mesh/vyrath_gen_tripo_raw.glb` is the untouched Tripo mesh. Hashes in `mesh/SHA256SUMS`. | |
| 2. Empty place | `tools/make_test_place.py` | `~/Downloads/HeroWars_vyrath_redo/Vyrath_redo_testbed.rbxlx` (baseplate, spawn pad at z 70) |
| 3. Import | Studio Import 3D: Rig Type Custom, Keep Zero Influence Bones on, Anchored on | model + 19 KeyframeSequences in `ServerStorage.RBX_ANIMSAVES` |
| 4. Setup | `tools/setup_vyrath.luau` (run through the Studio MCP) | model scaled to a 25-stud boss, paws on y 0, boss scripts in place |
| 5. Test | `tools/test_vyrath.luau` | results in `TEST_LOG.md` |

Place files are 200+ MB, so they stay out of git and out of iCloud-synced `~/Documents`; `places.md` records their sizes and hashes.
