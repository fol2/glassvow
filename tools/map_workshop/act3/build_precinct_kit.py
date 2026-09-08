"""Controlled Blender construction of the intact Obsidian Court study kit.

Run with Blender --background --python this_file. Metres, Z up in Blender;
glTF converts to Godot Y up. The architectural front is Blender -Y/Godot +Z.
No textures or imported geometry. Broad planes, deep openings and bevels own form.
"""
import math
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

OUT = Path(__file__).resolve().parent / 'kit'


def material(name, colour, roughness, emission=None):
    item = bpy.data.materials.new(name)
    item.diffuse_color = (*colour, 1)
    item.use_nodes = True
    shader = item.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*colour, 1)
    shader.inputs['Roughness'].default_value = roughness
    shader.inputs['Metallic'].default_value = .18
    if emission:
        shader.inputs['Emission Color'].default_value = (*emission, 1)
        shader.inputs['Emission Strength'].default_value = 1.1
    return item


bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
STONE = material('Obsidian broad planes', (.035, .029, .054), .42)
EDGE = material('Cool dressed edges', (.095, .081, .135), .42)
ROOF = material('Intact slate roof', (.024, .019, .038), .26)
GLASS = material('Recessed amethyst glass', (.055, .006, .038), .32, (.24, .008, .12))
DARK = material('Door recess', (.021, .017, .032), .78)


def mesh(name, vertices, faces, mat=STONE):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(mat)
    return obj


def box(name, centre, size, mat=STONE, bevel=.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=centre)
    obj = bpy.context.object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if bevel:
        modifier = obj.modifiers.new('Dressed arris', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    return obj


def beam(name, a, b, width, depth=None, mat=EDGE):
    delta = Vector(b) - Vector(a)
    obj = box(name, (Vector(a) + Vector(b)) * .5,
              (width, depth or width, delta.length), mat, min(.025, width * .2))
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    return obj


def lancet(width, height, spring, samples=10):
    half = width * .5
    rise = height - spring
    centre = (rise * rise - half * half) / (2 * half)
    radius = half + centre
    angle = math.acos(centre / radius)
    left = [(-half, 0), (-half, spring)]
    left += [(centre - radius * math.cos(angle * i / samples),
              spring + radius * math.sin(angle * i / samples))
             for i in range(1, samples + 1)]
    return left + [(-x, z) for x, z in reversed(left[:-1])]


def arch(name, x, y, z, width, height, spring, thickness=.35, depth=.7):
    inner = lancet(width, height, spring)
    outer = lancet(width + 2 * thickness, height + thickness, spring)
    vertices = [(x + px, y + py, z + pz)
                for py in [-depth * .5, depth * .5] for ring in [inner, outer]
                for px, pz in ring]
    n = len(inner)
    faces = []
    for i in range(n - 1):
        j = i + 1
        faces += [(i, j, n+j, n+i), (2*n+i, 3*n+i, 3*n+j, 2*n+j),
                  (i, 2*n+i, 2*n+j, j), (n+i, n+j, 3*n+j, 3*n+i)]
    faces += [(0, n, 3*n, 2*n), (n-1, 3*n-1, 4*n-1, 2*n-1)]
    return mesh(name, vertices, faces, EDGE)


def pane(name, x, y, z, width, height, spring, mat=GLASS):
    points = lancet(width, height, spring)
    return mesh(name, [(x + px, y, z + pz) for px, pz in points],
                [tuple(range(len(points)-1, -1, -1))], mat)


def window(name, x, y, z, width, height):
    spring = height * .55
    arch(name + ' deep reveal', x, y, z, width, height, spring, .24, .8)
    pane(name + ' shadow backing', x, y + .34, z + .05,
         width - .15, height - .12, spring, DARK)
    # Narrow lights sit inside a dark opening; stone and shadow dominate the bay.
    for index, offset in enumerate([-.24, 0, .24]):
        light_height = height * (.88 if index == 1 else .72)
        light_width = width * .16
        pane(name + ' inset light ' + str(index), x + width*offset, y+.28,
             z+.22, light_width, light_height, light_height*.65)
        arch(name + ' light frame ' + str(index), x + width*offset, y+.20,
             z+.22, light_width+.04, light_height+.06, light_height*.65,
             .045, .12)
    beam(name + ' mullion', (x, y-.12, z), (x, y-.12, z+height-.25), .10)
    for sign in [-1, 1]:
        beam(name + ' tracery', (x, y-.13, z+height*.62),
             (x+sign*width*.36, y-.13, z+height*.40), .075)
    box(name + ' sill', (x, y-.10, z-.12), (width+.7, 1.0, .24), EDGE)


def pinnacle(name, x, y, base, height, width):
    bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=width*.72, radius2=0,
                                    depth=height, location=(x, y, base+height*.5),
                                    rotation=(0, 0, math.pi*.25))
    bpy.context.object.name = name
    bpy.context.object.data.materials.append(ROOF)
    for sign in [-1, 1]:
        beam(name + ' arris', (x+sign*width*.5, y-width*.5, base),
             (x, y, base+height), .075, mat=EDGE)


def buttress(x, y, sign):
    # A solid, tapered blade with a deliberate footing and weathered arris.
    profile = [(x, .6), (x+sign*3.0, .6), (x+sign*2.5, 2.0),
               (x+sign*.5, 11.6), (x, 12.6)]
    verts = [(px, y+dy, pz) for dy in [-.52, .52] for px, pz in profile]
    n = len(profile)
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    faces += [(i, (i+1)%n, (i+1)%n+n, i+n) for i in range(n)]
    mesh('Blade buttress', verts, faces)
    beam('Buttress ridge', (x+sign*2.5, y-.55, 2.0),
         (x+sign*.5, y-.55, 11.6), .13)
    box('Buttress footing', (x+sign*1.25, y, .36), (3.0, 1.7, .72), EDGE)


def hall():
    box('Continuous hall foundation', (0, 0, .32), (25.5, 25.0, .64), STONE, .13)
    # Facade is assembled around actual recesses instead of glass on a flat wall.
    box('Nave interior shadow', (0, .6, 5.8), (19.5, 18.7, 10.5), DARK, .02)
    for x in [-10.5, -6.0, 6.0, 10.5]:
        box('Facade structural pier', (x, -11.0, 6.0), (1.2, 1.6, 11.0))
    for x in [-8.25, 8.25]:
        window('Tall facade lancet', x, -11.6, 2.0, 2.4, 7.2)
        box('Window apron', (x, -11.0, 1.0), (3.3, 1.4, 1.2))
        box('Window spandrel', (x, -10.95, 10.25), (3.3, 1.5, 1.9))
    arch('Great portal outer moulding', 0, -11.7, .64, 7.0, 10.4, 5.8, .6, 1.4)
    arch('Great portal inner moulding', 0, -11.25, .64, 6.3, 10.0, 5.8, .16, .55)
    pane('Closed ceremonial doors', 0, -10.2, .64, 6.3, 10.0, 5.8, DARK)
    for x in [-1.5, 0, 1.5]:
        window('Door light', x, -10.92, 2.0, .62, 5.0)
    for x in [-4.4, 4.4]:
        box('Portal jamb mass', (x, -11.1, 5.8), (1.3, 1.8, 10.4))
    # Complete gable and broad intact roof: no scattered floating roof fragments.
    # Swept, faceted vault: broad concave planes rise into one sovereign ridge.
    roof_profile = [(-12,11),(-7,12.7),(-3.5,16.3),(0,20.2),
                    (3.5,16.3),(7,12.7),(12,11)]
    gable_vertices = [(x*.933,y,z) for y in [-11.1,-10.1]
                      for x,z in roof_profile]
    n = len(roof_profile)
    gable_faces = [tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
    gable_faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh('Front gable',gable_vertices,gable_faces)
    roof_vertices = [(x,y,z) for y in [-12,0,12] for x,z in roof_profile]
    roof_faces = [(row*n+i,(row+1)*n+i,(row+1)*n+i+1,row*n+i+1)
                  for row in range(2) for i in range(n-1)]
    roof_faces += [tuple(range(2*n,3*n)),(0,n-1,3*n-1,2*n)]
    mesh('Complete faceted vault',roof_vertices,roof_faces,ROOF)
    for y in [-12,0,12]:
        for i in range(n-1):
            x0,z0 = roof_profile[i]
            x1,z1 = roof_profile[i+1]
            beam('Vault facet seam',(x0,y,z0+.045),(x1,y,z1+.045),.10)
    beam('Ridge coping', (0,-12,20.25), (0,12,20.25), .2)
    # Deep side bays are separated by substantial masonry; windows sit within bays.
    for sign in [-1, 1]:
        for y in [-8.5, -3.0, 2.5, 8.0]:
            before = set(bpy.context.scene.objects)
            window('Side lancet', 0, 0, 2.1, 2.5, 6.7)
            bpy.context.view_layer.update()
            transform = Matrix.Translation((sign*11.0, y, 0)) @ Matrix.Rotation(sign*math.pi*.5, 4, 'Z')
            for obj in set(bpy.context.scene.objects) - before:
                obj.matrix_world = transform @ obj.matrix_world.copy()
            box('Side wall apron', (sign*10.7,y,1.1), (1.4,4.6,1.3))
            box('Side wall head', (sign*10.7,y,10.15), (1.4,4.6,2.0))
        for y in [-11.0, -5.5, 0, 5.5, 11.0]:
            box('Side structural bay', (sign*10.7,y,5.9), (1.5,1.0,10.5))
            buttress(sign*11.0, y, sign)
    box('Rear closure', (0,11.0,5.9), (22,1.4,10.5))
    for x in [-10.8, 10.8]:
        box('Tower backing', (x,-10.5,8.3), (2.5,2.0,15.4), STONE, .11)
        for side in [-1, 1]:
            box('Tower reveal pier', (x+side*1.02,-12.0,8.3), (.46,1.0,15.4))
        box('Tower apron', (x,-12.0,3.7), (2.5,1.0,6.2))
        box('Tower head', (x,-12.0,14.9), (2.5,1.0,2.2))
        window('Tower light', x,-12.7,7.0,1.05,6.5)
        box('Tower crown', (x,-11,16.0), (3.0,3.5,.65), EDGE)
        pinnacle('Tower spire', x,-11,16.3,6.2,3.0)
    window('Gable rose lancet', 0,-11.75,12.6,2.7,4.1)


def glazed_gallery(width=7.5):
    # A narrow lit gable punctuates the low arcade without widening its reserve.
    for x in [-width*.5, width*.5]:
        box('Glazed bay blade pier', (x,0,5.3), (.85,1.4,10.6))
        box('Glazed bay footing', (x,0,.27), (1.3,1.9,.54), EDGE)
        box('Glazed bay capital', (x,0,10.45), (1.1,1.6,.3), EDGE)
        pinnacle('Glazed bay finial',x,0,10.6,2.1,1.0)
    pane('Tall gallery shadow recess',0,0,.6,width-1.1,10.2,6.0,DARK)
    arch('Tall gallery enclosing arch',0,0,.55,width-.9,10.3,6.0,.3,1.2)
    for index,x in enumerate([-width*.24,0,width*.24]):
        before = set(bpy.context.scene.objects)
        light_height = 8.7 if index==1 else 6.5
        window('Tall gallery light '+str(index),x,-.25,.8,width*.15,light_height)
        pane('Gallery amethyst glazing',x,-.43,1.0,width*.15-.16,
             light_height-.35,light_height*.55,GLASS)
        beam('Glazing central lead',(x,-.46,1.0),(x,-.46,light_height+.45),.055)
        for level in [2.0,3.8,5.6]:
            if level < light_height:
                beam('Glazing cross lead',(x-.44,-.46,level),(x+.44,-.46,level),.045)
        bpy.context.view_layer.update()
        # Court returns are seen from both sides; each face has a real recess.
        for source in set(bpy.context.scene.objects) - before:
            opposite = source.copy()
            opposite.data = source.data.copy()
            bpy.context.collection.objects.link(opposite)
            opposite.matrix_world = Matrix.Diagonal((1,-1,1,1)) @ source.matrix_world
    box('Glazed bay sill course',(0,0,.4),(width,1.5,.22),EDGE)
    for sign in [-1,1]:
        beam('Gable verge',(sign*(width*.5+.35),0,10.7),(0,0,14.7),.22,.8)
    pinnacle('Glazed bay central crown',0,0,14.6,1.2,.6)


def gallery(width=6.0, blind=False):
    if blind:
        glazed_gallery(width)
        return
    for x in [-width*.5, width*.5]:
        box('Cloister pier', (x,0,4.3), (.85,1.4,8.6))
        box('Pier base', (x,0,.27), (1.3,1.9,.54), EDGE)
        box('Pier capital', (x,0,7.7), (1.2,1.8,.35), EDGE)
    arch('Cloister pointed vault', 0,0,.55,width-.9,7.1,3.0,.36,1.2)
    box('Gallery parapet coping', (0,0,8.35), (width+1.0,1.7,.52), EDGE)


def covered_gallery(width=7.5):
    # Half piers meet at the module boundary without doubled external faces.
    for sign in [-1, 1]:
        x = sign*(width*.5-.23)
        box('Covered arcade half pier', (x,0,4.25), (.46,1.1,8.5), STONE, .025)
        box('Covered arcade footing', (x,0,.22), (.46,1.5,.44), EDGE, .025)
        box('Covered arcade capital', (x,0,7.85), (.46,1.45,.3), EDGE, .025)
    arch('Covered arcade vault', 0,0,.5,width-.95,7.2,3.0,.28,1.0)
    box('Continuous gallery floor', (0,.95,.07), (width,3.4,.14), STONE, .015)
    box('Gallery rear wall', (0,2.25,4.25), (width,.45,8.5), STONE, .02)
    box('Front cornice', (0,0,8.55), (width,1.4,.3), EDGE, .025)
    # A closed sloping roof gives the cloister actual depth from the game camera.
    vertices = [(x,y,z+offset) for offset in [0,.2] for x in [-width*.5,width*.5]
                for y,z in [(-.8,8.7),(2.75,10.0)]]
    mesh('Covered gallery slate roof', vertices,
         [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)],ROOF)
    box('Empty cloister seat', (0,1.65,.65), (4.0,.65,.24), EDGE, .04)
    for x in [-1.4,1.4]:
        box('Seat support', (x,1.65,.36), (.35,.5,.58),STONE,.025)


def export(name, build):
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    build()
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = next(o for o in bpy.context.scene.objects if o.type == 'MESH')
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.export_scene.gltf(filepath=str(OUT / (name+'.glb')), export_format='GLB',
                               use_selection=True, export_apply=True, export_yup=True)
    obj.data.calc_loop_triangles()
    print('PRECINCT_ASSET', name, 'triangles', len(obj.data.loop_triangles))


OUT.mkdir(parents=True, exist_ok=True)
builders = {'obsidian-great-hall': hall, 'cloister-bay': gallery,
            'glazed-gallery-bay': lambda: gallery(7.5, True),
            'covered-cloister-bay': covered_gallery}
selected = next((arg.split('=',1)[1] for arg in sys.argv if arg.startswith('--asset=')), None)
if selected is not None and selected not in builders:
    raise ValueError('Unknown precinct asset: '+selected)
for name, builder in builders.items():
    if selected is None or selected == name:
        export(name, builder)
