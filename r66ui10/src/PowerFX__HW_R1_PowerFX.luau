-- Reusable, asset-ID-free power library. All instances are local, bounded and short-lived.
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local Surface=require(script.Parent.SurfaceFX)
local Rules=require(script.Parent.Rules)
local FX={active=0,limit=UIS.TouchEnabled and 90 or 180}
local folder=Instance.new("Folder"); folder.Name="HeroPowerFX"; folder.Parent=workspace
local colors={Solarion=Color3.fromRGB(255,170,45),Wraithstep=Color3.fromRGB(145,83,217),Tempest=Color3.fromRGB(147,225,255),Bulwark=Color3.fromRGB(163,174,185)}
function FX.visible(model)
 local root=model and model:FindFirstChild("HumanoidRootPart")
 local camera=workspace.CurrentCamera
 if not root or not camera or (root.Position-camera.CFrame.Position).Magnitude>150 then return false end
 if model~=Players.LocalPlayer.Character and model:GetAttribute("Invisible") and (model:GetAttribute("RevealEnd") or 0)<=workspace:GetServerTimeNow() then return false end
 return true
end
local function part(name,cf,size,color,life,material,shape)
 if FX.active>=FX.limit then return nil end
 local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
 p.CastShadow=false; p.CFrame=cf; p.Size=size; p.Color=color; p.Material=material or Enum.Material.Neon
 p.Shape=shape or Enum.PartType.Block; p.Parent=folder; FX.active+=1
 p.Destroying:Once(function() FX.active-=1 end)
 Tween:Create(p,TweenInfo.new(life),{Transparency=1}):Play(); Debris:AddItem(p,life+0.05)
 return p
end
local function line(name,a,b,width,color,life)
 local delta=b-a; if delta.Magnitude<0.01 then return end
 return part(name,CFrame.lookAt((a+b)/2,b),Vector3.new(width,width,delta.Magnitude),color,life)
end
local function ring(name,at,radius,color,life,tilt)
 local base=CFrame.new(at)*(tilt or CFrame.new())
 local count=UIS.TouchEnabled and 10 or 16
 for i=1,count do
  local a=i/count*math.pi*2; local b=(i+1)/count*math.pi*2
  line(name,base:PointToWorldSpace(Vector3.new(math.cos(a)*radius,0,math.sin(a)*radius)),base:PointToWorldSpace(Vector3.new(math.cos(b)*radius,0,math.sin(b)*radius)),0.065,color,life)
 end
end
local function motes(name,at,color,count,smoke)
 local p=part(name,CFrame.new(at),Vector3.one*0.1,color,0.85)
 if not p then return end; p.Transparency=1
 local e=Instance.new("ParticleEmitter"); e.Texture="rbxasset://textures/particles/"..(smoke and "smoke_main.dds" or "sparkles_main.dds")
 e.Rate=0; e.Lifetime=NumberRange.new(0.25,0.7); e.Speed=NumberRange.new(2,smoke and 7 or 16)
 e.SpreadAngle=Vector2.new(180,180); e.Color=ColorSequence.new(color)
 e.LightEmission=smoke and 0 or 0.8; e.Drag=4
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,smoke and 1 or 0.17),NumberSequenceKeypoint.new(1,smoke and 2.5 or 0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,1)})
 e.Parent=p; e:Emit(UIS.TouchEnabled and math.ceil(count/2) or count)
end
local function bolt(a,b,color,life)
 local previous=a
 for i=1,7 do
  local nextPoint=a:Lerp(b,i/7)+(i==7 and Vector3.zero or Vector3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)*1.6)
  line("StormBranch",previous,nextPoint,0.09,color,life)
  if i==3 or i==5 then line("StormFork",nextPoint,nextPoint+Vector3.new(1.2,1.3,0.5),0.035,color,life) end
  previous=nextPoint
 end
end
local function shards(at,color,count,metal)
 for i=1,count do
  local ang=i/count*math.pi*2
  local p=part(metal and "AlloyDebris" or "StormglassShard",CFrame.new(at)*CFrame.Angles(i,ang,0),Vector3.new(0.12,0.5,0.22),color,0.55,metal and Enum.Material.Metal or Enum.Material.Glass)
  if p then Tween:Create(p,TweenInfo.new(0.5),{CFrame=p.CFrame+Vector3.new(math.cos(ang)*3,math.random()+0.3,math.sin(ang)*3)}):Play() end
 end
end
local function shadowCuts(at,aim,color,big)
 local cf=CFrame.lookAt(at,at+aim)
 for i=-1,1 do
  local a=cf:PointToWorldSpace(Vector3.new(-1.5,i*0.4,-0.3))
  local b=cf:PointToWorldSpace(Vector3.new(1.5,i*0.4+1,-(big and 3 or 1)))
  line("ShadowRake",a,b,0.08,color,0.18)
 end
 motes("ShadowWisps",at,Color3.fromRGB(40,24,61),big and 14 or 5,true)
end
-- R38 (Peter: "look at Tempest's animations, add more lightning and thunder"). A real storm kit:
-- thick forked bolts with a glow shell, a flash of light, a thunder crack, a sky strike from a cloud,
-- and static that crawls over her.
local THUNDER={"rbxassetid://9120018050","rbxassetid://9126082854"}
local ZAP={"rbxassetid://9114277757","rbxassetid://9116275998","rbxassetid://9113147849"}
local function sound(list,at,volume,pitch)
 local holder=part("StormSound",CFrame.new(at),Vector3.one*0.05,Color3.new(1,1,1),3)
 if not holder then return end
 holder.Transparency=1
 local s=Instance.new("Sound"); s.SoundId=list[math.random(1,#list)]; s.Volume=volume or 0.6
 s.PlaybackSpeed=(pitch or 1)*(0.92+math.random()*0.16); s.RollOffMaxDistance=220; s.Parent=holder; s:Play()
end
local function flashLight(at,color,range,life)
 local holder=part("StormFlash",CFrame.new(at),Vector3.one*0.05,color,life)
 if not holder then return end
 holder.Transparency=1
 local l=Instance.new("PointLight"); l.Color=color; l.Range=range; l.Brightness=8; l.Shadows=false; l.Parent=holder
 Tween:Create(l,TweenInfo.new(life),{Brightness=0}):Play()
end
-- A thick jagged bolt: white-hot core, coloured glow shell, side forks. Flickers twice.
local function storm(a,b,color,life,width)
 width=width or 0.22
 local function draw(l)
  local segs=math.clamp(math.floor((b-a).Magnitude/2.5),5,16)
  local prev=a; local jit=math.min(2.4,(b-a).Magnitude*0.08+0.5)
  for i=1,segs do
   local p=a:Lerp(b,i/segs)+(i==segs and Vector3.zero or Vector3.new(math.random()-0.5,math.random()-0.5,math.random()-0.5)*jit)
   line("StormCore",prev,p,width*0.45,Color3.fromRGB(245,252,255),l)
   line("StormGlow",prev,p,width,color,l*1.3)
   if math.random()<0.35 then
    local f=p+Vector3.new(math.random()-0.5,math.random()-0.6,math.random()-0.5)*jit*2.2
    line("StormFork",p,f,width*0.3,color,l)
   end
   prev=p
  end
 end
 draw(life)
 task.delay(life*0.45,function() draw(life*0.6) end)
end
FX.storm=storm
-- R40 (Peter: "Solarion, increase his animation as well"): a sun-fire kit to match Tempest's storm.
local FIRE={"rbxassetid://9117987817","rbxassetid://9117987278"}
local WHOOSH={"rbxassetid://9120728815","rbxassetid://9120729339"}
local SUNCORE=Color3.fromRGB(255,246,210)
local function flames(at,color,count,size,speed)
 local p=part("SunFlames",CFrame.new(at),Vector3.one*0.1,color,1)
 if not p then return end; p.Transparency=1
 local e=Instance.new("ParticleEmitter"); e.Texture="rbxasset://textures/particles/fire_main.dds"
 e.Rate=0; e.Lifetime=NumberRange.new(0.25,0.55); e.Speed=NumberRange.new(2,speed or 10); e.SpreadAngle=Vector2.new(180,180)
 e.Color=ColorSequence.new(Color3.fromRGB(255,230,150),color); e.LightEmission=1; e.Drag=3
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size or 1),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)})
 e.Parent=p; e:Emit(UIS.TouchEnabled and math.ceil(count/2) or count)
end
-- A short burst of sunlight: white core ball, orange shell, rays, flames and a flash.
local function sunburst(at,color,radius,life)
 local core=part("SunCore",CFrame.new(at),Vector3.one*radius*0.5,SUNCORE,life,Enum.Material.Neon,Enum.PartType.Ball)
 if core then Tween:Create(core,TweenInfo.new(life),{Size=Vector3.one*radius*1.4}):Play() end
 local shell=part("SunShell",CFrame.new(at),Vector3.one*radius,color,life*1.2,Enum.Material.Neon,Enum.PartType.Ball)
 if shell then shell.Transparency=0.4; Tween:Create(shell,TweenInfo.new(life*1.2),{Size=Vector3.one*radius*2.4}):Play() end
 for i=1,8 do
  local a=i/8*math.pi*2+math.random()*0.3
  local dir=Vector3.new(math.cos(a),(math.random()-0.3)*0.8,math.sin(a)).Unit
  line("SunRay",at+dir*radius*0.4,at+dir*radius*(1.6+math.random()),0.12,color,life)
 end
 flames(at,color,14,radius*0.6)
 flashLight(at,color,radius*8,life*1.4)
end
FX.sunburst=sunburst
function FX.impact(target,attacker,name,result)
 if not FX.visible(target) then return end
 local root=target.HumanoidRootPart; local hero=attacker and attacker:GetAttribute("Hero") or "Bulwark"
 local col=colors[hero] or colors.Bulwark; local at=root.Position+Vector3.new(0,0.7,0)
 if result=="Dodge" then return end
 if result=="Parry" or result=="Block" then ring("Deflect",at,1.5,Color3.fromRGB(110,220,230),0.2,CFrame.Angles(math.pi/2,0,0)); return end
 if hero=="Solarion" then
  motes("SolarEmbers",at,col,18); ring("HeatLens",at,1.1,col,0.18,CFrame.Angles(math.pi/2,0,0))
  -- R40: the hit bursts into sunfire.
  sunburst(at,col,1.4,0.22); sound(FIRE,at,0.4,1.2)
 elseif hero=="Wraithstep" then shadowCuts(at,root.CFrame.LookVector,col,name=="Super")
 elseif hero=="Tempest" then
  -- R38: arcs leap over the victim, a crackle and a blue flash.
  for i=1,3 do
   local a=math.random()*math.pi*2
   storm(at+Vector3.new(math.cos(a)*1.6,-1.2,math.sin(a)*1.6),at+Vector3.new(-math.cos(a)*1.2,1.4,-math.sin(a)*1.2),col,0.14,0.1)
  end
  shards(at,col,5,false); flashLight(at,col,14,0.2); sound(ZAP,at,0.45,1.1)
 else
  shards(at,col,7,true); motes("ImpactDust",at,Color3.fromRGB(103,100,95),10,true)
  ring("CompressionRing",at,1.8,col,0.2,CFrame.Angles(math.pi/2,0,0))
 end
end
function FX.attack(model,name,aim,move,delaySeconds,still)
 if not FX.visible(model) then return end
 local hero=model:GetAttribute("Hero"); local col=colors[hero]; if not col then return end
 if hero=="Wraithstep" and name=="Grapple" then return end -- R17: the client's bat-and-chain grapple owns this
 local root=model.HumanoidRootPart
 local special=move.Cast or name=="Super" or name=="Interrupt" or (name~="Light1" and name~="Light2" and name~="Light3" and name~="Heavy")
 if special then
  if hero=="Solarion" then
   ring("SolarChargeLens",root.Position,0.6,col,delaySeconds,CFrame.Angles(math.pi/2,0,0))
   -- R40: a long charge (Solar Hammer) grows a miniature sun between his hands: it swells, throws
   -- rays and flames, lights the ground and hums; a quick special just flares his fists.
   if delaySeconds>=0.4 then
    sound(FIRE,root.Position,0.45,0.7)
    task.spawn(function()
     local t0=os.clock()
     while os.clock()-t0<delaySeconds and still() do
      local r=model:FindFirstChild("RightHand"); local l=model:FindFirstChild("LeftHand")
      if r and l then
       local mid=(r.Position+l.Position)/2+root.CFrame.LookVector*0.8
       local k=math.clamp((os.clock()-t0)/delaySeconds,0,1)
       local sun=part("MiniSun",CFrame.new(mid),Vector3.one*(0.5+k*1.6),SUNCORE,0.1,Enum.Material.Neon,Enum.PartType.Ball)
       local halo=part("MiniSunHalo",CFrame.new(mid),Vector3.one*(1+k*2.6),col,0.12,Enum.Material.Neon,Enum.PartType.Ball)
       if halo then halo.Transparency=0.5 end
       if math.random()<0.6 then
        local a=math.random()*math.pi*2; local d=Vector3.new(math.cos(a),math.random()-0.5,math.sin(a)).Unit
        line("MiniSunRay",mid+d*0.6,mid+d*(1.5+k*2.5),0.07,col,0.12)
       end
       if math.random()<0.3 then flames(mid,col,4,0.6,4) end
      end
      task.wait(0.07)
     end
    end)
   else
    for _,n in {"RightHand","LeftHand"} do local h=model:FindFirstChild(n); if h then flames(h.Position,col,6,0.7,5) end end
   end
  elseif hero=="Wraithstep" then motes("ShadowGather",root.Position,Color3.fromRGB(40,24,61),6,true)
  elseif hero=="Tempest" then
   bolt(root.Position+Vector3.new(-1,0,0),root.Position+Vector3.new(1,0.3,0),col,math.min(delaySeconds,0.25))
   -- R38: a long cast gathers a storm: a dark cloud forms over her head and crackles, static crawls
   -- down her arms, and it rumbles.
   if delaySeconds>=0.5 then
    local top=root.Position+Vector3.new(0,7,0)
    for i=1,5 do
     local c=part("StormCloud",CFrame.new(top+Vector3.new(math.random(-3,3),math.random()*1.2,math.random(-3,3))),Vector3.new(4,2.2,4)*(0.8+math.random()*0.5),Color3.fromRGB(70,76,92),delaySeconds+0.4,Enum.Material.SmoothPlastic,Enum.PartType.Ball)
     if c then c.Transparency=0.35 end
    end
    sound(THUNDER,top,0.35,0.6)
    task.spawn(function()
     local t0=os.clock()
     while os.clock()-t0<delaySeconds and still() do
      local hand=model:FindFirstChild(math.random()<0.5 and "RightHand" or "LeftHand")
      if hand then storm(top+Vector3.new(math.random(-2,2),-0.5,math.random(-2,2)),hand.Position,col,0.1,0.08) end
      task.wait(0.12+math.random()*0.1)
     end
    end)
   end
  else motes("TitanPressure",root.Position-Vector3.new(0,2,0),Color3.fromRGB(95,94,91),5,true) end
 end
 task.delay(math.max(0.01,delaySeconds),function()
  if not still() or not FX.visible(model) then return end
  local start=root.Position
  -- Teleports and landing attacks have authoritative arrival/landing events.
  if hero=="Solarion" and name=="Pounce" then
   -- R40: he leaps as a comet, trailing sunfire.
   sound(WHOOSH,start,0.5,0.9)
   task.spawn(function()
    local t0=os.clock(); local dur=math.max(0.3,(move.Active or 20)/60)
    while os.clock()-t0<dur and root.Parent do
     flames(root.Position,colors.Solarion,5,1.1,3)
     line("CometTail",root.Position,root.Position-root.AssemblyLinearVelocity.Unit*2.5,0.5,colors.Solarion,0.2)
     task.wait(0.05)
    end
   end)
  end
  if move.ShadowCircle or move.Teleport or name=="Pounce" or name=="TitanDrop" then return end
  local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={model,folder}
  local length=move.Aoe and 0 or (move.Range or 5)
  local hit=workspace:Raycast(start,aim*length,params); local finish=hit and hit.Position or start+aim*length
  if hero=="Solarion" and move.Pulses then return end -- R22: each photon pulse is drawn by the client's "Pulse" event
  if hero=="Solarion" and move.BeamFX then
   local hand=model:FindFirstChild("RightHand")
   local origin=hand and hand.Position or start
   local obstruction=workspace:Raycast(origin,finish-origin,params)
   if obstruction then finish=obstruction.Position end
   local holder=part("SolarHammerBeamAsset",CFrame.new(origin),Vector3.one*.05,col,.4)
   if holder then
    holder.Transparency=1
    local from=Instance.new("Attachment"); from.Parent=holder
    local to=Instance.new("Attachment"); to.Position=finish-origin; to.Parent=holder
    local beam=Instance.new("Beam"); beam.Name="SolarHammerBeam"
    beam.Attachment0=from; beam.Attachment1=to; beam.FaceCamera=true
    beam.Width0=.85; beam.Width1=.55; beam.LightEmission=1; beam.LightInfluence=0
    beam.Color=ColorSequence.new(col); beam.Transparency=NumberSequence.new(.1); beam.Parent=holder
   end
   line("SolarHammerBeamCore",origin,finish,.2,Color3.fromRGB(255,248,218),.4)
   motes("SolarHammerImpact",finish,col,16)
   Surface.scorch(model,finish,3)
   return
  end
  if hero=="Wraithstep" and name=="Grapple" then
   local hand=model:FindFirstChild("LeftHand") or root
   local origin=hand.Position
   local holder=part("ShadowGrappleAsset",CFrame.new(origin),Vector3.one*.05,col,.65)
   if holder then
    holder.Transparency=1
    local from=Instance.new("Attachment"); from.Parent=holder
    local to=Instance.new("Attachment"); to.Position=finish-origin; to.Parent=holder
    for i=-1,1 do
     local beam=Instance.new("Beam"); beam.Name=i==0 and "ShadowGrappleCore" or "ShadowGrappleTendril"
     beam.Attachment0=from; beam.Attachment1=to; beam.FaceCamera=true; beam.Segments=12
     beam.Width0=i==0 and .15 or .4; beam.Width1=i==0 and .1 or .22
     beam.CurveSize0=i*2; beam.CurveSize1=-i*2; beam.LightEmission=1; beam.LightInfluence=0
     beam.Color=ColorSequence.new(i==0 and Color3.fromRGB(235,209,255) or col)
     beam.Transparency=NumberSequence.new(.08,.65); beam.Parent=holder
     Tween:Create(beam,TweenInfo.new(.6),{Width0=0,Width1=0}):Play()
    end
   end
   local hook=part("ShadowGrappleHook",CFrame.new(finish),Vector3.one*.7,col,.5,Enum.Material.Neon,Enum.PartType.Ball)
   ring("ShadowGrappleClaw",finish,1.2,col,.45,CFrame.lookAt(Vector3.zero,aim).Rotation*CFrame.Angles(math.pi/2,0,0))
   motes("GrappleShadowSmoke",finish,Color3.fromRGB(40,24,61),14,true)
   return
  end
  local big=name=="Super"
  local step=tonumber(string.match(name,"^Light(%d)$"))
  if step then
   local hand=model:FindFirstChild(step==2 and "LeftHand" or step==3 and "RightFoot" or "RightHand")
   local origin=hand and hand.Position or start
   local cf=CFrame.lookAt(origin,origin+aim)
   local side=step==2 and -1 or 1
   if hero=="Solarion" then
    line("SolarCombo"..step,origin,origin+aim*(step==3 and 3 or 1.7),.12,col,.18)
    motes("SolarKnuckleEmbers",origin,col,step*3)
    -- R40: flaming fists; the kick sweeps a ring of fire.
    line("SolarComboCore"..step,origin,origin+aim*(step==3 and 3 or 1.7),.05,SUNCORE,.14)
    flames(origin+aim,col,step==3 and 12 or 6,step==3 and 1.1 or 0.7,6)
    if step==3 then
     ring("SunKickArc",origin,2.4,col,.25,CFrame.lookAt(Vector3.zero,aim).Rotation)
     ring("SunKickArcCore",origin,1.6,SUNCORE,.18,CFrame.lookAt(Vector3.zero,aim).Rotation)
     sound(WHOOSH,origin,0.45,1.1); sound(FIRE,origin,0.3,1.4)
    end
   elseif hero=="Bulwark" then
    local p=part("ShieldCombo"..step,cf,Vector3.new(.25,step==3 and .5 or 1.2,.7),col,.18,Enum.Material.Metal)
    if p then Tween:Create(p,TweenInfo.new(.16),{CFrame=cf+aim*1.8}):Play() end
    motes("ShieldContactDust",origin,Color3.fromRGB(114,105,90),4,true)
   elseif hero=="Wraithstep" then
    line("ShadowCombo"..step,origin-cf.RightVector*side,origin+cf.RightVector*side+Vector3.yAxis*(step==3 and 2 or .4),.065,col,.16)
    motes("ShadowComboWisps",origin,Color3.fromRGB(40,24,61),4,true)
   else
    -- R38: every spark jab throws a small arc; the third is a forked bolt with a crack.
    if step==3 then storm(origin,origin+aim*4,col,.16,.16); sound(ZAP,origin,0.35,1.3)
    else ring("PalmWind"..step,origin,step*.5,col,.2,CFrame.Angles(math.pi/2,0,side*.5)); storm(origin,origin+aim*2.2,col,.1,.07) end
   end
   return
  end
  if hero=="Solarion" then
   if name~="SolarFlare" and (special or name=="Heavy") then Surface.scorch(model,move.Aoe and start or finish,move.Aoe or 3) end
   if name=="Beam" or name=="Interrupt" then
    line("SunLanceShell",start,finish,name=="Beam" and 0.3 or 0.12,col,0.18)
    line("SunLanceCore",start,finish,0.07,Color3.fromRGB(255,244,200),0.12)
    motes("CoronaMotes",finish,col,12)
   else
    ring(big and "SupernovaCorona" or "SolarCompression",start,move.Aoe or 1.4,col,big and 0.55 or 0.2)
    motes("HeatSparks",start,col,big and 32 or 8)
    if big then ring("SupernovaInner",start,6,Color3.fromRGB(255,225,140),0.35,CFrame.Angles(math.pi/2,0,0)) end
   end
  elseif hero=="Wraithstep" then
   shadowCuts(start+aim*2,aim,col,big)
   if name=="Grapple" or name=="Interrupt" then
    line("ShadowTether",start,finish,0.045,col,0.2)
    for i=1,3 do motes("TetherWisps",start:Lerp(finish,i/3),Color3.fromRGB(40,24,61),3,true) end
   end
   if big then
    for i=1,3 do shadowCuts(start+aim*i*2,aim,col,true) end
   end
  elseif hero=="Tempest" then
   if name=="Lightning" or name=="Interrupt" or big then
    -- R38: Lightning is a hand bolt plus a sky strike from the storm cloud onto the target: a pillar
    -- of light, a burn mark, a flash that lights the arena and a thunder crack.
    local hand=model:FindFirstChild("RightHand"); local origin=hand and hand.Position or start
    storm(origin,finish,col,0.22,0.24)
    storm(finish+Vector3.new(math.random(-3,3),45,math.random(-3,3)),finish,col,0.3,0.5)
    ring("StrikeRing",finish-Vector3.new(0,2.4,0),3.5,col,0.35)
    Surface.scorch(model,finish-Vector3.new(0,2.5,0),2.5)
    flashLight(finish,col,40,0.35); sound(THUNDER,finish,0.9,1)
   elseif name=="Heavy" then
    -- R38 Storm Fist: the punch throws a crackling arc down its whole reach and claps thunder.
    local hand=model:FindFirstChild("RightHand"); local origin=hand and hand.Position or start
    storm(origin,finish,col,0.18,0.3)
    storm(origin,finish+Vector3.new(0,1.5,0),col,0.14,0.12)
    ring("Thunderclap",origin+aim*1.5,1.6,Color3.fromRGB(235,248,255),0.22,CFrame.lookAt(Vector3.zero,aim).Rotation*CFrame.Angles(math.pi/2,0,0))
    flashLight(origin,col,20,0.2); sound(THUNDER,origin,0.6,1.4)
   elseif name=="Whirlwind" then
    -- Show the cast path; the target's Whirl attribute owns the sustained funnel.
    for i=1,3 do ring("WhirlwindPath"..i,start:Lerp(finish,i/3),move.Width/2,col,0.3,CFrame.lookAt(Vector3.zero,aim).Rotation*CFrame.Angles(math.pi/2,0,0)) end
    -- R38: lightning arcs through the funnel path and thunder rolls.
    for i=1,3 do local p=start:Lerp(finish,i/3); storm(p+Vector3.new(0,4,0),p-Vector3.new(0,1,0),col,0.2,0.14) end
    sound(THUNDER,finish,0.6,0.8)
   else
    for i=1,3 do ring("WindShear"..i,start:Lerp(finish,i/3),move.Width/2*i/3,col,0.3,CFrame.lookAt(Vector3.zero,aim).Rotation*CFrame.Angles(math.pi/2,0,0)) end
   end
   if special then shards(finish,col,big and 10 or 5,false) end
  else
   local ground=root.Position
   if big or name=="Slam" or name=="Heavy" then
    Surface.quake(model,move.Aoe and ground or start:Lerp(finish,.5),move.Aoe or move.Width/2)
   end
   shards(start+aim*2,col,big and 12 or 5,true)
   motes("TitanDust",ground,Color3.fromRGB(103,100,95),big and 24 or 7,true)
  end
 end)
end
function FX.defensive(model)
 if not FX.visible(model) then return end
 local hero=model:GetAttribute("Hero"); local at=model.HumanoidRootPart.Position; local col=colors[hero]
 if hero=="Wraithstep" then motes("VanishSmoke",at,Color3.fromRGB(40,24,61),15,true)
 elseif hero=="Bulwark" then ring("TitanParry",at+model.HumanoidRootPart.CFrame.LookVector,1.5,col,0.35,CFrame.Angles(math.pi/2,0,0))
 elseif hero=="Tempest" then ring("TailwindVortex",at,2,col,0.35); shards(at,col,6,false)
 elseif col then ring("SolarGuard",at,2,col,0.35,CFrame.Angles(math.pi/2,0,0)) end
end
local flightTimes=setmetatable({},{__mode="k"})
function FX.flight(model,state,changed,speed)
 if not FX.visible(model) or state=="Ground" then return end
 local now=os.clock(); if not changed and now-(flightTimes[model] or 0)<.22 then return end
 flightTimes[model]=now
 local root=model:FindFirstChild("HumanoidRootPart"); if not root then return end
 if model:GetAttribute("Hero")=="Solarion" then
  for _,name in {"LeftFoot","RightFoot"} do
   local foot=model:FindFirstChild(name)
   if foot then
    motes("SolarFlightExhaust",foot.Position,colors.Solarion,4)
    -- R40: rocket jets of sunfire from his feet, longer the faster he flies.
    local len=1.5+math.clamp((speed or 0)/10,0,3)
    local down=-(foot.CFrame.UpVector)
    line("SolarJet",foot.Position,foot.Position+down*len,0.35,colors.Solarion,0.24)
    line("SolarJetCore",foot.Position,foot.Position+down*len*0.6,0.15,SUNCORE,0.2)
    flames(foot.Position+down*0.5,colors.Solarion,3,0.6,6)
   end
  end
  if changed and state=="Takeoff" then sunburst(root.Position-Vector3.new(0,2.5,0),colors.Solarion,2,0.3); sound(FIRE,root.Position,0.5,0.8) end
  if changed and state=="Land" then Surface.scorch(model,root.Position,2) end
 else
  motes("TempestSlipstream",root.Position-root.CFrame.LookVector,colors.Tempest,3,true)
  -- R38: static crawls over her while she flies, and now and then a crack of lightning below her.
  local a=math.random()*math.pi*2
  storm(root.Position+Vector3.new(math.cos(a),1.5,math.sin(a)),root.Position+Vector3.new(-math.cos(a),-1.5,-math.sin(a)),colors.Tempest,0.1,0.06)
  if math.random()<0.12 then storm(root.Position-Vector3.new(0,2,0),root.Position-Vector3.new(math.random(-6,6),14,math.random(-6,6)),colors.Tempest,0.2,0.16) end
 end
end
function FX.ground(model,at,kind)
 if not FX.visible(model) then return end
 if kind=="SolarFlare" then Surface.scorch(model,at,Rules.Moves.SolarFlare.Aoe)
 elseif kind=="PounceLand" then
  ring("PounceSplash",at,Rules.Moves.Pounce.Splash,colors.Solarion,.35)
  sunburst(at+Vector3.new(0,1,0),colors.Solarion,2.5,0.35); sound(FIRE,at,0.6,0.8) -- R40
  Surface.scorch(model,at,Rules.Moves.Pounce.Splash)
 else Surface.quake(model,at,3) end -- Titan Drop hits its carried victim, not a ten-stud area.
end
return FX
