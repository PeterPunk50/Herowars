-- V60 visual check (Edit data model): a copy of Dread Knight's rig standing at the origin with the same cold-fire eyes
-- (Sig.coldEyes) and two cold-fire footprints (Sig.coldPrint, without the fade) as the client makes in play, and the
-- camera on his helmet. Delete workspace.ColdFireLook afterwards. Arg: none.
local HW = game.ReplicatedStorage.HeroWars
local old = workspace:FindFirstChild("ColdFireLook"); if old then old:Destroy() end
local m = HW.Rigs.VarnT:Clone(); m.Name = "ColdFireLook"
for _, p in m:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true end end
m.Parent = workspace
local root = m:FindFirstChild("HumanoidRootPart")
m:PivotTo(CFrame.new(0, 0, 0)) -- faces -Z, like every rig; the camera stands on -Z
local box = m:GetExtentsSize(); local cf = m:GetBoundingBox()
m:PivotTo(m:GetPivot() + Vector3.new(0, box.Y / 2 - cf.Position.Y, 0))       -- feet on y 0
local COLD = Color3.fromRGB(215, 240, 255)
local head = m:FindFirstChild("Head")
local sx, sy, sz = head.Size.X, head.Size.Y, head.Size.Z
for _, side in {{"L", -1}, {"R", 1}} do
	local a = Instance.new("Attachment"); a.Name = "ColdFireEye" .. side[1]; a.Position = Vector3.new(side[2] * sx * 0.095, -sy * 0.125, -sz * 0.52); a.Parent = head
	local e = Instance.new("ParticleEmitter"); e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 190, 255))
	e.LightEmission = 1; e.LightInfluence = 0; e.Brightness = 3; e.Rate = 40; e.Lifetime = NumberRange.new(0.3, 0.5); e.Speed = NumberRange.new(0.5, 1.1)
	e.SpreadAngle = Vector2.new(12, 12); e.Acceleration = Vector3.new(0, 2.5, 0)
	e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0.02)})
	local core = Instance.new("ParticleEmitter"); core.Texture = "rbxasset://textures/particles/sparkles_main.dds"; core.Color = ColorSequence.new(Color3.new(1, 1, 1)); core.LightEmission = 1; core.LightInfluence = 0; core.Brightness = 5; core.Rate = 24; core.Lifetime = NumberRange.new(0.15, 0.25); core.Speed = NumberRange.new(0, 0.1); core.Size = NumberSequence.new(0.09); core.Parent = a
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1)}); e.EmissionDirection = Enum.NormalId.Top; e.Parent = a
end
local l = Instance.new("PointLight"); l.Color = COLD; l.Brightness = 1.6; l.Range = 5; l.Parent = head
for _, f in {"LeftFoot", "RightFoot"} do
	local foot = m:FindFirstChild(f)
	local at = Vector3.new(foot.Position.X, 0.06, foot.Position.Z - 1.4)
	local disc = Instance.new("Part"); disc.Name = "ColdPrint"; disc.Anchored = true; disc.CanCollide = false; disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(0.06, 1.1, 1.1); disc.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2); disc.Color = Color3.fromRGB(150, 210, 255); disc.Material = Enum.Material.Neon; disc.Transparency = 0.55; disc.Parent = m
	local core = disc:Clone(); core.Size = Vector3.new(0.06, 0.44, 0.44); core.Color = Color3.new(1, 1, 1); core.Transparency = 0.3; core.CFrame = disc.CFrame + Vector3.new(0, 0.01, 0); core.Parent = m
	local a = Instance.new("Attachment"); a.Parent = disc
	local e = Instance.new("ParticleEmitter"); e.Texture = "rbxasset://textures/particles/smoke_main.dds"; e.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 190, 255))
	e.LightEmission = 0.8; e.LightInfluence = 0; e.Rate = 14; e.Lifetime = NumberRange.new(0.5, 0.9); e.Speed = NumberRange.new(1, 2.2); e.SpreadAngle = Vector2.new(20, 20)
	e.Acceleration = Vector3.new(0, 2, 0); e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.05)})
	e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1)}); e.EmissionDirection = Enum.NormalId.Right; e.Parent = a
end
game.Lighting.ClockTime = 20.5                                         -- dusk, so the cold fire reads
local cam = workspace.CurrentCamera; cam.CameraType = Enum.CameraType.Scriptable
cam.CFrame = CFrame.lookAt(head.Position + Vector3.new(0.6, 0.2, -3.2), head.Position)
return string.format("ColdFireLook at the origin, %.1f studs tall, head %s, eyes at x +-%.2f y %.2f z %.2f (head space)", box.Y, tostring(head.Size), sx * 0.095, -sy * 0.125, -sz * 0.52)
