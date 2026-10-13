local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Rules = require(RS.HeroWars.Rules)
local Appearance = {}
local ModernStyle = require(RS.HeroWars.ModernStyle)
local SKIN_TONE = Color3.fromRGB(181,124,89)
-- Smooth kit armour (v16): HeroWars_KitArmour.glb holds eight smooth shapes (Kit_RoundShell, Kit_LimbShell,
-- Kit_Pillow, Kit_Tile, Kit_Capsule, Kit_Barrel, Kit_Band, Kit_Dome). Import it once in Studio
-- (File > Import 3D); whatever the import is called, it is found by its meshes and moved here on first use.
-- Without it, every piece falls back to the v15 block version, so the game always runs.
local kitFolder
local triedDownload=false
local loading=false
local MESH_IDS={Kit_RoundShell="107304196364074",Kit_LimbShell="104133613344701",Kit_Pillow="113024271686346",
 Kit_Tile="108974579127757",Kit_Capsule="116485151927132",Kit_Barrel="86641790264593",Kit_Band="86779603589343",
 Kit_Dome="78527529959487"}
local function kitMeshes()
 if kitFolder and kitFolder.Parent then return kitFolder end
 -- v19: the bot and the player spawn at the same moment. Whoever comes second waits for the first
 -- download instead of getting nothing (that is what left the v18 bot in block armour).
 while loading do task.wait() end
 if kitFolder and kitFolder.Parent then return kitFolder end
 local home=RS.HeroWars
 kitFolder=home:FindFirstChild("KitArmour")
 if not kitFolder then
  -- Studio's importer names the model after nothing useful ("Scene"), so find it by a mesh inside it (v17).
  local mesh
  for _,d in workspace:GetDescendants() do
   if d.Name=="Kit_RoundShell" and d:IsA("MeshPart") then mesh=d; break end
  end
  if mesh then
   local top=mesh; while top.Parent and top.Parent~=workspace do top=top.Parent end
   top.Name="KitArmour"; top.Parent=home; kitFolder=top
  end
 end
 if not kitFolder and not triedDownload then
  -- No import in this place: build the templates straight from the meshes already uploaded to Peter's
  -- account (asset IDs from his 2026-10-09 import), so a fresh copy of the place needs no Studio step.
  triedDownload=true; loading=true
  local AssetService=game:GetService("AssetService")
  local folder=Instance.new("Folder"); folder.Name="KitArmour"
  for name,id in MESH_IDS do
   local uri="rbxassetid://"..id
   local ok,part=pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(uri)) end)
   if not ok then ok,part=pcall(function() return (AssetService.CreateMeshPartAsync :: any)(AssetService,uri) end) end
   if ok and part then part.Name=name; part.Anchored=true; part.Parent=folder
   else warn("[HeroWars] mesh "..name.." did not load ("..tostring(part)..")") end
  end
  if folder:FindFirstChild("Kit_RoundShell") then folder.Parent=home; kitFolder=folder else folder:Destroy() end
  loading=false
 end
 return kitFolder
end
-- Catalog gear (v17): some skins wear ready-made Roblox catalog accessories by asset ID (free to show;
-- nobody needs to own them). Loaded once per skin through a throwaway rig, then cloned onto the hero.
local gearCache={}
local GEAR_FIELDS={Hair="HairAccessory",Hat="HatAccessory",Face="FaceAccessory",Front="FrontAccessory",Back="BackAccessory",Shoulders="ShouldersAccessory",Waist="WaistAccessory"}
-- v31: gear is loaded on a rig the hero's size, so it fits Bulwark's bigger body.
local GEAR_SCALE={Bulwark=1.18}
local function gearDescription(hero)
 local d=Instance.new("HumanoidDescription")
 local sc=GEAR_SCALE[hero or ""]
 if sc then d.HeightScale=sc; d.WidthScale=sc; d.DepthScale=sc end
 return d
end
local function gearTemplates(skin,hero)
 if gearCache[skin] then return gearCache[skin] end
 local d=gearDescription(hero)
 for slot,ids in skin.Gear do if GEAR_FIELDS[slot] then d[GEAR_FIELDS[slot]]=ids end end
 local ok,rig=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(d,Enum.HumanoidRigType.R15) end)
 d:Destroy()
 local list={}
 if ok then
  for _,v in rig:GetChildren() do if v:IsA("Accessory") then v.Parent=nil; table.insert(list,v) end end
  rig:Destroy()
 else
  warn("[HeroWars] "..skin.Name.." gear did not load ("..tostring(rig).."); showing the kit pieces instead.")
 end
 gearCache[skin]=list
 return list
end
-- v31: a catalog shield (Gear.Shield) replaces the kit shield on Bulwark's forearm, on the same ShieldWeld,
-- so it still comes up in front of him when he guards. It is loaded on a throwaway rig's back first; its
-- attachment there tells which way its face points (out of the back), so it can face out from the arm.
local shieldCache={}
local function shieldTemplate(skin,hero)
 local id=skin.Gear and skin.Gear.Shield
 if not id then return nil end
 if shieldCache[skin]~=nil then return shieldCache[skin] or nil end
 local d=gearDescription(hero); d.BackAccessory=id
 local ok,rig=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(d,Enum.HumanoidRigType.R15) end)
 d:Destroy()
 local result=false
 if ok then
  local torso=rig:FindFirstChild("UpperTorso")
  for _,v in rig:GetChildren() do
   local h=v:IsA("Accessory") and v:FindFirstChild("Handle")
   local att=h and h:FindFirstChildOfClass("Attachment")
   local bodyAtt=att and torso and torso:FindFirstChild(att.Name)
   if h and h:IsA("BasePart") and bodyAtt then
    -- The handle's turn relative to the torso, from the two matching attachments.
    local rot=(bodyAtt.CFrame*att.CFrame:Inverse()).Rotation
    local handle=h:Clone()
    for _,c in handle:GetChildren() do
     if c:IsA("Attachment") or c:IsA("JointInstance") or c:IsA("WeldConstraint") then c:Destroy() end
    end
    result={handle=handle,rot=rot}
    break
   end
  end
  rig:Destroy()
 end
 if not result then warn("[HeroWars] "..skin.Name.." shield did not load; showing the kit shield.") end
 shieldCache[skin]=result
 return result or nil
end
-- Sculpted armour (v20): HeroWars_KitSculpt.glb holds one modelled mesh per armour piece. Import it in
-- Studio once (File > Import 3D); the game finds the import by its meshes, wherever it lands, and moves it
-- into ReplicatedStorage > HeroWars > KitSculpt. Once its asset IDs are known they go in SCULPT_IDS so a
-- fresh copy loads them with no import. Without them, each piece keeps its generic kit shape.
-- From Peter's 2026-10-09 import (v20), so a fresh copy of the place loads the sculpts with no import.
local SCULPT_IDS={Kit_SolHelmet="124691608054127",Kit_SolPauldron="116667215091461",Kit_SolChest="87766908511105",
 Kit_SolThruster="86887808813426",Kit_Gauntlet="130625045454866",Kit_Boot="84129605950156",
 Kit_WraHood="85700909510092",Kit_WraMask="137357411674352",Kit_WraGuard="114075107575279",
 -- Batch 2, from Peter's 2026-10-09 morning import (v23).
 Kit_Belt="116732703353421",Kit_ShinGuard="85186805188101",Kit_ThighPlate="140466887608952",
 Kit_SolReactor="77831764803353",Kit_WraPack="117251759337658",Kit_WraGrapple="128905323477697"}
local SCULPT_NAMES={"Kit_SolHelmet","Kit_SolPauldron","Kit_SolChest","Kit_SolThruster","Kit_Gauntlet","Kit_Boot",
 "Kit_WraHood","Kit_WraMask","Kit_WraGuard",
 -- Batch 2 (v22, HeroWars_KitSculpt2.glb): until imported, these pieces keep their old shapes or are skipped.
 "Kit_Belt","Kit_ShinGuard","Kit_ThighPlate","Kit_SolReactor","Kit_WraPack","Kit_WraGrapple"}
-- Studio's importer brings the sculpts in back to front (Peter, v20), so turn them round.
local SCULPT_YAW=180
local sculptFolder
local sculptTried=false
local sculptLoading=false
local sculptScanned=false
local function sculptMeshes()
 if sculptFolder and sculptFolder.Parent then return sculptFolder end
 if sculptScanned and sculptTried then return nil end
 while sculptLoading do task.wait() end
 if sculptFolder and sculptFolder.Parent then return sculptFolder end
 local home=RS.HeroWars
 sculptFolder=home:FindFirstChild("KitSculpt")
 if sculptFolder then return sculptFolder end
 local wanted={}; for _,n in SCULPT_NAMES do wanted[n]=true end
 local folder
 for _,d in workspace:GetDescendants() do
  if d:IsA("MeshPart") and wanted[d.Name] then
   folder=folder or Instance.new("Folder")
   local top=d; while top.Parent and top.Parent~=workspace do top=top.Parent end
   if top.Parent==workspace then top.Parent=folder end
  end
 end
 if not sculptTried and next(SCULPT_IDS) then
  -- Load every sculpt with a known ID that isn't already imported into this place (v22: an import of
  -- batch 2 no longer stops batch 1 loading by ID).
  sculptTried=true; sculptLoading=true
  local AssetService=game:GetService("AssetService")
  folder=folder or Instance.new("Folder")
  for name,id in SCULPT_IDS do
   if folder:FindFirstChild(name,true) then continue end
   local ok,part=pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri("rbxassetid://"..id)) end)
   if ok and part then part.Name=name; part.Anchored=true; part.Parent=folder
   else warn("[HeroWars] sculpt "..name.." did not load ("..tostring(part)..")") end
  end
  sculptLoading=false
 end
 if folder then folder.Name="KitSculpt"; folder.Parent=home; sculptFolder=folder end
 sculptScanned=true; sculptTried=true
 return sculptFolder
end
local function template(name)
 if name and string.sub(name,1,4)=="Kit_" then
  local sf=sculptMeshes()
  local st=sf and sf:FindFirstChild(name,true)
  if st and st:IsA("MeshPart") then return st end
 end
 local folder=kitMeshes()
 local t=folder and name and folder:FindFirstChild(name,true)
 return t and t:IsA("MeshPart") and t or nil
end
function Appearance.hasMeshes()
 return template("Kit_RoundShell")~=nil
end
local function makePart(meshName, shape)
 local t=template(meshName)
 if t then
  local p=t:Clone()
  for _,c in p:GetChildren() do c:Destroy() end
  p.Anchored=false
  return p
 end
 local p=Instance.new("Part")
 if shape then p.Shape=shape end
 return p
end
local function attachPivot(model, body, p, name, size, offset, color, material, kind)
 p.Name=name; p.Size=size; p.Color=color; p.Material=material
 p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true; p.CastShadow=true
 local weld=Instance.new("Weld"); weld.Name=kind=="shield" and "ShieldWeld" or "SwayWeld"
 weld.Part0=body; weld.Part1=p; weld.C0=offset
 weld.C1=kind=="hair" and CFrame.new(0,size.Y/2,0) or CFrame.identity
 p.CFrame=body.CFrame*weld.C0*weld.C1:Inverse(); p.Parent=model; weld.Parent=p
 return p
end
local function attach(model, body, p, name, size, offset, color, material)
 p.Name=name; p.Size=size; p.Color=color; p.Material=material
 p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true; p.CastShadow=true
 p.CFrame=body.CFrame*offset; p.Parent=model
 local weld=Instance.new("WeldConstraint"); weld.Part0=body; weld.Part1=p; weld.Parent=p
 return p
end
-- v41 Mixamo bodies (Peter's Mixamo characters, cut into the 15 R15 parts by
-- HeroWars-assets/mixamo-tools/mixamo_body_to_r15.py into kit-bodies/HeroWars_Bodies.glb). A skin with
-- Body="Ely" hides the rig's own parts and welds the matching Body_Ely_<Part> mesh to each one, fitted
-- so each piece's joints land on the rig's joints (limbs stretch to the rig's limb lengths). Animations,
-- captures and the hurtbox are unchanged. Import the GLB once in Studio (File > Import 3D); the game
-- finds the meshes by name. Their IDs then go in BODY_IDS so a fresh copy loads them with no import.
-- Without the meshes the skin shows its palette on the normal body.
-- v44: IDs from Peter's 2026-10-09 import of HeroWars_Assets.glb (mesh, texture), so no import is needed.
local BODY={IDS={
 Body_Maria_Head={"129986825442602","117881400147042"},
 Body_Maria_LeftFoot={"96168851609398","117881400147042"},
 Body_Maria_LeftHand={"85080041787927","117881400147042"},
 Body_Maria_LeftLowerArm={"130752502894984","117881400147042"},
 Body_Maria_LeftLowerLeg={"74130268153668","117881400147042"},
 Body_Maria_LeftUpperArm={"83166655735759","117881400147042"},
 Body_Maria_LeftUpperLeg={"91596058939651","117881400147042"},
 Body_Maria_LowerTorso={"105438280364866","117881400147042"},
 Body_Maria_RightFoot={"109546374387937","117881400147042"},
 Body_Maria_RightHand={"119843042775950","117881400147042"},
 Body_Maria_RightLowerArm={"112681722765967","117881400147042"},
 Body_Maria_RightLowerLeg={"80077639622573","117881400147042"},
 Body_Maria_RightUpperArm={"101966542909807","117881400147042"},
 Body_Maria_RightUpperLeg={"110679891732137","117881400147042"},
 Body_Maria_UpperTorso={"72263053533019","117881400147042"},
 Body_Ninja_Head={"113554488382614","108273751372515"},
 Body_Ninja_LeftFoot={"84410453871818","108273751372515"},
 Body_Ninja_LeftHand={"83144125070065","108273751372515"},
 Body_Ninja_LeftLowerArm={"91468615295069","108273751372515"},
 Body_Ninja_LeftLowerLeg={"126988857575797","108273751372515"},
 Body_Ninja_LeftUpperArm={"110391091256322","108273751372515"},
 Body_Ninja_LeftUpperLeg={"80567814461922","108273751372515"},
 Body_Ninja_LowerTorso={"112458265957779","108273751372515"},
 Body_Ninja_RightFoot={"91257440807568","108273751372515"},
 Body_Ninja_RightHand={"91339061331720","108273751372515"},
 Body_Ninja_RightLowerArm={"98342892980535","108273751372515"},
 Body_Ninja_RightLowerLeg={"126463375477046","108273751372515"},
 Body_Ninja_RightUpperArm={"95979959950472","108273751372515"},
 Body_Ninja_RightUpperLeg={"132946373404177","108273751372515"},
 Body_Ninja_UpperTorso={"72522367079788","108273751372515"},
 Body_Paladin_Head={"119248026694698","106040424054417"},
 Body_Paladin_LeftFoot={"70462808871498","106040424054417"},
 Body_Paladin_LeftHand={"80490584514600","106040424054417"},
 Body_Paladin_LeftLowerArm={"139726708621274","106040424054417"},
 Body_Paladin_LeftLowerLeg={"92315612979427","106040424054417"},
 Body_Paladin_LeftUpperArm={"74913977688865","106040424054417"},
 Body_Paladin_LeftUpperLeg={"80106103899129","106040424054417"},
 Body_Paladin_LowerTorso={"129065096011894","106040424054417"},
 Body_Paladin_RightFoot={"75952021924133","106040424054417"},
 Body_Paladin_RightHand={"127927990473680","106040424054417"},
 Body_Paladin_RightLowerArm={"78971569335327","106040424054417"},
 Body_Paladin_RightLowerLeg={"129149139140024","106040424054417"},
 Body_Paladin_RightUpperArm={"95517307639087","106040424054417"},
 Body_Paladin_RightUpperLeg={"124633331923493","106040424054417"},
 Body_Paladin_UpperTorso={"95456478736674","106040424054417"},
 Body_Sol_Head={"101826170410922","82194919757779"},
 Body_Sol_LeftFoot={"140351308496252","82194919757779"},
 Body_Sol_LeftHand={"124143624413608","82194919757779"},
 Body_Sol_LeftLowerArm={"78878400998291","82194919757779"},
 Body_Sol_LeftLowerLeg={"97443555802197","82194919757779"},
 Body_Sol_LeftUpperArm={"104700450599460","82194919757779"},
 Body_Sol_LeftUpperLeg={"128746913822241","82194919757779"},
 Body_Sol_LowerTorso={"121701312884917","82194919757779"},
 Body_Sol_RightFoot={"121511995205160","82194919757779"},
 Body_Sol_RightHand={"100824648027476","82194919757779"},
 Body_Sol_RightLowerArm={"102360582138535","82194919757779"},
 Body_Sol_RightLowerLeg={"113132801686556","82194919757779"},
 Body_Sol_RightUpperArm={"133749803021539","82194919757779"},
 Body_Sol_RightUpperLeg={"87799339155008","82194919757779"},
 Body_Sol_UpperTorso={"87235540859788","82194919757779"}},YAW=0,tried=false,loading=false,
 RIG={
 Sol={
  Joints={Root={0.0006,0.9825,-0.0058},Waist={0.0004,1.0869,0.0042},Neck={-0.0001,1.5047,0.0441},LeftShoulder={-0.1959,1.4385,0.0440},LeftElbow={-0.1959,1.2208,0.0440},LeftWrist={-0.1959,0.9562,0.0440},LeftHip={-0.1007,0.9245,0.0001},LeftKnee={-0.1007,0.5133,-0.0172},LeftAnkle={-0.1007,0.1408,0.0257},RightShoulder={0.1968,1.4385,0.0448},RightElbow={0.1968,1.2217,0.0448},RightWrist={0.1968,0.9578,0.0448},RightHip={0.1007,0.9245,0.0001},RightKnee={0.1007,0.5133,-0.0172},RightAnkle={0.1007,0.1408,0.0257}},
  Parts={
   LowerTorso={Center={-0.0000,0.9774,-0.0047},Size={0.3935,0.2674,0.2757},Tris=852},
   UpperTorso={Center={0.0069,1.3178,0.0346},Size={0.5052,0.5121,0.3532},Tris=2953},
   Head={Center={-0.0019,1.6471,0.0180},Size={0.1767,0.2878,0.2447},Tris=3866},
   LeftUpperArm={Center={-0.1959,1.3406,0.0537},Size={0.1286,0.2911,0.1916},Tris=304},
   LeftLowerArm={Center={-0.2005,1.0953,0.0509},Size={0.1370,0.3035,0.1312},Tris=503},
   LeftHand={Center={-0.1775,0.8707,0.0396},Size={0.1110,0.2696,0.1434},Tris=1162},
   RightUpperArm={Center={0.2010,1.3375,0.0551},Size={0.1258,0.2957,0.1893},Tris=289},
   RightLowerArm={Center={0.1998,1.0961,0.0526},Size={0.1370,0.3017,0.1285},Tris=505},
   RightHand={Center={0.1766,0.8721,0.0362},Size={0.1075,0.2699,0.1402},Tris=1162},
   LeftUpperLeg={Center={-0.1002,0.7060,0.0114},Size={0.1935,0.4955,0.2372},Tris=501},
   LeftLowerLeg={Center={-0.1086,0.3252,0.0105},Size={0.1464,0.3764,0.2155},Tris=866},
   LeftFoot={Center={-0.1209,0.0800,-0.0518},Size={0.1398,0.1576,0.3091},Tris=189},
   RightUpperLeg={Center={0.1028,0.7065,0.0114},Size={0.1879,0.4963,0.2373},Tris=501},
   RightLowerLeg={Center={0.1084,0.3252,0.0098},Size={0.1465,0.3766,0.2154},Tris=866},
   RightFoot={Center={0.1205,0.0800,-0.0530},Size={0.1401,0.1576,0.3088},Tris=189},
  },
 },
 Ninja={
  Joints={Root={0.0000,0.9354,0.0034},Waist={0.0001,1.0451,0.0126},Neck={0.0001,1.4839,0.0494},LeftShoulder={-0.2072,1.4140,0.0499},LeftElbow={-0.2072,1.2038,0.0499},LeftWrist={-0.2072,0.8954,0.0499},LeftHip={-0.0929,0.8744,0.0024},LeftKnee={-0.1018,0.4617,-0.0002},LeftAnkle={-0.0929,0.1145,0.0247},RightShoulder={0.2074,1.4140,0.0490},RightElbow={0.2074,1.2037,0.0490},RightWrist={0.2074,0.8953,0.0490},RightHip={0.0929,0.8743,-0.0014},RightKnee={0.1018,0.4616,0.0106},RightAnkle={0.0929,0.1146,0.0247}},
  Parts={
   LowerTorso={Center={0.0000,0.9300,0.0134},Size={0.3690,0.2644,0.2666},Tris=957},
   UpperTorso={Center={-0.0030,1.2863,0.0304},Size={0.5020,0.5204,0.3479},Tris=4901},
   Head={Center={0.0001,1.6277,-0.0018},Size={0.1766,0.2486,0.2321},Tris=3806},
   LeftUpperArm={Center={-0.2071,1.3074,0.0509},Size={0.1216,0.2755,0.1768},Tris=614},
   LeftLowerArm={Center={-0.2092,1.0557,0.0530},Size={0.1427,0.3236,0.1265},Tris=726},
   LeftHand={Center={-0.1877,0.7900,0.0318},Size={0.1204,0.2520,0.1689},Tris=3276},
   RightUpperArm={Center={0.2074,1.3116,0.0520},Size={0.1216,0.2841,0.1816},Tris=666},
   RightLowerArm={Center={0.2094,1.0557,0.0518},Size={0.1425,0.3241,0.1265},Tris=726},
   RightHand={Center={0.1879,0.7901,0.0308},Size={0.1201,0.2517,0.1720},Tris=3276},
   LeftUpperLeg={Center={-0.1071,0.6476,0.0054},Size={0.2143,0.4357,0.2406},Tris=1253},
   LeftLowerLeg={Center={-0.1042,0.2803,0.0292},Size={0.1495,0.3454,0.1810},Tris=768},
   LeftFoot={Center={-0.0969,0.0734,-0.0658},Size={0.1310,0.1486,0.2968},Tris=892},
   RightUpperLeg={Center={0.1042,0.6470,0.0049},Size={0.2197,0.4353,0.2390},Tris=1259},
   RightLowerLeg={Center={0.1042,0.2808,0.0401},Size={0.1495,0.3465,0.1803},Tris=768},
   RightFoot={Center={0.0969,0.0735,-0.0561},Size={0.1310,0.1488,0.2968},Tris=892},
  },
 },
 Maria={
  Joints={Root={0.0000,1.0525,-0.0177},Waist={-0.0000,1.1050,-0.0203},Neck={0.0011,1.4853,0.0349},LeftShoulder={-0.1533,1.4287,0.0445},LeftElbow={-0.1533,1.1830,0.0445},LeftWrist={-0.1533,0.9520,0.0445},LeftHip={-0.0969,0.9957,-0.0008},LeftKnee={-0.0969,0.5642,-0.0158},LeftAnkle={-0.0969,0.1583,0.0269},RightShoulder={0.1532,1.4287,0.0445},RightElbow={0.1532,1.1830,0.0445},RightWrist={0.1532,0.9520,0.0445},RightHip={0.0969,0.9957,-0.0008},RightKnee={0.0969,0.5642,-0.0158},RightAnkle={0.0969,0.1583,0.0269}},
  Parts={
   LowerTorso={Center={0.0000,1.0379,-0.0158},Size={0.3639,0.2796,0.2716},Tris=736},
   UpperTorso={Center={-0.0000,1.3508,-0.0192},Size={0.3671,0.4472,0.3283},Tris=3332},
   Head={Center={0.0010,1.6144,-0.0017},Size={0.1799,0.2736,0.2333},Tris=2548},
   LeftUpperArm={Center={-0.1955,1.3618,0.0351},Size={0.1830,0.4004,0.2386},Tris=1383},
   LeftLowerArm={Center={-0.1626,1.0722,0.0564},Size={0.1371,0.2712,0.1173},Tris=522},
   LeftHand={Center={-0.1450,0.8656,0.0377},Size={0.1169,0.2123,0.1215},Tris=899},
   RightUpperArm={Center={0.1954,1.3617,0.0351},Size={0.1830,0.4004,0.2386},Tris=1383},
   RightLowerArm={Center={0.1625,1.0722,0.0564},Size={0.1371,0.2712,0.1173},Tris=522},
   RightHand={Center={0.1449,0.8655,0.0377},Size={0.1169,0.2123,0.1215},Tris=899},
   LeftUpperLeg={Center={-0.1076,0.7823,0.0037},Size={0.2156,0.4684,0.2238},Tris=482},
   LeftLowerLeg={Center={-0.0925,0.4086,-0.0070},Size={0.1559,0.5545,0.2396},Tris=407},
   LeftFoot={Center={-0.0991,0.1080,-0.0444},Size={0.1544,0.2189,0.3033},Tris=258},
   RightUpperLeg={Center={0.1078,0.7823,-0.0003},Size={0.2153,0.4684,0.2157},Tris=480},
   RightLowerLeg={Center={0.0925,0.4086,-0.0070},Size={0.1559,0.5545,0.2396},Tris=407},
   RightFoot={Center={0.0991,0.1080,-0.0444},Size={0.1544,0.2189,0.3033},Tris=258},
  },
 },
 Paladin={
  Joints={Root={-0.0003,0.9558,-0.0050},Waist={-0.0005,1.0615,0.0062},Neck={-0.0012,1.4845,0.0509},LeftShoulder={-0.1853,1.4461,0.0505},LeftElbow={-0.1853,1.1904,0.0505},LeftWrist={-0.1853,0.9743,0.0505},LeftHip={-0.0982,0.8970,0.0008},LeftKnee={-0.0982,0.4801,-0.0053},LeftAnkle={-0.0982,0.1115,0.0256},RightShoulder={0.1834,1.4461,0.0505},RightElbow={0.1834,1.1904,0.0505},RightWrist={0.1834,0.9743,0.0505},RightHip={0.0982,0.8970,0.0008},RightKnee={0.0982,0.4801,-0.0053},RightAnkle={0.0982,0.1115,0.0256}},
  Parts={
   LowerTorso={Center={-0.0007,0.9560,0.0168},Size={0.4206,0.2531,0.2764},Tris=398},
   UpperTorso={Center={0.0002,1.2706,0.0139},Size={0.4838,0.5538,0.3139},Tris=2798},
   Head={Center={-0.0007,1.5991,0.0245},Size={0.1878,0.2527,0.2634},Tris=4924},
   LeftUpperArm={Center={-0.2042,1.3163,0.0519},Size={0.1603,0.2983,0.2070},Tris=548},
   LeftLowerArm={Center={-0.1894,1.0835,0.0483},Size={0.1304,0.2754,0.1738},Tris=392},
   LeftHand={Center={-0.1704,0.8803,0.0493},Size={0.0908,0.2030,0.1265},Tris=820},
   RightUpperArm={Center={0.2021,1.3159,0.0519},Size={0.1606,0.2984,0.2070},Tris=544},
   RightLowerArm={Center={0.1876,1.0831,0.0483},Size={0.1304,0.2752,0.1738},Tris=400},
   RightHand={Center={0.1685,0.8798,0.0493},Size={0.0908,0.2029,0.1265},Tris=812},
   LeftUpperLeg={Center={-0.1100,0.6842,0.0137},Size={0.2188,0.5138,0.2548},Tris=778},
   LeftLowerLeg={Center={-0.1013,0.2915,0.0095},Size={0.1421,0.3900,0.1914},Tris=379},
   LeftFoot={Center={-0.0986,0.0821,-0.0416},Size={0.1063,0.1642,0.2520},Tris=352},
   RightUpperLeg={Center={0.0793,0.6842,0.0141},Size={0.2775,0.5135,0.2564},Tris=786},
   RightLowerLeg={Center={0.1000,0.2914,0.0078},Size={0.1421,0.3898,0.1914},Tris=375},
   RightFoot={Center={0.0972,0.0821,-0.0434},Size={0.1063,0.1642,0.2520},Tris=354},
  },
 },
},
 PROX={LowerTorso="Root",UpperTorso="Waist",Head="Neck",LeftUpperArm="LeftShoulder",LeftLowerArm="LeftElbow",
  LeftHand="LeftWrist",RightUpperArm="RightShoulder",RightLowerArm="RightElbow",RightHand="RightWrist",
  LeftUpperLeg="LeftHip",LeftLowerLeg="LeftKnee",LeftFoot="LeftAnkle",RightUpperLeg="RightHip",
  RightLowerLeg="RightKnee",RightFoot="RightAnkle"},
 DIST={LeftUpperArm="LeftElbow",LeftLowerArm="LeftWrist",RightUpperArm="RightElbow",RightLowerArm="RightWrist",
  LeftUpperLeg="LeftKnee",LeftLowerLeg="LeftAnkle",RightUpperLeg="RightKnee",RightLowerLeg="RightAnkle"}}
function BODY.meshes()
 local home=RS.HeroWars
 if BODY.folder and BODY.folder.Parent then return BODY.folder end
 while BODY.loading do task.wait() end
 local folder=home:FindFirstChild("Bodies")
 if not folder then
  for _,d in workspace:GetDescendants() do
   if d:IsA("MeshPart") and string.sub(d.Name,1,5)=="Body_" then
    folder=folder or Instance.new("Folder")
    local top=d; while top.Parent and top.Parent~=workspace do top=top.Parent end
    if top.Parent==workspace then top.Parent=folder end
   end
  end
 end
 if not BODY.tried and next(BODY.IDS) then
  BODY.tried=true; BODY.loading=true
  local AssetService=game:GetService("AssetService")
  folder=folder or Instance.new("Folder")
  for name,id in BODY.IDS do
   if folder:FindFirstChild(name,true) then continue end
   local uri="rbxassetid://"..id[1]
   local ok,part=pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(uri)) end)
   -- v49: the same fallbacks as the kit armour (older API form), and one retry for a throttled load.
   if not ok then ok,part=pcall(function() return (AssetService.CreateMeshPartAsync :: any)(AssetService,uri) end) end
   if not ok then task.wait(0.5); ok,part=pcall(function() return AssetService:CreateMeshPartAsync(Content.fromUri(uri)) end) end
   if ok and part then part.Name=name; part.Anchored=true; part.TextureID="rbxassetid://"..id[2]; part.Parent=folder
   else warn("[HeroWars] body mesh "..name.." did not load ("..tostring(part)..")") end
  end
  BODY.loading=false
 end
 if folder then folder.Name="Bodies"; folder.Parent=home; BODY.folder=folder end
 return BODY.folder
end
-- Rest frame of every part relative to the root, from the joints (pose-independent).
function BODY.rest(model)
 local cf={HumanoidRootPart=CFrame.identity}; local byPart={}; local byName={}
 for _,m in model:GetDescendants() do
  if m:IsA("Motor6D") and m.Part0 and m.Part1 then byPart[m.Part1.Name]=m; byName[m.Name]=m end
 end
 local function get(n)
  if cf[n] then return cf[n] end
  local m=byPart[n]; if not m then return nil end
  local p=get(m.Part0.Name); if not p then return nil end
  cf[n]=p*m.C0*m.C1:Inverse(); return cf[n]
 end
 local joints={}
 for name,m in byName do local p=get(m.Part0.Name); if p then joints[name]=(p*m.C0).Position end end
 return cf,joints
end
-- true when the body went on; false leaves the normal look to the caller.
function BODY.apply(model, name)
 local data=BODY.RIG[name]; local folder=data and BODY.meshes()
 -- v49: say why a body didn't go on (Peter saw the old look in v47 with no clue in Output).
 if not folder then warn("[HeroWars] body "..tostring(name)..": no body meshes loaded, using the kit look"); return false end
 local meshes={}
 for part in BODY.PROX do
  local m=folder:FindFirstChild("Body_"..name.."_"..part,true)
  if not (m and m:IsA("MeshPart")) then warn("[HeroWars] body "..name..": mesh Body_"..name.."_"..part.." missing, using the kit look"); return false end
  meshes[part]=m
 end
 local cf,rj=BODY.rest(model)
 local function mix(j) local v=data.Joints[j]; return Vector3.new(v[1],v[2],v[3]) end
 local function ankle(t) return (t("LeftAnkle").Y+t("RightAnkle").Y)/2 end
 if not (rj.Neck and rj.LeftAnkle and rj.RightAnkle) then warn("[HeroWars] body "..name..": rig joints not found, using the kit look"); return false end
 local k=(rj.Neck.Y-(rj.LeftAnkle.Y+rj.RightAnkle.Y)/2)/(mix("Neck").Y-ankle(mix))
 for part,m in meshes do
  local limb=model:FindFirstChild(part); local prox=BODY.PROX[part]
  if not (limb and cf[part] and rj[prox]) then continue end
  local info=data.Parts[part]
  local s=Vector3.new(k,k,k)
  local dist=BODY.DIST[part]
  if dist and rj[dist] then
   local ml=(mix(dist)-mix(prox)).Magnitude
   if ml>0.01 then s=Vector3.new(k,(rj[dist]-rj[prox]).Magnitude/ml,k) end
  end
  local c=Vector3.new(info.Center[1],info.Center[2],info.Center[3])
  local centre=rj[prox]+(c-mix(prox))*s
  local p=m:Clone()
  for _,ch in p:GetChildren() do if not ch:IsA("SurfaceAppearance") then ch:Destroy() end end
  p.Name="Body"..part; p.Anchored=false; p.Size=Vector3.new(info.Size[1],info.Size[2],info.Size[3])*s
  p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true; p.CastShadow=true
  p:SetAttribute("KitPiece",true)
  local weld=Instance.new("Weld"); weld.Part0=limb; weld.Part1=p
  weld.C0=cf[part]:Inverse()*CFrame.new(centre)*CFrame.Angles(0,math.rad(BODY.YAW),0)
  p.CFrame=limb.CFrame*weld.C0; p.Parent=model; weld.Parent=p
  limb.Transparency=1; limb:SetAttribute("BodyHidden",true)
 end
 local face=model:FindFirstChild("Head") and model.Head:FindFirstChild("HumanFace")
 if face then face.Enabled=false end
 BODY.aura(model,name)
 model:SetAttribute("AppliedBody",name)
 print("[HeroWars] body "..name.." on "..model.Name)
 return true
end
-- v42 idle aura per character (the stealth code hides emitters and lights while a fighter is unseen).
BODY.AURA={
 Sol={part="BodyUpperTorso",light={111,180,255,9},color={255,190,70},tex="sparkles_main",rate=6,size=0.25,up=2},
 Ninja={part="BodyLowerTorso",light=nil,color={60,30,100},tex="smoke_main",rate=8,size=1.6,up=1},
 Maria={part="BodyUpperTorso",light={255,215,110,8},color={255,225,120},tex="sparkles_main",rate=7,size=0.22,up=0},
 Paladin={part="BodyUpperTorso",light={255,200,120,8},color={255,190,90},tex="sparkles_main",rate=5,size=0.25,up=4},
}
function BODY.aura(model,name)
 local a=BODY.AURA[name]; local part=a and model:FindFirstChild(a.part); if not part then return end
 if a.light then
  local l=Instance.new("PointLight"); l.Color=Color3.fromRGB(a.light[1],a.light[2],a.light[3]); l.Range=a.light[4]
  l.Brightness=1; l.Shadows=false; l.Parent=part
 end
 local e=Instance.new("ParticleEmitter"); e.Name="BodyAura"; e.Texture="rbxasset://textures/particles/"..a.tex..".dds"
 e.Color=ColorSequence.new(Color3.fromRGB(a.color[1],a.color[2],a.color[3])); e.Rate=a.rate; e.LightEmission=a.tex=="smoke_main" and 0 or 1
 e.Lifetime=NumberRange.new(0.8,1.4); e.Speed=NumberRange.new(0.5,1.5); e.SpreadAngle=Vector2.new(180,180)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,a.size),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,a.tex=="smoke_main" and 0.6 or 0.2),NumberSequenceKeypoint.new(1,1)})
 e.Acceleration=Vector3.new(0,a.up,0); e.Parent=part
end
-- Smooth body (v18): Roblox's free "Superhero" body package (bundle 299) replaces the square default
-- body. It takes body colours, so the kit palettes paint it. If it fails to load, the square body
-- and the v16 smooth shells come back instead.
local BODY_PACKAGE={Torso=32336059,RightArm=32336117,LeftArm=32336182,LeftLeg=32336243,RightLeg=32336306}
-- v35 (Peter: Tempest "doesn't look like a female"): Roblox's free City Life Woman body (bundle 337,
-- made by Roblox; part IDs checked on catalog.roblox.com). Painted by zone like the others. If it fails
-- to load she falls back to the Superhero body with the v26 reshape and curve pieces.
local HERO_PACKAGE={Tempest={Torso=2492674027,LeftArm=2492667589,RightArm=2492669375,LeftLeg=2492671662,RightLeg=2492670347}}
-- On the woman's body only a light touch: slightly stronger legs, a little narrower in the arms.
local PACKAGE_SHAPE={Tempest={LeftUpperArm=Vector3.new(0.95,1,0.95),RightUpperArm=Vector3.new(0.95,1,0.95),
 LeftUpperLeg=Vector3.new(1.08,1,1.06),RightUpperLeg=Vector3.new(1.08,1,1.06)}}
-- Pieces that only made sense on the Superhero body (padding for bust, hips and waist).
local PACKAGE_HIDE={Tempest={Bodice=true,HipCurve=true,SidePanelL=true,SidePanelR=true}}
-- Build per hero (v19, looks only: the hurtbox comes from standardBounds): Wraithstep is slimmer.
local BUILD={Wraithstep={WidthScale=0.86,DepthScale=0.9},
 -- v25: Tempest sits between Wraithstep and Solarion; Bulwark is the biggest (matches Rules Scale 1.18).
 Tempest={WidthScale=0.94,DepthScale=0.95},
 Bulwark={HeightScale=1.18,WidthScale=1.18,DepthScale=1.18}}
-- Body shape (v20, looks only): per-part stretch (X width, Y height, Z depth). Solarion is V-shaped:
-- broad chest and shoulders, bigger arms, a narrow waist. Joints and attachments move with the parts.
local SHAPE={Solarion={UpperTorso=Vector3.new(1.24,1.06,1.12),LowerTorso=Vector3.new(0.92,1,0.92),
 LeftUpperArm=Vector3.new(1.14,1.02,1.14),RightUpperArm=Vector3.new(1.14,1.02,1.14),
 LeftLowerArm=Vector3.new(1.08,1,1.08),RightLowerArm=Vector3.new(1.08,1,1.08),
 LeftUpperLeg=Vector3.new(1,1,1.06),RightUpperLeg=Vector3.new(1,1,1.06)},
 -- v25 Bulwark: massive chest, arms and big armoured hands. v26: heavier still (Peter: "muscle tank"),
 -- with a thick chest and arms; the muscle shapes themselves are pieces (pecs, abs, biceps, calves).
 Bulwark={UpperTorso=Vector3.new(1.38,1.08,1.3),LowerTorso=Vector3.new(1.1,1,1.1),
 LeftUpperArm=Vector3.new(1.62,1.05,1.62),RightUpperArm=Vector3.new(1.62,1.05,1.62),
 LeftLowerArm=Vector3.new(1.48,1,1.48),RightLowerArm=Vector3.new(1.48,1,1.48),
 LeftHand=Vector3.new(1.5,1.4,1.5),RightHand=Vector3.new(1.5,1.4,1.5),
 LeftUpperLeg=Vector3.new(1.18,1,1.18),RightUpperLeg=Vector3.new(1.18,1,1.18),
 LeftLowerLeg=Vector3.new(1.14,1,1.14),RightLowerLeg=Vector3.new(1.14,1,1.14)},
 -- v26 Tempest (Peter: a woman's figure, curves top and bottom, a small waist, no spindly legs):
 -- narrower shoulders and a slim waist, strong thighs and calves; hips and bust are pieces.
 Tempest={UpperTorso=Vector3.new(0.95,1.02,1.0),LowerTorso=Vector3.new(0.84,1,0.9),
 LeftUpperArm=Vector3.new(0.92,1,0.92),RightUpperArm=Vector3.new(0.92,1,0.92),
 LeftLowerArm=Vector3.new(0.9,1,0.9),RightLowerArm=Vector3.new(0.9,1,0.9),
 LeftUpperLeg=Vector3.new(1.2,1,1.16),RightUpperLeg=Vector3.new(1.2,1,1.16),
 LeftLowerLeg=Vector3.new(1.1,1,1.1),RightLowerLeg=Vector3.new(1.1,1,1.1)}}
-- Hip joints keep their spacing so the legs never overlap under the narrower waist.
local KEEP_C0={LeftHip=true,RightHip=true}
local function scaleCF(cf, k)
 return CFrame.new(cf.Position*k)*cf.Rotation
end
local function reshape(model, hero)
 local shape=model:GetAttribute("HeroBody") and PACKAGE_SHAPE[hero] or SHAPE[hero]; if not shape then return end
 for name,k in shape do
  local part=model:FindFirstChild(name)
  if part and part:IsA("BasePart") then
   part.Size=part.Size*k
   for _,v in part:GetChildren() do if v:IsA("Attachment") then v.Position=v.Position*k end end
  end
 end
 -- Joint offsets live in the part they belong to; stretch each side by its own part.
 for _,m in model:GetDescendants() do
  if m:IsA("Motor6D") then
   local k0=m.Part0 and shape[m.Part0.Name]; local k1=m.Part1 and shape[m.Part1.Name]
   if k0 and not KEEP_C0[m.Name] then m.C0=scaleCF(m.C0,k0) end
   if k1 then m.C1=scaleCF(m.C1,k1) end
  end
 end
end
local function describe(smoothBody, hero, own)
 local d=Instance.new("HumanoidDescription")
 d.HeadColor=SKIN_TONE
 -- Fixed standard R15 proportions: cosmetic shells never change combat reach.
 d.HeightScale=1; d.WidthScale=1; d.DepthScale=1; d.HeadScale=1
 d.BodyTypeScale=0; d.ProportionScale=0
 if smoothBody then for field,id in (own and HERO_PACKAGE[hero or ""]) or BODY_PACKAGE do d[field]=id end end
 for field,v in BUILD[hero or ""] or {} do d[field]=v end
 return d
end
-- Normalize new attachment-based avatars for this game's Motor6D animation pipeline.
function Appearance.prepareRig(model)
 local converted={}
 for _,joint in model:GetDescendants() do
  if joint:IsA("AnimationConstraint") then
   local motor=Instance.new("Motor6D")
   motor.Name=joint.Name; motor.Part0=joint.Part0; motor.Part1=joint.Part1
   motor.C0=joint.C0; motor.C1=joint.C1; motor.Transform=joint.Transform
   motor.Parent=joint.Parent
   table.insert(converted,{joint=joint,a0=joint.Attachment0,a1=joint.Attachment1})
  end
 end
 -- Remove only physical companions of converted joints, not unrelated constraints.
 for _,entry in converted do
  for _,other in model:GetDescendants() do
   if other:IsA("BallSocketConstraint") and
    ((other.Attachment0==entry.a0 and other.Attachment1==entry.a1) or
     (other.Attachment0==entry.a1 and other.Attachment1==entry.a0)) then other:Destroy() end
  end
  entry.joint:Destroy()
 end
 return #converted
end
-- R48 (Peter: "build them in place"): every body Roblox builds is kept, so it is only ever fetched once.
-- A copy goes into ServerStorage.HeroWarsRigs. When that folder is saved into the place file (one Studio
-- save, then baked into every build), the server copies the saved bodies and never waits on Roblox.
local rigCache={}
-- R51: kept in ReplicatedStorage.HeroWarsRigs so it shows in Studio's normal (client) Explorer view; a saved
-- copy is found in either ServerStorage or ReplicatedStorage.
local savedRigs=game:GetService("RunService"):IsServer() and (game:GetService("ServerStorage"):FindFirstChild("HeroWarsRigs")
 or (RS:FindFirstChild("HeroWarsRigs") and RS.HeroWarsRigs:GetAttribute("Saved") and RS.HeroWarsRigs))
local liveRigs
local function rig(smoothBody, hero, own)
 local key=(smoothBody and "Smooth" or "Square")..(own and "Own" or "").."_"..(hero or "Base")
 local cached=rigCache[key] or (savedRigs and savedRigs:FindFirstChild(key))
 if cached then
  local ok,copy=pcall(function() return cached:Clone() end)
  if ok and copy then rigCache[key]=cached; return true,copy end
 end
 local d=describe(smoothBody,hero,own)
 local ok,model=pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(d,Enum.HumanoidRigType.R15) end)
 d:Destroy()
 if ok then
  Appearance.prepareRig(model)
  local okc,keep=pcall(function() return model:Clone() end)
  if okc and keep then
   keep.Name=key; rigCache[key]=keep
   if game:GetService("RunService"):IsServer() then
    if not liveRigs then
     liveRigs=RS:FindFirstChild("HeroWarsRigs") or Instance.new("Folder")
     liveRigs.Name="HeroWarsRigs"; liveRigs:SetAttribute("Saved",true); liveRigs.Parent=RS
    end
    keep:Clone().Parent=liveRigs
    print("[HeroWars] body fetched from Roblox and kept: "..key.." ("..#liveRigs:GetChildren().." in ReplicatedStorage.HeroWarsRigs; save that folder to skip this next time)")
   end
  end
 end
 return ok,model
end
-- Hurtbox bounds of the standard square R15 body, in root space, measured once. Every hero and skin
-- uses these, so the smooth body (or any future body) never changes what can be hit.
local standardBounds
function Appearance.standardBounds()
 if standardBounds then return standardBounds.lo,standardBounds.hi end
 local ok,model=rig(false)
 if not ok then error(model) end
 -- Measured in the world (out of sight) so the joints have placed every limb.
 local root=model.HumanoidRootPart; root.Anchored=true
 model:PivotTo(CFrame.new(0,-400,0)); model.Parent=workspace
 local lo,hi
 for _,p in model:GetChildren() do
  if p:IsA("BasePart") and not p.Massless then
   for _,x in {-0.5,0.5} do for _,y in {-0.5,0.5} do for _,z in {-0.5,0.5} do
    local c=root.CFrame:PointToObjectSpace((p.CFrame*CFrame.new(p.Size*Vector3.new(x,y,z))).Position)
    lo=lo and lo:Min(c) or c; hi=hi and hi:Max(c) or c
   end end end
  end
 end
 model:Destroy()
 standardBounds={lo=lo,hi=hi}
 return lo,hi
end
local function color(palette, zone)
 if zone=="Flesh" then return Color3.new(Rules.hex(palette.Flesh or Rules.DefaultFlesh)) end
 return Color3.new(Rules.hex(palette[zone] or palette[Rules.ExtraZones[zone] or "Primary"]))
end
-- v34 Bulwark (Peter: "show some muscles, big muscle arms"): bare chest, shoulders and arms.
local HERO_ZONES={Bulwark={UpperTorso="Flesh",LeftUpperArm="Flesh",RightUpperArm="Flesh",LeftLowerArm="Flesh",RightLowerArm="Flesh"}}
-- Body zones from the kit's colour-zone guide.
local ZONES={UpperTorso="Primary",LowerTorso="Secondary",LeftUpperArm="Primary",RightUpperArm="Primary",
 LeftLowerArm="Secondary",RightLowerArm="Secondary",LeftUpperLeg="Primary",RightUpperLeg="Primary",
 LeftLowerLeg="Secondary",RightLowerLeg="Secondary",LeftFoot="Metal",RightFoot="Metal"}
-- BEGIN GENERATED PIECES
-- GENERATED from HeroWars-assets/kit-meshes/pieces.json by make_luau.py; edit the JSON, not this table.
local PIECES={
 Shared={
  {limb="UpperTorso",name="TorsoShell",zone="Primary",size={{1.05,0},{1.03,0},{1.1,0}},mesh="Kit_RoundShell",shell=true},
  {limb="LowerTorso",name="HipShell",zone="Secondary",size={{1.04,0},{1.15,0},{1.08,0}},mesh="Kit_RoundShell",shell=true},
  {limb="LowerTorso",name="Belt",zone="Accent",size={{1.08,0},{0,0.22},{1.14,0}},mesh="Kit_Band",pos={{0,0},{0,0.1},{0,0}}},
  {limb="*UpperArm",name="ArmShell",zone="Primary",size={{1.02,0},{1,0},{1.02,0}},mesh="Kit_LimbShell",shell=true},
  {limb="*UpperArm",name="ShoulderPlate",zone="Metal",size={{1.35,0},{0,0.55},{1.35,0}},mesh="Kit_Dome",pos={{0,0},{0.5,-0.08},{0,0}}},
  {limb="*LowerArm",name="Gauntlet",zone="Secondary",size={{1.06,0},{0.85,0},{1.06,0}},mesh="Kit_Capsule",pos={{0,0},{-0.06,0},{0,0}}},
  {limb="*LowerArm",name="GauntletTrim",zone="Accent",size={{1.12,0},{0,0.14},{1.12,0}},mesh="Kit_Band",pos={{0,0},{-0.42,0},{0,0}}},
  {limb="*UpperLeg",name="LegShell",zone="Primary",size={{1.02,0},{1.02,0},{1.02,0}},mesh="Kit_LimbShell",shell=true},
  {limb="*LowerLeg",name="ShinShell",zone="Secondary",size={{1.04,0},{1,0},{1.04,0}},mesh="Kit_LimbShell",shell=true},
  {limb="*LowerLeg",name="BootCuff",zone="Dark",size={{1.12,0},{0,0.24},{1.12,0}},mesh="Kit_Band",pos={{0,0},{-0.5,0.18},{0,0}}},
  {limb="*Foot",name="Boot",zone="Metal",size={{1.15,0},{1.7,0},{1.2,0}},mesh="Kit_RoundShell",pos={{0,0},{0,0.08},{0,-0.04}}},
 },
 Solarion={
  {limb="UpperTorso",name="SolarCoreFrame",zone="Accent",size={{0,0.8},{0,0.8},{0,0.14}},mesh="Kit_Tile",pos={{0,0},{0,0.05},{-0.55,-0.06}},rot=45},
  {limb="UpperTorso",name="SolarCore",zone="Emissive",size={{0,0.56},{0,0.56},{0,0.14}},mesh="Kit_Tile",pos={{0,0},{0,0.05},{-0.55,-0.11}},rot=45,neon=true},
  {limb="UpperTorso",name="ChestPlate",zone="Metal",size={{0.78,0},{0.32,0},{0,0.12}},mesh="Kit_Pillow",pos={{0,0},{0.3,0},{-0.55,-0.04}}},
  {limb="UpperTorso",name="BackThrusterLeft",zone="Metal",size={{0,0.55},{0,1.35},{0,0.55}},mesh="Kit_Capsule",pos={{0,-0.45},{0,0},{0.55,0.3}}},
  {limb="UpperTorso",name="BackThrusterRight",zone="Metal",size={{0,0.55},{0,1.35},{0,0.55}},mesh="Kit_Capsule",pos={{0,0.45},{0,0},{0.55,0.3}}},
  {limb="UpperTorso",name="ThrusterGlowLeft",zone="Emissive",size={{0,0.36},{0,0.24},{0,0.36}},mesh="Kit_Capsule",pos={{0,-0.45},{0,-0.74},{0.55,0.3}},neon=true},
  {limb="UpperTorso",name="ThrusterGlowRight",zone="Emissive",size={{0,0.36},{0,0.24},{0,0.36}},mesh="Kit_Capsule",pos={{0,0.45},{0,-0.74},{0.55,0.3}},neon=true},
  {limb="UpperTorso",name="BackCore",zone="Accent",size={{0,0.4},{0,0.4},{0,0.4}},pos={{0,0},{0,0.25},{0.55,0.05}},neon=true,ball=true},
  {limb="Head",name="HelmetCap",zone="Metal",size={{1.15,0},{0.5,0},{1.15,0}},mesh="Kit_Dome",pos={{0,0},{0.4,0},{0,0.02}}},
  {limb="Head",name="HelmetCrest",zone="Accent",size={{0,0.2},{0,0.28},{0.95,0}},mesh="Kit_Pillow",pos={{0,0},{0.68,0},{0,0}}},
  {limb="Head",name="Visor",zone="Accent",size={{0.95,0},{0,0.17},{0,0.14}},mesh="Kit_Pillow",pos={{0,0},{0.2,0},{-0.6,-0.02}},neon=true},
 },
 Wraithstep={
  {limb="Head",name="HoodCap",zone="Dark",size={{1.25,0},{0.68,0},{1.25,0}},mesh="Kit_Dome",pos={{0,0},{0.3,0},{0,0.06}}},
  {limb="Head",name="HoodBack",zone="Dark",size={{1.2,0},{0.95,0},{0,0.3}},mesh="Kit_Pillow",pos={{0,0},{-0.05,0},{0.55,0.1}}},
  {limb="Head",name="Visor",zone="Emissive",size={{0.95,0},{0,0.15},{0,0.14}},mesh="Kit_Pillow",pos={{0,0},{0.08,0},{-0.7,-0.02}},neon=true},
  {limb="Head",name="HalfMask",zone="Dark",size={{1,0},{0.34,0},{0,0.16}},mesh="Kit_Pillow",pos={{0,0},{-0.22,0},{-0.55,0}}},
  {limb="UpperTorso",name="StealthBadge",zone="Accent",size={{0,0.44},{0,0.44},{0,0.12}},mesh="Kit_Tile",pos={{0,0},{0,0.12},{-0.55,-0.06}},rot=45,neon=true},
  {limb="UpperTorso",name="ChestStrap",zone="Dark",size={{0,0.24},{1.08,0},{1.14,0}},mesh="Kit_Pillow",rot=28},
  {limb="UpperTorso",name="CompactBackpack",zone="Dark",size={{0,1.3},{0,1.2},{0,0.55}},mesh="Kit_RoundShell",pos={{0,0},{0,0.05},{0.55,0.27}}},
  {limb="UpperTorso",name="PackLight",zone="Emissive",size={{0,0.55},{0,0.12},{0,0.08}},mesh="Kit_Pillow",pos={{0,0},{0,0.4},{0.55,0.56}},neon=true},
  {limb="RightLowerArm",name="GrappleHousing",zone="Accent",size={{1.35,0},{0.5,0},{1.4,0}},mesh="Kit_RoundShell",pos={{0,0},{-0.08,0},{0,-0.05}}},
  {limb="RightLowerArm",name="GrappleMuzzle",zone="Emissive",size={{0,0.3},{0,0.3},{0,0.25}},mesh="Kit_Barrel",pos={{0,0},{-0.08,0},{-0.7,-0.1}},neon=true},
 },
}
-- END GENERATED PIECES
-- Where each sculpt replaces a kit piece, with its own size/pos (same a*limbSize+b form as PIECES).
-- hide: kit pieces the sculpt makes unnecessary.
local SHARED_SCULPTS={
 Gauntlet={mesh="Kit_Gauntlet"},
 Belt={mesh="Kit_Belt",size={{1.08,0},{0,0.3},{1.14,0}}},
 Boot={mesh="Kit_Boot",size={{1.15,0},{1.9,0},{1.25,0}},pos={{0,0},{0,0.1},{0,-0.06}}},
}
local SCULPTS={
 Solarion={
  -- Peter prefers v17's open cap with just the goggles, so the sculpted helmet is only on one skin,
  -- turned the right way round, to compare (v21).
  HelmetCap={mesh="Kit_SolHelmet",size={{1.25,0},{1.2,0},{1.25,0}},pos={{0,0},{0.12,0},{0,0.02}},onlySkins={Celestial=true}},
  ShoulderPlate={mesh="Kit_SolPauldron",size={{1.45,0},{0,0.7},{1.45,0}},pos={{0,0},{0.5,-0.05},{0,0}}},
  ChestPlate={mesh="Kit_SolChest",size={{0.92,0},{0.6,0},{0,0.2}},pos={{0,0},{0.18,0},{-0.5,-0.08}}},
  BackThrusterLeft={mesh="Kit_SolThruster"},
  BackThrusterRight={mesh="Kit_SolThruster"},
 },
 Bulwark={
  ShoulderPlate={mesh="Kit_SolPauldron",size={{1.6,0},{0,0.85},{1.6,0}},pos={{0,0},{0.5,-0.02},{0,0}}},
 },
 Wraithstep={
  HoodCap={mesh="Kit_WraHood",size={{1.32,0},{1.25,0},{1.35,0}},pos={{0,0},{0.05,0},{0,0.06}},hide={"HoodBack"},onlySkins={Phantom=true}},
  HalfMask={mesh="Kit_WraMask",size={{1.08,0},{0.36,0},{0.48,0}},pos={{0,0},{-0.22,0},{-0.33,0}}},
  CompactBackpack={mesh="Kit_WraPack"},
  GrappleHousing={mesh="Kit_WraGrapple",size={{1.3,0},{0.8,0},{1.3,0}},pos={{0,0},{-0.1,0},{0,-0.05}}},
  ShoulderPlate={mesh="Kit_WraGuard",size={{1.3,0},{0,0.55},{1.3,0}},pos={{0,0},{0.5,-0.05},{0,0}}},
 },
}
local function sculptFor(hero, name, skinName)
 local sc=(SCULPTS[hero] and SCULPTS[hero][name]) or SHARED_SCULPTS[name]
 if sc and sc.onlySkins and not sc.onlySkins[skinName or ""] then return nil end
 if sc and template(sc.mesh) then return sc end
 return nil
end
-- v25 heroes' own pieces (not in pieces.json); v26 reworks both (Peter's notes).
-- Tempest: big storm hair made of separate locks that sway (pivot="hair": hung from the top on a Weld the
-- client swings), glowing eyes, a bodice and curved hips over a slim waist, dark side panels that narrow
-- the waist, thigh boots and long gloves, a split cape that sways, and a lightning crown on Storm Queen.
-- Bulwark: an ancient heavy infantryman. Crested helmet with cheek and nose guards and glowing eye slits,
-- silver muscle cuirass (pecs, abs, traps), bare-looking biceps and calves, bronze bracers, a leather
-- skirt (pteruges), a cloak, a round bronze shield on the left arm (raised by the client when he guards)
-- and a short sword in his right hand. Looks only; his hurtbox is the scaled standard box.
local HERO_PIECES={
 Tempest={
  {limb="Head",name="HairCrown",zone="Hair",size={{1.6,0},{0.9,0},{1.6,0}},mesh="Kit_Dome",pos={{0,0},{0.32,0},{0,0.06}}},
  {limb="Head",name="HairVolume",zone="Hair",size={{1.5,0},{1.1,0},{1.1,0}},mesh="Kit_RoundShell",pos={{0,0},{0.15,0},{0.3,0}}},
  {limb="Head",name="HairLock1",zone="Hair",mesh="Kit_Capsule",size={{0.42,0},{1.75,0},{0.38,0}},pos={{-0.44,0},{0.3,0},{0.36,0}},rot=-24,tilt=-14,pivot="hair",sway=1,shade=0},
  {limb="Head",name="HairLock2",zone="Hair",mesh="Kit_Capsule",size={{0.42,0},{1.95,0},{0.38,0}},pos={{-0.22,0},{0.3,0},{0.36,0}},rot=-12,tilt=-14,pivot="hair",sway=1,shade=1},
  {limb="Head",name="HairLock3",zone="Hair",mesh="Kit_Capsule",size={{0.42,0},{2.05,0},{0.38,0}},pos={{0,0},{0.3,0},{0.36,0}},rot=0,tilt=-14,pivot="hair",sway=1,shade=0},
  {limb="Head",name="HairLock4",zone="Hair",mesh="Kit_Capsule",size={{0.42,0},{1.95,0},{0.38,0}},pos={{0.22,0},{0.3,0},{0.36,0}},rot=12,tilt=-14,pivot="hair",sway=1,shade=1},
  {limb="Head",name="HairLock5",zone="Hair",mesh="Kit_Capsule",size={{0.42,0},{1.75,0},{0.38,0}},pos={{0.44,0},{0.3,0},{0.36,0}},rot=24,tilt=-14,pivot="hair",sway=1,shade=0},
  {limb="Head",name="HairSide1",zone="Hair",mesh="Kit_Capsule",size={{0.3,0},{1.3,0},{0.36,0}},pos={{-0.6,0},{0.25,0},{0.04,0}},rot=-18,tilt=-6,pivot="hair",sway=0.8,shade=1},
  {limb="Head",name="HairSide2",zone="Hair",mesh="Kit_Capsule",size={{0.3,0},{1.5,0},{0.36,0}},pos={{-0.58,0},{0.25,0},{0.26,0}},rot=-18,tilt=-6,pivot="hair",sway=0.8,shade=0},
  {limb="Head",name="HairSide3",zone="Hair",mesh="Kit_Capsule",size={{0.3,0},{1.3,0},{0.36,0}},pos={{0.6,0},{0.25,0},{0.04,0}},rot=18,tilt=-6,pivot="hair",sway=0.8,shade=1},
  {limb="Head",name="HairSide4",zone="Hair",mesh="Kit_Capsule",size={{0.3,0},{1.5,0},{0.36,0}},pos={{0.58,0},{0.25,0},{0.26,0}},rot=18,tilt=-6,pivot="hair",sway=0.8,shade=0},
  {limb="Head",name="HairFringe1",zone="Hair",mesh="Kit_Capsule",size={{0.24,0},{0.75,0},{0.2,0}},pos={{-0.4,0},{0.42,0},{-0.36,0}},rot=-28,pivot="hair",sway=0.4},
  {limb="Head",name="HairFringe2",zone="Hair",mesh="Kit_Capsule",size={{0.24,0},{0.75,0},{0.2,0}},pos={{0.4,0},{0.42,0},{-0.36,0}},rot=28,pivot="hair",sway=0.4},
  {limb="Head",name="Circlet",zone="Metal",size={{1.05,0},{0,0.12},{1.05,0}},mesh="Kit_Band",pos={{0,0},{0.26,0},{0,0}}},
  {limb="Head",name="CircletGem",zone="Emissive",size={{0,0.22},{0,0.22},{0,0.07}},mesh="Kit_Tile",pos={{0,0},{0.26,0},{-0.5,-0.05}},rot=45,neon=true},
  {limb="Head",name="CrownSpike1",zone="Emissive",size={{0,0.1},{0,0.26},{0,0.06}},mesh="Kit_Pillow",pos={{-0.3,0},{0.4,0},{-0.44,0}},rot=-24,neon=true,onlySkins={StormQueen=true}},
  {limb="Head",name="CrownSpike2",zone="Emissive",size={{0,0.1},{0,0.34},{0,0.06}},mesh="Kit_Pillow",pos={{-0.15,0},{0.4,0},{-0.44,0}},rot=-12,neon=true,onlySkins={StormQueen=true}},
  {limb="Head",name="CrownSpike3",zone="Emissive",size={{0,0.1},{0,0.42},{0,0.06}},mesh="Kit_Pillow",pos={{0,0},{0.4,0},{-0.44,0}},rot=0,neon=true,onlySkins={StormQueen=true}},
  {limb="Head",name="CrownSpike4",zone="Emissive",size={{0,0.1},{0,0.34},{0,0.06}},mesh="Kit_Pillow",pos={{0.15,0},{0.4,0},{-0.44,0}},rot=12,neon=true,onlySkins={StormQueen=true}},
  {limb="Head",name="CrownSpike5",zone="Emissive",size={{0,0.1},{0,0.26},{0,0.06}},mesh="Kit_Pillow",pos={{0.3,0},{0.4,0},{-0.44,0}},rot=24,neon=true,onlySkins={StormQueen=true}},
  {limb="Head",name="EyeL",zone="Emissive",size={{0.13,0},{0.075,0},{0,0.05}},mesh="Kit_Pillow",pos={{-0.185,0},{0.07,0},{-0.5,0.03}},rot=-8,neon=true},
  {limb="Head",name="EyeR",zone="Emissive",size={{0.13,0},{0.075,0},{0,0.05}},mesh="Kit_Pillow",pos={{0.185,0},{0.07,0},{-0.5,0.03}},rot=8,neon=true},
  {limb="UpperTorso",name="Bodice",zone="Primary",size={{0.82,0},{0.36,0},{0,0.5}},mesh="Kit_RoundShell",pos={{0,0},{0.16,0},{-0.5,0.14}}},
  {limb="UpperTorso",name="NecklineL",zone="Accent",size={{0,0.07},{0.34,0},{0,0.05}},mesh="Kit_Pillow",pos={{-0.09,0},{0.36,0},{-0.5,-0.08}},rot=-30},
  {limb="UpperTorso",name="NecklineR",zone="Accent",size={{0,0.07},{0.34,0},{0,0.05}},mesh="Kit_Pillow",pos={{0.09,0},{0.36,0},{-0.5,-0.08}},rot=30},
  {limb="UpperTorso",name="SidePanelL",zone="Dark",size={{0,0.08},{0.9,0},{0.86,0}},mesh="Kit_Pillow",pos={{-0.5,0},{-0.05,0},{0,0}},rot=8},
  {limb="UpperTorso",name="SidePanelR",zone="Dark",size={{0,0.08},{0.9,0},{0.86,0}},mesh="Kit_Pillow",pos={{0.5,0},{-0.05,0},{0,0}},rot=-8},
  {limb="UpperTorso",name="BoltA",zone="Emissive",size={{0,0.45},{0,0.13},{0,0.07}},mesh="Kit_Pillow",pos={{-0.05,0},{-0.22,0},{-0.5,-0.05}},rot=35,neon=true},
  {limb="UpperTorso",name="BoltB",zone="Emissive",size={{0,0.45},{0,0.13},{0,0.07}},mesh="Kit_Pillow",pos={{0.05,0},{-0.34,0},{-0.5,-0.05}},rot=35,neon=true},
  {limb="UpperTorso",name="CapeL",zone="Cloth",size={{0.54,0},{0,3.3},{0,0.1}},mesh="Kit_Pillow",pos={{-0.26,0},{0.45,0},{0.5,0.2}},rot=-4,tilt=-6,pivot="hair",sway=0.6},
  {limb="UpperTorso",name="CapeR",zone="Cloth",size={{0.54,0},{0,3.3},{0,0.1}},mesh="Kit_Pillow",pos={{0.26,0},{0.45,0},{0.5,0.2}},rot=4,tilt=-6,pivot="hair",sway=0.6},
  {limb="UpperTorso",name="CapeClasp",zone="Metal",size={{0.9,0},{0,0.16},{0,0.16}},mesh="Kit_Pillow",pos={{0,0},{0.45,0},{0.5,0.08}}},
  {limb="LowerTorso",name="HipCurve",zone="Primary",size={{1.35,0},{0,0.95},{1.22,0}},mesh="Kit_RoundShell",pos={{0,0},{0,-0.25},{0,0.03}}},
  {limb="*UpperLeg",name="ThighBoot",zone="Secondary",size={{1.05,0},{0.5,0},{1.05,0}},mesh="Kit_LimbShell",pos={{0,0},{-0.25,0},{0,0}}},
  {limb="*UpperLeg",name="ThighBootTrim",zone="Accent",size={{1.08,0},{0,0.12},{1.08,0}},mesh="Kit_Band",pos={{0,0},{0,0},{0,0}}},
 },
 Bulwark={
  {limb="Head",name="Helmet",zone="Metal",size={{1.22,0},{1.16,0},{1.22,0}},mesh="Kit_RoundShell",pos={{0,0},{0.04,0},{0,0}}},
  {limb="Head",name="Brow",zone="Accent",size={{1.02,0},{0.14,0},{0,0.14}},mesh="Kit_Pillow",pos={{0,0},{0.24,0},{-0.56,0}}},
  {limb="Head",name="CheekGuardL",zone="Metal",size={{0.3,0},{0.58,0},{0,0.12}},mesh="Kit_Pillow",pos={{-0.3,0},{-0.14,0},{-0.56,0}},rot=8},
  {limb="Head",name="CheekGuardR",zone="Metal",size={{0.3,0},{0.58,0},{0,0.12}},mesh="Kit_Pillow",pos={{0.3,0},{-0.14,0},{-0.56,0}},rot=-8},
  {limb="Head",name="NoseGuard",zone="Metal",size={{0.13,0},{0.45,0},{0,0.1}},mesh="Kit_Pillow",pos={{0,0},{0,0},{-0.6,0}}},
  {limb="Head",name="EyeSlitL",zone="Emissive",size={{0.26,0},{0.08,0},{0,0.06}},mesh="Kit_Pillow",pos={{-0.19,0},{0.1,0},{-0.6,-0.01}},rot=-6,neon=true},
  {limb="Head",name="EyeSlitR",zone="Emissive",size={{0.26,0},{0.08,0},{0,0.06}},mesh="Kit_Pillow",pos={{0.19,0},{0.1,0},{-0.6,-0.01}},rot=6,neon=true},
  {limb="Head",name="CrestRidge",zone="Accent",size={{0,0.14},{0,0.18},{1.05,0}},mesh="Kit_Pillow",pos={{0,0},{0.6,0},{0,0}}},
  {limb="Head",name="Plume1",zone="Cloth",size={{0.22,0},{0,0.50},{0,0.36}},mesh="Kit_Capsule",pos={{0,0},{0.291,0},{-0.517,0}},tilt=-70},
  {limb="Head",name="Plume2",zone="Cloth",size={{0.22,0},{0,0.58},{0,0.36}},mesh="Kit_Capsule",pos={{0,0},{0.461,0},{-0.402,0}},tilt=-47},
  {limb="Head",name="Plume3",zone="Cloth",size={{0.22,0},{0,0.67},{0,0.36}},mesh="Kit_Capsule",pos={{0,0},{0.580,0},{-0.215,0}},tilt=-23},
  {limb="Head",name="Plume4",zone="Cloth",size={{0.22,0},{0,0.75},{0,0.36}},mesh="Kit_Capsule",pos={{0,0},{0.620,0},{0.000,0}},tilt=0},
  {limb="Head",name="Plume5",zone="Cloth",size={{0.22,0},{0,0.67},{0,0.36}},mesh="Kit_Capsule",pos={{0,0},{0.580,0},{0.215,0}},tilt=23},
  {limb="Head",name="Plume6",zone="Cloth",size={{0.22,0},{0,0.58},{0,0.36}},mesh="Kit_Capsule",pos={{0,0},{0.461,0},{0.402,0}},tilt=47},
  {limb="Head",name="Plume7",zone="Cloth",size={{0.22,0},{0,0.50},{0,0.36}},mesh="Kit_Capsule",pos={{0,0},{0.291,0},{0.517,0}},tilt=70},
  -- v34 (Peter: "remove the big back pack, show some muscles, big muscle arms"): the silver cuirass,
  -- back plate and cloak are gone. Bare, sculpted chest and shoulders, huge arms, a leather baldric
  -- for the sword and wrapped fists. The shade=1 pieces are a touch darker to read as muscle definition.
  {limb="UpperTorso",name="Traps",zone="Flesh",size={{0.86,0},{0,0.46},{0.74,0}},mesh="Kit_Dome",pos={{0,0},{0.5,-0.04},{0,0}}},
  {limb="UpperTorso",name="PecL",zone="Flesh",size={{0.5,0},{0.36,0},{0,0.46}},mesh="Kit_RoundShell",pos={{-0.24,0},{0.2,0},{-0.5,0.12}}},
  {limb="UpperTorso",name="PecR",zone="Flesh",size={{0.5,0},{0.36,0},{0,0.46}},mesh="Kit_RoundShell",pos={{0.24,0},{0.2,0},{-0.5,0.12}}},
  {limb="UpperTorso",name="Ab",zone="Flesh",size={{0.2,0},{0.13,0},{0,0.14}},mesh="Kit_Pillow",pos={{-0.11,0},{-0.07,0},{-0.5,-0.01}},shade=1},
  {limb="UpperTorso",name="Ab",zone="Flesh",size={{0.2,0},{0.13,0},{0,0.14}},mesh="Kit_Pillow",pos={{0.11,0},{-0.07,0},{-0.5,-0.01}},shade=1},
  {limb="UpperTorso",name="Ab",zone="Flesh",size={{0.2,0},{0.13,0},{0,0.14}},mesh="Kit_Pillow",pos={{-0.11,0},{-0.22,0},{-0.5,-0.01}},shade=1},
  {limb="UpperTorso",name="Ab",zone="Flesh",size={{0.2,0},{0.13,0},{0,0.14}},mesh="Kit_Pillow",pos={{0.11,0},{-0.22,0},{-0.5,-0.01}},shade=1},
  {limb="UpperTorso",name="Ab",zone="Flesh",size={{0.2,0},{0.13,0},{0,0.14}},mesh="Kit_Pillow",pos={{-0.11,0},{-0.37,0},{-0.5,-0.01}},shade=1},
  {limb="UpperTorso",name="Ab",zone="Flesh",size={{0.2,0},{0.13,0},{0,0.14}},mesh="Kit_Pillow",pos={{0.11,0},{-0.37,0},{-0.5,-0.01}},shade=1},
  {limb="UpperTorso",name="LatL",zone="Flesh",size={{0,0.22},{0.7,0},{0.7,0}},mesh="Kit_RoundShell",pos={{-0.5,0.02},{0.05,0},{0,0}},rot=8,shade=1},
  {limb="UpperTorso",name="LatR",zone="Flesh",size={{0,0.22},{0.7,0},{0.7,0}},mesh="Kit_RoundShell",pos={{0.5,-0.02},{0.05,0},{0,0}},rot=-8,shade=1},
  {limb="UpperTorso",name="Baldric",zone="Dark",size={{0,0.22},{1.45,0},{0,0.07}},mesh="Kit_Pillow",pos={{0,0},{0.02,0},{-0.5,-0.1}},rot=-38},
  {limb="UpperTorso",name="BaldricBack",zone="Dark",size={{0,0.22},{1.45,0},{0,0.07}},mesh="Kit_Pillow",pos={{0,0},{0.02,0},{0.5,0.05}},rot=38},
  {limb="UpperTorso",name="BaldricBoss",zone="Accent",size={{0,0.3},{0,0.3},{0,0.3}},pos={{-0.3,0},{0.38,0},{-0.5,-0.1}},ball=true},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.26},{0,0.8},{0,0.07}},mesh="Kit_Pillow",pos={{-0.36,0},{-0.5,-0.32},{-0.5,-0.02}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.26},{0,0.8},{0,0.07}},mesh="Kit_Pillow",pos={{-0.12,0},{-0.5,-0.32},{-0.5,-0.02}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.26},{0,0.8},{0,0.07}},mesh="Kit_Pillow",pos={{0.12,0},{-0.5,-0.32},{-0.5,-0.02}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.26},{0,0.8},{0,0.07}},mesh="Kit_Pillow",pos={{0.36,0},{-0.5,-0.32},{-0.5,-0.02}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.26},{0,0.8},{0,0.07}},mesh="Kit_Pillow",pos={{-0.25,0},{-0.5,-0.32},{0.5,0.02}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.26},{0,0.8},{0,0.07}},mesh="Kit_Pillow",pos={{0,0},{-0.5,-0.32},{0.5,0.02}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.26},{0,0.8},{0,0.07}},mesh="Kit_Pillow",pos={{0.25,0},{-0.5,-0.32},{0.5,0.02}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.07},{0,0.8},{0,0.26}},mesh="Kit_Pillow",pos={{-0.5,-0.02},{-0.5,-0.32},{-0.18,0}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.07},{0,0.8},{0,0.26}},mesh="Kit_Pillow",pos={{-0.5,-0.02},{-0.5,-0.32},{0.18,0}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.07},{0,0.8},{0,0.26}},mesh="Kit_Pillow",pos={{0.5,0.02},{-0.5,-0.32},{-0.18,0}}},
  {limb="LowerTorso",name="Pteruge",zone="Dark",size={{0,0.07},{0,0.8},{0,0.26}},mesh="Kit_Pillow",pos={{0.5,0.02},{-0.5,-0.32},{0.18,0}}},
  -- Arms: a round deltoid cap, a big bicep in front, the tricep behind, and a thick forearm.
  {limb="*UpperArm",name="Delt",zone="Flesh",size={{1.12,0},{0,0.62},{1.1,0}},mesh="Kit_Dome",pos={{0,0},{0.5,-0.14},{0,0}}},
  {limb="*UpperArm",name="Bicep",zone="Flesh",size={{0.86,0},{0.62,0},{0.78,0}},mesh="Kit_RoundShell",pos={{0,0},{-0.06,0},{-0.2,0}}},
  {limb="*UpperArm",name="Tricep",zone="Flesh",size={{0.8,0},{0.58,0},{0.7,0}},mesh="Kit_RoundShell",pos={{0,0},{0.02,0},{0.2,0}},shade=1},
  {limb="*LowerArm",name="Forearm",zone="Flesh",size={{1.0,0},{0.6,0},{0.96,0}},mesh="Kit_RoundShell",pos={{0,0},{0.16,0},{0,0}}},
  {limb="*LowerArm",name="BracerTop",zone="Accent",size={{1.12,0},{0,0.16},{1.12,0}},mesh="Kit_Band",pos={{0,0},{-0.12,0},{0,0}}},
  {limb="*LowerArm",name="BracerBottom",zone="Accent",size={{1.12,0},{0,0.16},{1.12,0}},mesh="Kit_Band",pos={{0,0},{-0.42,0},{0,0}}},
  {limb="*LowerLeg",name="Calf",zone="Secondary",size={{0.8,0},{0.5,0},{0.7,0}},mesh="Kit_RoundShell",pos={{0,0},{0.2,0},{0.2,0}}},
  {limb="*Hand",name="HandWrap",zone="Dark",size={{1.06,0},{0,0.2},{1.06,0}},mesh="Kit_Band",pos={{0,0},{0.22,0},{0,0}}},
  -- Shield (aspis): a bronze disc on a Weld (pivot="shield") with its rim, boss and glowing ring welded to it.
  -- v28 (Peter: "give Bulwark a visible shield"): a bigger aspis, 4.2 studs across, standing well clear
  -- of the arm, with a thicker rim, a bigger boss and a brighter ring.
  {limb="LeftLowerArm",name="ShieldDisc",zone="Accent",size={{0,0.32},{0,4.2},{0,4.2}},pos={{-0.5,-0.45},{0.05,0},{0,0}},cyl=true,pivot="shield"},
  {limb="ShieldDisc",name="ShieldRim",zone="Metal",size={{0,4.36},{0,0.42},{0,4.36}},mesh="Kit_Band",rot=90},
  {limb="ShieldDisc",name="ShieldBoss",zone="Metal",size={{0,1.15},{0,0.55},{0,1.15}},mesh="Kit_Dome",pos={{0,-0.22},{0,0},{0,0}},rot=90},
  {limb="ShieldDisc",name="ShieldRing",zone="Emissive",size={{0,2.8},{0,0.08},{0,2.8}},mesh="Kit_Band",pos={{0,-0.18},{0,0},{0,0}},rot=90,neon=true},
  -- Sword: grip through the fist, blade pointing forward (it follows the arm in every pose).
  {limb="RightHand",name="SwordGrip",zone="Dark",size={{0,0.22},{0,0.8},{0,0.22}},mesh="Kit_Capsule",pos={{0,0},{-0.1,0},{0,0}},tilt=-90},
  {limb="RightHand",name="SwordGuard",zone="Accent",size={{0,0.2},{0,1.0},{0,0.2}},mesh="Kit_Pillow",pos={{0,0},{-0.1,0},{0,-0.5}}},
  {limb="RightHand",name="SwordPommel",zone="Accent",size={{0,0.3},{0,0.3},{0,0.3}},pos={{0,0},{-0.1,0},{0,0.48}},ball=true},
  {limb="RightHand",name="SwordBlade",zone="Metal",size={{0,0.08},{0,2.6},{0,0.36}},mesh="Kit_Pillow",pos={{0,0},{-0.1,0},{0,-1.88}},tilt=-90},
  {limb="RightHand",name="SwordTip",zone="Metal",size={{0,0.08},{0,0.36},{0,0.36}},mesh="Kit_Tile",pos={{0,0},{-0.1,0},{0,-3.16}},tilt=45},
  {limb="RightHand",name="SwordRune",zone="Emissive",size={{0,0.1},{0,1.9},{0,0.06}},mesh="Kit_Pillow",pos={{0,0},{-0.1,0},{0,-1.75}},tilt=-90,neon=true},
 },
}
-- Pieces a hero doesn't wear: Tempest goes without the shared shoulder domes and the bulky gauntlets,
-- and her panels replace the thigh stripes and side seams; Bulwark's cuirass replaces the side seams.
local HERO_HIDE={Tempest={ShoulderPlate=true,Gauntlet=true,ThighStripe=true,SideSeamL=true,SideSeamR=true},
 -- v34: Bulwark's arms and chest are bare, so no shoulder domes, gauntlets, arm bands or collar.
 Bulwark={SideSeamL=true,SideSeamR=true,ShoulderPlate=true,Gauntlet=true,GauntletTrim=true,ArmBand=true,Collar=true,TorsoShell=true,ArmShell=true}}
-- Hands: Bulwark's are armoured (Metal), Tempest wears long gloves (Secondary); the others are bare.
local HAND_ZONE={Bulwark="Flesh",Tempest="Secondary"}
-- Extra armour (v22) that exists only as sculpts: shown once HeroWars_KitSculpt2.glb is imported or its IDs
-- are in SCULPT_IDS, otherwise skipped. hide: trim lines the plate covers.
local EXTRAS={
 Shared={
  {extra=true,limb="*LowerLeg",name="ShinGuard",zone="Metal",mesh="Kit_ShinGuard",size={{1.1,0},{0.95,0},{0.62,0}},pos={{0,0},{0.03,0},{-0.28,0}},hide={"ShinStripe"}},
 },
 Solarion={
  {extra=true,limb="*UpperLeg",name="ThighPlate",zone="Metal",mesh="Kit_ThighPlate",size={{1.06,0},{0.8,0},{0.5,0}},pos={{0,0},{0.02,0},{-0.3,0}},hide={"ThighStripe"}},
  {extra=true,limb="UpperTorso",name="BackReactor",zone="Metal",mesh="Kit_SolReactor",size={{0,0.8},{0,0.8},{0,0.18}},pos={{0,0},{0,0.25},{0.5,0.06}}},
 },
 Wraithstep={},
 Bulwark={
  {extra=true,limb="*UpperLeg",name="ThighPlate",zone="Metal",mesh="Kit_ThighPlate",size={{1.06,0},{0.8,0},{0.5,0}},pos={{0,0},{0.02,0},{-0.3,0}},hide={"ThighStripe"}},
 },
}
-- Trim (v21): thin accent lines and dark soles so the suit reads as designed, not coloured-in.
local TRIM={
 {limb="*UpperArm",name="ArmBand",zone="Accent",size={{1.04,0},{0,0.12},{1.04,0}},mesh="Kit_Band",pos={{0,0},{-0.18,0},{0,0}}},
 {limb="*UpperLeg",name="ThighStripe",zone="Accent",size={{0,0.14},{0.8,0},{0,0.05}},mesh="Kit_Pillow",pos={{0,0},{0,0},{-0.5,-0.01}}},
 {limb="*LowerLeg",name="ShinStripe",zone="Accent",size={{0,0.12},{0.7,0},{0,0.05}},mesh="Kit_Pillow",pos={{0,0},{0.05,0},{-0.5,-0.04}}},
 {limb="UpperTorso",name="SideSeamL",zone="Accent",size={{0,0.06},{0.75,0},{0.9,0}},mesh="Kit_Pillow",pos={{-0.5,0},{-0.05,0},{0,0}}},
 {limb="UpperTorso",name="SideSeamR",zone="Accent",size={{0,0.06},{0.75,0},{0.9,0}},mesh="Kit_Pillow",pos={{0.5,0},{-0.05,0},{0,0}}},
 {limb="UpperTorso",name="Collar",zone="Dark",size={{0.5,0},{0,0.14},{0.62,0}},mesh="Kit_Band",pos={{0,0},{0.5,0},{0,0}}},
 {limb="*Foot",name="Sole",zone="Dark",size={{1.2,0},{0,0.1},{1.3,0}},mesh="Kit_Pillow",pos={{0,0},{-0.5,0.02},{0,-0.06}}},
}
local SHINE={Metal=0.22,Accent=0.08,Dark=0.04}
-- Pieces that cast a little light of their skin's glow colour (range in studs).
local LIGHTS={SolarCore=7,ThrusterGlowLeft=4,Visor=5,GrappleMuzzle=4,PackLight=4,EyeL=3,EyeSlitL=3,ShieldRing=5,CrownSpike3=4}
local function lin(spec, s)
 return Vector3.new(spec[1][1]*s.X+spec[1][2],spec[2][1]*s.Y+spec[2][2],spec[3][1]*s.Z+spec[3][2])
end
-- Paint the body and (re)build the kit armour for one skin. Safe to call on a live character:
-- every piece is massless and never queryable, so the fixed Hurtbox stays the only hit target.
-- The skin's own shield (Gear.Shield) on the left forearm, if it has one.
function Appearance.bodyShield(model, shield)
 local arm=model:FindFirstChild("LeftLowerArm")
 if shield and arm then
  -- Where the kit shield sits (its face looks out from the arm, -X), turned from "out of the back".
  local h=shield.handle:Clone()
  local s=arm.Size
  local k=4.2/math.max(h.Size.X,h.Size.Y,h.Size.Z,0.1)
  local mesh=h:FindFirstChildOfClass("SpecialMesh"); if mesh then mesh.Scale*=k end
  h.Size*=k
  local offset=CFrame.new(-0.5*s.X-0.45,0.05*s.Y,0)*CFrame.Angles(0,-math.pi/2,0)*shield.rot
  h.Name="ShieldDisc"; h.Anchored=false; h.CanCollide=false; h.CanTouch=false; h.CanQuery=false; h.Massless=true
  h:SetAttribute("KitPiece",true)
  local weld=Instance.new("Weld"); weld.Name="ShieldWeld"; weld.Part0=arm; weld.Part1=h; weld.C0=offset
  h.CFrame=arm.CFrame*offset; h.Parent=model; weld.Parent=h
 end
end
function Appearance.applySkin(model, hero, skin)
 model:SetAttribute("AppliedBody",nil)
 if not skin or not skin.Palette then return end
 local palette=skin.Palette
 -- v41: undo a Mixamo body from the last skin.
 for _,p in model:GetChildren() do
  if p:GetAttribute("BodyHidden") then p.Transparency=0; p:SetAttribute("BodyHidden",nil) end
 end
 local face0=model:FindFirstChild("Head") and model.Head:FindFirstChild("HumanFace")
 if face0 then face0.Enabled=hero~="Bulwark" end
 local smoothBody=model:GetAttribute("SmoothBody")==true
 -- Shells only cover the square body; the smooth body package needs none.
 local smooth=not smoothBody and Appearance.hasMeshes()
 for _,v in model:GetChildren() do if v:GetAttribute("KitPiece") then v:Destroy() end end
 for part,zone in ZONES do
  local p=model:FindFirstChild(part)
  -- With the smooth shells on, the blocky body underneath is hidden (it still animates and carries the welds).
  local z=(HERO_ZONES[hero] and HERO_ZONES[hero][part]) or zone
  if p then p.Color=color(palette,z); p.Transparency=smooth and 1 or 0; p.Material=Enum.Material.SmoothPlastic; p.Reflectance=(hero=="Bulwark" and z~="Flesh") and 0.14 or 0 end
 end
 for _,name in {"LeftHand","RightHand"} do
  local p=model:FindFirstChild(name)
  if p then p.Color=HAND_ZONE[hero] and color(palette,HAND_ZONE[hero]) or SKIN_TONE end
 end
 -- Tempest's drawn eyes glow in the skin's light colour under her neon eye pieces (v26).
 local face=model:FindFirstChild("Head") and model.Head:FindFirstChild("HumanFace")
 if face and hero=="Tempest" then
  for _,eye in face:GetDescendants() do if eye.Name=="Eye" then eye.BackgroundColor3=color(palette,"Emissive") end end
 end
 if skin.Body then
  for _,v in model:GetChildren() do if v:GetAttribute("KitPiece") then v:Destroy() end end
  if BODY.apply(model,skin.Body) then
   -- The Mixamo body is the whole look; only a skin shield goes on top (Bulwark's guard raises it).
   Appearance.bodyShield(model,shieldTemplate(skin,hero))
   local outline=Instance.new("Highlight"); outline.Name="Outline"; outline:SetAttribute("KitPiece",true)
   outline.FillTransparency=1; outline.OutlineColor=color(palette,"Dark"); outline.OutlineTransparency=0.35
   outline.DepthMode=Enum.HighlightDepthMode.Occluded; outline.Parent=model
   return
  end
 end
 local gear=skin.Gear and gearTemplates(skin,hero) or {}
 local hide={}
 if #gear>0 then for _,n in skin.Hide or {} do hide[n]=true end end
 local shield=shieldTemplate(skin,hero)
 if shield then for _,n in {"ShieldDisc","ShieldRim","ShieldBoss","ShieldRing"} do hide[n]=true end end
 local list={}
 for _,e in PIECES.Shared do table.insert(list,e) end
 for _,e in PIECES[hero] or {} do table.insert(list,e) end
 for _,e in HERO_PIECES[hero] or {} do table.insert(list,e) end
 for n in HERO_HIDE[hero] or {} do hide[n]=true end
 if model:GetAttribute("HeroBody") then for n in PACKAGE_HIDE[hero] or {} do hide[n]=true end end
 for _,e in EXTRAS.Shared do table.insert(list,e) end
 for _,e in EXTRAS[hero] or {} do table.insert(list,e) end
 for _,e in TRIM do table.insert(list,e) end
 for _,e in list do
  if (e.shell and not smooth) or hide[e.name] then continue end
  if e.onlySkins and not e.onlySkins[skin.Name or ""] then continue end
  if e.extra and not e.sculpt then
   -- An extra: only with its sculpt loaded.
   if not template(e.mesh) then continue end
   for _,n in e.hide or {} do hide[n]=true end
   e=table.clone(e); e.sculpt=true
  end
  -- With the sculpts imported, a sculpt can replace this piece (v20).
  local sc=sculptFor(hero,e.name,skin.Name)
  if sc then
   for _,n in sc.hide or {} do hide[n]=true end
   e={limb=e.limb,name=e.name,zone=e.zone,mesh=sc.mesh,size=sc.size or e.size,pos=sc.pos or e.pos,rot=e.rot,tilt=e.tilt,neon=e.neon,sculpt=true}
  end
  -- Armour pieces still use the smooth meshes on the smooth body when they're available.
  local limbs=string.sub(e.limb,1,1)=="*" and {"Left"..string.sub(e.limb,2),"Right"..string.sub(e.limb,2)} or {e.limb}
  for _,limbName in limbs do
   local limb=model:FindFirstChild(limbName)
   if limb and limb:IsA("BasePart") then
    local s=limb.Size
    local offset=CFrame.new(e.pos and lin(e.pos,s) or Vector3.zero)*CFrame.Angles(math.rad(e.tilt or 0),0,math.rad(e.rot or 0))
    if e.sculpt and SCULPT_YAW~=0 then offset=offset*CFrame.Angles(0,math.rad(SCULPT_YAW),0) end
    -- v19 finish: polished plates (metal and accent zones catch the light), real glow on the lit parts.
    local material=e.neon and Enum.Material.Neon or Enum.Material.SmoothPlastic
    local p=makePart(e.mesh,e.ball and Enum.PartType.Ball or e.cyl and Enum.PartType.Cylinder or nil)
    local tone=color(palette,e.zone)
    if e.shade==1 then tone=tone:Lerp(Color3.new(0,0,0),0.1) end
    if e.pivot then
     -- v26: hung on a Weld instead of a WeldConstraint so the client can swing it (hair, capes) or
     -- raise it (Bulwark's shield). Hair hangs from its top; the shield turns about its centre.
     attachPivot(model,limb,p,e.name,lin(e.size,s),offset,tone,material,e.pivot)
     if e.sway then p:SetAttribute("Sway",e.sway) end
    else
     attach(model,limb,p,e.name,lin(e.size,s),offset,tone,material)
    end
    p.Reflectance=e.neon and 0 or SHINE[e.zone] or 0
    p:SetAttribute("KitPiece",true)
    if e.neon and LIGHTS[e.name] then
     local light=Instance.new("PointLight"); light.Color=color(palette,e.zone)
     light.Range=LIGHTS[e.name]; light.Brightness=1.4; light.Shadows=false; light.Parent=p
    end
   end
  end
 end
 -- A soft dark outline so the hero reads clearly against the arena.
 local outline=Instance.new("Highlight"); outline.Name="Outline"; outline:SetAttribute("KitPiece",true)
 outline.FillTransparency=1; outline.OutlineColor=color(palette,"Dark"); outline.OutlineTransparency=0.35
 outline.DepthMode=Enum.HighlightDepthMode.Occluded; outline.Parent=model
 local humanoid=model:FindFirstChildOfClass("Humanoid")
 Appearance.bodyShield(model,shield)
 for _,t in gear do
  local acc=t:Clone(); acc:SetAttribute("KitPiece",true)
  -- Looks only: never collides, never queryable, never adds weight.
  for _,p in acc:GetDescendants() do
   if p:IsA("BasePart") then p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Massless=true end
  end
  -- v28: catalog hair takes the skin's Hair colour. A near-white Hair keeps the strand texture
  -- (tinted where the mesh allows it); any other colour replaces the texture with a flat colour.
  -- v29: some hair items are listed as Hat, so also go by the HairAttachment.
  local isHair=acc.AccessoryType==Enum.AccessoryType.Hair or acc:FindFirstChild("HairAttachment",true)~=nil
  if isHair and palette.Hair then
   local hc=color(palette,"Hair"); local light=math.min(hc.R,hc.G,hc.B)>0.85
   for _,p in acc:GetDescendants() do
    if p:IsA("SpecialMesh") then p.VertexColor=Vector3.new(hc.R,hc.G,hc.B)*(light and 1 or 1.4)
    elseif p:IsA("MeshPart") then
     p.Color=hc
     if not light then p.TextureID="" ; for _,sa in p:GetChildren() do if sa:IsA("SurfaceAppearance") then sa:Destroy() end end end
    elseif p:IsA("BasePart") and not light then p.Color=hc end
   end
  end
  humanoid:AddAccessory(acc)
 end
 ModernStyle.apply(model,hero,skin)
end
-- skin: an entry from Rules.Skins (falls back to the hero's first skin).
function Appearance.create(hero, definition, skin)
 skin=skin or Rules.skin(hero)
 local ok,model=false,nil
 local own=HERO_PACKAGE[hero]~=nil
 if own then
  ok,model=rig(true,hero,true)
  if not ok then warn("[HeroWars] "..hero.."'s own body did not load ("..tostring(model).."); using the Superhero body."); own=false end
 end
 if not ok then ok,model=rig(true,hero) end
 local smoothBody=ok
 if not ok then
  warn("[HeroWars] smooth body did not load ("..tostring(model).."); using the square body.")
  ok,model=rig(false,hero)
 end
 if not ok then error(model) end
 -- The client plays each hero's own idle/run/jump set (v19), so Roblox's default Animate must not run.
 local animate=model:FindFirstChild("Animate"); if animate then animate:Destroy() end
 if own and smoothBody then
  model:SetAttribute("HeroBody",true)
  -- Her own body is painted by zone, so its baked skin texture comes off.
  for _,p in model:GetChildren() do
   if p:IsA("MeshPart") and ZONES[p.Name] then p.TextureID=""; for _,sa in p:GetChildren() do if sa:IsA("SurfaceAppearance") then sa:Destroy() end end end
  end
 end
 reshape(model,hero)
 model.Name=hero
 model:SetAttribute("SmoothBody",smoothBody)
 -- Bare human hands are actual R15 hand meshes, not extra props or gloves.
 for _,name in {"LeftHand","RightHand"} do model[name].Color=SKIN_TONE; model[name].Transparency=0 end
 model.Head.Transparency=0
 for _,v in model:GetChildren() do
  if v:IsA("Shirt") or v:IsA("Pants") or v:IsA("ShirtGraphic") or v:IsA("Accessory") then v:Destroy() end
 end
 -- Explicit simple human facial features, independent of a catalog face asset.
 for _,v in model.Head:GetChildren() do if v:IsA("Decal") then v:Destroy() end end
 -- Bulwark's helmet closes over the whole head, so he has no drawn face (v25).
 local face=Instance.new("SurfaceGui"); face.Name="HumanFace"; face.Face=Enum.NormalId.Front
 face.Enabled=hero~="Bulwark"
 face.CanvasSize=Vector2.new(200,200); face.Parent=model.Head
 Appearance.drawFace(face,hero)
 Appearance.applySkin(model,hero,skin)
 local humanoid=model:FindFirstChildOfClass("Humanoid")
 humanoid.DisplayName=hero; humanoid.MaxHealth=definition.Health; humanoid.Health=definition.Health
 humanoid.WalkSpeed=definition.Speed; humanoid.UseJumpPower=true; humanoid.JumpPower=45
 model:SetAttribute("Hero",hero)
 return model
end
-- v49 (Peter: "new face features"): a fuller drawn face per hero: brows, eyes with whites, irises and a
-- glint, a nose line and a mouth, plus hero touches (Wraithstep's mask, Tempest's lashes and blush,
-- Solarion's sun mark). The client changes the expression (calm, fighting, hurt) by these part names.
local FACE={
 Solarion={iris={226,160,52},brow={70,42,30},browTilt=6,mouth="‿",mouthColor={90,40,34},mark=true},
 Wraithstep={iris={190,120,255},brow={20,18,26},browTilt=14,mask=true,glow=true},
 Tempest={iris={150,220,255},brow={60,40,46},browTilt=-4,mouth="◡",mouthColor={168,62,84},lashes=true,blush=true},
 Bulwark={iris={110,170,220},brow={60,50,46},browTilt=10,mouth="—",mouthColor={80,40,34}},
}
local function frame(parent,name,pos,size,rgb,round)
 local f=Instance.new("Frame"); f.Name=name; f.BorderSizePixel=0; f.Position=pos; f.Size=size
 f.BackgroundColor3=Color3.fromRGB(rgb[1],rgb[2],rgb[3]); f.Parent=parent
 if round then local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(round,0); c.Parent=f end
 return f
end
function Appearance.drawFace(face,hero)
 local d=FACE[hero] or FACE.Solarion
 face:SetAttribute("BrowTilt",d.browTilt)
 if d.mask then frame(face,"Mask",UDim2.fromOffset(18,104),UDim2.fromOffset(164,96),{22,20,30},0.12) end
 for i,x in {48,118} do
  local side=i==1 and "L" or "R"
  local white=frame(face,"EyeWhite"..side,UDim2.fromOffset(x,70),UDim2.fromOffset(34,24),d.glow and {30,18,44} or {245,242,236},1)
  white.ClipsDescendants=true
  local iris=frame(white,"Eye",UDim2.fromOffset(9,2),UDim2.fromOffset(17,20),d.iris,1)
  if d.glow then iris.Size=UDim2.fromOffset(22,10); iris.Position=UDim2.fromOffset(6,7) end
  frame(iris,"Pupil",UDim2.fromScale(0.3,0.25),UDim2.fromScale(0.42,0.5),{15,12,14},1)
  frame(iris,"Glint",UDim2.fromScale(0.58,0.12),UDim2.fromScale(0.26,0.26),{255,255,255},1)
  local brow=frame(face,"Brow"..side,UDim2.fromOffset(x-2,56),UDim2.fromOffset(38,7),d.brow,1)
  brow.Rotation=(i==1 and 1 or -1)*d.browTilt
  if d.lashes then
   local lash=frame(face,"Lash"..side,UDim2.fromOffset(x+(i==1 and -6 or 30),68),UDim2.fromOffset(10,4),{30,20,24},1)
   lash.Rotation=i==1 and 25 or -25
  end
  if d.blush then local b=frame(face,"Blush"..side,UDim2.fromOffset(x-4,104),UDim2.fromOffset(26,12),{240,140,150},1); b.BackgroundTransparency=0.55 end
 end
 if not d.mask then
  local nose=frame(face,"Nose",UDim2.fromOffset(95,96),UDim2.fromOffset(10,18),{0,0,0},1); nose.BackgroundTransparency=0.85
  local mouth=Instance.new("TextLabel"); mouth.Name="Mouth"; mouth.BackgroundTransparency=1
  mouth.Position=UDim2.fromOffset(50,112); mouth.Size=UDim2.fromOffset(100,44)
  mouth.Text=d.mouth; mouth.TextSize=40; mouth.TextColor3=Color3.fromRGB(d.mouthColor[1],d.mouthColor[2],d.mouthColor[3])
  mouth:SetAttribute("Calm",d.mouth); mouth.Parent=face
 end
 if d.mark then frame(face,"SunMark",UDim2.fromOffset(93,30),UDim2.fromOffset(14,14),{255,200,80},1).Rotation=45 end
end
return Appearance
