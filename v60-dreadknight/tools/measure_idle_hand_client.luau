-- V60 Play (Client, as Dread Knight): average the right hand's pose relative to the root over his idle and give the
-- GreatswordWeld C0 that holds the 4.2-stud sword by its grip: blade pointing forward and up, flat facing sideways.
local me=game.Players.LocalPlayer.Character; local r=me.HumanoidRootPart; local hand=me.RightHand
task.wait(1)
local n=0; local sumP=Vector3.zero; local sumL,sumU=Vector3.zero,Vector3.zero
for i=1,60 do
 local rel=r.CFrame:ToObjectSpace(hand.CFrame); sumP+=rel.Position; sumL+=rel.LookVector; sumU+=rel.UpVector; n+=1
 game:GetService("RunService").RenderStepped:Wait()
end
local p=sumP/n; local look=(sumL/n).Unit; local up=(sumU/n).Unit
local right=up:Cross(-look).Unit; up=(-look):Cross(right).Unit
local handRel=CFrame.fromMatrix(p,right,up,-look)
local L=4.2; local dir=Vector3.new(0.1,0.45,-1).Unit                 -- blade: forward, up about 24 degrees, a touch outward
local x=(Vector3.xAxis-dir*Vector3.xAxis:Dot(dir)).Unit              -- the blade's flat faces sideways
local z=x:Cross(dir).Unit
local centre=p+dir*(0.33*L)                                          -- the grip (17% up from the pommel end) sits in the hand
local want=CFrame.fromMatrix(centre,x,dir,z)
local c0=handRel:ToObjectSpace(want)
local comps={c0:GetComponents()}; for i,v in comps do comps[i]=string.format("%.5f",v) end
return "right hand in root space "..tostring(p).."; C0 = "..table.concat(comps," ")
