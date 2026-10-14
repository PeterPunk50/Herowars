-- The test: two players join, Solarion jabs Wraithstep, the server must report PASS. ------------------------
local passed, failed = 0, 0
local function check(name, cond, detail)
 if cond then passed += 1 else failed += 1; print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or "")) end
end
local function makeChar(name)
 local char = inst("Model", name)
 local hum = inst("Humanoid", "Humanoid", char); hum.Health = 100; hum.MaxHealth = 100
 local root = inst("Part", "HumanoidRootPart", char); root.CFrame = CFrame.new(0, 3, 30)
 setmetatable(root, {__index = function(o, k)
  if k == "Position" then return rawget(o, "CFrame").Position end
  return Inst.__index(o, k)
 end, __newindex = Inst.__newindex})
 return char, hum
end
MAKE_CHAR = makeChar
local function fakePlayer(name, id)
 local p = inst("Player", name); p.UserId = id; p.CharacterAdded = signal()
 local char, hum = makeChar(name .. "Character"); char.Parent = workspace
 p.Character = char
 table.insert(Players._list, p)
 return p, char, hum
end
local remote = ReplicatedStorage.HeroEngineNet.HeroEngine
local p1, c1, h1 = fakePlayer("Player1", 1)
local p2, c2, h2 = fakePlayer("Player2", 2)
Players.PlayerAdded:Fire(p1)
Players.PlayerAdded:Fire(p2)
check("player 1 is Solarion", p1:GetAttribute("Hero") == "Solarion")
check("player 2 is Wraithstep", p2:GetAttribute("Hero") == "Wraithstep")
check("Solarion health from Rules", h1.MaxHealth == 115 and h1.Health == 115, h1.Health)
check("placed 4 studs apart", math.abs((c1.HumanoidRootPart.Position - c2.HumanoidRootPart.Position).Magnitude - 4) < 1e-6)
local function beat(n) for _ = 1, n do RunService.Heartbeat:Fire(1 / 60) end end
beat(5)
-- A client that tries to send damage or an unknown action is ignored.
remote.OnServerEvent:Fire(p1, "Damage", {target = c2, amount = 999})
remote.OnServerEvent:Fire(p1, "Use", {input = "Nuke"})
beat(30)
check("forged requests change nothing", h2.Health == 100, h2.Health)
remote.OnServerEvent:Fire(p1, "Use", {input = "Light"})
remote.OnServerEvent:Fire(p1, "Use", {input = "Light"}) -- pressed again mid-swing: refused
beat(30)
check("Wraithstep's server Humanoid 100 -> 94", h2.Health == 94, h2.Health)
local result = workspace:GetAttribute("Phase0Result")
check("server reports PASS", type(result) == "string" and result:sub(1, 4) == "PASS", result)
local refused, hits = false, 0
for _, e in MOCK_LOG do
 if e.args[1] == "Ack" and e.args[2].ok == false and e.args[2].why == "busy:Startup" then refused = true end
 if e.to == "all" and e.args[1] == "Hit" then hits += 1 end
end
check("second press while busy refused", refused)
check("both clients told about one hit", hits == 1, hits)
-- Rig check: Wraithstep swaps into the rigged body, keeps his health, and still takes Solarion's hits.
beat(60)
remote.OnServerEvent:Fire(p2, "Body", {})
local rig = p2.Character
check("Wraithstep now wears the rig", rig ~= c2 and rig.Name == "Player2" and c2._destroyed == true)
check("rig keeps his health (94)", rig.Humanoid.Health == 94, rig.Humanoid.Health)
check("rig placed where he stood", (rig.HumanoidRootPart.Position - c2.HumanoidRootPart.Position).Magnitude < 1e-6)
check("rig neck check off", rig.Humanoid.RequiresNeck == false)
remote.OnServerEvent:Fire(p1, "Use", {input = "Light"})
beat(30)
check("Sun Jab hits the rigged Wraithstep: 94 -> 88", rig.Humanoid.Health == 88, rig.Humanoid.Health)
result = workspace:GetAttribute("Phase0Result")
check("second PASS", type(result) == "string" and result:sub(1, 6) == "PASS 2", result)
-- Spam is rate-limited: 100 requests in the same instant, at most 30 handled.
local acks0 = 0; for _, e in MOCK_LOG do if e.args[1] == "Ack" then acks0 += 1 end end
for _ = 1, 100 do remote.OnServerEvent:Fire(p2, "Use", {input = "Light"}) end
local acks1 = 0; for _, e in MOCK_LOG do if e.args[1] == "Ack" then acks1 += 1 end end
check("rate limit holds", acks1 - acks0 <= 30, acks1 - acks0)
print("\nserver says: " .. tostring(result))
print(string.format("%d passed, %d failed", passed, failed))
if failed > 0 then error("server mock tests failed", 0) end
