-- V60 Edit-mode check: the shared modules compile and Dread Knight's data is wired. Run: studio_mcp.py luau check_rules_dk.luau V60_pre Edit
-- (modules are required as clones in a scratch folder next to the originals, so their script.Parent siblings resolve)
local HW = game.ReplicatedStorage.HeroWars
local out = {}
local tmp = Instance.new("Folder"); tmp.Name = "CheckScratch"
for _, c in HW:GetChildren() do if c:IsA("ModuleScript") then c:Clone().Parent = tmp end end
tmp.Parent = game.ServerStorage
for _, n in {"Rules", "PowerFX", "FlightMotion", "MocapData", "MeshCostumes", "ModernStyle", "SurfaceFX", "MotionData"} do
	local ok, err = pcall(require, tmp[n])
	table.insert(out, n .. (ok and " ok" or (" FAILED: " .. tostring(err))))
end
local R = require(HW.Rules:Clone())
local sk, id = R.skin("DreadKnight")
local C, D = R.Characters.DreadKnight, R.Defensives.DreadKnight
table.insert(out, ("DreadKnight: shown as %q hp %d speed %s flies %s skin %s rig %s defensive %s (%s, absorb %s)"):format(R.display("DreadKnight"), C.Health, tostring(C.Speed), tostring(C.Flies), id, tostring(sk.Rig), D.Name, D.Kind, tostring(D.Absorb)))
for _, a in {"Light", "Heavy", "Throw", "Skill1", "Skill2", "Skill3", "Interrupt", "Super", "Dash", "Flight"} do
	local name = R.moveName("DreadKnight", a, 1)
	local m = name and R.heroMove("DreadKnight", name)
	table.insert(out, ("  %-9s -> %-15s %s"):format(a, tostring(name), m and ("%s dmg %s startup %s range %s"):format(R.title("DreadKnight", name), tostring(m.Damage), tostring(m.Startup), tostring(m.Range)) or (R.actionAvailable("DreadKnight", a) and "available" or "removed")))
end
table.insert(out, "isPounce: Pounce " .. tostring(R.isPounce("Pounce")) .. ", ValkyrieDive " .. tostring(R.isPounce("ValkyrieDive")) .. ", Charge " .. tostring(R.isPounce("Charge")))
table.insert(out, ("Bulwark: shown as %q, default skin %s, order %s"):format(R.display("Bulwark"), R.Skins.Bulwark.Order[1], table.concat(R.Skins.Bulwark.Order, ",")))
table.insert(out, "Bot heroes: " .. table.concat(R.Bot.Heroes, ","))
local M = require(HW.MocapData:Clone())
local v, b = {}, {}
for k in M do if string.sub(k, 1, 12) == "dreadknight_" then table.insert(v, k) elseif string.sub(k, 1, 8) == "bulwark_" then table.insert(b, k) end end
table.sort(v); table.sort(b)
table.insert(out, "captures dreadknight: " .. table.concat(v, ","))
table.insert(out, "captures bulwark: " .. table.concat(b, ","))
local V = HW.Rigs:FindFirstChild("VarnT")
table.insert(out, "rig VarnT: " .. tostring(V ~= nil) .. ", greatsword " .. tostring(V and V:FindFirstChild("Greatsword") and V.Greatsword.Size.Y) .. ", fists " .. tostring(V and V:FindFirstChild("RightFist") ~= nil and V:FindFirstChild("LeftFist") ~= nil) .. ", left grip " .. tostring(V and V:FindFirstChild("LeftGripFrame") ~= nil))
tmp:Destroy()
return table.concat(out, "\n")
