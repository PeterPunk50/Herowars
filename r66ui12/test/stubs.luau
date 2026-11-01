-- Roblox stand-ins for the offline BotAI test (prepended to each file by run_sim.sh).
local V = {}
V.__index = V
local function vec(x, y, z) return setmetatable({X = x, Y = y, Z = z}, V) end
V.__add = function(a, b) return vec(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V.__sub = function(a, b) return vec(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V.__mul = function(a, b)
 if type(a) == "number" then return vec(b.X * a, b.Y * a, b.Z * a) end
 if type(b) == "number" then return vec(a.X * b, a.Y * b, a.Z * b) end
 return vec(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V.__unm = function(a) return vec(-a.X, -a.Y, -a.Z) end
V.__index = function(v, k)
 if k == "Magnitude" then return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z) end
 if k == "Unit" then local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z); return m > 0 and vec(v.X / m, v.Y / m, v.Z / m) or vec(0, 0, 0) end
 return V[k]
end
function V.Cross(a, b) return vec(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function V.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
Vector3 = {new = vec, zero = vec(0, 0, 0), yAxis = vec(0, 1, 0)}
Enum = {Material = {Air = "Air", Plastic = "Plastic"}}
function typeof(v) if type(v) == "table" and rawget(v, "__inst") then return "Instance" end return type(v) end
function instanceStub(isPlayer)
 local o = {__inst = true}
 function o:IsA(c) return (c == "Player") == isPlayer end
 return o
end
