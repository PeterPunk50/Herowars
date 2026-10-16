-- Joins the Vyrath boss controller to HeroWars' Main: spawns and clears the dragon, lets hero attacks hit its hurt
-- volumes, routes its breath and tail damage through the fighters' state, and keeps it in step with Pause.
-- Main calls BossLink.start(ctx) once its locals exist, then BossLink.tryHit from hitTargets and BossLink.command
-- from the Combat remote. ctx: {states=,alive=,remote=,notify=,tick=function,paused=function,fury=,super=,endInvisible=}.
local SS=game:GetService("ServerStorage")
local Boss=require(script.Parent.Boss)
local D=require(script.Parent.BossData)
local L={boss=nil,model=nil,ctx=nil}
local SPAWN=Vector3.new(0,-0.7536,-78) -- pivot height puts the paws on the arena floor (y=0); near the far wall, behind the obstacles

local function clipsFor()
 local src=SS:FindFirstChild("VyrathBoss")
 local clips={}
 for _,name in D.Clips do
  local ks=src and src.Clips:FindFirstChild("Armature|"..name)
  clips[name]=D.AnimationIds[name] or ks or error("Vyrath clip missing: "..name)
 end
 return clips
end

-- Hero attacks: the attack box (centre CFrame, size) against the dragon's capsules; the contact point decides the zone.
local function pointInBox(p,cf,half,pad)
 local l=cf:PointToObjectSpace(p)
 return math.abs(l.X)<=half.X+pad and math.abs(l.Y)<=half.Y+pad and math.abs(l.Z)<=half.Z+pad
end
function L.tryHit(s,a,center,size)
 local boss=L.boss; if not boss or not boss.alive or a.hit[L.model] then return false end
 local half=size/2; local best,bestD
 for _,c in boss:volumes() do
  for i=0,5 do
   local p=c.a:Lerp(c.b,i/5)
   if pointInBox(p,center,half,c.r) then
    local d=(p-s.root.Position).Magnitude
    if not bestD or d<bestD then best,bestD=p,d end
   end
  end
 end
 if not best then return false end
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={s.model}
 local ray=workspace:Raycast(s.root.Position,best-s.root.Position,params)
 if ray and not ray.Instance:IsDescendantOf(L.model) then return false end
 local ctx=L.ctx; local move=a.move; local tick=ctx.tick()
 local base=(move.AirDamage and s.flying) and move.AirDamage or move.Damage
 local dmg=boss:hit(base,best,s.model)
 a.hit[L.model]=true; a.confirmed=true; a.contact=true; a.anyHit=true; a.direct=true
 s.lastCombat=tick; s.damage+=dmg; s.hits+=1
 s.fury=math.min(ctx.fury.Max,s.fury+(move.Fury or 0))
 if not move.Super then s.super=math.min(ctx.super.Max,(s.super or 0)+dmg*ctx.super.PerDamageDealt) end
 local stop=move.HitStop or 0
 s.hitstop=math.max(s.hitstop or 0,tick+stop)
 ctx.remote:FireAllClients("Hit",L.model,"Hit",dmg,s.model,a.name,stop,false,false,nil)
 return true
end

function L.init(ctx) L.ctx=ctx end
function L.start(ctx)
 L.ctx=ctx or L.ctx; ctx=L.ctx
 if L.model then return L.boss end
 local src=SS:FindFirstChild("VyrathBoss"); if not src then warn("[Vyrath] ServerStorage.VyrathBoss missing"); return nil end
 local model=src.Vyrath:Clone(); model.Name="Vyrath"
 -- invisible parts the client effects look for (damage numbers hang off Head; impacts use HumanoidRootPart)
 for _,spec in {{"Head",Vector3.new(0,19,-11)},{"HumanoidRootPart",Vector3.new(0,12,0)}} do
  local p=Instance.new("Part"); p.Name=spec[1]; p.Anchored=true; p.CanCollide=false; p.CanQuery=false; p.CanTouch=false; p.Transparency=1; p.Size=Vector3.new(2,2,2)
  p.CFrame=model:GetPivot()*CFrame.new(spec[2]); p.Parent=model
 end
 model:SetAttribute("Hero","Vyrath")
 model.Parent=workspace
 L.model=model
 L.boss=Boss.new(model,clipsFor(),{
  paused=ctx.paused,
  targets=function()
   local t={}
   for key,st in ctx.states do
    if typeof(key)=="Instance" and key:IsA("Model") and ctx.alive(st) and not st.isDummy and not st.isPractice and not st.model:GetAttribute("Invisible") then -- players only for now; raid bots come with the party code
     table.insert(t,{model=st.model,root=st.root,hum=st.hum,s=st})
    end
   end
   return t
  end,
  damage=function(t,amount,kind,dir)
   local st=t.s; local tick=ctx.tick()
   if not ctx.alive(st) or tick<(st.invulnerable or 0) then return end
   -- a raised block halves it; a parry window turns it away
   if tick<(st.parryUntil or 0) then ctx.remote:FireAllClients("Hit",st.model,"Parry",0,L.model,kind,0,false,false,nil); return end
   local result="Hit"
   if st.block then amount=math.ceil(amount*0.5); result="Block" end
   st.hum:TakeDamage(amount); st.lastHurt=tick; st.lastCombat=tick
   if ctx.endInvisible and result~="Block" then ctx.endInvisible(st) end
   st.fury=math.min(ctx.fury.Max,st.fury+amount*ctx.fury.PerDamageTaken)
   if kind=="Sweep" and result~="Block" then
    st.stunned=math.max(st.stunned,tick+30); st.action=nil
    st.knock={dir=dir or Vector3.new(0,0,1),push=12,start=tick}
   end
   ctx.remote:FireAllClients("Hit",st.model,result,amount,L.model,kind,result=="Block" and 2 or 4,false,false,nil)
  end,
  onEvent=function(name,arg)
   if name=="Death" then
    for _,p in game:GetService("Players"):GetPlayers() do ctx.notify(p,"Vyrath is slain!") end
    task.delay(12,function() if L.model==model then L.clear() end end)
   elseif name=="WeakpointBreak" then
    for _,p in game:GetService("Players"):GetPlayers() do ctx.notify(p,"Weak point broken: "..tostring(arg).."! Vyrath staggers") end
   end
  end,
 })
 L.boss:moveTo(SPAWN,math.pi) -- facing +Z, toward the players' side
 return L.boss
end
function L.clear()
 if L.boss then L.boss:destroy() end
 if L.model then L.model:Destroy() end
 L.boss=nil; L.model=nil
end
function L.command(player,data)
 local ctx=L.ctx
 if data=="clear" or (data=="toggle" and L.model) then L.clear(); ctx.notify(player,"Vyrath dismissed"); return end
 if L.model then ctx.notify(player,"Vyrath is already here"); return end
 if L.start(ctx) then for _,p in game:GetService("Players"):GetPlayers() do ctx.notify(p,player.DisplayName.." summoned Vyrath, the Storm-Crowned Dragon") end end
end
function L.alive() return L.boss~=nil and L.boss.alive end
return L
