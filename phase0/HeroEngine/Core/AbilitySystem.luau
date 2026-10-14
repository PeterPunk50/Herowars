-- HeroEngine Phase 0: the one way any character uses an ability.
-- An ability spec is plain data in 60 Hz ticks (the same fields HeroWars Rules.Moves uses):
--   Startup, Active, Recovery, Damage, Range, Width, Height   (required)
--   Cooldown, Cost (resource, also starts the global cooldown), Stun, Fury (resource gained on contact),
--   Pulses + PulseGap (several separate hits in one Active window), RampStep/RampMax/RampReset (a cooldown
--   that grows when spammed), SweetSpot, AirDamage, BreaksGuard, Throw, Title.
-- The server calls tryUse when a client asks, and step once per tick; step says when to look for hits.
local StateMachine = if script then require(script.Parent.StateMachine) else require("./StateMachine")
local CombatRules = if script then require(script.Parent.CombatRules) else require("./CombatRules")

local AbilitySystem = {}
AbilitySystem.GCD = 45 -- ticks; shared by every ability with a Cost (WoW global cooldown)

local REQUIRED = {"Startup", "Active", "Recovery", "Damage", "Range", "Width", "Height"}

-- Checks a spec and fills defaults. Errors name the ability and the missing field.
function AbilitySystem.define(name, spec)
 for _, k in REQUIRED do
  if type(spec[k]) ~= "number" then error(string.format("ability %s: %s must be a number", name, k), 2) end
 end
 local a = table.clone(spec)
 a.Name = name
 a.Cooldown = a.Cooldown or 0
 a.Stun = a.Stun or 0
 a.Title = a.Title or name
 return a
end

-- Which ability an input fires right now. Inputs map to an ability name, or to a chain
-- {Chain = {"Light1", "Light2", "Light3"}, Window = ticks} that steps on while presses keep coming.
local function resolve(f, input, now)
 local entry = f.config.Inputs[input]
 if type(entry) == "string" then return entry, nil end
 if type(entry) == "table" and entry.Chain then
  local step = now <= f.comboUntil and f.combo % #entry.Chain + 1 or 1
  return entry.Chain[step], {step = step, window = entry.Window or 45}
 end
 return nil, nil
end
AbilitySystem.resolve = resolve

-- Returns true, abilityName or false, reason. On success the fighter is in Startup.
function AbilitySystem.tryUse(f, input, now, aim)
 if f.hp <= 0 then return false, "dead" end
 StateMachine.update(f.state, now)
 if not StateMachine.canAct(f.state) then return false, "busy:" .. f.state.name end
 local name, chain = resolve(f, input, now)
 local a = name and f.config.Abilities[name]
 if not a then return false, "no ability for " .. tostring(input) end
 local readyAt = math.max(f.cooldowns[name] or 0, a.Cost and f.gcd or 0)
 if now < readyAt then return false, "cooldown" end
 if a.Cost then
  if f.resource < a.Cost then return false, "resource" end
  f.resource -= a.Cost; f.gcd = now + AbilitySystem.GCD
 end
 if chain then f.combo = chain.step; f.comboUntil = now + chain.window else f.combo = 0 end
 local cooldown = a.Cooldown
 if a.RampStep then
  local uses = now < (f.cooldowns[name] or 0) + a.RampReset and (f.ramp[name] or 0) or 0
  cooldown = math.min(a.RampMax, a.Cooldown + uses * a.RampStep)
  f.ramp[name] = uses + 1
 end
 f.cooldowns[name] = now + cooldown
 f.action = {name = name, move = a, frame = 0, hit = {}, aim = aim or {0, 0, -1}, pulsed = 0, contact = false}
 StateMachine.set(f.state, "Startup", now)
 return true, name
end

-- Advance one tick. Returns true when hits should be looked for this tick (callers then use
-- AbilitySystem.canHit per target, so each target is hit once per pulse).
function AbilitySystem.step(f, now)
 StateMachine.update(f.state, now)
 local act = f.action
 if not act then return false end
 act.frame += 1
 local phase = CombatRules.phase(act.move, act.frame, act.extra)
 local m = act.move
 if phase == "Idle" then
  f.action = nil
  StateMachine.set(f.state, "Idle", now)
  return false
 end
 StateMachine.set(f.state, phase, now)
 if phase ~= "Active" then return false end
 if m.Pulses then
  -- Pulse i (0-based) fires at Startup + 1 + i * PulseGap; each pulse may hit the same target again.
  if act.pulsed < m.Pulses and act.frame - m.Startup - 1 >= act.pulsed * (m.PulseGap or 1) then
   act.pulsed += 1; act.hit = {}
   return true
  end
  return false
 end
 return true
end

function AbilitySystem.canHit(f, targetId)
 return f.action ~= nil and not f.action.hit[targetId]
end

-- Bookkeeping after a blow lands: mark the target, resource for both sides, and hitstun on the target
-- (which also stops whatever the target was doing).
-- `act` is passed in because the attacker may already have been knocked out of it by a blow on the same tick.
function AbilitySystem.landed(f, act, target, result, now)
 act.hit[target.id] = true
 act.contact = true
 if result.damage > 0 then
  f.damageDealt += result.damage; f.hits += 1
  if act.move.Fury then f.resource = math.min(f.resourceMax, f.resource + act.move.Fury) end
  local per = target.config.Resource and target.config.Resource.PerDamageTaken
  if per then target.resource = math.min(target.resourceMax, target.resource + result.damage * per) end
 end
 if target.hp <= 0 then
  target.action = nil
  StateMachine.set(target.state, "Dead", now)
 elseif result.damage > 0 and result.result ~= "Block" and (act.move.Stun or 0) > 0 then
  target.action = nil
  StateMachine.set(target.state, "Stunned", now, now + act.move.Stun)
 end
end

-- Is the target in its own wind-up (a counter-hit)?
function AbilitySystem.inStartup(f)
 return f.action ~= nil and CombatRules.phase(f.action.move, f.action.frame, f.action.extra) == "Startup"
end

return AbilitySystem
