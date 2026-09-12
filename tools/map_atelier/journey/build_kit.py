"""Original Act I sculpted kit. Run with Blender background Python.

Geometry and material colours are authored here; no downloaded model or baked
lighting is used. Y-up GLBs, grounded pivots and local .blend masters are retained.
"""
from pathlib import Path
import math
import random
import json
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
import foliage
import stone_finish
import natural_variants
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / 'assets/art/map-journey'
MASTERS = ROOT / 'tools/map_atelier/journey/sources'
OUT.mkdir(parents=True, exist_ok=True)
MASTERS.mkdir(parents=True, exist_ok=True)
RNG = random.Random(7403)
MANIFEST = []


def material(name, rgb, roughness=.86, glow=0):
    mat = bpy.data.materials.new(name)
    rgb = tuple(c * (0.35 if not glow else 0.7) for c in rgb)
    mat.diffuse_color = (*rgb, 1)
    mat.use_nodes = True
    p = mat.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*rgb, 1)
    p.inputs['Roughness'].default_value = roughness
    if glow:
        p.inputs['Emission Color'].default_value = (*rgb, 1)
        p.inputs['Emission Strength'].default_value = glow
    return mat


STONE = [material('Ash stone / ' + str(i), c) for i, c in enumerate([
    (.24,.225,.25), (.31,.29,.30), (.38,.345,.33), (.20,.19,.225)])]
EDGE = material('Worn pale stone', (.41,.375,.35))
BARK = material('Charcoal bark', (.095,.085,.105))
NEEDLE = [material('Charcoal needles / '+str(i), c) for i,c in enumerate([
    (.018,.020,.026), (.022,.026,.034), (.027,.032,.040)])]
ASH = [material('Ash red leaf / '+str(i), c) for i,c in enumerate([
    (.16,.035,.048), (.19,.047,.055), (.23,.060,.067), (.14,.027,.043)])]
METAL = material('Oxidised bronze', (.21,.155,.09), .64)
AMBER = material('Amber glass', (.85,.37,.065), .34, .65)
GLASS = material('Old amber window', (.48,.19,.04), .45, .23)
DARK = material('Glass lead', (.075,.063,.058), .7)


def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)


def mesh(name, verts, faces, mats, shade=None):
    data = bpy.data.meshes.new(name)
    data.from_pydata(verts, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for mat in mats:
        data.materials.append(mat)
    for polygon in data.polygons:
        polygon.material_index = shade(polygon) if shade else RNG.randrange(len(mats))
    return obj


def bevel(obj, amount=.035):
    bpy.context.view_layer.objects.active=obj
    mod=obj.modifiers.new('Sculpted edge', 'BEVEL')
    mod.width=amount
    mod.segments=1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def block(name, at, size, mat, edge=.03, rotation=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=at)
    obj=bpy.context.object
    obj.name=name
    obj.dimensions=size
    obj.rotation_euler.z=rotation
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    if edge:
        bevel(obj,edge)
    return obj


def rod(name, a, b, radius, mat, vertices=7, end_radius=None):
    delta=Vector(b)-Vector(a)
    bpy.ops.mesh.primitive_cone_add(vertices=vertices, radius1=radius,
        radius2=radius if end_radius is None else end_radius, depth=delta.length,
        location=(Vector(a)+Vector(b))/2)
    obj=bpy.context.object
    obj.name=name
    obj.rotation_euler=delta.to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(mat)
    return obj


def extrude(name, polygon, depth, mats, y=0):
    n=len(polygon)
    verts=[(x, y+d, z) for d in [-depth/2,depth/2] for x,z in polygon]
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]
    faces.extend((i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n))
    return mesh(name,verts,faces,mats)


def pointed_outline(width, base, spring, apex):
    return [(-width/2,base),(width/2,base),(width/2,spring),
        (width*.36,spring+(apex-spring)*.5),(0,apex),
        (-width*.36,spring+(apex-spring)*.5),(-width/2,spring)]


def lantern(x, y, z):
    block('Lamp foot', (x,y,z), (.39,.39,.1), METAL)
    block('Amber light', (x,y,z+.31), (.27,.27,.49), AMBER, .015)
    for dx in [-.17,.17]:
        for dy in [-.17,.17]:
            rod('Lamp leading', (x+dx,y+dy,z), (x+dx*.85,y+dy*.85,z+.6), .023,METAL,5)
    bpy.ops.mesh.primitive_cone_add(vertices=4,radius1=.32,radius2=.07,depth=.23,location=(x,y,z+.70),rotation=(0,0,math.pi/4))
    bpy.context.object.data.materials.append(METAL)
    rod('Lamp chain',(x,y,z+.80),(x,y,z+1.13),.018,METAL,5)


def arch():
    reset()
    spring = 3.03
    def arc(t, radius, side):
        end=math.acos(-.75/radius)
        angle=math.pi+(end-math.pi)*t
        return (side*(-.75-radius*math.cos(angle)),spring+radius*math.sin(angle))
    for side in [-1,1]:
        for course in range(6):
            # Broad chipped corners and staggered joints retain a quiet face.
            height=.43
            width=.78+RNG.uniform(-.035,.035)
            obj=block('Pillar ashlar',(side*1.54,0,.49+course*.43),(width,.93,height-.016),STONE[course%3],0)
            for v in obj.data.vertices:
                v.co.x+=RNG.uniform(-.018,.018)
                v.co.y+=RNG.uniform(-.015,.015)
            bevel(obj,.055+RNG.uniform(0,.025))
        for z,width,depth,height in [(.12,1.16,1.25,.24),(.29,1.03,1.10,.14),(2.91,.99,1.07,.15),(3.02,1.07,1.15,.08)]:
            block('Carved plinth and capital',(side*1.54,0,z),(width,depth,height),STONE[1],.025)
        # Slender engaged shafts articulate the front face without noisy texture.
        for offset in [-.22,.22]:
            rod('Engaged shaft',(side*1.54+offset,-.49,.40),(side*1.54+offset,-.49,2.83),.065,STONE[2],8)
            for z in [.43,2.77]:
                block('Shaft collar',(side*1.54+offset,-.49,z),(.18,.19,.10),EDGE,.02)
        for j in range(11):
            t0=j/11+.002;t1=(j+1)/11-.002
            outline=[arc(t0,2.1,side),arc(t1,2.1,side),arc(t1,2.50,side),arc(t0,2.50,side)]
            bevel(extrude('Arch voussoir',outline,.88,[STONE[(j+1)%3]]),.045)
        # Recessed inner archivolt: continuous narrow moulding, jointed stone rim.
        for radius,mat in [(2.04,EDGE),(2.13,METAL),(2.35,STONE[0])]:
            for j in range(20):
                a=arc(j/20,radius,side);b=arc((j+1)/20,radius,side)
                rod('Archivolt',(a[0],-.50,a[1]),(b[0],-.50,b[1]),.034,mat,6)
        rod('Lamp bracket',(side*1.55,-.46,3.55),(side*2.38,-.46,3.42),.035,METAL)
        rod('Bracket brace',(side*1.55,-.46,3.10),(side*2.21,-.46,3.43),.026,METAL)
        lantern(side*2.30,-.46,1.90)
        rod('Hanging chain',(side*2.30,-.46,3.03),(side*2.30,-.46,3.43),.018,METAL,5)
        # A low buttress gives the opening real mass in depth.
        bevel(extrude('Buttress',[(side*1.80,0),(side*2.14,0),(side*2.04,1.23),(side*1.80,1.82)],.74,[STONE[0]],y=.25),.04)
    # A supported stone tympanum carries the trefoil rather than floating glass.
    polygon=[(-1.17,3.63),(-.70,3.65),(-.35,3.48),(0,3.23),(.35,3.48),(.70,3.65),(1.17,3.63),(.94,4.12),(.51,4.64),(0,5.02),(-.51,4.64),(-.94,4.12)]
    bevel(extrude('Carved tympanum',polygon,.62,[STONE[0]],y=-.03),.035)
    for i,a in enumerate(polygon):
        b=polygon[(i+1)%len(polygon)]
        rod('Tympanum border',(a[0],-.37,a[1]),(b[0],-.37,b[1]),.025,METAL,6)
    # One clover-shaped recess, not three disconnected circular badges.
    clover=[]
    for i in range(60):
        angle=i*math.tau/60
        radius=.40+.115*math.cos(3*(angle-math.pi/2))
        clover.append((math.cos(angle)*radius,4.17+math.sin(angle)*radius))
    extrude('Trefoil recess',clover,.025,[DARK],y=-.36)
    for i,a in enumerate(clover):
        b=clover[(i+1)%len(clover)]
        rod('Trefoil bronze tracery',(a[0],-.395,a[1]),(b[0],-.395,b[1]),.029,METAL,6)
    save('amber-arch','Tall ashlar gateway with engaged shafts, recessed trefoil and paired amber lamps',10000)


def conifer():
    foliage.conifer(reset, rod, mesh, save, BARK, OUT)


def copse():
    foliage.copse(reset, rod, mesh, save, BARK, OUT)


def rock(ridge=False):
    reset()
    # Leaning, intersecting masses share a geological direction. Broad sloped
    # crowns and unequal shoulders replace the previous repeating slab stack.
    rng = random.Random(7493 if ridge else 7481)
    outline=[(-.9,-.5),(-.42,-.76),(.53,-.66),(1,-.22),(.82,.54),(.14,.72),(-.82,.51)]
    chunks = [(-1.0,.1,.61,.65),(-.10,.0,.86,.75),(.85,.12,.66,.62),(1.35,-.10,.30,.35)] if ridge else [(-.64,.23,1.53,.91),(.49,.29,1.19,.84),(.99,-.40,.59,.50),(-.82,-.60,.43,.43)]
    for chunk,(x,y,height,width) in enumerate(chunks):
        points=[(a*width+rng.uniform(-.09,.09),b*width+rng.uniform(-.07,.07)) for a,b in outline]
        verts=[]
        for level,scale,shift in [(0,1.08,0),(.68,1,.14),(1,.77,.25)]:
            for i,(a,b) in enumerate(points):
                z=height*level
                if level:
                    z+=a*.19+b*.12+rng.uniform(-.06,.06)
                verts.append((x+a*scale+shift,y+b*scale,z))
        # Three unequal top planes, including an off-centre crown.
        verts.append((x+.19,y+.02,height+.11))
        faces=[tuple(range(6,-1,-1))]
        for ring in range(2):
            for i in range(7):
                n=(i+1)%7; a=ring*7
                faces.append((a+i,a+n,a+n+7,a+i+7))
        faces.extend([(14,15,16,21),(16,17,18,21),(18,19,20,14,21)])
        obj=mesh('Weathered slate mass',verts,faces,STONE,
            lambda p: 1 if p.index>=15 else [0,1,3,0][(p.index+chunk)%4])
        bevel(obj,.035)
    save('slate-ridge' if ridge else 'slate-bank','Leaning slate masses with broad sloping crowns and irregular fractured shoulders',3000)


def memorial():
    reset()
    block('Memorial foot',(0,0,.10),(.85,.55,.20),STONE[0],.045)
    bevel(extrude('Memorial body',pointed_outline(.75,.16,1.48,1.96),.37,[STONE[1]]),.04)
    for width,base,spring,apex,depth,mat in [(.58,.28,1.40,1.77,-.20,STONE[0]),(.43,.38,1.30,1.60,-.24,METAL),(.32,.40,1.26,1.49,-.25,GLASS)]:
        outline=pointed_outline(width,base,spring,apex)
        extrude('Recessed memorial niche',outline,.026,[mat],y=depth)
        if mat != GLASS:
            for i,a in enumerate(outline):
                b=outline[(i+1)%len(outline)]
                rod('Carved niche rim',(a[0],depth-.02,a[1]),(b[0],depth-.02,b[1]),.021,EDGE if mat == STONE[0] else METAL,6)
    rod('Leading',(0,-.29,.42),(0,-.29,1.48),.016,METAL,5)
    for z in [.65,.93,1.19]:
        rod('Diamond leading',(-.14,-.29,z),(0,-.29,z+.17),.012,METAL,5)
        rod('Diamond leading',(0,-.29,z+.17),(.14,-.29,z),.012,METAL,5)
    for x in [-.2,.15]:
        rod('Quiet candle',(x,-.3,.2),(x,-.3,.39),.035,EDGE,7)
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=.044,location=(x,-.3,.43))
        bpy.context.object.data.materials.append(AMBER)
    save('memorial','Carved Gothic memorial with a deep leaded amber niche',3500)


def waystone():
    reset()
    for h,r in [(.05,.38),(.14,.31)]:
        bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=.1,location=(0,0,h))
        obj=bpy.context.object;obj.name='Waystone footing';obj.data.materials.append(STONE[0]);bevel(obj,.02)
    bevel(extrude('Waystone',pointed_outline(.38,.19,.56,.80),.24,[STONE[2]]),.02)
    extrude('Quiet glass',pointed_outline(.14,.30,.56,.65),.03,[GLASS],y=-.145)
    save('waystone','Low grounded stone; encounter identity remains a screen-space overlay',1000)


def bridge():
    reset()
    block('Bridge foundation',(0,0,.31),(2.0,3.2,.20),STONE[0],.045)
    for row in range(5):
        for side in [-1,1]:
            block('Paving slab',(side*.46,-1.27+row*.635,.445),(.90,.616,.15),STONE[(row+(side+1)//2)%3],.027)
    for side in [-1,1]:
        block('Parapet',(side*.92,0,.66),(.18,3.2,.28),STONE[1],.03)
        for y in [-1.47,0,1.47]:
            block('Parapet post',(side*.92,y,.76),(.29,.27,.53),STONE[2],.025)
        block('Foundation',(side*.73,0,.14),(.43,2.9,.28),STONE[0],.025)
    save('bridge-bay','Stone bridge bay for material, thickness and parapet-scale review',2000)


def lamp_pair():
    reset()
    for side in [-1,1]:
        rod('Lamp bracket',(side*1.55,-.46,3.55),(side*2.38,-.46,3.42),.035,METAL)
        rod('Bracket brace',(side*1.55,-.46,3.10),(side*2.21,-.46,3.43),.026,METAL)
        lantern(side*2.30,-.46,1.90)
        rod('Hanging chain',(side*2.30,-.46,3.03),(side*2.30,-.46,3.43),.018,METAL,5)
    save('lamp-pair','Separate bronze and amber lamps for the generated gateway',1800,grounded=False)


def save(name,description,budget,grounded=True):
    objects=[o for o in bpy.context.scene.objects if o.type=='MESH']
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join()
    obj=bpy.context.object;obj.name=name
    bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
    # Recalculate outward normals consistently after the constructive primitives.
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
    low=min(v.co.z for v in obj.data.vertices)
    if grounded:
        for v in obj.data.vertices:v.co.z-=low
    tri=obj.modifiers.new('Export triangles','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=tri.name)
    triangles=len(obj.data.polygons)
    assert triangles<=budget,(name,triangles,budget)
    # Merge duplicated material slots left by joining parts.
    materials=[]
    remap={}
    for i,mat in enumerate(obj.data.materials):
        if mat not in materials:materials.append(mat)
        remap[i]=materials.index(mat)
    indices=[remap[p.material_index] for p in obj.data.polygons]
    obj.data.materials.clear()
    for mat in materials:obj.data.materials.append(mat)
    for p,i in zip(obj.data.polygons,indices):p.material_index=i
    if name.startswith('slate-') or name in ['amber-arch','memorial','waystone','bridge-bay']:
        stone_finish.apply(obj,OUT/'textures/ash-stone-colour.png')
    if any(mat.name.startswith('Foliage /') for mat in materials):
        assert obj.data.uv_layers and obj.data.uv_layers[0].name == 'UVMap'
        uv=obj.data.uv_layers[0].data
        leaf_uvs={tuple(uv[loop].uv) for p in obj.data.polygons
            if obj.data.materials[p.material_index].name.startswith('Foliage /')
            for loop in p.loop_indices}
        assert len(leaf_uvs)>16, 'Leaf UVs collapsed during stem/card join'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(MASTERS/(name+'.blend')))
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_apply=True,export_texcoords=True,export_normals=True,export_materials='EXPORT')
    coords=[tuple(v.co) for v in obj.data.vertices]
    bounds=[[round(min(v[i] for v in coords),4),round(max(v[i] for v in coords),4)] for i in range(3)]
    MANIFEST.append({'id':name,'file':name+'.glb','source':'tools/map_atelier/journey/sources/'+name+'.blend','description':description,'triangles':triangles,'materials':len(materials),'blender_xyz_bounds':bounds,'grounded':grounded})
    print('JOURNEY_ASSET',name,triangles,len(materials),flush=True)

for builder in [arch,conifer,copse,rock,memorial,waystone,bridge,lamp_pair]:builder()
foliage.conifer(reset, rod, mesh, save, BARK, OUT, slender=True)
foliage.copse(reset, rod, mesh, save, BARK, OUT, spreading=True)
rock(ridge=True)
natural_variants.build(reset, rod, mesh, bevel, save, BARK, STONE, OUT)
(OUT/'manifest.json').write_text(json.dumps({'status':'Step 3 sample; awaiting native visual review','generator':'tools/map_atelier/journey/build_kit.py','seed':7403,'assets':MANIFEST},indent=2)+'\n')
print('JOURNEY_KIT_OK',len(MANIFEST),flush=True)
