-- Uploaded, licensed meshes fitted in build.py. Only cosmetics are cloned.
local Costumes={}
-- Templates were fitted to a smaller reference body. Measure the complete
-- armour group in limb space, then fit it to the actual reshaped R15 limb.
local function armourFit(group,limb)
 local lo,hi
 for _,part in group:GetChildren() do
  if part:IsA("MeshPart") and not string.find(part.Name,"BulwarkShield") then
   for _,x in {-.5,.5} do for _,y in {-.5,.5} do for _,z in {-.5,.5} do
    local p=part.CFrame:PointToWorldSpace(part.Size*Vector3.new(x,y,z))
    lo=lo and lo:Min(p) or p; hi=hi and hi:Max(p) or p
   end end end
  end
 end
 if not lo then return end
 local size=hi-lo
 if math.min(size.X,size.Y,size.Z)<=0 then return end
 local target=limb.Size*Vector3.new(1.12,1.04,1.16)
 return (lo+hi)/2,target/size,target
end
function Costumes.apply(character,hero)
 local bank=game:GetService("ReplicatedStorage"):FindFirstChild("HeroWarsAccessories")
 local template=bank and bank:FindFirstChild(hero)
 if not template then return false end
 local attached=0
 for _,group in template:GetChildren() do
  local limb=character:FindFirstChild(group.Name)
  if not limb then continue end
  local center,scale,target
  if hero=="Bulwark" then center,scale,target=armourFit(group,limb) end
  for _,source in group:GetChildren() do
   if not source:IsA("MeshPart") then continue end
   local part=source:Clone()
   part.Name="Imported_"..source.Name
   part.Anchored=false; part.Massless=true
   part.CanCollide=false; part.CanTouch=false; part.CanQuery=false
   part:SetAttribute("KitPiece",true); part:SetAttribute("ModernPiece",true)
   local offset=part.CFrame
   if scale and not string.find(source.Name,"BulwarkShield") then
    part.Size=part.Size*Vector3.new((offset.RightVector*scale).Magnitude,
     (offset.UpVector*scale).Magnitude,(offset.LookVector*scale).Magnitude)
    offset=CFrame.new((offset.Position-center)*scale)*offset.Rotation
    part:SetAttribute("ArmourFitTarget",target)
   end
   local tint=hero=="Tempest" and Color3.fromRGB(26,34,47) or hero=="Bulwark" and Color3.fromRGB(103,119,133) or Color3.fromRGB(78,84,96)
   part.Color=tint
   for _,surface in part:GetChildren() do
    if surface:IsA("SurfaceAppearance") then surface.Color=tint end
   end
   if hero=="Tempest" then part.Material=Enum.Material.Fabric end
   if source.Name=="SolarHelmet_2" then
    for _,surface in part:GetChildren() do if surface:IsA("SurfaceAppearance") then surface:Destroy() end end
    part.Color=Color3.fromRGB(78,44,12); part.Material=Enum.Material.Glass; part.Reflectance=.18
   end
   if string.find(source.Name,"BulwarkShield") then
    local pivot=CFrame.new(-.88,-.2,0)
    offset=pivot*CFrame.Angles(0,math.rad(35),0)*pivot:Inverse()*offset
    -- Keep the shield outside the newly fitted bracer.
    offset+=Vector3.new(-limb.Size.X*.56-.30+.88,0,0)
   end
   part.CFrame=limb.CFrame*offset; part.Parent=character
   local weld=Instance.new("Weld")
   weld.Name="CostumeWeld"; weld.Part0=limb; weld.Part1=part; weld.C0=offset; weld.Parent=part
   if string.find(source.Name,"BulwarkShield") then
    -- All four pieces animate around one pivot, retaining their relative transforms.
    local pivot=CFrame.new(-limb.Size.X*.56-.30,-.2,0)*CFrame.Angles(0,math.rad(35),0)
    weld.Name="ShieldWeld"
    weld:SetAttribute("ShieldPivot",pivot)
    weld:SetAttribute("ShieldPieceOffset",pivot:Inverse()*offset)
   end
   attached+=1
  end
 end
 if attached==0 then return false end
 for _,part in character:GetChildren() do
  local name=part.Name
  local remove=false
  if hero=="Solarion" then
   remove=name=="ClosedHelmet" or name=="OpaqueFaceplate" or name=="VisorSlit"
  elseif hero=="Bulwark" then
   remove=string.find(name,"TitanChestSegment") or string.find(name,"TitanShoulder") or string.find(name,"AlloyBand") or name=="TitanBackplate" or name=="TitanStatus" or name=="ShieldDisc" or name=="ShieldPowerStrip" or string.find(name,"Bracer")
  elseif hero=="Tempest" then
   remove=string.find(name,"CoatSkirt") or string.find(name,"StormglassPanel") or string.find(name,"CoatPiping")
  end
  if remove and part:GetAttribute("ModernPiece") then part:Destroy() end
 end
 character:SetAttribute("ImportedCostumeParts",attached)
 character:SetAttribute("ArtPass","V47-R7-ArmourFit")
 return true
end
return Costumes
