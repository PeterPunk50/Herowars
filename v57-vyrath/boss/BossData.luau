-- Vyrath, the Storm-Crowned Dragon: numbers the boss controller reads. Frames are at 24 fps in the Blender clips
-- (see codex_vyrath_dragon_kit/RIG_NOTES.md and vyrath_signature_events.json); seconds = frame/24.
-- Units: studs at the test-bed scale (Model:ScaleTo(0.35) on the 100-stud import, so 1 Blender unit = 35 studs).
local D = {}
D.FPS = 24
D.Scale = 35 -- studs per Blender unit at the current ScaleTo
-- Clip names as the Studio import stored them (ServerStorage.RBX_ANIMSAVES.Vyrath_all2["Armature|<name>"]).
D.Clips = {"Idle","Idle_LookAround","Idle_PawShift","Idle_PawStomp","Idle_Snort","Idle_TailSwish","Idle_WingStretch","Walk","Charge_Run",
 "Turn_Left90","Roar","Hit_Flinch","Stagger_WeakpointBreak","Death","Sig_ThunderBreath","Sig_TailSweep","Sig_Takeoff","Flight_Hover","Sig_Landing"}
-- Published AnimationIds go here once the clips are uploaded; empty = register the KeyframeSequences in Studio.
D.AnimationIds = {}
D.Frames = { -- length in frames; loops
 Idle={96,true}, Idle_LookAround={192,false}, Idle_PawShift={96,false}, Idle_PawStomp={96,false}, Idle_Snort={96,false}, Idle_TailSwish={96,false}, Idle_WingStretch={192,false},
 Walk={48,true}, Charge_Run={24,true}, Turn_Left90={84,false}, Roar={96,false}, Hit_Flinch={36,false}, Stagger_WeakpointBreak={144,false}, Death={144,false},
 Sig_ThunderBreath={168,false}, Sig_TailSweep={108,false}, Sig_Takeoff={108,false}, Flight_Hover={48,true}, Sig_Landing={120,false},
}
-- Event frames (from the Blender markers).
D.Breath = {WarningStart=26, ActiveStart=56, ActiveEnd=100, ExposedStart=108, ExposedEnd=148, Cancelable=55,
 HalfAngle=14, Range=0.85*35, DamagePerTick=9, TickSeconds=0.2, Cooldown=9}
D.TailSweep = {ContactStart=50, ContactEnd=60, Cancelable=40, VulnerableStart=71, VulnerableEnd=94, Damage=22, Radius=0.05*35, Push=40, Cooldown=6, Reach=14}
D.Roar = {Committed=30, Cooldown=20}
D.Stagger = {ExposedStart=26, ExposedEnd=110}
D.Turn = {Degrees=90, Frames=84}
-- Ground speeds of the in-place loops (Blender units per second times scale).
D.Speed = {Walk=0.0933*35, Charge_Run=0.36*35}
D.TurnRate = {Idle=40, Walk=60, Charge_Run=35} -- degrees per second the body may yaw while in that state (no snap turns)
D.Move = {ChargeMinDist=30, WalkMinDist=16, StopDist=18}
-- Hit points and weak points. Weak points are the socket bones; a hit within Radius studs of one counts for it.
D.HP = 2000
D.WeakPoints = {
 Throat={bone="Socket_Weak_Throat", Radius=3.5, Mult=3.0, Break=260},
 Crown={bone="Socket_Weak_Crown", Radius=3.0, Mult=2.0, Break=320},
 WingRootL={bone="Socket_Weak_WingRoot_L", Radius=3.0, Mult=2.0, Break=320},
 WingRootR={bone="Socket_Weak_WingRoot_R", Radius=3.0, Mult=2.0, Break=320},
}
D.ExposedMult = 2.0 -- extra on the throat while the breath's exposed window or a stagger runs
D.FlinchDamage = 40 -- a single hit this big makes it flinch (only while idle or walking)
D.FlinchCooldown = 4
D.Aggro = 220 -- studs; targets farther away are ignored (the HeroWars arena is 180 across)
return D
