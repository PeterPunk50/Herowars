-- HeroEngine Phase 0: a fighter's state, with the transitions every character shares.
-- Idle -> Startup -> Active -> Recovery -> Idle is driven by AbilitySystem from the move's frame data;
-- Stunned and Dead are entered by hits. A state with `untilTick` ends by itself when the clock passes it.
local StateMachine = {}

StateMachine.States = {"Idle", "Startup", "Active", "Recovery", "Stunned", "Dead"}

-- Which state may follow which. Anything not listed is refused (and reported by `set`).
StateMachine.Allowed = {
 Idle = {Startup = true, Stunned = true, Dead = true},
 Startup = {Active = true, Stunned = true, Dead = true, Idle = true}, -- Idle: cancelled
 Active = {Recovery = true, Stunned = true, Dead = true},
 Recovery = {Idle = true, Stunned = true, Dead = true, Startup = true}, -- Startup: a cancel into the next move
 Stunned = {Idle = true, Stunned = true, Dead = true},
 Dead = {Idle = true}, -- respawn
}

function StateMachine.new()
 return {name = "Idle", since = 0, untilTick = nil}
end

-- Move to `name` at tick `now`. Returns true, or false and why.
function StateMachine.set(sm, name, now, untilTick)
 if sm.name == name and name ~= "Stunned" then sm.untilTick = untilTick; return true end
 local ok = StateMachine.Allowed[sm.name] and StateMachine.Allowed[sm.name][name]
 if not ok then return false, sm.name .. " -> " .. name .. " is not allowed" end
 sm.name, sm.since, sm.untilTick = name, now, untilTick
 return true
end

-- A timed state (a stun) that has run out goes back to Idle.
function StateMachine.update(sm, now)
 if sm.untilTick and now >= sm.untilTick and sm.name == "Stunned" then
  StateMachine.set(sm, "Idle", now)
 end
 return sm.name
end

function StateMachine.canAct(sm) return sm.name == "Idle" end
function StateMachine.busy(sm) return sm.name ~= "Idle" end

return StateMachine
