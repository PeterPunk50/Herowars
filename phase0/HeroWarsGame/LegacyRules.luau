-- The HeroWars Rules module that the live game uses, so the character files read their numbers from the
-- one place Peter, Claude and Codex already tune. Nothing is copied: change Rules, and the engine follows.
-- In Roblox: ReplicatedStorage.HeroWars.Rules (where the game keeps it; the Phase 0 test place maps the
-- r66ui11 file there). Offline (Luau CLI tests): the r66ui11 source in this repo. When a newer build lands
-- in the repo, point the path below at it.
if script then
 return require(game:GetService("ReplicatedStorage"):WaitForChild("HeroWars"):WaitForChild("Rules"))
end
return require("../../r66ui11/src/Rules__3")
