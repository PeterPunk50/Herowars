-- HeroEngine Phase 0: one server tick of combat, shared by the Roblox server and the offline tests, so the
-- Studio integration test and `Tests/run.luau` run the same code.
-- Like HeroWars Main, contacts found in a tick are applied together after every fighter has stepped, so two
-- blows landing on the same tick trade instead of the first cancelling the second.
local AbilitySystem = if script then require(script.Parent.AbilitySystem) else require("./AbilitySystem")
local DamageCalculator = if script then require(script.Parent.DamageCalculator) else require("./DamageCalculator")
local CharacterStats = if script then require(script.Parent.CharacterStats) else require("./CharacterStats")

local Simulation = {}

-- world = {fighters = {f, ...}}
-- adapter = {
--  targets(f, action) -> {{fighter = t, distance = studs}, ...}   (geometry: CombatRules boxes or Roblox)
--  defender(t, f) -> {blocking?, facing?, parry?, invulnerable?, absorb?}   (optional)
--  onHit(f, t, result, action)   (optional: mirror health, send effects)
-- }
function Simulation.tick(world, now, adapter)
 local contacts = {}
 for _, f in world.fighters do
  if CharacterStats.isAlive(f) and AbilitySystem.step(f, now) then
   for _, c in adapter.targets(f, f.action) do
    local t = c.fighter
    if t ~= f and CharacterStats.isAlive(t) and AbilitySystem.canHit(f, t.id) then
     f.action.hit[t.id] = true -- one contact per target per pulse, even before it is applied
     table.insert(contacts, {f = f, t = t, action = f.action, distance = c.distance, counter = AbilitySystem.inStartup(t)})
    end
   end
  end
 end
 local results = {}
 for _, c in contacts do
  local f, t, act = c.f, c.t, c.action
  local mods = f.config.DamageModifiers and f.config.DamageModifiers(f, t, act, now) or nil
  local result = DamageCalculator.compute({
   move = act.move, distance = c.distance, counter = c.counter, modifiers = mods,
   attackerFlying = f.flying, defender = adapter.defender and adapter.defender(t, f) or nil,
  })
  local before = t.hp
  CharacterStats.takeDamage(t, result.damage)
  result.before, result.after = before, t.hp
  AbilitySystem.landed(f, act, t, result, now) -- still counts if f was hit out of the move this same tick
  if adapter.onHit then adapter.onHit(f, t, result, act) end
  table.insert(results, {attacker = f, target = t, ability = act.name, title = act.move.Title, result = result})
 end
 return results
end

return Simulation
