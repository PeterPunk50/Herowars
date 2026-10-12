# R66-ui (2026-10-12, base R66, built by Claude, NOT in Codex's R67+ line)

Peter: "the mobile view the menu box needs to fit all ... so none are cut off".

**Codex needs to merge this into its R67+ build.** Only the client script (LocalScript referent 10) changed; Main and the place are R66's. The diff is four small edits in HeroWarsClient__10.luau (search for `R66-ui`):
1. In the MenuShell `fit()` near the top: `if shell:GetAttribute("TouchFit") then return end` as its first line.
2. In the phone tile block (`-- R64m ... grid of square-ish tiles`), after the UIGridLayout is created: the `fitTiles()` block.
3. First line of the main `remote.OnClientEvent` handler: `if kind=="Fx" and Sig.fxFar and Sig.fxFar(a,b,c) then return end`.
4. A new `;(function() ... end)()` at the very end of the file (far-effect filter + phone graphics profile).

## Phone MENU fit (client)
- The tile grid picks 3, 4, 5 or 6 columns from the real screen size so every tile shows at once, no scrolling.
- Tiles stay 50-64 px tall where possible; only a very short screen shrinks them (down to 34 px).
- The menu's UIScale is 1 on phones now (it was 0.8 on short screens, which made the text tiny and still overflowed).
- Refits when the screen turns, when a tile is shown or hidden, and each time MENU opens.
- Scrolling stays on only as a last resort (6 columns of 34 px tiles still too tall).
- Example: a 412 px tall landscape phone (Studio's S22 Ultra) gets 4 columns x 4 rows of 84x64 tiles, 348 px tall.

## Phone performance (client)
From knowledge/HeroWars/LIVE_CHECK_2026-10-12.md items 3 and 4.
- **Far effects skipped (all devices):** one-off effect bursts (Quake, Shockwave, Pulse, Holy Ring, Door Slam, Teleport, Drain/Zap/Shade ticks, Super flash and shake, and so on) from a fighter more than 140 studs from your camera and your fighter aren't drawn. Your own fight and a duel you WATCH are always inside that range. Effects that change how a fighter looks for a while (Shield, Parry, Vanish, Armor, Glitch, Snare, casts, Solar Absorb, Cancel) always run, so nobody stays wrongly visible or invisible.
- **Phone graphics profile (touch screens only):** Depth of Field and Sun Rays off, no light casts shadows (the temple torch fires did), sharp shadows (ShadowSoftness 0). Stays on through arena changes and new lights.
- **Not done:** Lighting stays Future (Technology 4, as the build method says). A script can't change Technology; switching the whole place to ShadowMap (3) is a place-file choice for Peter.
- Output prints `[HeroWars] phone graphics profile on: ...` on a phone.

## Server size (Peter's click)
The place file already says 12, but the live game uses the dashboard setting, which is 50. In Studio with HeroWars published: File > Game Settings > Places > the start place's ... menu > Edit > set **Max Players** to 12 > Save. (The same setting is under the start place on the Creator Dashboard.) 5 duel rings x 2 = 10 fighters, plus 2 spare.

## Checks
- All 11 scripts pass `luau-compile --binary -O2 -g2` with nothing on stderr; luau-analyze shows only Roblox globals.
- Place: 1111/1111 unique referents, Technology=4, XML parses; client source round-trips exactly.
- Built by swapping sources into R66's place (which already has bodies, avatars and temples) with `swap.py` (class + referent).

---

# R66-ui2 (2026-10-12, round 2, same folder): `HeroWars_V47_R66ui2.rbxlx`

Peter: "make buttons fit to size (don't take up center screen), do all of the changes recommended, do a vote for the bots, remove the loading screen at the startup, get a fast startup for both".

Changes Main (Script 7) and the client (LocalScript 10). `src/` holds the ui2 sources. To re-apply them onto Codex's line, run `patch/main_r2.py` and `patch/client_r2.py` (each takes the script path). They assert every anchor, so a mismatch fails loudly instead of silently.

## Client
- **How to Play card:** sits top-left under the Roblox buttons. It is at most 45% of the screen wide and stays clear of the bottom button row, so it never covers the centre.
- **No loading screen:** the welcome screen is gone and the lobby doesn't open on join. You spawn straight in, and MENU > Lobby picks a hero (the card's MENU row says so).
- **Faster first load:** downloads go in this order: the fighters in the arena, then every hero's default look, then the other skins. On phones the other skins wait 20 s.
- **Vote bar:** sits top right under MENU, with YES / NO, the count and the seconds left.
- **Leaderboard:** a MENU button (a tile on phones). It opens a left-side panel showing this server (PvP wins / losses and bot wins) and the all-time top 10 PvP wins.
- **Guided fight:** uses the nearest bot or practice dummy that isn't in a duel, so several new players can do it at once.

## Server
- **Votes:** with 2+ players in the server, changing the Arena, the bot level (incl. Off) or the bot hero starts a 20 s vote. YES from more than half the players passes it; NO from enough players, or the timer running out, fails it. Alone in a server it happens at once, as before. One vote at a time. The old rules still apply first (no arena change during duels, no bot hero change mid bot match).
- **Pause:** only works when the two duelists are the only players in the server, because it freezes everyone.
- **Practice dummies:** one still dummy beside every duel ring except ring 1, where the bot stands. They stand 22 studs past the ring's mark, on the floor, cycling Bulwark / Tempest / Solarion / Wraithstep. They appear 8 s after the server starts, so the first player's fighter comes first.
  - They heal to full after 6 s without being hit and respawn 3 s after a KO.
  - Anyone not in a duel can hit them.
  - They move to their ring's spot on an arena change.
  - Guided-fight steps 6-7 (Coach) make the nearest free bot or practice dummy swing or cast.
- **Saved wins:** DataStore `HeroWarsStats` (key `s_<UserId>`) holds PvP wins and losses plus bot wins. The OrderedDataStore `HeroWarsWins` holds PvP wins for the all-time top 10. A `leaderstats` folder (Wins, Losses) is on each player.
  - Saves happen after each match, every 2 minutes, on leaving and on shutdown.
  - Bot wins don't count on the all-time board, so nobody can farm the Easy bot.
  - Saving only works in the published game (API access).

## Not done, on purpose
- **StreamingEnabled stays off.** The 5 MB place file is mostly XML text (HW_Temple2 is 3.4 MB of CFrames, not mesh data); meshes and textures already download separately by asset id. Streaming wouldn't shrink that and risks the arena, rings and temples not being there at spawn. The faster-start changes above target the real wait instead.
- Lighting stays Technology 4 (build rule; not changeable from a script).

## Checks (ui2)
- All 11 scripts pass `luau-compile --binary -O2 -g2` with nothing on stderr. luau-analyze shows only Roblox globals. Its one type warning (Main ~line 1008, math.max) was already in R66.
- Place: 1111/1111 unique referents, Technology=4, XML parses, both sources round-trip exactly.
- **Not play-tested.** Nobody has run votes with 2+ players, the practice dummies, or DataStore saving yet. Test with Test > Clients and Servers (2 players), then live with the second account.

---

# R66-ui3 (2026-10-12): `HeroWars_V47_R66ui3.rbxlx` (client only, on top of ui2)

From Peter's phone screenshot of ui2: the How to Play card showed as a dark box with its text hidden. He also said "it needs to disappear when the menu is shut".

- **Text hidden:** the HUD ScreenGui draws by global ZIndex, so the card (ZIndex 40) and the guided-fight box (30) covered their own text and buttons (ZIndex 1). This bug was already in R66. A small `;(function() ... end)()` near the end (tag `R66-ui2 fix`) now lifts everything inside them one level above its parent, including rows added later.
- **Closing with MENU:** the card and the leaderboard belong to MENU now.
  - Opening the card also opens MENU.
  - Shutting MENU closes the card, which counts as "seen", and closes the leaderboard.
  - The How to play button toggles the card.
- Codex: these edits are tagged `R66-ui3`/`R66-ui2 fix` in src/HeroWarsClient__10.luau (they are not in patch/client_r2.py).

# R66-ui4 (2026-10-12): `HeroWars_V47_R66ui4.rbxlx` (client only, replaces ui3)
Peter: "all should go when MENU is clicked again".
- Shutting MENU now ends a running guided fight and closes the keybinds list, as well as the card and leaderboard (ui3).
- Starting the guided fight (from the card or MENU) shuts MENU itself, so the fight has the screen. Opening and shutting MENU afterwards ends it.
- Tagged `R66-ui4` in src/HeroWarsClient__10.luau.

# R66-ui5 (2026-10-12): `HeroWars_V47_R66ui5.rbxlx` (client only, replaces ui4)
Peter: "the menu screens should be movable, with a 0.4 s check so no mistake moves happen".
- How to Play, Leaderboard, Guided fight and Keybindings can now be dragged.
- **How:** press and hold an empty part of the panel (not a button) for 0.4 s without moving more than 8 px. The edge turns white, and the panel then follows the finger or mouse until release.
- A tap, a button press, or a swipe that starts moving before 0.4 s never moves a panel.
- Panels are kept fully on screen, also when the phone turns. The panel takes the touch, so the camera doesn't turn while dragging.
- Positions last for the session.
- The MENU drop-down itself stays docked top right, level with the Roblox button (Peter's UI rule).
- Tagged `R66-ui5` in src/HeroWarsClient__10.luau.

# R66-ui6 (2026-10-12): `HeroWars_V47_R66ui6.rbxlx` (client only, replaces ui5)
Peter's screenshot showed two problems in ui5: the How to Play card's last row (MENU) ran into START GUIDED FIGHT, and he couldn't move the box or the announcement.
- **Card height:** the card is taller (PC 424, phone 362; was 400/330), so all six rows fit above the two buttons.
- **Dragging, rewritten:** ui5 listened for presses on the panel frames themselves, and the text inside them covered the frames, so no press reached them. ui6 reads presses from UserInputService and checks which panel is under the pointer, skipping buttons. Same 0.4 s hold and 8 px rule.
- **Also movable now:** the controls hint line ("Abilities on the bar below…", PC) and the Notice line, while they're showing.
- Tagged `R66-ui5/ui6`/`R66-ui6` in src/HeroWarsClient__10.luau.

# R66-ui7 (2026-10-12): `HeroWars_V47_R66ui7.rbxlx` (client only, replaces ui6)
Peter's phone screenshots of ui6:
- the How to Play card sat under the MENU tiles;
- the guided-fight box sat on top of the Lobby;
- the fight commentary (round line) covered the guide;
- the boxes still couldn't be moved on the phone.

He asked for a proper screen-management solution, plus a fast option for skins.

**Screen layout manager** (tag `R66-ui7 screen layout`, checked 10 times a second):
- **Left column, top down:**
  - the round line (fight commentary);
  - then the guided-fight box (phones; on PC it stays at 40% height);
  - then the notice line.

  They stack and never overlap. A panel someone dragged by hand keeps its spot (attribute `Dragged`).
- **Guide steps aside:** while a big panel is open (Lobby, Keybindings, How to Play, Leaderboard), the guided-fight box hides. It comes back when the panel closes, if the guide is still running.
- **Phones, one screen at a time:** opening How to Play, Leaderboard or the Lobby from MENU hides the MENU tiles. Closing the panel (GOT IT / X / wear) brings the tiles back, and tapping MENU shuts everything.
  - The Lobby no longer shuts MENU on phones, which also means it no longer ends a running guide.

**Looks: Simple / 3D** (MENU button `LooksButton`, a tile on phones):
- **Simple** (phone default): other fighters show their hero-coloured base body. Skin pieces (KitPiece) are hidden on this screen only, and no other skins are downloaded (`Preload.paused`).
- **3D** (PC default): full skins, with the rest of the skins downloading in the background.
- Your own fighter always wears its real look.
- Honest limit: the skins on fighters already in the arena may still download in Simple. What Simple saves is the 20+ lobby skins and the cost of drawing the meshes.

**Dragging:** it still works where it can; the layout is the answer on phones.

# R66-ui8 (2026-10-12): `HeroWars_V47_R66ui8.rbxlx` (client only, replaces ui7)
Peter: "performance now".
- **Effect cap on phones:** at most 90 effect parts are drawn at once (`fxPart`). Extra ones still run their tweens and timers but aren't drawn, so two big powers landing together (Bulwark quake ~60-85 parts plus Solar Hammer) can't spike the frame.
- **Sway only up close:** cape and armour sway (the per-frame spring loop over every rig) skips fighters more than 120 studs from the camera on PC, or 60 on phones. With 12 players and 4 practice dummies, that's most rigs most of the time.
- **Phone performance so far (ui1-ui8):**
  - no depth of field, sun rays or light shadows;
  - far effect bursts skipped;
  - Simple looks, so no lobby-skin downloads and no skin meshes drawn on other fighters;
  - effect-part cap;
  - distant sway skipped;
  - live server size 12;
  - no loading screen.
- **Not done:** Lighting stays Future (Technology 4, build rule). Effect parts are still new parts each time (no pooling); the cap bounds the worst case.
- Tagged `R66-ui8` in src/HeroWarsClient__10.luau.
