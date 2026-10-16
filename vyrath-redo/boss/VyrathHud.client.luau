-- Vyrath boss HUD for HeroWars: HP bar and state while the dragon is in the arena; B summons or dismisses it.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local remote=RS:WaitForChild("HeroWars"):WaitForChild("Combat")
local gui=Instance.new("ScreenGui"); gui.Name="VyrathHud"; gui.ResetOnSpawn=false; gui.DisplayOrder=5; gui.Parent=player:WaitForChild("PlayerGui")
local bar=Instance.new("Frame"); bar.Size=UDim2.new(0.44,0,0,16); bar.Position=UDim2.new(0.28,0,0,64); bar.BackgroundColor3=Color3.fromRGB(25,25,30); bar.BorderSizePixel=0; bar.Visible=false; bar.Parent=gui
local fill=Instance.new("Frame"); fill.Size=UDim2.new(1,0,1,0); fill.BackgroundColor3=Color3.fromRGB(90,160,255); fill.BorderSizePixel=0; fill.Parent=bar
local label=Instance.new("TextLabel"); label.Size=UDim2.new(1,0,0,20); label.Position=UDim2.new(0,0,1,2); label.BackgroundTransparency=1; label.TextColor3=Color3.new(1,1,1); label.TextStrokeTransparency=0.4; label.Font=Enum.Font.GothamBold; label.TextSize=15; label.Parent=bar
local tip=Instance.new("TextLabel"); tip.Size=UDim2.new(0,320,0,18); tip.Position=UDim2.new(1,-332,1,-70); tip.BackgroundTransparency=1; tip.TextColor3=Color3.fromRGB(220,220,230); tip.TextStrokeTransparency=0.5; tip.Font=Enum.Font.Gotham; tip.TextSize=13; tip.TextXAlignment=Enum.TextXAlignment.Right; tip.Text="B: summon / dismiss Vyrath (raid boss test)"; tip.Parent=gui
local model
local function refresh()
 if not model or not model.Parent then bar.Visible=false; return end
 bar.Visible=true
 local hp,mx=model:GetAttribute("HP") or 0,model:GetAttribute("MaxHP") or 1
 fill.Size=UDim2.new(math.clamp(hp/mx,0,1),0,1,0)
 local ex=model:GetAttribute("Exposed")
 label.Text=("VYRATH  %d / %d   %s%s"):format(hp,mx,tostring(model:GetAttribute("State") or ""),ex and "   WEAK POINT OPEN" or "")
 fill.BackgroundColor3=ex and Color3.fromRGB(255,200,90) or (hp/mx>0.3 and Color3.fromRGB(90,160,255) or Color3.fromRGB(220,70,60))
end
local function watch(m)
 model=m; refresh()
 m.AttributeChanged:Connect(refresh)
 m.AncestryChanged:Connect(function() if not m:IsDescendantOf(workspace) then if model==m then model=nil end; refresh() end end)
end
local existing=workspace:FindFirstChild("Vyrath"); if existing then watch(existing) end
workspace.ChildAdded:Connect(function(c) if c.Name=="Vyrath" and c:IsA("Model") then watch(c) end end)
UIS.InputBegan:Connect(function(input,gp)
 if gp or input.KeyCode~=Enum.KeyCode.B then return end
 remote:FireServer("Boss","toggle")
end)
