-- Cosmetic surface marks only: never edits terrain, collision, or damage.
local Debris=game:GetService("Debris")
local Tween=game:GetService("TweenService")
local S={count=0,limit=96}
local bin=Instance.new("Folder"); bin.Name="HeroSurfaceFX"; bin.Parent=workspace
local function ground(model,at)
 local p=RaycastParams.new(); p.FilterType=Enum.RaycastFilterType.Exclude
 local exclude={bin}
 for _,v in workspace:GetChildren() do
  if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") or v.Name=="HeroPowerFX" then table.insert(exclude,v) end
 end
 if model then table.insert(exclude,model) end
 p.FilterDescendantsInstances=exclude
 local hit=workspace:Raycast(at+Vector3.yAxis*2,-Vector3.yAxis*14,p)
 if not hit or hit.Normal.Y<0.45 or hit.Material==Enum.Material.Water then return end
 local up=hit.Normal; local right=up:Cross(Vector3.zAxis).Unit
 return CFrame.fromMatrix(hit.Position+up*0.035,right,up),hit
end
local function piece(cf,size,color,life,material)
 if S.count>=S.limit then return end
 local p=Instance.new("Part"); p.Name="SurfaceMark"; p.Anchored=true
 p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=false
 p.Size=size; p.CFrame=cf; p.Color=color; p.Material=material or Enum.Material.Slate
 p.Parent=bin; S.count+=1; p.Destroying:Once(function() S.count-=1 end)
 task.delay(math.max(0,life-1),function() if p.Parent then Tween:Create(p,TweenInfo.new(1),{Transparency=1}):Play() end end)
 Debris:AddItem(p,life); return p
end
local function smoke(cf,color,big)
 local p=piece(cf,Vector3.one*.1,color,3); if not p then return end; p.Transparency=1
 local e=Instance.new("ParticleEmitter"); e.Texture="rbxasset://textures/particles/smoke_main.dds"
 e.Rate=0; e.Lifetime=NumberRange.new(1,2.5); e.Speed=NumberRange.new(1,4)
 e.Acceleration=Vector3.new(0,2,0); e.SpreadAngle=Vector2.new(25,25)
 e.Color=ColorSequence.new(color); e.LightEmission=0
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,big and 4 or 2)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,1)})
 e.Parent=p; e:Emit(big and 16 or 7)
end
function S.scorch(model,at,radius)
 local cf=ground(model,at); if not cf then return end
 for i=1,7 do
  local a=i*2.399; local r=radius*math.sqrt(i/7)*.5
  local p=piece(cf*CFrame.new(math.cos(a)*r,0,math.sin(a)*r)*CFrame.Angles(0,a,0),Vector3.new(radius*.75,.025,radius*.5),Color3.fromRGB(29,24,21),8)
  if p then p.Name="SolarScorch" end
 end
 smoke(cf,Color3.fromRGB(65,61,57),radius>3)
end
function S.quake(model,at,radius)
 local cf,hit=ground(model,at); if not cf then return end
 for ray=1,6 do
  local angle=ray*math.pi/3; local prev=Vector3.zero
  for step=1,3 do
   local nextPoint=Vector3.new(math.cos(angle)*radius*step/3,0,math.sin(angle)*radius*step/3)
    +Vector3.new(math.sin(ray*step)*.45,0,math.cos(ray+step)*.45)
   local a=cf:PointToWorldSpace(prev); local b=cf:PointToWorldSpace(nextPoint)
   -- Reproject every segment, preventing floating cracks across ledges.
   local surface=ground(model,(a+b)/2)
   if surface and math.abs(surface.Position.Y-((a+b)/2).Y)<1 then
    local dir=b-a; local back=dir.Unit; local right=surface.UpVector:Cross(back).Unit
    local mark=piece(CFrame.fromMatrix(surface.Position,right,surface.UpVector,back),Vector3.new(.12+step*.035,.035,dir.Magnitude),Color3.fromRGB(28,27,25),5)
    if mark then mark.Name="BulwarkGroundCrack" end
   end
   prev=nextPoint
  end
  local offset=Vector3.new(math.cos(angle),0,math.sin(angle))*radius*.55
  local rock=piece(cf*CFrame.new(offset),Vector3.new(.5,.35,.65),hit.Instance:IsA("BasePart") and hit.Instance.Color or Color3.fromRGB(100,95,87),.8,Enum.Material.Slate)
  if rock then rock.Name="EarthquakeDebris"; Tween:Create(rock,TweenInfo.new(.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out,0,true),{CFrame=rock.CFrame+Vector3.yAxis*1.4}):Play() end
 end
 smoke(cf,Color3.fromRGB(119,111,97),true)
end
return S
