-- Vyrath boss controller (server). Owns a skinned-mesh dragon model (no Humanoid): plays its clips through the
-- AnimationController, moves and turns it with PivotTo at limited rates, runs the action state machine, tests the
-- breath cone and tail sweep against targets, and takes damage with weak points, stagger and death.
-- Targets are supplied by the host (HeroWars Main or the test harness) as {model=, root=, hum=} records, so the
-- same module works in the test bed and in the game.
local RunService=game:GetService("RunService")
local KSP=game:GetService("KeyframeSequenceProvider")
local D=require(script.Parent.BossData)
local Boss={}
Boss.__index=Boss

local function bonesOf(mesh)
 local t={}
 for _,b in mesh:GetDescendants() do if b:IsA("Bone") then t[b.Name]=b end end
 return t
end
local function flat(v) return Vector3.new(v.X,0,v.Z) end
local function yawOf(cf) local l=cf.LookVector; return math.atan2(-l.X,-l.Z) end -- radians; 0 = facing -Z
local function wrap(a) return (a+math.pi)%(2*math.pi)-math.pi end

-- model: the imported dragon (MeshPart + AnimationController). clips: name -> KeyframeSequence or AnimationId string.
-- opts.targets(): list of {model=,root=,hum=}; opts.onEvent(name,...) for effects; opts.log(text).
function Boss.new(model,clips,opts)
 local self=setmetatable({},Boss)
 self.model=model; self.mesh=model:FindFirstChildOfClass("MeshPart"); self.bones=bonesOf(self.mesh)
 self.opts=opts or {}
 self.targets=self.opts.targets or function() return {} end
 self.log=self.opts.log or print
 local ac=model:FindFirstChildOfClass("AnimationController") or Instance.new("AnimationController",model)
 self.animator=ac:FindFirstChildOfClass("Animator") or Instance.new("Animator",ac)
 self.tracks={}
 for name,src in clips do
  local anim=Instance.new("Animation"); anim.Name=name
  anim.AnimationId=typeof(src)=="string" and src or KSP:RegisterKeyframeSequence(src)
  local tr=self.animator:LoadAnimation(anim); tr.Priority=Enum.AnimationPriority.Action
  tr.Looped=D.Frames[name] and D.Frames[name][2] or false
  self.tracks[name]=tr
 end
 self.hp=D.HP; self.alive=true
 self.weak={}; for k in D.WeakPoints do self.weak[k]=0 end
 self.cool={}; self.flinchAt=-100
 self.state="Idle"; self.stateAt=0; self.track=nil; self.frame=0
 -- Keep the import's pivot rotation (the FBX comes in with a 90-degree base rotation): the body yaws relative to it,
 -- and yaw 0 means facing world -Z like a Roblox character. The facing comes from the skeleton, root to head.
 local pv=model:GetPivot(); self.R0=pv.Rotation; self.pos=pv.Position
 local root,head=self.bones["tripo::Root"],self.bones["Head"]
 local facing=flat(head.WorldPosition-root.WorldPosition); if facing.Magnitude<0.1 then facing=Vector3.new(0,0,-1) end
 self.yaw0=math.atan2(-facing.Unit.X,-facing.Unit.Z); self.yaw=self.yaw0
 self.breathHit={}; self.sweepHit={}
 self.exposed=false
 model:SetAttribute("HP",self.hp); model:SetAttribute("MaxHP",D.HP); model:SetAttribute("State","Idle")
 self.cone=self:makeCone()
 self.t=0
 self.conn=RunService.Heartbeat:Connect(function(dt) if self.opts.paused and self.opts.paused() then return end; self:step(math.min(dt,0.1)) end)
 return self
end

function Boss:destroy() if self.conn then self.conn:Disconnect() end; if self.cone then self.cone:Destroy() end end

-- A translucent cone drawn from the mouth during the breath warning and the breath itself (the "visible warning").
function Boss:makeCone()
 local p=Instance.new("Part"); p.Name="BreathCone"; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
 p.Shape=Enum.PartType.Block; p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(120,190,255); p.Transparency=1; p.CastShadow=false
 p.Parent=workspace
 return p
end

function Boss:socket(name) local b=self.bones[name]; return b and b.TransformedWorldCFrame end
-- Where the breath goes: from the skull base through the mouth socket (the socket bone's own axes are not reliable).
function Boss:aim()
 local s,h=self:socket("Socket_Breath"),self:socket("Head")
 if s and h then local d=s.Position-h.Position; if d.Magnitude>0.1 then return s.Position,d.Unit end end
 return s and s.Position or self.pos+Vector3.new(0,12,0),self:forward()
end
function Boss:play(name,speed)
 if self.track then self.track:Stop(0.1) end
 local tr=self.tracks[name]; self.track=tr; self.trackName=name
 tr:Play(0.1,1,speed or 1)
 self.state=name; self.stateAt=self.t; self.frame=0
 self.model:SetAttribute("State",name)
 self.breathHit={}; self.sweepHit={}
 if self.opts.onEvent then self.opts.onEvent("State",name) end
end
function Boss:frames() return self.track and self.track.TimePosition*D.FPS or 0 end
function Boss:done() return self.track and not self.track.IsPlaying end

-- Movement: slide the model along its facing and yaw it, both rate-limited.
function Boss:moveTo(pos,yaw)
 self.pos=pos; self.yaw=yaw
 self.model:PivotTo(CFrame.new(pos)*CFrame.Angles(0,yaw-self.yaw0,0)*self.R0)
end
function Boss:turnToward(target,dt,rate)
 local want=yawOf(CFrame.lookAt(self.pos,Vector3.new(target.X,self.pos.Y,target.Z)))
 local d=wrap(want-self.yaw)
 local step=math.rad(rate)*dt
 if math.abs(d)<=step then return want,0 end
 return self.yaw+math.sign(d)*step,d
end
function Boss:forward() return Vector3.new(-math.sin(self.yaw),0,-math.cos(self.yaw)) end
function Boss:clearDir(dir,dist)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={self.model,self.cone}
 local from=self.pos+Vector3.new(0,6,0)
 return workspace:Raycast(from,dir*dist,params)==nil
end
function Boss:clearAhead(dist) return self:clearDir(self:forward(),dist) end
-- Steering round a block: the yaw the body should take this frame, or nil to stop. Feels left and right of the
-- line ahead and bends toward the first clear side (a greybox stand-in for real pathfinding).
function Boss:steer(wantYaw,dist)
 local fwd=Vector3.new(-math.sin(wantYaw),0,-math.cos(wantYaw))
 if self:clearDir(fwd,dist) then return wantYaw end
 for _,off in {35,-35,70,-70,110,-110} do
  local y=wantYaw+math.rad(off)
  if self:clearDir(Vector3.new(-math.sin(y),0,-math.cos(y)),dist) then return y end
 end
 return nil
end

function Boss:pickTarget()
 local best,bestD
 for _,t in self.targets() do
  if t.root and t.root.Parent and t.hum and t.hum.Health>0 then
   local d=(t.root.Position-self.pos).Magnitude
   if d<=D.Aggro and (not bestD or d<bestD) then best,bestD=t,d end
  end
 end
 return best,bestD
end
function Boss:angleTo(pos)
 local want=yawOf(CFrame.lookAt(self.pos,Vector3.new(pos.X,self.pos.Y,pos.Z)))
 return math.deg(wrap(want-self.yaw))
end
function Boss:ready(name) return self.t>=(self.cool[name] or 0) end

-- Breath: the lightning arcs down from the mouth, so the test is a wedge on the ground: inside HalfAngle of the head's
-- facing (flat), within Range of the mouth (flat), not above the mouth, and with a clear line from the mouth.
function Boss:breathTick()
 local mouth,dir=self:aim()
 local fdir=flat(dir); if fdir.Magnitude<0.05 then fdir=self:forward() end; fdir=fdir.Unit
 local cosHalf=math.cos(math.rad(D.Breath.HalfAngle))
 for _,t in self.targets() do
  if t.root and t.root.Parent and t.hum and t.hum.Health>0 then
   -- the wedge starts at the body (the mouth hangs 16 studs ahead of it); the sight line still runs from the mouth
   local fd=flat(t.root.Position-self.pos); local dist=fd.Magnitude
   local d=t.root.Position-mouth
   if dist<=D.Breath.Range and dist>4 and fd.Unit:Dot(fdir)>=cosHalf and d.Y<=2 then
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={self.model,self.cone}
    local hit=workspace:Raycast(mouth,d,params)
    if not hit or hit.Instance:IsDescendantOf(t.model) then
     local last=self.breathHit[t.model] or -1
     if self.t-last>=D.Breath.TickSeconds then
      self.breathHit[t.model]=self.t
      if self.opts.damage then self.opts.damage(t,D.Breath.DamagePerTick,"Breath") else t.hum:TakeDamage(D.Breath.DamagePerTick) end
      if self.opts.onEvent then self.opts.onEvent("BreathHit",t.model,D.Breath.DamagePerTick) end
     end
    end
   end
  end
 end
end
-- Tail sweep: capsules along the tail bones during the contact frames; one hit per target per sweep, with a shove.
function Boss:sweepTick()
 local segs={}
 for i=4,12 do local b=self.bones[("Tail_%02d"):format(i)]; if b then table.insert(segs,b.TransformedWorldCFrame.Position) end end
 if #segs<2 then return end
 for _,t in self.targets() do
  if t.root and t.root.Parent and t.hum and t.hum.Health>0 and not self.sweepHit[t.model] then
   local p=t.root.Position
   for i=1,#segs-1 do
    local a,b=segs[i],segs[i+1]; local ab=b-a
    local u=math.clamp((p-a):Dot(ab)/math.max(ab:Dot(ab),1e-6),0,1)
    local dist=(p-(a+ab*u)).Magnitude
    if dist<=D.TailSweep.Radius+2.5 then -- target's own body radius
     self.sweepHit[t.model]=true
     local shove=flat(p-self.pos); if shove.Magnitude<0.1 then shove=self:forward() end
     if self.opts.damage then self.opts.damage(t,D.TailSweep.Damage,"Sweep",shove.Unit) else t.hum:TakeDamage(D.TailSweep.Damage); t.root.AssemblyLinearVelocity=shove.Unit*D.TailSweep.Push+Vector3.new(0,25,0) end
     if self.opts.onEvent then self.opts.onEvent("SweepHit",t.model,D.TailSweep.Damage) end
     break
    end
   end
  end
 end
end

function Boss:showCone(on,warning)
 local p=self.cone
 if not on then p.Transparency=1; return end
 local origin,dir=self:aim()
 local fdir=flat(dir); if fdir.Magnitude<0.05 then fdir=self:forward() end; fdir=fdir.Unit
 -- the telegraph lies on the ground where the breath lands: a flat wedge-ish slab from under the mouth out to Range
 local len=D.Breath.Range; local r=math.tan(math.rad(D.Breath.HalfAngle))*len
 local base=Vector3.new(self.pos.X,0.15,self.pos.Z)
 p.CFrame=CFrame.lookAt(base,base+fdir)*CFrame.new(0,0,-len/2)*CFrame.Angles(0,math.rad(90),0)
 p.Size=Vector3.new(len,0.3,r*2)
 p.Transparency=warning and 0.55 or 0.3
 p.Color=warning and Color3.fromRGB(255,220,120) or Color3.fromRGB(120,190,255)
end

-- Hurt volumes for the host's attack tests: capsules {a=,b=,r=} along the live bones (world space, studs).
local CHAINS={
 {r=0.07,bones={"Pelvis","tripo::Spine_0","tripo::Spine_1","Neck_01"}},
 {r=0.045,bones={"Neck_01","Neck_03","Neck_05","Neck_07","Head","Socket_Breath"}},
 {r=0.035,bones={"Tail_01","Tail_03","Tail_05","Tail_07","Tail_09","Tail_12"}},
 {r=0.03,bones={"Wing_L_Shoulder","Wing_L_Arm","Wing_L_Forearm","Wing_L_D1_1"}},
 {r=0.03,bones={"Wing_R_Shoulder","Wing_R_Arm","Wing_R_Forearm","Wing_R_D1_1"}},
 {r=0.035,bones={"HindLeg_L_Hip","HindLeg_L_Knee","HindLeg_L_Ankle"}},
 {r=0.035,bones={"HindLeg_R_Hip","HindLeg_R_Knee","HindLeg_R_Ankle"}},
 {r=0.03,bones={"bone_26","tripo::0_Left_Limb_0","tripo::0_Left_Limb_1","tripo::0_Left_Limb_3"}},
 {r=0.03,bones={"bone_42","tripo::0_Right_Limb_0","tripo::0_Right_Limb_1","tripo::0_Right_Limb_3"}},
}
function Boss:volumes()
 local out={}
 for _,c in CHAINS do
  local prev
  for _,n in c.bones do
   local b=self.bones[n]
   if b then local p=b.TransformedWorldCFrame.Position; if prev then table.insert(out,{a=prev,b=p,r=c.r*D.Scale}) end; prev=p end
  end
 end
 return out
end

-- Damage in. pos: where the hit landed (world). Returns the damage applied.
function Boss:hit(damage,pos,source)
 if not self.alive then return 0 end
 local zone,mult="Body",1
 if pos then
  for name,w in D.WeakPoints do
   local s=self:socket(w.bone)
   if s and (s.Position-pos).Magnitude<=w.Radius then zone,mult=name,w.Mult; break end
  end
 end
 if zone=="Throat" and self.exposed then mult*=D.ExposedMult end
 local dmg=math.floor(damage*mult+0.5)
 self.hp=math.max(0,self.hp-dmg); self.model:SetAttribute("HP",self.hp)
 if self.opts.onEvent then self.opts.onEvent("Hurt",zone,dmg,self.hp,source) end
 if zone~="Body" then
  self.weak[zone]+=dmg
  if self.weak[zone]>=D.WeakPoints[zone].Break and self.state~="Stagger_WeakpointBreak" and self.state~="Death" then
   self.weak[zone]=0
   if self.opts.onEvent then self.opts.onEvent("WeakpointBreak",zone) end
   self:play("Stagger_WeakpointBreak")
  end
 end
 if self.hp<=0 then
  self.alive=false; self:showCone(false); self:play("Death")
  if self.opts.onEvent then self.opts.onEvent("Death") end
 elseif dmg>=D.FlinchDamage and (self.state=="Idle" or self.state=="Walk" or self.state=="Charge_Run") and self.t-self.flinchAt>=D.FlinchCooldown then
  self.flinchAt=self.t; self:play("Hit_Flinch")
 end
 return dmg
end

-- The brain. Runs every Heartbeat.
function Boss:step(dt)
 self.t+=dt
 local st=self.state
 local f=self:frames()
 self.exposed=(st=="Sig_ThunderBreath" and f>=D.Breath.ExposedStart and f<=D.Breath.ExposedEnd) or (st=="Stagger_WeakpointBreak" and f>=D.Stagger.ExposedStart and f<=D.Stagger.ExposedEnd)
 self.model:SetAttribute("Exposed",self.exposed)
 if st=="Death" then return end
 if self.track==nil then self:play("Idle"); return end
 local target,dist=self:pickTarget()
 self.model:SetAttribute("Target",target and target.model.Name or "none"); self.model:SetAttribute("Targets",#self.targets())
 -- committed and reaction clips run to their end
 if st=="Sig_ThunderBreath" then
  if f>=D.Breath.WarningStart and f<D.Breath.ActiveStart then self:showCone(true,true)
  elseif f>=D.Breath.ActiveStart and f<=D.Breath.ActiveEnd then self:showCone(true,false); self:breathTick()
  else self:showCone(false) end
  if f<D.Breath.Cancelable and target then -- still charging: keep the aim on the target
   local yaw=self:turnToward(target.root.Position,dt,D.TurnRate.Idle); self:moveTo(self.pos,yaw)
  end
  if self:done() then self.cool.Breath=self.t+D.Breath.Cooldown; self:play("Idle") end
  return
 elseif st=="Sig_TailSweep" then
  if f>=D.TailSweep.ContactStart and f<=D.TailSweep.ContactEnd then self:sweepTick() end
  if self:done() then self.cool.Sweep=self.t+D.TailSweep.Cooldown; self:play("Idle") end
  return
 elseif st=="Roar" or st=="Hit_Flinch" or st=="Stagger_WeakpointBreak" or st=="Sig_Takeoff" or st=="Sig_Landing" then
  if self:done() then if st=="Roar" then self.cool.Roar=self.t+D.Roar.Cooldown end; self:play("Idle") end
  return
 elseif st=="Turn_Left90" then
  -- the clip turns the pose 90 degrees left over its length; the pivot follows so the pose and the body agree at the end
  local want=self.turnFrom+math.rad(D.Turn.Degrees)*math.clamp(f/D.Turn.Frames,0,1)
  self:moveTo(self.pos,want)
  if self:done() then self:moveTo(self.pos,self.turnFrom+math.rad(D.Turn.Degrees)); self:play("Idle") end
  return
 end
 if not target then
  if st~="Idle" then self:play("Idle") end
  return
 end
 local ang=self:angleTo(target.root.Position)
 -- decide
 if st=="Idle" and ang>60 and ang<120 and dist>D.Move.StopDist then
  self.turnFrom=self.yaw; self:play("Turn_Left90"); return
 end
 if dist<=D.Breath.Range*0.9 and math.abs(ang)<=25 and self:ready("Breath") then self:play("Sig_ThunderBreath"); return end
 if dist<=D.TailSweep.Reach and math.abs(ang)>=70 and self:ready("Sweep") then self:play("Sig_TailSweep"); return end
 if dist<=D.Breath.Range and self:ready("Roar") and math.random()<0.15*dt then self:play("Roar"); return end
 -- locomotion
 local wantState=(dist>D.Move.ChargeMinDist) and "Charge_Run" or (dist>D.Move.WalkMinDist) and "Walk" or "Idle"
 if wantState~=st then self:play(wantState) end
 local rate=D.TurnRate[wantState] or D.TurnRate.Idle
 local goal=yawOf(CFrame.lookAt(self.pos,Vector3.new(target.root.Position.X,self.pos.Y,target.root.Position.Z)))
 local steered=wantState~="Idle" and self:steer(goal,18) or goal
 local yaw
 if steered then
  local d=wrap(steered-self.yaw); local step=math.rad(rate)*dt
  yaw=math.abs(d)<=step and steered or self.yaw+math.sign(d)*step
 else yaw=self.yaw end
 local pos=self.pos
 if wantState~="Idle" and steered and self:clearAhead(12) then
  local fwd=Vector3.new(-math.sin(yaw),0,-math.cos(yaw))
  pos=pos+fwd*D.Speed[wantState]*dt
 end
 self:moveTo(pos,yaw)
end
return Boss
