# Blender (headless), V60b (Peter: "hand grip sword grip wrong not in a fist"): curl Varn's open claws into fists around
# the greatsword's grip line and export them as static meshes for Roblox, with the untouched hands as alignment references.
# usage: blender -b --factory-startup --python make_fists.py -- <HW_varn_tripo_6k_R15.fbx> <out dir> [knuckle fraction] [turns]
# Grip axes come from grip_axis.py (the line through both palms in his two-handed idle, in each hand's rest frame, Roblox
# rig axes): right hand -> left hand (-0.29,-0.48,0.82); the left hand uses its mirror (see U).
# Writes <out>/varn_fists.fbx (RightFist, LeftFist, RightHandRef, LeftHandRef; 1 Blender metre = 3.4 studs), fists.json
# (bounding-box centres, grip point and axis per hand, in Roblox studs relative to the hand's own bounding-box centre)
# and preview renders.
import bpy, bmesh, sys, os, json, math
from mathutils import Vector
a = sys.argv[sys.argv.index('--') + 1:]
fbx, out = a[0], a[1]; KNUCKLE = float(a[2]) if len(a) > 2 else 0.45; TURN = float(a[3]) if len(a) > 3 else 4.4
os.makedirs(out, exist_ok=True)
STUDS = 3.4                                   # studs per Blender metre (the rig: cm FBX, ScaleTo 0.034)
def rig2b(v): return Vector((-v[0], v[2], v[1]))           # Roblox rig axes -> Blender world axes
def b2rbx(v): return [-v.x * STUDS, v.z * STUDS, v.y * STUDS]  # Blender world (m) -> Roblox studs, rig axes
# left: the mirror of the right hand's line (its own measured line ran through the palm: the retarget twists that wrist),
# pointing at the other hand (the blade side); the client pins the left hand onto the hilt along it.
U = {'RightHand': rig2b((-0.29, -0.48, 0.82)).normalized(), 'LeftHand': rig2b((-0.29, 0.48, -0.82)).normalized()}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=fbx)
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
info = {}
made = []
for hand in ('RightHand', 'LeftHand'):
    src = bpy.data.objects[hand]
    W = arm.matrix_world @ arm.data.bones[hand].head_local
    ref = src.copy(); ref.data = src.data.copy(); ref.name = hand.replace('Hand', 'HandRef'); bpy.context.scene.collection.objects.link(ref)
    fist = src.copy(); fist.data = src.data.copy(); fist.name = hand.replace('Hand', 'Fist'); bpy.context.scene.collection.objects.link(fist)
    for o in (ref, fist):
        o.modifiers.clear(); o.parent = None; o.matrix_world = src.matrix_world.copy()
        o.data.transform(o.matrix_world); o.matrix_world.identity()     # bake to world coordinates
        o.vertex_groups.clear()
    me = fist.data; bm = bmesh.new(); bm.from_mesh(me)
    pts = [v.co.copy() for v in bm.verts]
    u = U[hand]; medial = Vector((1, 0, 0)) if W.x < 0 else Vector((-1, 0, 0))
    far = sorted(pts, key=lambda p: (p - W).length)[-max(4, len(pts) // 5):]
    f0 = (sum(far, Vector()) / len(far) - W).normalized()
    f = (f0 - u * u.dot(f0)).normalized()
    n = u.cross(f).normalized()
    if n.dot(medial) < 0: n = -n
    s_all = [(p - W).dot(f) for p in pts]; Lh = max(s_all); sk = KNUCKLE * Lh
    # subdivide finger edges first so the curl bends smoothly instead of folding the low-poly claws
    edges = [e for e in bm.edges if min((e.verts[0].co - W).dot(f), (e.verts[1].co - W).dot(f)) > sk - 0.01]
    bmesh.ops.subdivide_edges(bm, edges=edges, cuts=2, use_grid_fill=True)
    fing = [v for v in bm.verts if (v.co - W).dot(f) > sk]
    h0 = sum((v.co - W).dot(n) for v in fing) / len(fing)
    Lf = Lh - sk; R = Lf / TURN
    wm = sum(((v.co - W).dot(u) for v in fing), 0.0) / len(fing)
    for v in fing:
        d = v.co - W; s = d.dot(f) - sk; h = d.dot(n) - h0; w = d.dot(u)
        t = s / R
        v.co = W + u * w + f * (sk + (R - h) * math.sin(t)) + n * (h0 + R - (R - h) * math.cos(t))
    bm.to_mesh(me); bm.free(); me.update()
    G = W + f * sk + n * (h0 + R) + u * wm                               # the grip line's point mid-palm
    def bbc(o):
        vs = [v.co for v in o.data.vertices]
        lo = Vector((min(p.x for p in vs), min(p.y for p in vs), min(p.z for p in vs))); hi = Vector((max(p.x for p in vs), max(p.y for p in vs), max(p.z for p in vs)))
        return (lo + hi) / 2, hi - lo
    rc, rs = bbc(ref); fc, fs = bbc(fist)
    info[hand] = dict(ref_size=[abs(x) for x in b2rbx(rs)], fist_size=[abs(x) for x in b2rbx(fs)], fist_offset=b2rbx(fc - rc),
                      grip_point=b2rbx(G - rc), grip_axis=[-u.x, u.z, u.y], fingers=[-f.x, f.z, f.y], palm=[-n.x, n.z, n.y],
                      curl_radius_studs=R * STUDS, knuckle=KNUCKLE, turn=TURN)
    print('FIST', hand, 'verts', len(me.vertices), 'finger len %.3f m, R %.3f m (%.3f studs)' % (Lf, R, R * STUDS))
    made += [ref, fist]
json.dump(info, open(os.path.join(out, 'fists.json'), 'w'), indent=1)
# export: only the four objects; 1 Blender metre = 3.4 studs (FBX is cm and Studio reads 1 cm as 1 stud: 0.034)
for o in bpy.context.scene.objects: o.select_set(o in made)
bpy.ops.export_scene.fbx(filepath=os.path.join(out, 'varn_fists.fbx'), use_selection=True, global_scale=0.034, apply_unit_scale=True,
                         object_types={'MESH'}, use_mesh_modifiers=False, mesh_smooth_type='FACE', path_mode='COPY', embed_textures=True)
# preview renders: fists with a grip rod through each grip line
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH' and o not in made: bpy.data.objects.remove(o)
for hand, d in info.items():
    o = bpy.data.objects[hand.replace('Hand', 'Fist')]
    rc = (lambda vs: (Vector((min(p.x for p in vs), min(p.y for p in vs), min(p.z for p in vs))) + Vector((max(p.x for p in vs), max(p.y for p in vs), max(p.z for p in vs)))) / 2)([v.co for v in bpy.data.objects[hand.replace('Hand', 'HandRef')].data.vertices])
    G = rc + Vector((-d['grip_point'][0], d['grip_point'][2], d['grip_point'][1])) / STUDS
    u = Vector((-d['grip_axis'][0], d['grip_axis'][2], d['grip_axis'][1]))
    bpy.ops.mesh.primitive_cylinder_add(radius=0.012, depth=0.3, location=G)
    rod = bpy.context.active_object; rod.rotation_euler = u.to_track_quat('Z', 'Y').to_euler(); rod.name = hand + 'Rod'
for o in made:
    if o.name.endswith('Ref'): o.hide_render = True
sc = bpy.context.scene; sc.render.engine = 'BLENDER_WORKBENCH'; sc.display.shading.light = 'STUDIO'; sc.display.shading.color_type = 'TEXTURE'
sc.render.resolution_x = sc.render.resolution_y = 384; sc.world = bpy.data.worlds.new('w'); sc.world.color = (0.25, 0.25, 0.28)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam; cam.data.type = 'ORTHO'
for hand in ('RightHand', 'LeftHand'):
    o = bpy.data.objects[hand.replace('Hand', 'Fist')]; vs = [v.co for v in o.data.vertices]
    for x in bpy.context.scene.objects:
        if x.type == 'MESH' and not x.name.endswith('Ref'): x.hide_render = not (x == o or x.name == hand + 'Rod')
    c = sum(vs, Vector()) / len(vs); r = max((p - c).length for p in vs); cam.data.ortho_scale = r * 2.6
    for tag, dvec in (('front', Vector((0, -1, 0))), ('out', Vector((-1 if c.x < 0 else 1, 0, 0))), ('below', Vector((0, 0, -1)))):
        cam.location = c + dvec * r * 4; cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Z' if tag == 'below' else 'Y').to_euler()
        sc.render.filepath = os.path.join(out, 'fist_%s_%s.png' % (hand, tag)); bpy.ops.render.render(write_still=True)
print('FISTS DONE', json.dumps(info))
