-- HeroEngine Phase 0: a fighter's numbers (health, resource, cooldowns) as a plain table.
-- The Roblox side mirrors `hp` onto the Humanoid; the engine never reads the Humanoid back, so the server's
-- copy here is the truth.
local StateMachine = if script then require(script.Parent.StateMachine) else require("./StateMachine")

local CharacterStats = {}

-- config = a character file (HeroWarsGame/Characters/*): {Name, Stats = {Health, Speed, ...}, Resource?}
function CharacterStats.new(id, config)
 local stats = config.Stats
 local res = config.Resource
 return {
  id = id, hero = config.Name, config = config,
  hp = stats.Health, maxHp = stats.Health, speed = stats.Speed,
  resource = res and res.Start or 0, resourceMax = res and res.Max or 0,
  state = StateMachine.new(), action = nil,
  cooldowns = {}, ramp = {}, gcd = 0,
  combo = 0, comboUntil = -1,
  damageDealt = 0, hits = 0,
 }
end

function CharacterStats.isAlive(f) return f.hp > 0 end

-- Returns the damage actually taken (never below zero health).
function CharacterStats.takeDamage(f, amount)
 local took = math.min(f.hp, math.max(0, amount))
 f.hp -= took
 return took
end

function CharacterStats.heal(f, amount)
 local got = math.min(f.maxHp - f.hp, math.max(0, amount))
 f.hp += got
 return got
end

function CharacterStats.gain(f, amount)
 f.resource = math.min(f.resourceMax, f.resource + amount)
end

return CharacterStats
