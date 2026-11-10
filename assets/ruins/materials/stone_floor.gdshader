shader_type spatial;
// Steinplatten-Boden passend zum Tempeltor (scenes/ruins/stone_floor.tscn).
// Textur in Weltkoordinaten -> nebeneinanderliegende Kacheln gehen ohne Naht ineinander über.
// Nur ein Maßstab (das Plattenmuster ist regelmäßig, Mischen würde Doppelkanten erzeugen);
// Wiederholung wird über großflächige Farb- und Moosvariation kaschiert.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tile_size = 5.0;          // Meter pro Texturwiederholung
uniform float variation_size = 14.0;    // Größe der helleren/dunkleren Flecken in Metern
uniform vec3 tint_light : source_color = vec3(1.05, 1.03, 0.98);
uniform vec3 tint_dark : source_color = vec3(0.72, 0.72, 0.66);
uniform vec3 moss_color : source_color = vec3(0.33, 0.42, 0.18);
uniform float moss_amount = 0.35;
uniform float bump_strength = 1.6;

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

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec3 n = abs(world_normal);
	vec3 w = pow(n, vec3(4.0));
	w /= (w.x + w.y + w.z);

	vec2 uv_top = world_pos.xz / tile_size;
	vec3 col = texture(albedo_tex, uv_top).rgb * w.y
			+ texture(albedo_tex, world_pos.xy / tile_size).rgb * w.z
			+ texture(albedo_tex, world_pos.zy / tile_size).rgb * w.x;

	// großflächige Variation: hellere / dunklere, bemooste Bereiche
	float v = value_noise(world_pos.xz / variation_size) * 0.6
			+ value_noise(world_pos.xz / (variation_size * 0.3)) * 0.4;
	col *= mix(tint_dark, tint_light, smoothstep(0.2, 0.8, v));
	float joints = 1.0 - smoothstep(0.25, 0.45, lum(col));   // dunkle Fugen
	float moss = smoothstep(0.55, 0.8, value_noise(world_pos.xz / 3.0 + 7.3)) * moss_amount;
	col = mix(col, moss_color * (0.6 + lum(col)), clamp(moss * (0.4 + joints), 0.0, 1.0));

	// einfache Normalen aus der Helligkeit (Fugen liegen tiefer) – nur auf der Oberseite
	vec2 px = vec2(1.0 / 1024.0);
	float h = lum(texture(albedo_tex, uv_top).rgb);
	float hx = lum(texture(albedo_tex, uv_top + vec2(px.x, 0.0)).rgb);
	float hy = lum(texture(albedo_tex, uv_top + vec2(0.0, px.y)).rgb);
	vec3 bump = normalize(vec3((h - hx) * bump_strength * 8.0, (h - hy) * bump_strength * 8.0, 1.0));
	NORMAL_MAP = mix(vec3(0.5, 0.5, 1.0), bump * 0.5 + 0.5, w.y);

	ALBEDO = col;
	ROUGHNESS = mix(0.85, 0.98, joints);
	SPECULAR = 0.3;
}
