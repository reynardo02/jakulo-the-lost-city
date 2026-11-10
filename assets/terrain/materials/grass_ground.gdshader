shader_type spatial;
// Realistischer Grasboden für die Boden-Kacheln (Material "grass").
// Die Textur wird in Weltkoordinaten projiziert -> läuft ohne Naht über alle Kacheln,
// egal wie sie gedreht sind. Zwei Maßstäbe + Rauschen verdecken die Wiederholung.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 3.0;          // Meter pro Texturwiederholung (feine Ebene)
uniform float macro_size = 11.0;        // Meter pro Wiederholung der groben, gedrehten Ebene
uniform float variation_size = 18.0;    // Größe der hellen/dunklen Flecken in Metern
uniform vec3 tint_dry : source_color = vec3(0.86, 0.84, 0.62);
uniform vec3 tint_lush : source_color = vec3(0.82, 0.95, 0.78);
uniform float roughness_value = 0.95;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
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

vec3 grass_at(vec2 p) {
	// feine Ebene + grobe, um ~37° gedrehte Ebene, per Rauschen gemischt
	vec3 fine = texture(albedo_tex, p / tile_size).rgb;
	mat2 rot = mat2(vec2(0.799, 0.602), vec2(-0.602, 0.799));
	vec3 coarse = texture(albedo_tex, rot * p / macro_size + vec2(0.37, 0.71)).rgb;
	float m = smoothstep(0.3, 0.7, value_noise(p / 6.0));
	return mix(fine, coarse, m * 0.55);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec3 w = pow(n, vec3(4.0));
	w /= (w.x + w.y + w.z);

	// Triplanar: oben XZ, Seiten der Grasschicht XY / ZY
	vec3 col = grass_at(world_pos.xz) * w.y
			+ grass_at(world_pos.xy) * w.z
			+ grass_at(world_pos.zy) * w.x;

	// großflächige Farbvariation (trockenere / sattere Stellen)
	float v = value_noise(world_pos.xz / variation_size) * 0.65
			+ value_noise(world_pos.xz / (variation_size * 0.35)) * 0.35;
	col *= mix(tint_dry, tint_lush, smoothstep(0.25, 0.75, v));

	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.2;
}
