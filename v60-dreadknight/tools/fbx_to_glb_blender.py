"""Run inside Blender: blender -b --factory-startup --python fbx_to_glb_blender.py -- <in.fbx> <out.glb>
Imports a Mixamo animation FBX and writes it as a glb (armature + animation) for ual_retarget.Library."""
import bpy, sys
args = sys.argv[sys.argv.index('--') + 1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=args[0])
bpy.ops.export_scene.gltf(filepath=args[1], export_format='GLB', export_animations=True, export_skins=True, export_yup=True)
print('WROTE', args[1])
