import bpy, math, os, json
import numpy as np
from mathutils import Matrix, Vector

OUT = "/private/tmp/claude-501/-Users-peteralleyne-Downloads/8d0e984c-cb7f-420d-befa-67d549426a5d/scratchpad/vyrath_test"
os.makedirs(OUT, exist_ok=True)

arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
for o in bpy.data.objects:
    if o.type == 'MESH' and o is not body:
        o.hide_render = True
        o.hide_viewport = True

scn = bpy.context.scene
scn.render.engine = 'BLENDER_WORKBENCH'
scn.render.resolution_x, scn.render.resolution_y = 520, 400
scn.render.image_settings.file_format = 'PNG'
scn.display.shading.light = 'STUDIO'
scn.display.shading.color_type = 'TEXTURE'
scn.display.shading.show_cavity = False
scn.display.shading.background_type = 'WORLD'
if scn.world is None:
    scn.world = bpy.data.worlds.new("W")
scn.world.color = (0.93, 0.93, 0.93)

cam_data = bpy.data.cameras.new("TestCam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 1.35
cam = bpy.data.objects.new("TestCam", cam_data)
scn.collection.objects.link(cam)
scn.camera = cam
VIEWS = {
    "front": ((3.0, 0.0, 0.36), (90, 0, 90)),
    "side": ((0.0, -3.0, 0.36), (90, 0, 0)),
    "top": ((0.0, 0.0, 3.0), (0, 0, 0)),
}


def shot(name, view):
    loc, eul = VIEWS[view]
    cam.location = loc
    cam.rotation_euler = tuple(math.radians(a) for a in eul)
    scn.render.filepath = f"{OUT}/{name}_{view}.png"
    bpy.ops.render.render(write_still=True)


def rot(bone, axis, deg):
    """Rotate pose bone about an armature-space axis through its head."""
    pb = arm.pose.bones[bone]
    m = pb.matrix.copy()
    head = m.translation.copy()
    R = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head)
    pb.matrix = R @ m
    bpy.context.view_layer.update()


def reset():
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


def verts():
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    a = np.array([body.matrix_world @ v.co for v in me.vertices])
    ev.to_mesh_clear()
    return a


reset()
rest_v = verts()
me0 = body.data
edges = np.array([[e.vertices[0], e.vertices[1]] for e in me0.edges])
rest_len = np.linalg.norm(rest_v[edges[:, 0]] - rest_v[edges[:, 1]], axis=1)
rest_len = np.maximum(rest_len, 1e-6)

NECK = ['bone_10', 'bone_11', 'tripo::Head_0', 'tripo::Head_1', 'tripo::Head_2']
L, R_ = 'bone_20', 'bone_32'   # left (+Y) and right (-Y) wing shoulders


def pose_rest():
    pass


def wings_up():
    rot(L, 'X', 55); rot(R_, 'X', -55)


def wings_down():
    rot(L, 'X', -35); rot(R_, 'X', 35)


def wings_fold():
    rot(L, 'Z', 70); rot(R_, 'Z', -70)


def wings_forward():
    rot(L, 'Z', -30); rot(R_, 'Z', 30)


def hip_yaw():
    rot('bone_1', 'Z', 25)


def hip_pitch():
    rot('bone_1', 'Y', 20)


def neck_down():
    for b in NECK: rot(b, 'Y', 8)


def neck_up():
    for b in NECK: rot(b, 'Y', -5)


def neck_side():
    for b in NECK: rot(b, 'Z', 7)


POSES = {
    "rest": (pose_rest, ["front", "top", "side"]),
    "wings_up": (wings_up, ["front", "top"]),
    "wings_down": (wings_down, ["front", "top"]),
    "wings_fold": (wings_fold, ["front", "top"]),
    "wings_forward": (wings_forward, ["front", "top"]),
    "hip_yaw": (hip_yaw, ["top", "side"]),
    "hip_pitch": (hip_pitch, ["top", "side"]),
    "neck_down": (neck_down, ["side", "top"]),
    "neck_up": (neck_up, ["side", "top"]),
    "neck_side": (neck_side, ["side", "top"]),
}

report = {}
for name, (fn, views) in POSES.items():
    reset()
    fn()
    v = verts()
    el = np.linalg.norm(v[edges[:, 0]] - v[edges[:, 1]], axis=1)
    ratio = el / rest_len
    disp = np.linalg.norm(v - rest_v, axis=1)
    report[name] = {
        "edge_stretch_max": round(float(ratio.max()), 2),
        "edges_over_1.5x": int((ratio > 1.5).sum()),
        "edges_under_0.5x": int((ratio < 0.5).sum()),
        "verts_moved_gt_0.02": int((disp > 0.02).sum()),
        "max_move": round(float(disp.max()), 3),
    }
    for vw in views:
        shot(name, vw)
reset()
print(json.dumps(report, indent=1))
