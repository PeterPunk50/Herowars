-- Test 5b (Server data model, V58 in Play): watch the summoned dragon hunt and breathe on the player's hero for 36 s.
local Players = game:GetService("Players")
local plr = Players:GetPlayers()[1]
local function dragon()
	for _, m in workspace:GetDescendants() do
		if m:IsA("Model") and m.Name == "Vyrath" and m:GetAttribute("State") ~= nil then return m end
	end
end
local d = dragon()
if not d then return "no summoned Vyrath with a State attribute in workspace" end
local char = plr.Character
local hum = char and char:FindFirstChildOfClass("Humanoid")
local root = char and char:FindFirstChild("HumanoidRootPart")
local hp0 = hum and hum.Health or -1
local states, seen, minDist = {}, {}, math.huge
local t0 = os.clock()
while os.clock() - t0 < 36 do
	task.wait(0.25)
	local s = d:GetAttribute("State")
	if s and not seen[s] then seen[s] = true; table.insert(states, ("%s@%.1f"):format(s, os.clock() - t0)) end
	if root then
		local p = d:GetPivot().Position
		minDist = math.min(minDist, (Vector3.new(p.X, 0, p.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude)
	end
end
return table.concat({
	("dragon at %s, HP %s"):format(tostring(d:GetPivot().Position), tostring(d:GetAttribute("HP"))),
	"states: " .. table.concat(states, ", "),
	("closest approach to the hero %.1f studs"):format(minDist),
	("hero %s health %d -> %d"):format(char and char.Name or "?", hp0, hum and hum.Health or -1),
}, "\n")
