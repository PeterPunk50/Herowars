-- Wraithstep: the HeroWars shadow assassin. Phase 0 gives him his Shade Slash combo and Grave Scythe so he
-- can hit back in the two-client test; Grapple, Phase, Shadow Circle, Vanish and his regeneration come in
-- Phase 1. Hero-only damage rules go in DamageModifiers (his Shadow Circle x1.5 is the first candidate).
local Rules = if script then require(script.Parent.Parent.LegacyRules) else require("../LegacyRules")
local AbilitySystem = if script
 then require(script.Parent.Parent.Parent.HeroEngine.Core.AbilitySystem)
 else require("../../HeroEngine/Core/AbilitySystem")

local HERO = "Wraithstep"
local function ability(name) return AbilitySystem.define(name, Rules.heroMove(HERO, name)) end

return {
 Name = HERO,
 Stats = {Health = Rules.Characters[HERO].Health, Speed = Rules.Characters[HERO].Speed, Regen = Rules.Characters[HERO].Regen},
 Resource = {Name = "Fury", Max = Rules.Fury.Max, Start = Rules.Fury.Start, PerDamageTaken = Rules.Fury.PerDamageTaken},
 Abilities = {
  Light1 = ability("Light1"), -- Shade Slash
  Light2 = ability("Light2"), -- Night Claw
  Light3 = ability("Light3"), -- Reaper Kick
  Heavy = ability("Heavy"),   -- Grave Scythe
 },
 Inputs = {
  Light = {Chain = {"Light1", "Light2", "Light3"}, Window = 45},
  Heavy = "Heavy",
 },
 -- Example hook (off in Phase 0): return {{name = "ShadowCircle", scale = 1.5}} while he stands in his circle.
 DamageModifiers = nil,
 Visuals = {Skin = "Shinobi", PowerStyle = "Shadow", Accent = Rules.Characters[HERO].Accent},
}
