-- V59: the winged shield's rest fit on her left forearm, measured over her shield idle (measure_idle_arm_client.luau):
-- upright in front of the forearm, crest (mesh -X) facing her forward, wings level. Run in Valkyra_shield_import (Edit).
local kit = workspace:FindFirstChild("WingedShieldKit"); assert(kit, "WingedShieldKit not found")
local off = kit:FindFirstChild("ArmOffset"); assert(off, "ArmOffset not found")
off.Value = CFrame.new(-0.4249, 0.0166, -0.0669, 0.98293, 0.04404, -0.17861, 0.16737, 0.18874, 0.96766, 0.07633, -0.98104, 0.17814)
local x, y, z = off.Value:ToEulerAnglesXYZ()
return string.format("ArmOffset %s, turn %.0f %.0f %.0f deg", tostring(off.Value.Position), math.deg(x), math.deg(y), math.deg(z))
