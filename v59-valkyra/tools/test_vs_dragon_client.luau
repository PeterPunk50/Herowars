-- V59 Play test (Client): summon Vyrath (the HUD's B), then aim at it and use Valkyra's moves; returns the boss HP after each.
local Combat=game.ReplicatedStorage.HeroWars.Combat; local RunS=game:GetService("RunService"); local cam=workspace.CurrentCamera
local me=game.Players.LocalPlayer.Character
Combat:FireServer("Boss","toggle")
local d; local t0=os.clock()
repeat task.wait(0.3); for _,m in workspace:GetDescendants() do if m:IsA("Model") and m.Name=="Vyrath" and m:GetAttribute("State")~=nil then d=m end end until d or os.clock()-t0>10
if not d then return "no dragon" end
local function aimAt() local r=me.HumanoidRootPart; local p=d:GetPivot().Position+Vector3.new(0,6,0); cam.CFrame=CFrame.lookAt(r.Position+Vector3.new(0,2,0)-(p-r.Position).Unit*8,p) end
RunS:BindToRenderStep("V59DragonAim",Enum.RenderPriority.Last.Value+10,aimAt)
local out={"summoned, HP "..tostring(d:GetAttribute("HP"))}
-- wait until it is within javelin range
t0=os.clock(); repeat task.wait(0.2) until (d:GetPivot().Position-me.HumanoidRootPart.Position).Magnitude<34 or os.clock()-t0>15
for _,a in {"Skill1","Skill2","Skill3","Heavy","Light"} do
 local before=d:GetAttribute("HP"); Combat:FireServer(a); task.wait(2.4)
 table.insert(out,string.format("%s: HP %s -> %s (dist %.0f, state %s)",a,tostring(before),tostring(d:GetAttribute("HP")),(d:GetPivot().Position-me.HumanoidRootPart.Position).Magnitude,tostring(d:GetAttribute("State"))))
end
RunS:UnbindFromRenderStep("V59DragonAim")
local hum=me:FindFirstChildOfClass("Humanoid")
table.insert(out,"Valkyra health "..tostring(hum.Health).."/"..tostring(hum.MaxHealth))
Combat:FireServer("Boss","toggle")
return table.concat(out,"\n")
