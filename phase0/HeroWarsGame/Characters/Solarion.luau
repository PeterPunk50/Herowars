-- Solarion (the plan's "Solaris"): the HeroWars sun-powered flyer. Character files hold what is unique to a
-- hero: stats, abilities, which input fires what, hero-only damage rules and how it looks. The shared
-- behaviour (cooldowns, Fury, the global cooldown, frame phases, damage order) is in HeroEngine/Core.
-- Phase 0 connects his melee combo and Solar Hammer; flight, Pounce, Solar Absorb and Solar Shield come in Phase 1.
local Rules = if script then require(script.Parent.Parent.LegacyRules) else require("../LegacyRules")
local AbilitySystem = if script
 then require(script.Parent.Parent.Parent.HeroEngine.Core.AbilitySystem)
 else require("../../HeroEngine/Core/AbilitySystem")

local HERO = "Solarion"
local function ability(name) return AbilitySystem.define(name, Rules.heroMove(HERO, name)) end

return {
 Name = HERO,
 Stats = {Health = Rules.Characters[HERO].Health, Speed = Rules.Characters[HERO].Speed, Flies = Rules.Characters[HERO].Flies},
 Resource = {Name = "Fury", Max = Rules.Fury.Max, Start = Rules.Fury.Start, PerDamageTaken = Rules.Fury.PerDamageTaken},
 Abilities = {
  Light1 = ability("Light1"), -- Sun Jab
  Light2 = ability("Light2"), -- Flare Cross
  Light3 = ability("Light3"), -- Corona Kick
  Heavy = ability("Heavy"),   -- Solar Hammer: three photon pulses down a 30-stud line
 },
 -- Action bar keys in the live game: 1 = combo, 2 = Solar Hammer.
 Inputs = {
  Light = {Chain = {"Light1", "Light2", "Light3"}, Window = 45},
  Heavy = "Heavy",
 },
 Visuals = {Skin = "Trooper", PowerStyle = "Plasma", Accent = Rules.Characters[HERO].Accent},
}
