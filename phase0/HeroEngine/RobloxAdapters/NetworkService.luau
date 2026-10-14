-- HeroEngine Phase 0 Roblox adapter: the only door between clients and the server.
-- Clients send requests (an action name and a small table); the server checks the action is on its list,
-- rate-limits each player and hands the request to a handler, which validates everything else. Clients never
-- send damage, health, targets or positions: the server works those out (server authority).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NetworkService = {}
NetworkService.PerSecond = 30 -- requests a player may send per second before the rest are dropped

local function remoteFor(name)
 local folder = ReplicatedStorage:FindFirstChild("HeroEngineNet")
 if RunService:IsServer() then
  if not folder then folder = Instance.new("Folder"); folder.Name = "HeroEngineNet"; folder.Parent = ReplicatedStorage end
  local r = folder:FindFirstChild(name)
  if not r then r = Instance.new("RemoteEvent"); r.Name = name; r.Parent = folder end
  return r
 end
 return ReplicatedStorage:WaitForChild("HeroEngineNet"):WaitForChild(name)
end

-- Server side. handlers[action] = function(player, data) ... end
function NetworkService.server(name, handlers)
 local remote = remoteFor(name)
 local budget = {}
 remote.OnServerEvent:Connect(function(player, action, data)
  local handler = type(action) == "string" and handlers[action]
  if not handler then return end
  if data ~= nil and type(data) ~= "table" then return end
  local now = os.clock()
  local b = budget[player]
  if not b or now - b.since >= 1 then b = {since = now, n = 0}; budget[player] = b end
  b.n += 1
  if b.n > NetworkService.PerSecond then return end
  handler(player, data or {})
 end)
 game:GetService("Players").PlayerRemoving:Connect(function(p) budget[p] = nil end)
 return {
  send = function(player, kind, payload) remote:FireClient(player, kind, payload) end,
  broadcast = function(kind, payload) remote:FireAllClients(kind, payload) end,
 }
end

-- Client side.
function NetworkService.client(name)
 local remote = remoteFor(name)
 return {
  request = function(action, data) remote:FireServer(action, data) end,
  on = function(handler) return remote.OnClientEvent:Connect(handler) end,
 }
end

return NetworkService
