import bpy, math, json, os
import numpy as np
from mathutils import Matrix, Vector

SRC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_walk_v4.blend"
OUT = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
SC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/idle_work/"
FPS = 24
T = globals().get('IDLE_T', 96)               # 4 seconds, one breath per loop
DROP = globals().get('IDLE_DROP', 0.015)      # body sits low enough that the nearly straight front legs keep slack while the chest rises
TAIL_LIFT = globals().get('IDLE_TAIL_LIFT', 1.5)
DO_RENDER = globals().get('DO_RENDER', True)
SAVE = globals().get('SAVE', True)
DO_EXPORT = globals().get('DO_EXPORT', True)

bpy.ops.wm.open_mainfile(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
me = body.data
N = len(me.vertices)
vl = bpy.data.scenes[0].view_layers[0]
scn = bpy.context.scene
scn.render.fps = FPS
pb = arm.pose.bones
neck = [f'Neck_{i + 1:02d}' for i in range(8)]
tail = [f'Tail_{i + 1:02d}' for i in range(12)]
ANIM = ['tripo::Root', 'Pelvis', 'tripo::Spine_0', 'tripo::Spine_1', 'Jaw', 'Wing_L_Shoulder', 'Wing_R_Shoulder', 'Wing_L_Forearm', 'Wing_R_Forearm'] + neck + tail + \
       ['IK_Paw_HL', 'IK_Paw_HR', 'IK_Paw_FL', 'IK_Paw_FR']


def mode(m):
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl):
        bpy.ops.object.mode_set(mode=m)


def reset():
    for p in pb:
        p.location = (0, 0, 0)
        p.rotation_mode = 'QUATERNION'
        p.rotation_quaternion = (1, 0, 0, 0)
        p.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def rot(bone, axis, deg):
    p = pb[bone]
    m = p.matrix.copy()
    head = m.translation.copy()
    p.matrix = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head) @ m
    bpy.context.view_layer.update()


def shift(bone, delta):
    p = pb[bone]
    m = p.matrix.copy()
    m.translation += Vector(delta)
    p.matrix = m
    bpy.context.view_layer.update()


def bump(f, a, b):
    """0 outside [a, b], a smooth 0-1-0 hump inside."""
    if f < a or f > b:
        return 0.0
    return math.sin(math.pi * (f - a) / (b - a)) ** 2


def pose_frame(f):
    reset()
    ph = 2 * math.pi * (f - 1) / T
    br = math.sin(ph)                                     # breath: chest rises on the way up, falls on the way down
    shift('tripo::Root', (0, 0, -DROP + 0.004 * br))
    rot('tripo::Spine_1', 'Y', -1.2 * br)
    rot('tripo::Spine_0', 'Y', -0.6 * br)
    rot('Pelvis', 'Z', 2.0 * math.sin(ph + 0.5))          # slow weight shift
    rot('Pelvis', 'X', 1.2 * math.sin(ph - 1.0))
    for i, b in enumerate(neck):                          # head sways and looks about, a little
        rot(b, 'Y', -0.25 * br + 0.3 * math.sin(ph - 0.8))
        rot(b, 'Z', (6.0 / 8) * math.sin(ph + 1.3) + (1.5 / 8) * math.sin(2 * ph))
    rot('Jaw', 'Y', 2.0 * (0.5 + 0.5 * math.sin(ph + 2.0)))
    flick = bump(f, 56, 78)                               # one wing settle per loop
    for side, sg in (('L', 1), ('R', -1)):
        rot(f'Wing_{side}_Shoulder', 'X', sg * (1.2 * br + 5.0 * flick))
        rot(f'Wing_{side}_Shoulder', 'Z', sg * 6.0 * flick)
        rot(f'Wing_{side}_Forearm', 'Z', sg * 4.0 * flick)
    for i, b in enumerate(tail):
        rot(b, 'Z', 2.4 * math.sin(ph - 0.35 * (i + 1)))
        rot(b, 'Y', TAIL_LIFT + 0.6 * math.sin(2 * ph - 0.5 * (i + 1)))
    # paws stay exactly where the rest pose puts them


def key_frame(f):
    for n in ANIM:
        pb[n].keyframe_insert('location', frame=f)
        pb[n].keyframe_insert('rotation_quaternion', frame=f)


walk = arm.animation_data.action if arm.animation_data else None
if walk:
    walk.use_fake_user = True
arm.animation_data_create()
idle = bpy.data.actions.new('Idle')
idle.use_fake_user = True
arm.animation_data.action = idle
for f in range(1, T + 2):
    pose_frame(1 if f == T + 1 else f)
    key_frame(f)
reset()
scn.frame_start, scn.frame_end = 1, T

# ------------------------------------------------------------------ measure
rest_mesh = np.array([v.co[:] for v in me.vertices])
edges = np.array([[e.vertices[0], e.vertices[1]] for e in me.edges])
rest_len = np.maximum(np.linalg.norm(rest_mesh[edges[:, 0]] - rest_mesh[edges[:, 1]], axis=1), 1e-6)
gname = {i: g.name for i, g in enumerate(body.vertex_groups)}
W = np.zeros((N, len(gname)))
for v in me.vertices:
    for g in v.groups:
        W[v.index, g.group] = g.weight
dom = np.array([gname[i] for i in W.argmax(1)])
foot_groups = {'HL': ['HindLeg_L_Foot'], 'HR': ['HindLeg_R_Foot'], 'FL': ['tripo::0_Left_Limb_2', 'tripo::0_Left_Limb_3', 'tripo::0_Left_Limb_4'],
               'FR': ['tripo::0_Right_Limb_1', 'tripo::0_Right_Limb_2', 'tripo::0_Right_Limb_3']}
toe_idx = {}
for k, gs in foot_groups.items():
    idx = np.where(np.isin(dom, gs))[0]
    toe_idx[k] = idx[np.argmin(rest_mesh[idx, 2])]
eff = {'HL': 'HindLeg_L_Ankle', 'HR': 'HindLeg_R_Ankle', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
knee = {'HL': 'HindLeg_L_Knee', 'HR': 'HindLeg_R_Knee', 'FL': 'tripo::0_Left_Limb_1', 'FR': 'tripo::0_Right_Limb_0'}
limb_root = {'HL': 'HindLeg_L_Hip', 'HR': 'HindLeg_R_Hip', 'FL': 'bone_26', 'FR': 'bone_42'}
foot_all = np.isin(dom, sum(foot_groups.values(), []))
tail_all = np.array([d.startswith('Tail_') for d in dom])
head_tip = int(np.argmax(rest_mesh[:, 0]))
tail_tip = int(np.argmin(rest_mesh[:, 0]))
wingL_tip = int(np.argmax(rest_mesh[:, 1]))
wingR_tip = int(np.argmin(rest_mesh[:, 1]))
chest = int(np.argmin(np.linalg.norm(rest_mesh - np.array([0.30, 0.0, 0.30]), axis=1)))
track = {'head tip': head_tip, 'tail tip': tail_tip, 'left wing tip': wingL_tip, 'right wing tip': wingR_tip, 'chest': chest}
pos = {k: [] for k in track}
tg = {k: [] for k in eff}
ball = {k: [] for k in eff}
toe = {k: [] for k in eff}
kx = {k: [] for k in eff}
stats = []
zmin = []
maxedge = {}
for f in range(1, T + 2):
    scn.frame_set(f)
    bpy.context.view_layer.update()
    ev = body.evaluated_get(bpy.context.evaluated_depsgraph_get())
    m = ev.to_mesh()
    V = np.array([v.co[:] for v in m.vertices])
    ev.to_mesh_clear()
    ratio = np.linalg.norm(V[edges[:, 0]] - V[edges[:, 1]], axis=1) / rest_len
    bad = (ratio > 1.5) | (ratio < 0.5)
    stats.append((float(ratio.max()), int(bad.sum())))
    zmin.append((float(V[foot_all, 2].min()), float(V[tail_all, 2].min()), float(V[~foot_all & ~tail_all, 2].min())))
    em = int(np.argmax(ratio))
    if ratio[em] > maxedge.get('ratio', 0):
        maxedge = {'ratio': round(float(ratio[em]), 2), 'frame': f, 'at': ((rest_mesh[edges[em, 0]] + rest_mesh[edges[em, 1]]) / 2).round(3).tolist(),
                   'bones': [str(dom[edges[em, 0]]), str(dom[edges[em, 1]])]}
    for k, i in track.items():
        pos[k].append(V[i])
    for k in eff:
        tg[k].append(np.array(pb[f'IK_Paw_{k}'].head))
        ball[k].append(np.array(pb[eff[k]].tail))
        toe[k].append(V[toe_idx[k]])
        kn = np.array(pb[knee[k]].head); rt = np.array(pb[limb_root[k]].head); b = np.array(pb[eff[k]].tail)
        kx[k].append(float(kn[0] - (rt[0] + (kn[2] - rt[2]) / (b[2] - rt[2]) * (b[0] - rt[0]))))
scn.frame_set(1)
rep = {'frames': T, 'seconds': T / FPS, 'drop': DROP, 'feet': {}, 'motion_range': {}}
for k in eff:
    A = np.array(tg[k][:T]); B = np.array(ball[k][:T]); Tt = np.array(toe[k][:T])
    rep['feet'][k] = {'target_move': round(float(np.ptp(A, axis=0).max()), 6), 'ankle_move': round(float(np.ptp(B, axis=0).max()), 6),
                      'toe_vertex_move': round(float(np.ptp(Tt, axis=0).max()), 6),
                      'ik_error_max': round(max(float(np.linalg.norm(np.array(tg[k][i]) - np.array(ball[k][i]))) for i in range(T)), 6),
                      'knee_x_range': [round(min(kx[k]), 3), round(max(kx[k]), 3)]}
for k in track:
    P = np.array(pos[k][:T])
    rep['motion_range'][k] = [round(float(x), 4) for x in np.ptp(P, axis=0)]
loop = {k: round(float(np.linalg.norm(np.array(pos[k][0]) - np.array(pos[k][T]))), 6) for k in track}
rep['loop_seam_gap'] = loop
rep['mesh'] = {'max_stretch': round(max(s[0] for s in stats), 2), 'worst_bad_edges_in_a_frame': max(s[1] for s in stats), 'max_edge': maxedge}
rep['clearance'] = {'foot_min_z': round(min(z[0] for z in zmin), 4), 'tail_min_z': round(min(z[1] for z in zmin), 4), 'body_min_z': round(min(z[2] for z in zmin), 4)}
json.dump(rep, open(SC + 'idle_report.json', 'w'))
print(json.dumps(rep))

# ------------------------------------------------------------------ renders
if DO_RENDER:
    IMG = SC + 'vyrath_idle_img'
    os.makedirs(IMG, exist_ok=True)
    for o in bpy.data.objects:
        if o.type == 'MESH' and o is not body:
            o.hide_render = True; o.hide_viewport = True
    scn.render.engine = 'BLENDER_WORKBENCH'
    scn.render.resolution_x, scn.render.resolution_y = 520, 300
    scn.display.shading.light = 'STUDIO'
    scn.display.shading.color_type = 'TEXTURE'
    scn.display.shading.background_type = 'WORLD'
    if scn.world is None:
        scn.world = bpy.data.worlds.new("W")
    scn.world.color = (0.93, 0.93, 0.93)
    cam = next((o for o in bpy.data.objects if o.type == 'CAMERA'), None)
    if cam is None:
        cd = bpy.data.cameras.new("IdleCam"); cam = bpy.data.objects.new("IdleCam", cd); scn.collection.objects.link(cam)
    cam.data.type = 'ORTHO'; cam.data.ortho_scale = 1.4
    scn.camera = cam
    cam.location = (0.0, -3.0, 0.36); cam.rotation_euler = (math.radians(90), 0, 0)
    for f in range(1, T + 1, T // 8):
        scn.frame_set(f)
        scn.render.filepath = f"{IMG}/idle_{f:02d}.png"
        bpy.ops.render.render(write_still=True)
    scn.frame_set(1)

if SAVE:
    bpy.ops.wm.save_as_mainfile(filepath=OUT + "/vyrath_motion_v4.blend")

if DO_EXPORT:
    mode('POSE')
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], active_object=arm, object=arm, view_layer=vl, selected_objects=[arm]):
        bpy.ops.pose.select_all(action='SELECT')
        bpy.ops.nla.bake(frame_start=1, frame_end=T + 1, only_selected=False, visual_keying=True, clear_constraints=False,
                         clear_parents=False, use_current_action=False, bake_types={'POSE'})
    mode('OBJECT')
    baked = arm.animation_data.action
    for a in list(bpy.data.actions):
        if a is not baked:
            bpy.data.actions.remove(a)
    baked.name = 'Idle'
    with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], view_layer=vl, active_object=arm, object=arm,
                                   selected_objects=[arm, body], selected_editable_objects=[arm, body]):
        for o in bpy.data.objects:
            o.select_set(o in (arm, body))
        bpy.ops.export_scene.gltf(filepath=OUT + "/vyrath_idle_v4.glb", export_format='GLB', use_selection=True, export_skins=True,
                                  export_animations=True, export_force_sampling=True, export_apply=False)
    print('exported idle glb', os.path.getsize(OUT + "/vyrath_idle_v4.glb"))
