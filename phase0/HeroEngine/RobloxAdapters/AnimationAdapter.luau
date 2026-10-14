-- HeroEngine Phase 0 Roblox adapter (client): how an engine event looks on screen. Phase 0 uses a simple
-- procedural arm swing, a red flash on the target and a floating damage number, so the test works with plain
-- Roblox avatars. Phase 1 points `attack` at the game's real motion (HeroWars MocapData / FlightMotion).
local TweenService = game:GetService("TweenService")

local AnimationAdapter = {}

-- Swing the right arm forward over the wind-up, then back.
function AnimationAdapter.attack(model, startupSeconds)
 local arm = model and model:FindFirstChild("RightUpperArm")
 local joint = arm and arm:FindFirstChild("RightShoulder")
 if not joint or not joint:IsA("Motor6D") then return end
 local rest = joint:GetAttribute("RestC0")
 if not rest then rest = joint.C0; joint:SetAttribute("RestC0", rest) end
 local out = TweenService:Create(joint, TweenInfo.new(math.max(0.05, startupSeconds)), {C0 = rest * CFrame.Angles(math.rad(95), 0, 0)})
 out:Play()
 out.Completed:Once(function()
  TweenService:Create(joint, TweenInfo.new(0.15), {C0 = rest}):Play()
 end)
end

function AnimationAdapter.hit(model, damage, result)
 if not model then return end
 local h = Instance.new("Highlight")
 h.FillColor = Color3.fromRGB(255, 60, 60); h.FillTransparency = 0.4; h.OutlineTransparency = 1
 h.Parent = model
 task.delay(0.15, function() h:Destroy() end)
 local head = model:FindFirstChild("Head")
 if not head then return end
 local gui = Instance.new("BillboardGui")
 gui.Size = UDim2.fromOffset(120, 40); gui.StudsOffset = Vector3.new(0, 2.5, 0); gui.AlwaysOnTop = true
 local label = Instance.new("TextLabel")
 label.Size = UDim2.fromScale(1, 1); label.BackgroundTransparency = 1
 label.Font = Enum.Font.GothamBlack; label.TextScaled = true
 label.TextColor3 = Color3.fromRGB(255, 220, 90); label.TextStrokeTransparency = 0.3
 label.Text = result == "Hit" and tostring(damage) or (tostring(damage) .. " " .. result)
 label.Parent = gui; gui.Parent = head
 TweenService:Create(gui, TweenInfo.new(0.8), {StudsOffset = Vector3.new(0, 5, 0)}):Play()
 TweenService:Create(label, TweenInfo.new(0.8), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
 task.delay(0.8, function() gui:Destroy() end)
end

return AnimationAdapter
