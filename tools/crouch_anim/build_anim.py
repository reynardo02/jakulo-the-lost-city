"""Erstellt die Duck-Animationen des Spielers fürs Schleichen.

Aufruf:
  blender -b --python tools/crouch_anim/build_anim.py -- <character.glb> <out.glb> <out.blend> [vorschau-ordner]

Ausgangspunkt sind die vorhandenen Animationen Idle_9 und Walking. Pro Bild wird die Hüfte
abgesenkt und der Oberkörper nach vorn geneigt; die Beine werden so gebeugt, dass die Füße
genau dort bleiben, wo sie in der Vorlage stehen (eigene Zwei-Knochen-IK, Knie nach vorn).
  Crouch_Idle  Schleife: geduckt stehen
  Crouch_Walk  Schleife: geduckt gehen, langsamer als Walking (passt zum Schleichtempo)
"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

args = sys.argv[sys.argv.index("--") + 1:]
src, out_glb, out_blend = args[:3]
preview_dir = args[3] if len(args) > 3 else ""
FPS = 30

HIP_DROP = 0.23        # so weit geht die Hüfte nach unten (m)
HIP_BACK = 0.05        # ... und etwas nach hinten, damit der Schwerpunkt über den Füßen bleibt
LEAN = 11.0            # Vorneigung je Wirbelsäulen-Knochen (3 Stück) in Grad
WALK_SLOWDOWN = 1.7    # Crouch_Walk dauert so viel länger als ein Walking-Zyklus

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=src)

arm = next(o for o in bpy.data.objects if o.type == 'ARMATURE')
for o in list(bpy.data.objects):
    if o.type == 'MESH' and o.parent != arm:
        bpy.data.objects.remove(o)   # lose Icosphere aus dem Export

P = "mixamorig:"
pbones = arm.pose.bones
LEFT = Vector((1, 0, 0))       # Figur schaut nach -Y, links ist +X
FORWARD = Vector((0, -1, 0))


def rot(bone, axis, deg):
    """Dreht einen Knochen im Armature-Raum um seinen Kopf (Kinder wandern mit)."""
    pb = pbones[P + bone]
    h = pb.head.copy()
    r = Matrix.Rotation(math.radians(deg), 4, axis)
    pb.matrix = Matrix.Translation(h) @ r @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


def move(bone, offset):
    pb = pbones[P + bone]
    pb.matrix = Matrix.Translation(offset) @ pb.matrix
    bpy.context.view_layer.update()


def aim(bone, direction):
    """Dreht einen Knochen auf kürzestem Weg so, dass er in `direction` zeigt."""
    pb = pbones[P + bone]
    h = pb.head.copy()
    q = (pb.tail - pb.head).normalized().rotation_difference(direction.normalized())
    pb.matrix = Matrix.Translation(h) @ q.to_matrix().to_4x4() @ Matrix.Translation(-h) @ pb.matrix
    bpy.context.view_layer.update()


def sample(action_name, frame):
    """Pose der Vorlage an einem (auch gebrochenen) Bild: Basiswerte und Fußlage."""
    act = bpy.data.actions[action_name]
    arm.animation_data.action = act
    if act.slots:
        arm.animation_data.action_slot = act.slots[0]
    scene.frame_set(int(math.floor(frame)), subframe=frame - math.floor(frame))
    bpy.context.view_layer.update()
    basis = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbones}
    feet = {s: (pbones[P + s + "Foot"].head.copy(), pbones[P + s + "Foot"].matrix.to_3x3())
            for s in ("Left", "Right")}
    return basis, feet


def crouch(basis, feet, t, walking):
    """Macht aus einer Vorlagen-Pose die geduckte Pose und gibt deren Basiswerte zurück."""
    arm.animation_data.action = None
    for pb in pbones:
        # Arme im Gehen aus der Steh-Pose: der Armschwung der Vorlage sähe geduckt verrenkt aus
        use = ARM_POSE if walking and is_arm(pb.name) else basis
        pb.location, pb.rotation_quaternion = use[pb.name][0].copy(), use[pb.name][1].copy()
    bpy.context.view_layer.update()
    w = 2 * math.pi * t

    # Hüfte runter, im Stand leichtes Atmen, im Gehen wippt sie etwas mit
    bob = 0.012 * math.sin(w) if not walking else 0.015 * math.sin(2 * w)
    move("Hips", Vector((0, HIP_BACK, -HIP_DROP + bob)))
    rot("Hips", LEFT, 6)
    for s in ("Spine", "Spine1", "Spine2"):
        rot(s, LEFT, LEAN + (0.8 * math.sin(w) if not walking else 0.0))
    rot("Neck", LEFT, -10)
    rot("Head", LEFT, -16)                                     # Blick bleibt nach vorn gerichtet
    if not walking:
        rot("Head", Vector((0, 0, 1)), 14 * math.sin(w))       # sieht sich vorsichtig um

    # Arme: hängen durch die Vorneigung nach hinten -> nach vorn holen und anwinkeln
    for side, sign in (("Left", 1), ("Right", -1)):
        swing = 7 * math.sin(w) * sign if walking else 0.0     # kleiner Gegenschwung zu den Beinen
        rot(side + "Arm", LEFT, -34 + swing)
        rot(side + "Arm", FORWARD, sign * 8)                   # leicht vom Körper weg
        rot(side + "ForeArm", LEFT, -48)

    # Beine: Füße bleiben an ihrem Platz, das Knie knickt nach vorn
    for side in ("Left", "Right"):
        up, leg, foot = pbones[P + side + "UpLeg"], pbones[P + side + "Leg"], pbones[P + side + "Foot"]
        l1 = (leg.head - up.head).length
        l2 = (foot.head - leg.head).length
        hip = up.head.copy()
        target, foot_rot = feet[side]
        to_target = target - hip
        d = min(to_target.length, l1 + l2 - 1e-3)
        u = to_target.normalized()
        cos_a = max(-1.0, min(1.0, (l1 * l1 + d * d - l2 * l2) / (2 * l1 * d)))
        f = (FORWARD - u * FORWARD.dot(u)).normalized()
        thigh = u * cos_a + f * math.sqrt(max(0.0, 1.0 - cos_a * cos_a))
        aim(side + "UpLeg", thigh)
        aim(side + "Leg", target - pbones[P + side + "Leg"].head)
        foot = pbones[P + side + "Foot"]
        foot.matrix = Matrix.Translation(foot.head.copy()) @ foot_rot.to_4x4()   # Fuß bleibt flach wie in der Vorlage
        bpy.context.view_layer.update()

    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbones}


def is_arm(bone_name):
    return any(k in bone_name for k in ("Shoulder", "Arm", "Hand"))


ARM_POSE = sample("Idle_9", bpy.data.actions["Idle_9"].frame_range[0])[0]


def build(name, source, frames, slowdown):
    src_act = bpy.data.actions[source]
    start, end = src_act.frame_range
    poses = []
    for f in range(frames + 1):
        t = f / frames
        basis, feet = sample(source, start + (end - start) * t)
        poses.append(crouch(basis, feet, t, slowdown > 1.0 or source == "Walking"))
    poses[-1] = poses[0]   # saubere Schleife
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f, pose in enumerate(poses):
        for pb in pbones:
            pb.location, pb.rotation_quaternion = pose[pb.name]
            pb.keyframe_insert("rotation_quaternion", frame=f)
            pb.keyframe_insert("location", frame=f)
    act = arm.animation_data.action
    act.name = name
    act.use_fake_user = True
    act.use_frame_range = True
    act.frame_start, act.frame_end = 0, frames
    act.use_cyclic = True
    print("BUILT %s: %d Bilder aus %s (%.0f..%.0f)" % (name, frames, source, start, end))
    return act


idle_len = bpy.data.actions["Idle_9"].frame_range
walk_len = bpy.data.actions["Walking"].frame_range
build("Crouch_Idle", "Idle_9", 90, 1.0)
build("Crouch_Walk", "Walking", int(round((walk_len[1] - walk_len[0]) * WALK_SLOWDOWN)), WALK_SLOWDOWN)


# ---------- Vorschau-Bilder (Seitenansicht) ----------
def preview(action_name, frame, path):
    act = bpy.data.actions[action_name]
    arm.animation_data.action = act
    if act.slots:
        arm.animation_data.action_slot = act.slots[0]
    scene.frame_set(frame)
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


if preview_dir:
    cam_data = bpy.data.cameras.new("PreviewCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 2.6
    cam = bpy.data.objects.new("PreviewCam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = 'BLENDER_WORKBENCH'
    scene.display.shading.light = 'STUDIO'
    scene.display.shading.color_type = 'TEXTURE'
    scene.render.resolution_x, scene.render.resolution_y = 500, 500
    scene.render.film_transparent = False
    views = {"seite": (Vector((4, -0.2, 0.95)), (math.radians(90), 0, math.radians(90))),
             "schraeg": (Vector((2.6, -3.0, 1.3)), (math.radians(82), 0, math.radians(41)))}
    for view, (loc, rot_euler) in views.items():
        cam.location, cam.rotation_euler = loc, rot_euler
        preview("Idle_9", 0, "%s/vorlage_idle_%s.png" % (preview_dir, view))
        preview("Crouch_Idle", 0, "%s/crouch_idle_%s.png" % (preview_dir, view))
        n = int(bpy.data.actions["Crouch_Walk"].frame_end)
        for i, fr in enumerate((n // 4, 3 * n // 4)):
            preview("Crouch_Walk", fr, "%s/crouch_walk_%s_%d.png" % (preview_dir, view, i))
    bpy.data.objects.remove(cam)

# ---------- Export ----------
for a in list(bpy.data.actions):
    if a.name not in ("Crouch_Idle", "Crouch_Walk"):
        bpy.data.actions.remove(a)
scene.frame_start, scene.frame_end = 0, 90
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_frame_range=False, export_yup=True)
print("DONE")
