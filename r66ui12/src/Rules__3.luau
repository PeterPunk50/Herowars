-- Pure rules: shared by the runtime and offline regression tests.
local Rules = {}
Rules.Hz = 60
-- About 250 ms input queue (WoW uses ~400 ms; fighting games use less).
Rules.BufferFrames = 15
-- Fresh block presses parry for this many ticks (wider than v9's 6 to allow for ping).
Rules.ParryFrames = 9
-- Hitting a fighter during their wind-up: extra hitstun and damage.
Rules.CounterStun = 1.5
Rules.CounterDamage = 1.2
-- Walking backwards while locked on a target is slower, like WoW backpedal.
Rules.BackpedalScale = 0.65
Rules.MaxAltitude = 25
-- Per-hero flight ceiling (v23): Solarion flies higher (Peter). Others use Rules.MaxAltitude.
-- v28 (Peter: "make the fly higher"): Solarion 60 (was 45), Tempest 50 (was 38).
Rules.FlightCeiling = {Solarion = 60, Tempest = 50}
function Rules.ceiling(hero) return Rules.FlightCeiling[hero] or Rules.MaxAltitude end
Rules.MaxRange = 40
-- v43: how far Tab looks for a target (the whole arena).
Rules.TabRange = 250
-- The third unblocked hit in a chain knocks the victim down (invulnerable until they stand),
-- and the attacker recovers this many ticks earlier, so a finished combo ends slightly in their favour.
Rules.ChainHits = 3
Rules.ChainWindow = 90
Rules.Knockdown = 36
Rules.KnockdownAdvantage = 10
-- Global cooldown shared by every move that costs Fury (WoW style).
Rules.GCD = 45
-- Fury: combat resource. Regenerates slowly, builds from landing hits and taking damage.
Rules.Fury = {Max = 100, Start = 50, Regen = 4, PerDamageTaken = 0.5}
-- Rounds: best of three, 99 second timer; on time-out the higher health % wins.
Rules.Round = {Seconds = 99, Countdown = 3, WinsNeeded = 2, Intermission = 4, Overtime = 20}
-- v27 overtime: if the timer runs out with both standing, nobody can fly for Overtime more seconds,
-- then the higher health % wins. Stops a flyer winning by hovering out of a ground hero's reach.
-- The chain window stays open until at least this many ticks after the victim's stun ends (v27),
-- so a long stun (Grapple) can't be waited out to reset the three-hit knockdown count.
Rules.ChainAfterStun = 30
-- v28 shadow pools: a Shrouded Wraithstep is near invisible (and can't be Tab-targeted) beyond Range studs.
Rules.Shroud = {Range = 20}
-- One successful ambush per hiding episode; impact must be strictly before expiry.
Rules.Sneak = {Window = 120, Multiplier = 1.25}
function Rules.updateSneak(state, hero, hidden, now)
 state=state or {hidden=false,ready=false}
 hidden=hero=="Wraithstep" and hidden==true
 if hidden and not state.hidden then
  state.ready=true; state.expires=nil
 elseif state.hidden and not hidden then
  state.expires=now+Rules.Sneak.Window
 end
 state.hidden=hidden
 if hero~="Wraithstep" or (not hidden and (not state.expires or now>=state.expires)) then state.ready=false end
 return state
end
function Rules.sneakDamage(state, hero, now, damage, result)
 if hero~="Wraithstep" or not state or not state.ready or damage<=0
  or (not state.hidden and (not state.expires or now>=state.expires))
  or (result~="Hit" and result~="Counter" and result~="Throw" and result~="GuardBreak") then return damage,0 end
 state.ready=false
 local boosted=math.floor(damage*Rules.Sneak.Multiplier+.5)
 return boosted,boosted-damage
end
-- v27 stun diminishing returns (WoW style): long stuns (Min ticks or more) on the same fighter within
-- Reset ticks of the last one last 100%, 50%, 25%, then they are immune (a normal ImmuneStun flinch).
Rules.StunDR = {Min = 60, Reset = 1080, Scale = {1, 0.5, 0.25}, ImmuneStun = 18}
-- count = long stuns already taken in this DR window. Returns the stun to apply and whether it was immune.
function Rules.drStun(stun, count)
 if stun < Rules.StunDR.Min then return stun, false end
 local k = Rules.StunDR.Scale[count + 1]
 if not k then return Rules.StunDR.ImmuneStun, true end
 return math.floor(stun * k + 0.5), false
end
-- Sparring bot levels. Think: ticks between decisions (random in range).
-- Block/Evade: chance to guard or dodge back when the player starts an attack.
-- Attack: chance to attack when in range; the rest is guarding briefly or backing off.
-- AntiAir: chance to use Skill 1 on a flying or jumping player.
Rules.Bot = {
 Order = {"Easy", "Normal", "Hard", "Off"},
 Default = "Easy",
 Easy = {Think = {30, 50}, Block = 0.25, Evade = 0.10, Attack = 0.35, AntiAir = 0.15, Dash = 0.03, Trinket = 0.2, Ranged = 0.15},
 Normal = {Think = {16, 28}, Block = 0.40, Evade = 0.15, Attack = 0.55, AntiAir = 0.35, Dash = 0.06, Trinket = 0.5, Ranged = 0.3},
 Hard = {Think = {8, 16}, Block = 0.50, Evade = 0.15, Attack = 0.70, AntiAir = 0.50, Dash = 0.10, Trinket = 0.8, Ranged = 0.45},
 -- v27: the bot can be any hero (bot hero button). Trinket: chance to use its defensive to break a
 -- long stun or a knockdown. Ranged: chance per decision to use a long-range Skill 1 (Beam, Lightning).
 Heroes = {"Wraithstep", "Solarion", "Tempest", "Bulwark"},
}
-- Skins (v15): the HeroWars Skin & Animation Kit's looks. Cosmetic only.
-- Palette = the kit's six colour zones (hex): Primary suit, Secondary lower arms/legs and gauntlets,
-- Metal plates and boots, Accent visor/badge/trim, Emissive neon cores and every ability effect, Dark hood/pack.
-- Appearance welds the kit's armour pieces (shoulder plates, gauntlets, boots, Solarion's core, visor and
-- thrusters, Wraithstep's hood, visor, grapple housing and backpack) and paints them from the palette.
-- Moves = what the skin does while that attack fires: Glow (outline flare), Tint (body colour),
-- Trail (hand/foot streaks), Aura (Fire/Sparkles/Smoke), Color (effect colour for that move only).
-- "Defensive" covers Solar Shield / Shadow Step. Skins never change hitboxes, damage or timing.
Rules.Zones = {"Primary", "Secondary", "Metal", "Accent", "Emissive", "Dark"}
-- Optional extra zones (v26): Hair and Cloth (capes, crests, plumes). A skin without them uses Metal / Secondary.
Rules.ExtraZones = {Hair = "Metal", Cloth = "Secondary"}
-- v34: bare skin (Bulwark's muscles). Skins without a Flesh colour use this tan.
Rules.DefaultFlesh = "C68A5C"
local function kit(name, primary, secondary, metal, accent, emissive, dark, moves, extra)
 local palette = {Primary = primary, Secondary = secondary, Metal = metal, Accent = accent, Emissive = emissive, Dark = dark}
 for zone, hex in extra or {} do palette[zone] = hex end
 return {Name = name, Palette = palette, Moves = moves}
end
Rules.Skins = {
 Solarion = {
  Order = {"Default", "Eclipse", "Celestial", "Inferno", "Obsidian", "Vanguard"},
  Default = kit("Default", "13233C", "50617B", "B9C6D8", "FFA924", "FFCF63", "090F1C",
   {Beam = {Glow = true}, Pounce = {Trail = true}}),
  Eclipse = kit("Eclipse", "101120", "3D3B50", "858198", "865BFF", "C09FFF", "08070E",
   {Beam = {Glow = true, Tint = {0.06,0.04,0.14}}, Heavy = {Glow = true}}),
  Celestial = kit("Celestial", "E4E9EF", "809BC3", "F8FAFF", "68B9FA", "B4E8FF", "253854",
   {Beam = {Aura = "Sparkles", Glow = true}, Defensive = {Aura = "Sparkles", Glow = true}}),
  Inferno = kit("Inferno", "421719", "8B292A", "9F9290", "FF5D20", "FFD04B", "1C0C0F",
   {Beam = {Aura = "Fire", Glow = true}, Pounce = {Trail = true, Aura = "Fire"}}),
  Obsidian = kit("Obsidian", "11141A", "252B30", "777D8A", "E6B84B", "FFEB9B", "05070A",
   {Pounce = {Trail = true}, Heavy = {Glow = true}}),

  -- v17 catalog gear: sci-fi chest armour, mech pauldrons, wing jetpack, samurai brow visor.
  Vanguard = kit("Vanguard", "13233C", "50617B", "B9C6D8", "FFA924", "FFCF63", "090F1C",
   {Beam = {Glow = true}, Pounce = {Trail = true, Aura = "Fire"}}),
 },
 Wraithstep = {
  Order = {"Default", "Phantom", "Crimson", "Arctic", "StealthOps", "Shadow"},
  Default = kit("Default", "11131D", "282C40", "666A80", "8C43ED", "CC9DFF", "080912",
   {Grapple = {Glow = true}, Uppercut = {Trail = true}}),
  Phantom = kit("Phantom", "182B43", "294C68", "708AA6", "32CBFF", "9CE8FF", "071726",
   {Grapple = {Glow = true}, Defensive = {Aura = "Sparkles"}}),
  Crimson = kit("Crimson", "241118", "4D1829", "8A626F", "F5496E", "FF97AB", "11070C",
   {Grapple = {Aura = "Smoke", Glow = true}, Throw = {Tint = {0.40,0.02,0.04}}, Defensive = {Aura = "Smoke"}}),
  Arctic = kit("Arctic", "D1DAE5", "869AB4", "F2F7FF", "4989DB", "B7E1FF", "2A3D59",
   {Uppercut = {Aura = "Sparkles", Trail = true}, Throw = {Tint = {0.60,0.85,1}}}),
  StealthOps = kit("StealthOps", "1A211C", "38483C", "697B70", "AECD49", "D8F7A4", "09120C",
   {Uppercut = {Trail = true}, Grapple = {Glow = true}}),

  -- v17 catalog gear: purple assassin hood, purple visor lens, cyber ninja mask, tactical backpack.
  Shadow = kit("Shadow", "11131D", "282C40", "666A80", "8C43ED", "CC9DFF", "080912",
   {Grapple = {Aura = "Smoke", Glow = true}, Defensive = {Aura = "Smoke"}}),
 },
 -- v26 Tempest: fitted storm suit with dark side panels, long gloves and thigh boots, a split cape (Cloth)
 -- and her own hair colour (Hair). Metal is the silver or gold of her circlet and trim.
 Tempest = {
  Order = {"Default", "Thunderhead", "Monsoon", "Sunstorm", "Blizzard", "StormQueen"},
  Default = kit("Default", "1B2235", "0F1320", "D8DEE8", "6FC8FF", "BDE8FF", "0B0D14",
   {Lightning = {Glow = true}, Gale = {Aura = "Sparkles"}}, {Hair = "F4F6FA", Cloth = "2B3A66"}),
  Thunderhead = kit("Thunderhead", "241B38", "15101F", "CFC6E6", "A06BFF", "D7C2FF", "0E0A16",
   {Lightning = {Glow = true, Aura = "Sparkles"}}, {Hair = "E9E2FF", Cloth = "3E2F5C"}),
  Monsoon = kit("Monsoon", "0F3533", "0A1F1E", "CFE7E3", "3FD6C4", "A6FFF3", "061716",
   {Gale = {Trail = true}, Lightning = {Glow = true}}, {Hair = "DDF5F1", Cloth = "1E5552"}),
  Sunstorm = kit("Sunstorm", "3A1E10", "22120A", "E9C77A", "FF9B2E", "FFD27A", "180C06",
   {Lightning = {Aura = "Fire", Glow = true}}, {Hair = "E8B04A", Cloth = "7A2E14"}),
  Blizzard = kit("Blizzard", "E3EAF3", "5E7898", "FFFFFF", "4C8DE0", "C9EBFF", "2B3E5C",
   {Gale = {Aura = "Sparkles", Trail = true}}, {Hair = "BFE4FF", Cloth = "8FA6C4"}),
  -- Black and gold with white hair and white-hot eyes; the only skin with the lightning crown.
  StormQueen = kit("StormQueen", "14141C", "0C0C12", "E6C36A", "F0D58A", "FFFFFF", "060608",
   {Lightning = {Glow = true, Aura = "Sparkles"}, Gale = {Trail = true}}, {Hair = "FFFFFF", Cloth = "101018"}),
 },
 -- v26 Bulwark: an ancient heavy infantryman. Silver muscle armour, bronze trim (Accent),
 -- leather straps and skirt (Dark), plume and cloak (Cloth).
 Bulwark = {
  Order = {"Default", "Gilded", "Blackiron", "CrimsonGuard", "Frost"},
  Default = kit("Default", "B9C0CA", "9AA2AE", "E1E6EC", "B8873B", "8FD3FF", "3A2A1E",
   {Slam = {Glow = true}, Charge = {Trail = true}}, {Cloth = "A3242B", Flesh = "C68A5C"}),
  Gilded = kit("Gilded", "C9CED6", "A4ABB6", "ECEFF3", "E2B13C", "FFE39A", "4A3622",
   {Slam = {Glow = true, Aura = "Sparkles"}}, {Cloth = "F2EDE0", Flesh = "D9A276"}),
  Blackiron = kit("Blackiron", "3A3F47", "2A2E35", "6E7580", "B0763A", "FFB27A", "1A120C",
   {Slam = {Aura = "Fire", Glow = true}}, {Cloth = "6A1414", Flesh = "7E5136"}),
  CrimsonGuard = kit("CrimsonGuard", "B5BCC6", "8E2A2E", "DDE2E8", "C79A45", "FF8A90", "2B1416",
   {Charge = {Trail = true, Glow = true}}, {Cloth = "8E1D24", Flesh = "B87A4C"}),
  Frost = kit("Frost", "C8D8E8", "90AACB", "F2F8FF", "7FA6C9", "CDEEFF", "26384F",
   {Slam = {Aura = "Sparkles"}, Defensive = {Aura = "Sparkles"}}, {Cloth = "2F5D8A", Flesh = "E0B48F"}),
 },
}
-- Gear: catalog accessory IDs by slot (worn as-is, own colours); Hide: kit pieces the gear replaces.
Rules.Skins.Solarion.Vanguard.Gear = {Front = "16902744449", Shoulders = "98139630563283,110863884304013", Back = "77395553653058", Hat = "7285794121"}
Rules.Skins.Solarion.Vanguard.Hide = {"ShoulderPlate", "ChestPlate", "BackThrusterLeft", "BackThrusterRight", "ThrusterGlowLeft", "ThrusterGlowRight", "BackCore", "HelmetCap", "HelmetCrest", "Visor"}
Rules.Skins.Wraithstep.Shadow.Gear = {Hat = "100218406253308,17752562852", Face = "119631623823588", Back = "14720055737"}
Rules.Skins.Wraithstep.Shadow.Hide = {"HoodCap", "HoodBack", "Visor", "HalfMask", "CompactBackpack", "PackLight"}
-- v28 (Peter: better hair from real assets): Tempest wears catalog hair, recoloured to each skin's Hair
-- colour (a near-white Hair keeps the asset's own strand texture). Her block-built locks come back if
-- the catalog hair fails to load. Verified on economy.roblox.com 2026-10-09 (all type 41, hair).
local TEMPEST_HAIR_PIECES = {"HairCrown", "HairVolume", "HairLock1", "HairLock2", "HairLock3", "HairLock4", "HairLock5",
 "HairSide1", "HairSide2", "HairSide3", "HairSide4", "HairFringe1", "HairFringe2"}
local TEMPEST_HAIR = {
 Default = "71806565309810",     -- windswept swirly long flowy anime hair (white)
 Thunderhead = "6536308118",     -- Long White Hair
 Monsoon = "71806565309810",
 Sunstorm = "124220882824199",   -- Storms Weather Goddess Hair
 Blizzard = "71806565309810",
 StormQueen = "6536308118",
}
for id, hair in TEMPEST_HAIR do
 Rules.Skins.Tempest[id].Gear = {Hair = hair}
 Rules.Skins.Tempest[id].Hide = TEMPEST_HAIR_PIECES
end
-- v31 asset upgrade (Peter: "do asset upgrade", from HeroWars-assets/tempest-bulwark-asset-shortlist.md).
-- Each is its hero's new first skin; the old looks are one Skin click away.
-- Stormcrown: wind-blown long hair, the Platinum Lightning Crown and a black split cloak over the Default suit.
Rules.Skins.Tempest.Stormcrown = kit("Stormcrown", "1B2235", "0F1320", "D8DEE8", "6FC8FF", "BDE8FF", "0B0D14",
 {Lightning = {Glow = true, Aura = "Sparkles"}, Gale = {Trail = true}}, {Hair = "F4F6FA", Cloth = "2B3A66"})
Rules.Skins.Tempest.Stormcrown.Gear = {Hair = "115394213298441", Hat = "13752664220", Back = "88318553584291"}
local stormHide = table.clone(TEMPEST_HAIR_PIECES)
for _, n in {"Circlet", "CircletGem", "CrownSpike1", "CrownSpike2", "CrownSpike3", "CrownSpike4", "CrownSpike5", "CapeL", "CapeR", "CapeClasp"} do
 table.insert(stormHide, n)
end
Rules.Skins.Tempest.Stormcrown.Hide = stormHide
table.insert(Rules.Skins.Tempest.Order, 1, "Stormcrown")
-- Spartan: Spartan helmet and the bronze Aegis shield on his forearm (Shield: replaces the kit shield and
-- still comes up when he guards). v34 (Peter: "remove the big back pack, show some muscles, big muscle
-- arms"): no cuirass, pauldrons or cloak any more, so his bare chest and arms show.
Rules.Skins.Bulwark.Spartan = kit("Spartan", "B9C0CA", "9AA2AE", "E1E6EC", "B8873B", "8FD3FF", "3A2A1E",
 {Slam = {Glow = true}, Charge = {Trail = true}}, {Cloth = "A3242B", Flesh = "BF8455"})
Rules.Skins.Bulwark.Spartan.Gear = {Hat = "114387329234064", Shield = "107749780314714"}
Rules.Skins.Bulwark.Spartan.Hide = {"Helmet", "Brow", "CheekGuardL", "CheekGuardR", "NoseGuard", "EyeSlitL", "EyeSlitR",
 "CrestRidge", "Plume1", "Plume2", "Plume3", "Plume4", "Plume5", "Plume6", "Plume7"}
table.insert(Rules.Skins.Bulwark.Order, 1, "Spartan")
-- v41 Mixamo bodies (Peter's Mixamo characters; Appearance BODY). Each shows the character's own textures;
-- the palette only colours effects, the outline, and the plain body if the meshes aren't in the place yet.
Rules.Skins.Solarion.Trooper = kit("Trooper", "2A2C33", "5A2220", "9AA0AA", "FF7A1F", "FFB25E", "0D0E12",
 {Beam = {Glow = true}, Pounce = {Trail = true}})
Rules.Skins.Solarion.Trooper.Body = "Ely"
Rules.Skins.Wraithstep.Shinobi = kit("Shinobi", "3B3C5A", "23243A", "6A6C88", "8C43ED", "CC9DFF", "0B0B14",
 {Grapple = {Aura = "Smoke", Glow = true}, Defensive = {Aura = "Smoke"}})
Rules.Skins.Wraithstep.Shinobi.Body = "Ninja"
Rules.Skins.Tempest.Valkyrie = kit("Valkyrie", "2A2C30", "15161A", "E2B13C", "F0C24A", "FFE9A6", "0A0A0C",
 {Lightning = {Glow = true, Aura = "Sparkles"}}, {Hair = "F2D98A", Cloth = "2A2C30"})
Rules.Skins.Tempest.Valkyrie.Body = "Maria"
Rules.Skins.Bulwark.Paladin = kit("Paladin", "3A3D42", "2A2C30", "8A8F98", "B8873B", "FFD08A", "121214",
 {Slam = {Glow = true}, Charge = {Trail = true}}, {Cloth = "3A1412", Flesh = "BF8455"})
Rules.Skins.Bulwark.Paladin.Body = "Paladin"
Rules.Skins.Bulwark.Paladin.Gear = {Shield = "107749780314714"}
-- v46 (Peter: "the skins still look like roblox skins"): the Mixamo characters are each hero's first
-- (default) skin; the older looks follow them in the Skin list.
for hero, id in {Solarion = "Trooper", Wraithstep = "Shinobi", Tempest = "Valkyrie", Bulwark = "Paladin"} do
 table.insert(Rules.Skins[hero].Order, 1, id)
end
-- "RRGGBB" -> r, g, b in 0..1 (pure, so tests and both sides share it).
function Rules.hex(h)
 return tonumber(string.sub(h,1,2),16)/255, tonumber(string.sub(h,3,4),16)/255, tonumber(string.sub(h,5,6),16)/255
end
-- Suit and Accent (0..1 triples) are derived from the palette; effects and the HUD use them.
for _,set in Rules.Skins do
 for _,id in set.Order do
  local sk = set[id]
  sk.Suit = {Rules.hex(sk.Palette.Primary)}; sk.Accent = {Rules.hex(sk.Palette.Emissive)}
 end
end
-- The skin to use: the requested one if it exists for that hero, otherwise the hero's first skin.
function Rules.skin(hero, id)
 local set = Rules.Skins[hero]
 if not set then return nil, nil end
 if type(id) == "string" and set[id] and id ~= "Order" then return set[id], id end
 return set[set.Order[1]], set.Order[1]
end
Rules.Flight = {Max = 100, Takeoff = 15, Drain = 10, Recharge = 20, Delay = 60, Speed = 24, TakeoffRise = 18, TakeoffSeconds = 0.45}
Rules.Characters = {
 -- Solarion is slower, so he gets more health (WoW plate vs leather).
 -- v28 health (Peter): Bulwark most, Wraithstep least but he slowly regenerates.
 -- Regen: health per second once he hasn't been hit for Delay ticks.
 Solarion = {Health = 115, Speed = 16, DashSpeed = 44, Flies = true, Color = {0.075,0.137,0.235}, Accent = {1,0.812,0.388}},
 Wraithstep = {Health = 100, Regen = {PerSecond = 1.5, Delay = 180}, Speed = 20, DashSpeed = 56, Color = {0.067,0.075,0.114}, Accent = {0.8,0.616,1}},
 -- v25 (Peter): Tempest, a flying storm-caller, bigger than Wraithstep and smaller than Solarion.
 Tempest = {Health = 105, Speed = 18, DashSpeed = 50, Flies = true, Color = {0.106,0.122,0.180}, Accent = {0.741,0.910,1}},
 -- Bulwark, the tank: biggest (Scale also grows the hurtbox), slowest, most health.
 -- R6 balance: Bulwark 120 HP, still the most; Shield Parry retained.
 Bulwark = {Health = 120, Speed = 13, DashSpeed = 36, Scale = 1.18, Color = {0.725,0.757,0.8}, Accent = {0.561,0.827,1}},
}
-- One defensive per hero. Usable while stunned (a stun breaker, like a WoW PvP trinket).
Rules.Defensives = {
 -- Kind: Shield (take less damage for Duration) or Blink (slide Distance, briefly untouchable).
 Solarion = {Name = "Solar Shield", Kind = "Shield", Cooldown = 1200, Duration = 120, DamageScale = 0.4},
 -- v28 Vanish (Peter: "let wraith go invisible for 3 seconds"): breaks stuns, then he is invisible to the
 -- other player for Duration ticks (untargetable, a faint shimmer up close). Attacking or being hit ends it.
 -- v45 (Peter: "disappear a shadow for 1.5 seconds then disappear from all other players"): first ShadowTime
 -- ticks as a black shadow everyone can see (and hit), then Duration ticks fully invisible to the others.
 Wraithstep = {Name = "Vanish", Kind = "Vanish", Cooldown = 1080, Duration = 180, Invulnerable = 18, ShadowTime = 0},
 Tempest = {Name = "Tailwind", Kind = "Blink", Cooldown = 900, Distance = 16, Invulnerable = 22},
 -- v48 Shield Parry (Peter: "do a parry for bulwark"): raises his shield for Window ticks. A blow that lands
 -- in the window does nothing, the attacker reels for Stun ticks, Bulwark gains Fury and the cooldown drops
 -- to SuccessCooldown. He can't attack while the shield is up. Still breaks stuns, like the other Defensives.
 Bulwark = {Name = "Shield Parry", Kind = "Parry", Cooldown = 720, Window = 21, Stun = 45, SuccessCooldown = 180, Fury = 15},
}
-- startup / active / recovery are logical 60 Hz ticks; cooldown starts on acceptance.
-- HitStop: ticks both fighters freeze on contact. Push: studs the target slides back.
-- Lunge: studs the attacker steps in during startup. Whiff: extra recovery ticks on a miss.
-- Cost: Fury spent (and triggers the GCD). Fury: Fury gained when the move connects.
-- BlockStun: ticks the defender is held on block (default 6).
Rules.Moves = {
 Light1 = {Startup=5, Active=3, Recovery=7, Damage=6, Stun=12, Range=6, Width=3.5, Height=5, Cooldown=0, HitStop=4, Push=2, Lunge=1.2, Whiff=4, Fury=6},
 Light2 = {Startup=5, Active=3, Recovery=8, Damage=7, Stun=13, Range=6, Width=3.5, Height=5, Cooldown=0, HitStop=4, Push=2.5, Lunge=1.5, Whiff=4, Fury=6},
 Light3 = {Startup=7, Active=3, Recovery=18, Damage=10, Stun=18, Range=7, Width=4, Height=5, Cooldown=0, HitStop=7, Push=6, Lunge=2, Whiff=6, Fury=8},
 Heavy = {Startup=18, Active=4, Recovery=24, Damage=16, Stun=29, Range=8, Width=5, Height=6, Cooldown=60, HitStop=9, Push=10, Lunge=2.5, Whiff=8, SweetSpot=2.5, BlockStun=16, Fury=10},
 -- Throw beats block; any strike beats it (one tick slower than a jab). Can't grab stunned or airborne fighters.
 Throw = {Startup=6, Active=2, Recovery=20, Damage=12, Stun=34, Range=4.5, Width=3.5, Height=5, Cooldown=60, HitStop=6, Push=7, Whiff=10, Throw=true, Fury=10},
 Beam = {Startup=24, Active=3, Recovery=27, Damage=14, AirDamage=10, Stun=15, Range=40, Width=4, Height=4, Cooldown=240, HitStop=5, Push=4, Cost=30},
 -- Pounce: crouch, leap in an arc at the target (up to Leap studs), pin on a direct hit, splash on landing.
 Pounce = {Startup=16, Active=30, Recovery=18, Damage=18, Stun=30, Range=5.5, Width=5, Height=6, Cooldown=300, HitStop=10, Push=0, Whiff=18, Leap=26, Splash=7, Cost=35},
 -- Grapple: two shadow bats drag the target to Wraithstep's feet. A flyer is stunned 2 seconds,
 -- someone caught mid-jump 3 seconds (v23, Peter). Range 50 (was 40) so it still reaches Solarion's higher flight.
 -- v27 audit: 1.5 s on a flyer, 2 s on a jumper (was 2 s / 3 s), and stun diminishing returns apply.
 Grapple = {Startup=18, Active=4, Recovery=26, Damage=16, Stun=120, JumpStun=180, Range=62, Width=8, Height=8, Cooldown=360, Grounding=true, AirOnly=true, Pull=3.5, HitStop=6, Push=0, Cost=35},
 Uppercut = {Startup=10, Active=5, Recovery=25, Damage=14, Stun=24, Range=9, Width=6, Height=12, Cooldown=240, HitStop=8, Push=2, Lift=38, Lunge=1.5, Whiff=8, Cost=25},
 -- v25 Tempest: a quick lightning bolt at range, and a gust that blows people back and up.
 -- v27 audit: Lightning 14 -> 18 startup and 25 -> 30 Fury, so it no longer outclasses Beam.
 Lightning = {Startup=18, Active=3, Recovery=22, Damage=12, AirDamage=10, Stun=18, Range=38, Width=3, Height=4, Cooldown=180, HitStop=6, Push=3, Cost=30},
 Gale = {Startup=12, Active=4, Recovery=22, Damage=9, Stun=26, Range=12, Width=10, Height=8, Cooldown=240, HitStop=6, Push=16, Lift=20, Whiff=6, Cost=25},
 -- v25 Bulwark: a guard-breaking ground slam, and a shoulder charge that covers ground fast.
 -- v27 audit: still unblockable, but +3 on hit (was +11), so it no longer leads into a guaranteed combo.
 Slam = {Startup=20, Active=4, Recovery=26, Damage=18, Stun=32, Range=9, Width=12, Height=6, Cooldown=300, HitStop=10, Push=8, BreaksGuard=true, Lunge=1, Whiff=10, Cost=35},
 Charge = {Startup=14, Active=6, Recovery=24, Damage=14, Stun=28, Range=6, Width=5, Height=6, Cooldown=240, HitStop=8, Push=14, Lunge=10, Whiff=10, Cost=25},
 -- v27 Bulwark anti-air: Charge aimed up at an airborne target (aim AirAim or steeper) becomes a leap
 -- of up to Leap studs along the aim. A hit slams a flyer to the ground. Same button, cooldown and Fury.
 ChargeLeap = {Startup=14, Active=18, Recovery=24, Damage=14, Stun=28, Range=3, Width=6, Height=7, Cooldown=240, HitStop=8, Push=0, Leap=40, AirAim=0.3, Grounding=true, Whiff=10, Cost=25},
}
-- v28 new moves --------------------------------------------------------------------------------
-- Solar Flare (Solarion, Skill 3): a burst all round him. Aoe = radius. Anyone invisible within Reveal
-- studs is lit up (a coloured hue) for RevealTicks and can't vanish again until it fades.
Rules.Moves.SolarFlare = {Startup=10, Active=3, Recovery=22, Damage=8, Stun=14, Range=0, Aoe=10, Width=20, Height=8,
 Cooldown=480, HitStop=5, Push=6, Reveal=16, RevealTicks=300, Whiff=6, Cost=20}
-- Shadow Door (Wraithstep, Skill 3): steps out of the shadows behind the target. Teleport moves pick a
-- free spot on a ring of radius Ring round a target MinRange..Range away (behind it first), then
-- recover for Recovery ticks. No damage.
Rules.Moves.ShadowDoor = {Startup=6, Active=1, Recovery=18, Damage=0, Stun=0, Range=30, MinRange=6, Ring=3.5,
 Teleport=true, Cooldown=600, Cost=20}
-- Dimension Door (Bulwark, Skill 3; Peter): the same ring teleport from medium range, with a 0.7 s
-- delay afterwards (Recovery 42) before he can act.
Rules.Moves.DimensionDoor = {Startup=12, Active=1, Recovery=42, Damage=0, Stun=0, Range=30, MinRange=8, Ring=4,
 Teleport=true, Cooldown=720, Cost=25}
-- Titan Drop (Bulwark's throw; Peter: "grabs the toon and slams him on his head"): grab, leap up
-- CarryHeight studs carrying the victim upside down, and drive them into the floor over Carry ticks.
-- Always a knockdown. Beats block like any throw.
Rules.Moves.TitanDrop = {Startup=8, Active=2, Recovery=20, Damage=20, Stun=34, Range=4.5, Width=3.5, Height=5,
 Cooldown=120, HitStop=6, Push=0, Whiff=12, Throw=true, Carry=36, CarryHeight=12, Fury=12}
-- v29 Whirlwind (Tempest, Skill 3; Peter: "a whirlwind at range that lifts and stuns for 4 seconds"):
-- a funnel at the target lifts them WhirlHeight studs and spins them for Stun ticks (4 s). Like WoW's
-- Cyclone, nobody can damage them while they spin, so it can't start a free combo; it can't be blocked,
-- stun diminishing returns apply and a defensive breaks out of it.
Rules.Moves.Whirlwind = {Startup=16, Active=4, Recovery=24, Damage=4, Stun=240, Range=30, Width=5, Height=6,
 Cooldown=1200, HitStop=4, Push=0, BreaksGuard=true, Whirl=true, WhirlHeight=7, Cost=40}
-- Which moves each hero's skill buttons use (Skill3 is v28, Tempest's v29).
Rules.HeroSkills = {
 Solarion = {Skill2 = "Pounce", Skill3 = "SolarFlare"},
 Wraithstep = {Skill1 = "Grapple", Skill2 = "Uppercut", Skill3 = "ShadowCircle"},
 Tempest = {Skill1 = "Lightning", Skill2 = "Gale", Skill3 = "Whirlwind"},
 Bulwark = {Skill1 = "Slam", Skill2 = "Charge", Skill3 = "DimensionDoor"},
}
-- A hero's own throw (default "Throw").
Rules.HeroThrows = {Bulwark = "TitanDrop"}
-- v28 (Peter: "change name, individualise the damage"): each hero's combo and heavy have their own name,
-- damage and a little of their own timing. Anything not listed comes from Rules.Moves.
Rules.HeroMoves = {
 Solarion = {Light1 = {Title = "Sun Jab"}, Light2 = {Title = "Flare Cross"}, Light3 = {Title = "Corona Kick"},
  Heavy = {Title = "Solar Hammer", Cast = true, Startup = 90, Damage = 24, Lunge = 0, BeamFX = true}},
 Wraithstep = {Light1 = {Title = "Shade Slash", Damage = 5, Startup = 4}, Light2 = {Title = "Night Claw", Damage = 6, Startup = 4},
  Light3 = {Title = "Reaper Kick", Damage = 9, Startup = 6}, Heavy = {Title = "Grave Scythe", Damage = 15, Startup = 15, Width = 7}},
 Tempest = {Light1 = {Title = "Spark Jab"}, Light2 = {Title = "Static Palm", Damage = 6}, Light3 = {Title = "Thunder Kick", Damage = 9, Range = 8},
  Heavy = {Title = "Storm Fist", Damage = 15, Range = 9}},
 Bulwark = {Light1 = {Title = "Shield Jab", Damage = 7, Startup = 6}, Light2 = {Title = "Pommel Strike", Damage = 8, Startup = 6},
  Light3 = {Title = "Bronze Kick", Damage = 12, Startup = 8}, Heavy = {Title = "Titan Cleave", Damage = 19, Startup = 21, Range = 9}},
}
-- Display names for moves that aren't per-hero.
Rules.Titles = {Throw = "Throw", Beam = "Solar Beam", Pounce = "Pounce", Grapple = "Grapple", Uppercut = "Uppercut",
 Lightning = "Lightning", Gale = "Gale", Slam = "Earth Slam", Charge = "Charge", SolarFlare = "Solar Flare",
 ShadowDoor = "Shadow Door", DimensionDoor = "Dimension Door", TitanDrop = "Titan Drop", Whirlwind = "Whirlwind",
 Light1 = "Jab", Light2 = "Cross", Light3 = "Kick", Heavy = "Heavy"}
local heroMoveCache = {}
-- The move table this hero actually uses (base move plus the hero's overrides). Cached.
Rules.Moves.ShadowCircle={Startup=90,Active=1,Recovery=20,Damage=0,Stun=0,Range=0,Width=0,Height=0,
 Cooldown=900,Cost=25,Cast=true,ShadowCircle=true,Radius=10,Duration=480,Multiplier=1.5}
Rules.Titles.ShadowCircle="Shadow Circle"
Rules.RemovedActions={
 Wraithstep={Light=true,Super=true,Dash=true,Flight=true},
 Solarion={Skill1=true,Super=true,Interrupt=true},
 Tempest={Light=true,Super=true,Dash=true,Interrupt=true},
 Bulwark={Super=true,Dash=true,Flight=true,Interrupt=true},
}
function Rules.actionAvailable(hero,action)
 local removed=Rules.RemovedActions[hero]
 return not (removed and removed[action])
end
function Rules.heroMove(hero, name)
 if hero=="Wraithstep" and name=="ShadowDoor" then return nil end
 local action=({Light1="Light",Light2="Light",Light3="Light"})[name] or name
 if not Rules.actionAvailable(hero,action) then return nil end
 if hero=="Solarion" and (name=="Super" or name=="Beam") then return nil end -- R22: Interrupt is back
 local base = Rules.Moves[name]
 local over = Rules.HeroMoves[hero or ""] and Rules.HeroMoves[hero][name]
 if not base or not over then return base end
 local key = hero .. ":" .. name
 if not heroMoveCache[key] then
  local m = table.clone(base)
  for k, v in over do m[k] = v end
  heroMoveCache[key] = m
 end
 return heroMoveCache[key]
end
function Rules.title(hero, name)
 local over = Rules.HeroMoves[hero or ""] and Rules.HeroMoves[hero][name]
 return over and over.Title or Rules.Titles[name] or name
end
-- Cancel routes (step B). After a move makes contact, a buffered press for one of Into may cut
-- the rest of the move short, from the contact frame (including hit-stop) to the end of recovery.
-- On="Contact": hit or blocked. On="Hit": only an unblocked hit. Fury/GCD/cooldowns still apply.
Rules.Cancels = {
 Light1 = {On = "Contact", Into = {"Light2", "Heavy", "Throw", "Skill1", "Skill2"}},
 Light2 = {On = "Contact", Into = {"Light3", "Heavy", "Skill1", "Skill2"}},
 Light3 = {On = "Hit", Into = {"Skill1", "Skill2"}},
 Heavy = {On = "Hit", Into = {"Skill1", "Skill2"}},
 Beam = {On = "Hit", Into = {"Dash"}},
 Uppercut = {On = "Hit", Into = {"Dash"}},
 Grapple = {On = "Hit", Into = {"Dash"}},
 Lightning = {On = "Hit", Into = {"Dash"}},
 Gale = {On = "Hit", Into = {"Dash"}},
 Slam = {On = "Hit", Into = {"Dash"}},
 Charge = {On = "Hit", Into = {"Dash"}},
 SolarFlare = {On = "Hit", Into = {"Dash"}},
}
-- action: {name, contact (bool), blocked (bool: every contact so far was blocked)}.
-- input: the button pressed ("Light", "Heavy", "Throw", "Skill1", "Skill2", "Dash").
-- Light cancels only chain to the next combo step (Light1 → Light2 → Light3).
function Rules.canCancel(action, input)
 local c = action and Rules.Cancels[action.name]
 if not c or not action.contact then return false end
 if c.On == "Hit" and action.blocked then return false end
 local want = input
 if input == "Light" then
  local n = tonumber(string.sub(action.name, 6))
  if string.sub(action.name, 1, 5) ~= "Light" or not n or n >= 3 then return false end
  want = "Light" .. tostring(n + 1)
 end
 return table.find(c.Into, want) ~= nil
end
-- Hurtbox states (step E): size scale and vertical shift (fraction of standing height) applied
-- to the one fixed hurtbox. Down = knocked down, Crouch = Pounce wind-up, Air = flying or jumping.
Rules.HurtboxStates = {
 Stand = {Scale = {1, 1, 1}, Shift = 0},
 Crouch = {Scale = {1, 0.7, 1}, Shift = -0.15},
 Air = {Scale = {1, 0.9, 1}, Shift = 0.05},
 Down = {Scale = {1.15, 0.35, 1.5}, Shift = -0.32},
}
-- Limb hurtbox: while a melee move is Active or in Recovery, the attacking arm/leg is hittable,
-- so a whiffed punch can be punished by poking it. Depth is a fraction of the move's Range.
Rules.Limb = {Width = 1.6, Height = 1.6, Depth = 0.6}
-- Lag compensation (step E): hits from a player are checked against where targets were
-- ping/2 + Interp seconds ago, at most MaxTicks back. HistoryTicks = ring buffer length.
Rules.Rewind = {Interp = 0.05, MaxTicks = 7, HistoryTicks = 16}
function Rules.rewindTicks(pingSeconds)
 local t = math.floor(((pingSeconds or 0) / 2 + Rules.Rewind.Interp) * Rules.Hz + 0.5)
 return math.clamp(t, 0, Rules.Rewind.MaxTicks)
end
-- Oriented box overlap (separating axis test), plain numbers so tests can run outside Roblox.
-- box = {p = {x,y,z} centre, a = {{x,y,z},{x,y,z},{x,y,z}} unit axes, h = {hx,hy,hz} half sizes}.
local function dot(u, v) return u[1]*v[1] + u[2]*v[2] + u[3]*v[3] end
local function cross(u, v) return {u[2]*v[3]-u[3]*v[2], u[3]*v[1]-u[1]*v[3], u[1]*v[2]-u[2]*v[1]} end
local function radius(box, axis)
 return box.h[1]*math.abs(dot(box.a[1], axis)) + box.h[2]*math.abs(dot(box.a[2], axis)) + box.h[3]*math.abs(dot(box.a[3], axis))
end
function Rules.boxesOverlap(A, B)
 local d = {B.p[1]-A.p[1], B.p[2]-A.p[2], B.p[3]-A.p[3]}
 local axes = {A.a[1], A.a[2], A.a[3], B.a[1], B.a[2], B.a[3]}
 for i = 1, 3 do for j = 1, 3 do
  local c = cross(A.a[i], B.a[j])
  if dot(c, c) > 1e-9 then table.insert(axes, c) end
 end end
 for _, axis in axes do
  if math.abs(dot(d, axis)) > radius(A, axis) + radius(B, axis) + 1e-6 then return false end
 end
 return true
end
function Rules.isMelee(name)
 return name=="Light1" or name=="Light2" or name=="Light3" or name=="Heavy" or name=="Uppercut" or name=="Pounce" or name=="Throw"
  or name=="Slam" or name=="Charge" or name=="TitanDrop" or name=="SolarFlare"
end
-- extra: added recovery ticks (a whiffed attack recovers slower).
function Rules.phase(move, frame, extra)
 if frame <= move.Startup then return "Startup" end
 if frame <= move.Startup + move.Active then return "Active" end
 if frame <= move.Startup + move.Active + move.Recovery + (extra or 0) then return "Recovery" end
 return "Idle"
end
function Rules.validVector(x,y,z)
 for _,v in {x,y,z} do
  if type(v) ~= "number" or v ~= v or math.abs(v) > 1.01 then return false end
 end
 return x*x+y*y+z*z <= 1.03
end
function Rules.moveName(hero, action, combo)
 if not Rules.actionAvailable(hero,action) then return nil end
 if hero=="Solarion" and (action=="Super" or action=="Skill1") then return nil end
 if action == "Light" then return "Light"..tostring(combo) end
 if action == "Heavy" then return "Heavy" end
 if action == "Throw" then return Rules.HeroThrows[hero or ""] or "Throw" end
 if action == "Interrupt" or action == "Super" then return action end
 if action == "Skill1" or action == "Skill2" or action == "Skill3" then
  local set = Rules.HeroSkills[hero] or Rules.HeroSkills.Wraithstep
  return set[action]
 end
 return nil
end
function Rules.defend(damage, blocking, facing, parry, breaksGuard, invulnerable, throw)
 if invulnerable then return 0,"Dodge" end
 if throw then return damage,"Throw" end
 if blocking and facing then
  if parry then return 0,"Parry" end
  if not breaksGuard then return math.floor(damage*0.2),"Block" end
  return damage,"GuardBreak"
 end
 return damage,"Hit"
end
-- v30 step C: a player's own client moves their fighter while nothing is forcing it, and the server
-- checks every step. Movement over the allowed speed builds up "debt" (packets arrive in bunches, so
-- some slack is fine); past SlackStuds the server snaps the fighter back to its last good spot.
Rules.Net = {
 SlackStuds = 3,       -- burst allowance before a snap-back
 SpeedTolerance = 1.25, -- allowed speed x this, per tick
 TickSlack = 0.05,     -- studs per tick on top (rounding, slopes, collisions)
 GraceTicks = 12,      -- state changes (stop, slow down) take ping plus this long to bind
 JumpRise = 8,         -- studs above the ground a jump may reach without flight (a jump is about 5)
 ReturnDelay = 6,      -- free ticks before the server hands movement back after stun, knockback etc.
 AirGrace = 60,        -- ticks after that hand-back (or a snap) before the height check applies again
}
function Rules.moveCheck(debt, moved, speed)
 local allowance = speed*Rules.Net.SpeedTolerance/60 + Rules.Net.TickSlack
 debt = math.max(0, debt + moved - allowance)
 return debt, debt > Rules.Net.SlackStuds
end
-- v32 arenas (Peter: two choices, a modern city park and an ancient Aztec ruin). First is the default.
-- Same size, floor and walls; each has its own cover, obstacles and shadow pools. Switched between matches.
Rules.Arenas = {Order = {"Ruin", "Park"}, Ruin = {Title = "Jungle Temples"}, Park = {Title = "City Park"}}
-- v49 (WoW audit step 5): cast bars and interrupts. A Cast move shows a cast bar over the caster for its
-- Startup ticks (longer now, so there is time to react). Any hit still stops it; the hero's Interrupt
-- (key 8) also locks the move it stopped for Lockout ticks, like a WoW kick's school lockout.
for _,name in {"Lightning", "Grapple", "Whirlwind", "DimensionDoor"} do
 local move=Rules.Moves[name]
 move.Startup=90; move.Cast=true
 move.Damage=math.floor(move.Damage*1.5+.5)
 if move.AirDamage then move.AirDamage=math.floor(move.AirDamage*1.5+.5) end
end
-- Fast, off the global cooldown, 15 s cooldown, little damage. Each hero's own version is in HeroMoves.
Rules.Moves.Interrupt = {Startup=5, Active=3, Recovery=14, Damage=4, Stun=10, Range=8, Width=4, Height=6,
 Cooldown=900, HitStop=4, Push=1, Lunge=1, Whiff=6, Interrupt=true, Lockout=240}
-- v49 (audit step 6): a super per hero (key 5). The Super meter fills from damage dealt and taken and
-- empties on use. The caster can't be hit during the super's wind-up (SF super freeze).
Rules.Super = {Max = 100, PerDamageDealt = 1.2, PerDamageTaken = 1.0}
Rules.Moves.Super = {Startup=18, Active=5, Recovery=30, Damage=28, Stun=50, Range=9, Width=6, Height=7,
 Cooldown=0, HitStop=14, Push=12, Lunge=2, Whiff=10, Super=true}
local function over(hero, name, t) Rules.HeroMoves[hero] = Rules.HeroMoves[hero] or {}; Rules.HeroMoves[hero][name] = t end
-- R15: Tempest trades immediate burst for visible, interruptible casts.
for name,seconds in {Lightning=4,Heavy=3,Gale=1.5,Whirlwind=1.5} do
 local base=Rules.Moves[name]
 local patch=Rules.HeroMoves.Tempest[name] or {}
 patch.Damage=(patch.Damage or base.Damage)*0.75
 if base.AirDamage then patch.AirDamage=base.AirDamage*0.75 end
 patch.Startup=seconds*60; patch.Cast=true; patch.Lunge=0
 Rules.HeroMoves.Tempest[name]=patch
end
-- Solarion Sun Lance removed in R11.
over("Wraithstep", "Interrupt", {Title = "Throat Strike", Range = 9, Lunge = 3})
over("Tempest", "Interrupt", {Title = "Static Snap", Range = 26, Width = 3, Lunge = 0})
over("Bulwark", "Interrupt", {Title = "Shield Bash", Range = 8, Width = 6, Push = 4})
-- Solarion has no Super or Solar Beam in R8.
over("Wraithstep", "Super", {Title = "Shadow Rend", Range = 8, Lunge = 16, Startup = 14, Damage = 28})
over("Tempest", "Super", {Title = "Storm Lance", Range = 45, Width = 5, Lunge = 0, Startup = 20, Damage = 26, AirDamage = 26})
over("Bulwark", "Super", {Title = "Titan Quake", Range = 0, Aoe = 13, Width = 26, Height = 8, Startup = 22, Damage = 30, BreaksGuard = true})
-- v42 (Peter: unique powers): every attack and the defensive of these skins plays its own effect style
-- (client POW.STYLE). Trooper is now Solarion's blue and gold (body "Sol", recoloured Ely).
Rules.Skins.Solarion.Trooper.Body = "Sol"
Rules.Skins.Solarion.Trooper.Palette.Primary = "13233C"; Rules.Skins.Solarion.Trooper.Palette.Secondary = "50617B"
Rules.Skins.Solarion.Trooper.Palette.Accent = "FFA924"; Rules.Skins.Solarion.Trooper.Palette.Emissive = "6FB4FF"
do local t = Rules.Skins.Solarion.Trooper; t.Suit = {Rules.hex(t.Palette.Primary)}; t.Accent = {Rules.hex(t.Palette.Emissive)} end
Rules.PowerStyles = {Plasma = true, Shadow = true, Storm = true, Holy = true}
for hero, pair in {Solarion = {"Trooper", "Plasma"}, Wraithstep = {"Shinobi", "Shadow"}, Tempest = {"Valkyrie", "Storm"}, Bulwark = {"Paladin", "Holy"}} do
 local skin = Rules.Skins[hero][pair[1]]
 local list = {"Light1", "Light2", "Light3", "Heavy", "Defensive"}
 for _, m in Rules.HeroSkills[hero] do table.insert(list, m) end
 if hero~="Solarion" then table.insert(list, "Interrupt"); table.insert(list, "Super") end
 if Rules.Moves.ChargeLeap and hero == "Bulwark" then table.insert(list, "ChargeLeap") end
 skin.Moves = {}
 for _, m in list do skin.Moves[m] = {Power = pair[2], Glow = m == "Heavy" or m == "Defensive" or nil} end
end
-- V47-R1: cosmetic review skins, retaining all older skins and the v47 motion data.
for hero,source in {Solarion="Trooper",Tempest="Stormcrown",Bulwark="Paladin"} do
 local old=Rules.Skins[hero][source]
 local modern=table.clone(old); modern.Palette=table.clone(old.Palette)
 modern.Name=hero=="Solarion" and "Solar Vanguard" or hero=="Tempest" and "Stormglass" or "Alloy Titan"
 modern.Modern=true; modern.Body=nil; modern.Gear=nil; modern.Hide=nil; modern.Moves={}
 modern.Palette.Primary="181D26"; modern.Palette.Secondary="252D38"; modern.Palette.Metal="939EAB"
 modern.Palette.Emissive=hero=="Solarion" and "FFAA2D" or hero=="Tempest" and "93E1FF" or "A3AEB9"
 modern.Palette.Accent=modern.Palette.Emissive
 if hero=="Tempest" then modern.Gear={Hair=Rules.Skins.Tempest.Stormcrown.Gear.Hair}; modern.Palette.Hair="211C25" end
 modern.Suit={Rules.hex(modern.Palette.Primary)}; modern.Accent={Rules.hex(modern.Palette.Emissive)}
 Rules.Skins[hero].Modern=modern; table.insert(Rules.Skins[hero].Order,1,"Modern")
end
-- Preserve Wraith's current skin and silhouette. Dedicated FX replaces generic power bursts.
Rules.Skins.Wraithstep.Shinobi.Moves={}
Rules.HeroMoves.Bulwark.Light2.Title="Alloy Cross"
Rules.HeroMoves.Bulwark.Light3.Title="Steelbreaker Kick"
-- R22 (Peter, 2026-10-10): every hero has five attacks; Solarion loses his dodge, Pounce hits softer and
-- Solar Hammer becomes photon pulses at range; Tempest casts faster and reaches further.
Rules.Arenas.Order = {"Park", "Ruin"} -- City Park is the default arena
Rules.RemovedActions.Solarion.Dash = true
Rules.RemovedActions.Solarion.Interrupt = nil -- 5th attack: Sun Strike
Rules.RemovedActions.Wraithstep.Light = nil   -- 5th attack: his Shade Slash combo
Rules.RemovedActions.Tempest.Light = nil      -- 5th attack: a quick Spark Jab combo (R16 audit 3)
Rules.RemovedActions.Bulwark.Interrupt = nil  -- 5th attack: Shield Bash
over("Solarion", "Interrupt", {Title = "Sun Strike", Range = 8, Lunge = 2})
over("Solarion", "Pounce", {Damage = 13}) -- was 18
do
 -- Solar Hammer: after the 1.5 s cast, three photon pulses fly out PulseGap ticks apart, each one a hit.
 local h = Rules.HeroMoves.Solarion.Heavy
 h.BeamFX = nil; h.Pulses = 3; h.PulseGap = 12; h.Active = 25; h.Range = 30; h.Width = 4; h.Height = 5
 h.Damage = 9; h.Push = 3; h.HitStop = 4; h.Stun = 18
 local t = Rules.HeroMoves.Tempest
 t.Heavy.Startup = 90; t.Heavy.Range = 14      -- Storm Fist: 1.5 s cast (was 3), reach 14 (was 9)
 t.Lightning.Startup = 120; t.Lightning.Range = 50 -- 2 s cast (was 4), range 50 (was 38)
 t.Gale.Range = 18; t.Gale.Width = 12           -- was 12
 t.Whirlwind.Range = 45                         -- was 30
 t.Light1.Range = 9; t.Light2 = t.Light2 or {}; t.Light2.Range = 9; t.Light3.Range = 11
end
-- R23 (Peter: "make Dimension Door a real attack, teleport and ground"): Bulwark steps out beside his
-- target, even one in the air, and slams on arrival. Anyone in Aoe studs takes the hit, and a flyer is
-- driven into the floor (Grounding). Reach 40 (was 30) so it gets up to flyers. His anti-air answer.
over("Bulwark", "DimensionDoor", {Range = 40, Arrive = true, Aoe = 7, Width = 14, Height = 10, Damage = 12, Stun = 40,
 HitStop = 8, Push = 4, Grounding = true, BreaksGuard = true})
-- R24 (Peter): Storm Fist has no cast at all (a normal 0.3 s heavy wind-up); Lightning casts for 3 s.
do
 local t = Rules.HeroMoves.Tempest
 t.Heavy.Cast = false; t.Heavy.Startup = 18
 t.Lightning.Startup = 180
end
-- R25 (Peter): Whirlwind has no cast and reaches further; Solarion's combo hits softer and Solar Hammer
-- casts faster; Bulwark's combo, Titan Cleave and Shield Bash hit softer.
do
 local t = Rules.HeroMoves.Tempest
 t.Whirlwind.Cast = false; t.Whirlwind.Startup = 16; t.Whirlwind.Range = 60 -- was a 1.5 s cast, range 45
 local s = Rules.HeroMoves.Solarion
 s.Light1.Damage = 5; s.Light2.Damage = 6; s.Light3.Damage = 8 -- was 6 / 7 / 10
 s.Heavy.Startup = 60 -- Solar Hammer cast 1 s (was 1.5 s)
 local b = Rules.HeroMoves.Bulwark
 b.Light1.Damage = 5; b.Light2.Damage = 6; b.Light3.Damage = 9 -- was 7 / 8 / 12
 b.Heavy.Damage = 15 -- Titan Cleave, was 19
 b.Interrupt.Damage = 2 -- Shield Bash, was 4
end
-- R26 (Peter): Dimension Door casts for 1 s (was 1.5 s) and has the longest reach in the game, 65
-- (Grapple is 62). That is Bulwark's whole change.
do local d = Rules.HeroMoves.Bulwark.DimensionDoor; d.Startup = 60; d.Range = 65 end
-- R27 (Peter): Vanish lasts twice as long, 6 s (was 3 s). Attacking or being hit still ends it.
Rules.Defensives.Wraithstep.Duration = 360
-- R29 (Peter): Bulwark loses keys 1 and 5 (Shield Jab combo and Shield Bash). His keys renumber in
-- order: 1 Titan Cleave, 2 Earth Slam, 3 Charge, 4 Shield Parry, 5 Dimension Door.
Rules.RemovedActions.Bulwark.Light = true
Rules.RemovedActions.Bulwark.Interrupt = true
-- R29 (Peter: "allow grapple to hit on the ground and stun"): Grapple now catches grounded targets too.
-- On the ground: reeled in and stunned 2 s (Stun 120). Caught jumping: 3 s (JumpStun). A flyer is
-- pulled out of the air as before.
Rules.Moves.Grapple.AirOnly = nil
-- R30 (Peter): Solarion loses Sun Strike (interrupt) and Solar Flare; Tempest loses Tailwind and Gale.
-- Keys renumber in order: Solarion 1 Combo, 2 Solar Hammer, 3 Pounce, 4 Fly, 5 Solar Shield;
-- Tempest 1 Combo, 2 Storm Fist, 3 Lightning, 4 Fly, 5 Whirlwind.
Rules.RemovedActions.Solarion.Interrupt = true
Rules.RemovedActions.Solarion.Skill3 = true
Rules.RemovedActions.Tempest.Defensive = true
Rules.RemovedActions.Tempest.Skill2 = true
-- Tempest's channelled cast 0.7 s shorter: Lightning 3 s -> 2.3 s.
Rules.HeroMoves.Tempest.Lightning.Startup = Rules.HeroMoves.Tempest.Lightning.Startup - 42
-- R31 (Peter: "reduce the circle for wraith cooldown by .7"): Shadow Circle cooldown 15 s -> 14.3 s.
Rules.Moves.ShadowCircle.Cooldown = Rules.Moves.ShadowCircle.Cooldown - 42
-- R32 (Peter): Wraithstep loses Uppercut and Throat Strike.
-- Keys: 1 Combo, 2 Grave Scythe, 3 Grapple, 4 Vanish, 5 Shadow Circle.
Rules.RemovedActions.Wraithstep.Skill2 = true
Rules.RemovedActions.Wraithstep.Interrupt = true
-- R33 (Peter: "reduce Wraith cast time by .7 seconds"): Grapple and Shadow Circle cast 1.5 s -> 0.8 s.
for _,name in {"Grapple","ShadowCircle"} do
 local o=Rules.HeroMoves.Wraithstep and Rules.HeroMoves.Wraithstep[name]
 if o and o.Startup then o.Startup=o.Startup-42 else Rules.Moves[name].Startup=Rules.Moves[name].Startup-42 end
end
-- R35 (Peter, 18:41).
-- Tempest: Storm Fist (key 2) reaches 22 (was 14); Lightning cast 0.8 s shorter, 2.3 s -> 1.5 s.
Rules.HeroMoves.Tempest.Heavy.Range = 22
Rules.HeroMoves.Tempest.Lightning.Startup = Rules.HeroMoves.Tempest.Lightning.Startup - 48
-- Bulwark: Earth Slam (key 2) becomes a holy shock circle all round him (radius 12). Everyone it hits has a
-- 40% chance of a 1.5 s stun, and everyone within 16 is lit up with a gold outline for 2 s (can't vanish or
-- hide in shadow). Bulwark also gets a speed boost: 40% faster for 3 s.
do local m=Rules.HeroMoves.Bulwark.Slam or {}; Rules.HeroMoves.Bulwark.Slam=m
 m.Aoe=12; m.Height=8; m.StunChance=0.4; m.ChanceStun=90; m.Reveal=16; m.RevealTicks=120; m.HolyRing=true
 m.SpeedBuff=1.4; m.SpeedTicks=180 end
-- Wraithstep: Shadow Circle hits harder (+75%, was +50%) and burns enemies standing in it (3 damage every
-- half second), and his attacks deal 15% more.
Rules.Moves.ShadowCircle.Multiplier = 1.75
Rules.Moves.ShadowCircle.Burn = 3
Rules.Moves.ShadowCircle.BurnEvery = 30
for _,n in {"Light1","Light2","Light3","Heavy","Grapple"} do
 local o=Rules.HeroMoves.Wraithstep[n]
 local base=(o and o.Damage) or Rules.Moves[n].Damage
 if o then o.Damage=base*1.15 else Rules.HeroMoves.Wraithstep[n]={Damage=base*1.15} end
end
table.clear(heroMoveCache)
-- R36 (Peter: "Bulwark is boring, how can I make him more exciting"; see BULWARK_AUDIT_R35.md).
-- Charge: super armour (hits don't stop it) and a wall splat: a connecting Charge carries the target 12
-- studs; driving them into a wall stuns 1.2 s and deals 8 more.
Rules.Moves.Charge.Armor = true
Rules.Moves.Charge.Carry12 = 12
Rules.Bulwark = {
 SplatDamage = 8, SplatStun = 72,
 -- Parry riposte: a successful Shield Parry bashes back for 10 and resets Charge.
 RiposteDamage = 10,
 -- Juggernaut: each unblocked hit he lands is a stack (max 5, gone 4 s after his last hit); each stack is
 -- +4% speed and +4% damage. At 5 stacks his next Titan Cleave becomes a 20-stud shockwave (+30% damage).
 StackMax = 5, StackTicks = 240, StackSpeed = 0.04, StackDamage = 0.04,
 ShockRange = 20, ShockWidth = 7, ShockDamage = 1.3,
}
-- Weight: his Cleave and Slam freeze the hit a little longer.
Rules.HeroMoves.Bulwark.Heavy.HitStop = (Rules.HeroMoves.Bulwark.Heavy.HitStop or Rules.Moves.Heavy.HitStop or 8) + 3
Rules.HeroMoves.Bulwark.Slam.HitStop = (Rules.Moves.Slam.HitStop or 10) + 2
table.clear(heroMoveCache)
-- R37 (Peter, after the R36 balance audit).
-- Solarion: the audit's fix, combo 5/6/8 -> 6/7/9.
do local s=Rules.HeroMoves.Solarion; s.Light1.Damage=6; s.Light2.Damage=7; s.Light3.Damage=9 end
-- Bulwark: melee damage down about 15%: Cleave 15 -> 13, Earth Slam 18 -> 15, Charge 14 -> 12.
Rules.HeroMoves.Bulwark.Heavy.Damage = 13
Rules.HeroMoves.Bulwark.Slam.Damage = 15
do local c=Rules.HeroMoves.Bulwark.Charge or {}; Rules.HeroMoves.Bulwark.Charge=c; c.Damage=12
   local l=Rules.HeroMoves.Bulwark.ChargeLeap or {}; Rules.HeroMoves.Bulwark.ChargeLeap=l; l.Damage=12 end
-- Bulwark: Shield Bash returns as Shield Throw (key 5): he hurls his shield like a frisbee up to 35 studs
-- and it spins back to his hand. Low damage (2), still an interrupt (locks a cast 4 s), and it knocks a
-- flyer out of the air (Grounding).
Rules.RemovedActions.Bulwark.Interrupt = nil
do local m=Rules.HeroMoves.Bulwark.Interrupt
 m.Title="Shield Throw"; m.Range=35; m.Width=4; m.Height=6; m.Damage=2; m.Startup=12; m.Active=6; m.Recovery=18
 m.Lunge=0; m.Push=2; m.Grounding=true; m.ShieldThrow=true; m.Cooldown=600 end
table.clear(heroMoveCache)
-- R38 (Peter: "fix Wraithstep but give him a DoT to drain and gain back health based on damage given").
-- The R36 audit fix: Shadow Circle back to +50% (burn kept), and the R35 +15% damage taken off again.
Rules.Moves.ShadowCircle.Multiplier = 1.5
Rules.Moves.ShadowCircle.Burn = 2 -- was 3; the Soul Drain is his DoT now
for _,n in {"Light1","Light2","Light3","Heavy","Grapple"} do
 local o=Rules.HeroMoves.Wraithstep[n]; if o and o.Damage then o.Damage=o.Damage/1.15 end
end
-- Soul Drain: Grave Scythe (key 2) leaves a drain on the target, 2 damage every half second for 3 s
-- (12 in all); every point drained heals Wraithstep. A new Scythe hit refreshes it.
do local m=Rules.HeroMoves.Wraithstep.Heavy; m.Drain=2; m.DrainEvery=30; m.DrainTicks=6; m.DrainHeal=1 end
table.clear(heroMoveCache)
-- R41 (Peter: "Solarion is pretty weak"): Solar Hammer casts in 0.5 s (was 1 s). Solar Shield is now a
-- damage sponge: while it is up he takes no damage at all until it has soaked Absorb points, then it
-- burns off. It lasts 4 s (was 2 s), comes back in 10 s (was 20 s), and he can attack, fly and move
-- freely with it on. Hits it soaks completely don't stun or knock him back either.
Rules.HeroMoves.Solarion.Heavy.Startup = 30
do local d = Rules.Defensives.Solarion; d.Duration = 240; d.Cooldown = 600; d.DamageScale = nil; d.Absorb = 30 end
-- R41 (Peter): Tempest's Storm Fist and Lightning leave a lightning tick on the target (Zap damage every
-- ZapEvery ticks, ZapTicks times). Each of those hits also gives her one heal stack (max StackMax, gone
-- StackTicks after her last one); every tick heals her StackHeal x stacks of its damage:
-- 2 stacks 25%, 4 stacks 50%, 6 stacks 75%.
Rules.Tempest = {ZapDamage = 2, ZapEvery = 30, ZapTicks = 6, StackMax = 6, StackHeal = 0.125, StackTicks = 480}
Rules.HeroMoves.Tempest.Heavy.Zap = true
Rules.HeroMoves.Tempest.Lightning.Zap = true
table.clear(heroMoveCache)
-- R42: Whirlwind locks onto the nearest enemy within 60 studs inside a 25-degree wedge of the aim
-- (see hitTargets in Main). It still lifts and spins them for 4 s, untouchable.
Rules.HeroMoves.Tempest.Whirlwind.Cone = 25
Rules.HeroMoves.Tempest.Whirlwind.ReachY = 40
-- R46 (Peter: "make the Tempest one do damage as well and add a tick"): Whirlwind hits for 8 (was 4.5)
-- and leaves a lightning tick for the whole 4 s spin (8 ticks of 2), which also gives her a heal stack.
do local w = Rules.HeroMoves.Tempest.Whirlwind; w.Damage = 8; w.Zap = true; w.ZapTicks = 8 end
-- R44 (Peter): Whirlwind cooldown 12 s (was 20 s).
-- R45 (Peter: "increase the cooldown over usage but drop it low at first"): a ramping cooldown. The first
-- cast waits 4 s, and each cast after it adds 4 s (4, 8, 12, 16, then 20 s at most). Leave it ready and
-- unused for RampReset ticks (10 s) and it drops back to 4 s.
do local w = Rules.HeroMoves.Tempest.Whirlwind; w.Cooldown = 240; w.RampStep = 240; w.RampMax = 1200; w.RampReset = 600 end
table.clear(heroMoveCache)
-- R47 (Peter, 2026-10-11) ------------------------------------------------------------------------
-- Solar Hammer: a ramping cooldown like Whirlwind. 1 s first, +1.5 s per cast (1, 2.5, 4, 5.5, 7, 8 s
-- at most); 6 s ready and unused drops it back to 1 s.
do local h = Rules.HeroMoves.Solarion.Heavy; h.Cooldown = 60; h.RampStep = 90; h.RampMax = 480; h.RampReset = 360 end
-- Solar Absorb (Solarion, Skill 3, the last key): he puts down a glowing white-and-red sphere (radius
-- Radius) for Duration ticks. Every enemy inside loses Absorb health each AbsorbEvery ticks and Solarion
-- gains it. No hitbox; like Shadow Circle it's a zone.
Rules.Moves.SolarAbsorb = {Startup = 20, Active = 1, Recovery = 16, Damage = 0, Stun = 0, Range = 10, Width = 0, Height = 0,
 Cooldown = 1080, Cost = 25, SolarAbsorb = true, Radius = 12, Duration = 480, Absorb = 2, AbsorbEvery = 30}
Rules.Titles.SolarAbsorb = "Solar Absorb"
Rules.HeroSkills.Solarion.Skill3 = "SolarAbsorb"
Rules.RemovedActions.Solarion.Skill3 = nil
-- Lightning Snare (Tempest, Skill 2): locks onto the enemy you aim at (like Whirlwind) and lightning
-- bursts up from the ground and holds them in place, even in the air, for Stun ticks (2 s). It leaves a
-- lightning tick and gives her a heal stack.
Rules.Moves.GroundBolt = {Startup = 24, Active = 2, Recovery = 20, Damage = 6, Stun = 120, Range = 50, Width = 0, Height = 0,
 Cooldown = 900, Cost = 25, HitStop = 4, Push = 0, LockOn = true, Cone = 35, ReachY = 40, Snare = true, Zap = true, ZapTicks = 4}
Rules.Titles.GroundBolt = "Lightning Snare"
Rules.HeroSkills.Tempest.Skill2 = "GroundBolt"
Rules.RemovedActions.Tempest.Skill2 = nil
-- Whirlwind: a wider lock-on (35 degrees), and it also catches every other enemy within WhirlSplash studs
-- of its target. Casting it wraps Tempest in a mist cloud: she takes 50% less damage for 12 s (3x the spin).
do local w = Rules.HeroMoves.Tempest.Whirlwind; w.Cone = 35; w.WhirlSplash = 8; w.Mist = 720; w.MistScale = 0.5 end
-- Spark Jab combo reaches 20 studs (was 9 / 9 / 11).
do local t = Rules.HeroMoves.Tempest; t.Light1.Range = 20; t.Light2.Range = 20; t.Light3.Range = 20 end
table.clear(heroMoveCache)
-- R49 (Peter: "Wraith's sixth power is Phase"): a shorter vanish (Phase ticks, 3 s). While phased his
-- combo key fires Shade Bolts instead: ranged lock-on shots that leave a shadow damage-over-time (Dot every
-- DotEvery ticks, DotTicks times) that heals him for what it deals (like Solar Absorb). Every bolt is its own
-- stack, and they stack with Soul Drain. Attacking or being hit doesn't reveal him until the timer ends.
Rules.Moves.Phase = {Startup = 6, Active = 1, Recovery = 10, Damage = 0, Stun = 0, Range = 0, Width = 0, Height = 0,
 Cooldown = 1080, Cost = 20, Phase = 180}
Rules.Titles.Phase = "Phase"
-- R50 (Peter chose "gaps of 2/4/6 s"): Phase lasts 12.5 s and he flickers visible to everyone for
-- GlitchTicks at each Glitches mark (seconds after he phased): 2 s in, then 4 s later, then 6 s later.
do local p = Rules.Moves.Phase; p.Phase = 750; p.Glitches = {2, 6, 12}; p.GlitchTicks = 18 end
Rules.Moves.ShadeBolt = {Startup = 10, Active = 2, Recovery = 14, Damage = 1, Stun = 0, Range = 40, Width = 0, Height = 0,
 Cooldown = 30, HitStop = 0, Push = 0, LockOn = true, Cone = 35, ReachY = 40, Dot = 2, DotEvery = 30, DotTicks = 6, DotHeal = 1}
Rules.Titles.ShadeBolt = "Shade Bolt"
Rules.HeroSkills.Wraithstep.Skill2 = "Phase"
Rules.RemovedActions.Wraithstep.Skill2 = nil
-- R52 (Peter): Shield Parry also gives Bulwark a burn-off shield (Absorb points for AbsorbTicks, 6.5 s;
-- he takes no damage until it is burnt off) and a HealTicks (3 s) window: every parry or hit he lands in it
-- heals him HealPct (25%) of that blow's damage.
do local d = Rules.Defensives.Bulwark; d.Absorb = 25; d.AbsorbTicks = 390; d.HealTicks = 180; d.HealPct = 0.25 end
-- R53 (Peter, 2026-10-11, from BALANCE_AUDIT_R52.md) -------------------------------------------------
-- Phase lasts 8 s and glitches at 2 and 5 s. Shade Bolts don't stack: a new bolt restarts the one shadow tick.
do local p = Rules.Moves.Phase; p.Phase = 480; p.Glitches = {2, 5} end
Rules.Moves.ShadeBolt.NoStack = true
-- Bulwark: the 25 shield and the heal window only start when a parry lands; a landed parry resets to 6 s.
do local d = Rules.Defensives.Bulwark; d.OnSuccess = true; d.SuccessCooldown = 360 end
-- Tempest: Tailwind is back as her defensive; Storm Fist 14, Spark Jab combo 7/7/10, lightning tick 3.
Rules.RemovedActions.Tempest.Defensive = nil
do local t = Rules.HeroMoves.Tempest; t.Heavy.Damage = 14; t.Light1.Damage = 7; t.Light2.Damage = 7; t.Light3.Damage = 10 end
Rules.Tempest.ZapDamage = 3
-- Solarion: Solar Shield cooldown 14 s (was 10 s).
Rules.Defensives.Solarion.Cooldown = 840
-- Bulwark Earth Slam: no 40% roll; every hit stuns a fixed 0.8 s (under the 1 s diminishing-returns line).
do local m = Rules.HeroMoves.Bulwark.Slam; m.StunChance = nil; m.ChanceStun = nil; m.Stun = 48 end
-- R66-ui11c (Peter, 2026-10-13: "reduce the cd on Bulwark's big attack but don't let him spam" ... "no, his
-- spam attack button"): Titan Cleave (key 1) cooldown 0.6 s (was 1 s), so the swing itself (about 0.8 s) sets
-- the pace. Each Cleave used within 1.5 s of it coming ready waits 0.2 s longer, up to 1.2 s, so mashing it
-- slows down; a short pause resets it.
do local m = Rules.HeroMoves.Bulwark.Heavy; m.Cooldown = 36; m.RampStep = 12; m.RampMax = 72; m.RampReset = 90 end
table.clear(heroMoveCache)
-- Diminishing returns: Lightning Snare (root) and Whirlwind (cyclone) each count on their own, apart from stuns.
function Rules.drGroup(move) return move.Snare and "Root" or move.Whirl and "Cyclone" or "Stun" end
table.clear(heroMoveCache)
-- R54 (Peter: "put up the parry shield longer and reflect the attack back at the caster; only heal on a
-- successful parry"): the parry window is 1 s (was 0.35 s) and stays up the whole time. Every blow that
-- lands in it, melee or ranged, is reflected back at its attacker for Reflect x its damage (replaces the
-- fixed 10 riposte), and the attacker reels. The shield, Fury and 6 s reset come once per window. The heal
-- (25% of each parried blow) comes only from parries now, not from hits he lands.
do local d = Rules.Defensives.Bulwark; d.Window = 60; d.Reflect = 1; d.HealOnParryOnly = true end
-- R55 (Peter: "give back Wraith his stacks like you suggested"): Shade Bolts stack again, up to MaxStacks
-- on one target; a 4th bolt replaces the oldest stack.
Rules.Moves.ShadeBolt.NoStack = nil
Rules.Moves.ShadeBolt.MaxStacks = 3
-- R58 (Peter: "what are the squares on the ground, remove them"): the dark shadow-pool squares (Wraithstep's
-- Shroud zones) and the green moss squares are gone from both arenas. true brings them back.
Rules.Arenas.ShadowPools = false
-- R59 (Peter: "upgrade the pyramid look"): Peter's Toolbox temples, baked into ReplicatedStorage.HeroWars.Temples.
-- HW_Temple (the "Mayan Temple" mesh) replaces the two plaza pyramids and the two side shrines; HW_Temple2 (a big
-- stepped pyramid with a temple on top) replaces Temple I and Temple II behind the trees.
--   Name     model in Temples        Yaw  turns it (degrees) so its stairs face the plaza
--   Fit      footprint = old temple base x Fit (the mesh has a wide stone slab, so 1.6 keeps the pyramid the old size)
--   Height   if set, scale by height instead of footprint
--   Collide  true = players walk on the model itself; the old blocks are removed. false = look only, and the
--            old blocks stay as invisible walls (KeepBlocks).
-- Enabled = false brings the old block temples back.
Rules.Arenas.TempleModels = {
	Enabled = true,
	Temple = {Name = "HW_Temple", Yaw = 180, Fit = 1.6, Collide = true},
	Shrine = {Name = "HW_Temple", Yaw = 180, Fit = 1.6, Collide = true},
	BigNorth = {Name = "HW_Temple2", Yaw = -90, Height = 125, Collide = false},
	BigSouth = {Name = "HW_Temple2", Yaw = -90, Height = 70, Collide = false},
	-- R61 (Peter: "move the big pyramid to the centre and remove the small pyramids"): HW_Temple2 stands in
	-- the middle of the plaza, Width studs across (trees included), stairs facing +Z, and you can climb it.
	-- The small temples and the far temples are not built while it is. Spots = start z of the player, the bot
	-- and the round line, all on the stairs side. Centre = nil goes back to the R59 layout.
	Centre = {Name = "HW_Temple2", Yaw = -90, Width = 80, Collide = true, Spots = {Player = 78, Dummy = 48, Round = 64},
		Rings = {{0, 64, "x"}, {0, -64, "x"}, {-66, 0, "z"}, {66, 0, "z"}}},
}
-- R62 (Peter: "add more HP to Bulwark, you decide"): 120 -> 135. Duel sim (r62 sim, R61 rules): he is
-- already strong toe-to-toe but loses when kited at range (23-49%); 135 lifts his kite games to 30-52% while
-- keeping melee short of runaway (perfect parry reads 81%).
Rules.Characters.Bulwark.Health = 135
-- R63 (top-5 audit item 1, "everyone fights"): several 1v1 duels at once, each on its own ring. A ring is a
-- start mark {x, z, axis}: the two fighters stand 12 studs either side of it along the axis, facing each other.
-- Ring 1 is the old duel spot. Jungle Temples with the centre pyramid uses TempleModels.Centre.Rings.
Rules.Arenas.Park.Rings = {{0, 10, "x"}, {0, 74, "x"}, {0, -74, "x"}, {-72, 0, "z"}, {72, 0, "z"}}
Rules.Arenas.Ruin.Rings = {{0, 10, "x"}, {-45, 45, "x"}, {45, 45, "x"}, {-45, -45, "x"}, {45, -45, "x"}}
-- R35: the "angel arrives" choir on Bulwark's holy slam. Paste a Roblox audio id here (Toolbox > Audio,
-- search "angel choir"), e.g. "rbxassetid://123456". Empty = a bright shimmer chord from the sound bank.
Rules.AngelChoirSound = ""
-- R66-ui9 Tactical bot AI (Peter, 2026-10-12: "Bot AI Strategy & Priority System", our four heroes only).
-- Pure data, read by the server ModuleScript ServerScriptService.HeroWars.BotAI. Tune the bot here; no code
-- changes are needed. Times are 60 Hz ticks (60 = 1 s); distances are studs.
--
-- How a decision works: every Think ticks (and the moment the bot notices something new) each tactic in the
-- hero's kit is checked. A tactic that fits the fight scores PriorityScore[P] + its own bonus + a random
-- 0..Noise. The best score wins (Mistake = chance it picks a random fitting tactic instead). P1 always beats
-- P2, P2 beats P3, unless Noise is bigger than the gap (Easy).
-- The bot never sees more than a player would: an enemy attack is only noticed React ticks after its
-- wind-up starts, it can't target someone invisible, and it uses the same buttons, cooldowns, Fury and
-- recovery as a player.
Rules.BotAI = {
 Debug = false,          -- true: every decision is printed to Output as "[BotAI] ..."
 Attributes = true,      -- the bot model carries live AI_* attributes (select it in the Explorer to watch)
 PriorityScore = {300, 200, 100}, -- P1, P2, P3
 SpamCount = 3,          -- this many enemy attack starts inside SpamWindow ticks counts as "spamming"
 SpamWindow = 150,
 Memory = 8,             -- enemy attack starts remembered (pattern memory)
 LowHealth = 0.3,        -- below this share of health, survival tactics come first
 Difficulty = {
  -- React: ticks before an enemy wind-up is noticed (random in the range). Think: ticks between plans.
  -- Defend: chance to defend a threatening attack it noticed. Counter: chance to punish a miss or an opening.
  -- Combo: how many presses of a combo chain it carries out. AntiAir / Interrupt / Trinket: chances.
  -- Noise: random score added to every tactic. Mistake: chance of a random fitting tactic.
  -- Learn: remembers the enemy's rhythm and baits spam. Bait: chance to bait when it does.
  -- Reserve: keeps Fury for its anti-air move against a flying hero. Respect: chance to hold back from
  -- hitting into a Shield Parry, a Whirlwind spin or a Solar Shield. Spacing: chance to keep its range.
  -- R66-ui11 (Peter, 2026-10-13: "tone down the bot"): Easy is new and much weaker, with reactions about twice
  -- as slow as the old Easy; Normal is the old Easy; Hard is the old Normal.
  Easy = {React = {60, 96}, Think = {48, 72}, Defend = 0.08, Counter = 0.1, Combo = {1, 1}, AntiAir = 0.1,
   Interrupt = 0.05, Trinket = 0.1, Noise = 110, Mistake = 0.45, Learn = false, Bait = 0, Reserve = false,
   Respect = 0, Spacing = 0.15,
   Burst = {1, 2}, Discipline = 0.35, Patience = 0.5, Pressure = 240, Dodge = 0.1, Retreat = 0.3, Variety = 30, Read = false},
  Normal = {React = {30, 48}, Think = {24, 36}, Defend = 0.2, Counter = 0.25, Combo = {1, 2}, AntiAir = 0.25,
   Interrupt = 0.15, Trinket = 0.25, Noise = 70, Mistake = 0.3, Learn = false, Bait = 0, Reserve = false,
   Respect = 0.1, Spacing = 0.3,
   Burst = {1, 3}, Discipline = 0.6, Patience = 0.7, Pressure = 200, Dodge = 0.25, Retreat = 0.5, Variety = 50, Read = false},
  Hard = {React = {18, 30}, Think = {12, 20}, Defend = 0.5, Counter = 0.6, Combo = {2, 3}, AntiAir = 0.6,
   Interrupt = 0.5, Trinket = 0.6, Noise = 50, Mistake = 0.1, Learn = false, Bait = 0, Reserve = true,
   Respect = 0.6, Spacing = 0.7,
   Burst = {2, 3}, Discipline = 0.85, Patience = 0.85, Pressure = 170, Dodge = 0.55, Retreat = 0.65, Variety = 60, Read = true},
 },
 -- R66-ui12 (Peter, 2026-10-31: "the bot just runs up and starts chopping, make it more strategic and tactical"):
 -- stance settings, added to each level above. Smarter, not stronger: reactions, defend and punish chances stay
 -- as R66-ui11 set them.
 --   Burst: presses per trip in before it steps back out.  Discipline: chance it really steps out (else keeps
 --   swinging).  Patience: chance it waits in neutral instead of just walking in.  Pressure: ticks without a press
 --   before it goes in anyway.  Dodge: chance to step out of a noticed attack (was the Defend chance).
 --   Retreat: chance to back off when low and behind.  Variety: score taken off the tactic it used last.
 --   Read: goes in when your defensive is on cooldown.  Noise is lower than R66-ui11 so its priorities matter.
 -- Styles (per hero): Aggro = how often a stance ends in going in (0-1), Margin = studs it waits outside your
 -- swing reach, HitAndOut = how much it likes stepping out after a burst, Advance = creeps forward while waiting
 -- (never backs up), RetreatHP = health share it backs off at (0 = never), *Time = stance lengths in ticks.
 Styles = {
  Default = {Aggro = 0.5, Margin = 1.5, HitAndOut = 0.6},
  -- Juggernaut: walks you down behind his shield, parries, punishes; never runs.
  Bulwark = {Aggro = 0.6, Margin = 1, HitAndOut = 0.3, Advance = true, RetreatHP = 0, NeutralTime = {30, 60}},
  -- Kiter: stays at lightning range, snares whoever walks in, blinks away; backs off early.
  Tempest = {Aggro = 0.4, Margin = 4, HitAndOut = 0.9, RetreatHP = 0.4, OutTime = {40, 70}},
  -- Diver: waits outside your reach, pounces in for a burst, gets out again.
  Solarion = {Aggro = 0.5, Margin = 3, HitAndOut = 0.75, RetreatHP = 0.3, NeutralTime = {40, 80}},
  -- Assassin: patient, pokes with Shade Bolts, goes in when you miss or are low.
  Wraithstep = {Aggro = 0.3, Margin = 3.5, HitAndOut = 0.85, RetreatHP = 0.35, NeutralTime = {60, 110}},
 },
 -- Strategy kits. Ideal / Min = the range it likes and the closest it lets an enemy stay. Use = the button.
 -- Type says what the tactic waits for (see BotAI for each):
 --   StunBreak  stunned 0.7 s+, spun, snared or knocked down: use the defensive as a trinket
 --   Defend     a noticed enemy attack will land within Lead ticks (Heavy = only big attacks)
 --   Escape     health under LowHP and the enemy is close
 --   Interrupt  the enemy is channelling a cast that won't finish before this lands
 --   Peel       an enemy closer than Max is walking in (ranged heroes push them off)
 --   AntiAir    the enemy is flying or in the air, Min..Max away
 --   Punish     the enemy just missed (in recovery), or is held (stunned/snared), Min..Max away
 --   Combo      a chain of presses (Chain) in melee reach Max
 --   Melee      one press in reach Max     GapClose  Min..Max away     Ranged  Min..Max away, clear sight
 --   Zone       a circle/sphere when the enemy is within Max (Held = only on a held enemy)
 --   Phase      Wraithstep's Phase when the enemy is Min+ away   Fly  take off (When "foeFlies" or "kited")
 --   Reveal     the enemy vanished within Max: slam where they were   Bait  (Hard) step out of a spammer's reach
 --   Evade      no button: step back from a noticed melee attack, or sideways from a ranged one
 Kits = {
  Bulwark = {Ideal = 5, Min = 2, Reserve = "Interrupt", Tactics = {
   {Id = "Trinket", P = 1, Type = "StunBreak", Use = "Defensive"},
   {Id = "Parry", P = 1, Type = "Defend", Use = "Defensive", Lead = 30},
   {Id = "ShieldThrowCast", P = 1, Type = "Interrupt", Use = "Interrupt"},
   {Id = "ShieldThrowAir", P = 1, Type = "AntiAir", Use = "Interrupt", Max = 33},
   {Id = "ChargeLeapAir", P = 1, Type = "AntiAir", Use = "Skill2", Max = 30, Bonus = -10},
   {Id = "CleavePunish", P = 1, Type = "Punish", Use = "Heavy", Max = 9},
   {Id = "SlamPunish", P = 1, Type = "Punish", Use = "Skill1", Max = 11, Bonus = 10},
   {Id = "RevealSlam", P = 2, Type = "Reveal", Use = "Skill1", Max = 12},
   {Id = "DoorAir", P = 2, Type = "AntiAir", Use = "Skill3", Min = 12, Max = 60},
   {Id = "CleaveSlam", P = 2, Type = "Combo", Chain = {"Heavy", "Skill1"}, Max = 8.5},
   {Id = "Slam", P = 2, Type = "Melee", Use = "Skill1", Max = 11},
   {Id = "ChargeIn", P = 2, Type = "GapClose", Use = "Skill2", Min = 7, Max = 16},
   {Id = "DoorIn", P = 3, Type = "GapClose", Use = "Skill3", Min = 22, Max = 62},
   {Id = "StepOut", P = 2, Type = "Evade", Bonus = 40},
   {Id = "BaitSpam", P = 2, Type = "Bait", Bonus = 60},
  }},
  Tempest = {Ideal = 14, Min = 9, Reserve = "Skill2", Tactics = {
   {Id = "Trinket", P = 1, Type = "StunBreak", Use = "Defensive"},
   {Id = "Tailwind", P = 1, Type = "Defend", Use = "Defensive", Lead = 14, Heavy = true},
   {Id = "TailwindLow", P = 1, Type = "Escape", Use = "Defensive", Max = 9},
   {Id = "WhirlLow", P = 1, Type = "Escape", Use = "Skill3", Max = 20, Bonus = 20},
   {Id = "SnareCast", P = 1, Type = "Interrupt", Use = "Skill2", Max = 48},
   {Id = "WhirlCast", P = 1, Type = "Interrupt", Use = "Skill3", Max = 55, Bonus = -10},
   {Id = "SnareAir", P = 1, Type = "AntiAir", Use = "Skill2", Max = 48},
   {Id = "FistPunish", P = 1, Type = "Punish", Use = "Heavy", Max = 21},
   {Id = "SnarePeel", P = 1, Type = "Peel", Use = "Skill2", Max = 8, Bonus = -20},
   {Id = "LightningHeld", P = 2, Type = "Ranged", Use = "Skill1", Min = 8, Max = 48, Held = true, Bonus = 40},
   {Id = "LightningAir", P = 2, Type = "AntiAir", Use = "Skill1", Max = 48},
   {Id = "SparkCombo", P = 2, Type = "Combo", Chain = {"Light", "Light", "Light", "Heavy"}, Max = 19},
   {Id = "StormFist", P = 2, Type = "Melee", Use = "Heavy", Max = 21},
   {Id = "Lightning", P = 3, Type = "Ranged", Use = "Skill1", Min = 22, Max = 48},
   {Id = "FlyUp", P = 3, Type = "Fly", Use = "Flight", When = "foeFlies"},
   {Id = "StepOut", P = 2, Type = "Evade", Bonus = 40},
   {Id = "BaitSpam", P = 2, Type = "Bait", Bonus = 60},
  }},
  Solarion = {Ideal = 4, Min = 2, LandEnergy = 35, Tactics = {
   {Id = "Trinket", P = 1, Type = "StunBreak", Use = "Defensive"},
   {Id = "SolarShield", P = 1, Type = "Defend", Use = "Defensive", Lead = 40, Heavy = true},
   {Id = "ShieldLow", P = 1, Type = "Escape", Use = "Defensive", Max = 10},
   {Id = "HammerAir", P = 1, Type = "AntiAir", Use = "Heavy", Max = 28},
   {Id = "PouncePunish", P = 1, Type = "Punish", Use = "Skill2", Min = 4, Max = 24},
   {Id = "JabPunish", P = 1, Type = "Punish", Use = "Light", Max = 7, Bonus = 10},
   {Id = "FlyAir", P = 2, Type = "Fly", Use = "Flight", When = "foeFlies"},
   {Id = "Absorb", P = 2, Type = "Zone", Use = "Skill3", Max = 9},
   {Id = "SunCombo", P = 2, Type = "Combo", Chain = {"Light", "Light", "Light", "Heavy"}, Max = 7},
   {Id = "Hammer", P = 2, Type = "Ranged", Use = "Heavy", Min = 8, Max = 28},
   {Id = "PounceIn", P = 3, Type = "GapClose", Use = "Skill2", Min = 10, Max = 24},
   {Id = "FlyKited", P = 3, Type = "Fly", Use = "Flight", When = "kited"},
   {Id = "StepOut", P = 2, Type = "Evade", Bonus = 40},
   {Id = "BaitSpam", P = 2, Type = "Bait", Bonus = 60},
  }},
  Wraithstep = {Ideal = 4, Min = 2, Reserve = "Skill1", Tactics = {
   {Id = "Trinket", P = 1, Type = "StunBreak", Use = "Defensive"},
   {Id = "VanishStep", P = 1, Type = "Defend", Use = "Defensive", Lead = 16, Heavy = true},
   {Id = "VanishLow", P = 1, Type = "Escape", Use = "Defensive", Max = 10},
   {Id = "GrappleAir", P = 1, Type = "AntiAir", Use = "Skill1", Max = 60},
   {Id = "ScythePunish", P = 1, Type = "Punish", Use = "Heavy", Max = 8},
   {Id = "SlashPunish", P = 1, Type = "Punish", Use = "Light", Max = 7, Bonus = -10},
   {Id = "CircleHeld", P = 2, Type = "Zone", Use = "Skill3", Max = 8, Held = true, Bonus = 30},
   {Id = "ShadeCombo", P = 2, Type = "Combo", Chain = {"Light", "Light", "Light", "Heavy"}, Max = 7},
   {Id = "ShadeBolts", P = 2, Type = "Ranged", Use = "Light", Min = 6, Max = 38, Phased = true},
   {Id = "GrappleKite", P = 2, Type = "Ranged", Use = "Skill1", Min = 14, Max = 60},
   {Id = "PhaseRange", P = 3, Type = "Phase", Use = "Skill2", Min = 12},
   {Id = "StepOut", P = 2, Type = "Evade", Bonus = 40},
   {Id = "BaitSpam", P = 2, Type = "Bait", Bonus = 60},
  }},
 },
}
-- R66-ui10 climbing (Peter, 2026-10-12: "make sure Bulwark's jump is increased so he can get up the steps; Wraith
-- has spider climb, it comes up but he doesn't have to press the button; Bulwark climbs up if he is short in his
-- jump; the pyramid walls are high and give flyers too much advantage"). The centre pyramid's tiers are 3.8 studs
-- high with 1.7-stud ledges; its stairs are 0.8 studs a step. Used by ReplicatedStorage.HeroWars.Climb.
-- JumpPower: 45 jumps about 5.2 studs; 55 about 7.7 (enough for a tier with room to spare).
Rules.Characters.Bulwark.JumpPower = 55
Rules.Climb = {
 Default = {},                                        -- other heroes: bots still jump walls they can get over
 Bulwark = {Mantle = 3.5},                            -- in the air at a ledge up to 3.5 studs above his feet: pulls up
 Wraithstep = {Wall = true, Speed = 14, Mantle = 4},  -- spider climb: walking into a wall climbs it, no button
}
function Rules.canInterrupt(move,cast,frame,damage,result)
 return move.Interrupt==true and damage>0 and result~="Block" and cast~=nil
  and cast.Cast==true and frame>=0 and frame<=cast.Startup
end
return Rules
