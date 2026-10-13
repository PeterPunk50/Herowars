-- Cosmetic geometry only: never touches motors, Humanoid scale, or combat hurtboxes.
local Style={}
local function piece(model,limbName,name,size,offset,color,material,wedge)
 local limb=model:FindFirstChild(limbName); if not limb then return end
 local p=Instance.new(wedge and "WedgePart" or "Part")
 p.Name=name; p.Size=size; p.Material=material or Enum.Material.Metal; p.Color=color
 p.Massless=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.CastShadow=true
 p:SetAttribute("KitPiece",true); p:SetAttribute("ModernPiece",true)
 p.CFrame=limb.CFrame*offset; p.Parent=model
 local weld=Instance.new("Weld"); weld.Name=name=="ShieldDisc" and "ShieldWeld" or name.."Weld"
 weld.Part0=limb; weld.Part1=p; weld.C0=offset; weld.Parent=p
 return p
end
local function face(model,hero)
 local head=model:FindFirstChild("Head"); local gui=head and head:FindFirstChild("HumanFace")
 if not gui then return end
 gui.Enabled=true
 gui:SetAttribute("BrowTilt",hero=="Bulwark" and 13 or 8)
 for _,v in gui:GetChildren() do
  if v.Name=="SunMark" or string.find(v.Name,"Blush") or string.find(v.Name,"Lash") then v:Destroy() end
 end
 local mouth=gui:FindFirstChild("Mouth")
 if mouth then mouth.Text="—"; mouth:SetAttribute("Calm","—"); mouth.TextSize=24 end
end
function Style.apply(model,hero,skin)
 if not skin.Modern then return end
 -- Retain catalog hair, replace old capes, medieval armor, masks and oversized trim.
 for _,v in model:GetChildren() do
  if v:GetAttribute("KitPiece") then
   local hair=v:IsA("Accessory") and (v.AccessoryType==Enum.AccessoryType.Hair or v:FindFirstChild("HairAttachment",true))
   if not hair then v:Destroy() end
  end
 end
 local dark=Color3.fromRGB(24,29,38); local steel=Color3.fromRGB(147,158,171)
 local amber=Color3.fromRGB(255,161,46); local ice=Color3.fromRGB(139,215,240)
 local skinTone=Color3.fromRGB(181,124,89)
 for _,v in model:GetChildren() do
  if v:IsA("BasePart") and v.Name~="HumanoidRootPart" and not v:GetAttribute("ModernPiece") and not string.find(v.Name,"Hurtbox") then
   v.Transparency=0; v:SetAttribute("BodyHidden",nil)
   v.Color=dark; v.Material=Enum.Material.SmoothPlastic
  end
 end
 model.Head.Color=hero=="Bulwark" and steel or skinTone
 for _,n in {"LeftHand","RightHand"} do model[n].Color=hero=="Bulwark" and steel or skinTone end
 face(model,hero)
 if hero=="Solarion" then
  for _,sign in {-1,1} do
   piece(model,"UpperTorso","SolarPectoral"..sign,Vector3.new(0.87,0.62,0.2),CFrame.new(sign*0.53,0.2,-0.59)*CFrame.Angles(0,0,sign*0.16),steel)
   piece(model,"UpperTorso","SolarAmberTrim"..sign,Vector3.new(0.7,0.07,0.08),CFrame.new(sign*0.47,0.4,-0.72)*CFrame.Angles(0,0,sign*0.18),amber,Enum.Material.Neon)
   piece(model,"UpperTorso","BackReactor"..sign,Vector3.new(0.36,0.95,0.35),CFrame.new(sign*0.52,0,0.66),dark)
   piece(model,"UpperTorso","ReactorVent"..sign,Vector3.new(0.16,0.65,0.08),CFrame.new(sign*0.52,0,0.88),amber,Enum.Material.Neon)
  end
  local core=piece(model,"UpperTorso","SolarCore",Vector3.new(0.38,0.38,0.14),CFrame.new(0,0.12,-0.74),amber,Enum.Material.Neon)
  if core then core.Shape=Enum.PartType.Ball end
  piece(model,"Head","ModernHair",Vector3.new(1.8,0.25,0.95),CFrame.new(0,0.57,0.07),Color3.fromRGB(27,20,18),Enum.Material.SmoothPlastic)
  for _,side in {"Left","Right"} do
   piece(model,side.."UpperArm",side.."SolarShoulder",Vector3.new(0.98,0.3,1.02),CFrame.new(0,0.38,0),steel)
   piece(model,side.."LowerLeg",side.."SolarShin",Vector3.new(0.66,0.88,0.14),CFrame.new(0,0,-0.51),steel)
  end
 elseif hero=="Tempest" then
  -- Split faceted coat panels hang from torso/hips; no humanoid size or motor changes.
  for _,sign in {-1,1} do
   for i=1,3 do
    local panel=piece(model,"LowerTorso","StormglassPanel"..sign..i,Vector3.new(0.5,1.6+i*0.2,0.12),CFrame.new(sign*(0.38+i*0.16),-0.65,0.35+i*0.07)*CFrame.Angles(0,sign*0.2,sign*(0.06+i*0.06)),ice,Enum.Material.Glass,true)
    if panel then panel.Transparency=0.42; panel.Reflectance=0.12 end
   end
   local collar=piece(model,"UpperTorso","GlassCollar"..sign,Vector3.new(0.62,0.3,0.4),CFrame.new(sign*0.7,0.52,0),ice,Enum.Material.Glass,true)
   if collar then collar.Transparency=0.35 end
  end
  piece(model,"UpperTorso","StormClasp",Vector3.new(0.18,0.18,0.12),CFrame.new(0,0.45,-0.61),ice,Enum.Material.Neon)
  if not model:FindFirstChildWhichIsA("Accessory") then
   local hair=piece(model,"Head","StormHair",Vector3.new(1.85,0.35,1),CFrame.new(0,0.55,0.06),Color3.fromRGB(29,25,31),Enum.Material.SmoothPlastic)
   if hair then hair.Shape=Enum.PartType.Ball end
   local bun=piece(model,"Head","StormBun",Vector3.new(0.75,0.65,0.65),CFrame.new(0,0.76,0.48),Color3.fromRGB(29,25,31),Enum.Material.SmoothPlastic)
   if bun then bun.Shape=Enum.PartType.Ball end
  end
 elseif hero=="Bulwark" then
  -- Segmented alloy anatomy and restrained industrial trim: no plume, skirt or bronze armor.
  for _,limb in {"Head","UpperTorso","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftHand","RightHand"} do
   model[limb].Color=steel; model[limb].Material=Enum.Material.Metal; model[limb].Reflectance=0.12
  end
  piece(model,"Head","TitanHair",Vector3.new(1.85,0.22,1),CFrame.new(0,0.58,0.05),dark,Enum.Material.SmoothPlastic)
  for i=1,4 do
   piece(model,"UpperTorso","TitanChestSegment"..i,Vector3.new(2.12,0.19,0.16),CFrame.new(0,0.45-i*0.21,-0.68),steel)
  end
  for _,side in {"Left","Right"} do
   local limb=model[side.."UpperArm"]
   for i=1,4 do
    piece(model,side.."UpperArm",side.."AlloyBand"..i,Vector3.new(limb.Size.X+0.08,0.045,limb.Size.Z+0.08),CFrame.new(0,(i-2.5)*0.22,0),dark)
   end
   piece(model,side.."UpperArm",side.."TitanShoulder",Vector3.new(1.25,0.35,1.3),CFrame.new(0,0.48,0),dark)
   piece(model,side.."LowerLeg",side.."TitanShin",Vector3.new(0.82,1.1,0.18),CFrame.new(0,0,-0.63),steel)
  end
  piece(model,"UpperTorso","TitanBackplate",Vector3.new(1.3,1.5,0.35),CFrame.new(0,0,0.8),dark)
  piece(model,"UpperTorso","TitanStatus",Vector3.new(0.7,0.07,0.07),CFrame.new(0,0.47,-0.8),Color3.fromRGB(97,217,191),Enum.Material.Neon)
  piece(model,"LeftLowerArm","ShieldDisc",Vector3.new(0.23,2.15,1.35),CFrame.new(-0.78,0,0),dark)
  piece(model,"ShieldDisc","ShieldPowerStrip",Vector3.new(0.04,1.6,0.12),CFrame.new(-0.14,0,0),Color3.fromRGB(97,217,191),Enum.Material.Neon)
 end
 -- Covered costume test pass. Wraith's non-Modern skin never enters this function.
 for _,v in model:GetChildren() do
  if v:IsA("Accessory") and v.AccessoryType==Enum.AccessoryType.Hair or v.Name=="ModernHair" or v.Name=="TitanHair" or v.Name=="StormHair" or v.Name=="StormBun" then v:Destroy() end
 end
 local head=model:FindFirstChild("Head")
 if head then
  head.Color=dark
  for _,v in head:GetDescendants() do
   if v:IsA("Decal") then v.Transparency=1 elseif v:IsA("SurfaceGui") then v.Enabled=false end
  end
 end
 local glow=hero=="Solarion" and amber or hero=="Tempest" and ice or Color3.fromRGB(97,217,191)
 local helmet=piece(model,"Head","ClosedHelmet",Vector3.new(2.04,1.12,1.12),CFrame.new(),dark)
 if helmet then helmet.Shape=Enum.PartType.Ball end
 piece(model,"Head","OpaqueFaceplate",Vector3.new(1.72,.78,.18),CFrame.new(0,-.04,-.56),dark)
 piece(model,"Head","VisorSlit",Vector3.new(1.5,.09,.04),CFrame.new(0,.17,-.67),glow,Enum.Material.Neon)
 for _,side in {"Left","Right"} do
  local hand=model:FindFirstChild(side.."Hand"); if hand then hand.Color=dark; hand.Material=Enum.Material.Metal end
  piece(model,side.."LowerArm",side.."Bracer",Vector3.new(.84,.68,1.04),CFrame.new(),hero=="Tempest" and dark or steel)
  piece(model,side.."Foot",side.."ArmoredBoot",Vector3.new(.86,.43,1.28),CFrame.new(0,0,-.05),dark)
 end
 if hero=="Tempest" then
  -- Opaque coat over the existing suit, with split skirt panels following each thigh.
  for _,v in model:GetChildren() do
   if string.find(v.Name,"StormglassPanel") or string.find(v.Name,"GlassCollar") then v.Color=dark; v.Material=Enum.Material.Fabric; v.Transparency=0 end
  end
  piece(model,"UpperTorso","StormCoatBodice",Vector3.new(2.08,1.58,1.12),CFrame.new(),dark,Enum.Material.Fabric)
  for _,side in {"Left","Right"} do
   piece(model,side.."UpperArm",side.."CoatSleeve",Vector3.new(.88,1.18,1.05),CFrame.new(),dark,Enum.Material.Fabric)
   piece(model,side.."UpperLeg",side.."CoatSkirt",Vector3.new(1.06,1.95,1.19),CFrame.new(0,-.12,0),dark,Enum.Material.Fabric)
   piece(model,side.."UpperLeg",side.."CoatPiping",Vector3.new(.055,1.7,.045),CFrame.new(side=="Left" and -.46 or .46,-.1,-.61),ice)
  end
  piece(model,"UpperTorso","CoatFrontSeam",Vector3.new(.06,1.35,.04),CFrame.new(0,0,-.58),ice)
 end
 require(script.Parent.MeshCostumes).apply(model,hero)
end
return Style
