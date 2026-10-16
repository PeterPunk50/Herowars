-- Test 5a (Client data model, V58 in Play): pick Solarion and summon the dragon with the HUD's B action.
local Combat = game.ReplicatedStorage:WaitForChild("HeroWars"):WaitForChild("Combat")
Combat:FireServer("Select", "Solarion")
task.wait(3)
Combat:FireServer("Boss", "toggle")
task.wait(1)
local hud = game.Players.LocalPlayer.PlayerGui:FindFirstChild("VyrathHud", true)
return "selected Solarion, sent Boss toggle; VyrathHud gui present: " .. tostring(hud ~= nil)
