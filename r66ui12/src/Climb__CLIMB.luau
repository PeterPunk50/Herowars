-- R66-ui10 climbing (ReplicatedStorage.HeroWars.Climb). Peter, 2026-10-12: "make sure Bulwark's jump is
-- increased so he can get up the steps; Wraith has spider climb, it comes up but he doesn't have to press the
-- button; Bulwark climbs up if he is short in his jump; the pyramid walls are high and give flyers too much
-- advantage". Settings are in Rules.Climb (and Rules.Characters.<hero>.JumpPower).
--
-- Climb.step runs once a frame for a fighter that is walking (not flying, stunned or attacking):
--   Wall   (Wraithstep) walking into a wall climbs straight up it at Speed studs/s. No button. At the top he
--          pulls himself onto the ledge. Let go of the direction and he drops.
--   Mantle (Bulwark, and Wraithstep at a wall's top) in the air and pushing at a wall whose top is no more than
--          Mantle studs above the feet: he pulls up onto the ledge.
--   autoJump (server bots only) jumps when a wall he can get over is in the way.
-- The client runs it for your own fighter; the server runs it for the sparring bot.
local Climb = {}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true -- effects and see-through decoration don't count as walls

local function filterFor(model)
 local list = {model}
 local fighters = workspace:FindFirstChild("Fighters")
 if fighters then table.insert(list, fighters) end
 for _, m in workspace:GetChildren() do
  if m ~= model and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then table.insert(list, m) end
 end
 params.FilterDescendantsInstances = list
end

local function standHeight(hum, root) return hum.HipHeight + root.Size.Y / 2 end

-- The wall straight ahead (along dir), if any: returns the hit.
local function wallAhead(root, dir, height, reach)
 local origin = Vector3.new(root.Position.X, height, root.Position.Z)
 local hit = workspace:Raycast(origin, dir * reach, params)
 -- The arena's outer walls (Boundary) can't be climbed.
 if hit and math.abs(hit.Normal.Y) < 0.5 and hit.Instance.Name ~= "Boundary" then return hit end
 return nil
end

-- A ledge on top of the wall hit: its height, if the top is between lo and hi.
local function ledgeTop(hit, dir, lo, hi)
 local over = hit.Position + dir * 1.4
 local origin = Vector3.new(over.X, hi + 0.5, over.Z)
 local down = workspace:Raycast(origin, Vector3.new(0, -(hi - lo + 0.5), 0), params)
 if down and down.Normal.Y > 0.7 and down.Position.Y > lo then return down.Position.Y, over end
 return nil
end

-- Is there room to stand on the ledge (nothing solid where the body would be)?
local function roomAt(spot, tall)
 local up = workspace:Raycast(spot + Vector3.new(0, 0.2, 0), Vector3.new(0, tall, 0), params)
 return up == nil
end

-- One frame. cfg = Rules.Climb[hero] (nil = this hero doesn't climb); moveDir = the walk direction (world).
-- opts.autoJump = jump at a wall that the jump plus Mantle can get over (bots). Returns "climb", "mantle",
-- "jump" or nil.
function Climb.step(cfg, model, root, hum, moveDir, opts)
 if not cfg or not root or not hum or hum.Health <= 0 then return nil end
 local flat = Vector3.new(moveDir.X, 0, moveDir.Z)
 if flat.Magnitude < 0.1 then
  if model:GetAttribute("Climbing") then model:SetAttribute("Climbing", nil) end
  return nil
 end
 local dir = flat.Unit
 filterFor(model)
 local stand = standHeight(hum, root)
 local feet = root.Position.Y - stand
 local reach = root.Size.X / 2 + 1.6
 local airborne = hum.FloorMaterial == Enum.Material.Air
 local now = os.clock()
 if now < (model:GetAttribute("ClimbHold") or 0) then return nil end
 -- Pull up onto a ledge (mantle): in the air, at a wall whose top is close above the feet.
 local mantle = cfg.Mantle or 0
 if mantle > 0 and (airborne or cfg.Wall) then
  local hit = wallAhead(root, dir, feet + 0.6, reach) or wallAhead(root, dir, root.Position.Y, reach)
  if hit then
   local top, over = ledgeTop(hit, dir, feet + 0.4, feet + mantle)
   if top and (airborne or top - feet > 2) then
    local spot = Vector3.new(over.X, top, over.Z)
    if roomAt(spot, stand * 2) then
     root.CFrame = CFrame.new(spot + Vector3.new(0, stand + 0.05, 0)) * root.CFrame.Rotation
     root.AssemblyLinearVelocity = Vector3.new(dir.X * 6, 0, dir.Z * 6)
     model:SetAttribute("ClimbHold", now + 0.25)
     model:SetAttribute("Climbing", nil)
     return "mantle"
    end
   end
  end
 end
 -- Spider climb: walking into a wall goes up it.
 if cfg.Wall then
  -- Chest height on the ground (so a stair step doesn't count), chest or feet in the air.
  local hit = wallAhead(root, dir, root.Position.Y, reach) or (airborne and wallAhead(root, dir, feet + 0.6, reach))
  if hit and dir:Dot(-hit.Normal) > 0.5 then
   local into = -Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
   root.AssemblyLinearVelocity = into * 2 + Vector3.new(0, cfg.Speed or 14, 0)
   if not model:GetAttribute("Climbing") then model:SetAttribute("Climbing", true) end
   return "climb"
  end
 end
 if model:GetAttribute("Climbing") then model:SetAttribute("Climbing", nil) end
 -- Bots: jump at a wall they can get over (jump height + Mantle).
 if opts and opts.autoJump and not airborne then
  local hit = wallAhead(root, dir, feet + 0.6, reach + 0.6)
  if hit then
   local jumpHeight = (hum.JumpPower ^ 2) / (2 * workspace.Gravity)
   local top = ledgeTop(hit, dir, feet + 0.4, feet + jumpHeight + mantle)
   if top then hum.Jump = true; return "jump" end
  end
 end
 return nil
end

-- Server check for the anti-cheat: is this fighter on a wall it may be climbing (any side)?
function Climb.onWall(model, root)
 filterFor(model)
 for i = 0, 7 do
  local a = i * math.pi / 4
  local dir = Vector3.new(math.cos(a), 0, math.sin(a))
  local hit = workspace:Raycast(root.Position, dir * (root.Size.X / 2 + 2.5), params)
  if hit and hit.Instance.Name ~= "Boundary" then return true end
 end
 return false
end

return Climb
