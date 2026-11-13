"""Erstellt die Spieler-Animationen für das Aufstemmen des Krokodilmauls.

Aufruf:
  blender -b --python tools/croc_hang_anim/build_anim.py -- <character.glb> <out.glb> <out.blend>

Ausgangspose ist Rope_Hang_Idle (Finger greifen bereits). Die Arme greifen per IK
V-förmig zur Seite nach oben - eine Hand am Oberkiefer, eine am Unterkiefer. Rumpf und
Beine werden prozedural bewegt und anschließend gebacken. Im Spiel zieht ein
TwoBoneIK3D die Hände zusätzlich genau an die Kieferspitzen.
  Croc_Jaw_Brace  Schleife: Kiefer auseinanderhalten, strampeln, zappeln
  Croc_Jaw_Push   kurzer Ruck pro Tastendruck: Arme stoßen nach außen, Beine treten
"""
import bpy, sys, math
from mathutils import Matrix, Vector

src, out_glb, out_blend = sys.argv[sys.argv.index("--") + 1:][:3]
FPS = 30

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
LEFT = Vector((1, 0, 0))    # Figur schaut nach -Y, links ist +X
UP = Vector((0, 0, 1))

# ---------- Grundpose aus Rope_Hang_Idle ----------
rope = bpy.data.actions["Rope_Hang_Idle"]
arm.animation_data.action = rope
if rope.slots:
    arm.animation_data.action_slot = rope.slots[0]
scene.frame_set(0)
base = {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in pbones}
arm.animation_data.action = None


def reset_pose():
    for pb in pbones:
        pb.location, pb.rotation_quaternion = base[pb.name][0].copy(), base[pb.name][1].copy()
    bpy.context.view_layer.update()


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


# ---------- Griffpunkte (fest) ----------
reset_pose()
sh_l = pbones[P + "LeftArm"].head.copy()
sh_r = pbones[P + "RightArm"].head.copy()
reach = (pbones[P + "LeftForeArm"].head - sh_l).length + (pbones[P + "LeftHand"].head - pbones[P + "LeftForeArm"].head).length
# V-Form: Arme fast gestreckt, 40° über der Waagerechten
SPREAD = math.radians(40)
hand_z = (sh_l.z + sh_r.z) / 2 + reach * 0.92 * math.sin(SPREAD)
hand_x = abs(sh_l.x) + reach * 0.92 * math.cos(SPREAD)
HAND_FWD = -0.08
targets = {}
for side, sh, sign in (("Left", sh_l, 1), ("Right", sh_r, -1)):
    def empty(name, loc):
        e = bpy.data.objects.new(name, None)
        e.location = loc
        scene.collection.objects.link(e)
        return e
    targets[side] = (
        empty(side + "HandTarget", Vector((sign * hand_x, HAND_FWD, hand_z))),
        empty(side + "ElbowPole", Vector((sign * hand_x * 0.6, 0.6, hand_z - 0.9))),
        empty(side + "HandAim", Vector((sign * (hand_x + 0.7), HAND_FWD, hand_z + 0.6))),
    )


def add_constraints():
    for side, (tgt, pole, aim) in targets.items():
        ik = pbones[P + side + "ForeArm"].constraints.new('IK')
        ik.target, ik.pole_target, ik.chain_count = tgt, pole, 2
        ik.pole_angle = math.radians(-90 if side == "Left" else -90)
        dt = pbones[P + side + "Hand"].constraints.new('DAMPED_TRACK')
        dt.target = aim


def keyframe_all(frame):
    for pb in pbones:
        pb.keyframe_insert("rotation_quaternion", frame=frame)
        pb.keyframe_insert("location", frame=frame)


def build(name, frames, pose_fn, cyclic):
    act = bpy.data.actions.new(name)
    arm.animation_data.action = act
    for f in range(frames + 1):
        t = f / frames
        reset_pose()
        pose_fn(t)
        keyframe_all(f)
    add_constraints()
    bpy.context.view_layer.objects.active = arm
    arm.select_set(True)
    bpy.ops.object.mode_set(mode='POSE')
    bpy.ops.pose.select_all(action='SELECT')
    bpy.ops.nla.bake(frame_start=0, frame_end=frames, only_selected=False, visual_keying=True,
                     clear_constraints=True, use_current_action=True, bake_types={'POSE'})
    bpy.ops.object.mode_set(mode='OBJECT')
    act = arm.animation_data.action
    act.name = name
    act.use_fake_user = True
    act.use_frame_range = True
    act.frame_start, act.frame_end = 0, frames
    act.use_cyclic = cyclic
    return act


def body(t, lift=0.0, tuck=0.0):
    """Gemeinsame Rumpf-/Beinbewegung. t: Phase 0..1, lift: Hochziehen in m, tuck: Beine anziehen 0..1"""
    w = 2 * math.pi * t
    move("Hips", Vector((0.03 * math.sin(w), 0.04 * math.sin(w + 1.0), lift)))
    rot("Hips", LEFT, 6 * math.sin(w) + 8 + 6 * tuck)        # Pendeln vor/zurück
    rot("Hips", Vector((0, -1, 0)), 5 * math.sin(w + 0.7))     # seitliches Zappeln
    for s in ("Spine", "Spine1", "Spine2"):
        rot(s, LEFT, -1 - 2 * math.sin(w + 0.5))                  # Oberkörper leicht ins Hohlkreuz
    rot("Neck", LEFT, -4)
    rot("Head", LEFT, -8 + 6 * tuck + 4 * math.sin(2 * w))      # Blick leicht nach oben, beim Stoß Kopf runter
    rot("Head", UP, 18 * math.sin(w + 0.3))                     # Blick zwischen den Kiefern hin und her
    # Strampeln: Beine gegenläufig, Knie beugen sich beim Vorschwingen
    for side, ph in (("Left", 0.0), ("Right", math.pi)):
        s = math.sin(w * 2 + ph)
        rot(side + "UpLeg", LEFT, -18 * s * (1 - tuck) - 60 * tuck - 12)
        rot(side + "Leg", LEFT, 25 + 30 * (0.5 + 0.5 * math.cos(w * 2 + ph)) * (1 - tuck) + 70 * tuck)
        rot(side + "Foot", LEFT, -15 * s)


build("Croc_Jaw_Brace", 36, lambda t: body(t), True)


def push(t):
    # schneller Stoß, langsamer zurück: Körper spannt sich, Beine treten an
    k = math.sin(math.pi * min(t / 0.3, 1.0) * 0.5) if t < 0.3 else math.cos(math.pi * 0.5 * (t - 0.3) / 0.7)
    body(0.0, lift=0.12 * k, tuck=0.6 * k)


build("Croc_Jaw_Push", 12, push, False)

# ---------- Kennzahlen für das Spiel ----------
arm.animation_data.action = bpy.data.actions["Croc_Jaw_Brace"]
arm.animation_data.action_slot = arm.animation_data.action.slots[0]
scene.frame_set(0)
grip = (pbones[P + "LeftHand"].tail + pbones[P + "RightHand"].tail) / 2
span = (pbones[P + "LeftHand"].tail - pbones[P + "RightHand"].tail).length
print("GRIP_MID (Blender, Füße=Ursprung):", tuple(round(x, 3) for x in grip),
      "-> Godot hoch=%.3f vor=%.3f Spannweite=%.3f" % (grip.z, -grip.y, span))

# ---------- Export ----------
for a in list(bpy.data.actions):
    if a.name not in ("Croc_Jaw_Brace", "Croc_Jaw_Push"):
        bpy.data.actions.remove(a)
for o in list(bpy.data.objects):
    if o.type == 'EMPTY':
        bpy.data.objects.remove(o)
scene.frame_start, scene.frame_end = 0, 36
bpy.ops.wm.save_as_mainfile(filepath=out_blend)
bpy.ops.export_scene.gltf(filepath=out_glb, export_format='GLB', export_animation_mode='ACTIONS',
                          export_force_sampling=True, export_frame_range=False, export_yup=True)
print("DONE")
