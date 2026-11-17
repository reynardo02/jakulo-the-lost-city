"""Erzeugt die Level-3-Modelle neu in Blender und exportiert sie als GLB:

    assets/level3/monkey_v2.glb     sitzender Affe (organischer Körper, Gesicht, Schwanz)
    assets/level3/platform_v2.glb   Baumplattform aus einzelnen Planken mit Seilgeländer
    assets/level3/jewel_v2.glb      Juwel im Brillantschliff
    assets/level3/wood_planks.png   Plankentextur für Stege und Astgabeln (triplanar im Spiel)
    assets/level3/bark.png          Rindentextur für den Stamm des großen Baums

Fell- und Holzstrukturen sind prozedurale Blender-Shader, die in Texturen gebacken werden
(glTF kann keine Blender-Shader-Knoten). Dazu je ein Vorschaubild in tools/blender/previews/.

Aufruf (aus dem Projektordner):
    blender --background --python tools/blender/build_level3_assets.py

Am Ende steht in der Ausgabe PLATFORM_DECK_FROM_BOTTOM: der Anteil der Modellhöhe, auf dem das
Plattformdeck liegt (für tools/level3/build_level_3.gd).
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = {
    "monkey": os.path.join(ROOT, "assets", "level3", "monkey_v2.glb"),
    "platform": os.path.join(ROOT, "assets", "level3", "platform_v2.glb"),
    "jewel": os.path.join(ROOT, "assets", "level3", "jewel_v2.glb"),
    "planks": os.path.join(ROOT, "assets", "level3", "wood_planks.png"),
    "bark": os.path.join(ROOT, "assets", "level3", "bark.png"),
}
PREVIEWS = os.path.join(ROOT, "tools", "blender", "previews")
TEX_DIR = os.path.join(ROOT, "tools", "blender", "baked")

random.seed(7)


# ---------------------------------------------------------------- Grundlagen

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 24
    scene.cycles.bake_type = "DIFFUSE"
    scene.render.bake.use_pass_direct = False
    scene.render.bake.use_pass_indirect = False
    scene.render.bake.use_pass_color = True
    scene.render.bake.margin = 6


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def apply_all(obj):
    select_only([obj])
    for mod in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)


def join(objs, name):
    select_only(objs)
    bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.name = name
    obj.data.name = name
    return obj


def shade_smooth(obj, smooth=True):
    for poly in obj.data.polygons:
        poly.use_smooth = smooth


def sphere(name, loc, radius, scale=(1, 1, 1), segments=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    shade_smooth(obj)
    return obj


def cylinder(name, a, b, radius, verts=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=d.length, location=(a + b) / 2)
    obj = bpy.context.active_object
    obj.name = name
    obj.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def box(name, loc, size, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bev = obj.modifiers.new("Bevel", "BEVEL")
    bev.width = min(size) * 0.18
    bev.segments = 2
    apply_all(obj)
    return obj


def tube(name, points, radius, taper_end=1.0):
    """Gebogenes Rohr entlang von Punkten (Seil, Schwanz)."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    curve.resolution_u = 8
    spline = curve.splines.new("NURBS")
    spline.points.add(len(points) - 1)
    for i, p in enumerate(points):
        spline.points[i].co = (p[0], p[1], p[2], 1.0)
        spline.points[i].radius = 1.0 + (taper_end - 1.0) * i / (len(points) - 1)
    spline.use_endpoint_u = True
    spline.order_u = 3
    obj = link(bpy.data.objects.new(name, curve))
    select_only([obj])
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.active_object
    shade_smooth(obj)
    return obj


# ---------------------------------------------------------------- Materialien

def material(name, builder):
    """Material mit prozeduralem Shader; builder(nodes, links) liefert den Farbausgang."""
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    bsdf = nodes.new("ShaderNodeBsdfPrincipled")
    links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    color = builder(nodes, links)
    links.new(color, bsdf.inputs["Base Color"])
    return mat


def ramp(nodes, links, fac, stops):
    r = nodes.new("ShaderNodeValToRGB")
    els = r.color_ramp.elements
    els[0].position, els[0].color = stops[0][0], (*stops[0][1], 1)
    els[1].position, els[1].color = stops[-1][0], (*stops[-1][1], 1)
    for pos, col in stops[1:-1]:
        e = els.new(pos)
        e.color = (*col, 1)
    links.new(fac, r.inputs["Fac"])
    return r.outputs["Color"]


def fur(dark, light, scale=60.0):
    def build(nodes, links):
        coord = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0, 1.0, 6.0)   # Strähnen entlang Z
        links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        strands = nodes.new("ShaderNodeTexNoise")
        strands.inputs["Scale"].default_value = scale
        strands.inputs["Detail"].default_value = 8
        links.new(mapping.outputs["Vector"], strands.inputs["Vector"])
        patches = nodes.new("ShaderNodeTexNoise")
        patches.inputs["Scale"].default_value = 4
        links.new(coord.outputs["Object"], patches.inputs["Vector"])
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "FLOAT"
        mix.inputs["Factor"].default_value = 0.35
        links.new(strands.outputs["Fac"], mix.inputs["A"])
        links.new(patches.outputs["Fac"], mix.inputs["B"])
        return ramp(nodes, links, mix.outputs["Result"], [(0.3, dark), (0.55, light), (0.75, dark)])
    return build


def wood(dark, light, rings=7.0, stretch=(1.0, 6.0, 1.0)):
    def build(nodes, links):
        coord = nodes.new("ShaderNodeTexCoord")
        mapping = nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = stretch
        links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        wave = nodes.new("ShaderNodeTexWave")
        wave.wave_type = "RINGS"
        wave.inputs["Scale"].default_value = rings
        wave.inputs["Distortion"].default_value = 6
        wave.inputs["Detail"].default_value = 4
        links.new(mapping.outputs["Vector"], wave.inputs["Vector"])
        grain = nodes.new("ShaderNodeTexNoise")
        grain.inputs["Scale"].default_value = 40
        grain.inputs["Detail"].default_value = 6
        links.new(mapping.outputs["Vector"], grain.inputs["Vector"])
        mix = nodes.new("ShaderNodeMix")
        mix.data_type = "FLOAT"
        mix.inputs["Factor"].default_value = 0.4
        links.new(wave.outputs["Fac"], mix.inputs["A"])
        links.new(grain.outputs["Fac"], mix.inputs["B"])
        return ramp(nodes, links, mix.outputs["Result"], [(0.2, dark), (0.6, light), (0.9, dark)])
    return build


def rope_mat():
    def build(nodes, links):
        coord = nodes.new("ShaderNodeTexCoord")
        wave = nodes.new("ShaderNodeTexWave")
        wave.bands_direction = "DIAGONAL"
        wave.inputs["Scale"].default_value = 60
        wave.inputs["Distortion"].default_value = 1.5
        links.new(coord.outputs["Object"], wave.inputs["Vector"])
        return ramp(nodes, links, wave.outputs["Fac"], [(0.2, (0.36, 0.27, 0.15)), (0.6, (0.72, 0.6, 0.4))])
    return build


def flat(color):
    def build(nodes, links):
        rgb = nodes.new("ShaderNodeRGB")
        rgb.outputs[0].default_value = (*color, 1)
        return rgb.outputs[0]
    return build


def bake_to_texture(obj, tex_name, size, roughness=0.8):
    """Backt die Grundfarbe aller Materialien von obj in eine Textur und ersetzt sie durch
    ein einfaches Material mit dieser Textur (das glTF exportieren kann)."""
    select_only([obj])
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")

    image = bpy.data.images.new(tex_name, size, size)
    for slot in obj.material_slots:
        nodes = slot.material.node_tree.nodes
        node = nodes.new("ShaderNodeTexImage")
        node.image = image
        nodes.active = node
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=6)
    os.makedirs(TEX_DIR, exist_ok=True)
    image.filepath_raw = os.path.join(TEX_DIR, tex_name + ".png")
    image.file_format = "PNG"
    image.save()

    final = bpy.data.materials.new(tex_name)
    final.use_nodes = True
    nodes, links = final.node_tree.nodes, final.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = roughness
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    obj.data.materials.clear()
    obj.data.materials.append(final)


def export(objs, path):
    select_only(objs)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True)
    print("exportiert:", path)


def preview(objs, path, distance, target_z, angle=35):
    scene = bpy.context.scene
    lo = Vector((1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            lo = Vector(map(min, lo, o.matrix_world @ Vector(c)))
    world = bpy.data.worlds.new("Welt")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.62, 0.66, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    scene.world = world
    sun = link(bpy.data.objects.new("Sonne", bpy.data.lights.new("Sonne", "SUN")))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    cam = link(bpy.data.objects.new("Kamera", bpy.data.cameras.new("Kamera")))
    a = math.radians(angle)
    cam.location = (distance * math.sin(a), -distance * math.cos(a), target_z + distance * 0.35)
    direction = Vector((0, 0, target_z)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = 640
    scene.render.filepath = path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------- Affe

def build_monkey():
    reset()
    # Körper und Gliedmaßen als Skelett mit Skin-Modifier (gibt organische Übergänge)
    # Achsen: x rechts, -y vorn (Blickrichtung), z oben. Sitzende Haltung.
    verts, edges, radii = [], [], []

    def v(p, r):
        verts.append(p)
        radii.append(r)
        return len(verts) - 1

    pelvis = v((0, 0.03, 0.30), 0.19)
    chest = v((0, -0.01, 0.58), 0.18)
    neck = v((0, -0.04, 0.76), 0.085)
    edges += [(pelvis, chest), (chest, neck)]
    for s in (-1, 1):
        sh = v((s * 0.16, -0.03, 0.66), 0.07)
        el = v((s * 0.24, -0.10, 0.44), 0.055)
        wr = v((s * 0.20, -0.24, 0.33), 0.045)
        hd = v((s * 0.17, -0.31, 0.31), 0.05)
        edges += [(chest, sh), (sh, el), (el, wr), (wr, hd)]
        hp = v((s * 0.12, -0.02, 0.26), 0.085)
        kn = v((s * 0.21, -0.25, 0.36), 0.065)
        an = v((s * 0.15, -0.22, 0.07), 0.05)
        ft = v((s * 0.15, -0.34, 0.04), 0.045)
        edges += [(pelvis, hp), (hp, kn), (kn, an), (an, ft)]
    mesh = bpy.data.meshes.new("AffeKoerper")
    mesh.from_pydata(verts, edges, [])
    body = link(bpy.data.objects.new("AffeKoerper", mesh))
    skin = body.modifiers.new("Skin", "SKIN")
    for i, r in enumerate(radii):
        body.data.skin_vertices[0].data[i].radius = (r, r)
    body.data.skin_vertices[0].data[pelvis].use_root = True
    sub = body.modifiers.new("Sub", "SUBSURF")
    sub.levels = 2
    apply_all(body)
    shade_smooth(body)

    head = sphere("Kopf", (0, -0.06, 0.90), 0.17, (1.0, 0.95, 1.0))
    brow = sphere("Stirn", (0, -0.16, 0.96), 0.11, (1.25, 0.45, 0.5))
    face = sphere("Gesicht", (0, -0.17, 0.89), 0.115, (1.05, 0.5, 0.95))
    muzzle = sphere("Schnauze", (0, -0.22, 0.85), 0.075, (1.15, 0.85, 0.75))
    ears = [sphere("Ohr", (s * 0.165, -0.04, 0.93), 0.06, (0.45, 0.9, 1.0)) for s in (-1, 1)]
    inner = [sphere("OhrInnen", (s * 0.175, -0.06, 0.93), 0.04, (0.3, 0.7, 0.8)) for s in (-1, 1)]
    eyes = [sphere("Auge", (s * 0.052, -0.215, 0.935), 0.022, segments=16, rings=8) for s in (-1, 1)]
    nostrils = [sphere("Nasenloch", (s * 0.018, -0.29, 0.865), 0.009, segments=12, rings=6) for s in (-1, 1)]
    belly = sphere("Bauch", (0, -0.11, 0.46), 0.15, (0.95, 0.55, 1.25))
    tail = tube("Schwanz", [(0, 0.17, 0.22), (0, 0.42, 0.10), (0.05, 0.62, 0.16), (0.08, 0.72, 0.40),
                            (0.04, 0.66, 0.58), (-0.04, 0.56, 0.56), (-0.03, 0.55, 0.45)], 0.035, 0.45)

    fur_mat = material("Fell", fur((0.045, 0.028, 0.015), (0.16, 0.095, 0.045)))
    skin_mat = material("Haut", fur((0.30, 0.19, 0.14), (0.46, 0.31, 0.23), scale=20))
    belly_mat = material("Bauchfell", fur((0.16, 0.10, 0.055), (0.30, 0.20, 0.11)))
    eye_mat = material("Auge", flat((0.02, 0.015, 0.01)))
    for o in (body, head, tail, *ears):
        o.data.materials.append(fur_mat)
    for o in (face, muzzle, brow, *inner):
        o.data.materials.append(skin_mat)
    brow.data.materials[0] = fur_mat
    belly.data.materials.append(belly_mat)
    for o in (*eyes, *nostrils):
        o.data.materials.append(eye_mat)

    monkey = join([body, head, brow, face, muzzle, belly, tail, *ears, *inner, *eyes, *nostrils], "Affe")
    bake_to_texture(monkey, "affe_fell", 1024, roughness=0.9)
    export([monkey], OUT["monkey"])
    preview([monkey], os.path.join(PREVIEWS, "affe.png"), 2.4, 0.5)


# ---------------------------------------------------------------- Plattform

def build_platform():
    reset()
    radius = 1.0
    parts = []
    plank_mats = [material("Planke%d" % i, wood(d, l)) for i, (d, l) in enumerate([
        ((0.22, 0.13, 0.07), (0.45, 0.30, 0.17)),
        ((0.25, 0.16, 0.09), (0.50, 0.35, 0.20)),
        ((0.19, 0.12, 0.07), (0.40, 0.27, 0.15)),
    ])]
    beam_mat = material("Balken", wood((0.13, 0.08, 0.05), (0.30, 0.20, 0.12), rings=4, stretch=(1, 1, 5)))
    rope = material("Seil", rope_mat())

    # Deck: Planken quer, Oberkante bei z = 0, leicht unregelmäßig
    width, gap, thick = 0.165, 0.014, 0.06
    y = -radius + width / 2
    while y < radius - width / 3:
        half = math.sqrt(max(radius ** 2 - y ** 2, 0.0)) * 0.97
        if half > 0.15:
            length = 2 * half + random.uniform(-0.06, 0.04)
            p = box("Planke", (random.uniform(-0.02, 0.02), y, -thick / 2 + random.uniform(-0.008, 0.006)),
                    (length, width, thick), rot=(random.uniform(-0.015, 0.015), 0, random.uniform(-0.02, 0.02)))
            p.data.materials.append(random.choice(plank_mats))
            parts.append(p)
        y += width + gap

    # Rahmen unter dem Deck und Träger
    bpy.ops.mesh.primitive_torus_add(major_radius=radius * 0.93, minor_radius=0.055, major_segments=48,
                                     minor_segments=10, location=(0, 0, -0.11))
    rim = bpy.context.active_object
    rim.name = "Rahmen"
    shade_smooth(rim)
    rim.data.materials.append(beam_mat)
    parts.append(rim)
    for ang in (0, math.pi / 2):
        d = Vector((math.cos(ang), math.sin(ang), 0)) * radius * 0.92
        b = cylinder("Traeger", (-d.x, -d.y, -0.13), (d.x, d.y, -0.13), 0.06, 10)
        shade_smooth(b)
        b.data.materials.append(beam_mat)
        parts.append(b)
    hub = cylinder("Mittelpfosten", (0, 0, -0.08), (0, 0, -0.55), 0.09, 12)
    shade_smooth(hub)
    hub.data.materials.append(beam_mat)
    parts.append(hub)

    # Pfosten und durchhängende Seile auf einer Hälfte (die andere bleibt offen zum Springen)
    posts = []
    for i in range(5):
        ang = math.radians(-90 + i * 45)
        base = Vector((math.cos(ang), math.sin(ang), 0)) * radius * 0.9
        top = base + Vector((random.uniform(-0.02, 0.02), random.uniform(-0.02, 0.02), 0.55))
        post = cylinder("Pfosten", (base.x, base.y, -0.12), top, 0.035, 10)
        shade_smooth(post)
        post.data.materials.append(beam_mat)
        parts.append(post)
        posts.append(top)
    for a, b in zip(posts, posts[1:]):
        for h, sag in ((0.0, 0.07), (-0.25, 0.05)):
            pts = []
            for k in range(7):
                t = k / 6
                p = a.lerp(b, t)
                pts.append((p.x, p.y, p.z + h - sag * math.sin(math.pi * t)))
            r = tube("Seil", pts, 0.012)
            r.data.materials.append(rope)
            parts.append(r)

    platform = join(parts, "Plattform")
    bake_to_texture(platform, "plattform_holz", 2048, roughness=0.85)
    export([platform], OUT["platform"])
    zs = [(platform.matrix_world @ v.co).z for v in platform.data.vertices]
    print("PLATFORM_DECK_FROM_BOTTOM = %.4f" % ((0.0 - min(zs)) / (max(zs) - min(zs))))
    preview([platform], os.path.join(PREVIEWS, "plattform.png"), 3.6, 0.0, angle=25)


# ---------------------------------------------------------------- Juwel

def build_jewel():
    reset()
    # Brillantschliff als konvexe Hülle der Facetten-Ecken: Rundiste, Krone, Tafel, Pavillon, Spitze
    bm = bmesh.new()

    def ring(n, r, z, offset=0.0):
        for i in range(n):
            a = 2 * math.pi * (i + offset) / n
            bm.verts.new((r * math.cos(a), r * math.sin(a), z))

    ring(16, 0.5, 0.025)
    ring(16, 0.5, -0.025)
    ring(8, 0.40, 0.15, 0.5)
    ring(8, 0.26, 0.24)
    ring(8, 0.30, -0.22, 0.5)
    bm.verts.new((0, 0, -0.5))
    bmesh.ops.convex_hull(bm, input=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    mesh = bpy.data.meshes.new("Juwel")
    bm.to_mesh(mesh)
    jewel = link(bpy.data.objects.new("Juwel", mesh))
    shade_smooth(jewel, False)

    mat = bpy.data.materials.new("Rubin")
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (0.45, 0.0, 0.025, 1)
    bsdf.inputs["Roughness"].default_value = 0.04
    bsdf.inputs["Metallic"].default_value = 0.45
    bsdf.inputs["Specular IOR Level"].default_value = 1.0
    bsdf.inputs["Emission Color"].default_value = (0.9, 0.05, 0.08, 1)
    bsdf.inputs["Emission Strength"].default_value = 0.2
    jewel.data.materials.append(mat)
    export([jewel], OUT["jewel"])
    preview([jewel], os.path.join(PREVIEWS, "juwel.png"), 2.0, 0.0, angle=20)


# ---------------------------------------------------------------- Kacheltexturen

def bake_tile(path, builder, size=1024):
    """Backt einen prozeduralen Shader auf eine 1 x 1 m große Fläche und speichert das Bild."""
    reset()
    bpy.ops.mesh.primitive_plane_add(size=1.0)
    plane = bpy.context.active_object
    plane.data.materials.append(material("Kachel", builder))
    image = bpy.data.images.new(os.path.basename(path), size, size)
    node = plane.data.materials[0].node_tree.nodes.new("ShaderNodeTexImage")
    node.image = image
    plane.data.materials[0].node_tree.nodes.active = node
    select_only([plane])
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, margin=0)
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    print("gebacken:", path)


def planks(nodes, links):
    coord = nodes.new("ShaderNodeTexCoord")
    bricks = nodes.new("ShaderNodeTexBrick")   # Planken als lange, versetzte Reihen
    bricks.inputs["Scale"].default_value = 1.0
    bricks.inputs["Brick Width"].default_value = 1.6
    bricks.inputs["Row Height"].default_value = 0.2
    bricks.inputs["Mortar Size"].default_value = 0.008
    bricks.inputs["Color1"].default_value = (0.42, 0.29, 0.17, 1)
    bricks.inputs["Color2"].default_value = (0.30, 0.20, 0.12, 1)
    bricks.inputs["Mortar"].default_value = (0.06, 0.04, 0.03, 1)
    links.new(coord.outputs["Generated"], bricks.inputs["Vector"])
    grain = wood((0.18, 0.11, 0.06), (0.5, 0.36, 0.22), rings=3, stretch=(0.4, 8.0, 1.0))(nodes, links)
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MULTIPLY"
    mix.inputs["Factor"].default_value = 0.75
    links.new(bricks.outputs["Color"], mix.inputs["A"])
    links.new(grain, mix.inputs["B"])
    bright = nodes.new("ShaderNodeBrightContrast")
    bright.inputs["Bright"].default_value = 0.12
    links.new(mix.outputs["Result"], bright.inputs["Color"])
    return bright.outputs["Color"]


def bark(nodes, links):
    coord = nodes.new("ShaderNodeTexCoord")
    mapping = nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (6.0, 0.8, 1.0)   # tiefe Furchen entlang des Stamms
    links.new(coord.outputs["Generated"], mapping.inputs["Vector"])
    voronoi = nodes.new("ShaderNodeTexVoronoi")
    voronoi.feature = "DISTANCE_TO_EDGE"
    voronoi.inputs["Scale"].default_value = 3.0
    links.new(mapping.outputs["Vector"], voronoi.inputs["Vector"])
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 12
    noise.inputs["Detail"].default_value = 10
    links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
    mix = nodes.new("ShaderNodeMix")
    mix.data_type = "FLOAT"
    mix.inputs["Factor"].default_value = 0.35
    links.new(voronoi.outputs["Distance"], mix.inputs["A"])
    links.new(noise.outputs["Fac"], mix.inputs["B"])
    return ramp(nodes, links, mix.outputs["Result"],
                [(0.02, (0.04, 0.03, 0.02)), (0.12, (0.17, 0.12, 0.08)), (0.35, (0.30, 0.23, 0.16)), (0.7, (0.22, 0.18, 0.13))])


build_monkey()
build_platform()
build_jewel()
bake_tile(OUT["planks"], planks)
bake_tile(OUT["bark"], bark)
print("FERTIG")
