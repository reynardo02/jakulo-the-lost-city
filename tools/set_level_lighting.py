"""Gibt Level 1 und Level 2 je eine eigene Lichtstimmung (Level 3 setzt sein Licht im eigenen
Generator tools/level3/build_level_3.gd).

- Level 1 (mit Strand): früher Morgen. Tief stehende, goldene Sonne, lange Schatten,
  warmer Dunst über dem Dschungel, kühle Schatten.
- Level 2 (Dorf): Abenddämmerung. Rote, flache Sonne, violetter Himmel, dunklere Schatten.
  Lagerfeuer und Fackeln leuchten und flackern; sie tragen jetzt sichtbar zur Szene bei.

Ersetzt nur die Umgebungs-Ressource, die Sonne und (Level 2) die Feuerlichter. Mehrfach
ausführbar: python tools/set_level_lighting.py
"""
from pathlib import Path
import math
import re

ROOT = Path(__file__).resolve().parents[1]


def sun_transform(elevation_deg, yaw_deg):
    """Transform3D eines DirectionalLight3D, das unter `elevation` von `yaw` her scheint."""
    e, y = math.radians(elevation_deg), math.radians(yaw_deg)
    # Basis = Ry(yaw) * Rx(-elevation); das Licht strahlt entlang -Z dieser Basis
    cx, sx = math.cos(-e), math.sin(-e)
    cy, sy = math.cos(y), math.sin(y)
    rx = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    ry = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    m = [[sum(ry[i][k] * rx[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    # .tscn speichert die Basis zeilenweise
    rows = [m[i][j] for i in range(3) for j in range(3)]
    return 'Transform3D(' + ', '.join(f'{v:.6g}' for v in rows) + ', 0, 20, 0)'


def env_block(env_id, sky_id, mood):
    return f'''[sub_resource type="Environment" id="{env_id}"]
background_mode = 2
sky = SubResource("{sky_id}")
ambient_light_source = 3
ambient_light_color = Color({mood['ambient_color']}, 1)
ambient_light_energy = {mood['ambient_energy']}
reflected_light_source = 2
tonemap_mode = 2
tonemap_exposure = {mood['exposure']}
ssao_enabled = true
ssao_radius = 1.5
ssao_intensity = 2.5
ssil_enabled = true
glow_enabled = true
glow_intensity = {mood['glow']}
glow_bloom = {mood['bloom']}
fog_enabled = true
fog_mode = 1
fog_light_color = Color({mood['fog_color']}, 1)
fog_light_energy = {mood['fog_energy']}
fog_sun_scatter = {mood['sun_scatter']}
fog_density = {mood['fog_density']}
fog_sky_affect = {mood['fog_sky']}
fog_depth_begin = {mood['fog_begin']}
fog_depth_end = {mood['fog_end']}
volumetric_fog_enabled = true
volumetric_fog_density = 0.012
volumetric_fog_albedo = Color({mood['fog_color']}, 1)
volumetric_fog_length = 80.0
adjustment_enabled = true
adjustment_contrast = {mood['contrast']}
adjustment_saturation = {mood['saturation']}

'''


def sky_block(sky_mat_id, mood):
    return f'''[sub_resource type="ProceduralSkyMaterial" id="{sky_mat_id}"]
sky_top_color = Color({mood['sky_top']}, 1)
sky_horizon_color = Color({mood['sky_horizon']}, 1)
sky_curve = 0.12
ground_bottom_color = Color(0.02, 0.03, 0.02, 1)
ground_horizon_color = Color({mood['ground_horizon']}, 1)
sun_angle_max = 25.0
sun_curve = 0.1

'''


MOODS = {
    'level_1': dict(  # Morgen
        sky_top='0.36, 0.56, 0.78', sky_horizon='0.96, 0.8, 0.6', ground_horizon='0.62, 0.6, 0.46',
        ambient_color='0.62, 0.72, 0.82', ambient_energy=0.55, exposure=1.0, glow=0.7, bloom=0.1,
        fog_color='0.78, 0.72, 0.55', fog_energy=1.0, sun_scatter=0.35, fog_density=0.62, fog_sky=0.45,
        fog_begin=8.0, fog_end=95.0, contrast=1.1, saturation=0.95,
        sun_color='1, 0.78, 0.52', sun_energy=1.3, elevation=18, yaw=34),
    'level_2': dict(  # Abenddämmerung: warm am Horizont, blaue Schatten, Feuer sichtbar
        sky_top='0.24, 0.32, 0.55', sky_horizon='0.98, 0.62, 0.38', ground_horizon='0.46, 0.38, 0.32',
        ambient_color='0.58, 0.62, 0.82', ambient_energy=0.75, exposure=1.15, glow=0.85, bloom=0.14,
        fog_color='0.55, 0.5, 0.56', fog_energy=0.9, sun_scatter=0.45, fog_density=0.4, fog_sky=0.35,
        fog_begin=14.0, fog_end=120.0, contrast=1.08, saturation=0.95,
        sun_color='1, 0.62, 0.38', sun_energy=1.05, elevation=13, yaw=-60),
}

FIRES = [  # (Name, Position, Farbe, Energie, Reichweite)
    ('FackelLicht1', (-1.8, 1.9, -214.6), '1, 0.6, 0.25', 2.2, 8.0),
    ('FackelLicht2', (1.8, 1.9, -214.6), '1, 0.6, 0.25', 2.2, 8.0),
    ('FackelLicht3', (-9.9, 1.9, -226.1), '1, 0.6, 0.25', 2.2, 8.0),
]


def apply(level):
    path = ROOT / f'scenes/{level}.tscn'
    text = path.read_text(encoding='utf-8')
    mood = MOODS[level]
    env_id = re.search(r'\[sub_resource type="Environment" id="([^"]+)"\]', text).group(1)
    sky_id = re.search(r'\[sub_resource type="Sky" id="([^"]+)"\]', text).group(1)
    sky_mat_id = re.search(r'\[sub_resource type="ProceduralSkyMaterial" id="([^"]+)"\]', text).group(1)
    text = re.sub(r'\[sub_resource type="Environment" id="%s"\]\n.*?\n\n' % re.escape(env_id),
                  lambda _: env_block(env_id, sky_id, mood), text, count=1, flags=re.S)
    text = re.sub(r'\[sub_resource type="ProceduralSkyMaterial" id="%s"\]\n.*?\n\n' % re.escape(sky_mat_id),
                  lambda _: sky_block(sky_mat_id, mood), text, count=1, flags=re.S)
    sun = re.search(r'(\[node name="DirectionalLight3D" type="DirectionalLight3D" parent="\."[^\]]*\]\n)(.*?)\n\n', text, re.S)
    body = f'''transform = {sun_transform(mood['elevation'], mood['yaw'])}
light_color = Color({mood['sun_color']}, 1)
light_energy = {mood['sun_energy']}
shadow_enabled = true
shadow_blur = 1.5
directional_shadow_max_distance = 80.0
sky_mode = 1'''
    text = text[:sun.start(2)] + body + text[sun.end(2):]

    if level == 'level_2':
        if 'id="flicker_light"' not in text:
            at = text.index('[sub_resource')
            text = text[:at] + '[ext_resource type="Script" path="res://scripts/flicker_light.gd" id="flicker_light"]\n\n' + text[at:]
        # Lagerfeuer: kräftiger, weiter, flackernd
        text = re.sub(r'(\[node name="Feuerschein" type="OmniLight3D"[^\]]*\]\n)(.*?)\n\n',
                      lambda m: m.group(1) + 'transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 1.2, -216)\n'
                      'light_color = Color(1, 0.55, 0.22, 1)\nlight_energy = 4.0\nshadow_enabled = true\n'
                      'omni_range = 13.0\nomni_attenuation = 1.4\nscript = ExtResource("flicker_light")\n'
                      'strength = 0.22\n\n', text, count=1, flags=re.S)
        for name, (x, y, z), color, energy, rng in FIRES:
            if f'[node name="{name}"' in text:
                continue
            text = text.rstrip('\n') + f'''

[node name="{name}" type="OmniLight3D" parent="Umgebung/Dorf/deko"]
transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, {x}, {y}, {z})
light_color = Color({color}, 1)
light_energy = {energy}
omni_range = {rng}
omni_attenuation = 1.6
script = ExtResource("flicker_light")
strength = 0.3
speed = 11.0
'''
    path.write_text(text, encoding='utf-8')
    print(level, 'Licht gesetzt')


if __name__ == '__main__':
    for level in MOODS:
        apply(level)
