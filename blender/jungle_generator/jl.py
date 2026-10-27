# Low-Poly Dschungel-Asset-Generator (Blender bpy), Farben passend zu assets/nature
import bpy, bmesh, math, random
from mathutils import Vector, Matrix

PAL = {
 'leaf_dark': (0.012, 0.102, 0.016), 'leaf': (0.031, 0.216, 0.024), 'leaf_light': (0.188, 0.447, 0.039),
 'palm_leaf': (0.063, 0.294, 0.031), 'vine': (0.059, 0.141, 0.02), 'bark': (0.118, 0.059, 0.024),
 'bark_light': (0.263, 0.173, 0.082), 'moss': (0.075, 0.196, 0.024), 'flower_red': (0.749, 0.016, 0.012),
 'flower_yellow': (0.957, 0.604, 0.02), 'flower_orange': (0.95, 0.28, 0.01), 'flower_blue': (0.05, 0.12, 0.6),
 'flower_pink': (0.827, 0.102, 0.216), 'bamboo': (0.25, 0.42, 0.06), 'bamboo_ring': (0.13, 0.22, 0.03),
 'leaf_stripe': (0.3, 0.5, 0.12),
}
_mats = {}
def mat(name):
    if name in _mats: return _mats[name]
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    b.inputs['Base Color'].default_value = (*PAL[name], 1); b.inputs['Roughness'].default_value = 0.85
    m.use_backface_culling = False
    _mats[name] = m; return m

class Builder:
    """sammelt Geometrie je Material in einem bmesh"""
    def __init__(self, name):
        self.name = name; self.bm = bmesh.new(); self.mats = []
    def mi(self, m):
        if m not in self.mats: self.mats.append(m)
        return self.mats.index(m)
    def face(self, verts, m):
        vs = [self.bm.verts.new(v) for v in verts]
        f = self.bm.faces.new(vs); f.material_index = self.mi(m); return f
    def strip(self, rows, m, close=False):
        """rows: Liste von Punktreihen gleicher Länge -> Quads dazwischen"""
        R = [[self.bm.verts.new(p) for p in row] for row in rows]
        mi = self.mi(m)
        n = len(R[0])
        for a, b in zip(R, R[1:]):
            for i in range(n - (0 if close else 1)):
                j = (i + 1) % n
                f = self.bm.faces.new((a[i], a[j], b[j], b[i])); f.material_index = mi
        return R
    def finish(self):
        me = bpy.data.meshes.new(self.name); self.bm.to_mesh(me); self.bm.free()
        for m in self.mats: me.materials.append(mat(m))
        for p in me.polygons: p.use_smooth = False
        o = bpy.data.objects.new(self.name, me); bpy.context.scene.collection.objects.link(o); return o

def frame(origin, direction, up=Vector((0, 0, 1))):
    d = Vector(direction).normalized()
    side = d.cross(up)
    if side.length < 1e-4: side = Vector((1, 0, 0))
    side.normalize(); nrm = side.cross(d).normalized()
    return Vector(origin), d, side, nrm

def tube(B, pts, radii, m, sides=6, cap=True):
    rows = []
    for i, p in enumerate(pts):
        d = (pts[min(i+1, len(pts)-1)] - pts[max(i-1, 0)]).normalized()
        _, d, s, n = frame(p, d, Vector((0, 1, 0)) if abs(d.z) > 0.95 else Vector((0, 0, 1)))
        rows.append([p + (s*math.cos(2*math.pi*k/sides) + n*math.sin(2*math.pi*k/sides))*radii[i] for k in range(sides)])
    R = B.strip(rows, m, close=True)
    if cap and radii[-1] > 0.001:
        f = B.bm.faces.new(R[-1]); f.material_index = B.mi(m)
    return R

def curve(p0, p1, sag, n):
    """Bogen von p0 nach p1, in der Mitte um 'sag' (Vector) verschoben"""
    p0, p1, sag = Vector(p0), Vector(p1), Vector(sag)
    return [p0.lerp(p1, t) + sag*4*t*(1-t) for t in [i/n for i in range(n+1)]]

def leaf(B, base, direction, length, width_fn, m, n=6, droop=0.3, fold=0.08, m_back=None, twist=0.0):
    """flaches Low-Poly-Blatt mit Mittelrippe; width_fn(t)->halbe Breite (relativ zur Länge)"""
    o, d, s, nrm = frame(base, direction)
    rows = []
    for i in range(n+1):
        t = i/n
        # Blatt biegt sich nach unten (droop) entlang der Länge
        p = o + d*(t*length) - Vector((0, 0, 1))*(droop*length*t*t)
        w = width_fn(t)*length
        sd = (s*math.cos(twist*t) + nrm*math.sin(twist*t))
        rows.append([p - sd*w + nrm*0.0, p + nrm*(fold*length*min(t*4, 1)*(1-t)), p + sd*w])
    B.strip(rows, m)

def split_leaf(B, base, direction, length, m, lobes=4, droop=0.25, width=0.42):
    """Monstera-Blatt: einzelne Lappen links/rechts mit Schlitzen"""
    o, d, s, nrm = frame(base, direction)
    def mid(t): return o + d*(t*length) - Vector((0, 0, 1))*(droop*length*t*t)
    for side in (-1, 1):
        for k in range(lobes):
            t0 = 0.08 + k*(0.86/lobes); t1 = t0 + 0.86/lobes*0.82
            sh = math.sin(math.pi*(0.25 + 0.75*(k+0.5)/lobes))  # Herzform
            w = width*length*sh
            back = 0.12*length
            a, b = mid(t0), mid(t1)
            oa = a + s*side*w + d*(back*0.2) - Vector((0, 0, 1))*w*0.25
            ob = b + s*side*w*0.85 + d*back - Vector((0, 0, 1))*w*0.3
            B.face([a, oa, ob, b] if side > 0 else [b, ob, oa, a], m)
    # Spitze
    B.face([mid(0.92), mid(0.92) + s*0.06*length, mid(1.0), mid(0.92) - s*0.06*length], m)

def lump(B, center, radii, m, rnd, sub=1):
    tmp = bmesh.new(); bmesh.ops.create_icosphere(tmp, subdivisions=sub, radius=1)
    for v in tmp.verts:
        j = 1 + rnd.uniform(-0.12, 0.12)
        v.co = Vector((v.co.x*radii[0]*j, v.co.y*radii[1]*j, v.co.z*radii[2]*j)) + Vector(center)
    me = bpy.data.meshes.new('tmp'); tmp.to_mesh(me); tmp.free()
    off = len(B.bm.faces); B.bm.from_mesh(me); bpy.data.meshes.remove(me)
    mi = B.mi(m); B.bm.faces.ensure_lookup_table()
    for f in B.bm.faces[off:]: f.material_index = mi

def export(objs, path):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs: o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_yup=True, use_selection=True)

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True); _mats.clear()
