-- Test 1 (Server data model, during Play): the boss loads its clips, animates, hunts the player and breathes on them.
-- Run: studio_mcp.py luau test_1_hunt.luau Vyrath_redo_testbed Server   (about 38 s)
local Players = game:GetService("Players")
local ctl = game.ServerStorage:WaitForChild("VyrathControl", 10)
assert(ctl, "no VyrathControl: BossHarness did not start")
local plr = Players:GetPlayers()[1]
assert(plr and plr.Character, "no player character")
local char = plr.Character
local hum, root = char:FindFirstChildOfClass("Humanoid"), char:FindFirstChild("HumanoidRootPart")
local regen = char:FindFirstChild("Health") -- default 1%/s regen hides small breath ticks
if regen then regen:Destroy() end
hum.MaxHealth, hum.Health = 100, 100

local model = workspace:FindFirstChild("Vyrath")
local animator = model:FindFirstChildWhichIsA("Animator", true)
local function bone(name)
	for _, d in model:GetDescendants() do if d:IsA("Bone") and d.Name == name then return d end end
end
local jaw, tail = bone("Jaw"), bone("Tail_12")
local states, seen = {}, {}
local minDist, firstHit, hitsTaken = math.huge, nil, 0
local lastHp = hum.Health
local jawMove, tailMove = 0, 0
local lastJaw, lastTail = jaw.TransformedWorldCFrame.Position, tail.TransformedWorldCFrame.Position
local t0 = os.clock()
while os.clock() - t0 < 36 do
	task.wait(0.25)
	local s = ctl:Invoke("state")
	if not seen[s.state] then seen[s.state] = true; table.insert(states, ("%s@%.1f"):format(s.state, os.clock() - t0)) end
	local d = (Vector3.new(s.pos.X, 0, s.pos.Z) - Vector3.new(root.Position.X, 0, root.Position.Z)).Magnitude
	minDist = math.min(minDist, d)
	if hum.Health < lastHp then
		hitsTaken += 1
		firstHit = firstHit or os.clock() - t0
	end
	lastHp = hum.Health
	local j, tl = jaw.TransformedWorldCFrame.Position, tail.TransformedWorldCFrame.Position
	jawMove += (j - lastJaw).Magnitude; tailMove += (tl - lastTail).Magnitude
	lastJaw, lastTail = j, tl
end
local tracks = {}
for _, tr in animator:GetPlayingAnimationTracks() do table.insert(tracks, ("%s %.2fs"):format(tr.Animation and tr.Animation.Name or "?", tr.Length)) end
return table.concat({
	"states seen: " .. table.concat(states, ", "),
	("closest approach %.1f studs (player at spawn, z 70)"):format(minDist),
	("player health 100 -> %d, %d damage ticks, first at %s s"):format(hum.Health, hitsTaken, firstHit and ("%.1f"):format(firstHit) or "-"),
	("jaw bone travelled %.1f studs, tail tip %.1f studs over 36 s"):format(jawMove, tailMove),
	"playing tracks now: " .. (#tracks > 0 and table.concat(tracks, "; ") or "none"),
}, "\n")
