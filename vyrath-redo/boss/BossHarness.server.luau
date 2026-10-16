-- Test bed harness for the Vyrath boss: a floor, a spawn, the boss, and a remote so a player can hit it by clicking.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Boss=require(script.Parent.Boss)
local D=require(script.Parent.BossData)
local floor=workspace:FindFirstChild("Floor") or Instance.new("Part")
floor.Name="Floor"; floor.Anchored=true; floor.Size=Vector3.new(400,1,400); floor.Position=Vector3.new(0,-0.5,0)
floor.Color=Color3.fromRGB(70,80,70); floor.Material=Enum.Material.Slate; floor.Parent=workspace
if not workspace:FindFirstChild("Spawn") then
 local sp=Instance.new("SpawnLocation"); sp.Name="Spawn"; sp.Anchored=true; sp.Size=Vector3.new(8,1,8); sp.Position=Vector3.new(0,0.5,70); sp.Parent=workspace
end
-- a few blocks so the "no attacks through occlusion" rule can be seen
for i,p in {Vector3.new(30,5,40),Vector3.new(-30,5,45)} do
 local b=workspace:FindFirstChild("Block"..i) or Instance.new("Part"); b.Name="Block"..i; b.Anchored=true; b.Size=Vector3.new(10,10,4); b.Position=p; b.Color=Color3.fromRGB(110,110,120); b.Parent=workspace
end
local model=workspace:WaitForChild("Vyrath")
local saves=game.ServerStorage.RBX_ANIMSAVES:FindFirstChild("Vyrath_all2")
local clips={}
for _,name in D.Clips do
 clips[name]=D.AnimationIds[name] or (saves and saves:FindFirstChild("Armature|"..name)) or error("no clip "..name)
end
local remote=RS:FindFirstChild("BossTest") or Instance.new("RemoteEvent"); remote.Name="BossTest"; remote.Parent=RS
local log={}
local function note(...) local s=table.concat({...}," "); table.insert(log,("%.2f %s"):format(os.clock(),s)); print("[Vyrath]",s) end
local boss=Boss.new(model,clips,{
 targets=function()
  local t={}
  for _,p in Players:GetPlayers() do
   local c=p.Character; local h=c and c:FindFirstChildOfClass("Humanoid"); local r=c and c:FindFirstChild("HumanoidRootPart")
   if h and r then table.insert(t,{model=c,root=r,hum=h,player=p}) end
  end
  for _,m in workspace:GetChildren() do -- stand-in targets named Dummy*
   if m:IsA("Model") and m.Name:sub(1,5)=="Dummy" then local h=m:FindFirstChildOfClass("Humanoid"); local r=m:FindFirstChild("HumanoidRootPart"); if h and r then table.insert(t,{model=m,root=r,hum=h}) end end
  end
  return t
 end,
 onEvent=function(name,...) note(name,...); remote:FireAllClients("Event",name,...) end,
 log=note,
})
-- Control hook for scripted tests (the Studio MCP cannot see this script's _G): ServerStorage.VyrathControl:Invoke(kind,...)
local ctl=game.ServerStorage:FindFirstChild("VyrathControl") or Instance.new("BindableFunction"); ctl.Name="VyrathControl"; ctl.Parent=game.ServerStorage
ctl.OnInvoke=function(kind,a,b,c)
 if kind=="hit" then return boss:hit(a,b,c)
 elseif kind=="log" then return table.concat(log,"\n",math.max(1,#log-(a or 40)))
 elseif kind=="state" then return {state=boss.state,hp=boss.hp,pos=boss.pos,yaw=math.deg(boss.yaw),frame=boss:frames(),exposed=boss.exposed,weak=boss.weak,t=boss.t}
 elseif kind=="play" then boss:play(a); return true
 elseif kind=="socket" then local s=boss:socket(a); return s and s.Position
 elseif kind=="cooldowns" then boss.cool={}; return true
 end
end
remote.OnServerEvent:Connect(function(player,kind,pos,damage)
 if kind=="Hit" and typeof(pos)=="Vector3" then
  local c=player.Character; local r=c and c:FindFirstChild("HumanoidRootPart")
  if r and (r.Position-pos).Magnitude<=60 then boss:hit(math.clamp(tonumber(damage) or 20,1,60),pos,player.Name) end
 end
end)
note("boss up, HP",D.HP)
