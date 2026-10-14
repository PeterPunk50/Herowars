-- HeroEngine Phase 0 Roblox adapter: turns characters in the workspace into the engine's plain boxes and asks
-- CombatRules which fighters a strike touches. Same shapes as HeroWars Main: a Width x Height x Range box
-- along the aim, against a standard R15 hurtbox, with reach measured to the hurtbox edge.
-- Not yet ported from Main (Phase 1): lag-compensated rewind, crouch/air/down hurtbox states, limb boxes,
-- line-of-sight walls, Hero Scale (Bulwark's bigger hurtbox).
local Core = script.Parent.Parent.Core
local CombatRules = require(Core.CombatRules)

local HitboxAdapter = {}
-- Standard R15 body around the HumanoidRootPart: 4 wide, 5.2 tall, 2 deep, centre 0.4 below the root.
HitboxAdapter.HurtSize = {4, 5.2, 2}
HitboxAdapter.HurtOffset = -0.4

local function arr(v) return {v.X, v.Y, v.Z} end
HitboxAdapter.toArray = arr

function HitboxAdapter.hurtbox(root)
 local cf = root.CFrame * CFrame.new(0, HitboxAdapter.HurtOffset, 0)
 return CombatRules.boxFacing(arr(cf.Position), arr(cf.LookVector), HitboxAdapter.HurtSize), arr(cf.Position)
end

-- fighters: engine fighters, each with .root (HumanoidRootPart). Returns targets for Simulation.tick.
function HitboxAdapter.targets(attacker, action, fighters)
 local out = {}
 local origin = arr(attacker.root.Position)
 local strike = CombatRules.strikeBox(origin, action.aim, action.move)
 for _, t in fighters do
  if t ~= attacker and t.root and t.root.Parent then
   local hurt, centre = HitboxAdapter.hurtbox(t.root)
   if CombatRules.boxesOverlap(strike, hurt) and CombatRules.inReach(origin, centre, action.move, HitboxAdapter.HurtSize) then
    table.insert(out, {fighter = t, distance = CombatRules.len(CombatRules.sub(centre, origin))})
   end
  end
 end
 return out
end

return HitboxAdapter
