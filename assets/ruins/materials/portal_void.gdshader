shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// Dunkelheit im magischen Portal (scenes/ruins/magic_portal.tscn).
// Fast schwarz, langsam wabernde Schlieren und ein schwacher Schimmer am Rand der Öffnung.
// Von beiden Seiten gleich -> man sieht durch das Portal nichts als Dunkelheit.

uniform vec3 glow_color : source_color = vec3(0.25, 0.95, 0.9);   // passt zu den türkisen Runen
uniform float edge_glow = 0.1;       // Stärke des Randschimmers
uniform float edge_width = 0.04;     // Breite des Schimmers (Anteil der Fläche)
uniform float swirl_strength = 0.012; // Helligkeit der Schlieren in der Mitte
uniform float swirl_speed = 0.25;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += value_noise(p) * a;
		p *= 2.1;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 c = UV - 0.5;
	// Strudel: Koordinaten je nach Abstand zur Mitte langsam verdreht
	float r = length(c * vec2(1.0, 0.65));
	float ang = TIME * swirl_speed + r * 6.0;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	float n = fbm(rot * c * 4.0 + vec2(0.0, TIME * 0.05));

	// Abstand zum Rand der Öffnung (0 am Rand, 0.5 in der Mitte)
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float rim = 1.0 - smoothstep(0.0, edge_width, edge);
	float flicker = 0.85 + 0.15 * sin(TIME * 1.7 + n * 6.0);

	vec3 col = glow_color * (n * n) * swirl_strength * (1.0 - rim);   // kaum sichtbare Schlieren
	col += glow_color * rim * rim * edge_glow * (0.6 + 0.4 * n) * flicker;
	ALBEDO = col;
}
