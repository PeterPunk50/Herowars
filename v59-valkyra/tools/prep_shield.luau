-- V59: turn the imported Tripo winged shield into the kit build_v59.py expects (run in Valkyra_shield_import, Edit).
-- Model "WingedShieldKit" = MeshPart "WingedShield" (scaled 1.9x: about 1.9 studs tall and wide) + CFrameValue "ArmOffset"
-- (its CFrame relative to her LeftLowerArm at rest: on the outer side of the forearm, crest (mesh -X) facing out).
local scene = workspace:FindFirstChild("Scene") or workspace:FindFirstChild("WingedShieldKit")
assert(scene, "imported model not found")
local mp = scene:FindFirstChildWhichIsA("MeshPart", true)
mp.Name = "WingedShield"
local k = 1.9
if mp.Size.Y < 1.2 then mp.Size = mp.Size * k end
mp.Anchored = true; mp.CanCollide = false; mp.CanTouch = false; mp.CanQuery = false; mp.Massless = true; mp.CastShadow = true
scene.Name = "WingedShieldKit"
for _, c in scene:GetChildren() do if c ~= mp and not c:IsA("CFrameValue") then c:Destroy() end end
mp.Parent = scene
local off = scene:FindFirstChild("ArmOffset") or Instance.new("CFrameValue")
off.Name = "ArmOffset"; off.Value = CFrame.new(-(0.229 + mp.Size.X / 2 - 0.06), -0.18, 0); off.Parent = scene
return string.format("WingedShield size %s, ArmOffset %s", tostring(mp.Size), tostring(off.Value.Position))
