-- R66-ui9 offline test for the tactical bot AI. Runs the real BotAI module and the real Rules against a
-- simplified duel (positions, frame data, cooldowns, Fury, stuns, defensives, flight) with scripted players.
-- Not Roblox physics: no walls, no hitbox shapes (reach = range + lunge + leap + area), no stun DR, no DoTs.
-- Run: bash test/run_sim.sh   (copies src/ next to this file and runs it with the Luau CLI)
local SEED = 12345

-- Roblox stand-ins: stubs.luau (run_sim.sh prepends it to this file, Rules and BotAI).
local vec = Vector3.new
local function instance(isPlayer)
 local o = {__inst = true}
 function o:IsA(c) return (c == "Player") == isPlayer end
 return o
end
local function model()
 local m = {attrs = {}}
 function m:GetAttribute(k) return self.attrs[k] end
 function m:SetAttribute(k, v) self.attrs[k] = v end
 return m
end

local Rules = require("./Rules")
local BotAI = require("./BotAI")

-- A tiny duel world ---------------------------------------------------------------------------------------
local T = 0
local states = {}
local function newFighter(hero, isBot, pos)
 local c = Rules.Characters[hero]
 local s = {hero = hero, isDummy = isBot, model = model(), cooldowns = {}, fury = Rules.Fury.Start, gcd = 0, stunned = 0,
  energy = 100, flying = false, dir = vec(0, 0, 0), aim = vec(1, 0, 0), invulnerable = 0, combo = 0, comboUntil = 0,
  hum = {Health = c.Health, MaxHealth = c.Health, FloorMaterial = "Plastic"},
  root = {Position = pos, CFrame = {LookVector = vec(1, 0, 0)}}, buffer = nil, log = {}}
 return s
end
local function alive(s) return s.hum.Health > 0 end
local function flatUnit(v, fb) local f = vec(v.X, 0, v.Z); if f.Magnitude < 0.01 then return fb end return f.Unit end
local function reach(m)
 if m.Whirl or m.LockOn then return (m.Range or 0) + 3 end
 return (m.Range or 0) + (m.Lunge or 0) + (m.Leap or 0) + math.max(m.Aoe or 0, m.Radius or 0) + 1
end
local stats

local function other(s) for k, t in states do if t ~= s then return t end end end

local function useDefensive(s)
 local d = Rules.Defensives[s.hero]
 s.cooldowns.Defensive = T + d.Cooldown
 s.stunned = T; s.whirl = nil; s.snare = nil; s.action = nil
 if d.Kind == "Parry" then s.parryUntil = T + d.Window
 elseif d.Kind == "Shield" then s.shieldHP = d.Absorb or 30; s.shieldUntil = T + d.Duration
 elseif d.Kind == "Vanish" then s.invulnerable = T + (d.Invulnerable or 18); s.hiddenUntil = T + 60; s.model:SetAttribute("Invisible", true)
 elseif d.Kind == "Blink" then
  local t = other(s); local away = flatUnit(s.root.Position - t.root.Position, vec(1, 0, 0))
  s.root.Position = s.root.Position + away * d.Distance; s.invulnerable = T + d.Invulnerable
 end
 if s.isDummy then stats.defensives += 1 end
end

local function tryAttack(s, input)
 if s.action or T < s.stunned or T < (s.parryUntil or 0) then return "wait" end
 local combo = T <= s.comboUntil and s.combo % 3 + 1 or 1
 local name = Rules.moveName(s.hero, input, combo)
 if input == "Light" and T < (s.phaseUntil or 0) then name = "ShadeBolt" end
 local move = name and Rules.heroMove(s.hero, name)
 if not move then return "fail" end
 if T < (s.cooldowns[name] or 0) then return "fail" end
 if move.Cost then
  if T < s.gcd or s.fury < move.Cost then return "fail" end
  s.fury -= move.Cost; s.gcd = T + Rules.GCD
 end
 if input == "Light" then s.combo = combo; s.comboUntil = T + 45 else s.combo = 0 end
 s.cooldowns[name] = T + (move.Cooldown or 0)
 if move.Phase then s.phaseUntil = T + move.Phase end
 s.action = {name = name, move = move, frame = 0, contact = false, extra = 0}
 s.model:SetAttribute("Invisible", T < (s.phaseUntil or 0) or nil)
 s.hiddenUntil = nil
 if s.isDummy then stats.attacks += 1 else stats.playerAttacks += 1 end
 return "ok"
end

local function doAction(s, act, data)
 if not Rules.actionAvailable(s.hero, act) then return end
 if act == "Defensive" then if T >= (s.cooldowns.Defensive or 0) then useDefensive(s) end return end
 if act == "Flight" then
  if s.flying then s.flying = false
  elseif Rules.Characters[s.hero].Flies and s.energy >= Rules.Flight.Takeoff then s.energy -= Rules.Flight.Takeoff; s.flying = true; s.flightStart = T end
  return
 end
 if act == "Dash" or act == "Block" or act == "Jump" then return end
 local r = tryAttack(s, act)
 if r == "wait" then s.buffer = {input = act, expires = T + Rules.BufferFrames} end
end

local function land(a, t, move)
 -- One contact from a to t.
 if T < t.invulnerable or (t.model:GetAttribute("Invisible") and not move.LockOn) then return end
 if T < (t.parryUntil or 0) then
  a.stunned = T + 45; a.action = nil
  local dmg = move.Damage or 0; a.hum.Health -= dmg
  if t.isDummy then stats.parried += 1 end
  return
 end
 local dmg = move.Damage or 0
 if (t.shieldHP or 0) > 0 and T < (t.shieldUntil or 0) then local took = math.min(dmg, t.shieldHP); t.shieldHP -= took; dmg -= took end
 t.hum.Health -= dmg
 a.action.contact = true
 if move.Stun and move.Stun > 0 then t.stunned = math.max(t.stunned, T + move.Stun); t.action = nil; t.flying = false end
 if move.Whirl then t.whirl = {ends = t.stunned}; t.invulnerable = t.stunned end
 if move.Snare then t.snare = {ends = t.stunned} end
 if move.Grounding then t.flying = false end
 if move.Interrupt and t.action and t.action.move.Cast then t.action = nil; t.stunned = T + 240 end
 if a.isDummy then stats.dealt += dmg; stats.botHits += 1 else stats.taken += dmg; stats.playerHits += 1 end
end

local function step(s)
 local t = other(s)
 if s.whirl and T >= s.whirl.ends then s.whirl = nil end
 if s.snare and T >= s.snare.ends then s.snare = nil end
 if s.hiddenUntil and T >= s.hiddenUntil then s.model:SetAttribute("Invisible", nil); s.hiddenUntil = nil end
 if s.phaseUntil and T >= s.phaseUntil then s.phaseUntil = nil; s.model:SetAttribute("Invisible", nil) end
 s.fury = math.min(100, s.fury + Rules.Fury.Regen / 60)
 if s.buffer then
  if T > s.buffer.expires then s.buffer = nil
  elseif tryAttack(s, s.buffer.input) ~= "wait" then s.buffer = nil end
 end
 local a = s.action
 if a then
  a.frame += 1
  local m = a.move
  if a.frame == m.Startup + 1 then
   local d = (t.root.Position - s.root.Position).Magnitude
   if m.ShadowCircle or m.SolarAbsorb or m.Teleport or m.Phase then
    a.contact = d <= reach(m)
    if m.Teleport and a.contact then s.root.Position = t.root.Position - flatUnit(t.root.Position - s.root.Position, vec(1, 0, 0)) * 3 end
   elseif (m.Damage or 0) > 0 and d <= reach(m) then land(s, t, m) end
  end
  if s.action and a.frame > m.Startup + m.Active + m.Recovery + (a.contact and 0 or (m.Whiff or 0)) then s.action = nil end
 end
 -- Movement.
 local speed = Rules.Characters[s.hero].Speed
 if T < s.stunned then speed = 0 elseif s.action then speed = 9 end
 local p = s.root.Position
 local flat = vec(s.dir.X, 0, s.dir.Z)
 if s.flying then
  s.energy = math.max(0, s.energy - Rules.Flight.Drain / 60)
  local vy = T - (s.flightStart or 0) < 27 and 18 or (s.dir.Y or 0) * Rules.Flight.Speed
  p = p + flat * (Rules.Flight.Speed / 60) + vec(0, vy / 60, 0)
  if s.energy <= 0 then s.flying = false end
 else
  p = p + flat * (speed / 60)
  if p.Y > 0 then p = vec(p.X, math.max(0, p.Y - 0.6), p.Z) end
  s.energy = math.min(100, s.energy + Rules.Flight.Recharge / 60)
 end
 p = vec(math.clamp(p.X, -85, 85), math.min(p.Y, Rules.ceiling(s.hero)), math.clamp(p.Z, -85, 85))
 s.root.Position = p
 s.hum.FloorMaterial = (s.flying or p.Y > 0.5) and "Air" or "Plastic"
end

-- Scripted players ----------------------------------------------------------------------------------------
local PLAYERS = {}
-- Spam: walks in to about 6 studs, then stands and mashes on a steady rhythm (what Peter saw on his phone).
PLAYERS.spam = function(p, bot)
 local d = bot.root.Position - p.root.Position
 p.aim = d.Unit
 p.dir = d.Magnitude > (p.closing and 4 or 7.5) and flatUnit(d, vec(1, 0, 0)) or vec(0, 0, 0)
 p.closing = d.Magnitude > 9
 if T % 22 == 0 and d.Magnitude < 9 then
  if Rules.actionAvailable(p.hero, "Light") then doAction(p, "Light") else doAction(p, "Heavy") end
 end
 if T % 150 == 75 and d.Magnitude < 9 then doAction(p, "Heavy") end
end
-- Flyer: hovers above at 18 studs and fires ranged moves.
PLAYERS.flyer = function(p, bot)
 local d = bot.root.Position - p.root.Position
 p.aim = d.Unit
 if not p.flying and p.energy > 60 then doAction(p, "Flight") end
 local flat = flatUnit(d, vec(1, 0, 0))
 local want = p.root.Position.Y < 14 and 1 or 0
 p.dir = vec(d.Magnitude > 20 and flat.X or (d.Magnitude < 15 and -flat.X or 0), want, d.Magnitude > 20 and flat.Z or (d.Magnitude < 15 and -flat.Z or 0))
 if T % 30 == 0 then doAction(p, Rules.HeroSkills[p.hero].Skill1 and "Skill1" or "Heavy") end
 if T % 30 == 15 then doAction(p, "Heavy") end
end
-- Kiter: keeps 25-32 studs and casts.
PLAYERS.kite = function(p, bot)
 local d = bot.root.Position - p.root.Position
 p.aim = d.Unit
 local flat = flatUnit(d, vec(1, 0, 0))
 p.dir = d.Magnitude < 25 and -flat or (d.Magnitude > 32 and flat or vec(0, 0, 0))
 if T % 20 == 0 then
  if Rules.HeroSkills[p.hero].Skill1 then doAction(p, "Skill1") end
  doAction(p, "Heavy")
 end
end
-- Caster: stands at mid range and channels casts (Solar Hammer, Lightning).
PLAYERS.caster = function(p, bot)
 local d = bot.root.Position - p.root.Position
 p.aim = d.Unit
 local flat = flatUnit(d, vec(1, 0, 0))
 p.dir = d.Magnitude < 12 and -flat or (d.Magnitude > 18 and flat or vec(0, 0, 0))
 if T % 25 == 0 then doAction(p, p.hero == "Tempest" and "Skill1" or "Heavy") end
end

-- One fight -----------------------------------------------------------------------------------------------
local function fight(level, botHero, playerHero, script, opts)
 opts = opts or {}
 T = 0; table.clear(states)
 stats = {defensives = 0, attacks = 0, playerAttacks = 0, dealt = 0, taken = 0, botHits = 0, playerHits = 0, parried = 0,
  tactics = {}, types = {}, reactions = {}, threats = 0, threatsAvoided = 0, thinkTime = 0, thinks = 0}
 local pk, bk = instance(true), instance(false)
 local p = newFighter(playerHero, false, vec(-12, 0, 0))
 local b = newFighter(botHero, true, vec(12, 0, 0))
 if opts.botHp then b.hum.Health = b.hum.MaxHealth * opts.botHp end
 states[pk] = p; states[bk] = b
 local ctx = {Rules = Rules, states = states, alive = alive, flatUnit = flatUnit, clearSight = function() return true end,
  foe = function(a, c) return a ~= c end, doAction = doAction, now = function() return T end, level = function() return level end,
  onPress = function(s, tac, use, score, reaction)
   stats.tactics[tac.Id] = (stats.tactics[tac.Id] or 0) + 1
   stats.types[tac.Type] = (stats.types[tac.Type] or 0) + 1
   if reaction and (tac.Type == "Defend" or tac.Type == "Punish" or tac.Type == "Interrupt") then table.insert(stats.reactions, reaction) end
  end}
 -- Threat bookkeeping: each player attack that starts with the bot in reach; avoided = it didn't hurt the bot.
 local watching
 local duration = opts.ticks or 60 * 60
 while T < duration and alive(p) and alive(b) do
  T += 1
  PLAYERS[script](p, b)
  local c0 = os.clock()
  BotAI.think(b, ctx)
  stats.thinkTime += os.clock() - c0; stats.thinks += 1
  local hp = b.hum.Health
  step(p); step(b)
  if p.action and p.action ~= watching then
   watching = p.action
   local d = (b.root.Position - p.root.Position).Magnitude
   if d <= reach(p.action.move) and (p.action.move.Damage or 0) > 0 then stats.threats += 1; watching.threat = true; watching.hpAt = hp end
  end
  if watching and watching.threat and not watching.scored and p.action ~= watching then
   watching.scored = true
   if not watching.contact then stats.threatsAvoided += 1 end
  end
 end
 stats.winner = not alive(b) and "player" or (not alive(p) and "bot" or "time")
 stats.seconds = T / 60
 return stats
end

-- Scenarios -----------------------------------------------------------------------------------------------
math.randomseed(SEED)
local LEVELS = {"Easy", "Normal", "Hard"}
local HEROES = {"Bulwark", "Tempest", "Solarion", "Wraithstep"}
local function avg(list) if #list == 0 then return 0 end local s = 0 for _, v in list do s += v end return s / #list end
local function pct(a, b) return b > 0 and math.floor(100 * a / b + 0.5) or 0 end

local function scenario(title, script, playerHeroes, opts, reps)
 print("\n## " .. title)
 print("| Bot | Level | Threats avoided | Defends | Evades | Punishes | Anti-air | Interrupts | Baits | Avg react (ticks) | Dmg dealt/taken | Wins |")
 print("|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|")
 local all = {}
 for _, hero in HEROES do
  for _, level in LEVELS do
   local agg = {threats = 0, avoided = 0, defend = 0, evade = 0, punish = 0, air = 0, interrupt = 0, bait = 0, react = {}, dealt = 0, taken = 0, wins = 0, n = 0, think = 0, thinks = 0}
   for _, ph in playerHeroes do
    for _ = 1, reps or 4 do
     local st = fight(level, hero, ph, script, opts)
     agg.n += 1
     agg.threats += st.threats; agg.avoided += st.threatsAvoided
     agg.defend += (st.types.Defend or 0) + (st.types.Escape or 0); agg.punish += st.types.Punish or 0; agg.evade += st.types.Evade or 0
     agg.air += (st.types.AntiAir or 0) + (st.types.Fly or 0); agg.interrupt += st.types.Interrupt or 0
     agg.bait += st.types.Bait or 0
     for _, r in st.reactions do table.insert(agg.react, r) end
     agg.dealt += st.dealt; agg.taken += st.taken; agg.wins += st.winner == "bot" and 1 or 0
     agg.think += st.thinkTime; agg.thinks += st.thinks
    end
   end
   print(string.format("| %s | %s | %d%% | %.1f | %.1f | %.1f | %.1f | %.1f | %.1f | %.0f | %.0f / %.0f | %d/%d |", hero, level,
    pct(agg.avoided, agg.threats), agg.defend / agg.n, agg.evade / agg.n, agg.punish / agg.n, agg.air / agg.n, agg.interrupt / agg.n, agg.bait / agg.n,
    avg(agg.react), agg.dealt / agg.n, agg.taken / agg.n, agg.wins, agg.n))
   table.insert(all, agg)
  end
 end
 return all
end

print("# Bot AI offline test (R66-ui9)")
print("Each row: averages per fight (60 s max). Threats avoided = player attacks started with the bot in reach that didn't land.")
local perf = {}
for _, r in scenario("1. Attack spam (player presses the same attack every 22 ticks in melee)", "spam", HEROES) do table.insert(perf, r) end
for _, r in scenario("2. Flight vs ground (player flies 14 up, 15-20 away, fires ranged)", "flyer", {"Solarion", "Tempest"}) do table.insert(perf, r) end
for _, r in scenario("3. Retreating player (kites at 25-32 studs and casts)", "kite", {"Tempest", "Wraithstep"}) do table.insert(perf, r) end
for _, r in scenario("4. Casting player (channels Solar Hammer / Lightning at 12-18)", "caster", {"Solarion", "Tempest"}) do table.insert(perf, r) end
for _, r in scenario("5. Low health (bot starts at 25% vs spam)", "spam", HEROES, {botHp = 0.25}) do table.insert(perf, r) end
local t, n = 0, 0
for _, r in perf do t += r.think; n += r.thinks end
print(string.format("\n## Cost\nBotAI.think: %.1f microseconds per server tick on average (%d ticks, this machine, plain Luau).", 1e6 * t / n, n))
