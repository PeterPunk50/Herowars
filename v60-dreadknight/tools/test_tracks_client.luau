-- V59 Play test (Client): which animation track plays 0.3 s into each of the current hero's moves (lengths identify captures).
local Combat = game.ReplicatedStorage.HeroWars.Combat
local hum = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
local animator = hum:FindFirstChildOfClass("Animator")
local out = {}
for _, a in {"Light", "Heavy", "Skill1", "Skill2", "Skill3", "Interrupt", "Defensive"} do
	Combat:FireServer(a); task.wait(0.3)
	local l = {}
	for _, tr in animator:GetPlayingAnimationTracks() do if tr.IsPlaying then table.insert(l, ("%.2fs@%.2f"):format(tr.Length, tr.Speed)) end end
	table.insert(out, a .. ": " .. table.concat(l, " "))
	task.wait(2.2)
end
Combat:FireServer("Block", true); task.wait(0.6)
local l = {}; for _, tr in animator:GetPlayingAnimationTracks() do if tr.IsPlaying then table.insert(l, ("%.2fs"):format(tr.Length)) end end
table.insert(out, "Block: " .. table.concat(l, " ") .. " blocking=" .. tostring(hum.Parent:GetAttribute("Blocking")))
Combat:FireServer("Block", false)
return table.concat(out, "\n")
