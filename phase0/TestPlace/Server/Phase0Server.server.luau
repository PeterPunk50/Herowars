-- HeroEngine Phase 0 integration test (server). Unpublished test place only; the live game never runs this.
-- Player 1 plays Solarion, player 2 Wraithstep. Clients only ask "use Light" / "use Heavy"; this server picks
-- the target, runs the engine (AbilitySystem -> Simulation -> HitboxAdapter -> DamageCalculator) at 60 Hz and
-- owns everyone's health. The test passes when a Solarion attack, run through the engine, takes the right
-- amount off Wraithstep on the server and both clients are told.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Engine = ReplicatedStorage:WaitForChild("HeroEngine")
local Core = Engine:WaitForChild("Core")
local Adapters = Engine:WaitForChild("RobloxAdapters")
local AbilitySystem = require(Core.AbilitySystem)
local CharacterStats = require(Core.CharacterStats)
local Simulation = require(Core.Simulation)
local CombatRules = require(Core.CombatRules)
local NetworkService = require(Adapters.NetworkService)
local HitboxAdapter = require(Adapters.HitboxAdapter)
local Game = ReplicatedStorage:WaitForChild("HeroWarsGame")
local Rules = require(Game.LegacyRules)
local HEROES = {"Solarion", "Wraithstep"}
local CONFIG = {Solarion = require(Game.Characters.Solarion), Wraithstep = require(Game.Characters.Wraithstep)}
-- Where each hero stands for the test: 4 studs apart, facing each other.
local SPOT = {Solarion = CFrame.lookAt(Vector3.new(0, 3, 8), Vector3.new(0, 3, 0)),
 Wraithstep = CFrame.lookAt(Vector3.new(0, 3, 4), Vector3.new(0, 3, 12))}
local INPUTS = {Light = true, Heavy = true}
-- Rig check: key 3 cycles your body through the rigged models in ServerStorage.Rigs (Peter's Import 3D meshes,
-- made Studio-ready by rigging/tools/fix_studio_import.py) and back to your own avatar. Looks only: your hero,
-- health and abilities stay the same.
local Rigs = game:GetService("ServerStorage"):WaitForChild("Rigs")
local BODIES = {}
for _, m in Rigs:GetChildren() do table.insert(BODIES, m.Name) end
table.sort(BODIES)
local bodyIndex = {} -- player -> 0 (own avatar) .. #BODIES
local swapping = {} -- player -> true while a body swap keeps the same fighter

local heroOf = {} -- player -> hero name
local fighterOf = {} -- player -> engine fighter
local world = {fighters = {}}
local tick = 0
local passes = 0

local net
local function log(text)
 print("[Phase0] " .. text)
 net.broadcast("Log", {text = text})
end

local function rebuildWorld()
 world.fighters = {}
 for _, f in fighterOf do table.insert(world.fighters, f) end
end

local function freeHero()
 local taken = {}
 for _, h in heroOf do taken[h] = true end
 for _, h in HEROES do if not taken[h] then return h end end
 return nil
end

local function place(player)
 local f = fighterOf[player]
 local char = player.Character
 if f and char then char:PivotTo(SPOT[f.hero]) end
end

local function onCharacter(player, char)
 local hero = heroOf[player]
 if not hero then return end
 local hum = char:WaitForChild("Humanoid")
 local root = char:WaitForChild("HumanoidRootPart")
 local old = fighterOf[player]
 if old and old.model == char then return end -- already bound (CharacterAdded and the swap both call this)
 if swapping[player] and old then
  -- Same fighter, new body: keep health, cooldowns and state.
  old.model, old.root, old.hum = char, root, hum
  hum.MaxHealth = old.maxHp; hum.Health = old.hp; hum.BreakJointsOnDeath = false
  char:SetAttribute("Hero", hero)
  return
 end
 bodyIndex[player] = 0
 local f = CharacterStats.new(player.UserId, CONFIG[hero])
 f.player, f.model, f.root, f.hum = player, char, root, hum
 fighterOf[player] = f
 rebuildWorld()
 hum.MaxHealth = f.maxHp; hum.Health = f.hp
 hum.BreakJointsOnDeath = false
 char:SetAttribute("Hero", hero)
 task.wait(0.2)
 place(player)
end

Players.PlayerAdded:Connect(function(player)
 local hero = freeHero()
 heroOf[player] = hero
 player:SetAttribute("Hero", hero or "Spectator")
 player.CharacterAdded:Connect(function(char) onCharacter(player, char) end)
 if player.Character then onCharacter(player, player.Character) end
end)
Players.PlayerRemoving:Connect(function(player)
 heroOf[player] = nil; fighterOf[player] = nil; rebuildWorld()
end)

-- The nearest other fighter within the hero's tab range, else straight ahead (the server aims, not the client).
local function aimFor(f)
 local best, bestD
 for _, t in world.fighters do
  if t ~= f and t.hp > 0 and t.root.Parent then
   local d = (t.root.Position - f.root.Position).Magnitude
   if d <= Rules.MaxRange and (not bestD or d < bestD) then best, bestD = t, d end
  end
 end
 local dir = best and (best.root.Position - f.root.Position) or f.root.CFrame.LookVector
 if dir.Magnitude < 0.01 then dir = f.root.CFrame.LookVector end
 return HitboxAdapter.toArray(dir.Unit)
end

-- What the old game would have done, from the legacy Rules alone (not from the engine), to check against.
local function expected(ability, result)
 local d = Rules.heroMove("Solarion", ability).Damage
 if result.sweet then d *= 1.25 end
 if result.result == "Counter" then d *= 1.2 end
 return math.floor(d + 0.5)
end

local adapter = {
 targets = function(f, action) return HitboxAdapter.targets(f, action, world.fighters) end,
 onHit = function(f, t, result, action)
  if t.hum and t.hum.Parent then t.hum.Health = t.hp end
  net.broadcast("Hit", {attacker = f.model, target = t.model, attackerHero = f.hero, targetHero = t.hero,
   title = action.move.Title, damage = result.damage, result = result.result, before = result.before, after = result.after})
  log(string.format("%s %s hit %s for %d (%d -> %d) [%s]", f.hero, action.move.Title, t.hero, result.damage,
   result.before, result.after, result.result))
  if f.hero == "Solarion" and t.hero == "Wraithstep" and f.player ~= t.player then
   local want = expected(action.name, result)
   local serverHealth = t.hum and math.floor(t.hum.Health + 0.5)
   if result.damage == want and result.before - result.after == want and serverHealth == t.hp then
    passes += 1
    local text = string.format("PASS %d: Solarion %s damaged Wraithstep through HeroEngine for %d (%d -> %d), server Humanoid = %d",
     passes, action.move.Title, want, result.before, result.after, serverHealth)
    workspace:SetAttribute("Phase0Result", text)
    log(text)
   else
    local text = string.format("FAIL: %s expected %d, engine said %d (%d -> %d), server Humanoid = %s",
     action.move.Title, want, result.damage, result.before, result.after, tostring(serverHealth))
    workspace:SetAttribute("Phase0Result", text)
    warn("[Phase0] " .. text)
    net.broadcast("Log", {text = text})
   end
  end
 end,
}

net = NetworkService.server("HeroEngine", {
 Use = function(player, data)
  local f = fighterOf[player]
  if not f or not INPUTS[data.input] then return end
  local ok, why = AbilitySystem.tryUse(f, data.input, tick, aimFor(f))
  net.send(player, "Ack", {input = data.input, ok = ok, why = not ok and why or nil, ability = ok and why or nil})
  if ok then
   local a = f.config.Abilities[why]
   net.broadcast("Attack", {model = f.model, title = a.Title, startup = CombatRules.seconds(a.Startup)})
  end
 end,
 Body = function(player)
  local f = fighterOf[player]
  local old = player.Character
  if not f or not old or f.hp <= 0 or #BODIES == 0 or swapping[player] then return end
  local i = ((bodyIndex[player] or 0) + 1) % (#BODIES + 1)
  bodyIndex[player] = i
  local at = old:GetPivot()
  swapping[player] = true
  local char
  if i == 0 then
   swapping[player] = nil
   bodyIndex[player] = 0
   player:LoadCharacter() -- back to the player's own avatar (a fresh fighter at full health)
   log(player.Name .. " is back in their own avatar")
   return
  end
  char = Rigs[BODIES[i]]:Clone()
  char.Name = player.Name
  local hum = char:FindFirstChildOfClass("Humanoid")
  hum.RequiresNeck = false -- the import names the neck joint HeadMotor6D, not Neck
  hum.BreakJointsOnDeath = false
  local animate = old:FindFirstChild("Animate")
  if animate then animate:Clone().Parent = char end -- Roblox's default walk/idle animations
  char.PrimaryPart = char:FindFirstChild("HumanoidRootPart")
  char:PivotTo(at)
  char.Parent = workspace
  player.Character = char
  onCharacter(player, char)
  old:Destroy()
  swapping[player] = nil
  log(string.format("%s (%s) is now wearing %s", player.Name, f.hero, BODIES[i]))
 end,
 Reset = function(player)
  -- Test convenience: everyone back to full health on their spot.
  for p, f in fighterOf do
   f.hp = f.maxHp; f.action = nil; f.cooldowns = {}; f.ramp = {}; f.gcd = 0
   f.state.name, f.state.untilTick = "Idle", nil
   if f.hum.Parent then f.hum.Health = f.hp end
   place(p)
  end
  log(player.Name .. " reset the test")
 end,
})

-- 60 Hz fixed step, like HeroWars Main.
local acc = 0
RunService.Heartbeat:Connect(function(dt)
 acc = math.min(acc + dt, 0.25)
 while acc >= 1 / CombatRules.Hz do
  acc -= 1 / CombatRules.Hz
  tick += 1
  Simulation.tick(world, tick, adapter)
 end
end)

workspace:SetAttribute("Phase0Result", "waiting: Solarion has not hit Wraithstep yet")
print("[Phase0] HeroEngine test server ready. Player 1 = Solarion, player 2 = Wraithstep.")
