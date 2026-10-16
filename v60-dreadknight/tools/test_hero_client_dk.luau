-- V59 Play test (Client data model): pick a hero, fire each action, record what the server sends back.
-- Edit HERO below, then run: studio_mcp.py luau test_hero_client.luau V59 Client
local HERO = "DreadKnight"
local RS = game:GetService("ReplicatedStorage")
local Combat = RS.HeroWars:WaitForChild("Combat")
local plr = game.Players.LocalPlayer
local seen, notes = {}, {}
local conn = Combat.OnClientEvent:Connect(function(kind, a, b, ...)
	if kind == "Attack" and typeof(a) == "Instance" and a == plr.Character then table.insert(seen, tostring(b))
	elseif kind == "Notify" or kind == "Note" then table.insert(notes, tostring(a)) end
end)
Combat:FireServer("Select", HERO)
local t0 = os.clock(); repeat task.wait(0.25) until (plr.Character and plr.Character:GetAttribute("Hero") == HERO) or os.clock() - t0 > 15
task.wait(2.5)
local c = plr.Character
local hum = c and c:FindFirstChildOfClass("Humanoid")
local info = ("hero %s rig %s display %s health %s/%s parts %d shield %s"):format(tostring(c and c:GetAttribute("Hero")), tostring(c and c:GetAttribute("RigName")),
	tostring(hum and hum.DisplayName), tostring(hum and hum.Health), tostring(hum and hum.MaxHealth), c and #c:GetChildren() or 0, tostring(c and c:FindFirstChild("ShieldDisc", true) ~= nil))
local function fire(action, wait) Combat:FireServer(action); task.wait(wait or 1.4) end
for _, a in {"Light", "Light", "Light"} do fire(a, 0.45) end
task.wait(1)
for _, a in {"Heavy", "Skill1", "Skill2", "Skill3", "Interrupt", "Defensive", "Dash"} do fire(a, 2.2) end
local tracks = {}
local animator = hum and hum:FindFirstChildOfClass("Animator")
if animator then for _, tr in animator:GetPlayingAnimationTracks() do table.insert(tracks, ("%s %.2fs"):format(tr.Animation and tr.Animation.Name or "?", tr.Length)) end end
conn:Disconnect()
return table.concat({info, "attacks the server started: " .. table.concat(seen, ", "), "notes: " .. table.concat(notes, " | "), "tracks now: " .. table.concat(tracks, "; ")}, "\n")
