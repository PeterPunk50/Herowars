local Data=require(script.Parent.MotionData)
local FX=require(script.Parent.PowerFX)
local Motion={states=setmetatable({},{__mode="k"})}
local limbs={RightHip="rh",LeftHip="lh",RightKnee="rk",LeftKnee="lk",RightAnkle="ra",LeftAnkle="la"}
local solar={
 Takeoff={rx=-0.2,ry=-0.14,rh=0.3,lh=0.2,rk=-0.6,lk=-0.4,ra=-0.2,la=-0.2,rs=0.4,ls=0.4,re=1.2,le=1.2},
 Hover={rx=0,ry=0,rh=-0.08,lh=-0.14,rk=-0.1,lk=-0.16,ra=-0.24,la=-0.24,rs=0.22,ls=0.22,re=1.1,le=1.1},
 Cruise={rx=-1.05,ry=0,rh=-0.08,lh=-0.12,rk=-0.06,lk=-0.1,ra=-0.35,la=-0.35,rs=2.95,ls=-0.22,re=0.08,le=0.22},
 Brake={rx=0.18,ry=-0.08,rh=0.42,lh=0.32,rk=-0.8,lk=-0.6,ra=-0.12,la=-0.12,rs=0.6,ls=0.6,re=0.5,le=0.5},
 Dive={rx=-1.3,ry=0,rh=0,lh=-0.06,rk=-0.06,lk=-0.06,ra=-0.45,la=-0.45,rs=3.05,ls=-0.1,re=0.05,le=0.12},
 Descend={rx=0,ry=0,rh=0.15,lh=0.08,rk=-0.35,lk=-0.2,ra=-0.12,la=-0.12,rs=0.4,ls=0.4,re=0.8,le=0.8},
 Land={rx=-0.15,ry=-0.35,rh=0.7,lh=0.6,rk=-1.1,lk=-1,ra=0.2,la=0.2,rs=0.45,ls=0.45,re=0.7,le=0.7},
}
function Motion.update(model,root,now)
 local hero=model:GetAttribute("Hero")
 if hero~="Solarion" and hero~="Tempest" and hero~="Bulwark" and hero~="Wraithstep" then return end
 local hum=model:FindFirstChildOfClass("Humanoid"); if not hum then return end
 local s=Motion.states[model]
 if not s then s={transforms={},last=now,name="Ground",since=now}; Motion.states[model]=s end
 local v=root.AssemblyLinearVelocity
 local flat=Vector3.new(v.X,0,v.Z)
 local look=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
 local forward=look.Magnitude>.01 and flat:Dot(look.Unit) or 0
 Data.step(s,{flying=model:GetAttribute("Flying")==true,grounded=hum.FloorMaterial~=Enum.Material.Air,
  speed=flat.Magnitude,forwardSpeed=forward,vertical=v.Y,alive=hum.Health>0,locked=model:GetAttribute("Locked")==true},now)
 if model:GetAttribute("FlightVisualState")~=s.name then model:SetAttribute("FlightVisualState",s.name) end
 FX.flight(model,s.name,s.changed,s.speed)
 return s
end
function Motion.apply(model,motors,now,attacking)
 local s=Motion.states[model]; if not s then return end
 local dt=math.clamp(now-s.last,0,0.1); s.last=now
 if s.name=="Ground" or attacking then
  -- Animator owns the body again. Clear held smoothing targets to prevent stale re-entry.
  s.transforms={}; if s.name=="Ground" and not attacking then Motion.ground(model,motors,now) end; return
 end
 local hero=model:GetAttribute("Hero"); local p=table.clone(solar[s.name] or solar.Hover)
 local horizontal=s.name=="Cruise" or s.name=="Dive"
 if model:GetAttribute("Flying") then p.rx=horizontal and -(model:GetAttribute("RigSkin")==true and 0.85 or math.pi/2) or 0 end -- V49g: a skinned rig leans into flight instead of lying flat
 local age=now-s.since
 if hero=="Tempest" then
  -- Arms and hands stay entirely on her existing Mixamo capture. Swim through the hips/feet.
  local fast=s.name=="Cruise" or s.name=="Dive"
  p.rx=horizontal and -(model:GetAttribute("RigSkin")==true and 0.85 or math.pi/2) or 0 -- V49g
  local kick=math.sin(now*(fast and 5.5 or 2.4))*(fast and 0.16 or 0.055)
  if s.name~="Land" then
   p.rh=-0.22+kick; p.lh=-0.22-kick
   p.rk=-0.12-math.max(0,kick)*0.8; p.lk=-0.12-math.max(0,-kick)*0.8
   p.ra=fast and -0.5 or -0.32; p.la=p.ra; p.ry=math.sin(now*2.3)*0.035
  end
 end
 local weight=s.name=="Land" and math.clamp(1-age/0.42,0,1) or 1
 local alpha=1-math.exp(-dt*12)
 local function set(name,target)
  local motor=motors[name]; if not motor then return end
  local desired=motor.Transform:Lerp(target,weight)
  local prev=s.transforms[name] or motor.Transform
  local value=prev:Lerp(desired,alpha); s.transforms[name]=value; motor.Transform=value
 end
 for name,key in limbs do set(name,CFrame.Angles(p[key],0,0)) end
 set("Root",CFrame.new(0,p.ry,0)*CFrame.Angles(p.rx,0,0))
 -- Captured flight loops must not keep the torso bent when hovering upright.
 set("Waist",CFrame.identity)
 set("Neck",CFrame.Angles(horizontal and .65 or 0,0,0))
 if hero=="Solarion" then
  set("RightShoulder",CFrame.Angles(p.rs,0,0)); set("LeftShoulder",CFrame.Angles(p.ls,0,0))
  set("RightElbow",CFrame.Angles(p.re,0,0)); set("LeftElbow",CFrame.Angles(p.le,0,0))
  set("Neck",CFrame.Angles(math.clamp(-p.rx*0.55,-0.1,0.65),0,0))
 end
end
-- R16 authored silhouettes layered over the existing captured timing.
-- Angles are degrees; no root-part movement or combat timing is changed.
local function pose(root,waist,rs,ls,re,le,rh,lh)
 return {Root=root,Waist=waist,RightShoulder=rs,LeftShoulder=ls,RightElbow=re,LeftElbow=le,RightHip=rh,LeftHip=lh}
end
local styles={
 Solarion={
  Heavy={pose({-8,0,0},{0,-20,0},{-75,-10,12},{15,0,-18},{65,0,0},{55,0,0}),pose({-3,0,0},{0,12,0},{-95,0,0},{20,0,-15},{8,0,0},{45,0,0})},
  Pounce={pose({-25,0,0},{15,0,0},{35,0,20},{35,0,-20},{80,0,0},{80,0,0},{-28,0,8},{-28,0,-8}),pose({-35,0,0},{-10,0,0},{-120,0,15},{-120,0,-15},{10,0,0},{10,0,0})},
  SolarFlare={pose({0,0,0},{-8,0,0},{-65,0,38},{-65,0,-38},{100,0,0},{100,0,0}),pose({-7,0,0},{-12,0,0},{-30,0,82},{-30,0,-82},{5,0,0},{5,0,0})},
 },
 Tempest={
  Heavy={pose({0,0,6},{-8,-20,0},{-40,0,65},{-65,0,-45},{90,0,0},{70,0,0}),pose({0,0,-5},{-6,22,0},{-105,0,25},{-65,0,-60},{12,0,0},{55,0,0})},
  Lightning={pose({0,0,-5},{-10,15,0},{-145,0,20},{-35,0,-55},{35,0,0},{80,0,0}),pose({-6,0,3},{0,-12,0},{-95,0,8},{-25,0,-65},{8,0,0},{65,0,0})},
  Gale={pose({0,0,0},{-5,-30,0},{-35,0,55},{-70,0,-60},{80,0,0},{95,0,0}),pose({-5,0,0},{0,20,0},{-90,0,35},{-90,0,-35},{8,0,0},{8,0,0})},
  Whirlwind={pose({0,0,8},{-12,-15,0},{-125,0,50},{-125,0,-50},{55,0,0},{55,0,0}),pose({0,0,-8},{-12,20,0},{-155,0,35},{-155,0,-35},{10,0,0},{10,0,0})},
 },
 Bulwark={
  Heavy={pose({-10,0,0},{5,-30,0},{-145,0,25},{-55,0,-25},{70,0,0},{100,0,0}),pose({-20,0,0},{8,25,0},{-35,0,10},{-60,0,-20},{15,0,0},{100,0,0})},
  Slam={pose({-8,0,0},{-12,0,0},{-160,0,20},{-55,0,-25},{45,0,0},{100,0,0}),pose({-40,0,0},{20,0,0},{-40,0,0},{-65,0,-25},{15,0,0},{90,0,0},{-35,0,15},{-35,0,-15})},
  Charge={pose({-25,0,0},{5,15,0},{25,0,10},{-85,0,-15},{80,0,0},{105,0,0}),pose({-32,0,0},{5,15,0},{35,0,10},{-85,0,-15},{70,0,0},{95,0,0})},
  DimensionDoor={pose({-5,0,0},{0,-15,0},{-50,0,20},{-65,0,-15},{110,0,0},{100,0,0}),pose({-5,0,0},{0,15,0},{-90,0,10},{-65,0,-15},{20,0,0},{100,0,0})},
 },
 Wraithstep={
  Heavy={pose({-20,0,8},{10,-40,0},{35,0,25},{-35,0,-20},{100,0,0},{70,0,0}),pose({-25,0,-8},{5,45,0},{-65,0,-30},{30,0,-25},{15,0,0},{85,0,0})},
  Grapple={pose({-15,0,5},{8,25,0},{20,0,15},{-45,0,-25},{95,0,0},{110,0,0}),pose({-20,0,-5},{5,-25,0},{30,0,15},{-100,0,-10},{80,0,0},{10,0,0})},
  Uppercut={pose({-30,0,8},{15,-35,0},{45,0,5},{-30,0,-20},{110,0,0},{90,0,0},{-20,0,5},{-10,0,-5}),pose({-5,0,-8},{-12,35,0},{-150,0,5},{20,0,-20},{45,0,0},{75,0,0})},
  Interrupt={pose({-10,0,0},{5,-20,0},{-30,0,10},{-40,0,-15},{95,0,0},{90,0,0}),pose({-18,0,0},{0,30,0},{-100,0,-5},{20,0,-20},{10,0,0},{80,0,0})},
  ShadowCircle={pose({-30,0,0},{15,0,0},{-50,0,35},{-50,0,-35},{100,0,0},{100,0,0},{-35,0,12},{-35,0,-12}),pose({-38,0,0},{15,0,0},{-25,0,65},{-25,0,-65},{10,0,0},{10,0,0},{-40,0,12},{-40,0,-12})},
 },
}
local function angle(v) return CFrame.Angles(math.rad(v[1]),math.rad(v[2] or 0),math.rad(v[3] or 0)) end
function Motion.attack(model,motors,p,now)
 if not p then return end
 local hero=model:GetAttribute("Hero")
 if p.name=="Hurt" then
  local tilt=({Solarion=-8,Tempest=-16,Bulwark=7,Wraithstep=18})[hero] or 0
  if motors.Waist then motors.Waist.Transform*=CFrame.Angles(math.rad(tilt),0,math.rad(tilt*.35)) end
  return
 end
 if not p.move or p.name=="Pin" then return end
 local time=p.holdUntil and now<p.holdUntil and p.holdFrom or now
 local f=math.max(0,(time-p.start)*60); local m=p.move
 local pair=styles[hero] and styles[hero][p.name]
 local step=tonumber(string.match(p.name,"^Light(%d)$"))
 if step and (hero=="Solarion" or hero=="Bulwark") then
  if hero=="Solarion" then
   local side=step==2 and -1 or 1
   pair={pose({-5,0,0},{0,-side*20,0},{-35,0,18},{-35,0,-18},{90,0,0},{90,0,0}),pose({-10,0,0},{0,side*25,0},{step==2 and -35 or -95,0,10},{step==2 and -95 or -35,0,-10},{step==2 and 85 or 12,0,0},{step==2 and 12 or 85,0,0})}
   if step==3 then pair[1].RightHip={0,0,4}; pair[2].RightHip={-85,0,10}; pair[2].Root={12,0,0} end
  else
   pair={pose({-10,0,0},{0,-20,0},{-30,0,20},{-65,0,-15},{85,0,0},{100,0,0}),pose({-16,0,0},{0,step==2 and 30 or 12,0},{step==2 and -85 or -30,0,15},{step==1 and -100 or -65,0,-15},{step==2 and 20 or 80,0,0},{step==1 and 45 or 100,0,0})}
   if step==3 then pair[1].RightHip={0,0,4}; pair[2].RightHip={-65,0,18} end
  end
 end
 if not pair then return end
 local charge=math.clamp(f/math.max(1,m.Startup),0,1)
 local release=math.clamp((f-m.Startup)/math.max(1,m.Active),0,1)
 local recovery=math.clamp((f-m.Startup-m.Active)/math.max(1,m.Recovery),0,1)
 local weight=(f<=m.Startup and math.min(1,charge*4) or 1-recovery)*.92
 for name,v in pair[1] do
  local motor=motors[name]
  if motor then
   local target=angle(v):Lerp(angle(pair[2][name] or v),release)
   if m.Cast and f<m.Startup and name=="RightShoulder" then target*=CFrame.Angles(math.sin(time*4)*.025,0,0) end
   motor.Transform=motor.Transform:Lerp(target,weight)
  end
 end
end
-- Ground locomotion has a distinct posture, cadence and arm carriage for each hero.
function Motion.ground(model,motors,now)
 if model:GetAttribute("Blocking") or model:GetAttribute("Shielded") or model:GetAttribute("Parrying") or model:GetAttribute("Locked") then return end
 local root=model:FindFirstChild("HumanoidRootPart"); local hum=model:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.FloorMaterial==Enum.Material.Air then return end
 local hero=model:GetAttribute("Hero")
 local profile=({Solarion={lean=-3,stride=30,arm=28,rate=1.8,bob=.04},Tempest={lean=2,stride=18,arm=10,rate=1.5,bob=.07},Bulwark={lean=-10,stride=23,arm=12,rate=1.35,bob=.075},Wraithstep={lean=-19,stride=35,arm=13,rate=2.3,bob=.035}})[hero]
 if not profile then return end
 local speed=Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude
 local run=math.clamp(speed/10,0,1)
 local state=Motion.states[model]; if not state then return end
 local dt=math.clamp(now-(state.groundLast or now),0,.1); state.groundLast=now
 state.phase=(state.phase or 0)+dt*profile.rate*math.pi*2*math.clamp(speed/16,.3,1.6)
 local wave=math.sin(state.phase)*run; local breath=math.sin(now*2)*.8
 local target=pose({profile.lean,0,0},{0,wave*(hero=="Wraithstep" and 9 or 4),0},{profile.arm*wave,0,8},{-profile.arm*wave,0,-8},{20,0,0},{20,0,0},{profile.stride*wave,0,4},{-profile.stride*wave,0,-4})
 if hero=="Tempest" then target.RightShoulder={-22+wave*8,0,25+breath}; target.LeftShoulder={-22-wave*8,0,-25-breath}; target.RightElbow={65,0,0}; target.LeftElbow={65,0,0}
 elseif hero=="Bulwark" then target.LeftShoulder={-55,0,-18}; target.LeftElbow={95,0,0}; target.RightElbow={65,0,0}
 elseif hero=="Wraithstep" then target.RightShoulder={20+wave*12,0,15}; target.LeftShoulder={-15-wave*12,0,-18}; target.RightElbow={85,0,0}; target.LeftElbow={75,0,0}; target.Waist={8,-12,0}
 end
 target.RightKnee={-math.max(0,-wave)*30,0,0}; target.LeftKnee={-math.max(0,wave)*30,0,0}
 if model:GetAttribute("RigSkin")==true then target.RightHip=nil; target.LeftHip=nil; target.RightKnee=nil; target.LeftKnee=nil end -- V55c: a skinned rig keeps the clip's legs (this stride capped the knees at 30 deg)
 for name,v in target do if motors[name] then motors[name].Transform=angle(v) end end
 if motors.Root then motors.Root.Transform=CFrame.new(0,math.abs(wave)*profile.bob,0)*angle(target.Root) end
end
return Motion