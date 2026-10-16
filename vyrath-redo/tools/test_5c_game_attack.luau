-- Test 5c (Client data model, V58 in Play): face the dragon and throw light attacks for 20 s.
local Combat = game.ReplicatedStorage.HeroWars.Combat
local char = game.Players.LocalPlayer.Character
local root = char and char:FindFirstChild("HumanoidRootPart")
local n = 0
local t0 = os.clock()
while os.clock() - t0 < 20 do
	local d
	for _, m in workspace:GetDescendants() do if m:IsA("Model") and m.Name == "Vyrath" and m:GetAttribute("State") ~= nil then d = m; break end end
	if d and root then
		local p = d:GetPivot().Position
		root.CFrame = CFrame.lookAt(root.Position, Vector3.new(p.X, root.Position.Y, p.Z))
	end
	Combat:FireServer("Light")
	n += 1
	task.wait(0.4)
end
return ("sent %d Light attacks"):format(n)
