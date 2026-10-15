import bpy, math, os, json
import numpy as np
from mathutils import Matrix, Vector

SC = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/v4_work/"
IMG = SC + "vyrath_v4_img"
OUT = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
os.makedirs(IMG, exist_ok=True)
arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
body = next(o for o in bpy.data.objects if o.type == 'MESH' and o.name.startswith('tripo_node'))
vl = bpy.data.scenes[0].view_layers[0]
neck = [f'Neck_{i + 1:02d}' for i in range(8)]


def rot(bone, axis, deg):
    pb = arm.pose.bones[bone]
    m = pb.matrix.copy()
    head = m.translation.copy()
    pb.matrix = Matrix.Translation(head) @ Matrix.Rotation(math.radians(deg), 4, axis) @ Matrix.Translation(-head) @ m
    bpy.context.view_layer.update()


def reset():
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.scale = (1, 1, 1)
    bpy.context.view_layer.update()


for o in bpy.data.objects:
    if o.type == 'MESH' and o is not body:
        o.hide_render = True
        o.hide_viewport = True
scn = bpy.context.scene
scn.render.engine = 'BLENDER_WORKBENCH'
scn.render.resolution_x, scn.render.resolution_y = 520, 400
scn.display.shading.light = 'STUDIO'
scn.display.shading.color_type = 'TEXTURE'
scn.display.shading.background_type = 'WORLD'
if scn.world is None:
    scn.world = bpy.data.worlds.new("W")
scn.world.color = (0.93, 0.93, 0.93)
cam_data = bpy.data.cameras.new("TestCam")
cam_data.type = 'ORTHO'
cam = bpy.data.objects.new("TestCam", cam_data)
scn.collection.objects.link(cam)
scn.camera = cam
VIEWS = {"front": ((3.0, 0.0, 0.36), (90, 0, 90)), "side": ((0.0, -3.0, 0.36), (90, 0, 0)), "top": ((0.0, 0.0, 3.0), (0, 0, 0)),
         "wingR": ((3.0, -0.27, 0.5), (90, 0, 90)), "neckbase": ((0.29, -3.0, 0.38), (90, 0, 0))}
SCALE = {"wingR": 0.62, "neckbase": 0.3}


def shot(name, view):
    loc, eul = VIEWS[view]
    cam.location = loc
    cam.rotation_euler = tuple(math.radians(a) for a in eul)
    cam_data.ortho_scale = SCALE.get(view, 1.35)
    scn.render.filepath = f"{IMG}/{name}_{view}.png"
    bpy.ops.render.render(write_still=True)


def sym(bone, axis, deg):
    return lambda: (rot('Wing_L_' + bone, axis, deg), rot('Wing_R_' + bone, axis, -deg))


def pose(name, fn, views):
    reset(); fn()
    for v in views:
        shot(name, v)


pose('rest', lambda: None, ['front', 'wingR', 'neckbase'])
pose('d4_spread', sym('D4_0', 'X', 25), ['wingR'])
pose('d4_fold', sym('D4_0', 'X', -20), ['wingR'])
pose('fan_all4', lambda: [sym(d, 'X', 8)() for d in ('D1_0', 'D2_0', 'D3_0', 'D4_0')], ['wingR'])
pose('wings_up55', sym('Shoulder', 'X', 55), ['front'])
pose('wings_fold70', lambda: (rot('Wing_L_Shoulder', 'Z', 70), rot('Wing_R_Shoulder', 'Z', -70)), ['front', 'top'])
pose('neck_down', lambda: [rot(b, 'Y', 5) for b in neck], ['neckbase', 'side'])
reset()

with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], view_layer=vl, active_object=arm, object=arm,
                               selected_objects=[arm, body], selected_editable_objects=[arm, body]):
    for o in bpy.data.objects:
        o.select_set(o in (arm, body))
    bpy.ops.export_scene.gltf(filepath=OUT + "/vyrath_quad_rig_v4.glb", export_format='GLB', use_selection=True,
                              export_skins=True, export_animations=False, export_apply=False)
print("exported", os.path.getsize(OUT + "/vyrath_quad_rig_v4.glb"))

me = body.data
N = len(me.vertices)
rest = np.array([v.co[:] for v in me.vertices])
names = [g.name for g in body.vertex_groups]
Wm = np.zeros((N, len(names)), dtype=np.float32)
for v in me.vertices:
    for g in v.groups:
        Wm[v.index, g.group] = g.weight
np.savez(SC + "vyrath_dump.npz", rest=rest, W=Wm, names=np.array(names), edges=np.array([[e.vertices[0], e.vertices[1]] for e in me.edges]))
json.dump({b.name: dict(head=list(b.head_local), tail=list(b.tail_local), parent=b.parent.name if b.parent else None) for b in arm.data.bones},
          open(SC + "vyrath_bones.json", "w"))
print("dumped", len(arm.data.bones), "bones, groups", len(names), "max influences", int((Wm > 0).sum(1).max()))
