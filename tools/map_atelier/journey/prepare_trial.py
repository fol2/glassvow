"""Inspect and normalise one external GLB candidate without replacing the kit.

Run with Blender: --background --python prepare_trial.py -- SOURCE.glb NAME
The original download is retained. Only the trial copy is reduced and grounded.
"""
from pathlib import Path
import sys
import json
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
args = sys.argv[sys.argv.index('--') + 1:]
if len(args) not in [2,3] or (len(args) == 3 and args[2] != '--thin-web'):
    raise SystemExit('Expected SOURCE.glb NAME [--thin-web]')
source = Path(args[0]).resolve()
name = args[1]
thin_web = '--thin-web' in args
assert source.is_file() and source.suffix.lower() == '.glb'
assert name and all(c in 'abcdefghijklmnopqrstuvwxyz0123456789-' for c in name)
out = ROOT / 'assets/art/map-journey/trials'
out.mkdir(parents=True, exist_ok=True)
target = out / (name + '.glb')
assert source != target, 'Never replace the original download'

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(source))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert objects, 'No mesh in imported candidate'
before = sum(len(p.vertices) - 2 for obj in objects for p in obj.data.polygons)
images = [{'name': i.name, 'size': list(i.size)} for i in bpy.data.images if i.size[0] and i.source == 'FILE']
bpy.ops.object.select_all(action='DESELECT')
for obj in objects:
    obj.select_set(True)
bpy.context.view_layer.objects.active = objects[0]
if len(objects) > 1:
    bpy.ops.object.join()
obj = bpy.context.object
obj.name = name
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
coords = [v.co.copy() for v in obj.data.vertices]
low = Vector(tuple(min(v[i] for v in coords) for i in range(3)))
high = Vector(tuple(max(v[i] for v in coords) for i in range(3)))
assert high.z - low.z > .001, 'Degenerate vertical extent'
factor = 5.5 / (high.z - low.z)
centre = Vector(((low.x + high.x) / 2, (low.y + high.y) / 2, low.z))
for vertex in obj.data.vertices:
    vertex.co = (vertex.co - centre) * factor
if thin_web:
    # Thick generated tracery hides its own aperture at the 55-degree camera.
    # Thin only the ornamental web; keep the load-bearing arch and piers deep.
    def smooth(a, b, value):
        t = max(0, min(1, (value-a)/(b-a)))
        return t*t*(3-2*t)
    for vertex in obj.data.vertices:
        p = vertex.co
        weight = (1-smooth(.80,1.25,abs(p.x))) * smooth(3.55,3.95,p.z) * (1-smooth(4.85,5.25,p.z))
        p.y *= 1-.70*weight
budget = 24000
if before > budget:
    modifier = obj.modifiers.new('Trial geometry budget', 'DECIMATE')
    modifier.ratio = budget / before
    modifier.use_collapse_triangulate = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
triangulate = obj.modifiers.new('Export triangles', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=triangulate.name)
after = len(obj.data.polygons)
assert after <= budget * 1.02, (after, budget)
assert all(len(p.vertices) == 3 for p in obj.data.polygons)
# The generated metallic/roughness map makes ash stone look like polished metal.
# Preserve the source download; calibrate this stone-only trial to matte mineral.
for mat in obj.data.materials:
    for node in mat.node_tree.nodes:
        if node.type == 'BSDF_PRINCIPLED':
            for key, value in [('Metallic', 0.0), ('Roughness', .92)]:
                for link in list(node.inputs[key].links):
                    mat.node_tree.links.remove(link)
                node.inputs[key].default_value = value
        elif node.type == 'NORMAL_MAP':
            node.inputs['Strength'].default_value = .45
bpy.ops.export_scene.gltf(filepath=str(target), export_format='GLB',
    use_selection=True, export_yup=True, export_apply=True, export_materials='EXPORT')
report = {'status': 'Unaccepted single-asset trial; requires native inspection',
    'source': str(source), 'output': str(target.relative_to(ROOT)),
    'triangles_before': before, 'triangles_after': after,
    'height': 5.5, 'source_blender_bounds': [list(low), list(high)],
    'materials': [m.name for m in obj.data.materials], 'images': images,
    'uv_layers': len(obj.data.uv_layers),
    'stone_treatment': {'metallic': 0, 'roughness': .92, 'normal_strength': .45},
    'thin_ornamental_web': thin_web}
(out / (name + '.json')).write_text(json.dumps(report, indent=2) + '\n')
print('TRIAL_PREPARED', json.dumps(report), flush=True)
