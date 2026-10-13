-- Pure presentation state logic; never changes flight physics or combat timing.
local Motion={}
function Motion.step(s,input,now)
 local nextState="Ground"
 if not input.alive or (input.locked and not input.flying) then
  s.airborne=false; s.wasFlying=false; s.landUntil=0; s.takeoff=nil; s.brakeUntil=0
 elseif input.flying then
  if not s.wasFlying then s.takeoff=now end
  s.airborne=true
  if (s.speed or 0)>8 and input.speed<(s.speed or 0)-3 then s.brakeUntil=now+0.24 end
  local forward=input.forwardSpeed or input.speed
  -- R29: stunned or frozen in the air stays upright (it used to drop to the ground state, which let a
  -- flat flight capture show).
  if input.locked then nextState="Hover"
  elseif now-(s.takeoff or now)<0.45 then nextState="Takeoff"
  elseif input.speed<2 then nextState="Hover" -- R20: settles upright sooner when you stop
  elseif input.vertical< -4 and forward>4 then nextState="Dive"
  elseif now<(s.brakeUntil or 0) then nextState="Brake"
  elseif forward>4 then nextState="Cruise"
  else nextState="Hover" end
 else
  if s.airborne and input.grounded then s.airborne=false; s.landUntil=now+0.42
  elseif s.airborne then nextState="Descend" end
  if now<(s.landUntil or 0) then nextState="Land" end
 end
 if nextState~=s.name then s.changed=true; s.since=now else s.changed=false end
 s.name=nextState; s.speed=input.speed; s.wasFlying=input.flying and input.alive and not input.locked
 return s
end
return Motion
