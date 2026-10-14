-- HeroEngine Phase 0 offline tests. Run from the repo root:  bash phase0/HeroEngine/Tests/run.sh
-- 1. Core unit tests. 2. Parity: the engine's rules give the same answers as HeroWars Rules (r66ui11).
-- 3. Character files match the live numbers. 4. Integration: Solarion's Sun Jab, run through the engine's
--    server tick, damages Wraithstep (the same Simulation.tick the Studio test place runs).
local CombatRules = require("../Core/CombatRules")
local DamageCalculator = require("../Core/DamageCalculator")
local AbilitySystem = require("../Core/AbilitySystem")
local CharacterStats = require("../Core/CharacterStats")
local StateMachine = require("../Core/StateMachine")
local Simulation = require("../Core/Simulation")
local Rules = require("../../HeroWarsGame/LegacyRules")
local Solarion = require("../../HeroWarsGame/Characters/Solarion")
local Wraithstep = require("../../HeroWarsGame/Characters/Wraithstep")

local passed, failed = 0, 0
local function check(name, cond, detail)
 if cond then passed += 1 else failed += 1; print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or "")) end
end
local function section(name) print("-- " .. name) end

section("CombatRules")
local jab = {Startup = 5, Active = 3, Recovery = 7}
check("phase startup", CombatRules.phase(jab, 5) == "Startup")
check("phase active", CombatRules.phase(jab, 6) == "Active" and CombatRules.phase(jab, 8) == "Active")
check("phase recovery", CombatRules.phase(jab, 15) == "Recovery" and CombatRules.phase(jab, 16) == "Idle")
check("phase whiff adds recovery", CombatRules.phase(jab, 16, 4) == "Recovery")
check("validUnit ok", CombatRules.validUnit({0, 0, -1}))
check("validUnit NaN", not CombatRules.validUnit({0 / 0, 0, 1}))
check("validUnit long", not CombatRules.validUnit({1, 1, 0}))
check("validUnit not a table", not CombatRules.validUnit("x"))

section("Parity with HeroWars Rules")
local bools = {false, true}
local same = true
for _, dmg in {0, 1, 6, 17, 24} do for _, b in bools do for _, f in bools do for _, p in bools do
 for _, g in bools do for _, i in bools do for _, t in bools do
  local d1, r1 = CombatRules.defend(dmg, b, f, p, g, i, t)
  local d2, r2 = Rules.defend(dmg, b, f, p, g, i, t)
  if d1 ~= d2 or r1 ~= r2 then same = false end
 end end end
end end end end
check("defend matches Rules.defend (320 cases)", same)
local drSame = true
for _, stun in {10, 59, 60, 90, 120, 180, 240} do for count = 0, 4 do
 local a1, b1 = CombatRules.drStun(stun, count); local a2, b2 = Rules.drStun(stun, count)
 if a1 ~= a2 or b1 ~= b2 then drSame = false end
end end
check("drStun matches Rules.drStun", drSame)
math.randomseed(7)
local boxSame, overlaps = true, 0
local function rbox()
 local look = CombatRules.unit({math.random() * 2 - 1, math.random() - 0.5, math.random() * 2 - 1}, {0, 0, -1})
 return CombatRules.strikeBox({math.random() * 10, math.random() * 4, math.random() * 10}, look,
  {Range = 1 + math.random() * 8, Width = 1 + math.random() * 5, Height = 1 + math.random() * 6})
end
for _ = 1, 2000 do
 local A, B = rbox(), rbox()
 local e = CombatRules.boxesOverlap(A, B)
 if e ~= Rules.boxesOverlap(A, B) then boxSame = false end
 if e then overlaps += 1 end
end
check("boxesOverlap matches Rules.boxesOverlap (2000 random boxes)", boxSame)
check("random boxes include overlaps and misses", overlaps > 100 and overlaps < 1900, overlaps)
check("phase matches Rules.phase", (function()
 for frame = 0, 40 do if CombatRules.phase(jab, frame, 2) ~= Rules.phase(jab, frame, 2) then return false end end
 return true
end)())
check("GCD matches", AbilitySystem.GCD == Rules.GCD)
check("ParryFrames matches", CombatRules.ParryFrames == Rules.ParryFrames)
check("Hz matches", CombatRules.Hz == Rules.Hz)

section("Character files read the live numbers")
for _, pair in {{Solarion, "Solarion"}, {Wraithstep, "Wraithstep"}} do
 local c, hero = pair[1], pair[2]
 check(hero .. " health", c.Stats.Health == Rules.Characters[hero].Health, c.Stats.Health)
 for name, a in c.Abilities do
  local live = Rules.heroMove(hero, name)
  for k, v in live do
   if a[k] ~= v then check(hero .. " " .. name .. "." .. k, false, tostring(a[k]) .. " vs " .. tostring(v)) end
  end
 end
end
check("Sun Jab is 6 damage", Solarion.Abilities.Light1.Damage == 6 and Solarion.Abilities.Light1.Title == "Sun Jab")
check("Solar Hammer has 3 pulses", Solarion.Abilities.Heavy.Pulses == 3)
check("define rejects a broken spec", not pcall(AbilitySystem.define, "Broken", {Startup = 1}))

section("DamageCalculator")
local r = DamageCalculator.compute({move = {Damage = 6, Range = 6}})
check("plain hit", r.damage == 6 and r.result == "Hit")
r = DamageCalculator.compute({move = {Damage = 10, Range = 6}, defender = {blocking = true, facing = true}})
check("block lets 20% through", r.damage == 2 and r.result == "Block")
r = DamageCalculator.compute({move = {Damage = 10, Range = 6}, defender = {blocking = true, facing = true, parry = true}})
check("parry", r.damage == 0 and r.result == "Parry")
r = DamageCalculator.compute({move = {Damage = 10, Range = 6, BreaksGuard = true}, defender = {blocking = true, facing = true}})
check("guard break", r.damage == 10 and r.result == "GuardBreak")
r = DamageCalculator.compute({move = {Damage = 10, Range = 6}, counter = true})
check("counter-hit x1.2", r.damage == 12 and r.result == "Counter")
r = DamageCalculator.compute({move = {Damage = 9, Range = 30, SweetSpot = 2.5}, distance = 28})
check("sweet spot x1.25 rounds", r.damage == 11 and r.sweet, r.damage)
r = DamageCalculator.compute({move = {Damage = 10, Range = 6}, modifiers = {{name = "ShadowCircle", scale = 1.5}}})
check("modifier", r.damage == 15)
r = DamageCalculator.compute({move = {Damage = 10, Range = 6}, defender = {absorb = 30}})
check("absorb soaks it all", r.damage == 0 and r.result == "Absorb" and r.absorbed == 10)
r = DamageCalculator.compute({move = {Damage = 10, AirDamage = 7, Range = 6}, attackerFlying = true})
check("air damage", r.damage == 7)

section("StateMachine")
local sm = StateMachine.new()
check("starts idle", sm.name == "Idle" and StateMachine.canAct(sm))
check("idle -> active refused", not StateMachine.set(sm, "Active", 0))
check("stun runs out", StateMachine.set(sm, "Stunned", 0, 10) and StateMachine.update(sm, 9) == "Stunned" and StateMachine.update(sm, 10) == "Idle")

section("AbilitySystem")
local sol = CharacterStats.new("A", Solarion)
local ok, name = AbilitySystem.tryUse(sol, "Light", 100)
check("combo starts at Sun Jab", ok and name == "Light1", name)
check("busy during the jab", not AbilitySystem.tryUse(sol, "Light", 101))
for t = 101, 116 do AbilitySystem.step(sol, t) end
check("jab ends after 15 ticks", sol.action == nil and sol.state.name == "Idle")
ok, name = AbilitySystem.tryUse(sol, "Light", 120)
check("chain steps to Flare Cross", ok and name == "Light2", name)
for t = 121, 140 do AbilitySystem.step(sol, t) end
ok, name = AbilitySystem.tryUse(sol, "Light", 200)
check("chain resets after the window", ok and name == "Light1", name)
for t = 201, 220 do AbilitySystem.step(sol, t) end
ok = AbilitySystem.tryUse(sol, "Heavy", 300)
check("Solar Hammer starts", ok)
local windows = 0
for t = 301, 400 do if AbilitySystem.step(sol, t) then windows += 1 end end
check("Solar Hammer opens 3 hit windows", windows == 3, windows)
local cd1 = sol.cooldowns.Heavy - 300
AbilitySystem.tryUse(sol, "Heavy", 400)
for t = 401, 500 do AbilitySystem.step(sol, t) end
local cd2 = sol.cooldowns.Heavy - 400
check("Solar Hammer cooldown ramps when spammed", cd1 == 60 and cd2 == 150, cd1 .. " then " .. cd2)
check("unknown input refused", not AbilitySystem.tryUse(sol, "Skill9", 600))

section("Integration: Sun Jab through the engine damages Wraithstep")
-- Offline geometry: the same strike box and reach test HeroWars Main uses, with a standard R15 hurtbox.
local HURT = {4, 5.2, 2}
local A, B
local function adapter(pos)
 return {
  targets = function(f, act)
   local out = {}
   local box = CombatRules.strikeBox(pos[f.id], act.aim, act.move)
   for id, p in pos do
    if id ~= f.id then
     local t = (id == "A") and A or B
     local hurt = CombatRules.boxFacing(p, {0, 0, 1}, HURT)
     if CombatRules.boxesOverlap(box, hurt) and CombatRules.inReach(pos[f.id], p, act.move, HURT) then
      table.insert(out, {fighter = t, distance = CombatRules.len(CombatRules.sub(p, pos[f.id]))})
     end
    end
   end
   return out
  end,
 }
end
A = CharacterStats.new("A", Solarion)
B = CharacterStats.new("B", Wraithstep)
local world = {fighters = {A, B}}
local pos = {A = {0, 3, 0}, B = {0, 3, -4}}
local ad = adapter(pos)
check("Solarion presses 1", AbilitySystem.tryUse(A, "Light", 1, {0, 0, -1}))
local hits, stateAfterHit = {}, nil
for t = 1, 30 do
 for _, h in Simulation.tick(world, t, ad) do table.insert(hits, h); stateAfterHit = B.state.name end
end
check("one hit", #hits == 1, #hits)
local h = hits[1]
check("Sun Jab hit Wraithstep for 6", h and h.ability == "Light1" and h.target == B and h.result.damage == 6, h and h.result.damage)
check("Wraithstep 100 -> 94", B.hp == 94 and h.result.before == 100 and h.result.after == 94, B.hp)
check("Wraithstep was stunned by it", stateAfterHit == "Stunned", stateAfterHit)
check("and is free again once the stun ends", B.state.name == "Idle", B.state.name)
check("Solarion gained Fury", A.resource == Rules.Fury.Start + Solarion.Abilities.Light1.Fury, A.resource)
check("Wraithstep gained Fury from the hit", B.resource == Rules.Fury.Start + 6 * Rules.Fury.PerDamageTaken, B.resource)
-- Out of reach: 12 studs away, nothing lands.
local C = CharacterStats.new("A", Solarion); local D = CharacterStats.new("B", Wraithstep)
A, B = C, D
local far = adapter({A = {0, 3, 0}, B = {0, 3, -12}})
AbilitySystem.tryUse(C, "Light", 1, {0, 0, -1})
local n = 0
for t = 1, 30 do n += #Simulation.tick({fighters = {C, D}}, t, far) end
check("a jab 12 studs short misses", n == 0 and D.hp == 100)
-- Solar Hammer down the line: three pulses of 9 at 20 studs.
local E = CharacterStats.new("A", Solarion); local F = CharacterStats.new("B", Wraithstep)
A, B = E, F
local line = adapter({A = {0, 3, 0}, B = {0, 3, -20}})
AbilitySystem.tryUse(E, "Heavy", 1, {0, 0, -1})
local pulses = 0
for t = 1, 120 do pulses += #Simulation.tick({fighters = {E, F}}, t, line) end
check("Solar Hammer lands 3 pulses for 27", pulses == 3 and F.hp == 73, pulses .. " pulses, hp " .. F.hp)

print(string.format("\n%d passed, %d failed", passed, failed))
if failed > 0 then error("tests failed", 0) end
