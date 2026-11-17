"""Generate small deterministic original PCM effects. No external dependencies.

python tools/generate_foley.py                 # alles
python tools/generate_foley.py --foley-only    # nur die 24 Schritt-/Landeclips
python tools/generate_foley.py --stones-only   # Schritte + Steinwurf der Affen
"""
from pathlib import Path
import math
import random
import struct
import wave
import sys

ROOT = Path(__file__).resolve().parents[1] / "assets/music/sounds"
RATE = 44100


class Biquad:
    """RBJ biquad (lowpass, highpass, bandpass with constant peak gain)."""

    def __init__(self, kind, freq, q=0.707):
        w = math.tau * freq / RATE
        cw, alpha = math.cos(w), math.sin(w) / (2 * q)
        if kind == 'low':
            b = [(1 - cw) / 2, 1 - cw, (1 - cw) / 2]
        elif kind == 'high':
            b = [(1 + cw) / 2, -(1 + cw), (1 + cw) / 2]
        else:
            b = [alpha, 0.0, -alpha]
        a = [1 + alpha, -2 * cw, 1 - alpha]
        self.b = [x / a[0] for x in b]
        self.a = [a[1] / a[0], a[2] / a[0]]
        self.x1 = self.x2 = self.y1 = self.y2 = 0.0

    def __call__(self, x):
        y = self.b[0] * x + self.b[1] * self.x1 + self.b[2] * self.x2 - self.a[0] * self.y1 - self.a[1] * self.y2
        self.x2, self.x1, self.y2, self.y1 = self.x1, x, self.y1, y
        return y


def burst(start, decay, attack=0.0015):
    """Envelope of a short contact: fast attack, exponential decay."""
    def env(t):
        dt = t - start
        if dt < 0:
            return 0.0
        return min(1.0, dt / attack) * math.exp(-dt / decay)
    return env


# Per surface: impact colour, decay, texture band (Hz, Q), number and loudness of tiny grains.
SURFACES = {
    # forest floor: soft thud, leaves and small twigs crackle
    'earth': dict(body=('low', 420), decay=.016, grain=(3800, 1.2), grains=(14, 26), grain_amp=.22, toe=.55),
    # stone: short hard tap with sand grit
    'stone': dict(body=('band', 1900), decay=.006, grain=(5200, 1.6), grains=(8, 16), grain_amp=.16, toe=.6),
    # wood: hollow plank knock, barely any grit
    'wood': dict(body=('wood', 0), decay=.009, grain=(4200, 1.4), grains=(3, 7), grain_amp=.08, toe=.5),
    # water: wet slap, splash and a few drips
    'water': dict(body=('splash', 0), decay=.06, grain=(2200, 2.5), grains=(6, 12), grain_amp=.12, toe=.7),
}


def foley(surface, variant, landing=False):
    """A natural footstep: heel strike, toe roll and the surface's own texture."""
    rng = random.Random(9100 + variant * 131 + sum(map(ord, surface)) + int(landing) * 777)
    cfg = SURFACES[surface]
    duration = (.42 if landing else .3) + (.15 if surface == 'water' else 0.0)
    n = int(duration * RATE)
    heel_t = rng.uniform(.004, .009)
    toe_t = heel_t + (rng.uniform(.035, .06) if landing else rng.uniform(.06, .1))
    decay = cfg['decay'] * (1.8 if landing else 1.0) * rng.uniform(.85, 1.2)
    heel = burst(heel_t, decay)
    toe = burst(toe_t, decay * .8)
    toe_amp = cfg['toe'] * rng.uniform(.7, 1.1) * (.6 if landing else 1.0)

    kind, freq = cfg['body']
    if kind == 'wood':
        res = [Biquad('band', rng.uniform(150, 210), 3.5), Biquad('band', rng.uniform(430, 620), 4.5),
               Biquad('band', rng.uniform(1500, 2100), 2.0)]
        mix = [1.0, .55, .25]
    elif kind == 'splash':
        res = [Biquad('band', 700, .9), Biquad('band', 1800, 1.1), Biquad('low', 260)]
        mix = [.8, .55, .9]
    elif kind == 'band':
        res = [Biquad('band', freq * rng.uniform(.85, 1.15), 1.2), Biquad('low', 300)]
        mix = [1.0, .45]
    else:
        res = [Biquad(kind, freq * rng.uniform(.85, 1.15)), Biquad('band', 1400, .8)]
        mix = [1.0, .3]
    thump = Biquad('low', 120)
    hp = Biquad('high', 45)
    grain_filter = Biquad('band', cfg['grain'][0] * rng.uniform(.8, 1.2), cfg['grain'][1])

    # Texture: many tiny clicks around heel and toe contact (crackle, grit, drips).
    grains = []
    lo, hi = cfg['grains']
    for _ in range(int(rng.randint(lo, hi) * (1.6 if landing else 1.0))):
        around = heel_t if rng.random() < .55 else toe_t
        at = around + abs(rng.gauss(0, .045 if surface != 'water' else .12))
        grains.append((at, rng.uniform(.0006, .0025), cfg['grain_amp'] * rng.uniform(.25, 1.0)))
    drips = []
    if surface == 'water':
        for _ in range(rng.randint(2, 5) + (3 if landing else 0)):
            drips.append((rng.uniform(.08, duration - .06), rng.uniform(900, 1900), rng.uniform(.04, .1)))

    out = []
    for i in range(n):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        if kind == 'splash':
            sw = max(0.0, t - heel_t)
            e = min(1.0, sw / .012) * math.exp(-sw / (decay * 1.4)) + toe(t) * toe_amp * .5
        else:
            e = heel(t) + toe(t) * toe_amp
        body = sum(m * f(noise) for m, f in zip(mix, res)) * e
        body += thump(noise) * e * (2.2 if landing else 1.2)
        g = 0.0
        for at, length, amp in grains:
            if at <= t < at + length * 6:
                g += amp * math.exp(-(t - at) / length) * rng.uniform(-1, 1)
        texture = grain_filter(g) * 3.0
        drip = 0.0
        for at, f, amp in drips:
            dt = t - at
            if 0 <= dt < .03:
                drip += amp * math.sin(math.tau * f * dt * (1 + dt * 18)) * math.exp(-dt / .008)
        fade = min(1.0, (duration - t) / .03)
        out.append(hp(body + texture + drip) * fade)
    name = ('land_' if landing else 'step_') + surface + ('' if variant == 0 else f'_{variant+1}')
    save(name, out, .5 if landing else .42)


def save(name, data, peak_level):
    peak = max(max(abs(x) for x in data), 1e-6)
    with wave.open(str(ROOT / (name + '.wav')), 'wb') as f:
        f.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        f.writeframes(b''.join(struct.pack('<h', int(max(-1.0, min(1.0, x / peak * peak_level)) * 32767)) for x in data))


def effect(name, seconds, sample, seed=731):
    rng = random.Random(seed)
    save(name, [sample(i / RATE, rng) for i in range(int(seconds * RATE))], .6)


def stone_effects():
    """Stones thrown by the monkeys: whoosh, knock on ground or wood, splash into water."""
    sweep = {'f': None}

    def whoosh(t, rng):
        k = min(t / .35, 1.0)
        if sweep['f'] is None or int(t * RATE) % 64 == 0:
            old = sweep['f']
            sweep['f'] = Biquad('band', 500 + 1400 * k, .9)
            if old:
                sweep['f'].x1, sweep['f'].x2, sweep['f'].y1, sweep['f'].y2 = old.x1, old.x2, old.y1, old.y2
        return sweep['f'](rng.uniform(-1, 1)) * math.sin(math.pi * k) ** 2
    effect('stone_whoosh', .35, whoosh, 11)

    for i, (f1, f2) in enumerate([(240, 820), (300, 1000)]):
        r1, r2, lp = Biquad('band', f1, 5), Biquad('band', f2, 6), Biquad('low', 2500)

        def knock(t, rng, r1=r1, r2=r2, lp=lp):
            n = rng.uniform(-1, 1)
            bounce = .35 * math.exp(-(t - .07) / .003) if t > .07 else 0.0
            return lp(r1(n) * 1.2 + r2(n) * .7) * (math.exp(-t / .004) + bounce + .3 * math.exp(-t / .03))
        effect('stone_hit' + ('' if i == 0 else '_2'), .22, knock, 20 + i)

    lo, mid = Biquad('low', 400), Biquad('band', 1500, .8)

    def splash(t, rng):
        n = rng.uniform(-1, 1)
        env = min(1, t / .01) * math.exp(-t / .09)
        plop = math.sin(math.tau * 380 * t * (1 + t * 6)) * math.exp(-t / .03) * .5
        drips = 0.0
        for at, f in [(.13, 1300), (.19, 1700), (.27, 1100), (.33, 1500)]:
            dt = t - at
            if 0 <= dt < .03:
                drips += .12 * math.sin(math.tau * f * dt * (1 + dt * 20)) * math.exp(-dt / .007)
        return (lo(n) * .9 + mid(n) * .6) * env + plop + drips
    effect('stone_splash', .45, splash, 31)


def write(name, seconds, sample):
    rng = random.Random(731)
    data = bytearray()
    for i in range(int(seconds * 22050)):
        t = i / 22050
        value = max(-1, min(1, sample(t, rng)))
        data.extend(struct.pack("<h", int(value * 23000)))
    with wave.open(str(ROOT / (name + ".wav")), "wb") as out:
        out.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
        out.writeframes(data)


if __name__ == "__main__":
    ROOT.mkdir(parents=True, exist_ok=True)
    for surface in ['earth', 'wood', 'stone', 'water']:
        for variant in range(3):
            foley(surface, variant)
            foley(surface, variant, landing=True)
    if '--foley-only' in sys.argv:
        sys.exit(0)
    stone_effects()
    if '--stones-only' in sys.argv:
        sys.exit(0)
    write("jungle_call", 1.4, lambda t, r: math.sin(math.tau*(1600*t+95*math.sin(t*18))) * max(0, math.sin(t*13))**8 * math.sin(math.pi*t/1.4)**2 * .14)
    write("water_flow", 4.0, lambda t, r: r.uniform(-1,1)*.18*(.75+.15*math.sin(t*3)+.1*math.sin(t*7)))
