-- V60: turn the imported Tripo greatsword into the kit build_v60.py expects (run in DreadKnight_sword_import, Edit).
-- Model "GreatswordKit" = MeshPart "Greatsword" (4.2 studs long; blade along local +Y, pommel at -Y, flat across local X,
-- crossguard along local Z) + CFrameValue "HandOffset" (its CFrame relative to his RightHand; set by measure_idle_hand).
local scene = workspace:FindFirstChild("Scene"); local kit = workspace:FindFirstChild("GreatswordKit")
local mp = (kit or scene):FindFirstChildWhichIsA("MeshPart", true); assert(mp, "no imported MeshPart")
if not kit then kit = Instance.new("Model"); kit.Name = "GreatswordKit"; kit.Parent = workspace end
mp.Parent = kit                                   -- reparent first, then clear the importer's container
if scene and scene ~= kit then scene:Destroy() end
mp.Name = "Greatsword"
local L = 4.2
if mp.Size.Y < 2 then mp.Size = mp.Size * (L / mp.Size.Y) end
mp.Anchored = true; mp.CanCollide = false; mp.CanTouch = false; mp.CanQuery = false; mp.Massless = true
mp.CFrame = CFrame.new(0, mp.Size.Y / 2, -6)
local off = kit:FindFirstChild("HandOffset") or Instance.new("CFrameValue"); off.Name = "HandOffset"; off.Parent = kit
local sa = mp:FindFirstChildOfClass("SurfaceAppearance")
return string.format("Greatsword size %s, SA %s, kit children %d", tostring(mp.Size), tostring(sa ~= nil), #kit:GetChildren())
