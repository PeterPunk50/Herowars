-- HeroEngine Phase 0: the shared combat rules every game on the engine uses.
-- Platform-neutral: plain numbers and tables only (no Roblox types), so the same file runs in the Luau CLI,
-- in Roblox and, as a spec, in any later engine. Vectors are {x, y, z} arrays.
-- Ported from HeroWars Rules (r66ui11); Tests/run.luau checks every function here against the original.
local CombatRules = {}

CombatRules.Hz = 60 -- one logical tick = 1/60 s; all frame data is in ticks
CombatRules.ParryFrames = 9 -- a block raised this recently parries instead of blocking
CombatRules.BlockScale = 0.2 -- share of damage that gets through a block
CombatRules.StunDR = {Min = 60, Reset = 1080, Scale = {1, 0.5, 0.25}, ImmuneStun = 18}

function CombatRules.seconds(ticks) return ticks / CombatRules.Hz end
function CombatRules.ticks(seconds) return math.floor(seconds * CombatRules.Hz + 0.5) end

-- Which part of a move a frame is in. extra = added recovery (a whiffed attack recovers slower).
function CombatRules.phase(move, frame, extra)
 if frame <= move.Startup then return "Startup" end
 if frame <= move.Startup + move.Active then return "Active" end
 if frame <= move.Startup + move.Active + move.Recovery + (extra or 0) then return "Recovery" end
 return "Idle"
end

-- What a defender's guard does to one blow. Returns the damage that gets through and the result name.
function CombatRules.defend(damage, blocking, facing, parry, breaksGuard, invulnerable, throw)
 if invulnerable then return 0, "Dodge" end
 if throw then return damage, "Throw" end
 if blocking and facing then
  if parry then return 0, "Parry" end
  if not breaksGuard then return math.floor(damage * CombatRules.BlockScale), "Block" end
  return damage, "GuardBreak"
 end
 return damage, "Hit"
end

-- WoW-style stun diminishing returns. count = long stuns already taken in this DR window.
function CombatRules.drStun(stun, count)
 local dr = CombatRules.StunDR
 if stun < dr.Min then return stun, false end
 local k = dr.Scale[count + 1]
 if not k then return dr.ImmuneStun, true end
 return math.floor(stun * k + 0.5), false
end

-- Vector helpers ----------------------------------------------------------------------------------------
local function dot(u, v) return u[1]*v[1] + u[2]*v[2] + u[3]*v[3] end
local function cross(u, v) return {u[2]*v[3]-u[3]*v[2], u[3]*v[1]-u[1]*v[3], u[1]*v[2]-u[2]*v[1]} end
local function sub(u, v) return {u[1]-v[1], u[2]-v[2], u[3]-v[3]} end
local function len(u) return math.sqrt(dot(u, u)) end
local function unit(u, fallback)
 local l = len(u)
 if l < 1e-6 then return fallback end
 return {u[1]/l, u[2]/l, u[3]/l}
end
CombatRules.dot, CombatRules.cross, CombatRules.sub, CombatRules.len, CombatRules.unit = dot, cross, sub, len, unit

-- Oriented boxes: {p = centre, a = {right, up, look} unit axes, h = half sizes}.
local function radius(box, axis)
 return box.h[1]*math.abs(dot(box.a[1], axis)) + box.h[2]*math.abs(dot(box.a[2], axis)) + box.h[3]*math.abs(dot(box.a[3], axis))
end
-- Separating axis test.
function CombatRules.boxesOverlap(A, B)
 local d = sub(B.p, A.p)
 local axes = {A.a[1], A.a[2], A.a[3], B.a[1], B.a[2], B.a[3]}
 for i = 1, 3 do for j = 1, 3 do
  local c = cross(A.a[i], B.a[j])
  if dot(c, c) > 1e-9 then table.insert(axes, c) end
 end end
 for _, axis in axes do
  if math.abs(dot(d, axis)) > radius(A, axis) + radius(B, axis) + 1e-6 then return false end
 end
 return true
end

-- The box a fighter facing `look` (flattened to the ground) occupies: centre `at`, size {w, h, d}.
function CombatRules.boxFacing(at, look, size)
 local flat = unit({look[1], 0, look[3]}, {0, 0, -1})
 local up = {0, 1, 0}
 local right = cross(flat, up)
 return {p = {at[1], at[2], at[3]}, a = {right, up, flat}, h = {size[1]/2, size[2]/2, size[3]/2}}
end

-- A melee move's strike box, as HeroWars builds it: Width x Height x Range, starting at the attacker's
-- root and reaching Range studs along the aim.
function CombatRules.strikeBox(origin, aim, move)
 local look = unit(aim, {0, 0, -1})
 local centre = {origin[1] + look[1]*move.Range/2, origin[2] + look[2]*move.Range/2, origin[3] + look[3]*move.Range/2}
 local up0 = math.abs(look[2]) > 0.99 and {0, 0, 1} or {0, 1, 0}
 local right = unit(cross(look, up0), {1, 0, 0})
 local up = cross(right, look)
 return {p = centre, a = {right, up, look}, h = {move.Width/2, move.Height/2, move.Range/2}}
end

-- Reach is measured to the edge of the target's hurtbox, so it doesn't depend on the angle.
function CombatRules.inReach(origin, targetPos, move, hurtSize)
 local reach = (move.Aoe or move.Range) + math.max(hurtSize[1], hurtSize[3]) / 2
 return len(sub(targetPos, origin)) <= reach
end

-- An input vector from a client: three numbers, unit length (rejects NaN and oversized values).
function CombatRules.validUnit(v)
 if type(v) ~= "table" then return false end
 for i = 1, 3 do
  local x = v[i]
  if type(x) ~= "number" or x ~= x or math.abs(x) > 1.01 then return false end
 end
 local l2 = dot(v, v)
 return l2 >= 0.97 and l2 <= 1.03
end

return CombatRules
