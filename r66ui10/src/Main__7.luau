local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Rules=require(RS.HeroWars.Rules)
local Appearance=require(script.Parent.Appearance)
Players.CharacterAutoLoads=false
local remote=Instance.new("RemoteEvent"); remote.Name="Combat"; remote.Parent=RS.HeroWars
-- Arena light (v19, looks only): environment reflections so polished armour shines, and a soft bloom
-- so the glowing parts glow.
do
 local Lighting=game:GetService("Lighting")
 -- v36 graphics pass: full environment light and reflections, crisp shadows.
 Lighting.EnvironmentSpecularScale=1; Lighting.EnvironmentDiffuseScale=1
 Lighting.GlobalShadows=true; Lighting.ShadowSoftness=0.12
 if not Lighting:FindFirstChild("HeroWarsBloom") then
  local bloom=Instance.new("BloomEffect"); bloom.Name="HeroWarsBloom"
  bloom.Intensity=0.5; bloom.Size=20; bloom.Threshold=1.4; bloom.Parent=Lighting
 end
end
local states={}; local gates={}; local tick=0
-- Spawn counter: fighters update in this fixed order every tick, never in hash-table order.
local nextIndex=0
-- The sparring bot's current state (replaced each time it respawns).
local dummy=nil
-- Paused: the whole simulation stops, including every timer, until resumed.
local paused=false
-- Overtime (v27): nobody can take off while it runs.
local noFlight=false
-- Highest anyone can be (the top flight ceiling); a Bulwark leap may go this high.
local TOP_HEIGHT=0
for _,h in Rules.FlightCeiling do TOP_HEIGHT=math.max(TOP_HEIGHT,h+3) end
-- v32 arenas (Peter: "arena layout and style, 2 choices: modern city park and an ancient Aztec ruin").
-- Both are 180 x 180 on a flat floor at Y=0 inside the same walls, mirrored so neither side has an edge,
-- with blocks that stop movement and line of sight, and four to six shadow pools for Wraithstep.
-- Decoration never collides and never blocks beams. Switch with the Arena button between matches.
local arena=Instance.new("Folder"); arena.Name="HeroWarsArena"; arena.Parent=workspace
local shadowZones={}
local arenaName=Rules.Arenas.Order[1]
-- R61: an arena whose middle is built over (Jungle Temples' centre pyramid) sets its own start spots (z of the
-- player spawn, the bot spawn and the round start line); nil = the usual spots around the middle.
local arenaSpots=nil
local function spotZ(kind,default) return arenaSpots and arenaSpots[kind] or default end
-- R63: can these two fighters hurt each other? Set by the duel system (fighters in a duel only hit each other).
local foe=function(_s,_t) return true end
local MAT=Enum.Material
local function part(name,size,position,color,material)
 local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.Size=size
 p.Position=position; p.Color=color or Color3.fromRGB(128,128,128); p.Material=material or MAT.SmoothPlastic; p.Parent=arena
 return p
end
-- Looks only: no collision, never blocks beams or line of sight.
local function deco(name,size,position,color,material,shape)
 local p=part(name,size,position,color,material or MAT.Neon)
 p.CanCollide=false; p.CanQuery=false; p.CanTouch=false
 if p.Material==MAT.Neon then p.CastShadow=false end
 if shape then p.Shape=shape end
 return p
end
-- A flat disc lying on the floor (cylinders stand on their X axis, so turn them).
local function disc(name,diameter,y,color,material,x,z)
 local p=deco(name,Vector3.new(0.06,diameter,diameter),Vector3.zero,color,material,Enum.PartType.Cylinder)
 p.CFrame=CFrame.new(x or 0,y,z or 0)*CFrame.Angles(0,0,math.rad(90))
 return p
end
local function light(p,color,range,brightness)
 local l=Instance.new("PointLight"); l.Color=color; l.Range=range; l.Brightness=brightness or 1.5; l.Shadows=false; l.Parent=p
end
local function flame(p)
 local f=Instance.new("Fire"); f.Size=3; f.Heat=6; f.Color=Color3.fromRGB(255,150,60); f.SecondaryColor=Color3.fromRGB(255,60,20); f.Parent=p
 light(p,Color3.fromRGB(255,160,80),24,2.2)
 -- v36: fire casts real flickering shadows (Future lighting).
 local l=p:FindFirstChildOfClass("PointLight"); if l then l.Shadows=true end
 local a=Instance.new("Attachment"); a.Position=Vector3.new(0,0.6,0); a.Parent=p
 local e=Instance.new("ParticleEmitter"); e.Texture="rbxasset://textures/particles/sparkles_main.dds"
 e.Color=ColorSequence.new(Color3.fromRGB(255,190,90),Color3.fromRGB(255,80,20)); e.LightEmission=1; e.Rate=8
 e.Lifetime=NumberRange.new(0.8,1.6); e.Speed=NumberRange.new(2,5); e.SpreadAngle=Vector2.new(25,25)
 e.Acceleration=Vector3.new(0,3,0); e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.18),NumberSequenceKeypoint.new(1,0)}); e.Parent=a
end
-- A shadow pool (v28 rules): Wraithstep standing in it is Shrouded. glow = edge colour.
local function shadowPool(center,glow)
 if Rules.Arenas.ShadowPools==false then return end -- R58 (Peter): no shadow-pool squares on the ground
 local pool=deco("ShadowPool",Vector3.new(12,0.06,12),center+Vector3.new(0,0.04,0),Color3.fromRGB(8,6,14),MAT.SmoothPlastic)
 pool.Transparency=0.25; pool.CastShadow=false
 for _,e in {{Vector3.new(12.4,0.08,0.25),Vector3.new(0,0,6.1)},{Vector3.new(12.4,0.08,0.25),Vector3.new(0,0,-6.1)},
  {Vector3.new(0.25,0.08,12.4),Vector3.new(6.1,0,0)},{Vector3.new(0.25,0.08,12.4),Vector3.new(-6.1,0,0)}} do
  deco("ShadowEdge",e[1],center+e[2]+Vector3.new(0,0.06,0),glow).Transparency=0.45
 end
 local att=Instance.new("Attachment"); att.Parent=pool
 local wisp=Instance.new("ParticleEmitter"); wisp.Texture="rbxasset://textures/particles/smoke_main.dds"
 wisp.Color=ColorSequence.new(Color3.fromRGB(30,15,45)); wisp.Rate=6; wisp.Lifetime=NumberRange.new(2,3.5)
 wisp.Speed=NumberRange.new(0.5,1.5); wisp.SpreadAngle=Vector2.new(80,80); wisp.EmissionDirection=Enum.NormalId.Top
 wisp.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,3),NumberSequenceKeypoint.new(1,5)})
 wisp.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.75),NumberSequenceKeypoint.new(1,1)}); wisp.Parent=att
 table.insert(shadowZones,{center=center,half=6})
end
local function walls(visible,color,material)
 for _,v in {{0,12,91,184,24,2},{0,12,-91,184,24,2},{91,12,0,2,24,180},{-91,12,0,2,24,180}} do
  local w=part("Boundary",Vector3.new(v[4],v[5],v[6]),Vector3.new(v[1],v[2],v[3]),color,material)
  if not visible then w.Transparency=1; w.CastShadow=false end
 end
end
local function mirror4(f) for _,sx in {-1,1} do for _,sz in {-1,1} do f(sx,sz) end end end
local Lighting=game:GetService("Lighting")
local function effect(class,name,props)
 local e=Lighting:FindFirstChild(name)
 if not e then e=Instance.new(class); e.Name=name; e.Parent=Lighting end
 for k,v in props do e[k]=v end
end
if not Lighting:FindFirstChildOfClass("Sky") then local sky=Instance.new("Sky"); sky.SunAngularSize=14; sky.Parent=Lighting end
-- v36 graphics pass (Peter: "upgrade all graphics for everything in HeroWars"). Looks only: nothing in GFX
-- collides inside the walls, blocks line of sight or changes a hit.
local GFX={}
-- Real terrain outside the walls (ground, an outer band, optional water), never inside the fight.
function GFX.terrain(ground,groundColor,band,bandColor,water)
 local T=workspace.Terrain
 T:Clear()
 pcall(function() T.Decoration=true end) -- grass blades
 T:SetMaterialColor(ground,groundColor)
 T:FillBlock(CFrame.new(0,-6,0),Vector3.new(600,12,600),ground)
 if band then
  T:SetMaterialColor(band,bandColor)
  for _,v in {{0,100,216,16},{0,-100,216,16},{100,0,16,216},{-100,0,16,216}} do
   T:FillBlock(CFrame.new(v[1],-6,v[2]),Vector3.new(v[3],12,v[4]),band)
  end
 end
 if water then
  T:FillBlock(water*CFrame.new(0,1,0),Vector3.new(600,8,24),Enum.Material.Air)
  T:FillBlock(water,Vector3.new(600,8,24),Enum.Material.Water)
 end
 -- The fight floor is a part; keep terrain out from under it so no grass pokes through.
 T:FillBlock(CFrame.new(0,-6,0),Vector3.new(184,12,184),Enum.Material.Air)
end
-- Sky, sun, stars and volumetric clouds.
function GFX.sky(props,clouds)
 local sky=Lighting:FindFirstChildOfClass("Sky")
 if sky then for k,v in props do sky[k]=v end end
 local c=workspace.Terrain:FindFirstChildOfClass("Clouds")
 if not c then c=Instance.new("Clouds"); c.Parent=workspace.Terrain end
 for k,v in clouds do c[k]=v end
end
-- Drifting motes over the arena (pollen by day, fireflies and dust at dusk).
function GFX.motes(color,rate,size,glow)
 local box=deco("Motes",Vector3.new(170,26,170),Vector3.new(0,14,0),Color3.new(),MAT.SmoothPlastic)
 box.Transparency=1; box.CastShadow=false
 local e=Instance.new("ParticleEmitter"); e.Texture="rbxasset://textures/particles/sparkles_main.dds"
 e.Shape=Enum.ParticleEmitterShape.Box; e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume
 e.Color=ColorSequence.new(color); e.LightEmission=glow; e.Rate=rate; e.Lifetime=NumberRange.new(5,9)
 e.Speed=NumberRange.new(0.2,0.8); e.SpreadAngle=Vector2.new(180,180); e.RotSpeed=NumberRange.new(-30,30)
 e.Acceleration=Vector3.new(0.3,0.15,0)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(0.2,size),NumberSequenceKeypoint.new(0.8,size),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new(0.2); e.Parent=box
end
-- Bloom, depth of field and grade for an arena.
function GFX.post(bloom,exposure)
 effect("BloomEffect","HeroWarsBloom",bloom)
 effect("DepthOfFieldEffect","HeroWarsDepth",{FarIntensity=0.14,FocusDistance=45,InFocusRadius=95,NearIntensity=0})
 Lighting.ExposureCompensation=exposure
end

local BUILD={}
-- Modern city park: grass and paved paths, news kiosks for cover, four big trees whose shade is a
-- shadow pool, two graffiti walls, benches to hop over, lamp posts, and a city skyline past the hedges.
function BUILD.Park()
 part("Floor",Vector3.new(180,2,180),Vector3.new(0,-1,0),Color3.fromRGB(84,138,68),MAT.Grass)
 walls(false,Color3.fromRGB(60,90,50),MAT.Grass)
 local PAVE=Color3.fromRGB(176,170,160)
 deco("Path",Vector3.new(176,0.04,12),Vector3.new(0,0.02,0),PAVE,MAT.Pavement)
 deco("Path",Vector3.new(12,0.04,176),Vector3.new(0,0.02,0),PAVE,MAT.Pavement)
 disc("Plaza",30,0.04,Color3.fromRGB(190,184,172),MAT.Pavement)
 disc("PlazaRing",22,0.06,Color3.fromRGB(150,120,90),MAT.Brick)
 disc("PlazaInner",18,0.08,Color3.fromRGB(196,190,178),MAT.Pavement)
 -- Hedge and railings along the edge; the city rises behind them.
 for _,v in {{0,88,180,4,3},{0,-88,180,4,3},{88,0,3,4,180},{-88,0,3,4,180}} do
  deco("Hedge",Vector3.new(v[3],v[4],v[5]),Vector3.new(v[1],2,v[2]),Color3.fromRGB(46,96,44),MAT.Grass)
 end
 local rng=Random.new(32)
 for side=1,4 do
  for i=-4,4 do
   local h=rng:NextInteger(40,130); local w=rng:NextInteger(18,30)
   local along=i*22; local out=110+rng:NextInteger(0,30)
   local pos=side==1 and Vector3.new(along,h/2,-out) or side==2 and Vector3.new(along,h/2,out)
    or side==3 and Vector3.new(-out,h/2,along) or Vector3.new(out,h/2,along)
   local tone=rng:NextInteger(70,140)
   deco("Building",Vector3.new(w,h,w),pos,Color3.fromRGB(tone,tone+6,tone+16),rng:NextNumber()<0.5 and MAT.Glass or MAT.Concrete)
   for y=12,h-6,14 do
    deco("Windows",Vector3.new(w+0.2,1.2,w+0.2),Vector3.new(pos.X,y,pos.Z),rng:NextNumber()<0.5 and Color3.fromRGB(255,214,140) or Color3.fromRGB(150,200,255)).Transparency=0.35
   end
  end
 end
 -- Cover: two news kiosks.
 for _,x in {-26,26} do
  part("Cover",Vector3.new(8,12,18),Vector3.new(x,6,0),Color3.fromRGB(46,96,140),MAT.Metal)
  deco("KioskRoof",Vector3.new(10,0.8,20),Vector3.new(x,12.4,0),Color3.fromRGB(220,70,60),MAT.SmoothPlastic)
  deco("KioskSign",Vector3.new(8.2,1.2,18.2),Vector3.new(x,10.6,0),Color3.fromRGB(255,220,120))
  deco("KioskWindow",Vector3.new(8.3,4,12),Vector3.new(x,6,0),Color3.fromRGB(170,210,230),MAT.Glass).Transparency=0.3
 end
 -- Four big trees: the trunk blocks, the canopy is only looks, and its shade is a shadow pool.
 for _,c in {{-48,-36},{48,-36},{-48,40},{48,40}} do
  part("Obstacle",Vector3.new(4,16,4),Vector3.new(c[1],8,c[2]),Color3.fromRGB(96,66,44),MAT.Wood)
  for i,b in {{0,18,0,20},{-5,15,3,13},{5,16,-3,14},{0,22,0,13},{-4,20,-4,10},{5,20,4,11}} do
   deco("Canopy",Vector3.one*b[4],Vector3.new(c[1]+b[1],b[2],c[2]+b[3]),i%2==0 and Color3.fromRGB(64,128,56) or Color3.fromRGB(48,104,46),MAT.LeafyGrass,Enum.PartType.Ball)
  end
  -- v36: roots at the base and a few falling leaves.
  for k=0,3 do
   local a=k*math.pi/2+0.4
   deco("TreeRoot",Vector3.new(1.2,1,4),Vector3.new(c[1]+math.cos(a)*2.4,0.4,c[2]+math.sin(a)*2.4),Color3.fromRGB(86,60,40),MAT.Wood).CFrame=
    CFrame.new(c[1]+math.cos(a)*2.6,0.35,c[2]+math.sin(a)*2.6)*CFrame.Angles(0,-a+math.pi/2,0)*CFrame.Angles(math.rad(-12),0,0)
  end
  local leafBox=deco("Leaves",Vector3.new(16,2,16),Vector3.new(c[1],14,c[2]),Color3.new(),MAT.SmoothPlastic); leafBox.Transparency=1
  local lf=Instance.new("ParticleEmitter"); lf.Shape=Enum.ParticleEmitterShape.Box; lf.Rate=1.5; lf.Lifetime=NumberRange.new(5,7)
  lf.Color=ColorSequence.new(Color3.fromRGB(110,150,60),Color3.fromRGB(200,150,60)); lf.Speed=NumberRange.new(0.5,1)
  lf.Acceleration=Vector3.new(0.6,-2.2,0.3); lf.RotSpeed=NumberRange.new(-120,120); lf.Rotation=NumberRange.new(0,360)
  lf.Size=NumberSequence.new(0.35); lf.Texture="rbxasset://textures/particles/sparkles_main.dds"; lf.Parent=leafBox
  shadowPool(Vector3.new(c[1],0,c[2]),Color3.fromRGB(120,70,200))
 end
 -- Two graffiti walls with shade behind them.
 for _,z in {-56,58} do
  part("Obstacle",Vector3.new(16,10,3),Vector3.new(0,5,z),Color3.fromRGB(150,150,148),MAT.Concrete)
  local side=z<0 and -1.6 or 1.6
  for i,col in {Color3.fromRGB(255,80,160),Color3.fromRGB(80,220,255),Color3.fromRGB(255,210,60)} do
   deco("Graffiti",Vector3.new(4.5,2.2+i,0.1),Vector3.new(-7+i*4.2,3+i*0.8,z-side),col).Transparency=0.15
  end
  shadowPool(Vector3.new(0,0,z+7),Color3.fromRGB(120,70,200))
 end
 -- Benches: knee-high, you can hop over them.
 mirror4(function(sx,sz)
  part("Bench",Vector3.new(6,1.6,2),Vector3.new(sx*14,0.8,sz*32),Color3.fromRGB(130,86,52),MAT.WoodPlanks)
 end)
 -- Lamp posts along the paths.
 for _,v in {{-9,-30},{9,30},{-30,9},{30,-9},{-9,62},{9,-62},{62,9},{-62,-9}} do
  deco("LampPost",Vector3.new(0.6,14,0.6),Vector3.new(v[1],7,v[2]),Color3.fromRGB(40,44,50),MAT.Metal)
  local head=deco("LampHead",Vector3.new(1.6,1,1.6),Vector3.new(v[1],14.4,v[2]),Color3.fromRGB(255,230,170))
  light(head,Color3.fromRGB(255,225,170),24,1)
  deco("LampCap",Vector3.new(2.2,0.4,2.2),Vector3.new(v[1],15.1,v[2]),Color3.fromRGB(40,44,50),MAT.Metal)
  deco("LampBase",Vector3.new(1.4,1,1.4),Vector3.new(v[1],0.5,v[2]),Color3.fromRGB(40,44,50),MAT.Metal)
 end
 -- v36: flower beds along the hedges and stepping-stone edging on the paths (looks only).
 local FLOWERS={Color3.fromRGB(255,90,120),Color3.fromRGB(255,210,70),Color3.fromRGB(170,110,255),Color3.fromRGB(255,255,255)}
 local frng=Random.new(7)
 for _,side in {{0,84,1,0},{0,-84,1,0},{84,0,0,1},{-84,0,0,1}} do
  for i=-7,7 do
   local x=side[1]+side[3]*i*11; local z=side[2]+side[4]*i*11
   if math.abs(i)<=1 then continue end -- keep the path ends clear
   deco("FlowerBed",Vector3.new(side[3]==1 and 8 or 3,0.5,side[4]==1 and 8 or 3),Vector3.new(x,0.25,z),Color3.fromRGB(80,56,38),MAT.Ground)
   for _=1,5 do
    deco("Flower",Vector3.one*0.7,Vector3.new(x+(frng:NextNumber()-0.5)*(side[3]==1 and 7 or 2),0.7,z+(frng:NextNumber()-0.5)*(side[4]==1 and 7 or 2)),
     FLOWERS[frng:NextInteger(1,#FLOWERS)],MAT.SmoothPlastic,Enum.PartType.Ball)
   end
  end
 end
 for _,along in {-51.5,51.5} do
  for _,o in {-6.4,6.4} do
   deco("Kerb",Vector3.new(73,0.3,0.6),Vector3.new(along,0.12,o),Color3.fromRGB(150,146,140),MAT.Concrete)
   deco("Kerb",Vector3.new(0.6,0.3,73),Vector3.new(o,0.12,along),Color3.fromRGB(150,146,140),MAT.Concrete)
  end
 end
 deco("CenterLine",Vector3.new(1,0.04,150),Vector3.new(0,0.1,0),Color3.fromRGB(255,255,255),MAT.SmoothPlastic).Transparency=0.6
 Lighting.ClockTime=14.2; Lighting.Brightness=3; Lighting.OutdoorAmbient=Color3.fromRGB(140,140,150)
 Lighting.Ambient=Color3.fromRGB(40,44,52); Lighting.ColorShift_Top=Color3.fromRGB(255,248,235); Lighting.GeographicLatitude=35
 effect("Atmosphere","HeroWarsAtmosphere",{Density=0.22,Offset=0.1,Haze=0.8,Glare=0.2,Color=Color3.fromRGB(200,215,235),Decay=Color3.fromRGB(120,140,170)})
 effect("ColorCorrectionEffect","HeroWarsGrade",{Contrast=0.1,Saturation=0.2,TintColor=Color3.fromRGB(255,252,245)})
 effect("SunRaysEffect","HeroWarsSunRays",{Intensity=0.05,Spread=0.5})
 -- v36: grass and a city street round the park, a blue sky with drifting clouds, pollen in the air.
 GFX.terrain(Enum.Material.Grass,Color3.fromRGB(78,132,62),Enum.Material.Asphalt,Color3.fromRGB(58,60,66))
 GFX.sky({SunAngularSize=12,MoonAngularSize=9,StarCount=0,CelestialBodiesShown=true},{Cover=0.55,Density=0.55,Color=Color3.fromRGB(255,255,255)})
 GFX.motes(Color3.fromRGB(255,250,210),14,0.18,0.3)
 GFX.post({Intensity=0.45,Size=24,Threshold=1.5},0.1)
end
-- R37 (Peter sent a photo of Tikal: "the arena for Aztec, make it something like this"): Jungle Temples.
-- A grass plaza in misty rainforest. Two grey step pyramids with a temple house on top face each other
-- across the plaza (north and south); two smaller shrines sit east and west; carved stelae give cover.
-- Every temple has a front stairway you can run up, so the high ground is part of the fight. The walls are
-- invisible; the jungle closes in all round, with the great Temple I towering over the trees to the north.
function BUILD.Ruin()
 local STONE=Color3.fromRGB(122,120,112); local LIGHT=Color3.fromRGB(150,146,136); local DARK=Color3.fromRGB(78,76,72)
 local MOSS=Color3.fromRGB(70,98,58); local PAINT=Color3.fromRGB(176,78,48); local GRASS=Color3.fromRGB(76,122,58)
 part("Floor",Vector3.new(180,2,180),Vector3.new(0,-1,0),GRASS,MAT.Grass)
 walls(false,STONE,MAT.Slate) -- R57 fix: walls(false) passed no colour, so the whole arena failed to build (R37-R56)
 -- Plaza: worn stone paths in a cross, mossy patches, a low terrace edge all round.
 deco("PathNS",Vector3.new(10,0.05,170),Vector3.new(0,0.03,0),Color3.fromRGB(132,128,116),MAT.Cobblestone)
 deco("PathEW",Vector3.new(170,0.05,10),Vector3.new(0,0.03,0),Color3.fromRGB(132,128,116),MAT.Cobblestone)
 disc("PlazaCircle",22,0.07,Color3.fromRGB(128,124,114),MAT.Slate)
 disc("PlazaGlyph",8,0.09,Color3.fromRGB(150,70,45),MAT.Slate)
 local mr=Random.new(9)
 for _=1,(Rules.Arenas.ShadowPools==false and 0 or 18) do
  deco("MossPatch",Vector3.new(mr:NextInteger(6,14),0.04,mr:NextInteger(5,11)),Vector3.new(mr:NextInteger(-80,80),0.025,mr:NextInteger(-80,80)),Color3.fromRGB(58,mr:NextInteger(90,110),48),MAT.LeafyGrass)
 end
 for _,v in {{0,-89,178,2},{0,89,178,2},{-89,0,2,178},{89,0,2,178}} do
  deco("TerraceEdge",Vector3.new(v[3],1.2,v[4]),Vector3.new(v[1],0.6,v[2]),DARK,MAT.Slate)
 end
 -- A temple: stepped tiers, a front stairway (a ramp you can run up), a temple house with a dark doorway,
 -- red painted carvings and a roof comb. facing = unit vector from the temple toward the plaza centre.
 -- R56 (Peter: "I don't think it spawned like the picture"): steeper, taller tiers with dark weathered
 -- bands, a wide stairway, a bigger temple house with a painted frieze and a tall roof comb, as in the photo.
 -- R59: Peter's saved Toolbox models (RS.HeroWars.Temples) replace the block temples' look. Each is scaled to the
 -- old footprint (or a height), set on the ground with its stairs toward the plaza. With Collide the model is
 -- what you walk on and the old blocks go; without it the model is look-only and the blocks stay invisible.
 -- Returns false (keep the blocks as they are) if the model is missing or fails.
 local TM=Rules.Arenas.TempleModels or {}
 local temples=RS.HeroWars:FindFirstChild("Temples")
 local function dressWithModel(kind,before,center,facing,base)
  local cfg=TM[kind]
  if not (TM.Enabled and temples and cfg) then return false end
  local src=temples:FindFirstChild(cfg.Name or "")
  if not src then return false end
  local placedSize
  local ok,err=pcall(function()
   local m=src:IsA("Model") and src:Clone() or nil
   if not m then m=Instance.new("Model"); src:Clone().Parent=m end
   for _,d in m:GetDescendants() do if d:IsA("LuaSourceContainer") then d:Destroy() end end
   local _,size=m:GetBoundingBox()
   local s=cfg.Height and cfg.Height/math.max(size.Y,0.1) or (base*(cfg.Fit or 1))/math.max(size.X,size.Z,0.1)
   if s>0 and math.abs(s-1)>0.001 then m:ScaleTo(m:GetScale()*s) end
   local bcf,bsize=m:GetBoundingBox()
   local look=CFrame.lookAt(center,center+facing)*CFrame.Angles(0,math.rad(cfg.Yaw or 0),0)
   -- Pivot so the bounding box's bottom centre sits on the ground at the temple centre.
   local offset=bcf:ToObjectSpace(m:GetPivot())
   m:PivotTo(look*CFrame.new(0,bsize.Y/2,0)*offset)
   for _,d in m:GetDescendants() do
    if d:IsA("BasePart") then d.Anchored=true; d.CanCollide=cfg.Collide==true; d.CanQuery=cfg.Collide==true; d.CanTouch=false end
   end
   m.Name=kind.."Model"; m.Parent=arena
   placedSize=bsize
  end)
  if not ok then warn("[HeroWars] temple model "..tostring(cfg.Name).." failed: "..tostring(err)); return false end
  local had={}; for _,c in before do had[c]=true end
  for _,c in arena:GetChildren() do
   if not had[c] and c:IsA("BasePart") then
    if c.CanCollide and not cfg.Collide then c.Transparency=1 else c:Destroy() end
   end
  end
  return true,placedSize
 end
 local function temple(center,facing,tiers,base,step,house,tierH,kind)
  tierH=tierH or 4
  local before=arena:GetChildren()
  local look=CFrame.lookAt(center,center+facing)
  for i=0,tiers-1 do
   local w=base-i*step*2
   local t=part("Obstacle",Vector3.new(w,tierH,w),Vector3.zero,i%2==0 and STONE or LIGHT,MAT.Slate)
   t.CFrame=look*CFrame.new(0,tierH/2+i*tierH,0)
   deco("TierBand",Vector3.new(w+0.15,tierH*0.3,w+0.15),Vector3.zero,DARK,MAT.Slate).CFrame=look*CFrame.new(0,i*tierH+tierH*0.15,0)
   deco("TierMoss",Vector3.new(w+0.1,0.4,w+0.1),Vector3.zero,MOSS,MAT.LeafyGrass).CFrame=look*CFrame.new(0,(i+1)*tierH+0.05,0)
  end
  local height=tiers*tierH; local topHalf=(base-(tiers-1)*step*2)/2; local depth=height
  local ramp=Instance.new("WedgePart"); ramp.Name="Stairs"; ramp.Anchored=true
  ramp.Size=Vector3.new(10,height,depth); ramp.Color=DARK; ramp.Material=MAT.Slate; ramp.Parent=arena
  -- A wedge's low edge is on its front (-Z), so it faces out from the temple and climbs toward it.
  ramp.CFrame=look*CFrame.new(0,height/2,-(topHalf+depth/2))
  for k=1,math.floor(height/1.2) do -- step lines painted on the ramp
   local d=topHalf+depth*(k/math.floor(height/1.2)); local y=height*(1-k/math.floor(height/1.2))
   deco("StepLine",Vector3.new(10.1,0.15,0.4),Vector3.zero,Color3.fromRGB(60,58,55),MAT.Slate).CFrame=look*CFrame.new(0,y+0.05,-d)
  end
  local hy=height+house.Y/2
  local hut=part("Obstacle",house,Vector3.zero,LIGHT,MAT.Slate); hut.CFrame=look*CFrame.new(0,hy,0)
  deco("Doorway",Vector3.new(house.X*0.3,house.Y*0.55,0.3),Vector3.zero,Color3.fromRGB(14,12,12),MAT.SmoothPlastic).CFrame=look*CFrame.new(0,height+house.Y*0.28,-house.Z/2-0.1)
  for _,sx in {-1,1} do
   deco("Carving",Vector3.new(house.X*0.25,house.Y*0.4,0.25),Vector3.zero,PAINT,MAT.Slate).CFrame=look*CFrame.new(sx*house.X*0.32,height+house.Y*0.55,-house.Z/2-0.1)
  end
  deco("Frieze",Vector3.new(house.X+0.2,house.Y*0.22,house.Z+0.2),Vector3.zero,Color3.fromRGB(196,170,130),MAT.Slate).CFrame=look*CFrame.new(0,height+house.Y*0.86,0)
  deco("RoofComb",Vector3.new(house.X*0.6,house.Y*0.9,house.Z*0.35),Vector3.zero,STONE,MAT.Slate).CFrame=look*CFrame.new(0,height+house.Y*1.45,house.Z*0.15)
  deco("Vines",Vector3.new(base*0.5,height*0.6,0.2),Vector3.zero,Color3.fromRGB(56,104,48),MAT.LeafyGrass).CFrame=look*CFrame.new(base*0.22,height*0.4,base/2+0.05)
  dressWithModel(kind or "Temple",before,center,facing,base)
 end
 -- The two great pyramids face each other; the two shrines east and west.
 -- R61 (Peter: "move the big pyramid to the centre and remove the small pyramids"): with the big pyramid
 -- model baked in, it stands in the middle of the plaza (stairs facing the spawn side) and the four small
 -- temples are gone. Fighters start on the stairs side (Rules.Arenas.TempleModels.Centre.Spots).
 local centre=TM.Enabled and temples and TM.Centre and temples:FindFirstChild(TM.Centre.Name or "")
 if centre then
  local used=dressWithModel("Centre",arena:GetChildren(),Vector3.zero,Vector3.new(0,0,1),TM.Centre.Width or 80)
  if used then arenaSpots=TM.Centre.Spots; print("[HeroWars] Jungle Temples: "..TM.Centre.Name.." placed in the centre")
  else centre=nil end
 else
  warn("[HeroWars] Jungle Temples: no "..tostring(TM.Centre and TM.Centre.Name).." in ReplicatedStorage.HeroWars.Temples, using the block temples")
 end
 if not centre then
  temple(Vector3.new(0,0,-60),Vector3.new(0,0,1),5,32,2.4,Vector3.new(14,10,12),4.4)
  temple(Vector3.new(0,0,60),Vector3.new(0,0,-1),5,32,2.4,Vector3.new(14,10,12),4.4)
  temple(Vector3.new(-62,0,0),Vector3.new(1,0,0),3,24,2.5,Vector3.new(17,9,14),4,"Shrine")
  temple(Vector3.new(62,0,0),Vector3.new(-1,0,0),3,24,2.5,Vector3.new(17,9,14),4,"Shrine")
 end
 -- Carved stelae with round altars in front (cover, like the small monuments on the plaza).
 mirror4(function(sx,sz)
  local p=centre and Vector3.new(sx*36,0,sz*66) or Vector3.new(sx*28,0,sz*20)
  part("Cover",Vector3.new(3,9,2),p+Vector3.new(0,4.5,0),STONE,MAT.Slate)
  deco("SteleCarving",Vector3.new(2.2,5,0.15),p+Vector3.new(0,5,-sz*1.05),PAINT,MAT.Slate).Transparency=0.3
  local alt=deco("Altar",Vector3.new(1.6,3.4,3.4),p+Vector3.new(0,0.8,-sz*3.2),DARK,MAT.Slate,Enum.PartType.Cylinder)
  alt.CFrame=CFrame.new(p+Vector3.new(0,0.8,-sz*3.2))*CFrame.Angles(0,0,math.rad(90)); alt.CanCollide=false
 end)
 -- Shade pools for Wraithstep beside the pyramids and in front of the shrines.
 mirror4(function(sx,sz) shadowPool(Vector3.new(sx*26,0,sz*44),Color3.fromRGB(110,200,140)) end)
 for _,sx in {-1,1} do shadowPool(Vector3.new(sx*36,0,14),Color3.fromRGB(110,200,140)) end
 -- Beyond the plaza: Temple I towering over the trees to the north, Temple II south, and the rainforest.
 local bigClear={} -- R59: half-width kept free of canopy trees round each big temple model
 local function bigTemple(z,tiers,base,facing)
  local tierH=9; local shrink=4
  local look=CFrame.lookAt(Vector3.new(0,0,z),Vector3.new(0,0,z+facing))
  local before=arena:GetChildren()
  for i=0,tiers-1 do
   local w=base-i*shrink
   deco("Temple",Vector3.new(w,tierH,w),Vector3.zero,i%2==0 and STONE or LIGHT,MAT.Slate).CFrame=look*CFrame.new(0,tierH/2+i*tierH,0)
   deco("TempleBand",Vector3.new(w+0.2,tierH*0.3,w+0.2),Vector3.zero,DARK,MAT.Slate).CFrame=look*CFrame.new(0,i*tierH+tierH*0.15,0)
  end
  local top=tiers*tierH; local topHalf=(base-(tiers-1)*shrink)/2
  local st=Instance.new("WedgePart"); st.Name="TempleStairs"; st.Anchored=true; st.CanCollide=false; st.CanQuery=false; st.CanTouch=false
  st.Size=Vector3.new(12,top,top*0.55); st.Color=DARK; st.Material=MAT.Slate; st.Parent=arena
  st.CFrame=look*CFrame.new(0,top/2,-(topHalf+top*0.275-2))
  deco("TempleHouse",Vector3.new(16,14,13),Vector3.zero,LIGHT,MAT.Slate).CFrame=look*CFrame.new(0,top+7,0)
  deco("TempleDoor",Vector3.new(4,7,0.3),Vector3.zero,Color3.fromRGB(14,12,12),MAT.SmoothPlastic).CFrame=look*CFrame.new(0,top+4.5,-6.6)
  deco("TempleComb",Vector3.new(12,20,5),Vector3.zero,STONE,MAT.Slate).CFrame=look*CFrame.new(0,top+24,2)
  deco("CombWindow",Vector3.new(3,4,5.2),Vector3.zero,Color3.fromRGB(20,20,20),MAT.SmoothPlastic).CFrame=look*CFrame.new(0,top+26,2)
  local used,sz=dressWithModel(z<0 and "BigNorth" or "BigSouth",before,Vector3.new(0,0,z),Vector3.new(0,0,facing),base)
  if used and sz then bigClear[z]=math.max(sz.X,sz.Z)/2 end
 end
 -- Temple I towers over the canopy to the north (the photo's focal point); Temple II smaller to the south.
 if not centre then bigTemple(-215,10,58,1); bigTemple(200,6,44,-1) end
 -- A dense rainforest canopy all round: overlapping crowns at several heights, so it reads as one green
 -- carpet from the plaza, as in the photo (R37 had sparse lollipop trees).
 local rng=Random.new(17)
 for i=1,240 do
  local a=rng:NextNumber()*math.pi*2; local r=rng:NextInteger(94,300)
  local x,z=math.cos(a)*r,math.sin(a)*r
  if math.abs(x)<34 and (math.abs(z+215)<36 or math.abs(z-200)<28) then continue end -- keep the big temples clear
  local skip=false; for bz,h in bigClear do if math.abs(x)<h*0.8 and math.abs(z-bz)<h*0.8 then skip=true end end
  if skip then continue end
  local h=rng:NextInteger(18,34)
  if r<150 then deco("JungleTrunk",Vector3.new(2.4,h,2.4),Vector3.new(x,h/2,z),Color3.fromRGB(110,100,84),MAT.Wood) end
  local cw=rng:NextInteger(24,40)
  deco("JungleCrown",Vector3.new(cw,cw*0.5,cw),Vector3.new(x,h+cw*0.15,z),Color3.fromRGB(rng:NextInteger(30,48),rng:NextInteger(78,112),rng:NextInteger(34,48)),MAT.LeafyGrass,Enum.PartType.Ball)
 end
 -- Mist drifting through the canopy.
 -- Low mist lying on the canopy, thickest behind Temple I.
 local fr=Random.new(3)
 for k=1,30 do
  local a=fr:NextNumber()*math.pi*2; local r=fr:NextInteger(150,290)
  local x,z=math.cos(a)*r,math.sin(a)*r
  if k<=12 then x=fr:NextInteger(-160,160); z=fr:NextInteger(-300,-240) end
  local m=deco("Mist",Vector3.new(fr:NextInteger(60,110),fr:NextInteger(8,14),fr:NextInteger(40,70)),Vector3.new(x,fr:NextInteger(34,48),z),Color3.fromRGB(235,238,235),MAT.SmoothPlastic,Enum.PartType.Ball)
  m.Transparency=0.78; m.CastShadow=false
 end
 -- Overcast tropical day: soft grey light, heavy humid haze.
 Lighting.ClockTime=11; Lighting.Brightness=1.7; Lighting.OutdoorAmbient=Color3.fromRGB(140,148,140)
 Lighting.Ambient=Color3.fromRGB(40,44,40); Lighting.ColorShift_Top=Color3.fromRGB(220,226,220); Lighting.GeographicLatitude=17
 effect("Atmosphere","HeroWarsAtmosphere",{Density=0.3,Offset=0.15,Haze=1.8,Glare=0.15,Color=Color3.fromRGB(205,212,205),Decay=Color3.fromRGB(96,116,100)})
 effect("ColorCorrectionEffect","HeroWarsGrade",{Contrast=0.12,Saturation=0.08,TintColor=Color3.fromRGB(236,244,236)})
 effect("SunRaysEffect","HeroWarsSunRays",{Intensity=0.04,Spread=0.6})
 GFX.terrain(Enum.Material.LeafyGrass,Color3.fromRGB(50,86,42),Enum.Material.Mud,Color3.fromRGB(80,70,56))
 GFX.sky({SunAngularSize=10,MoonAngularSize=9,StarCount=0,CelestialBodiesShown=false},{Cover=0.86,Density=0.72,Color=Color3.fromRGB(205,208,210)})
 GFX.motes(Color3.fromRGB(230,235,230),8,0.25,0.2)
 GFX.post({Intensity=0.35,Size=24,Threshold=1.6},0.05)
end
local function buildArena(name)
 if not BUILD[name] then return end
 arena:ClearAllChildren(); table.clear(shadowZones); arenaSpots=nil
 arenaName=name; arena:SetAttribute("Arena",name)
 local ok,err=pcall(BUILD[name])
 if not ok then
  -- Never leave the fight without a floor: fall back to a plain one.
  warn("[HeroWars] arena "..name.." failed to build: "..tostring(err))
  arena:ClearAllChildren(); table.clear(shadowZones); arenaSpots=nil
  part("Floor",Vector3.new(180,2,180),Vector3.new(0,-1,0),Color3.fromRGB(30,37,52),MAT.Slate)
  walls(true,Color3.fromRGB(52,63,82),MAT.Concrete)
 end
end
buildArena(arenaName)
local function alive(s) return s and s.model.Parent and s.hum.Health>0 end
local function notify(p,text) if p then remote:FireClient(p,"Notice",text) end end
local function stopFlight(s)
 s.flying=false; s.velocity.Enabled=false; s.lastFlight=tick; s.hum.AutoRotate=true
end
local dummyGen=0 -- R43: bumped by every bot spawn; a slower, older bot spawn that finishes late is dropped
local D
local function spawnFighter(player,hero,isDummy,skinId,ring)
 local gen
 -- R66-ui: isDummy=="practice" is a still practice dummy beside duel ring `ring` (not the sparring bot).
 local practice=isDummy=="practice"; if practice then isDummy=false end
 if isDummy then dummyGen+=1; gen=dummyGen end
 -- v49: the sparring dummy wears its hero's default (Mixamo character) look too; it used to pick a random
 -- older kit skin, which is why the bot still looked like a Roblox avatar.
 if isDummy and not skinId then skinId=Rules.Skins[hero].Order[1] end
 local skin; skin,skinId=Rules.skin(hero,skinId)
 -- R65 (Peter: first join "took time to come in"): once a hero's body has been built (here or by the lobby
 -- previews) it is kept, and later spawns copy and repaint it instead of downloading a rig from Roblox again.
 Appearance.baseCache=Appearance.baseCache or {}
 local model
 local cached=Appearance.baseCache[hero]
 if cached then
  model=cached:Clone(); Appearance.applySkin(model,hero,skin)
  local hum=model:FindFirstChildOfClass("Humanoid"); hum.MaxHealth=Rules.Characters[hero].Health; hum.Health=hum.MaxHealth
 else
  model=Appearance.create(hero,Rules.Characters[hero],skin) -- may yield while Roblox loads the standard rig
  if not Appearance.baseCache[hero] then Appearance.baseCache[hero]=model:Clone() end
 end
 if player and not player.Parent then model:Destroy(); return end
 -- R43 (Peter: "getting two enemies spawn"): building a body can take seconds while the lobby skins
 -- build, so a bot respawn after a KO and a Bot hero switch (or the first spawn) could both finish and
 -- leave two bots. Only the newest bot spawn counts, and it replaces any bot still standing.
 if isDummy then
  if gen~=dummyGen then model:Destroy(); return end
  for key,st in states do
   if st.isDummy and typeof(key)=="Instance" and key:IsA("Model") then
    if st.shadowCircle then st.shadowCircle.visual:Destroy() end
    states[key]=nil; key:Destroy()
   end
  end
  dummy=nil
 end
 local previous=player and states[player]
 if previous and previous.shadowCircle then previous.shadowCircle.visual:Destroy() end
 if previous then states[previous.model]=nil; states[player]=nil; previous.model:Destroy() end
 model.Parent=workspace
 local SPAWN_X={Solarion=-10,Wraithstep=10,Tempest=-18,Bulwark=18}
 local origin=isDummy and Vector3.new(0,4,spotZ("Dummy",-22)) or Vector3.new(SPAWN_X[hero] or 0,4,spotZ("Player",22))
 if practice then origin=D.practiceSpot(ring) end
 -- R65 (Peter: "sometimes the toon is below the ground"): stand the fighter on the real floor under its spot
 -- (a ray down from just above it), at its own standing height, instead of a fixed height of 4.
 do
  local h=model:FindFirstChildOfClass("Humanoid"); local r=model:FindFirstChild("HumanoidRootPart")
  local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.RespectCanCollide=true
  local skip={model}; for _,st in states do if typeof(st)=="table" and st.model then table.insert(skip,st.model) end end
  params.FilterDescendantsInstances=skip
  local hit=workspace:Raycast(Vector3.new(origin.X,14,origin.Z),Vector3.new(0,-60,0),params)
  if hit and h and r then origin=Vector3.new(origin.X,hit.Position.Y+h.HipHeight+r.Size.Y/2+0.3,origin.Z) end
 end
 model:PivotTo(CFrame.lookAt(origin,Vector3.new(0,origin.Y,spotZ("Round",0))))
 local root=model.HumanoidRootPart; root:SetNetworkOwner(nil)
 model:SetAttribute("Skin",skinId)
 -- Fixed hurtbox: one invisible box around the standard R15 body, the only part attacks can find.
 -- Capes, pauldrons, trims and any future skin geometry are never queryable, so looks can't change hits.
 -- v18: the bounds come from the standard square body, whatever body this hero is wearing.
 local lo,hi=Appearance.standardBounds()
 -- v25: a bigger hero (Bulwark) is a bigger target; Scale grows the body and the hurtbox together.
 local scale=Rules.Characters[hero].Scale or 1
 lo*=scale; hi*=scale
 for _,p in model:GetDescendants() do if p:IsA("BasePart") then p.CanQuery=false end end
 local hurtbox=Instance.new("Part"); hurtbox.Name="Hurtbox"; hurtbox.Transparency=1; hurtbox.CanCollide=false
 hurtbox.CanTouch=false; hurtbox.CanQuery=true; hurtbox.Massless=true; hurtbox.CastShadow=false
 hurtbox.Size=hi-lo; hurtbox.CFrame=root.CFrame*CFrame.new((lo+hi)/2); hurtbox.Parent=model
 -- A classic Weld so the hurtbox can be resized and shifted per state (stand, crouch, air, down).
 local hw=Instance.new("Weld"); hw.Part0=root; hw.Part1=hurtbox; hw.C0=CFrame.new((lo+hi)/2); hw.Parent=hurtbox
 local a=Instance.new("Attachment"); a.Name="FlightAttachment"; a.Parent=root
 local velocity=Instance.new("LinearVelocity"); velocity.Name="FlightVelocity"; velocity.Attachment0=a
 velocity.RelativeTo=Enum.ActuatorRelativeTo.World; velocity.MaxForce=100000
 velocity.Enabled=false; velocity.Parent=root
 local s={player=player,model=model,root=root,hum=model:FindFirstChildOfClass("Humanoid"),hero=hero,
  energy=100,flying=false,velocity=velocity,dir=Vector3.zero,aim=root.CFrame.LookVector,
  lastFlight=-600,lastCombat=-600,hitstop=0,lock=false,stunned=0,invulnerable=0,cooldowns={},combo=0,comboUntil=0,
  block=false,blockAt=-600,parryReady=0,action=nil,dashUntil=0,damage=0,hits=0,isDummy=isDummy,skin=skinId,
  receivedHits=0,chainExpires=0,blockHeld=false,blockStunned=false,fury=Rules.Fury.Start,gcd=0,shieldUntil=0,
  hurtbox=hurtbox,hurtWeld=hw,hurtBase={center=(lo+hi)/2,size=hi-lo},hurtState="Stand",history={},inputs={},owned=false,moveDebt=0,snaps=0}
 nextIndex+=1; s.index=nextIndex
 if practice then
  s.isPractice=true; s.practiceRing=ring; model:SetAttribute("Practice",true); model.Name="Practice dummy"
  -- Heals back to full after 6 s without being hit.
  local last=s.hum.Health
  s.hum.HealthChanged:Connect(function(h) if h<last then s.practiceHurtAt=os.clock() end; last=h end)
 end
 states[model]=s
 if player then states[player]=s; player.Character=model end
 if isDummy then dummy=s end
 -- R61 (Peter: "they lie down sometimes"): a fighter can't trip into Roblox's fall-over or ragdoll states.
 -- Knockdowns are animations, so nothing in the game needs those states; flight is untouched.
 for _,st in {Enum.HumanoidStateType.FallingDown,Enum.HumanoidStateType.Ragdoll} do s.hum:SetStateEnabled(st,false) end
 s.hum.Died:Connect(function()
  stopFlight(s); s.action=nil; s.block=false; s.blockHeld=false
  model:SetAttribute("Blocking",false); model:SetAttribute("Flying",false); model:SetAttribute("Shielded",false)
  task.delay(3,function()
   if player and player.Parent and states[player]==s then
    local ok,err=pcall(spawnFighter,player,hero,false,skinId); if not ok then warn(err) end
   elseif practice and states[model]==s then
    states[model]=nil; model:Destroy()
    if D.rings()[ring] then local ok,err=pcall(spawnFighter,nil,hero,"practice",nil,ring); if not ok then warn(err) end end
   elseif isDummy and states[model]==s then
    states[model]=nil; model:Destroy()
    local ok,err=pcall(spawnFighter,nil,hero,true); if not ok then warn(err) end
   end
  end)
 end)
 return s
end
local function clearSight(s,target)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={s.model}
 local delta=target.root.Position-s.root.Position
 local result=workspace:Raycast(s.root.Position,delta,params)
 return not result or result.Instance:IsDescendantOf(target.model)
end
local function facingTarget(target,s)
 local delta=s.root.Position-target.root.Position
 return delta.Magnitude<0.01 or target.root.CFrame.LookVector:Dot(delta.Unit)>0.25
end
local function flatUnit(v,fallback)
 local f=Vector3.new(v.X,0,v.Z)
 return f.Magnitude>0.01 and f.Unit or fallback
end
local slideParams=RaycastParams.new(); slideParams.FilterType=Enum.RaycastFilterType.Exclude
-- Move a fighter by a small horizontal step, stopping short of walls and other fighters.
local function slide(s,delta)
 if delta.Magnitude<0.001 then return true end
 slideParams.FilterDescendantsInstances={s.model}
 local hit=workspace:Raycast(s.root.Position,delta.Unit*(delta.Magnitude+1.2),slideParams)
 if hit then
  local allowed=math.max(0,hit.Distance-1.2)
  if allowed<0.01 then return false end
  delta=delta.Unit*allowed
 end
 s.root.CFrame=s.root.CFrame+delta
 return not hit
end
local function standHeight(s) return s.hum.HipHeight+s.root.Size.Y/2 end
-- v30 step C: client-owned movement. A player's own client moves their fighter (walking, jumping,
-- facing, dash, lunge, flight) while nothing is forcing it, so none of that waits on ping. The server
-- takes movement back for stuns, knockback, pulls, carries, whirls, leaps, teleports and the countdown,
-- and checks every step the client makes, snapping it back if it went somewhere it couldn't.
local groundParams=RaycastParams.new(); groundParams.FilterType=Enum.RaycastFilterType.Exclude
groundParams.RespectCanCollide=true
local function groundY(s,at)
 groundParams.FilterDescendantsInstances={s.model}
 local p=at or s.root.Position
 local hit=workspace:Raycast(p,Vector3.new(0,-300,0),groundParams)
 return hit and hit.Position.Y or 0
end
local function heightAboveGround(s) return s.root.Position.Y-groundY(s)-standHeight(s) end
local function pingTicks(s)
 local ok,ping=pcall(function() return s.player:GetNetworkPing() end)
 return math.floor((ok and ping or 0.1)*120+0.5) -- round trip, in ticks
end
-- After the server moves a client-owned fighter, tell its client too, and ignore the old positions
-- still on their way in.
local function syncOwner(s)
 if not s.owned then return end
 remote:FireClient(s.player,"Snap",s.root.CFrame)
 local p=s.root.Position
 s.lastGood=p; s.lastPos=p; s.moveDebt=0; s.snapGrace=tick+pingTicks(s)+6; s.airGrace=tick+Rules.Net.AirGrace
end
local function placeAt(s,cf)
 s.root.CFrame=cf; s.root.AssemblyLinearVelocity=Vector3.zero
 syncOwner(s)
end
local function setOwner(s,client)
 if s.owned==client or not s.player or s.root.Anchored then return end
 local ok=pcall(function() s.root:SetNetworkOwner(client and s.player or nil) end)
 if not ok then return end
 s.owned=client; s.model:SetAttribute("ClientMove",client)
 local p=s.root.Position
 s.lastGood=p; s.lastPos=p; s.moveDebt=0; s.speedHist={}
 if client then s.airGrace=tick+Rules.Net.AirGrace; s.snapGrace=tick+pingTicks(s)+6
 else s.hum.AutoRotate=true end
end
local function snapBack(s,toGround)
 local p=s.lastGood or s.root.Position
 if toGround then p=Vector3.new(p.X,groundY(s,p)+standHeight(s),p.Z) end
 s.snaps+=1
 placeAt(s,CFrame.new(p)*s.root.CFrame.Rotation)
end
local function checkMove(s,locked,frozen,held)
 local p=s.root.Position
 local last=s.lastPos or p; s.lastPos=p
 if tick<(s.snapGrace or 0) then s.lastGood=p; s.moveDebt=0; return end
 local c=Rules.Characters[s.hero]
 local allowed=(locked or frozen or held) and 0 or s.flying and math.sqrt(Rules.Flight.Speed^2+Rules.Flight.TakeoffRise^2) or c.Speed*(tick<(s.speedUntil or 0) and s.speedScale or 1)*(1+Rules.Bulwark.StackSpeed*(s.jugg or 0))
 if tick<s.dashUntil+6 then allowed=math.max(allowed,c.DashSpeed) end
 local a=s.action
 if a and a.move.Lunge and a.frame<=a.move.Startup+2 then allowed+=a.move.Lunge*60/a.move.Startup end
 -- A slow-down or stop reaches the client a round trip later, so the fastest speed allowed lately counts.
 local hist=s.speedHist or {}; s.speedHist=hist
 hist[tick%60+1]=allowed
 local best=allowed
 for i=1,math.clamp(pingTicks(s)+Rules.Net.GraceTicks,6,59) do
  local v=hist[(tick-i)%60+1]; if v and v>best then best=v end
 end
 local delta=p-last
 local moved=s.flying and delta.Magnitude or Vector3.new(delta.X,0,delta.Z).Magnitude
 local debt,over=Rules.moveCheck(s.moveDebt or 0,moved,best)
 s.moveDebt=debt
 if over then snapBack(s,false); return end
 if debt==0 then s.lastGood=p end
 -- Without flight or a leap, a jump tops out about 5 studs up.
 -- (Flight ending reaches the client late, so a flyer may still be rising for a moment after.)
 if not s.flying and delta.Y>0.05 and tick>=(s.airGrace or 0) and tick>=(s.leapTop or 0)
  and tick-s.lastFlight>pingTicks(s)+Rules.Net.GraceTicks+Rules.Net.AirGrace and heightAboveGround(s)>D.jumpRise(s)
  and not (Rules.Climb[s.hero] and Rules.Climb[s.hero].Wall and D.Climb and D.Climb.onWall(s.model,s.root)) then
  snapBack(s,true)
 end
end
-- Pounce homes on the nearest fighter close to the committed aim.
local function pounceTarget(s,aim,move)
 local best,bestDist
 for key,t in states do
  if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) then
   local delta=t.root.Position-s.root.Position; local dist=delta.Magnitude
   if dist>0.5 and dist<=move.Leap+4 and aim:Dot(delta.Unit)>0.85 and (not bestDist or dist<bestDist) and clearSight(s,t) then
    best,bestDist=t,dist
   end
  end
 end
 return best
end
local function pounceLanding(s,a)
 local pos=s.root.Position; local move=a.move
 local t=a.target; local goal
 if t and alive(t) then
  local tp=t.root.Position
  goal=tp-flatUnit(tp-pos,s.root.CFrame.LookVector)*1.8
 else
  local flat=flatUnit(a.aim,s.root.CFrame.LookVector)
  local reach=16
  local wall=workspace:Raycast(pos,flat*reach,slideParams)
  if wall then reach=math.max(0,wall.Distance-1.5) end
  local probe=pos+flat*reach
  local floor=workspace:Raycast(probe+Vector3.new(0,2,0),Vector3.new(0,-80,0),slideParams)
  goal=Vector3.new(probe.X,(floor and floor.Position.Y or 0)+standHeight(s),probe.Z)
 end
 local delta=goal-pos
 if delta.Magnitude>move.Leap then goal=pos+delta.Unit*move.Leap end
 return goal
end
-- Hurtboxes (step E) ---------------------------------------------------------------
-- Plain-number box for Rules.boxesOverlap.
local function toBox(cf,size)
 local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
 return {p={cf.X,cf.Y,cf.Z},a={{r.X,r.Y,r.Z},{u.X,u.Y,u.Z},{l.X,l.Y,l.Z}},h={size.X/2,size.Y/2,size.Z/2}}
end
local teleportTarget, endInvisible
local function hurtState(s)
 if tick<(s.downUntil or 0) then return "Down" end
 local a=s.action
 if a and a.name=="Pounce" and Rules.phase(a.move,a.frame,a.extra)=="Startup" then return "Crouch" end
 if s.flying or s.hum.FloorMaterial==Enum.Material.Air then return "Air" end
 return "Stand"
end
local function hurtboxFor(s,state)
 local sc=Rules.HurtboxStates[state]; local base=s.hurtBase
 local size=base.size*Vector3.new(sc.Scale[1],sc.Scale[2],sc.Scale[3])
 local center=base.center+Vector3.new(0,sc.Shift*base.size.Y,0)
 return s.root.CFrame*CFrame.new(center),size,center
end
-- The attacking arm/leg is hittable while a melee move is Active or recovering (whiff punishes).
local function limbFor(s)
 local a=s.action
 if not a or not Rules.isMelee(a.name) or a.name=="Pounce" then return nil end
 local phase=Rules.phase(a.move,a.frame,a.extra)
 if phase~="Active" and phase~="Recovery" then return nil end
 local depth=a.move.Range*Rules.Limb.Depth
 local flat=Vector3.new(a.aim.X,0,a.aim.Z); if flat.Magnitude<0.01 then flat=s.root.CFrame.LookVector end
 local cf=CFrame.lookAt(s.root.Position,s.root.Position+flat)*CFrame.new(0,0.3,-(s.hurtBase.size.Z/2+depth/2))
 return cf,Vector3.new(Rules.Limb.Width,Rules.Limb.Height,depth)
end
-- Record every fighter's boxes each tick so a player's hits can be checked against where the
-- target was on that player's screen (lag compensation, capped by Rules.Rewind).
local function recordHurtbox(s)
 local state=hurtState(s)
 local cf,size,center=hurtboxFor(s,state)
 if state~=s.hurtState then
  s.hurtState=state; s.hurtbox.Size=size; s.hurtWeld.C0=CFrame.new(center)
  s.model:SetAttribute("HurtState",state)
 end
 local limbCf,limbSize=limbFor(s)
 s.history[tick%Rules.Rewind.HistoryTicks+1]={tick=tick,body=toBox(cf,size),pos=cf.Position,
  limb=limbCf and toBox(limbCf,limbSize) or nil}
end
-- The target's boxes `back` ticks ago (or the closest newer record we still have).
local function snapshot(t,back)
 local want=tick-back
 for i=0,back do
  local h=t.history[(want+i)%Rules.Rewind.HistoryTicks+1]
  if h and h.tick==want+i then return h end
 end
 local cf,size=hurtboxFor(t,hurtState(t))
 local limbCf,limbSize=limbFor(t)
 return {tick=tick,body=toBox(cf,size),pos=cf.Position,limb=limbCf and toBox(limbCf,limbSize) or nil}
end
-- Contacts found this tick are applied together after every fighter has moved (step A),
-- so two attacks that land on the same tick trade instead of the first cancelling the second.
local contacts={}
local function queueContact(s,a,t,scale,stunOverride,splash)
 if not foe(s,t) then return end -- R63: nobody can hit into someone else's duel
 -- Counter-hit is judged on the state at contact, before any of this tick's hits are applied.
 local counter=t.action~=nil and Rules.phase(t.action.move,t.action.frame,t.action.extra)=="Startup"
 a.pending=true
 table.insert(contacts,{s=s,a=a,t=t,scale=scale,stun=stunOverride,splash=splash,counter=counter})
end
-- v28 Vanish / Shrouded / Solar Flare reveal ---------------------------------------------------------
local function inShadow(s)
 local p=s.root.Position
 if p.Y>8 then return false end
 for _,z in shadowZones do
  if math.abs(p.X-z.center.X)<=z.half and math.abs(p.Z-z.center.Z)<=z.half then return true end
 end
 return false
end
local function updateSneak(s)
 local hidden=tick>=(s.revealedUntil or 0) and (s.model:GetAttribute("Invisible")==true or inShadow(s))
 s.sneak=Rules.updateSneak(s.sneak,s.hero,hidden,tick)
end
endInvisible=function(s)
 updateSneak(s) -- capture genuine hiding before an attack, hit or reveal ends it
 if tick<(s.phaseUntil or 0) then return end -- R49 Phase: nothing reveals him until its timer ends
 if (s.invisibleUntil or 0)>tick then s.invisibleUntil=tick end
 s.shadowUntil=nil
 if s.model:GetAttribute("ShadowForm") then s.model:SetAttribute("ShadowForm",false) end
 if s.model:GetAttribute("Invisible") then s.model:SetAttribute("Invisible",false) end
 updateSneak(s)
end
-- The nearest other fighter roughly ahead (along the aim) between MinRange and Range.
teleportTarget=function(s,move)
 local best,bestDist
 for key,t in states do
  if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) then
   local delta=t.root.Position-s.root.Position; local dist=delta.Magnitude
   -- v29: a vanished fighter can't be door-stepped (unless a Solar Flare lit them up).
   local hidden=t.model:GetAttribute("Invisible") and (t.model:GetAttribute("RevealEnd") or 0)<=workspace:GetServerTimeNow()
   if not hidden and dist>=move.MinRange and dist<=move.Range and s.aim:Dot(delta.Unit)>0.6 and (not bestDist or dist<bestDist) then
    best,bestDist=t,dist
   end
  end
 end
 return best
end
-- A free spot on the ring round the target: straight behind it first, then working round both ways.
local function doorSpot(s,t,move)
 local back=-flatUnit(t.root.CFrame.LookVector,Vector3.new(0,0,1))
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={s.model,t.model}
 for _,deg in {0,45,-45,90,-90,135,-135,180} do
  local dir=CFrame.fromAxisAngle(Vector3.yAxis,math.rad(deg)):VectorToWorldSpace(back)
  local spot=t.root.Position+dir*move.Ring
  local blocked=workspace:Raycast(t.root.Position,dir*(move.Ring+1.5),params)
  if not blocked and math.abs(spot.X)<85 and math.abs(spot.Z)<85 then return spot end
 end
 return nil
end
local function startAttack(s,input,quiet)
 if not alive(s) or s.block then return "fail" end
 if s.action or tick<s.stunned or tick<s.dashUntil then return "wait" end
 local combo=tick<=s.comboUntil and s.combo%3+1 or 1
 local name=Rules.moveName(s.hero,input,combo)
 if input=="Light" and tick<(s.phaseUntil or 0) then name="ShadeBolt" end -- R49: phased, the combo key shoots
 local move=name and Rules.heroMove(s.hero,name)
 if not move then return "fail" end
 -- v27: Bulwark's Charge aimed up at someone in the air becomes a leap (same cooldown and Fury).
 local leapUp=name=="Charge" and s.aim.Y>=Rules.Moves.ChargeLeap.AirAim
 if leapUp then move=Rules.Moves.ChargeLeap end
 -- Pressed just before a cooldown or the GCD ends: hold it and fire the moment it's ready.
 local readyAt=math.max(s.cooldowns[name] or 0,move.Cost and s.gcd or 0)
 if tick<readyAt then return readyAt-tick<=Rules.BufferFrames and "wait" or "fail" end
 -- v28 teleports need a target at medium range in front of you (checked before any Fury is spent).
 local doorTarget
 if move.Teleport then
  doorTarget=teleportTarget(s,move)
  if not doorTarget then
   if not quiet then notify(s.player,string.format("%s needs a target %d-%d studs away",Rules.title(s.hero,name),move.MinRange,move.Range)) end
   return "fail"
  end
 end
 -- v49 super: needs a full Super meter, which it empties. Checked before anything else is spent.
 if move.Super then
  if (s.super or 0)<Rules.Super.Max then
   if not quiet then notify(s.player,string.format("%s needs a full Super meter (%d%%)",Rules.title(s.hero,name),math.floor((s.super or 0)/Rules.Super.Max*100))) end
   return "fail"
  end
 end
 if move.Cost then
  -- Fury-costing moves share a global cooldown, WoW style.
  if s.fury<move.Cost then
   if not quiet then notify(s.player,string.format("Not enough Fury for %s (%d needed)",name,move.Cost)) end
   return "fail"
  end
  s.fury-=move.Cost; s.gcd=tick+Rules.GCD
 end
 if name=="Light1" or name=="Light2" or name=="Light3" then s.combo=combo; s.comboUntil=tick+45 else s.combo=0 end
 local cooldown=move.Cooldown
 if move.RampStep then
  -- R45 ramping cooldown: each cast soon after the last one waits longer, up to RampMax.
  s.ramp=s.ramp or {}
  local uses=tick<(s.cooldowns[name] or 0)+move.RampReset and (s.ramp[name] or 0) or 0
  cooldown=math.min(move.RampMax,move.Cooldown+uses*move.RampStep); s.ramp[name]=uses+1
 end
 s.cooldowns[name]=tick+cooldown; s.lastCombat=tick; s.recoverBy=nil
 s.action={name=name,move=move,frame=0,hit={},aim=s.aim,confirmed=false,extra=0,leapUp=leapUp,target=doorTarget}
 if move.Super then
  -- Untouchable through the wind-up; every screen flashes and freezes for a moment (SF super flash).
  s.super=0; s.invulnerable=math.max(s.invulnerable,tick+move.Startup)
  remote:FireAllClients("Fx",s.model,"Super",Rules.title(s.hero,name))
 end
 endInvisible(s) -- attacking gives you away
 s.hum.AutoRotate=false
 local flat=Vector3.new(s.aim.X,0,s.aim.Z)
 if flat.Magnitude>0.01 and not s.owned then s.root.CFrame=CFrame.lookAt(s.root.Position,s.root.Position+flat) end
 local landing
 if name=="Pounce" then
  slideParams.FilterDescendantsInstances={s.model}
  s.action.target=pounceTarget(s,s.aim,move)
  landing=pounceLanding(s,s.action)
 end
 -- v36: the server time it started, so other screens can start it in step.
 remote:FireAllClients("Attack",s.model,name,s.action.aim,landing,workspace:GetServerTimeNow())
 return "ok"
end
-- Per-round hit log for balance telemetry (printed to Output when a round ends).
local roundLog=nil
-- R41 Solar Shield: soaks damage until its points run out, then burns off. Returns what gets through.
local function soak(t,dmg)
 if dmg>0 and tick<(t.mistUntil or 0) then dmg*=(t.mistScale or 1) end -- R47 Tempest's mist (ticks)
 if dmg<=0 or tick>=(t.absorbUntil or t.shieldUntil or 0) or (t.shieldHP or 0)<=0 then return dmg end
 local took=math.min(dmg,t.shieldHP); t.shieldHP-=took
 if t.shieldHP<=0 then
  t.shieldHP=nil; t.shieldUntil=tick; t.absorbUntil=nil; t.model:SetAttribute("ShieldHP",nil)
  remote:FireAllClients("Fx",t.model,"ShieldBreak",t.root.Position)
 else t.model:SetAttribute("ShieldHP",math.ceil(t.shieldHP)) end
 return dmg-took
end
-- One contact: damage, hit-stop for both fighters, hitstun, knockback and counter-hits.
local function applyHit(s,a,t,scale,stunOverride,splash,counter)
 local move=a.move
 local base=(move.AirDamage and s.flying) and move.AirDamage or move.Damage
 local damage=base*(scale or 1)
 local sweet=false
 if move.SweetSpot and (t.root.Position-s.root.Position).Magnitude>=move.Range-move.SweetSpot then damage*=1.25; sweet=true end
  if counter then damage*=Rules.CounterDamage end
 local zone=s.shadowCircle
 if s.hero=="Wraithstep" and zone and tick<zone.expires and zone.visual.Parent then
  local delta=t.root.Position-zone.center
  if Vector3.new(delta.X,0,delta.Z).Magnitude<=zone.radius and math.abs(delta.Y)<=6 then damage*=zone.mult or 1.5 end
 end
 if s.hero=="Bulwark" and (s.jugg or 0)>0 then damage*=1+Rules.Bulwark.StackDamage*s.jugg end -- R36 Juggernaut
 if tick<(t.shieldUntil or 0) then damage*=(Rules.Defensives[t.hero].DamageScale or 1) end
 if tick<(t.mistUntil or 0) then damage*=(t.mistScale or 1) end -- R47 Tempest's mist cloud
 damage=math.floor(damage+0.5)
 local result
 -- v48 Shield Parry: a blow inside Bulwark's window is parried from any side.
 local parried=tick<(t.parryUntil or 0) and not move.Throw
 local rawDamage=damage -- R52: Bulwark's parry heal is a share of the blow he turned away
 damage,result=Rules.defend(damage,t.block or parried,parried or facingTarget(t,s),parried or tick-t.blockAt<Rules.ParryFrames,move.BreaksGuard,tick<t.invulnerable,move.Throw)
 if result=="Hit" and counter then result="Counter" end
 updateSneak(s)
 local sneakBonus
 damage,sneakBonus=Rules.sneakDamage(s.sneak,s.hero,tick,damage,result)
 -- R41: a blow the Solar Shield soaks completely does nothing else (no stun, push or interrupt).
 if damage>0 and (t.shieldHP or 0)>0 then
  damage=soak(t,damage)
  if damage<=0 then damage=0; result="Absorb" end
 end
 -- v49 interrupt: a hit on someone casting locks the move they were casting (WoW school lockout).
 local cast=t.action
 if Rules.canInterrupt(move,cast and cast.move,cast and cast.frame or 0,damage,result) then
  t.cooldowns[cast.name]=math.max(t.cooldowns[cast.name] or 0,tick+move.Lockout)
  local castTitle=Rules.title(t.hero,cast.name)
  notify(t.player,string.format("Interrupted! %s locked for %ds",castTitle,move.Lockout/60))
  notify(s.player,string.format("Interrupted %s • locked for %ds",castTitle,move.Lockout/60))
  remote:FireAllClients("Fx",t.model,"Interrupted",castTitle)
 end
 s.lastCombat=tick; t.lastCombat=tick
 if result=="Parry" then
  s.stunned=tick+24; s.action=nil; stopFlight(s)
  local pd=Rules.Defensives[t.hero]
  if parried and pd and pd.Kind=="Parry" then
   s.stunned=tick+pd.Stun; s.buffer=nil
   -- R54 (Peter): the shield stays up for the whole window and turns away every blow in it.
   local first=not t.parryLanded; t.parryLanded=true
   if pd.Reflect==nil then t.parryUntil=0; t.shieldUntil=0 end
   if first and pd.OnSuccess and pd.Absorb then
    -- R53: the burn-off shield and the heal window start only when a parry lands.
    t.shieldHP=pd.Absorb; t.absorbUntil=tick+pd.AbsorbTicks; t.model:SetAttribute("ShieldHP",pd.Absorb)
    t.healUntil=tick+(pd.HealTicks or 0); t.healPct=pd.HealPct or 0
   end
   if tick<(t.healUntil or 0) and rawDamage>0 then
    local heal=rawDamage*(t.healPct or 0)
    t.hum.Health=math.min(t.hum.MaxHealth,t.hum.Health+heal)
    remote:FireAllClients("Fx",t.model,"Heal",t.root.Position,heal)
   end
   if first then
    t.cooldowns.Defensive=math.min(t.cooldowns.Defensive or 0,tick+pd.SuccessCooldown)
    t.fury=math.min(Rules.Fury.Max,t.fury+(pd.Fury or 0))
   end
   -- R36 riposte: the parry bashes back at once and Charge is ready again.
   -- R54 (Peter): it reflects the blow itself back at whoever threw it, near or far, for its full damage.
   if t.hero=="Bulwark" and alive(s) then
    local rd=pd.Reflect and math.max(1,math.floor(rawDamage*pd.Reflect+0.5)) or Rules.Bulwark.RiposteDamage
    s.hum:TakeDamage(rd); t.damage+=rd; t.hits+=1; s.lastHurt=tick; endInvisible(s)
    t.cooldowns.Charge=0; t.cooldowns.ChargeLeap=0
    remote:FireAllClients("Fx",t.model,"Riposte",s.root.Position,rd,s.model)
   end
   notify(t.player,string.format("Parried! %s reflected • %s ready in %ds",Rules.title(s.hero,a.name),pd.Name,pd.SuccessCooldown/60))
   notify(s.player,string.format("Parried by %s",pd.Name))
  end
 end
 local stop=0; local knockdown=false; local armored=false
 if damage>0 then
  stop=(move.HitStop or 0)+(sweet and 3 or 0)
  if result=="Block" or splash then stop=math.ceil(stop/2) end
  t.hum:TakeDamage(damage); s.damage+=damage; s.hits+=1; a.confirmed=true
  t.lastHurt=tick; if result~="Block" then endInvisible(t) end
  -- Cancel bookkeeping (step B): contact = hit or block; anyHit = at least one unblocked hit.
  a.contact=true; if result~="Block" then a.anyHit=true end
  if not splash then a.direct=true end
  -- R36 super armour (Bulwark's Charge): hits still hurt but don't stop him.
  local ta=t.action
  armored=ta~=nil and ta.move.Armor==true and result~="Block" and result~="Parry" and Rules.phase(ta.move,ta.frame,ta.extra)~="Recovery"
  if not armored then t.action=nil end
  if result~="Block" then s.fury=math.min(Rules.Fury.Max,s.fury+(move.Fury or 0)) end
  t.fury=math.min(Rules.Fury.Max,t.fury+damage*Rules.Fury.PerDamageTaken)
  -- v49 Super meter: from damage dealt and taken (a super itself builds none).
  if not move.Super then s.super=math.min(Rules.Super.Max,(s.super or 0)+damage*Rules.Super.PerDamageDealt) end
  t.super=math.min(Rules.Super.Max,(t.super or 0)+damage*Rules.Super.PerDamageTaken)
  local stun=stunOverride or move.Stun
  -- R35 Bulwark's holy Earth Slam: a chance of a long stun.
  if move.StunChance and result~="Block" and math.random()<move.StunChance then stun=math.max(stun,move.ChanceStun) end
  -- Grapple (v23): caught mid-jump (not flying) is the longer stun.
  if move.JumpStun and result~="Block" and not t.flying and t.hum.FloorMaterial==Enum.Material.Air then stun=move.JumpStun end
  if result=="Counter" and stun<60 then stun=math.floor(stun*Rules.CounterStun) end
  -- Stun diminishing returns (v27): repeat long stuns within 18 s get shorter, then immune.
  if result~="Block" and stun>=Rules.StunDR.Min then
   -- R53: roots (Snare) and cyclones (Whirlwind) have their own DR counts.
   local g=Rules.drGroup(move); t.dr=t.dr or {}
   local dr=t.dr[g]; if not dr or tick>dr.untilTick then dr={count=0,untilTick=0}; t.dr[g]=dr end
   local immune
   stun,immune=Rules.drStun(stun,dr.count)
   dr.count+=1; dr.untilTick=tick+Rules.StunDR.Reset
   if immune then notify(t.player,"Stun immune (diminishing returns)"); notify(s.player,"Target is stun immune for now") end
  end
  -- Long stuns show a countdown over the victim (v23).
  if result~="Block" and stun>=60 then t.model:SetAttribute("StunEnd",workspace:GetServerTimeNow()+(stop+stun)/60) end
  t.stunned=tick+stop+(result=="Block" and (move.BlockStun or 6) or stun)
  t.blockStunned=result=="Block"
  t.hitstop=tick+stop; s.hitstop=math.max(s.hitstop or 0,tick+stop)
  if result~="Block" then
   t.block=false
   t.receivedHits=tick<=t.chainExpires and t.receivedHits+1 or 1; t.chainExpires=math.max(tick+Rules.ChainWindow,t.stunned+Rules.ChainAfterStun)
   if t.receivedHits>=Rules.ChainHits and not move.Whirl then -- R42: a whirl is never swallowed by a chain knockdown
    -- Third hit: knockdown. The victim can't be hit until they stand; the attacker recovers first.
    knockdown=true
    t.stunned=tick+stop+Rules.Knockdown; t.invulnerable=t.stunned; t.downUntil=t.stunned; t.receivedHits=0; t.pull=nil
    if s.action==a then s.recoverBy=tick+stop+Rules.Knockdown-Rules.KnockdownAdvantage end
   end
  end
  if move.Grounding and result~="Block" then
   stopFlight(t)
   if move.Pull and not knockdown then
    -- Reel the target in to land just in front of the attacker.
    local front=flatUnit(t.root.Position-s.root.Position,s.root.CFrame.LookVector)
    local spot=s.root.Position+front*move.Pull
    slideParams.FilterDescendantsInstances={t.model,s.model}
    local floor=workspace:Raycast(spot+Vector3.new(0,3,0),Vector3.new(0,-60,0),slideParams)
    local y=(floor and floor.Position.Y or s.root.Position.Y-standHeight(s))+standHeight(t)
    t.pull={from=t.root.Position,to=Vector3.new(spot.X,y,spot.Z),start=tick+stop,ticks=12}
   else
    setOwner(t,false) -- v30: the server slams it down, so the server must own it
    t.root.AssemblyLinearVelocity=Vector3.new(0,-55,0)
   end
  end
  local push=(move.Push or 0)*(result=="Block" and 0.5 or 1)*(splash and 0.5 or 1)
  if splash then push=3 end
  if push>0 then
   t.knock={dir=flatUnit(t.root.Position-s.root.Position,flatUnit(a.aim,s.root.CFrame.LookVector)),push=push,start=tick+stop}
  end
  if move.Lift and result~="Block" then t.launch={at=tick+stop,speed=move.Lift} end
  if move.Whirl and result~="Block" and not knockdown then
   -- v29 Whirlwind: lifted and spun until the stun ends, untouchable meanwhile (WoW Cyclone).
   t.invulnerable=math.max(t.invulnerable,t.stunned); t.receivedHits=0
   t.knock=nil; t.pull=nil; t.launch=nil; stopFlight(t)
   t.whirl={base=t.root.Position,start=tick+stop,ends=t.stunned,height=move.WhirlHeight}
   t.model:SetAttribute("Whirl",true)
  end
  if move.Carry and result=="Throw" then
   -- v28 Titan Drop: always a knockdown. Both rise and come down together, the victim head first.
   knockdown=true
   t.stunned=tick+stop+move.Carry+Rules.Knockdown; t.invulnerable=t.stunned; t.downUntil=t.stunned; t.receivedHits=0
   t.knock=nil; t.pull=nil; t.launch=nil; stopFlight(t); stopFlight(s)
   if s.action==a then a.extra=move.Carry end
   local front=flatUnit(t.root.Position-s.root.Position,s.root.CFrame.LookVector)
   local yaw=s.root.CFrame.Rotation
   s.carry={from=s.root.Position,to=s.root.Position,start=tick+stop,ticks=move.Carry,height=move.CarryHeight,rot=yaw,up=yaw}
   t.carry={from=t.root.Position,to=s.root.Position+front*2.2+Vector3.new(0,t.root.Position.Y-s.root.Position.Y,0),
    start=tick+stop,ticks=move.Carry,height=move.CarryHeight+2.5,rot=yaw*CFrame.Angles(math.pi,0,0),up=yaw*CFrame.Angles(0,math.pi,0),land=true,by=s.model}
  end
 end
 if armored then
  -- R36: shrug it off. No stun, no push, no knockdown; Charge keeps going.
  t.stunned=math.min(t.stunned,tick+stop); t.knock=nil; t.pull=nil; t.launch=nil; t.receivedHits=0
  if knockdown then knockdown=false; t.invulnerable=tick; t.downUntil=tick end
  if t.whirl then t.whirl=nil; t.model:SetAttribute("Whirl",false); t.invulnerable=tick end
  t.model:SetAttribute("StunEnd",nil)
  remote:FireAllClients("Fx",t.model,"Armor",t.root.Position)
 end
 if damage>0 and move.Drain and result~="Block" and result~="Parry" then
  -- R38 Soul Drain: a damage-over-time that heals the attacker as it ticks.
  t.drain={by=s,dmg=move.Drain,every=move.DrainEvery,left=move.DrainTicks,ticks=move.DrainTicks,heal=move.DrainHeal or 1,nextAt=tick+stop+move.DrainEvery}
  t.model:SetAttribute("Drained",true)
 end
 if damage>0 and move.Snare and result~="Block" and result~="Parry" and alive(t) then
  -- R47 Lightning Snare: held in place where they stand (or hover) until the stun ends.
  t.snare={pos=t.root.Position,ends=t.stunned}; t.knock=nil; t.pull=nil; t.launch=nil
  t.model:SetAttribute("Snared",true)
  remote:FireAllClients("Fx",t.model,"Snare",t.root.Position,(t.stunned-tick)/60)
 end
 if damage>0 and tick<(s.healUntil or 0) and result~="Parry" and not Rules.Defensives[s.hero].HealOnParryOnly then
  -- R52: a hit Bulwark lands inside his parry heal window heals him a share of it.
  local heal=damage*(s.healPct or 0)
  s.hum.Health=math.min(s.hum.MaxHealth,s.hum.Health+heal)
  remote:FireAllClients("Fx",s.model,"Heal",s.root.Position,heal)
 end
 if damage>0 and move.Dot and result~="Block" and result~="Parry" then
  -- R49 Shade Bolt: one more shadow stack on the target; each ticks on its own and heals Wraithstep.
  -- R53: no stacking; a new bolt replaces the shadow tick that is running.
  if move.NoStack then t.dots={} else t.dots=t.dots or {} end
  -- R55: at most MaxStacks shadow stacks; the oldest one makes room for the new bolt.
  if move.MaxStacks then while #t.dots>=move.MaxStacks do table.remove(t.dots,1) end end
  table.insert(t.dots,{by=s,dmg=move.Dot,every=move.DotEvery,left=move.DotTicks,heal=move.DotHeal or 1,nextAt=tick+move.DotEvery})
  t.model:SetAttribute("ShadeStacks",#t.dots)
 end
 if damage>0 and move.Zap and result~="Block" and result~="Parry" then
  -- R41 Tempest: a lightning tick on the target and a heal stack for her.
  local Z=Rules.Tempest
  s.zapStacks=math.min(Z.StackMax,(s.zapStacks or 0)+1); s.zapUntil=tick+Z.StackTicks
  s.model:SetAttribute("ZapStacks",s.zapStacks)
  t.zap={by=s,left=move.ZapTicks or Z.ZapTicks,nextAt=tick+stop+Z.ZapEvery}
  t.model:SetAttribute("Zapped",true)
 end
 if damage>0 and s.hero=="Bulwark" and result~="Block" and result~="Parry" then
  -- R36 Juggernaut stacks.
  local B=Rules.Bulwark
  s.jugg=math.min(B.StackMax,(s.jugg or 0)+1); s.juggUntil=tick+B.StackTicks
  s.model:SetAttribute("Juggernaut",s.jugg)
  -- R36 wall splat: a ground Charge carries the target up to 12 studs and slams them into any wall.
  if a.name=="Charge" and not a.leapUp and a.move.Carry12 and not knockdown and not t.flying then
   local dir=flatUnit(t.root.Position-s.root.Position,flatUnit(a.aim,s.root.CFrame.LookVector))
   slideParams.FilterDescendantsInstances={t.model,s.model}
   local wall=workspace:Raycast(t.root.Position,dir*(a.move.Carry12+1.5),slideParams)
   local dist=wall and math.max(0,wall.Distance-1.5) or a.move.Carry12
   local to=t.root.Position+dir*dist
   t.knock=nil
   t.pull={from=t.root.Position,to=to,start=tick+stop,ticks=14}
   s.pull={from=s.root.Position,to=to-dir*2.6+Vector3.new(0,s.root.Position.Y-t.root.Position.Y,0),start=tick+stop,ticks=14}
   t.stunned=math.max(t.stunned,tick+stop+16)
   if wall then t.splat={at=tick+stop+14,by=s,pos=wall.Position} end
  end
 end
 if roundLog then
  table.insert(roundLog,{hero=s.hero,move=a.name,result=result,damage=damage,sneakBonus=sneakBonus,dist=(t.root.Position-s.root.Position).Magnitude})
 end
 remote:FireAllClients("Hit",t.model,result,damage,s.model,a.name,stop,sweet,knockdown,sneakBonus)
end
local function hitTargets(s,a)
 local move=a.move
 if move.Whirl or move.LockOn then
  -- R47: Lightning Snare locks on the same way (LockOn).
  -- R42 (Peter: "I don't see the whirlwind CC anyone"): the old 5-stud-wide line 60 studs long almost
  -- never landed. Whirlwind now locks on, like WoW's Cyclone: the nearest enemy within reach inside a
  -- Cone-degree wedge of the aim (flat, any height a flyer can reach) with a clear line of sight.
  if a.whirlDone then return end
  a.whirlDone=true
  local best,bestD
  local flatAim=flatUnit(a.aim,s.root.CFrame.LookVector); local cosCone=math.cos(math.rad(move.Cone or 25))
  for key,t in states do
   if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) and not a.hit[key] then
    local d=t.root.Position-s.root.Position
    local flat=Vector3.new(d.X,0,d.Z)
    local inCone=flat.Magnitude<4 or flat.Unit:Dot(flatAim)>=cosCone
    if d.Magnitude<=move.Range+3 and inCone and math.abs(d.Y)<=(move.ReachY or 40) and clearSight(s,t) and (not bestD or d.Magnitude<bestD) then
     best,bestD=key,d.Magnitude
    end
   end
  end
  local spot=best and states[best].root.Position or s.root.Position+flatAim*math.min(move.Range,30)
  remote:FireAllClients("Fx",s.model,move.Whirl and "WhirlCast" or move.Dot and "ShadeCast" or "SnareCast",spot,best~=nil)
  if best then
   a.hit[best]=true; queueContact(s,a,states[best])
   -- R47 (Peter: "the whirlwind needs to CC people"): everyone else near its target is caught too.
   if move.WhirlSplash then
    for key,t in states do
     if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) and not a.hit[key]
      and (t.root.Position-spot).Magnitude<=move.WhirlSplash then
      a.hit[key]=true; queueContact(s,a,t)
     end
    end
   end
  end
  return
 end
 local cf=CFrame.lookAt(s.root.Position,s.root.Position+a.aim)
 local center=cf*CFrame.new(0,0,-move.Range/2)
 local size=Vector3.new(move.Width,move.Height,move.Range)
 if move.Aoe then
  -- v28 Solar Flare: a burst all round the attacker.
  center=CFrame.new(s.root.Position); size=Vector3.new(move.Aoe*2,move.Height,move.Aoe*2)
 end
 if a.name=="Pounce" then
  -- Body hitbox that travels with the leap.
  center=s.root.CFrame; size=Vector3.new(move.Width,move.Height,move.Width)
 end
 -- Lag compensation: a player's attack is tested against targets where that player saw them.
 local back=s.player and Rules.rewindTicks(s.player:GetNetworkPing()) or 0
 local box=toBox(center,size)
 for key,t in states do
  if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) and not a.hit[key] then
   local snap=snapshot(t,back)
   local touched=Rules.boxesOverlap(box,snap.body) or (snap.limb~=nil and Rules.boxesOverlap(box,snap.limb))
   -- Reach is measured to the hurtbox, not the root, so it doesn't depend on the angle.
   local reach=(move.Aoe or move.Range)+math.max(t.hurtBase.size.X,t.hurtBase.size.Z)/2
   if touched and (snap.pos-s.root.Position).Magnitude<=reach
    and clearSight(s,t) and (not move.AirOnly or t.flying or t.hum.FloorMaterial==Enum.Material.Air)
    and (not move.Throw or (tick>=t.stunned and not t.flying and t.hum.FloorMaterial~=Enum.Material.Air)) then
    a.hit[key]=true
    queueContact(s,a,t)
   end
  end
 end
 if s.player then remote:FireClient(s.player,"Box",center,size) end
end
-- End of the leap: splash anyone close, then recover (slowly if nothing was hit).
local function pounceLand(s,a)
 local move=a.move; local pos=s.root.Position
 a.landed=true
 for key,t in states do
  if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) and not a.hit[key] then
   local d=t.root.Position-pos
   if Vector3.new(d.X,0,d.Z).Magnitude<=move.Splash and math.abs(d.Y)<5 then
    a.hit[key]=true; queueContact(s,a,t,0.5,12,true)
   end
  end
 end
 remote:FireAllClients("Fx",s.model,"PounceLand",pos,a.direct==true)
 a.frame=move.Startup+move.Active; a.recovering=true
 if not a.confirmed and not a.pending then a.extra=move.Whiff or 0; remote:FireAllClients("Whiff",s.model,a.name) end
end
local function pounceStep(s,a)
 local move=a.move
 slideParams.FilterDescendantsInstances={s.model}
 if not a.leap then
  stopFlight(s); s.hum.AutoRotate=false
  local from=s.root.Position; local to=pounceLanding(s,a)
  local dist=(to-from).Magnitude
  local grounded=s.hum.FloorMaterial~=Enum.Material.Air
  a.leap={from=from,to=to,ticks=math.clamp(math.floor(dist/45*60+0.5),10,move.Active),
   height=grounded and 4+dist*0.15 or 1.5,start=a.frame-1}
 end
 local l=a.leap
 if a.target and alive(a.target) then
  -- Light homing: the landing point drifts at most a quarter stud per tick toward the target.
  local drift=pounceLanding(s,a)-l.to
  if drift.Magnitude>0.25 then drift=drift.Unit*0.25 end
  l.to+=drift
 end
 local k=math.clamp((a.frame-l.start)/l.ticks,0,1)
 local p=l.from:Lerp(l.to,k)+Vector3.new(0,l.height*4*k*(1-k),0)
 local face=flatUnit(l.to-l.from,s.root.CFrame.LookVector)
 local step=p-s.root.Position
 local wall=step.Magnitude>0.01 and workspace:Raycast(s.root.Position,step,slideParams)
 if wall then
  -- Touching the floor ends the leap standing; a wall or fighter stops it just short.
  if wall.Normal.Y>0.7 then p=wall.Position+Vector3.new(0,standHeight(s),0) else p=wall.Position-step.Unit*1.2 end
  k=1
 end
 s.root.CFrame=CFrame.lookAt(p,p+face); s.root.AssemblyLinearVelocity=Vector3.zero
 hitTargets(s,a)
 if s.action==a and (a.direct or k>=1) then pounceLand(s,a) end
end
-- Bulwark's anti-air leap (v27): flies straight along the committed aim, stops on contact or a wall.
local function chargeLeapStep(s,a)
 local move=a.move
 if not a.leap then
  stopFlight(s); s.hum.AutoRotate=false
  slideParams.FilterDescendantsInstances={s.model}
  local from=s.root.Position; local reach=move.Leap
  local wall=workspace:Raycast(from,a.aim*reach,slideParams)
  if wall then reach=math.max(0,wall.Distance-2) end
  local to=from+a.aim*reach
  a.leap={from=from,to=Vector3.new(to.X,math.min(to.Y,TOP_HEIGHT),to.Z),start=a.frame-1}
  s.leapTop=tick+150 -- allowed above the normal ceiling until he has fallen back down
 end
 if not a.contact then
  local l=a.leap
  local k=math.clamp((a.frame-l.start)/move.Active,0,1)
  local p=l.from:Lerp(l.to,k)
  local face=flatUnit(l.to-l.from,s.root.CFrame.LookVector)
  s.root.CFrame=CFrame.lookAt(p,p+face); s.root.AssemblyLinearVelocity=Vector3.zero
 end
 hitTargets(s,a)
end
local validActions={Vote=true,Leaderboard=true,Coach=true,Progress=true,SaveProgress=true,Queue=true,Challenge=true,Accept=true,Block=true,Arena=true,Skill3=true,Interrupt=true,Super=true,BotHero=true,Skin=true,Pause=true,Restart=true,Defensive=true,Bot=true,Light=true,Heavy=true,Skill1=true,Skill2=true,Dash=true,Flight=true,Move=true,Select=true,Jump=true,LoadBinds=true,SaveBinds=true,Reload=true,Preview=true,PickSkin=true,StopFight=true,ResetFight=true}
-- Player keybindings persist in a DataStore. Unpublished places (or Studio without API access) just keep them for the session.
local DataStoreService=game:GetService("DataStoreService")
local bindStore
do
 local ok,store=pcall(function() return DataStoreService:GetDataStore("HeroWarsKeybinds") end)
 if ok then bindStore=store else warn("HeroWars keybindings will not be saved: "..tostring(store)) end
end
local bindIds={Interrupt=true,Super=true,Skill3=true,Pause=true,Restart=true,Defensive=true,Light=true,Heavy=true,Skill1=true,Skill2=true,Dash=true,Flight=true,Rise=true,Descend=true,Debug=true,Keybinds=true,TargetNext=true,MoveForward=true,MoveBack=true,MoveLeft=true,MoveRight=true,StrafeLeft=true,StrafeRight=true}
local function cleanBinds(data)
 if type(data)~="table" then return nil end
 local out={}
 for id,pair in data do
  if type(id)=="string" and bindIds[id] and type(pair)=="table" then
   local clean={}
   for i=1,2 do
    local k=pair[i]
    local ok=type(k)=="string" and #k<=24 and (k=="" or k=="MouseButton3" or k=="WheelUp" or k=="WheelDown" or pcall(function() return Enum.KeyCode[k] end))
    clean[i]=ok and k or ""
   end
   out[id]=clean
  end
 end
 return out
end
-- Defensive: Solarion's shield or Wraithstep's blink. Breaks stuns, like a WoW PvP trinket.
local function useDefensive(s)
 local def=Rules.Defensives[s.hero]
 if not def or tick<(s.cooldowns.Defensive or 0) or tick<(s.hitstop or 0) then return end
 s.cooldowns.Defensive=tick+def.Cooldown
 s.stunned=tick; s.action=nil; s.knock=nil; s.pull=nil; s.launch=nil; s.receivedHits=0; s.blockStunned=false
 -- v27 fix: getting up early ends the knockdown's invulnerability too (it used to carry on while you acted).
 if tick<(s.downUntil or 0) then s.downUntil=tick; s.invulnerable=math.min(s.invulnerable,tick) end
 if s.carry then s.carry=nil end
 s.model:SetAttribute("StunEnd",nil) -- v29: the stun countdown goes with the stun
 if s.whirl then
  -- R46 (Peter: "if you can get out, make it reduce the stun to half its time"): a defensive no longer
  -- frees you from Whirlwind; it cuts the spin that is left in half. The defensive itself still works.
  local w=s.whirl; w.ends=tick+math.ceil(math.max(0,w.ends-tick)/2)
  s.stunned=w.ends; s.invulnerable=math.max(s.invulnerable,w.ends)
  s.model:SetAttribute("StunEnd",workspace:GetServerTimeNow()+(w.ends-tick)/60)
  notify(s.player,"Whirlwind cut in half")
 end
 if def.Kind=="Shield" then
  s.shieldUntil=tick+def.Duration
  if def.Absorb then s.shieldHP=def.Absorb; s.model:SetAttribute("ShieldHP",def.Absorb) end
  remote:FireAllClients("Fx",s.model,"Shield",def.Duration/60)
 elseif def.Kind=="Parry" then
  -- v48: shield up for the window (Shielded draws his guard pose; no DamageScale, so no damage cut).
  s.parryUntil=tick+def.Window; s.shieldUntil=s.parryUntil; s.parryLanded=nil
  if def.Absorb and not def.OnSuccess then -- R52: plus a burn-off shield and a heal window (R53: on a landed parry instead)
   s.shieldHP=def.Absorb; s.absorbUntil=tick+def.AbsorbTicks; s.model:SetAttribute("ShieldHP",def.Absorb)
   s.healUntil=tick+(def.HealTicks or 0); s.healPct=def.HealPct or 0
  end
  remote:FireAllClients("Fx",s.model,"Parry",def.Window/60)
 elseif def.Kind=="Vanish" then
  -- v28: break the stun and disappear (unless a Solar Flare has lit him up).
  s.invulnerable=math.max(s.invulnerable,tick+def.Invulnerable)
  local revealed=tick<(s.revealedUntil or 0)
  -- v45: a shadow first, then invisible once the shadow time runs out (the tick loop switches it).
  if not revealed then
   local shadow=def.ShadowTime or 0
   s.shadowUntil=tick+shadow; s.invisibleUntil=tick+shadow+def.Duration
   if shadow>0 then s.model:SetAttribute("ShadowForm",true) else s.model:SetAttribute("Invisible",true) end
  end
  remote:FireAllClients("Fx",s.model,"Vanish",s.root.Position,revealed)
 else
  local from=s.root.Position
  local flat=Vector3.new(s.dir.X,0,s.dir.Z)
  local dir=flat.Magnitude>0.1 and flat.Unit or -flatUnit(s.aim,s.root.CFrame.LookVector)
  stopFlight(s); slide(s,dir*def.Distance); syncOwner(s)
  s.invulnerable=math.max(s.invulnerable,tick+def.Invulnerable)
  remote:FireAllClients("Fx",s.model,"ShadowStep",from)
 end
end
local function startDash(s)
 s.cooldowns.Dash=tick+90; s.dashUntil=tick+12; s.invulnerable=math.max(s.invulnerable,tick+6)
 local flat=Vector3.new(s.dir.X,0,s.dir.Z)
 s.dashDir=flat.Magnitude>0.1 and flat.Unit or s.root.CFrame.LookVector
 -- v30: the client dashed the moment it was pressed, so some of it may already have been counted.
 if s.owned then s.moveDebt=math.max(0,s.moveDebt-Rules.Characters[s.hero].DashSpeed*12/60) end
 remote:FireAllClients("Fx",s.model,"Dash")
end
-- One buffered press: "ok" = done, "wait" = keep it buffered and retry next tick, "fail" = drop it.
-- v35 (Peter: "remove the throw and block"): neither is an action any more; defence is dodging, Defensives
-- and spacing (WoW style). The server ignores Block and Throw presses from older clients.
local BUFFERED={Light=true,Heavy=true,Skill1=true,Skill2=true,Skill3=true,Interrupt=true,Super=true,Dash=true,Defensive=true}
-- v30 step D: every press carries a number from the client, and the server answers each one, accepted
-- or refused, with its tick. A refused press fades out on the presser's screen instead of playing out.
local function ack(s,seq,accepted)
 if not seq or not s.player then return end
 -- v36: also which move started (the client corrects its combo guess) and how long the press waited.
 local at=s.pressAt and s.pressAt[seq]; if at then s.pressAt[seq]=nil end
 remote:FireClient(s.player,"Ack",seq,accepted,tick,accepted and s.action and s.action.name or nil,at and math.max(0,tick-at) or 0)
end
local function tryInput(s,input,quiet)
 if not Rules.actionAvailable(s.hero,input) then return "fail" end
 if tick<(s.holdUntil or 0) then return "wait" end
 if input=="Defensive" then
  -- Works out of stun (a stun breaker); waits only for hit-stop or a cooldown that is nearly up.
  local readyAt=s.cooldowns.Defensive or 0
  if tick<(s.hitstop or 0) then return "wait" end
  if tick<readyAt then return readyAt-tick<=Rules.BufferFrames and "wait" or "fail" end
  useDefensive(s); return "ok"
 end
 -- v48: nothing else starts while Bulwark's parry shield is up (it is held until the window ends).
 if tick<(s.parryUntil or 0) then return "wait" end
 local busy=s.action or tick<s.stunned or tick<s.dashUntil or tick<(s.hitstop or 0)
 if input=="Dash" then
  if busy then return "wait" end
  if s.flying or s.block then return "fail" end
  local readyAt=s.cooldowns.Dash or 0
  if tick<readyAt then return readyAt-tick<=Rules.BufferFrames and "wait" or "fail" end
  startDash(s); return "ok"
 end
 return startAttack(s,input,quiet)
end
local function doAction(s,action,data,seq)
 if not Rules.actionAvailable(s.hero,action) then ack(s,seq,false); return end
 if seq and s.player then
  s.pressAt=s.pressAt or {}; s.pressAt[seq]=tick
  if seq%64==0 then for k,v in s.pressAt do if tick-v>600 then s.pressAt[k]=nil end end end
 end
 if action=="Block" then s.blockHeld=data==true end
 if action=="Block" and data==false then s.block=false; return end
 if tick<(s.holdUntil or 0) then ack(s,seq,false); return end
 if BUFFERED[action] then
  -- Pressed while busy (attacking, stunned, frozen, dashing, cooldown nearly up): remember it.
  local result=tryInput(s,action,false)
  if result=="wait" then
   if s.buffer then ack(s,s.buffer.seq,false) end -- a newer press replaces it
   s.buffer={input=action,expires=tick+Rules.BufferFrames,seq=seq}
  else ack(s,seq,result=="ok") end
  return
 end
 if tick<s.stunned or s.action or tick<s.dashUntil then return end
 if action=="Jump" then
  if not s.owned and not s.block and not s.flying and s.hum.FloorMaterial~=Enum.Material.Air then s.hum.Jump=true end
 elseif action=="Block" then
  if data==true and not s.flying and not s.block then
   s.block=true
   if tick>=s.parryReady then s.blockAt=tick; s.parryReady=tick+45 else s.blockAt=-600 end
  end
 elseif action=="Flight" and Rules.Characters[s.hero].Flies and not s.block then
  if s.flying then stopFlight(s)
  elseif noFlight or s.noFlightDuel then notify(s.player,"No flying in overtime.")
  elseif s.energy>=Rules.Flight.Takeoff then
   s.energy-=Rules.Flight.Takeoff; s.flying=true; s.velocity.Enabled=true
   s.flightStart=tick; s.hum.AutoRotate=false
  end
 end
end
local botLevel=Rules.Bot.Default
-- v27: which hero the sparring bot plays (bot hero button).
local botHero=Rules.Bot.Heroes[1]
local botSwapping=false
local duelStopped=false -- R22: STOP FIGHT holds off the automatic duel until START FIGHT
-- Resume runs its own 3-2-1 before the fight unfreezes; the token cancels a stale countdown.
local resumeToken=0
local resuming=false
local function botOn() return botLevel~="Off" end
-- R63 (top-5 audit item 1, option b: "everyone fights"): many 1v1 duels run at once. Each duel has its
-- own best-of-3, 99 s timer and ring (a pair of start marks in the arena). Players join with QUEUE (the
-- first two waiting are paired), CHALLENGE the fighter they have targeted (who presses ACCEPT), or press
-- START FIGHT to duel the sparring bot when it's free. Fighters in a duel can only hurt each other, so
-- nobody can interfere; everyone else spars freely or WATCHes a duel. Two players alone in a server still
-- start a duel on their own, as before. Fighters are keyed by Player, or by "Bot" for the sparring bot.
D={list={},of={},queue={},challenges={},nextId=0}
-- R66-ui10: a higher jump (Rules.Characters.<hero>.JumpPower) and a ledge pull-up reach higher before the
-- anti-cheat calls it flying; Wraithstep on a wall (spider climb) is checked separately.
function D.jumpRise(s)
 local jp=Rules.Characters[s.hero].JumpPower or 45
 local mantle=Rules.Climb and Rules.Climb[s.hero] and Rules.Climb[s.hero].Mantle or 0
 return Rules.Net.JumpRise+math.max(0,(jp*jp-45*45)/(2*workspace.Gravity))+mantle
end
local function stateOf(key) if key=="Bot" then return dummy end return states[key] end
local function nameOf(key) if key=="Bot" then return "Sparring bot" end return key.DisplayName end
local function keyOf(s) if not s then return nil end if s.isDummy then return "Bot" end return s.player end
local function inDuel(player) return D.of[player]~=nil end
foe=function(s,t)
 local da,db=D.of[keyOf(s)],D.of[keyOf(t)]
 if da or db then return da==db end
 return true
end
-- Ring start marks for the current arena: {x, z, axis}; the two fighters stand 12 studs either side of
-- the mark along that axis, facing each other.
function D.rings()
 local c=Rules.Arenas.TempleModels and Rules.Arenas.TempleModels.Centre
 if arenaSpots and c and c.Rings then return c.Rings end
 local a=Rules.Arenas[arenaName]
 return (a and a.Rings) or {{0,spotZ("Round",10),"x"}}
end
function D.practiceSpot(i)
 local r=D.rings()[i] or D.rings()[1]
 return r[3]=="z" and Vector3.new(r[1],4,r[2]+22) or Vector3.new(r[1]+22,4,r[2])
end
function D.freeRing()
 local used={}; for _,d in D.list do used[d.ring]=true end
 for i=1,#D.rings() do if not used[i] then return i end end
 return nil
end
function D.mark(d,i)
 local rings=D.rings(); local r=rings[d.ring] or rings[1]
 local off=i==1 and -12 or 12
 local p=r[3]=="z" and Vector3.new(r[1],4,r[2]+off) or Vector3.new(r[1]+off,4,r[2])
 return CFrame.lookAt(p,Vector3.new(r[1],4,r[2]))
end
local function healthPct(s) return alive(s) and s.hum.Health/s.hum.MaxHealth or 0 end
local function roundData(d,banner)
 local wins={}
 for _,k in d.fighters do wins[nameOf(k)]=d.wins[k] or 0 end
 local left=0
 if d.phase=="Fight" then left=math.max(0,math.ceil((d.endsAt-tick)/60))
 elseif d.phase=="Countdown" then left=math.max(0,math.ceil((d.fightAt-tick)/60)) end
 return {phase=d.phase,number=d.number,left=left,wins=wins,banner=banner,bot=d.bot,paused=paused}
end
-- A duel's round display goes to its two fighters only.
local function broadcastRound(d,banner)
 local data=roundData(d,banner)
 for _,k in d.fighters do if k~="Bot" and k.Parent then remote:FireClient(k,"Round",data) end end
end
local function idleRound(player,banner)
 remote:FireClient(player,"Round",{phase="Waiting",number=0,left=0,wins={},banner=banner,bot=false,paused=paused})
end
-- Everyone gets the list of running duels (for the menu's duel list and WATCH) and the queue size.
function D.announce()
 local list={}
 for _,d in D.list do
  local a,b=d.fighters[1],d.fighters[2]
  table.insert(list,{id=d.id,a=nameOf(a),b=nameOf(b),wa=d.wins[a] or 0,wb=d.wins[b] or 0,phase=d.phase,
   ma=stateOf(a) and stateOf(a).model or nil,mb=stateOf(b) and stateOf(b).model or nil})
 end
 remote:FireAllClients("Duels",list,#D.queue)
end
local function resetFighter(s,cf,hold)
 s.hum.Health=s.hum.MaxHealth; s.energy=100; s.fury=Rules.Fury.Start; s.super=0; s.cooldowns={}; s.gcd=0
 if s.buffer then ack(s,s.buffer.seq,false) end
 s.action=nil; s.buffer=nil; s.stunned=0; s.hitstop=0; s.knock=nil; s.pull=nil; s.launch=nil; s.receivedHits=0
 s.block=false; s.blockStunned=false; s.shieldUntil=0; s.parryUntil=0; s.invulnerable=0; s.downUntil=0; s.drCount=0; s.drUntil=0; s.dr=nil; s.carry=nil; s.lastHurt=nil; s.whirl=nil; s.model:SetAttribute("Whirl",false)
 s.model:SetAttribute("StunEnd",nil); s.model:SetAttribute("RevealEnd",nil)
 if s.shadowCircle then s.shadowCircle.visual:Destroy(); s.shadowCircle=nil end
 s.speedUntil=0; s.model:SetAttribute("SpeedBuffEnd",nil)
 s.jugg=0; s.splat=nil; s.model:SetAttribute("Juggernaut",0)
 s.drain=nil; s.model:SetAttribute("Drained",false)
 s.shieldHP=nil; s.model:SetAttribute("ShieldHP",nil); s.ramp=nil; s.absorbUntil=nil; s.healUntil=nil
 s.snare=nil; s.model:SetAttribute("Snared",false); s.mistUntil=nil; s.model:SetAttribute("MistEnd",nil)
 s.dots=nil; s.model:SetAttribute("ShadeStacks",nil); s.phaseUntil=nil; s.phaseStart=nil; s.glitching=nil; s.model:SetAttribute("PhaseEnd",nil)
 if s.solarZone then s.solarZone.visual:Destroy(); s.solarZone=nil end
 s.zap=nil; s.zapStacks=nil; s.model:SetAttribute("Zapped",false); s.model:SetAttribute("ZapStacks",nil)
 s.invisibleUntil=0; s.revealedUntil=0; s.model:SetAttribute("Invisible",false); s.shadowUntil=nil; s.model:SetAttribute("ShadowForm",false); s.sneak=nil; stopFlight(s)
 setOwner(s,false) -- v30: take movement back first so the client can't drag it back to the old spot
 placeAt(s,cf)
 s.holdUntil=hold
end
-- Practice reset (no duel): the player, and the bot when it isn't in someone's duel, back on the marks.
function D.practiceReset(player)
 local s=states[player]
 if s and alive(s) then resetFighter(s,CFrame.lookAt(Vector3.new(0,4,spotZ("Player",22)),Vector3.new(0,4,spotZ("Round",0))),nil) end
 if dummy and alive(dummy) and not D.of.Bot then
  resetFighter(dummy,CFrame.lookAt(Vector3.new(0,4,spotZ("Dummy",-22)),Vector3.new(0,4,spotZ("Round",0))),nil)
 end
end
-- Telemetry: what landed this round, per hero and move, printed to Output.
local function logSummary(d)
 if not roundLog or #roundLog==0 then return end
 local by={}
 for _,h in roundLog do
  local key=h.hero.." "..h.move
  local e=by[key] or {n=0,dmg=0,dist=0,res={}}; by[key]=e
  e.n+=1; e.dmg+=h.damage; e.dist+=h.dist; e.res[h.result]=(e.res[h.result] or 0)+1
 end
 print(string.format("[HeroWars] Round %d hit log (%d contacts):",d and d.number or 0,#roundLog))
 for key,e in by do
  local parts={}; for r,n in e.res do table.insert(parts,r.."="..n) end
  print(string.format("  %s x%d • %d dmg • avg %.1f studs • %s",key,e.n,e.dmg,e.dist/e.n,table.concat(parts," ")))
 end
 roundLog={}
end
local function startRound(d)
 d.number+=1; d.phase="Countdown"; d.fightAt=tick+Rules.Round.Countdown*60
 d.endsAt=d.fightAt+Rules.Round.Seconds*60; roundLog=roundLog or {}; d.shown=nil; d.overtime=false
 for i,k in d.fighters do
  local st=stateOf(k)
  if st then st.noFlightDuel=nil; resetFighter(st,D.mark(d,i),d.fightAt) end
 end
 broadcastRound(d) -- the countdown shows 3, 2, 1, GO!
end
local function endRound(d,winner,how)
 logSummary(d)
 d.phase="Over"; d.nextAt=tick+Rules.Round.Intermission*60
 local banner
 if winner then
  d.wins[winner]=(d.wins[winner] or 0)+1
  banner=how.." • "..nameOf(winner).." wins round "..d.number
  if d.wins[winner]>=Rules.Round.WinsNeeded then
   banner=nameOf(winner).." wins the match!"; d.matchOver=true
   D.recordMatch(d,winner)
   print("[HeroWars] Match won by "..nameOf(winner).." ("..stateOf(winner).hero..")")
  end
 else banner=how.." • Draw" end
 broadcastRound(d,banner); D.announce()
end
-- Start over: fresh match from round 1, both fighters back on their marks, 3-2-1-GO.
local function restartMatch(d)
 for _,k in d.fighters do if not alive(stateOf(k)) then return false end end
 d.wins={}; d.number=0; d.matchOver=false; logSummary(d)
 startRound(d)
 return true
end
local function freeze(on)
 for key,st in states do
  if typeof(key)=="Instance" and key:IsA("Model") and st.root.Parent then
   if on then st.root.AssemblyLinearVelocity=Vector3.zero; st.root.AssemblyAngularVelocity=Vector3.zero end
   st.root.Anchored=on
   -- v30: anchoring takes movement off the client; start again from the server after unpausing.
   if not on and st.player then
    pcall(function() st.root:SetNetworkOwner(nil) end)
    st.owned=false; st.freeSince=nil; st.model:SetAttribute("ClientMove",false)
   end
  end
 end
end
-- Pause stops everything at once. Resume counts 3, 2, 1, then GO and the fight continues
-- from the same moment. instant=true skips the countdown (used when the match ends or restarts).
-- R63: pause stops the whole server, so it only works while one duel is running.
local function tellAll(text)
 local seen={}
 for _,d in D.list do for _,k in d.fighters do if k~="Bot" and not seen[k] then seen[k]=true; remote:FireClient(k,"Round",roundData(d,text)) end end end
 for _,p in Players:GetPlayers() do if not seen[p] then idleRound(p,text) end end
end
local function setPaused(on,by,instant)
 resumeToken+=1; local token=resumeToken; resuming=false
 if on then
  paused=true; freeze(true)
  tellAll("PAUSED"); remote:FireAllClients("Paused",true,by)
  return
 end
 if not paused then return end
 if instant then
  paused=false; freeze(false); remote:FireAllClients("Paused",false,by); return
 end
 resuming=true
 remote:FireAllClients("Paused","resuming",by)
 task.spawn(function()
  for n=3,1,-1 do
   if resumeToken~=token then return end
   tellAll(tostring(n)); task.wait(1)
  end
  if resumeToken~=token or not paused then return end
  resuming=false; paused=false; freeze(false)
  tellAll("GO!"); remote:FireAllClients("Paused",false,by)
 end)
end
-- A new duel between two free fighters on a free ring. nil when every ring is busy.
function D.start(a,b)
 local ring=D.freeRing(); if not ring then return nil end
 D.nextId+=1
 local d={id=D.nextId,phase="Waiting",wins={},number=0,fighters={a,b},ring=ring,bot=(a=="Bot" or b=="Bot"),matchOver=false}
 table.insert(D.list,d)
 for _,k in d.fighters do
  D.of[k]=d
  local i=table.find(D.queue,k); if i then table.remove(D.queue,i) end
  if k~="Bot" then D.challenges[k]=nil end
  local st=stateOf(k); if st then st.model:SetAttribute("DuelId",d.id) end
 end
 for p,c in D.challenges do if c.from==a or c.from==b then D.challenges[p]=nil end end
 print(string.format("[HeroWars] Duel %d: %s vs %s on ring %d",d.id,nameOf(a),nameOf(b),ring))
 startRound(d); D.announce()
 return d
end
function D.finish(d,banner)
 local i=table.find(D.list,d); if i then table.remove(D.list,i) end
 for _,k in d.fighters do
  if D.of[k]==d then D.of[k]=nil end
  local st=stateOf(k)
  if st then st.noFlightDuel=nil; st.holdUntil=nil; st.model:SetAttribute("DuelId",nil) end
  if k~="Bot" and k.Parent then idleRound(k,banner) end
 end
 logSummary(d)
 if paused and #D.list==0 then setPaused(false,"",true) end
 D.announce()
end
local function free(player) return player and player.Parent and states[player] and alive(states[player]) and not D.of[player] end
local function roundStep()
 noFlight=false
 -- Pairing: the queue first, then two players alone in the server duel on their own (as before R63).
 for i=#D.queue,1,-1 do if not free(D.queue[i]) then table.remove(D.queue,i) end end
 while #D.queue>=2 and D.freeRing() do D.start(D.queue[1],D.queue[2]) end
 local players=Players:GetPlayers()
 if #players==2 and #D.list==0 and not duelStopped and free(players[1]) and free(players[2]) then D.start(players[1],players[2]) end
 if tick%120==0 then
  for _,p in players do if not D.of[p] then idleRound(p) end end
  D.announce()
 end
 for _,d in table.clone(D.list) do
  -- A fighter who left (or the bot switched off) ends the duel. The bot counts while it respawns.
  local gone=false
  for _,k in d.fighters do
   if k=="Bot" then if not botOn() then gone=true end
   elseif not k.Parent or not states[k] then gone=true end
  end
  if gone then D.finish(d,"Match cancelled"); continue end
  local a,b=stateOf(d.fighters[1]),stateOf(d.fighters[2])
  -- A fighter's body after a K.O. respawn is a new model: tag it with the duel again.
  for _,st in {a,b} do if st and st.model:GetAttribute("DuelId")~=d.id then st.model:SetAttribute("DuelId",d.id) end end
  if d.phase=="Countdown" then
   local left=math.max(0,math.ceil((d.fightAt-tick)/60))
   if tick>=d.fightAt then d.phase="Fight"; broadcastRound(d,"GO!"); D.announce()
   elseif left~=d.shown and tick>d.fightAt-Rules.Round.Countdown*60 then
    -- One big number per second: 3, 2, 1 (the round title shows on the first tick).
    d.shown=left; broadcastRound(d,tostring(left))
   end
  elseif d.phase=="Fight" then
   local aa,ba=alive(a),alive(b)
   if not aa or not ba then
    endRound(d,(aa and d.fighters[1]) or (ba and d.fighters[2]) or nil,"K.O.")
   elseif tick>=d.endsAt and not d.overtime and (Rules.Round.Overtime or 0)>0 then
    -- v27 overtime: everyone lands and fights on the ground for a last few seconds.
    d.overtime=true; d.endsAt=tick+Rules.Round.Overtime*60
    for _,k in d.fighters do local st=stateOf(k); if st then st.noFlightDuel=true; stopFlight(st) end end
    broadcastRound(d,"OVERTIME • no flying")
   elseif tick>=d.endsAt then
    local pa,pb=healthPct(a),healthPct(b)
    endRound(d,pa>pb and d.fighters[1] or pb>pa and d.fighters[2] or nil,"Time")
   elseif tick%30==0 then broadcastRound(d) end
  elseif d.phase=="Over" then
   if d.matchOver and tick>=d.nextAt then
    -- The match is done: the ring is freed. QUEUE, CHALLENGE or START FIGHT for another.
    D.finish(d,d.bot and "Press START FIGHT (R) to go again" or "Match over • QUEUE or CHALLENGE for another")
   elseif tick>=d.nextAt and alive(a) and alive(b) then
    startRound(d)
   end
  end
 end
end
-- Sparring bot. R66-ui9 (Peter: "Bot AI Strategy & Priority System"): the tactical AI lives in the BotAI
-- module next to this script, and its strategy kits, priorities and Easy / Normal / Hard settings are data in
-- Rules.BotAI. This only decides whether the bot is fighting (its own match's FIGHT phase).
D.BotAI=require(script.Parent:WaitForChild("BotAI"))
D.Climb=require(RS.HeroWars:WaitForChild("Climb")) -- R66-ui10 wall climb / ledge pull-up / bot jumps
D.botCtx={Rules=Rules,states=states,alive=alive,clearSight=clearSight,flatUnit=flatUnit,
 foe=function(a,b) return foe(a,b) end,doAction=function(s,a,d) doAction(s,a,d) end,
 now=function() return tick end,level=function() return botLevel end}
local function botThink(s)
 local fighting=botOn() and D.of.Bot~=nil and D.of.Bot.phase=="Fight"
 if not fighting then
  s.dir=Vector3.zero; s.lock=false
  if s.blockHeld then doAction(s,"Block",false) end
  if s.flying then doAction(s,"Flight") end
  return
 end
 D.BotAI.think(s,D.botCtx)
end
local previewFolder=Instance.new("Folder"); previewFolder.Name="Previews"; previewFolder.Parent=RS.HeroWars
-- R22 (Peter: "the preview lobby skin load slow"): each preview used to build a whole new body from
-- Roblox (several seconds). Now the server builds one body per hero once, then makes every skin by
-- copying it and repainting (the same repaint as the in-game Skin button), and does all of them in the
-- background from the moment the server starts, one worker per hero, so the lobby is usually ready.
-- R30: no 2-second head start for the fighters any more; skins build first. Building them also warms
-- Appearance's gear and shield caches, so in-game skin changes are instant too. Total = how many looks.
local previewQueue={}; local previewBase={}
do local n=0; for _,h in {"Solarion","Wraithstep","Tempest","Bulwark"} do n+=#Rules.Skins[h].Order end; previewFolder:SetAttribute("Total",n) end
local function previewFirst(hero,id)
 local q=previewQueue[hero]; if not q or previewFolder:FindFirstChild(hero.."|"..id) then return end
 local i=table.find(q,id); if i then table.remove(q,i) end
 table.insert(q,1,id)
end
for _,hero in {"Solarion","Wraithstep","Tempest","Bulwark"} do
 previewQueue[hero]=table.clone(Rules.Skins[hero].Order)
 task.spawn(function()
  local q=previewQueue[hero]
  while #q>0 do
   local id=table.remove(q,1)
   local key=hero.."|"..id
   if not previewFolder:FindFirstChild(key) then
    local ok,model=pcall(function()
     local skin=Rules.skin(hero,id)
     Appearance.baseCache=Appearance.baseCache or {}
     if not previewBase[hero] and Appearance.baseCache[hero] then previewBase[hero]=Appearance.baseCache[hero] end -- R65: shared with spawns
     if not previewBase[hero] then
      previewBase[hero]=Appearance.create(hero,Rules.Characters[hero],skin)
      if not Appearance.baseCache[hero] then Appearance.baseCache[hero]=previewBase[hero] end
      return previewBase[hero]:Clone()
     end
     local m=previewBase[hero]:Clone(); Appearance.applySkin(m,hero,skin); return m
    end)
    if ok and model then
     for _,d in model:GetDescendants() do
      if d:IsA("BasePart") then d.Anchored=true; d.CanCollide=false; d.CanQuery=false; d.CanTouch=false
      elseif d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
     end
     model.Name=key; model:PivotTo(CFrame.new()); model.Parent=previewFolder
    else warn("[HeroWars] lobby preview "..key.." failed: "..tostring(model)) end
   end
   task.wait()
  end
 end)
end
D.handlers={}
-- R66-ui (Peter: "do a vote for the bots"): with more than one player in the server, changing the arena, the
-- bot's level or the bot's hero is a vote. YES from more than half the players passes it; 20 s, then it fails.
-- Alone in a server it happens straight away, as before.
function D.voteText(kind)
 if kind=="Arena" then
  local order=Rules.Arenas.Order; local nxt=order[(table.find(order,arenaName) or 0)%#order+1]
  return "Change the arena to "..((Rules.Arenas[nxt] and Rules.Arenas[nxt].Title) or nxt).."?"
 elseif kind=="Bot" then
  local order=Rules.Bot.Order; local nxt=order[(table.find(order,botLevel) or 0)%#order+1]
  return nxt=="Off" and "Turn the sparring bot off?" or ("Set the sparring bot to "..nxt.."?")
 else
  local heroes=Rules.Bot.Heroes; return "Switch the sparring bot to "..heroes[(table.find(heroes,botHero) or 0)%#heroes+1].."?"
 end
end
function D.needed() return math.floor(#Players:GetPlayers()/2)+1 end
function D.sendVote()
 local v=D.vote; if not v then return end
 local yes=0; for _ in v.yes do yes+=1 end
 remote:FireAllClients("Vote",{id=v.id,text=v.text,by=v.by.DisplayName,yes=yes,need=D.needed(),left=math.max(0,math.ceil(v.ends-os.clock()))})
end
function D.endVote(passed)
 local v=D.vote; if not v then return end
 D.vote=nil
 remote:FireAllClients("VoteEnd",{id=v.id,passed=passed})
 tellAll((passed and "Vote passed: " or "Vote failed: ")..v.text)
 if passed and v.by.Parent then D.onServerEvent(v.by,v.kind,nil,nil,true) end
end
function D.tallyVote()
 local v=D.vote; if not v then return end
 local yes,no=0,0
 for p in v.yes do if p.Parent then yes+=1 end end
 for p in v.no do if p.Parent then no+=1 end end
 local n=#Players:GetPlayers(); local need=D.needed()
 if yes>=need then D.endVote(true) elseif no>n-need then D.endVote(false) else D.sendVote() end
end
function D.askVote(player,kind)
 if #Players:GetPlayers()<=1 then D.onServerEvent(player,kind,nil,nil,true); return end
 if D.vote then notify(player,"A vote is already running. Vote on it at the top right."); return end
 D.voteId=(D.voteId or 0)+1
 D.vote={id=D.voteId,kind=kind,by=player,text=D.voteText(kind),yes={[player]=true},no={},ends=os.clock()+20}
 local id=D.voteId
 D.tallyVote()
 task.delay(20,function() if D.vote and D.vote.id==id then D.endVote(false) end end)
end
function D.castVote(player,yes)
 local v=D.vote; if not v then return end
 v.yes[player]=yes or nil; v.no[player]=(not yes) or nil
 D.tallyVote()
end
-- R66-ui: saved wins. Player-vs-player wins and losses plus bot wins, kept in DataStore HeroWarsStats
-- (key s_<UserId>); PvP wins also go to the OrderedDataStore HeroWarsWins for the all-time leaderboard.
D.stats={}
function D.statStores()
 if D.statStore==nil then
  local ok,a=pcall(function() return DataStoreService:GetDataStore("HeroWarsStats") end)
  local ok2,b=pcall(function() return DataStoreService:GetOrderedDataStore("HeroWarsWins") end)
  D.statStore=ok and a or false; D.winStore=ok2 and b or false
  if not ok then warn("HeroWars wins will not be saved: "..tostring(a)) end
 end
 return D.statStore,D.winStore
end
function D.loadStats(player)
 local st={wins=0,losses=0,botWins=0}
 D.stats[player]=st
 local folder=Instance.new("Folder"); folder.Name="leaderstats"
 local w=Instance.new("IntValue"); w.Name="Wins"; w.Parent=folder
 local l=Instance.new("IntValue"); l.Name="Losses"; l.Parent=folder
 folder.Parent=player
 local store=D.statStores()
 if store then
  local ok,saved=pcall(function() return store:GetAsync("s_"..player.UserId) end)
  if ok and type(saved)=="table" and D.stats[player]==st then
   st.wins=tonumber(saved.wins) or 0; st.losses=tonumber(saved.losses) or 0; st.botWins=tonumber(saved.botWins) or 0
  elseif not ok then warn("HeroWars wins not loaded: "..tostring(saved)) end
 end
 st.loaded=true
 w.Value=st.wins; l.Value=st.losses
end
function D.saveStats(player,leaving)
 local st=D.stats[player]; if not st then return end
 if leaving then D.stats[player]=nil end
 if not st.loaded or not st.dirty then return end
 st.dirty=false
 local store,wins=D.statStores()
 local uid=player.UserId
 task.spawn(function()
  if store then
   local ok,err=pcall(function() store:SetAsync("s_"..uid,{wins=st.wins,losses=st.losses,botWins=st.botWins}) end)
   if not ok then warn("HeroWars wins not saved: "..tostring(err)) end
  end
  if wins and uid>0 then pcall(function() wins:SetAsync(tostring(uid),st.wins) end) end
 end)
end
function D.recordMatch(d,winner)
 local a,b=d.fighters[1],d.fighters[2]; local loser=winner==a and b or a
 local function bump(k,field)
  if k=="Bot" then return end
  local st=D.stats[k]; if not st then return end
  st[field]+=1; st.dirty=true
  local ls=k:FindFirstChild("leaderstats")
  if ls and field~="botWins" then local v=ls:FindFirstChild(field=="wins" and "Wins" or "Losses"); if v then v.Value=st[field] end end
  D.saveStats(k)
 end
 if d.bot then bump(winner,"botWins") else bump(winner,"wins"); bump(loser,"losses") end
end
-- Leaderboard: this server's players and the all-time top 10 (refreshed at most once a minute).
D.names={}
function D.sendBoard(player)
 local here={}
 for _,p in Players:GetPlayers() do
  local st=D.stats[p]
  table.insert(here,{name=p.DisplayName,wins=st and st.wins or 0,losses=st and st.losses or 0,bot=st and st.botWins or 0,me=p==player})
 end
 table.sort(here,function(x,y) return x.wins>y.wins end)
 local _,wins=D.statStores()
 if wins and os.clock()-(D.topAt or -100)>60 then
  D.topAt=os.clock()
  local ok,page=pcall(function() return wins:GetSortedAsync(false,10):GetCurrentPage() end)
  if ok then
   local top={}
   for _,e in page do
    local id=tonumber(e.key)
    local name=id and D.names[id]
    if id and not name then
     local ok2,n=pcall(function() return Players:GetNameFromUserIdAsync(id) end)
     name=ok2 and n or ("Player "..e.key); D.names[id]=name
    end
    table.insert(top,{name=name or e.key,wins=e.value})
   end
   D.top=top
  end
 end
 remote:FireClient(player,"Board",{here=here,top=D.top or {}})
end
local function onServerEvent(player,action,data,seq,data_vote)
 if type(action)~="string" or not validActions[action] then return end
 local now=os.clock(); local gate=gates[player]
 if not gate then gate={tokens=60,time=now}; gates[player]=gate end
 gate.tokens=math.min(60,gate.tokens+(now-gate.time)*40); gate.time=now
 if type(seq)~="number" or seq~=seq or seq<0 or seq>2^31 or seq%1~=0 then seq=nil end
 if gate.tokens<1 then if seq and states[player] then ack(states[player],seq,false) end; return end; gate.tokens-=1
 if action=="Vote" then D.castVote(player,data==true); return end
 if action=="Leaderboard" then D.sendBoard(player); return end
 -- R19 lobby: a look-only copy of any hero in any skin, built once and kept in ReplicatedStorage so the
 -- lobby can spin it in a viewport. Anchored, no hurtbox, never in the workspace.
 if action=="Preview" then
  -- R22: every look is already being built in the background (see previewQueue); asking just moves this
  -- one to the front of its hero's queue.
  if type(data)~="table" or type(data.hero)~="string" or not Rules.Characters[data.hero] or type(data.skin)~="string" then return end
  local _,id=Rules.skin(data.hero,data.skin); if id~=data.skin then return end
  previewFirst(data.hero,id)
  return
 end
 -- R19 lobby: choose the skin a hero will wear before switching to them.
 if action=="PickSkin" then
  if type(data)~="table" or type(data.hero)~="string" or not Rules.Characters[data.hero] or type(data.skin)~="string" then return end
  local _,id=Rules.skin(data.hero,data.skin); if id~=data.skin then return end
  gate.skins=gate.skins or {}; gate.skins[data.hero]=id
  return
 end
 if action=="LoadBinds" then
  if gate.bindsLoaded then return end; gate.bindsLoaded=true
  local saved
  if bindStore then
   local ok,result=pcall(function() return bindStore:GetAsync("keys_"..player.UserId) end)
   if ok then saved=cleanBinds(result) else warn("HeroWars keybindings not loaded: "..tostring(result)) end
  end
  if saved and player.Parent then remote:FireClient(player,"Binds",saved) end
  return
 end
 if action=="SaveBinds" then
  local clean=cleanBinds(data); if not clean or not bindStore then return end
  gate.pendingBinds=clean
  if gate.bindSaveQueued then return end; gate.bindSaveQueued=true
  -- At most one DataStore write per player every 6 seconds; the latest bindings win.
  task.delay(math.max(0,(gate.bindsSavedAt or -10)+6-os.clock()),function()
   local pending=gate.pendingBinds; gate.pendingBinds=nil; gate.bindSaveQueued=false; gate.bindsSavedAt=os.clock()
   if pending then
    local ok,err=pcall(function() bindStore:SetAsync("keys_"..player.UserId,pending) end)
    if not ok then warn("HeroWars keybindings not saved: "..tostring(err)) end
   end
  end)
  return
 end

 -- R66 (Peter: "a How to Play card ... and a 60-90 second guided first fight"): whether this player has seen the
 -- How to Play card and finished the guided fight, kept in its own DataStore (HeroWarsProgress, key p_<UserId>).
 if action=="Progress" or action=="SaveProgress" then
  if not D.progressStore then
   local ok,store=pcall(function() return DataStoreService:GetDataStore("HeroWarsProgress") end)
   D.progressStore=ok and store or false
   if not ok then warn("HeroWars progress will not be saved: "..tostring(store)) end
  end
  local store=D.progressStore
  if action=="Progress" then
   if gate.progressLoaded then return end; gate.progressLoaded=true
   local saved
   if store then
    local ok,result=pcall(function() return store:GetAsync("p_"..player.UserId) end)
    if ok then saved=result else warn("HeroWars progress not loaded: "..tostring(result)) end
   end
   saved=type(saved)=="table" and saved or {}
   if player.Parent then remote:FireClient(player,"Progress",{howto=saved.howto==true,tutorial=saved.tutorial==true}) end
   return
  end
  if type(data)~="table" or not store then return end
  gate.pendingProgress={howto=data.howto==true,tutorial=data.tutorial==true}
  if gate.progressSaveQueued then return end; gate.progressSaveQueued=true
  -- At most one write per player every 6 seconds; the latest wins.
  task.delay(math.max(0,(gate.progressSavedAt or -10)+6-os.clock()),function()
   local pending=gate.pendingProgress; gate.pendingProgress=nil; gate.progressSaveQueued=false; gate.progressSavedAt=os.clock()
   if pending then
    local ok,err=pcall(function() store:SetAsync("p_"..player.UserId,pending) end)
    if not ok then warn("HeroWars progress not saved: "..tostring(err)) end
   end
  end)
  return
 end
 local s=states[player]
 -- R66 guided fight, steps 6 and 7: the sparring bot swings at (data "Swing") or starts a cast at (data "Cast")
 -- the player who asked, so they can practise Defensive / Dodge and Interrupt. Only while the bot is in no match,
 -- the player is in no duel and stands within 22 studs of it; at most once every 2.5 s per player.
 if action=="Coach" then
  if (data~="Swing" and data~="Cast") or inDuel(player) or not alive(s) then return end
  if now-(gate.coachAt or -10)<2.5 then return end
  -- R66-ui: the nearest sparring partner, the bot (when it's in no match) or a practice dummy.
  local dummy,best=nil,22
  for key,st in states do
   if typeof(key)=="Instance" and (st.isPractice or (st.isDummy and not D.of.Bot)) and alive(st) then
    local dist=(s.root.Position-st.root.Position).Magnitude
    if dist<=best then dummy,best=st,dist end
   end
  end
  if not dummy then notify(player,"Walk up to the bot or a practice dummy first."); return end
  local delta=s.root.Position-dummy.root.Position
  gate.coachAt=now
  local flat=Vector3.new(delta.X,0,delta.Z)
  if flat.Magnitude>0.1 then dummy.aim=flat.Unit; dummy.root.CFrame=CFrame.lookAt(dummy.root.Position,dummy.root.Position+flat.Unit) end
  local pick
  if data=="Cast" then
   for _,id in {"Skill1","Skill2","Skill3","Heavy"} do
    local name=Rules.moveName(dummy.hero,id,1); local m=name and Rules.heroMove(dummy.hero,name)
    if m and m.Cast and (m.Damage or 0)>0 and tick>=(dummy.cooldowns[name] or 0) then pick=id; break end
   end
   if not pick then notify(player,"The bot has no cast ready. Try again in a moment."); return end
  else
   pick=Rules.actionAvailable(dummy.hero,"Light") and "Light" or "Heavy"
  end
  doAction(dummy,pick)
  return
 end
 if action=="BotHero" then
  -- v27: switch the sparring bot's hero (not during a bot match).
  if D.of.Bot and not D.of.Bot.matchOver then
   notify(player,"Change the bot's hero after its match."); return
  end
  if botSwapping then return end
  if not data_vote then D.askVote(player,action); return end
  local heroes=Rules.Bot.Heroes
  botHero=heroes[(table.find(heroes,botHero) or 0)%#heroes+1]
  remote:FireAllClients("Bot",botLevel,botHero)
  botSwapping=true
  local old=dummy
  if old then dummy=nil; states[old.model]=nil; old.model:Destroy() end
  local ok,err=pcall(spawnFighter,nil,botHero,true); botSwapping=false
  if not ok then warn("Training dummy: "..tostring(err)) end
  return
 end
 if action=="Arena" then
  -- v32: next arena, when no duel is running (R63: any duel). Everyone goes back to a clear spot.
  if #D.list>0 then notify(player,"Change the arena when no duels are running."); return end
  if not data_vote then D.askVote(player,action); return end
  local order=Rules.Arenas.Order
  buildArena(order[(table.find(order,arenaName) or 0)%#order+1])
  local i=0
  for key,st in states do
   if typeof(key)=="Instance" and key:IsA("Model") and st.isPractice then
    if D.rings()[st.practiceRing] then
     local o=D.practiceSpot(st.practiceRing); placeAt(st,CFrame.lookAt(o,Vector3.new(0,4,spotZ("Round",0))))
    else states[key]=nil; key:Destroy() end
   elseif typeof(key)=="Instance" and key:IsA("Model") and alive(st) then
    i+=1
    local origin=st.isDummy and Vector3.new(0,4,spotZ("Dummy",-22)) or Vector3.new(i%2==1 and -12 or 12,4,spotZ("Player",14))
    placeAt(st,CFrame.lookAt(origin,Vector3.new(0,4,spotZ("Round",0))))
   end
  end
  remote:FireAllClients("Arena",arenaName)
  return
 end
 if action=="Bot" then
  if not data_vote then D.askVote(player,action); return end
  local order=Rules.Bot.Order
  botLevel=order[(table.find(order,botLevel) or 0)%#order+1]
  -- Switching the bot off ends its match; never leave the game frozen.
  if not botOn() and D.of.Bot then D.finish(D.of.Bot,"The sparring bot was switched off") end
  remote:FireAllClients("Bot",botLevel,botHero)
  return
 end
 if action=="Pause" then
  if not inDuel(player) then notify(player,"Pause works during a match."); return end
  if #D.list>1 and not paused then notify(player,"Pause is off while other duels are running."); return end
  -- R66-ui: pausing freezes the whole server, so it only works when the two of you are the only players.
  if not paused then for _,p in Players:GetPlayers() do if not (D.of[p] and D.of[p]==D.of[player]) then notify(player,"Pause is off while other players are in the server."); return end end end
  -- P during the resume countdown pauses again instead of restarting the count.
  setPaused(not paused or resuming,player.DisplayName); return
 end
 -- R63: QUEUE joins (or leaves) the line for the next free ring; the first two waiting fight.
 if action=="Queue" then
  local i=table.find(D.queue,player)
  if i then table.remove(D.queue,i); notify(player,"Left the queue."); D.announce(); return end
  if inDuel(player) then notify(player,"You're already in a duel."); return end
  if not free(player) then notify(player,"Get back up first, then queue."); return end
  table.insert(D.queue,player)
  notify(player,#D.queue>=2 and "Opponent found!" or "In the queue • waiting for an opponent (QUEUE again to leave)")
  D.announce(); return
 end
 -- R63: CHALLENGE the fighter you have targeted; they get ACCEPT at the top right for 30 seconds.
 if action=="Challenge" then
  if inDuel(player) then notify(player,"Finish your duel first."); return end
  local target=typeof(data)=="Instance" and data:IsA("Model") and states[data] or nil
  if not target then notify(player,"Target a fighter first (tap or click them, or Tab), then CHALLENGE."); return end
  if target.isDummy then data="Bot" -- challenging the bot is START FIGHT against it
  else
   local other=target.player
   if other==player then return end
   if D.of[other] then notify(player,other.DisplayName.." is in a duel. WATCH it, or QUEUE."); return end
   D.challenges[other]={from=player,at=tick}
   remote:FireClient(other,"Challenge",player.DisplayName)
   notify(player,"Challenge sent to "..other.DisplayName..".")
   return
  end
 end
 if action=="Accept" then
  local c=D.challenges[player]; D.challenges[player]=nil
  if data==false then if c and c.from.Parent then notify(c.from,player.DisplayName.." declined.") end; return end
  if not c or tick-c.at>30*60 or not c.from.Parent then notify(player,"That challenge has expired."); return end
  if not free(player) or not free(c.from) then notify(player,"One of you is busy or down. Try again in a moment."); return end
  if not D.start(c.from,player) then notify(player,"Every ring is busy. QUEUE to fight next."); return end
  return
 end
 -- R22 (Peter: "put a stop fight button"): ends the match on the spot, heals both fighters and frees them.
 if action=="StopFight" then
  -- R30: works any time, also in practice with no match running, and fully resets the fighters.
  local d=D.of[player]
  setPaused(false,player.DisplayName,true)
  duelStopped=true
  if d then
   for i,k in d.fighters do local st=stateOf(k); if st and alive(st) then resetFighter(st,D.mark(d,i),nil) end end
   D.finish(d,"Fight stopped • health reset")
  else
   D.practiceReset(player); idleRound(player,"Fight stopped • health reset • START FIGHT (R) to go again")
  end
  return
 end
 -- R34: RESET restarts the whole fight from round 1 with a fresh 3-2-1-GO. Works in practice too.
 if action=="ResetFight" then
  local d=D.of[player]
  setPaused(false,player.DisplayName,true)
  if d then
   duelStopped=false
   for _,k in d.fighters do if not alive(stateOf(k)) then notify(player,"Wait until both fighters are back up."); return end end
   d.wins={}; d.number=0; d.matchOver=false; logSummary(d); startRound(d)
   broadcastRound(d,"Fight reset • starting again")
  else
   D.practiceReset(player); idleRound(player,"Fight reset")
  end
  return
 end
 if action=="Restart" or (action=="Challenge" and data=="Bot") then
  local d=D.of[player]
  if not d then
   duelStopped=false
   -- Two players alone: START FIGHT just lets their duel start again on its own (as before R63).
   local players=Players:GetPlayers()
   if action=="Restart" and #players==2 and free(players[1]) and free(players[2]) then notify(player,"Your duel starts now."); return end
   -- START FIGHT: with the bot on and free, begin a best-of-3 against it (3-2-1-GO).
   if not botOn() then notify(player,"Turn the sparring bot on first, or QUEUE for a player."); return end
   if not dummy then notify(player,"The sparring bot is getting up. Try again in a moment."); return end
   if D.of.Bot then notify(player,"The sparring bot is busy with another duel. QUEUE for a player."); return end
   if not free(player) then return end
   if not D.start(player,"Bot") then notify(player,"Every ring is busy. QUEUE to fight next.") end
   return
  end
  setPaused(false,player.DisplayName,true)
  if not restartMatch(d) then notify(player,"Wait until both fighters are back up, then start over.") end
  return
 end
 -- v30: a press number is a whole number or nothing.
 if type(seq)~="number" or seq~=seq or seq<0 or seq>2^31 or seq%1~=0 then seq=nil end
 if paused and action~="Select" and action~="Reload" then if seq and s then ack(s,seq,false) end; return end
 if action=="Skin" then
  -- Cosmetic only (v15): repaint and re-armour the live character in place. No respawn, so health,
  -- position and the round are untouched, and it works any time you're not mid-attack, even in a match.
  if not s or type(data)~="string" then return end
  local skin,id=Rules.skin(s.hero,data); if id~=data then return end
  if not alive(s) then notify(player,"Pick a skin once you're back up."); return end
  if s.action then notify(player,"Finish the attack, then change skin."); return end
  Appearance.applySkin(s.model,s.hero,skin)
  s.skin=id; s.model:SetAttribute("Skin",id)
  gate.skins=gate.skins or {}; gate.skins[s.hero]=id
  notify(player,skin.Name.." skin on.")
  return
 end
 -- R65 (Peter: "I don't know how to do a reload, but do it"): MENU > Reload, or the client by itself when its
 -- fighter is under the floor or never appeared. Rebuilds the same hero and skin at the start spot. In a
 -- running duel only a fighter that is actually under the floor (or missing) can reload.
 if action=="Reload" then
  if gate.spawning or now<(gate.reloadAt or 0) then return end
  local below=s and alive(s) and s.root.Position.Y<-1.5
  if s and inDuel(player) and not D.of[player].matchOver and not below then notify(player,"Reload after the match (or when stuck under the floor)."); return end
  gate.reloadAt=now+5; gate.spawning=true
  if s then warn(("[HeroWars] reload for %s (%s, y=%.1f, asked by %s)"):format(player.Name,s.hero,s.root.Position.Y,tostring(data))) end
  local ok,err=pcall(spawnFighter,player,s and s.hero or "Solarion",false,s and s.skin)
  gate.spawning=false
  if not ok then warn(err); notify(player,"Reload failed. Try again.") else notify(player,"Fighter reloaded.") end
  return
 end
 if action=="Select" then
  if type(data)~="string" or not Rules.Characters[data] or gate.spawning then return end
  if inDuel(player) and not D.of[player].matchOver then notify(player,"Switch characters after the match."); return end
  -- R46 (Peter: "couldn't stop fight and reset to change my toon"): outside a match you can switch any
  -- time (STOP FIGHT or RESET ends one first). The out-of-combat rule only applies in a running duel.
  if s and inDuel(player) and (not alive(s) or tick-s.lastCombat<480 or s.action or tick<s.stunned or s.flying) then notify(player,"Switch after 8 seconds out of combat, on the ground."); return end
  if now<(gate.selectAt or 0) then return end
  gate.selectAt=now+3; gate.spawning=true
  local ok,err=pcall(spawnFighter,player,data,false,gate.skins and gate.skins[data]); gate.spawning=false
  if not ok then warn(err); notify(player,"Character could not load. Try again.") end
  return
 end
 if not alive(s) then if seq and s then ack(s,seq,false) end; return end
 if action=="Move" then
  if type(data)~="table" or typeof(data.dir)~="Vector3" or typeof(data.aim)~="Vector3" then return end
  if not Rules.validVector(data.dir.X,data.dir.Y,data.dir.Z) or not Rules.validVector(data.aim.X,data.aim.Y,data.aim.Z) or data.aim.Magnitude<0.9 then return end
  s.dir=data.dir; s.aim=data.aim.Unit; s.lock=data.lock==true; s.hasTarget=data.target==true; s.lastMove=tick; return
 end
 -- Queued and applied at the start of the next tick, in arrival order (step A).
 table.insert(s.inputs,{action,data,seq})
end
remote.OnServerEvent:Connect(function(player,action,data,seq) onServerEvent(player,action,data,seq,false) end)
D.onServerEvent=onServerEvent
local function update(s)
 if s.shadowCircle and (not alive(s) or tick>=s.shadowCircle.expires) then s.shadowCircle.visual:Destroy(); s.shadowCircle=nil end
 -- R47 Solar Absorb: enemies inside the sphere lose health and Solarion gains it.
 local sz=s.solarZone
 if sz and (not alive(s) or tick>=sz.expires or not sz.visual.Parent) then sz.visual:Destroy(); s.solarZone=nil; sz=nil end
 if sz and tick>=sz.nextAt then
  sz.nextAt=tick+sz.every
  for key,t in states do
   if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) and (t.root.Position-sz.center).Magnitude<=sz.radius then
    local dmg=math.min(soak(t,sz.absorb),t.hum.Health)
    if dmg>0 then
     t.hum:TakeDamage(dmg); t.lastHurt=tick; s.damage+=dmg
     s.hum.Health=math.min(s.hum.MaxHealth,s.hum.Health+dmg)
    end
    remote:FireAllClients("Fx",t.model,"Absorb",t.root.Position,dmg,s.model)
   end
  end
 end
 if s.dots then
  -- R49 Shade Bolt stacks: each ticks on its own clock.
  for i=#s.dots,1,-1 do
   local d=s.dots[i]
   if not alive(s) or d.left<=0 then table.remove(s.dots,i)
   elseif tick>=d.nextAt then
    d.left-=1; d.nextAt=tick+d.every
    local dmg=math.min(soak(s,d.dmg),s.hum.Health)
    if dmg>0 then
     s.hum:TakeDamage(dmg); s.lastHurt=tick
     if d.by and alive(d.by) then d.by.damage+=dmg; d.by.hum.Health=math.min(d.by.hum.MaxHealth,d.by.hum.Health+dmg*d.heal) end
    end
    remote:FireAllClients("Fx",s.model,"Shade",s.root.Position,dmg,d.by and d.by.model,#s.dots)
    if d.left<=0 then table.remove(s.dots,i) end
   end
  end
  if #s.dots==0 then s.dots=nil end
  local n=s.dots and #s.dots or nil
  if s.model:GetAttribute("ShadeStacks")~=n then s.model:SetAttribute("ShadeStacks",n) end
 end
 if s.snare then
  if tick>=s.snare.ends or not alive(s) then s.snare=nil; s.model:SetAttribute("Snared",false)
  else s.root.CFrame=CFrame.new(s.snare.pos)*s.root.CFrame.Rotation; s.root.AssemblyLinearVelocity=Vector3.zero end
 end
 if s.drain and tick>=s.drain.nextAt then
  local dr=s.drain
  if alive(s) and dr.left>0 then
   dr.left-=1; dr.nextAt=tick+dr.every
   local dmg=soak(s,dr.dmg*(tick<(s.shieldUntil or 0) and (Rules.Defensives[s.hero].DamageScale or 1) or 1))
   dmg=math.min(dmg,s.hum.Health)
   s.hum:TakeDamage(dmg); s.lastHurt=tick
   local by=dr.by
   if by and alive(by) then
    by.damage+=dmg
    by.hum.Health=math.min(by.hum.MaxHealth,by.hum.Health+dmg*dr.heal)
   end
   remote:FireAllClients("Fx",s.model,"Drain",s.root.Position,dmg,by and by.model)
   if dr.left==dr.ticks-1 then print(string.format("[HeroWars] Soul Drain tick: %s -%d, %s +%d",s.hero,dmg,by and by.hero or "?",dmg)) end
  end
  if dr.left<=0 or not alive(s) then s.drain=nil; s.model:SetAttribute("Drained",false) end
 end
 -- R41 Tempest's lightning tick: hurts on every tick and heals her by her heal stacks.
 if s.zapStacks and tick>=(s.zapUntil or 0) then s.zapStacks=nil; s.model:SetAttribute("ZapStacks",nil) end
 if s.zap and tick>=s.zap.nextAt then
  local z=s.zap; local Z=Rules.Tempest
  if alive(s) and z.left>0 then
   z.left-=1; z.nextAt=tick+Z.ZapEvery
   local dmg=math.min(soak(s,Z.ZapDamage),s.hum.Health)
   local heal=0; local by=z.by
   if dmg>0 then
    s.hum:TakeDamage(dmg); s.lastHurt=tick
    if by and alive(by) then
     by.damage+=dmg
     heal=dmg*Z.StackHeal*(by.zapStacks or 0)
     by.hum.Health=math.min(by.hum.MaxHealth,by.hum.Health+heal)
    end
   end
   remote:FireAllClients("Fx",s.model,"Zap",s.root.Position,dmg,by and by.model,heal,by and by.zapStacks or 0)
   if not z.logged then z.logged=true; print(string.format("[HeroWars] Lightning tick: %s -%d, Tempest +%.2f (%d stacks)",s.hero,dmg,heal,by and by.zapStacks or 0)) end
  end
  if z.left<=0 or not alive(s) then s.zap=nil; s.model:SetAttribute("Zapped",false) end
 end
 -- R36: Juggernaut stacks fade 4 s after his last hit; a wall splat lands when the carry ends.
 if s.jugg and s.jugg>0 and tick>=(s.juggUntil or 0) then s.jugg=0; s.model:SetAttribute("Juggernaut",0) end
 if s.splat and tick>=s.splat.at then
  local sp=s.splat; s.splat=nil
  if alive(s) then
   local B=Rules.Bulwark
   s.hum:TakeDamage(B.SplatDamage); s.lastHurt=tick
   if sp.by then sp.by.damage+=B.SplatDamage end
   s.dr=s.dr or {}; local dr=s.dr.Stun; if not dr or tick>dr.untilTick then dr={count=0,untilTick=0}; s.dr.Stun=dr end
   local stun,immune=Rules.drStun(B.SplatStun,dr.count)
   dr.count+=1; dr.untilTick=tick+Rules.StunDR.Reset
   if not immune then s.stunned=math.max(s.stunned,tick+stun); s.model:SetAttribute("StunEnd",workspace:GetServerTimeNow()+stun/60) end
   remote:FireAllClients("Fx",s.model,"WallSplat",s.root.Position,B.SplatDamage)
  end
 end
 -- R35 (Peter: "Wraith circle needs to be more potent, let it do damage"): enemies standing in it burn.
 local zone=s.shadowCircle
 if zone and zone.burn and tick>=zone.nextBurn then
  zone.nextBurn=tick+(zone.every or 30)
  for key,t in states do
   if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) and tick>=(t.invulnerable or 0) then
    local delta=t.root.Position-zone.center
    if Vector3.new(delta.X,0,delta.Z).Magnitude<=zone.radius and math.abs(delta.Y)<=6 then
     local dmg=soak(t,zone.burn*(tick<(t.shieldUntil or 0) and (Rules.Defensives[t.hero].DamageScale or 1) or 1))
     t.hum.Health=math.max(0,t.hum.Health-dmg); t.lastHurt=tick
     remote:FireAllClients("Fx",t.model,"CircleBurn",t.root.Position,math.floor(dmg+0.5))
    end
   end
  end
 end
 if not alive(s) then return end
 -- R19: Fury shows on everyone's nameplate, so it goes out as a whole-number attribute when it changes.
 do local f=math.floor(s.fury or 0); if s.furyShown~=f then s.furyShown=f; s.model:SetAttribute("Fury",f) end end
 if s.isDummy then botThink(s) end
 local locked=tick<s.stunned
 local frozen=tick<(s.hitstop or 0)
 local held=tick<(s.holdUntil or 0)
 if tick-(s.lastMove or -600)>30 then s.dir=Vector3.zero; s.lock=false end
 local pouncing=s.action and (s.action.name=="Pounce" or s.action.leapUp) and Rules.phase(s.action.move,s.action.frame,s.action.extra)~="Recovery"
 -- v30 step C: the server moves the fighter while something forces it; otherwise its own client does.
 local forced=not s.player or (locked and not s.blockStunned) or held or pouncing or s.knock or s.pull or s.carry
  or s.whirl or s.snare or s.launch or (s.action and s.action.move.Teleport)
 if forced then setOwner(s,false); s.freeSince=nil
 elseif not s.owned then
  s.freeSince=s.freeSince or tick
  if tick-s.freeSince>=Rules.Net.ReturnDelay then setOwner(s,true) end
 end
 local owned=s.owned
 local stopped=locked or frozen or held
 if s.model:GetAttribute("Locked")~=stopped then s.model:SetAttribute("Locked",stopped) end
 local speed=Rules.Characters[s.hero].Speed*(tick<(s.speedUntil or 0) and s.speedScale or 1)*(1+Rules.Bulwark.StackSpeed*(s.jugg or 0)) -- R35 slam boost, R36 stacks
 local flatDir=Vector3.new(s.dir.X,0,s.dir.Z); local facing=flatUnit(s.aim,s.root.CFrame.LookVector)
 if s.lock and flatDir.Magnitude>0.1 and flatDir.Unit:Dot(facing)<-0.3 then speed*=Rules.BackpedalScale end
 if not owned then
  s.hum.WalkSpeed=(locked or frozen or pouncing or held) and 0 or s.block and 7 or s.action and 9 or speed
  s.hum.JumpPower=(locked or held or s.block or s.action or s.flying) and 0 or (Rules.Characters[s.hero].JumpPower or 45) -- R66-ui10 per hero
  -- Server-moved: drive the humanoid from validated intent.
  s.hum:Move((locked or frozen or pouncing or held or s.flying or (s.isDummy and not botOn())) and Vector3.zero or flatDir,false)
  -- R66-ui10: the sparring bot climbs like a player (Wraithstep walls, Bulwark ledges) and jumps what it can get over.
  if s.isDummy and botOn() and not (locked or frozen or pouncing or held or s.flying or s.action) and D.Climb then
   D.Climb.step(Rules.Climb[s.hero] or Rules.Climb.Default,s.model,s.root,s.hum,flatDir,{autoJump=true})
  end
 end
 if s.block and not owned then
  local flat=Vector3.new(s.aim.X,0,s.aim.Z)
  if flat.Magnitude>0.01 then s.root.CFrame=CFrame.lookAt(s.root.Position,s.root.Position+flat) end
 end
 -- Blockstun keeps the guard up; any other stun drops it.
 -- The buffer survives stun so a reversal can be pressed just before recovering (step A).
 if locked then s.action=nil; if not s.blockStunned then s.block=false end; stopFlight(s)
 else s.blockStunned=false end
 -- Holding block brings the guard back as soon as the fighter is free (no parry window on re-raise).
 if s.blockHeld and not s.block and not locked and not held and not s.action and not s.flying and tick>=s.dashUntil then
  s.block=true; s.blockAt=-600
 end
 if s.carry and not frozen and tick>=s.carry.start then
  -- v28 Titan Drop: up in an arc and down hard; the victim is held upside down until the impact.
  local c=s.carry; local k=math.min(1,(tick-c.start+1)/c.ticks)
  local p=c.from:Lerp(c.to,k)+Vector3.new(0,c.height*4*k*(1-k),0)
  s.root.CFrame=CFrame.new(p)*(k<1 and c.rot or c.up)
  s.root.AssemblyLinearVelocity=Vector3.zero
  if k>=1 then
   s.carry=nil
   if c.land then remote:FireAllClients("Fx",c.by,"TitanDropLand",s.root.Position) end
  end
 end
 if s.whirl then
  local w=s.whirl
  if tick>=w.ends then s.whirl=nil; s.model:SetAttribute("Whirl",false)
  elseif tick>=w.start then
   local k=math.min(1,(tick-w.start)/20)
   s.root.CFrame=CFrame.new(w.base+Vector3.new(0,w.height*k+math.sin(tick*0.2)*0.4,0))*CFrame.Angles(0,tick*0.35,0)
   s.root.AssemblyLinearVelocity=Vector3.zero
  end
 end
 -- v28 Wraithstep regenerates slowly once he hasn't been hit for a while.
 local regen=Rules.Characters[s.hero].Regen
 if regen and tick-(s.lastHurt or -100000)>=regen.Delay and s.hum.Health<s.hum.MaxHealth then
  s.hum.Health=math.min(s.hum.MaxHealth,s.hum.Health+regen.PerSecond/60)
 end
 if s.shadowUntil and tick>=s.shadowUntil then
  s.shadowUntil=nil; s.model:SetAttribute("ShadowForm",false)
  if tick<(s.invisibleUntil or 0) and tick>=(s.revealedUntil or 0) then s.model:SetAttribute("Invisible",true) end
 end
 -- Record the last invisible tick before clearing it, including natural expiry.
 updateSneak(s)
 if s.model:GetAttribute("Invisible") and tick>=(s.invisibleUntil or 0) then s.model:SetAttribute("Invisible",false) end
 if s.phaseStart and tick<(s.phaseUntil or 0) then
  -- R50 Phase glitches: a short flicker into view at each mark.
  local P=Rules.Moves.Phase; local el=tick-s.phaseStart; local on=false
  for _,at in P.Glitches or {} do if el>=at*60 and el<at*60+(P.GlitchTicks or 18) then on=true end end
  if on~=s.glitching then
   s.glitching=on
   s.model:SetAttribute("Invisible",not on and tick>=(s.revealedUntil or 0))
   if on then remote:FireAllClients("Fx",s.model,"Glitch",s.root.Position) end
  end
 elseif s.phaseStart then s.phaseStart=nil; s.glitching=nil end
 local shrouded=s.hero=="Wraithstep" and inShadow(s)
 if s.model:GetAttribute("Shrouded")~=shrouded then s.model:SetAttribute("Shrouded",shrouded) end
 updateSneak(s)
 if s.pull and not frozen and tick>=s.pull.start then
  -- Grapple reel-in: the target is dragged to the attacker's feet.
  local k=math.min(1,(tick-s.pull.start+1)/s.pull.ticks)
  s.root.CFrame=CFrame.new(s.pull.from:Lerp(s.pull.to,k))*s.root.CFrame.Rotation
  s.root.AssemblyLinearVelocity=Vector3.zero
  if k>=1 then s.pull=nil end
 end
 s.fury=math.min(Rules.Fury.Max,s.fury+Rules.Fury.Regen/60)
 local shielded=tick<(s.shieldUntil or 0)
 if s.model:GetAttribute("Shielded")~=shielded then s.model:SetAttribute("Shielded",shielded) end
 if s.shieldHP and tick>=(s.absorbUntil or s.shieldUntil or 0) then s.shieldHP=nil; s.absorbUntil=nil; s.model:SetAttribute("ShieldHP",nil) end
 local parrying=tick<(s.parryUntil or 0)
 if s.model:GetAttribute("Parrying")~=parrying then s.model:SetAttribute("Parrying",parrying) end
 if frozen then
  -- Hit-stop: both fighters hang for a few ticks on contact. The input buffer's clock stops too.
  if s.buffer then s.buffer.expires+=1 end
  if not owned then local v=s.root.AssemblyLinearVelocity; s.root.AssemblyLinearVelocity=Vector3.new(0,math.min(v.Y,0),0) end
 end
 if s.knock and not frozen and tick>=s.knock.start then
  -- Knockback slides the fighter back over 8 ticks, fastest first.
  local i=tick-s.knock.start
  if i>=8 or not slide(s,s.knock.dir*s.knock.push*(8-i)/36) then s.knock=nil end
 end
 if s.launch and not frozen and tick>=s.launch.at then
  local v=s.root.AssemblyLinearVelocity; s.root.AssemblyLinearVelocity=Vector3.new(v.X,s.launch.speed,v.Z); s.launch=nil
 end
 if s.flying then
  s.energy=math.max(0,s.energy-Rules.Flight.Drain/60); s.lastFlight=tick
  local direction=(s.action or frozen) and Vector3.zero or s.dir
  local velocity=direction*Rules.Flight.Speed
  if tick-s.flightStart<Rules.Flight.TakeoffSeconds*60 then velocity=Vector3.new(0,Rules.Flight.TakeoffRise,0) end
  if s.root.Position.Y>=Rules.ceiling(s.hero)+3 then velocity=Vector3.new(velocity.X,math.min(0,velocity.Y),velocity.Z) end
  if not owned then s.velocity.VectorVelocity=velocity end
  -- R20: a flyer the server moves (the bot, or before the client owns movement) levels out when still.
  if not owned and velocity.Magnitude<0.5 and s.root.CFrame.UpVector.Y<0.999 then
   local look=Vector3.new(s.root.CFrame.LookVector.X,0,s.root.CFrame.LookVector.Z)
   if look.Magnitude>0.01 then
    s.root.CFrame=s.root.CFrame:Lerp(CFrame.lookAt(s.root.Position,s.root.Position+look.Unit),0.2)
    s.root.AssemblyAngularVelocity=Vector3.zero
   end
  end
  if s.energy<=0 then stopFlight(s)
  -- v47 (Peter: Tempest "floating, stiff legs"): flight never ended at ground level, so a flyer who came
  -- down kept hovering in the flight pose with her legs locked. Touching down (not rising) now lands.
  elseif tick-s.flightStart>30 and (s.dir.Y or 0)<=0.1 and heightAboveGround(s)<1.6 then stopFlight(s) end
 elseif tick-s.lastFlight>=Rules.Flight.Delay and (s.hum.FloorMaterial~=Enum.Material.Air or heightAboveGround(s)<1) then
  s.energy=math.min(100,s.energy+Rules.Flight.Recharge/60)
 end
 if not locked and not frozen and not owned then
  local dashSpeed=Rules.Characters[s.hero].DashSpeed
  if tick<s.dashUntil then
   s.root.AssemblyLinearVelocity=s.dashDir*dashSpeed+Vector3.new(0,s.root.AssemblyLinearVelocity.Y,0)
  elseif s.dashDir and tick<s.dashUntil+6 then
   -- Slide out of the dash instead of stopping dead.
   local k=1-(tick-s.dashUntil)/6
   s.root.AssemblyLinearVelocity=s.dashDir*dashSpeed*0.45*k+Vector3.new(0,s.root.AssemblyLinearVelocity.Y,0)
  end
 end
 if s.action and s.recoverBy and tick>=s.recoverBy and not frozen then
  -- Knockdown combo ender: the attacker is free a little before the victim stands up.
  s.action=nil; s.recoverBy=nil
 end
 if s.action and not frozen then
  local a=s.action; a.frame+=1; local phase=Rules.phase(a.move,a.frame,a.extra)
  -- v28 (Peter): with a target selected, keep turning to face it through the wind-up, so the hitbox
  -- goes where the target is. (Leaps and teleports already chose their path.)
  if phase=="Startup" and s.hasTarget and not a.leapUp and a.name~="Pounce" and not a.move.Teleport and not a.move.Aoe then
   a.aim=s.aim
   local flat=Vector3.new(a.aim.X,0,a.aim.Z)
   if flat.Magnitude>0.01 and not owned then s.root.CFrame=CFrame.lookAt(s.root.Position,s.root.Position+flat) end
  end
  if a.frame==1 and a.move.ShieldThrow then
   -- R37 Shield Throw: the client draws the spinning shield out to the hit and back to his hand.
   local hand=s.model:FindFirstChild("LeftHand") or s.root
   remote:FireAllClients("Fx",s.model,"ShieldThrow",hand.Position,flatUnit(a.aim,s.root.CFrame.LookVector),a.move.Range,a.move.Startup/60)
  end
  if phase=="Active" and a.frame==a.move.Startup+1 and s.hero=="Bulwark" and a.name=="Heavy" then
   -- R36: every Cleave cracks the ground in front; at 5 Juggernaut stacks it's a 20-stud shockwave.
   local B=Rules.Bulwark
   local front=s.root.Position+flatUnit(a.aim,s.root.CFrame.LookVector)*4
   if (s.jugg or 0)>=B.StackMax then
    a.move=table.clone(a.move); a.move.Range=B.ShockRange; a.move.Width=B.ShockWidth
    a.move.Damage*=B.ShockDamage; a.move.BreaksGuard=true
    s.jugg=0; s.model:SetAttribute("Juggernaut",0)
    remote:FireAllClients("Fx",s.model,"Shockwave",s.root.Position,flatUnit(a.aim,s.root.CFrame.LookVector),B.ShockRange)
   else remote:FireAllClients("Fx",s.model,"Quake",front,0.45) end
  end
  if phase=="Active" and a.frame==a.move.Startup+1 then
   if a.move.Phase then
    -- R49 Phase: vanish now for Phase ticks; attacks and hits don't end it (see endInvisible).
    s.phaseUntil=tick+a.move.Phase; s.phaseStart=tick; s.glitching=false; s.shadowUntil=nil; s.model:SetAttribute("ShadowForm",false)
    s.invisibleUntil=math.max(s.invisibleUntil or 0,s.phaseUntil)
    if tick>=(s.revealedUntil or 0) then s.model:SetAttribute("Invisible",true) end
    s.model:SetAttribute("PhaseEnd",workspace:GetServerTimeNow()+a.move.Phase/60)
    remote:FireAllClients("Fx",s.model,"Vanish",s.root.Position,false)
   end
   if a.move.Mist then
    -- R47 (Peter): casting Whirlwind wraps Tempest in a mist cloud: half damage for 3x the spin.
    s.mistUntil=tick+a.move.Mist; s.mistScale=a.move.MistScale or 0.5
    s.model:SetAttribute("MistEnd",workspace:GetServerTimeNow()+a.move.Mist/60)
   end
   if a.move.SolarAbsorb then
    -- R47 (Peter: "a solar absorb... a 3D sphere, white glowing red"): a sphere around where he stands.
    if s.solarZone then s.solarZone.visual:Destroy() end
    local m=a.move; local center=s.root.Position
    local visual=Instance.new("Model"); visual.Name="SolarAbsorbZone"; visual:SetAttribute("Owner",s.model.Name)
    local ball=Instance.new("Part"); ball.Name="Sphere"; ball.Shape=Enum.PartType.Ball; ball.Size=Vector3.one*m.Radius*2
    ball.CFrame=CFrame.new(center); ball.Anchored=true; ball.CanCollide=false; ball.CanTouch=false; ball.CanQuery=false; ball.CastShadow=false
    ball.Color=Color3.fromRGB(255,245,240); ball.Material=Enum.Material.ForceField; ball.Transparency=0.15; ball.Parent=visual
    local core=ball:Clone(); core.Name="Core"; core.Size=Vector3.one*m.Radius*2*0.97; core.Material=Enum.Material.Glass
    core.Color=Color3.fromRGB(255,235,230); core.Transparency=0.88; core.Parent=visual
    local glow=Instance.new("Highlight"); glow.FillColor=Color3.fromRGB(255,40,40); glow.FillTransparency=0.85
    glow.OutlineColor=Color3.fromRGB(255,60,50); glow.OutlineTransparency=0; glow.DepthMode=Enum.HighlightDepthMode.Occluded; glow.Parent=visual
    local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(255,50,40); light.Range=m.Radius*2; light.Brightness=3; light.Parent=ball
    local bb=Instance.new("BillboardGui"); bb.Size=UDim2.fromOffset(190,40); bb.AlwaysOnTop=true; bb.MaxDistance=120
    bb.StudsOffset=Vector3.new(0,m.Radius+1,0); bb.Parent=ball
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.fromScale(1,1); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamBold
    lbl.TextScaled=true; lbl.TextColor3=Color3.fromRGB(255,120,100); lbl.TextStrokeTransparency=.3; lbl.Parent=bb
    visual.Parent=workspace
    s.solarZone={center=center,radius=m.Radius,expires=tick+m.Duration,visual=visual,absorb=m.Absorb,every=m.AbsorbEvery,nextAt=tick+m.AbsorbEvery}
    task.spawn(function()
     for left=math.floor(m.Duration/60+.5),1,-1 do
      if not visual.Parent then return end
      lbl.Text=string.format("SOLAR ABSORB • %ds",left)
      task.wait(1)
     end
    end)
    remote:FireAllClients("Fx",s.model,"SolarAbsorb",center,m.Radius)
   end
   if a.move.ShadowCircle then
    if s.shadowCircle and s.shadowCircle.visual then s.shadowCircle.visual:Destroy() end
    local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
    local excluded={}; for key,t in states do if typeof(key)=="Instance" and key:IsA("Model") then table.insert(excluded,key) end end
    params.FilterDescendantsInstances=excluded
    local floor=workspace:Raycast(s.root.Position,Vector3.new(0,-100,0),params)
    local center=floor and floor.Position+Vector3.new(0,.08,0) or s.root.Position-Vector3.new(0,3,0)
    local visual=Instance.new("Model"); visual.Name="ShadowCircleZone"; visual:SetAttribute("Owner",s.model.Name)
    local function piece(name,size,cf,color,alpha)
     local p=Instance.new("Part"); p.Name=name; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
     p.CastShadow=false; p.Size=size; p.CFrame=cf; p.Color=color; p.Material=Enum.Material.Neon; p.Transparency=alpha; p.Parent=visual
     return p
    end
    local radius=a.move.Radius
    local disc=piece("ShadowPool",Vector3.new(.08,radius*2,radius*2),CFrame.new(center)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(34,12,57),.35)
    disc.Shape=Enum.PartType.Cylinder
    for i=1,40 do
     local angle=i*math.pi*2/40
     local at=center+Vector3.new(math.cos(angle)*radius,.04,math.sin(angle)*radius)
     piece("RuneEdge",Vector3.new(.18,.1,radius*2*math.pi/40*.85),CFrame.lookAt(at,center+Vector3.new(0,.04,0))*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(160,85,235),.1)
    end
    -- R17 (R16 audit 4): a floating label shows the bonus and the seconds left; the rim fades in the last 2 s.
    local tag=piece("CircleLabel",Vector3.one*.2,CFrame.new(center+Vector3.new(0,3.5,0)),Color3.new(),1)
    local bb=Instance.new("BillboardGui"); bb.Size=UDim2.fromOffset(190,40); bb.AlwaysOnTop=true; bb.MaxDistance=120; bb.Parent=tag
    local lbl=Instance.new("TextLabel"); lbl.Size=UDim2.fromScale(1,1); lbl.BackgroundTransparency=1; lbl.Font=Enum.Font.GothamBold
    lbl.TextScaled=true; lbl.TextColor3=Color3.fromRGB(205,150,255); lbl.TextStrokeTransparency=.3; lbl.Parent=bb
    local seconds=math.floor(a.move.Duration/60+.5); local bonus=math.floor((a.move.Multiplier-1)*100+.5)
    task.spawn(function()
     for left=seconds,1,-1 do
      if not visual.Parent then return end
      lbl.Text=string.format("SHADOW CIRCLE +%d%% • %ds",bonus,left)
      if left<=2 then for _,p in visual:GetChildren() do if p.Name=="RuneEdge" then p.Transparency=left==2 and .4 or .7 end end end
      task.wait(1)
     end
    end)
    -- R22 (Peter: "no shadow circle fx asset or animation"): the pool breathes dark mist and purple wisps
    -- rise round the rim, lit from inside.
    do
     local function wisps(at,color,rate,speed,size,life)
      local att=Instance.new("Attachment"); att.Parent=disc; att.WorldCFrame=CFrame.new(at)
      local e=Instance.new("ParticleEmitter"); e.Texture="rbxasset://textures/particles/smoke_main.dds"
      e.Color=ColorSequence.new(color); e.LightEmission=0.4; e.LightInfluence=0; e.Rate=rate
      e.Lifetime=NumberRange.new(life*0.7,life); e.Speed=NumberRange.new(speed*0.5,speed); e.EmissionDirection=Enum.NormalId.Top
      e.SpreadAngle=Vector2.new(12,12); e.Rotation=NumberRange.new(0,360); e.RotSpeed=NumberRange.new(-60,60)
      e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*0.4),NumberSequenceKeypoint.new(1,size)})
      e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5),NumberSequenceKeypoint.new(1,1)})
      e.Acceleration=Vector3.new(0,1.5,0); e.Parent=att
     end
     for i=1,8 do
      local angle=i*math.pi*2/8
      wisps(center+Vector3.new(math.cos(angle)*radius*0.92,0.2,math.sin(angle)*radius*0.92),Color3.fromRGB(150,70,230),5,3,1.4,1.4)
     end
     wisps(center+Vector3.new(0,0.2,0),Color3.fromRGB(25,10,40),14,1,radius*0.6,2.2)
     local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(150,70,230); light.Range=radius*1.4; light.Brightness=2; light.Parent=disc
    end
    visual.Parent=workspace
    s.shadowCircle={center=center,radius=radius,expires=tick+a.move.Duration,visual=visual,
     mult=a.move.Multiplier,burn=a.move.Burn,every=a.move.BurnEvery,nextBurn=tick+(a.move.BurnEvery or 30)}
    game:GetService("Debris"):AddItem(visual,a.move.Duration/60)
   end
   if a.move.Teleport then
    -- v28 Shadow Door / Dimension Door: step out on the ring behind the target.
    local t=a.target
    local spot=t and alive(t) and doorSpot(s,t,a.move)
    if spot then
     local from=s.root.Position
     stopFlight(s)
     s.root.CFrame=CFrame.lookAt(spot,Vector3.new(t.root.Position.X,spot.Y,t.root.Position.Z))
     s.root.AssemblyLinearVelocity=Vector3.zero
     remote:FireAllClients("Fx",s.model,"Teleport",from,a.name)
     -- R23: Dimension Door lands with a slam that grounds flyers.
     if a.move.Arrive then hitTargets(s,a); remote:FireAllClients("Fx",s.model,"DoorSlam",s.root.Position) end
    else
     -- v29: no room, so give back the Fury and the cooldown.
     if a.move.Cost then s.fury=math.min(Rules.Fury.Max,s.fury+a.move.Cost) end
     s.cooldowns[a.name]=tick
     notify(s.player,"No room to step out there (Fury refunded)")
    end
   end
   if a.move.Reveal then
    -- v28 Solar Flare: everyone close by is lit up, which also ends (and blocks) Vanish.
    for key,t in states do
     if typeof(key)=="Instance" and key:IsA("Model") and t~=s and alive(t) and foe(s,t) and (t.root.Position-s.root.Position).Magnitude<=a.move.Reveal then
      endInvisible(t); t.revealedUntil=tick+a.move.RevealTicks
      t.model:SetAttribute("RevealEnd",workspace:GetServerTimeNow()+a.move.RevealTicks/60)
     end
    end
    remote:FireAllClients("Fx",s.model,a.move.HolyRing and "HolyRing" or "SolarFlare",s.root.Position,a.move.Aoe or a.move.Reveal)
   end
   if a.move.SpeedBuff then
    -- R35 (Peter: "the slam should give him a speed buff").
    s.speedUntil=tick+a.move.SpeedTicks; s.speedScale=a.move.SpeedBuff
    s.model:SetAttribute("SpeedBuffEnd",workspace:GetServerTimeNow()+a.move.SpeedTicks/60)
    s.model:SetAttribute("SpeedBuff",a.move.SpeedBuff)
   end
  end
  -- R30: Bulwark's Charge (and his Charge leap) ends in an earthquake where he plants his feet.
  if s.hero=="Bulwark" and a.name=="Charge" and phase=="Recovery" and not a.quaked then
   a.quaked=true; remote:FireAllClients("Fx",s.model,"Quake",s.root.Position,1)
  end
  if phase=="Startup" and a.move.Lunge and not owned then
   -- Step in behind the punch so even a miss has weight.
   slide(s,flatUnit(a.aim,s.root.CFrame.LookVector)*a.move.Lunge/a.move.Startup)
  end
  if a.name=="Pounce" and phase=="Active" and not a.landed then pounceStep(s,a)
  elseif a.leapUp and phase=="Active" then chargeLeapStep(s,a)
  elseif a.move.Teleport or a.move.ShadowCircle or a.move.SolarAbsorb or a.move.Phase then -- no hitbox
  elseif phase=="Active" and a.move.Pulses then
   -- R22 Solar Hammer photon pulses: each pulse is its own hit along the aim, PulseGap ticks apart.
   a.pulsed=a.pulsed or 0
   if a.pulsed<a.move.Pulses and a.frame-a.move.Startup-1>=a.pulsed*a.move.PulseGap then
    a.pulsed+=1; a.hit={}
    hitTargets(s,a)
    local hand=s.model:FindFirstChild("RightHand")
    remote:FireAllClients("Fx",s.model,"Pulse",hand and hand.Position or s.root.Position,a.aim,a.move.Range)
   end
  elseif phase=="Active" then hitTargets(s,a) end
  if s.action==a and phase=="Recovery" and not a.recovering then
   a.recovering=true
   if Rules.isMelee(a.name) and not a.confirmed and not a.move.Teleport then
    a.extra=a.move.Whiff or 0
    remote:FireAllClients("Whiff",s.model,a.name)
   end
  end
  -- Cancels (step B): after contact, a buffered press listed in Rules.Cancels cuts the move short.
  -- Whiffs never cancel. If the new move can't start yet (cooldown, Fury), the old one carries on.
  if s.action~=a then
  elseif a.contact and s.buffer and tick<=s.buffer.expires
   and Rules.canCancel({name=a.name,contact=true,blocked=not a.anyHit},s.buffer.input) then
   s.action=nil
   if tryInput(s,s.buffer.input,true)=="ok" then
    ack(s,s.buffer.seq,true); s.buffer=nil; remote:FireAllClients("Fx",s.model,"Cancel",a.name)
   else s.action=a end
  end
  if s.action==a and Rules.phase(a.move,a.frame,a.extra)=="Idle" then s.action=nil end
 end
 if owned then -- the client turns its own fighter
 elseif s.lock and not s.action and not s.flying and not locked and not s.block then
  -- WoW-style lock-on: face the selected target and strafe around it.
  s.hum.AutoRotate=false
  s.root.CFrame=CFrame.lookAt(s.root.Position,s.root.Position+facing)
 elseif not s.action and not s.flying then s.hum.AutoRotate=true end
 if s.buffer then
  -- Fire the buffered press on the first tick it can happen; Defensive can also cut into an action.
  local b=s.buffer
  if tick>b.expires then s.buffer=nil; ack(s,b.seq,false)
  elseif not s.action or b.input=="Defensive" then
   local result=tryInput(s,b.input,true)
   if result~="wait" then s.buffer=nil; ack(s,b.seq,result=="ok") end
  end
 end
 -- Test arena uses a single floor at Y=0. Higher terrain needs a local-ground altitude query.
 local p=s.root.Position
 local top=tick<(s.leapTop or 0) and TOP_HEIGHT or Rules.ceiling(s.hero)+3
 if owned then checkMove(s,locked,frozen,held); p=s.root.Position end
 -- R65: a body sunk under the floor (centre below y=-1.5 for 15 ticks, not flying) counts as a fall too.
 if p.Y< -1.5 and not s.flying then s.sunkTicks=(s.sunkTicks or 0)+1 else s.sunkTicks=0 end
 if math.abs(p.X)>88 or math.abs(p.Z)>88 or p.Y< -10 or s.sunkTicks>=15 or p.Y>top then
  -- R61 (Peter: a Solarion skin dropped through the floor): say who fell and in which look, once each,
  -- and after a second fall within 3 s put them back at their start spot, upright.
  if p.Y< -1.5 then
   s.sunkTicks=0
   if not s.fellLogged then s.fellLogged=true; warn(("[HeroWars] %s (skin %s, body %s) fell through the floor in %s at x=%d z=%d; put back"):format(s.hero,tostring(s.skin),tostring(s.model:GetAttribute("AppliedBody")),arenaName,math.floor(p.X),math.floor(p.Z))) end
   if tick-(s.lastFall or -999)<180 then
    local o=Vector3.new(0,4,s.isDummy and spotZ("Dummy",-22) or spotZ("Player",22))
    s.root.AssemblyLinearVelocity=Vector3.zero; placeAt(s,CFrame.lookAt(o,Vector3.new(0,4,spotZ("Round",0)))); p=o
   else
    local o=Vector3.new(math.clamp(p.X,-85,85),4,math.clamp(p.Z,-85,85))
    local look=Vector3.new(s.root.CFrame.LookVector.X,0,s.root.CFrame.LookVector.Z)
    placeAt(s,CFrame.lookAt(o,o+(look.Magnitude>0.05 and look.Unit or Vector3.new(0,0,-1))))
   end
   s.lastFall=tick
  else
   placeAt(s,CFrame.new(math.clamp(p.X,-85,85),math.clamp(p.Y,4,top),math.clamp(p.Z,-85,85))*s.root.CFrame.Rotation)
  end
 end
 -- R61 (Peter: "they lie down sometimes, correct that, don't break the automatic upright pose when flying"):
 -- a fighter on the ground tipped more than ~50 degrees for half a second is stood back up, keeping the way
 -- they face. Flyers are left to the client's own levelling.
 if not s.flying and alive(s) then
  local up=s.root.CFrame.UpVector
  if up.Y<0.65 then
   s.tippedSince=s.tippedSince or tick
   if tick-s.tippedSince>=30 then
    local look=Vector3.new(s.root.CFrame.LookVector.X,0,s.root.CFrame.LookVector.Z)
    if look.Magnitude<0.05 then look=Vector3.new(-up.X,0,-up.Z) end
    if look.Magnitude<0.05 then look=Vector3.new(0,0,-1) end
    local q=s.root.Position+Vector3.new(0,1,0)
    s.root.AssemblyAngularVelocity=Vector3.zero
    placeAt(s,CFrame.lookAt(q,q+look.Unit))
    s.hum:ChangeState(Enum.HumanoidStateType.GettingUp)
    s.tippedSince=nil
   end
  else s.tippedSince=nil end
 end
 -- Replicated so every client can draw the block shield and flight glow.
 if s.model:GetAttribute("Blocking")~=s.block then s.model:SetAttribute("Blocking",s.block) end
 if s.model:GetAttribute("Flying")~=s.flying then s.model:SetAttribute("Flying",s.flying) end
 if tick%6==0 and s.player then
  local cooldowns={}; for name,untilTick in s.cooldowns do cooldowns[name]=math.max(0,untilTick-tick)/60 end
  remote:FireClient(s.player,"State",{hero=s.hero,health=s.hum.Health,energy=s.energy,flying=s.flying,
   phase=locked and "Stunned" or s.block and "Blocking" or s.action and Rules.phase(s.action.move,s.action.frame,s.action.extra) or "Idle",
   move=s.action and s.action.name or "-",frame=s.action and s.action.frame or 0,tick=tick,
   damage=s.damage,hits=s.hits,cooldowns=cooldowns,ping=math.floor(s.player:GetNetworkPing()*1000),
   fury=s.fury,super=s.super or 0,gcd=math.max(0,s.gcd-tick)/60,owned=owned,snaps=s.snaps,maxHealth=s.hum.MaxHealth,shield=math.max(0,(s.shieldUntil or 0)-tick)/60})
 end
end
local accumulator=0
RunService.Heartbeat:Connect(function(dt)
 if paused then accumulator=0; return end
 accumulator+=dt; local steps=0
 while accumulator>=1/60 and steps<8 do
  accumulator-=1/60; steps+=1; tick+=1
  -- Fixed order (spawn index) so nothing depends on hash-table order (step A).
  local order={}
  for key,s in states do if typeof(key)=="Instance" and key:IsA("Model") then table.insert(order,s) end end
  table.sort(order,function(x,y) return x.index<y.index end)
  -- 1. Inputs that arrived since the last tick, in arrival order.
  for _,s in order do
   local queued=s.inputs; s.inputs={}
   if alive(s) then for _,q in queued do doAction(s,q[1],q[2],q[3]) end
   else for _,q in queued do ack(s,q[3],false) end end
  end
  -- 2. Simulate every fighter; attacks only collect contacts.
  for _,s in order do update(s) end
  -- 3. Apply all of this tick's contacts together, so same-tick hits trade.
  local batch=contacts; contacts={}
  table.sort(batch,function(x,y) return x.s.index<y.s.index end)
  for _,c in batch do
   if alive(c.t) then applyHit(c.s,c.a,c.t,c.scale,c.stun,c.splash,c.counter) end
  end
  -- 4. Record hurtboxes for lag compensation.
  for _,s in order do if alive(s) then recordHurtbox(s) end end
  roundStep()
 end
 if accumulator>0.25 then accumulator=0.25 end -- bounded catch-up; not rollback simulation
end)
local function onPlayer(player)
 remote:FireClient(player,"Arena",arenaName)
 task.spawn(D.loadStats,player)
 gates[player]={tokens=60,time=os.clock(),spawning=true}
 local hero=#Players:GetPlayers()%2==1 and "Solarion" or "Wraithstep"
 local ok,err=pcall(spawnFighter,player,hero,false)
 if gates[player] then gates[player].spawning=false end
 if not ok then warn(err); notify(player,"Rig load failed. Open the Lobby and press PLAY AS to retry.") end
end
Players.PlayerAdded:Connect(onPlayer)
Players.PlayerRemoving:Connect(function(player)
 if inDuel(player) then setPaused(false,player.DisplayName,true) end
 D.challenges[player]=nil; local qi=table.find(D.queue,player); if qi then table.remove(D.queue,qi) end
 local s=states[player]; if s then states[s.model]=nil; s.model:Destroy() end
 states[player]=nil; gates[player]=nil
 if D.vote then D.vote.yes[player]=nil; D.vote.no[player]=nil; task.defer(D.tallyVote) end
 D.saveStats(player,true)
end)
for _,player in Players:GetPlayers() do task.spawn(onPlayer,player) end
task.spawn(function()
 local ok,err=pcall(spawnFighter,nil,botHero,true); if not ok then warn("Training dummy: "..tostring(err)) end
end)
-- R66-ui: a still practice dummy beside every duel ring except the first (the sparring bot stands there).
task.delay(8,function()
 local heroes={"Bulwark","Tempest","Solarion","Wraithstep"}
 for i=2,#D.rings() do
  local ok,err=pcall(spawnFighter,nil,heroes[(i-2)%#heroes+1],"practice",nil,i); if not ok then warn("Practice dummy: "..tostring(err)) end
 end
end)
task.spawn(function()
 while true do
  task.wait(1)
  for key,st in states do
   if typeof(key)=="Instance" and st.isPractice and alive(st) and os.clock()-(st.practiceHurtAt or 0)>6 and st.hum.Health<st.hum.MaxHealth then
    st.hum.Health=st.hum.MaxHealth
   end
  end
 end
end)
task.spawn(function() while true do task.wait(120); for p in D.stats do D.saveStats(p) end end end)
game:BindToClose(function() for p in D.stats do D.saveStats(p) end; task.wait(2) end)
