"""loop_check.py <place-name-fragment>: in a running HeroWars Play session, make a hero run (default Valkyra; arg 2 picks another) and measure whether her run loop really plays:
TimePosition of the looping track over frames, and the left/right foot fore-aft positions (they must swing in antiphase).
Written 2026-10-14 after the ground-loop freeze (see memory herowars-ground-loop-freeze): a track with the right length can still be stuck on frame 0."""
import sys, json
sys.path.insert(0, __import__('os').path.dirname(__import__('os').path.abspath(__file__)))
import studio_mcp as s
name = sys.argv[1] if len(sys.argv) > 1 else 'HeroWars'
hero = sys.argv[2] if len(sys.argv) > 2 else 'Valkyra'
LUA = 'local HERO_NAME = "%s"\n' % hero + '''
local RS = game:GetService("ReplicatedStorage"); local RunS = game:GetService("RunService")
RS.HeroWars.Combat:FireServer("Select", HERO_NAME); task.wait(5)
game.Players.LocalPlayer.PlayerGui.HeroWarsHUD.Lobby.Visible = false
task.wait(1)
local ch = game.Players.LocalPlayer.Character; local hum = ch.Humanoid; local root = ch.HumanoidRootPart
local an = hum:FindFirstChildOfClass("Animator")
local function loopTrack()
  for _, t in an:GetPlayingAnimationTracks() do if t.Looped and t.Length > 0.5 and t.WeightCurrent > 0.5 then return t end end
end
local function measure(label, moving, secs)
  local conn
  if moving then RunS:BindToRenderStep("LoopCheckWalk", Enum.RenderPriority.Last.Value + 10, function() hum:Move(Vector3.new(0, 0, -1), false) end) end -- after the game's own input step
  task.wait(0.8)
  local tps, lz, rz, lens = {}, {}, {}, {}
  local t0 = os.clock()
  while os.clock() - t0 < secs do
    local tr = loopTrack()
    if tr then table.insert(tps, tr.TimePosition); lens[string.format("%.2f", tr.Length)] = true end
    local lf, rf = ch:FindFirstChild("LeftFoot"), ch:FindFirstChild("RightFoot")
    table.insert(lz, root.CFrame:PointToObjectSpace(lf.Position).Z); table.insert(rz, root.CFrame:PointToObjectSpace(rf.Position).Z)
    RunS.RenderStepped:Wait()
  end
  RunS:UnbindFromRenderStep("LoopCheckWalk")
  local sp = root.AssemblyLinearVelocity; local mn, mx = math.huge, -math.huge; local distinct = {}
  for _, v in tps do mn = math.min(mn, v); mx = math.max(mx, v); distinct[string.format("%.2f", v)] = true end
  local n = 0; for _ in distinct do n += 1 end
  local ml, mr = 0, 0; for i = 1, #lz do ml += lz[i]; mr += rz[i] end; ml /= #lz; mr /= #rz
  local cov, vl, vr, lo, hi = 0, 0, 0, math.huge, -math.huge
  for i = 1, #lz do local a, b = lz[i] - ml, rz[i] - mr; cov += a * b; vl += a * a; vr += b * b; lo = math.min(lo, lz[i]); hi = math.max(hi, lz[i]) end
  local lens_s = {}; for k in lens do table.insert(lens_s, k) end
  return string.format("%-8s frames=%d  loop len=%s  TimePosition %.2f..%.2f (%d distinct)  left foot swing %.2f studs  L/R correlation %.2f", label, #lz, table.concat(lens_s, ","), tps[1] and mn or -1, tps[1] and mx or -1, n, hi - lo, (vl > 0 and vr > 0) and cov / math.sqrt(vl * vr) or 0)
end
local out = {}
table.insert(out, measure("idle", false, 2.5))
table.insert(out, measure("running", true, 3.0))
task.wait(1.0)
table.insert(out, measure("idle2", false, 2.0))
return table.concat(out, "\\n")
'''
c = s.Client()
try:
    sid = c.pick(name)
    print(s.text_of(c.tool('execute_luau', {'code': LUA, 'studio_id': sid, 'datamodel_type': 'Client'}, timeout=240)))
finally: c.close()
