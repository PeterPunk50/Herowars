-- HeroEngine Phase 0 integration test (client). Sends only requests; shows what the server decided.
-- Keys: 1 = combo (Sun Jab, Flare Cross, Corona Kick), 2 = Solar Hammer / Grave Scythe, 3 = next rigged body,
-- R = reset the test.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Adapters = ReplicatedStorage:WaitForChild("HeroEngine"):WaitForChild("RobloxAdapters")
local NetworkService = require(Adapters.NetworkService)
local AnimationAdapter = require(Adapters.AnimationAdapter)
local player = Players.LocalPlayer
local net = NetworkService.client("HeroEngine")

local gui = Instance.new("ScreenGui")
gui.Name = "Phase0"; gui.ResetOnSpawn = false; gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("TextLabel")
panel.Size = UDim2.new(0, 460, 0, 210); panel.Position = UDim2.new(0, 12, 0, 60)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 26); panel.BackgroundTransparency = 0.25
panel.TextColor3 = Color3.new(1, 1, 1); panel.Font = Enum.Font.Code; panel.TextSize = 14
panel.TextXAlignment = Enum.TextXAlignment.Left; panel.TextYAlignment = Enum.TextYAlignment.Top
panel.TextWrapped = true; panel.Parent = gui
local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingTop = UDim.new(0, 6); pad.Parent = panel

local lines = {}
local function healthLine()
 local out = {}
 for _, p in Players:GetPlayers() do
  local c = p.Character
  local h = c and c:FindFirstChildOfClass("Humanoid")
  local hero = p:GetAttribute("Hero") or "?"
  if h then table.insert(out, string.format("%s (%s) %d/%d", hero, p.Name, math.floor(h.Health + 0.5), h.MaxHealth)) end
 end
 return table.concat(out, "   ")
end
local function redraw()
 local hero = player:GetAttribute("Hero") or "?"
 local how = hero == "Solarion" and "Press 1 to jab Wraithstep (2 = Solar Hammer). 3 = next rig body. R resets."
  or hero == "Wraithstep" and "Stand still and let Solarion hit you (1/2 hit back). 3 = next rig body. R resets."
  or "Spectating: only two fighters in this test."
 panel.Text = string.format("HeroEngine Phase 0 test   You are: %s\n%s\n%s\nResult: %s\n\n%s", hero, how, healthLine(),
  tostring(workspace:GetAttribute("Phase0Result")), table.concat(lines, "\n"))
end
local function add(text)
 table.insert(lines, 1, text)
 if #lines > 6 then table.remove(lines) end
 redraw()
end

net.on(function(kind, data)
 if kind == "Log" then add(data.text)
 elseif kind == "Attack" then AnimationAdapter.attack(data.model, data.startup)
 elseif kind == "Hit" then AnimationAdapter.hit(data.target, data.damage, data.result); redraw()
 elseif kind == "Ack" and not data.ok then add("Server refused " .. data.input .. ": " .. tostring(data.why))
 end
end)

UserInputService.InputBegan:Connect(function(input, typing)
 if typing then return end
 if input.KeyCode == Enum.KeyCode.One then net.request("Use", {input = "Light"})
 elseif input.KeyCode == Enum.KeyCode.Two then net.request("Use", {input = "Heavy"})
 elseif input.KeyCode == Enum.KeyCode.Three then net.request("Body", {})
 elseif input.KeyCode == Enum.KeyCode.R then net.request("Reset", {})
 end
end)
workspace:GetAttributeChangedSignal("Phase0Result"):Connect(redraw)
player:GetAttributeChangedSignal("Hero"):Connect(redraw)
task.spawn(function() while true do redraw(); task.wait(0.5) end end)
