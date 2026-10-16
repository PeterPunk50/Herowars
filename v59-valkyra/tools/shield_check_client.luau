-- V59 Play test (Client): where the winged shield sits at rest and in guard, and which way its crest (mesh -X) faces.
local Combat=game.ReplicatedStorage.HeroWars.Combat
local me=game.Players.LocalPlayer.Character; local r=me.HumanoidRootPart; local torso=me:FindFirstChild("UpperTorso")
local sd=me:FindFirstChild("ShieldDisc",true)
local function report(tag)
 local cf=sd.CFrame; local crest=-cf.RightVector
 local rel=r.CFrame:PointToObjectSpace(cf.Position)
 return string.format("%s: crest faces fwd %.2f left %.2f up %.2f | centre right %.2f up %.2f back %.2f | wingspan axis up %.2f",
  tag, crest:Dot(r.CFrame.LookVector), crest:Dot(-r.CFrame.RightVector), crest.Y, rel.X, rel.Y, rel.Z, cf.UpVector.Y)
end
task.wait(0.5)
local out={report("rest")}
Combat:FireServer("Block",true); task.wait(0.8); table.insert(out,report("guard")); Combat:FireServer("Block",false); task.wait(0.8)
table.insert(out,report("after"))
return table.concat(out,"\n")
