"""Run inside Blender: blender -b --factory-startup --python fbx_to_glb_batch_blender.py -- <out dir> <in.fbx>...
Like fbx_to_glb_blender.py for many Mixamo clips in one Blender run; "great sword slash (2).fbx" -> gs_slash_2.glb."""
import bpy, sys, os, re
args = sys.argv[sys.argv.index('--') + 1:]; out = args[0]
for f in args[1:]:
    base = os.path.splitext(os.path.basename(f))[0].lower().replace('great sword ', 'gs_')
    m = re.match(r'(.*) \((\d+)\)$', base); base = '%s_%s' % (m.group(1), m.group(2)) if m else base
    name = re.sub(r'[^a-z0-9_]+', '_', base).strip('_')
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=f)
    acts = [a for a in bpy.data.actions]; dur = max((a.frame_range[1] - a.frame_range[0]) for a in acts) / 30.0 if acts else 0
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, name + '.glb'), export_format='GLB', export_animations=True, export_skins=True, export_yup=True)
    print('WROTE %-28s %5.2fs  from %s' % (name, dur, os.path.basename(f)))
