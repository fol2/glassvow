"""Read-only ray probes of the reduced gateway's actual mesh openings."""
from pathlib import Path
import json
import math
import sys
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

path = Path(sys.argv[sys.argv.index('--') + 1]).resolve()
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(path))
objects = [o for o in bpy.context.scene.objects if o.type == 'MESH']
assert len(objects) == 1
obj = objects[0]
verts = [obj.matrix_world @ v.co for v in obj.data.vertices]
tree = BVHTree.FromPolygons(verts, [tuple(p.vertices) for p in obj.data.polygons], all_triangles=True)
def occupied(x, z):
    hit, *_ = tree.ray_cast(Vector((x, -10, z)), Vector((0, 1, 0)), 20)
    return hit is not None
door = [occupied(x,z) for x in [-.5,0,.5] for z in [1,2,2.8]]
passage = [occupied(x,z) for x in [-.8,-.72,0,.72,.8] for z in [.05,.2,.5,1,2]]
piers = [occupied(x,z) for x in [-1.65,1.65] for z in [1,2]]
upper = [{'height':round(z,2),'open':not occupied(0,z)} for z in [3.8+i*.05 for i in range(23)]]
direction = Vector((0,math.cos(math.radians(55)),-math.sin(math.radians(55))))
camera_scan = []
for z in [4.05+i*.05 for i in range(11)]:
    at = Vector((0,0,z))
    hit, *_ = tree.ray_cast(at-direction*10,direction,20)
    camera_scan.append({'height':round(z,2),'open':hit is None})
report = {'door_clear': not any(door), 'route_passage_probes_clear': not any(passage), 'piers_solid': all(piers),
    'upper_centre_scan': upper, 'camera_55_centre_scan':camera_scan}
print('TRIAL_GEOMETRY', json.dumps(report), flush=True)
assert report['door_clear'] and report['piers_solid']
assert report['route_passage_probes_clear'], 'The 1.44-unit route width intersects a passage probe'
assert any(p['open'] for p in upper), 'Upper aperture is closed by geometry'
