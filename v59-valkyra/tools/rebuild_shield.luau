-- V59: rebuild the winged shield MeshPart from its uploaded assets (no new upload) and tag it for build_v59.py.
local AS = game:GetService("AssetService")
local MESH, COLOR, NORMAL, MR = "rbxassetid://139531211590273", "rbxassetid://87397162701694", "rbxassetid://74531930349025", "rbxassetid://114144180687156"
local old = workspace:FindFirstChild("WingedShieldKit"); if old then old:Destroy() end
local mp = AS:CreateMeshPartAsync(Content.fromUri(MESH))
mp.Name = "WingedShield"
local sa = Instance.new("SurfaceAppearance")
local ok1 = pcall(function() sa.ColorMapContent = Content.fromUri(COLOR); sa.NormalMapContent = Content.fromUri(NORMAL); sa.MetalnessMapContent = Content.fromUri(MR); sa.RoughnessMapContent = Content.fromUri(MR) end)
if not ok1 then pcall(function() sa.ColorMap = COLOR; sa.NormalMap = NORMAL; sa.MetalnessMap = MR; sa.RoughnessMap = MR end) end
sa.Parent = mp
local native = mp.Size
mp.Size = native * 1.9
mp.Anchored = true; mp.CanCollide = false; mp.CanTouch = false; mp.CanQuery = false; mp.Massless = true
local kit = Instance.new("Model"); kit.Name = "WingedShieldKit"
mp.CFrame = CFrame.new(0, mp.Size.Y / 2, -5); mp.Parent = kit
local off = Instance.new("CFrameValue"); off.Name = "ArmOffset"; off.Value = CFrame.new(-(0.229 + mp.Size.X / 2 - 0.06), -0.18, 0); off.Parent = kit
kit.Parent = workspace
return string.format("rebuilt: native %s -> %s; SA color %s normal %s; ArmOffset %s", tostring(native), tostring(mp.Size), tostring(sa.ColorMap), tostring(sa.NormalMap), tostring(off.Value.Position))
