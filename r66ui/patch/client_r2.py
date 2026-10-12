# R66-ui round 2, client: How to Play card off-centre, no loading screen, faster phone preload,
# vote bar, leaderboard, guided fight with the nearest bot or practice dummy.
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
def rep(old,new,count=1):
    global s
    assert s.count(old)==count,(old[:80],s.count(old)); s=s.replace(old,new)

# 1. How to Play card: top-left, below the Roblox buttons, never over the centre or the bottom buttons.
rep('''local card=Instance.new("Frame"); card.Name="HowToPlay"; card.AnchorPoint=Vector2.new(0.5,0.5); card.Position=UDim2.fromScale(0.5,0.5)''',
'''local card=Instance.new("Frame"); card.Name="HowToPlay"; card.AnchorPoint=Vector2.new(0,0); card.Position=UDim2.fromOffset(12,touch and 4 or 8)''')
rep('''  fit.Scale=math.min(1,(v.X-24)/W,(v.Y-16)/H)''',
'''  -- R66-ui (Peter: "make it fit, don't take up the centre of the screen"): at most 45% of the screen wide, and
  -- clear of the bottom row of buttons (100 px on phones). gui sits under Roblox's top bar, so y 4 is just below it.
  fit.Scale=math.min(1,(v.X*0.45)/W,(v.Y-(touch and 100 or 90))/H)''')
rep('''   row("MENU","Top right: QUEUE or CHALLENGE a player, How to play, Guided fight.",6)''',
    '''   row("MENU","Top right: Lobby (pick your hero), QUEUE or CHALLENGE a player, Leaderboard.",6)''')
rep('''    "Top right: QUEUE or CHALLENGE a player, How to play, Guided fight. "..key("Keybinds").." changes keys.",6)''',
    '''    "Top right: Lobby (pick your hero), QUEUE or CHALLENGE, Leaderboard. "..key("Keybinds").." changes keys.",6)''')
# 2. No loading screen: you spawn straight in; the lobby is in MENU.
i=s.index(''' -- R35 (Peter: "a welcome to HeroWars, give the toons time to load, 5 second delay"): a welcome screen''')
j=s.index('''  task.wait(0.4); w:Destroy()
  open()
 end)
''',i)+len('''  task.wait(0.4); w:Destroy()
  open()
 end)
''')
s=s[:i]+''' -- R66-ui (Peter: "remove the loading screen at the startup, a fast startup for both"): no welcome screen and no
 -- lobby on join; you spawn straight into the arena and skins keep downloading in the background. Pick a hero
 -- from MENU > Lobby. (The R35-R47 welcome screen waited for 10% of the skins, 5 s at least.)
'''+s[j:]
# 3. Preload order: fighters already in the arena first, then every hero's default look, then the rest;
#    on phones the rest waits 20 s so the first fight's downloads come first.
rep(''' local queue={}
 for _,m in folder:GetChildren() do table.insert(queue,m) end
 folder.ChildAdded:Connect(function(m) table.insert(queue,m) end)
 while true do
  local m=table.remove(queue,1)''',''' local queue={}
 local list={}; for _,m in workspace:GetChildren() do if m:IsA("Model") and m:GetAttribute("Hero") then table.insert(list,m) end end
 pcall(function() CP:PreloadAsync(list) end) -- R66-ui: the fighters you can see first
 local function isDefault(m) local h,id=string.match(m.Name,"^(%w+)|(.+)$"); local sk=h and Rules.Skins[h]; return sk and sk.Order[1]==id end
 local function add(m) if isDefault(m) then table.insert(queue,1,m) else table.insert(queue,m) end end
 for _,m in folder:GetChildren() do add(m) end
 folder.ChildAdded:Connect(add)
 local t0=os.clock()
 while true do
  if game:GetService("UserInputService").TouchEnabled and os.clock()-t0<20 and queue[1] and not isDefault(queue[1]) then task.wait(0.5); continue end
  local m=table.remove(queue,1)''')
# 4. Guided fight: the nearest bot or practice dummy (several new players can practise at once).
rep('''  for _,m in workspace:GetChildren() do
   if m:IsA("Model") and m~=player.Character and m:GetAttribute("Hero") and not Players:GetPlayerFromCharacter(m) then
    local h=m:FindFirstChildOfClass("Humanoid"); if h and h.Health>0 then return m,h end
   end
  end
 end''','''  local best,bh,bd=nil,nil,math.huge; local r=myRoot()
  for _,m in workspace:GetChildren() do
   if m:IsA("Model") and m~=player.Character and m:GetAttribute("Hero") and not Players:GetPlayerFromCharacter(m) and not m:GetAttribute("DuelId") then
    local h=m:FindFirstChildOfClass("Humanoid"); local mr=m:FindFirstChild("HumanoidRootPart")
    local d=(r and mr) and (mr.Position-r.Position).Magnitude or 1e6
    if h and h.Health>0 and d<bd then best,bh,bd=m,h,d end
   end
  end
  return best,bh
 end''')
rep('''STEPS[1]={text=function() return touch and "Walk up to the sparring bot (gold outline) with the left stick."
   or ("Walk up to the sparring bot (gold outline) with "''','''STEPS[1]={text=function() return touch and "Walk up to the gold-outlined dummy with the left stick."
   or ("Walk up to the gold-outlined dummy with "''')
# 5. Leaderboard button in MENU (a tile on phones).
rep(''' "QueueButton","ChallengeButton","WatchButton","SkinButton","BotButton","BotHeroButton","ArenaButton","ReloadButton"}''',
    ''' "QueueButton","ChallengeButton","WatchButton","LeaderboardButton","SkinButton","BotButton","BotHeroButton","ArenaButton","ReloadButton"}''')
anchor='-- R64 (Peter: "classy, fade, modern style"): menu, challenge and lobby buttons get rounded glass styling:'
rep(anchor,r''';(function()
 -- R66-ui: a vote bar (arena / bot changes need YES from more than half the server) and a leaderboard.
 local touch=UIS.TouchEnabled
 local GOLD=Color3.fromRGB(255,205,80)
 local function corner(o,r) local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 10); c.Parent=o end
 ---------------------------------------------------------------- vote bar (top right, under MENU's row)
 local bar=Instance.new("Frame"); bar.Name="VoteBar"; bar.AnchorPoint=Vector2.new(1,0)
 bar.Position=UDim2.new(1,-(touch and 146 or 162),0,60); bar.Size=UDim2.fromOffset(300,48)
 bar.BackgroundColor3=Color3.fromRGB(20,26,44); bar.BackgroundTransparency=0.1; bar.Visible=false; bar.ZIndex=30; bar.Parent=menuToggle.Parent
 corner(bar,10)
 do local st=Instance.new("UIStroke"); st.Color=GOLD; st.Transparency=0.4; st.Parent=bar end
 local txt=Instance.new("TextLabel"); txt.BackgroundTransparency=1; txt.Position=UDim2.fromOffset(8,2); txt.Size=UDim2.fromOffset(170,44)
 txt.Font=Enum.Font.GothamBold; txt.TextScaled=true; txt.TextWrapped=true; txt.TextColor3=Color3.new(1,1,1); txt.TextXAlignment=Enum.TextXAlignment.Left; txt.ZIndex=31; txt.Parent=bar
 do local c=Instance.new("UITextSizeConstraint"); c.MaxTextSize=13; c.MinTextSize=8; c.Parent=txt end
 local yes=button("VoteYes",bar,UDim2.fromOffset(182,8),UDim2.fromOffset(56,32),"YES",Color3.fromRGB(40,120,60)); yes.ZIndex=31; yes.TextSize=13
 local no=button("VoteNo",bar,UDim2.fromOffset(242,8),UDim2.fromOffset(50,32),"NO",Color3.fromRGB(120,45,45)); no.ZIndex=31; no.TextSize=13
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
 local lb=button("LeaderboardButton",panel,UDim2.new(),UDim2.fromOffset(260,38),"Leaderboard",Color3.fromRGB(150,110,30)); lb.LayoutOrder=2
 lb.Activated:Connect(function()
  if board.Visible then board.Visible=false; return end
  if touch then setMenuOpen(false) end
  local htp=gui:FindFirstChild("HowToPlay"); if htp then htp.Visible=false end
  refit(); board.Visible=true; body.Text="Loading…"; remote:FireServer("Leaderboard")
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
'''+anchor)
open(p,'w',encoding='utf-8').write(s)
print('ok')
