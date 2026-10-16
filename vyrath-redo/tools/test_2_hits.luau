-- Test 2 (Server data model, during Play): weak points, weak-point break and stagger, tail sweep on a flanking player, death.
-- Run: studio_mcp.py luau test_2_hits.luau Vyrath_redo_testbed Server   (about 30 s)
local Players = game:GetService("Players")
local ctl = game.ServerStorage:WaitForChild("VyrathControl", 10)
local plr = Players:GetPlayers()[1]
local char = plr.Character
local hum, root = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
local regen = char:FindFirstChild("Health")
if regen then regen:Destroy() end
hum.MaxHealth, hum.Health = 100, 100
local out = {}
local function say(...) table.insert(out, table.concat({...}, " ")) end
local function st() return ctl:Invoke("state") end

-- 1. body hit against throat hit (pivot height is the ground, so aim at the chest from above the pivot)
local s0 = st()
local body = Vector3.new(s0.pos.X, 9, s0.pos.Z)
local throat = ctl:Invoke("socket", "Socket_Weak_Throat")
local d1 = ctl:Invoke("hit", 20, body, "test")
local d2 = ctl:Invoke("hit", 20, throat, "test")
say(("hit 20 on the body -> %s damage, hit 20 on the throat socket -> %s damage"):format(tostring(d1), tostring(d2)))

-- 2. throat hits until the weak point breaks
local broke, n = false, 0
for i = 1, 12 do
	throat = ctl:Invoke("socket", "Socket_Weak_Throat")
	ctl:Invoke("hit", 20, throat, "test"); n = i
	task.wait(0.05)
	if st().state == "Stagger_WeakpointBreak" then broke = true; break end
end
say(("throat broke after %d more hits: %s, state %s"):format(n, tostring(broke), st().state))
task.wait(3)
local s = st()
throat = ctl:Invoke("socket", "Socket_Weak_Throat")
local d3 = ctl:Invoke("hit", 20, throat, "test")
say(("during the stagger (frame %.0f, exposed %s) a throat hit 20 -> %s damage"):format(s.frame, tostring(s.exposed), tostring(d3)))

-- 3. tail sweep: wait out the stagger, then stand the player 10 studs off the boss's flank
local t0 = os.clock()
while st().state == "Stagger_WeakpointBreak" and os.clock() - t0 < 8 do task.wait(0.2) end
ctl:Invoke("cooldowns")
s = st()
local yaw = math.rad(s.yaw)
local fwd = Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
local side = Vector3.new(fwd.Z, 0, -fwd.X)
root.CFrame = CFrame.new(Vector3.new(s.pos.X, 3, s.pos.Z) + side * 10 - fwd * 4)
local hp0, swept, sweepState = hum.Health, false, false
t0 = os.clock()
while os.clock() - t0 < 8 do
	task.wait(0.1)
	if st().state == "Sig_TailSweep" then sweepState = true end
	if hum.Health < hp0 then swept = true end
	if swept and sweepState then break end
end
say(("flanking player: tail sweep played %s, player hit %s (health %d -> %d)"):format(tostring(sweepState), tostring(swept), hp0, hum.Health))

-- 4. death: body hits of 60 until HP 0, then check it stays down
local hits = 0
while st().hp > 0 and hits < 80 do
	ctl:Invoke("hit", 60, Vector3.new(st().pos.X, 9, st().pos.Z), "test"); hits += 1
	task.wait(0.02)
end
task.wait(2)
local a = st()
task.wait(4)
local b = st()
say(("death: %d hits of 60, hp %d, state %s, still %s 4 s later (frame %.0f -> %.0f)"):format(hits, a.hp, a.state, b.state, a.frame, b.frame))
return table.concat(out, "\n")
