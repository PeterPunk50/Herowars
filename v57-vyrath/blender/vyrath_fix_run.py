exec(open('/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/vyrath_fix_lib.py').read())
import os

OUTDIR = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath"
IMG = "/Users/peteralleyne/Documents/Claude/tripo/out/vyrath/fixed_renders"
os.makedirs(IMG, exist_ok=True)

CFG = dict(sh_r=0.13, sh_iters=3, hip_r=0.14, hip_iters=6, alpha=0.5, foot_fix=True)
setup()
info = fix(CFG)
arm, body = G['arm'], G['body']
res = suite()
print("final metrics", json.dumps(res))

# -------- renders
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
cam_data.ortho_scale = 1.35
cam = bpy.data.objects.new("TestCam", cam_data)
scn.collection.objects.link(cam)
scn.camera = cam
VIEWS = {"front": ((3.0, 0.0, 0.36), (90, 0, 90)), "side": ((0.0, -3.0, 0.36), (90, 0, 0)), "top": ((0.0, 0.0, 3.0), (0, 0, 0))}


def shot(name, view):
    loc, eul = VIEWS[view]
    cam.location = loc
    cam.rotation_euler = tuple(math.radians(a) for a in eul)
    scn.render.filepath = f"{IMG}/{name}_{view}.png"
    bpy.ops.render.render(write_still=True)


P = make_poses()
for name, views in [('wings_up', ['front', 'top']), ('wings_fold', ['front', 'top']), ('digits', ['front', 'top']),
                    ('hip_yaw', ['top', 'side']), ('hip_pitch', ['side']), ('neck_down', ['side', 'top'])]:
    reset(); P[name](); [shot(name, v) for v in views]
reset(); shot('rest', 'side')

# -------- save + export
bpy.ops.wm.save_as_mainfile(filepath=OUTDIR + "/vyrath_rig_fixed.blend")
vl = bpy.data.scenes[0].view_layers[0]
with bpy.context.temp_override(window=bpy.context.window_manager.windows[0], view_layer=vl, active_object=arm, object=arm,
                               selected_objects=[arm, body], selected_editable_objects=[arm, body]):
    for o in bpy.data.objects:
        o.select_set(o in (arm, body))
    bpy.ops.export_scene.gltf(filepath=OUTDIR + "/vyrath_quad_rig_fixed.glb", export_format='GLB', use_selection=True,
                              export_skins=True, export_animations=False, export_apply=False)
print("exported", os.path.getsize(OUTDIR + "/vyrath_quad_rig_fixed.glb"))
