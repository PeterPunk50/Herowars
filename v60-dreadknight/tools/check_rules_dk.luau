-- V59 Edit-mode check: the shared modules compile and Valkyra's data is wired. Run: studio_mcp.py luau check_rules.luau V59_pre Edit
local HW = game.ReplicatedStorage.HeroWars
local out = {}
for _, n in {"Rules", "PowerFX", "FlightMotion", "MocapData", "MeshCostumes", "ModernStyle", "SurfaceFX", "MotionData"} do
	local ok, err = pcall(require, HW[n]:Clone())
	table.insert(out, n .. (ok and " ok" or (" FAILED: " .. tostring(err))))
end
local R = require(HW.Rules:Clone())
local sk, id = R.skin("DreadKnight")
table.insert(out, ("DreadKnight: hp %d flies %s skin %s rig %s defensive %s"):format(R.Characters.Valkyra.Health, tostring(R.Characters.Valkyra.Flies), id, tostring(sk.Rig), R.Defensives.Valkyra.Name))
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
table.insert(out, "rig ValkyraN: " .. tostring(HW.Rigs:FindFirstChild("VarnT") ~= nil) .. ", greatsword " .. tostring(HW.Rigs.VarnT:FindFirstChild("Greatsword", true) ~= nil))
return table.concat(out, "\n")
