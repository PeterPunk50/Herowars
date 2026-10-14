-- HeroEngine Phase 0: runs the Roblox side (NetworkService, HitboxAdapter, the test place's server script)
-- outside Studio against a small mock of the Roblox API, with two fake players. Generated into one file by
-- run_server_mock.py (the Roblox scripts are pasted in as functions). It checks the wiring, not Roblox itself:
-- the real proof is still the two-client test in Studio.
local realRequire = require
local MOCK_LOG = {}

-- Vector3 / CFrame (only what the scripts use) --------------------------------------------------------------
local V = {}
local function v3(x, y, z) return setmetatable({X = x or 0, Y = y or 0, Z = z or 0}, V) end
V.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b) if type(a) == "number" then a, b = b, a end return v3(a.X * b, a.Y * b, a.Z * b) end
V.__index = function(v, k)
 if k == "Magnitude" then return math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2) end
 if k == "Unit" then local m = math.sqrt(v.X ^ 2 + v.Y ^ 2 + v.Z ^ 2); return v3(v.X / m, v.Y / m, v.Z / m) end
 return nil
end
local function vcross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
local Vector3 = {new = v3, zero = v3()}
local C = {}
local function cf(p, look)
 look = look or v3(0, 0, -1)
 local right = vcross(look, v3(0, 1, 0)).Unit
 local up = vcross(right, look)
 return setmetatable({Position = p, LookVector = look, RightVector = right, UpVector = up}, C)
end
C.__mul = function(a, b) -- a * (pure translation b)
 local o = b.Position
 return cf(a.Position + a.RightVector * o.X + a.UpVector * o.Y - a.LookVector * o.Z, a.LookVector)
end
local CFrame = {
 new = function(x, y, z) return cf(v3(x, y, z)) end,
 lookAt = function(a, b) return cf(a, (b - a).Unit) end,
}

-- Instances and signals ------------------------------------------------------------------------------------
local function signal()
 local s = {fns = {}}
 function s:Connect(fn) table.insert(self.fns, fn); return {Disconnect = function() end} end
 function s:Once(fn) return self:Connect(fn) end
 function s:Fire(...) for _, fn in self.fns do fn(...) end end
 return s
end
local Inst = {}
Inst.__index = function(o, k)
 if k == "Parent" then return rawget(o, "_parent") end
 local m = rawget(Inst, k); if m then return m end
 local kids = rawget(o, "_kids"); return kids and kids[k]
end
Inst.__newindex = function(o, k, v)
 if k == "Parent" then
  local old = rawget(o, "_parent"); if old then old._kids[o.Name] = nil end
  rawset(o, "_parent", v); if v then v._kids[o.Name] = o end
 else rawset(o, k, v) end
end
local function inst(className, name, parent)
 local o = setmetatable({ClassName = className, Name = name or className, _kids = {}, _attrs = {}}, Inst)
 if parent then o.Parent = parent end
 return o
end
function Inst:FindFirstChild(n) return self._kids[n] end
function Inst:WaitForChild(n) local c = self._kids[n]; assert(c, "WaitForChild would hang: " .. n); return c end
function Inst:SetAttribute(k, v) self._attrs[k] = v end
function Inst:GetAttribute(k) return self._attrs[k] end
function Inst:IsA(c) return self.ClassName == c end
function Inst:PivotTo(c) self._kids.HumanoidRootPart.CFrame = c end
function Inst:FireClient(p, ...) table.insert(MOCK_LOG, {to = p.Name, args = {...}}) end
function Inst:FireAllClients(...) table.insert(MOCK_LOG, {to = "all", args = {...}}) end
local Instance = {new = function(className)
 local o = inst(className)
 if className == "RemoteEvent" then o.OnServerEvent = signal(); o.OnClientEvent = signal() end
 return o
end}

local ReplicatedStorage = inst("ReplicatedStorage")
local workspace = inst("Workspace")
local Players = inst("Players"); Players.PlayerAdded = signal(); Players.PlayerRemoving = signal(); Players._list = {}
function Players:GetPlayers() return self._list end
local RunService = inst("RunService"); RunService.Heartbeat = signal()
function RunService:IsServer() return true end
local services = {ReplicatedStorage = ReplicatedStorage, Players = Players, RunService = RunService, Workspace = workspace}
local game = {GetService = function(_, n) return assert(services[n], n) end}
local task = {wait = function() end, delay = function() end, spawn = function(f) f() end}
local function warn(...) print("WARN", ...) end

-- A Roblox module in the mock tree: requiring it loads the real file (which takes its Luau CLI branch).
local function moduleAt(parent, name, path)
 local m = inst("ModuleScript", name, parent); m.__path = path; return m
end
local loaded = {}
local function require(x)
 if type(x) == "table" and x.__fn then
  if loaded[x] == nil then loaded[x] = x.__fn() end
  return loaded[x]
 end
 if type(x) == "table" and x.__path then return realRequire(x.__path) end
 return realRequire(x)
end
local HE = inst("Folder", "HeroEngine", ReplicatedStorage)
local Core = inst("Folder", "Core", HE)
for _, n in {"AbilitySystem", "CharacterStats", "CombatRules", "DamageCalculator", "Simulation", "StateMachine"} do
 moduleAt(Core, n, "../Core/" .. n)
end
local Adapters = inst("Folder", "RobloxAdapters", HE)
local HG = inst("Folder", "HeroWarsGame", ReplicatedStorage)
moduleAt(HG, "LegacyRules", "../../HeroWarsGame/LegacyRules")
local Chars = inst("Folder", "Characters", HG)
moduleAt(Chars, "Solarion", "../../HeroWarsGame/Characters/Solarion")
moduleAt(Chars, "Wraithstep", "../../HeroWarsGame/Characters/Wraithstep")
local function robloxModule(parent, name, fn)
 local m = inst("ModuleScript", name, parent); m.__fn = fn; return m
end
