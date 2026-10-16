-- Test 4 (Server data model, during Play): where does the tail actually pass during the sweep's contact frames,
-- and does a player standing on that path get hit?  Run: studio_mcp.py luau test_4_sweep_path.luau Vyrath_redo_testbed Server
local Players = game:GetService("Players")
local ctl = game.ServerStorage:WaitForChild("VyrathControl", 10)
local plr = Players:GetPlayers()[1]
local char = plr.Character
local hum, root = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
local regen = char:FindFirstChild("Health")
if regen then regen:Destroy() end
local model = workspace.Vyrath
local bones = {}
for _, d in model:GetDescendants() do if d:IsA("Bone") then bones[d.Name] = d end end
local function st() return ctl:Invoke("state") end
local out = {}
local function waitFree(limit)
	local t0 = os.clock()
	while os.clock() - t0 < limit do
		local s = st().state
		if s == "Idle" or s == "Walk" or s == "Charge_Run" then return end
		task.wait(0.2)
	end
end

-- park the player far away so the boss idles, then play the sweep on demand and record the tail in the boss's frame
waitFree(10)
root.CFrame = CFrame.new(0, 3, 160)
task.wait(0.5)
local s = st()
local yaw = math.rad(s.yaw)
local base = CFrame.new(s.pos) * CFrame.Angles(0, yaw, 0) -- local -Z = the boss's forward
ctl:Invoke("play", "Sig_TailSweep")
local samples = {}
local t0 = os.clock()
while os.clock() - t0 < 5 do
	task.wait()
	local f = st().frame
	if f >= 50 and f <= 60 then
		for i = 4, 12 do
			local b = bones[("Tail_%02d"):format(i)]
			table.insert(samples, base:PointToObjectSpace(b.TransformedWorldCFrame.Position))
		end
	elseif f > 60 then break end
end
local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
for _, p in samples do lo, hi = lo:Min(p), hi:Max(p) end
table.insert(out, ("tail bones 4-12 during contact (boss frame; x right, y up, z back): x %.1f..%.1f, y %.1f..%.1f, z %.1f..%.1f (%d samples)"):format(lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z, #samples))
-- how close does the tail get to where test 3 stood the player (10 studs off a flank, 4 back, root 3 up)?
for _, side in { { "left", -10 }, { "right", 10 } } do
	local p = Vector3.new(side[2], 3 - s.pos.Y, 4)
	local best = math.huge
	for _, q in samples do best = math.min(best, (q - p).Magnitude) end
	table.insert(out, ("closest tail sample to a player 10 off the %s flank, 4 back: %.1f studs (hit radius 4.25)"):format(side[1], best))
end
-- stand the player on a contact sample at root height and sweep again
waitFree(8)
ctl:Invoke("cooldowns")
local pick = samples[math.floor(#samples / 2)]
s = st(); yaw = math.rad(s.yaw); base = CFrame.new(s.pos) * CFrame.Angles(0, yaw, 0)
local target = base:PointToWorldSpace(Vector3.new(pick.X, 0, pick.Z)) + Vector3.new(0, 3, 0)
hum.MaxHealth, hum.Health = 100, 100
root.CFrame = CFrame.new(target); root.Anchored = true -- hold still so the boss does not turn away first
ctl:Invoke("play", "Sig_TailSweep")
local hit = false; t0 = os.clock()
while os.clock() - t0 < 5 do task.wait(0.05); if hum.Health < 100 then hit = true; break end end
root.Anchored = false
table.insert(out, ("player held on the tail's path (%.1f, %.1f in the boss frame): hit %s, health %d"):format(pick.X, pick.Z, tostring(hit), hum.Health))
return table.concat(out, "\n")
