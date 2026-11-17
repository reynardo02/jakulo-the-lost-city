"""Build editable, deterministic dressing scenes without regenerating the levels."""
from pathlib import Path
import math
import random

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "scenes/dressing"

class Scene:
    def __init__(self):
        self.resources = []
        self.nodes = ['[node name="Dressing" type="Node3D"]\n']
        self.counter = 0
        self.external = {}
        self.materials = {}

    def resource(self, kind, text):
        self.counter += 1
        key = f"polish_{self.counter}"
        self.resources.append(f'[sub_resource type="{kind}" id="{key}"]\n{text}\n')
        return f'SubResource("{key}")'

    def material(self, name, color):
        if name not in self.materials:
            self.materials[name] = self.resource('StandardMaterial3D', f'albedo_color = Color({color}, 1)\nroughness = 0.95')
        return self.materials[name]

    def node(self, name, kind, position, properties='', scale=(1,1,1), rotation=(0,0,0)):
        self.counter += 1
        vec = lambda v: ', '.join(f'{x:.5f}' for x in v)
        self.nodes.append(f'[node name="{name}_{self.counter}" type="{kind}" parent="."]\nposition = Vector3({vec(position)})\nrotation = Vector3({vec(rotation)})\nscale = Vector3({vec(scale)})\n{properties}\n')

    def mesh(self, name, kind, mesh, position, material, scale=(1,1,1), rotation=(0,0,0)):
        ref = self.resource(kind, f'material = {material}\n{mesh}')
        self.node(name, 'MeshInstance3D', position, f'mesh = {ref}', scale, rotation)

    def model(self, path, position, scale=1, yaw=0):
        if path not in self.external:
            self.external[path] = f'model_{len(self.external)}'
        self.counter += 1
        c, s = math.cos(yaw)*scale, math.sin(yaw)*scale
        p = ', '.join(str(x) for x in position)
        self.nodes.append(f'[node name="Plant_{self.counter}" parent="." instance=ExtResource("{self.external[path]}")]\ntransform = Transform3D({c}, 0, {-s}, 0, {scale}, 0, {s}, 0, {c}, {p})\n')

    def beam(self, a, b, radius, material):
        d = [b[i]-a[i] for i in range(3)]
        length = math.sqrt(sum(x*x for x in d))
        # Euler rotation of a Y-aligned cylinder.
        rotation = (math.acos(d[1]/length), math.atan2(d[0], d[2]), 0)
        self.mesh('Seil', 'CylinderMesh', f'top_radius = {radius}\nbottom_radius = {radius}\nheight = {length}\nradial_segments = 10', [(a[i]+b[i])/2 for i in range(3)], material, rotation=rotation)

    def save(self, name):
        external = ''.join(f'[ext_resource type="PackedScene" path="res://{p}" id="{key}"]\n' for p,key in self.external.items())
        OUT.mkdir(exist_ok=True)
        (OUT / f'{name}.tscn').write_text('[gd_scene format=3]\n\n'+external+'\n'+'\n'.join(self.resources+self.nodes), encoding='utf-8')

def build():
    rng = random.Random(2417)
    scene = Scene()
    rock = scene.material('rock', '0.23, 0.27, 0.21')
    soil = scene.material('soil', '0.22, 0.17, 0.10')
    # Dry sections only; no new objects on landing zones or in the pit.
    for z in [-12,-18,-25,-30,-51,-58,-66,-73]:
        for side in [-1,1]:
            x = side*rng.uniform(5.4,6.5)
            scene.mesh('Uferfels', 'SphereMesh', 'radial_segments = 9\nrings = 5', (x,.08,z), rock, (rng.uniform(.7,1.2),.45,rng.uniform(.8,1.5)))
            scene.model('assets/nature/fern_small.glb', (x-side*.4,0,z+1.1), rng.uniform(.65,1.1), rng.random()*math.tau)
            scene.model('assets/nature/jungle/ground_leaves.glb', (x-side*.7,.025,z-.8), .65, rng.random()*math.tau)
    for z in [-83,-87,-91,-95]:
        for side in [-1,1]:
            scene.mesh('FeuchtesUfer', 'SphereMesh', 'radial_segments = 12\nrings = 5', (side*6.15,-.25,z), soil, (1.0,.4,2.4))
            scene.model('assets/level3/reeds.glb', (side*6.3,-.12,z+.4), .65, rng.random()*math.tau)
    # Small stone fragments foreshadow the temple, outside the centre of the path.
    for i in range(9):
        scene.mesh('Ruinenfragment', 'BoxMesh', 'size = Vector3(0.8, 0.25, 0.55)', (4.9+i*.18,.04,-101-i*1.4), rock, rotation=(0,rng.random(),.12))
    scene.save('level_1')

    scene = Scene()
    wood = scene.material('wood', '0.29, 0.19, 0.10')
    cloth = scene.material('cloth', '0.48, 0.37, 0.23')
    clay = scene.material('clay', '0.36, 0.23, 0.15')
    # Work areas by the huts, away from the central patrol and stealth routes.
    for x,z in [(-17,-204),(-10,-219),(10,-219),(14,-204)]:
        for side in [-1,1]:
            scene.beam((x+side*.85,0,z),(x+side*.85,2.4,z),.055,wood)
        scene.beam((x-.85,2.3,z),(x+.85,2.3,z),.025,wood)
        scene.mesh('TrockenTuch','BoxMesh','size = Vector3(1.15, 1.05, 0.025)',(x,1.72,z),cloth,rotation=(.07,0,.03))
        for i in range(3):
            scene.beam((x-1.0,.12+i*.13,z+.7),(x+.7,.12+i*.13,z+.85),.085,wood)
        scene.mesh('Vorratstopf','CylinderMesh','top_radius = 0.25\nbottom_radius = 0.32\nheight = 0.55\nradial_segments = 16',(x+1.2,.275,z+.7),clay)
    scene.save('level_2')

    scene = Scene()
    rope = scene.material('rope', '0.37, 0.28, 0.16')
    iron = scene.material('iron', '0.18, 0.20, 0.17')
    # Visible linkage runs overhead, clear of the spiral climbing route.
    points = [(0,19,-125.4),(0,21,-125.4),(7,21,-123),(20.5,7,-112.5),(22,5,-112.5)]
    for a,b in zip(points,points[1:]):
        scene.beam(a,b,.045,rope)
    for p in points[1:-1]:
        scene.mesh('Umlenkrolle','TorusMesh','inner_radius = 0.17\nouter_radius = 0.30\nrings = 20\nring_segments = 8',p,iron,rotation=(math.pi/2,0,0))
    scene.beam((20.5,0,-112.5),(20.5,7.4,-112.5),.12,rope)
    scene.save('level_3')

    scene = Scene()
    damp = scene.material('footprint', '0.28, 0.22, 0.14')
    wood = scene.material('wreckwood', '0.26, 0.19, 0.12')
    for i in range(22):
        z = 3.0+i*.62
        x = math.sin(z*.15)*.7 + (.16 if i%2 else -.16)
        scene.mesh('Fussspur','SphereMesh','radial_segments = 10\nrings = 4',(x,.084-z*.04,z),damp,(.12,.007,.28),(.04,0,0))
    for x,z,yaw in [(2.8,10,.3),(-3,6,-.8),(4,17,1.1)]:
        scene.mesh('Wrackbrett','BoxMesh','size = Vector3(0.25, 0.09, 1.4)',(x,.13-z*.04,z),wood,rotation=(.04,yaw,.08))
    scene.save('beach')
    beach = ROOT / 'scenes/level_1_beach.tscn'
    text = beach.read_text(encoding='utf-8')
    if 'id="polish_dressing"' not in text:
        at = text.index('[sub_resource')
        text = text[:at]+'[ext_resource type="PackedScene" path="res://scenes/dressing/beach.tscn" id="polish_dressing"]\n\n'+text[at:]
        text += '\n[node name="StrandSpuren" parent="." instance=ExtResource("polish_dressing")]\n'
        beach.write_text(text,encoding='utf-8')

    for level in ['level_1','level_2','level_3']:
        path = ROOT / f'scenes/{level}.tscn'
        text = path.read_text(encoding='utf-8')
        if 'id="polish_dressing"' not in text:
            at = text.index('[sub_resource')
            text = text[:at] + f'[ext_resource type="PackedScene" path="res://scenes/dressing/{level}.tscn" id="polish_dressing"]\n[ext_resource type="Script" path="res://scripts/jungle_ambience.gd" id="polish_ambience"]\n\n' + text[at:]
            text += '\n[node name="LandscapeDetails" parent="." instance=ExtResource("polish_dressing")]\n\n[node name="JungleAmbience" type="Node3D" parent="."]\nscript = ExtResource("polish_ambience")\n'
            if level == 'level_3': text += 'quiet = true\n'
        if level == 'level_1':
            text = text.replace('[node name="LandscapeDetails" parent="."', '[node name="LandscapeDetails" parent="Umgebung"')
        path.write_text(text, encoding='utf-8')

if __name__ == '__main__':
    build()
