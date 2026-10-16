-- Test 3 (Server data model, fresh Play): tail sweep against a player standing off each flank.
-- Run: studio_mcp.py luau test_3_sweep_sides.luau Vyrath_redo_testbed Server   (about 30 s)
local Players = game:GetService("Players")
local ctl = game.ServerStorage:WaitForChild("VyrathControl", 10)
local plr = Players:GetPlayers()[1]
local char = plr.Character
local hum, root = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
local regen = char:FindFirstChild("Health")
if regen then regen:Destroy() end
local out = {}
local function st() return ctl:Invoke("state") end
local function waitFree(limit)
	local t0 = os.clock()
	while os.clock() - t0 < limit do
		local s = st().state
		if s == "Idle" or s == "Walk" or s == "Charge_Run" then return true end
		task.wait(0.2)
	end
	return false
end
for _, side in { { "left", -1 }, { "right", 1 } } do
	waitFree(10)
	hum.MaxHealth, hum.Health = 100, 100
	ctl:Invoke("cooldowns")
	local s = st()
	local yaw = math.rad(s.yaw)
	local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
	local right = Vector3.new(-fwd.Z, 0, fwd.X) -- fwd turned 90 degrees clockwise seen from above
	root.CFrame = CFrame.new(Vector3.new(s.pos.X, 3, s.pos.Z) + right * side[2] * 10 - fwd * 4)
	root.AssemblyLinearVelocity = Vector3.zero
	local played, hit, t0 = false, false, os.clock()
	while os.clock() - t0 < 7 do
		task.wait(0.1)
		if st().state == "Sig_TailSweep" then played = true end
		if hum.Health < 100 then hit = true end
		if played and hit then break end
	end
	table.insert(out, ("player 10 studs off the %s flank: sweep played %s, player hit %s (health %d)"):format(side[1], tostring(played), tostring(hit), hum.Health))
end
return table.concat(out, "\n")
