"""V59 Play test: move a practice dummy (attribute Practice) to <distance> studs in front of the player's hero (server),
aim at it and fire one action (client), then read the dummy's health (server).
usage: python3 -I hit_test.py <place name> <action> <distance> [repeats]"""
import sys, os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
sys.argv, args = sys.argv[:1], sys.argv[1:]
import studio_mcp as sm
place, action, dist = args[0], args[1], float(args[2]); reps = int(args[3]) if len(args) > 3 else 1
c = sm.Client(); sid = c.pick(place)
def run(code, dm): return sm.text_of(c.tool('execute_luau', {'code': code, 'studio_id': sid, 'datamodel_type': dm}))
FIND = '''local me=game.Players:GetPlayers()[1].Character
local dummy
for _,m in workspace:GetDescendants() do if m:IsA("Model") and m:GetAttribute("Practice") and m:FindFirstChildOfClass("Humanoid") and m:FindFirstChildOfClass("Humanoid").Health>0 then dummy=m; break end end
if not dummy then return "no practice dummy" end
local h=dummy:FindFirstChildOfClass("Humanoid")
'''
try:
    for r in range(reps):
        print('place:', run(FIND + '''h.Health=h.MaxHealth
local r=me.HumanoidRootPart; local at=r.Position+Vector3.new(r.CFrame.LookVector.X,0,r.CFrame.LookVector.Z).Unit*%s
dummy:PivotTo(CFrame.lookAt(at,Vector3.new(r.Position.X,at.Y,r.Position.Z)))
for _,p in dummy:GetDescendants() do if p:IsA("BasePart") then p.AssemblyLinearVelocity=Vector3.zero end end
task.wait(0.5)
return string.format("%%s (%%s) hp %%d at %%.1f studs", dummy.Name, tostring(dummy:GetAttribute("Hero")), h.Health, (dummy:GetPivot().Position-r.Position).Magnitude)''' % dist, 'Server'))
        print('client:', run(FIND + '''local Combat=game.ReplicatedStorage.HeroWars.Combat
local RunS=game:GetService("RunService"); local cam=workspace.CurrentCamera
-- the client aims along the camera, so hold the camera on the dummy while the move runs
RunS:BindToRenderStep("V59TestAim",Enum.RenderPriority.Last.Value+10,function()
 local r=me:FindFirstChild("HumanoidRootPart"); local t=dummy:FindFirstChild("HumanoidRootPart")
 if r and t then cam.CFrame=CFrame.lookAt(r.Position+Vector3.new(0,1.5,0)-(t.Position-r.Position).Unit*8,t.Position) end
end)
task.wait(0.3)
Combat:FireServer("%s")
task.wait(2.2)
RunS:UnbindFromRenderStep("V59TestAim")
return string.format("fired %s; now %%.1f studs apart", (dummy.HumanoidRootPart.Position-me.HumanoidRootPart.Position).Magnitude)''' % (action, action), 'Client'))
        print('after:', run(FIND + 'return string.format("dummy hp %d / %d, airborne %s", h.Health, h.MaxHealth, tostring(h.FloorMaterial==Enum.Material.Air))', 'Server'))
finally:
    c.close()
