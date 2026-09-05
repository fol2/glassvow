"""Six additional woodland forms with distinct structures, not rescaled copies."""
import math
import random
from mathutils import Vector
import foliage


def build(reset, rod, mesh, bevel, save, bark, stone, out):
    rng = random.Random(7617)
    needles = foliage.leaf_material(out/'textures/conifer-sprays.png', 'Foliage / wind-bent needles')
    leaves = foliage.leaf_material(out/'textures/ash-twigs.png', 'Foliage / thorn leaves')

    reset()
    trunk = [Vector(p) for p in [(0,0,0),(.05,.02,1.1),(.25,0,2.4),(.65,.08,3.6),(1.12,.06,4.6),(1.65,.1,5.4)]]
    for i in range(len(trunk)-1):
        rod('Wind-bent trunk', trunk[i], trunk[i+1], .18*(1-i/6), bark, 8, .14*(1-i/6))
    for level in range(6):
        root=trunk[1].lerp(trunk[-1],.08+level*.15)
        for branch in range(4):
            direction=Vector((.75+rng.random()*.3, (branch-1.5)*.62, .12))
            length=(1.6-level*.18)*rng.uniform(.8,1.1)
            end=root+direction*length+Vector((0,0,-.24*length))
            rod('Leeward branch',root,end,.04,bark,6,.008)
            foliage.spray(mesh,root,direction,length,length*.82,-.3*length,rng.randrange(4),needles)
            foliage.spray(mesh,root,Vector((direction.x,direction.y,.65)),length*.72,length*.8,-.15,rng.randrange(4),needles)
    save('conifer-wind','Leaning pine with a swept one-sided crown and exposed windward trunk',4000)

    reset()
    trunk=[Vector(p) for p in [(0,0,0),(.14,0,1.3),(-.08,.08,2.7),(.3,.04,4.1),(.22,.12,5.2)]]
    for i in range(4):
        rod('Old forked trunk',trunk[i],trunk[i+1],.22*(1-i/5),bark,8,.16*(1-i/5))
    for i in range(7):
        root=trunk[1].lerp(trunk[3],i/7)
        angle=i*2.4
        elbow=root+Vector((math.cos(angle)*1.05,math.sin(angle)*1.05,.35))
        tip=elbow+Vector((math.cos(angle)*.5,math.sin(angle)*.5,1.05))
        rod('Bare angular limb',root,elbow,.075,bark,7,.045)
        rod('Fork tip',elbow,tip,.045,bark,6,.008)
        rod('Broken side fork',elbow,elbow+Vector((math.cos(angle+.8)*.7,math.sin(angle+.8)*.7,.4)),.032,bark,5,.005)
    for angle in [0,1.5,3.0,4.5]:
        rod('Exposed root',(0,0,.2),(math.cos(angle)*.65,math.sin(angle)*.65,.025),.13,bark,7,.035)
    save('conifer-snag','Forked leafless woodland snag with exposed roots and angular limbs',2200)

    reset()
    for stem in range(7):
        angle=stem*2.39996+rng.uniform(-.35,.35)
        base=Vector((math.cos(angle)*rng.uniform(.08,.3),math.sin(angle)*rng.uniform(.08,.3),.03))
        elbow=base+Vector((math.cos(angle)*.4,math.sin(angle)*.4,rng.uniform(.55,.85)))
        tip=elbow+Vector((math.cos(angle)*.52,math.sin(angle)*.52,-.42))
        rod('Bowed thorn cane',base,elbow,.024,bark,5,.014)
        rod('Trailing thorn cane',elbow,tip,.014,bark,5,.004)
        for t in [.4,.7,1.0]:
            root=elbow.lerp(tip,t)
            direction=Vector((math.cos(angle+.8),math.sin(angle+.8),.05))
            foliage.spray(mesh,root,direction,.38,.30,-.07,stem%4,leaves)
    save('ash-bramble','Open arching thorn canes with sparse trailing ash-red leaves',2000)

    fern_mat = bark.copy()
    fern_mat.name = 'Fern / muted plum'
    fern_mat.diffuse_color = (.036,.022,.031,1)
    fern_mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value = (.036,.022,.031,1)
    reset()
    # Radial, divided fronds use actual narrow leaf geometry, not shrub cards.
    for frond in range(9):
        angle=frond*2.39996
        length=rng.uniform(.70,1.1)
        direction=Vector((math.cos(angle),math.sin(angle),0))
        side=Vector((-direction.y,direction.x,0))
        def at(t):
            return direction*length*t+Vector((0,0,.08+.50*math.sin(t*2.0)))
        previous=at(0)
        for j in range(1,8):
            t=j/8;centre=at(t)
            rod('Fern rachis',previous,centre,.013,bark,5,.008)
            previous=centre
            for sign in [-1,1]:
                width=.25*math.sin(math.pi*t)
                root=centre-direction*.09
                tip=centre+side*sign*width-direction*.11
                mid=(root+tip)*.5+Vector((0,0,.045))
                verts=[tuple(root),tuple(mid+direction*.045),tuple(tip),tuple(mid-direction*.04)]
                mesh('Divided fern leaflet',verts,[(0,1,2),(0,2,3)],[fern_mat])
    # A subdued mineral-plum frond remains in the woodland palette.
    save('ash-fern','Low radial fern with divided sculpted fronds and an open centre',2600)

    def shard(name, x,y,width,depth,height,lean,material):
        outline=[(-.6,-.35),(.15,-.55),(.62,-.12),(.40,.46),(-.46,.40)]
        verts=[(x+a*width,y+b*depth,0) for a,b in outline]
        verts += [(x+a*width*.68+lean,y+b*depth*.7,height+(a*.25)) for a,b in outline]
        faces=[(4,3,2,1,0),(5,6,7,8,9)]+[(i,(i+1)%5,(i+1)%5+5,i+5) for i in range(5)]
        bevel(mesh(name,verts,faces,[material]),.025)
    reset()
    shard('Tilted split blade',-.3,0,1.15,.8,2.0,.4,stone[0])
    shard('Broken blade foot',.6,-.1,.65,.9,.68,.05,stone[2])
    save('slate-shard','Narrow upright split slate blade with a low fractured foot',1200)
    reset()
    for i in range(9):
        angle=i*2.4;radius=.35+i*.13
        shard('Part-buried scree',math.cos(angle)*radius,math.sin(angle)*radius,.48+rng.random()*.3,.4+rng.random()*.25,.16+rng.random()*.18,.06,stone[i%4])
    save('slate-scree','Loose part-buried flat fragments in an irregular low fan',1800)
