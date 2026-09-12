"""Dimensional branches carrying curved painterly foliage cards.

Each atlas quadrant is a complete twig; the transparent gaps remain real gaps.
Woody stems are geometry, and cards occupy several heights and orientations.
"""
from pathlib import Path
import math
import random
import bpy
from mathutils import Vector


def leaf_material(path, name):
    assert Path(path).is_file(), 'Missing authored foliage atlas: ' + str(path)
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = False
    shader = mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Roughness'].default_value = .96
    shader.inputs['Metallic'].default_value = 0
    tex = mat.node_tree.nodes.new('ShaderNodeTexImage')
    tex.image = bpy.data.images.load(str(path), check_existing=True)
    mat.node_tree.links.new(tex.outputs['Color'], shader.inputs['Base Color'])
    mat.node_tree.links.new(tex.outputs['Alpha'], shader.inputs['Alpha'])
    mat.surface_render_method = 'DITHERED'
    return mat


def spray(mesh, root, direction, length, width, drop, variant, mat):
    root = Vector(root)
    direction = Vector(direction).normalized()
    side = Vector((-direction.y, direction.x, 0)).normalized()
    vertices = []
    uvs = []
    column, row = variant % 2, variant // 2
    for t in [0, .4, .75, 1]:
        centre = root + direction * length * t + Vector((0,0,drop*t*t))
        for u in [0, .5, 1]:
            p = centre + side * width * (u-.5)
            p.z += .07 * math.sin(math.pi*t) * (1-abs(u-.5)*2)
            vertices.append(tuple(p))
            uvs.append(((column+u)/2, (row+t)/2))
    faces = []
    for j in range(3):
        for k in range(2):
            a = j*3+k
            faces.append((a,a+3,a+4,a+1))
    obj = mesh('Curved foliage spray',vertices,faces,[mat])
    # Match the primitive stems' layer name before joining. Otherwise glTF's
    # default TEXCOORD_0 is empty on leaves and samples transparent atlas corners.
    uv = obj.data.uv_layers.new(name='UVMap')
    for polygon in obj.data.polygons:
        for loop in polygon.loop_indices:
            uv.data[loop].uv = uvs[obj.data.loops[loop].vertex_index]


def conifer(reset, rod, mesh, save, bark, out, slender=False):
    reset()
    rng = random.Random(7491 if slender else 7461)
    mat = leaf_material(out/'textures/conifer-sprays.png','Foliage / charcoal sprays')
    trunk = [Vector((.065*math.sin(i*.8), .045*math.cos(i),i*.79)) for i in range(9)]
    for i in range(8):
        rod('Crooked charcoal trunk',trunk[i],trunk[i+1],.105*(1-i/9),bark,7,.105*(1-(i+1)/9))
    for tier,z in enumerate([1.10,1.87,2.58,3.25,3.91,4.51,5.05,5.57,5.96]):
        reach = (1.18 if slender else 1.70) * (1-z/7.1)**.72
        count = (4 if tier % 3 else 3) if slender else (7 if tier < 5 else 5)
        for branch in range(count):
            angle = branch*math.tau/count+tier*2.39996+rng.uniform(-.3,.3)
            direction = Vector((math.cos(angle),math.sin(angle),rng.uniform(.06,.23)))
            root = Vector((.055*math.sin(z),0,z+rng.uniform(-.14,.14)))
            length = reach*rng.uniform(.72,1.14)
            drop = -length*rng.uniform(.28,.49)
            end = root+direction*length+Vector((0,0,drop))
            rod('Sweeping bough',root,end,.025*(1-tier/12),bark,5,.005)
            spray(mesh,root,direction,length,length*1.05,drop,rng.randrange(4),mat)
            # A shorter, rising spray gives each bough volume at oblique views.
            lifted = Vector((direction.x,direction.y,.62))
            spray(mesh,root,lifted,length*.76,length*.83,-length*.12,rng.randrange(4),mat)
    for i in range(5):
        z=.58+i*.32; angle=i*2.4
        root=(0,0,z)
        tip=(math.cos(angle)*.6,math.sin(angle)*.6,z-.22)
        rod('Bare lower twig',root,tip,.02,bark,5,.004)
    save('conifer-spire' if slender else 'conifer','Sparse asymmetrical charcoal conifer with curved painted twig cards',4000)


def copse(reset, rod, mesh, save, bark, out, spreading=False):
    reset()
    rng = random.Random(7492 if spreading else 7462)
    mat = leaf_material(out/'textures/ash-twigs.png','Foliage / ash-red twigs')
    for stem in range(9 if spreading else 6):
        angle=stem*2.39996
        base=Vector((math.cos(angle)*(.65 if spreading else .40),math.sin(angle)*(.43 if spreading else .27),0))
        tip=base+Vector((math.cos(angle)*.19,math.sin(angle)*.19,rng.uniform(.32,.62) if spreading else rng.uniform(.7,1.28)))
        rod('Ash stem',base,tip,.035,bark,6,.008)
        for branch in range(5):
            azimuth=angle+branch*2.39996
            direction=Vector((math.cos(azimuth),math.sin(azimuth),rng.uniform(.12,.65)))
            root=base.lerp(tip,.48+branch*.10)
            length=rng.uniform(.52,.83)
            end=root+direction*length
            rod('Ash twig',root,end,.012,bark,5,.003)
            spray(mesh,root,direction,length,length*.94,-.12,rng.randrange(4),mat)
    save('ash-heath' if spreading else 'ash-copse','Open ash-red shrub with woody stems and layered painted leaf sprays',2500)
