shader_type spatial;
// Wasser für Prolog, Strand und die Wasserblöcke in den Leveln.
// Große Wellen verschieben die Punkte des Meshes, feine Kräuselungen entstehen nur in der
// Beleuchtung (Normalen pro Pixel). Dadurch sieht das Wasser auch auf grob unterteilten
// Flächen glatt aus, und Sonne und Himmel spiegeln sich gebrochen auf der Oberfläche.
// `storm` (0 .. 1) macht das Wasser dunkler, rauer und legt Schaum auf die Kämme,
// `offset` verschiebt das Wellenmuster (so sieht es aus, als fahre das Schiff).
//
// Auf Leistung getrimmt (läuft pro Pixel, in 4K also sehr oft): Alle Steigungen werden direkt
// aus den Sinuswellen berechnet statt über mehrfaches Abtasten, Rauschen gibt es nur einmal
// für den Schaum und nur, wenn überhaupt Schaum zu sehen ist.
render_mode cull_disabled, specular_schlick_ggx;

uniform vec3 calm_color : source_color = vec3(0.05, 0.25, 0.36);
uniform vec3 storm_color : source_color = vec3(0.03, 0.07, 0.09);
uniform vec3 foam_color : source_color = vec3(0.85, 0.9, 0.93);
uniform float wave_height = 0.3;
uniform float storm = 0.0;
uniform vec2 offset = vec2(0.0);
// Glätte der Oberfläche: klein = klare Spiegelungen und Sonnenglitzern
uniform float roughness : hint_range(0.0, 1.0) = 0.06;
// Für Wasser im Schatten (Level 1/2): Eigenleuchten gegen Schwarz
uniform float self_light : hint_range(0.0, 1.0) = 0.0;
// Feine Kräuselungen
uniform float ripple_strength : hint_range(0.0, 2.0) = 0.5;
uniform float ripple_scale = 0.9;   // Wiederholungen pro Meter
uniform float ripple_speed = 0.6;

varying float v_height;
varying vec2 v_pos;

// Große Wellen: x = Höhe, yz = Steigung in x- und z-Richtung
vec3 waves(vec2 p, float t) {
	float a0 = p.x * 0.16 + t * 1.1 + sin(p.y * 0.05) * 2.0;
	vec2 k1 = vec2(-0.25, 0.21);
	vec2 k2 = vec2(0.41, 0.37);
	vec2 k3 = vec2(-0.7, 0.9);
	float a1 = dot(p, k1) + t * 1.6;
	float a2 = dot(p, k2) + t * 2.3;
	float a3 = dot(p, k3) + t * 3.1;
	float h = sin(a0) + sin(a1) * 0.55 + sin(a2) * 0.3 + sin(a3) * 0.15;
	vec2 g = vec2(0.16, cos(p.y * 0.05) * 0.1) * cos(a0)
		+ k1 * cos(a1) * 0.55 + k2 * cos(a2) * 0.3 + k3 * cos(a3) * 0.15;
	return vec3(h, g) * 0.5;
}

// Steigung der Kräuselungen: sechs kurze Wellen aus verschiedenen Richtungen
vec2 ripple_slope(vec2 p, float t) {
	vec2 s = vec2(0.0);
	vec2 k;
	k = vec2(1.3, 0.4);   s += k * cos(dot(p, k) + t * 1.9) * 0.30;
	k = vec2(-0.6, 1.1);  s += k * cos(dot(p, k) + t * 1.7) * 0.30;
	k = vec2(0.9, -1.5);  s += k * cos(dot(p, k) + t * 2.1) * 0.22;
	k = vec2(-2.1, -0.8); s += k * cos(dot(p, k) + t * 2.6) * 0.14;
	k = vec2(2.7, 1.6);   s += k * cos(dot(p, k) + t * 3.0) * 0.09;
	k = vec2(-1.3, 3.1);  s += k * cos(dot(p, k) + t * 3.2) * 0.08;
	return s;
}

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

void vertex() {
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 p = world.xz + offset;
	float h = waves(p, TIME).x;
	VERTEX.y += h * wave_height;
	v_height = h;
	v_pos = p;
}

void fragment() {
	vec2 p = v_pos;
	float t = TIME;

	vec2 slope = waves(p, t).yz * wave_height;
	slope += ripple_slope(p * ripple_scale, t * ripple_speed)
		* ripple_strength * (1.0 + storm * 3.0) * 0.15;
	vec3 world_normal = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	// Farbe: Täler tief und dunkel, Kämme heller (Licht scheint durch das dünnere Wasser)
	vec3 deep = mix(calm_color, storm_color, storm);
	float crest = clamp(v_height * 0.5 + 0.5, 0.0, 1.0);
	vec3 water = mix(deep * 0.7, deep * 1.5 + vec3(0.0, 0.04, 0.04), crest * crest);

	// Schaum auf den Kämmen; im Sturm brechen schon niedrigere Kämme
	float foam_line = mix(0.5, 0.15, storm);
	float foam = 0.0;
	if (v_height > foam_line - 0.45) {
		float n = value_noise(p * 1.7 + t * vec2(0.5, 0.3));
		foam = smoothstep(foam_line, foam_line + 0.4, v_height + (n - 0.5) * mix(0.4, 0.9, storm));
		foam *= 0.08 + storm * 0.85;
	}

	ALBEDO = mix(water, foam_color, foam);
	EMISSION = ALBEDO * self_light;
	ROUGHNESS = mix(roughness + storm * 0.1, 0.7, foam);
	SPECULAR = 0.5;
}
