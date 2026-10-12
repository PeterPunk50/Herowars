# R66-ui round 2, Main: practice dummy per ring, votes for arena/bot, pause lock, saved wins + leaderboard.
import sys
p=sys.argv[1]; s=open(p,encoding='utf-8').read()
def rep(old,new,count=1):
    global s
    assert s.count(old)==count,(old,s.count(old)); s=s.replace(old,new)

rep('validActions={Coach=true,','validActions={Vote=true,Leaderboard=true,Coach=true,')
# --- practice dummies through spawnFighter (isDummy=="practice", 5th arg = ring)
rep('local function spawnFighter(player,hero,isDummy,skinId)\n local gen\n if isDummy then dummyGen+=1; gen=dummyGen end',
    'local function spawnFighter(player,hero,isDummy,skinId,ring)\n local gen\n -- R66-ui: isDummy=="practice" is a still practice dummy beside duel ring `ring` (not the sparring bot).\n local practice=isDummy=="practice"; if practice then isDummy=false end\n if isDummy then dummyGen+=1; gen=dummyGen end')
rep(' local origin=isDummy and Vector3.new(0,4,spotZ("Dummy",-22)) or Vector3.new(SPAWN_X[hero] or 0,4,spotZ("Player",22))\n',
    ' local origin=isDummy and Vector3.new(0,4,spotZ("Dummy",-22)) or Vector3.new(SPAWN_X[hero] or 0,4,spotZ("Player",22))\n if practice then origin=D.practiceSpot(ring) end\n')
rep(' nextIndex+=1; s.index=nextIndex\n states[model]=s\n',
    ''' nextIndex+=1; s.index=nextIndex
 if practice then
  s.isPractice=true; s.practiceRing=ring; model:SetAttribute("Practice",true); model.Name="Practice dummy"
  -- Heals back to full after 6 s without being hit.
  local last=s.hum.Health
  s.hum.HealthChanged:Connect(function(h) if h<last then s.practiceHurtAt=os.clock() end; last=h end)
 end
 states[model]=s
''')
rep('''   elseif isDummy and states[model]==s then
    states[model]=nil; model:Destroy()
    local ok,err=pcall(spawnFighter,nil,hero,true); if not ok then warn(err) end''',
'''   elseif practice and states[model]==s then
    states[model]=nil; model:Destroy()
    if D.rings()[ring] then local ok,err=pcall(spawnFighter,nil,hero,"practice",nil,ring); if not ok then warn(err) end end
   elseif isDummy and states[model]==s then
    states[model]=nil; model:Destroy()
    local ok,err=pcall(spawnFighter,nil,hero,true); if not ok then warn(err) end''')
# D is created after spawnFighter in the file but before any spawn runs; spawnFighter reads it as an upvalue.
rep('local function spawnFighter(player,hero,isDummy,skinId,ring)','local D\nlocal function spawnFighter(player,hero,isDummy,skinId,ring)')
rep('local D={list={},of={},queue={},challenges={},nextId=0}','D={list={},of={},queue={},challenges={},nextId=0}')
# Practice spot: 20 studs past the far end of ring i's line (the fighters stand at 12), on the floor.
rep('function D.freeRing()','''function D.practiceSpot(i)
 local r=D.rings()[i] or D.rings()[1]
 return r[3]=="z" and Vector3.new(r[1],4,r[2]+22) or Vector3.new(r[1]+22,4,r[2])
end
function D.freeRing()''')
# Arena change: practice dummies go to their ring's spot on the new map (or go away if it has fewer rings).
rep('''  for key,st in states do
   if typeof(key)=="Instance" and key:IsA("Model") and alive(st) then
    i+=1''','''  for key,st in states do
   if typeof(key)=="Instance" and key:IsA("Model") and st.isPractice then
    if D.rings()[st.practiceRing] then
     local o=D.practiceSpot(st.practiceRing); placeAt(st,CFrame.lookAt(o,Vector3.new(0,4,spotZ("Round",0))))
    else states[key]=nil; key:Destroy() end
   elseif typeof(key)=="Instance" and key:IsA("Model") and alive(st) then
    i+=1''')
# --- Coach (guided fight steps 6-7) uses the nearest free bot or practice dummy, so several players can do it at once.
rep('''  if (data~="Swing" and data~="Cast") or D.of.Bot or inDuel(player) or not alive(s) or not alive(dummy) then return end
  if now-(gate.coachAt or -10)<2.5 then return end
  local delta=s.root.Position-dummy.root.Position
  if delta.Magnitude>22 then notify(player,"Walk up to the bot first."); return end''',
'''  if (data~="Swing" and data~="Cast") or inDuel(player) or not alive(s) then return end
  if now-(gate.coachAt or -10)<2.5 then return end
  -- R66-ui: the nearest sparring partner, the bot (when it's in no match) or a practice dummy.
  local dummy,best=nil,22
  for key,st in states do
   if typeof(key)=="Instance" and (st.isPractice or (st.isDummy and not D.of.Bot)) and alive(st) then
    local dist=(s.root.Position-st.root.Position).Magnitude
    if dist<=best then dummy,best=st,dist end
   end
  end
  if not dummy then notify(player,"Walk up to the bot or a practice dummy first."); return end
  local delta=s.root.Position-dummy.root.Position''')
# --- votes: arena, bot level and bot hero
rep('''  if botSwapping then return end
  local heroes=Rules.Bot.Heroes
  botHero=heroes[(table.find(heroes,botHero) or 0)%#heroes+1]''','''  if botSwapping then return end
  if not data_vote then D.askVote(player,action); return end
  local heroes=Rules.Bot.Heroes
  botHero=heroes[(table.find(heroes,botHero) or 0)%#heroes+1]''')
rep('''  if #D.list>0 then notify(player,"Change the arena when no duels are running."); return end
  local order=Rules.Arenas.Order''','''  if #D.list>0 then notify(player,"Change the arena when no duels are running."); return end
  if not data_vote then D.askVote(player,action); return end
  local order=Rules.Arenas.Order''')
rep(''' if action=="Bot" then
  local order=Rules.Bot.Order''',''' if action=="Bot" then
  if not data_vote then D.askVote(player,action); return end
  local order=Rules.Bot.Order''')
# Pause: only when nobody else is in the server (it freezes everyone).
rep('''  if #D.list>1 and not paused then notify(player,"Pause is off while other duels are running."); return end''',
'''  if #D.list>1 and not paused then notify(player,"Pause is off while other duels are running."); return end
  -- R66-ui: pausing freezes the whole server, so it only works when the two of you are the only players.
  if not paused then for _,p in Players:GetPlayers() do if not (D.of[p] and D.of[p]==D.of[player]) then notify(player,"Pause is off while other players are in the server."); return end end end''')
# The handler gets a flag telling it a vote already passed (D.applyVote calls it again).
rep('remote.OnServerEvent:Connect(function(player,action,data,seq)\n',
'''D.handlers={}
local function onServerEvent(player,action,data,seq,data_vote)
''')
# find the end of the connected function: it is the line "end)" right before the next top-level statement after it.
i=s.index('local function onServerEvent(player,action,data,seq,data_vote)')
j=s.index('\nend)\n',i)
s=s[:j]+'\nend\nremote.OnServerEvent:Connect(function(player,action,data,seq) onServerEvent(player,action,data,seq,false) end)\nD.onServerEvent=onServerEvent\n'+s[j+len('\nend)\n'):]
# Votes and the Vote/Leaderboard actions handled first inside the handler.
rep(''' if gate.tokens<1 then if seq and states[player] then ack(states[player],seq,false) end; return end; gate.tokens-=1
''',''' if gate.tokens<1 then if seq and states[player] then ack(states[player],seq,false) end; return end; gate.tokens-=1
 if action=="Vote" then D.castVote(player,data==true); return end
 if action=="Leaderboard" then D.sendBoard(player); return end
''')
# --- match results
rep('''   banner=nameOf(winner).." wins the match!"; d.matchOver=true''','''   banner=nameOf(winner).." wins the match!"; d.matchOver=true
   D.recordMatch(d,winner)''')
# Leave: count the vote again without them.
rep(''' states[player]=nil; gates[player]=nil
end)''',''' states[player]=nil; gates[player]=nil
 if D.vote then D.vote.yes[player]=nil; D.vote.no[player]=nil; task.defer(D.tallyVote) end
 D.saveStats(player,true)
end)''')
rep('''local function onPlayer(player)
 remote:FireClient(player,"Arena",arenaName)''','''local function onPlayer(player)
 remote:FireClient(player,"Arena",arenaName)
 task.spawn(D.loadStats,player)''')
# Practice dummies spawn a little after the server starts, so the first player's own fighter comes first.
rep('''task.spawn(function()
 local ok,err=pcall(spawnFighter,nil,botHero,true); if not ok then warn("Training dummy: "..tostring(err)) end
end)''','''task.spawn(function()
 local ok,err=pcall(spawnFighter,nil,botHero,true); if not ok then warn("Training dummy: "..tostring(err)) end
end)
-- R66-ui: a still practice dummy beside every duel ring except the first (the sparring bot stands there).
task.delay(8,function()
 local heroes={"Bulwark","Tempest","Solarion","Wraithstep"}
 for i=2,#D.rings() do
  local ok,err=pcall(spawnFighter,nil,heroes[(i-2)%#heroes+1],"practice",nil,i); if not ok then warn("Practice dummy: "..tostring(err)) end
 end
end)
task.spawn(function()
 while true do
  task.wait(1)
  for key,st in states do
   if typeof(key)=="Instance" and st.isPractice and alive(st) and os.clock()-(st.practiceHurtAt or 0)>6 and st.hum.Health<st.hum.MaxHealth then
    st.hum.Health=st.hum.MaxHealth
   end
  end
 end
end)''')
# --- the vote + stats module, before the handler
rep('D.handlers={}\n',r'''D.handlers={}
-- R66-ui (Peter: "do a vote for the bots"): with more than one player in the server, changing the arena, the
-- bot's level or the bot's hero is a vote. YES from more than half the players passes it; 20 s, then it fails.
-- Alone in a server it happens straight away, as before.
function D.voteText(kind)
 if kind=="Arena" then
  local order=Rules.Arenas.Order; local nxt=order[(table.find(order,arenaName) or 0)%#order+1]
  return "Change the arena to "..((Rules.Arenas[nxt] and Rules.Arenas[nxt].Title) or nxt).."?"
 elseif kind=="Bot" then
  local order=Rules.Bot.Order; local nxt=order[(table.find(order,botLevel) or 0)%#order+1]
  return nxt=="Off" and "Turn the sparring bot off?" or ("Set the sparring bot to "..nxt.."?")
 else
  local heroes=Rules.Bot.Heroes; return "Switch the sparring bot to "..heroes[(table.find(heroes,botHero) or 0)%#heroes+1].."?"
 end
end
function D.needed() return math.floor(#Players:GetPlayers()/2)+1 end
function D.sendVote()
 local v=D.vote; if not v then return end
 local yes=0; for _ in v.yes do yes+=1 end
 remote:FireAllClients("Vote",{id=v.id,text=v.text,by=v.by.DisplayName,yes=yes,need=D.needed(),left=math.max(0,math.ceil(v.ends-os.clock()))})
end
function D.endVote(passed)
 local v=D.vote; if not v then return end
 D.vote=nil
 remote:FireAllClients("VoteEnd",{id=v.id,passed=passed})
 tellAll((passed and "Vote passed: " or "Vote failed: ")..v.text)
 if passed and v.by.Parent then D.onServerEvent(v.by,v.kind,nil,nil,true) end
end
function D.tallyVote()
 local v=D.vote; if not v then return end
 local yes,no=0,0
 for p in v.yes do if p.Parent then yes+=1 end end
 for p in v.no do if p.Parent then no+=1 end end
 local n=#Players:GetPlayers(); local need=D.needed()
 if yes>=need then D.endVote(true) elseif no>n-need then D.endVote(false) else D.sendVote() end
end
function D.askVote(player,kind)
 if #Players:GetPlayers()<=1 then D.onServerEvent(player,kind,nil,nil,true); return end
 if D.vote then notify(player,"A vote is already running. Vote on it at the top right."); return end
 D.voteId=(D.voteId or 0)+1
 D.vote={id=D.voteId,kind=kind,by=player,text=D.voteText(kind),yes={[player]=true},no={},ends=os.clock()+20}
 local id=D.voteId
 D.tallyVote()
 task.delay(20,function() if D.vote and D.vote.id==id then D.endVote(false) end end)
end
function D.castVote(player,yes)
 local v=D.vote; if not v then return end
 v.yes[player]=yes or nil; v.no[player]=(not yes) or nil
 D.tallyVote()
end
-- R66-ui: saved wins. Player-vs-player wins and losses plus bot wins, kept in DataStore HeroWarsStats
-- (key s_<UserId>); PvP wins also go to the OrderedDataStore HeroWarsWins for the all-time leaderboard.
D.stats={}
function D.statStores()
 if D.statStore==nil then
  local ok,a=pcall(function() return DataStoreService:GetDataStore("HeroWarsStats") end)
  local ok2,b=pcall(function() return DataStoreService:GetOrderedDataStore("HeroWarsWins") end)
  D.statStore=ok and a or false; D.winStore=ok2 and b or false
  if not ok then warn("HeroWars wins will not be saved: "..tostring(a)) end
 end
 return D.statStore,D.winStore
end
function D.loadStats(player)
 local st={wins=0,losses=0,botWins=0}
 D.stats[player]=st
 local folder=Instance.new("Folder"); folder.Name="leaderstats"
 local w=Instance.new("IntValue"); w.Name="Wins"; w.Parent=folder
 local l=Instance.new("IntValue"); l.Name="Losses"; l.Parent=folder
 folder.Parent=player
 local store=D.statStores()
 if store then
  local ok,saved=pcall(function() return store:GetAsync("s_"..player.UserId) end)
  if ok and type(saved)=="table" and D.stats[player]==st then
   st.wins=tonumber(saved.wins) or 0; st.losses=tonumber(saved.losses) or 0; st.botWins=tonumber(saved.botWins) or 0
  elseif not ok then warn("HeroWars wins not loaded: "..tostring(saved)) end
 end
 st.loaded=true
 w.Value=st.wins; l.Value=st.losses
end
function D.saveStats(player,leaving)
 local st=D.stats[player]; if not st then return end
 if leaving then D.stats[player]=nil end
 if not st.loaded or not st.dirty then return end
 st.dirty=false
 local store,wins=D.statStores()
 local uid=player.UserId
 task.spawn(function()
  if store then
   local ok,err=pcall(function() store:SetAsync("s_"..uid,{wins=st.wins,losses=st.losses,botWins=st.botWins}) end)
   if not ok then warn("HeroWars wins not saved: "..tostring(err)) end
  end
  if wins and uid>0 then pcall(function() wins:SetAsync(tostring(uid),st.wins) end) end
 end)
end
function D.recordMatch(d,winner)
 local a,b=d.fighters[1],d.fighters[2]; local loser=winner==a and b or a
 local function bump(k,field)
  if k=="Bot" then return end
  local st=D.stats[k]; if not st then return end
  st[field]+=1; st.dirty=true
  local ls=k:FindFirstChild("leaderstats")
  if ls and field~="botWins" then local v=ls:FindFirstChild(field=="wins" and "Wins" or "Losses"); if v then v.Value=st[field] end end
  D.saveStats(k)
 end
 if d.bot then bump(winner,"botWins") else bump(winner,"wins"); bump(loser,"losses") end
end
-- Leaderboard: this server's players and the all-time top 10 (refreshed at most once a minute).
D.names={}
function D.sendBoard(player)
 local here={}
 for _,p in Players:GetPlayers() do
  local st=D.stats[p]
  table.insert(here,{name=p.DisplayName,wins=st and st.wins or 0,losses=st and st.losses or 0,bot=st and st.botWins or 0,me=p==player})
 end
 table.sort(here,function(x,y) return x.wins>y.wins end)
 local _,wins=D.statStores()
 if wins and os.clock()-(D.topAt or -100)>60 then
  D.topAt=os.clock()
  local ok,page=pcall(function() return wins:GetSortedAsync(false,10):GetCurrentPage() end)
  if ok then
   local top={}
   for _,e in page do
    local id=tonumber(e.key)
    local name=id and D.names[id]
    if id and not name then
     local ok2,n=pcall(function() return Players:GetNameFromUserIdAsync(id) end)
     name=ok2 and n or ("Player "..e.key); D.names[id]=name
    end
    table.insert(top,{name=name or e.key,wins=e.value})
   end
   D.top=top
  end
 end
 remote:FireClient(player,"Board",{here=here,top=D.top or {}})
end
''')
# Autosave every 2 minutes for anyone with unsaved results.
s=s.rstrip('\n')+'\ntask.spawn(function() while true do task.wait(120); for p in D.stats do D.saveStats(p) end end end)\ngame:BindToClose(function() for p in D.stats do D.saveStats(p) end; task.wait(2) end)\n'
open(p,'w',encoding='utf-8').write(s)
print('ok')
