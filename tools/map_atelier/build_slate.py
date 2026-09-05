"""Original connected slate outcrop. Run with Blender's background Python.

One material, grounded pivot and a closed surface; no invisible stacked shells.
The .blend master is retained beside this source. Output is Y-up GLB.
"""
from pathlib import Path
import math
import random
import bpy

ROOT = Path(__file__).resolve().parents[2]
RNG = random.Random(470)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
material = bpy.data.materials.new('Layered slate')
material.diffuse_color = (.25, .32, .34, 1)
material.use_nodes = True
material.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value = .94
parts = []
for pile in range(5):
    angle = pile * 2.39
    x, y = math.cos(angle) * .54, math.sin(angle) * .46
    outline = [(math.cos(j * math.tau / 7) * RNG.uniform(.50, .65),
                math.sin(j * math.tau / 7) * RNG.uniform(.43, .56)) for j in range(7)]
    for layer in range(3):
        z = layer * .10
        size = 1 - layer * .065
        vertices = [(x + a * size, y + b * size, z + h)
                    for h in (0, .145) for a, b in outline]
        faces = [tuple(range(6, -1, -1)), tuple(range(7, 14))]
        faces += [(j, (j + 1) % 7, (j + 1) % 7 + 7, j + 7) for j in range(7)]
        mesh = bpy.data.meshes.new('Stratum')
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new('Stratum', mesh)
        bpy.context.collection.objects.link(obj)
        parts.append(obj)
obj = parts[0]
bpy.context.view_layer.objects.active = obj
obj.select_set(True)
for other in parts[1:]:
    union = obj.modifiers.new('Join exposed strata', 'BOOLEAN')
    union.operation = 'UNION'
    union.solver = 'EXACT'
    union.object = other
    bpy.ops.object.modifier_apply(modifier=union.name)
    bpy.data.objects.remove(other, do_unlink=True)
bevel = obj.modifiers.new('Worn edges', 'BEVEL')
bevel.width = .012
bevel.segments = 1
bpy.ops.object.modifier_apply(modifier=bevel.name)
triangulate = obj.modifiers.new('Triangles', 'TRIANGULATE')
bpy.ops.object.modifier_apply(modifier=triangulate.name)
if len(obj.data.polygons) > 2000:
    simplify = obj.modifiers.new('Mobile geometry budget', 'DECIMATE')
    simplify.ratio = 1900 / len(obj.data.polygons)
    bpy.ops.object.modifier_apply(modifier=simplify.name)
obj.name = 'slate-cluster'
obj.data.materials.clear()
obj.data.materials.append(material)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
assert 600 <= len(obj.data.polygons) <= 2500
assert abs(min(v.co.z for v in obj.data.vertices)) < .001
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'tools/map_atelier/sources/slate-cluster.blend'))
bpy.ops.export_scene.gltf(filepath=str(ROOT / 'assets/art/map-atelier/slate-cluster.glb'),
                         export_format='GLB', use_selection=True, export_yup=True,
                         export_apply=True, export_texcoords=False, export_normals=True,
                         export_materials='EXPORT')
print('SLATE', len(obj.data.polygons), 'triangles; grounded closed union')
