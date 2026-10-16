local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local CAS=game:GetService("ContextActionService")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local player=Players.LocalPlayer
local remote=RS:WaitForChild("HeroWars"):WaitForChild("Combat")
local Rules=require(RS.HeroWars.Rules)
local PowerFX=require(RS.HeroWars.PowerFX)
-- R30 (Peter: "preload the skins before the rest of the program so the user doesn't have to wait"):
-- the very first thing this client does is download every skin look (meshes and textures) the server
-- builds into Previews, each one as it appears, so the lobby and skin changes don't wait on downloads.
-- R46: counts what has really finished downloading (Preload.done / Preload.names), so the welcome
-- screen can wait for it.
local Preload={done=0,names={},paused=game:GetService("UserInputService").TouchEnabled} -- R66-ui7: phones start in Simple looks
task.spawn(function()
 local folder=RS.HeroWars:WaitForChild("Previews",30); if not folder then return end
 local CP=game:GetService("ContentProvider")
 local queue={}
 local list={}; for _,m in workspace:GetChildren() do if m:IsA("Model") and m:GetAttribute("Hero") then table.insert(list,m) end end
 pcall(function() CP:PreloadAsync(list) end) -- R66-ui: the fighters you can see first
 local function isDefault(m) local h,id=string.match(m.Name,"^(%w+)|(.+)$"); local sk=h and Rules.Skins[h]; return sk and sk.Order[1]==id end
 local function add(m) if isDefault(m) then table.insert(queue,1,m) else table.insert(queue,m) end end
 for _,m in folder:GetChildren() do add(m) end
 folder.ChildAdded:Connect(add)
 local t0=os.clock()
 while true do
  if Preload.paused or (game:GetService("UserInputService").TouchEnabled and os.clock()-t0<20 and queue[1] and not isDefault(queue[1])) then task.wait(0.5); continue end
  local m=table.remove(queue,1)
  if m then
   pcall(function() CP:PreloadAsync({m}) end)
   if not Preload.names[m.Name] then Preload.names[m.Name]=true; Preload.done+=1 end
  else task.wait(0.2) end
 end
end)
local poses={}
local function pose(model,name)
 if not model then return nil end
 local existing=poses[model]
 if existing and existing.name==name and os.clock()-existing.start<0.2 then return existing end
 -- v28: each hero's own version of the move (timing differs per hero).
 local p={name=name,start=os.clock(),hero=model:GetAttribute("Hero"),move=Rules.heroMove(model:GetAttribute("Hero"),name)}; poses[model]=p
 return p
end
local updateStealth, hiddenFromMe
local function heroMoveOf(model,name) return Rules.heroMove(model and model:GetAttribute("Hero"),name) end
local StarterGui=game:GetService("StarterGui")
-- Number keys belong to the action bar, not the Roblox tool backpack.
task.spawn(function()
 for _=1,10 do
  -- v43: Tab is our target key, so Roblox's player list (also on Tab) is turned off.
  if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack,false); StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList,false); StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat,false) end) then return end
  task.wait(0.5)
 end
end)
local gui=Instance.new("ScreenGui"); gui.Name="HeroWarsHUD"; gui.ResetOnSpawn=false; gui.Parent=player:WaitForChild("PlayerGui")
local function label(name,pos,size,text)
 local l=Instance.new("TextLabel"); l.Name=name; l.Position=pos; l.Size=size
 l.BackgroundColor3=Color3.fromRGB(15,20,31); l.BackgroundTransparency=0.15
 l.TextColor3=Color3.fromRGB(240,240,248); l.Font=Enum.Font.Gotham; l.TextSize=14
 l.TextWrapped=true; l.Text=text; l.Parent=gui; return l
end
-- Stats, character choice and keybinds live in a panel on the right edge,
-- clear of the Roblox chat window (top-left) and the action bar (bottom-centre).
-- R64 (Peter: "make the buttons bigger on the menu, classy fade, modern style"): the panel sits in a
-- see-through MenuShell (a CanvasGroup) that fades and slides in and out, is scaled up (1.2x on desktop,
-- 1.0x on phones, was 0.8x) and scrolls when the screen is short. Buttons get rounded glass styling below.
local panel=Instance.new("ScrollingFrame"); panel.Name="SidePanel"; panel.BackgroundTransparency=1
panel.BorderSizePixel=0; panel.ScrollBarThickness=3; panel.ScrollBarImageTransparency=0.5; panel.ScrollingDirection=Enum.ScrollingDirection.Y
panel.AutomaticCanvasSize=Enum.AutomaticSize.Y; panel.CanvasSize=UDim2.new(); panel.Size=UDim2.new(1,0,1,0)
do
 local shell=Instance.new("CanvasGroup"); shell.Name="MenuShell"; shell.BackgroundTransparency=1; shell.AnchorPoint=Vector2.new(1,0)
 -- R64b (Peter: "move the menu higher, the same level as the Roblox symbol"): MENU, the menu and the challenge
 -- pill live in their own ScreenGui that ignores Roblox's top-bar inset, so MENU sits in line with the Roblox button.
 local top=Instance.new("ScreenGui"); top.Name="HeroWarsTop"; top.ResetOnSpawn=false; top.IgnoreGuiInset=true; top.DisplayOrder=gui.DisplayOrder+1
 top.Parent=gui.Parent
 shell.Position=UDim2.new(1,-12,0,64); shell.Parent=top; panel.Parent=shell
 local scale=Instance.new("UIScale"); scale.Scale=UIS.TouchEnabled and 1 or 1.2; scale.Parent=shell
 local function fit()
  if shell:GetAttribute("TouchFit") then return end -- R66-ui: on phones the tile grid sizes the menu itself (end of file)
  -- R64c (Peter: "menu off screen on mobile"): size from this ScreenGui's own height, which follows the real
  -- screen (the camera's viewport size was stale on phones), leaving a margin under the menu.
  local h=top.AbsoluteSize.Y; if h<50 then h=workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.Y or 700 end
  if UIS.TouchEnabled then scale.Scale=h<500 and 0.8 or 1 end -- R64d: smaller on a phone held sideways
  shell.Size=UDim2.fromOffset(UIS.TouchEnabled and 280 or 268,math.max(120,math.floor(math.min(470,(h-64-16)/scale.Scale))))
 end
 fit(); top:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
 if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
 local pad=Instance.new("UIPadding"); pad.PaddingRight=UDim.new(0,6); pad.Parent=panel
 -- R64d (Peter's phone screenshot): on touch screens the menu gets a solid dark card behind it, so the power
 -- buttons underneath don't show through, and a little inner padding.
 if UIS.TouchEnabled then
  shell.BackgroundColor3=Color3.fromRGB(14,18,28); shell.BackgroundTransparency=0.04
  local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,14); c.Parent=shell
  pad.PaddingLeft=UDim.new(0,6); pad.PaddingTop=UDim.new(0,6); pad.PaddingBottom=UDim.new(0,6)
 end
end
do local panelList=Instance.new("UIListLayout"); panelList.Padding=UDim.new(0,8); panelList.SortOrder=Enum.SortOrder.LayoutOrder; panelList.Parent=panel end
local menuToggle=Instance.new("TextButton"); menuToggle.Name="MenuToggle"; menuToggle.AnchorPoint=Vector2.new(1,0)
menuToggle.Position=UDim2.new(1,-12,0,12); menuToggle.Size=UDim2.fromOffset(UIS.TouchEnabled and 124 or 140,44)
menuToggle.BackgroundColor3=Color3.fromRGB(15,20,31); menuToggle.BackgroundTransparency=0.25; menuToggle.TextColor3=Color3.fromRGB(240,240,248)
menuToggle.Font=Enum.Font.GothamBold; menuToggle.TextSize=18; menuToggle.Parent=panel.Parent.Parent
do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,12); c.Parent=menuToggle end
local function setMenuOpen(open,instant)
 local shell=panel.Parent; local TS=game:GetService("TweenService")
 menuToggle.Text=open and "MENU  \u{25B2}" or "MENU  \u{25BC}"
 shell:SetAttribute("Open",open)
 if instant then shell.Visible=open; shell.GroupTransparency=0; return end
 if open then
  shell.Visible=true; shell.GroupTransparency=1; shell.Position=UDim2.new(1,-12,0,52)
  TS:Create(shell,TweenInfo.new(0.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{GroupTransparency=0,Position=UDim2.new(1,-12,0,64)}):Play()
 else
  local t=TS:Create(shell,TweenInfo.new(0.18,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{GroupTransparency=1,Position=UDim2.new(1,-12,0,52)})
  t.Completed:Connect(function() if not shell:GetAttribute("Open") then shell.Visible=false end end); t:Play()
 end
end
setMenuOpen(not UIS.TouchEnabled,true) -- open on desktop, closed on phones and tablets
menuToggle.Activated:Connect(function() setMenuOpen(not panel.Parent:GetAttribute("Open")) end)
local hud=label("Stats",UDim2.new(),UDim2.fromOffset(260,94),"HEROWARS R66-ui8 • loading character…")
hud.Parent=panel; hud.LayoutOrder=1
if UIS.TouchEnabled then hud.Visible=false end -- R64d: the stats box is desktop only; phones show HP on the nameplate
-- R60 (Peter: "move all centre-screen writing to the side or bottom, or make it see-through and fading"):
-- messages sit low on the left edge, half see-through, and fade away a few seconds after they change.
local notice=label("Notice",UDim2.new(0,12,UIS.TouchEnabled and 0.48 or 0.62,0),UDim2.fromOffset(300,40),"Aim with the camera. Attack the dummy or another player.")
notice.BackgroundTransparency=0.6; notice.TextSize=13; notice.TextXAlignment=Enum.TextXAlignment.Left
do local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.Parent=notice end
do
 local token=0
 notice:GetPropertyChangedSignal("Text"):Connect(function()
  token+=1; local mine=token
  notice.TextTransparency=0; notice.BackgroundTransparency=0.6; notice.Visible=notice.Text~=""
  task.delay(4,function()
   if token~=mine then return end
   game:GetService("TweenService"):Create(notice,TweenInfo.new(1.2),{TextTransparency=1,BackgroundTransparency=1}):Play()
  end)
 end)
 task.delay(6,function() if notice.Text~="" then game:GetService("TweenService"):Create(notice,TweenInfo.new(1.2),{TextTransparency=1,BackgroundTransparency=1}):Play() end end)
end
local debugLabel=label("Debug",UDim2.new(),UDim2.fromOffset(280,144),""); debugLabel.Visible=false
debugLabel.Parent=panel; debugLabel.LayoutOrder=4
do local reticle=label("Aim",UDim2.new(0.5,-8,0.5,-8),UDim2.fromOffset(16,16),"+"); reticle.BackgroundTransparency=1; reticle.TextTransparency=0.45 end
local help=label("Controls",UDim2.new(0.5,-230,1,-112),UDim2.fromOffset(460,36),"Abilities on the bar below (keys or click) • WASD move • Space jump / rise • X descend\nClick a fighter or Tab to target • K keybindings • H hitboxes • Right-drag camera")
help.TextSize=13
if UIS.TouchEnabled then help.Visible=false end
local function button(name,parent,pos,size,text,color)
 local b=Instance.new("TextButton"); b.Name=name; b.Position=pos; b.Size=size; b.Text=text
 b.TextColor3=Color3.new(1,1,1); b.BackgroundColor3=color or Color3.fromRGB(45,55,75)
 b.Font=Enum.Font.GothamBold; b.TextSize=14; b.AutoButtonColor=true; b.Parent=parent
 return b
end
-- Hero / villain choice sits bottom-centre, just above the controls line and action bar,
-- where neither the chat window (top-left) nor the player list (top-right) can reach it.
local heroRow=Instance.new("Frame"); heroRow.Name="CharacterChoice"; heroRow.BackgroundTransparency=1
-- R41 (Peter): nothing clickable near the action bar or the middle of the screen, so Lobby and Pause
-- sit at the top of the right-hand side panel.
heroRow.Size=UDim2.fromOffset(260,40); heroRow.LayoutOrder=0; heroRow.Parent=panel
-- v25: four heroes.
local HERO_BUTTON_COLORS={Solarion=Color3.fromRGB(33,81,143),Wraithstep=Color3.fromRGB(93,55,134),
 Tempest=Color3.fromRGB(40,110,140),Bulwark=Color3.fromRGB(100,108,122),Valkyra=Color3.fromRGB(47,79,168),DreadKnight=Color3.fromRGB(40,46,58)} -- V59: Valkyra, V60: Dread Knight
-- R30 (Peter): the four hero buttons are gone; pick a hero in the Lobby (PLAY AS). This row now holds
-- only the Lobby and Pause buttons.
local debugOn=false; local flyUp=false; local flyDown=false; local flying=false
local function flash(model,color,duration)
 if not model or not model.Parent then return end
 local h=Instance.new("Highlight"); h.FillColor=color; h.FillTransparency=0.65; h.OutlineTransparency=1
 h.Adornee=model; h.Parent=model; Debris:AddItem(h,duration or 0.12)
end

-- Ability feedback: asset-free neon parts, rings, particles and floating numbers.
-- Everything here is client-only presentation and never affects hits or damage.
local TweenService=game:GetService("TweenService")
local fxFolder=Instance.new("Folder"); fxFolder.Name="HeroWarsFx"; fxFolder.Parent=workspace
-- Effect colour comes from the fighter's skin (and that skin's per-move colour, if it sets one).
local function skinOf(model)
 return model and Rules.skin(model:GetAttribute("Hero") or "",model:GetAttribute("Skin"))
end
local function heroAccent(model,moveName)
 local skin=skinOf(model)
 if not skin then return Color3.fromRGB(255,200,90) end
 local m=moveName and skin.Moves and skin.Moves[moveName]
 return Color3.new(table.unpack(m and m.Color or skin.Accent))
end
local function fxPart(shape,size,cf,color,transparency,material)
 local p=Instance.new("Part"); p.Name="Fx"; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
 p.CastShadow=false; p.Shape=shape; p.Size=size; p.CFrame=cf; p.Color=color
 p.Material=material or Enum.Material.Neon; p.Transparency=transparency or 0.15
 -- R66-ui8: phones draw at most 90 effect parts at once; extra ones still run (tweens, timers) but are never drawn,
 -- so two big powers landing together (Bulwark quake ~60-85 parts + Solar Hammer) can't spike the frame.
 if UIS.TouchEnabled and #fxFolder:GetChildren()>=90 then return p end
 p.Parent=fxFolder
 return p
end
local function fadeOut(p,duration,goal)
 goal=goal or {}; goal.Transparency=1
 TweenService:Create(p,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),goal):Play()
 Debris:AddItem(p,duration+0.1)
end
local function burst(position,color,size,duration)
 local p=fxPart(Enum.PartType.Ball,Vector3.one*0.4,CFrame.new(position),color,0.1)
 fadeOut(p,duration or 0.25,{Size=Vector3.one*(size or 4)})
end
-- Flat expanding ring (a cylinder's axis is its X, rotated to vertical).
local function ring(position,color,size,duration)
 local p=fxPart(Enum.PartType.Cylinder,Vector3.new(0.2,1,1),CFrame.new(position)*CFrame.Angles(0,0,math.pi/2),color,0.2)
 fadeOut(p,duration or 0.35,{Size=Vector3.new(0.2,size or 10,size or 10)})
end
local function beamBetween(a,b,color,thickness,duration)
 local length=(b-a).Magnitude; if length<0.05 then return end
 local p=fxPart(Enum.PartType.Cylinder,Vector3.new(length,thickness,thickness),CFrame.lookAt((a+b)/2,b)*CFrame.Angles(0,math.pi/2,0),color,0.05)
 fadeOut(p,duration or 0.25,{Size=Vector3.new(length,thickness*0.2,thickness*0.2)})
end
local followers={}
local solarDomes={} -- R41: Solarion's live shield dome, popped early by ShieldBreak
RunService.RenderStepped:Connect(function()
 for i=#followers,1,-1 do
  local f=followers[i]
  if os.clock()>f.expires or not f.part.Parent or not f.target.Parent then table.remove(followers,i)
  else f.part.CFrame=f.target.CFrame end
 end
end)
-- A glowing orb that grows on a body part during an attack's startup.
local function charge(model,partName,color,seconds,size)
 local target=model:FindFirstChild(partName); if not target or seconds<=0 then return end
 local p=fxPart(Enum.PartType.Ball,Vector3.one*0.3,target.CFrame,color,0.25)
 table.insert(followers,{part=p,target=target,expires=os.clock()+seconds})
 TweenService:Create(p,TweenInfo.new(seconds),{Size=Vector3.one*(size or 1.5)}):Play()
 Debris:AddItem(p,seconds)
end
local function afterimages(root,color,count)
 for i=0,count-1 do
  task.delay(i*0.04,function()
   if not root.Parent then return end
   fadeOut(fxPart(Enum.PartType.Block,Vector3.new(2,4.5,1),root.CFrame,color,0.55),0.25)
  end)
 end
end
local function groundBelow(model,root)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={model,fxFolder}
 local ray=workspace:Raycast(root.Position,Vector3.new(0,-14,0),params)
 return ray and ray.Position or root.Position-Vector3.new(0,3,0)
end
local function popText(model,text,color,size)
 local head=model and model:FindFirstChild("Head"); if not head then return end
 local bb=Instance.new("BillboardGui"); bb.Name="FxText"; bb.Size=UDim2.fromOffset(180,40)
 bb.StudsOffset=Vector3.new(math.random(-10,10)/10,2.2,0); bb.AlwaysOnTop=true; bb.Adornee=head
 bb.Parent=player:WaitForChild("PlayerGui")
 local t=Instance.new("TextLabel"); t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.Text=text
 t.Font=Enum.Font.GothamBlack; t.TextSize=size or 26; t.TextColor3=color; t.TextStrokeTransparency=0.3; t.Parent=bb
 TweenService:Create(bb,TweenInfo.new(0.8),{StudsOffset=bb.StudsOffset+Vector3.new(0,2.5,0)}):Play()
 TweenService:Create(t,TweenInfo.new(0.8,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{TextTransparency=1,TextStrokeTransparency=1}):Play()
 Debris:AddItem(bb,0.85)
end
local hurtFlash=Instance.new("Frame"); hurtFlash.Name="HurtFlash"; hurtFlash.Size=UDim2.fromScale(1,1)
hurtFlash.BackgroundColor3=Color3.fromRGB(200,30,30); hurtFlash.BackgroundTransparency=1; hurtFlash.BorderSizePixel=0
hurtFlash.Active=false; hurtFlash.ZIndex=0; hurtFlash.Parent=gui
-- Built-in Roblox sparkle texture (ships with every client, no upload needed).
local FX_TEXTURE="rbxasset://textures/particles/sparkles_main.dds"
local function anchorPoint(cf)
 local p=Instance.new("Part"); p.Name="FxAnchor"; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
 p.Transparency=1; p.Size=Vector3.one*0.2; p.CFrame=cf; p.Parent=fxFolder
 local a=Instance.new("Attachment"); a.Parent=p
 return p,a
end
local function texturedBeam(a0,a1,color,width,speed,length)
 local b=Instance.new("Beam"); b.Attachment0=a0; b.Attachment1=a1; b.Color=ColorSequence.new(color)
 b.LightEmission=1; b.LightInfluence=0; b.FaceCamera=true; b.Segments=1
 b.Width0=width; b.Width1=width*0.8; b.Texture=FX_TEXTURE; b.TextureMode=Enum.TextureMode.Wrap
 b.TextureLength=length; b.TextureSpeed=speed; b.Transparency=NumberSequence.new(0.05)
 b.Parent=a0.Parent
 return b
end
local function emitter(parent,color,props)
 local e=Instance.new("ParticleEmitter"); e.Texture=FX_TEXTURE; e.Color=ColorSequence.new(color)
 e.LightEmission=1; e.LightInfluence=0
 for k,v in props do e[k]=v end
 e.Parent=parent; return e
end
-- Shadow bats (v23): Wraithstep's Grapple sends two bat demons out of a shroud of shadow. They circle him
-- during the wind-up, fly to the target, and on a hit grab it and drag it down. Built from plain parts.
local SMOKE_TEXTURE="rbxasset://textures/particles/smoke_main.dds"
local bats={}            -- live bats being flown each frame
local grappleBats={}     -- attacker model -> its two bats, until they latch or give up
local function shadowSmoke(parent,rate)
 local e=Instance.new("ParticleEmitter"); e.Texture=SMOKE_TEXTURE; e.Color=ColorSequence.new(Color3.fromRGB(28,14,36))
 e.LightInfluence=0; e.Rate=rate; e.Lifetime=NumberRange.new(0.35,0.7); e.Speed=NumberRange.new(0.5,2)
 e.SpreadAngle=Vector2.new(180,180); e.Rotation=NumberRange.new(0,360); e.RotSpeed=NumberRange.new(-90,90)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.9),NumberSequenceKeypoint.new(1,2.2)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.35),NumberSequenceKeypoint.new(1,1)})
 e.Parent=parent; return e
end
local function makeBat(accent)
 local dark=Color3.fromRGB(24,14,30)
 local b={t=0,parts={}}
 b.body=fxPart(Enum.PartType.Ball,Vector3.new(0.75,0.8,1),CFrame.new(),dark,0,Enum.Material.SmoothPlastic)
 b.head=fxPart(Enum.PartType.Ball,Vector3.one*0.55,CFrame.new(),dark,0,Enum.Material.SmoothPlastic)
 b.wings={fxPart(Enum.PartType.Block,Vector3.new(1.8,0.07,0.95),CFrame.new(),Color3.fromRGB(40,20,48),0,Enum.Material.SmoothPlastic),
  fxPart(Enum.PartType.Block,Vector3.new(1.8,0.07,0.95),CFrame.new(),Color3.fromRGB(40,20,48),0,Enum.Material.SmoothPlastic)}
 b.ears={fxPart(Enum.PartType.Block,Vector3.new(0.12,0.35,0.12),CFrame.new(),dark,0,Enum.Material.SmoothPlastic),
  fxPart(Enum.PartType.Block,Vector3.new(0.12,0.35,0.12),CFrame.new(),dark,0,Enum.Material.SmoothPlastic)}
 b.eyes={fxPart(Enum.PartType.Ball,Vector3.one*0.13,CFrame.new(),Color3.fromRGB(255,40,60),0),
  fxPart(Enum.PartType.Ball,Vector3.one*0.13,CFrame.new(),Color3.fromRGB(255,40,60),0)}
 for _,list in {{b.body,b.head},b.wings,b.ears,b.eyes} do for _,p in list do table.insert(b.parts,p) end end
 shadowSmoke(b.body,30)
 local light=Instance.new("PointLight"); light.Color=accent; light.Range=6; light.Brightness=1; light.Parent=b.body
 return b
end
local function poseBat(b,pos,look)
 if (look.Magnitude<0.01) then look=Vector3.new(0,0,-1) end
 local cf=CFrame.lookAt(pos,pos+look)
 local flap=math.sin(b.t*24)*0.8
 b.body.CFrame=cf; b.head.CFrame=cf*CFrame.new(0,0.2,-0.55)
 for i,side in {-1,1} do
  b.wings[i].CFrame=cf*CFrame.new(side*0.3,0.15,0)*CFrame.Angles(0,0,side*flap)*CFrame.new(side*0.9,0,0)
  b.ears[i].CFrame=cf*CFrame.new(side*0.15,0.55,-0.55)
  b.eyes[i].CFrame=cf*CFrame.new(side*0.12,0.25,-0.8)
 end
end
local function poofBat(b)
 local where=b.body.Position
 local puff=Instance.new("Attachment"); local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,CFrame.new(where),Color3.new(),1)
 puff.Parent=holder; shadowSmoke(puff,0):Emit(18); Debris:AddItem(holder,1)
 for _,p in b.parts do fadeOut(p,0.15) end
 b.dead=true
end
-- mode: orbit (around a root), fly (from -> to over dur), latch (on a target root, dragging down).
RunService.RenderStepped:Connect(function(dt)
 for i=#bats,1,-1 do
  local b=bats[i]
  if b.dead then table.remove(bats,i); continue end
  b.t+=dt; b.age=(b.age or 0)+dt
  local m=b.mode
  if m.kind=="orbit" then
   if not m.root.Parent then poofBat(b); continue end
   local a=b.t*5+b.phase
   local pos=m.root.Position+Vector3.new(math.cos(a)*2.6,1.8+math.sin(b.t*7)*0.3,math.sin(a)*2.6)
   poseBat(b,pos,Vector3.new(-math.sin(a),0,math.cos(a)))
  elseif m.kind=="fly" then
   local k=math.min(1,(b.age-m.at)/m.dur)
   local pos=m.from:Lerp(m.to,k)+Vector3.new(0,math.sin(k*math.pi)*1.5,0)+m.side*math.sin(k*math.pi)*1.5
   poseBat(b,pos,m.to-m.from)
   if k>=1 then
    if m.done then local d=m.done; m.done=nil; m.hold=true; d(b)
    elseif not m.hold then poofBat(b) end
   end
  elseif m.kind=="latch" then
   if not m.root.Parent or b.age-m.at>m.dur then poofBat(b); continue end
   local pos=m.root.Position+m.offset+Vector3.new(0,math.sin(b.t*10)*0.15,0)
   poseBat(b,pos,Vector3.new(0,-1,0)+m.offset*0.3)
  end
 end
end)
local function setMode(b,mode) mode.at=b.age or 0; b.mode=mode end
-- Skin reactions: what a skin does while one of its listed attacks fires (Rules.Skins[hero][id].Moves).
-- Pure presentation; timing follows the move's startup + active frames.
local BODY={"UpperTorso","LowerTorso","LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm",
 "LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}
-- v42 character powers (Peter: "VFX ... also to their attacks powers so they are unique"). A skin move
-- reaction Power="Plasma"|"Shadow"|"Storm"|"Holy" plays that style's own effect: a build-up on the striking
-- hand through the wind-up, then a signature burst on the hit frame. Presentation only.
local POW={}
function POW.bolt(a,b,color,thick,dur)
 local n=math.max(3,math.floor((b-a).Magnitude/2.5)); local last=a
 for i=1,n do
  local p=i==n and b or a:Lerp(b,i/n)+Vector3.new(math.random(-10,10),math.random(-10,10),math.random(-10,10))/14
  beamBetween(last,p,color,thick,dur); last=p
 end
end
function POW.shards(at,dir,color,count,speed)
 for i=1,count do
  local p=fxPart(Enum.PartType.Block,Vector3.new(0.25,0.25,0.6),CFrame.new(at),color,0.05)
  local v=(dir+Vector3.new(math.random(-10,10),math.random(-6,10),math.random(-10,10))/12).Unit*(speed or 6)
  p.CFrame=CFrame.lookAt(at,at+v)
  fadeOut(p,0.3,{CFrame=CFrame.lookAt(at+v,at+v*2),Size=Vector3.new(0.05,0.05,1.2)})
 end
end
function POW.emit(part,color,texture,rate,life,speed,size,dur,up)
 local e=Instance.new("ParticleEmitter"); e.Texture=texture; e.Color=ColorSequence.new(color); e.Rate=rate
 e.Lifetime=NumberRange.new(life*0.6,life); e.Speed=NumberRange.new(speed*0.5,speed); e.SpreadAngle=Vector2.new(180,180)
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.2),NumberSequenceKeypoint.new(1,1)})
 e.LightEmission=1; e.Acceleration=Vector3.new(0,up or 0,0); e.Parent=part
 task.delay(dur,function() e.Enabled=false end); Debris:AddItem(e,dur+life)
 return e
end
function POW.light(part,color,range,dur)
 local l=Instance.new("PointLight"); l.Color=color; l.Range=range; l.Brightness=2.5; l.Shadows=false; l.Parent=part
 Debris:AddItem(l,dur)
end
local SPARK="rbxasset://textures/particles/sparkles_main.dds"
local SMOKE="rbxasset://textures/particles/smoke_main.dds"
POW.STYLE={
 -- Trooper: blue plasma gathers in the fist, then a gold-and-blue shard blast.
 Plasma=function(model,hand,root,lead,dur)
  local blue,gold=Color3.fromRGB(70,150,255),Color3.fromRGB(255,190,60)
  charge(model,hand.Name,blue,lead,1.6); POW.light(hand,blue,10,dur)
  POW.emit(hand,gold,SPARK,60,0.25,4,0.35,lead)
  task.delay(lead,function()
   if not hand.Parent then return end
   local at=hand.Position; burst(at,blue,6,0.25); burst(at,gold,3.5,0.18)
   POW.shards(at,root.CFrame.LookVector,gold,8,7); ring(at,blue,7,0.3)
  end)
 end,
 -- Shinobi: violet smoke pours off him and he flickers; the blow lands as a crossed shadow slash.
 Shadow=function(model,hand,root,lead,dur)
  local violet=Color3.fromRGB(140,67,237)
  local torso=model:FindFirstChild("UpperTorso")
  if torso then POW.emit(torso,Color3.fromRGB(40,20,70),SMOKE,30,0.6,2,1.4,dur,2) end
  afterimages(root,violet,3)
  task.delay(lead,function()
   if not hand.Parent then return end
   local at=hand.Position+root.CFrame.LookVector*1.5
   for _,z in {0.8,-0.8} do
    local p=fxPart(Enum.PartType.Block,Vector3.new(0.15,4.5,0.5),CFrame.lookAt(at,at+root.CFrame.LookVector)*CFrame.Angles(0,0,z),violet,0.05)
    fadeOut(p,0.28,{Size=Vector3.new(0.02,6,0.1)})
   end
   burst(at,Color3.fromRGB(30,10,50),5,0.3)
  end)
 end,
 -- Valkyrie: gold lightning crackles over her, then a bolt drops from the sky onto the strike.
 Storm=function(model,hand,root,lead,dur)
  local gold,white=Color3.fromRGB(255,215,90),Color3.fromRGB(255,250,225)
  POW.light(hand,gold,12,dur)
  for i=0,math.floor(dur/0.08) do
   task.delay(i*0.08,function()
    if not root.Parent then return end
    local c=root.Position+Vector3.new(0,0.5,0)
    POW.bolt(c+Vector3.new(math.random(-15,15),math.random(-10,20),math.random(-15,15))/10,hand.Position,gold,0.12,0.08)
   end)
  end
  task.delay(lead,function()
   if not hand.Parent then return end
   local at=hand.Position+root.CFrame.LookVector*1.5
   POW.bolt(at+Vector3.new(0,16,0),at,white,0.35,0.2); POW.bolt(at+Vector3.new(2,16,1),at,gold,0.2,0.2)
   burst(at,white,5,0.2); ring(at-Vector3.new(0,1.5,0),gold,9,0.35)
  end)
 end,
 -- Paladin: a gold rune ring under his feet and rising embers; the hit raises a pillar of light.
 Holy=function(model,hand,root,lead,dur)
  local gold=Color3.fromRGB(255,205,110)
  local feet=root.Position-Vector3.new(0,2.9,0)
  ring(feet,gold,9,dur); ring(feet,Color3.fromRGB(255,240,200),5,dur*0.8)
  local torso=model:FindFirstChild("UpperTorso")
  if torso then POW.emit(torso,gold,SPARK,25,0.9,2,0.3,dur,6) end
  POW.light(root,gold,14,dur)
  task.delay(lead,function()
   if not hand.Parent then return end
   local at=hand.Position+root.CFrame.LookVector*2
   local pillar=fxPart(Enum.PartType.Cylinder,Vector3.new(14,2.4,2.4),CFrame.new(at+Vector3.new(0,5,0))*CFrame.Angles(0,0,math.pi/2),gold,0.25)
   fadeOut(pillar,0.45,{Size=Vector3.new(16,0.2,0.2)})
   burst(at,Color3.fromRGB(255,250,230),6,0.3); ring(at-Vector3.new(0,1.5,0),gold,10,0.4)
  end)
 end,
}
function POW.play(model,style,moveName,dur)
 local f=POW.STYLE[style]; local root=model:FindFirstChild("HumanoidRootPart"); if not f or not root then return end
 local move=Rules.Moves[moveName]
 local kick=moveName=="Light3" or string.find(moveName,"Kick")~=nil
 local hand=model:FindFirstChild(kick and "RightFoot" or "RightHand") or root
 f(model,hand,root,move and move.Startup/60 or 0.15,dur)
end
-- v43 VFX assets (Peter: "more assets vfx effect"). Twelve textures made for HeroWars
-- (HeroWars-assets/vfx: Burst, Fire, Glow, Hex, Lightning, Rune, Shockwave, Slash, Smoke, Spark, Star, Wisp)
-- ship in HeroWars_Assets.glb as small quads named VFX_<Name>; Import 3D uploads them and the game reads each
-- quad's texture. Until then Roblox's built-in particle textures stand in. Used on every swing, hit,
-- block, skill cast, dash and knockdown. Presentation only.
local VFX={tex={},
 -- v44: texture IDs from Peter's 2026-10-09 import, so no import is needed.
 ID={Burst="75550696289537",Fire="99868293957169",Glow="93470077369888",Hex="120975739304980",Lightning="89969993020032",Rune="125564999921992",Shockwave="117433114677176",Slash="104383399639392",Smoke="98529927784986",Spark="138931828539905",Star="74944357140229",Wisp="95941693149804"},
 BUILTIN={Smoke="rbxasset://textures/particles/smoke_main.dds",Fire="rbxasset://textures/particles/fire_main.dds",
  Spark="rbxasset://textures/particles/fire_sparks_main.dds",Star="rbxasset://textures/particles/sparkles_main.dds",
  Glow="rbxasset://textures/particles/sparkles_main.dds",Burst="rbxasset://textures/particles/explosion01_core_texture.dds",
  Shockwave="rbxasset://textures/particles/explosion01_shockwave_texture.dds",Wisp="rbxasset://textures/particles/smoke_main.dds"}}
function VFX.find(name)
 local want="VFX_"..name
 for _,root in {RS:FindFirstChild("HeroWars"),workspace} do
  local m=root and root:FindFirstChild(want,true)
  if m and m:IsA("MeshPart") then
   if m.TextureID~="" then return m.TextureID end
   local sa=m:FindFirstChildOfClass("SurfaceAppearance")
   local ok,id=pcall(function() return sa and sa.ColorMap end)
   if ok and type(id)=="string" and id~="" then return id end
  end
 end
 return nil
end
-- texture, and whether it's one of ours (our Smoke and Fire are 4x4 flipbooks)
function VFX.get(name)
 local t=VFX.tex[name]
 if t==nil or (not t.own and os.clock()-t.at>5) then
  local id=VFX.find(name) or (VFX.ID[name] and "rbxassetid://"..VFX.ID[name])
  t={id=id or VFX.BUILTIN[name] or false,own=id~=nil,at=os.clock()}; VFX.tex[name]=t
 end
 return t.id or nil,t.own
end
-- One shot of particles at a point. o: count, size {from,to}, life, speed, spread, color, light, rot,
-- rotSpeed, flat (lies on the ground), dir (emission direction), accel, transparency start.
function VFX.shot(name,pos,o)
 local tex,own=VFX.get(name); if not tex then return end
 local p=Instance.new("Part"); p.Name="Vfx"; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
 p.Transparency=1; p.Size=Vector3.one*0.1; p.CFrame=o.cf or CFrame.new(pos); p.Parent=fxFolder
 local e=Instance.new("ParticleEmitter"); e.Texture=tex; e.Enabled=false
 e.Color=ColorSequence.new(o.color or Color3.new(1,1,1)); e.LightEmission=o.light or 1; e.LightInfluence=0
 local s=o.size or {1,2}
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s[1]),NumberSequenceKeypoint.new(1,s[2])})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,o.alpha or 0),NumberSequenceKeypoint.new(0.6,math.max(o.alpha or 0,0.3)),NumberSequenceKeypoint.new(1,1)})
 local life=o.life or 0.3; e.Lifetime=NumberRange.new(life*0.8,life)
 e.Speed=NumberRange.new((o.speed or 0)*0.6,o.speed or 0); e.SpreadAngle=Vector2.new(o.spread or 0,o.spread or 0)
 e.Rotation=NumberRange.new(o.rot or 0,(o.rot or 0)+(o.rotJitter or 0)); e.RotSpeed=NumberRange.new(o.rotSpeed or 0)
 e.Acceleration=o.accel or Vector3.zero; e.Drag=o.drag or 0
 if o.flat then e.Orientation=Enum.ParticleOrientation.VelocityPerpendicular; e.EmissionDirection=Enum.NormalId.Top; e.Speed=NumberRange.new(0.01)
 elseif o.streak then e.Orientation=Enum.ParticleOrientation.VelocityParallel end
 if o.dir then e.EmissionDirection=o.dir end
 if own and (name=="Smoke" or name=="Fire") then e.FlipbookLayout=Enum.ParticleFlipbookLayout.Grid4x4; e.FlipbookMode=Enum.ParticleFlipbookMode.OneShot end
 e.ZOffset=o.z or 0.5; e.Parent=p
 e:Emit(o.count or 1)
 Debris:AddItem(p,life+0.2)
end
function VFX.contact(target,attacker)
 local troot=target and target:FindFirstChild("HumanoidRootPart"); local root=attacker and attacker:FindFirstChild("HumanoidRootPart")
 if not troot then return nil end
 local toward=root and Vector3.new(root.Position.X-troot.Position.X,0,root.Position.Z-troot.Position.Z) or Vector3.zero
 toward=toward.Magnitude>0.1 and toward.Unit or Vector3.zero
 return troot.Position+toward*1.1+Vector3.new(0,0.8,0),toward
end
-- A landed blow: hot core, starburst, a shockwave and sparks thrown back; heavier hits add smoke.
-- A blocked blow shows a hex shield flash instead.
function VFX.impact(target,result,damage,attacker,moveName)
 if PowerFX then PowerFX.impact(target,attacker,moveName,result); return end
 local at,toward=VFX.contact(target,attacker); if not at then return end
 local accent=heroAccent(attacker,moveName); local white=Color3.fromRGB(255,250,235)
 if result=="Block" then
  VFX.shot("Hex",at,{size={2.5,5},life=0.25,color=Color3.fromRGB(150,210,255),alpha=0.2})
  VFX.shot("Spark",at,{count=6,size={0.6,0},life=0.2,speed=18,spread=60,streak=true,color=white,dir=Enum.NormalId.Top})
  return
 end
 local heavy=(damage or 0)>=12
 VFX.shot("Burst",at,{size={heavy and 4 or 2.8,heavy and 8 or 5},life=0.16,color=white,rotJitter=360})
 VFX.shot("Star",at,{size={heavy and 6 or 4,0},life=0.12,color=accent,rotJitter=90})
 VFX.shot("Shockwave",at,{size={1,heavy and 10 or 6},life=0.25,color=accent,alpha=0.1})
 VFX.shot("Spark",at,{count=heavy and 16 or 9,size={heavy and 0.9 or 0.6,0},life=0.25,speed=heavy and 32 or 22,spread=180,streak=true,color=accent:Lerp(white,0.5),drag=4})
 if heavy then
  VFX.shot("Smoke",at-Vector3.new(0,0.5,0),{count=3,size={2,5},life=0.7,speed=4,spread=180,color=Color3.fromRGB(90,90,100),light=0,alpha=0.35,rotJitter=360})
 end
end
VFX.SLASH_ROT={Light1=-20,Light2=200,Light3=80,Heavy=-35}
-- A swing: a slash arc in front of the striker on its hit frame. Skills, the defensive and throws draw
-- a spinning rune circle under the caster through the wind-up instead.
function VFX.swing(model,moveName)
 if PowerFX then return end -- dedicated timed power effects in playMove
 local root=model and model:FindFirstChild("HumanoidRootPart"); if not root then return end
 local hero=model:GetAttribute("Hero") or ""
 local move=Rules.heroMove and Rules.heroMove(hero,moveName) or Rules.Moves[moveName]
 local lead=move and move.Startup/60 or 0.12
 local accent=heroAccent(model,moveName)
 local skills=Rules.HeroSkills[hero] or {}
 local isSkill=moveName=="Defensive" or moveName==skills.Skill1 or moveName==skills.Skill2 or moveName==skills.Skill3 or moveName=="ChargeLeap" or moveName=="Super"
 if isSkill then
  local feet=root.Position-Vector3.new(0,2.9,0)
  VFX.shot("Rune",feet,{flat=true,size={2,10},life=lead+0.45,color=accent,rotSpeed=120,alpha=0.15,z=0})
  VFX.shot("Glow",root.Position,{size={3,7},life=lead+0.2,color=accent,alpha=0.5})
  return
 end
 local rot=VFX.SLASH_ROT[moveName]; if not rot then return end
 task.delay(lead,function()
  if not root.Parent then return end
  local at=root.Position+root.CFrame.LookVector*2.6+Vector3.new(0,0.4,0)
  local big=moveName=="Heavy"
  VFX.shot("Slash",at,{size={big and 7 or 5,big and 9 or 6},life=big and 0.2 or 0.14,color=accent:Lerp(Color3.new(1,1,1),0.35),rot=rot})
 end)
end
-- Dash: dust puffs at the feet (shadow wisps for Wraithstep).
function VFX.dash(model,root)
 local feet=root.Position-Vector3.new(0,2.6,0)
 local shadow=(model:GetAttribute("Hero") or "")=="Wraithstep"
 VFX.shot(shadow and "Wisp" or "Smoke",feet,{count=4,size={1.5,4},life=0.5,speed=6,spread=70,dir=Enum.NormalId.Top,
  color=shadow and Color3.fromRGB(70,35,120) or Color3.fromRGB(170,160,145),light=shadow and 0.3 or 0,alpha=0.35,rotJitter=360})
end
-- Knockdown: a dust ring and a flat shockwave where the body lands.
function VFX.slam(model)
 local root=model and model:FindFirstChild("HumanoidRootPart"); if not root then return end
 local feet=root.Position-Vector3.new(0,2.6,0)
 VFX.shot("Shockwave",feet,{flat=true,size={2,14},life=0.35,color=Color3.fromRGB(255,235,200),alpha=0.2,z=0})
 VFX.shot("Smoke",feet,{count=8,size={2,5},life=0.8,speed=10,spread=90,dir=Enum.NormalId.Top,color=Color3.fromRGB(150,140,125),light=0,alpha=0.4,drag=3,rotJitter=360})
end
local function skinReact(model,moveName)
 if moveName=="Defensive" then PowerFX.defensive(model) end
 if PowerFX then return end -- prevent old skin light pillars layering over new effects
 local skin=skinOf(model); local r=skin and skin.Moves and skin.Moves[moveName]
 if not r or not model.Parent then return end
 local move=Rules.Moves[moveName]
 local dur=move and (move.Startup+move.Active)/60+0.25 or 0.8
 local color=heroAccent(model,moveName)
 if r.Glow then
  local h=Instance.new("Highlight"); h.FillColor=color; h.FillTransparency=0.55
  h.OutlineColor=color; h.OutlineTransparency=0; h.Adornee=model; h.Parent=model; Debris:AddItem(h,dur)
 end
 if r.Tint then
  local tint=Color3.new(table.unpack(r.Tint)); local saved={}
  for _,n in BODY do local p=model:FindFirstChild(n); if p then saved[p]=p.Color; p.Color=tint end end
  -- v16: with the smooth kit meshes the body is hidden, so tint the shells that stand in for it.
  for _,p in model:GetChildren() do
   if p:GetAttribute("KitPiece") and string.find(p.Name,"Shell") then saved[p]=p.Color; p.Color=tint end
  end
  task.delay(dur,function() for p,c in saved do if p.Parent and p.Color==tint then p.Color=c end end end)
 end
 if r.Trail then
  for _,n in {"RightHand","LeftHand","RightFoot","LeftFoot"} do
   local part=model:FindFirstChild(n)
   if part then
    local a0=Instance.new("Attachment"); a0.Position=Vector3.new(0,0.3,0); a0.Parent=part
    local a1=Instance.new("Attachment"); a1.Position=Vector3.new(0,-0.3,0); a1.Parent=part
    local t=Instance.new("Trail"); t.Attachment0=a0; t.Attachment1=a1; t.Color=ColorSequence.new(color)
    t.Lifetime=0.25; t.LightEmission=1; t.FaceCamera=true; t.Transparency=NumberSequence.new(0.2,1); t.Parent=part
    Debris:AddItem(t,dur+0.3); Debris:AddItem(a0,dur+0.3); Debris:AddItem(a1,dur+0.3)
   end
  end
 end
 if r.Power then POW.play(model,r.Power,moveName,dur) end
 local torso=model:FindFirstChild("UpperTorso")
 if r.Aura and torso then
  local fx
  if r.Aura=="Fire" then fx=Instance.new("Fire"); fx.Color=color; fx.SecondaryColor=Color3.new(1,0.9,0.4); fx.Size=4; fx.Heat=6
  elseif r.Aura=="Sparkles" then fx=Instance.new("Sparkles"); fx.SparkleColor=color
  elseif r.Aura=="Smoke" then fx=Instance.new("Smoke"); fx.Color=color; fx.Opacity=0.2; fx.RiseVelocity=2; fx.Size=2 end
  if fx then fx.Parent=torso; Debris:AddItem(fx,dur) end
 end
end
-- Camera shake for hits you deal or take; decays over its duration.
local shakeS={until_=0,amp=0,dur=0.1}
local function shake(amp,duration)
 local now=os.clock()
 local current=now<shakeS.until_ and shakeS.amp*(shakeS.until_-now)/shakeS.dur or 0
 if amp>=current then shakeS.amp=amp; shakeS.dur=duration; shakeS.until_=now+duration end
end
RunService:BindToRenderStep("HeroWarsShake",Enum.RenderPriority.Camera.Value+1,function()
 local left=shakeS.until_-os.clock(); if left<=0 then return end
 local k=shakeS.amp*left/shakeS.dur; local cam=workspace.CurrentCamera
 cam.CFrame=cam.CFrame*CFrame.new((math.random()-0.5)*k,(math.random()-0.5)*k,0)*CFrame.Angles(0,0,(math.random()-0.5)*k*0.04)
end)
-- Freeze a fighter's pose for the hit-stop.
local function holdPose(model,seconds)
 local p=model and poses[model]; if not p or seconds<=0 then return end
 local now=os.clock()
 if not p.holdUntil then p.holdFrom=now end
 p.holdUntil=math.max(p.holdUntil or 0,now+seconds)
end
-- v34 signatures (Peter: "all of the moves and powers need signature assets, animation, movement and
-- sounds; they should look different, sound different and have different miss, movement and hit feedback").
-- Everything is looks and sound only. One table (Sig) so the client stays well under Luau's 200 locals.
local Sig={}
Sig.Motion=require(RS.HeroWars.FlightMotion)
-- Sound bank. Each entry is a list; one is picked at random so repeats don't sound identical.
-- rbxassetid ones are Roblox's free Pro Sound Effects library (uploader ProSoundEffects, verified) and the
-- Roblox account's own sounds; rbxasset ones ship with the client. v33's swordslash/collide/unsheath
-- rbxasset paths are not in the current client sound list, so those moves were most likely silent.
Sig.BANK={
 swingFast={"rbxassetid://9120704940","rbxassetid://9120705181","rbxassetid://9126014020"},
 swingHeavy={"rbxassetid://9120728815","rbxassetid://9120729339"},
 punchLight={"rbxassetid://9113510797","rbxassetid://9117969420","rbxassetid://9119641416"},
 punchHeavy={"rbxassetid://9117969687","rbxassetid://9117971636","rbxassetid://9117972870"},
 clang={"rbxassetid://9119072660","rbxassetid://9119072674","rbxassetid://9119746598"},
 block={"rbxassetid://9116524438","rbxassetid://9113510797"},
 slash={"rbxassetid://9119749145","rbxassetid://9126013811","rbxassetid://12222216"},
 zap={"rbxassetid://9114277757","rbxassetid://9116275998","rbxassetid://9113147849"},
 thunder={"rbxassetid://9120018050","rbxassetid://9126082854"},
 wind={"rbxassetid://9114373663","rbxassetid://9113840530","rbxassetid://9113080102"},
 laser={"rbxassetid://9116236630","rbxassetid://9116236891"},
 fire={"rbxassetid://9117987817","rbxassetid://9117987278"},
 explosion={"rbxassetid://9116973611","rbxassetid://9114086657","rbxasset://sounds/impact_explosion_03.mp3"},
 fizz={"rbxassetid://9125640290"},
 portal={"rbxassetid://9116421550","rbxassetid://9116421827","rbxassetid://9125648149"},
 ghost={"rbxassetid://9125989410","rbxassetid://9119707097","rbxassetid://9116406610"},
 chain={"rbxassetid://9113760225","rbxassetid://9113763590","rbxassetid://9120660173"},
 stomp={"rbxassetid://9114523161","rbxassetid://9126009571","rbxassetid://9118685591"},
 dash={"rbxassetid://9126229255","rbxassetid://9120733724"},
 land={"rbxasset://sounds/action_jump_land.mp3","rbxassetid://9113481039"},
 charge={"rbxassetid://9117885256","rbxassetid://9117884499"},
 shield={"rbxassetid://9117885256","rbxassetid://9117884499"},
 parry={"rbxassetid://9125361455","rbxassetid://9113133597"},
 whiff={"rbxassetid://9126047581","rbxassetid://9120704978","rbxassetid://9113305311"},
 grunt={"rbxassetid://9116451739","rbxasset://sounds/ouch.ogg"},
}
-- Long library sounds are faded out after this many seconds (thunder and wind run 2 to 5 s).
Sig.CUT={thunder=1.5,wind=1.2,ghost=1.3,stomp=1.4,explosion=1.6,charge=1,shield=1.1,punchHeavy=1.2}
-- Per-hero signature: impact style, miss style, movement style, text colour, and which bank sounds each
-- kind of action uses (name, volume, pitch).
Sig.HERO={
 Solarion={hit="sun",whiffFx="ember",step="spark",landFx="flare",text=Color3.fromRGB(255,214,110),
  swingL={"swingFast",0.45,1.1},swingH={"swingHeavy",0.6,0.85},hitL={"punchLight",0.6,1.05},hitH={"fire",0.8,0.95},
  whiff={"fizz",0.35,1.4},dash={"dash",0.55,0.95},land={"land",0.7,0.9},block={"block",0.5,1}},
 Wraithstep={hit="claw",whiffFx="smoke",step="wisp",landFx="smoke",text=Color3.fromRGB(205,150,255),
  swingL={"slash",0.45,1.35},swingH={"slash",0.6,0.75},hitL={"slash",0.55,1.5},hitH={"ghost",0.7,0.9},
  whiff={"ghost",0.3,1.6},dash={"ghost",0.5,1.25},land={"land",0.35,1.3},block={"block",0.45,1.2}},
 Tempest={hit="storm",whiffFx="static",step="breeze",landFx="gust",text=Color3.fromRGB(170,225,255),
  swingL={"zap",0.4,1.3},swingH={"wind",0.6,1.1},hitL={"zap",0.55,1.15},hitH={"thunder",0.7,1.05},
  whiff={"zap",0.25,1.8},dash={"wind",0.55,1.35},land={"wind",0.4,0.9},block={"block",0.5,1.1}},
 Bulwark={hit="bronze",whiffFx="stumble",step="quake",landFx="quake",text=Color3.fromRGB(255,190,110),
  swingL={"swingHeavy",0.5,1.15},swingH={"swingHeavy",0.75,0.7},hitL={"punchHeavy",0.7,1.1},hitH={"clang",0.85,0.8},
  whiff={"grunt",0.5,0.9},dash={"stomp",0.6,1.1},land={"stomp",0.8,0.85},block={"clang",0.6,1.2}},
 -- V59 Valkyra: light, quick spear-and-shield sounds and a gold flash on impact.
 Valkyra={hit="sun",whiffFx="ember",step="breeze",landFx="gust",text=Color3.fromRGB(255,214,120),
  swingL={"swingFast",0.45,1.25},swingH={"swingHeavy",0.6,1.0},hitL={"punchLight",0.6,1.2},hitH={"clang",0.75,1.1},
  whiff={"fizz",0.3,1.5},dash={"wind",0.55,1.3},land={"land",0.55,1.1},block={"block",0.5,1.15}},
 -- V60 Dread Knight: heavy great-sword sounds; cold white fire on every footstep and landing.
 DreadKnight={hit="bronze",whiffFx="smoke",step="coldfire",landFx="coldfire",text=Color3.fromRGB(205,235,255),
  swingL={"swingHeavy",0.55,0.9},swingH={"swingHeavy",0.8,0.65},hitL={"punchHeavy",0.7,0.9},hitH={"clang",0.85,0.7},
  whiff={"grunt",0.5,0.7},dash={"stomp",0.6,0.9},land={"stomp",0.8,0.75},block={"clang",0.6,1.0}},
}
-- Per-move overrides: cast sound at release, hit sound, impact style, and the victim's reaction.
Sig.MOVE={
 Beam={cast={"laser",0.7,1},charge={"charge",0.45,1},hitSnd={"fire",0.8,1.1},hit="scorch",react="burn"},
 Pounce={cast={"dash",0.7,0.8},hitSnd={"explosion",0.8,1.1},hit="sunquake",react="body"},
 SolarFlare={cast={"explosion",0.9,1},charge={"charge",0.5,0.8},hitSnd={"fire",0.7,1.2},hit="sun",react="burn"},
 Grapple={cast={"chain",0.7,1},charge={"ghost",0.5,0.8},hitSnd={"chain",0.8,0.8},hit="chain",react="pull"},
 Uppercut={cast={"swingHeavy",0.6,1.2},hitSnd={"punchHeavy",0.85,1},hit="claw",react="launch"},
 ShadowDoor={cast={"portal",0.6,1.3},charge={"ghost",0.5,1}},
 Lightning={cast={"thunder",0.85,1},charge={"charge",0.45,1.3},hitSnd={"zap",0.9,0.9},hit="bolt",react="shock"},
 Gale={cast={"wind",0.75,1},hitSnd={"wind",0.6,1.4},hit="gust",react="stagger"},
 Whirlwind={cast={"wind",0.9,0.7},charge={"wind",0.5,1.3},hitSnd={"wind",0.8,0.9},hit="gust",react="spin"},
 Slam={cast={"stomp",1,0.8},hitSnd={"clang",0.9,0.7},hit="quake",react="body"},
 Charge={cast={"dash",0.8,0.75},hitSnd={"punchHeavy",0.9,0.8},hit="bronze",react="stagger"},
 DimensionDoor={cast={"portal",0.7,0.8},charge={"charge",0.45,0.7}},
 TitanDrop={cast={"grunt",0.7,0.8},hitSnd={"stomp",1,0.7},hit="quake",react="body"},
 Throw={cast={"swingFast",0.5,0.9},react="spin"},
 -- V59 Valkyra
 JavelinOfLight={cast={"swingFast",0.7,1.3},charge={"charge",0.4,1.4},hitSnd={"zap",0.8,1.2},hit="sun",react="shock"},
 ValkyrieDive={cast={"dash",0.7,1.0},hitSnd={"explosion",0.7,1.3},hit="sunquake",react="body"},
 WingedRush={cast={"wind",0.75,1.3},hitSnd={"punchHeavy",0.8,1.1},hit="sun",react="stagger"},
 SkyToss={cast={"swingFast",0.5,1.1},react="launch"},
 -- V60 Dread Knight
 DeathGrip={cast={"chain",0.8,0.8},charge={"ghost",0.5,0.7},hitSnd={"chain",0.85,0.7},hit="chain",react="pull"},
 SoulReaper={cast={"dash",0.7,0.7},hitSnd={"clang",0.9,0.6},hit="quake",react="body"},
 BlightGround={cast={"ghost",0.8,0.6},charge={"charge",0.45,0.6}},
}
-- Victim reactions per hero for the basic attacks (moves above override these).
Sig.REACT={
 Solarion={Light1="jab",Light2="jab",Light3="body",Heavy="body"},
 Wraithstep={Light1="claw",Light2="claw",Light3="spin",Heavy="claw"},
 Tempest={Light1="shock",Light2="shock",Light3="launch",Heavy="shock"},
 Bulwark={Light1="jab",Light2="stagger",Light3="body",Heavy="stagger"},
 Valkyra={Light1="jab",Light2="stagger",Light3="launch",Heavy="body"}, -- V59
 DreadKnight={Light1="stagger",Light2="stagger",Light3="body",Heavy="body"}, -- V60
}
-- Hurt poses by reaction (joint angles, same keys as KEYS). jitter = shakes while it holds (electric).
Sig.HURTS={
 jab={wx=0.25,nx=0.55,wy=0.25,rs=0.4,re=1.5,ls=0.6,le=1.6,ry=-0.05},
 body={wx=-0.65,nx=-0.25,rs=0.9,re=1.9,ls=0.9,le=1.9,ry=-0.35,rh=0.3,rk=-0.5,lh=0.2,lk=-0.4},
 launch={wx=0.75,nx=0.65,rs=-0.7,re=0.6,ls=-0.7,le=0.6,rx=0.25,rh=0.4,rk=-0.6,lk=-0.3},
 spin={wy=1.1,wx=0.2,nx=0.3,rs=1.0,re=0.4,ls=-0.5,le=0.8,rh=0.3,lh=-0.3},
 shock={wx=0.15,nx=0.45,rs=1.3,re=0.1,ls=1.3,le=0.1,rh=0.15,lh=-0.15,jitter=true},
 burn={wx=0.4,nx=-0.35,rs=1.7,re=2.3,ls=1.7,le=2.3,ry=-0.2},
 stagger={wx=0.35,wy=-0.65,nx=0.3,rs=0.3,re=0.6,ls=1.0,le=1.2,rh=0.5,rk=-0.3,lh=-0.4,ry=-0.15},
 claw={wy=0.75,nx=0.35,wx=0.15,ls=0.9,le=2.1,rs=0.3,re=1.0},
 pull={wx=-0.5,nx=0.2,rs=1.8,re=0.3,ls=1.8,le=0.3,rh=-0.4,lh=0.3,ry=-0.2},
}
-- Per-hero attack animations (Peter: "they currently all look the same"). Same timing as the shared
-- KEYS (that comes from Rules); only the shapes differ. Filled in below KEYS.
Sig.KEYS={}
function Sig.heroOf(model) return model and model:GetAttribute("Hero") or "" end
function Sig.play(spec,where,volScale)
 if not spec or not where then return end
 local list=Sig.BANK[spec[1]]; if not list or #list==0 then return end
 local id=list[math.random(1,#list)]
 local s=Instance.new("Sound"); s.SoundId=id; s.Volume=(spec[2] or 0.6)*(volScale or 1)
 s.PlaybackSpeed=(spec[3] or 1)*(0.95+math.random()*0.1); s.RollOffMaxDistance=160
 if typeof(where)=="Vector3" then local p=anchorPoint(CFrame.new(where)); s.Parent=p; Debris:AddItem(p,4)
 else s.Parent=where end
 s:Play(); Debris:AddItem(s,4)
 local cut=Sig.CUT[spec[1]]
 if cut then task.delay(cut,function() if s.Parent then TweenService:Create(s,TweenInfo.new(0.35),{Volume=0}):Play() end end) end
end
-- The sound an action makes for this hero and move. kind: "cast", "charge", "hit", "whiff".
function Sig.sound(model,moveName,kind,where,heavy)
 if Sig.heroOf(model)=="Solarion" and moveName=="Heavy" then moveName="Beam" end
 local H=Sig.HERO[Sig.heroOf(model)] or Sig.HERO.Solarion
 local M=Sig.MOVE[moveName or ""]
 if kind=="cast" then Sig.play((M and M.cast) or (heavy and H.swingH or H.swingL),where)
 elseif kind=="charge" then if M and M.charge then Sig.play(M.charge,where) end
 elseif kind=="hit" then Sig.play((M and M.hitSnd) or (heavy and H.hitH or H.hitL),where); if heavy and not (M and M.hitSnd) then Sig.play(H.hitL,where,0.6) end
 elseif kind=="whiff" then Sig.play(H.whiff,where); Sig.play({"whiff",0.35,heavy and 0.75 or 1.1},where)
 elseif kind=="dash" then Sig.play(H.dash,where)
 elseif kind=="land" then Sig.play(H.land,where)
 elseif kind=="block" then Sig.play(H.block,where) end
end
function Sig.react(attacker,moveName)
 local M=Sig.MOVE[moveName or ""]
 if M and M.react then return M.react end
 local R=Sig.REACT[Sig.heroOf(attacker)]
 return R and R[moveName or ""] or "jab"
end
local function sigEmbers(pos,color,count,speed,up)
 local p,a=anchorPoint(CFrame.new(pos))
 emitter(a,color,{Rate=0,Lifetime=NumberRange.new(0.3,0.7),Speed=NumberRange.new(speed*0.5,speed),Drag=3,
  Acceleration=Vector3.new(0,up or 0,0),SpreadAngle=Vector2.new(180,180),
  Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.3),NumberSequenceKeypoint.new(1,0)})}):Emit(count)
 Debris:AddItem(p,1)
end
local function sigSmoke(pos,count)
 local h=fxPart(Enum.PartType.Ball,Vector3.one*0.1,CFrame.new(pos),Color3.new(),1)
 local a=Instance.new("Attachment"); a.Parent=h; shadowSmoke(a,0):Emit(count); Debris:AddItem(h,1.5)
end
local function sigArc(a,b,color,width,segs,jit,dur)
 local span=b-a; if span.Magnitude<0.2 then return end
 local side=span.Unit:Cross(Vector3.yAxis); if side.Magnitude<0.1 then side=Vector3.xAxis end; side=side.Unit
 local up=side:Cross(span.Unit).Unit; local last=a
 for i=1,segs do
  local nxt=i==segs and b or a+span*(i/segs)+side*(math.random()-0.5)*jit+up*(math.random()-0.5)*jit
  fadeOut(fxPart(Enum.PartType.Block,Vector3.new(width,width,(nxt-last).Magnitude),CFrame.lookAt((last+nxt)/2,nxt),color,0),dur)
  last=nxt
 end
end
local function sigRays(pos,facing,color,count,len,width,dur)
 local base=CFrame.lookAt(pos,pos+facing)
 for i=1,count do
  local d=(base*CFrame.Angles(0,0,i/count*math.pi*2)*CFrame.Angles(math.rad(70),0,0)).LookVector
  local p=fxPart(Enum.PartType.Block,Vector3.new(width,width,0.4),CFrame.lookAt(pos,pos+d),color,0)
  fadeOut(p,dur,{Size=Vector3.new(width*0.3,width*0.3,len),CFrame=CFrame.lookAt(pos,pos+d)*CFrame.new(0,0,-len/2)})
 end
end
-- Impact visuals. style from the move (Sig.MOVE) or the attacker's hero.
function Sig.hit(target,attacker,moveName,pos,toward,heavy,accent,size)
 local M=Sig.MOVE[moveName or ""]; local H=Sig.HERO[Sig.heroOf(attacker)] or Sig.HERO.Solarion
 local style=(M and M.hit) or H.hit
 local troot=target and target:FindFirstChild("HumanoidRootPart"); if not troot then return end
 local facing=toward.Magnitude>0.1 and toward or troot.CFrame.LookVector
 local white=Color3.new(1,1,1)
 if style=="sun" or style=="scorch" or style=="sunquake" then
  -- Solar: a white-hot core, golden rays bursting out, embers drifting up.
  burst(pos,Color3.fromRGB(255,250,225),size*0.7,0.12); burst(pos,accent,size,0.28)
  sigRays(pos,facing,Color3.fromRGB(255,215,120),heavy and 10 or 6,size*1.4,0.22,0.22)
  sigEmbers(pos,Color3.fromRGB(255,170,60),heavy and 26 or 12,10,8)
  if style=="scorch" then
   local g=groundBelow(target,troot)
   fadeOut(fxPart(Enum.PartType.Cylinder,Vector3.new(0.05,5,5),CFrame.new(g+Vector3.new(0,0.06,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(40,25,15),0.2,Enum.Material.SmoothPlastic),1.4)
  elseif style=="sunquake" then
   local g=groundBelow(target,troot)
   ring(g+Vector3.new(0,0.1,0),accent,size*3.5,0.4); ring(g+Vector3.new(0,0.12,0),Color3.fromRGB(255,240,200),size*2,0.3)
  end
 elseif style=="claw" or style=="chain" then
  -- Shadow: three glowing claw rakes slashed across the target and a puff of smoke.
  local base=CFrame.lookAt(pos,pos+facing)*CFrame.Angles(0,0,math.rad(math.random(-50,50)))
  for i=-1,1 do
   local cf=base*CFrame.new(i*0.42,0,-0.1)
   local p=fxPart(Enum.PartType.Block,Vector3.new(0.12,0.4,0.05),cf*CFrame.new(0,1.4,0),accent,0)
   fadeOut(p,0.32,{Size=Vector3.new(0.08,heavy and 3.6 or 2.8,0.05),CFrame=cf})
  end
  sigSmoke(pos,heavy and 22 or 10); burst(pos,Color3.fromRGB(30,10,40),size*0.8,0.2)
  if style=="chain" then
   for i=0,2 do task.delay(i*0.06,function() if troot.Parent then ring(troot.Position+Vector3.new(0,i-1,0),accent,4.2,0.3) end end) end
  end
 elseif style=="storm" or style=="bolt" or style=="gust" then
  -- Storm: jagged arcs crawl over the target, a blue-white flash, static sparks.
  burst(pos,white,size*0.6,0.1)
  for _=1,heavy and 4 or 2 do
   local a=troot.Position+Vector3.new((math.random()-0.5)*3,(math.random()-0.2)*3,(math.random()-0.5)*3)
   local b=troot.Position+Vector3.new((math.random()-0.5)*3,(math.random()-0.5)*3,(math.random()-0.5)*3)
   sigArc(a,b,math.random()<0.5 and white or accent,0.12,4,0.9,0.16)
  end
  sigEmbers(pos,Color3.fromRGB(190,235,255),heavy and 22 or 10,16,0)
  if style=="bolt" then sigArc(troot.Position+Vector3.new(0,16,0),troot.Position,white,0.35,7,2.4,0.25); ring(groundBelow(target,troot)+Vector3.new(0,0.1,0),accent,8,0.3) end
  if style=="gust" then
   for i=0,2 do
    local p=fxPart(Enum.PartType.Cylinder,Vector3.new(0.15,2,2),CFrame.new(troot.Position+Vector3.new(0,i*1.2-1,0))*CFrame.Angles(0,0,math.pi/2),Color3.new(0.9,0.97,1),0.4)
    fadeOut(p,0.35,{Size=Vector3.new(0.15,5+i,5+i)})
   end
  end
 elseif style=="bronze" or style=="quake" then
  -- Bronze: hot metal sparks spraying out and falling, a dust shock round the feet.
  burst(pos,Color3.fromRGB(255,235,190),size*0.6,0.1); burst(pos,Color3.fromRGB(205,150,70),size*0.9,0.22)
  local p,a=anchorPoint(CFrame.lookAt(pos,pos-facing+Vector3.new(0,0.3,0)))
  emitter(a,Color3.fromRGB(255,180,80),{Rate=0,Lifetime=NumberRange.new(0.3,0.6),Speed=NumberRange.new(16,30),Drag=2,
   Acceleration=Vector3.new(0,-60,0),SpreadAngle=Vector2.new(35,35),EmissionDirection=Enum.NormalId.Front,
   Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.22),NumberSequenceKeypoint.new(1,0.05)})}):Emit(heavy and 30 or 16)
  Debris:AddItem(p,1)
  local g=groundBelow(target,troot)
  ring(g+Vector3.new(0,0.1,0),Color3.fromRGB(170,160,140),heavy and 10 or 6,0.45)
  if style=="quake" then
   for i=1,6 do
    local ang=i/6*math.pi*2
    local chunk=fxPart(Enum.PartType.Block,Vector3.one*(0.4+math.random()*0.4),CFrame.new(g),Color3.fromRGB(90,92,100),0,Enum.Material.Slate)
    fadeOut(chunk,0.55,{CFrame=CFrame.new(g+Vector3.new(math.cos(ang),0,math.sin(ang))*3+Vector3.new(0,1.5+math.random()*1.5,0))*CFrame.Angles(math.random()*3,math.random()*3,0)})
   end
  end
 end
end
-- Missing: each hero's own fizzle at the end of the reach, plus a dull swish.
function Sig.whiff(model,moveName,reach,heavy)
 local H=Sig.HERO[Sig.heroOf(model)] or Sig.HERO.Solarion
 local accent=heroAccent(model)
 local style=H.whiffFx
 if style=="ember" then
  sigEmbers(reach,Color3.fromRGB(255,140,40),10,4,-20); burst(reach,Color3.fromRGB(255,190,90),1.4,0.15)
 elseif style=="smoke" then
  sigSmoke(reach,heavy and 14 or 8)
 elseif style=="static" then
  for _=1,2 do sigArc(reach,reach+Vector3.new((math.random()-0.5)*2.5,(math.random()-0.5)*2.5,(math.random()-0.5)*2.5),accent,0.07,3,0.6,0.12) end
 elseif style=="stumble" then
  local root=model:FindFirstChild("HumanoidRootPart")
  if root then
   local g=groundBelow(model,root)
   ring(g+Vector3.new(0,0.1,0),Color3.fromRGB(175,165,145),5,0.4); burst(g+root.CFrame.LookVector*2,Color3.fromRGB(175,165,145),2.5,0.35)
  end
 end
 Sig.sound(model,moveName,"whiff",reach,heavy)
 local root=model:FindFirstChild("HumanoidRootPart")
 if root then popText(model,"MISS",H.text:Lerp(Color3.fromRGB(180,180,190),0.5),20) end
end
-- Dash: each hero leaves their own trail.
function Sig.dash(model,root)
 local hero=Sig.heroOf(model)
 local g=groundBelow(model,root)
 if hero=="Solarion" then
  afterimages(root,Color3.fromRGB(255,205,110),5); sigEmbers(root.Position,Color3.fromRGB(255,170,60),14,6,6)
 elseif hero=="Wraithstep" then
  sigSmoke(root.Position,18)
  for i=0,2 do task.delay(i*0.05,function() if root.Parent then sigSmoke(root.Position,6) end end) end
 elseif hero=="Tempest" then
  afterimages(root,Color3.fromRGB(205,235,255),4)
  for i=-1,1,2 do
   local side=root.CFrame.RightVector*i*1.2
   beamBetween(root.Position+side-root.CFrame.LookVector*1,root.Position+side-root.CFrame.LookVector*6,Color3.new(0.9,0.97,1),0.15,0.25)
  end
 else
  ring(g+Vector3.new(0,0.1,0),Color3.fromRGB(175,165,145),9,0.4)
  for i=0,3 do task.delay(i*0.06,function() if root.Parent then burst(groundBelow(model,root)+Vector3.new(0,0.4,0),Color3.fromRGB(185,175,155),3,0.35) end end) end
  local me=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if me and (me.Position-g).Magnitude<18 then shake(0.25,0.15) end
 end
 Sig.sound(model,nil,"dash",root)
end
-- Footsteps and landings (run on every client for every fighter).
Sig.moveState=setmetatable({},{__mode="k"})
function Sig.move(model,root,now)
 local st=Sig.moveState[model]; if not st then st={vy=0,step=now}; Sig.moveState[model]=st end
 local v=root.AssemblyLinearVelocity; local flat=Vector3.new(v.X,0,v.Z).Magnitude
 local hero=Sig.heroOf(model); local H=Sig.HERO[hero]
 if not H then return end
 if model:GetAttribute("Flying") then
  -- v35: each flyer leaves her or his own wake. Solarion sheds sparks and a heat ring; Tempest rides a
  -- spinning wind vortex with a crackle of lightning now and then.
  st.vy=v.Y
  local below=root.Position-Vector3.new(0,3,0)
  if hero=="Solarion" and now-(st.fx or 0)>0.09 then
   st.fx=now; sigEmbers(below,Color3.fromRGB(255,170,60),4,8,-25)
   if flat>8 then fadeOut(fxPart(Enum.PartType.Ball,Vector3.one*1.2,CFrame.new(root.Position-root.CFrame.LookVector*1.5),Color3.fromRGB(255,200,90),0.5),0.3,{Size=Vector3.one*0.2}) end
  elseif hero=="Tempest" and now-(st.fx or 0)>0.16 then
   st.fx=now
   local r=fxPart(Enum.PartType.Cylinder,Vector3.new(0.12,2.2,2.2),CFrame.new(below+Vector3.new(0,0.4,0))*CFrame.Angles(0,0,math.pi/2),Color3.new(0.88,0.96,1),0.45)
   fadeOut(r,0.45,{Size=Vector3.new(0.12,5.5,5.5),CFrame=CFrame.new(below-Vector3.new(0,1.2,0))*CFrame.Angles(0,0,math.pi/2)})
   if math.random()<0.18 then sigArc(below+Vector3.new((math.random()-0.5)*3,0,(math.random()-0.5)*3),root.Position+Vector3.new((math.random()-0.5)*2,-0.5,(math.random()-0.5)*2),Color3.new(1,1,1),0.07,4,0.7,0.12) end
  end
  return
 end
 -- v35 stealth wake: hidden Wraithstep sees thin shadow wisps rising off himself (only on his own
 -- screen, so they never give him away).
 if model==player.Character and (model:GetAttribute("Invisible") or model:GetAttribute("Shrouded")) and now-(st.fx or 0)>0.14 then
  st.fx=now; sigSmoke(root.Position-Vector3.new(0,1.5,0),2)
 end
 local landed=st.vy<-28 and v.Y>-4
 st.vy=v.Y
 if landed then
  local g=groundBelow(model,root)
  if H.landFx=="quake" then
   ring(g+Vector3.new(0,0.1,0),Color3.fromRGB(175,165,145),10,0.45); burst(g,Color3.fromRGB(185,175,155),4,0.35)
   local me=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   if me and (me.Position-g).Magnitude<25 then shake(0.5,0.2) end
  elseif H.landFx=="flare" then ring(g+Vector3.new(0,0.1,0),Color3.fromRGB(255,200,90),6,0.3); sigEmbers(g,Color3.fromRGB(255,170,60),10,6,4)
  elseif H.landFx=="smoke" then sigSmoke(g+Vector3.new(0,0.5,0),8)
  elseif H.landFx=="coldfire" then Sig.coldPrint(g,2.4); sigEmbers(g+Vector3.new(0,0.2,0),Color3.fromRGB(215,240,255),14,5,6) -- V60
  else ring(g+Vector3.new(0,0.1,0),Color3.new(0.9,0.97,1),6,0.3) end
  Sig.sound(model,nil,"land",root)
 end
 if flat>6 and math.abs(v.Y)<3 and now-st.step>(hero=="Bulwark" and 0.42 or 0.3)*(16/math.max(flat,8)) then
  st.step=now
  local g=groundBelow(model,root)
  if H.step=="quake" then
   burst(g+Vector3.new(0,0.2,0),Color3.fromRGB(185,175,155),1.6,0.3); Sig.play({"stomp",0.18,1.3},root)
  elseif H.step=="spark" then sigEmbers(g+Vector3.new(0,0.2,0),Color3.fromRGB(255,190,80),3,3,4)
  elseif H.step=="wisp" then sigSmoke(g+Vector3.new(0,0.3,0),2)
  elseif H.step=="coldfire" then -- V60 Dread Knight: each footfall leaves a print of cold white fire under that foot
   st.foot=st.foot=="LeftFoot" and "RightFoot" or "LeftFoot"
   local f=model:FindFirstChild(st.foot)
   if f then g=Vector3.new(f.Position.X,g.Y,f.Position.Z) end
   Sig.coldPrint(g,1.1); sigEmbers(g+Vector3.new(0,0.15,0),Color3.fromRGB(215,240,255),4,2,5)
  elseif H.step=="breeze" then fadeOut(fxPart(Enum.PartType.Cylinder,Vector3.new(0.1,1,1),CFrame.new(g+Vector3.new(0,0.1,0))*CFrame.Angles(0,0,math.pi/2),Color3.new(0.9,0.97,1),0.5),0.3,{Size=Vector3.new(0.1,2.5,2.5)}) end
 end
end
-- v36 graphics pass (Peter: "upgrade all graphics for everything in HeroWars"). Looks only.
-- Weapon trails: the striking limb (or Bulwark's sword) leaves a ribbon in the hero's colour through
-- the swing, from just before the hit frames to just after.
Sig.LIMB={
 Default={Light1={"RightHand"},Light2={"LeftHand"},Light3={"RightFoot"},Heavy={"RightHand","LeftHand"},Uppercut={"RightHand"},
  Pounce={"RightHand","LeftHand"},Slam={"RightHand","LeftHand"},Charge={"LeftHand"},Gale={"RightHand","LeftHand"},
  Lightning={"RightHand"},Beam={"RightHand"},Grapple={"RightHand"},Whirlwind={"RightHand","LeftHand"},SolarFlare={"RightHand","LeftHand"}},
 Tempest={Light1={"LeftHand"},Light2={"RightHand"},Light3={"LeftFoot"}},
 Bulwark={Light1={"LeftHand"},Light2={"SwordBlade"},Light3={"RightFoot"},Heavy={"SwordBlade"},Slam={"SwordBlade","LeftHand"}},
 Valkyra={Light1={"RightHand"},Light2={"LeftHand"},Light3={"RightFoot"},Heavy={"RightHand"},JavelinOfLight={"RightHand"}, -- V59
  ValkyrieDive={"RightHand","LeftHand"},WingedRush={"LeftHand"},SkyToss={"RightHand","LeftHand"}},
 DreadKnight={Light1={"Greatsword"},Light2={"Greatsword"},Light3={"Greatsword"},Heavy={"Greatsword"},SoulReaper={"Greatsword"}}, -- V60: the blade trails
}
function Sig.trailOn(part,accent)
 local tr=part:FindFirstChild("SigTrail")
 if not tr then
  -- The ribbon runs along the part's longest side.
  local s=part.Size; local axis=(s.X>=s.Y and s.X>=s.Z) and Vector3.xAxis or (s.Y>=s.Z and Vector3.yAxis or Vector3.zAxis)
  local half=math.max(s.X,s.Y,s.Z)*0.45
  local a0=Instance.new("Attachment"); a0.Name="SigTrailA"; a0.Position=axis*half; a0.Parent=part
  local a1=Instance.new("Attachment"); a1.Name="SigTrailB"; a1.Position=-axis*half; a1.Parent=part
  tr=Instance.new("Trail"); tr.Name="SigTrail"; tr.Attachment0=a0; tr.Attachment1=a1
  tr.Lifetime=0.16; tr.MinLength=0.02; tr.LightEmission=0.85; tr.LightInfluence=0; tr.FaceCamera=true
  tr.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)})
  tr.WidthScale=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0.3)})
  tr.Enabled=false; tr.Parent=part
 end
 tr.Color=ColorSequence.new(Color3.new(1,1,1),accent)
 return tr
end
function Sig.trail(model,p)
 if not model or not p or p.trailed or not p.move then return end
 p.trailed=true
 local hero=Sig.heroOf(model)
 local list=(Sig.LIMB[hero] and Sig.LIMB[hero][p.name]) or Sig.LIMB.Default[p.name]
 if not list then return end
 local m=p.move; local accent=heroAccent(model,p.name)
 local age=os.clock()-p.start
 local on=math.max(0,(m.Startup-3)/60-age); local off=math.max(on+0.05,(m.Startup+m.Active+5)/60-age)
 for _,name in list do
  local part=model:FindFirstChild(name,true)
  if part and part:IsA("BasePart") then
   local tr=Sig.trailOn(part,accent)
   task.delay(on,function() if poses[model]==p and not (hiddenFromMe and hiddenFromMe(model)) then tr.Enabled=true end end)
   task.delay(off,function() tr.Enabled=false end)
  end
 end
end
-- Big blows involving me: a flash of contrast and a short camera punch-in. Dashes widen the view a moment.
Sig.FOV=70
function Sig.punch(amount)
 local cc=game:GetService("Lighting"):FindFirstChild("SigImpact")
 if not cc then cc=Instance.new("ColorCorrectionEffect"); cc.Name="SigImpact"; cc.Parent=game:GetService("Lighting") end
 cc.Brightness=0.08*amount; cc.Contrast=0.3*amount; cc.Saturation=-0.25*amount
 TweenService:Create(cc,TweenInfo.new(0.28,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Brightness=0,Contrast=0,Saturation=0}):Play()
 Sig.fov(-4*amount,0.3)
end
function Sig.fov(delta,dur)
 local cam=workspace.CurrentCamera; if not cam then return end
 cam.FieldOfView=Sig.FOV+delta
 TweenService:Create(cam,TweenInfo.new(dur,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{FieldOfView=Sig.FOV}):Play()
end
-- Low health: red edges that pulse faster the closer I am to dying.
Sig.vig={frames={},level=0}
for i,v in {{UDim2.fromScale(0,0),UDim2.fromScale(0.16,1),0},{UDim2.fromScale(0,0),UDim2.fromScale(1,0.2),90},
 {UDim2.fromScale(0.84,0),UDim2.fromScale(0.16,1),180},{UDim2.fromScale(0,0.8),UDim2.fromScale(1,0.2),270}} do
 local f=Instance.new("Frame"); f.Name="LowHealth"..i; f.Position=v[1]; f.Size=v[2]; f.BorderSizePixel=0
 f.BackgroundColor3=Color3.fromRGB(170,0,0); f.BackgroundTransparency=1; f.Active=false; f.ZIndex=0; f.Parent=gui
 local g=Instance.new("UIGradient"); g.Rotation=v[3]
 g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,1)}); g.Parent=f
 table.insert(Sig.vig.frames,f)
end
RunService.RenderStepped:Connect(function()
 local lvl=Sig.vig.level
 if lvl<=0 and Sig.vig.off then return end -- R30: nothing to do at healthy HP
 Sig.vig.off=lvl<=0
 local t=lvl<=0 and 1 or math.clamp(0.75-lvl*0.35+math.sin(os.clock()*(3+lvl*5))*0.12,0.25,1)
 for _,f in Sig.vig.frames do f.BackgroundTransparency=t end
end)
-- v36 motion capture. Mixamo moves converted to R15 keyframes (HeroWars-tools/mixamo_to_r15.py) live in
-- ReplicatedStorage.HeroWars.Mocap, named like the download list (solarion_light1, hit_head, tempest_fly).
-- A move with a capture plays it, sped to the move's frame data and frozen through hit-stop; every
-- move without one keeps its hand-made pose. Studio playtests play them without publishing.
Sig.MOCAP_FILE={SolarFlare="flare",ShadowDoor="door",DimensionDoor="door",ChargeLeap="leap"}
-- v49: the Interrupt and Super moves borrow one of the hero's existing moves for pose and capture.
Sig.ALIAS={Solarion={Interrupt="Light2",Heavy="Beam"},Wraithstep={Interrupt="Light1",Super="Uppercut"},
 Tempest={Interrupt="Lightning",Super="Lightning"},Bulwark={Interrupt="Light1",Super="Slam"},
 -- V59: Valkyra's moves borrow the nearest generic pose keys; her captures are named after these (valkyra_lightning ...).
 Valkyra={JavelinOfLight="Lightning",ValkyrieDive="Pounce",WingedRush="Charge",SkyToss="Throw"},
 -- V60: Dread Knight's moves borrow generic pose keys too (captures dreadknight_grapple, _pounce, _slam).
 DreadKnight={DeathGrip="Grapple",SoulReaper="Pounce",BlightGround="Slam",Interrupt="Light1"}}
function Sig.alias(hero,name) local a=Sig.ALIAS[hero or ""]; return a and a[name] or name end
Sig.MOCAP_REACT={jab="hit_head",claw="hit_head",shock="hit_shock",body="hit_body",burn="hit_body",pull="hit_body",
 stagger="hit_side",spin="hit_side",launch="hit_side"}
Sig.mocapIds={}; Sig.mocapCache=setmetatable({},{__mode="k"}); Sig.mocapNow=setmetatable({},{__mode="k"})
-- v50: a move with its own capture instead of the alias's (Bulwark's Shield Throw on the Interrupt slot).
Sig.MOCAP_OVERRIDE={Bulwark={Interrupt="bulwark_shieldthrow"},Solarion={Heavy="solarion_heavy"},DreadKnight={Interrupt="dreadknight_gravestrike"}} -- V56: Solar Hammer plays its own (Blender) capture, not the Beam alias
-- v50 captured ground loops per hero: Wraithstep stays crouched (idle) and runs low with his arms back (run);
-- Solarion and Tempest have an idle. A hero without a run keeps the Roblox run.
-- V52 gave the Bulwark slot Valkyra's shield idle and jog; V59 moves them to her own hero (valkyra_idle, valkyra_run) and
-- Bulwark is back on his knight set (no captured loops, as in V51).
-- V60 Dread Knight's cold white fire (looks only, every client). coldPrint: a fading footprint of white-blue flame on the
-- ground; coldEyes: two small cold flames and a pale light burning in the eye slits of his helmet, made once per body.
Sig.COLD=Color3.fromRGB(215,240,255)
function Sig.coldPrint(at,size)
 -- a translucent ice-blue glow on the ground with a white-hot centre and cold wisps rising off it; fades in 1.6 s
 local glow=fxPart(Enum.PartType.Cylinder,Vector3.new(0.05,size,size),CFrame.new(at+Vector3.new(0,0.05,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(150,210,255),0.55)
 fadeOut(glow,1.6,{Size=Vector3.new(0.05,size*1.3,size*1.3)})
 local core=fxPart(Enum.PartType.Cylinder,Vector3.new(0.06,size*0.4,size*0.4),CFrame.new(at+Vector3.new(0,0.06,0))*CFrame.Angles(0,0,math.pi/2),Color3.new(1,1,1),0.3)
 fadeOut(core,0.9)
 local a=Instance.new("Attachment"); a.Parent=glow
 local e=Instance.new("ParticleEmitter"); e.Texture="rbxasset://textures/particles/smoke_main.dds"; e.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(120,190,255))
 e.LightEmission=0.8; e.LightInfluence=0; e.Rate=0; e.Lifetime=NumberRange.new(0.5,0.9); e.Speed=NumberRange.new(1,2.2); e.SpreadAngle=Vector2.new(20,20)
 e.Acceleration=Vector3.new(0,2,0); e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*0.32),NumberSequenceKeypoint.new(1,size*0.05)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.35),NumberSequenceKeypoint.new(1,1)}); e.EmissionDirection=Enum.NormalId.Right; e.Parent=a
 e:Emit(math.floor(8+size*6))
end
function Sig.coldEyes(model)
 local head=model:FindFirstChild("Head"); if not head or head:FindFirstChild("ColdFireEyeL") then return end
 local sx,sy,sz=head.Size.X,head.Size.Y,head.Size.Z
 for _,side in {{"L",-1},{"R",1}} do
  -- the eye slits: his head part includes the horns, so they sit below its centre
  local a=Instance.new("Attachment"); a.Name="ColdFireEye"..side[1]; a.Position=Vector3.new(side[2]*sx*0.095,-sy*0.125,-sz*0.52); a.Parent=head
  -- smoke_main is grayscale and takes the tint; the fire texture is orange and reads warm
  local e=Instance.new("ParticleEmitter"); e.Name="ColdFire"; e.Texture="rbxasset://textures/particles/smoke_main.dds"
  e.Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(120,190,255)); e.LightEmission=1; e.LightInfluence=0; e.Brightness=3; e.Rate=40 -- Brightness: reads in daylight over the helmet's green glow
  e.Lifetime=NumberRange.new(0.3,0.5); e.Speed=NumberRange.new(0.5,1.1); e.SpreadAngle=Vector2.new(8,8); e.Acceleration=Vector3.new(0,2.5,0)
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.16),NumberSequenceKeypoint.new(1,0.02)})
  local core=Instance.new("ParticleEmitter"); core.Name="ColdFireCore"; core.Texture="rbxasset://textures/particles/sparkles_main.dds"
  core.Color=ColorSequence.new(Color3.new(1,1,1)); core.LightEmission=1; core.LightInfluence=0; core.Brightness=5; core.Rate=24; core.Lifetime=NumberRange.new(0.15,0.25)
  core.Speed=NumberRange.new(0,0.1); core.Size=NumberSequence.new(0.09); core.Parent=a
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(1,1)}); e.EmissionDirection=Enum.NormalId.Top; e.Parent=a
 end
 local l=Instance.new("PointLight"); l.Name="ColdFireEyeLight"; l.Color=Sig.COLD; l.Brightness=1.6; l.Range=5; l.Parent=head
end
-- V60b (Peter: "hand grip sword grip wrong not in a fist", "his rig need to be two handed sword attacks"): his hands are
-- Blender-curled fists welded over the hidden open claws (build_v60.py). Something that fades or shows his parts sets
-- the hand's Transparency; the fist takes that value and the claw goes back to hidden.
function Sig.fistHands(model)
 for _,side in {"Right","Left"} do
  local hand=model:FindFirstChild(side.."Hand"); local fist=model:FindFirstChild(side.."Fist")
  if hand and fist and hand.Transparency<1 then fist.Transparency=hand.Transparency; hand.Transparency=1 end
 end
end
function Sig.arc(u,v) -- the rotation turning unit vector u onto v
 local c=u:Dot(v)
 if c>0.99999 then return CFrame.identity end
 if c<-0.99999 then local ax=u:Cross(Vector3.xAxis); if ax.Magnitude<1e-3 then ax=u:Cross(Vector3.yAxis) end; return CFrame.fromAxisAngle(ax.Unit,math.pi) end
 return CFrame.fromAxisAngle(u:Cross(v).Unit,math.acos(c))
end
-- The Great Sword captures hold the hilt in both hands, but retargeted onto his longer arms the left hand drifts off it in
-- the fast swings, so after each frame's pose the left arm is solved (two-bone IK, elbow kept on the captured side) to
-- put the left fist on the sword at LeftGripY. Where a wide swing takes the hilt beyond the left arm's reach (about 1 frame
-- in 10), the sword and right arm are first pulled in toward the left shoulder by the shortfall. Death Grip throws that
-- hand out, so it is left alone there.
Sig.armJoints=setmetatable({},{__mode="k"})
function Sig.solveArm(sh,el,wr,H,world) -- shoulder, elbow, wrist motors; H = the hand's wanted world CFrame
 local UT=world(sh.Part0); local J0=UT*sh.C0; local S=J0.Position
 local W=(H*wr.C1).Position
 local a=(el.C0.Position-sh.C1.Position).Magnitude; local b=(wr.C0.Position-el.C1.Position).Magnitude
 local d=W-S; local dist=d.Magnitude; if dist<1e-3 then return end
 local dir=d/dist; local r=math.clamp(dist,math.abs(a-b)+0.02,a+b-0.02)
 local UA=world(sh.Part1); local Ecur=(UA*el.C0).Position
 local pole=(Ecur-S)-dir*(Ecur-S):Dot(dir)
 if pole.Magnitude<1e-3 then pole=-UT.UpVector-dir*(-UT.UpVector):Dot(dir) end
 pole=pole.Unit
 local x=(a*a-b*b+r*r)/(2*r); local E=S+dir*x+pole*math.sqrt(math.max(a*a-x*x,0))
 local UAr=Sig.arc(((UA*el.C0).Position-(UA*sh.C1).Position).Unit,(E-S).Unit)*UA.Rotation
 local UAn=CFrame.new(S-UAr:VectorToWorldSpace(sh.C1.Position))*UAr
 sh.Transform=J0:Inverse()*UAn*sh.C1
 local J1=UAn*el.C0; local E1=J1.Position
 local LA=J1*el.Transform*el.C1:Inverse()
 local LAr=Sig.arc(((LA*wr.C0).Position-(LA*el.C1).Position).Unit,(S+dir*r-E1).Unit)*LA.Rotation
 local LAn=CFrame.new(E1-LAr:VectorToWorldSpace(el.C1.Position))*LAr
 el.Transform=J1:Inverse()*LAn*el.C1
 local J2=LAn*wr.C0
 wr.Transform=J2:Inverse()*CFrame.new(J2.Position-H.Rotation:VectorToWorldSpace(wr.C1.Position))*H.Rotation*wr.C1
end
function Sig.twoHand(model,motors,p)
 if p and (p.name=="DeathGrip" or p.name=="Pin") then return end
 local sword=model:FindFirstChild("Greatsword"); local gy=sword and sword:FindFirstChild("LeftGripY"); local gf=model:FindFirstChild("LeftGripFrame")
 local sh,el,wr=motors.LeftShoulder,motors.LeftElbow,motors.LeftWrist
 local weld=sword and sword:FindFirstChild("GreatswordWeld"); local root=model:FindFirstChild("HumanoidRootPart")
 if not (gy and gf and sh and el and wr and weld and weld.Part0 and root and sh.Part0 and sh.Part1 and el.Part1) then return end
 -- world frames from the root through the joints as posed this frame (part CFrames only follow Transform a step later)
 local byPart=Sig.armJoints[model]
 if not byPart then byPart={}; for _,m in motors do if m.Part1 then byPart[m.Part1]=m end end; Sig.armJoints[model]=byPart end
 local cache={}
 local function world(part)
  if part==root then return root.CFrame end
  if cache[part] then return cache[part] end
  local m=byPart[part]; local c=(m and m.Part0) and world(m.Part0)*m.C0*m.Transform*m.C1:Inverse() or part.CFrame
  cache[part]=c; return c
 end
 local Hr=world(weld.Part0)
 local H=Hr*weld.C0*weld.C1:Inverse()*CFrame.new(0,gy.Value,0)*gf.Value:Inverse() -- the left hand on the hilt
 local S=(world(sh.Part0)*sh.C0).Position; local W=(H*wr.C1).Position
 local reach=((el.C0.Position-sh.C1.Position).Magnitude+(wr.C0.Position-el.C1.Position).Magnitude)*0.96
 local over=(W-S).Magnitude-reach
 local rs,re,rw=motors.RightShoulder,motors.RightElbow,motors.RightWrist
 if over>0 and rs and re and rw and rs.Part0 and rs.Part1 and re.Part1 then
  local shift=(S-W).Unit*over
  Sig.solveArm(rs,re,rw,Hr+shift,world)
  H=H+shift
 end
 Sig.solveArm(sh,el,wr,H,world)
end
Sig.LOOPS={Wraithstep={idle="idle",run="run"},Solarion={idle="idle"},Tempest={idle="idle"},Valkyra={idle="idle",run="run"},DreadKnight={idle="idle",run="run"}}
function Sig.mocapName(model,p,state)
 local hero=string.lower(Sig.heroOf(model))
 if p then
  if p.name=="Hurt" then return p.react and Sig.MOCAP_REACT[p.react] or "hit_head" end
  if p.name=="Pin" then return "hit_knockdown" end
  local o=Sig.MOCAP_OVERRIDE[Sig.heroOf(model)]; if o and o[p.name] then return o[p.name] end
  local nm=Sig.alias(Sig.heroOf(model),p.name)
  return hero.."_"..(Sig.MOCAP_FILE[nm] or string.lower(nm))
 end
 return state and hero.."_"..state or nil
end
function Sig.mocapTrack(model,name)
 local cache=Sig.mocapCache[model]; if not cache then cache={}; Sig.mocapCache[model]=cache end
 if cache[name]~=nil then return cache[name] or nil end
 cache[name]=false
 local id=Sig.mocapId(name)
 local hum=model:FindFirstChildOfClass("Humanoid")
 if not id or not hum then return nil end
 local animator=hum:FindFirstChildOfClass("Animator") or Instance.new("Animator",hum)
 local anim=Instance.new("Animation"); anim.AnimationId=id
 local ok,track=pcall(function() return animator:LoadAnimation(anim) end)
 if not ok then return nil end
 track.Priority=Enum.AnimationPriority.Action4
 cache[name]=track
 return track
end
-- Every frame for every fighter: true while a capture is playing its current move or loop.
function Sig.mocap(model,p,state,now,rate,force)
 if not Sig.mocapFolder then return false end
 local name=(p or state) and Sig.mocapName(model,p,state) or nil
 local cur=Sig.mocapNow[model]
 -- V54b: a bare call (nothing requested, no rate) used to stop the running ground loop every frame, and the ground-loop branch restarted it from 0 (frozen legs).
 -- A running loop now survives it unless a hand-made pose (force) takes over; the ground-loop call itself (rate~=nil) still stops what it does not want.
 if cur and (cur.name~=name or cur.p~=p) and not (name==nil and rate==nil and cur.loop and not force) then cur.track:Stop(0.12); Sig.mocapNow[model]=nil; cur=nil end
 if not name then return false end
 if not cur then
  local track=Sig.mocapTrack(model,name)
  if not track then return false end
  track.Looped=p==nil
  track:Play(0.06)
  cur={name=name,p=p,track=track,loop=(rate~=nil)}; Sig.mocapNow[model]=cur -- V54b: loop flag
 end
 local track=cur.track
 if not cur.speed and track.Length>0 then
  -- v37: the capture's "Hit" keyframe (where a hand or foot is furthest out) lands on the move's hit
  -- frames: played at up to 3x, starting part-way in if the capture has a long lead-in.
  local start=0
  local ok,th=pcall(function() return track:GetTimeOfKeyframe("Hit") end)
  if p and p.move and ok and th and th>0 then
   local impact=(p.move.Startup+p.move.Active*0.5)/60
   cur.speed=math.clamp(th/impact,0.5,3); start=math.max(0,th-cur.speed*impact)
  else
   local dur=p and (p.move and (p.move.Startup+p.move.Active+p.move.Recovery+(p.extra or 0))/60 or p.dur)
   cur.speed=dur and dur>0 and math.clamp(track.Length/dur,0.5,3) or 1
  end
  track:AdjustSpeed(cur.speed)
  if p then track.TimePosition=math.clamp(start+(now-p.start)*cur.speed,0,track.Length-0.05) end
 end
 -- v50: a ground loop is paced to the fighter's speed.
 if not p and rate and cur.rate~=rate then cur.rate=rate; track:AdjustSpeed(rate) end
 if p and p.holdUntil and now<p.holdUntil then
  if not cur.frozen then cur.frozen=true; track:AdjustSpeed(0) end
 elseif cur.frozen then cur.frozen=false; track:AdjustSpeed(cur.held and 0 or cur.speed or 1) end
 -- Hold the last frame (instead of snapping to a T-pose) if the capture ends before the move does.
 if p and not cur.held and cur.speed and track.Length>0 and track.TimePosition>=track.Length-0.06 then cur.held=true; track:AdjustSpeed(0) end
 return true
end
-- v40: captures ship as numbers (ReplicatedStorage.HeroWars.MocapData) instead of thousands of Pose
-- objects, which made the place take minutes to open. Each KeyframeSequence is built here once.
Sig.MOCAP_PARENT={LowerTorso="HumanoidRootPart",UpperTorso="LowerTorso",Head="UpperTorso",
 LeftUpperArm="UpperTorso",LeftLowerArm="LeftUpperArm",LeftHand="LeftLowerArm",
 RightUpperArm="UpperTorso",RightLowerArm="RightUpperArm",RightHand="RightLowerArm",
 LeftUpperLeg="LowerTorso",LeftLowerLeg="LeftUpperLeg",LeftFoot="LeftLowerLeg",
 RightUpperLeg="LowerTorso",RightLowerLeg="RightUpperLeg",RightFoot="RightLowerLeg"}
function Sig.mocapBuild(name)
 local data=Sig.mocapData; local s=data and data[name]
 if type(s)~="string" then return nil end
 local v=string.split(s," "); local i=1
 local function nx() local x=tonumber(v[i]) or 0; i+=1; return x end
 local kfs=Instance.new("KeyframeSequence"); kfs.Name=name
 kfs.Loop=nx()==1; kfs.Priority=Enum.AnimationPriority.Action
 local hit,n=nx(),nx()
 for k=0,n-1 do
  local kf=Instance.new("Keyframe"); kf.Time=nx(); kf.Name=k==hit and "Hit" or "Keyframe"
  local rootY=nx()
  local poses={HumanoidRootPart=Instance.new("Pose")}
  poses.HumanoidRootPart.Name="HumanoidRootPart"; poses.HumanoidRootPart.Weight=1
  for _,j in data.JOINTS do
   local qx,qy,qz,qw=nx(),nx(),nx(),nx()
   local pose=Instance.new("Pose"); pose.Name=j; pose.Weight=1
   pose.CFrame=CFrame.new(0,j=="LowerTorso" and rootY or 0,0,qx,qy,qz,qw)
   poses[j]=pose
  end
  for _,j in data.JOINTS do poses[j].Parent=poses[Sig.MOCAP_PARENT[j]] end
  poses.HumanoidRootPart.Parent=kf
  kf.Parent=kfs
 end
 return kfs
end
function Sig.mocapId(name)
 local id=Sig.mocapIds[name]
 if id==nil then
  local ok,res=pcall(function()
   local kfs=Sig.mocapBuild(name)
   if not kfs then return false end
   return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs)
  end)
  id=ok and res or false; Sig.mocapIds[name]=id
  if not ok then warn("[HeroWars] capture "..name.." could not load: "..tostring(res)) end
 end
 return id or nil
end
do
 local mod=RS.HeroWars:FindFirstChild("MocapData")
 local ok,data=pcall(function() return mod and require(mod) end)
 if ok and type(data)=="table" and data.JOINTS then
  Sig.mocapData=data; Sig.mocapFolder=true
  -- Warm up in the background, one capture per frame, so the first use of a move doesn't hitch.
  task.spawn(function()
   for name in data do if name~="JOINTS" then Sig.mocapId(name); task.wait() end end
  end)
 elseif mod then warn("[HeroWars] MocapData failed to load: "..tostring(data)) end
end
local function involvesMe(...) for _,m in {...} do if m and m==player.Character then return true end end return false end
-- Aim telegraph: during wind-up an arrow grows from the caster along the committed aim
-- (which points at the current target when one is selected), so everyone sees where it will land.
local function flatDir(v) local f=Vector3.new(v.X,0,v.Z); return f.Magnitude>0.01 and f.Unit or Vector3.new(0,0,-1) end
local function reachAlong(model,origin,dir,range)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={model,fxFolder}
 local ray=workspace:Raycast(origin,dir*range,params)
 return ray and ray.Position or origin+dir*range
end
local aimLines={}
RunService.RenderStepped:Connect(function()
 local now=os.clock()
 for i=#aimLines,1,-1 do
  local a=aimLines[i]
  if now>a.expires or not a.root.Parent or not a.alive() then
   a.shaft:Destroy(); a.tip:Destroy(); table.remove(aimLines,i)
  else
   local t=math.clamp((now-a.born)/a.duration,0,1)
   local start=a.root.Position+a.offset
   local len=math.max(0.5,a.length*(0.3+0.7*t))
   local finish=start+a.dir*len
   local w=0.15+0.15*t
   a.shaft.Size=Vector3.new(w,w,len); a.shaft.CFrame=CFrame.lookAt((start+finish)/2,finish)
   a.shaft.Transparency=0.6-0.35*t
   a.tip.CFrame=CFrame.lookAt(finish,finish+a.dir)*CFrame.Angles(0,math.pi/4,0)
   a.tip.Transparency=0.5-0.4*t
  end
 end
end)
local function telegraph(root,dir,length,color,duration,alive,offset)
 if duration<=0 or length<=0.5 then return end
 local shaft=fxPart(Enum.PartType.Block,Vector3.new(0.15,0.15,1),root.CFrame,color,0.6)
 local tip=fxPart(Enum.PartType.Block,Vector3.new(1.1,0.15,1.1),root.CFrame,color,0.5)
 table.insert(aimLines,{root=root,dir=dir,length=length,shaft=shaft,tip=tip,born=os.clock(),duration=duration,
  expires=os.clock()+duration,alive=alive,offset=offset or Vector3.new(0,0.6,0)})
end
-- Move a part from one CFrame to another, fading as it goes.
local function travel(p,toCFrame,duration,toSize)
 local goal={CFrame=toCFrame}; if toSize then goal.Size=toSize end
 TweenService:Create(p,TweenInfo.new(duration,Enum.EasingStyle.Linear),goal):Play()
 task.delay(duration*0.6,function() if p.Parent then fadeOut(p,duration*0.6) end end)
 Debris:AddItem(p,duration*1.3+0.1)
end
-- R22 (Peter: "no shadow circle fx asset or animation"): the cast now draws the circle. A purple ring spreads
-- from his hands across the floor for the whole cast, dark smoke boils round him and rune sparks rise
-- from the rim into his hands; when it closes the ring flashes and a wave of shadow rolls out.
function Sig.circleCast(model,root,move,startup,still)
 local acc=Color3.fromRGB(160,85,235)
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={model,fxFolder}
 local floor=workspace:Raycast(root.Position,Vector3.new(0,-60,0),params)
 local center=floor and floor.Position+Vector3.new(0,0.06,0) or root.Position-Vector3.new(0,3,0)
 local radius=move.Radius or 10
 local flat=CFrame.new(center)*CFrame.Angles(0,0,math.pi/2)
 local rim=fxPart(Enum.PartType.Cylinder,Vector3.new(0.06,1,1),flat,acc,0.25)
 local pool=fxPart(Enum.PartType.Cylinder,Vector3.new(0.05,1,1),flat*CFrame.new(-0.01,0,0),Color3.fromRGB(20,8,32),0.3,Enum.Material.SmoothPlastic)
 TweenService:Create(rim,TweenInfo.new(startup,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(0.06,radius*2,radius*2)}):Play()
 TweenService:Create(pool,TweenInfo.new(startup,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(0.05,radius*2-0.6,radius*2-0.6)}):Play()
 local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,CFrame.new(center+Vector3.new(0,0.5,0)),Color3.new(),1)
 local att=Instance.new("Attachment"); att.Parent=holder; local smoke=shadowSmoke(att,40)
 local light=Instance.new("PointLight"); light.Color=acc; light.Range=4; light.Brightness=3; light.Parent=holder
 TweenService:Create(light,TweenInfo.new(startup),{Range=radius*1.5}):Play()
 local step=0.12
 for i=1,math.floor(startup/step) do
  task.delay(i*step,function()
   if not still() then return end
   local r=radius*math.min(1,i*step/startup); local a=math.random()*math.pi*2
   local from=center+Vector3.new(math.cos(a)*r,0.2,math.sin(a)*r)
   local hand=model:FindFirstChild(i%2==0 and "LeftHand" or "RightHand")
   local spark=fxPart(Enum.PartType.Block,Vector3.new(0.25,0.6,0.25),CFrame.new(from),acc,0.1)
   travel(spark,hand and hand.CFrame or CFrame.new(root.Position),0.35,Vector3.new(0.1,0.25,0.1))
  end)
 end
 task.delay(startup,function()
  smoke.Enabled=false; Debris:AddItem(holder,1)
  if not still() then fadeOut(rim,0.2); fadeOut(pool,0.2); return end
  smoke:Emit(45)
  rim.Transparency=0; fadeOut(rim,0.5,{Size=Vector3.new(0.06,radius*2.6,radius*2.6)})
  fadeOut(pool,0.6)
  ring(center+Vector3.new(0,0.3,0),Color3.fromRGB(60,20,90),radius*3,0.45)
  burst(root.Position,acc,5,0.3)
  Sig.play({"portal",0.6,0.7},root); Sig.play({"ghost",0.5,0.8},root)
 end)
end
local function playMove(model,name,aim,landing)
 local move=heroMoveOf(model,name); local root=model and model:FindFirstChild("HumanoidRootPart")
 local hero=model and model:GetAttribute("Hero")
 if not move or not root or typeof(aim)~="Vector3" or aim.Magnitude<0.5 then return end
 aim=aim.Unit
 local accent=heroAccent(model,name); local startup=move.Startup/60
 local token=poses[model]
 -- v36: time the effects from when the pose began (my own moves start on the press, others are aligned).
 if token and token.name==name then startup=math.max(0.02,startup-(os.clock()-token.start)) end
 -- Skip the payoff if the attack was interrupted (the target was hit or parried).
 local function still() return poses[model]==token and root.Parent~=nil end
 PowerFX.attack(model,name,aim,move,startup,still)
 -- R17 (R16 audit 4): long casts build up glow in both hands for the whole cast, so the wind-up reads.
 if move.Cast and startup>0.5 then
  local acc=heroAccent(model,name)
  charge(model,"RightHand",acc,startup,1.4); charge(model,"LeftHand",acc,startup,1.4)
  local step=0.25
  for i=1,math.floor(startup/step) do
   task.delay(i*step,function()
    if not still() then return end
    local hand=model:FindFirstChild(i%2==0 and "LeftHand" or "RightHand"); if not hand then return end
    burst(hand.Position,acc,0.6+1.4*(i*step/startup),0.18)
   end)
  end
 end
 -- v34: this hero's own sounds for this move (charge now, the swing or cast at release).
 local heavyMove=name=="Heavy" or move.Startup>=14
 Sig.sound(model,name,"charge",root)
 task.delay(startup,function() if still() then Sig.sound(model,name,"cast",root,heavyMove) end end)
 if name=="ShadowCircle" and Sig.circleCast then Sig.circleCast(model,root,move,startup,still) end
 -- R17 (Peter: Wraithstep lost his grapple bats and shadow): Grapple keeps its own shroud, bats and chain.
 if PowerFX and name~="Grapple" then return end -- unified, interrupt-aware effects own move presentation
 local dir=flatDir(aim)
 -- A point `dist` studs along the flat aim, `height` above the root.
 local function along(dist,height)
  local p=root.Position+dir*dist+Vector3.new(0,height or 0,0)
  return CFrame.lookAt(p,p+dir)
 end
 if name=="Light1" or name=="Light2" or name=="Light3" then
  -- v28: every hero's combo looks different (Peter: "the power visuals are all the same").
  telegraph(root,dir,move.Range,accent,startup,still)
  local step=name=="Light1" and 1 or name=="Light2" and 2 or 3
  task.delay(startup,function()
   if not still() then return end
   local tilt=step==1 and 0.5 or step==2 and -0.5 or 0
   if hero=="Wraithstep" then
    -- Shadow claws: three thin parallel rakes and a puff of smoke.
    for i=-1,1 do
     local off=Vector3.new(0,i*0.45,0)
     local p=fxPart(Enum.PartType.Block,Vector3.new(3.2,0.08,0.25),along(1.5,0.4)*CFrame.new(off)*CFrame.Angles(0,0,tilt*1.4),accent,0.15)
     travel(p,along(move.Range-0.5,0.4)*CFrame.new(off)*CFrame.Angles(0,0,tilt*1.4),0.09,Vector3.new(4.2,0.05,0.2))
    end
    local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,along(move.Range-1,0.4),Color3.new(),1)
    local att=Instance.new("Attachment"); att.Parent=holder; shadowSmoke(att,0):Emit(step==3 and 14 or 6)
    Debris:AddItem(holder,1.2)
   elseif hero=="Tempest" then
    -- Static: a short jagged spark from the hand to the end of the reach.
    local a=along(1.2,0.5).Position; local b=along(move.Range,0.5).Position; local span=b-a
    local side=span.Unit:Cross(Vector3.yAxis); side=side.Magnitude>0.1 and side.Unit or Vector3.xAxis
    local last=a
    for i=1,4 do
     local nxt=i==4 and b or a+span*(i/4)+side*(math.random()-0.5)*0.9+Vector3.new(0,(math.random()-0.5)*0.9,0)
     fadeOut(fxPart(Enum.PartType.Block,Vector3.new(0.16,0.16,(nxt-last).Magnitude),CFrame.lookAt((last+nxt)/2,nxt),i%2==0 and Color3.new(1,1,1) or accent,0),0.16)
     last=nxt
    end
    burst(b,Color3.new(1,1,1),1.6,0.12)
   elseif hero=="Bulwark" then
    -- Bronze: the shield rim (jab, cross) or the boot (kick) shoves forward with metal sparks.
    local disc=fxPart(Enum.PartType.Cylinder,Vector3.new(0.3,2.8,2.8),along(1.5,0.3)*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(205,150,70),0.25,Enum.Material.Metal)
    travel(disc,along(move.Range-0.5,0.3)*CFrame.Angles(0,math.pi/2,0),0.12,Vector3.new(0.3,step==3 and 4 or 3.4,step==3 and 4 or 3.4))
    task.delay(0.12,function() burst(along(move.Range-0.5,0.3).Position,Color3.fromRGB(255,230,170),2.2,0.15) end)
   else
    -- Solarion: a golden arc that ends in a small sunburst.
    local size=Vector3.new(step==3 and 6 or 4.5,0.25,0.8)
    local p=fxPart(Enum.PartType.Block,size*Vector3.new(1,0.6,0.6),along(1.5,0.4)*CFrame.Angles(0,0,tilt),accent,0.35)
    travel(p,along(move.Range-1,0.4)*CFrame.Angles(0,0,tilt),0.12,size*Vector3.new(1.3,1,1))
    task.delay(0.12,function()
     local tip=along(move.Range-0.5,0.4).Position
     burst(tip,Color3.fromRGB(255,240,190),1.8+step*0.4,0.15); ring(tip,accent,2+step,0.2)
    end)
   end
  end)
 elseif name=="Throw" then
  telegraph(root,dir,move.Range,Color3.fromRGB(255,170,220),startup,still)
  task.delay(startup,function()
   if not still() then return end
   ring(along(2.5,-2.5).Position,Color3.fromRGB(255,170,220),5,0.25)
  end)
 elseif name=="TitanDrop" then
  -- Both hands reach out to grab; a bronze ring marks the grab.
  telegraph(root,dir,move.Range,Color3.fromRGB(230,170,80),startup,still)
  charge(model,"LeftHand",accent,startup,1); charge(model,"RightHand",accent,startup,1)
  task.delay(startup,function()
   if not still() then return end
   ring(along(2.5,-2.5).Position,Color3.fromRGB(230,170,80),6,0.3)
  end)
 elseif name=="Whirlwind" then
  -- A funnel of wind spins up at the end of the reach.
  charge(model,"LeftHand",accent,startup,1); charge(model,"RightHand",accent,startup,1)
  local reach=reachAlong(model,root.Position,aim,move.Range)
  telegraph(root,aim,(reach-root.Position).Magnitude,accent,startup,still,Vector3.new(0,0.8,0))
  -- R42: the funnel itself comes from the server's WhirlCast (it flies to whoever it locked onto).
 elseif name=="SolarFlare" then
  charge(model,"UpperTorso",accent,startup,3)
  ring(groundBelow(model,root)+Vector3.new(0,0.1,0),accent,4,startup)
 elseif name=="ShadowDoor" or name=="DimensionDoor" then
  -- Wind-up only; the doors themselves appear on the server's Teleport effect.
  local c=name=="ShadowDoor" and accent or Color3.fromRGB(150,200,255)
  local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,root.CFrame,Color3.new(),1)
  local att=Instance.new("Attachment"); att.Parent=holder
  if name=="ShadowDoor" then shadowSmoke(att,0):Emit(30)
  else emitter(att,c,{Rate=0,Lifetime=NumberRange.new(0.3,0.5),Speed=NumberRange.new(-8,-4),SpreadAngle=Vector2.new(180,180),
   Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.7),NumberSequenceKeypoint.new(1,0)})}):Emit(40) end
  Debris:AddItem(holder,1.5)
  ring(groundBelow(model,root)+Vector3.new(0,0.1,0),c,6,startup)
 elseif name=="Heavy" then
  charge(model,"RightHand",accent,startup,1.8)
  telegraph(root,dir,move.Range,accent,startup,still)
  task.delay(startup,function()
   if not still() then return end
   if hero=="Wraithstep" then
    -- Grave Scythe: a wide reaping arc of shadow from one side to the other.
    for i=0,8 do
     task.delay(i*0.012,function()
      local ang=math.rad(-70+i*17.5)
      local d=CFrame.fromAxisAngle(Vector3.yAxis,ang):VectorToWorldSpace(dir)
      local pos=root.Position+d*(move.Range-1)+Vector3.new(0,0.5,0)
      fadeOut(fxPart(Enum.PartType.Block,Vector3.new(0.25,2.2,1.6),CFrame.lookAt(pos,pos+d),accent,0.15),0.25)
     end)
    end
    local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,along(move.Range-1,0),Color3.new(),1)
    local att=Instance.new("Attachment"); att.Parent=holder; shadowSmoke(att,0):Emit(20); Debris:AddItem(holder,1.2)
   elseif hero=="Tempest" then
    -- Storm Fist: a wind spiral down the reach and a bolt striking the far end.
    for i=0,4 do
     task.delay(i*0.03,function()
      local p=fxPart(Enum.PartType.Cylinder,Vector3.new(0.15,2,2),along(1.5+i*1.6,0.5)*CFrame.Angles(0,math.pi/2,0),Color3.new(0.9,0.97,1),0.35)
      fadeOut(p,0.25,{Size=Vector3.new(0.15,4+i,4+i)})
     end)
    end
    local tip=along(move.Range,0).Position
    beamBetween(tip+Vector3.new(0,14,0),tip,accent,0.5,0.2); burst(tip,Color3.new(1,1,1),5,0.25)
   elseif hero=="Bulwark" then
    -- Titan Cleave: a bronze sword arc from overhead down into the floor, which cracks.
    for i=0,6 do
     task.delay(i*0.014,function()
      local ang=math.rad(80-i*25)
      local pos=root.Position+dir*(2+math.cos(ang)*(move.Range-2))+Vector3.new(0,math.sin(ang)*(move.Range-2),0)
      fadeOut(fxPart(Enum.PartType.Block,Vector3.new(0.3,1.2,1.4),CFrame.lookAt(pos,pos+dir),Color3.fromRGB(235,190,110),0.1,Enum.Material.Metal),0.3)
     end)
    end
    task.delay(0.1,function()
     local g=groundBelow(model,root)+dir*(move.Range-1.5)
     ring(g+Vector3.new(0,0.1,0),Color3.fromRGB(170,165,150),9,0.45); burst(g,accent,4,0.25)
    end)
   else
    -- Solar Hammer: a rolling shockwave and a small sun at the end of it.
    local w=fxPart(Enum.PartType.Cylinder,Vector3.new(0.6,4,4),along(1.5,0)*CFrame.Angles(0,math.pi/2,0),accent,0.35)
    travel(w,along(move.Range,0)*CFrame.Angles(0,math.pi/2,0),0.16,Vector3.new(0.6,7,7))
    task.delay(0.16,function()
     local front=along(move.Range-1,0).Position
     ring(front-Vector3.new(0,2.6,0),accent,8,0.3); burst(front,Color3.fromRGB(255,235,170),5,0.3)
    end)
   end
  end)
 elseif name=="Beam" then
  local hand=model:FindFirstChild("RightHand") or root
  local reach=reachAlong(model,root.Position,aim,move.Range)
  telegraph(root,aim,(reach-root.Position).Magnitude,accent,startup,still,Vector3.new(0,0.8,0))
  -- Charge: sparks are sucked into the hand while the orb grows.
  local chargePart,chargeAtt=anchorPoint(hand.CFrame)
  table.insert(followers,{part=chargePart,target=hand,expires=os.clock()+startup})
  emitter(chargeAtt,accent,{Rate=90,Lifetime=NumberRange.new(0.2,0.35),Speed=NumberRange.new(-9,-5),
   SpreadAngle=Vector2.new(180,180),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.6),NumberSequenceKeypoint.new(1,0)})})
  Debris:AddItem(chargePart,startup+0.05)
  charge(model,"RightHand",accent,startup,2)
  task.delay(startup,function()
   if not still() then return end
   local start=hand.Position
   local finish=reachAlong(model,root.Position,aim,move.Range)
   if (finish-start).Magnitude<0.2 then return end
   local hold=0.4; local flight=0.1
   -- The beam's head races from the hand to the target, then the full beam holds and thins out.
   local startPart,a0=anchorPoint(CFrame.lookAt(start,finish))
   local endPart,a1=anchorPoint(CFrame.new(start))
   table.insert(followers,{part=startPart,target=hand,expires=os.clock()+hold})
   TweenService:Create(endPart,TweenInfo.new(flight,Enum.EasingStyle.Linear),{CFrame=CFrame.new(finish)}):Play()
   local head=fxPart(Enum.PartType.Ball,Vector3.one*1.8,CFrame.new(start),Color3.new(1,1,1),0)
   travel(head,CFrame.new(finish),flight,Vector3.one*2.4)
   local outer=texturedBeam(a0,a1,accent,2.6,6,4)
   local inner=texturedBeam(a0,a1,Color3.new(1,1,1),1,10,2)
   task.delay(flight,function()
    for _,b in {outer,inner} do
     TweenService:Create(b,TweenInfo.new(hold-flight,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Width0=0,Width1=0}):Play()
    end
    beamBetween(start,finish,accent,0.6,hold-flight)
    local impact=emitter(a1,accent,{Rate=0,Lifetime=NumberRange.new(0.3,0.6),Speed=NumberRange.new(14,26),Drag=4,
     SpreadAngle=Vector2.new(180,180),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.9),NumberSequenceKeypoint.new(1,0)})})
    impact:Emit(40)
    burst(finish,accent,6,0.35); ring(finish,accent,7,0.35)
   end)
   Debris:AddItem(startPart,hold+0.1); Debris:AddItem(endPart,hold+0.7)
   -- Muzzle ring facing down the beam.
   fadeOut(fxPart(Enum.PartType.Cylinder,Vector3.new(0.2,1,1),CFrame.lookAt(start,finish)*CFrame.Angles(0,math.pi/2,0),accent,0.2),0.3,{Size=Vector3.new(0.2,5,5)})
  end)
 elseif name=="Grapple" then
  local hand=model:FindFirstChild("LeftHand") or root
  local reach=reachAlong(model,root.Position,aim,move.Range)
  -- Shroud of shadows: smoke wells up round Wraithstep and two bat demons wheel out of it.
  do
   local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,root.CFrame,Color3.new(),1)
   local att=Instance.new("Attachment"); att.Parent=holder
   local shroud=shadowSmoke(att,0); shroud.Speed=NumberRange.new(2,5); shroud:Emit(40)
   table.insert(followers,{part=holder,target=root,expires=os.clock()+startup+0.3})
   Debris:AddItem(holder,startup+1)
   local pair={}
   for i=1,2 do
    local b=makeBat(accent); b.phase=i*math.pi
    setMode(b,{kind="orbit",root=root}); table.insert(bats,b); table.insert(pair,b)
   end
   grappleBats[model]=pair
   task.delay(startup,function()
    if grappleBats[model]~=pair then return end
    local target=reachAlong(model,root.Position,aim,move.Range)
    for i,b in pair do
     if b.dead then continue end
     local side=root.CFrame.RightVector*(i==1 and -1 or 1)
     setMode(b,{kind="fly",from=b.body.Position,to=target,dur=0.16,side=side,done=function(bat)
      -- Missed: hang a moment, then fly home and vanish.
      task.delay(0.25,function()
       if bat.dead or bat.mode.kind=="latch" then return end
       setMode(bat,{kind="fly",from=bat.body.Position,to=root.Position+Vector3.new(0,2,0),dur=0.3,side=-side})
      end)
     end})
    end
    task.delay(1.2,function() if grappleBats[model]==pair then grappleBats[model]=nil end end)
   end)
  end
  telegraph(root,aim,(reach-root.Position).Magnitude,accent,startup,still,Vector3.new(0,0.8,0))
  charge(model,"LeftHand",accent,startup,1.2)
  task.delay(startup,function()
   if not still() then return end
   local start=hand.Position
   local finish=reachAlong(model,root.Position,aim,move.Range)
   local out=0.14; local back=0.22
   -- The chain shoots out to the target, latches, then reels back in.
   local startPart,a0=anchorPoint(CFrame.new(start))
   local endPart,a1=anchorPoint(CFrame.new(start))
   table.insert(followers,{part=startPart,target=hand,expires=os.clock()+out+back+0.1})
   local chain=texturedBeam(a0,a1,accent,0.6,-8,1.5)
   local hook=fxPart(Enum.PartType.Ball,Vector3.one*1,CFrame.new(start),accent,0)
   TweenService:Create(endPart,TweenInfo.new(out,Enum.EasingStyle.Linear),{CFrame=CFrame.new(finish)}):Play()
   TweenService:Create(hook,TweenInfo.new(out,Enum.EasingStyle.Linear),{CFrame=CFrame.new(finish)}):Play()
   task.delay(out,function()
    burst(finish,accent,3,0.25); ring(finish,accent,5,0.3)
    TweenService:Create(endPart,TweenInfo.new(back,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=startPart.CFrame}):Play()
    TweenService:Create(chain,TweenInfo.new(back),{Width0=0.2,Width1=0.2}):Play()
    fadeOut(hook,back,{CFrame=startPart.CFrame})
   end)
   Debris:AddItem(startPart,out+back+0.15); Debris:AddItem(endPart,out+back+0.15)
  end)
 elseif Rules.isPounce(name) then -- V59: Valkyrie Dive shows the same landing ring
  -- Crouch: a landing ring grows where Solarion will come down, then the leap leaves afterimages.
  local goal=typeof(landing)=="Vector3" and landing or root.Position+dir*16
  local floorAt=groundBelow(model,{Position=goal})
  telegraph(root,(goal-root.Position).Magnitude>0.5 and (goal-root.Position).Unit or dir,(goal-root.Position).Magnitude,accent,startup,still,Vector3.zero)
  local marker=fxPart(Enum.PartType.Cylinder,Vector3.new(0.15,2,2),CFrame.new(floorAt+Vector3.new(0,0.1,0))*CFrame.Angles(0,0,math.pi/2),accent,0.4)
  TweenService:Create(marker,TweenInfo.new(startup),{Size=Vector3.new(0.15,move.Splash*2,move.Splash*2)}):Play()
  Debris:AddItem(marker,startup+0.6)
  charge(model,"LowerTorso",accent,startup,2.5)
  task.delay(startup,function()
   if not still() then return end
   ring(groundBelow(model,root)+Vector3.new(0,0.1,0),Color3.fromRGB(200,190,170),7,0.3)
   afterimages(root,accent,8)
  end)
 elseif name=="JavelinOfLight" then
  -- V59 Valkyra: the throw line shows while the light spear forms in her hand (PowerFX draws the spear itself).
  telegraph(root,aim,(reachAlong(model,root.Position,aim,move.Range)-root.Position).Magnitude,accent,startup,still,Vector3.new(0,0.8,0))
  charge(model,"RightHand",accent,startup,1.4)
 elseif name=="Lightning" then
  -- Storm call: sparks gather above the raised hand, then a jagged bolt cracks to the target.
  local hand=model:FindFirstChild("RightHand") or root
  telegraph(root,aim,(reachAlong(model,root.Position,aim,move.Range)-root.Position).Magnitude,accent,startup,still,Vector3.new(0,0.8,0))
  charge(model,"RightHand",accent,startup,1.6)
  task.delay(startup,function()
   if not still() then return end
   local start=hand.Position
   local finish=reachAlong(model,root.Position,aim,move.Range)
   local span=finish-start
   if span.Magnitude<0.5 then return end
   local side=span.Unit:Cross(Vector3.yAxis); if side.Magnitude<0.1 then side=Vector3.xAxis end; side=side.Unit
   local up=side:Cross(span.Unit).Unit
   for pass=1,2 do
    local points={start}
    for i=1,7 do
     local k=i/8; local jitter=(pass==1 and 1.2 or 0.7)
     table.insert(points,start+span*k+side*(math.random()-0.5)*2*jitter+up*(math.random()-0.5)*2*jitter)
    end
    table.insert(points,finish)
    for i=1,#points-1 do
     local a,b=points[i],points[i+1]
     local seg=fxPart(Enum.PartType.Block,Vector3.new(pass==1 and 0.35 or 0.18,pass==1 and 0.35 or 0.18,(b-a).Magnitude),
      CFrame.lookAt((a+b)/2,b),pass==1 and accent or Color3.new(1,1,1),0)
     fadeOut(seg,0.22)
    end
   end
   burst(finish,accent,6,0.3); ring(finish,accent,7,0.3); burst(start,Color3.new(1,1,1),2.5,0.15)
  end)
 elseif name=="Gale" then
  -- A gust: swirling rings rush forward from the palms and spread.
  charge(model,"LeftHand",accent,startup,1); charge(model,"RightHand",accent,startup,1)
  telegraph(root,dir,move.Range,accent,startup,still)
  task.delay(startup,function()
   if not still() then return end
   for i=0,3 do
    task.delay(i*0.04,function()
     local from=along(1.5,0.6)
     local p=fxPart(Enum.PartType.Cylinder,Vector3.new(0.2,2.5,2.5),from*CFrame.Angles(0,math.pi/2,0),Color3.new(0.9,0.97,1),0.35)
     local to=along(move.Range,0.6+i*0.2)
     fadeOut(p,0.3,{CFrame=to*CFrame.Angles(0,math.pi/2,0),Size=Vector3.new(0.2,move.Width,move.Width)})
    end)
   end
   afterimages(root,accent,2)
  end)
 elseif name=="Slam" then
  -- Fists up, then the floor cracks: a shock ring and stone chunks thrown up around the impact.
  charge(model,"LeftHand",accent,startup,1.4); charge(model,"RightHand",accent,startup,1.4)
  telegraph(root,dir,move.Range,accent,startup,still)
  task.delay(startup,function()
   if not still() then return end
   local ground=groundBelow(model,root)+dir*3
   ring(ground+Vector3.new(0,0.1,0),accent,move.Width*1.6,0.45)
   ring(ground+Vector3.new(0,0.15,0),Color3.fromRGB(170,165,150),move.Width,0.6)
   burst(ground,accent,6,0.3)
   for i=1,8 do
    local a=i/8*math.pi*2
    local chunk=fxPart(Enum.PartType.Block,Vector3.one*(0.5+math.random()*0.5),CFrame.new(ground),Color3.fromRGB(90,92,100),0,Enum.Material.Slate)
    local out=ground+Vector3.new(math.cos(a),0,math.sin(a))*(3+math.random()*3)+Vector3.new(0,1.5+math.random()*2,0)
    fadeOut(chunk,0.6,{CFrame=CFrame.new(out)*CFrame.Angles(math.random()*3,math.random()*3,0)})
   end
   local me=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   if me and (me.Position-ground).Magnitude<30 then shake(1,0.35) end
  end)
 elseif name=="Charge" then
  -- Head down: a dust wake and afterimages along the run, then a shock at the shoulder.
  telegraph(root,dir,move.Range+move.Lunge,accent,startup,still)
  afterimages(root,accent,6)
  for i=0,5 do
   task.delay(i*startup/6,function()
    if not still() then return end
    burst(groundBelow(model,root)+Vector3.new(0,0.4,0),Color3.fromRGB(190,180,160),2.5,0.3)
   end)
  end
  task.delay(startup,function()
   if not still() then return end
   local hit=along(2.5,0.8).Position
   burst(hit,accent,5,0.25); ring(hit,accent,6,0.3)
  end)
 elseif name=="Uppercut" then
  charge(model,"RightHand",accent,startup,1.2)
  telegraph(root,dir,move.Range,accent,startup,still)
  task.delay(startup,function()
   if not still() then return end
   -- Pillar erupts where the aim lands and rises.
   local base=root.Position+dir*4-Vector3.new(0,2.5,0)
   local p=fxPart(Enum.PartType.Cylinder,Vector3.new(2,4,4),CFrame.new(base)*CFrame.Angles(0,0,math.pi/2),accent,0.25)
   fadeOut(p,0.35,{Size=Vector3.new(14,5,5),CFrame=CFrame.new(base+Vector3.new(0,7,0))*CFrame.Angles(0,0,math.pi/2)})
   ring(base+Vector3.new(0,0.1,0),accent,8,0.3)
  end)
 end
end
local function hitFx(target,result,damage,attacker,moveName,sweet,quiet)
 local root=target and target:FindFirstChild("HumanoidRootPart"); if not root then return end
 local from=attacker and attacker:FindFirstChild("HumanoidRootPart")
 -- Sparks fly where the blow lands: on the target's side facing the attacker.
 local toward=from and from.Position-root.Position or Vector3.zero
 toward=Vector3.new(toward.X,0,toward.Z); toward=toward.Magnitude>0.1 and toward.Unit or Vector3.zero
 local pos=root.Position+toward*1.1+Vector3.new(0,0.8,0)
 local heavy=damage>=12
 local accent=attacker and heroAccent(attacker) or Color3.fromRGB(255,200,90)
 if result=="Parry" then
  local c=Color3.fromRGB(110,230,255)
  ring(root.Position,c,10,0.35); burst(pos,c,5,0.3); popText(target,"PARRY!",c,30); Sig.play({"parry",0.7,1},root); Sig.play({"clang",0.5,1.4},root)
 elseif result=="Dodge" then
  popText(target,"DODGE",Color3.fromRGB(230,230,240))
 elseif result=="Absorb" then
  -- R41: the Solar Shield soaked the whole blow.
  burst(pos,Color3.fromRGB(255,205,100),3,0.2); popText(target,"ABSORB",Color3.fromRGB(255,215,110),22)
  Sig.sound(target,nil,"block",root)
 elseif result=="Block" then
  burst(pos,Color3.fromRGB(120,170,255),3,0.2); popText(target,"BLOCK -"..tostring(damage),Color3.fromRGB(150,190,255),20)
  Sig.sound(target,nil,"block",root)
 else
  local size=2.5+damage*0.25
  -- v34: the attacker's own impact (sun rays, shadow claws, lightning arcs, bronze sparks) and sound.
  Sig.hit(target,attacker,moveName,pos,toward,heavy,result=="GuardBreak" and Color3.fromRGB(255,140,60) or accent,size)
  if heavy or result=="Counter" then ring(pos,accent,size*2.5,0.3) end
  if not quiet then Sig.sound(attacker,moveName,"hit",root,heavy) end
  if result=="Counter" then popText(target,"COUNTER -"..tostring(damage),Color3.fromRGB(255,225,60),32)
  elseif result=="GuardBreak" then
   ring(pos,Color3.fromRGB(255,120,40),9,0.3)
   popText(target,"GUARD BREAK -"..tostring(damage),Color3.fromRGB(255,150,70),30)
  elseif result=="Throw" then popText(target,"THROW -"..tostring(damage),Color3.fromRGB(255,170,220),30)
  elseif sweet then popText(target,"CRUSH -"..tostring(damage),Color3.fromRGB(255,200,80),32)
  else popText(target,"-"..tostring(damage),heavy and Color3.fromRGB(255,210,70) or Color3.fromRGB(255,110,80),heavy and 32 or 24) end
 end
 if target==player.Character and damage>0 then
  hurtFlash.BackgroundTransparency=0.7
  TweenService:Create(hurtFlash,TweenInfo.new(0.35),{BackgroundTransparency=1}):Play()
 end
end
-- Shield while blocking and a glow under Solarion while flying, driven by server attributes.
local statusFx={}
local clearStatusFx
local function updateStatusFx(model,root)
 -- v29: a hidden fighter shows no shield, aura, stun timer or whirl rings either.
 if hiddenFromMe(model) then if statusFx[model] then clearStatusFx(model) end; return end
 local st=statusFx[model]; if not st then st={}; statusFx[model]=st end
 local blocking=model:GetAttribute("Blocking")==true
 if blocking and not st.shield then
  st.shield=fxPart(Enum.PartType.Cylinder,Vector3.new(0.3,5.5,5.5),root.CFrame,Color3.fromRGB(120,180,255),0.45,Enum.Material.ForceField)
 elseif not blocking and st.shield then st.shield:Destroy(); st.shield=nil end
 if st.shield then st.shield.CFrame=root.CFrame*CFrame.new(0,0.3,-1.8)*CFrame.Angles(0,math.pi/2,0) end
 local shieldedNow=model:GetAttribute("Shielded")==true
 if shieldedNow and not st.bubble then
  st.bubble=fxPart(Enum.PartType.Ball,Vector3.one*7,root.CFrame,heroAccent(model),0.6,Enum.Material.ForceField)
 elseif not shieldedNow and st.bubble then st.bubble:Destroy(); st.bubble=nil end
 if st.bubble then st.bubble.CFrame=root.CFrame end
 -- R47 Tempest's mist cloud: grey-white mist rolls round her while it lasts.
 local mistEnd=model:GetAttribute("MistEnd")
 local misty=mistEnd~=nil and mistEnd>workspace:GetServerTimeNow()
 if misty and not st.mist then
  local att=Instance.new("Attachment"); att.Name="MistCloud"; att.Position=Vector3.new(0,-1,0); att.Parent=root
  local e=emitter(att,Color3.fromRGB(225,232,240),{Rate=26,Lifetime=NumberRange.new(1,1.6),Speed=NumberRange.new(1,3),
   SpreadAngle=Vector2.new(180,30),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,2.5),NumberSequenceKeypoint.new(1,5)})})
  e.Texture=SMOKE_TEXTURE; e.LightEmission=0.1; e.RotSpeed=NumberRange.new(-60,60); e.Rotation=NumberRange.new(0,360)
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.55),NumberSequenceKeypoint.new(1,1)})
  st.mist=att
 elseif not misty and st.mist then st.mist:Destroy(); st.mist=nil end
 -- R46: a crackle (lightning tick) or purple wisps (Soul Drain) stay on anyone a tick is hurting.
 local ticking=model:GetAttribute("Zapped")==true and "zap" or model:GetAttribute("Drained")==true and "drain" or nil
 if ticking~=st.tickKind then
  if st.tickAura then st.tickAura:Destroy(); st.tickAura=nil end
  st.tickKind=ticking
  if ticking then
   local att=Instance.new("Attachment"); att.Name="TickAura"; att.Parent=root
   local col=ticking=="zap" and Color3.fromRGB(140,210,255) or Color3.fromRGB(170,80,255)
   local e=emitter(att,col,{Rate=30,Lifetime=NumberRange.new(0.25,0.5),Speed=NumberRange.new(2,5),SpreadAngle=Vector2.new(180,180),
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.5),NumberSequenceKeypoint.new(1,0)})})
   e.LightEmission=1
   local l=Instance.new("PointLight"); l.Color=col; l.Range=8; l.Brightness=1.5; l.Parent=att
   st.tickAura=att
  end
 end
 -- v29 Whirlwind: wind rings spin round anyone caught in it.
 if model:GetAttribute("Whirl") then
  if not st.whirl then
   st.whirl={}
   -- R42: a full funnel (7 rings, wide at the top) with dust and storm smoke, big enough to read.
  for i=1,7 do table.insert(st.whirl,fxPart(Enum.PartType.Cylinder,Vector3.new(0.25,3+i*1.6,3+i*1.6),root.CFrame,Color3.new(0.88,0.96,1),0.35)) end
  local att=Instance.new("Attachment"); att.Name="WhirlDust"; att.Position=Vector3.new(0,-2.5,0); att.Parent=root
  local e=emitter(att,Color3.fromRGB(205,220,240),{Rate=40,Lifetime=NumberRange.new(0.6,1),Speed=NumberRange.new(4,8),
   SpreadAngle=Vector2.new(25,25),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.2),NumberSequenceKeypoint.new(1,3)})})
  e.Texture=SMOKE_TEXTURE; e.EmissionDirection=Enum.NormalId.Top; e.RotSpeed=NumberRange.new(-200,200); e.LightEmission=0.2
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.4),NumberSequenceKeypoint.new(1,1)})
  st.whirlDust=att
  end
  local t=os.clock()
  for i,r in st.whirl do r.CFrame=CFrame.new(root.Position+Vector3.new(math.sin(t*5+i)*0.4,-3.4+i*1.25,math.cos(t*5+i)*0.4))*CFrame.Angles(0,t*(7+i),0)*CFrame.Angles(0,0,math.pi/2+math.sin(t*4+i)*0.15) end
 elseif st.whirl then
  for _,r in st.whirl do r:Destroy() end; st.whirl=nil
  if st.whirlDust then st.whirlDust:Destroy(); st.whirlDust=nil end
 end
 -- v49 face expression: fighting while a move plays, wincing when hit.
 do
  local fg=model:FindFirstChild("Head") and model.Head:FindFirstChild("HumanFace")
  if fg and fg.Enabled then
   local p=poses[model]
   local mood=p and (p.name=="Hurt" or p.name=="Pin") and "hurt" or (p and p.move) and "fight" or "calm"
   if st.mood~=mood and Sig.faceMood then st.mood=mood; Sig.faceMood(fg,mood) end
  end
 end
 -- R18 nameplate: name, health bar and cast bar together over every fighter's head (WoW style).
 -- Replaces Roblox's own name/health display and the separate v49 cast bar. The cast row only
 -- shows while a Cast move winds up; an interrupt or any hit replaces the pose, which ends it.
 do
  local head=model:FindFirstChild("Head"); local hum=model:FindFirstChildOfClass("Humanoid")
  if head and hum then
   local g=st.plate
   if not g or g.Adornee~=head then
    if g then g:Destroy() end
    g=Instance.new("BillboardGui"); g.Name="Nameplate"; g.Size=UDim2.fromOffset(160,58); g.StudsOffset=Vector3.new(0,3.7,0)
    g.AlwaysOnTop=true; g.MaxDistance=200; g.Adornee=head; g.ResetOnSpawn=false
    local function bar(name,y,h,col)
     local back=Instance.new("Frame"); back.Name=name; back.Position=UDim2.fromOffset(0,y); back.Size=UDim2.new(1,0,0,h)
     back.BackgroundColor3=Color3.fromRGB(15,15,20); back.BackgroundTransparency=0.15; back.BorderSizePixel=0; back.Parent=g
     local fill=Instance.new("Frame"); fill.Name="Fill"; fill.BorderSizePixel=0; fill.BackgroundColor3=col; fill.Size=UDim2.fromScale(1,1); fill.Parent=back
     local t=Instance.new("TextLabel"); t.Name="Text"; t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1); t.ZIndex=2
     t.Font=Enum.Font.GothamBold; t.TextSize=11; t.TextColor3=Color3.new(1,1,1); t.TextStrokeTransparency=0.4; t.Text=""; t.Parent=back
     return back
    end
    local n=Instance.new("TextLabel"); n.Name="NameText"; n.BackgroundTransparency=1; n.Size=UDim2.new(1,0,0,14)
    n.Font=Enum.Font.GothamBlack; n.TextSize=13; n.TextColor3=Color3.new(1,1,1); n.TextStrokeTransparency=0.3; n.Parent=g
    bar("Health",15,13,Color3.fromRGB(70,200,90))
    bar("Fury",29,12,Color3.fromRGB(235,120,30)).Text.TextSize=9 -- R19 (Peter): Fury sits with health and cast
    bar("Cast",42,14,Color3.fromRGB(255,190,60)).Visible=false
    -- R41: a status row over the name: Tempest's heal stacks, a lightning tick, Solar Shield points.
    local buff=Instance.new("TextLabel"); buff.Name="Buff"; buff.BackgroundTransparency=1; buff.Position=UDim2.fromOffset(-40,-16)
    buff.Size=UDim2.new(1,80,0,15); buff.Font=Enum.Font.GothamBold; buff.TextSize=12; buff.TextColor3=Color3.fromRGB(170,225,255)
    buff.TextStrokeTransparency=0.3; buff.Text=""; buff.Parent=g
    hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
    -- R64h (Peter: "make the health bars smaller on mobile, clear the centre"): phones get a 65% nameplate.
    if UIS.TouchEnabled then
     local k=0.65; g.Size=UDim2.fromOffset(160*k,58*k)
     for _,d in g:GetDescendants() do
      if d:IsA("GuiObject") then
       d.Position=UDim2.new(d.Position.X.Scale,d.Position.X.Offset*k,d.Position.Y.Scale,d.Position.Y.Offset*k)
       d.Size=UDim2.new(d.Size.X.Scale,d.Size.X.Offset*k,d.Size.Y.Scale,d.Size.Y.Offset*k)
      end
      if d:IsA("TextLabel") then d.TextSize=math.max(7,math.floor(d.TextSize*k+0.5)) end
     end
    end
    g.Parent=fxFolder; st.plate=g
   end
   hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
   local mine=model==(player.Character)
   g.NameText.Text=Rules.display(model:GetAttribute("Hero") or hum.DisplayName)
   g.NameText.TextColor3=mine and Color3.fromRGB(120,200,255) or Color3.fromRGB(255,235,235)
   local hp=math.clamp(hum.Health/math.max(1,hum.MaxHealth),0,1)
   g.Health.Fill.Size=UDim2.fromScale(hp,1)
   g.Health.Fill.BackgroundColor3=hp>0.5 and Color3.fromRGB(70,200,90) or hp>0.25 and Color3.fromRGB(235,190,50) or Color3.fromRGB(220,60,50)
   local shieldHP=model:GetAttribute("ShieldHP")
   g.Health.Text.Text=string.format("%d / %d",math.ceil(hum.Health),math.floor(hum.MaxHealth))..(shieldHP and string.format("  +%d", shieldHP) or "")
   local tags={}
   local stacks=model:GetAttribute("ZapStacks")
   if stacks and stacks>0 then
    table.insert(tags,string.format("⚡ Heal x%d (%d%%)",stacks,math.floor(stacks*Rules.Tempest.StackHeal*100+0.5)))
   end
   if model:GetAttribute("Zapped")==true then table.insert(tags,"⚡ Lightning tick") end
   if model:GetAttribute("Drained")==true then table.insert(tags,"☠ Soul Drain") end
   if model:GetAttribute("Snared")==true then table.insert(tags,"⚡ Snared") end
   local shade=model:GetAttribute("ShadeStacks")
   if shade and shade>0 then table.insert(tags,string.format("☠ Shade x%d",shade)) end
   local phaseEnd=model:GetAttribute("PhaseEnd")
   local phaseLeft=phaseEnd and phaseEnd-workspace:GetServerTimeNow() or 0
   if phaseLeft>0 then table.insert(tags,string.format("◐ Phase %.1fs",phaseLeft)) end
   local mistEnd=model:GetAttribute("MistEnd")
   local mistLeft=mistEnd and mistEnd-workspace:GetServerTimeNow() or 0
   if mistLeft>0 then table.insert(tags,string.format("☁ Mist -50%% %ds",math.ceil(mistLeft))) end
   if shieldHP then table.insert(tags,string.format("%s Shield %d",model:GetAttribute("Hero")=="Solarion" and "☀" or "◆",shieldHP)) end
   g.Buff.Text=table.concat(tags,"  •  ")
   g.Buff.TextColor3=shieldHP and #tags==1 and Color3.fromRGB(255,215,110) or Color3.fromRGB(170,225,255)
   local fury=(mine and Sig.lastState and Sig.lastState.fury) or model:GetAttribute("Fury") or 0
   g.Fury.Fill.Size=UDim2.fromScale(math.clamp(fury/Rules.Fury.Max,0,1),1)
   g.Fury.Text.Text="Fury "..math.floor(fury)
   local p=poses[model]; local m=p and p.move
   local frac=(m and m.Cast and not p.fadeJ and not p.predictedFail) and ((p.holdFrom or os.clock())-p.start)*60/m.Startup or 2
   if frac<1 then
    g.Cast.Visible=true; g.Cast.Fill.Size=UDim2.fromScale(math.clamp(frac,0,1),1)
    g.Cast.Text.Text=Rules.title(model:GetAttribute("Hero"),p.name)
   else g.Cast.Visible=false end
  end
 end
 -- Stun countdown (v23) over anyone held by a long stun.
 local stunEnd=model:GetAttribute("StunEnd")
 local left=stunEnd and stunEnd-workspace:GetServerTimeNow() or 0
 local head=model:FindFirstChild("Head")
 if left>0 and head then
  if not st.stunGui then
   local g=Instance.new("BillboardGui"); g.Name="StunTimer"; g.Size=UDim2.fromOffset(150,40)
   g.StudsOffset=Vector3.new(0,5.6,0); g.AlwaysOnTop=true; g.Adornee=head
   local t=Instance.new("TextLabel"); t.Name="Text"; t.BackgroundTransparency=1; t.Size=UDim2.fromScale(1,1)
   t.Font=Enum.Font.GothamBlack; t.TextScaled=true; t.TextColor3=Color3.fromRGB(255,215,90)
   t.TextStrokeTransparency=0.2; t.Parent=g
   g.Parent=fxFolder; st.stunGui=g
  end
  st.stunGui.Text.Text=string.format("STUNNED %.1f",left)
 elseif st.stunGui then st.stunGui:Destroy(); st.stunGui=nil end
 local flyingNow=model:GetAttribute("Flying")==true
 if flyingNow and not st.aura then
  local accent=heroAccent(model)
  local att=Instance.new("Attachment"); att.Name="FlightFx"; att.Position=Vector3.new(0,-2.6,0); att.Parent=root
  local e=Instance.new("ParticleEmitter"); e.Color=ColorSequence.new(accent); e.LightEmission=1; e.Rate=45
  e.Lifetime=NumberRange.new(0.25,0.45); e.Speed=NumberRange.new(6,10); e.SpreadAngle=Vector2.new(18,18)
  e.EmissionDirection=Enum.NormalId.Bottom
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.6),NumberSequenceKeypoint.new(1,0)}); e.Parent=att
  if model:GetAttribute("Hero")=="Tempest" then
   -- v35: Tempest rides a churning storm cloud instead of a jet.
   e.Texture=SMOKE_TEXTURE; e.Color=ColorSequence.new(Color3.fromRGB(215,230,245),Color3.fromRGB(120,135,160))
   e.LightEmission=0.2; e.Rate=28; e.Lifetime=NumberRange.new(0.5,0.9); e.Speed=NumberRange.new(1,3)
   e.SpreadAngle=Vector2.new(180,30); e.RotSpeed=NumberRange.new(-120,120); e.Rotation=NumberRange.new(0,360)
   e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.2),NumberSequenceKeypoint.new(1,2.6)})
   e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.4),NumberSequenceKeypoint.new(1,1)})
   Sig.play({"wind",0.6,1.1},root)
  else
   e.Color=ColorSequence.new(Color3.fromRGB(255,245,210),accent)
   Sig.play({"fire",0.5,0.8},root); Sig.play({"dash",0.5,0.8},root)
  end
  local light=Instance.new("PointLight"); light.Color=accent; light.Range=12; light.Brightness=2; light.Parent=att
  st.aura=att
  ring(root.Position-Vector3.new(0,2.8,0),accent,10,0.4)
  -- Thruster flames (v21): each back thruster's glow tip blasts downward while flying.
  st.flames={}
  for _,name in {"ThrusterGlowLeft","ThrusterGlowRight"} do
   local tip=model:FindFirstChild(name)
   if tip and tip:IsA("BasePart") then
    local fa=Instance.new("Attachment"); fa.Name="ThrusterFlame"; fa.Position=Vector3.new(0,-tip.Size.Y/2,0); fa.Parent=tip
    local f=Instance.new("ParticleEmitter"); f.Texture=FX_TEXTURE; f.LightEmission=1; f.Rate=90
    f.Color=ColorSequence.new(Color3.new(1,1,1),tip.Color); f.Lifetime=NumberRange.new(0.12,0.22)
    f.Speed=NumberRange.new(14,20); f.SpreadAngle=Vector2.new(6,6); f.EmissionDirection=Enum.NormalId.Bottom
    f.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.55),NumberSequenceKeypoint.new(1,0.05)})
    f.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.1),NumberSequenceKeypoint.new(1,1)}); f.Parent=fa
    table.insert(st.flames,fa)
   end
  end
 elseif not flyingNow and st.aura then
  st.aura:Destroy(); st.aura=nil
  for _,fa in st.flames or {} do fa:Destroy() end; st.flames=nil
 end
end
clearStatusFx=function(model)
 local st=statusFx[model]; if not st then return end
 if st.shield then st.shield:Destroy() end
 if st.aura then st.aura:Destroy() end
 if st.stunGui then st.stunGui:Destroy() end
 if st.plate then st.plate:Destroy() end
 for _,r in st.whirl or {} do r:Destroy() end
 if st.whirlDust then st.whirlDust:Destroy() end
 if st.tickAura then st.tickAura:Destroy() end
 if st.mist then st.mist:Destroy() end
 for _,fa in st.flames or {} do fa:Destroy() end
 if st.bubble then st.bubble:Destroy() end
 statusFx[model]=nil
end

-- WoW-style bindings: each action has two rebindable keyboard keys plus a fixed gamepad button.
local ACTIONS={
 {id="Light",name="Combo",bar=true,pad=Enum.KeyCode.ButtonR2,defaults={"One","KeypadOne"}},
 {id="Heavy",name="Heavy",bar=true,pad=Enum.KeyCode.ButtonL2,defaults={"Two","KeypadTwo"}},
 {id="Skill1",name="Skill 1",bar=true,pad=Enum.KeyCode.ButtonX,defaults={"Three","KeypadThree"}},
 {id="Skill2",name="Skill 2",bar=true,pad=Enum.KeyCode.ButtonY,defaults={"Four","KeypadFour"}},
 {id="Super",name="Super",bar=true,pad=Enum.KeyCode.ButtonL3,defaults={"Five","KeypadFive"}}, -- v49
 {id="Dash",name="Dodge",bar=true,pad=Enum.KeyCode.ButtonB,defaults={"Six","KeypadSix"}},
 {id="Flight",name="Fly",bar=true,pad=Enum.KeyCode.DPadUp,defaults={"Seven","KeypadSeven"}},
 {id="Interrupt",name="Interrupt",bar=true,pad=Enum.KeyCode.ButtonR3,defaults={"Eight","KeypadEight"}}, -- v49
 {id="Defensive",name="Defensive",bar=true,pad=Enum.KeyCode.DPadLeft,defaults={"Nine","KeypadNine"}},
 {id="Skill3",name="Skill 3",bar=true,pad=Enum.KeyCode.DPadRight,defaults={"Zero","KeypadZero"}},
 -- R65 (Peter: "the movement keys don't show up in binding, add them, both WASD and arrow keys"): walking is
 -- rebindable too. This client reads the walk keys itself (Sig.walkInput) instead of Roblox's PlayerModule,
 -- so they work the moment the fighter appears and follow your own keys.
 {id="MoveForward",name="Move forward",walk=Vector3.new(0,0,-1),defaults={"W","Up"}},
 {id="MoveBack",name="Backpedal",walk=Vector3.new(0,0,1),face=true,defaults={"S","Down"}},
 -- R65c (Peter: "where is move left and move right, I need both that and strafe"): Move left / right turn and
 -- run that way (A / D, as before); Strafe left / right sidestep while still facing ahead (Q / E, like WoW).
 {id="MoveLeft",name="Move left",walk=Vector3.new(-1,0,0),defaults={"A","Left"}},
 {id="MoveRight",name="Move right",walk=Vector3.new(1,0,0),defaults={"D","Right"}},
 {id="StrafeLeft",name="Strafe left",walk=Vector3.new(-1,0,0),face=true,defaults={"Q",""}},
 {id="StrafeRight",name="Strafe right",walk=Vector3.new(1,0,0),face=true,defaults={"E",""}},
 {id="Rise",name="Jump / rise",pad=Enum.KeyCode.ButtonA,defaults={"Space",""}},
 {id="Descend",name="Descend",pad=Enum.KeyCode.DPadDown,defaults={"X","LeftControl"}},
 {id="Debug",name="Debug hitboxes",defaults={"H",""}},
 {id="Keybinds",name="Keybinding menu",defaults={"K",""}},
 {id="TargetNext",name="Next target",defaults={"Tab",""}},
 {id="Pause",name="Pause / resume match",defaults={"P",""}},
 {id="Restart",name="Start fight / start over",defaults={"R",""}},
}
-- Keys that would break movement, chat or the Roblox menu if an ability took them.
local RESERVED={W=true,A=true,S=true,D=true,Up=true,Down=true,Left=true,Right=true,
 Escape=true,Slash=true,Backquote=true,Backspace=true,Return=true,Unknown=true}
local DIGITS={"One","Two","Three","Four","Five","Six","Seven","Eight","Nine","Zero"}
local SHORT={LeftShift="Shift",RightShift="RShift",LeftControl="Ctrl",RightControl="RCtrl",
 LeftAlt="Alt",RightAlt="RAlt",Space="Space",LeftBracket="[",RightBracket="]",Semicolon=";",
 Quote="'",Comma=",",Period=".",Minus="-",Equals="=",BackSlash="\\"}
for i,d in DIGITS do SHORT[d]=tostring(i%10); SHORT["Keypad"..d]="Num"..tostring(i%10) end
-- v49 (Peter: gaming mouse): middle click and the wheel can be bound too. Roblox doesn't see a mouse's
-- side buttons, so those are set in the mouse's own software to send a key (F1-F12, a number...).
-- v49 face expression by mood (the face is drawn by Appearance.drawFace on the server) ("calm", "fight", "hurt"): brows, eye openness and mouth.
function Sig.faceMood(face,mood)
 local tilt=face:GetAttribute("BrowTilt") or 6
 for i,side in {"L","R"} do
  local s=i==1 and 1 or -1
  local brow=face:FindFirstChild("Brow"..side)
  if brow then
   brow.Rotation=s*(mood=="fight" and tilt+16 or mood=="hurt" and -12 or tilt)
   brow.Position=UDim2.fromOffset(brow.Position.X.Offset,mood=="fight" and 60 or mood=="hurt" and 50 or 56)
  end
  local white=face:FindFirstChild("EyeWhite"..side)
  if white then white.Size=UDim2.fromOffset(34,mood=="hurt" and 8 or mood=="fight" and 18 or 24); white.Position=UDim2.fromOffset(white.Position.X.Offset,mood=="hurt" and 78 or 70) end
 end
 local mouth=face:FindFirstChild("Mouth")
 if mouth then mouth.Text=mood=="hurt" and "o" or mood=="fight" and "▬" or (mouth:GetAttribute("Calm") or "‿") end
end
Sig.MOUSE_BINDS={MouseButton3=Enum.UserInputType.MouseButton3,WheelUp=true,WheelDown=true}
SHORT.MouseButton3="Mouse3"; SHORT.WheelUp="Wheel ↑"; SHORT.WheelDown="Wheel ↓"
local function keyText(name) if name=="" then return "—" end return SHORT[name] or name end
-- R65: the walk keys (W A S D and the arrows) are only reserved for powers; the Move actions can use them.
Sig.WALK_KEYS={W=true,A=true,S=true,D=true,Up=true,Down=true,Left=true,Right=true}
local function validKey(name,id)
 if type(name)~="string" then return false end
 if name=="" or Sig.MOUSE_BINDS[name] then return true end
 local ok,kc=pcall(function() return Enum.KeyCode[name] end)
 return ok and kc~=nil and (not RESERVED[name] or (type(id)=="string" and id:sub(1,4)=="Move" and Sig.WALK_KEYS[name]==true))
end
-- R65: which walk keys are held right now (key name -> its action), Sig.walkFacing: a strafe or backpedal key is held, and the camera-relative walk they add up to.
Sig.walkHeld={}
-- R65d (Peter: "the toons are not moving at all"): Roblox's own controls walk with the default keys again
-- (W/Up forward, S/Down back, A/Left left, D/Right right, exactly as in R64). This client only reads a walk key
-- that was moved somewhere else (Q / E strafe, or a rebind) and swallows a default key moved away.
Sig.NATIVE_WALK={MoveForward={W=true,Up=true},MoveBack={S=true,Down=true},MoveLeft={A=true,Left=true},MoveRight={D=true,Right=true}}
-- A strafe or backpedal key is held right now (checked straight from the keyboard, so default keys count too).
Sig.walkFacing=function()
 if UIS:GetFocusedTextBox() then return false end
 for _,a in ACTIONS do
  if a.face then
   for _,k in Sig.binds[a.id] do
    if k~="" and not Sig.MOUSE_BINDS[k] then
     local ok,down=pcall(function() return UIS:IsKeyDown(Enum.KeyCode[k]) end)
     if ok and down then return true end
    end
   end
  end
 end
 return false
end
Sig.walkVec=function()
 local v=Vector3.zero
 for _,a in Sig.walkHeld do v+=a.walk end
 return v.Magnitude>1 and v.Unit or v
end
local binds={}
Sig.binds=binds
local function resetBinds() for _,a in ACTIONS do binds[a.id]={a.defaults[1],a.defaults[2]} end end
resetBinds()

local menuOpen=false; local capturing=nil
local predictedCombo,lastLightAt=0,0
-- v30 step D: every attack, dash and defensive press carries a number; the server answers each one.
local PRESS_IDS={Light=true,Heavy=true,Throw=true,Skill1=true,Skill2=true,Skill3=true,Interrupt=true,Super=true,Dash=true,Defensive=true}
-- v33: v30 netcode state in one table (the client chunk was over Luau's 200-local limit)
local net={pressSeq=0,pending={},rejects=0,lastAckMs=0,localDash=nil,myLunge=nil,localFreezeUntil=0,blockHeldLocal=false,snapTo=nil,lastDashAt=-10,lastLungeAt=-10,lastLungeName=nil}
-- v30 step C: my client moves my own fighter while the server allows it ("ClientMove").
-- My current move as the server confirmed it, so presses mid-move only predict a new pose
-- when the shared Rules.canCancel says the server will allow the cancel (step B).
local myAct=nil
local function myActBusy()
 if not myAct then return false end
 local m=heroMoveOf(player.Character,myAct.name)
 return m~=nil and os.clock()-myAct.start<(m.Startup+m.Active+m.Recovery)/60
end
local setTarget, cycleTarget, sendMove, myRootPart, aimVectorOf, moveIntentOf
-- My guessed pose is still running (the server's "Attack" for it may not be here yet).
local function predictedBusy(me)
 local p=poses[me]; local m=p and p.move
 return m~=nil and not p.fadeJ and os.clock()-p.start<(m.Startup+m.Active+m.Recovery)/60
end
local function willDashBlocked(me,remaining)
 return flying or net.blockHeldLocal or me:GetAttribute("Blocking")==true or me:GetAttribute("Locked")==true
  or myActBusy() or predictedBusy(me) or remaining>0.05 or net.localDash~=nil
end
-- Start my own dash or lunge (on the press, or when a buffered press is accepted later).
local function startLocalDash(me,seq)
 local camera=workspace.CurrentCamera; local hum=me:FindFirstChildOfClass("Humanoid"); local root=me:FindFirstChild("HumanoidRootPart")
 if not camera or not hum or not root or not moveIntentOf then return end
 local d=moveIntentOf(hum,camera); d=Vector3.new(d.X,0,d.Z)
 local look=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
 net.localDash={start=os.clock(),dir=d.Magnitude>0.1 and d.Unit or (look.Magnitude>0.01 and look.Unit or Vector3.new(0,0,-1)),seq=seq}
 net.lastDashAt=os.clock(); Sig.fov(5,0.35)
end
local function startLocalLunge(me,name,seq)
 local m=Rules.heroMove(me:GetAttribute("Hero"),name)
 local camera=workspace.CurrentCamera; local root=me:FindFirstChild("HumanoidRootPart")
 if not m or not m.Lunge or not camera or not root or not aimVectorOf then return end
 local aim=aimVectorOf(camera); local flat=Vector3.new(aim.X,0,aim.Z)
 flat=flat.Magnitude>0.01 and flat.Unit or root.CFrame.LookVector
 net.myLunge={dir=flat,rate=m.Lunge*60/m.Startup,ends=os.clock()+m.Startup/60,seq=seq}
 net.lastLungeAt=os.clock(); net.lastLungeName=name
end
local lastState=nil; local slots={}
local cooldownName
local refreshBar, refreshMenu, setMenu
-- v36 prediction (Peter: "improve the input prediction to 10 if you can"). All looks and feel; the
-- server still decides every hit, cost and cooldown.
-- Round trip, smoothed from the server's answers to my presses (buffered waits taken out).
net.rtt=nil; net.spent={}; net.dashSeen=setmetatable({},{__mode="k"}); net.predHit=nil
-- Fury, cooldown and global cooldown spent by a guessed move, shown on my bar at once. Each guess is
-- dropped by the first server State sent after the server answered that press (or by a refusal).
net.applySpent=function(st)
 if not st or not st.cooldowns then return end
 local now=os.clock()
 for i=#net.spent,1,-1 do
  local e=net.spent[i]
  if now-e.at>2 then table.remove(net.spent,i)
  elseif e.applied~=st then
   e.applied=st
   if e.cd then st.cooldowns[e.cd]=math.max(st.cooldowns[e.cd] or 0,e.cdUntil-now) end
   if e.cost>0 then st.fury=math.max(0,(st.fury or 0)-e.cost) end
   if e.gcdUntil then st.gcd=math.max(st.gcd or 0,e.gcdUntil-now) end
  end
 end
end
net.spend=function(seq,name,m)
 local now=os.clock()
 table.insert(net.spent,{seq=seq,at=now,cd=(m.Cooldown or 0)>0 and name or nil,cdUntil=now+(m.Cooldown or 0)/60,
  cost=m.Cost or 0,gcdUntil=m.Cost and now+Rules.GCD/60 or nil})
 net.applySpent(lastState)
 if refreshBar then refreshBar() end
end
net.settle=function(st)
 for i=#net.spent,1,-1 do if net.spent[i].acked then table.remove(net.spent,i) end end
 net.applySpent(st)
end
net.box=function(cf,size)
 local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
 return {p={cf.X,cf.Y,cf.Z},a={{r.X,r.Y,r.Z},{u.X,u.Y,u.Z},{l.X,l.Y,l.Z}},h={size.X/2,size.Y/2,size.Z/2}}
end
-- Hit confirm on my screen: when my guessed swing's hit frames overlap a fighter's hurtbox here (the same
-- box test the server runs, against where I see them, which is where the server rewinds them to), the
-- spark, sound and hit-stop play at once instead of a round trip later. The server's Hit then only adds
-- the damage number and the full effect; a server miss just doesn't follow it up.
net.losParams=RaycastParams.new(); net.losParams.FilterType=Enum.RaycastFilterType.Include
-- v49 (audit step 4): other fighters are drawn about half a round trip behind where the server has them.
-- My hit check leads them by their velocity over that time (capped), so a whiff doesn't show as a hit.
net.lead=function(t)
 local tr=t:FindFirstChild("HumanoidRootPart"); if not tr then return Vector3.zero end
 local v=tr.AssemblyLinearVelocity; v=Vector3.new(v.X,math.clamp(v.Y,-20,20),v.Z)
 local lead=v*math.min((net.rtt or 0)/2,0.15)
 return lead.Magnitude>4 and lead.Unit*4 or lead
end
-- v49: how many hits I showed before the server answered, and how many the server then turned down.
net.predCount=0; net.mispredicts=0
net.contact=function(me,p)
 local m=p.move
 if not m or m.Teleport or m.Throw or m.AirOnly or m.Leap or p.name=="Charge" or not aimVectorOf then return end
 local camera=workspace.CurrentCamera; if not camera then return end
 local aim=aimVectorOf(camera)
 task.spawn(function()
  while poses[me]==p and not p.fadeJ and not p.whiff do
   local root=me:FindFirstChild("HumanoidRootPart"); if not root then return end
   local f=((p.holdFrom or os.clock())-p.start)*60
   if f>m.Startup+m.Active then return end
   if f>=m.Startup then
    local cf=m.Aoe and CFrame.new(root.Position) or CFrame.lookAt(root.Position,root.Position+aim)*CFrame.new(0,0,-m.Range/2)
    local box=net.box(cf,m.Aoe and Vector3.new(m.Aoe*2,m.Height,m.Aoe*2) or Vector3.new(m.Width,m.Height,m.Range))
    local arenaFolder=workspace:FindFirstChild("HeroWarsArena")
    for _,t in workspace:GetChildren() do
     local hb=t:IsA("Model") and t~=me and t:GetAttribute("Hero") and t:FindFirstChild("Hurtbox")
     local hum=hb and t:FindFirstChildOfClass("Humanoid")
     local tp=hum and poses[t]
     if hum and hum.Health>0 and not (hiddenFromMe and hiddenFromMe(t)) and not (tp and tp.name=="Pin") and not t:GetAttribute("Parrying")
      and os.clock()-(net.dashSeen[t] or -9)>0.3 and Rules.boxesOverlap(box,net.box(hb.CFrame+net.lead(t),hb.Size)) then
      local clear=true
      if arenaFolder then
       net.losParams.FilterDescendantsInstances={arenaFolder}
       local d=hb.Position-root.Position
       clear=workspace:Raycast(root.Position,d,net.losParams)==nil
      end
      if clear then net.confirm(me,t,p); return end
     end
    end
   end
   RunService.Heartbeat:Wait()
  end
 end)
end
net.confirm=function(me,t,p)
 local troot=t:FindFirstChild("HumanoidRootPart"); local root=me:FindFirstChild("HumanoidRootPart")
 if not troot or not root then return end
 local m=p.move; local now=os.clock()
 local ph={target=t,name=p.name,at=now}
 net.predHit=ph; net.predCount+=1
 -- No server Hit for it within a second: the server missed it (a misprediction).
 task.delay(1,function() if net.predHit==ph then net.predHit=nil; net.mispredicts+=1 end end)
 local toward=Vector3.new(root.Position.X-troot.Position.X,0,root.Position.Z-troot.Position.Z)
 toward=toward.Magnitude>0.1 and toward.Unit or Vector3.zero
 local pos=troot.Position+toward*1.1+Vector3.new(0,0.8,0)
 local heavy=(m.Damage or 0)>=12
 -- Hero-specific predicted impact below replaces the shared white flash.
 VFX.impact(t,"Hit",m.Damage,me,p.name)
 Sig.sound(me,p.name,"hit",troot,heavy)
 local stop=(m.HitStop or 0)/60
 holdPose(me,stop); net.localFreezeUntil=math.max(net.localFreezeUntil,now+stop)
 -- v49 (audit step 4): the victim flinches on my screen at once; the server's Hit replaces it.
 if not poses[t] or poses[t].name~="Pin" then poses[t]={name="Hurt",start=now,dur=0.2+stop,power=heavy and 1 or 0.6,predicted=true}; holdPose(t,stop) end
 if heavy then shake(0.6,0.2); Sig.punch(0.6) else shake(0.25,0.1) end
end
-- Start my guessed move on the press (or when a buffered press will fire): pose, lunge, trail, my bar.
net.predict=function(action,seq,hero,remaining)
 local me=player.Character; if not me or not hero then return end
 local st=lastState or {}
 local first=Rules.moveName(hero,action,1); local m=first and Rules.heroMove(hero,first)
 if action~="Light" and not m then return end
 -- v29 fix: no punch on screen for a press the server will refuse (cooldown, Fury or global cooldown).
 if m and (remaining or 0)>0.05 then return end
 if m and m.Cost and ((st.fury or 0)<m.Cost or (st.gcd or 0)>0.05) then return end
 if m and m.Super and (st.super or 0)<Rules.Super.Max then return end
 flash(me,Color3.fromRGB(240,210,140),0.07)
 local combo=1
 if action=="Light" then
  -- Guess the combo step so the jab/cross/kick pose starts at once; the server's answer corrects it.
  local now=os.clock()
  if seq and net.pending[seq] then net.pending[seq].prevCombo=predictedCombo end
  predictedCombo=now-lastLightAt<0.75 and predictedCombo%3+1 or 1; lastLightAt=now
  combo=predictedCombo
 end
 local p=pose(me,Rules.moveName(hero,action,combo))
 if not p then return end
 p.predicted=true
 if seq and net.pending[seq] then net.pending[seq].pose=p end
 -- v30: step in behind the punch at once (the server checks it).
 if me:GetAttribute("ClientMove") then startLocalLunge(me,p.name,seq) end
 Sig.trail(me,p)
 if p.move then net.spend(seq,p.name,p.move); net.contact(me,p) end
end
local function input(action,state)
 if UIS:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
 local down=state==Enum.UserInputState.Begin
 if down and Sig.onInput then Sig.onInput(action) end -- R66: the guided fight watches presses
 local up=state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel
 if action=="Rise" then if down then flyUp=true elseif up then flyUp=false end
 elseif action=="Descend" then if down then flyDown=true elseif up then flyDown=false end
 elseif action=="Debug" and down then debugOn=not debugOn; debugLabel.Visible=debugOn
 elseif action=="Keybinds" and down then setMenu(not menuOpen)
 elseif action=="TargetNext" then if down and cycleTarget then cycleTarget() end
 elseif action=="Pause" or action=="Restart" then if down then remote:FireServer(action) end
 elseif action=="Block" then
  if down or up then remote:FireServer("Block",down); net.blockHeldLocal=down end
 elseif down then
  -- Tell the player straight away when an ability is still cooling down.
  local hero=lastState and lastState.hero
  local cd=hero and cooldownName and cooldownName(action,hero)
  local remaining=cd and lastState.cooldowns[cd] or 0
  if remaining>0.05 then
   notice.Text=string.format("%s not ready (%.1fs)",cd=="Defensive" and "Defensive" or Rules.title(hero,cd),remaining)
   local slot=slots[action]
   if slot then
    slot.button.BackgroundColor3=Color3.fromRGB(140,30,30)
    task.delay(0.15,function() slot.button.BackgroundColor3=Color3.fromRGB(28,34,48) end)
   end
  end
  -- Send the latest aim first so the server commits the attack toward the current target.
  if sendMove then sendMove() end
  local seq=nil
  if PRESS_IDS[action] then net.pressSeq+=1; seq=net.pressSeq; net.pending[seq]={action=action,at=os.clock()} end
  remote:FireServer(action,nil,seq)
  local me=player.Character
  local attack=action=="Light" or action=="Heavy" or action=="Skill1" or action=="Skill2" or action=="Skill3"
  -- v30: stunned or frozen, the server will only buffer it, so don't guess a pose.
  if attack and me and hero and not me:GetAttribute("Locked") then
   if not myActBusy() or Rules.canCancel(myAct,action) then net.predict(action,seq,hero,remaining)
   else
    -- v36: pressed near the end of a move, the server buffers it and fires it on the first free frame;
    -- start it here at that moment too instead of waiting for the server's word.
    local m=heroMoveOf(me,myAct.name)
    local left=m and (m.Startup+m.Active+m.Recovery)/60-(os.clock()-myAct.start) or 1
    if left<=Rules.BufferFrames/60 then
     task.delay(math.max(0,left),function()
      if seq and net.pending[seq] and not myActBusy() and not me:GetAttribute("Locked") then
       local cd=cooldownName(action,hero); net.predict(action,seq,hero,cd and lastState and lastState.cooldowns[cd] or 0)
      end
     end)
    end
   end
  end
  -- v30: dash at once on my screen when the server will allow it; a refusal snaps me back.
  if action=="Dash" and me and me:GetAttribute("ClientMove") and not willDashBlocked(me,remaining) then startLocalDash(me,seq) end
 end
 return Enum.ContextActionResult.Sink
end
local captureEndedAt=0
local function onBound(id,state)
 -- While a key is being captured, swallow it so it doesn't also fire an ability.
 if capturing or os.clock()-captureEndedAt<0.1 then return Enum.ContextActionResult.Sink end
 if menuOpen and id~="Keybinds" then return Enum.ContextActionResult.Sink end
 if id=="Rise" then
  -- Space/A keeps standard jumping when grounded.
  input("Rise",state)
  if state==Enum.UserInputState.Begin and not flying then remote:FireServer("Jump") end
  return flying and Enum.ContextActionResult.Sink or Enum.ContextActionResult.Pass
 end
 return input(id,state)
end
-- R21 (Peter: "redo number from 1 to 5 or whatever, sequentially 1,2,3,4,5"): the powers on the bar are
-- always numbered 1, 2, 3... from left to right, with no gaps. A power you moved to a non-number key
-- (Q, F, the mouse...) keeps that key and the rest still count up in order.
Sig.numberPowers=function()
 local hero=lastState and lastState.hero or (player.Character and player.Character:GetAttribute("Hero")) or "Solarion"
 Sig.numberedHero=hero
 local function digitOf(key)
  for i,d in DIGITS do if key==d or key=="Keypad"..d then return i end end
  return nil
 end
 local n=0
 for _,a in ACTIONS do
  if a.bar then
   local pair=binds[a.id]
   if Rules.actionAvailable(hero,a.id) and (pair[1]=="" or digitOf(pair[1])) then
    n+=1
    if n<=#DIGITS then pair[1]=DIGITS[n]; if pair[2]=="" or digitOf(pair[2]) then pair[2]="Keypad"..DIGITS[n] end
    else pair[1]="" end
   elseif not Rules.actionAvailable(hero,a.id) then
    -- Hidden powers give their numbers back so they can't fire from this hero's keys.
    for slot=1,2 do if digitOf(pair[slot]) then pair[slot]="" end end
   elseif digitOf(pair[2]) then pair[2]="" end -- on its own key: drop a stray number so it can't clash
  end
 end
end
local function applyBindings()
 Sig.numberPowers()
 for _,a in ACTIONS do
  local actionName="HW_"..a.id
  CAS:UnbindAction(actionName)
  if a.walk then
   -- R65: walk keys. Held keys are tracked here and the PreSimulation step walks the fighter with them.
   local keys={}
   local native=Sig.NATIVE_WALK[a.id] or {}
   for _,k in binds[a.id] do if k~="" and not Sig.MOUSE_BINDS[k] and not native[k] then table.insert(keys,Enum.KeyCode[k]) end end
   for k in Sig.walkHeld do if Sig.walkHeld[k]==a then Sig.walkHeld[k]=nil end end
   if #keys>0 then
    CAS:BindActionAtPriority(actionName,function(_,state,io)
     local name=io and io.KeyCode and io.KeyCode.Name or a.id
     if state==Enum.UserInputState.Begin and not capturing then Sig.walkHeld[name]=a else Sig.walkHeld[name]=nil end
     return Enum.ContextActionResult.Sink
    end,false,3000,table.unpack(keys))
   end
   continue
  end
  local inputs={}
  for _,k in binds[a.id] do
   local mouse=Sig.MOUSE_BINDS[k]
   if mouse then if typeof(mouse)=="EnumItem" then table.insert(inputs,mouse) end -- the wheel is handled below
   elseif k~="" then table.insert(inputs,Enum.KeyCode[k]) end
  end
  if a.pad then table.insert(inputs,a.pad) end
  -- On touch screens the action bar is the button set; only rise/descend need extra buttons.
  -- R60 (Peter: "what do Up and Down do?"): they fly up and down, so only heroes who can fly get them.
  local touchButton=not Sig.touchPad and (a.id=="Rise" or a.id=="Descend") and Rules.actionAvailable(Sig.numberedHero,"Flight") and (Rules.Characters[Sig.numberedHero] or {}).Flies==true
  if #inputs>0 then
   CAS:BindActionAtPriority(actionName,function(_,state) return onBound(a.id,state) end,touchButton,3000,table.unpack(inputs))
   if touchButton then
    CAS:SetTitle(actionName,a.id=="Rise" and "Up" or "Down")
    CAS:SetPosition(actionName,a.id=="Rise" and UDim2.new(1,-131,1,-245) or UDim2.new(1,-65,1,-245))
   end
  end
 end
 -- R65: a default walk key you moved away from (or cleared) is swallowed, so Roblox's own controls can't
 -- still walk with it; every walk key that is bound is read by this client instead.
 CAS:UnbindAction("HW_WalkSink")
 do
  local used={}; for _,a in ACTIONS do for _,k in binds[a.id] do used[k]=true end end
  local spare={}; for k in Sig.WALK_KEYS do if not used[k] then table.insert(spare,Enum.KeyCode[k]) end end
  if #spare>0 then CAS:BindActionAtPriority("HW_WalkSink",function() return Enum.ContextActionResult.Sink end,false,3000,table.unpack(spare)) end
 end
 if refreshBar then refreshBar() end
end

-- Action bar: numbered slots along the bottom, clickable or tappable.
local bar=Instance.new("Frame"); bar.Name="ActionBar"; bar.BackgroundTransparency=1
local slotCount=0; for _,a in ACTIONS do if a.bar then slotCount+=1 end end
bar.Size=UDim2.fromOffset(slotCount*62-6,56); bar.Position=UDim2.new(0.5,-(slotCount*62-6)/2,1,-68); bar.Parent=gui
do
 local i=0
 for _,a in ACTIONS do
  if a.bar then
   local b=button(a.id,bar,UDim2.fromOffset(i*62,0),UDim2.fromOffset(56,56),a.name,Color3.fromRGB(28,34,48))
   b.TextSize=12; b.TextWrapped=true
   local stroke=Instance.new("UIStroke"); stroke.Color=Color3.fromRGB(200,170,90); stroke.Thickness=1.5
   stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; stroke.Parent=b
   local key=Instance.new("TextLabel"); key.Name="Key"; key.BackgroundTransparency=1
   key.Position=UDim2.fromOffset(3,1); key.Size=UDim2.fromOffset(50,14); key.TextXAlignment=Enum.TextXAlignment.Left
   key.Font=Enum.Font.GothamBold; key.TextSize=11; key.TextColor3=Color3.fromRGB(255,220,130); key.ZIndex=3; key.Parent=b
   local shade=Instance.new("Frame"); shade.Name="Cooldown"; shade.BackgroundColor3=Color3.new(0,0,0)
   shade.BackgroundTransparency=0.35; shade.BorderSizePixel=0; shade.AnchorPoint=Vector2.new(0,1)
   shade.Position=UDim2.fromScale(0,1); shade.Size=UDim2.fromScale(1,0); shade.ZIndex=2; shade.Parent=b
   local timer=Instance.new("TextLabel"); timer.Name="Timer"; timer.BackgroundTransparency=1
   timer.Size=UDim2.fromScale(1,1); timer.Font=Enum.Font.GothamBold; timer.TextSize=18
   timer.TextColor3=Color3.new(1,1,1); timer.Text=""; timer.ZIndex=4; timer.Parent=b
   if a.hold then
    b.InputBegan:Connect(function(io)
     if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then input(a.id,Enum.UserInputState.Begin) end
    end)
    b.InputEnded:Connect(function(io)
     if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then input(a.id,Enum.UserInputState.End) end
    end)
   else
    b.Activated:Connect(function() if not menuOpen then input(a.id,Enum.UserInputState.Begin) end end)
   end
   slots[a.id]={button=b,key=key,shade=shade,timer=timer}
   i+=1
  end
 end
end
-- R63 (top-5 audit item 2, "mobile layout like TSB"): on a phone the bar becomes round buttons at the
-- bottom right: one big ATTACK (the combo), Heavy and the 3 skills in an arc round it, Dodge / Defensive /
-- Fly in a column above the Roblox jump button, and Interrupt or Super only for heroes who have them.
-- Up / Down (fly higher / lower) show only while flying. Desktop keeps the WoW bar unchanged.
-- Spots are {x, y, size} in pixels from the bottom-right corner (button centres).
if UIS.TouchEnabled and not UIS.KeyboardEnabled then
 -- R64f (Peter: "just keep the buttons at the bottom"): everything sits in two low rows left of a big ATTACK,
 -- which sits just left of the Roblox jump button. Nothing rises past about 130 from the bottom, so nothing
 -- reaches the MENU, the target box or the middle of the screen.
 -- R64i (Peter: "put all of the buttons at the bottom for Samsung, leave it like it is for Apple, make the buttons
 -- bigger, keep attacking close and defence together"). Two layouts, packed so no gaps are left for moves a hero
 -- doesn't have: attacks (Heavy, skills, Interrupt, Super) sit next to ATTACK, defence (Dodge, Defensive, Fly) together.
 --  * one row (Samsung / phones without a notch): everything in a single row along the bottom edge;
 --  * two rows (iPhone with a notch): attacks on the bottom row, defence on the row above.
 -- The phone picks one by whether the screen has a notch; MENU has a button to switch. Roblox scripts can't ask
 -- whether a phone is Android or iPhone, so the notch is the tell.
 local GROUPS={Attack={"Heavy","Skill1","Skill2","Skill3","Interrupt","Super"},Defence={"Dash","Defensive","Flight"}}
 local pad=Instance.new("Frame"); pad.Name="TouchPad"; pad.BackgroundTransparency=1; pad.Size=UDim2.fromScale(1,1)
 pad.Active=false; pad.Parent=gui
 bar.Visible=false
 for _,slot in slots do
  slot.button.Parent=pad; slot.key.Visible=false
  local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0.5,0); c.Parent=slot.button
  local c2=Instance.new("UICorner"); c2.CornerRadius=UDim.new(0.5,0); c2.Parent=slot.shade
  slot.button.BackgroundTransparency=0.15
 end
 Sig.touchPad=pad
 local layoutCache={}
 local function usable(id,hero)
  if not Rules.actionAvailable(hero,id) then return false end
  if id=="Flight" then return Rules.Characters[hero]~=nil and Rules.Characters[hero].Flies==true end
  if id=="Skill3" then return Rules.moveName(hero,"Skill3",1)~=nil end
  return true
 end
 -- R64l (Peter: "Bulwark doesn't have an attack, I took out his combo; think of a solution for all"): every hero
 -- gets the big ATTACK button. If a hero has no combo (Bulwark), his first attack (Heavy: Cleave) takes the ATTACK
 -- spot and title instead, so the big button always hits.
 Sig.attackId=function(hero) return Rules.actionAvailable(hero,"Light") and "Light" or "Heavy" end
 -- R64l (Peter: "a switch for the button layout, styled or flat"): Flat = one row along the bottom (default);
 -- Styled = the arc round ATTACK (attacks) with defence stacked above the jump button, scaled to the screen height.
 local function layout(hero)
  local one=pad:GetAttribute("OneRow")==true
  local w=math.max(pad.AbsoluteSize.X,600); local h=math.max(pad.AbsoluteSize.Y,300)
  local key=hero..(one and "|flat|" or "|styled|")..math.floor(w).."x"..math.floor(h)
  if layoutCache[key] then return layoutCache[key] end
  local L={}; local att={}; local def={}
  local big=Sig.attackId(hero)
  for _,id in GROUPS.Attack do if id~=big and usable(id,hero) then table.insert(att,id) end end
  for _,id in GROUPS.Defence do if usable(id,hero) then table.insert(def,id) end end
  if one then
   -- ATTACK just left of the Roblox jump button, then attacks, a gap, then defence; shrinks only if the
   -- row would reach the thumbstick.
   L[big]={-150,-54,88}
   local size,gapIn,gapGroup=70,6,16 -- R64j: bigger (ATTACK stays 88)
   local need=(#att+#def)*(size+gapIn)+gapGroup
   local avail=w-215-200
   if need>avail then local k=avail/need; size=math.floor(size*k); gapIn=math.max(2,math.floor(gapIn*k)); gapGroup=math.floor(gapGroup*k) end
   local x=-200-size/2
   for _,id in att do L[id]={x,-10-size/2,size}; x-=size+gapIn end
   x-=gapGroup
   for _,id in def do L[id]={x,-10-size/2,size}; x-=size+gapIn end
  else
   -- Styled: designed for 300 of height above the bottom; shorter screens scale it down so nothing reaches MENU.
   local k=math.clamp((h-70)/300,0.6,1)
   local ARC={{-282,-84},{-266,-152},{-212,-198},{-144,-204},{-340,-150},{-322,-216}}
   local COL={{-60,-168},{-60,-232},{-124,-270}}
   L[big]={-170*k,-84*k,96*k}
   for i,id in att do local p=ARC[i]; if p then L[id]={p[1]*k,p[2]*k,62*k} end end
   for i,id in def do local p=COL[i]; if p then L[id]={p[1]*k,p[2]*k,58*k} end end
  end
  layoutCache[key]=L; return L
 end
 Sig.touchSpot=function(id,slot,hero)
  local spot=layout(hero)[id]
  if not spot then slot.button.Visible=false; return end
  local size=spot[3]
  slot.button.Size=UDim2.fromOffset(size,size)
  slot.button.Position=UDim2.new(1,spot[1]-size/2,1,spot[2]-size/2)
  slot.button.TextSize=size>=80 and 18 or (size>=64 and 13 or size>=56 and 12 or 10)
 end
 -- Pick the layout: a notch (left safe-area inset) means an iPhone-style screen, so two rows; else one row.
 pad:SetAttribute("OneRow",true)
 task.spawn(function()
  local probe=Instance.new("ScreenGui"); probe.Name="SafeProbe"; probe.ScreenInsets=Enum.ScreenInsets.DeviceSafeInsets; probe.Parent=gui.Parent
  local f=Instance.new("Frame"); f.BackgroundTransparency=1; f.Size=UDim2.fromScale(1,1); f.Parent=probe
  task.wait(0.5)
  local left=f.AbsolutePosition.X; local right=workspace.CurrentCamera.ViewportSize.X-(f.AbsolutePosition.X+f.AbsoluteSize.X)
  probe:Destroy()
  local notch=math.max(left,right)>=30
  -- R64j (Peter: "put all the buttons at the bottom in a line"): one row on every phone; the MENU button still switches.
  print(string.format("[HeroWars] phone buttons: one row (notch %s, safe-area inset %d/%d)",notch and "yes" or "no",math.floor(left),math.floor(right)))
 end)
 do
  -- R64l: right under Lobby / Pause at the top of MENU, so it is seen without scrolling.
  local b=button("ButtonLayout",panel,UDim2.new(),UDim2.fromOffset(260,38),"Buttons: Flat",Color3.fromRGB(55,65,95)); b.LayoutOrder=1
  local function relabel() b.Text=pad:GetAttribute("OneRow") and "Buttons: FLAT  (tap for Styled)" or "Buttons: STYLED  (tap for Flat)" end
  relabel(); pad:GetAttributeChangedSignal("OneRow"):Connect(relabel)
  b.Activated:Connect(function() pad:SetAttribute("Chosen",true); pad:SetAttribute("OneRow",not pad:GetAttribute("OneRow")); if refreshBar then refreshBar() end end)
 end
 -- Up / Down while flying, left of the arc.
 local function flyButton(name,text,y,onDown)
  local b=button(name,pad,UDim2.new(1,-350-28,1,y-28),UDim2.fromOffset(56,56),text,Color3.fromRGB(40,60,90))
  local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0.5,0); c.Parent=b
  b.TextSize=14; b.Visible=false; b.BackgroundTransparency=0.15
  b.InputBegan:Connect(function(io) if io.UserInputType==Enum.UserInputType.Touch or io.UserInputType==Enum.UserInputType.MouseButton1 then onDown(true) end end)
  b.InputEnded:Connect(function(io) if io.UserInputType==Enum.UserInputType.Touch or io.UserInputType==Enum.UserInputType.MouseButton1 then onDown(false) end end)
  return b
 end
 local up=flyButton("FlyUp","UP",-162,function(on) flyUp=on end)
 local down=flyButton("FlyDown","DOWN",-162,function(on) flyDown=on end)
 up.Size=UDim2.fromOffset(50,50); down.Size=UDim2.fromOffset(50,50)
 up.Position=UDim2.new(1,-240-25,1,-160-25); down.Position=UDim2.new(1,-298-25,1,-160-25) -- R64i: above the rows, only while flying
 RunService.Heartbeat:Connect(function()
  -- R64l (Peter: "remove up and down on mobile for flying; players fly out of reach"): never shown.
  if up.Visible then up.Visible=false; down.Visible=false end; flyUp=false; flyDown=false
 end)
end
cooldownName=function(id,hero)
 if id=="Heavy" then return "Heavy" end
 if id=="Throw" then return Rules.moveName(hero,"Throw",1) end
 if id=="Defensive" then return "Defensive" end
 if id=="Interrupt" or id=="Super" then return id end
 if id=="Skill1" or id=="Skill2" or id=="Skill3" then return Rules.moveName(hero,id,1) end
 if id=="Dash" then return "Dash" end
 return nil
end
refreshBar=function()
 local hero=lastState and lastState.hero or (player.Character and player.Character:GetAttribute("Hero")) or "Solarion"
 if Sig.numberedHero~=hero then applyBindings(); return end
 local visibleSlots=0
 for _,a in ACTIONS do
  local slot=slots[a.id]
  if slot then
   slot.button.Visible=Rules.actionAvailable(hero,a.id)
   if Sig.touchSpot then Sig.touchSpot(a.id,slot,hero) -- R63 phone layout
   elseif slot.button.Visible then
    slot.button.Position=UDim2.fromOffset(visibleSlots*62,0)
    visibleSlots+=1
   end
   local pair=binds[a.id]
   slot.key.Text=keyText(pair[1]~="" and pair[1] or pair[2])
   local title=a.name
   -- v28: every hero's buttons carry that hero's own move names.
   local named=a.id=="Light" and "Light1" or (a.id=="Heavy" or a.id=="Throw" or a.id=="Skill1" or a.id=="Skill2" or a.id=="Skill3" or a.id=="Interrupt" or a.id=="Super") and Rules.moveName(hero,a.id,1) or nil
   if named then title=Rules.title(hero,named) end
   if a.id=="Skill3" and not named then title="—" end
   if Sig.touchPad and Sig.attackId and a.id==Sig.attackId(hero) then title="ATTACK" end -- R64l: Bulwark's Cleave when he has no combo
   if a.id=="Defensive" then title=Rules.Defensives[hero] and Rules.Defensives[hero].Name or title end
   local cd=cooldownName(a.id,hero)
   local move=cd and Rules.heroMove(hero,cd)
   if move and move.Cost then title=title.."\n"..move.Cost.." Fury" end
   if move and move.Super then title=title.."\n"..math.floor((lastState and lastState.super or 0)/Rules.Super.Max*100).."%" end
   slot.button.Text=title
   -- Greyed out when it can't be used: Fly for Wraithstep, or not enough Fury.
   local disabled=(a.id=="Skill3" and not named) or (a.id=="Flight" and not (Rules.Characters[hero] and Rules.Characters[hero].Flies)) or (move~=nil and move.Cost~=nil and lastState~=nil and (lastState.fury or 0)<move.Cost) or (move~=nil and move.Super==true and (lastState==nil or (lastState.super or 0)<Rules.Super.Max))
   slot.button.TextTransparency=disabled and 0.6 or 0
   local remaining=0; local total=1
   if cd and lastState then
    remaining=lastState.cooldowns[cd] or 0
    total=cd=="Dash" and 1.5 or cd=="Defensive" and (Rules.Defensives[hero].Cooldown/60) or (move and move.Cooldown/60) or 1
    -- R45: a ramping cooldown can be longer than the move's base one; the sweep uses the longest seen.
    if remaining<=0.05 then slot.cdPeak=nil elseif remaining>(slot.cdPeak or 0) then slot.cdPeak=remaining end
    total=math.max(total,slot.cdPeak or 0)
    -- Fury moves also wait on the global cooldown.
    if move and move.Cost and (lastState.gcd or 0)>remaining then remaining=lastState.gcd; total=Rules.GCD/60 end
   end
   if a.id=="Flight" and lastState and not disabled then
    slot.timer.Text=lastState.flying and "ON" or ""
    slot.shade.Size=UDim2.fromScale(1,1-math.clamp(lastState.energy/100,0,1))
   else
    slot.shade.Size=UDim2.fromScale(1,remaining>0 and math.clamp(remaining/total,0,1) or 0)
    slot.timer.Text=remaining>0.05 and string.format("%.1f",remaining) or ""
   end
  end
 end
 local width=math.max(0,visibleSlots*62-6)
 bar.Size=UDim2.fromOffset(width,56)
 bar.Position=UDim2.new(0.5,-width/2,1,-68)
end

-- Keybinding menu: two keys per action, click to rebind, reset button restores defaults.
local menu=Instance.new("Frame"); menu.Name="Keybindings"; menu.Visible=false
local rowH=30
menu.Size=UDim2.fromOffset(420,#ACTIONS*rowH+122); menu.Position=UDim2.new(0.5,-210,0.5,-(#ACTIONS*rowH+122)/2)
menu.BackgroundColor3=Color3.fromRGB(18,22,34); menu.BackgroundTransparency=0.05; menu.ZIndex=10; menu.Parent=gui
-- R65: four walk rows made the list taller, so it shrinks to fit short screens (centred, never over full size).
do
 local sc=Instance.new("UIScale"); sc.Parent=menu
 menu.AnchorPoint=Vector2.new(0.5,0.5); menu.Position=UDim2.fromScale(0.5,0.5)
 local function fitMenu()
  local h=gui.AbsoluteSize.Y; if h<50 then return end
  sc.Scale=math.clamp((h-24)/(#ACTIONS*rowH+122),0.45,1)
 end
 fitMenu(); gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitMenu)
end
do local menuStroke=Instance.new("UIStroke"); menuStroke.Color=Color3.fromRGB(200,170,90); menuStroke.Thickness=2; menuStroke.Parent=menu end
local function menuLabel(text,pos,size,font,sizePx)
 local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Position=pos; l.Size=size; l.Text=text
 l.TextColor3=Color3.fromRGB(235,235,245); l.Font=font or Enum.Font.Gotham; l.TextSize=sizePx or 14
 l.TextXAlignment=Enum.TextXAlignment.Left; l.ZIndex=11; l.Parent=menu; return l
end
menuLabel("Keybindings",UDim2.fromOffset(16,8),UDim2.fromOffset(300,24),Enum.Font.GothamBold,18)
menuLabel("Action",UDim2.fromOffset(16,36),UDim2.fromOffset(150,18),Enum.Font.GothamBold,12)
menuLabel("Key 1",UDim2.fromOffset(186,36),UDim2.fromOffset(100,18),Enum.Font.GothamBold,12)
menuLabel("Key 2",UDim2.fromOffset(296,36),UDim2.fromOffset(100,18),Enum.Font.GothamBold,12)
local status=menuLabel("Click a key box, then press the new key. Backspace clears it.",UDim2.fromOffset(16,#ACTIONS*rowH+60),UDim2.fromOffset(390,18),Enum.Font.Gotham,12)
status.TextColor3=Color3.fromRGB(190,195,210)
local keyButtons={}
for row,a in ACTIONS do
 local y=56+(row-1)*rowH
 menuLabel(a.name..(a.hold and " (hold)" or ""),UDim2.fromOffset(16,y+3),UDim2.fromOffset(165,22))
 keyButtons[a.id]={}
 for slotIndex=1,2 do
  local b=button(a.id..slotIndex,menu,UDim2.fromOffset(186+(slotIndex-1)*110,y),UDim2.fromOffset(100,26),"",Color3.fromRGB(40,48,66))
  b.ZIndex=11; b.TextSize=13
  b.Activated:Connect(function()
   if capturing and capturing.id==a.id and capturing.slot==slotIndex then
    capturing=nil; status.Text="Cancelled."; refreshMenu(); return
   end
   capturing={id=a.id,slot=slotIndex}
   status.Text="Press a key for "..a.name.." (Backspace clears, click again to cancel)…"
   refreshMenu()
  end)
  keyButtons[a.id][slotIndex]=b
 end
end
local function saveBinds() remote:FireServer("SaveBinds",binds) end
local reset=button("Reset",menu,UDim2.fromOffset(16,#ACTIONS*rowH+84),UDim2.fromOffset(190,30),"Reset to defaults",Color3.fromRGB(120,60,40))
reset.ZIndex=11
reset.Activated:Connect(function()
 capturing=nil; resetBinds(); applyBindings(); refreshMenu(); saveBinds()
 status.Text="Default keys restored."
end)
local close=button("Close",menu,UDim2.fromOffset(214,#ACTIONS*rowH+84),UDim2.fromOffset(190,30),"Close (K)",Color3.fromRGB(45,90,60))
close.ZIndex=11
close.Activated:Connect(function() setMenu(false) end)
refreshMenu=function()
 for id,pair in keyButtons do
  for slotIndex,b in pair do
   local active=capturing and capturing.id==id and capturing.slot==slotIndex
   b.Text=active and "…" or keyText(binds[id][slotIndex])
   b.BackgroundColor3=active and Color3.fromRGB(150,120,40) or Color3.fromRGB(40,48,66)
  end
 end
end
setMenu=function(open)
 if open and UIS.TouchEnabled and not UIS.KeyboardEnabled then return end -- R65c: no keybinds on phones
 menuOpen=open; menu.Visible=open; capturing=nil
 if open then status.Text="Click a key box, then press the new key. Backspace clears it."; refreshMenu() end
end
local keysButton=button("KeybindsButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Keybinds (K)",Color3.fromRGB(70,70,40))
if UIS.TouchEnabled and not UIS.KeyboardEnabled then keysButton.Visible=false; keysButton.Parent=nil end -- R65c (Peter): not on phones
keysButton.LayoutOrder=3
keysButton.Activated:Connect(function() setMenu(not menuOpen) end)
-- Sparring bot level: click to cycle Easy → Normal → Hard → Off. Alone, you fight it in rounds.
local botButton=button("BotButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Sparring bot: "..Rules.Bot.Default,Color3.fromRGB(40,80,70))
botButton.LayoutOrder=5
botButton.Activated:Connect(function() remote:FireServer("Bot") end)
-- v27: which hero the bot plays. Click to cycle Wraithstep → Solarion → Tempest → Bulwark.
local botHeroButton=button("BotHeroButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Bot hero: "..Rules.display(Rules.Bot.Heroes[1]),Color3.fromRGB(40,70,90))
botHeroButton.LayoutOrder=5
botHeroButton.Activated:Connect(function() remote:FireServer("BotHero") end)
-- v32: arena picker (City Park / Jungle Temples, R37), between matches.
local arenaButton=button("ArenaButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Arena: "..Rules.Arenas[Rules.Arenas.Order[1]].Title,Color3.fromRGB(100,74,40))
arenaButton.LayoutOrder=5
arenaButton.Activated:Connect(function() remote:FireServer("Arena") end)
local function showBot(level,hero)
 if type(level)~="string" then return end
 botButton.Text=level=="Off" and "Sparring bot: OFF (dummy stands still)" or "Sparring bot: "..level.." (click to change)"
 botButton.BackgroundColor3=level=="Off" and Color3.fromRGB(70,50,50) or Color3.fromRGB(40,80,70)
 if type(hero)=="string" then botHeroButton.Text="Bot hero: "..Rules.display(hero).." (click to change)" end
end
-- Skin picker (v15, v17): cycles the hero's kit and catalog-gear skins, any time you're not mid-attack (cosmetic only).
local skinButton=button("SkinButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Skin: Default",Color3.fromRGB(70,50,90))
skinButton.LayoutOrder=4
local function refreshSkin()
 local model=player.Character
 local skin=skinOf(model)
 local hero=model and model:GetAttribute("Hero"); local set=hero and Rules.Skins[hero]
 local i=set and skin and table.find(set.Order,skin.Name)
 skinButton.Text=skin and string.format("Skin: %s %d/%d (click for next)",skin.Name,i or 1,set and #set.Order or 1) or "Skin: —"
end
skinButton.Activated:Connect(function()
 local model=player.Character; local hero=model and model:GetAttribute("Hero")
 local set=hero and Rules.Skins[hero]; if not set then return end
 local _,current=Rules.skin(hero,model:GetAttribute("Skin"))
 local i=table.find(set.Order,current) or 1
 remote:FireServer("Skin",set.Order[i%#set.Order+1])
end)
-- Match controls: pause/resume (P) and start over with a fresh 3-2-1-GO (R).
local matchRow=Instance.new("Frame"); matchRow.Name="MatchControls"; matchRow.BackgroundTransparency=1
matchRow.Size=UDim2.fromOffset(260,38); matchRow.LayoutOrder=6; matchRow.Parent=panel
-- R30 (Peter: "put the pause button with the lobby button"): Pause sits beside Lobby at the bottom.
local pauseButton=button("PauseButton",heroRow,UDim2.fromOffset(133,0),UDim2.fromOffset(127,40),"Pause (P)",Color3.fromRGB(70,70,90))
local restartButton=button("RestartButton",matchRow,UDim2.new(),UDim2.fromOffset(82,38),"START (R)",Color3.fromRGB(40,110,60))
do -- R22 (Peter: "put a stop fight button")
 local stopButton=button("StopButton",matchRow,UDim2.fromOffset(89,0),UDim2.fromOffset(82,38),"STOP FIGHT",Color3.fromRGB(140,45,45))
 pauseButton.TextSize=16; restartButton.TextSize=13; stopButton.TextSize=13
 stopButton.Activated:Connect(function() remote:FireServer("StopFight") end)
 -- R34: RESET restarts the whole fight (health, Fury, cooldowns, positions, score) from scratch.
 local resetButton=button("ResetFightButton",matchRow,UDim2.fromOffset(178,0),UDim2.fromOffset(82,38),"RESET",Color3.fromRGB(150,110,30))
 resetButton.TextSize=13
 resetButton.Activated:Connect(function() remote:FireServer("ResetFight") end)
end
pauseButton.Activated:Connect(function() remote:FireServer("Pause") end)
restartButton.Activated:Connect(function() remote:FireServer("Restart") end)
-- R63 (top-5 audit item 1, "everyone fights"): QUEUE for the next free ring, CHALLENGE the fighter you have
-- targeted, WATCH a running duel (the camera follows its fighters; again to switch, last press comes back).
-- The duel list shows every running duel. A challenge to you shows ACCEPT / NO beside the MENU button.
do
 local duelRow=Instance.new("Frame"); duelRow.Name="DuelControls"; duelRow.BackgroundTransparency=1
 duelRow.Size=UDim2.fromOffset(260,38); duelRow.LayoutOrder=7; duelRow.Parent=panel
 local queueButton=button("QueueButton",duelRow,UDim2.new(),UDim2.fromOffset(82,38),"QUEUE",Color3.fromRGB(40,90,140))
 local challengeButton=button("ChallengeButton",duelRow,UDim2.fromOffset(89,0),UDim2.fromOffset(82,38),"CHALLENGE",Color3.fromRGB(130,60,130))
 local watchButton=button("WatchButton",duelRow,UDim2.fromOffset(178,0),UDim2.fromOffset(82,38),"WATCH",Color3.fromRGB(60,70,90))
 queueButton.TextSize=13; challengeButton.TextSize=12; watchButton.TextSize=13
 local duelList=label("DuelList",UDim2.new(),UDim2.fromOffset(260,20),"No duels running")
 duelList.Parent=panel; duelList.LayoutOrder=8; duelList.TextSize=12; duelList.AutomaticSize=Enum.AutomaticSize.Y
 duelList.BackgroundTransparency=0.4; duelList.TextXAlignment=Enum.TextXAlignment.Left
 do local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,6); pad.PaddingTop=UDim.new(0,3); pad.PaddingBottom=UDim.new(0,3); pad.Parent=duelList end
 queueButton.Activated:Connect(function() remote:FireServer("Queue") end)
 challengeButton.Activated:Connect(function()
  local t=Sig.getTarget and Sig.getTarget()
  if not t then notice.Text="Target a fighter first (tap or click them, or Tab), then CHALLENGE."; return end
  remote:FireServer("Challenge",t)
 end)
 -- Watching: the camera follows a duel's fighters in turn; pressing past the last one comes back to you.
 local duels={}; local watching=0
 local function camHome()
  local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if hum then workspace.CurrentCamera.CameraSubject=hum end
  watching=0; watchButton.Text="WATCH"
 end
 local function watchList()
  local list={}
  for _,d in duels do
   for _,m in {d.ma,d.mb} do if typeof(m)=="Instance" and m.Parent and m~=player.Character then table.insert(list,{model=m,d=d}) end end
  end
  return list
 end
 watchButton.Activated:Connect(function()
  local list=watchList()
  if #list==0 then camHome(); notice.Text="No duels to watch right now."; return end
  watching+=1
  if watching>#list then camHome(); notice.Text="Back to your fighter."; return end
  local pick=list[watching]; local hum=pick.model:FindFirstChildOfClass("Humanoid")
  if hum then workspace.CurrentCamera.CameraSubject=hum end
  watchButton.Text=string.format("WATCH %d/%d",watching,#list)
  notice.Text=string.format("Watching %s vs %s",pick.d.a,pick.d.b)
 end)
 Sig.queueSize=0
 Sig.onDuels=function(list,queued)
  duels=type(list)=="table" and list or {}
  Sig.queueSize=type(queued)=="number" and queued or 0
  local lines={}
  for _,d in duels do
   table.insert(lines,string.format("%s %d - %d %s%s",d.a,d.wa or 0,d.wb or 0,d.b,d.phase=="Countdown" and " • starting" or ""))
  end
  if #lines==0 then lines={"No duels running"} end
  if Sig.queueSize>0 then table.insert(lines,Sig.queueSize.." waiting in the queue") end
  duelList.Text=table.concat(lines,"\n")
  -- In my own duel the camera always follows me.
  if (player.Character and player.Character:GetAttribute("DuelId")) and watching>0 then camHome() end
  if watching>0 and #watchList()==0 then camHome() end
 end
 player.CharacterAdded:Connect(function() if watching>0 then task.defer(camHome) end end)
 -- A challenge to me: ACCEPT / NO beside the MENU button (top right, away from the action buttons).
 local ask=Instance.new("Frame"); ask.Name="ChallengeAsk"; ask.AnchorPoint=Vector2.new(1,0)
 ask.Position=UDim2.new(1,-(UIS.TouchEnabled and 146 or 162),0,12); ask.Size=UDim2.fromOffset(260,44)
 ask.BackgroundColor3=Color3.fromRGB(60,30,70); ask.BackgroundTransparency=0.15; ask.Visible=false; ask.Parent=menuToggle.Parent
 do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=ask end
 local askText=Instance.new("TextLabel"); askText.BackgroundTransparency=1; askText.Position=UDim2.fromOffset(8,0)
 askText.Size=UDim2.fromOffset(122,36); askText.Font=Enum.Font.GothamBold; askText.TextSize=12; askText.TextWrapped=true
 askText.TextColor3=Color3.new(1,1,1); askText.TextXAlignment=Enum.TextXAlignment.Left; askText.Parent=ask
 local yes=button("AcceptChallenge",ask,UDim2.fromOffset(134,4),UDim2.fromOffset(66,28),"ACCEPT",Color3.fromRGB(40,120,60)); yes.TextSize=12
 local no=button("DeclineChallenge",ask,UDim2.fromOffset(204,4),UDim2.fromOffset(40,28),"NO",Color3.fromRGB(120,45,45)); no.TextSize=12
 local askToken=0
 yes.Activated:Connect(function() ask.Visible=false; remote:FireServer("Accept",true) end)
 no.Activated:Connect(function() ask.Visible=false; remote:FireServer("Accept",false) end)
 Sig.onChallenge=function(from)
  askToken+=1; local mine=askToken
  askText.Text=tostring(from).." challenges you!"; ask.Visible=true
  notice.Text=tostring(from).." challenges you to a duel. ACCEPT is at the top right."
  task.delay(30,function() if askToken==mine then ask.Visible=false end end)
 end
end
-- Fury bar just above the action bar: spent by specials, built by landing and taking hits.
local furyBack=Instance.new("Frame"); furyBack.Name="Fury"; furyBack.BackgroundColor3=Color3.fromRGB(40,20,15)
furyBack.BorderSizePixel=0; furyBack.AnchorPoint=Vector2.new(0.5,1)
furyBack.Position=UDim2.new(0.5,0,1,-74); furyBack.Size=UDim2.fromOffset(300,12); furyBack.Parent=gui
furyBack.Visible=false -- R19: Fury moved to the nameplate over the head
local furyFill=Instance.new("Frame"); furyFill.BackgroundColor3=Color3.fromRGB(235,120,30); furyFill.BorderSizePixel=0
furyFill.Size=UDim2.fromScale(0.5,1); furyFill.Parent=furyBack
local furyText=Instance.new("TextLabel"); furyText.BackgroundTransparency=1; furyText.Size=UDim2.fromScale(1,1)
furyText.Font=Enum.Font.GothamBold; furyText.TextSize=10; furyText.TextColor3=Color3.new(1,1,1); furyText.Text="Fury 50"
furyText.ZIndex=2; furyText.Parent=furyBack
-- v49 Super meter, just above the Fury bar; it glows when the super (key 5) is ready.
do
 local back=Instance.new("Frame"); back.Name="Super"; back.BackgroundColor3=Color3.fromRGB(20,20,45); back.BorderSizePixel=0
 back.AnchorPoint=Vector2.new(0.5,1); back.Position=UDim2.new(0.5,0,1,-88); back.Size=UDim2.fromOffset(300,10); back.Parent=gui
 local fill=Instance.new("Frame"); fill.BackgroundColor3=Color3.fromRGB(90,150,255); fill.BorderSizePixel=0
 fill.Size=UDim2.fromScale(0,1); fill.Parent=back
 local text=Instance.new("TextLabel"); text.BackgroundTransparency=1; text.Size=UDim2.fromScale(1,1)
 text.Font=Enum.Font.GothamBold; text.TextSize=9; text.TextColor3=Color3.new(1,1,1); text.Text="Super 0%"; text.ZIndex=2; text.Parent=back
 Sig.superFill=fill; Sig.superText=text; back.Visible=false
end
-- Round display: timer and score at the top, a big banner for round start / K.O. / time.
-- R64h (Peter: "move the practice bar completely to the side and make it disappear"): the round line sits at the
-- top-left under the Roblox buttons; the practice hint fades out after 4 seconds (round timer and score stay).
local roundLabel=label("Round",UDim2.new(0,12,0,6),UDim2.fromOffset(UIS.TouchEnabled and 230 or 300,UIS.TouchEnabled and 34 or 26),"")
roundLabel.Font=Enum.Font.GothamBold; roundLabel.Visible=false; roundLabel.BackgroundTransparency=0.55
roundLabel.TextXAlignment=Enum.TextXAlignment.Left; roundLabel.TextSize=UIS.TouchEnabled and 11 or 13
do local pad=Instance.new("UIPadding"); pad.PaddingLeft=UDim.new(0,8); pad.PaddingRight=UDim.new(0,8); pad.Parent=roundLabel
 local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=roundLabel end
local banner=Instance.new("TextLabel"); banner.Name="Banner"; banner.BackgroundTransparency=1
-- R60: the round banner (3-2-1, FIGHT, K.O.) sits at the top under the timer, smaller, and fades (was mid-screen).
banner.AnchorPoint=Vector2.new(0.5,0); banner.Position=UDim2.new(0.5,0,0,106); banner.Size=UDim2.fromOffset(600,40)
banner.Font=Enum.Font.GothamBlack; banner.TextSize=UIS.TouchEnabled and 24 or 30; banner.TextColor3=Color3.fromRGB(255,215,90)
banner.TextStrokeTransparency=0.2; banner.TextTransparency=1; banner.TextStrokeColor3=Color3.new(0,0,0); banner.Parent=gui
local pausedNow=false
local bannerTween
local function showBanner(text)
 if bannerTween then bannerTween:Cancel() end
 banner.Text=text; banner.TextTransparency=0.1; banner.TextStrokeTransparency=0.4
 -- Countdown numbers are short and punchy; PAUSED stays up until the match resumes.
 if text=="PAUSED" then return end
 local hold=(text=="1" or text=="2" or text=="3") and 0.35 or 1.6
 bannerTween=TweenService:Create(banner,TweenInfo.new(0.5,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,hold),{TextTransparency=1,TextStrokeTransparency=1})
 bannerTween:Play()
end
Sig.captureKey=function(name)
 local target=capturing; capturing=nil; captureEndedAt=os.clock()
 if name=="Backspace" then
  binds[target.id][target.slot]=""
  status.Text="Key cleared."
 elseif not validKey(name,target.id) then
  status.Text=keyText(name).." is reserved for movement, chat or menus."
 else
  -- One key, one action: take it away from whatever had it before.
  local moved=false
  for id,pair in binds do for i,k in pair do if k==name and not (id==target.id and i==target.slot) then pair[i]=""; moved=true end end end
  binds[target.id][target.slot]=name
  status.Text=keyText(name)..(moved and " bound (removed from its old action)." or " bound.")
 end
 applyBindings(); refreshMenu(); saveBinds()
end
UIS.InputBegan:Connect(function(io)
 if not capturing then return end
 if io.UserInputType==Enum.UserInputType.Keyboard then Sig.captureKey(io.KeyCode.Name)
 elseif io.UserInputType==Enum.UserInputType.MouseButton3 then Sig.captureKey("MouseButton3") end
end)
-- v49: the mouse wheel. While binding it sets the key; in play a wheel notch is one press of its action.
UIS.InputChanged:Connect(function(io,processed)
 if io.UserInputType~=Enum.UserInputType.MouseWheel then return end
 local name=io.Position.Z>0 and "WheelUp" or "WheelDown"
 if capturing then Sig.captureKey(name); return end
 if processed or menuOpen then return end
 for _,a in ACTIONS do
  local pair=binds[a.id]
  if pair[1]==name or pair[2]==name then onBound(a.id,Enum.UserInputState.Begin); task.delay(0.05,function() onBound(a.id,Enum.UserInputState.End) end) end
 end
end)
-- R19 lobby (Peter: "a lobby where you can see each toon, the powers, the number behind and description,
-- also a visual you can rotate and change the skin"). Opens on join and from the Lobby button. The preview
-- body is built by the server (Preview) in the chosen skin and spun here in a viewport; drag to turn it.
do
 local HEROES={"Solarion","Wraithstep","Tempest","Bulwark","Valkyra","DreadKnight"} -- V59: Valkyra, V60: Dread Knight
 Sig.rigMove=function(m,f) -- V51: move a rig preview; a rig whose joints are connected moves as one piece, from its root
  local rr=m:FindFirstChild("HumanoidRootPart")
  if rr and #rr:GetConnectedParts(true)>0 then rr.CFrame=f(rr.CFrame)
  else for _,q in m:GetDescendants() do if q:IsA("BasePart") then q.CFrame=f(q.CFrame) end end end
 end
 local ROLE={
  Solarion="Flying bruiser. Punch combos up close, photon pulses at range from Solar Hammer; leaps in with Pounce and lights up hidden enemies.",
  Wraithstep="Stealth assassin. No flight; pulls flyers down with his bats, vanishes, and hits harder from the shadows and inside his circle.",
  Tempest="Storm caster. A quick spark combo up close and long-reaching casts from the air; Gale pushes attackers away and Whirlwind locks one enemy down.",
  Bulwark="Armoured tank. Most health, no flight; breaks guards, charges or leaps at flyers, and parries with his shield.",
  DreadKnight="Death knight. No flight; a heavy great-sword combo and a guard-breaking cleave, chains that drag enemies in, a leaping strike that drains life, and a ring of cold blight.",
  Valkyra="Winged shieldmaiden. Flies; a quick spear combo, a javelin of light at range, dives from above and dashes through foes on her wings.",
 }
 local DESC={
  Solarion={Light="Three-hit punch combo. The third hit knocks back.",Heavy="Half-second charge, then three photon pulses fly out at range. Each pulse is a hit; an interrupt or a hit during the charge cancels it.",Interrupt="Fast sun-fist strike. Stops a cast and locks that power for 4 seconds.",
   Skill2="Crouch and leap at your target. A direct hit pins them; landing splashes everyone near.",Dash="Quick dodge in the direction you're moving.",
   Flight="Take off or land. Space rises, X descends. Uses flight energy.",Defensive="Golden shield for 4 seconds: you take no damage until it has soaked 30, then it burns off. You can attack, move and fly with it up. Breaks stuns; 14 s cooldown.",
   Skill3="Solar Absorb: a glowing sphere around you for 8 seconds. Enemies inside lose 2 health every half second and you gain it. 18 s cooldown."},
  Wraithstep={Light="Quick three-hit shadow claw combo.",Heavy="Twisting scythe slash that leaves a Soul Drain: 2 damage every half second for 3 seconds, and every point drained heals you.",Skill1="Two shadow bats drag the target to your feet and stun them for 2 seconds (3 if caught jumping). Pulls a flyer out of the air.",
   Skill2="Phase: vanish for 8 seconds, but you glitch into view for a moment at 2 and 5 seconds. While phased, your combo key fires Shade Bolts (40 studs, locks on): each leaves a shadow tick (2 every half second for 3 s) that heals you. Up to 3 stack on one target (a 4th replaces the oldest), and they add to Soul Drain. Attacking or being hit doesn't reveal you until Phase ends. 18 s cooldown.",Interrupt="Fast throat strike. Stops a cast and locks that power for 4 seconds.",
   Defensive="Breaks stuns and turns you invisible for 6 seconds. Attacking or being hit ends it. Your first hit from hiding deals 25% extra.",
   Skill3="Cast a shadow circle on the ground for 8 seconds. Enemies inside it burn (2 damage every half second) and your hits on them deal 50% extra."},
  Tempest={Light="Quick three-hit spark combo that reaches 20 studs.",Heavy="A storm-charged fist that reaches 22 studs. No cast. Leaves a lightning tick (3 damage every half second for 3 s) and gives you a heal stack.",Skill1="1.5-second cast, then a lightning bolt at long range. Leaves a lightning tick and gives you a heal stack. Each stack (up to 6) makes your ticks heal you 12.5% of their damage.",
   Skill2="Lightning Snare: locks onto the enemy you aim at; lightning bursts up from the ground and holds them in place (even in the air) for 2 seconds. Leaves a lightning tick. 15 s cooldown.",Flight="Ride a storm cloud. Space rises, X descends. Uses flight energy.",
   Defensive="Tailwind: blink a short distance, untouchable for a moment. Breaks stuns; 15 s cooldown.",Skill3="Cooldown starts at 4 s and grows 4 s with each cast (up to 20 s); 10 s unused resets it. An instant whirlwind that locks onto the enemy you aim at (up to 60 studs) and lifts and spins them for 4 seconds. Nobody can damage them while they spin, but they take a lightning tick the whole time, and anyone within 8 studs of them is caught too. A defensive only cuts the spin in half. Casting it wraps you in a mist cloud: 50% less damage for 12 seconds."},
  Bulwark={Light="Shield-and-fist combo.",Interrupt="Shield Throw: hurl your shield like a frisbee up to 35 studs; it spins back to your hand. Knocks a flyer out of the air, and stops a cast (locks that power for 4 seconds).",Heavy="Overhead sword cleave that cracks the ground. Every hit you land is a Juggernaut stack (faster, harder); at 5 stacks this becomes a 20-stud shockwave.",Skill1="Holy ground slam all around you that can't be blocked. stuns everyone it hits for 0.8 s, lights up everyone nearby in gold for 2 s so they can't hide, and makes you 40% faster for 3 s.",
   Skill2="Unstoppable shoulder charge: hits can't stop it, it carries the target, and driving them into a wall stuns them and deals extra damage. Aim up at a flyer and it becomes a leap that slams them down.",
   Defensive="Raise the shield for 1 second. Every blow that lands on it, close up or from range, is reflected back at the attacker for its full damage, and they reel. Your first parry also gives Fury, readies Charge, a 25-point shield for 6.5 s and 3 s in which every blow you parry heals you 25% of it. A landed parry is ready again in 6 s.",
   Skill3="1-second cast, then teleport beside your target from up to 65 studs, even one in the air, and slam on arrival. The slam hits everyone close and drives a flyer into the floor."},
  -- V59 Valkyra
  Valkyra={Light="Three-hit spear and shield combo: Spear Jab, Shield Bash, then Rising Wing, a spinning leap kick that lifts.",Heavy="Valhalla Thrust: a lunging spear thrust that reaches 10 studs.",
   Skill1="Javelin of Light: throw a spear of light in a straight line up to 40 studs. Knocks a flyer out of the air.",
   Skill2="Valkyrie Dive: leap up and dive onto the enemy in front of you. A direct hit pins them; the landing splashes everyone near.",
   Skill3="Winged Rush: a wing-boosted 16-stud dash through the enemy. You can't be hit for the first moment of it.",Dash="Quick dodge in the direction you're moving.",
   Flight="Take off or land on your wings. Space rises, X descends. Uses flight energy.",
   Defensive="Aegis Wings: your wings fold round your shield for 2 seconds and you take 60% less damage. Breaks stuns; 18 s cooldown."},
  -- V60 Dread Knight
  DreadKnight={Light="Three-hit great-sword combo: Reaper's Cut, Grave Slash, then Bone Breaker, which knocks back.",Heavy="Doom Cleave: a two-handed overhead cleave that breaks guard.",
   Skill1="Death Grip: chains of cold fire drag the enemy you aim at to your feet from up to 40 studs and hold them a second. Pulls a flyer out of the air.",
   Skill2="Soul Reaper: leap onto the enemy in front of you. The strike leaves a soul drain: 2 damage every half second for 3 seconds, and you heal what it drains.",
   Skill3="Blight Ground: a ring of cold blight around you for 6 seconds. Enemies inside burn and take 25% more damage from you.",
   Interrupt="Grave Strike: a fast pommel strike. Stops a cast and locks that power for 4 seconds.",Dash="Quick dodge in the direction you're moving.",
   Defensive="Bone Armour: you take no damage until it has soaked 30, for 4 seconds. Breaks stuns; 18 s cooldown."},
 }
 local function stats(hero,id)
  local name=id=="Light" and "Light1" or (id=="Heavy" or id=="Skill1" or id=="Skill2" or id=="Skill3" or id=="Interrupt") and Rules.moveName(hero,id,1) or nil
  local move=name and Rules.heroMove(hero,name)
  local title=name and Rules.title(hero,name) or nil
  local d=Rules.Defensives[hero]
  if id=="Defensive" and d then return d.Name,string.format("Cooldown %ds",math.floor(d.Cooldown/60)) end
  if id=="Dash" then return "Dodge","" end
  if id=="Flight" then return "Fly","" end
  if not move then return title or id,"" end
  local bits={}
  if move.Cast and move.Startup>=30 then table.insert(bits,string.format("Cast %.1fs",move.Startup/60)) end
  if (move.Damage or 0)>0 then table.insert(bits,"Damage "..math.floor(move.Damage+0.5)) end
  if (move.Cooldown or 0)>=60 then table.insert(bits,string.format("Cooldown %gs",math.floor(move.Cooldown/6)/10)) end
  if move.Cost then table.insert(bits,move.Cost.." Fury") end
  if (move.Range or 0)>=12 then table.insert(bits,"Range "..math.floor(move.Range)) end
  return title,table.concat(bits," • ")
 end
 -- The number each power is on: your own keys for the hero you're playing, else the automatic 1, 2, 3... order.
 local function keyFor(hero,id,n)
  local current=player.Character and player.Character:GetAttribute("Hero")
  if hero==current then local pair=binds[id]; return keyText(pair[1]~="" and pair[1] or pair[2]) end
  return tostring(n%10)
 end
 local lobby=Instance.new("Frame"); lobby.Name="Lobby"; lobby.AnchorPoint=Vector2.new(0.5,0.5); lobby.Position=UDim2.fromScale(0.5,0.5)
 lobby.Size=UDim2.new(0.94,0,0.92,0); lobby.BackgroundColor3=Color3.fromRGB(12,15,24); lobby.BackgroundTransparency=0.08; lobby.ZIndex=20; lobby.Parent=gui
 do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,16); c.Parent=lobby
  local s=Instance.new("UISizeConstraint"); s.MaxSize=Vector2.new(1440,880); s.Parent=lobby -- R64: bigger lobby (was 1100x680)
  local st=Instance.new("UIStroke"); st.Color=Color3.fromRGB(255,215,120); st.Transparency=0.7; st.Thickness=1.5; st.Parent=lobby
  local g=Instance.new("UIGradient"); g.Rotation=90; g.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(170,175,195)); g.Parent=lobby end
 -- R64k (Peter's S22 Ultra screenshot: the lobby ran off a short phone screen): the whole lobby is scaled to the
 -- screen height (760 tall = full size, never under 55%), and its frame grows by the same amount so it still
 -- fills 94% x 92% of the screen. The fade-in UIScale (end of the script) tweens up to this BaseScale.
 do
  local fitScale=Instance.new("UIScale"); fitScale.Name="FitScale"; fitScale.Parent=lobby
  local function fitLobby()
   local h=gui.AbsoluteSize.Y; if h<50 then return end
   local k=math.clamp(h/760,0.55,1)
   lobby:SetAttribute("BaseScale",k); fitScale.Scale=k
   lobby.Size=UDim2.new(0.94/k,0,0.92/k,0)
  end
  fitLobby(); gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitLobby)
 end
 local function txt(parent,name,pos,size,text,sz,font,col,xa)
  local t=Instance.new("TextLabel"); t.Name=name; t.Position=pos; t.Size=size; t.BackgroundTransparency=1; t.Text=text
  t.TextSize=sz; t.Font=font or Enum.Font.Gotham; t.TextColor3=col or Color3.fromRGB(235,235,245); t.TextWrapped=true
  t.TextXAlignment=xa or Enum.TextXAlignment.Left; t.TextYAlignment=Enum.TextYAlignment.Top; t.ZIndex=21; t.Parent=parent; return t
 end
 txt(lobby,"Title",UDim2.fromOffset(24,14),UDim2.new(1,-90,0,38),"HEROWARS • CHOOSE YOUR HERO",30,Enum.Font.GothamBlack)
 local close=button("Close",lobby,UDim2.new(1,-58,0,12),UDim2.fromOffset(46,42),"X",Color3.fromRGB(110,40,40)); close.ZIndex=22
 -- Hero tabs down the left.
 local tabs={}
 for i,h in HEROES do
  local b=button(h,lobby,UDim2.fromOffset(24,68+(i-1)*72),UDim2.fromOffset(184,62),Rules.display(h),HERO_BUTTON_COLORS[h]); b.ZIndex=22; b.TextSize=22; tabs[h]=b
 end
 -- The spinning preview in the middle.
 local view=Instance.new("ViewportFrame"); view.Name="Preview"; view.Position=UDim2.fromOffset(224,68); view.Size=UDim2.new(0.34,0,1,-184)
 view.BackgroundColor3=Color3.fromRGB(28,34,50); view.Ambient=Color3.fromRGB(150,150,165); view.LightColor=Color3.fromRGB(255,250,240)
 view.LightDirection=Vector3.new(-1,-1,-1.5); view.ZIndex=21; view.Parent=lobby
 do local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=view end
 local cam=Instance.new("Camera"); cam.FieldOfView=30; cam.Parent=view; view.CurrentCamera=cam
 local world=Instance.new("WorldModel"); world.Parent=view
 local loading=txt(view,"Loading",UDim2.new(0,0,0,8),UDim2.new(1,0,0,30),"Loading look…",19,Enum.Font.GothamBold,nil,Enum.TextXAlignment.Center)
 txt(view,"Hint",UDim2.new(0,0,1,-28),UDim2.new(1,0,0,22),"Drag to turn",15,Enum.Font.Gotham,Color3.fromRGB(170,175,195),Enum.TextXAlignment.Center)
 local skinRow=Instance.new("Frame"); skinRow.BackgroundTransparency=1; skinRow.Position=UDim2.new(0,224,1,-108); skinRow.Size=UDim2.new(0.34,0,0,42); skinRow.ZIndex=21; skinRow.Parent=lobby
 local prev=button("PrevSkin",skinRow,UDim2.new(),UDim2.fromOffset(50,42),"<",Color3.fromRGB(60,60,85)); prev.ZIndex=22
 local nextB=button("NextSkin",skinRow,UDim2.new(1,-50,0,0),UDim2.fromOffset(50,42),">",Color3.fromRGB(60,60,85)); nextB.ZIndex=22
 local skinName=txt(skinRow,"SkinName",UDim2.fromOffset(54,8),UDim2.new(1,-108,0,28),"",19,Enum.Font.GothamBold,nil,Enum.TextXAlignment.Center)
 local play=button("Play",lobby,UDim2.new(0,224,1,-58),UDim2.new(0.34,0,0,46),"PLAY",Color3.fromRGB(40,120,60)); play.ZIndex=22; play.TextSize=21
 -- Hero info and the power list on the right.
 local info=Instance.new("Frame"); info.BackgroundTransparency=1; info.Position=UDim2.new(0.34,244,0,68); info.Size=UDim2.new(0.66,-268,1,-84); info.ZIndex=21; info.Parent=lobby
 local heroName=txt(info,"Hero",UDim2.new(),UDim2.new(1,0,0,38),"",32,Enum.Font.GothamBlack)
 local heroLine=txt(info,"Line",UDim2.fromOffset(0,40),UDim2.new(1,0,0,24),"",18,Enum.Font.GothamBold,Color3.fromRGB(255,200,110))
 local role=txt(info,"Role",UDim2.fromOffset(0,68),UDim2.new(1,0,0,52),"",17)
 local list=Instance.new("ScrollingFrame"); list.Position=UDim2.fromOffset(0,128); list.Size=UDim2.new(1,0,1,-128); list.BackgroundTransparency=1
 list.BorderSizePixel=0; list.ScrollBarThickness=6; list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.new(); list.ZIndex=21; list.Parent=info
 do local l=Instance.new("UIListLayout"); l.Padding=UDim.new(0,8); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Parent=list end
 local sel={hero=nil,skin={},yaw=0,drag=false,token=0,model=nil}
 local function showModel()
  sel.token+=1; local token=sel.token
  local hero=sel.hero; local id=sel.skin[hero]
  local key=hero.."|"..id
  -- R22: the last look stays up until the new one is ready (no blank frame), and the skins either side
  -- are asked for too so the arrows feel instant.
  local folder=RS.HeroWars:FindFirstChild("Previews")
  local ready=folder and folder:FindFirstChild(key)
  if sel.model and (not ready) and sel.modelHero~=hero then sel.model:Destroy(); sel.model=nil end
  -- R65 (Peter: "the skins' 3D models take time to load; show an image or something first, then the 3D"):
  -- while a look downloads, the hero's default look (loaded before the welcome screen closes) stands in,
  -- repainted in the new skin's colours, with a strip of those colours under the name. The real 3D look
  -- replaces it the moment it arrives.
  do
   local skin=Rules.skin(hero,id)
   if not sel.swatch then
    local strip=Instance.new("Frame"); strip.Name="Swatches"; strip.BackgroundTransparency=1; strip.AnchorPoint=Vector2.new(0.5,0)
    strip.Position=UDim2.new(0.5,0,0,42); strip.Size=UDim2.fromOffset(6*30,22); strip.ZIndex=22; strip.Parent=view
    local l=Instance.new("UIListLayout"); l.FillDirection=Enum.FillDirection.Horizontal; l.Padding=UDim.new(0,6); l.HorizontalAlignment=Enum.HorizontalAlignment.Center; l.Parent=strip
    sel.swatch=strip
   end
   for _,ch in sel.swatch:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
   for i,zone in {"Primary","Secondary","Metal","Accent","Emissive","Dark"} do
    local hex=skin and skin.Palette[zone]
    if hex then
     local f=Instance.new("Frame"); f.LayoutOrder=i; f.Size=UDim2.fromOffset(22,22); f.BackgroundColor3=Color3.fromHex(hex); f.ZIndex=22; f.Parent=sel.swatch
     local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0.5,0); c.Parent=f
     local st=Instance.new("UIStroke"); st.Color=Color3.new(1,1,1); st.Transparency=0.5; st.Parent=f
    end
   end
   local baseId=Rules.Skins[hero].Order[1]
   local base=folder and folder:FindFirstChild(hero.."|"..baseId)
   if not ready and base and skin then
    if sel.model then sel.model:Destroy() end
    local m=base:Clone()
    -- Repaint: each part takes the new skin's colour for whichever default colour it is closest to.
    local from=Rules.skin(hero,baseId).Palette
    for _,d in m:GetDescendants() do
     if d:IsA("BasePart") then
      local best,bestD=nil,0.08
      for zone,hex in from do
       local c=Color3.fromHex(hex); local dd=math.abs(c.R-d.Color.R)+math.abs(c.G-d.Color.G)+math.abs(c.B-d.Color.B)
       if dd<bestD and skin.Palette[zone] then best,bestD=zone,dd end
      end
      if best then d.Color=Color3.fromHex(skin.Palette[best]) end
     end
    end
    m.Parent=world; sel.model=m; sel.modelHero=hero
    local cf,size=m:GetBoundingBox(); local h=math.max(size.Y,4)
    sel.center=cf.Position
    cam.CFrame=CFrame.lookAt(sel.center+Vector3.new(0,h*0.08,-h*2.1),sel.center)
    m:PivotTo(CFrame.Angles(0,sel.yaw,0))
   end
  end
  local pf=RS.HeroWars:FindFirstChild("Previews")
  loading.Text=pf and pf:GetAttribute("Total") and string.format("Preparing skins %d/%d…",#pf:GetChildren(),pf:GetAttribute("Total")) or "Loading look…"
  loading.Visible=not ready
  if not ready then loading.Text="Loading 3D look… (colour preview)" end
  if not ready then remote:FireServer("Preview",{hero=hero,skin=id}) end
  local order=Rules.Skins[hero].Order; local i=table.find(order,id) or 1
  for _,n in {i%#order+1,(i-2)%#order+1} do
   if not (folder and folder:FindFirstChild(hero.."|"..order[n])) then remote:FireServer("Preview",{hero=hero,skin=order[n]}) end
  end
  task.spawn(function()
   folder=folder or RS.HeroWars:WaitForChild("Previews",10)
   local src=folder and (folder:FindFirstChild(key) or folder:WaitForChild(key,30))
   if token~=sel.token then return end
   if not src then loading.Text="Look could not load"; return end
   if sel.model then sel.model:Destroy() end
   local m=src:Clone(); m.Parent=world; sel.model=m; sel.modelHero=hero; loading.Visible=false
   local cf,size=m:GetBoundingBox()
   local h=math.max(size.Y,4)
   sel.center=cf.Position
   -- V49: a skinned rig's clone keeps its stored part CFrames (far from the origin) and PivotTo does not move skinned
   -- parts, so shift every part to put the root at the origin, and frame from the root and hip height instead of the
   -- bounding box (which is the unposed mesh: sideways and oversized).
   local rr=m:FindFirstChild("HumanoidRootPart"); local rh=m:FindFirstChildOfClass("Humanoid")
   if rr and rr:IsA("MeshPart") and rr.HasSkinnedMesh==false and rh and m:FindFirstChild("UpperTorso") and m.UpperTorso:IsA("MeshPart") and m.UpperTorso.HasSkinnedMesh then
    local d=rr.CFrame.Position
    Sig.rigMove(m,function(cf) return cf-d end)
    h=(rh.HipHeight+rr.Size.Y/2)*2; sel.center=Vector3.new(0,rr.Size.Y/2+rh.HipHeight-h/2+0.3,0)
    m:SetAttribute("RigPreview",true)
   end
   cam.CFrame=CFrame.lookAt(sel.center+Vector3.new(0,h*0.08,-h*2.1),sel.center)
   if m:GetAttribute("RigPreview") then sel.rigYaw=sel.yaw; Sig.rigMove(m,function(cf) return CFrame.Angles(0,sel.yaw,0)*cf end)
   else m:PivotTo(CFrame.Angles(0,sel.yaw,0)) end
  end)
 end
 local function showHero(hero)
  sel.hero=hero
  for h,b in tabs do b.BorderSizePixel=h==hero and 3 or 0; b.BorderColor3=Color3.new(1,1,1); b.BackgroundTransparency=h==hero and 0 or 0.35
   -- R64: rounded tabs can't show a border, so the chosen hero gets a bright gold edge instead.
   b:SetAttribute("Selected",h==hero)
   local st=b:FindFirstChildOfClass("UIStroke"); if st then st.Color=h==hero and Color3.fromRGB(255,215,120) or Color3.new(1,1,1); st.Thickness=h==hero and 3 or 1; st.Transparency=h==hero and 0 or 0.82 end
  end
  local set=Rules.Skins[hero]
  if not sel.skin[hero] then
   local current=player.Character and player.Character:GetAttribute("Hero")==hero and player.Character:GetAttribute("Skin")
   local _,id=Rules.skin(hero,current or set.Order[1]); sel.skin[hero]=id
  end
  local skin=Rules.skin(hero,sel.skin[hero])
  skinName.Text=string.format("%s  (%d/%d)",skin.Name,table.find(set.Order,sel.skin[hero]) or 1,#set.Order)
  local c=Rules.Characters[hero]
  heroName.Text=Rules.display(hero)
  heroLine.Text=string.format("Health %d  •  %s",c.Health,c.Flies and "Can fly" or "Ground fighter")
  role.Text=ROLE[hero] or ""
  local current=player.Character and player.Character:GetAttribute("Hero")
  play.Text=current==hero and "WEAR THIS SKIN" or "PLAY AS "..string.upper(Rules.display(hero))
  for _,ch in list:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
  local n=0
  for _,a in ACTIONS do
   if a.bar and Rules.actionAvailable(hero,a.id) and not (a.id=="Skill3" and not Rules.moveName(hero,"Skill3",1)) and not (a.id=="Flight" and not c.Flies) then
    n+=1
    local row=Instance.new("Frame"); row.Name=a.id; row.LayoutOrder=n; row.Size=UDim2.new(1,-12,0,84); row.AutomaticSize=Enum.AutomaticSize.Y; row.BackgroundColor3=Color3.fromRGB(26,31,46); row.ZIndex=21; row.Parent=list
    do local rc=Instance.new("UICorner"); rc.CornerRadius=UDim.new(0,10); rc.Parent=row
     local rp=Instance.new("UIPadding"); rp.PaddingBottom=UDim.new(0,10); rp.Parent=row end
    local k=txt(row,"Key",UDim2.fromOffset(10,12),UDim2.fromOffset(56,56),keyFor(hero,a.id,n),28,Enum.Font.GothamBlack,Color3.fromRGB(20,20,28),Enum.TextXAlignment.Center)
    k.BackgroundTransparency=0; k.BackgroundColor3=Color3.fromRGB(255,205,90); k.TextYAlignment=Enum.TextYAlignment.Center
    do local kc=Instance.new("UICorner"); kc.CornerRadius=UDim.new(0,6); kc.Parent=k end
    local title,line=stats(hero,a.id)
    txt(row,"Name",UDim2.fromOffset(78,6),UDim2.new(0.5,-78,0,26),title or a.name,20,Enum.Font.GothamBold)
    txt(row,"Stats",UDim2.new(0.5,0,0,8),UDim2.new(0.5,-10,0,22),line or "",15,Enum.Font.Gotham,Color3.fromRGB(255,200,110),Enum.TextXAlignment.Right)
    txt(row,"Desc",UDim2.fromOffset(78,34),UDim2.new(1,-90,0,0),(DESC[hero] and DESC[hero][a.id]) or "",16,Enum.Font.Gotham,Color3.fromRGB(215,220,232)).AutomaticSize=Enum.AutomaticSize.Y
   end
  end
  showModel()
 end
 local function stepSkin(dir)
  local set=Rules.Skins[sel.hero]; local i=table.find(set.Order,sel.skin[sel.hero]) or 1
  local _,id=Rules.skin(sel.hero,set.Order[(i-1+dir)%#set.Order+1]); sel.skin[sel.hero]=id; showHero(sel.hero)
 end
 prev.Activated:Connect(function() stepSkin(-1) end)
 nextB.Activated:Connect(function() stepSkin(1) end)
 for h,b in tabs do b.Activated:Connect(function() showHero(h) end) end
 play.Activated:Connect(function()
  local hero=sel.hero; local id=sel.skin[hero]
  local current=player.Character and player.Character:GetAttribute("Hero")
  if current==hero then remote:FireServer("Skin",id)
  else remote:FireServer("PickSkin",{hero=hero,skin=id}); remote:FireServer("Select",hero) end
  lobby.Visible=false
 end)
 close.Activated:Connect(function() lobby.Visible=false end)
 view.InputBegan:Connect(function(io)
  if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then sel.drag=true; sel.dragX=io.Position.X end
 end)
 UIS.InputEnded:Connect(function(io)
  if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then sel.drag=false end
 end)
 UIS.InputChanged:Connect(function(io)
  if sel.drag and (io.UserInputType==Enum.UserInputType.MouseMovement or io.UserInputType==Enum.UserInputType.Touch) then
   sel.yaw+=(io.Position.X-(sel.dragX or io.Position.X))*0.012; sel.dragX=io.Position.X; sel.spinAt=os.clock()+2
  end
 end)
 RunService.RenderStepped:Connect(function(dt)
  if not lobby.Visible or not sel.model then return end
  if not sel.drag and os.clock()>(sel.spinAt or 0) then sel.yaw+=dt*0.6 end
  if sel.model:GetAttribute("RigPreview") then
   -- V49: the spin is applied as a delta so the rig's own part CFrames stay consistent.
   local dy=sel.yaw-(sel.rigYaw or 0); sel.rigYaw=sel.yaw
   Sig.rigMove(sel.model,function(cf) return CFrame.Angles(0,dy,0)*cf end)
  else sel.model:PivotTo(CFrame.Angles(0,sel.yaw,0)) end
 end)
 local open=function()
  lobby.Visible=true
  showHero((player.Character and player.Character:GetAttribute("Hero")) or sel.hero or "Solarion")
 end
 -- The Lobby button joins the hero row (top of the side panel since R41).
 local lb=button("Lobby",heroRow,UDim2.fromOffset(0,0),UDim2.fromOffset(127,40),"Lobby",Color3.fromRGB(150,110,30)); lb.TextSize=16
 lb.Activated:Connect(function() if lobby.Visible then lobby.Visible=false else open() end end) -- R66-ui7: on phones the layout swaps the MENU tiles out while the lobby is open (was: MENU closed) -- R64k: on phones the menu closes so it does not cover the lobby
 Sig.openLobby=open
 -- R66-ui (Peter: "remove the loading screen at the startup, a fast startup for both"): no welcome screen and no
 -- lobby on join; you spawn straight into the arena and skins keep downloading in the background. Pick a hero
 -- from MENU > Lobby. (The R35-R47 welcome screen waited for 10% of the skins, 5 s at least.)
end
applyBindings()
remote:FireServer("LoadBinds")
UIS.WindowFocusReleased:Connect(function() flyUp=false; flyDown=false; table.clear(Sig.walkHeld) end)
UIS.TextBoxFocused:Connect(function() table.clear(Sig.walkHeld) end)
local function onCharacter(model)
 flying=false; flyUp=false; flyDown=false
 task.defer(refreshSkin)
 model:GetAttributeChangedSignal("Skin"):Connect(refreshSkin)
 local hum=model:WaitForChild("Humanoid")
 -- R61 (Peter: "they lie down sometimes"): this client runs its own fighter's physics, so the fall-over and
 -- ragdoll states are turned off here too (the server turns them off for bots).
 for _,st in {Enum.HumanoidStateType.FallingDown,Enum.HumanoidStateType.Ragdoll} do hum:SetStateEnabled(st,false) end
 workspace.CurrentCamera.CameraSubject=hum; workspace.CurrentCamera.CameraType=Enum.CameraType.Custom
end
player.CharacterAdded:Connect(onCharacter)
if player.Character then task.spawn(onCharacter,player.Character) end
-- Movement intent comes straight from the player's input, not Humanoid.MoveDirection:
-- the root is server-owned and the server's own Move() replicates back into MoveDirection.
local controls
task.spawn(function()
 local ok,module=pcall(function() return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule",10)) end)
 if ok and module then controls=module:GetControls() else warn("HeroWars: PlayerModule not found; using MoveDirection") end
end)
local function moveIntent(hum,camera)
 -- R65: the walk keys are read by this client (Sig.walkHeld); the stick and touch pad still come from PlayerModule.
 local w=Sig.walkVec()
 if not controls and w.Magnitude<0.01 then return hum.MoveDirection end
 local v=(controls and controls:GetMoveVector() or Vector3.zero)+w
 if v.Magnitude>1 then v=v.Unit end
 local look=camera.CFrame.LookVector; local right=camera.CFrame.RightVector
 look=Vector3.new(look.X,0,look.Z); right=Vector3.new(right.X,0,right.Z)
 if look.Magnitude>0.01 then look=look.Unit end
 if right.Magnitude>0.01 then right=right.Unit end
 return right*v.X-look*v.Z
end
-- WoW-style targeting: click a fighter (or press Tab) to target it; abilities then aim at it.
local currentTarget=nil
local targetHighlight=nil
local targetRing=fxPart(Enum.PartType.Cylinder,Vector3.new(0.15,5,5),CFrame.new(0,-100,0),Color3.fromRGB(255,70,60),0.35)
targetRing.Transparency=1
local targetFrame=Instance.new("Frame"); targetFrame.Name="TargetFrame"; targetFrame.AnchorPoint=Vector2.new(0.5,0)
-- R64g (Peter: "move the opponent health bar to the top, same level as Roblox and MENU"): it lives in the
-- inset-free HeroWarsTop ScreenGui, top centre, level with the Roblox button.
targetFrame.Position=UDim2.new(0.5,0,0,10); targetFrame.Size=UDim2.fromOffset(280,62)
targetFrame.BackgroundColor3=Color3.fromRGB(15,20,31); targetFrame.BackgroundTransparency=0.15; targetFrame.Visible=false; targetFrame.Parent=menuToggle.Parent
do local targetStroke=Instance.new("UIStroke"); targetStroke.Color=Color3.fromRGB(255,90,70); targetStroke.Thickness=1.5; targetStroke.Parent=targetFrame end
-- R64e (Peter: "make the target box smaller"): 70% size on phones, 85% on desktop, a little more see-through.
do local sc=Instance.new("UIScale"); sc.Scale=UIS.TouchEnabled and 0.55 or 0.85; sc.Parent=targetFrame
 targetFrame.BackgroundTransparency=0.3
 local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,8); c.Parent=targetFrame end
local targetName=Instance.new("TextLabel"); targetName.BackgroundTransparency=1; targetName.Position=UDim2.fromOffset(10,4)
targetName.Size=UDim2.fromOffset(200,20); targetName.Font=Enum.Font.GothamBold; targetName.TextSize=15
targetName.TextXAlignment=Enum.TextXAlignment.Left; targetName.TextColor3=Color3.new(1,1,1); targetName.Parent=targetFrame
local targetRange=Instance.new("TextLabel"); targetRange.BackgroundTransparency=1; targetRange.Position=UDim2.fromOffset(150,4)
targetRange.Size=UDim2.fromOffset(95,20); targetRange.Font=Enum.Font.Gotham; targetRange.TextSize=12
targetRange.TextXAlignment=Enum.TextXAlignment.Right; targetRange.TextColor3=Color3.fromRGB(200,200,210); targetRange.Parent=targetFrame
local clearTarget=button("ClearTarget",targetFrame,UDim2.fromOffset(252,4),UDim2.fromOffset(22,20),"X",Color3.fromRGB(90,40,40))
clearTarget.TextSize=12
local hpBack=Instance.new("Frame"); hpBack.BackgroundColor3=Color3.fromRGB(45,20,20); hpBack.BorderSizePixel=0
hpBack.Position=UDim2.fromOffset(10,30); hpBack.Size=UDim2.fromOffset(260,22); hpBack.Parent=targetFrame
local hpFill=Instance.new("Frame"); hpFill.BackgroundColor3=Color3.fromRGB(200,50,45); hpFill.BorderSizePixel=0
hpFill.Size=UDim2.fromScale(1,1); hpFill.Parent=hpBack
local hpText=Instance.new("TextLabel"); hpText.BackgroundTransparency=1; hpText.Size=UDim2.fromScale(1,1)
hpText.Font=Enum.Font.GothamBold; hpText.TextSize=13; hpText.TextColor3=Color3.new(1,1,1); hpText.ZIndex=2; hpText.Parent=hpBack
function myRootPart() local me=player.Character; return me and me:FindFirstChild("HumanoidRootPart") end
-- v28: is this fighter hidden from me (Vanish, or Shrouded in a shadow pool and far away)?
-- A Solar Flare's reveal (RevealEnd) shows them again.
hiddenFromMe=function(m)
 if not m or m==player.Character then return false end
 if (m:GetAttribute("RevealEnd") or 0)>workspace:GetServerTimeNow() then return false end
 if m:GetAttribute("Invisible") then return true end
 if m:GetAttribute("Shrouded") then
  local me=myRootPart(); local root=m:FindFirstChild("HumanoidRootPart")
  return me~=nil and root~=nil and (root.Position-me.Position).Magnitude>Rules.Shroud.Range
 end
 return false
end
local function targetAlive(m)
 local hum=m and m.Parent and m:FindFirstChildOfClass("Humanoid")
 return hum and hum.Health>0 and m:FindFirstChild("HumanoidRootPart")~=nil
end
setTarget=function(m)
 if m==player.Character then m=nil end
 if m==currentTarget then return end
 if targetHighlight then targetHighlight:Destroy(); targetHighlight=nil end
 currentTarget=m
 targetFrame.Visible=m~=nil
 targetRing.Transparency=1
 if m then
  local h=Instance.new("Highlight"); h.Name="TargetHighlight"; h.FillTransparency=1
  h.OutlineColor=Color3.fromRGB(255,70,60); h.OutlineTransparency=0; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
  h.Adornee=m; h.Parent=m; targetHighlight=h
  local who=m:GetAttribute("Hero") or m.Name
  local owner=Players:GetPlayerFromCharacter(m)
  targetName.Text=owner and (who.." • "..owner.DisplayName) or (who.." • Dummy")
 end
end
clearTarget.Activated:Connect(function() setTarget(nil) end)
Sig.getTarget=function() return currentTarget end
-- R63: in a duel only your opponent counts as a foe (others can't be hit); outside one, anyone not in a duel.
Sig.foe=function(m)
 local mine=player.Character and player.Character:GetAttribute("DuelId"); local theirs=m:GetAttribute("DuelId")
 if mine or theirs then return mine==theirs end
 return true
end
-- Living fighters I can see, nearest first. v43 (Peter: Tab didn't select anyone): Tab used to look only
-- within ability range (Rules.MaxRange, 40 studs), so at the start of a round nobody was close enough.
-- Like WoW it now picks any visible fighter in the arena; the target frame says when it's out of range.
local function targetsInRange()
 local myRoot=myRootPart(); local list={}
 if not myRoot then return list end
 for _,m in workspace:GetChildren() do
  if m:IsA("Model") and m~=player.Character and m:GetAttribute("Hero") and targetAlive(m) and not hiddenFromMe(m) and Sig.foe(m) then
   local d=(m.HumanoidRootPart.Position-myRoot.Position).Magnitude
   if d<=Rules.TabRange then table.insert(list,{model=m,dist=d}) end
  end
 end
 table.sort(list,function(a,b) return a.dist<b.dist end)
 return list
end
cycleTarget=function()
 local list=targetsInRange()
 if #list==0 then notice.Text="No fighters to target."; return end
 local index=0
 for i,entry in list do if entry.model==currentTarget then index=i end end
 local pick=list[index%#list+1]
 setTarget(pick.model)
 notice.Text=string.format("Target: %s • %d studs%s",pick.model:GetAttribute("Hero") or pick.model.Name,math.floor(pick.dist),pick.dist>Rules.MaxRange and " (out of range)" or "")
end
-- R63 (top-5 audit item 2): on a phone the nearest foe is targeted automatically, so ATTACK and the skills
-- aim at someone without tapping. A fighter you tap stays targeted while they're a foe and within range,
-- unless they're far off and another foe is close.
if UIS.TouchEnabled and not UIS.KeyboardEnabled then
 task.spawn(function()
  while true do
   task.wait(0.25)
   local list=targetsInRange()
   local near=list[1]
   local cur=currentTarget
   local keep=cur~=nil and targetAlive(cur) and not hiddenFromMe(cur) and Sig.foe(cur)
   if keep and near and near.model~=cur then
    local me=myRootPart(); local d=me and (cur.HumanoidRootPart.Position-me.Position).Magnitude or 0
    if d>Rules.MaxRange*1.5 and near.dist<=Rules.MaxRange then keep=false end
   end
   if not keep then setTarget(near and near.model or nil) end
  end
 end)
end
-- Click (or tap) a fighter to target it; clicking empty ground with the mouse clears the target.
UIS.InputBegan:Connect(function(io,processed)
 if io.KeyCode==Enum.KeyCode.Escape then setTarget(nil); return end
 if processed or menuOpen then return end
 local camera=workspace.CurrentCamera; if not camera then return end
 local ray
 if io.UserInputType==Enum.UserInputType.MouseButton1 then
  local loc=UIS:GetMouseLocation(); ray=camera:ViewportPointToRay(loc.X,loc.Y)
 elseif io.UserInputType==Enum.UserInputType.Touch then
  ray=camera:ScreenPointToRay(io.Position.X,io.Position.Y)
 else return end
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={player.Character,fxFolder}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*500,params)
 local model=hit and hit.Instance:FindFirstAncestorOfClass("Model")
 if model and model:GetAttribute("Hero") and targetAlive(model) and not hiddenFromMe(model) then setTarget(model)
 elseif io.UserInputType==Enum.UserInputType.MouseButton1 then setTarget(nil) end
end)
RunService.RenderStepped:Connect(function()
 if not currentTarget then return end
 if not targetAlive(currentTarget) or hiddenFromMe(currentTarget) then setTarget(nil); return end
 local hum=currentTarget:FindFirstChildOfClass("Humanoid"); local root=currentTarget.HumanoidRootPart
 hpFill.Size=UDim2.fromScale(math.clamp(hum.Health/hum.MaxHealth,0,1),1)
 hpText.Text=string.format("%d / %d",math.ceil(hum.Health),math.floor(hum.MaxHealth))
 local myRoot=myRootPart()
 local dist=myRoot and (root.Position-myRoot.Position).Magnitude or 0
 local inRange=dist<=Rules.MaxRange
 targetRange.Text=inRange and string.format("%d studs",math.floor(dist)) or "Out of range"
 targetRange.TextColor3=inRange and Color3.fromRGB(200,200,210) or Color3.fromRGB(255,110,90)
 targetRing.Transparency=0.35
 targetRing.CFrame=CFrame.new(root.Position-Vector3.new(0,2.9,0))*CFrame.Angles(0,0,math.pi/2)
end)
-- Abilities aim at the target while it is in range; otherwise at the camera's crosshair.
-- Close enough to the target to lock on: face it and strafe/backpedal around it.
local LOCK_RANGE=15
local function lockOn()
 local myRoot=myRootPart()
 return myRoot~=nil and targetAlive(currentTarget) and (currentTarget.HumanoidRootPart.Position-myRoot.Position).Magnitude<=LOCK_RANGE
end
local function aimVector(camera)
 local myRoot=myRootPart()
 if myRoot and targetAlive(currentTarget) then
  local delta=currentTarget.HumanoidRootPart.Position-myRoot.Position
  if delta.Magnitude>0.5 and delta.Magnitude<=Rules.MaxRange then return delta.Unit end
 end
 return camera.CFrame.LookVector
end
aimVectorOf=aimVector; moveIntentOf=moveIntent
local lastSentDir=Vector3.zero
sendMove=function()
 local model=player.Character; local hum=model and model:FindFirstChildOfClass("Humanoid")
 local camera=workspace.CurrentCamera
 if not hum or not camera then return end
 local dir=moveIntent(hum,camera)
 if flying then
  -- Camera pitch plus explicit rise/descent supports aiming above/below opponents.
  dir=Vector3.new(dir.X,(flyUp and 1 or 0)-(flyDown and 1 or 0),dir.Z)
 end
 if dir.Magnitude>1 then dir=dir.Unit end
 -- target: a selected target in range, so the server keeps the attacker facing it through wind-ups (v28).
 local myRoot=myRootPart()
 local hasTarget=myRoot~=nil and targetAlive(currentTarget) and (currentTarget.HumanoidRootPart.Position-myRoot.Position).Magnitude<=Rules.MaxRange
 remote:FireServer("Move",{dir=dir,aim=aimVector(camera),lock=lockOn(),target=hasTarget})
 lastSentDir=dir
end
local elapsed=0
RunService.RenderStepped:Connect(function(dt)
 elapsed+=dt
 -- Send at once when the stick/keys change (at most 30 a second), otherwise 10 a second.
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 local camera=workspace.CurrentCamera
 local changed=hum and camera and (moveIntent(hum,camera)-Vector3.new(lastSentDir.X,0,lastSentDir.Z)).Magnitude>0.1
 if elapsed<0.1 and not (changed and elapsed>=1/30) then return end
 elapsed=0
 sendMove()
end)
-- v30 step C: my client moves my own fighter while the server lets it ("ClientMove" on the model):
-- walk speed, jumping, facing, dash, lunge and flight all answer at once instead of a round trip later.
-- Stuns, knockback, pulls, carries, whirls, leaps and teleports stay on the server, which also checks
-- every step and snaps me back ("Snap") if I went somewhere I couldn't.
local lungeParams=RaycastParams.new(); lungeParams.FilterType=Enum.RaycastFilterType.Exclude
local function stepAlong(model,root,delta)
 if delta.Magnitude<0.001 then return end
 lungeParams.FilterDescendantsInstances={model}
 local hit=workspace:Raycast(root.Position,delta.Unit*(delta.Magnitude+1.2),lungeParams)
 if hit then delta=delta.Unit*math.max(0,hit.Distance-1.2) end
 root.CFrame=root.CFrame+delta
end
local flightClock=nil
RunService.PreSimulation:Connect(function(dt)
 local model=player.Character; local hum=model and model:FindFirstChildOfClass("Humanoid")
 local root=model and model:FindFirstChild("HumanoidRootPart"); local camera=workspace.CurrentCamera
 if not hum or not root or not camera or hum.Health<=0 then net.localDash=nil; net.myLunge=nil; net.snapTo=nil; return end
 local now=os.clock()
 if net.snapTo then
  -- Ease a server correction in over a few frames instead of popping.
  local k=math.min(1,(now-net.snapTo.start)/0.08)
  root.CFrame=net.snapTo.from:Lerp(net.snapTo.to,k); root.AssemblyLinearVelocity=Vector3.zero
  if k>=1 then net.snapTo=nil end
  return
 end
 if not model:GetAttribute("ClientMove") then net.localDash=nil; net.myLunge=nil; flightClock=nil; return end
 local c=Rules.Characters[model:GetAttribute("Hero") or ""]; if not c then return end
 local locked=model:GetAttribute("Locked")==true or now<net.localFreezeUntil
 local blocking=model:GetAttribute("Blocking")==true or net.blockHeldLocal
 local p=poses[model]; local pm=p and p.move
 local acting=myActBusy() or (pm~=nil and not p.fadeJ and now-p.start<(pm.Startup+pm.Active+pm.Recovery)/60)
 local fly=model:GetAttribute("Flying")==true
 local aim=aimVector(camera); local flatAim=Vector3.new(aim.X,0,aim.Z)
 flatAim=flatAim.Magnitude>0.01 and flatAim.Unit or root.CFrame.LookVector
 local dir=moveIntent(hum,camera)
 local speed=c.Speed
 -- R35: Bulwark's Earth Slam speed boost.
 if (model:GetAttribute("SpeedBuffEnd") or 0)>workspace:GetServerTimeNow() then speed*=model:GetAttribute("SpeedBuff") or 1 end
 speed*=1+Rules.Bulwark.StackSpeed*(model:GetAttribute("Juggernaut") or 0) -- R36 Juggernaut stacks
 local lock=lockOn()
 -- R65 (Peter: "add strafing left to right"): walking with the keys keeps you facing ahead (your target, or
 -- where the camera looks), WoW-style: A / D sidestep, S backpedals at backpedal speed, W runs ahead.
 local keyWalk=not fly and dir.Magnitude>0.1 and Sig.walkFacing() -- R65c/d: only while a strafe / backpedal key is held
 if (lock or keyWalk) and dir.Magnitude>0.1 and dir.Unit:Dot(flatAim)<-0.3 then speed*=Rules.BackpedalScale end
 hum.WalkSpeed=locked and 0 or blocking and 7 or acting and 9 or speed
 hum.JumpPower=(locked or blocking or acting or fly) and 0 or 45
 -- Facing: guard, wind-ups and lock-on face the aim; a swing keeps its direction once it lands;
 -- otherwise Roblox turns toward the walk direction.
 local winding=pm~=nil and not p.fadeJ and now-p.start<pm.Startup/60
 local face=not fly and (blocking or winding or (lock and not acting) or (keyWalk and not acting))
 hum.AutoRotate=not face and not fly and not acting
 if face and not locked then root.CFrame=CFrame.lookAt(root.Position,root.Position+flatAim) end
 if locked then
  local v=root.AssemblyLinearVelocity; root.AssemblyLinearVelocity=Vector3.new(0,math.min(v.Y,0),0)
 end
 if net.localDash then
  -- Same dash as the server: 12 ticks at full speed, then 6 ticks sliding out.
  local i=(now-net.localDash.start)*60
  if locked or i>=18 then net.localDash=nil
  else
   local k=i<12 and 1 or 0.45*(1-(i-12)/6)
   local v=root.AssemblyLinearVelocity; root.AssemblyLinearVelocity=net.localDash.dir*c.DashSpeed*k+Vector3.new(0,v.Y,0)
  end
 end
 if net.myLunge then
  if locked or now>=net.myLunge.ends then net.myLunge=nil
  else stepAlong(model,root,net.myLunge.dir*net.myLunge.rate*math.min(dt,1/20)) end
 end
 local fv=root:FindFirstChild("FlightVelocity")
 if fly and fv then
  flightClock=flightClock or now
  local d=Vector3.new(dir.X,(flyUp and 1 or 0)-(flyDown and 1 or 0),dir.Z); if d.Magnitude>1 then d=d.Unit end
  local v=(locked or acting) and Vector3.zero or d*Rules.Flight.Speed
  if now-flightClock<Rules.Flight.TakeoffSeconds then v=Vector3.new(0,Rules.Flight.TakeoffRise,0) end
  if root.Position.Y>=Rules.ceiling(model:GetAttribute("Hero"))+3 then v=Vector3.new(v.X,math.min(0,v.Y),v.Z) end
  fv.VectorVelocity=v
  -- v35 (Peter: "the fly is still funny in terms of turning around"): nothing turned a flyer before,
  -- so she or he kept facing wherever the takeoff left them, flying sideways and backwards. Now the body
  -- swings smoothly round to the flight direction, or to the target while attacking or locked on;
  -- the pose banks into the turn.
  local want
  if lock or acting or (pm~=nil and now-p.start<pm.Startup/60) then want=flatAim
  else local hv=Vector3.new(v.X,0,v.Z); if hv.Magnitude>2 then want=hv.Unit end end
  if want and not locked then
   local cur=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
   cur=cur.Magnitude>0.01 and cur.Unit or want
   if cur:Dot(want)<-0.97 then want=(want+root.CFrame.RightVector*0.3).Unit end
   local k=1-math.exp(-9*math.min(dt,0.1))
   local look=cur:Lerp(want,k); if look.Magnitude>0.01 then root.CFrame=CFrame.lookAt(root.Position,root.Position+look.Unit) end
  else
   -- R29: also while stunned or frozen. R20 (Peter: "automatic upright when not moving and flying"): with no flight input nothing turned the
   -- body, so a tilt from a hit, a bump or the takeoff stayed while hovering. It now levels out on its own,
   -- keeping the way it faces.
   local up=root.CFrame.UpVector
   if up.Y<0.999 then
    local cur=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z)
    if cur.Magnitude<0.01 then cur=Vector3.new(-up.X,0,-up.Z) end
    if cur.Magnitude>0.01 then
     local k=1-math.exp(-10*math.min(dt,0.1))
     root.CFrame=root.CFrame:Lerp(CFrame.lookAt(root.Position,root.Position+cur.Unit),k)
     root.AssemblyAngularVelocity=Vector3.zero
    end
   end
  end
 else flightClock=nil end
end)
-- R30 (Peter: "Bulwark should have an earthquake FX when he does Dimension Door and the Charge"):
-- the ground splits in jagged cracks from the impact, slabs heave up and sink back, rocks and dust fly,
-- a shock ring rolls out and anyone close feels the camera shake. Size 1 = Charge, bigger = Door.
function Sig.quake(at,size)
 size=size or 1
 local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude
 local skip={fxFolder}; for _,pl in Players:GetPlayers() do if pl.Character then table.insert(skip,pl.Character) end end
 params.FilterDescendantsInstances=skip
 local ray=workspace:Raycast(at+Vector3.new(0,3,0),Vector3.new(0,-40,0),params)
 local g=ray and ray.Position or at
 local earth=Color3.fromRGB(96,78,60); local dark=Color3.fromRGB(28,22,18); local glow=Color3.fromRGB(255,140,50)
 -- Cracks: jagged dark seams radiating out, a faint molten glow inside each.
 for i=1,math.floor(7*size) do
  local ang=(i/math.floor(7*size))*math.pi*2+math.random()*0.5; local from=g; local len=(5+math.random()*5)*size
  for seg=1,3 do
   local dir=Vector3.new(math.cos(ang),0,math.sin(ang)); ang+=(math.random()-0.5)*0.8
   local to=from+dir*len/3
   local cf=CFrame.lookAt((from+to)/2+Vector3.new(0,0.06,0),to+Vector3.new(0,0.06,0))
   local crack=fxPart(Enum.PartType.Block,Vector3.new(0.35*size,0.12,(to-from).Magnitude),cf,dark,0,Enum.Material.Slate)
   fadeOut(crack,1.6+seg*0.1,{Transparency=1})
   local seam=fxPart(Enum.PartType.Block,Vector3.new(0.12*size,0.14,(to-from).Magnitude*0.9),cf,glow,0.2)
   fadeOut(seam,0.7,{Transparency=1})
   from=to
  end
 end
 -- Heaving slabs that pop up at an angle and sink back.
 for i=1,math.floor(6*size) do
  local a=math.random()*math.pi*2; local r=(2+math.random()*4)*size
  local p=g+Vector3.new(math.cos(a)*r,-0.6,math.sin(a)*r)
  local slab=fxPart(Enum.PartType.Block,Vector3.new(2+math.random()*1.5,1,2+math.random()*1.5)*size,CFrame.new(p),earth,0,Enum.Material.Slate)
  local up=CFrame.new(p+Vector3.new(0,0.8*size,0))*CFrame.Angles((math.random()-0.5)*0.9,math.random()*3,(math.random()-0.5)*0.9)
  game:GetService("TweenService"):Create(slab,TweenInfo.new(0.12,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{CFrame=up}):Play()
  task.delay(0.5,function() if slab.Parent then fadeOut(slab,0.6,{CFrame=up-Vector3.new(0,1.2*size,0),Transparency=1}) end end)
 end
 -- Rocks thrown up and out.
 for i=1,math.floor(10*size) do
  local a=math.random()*math.pi*2
  local rock=fxPart(Enum.PartType.Block,Vector3.one*(0.4+math.random()*0.6),CFrame.new(g+Vector3.new(0,0.5,0)),earth,0,Enum.Material.Slate)
  local out=g+Vector3.new(math.cos(a),0,math.sin(a))*(4+math.random()*6)*size+Vector3.new(0,2+math.random()*4,0)
  fadeOut(rock,0.7,{CFrame=CFrame.new(out)*CFrame.Angles(math.random()*4,math.random()*4,0),Transparency=1})
 end
 -- Dust and the rolling shock ring.
 ring(g+Vector3.new(0,0.3,0),Color3.fromRGB(170,150,120),22*size,0.5)
 ring(g+Vector3.new(0,0.3,0),glow,12*size,0.3)
 burst(g+Vector3.new(0,1,0),Color3.fromRGB(150,130,105),8*size,0.5)
 Sig.play({"stomp",1,0.6},g); Sig.play({"explosion",0.45,0.6},g)
 local me=myRootPart and myRootPart()
 if me then local d=(me.Position-g).Magnitude; if d<35*size then shake(math.clamp(1.4*size*(1-d/(35*size)),0.3,1.6),0.5) end end
end
-- R36 Juggernaut stacks: an orange glow on Bulwark that grows with each stack, "JUGGERNAUT x3" pops,
-- and at 5 stacks embers stream off him until his next Cleave.
Sig.juggSeen=setmetatable({},{__mode="k"})
function Sig.jugg(model,root)
 local n=model:GetAttribute("Juggernaut") or 0
 local seen=Sig.juggSeen[model] or 0
 if n==seen then return end
 Sig.juggSeen[model]=n
 local torso=model:FindFirstChild("UpperTorso") or root
 local light=torso:FindFirstChild("JuggGlow")
 if n>0 and not light then
  light=Instance.new("PointLight"); light.Name="JuggGlow"; light.Color=Color3.fromRGB(255,140,50); light.Range=10; light.Parent=torso
 end
 if light then light.Brightness=n*0.7; light.Enabled=n>0 end
 local embers=torso:FindFirstChild("JuggEmbers")
 if n>=Rules.Bulwark.StackMax and not embers then
  embers=Instance.new("ParticleEmitter"); embers.Name="JuggEmbers"; embers.Color=ColorSequence.new(Color3.fromRGB(255,150,60))
  embers.LightEmission=1; embers.Rate=25; embers.Lifetime=NumberRange.new(0.4,0.8); embers.Speed=NumberRange.new(2,5)
  embers.Size=NumberSequence.new(0.25,0); embers.SpreadAngle=Vector2.new(60,60); embers.Parent=torso
 elseif embers and n<Rules.Bulwark.StackMax then embers:Destroy() end
 if n>seen then popText(model,n>=Rules.Bulwark.StackMax and "JUGGERNAUT MAX!" or "JUGGERNAUT x"..n,Color3.fromRGB(255,150,60),n>=Rules.Bulwark.StackMax and 30 or 22) end
end
-- Asset-free procedural animation. Motor poses are visual only, never hit detection.
-- Joint angles in radians: rs/ls shoulders (+ = arm forward), re/le elbows (+ = bend),
-- wx waist pitch (- = lean forward), wy waist twist (+ = right shoulder forward),
-- rh/lh hips (+ = leg forward), rk/lk knees (- = bend), ry body drop, rx body tilt back, nx neck.
local KEYS={
 Light1={ -- left jab
  wind={ls=0.5,le=1.7,rs=0.4,re=1.9,wy=0.15,rh=0.1,lk=-0.2},
  hit={ls=1.6,le=0.05,rs=0.45,re=1.9,wy=-0.4,wx=-0.12,lh=0.25,rh=-0.1}},
 Light2={ -- right cross
  wind={rs=0.3,re=1.8,ls=0.5,le=1.7,wy=-0.25,rk=-0.2},
  hit={rs=1.62,re=0.05,ls=0.45,le=1.9,wy=0.5,wx=-0.15,rh=-0.15,lh=0.3,lk=-0.2}},
 Light3={ -- front kick
  wind={rh=0.9,rk=-1.5,ls=0.6,le=1.6,rs=0.5,re=1.6,wx=0.1,ry=-0.2},
  hit={rh=1.55,rk=-0.05,wx=0.28,rs=-0.3,re=0.6,ls=0.6,le=1.6,lk=-0.2}},
 Heavy={ -- haymaker
  wind={rs=-0.9,re=1.4,wy=-0.9,ls=0.9,le=1.2,ry=-0.3,rh=0.3,rk=-0.4,lh=-0.2},
  hit={rs=1.65,re=0,wy=0.75,wx=-0.32,ls=-0.4,le=0.4,rh=-0.35,lh=0.55,lk=-0.35,ry=-0.4}},
 -- v25 Tempest: arm thrown up to call the bolt, then flung forward; both palms push the gale.
 Lightning={
  wind={rs=2.8,re=0.3,ls=0.4,le=0.8,wx=0.15,wy=0.2},
  hit={rs=1.6,re=0,ls=0.3,le=0.9,wx=-0.12,wy=0.45}},
 Gale={
  wind={rs=0.6,re=1.9,ls=0.6,le=1.9,wy=-0.3,wx=0.15,ry=-0.2},
  hit={rs=1.55,re=0,ls=1.55,le=0,wx=-0.2,lh=0.3,rh=-0.2}},
 -- v25 Bulwark: both fists high, then hammered into the floor; a low shoulder-first charge.
 Slam={
  wind={rs=2.9,re=0.5,ls=2.9,le=0.5,wx=0.25,ry=0.1},
  hit={rs=0.9,re=0.2,ls=0.9,le=0.2,wx=-0.7,ry=-0.8,rh=0.9,rk=-1.3,lh=0.6,lk=-1.1}},
 Charge={
  wind={rs=-0.3,re=1.4,ls=0.6,le=1.8,wx=-0.35,wy=0.5,ry=-0.3,rh=0.4,rk=-0.6},
  hit={rs=-0.2,re=1.2,ls=0.5,le=1.9,wx=-0.55,wy=0.7,lh=0.5,rh=-0.4}},
 Uppercut={
  wind={ry=-0.9,rh=0.6,rk=-1.0,lh=0.6,lk=-1.0,rs=-0.3,re=1.6,wx=-0.3,wy=-0.4},
  hit={rs=2.9,re=0.2,wy=0.4,wx=0.2,ry=0.3,rh=-0.2,lh=0.4,lk=-0.6,ls=0.3,le=1.2}},
 Throw={ -- two-handed grab, then a hip twist toss
  wind={rs=0.9,re=0.9,ls=0.9,le=0.9,wx=-0.2,ry=-0.2},
  hit={rs=1.4,re=0.3,ls=1.4,le=0.3,wy=0.9,wx=-0.3,rh=-0.3,lh=0.4,lk=-0.3}},
 Grapple={
  wind={ls=0.2,le=1.4,wy=0.5,rs=0.3,re=1.2},
  hit={ls=1.6,le=0,wy=-0.45,wx=-0.1,rs=0.2,re=1.4}},
 Beam={hold=18,
  wind={rs=-0.4,re=1.6,ls=-0.4,le=1.6,wy=0.6,wx=0.1},
  hit={rs=1.55,ls=1.55,re=0,le=0,wx=-0.12}},
 Pounce={ -- crouch, then fly forward with arms reaching out
  wind={ry=-1.1,rh=1.0,rk=-1.7,lh=1.0,lk=-1.7,wx=-0.5,rs=-0.7,ls=-0.7,re=0.4,le=0.4},
  hit={rh=0.3,rk=-1.2,lh=-0.5,lk=-0.6,rs=2.4,ls=2.4,re=0.3,le=0.3,wx=-0.45}},
}
-- v28 new moves.
KEYS.SolarFlare={noStance=true, -- arms pulled in to the core, then flung wide as the flare bursts
 wind={rs=0.6,re=2.0,ls=0.6,le=2.0,wx=0.25,ry=-0.25,rk=-0.4,lk=-0.4},
 hit={rs=1.4,re=0,ls=1.4,le=0,wx=-0.25,nx=-0.2}}
KEYS.ShadowDoor={noStance=true, -- folds into the shadows, steps out low and ready
 wind={ry=-0.8,wx=0.5,rs=0.4,ls=0.4,re=1.8,le=1.8,rh=0.7,rk=-1.2,lh=0.7,lk=-1.2},
 hit={ry=-0.3,wx=-0.2,rs=0.9,re=1.4,ls=0.9,le=1.4,rh=0.3,rk=-0.6,lh=-0.1,lk=-0.4}}
-- R22 Shadow Circle: drops to one knee and presses both hands into the floor to draw the circle, then rises
-- with the arms swept out as it closes.
KEYS.ShadowCircle={noStance=true,
 wind={ry=-1.0,wx=0.75,nx=0.35,rs=1.2,re=0.25,ls=1.2,le=0.25,rh=1.25,rk=-1.9,lh=-0.15,lk=-1.6},
 hit={ry=-0.25,wx=-0.15,rs=0.4,re=0.2,ls=0.4,le=0.2,wy=0,rh=0.2,rk=-0.4,lh=-0.1,lk=-0.3}}
KEYS.DimensionDoor={noStance=true, -- sword arm raised to cut the door, then a braced landing
 wind={rs=2.6,re=0.4,ls=1.0,le=1.2,wx=0.1,ry=-0.1},
 hit={rs=0.8,re=0.6,ls=1.25,le=1.1,ry=-0.35,rh=0.4,rk=-0.6,lh=-0.1,lk=-0.4,wx=-0.2}}
KEYS.Whirlwind={noStance=true, -- both arms stir the air in a circle, then fling the funnel out
 wind={rs=1.8,re=0.6,ls=1.8,le=0.6,wy=0.8,wx=0.1},
 hit={rs=1.5,re=0.1,ls=1.5,le=0.1,wy=-0.6,wx=-0.15}}
KEYS.TitanDrop={ -- grab, then heave the victim up overhead
 wind={rs=1.1,re=0.8,ls=1.1,le=0.8,wx=-0.25,ry=-0.25,rk=-0.4,lk=-0.4},
 hit={rs=3.0,re=0.3,ls=3.0,le=0.3,wx=0.3,ry=0.1,nx=0.3}}
KEYS.GroundBolt=KEYS.Lightning -- R47 Lightning Snare: the same call-down as Lightning
KEYS.ShadeBolt=KEYS.Lightning -- R49 Shade Bolt: a flick of shadow from the hand
KEYS.Phase=KEYS.ShadowDoor -- R49 Phase: folds into the shadows
KEYS.SolarAbsorb=KEYS.SolarFlare -- R47 Solar Absorb: arms in to the core, flung wide as the sphere forms
-- v34 per-hero attack shapes (Sig.KEYS). Solarion keeps the boxer's jab, cross and kick, with a
-- two-fisted hammer for his Heavy; the others fight in their own style.
Sig.KEYS.Solarion={
 Light3={ -- flying knee
  wind={rh=0.4,rk=-0.6,ls=0.9,le=1.5,rs=0.9,re=1.5,ry=-0.3,wx=0.1},
  hit={rh=1.7,rk=-2.0,lh=-0.3,lk=-0.2,ls=1.0,le=1.6,rs=1.0,re=1.6,wx=-0.25,ry=0.25}},
 Heavy={ -- Solar Hammer: both fists raised, then smashed down together
  wind={rs=2.8,re=0.6,ls=2.8,le=0.6,wx=0.3,ry=0.1,nx=0.2},
  hit={rs=1.0,re=0.1,ls=1.0,le=0.1,wx=-0.6,ry=-0.45,rh=0.5,rk=-0.8,lh=-0.2,lk=-0.3}},
}
Sig.KEYS.Wraithstep={
 Light1={ -- backhand claw rake, right to left
  wind={rs=0.9,re=1.6,wy=0.7,ls=0.4,le=1.8,ry=-0.2,rk=-0.3},
  hit={rs=1.3,re=0.3,wy=-0.8,wx=-0.15,ls=0.3,le=1.8,lh=0.3,rk=-0.3}},
 Light2={ -- the other claw, rising
  wind={ls=0.2,le=1.9,wy=-0.6,rs=0.5,re=1.7,ry=-0.3,lk=-0.4},
  hit={ls=2.1,le=0.4,wy=0.6,wx=-0.1,rs=0.4,re=1.8,rh=0.3,ry=0.05}},
 Light3={noStance=true, -- spinning back kick
  wind={wy=-1.2,rh=0.5,rk=-1.2,ls=0.8,le=1.4,rs=0.8,re=1.4,ry=-0.2,yw=-0.9},
  hit={wy=0.4,rh=-1.2,rk=-0.1,lh=0.1,lk=-0.3,wx=0.35,ls=1.2,le=0.6,rs=-0.4,re=0.4,yw=1.6}},
 Heavy={ -- Grave Scythe: crouched low, one arm swept wide in a reaping arc
  wind={rs=1.4,re=0.3,wy=1.1,ls=0.3,le=1.6,ry=-0.7,rh=0.8,rk=-1.3,lh=0.5,lk=-1.1,wx=-0.2},
  hit={rs=1.5,re=0.1,wy=-1.2,ls=-0.3,le=0.8,ry=-0.8,rh=0.9,rk=-1.4,lh=0.4,lk=-1.0,wx=-0.35}},
}
Sig.KEYS.Tempest={
 Light1={ -- open palm strike
  wind={ls=0.3,le=2.1,rs=0.4,re=1.6,wy=0.3,rh=0.1},
  hit={ls=1.55,le=0,rs=0.3,re=1.5,wy=-0.35,wx=-0.08,lh=0.2,nx=-0.1}},
 Light2={ -- knife-hand chop, high to low
  wind={rs=2.4,re=1.0,ls=0.6,le=1.5,wy=-0.4,wx=0.15},
  hit={rs=1.1,re=0.05,ls=0.4,le=1.6,wy=0.45,wx=-0.2,rh=-0.1,lh=0.25}},
 Light3={ -- crescent kick, high and wide
  wind={lh=0.7,lk=-1.3,rs=1.2,re=0.6,ls=-0.2,le=0.4,wy=0.5,ry=-0.1},
  hit={lh=2.0,lk=-0.1,rh=-0.15,wy=-0.8,wx=0.35,rs=1.4,re=0.2,ls=-0.5,le=0.3}},
 Heavy={ -- Storm Fist: both palms drawn back at the hip, then thrust out together
  wind={rs=-0.5,re=1.9,ls=-0.5,le=1.9,wy=0.6,ry=-0.35,rk=-0.5,lk=-0.5,wx=0.1},
  hit={rs=1.6,re=0,ls=1.5,le=0.1,wy=-0.2,wx=-0.3,rh=-0.35,lh=0.6,lk=-0.4,ry=-0.25}},
}
Sig.KEYS.Bulwark={
 Light1={ -- shield bash: the shield arm driven straight out, shoulder behind it
  wind={ls=1.2,le=1.3,rs=0.5,re=1.7,wy=0.5,ry=-0.25,rk=-0.4},
  hit={ls=1.45,le=0.6,rs=0.4,re=1.8,wy=-0.55,wx=-0.3,lh=0.45,lk=-0.3,rh=-0.2,ry=-0.2}},
 Light2={ -- pommel strike: the sword hand hooks across
  wind={rs=1.0,re=2.2,wy=-0.6,ls=1.2,le=1.2,rk=-0.3},
  hit={rs=1.5,re=1.2,wy=0.85,wx=-0.2,ls=1.0,le=1.4,lh=0.3,rh=-0.2}},
 Light3={ -- stomp kick: knee high, heel driven down and forward
  wind={rh=1.6,rk=-1.9,ls=1.2,le=1.2,rs=0.5,re=1.6,wx=0.2,ry=0.05},
  hit={rh=0.9,rk=-0.1,lh=-0.1,lk=-0.4,wx=-0.2,ls=1.2,le=1.2,rs=0.6,re=1.6,ry=-0.3}},
 Heavy={ -- Titan Cleave: the sword lifted high over the head, then hewn straight down
  wind={rs=3.1,re=0.8,ls=1.2,le=1.1,wx=0.35,wy=-0.2,ry=0.05,nx=0.15},
  hit={rs=0.7,re=0.05,ls=1.1,le=1.2,wx=-0.7,wy=0.25,ry=-0.55,rh=0.7,rk=-1.0,lh=-0.3,lk=-0.4}},
}
for _,set in Sig.KEYS do for name,K in set do
 local base=KEYS[name]; if base and base.hold then K.hold=base.hold end
end end
local HURT={wx=0.45,nx=0.35,rs=0.5,re=1.4,ls=0.5,le=1.4,ry=-0.15,rk=-0.2,lk=-0.2}
local PIN={rx=1.4,ry=-2.2,rs=0.3,ls=0.3,re=0.4,le=0.4,rh=0.2,lh=-0.2,nx=-0.3}
local CROUCH={ry=-0.9,rh=0.9,rk=-1.4,lh=0.6,lk=-1.2,wx=-0.35,rs=0.5,ls=0.5,re=0.8,le=0.8}
local GUARD={rs=1.2,re=2.0,ls=1.2,le=2.0,wx=-0.08}
-- v26 Bulwark guards behind his shield: braced low, shield arm forward, sword arm cocked back.
local SHIELD_GUARD={ls=1.25,le=1.1,rs=0.5,re=1.7,wx=-0.15,wy=-0.25,ry=-0.2,rh=0.35,rk=-0.4,lh=-0.1,lk=-0.3}
-- Flying (v21): leaning into the flight, arms back, legs trailing (bobs gently while it holds).
local FLY={wx=-0.3,rs=-0.35,ls=-0.35,re=0.25,le=0.25,rh=-0.35,rk=-0.45,lh=-0.15,lk=-0.25,nx=0.15}
local JOINTS={"rs","re","ls","le","wx","wy","rh","rk","lh","lk","ry","rx","nx","yw"}
-- v28 (Peter: face the target three-quarters on): every attack turns the body about 30 degrees side-on
-- (yw, lead shoulder to the target) in the wind-up and keeps some of it through the hit, while the waist
-- turns the chest back so the strike still travels straight at the target.
local STANCE_WIND,STANCE_HIT=0.5,0.25
for _,K in KEYS do
 if not K.noStance then
  if K.wind.yw==nil then K.wind.yw=STANCE_WIND; K.wind.wy=(K.wind.wy or 0)-STANCE_WIND*0.6 end
  if K.hit.yw==nil then K.hit.yw=STANCE_HIT; K.hit.wy=(K.hit.wy or 0)-STANCE_HIT*0.6 end
 end
end
for _,set in Sig.KEYS do for _,K in set do
 if not K.noStance then
  if K.wind.yw==nil then K.wind.yw=STANCE_WIND; K.wind.wy=(K.wind.wy or 0)-STANCE_WIND*0.6 end
  if K.hit.yw==nil then K.hit.yw=STANCE_HIT; K.hit.wy=(K.hit.wy or 0)-STANCE_HIT*0.6 end
 end
end end
local function blend(a,b,t)
 local out={}
 for _,k in JOINTS do local x=a[k] or 0; out[k]=x+((b[k] or 0)-x)*t end
 return out
end
local function scaled(a,s) local out={}; for _,k in JOINTS do out[k]=(a[k] or 0)*s end return out end
local function easeInOut(t) return t<0.5 and 2*t*t or 1-(-2*t+2)^2/2 end
local NEUTRAL={}
-- v35 flight and stealth poses (Peter: flying and stealth should each have their own animation).
-- Solarion flies like a classic superhero: hovering with fists ready, cruising flat out with one fist
-- forward. Tempest levitates with one knee drawn up, and leans back into the wind with arms trailing
-- when she moves. Both bank into turns. Hidden Wraithstep creeps low.
Sig.FLY={
 Solarion={hover={rs=0.3,re=1.3,ls=0.3,le=1.3,rh=0.12,lh=-0.12,rk=-0.15,lk=-0.3,wx=0.05},
  cruise={rs=2.95,re=0.05,ls=-0.3,le=0.3,wx=-0.25,nx=0.75,rh=-0.15,lh=-0.1,rk=-0.08,lk=-0.2,rx=-1.0}},
 Tempest={hover={rs=0.55,re=0.9,ls=0.55,le=0.9,rh=0.4,rk=-1.15,lh=-0.05,lk=-0.15,wx=0.05,nx=-0.05},
  cruise={rs=-0.75,re=0.3,ls=-0.75,le=0.3,wx=-0.2,rx=-0.55,nx=0.35,rh=-0.15,rk=-0.45,lh=0.15,lk=-0.7}},
 -- V59 Valkyra: hovers upright with the shield held across her and the spear arm low; cruises spear-first like a diving bird.
 Valkyra={hover={rs=0.35,re=0.6,ls=1.1,le=1.2,rh=0.2,rk=-0.5,lh=-0.05,lk=-0.2,wx=0.05},
  cruise={rs=2.8,re=0.1,ls=1.0,le=1.3,wx=-0.25,nx=0.6,rh=-0.15,lh=-0.1,rk=-0.1,lk=-0.25,rx=-0.9}},
}
Sig.SNEAK={ry=-0.55,wx=-0.5,nx=0.35,rs=-0.45,re=1.25,ls=-0.45,le=1.25,rk=-0.75,lk=-0.75,rh=0.35,lh=0.35}
Sig.flyState=setmetatable({},{__mode="k"})
function Sig.flyPose(model,root,now)
 local set=Sig.FLY[Sig.heroOf(model)]
 local v=root.AssemblyLinearVelocity; local flat=Vector3.new(v.X,0,v.Z).Magnitude
 local J
 if set then J=blend(set.hover,set.cruise,math.clamp(flat/Rules.Flight.Speed,0,1))
 else J=blend(FLY,NEUTRAL,0) end
 local bob=math.sin(now*3)*0.06; J.ry+=bob; J.rh+=bob; J.lh-=bob
 -- Lean back when climbing, forward when diving.
 J.rx+=math.clamp(v.Y*0.012,-0.3,0.3)
 -- Bank into turns from how fast the facing swings round.
 local st=Sig.flyState[model]; if not st then st={yaw=0,bank=0,t=now}; Sig.flyState[model]=st end
 local look=root.CFrame.LookVector; local yaw=math.atan2(-look.X,-look.Z)
 local dt=math.max(now-st.t,1/240); local dy=yaw-st.yaw
 if dy>math.pi then dy-=2*math.pi elseif dy<-math.pi then dy+=2*math.pi end
 st.yaw=yaw; st.t=now
 st.bank+=(math.clamp(-dy/dt*0.18,-0.6,0.6)-st.bank)*math.min(1,dt*8)
 J.bk=st.bank
 return J
end
function Sig.sneakPose(model,root,now)
 local v=root.AssemblyLinearVelocity; local k=math.clamp(Vector3.new(v.X,0,v.Z).Magnitude/12,0,1)
 local J=blend(Sig.SNEAK,NEUTRAL,0); local s=math.sin(now*9)*k*0.55
 J.rh+=s; J.lh-=s; J.rs-=s*0.4; J.ls+=s*0.4
 return J
end
-- Joints for one pose at time `clock`; nil when the pose has finished.
local function evaluate(p,clock)
 if p.fadeJ then
  -- v30: the server refused this press, so the guessed pose melts back to neutral.
  local t=(clock-p.fadeFrom)/0.15; if t>=1 then return nil end
  return blend(p.fadeJ,NEUTRAL,easeInOut(t))
 end
 local elapsed=clock-p.start
 if p.name=="Hurt" then
  local t=elapsed/p.dur; if t>=1 then return nil end
  -- v34: the reaction fits the blow (a jab snaps the head, a body blow doubles over, lightning locks up).
  local R=Sig.HURTS[p.react or ""] or HURT
  local J=blend(scaled(R,p.power or 1),NEUTRAL,t*t)
  if R.jitter and t<0.7 then for _,k in {"rs","ls","nx","wx"} do J[k]+=(math.random()-0.5)*0.35 end end
  return J
 elseif p.name=="Pin" then
  local t=elapsed/p.dur; if t>=1 then return nil end
  return blend(PIN,NEUTRAL,math.max(0,(t-0.75)/0.25))
 elseif p.name=="Land" then
  local t=elapsed/p.dur; if t>=1 then return nil end
  local from=p.whiff and blend(CROUCH,{wx=-0.75,rs=1.2,ls=1.2,ry=-1.0,rh=1.1,rk=-1.5,lh=0.4,lk=-1.0},1) or CROUCH
  local hold=p.whiff and 0.6 or 0.25
  return blend(from,NEUTRAL,easeInOut(math.max(0,(t-hold)/(1-hold))))
 end
 local move=p.move or Rules.Moves[p.name]; local kn=Sig.alias(p.hero,p.name); local K=(p.hero and Sig.KEYS[p.hero] and Sig.KEYS[p.hero][kn]) or KEYS[kn]
 if not move or not K then return nil end
 local frame=elapsed*60
 local S=move.Startup; local A=move.Active+(K.hold or 0); local R=move.Recovery+(p.extra or 0)-(K.hold or 0)
 if frame<=S then return blend(NEUTRAL,K.wind,easeInOut(frame/S)) end
 if frame<=S+A then return blend(K.wind,K.hit,math.min((frame-S)/2,1)) end
 local r=(frame-S-A)/math.max(R,1)
 if r>=1 then return nil end
 if p.whiff then
  -- Overextended: the limb hangs out and the body tips forward before it can recover.
  local over=blend(K.hit,{wx=(K.hit.wx or 0)-0.3},1)
  return blend(over,NEUTRAL,easeInOut(math.max(0,(r-0.45)/0.55)))
 end
 return blend(K.hit,NEUTRAL,1-(1-r)^2)
end
local rigs={}; local posed={}
-- Hero movement sets (v19): Roblox's own catalog animations, free in any game. Solarion moves with the
-- Superhero set, Wraithstep with the Ninja set. Played on every client, looks only. Attacks, guard and
-- hit poses still come from the procedural poses above, which take over the joints while they run.
local HERO_ANIMS={
 Solarion={idle=616111295,run=616117076,jump=616115533,fall=616108001},
 Wraithstep={idle=656117400,run=656118852,jump=656117878,fall=656115606},
 -- v25: Tempest moves with the Stylish set. v34: Bulwark walks with Roblox's Knight set (a heavy,
 -- armoured stride) instead of sharing Solarion's Superhero set (IDs checked on economy.roblox.com).
 Tempest={idle=616136790,run=616140816,jump=616139451,fall=616134815},
 Bulwark={idle=657595757,run=657564596,jump=658409194,fall=657600338},
 Valkyra={idle=616136790,run=616140816,jump=616139451,fall=616134815}, -- V59: the Stylish set under her own captured idle and run
 DreadKnight={idle=657595757,run=657564596,jump=658409194,fall=657600338}, -- V60: the Knight set under his own captured idle and run
}
local moveAnims={}
local function heroTracks(model)
 local set=moveAnims[model]
 if set~=nil then return set or nil end
 local ids=HERO_ANIMS[model:GetAttribute("Hero")]
 local hum=model:FindFirstChildOfClass("Humanoid")
 if not ids or not hum then moveAnims[model]=false; return nil end
 local animator=hum:FindFirstChildOfClass("Animator") or Instance.new("Animator",hum)
 set={tracks={},current=nil}
 for name,id in ids do
  local anim=Instance.new("Animation"); anim.AnimationId="rbxassetid://"..id
  local ok,track=pcall(function() return animator:LoadAnimation(anim) end)
  if ok then track.Looped=name~="jump"; track.Priority=Enum.AnimationPriority.Movement; set.tracks[name]=track
  else warn("[HeroWars] "..name.." animation did not load: "..tostring(track)) end
 end
 if not set.tracks.idle or not set.tracks.run then set=false end
 moveAnims[model]=set
 return set or nil
end
local function playLoco(set, name, rate)
 if set.current~=name then
  if set.current and set.tracks[set.current] then set.tracks[set.current]:Stop(0.2) end
  set.current=name
  if name and set.tracks[name] then set.tracks[name]:Play(0.2) end
 end
 if name and rate and set.tracks[name] then set.tracks[name]:AdjustSpeed(rate) end
end
-- v28 Vanish / shadow pools / Solar Flare reveal, drawn on each client (looks only; hits are unchanged).
-- I see myself ghosted; others see a faint shimmer up close and nothing further away. A reveal adds a hue.
local stealth={}
updateStealth=function(model,root)
 local st=stealth[model]; if not st then st={alpha=0}; stealth[model]=st end
 local mine=model==player.Character
 local invisible=model:GetAttribute("Invisible")==true
 local shrouded=model:GetAttribute("Shrouded")==true
 local shadowForm=model:GetAttribute("ShadowForm")==true
 local revealed=(model:GetAttribute("RevealEnd") or 0)>workspace:GetServerTimeNow()
 local alpha=0
 if mine then alpha=invisible and not revealed and 1 or shrouded and 0.35 or 0
 elseif not revealed then
  local me=myRootPart(); local dist=me and (root.Position-me.Position).Magnitude or 999
  -- v45: gone completely for everyone else (no shimmer up close any more).
  if invisible then alpha=1
  elseif shrouded then alpha=dist>Rules.Shroud.Range and 0.92 or 0.5 end
 end
 if alpha~=st.alpha then
  st.alpha=alpha
  for _,d in model:GetDescendants() do
   if d:IsA("BasePart") and d.Name~="HumanoidRootPart" and d.Name~="Hurtbox" then d.LocalTransparencyModifier=alpha
   elseif d:IsA("Decal") then d.LocalTransparencyModifier=alpha
   elseif d:IsA("Highlight") and d.Name~="RevealHue" and d.Name~="ShadowFormHue" then d.Enabled=alpha<0.9
   elseif d:IsA("SurfaceGui") or d:IsA("BillboardGui") then d.Enabled=alpha<0.9
   elseif (d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("PointLight")) and d.Name~="SigTrail" then d.Enabled=alpha<0.9 end
  end
  local hum=model:FindFirstChildOfClass("Humanoid")
  if hum then hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
 end
 -- v45 Vanish shadow: for the first 1.5 s he's a pitch-black silhouette trailing dark smoke, seen by all.
 if shadowForm and not st.shadow then
  local h=Instance.new("Highlight"); h.Name="ShadowFormHue"; h.FillColor=Color3.new(0,0,0); h.FillTransparency=(model:GetAttribute("RigSkin")==true) and 0.55 or 0
  h.OutlineColor=Color3.fromRGB(120,60,200); h.OutlineTransparency=0.2; h.DepthMode=Enum.HighlightDepthMode.Occluded
  h.Adornee=model; h.Parent=model
  local torso=model:FindFirstChild("UpperTorso") or root
  local e=Instance.new("ParticleEmitter"); e.Name="ShadowFormSmoke"; e.Texture=(VFX.get("Smoke")) or "rbxasset://textures/particles/smoke_main.dds"
  e.Color=ColorSequence.new(Color3.fromRGB(20,10,35)); e.LightEmission=0; e.Rate=40; e.Lifetime=NumberRange.new(0.5,0.9)
  e.Speed=NumberRange.new(1,3); e.SpreadAngle=Vector2.new(180,180); e.Acceleration=Vector3.new(0,3,0)
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1.6),NumberSequenceKeypoint.new(1,3)})
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.35),NumberSequenceKeypoint.new(1,1)}); e.Parent=torso
  st.shadow={h,e}
 elseif not shadowForm and st.shadow then
  for _,x in st.shadow do x:Destroy() end; st.shadow=nil
 end
 -- Solar Flare reveal: a burning gold hue over the whole body while it lasts.
 if revealed and not st.hue then
  local h=Instance.new("Highlight"); h.Name="RevealHue"; h.FillColor=Color3.fromRGB(255,170,40); h.FillTransparency=0.45
  h.OutlineColor=Color3.fromRGB(255,220,120); h.OutlineTransparency=0; h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
  h.Adornee=model; h.Parent=model; st.hue=h
 elseif not revealed and st.hue then st.hue:Destroy(); st.hue=nil end
end
local MOTOR={rs="RightShoulder",re="RightElbow",ls="LeftShoulder",le="LeftElbow",rh="RightHip",rk="RightKnee",lh="LeftHip",lk="LeftKnee",nx="Neck"}
RunService.PreSimulation:Connect(function()
 local now=os.clock()
 -- R30 performance audit: look for new fighters 4 times a second instead of scanning every workspace
 -- child every frame.
 if now-(Sig.rigScanAt or 0)>=0.25 then
  Sig.rigScanAt=now
  for _,model in workspace:GetChildren() do
   if model:IsA("Model") and not rigs[model] and model:GetAttribute("Hero") then
    local motors={}
    for _,v in model:GetDescendants() do if v:IsA("Motor6D") then motors[v.Name]=v end end
    rigs[model]=motors
   end
  end
 end
 for model,motors in rigs do
  if not model.Parent then rigs[model]=nil; stealth[model]=nil; poses[model]=nil; posed[model]=nil; moveAnims[model]=nil; clearStatusFx(model); continue end
  local root=model:FindFirstChild("HumanoidRootPart")
  if root then updateStatusFx(model,root); updateStealth(model,root); if not hiddenFromMe(model) then Sig.move(model,root,now) end end
  if root and model:GetAttribute("Hero")=="Bulwark" then Sig.jugg(model,root) end
  if root and model:GetAttribute("Hero")=="DreadKnight" then Sig.coldEyes(model); Sig.fistHands(model) end -- V60, V60b fists
  if root then Sig.Motion.update(model,root,now) end
  local p=poses[model]; local J
  if p then
   local clock=now
   -- Hit-stop: hold the pose still, then carry on where it left off.
   if p.holdUntil then
    if now<p.holdUntil then clock=p.holdFrom
    else p.start+=p.holdUntil-p.holdFrom; p.holdFrom=nil; p.holdUntil=nil end
   end
   J=evaluate(p,clock)
   if not J then poses[model]=nil end
  end
  if not J and (model:GetAttribute("Hero")=="Bulwark" or model:GetAttribute("Hero")=="Valkyra" or model:GetAttribute("Hero")=="DreadKnight") and (model:GetAttribute("Blocking") or model:GetAttribute("Shielded") or model:GetAttribute("Parrying")) then J=SHIELD_GUARD end
  if not J and model:GetAttribute("Blocking") then J=GUARD end
  if not J and root and model:GetAttribute("Flying") then
   J=Sig.flyPose(model,root,now)
  end
  if not J and root and (model:GetAttribute("Invisible") or model:GetAttribute("Shrouded")) and not hiddenFromMe(model) then J=Sig.sneakPose(model,root,now) end
  local set=heroTracks(model)
  -- v36: a motion capture for this move (or this flight or stealth loop) plays instead of the hand-made pose.
  local mp=J and poses[model]==p and p or nil
  local ms=(J and not mp) and (model:GetAttribute("Flying") and "fly" or ((model:GetAttribute("Invisible") or model:GetAttribute("Shrouded")) and "sneak") or (J==SHIELD_GUARD and (model:GetAttribute("Parrying") and "parry" or "guard") or nil)) or nil -- V53: captured guard and parry
  -- R29 (Peter: "Solarion is not standing up when flying, why does that keep breaking"): his Mixamo fly
  -- capture is a horizontal superman pose, and every earlier fix only rotated it back upright afterwards.
  -- Whenever that correction stepped aside (stunned, hit, after an attack, landing) the capture showed
  -- lying flat. Now the capture plays only while he is really flying forward (Cruise or Dive); any other
  -- time in the air he uses the hand-made upright hover pose.
  if ms=="fly" and Sig.heroOf(model)=="Solarion" then
   local fs=model:GetAttribute("FlightVisualState")
   if fs~="Cruise" and fs~="Dive" then ms=nil end
  end
  if Sig.mocap(model,mp,ms,now,nil,J~=nil) then -- V54b: J~=nil = a hand-made pose is taking over, so a running loop must stop
   Sig.Motion.apply(model,motors,now,mp~=nil or model:GetAttribute("Blocking") or ms=="guard" or ms=="parry") -- V53: the guard and parry captures own the limbs
   Sig.Motion.attack(model,motors,mp,now)
   posed[model]=true
   if set then playLoco(set,nil) end
   Sig.twoHand(model,motors,p) -- V60b
   continue
  end
  if J then
   posed[model]=true
   if set then playLoco(set,nil) end
   for key,name in MOTOR do local m=motors[name]; if m then m.Transform=CFrame.Angles(J[key] or 0,0,0) end end -- V49f: guard tables omit some joints
   if motors.Waist then motors.Waist.Transform=CFrame.Angles(J.wx or 0,J.wy or 0,0) end
   -- v30: the victim shudders side to side through the hit-stop freeze.
   local jx=0
   if p and p.shake and p.holdUntil and now<p.holdUntil then jx=math.sin(now*95)*p.shake end
   if motors.Root then motors.Root.Transform=CFrame.new(jx,J.ry or 0,0)*CFrame.Angles(J.rx or 0,J.yw or 0,J.bk or 0) end -- V49f: the native rig has a Root motor; guard tables omit rx/ry
  else
   if posed[model] then
    -- Hand the extra joints back to the default animations.
    posed[model]=nil
    for _,name in {"RightElbow","LeftElbow","RightKnee","LeftKnee","Neck","Waist","Root"} do
     if motors[name] then motors[name].Transform=CFrame.identity end
    end
   end
   local speed=root and Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude or 0
   -- v38: a captured walk (Bulwark's sword-and-shield walk) replaced the run on the ground. v46 (Peter:
   -- Bulwark's walking looked wrong): it played at one speed whatever his pace, so his feet slid; his
   -- Knight run (paced to his speed) is back. Captured loops now only cover flying and sneaking.
   -- v50: a hero with captured ground loops (Sig.LOOPS) plays them instead of the Roblox idle/run.
   local loops=Sig.LOOPS[Sig.heroOf(model)]
   local ls,rate=nil,1
   if loops and not model:GetAttribute("Flying") and root and math.abs(root.AssemblyLinearVelocity.Y)<4 then
    if speed>1.5 then ls=loops.run; rate=math.clamp(speed/14,0.6,1.8) else ls=loops.idle end
   end
   if Sig.mocap(model,nil,ls,now,rate) then
    if set then playLoco(set,nil); for _,tr in set.tracks do if tr.IsPlaying then tr:Stop(0) end end end -- no fade: a blending Roblox run would fight the capture
    Sig.Motion.apply(model,motors,now,true) -- true: the capture owns the limbs (Motion.ground would lerp over it)
    if Sig.strafe then Sig.strafe(model,motors,speed>1.5 and root or nil,nil,now) end -- V55b: strafe turn on captured loops too
    Sig.twoHand(model,motors,p) -- V60b
    continue
   end
   -- V49b: a capture stopped the Roblox clip earlier with set.current still naming it; clear it so playLoco restarts.
   if set and set.current and set.tracks[set.current] and not set.tracks[set.current].IsPlaying then set.current=nil end
   if set then
    local vy=root and root.AssemblyLinearVelocity.Y or 0
    if model:GetAttribute("Flying") then playLoco(set,"idle")
    elseif vy>4 and set.tracks.jump then playLoco(set,"jump")
    elseif vy<-6 and set.tracks.fall then playLoco(set,"fall")
    elseif speed>1.5 then playLoco(set,"run",math.clamp(speed/16,0.6,1.6))
    else playLoco(set,"idle") end
    Sig.Motion.apply(model,motors,now,false)
    if Sig.strafe then Sig.strafe(model,motors,speed>1.5 and root or nil,set,now) end -- V55b: after Motion.ground, which rewrote Root/Waist every frame and hid the strafe turn
    Sig.twoHand(model,motors,p) -- V60b
    continue
   end
   local swing=math.sin(now*10)*math.min(speed/20,1)*0.5
   if motors.RightShoulder then motors.RightShoulder.Transform=CFrame.Angles(-swing,0,0) end
   if motors.LeftShoulder then motors.LeftShoulder.Transform=CFrame.Angles(swing,0,0) end
   if motors.RightHip then motors.RightHip.Transform=CFrame.Angles(swing,0,0) end
   if motors.LeftHip then motors.LeftHip.Transform=CFrame.Angles(-swing,0,0) end
  end
  Sig.Motion.apply(model,motors,now,p~=nil or model:GetAttribute("Blocking"))
  Sig.Motion.attack(model,motors,p,now)
  Sig.twoHand(model,motors,p) -- V60b
 end
end)
-- v26 hair, capes and shield (looks only, run on every client). Pieces the server hung on a Weld swing
-- here: hair and capes trail behind movement, stream back in flight, drift in a breeze and lift with
-- static while Tempest casts. Bulwark's shield moves from his forearm to in front of his chest when he guards.
local swayState=setmetatable({},{__mode="k"})
-- v50 cloth: the bones of a cape or coat (Appearance BODY.cloth), found once per fighter and rechecked every 2 s.
Sig.clothLists=setmetatable({},{__mode="k"}) -- on Sig: the main chunk is at Luau's 200-local limit
function Sig.clothBones(model,now)
 local c=Sig.clothLists[model]
 if c and (c.bones[1]==nil or c.bones[1].bone.Parent) and now-c.at<2 then return c.bones end
 if c and c.bones[1] and c.bones[1].bone.Parent and c.bones[1].bone:IsDescendantOf(model) then c.at=now; return c.bones end
 local bones={}
 for _,part in model:GetChildren() do
  if part:IsA("BasePart") and part:GetAttribute("Cloth") then
   for _,b in part:GetDescendants() do
    local chain,k=string.match(b.Name,"^C(%d+)_(%d+)$")
    if chain and b:IsA("Bone") then table.insert(bones,{bone=b,chain=tonumber(chain),k=tonumber(k)}) end
   end
  end
 end
 Sig.clothLists[model]={bones=bones,at=now}
 return bones
end
local swayLists=setmetatable({},{__mode="k"})
local function swayList(model)
 local list=swayLists[model]
 if list then
  local ok=true
  for _,w in list do if not w.Parent or not w.Parent.Parent then ok=false; break end end
  if ok and #list>0 then return list end
 end
 list={}
 for _,p in model:GetChildren() do
  if p:IsA("BasePart") then
   local w=p:FindFirstChild("SwayWeld") or p:FindFirstChild("ShieldWeld")
   if w and w:IsA("Weld") then table.insert(list,w) end
  end
 end
 swayLists[model]=list
 return list
end
RunService.RenderStepped:Connect(function(dt)
 dt=math.min(dt,1/20)
 local now=os.clock()
 local cam=workspace.CurrentCamera; local camPos=cam and cam.CFrame.Position or Vector3.zero
 local swayFar=UIS.TouchEnabled and 60 or 120
 for model in rigs do
  if not model.Parent then continue end
  local list=swayList(model)
  local root=model:FindFirstChild("HumanoidRootPart")
  if not root then continue end
  -- R66-ui8: cape/armour sway is skipped for fighters far from the camera (120 studs on PC, 60 on phones),
  -- where nobody can see it; with 12 players and 4 practice dummies that is most rigs most of the time.
  if (root.Position-camPos).Magnitude>swayFar then continue end
  local v=root.CFrame:VectorToObjectSpace(root.AssemblyLinearVelocity)
  local flying=model:GetAttribute("Flying")==true
  -- v50 cloth: cape and coat bones blow in a breeze, stream back with speed and in flight, growing down each chain.
  local bones=Sig.clothBones(model,now)
  if bones[1] then
   local back=math.clamp(-v.Z*0.03,0,0.9)+(flying and 0.5 or 0)
   for _,b in bones do
    local gust=0.5+0.5*math.sin(now*0.7+b.chain*0.9); local flap=math.sin(now*3.1+b.k*0.8+b.chain*0.5)
    b.bone.Transform=CFrame.Angles(-(0.05+0.14*gust+back)*b.k^0.8-0.05*flap*b.k,0.04*flap*b.k,0.03*math.sin(now*2.3+b.chain))
   end
  end
  if #list==0 then continue end
  local p=poses[model]
  local charged=p and (p.name=="Lightning" or p.name=="Gale")
  local guard=model:GetAttribute("Blocking")==true or model:GetAttribute("Shielded")==true or model:GetAttribute("Parrying")==true
  for i,w in list do
   local st=swayState[w]
   if not st then st={base=w:GetAttribute("ShieldPivot") or w.C0,piece=w:GetAttribute("ShieldPieceOffset") or CFrame.identity,ax=0,az=0,vx=0,vz=0,g=0,phase=i*1.7}; swayState[w]=st end
   local part=w.Part1
   if w.Name=="ShieldWeld" then
    -- v50 Shield Throw: through the Interrupt the shield leaves the forearm, spins out along the aim and comes back.
    -- The pose entry is cleared as soon as the capture takes over, so the flight is timed off the capture
    -- itself (Sig.mocapNow), which lasts the whole move.
    local cur=Sig.mocapNow[model]; local tp=cur and cur.name=="bulwark_shieldthrow" and cur.p or nil
    if tp and tp.start and Sig.heroOf(model)=="Bulwark" then
     local arm=w.Part0
     if arm then
      local dur=math.max(tp.move and (tp.move.Startup+tp.move.Active+tp.move.Recovery)/60 or 1.1,0.6)
      local u=math.clamp((now-tp.start-0.1)/(dur-0.1),0,1); local reach=(tp.move and tp.move.Range or 35)*0.85
      local pos=arm.Position+root.CFrame.LookVector*(math.sin(u*math.pi)*reach)+Vector3.new(0,1.3*math.sin(u*math.pi),0)
      w.C0=arm.CFrame:ToObjectSpace(CFrame.new(pos)*CFrame.Angles(0,now*22,0)*(arm.CFrame.Rotation*st.base.Rotation))*st.piece
      continue
     end
    end
    st.g+=((guard and 1 or 0)-st.g)*math.min(dt*14,1)
    local torso=model:FindFirstChild("UpperTorso"); local arm=w.Part0
    if st.g<0.01 or not torso or not arm then w.C0=st.base*st.piece
    else
     if Sig.heroOf(model)=="Valkyra" and root then
      -- V59: her winged kite shield has a top and a front. In guard it stands upright in front of her chest with the
      -- crest (mesh -X) facing where she faces, whatever the forearm and a crouching, leaning torso do; at rest it
      -- keeps the fit measured on her shield idle (st.base, the ShieldWeld C0 from the build).
      local look=Vector3.new(root.CFrame.LookVector.X,0,root.CFrame.LookVector.Z); look=look.Magnitude>0.01 and look.Unit or Vector3.new(0,0,-1)
      local right=look:Cross(Vector3.yAxis)
      local pos=torso.Position+look*(torso.Size.Z/2+0.9)-right*0.25+Vector3.new(0,0.05,0)
      local upright=CFrame.lookAt(pos,pos+look)*CFrame.Angles(0,-math.pi/2,0)
      w.C0=(st.base*st.piece):Lerp(arm.CFrame:ToObjectSpace(upright),st.g)
     else
     local front=torso.CFrame*CFrame.new(-0.25,0.05,-(torso.Size.Z/2+0.9))*CFrame.Angles(0,-math.pi/2,0)
     -- v31: a catalog shield keeps its own turn (base.Rotation; identity for the kit shield).
     w.C0=st.base:Lerp(arm.CFrame:ToObjectSpace(front)*st.base.Rotation,st.g)*st.piece
     end
    end
    continue
   end
   local weight=part and part:GetAttribute("Sway") or 1
   -- Targets in radians: X tips the piece back (-) or forward (+), Z swings it sideways.
   local tx=math.clamp(v.Z*0.035,-1.0,0.35)+math.clamp(v.Y*0.02,-0.25,0.3)
   local tz=math.clamp(-v.X*0.03,-0.6,0.6)
   tx+=math.sin(now*1.7+st.phase)*0.06; tz+=math.cos(now*1.3+st.phase)*0.05
   if flying then tx-=0.45; tx+=math.sin(now*12+st.phase)*0.1 end
   if charged then
    local side=st.base.Position.X>=0 and 1 or -1
    tx-=0.35; tz+=side*0.3+math.sin(now*40+st.phase)*0.06
   end
   tx*=weight; tz*=weight
   -- A damped spring, so pieces overshoot a little and settle.
   st.vx+=((tx-st.ax)*60-st.vx*9)*dt; st.vz+=((tz-st.az)*60-st.vz*9)*dt
   st.ax+=st.vx*dt; st.az+=st.vz*dt
   w.C0=st.base*CFrame.Angles(st.ax,0,st.az)
  end
 end
end)
remote.OnClientEvent:Connect(function(kind,a,b,c,d,e,f,g,h,sneakBonus)
 if kind=="Fx" and Sig.fxFar and Sig.fxFar(a,b,c) then return end -- R66-ui: skip effects from far-off fights
 if kind=="Notice" then notice.Text=a
 elseif kind=="Bot" then showBot(a,b)
 elseif kind=="Arena" then
  local info=type(a)=="string" and Rules.Arenas[a]
  if info then arenaButton.Text="Arena: "..info.Title.." (click to change)"; notice.Text="Arena: "..info.Title end
 elseif kind=="Paused" then
  pausedNow=a==true
  pauseButton.Text=a=="resuming" and "Resuming…" or pausedNow and "Resume (P)" or "Pause (P)"
  notice.Text=a=="resuming" and "Resuming in 3…" or pausedNow and ((b or "Someone").." paused the match. Press P to resume.") or "Fight on!"
 elseif kind=="Duels" then if Sig.onDuels then Sig.onDuels(a,b) end
 elseif kind=="Challenge" then if Sig.onChallenge then Sig.onChallenge(a) end
 elseif kind=="Round" then
  -- a: {phase, number, left, wins={name=count}, banner}
  if type(a)~="table" then return end
  if a.phase=="Waiting" then
   roundLabel.Visible=true
   local hint=UIS.TouchEnabled and "Practice • START FIGHT, QUEUE or CHALLENGE in MENU" or "Practice • START FIGHT (R) duels the bot • QUEUE or CHALLENGE (menu) for a player"
   if roundLabel.Text~=hint then
    roundLabel.Text=hint; roundLabel.TextTransparency=0; roundLabel.BackgroundTransparency=0.55
    local tok=os.clock(); roundLabel:SetAttribute("FadeTok",tok)
    task.delay(4,function()
     if roundLabel:GetAttribute("FadeTok")==tok then TweenService:Create(roundLabel,TweenInfo.new(1.2),{TextTransparency=1,BackgroundTransparency=1}):Play() end
    end)
   end
   restartButton.Text="START FIGHT (R)"; restartButton.BackgroundColor3=Color3.fromRGB(40,110,60)
  else
   local score={}
   for name,w in a.wins do table.insert(score,name.." "..string.rep("●",w)..string.rep("○",Rules.Round.WinsNeeded-w)) end
   local clock=a.phase=="Fight" and string.format("%d:%02d",a.left//60,a.left%60) or a.phase=="Countdown" and ("Starts in "..a.left) or "—"
   roundLabel.Visible=true
   if roundLabel:GetAttribute("FadeTok") then roundLabel:SetAttribute("FadeTok",nil); roundLabel.TextTransparency=0; roundLabel.BackgroundTransparency=0.55 end
   if a.paused then clock="PAUSED" end
   restartButton.Text="START OVER (R)"; restartButton.BackgroundColor3=Color3.fromRGB(90,60,40)
   roundLabel.Text=string.format("Round %d • %s • %s",a.number,clock,table.concat(score,"  vs  "))
  end
  if type(a.banner)=="string" then showBanner(a.banner) end
 elseif kind=="Binds" then
  -- Saved keys from a previous session; anything invalid falls back to the default.
  if type(a)=="table" then
   for _,act in ACTIONS do
    local pair=a[act.id]
    if type(pair)=="table" and validKey(pair[1],act.id) and validKey(pair[2],act.id) then binds[act.id]={pair[1],pair[2]} end
   end
   applyBindings(); refreshMenu()
   notice.Text="Your saved keybindings are loaded. Press K to change them."
  end
 elseif kind=="State" then
  net.settle(a)
  flying=a.flying
  -- v36: red edges when I'm low.
  local frac=(a.health or 100)/math.max(1,a.maxHealth or 100)
  Sig.vig.level=frac<0.3 and a.health>0 and (0.3-frac)/0.3+0.2 or 0
  local skill1=Rules.moveName(a.hero,a.hero=="Solarion" and "Skill2" or "Skill1",1)
  local skill2=Rules.moveName(a.hero,a.hero=="Solarion" and "Skill3" or "Skill2",1)
  hud.Text=string.format("R66-ui8 • %s • HP %d / %d • Fury %d\nFlight energy %d • %s%s\n%s %.1fs  |  %s %.1fs",Rules.display(a.hero),math.ceil(a.health),math.floor(a.maxHealth or 100),math.floor(a.fury or 0),math.floor(a.energy),a.phase,(a.shield or 0)>0 and " • SHIELD" or "",skill1 or "—",skill1 and a.cooldowns[skill1] or 0,skill2 or "—",skill2 and a.cooldowns[skill2] or 0) -- R30 fix: removed powers are nil
  furyFill.Size=UDim2.fromScale(math.clamp((a.fury or 0)/Rules.Fury.Max,0,1),1)
  furyText.Text="Fury "..math.floor(a.fury or 0)
  do
   Sig.superFill.Parent.Visible=Rules.actionAvailable(a.hero,"Super") -- R17: no meter for heroes without a Super
   local f=math.clamp((a.super or 0)/Rules.Super.Max,0,1)
   Sig.superFill.Size=UDim2.fromScale(f,1)
   Sig.superFill.BackgroundColor3=f>=1 and Color3.fromRGB(255,220,90):Lerp(Color3.fromRGB(255,255,255),(math.sin(os.clock()*8)+1)*0.25) or Color3.fromRGB(90,150,255)
   Sig.superText.Text=f>=1 and "SUPER READY (5)" or ("Super "..math.floor(f*100).."%")
  end
  lastState=a; Sig.lastState=a; refreshBar()
  debugLabel.Text=string.format("Tick %d • %s • frame %d\n%s • network ping %d ms\nHits %d • damage %d\nMovement: %s • snap-backs %d\nLast press answered in %d ms (avg %d) • refused %d\nPredicted hits %d • server disagreed %d",a.tick,a.move,a.frame,a.phase,a.ping,a.hits,a.damage,a.owned and "mine (client)" or "server",a.snaps or 0,net.lastAckMs,math.floor((net.rtt or 0)*1000+0.5),net.rejects,net.predCount,net.mispredicts)
 elseif kind=="Ack" then
  -- v30 step D: a: press number, b: accepted, c: server tick.
  -- v36: d: the move the server actually started, e: ticks the press waited in the server's buffer.
  local pend=net.pending[a]; net.pending[a]=nil
  if pend then
   net.lastAckMs=math.floor((os.clock()-pend.at)*1000+0.5)
   if (e or 0)==0 then local rtt=os.clock()-pend.at; net.rtt=net.rtt and net.rtt*0.8+rtt*0.2 or rtt end
   if b then
    for _,x in net.spent do if x.seq==a then x.acked=true end end
    -- My guessed combo step was wrong: fix the running pose in place (no restart) and the next guess.
    local me=player.Character; local p=me and poses[me]
    if d and p and p==pend.pose and p.name~=d and heroMoveOf(me,d) then p.name=d; p.move=heroMoveOf(me,d) end
    local step=d and tonumber(string.match(d,"^Light(%d)$")); if step then predictedCombo=step end
   else
    for i=#net.spent,1,-1 do if net.spent[i].seq==a then table.remove(net.spent,i) end end
    if pend.prevCombo then predictedCombo=pend.prevCombo end
    net.rejects+=1
    local me=player.Character; local p=me and poses[me]
    if p and p==pend.pose and not p.fadeJ then
     p.fadeJ=evaluate(p,p.holdFrom or os.clock()) or NEUTRAL; p.fadeFrom=os.clock(); p.holdUntil=nil; p.holdFrom=nil
    end
    if net.myLunge and net.myLunge.seq==a then net.myLunge=nil end
    if net.localDash and net.localDash.seq==a then net.localDash=nil end
   end
  end
  for id,q in net.pending do
   -- No answer after a second (dropped while respawning): treat it as refused.
   if os.clock()-q.at>1 then
    net.pending[id]=nil
    local me=player.Character; local p=me and poses[me]
    if q.pose and p==q.pose and not p.fadeJ then p.fadeJ=evaluate(p,os.clock()) or NEUTRAL; p.fadeFrom=os.clock() end
   end
  end
 elseif kind=="Snap" then
  -- v30 step C: the server put me somewhere else (a correction or a blink); ease to it.
  local root=myRootPart()
  if root and typeof(a)=="CFrame" then net.snapTo={from=root.CFrame,to=a,start=os.clock()}; net.localDash=nil; net.myLunge=nil end
 elseif kind=="Attack" then
  local p0=poses[a]
  if a==player.Character and p0 and p0.predicted and not p0.fadeJ and os.clock()-p0.start<1.2 then
   -- v36: my guessed pose is already running; confirm it (renamed if the server chose another move)
   -- instead of restarting it, so a slow connection never shows the punch twice.
   p0.predicted=nil
   if p0.name~=b and heroMoveOf(a,b) then p0.name=b; p0.move=heroMoveOf(a,b) end
  else
   local p=pose(a,b)
   -- v36: other fighters' moves start where the server is, not when the message got here. At most half
   -- the wind-up is skipped so the tell stays readable.
   if p and e and p.move and not p.aligned then p.aligned=true; p.start-=math.clamp(workspace:GetServerTimeNow()-e,0,p.move.Startup*0.5/60) end
  end
  flash(a,Color3.fromRGB(255,183,65),0.15)
  playMove(a,b,c,d)
  skinReact(a,b)
  VFX.swing(a,b)
  Sig.trail(a,poses[a])
  if a==player.Character then local cur=poses[a]; myAct={name=b,start=cur and cur.name==b and cur.start or os.clock(),contact=false,blocked=true} end
  -- v30: a buffered press the server started later still lunges on my screen (unless I already did).
  if a==player.Character and a:GetAttribute("ClientMove") and not net.myLunge and not (net.lastLungeName==b and os.clock()-net.lastLungeAt<0.6) then
   startLocalLunge(a,b,nil)
  end
  if a==player.Character then notice.Text=Rules.title(a:GetAttribute("Hero"),b) end
 elseif kind=="Fx" and b=="Pulse" then
  -- R22 Solar Hammer: a photon pulse, a bright orb with a light streak flying the length of the reach.
  if typeof(c)=="Vector3" and typeof(d)=="Vector3" and type(e)=="number" and a and not (hiddenFromMe and hiddenFromMe(a)) then
   local col=heroAccent(a,"Heavy"); local dir=d.Magnitude>0.01 and d.Unit or Vector3.zAxis
   local params=RaycastParams.new(); params.FilterType=Enum.RaycastFilterType.Exclude; params.FilterDescendantsInstances={a,fxFolder}
   local hit=workspace:Raycast(c,dir*e,params); local finish=hit and hit.Position or c+dir*e
   local span=(finish-c).Magnitude; local t=math.clamp(span/120,0.06,0.25)
   local orb=fxPart(Enum.PartType.Ball,Vector3.one*1.3,CFrame.new(c),Color3.fromRGB(255,245,215),0)
   local glow=fxPart(Enum.PartType.Ball,Vector3.one*2.4,CFrame.new(c),col,0.45)
   local light=Instance.new("PointLight"); light.Color=col; light.Range=12; light.Brightness=3; light.Parent=orb
   travel(orb,CFrame.new(finish),t); travel(glow,CFrame.new(finish),t,Vector3.one*1.2)
   beamBetween(c,finish,col,0.45,0.2)
   burst(c,col,2.2,0.15)
   task.delay(t,function()
    burst(finish,col,4,0.25); ring(finish,col,5,0.3)
    if PowerFX and PowerFX.sunburst then PowerFX.sunburst(finish,col,1.6,0.25) end -- R40
   end)
   -- R40: each photon pulse leaves a comet trail of embers and a muzzle flare at his hands.
   for i=1,6 do
    task.delay(t*i/6,function()
     local p=c:Lerp(finish,i/6)
     fadeOut(fxPart(Enum.PartType.Ball,Vector3.one*0.9,CFrame.new(p),Color3.fromRGB(255,200,90),0.2),0.25,{Size=Vector3.one*0.15})
    end)
   end
   if PowerFX and PowerFX.sunburst then PowerFX.sunburst(c,col,0.9,0.15) end
   Sig.play({"laser",0.5,1.3},c); Sig.play({"fire",0.35,1.2},c)
  end
 elseif kind=="Fx" and b=="Shield" then
  local root=a and a:FindFirstChild("HumanoidRootPart")
  if root then ring(root.Position,heroAccent(a,"Defensive"),12,0.4); Sig.play(Sig.heroOf(a)=="Bulwark" and {"clang",0.8,0.7} or {"shield",0.7,1},root) end
  if root and Sig.heroOf(a)=="Solarion" then
   -- R40 Solar Shield: a golden sun dome closes round him and fades at the end (R41: lasts c seconds,
   -- and the ShieldBreak Fx pops it early once its points are burnt off).
   local life=typeof(c)=="number" and c or 2
   local dome=fxPart(Enum.PartType.Ball,Vector3.one*2,root.CFrame,Color3.fromRGB(255,200,90),0.6)
   dome.Material=Enum.Material.ForceField
   TweenService:Create(dome,TweenInfo.new(0.2),{Size=Vector3.one*8}):Play()
   table.insert(followers,{part=dome,target=root,expires=os.clock()+life})
   task.delay(life-0.4,function() if dome.Parent then fadeOut(dome,0.4) end end)
   Debris:AddItem(dome,life+0.1)
   if solarDomes[a] and solarDomes[a].Parent then solarDomes[a]:Destroy() end
   solarDomes[a]=dome
   if PowerFX and PowerFX.sunburst then PowerFX.sunburst(root.Position,Color3.fromRGB(255,190,80),1.8,0.3) end
  end
  if a then skinReact(a,"Defensive") end
  if a==player.Character then
   local def=Rules.Defensives[a:GetAttribute("Hero") or ""]
   if def and def.Absorb then notice.Text=string.format("%s • stun broken • soaks %d damage",def.Name,def.Absorb)
   elseif def then notice.Text=string.format("%s • stun broken • %d%% less damage",def.Name,math.floor((1-(def.DamageScale or 1))*100+0.5)) end
  end
 elseif kind=="Fx" and b=="Super" then
  -- v49 super flash: a burst of light, the move's name, and a short camera punch on every screen.
  local root=a and a:FindFirstChild("HumanoidRootPart")
  if root then
   local col=heroAccent(a,"Super")
   -- Timed hero-specific payoff is emitted by PowerFX.attack.
   popText(a,string.upper(type(c)=="string" and c or "SUPER"),Color3.fromRGB(255,230,120),34)
   Sig.play({"explosion",0.8,0.8},root); Sig.punch(0.8); shake(0.7,0.25)
  end
 elseif kind=="Fx" and b=="Interrupted" then
  if a then popText(a,"INTERRUPTED",Color3.fromRGB(255,120,90),28); flash(a,Color3.fromRGB(255,120,90),0.2) end
 elseif kind=="Fx" and b=="Parry" then
  -- v48 Shield Parry: a bright flash on the raised shield; the guard pose comes from Shielded.
  local root=a and a:FindFirstChild("HumanoidRootPart")
  if root then
   local c=Color3.fromRGB(110,230,255)
   ring(root.Position,c,7,0.25); burst(root.Position+root.CFrame.LookVector*1.8+Vector3.new(0,0.8,0),c,3,0.2)
   Sig.play({"clang",0.45,1.6},root)
  end
  if a then skinReact(a,"Defensive") end
  if a==player.Character then
   local def=Rules.Defensives[a:GetAttribute("Hero") or ""]
   if def then notice.Text=string.format("%s • stun broken • parry the next blow",def.Name) end
  end
 elseif kind=="Fx" and b=="ShadowStep" then
  local root=a and a:FindFirstChild("HumanoidRootPart")
  if root and typeof(c)=="Vector3" then
   local accent=heroAccent(a,"Defensive"); skinReact(a,"Defensive")
   burst(c,accent,6,0.3); ring(c-Vector3.new(0,2.8,0),accent,8,0.35)
   burst(root.Position,accent,5,0.3); afterimages(root,accent,4); beamBetween(c,root.Position,accent,0.5,0.25)
   Sig.play({"wind",0.6,1.4},root); Sig.play({"zap",0.5,1.2},root)
  end
  if a==player.Character then
   local def=Rules.Defensives[a:GetAttribute("Hero") or ""]
   notice.Text=(def and def.Name or "Blink").." • stun broken"
  end
 elseif kind=="Fx" and b=="Vanish" then
  -- v28 Vanish: a burst of shadow where he stood (or a REVEALED flash if a Solar Flare is on him).
  if typeof(c)=="Vector3" then
   local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,CFrame.new(c),Color3.new(),1)
   local att=Instance.new("Attachment"); att.Parent=holder; shadowSmoke(att,0):Emit(45); Debris:AddItem(holder,2)
   ring(c-Vector3.new(0,2.8,0),heroAccent(a,"Defensive"),9,0.4)
  end
  if typeof(c)=="Vector3" then Sig.play({"ghost",0.7,0.8},c) end
  if d and a then popText(a,"REVEALED",Color3.fromRGB(255,190,70),24) end
  if a==player.Character then notice.Text=d and "Vanish • stun broken • you're lit up, can't vanish" or "Vanish • hidden for 3 s • attacking reveals you" end
 elseif kind=="Fx" and b=="Teleport" then
  -- v28 Shadow Door (smoke) / Dimension Door (blue-white portals) at both ends.
  local root=a and a:FindFirstChild("HumanoidRootPart")
  if root and typeof(c)=="Vector3" then
   local door=d=="DimensionDoor"; local col=door and Color3.fromRGB(150,200,255) or heroAccent(a)
   for _,at in {c,root.Position} do
    local disc=fxPart(Enum.PartType.Cylinder,Vector3.new(0.2,0.5,0.5),CFrame.new(at)*CFrame.Angles(0,0,0),col,0.2)
    fadeOut(disc,0.45,{Size=Vector3.new(0.2,6,6)})
    if not door then
     local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,CFrame.new(at),Color3.new(),1)
     local att=Instance.new("Attachment"); att.Parent=holder; shadowSmoke(att,0):Emit(25); Debris:AddItem(holder,1.5)
    else burst(at,Color3.new(1,1,1),4,0.25) end
   end
   afterimages(root,col,3)
   Sig.play({"portal",0.7,door and 0.75 or 1.25},root); if not door then Sig.play({"ghost",0.5,1},root) end
  end
 elseif kind=="Fx" and b=="DoorSlam" then
  -- R23 Dimension Door arrival: a blue-white shock ring and a downward blast.
  if typeof(c)=="Vector3" and a and not (hiddenFromMe and hiddenFromMe(a)) then
   local col=Color3.fromRGB(150,200,255)
   ring(c,col,16,0.4); ring(c,Color3.new(1,1,1),9,0.25); burst(c,col,7,0.3)
   beamBetween(c+Vector3.new(0,6,0),c-Vector3.new(0,3,0),col,1.2,0.25)
   Sig.play({"stomp",1,0.8},c); Sig.play({"explosion",0.5,1.1},c)
   local me=myRootPart and myRootPart()
   if me and (me.Position-c).Magnitude<18 then shake(0.7,0.3) end
   Sig.quake(c,1.4) -- R30 earthquake on arrival
  end
 elseif kind=="Fx" and b=="HolyRing" then
  -- R35 Bulwark's holy Earth Slam: a ring of gold light rolls out, pillars of light rise round him, a
  -- bright flash, an "angel arrives" chord, and everyone inside is outlined in gold for 2 s (RevealEnd).
  if typeof(c)=="Vector3" and a then
   local r=type(d)=="number" and d or 12
   local gold=Color3.fromRGB(255,225,140); local white=Color3.fromRGB(255,250,230)
   ring(c-Vector3.new(0,2.5,0),gold,r*2,0.55); ring(c-Vector3.new(0,2.5,0),white,r*1.2,0.35)
   for i=1,10 do
    local ang=i/10*math.pi*2
    local p=c+Vector3.new(math.cos(ang)*r*0.8,1,math.sin(ang)*r*0.8)
    local pillar=fxPart(Enum.PartType.Cylinder,Vector3.new(0.4,1.4,1.4),CFrame.new(p-Vector3.new(0,3,0))*CFrame.Angles(0,0,math.pi/2),gold,0.3)
    fadeOut(pillar,0.9,{Size=Vector3.new(14,0.3,0.3),CFrame=CFrame.new(p+Vector3.new(0,4,0))*CFrame.Angles(0,0,math.pi/2)})
   end
   beamBetween(c+Vector3.new(0,22,0),c-Vector3.new(0,2,0),white,3,0.45)
   local flashPart=anchorPoint(CFrame.new(c+Vector3.new(0,3,0)))
   local light=Instance.new("PointLight"); light.Color=gold; light.Range=r*2.5; light.Brightness=6; light.Parent=flashPart
   TweenService:Create(light,TweenInfo.new(1.2),{Brightness=0}):Play(); Debris:AddItem(flashPart,1.3)
   if Rules.AngelChoirSound and Rules.AngelChoirSound~="" then
    local snd=Instance.new("Sound"); snd.SoundId=Rules.AngelChoirSound; snd.Volume=0.8; snd.RollOffMaxDistance=160
    snd.Parent=flashPart; snd:Play()
   else
    Sig.play({"shield",0.7,1.5},c); Sig.play({"shield",0.5,1.2},c); Sig.play({"portal",0.4,1.6},c)
   end
   Sig.play({"stomp",0.9,0.8},c)
   popText(a,"SPEED UP",Color3.fromRGB(255,225,140),26)
   local me=myRootPart and myRootPart()
   if me and (me.Position-c).Magnitude<r*2 then shake(0.6,0.3) end
  end
 elseif kind=="Fx" and b=="ShieldThrow" then
  -- R37 Bulwark's Shield Throw: the shield spins out like a frisbee and curves back to his hand. His
  -- own shield is hidden while it's in the air.
  if typeof(c)=="Vector3" and typeof(d)=="Vector3" and a and not (hiddenFromMe and hiddenFromMe(a)) then
   local range=type(e)=="number" and e or 35; local out=math.max(0.12,type(f)=="number" and f or 0.2)
   local held
   for _,p in a:GetChildren() do if p:IsA("BasePart") and p:FindFirstChild("ShieldWeld") then held=p end end
   if held then held.LocalTransparencyModifier=1 end
   local disc=fxPart(Enum.PartType.Cylinder,Vector3.new(0.35,3.4,3.4),CFrame.new(c),Color3.fromRGB(150,155,165),0,Enum.Material.Metal)
   local rim=fxPart(Enum.PartType.Cylinder,Vector3.new(0.4,3.7,3.7),CFrame.new(c),Color3.fromRGB(205,160,80),0,Enum.Material.Metal)
   local boss=fxPart(Enum.PartType.Cylinder,Vector3.new(0.5,1.2,1.2),CFrame.new(c),Color3.fromRGB(240,200,110),0.1)
   local trail={}
   local side=Vector3.yAxis:Cross(d); if side.Magnitude<0.01 then side=Vector3.xAxis end; side=side.Unit
   local t0=os.clock(); local back=out*1.4
   local conn; conn=RunService.RenderStepped:Connect(function()
    local t=os.clock()-t0
    local hand=a.Parent and (a:FindFirstChild("LeftHand") or a:FindFirstChild("HumanoidRootPart"))
    local home=hand and hand.Position or c
    local pos
    if t<out then local k=t/out; pos=c+d*range*math.sin(k*math.pi/2)+side*math.sin(k*math.pi)*2
    elseif t<out+back then local k=(t-out)/back; local far=c+d*range; pos=far:Lerp(home,k*k)-side*math.sin(k*math.pi)*4+Vector3.new(0,math.sin(k*math.pi)*1.5,0)
    else
     conn:Disconnect(); for _,p in {disc,rim,boss} do p:Destroy() end
     if held and held.Parent then held.LocalTransparencyModifier=0 end
     Sig.play({"clang",0.5,1.3},home); return
    end
    local spin=CFrame.Angles(0,t*40,0)*CFrame.Angles(0,0,math.pi/2) -- flat, spinning about the vertical
    local cf=CFrame.new(pos)*spin
    disc.CFrame=cf; rim.CFrame=cf; boss.CFrame=cf
    if #trail<40 and math.random()<0.7 then
     table.insert(trail,true)
     fadeOut(fxPart(Enum.PartType.Ball,Vector3.one*0.9,CFrame.new(pos),Color3.fromRGB(255,215,140),0.4),0.2,{Size=Vector3.one*0.1})
    end
   end)
   Sig.play({"swingHeavy",0.8,1.3},c); Sig.play({"wind",0.4,1.6},c)
  end
 elseif kind=="Fx" and b=="Riposte" then
  -- R36 Bulwark's parry riposte: a shield flash and a heavy bash back.
  if typeof(c)=="Vector3" and a then
   local bronze=Color3.fromRGB(255,200,110)
   ring(c,bronze,9,0.3); burst(c,Color3.new(1,1,1),5,0.2)
   Sig.play({"clang",1,0.8},c); Sig.play({"punchHeavy",0.9,0.7},c)
   popText(a,"RIPOSTE!",bronze,30)
   if e then popText(e,"-"..tostring(d or 0),Color3.fromRGB(255,120,90),22) end
   local me=myRootPart and myRootPart()
   if me and (me.Position-c).Magnitude<20 then shake(0.6,0.25) end
  end
 elseif kind=="Fx" and b=="Armor" then
  -- R36 super armour: the hit sparks off his plate and he keeps coming.
  if typeof(c)=="Vector3" and a then
   burst(c+Vector3.new(0,1,0),Color3.fromRGB(255,220,150),3.5,0.18); Sig.play({"clang",0.7,1.2},c)
   popText(a,"ARMOR",Color3.fromRGB(255,220,150),20)
  end
 elseif kind=="Fx" and b=="WallSplat" then
  if typeof(c)=="Vector3" and a then
   Sig.quake(c,0.8); Sig.play({"explosion",0.6,0.9},c); Sig.play({"punchHeavy",1,0.6},c)
   popText(a,"WALL SPLAT! -"..tostring(d or 0),Color3.fromRGB(255,170,80),32)
  end
 elseif kind=="Fx" and b=="Shockwave" then
  -- R36 Juggernaut x5: Titan Cleave sends a ground shockwave along the aim.
  if typeof(c)=="Vector3" and typeof(d)=="Vector3" and a then
   local len=type(e)=="number" and e or 20
   for i=1,8 do
    task.delay(i*0.035,function()
     Sig.quake(c+d*(len*i/8)-Vector3.new(0,2.5,0),0.35)
    end)
   end
   Sig.play({"thunder",0.6,0.6},c)
   popText(a,"JUGGERNAUT!",Color3.fromRGB(255,140,50),34)
  end
 elseif kind=="Fx" and b=="Drain" then
  -- R38 Soul Drain: a purple wisp leaves the victim and flies into Wraithstep, who glows and heals.
  if typeof(c)=="Vector3" and a then
   popText(a,"-"..tostring(d or 0).." DRAIN",Color3.fromRGB(190,110,255),26) -- R46: bigger and named
   flash(a,Color3.fromRGB(150,60,230),0.15)
   burst(c,Color3.fromRGB(120,40,200),2.5,0.25)
   local to=e and e.Parent and e:FindFirstChild("HumanoidRootPart")
   if to then
    local orb=fxPart(Enum.PartType.Ball,Vector3.one*0.8,CFrame.new(c+Vector3.new(0,1,0)),Color3.fromRGB(180,90,255),0.1)
    TweenService:Create(orb,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=to.CFrame,Size=Vector3.one*0.3}):Play()
    Debris:AddItem(orb,0.4)
    task.delay(0.35,function() if to.Parent then popText(e,"+"..tostring(d or 0).." HEAL",Color3.fromRGB(120,255,140),26); flash(e,Color3.fromRGB(150,80,255),0.12) end end)
   end
  end
 elseif kind=="Fx" and b=="WhirlCast" then
  -- R42 Whirlwind: a spinning funnel leaves Tempest's hands and races to the enemy it locked onto
  -- (or blows out ahead of her and dies away on a miss).
  local from=a and a:FindFirstChild("HumanoidRootPart")
  if from and typeof(c)=="Vector3" then
   local rings={}
   for i=1,6 do rings[i]=fxPart(Enum.PartType.Cylinder,Vector3.new(0.25,2+i*1.3,2+i*1.3),from.CFrame,Color3.new(0.9,0.97,1),0.3) end
   local holder=fxPart(Enum.PartType.Ball,Vector3.one*0.1,from.CFrame,Color3.new(),1)
   local att=Instance.new("Attachment"); att.Parent=holder
   local e=emitter(att,Color3.fromRGB(205,220,240),{Rate=60,Lifetime=NumberRange.new(0.4,0.7),Speed=NumberRange.new(3,6),
    SpreadAngle=Vector2.new(180,40),Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,2.6)})})
   e.Texture=SMOKE_TEXTURE; e.RotSpeed=NumberRange.new(-200,200)
   e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.4),NumberSequenceKeypoint.new(1,1)})
   Sig.play({"wind",0.9,0.8},from); if PowerFX and PowerFX.storm then PowerFX.storm(from.Position+Vector3.new(0,3,0),c+Vector3.new(0,3,0),Color3.fromRGB(150,210,255),0.12,0.25) end
   local start=from.Position; local t0=os.clock(); local travel=math.clamp((c-start).Magnitude/140,0.15,0.45)
   task.spawn(function()
    while true do
     local k=(os.clock()-t0)/travel
     local fade=math.clamp(k-1,0,1)/0.5
     if fade>=1 then break end
     local base=start:Lerp(c,math.min(k,1))-Vector3.new(0,2.5,0)
     local spin=os.clock()*14
     holder.CFrame=CFrame.new(base)
     for i,r in rings do
      if r.Parent then
       r.CFrame=CFrame.new(base+Vector3.new(0,i*1.3,0))*CFrame.Angles(0,spin+i,0)*CFrame.Angles(0,0,math.pi/2)
       r.Transparency=0.3+0.7*fade
      end
     end
     RunService.Heartbeat:Wait()
    end
    for _,r in rings do r:Destroy() end
    e.Enabled=false; Debris:AddItem(holder,1)
   end)
   if d then
    ring(c-Vector3.new(0,2.5,0),Color3.fromRGB(200,235,255),10,0.4)
    Sig.play({"wind",1,0.6},c)
   end
  end
 elseif kind=="Fx" and b=="ShadeCast" then
  -- R49 Shade Bolt: a dark purple bolt streaks from the (hidden) Wraithstep to the target.
  local from=a and a:FindFirstChild("RightHand") or (a and a:FindFirstChild("HumanoidRootPart"))
  if from and typeof(c)=="Vector3" then
   local bolt=fxPart(Enum.PartType.Ball,Vector3.one*1.1,from.CFrame,Color3.fromRGB(120,40,200),0.15)
   bolt.Material=Enum.Material.Neon
   local att=Instance.new("Attachment"); att.Parent=bolt
   local tr=emitter(att,Color3.fromRGB(150,70,230),{Rate=60,Lifetime=NumberRange.new(0.2,0.35),Speed=NumberRange.new(0,1),
    Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0.6),NumberSequenceKeypoint.new(1,0)})})
   tr.LightEmission=0.6
   local travel=math.clamp((c-from.Position).Magnitude/120,0.1,0.35)
   TweenService:Create(bolt,TweenInfo.new(travel,Enum.EasingStyle.Linear),{CFrame=CFrame.new(c)}):Play()
   Debris:AddItem(bolt,travel+0.05)
   task.delay(travel,function() burst(c,Color3.fromRGB(120,40,200),3,0.25) end)
   Sig.play({"dash",0.5,1.3},from.Position)
  end
 elseif kind=="Fx" and b=="Heal" then
  -- R52 Bulwark's parry heal window.
  if a and typeof(d)=="number" and d>0 then
   popText(a,string.format("+%s HEAL",d%1==0 and tostring(d) or string.format("%.1f",d)),Color3.fromRGB(120,255,140),26)
   flash(a,Color3.fromRGB(255,225,120),0.15)
   if typeof(c)=="Vector3" then ring(c-Vector3.new(0,2.5,0),Color3.fromRGB(255,215,110),7,0.3) end
  end
 elseif kind=="Fx" and b=="Glitch" then
  -- R50: Phase flickers him into view; a purple static flash marks it.
  if a then
   flash(a,Color3.fromRGB(160,70,255),0.3)
   if typeof(c)=="Vector3" then burst(c,Color3.fromRGB(150,60,230),3,0.2) end
   popText(a,"GLITCH",Color3.fromRGB(200,140,255),20)
  end
 elseif kind=="Fx" and b=="Shade" then
  -- R49 Shade Bolt tick: a wisp flies to Wraithstep, who heals.
  if typeof(c)=="Vector3" and a then
   popText(a,"-"..tostring(d or 0).." SHADE x"..tostring(f or 1),Color3.fromRGB(175,95,255),26)
   flash(a,Color3.fromRGB(120,40,200),0.15)
   local to=e and e.Parent and e:FindFirstChild("HumanoidRootPart")
   if to and (d or 0)>0 then
    local orb=fxPart(Enum.PartType.Ball,Vector3.one*0.7,CFrame.new(c+Vector3.new(0,1,0)),Color3.fromRGB(170,80,255),0.1)
    TweenService:Create(orb,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=to.CFrame,Size=Vector3.one*0.3}):Play()
    Debris:AddItem(orb,0.4)
    if not hiddenFromMe(e) then task.delay(0.35,function() if to.Parent then popText(e,"+"..tostring(d).." HEAL",Color3.fromRGB(120,255,140),24) end end) end
   end
  end
 elseif kind=="Fx" and b=="SnareCast" then
  -- R47 Lightning Snare: a bolt from her raised hand to the sky, then down onto the locked target.
  local from=a and a:FindFirstChild("HumanoidRootPart")
  if from and typeof(c)=="Vector3" and PowerFX and PowerFX.storm then
   PowerFX.storm(from.Position+Vector3.new(0,2.5,0),from.Position+Vector3.new(0,22,0),Color3.fromRGB(160,215,255),0.18,0.3)
   PowerFX.storm(c+Vector3.new(0,22,0),c,Color3.fromRGB(190,230,255),0.2,0.35)
   Sig.play({"thunder",0.8,1.1},c)
  end
 elseif kind=="Fx" and b=="Snare" then
  -- R47: lightning bursts up from the ground round the target and keeps crackling while they're held.
  if typeof(c)=="Vector3" and a then
   local troot=a:FindFirstChild("HumanoidRootPart")
   local dur=typeof(d)=="number" and d or 2
   ring(c-Vector3.new(0,2.6,0),Color3.fromRGB(150,210,255),8,0.4)
   popText(a,"SNARED",Color3.fromRGB(150,215,255),28)
   Sig.play({"zap",0.9,0.9},c)
   task.spawn(function()
    local t0=os.clock()
    while os.clock()-t0<dur and troot and troot.Parent do
     local p=troot.Position
     for i=1,3 do
      local ang=math.random()*math.pi*2
      local base=p+Vector3.new(math.cos(ang)*2.2,-2.8,math.sin(ang)*2.2)
      if PowerFX and PowerFX.storm then PowerFX.storm(base,p+Vector3.new(math.cos(ang+2)*0.8,1.5,math.sin(ang+2)*0.8),Color3.fromRGB(160,220,255),0.12,0.18) end
     end
     task.wait(0.2)
    end
   end)
  end
 elseif kind=="Fx" and b=="SolarAbsorb" then
  -- R47: the sphere forms with a red-gold flash.
  if typeof(c)=="Vector3" then
   ring(c,Color3.fromRGB(255,80,60),(d or 12)*2,0.45)
   if PowerFX and PowerFX.sunburst then PowerFX.sunburst(c,Color3.fromRGB(255,90,70),2.5,0.4) end
   Sig.play({"fire",0.8,0.8},c)
  end
 elseif kind=="Fx" and b=="Absorb" then
  -- R47 Solar Absorb tick: a red ember leaves the victim and flies into Solarion, who heals.
  if typeof(c)=="Vector3" and a then
   popText(a,"-"..tostring(d or 0).." ABSORB",Color3.fromRGB(255,110,90),26)
   flash(a,Color3.fromRGB(255,60,50),0.15)
   local to=e and e.Parent and e:FindFirstChild("HumanoidRootPart")
   if to and (d or 0)>0 then
    local orb=fxPart(Enum.PartType.Ball,Vector3.one*0.8,CFrame.new(c+Vector3.new(0,1,0)),Color3.fromRGB(255,80,60),0.05)
    orb.Material=Enum.Material.Neon
    TweenService:Create(orb,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=to.CFrame,Size=Vector3.one*0.3}):Play()
    Debris:AddItem(orb,0.4)
    task.delay(0.35,function() if to.Parent then popText(e,"+"..tostring(d).." HEAL",Color3.fromRGB(120,255,140),26); flash(e,Color3.fromRGB(255,120,80),0.12) end end)
   end
  end
 elseif kind=="Fx" and b=="ShieldBreak" then
  -- R41: the Solar Shield's points are gone; it shatters in a gold flash.
  local dome=a and solarDomes[a]; solarDomes[a or 0]=nil
  if dome and dome.Parent then dome:Destroy() end
  if typeof(c)=="Vector3" and a then
   burst(c,Color3.fromRGB(255,200,90),6,0.35); ring(c,Color3.fromRGB(255,190,70),12,0.35)
   popText(a,"SHIELD BROKEN",Color3.fromRGB(255,200,90),26)
   Sig.play({"shield",0.8,1.4},a:FindFirstChild("HumanoidRootPart"))
  end
 elseif kind=="Fx" and b=="Zap" then
  -- R41 Tempest's lightning tick: a spark on the target, an arc back to her and the heal she gets.
  if typeof(c)=="Vector3" and a then
   popText(a,"-"..tostring(d or 0).." SHOCK",Color3.fromRGB(120,200,255),26) -- R46: bigger and named
   flash(a,Color3.fromRGB(120,200,255),0.15)
   burst(c,Color3.fromRGB(150,210,255),2.2,0.2)
   local to=e and e.Parent and e:FindFirstChild("HumanoidRootPart")
   if to and (f or 0)>0 then
    local spark=fxPart(Enum.PartType.Ball,Vector3.one*0.7,CFrame.new(c+Vector3.new(0,1,0)),Color3.fromRGB(170,225,255),0.05)
    spark.Material=Enum.Material.Neon
    TweenService:Create(spark,TweenInfo.new(0.25,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=to.CFrame,Size=Vector3.one*0.3}):Play()
    Debris:AddItem(spark,0.3)
    local healText=string.format("+%s",(f%1==0) and tostring(f) or string.format("%.1f",f))
    task.delay(0.25,function() if to.Parent then popText(e,healText.." HEAL x"..tostring(g or 0),Color3.fromRGB(120,255,170),26); flash(e,Color3.fromRGB(120,255,170),0.12) end end)
   end
  end
 elseif kind=="Fx" and b=="CircleBurn" then
  -- R35: Shadow Circle burning someone standing in it.
  if typeof(c)=="Vector3" and a then
   burst(c,Color3.fromRGB(150,60,220),3,0.3)
   popText(a,"-"..tostring(d or 0),Color3.fromRGB(190,120,255),20)
  end
 elseif kind=="Fx" and b=="Quake" then
  if typeof(c)=="Vector3" and a and not (hiddenFromMe and hiddenFromMe(a)) then Sig.quake(c,type(d)=="number" and d or 1) end
 elseif kind=="Fx" and b=="SolarFlare" then
  if typeof(c)=="Vector3" then
   PowerFX.ground(a,c,"SolarFlare")
   local me=myRootPart and myRootPart()
   if me and (me.Position-c).Magnitude<20 then shake(0.6,0.25) end
  end
 elseif kind=="Fx" and b=="TitanDropLand" then
  if typeof(c)=="Vector3" then
   PowerFX.ground(a,c,"TitanDropLand")
   Sig.play({"stomp",1,0.7},c); Sig.play({"explosion",0.5,0.8},c)
   local me=myRootPart and myRootPart()
   if me and (me.Position-c).Magnitude<30 then shake(1.3,0.4) end
   popText(a,"TITAN DROP",Color3.fromRGB(255,190,90),30)
  end
 elseif kind=="Fx" and b=="Cancel" then
  if a then flash(a,Color3.fromRGB(120,230,255),0.08) end
 elseif kind=="Hit" then
  -- R36 weight: Bulwark's hits clank and thud.
  if d and d:GetAttribute("Hero")=="Bulwark" and b~="Block" and (c or 0)>0 and a then
   local hr=a:FindFirstChild("HumanoidRootPart")
   if hr then Sig.play({"clang",0.45,0.75},hr) end
   local me=myRootPart and myRootPart()
   if me and hr and (me.Position-hr.Position).Magnitude<16 then shake(0.35,0.18) end
  end
  if (sneakBonus or 0)>0 then
   popText(a,"SNEAK ATTACK +"..tostring(sneakBonus),Color3.fromRGB(205,150,255),30)
  end
  if e=="Grapple" and d and grappleBats[d] and (c or 0)>0 and b~="Block" then
   -- The bats grab the target by the shoulders and drag it down, then dissolve.
   local troot=a and a:FindFirstChild("HumanoidRootPart")
   for i,bat in grappleBats[d] do
    if troot and not bat.dead then
     local side=troot.CFrame.RightVector*(i==1 and -1.1 or 1.1)
     setMode(bat,{kind="latch",root=troot,offset=side+Vector3.new(0,1.6,0),dur=0.9})
    end
   end
   grappleBats[d]=nil
  end
  if d==player.Character and myAct and e==myAct.name and (c or 0)>0 then
   myAct.contact=true; if b~="Block" then myAct.blocked=false end
  end
  -- a target, b result, c damage, d attacker, e move, f hit-stop ticks, g sweet spot
  local stopSec=(f or 0)/60
  -- v36: I already showed this hit's spark, sound and freeze on my screen (net.confirm); don't repeat them.
  local pre=d==player.Character and net.predHit~=nil and net.predHit.target==a and net.predHit.name==e and os.clock()-net.predHit.at<1
  if pre then net.predHit=nil; if b=="Dodge" or b=="Parry" then net.mispredicts+=1 end end
  local move=heroMoveOf(d,e or "")
  local now=os.clock()
  if c>0 then
   local stun=(move and move.Stun or 12)*((b=="Counter" and (move and move.Stun or 12)<60) and Rules.CounterStun or 1)
   local p
   if h then p={name="Pin",start=now,dur=Rules.Knockdown/60+stopSec}
   elseif (Rules.isPounce(e) or e=="Grapple") and b~="Block" and c>=14 then p={name="Pin",start=now,dur=stun/60+stopSec}
   else
    p={name="Hurt",start=now,dur=b=="Block" and 0.15 or math.clamp(stun/60,0.2,0.6),
     power=b=="Block" and 0.3 or (b=="Counter" or c>=12) and 1.3 or 0.8,react=b~="Block" and Sig.react(d,e) or nil}
   end
   -- v30: the victim shakes through the freeze, harder for bigger hits.
   if b~="Block" and stopSec>0 then p.shake=math.clamp(0.12+c*0.015,0.12,0.45) end
   poses[a]=p
   -- v30: impact-frame snap. "Hit" arrives a round trip after contact, so the attacker's pose has run on;
   -- put it back on its first impact frame before freezing it, so the freeze shows the blow landing.
   local ap=not pre and d and poses[d]
   if ap and ap.name==e and ap.move and not ap.fadeJ then
    local m=ap.move; local frame=(now-ap.start)*60
    local snapped=math.clamp(frame,m.Startup+1,m.Startup+m.Active)
    if snapped~=frame then ap.start=now-snapped/60 end
   end
   holdPose(a,stopSec); if not pre then holdPose(d,stopSec) end
   if involvesMe(a,d) and not (pre and a~=player.Character) then net.localFreezeUntil=math.max(net.localFreezeUntil,now+stopSec) end
  end
  if b=="Parry" and d then poses[d]={name="Hurt",start=now,dur=0.4,power=1} end
  flash(a,b=="Parry" and Color3.fromRGB(100,220,255) or Color3.fromRGB(255,255,255),0.06)
  task.delay(0.06,function() flash(a,b=="Parry" and Color3.fromRGB(100,220,255) or Color3.fromRGB(255,90,65),0.14) end)
  hitFx(a,b,c,d,e,g,pre)
  if not pre and (c>0 or b=="Block") then VFX.impact(a,b,c,d,e) end
  if h then VFX.slam(a) end
  if involvesMe(a,d) and c>0 then
   local big=e=="Heavy" or e=="TitanDrop" or e=="SolarFlare" or Rules.isPounce(e) or e=="SkyToss" or e=="Uppercut" or e=="Grapple" or e=="Throw" or b=="Counter" or g or h
   if not pre then shake(big and 0.9 or 0.35,big and 0.3 or 0.15) end
   -- v36: a heavy blow on me or by me flashes the screen and punches the camera in.
   if big and not pre then Sig.punch(a==player.Character and 1 or 0.7) end
  end
  if h then popText(a,"KNOCKDOWN",Color3.fromRGB(255,170,90),26) end
  if a==player.Character or d==player.Character then
   notice.Text=Rules.title(d and d:GetAttribute("Hero"),e or "").." • "..b.." • "..tostring(c).." damage"..(h and " • knockdown" or "")
  end
 elseif kind=="Whiff" then
  if a==player.Character and net.predHit and net.predHit.name==b then net.predHit=nil end
  -- Missed: the limb stays out longer and a puff of air shows the reach.
  local p=poses[a]; local move=heroMoveOf(a,b)
  if p and p.name==b and move then p.whiff=true; p.extra=move.Whiff end
  local root=a and a:FindFirstChild("HumanoidRootPart")
  if root and move and not Rules.isPounce(b) then
   local reach=root.Position+root.CFrame.LookVector*math.min(move.Range,12)+Vector3.new(0,0.4,0)
   burst(reach,Color3.fromRGB(225,225,235),1.2,0.15)
   Sig.whiff(a,b,reach,b=="Heavy" or move.Startup>=14)
  end
  if a==player.Character then notice.Text=Rules.title(a:GetAttribute("Hero"),b).." missed • longer recovery" end
 elseif kind=="Fx" and b=="PounceLand" then
  local root=a and a:FindFirstChild("HumanoidRootPart")
  if root and typeof(c)=="Vector3" then
   local accent=heroAccent(a)
   local ground=groundBelow(a,root)
   local move=Rules.Moves.Pounce
   PowerFX.ground(a,c,"PounceLand")
   Sig.play(d and {"explosion",0.8,1.1} or {"land",0.6,1},root)
   poses[a]={name="Land",start=os.clock(),whiff=not d,dur=(move.Recovery+(d and 0 or move.Whiff))/60}
   local me=myRootPart and myRootPart()
   if me and (me.Position-ground).Magnitude<25 then shake(d and 1.1 or 0.45,d and 0.35 or 0.2) end
  end
 elseif kind=="Fx" and b=="Dash" then
  local root=a and a:FindFirstChild("HumanoidRootPart")
  -- v30: a buffered dash the server started later still moves me (unless I already dashed).
  if a and a==player.Character and a:GetAttribute("ClientMove") and not net.localDash and os.clock()-net.lastDashAt>0.6 then startLocalDash(a,nil) end
  if root then Sig.dash(a,root); VFX.dash(a,root) end
  if a==player.Character and os.clock()-net.lastDashAt>0.3 then Sig.fov(5,0.35) end
 elseif kind=="Box" and debugOn then
  local box=Instance.new("Part"); box.Name="DebugHitbox"; box.Anchored=true
  box.CanCollide=false; box.CanTouch=false; box.CanQuery=false
  box.CFrame=a; box.Size=b; box.Color=Color3.fromRGB(255,180,30); box.Transparency=0.88
  box.Material=Enum.Material.Neon; box.Parent=workspace; Debris:AddItem(box,0.08)
 end
end)
-- R65 (Peter: "add strafing left to right"): a fighter running sideways or backwards while facing ahead turns
-- the legs toward where they're going (up to ~65 degrees) while the chest and head keep facing ahead, leans
-- into the step, and plays the run backwards when backpedalling. Built on each hero's own run, on every
-- client, so everyone sees everyone strafe. Looks only.
;(function()
 -- R65d: keys this client reads (Q / E strafe, rebinds) walk the fighter the same way Roblox's controls do:
 -- Player:Move each frame, right after the control script's own render step.
 local walking=false
 RunService:BindToRenderStep("HW_Walk",Enum.RenderPriority.Input.Value+1,function()
  local camera=workspace.CurrentCamera; local c=player.Character; local hum=c and c:FindFirstChildOfClass("Humanoid")
  if not camera or not hum then return end
  if Sig.walkVec().Magnitude>0.01 then
   local d=moveIntentOf(hum,camera); player:Move(Vector3.new(d.X,0,d.Z),false); walking=true
  elseif walking then walking=false; player:Move(Vector3.zero,false) end
 end)
end)()
;(function()
 local state=setmetatable({},{__mode="k"})
 Sig.strafe=function(model,motors,root,set,now)
  local st=state[model]; if not st then st={a=0,lean=0,t=now}; state[model]=st end
  local dt=math.clamp(now-st.t,0,0.1); st.t=now
  local wantA,wantLean,back=0,0,false
  if root then
   local v=root.AssemblyLinearVelocity
   local rel=root.CFrame:VectorToObjectSpace(Vector3.new(v.X,0,v.Z))
   local side,fwd=rel.X,-rel.Z; local sp=math.max(rel.Magnitude,0.01)
   back=fwd< -0.25*sp
   wantA=math.clamp(back and math.atan2(side,-fwd) or -math.atan2(side,fwd),-1.15,1.15)
   wantLean=math.clamp(side/sp,-1,1)*0.12
  end
  local k=1-math.exp(-12*dt)
  st.a+=(wantA-st.a)*k; st.lean+=(wantLean-st.lean)*k
  local run=set and set.tracks.run
  if run and root then
   local rate=math.clamp(Vector3.new(root.AssemblyLinearVelocity.X,0,root.AssemblyLinearVelocity.Z).Magnitude/16,0.6,1.6)
   run:AdjustSpeed(back and -rate or rate)
  end
  if math.abs(st.a)<0.01 and math.abs(st.lean)<0.005 then return end
  if motors.Root then motors.Root.Transform=CFrame.Angles(0,st.a,-st.lean)*motors.Root.Transform end
  if motors.Waist then motors.Waist.Transform=CFrame.Angles(0,-st.a*0.75,0)*motors.Waist.Transform end
  if motors.Neck then motors.Neck.Transform=CFrame.Angles(0,-st.a*0.25,0)*motors.Neck.Transform end
 end
end)()
-- R66 (Peter: "A How to Play card for phone and PC. It shows on first join and stays in MENU after that. And a
-- 60-90 second guided first fight against the bot"): onboarding audit items 2 and 4 (ONBOARDING_AUDIT_R64.md).
--  * How to Play: a card with this device's controls (phone or PC, the player's own keys and hero's move names).
--    It opens by itself once, the first time the lobby closes, and is always in MENU (How to play).
--  * Guided fight: 8 short steps against the sparring bot (walk up, target, combo, skills, dodge, defend a
--    swing, stop a cast, finish it), one line at a time on the left, the button to press glowing gold. Each step
--    moves on as soon as it's done; SKIP ends it. Start it from the card or MENU (Guided fight).
--  * Seen / finished is saved on the server (HeroWarsProgress DataStore); unpublished places show the card each join.
-- Wrapped in its own function: the main chunk is at Luau's 200-local limit.
;(function()
 local TS=game:GetService("TweenService")
 local touch=UIS.TouchEnabled and not UIS.KeyboardEnabled
 local GOLD=Color3.fromRGB(255,215,90)
 local G={progress=nil,active=false,step=0}
 Sig.guide=G
 local function hero() local c=player.Character; return c and c:GetAttribute("Hero") end
 local function has(id)
  local h=hero(); if not h or not Rules.actionAvailable(h,id) then return false end
  if id=="Skill1" or id=="Skill2" or id=="Skill3" or id=="Interrupt" then return Rules.moveName(h,id,1)~=nil end
  if id=="Flight" then return Rules.Characters[h]~=nil and Rules.Characters[h].Flies==true end
  return true
 end
 local function key(id)
  local b=binds[id]; if not b then return "?" end
  return keyText(b[1]~="" and b[1] or (b[2] or ""))
 end
 local function name(id)
  local h=hero()
  if id=="Defensive" then local d=h and Rules.Defensives[h]; return d and d.Name or "Defensive" end
  if id=="Dash" then return "Dodge" end
  if id=="Light" then return "Combo" end
  local mn=h and Rules.moveName(h,id,1)
  return mn and Rules.title(h,mn) or id
 end
 local function attackId() return has("Light") and "Light" or "Heavy" end
 -- "tap Pounce" on a phone, "Pounce [4]" on a PC; the big phone attack button is called ATTACK.
 local function press(id)
  if touch then return id==attackId() and "ATTACK" or name(id) end
  return name(id).." ["..key(id).."]"
 end
 local function skillIds()
  local out={}
  for _,id in {"Heavy","Skill1","Skill2","Skill3"} do
   if id~=attackId() and has(id) then table.insert(out,id) end
  end
  return out
 end
 local function save() if G.progress then remote:FireServer("SaveProgress",G.progress) end end
 local function corner(o,r) local c=Instance.new("UICorner"); c.CornerRadius=r or UDim.new(0,12); c.Parent=o; return c end
 local function text(parent,t,size,font,color)
  local l=Instance.new("TextLabel"); l.BackgroundTransparency=1; l.Text=t; l.TextSize=size; l.Font=font or Enum.Font.Gotham
  l.TextColor3=color or Color3.fromRGB(235,238,248); l.TextWrapped=true; l.TextXAlignment=Enum.TextXAlignment.Left; l.Parent=parent
  return l
 end
 ---------------------------------------------------------------- How to Play card
 local W,H=touch and 540 or 620,touch and 362 or 424 -- R66-ui6: tall enough for six rows above the buttons (was 330/400)
 local card=Instance.new("Frame"); card.Name="HowToPlay"; card.AnchorPoint=Vector2.new(0,0); card.Position=UDim2.fromOffset(12,touch and 4 or 8)
 card.Size=UDim2.fromOffset(W,H); card.BackgroundColor3=Color3.fromRGB(14,18,28); card.BackgroundTransparency=0.04
 card.Visible=false; card.ZIndex=40; card.Parent=gui; corner(card,UDim.new(0,16))
 do local st=Instance.new("UIStroke"); st.Color=GOLD; st.Thickness=2; st.Transparency=0.2; st.Parent=card end
 local fit=Instance.new("UIScale"); fit.Parent=card
 local function refit()
  local v=gui.AbsoluteSize; if v.X<10 then return end
  -- R66-ui (Peter: "make it fit, don't take up the centre of the screen"): at most 45% of the screen wide, and
  -- clear of the bottom row of buttons (100 px on phones). gui sits under Roblox's top bar, so y 4 is just below it.
  fit.Scale=math.min(1,(v.X*0.45)/W,(v.Y-(touch and 100 or 90))/H)
 end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
 local title=text(card,"HOW TO PLAY",touch and 26 or 32,Enum.Font.GothamBlack,GOLD); title.Position=UDim2.fromOffset(22,12); title.Size=UDim2.new(1,-44,0,36)
 local sub=text(card,"",14,Enum.Font.GothamMedium,Color3.fromRGB(170,178,200)); sub.Position=UDim2.fromOffset(22,touch and 42 or 50); sub.Size=UDim2.new(1,-44,0,18)
 local rows=Instance.new("Frame"); rows.BackgroundTransparency=1; rows.Position=UDim2.fromOffset(22,touch and 66 or 78); rows.Size=UDim2.new(1,-44,1,touch and -132 or -150); rows.Parent=card
 do local l=Instance.new("UIListLayout"); l.Padding=UDim.new(0,touch and 5 or 8); l.SortOrder=Enum.SortOrder.LayoutOrder; l.Parent=rows end
 local function cardButton(t,x,w,color)
  local b=Instance.new("TextButton"); b.AnchorPoint=Vector2.new(0,1); b.Position=UDim2.new(0,x,1,-16); b.Size=UDim2.fromOffset(w,touch and 42 or 46)
  b.BackgroundColor3=color; b.Text=t; b.TextColor3=Color3.new(1,1,1); b.Font=Enum.Font.GothamBold; b.TextSize=touch and 16 or 18; b.AutoButtonColor=true
  b.Parent=card; corner(b); return b
 end
 local goBtn=cardButton("START GUIDED FIGHT",22,touch and 300 or 340,Color3.fromRGB(176,128,26))
 local okBtn=cardButton("GOT IT",touch and 334 or 374,touch and 184 or 224,Color3.fromRGB(45,55,75))
 local function row(chip,t,i)
  local r=Instance.new("Frame"); r.BackgroundTransparency=1; r.Size=UDim2.new(1,0,0,touch and 32 or 38); r.LayoutOrder=i; r.Parent=rows
  local c=text(r,chip,touch and 13 or 15,Enum.Font.GothamBold,Color3.fromRGB(20,16,6)); c.BackgroundTransparency=0; c.BackgroundColor3=GOLD
  c.TextXAlignment=Enum.TextXAlignment.Center; c.Size=UDim2.new(0,touch and 92 or 130,1,-4); c.TextScaled=true; corner(c,UDim.new(0,8))
  do local k=Instance.new("UITextSizeConstraint"); k.MaxTextSize=touch and 13 or 15; k.Parent=c; local p=Instance.new("UIPadding"); p.PaddingLeft=UDim.new(0,4); p.PaddingRight=UDim.new(0,4); p.Parent=c end
  local l=text(r,t,touch and 14 or 16); l.Position=UDim2.fromOffset(touch and 104 or 144,0); l.Size=UDim2.new(1,touch and -104 or -144,1,0)
 end
 local function fillCard()
  for _,ch in rows:GetChildren() do if ch:IsA("Frame") then ch:Destroy() end end
  local h=hero() or "your hero"; local atk=attackId()
  local names={}; for _,id in skillIds() do table.insert(names,name(id)) end
  local skills=#names>0 and table.concat(names,", ") or "none"
  sub.Text=string.format("Playing as %s • %s controls",h,touch and "phone" or "PC")
  if touch then
   row("STICK","Move with the left stick. Jump with the jump button.",1)
   row("TAP","Tap a fighter to target it (the nearest foe is picked for you).",2)
   row("ATTACK","The big button: "..name(atk)..". Tap again to chain hits.",3)
   row("SKILLS","The round buttons next to ATTACK: "..skills..".",4)
   local d=name("Defensive")
   row("DEFENCE",has("Dash") and ("Dodge and "..d.." sit together. "..d.." breaks stuns.") or (d.." is your defence button. It breaks stuns."),5)
   row("MENU","Top right: Lobby (pick your hero), QUEUE or CHALLENGE a player, Leaderboard.",6)
  else
   local walk=key("MoveForward")..key("MoveLeft")..key("MoveBack")..key("MoveRight")
   row(walk,"Move. "..key("StrafeLeft").." / "..key("StrafeRight").." strafe, "..key("Rise").." jumps.",1)
   row("CLICK / "..key("TargetNext"),"Target a fighter. Your powers aim at your target.",2)
   row(key(atk),name(atk).." – your basic attack. Press again to chain hits.",3)
   local ks={}; for _,id in skillIds() do table.insert(ks,key(id)) end
   row(#ks>0 and table.concat(ks," ") or "—","Skills: "..skills..". Names are on the bar.",4)
   row((has("Dash") and key("Dash").." / " or "")..key("Defensive"),(has("Dash") and "Dodge. " or "")..name("Defensive").." breaks stuns.",5)
   row("MENU",
    "Top right: Lobby (pick your hero), QUEUE or CHALLENGE, Leaderboard. "..key("Keybinds").." changes keys.",6)
  end
  goBtn.Text=(G.progress and G.progress.tutorial) and "GUIDED FIGHT AGAIN" or "START GUIDED FIGHT"
 end
 local function openCard()
  fillCard(); refit(); card.Visible=true
  fit.Scale*=0.94; TS:Create(fit,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=fit.Scale/0.94}):Play()
  -- R66-ui3 (Peter: "it needs to disappear when the menu is shut"): the card belongs to MENU, so MENU opens with it.
  if not panel.Parent:GetAttribute("Open") then setMenuOpen(true) end
 end
 local function closeCard()
  card.Visible=false
  G.progress=G.progress or {}
  if not G.progress.howto then G.progress.howto=true; save() end
 end
 G.openCard=openCard
 Sig.guide=G -- R66-ui7: the screen layout reads whether a guided fight is running
 panel.Parent:GetAttributeChangedSignal("Open"):Connect(function()
  if not panel.Parent:GetAttribute("Open") and card.Visible then closeCard() end
 end)
 okBtn.Activated:Connect(closeCard)
 ---------------------------------------------------------------- Guided fight
 local box=Instance.new("Frame"); box.Name="GuidedFight"; box.Visible=false
 box.Position=touch and UDim2.fromOffset(12,8) or UDim2.new(0,12,0.4,0); box.Size=UDim2.fromOffset(touch and 300 or 350,touch and 96 or 108)
 box.BackgroundColor3=Color3.fromRGB(14,18,28); box.BackgroundTransparency=0.15; box.ZIndex=30; box.Parent=gui; corner(box)
 do local st=Instance.new("UIStroke"); st.Color=GOLD; st.Thickness=1.5; st.Transparency=0.3; st.Parent=box end
 local head=text(box,"GUIDED FIGHT",12,Enum.Font.GothamBold,GOLD); head.Position=UDim2.fromOffset(12,6); head.Size=UDim2.new(1,-80,0,16)
 local line=text(box,"",touch and 15 or 17,Enum.Font.GothamBold); line.Position=UDim2.fromOffset(12,24); line.Size=UDim2.new(1,-24,1,-38)
 line.TextYAlignment=Enum.TextYAlignment.Top
 local track=Instance.new("Frame"); track.Position=UDim2.new(0,12,1,-10); track.Size=UDim2.new(1,-24,0,4); track.BorderSizePixel=0
 track.BackgroundColor3=Color3.fromRGB(45,50,66); track.Parent=box
 local fill=Instance.new("Frame"); fill.BorderSizePixel=0; fill.BackgroundColor3=GOLD; fill.Size=UDim2.fromScale(0,1); fill.Parent=track
 local skip=Instance.new("TextButton"); skip.AnchorPoint=Vector2.new(1,0); skip.Position=UDim2.new(1,-8,0,6); skip.Size=UDim2.fromOffset(58,22)
 skip.BackgroundColor3=Color3.fromRGB(45,55,75); skip.Text="SKIP"; skip.TextColor3=Color3.new(1,1,1); skip.Font=Enum.Font.GothamBold; skip.TextSize=12
 skip.Parent=box; corner(skip,UDim.new(0,8))
 local glows={}
 local function setGlow(ids)
  for _,g in glows do g:Destroy() end; table.clear(glows)
  for _,id in ids or {} do
   local s=slots[id]
   if s and s.button.Parent then
    local f=Instance.new("Frame"); f.Name="GuideGlow"; f.BackgroundTransparency=1; f.AnchorPoint=Vector2.new(0.5,0.5)
    f.Position=UDim2.fromScale(0.5,0.5); f.Size=UDim2.new(1,10,1,10); f.ZIndex=8
    local c=s.button:FindFirstChildOfClass("UICorner"); corner(f,c and c.CornerRadius or UDim.new(0,10))
    local st=Instance.new("UIStroke"); st.Color=GOLD; st.Thickness=3; st.Parent=f
    TS:Create(st,TweenInfo.new(0.45,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=0.75}):Play()
    f.Parent=s.button; table.insert(glows,f)
   end
  end
 end
 local function myRoot() local c=player.Character; return c and c:FindFirstChild("HumanoidRootPart") end
 local function findBot()
  local best,bh,bd=nil,nil,math.huge; local r=myRoot()
  for _,m in workspace:GetChildren() do
   if m:IsA("Model") and m~=player.Character and m:GetAttribute("Hero") and not Players:GetPlayerFromCharacter(m) and not m:GetAttribute("DuelId") then
    local h=m:FindFirstChildOfClass("Humanoid"); local mr=m:FindFirstChild("HumanoidRootPart")
    local d=(r and mr) and (mr.Position-r.Position).Magnitude or 1e6
    if h and h.Health>0 and d<bd then best,bh,bd=m,h,d end
   end
  end
  return best,bh
 end
 local function botDist()
  local b=findBot(); local r=myRoot(); local br=b and b:FindFirstChild("HumanoidRootPart")
  return (br and r) and (br.Position-r.Position).Magnitude or math.huge
 end
 local mark=Instance.new("Highlight"); mark.FillTransparency=1; mark.OutlineColor=GOLD; mark.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
 local STEPS={}
 STEPS[1]={text=function() return touch and "Walk up to the gold-outlined dummy with the left stick."
   or ("Walk up to the gold-outlined dummy with "..key("MoveForward")..key("MoveLeft")..key("MoveBack")..key("MoveRight")..".") end,
  done=function() return botDist()<14 end}
 STEPS[2]={text=function() return touch and "Tap the bot to target it." or ("Click the bot, or press "..key("TargetNext")..", to target it.") end,
  done=function() return currentTarget~=nil end}
 STEPS[3]={glow=function() return {attackId()} end,
  text=function() return string.format("Attack! %s %s three times. (%d/3)",touch and "Tap" or "Press",press(attackId()),math.min(G.count or 0,3)) end,
  on=function(a) if a==attackId() then G.count=(G.count or 0)+1 end end, done=function() return (G.count or 0)>=3 end}
 STEPS[4]={glow=function() local out={} for _,id in skillIds() do if not G.used[id] then table.insert(out,id) end end return out end,
  text=function()
   local bits={}; for _,id in skillIds() do table.insert(bits,(G.used[id] and "✓ " or "")..press(id)) end
   return "Now your skills: "..table.concat(bits,"  •  ")
  end,
  on=function(a) G.used[a]=true end,
  done=function() for _,id in skillIds() do if not G.used[id] then return false end end return true end}
 STEPS[5]={skip=function() return not has("Dash") end, glow=function() return {"Dash"} end,
  text=function() return "Dodge! "..(touch and "Tap " or "Press ")..press("Dash").." to dash out of danger." end,
  on=function(a) if a=="Dash" then G.count=1 end end, done=function() return (G.count or 0)>0 end}
 STEPS[6]={coach="Swing",every=3.5,glow=function() return has("Dash") and {"Defensive","Dash"} or {"Defensive"} end,
  text=function() return "The bot is swinging at you! As it winds up, use "..press("Defensive")..(has("Dash") and (" or "..press("Dash")) or "")..". "..name("Defensive").." also breaks stuns." end,
  on=function(a) if (a=="Defensive" or a=="Dash" or a=="Block") and G.coached then G.count=1 end end, done=function() return (G.count or 0)>0 end}
 -- Any hit stops a cast, so every hero can do this step; the Interrupt (when the hero has one) is the clean answer.
 STEPS[7]={coach="Cast",every=4.5,glow=function() return has("Interrupt") and {"Interrupt"} or {attackId()} end,
  text=function()
   return "It's casting – watch the bar over its head! Before it fills, "..(has("Interrupt") and ("use "..press("Interrupt").." or ") or "")
    .."hit it with "..press(attackId()).." (any hit stops a cast)."
  end,
  on=function(a)
   if G.coached and (a=="Interrupt" or a=="Light" or a=="Heavy" or a=="Skill1" or a=="Skill2" or a=="Skill3" or a=="Dash" or a=="Defensive") then G.count=1 end
  end, done=function() return (G.count or 0)>0 end}
 STEPS[8]={limit=60,text=function() return "Finish it! Use everything you've learned." end,
  begin=function() G.target=findBot() end,
  done=function()
   local b=G.target; local h=b and b:FindFirstChildOfClass("Humanoid")
   return b==nil or b.Parent==nil or (h~=nil and h.Health<=0)
  end}
 local conn
 local function stop()
  G.active=false; box.Visible=false; setGlow(nil); mark.Parent=nil; Sig.onInput=nil
  if conn then conn:Disconnect(); conn=nil end
 end
 local function celebrate()
  local banner=text(gui,"GUIDED FIGHT COMPLETE\nYou earned the title: Hero in Training",touch and 18 or 24,Enum.Font.GothamBlack,GOLD)
  banner.TextXAlignment=Enum.TextXAlignment.Center; banner.AnchorPoint=Vector2.new(0.5,0); banner.Position=UDim2.new(0.5,0,0,touch and 6 or 40)
  banner.Size=UDim2.fromOffset(touch and 420 or 560,touch and 52 or 70); banner.BackgroundTransparency=0.25; banner.BackgroundColor3=Color3.fromRGB(14,18,28)
  banner.TextStrokeTransparency=0.4; banner.ZIndex=45; corner(banner)
  local tip=text(gui,"Ready for a real fight? Open MENU (top right) and press QUEUE.",14,Enum.Font.GothamBold)
  tip.TextXAlignment=Enum.TextXAlignment.Center; tip.AnchorPoint=Vector2.new(0.5,0); tip.Position=UDim2.new(0.5,0,0,touch and 62 or 116)
  tip.Size=UDim2.fromOffset(460,22); tip.ZIndex=45
  local colors={GOLD,Color3.fromRGB(110,190,255),Color3.fromRGB(255,120,90),Color3.fromRGB(150,240,150),Color3.fromRGB(230,140,255)}
  for i=1,60 do
   local p=Instance.new("Frame"); p.BorderSizePixel=0; p.BackgroundColor3=colors[i%#colors+1]; p.Size=UDim2.fromOffset(math.random(6,11),math.random(10,16))
   p.Position=UDim2.new(math.random(),0,0,-20); p.Rotation=math.random(0,360); p.ZIndex=44; p.Parent=gui
   local t=math.random(18,32)/10
   TS:Create(p,TweenInfo.new(t,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(p.Position.X.Scale+(math.random()-0.5)*0.2,0,1,20),Rotation=p.Rotation+math.random(-360,360)}):Play()
   Debris:AddItem(p,t+0.1)
  end
  local snd=Instance.new("Sound"); snd.SoundId="rbxasset://sounds/electronicpingshort.wav"; snd.Volume=0.6; snd.Parent=gui; snd:Play(); Debris:AddItem(snd,3)
  task.delay(5,function()
   for _,o in {banner,tip} do TS:Create(o,TweenInfo.new(1),{TextTransparency=1,BackgroundTransparency=1,TextStrokeTransparency=1}):Play() end
   task.wait(1.1); banner:Destroy(); tip:Destroy()
  end)
 end
 local function enter(i)
  while STEPS[i] and STEPS[i].skip and STEPS[i].skip() do i+=1 end
  G.step=i; G.count=0; G.coached=false; G.since=os.clock(); G.coachAt=-10
  local st=STEPS[i]
  if not st then
   stop(); G.progress=G.progress or {}; G.progress.tutorial=true; save(); celebrate(); return
  end
  if st.begin then st.begin() end
  -- Step numbers count only the steps this hero gets (no Dodge step for heroes without a dash).
  local n,total=0,0
  for k,x in STEPS do if not (x.skip and x.skip()) then total+=1; if k<=i then n+=1 end end end
  head.Text=string.format("GUIDED FIGHT • STEP %d / %d",n,total)
  TS:Create(fill,TweenInfo.new(0.3),{Size=UDim2.fromScale((n-1)/total,1)}):Play()
  line.Text=st.text(); setGlow(st.glow and st.glow() or nil)
 end
 local function startGuide()
  if G.active then return end
  card.Visible=false; G.active=true; G.used={}; box.Visible=true
  if touch then setMenuOpen(false) end
  local b=findBot(); mark.Adornee=b; mark.Parent=b and workspace.CurrentCamera or nil
  Sig.onInput=function(a)
   local st=STEPS[G.step]; if st and st.on then st.on(a) end
   if st then line.Text=st.text(); if st.glow then setGlow(st.glow()) end end
  end
  enter(1)
  conn=RunService.Heartbeat:Connect(function()
   local st=STEPS[G.step]; if not st then return end
   local b=findBot(); if b and mark.Adornee~=b then mark.Adornee=b; mark.Parent=workspace.CurrentCamera end
   -- Steps 6 and 7: the server makes the bot swing or cast at you (only when you stand near it).
   if st.coach and os.clock()-G.coachAt>=st.every and botDist()<20 then
    G.coachAt=os.clock(); remote:FireServer("Coach",st.coach)
    task.delay(0.3,function() if STEPS[G.step]==st then G.coached=true end end)
   end
   local age=os.clock()-G.since
   -- Each line stays up at least a second, so it can be read; a step never holds you longer than its limit.
   if age>=1 and (st.done() or age>=(st.limit or 30)) then
    enter(G.step+1)
   end
  end)
 end
 G.start=startGuide
 goBtn.Activated:Connect(function() closeCard(); G.menuShutAt=os.clock(); setMenuOpen(false); startGuide() end) -- R66-ui4: the fight starts with MENU shut
 skip.Activated:Connect(stop)
 -- R66-ui4 (Peter: "all should go when MENU is clicked again"): shutting MENU also ends the guided fight and
 -- closes the keybinds list, so nothing MENU opened stays on screen.
 panel.Parent:GetAttributeChangedSignal("Open"):Connect(function()
  if panel.Parent:GetAttribute("Open") then return end
  if G.active and os.clock()-(G.menuShutAt or -10)>0.5 then stop() end
  local kb=gui:FindFirstChild("Keybindings"); if kb then kb.Visible=false end
 end)
 -- MENU: How to play and Guided fight, always there (tiles on phones).
 do
  local hb=button("HowToButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"How to play",Color3.fromRGB(150,110,30)); hb.LayoutOrder=2
  hb.Activated:Connect(function() if card.Visible then closeCard() else openCard() end end)
  local gb=button("GuideButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Guided fight",Color3.fromRGB(150,110,30)); gb.LayoutOrder=2
  gb.Activated:Connect(function() if G.active then stop() else G.menuShutAt=os.clock(); setMenuOpen(false); startGuide() end end)
 end
 -- First join: ask the server what this player has seen, then open the card once the welcome screen and the
 -- lobby have closed and the fighter is standing.
 remote.OnClientEvent:Connect(function(kind,a) if kind=="Progress" and type(a)=="table" then G.progress=a end end)
 remote:FireServer("Progress")
 task.spawn(function()
  local t0=os.clock()
  while os.clock()-t0<600 do
   task.wait(0.5)
   local lobby=gui:FindFirstChild("Lobby")
   local ready=not gui:FindFirstChild("Welcome") and not (lobby and lobby.Visible) and myRoot()~=nil
   if ready and (G.progress or os.clock()-t0>15) then
    G.progress=G.progress or {}
    if not G.progress.howto and not G.active and not card.Visible then task.wait(0.8); openCard() end
    return
   end
  end
 end)
end)()
;(function()
 -- R66-ui: a vote bar (arena / bot changes need YES from more than half the server) and a leaderboard.
 local touch=UIS.TouchEnabled
 local GOLD=Color3.fromRGB(255,205,80)
 local function corner(o,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 10); c.Parent=o end
 ---------------------------------------------------------------- vote bar (top right, under MENU's row)
 local bar=Instance.new("Frame"); bar.Name="VoteBar"; bar.AnchorPoint=Vector2.new(1,0)
 bar.Position=UDim2.new(1,-12,0,60); bar.Size=UDim2.fromOffset(290,48) -- right edge, far from the centre
 bar.BackgroundColor3=Color3.fromRGB(20,26,44); bar.BackgroundTransparency=0.1; bar.Visible=false; bar.ZIndex=30; bar.Parent=menuToggle.Parent
 corner(bar,10)
 do local st=Instance.new("UIStroke"); st.Color=GOLD; st.Transparency=0.4; st.Parent=bar end
 local txt=Instance.new("TextLabel"); txt.BackgroundTransparency=1; txt.Position=UDim2.fromOffset(8,2); txt.Size=UDim2.fromOffset(164,44)
 txt.Font=Enum.Font.GothamBold; txt.TextScaled=true; txt.TextWrapped=true; txt.TextColor3=Color3.new(1,1,1); txt.TextXAlignment=Enum.TextXAlignment.Left; txt.ZIndex=31; txt.Parent=bar
 do local c=Instance.new("UITextSizeConstraint"); c.MaxTextSize=13; c.MinTextSize=8; c.Parent=txt end
 local yes=button("VoteYes",bar,UDim2.fromOffset(176,8),UDim2.fromOffset(56,32),"YES",Color3.fromRGB(40,120,60)); yes.ZIndex=31; yes.TextSize=13
 local no=button("VoteNo",bar,UDim2.fromOffset(236,8),UDim2.fromOffset(50,32),"NO",Color3.fromRGB(120,45,45)); no.ZIndex=31; no.TextSize=13
 corner(yes,8); corner(no,8)
 local cur,voted=nil,false
 yes.Activated:Connect(function() voted=true; yes.BackgroundTransparency=0.5; no.BackgroundTransparency=0.5; remote:FireServer("Vote",true) end)
 no.Activated:Connect(function() voted=true; yes.BackgroundTransparency=0.5; no.BackgroundTransparency=0.5; remote:FireServer("Vote",false) end)
 ---------------------------------------------------------------- leaderboard (left side, never the centre)
 local board=Instance.new("Frame"); board.Name="Leaderboard"; board.Position=UDim2.fromOffset(12,touch and 4 or 8)
 board.Size=UDim2.fromOffset(touch and 250 or 280,touch and 230 or 300); board.BackgroundColor3=Color3.fromRGB(14,18,28); board.BackgroundTransparency=0.06
 board.Visible=false; board.ZIndex=35; board.Parent=gui; corner(board,14)
 do local st=Instance.new("UIStroke"); st.Color=GOLD; st.Thickness=2; st.Transparency=0.2; st.Parent=board end
 local bscale=Instance.new("UIScale"); bscale.Parent=board
 local function refit() local v=gui.AbsoluteSize; if v.Y>50 then bscale.Scale=math.min(1,(v.Y-(touch and 100 or 90))/board.Size.Y.Offset,(v.X*0.4)/board.Size.X.Offset) end end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit); refit()
 local head=Instance.new("TextLabel"); head.BackgroundTransparency=1; head.Position=UDim2.fromOffset(14,8); head.Size=UDim2.new(1,-60,0,26)
 head.Font=Enum.Font.GothamBlack; head.TextSize=touch and 18 or 22; head.TextColor3=GOLD; head.TextXAlignment=Enum.TextXAlignment.Left; head.Text="LEADERBOARD"; head.ZIndex=36; head.Parent=board
 local close=button("CloseBoard",board,UDim2.new(1,-42,0,8),UDim2.fromOffset(32,28),"X",Color3.fromRGB(70,40,40)); close.ZIndex=36; corner(close,8)
 local body=Instance.new("TextLabel"); body.BackgroundTransparency=1; body.Position=UDim2.fromOffset(14,40); body.Size=UDim2.new(1,-28,1,-48)
 body.Font=Enum.Font.GothamMedium; body.TextSize=touch and 12 or 14; body.TextColor3=Color3.fromRGB(230,234,245); body.RichText=true
 body.TextXAlignment=Enum.TextXAlignment.Left; body.TextYAlignment=Enum.TextYAlignment.Top; body.TextWrapped=true; body.ZIndex=36; body.Parent=board
 body.Text="Loading…"
 close.Activated:Connect(function() board.Visible=false end)
 panel.Parent:GetAttributeChangedSignal("Open"):Connect(function() if not panel.Parent:GetAttribute("Open") then board.Visible=false end end)
 local lb=button("LeaderboardButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Leaderboard",Color3.fromRGB(150,110,30)); lb.LayoutOrder=2
 lb.Activated:Connect(function()
  if board.Visible then board.Visible=false; return end
  local htp=gui:FindFirstChild("HowToPlay"); if htp then htp.Visible=false end
  refit(); board.Visible=true; body.Text="Loading…"; remote:FireServer("Leaderboard")
 end)
 ---------------------------------------------------------------- R66-ui7 looks: Simple or 3D
 -- Peter: "a toon skin still, and a button to load the 3D skins separately". Simple: other fighters show their
 -- hero-coloured base body (skin meshes hidden on this screen only) and no other skins are downloaded. 3D: full
 -- skins, and the rest of the skins download in the background. Phones start Simple, PCs 3D. Your own fighter
 -- always wears its real look.
 local R15={Head=1,UpperTorso=1,LowerTorso=1,LeftUpperArm=1,LeftLowerArm=1,LeftHand=1,RightUpperArm=1,RightLowerArm=1,RightHand=1,
  LeftUpperLeg=1,LeftLowerLeg=1,LeftFoot=1,RightUpperLeg=1,RightLowerLeg=1,RightFoot=1}
 local simple=touch
 local function kitOf(d,m)
  local o=d
  while o and o~=m do if o:GetAttribute("KitPiece") then return true end; o=o.Parent end
  return false
 end
 local function look(m)
  if not (m:IsA("Model") and m:GetAttribute("Hero")) or m==player.Character then return end
  local on=simple
  for _,d in m:GetDescendants() do
   if d:IsA("BasePart") then
    if kitOf(d,m) then d.LocalTransparencyModifier=on and 1 or 0
    elseif R15[d.Name] and d.Parent==m then
     if on then
      if d:GetAttribute("ToonOrig")==nil then d:SetAttribute("ToonOrig",d.Transparency) end
      d.Transparency=0
     elseif d:GetAttribute("ToonOrig")~=nil then d.Transparency=d:GetAttribute("ToonOrig"); d:SetAttribute("ToonOrig",nil) end
    end
   elseif d:IsA("Highlight") and kitOf(d,m) then d.Enabled=not on end
  end
 end
 local watched={}
 local function watch(m)
  if watched[m] or not (m:IsA("Model") and m:GetAttribute("Hero")) then return end
  watched[m]=true
  local queued=false
  m.DescendantAdded:Connect(function() if queued then return end; queued=true; task.delay(0.3,function() queued=false; if m.Parent then look(m) end end) end)
  m.AncestryChanged:Connect(function() if not m.Parent then watched[m]=nil end end)
  look(m)
 end
 for _,m in workspace:GetChildren() do watch(m) end
 workspace.ChildAdded:Connect(function(m) task.defer(watch,m) end)
 local looksBtn=button("LooksButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"",Color3.fromRGB(60,70,110)); looksBtn.LayoutOrder=2
 local function setLooksText() looksBtn.Text=simple and "Looks: Simple (tap for 3D skins)" or "Looks: 3D skins (tap for Simple)" end
 setLooksText()
 looksBtn.Activated:Connect(function()
  simple=not simple; Preload.paused=simple; setLooksText()
  for m in watched do if m.Parent then look(m) end end
  notice.Text=simple and "Simple looks: faster, no extra skin downloads." or "3D skins on: skins download in the background."
 end)
 local function esc(t) return (tostring(t):gsub("&","&amp;"):gsub("<","&lt;"):gsub(">","&gt;")) end
 remote.OnClientEvent:Connect(function(kind,a)
  if kind=="Vote" and type(a)=="table" then
   if cur~=a.id then cur=a.id; voted=a.by==player.DisplayName; yes.BackgroundTransparency=voted and 0.5 or 0; no.BackgroundTransparency=voted and 0.5 or 0 end
   txt.Text=string.format("%s wants: %s  YES %d/%d • %ds",tostring(a.by),tostring(a.text),a.yes or 0,a.need or 0,a.left or 0)
   bar.Visible=true
  elseif kind=="VoteEnd" and type(a)=="table" then
   if cur==a.id then bar.Visible=false; cur=nil end
  elseif kind=="Board" and type(a)=="table" then
   local lines={"<b>THIS SERVER</b>  wins / losses (PvP) • bot wins"}
   for i,e in a.here or {} do
    local l=string.format("%d. %s  %d / %d • %d",i,esc(e.name),e.wins or 0,e.losses or 0,e.bot or 0)
    table.insert(lines,e.me and ('<font color="#FFCD50">'..l.."</font>") or l)
   end
   table.insert(lines,""); table.insert(lines,"<b>ALL-TIME TOP 10</b>  PvP wins")
   if #(a.top or {})==0 then table.insert(lines,"(saved wins show here once the game is published)") end
   for i,e in a.top or {} do table.insert(lines,string.format("%d. %s  %d",i,esc(e.name),e.wins or 0)) end
   body.Text=table.concat(lines,"\n")
  end
 end)
end)()
-- R64 (Peter: "classy, fade, modern style"): menu, challenge and lobby buttons get rounded glass styling:
-- a soft top-to-bottom sheen, a thin light edge that brightens on hover, and a quick fade-in when shown.
-- Wrapped in its own function: the main chunk is at Luau's 200-local limit (R64 crashed on load in Studio).
;(function()
 local TS=game:GetService("TweenService")
 local function style(b,glass)
  if not b:IsA("TextButton") or b:GetAttribute("Styled") then return end
  b:SetAttribute("Styled",true)
  if not b:FindFirstChildOfClass("UICorner") then local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=b end
  local st=b:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
  st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; st.Color=Color3.fromRGB(255,255,255); st.Transparency=0.82; st.Thickness=1; st.Parent=b
  if not b:FindFirstChildOfClass("UIGradient") then
   local g=Instance.new("UIGradient"); g.Rotation=90
   g.Color=ColorSequence.new(Color3.fromRGB(255,255,255),Color3.fromRGB(185,190,205)); g.Parent=b
  end
  if glass and b.BackgroundTransparency<0.15 then b.BackgroundTransparency=0.15 end
  b.TextStrokeTransparency=0.85
  b.TextWrapped=true -- R64b (Peter): long labels like START FIGHT (R) wrap onto two lines instead of spilling out
  b.MouseEnter:Connect(function() TS:Create(st,TweenInfo.new(0.15),{Transparency=0.35}):Play() end)
  b.MouseLeave:Connect(function() TS:Create(st,TweenInfo.new(0.25),{Transparency=b:GetAttribute("Selected") and 0 or 0.82}):Play() end)
 end
 local function styleLabel(l)
  if not l:IsA("TextLabel") or l.BackgroundTransparency>=1 or l:GetAttribute("Styled") then return end
  l:SetAttribute("Styled",true); l.BackgroundTransparency=math.max(l.BackgroundTransparency,0.3)
  if not l:FindFirstChildOfClass("UICorner") then local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,10); c.Parent=l end
  local st=Instance.new("UIStroke"); st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border; st.Color=Color3.fromRGB(255,255,255); st.Transparency=0.88; st.Parent=l
 end
 local function under(root,glass,labels)
  if not root then return end
  for _,d in root:GetDescendants() do style(d,glass); if labels then styleLabel(d) end end
  root.DescendantAdded:Connect(function(d) task.defer(function() style(d,glass); if labels then styleLabel(d) end end) end)
 end
 -- R65 (Peter: "sometimes the toon is below the ground, I don't know how to do a reload but do it"): a Reload
 -- button in MENU rebuilds your fighter at your start spot, standing on the floor. It also runs by itself when
 -- your fighter is under the floor for 2 s, or hasn't appeared 20 s after joining (then every 15 s).
 do
  local rb=button("ReloadButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Reload my fighter",Color3.fromRGB(70,50,90)); rb.LayoutOrder=3
  rb.Activated:Connect(function() remote:FireServer("Reload","button"); rb.Text="Reloading…"; task.delay(3,function() rb.Text="Reload my fighter" end) end)
  task.spawn(function()
   local started=os.clock(); local under,lastAsk=0,-30
   while true do
    task.wait(1)
    local c=player.Character; local root=c and c:FindFirstChild("HumanoidRootPart")
    if root then under=root.Position.Y< -4 and under+1 or 0 else under=0 end
    local missing=not root and os.clock()-started>20
    if (under>=2 or missing) and os.clock()-lastAsk>15 then
     lastAsk=os.clock(); under=0
     remote:FireServer("Reload",missing and "missing" or "under")
    end
   end
  end)
 end
 -- R64m (Peter: "the menu is too long, buttons missing; split it into squares with wrapped text"): on phones
 -- the menu becomes a grid of square-ish tiles, three across, every button its own tile with text that wraps
 -- and shrinks to fit. The row frames are emptied into the grid; the duel list and stats box stay hidden.
 if UIS.TouchEnabled then
  local ORDER={"Lobby","HowToButton","GuideButton","PauseButton","ButtonLayout","RestartButton","StopButton","ResetFightButton",
   "QueueButton","ChallengeButton","WatchButton","LeaderboardButton","LooksButton","SkinButton","BotButton","BotHeroButton","ArenaButton","ReloadButton"}
  local list=panel:FindFirstChildOfClass("UIListLayout"); if list then list:Destroy() end
  for i,name in ORDER do
   local b=panel:FindFirstChild(name,true)
   if b and b:IsA("TextButton") then
    b.Parent=panel; b.LayoutOrder=i; b.TextScaled=true; b.TextWrapped=true
    local c=Instance.new("UITextSizeConstraint"); c.MaxTextSize=15; c.MinTextSize=8; c.Parent=b
    local pd=Instance.new("UIPadding"); pd.PaddingLeft=UDim.new(0,4); pd.PaddingRight=UDim.new(0,4); pd.PaddingTop=UDim.new(0,3); pd.PaddingBottom=UDim.new(0,3); pd.Parent=b
   end
  end
  for _,ch in panel:GetChildren() do
   if ch:IsA("GuiObject") and not ch:IsA("TextButton") then ch.Visible=false end
  end
  local grid=Instance.new("UIGridLayout"); grid.CellSize=UDim2.fromOffset(80,64); grid.CellPadding=UDim2.fromOffset(6,6)
  grid.SortOrder=Enum.SortOrder.LayoutOrder; grid.FillDirectionMaxCells=3; grid.Parent=panel
  -- R66-ui (Peter: "the menu box needs to fit all, so none are cut off"): the grid picks its column count and
  -- tile size from the real screen so every tile shows at once, with no scrolling. It tries 3 columns first, then
  -- 4, 5, 6, keeping tiles at least 50 px tall; only on a very short screen do the tiles shrink below that (to 34).
  local shell=panel.Parent; local top=shell.Parent
  shell:SetAttribute("TouchFit",true)
  local sc=shell:FindFirstChildOfClass("UIScale"); if sc then sc.Scale=1 end
  panel.ScrollBarThickness=0
  local GAP,INNER,TOPY,BOTTOM=6,12,64,10 -- tile gap, panel padding (6 each side), menu top, margin under it
  local function fitTiles()
   local v=top.AbsoluteSize; if v.Y<50 then local cam=workspace.CurrentCamera; v=cam and cam.ViewportSize or Vector2.new(900,400) end
   if sc then sc.Scale=1 end
   local n=0
   for _,ch in panel:GetChildren() do if ch:IsA("TextButton") and ch.Visible then n+=1 end end
   n=math.max(n,1)
   local availH=v.Y-TOPY-BOTTOM-INNER
   local availW=v.X-24-INNER-6
   local cols,cellH
   for c=3,6 do
    local rows=math.ceil(n/c); local h=math.floor((availH-GAP*(rows-1))/rows)
    cols,cellH=c,h
    if h>=50 then break end
   end
   cellH=math.clamp(cellH,34,64)
   local cellW=math.clamp(math.floor((availW-GAP*(cols-1))/cols),56,cellH>=50 and 84 or 76)
   grid.FillDirectionMaxCells=cols; grid.CellSize=UDim2.fromOffset(cellW,cellH)
   local rows=math.ceil(n/cols)
   local w=cols*cellW+GAP*(cols-1)+INNER+6
   local h=rows*cellH+GAP*(rows-1)+INNER
   shell.Size=UDim2.fromOffset(w,math.min(h,math.max(80,v.Y-TOPY-BOTTOM)))
   -- Scrolling is only a fallback if even 34 px tiles in 6 columns can't fit.
   panel.ScrollingEnabled=h>v.Y-TOPY-BOTTOM
  end
  fitTiles()
  top:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitTiles)
  if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitTiles) end
  for _,ch in panel:GetChildren() do
   if ch:IsA("TextButton") then ch:GetPropertyChangedSignal("Visible"):Connect(fitTiles) end
  end
  shell:GetAttributeChangedSignal("Open"):Connect(function() if shell:GetAttribute("Open") then fitTiles() end end)
 end
 under(panel.Parent,true,true)
 style(menuToggle,true)
 under(menuToggle.Parent:FindFirstChild("ChallengeAsk"),true,false)
 local lobby=gui:FindFirstChild("Lobby")
 under(lobby,false,false)
 -- The lobby fades in instead of popping up.
 if lobby then
  local fade=lobby:FindFirstChild("FitScale") -- R64k: one UIScale; the pop-in tweens up to the fitted size
  lobby:GetPropertyChangedSignal("Visible"):Connect(function()
   local k=lobby:GetAttribute("BaseScale") or 1
   if lobby.Visible and fade then fade.Scale=k*0.96; TS:Create(fade,TweenInfo.new(0.2,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Scale=k}):Play() end
  end)
 end
end)()
-- R66-ui2 fix (Peter's phone screenshot: the How to Play card showed as a dark box with its text hidden): this
-- ScreenGui draws by global ZIndex, so the card (ZIndex 40) and the guided-fight box (30) covered their own text and
-- buttons (ZIndex 1). Everything inside them now sits one level above its parent, including rows added later.
;(function()
 local function lift(root)
  if not root then return end
  local function set(o)
   if not o:IsA("GuiObject") then return end
   local p=o.Parent; local base=0
   while p and p~=root.Parent do if p:IsA("GuiObject") then base=math.max(base,p.ZIndex) end; p=p.Parent end
   if p==root.Parent and o~=root then o.ZIndex=math.max(o.ZIndex,base+1) end
  end
  for _,d in root:GetDescendants() do set(d) end
  root.DescendantAdded:Connect(set)
 end
 lift(gui:FindFirstChild("HowToPlay")); lift(gui:FindFirstChild("GuidedFight"))
end)()
-- R66-ui5/ui6 (Peter: "the menu screens should be movable, with a 0.4 s check so no mistake moves happen"):
-- How to Play, Leaderboard, Guided fight, Keybindings, the controls hint line and the notice line can be dragged.
-- Press and hold on the panel (not on a button) for 0.4 s without moving more than 8 px: the edge turns white and
-- the panel follows your finger or mouse until you let go. A tap, a button press or a swipe never moves it.
-- ui6: presses are read from UserInputService (ui5 listened on the frames, whose text covered them, so nothing moved).
;(function()
 local HOLD,SLOP=0.4,8
 local list={}
 local function shown(o)
  if o:IsA("TextLabel") and o.TextTransparency>0.5 and o.BackgroundTransparency>0.9 then return false end -- a faded-out notice
  while o and o:IsA("GuiObject") do if not o.Visible then return false end; o=o.Parent end; return true
 end
 local function inside(o,p) local a,z=o.AbsolutePosition,o.AbsoluteSize; return p.X>=a.X and p.Y>=a.Y and p.X<=a.X+z.X and p.Y<=a.Y+z.Y end
 local function onButton(root,p)
  for _,d in root:GetDescendants() do
   if (d:IsA("GuiButton") or d:IsA("TextBox")) and shown(d) and inside(d,p) then return true end
  end
  return false
 end
 local function place(f,abs)
  local par=f.Parent; if not (par and par:IsA("GuiBase2d")) then return end
  local ps,sz=par.AbsoluteSize,f.AbsoluteSize
  local x=math.clamp(abs.X-par.AbsolutePosition.X,0,math.max(0,ps.X-sz.X))
  local y=math.clamp(abs.Y-par.AbsolutePosition.Y,0,math.max(0,ps.Y-sz.Y))
  f.Position=UDim2.fromOffset(x+f.AnchorPoint.X*sz.X,y+f.AnchorPoint.Y*sz.Y)
 end
 local press,target,startPos,startAbs,dragging,token=nil,nil,nil,nil,false,0
 local function lift(f,on)
  local st=f:FindFirstChildOfClass("UIStroke")
  if not st then st=Instance.new("UIStroke"); st.Name="DragEdge"; st.Thickness=2; st.Transparency=1; st.Parent=f end
  if on then st:SetAttribute("C",st.Color); st:SetAttribute("T",st.Transparency); st.Color=Color3.new(1,1,1); st.Transparency=0
  else if st:GetAttribute("C") then st.Color=st:GetAttribute("C"); st.Transparency=st:GetAttribute("T") end end
 end
 local function finish() if dragging and target then lift(target,false); target:SetAttribute("Dragged",true) end; press=nil; target=nil; dragging=false; token+=1 end
 UIS.InputBegan:Connect(function(io)
  if press or (io.UserInputType~=Enum.UserInputType.MouseButton1 and io.UserInputType~=Enum.UserInputType.Touch) then return end
  local p=Vector2.new(io.Position.X,io.Position.Y)
  local best
  for _,f in list do
   if f.Parent and shown(f) and inside(f,p) and (not best or f.ZIndex>best.ZIndex) then best=f end
  end
  if not best or onButton(best,p) then return end
  press=io; target=best; startPos=p; startAbs=best.AbsolutePosition; dragging=false
  token+=1; local mine=token
  task.delay(HOLD,function() if token==mine and press then dragging=true; lift(target,true) end end)
 end)
 UIS.InputChanged:Connect(function(io)
  if not press then return end
  local same=io==press or (press.UserInputType==Enum.UserInputType.MouseButton1 and io.UserInputType==Enum.UserInputType.MouseMovement)
  if not same then return end
  local d=Vector2.new(io.Position.X,io.Position.Y)-startPos
  if not dragging then if d.Magnitude>SLOP then finish() end; return end -- moved too soon: a swipe, not a hold
  place(target,startAbs+d)
 end)
 UIS.InputEnded:Connect(function(io)
  if press and (io==press or (press.UserInputType==Enum.UserInputType.MouseButton1 and io.UserInputType==Enum.UserInputType.MouseButton1)) then finish() end
 end)
 for _,n in {"HowToPlay","Leaderboard","GuidedFight","Keybindings","Controls","Notice"} do
  local f=gui:FindFirstChild(n)
  if f then
   table.insert(list,f)
   if f:IsA("Frame") then f.Active=true end -- the panel takes the touch, so the camera doesn't turn under it
   if f.Parent:IsA("GuiBase2d") then f.Parent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() task.defer(place,f,f.AbsolutePosition) end) end
   f:GetPropertyChangedSignal("Visible"):Connect(function() if f.Visible then task.defer(place,f,f.AbsolutePosition) end end)
  end
 end
end)()
-- R66-ui7 screen layout (Peter: "better screen management for the guides and menu, the fight commentary overlaps the
-- guides"). Rules, checked 10 times a second:
--  * Left column, top down: the round line (fight commentary), then the guided-fight box, then the notice line.
--    Nothing in the column overlaps; a panel you dragged by hand keeps its spot.
--  * While a big panel is open (Lobby, Keybindings, How to Play, Leaderboard) the guided-fight box steps aside.
--  * Phones: one screen at a time. Opening How to Play, Leaderboard or the Lobby from MENU swaps the MENU tiles out;
--    closing it (GOT IT / X / WEAR) brings the tiles back. Tapping MENU shuts everything.
;(function()
 local touch=UIS.TouchEnabled
 local shell=panel.Parent
 local function vis(n) local f=gui:FindFirstChild(n); return f and f.Visible end
 local function showing(l) return l and l.Visible and (l.TextTransparency<0.9) end
 local held={} -- the guide box we hid, so we can bring it back
 local acc=0
 RunService.Heartbeat:Connect(function(dt)
  acc+=dt; if acc<0.1 then return end; acc=0
  local box=gui:FindFirstChild("GuidedFight"); local G=Sig.guide
  local bigPanel=vis("Lobby") or vis("Keybindings") or vis("HowToPlay") or vis("Leaderboard")
  if box and G then
   if G.active and bigPanel and box.Visible then box.Visible=false; held.box=true
   elseif held.box and (not G.active) then held.box=nil
   elseif held.box and not bigPanel then box.Visible=true; held.box=nil end
  end
  -- left column
  local y=touch and 6 or 8
  if showing(roundLabel) then roundLabel.Position=UDim2.fromOffset(12,y); y+=roundLabel.AbsoluteSize.Y+6 end
  if box and box.Visible and not box:GetAttribute("Dragged") then
   if touch then box.Position=UDim2.fromOffset(12,y) else box.Position=UDim2.new(0,12,0.4,0) end
   y=box.AbsolutePosition.Y-gui.AbsolutePosition.Y+box.AbsoluteSize.Y+6
  end
  if not notice:GetAttribute("Dragged") then
   local def=gui.AbsoluteSize.Y*(touch and 0.48 or 0.62)
   notice.Position=UDim2.fromOffset(12,math.max(def,y))
  end
  -- phones: one screen at a time
  if touch and shell:GetAttribute("Open") then
   local want=not (vis("HowToPlay") or vis("Leaderboard") or vis("Lobby"))
   if shell.Visible~=want then shell.Visible=want end
  end
 end)
end)()
-- R66-ui phone performance (knowledge/HeroWars/LIVE_CHECK_2026-10-12.md, items 3 and 4).
-- Own function: the main chunk is at Luau's 200-local limit.
;(function()
 local Lighting=game:GetService("Lighting")
 -- 1. Effects from fights far away aren't drawn. Only pure one-off bursts are skipped; effects that change how a
 -- fighter looks for a while (Shield, Parry, Vanish, Armor, Glitch, Snare, casts, Solar Absorb, Cancel) always run.
 local BURST={Pulse=true,Super=true,Interrupted=true,ShadowStep=true,Teleport=true,DoorSlam=true,HolyRing=true,
  ShieldThrow=true,Riposte=true,WallSplat=true,Shockwave=true,Drain=true,Heal=true,Shade=true,Absorb=true,
  ShieldBreak=true,Zap=true,CircleBurn=true,Quake=true,SolarFlare=true,TitanDropLand=true,PounceLand=true,Dash=true}
 local FAR=140 -- studs; a duel ring is well inside this, so your own fight and the one you WATCH always show
 Sig.fxFar=function(model,kind,pos)
  if not BURST[kind] then return false end
  if typeof(model)=="Instance" and model==player.Character then return false end
  local at=typeof(pos)=="Vector3" and pos or nil
  if not at then
   local r=typeof(model)=="Instance" and model:FindFirstChild("HumanoidRootPart")
   if not r then return false end
   at=r.Position
  end
  local cam=workspace.CurrentCamera
  if cam and (cam.Focus.Position-at).Magnitude<FAR then return false end
  if cam and (cam.CFrame.Position-at).Magnitude<FAR then return false end
  local me=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if me and (me.Position-at).Magnitude<FAR then return false end
  return true
 end
 -- 2. Phone graphics profile: no depth of field, no sun rays, and lights don't cast shadows on touch screens.
 -- (Lighting stays Future: Technology can't be changed from a script, only in the place file.)
 if not UIS.TouchEnabled then return end
 local function tame(d)
  if d:IsA("DepthOfFieldEffect") or d:IsA("SunRaysEffect") then
   d.Enabled=false
   d:GetPropertyChangedSignal("Enabled"):Connect(function() if d.Enabled then d.Enabled=false end end)
  elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
   d.Shadows=false
   d:GetPropertyChangedSignal("Shadows"):Connect(function() if d.Shadows then d.Shadows=false end end)
  end
 end
 for _,d in Lighting:GetDescendants() do tame(d) end
 Lighting.DescendantAdded:Connect(tame)
 for _,d in workspace:GetDescendants() do if d:IsA("Light") then tame(d) end end
 workspace.DescendantAdded:Connect(function(d) if d:IsA("Light") then tame(d) end end)
 Lighting.ShadowSoftness=0 -- sharp shadows are cheaper to draw
 print("[HeroWars] phone graphics profile on: no DoF, no sun rays, no light shadows, far effects skipped")
end)()
