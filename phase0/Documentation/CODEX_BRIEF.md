# Brief for Codex (Peter's Windows PC): Phase 0 test, rigs and R71 (2026-10-14)

Claude works in the cloud and can't open Studio. Codex is on the PC with Studio, so Studio work goes to Codex
and code work stays with Claude. Do these in order and send back what each step says to send.

## 1. Run the Phase 0 two-client test (about 5 minutes)

1. Get the place. Either:
   - pull branch `claude/project-thread-cy57r0` from github.com/PeterPunk50/Herowars and open
     `phase0/HeroEngine_Phase0_Test.rbxlx`, or
   - use the copy Peter downloads from the project.

   It's a separate test place, so don't publish it.
2. Open **Test > Clients and Servers**, set 2 players and click Start.
3. In the Player1 window (Solarion), press **1**. Expected: `PASS 1: Solarion Sun Jab ... (100 -> 94)` in the panel
   and in the Server Output.
4. Rig check: press **3** in each player window.
   - Each press swaps that player's body to the next rigged model: HW_Bulwark, then HW_Valkyra, then their own
     avatar again.
   - Health must stay the same through a swap.
   - Walk around in the rig. Then have Player1 press 1 again: it must still hit (`PASS 2`).
5. **Send back:** every `[Phase0]` line from the Server Output, plus any red errors. Note for each rig:
   - Did it stand upright at normal height?
   - Did it walk with animation?
   - Were the shield and helmet in place?
   - Did the other window see it?

## 2. Import the Solarion and Wraithstep rigs (Studio clicks, about 5 minutes)

The files are in the project at `knowledge/HeroWars/rigging/solarion/` and `.../wraithstep/` (Peter downloads them):

| Hero | Body (File > Import 3D, **Rig Type R15**) | Kit (File > Import 3D, no rig) |
|---|---|---|
| Solarion (Super kit) | `HW_solarion_super_6k_R15.fbx` | `HW_solarion_super_kit.fbx` |
| Wraithstep (Ninja kit) | `HW_wraithstep_ninja_6k_R15.fbx` | `HW_wraithstep_ninja_kit.fbx` |

1. Make a new Baseplate place.
2. Import the four files: each body, then its kit. They can sit anywhere. Import 3D uploads the meshes to Peter's
   account, so they can be used in his places.
3. Use **File > Save to File As** and save `SolWraith_import.rbxl`.
4. **Send back:** that .rbxl. Don't commit it to GitHub: the repo is public and the meshes come from Mixamo.

Claude then turns it into game-sized `HW_Solarion.rbxmx` and `HW_Wraithstep.rbxmx` (Humanoid, welded kit, scaled
from 171 studs to hero size). Claude puts them in the test place, so the next test is Solarion vs Wraithstep in
their own rigs.

## 3. Put R71 on GitHub

Push your current build to a new branch, `codex/r71`:
- `r71/src/*.luau`, in the same layout and names as `r66ui11/src/`;
- the `.rbxlx`;
- `HANDOVER_NEXT_SESSION.md`.

Phase 1 (moving combat into HeroEngine) has to start from your R71, not from Claude's older R66-ui11. Until it's
pushed, Claude won't touch `Main`.

## Who does what after this

| Claude (cloud) | Codex (PC) | Peter |
|---|---|---|
| Fix the imports into HW_Solarion / HW_Wraithstep. Rebuild the test place. Phase 1: Solarion's attacks through the engine behind a `Rules.UseEngine` flag, on top of R71. Keep the offline tests green. | Every Studio click: the tests, Import 3D, saving files. Merge Phase 1 into the R-line (Claude sends diffs with anchors). Run the two-client and phone tests. | Moves files between the project and the PC. Publishes to the live game with **File > Publish to Roblox As** only after a rigged build passes the two-client test. |
