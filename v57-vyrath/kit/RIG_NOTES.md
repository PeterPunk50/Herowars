# Vyrath: Tripo model and rig (2026-10-15)

Peter said to start the rig with Tripo3D, ahead of the design approvals the pilot prompt asks for. This is a first attempt to test what Tripo can do, not an approved design.

## What was made

| Item | Value |
|---|---|
| Prompt | Original four-legged, two-winged storm dragon boss: neutral standing pose, legs planted, wings half-open and symmetrical, long neck and tail, slate-blue scales, blue crystal horns. No franchise names. |
| Tripo project | `8f830b2a-11dd-400c-94de-d9e3b1fe9969` ("blue dragon 3d model"), visibility private, model v3.1, 16k face limit, PBR |
| Model | `~/Documents/Claude/tripo/out/vyrath/vyrath_gen.glb`: 15,292 triangles, 2048px normal, base colour and metal-rough maps, 0.89 x 0.73 x 1.0 units |
| Rig | `~/Documents/Claude/tripo/out/vyrath/vyrath_quad_rig.glb`: `tripo process rig --rig-type quadruped`, 52 joints, one skin, weights sum to 1 on all 10,574 vertices |
| Credits | 3,040 to 2,990 (50 spent: 30 generate, 20 rig). Pre-rig check, exports and the dry runs were free. |
| Previews | `vyrath_preview_front.png`, `vyrath_preview_three_quarter.png` in this folder |

## What the rig has

- Root, 2 spine bones (`Spine_0`, `Spine_1`), a 2-bone pelvis chain (`bone_1`, `bone_2`), a 5-bone tail (`Tail_0` to `Tail_4`), and a 7-bone neck and head chain (`bone_10`, `bone_11`, `Head_0` to `Head_4`). Which of those are neck and which are head is not labelled.
- Two front legs (`0_Left_Limb`, `0_Right_Limb`, 4 to 5 bones each).
- Two wings as bone chains: one side is a single 6-bone chain (`bone_20` to `bone_25`), the other has a 6-bone chain with three finger branches (`bone_32` to `bone_41`).

## Problems found (read-only check, no visual deformation test yet)

1. **Wings are not symmetrical.** One wing has finger branches and the other does not. Both are needed for the spec (independent shoulder, spar, forearm and four digits per wing).
2. **Hind legs are short.** `1_Left_Limb` has only 2 bones and the other hind leg is 2 unnamed bones (`bone_48`, `bone_49`). A walk needs hip, knee and ankle at least.
3. **Tail has 5 bones; the spec asks for 10 to 16 controls.** The neck and head chain has 7 bones in total, so the 6+ neck joints need checking once the chain is labelled.
4. **No confirmed jaw hinge, weak-point sockets, breath socket or paw IK targets.** They would be added in Blender.
5. **Which chain is which wing is inferred** from where each bone's vertices sit (one side at negative Z, the other at positive Z), not from a visual check.
6. **Tripo's pre-rig check classed the model as `avian`**, not quadruped. I rigged it as quadruped as asked; an avian rig was not tried.
7. **Bone names are mostly `bone_N`**, and the rig is oriented with the head along +X and the wingspan along Z. Both need cleaning before any Roblox import.
8. **No animation clips came with the export** (`anims: 0`).

## Blender pose test (2026-10-15)

Rig imported into Blender 5.2 (`~/Documents/Claude/tripo/out/vyrath/vyrath_pose_test.blend`, script `vyrath_pose_test.py`). Z is up, the head points along +X and the wings spread along Y. Each pose rotates real bones and compares every mesh edge with its rest length (a "bad" edge is stretched over 1.5x or squeezed under 0.5x; the mesh has about 31,000 edges). Sheets: `pose_test_wings.png`, `pose_test_hips.png`, `pose_test_neck.png`.

| Pose | Result | Worst edge stretch / bad edges |
|---|---|---|
| Wings up 55 degrees | Both wings lift and the membrane follows. Small pinch at the wing roots. | 2.06x / 13 |
| Wings down 35 degrees | Clean. | 1.41x / 0 |
| Wings forward 30 degrees | Clean. | 1.61x / 1 |
| Wings folded 70 degrees | Both fold back, but the membranes lie across the body and tail base, and the two wings fold into different shapes. Pinching at the shoulders. | 2.58x / 58 |
| Hips yaw 25 degrees | Pelvis and tail swing cleanly. **Hind legs do not move.** | 1.31x / 0 |
| Hips pitch 20 degrees | Tail raises and lowers cleanly, hind legs stay put. | 1.66x / 3 |
| Neck bent down 40 degrees (spread over 5 bones) | Neck curves smoothly. **Belly and hind-leg area also distort** (bad edges sit at the belly, not the neck). | 1.99x / 16 |
| Neck up 25 degrees | Acceptable. | 1.60x / 12 |
| Neck sideways 35 degrees | Acceptable. | 1.49x / 0 |

What the test showed about the skeleton:

- **Wings and front legs hang off the neck base.** `bone_18` to `bone_43` (both wings, both front legs) are children of `bone_10`, so bending the neck at its base drags the shoulders and wings with it. They should hang off the chest or spine.
- **Hind legs hang off the root, not the pelvis.** A hip rotation leaves them behind. That is fine for planted feet only if IK is added.
- **Wing roots pinch** when the wings go past about 50 degrees up or 70 degrees folded, so those weights need smoothing before wing beats are animated.
- **Neck bones carry weights into the belly.** That is where the bent-neck distortion comes from.
- Wing and hip rotations alone are usable as a first pass. Walking, wing beats and folding are not yet.

## Skeleton fix pass (2026-10-15, Peter asked for it)

Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_quad_rig_fixed.glb` (4.4 MB, 56 joints, one skin), `vyrath_rig_fixed.blend`, `vyrath_before_fix.blend` (the untouched import), and the scripts `vyrath_fix_lib.py` and `vyrath_fix_run.py` that redo the fix from the before-file. Sheets: `pose_test_fixed_wings.png`, `pose_test_fixed_hips_neck.png`.

What changed:

1. **Wings and front legs now hang off the chest** (`tripo::Spine_1`): both wing shoulders, both front-leg roots (`bone_26`, `bone_42`) and the two small chest bones (`bone_18`, `bone_19`). Bending the neck no longer moves them (wing movement 0.032 to 0, front-leg movement 0.023 to 0, in model units).
2. **Hind legs now hang off the pelvis** (`bone_1`, renamed `Pelvis`): `bone_48`, `bone_49` and `tripo::1_Left_Limb_0`. A hip rotation now carries the hind legs with it (hind-leg movement 0.001 to 0.035).
3. **Wing bones mirrored.** The left wing now has the same second and third digit chains as the right (`Wing_L_D2_0`, `D2_1`, `D3_0`, `D3_1`, mirrored from the right bones). The left wing mesh matches a mirror of the right to within 4 mm on average (worst 2 cm), so the right wing's weights were copied across. Wing bones are renamed `Wing_L_` / `Wing_R_` (`Shoulder`, `Arm`, `Forearm`, `D1_0` to `D1_2`, `D2_0` to `D2_1`, `D3_0` to `D3_1`). The right forearm bone was lengthened to reach its digit, as on the left.
4. **Shoulder weights smoothed** (3 passes, radius 0.13 around both shoulders), and the hip junction lightly smoothed (6 passes). The mesh has duplicate vertices at texture seams; smoothing was done on merged positions so no cracks open. Influences are capped at 4 per vertex.
5. **Extra fix found on the way:** Tripo had bound 159 vertices of the right hind foot to the right front leg's toe bone. Moving the hip showed it (62 stretched edges). They now follow the right hind-leg bone.

Pose results, before and after (stretched or squeezed edges outside 0.5x to 1.5x, out of about 31,000; worst stretch):

| Pose | Before | After |
|---|---|---|
| Wings up 55 degrees | 13 edges, 2.06x | 26 edges, 2.08x |
| Wings folded 70 degrees | 58 edges, 2.58x | 51 edges, 2.38x |
| Digit bones raised 25 degrees | right wing only, 11 edges, 1.63x | both wings, 34 edges, 2.43x |
| Neck bent down 40 degrees | 16 edges, 1.99x | 5 edges, 1.97x |
| Pelvis pitched 20 degrees | 3 edges (legs did not move) | 11 edges, 1.65x (legs follow) |
| Pelvis yawed 25 degrees | 0 edges (legs did not move) | 26 edges, 2.66x |

How to read that:

- Neck and pelvis pitch are clearly better. The neck no longer drags the wings, and the legs now follow the hips.
- **Wing roots are not better.** Smoothing barely changed the shoulder pinch (worst stretch still about 2.1x to 2.4x), and the left wing now carries the right wing's flaws. The wing bend is usable but needs hand weight painting at the shoulders before wing beats.
- The pelvis yaw number is a harsh test: the pelvis turns alone and the torso does not, so the join shears. In a real animation the spine bones follow. It was not re-tested with the spine following.
- Left digit rotation stretches more than the right (23 against 11 edges), because the left mesh is not an exact mirror.

Still wrong or untested:

- Hind legs still have only 2 bones each (no ankle or foot), and the right hind leg is a single bone running down the centre line. A walk cycle needs real leg chains.
- Tail still has 5 bones and the neck/head chain 7, short of the spec (10 to 16 tail controls, 6+ neck joints).
- No jaw hinge, weak-point or breath sockets, or paw IK targets.
- Front legs were not posed (no step test), and nothing was tested in Roblox.

## Legs, tail, neck, sockets and paw IK (v3, 2026-10-15, Peter asked for it)

This pass supersedes the "still wrong" list above for the hind legs, tail, neck, jaw, sockets and IK. Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_quad_rig_v3.glb` (4.5 MB, 78 joints), `vyrath_rig_v3.blend` (same rig plus the IK and copy-rotation constraints, which do not export to glTF), and the scripts `vyrath_rig_v3_build.py` and `vyrath_rig_v3_render.py` (they start from `vyrath_rig_fixed.blend`). Sheets: `pose_test_v3_chains.png`, `pose_test_v3_legs.png`, `rig_v3_hind_leg_bones.png`.

| Spec item | Now |
|---|---|
| Hind legs: hip, knee, ankle, foot | 4 bones per leg: `HindLeg_L_Hip`, `_Knee`, `_Ankle`, `_Foot` (and `_R_`), hung from `Pelvis`. Joints placed on the mesh: hip (0.13, 0.058, 0.235), knee (0.16, 0.064, 0.145), ankle (0.07, 0.072, 0.125), ball of foot (0.072, 0.080, 0.028), toe (0.128, 0.093, 0.008); the right leg mirrors the left. They replace the old 2-bone legs. |
| Tail 10 to 16 controls | 12 bones, `Tail_01` to `Tail_12`, spaced evenly along the old tail's curve (they replace `bone_2` and `Tail_0` to `Tail_4`). |
| Neck 6+ joints | 8 bones, `Neck_01` to `Neck_08`, from the chest to the skull (they replace 5). `Head` is the skull base. |
| Jaw hinge | `Jaw` (was `Head_4`). Opening it moves 95 vertices, all in the lower jaw. 11 stray vertices on the right hind shin had 5 to 7 percent Jaw weight from Tripo; that was removed. |
| Breath and weak-point sockets | Non-deforming bones: `Socket_Breath` (front of the mouth, points forward), `Socket_Weak_Throat` (front of the neck, on `Neck_04`), `Socket_Weak_Crown` (top of the head), `Socket_Weak_WingRoot_L` and `_R` (on the wing shoulders). |
| Paw IK targets | `IK_Paw_HL`, `IK_Paw_HR`, `IK_Paw_FL`, `IK_Paw_FR`, children of `tripo::Root`. Each drives a 3-bone IK chain in Blender and makes the first paw bone copy its rotation. The hind targets sit at the ball of the foot (0.028 high), the front targets at the wrist (about 0.05 high), not on the ground. |

How the weights were moved: the old neck, tail and hind-leg weights were redistributed onto the new bones by position (distance along the curve for the tail and neck, distance to the bone segment for the legs). Each vertex keeps the same total weight on that group, so the blend into the torso is unchanged. Duplicate vertices at texture seams get identical weights, and influences are capped at 4. The rest pose did not move (largest vertex change 0.0).

Pose tests (same method as before; "bad" means an edge stretched past 1.5x or squeezed under 0.5x, out of about 31,000):

| Pose | Before | After |
|---|---|---|
| Tail curled sideways 72 degrees | 1.26x, 0 bad | 1.11x, 0 bad |
| Tail curled down 60 degrees (the test rotates the tail bones about Y; this direction lowers the tail, not raises it) | not run | 1.14x, 0 bad |
| Neck bent down 40 degrees | 1.97x, 5 bad | 1.99x, 8 bad |
| Neck bent sideways 35 degrees | 1.36x, 0 bad | 1.71x, 3 bad |
| Jaw open 25 degrees | 1.74x, 4 bad (109 vertices moved) | 1.53x, 1 bad (95 vertices) |
| Hind paw lifted 6 cm with IK | not possible | 1.85x, 13 bad |
| Hind paw pulled back 4 cm and up 3 cm with IK | not possible | 1.87x, 6 bad |
| Front paw lifted 6 cm with IK | not possible | 1.93x, 11 bad |
| Hind legs flexed by hand (IK off) | not possible | 1.76x, 16 bad |

How to read that:

- Tail and jaw are clearly better. IK works: the foot follows its target and the leg bends at the knee.
- **The neck is slightly worse than before** (8 bad edges against 5, and 3 against 0 sideways), even with softer blending. The extra bones did not help; the shoulders and neck base still need hand weights.
- The hind-leg hip position was chosen by trying three spots (hip 15, 13 and 11.5 cm forward); the differences were small, and the middle one had the fewest bad edges overall.
- The leg numbers come from large test moves. Walking with small steps should look cleaner, but no walk has been tested.

Still short of the spec or untested:

- **Wings have 3 digits per wing, the spec says 4.** Wing-root pinching is not fixed (see the fix pass above).
- Paw targets are not on the ground and there are no pole targets (the knee and elbow bend direction comes from the rest pose). IK and copy-rotation constraints exist only in the `.blend`; the glTF has the target bones but no constraints, so any animation has to be baked before it leaves Blender.
- The leg, socket and crown positions are estimates from the mesh outline. Where each weak point sits is a design decision for Peter's approval (silhouette and weak-point placement), not something settled here.
- The spine is still two bones, there are no toe-level bones, and the tail and neck bones are not named by anatomy.
- Nothing has been walked, animated or imported into Roblox.

## Fourth wing digit, wing-root and neck-base weights (v4, 2026-10-15, Peter asked for it)

Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_quad_rig_v4.glb` (4.5 MB, 82 joints), `vyrath_rig_v4.blend` (keeps the IK constraints), and the scripts `vyrath_rig_v4_build.py` and `vyrath_rig_v4_render.py` (they start from `vyrath_rig_v3.blend`). Sheets: `pose_test_v4_wing_digits.png`, `pose_test_v4_neck_base.png`, `rig_v4_wing_bones.png`.

What changed:

1. **Fourth digit per wing:** `Wing_L_D4_0`, `Wing_L_D4_1`, `Wing_R_D4_0`, `Wing_R_D4_1`, children of each forearm. It follows the fourth lobe of the membrane. Measured from the mesh outline, the trailing edge has four lobe tips (about 0.52/0.71, 0.5/0.55, 0.385/0.372 and 0.225/0.346 along the span and height on the right wing), and the new spar runs from the wrist (0.195, 0.2, 0.475) down to the inner tip at (0.115, 0.225, 0.346). It takes weight only from the forearm and the other digit bones, never from the shoulder or arm. Spreading and folding it moves only that lobe.
2. **Neck-base weights:** a small central patch of the neck base (radius 0.06, away from the wing roots) was refilled by smoothing it fully from its surroundings. It was flipping between `Neck_01` and `Neck_03`, which caused all the neck bend problems.
3. **Wing-root weights:** the whole wing membrane, both armpits and the neck base were run through a weight optimiser that tries to keep every mesh edge at its rest length across 17 poses (wing up, down, fold, forward, elbow, arm, digit fans, neck, front paw, and combinations). A dozen check poses it never saw (marked "check pose" below) measure how it generalises. Influences stay at 4 per vertex.

Results (an edge counts as "bad" if stretched past 1.5x or squeezed under 0.5x, out of about 31,000; the last column is the single worst edge length change, in thousandths of the model's 1.0 wingspan, so roughly millimetres on a 1 m dragon):

| Pose | Before (v3) | After (v4) | Worst edge change |
|---|---|---|---|
| Neck bent down 40 degrees | 8 bad, 1.99x | 0 bad, 1.27x | 8.4 to 5.0 |
| Neck bent sideways 35 degrees | 3 bad, 1.71x | 0 bad, 1.20x | 6.2 to 3.8 |
| Neck down 25 degrees (check pose) | 3 bad | 0 bad | 5.1 to 3.1 |
| Wings up 55 degrees | 27 bad, 2.08x | 24 bad, 1.97x | 6.8 to 6.6 |
| Wings up 45 degrees (check pose) | 12 bad | 8 bad | 5.8 to 5.6 |
| Wings folded 70 degrees | 52 bad, 2.38x | 52 bad, 2.28x | 11.9 to 11.7 |
| Wings folded 50 degrees (check pose) | 20 bad | 17 bad | 8.0 to 7.9 |
| Fold 60 degrees plus elbow 20 (check pose) | 38 bad | 31 bad | 10.0 to 9.8 |
| Wings up 55 plus neck down | 34 bad | 23 bad | 8.4 to 6.6 |
| Digits D1 to D3 fanned a little | 2 bad, 1.71x | 12 bad, 2.01x | 8.5 to 14.3 |
| D2 swung 25 degrees (check pose) | 34 bad, 2.43x | 58 bad, 2.72x | 13.5 to 23.7 |
| New D4 swung 25 degrees (check pose) | none | 27 bad, 2.23x | 18.9 |
| All four digits fanned 8 degrees | none | 0 bad, 1.39x | 4.0 |

How to read that:

- **The neck base is fixed.** Neck bends are now clean (worst edge change down to 5 mm).
- **The wing root is not meaningfully better, and it cannot be fixed with weights.** The optimiser only improved the bad-edge count by a few, and the worst edge change at 55 degrees is still about 6.6 on a 1000-wide wing (0.7 percent of the span), 11.7 at a 70-degree fold. The root edges are only 5 to 9 thousandths long, so a few thousandths of stretch count as "bad" by ratio but is tiny in absolute terms. Getting it lower needs mesh changes at the armpit (more edge loops there), not more weight work.
- **Adding D4 cost something.** It took part of the lowest lobe from the D2 spar, so swinging D2 on its own by 25 degrees now stretches more (23.7 against 13.5), and a small three-digit fan stretches more (14.3 against 8.5). A normal four-digit fan is clean (4.0). Judge it on real wing animation, not on isolated 25-degree digit swings.
- Small regressions elsewhere: elbow 25 degrees 2 to 3 bad edges, front paw IK lift 11 to 13.

Still short or untested:

- **D4 and the other digits are placed from the mesh outline.** The D2 spar still ends at the wrong height compared with its lobe tip (its bone stops about 9 cm above the lobe tip). It was not moved.
- Wing-root and fold stretch remain (see above); the left wing still carries a copy of the right wing's weights.
- Spine, weak-point placement, paw-IK pole targets, and everything from the earlier "still short" list are unchanged. Nothing has been walked, animated or imported into Roblox.

## Walk cycle and foot-skating check (2026-10-15, Peter asked for it)

Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_walk_v4.blend` (the keyed walk with the IK still live), `vyrath_walk_v4.glb` (4.6 MB, the same walk baked into plain bone keys; the one `Walk` animation, 49 frames over 2.0 s, 83 animated joints) and the script `vyrath_walk_v4_build.py` (starts from `vyrath_rig_v4.blend`). In this folder: `walk_cycle_frames.png` (8 frames of the cycle) and `walk_foot_plot.png` (where each planted foot sits on the ground over two cycles).

The cycle: a looping 48-frame walk at 24 frames per second, in place (the body stays put and the ground slides back at 0.0933 units per second, which is exactly the speed that keeps a planted paw still on the ground). Footfall order is hind left, front left, hind right, front right (a normal four-legged walk), each paw planted for 75 percent of the cycle, with a stride of 0.14 (the paw travels back 0.14 while planted). Swing lifts are 5 cm (hind) and 3 cm (front). The body is lowered 0.02 and bobs 0.006 twice per cycle, the pelvis yaws 4 degrees, the spine counter-rotates, a wave runs down the tail (tail lifted 2 degrees per bone so the tip clears the ground), and the neck counter-sways. Wings stay in the rest pose, spread; they were not folded for the walk.

Setup changes: a new top bone `Ground` is now the parent of `tripo::Root` and the four `IK_Paw_*` targets, so the targets stay on the ground while `Root` moves the body (the targets used to hang off `Root`). The skeleton is now 83 joints. The dorsal and belly midline above the hips was re-blended (440 vertices) because the two thigh bones pulled it apart as the legs swung in opposite phases. That weight change exists only in `vyrath_walk_v4.blend` and the walk glb; `vyrath_quad_rig_v4.glb` does not have it.

Foot skating, measured over every planted stretch of the cycle (distances in model units; the stride is 0.14, so 1 unit of 1000 is about 0.7 percent of a stride):

| Paw | IK target | Ankle or wrist joint | Lowest mesh vertex of the foot (slide, height change) |
|---|---|---|---|
| Hind left | 0.0 | 0.0 | 6.3, 4.6 |
| Hind right | 0.0 | 0.0 | 10.8, 4.5 |
| Front left | 0.0 | 0.0 | 3.7, 0.6 |
| Front right | 0.0 | 0.0 | 0.0, 0.0 |

(The last column is thousandths of a unit.)

What that means:

- **The paws do not skate.** The IK targets, and the joints the legs actually reach, stay put to the last digit while planted, and the legs reached their targets in every frame (largest miss 0.00002), so no leg over-extends or lifts early.
- **The visible foot slips a little.** The lowest vertex of each foot slides 4 to 11 thousandths during the plant (3 to 8 percent of a stride) and rises up to 4.6 thousandths. That comes from the foot mesh not moving rigidly with the ankle (heel and toe weights blend with the metatarsus bone, which turns as the leg bends). It would show as a slight heel creep, mostly on the hind feet, and is not a skate in the sense of a sliding foot.
- **No knee flips.** Hind knees bow forward and front elbows bow back in every frame (bend offsets stay 0.05 to 0.09 and -0.05 to -0.02).
- **Ground contact.** Lowest foot vertex 0.0, body -0.0007, tail 0.034 clear. Nothing sinks into the ground.
- **Mesh during the walk.** Worst edge stretch over the cycle is 2.72x, at the belly midline between the thighs (an edge 15.6 thousandths long reaches 42.3, frame 13); the worst single frame (frame 31, the right front paw in mid-swing) has 46 stretched or squeezed edges out of about 31,000, mostly in the right shoulder and chest area. Before the setting tweaks and the hip fix the same cycle had 93 in its worst frame. This is an average-looking result, not a clean one.

How the numbers were checked: the baked animation reproduces the live IK exactly (largest joint difference 0.000000 over the cycle), and the exported glb was read back directly (49 keys per animated channel, leg, tail, wing and target bones all animated). Importing that glb back into Blender could not be done in this scripted setup, but even the untouched Tripo glb fails to re-import the same way, so that is the setup, not this file.

Not done or not tested: no turn, start or stop, run, or idle; no wing flap or fold in the walk; no Roblox import (a Roblox boss would need a creature animation format, see `LATER.md`); the walk was judged in side-on renders, not played at speed; the paw targets are at the ankle or wrist, not on the ground, so a ground-height error in Roblox would show as hovering by about 3 to 5 hundredths.

## Idle (2026-10-15, Peter asked for it after seeing the walk)

Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_motion_v4.blend` (open this one: it holds both the `Walk` and the new `Idle` action, with `Idle` active; switch in the Action Editor or Dope Sheet), `vyrath_idle_v4.glb` (4.6 MB, the idle baked, one `Idle` animation) and the script `vyrath_idle_v4_build.py` (starts from `vyrath_walk_v4.blend`). In this folder: `idle_cycle_frames.png`.

The idle is a looping 96-frame standing animation at 24 frames per second (4 seconds, one breath per loop). All four paws stay planted at their rest positions. On top of that:

- **Breathing:** the chest rises and falls (spine pitches about 1 degree, the body bobs 0.004 up and down) and the wing shoulders lift and settle slightly.
- **Weight shift:** the pelvis slowly yaws and rolls (2 and 1.2 degrees).
- **Head:** the neck sways side to side (about 6 degrees across the whole neck) and nods a little, and the jaw opens a hair with the breath.
- **Tail:** a slow wave travels down the tail (about 2.4 degrees per bone), lifted 1.5 degrees per bone so the tip clears the ground.
- **Wing settle:** once per loop, between frames 56 and 78, both wings tuck in a few degrees and ease back.

Measured over the loop (distances in model units; the wingspan is 1.0):

| Check | Result |
|---|---|
| Paw IK targets and ankle or wrist joints | do not move at all (0.0) |
| Lowest mesh vertex of each foot | moves at most 0.0003 on the hind feet and 0.0 on the front feet, so no foot creep |
| Legs reaching their targets | all frames, largest miss 0.0; knees and elbows keep their bend direction |
| Loop seam | frame 97 equals frame 1 exactly (0.0 gap at head, tail, both wing tips and chest) |
| Mesh | worst edge stretch 1.49x and at most 2 stretched edges in any frame (the walk had 46) |
| Ground | feet exactly on it, body 0.0013 above, tail 0.029 clear |
| Size of the motion (peak to peak) | head tip about 0.02 to 0.03, wing tips 0.04 to 0.065, tail tip up to 0.136 sideways, chest about 0.005 to 0.013 |

It is deliberately small: the chest and head move a few hundredths of the body length, so on a still frame the contact sheet looks almost identical; it reads when played.

Not done or not tested: no head-turn toward a target, no idle variations (look around, paw lift, wing stretch), no snort or breath-in-rage; not judged at game speed; the front paw targets sit at the wrist, not the ground; nothing in Roblox.

## Idle variations (2026-10-15, Peter asked for them)

Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_motion_v4.blend` now holds `Walk`, `Idle` and the six variations below, plus a `Showcase` strip on the NLA track that plays them all in order with an idle between each (1,344 frames, 56 seconds; press Space). `vyrath_idle_variations_v4.glb` (5.5 MB) has `Idle` and the six variations as seven separate baked animations. `vyrath_idle_variation_events.json` lists the key frames of each. Script: `vyrath_idle_variations_v4_build.py` (starts from the motion blend). In this folder: `idle_variations_frames.png`.

Each variation is the idle plus one extra action, built so its first and last frame equal the idle's first frame. Every clip is a whole number of breaths, so any variation can be played straight after or before the idle, or looped, with no pop.

| Clip | Length | What happens | Key frames |
|---|---|---|---|
| `Idle_LookAround` | 192 (8 s) | Slow turn of the head and neck to the left (about 38 degrees across neck and head), a hold, a turn to the right with a slight look-down, back to centre; the spine counter-twists and the tail follows | left peak 58, right peak 122, centre 176 |
| `Idle_PawStomp` | 96 (4 s) | Front right paw lifts 3.5 cm and reaches 1.2 cm forward, then slams down in 7 frames; the body dips, the chest pitches, the tail jolts, the weight shifts left | lift starts 18, top 38, impact 49 |
| `Idle_PawShift` | 96 (4 s) | Body leans left, the pelvis rolls, and the hind right paw lifts 3 cm and sets back down | weight left 30, paw up 46, paw down 62 |
| `Idle_WingStretch` | 192 (8 s) | Both wings open to about 38 degrees up and forward with the forearms extended and digits fanned, a hold with a faint tremble, then fold back; deeper breath, head lifted a little | spreading 20, full spread 62, folding back 122, rest 170 |
| `Idle_Snort` | 96 (4 s) | Slow inhale (head back, chest up) then a sharp forward snort with the jaw opening 10 degrees and a tail kick, then settle | inhale 10 to 30, puff 40, settled 52 |
| `Idle_TailSwish` | 96 (4 s) | A broad wave sweeps down the tail (about 5.5 degrees per bone) with the neck following slightly | sweep 18 to 78 |

Checks, every clip over its full length:

| Check | Result |
|---|---|
| Loop seam (last frame against first) | exact, 0.0 for all six |
| First frame against the idle's first frame | exact, 0.0 for all six (so they join the idle with no pop) |
| Paws not involved in the move | do not move at all; the lifted paw ends back exactly where it started |
| Paw reach and bend direction | legs reach every target (largest miss 0.00001); no knee or elbow flips |
| Ground | feet exactly on it, tail at least 0.029 clear, body above it |
| Mesh, worst edge stretch and worst frame's stretched edges | look around 1.50x and 2; shift 1.48x and 5; snort 1.49x and 2; tail swish 1.49x and 2; wing stretch 1.82x and 17; paw stomp 1.97x and 34 |

The stomp is the roughest. Lifting the front right paw pulls on the right shoulder and chest (the same weak spot the walk showed); the first version lifted 5 cm and had 52 stretched edges, so it was lowered to 3.5 cm (34). The wing stretch peaks at 38 degrees, below where the earlier wing-root stretch gets bad.

The key frames are saved as markers on each action (they show in Blender's timeline) and in the events json; glTF does not carry markers. The snort's puff at frame 40 and the stomp's impact at frame 49 are where a game would spawn dust or breath effects.

Not done or not tested: the clips were judged from still frames and by playing in Blender, not at game speed; no blend or transition logic exists (they only join cleanly because they start and end on the idle pose); no sound cues; nothing in Roblox.

## The four signature actions (2026-10-15, Peter asked for them)

Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_motion_v4.blend` now also holds `Sig_ThunderBreath`, `Sig_TailSweep`, `Sig_Takeoff`, `Flight_Hover` and `Sig_Landing`, plus a `Signature` NLA strip that plays idle, breath, idle, tail sweep, idle, takeoff, two hover loops, landing, idle (984 frames, 41 seconds; the `Showcase` strip from the idle variations is muted underneath, unmute one or the other). `vyrath_signature_actions_v4.glb` (5.3 MB) has the five clips baked. `vyrath_signature_events.json` has the key frames and the interrupt windows; `vyrath_signature_hit_data.json` has per-frame breath origin and direction and tail capsules. Scripts: `vyrath_signature_lib.py` (pose system) and `vyrath_signature_build.py`. In this folder: `signature_breath_tailsweep_frames.png`, `signature_takeoff_landing_frames.png`.

All clips start on the idle's first pose. The grounded ones end on it too. Takeoff ends exactly on the hover loop's first frame, the hover loops exactly, and landing starts on that hover frame and ends on the idle pose, so idle, takeoff, hover (any number of loops), landing, idle chains with no pop (all seams measured 0.0).

| Clip | Length | Phases (frame) | Interrupt windows |
|---|---|---|---|
| `Sig_ThunderBreath` | 168 (7.0 s) | plant 14; cone warning starts 26 (head drops, throat swells, jaw parts); inhale peak 54; breath 56 to 100 sweeping left to right (neck yaws about 26 degrees each way); exhale 100; exposed window 108 to 148 (head high, throat out, panting); recovered 169 | cancelable 1 to 55, committed 56 to 99, vulnerable 100 to 148, free from 149 |
| `Sig_TailSweep` | 108 (4.5 s) | flank check 18 (head turns to look back left); coil 36 (tail and hips wind up right); plant 44; contact 50 to 60 (tail whips left, about 9 degrees per bone, tip travels 0.76 sideways); recoil peak 78; recovered 109 | cancelable 1 to 40, committed 41 to 70, vulnerable 71 to 94, free from 95 |
| `Sig_Takeoff` | 108 (4.5 s) | load 22 (crouch, wings half open); wings unfolded 34; front paws leave 32, hind paws leave 38; leap and first downstroke to 58; second stroke from 80; bank peak 96; level in hover 109 | cancelable 1 to 30, committed 31 to 109 |
| `Flight_Hover` | 48 (2.0 s loop) | wing beat from 46 degrees up to 30 down, body bobs 0.044, slight pitch and roll, legs trailing | airborne loop |
| `Sig_Landing` | 120 (5.0 s) | flare 30 (pitch up 20 degrees, wings forward); descend; forefeet contact 62; hindfeet contact 70; compress peak 80 (body 0.045 low, wings out for balance); settled 121 | committed 1 to 61, vulnerable 62 to 96, free from 97 |

The breath warning is 30 frames (1.25 seconds) from the cone warning to the first damage frame, which meets the prompt's "visible 1 second or more". The breath stays grounded with all four paws planted and the wings only half raised. The hit data gives the mouth position and aim direction for every active breath frame, so the cone (12 degree half angle, range 0.85 of the wingspan, both adjustable) follows the sweep.

Checks:

| Clip | Paws planted | Mesh worst frame (stretched edges, worst ratio) | Wing to foreleg gap | Ground |
|---|---|---|---|---|
| Thunder Breath | all four, zero slide | 20, 1.70x (neck, 10.6 to 18 thousandths) | unchanged (0.060) | feet on it, tail 0.022 clear |
| Tail Sweep | all four, zero slide | 16, 1.68x | unchanged | feet on it, tail 0.030 clear |
| Takeoff | planted until lift, zero slide, then carried | 97, 2.50x | 0.046 (never touches) | foot dips 0.0017 at the leap |
| Hover | airborne | 23, 2.27x | 0.046 | 0.26 above ground |
| Landing | zero slide after contact | 83, 2.40x | unchanged | feet on it, tail 0.025 clear |

What the flight numbers mean: the airborne clips stretch at the belly behind the chest (edges of 4.5 thousandths stretched to 10 or 11), where the body pitch, the trailing legs and the wing root all pull on the same strip. A deep leg tuck under the body made it far worse (up to 295 bad edges), so the legs trail back instead, which also reads better for a dragon. The wing membrane never meets the forelegs (gap stays at least 0.046, the same as at rest apart from the fold). Hover at 23 bad edges is acceptable; takeoff and landing are rougher than any grounded clip and would benefit from the armpit and belly edge loops noted earlier.

Known flaws, not fixed: the throat swell scales neck bones 3 to 5, and bone scale is inherited, so the head also grows about 8 percent at the inhale peak (it reads as the whole front end filling with charge, but it is not what the spec describes); the breath direction in the hit data was normalised afterwards because of that. The tail sweep contact is a left sweep only; a mirrored right sweep is a sign flip in `tail_sweep_params`. There is no flight forward motion (hover is in place), no dive, no "Crownfall Tempest". Takeoff and landing were judged in side renders and by playing in Blender; nothing is in Roblox.

## Roblox Studio import test (2026-10-15, Peter asked for it)

What was tried: the v4 rig with the Idle baked into it was exported from Blender as FBX (`~/Documents/Claude/tripo/out/vyrath/studio/Vyrath_idle.fbx`, 4.9 MB, 15,292 triangles, 10,574 vertices, 83 bones, 4 influences per vertex, textures embedded) and brought into a scratch place (`studio/Vyrath_import.rbxlx`, a copy of the empty Tripo rigs place) with Studio's Import 3D: Rig Type Custom, Anchored on, Upload to Roblox unticked in the preview.

What the engine accepted:

| Item | Result |
|---|---|
| Mesh | One `MeshPart` with a `SurfaceAppearance` (colour and normal maps). 15.3k triangles went through without simplification or a warning. Imported at 1 Blender unit = 100 studs, so the dragon is 89 x 73 x 100 studs; it needs `Model:ScaleTo` (about 0.35 for a 25-stud boss). The pivot landed at the scene origin, so the mesh centre sits at y = -43.6. |
| Skeleton | 74 `Bone` objects in the right hierarchy (`Ground` > `tripo::Root` > `Pelvis` ... `Neck_08` > `Head` > `Jaw`, all four `HindLeg_*` chains, `Wing_*_D4_*`). **The 9 bones with no skin weights were dropped**: the five `Socket_*` bones and the four `IK_Paw_*` targets. "Keep Zero Influence Bones" was left unticked; tick it next time so the breath and weak-point sockets survive. |
| Animation | The Idle came in as a `KeyframeSequence` in `ServerStorage.RBX_ANIMSAVES.Vyrath_idle.Scene`: 96 keyframes, 3.958 s, Loop on, 84 poses per keyframe. The model got an `AnimationController` (no Humanoid), an `InitialPoses` folder of 255 CFrameValues and an `AnimSaves` pointer. |
| Playback | In Play, from the server: `KeyframeSequenceProvider:RegisterKeyframeSequence` gave a temporary id, `Animator:LoadAnimation` on the AnimationController loaded a 3.958 s track, and it played. Over 2.6 s the head moved 2.2 studs, jaw 2.0, tail tip 9.8, left wing tip 4.3, Neck_04 1.6, chest 0.9, and the hind and front feet 0.00, so the skinned mesh animates and the planted feet hold, at this scale. |
| Pictures | None. The window capture blurs Studio's 3D viewport and the MCP screen capture is black, so this was checked by bone positions only. The scratch Studio was left in Play with the camera on the dragon for Peter to look at. |

**An upload happened.** Despite the Upload box being unticked, the mesh (`rbxassetid://76540132093825`, "tripo_node_77af463a...") and the two textures (`73229354466442`, `136589261634376`) were uploaded to Peter's account (creator Adminlegendcreate), confirmed with `MarketplaceService:GetProductInfo`. Either the untick did not register or Studio uploads anyway for a skinned MeshPart. Peter had said to ask before uploading; this one was not asked. They are private assets in his inventory and can be archived from the Creator Dashboard if unwanted.

What this settles: Roblox takes the FBX, the 83-bone custom skeleton (minus weightless bones), 15k-triangle skinned mesh, 4 influences, and a 96-key baked animation, and plays it through an `AnimationController`. There is no need for the `MocapData` creature format for the dragon's own clips: the game can carry the dragon as a skinned MeshPart with uploaded animations (or `RegisterKeyframeSequence` in Studio). What is still open: scale, the dropped socket bones, uploading the other clips, a Humanoid-free way to move and hit-test the boss in `Main`, and performance on mobile (the mesh is one 15k-triangle draw with a 2048 normal map).

Second import, same day (Peter said keep the uploads and carry on): one FBX with all 13 clips (`studio/Vyrath_all.fbx`, 17 MB; Blender's exporter writes every action as its own take) imported with "Keep Zero Influence Bones" ticked. Result: all 83 bones (the five sockets and four paw targets included), a second mesh upload (`rbxassetid://126050040266222`), and 13 `KeyframeSequence`s in `ServerStorage.RBX_ANIMSAVES.Vyrath_all` with the right lengths (Walk and Hover 2.0 s, Idle 4.0, LookAround and WingStretch 8.0, Breath 7.0, TailSweep and Takeoff 4.5, Landing 5.0). The first import was deleted. `Model:ScaleTo(0.35)` and a pivot shift put the paws on y = 0 at the origin: the dragon is now about 25 studs to the top of the wings, head 19 studs up, facing -X. In Play all 13 registered and loaded on one Animator; Walk moved the feet 4.75 studs fore-aft and 1.0 to 1.7 up, and Thunder Breath swung `Socket_Breath` 4.7 studs sideways with the feet at 0.00, so the sockets ride the animation and can anchor the breath cone in game. Saved on Peter's say-so as `~/Documents/Claude/tripo/out/vyrath/studio/Vyrath_import.rbxlx` (202 MB of XML: the 13 keyframe sequences hold a CFrame per bone per key). It is the dragon's Studio test bed: open it with `RobloxStudio -localPlaceFile <path> -task EditFile`; the dragon stands at the origin at 25 studs with all 13 clips in `ServerStorage.RBX_ANIMSAVES.Vyrath_all`. File > Save to File on this place writes straight to the file with no sheet and takes about a minute; a second save during that shows "Another save in progress".


## Six more moves: roar, hit flinch, weak-point stagger, turn, charge run, death (2026-10-15, Peter: "the dragon's next moves")

Files in `~/Documents/Claude/tripo/out/vyrath/`: `vyrath_motion_v4.blend` now also holds these six (plus a `Moves2` NLA strip: idle, roar, idle, flinch, idle, stagger, idle, turn, four runs, death; 42 s, the other strips muted), `vyrath_moves2_v4.glb` (5.3 MB, the six baked), events and interrupt windows appended to `vyrath_signature_events.json`, build script `vyrath_moves2_build.py` (uses `vyrath_signature_lib.py`). In this folder: `moves2_frames.png`.

| Clip | Length | What happens | Joins |
|---|---|---|---|
| `Roar` | 96 (4 s) | Inhale with the head back, then a rear-up (body pitches 16 degrees, front paws leave the ground and tuck), jaw 32 degrees open, wings spread and quivering, tail lashing; settles | starts and ends on the idle pose |
| `Hit_Flinch` | 36 (1.5 s) | Body jerks back 3 cm and down, head snaps up with the jaw open, wings half up, tail whips; back in 1.5 s | starts and ends on the idle pose |
| `Stagger_WeakpointBreak` | 144 (6 s) | Knocked sideways (roll 6 degrees), buckles 4 cm, head drops low and shakes, jaw open, wings drooped; a long stunned hold; slow recovery | starts and ends on the idle pose |
| `Turn_Left90` | 84 (3.5 s) | Turns 90 degrees left in place: twelve small steps (each paw three times, 30 degrees each, hind-left, front-left, hind-right, front-right), the body yaw follows the average of the paws; head leads the turn | starts on the idle pose, ends on it rotated 90 degrees; mirror the signs for a right turn |
| `Charge_Run` | 24 (1 s loop) | Transverse gallop in place (hind pair then front pair), 0.18 stride, 50 percent stance, body bobbing 1.2 cm and pitching, wings folded back, head low; ground speed 0.36 units per second (about 12.6 studs per second at the 25-stud scale) | loops; does not join the idle (needs a start and stop) |
| `Death` | 144 (6 s) | Rear and gasp, then the legs give way (front paws slide forward and out, hind paws back), the body sinks 11.5 cm, the neck bends 84 degrees so the head drops to about 0.3 (half its standing height), wings droop to the ground, tail lies flat; holds the last frame | starts on the idle pose, ends down |

Checks over every clip:

| Clip | Paws | Mesh worst frame (stretched edges, worst ratio) | Ground |
|---|---|---|---|
| Roar | hind planted, zero slide; front carried during the rear | 42, 1.93x | feet on it, body clear |
| Hit flinch | all planted, zero slide | 4, 1.39x | clear |
| Stagger | all planted, zero slide | 83, 2.18x | body dips 0.009 (jaw tip) |
| Turn | each paw still while planted (0.0), 70 of 85 frames planted; no knee flips | 46, 2.11x | clear |
| Charge run | targets still in the ground frame while planted (0.0), legs reach every target | 88, 2.58x | 0.029 below at the lowest ankle during stance |
| Death | zero slide; legs reach | 183, 2.68x | 0.008 below (tail) |

Seams: roar, flinch and stagger return to the idle to within 0.0001; the turn ends 0.84 from the idle pose because it is meant to (rotated 90 degrees); the run loop is exact (0.0) but its first frame differs from the idle by 0.136, so a start and stop transition is still needed; the death ends 0.35 from the idle, down.

What was tuned and why: the first roar rose the body and over-reached the straight front legs (119 bad edges), so it became a rear-up with the front paws lifted (42). The first run used a 0.30 stride, which is longer than a hind leg (204 bad edges, legs overextended); 0.18 with a 50 percent stance fits. The first death sank the body 15 cm, which drove the tail and the folded front legs through the ground and left the dragon looking as if it were still standing; it now sinks 11.5 cm with the paws sliding out from under it, the tail lifted to lie on the ground, and the neck bent hard. The head still does not reach the ground (the neck is long and rises steeply), so it reads as "down and head low", not a flat sprawl. Stagger and death both cost the most stretch at the front legs and chest, the rig's known weak spot.

Not done: no right turn (sign flip), no run start or stop, no dive or forward flight, no hit reactions from the sides, and no "Crownfall Tempest"; judged from still frames and Blender playback.

Studio test bed updated the same day (Peter: "kk go"): one FBX with all 19 actions (`studio/Vyrath_all2.fbx`, 22.7 MB) imported with Keep Zero Influence Bones and Anchored on; Studio reused the existing mesh asset (`126050040266222`, no new upload). The old model and its animation saves were deleted, the new one scaled 0.35, stood on y = 0 at the origin and renamed `Vyrath`; its 19 clips are in `ServerStorage.RBX_ANIMSAVES.Vyrath_all2`. In Play, Roar (head 5.5 studs, hind feet 0.00), Charge_Run (feet 6 studs fore-aft) and Death (head drops 9.3 studs, wing tip 12) all played with the right lengths. Place re-saved.

## Boss controller, first pass (2026-10-15, Peter: "go")

Where it is: `~/Documents/Claude/HeroWars/rigging-src/boss/` (source of truth, copies in `tripo/out/vyrath/studio/`): `Boss.luau` (the controller, a ModuleScript), `BossData.luau` (every number in one place), `BossHarness.server.luau` (test-bed script: floor, spawn, two blocks, click-to-hit remote, a `ServerStorage.VyrathControl` BindableFunction for scripted tests) and `BossHud.client.luau` (HP bar, state line, click to hit). They sit in the test bed under `ServerScriptService.VyrathBoss` and `StarterPlayerScripts.BossHud`.

What the controller does (server, no Humanoid): loads the 19 clips on the model's `AnimationController` (Studio-registered KeyframeSequences now, `BossData.AnimationIds` once published); moves the model with `PivotTo` at the clips' ground speeds (walk 3.3, charge 12.6 studs per second) with turn rates of 35 to 60 degrees per second (no snap turns); picks the nearest living target from a list the host supplies (`{model=,root=,hum=}`, so HeroWars' `states` can plug in later); runs a state machine: Idle, Walk, Charge_Run, Turn_Left90 (the pivot rotates with the clip so pose and body agree at the end), Roar, Sig_ThunderBreath, Sig_TailSweep, Hit_Flinch, Stagger_WeakpointBreak, Death. Damage in goes through `Boss:hit(damage,pos,source)`: a hit within a socket's radius is a weak point (throat x3, crown and wing roots x2, plus x2 on the throat while exposed), weak-point damage accumulates to a break that plays the stagger, HP 0 plays the death and holds. The breath is a ground wedge from the body (14 degrees half angle, 30 studs) along the head's facing (so it sweeps with the neck), with a sight ray from the mouth, 9 damage every 0.2 s per target inside; a flat yellow slab on the ground shows the wedge during the warning and turns blue while it fires. The tail sweep is capsules along tail bones 4 to 12 during the contact frames, 22 damage and a shove, once per target.

Scripted fight in the test bed (default avatar at 70 studs, scripted through `VyrathControl`):

| Check | Result |
|---|---|
| Hunts | Idle, Turn_Left90 (when the target is 60 to 120 degrees to its left), Charge_Run from 70 to 30 studs, Walk to 16 to 18, then breath; a Roar now and then. Closest approach 16 studs. |
| Breath on open ground | hits: 18 damage from one breath at 22 studs (3 ticks of 6, before the tick was raised to 9). First hit 1.88 s after the warning starts (gate: 1 s or more). |
| Breath through a wall | 0 damage with the avatar behind a block 37 studs away. |
| Weak points | body hit 20 = 20, throat hit 20 = 60; the throat broke after 5 hits and the stagger played; during it a throat hit 20 = 120 (the exposed bonus). |
| Death | 26 body hits of 60 to zero; Death plays and holds its last frame (state stays Death). |
| Tail sweep | fires when a target is within 14 studs at 70 degrees or more off the nose; landed 22 and shoved the avatar. |
| Turn rate | at most 3 degrees per second seen while tracking a near-stationary target; it never snapped. |

Two traps found on the way: (1) the imported model's pivot carries a 90-degree base rotation, so a pure-yaw `PivotTo` lays the dragon on its side; the controller keeps the pivot's rotation and yaws relative to it (`R0`, `yaw0` from the root-to-head direction). (2) Roblox's default character regenerates 1 percent of MaxHealth a second, which hid the 6-point breath ticks in the first runs; the harness tests remove the character's `Health` script. The mouth sits 16 studs ahead of the pivot, so the wedge is anchored at the body, not the mouth.

Not done: no allied bots or party; the breath damage, HP (2000), weak-point break thresholds and cooldowns are first guesses; no hit effects or sounds; the HeroWars side (`Main`) does not call this yet (it needs a `targets` adapter over `states` and a hook so player attacks call `Boss:hit` with the contact position); flight (takeoff, hover, landing) is loaded but the brain never chooses it; no run start or stop. The HUD click-to-hit is a test tool, not game combat.

## Next steps (not done)

- Key the run start and stop, a right turn, a forward flight and a dive; add a right-side tail sweep.
- Add edge loops at the armpit in the mesh if the wing-root pinch matters in real animation.
- Wire the boss into HeroWars: a `targets` adapter over `states`, player attacks calling `Boss:hit`, and the boss HP bar in the game HUD.
- Show Peter the silhouettes, weak-point placement and bone hierarchy for approval, as the pilot prompt requires.
