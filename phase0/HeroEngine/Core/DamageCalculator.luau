-- HeroEngine Phase 0: one blow's damage, in the same order HeroWars' Main applies it (applyHit):
--   base (AirDamage when the attacker flies) -> sweet spot x1.25 -> counter-hit -> modifiers -> round
--   -> the defender's guard (CombatRules.defend) -> absorb shield.
-- Platform-neutral. Hero specials (Juggernaut stacks, Shadow Circle, Solar Shield) plug in as modifiers
-- from the character files instead of living here as `if hero == ...` checks.
local CombatRules = if script then require(script.Parent.CombatRules) else require("./CombatRules")

local DamageCalculator = {}
DamageCalculator.SweetSpotScale = 1.25
DamageCalculator.CounterScale = 1.2

-- hit = {
--  move = ability spec (Damage, AirDamage?, Range, SweetSpot?, BreaksGuard?, Throw?),
--  attackerFlying?, distance?, counter?, scale? (splash share),
--  modifiers? = {{name = "...", scale = 1.5}, ...},
--  defender = {blocking?, facing?, parry?, invulnerable?, absorb? (shield points left)},
-- }
-- Returns {damage, result, raw (before guard), absorbed, sweet, steps (for logs and tests)}.
function DamageCalculator.compute(hit)
 local move = hit.move
 local steps = {}
 local base = (move.AirDamage and hit.attackerFlying) and move.AirDamage or move.Damage
 local damage = base * (hit.scale or 1)
 table.insert(steps, {"base", damage})
 local sweet = false
 if move.SweetSpot and hit.distance and hit.distance >= move.Range - move.SweetSpot then
  damage *= DamageCalculator.SweetSpotScale; sweet = true
  table.insert(steps, {"sweet", damage})
 end
 if hit.counter then
  damage *= DamageCalculator.CounterScale
  table.insert(steps, {"counter", damage})
 end
 for _, m in hit.modifiers or {} do
  damage *= m.scale
  table.insert(steps, {m.name, damage})
 end
 damage = math.floor(damage + 0.5)
 local raw = damage
 local d = hit.defender or {}
 local result
 damage, result = CombatRules.defend(damage, d.blocking, d.facing, d.parry, move.BreaksGuard, d.invulnerable, move.Throw)
 table.insert(steps, {result, damage})
 local absorbed = 0
 if damage > 0 and (d.absorb or 0) > 0 then
  absorbed = math.min(damage, d.absorb)
  damage -= absorbed
  if damage <= 0 then result = "Absorb" end
  table.insert(steps, {"absorb", damage})
 end
 if result == "Hit" and hit.counter then result = "Counter" end
 return {damage = damage, result = result, raw = raw, absorbed = absorbed, sweet = sweet, steps = steps}
end

return DamageCalculator
