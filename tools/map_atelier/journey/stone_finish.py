"""Broad painted mineral colour mapped in world-sized planes, without baked light."""
import bpy


def apply(obj, path):
    assert path.is_file(), 'Missing authored stone colour texture'
    image = bpy.data.images.load(str(path), check_existing=True)
    indices = set()
    for i, mat in enumerate(obj.data.materials):
        if not mat.name.startswith(('Ash stone /', 'Worn pale stone')):
            continue
        indices.add(i)
        shader = mat.node_tree.nodes.get('Principled BSDF')
        tex = mat.node_tree.nodes.get('Quiet mineral colour')
        if tex is None:
            tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
            tex.name = 'Quiet mineral colour'
        tex.image = image
        mat.node_tree.links.new(tex.outputs['Color'],shader.inputs['Base Color'])
        shader.inputs['Roughness'].default_value = .94
    if not indices:
        return
    uv = obj.data.uv_layers.get('UVMap') or obj.data.uv_layers.new(name='UVMap')
    for polygon in obj.data.polygons:
        if polygon.material_index not in indices:
            continue
        axis = max(range(3), key=lambda i: abs(polygon.normal[i]))
        axes = [i for i in range(3) if i != axis]
        offset = polygon.material_index*.173
        for loop in polygon.loop_indices:
            p = obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv = (p[axes[0]]/3+offset,p[axes[1]]/3+offset*.71)
