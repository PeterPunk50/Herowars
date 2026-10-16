-- V59 Play (Client): average the left forearm's pose relative to the root over her idle loop and give the ShieldWeld C0
-- that puts the winged shield upright in front of the forearm, crest (mesh -X) facing her forward, wings level.
local me=game.Players.LocalPlayer.Character; local r=me.HumanoidRootPart; local arm=me.LeftLowerArm
task.wait(1)
local n=0; local sumP=Vector3.zero; local sumL,sumU=Vector3.zero,Vector3.zero
for i=1,60 do
 local rel=r.CFrame:ToObjectSpace(arm.CFrame)
 sumP+=rel.Position; sumL+=rel.LookVector; sumU+=rel.UpVector; n+=1
 game:GetService("RunService").RenderStepped:Wait()
end
local p=sumP/n; local look=(sumL/n).Unit; local up=(sumU/n).Unit
local right=up:Cross(-look).Unit; up=(-look):Cross(right).Unit
local armRel=CFrame.fromMatrix(p,right,up,-look)     -- the forearm in root space, averaged over the idle
-- wanted shield in root space: centre a little in front of and outside the forearm; rotation Ry(-90): mesh -X -> forward
local want=CFrame.new(p+Vector3.new(-0.08,0.05,-0.42))*CFrame.Angles(0,-math.pi/2,0)
local c0=armRel:ToObjectSpace(want)
local x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22=c0:GetComponents()
return string.format("forearm in root space %s; C0 = %.4f %.4f %.4f %.5f %.5f %.5f %.5f %.5f %.5f %.5f %.5f %.5f",tostring(p),x,y,z,r00,r01,r02,r10,r11,r12,r20,r21,r22)
