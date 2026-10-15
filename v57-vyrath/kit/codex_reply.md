Review complete. **Vyrath needs a separate custom creature rig and raid encounter system.** HeroWars provides useful combat infrastructure and asset utilities, but its current R15 pipeline and single sparring bot cannot directly support this boss.

No files were modified. I did not open Studio or Blender, call Tripo, spend credits, or upload anything. This is a static content/code review; animation, deformation and performance gates remain untested.

**Design and six milestones**

The :codex-file-citation{path="/Users/peteralleyne/Documents/Claude/HeroWars/codex_vyrath_dragon_kit/Hero_Wars_Rig_Motion_Production_Bible.docx" purpose="source"} describes an original, colossal storm dragon with four grounded legs, two independent wings, a barrel torso, a charging throat pouch, and a long counterbalancing tail. Its movement should communicate weight through anticipation, planted contacts, gradual turning and impact recovery.

The rig requires separate foreleg and hindleg chains; independent wing shoulders, spars, forearms and four membrane digits per wing; at least six neck segments; a jaw hinge; 10–16 tail controls; chest/pelvis controls; four paw IK targets; and combat sockets. The four pilot actions are grounded lightning breath, heavy takeoff, staged landing and a propagating tail sweep.

The [pilot prompt](/Users/peteralleyne/Documents/Claude/HeroWars/codex_vyrath_dragon_kit/Dragon_Boss_Pilot_Prompt.txt) divides delivery into:

| Milestone | Intended result |
|---|---|
| 1 | Audit the project and approve the design, storyboards and rig/test specifications. |
| 2 | Build a greybox custom rig with idle, walk and turn. |
| 3 | Test breath, tail sweep, takeoff and landing animations. |
| 4 | Implement authoritative attack volumes and a four-slot party with bot filling. |
| 5 | Test solo entry and mixed human/bot parties through four humans. |
| 6 | Profile Roblox desktop and mobile performance. |

The intended encounter has four party slots, 1–4 humans, bots filling vacancies, player-selected composition and provisional boss HP of 1,600–2,400.

**Diagnostic audit**

I inspected the embedded scripts in [V56](/Users/peteralleyne/Downloads/HeroWars_V56_BlenderMoves.rbxlx). Line references below refer to each embedded script’s source.

| Area | Reusable | What needs replacement or extension |
|---|---|---|
| Mesh tooling | General glTF reading, transforms, preview rendering and FBX parsing are useful foundations. | The hero builders, R15 verifier and humanoid partitioning are unsuitable as dragon builders. A custom hierarchy needs its own validation. |
| Existing rigs | Humanoid rigs remain useful for party members and scale references. | No validated dragon base was established. Enlarging Titan or adding wings to an R15 body does not satisfy the specified anatomy. |
| Animation data | Compact numeric packing, quaternion sampling and caching patterns can be reused. | Current capture hierarchy, root translation and animation loading assume a humanoid. |
| Combat | Server attack timing, cooldowns, queued contacts, oriented-box overlap and rewind history provide useful infrastructure. | Dragon hurt regions, sweeping breath, moving tail volumes, weakpoints and boss-specific reactions need dedicated handling. |
| Bots and parties | Hero ability selection, reaction delays and defensive decisions offer reusable pieces. | Four-slot membership, allied bots, hazard avoidance, cooperation and recovery navigation are new work. |
| Tripo | Existing exports and the documented candidate-review workflow provide experience. | The proven converter explicitly handles a biped. Dragon auto-rig/export support has not been verified. |

The main technical constraints are:

- **MocapData is structurally R15-specific.** Its header defines one loop flag, one `Hit` keyframe index and a frame count. Each frame stores time, root height and rotations for 15 joints. `HeroWarsClient` lines 1127–1152 hardcode their parent hierarchy and apply root height to `LowerTorso`. Lines 1074–1076 require a `Humanoid` to obtain an animator. Adding dragon joint names alone would not work. A separate, versioned creature format should support its hierarchy and multiple events/contact intervals; root movement also needs an explicit contract.
- **The current hitbox system describes humanoid bodies.** `Main.hurtboxFor`, `limbFor` and `recordHurtbox` around lines 739–767 record one body box and an optional forward attack-limb box. These cannot represent a long neck, tail, wings and independently exposed weakpoints accurately.
- **Existing sight checks are insufficient for sweeping breath.** `clearSight` at lines 589–594 casts from attacker root to target root. That is reusable for simple targeting, but breath needs obstruction checks from its muzzle across the actual damaging sector. The existing `WhirlSplash` branch at lines 1177–1182 also applies secondary contacts by distance without its own sight check; it should not become the breath implementation unchanged.
- **Bots are currently duel opponents.** `botThink` only runs during `D.of.Bot`’s fight phase and selects living `Player` states as enemies. Movement is direct pursuit/retreat, not recoverable pathfinding. The spawning code removes previous dummy bots, while `stateOf`/`keyOf` collapse the sparring bot to `"Bot"`.
- **There is no raid team relationship here.** `foe` at lines 1460–1463 isolates duel participants and otherwise returns true. Allied humans and party bots need encounter/team filtering. Automatic pairing of two humans into a duel must also be bypassed in raid mode.
- **Boss movement and reactions need separate rules.** Current health/alive checks, ground height, targeting and several attack conditions depend on `Humanoid`, `HumanoidRootPart`, `HipHeight` and `FloorMaterial`. Existing throws, teleports, stuns and knockdowns need a boss eligibility policy rather than being inherited automatically.

The [Tripo converter](/Users/peteralleyne/Documents/Claude/HeroWars/rigging-src/tools/tripo_to_kit.py:1) merges biped twist, finger and facial bones into a humanoid mapping. It asserts expected bone names and orientation. It would reject an unfamiliar dragon skeleton, and its reduction strategy would discard anatomy Vyrath needs.

The [existing boss plan](/Users/peteralleyne/Documents/Claude/HeroWars/rigging-src/VILLAINS_BOSSES_PLAN.md) already identifies dragons as a separate custom-rig job. Its recorded Tripo costs and successful humanoid exports are historical evidence, not verified dragon capabilities or current pricing.

The [rig history](/Users/peteralleyne/Documents/Claude/HeroWars/rigging-src/QUATERNIUS_RIGS.md) documents a working Blender capture bridge and later Blender work, superseding the older handover’s “no Blender” statement. It also records the client’s 200-local constraint: new client state should stay under `Sig` or an appropriate module.

**Gaps and contradictions to resolve**

1. **HP differs from the live baseline.** The prompt and bible agree on dragon HP. However, the bible proposes heroes at 120–180 HP, while V56 resolves to Solarion 115, Wraithstep 100, Tempest 105 and Bulwark 135. Boss HP should be tested against actual party damage, survivability and a target encounter duration.

2. **Party size is consistent for Vyrath, but composition is underspecified.** Both sources specify four slots. The bible’s two-player Titan and six-player Hive are separate encounters. “Balanced frontline/support/control” does not define a four-seat lineup, and the proposed roster’s healer is not a current playable hero.

3. **The full move list is unresolved.** The catalogue names an aerial dive and “Crownfall Tempest”; the pilot covers four component actions without a dive. Decide whether those catalogue moves are deferred or required.

4. **Four six-panel boards are required.** The bible supplies a breath schematic and written beats for the others. That is not an approved four-action storyboard package. Its general production stages also request idle, gait and reaction boards, extending the pilot’s explicit four-action list.

5. **Controls and exported bones are conflated.** “Six neck segments,” “spine controllers,” wing fingers and tail controls need an explicit distinction between authoring controls, deform bones and runtime helpers. Finger segment counts, spine layout, naming, axes and pivot limits remain open.

6. **Acceptance criteria lack reproducible measurements.** “No skating,” “believable mass,” “recoverable pathfinding” and “validated mobile performance” need tolerances, scenarios and hardware targets. The 1–5 scorecard lacks scoring anchors and an assigned reviewer.

7. **The gate sequence needs clarification.** Gameplay and mobile gates cannot pass during milestone 1 or 2. Mark them *not yet tested*, and apply “stop on failure” to gates relevant to the current milestone.

8. **Test coverage is incomplete.** Add 3 humans + 1 bot, disconnect/replacement rules, wipe/reset, obstructed attacks, latency, stuck navigation, airborne transitions and repeated encounter cycles. Clarify whether “Play Solo” means the required 1+3 party or a separate development harness.

9. **Read-only constraints prevent capability verification now.** Account-specific Tripo support, imported hierarchy, deformation and performance remain unknown. No outside schematic is part of this kit; Vyrath's design authority is the approved original silhouettes.

**Ordered plan and required approvals**

These are future steps; this review does not authorize asset creation or implementation.

1. **Resolve the encounter brief.** Approve four total party slots, legal heroes and default lineup; provisional HP and target fight duration; friendly-fire policy; boss control immunities; and whether dive/Crownfall are deferred.

2. **Prepare the silhouette package.** Front and side views must show a player scale marker, overall dimensions, four legs, independent wings, folded clearance, tail footprint and throat/wing-root weakpoints.  
   **Peter’s approval:** originality, proportions, scale, silhouette and weakpoint placement.

3. **Prepare four six-panel storyboards—24 panels total.** Each action needs timings, planted contacts, warning/active/recovery phases, interrupt windows, hazard volumes and events. Include the required neutral, crouched, folded, spread, flight and landing poses.  
   **Peter’s approval:** all four action sequences, warning readability, timing and counterplay.

4. **Specify the hierarchy and pivots.** Separate exported deform bones from IK/control helpers; identify axes, limits, bind pose, sockets and root-motion ownership.  
   **Peter’s approval:** the complete bone hierarchy and pivot placement, including independent wings and four paw targets.

5. **Specify deformation/contact tests.** Cover shoulder and wing-root clearance, neck sweep, hip compression, membrane folding/stretch, tail propagation and planted paws. Define measurable contact tolerances, turn limits and milestone-specific scorecard gates.  
   **Peter’s approval:** the deformation/contact test plan and its pass thresholds.

6. **Authorize milestone 2 separately.** Once those four design packages are approved, authorize creation of an isolated greybox workspace and custom rig. Tripo spending, Studio uploads and production changes would require their own explicit authorization if later needed.

7. **Execute milestone 2 in that isolated workspace.** Build the simplest weighted mesh that can expose deformation problems, validate all required poses, then create idle, straight walk, start/stop and gradual turns. Record contacts, speed, timing, defects and hierarchy. A rigid block assembly alone cannot validate membrane or shoulder deformation.

8. **Stop at the milestone 2 review.** Present the greybox and locomotion scorecard for Peter’s approval before signature-animation work. Roblox import and runtime gates remain pending until separately authorized.

The diagnostic review is complete. **The design packages and runtime gates are still pending; milestone 2 should begin only after the specified approvals.**