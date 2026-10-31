-- R66-ui9 Tactical bot AI (ServerScriptService.HeroWars.BotAI). Peter, 2026-10-12: "Bot AI Strategy &
-- Priority System" for our four heroes. Main's botThink calls BotAI.think(s, ctx) every server tick while
-- the sparring bot is in its match. All numbers live in Rules.BotAI (strategy kits, priorities, Easy /
-- Normal / Hard), so tuning never needs this file.
--
-- Parts: sense (what the bot can see), memory (the enemy's recent attacks and rhythm), tactics (one check
-- per tactic Type), choose (priority score), act (press the button through Main's doAction, same rules as a
-- player), move (spacing, strafing, flight) and telemetry (AI_* attributes, optional Output log).
-- Fair play: enemy attacks are noticed only React ticks after they start, invisible enemies can't be
-- targeted, and every press goes through the normal cooldown / Fury / recovery checks.
--
-- R66-ui12 (Peter, 2026-10-31: "the bot just runs up to the opponent and starts chopping, make it more strategic
-- and tactical"): a stance layer on top of the tactics. The bot is always in one stance:
--   neutral    waits just outside the enemy's reach and circles (footsies), pokes with ranged moves only
--   engage     goes in for a short burst (Burst presses), then
--   disengage  steps back out to the edge of reach (hit and out), and
--   retreat    backs off while low on health, circling so it doesn't run off the arena.
-- Melee, Combo and GapClose tactics only fire while engaging. Punish, Defend, Interrupt, AntiAir, Ranged, Zone and
-- Evade work in every stance, so a miss or a stun still gets punished at once (and switches it to engage).
-- Each hero has a Style in Rules.BotAI.Styles (Bulwark pushes forward, Tempest kites, Solarion dives in and out,
-- Wraithstep waits and strikes). A hero with no kit gets an automatic one (BotAI.autoKit), so new heroes fight too.
local BotAI = {}

local function rand(r) return math.random(r[1], r[2]) end
local OFFENCE -- R66-ui12, set below
-- R66-ui10: PathfindingService in the game; nil in the offline test.
local PFS = typeof(game) == "Instance" and game:GetService("PathfindingService") or nil

-- ctx (from Main): Rules, now() = server tick, states, foe(s,t), alive(s), doAction(s,action,data),
-- level() = "Easy"/"Normal"/"Hard", clearSight(s,t), flatUnit(v,fallback), groundHeight(s).
local function cfg(ctx) return ctx.Rules.BotAI end

-- The move a button would fire right now (nil if the hero hasn't got it).
local function moveFor(ctx, s, use)
 local Rules = ctx.Rules
 if use == "Defensive" or use == "Dash" or use == "Flight" then return nil end
 if not Rules.actionAvailable(s.hero, use) then return nil end
 local now = ctx.now()
 local name
 if use == "Light" then
  if now < (s.phaseUntil or 0) then name = "ShadeBolt"
  else name = Rules.moveName(s.hero, "Light", now <= (s.comboUntil or 0) and (s.combo or 0) % 3 + 1 or 1) end
 else name = Rules.moveName(s.hero, use, 1) end
 return name and Rules.heroMove(s.hero, name), name
end

-- Can this button be pressed now? Returns ok, reason ("cooldown", "fury", "gcd", "missing", "busy").
local function ready(ctx, s, use)
 local Rules, now = ctx.Rules, ctx.now()
 if not Rules.actionAvailable(s.hero, use) then return false, "missing" end
 if use == "Defensive" then
  if now < (s.cooldowns.Defensive or 0) then return false, "cooldown" end
  return true
 end
 if use == "Flight" then
  if not Rules.Characters[s.hero].Flies then return false, "missing" end
  if (s.energy or 0) < Rules.Flight.Takeoff + 15 then return false, "energy" end
  return true
 end
 if use == "Dash" then return now >= (s.cooldowns.Dash or 0) and not s.flying, "cooldown" end
 local move, name = moveFor(ctx, s, use)
 if not move then return false, "missing" end
 if now < (s.cooldowns[name] or 0) then return false, "cooldown" end
 if move.Cost then
  if now < (s.gcd or 0) then return false, "gcd" end
  if (s.fury or 0) < move.Cost then return false, "fury" end
 end
 -- Busy: like a player, a press up to BufferFrames before it can act is held by the server and fires then.
 local buffer = Rules.BufferFrames
 if now < (s.parryUntil or 0) or (s.stunned or 0) - now > buffer then return false, "busy" end
 local a = s.action
 if a and Rules.phase(a.move, a.frame, a.extra) ~= "Recovery" then return false, "busy" end
 return true, nil, move
end

-- How far an enemy move reaches (studs), for "will this hit me?".
local function reach(m)
 if not m then return 0 end
 if m.Whirl or m.LockOn then return (m.Range or 0) + 3 end
 return (m.Range or 0) + (m.Lunge or 0) + (m.Leap or 0) + math.max(m.Aoe or 0, m.Radius or 0) + 2.5
end
local function heavy(m)
 return m and ((m.Damage or 0) >= 12 or (m.Stun or 0) >= 40 or m.Cast or m.Whirl or m.Snare or m.Grounding or m.Throw) and true or false
end

-- R66-ui12: how far an enemy really threatens with a plain swing (Range + Lunge + a small margin), per hero.
local reachCache = {}
local function threatReach(m) return m and (m.Range or 0) + (m.Lunge or 0) + 1 or 0 end
local function heroReach(ctx, hero)
 if reachCache[hero] then return reachCache[hero] end
 local Rules = ctx.Rules
 local r = 0
 for _, name in {"Light1", "Light2", "Heavy"} do
  local ok, m = pcall(Rules.heroMove, hero, name)
  if ok and m and not m.Cast and not m.Beam then r = math.max(r, threatReach(m)) end
 end
 if r == 0 then r = 8 end
 reachCache[hero] = r
 return r
end

-- Pattern memory: the enemy's attack starts. Spam = SpamCount starts inside SpamWindow; with Learn the bot
-- expects the next start one average gap after the last.
local function remember(ctx, ai, t, act, dist)
 local C = cfg(ctx)
 table.insert(ai.seen, {name = act.name, at = ctx.now(), dist = dist, act = act})
 while #ai.seen > C.Memory do table.remove(ai.seen, 1) end
end
local function rhythm(ctx, ai)
 local C, now = cfg(ctx), ctx.now()
 local recent = {}
 for _, e in ai.seen do if now - e.at <= C.SpamWindow then table.insert(recent, e) end end
 local spam = #recent >= C.SpamCount
 local gap
 if #recent >= 2 then gap = (recent[#recent].at - recent[1].at) / (#recent - 1) end
 return spam, gap, recent[#recent]
end

-- What the bot can see this tick.
local function sense(ctx, s, ai)
 local now, Rules = ctx.now(), ctx.Rules
 local best, bestDist
 for key, t in ctx.states do
  if typeof(key) == "Instance" and key:IsA("Player") and ctx.alive(t) and ctx.foe(s, t) and not t.model:GetAttribute("Invisible") then
   local d = (t.root.Position - s.root.Position).Magnitude
   if not bestDist or d < bestDist then best, bestDist = t, d end
  end
 end
 local e = {t = best, dist = bestDist, now = now}
 if not best then return e end
 ai.lastSeen = {pos = best.root.Position, at = now}
 local delta = best.root.Position - s.root.Position
 e.delta = delta
 e.flat = ctx.flatUnit(delta, s.root.CFrame.LookVector)
 e.hp = s.hum.Health / s.hum.MaxHealth
 e.thp = best.hum.Health / best.hum.MaxHealth
 e.tAir = best.flying or best.hum.FloorMaterial == Enum.Material.Air
 e.rise = delta.Y
 e.tWhirl = best.whirl ~= nil
 e.tParry = now < (best.parryUntil or 0)
 e.tShield = (best.shieldHP or 0) > 0
 e.tInvuln = now < (best.invulnerable or 0)
 -- Held: stunned, snared or reeling, and hittable (a Whirlwind spin can't be hit).
 e.tHeld = (now < (best.stunned or 0) or best.snare ~= nil) and not e.tWhirl and not e.tInvuln
 -- The enemy's current attack, as the bot perceives it.
 local act = best.action
 if act ~= ai.watch then
  if ai.watch then ai.lastWatch = {act = ai.watch, endedAt = now} end
  ai.watch = act; ai.watchAt = now
  if act then
   local react = rand(cfg(ctx).Difficulty[ctx.level()].React)
   if ai.expectAt and math.abs(now - ai.expectAt) <= 10 then react = math.floor(react / 2); ai.anticipated = true else ai.anticipated = false end
   ai.react = react
   remember(ctx, ai, best, act, bestDist)
  end
 end
 if act and now - ai.watchAt >= (ai.react or 0) then
  e.act = act; e.move = act.move
  e.phase = Rules.phase(act.move, act.frame, act.extra)
  e.toHit = math.max(0, act.move.Startup - act.frame)
  e.casting = act.move.Cast and e.phase == "Startup"
  e.threat = (e.phase == "Startup" or e.phase == "Active") and bestDist <= reach(act.move)
  e.heavy = heavy(act.move)
  e.whiff = e.phase == "Recovery" and not act.contact
  e.newSeen = ai.noticed ~= act
 end
 -- A miss the bot noticed just after it ended still counts as an opening for a moment.
 if not e.whiff and ai.lastWatch and ai.lastWatch.act and not ai.lastWatch.act.contact and now - ai.lastWatch.endedAt <= 6 then
  e.whiff = Rules.phase(ai.lastWatch.act.move, ai.lastWatch.act.frame, ai.lastWatch.act.extra) ~= "Startup"
 end
 e.spam, e.gap, e.last = rhythm(ctx, ai)
 if e.spam and e.gap and e.last then ai.expectAt = e.last.at + e.gap else ai.expectAt = nil end
 e.tFlier = Rules.Characters[best.hero] and Rules.Characters[best.hero].Flies
 -- R66-ui12: the enemy's swing reach, and whether its defensive is spent (the effect ended, so a player can tell).
 e.tReach = heroReach(ctx, best.hero)
 e.tDefDown = best.cooldowns ~= nil and now < (best.cooldowns.Defensive or 0)
 return e
end

-- One roll per thing (an enemy attack, a stun), so a chance isn't re-rolled every tick.
local function roll(ai, key, p)
 ai.rolls = ai.rolls or {}
 local r = ai.rolls[key]
 if r == nil then r = math.random() < p; ai.rolls[key] = r end
 return r
end

local function respects(ai, e, diff)
 if not (e.tParry or e.tWhirl or e.tShield or e.tInvuln) then return false end
 return roll(ai, "respect" .. tostring(e.t.parryUntil) .. tostring(e.tWhirl) .. tostring(e.tShield), diff.Respect)
end

-- Tactic checks: return a bonus score if the tactic fits the fight now, or nil.
local TYPES = {}
TYPES.StunBreak = function(ctx, s, ai, e, tac, diff)
 local now = ctx.now()
 local stunLeft = (s.stunned or 0) - now
 local held = s.whirl or s.snare or now < (s.downUntil or 0) or stunLeft >= 40
 if not held then return nil end
 if not roll(ai, "trinket" .. tostring(s.stunned), diff.Trinket) then return nil end
 return (e.hp or 1) < 0.5 and 40 or 0
end
TYPES.Defend = function(ctx, s, ai, e, tac, diff)
 -- R66-ui12: the defensive is saved for big hits, except when low on health (then anything that would land).
 local low = (e.hp or 1) < cfg(ctx).LowHealth + 0.1
 if not e.threat or (tac.Heavy and not e.heavy and not low) then return nil end
 if e.toHit > (tac.Lead or 20) then return nil end
 if not roll(ai, "defend" .. tostring(e.act), diff.Defend) then return nil end
 return e.heavy and 30 or 0
end
TYPES.Evade = function(ctx, s, ai, e, tac, diff)
 -- No button: step out of a noticed attack's reach (melee) or sideways (a ranged line). Lock-ons can't be walked out of.
 if not e.threat or e.toHit < 3 or e.move.LockOn or e.move.Whirl or s.flying then return nil end
 -- R66-ui12: its own Dodge chance (was the Defend chance), and a big cast or heavy blow is dodged first.
 if not roll(ai, "evade" .. tostring(e.act), diff.Dodge or diff.Defend) then return nil end
 return (e.casting or e.heavy) and 40 or 0
end
TYPES.Escape = function(ctx, s, ai, e, tac, diff)
 if (e.hp or 1) > cfg(ctx).LowHealth or e.dist > (tac.Max or 10) then return nil end
 if not roll(ai, "escape" .. tostring(math.floor(ctx.now() / 120)), diff.Defend) then return nil end
 ai.retreatUntil = ctx.now() + 60
 return 20
end
TYPES.Interrupt = function(ctx, s, ai, e, tac, diff)
 if not e.casting then return nil end
 local m = moveFor(ctx, s, tac.Use)
 if not m or e.dist > math.min(tac.Max or 999, reach(m) - 1) then return nil end
 if e.toHit <= (m.Startup or 0) + 2 then return nil end
 if not roll(ai, "interrupt" .. tostring(e.act), diff.Interrupt) then return nil end
 return 20
end
TYPES.Peel = function(ctx, s, ai, e, tac, diff)
 if e.dist > (tac.Max or 8) or e.tHeld then return nil end
 return roll(ai, "peel" .. tostring(math.floor(ctx.now() / 90)), diff.Spacing) and 0 or nil
end
TYPES.AntiAir = function(ctx, s, ai, e, tac, diff)
 if not e.tAir or e.dist > (tac.Max or 40) or e.dist < (tac.Min or 0) or e.tWhirl then return nil end
 if not roll(ai, "air" .. tostring(math.floor(ctx.now() / 60)), diff.AntiAir) then return nil end
 return math.clamp(e.rise or 0, 0, 20)
end
TYPES.Punish = function(ctx, s, ai, e, tac, diff)
 if not (e.whiff or e.tHeld) or e.dist > (tac.Max or 8) or e.dist < (tac.Min or 0) then return nil end
 if respects(ai, e, diff) then return nil end
 local key = e.whiff and ("whiff" .. tostring(ai.lastWatch and ai.lastWatch.act or e.act)) or ("held" .. tostring(e.t.stunned))
 if not roll(ai, key, diff.Counter) then return nil end
 local m = moveFor(ctx, s, tac.Use)
 return m and (m.Damage or 0) or 0
end
TYPES.Combo = function(ctx, s, ai, e, tac, diff)
 if e.dist > (tac.Max or 6) or e.tAir and e.rise > 6 then return nil end
 if respects(ai, e, diff) then return nil end
 return e.tHeld and 30 or 0
end
TYPES.Melee = function(ctx, s, ai, e, tac, diff)
 if e.dist > (tac.Max or 6) or e.dist < (tac.Min or 0) then return nil end
 if respects(ai, e, diff) then return nil end
 return 0
end
TYPES.GapClose = function(ctx, s, ai, e, tac, diff)
 if e.dist < (tac.Min or 0) or e.dist > (tac.Max or 30) then return nil end
 return 0
end
TYPES.Ranged = function(ctx, s, ai, e, tac, diff)
 if e.dist < (tac.Min or 0) or e.dist > (tac.Max or 40) then return nil end
 if tac.Held and not e.tHeld then return nil end
 if tac.Phased and ctx.now() >= (s.phaseUntil or 0) then return nil end
 if not tac.Phased and tac.Use == "Light" then return nil end
 if e.tWhirl or respects(ai, e, diff) then return nil end
 if ctx.clearSight and not ctx.clearSight(s, e.t) then return nil end
 return 0
end
TYPES.Zone = function(ctx, s, ai, e, tac, diff)
 if e.dist > (tac.Max or 9) then return nil end
 if tac.Held and not e.tHeld then return nil end
 return 0
end
TYPES.Phase = function(ctx, s, ai, e, tac, diff)
 if ctx.now() < (s.phaseUntil or 0) then return nil end
 if e.tAir and (e.rise or 0) > 6 then return 40 end -- Shade Bolts lock on to a flyer
 if e.dist < (tac.Min or 12) then return nil end
 return 0
end
TYPES.Fly = function(ctx, s, ai, e, tac, diff)
 if s.flying then return nil end
 if tac.When == "foeFlies" then
  -- R66-ui10: also when the enemy stands high up (on the pyramid).
  if not ((e.rise or 0) > 6) then return nil end
  return roll(ai, "fly" .. tostring(math.floor(ctx.now() / 120)), diff.AntiAir) and 0 or nil
 end
 if tac.When == "kited" then
  ai.farSince = e.dist > 30 and (ai.farSince or ctx.now()) or nil
  if not ai.farSince or ctx.now() - ai.farSince < 120 then return nil end
  return 0
 end
 return nil
end
TYPES.Reveal = function(ctx, s, ai, e, tac, diff) return nil end -- only used when no enemy is visible (below)
TYPES.Bait = function(ctx, s, ai, e, tac, diff)
 if not diff.Learn or not e.spam or not ai.expectAt or not e.last then return nil end
 local soon = ai.expectAt - ctx.now()
 if soon < -4 or soon > 24 then return nil end
 local m = e.last.act and e.last.act.move
 if not m or e.dist > reach(m) + 1 then return nil end
 -- One bait per expected attack, and not back to back.
 if ai.baitFor == e.last.at or ctx.now() - (ai.baitAt or -999) < 60 then return nil end
 if not roll(ai, "bait" .. tostring(e.last.at), diff.Bait) then return nil end
 return 0
end
BotAI.Types = TYPES

-- Fury reserve (Normal/Hard): against a flying hero, keep enough Fury for the anti-air move.
local function reserveBlocks(ctx, s, kit, tac, e, diff)
 if not diff.Reserve or not kit.Reserve or tac.P == 1 or not e.tFlier or tac.Use == kit.Reserve then return false end
 local m = moveFor(ctx, s, tac.Use)
 local keep = moveFor(ctx, s, kit.Reserve)
 if not m or not m.Cost or not keep or not keep.Cost then return false end
 return (s.fury or 0) - m.Cost < keep.Cost
end

-- R66-ui12: tactics that walk the bot into the enemy; only while engaging.
OFFENCE = {Melee = true, Combo = true, GapClose = true}

local function setAttr(s, name, value)
 if s.model:GetAttribute(name) ~= value then s.model:SetAttribute(name, value) end
end

local function log(ctx, s, ai, text)
 local C = cfg(ctx)
 if C.Debug then print(string.format("[BotAI] t=%d %s %s: %s", ctx.now(), ctx.level(), s.hero, text)) end
end

-- Press a button; a combo tactic queues the rest of its chain.
local function press(ctx, s, ai, tac, use, score)
 local now = ctx.now()
 ctx.doAction(s, use)
 ai.stats.presses += 1
 -- R66-ui12: for hit-and-out, variety and the pressure timer.
 ai.lastPressAt = now; ai.lastTac = tac.Id; ai.lastTacAt = now
 if OFFENCE[tac.Type] or tac.Type == "Punish" then ai.engagePresses = (ai.engagePresses or 0) + 1 end
 local C = cfg(ctx)
 if C.Attributes then
  setAttr(s, "AI_Tactic", tac.Id); setAttr(s, "AI_Priority", "P" .. tac.P)
  setAttr(s, "AI_Score", math.floor(score)); setAttr(s, "AI_Move", use)
 end
 local reaction = ai.watch and now - (ai.watchAt or now) or nil
 if ctx.onPress then ctx.onPress(s, tac, use, score, reaction) end
 if ai.watch and (tac.Type == "Defend" or tac.Type == "Interrupt" or tac.Type == "Punish") then
  ai.noticed = ai.watch
  if C.Attributes then setAttr(s, "AI_React", reaction) end
  log(ctx, s, ai, string.format("%s P%d %s (score %d, reacted in %d ticks%s)", tac.Id, tac.P, use, score, reaction, ai.anticipated and ", anticipated" or ""))
 else
  log(ctx, s, ai, string.format("%s P%d %s (score %d)", tac.Id, tac.P, use, score))
 end
end

-- R66-ui12 stances. Style = Rules.BotAI.Styles[hero] (or Default).
local function styleOf(ctx, s)
 local C = cfg(ctx)
 return C.Styles and (C.Styles[s.hero] or C.Styles.Default) or {}
end
local function setStance(ctx, s, ai, diff, name, ticks, why)
 local now = ctx.now()
 if ai.stance ~= name then log(ctx, s, ai, "stance " .. name .. " (" .. why .. ")") end
 ai.stance = name; ai.stanceUntil = now + ticks
 if name == "engage" then ai.engagePresses = 0; ai.engageQuota = rand(diff.Burst or {1, 3}) end
 if cfg(ctx).Attributes then setAttr(s, "AI_Stance", name) end
end
local function chooseStance(ctx, s, ai, e, diff, kit, st)
 local C, now = cfg(ctx), ctx.now()
 local cur = ai.stance
 local hp, thp = e.hp or 1, e.thp or 1
 -- 1. Low on health and behind: back off for a while (Bulwark's style never does).
 local lowAt = st.RetreatHP or C.LowHealth
 if cur ~= "retreat" and hp < lowAt and thp > hp + 0.1 and not e.tHeld then
  if roll(ai, "retreat" .. tostring(math.floor(now / 240)), diff.Retreat or 0) then
   setStance(ctx, s, ai, diff, "retreat", rand(st.RetreatTime or {90, 150}), "low health"); return
  end
 end
 if cur == "retreat" and now < (ai.stanceUntil or 0) then return end
 -- 2. An opening: the enemy missed, is held, is nearly dead, or (Read) has spent its defensive.
 local opening = e.whiff or e.tHeld or thp < 0.25 or (diff.Read and e.tDefDown and (e.dist or 99) < (kit.Ideal or 5) + 12)
 if opening and cur ~= "engage" then
  setStance(ctx, s, ai, diff, "engage", rand({60, 100}), e.whiff and "you missed" or e.tHeld and "you are held" or thp < 0.25 and "you are low" or "your defensive is down")
  return
 end
 -- 3. Hit and out: the burst is spent and its last move is over.
 if cur == "engage" and (ai.engagePresses or 0) >= (ai.engageQuota or 2) and not s.action and not (ai.plan and #ai.plan > 0) then
  if math.random() < (diff.Discipline or 0.5) * (st.HitAndOut or 0.5) then
   setStance(ctx, s, ai, diff, "disengage", rand(st.OutTime or {30, 55}), "hit and out"); return
  end
  ai.engageQuota = (ai.engageQuota or 2) + rand(diff.Burst or {1, 3}) -- keeps swinging (the old rush)
 end
 -- 4. The enemy walks into its space while it waits: check them.
 if (cur == "neutral" or cur == "disengage") and (e.dist or 99) < (kit.Ideal or 5) + 1.5 and not e.act
  and roll(ai, "check" .. tostring(math.floor(now / 30)), diff.Counter or 0.2) then
  setStance(ctx, s, ai, diff, "engage", rand({45, 80}), "you walked in"); return
 end
 -- 5. The stance ran out: go in or wait, by style, health lead and patience.
 if now >= (ai.stanceUntil or 0) then
  local aggro = (st.Aggro or 0.5) + (hp - thp) * 0.5
  local why = "style"
  if now - (ai.lastPressAt or now - 9999) > (diff.Pressure or 180) then aggro = 1; why = "nothing happening" end
  if math.random() >= (diff.Patience or 0.6) then aggro = 1; why = "impatient" end
  if math.random() < aggro then setStance(ctx, s, ai, diff, "engage", rand(st.EngageTime or {60, 120}), why)
  else setStance(ctx, s, ai, diff, "neutral", rand(st.NeutralTime or {40, 90}), "waiting for an opening") end
 end
end

-- Pick the best tactic for this moment and use it. Returns true if something was pressed.
local function decide(ctx, s, ai, e, diff, kit)
 local C, now = cfg(ctx), ctx.now()
 local fits, rejected = {}, nil
 local engaging = ai.stance == nil or ai.stance == "engage"
 for _, tac in kit.Tactics do
  local check = TYPES[tac.Type]
  local bonus = (engaging or not OFFENCE[tac.Type]) and check and check(ctx, s, ai, e, tac, diff)
  -- R66-ui12: the same tactic twice in a row scores less, so it mixes its moves.
  if bonus and tac.Id == ai.lastTac and now - (ai.lastTacAt or -999) < 150 then bonus -= (diff.Variety or 0) end
  if bonus then
   local ok, why = true, nil
   if tac.Use then ok, why = ready(ctx, s, tac.Use) end
   if ok and tac.Type == "Combo" then ok, why = ready(ctx, s, tac.Chain[1]) end
   if ok and tac.Use and reserveBlocks(ctx, s, kit, tac, e, diff) then ok, why = false, "reserve" end
   if ok then
    table.insert(fits, {tac = tac, score = C.PriorityScore[tac.P] + bonus + (tac.Bonus or 0) + math.random() * diff.Noise})
   elseif not rejected then rejected = tac.Id .. ": " .. tostring(why) end
  end
 end
 if rejected then
  ai.stats.rejects += 1
  if C.Attributes then setAttr(s, "AI_Reject", rejected) end
 end
 if #fits == 0 then return false end
 table.sort(fits, function(a, b) return a.score > b.score end)
 local pick = fits[1]
 if #fits > 1 and math.random() < diff.Mistake then pick = fits[math.random(2, #fits)] end
 local tac = pick.tac
 if tac.Type == "Bait" then
  ai.mode = "bait"; ai.modeUntil = (ai.expectAt or now) + 12; ai.baitFor = e.last.at; ai.baitAt = now
  ai.baitReach = reach(e.last.act.move) + 1.5
  if C.Attributes then setAttr(s, "AI_Tactic", tac.Id); setAttr(s, "AI_Priority", "P" .. tac.P); setAttr(s, "AI_Move", "step back") end
  if ctx.onPress then ctx.onPress(s, tac, "bait", pick.score, nil) end
  log(ctx, s, ai, "BaitSpam: steps out of reach of the expected attack")
  return true
 end
 if tac.Type == "Punish" and ai.stance ~= "engage" and ai.stance ~= "retreat" then
  setStance(ctx, s, ai, diff, "engage", rand({50, 80}), "punish")
  ai.engagePresses = 0
 end
 if tac.Type == "Evade" then
  local ranged = (e.move.Range or 0) > 12
  ai.mode = ranged and "sidestep" or "evade"; ai.modeUntil = now + e.toHit + 14
  ai.sideSign = math.random() < 0.5 and 1 or -1
  if C.Attributes then setAttr(s, "AI_Tactic", tac.Id); setAttr(s, "AI_Priority", "P" .. tac.P); setAttr(s, "AI_Move", ranged and "sidestep" or "step back") end
  if ctx.onPress then ctx.onPress(s, tac, ai.mode, pick.score, now - (ai.watchAt or now)) end
  log(ctx, s, ai, string.format("%s: %s from %s (%d ticks to impact)", tac.Id, ai.mode, tostring(e.act.name), e.toHit))
  return true
 end
 if tac.Type == "Fly" then
  press(ctx, s, ai, tac, "Flight", pick.score); return true
 end
 if tac.Type == "Combo" then
  local n = math.min(#tac.Chain, rand(diff.Combo))
  ai.plan = table.move(tac.Chain, 2, n, 1, {}); ai.planTac = tac
  press(ctx, s, ai, tac, tac.Chain[1], pick.score)
  return true
 end
 if tac.Type == "Defend" and tac.Use == "Dash" then s.dir = -e.flat end
 if tac.Type == "Escape" or tac.Type == "Peel" then ai.retreatUntil = now + 45 end
 press(ctx, s, ai, tac, tac.Use, pick.score)
 if tac.Type == "Defend" and (s.hero == "Tempest" or s.hero == "Wraithstep") then ai.retreatUntil = now + 30 end
 return true
end

-- R66-ui10 pathfinding (Peter: "check the path finding and the pyramids"). The bot walks straight at the enemy
-- (Wraithstep climbs walls, Bulwark jumps and pulls up ledges: the Climb module). Only when it is stuck for
-- 0.75 s, or the enemy is 5+ studs above or below it, does it ask PathfindingService for a route (the pyramid's
-- stairs) and follow the waypoints, jumping where the path says. A route is reused for 1.5 s, or until the
-- enemy has moved 10 studs from its end. Computed off the tick (task.spawn), one at a time per bot.
local function flatDist(a, b) return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude end
local function navDir(ctx, s, ai, e, want)
 if not PFS or s.flying then return want end
 local now = ctx.now()
 if now - (ai.navCheckAt or -999) >= 45 then
  local moved = ai.navLastPos and flatDist(s.root.Position, ai.navLastPos) or 99
  ai.stuck = moved < 1.5 and e.dist > 6
  ai.navLastPos = s.root.Position; ai.navCheckAt = now
 end
 local high = math.abs(e.rise or 0) > 5
 if not (ai.stuck or high) then ai.path = nil; return want end
 local goal = e.t.root.Position
 if not ai.pathBusy and (not ai.path or now >= (ai.pathAt or 0) + 90 or flatDist(ai.pathGoal, goal) > 10) then
  ai.pathBusy = true
  local from = s.root.Position
  local big = (ctx.Rules.Characters[s.hero].Scale or 1) > 1.1
  task.spawn(function()
   local path = PFS:CreatePath({AgentRadius = big and 3 or 2.2, AgentHeight = big and 7 or 5.5, AgentCanJump = true, WaypointSpacing = 4})
   local ok = pcall(function() path:ComputeAsync(from, goal) end)
   if ok and path.Status == Enum.PathStatus.Success then ai.path = path:GetWaypoints(); ai.wp = 2 else ai.path = nil end
   ai.pathAt = ctx.now(); ai.pathGoal = goal; ai.pathBusy = false
   ai.stats.paths = (ai.stats.paths or 0) + 1
  end)
 end
 if ai.path then
  local wp = ai.path[ai.wp or 2]
  while wp and flatDist(wp.Position, s.root.Position) < 2.5 do ai.wp += 1; wp = ai.path[ai.wp] end
  if not wp then ai.path = nil; return want end
  if wp.Action == Enum.PathWaypointAction.Jump and s.hum.FloorMaterial ~= Enum.Material.Air then s.hum.Jump = true end
  local d = Vector3.new(wp.Position.X - s.root.Position.X, 0, wp.Position.Z - s.root.Position.Z)
  if d.Magnitude > 0.1 then return d.Unit end
 end
 return want
end

-- R66-ui12: never back off a ledge. A step that has no floor under it (12 studs down, 4 studs ahead) is turned
-- into a sidestep, or cancelled. Only checked when the bot moves away from or around the enemy.
local function safeDir(ctx, s, e, dir)
 if typeof(workspace) ~= "Instance" or dir.Magnitude < 0.1 or s.flying then return dir end
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = {s.model, e.t.model}
 local function hasFloor(d)
  local from = s.root.Position + d.Unit * 4
  return workspace:Raycast(from, Vector3.new(0, -12, 0), params) ~= nil
 end
 if hasFloor(dir) then return dir end
 local side = e.flat:Cross(Vector3.yAxis)
 for _, alt in {side, -side} do if hasFloor(alt) then return alt end end
 return Vector3.zero
end
local function blend(a, wa, b, wb)
 local v = a * wa + b * wb
 return v.Magnitude > 0.05 and v.Unit or Vector3.zero
end

-- Movement every tick: keep the kit's range, strafe, step out for a bait, retreat, fly.
local function move(ctx, s, ai, e, diff, kit)
 local now = ctx.now()
 local flat = e.flat
 local side = flat:Cross(Vector3.yAxis)
 local dir = Vector3.zero
 local state
 local st = styleOf(ctx, s)
 -- R66-ui12: the neutral ring = just outside the enemy's swing (never closer than the kit's own range).
 local ring = math.max(kit.Ideal or 5, (e.tReach or 8) + (st.Margin or 1.5))
 if not ai.strafeAt or now >= ai.strafeAt then
  ai.strafeAt = now + math.random(30, 70)
  ai.strafeSign = math.random() < 0.5 and 1 or -1
  ai.strafing = math.random() < diff.Spacing
 end
 if ai.mode == "bait" and now < (ai.modeUntil or 0) then dir = e.dist < (ai.baitReach or 9) and -flat or Vector3.zero; state = "baiting"
 elseif ai.mode == "evade" and now < (ai.modeUntil or 0) then dir = safeDir(ctx, s, e, -flat); state = "evading"
 elseif ai.mode == "sidestep" and now < (ai.modeUntil or 0) then dir = safeDir(ctx, s, e, side * (ai.sideSign or 1)); state = "sidestepping"
 elseif now < (ai.retreatUntil or 0) then dir = safeDir(ctx, s, e, -flat); state = "retreating"
 elseif e.tWhirl and e.dist < (e.tReach or 8) + 4 then
  -- Don't walk into a Whirlwind spin.
  dir = safeDir(ctx, s, e, blend(-flat, 0.8, side * (ai.strafeSign or 1), 0.6)); state = "keeping out of the spin"
 elseif ai.stance == "retreat" then
  -- Back off in a curve (circling away), so it doesn't run straight off the arena; far enough away it just circles.
  if e.dist < ring + 10 then dir = safeDir(ctx, s, e, blend(-flat, 0.75, side * (ai.strafeSign or 1), 0.65))
  else dir = safeDir(ctx, s, e, side * (ai.strafeSign or 1)) end
  state = "backing off (low)"
 elseif ai.stance == "disengage" then
  if e.dist < ring then dir = safeDir(ctx, s, e, blend(-flat, 0.8, side * (ai.strafeSign or 1), 0.5)); state = "stepping out"
  else dir = safeDir(ctx, s, e, side * (ai.strafeSign or 1)); state = "resetting" end
 elseif ai.stance == "neutral" then
  -- Footsies: hover at the ring and circle; creep in (Advance styles) or back up to keep the gap.
  if e.dist > ring + 2.5 then
   dir = navDir(ctx, s, ai, e, blend(flat, 0.85, side * (ai.strafeSign or 1), 0.45)); state = "edging in"
  elseif e.dist < ring - 1.5 and not st.Advance then
   dir = safeDir(ctx, s, e, blend(-flat, 0.7, side * (ai.strafeSign or 1), 0.6)); state = "keeping the gap"
  elseif st.Advance and e.dist > (kit.Ideal or 5) + 3 then
   dir = blend(flat, 0.45, side * (ai.strafeSign or 1), 0.8); state = "pressing forward"
  else
   dir = safeDir(ctx, s, e, side * (ai.strafeSign or 1)); state = "circling at range"
  end
 elseif e.dist > (kit.Ideal or 5) + 1.5 then
  dir = navDir(ctx, s, ai, e, flat); state = ai.path and "following a path" or "closing in"
 elseif e.dist < (kit.Min or 2) and roll(ai, "space" .. tostring(math.floor(now / 30)), diff.Spacing) then dir = safeDir(ctx, s, e, -flat); state = "making space"
 else
  dir = ai.strafing and side * ai.strafeSign or Vector3.zero
  state = ai.strafing and "circling" or "holding"
 end
 if s.flying then
  -- Flight: match the enemy's height (a little above), land before the energy runs out.
  local want = (e.t.flying or e.rise > 4) and (e.rise + 3) or -6
  local y = math.clamp(want / 8, -1, 1)
  dir = Vector3.new(dir.X, y, dir.Z)
  if (s.energy or 0) <= (kit.LandEnergy or 30) or (not e.t.flying and e.dist < 12 and e.rise > -3) then
   if not ai.landAt or now - ai.landAt > 30 then ai.landAt = now; ctx.doAction(s, "Flight"); log(ctx, s, ai, "lands (energy " .. math.floor(s.energy or 0) .. ")") end
  end
  state = "flying"
 end
 s.dir = dir
 if cfg(ctx).Attributes then setAttr(s, "AI_State", state) end
end

-- Hits and misses of the bot's own attacks (telemetry).
local function trackOwn(ctx, s, ai)
 if s.action ~= ai.own then
  if ai.own then
   if ai.own.contact then ai.stats.hits += 1 else ai.stats.misses += 1 end
   if cfg(ctx).Attributes then setAttr(s, "AI_Hits", ai.stats.hits); setAttr(s, "AI_Misses", ai.stats.misses) end
  end
  ai.own = s.action
 end
end

function BotAI.reset(s) s.ai = nil end

-- R66-ui12: a kit built from the hero's own moves, for any hero without one in Rules.BotAI.Kits (new heroes).
-- Big ranged moves poke, leaps and charges close the gap, casts with a radius are zones, Heavy punishes.
local autoKits = {}
function BotAI.autoKit(Rules, hero)
 if autoKits[hero] then return autoKits[hero] end
 local function moveOf(action)
  if not Rules.actionAvailable(hero, action) then return nil end
  local ok, m = pcall(function()
   local name = Rules.moveName(hero, action, 1)
   return name and Rules.heroMove(hero, name)
  end)
  return ok and m or nil
 end
 local t = {}
 local function add(tac) tac.Id = tac.Id or (tac.Type .. (tac.Use or "")); table.insert(t, tac) end
 if Rules.Defensives and Rules.Defensives[hero] then
  add({P = 1, Type = "StunBreak", Use = "Defensive"})
  add({P = 1, Type = "Defend", Use = "Defensive", Lead = 24, Heavy = true})
 end
 local light, heavyMove = moveOf("Light"), moveOf("Heavy")
 local melee = light and threatReach(light) or 0
 if heavyMove and not heavyMove.Cast then
  add({P = 1, Type = "Punish", Use = "Heavy", Max = threatReach(heavyMove)})
  add({P = 2, Type = "Melee", Use = "Heavy", Max = threatReach(heavyMove)})
  melee = math.max(melee, threatReach(heavyMove))
 end
 if light then
  add({P = 1, Type = "Punish", Use = "Light", Max = threatReach(light), Bonus = -10})
  add({P = 2, Type = "Combo", Chain = heavyMove and {"Light", "Light", "Light", "Heavy"} or {"Light", "Light", "Light"}, Max = threatReach(light)})
 end
 local ranged = false
 for _, action in {"Skill1", "Skill2", "Skill3", "Interrupt", "Throw"} do
  local m = moveOf(action)
  if m then
   local far = (m.Range or 0) + (m.Leap or 0)
   if m.Interrupt then add({P = 1, Type = "Interrupt", Use = action, Max = far}) end
   if (m.Radius or m.Aoe) and (m.Range or 0) < 6 and not m.Leap then
    add({P = 2, Type = "Zone", Use = action, Max = math.max(m.Radius or 0, m.Aoe or 0)})
   elseif m.Leap or m.Charge or (m.Lunge or 0) >= 6 then
    add({P = 3, Type = "GapClose", Use = action, Min = 7, Max = math.max(10, far)})
    add({P = 1, Type = "Punish", Use = action, Min = 4, Max = math.max(10, far), Bonus = -5})
   elseif (m.Range or 0) >= 14 then
    ranged = true
    add({P = 2, Type = "Ranged", Use = action, Min = 8, Max = m.Range})
    if m.AirOnly or m.Grounding then add({P = 1, Type = "AntiAir", Use = action, Max = m.Range}) end
   else
    add({P = 2, Type = "Melee", Use = action, Max = math.max(4, threatReach(m))})
   end
  end
 end
 add({P = 2, Type = "Evade", Id = "StepOut", Bonus = 40})
 local ideal = melee > 0 and math.max(3.5, melee * 0.55) or 12
 local kit = {Ideal = ideal, Min = 2, Tactics = t, Auto = true}
 if melee == 0 and ranged then kit.Ideal = 14; kit.Min = 9 end
 autoKits[hero] = kit
 return kit
end

function BotAI.think(s, ctx)
 local C = cfg(ctx)
 local kit = C.Kits[s.hero] or BotAI.autoKit(ctx.Rules, s.hero) -- R66-ui12: new heroes fight too
 local diff = C.Difficulty[ctx.level()] or C.Difficulty.Normal
 if not kit then return end
 local now = ctx.now()
 local ai = s.ai
 if not ai then
  ai = {seen = {}, stats = {presses = 0, hits = 0, misses = 0, rejects = 0}, offset = math.random(0, 5)}
  s.ai = ai
 end
 trackOwn(ctx, s, ai)
 local e = sense(ctx, s, ai)
 s.lastMove = now
 if not e.t then
  s.dir = Vector3.zero; s.lock = false; s.hasTarget = false
  -- The enemy vanished: Reveal tactics slam where they were last seen.
  local seen = ai.lastSeen
  if seen and now - seen.at <= 90 and now >= (ai.nextThink or 0) then
   ai.nextThink = now + rand(diff.Think)
   for _, tac in kit.Tactics do
    if tac.Type == "Reveal" and (seen.pos - s.root.Position).Magnitude <= (tac.Max or 12) and ready(ctx, s, tac.Use) then
     press(ctx, s, ai, tac, tac.Use, C.PriorityScore[tac.P]); break
    end
   end
  end
  if C.Attributes then setAttr(s, "AI_State", "no target") end
  return
 end
 if e.delta.Magnitude > 0.1 then s.aim = e.delta.Unit end
 s.lock = true; s.hasTarget = true
 chooseStance(ctx, s, ai, e, diff, kit, styleOf(ctx, s)) -- R66-ui12
 move(ctx, s, ai, e, diff, kit)
 -- A combo in progress: the next press as soon as the last one connects or ends.
 if ai.plan and #ai.plan > 0 then
  local a = s.action
  if not a or a.contact or (s.action and ctx.Rules.phase(a.move, a.frame, a.extra) == "Recovery") then
   local use = table.remove(ai.plan, 1)
   if not respects(ai, e, diff) and e.dist <= (ai.planTac.Max or 6) + 2 then
    ctx.doAction(s, use)
    if C.Attributes then setAttr(s, "AI_Move", use) end
   else ai.plan = nil end
  end
  return
 end
 -- Think on a timer, plus at once when something new is noticed (an attack, being stunned).
 local stunnedNow = now < (s.stunned or 0)
 local woke = ai.wasStunned and not stunnedNow
 ai.wasStunned = stunnedNow
 local urgent = (e.act and e.newSeen) or woke or ((s.stunned or 0) - now >= 40 and ai.stunSeen ~= s.stunned)
 if urgent and (s.stunned or 0) - now >= 40 then ai.stunSeen = s.stunned end
 if not urgent and now < (ai.nextThink or 0) then return end
 ai.nextThink = now + rand(diff.Think) + ai.offset
 if e.act then ai.noticed = e.act end
 decide(ctx, s, ai, e, diff, kit)
 if ai.rolls and now - (ai.rollsAt or 0) > 600 then table.clear(ai.rolls); ai.rollsAt = now end
end

return BotAI
