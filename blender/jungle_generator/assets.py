import sys, math, random
sys.path.insert(0, '/tmp/claude-0/jungle')
from jl import *
from mathutils import Vector

def heart(t):   return 0.42*math.sin(math.pi*min(1, t*1.05)) * (1.1 - 0.4*t)
def paddle(t):  return 0.16*math.sin(math.pi*t)**0.7
def arrow(t):   return 0.5*(1-t)**0.9 * min(1, t*6) if t > 0 else 0
def frond(t):   return 0.09*math.sin(math.pi*t)
def oval(t):    return 0.3*math.sin(math.pi*t)**0.8

def monstera():
    rnd = random.Random(1); B = Builder('monstera')
    for k in range(7):
        a = 2*math.pi*k/7 + rnd.uniform(-0.2, 0.2)
        h = rnd.uniform(0.9, 1.5); out = rnd.uniform(0.4, 0.75)
        tip = Vector((math.cos(a)*out, math.sin(a)*out, h))
        tube(B, curve((0, 0, 0), tip, (0, 0, 0.15), 4), [0.035, 0.03, 0.025, 0.022, 0.02], 'leaf_dark', sides=5)
        split_leaf(B, tip, (math.cos(a), math.sin(a), rnd.uniform(-0.1, 0.25)), rnd.uniform(0.75, 1.0),
                   'leaf' if k % 3 else 'leaf_dark', droop=0.35)
    return [B.finish()]

def elephant_ear():
    rnd = random.Random(2); B = Builder('elephant_ear')
    for k in range(5):
        a = 2*math.pi*k/5 + rnd.uniform(-0.25, 0.25)
        h = rnd.uniform(1.4, 2.2); out = rnd.uniform(0.3, 0.6)
        tip = Vector((math.cos(a)*out, math.sin(a)*out, h))
        tube(B, curve((0, 0, 0), tip, (0, 0, 0.1), 4), [0.06, 0.05, 0.04, 0.035, 0.03], 'leaf', sides=6)
        # großes Pfeilblatt hängt nach vorn/unten
        leaf(B, tip, (math.cos(a), math.sin(a), 0.35), rnd.uniform(1.3, 1.7), arrow,
             'leaf_light' if k % 2 else 'leaf', n=6, droop=0.55, fold=0.06)
    return [B.finish()]

def heliconia():
    rnd = random.Random(3); B = Builder('heliconia')
    for k in range(6):
        a = 2*math.pi*k/6 + rnd.uniform(-0.3, 0.3)
        h = rnd.uniform(1.2, 1.9); out = rnd.uniform(0.15, 0.35)
        tip = Vector((math.cos(a)*out, math.sin(a)*out, h))
        tube(B, curve((0, 0, 0), tip, (0, 0, 0), 3), [0.04, 0.035, 0.03, 0.025], 'leaf_dark', sides=5)
        leaf(B, tip, (math.cos(a), math.sin(a), 1.4), rnd.uniform(1.0, 1.3), paddle, 'leaf', n=6, droop=0.35, twist=0.4)
    # zwei hängende Blütenstände (Hummerschere): Zickzack aus roten/gelben Hochblättern
    for k in range(2):
        a = math.pi*k + 0.6
        top = Vector((math.cos(a)*0.35, math.sin(a)*0.35, 1.75))
        tube(B, curve((0, 0, 0), top, (0, 0, 0), 3), [0.03, 0.025, 0.02, 0.02], 'leaf_dark', sides=5)
        p = top.copy()
        for i in range(7):
            side = 1 if i % 2 else -1
            nxt = p + Vector((0, 0, -0.12))
            out = Vector((math.cos(a+side*0.5), math.sin(a+side*0.5), 0))*0.16
            B.face([p, p + out + Vector((0, 0, 0.03)), nxt + out*0.4], 'flower_red')
            B.face([p + out + Vector((0, 0, 0.03)), p + out*1.05 + Vector((0, 0, 0.05)), nxt + out*0.4], 'flower_yellow')
            p = nxt
    return [B.finish()]

def bird_of_paradise():
    rnd = random.Random(4); B = Builder('bird_of_paradise')
    for k in range(7):
        a = 2*math.pi*k/7 + rnd.uniform(-0.2, 0.2)
        h = rnd.uniform(0.6, 1.0)
        tip = Vector((math.cos(a)*0.15, math.sin(a)*0.15, h))
        tube(B, [Vector((0, 0, 0)), tip], [0.025, 0.02], 'leaf_dark', sides=5)
        leaf(B, tip, (math.cos(a), math.sin(a), 2.0), rnd.uniform(0.5, 0.7), oval, 'leaf', n=5, droop=0.25)
    for k in range(3):
        a = 2*math.pi*k/3 + 0.3
        top = Vector((math.cos(a)*0.2, math.sin(a)*0.2, 1.15 + 0.1*k))
        tube(B, [Vector((0, 0, 0)), top], [0.02, 0.015], 'leaf_dark', sides=5)
        d = Vector((math.cos(a+1.4), math.sin(a+1.4), 0.15)).normalized()
        beak = top + d*0.32
        B.face([top, beak, top + Vector((0, 0, -0.05)) + d*0.1], 'leaf_dark')   # Schnabel
        for i, c in enumerate(['flower_orange', 'flower_orange', 'flower_blue', 'flower_orange']):
            fan = top + d*0.08 + Vector((0, 0, 0.02))
            tipf = fan + Vector((0, 0, 0.32 - 0.05*i)) + d*(0.04*i - 0.05) + d.cross(Vector((0, 0, 1)))*(0.06*(i-1.5))
            B.face([fan, fan + d*0.07, tipf], c)
    return [B.finish()]

def tree_fern():
    rnd = random.Random(5); B = Builder('tree_fern')
    trunk = curve((0, 0, 0), (0.25, 0.1, 3.4), (0.15, 0, 0), 6)
    tube(B, trunk, [0.2, 0.17, 0.15, 0.14, 0.14, 0.15, 0.17], 'bark', sides=7)
    top = trunk[-1]
    for k in range(11):
        a = 2*math.pi*k/11 + rnd.uniform(-0.15, 0.15)
        d = Vector((math.cos(a), math.sin(a), rnd.uniform(0.3, 0.7)))
        L = rnd.uniform(1.8, 2.3)
        # Wedel: Mittelrippe + Fiederblättchen
        o, dd, s, n = frame(top, d)
        pts = [o + dd*(L*t) - Vector((0, 0, 1))*(0.7*L*t*t) for t in [i/8 for i in range(9)]]
        tube(B, pts, [0.025]*8 + [0.005], 'vine', sides=4, cap=False)
        for i in range(1, 8):
            w = 0.32*math.sin(math.pi*i/8)
            for side in (-1, 1):
                B.face([pts[i], pts[i] + s*side*w + dd*0.06 - Vector((0, 0, 0.05)), pts[i+1]], 'palm_leaf' if k % 2 else 'leaf')
    return [B.finish()]

def bamboo():
    rnd = random.Random(6); B = Builder('bamboo_cluster')
    for k in range(8):
        a = rnd.uniform(0, 2*math.pi); r = rnd.uniform(0.1, 0.55)
        base = Vector((math.cos(a)*r, math.sin(a)*r, 0)); H = rnd.uniform(4.5, 7.0)
        lean = Vector((math.cos(a), math.sin(a), 0))*rnd.uniform(0.3, 0.9)
        segs = int(H/0.6)
        pts = [base + Vector((0, 0, H*i/segs)) + lean*((i/segs)**2) for i in range(segs+1)]
        rad = rnd.uniform(0.05, 0.075)
        for i in range(segs):
            tube(B, [pts[i], pts[i+1]], [rad, rad*0.97], 'bamboo', sides=6, cap=False)
            tube(B, [pts[i+1] - Vector((0, 0, 0.02)), pts[i+1] + Vector((0, 0, 0.02))], [rad*1.12, rad*1.12], 'bamboo_ring', sides=6, cap=False)
            if i > segs*0.45 and rnd.random() < 0.6:
                for j in range(3):
                    aa = rnd.uniform(0, 2*math.pi)
                    leaf(B, pts[i+1], (math.cos(aa), math.sin(aa), -0.2), rnd.uniform(0.35, 0.5), lambda t: 0.1*math.sin(math.pi*t),
                         'leaf_light' if j == 0 else 'leaf', n=3, droop=0.3)
    return [B.finish()]

def giant_tree():
    rnd = random.Random(7); B = Builder('giant_tree')
    trunk = curve((0, 0, 0), (0.3, 0, 13.0), (0.4, 0.2, 0), 8)
    tube(B, trunk, [1.0, 0.85, 0.75, 0.68, 0.62, 0.58, 0.55, 0.5, 0.45], 'bark', sides=9)
    # Brettwurzeln
    for k in range(6):
        a = 2*math.pi*k/6 + rnd.uniform(-0.2, 0.2)
        dirv = Vector((math.cos(a), math.sin(a), 0)); side = Vector((-math.sin(a), math.cos(a), 0))
        out = rnd.uniform(2.2, 3.0); h = rnd.uniform(2.4, 3.2); t = 0.12
        p0, p1, p2 = dirv*0.6 + Vector((0, 0, h)), dirv*out + Vector((0, 0, -0.1)), dirv*0.6 + Vector((0, 0, -0.1))
        mid = dirv*(out*0.45) + Vector((0, 0, h*0.35))
        for sgn in (-1, 1):
            off = side*t*sgn
            B.face([p2 + off, p1 + off, mid + off, p0 + off] if sgn > 0 else [p0 + off, mid + off, p1 + off, p2 + off], 'bark_light')
        B.strip([[p0 - side*t, mid - side*t, p1 - side*t], [p0 + side*t, mid + side*t, p1 + side*t]], 'bark_light')
    # Äste + flache, breite Krone aus Blätterklumpen
    top = trunk[-1]
    for k in range(5):
        a = 2*math.pi*k/5 + rnd.uniform(-0.3, 0.3)
        end = top + Vector((math.cos(a)*4.5, math.sin(a)*4.5, rnd.uniform(0.5, 1.8)))
        start = trunk[-3]
        tube(B, curve(start, end, (0, 0, 0.8), 3), [0.35, 0.28, 0.2, 0.15], 'bark', sides=6)
        for j in range(3):
            c = end + Vector((rnd.uniform(-1.4, 1.4), rnd.uniform(-1.4, 1.4), rnd.uniform(-0.2, 0.6)))
            lump(B, c, (rnd.uniform(2.0, 2.8), rnd.uniform(2.0, 2.8), rnd.uniform(1.0, 1.4)), rnd.choice(['leaf', 'leaf_dark', 'leaf_light', 'leaf']), rnd)
    lump(B, top + Vector((0, 0, 1.4)), (3.2, 3.2, 1.6), 'leaf', rnd)
    # ein paar hängende Lianen
    for k in range(7):
        a = rnd.uniform(0, 2*math.pi); r = rnd.uniform(2.5, 5.0)
        p = top + Vector((math.cos(a)*r, math.sin(a)*r, -0.5))
        L = rnd.uniform(3, 7)
        tube(B, curve(p, p + Vector((0.2, 0, -L)), (0.15, 0.1, 0), 4), [0.04]*5, 'vine', sides=4)
    return [B.finish()]

def vine_curtain():
    rnd = random.Random(8); B = Builder('vine_curtain')
    W = 4.0
    tube(B, curve((-W/2, 0, 0), (W/2, 0, 0), (0, 0, -0.15), 6), [0.06]*7, 'vine', sides=5)
    for k in range(13):
        x = -W/2 + W*k/12 + rnd.uniform(-0.1, 0.1)
        L = rnd.uniform(1.5, 3.8)
        top = Vector((x, 0, -0.05 - 0.15*4*((x+W/2)/W)*(1-(x+W/2)/W)))
        pts = curve(top, top + Vector((rnd.uniform(-0.2, 0.2), rnd.uniform(-0.1, 0.1), -L)), (0.1, 0.05, 0), 5)
        tube(B, pts, [0.03]*6, 'vine', sides=4)
        for p in pts[1:]:
            if rnd.random() < 0.8:
                d = Vector((rnd.uniform(-1, 1), rnd.uniform(-0.3, -1) if rnd.random() < 0.5 else rnd.uniform(0.3, 1), -0.6))
                leaf(B, p, d, rnd.uniform(0.18, 0.28), lambda t: 0.3*math.sin(math.pi*t), rnd.choice(['leaf', 'leaf_light', 'leaf_dark']), n=3, droop=0.1)
    return [B.finish()]

def dense_bush():
    rnd = random.Random(9); B = Builder('jungle_bush_dense')
    for k in range(9):
        a = rnd.uniform(0, 2*math.pi); r = rnd.uniform(0, 0.9)
        lump(B, (math.cos(a)*r, math.sin(a)*r, rnd.uniform(0.5, 1.2)), (rnd.uniform(0.6, 0.9), rnd.uniform(0.6, 0.9), rnd.uniform(0.5, 0.7)),
             rnd.choice(['leaf', 'leaf_dark', 'leaf', 'leaf_light']), rnd)
    for k in range(14):  # abstehende Blätter am Rand
        a = 2*math.pi*k/14
        p = Vector((math.cos(a)*1.0, math.sin(a)*1.0, rnd.uniform(0.3, 1.0)))
        leaf(B, p, (math.cos(a), math.sin(a), 0.3), rnd.uniform(0.5, 0.8), oval, rnd.choice(['leaf', 'leaf_dark']), n=4, droop=0.3)
    return [B.finish()]

def ground_leaves():
    rnd = random.Random(10); B = Builder('ground_leaves')
    for k in range(12):
        a = 2*math.pi*k/12 + rnd.uniform(-0.2, 0.2)
        tip = Vector((math.cos(a)*0.15, math.sin(a)*0.15, rnd.uniform(0.15, 0.4)))
        tube(B, [Vector((0, 0, 0)), tip], [0.015, 0.012], 'leaf_dark', sides=4)
        L = rnd.uniform(0.4, 0.6)
        leaf(B, tip, (math.cos(a), math.sin(a), 0.6), L, oval, 'leaf_dark', n=5, droop=0.3)
        # helle Mittelstreifen (Calathea-Muster)
        leaf(B, tip + Vector((0, 0, 0.012)), (math.cos(a), math.sin(a), 0.6), L*0.92, lambda t: 0.08*math.sin(math.pi*t), 'leaf_stripe', n=5, droop=0.3*1.05)
    return [B.finish()]

ASSETS = {
 'monstera': monstera, 'elephant_ear': elephant_ear, 'heliconia': heliconia, 'bird_of_paradise': bird_of_paradise,
 'tree_fern': tree_fern, 'bamboo_cluster': bamboo, 'giant_tree': giant_tree, 'vine_curtain': vine_curtain,
 'jungle_bush_dense': dense_bush, 'ground_leaves': ground_leaves,
}

if __name__ == '__main__':
    import json
    stats = {}
    for name, fn in ASSETS.items():
        reset(); objs = fn()
        export(objs, f'/tmp/claude-0/jungle/out/{name}.glb')
        stats[name] = (sum(len(o.data.polygons) for o in objs), [round(x, 2) for x in objs[0].dimensions])
    print(json.dumps(stats, indent=0))
