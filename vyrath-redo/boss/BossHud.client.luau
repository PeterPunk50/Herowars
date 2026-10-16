-- Boss HP bar, state line, and click-to-hit for the test bed.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local remote=RS:WaitForChild("BossTest")
local model=workspace:WaitForChild("Vyrath")
local gui=Instance.new("ScreenGui"); gui.Name="BossHud"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local bar=Instance.new("Frame"); bar.Size=UDim2.new(0.5,0,0,18); bar.Position=UDim2.new(0.25,0,0,24); bar.BackgroundColor3=Color3.fromRGB(30,30,30); bar.BorderSizePixel=0; bar.Parent=gui
local fill=Instance.new("Frame"); fill.Size=UDim2.new(1,0,1,0); fill.BackgroundColor3=Color3.fromRGB(90,160,255); fill.BorderSizePixel=0; fill.Parent=bar
local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,0,0,22); label.Position=UDim2.new(0,0,0,44); label.BackgroundTransparency=1; label.TextColor3=Color3.new(1,1,1); label.TextStrokeTransparency=0.4; label.Font=Enum.Font.GothamBold; label.TextSize=16; label.Parent=bar
local tip=Instance.new("TextLabel"); tip.Size=UDim2.new(1,0,0,20); tip.Position=UDim2.new(0,0,1,-26); tip.BackgroundTransparency=1; tip.TextColor3=Color3.new(1,1,1); tip.TextStrokeTransparency=0.4; tip.Font=Enum.Font.Gotham; tip.TextSize=14; tip.Text="Click the dragon to hit it (20). Weak points: throat, crown, wing roots. The throat takes extra while it is exposed."; tip.Parent=gui
local function refresh()
 local hp,mx=model:GetAttribute("HP") or 0,model:GetAttribute("MaxHP") or 1
 fill.Size=UDim2.new(math.clamp(hp/mx,0,1),0,1,0)
 label.Text=("Vyrath %d / %d   %s%s"):format(hp,mx,tostring(model:GetAttribute("State")),model:GetAttribute("Exposed") and "  EXPOSED" or "")
 fill.BackgroundColor3=model:GetAttribute("Exposed") and Color3.fromRGB(255,200,90) or Color3.fromRGB(90,160,255)
end
model.AttributeChanged:Connect(refresh); refresh()
UIS.InputBegan:Connect(function(input,gp)
 if gp or input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
 local cam=workspace.CurrentCamera
 local ray=cam:ViewportPointToRay(input.Position.X,input.Position.Y)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Include; params.FilterDescendantsInstances={model}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*300,params)
 if hit then remote:FireServer("Hit",hit.Position,20) end
end)
