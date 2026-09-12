"""Act IV metre-scale kit. Blender Z-up, front -Y, converted to Godot +Z.
Deterministic construction only; no external scripts, textures or services.
Run blender --background --python tools/map_workshop/act4/build_kit.py.
"""
import math
from pathlib import Path
import bpy
from mathutils import Vector
OUT=Path(__file__).resolve().parent/'kit'

def material(name,rgb,rough=.7,emit=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*rgb,1);m.use_nodes=True
 n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*rgb,1);n.inputs['Roughness'].default_value=rough
 if emit:n.inputs['Emission Color'].default_value=(*rgb,1);n.inputs['Emission Strength'].default_value=emit
 return m
STONE=material('Charcoal dressed stone',(.027,.032,.046))
EDGE=material('Worn pale arris',(.052,.061,.079))
DARK=material('Deep recess',(.018,.022,.028))
BRONZE=material('Tarnished bronze tracery',(.12,.095,.055),.45)
TEAL=material('Faint teal glass',(.025,.25,.26),.3,.35)
AMBER=material('Old amber glass',(.75,.31,.035),.3,.25)
FIRE=material('Hearth coals',(.95,.30,.025),.6,1.1)
GLASS=[material('Amber pane '+str(i),(.50+.065*i,.18+.038*i,.025+.012*i),.32,.25) for i in range(5)]
COURSES=[material('Stone course '+str(i),(.021+.004*i,.026+.004*i,.039+.005*i)) for i in range(4)]

def mesh(name,verts,faces,mat=STONE):
 d=bpy.data.meshes.new(name);d.from_pydata(verts,[],faces);d.update();o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);o.data.materials.append(mat);return o

def bevel(o,width=.035):
 bpy.context.view_layer.objects.active=o
 m=o.modifiers.new('Dressed edge','BEVEL');m.width=width;m.segments=1
 bpy.ops.object.modifier_apply(modifier=m.name)
 return o

def box(name,p,size,mat=STONE,b=.04):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(mat)
 return bevel(o,b) if b else o

def beam(name,a,b,r=.07,mat=BRONZE):
 delta=Vector(b)-Vector(a);o=box(name,(Vector(a)+Vector(b))*.5,(r,r,delta.length),mat,min(.02,r*.2));o.rotation_euler=delta.to_track_quat('Z','Y').to_euler();return o

def ring(name,centre,inner,outer,depth,mat=EDGE,count=64,begin=0,end=math.tau):
 verts=[];faces=[]
 for i in range(count+1):
  a=begin+(end-begin)*i/count
  for r,y in [(inner,-depth),(outer,-depth),(inner,0),(outer,0)]:verts.append((centre[0]+r*math.cos(a),centre[1]+y,centre[2]+r*math.sin(a)))
 for i in range(count):
  j=4*i;faces.extend([(j,j+4,j+5,j+1),(j+2,j+3,j+7,j+6),(j,j+2,j+6,j+4),(j+1,j+5,j+7,j+3)])
 faces.extend([(0,1,3,2),(4*count+2,4*count+3,4*count+1,4*count)])
 return bevel(mesh(name,verts,faces,mat),.025)

def window():
 # A real aperture through a 2.6m wall. Front and back share exact boundary.
 centre=13.5;radius=7.3;vs=[];faces=[];count=192
 for i in range(count):
  a=math.tau*i/count;dx,dz=math.cos(a),math.sin(a)
  reach=min(12/max(abs(dx),1e-7),(25-centre if dz>0 else centre)/max(abs(dz),1e-7))
  for x,z,y in [(radius*dx,centre+radius*dz,-1.3),(reach*dx,centre+reach*dz,-1.3),(radius*dx,centre+radius*dz,1.3),(reach*dx,centre+reach*dz,1.3)]:vs.append((x,y,z))
 for i in range(count):
  j=4*i;k=4*((i+1)%count);faces.extend([(j,k,k+1,j+1),(j+2,j+3,k+3,k+2),(j,j+2,k+2,k),(j+1,k+1,k+3,j+3)])
 bevel(mesh('Thick aperture wall',vs,faces),.07)
 for row in range(32):
  z=.39+row*.77
  for col in range(14):
   x=-12+col*1.85+(row%2)*.925
   left,right=max(-12,x-.90),min(12,x+.90)
   if right-left<.25:continue
   nearest_x=max(left,min(0,right));nearest_z=max(z-.36,min(centre,z+.36))
   if math.hypot(nearest_x,nearest_z-centre)<7.7:continue
   box('Shallow dressed course',((left+right)/2,-1.34,z),(right-left,.18,.72),COURSES[(row+col*3)%4],.045)
 crest=[(-12,25.4),(-8.8,25.4),(-7.5,26.2),(-2.3,26.2),(0,25.8),(1.4,26.4),(4.9,26.4),(6.2,25.7),(9.4,25.7),(12,25.2)]
 for i in range(len(crest)-1):
  x0,z0=crest[i];x1,z1=crest[i+1]
  vs=[(x0,-1.3,24.6),(x1,-1.3,24.6),(x1,-1.3,z1),(x0,-1.3,z0),(x0,1.3,24.6),(x1,1.3,24.6),(x1,1.3,z1),(x0,1.3,z0)]
  bevel(mesh('Fractured upper silhouette',vs,[(0,1,2,3),(7,6,5,4),(0,4,5,1),(1,5,6,2),(2,6,7,3),(3,7,4,0)],COURSES[i%4]),.045)
 for x in [-11.7,11.7]:
  box('Buttress broad foot',(x,-.4,.6),(4.2,5.4,1.2),EDGE)
  box('Recessed buttress',(x,-.1,10),(2.1,3.9,20))
  for z,w,d in [(1.4,3.5,4.8),(6,2.5,4.3),(17,2.4,4.2),(20.2,2.65,4.3)]:box('Buttress collar',(x,-.2,z),(w,d,.4),EDGE)
  for side in [-1,1]:box('Slender buttress shaft',(x+side*.72,-2.14,10.7),(.2,.2,17),EDGE,.025)
 for inner,outer,depth in [(7.3,8.15,.42),(6.95,7.28,.25),(8.2,8.37,.16)]:ring('Window moulding',(0,-1.38,centre),inner,outer,depth)
 for i in range(48):
  a=math.tau*i/48;b=a+math.tau/48*.91
  ring('Radial voussoir',(0,-1.42,centre),7.45,8.0,.48,COURSES[i%4],2,a,b)
 disk=[(0,-.95,centre)]+[(6.95*math.cos(math.tau*i/96),-.95,centre+6.95*math.sin(math.tau*i/96)) for i in range(96)]
 mesh('Dark glass between petals',disk,[(0,i+1,(i+1)%96+1) for i in range(96)],material('Unlit amber glass',(.055,.026,.012),.32))
 for petal in range(6):
  a=math.tau*petal/6+math.pi/2;d=Vector((math.cos(a),math.sin(a)));side=Vector((-d.y,d.x));c=Vector((0,centre))+d*3.5
  points=[]
  for i in range(49):
   t=math.tau*i/48;p=c+d*3.22*math.cos(t)+side*1.72*math.sin(t);points.append((p.x,-1.40,p.y))
  for i in range(48):
   mesh('Quiet amber pane',[(c.x,-1.4,c.y),points[i],points[i+1]],[(0,1,2)],GLASS[(i//8+petal)%5])
   beam('Petal lead',points[i],points[i+1],.15)
  for i in [4,12,20,28,36,44]:beam('Pane division',(c.x,-1.43,c.y),points[i],.045)
 ring('Central seal',(0,-1.56,centre),.75,1.18,.25,BRONZE,40)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.74,location=(0,-1.48,centre));o=bpy.context.object;o.scale.y=.2;o.data.materials.append(AMBER)


def stele():
 box('Stele foot',(0,0,.12),(1.4,1,.24),EDGE)
 verts=[(-.48,-.24,.2),(.48,-.24,.2),(.48,-.24,2.3),(0,-.24,2.85),(-.48,-.24,2.3)]
 verts+= [(x,.24,z) for x,y,z in verts]
 faces=[(0,1,2,3,4),(9,8,7,6,5)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
 bevel(mesh('Standing walker',verts,faces),.055)
 box('Teal memory',(0,-.255,1.8),(.12,.05,1.0),TEAL,.015)
 box('Glass socket',(0,-.29,1.2),(.27,.13,.15),EDGE,.025)


def hearth():
 for row in range(6):
  for col in range(10):
   x=-4.5+col*.95+(row%2)*.2
   if abs(x)<1.55 and row<4:continue
   box('Hearth wall stone',(x,0,.36+row*.66),(.9,1.7,.62),COURSES[(row+col)%4],.055)
 box('Hearth sill',(0,-1.0,.2),(5.2,3,.4),EDGE)
 for x in [-1.75,1.75]:box('Hearth surround',(x,-1.2,1.5),(.65,1.2,2.6),EDGE)
 box('Hearth lintel',(0,-1.2,3),(4.3,1.4,.65),EDGE)
 box('Black recess',(0,.5,1.4),(2.8,.15,2.4),DARK)
 for i in range(7):
  o=box('Banked glowing coal',((i-3)*.33,-.6,.48+((i*5)%3)*.08),(.4,.38,.25),FIRE,.07);o.rotation_euler.z=i*.7
 # Small seated hooded effigy beside the hearth, no face or living figure claim.
 x=3.0
 box('Effigy seat',(x,-1.1,.55),(1.25,1.2,1.1))
 bpy.ops.mesh.primitive_cone_add(vertices=8,radius1=.68,radius2=.38,depth=1.5,location=(x,-1.1,1.5));bpy.context.object.data.materials.append(STONE)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=8,radius=.48,location=(x,-1.1,2.55));bpy.context.object.scale=(1,.85,1.1);bpy.context.object.data.materials.append(STONE)
 box('Hood shadow',(x,-1.50,2.48),(.46,.05,.53),DARK,.1)


def export(name,build):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 build();bpy.ops.object.select_all(action='SELECT');bpy.context.view_layer.objects.active=next(o for o in bpy.context.scene.objects if o.type=='MESH');bpy.ops.object.join();o=bpy.context.object;o.name=name
 # Ensure the asset origin is its authored base, not the last component centre.
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False);bpy.ops.object.mode_set(mode='OBJECT')
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_apply=True,export_yup=True)
 o.data.calc_loop_triangles();print('MIRROR_ASSET',name,len(o.data.loop_triangles))
OUT.mkdir(exist_ok=True)
for name,builder in [('threshold-window',window),('memory-stele',stele),('other-side-hearth',hearth)]:export(name,builder)
